'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');
const {
  convertBloodValue,
  normalizeBloodPayload,
  normalizeGutPayload,
} = require('../src/clinical/normalization');
const {
  scoreBloodReport,
  scoreGutReport,
  scoreMetric,
} = require('../src/clinical/scoring');
const {buildHealthSnapshot} = require('../src/clinical/snapshot');
const {
  ClinicalConflictError,
  ClinicalValidationError,
  validateEnvelope,
} = require('../src/clinical/validation');
const {
  ingestionFailureStatus,
  reserveIngestionJob,
  verifyHmac,
} = require('../src/clinical/ingestion');

function baseEnvelope(payload) {
  return {
    schemaVersion: '1.0',
    source: 'synthetic-lab',
    externalReportId: 'report-001',
    revision: 1,
    memberRef: {type: 'uid', value: 'member-001'},
    sampledAt: '2026-07-01T09:00:00.000Z',
    reportedAt: '2026-07-02T09:00:00.000Z',
    idempotencyKey: 'synthetic-lab-report-001-r1',
    kit: {udi: 'UDI-SYNTHETIC', lot: 'LOT-001', expiresAt: '2027-01-01'},
    payload,
  };
}

const gutPayload = {
  alpha: {shannon: 2.4, simpson: 0.82, chao1: 312, observedOtus: 248},
  beta: {
    pcoa: [
      {pc1: 0.1, pc2: 0.2, label: 'subject', isSubject: true},
      {pc1: 0.2, pc2: 0.3, label: 'reference'},
    ],
    explainedVariance: [0.31, 0.18],
  },
  abundance: {
    phylum: [{name: 'Firmicutes', value: 0.55}, {name: 'Bacteroidota', value: 0.4}],
    genus: [{name: 'Bacteroides', value: 22}, {name: 'Others', value: 70}],
  },
  unifrac: {weighted: 0.31, unweighted: 0.46},
  metadata: {sampleId: 'SYN-001', assay: '16S rRNA V3-V4'},
};

const bloodPayload = {
  biomarkers: [
    {code: 'ALT', value: 24, unit: 'IU/L'},
    {code: 'CREATININE', value: 88.4, unit: 'µmol/L'},
    {code: 'GLUCOSE', value: 5.55, unit: 'mmol/L'},
    {code: 'TG', value: 1.13, unit: 'mmol/L'},
    {code: 'HDL', value: 1.3, unit: 'mmol/L'},
  ],
  analyzer: {manufacturer: 'Synthetic', model: 'POCT-TEST'},
};

test('validates and normalizes a microbiome payload', () => {
  const envelope = validateEnvelope('gut', baseEnvelope(gutPayload));
  const normalized = normalizeGutPayload(envelope.payload);
  assert.equal(normalized.abundance.phylum[0].value, 55);
  assert.equal(normalized.beta.distance, 'bray-curtis');
  assert.equal(normalized.metadata.sampleId, 'SYN-001');
});

test('rejects duplicate or unsupported blood markers', () => {
  const invalid = baseEnvelope({
    biomarkers: [
      {code: 'ALT', value: 1, unit: 'U/L'},
      {code: 'ALT', value: 2, unit: 'U/L'},
      {code: 'UNKNOWN', value: 3, unit: 'mg/dL'},
    ],
  });
  assert.throws(() => validateEnvelope('blood', invalid), ClinicalValidationError);
});

test('rejects a report timestamp earlier than its sample timestamp', () => {
  const invalid = baseEnvelope(gutPayload);
  invalid.reportedAt = '2026-06-30T09:00:00.000Z';
  assert.throws(() => validateEnvelope('gut', invalid), ClinicalValidationError);
  assert.equal(new ClinicalConflictError('conflict').code, 'idempotency_conflict');
});

test('converts supported blood units to canonical units', () => {
  assert.equal(convertBloodValue('CRE', 88.4, 'µmol/L'), 1);
  assert.equal(convertBloodValue('GLU', 5.55, 'mmol/L'), 100.001);
  assert.equal(convertBloodValue('CHOL', 5, 'mmol/L'), 193.35);
  assert.equal(convertBloodValue('TG', 1.13, 'mmol/L'), 100.0841);
  assert.equal(convertBloodValue('TBIL', 17.104, 'µmol/L'), 1);
  assert.equal(convertBloodValue('TP', 70, 'g/L'), 7);
});

test('normalizes all 13 POCT biomarkers and preserves panel membership', () => {
  const samples = [
    ['ALT', 20, 'IU/L'], ['AST', 21, 'U/L'],
    ['TBIL', 17.104, 'µmol/L'], ['DBIL', 8.552, 'µmol/L'],
    ['TP', 70, 'g/L'], ['ALB', 40, 'g/L'],
    ['UREA', 5, 'mmol/L'], ['CRE', 88.4, 'µmol/L'],
    ['UA', 356.88, 'µmol/L'], ['GLU', 5.55, 'mmol/L'],
    ['TG', 1.13, 'mmol/L'], ['CHOL', 5, 'mmol/L'],
    ['HDL-C', 1.3, 'mmol/L'],
  ];
  const normalized = normalizeBloodPayload({
    biomarkers: samples.map(([code, value, unit]) => ({code, value, unit})),
  });
  assert.equal(normalized.biomarkers.length, 13);
  assert.deepEqual(
    [...new Set(normalized.biomarkers.map((marker) => marker.panel))].sort(),
    ['kidney', 'lipid', 'liver', 'metabolic'],
  );
  assert.equal(normalized.biomarkers.find((marker) => marker.code === 'UA').value, 6);
  assert.equal(normalized.biomarkers.find((marker) => marker.code === 'DBIL').value, 0.5);
});

test('does not guess unsupported blood units', () => {
  let error;
  try {
    convertBloodValue('CRE', 1, 'mmol/L');
  } catch (cause) {
    error = cause;
  }
  assert.ok(error instanceof ClinicalValidationError);
  assert.equal(ingestionFailureStatus(error), 'review_pending');
});

test('leaves blood and gut scores unscored without an approved policy', () => {
  const blood = scoreBloodReport(normalizeBloodPayload(bloodPayload), null);
  const gut = scoreGutReport(normalizeGutPayload(gutPayload), null);
  assert.equal(blood.overall.score, null);
  assert.equal(blood.overall.label, '산정 준비 중');
  assert.equal(gut.overall.score, null);
  assert.equal(gut.metrics.shannon.value, 2.4);
});

test('uses only approved versioned scoring bands', () => {
  const policy = {
    version: 'blood-v1',
    status: 'approved',
    markers: Object.fromEntries([
      'ALT', 'AST', 'TBIL', 'DBIL', 'TP', 'ALB', 'UREA', 'CRE', 'UA',
      'GLU', 'TG', 'CHOL', 'HDL-C',
    ].map((code) => [code, {
        weight: 1,
        referenceRange: {lower: 10, upper: 40, unit: 'U/L'},
        bands: [{min: 10, max: 40, score: 100, status: 'within', label: '범위 내'}],
      }])),
  };
  const scored = scoreBloodReport(normalizeBloodPayload(bloodPayload), policy);
  assert.equal(scored.policyVersion, 'blood-v1');
  assert.equal(scored.biomarkers[0].score, 100);
  assert.equal(scored.biomarkers[1].score, null);
});

test('rejects incomplete approved clinical policies instead of generating scores', () => {
  const blood = scoreBloodReport(normalizeBloodPayload(bloodPayload), {
    version: 'incomplete',
    status: 'approved',
    markers: {ALT: {bands: [{score: 100}]}},
  });
  const gut = scoreGutReport(normalizeGutPayload(gutPayload), {
    version: 'incomplete',
    status: 'approved',
    metrics: {shannon: {bands: [{score: 100}]}},
  });
  assert.equal(blood.overall.score, null);
  assert.equal(gut.overall.score, null);
});

test('range bands include their declared boundaries', () => {
  const definition = {
    referenceRange: {lower: 10, upper: 40, unit: 'U/L'},
    bands: [{min: 10, max: 40, score: 100, status: 'within', label: '범위 내'}],
  };
  assert.equal(scoreMetric(10, definition).status, 'within');
  assert.equal(scoreMetric(40, definition).status, 'within');
  assert.equal(scoreMetric(40.1, definition).status, 'unscored');
});

test('keeps missing insight axes explicit', () => {
  const snapshot = buildHealthSnapshot({
    asOf: new Date('2026-07-02T09:00:00.000Z'),
    axes: {gut: 80, blood: null, diet: 70, fitness: null},
    policy: {
      version: 'insight-v1',
      status: 'approved',
      minimumAxes: 4,
      axisWeights: {fitness: 1, diet: 1, gut: 1, blood: 1},
    },
  });
  assert.equal(snapshot.overallScore, null);
  assert.equal(snapshot.completeness, 0.5);
  assert.deepEqual(snapshot.missingAxes, ['fitness', 'blood']);
});

test('verifies HMAC signatures and rejects replay windows', () => {
  const rawBody = Buffer.from('{"schemaVersion":"1.0"}', 'utf8');
  const timestamp = '1782954000';
  const signature = crypto
    .createHmac('sha256', 'test-secret')
    .update(Buffer.concat([Buffer.from(`${timestamp}.`), rawBody]))
    .digest('hex');
  const now = Number(timestamp) * 1000;
  assert.equal(verifyHmac({
    rawBody,
    keyId: 'test-key',
    timestamp,
    signature,
    keyMap: {'test-key': 'test-secret'},
    now,
  }), true);
  assert.equal(verifyHmac({
    rawBody,
    keyId: 'test-key',
    timestamp,
    signature,
    keyMap: {'test-key': 'test-secret'},
    now: now + 10 * 60 * 1000,
  }), false);
});

test('idempotency reservation returns duplicates and rejects changed payloads', async () => {
  const existing = {
    exists: true,
    data: () => ({status: 'completed', payloadHash: 'hash-a', reportId: 'report-a'}),
  };
  const db = {
    runTransaction: async (callback) => callback({
      get: async () => existing,
      set: () => assert.fail('duplicate reservations must not be written'),
    }),
  };
  const input = {
    admin: {firestore: {FieldValue: {serverTimestamp: () => 'timestamp'}}},
    db,
    jobRef: {},
    reportKeyRef: {},
    jobId: 'job-a',
    type: 'blood',
    envelope: {source: 'lab', externalReportId: 'external-a', revision: 1},
    keyId: 'key-a',
    reportId: 'report-a',
  };
  const duplicate = await reserveIngestionJob({...input, payloadHash: 'hash-a'});
  assert.deepEqual(duplicate, {duplicate: true, status: 'completed', reportId: 'report-a'});
  await assert.rejects(
    reserveIngestionJob({...input, payloadHash: 'hash-b'}),
    ClinicalConflictError,
  );
});

test('a report revision cannot be overwritten through another idempotency key', async () => {
  let readCount = 0;
  const db = {
    runTransaction: async (callback) => callback({
      get: async () => {
        readCount += 1;
        return readCount === 1
          ? {exists: false}
          : {exists: true, data: () => ({jobId: 'original-job'})};
      },
      set: () => assert.fail('conflicting report revisions must not be written'),
    }),
  };
  await assert.rejects(
    reserveIngestionJob({
      admin: {firestore: {FieldValue: {serverTimestamp: () => 'timestamp'}}},
      db,
      jobRef: {},
      reportKeyRef: {},
      jobId: 'new-job',
      type: 'gut',
      envelope: {
        source: 'lab',
        externalReportId: 'external-a',
        revision: 1,
        idempotencyKey: 'different-key',
      },
      keyId: 'key-a',
      reportId: 'report-a',
      payloadHash: 'hash-a',
    }),
    (error) => error instanceof ClinicalConflictError &&
      error.code === 'report_revision_conflict',
  );
});

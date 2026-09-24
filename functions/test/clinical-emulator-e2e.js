'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {after, before, test} = require('node:test');
const {deleteApp, initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'dfet-e2e';
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const keyId = 'e2e';
const secret = 'e2e-secret';
const app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`}, 'clinical-e2e');
const db = getFirestore(app);

function envelope(type) {
  const now = Date.now();
  const common = {
    schemaVersion: '1.0',
    source: 'emulator-e2e',
    externalReportId: `${type}-e2e-001`,
    revision: 1,
    memberRef: {type: 'uid', value: 'member-e2e'},
    sampledAt: new Date(now - 120000).toISOString(),
    reportedAt: new Date(now - 60000).toISOString(),
    idempotencyKey: `${type}:emulator-e2e-001:1`,
    kit: {udi: 'UDI-E2E', lot: 'LOT-E2E', expiresAt: '2027-12-31'},
  };
  if (type === 'gut') {
    return {
      ...common,
      payload: {
        alpha: {shannon: 2.4, simpson: 0.82, chao1: 312, observedOtus: 248},
        beta: {
          pcoa: [
            {pc1: 0.1, pc2: 0.2, label: 'subject', isSubject: true},
            {pc1: 0.2, pc2: 0.3, label: 'reference'},
          ],
          explainedVariance: [0.31, 0.18],
        },
        abundance: {
          phylum: [{name: 'Firmicutes', value: 55}, {name: 'Bacteroidota', value: 40}],
          genus: [{name: 'Bacteroides', value: 22}, {name: 'Others', value: 70}],
        },
        unifrac: {weighted: 0.31, unweighted: 0.46},
        metadata: {sampleId: 'E2E-001', assay: '16S rRNA V3-V4'},
      },
    };
  }
  const biomarkers = [
    ['ALT', 20, 'U/L'], ['AST', 21, 'U/L'], ['TBIL', 1, 'mg/dL'],
    ['DBIL', 0.3, 'mg/dL'], ['TP', 7, 'g/dL'], ['ALB', 4, 'g/dL'],
    ['UREA', 30, 'mg/dL'], ['CRE', 1, 'mg/dL'], ['UA', 6, 'mg/dL'],
    ['GLU', 100, 'mg/dL'], ['TG', 100, 'mg/dL'], ['CHOL', 190, 'mg/dL'],
    ['HDL-C', 55, 'mg/dL'],
  ];
  return {
    ...common,
    payload: {
      biomarkers: biomarkers.map(([code, value, unit]) => ({code, value, unit})),
      analyzer: {manufacturer: 'D-FET Synthetic', model: 'E2E'},
    },
  };
}

async function ingest(type, payload) {
  const rawBody = JSON.stringify(payload);
  const timestamp = Date.now().toString();
  const signature = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex');
  const response = await fetch(
    `http://${functionHost}/${projectId}/asia-northeast3/clinicalApi/v1/ingestions/${type}`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-dfet-key-id': keyId,
        'x-dfet-timestamp': timestamp,
        'x-dfet-signature': signature,
      },
      body: rawBody,
    },
  );
  return {response, body: await response.json()};
}

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Firestore Emulator is required');
  assert.ok(process.env.FIREBASE_STORAGE_EMULATOR_HOST, 'Storage Emulator is required');
  await db.collection('users').doc('member-e2e').set({
    role: 'member',
    careType: 'both',
  });
});

after(async () => {
  await deleteApp(app);
});

test('signed gut and blood ingestion creates reports, snapshots, raw files, and idempotent jobs', async () => {
  const gutPayload = envelope('gut');
  const gut = await ingest('gut', gutPayload);
  assert.equal(gut.response.status, 200, JSON.stringify(gut.body));
  assert.equal(gut.body.data.status, 'completed');
  assert.equal(gut.body.data.duplicate, false);

  const gutReport = await db.collection('gutReports').doc(gut.body.data.reportId).get();
  const gutExpert = await db.collection('gutReportExperts').doc(gut.body.data.reportId).get();
  const gutSnapshot = await db.collection('healthSnapshots').doc(gut.body.data.snapshotId).get();
  assert.equal(gutReport.exists, true);
  assert.equal(gutExpert.exists, true);
  assert.equal(gutReport.data().overall.score, null);
  assert.equal(gutReport.data().overall.label, '산정 준비 중');
  assert.deepEqual(gutSnapshot.data().missingAxes, ['fitness', 'diet', 'gut', 'blood']);
  const [gutRawExists] = await getStorage(app)
    .bucket()
    .file(gutExpert.data().rawPath)
    .exists();
  assert.equal(gutRawExists, true);

  const duplicate = await ingest('gut', gutPayload);
  assert.equal(duplicate.response.status, 200, JSON.stringify(duplicate.body));
  assert.equal(duplicate.body.data.duplicate, true);
  assert.equal(duplicate.body.data.reportId, gut.body.data.reportId);

  const changed = structuredClone(gutPayload);
  changed.payload.alpha.shannon = 3.1;
  const conflict = await ingest('gut', changed);
  assert.equal(conflict.response.status, 409, JSON.stringify(conflict.body));
  assert.equal(conflict.body.error.code, 'idempotency_conflict');

  const blood = await ingest('blood', envelope('blood'));
  assert.equal(blood.response.status, 200, JSON.stringify(blood.body));
  const bloodReport = await db.collection('bloodReports').doc(blood.body.data.reportId).get();
  const bloodExpert = await db.collection('bloodReportExperts').doc(blood.body.data.reportId).get();
  assert.equal(bloodReport.exists, true);
  assert.equal(bloodExpert.exists, true);
  assert.equal(bloodReport.data().biomarkers.length, 13);
  assert.equal(bloodReport.data().overall.score, null);
});

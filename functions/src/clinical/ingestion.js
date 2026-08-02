'use strict';

const crypto = require('node:crypto');
const {INGESTION_TYPES} = require('./constants');
const {normalizeBloodPayload, normalizeGutPayload, round} = require('./normalization');
const {scoreBloodReport, scoreGutReport} = require('./scoring');
const {buildHealthSnapshot} = require('./snapshot');
const {
  ClinicalConflictError,
  ClinicalValidationError,
  validateEnvelope,
} = require('./validation');

const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
const MAX_BODY_BYTES = 10 * 1024 * 1024;

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function parseKeyMap(rawSecret) {
  if (!rawSecret) return {};
  try {
    const parsed = JSON.parse(rawSecret);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function parseTimestamp(value) {
  if (!value) return Number.NaN;
  if (/^\d+$/.test(value)) {
    const numeric = Number(value);
    return numeric < 10_000_000_000 ? numeric * 1000 : numeric;
  }
  return Date.parse(value);
}

function verifyHmac({rawBody, keyId, timestamp, signature, keyMap, now = Date.now()}) {
  const secret = keyMap[keyId];
  if (!secret || typeof secret !== 'string') return false;
  const timestampMs = parseTimestamp(timestamp);
  if (!Number.isFinite(timestampMs) || Math.abs(now - timestampMs) > MAX_CLOCK_SKEW_MS) {
    return false;
  }
  if (typeof signature !== 'string' || !/^[a-f\d]{64}$/i.test(signature)) return false;
  const payload = Buffer.concat([Buffer.from(`${timestamp}.`, 'utf8'), rawBody]);
  const expected = crypto.createHmac('sha256', secret).update(payload).digest();
  const supplied = Buffer.from(signature, 'hex');
  return supplied.length === expected.length && crypto.timingSafeEqual(expected, supplied);
}

function jsonResponse(res, status, body) {
  res.status(status).set('content-type', 'application/json; charset=utf-8').send(body);
}

function ingestionTypeFromPath(path) {
  return INGESTION_TYPES.find((type) => path.endsWith(`/v1/ingestions/${type}`)) || null;
}

function timestamp(admin, value) {
  return admin.firestore.Timestamp.fromDate(new Date(value));
}

function publicKit(kit) {
  if (!kit) return null;
  return {
    udi: kit.udi || null,
    lot: kit.lot || null,
    expiresAt: kit.expiresAt || null,
  };
}

function ingestionFailureStatus(error) {
  return error instanceof ClinicalValidationError &&
    error.message === 'Unsupported biomarker unit'
    ? 'review_pending'
    : 'failed';
}

async function resolveMemberId({db, envelope}) {
  const memberRef = typeof envelope.memberRef === 'string'
    ? {type: 'uid', value: envelope.memberRef}
    : envelope.memberRef;
  if (memberRef.type === 'uid') {
    const user = await db.collection('users').doc(memberRef.value).get();
    if (!user.exists) {
      throw new ClinicalValidationError('Member was not found', ['memberRef uid does not exist']);
    }
    return memberRef.value;
  }
  const aliasId = sha256(`${envelope.source}:${memberRef.value}`);
  const alias = await db.collection('memberAliases').doc(aliasId).get();
  if (!alias.exists || typeof alias.data().userId !== 'string') {
    throw new ClinicalValidationError('Member alias was not found', [
      'Map the external member ID in the admin portal before retrying',
    ]);
  }
  return alias.data().userId;
}

async function loadActivePolicy(db, collection, kind) {
  const snapshot = await db
    .collection(collection)
    .where('kind', '==', kind)
    .where('status', '==', 'approved')
    .where('active', '==', true)
    .orderBy('publishedAt', 'desc')
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0].data();
}

async function loadLatestScore(db, collection, userId, asOf) {
  const snapshot = await db
    .collection(collection)
    .where('userId', '==', userId)
    .where('reportedAt', '<=', asOf)
    .orderBy('reportedAt', 'desc')
    .limit(1)
    .get();
  if (snapshot.empty) return {score: null, reportId: null};
  const data = snapshot.docs[0].data();
  return {
    score: Number.isFinite(data.overall?.score) ? data.overall.score : null,
    reportId: snapshot.docs[0].id,
  };
}

function clampScore(value) {
  return round(Math.max(0, Math.min(100, value)), 1);
}

async function computeBehaviorAxes({admin, db, userId, policy, asOf}) {
  if (!policy || policy.status !== 'approved' || !policy.behavior) {
    return {fitness: null, diet: null};
  }
  const windowDays = Number.isInteger(policy.windowDays) ? policy.windowDays : 28;
  const start = new Date(asOf.getTime() - windowDays * 24 * 60 * 60 * 1000);
  const startTimestamp = admin.firestore.Timestamp.fromDate(start);
  const userRef = db.collection('users').doc(userId);
  const [workouts, meals] = await Promise.all([
    userRef.collection('workouts').where('timestamp', '>=', startTimestamp).get(),
    userRef.collection('meals').where('timestamp', '>=', startTimestamp).get(),
  ]);

  let fitness = null;
  const fitnessPolicy = policy.behavior.fitness;
  if (fitnessPolicy && Number.isFinite(fitnessPolicy.targetMinutes)) {
    const strengthSetMinutes = Number.isFinite(fitnessPolicy.strengthSetMinutes)
      ? fitnessPolicy.strengthSetMinutes
      : 0;
    const minutes = workouts.docs.reduce((total, doc) => {
      const data = doc.data();
      const duration = Number.isFinite(data.duration) ? data.duration : 0;
      const sets = Array.isArray(data.sets) ? data.sets.length : 0;
      return total + duration + sets * strengthSetMinutes;
    }, 0);
    fitness = clampScore((minutes / fitnessPolicy.targetMinutes) * 100);
  }

  let diet = null;
  const dietPolicy = policy.behavior.diet;
  if (dietPolicy && Number.isFinite(dietPolicy.targetCalories)) {
    const totalsByDate = new Map();
    for (const doc of meals.docs) {
      const data = doc.data();
      const key = typeof data.date === 'string' ? data.date : 'unknown';
      const current = totalsByDate.get(key) || {calories: 0, protein: 0};
      current.calories += Number.isFinite(data.calories) ? data.calories : 0;
      current.protein += Number.isFinite(data.protein) ? data.protein : 0;
      totalsByDate.set(key, current);
    }
    const minimumLoggedDays = Number.isInteger(dietPolicy.minimumLoggedDays)
      ? dietPolicy.minimumLoggedDays
      : windowDays;
    if (totalsByDate.size >= minimumLoggedDays) {
      const dailyScores = [...totalsByDate.values()].map((day) => {
        const calorieScore = 100 - Math.min(
          100,
          Math.abs(day.calories - dietPolicy.targetCalories) / dietPolicy.targetCalories * 100,
        );
        if (!Number.isFinite(dietPolicy.targetProtein)) return calorieScore;
        const proteinScore = Math.min(100, day.protein / dietPolicy.targetProtein * 100);
        return (calorieScore + proteinScore) / 2;
      });
      diet = clampScore(dailyScores.reduce((sum, value) => sum + value, 0) / dailyScores.length);
    }
  }
  return {fitness, diet};
}

function buildReportDocuments({admin, type, envelope, normalized, scored, reportId, userId, rawPath}) {
  const common = {
    reportId,
    userId,
    source: envelope.source,
    externalReportId: envelope.externalReportId,
    revision: envelope.revision,
    sampledAt: timestamp(admin, envelope.sampledAt),
    reportedAt: timestamp(admin, envelope.reportedAt),
    schemaVersion: envelope.schemaVersion,
    policyVersion: scored.policyVersion,
    overall: scored.overall,
    status: scored.overall.status,
    kit: publicKit(envelope.kit),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (type === 'gut') {
    return {
      consumer: {
        ...common,
        alpha: scored.metrics,
        composition: {phylum: normalized.abundance.phylum},
        summary: {
          score: scored.overall.score,
          label: scored.overall.label,
          primaryMetric: scored.metrics.shannon,
        },
      },
      expert: {
        ...common,
        normalized,
        scored,
        rawPath,
      },
    };
  }
  return {
    consumer: {
      ...common,
      biomarkers: scored.biomarkers.map(({sourceValue, sourceUnit, flags, ...marker}) => marker),
      panels: scored.panels,
      summary: {
        score: scored.overall.score,
        label: scored.overall.label,
        reviewCount: scored.biomarkers.filter((marker) => marker.status === 'review').length,
      },
    },
    expert: {
      ...common,
      normalized,
      scored,
      rawPath,
    },
  };
}

async function prepareSnapshot({admin, db, userId, type, reportId, reportScore, asOf}) {
  const [otherGut, otherBlood, policy] = await Promise.all([
    type === 'gut'
      ? Promise.resolve({score: reportScore, reportId})
      : loadLatestScore(db, 'gutReports', userId, asOf),
    type === 'blood'
      ? Promise.resolve({score: reportScore, reportId})
      : loadLatestScore(db, 'bloodReports', userId, asOf),
    loadActivePolicy(db, 'insightPolicyVersions', 'integrated'),
  ]);
  const behavior = await computeBehaviorAxes({admin, db, userId, policy, asOf});
  const snapshotId = sha256(`${userId}:${asOf.toISOString()}:${reportId}`).slice(0, 32);
  const snapshot = buildHealthSnapshot({
    asOf: admin.firestore.Timestamp.fromDate(asOf),
    axes: {
      fitness: behavior.fitness,
      diet: behavior.diet,
      gut: otherGut.score,
      blood: otherBlood.score,
    },
    policy,
    sourceReportIds: {gut: otherGut.reportId, blood: otherBlood.reportId},
  });
  return {
    snapshotId,
    document: {
      ...snapshot,
      snapshotId,
      userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

async function reserveIngestionJob({
  admin,
  db,
  jobRef,
  reportKeyRef,
  jobId,
  type,
  envelope,
  keyId,
  reportId,
  payloadHash,
}) {
  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(jobRef);
    if (existing.exists && existing.data().payloadHash !== payloadHash) {
      throw new ClinicalConflictError(
        'Idempotency key was already used with a different payload',
        ['Use the original payload or submit a new idempotencyKey'],
      );
    }
    if (existing.exists && existing.data().status === 'completed') {
      return {duplicate: true, status: 'completed', reportId: existing.data().reportId};
    }
    if (existing.exists && existing.data().status === 'processing') {
      return {duplicate: true, status: 'processing', reportId: existing.data().reportId || null};
    }
    if (!existing.exists) {
      const existingReport = await transaction.get(reportKeyRef);
      if (existingReport.exists) {
        throw new ClinicalConflictError(
          'External report revision was already submitted with another idempotency key',
          ['Reuse the original idempotencyKey or increment revision for corrected data'],
          'report_revision_conflict',
        );
      }
      transaction.set(reportKeyRef, {
        type,
        source: envelope.source,
        externalReportId: envelope.externalReportId,
        revision: envelope.revision,
        idempotencyKey: envelope.idempotencyKey,
        payloadHash,
        jobId,
        reportId,
        reservedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    transaction.set(jobRef, {
      jobId,
      type,
      source: envelope.source,
      externalReportId: envelope.externalReportId,
      revision: envelope.revision,
      reportId,
      payloadHash,
      status: 'processing',
      createdBy: `hmac:${keyId}`,
      ...(!existing.exists
        ? {createdAt: admin.firestore.FieldValue.serverTimestamp()}
        : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {duplicate: false};
  });
}

async function processIngestion({admin, type, envelope, rawBody, keyId}) {
  const db = admin.firestore();
  const payloadHash = sha256(rawBody);
  const jobId = sha256(
    `${type}:${keyId}:${envelope.source}:${envelope.idempotencyKey}`,
  ).slice(0, 40);
  const reportId = sha256(
    `${type}:${envelope.source}:${envelope.externalReportId}:${envelope.revision}`,
  ).slice(0, 32);
  const jobRef = db.collection('ingestionJobs').doc(jobId);
  const reportKeyRef = db.collection('clinicalReportKeys').doc(reportId);

  const reservation = await reserveIngestionJob({
    admin,
    db,
    jobRef,
    reportKeyRef,
    jobId,
    type,
    envelope,
    keyId,
    reportId,
    payloadHash,
  });
  if (reservation.duplicate) return {jobId, ...reservation};

  try {
    const userId = await resolveMemberId({db, envelope});
    const normalized = type === 'gut'
      ? normalizeGutPayload(envelope.payload)
      : normalizeBloodPayload(envelope.payload);
    const config = await loadActivePolicy(db, 'referenceRangeVersions', type);
    const scored = type === 'gut'
      ? scoreGutReport(normalized, config)
      : scoreBloodReport(normalized, config);
    const rawPath = `clinical-ingest/${type}/${jobId}/payload.json`;
    await admin.storage().bucket().file(rawPath).save(rawBody, {
      contentType: 'application/json',
      resumable: false,
      metadata: {
        metadata: {
          sha256: payloadHash,
          schemaVersion: envelope.schemaVersion,
          jobId,
        },
      },
    });

    const documents = buildReportDocuments({
      admin,
      type,
      envelope,
      normalized,
      scored,
      reportId,
      userId,
      rawPath,
    });
    const consumerCollection = type === 'gut' ? 'gutReports' : 'bloodReports';
    const expertCollection = type === 'gut' ? 'gutReportExperts' : 'bloodReportExperts';
    const preparedSnapshot = await prepareSnapshot({
      admin,
      db,
      userId,
      type,
      reportId,
      reportScore: scored.overall.score,
      asOf: new Date(envelope.reportedAt),
    });
    const batch = db.batch();
    batch.set(db.collection(consumerCollection).doc(reportId), documents.consumer);
    batch.set(db.collection(expertCollection).doc(reportId), documents.expert);
    batch.set(
      db.collection('healthSnapshots').doc(preparedSnapshot.snapshotId),
      preparedSnapshot.document,
    );
    batch.set(jobRef, {
      status: 'completed',
      userId,
      reportId,
      rawPath,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    batch.set(db.collection('auditLogs').doc(), {
      action: `clinical.${type}.ingested`,
      actorUid: null,
      actorEmail: null,
      actorRole: 'integration',
      actor: `hmac:${keyId}`,
      target: {userId, reportId, jobId},
      metadata: {source: envelope.source, revision: envelope.revision},
      occurredAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {
      jobId,
      reportId,
      snapshotId: preparedSnapshot.snapshotId,
      status: 'completed',
      duplicate: false,
    };
  } catch (error) {
    const failureStatus = ingestionFailureStatus(error);
    await jobRef.set({
      status: failureStatus,
      errorCode: error.code || 'internal',
      errorMessage: error instanceof ClinicalValidationError
        ? error.message
        : 'Clinical ingestion failed',
      ...(failureStatus === 'review_pending'
        ? {reviewReasons: error.details || []}
        : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}

function createClinicalApiHandler({admin, getKeyMap}) {
  return async (req, res) => {
    if (req.method !== 'POST') {
      res.set('allow', 'POST');
      return jsonResponse(res, 405, {error: {code: 'method_not_allowed'}});
    }
    const type = ingestionTypeFromPath(req.path || req.url || '');
    if (!type) return jsonResponse(res, 404, {error: {code: 'not_found'}});
    const rawBody = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.from(JSON.stringify(req.body || {}), 'utf8');
    if (rawBody.length > MAX_BODY_BYTES) {
      return jsonResponse(res, 413, {error: {code: 'payload_too_large'}});
    }
    const keyId = req.get('x-dfet-key-id');
    const requestTimestamp = req.get('x-dfet-timestamp');
    const signature = req.get('x-dfet-signature');
    if (!verifyHmac({
      rawBody,
      keyId,
      timestamp: requestTimestamp,
      signature,
      keyMap: getKeyMap(),
    })) {
      return jsonResponse(res, 401, {error: {code: 'invalid_signature'}});
    }

    try {
      const parsed = req.body && typeof req.body === 'object'
        ? req.body
        : JSON.parse(rawBody.toString('utf8'));
      const envelope = validateEnvelope(type, parsed);
      const result = await processIngestion({admin, type, envelope, rawBody, keyId});
      const status = result.status === 'processing' ? 202 : 200;
      return jsonResponse(res, status, {data: result});
    } catch (error) {
      if (error instanceof SyntaxError) {
        return jsonResponse(res, 400, {error: {code: 'invalid_json'}});
      }
      if (error instanceof ClinicalValidationError) {
        return jsonResponse(res, 422, {
          error: {code: error.code, message: error.message, details: error.details},
        });
      }
      if (error instanceof ClinicalConflictError) {
        return jsonResponse(res, 409, {
          error: {code: error.code, message: error.message, details: error.details},
        });
      }
      console.error('Clinical ingestion failed', {type, code: error.code || 'internal'});
      return jsonResponse(res, 500, {error: {code: 'internal'}});
    }
  };
}

module.exports = {
  MAX_CLOCK_SKEW_MS,
  MAX_BODY_BYTES,
  createClinicalApiHandler,
  ingestionTypeFromPath,
  ingestionFailureStatus,
  parseKeyMap,
  processIngestion,
  reserveIngestionJob,
  sha256,
  verifyHmac,
};

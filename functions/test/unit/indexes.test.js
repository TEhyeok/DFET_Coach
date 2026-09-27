'use strict';

// DF-024 (PRD §9.6, V1-05 §10.2.1): composite indexes in firestore.indexes.json.
// TC-DF024-01: the 20 v1 indexes exist, the 8 clinical indexes are unchanged, no duplicates.
// The emulator does not enforce composite indexes (ASM-P0-28), so the file is compared with the
// expected table below, copied by hand from the DF-024 card and V1-05 §10.2.1.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repoRoot = path.resolve(__dirname, '../../..');
const indexFile = JSON.parse(fs.readFileSync(path.join(repoRoot, 'firestore.indexes.json'), 'utf8'));

const ASC = 'ASCENDING';
const DESC = 'DESCENDING';

// Pre-existing clinical indexes (must stay exactly as they are).
const CLINICAL = [
  ['gutReports', [['userId', ASC], ['sampledAt', DESC]]],
  ['bloodReports', [['userId', ASC], ['sampledAt', DESC]]],
  ['gutReports', [['userId', ASC], ['reportedAt', DESC]]],
  ['bloodReports', [['userId', ASC], ['reportedAt', DESC]]],
  ['healthSnapshots', [['userId', ASC], ['asOf', DESC]]],
  ['referenceRangeVersions', [['kind', ASC], ['status', ASC], ['active', ASC], ['publishedAt', DESC]]],
  ['insightPolicyVersions', [['kind', ASC], ['status', ASC], ['active', ASC], ['publishedAt', DESC]]],
  ['ingestionJobs', [['createdBy', ASC], ['createdAt', DESC]]],
];

// V1-05 §10.2.1: PRD §9.6 rows 1-16 plus pending-member timeline rows 17-20 (ASM-05-27).
const V1 = [
  ['soap_notes', [['trainerId', ASC], ['sessionDate', DESC]]],
  ['soap_notes', [['trainerId', ASC], ['memberUid', ASC], ['sessionDate', DESC]]],
  ['soap_notes', [['memberUid', ASC], ['sessionDate', DESC]]],
  ['postureAssessments', [['trainerId', ASC], ['memberUid', ASC], ['capturedAt', DESC]]],
  ['postureAssessments', [['memberUid', ASC], ['capturedAt', DESC]]],
  ['bodyCompositionRecords', [['trainerId', ASC], ['memberUid', ASC], ['measuredAt', DESC]]],
  ['bodyCompositionRecords', [['memberUid', ASC], ['measuredAt', DESC]]],
  ['circumferenceMeasurements', [['trainerId', ASC], ['memberUid', ASC], ['metricCode', ASC], ['measuredAt', DESC]]],
  ['circumferenceMeasurements', [['memberUid', ASC], ['metricCode', ASC], ['measuredAt', DESC]]],
  ['bodyScans', [['trainerId', ASC], ['memberUid', ASC], ['takenAt', DESC]]],
  ['memberSummaries', [['memberUid', ASC], ['sharedAt', DESC]]],
  ['pendingMembers', [['trainerId', ASC], ['status', ASC], ['createdAt', DESC]]],
  ['consentRecords', [['subjectUid', ASC], ['recordedAt', DESC]]],
  ['consentRecords', [['pendingMemberId', ASC], ['recordedAt', DESC]]],
  ['rightsRequests', [['status', ASC], ['dueAt', ASC]]],
  ['auditLogs', [['memberUid', ASC], ['at', DESC]]],
  ['soap_notes', [['trainerId', ASC], ['pendingMemberId', ASC], ['sessionDate', DESC]]],
  ['postureAssessments', [['trainerId', ASC], ['pendingMemberId', ASC], ['capturedAt', DESC]]],
  ['bodyCompositionRecords', [['trainerId', ASC], ['pendingMemberId', ASC], ['measuredAt', DESC]]],
  ['circumferenceMeasurements', [['trainerId', ASC], ['pendingMemberId', ASC], ['metricCode', ASC], ['measuredAt', DESC]]],
];

function keyOf(collectionGroup, fields, queryScope = 'COLLECTION') {
  return `${collectionGroup}|${queryScope}|${fields.map(([f, o]) => `${f}:${o}`).join(',')}`;
}

function fileKeys() {
  return indexFile.indexes.map((ix) =>
    keyOf(ix.collectionGroup, ix.fields.map((f) => [f.fieldPath, f.order || f.arrayConfig]), ix.queryScope));
}

test('TC-DF024-01 AC-DF-024.1 all 20 v1 composite indexes are present with exact field order', () => {
  const keys = new Set(fileKeys());
  const missing = V1.filter(([c, f]) => !keys.has(keyOf(c, f))).map(([c, f]) => keyOf(c, f));
  assert.deepEqual(missing, []);
  assert.equal(V1.length, 20);
});

test('TC-DF024-01 AC-DF-024.1 the 8 existing clinical indexes are unchanged', () => {
  const keys = new Set(fileKeys());
  const missing = CLINICAL.filter(([c, f]) => !keys.has(keyOf(c, f))).map(([c, f]) => keyOf(c, f));
  assert.deepEqual(missing, []);
});

test('TC-DF024-01 AC-DF-024.2 no duplicate (collectionGroup, scope, fields) and nothing outside the two lists', () => {
  const keys = fileKeys();
  assert.equal(new Set(keys).size, keys.length, 'duplicate composite index');
  const allowed = new Set([...CLINICAL, ...V1].map(([c, f]) => keyOf(c, f)));
  assert.deepEqual(keys.filter((k) => !allowed.has(k)), []);
  assert.equal(keys.length, CLINICAL.length + V1.length);
});

test('TC-DF024-01 every index is a COLLECTION-scope composite of 2+ fields with valid orders', () => {
  for (const ix of indexFile.indexes) {
    assert.equal(ix.queryScope, 'COLLECTION', `${ix.collectionGroup} scope`);
    assert.ok(ix.fields.length >= 2, `${ix.collectionGroup} needs 2+ fields`);
    for (const f of ix.fields) assert.ok([ASC, DESC].includes(f.order), `${ix.collectionGroup}.${f.fieldPath} order`);
  }
  assert.ok(Array.isArray(indexFile.fieldOverrides), 'fieldOverrides array kept');
});

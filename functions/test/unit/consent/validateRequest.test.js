'use strict';

// DF-109 TC-109-03·04 and the MVP gate (V1-06 §6.2.1 schema, §6.2.3 V1·V7·V9·V10, DEC-22). Synthetic values only.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {HttpsError} = require('firebase-functions/v2/https');
const {
  DOCUMENT_VERSION_ID, SELECTION_KEYS, TOP_LEVEL_KEYS, assertMvpScope, validateRequest,
} = require('../../../src/consent/core/validateRequest');

const NOW = Date.UTC(2026, 10, 16, 1, 12, 41);

function request(overrides = {}) {
  return {
    clientCaptureId: '3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90',
    memberKey: {pendingMemberId: 'SYNTHpending00000001'},
    channel: 'trainerDeviceInPerson',
    selections: [
      {consentType: 'required', action: 'grant', documentVersion: 'required--1.0'},
      {consentType: 'healthData', action: 'grant', documentVersion: 'healthData--1.0'},
      {consentType: 'bodyImaging', action: 'grant', documentVersion: 'bodyImaging--test-1'},
    ],
    ...overrides,
  };
}

function rejects(fn, code, messageKey, field) {
  let error;
  try {
    fn();
  } catch (caught) {
    error = caught;
  }
  assert.ok(error instanceof HttpsError, `expected HttpsError, got ${error}`);
  assert.equal(error.code, code);
  assert.equal(error.message, messageKey);
  assert.equal(error.details.messageKey, messageKey);
  if (field !== undefined) assert.deepEqual(error.details.fields, [field]);
}

const validate = (data) => validateRequest(data, NOW);
const invalid = (data, field, key = 'common.invalidArgument') => rejects(() => validate(data), 'invalid-argument', key, field);

test('V1-06 §6.2.1 example request is valid and normalised', () => {
  const result = validate(request({capturedAt: '2026-11-16T01:12:30.000Z', reconfirmOf: null}));
  assert.deepEqual(result, {
    clientCaptureId: '3f2b8c1e-5d7a-4b1e-9a51-0c8e2d7f1a90',
    memberKey: {pendingMemberId: 'SYNTHpending00000001'},
    channel: 'trainerDeviceInPerson',
    selections: request().selections,
    capturedAtMillis: Date.UTC(2026, 10, 16, 1, 12, 30),
    hasSignature: false,
  });
  assert.equal(validate(request()).capturedAtMillis, null);
  assert.equal(validate(request({capturedAt: null, signaturePngBase64: null})).hasSignature, false);
});

test('TC-109-03 V1 duplicate consent type -> invalid-argument consent.duplicateType', () => {
  const selections = [
    {consentType: 'required', action: 'grant', documentVersion: 'required--1.0'},
    {consentType: 'required', action: 'grant', documentVersion: 'required--1.1'},
  ];
  invalid(request({selections}), 'selections[1].consentType', 'consent.duplicateType');
});

test('TC-109-03 schema: unknown keys, bad channel, bad IDs and selection shapes -> invalid-argument with the field', () => {
  invalid(null, 'data');
  invalid(request({extra: true}), 'extra');
  invalid(request({channel: 'kiosk'}), 'channel');
  invalid(request({clientCaptureId: 'short'}), 'clientCaptureId');
  invalid(request({clientCaptureId: 'has space 12345'}), 'clientCaptureId');
  invalid(request({memberKey: {}}), 'memberKey');
  invalid(request({memberKey: {memberUid: 'a', pendingMemberId: 'b'}}), 'memberKey');
  invalid(request({memberKey: {pendingMemberId: 'a/b'}}), 'memberKey.pendingMemberId');
  invalid(request({selections: []}), 'selections');
  invalid(request({selections: 'required'}), 'selections');
  invalid(request({selections: [{consentType: 'required', action: 'grant'}]}), 'selections[0].documentVersion');
  invalid(request({selections: [{consentType: 'other', action: 'grant', documentVersion: 'x--1'}]}),
    'selections[0].consentType');
  invalid(request({selections: [{consentType: 'required', action: 'agree', documentVersion: 'x--1'}]}),
    'selections[0].action');
  invalid(request({selections: [{consentType: 'required', action: 'grant', documentVersion: '..'}]}),
    'selections[0].documentVersion');
  invalid(request({selections: [{consentType: 'required', action: 'grant', documentVersion: 'a/b'}]}),
    'selections[0].documentVersion');
  invalid(request({selections: [{consentType: 'required', action: 'grant', documentVersion: 'x--1', note: 'n'}]}),
    'selections[0].note');
  invalid(request({signaturePngBase64: 12}), 'signaturePngBase64');
  invalid(request({signaturePngBase64: 'A'.repeat(1400001)}), 'signaturePngBase64');
});

test('V10 capturedAt: ISO 8601 only, within now − 7 days .. now + 5 minutes', () => {
  invalid(request({capturedAt: 'yesterday'}), 'capturedAt');
  invalid(request({capturedAt: 1763255550000}), 'capturedAt');
  const iso = (ms) => new Date(ms).toISOString();
  invalid(request({capturedAt: iso(NOW - 7 * 24 * 3600 * 1000 - 1)}), 'capturedAt', 'consent.capturedAtOutOfRange');
  invalid(request({capturedAt: iso(NOW + 5 * 60 * 1000 + 1)}), 'capturedAt', 'consent.capturedAtOutOfRange');
  assert.equal(validate(request({capturedAt: iso(NOW - 7 * 24 * 3600 * 1000)})).capturedAtMillis,
    NOW - 7 * 24 * 3600 * 1000);
  assert.equal(validate(request({capturedAt: '2026-11-16T01:17:41Z'})).capturedAtMillis, NOW + 5 * 60 * 1000);
});

test('V7 ① withdraw -> failed-precondition consent.requiredWithdrawNotSupported', () => {
  rejects(() => validate(request({selections: [{consentType: 'required', action: 'withdraw', documentVersion: 'required--1.0'}]})),
    'failed-precondition', 'consent.requiredWithdrawNotSupported', 'selections[0].action');
});

test('V9 reconfirmOf on the trainer channel -> invalid-argument consent.reconfirmMismatch', () => {
  invalid(request({reconfirmOf: 'SYNTHconsentRec00001'}), 'reconfirmOf', 'consent.reconfirmMismatch');
  invalid(request({reconfirmOf: 7}), 'reconfirmOf');
});

test('TC-109-04 withdraw-only requests need no signature (schema accepts them; the MVP gate is separate)', () => {
  const result = validate(request({selections: [{consentType: 'healthData', action: 'withdraw', documentVersion: 'healthData--1.0'}]}));
  assert.equal(result.hasSignature, false);
});

test('DEC-22 MVP gate: pending member, trainer channel, ①②③ grants without signature pass', () => {
  assert.doesNotThrow(() => assertMvpScope(validate(request())));
});

test('DEC-22 MVP gate: uid member, memberApp, ④⑤, withdraw and signature -> failed-precondition consent.unsupportedInMvp', () => {
  const gate = (data, field) => rejects(() => assertMvpScope(validate(data)),
    'failed-precondition', 'consent.unsupportedInMvp', field);
  gate(request({memberKey: {memberUid: 'synthMember0001'}}), 'memberKey.memberUid');
  gate(request({channel: 'memberApp'}), 'channel');
  gate(request({signaturePngBase64: 'iVBORw0KGgo='}), 'signaturePngBase64');
  gate(request({selections: [
    {consentType: 'required', action: 'grant', documentVersion: 'required--1.0'},
    {consentType: 'sharing', action: 'grant', documentVersion: 'sharing--1.0'},
  ]}), 'selections[1].consentType');
  gate(request({selections: [{consentType: 'research', action: 'grant', documentVersion: 'research--1.0'}]}),
    'selections[0].consentType');
  gate(request({selections: [{consentType: 'bodyImaging', action: 'withdraw', documentVersion: 'bodyImaging--1.0'}]}),
    'selections[0].action');
});

// V1-06 as written: the request schema of §6.2.1 and the common definitions of §3.12, read from the spec itself.
function specJson(heading) {
  const spec = fs.readFileSync(path.resolve(__dirname, '../../../../docs/v1/06_API_SPEC.md'), 'utf8');
  const start = spec.indexOf('```json\n', spec.indexOf(heading)) + '```json\n'.length;
  return JSON.parse(spec.slice(start, spec.indexOf('```', start)));
}

test('V1-06 §6.2.1/§3.12: the accepted keys and the documentVersion pattern are the spec\'s', () => {
  const schema = specJson('#### 6.2.1');
  const common = specJson('### 3.12');
  assert.deepEqual([...TOP_LEVEL_KEYS].sort(), Object.keys(schema.properties).sort());
  const item = schema.properties.selections.items;
  assert.deepEqual([...SELECTION_KEYS].sort(), Object.keys(item.properties).sort());
  assert.equal(item.properties.documentVersion.$ref, 'common#/$defs/ConsentDocumentVersionId');
  assert.equal(DOCUMENT_VERSION_ID.source, common.$defs.ConsentDocumentVersionId.pattern);
  for (const id of ['required--1.0', 'healthData--test-1', 'bodyImaging--2.1.3']) assert.match(id, DOCUMENT_VERSION_ID);
  for (const id of ['.', '..', 'a/b', '', 'x'.repeat(129)]) assert.doesNotMatch(id, DOCUMENT_VERSION_ID);
});

// The trainer app's request as RecordConsentRequest.payload builds it and FunctionsCallableClient sends it (DF-110):
// exactly five keys, a lowercase UUID capture ID, the pending member's 20-character ID, grants in card order and
// capturedAt as ISO 8601 with milliseconds and 'Z'. It passes the schema and the MVP gate as is.
test('DF-110 trainer app payload passes validateRequest and the MVP gate unchanged', () => {
  const capturedAt = new Date(NOW - 90 * 1000).toISOString();
  const payload = {
    clientCaptureId: '9b2f4c1a-7e3d-4f10-8a6b-2c5d7e9f0a1b',
    memberKey: {pendingMemberId: 'Ab3dEf6hIj9kLm2nOp5q'},
    channel: 'trainerDeviceInPerson',
    selections: ['required', 'healthData', 'bodyImaging'].map((consentType) => (
      {consentType, action: 'grant', documentVersion: `${consentType}--test-1`})),
    capturedAt,
  };
  assert.match(capturedAt, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  const normalised = validate(payload);
  assert.equal(normalised.capturedAtMillis, Date.parse(capturedAt));
  assert.equal(normalised.hasSignature, false);
  assert.doesNotThrow(() => assertMvpScope(normalised));
});

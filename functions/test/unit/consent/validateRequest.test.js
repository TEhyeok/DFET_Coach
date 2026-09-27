'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {validateRequest, validateCaptureTime} = require('../../../src/consent/core/validateRequest');

const now = new Date('2026-09-28T00:00:00.000Z');
const request = (overrides = {}) => ({
  memberKey: {pendingMemberId: 'SYNTHpending00000001'},
  clientCaptureId: 'cap_SYNTH_0001', channel: 'trainerDeviceInPerson',
  selections: [{consentType: 'required', action: 'grant', documentVersion: 'required--mvp-test-1'}],
  ...overrides,
});
function invalid(data, key = 'consent.invalidRequest') {
  assert.throws(() => validateRequest(data), error => {
    assert.equal(error.code, 'invalid-argument');
    assert.equal(error.details.messageKey, key);
    assert.equal(error.details.retryable, false);
    return true;
  });
}

test('TC-109-03 DEC-22 accepts pending grants without a signature and canonicalizes selections', () => {
  const data = request({signaturePngBase64: null, reconfirmOf: null, capturedAt: now.toISOString(), selections: [
    {consentType: 'bodyImaging', action: 'grant', documentVersion: 'bodyImaging--mvp-test-1'},
    {consentType: 'required', action: 'grant', documentVersion: 'required--mvp-test-1'},
  ]});
  const normalized = validateRequest(data);
  assert.deepEqual(normalized.selections.map(s => s.consentType), ['required', 'bodyImaging']);
  assert.equal(normalized.capturedAt.toISOString(), now.toISOString());
  assert.equal(validateRequest(request()).capturedAt, null);
});

test('TC-109-03 DEC-22 rejects deferred paths and unknown fields instead of silently dropping them', () => {
  for (const overrides of [
    {memberKey: {memberUid: 'synthMember0001'}},
    {memberKey: {pendingMemberId: 'p', memberUid: 'u'}},
    {channel: 'memberApp'}, {signaturePngBase64: 'iVBORw0KGgo='}, {reconfirmOf: 'old'},
    {extra: true}, {memberKey: {pendingMemberId: 'a/b'}}, {clientCaptureId: 'short'},
    {selections: []}, {selections: [{consentType: 'required', action: 'withdraw', documentVersion: 'v'}]},
    {selections: [{consentType: 'sharing', action: 'grant', documentVersion: 'v'}]},
    {selections: [{consentType: 'research', action: 'grant', documentVersion: 'v'}]},
    {selections: [{consentType: 'required', action: 'grant', documentVersion: 'a/b'}]},
    {selections: [{consentType: 'required', action: 'grant', documentVersion: 'v', extra: true}]},
  ]) invalid(request(overrides));
  invalid(null);
  invalid([]);
  invalid(request({selections: [...request().selections, ...request().selections]}), 'consent.duplicateType');
});

test('AC-DF-109.5 capturedAt must be an ISO instant within seven days past and five minutes future', () => {
  for (const capturedAt of ['tomorrow', '2026-09-28', 12]) invalid(request({capturedAt}));
  for (const offset of [-7 * 86400000, 300000]) {
    validateCaptureTime(new Date(now.getTime() + offset), now);
  }
  for (const offset of [-7 * 86400000 - 1, 300001]) {
    assert.throws(() => validateCaptureTime(new Date(now.getTime() + offset), now),
      error => error.code === 'invalid-argument' && error.details.messageKey === 'consent.captureTimeInvalid');
  }
  validateCaptureTime(null, now);
});

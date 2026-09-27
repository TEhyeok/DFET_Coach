'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {Timestamp} = require('firebase-admin/firestore');
const {derive} = require('../../../src/consent/core/deriveConsentState');

const t = (seconds, nanos = 0) => new Timestamp(seconds, nanos);
const record = (id, consentType, action, recordedAt) => ({
  id, consentType, action, recordedAt, documentVersion: `${consentType}--mvp-test-1`,
});

test('TC-109-01 AC-DF-109.3 derives the newest record per type and omits absent types', () => {
  const prior = {schemaVersion: 1, updatedAt: t(10), required: {
    granted: true, updatedAt: t(10), recordId: 'old', documentVersion: 'required--old',
  }};
  const next = derive(prior, [
    record('new', 'required', 'grant', t(20)),
    record('health', 'healthData', 'grant', t(15)),
    record('older', 'required', 'withdraw', t(5)),
  ]);
  assert.equal(next.required.recordId, 'new');
  assert.equal(next.healthData.granted, true);
  assert.equal('bodyImaging' in next, false);
  assert.equal(next.updatedAt.seconds, 20);
  assert.equal(prior.required.recordId, 'old', 'does not mutate the prior state');
});

test('TC-109-02 AC-DF-109.3 withdrawal wins equal timestamps regardless of record order', () => {
  const grant = record('z-grant', 'healthData', 'grant', t(20));
  const withdrawal = record('a-withdraw', 'healthData', 'withdraw', t(20));
  assert.deepEqual(derive({}, [grant, withdrawal]), derive({}, [withdrawal, grant]));
  assert.equal(derive({}, [grant, withdrawal]).healthData.granted, false);
  const previous = derive({}, [withdrawal]);
  assert.equal(derive(previous, [grant]).healthData.granted, false);
  assert.equal(derive(previous, [record('later', 'healthData', 'grant', t(21))]).healthData.granted, true);
});

test('AC-DF-109.3 timestamp ordering preserves nanoseconds and equal grants are deterministic', () => {
  const older = record('z', 'required', 'grant', t(20, 1));
  const newer = record('a', 'required', 'grant', t(20, 2));
  assert.equal(derive({}, [newer, older]).required.recordId, 'a');
  const equal = record('b', 'required', 'grant', t(20, 2));
  assert.deepEqual(derive({}, [newer, equal]), derive({}, [equal, newer]));
});

'use strict';

// DF-109 TC-109-01·02 (AC-DF-109.3, F-PRIV-02.2): memberConsentStates derivation table tests. Synthetic IDs only.

const assert = require('node:assert/strict');
const test = require('node:test');
const {Timestamp} = require('firebase-admin/firestore');
const {CONSENT_TYPES, derive, toResponseState} = require('../../../src/consent/core/deriveConsentState');

const T0 = Timestamp.fromMillis(Date.UTC(2026, 10, 16, 1, 0, 0));
const T1 = Timestamp.fromMillis(T0.toMillis() + 1000);

function record(consentType, action, recordedAt, recordId = `SYNTHrec_${consentType}_${action}`) {
  return {recordId, consentType, action, documentVersion: `${consentType}--1.0`, recordedAt};
}

function entry(granted, recordId, updatedAt, documentVersion) {
  return {granted, documentVersion, recordId, updatedAt};
}

test('TC-109-01 no stored state: each granted type gets an entry, types without records get no key', () => {
  const next = derive(null, [record('required', 'grant', T0), record('healthData', 'grant', T0)]);
  assert.deepEqual(Object.keys(next), ['required', 'healthData']);
  assert.deepEqual(next.required, entry(true, 'SYNTHrec_required_grant', T0, 'required--1.0'));
  assert.deepEqual(next.healthData, entry(true, 'SYNTHrec_healthData_grant', T0, 'healthData--1.0'));
  assert.equal('bodyImaging' in next, false);
});

test('TC-109-01 derivation of each type ①②③ on its own', () => {
  for (const type of ['required', 'healthData', 'bodyImaging']) {
    const next = derive(null, [record(type, 'grant', T0)]);
    assert.deepEqual(Object.keys(next), [type], type);
    assert.equal(next[type].granted, true, type);
    assert.equal(next[type].documentVersion, `${type}--1.0`, type);
    assert.equal(next[type].updatedAt, T0, type);
  }
});

test('TC-109-01 a newer record replaces the stored entry; untouched stored types are kept', () => {
  const prev = {
    required: entry(true, 'SYNTHrecOld1', T0, 'required--1.0'),
    healthData: entry(false, 'SYNTHrecOld2', T0, 'healthData--1.0'),
    updatedAt: T0,
    schemaVersion: 1,
  };
  const next = derive(prev, [record('healthData', 'grant', T1, 'SYNTHrecNew2')]);
  assert.deepEqual(next, {
    required: entry(true, 'SYNTHrecOld1', T0, 'required--1.0'),
    healthData: entry(true, 'SYNTHrecNew2', T1, 'healthData--1.0'),
  });
});

test('TC-109-01 an older record does not replace a newer stored entry', () => {
  const prev = {bodyImaging: entry(true, 'SYNTHrecStored', T1, 'bodyImaging--2.0')};
  const next = derive(prev, [record('bodyImaging', 'withdraw', T0, 'SYNTHrecLate')]);
  assert.deepEqual(next.bodyImaging, entry(true, 'SYNTHrecStored', T1, 'bodyImaging--2.0'));
});

test('TC-109-02 AC-DF-109.3 same time: withdraw beats grant, in either order and against the stored entry', () => {
  const both = [record('healthData', 'grant', T0, 'SYNTHg'), record('healthData', 'withdraw', T0, 'SYNTHw')];
  assert.equal(derive(null, both).healthData.recordId, 'SYNTHw');
  assert.equal(derive(null, [...both].reverse()).healthData.recordId, 'SYNTHw');

  const storedWithdraw = {healthData: entry(false, 'SYNTHstoredW', T0, 'healthData--1.0')};
  assert.equal(derive(storedWithdraw, [record('healthData', 'grant', T0, 'SYNTHg')]).healthData.recordId, 'SYNTHstoredW');
  const storedGrant = {healthData: entry(true, 'SYNTHstoredG', T0, 'healthData--1.0')};
  const next = derive(storedGrant, [record('healthData', 'withdraw', T0, 'SYNTHw')]);
  assert.deepEqual(next.healthData, entry(false, 'SYNTHw', T0, 'healthData--1.0'));
});

test('derive covers exactly the five consent types and ignores other stored fields', () => {
  assert.deepEqual([...CONSENT_TYPES], ['required', 'healthData', 'bodyImaging', 'sharing', 'research']);
  const next = derive({pendingPurge: {healthData: T0}, updatedAt: T0, schemaVersion: 1}, []);
  assert.deepEqual(next, {});
});

test('toResponseState keeps the five type keys and turns times into ISO 8601 UTC strings', () => {
  const state = {
    required: entry(true, 'SYNTHrec1', T0, 'required--1.0'),
    updatedAt: T0,
    schemaVersion: 1,
  };
  assert.deepEqual(toResponseState(state), {
    required: {granted: true, documentVersion: 'required--1.0', recordId: 'SYNTHrec1', updatedAt: '2026-11-16T01:00:00.000Z'},
  });
  assert.deepEqual(toResponseState(undefined), {});
});

// DF-203: contracts/posture-protocol.v1.json passes the meta-schema and the cross checks, the checks reject a
// broken range, a clothing option outside vocab and a schema violation, and the instruction key is a deck key.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { REPO_ROOT } from './helpers.mjs';
import { crossCheckErrors, loadInputs, validateInputs } from '../generate.mjs';

function load() {
  const { loaded, errors } = loadInputs(REPO_ROOT);
  assert.deepEqual(errors, []);
  assert.ok(loaded.postureProtocol, 'posture protocol is a registered input');
  return loaded;
}

function withProtocol(loaded, mutate) {
  const doc = structuredClone(loaded.postureProtocol.doc);
  mutate(doc);
  return { ...loaded, postureProtocol: { ...loaded.postureProtocol, doc } };
}

test('DF-203 posture protocol passes the meta-schema and the cross checks', () => {
  const loaded = load();
  assert.deepEqual(validateInputs(REPO_ROOT, loaded), []);
});

test('DF-203 the cross checks reject an unordered range and a clothing option outside vocab', () => {
  const loaded = load();
  const cases = [
    [(d) => { d.cameraHeightCm = { min: 110, max: 90 }; }, /cameraHeightCm: min must be below max/],
    [(d) => { d.cameraDistanceM = { min: 3, max: 3 }; }, /cameraDistanceM: min must be below max/],
    [(d) => { d.clothingOptions = ['fitted', 'tight']; }, /clothingOptions\/1: "tight" is not in vocab clothing/],
  ];
  for (const [mutate, expected] of cases) {
    const errors = crossCheckErrors(withProtocol(loaded, mutate));
    assert.ok(errors.some((e) => expected.test(e)), `${mutate} -> ${JSON.stringify(errors)}`);
  }
});

test('DF-203 the meta-schema rejects a malformed protocol', () => {
  const loaded = load();
  const cases = [
    (d) => { d.protocolVersion = 'v1'; },
    (d) => { d.levelToleranceDeg = 0; },
    (d) => { d.standardInstructionKey = 'tr07.'; },
    (d) => { d.standardInstructionKey = 'tr07..stand'; },
    (d) => { d.extra = true; },
    (d) => { delete d.clothingOptions; },
  ];
  for (const mutate of cases) {
    assert.notDeepEqual(validateInputs(REPO_ROOT, withProtocol(loaded, mutate)), [], mutate.toString());
  }
});

test('DF-203 standardInstructionKey is a copy deck key', () => {
  const { doc } = load().postureProtocol;
  const deck = JSON.parse(readFileSync(join(REPO_ROOT, 'docs/v1/data/copy_ko.json'), 'utf8'));
  assert.ok(deck.strings[doc.standardInstructionKey], `${doc.standardInstructionKey} is not in copy_ko.json`);
});

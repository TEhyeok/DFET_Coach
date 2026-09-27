// DF-201 AC-DF-201.9: contracts/vectors/posture-metrics.v1.json passes the meta-schema and the cross checks, and the
// checks reject a wrong code. The values themselves are verified by the Swift PostureMetricVectorTests.
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { REPO_ROOT } from './helpers.mjs';
import { loadInputs, validateInputs } from '../generate.mjs';

function load() {
  const { loaded, errors } = loadInputs(REPO_ROOT);
  assert.deepEqual(errors, []);
  assert.ok(loaded.postureMetricVectors, 'posture vectors are a registered input');
  return loaded;
}

function withCase(loaded, mutate) {
  const doc = structuredClone(loaded.postureMetricVectors.doc);
  mutate(doc);
  return { ...loaded, postureMetricVectors: { ...loaded.postureMetricVectors, doc } };
}

test('AC-DF-201.9 posture vectors pass the meta-schema and cross checks with PM-01..PM-24', () => {
  const loaded = load();
  assert.deepEqual(validateInputs(REPO_ROOT, loaded), []);
  const ids = loaded.postureMetricVectors.doc.cases.map((c) => c.id);
  assert.deepEqual(ids, Array.from({ length: 24 }, (_, i) => `PM-${String(i + 1).padStart(2, '0')}`));
});

test('AC-DF-201.9 an unknown landmark, metric or side and a duplicate id are rejected', () => {
  const loaded = load();
  const cases = [
    (d) => { d.cases[0].landmarks[0].code = 'c8'; },
    (d) => { d.cases[0].expected[0].metricCode = 'headForwardDistance'; },
    (d) => { d.cases[1].expected[0].side = 'up'; },
    (d) => { d.cases[1].id = 'PM-01'; },
    (d) => { d.cases[0].landmarks[0].x = 1.5; },
  ];
  for (const mutate of cases) {
    assert.notDeepEqual(validateInputs(REPO_ROOT, withCase(loaded, mutate)), [], mutate.toString());
  }
});

test('AC-DF-201.9 the meta-schema requires expected or expectedError on a metrics case', () => {
  const loaded = load();
  const errors = validateInputs(REPO_ROOT, withCase(loaded, (d) => { delete d.cases[0].expected; }));
  assert.ok(errors.length > 0);
});

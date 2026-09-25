// TC-DF003-03: key and value hygiene for the two DF-003 contracts
// (PRD appendix A operating rule "키는 영문 camelCase만", ADR-009 "no MDC constants on clients").
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readContract, readContractText, walk, HANGUL } from './helpers.mjs';

const FILES = ['metric-catalog.v1.json', 'vocab.v1.json'];

// The only numeric leaves allowed. Anything else numeric (e.g. an MDC value) fails.
const NUMERIC_KEYS = new Set(['version', 'revision', 'decimals', 'min', 'max', 'appMin']);

// Where Korean text may live: metric nameKo and vocab labelsKo values (V1-05 §13 공통 규칙).
function hangulAllowedAt(trail) {
  const keys = trail.filter((k) => typeof k === 'string');
  return keys.at(-1) === 'nameKo' || keys.at(-2) === 'labelsKo';
}

// Yields [trail, string] for every string leaf, including strings inside arrays.
function* stringLeaves(node, trail = []) {
  if (typeof node === 'string') {
    yield [trail, node];
  } else if (Array.isArray(node)) {
    for (const [i, item] of node.entries()) yield* stringLeaves(item, [...trail, i]);
  } else if (node !== null && typeof node === 'object') {
    for (const [k, v] of Object.entries(node)) yield* stringLeaves(v, [...trail, k]);
  }
}

for (const file of FILES) {
  const doc = readContract(file);

  test(`AC-DF-003.5 ${file}: no Korean keys; keys are ASCII`, () => {
    const bad = [];
    walk(doc, (trail, key) => {
      if (typeof key !== 'string') return;
      if (HANGUL.test(key) || !/^[\x21-\x7E]+$/.test(key)) bad.push(trail.join('.'));
    });
    assert.deepEqual(bad, []);
  });

  test(`AC-DF-003.5 ${file}: no MDC numbers or mdc* fields`, () => {
    const bad = [];
    walk(doc, (trail, key, value) => {
      if (typeof key !== 'string') return;
      const inEnumNames = trail.length === 2 && trail[0] === 'enums';
      if (/^mdc/i.test(key) && !(inEnumNames && key === 'mdcSource')) bad.push(`mdc key ${trail.join('.')}`);
      if (typeof value === 'number' && !NUMERIC_KEYS.has(key)) bad.push(`numeric ${trail.join('.')}=${value}`);
    });
    assert.deepEqual(bad, []);
  });

  test(`AC-DF-003.5 ${file}: no literature URLs or DOIs`, () => {
    const text = readContractText(file);
    assert.doesNotMatch(text, /https?:\/\//i);
    assert.doesNotMatch(text, /\bwww\./i);
    assert.doesNotMatch(text, /\bdoi\b|10\.\d{4,}\//i);
  });

  test(`AC-DF-003.5 ${file}: Korean text only inside nameKo / labelsKo values`, () => {
    const bad = [];
    for (const [trail, value] of stringLeaves(doc)) {
      if (HANGUL.test(value) && !hangulAllowedAt(trail)) bad.push(trail.join('.'));
    }
    assert.deepEqual(bad, []);
  });

  test(`AC-DF-003.5 ${file}: LF line endings, 2-space indent, trailing newline`, () => {
    const text = readContractText(file);
    assert.ok(!text.includes('\r'), 'no CR');
    assert.ok(text.endsWith('}\n'), 'ends with a single newline');
    assert.equal(text, `${JSON.stringify(doc, null, 2)}\n`, 'canonical JSON.stringify(doc, null, 2) formatting');
  });
}

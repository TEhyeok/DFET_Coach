// TC-12-LN-07: 문구 덱 전체가 대상별 규칙 세트로 위반 0건, 키 정규식·중복 0(docs/v1/12 §4.1, §4.2, §7.7, §7.11).
// 금지어 린트의 보고 모드(DF-040 전)와 무관하게 덱은 여기서 차단한다: 회원이 읽는 shared 문장은 트레이너 카탈로그에서
// 트레이너 세트만 받기 때문이다(§4.7-3).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { AUDIENCE_RULESETS, DECK_FILE, formatViolation, lintSource, loadRules } from '../prohibited-terms.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const raw = readFileSync(path.join(ROOT, DECK_FILE), 'utf8');
const deck = JSON.parse(raw);

test('TC-12-LN-07 the whole deck has no violation under its audience rule sets', () => {
  const violations = lintSource(DECK_FILE, raw, loadRules(ROOT));
  assert.deepEqual(violations.map(formatViolation), []);
});

test('TC-12-LN-07 every audience is one of §4.2 and the deck header lists the same rule sets', () => {
  for (const [key, entry] of Object.entries(deck.strings)) {
    assert.ok(Object.hasOwn(AUDIENCE_RULESETS, entry.audience), `${key}: audience ${entry.audience}`);
  }
  const header = Object.fromEntries(Object.entries(deck.audiences).map(([a, v]) => [a, v.ruleSets]));
  assert.deepEqual(header, AUDIENCE_RULESETS);
});

test('TC-12-LN-07 keys match the key pattern and none is written twice', () => {
  const pattern = new RegExp(deck.keyPattern);
  for (const key of Object.keys(deck.strings)) assert.match(key, pattern);
  // JSON.parse keeps the last of two equal keys, so count each key as written in the file.
  for (const key of Object.keys(deck.strings)) {
    const written = raw.split(`${JSON.stringify(key)}:`).length - 1;
    assert.equal(written, 1, `${key} is written ${written} times`);
  }
});

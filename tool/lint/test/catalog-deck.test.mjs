// The trainer catalog follows the copy deck (docs/v1/12 §4.3, §4.4, §4.7). Synthetic entries only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  BASELINE_FILE, CATALOG_FILE, DECK_FILE, DOC_FILE, addKeys, catalogErrors, catalogValue, deckErrors, formatCatalog,
  readBaseline, tableErrors, tableRows,
} from '../catalog-deck.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const read = (file) => JSON.parse(readFileSync(path.join(ROOT, file), 'utf8'));

function entry(value, comment = 'V1-12 · 합성') {
  return { comment, extractionState: 'manual', localizations: { ko: { stringUnit: { state: 'translated', value } } } };
}

const deck = {
  strings: {
    'fx.one': { ko: '대기 {count}건', audience: 'trainer', args: ['count'], prdRefs: ['§8.4'] },
    'fx.two': { ko: '{name} · 높이 {height}cm', audience: 'trainer', args: ['name', 'height'], prdRefs: [] },
    'fx.ratio': { ko: '선택 {selected}/{total} (100%)', audience: 'trainer', args: ['selected', 'total'], prdRefs: [] },
    'fx.n': { ko: '{n}회', audience: 'trainer', args: ['n'], prdRefs: [] },
    'fx.plain': { ko: '합성 문장', audience: 'shared', prdRefs: [] },
    'fx.member': { ko: '회원 문장', audience: 'member', prdRefs: [] },
  },
};

test('the repository catalog follows the deck, the §4.9 tables match it and its placeholders match args', () => {
  const realDeck = read(DECK_FILE);
  assert.deepEqual(deckErrors(realDeck), []);
  const doc = readFileSync(path.join(ROOT, DOC_FILE), 'utf8');
  assert.deepEqual(tableErrors(realDeck, doc, readBaseline(path.join(ROOT, BASELINE_FILE))), []);
  assert.ok(tableRows(doc).length > 700, 'the §4.9 tables were read');
  assert.deepEqual(catalogErrors(realDeck, read(CATALOG_FILE)), []);
});

test('a §4.9 row without a deck entry, with other text or another audience fails', () => {
  const doc = [
    '### 4.9 문구 키 전체 목록', '',
    '| 키 | 문구(ko) | 대상 | 단계 | 근거 | 메모 |', '|---|---|---|---|---|---|',
    '| `fx.plain` | 합성 문장 | shared | P0 | - |  |',
    '| `fx.gone` | 없는 행 | trainer | P0 | - |  |',
    '| `fx.one` | 대기 {n}건 | trainer | P0 | - |  |',
    '| `fx.member` | 회원 문장 | trainer | P0 | - |  |',
    '', '## 5 다음 절', '| `fx.outside` | 표 밖 | trainer | P0 | - |  |',
  ].join('\n');
  const errors = tableErrors(deck, doc);
  assert.equal(errors.length, 3, JSON.stringify(errors));
  assert.deepEqual(tableErrors(deck, doc.replace('### 4.9', '### 4.10')), [`${DOC_FILE}: section "### 4.9" not found`]);
  const malformed = doc.replace('| `fx.plain` | 합성 문장 | shared | P0 |', '| `fx.plain` | 합성 문장 | shared | p0 |');
  assert.ok(tableErrors(deck, malformed).some((e) => /row does not parse/.test(e)), 'an unparsable row fails');
  assert.ok(errors.some((e) => /fx.gone: row has no deck entry/.test(e)));
  assert.ok(errors.some((e) => /fx.one: .* ≠ deck/.test(e)));
  assert.ok(errors.some((e) => /fx.member: audience trainer ≠ deck member/.test(e)));
});

test('integer arguments become %lld and the rest %@, numbered when there are two or more (V1-12 §4.3)', () => {
  assert.equal(catalogValue(deck.strings['fx.one']), '대기 %lld건');
  assert.equal(catalogValue(deck.strings['fx.n']), '%lld회');
  assert.equal(catalogValue(deck.strings['fx.two']), '%1$@ · 높이 %2$@cm');
  assert.equal(catalogValue(deck.strings['fx.ratio']), '선택 %1$lld/%2$lld (100%%)', 'a literal % is escaped');
  const ok = { sourceLanguage: 'ko', strings: { 'fx.one': entry('대기 %lld건'), 'fx.two': entry('%1$@ · 높이 %2$@cm') } };
  assert.deepEqual(catalogErrors(deck, ok), []);
});

test('a specifier of the wrong type fails: String(format:) with %@ and an Int crashes', () => {
  for (const value of ['대기 %@건', '대기 %d건']) {
    const errors = catalogErrors(deck, { sourceLanguage: 'ko', strings: { 'fx.one': entry(value) } });
    assert.ok(errors.some((e) => /≠ deck/.test(e)), value);
  }
});

test('catalog entries are ko only, translated, without variations, in a ko catalog', () => {
  const extra = entry('합성 문장');
  extra.localizations.en = { stringUnit: { state: 'translated', value: 'x' } };
  const review = entry('합성 문장');
  review.localizations.ko.stringUnit.state = 'needs_review';
  const varied = entry('합성 문장');
  varied.localizations.ko.variations = { device: {} };
  const cases = [
    [{ sourceLanguage: 'ko', strings: { 'fx.plain': extra } }, /only a ko localization/],
    [{ sourceLanguage: 'ko', strings: { 'fx.plain': review } }, /state must be translated/],
    [{ sourceLanguage: 'ko', strings: { 'fx.plain': varied } }, /variations are not allowed/],
    [{ sourceLanguage: 'en', strings: {} }, /sourceLanguage must be ko/],
    [{ sourceLanguage: 'ko', strings: { 'fx.plain': entry('합성 문장', 'V1-120 · x') } }, /comment must start/],
  ];
  for (const [catalog, pattern] of cases) {
    assert.ok(catalogErrors(deck, catalog).some((e) => pattern.test(e)), pattern.toString());
  }
});

test('a key outside the deck, a changed sentence, unnumbered placeholders, a member key and a bad comment fail', () => {
  const cases = [
    [{ 'fx.missing': entry('없는 키') }, /not in the deck/],
    [{ 'fx.plain': entry('바뀐 문장') }, /≠ deck/],
    [{ 'fx.two': entry('%@ · 높이 %@cm') }, /≠ deck/],
    [{ 'fx.member': entry('회원 문장') }, /audience member/],
    [{ 'fx.plain': entry('합성 문장', 'DF-017') }, /comment must start/],
  ];
  for (const [strings, pattern] of cases) {
    const errors = catalogErrors(deck, { sourceLanguage: 'ko', strings });
    assert.ok(errors.some((e) => pattern.test(e)), `${JSON.stringify(strings)} -> ${JSON.stringify(errors)}`);
  }
});

test('a deck key without a §4.9 row fails unless baselined, and a stale baseline entry fails', () => {
  const doc = ['### 4.9 x', '| `fx.plain` | 합성 문장 | shared | P0 | - |  |', '## 5 y'].join('\n');
  const small = { strings: { 'fx.plain': deck.strings['fx.plain'], 'fx.n': deck.strings['fx.n'] } };
  assert.ok(tableErrors(small, doc, new Set()).some((e) => /fx.n has no row/.test(e)));
  assert.deepEqual(tableErrors(small, doc, new Set(['fx.n'])), []);
  assert.ok(tableErrors(small, doc, new Set(['fx.n', 'fx.plain'])).some((e) => /fx.plain has a §4.9 row now/.test(e)));
});

test('deck text and args must name the same placeholders', () => {
  const bad = { strings: { 'fx.bad': { ko: '{name}님 {count}건', audience: 'trainer', args: ['count'] } } };
  assert.equal(deckErrors(bad).length, 1);
});

test('--add copies the deck sentence and refuses keys that are not for the app', () => {
  const catalog = addKeys(deck, { sourceLanguage: 'ko', strings: {} }, ['fx.two']);
  assert.equal(catalog.strings['fx.two'].localizations.ko.stringUnit.value, '%1$@ · 높이 %2$@cm');
  assert.match(catalog.strings['fx.two'].comment, /^V1-12 · args: name, height$/);
  assert.throws(() => addKeys(deck, { strings: {} }, ['fx.member']), /audience member/);
  assert.throws(() => addKeys(deck, { strings: {} }, ['fx.none']), /not in/);
});

test('the writer keeps Xcode\'s layout, so an unchanged catalog round-trips byte for byte', () => {
  const raw = readFileSync(path.join(ROOT, CATALOG_FILE), 'utf8');
  assert.equal(formatCatalog(JSON.parse(raw)), raw);
});

#!/usr/bin/env node
// 트레이너 앱 문자열 카탈로그가 문구 덱을 따르는지 검사하고, 덱 키를 카탈로그로 옮겨 적는다. docs/v1/12 §4.3, §4.4,
// §4.7(ASM-12-22 `--check-deck`의 차단판). Node 22 내장 모듈만 쓴다.
//
// 사용법:
//   node tool/lint/catalog-deck.mjs [--check] [--root <dir>]      검사(기본)
//   node tool/lint/catalog-deck.mjs --add <key>... [--root <dir>]   덱 키를 카탈로그에 추가(값은 덱 문장 그대로)
//
// 검사 항목(모두 차단):
// - 카탈로그의 모든 키가 덱(docs/v1/data/copy_ko.json)에 있다. 덱이 정본이고 카탈로그에만 있는 키는 금지(§1, §4.7).
// - 대상(audience)이 trainer 또는 shared다(회원·관리자·동의 초안 문장은 트레이너 앱에 넣지 않는다).
// - 값이 덱 문장과 같다. 자리표시자는 덱의 `{name}`이 인자 하나면 `%@`(또는 `%lld`), 둘 이상이면 `args` 순서대로
//   `%1$@`, `%2$@`…(또는 `%1$lld`…)다(§4.3).
// - 주석이 `V1-12`로 시작한다(카탈로그 주석 규칙, §4.4).
// - 덱 전체: 문장의 `{name}` 자리표시자 집합이 `args`와 같다.
// - 이 문서 §4.9 표의 모든 행(`| \`키\` | 문구 | 대상 | 단계 |`)이 덱에 같은 문구·대상으로 있다. 덱에만 있고 표에 행이
//   없는 키는 개수만 알린다(기존 드리프트, 차단하지 않음).
// 종료 코드: 0 = 통과, 1 = 위반, 2 = 사용법·파일 오류.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const DECK_FILE = 'docs/v1/data/copy_ko.json';
export const CATALOG_FILE = 'trainer_app/App/Resources/Localizable.xcstrings';
export const DOC_FILE = 'docs/v1/12_COPY_ANALYTICS_AND_LINT.md';
const APP_AUDIENCES = new Set(['trainer', 'shared']);

/** Deck text with its `{name}` placeholders replaced by catalog format specifiers. */
export function catalogValue(entry) {
  const args = entry.args ?? [];
  let value = entry.ko;
  args.forEach((arg, i) => {
    const spec = arg === 'count' ? 'lld' : '@';
    value = value.replaceAll(`{${arg}}`, args.length === 1 ? `%${spec}` : `%${i + 1}$${spec}`);
  });
  return value;
}

/** `%lld` and `%@` are both accepted for an argument; compare with the integer form folded into `%@`. */
function normalize(value) {
  return value.replace(/%(\d+\$)?lld/g, (_, pos) => `%${pos ?? ''}@`);
}

function placeholders(text) {
  return new Set([...text.matchAll(/\{([A-Za-z][A-Za-z0-9]*)\}/g)].map((m) => m[1]));
}

export function deckErrors(deck) {
  const errors = [];
  for (const [key, entry] of Object.entries(deck.strings)) {
    const used = placeholders(entry.ko);
    const args = new Set(entry.args ?? []);
    const same = used.size === args.size && [...used].every((a) => args.has(a));
    if (!same) errors.push(`${DECK_FILE} ${key}: placeholders {${[...used].join(', ')}} ≠ args [${[...args].join(', ')}]`);
  }
  return errors;
}

/** Rows of the §4.9 key tables: key, text, audience. */
export function tableRows(doc) {
  const start = doc.indexOf('### 4.9');
  if (start < 0) return [];
  const next = doc.indexOf('\n## ', start);
  const section = doc.slice(start, next < 0 ? undefined : next);
  return [...section.matchAll(/^\| `([a-z][A-Za-z0-9.]*)` \| (.*?) \| (\w+) \| P\w+ \|/gm)]
    .map(([, key, text, audience]) => ({ key, text: text.trim(), audience }));
}

export function tableErrors(deck, doc) {
  const errors = [];
  for (const row of tableRows(doc)) {
    const d = deck.strings[row.key];
    const where = `${DOC_FILE} §4.9 ${row.key}`;
    if (!d) errors.push(`${where}: row has no deck entry`);
    else if (d.ko !== row.text) errors.push(`${where}: "${row.text}" ≠ deck "${d.ko}"`);
    else if (d.audience !== row.audience) errors.push(`${where}: audience ${row.audience} ≠ deck ${d.audience}`);
  }
  return errors;
}

export function catalogErrors(deck, catalog) {
  const errors = [];
  for (const [key, entry] of Object.entries(catalog.strings)) {
    const where = `${CATALOG_FILE} ${key}`;
    const d = deck.strings[key];
    if (!d) {
      errors.push(`${where}: not in the deck (add it to ${DECK_FILE} first, V1-12 §4.7)`);
      continue;
    }
    if (!APP_AUDIENCES.has(d.audience)) errors.push(`${where}: deck audience ${d.audience} is not for the trainer app`);
    const value = entry.localizations?.ko?.stringUnit?.value;
    if (typeof value !== 'string') {
      errors.push(`${where}: no ko value`);
      continue;
    }
    const expected = catalogValue(d);
    if (normalize(value) !== normalize(expected)) errors.push(`${where}: "${value}" ≠ deck "${expected}"`);
    if (!(entry.comment ?? '').startsWith('V1-12')) errors.push(`${where}: comment must start with "V1-12"`);
  }
  return errors;
}

function sortDeep(value) {
  if (Array.isArray(value)) return value.map(sortDeep);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((k) => [k, sortDeep(value[k])]));
  }
  return value;
}

/** Xcode's `.xcstrings` layout: two-space indent, sorted keys, `"key" : value`. */
export function formatCatalog(catalog) {
  return `${JSON.stringify(sortDeep(catalog), null, 2).replace(/^(\s*"(?:[^"\\]|\\.)*"): /gm, '$1 : ')}\n`;
}

export function addKeys(deck, catalog, keys) {
  for (const key of keys) {
    const d = deck.strings[key];
    if (!d) throw new Error(`${key} is not in ${DECK_FILE}`);
    if (!APP_AUDIENCES.has(d.audience)) throw new Error(`${key}: audience ${d.audience} is not for the trainer app`);
    const refs = (d.prdRefs ?? []).join(', ');
    const args = d.args?.length ? ` · args: ${d.args.join(', ')}` : '';
    catalog.strings[key] = {
      comment: `V1-12${refs ? ` · ${refs}` : ''}${args}`,
      extractionState: 'manual',
      localizations: { ko: { stringUnit: { state: 'translated', value: catalogValue(d) } } },
    };
  }
  return catalog;
}

function main(argv) {
  let root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  const keys = [];
  let add = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--root') root = path.resolve(argv[(i += 1)]);
    else if (arg === '--add') add = true;
    else if (arg === '--check') add = false;
    else if (add && !arg.startsWith('--')) keys.push(arg);
    else {
      console.error(`catalog-deck: unknown argument ${arg}`);
      return 2;
    }
  }
  let deck;
  let catalog;
  let doc;
  try {
    deck = JSON.parse(readFileSync(path.join(root, DECK_FILE), 'utf8'));
    catalog = JSON.parse(readFileSync(path.join(root, CATALOG_FILE), 'utf8'));
    doc = readFileSync(path.join(root, DOC_FILE), 'utf8');
  } catch (error) {
    console.error(`catalog-deck: ${error.message}`);
    return 2;
  }
  if (add) {
    try {
      addKeys(deck, catalog, keys);
    } catch (error) {
      console.error(`catalog-deck: ${error.message}`);
      return 2;
    }
    writeFileSync(path.join(root, CATALOG_FILE), formatCatalog(catalog));
    console.log(`catalog-deck: added ${keys.length} key(s)`);
    return 0;
  }
  const errors = [...deckErrors(deck), ...tableErrors(deck, doc), ...catalogErrors(deck, catalog)];
  for (const error of errors) console.log(error);
  const rows = new Set(tableRows(doc).map((r) => r.key));
  const unlisted = Object.keys(deck.strings).filter((k) => !rows.has(k));
  if (unlisted.length) console.log(`catalog-deck: note: ${unlisted.length} deck key(s) have no §4.9 row (not blocking)`);
  console.log(`catalog-deck: ${Object.keys(catalog.strings).length} catalog key(s), ${errors.length} violation(s)`);
  return errors.length ? 1 : 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) process.exit(main(process.argv.slice(2)));

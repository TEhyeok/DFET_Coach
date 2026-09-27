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
// - 값이 덱 문장과 **정확히** 같다. 자리표시자는 §4.3대로 정수 인자(`{count}`, `{n}`, `{selected}`, `{total}`)는
//   `%lld`, 그 밖은 `%@`이고, 인자가 둘 이상이면 `args` 순서대로 번호를 붙인다(`%1$@`, `%2$lld`…). 형식 문자열의
//   문자 `%`는 `%%`다. 형식 종류가 다르면 `String(format:)`이 앱을 죽일 수 있어 같은 값으로 보지 않는다.
// - 항목은 ko 하나, `stringUnit.state == translated`, 변형(variations) 없음, 카탈로그 `sourceLanguage == ko`다.
// - 주석이 `V1-12 · ` 또는 정확히 `V1-12`로 시작한다(카탈로그 주석 규칙, §4.4).
// - 덱 전체: 문장의 `{name}` 자리표시자 집합이 `args`와 같다.
// - 이 문서 §4.9 표의 모든 행(`| \`키\` | 문구 | 대상 | 단계 |`)이 덱에 같은 문구·대상으로 있다. §4.9가 없거나,
//   `| \`` 로 시작하는데 행 형식이 아닌 줄이 있으면 실패한다(검사 없이 통과하지 않게).
// - 덱 키는 §4.9에 행이 있어야 한다. 이 도구 도입 전부터 행이 없던 키는 `catalog-deck.baseline`에 적혀 있고
//   (행을 더하면 그 줄을 지운다), 거기 없는 새 키는 실패한다.
// 종료 코드: 0 = 통과, 1 = 위반, 2 = 사용법·파일 오류.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const DECK_FILE = 'docs/v1/data/copy_ko.json';
export const CATALOG_FILE = 'trainer_app/App/Resources/Localizable.xcstrings';
export const DOC_FILE = 'docs/v1/12_COPY_ANALYTICS_AND_LINT.md';
export const BASELINE_FILE = 'tool/lint/catalog-deck.baseline';
/// V1-12 §4.3: these argument names are integers (`%lld`).
export const INT_ARGS = new Set(['count', 'n', 'selected', 'total']);
const APP_AUDIENCES = new Set(['trainer', 'shared']);

/** Deck text with its `{name}` placeholders replaced by catalog format specifiers. */
export function catalogValue(entry) {
  const args = entry.args ?? [];
  let value = args.length ? entry.ko.replaceAll('%', '%%') : entry.ko;
  args.forEach((arg, i) => {
    const spec = INT_ARGS.has(arg) ? 'lld' : '@';
    value = value.replaceAll(`{${arg}}`, args.length === 1 ? `%${spec}` : `%${i + 1}$${spec}`);
  });
  return value;
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

const ROW = /^\| `([a-z][A-Za-z0-9.]*)` \| (.*?) \| (\w+) \| (P\w+) \|/;

/** §4.9: the key tables' rows, and lines that look like rows but do not parse. null when §4.9 is missing. */
export function tableSection(doc) {
  const heading = /^### 4\.9 /m.exec(doc);
  if (!heading) return null;
  const start = heading.index;
  const next = doc.indexOf('\n## ', start + 1);
  const lines = doc.slice(start, next < 0 ? undefined : next).split('\n');
  const rows = [];
  const malformed = [];
  for (const line of lines) {
    if (!line.startsWith('| `')) continue;
    const m = ROW.exec(line);
    if (m) rows.push({ key: m[1], text: m[2].trim(), audience: m[3] });
    else malformed.push(line.slice(0, 80));
  }
  return { rows, malformed };
}

export function tableRows(doc) {
  return tableSection(doc)?.rows ?? [];
}

export function tableErrors(deck, doc, baseline = null) {
  const section = tableSection(doc);
  if (!section) return [`${DOC_FILE}: section "### 4.9" not found`];
  const errors = section.malformed.map((line) => `${DOC_FILE} §4.9: row does not parse: ${line}`);
  if (baseline) {
    const listed = new Set(section.rows.map((r) => r.key));
    for (const key of Object.keys(deck.strings)) {
      if (!listed.has(key) && !baseline.has(key)) errors.push(`${DOC_FILE} §4.9: ${key} has no row (V1-12 §4.7 step 1)`);
    }
    for (const key of baseline) {
      if (listed.has(key)) errors.push(`${BASELINE_FILE}: ${key} has a §4.9 row now; delete its baseline line`);
      if (!deck.strings[key]) errors.push(`${BASELINE_FILE}: ${key} is not in the deck; delete its baseline line`);
    }
  }
  for (const row of section.rows) {
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
  if (catalog.sourceLanguage !== 'ko') errors.push(`${CATALOG_FILE}: sourceLanguage must be ko`);
  for (const [key, entry] of Object.entries(catalog.strings)) {
    const where = `${CATALOG_FILE} ${key}`;
    const d = deck.strings[key];
    if (!d) {
      errors.push(`${where}: not in the deck (add it to ${DECK_FILE} first, V1-12 §4.7)`);
      continue;
    }
    if (!APP_AUDIENCES.has(d.audience)) errors.push(`${where}: deck audience ${d.audience} is not for the trainer app`);
    const locales = Object.keys(entry.localizations ?? {});
    if (locales.length !== 1 || locales[0] !== 'ko') errors.push(`${where}: only a ko localization is allowed`);
    const ko = entry.localizations?.ko ?? {};
    if (ko.variations) errors.push(`${where}: variations are not allowed`);
    const value = ko.stringUnit?.value;
    if (typeof value !== 'string') {
      errors.push(`${where}: no ko value`);
      continue;
    }
    if (ko.stringUnit.state !== 'translated') errors.push(`${where}: state must be translated`);
    const expected = catalogValue(d);
    if (value !== expected) errors.push(`${where}: "${value}" ≠ deck "${expected}"`);
    if (!/^V1-12( · |$)/.test(entry.comment ?? '')) errors.push(`${where}: comment must start with "V1-12 · "`);
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

/** One key per line; `#` starts a comment. */
export function readBaseline(file) {
  const text = readFileSync(file, 'utf8');
  return new Set(text.split('\n').map((l) => l.replace(/#.*/, '').trim()).filter(Boolean));
}

function main(argv) {
  let root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  const keys = [];
  let add = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--root') {
      const value = argv[(i += 1)];
      if (!value) {
        console.error('catalog-deck: --root needs a directory');
        return 2;
      }
      root = path.resolve(value);
    }
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
  let baseline;
  try {
    deck = JSON.parse(readFileSync(path.join(root, DECK_FILE), 'utf8'));
    catalog = JSON.parse(readFileSync(path.join(root, CATALOG_FILE), 'utf8'));
    doc = readFileSync(path.join(root, DOC_FILE), 'utf8');
    baseline = readBaseline(path.join(root, BASELINE_FILE));
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
  const errors = [...deckErrors(deck), ...tableErrors(deck, doc, baseline), ...catalogErrors(deck, catalog)];
  for (const error of errors) console.log(error);
  if (baseline.size) console.log(`catalog-deck: note: ${baseline.size} baselined deck key(s) still have no §4.9 row`);
  console.log(`catalog-deck: ${Object.keys(catalog.strings).length} catalog key(s), ${errors.length} violation(s)`);
  return errors.length ? 1 : 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) process.exit(main(process.argv.slice(2)));

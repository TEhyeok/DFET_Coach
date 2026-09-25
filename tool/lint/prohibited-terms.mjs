#!/usr/bin/env node
// PRD 부록 C 금지어 린트(copy-lint). DF-010(보고 모드), DF-040(차단 모드). ADR-016, docs/v1/12 §7.
// 규칙 원본은 contracts/prohibited-terms.v1.json이다. Node 22 내장 모듈만 쓴다.
//
// 사용법:
//   node tool/lint/prohibited-terms.mjs [--mode=report|block] [--summary <file>] [--root <dir>]
//
// - 검사 대상(AC-DF-010.2): 아래 TARGETS의 문자열 리터럴과 문자열 카탈로그 값. 주석은 읽지 않는다(ASM-P0-07).
//   한글이 없는 문자열은 건너뛴다(docs/v1/12 §7.8).
// - 규칙 세트는 파일 경로의 pathRuleSets 첫 일치로 정한다(ASM-P0-08).
// - 출력: 위반마다 `path:line:col [ruleSet/id] term → 대체어` 한 줄. --summary는 GitHub Step Summary용 표를 덧붙인다.
// - 종료 코드: 0 = report 모드이거나 block 위반 0건, 1 = block 모드에서 severity block 위반 1건 이상,
//   2 = 사용법·규칙 파일 오류. causalPatterns는 두 모드 모두 경고(warn)로만 보고한다(AC-DF-010.3).
import { appendFileSync, existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const RULES_FILE = 'contracts/prohibited-terms.v1.json';
export const MODES = Object.freeze(['report', 'block']);

// AC-DF-010.2 검사 대상. dir 아래를 재귀로 돌며 확장자가 맞는 파일만 읽는다.
export const TARGETS = Object.freeze([
  { dir: 'trainer_app', exts: ['.swift', '.xcstrings'] },
  { dir: 'ios/Runner', exts: ['.swift'] },
  { dir: 'lib', exts: ['.dart'] },
  { dir: 'admin_web/app', exts: ['.ts', '.tsx'] },
  { dir: 'admin_web/components', exts: ['.ts', '.tsx'] },
  { dir: 'admin_web/lib', exts: ['.ts', '.tsx'] },
  { file: 'contracts/metric-catalog.v1.json' },
  { file: 'contracts/vocab.v1.json' },
]);

const HANGUL = /[가-힣ㄱ-ㅎㅏ-ㅣ]/;
const ZERO_WIDTH = new Set(['​', '‌', '‍', '﻿']);
// 보간·이스케이프 자리를 같은 길이로 가리는 문자. 공백이 아니어서 용어 사이 구분자로도 일치하지 않는다.
const MASK = '￼';

// ---------------------------------------------------------------------------------------------
// 경로 글롭

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');

/** `**`는 여러 단계(0단계 포함), `*`는 한 단계 안의 문자열. 저장소 루트 기준 상대 경로에 쓴다. */
export function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i += 1) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      if (glob[i + 2] === '/') {
        re += '(?:.*/)?';
        i += 2;
      } else {
        re += '.*';
        i += 1;
      }
    } else if (c === '*') {
      re += '[^/]*';
    } else {
      re += escapeRe(c);
    }
  }
  return new RegExp(`^${re}$`);
}

const globCache = new Map();
export function matchGlob(glob, rel) {
  if (!globCache.has(glob)) globCache.set(glob, globToRegExp(glob));
  return globCache.get(glob).test(rel);
}

// ---------------------------------------------------------------------------------------------
// 정규화와 일치(docs/v1/12 §7.3)

/**
 * NFC → 제로폭 문자 삭제 → U+3000·U+00A0·공백류를 공백 하나로 모은다.
 * map[i]는 정규화 문자열 i번째 UTF-16 단위의 입력(NFC) 오프셋이다. 입력이 NFC가 아니면 오프셋은 NFC 기준이다.
 */
export function normalize(input) {
  const s = input.normalize('NFC');
  let text = '';
  const map = [];
  let prevSpace = false;
  for (let i = 0; i < s.length; i += 1) {
    const c = s[i];
    if (ZERO_WIDTH.has(c)) continue;
    if (/\s/.test(c)) {
      if (prevSpace) continue;
      text += ' ';
      map.push(i);
      prevSpace = true;
      continue;
    }
    prevSpace = false;
    text += c;
    map.push(i);
  }
  map.push(s.length);
  return { text, map };
}

/** 용어 안의 공백은 선택적이고 · - _ / 구분자도 허용한다('체형 교정' = '체형교정' = '체형·교정'). */
export function termRegExp(term, boundary) {
  const body = term.split(' ').filter(Boolean).map(escapeRe).join('[\\s·\\-_/]*');
  return new RegExp((boundary === 'wordStart' ? '(?<![가-힣A-Za-z0-9])' : '') + body, 'giu');
}

/** 규칙 파일을 읽어 일치에 쓰는 형태로 바꾼다. */
export function compileRules(doc) {
  const sets = {};
  for (const [name, rules] of Object.entries(doc.ruleSets)) {
    sets[name] = rules.map((rule) => ({
      rule,
      patterns: [
        ...rule.terms.map((term) => ({ term, re: termRegExp(term, rule.match?.boundary) })),
        ...(rule.regex ?? []).map((rx) => ({ term: null, re: new RegExp(rx, 'giu') })),
      ],
      except: (rule.match?.except ?? []).map((e) => normalize(e).text),
    }));
  }
  return {
    doc,
    sets,
    causal: doc.causalPatterns.map((p) => ({ pattern: p, re: new RegExp(p.regex, 'gu') })),
    allowEntries: doc.allowEntries
      .filter((e) => e.active)
      .map((e) => ({ ...e, normalized: normalize(e.exactString).text })),
  };
}

function exceptRanges(text, excepts) {
  const ranges = [];
  for (const ex of excepts) {
    for (let at = text.indexOf(ex); at !== -1; at = text.indexOf(ex, at + 1)) ranges.push([at, at + ex.length]);
  }
  return ranges;
}

// 같은 규칙 안에서는 긴 일치에 들어가는 짧은 일치를 버린다('체형 교정'과 그 안의 '교정'은 C1-05 한 건).
// 다른 규칙끼리 겹친 일치는 모두 남긴다('거북목 개선' = C1-11 + C1-13, docs/v1/12 §7.3-7).
function dedupeWithinRule(hits) {
  hits.sort((a, b) => a.start - b.start || b.end - a.end);
  const kept = [];
  for (const h of hits) {
    if (!kept.some((k) => k.start <= h.start && h.end <= k.end)) kept.push(h);
  }
  return kept;
}

function onlyInApplies(onlyIn, { key, file }) {
  if (!onlyIn) return true;
  if (key && onlyIn.keyPrefixes.some((p) => key.startsWith(p))) return true;
  return Boolean(file) && onlyIn.globs.some((g) => matchGlob(g, file));
}

/**
 * 문자열 하나를 검사한다. 돌려주는 hit의 start/end는 입력(NFC) 문자열 기준 오프셋이다.
 * @param {string} input 검사할 문자열
 * @param {object} compiled compileRules 결과
 * @param {{ruleSets: string[], key?: string, file?: string}} ctx 적용할 세트와 onlyIn 판정용 키·경로
 */
export function scanText(input, compiled, { ruleSets, key, file }) {
  if (!HANGUL.test(input)) return [];
  const { text, map } = normalize(input);
  const suppressed = new Set();
  for (const entry of compiled.allowEntries) {
    if (entry.normalized === text) for (const id of entry.rules) suppressed.add(id);
  }
  const hits = [];
  for (const setName of ruleSets) {
    for (const { rule, patterns, except } of compiled.sets[setName] ?? []) {
      if (suppressed.has(rule.id) || !onlyInApplies(rule.onlyIn, { key, file })) continue;
      const excepts = exceptRanges(text, except);
      const ruleHits = [];
      for (const { term, re } of patterns) {
        for (const m of text.matchAll(re)) {
          const [a, b] = [m.index, m.index + m[0].length];
          if (b === a || excepts.some(([s, e]) => s <= a && b <= e)) continue;
          ruleHits.push({ start: a, end: b, term: term ?? m[0] });
        }
      }
      for (const h of dedupeWithinRule(ruleHits)) {
        hits.push({
          start: map[h.start],
          end: map[h.end - 1] + 1,
          match: text.slice(h.start, h.end),
          term: h.term,
          ruleSet: setName,
          ruleId: rule.id,
          severity: rule.severity,
          alternatives: rule.alternatives,
        });
      }
    }
  }
  if (ruleSets.includes('common')) {
    for (const { pattern, re } of compiled.causal) {
      for (const m of text.matchAll(re)) {
        if (m[0].length === 0) continue;
        hits.push({
          start: map[m.index],
          end: map[m.index + m[0].length - 1] + 1,
          match: m[0],
          term: m[0],
          ruleSet: 'causal',
          ruleId: pattern.id,
          severity: 'warn', // AC-DF-010.3: 두 모드 모두 경고만
          alternatives: [pattern.allowedExample],
        });
      }
    }
  }
  return hits.sort((a, b) => a.start - b.start || a.ruleId.localeCompare(b.ruleId));
}

// ---------------------------------------------------------------------------------------------
// 추출기(docs/v1/12 §7.8). 코드 파일 항목은 {text, origin}: text는 원문 조각을 그대로(보간·제어 이스케이프는 같은
// 길이의 MASK/공백으로 가림) 담아 origin + i가 원문 오프셋이다. JSON 항목은 {text, line, col, key?}다.

const isIdent = (c) => c !== undefined && /[A-Za-z0-9_$]/.test(c);

/**
 * 따옴표 문자열 하나를 읽는다(여는 따옴표 뒤 위치 i부터). 보간은 MASK로, 제어 이스케이프(\n \t \r)는 공백 두 칸으로
 * 바꿔 길이를 원문과 같게 둔다.
 * opts: quote(닫는 구분자), multiline, raw, interp: 'swift' | 'dart' | 'js' | null, lang(중첩 코드 스캔용)
 * 돌려주는 값: {end: 닫는 구분자 뒤 위치, text, items: 보간 안에서 찾은 중첩 리터럴}
 */
function readString(src, i, opts) {
  const { quote, multiline, raw, interp, lang } = opts;
  const parts = [];
  const nested = [];
  let segStart = i;
  const n = src.length;
  while (i < n) {
    if (src.startsWith(quote, i)) {
      parts.push(src.slice(segStart, i));
      return { end: i + quote.length, text: parts.join(''), items: nested };
    }
    const c = src[i];
    if (c === '\n' && !multiline) break; // 닫히지 않은 한 줄 문자열: 줄 끝에서 멈춘다
    if (c === '\\' && !raw) {
      const next = src[i + 1];
      if (interp === 'swift' && next === '(') {
        parts.push(src.slice(segStart, i));
        const close = scanBalanced(src, i + 2, '(', ')', lang, nested);
        parts.push(MASK.repeat(close - i));
        i = close;
        segStart = i;
        continue;
      }
      if (next === 'n' || next === 't' || next === 'r') {
        parts.push(src.slice(segStart, i));
        parts.push('  ');
        i += 2;
        segStart = i;
        continue;
      }
      i += 2;
      continue;
    }
    if (c === '$' && !raw && (interp === 'dart' || interp === 'js')) {
      if (src[i + 1] === '{') {
        parts.push(src.slice(segStart, i));
        const close = scanBalanced(src, i + 2, '{', '}', lang, nested);
        parts.push(MASK.repeat(close - i));
        i = close;
        segStart = i;
        continue;
      }
      if (interp === 'dart' && /[A-Za-z_]/.test(src[i + 1] ?? '')) {
        parts.push(src.slice(segStart, i));
        let j = i + 1;
        while (j < n && /[A-Za-z0-9_]/.test(src[j])) j += 1;
        parts.push(MASK.repeat(j - i));
        i = j;
        segStart = i;
        continue;
      }
    }
    i += 1;
  }
  parts.push(src.slice(segStart, i));
  return { end: i, text: parts.join(''), items: nested };
}

// 보간 안의 코드를 짝이 맞는 닫는 괄호까지 읽는다. 안의 문자열 리터럴도 항목으로 모은다. 닫는 괄호 뒤 위치를 돌려준다.
function scanBalanced(src, i, open, close, lang, items) {
  let depth = 1;
  while (i < src.length) {
    const r = scanToken(src, i, lang, items);
    if (r !== null) {
      i = r;
      continue;
    }
    const c = src[i];
    if (c === open) depth += 1;
    else if (c === close) {
      depth -= 1;
      if (depth === 0) return i + 1;
    }
    i += 1;
  }
  return i;
}

function skipBlockComment(src, i, nested) {
  let depth = 1;
  i += 2;
  while (i < src.length && depth > 0) {
    if (src.startsWith('*/', i)) {
      depth -= 1;
      i += 2;
    } else if (nested && src.startsWith('/*', i)) {
      depth += 1;
      i += 2;
    } else {
      i += 1;
    }
  }
  return i;
}

// 위치 i에서 주석이나 문자열이 시작하면 건너뛴 뒤 위치를 돌려주고(문자열은 items에 넣는다), 아니면 null.
function scanToken(src, i, lang, items) {
  const c = src[i];
  if (c === '/' && src[i + 1] === '/') {
    const eol = src.indexOf('\n', i);
    return eol === -1 ? src.length : eol;
  }
  if (c === '/' && src[i + 1] === '*') return skipBlockComment(src, i, lang !== 'ts');

  const emit = (start, r) => {
    items.push({ text: r.text, origin: start });
    items.push(...r.items);
    return r.end;
  };

  if (lang === 'swift') {
    if (c === '#' && /^#+"/.test(src.slice(i, i + 16))) {
      const hashes = /^#+/.exec(src.slice(i))[0];
      const at = i + hashes.length;
      const multi = src.startsWith('"""', at);
      const open = multi ? 3 : 1;
      return emit(at + open, readString(src, at + open, { quote: (multi ? '"""' : '"') + hashes, multiline: multi, raw: true, lang }));
    }
    if (src.startsWith('"""', i)) return emit(i + 3, readString(src, i + 3, { quote: '"""', multiline: true, interp: 'swift', lang }));
    if (c === '"') return emit(i + 1, readString(src, i + 1, { quote: '"', multiline: false, interp: 'swift', lang }));
    return null;
  }
  if (lang === 'dart') {
    const raw = c === 'r' && (src[i + 1] === "'" || src[i + 1] === '"') && !isIdent(src[i - 1]);
    const at = raw ? i + 1 : i;
    const q = src[at];
    if (q !== "'" && q !== '"') return null;
    const triple = src.startsWith(q.repeat(3), at);
    const quote = triple ? q.repeat(3) : q;
    return emit(at + quote.length, readString(src, at + quote.length, { quote, multiline: triple, raw, interp: 'dart', lang }));
  }
  // ts / tsx
  if (c === "'" || c === '"') return emit(i + 1, readString(src, i + 1, { quote: c, multiline: false, interp: null, lang }));
  if (c === '`') return emit(i + 1, readString(src, i + 1, { quote: '`', multiline: true, interp: 'js', lang }));
  return null;
}

// 주석과 문자열 밖의 코드만 남긴 사본(나머지는 공백, 줄바꿈 유지). TSX 텍스트 노드 찾기에 쓴다.
function scanFile(src, lang) {
  const items = [];
  const code = src.split('');
  let i = 0;
  while (i < src.length) {
    const r = scanToken(src, i, lang, items);
    if (r === null) {
      i += 1;
      continue;
    }
    for (let k = i; k < r; k += 1) if (code[k] !== '\n') code[k] = ' ';
    i = r;
  }
  return { items, code: code.join('') };
}

export function extractSwift(src) {
  return scanFile(src, 'swift').items;
}

export function extractDart(src) {
  return scanFile(src, 'dart').items;
}

/** 따옴표·백틱 리터럴(`${…}` 바깥)과 JSX 텍스트 노드(`>텍스트<`, `}텍스트{` 등). */
export function extractTs(src) {
  const { items, code } = scanFile(src, 'ts');
  const jsx = /[^<>{}\n]+/g;
  for (const m of code.matchAll(jsx)) {
    if (!HANGUL.test(m[0])) continue;
    const lead = m[0].length - m[0].trimStart().length;
    items.push({ text: m[0].trim(), origin: m.index + lead });
  }
  return items.sort((a, b) => a.origin - b.origin);
}

function lineColAt(text, offset) {
  let line = 1;
  let last = -1;
  for (let i = text.indexOf('\n'); i !== -1 && i < offset; i = text.indexOf('\n', i + 1)) {
    line += 1;
    last = i;
  }
  return { line, col: offset - last };
}

// JSON 문자열 값의 위치: from 뒤에서 처음 나오는 그 값의 JSON 표기. 못 찾으면 파일 처음부터 다시 찾는다.
function locateJsonString(raw, value, from) {
  const needle = JSON.stringify(value);
  let at = raw.indexOf(needle, from);
  if (at === -1) at = raw.indexOf(needle);
  return at === -1 ? { at: from, pos: lineColAt(raw, from) } : { at: at + needle.length, pos: lineColAt(raw, at + 1) };
}

/** `strings.<key>.localizations.ko`의 stringUnit.value(복수형 variations 안의 값 포함). 키를 함께 넘긴다. */
export function extractXcstrings(raw) {
  const doc = JSON.parse(raw);
  const items = [];
  let cursor = 0;
  for (const [key, entry] of Object.entries(doc.strings ?? {})) {
    const ko = entry?.localizations?.ko;
    if (!ko) continue;
    const keyAt = raw.indexOf(JSON.stringify(key), cursor);
    if (keyAt !== -1) cursor = keyAt;
    const values = [];
    (function walk(node) {
      if (!node || typeof node !== 'object') return;
      if (node.stringUnit && typeof node.stringUnit.value === 'string') values.push(node.stringUnit.value);
      if (node.variations) for (const v of Object.values(node.variations)) for (const c of Object.values(v)) walk(c);
    })(ko);
    for (const value of values) {
      const { at, pos } = locateJsonString(raw, value, cursor);
      cursor = at;
      items.push({ text: value, key, ...pos });
    }
  }
  return items;
}

/** contracts/{metric-catalog,vocab}.v1.json의 nameKo 값과 labelsKo 값. */
export function extractContractLabels(raw) {
  const items = [];
  let cursor = 0;
  const add = (value, key) => {
    const { at, pos } = locateJsonString(raw, value, cursor);
    cursor = at;
    items.push({ text: value, key, ...pos });
  };
  (function walk(node, trail) {
    if (Array.isArray(node)) node.forEach((v, i) => walk(v, [...trail, i]));
    else if (node && typeof node === 'object') {
      for (const [k, v] of Object.entries(node)) {
        if (k === 'nameKo' && typeof v === 'string') add(v, [...trail, k].join('.'));
        else if (k === 'labelsKo' && v && typeof v === 'object') {
          for (const [lk, lv] of Object.entries(v)) if (typeof lv === 'string') add(lv, [...trail, k, lk].join('.'));
        } else walk(v, [...trail, k]);
      }
    }
  })(JSON.parse(raw), []);
  return items;
}

export function extractFile(rel, raw) {
  if (rel.endsWith('.swift')) return extractSwift(raw);
  if (rel.endsWith('.dart')) return extractDart(raw);
  if (rel.endsWith('.ts') || rel.endsWith('.tsx')) return extractTs(raw);
  if (rel.endsWith('.xcstrings')) return extractXcstrings(raw);
  if (rel.endsWith('.json')) return extractContractLabels(raw);
  return [];
}

// ---------------------------------------------------------------------------------------------
// 저장소 검사

/** 경로의 규칙 세트(pathRuleSets 첫 일치). 일치가 없으면 null. */
export function ruleSetsFor(rel, doc) {
  const hit = doc.pathRuleSets.find((p) => matchGlob(p.glob, rel));
  return hit ? hit.ruleSets : null;
}

export function isSkipped(rel, doc) {
  return doc.excludePaths.some((g) => matchGlob(g, rel)) || doc.allowPaths.some((g) => matchGlob(g, rel));
}

function walkDir(root, dir, exts, out) {
  const abs = path.join(root, dir);
  if (!existsSync(abs)) return;
  for (const ent of readdirSync(abs, { withFileTypes: true })) {
    if (ent.name.startsWith('.') || ent.name === 'node_modules') continue;
    const rel = `${dir}/${ent.name}`;
    if (ent.isDirectory()) walkDir(root, rel, exts, out);
    else if (ent.isFile() && exts.some((e) => ent.name.endsWith(e))) out.push(rel);
  }
}

export function targetFiles(root, doc) {
  const files = [];
  for (const t of TARGETS) {
    if (t.file) {
      if (existsSync(path.join(root, t.file))) files.push(t.file);
    } else {
      walkDir(root, t.dir, t.exts, files);
    }
  }
  return [...new Set(files)].filter((rel) => !isSkipped(rel, doc)).sort();
}

/** 파일 하나의 위반 목록. rel은 저장소 루트 기준 슬래시 경로. */
export function lintSource(rel, raw, compiled, ruleSets = ruleSetsFor(rel, compiled.doc)) {
  if (!ruleSets) return [];
  const lineStarts = [0];
  for (let i = raw.indexOf('\n'); i !== -1; i = raw.indexOf('\n', i + 1)) lineStarts.push(i + 1);
  const locate = (offset) => {
    let lo = 0;
    let hi = lineStarts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return { line: lo + 1, col: offset - lineStarts[lo] + 1 };
  };
  const violations = [];
  for (const item of extractFile(rel, raw)) {
    for (const h of scanText(item.text, compiled, { ruleSets, key: item.key, file: rel })) {
      const pos = item.origin !== undefined ? locate(item.origin + h.start) : { line: item.line, col: item.col + h.start };
      violations.push({ file: rel, ...pos, ...(item.key ? { key: item.key } : {}), ...h });
    }
  }
  return violations;
}

export function loadRules(root) {
  const abs = path.join(root, RULES_FILE);
  if (!existsSync(abs)) throw new UsageError(`${RULES_FILE} not found under ${root}`);
  let doc;
  try {
    doc = JSON.parse(readFileSync(abs, 'utf8'));
  } catch (e) {
    throw new UsageError(`${RULES_FILE}: invalid JSON: ${e.message}`);
  }
  return compileRules(doc);
}

export function lintRepo(root) {
  const compiled = loadRules(root);
  const files = targetFiles(root, compiled.doc);
  const violations = [];
  const unmapped = [];
  for (const rel of files) {
    const sets = ruleSetsFor(rel, compiled.doc);
    if (!sets) {
      unmapped.push(rel);
      continue;
    }
    violations.push(...lintSource(rel, readFileSync(path.join(root, rel), 'utf8'), compiled, sets));
  }
  violations.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line || a.col - b.col || a.ruleId.localeCompare(b.ruleId));
  return { files, violations, unmapped };
}

// ---------------------------------------------------------------------------------------------
// 출력

export function formatViolation(v) {
  const key = v.key ? ` (key ${v.key})` : '';
  const warn = v.severity === 'warn' ? ' (warn)' : '';
  return `${v.file}:${v.line}:${v.col} [${v.ruleSet}/${v.ruleId}] ${v.term} → ${v.alternatives.join(' | ')}${warn}${key}`;
}

export function countBy(violations) {
  const block = violations.filter((v) => v.severity === 'block').length;
  return { total: violations.length, block, warn: violations.length - block, files: new Set(violations.map((v) => v.file)).size };
}

const cell = (s) => String(s).replace(/\\/g, '\\\\').replace(/\|/g, '\\|').replace(/\n/g, ' ');

export const SUMMARY_ROW_LIMIT = 1000;

/** GitHub Step Summary용 Markdown 표(AC-DF-010.6). */
export function renderSummary({ files, violations }, mode) {
  const c = countBy(violations);
  const out = [
    `## copy-lint (${mode} 모드)`,
    '',
    `규칙: \`${RULES_FILE}\` · 검사 파일 ${files.length}개 · ${mode === 'report' ? '보고 모드는 위반이 있어도 실패하지 않는다(DF-040에서 차단 전환).' : 'severity block 위반이 있으면 실패한다.'}`,
    '',
    '| 구분 | 건수 |',
    '|---|---:|',
    `| 위반 합계 | ${c.total} |`,
    `| block | ${c.block} |`,
    `| warn(인과 패턴) | ${c.warn} |`,
    `| 위반이 있는 파일 | ${c.files} |`,
    '',
  ];
  if (violations.length === 0) return `${out.join('\n')}\n`;

  const byRule = new Map();
  const byFile = new Map();
  for (const v of violations) {
    const rk = `${v.ruleSet}/${v.ruleId}`;
    const r = byRule.get(rk) ?? { severity: v.severity, count: 0 };
    r.count += 1;
    byRule.set(rk, r);
    const f = byFile.get(v.file) ?? { block: 0, warn: 0 };
    f[v.severity === 'block' ? 'block' : 'warn'] += 1;
    byFile.set(v.file, f);
  }
  out.push('### 규칙별', '', '| 규칙 | severity | 건수 |', '|---|---|---:|');
  for (const [k, r] of [...byRule].sort((a, b) => b[1].count - a[1].count || a[0].localeCompare(b[0]))) {
    out.push(`| ${cell(k)} | ${r.severity} | ${r.count} |`);
  }
  out.push('', '### 파일별', '', '| 파일 | block | warn |', '|---|---:|---:|');
  for (const [f, n] of [...byFile].sort((a, b) => a[0].localeCompare(b[0]))) out.push(`| ${cell(f)} | ${n.block} | ${n.warn} |`);
  out.push('', '### 위반 목록', '', '| 위치 | 규칙 | 용어 | 대체어 |', '|---|---|---|---|');
  for (const v of violations.slice(0, SUMMARY_ROW_LIMIT)) {
    const where = `${v.file}:${v.line}:${v.col}${v.key ? ` (${v.key})` : ''}`;
    out.push(`| ${cell(where)} | ${cell(`${v.ruleSet}/${v.ruleId}`)}${v.severity === 'warn' ? ' (warn)' : ''} | ${cell(v.term)} | ${cell(v.alternatives.join(' / '))} |`);
  }
  if (violations.length > SUMMARY_ROW_LIMIT) {
    out.push('', `표에는 처음 ${SUMMARY_ROW_LIMIT}건만 싣는다. 전체 목록은 job 로그에 있다.`);
  }
  return `${out.join('\n')}\n`;
}

// ---------------------------------------------------------------------------------------------
// CLI

class UsageError extends Error {}

const USAGE = 'usage: node tool/lint/prohibited-terms.mjs [--mode=report|block] [--summary <file>] [--root <dir>]';

export function parseArgs(argv) {
  const opts = { mode: 'report', summary: null, root: path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..') };
  const value = (i, name) => {
    const v = argv[i];
    if (v === undefined || v === '' || v.startsWith('--')) throw new UsageError(`${name} needs a value`);
    return v;
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const [flag, inline] = a.includes('=') ? [a.slice(0, a.indexOf('=')), a.slice(a.indexOf('=') + 1)] : [a, undefined];
    if (flag === '--mode') opts.mode = inline ?? value(++i, '--mode');
    else if (flag === '--summary') opts.summary = inline ?? value(++i, '--summary');
    else if (flag === '--root') opts.root = path.resolve(inline ?? value(++i, '--root'));
    else if (flag === '-h' || flag === '--help') opts.help = true;
    else throw new UsageError(`unknown argument ${a}`);
  }
  if (!MODES.includes(opts.mode)) throw new UsageError(`--mode must be one of ${MODES.join(', ')} (got "${opts.mode}")`);
  return opts;
}

export function run(argv, { out = console.log, err = console.error } = {}) {
  let opts;
  try {
    opts = parseArgs(argv);
    if (opts.help) {
      out(USAGE);
      return 0;
    }
    const result = lintRepo(opts.root);
    for (const rel of result.unmapped) err(`warning: ${rel} has no pathRuleSets entry; not checked`);
    for (const v of result.violations) out(formatViolation(v));
    const c = countBy(result.violations);
    out(`copy-lint (${opts.mode}): ${c.total} violation(s) — ${c.block} block, ${c.warn} warn — in ${c.files} of ${result.files.length} file(s)`);
    if (opts.summary) appendFileSync(opts.summary, renderSummary(result, opts.mode));
    if (opts.mode === 'block' && c.block > 0) {
      err(`copy-lint: ${c.block} block violation(s). Replace them with the listed alternatives (PRD appendix C).`);
      return 1;
    }
    return 0;
  } catch (e) {
    if (e instanceof UsageError) err(`copy-lint: ${e.message}\n${USAGE}`);
    else err(`copy-lint: ${e.stack ?? e}`);
    return 2;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  process.exitCode = run(process.argv.slice(2));
}

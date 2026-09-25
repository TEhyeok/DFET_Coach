#!/usr/bin/env node
// docs/v1 헤더 표준(V1-01 '문서 변경')과 상대 파일 링크 린트. DF-001(AC-DF-001.1, AC-DF-001.5).
// Node 22 내장 모듈만 쓴다(ASM-S01-03). 앵커(#...)는 검사하지 않는다(ASM-P0-23).
//
// 사용법:
//   node tool/lint/doc-headers.mjs [--links] [경로 ...]     (경로 기본값: docs/v1)
// 종료 코드: 0 통과, 1 위반(검사할 .md 파일이 0개인 경우 포함), 2 사용법 오류
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const HEADER_ROWS = Object.freeze([
  '문서 ID',
  '버전',
  '상태',
  '작성일',
  '소유자',
  '근거 PRD 절',
  '관련 에픽·스토리',
  '변경 규칙',
]);
export const TOC_HEADING = '## 목차';
export const DOC_CHANGE_FILE = '01_AGILE_WORKING_AGREEMENT.md';
export const DOC_CHANGE_HEADING = '## 문서 변경';

const DEFAULT_TARGET = 'docs/v1';
const SEPARATOR_ROW = /^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$/;
const FENCE = /^ {0,3}(`{3,}|~{3,})/;
// [text](dest "title") / ![alt](dest). dest는 <...> 또는 공백 없는 문자열(괄호 한 단계 허용).
const LINK = /!?\[(?:[^[\]]|\[[^[\]]*\])*\]\(\s*(<[^>\n]*>|[^\s()]*(?:\([^\s()]*\)[^\s()]*)*)(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*\)/g;
// 참조 정의 [label]: dest "title". 각주 정의 [^n]: 는 링크가 아니다.
const REF_DEF = /^ {0,3}\[(?!\^)(?:[^[\]]|\\.)+\]:\s*(<[^>\n]*>|\S+)/;
const SCHEME = /^[a-z][a-z0-9+.-]*:/i;

/** 경로(파일 또는 폴더) 아래의 .md 파일을 정렬해 돌려준다. */
export function collectMarkdown(target) {
  const st = statSync(target);
  if (st.isFile()) return target.endsWith('.md') ? [target] : [];
  const out = [];
  for (const entry of readdirSync(target, { withFileTypes: true })) {
    const p = path.join(target, entry.name);
    if (entry.isDirectory()) out.push(...collectMarkdown(p));
    else if (entry.isFile() && entry.name.endsWith('.md')) out.push(p);
  }
  return out.sort();
}

function splitRow(line) {
  const body = line.trim().replace(/^\|/, '').replace(/(?<!\\)\|$/, '');
  return body.split(/(?<!\\)\|/).map((c) => c.trim());
}

/** 헤더 표준 검사. 위반 목록 [{line, message}]을 돌려준다. */
export function checkHeader(file, text) {
  const errors = [];
  const lines = text.split(/\r?\n/);
  const err = (line, message) => errors.push({ line, message });

  if (!lines[0] || !lines[0].startsWith('# ')) {
    err(1, "첫 줄이 '# '으로 시작하지 않는다");
  }

  let i = 1;
  while (i < lines.length && lines[i].trim() === '') i++;
  if (i >= lines.length || !lines[i].trimStart().startsWith('|')) {
    err(Math.min(i + 1, lines.length), '제목 다음에 헤더 표가 없다');
  } else {
    const tableStart = i;
    const seen = new Map();
    let first = true;
    for (; i < lines.length && lines[i].trimStart().startsWith('|'); i++) {
      if (SEPARATOR_ROW.test(lines[i].trim())) continue;
      if (first) { first = false; continue; } // 표 머리 행(예: | 항목 | 내용 |)
      const [label = '', value = ''] = splitRow(lines[i]);
      if (!HEADER_ROWS.includes(label)) {
        err(i + 1, `헤더 표에 정의되지 않은 행 '${label}'이 있다`);
        continue;
      }
      if (seen.has(label)) err(i + 1, `헤더 표에 '${label}' 행이 두 번 있다`);
      else seen.set(label, i + 1);
      if (value === '') err(i + 1, `헤더 표 '${label}' 값이 비어 있다`);
    }
    for (const label of HEADER_ROWS) {
      if (!seen.has(label)) err(tableStart + 1, `헤더 표에 '${label}' 행이 없다`);
    }
    while (i < lines.length && lines[i].trim() === '') i++;
    if (i >= lines.length || lines[i].trim() !== TOC_HEADING) {
      err(Math.min(i + 1, lines.length), `헤더 표 다음에 '${TOC_HEADING}'가 없다`);
    }
  }

  if (path.basename(file) === DOC_CHANGE_FILE && !lines.some((l) => l.trim() === DOC_CHANGE_HEADING)) {
    err(1, `'${DOC_CHANGE_HEADING}' 절이 없다`);
  }
  return errors;
}

function blankInlineCode(line) {
  return line.replace(/(`+)[\s\S]*?(?<!`)\1(?!`)/g, (m) => ' '.repeat(m.length));
}

/** 코드 블록·인라인 코드를 뺀 본문에서 링크 대상 [{line, target}]을 뽑는다(인라인 링크와 참조 정의). */
export function extractLinks(text) {
  const links = [];
  let fence = null;
  text.split(/\r?\n/).forEach((raw, idx) => {
    const m = raw.match(FENCE);
    if (fence) {
      if (m && m[1][0] === fence[0] && m[1].length >= fence.length && raw.trim() === m[1]) fence = null;
      return;
    }
    if (m) { fence = m[1]; return; }
    const line = blankInlineCode(raw);
    const def = line.match(REF_DEF);
    if (def) links.push({ line: idx + 1, target: def[1].replace(/^<|>$/g, '') });
    for (const lm of line.matchAll(LINK)) {
      links.push({ line: idx + 1, target: lm[1].replace(/^<|>$/g, '') });
    }
  });
  return links;
}

/** 상대 파일 링크 검사. 외부 URL·앵커 단독 링크는 건너뛰고, 앵커 부분은 떼고 파일 존재만 본다. */
export function checkLinks(file, text, { repoRoot = process.cwd() } = {}) {
  const errors = [];
  for (const { line, target } of extractLinks(text)) {
    if (target === '' || target.startsWith('#') || target.startsWith('//') || SCHEME.test(target)) continue;
    let rel = target.replace(/[?#].*$/, '');
    if (rel === '') continue;
    try { rel = decodeURIComponent(rel); } catch { /* 그대로 둔다 */ }
    const resolved = rel.startsWith('/') ? path.join(repoRoot, rel) : path.resolve(path.dirname(file), rel);
    if (!existsSync(resolved)) errors.push({ line, message: `깨진 상대 링크: ${target}` });
  }
  return errors;
}

/** 경로 목록을 검사해 {files, errors:[{file,line,message}]}를 돌려준다. */
export function lint(targets, { links = false, repoRoot = process.cwd() } = {}) {
  const files = targets.flatMap((t) => collectMarkdown(t));
  const errors = [];
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    for (const e of checkHeader(file, text)) errors.push({ file, ...e });
    if (links) for (const e of checkLinks(file, text, { repoRoot })) errors.push({ file, ...e });
  }
  return { files, errors };
}

function main(argv) {
  const usage = '사용법: node tool/lint/doc-headers.mjs [--links] [경로 ...]  (기본 경로: docs/v1)';
  let links = false;
  const targets = [];
  for (const a of argv) {
    if (a === '--links') links = true;
    else if (a === '-h' || a === '--help') { console.log(usage); return 0; }
    else if (a.startsWith('-')) { console.error(`알 수 없는 옵션: ${a}\n${usage}`); return 2; }
    else targets.push(a);
  }
  if (targets.length === 0) targets.push(DEFAULT_TARGET);
  for (const t of targets) {
    if (!existsSync(t)) { console.error(`경로 없음: ${t}\n${usage}`); return 2; }
  }
  const { files, errors } = lint(targets, { links });
  if (files.length === 0) {
    // 폴더 이름이 바뀌거나 비면 CI가 조용히 통과하지 않게 한다
    console.error(`FAIL: 검사할 .md 파일이 없다: ${targets.join(', ')}`);
    return 1;
  }
  for (const e of errors) console.error(`${e.file}:${e.line}: ${e.message}`);
  const scope = links ? '헤더 표준 + 상대 링크' : '헤더 표준';
  if (errors.length > 0) {
    console.error(`FAIL: ${files.length}개 파일, 위반 ${errors.length}건 (${scope})`);
    return 1;
  }
  console.log(`OK: ${files.length}개 파일 (${scope})`);
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  process.exitCode = main(process.argv.slice(2));
}

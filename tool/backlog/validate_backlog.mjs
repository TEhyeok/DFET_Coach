#!/usr/bin/env node
// TL-12 validate_backlog.mjs — 이슈 데이터 검증기(Node 22+ 내장 모듈만)
// 사용: node tool/backlog/validate_backlog.mjs [--prd docs/PRD_V1.md] [--repo-root <dir>] [issues.json]
// 검사
//  1) issue.schema.json의 required·type·enum
//  2) 키 유일성, 제목 '[KEY] ' 접두
//  3) 라벨이 labels.json에 존재, type/·phase/·prio/ 정확히 1(에픽은 type/epic만), size/ 0~1
//  4) 마일스톤이 milestones.json에 존재(trackingOnly 아닌 것)
//  5) epic 참조 존재, deps·cardDeps 대상 존재, 의존 순환 0(deps ∪ cardDeps)
//  6) trace 토큰이 PRD에 존재(범위 A~B는 양 끝, §는 제목 존재, ADR-NNN은 docs/v1/adr 파일 존재,
//     AS-DEV·Q-DEV·AC-DF는 개발 ID라 제외)
//  7) 교차 검사: 모든 DF 키가 docs/v1/backlog/*.md 카드와 02 색인에 있고, sprints/SPRINT_NN.md가 있으면
//     그 스프린트에 배정된 키가 스프린트 문서에 나온다
// 오류가 있으면 exit 1. 형식: "<파일>: <KEY> <메시지>"
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const argv = process.argv.slice(2);
const here = dirname(fileURLToPath(import.meta.url));
let root = resolve(here, '..', '..');
let prdPath = null;
const files = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--repo-root') root = resolve(argv[++i]);
  else if (argv[i] === '--prd') prdPath = argv[++i];
  else files.push(argv[i]);
}
prdPath = resolve(prdPath ?? join(root, 'docs/PRD_V1.md'));
if (!files.length) files.push(join(root, 'tool/backlog/issues.json'));

const errors = [];
const warns = [];
const err = (f, k, m) => errors.push(`${basename(f)}: ${k} ${m}`);

const schema = JSON.parse(readFileSync(join(root, 'tool/backlog/issue.schema.json'), 'utf8'));
const labels = new Set(JSON.parse(readFileSync(join(root, 'tool/backlog/labels.json'), 'utf8')).labels.map((l) => l.name));
const msDoc = JSON.parse(readFileSync(join(root, 'tool/backlog/milestones.json'), 'utf8'));
const milestones = new Set(msDoc.milestones.filter((m) => !m.trackingOnly).map((m) => m.title));
if (!existsSync(prdPath)) { console.error(`PRD not found: ${prdPath} (use --prd)`); process.exit(2); }
const prd = readFileSync(prdPath, 'utf8');
const prdHeadings = prd.split('\n').filter((l) => /^#{1,6} /.test(l));
const adrDir = join(root, 'docs/v1/adr');
const adrs = existsSync(adrDir) ? readdirSync(adrDir).map((f) => (/^(ADR-\d{3})/.exec(f) || [])[1]).filter(Boolean) : [];

const typeOk = (v, t) => (Array.isArray(t) ? t.some((x) => typeOk(v, x)) :
  t === 'null' ? v === null : t === 'array' ? Array.isArray(v) : t === 'integer' ? Number.isInteger(v) :
  t === 'object' ? v !== null && typeof v === 'object' && !Array.isArray(v) : typeof v === t);

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const inPrd = (id) => new RegExp(`${esc(id)}(?![0-9A-Za-z])`).test(prd) || new RegExp(`${esc(id)}(?![0-9])`).test(prd);

// trace 토큰 하나를 검사할 ID 목록으로 펼친다. null이면 검사 제외.
function expand(tokRaw) {
  let tok = tokRaw.replace(/\(.*?\)/g, '').trim().split(/\s+/)[0];
  tok = tok.replace(/[,.]$/, '');
  if (!tok) return null;
  if (/^(AS-DEV|Q-DEV|AC-DF|ASM|CF|TC)-/.test(tok)) return null;
  if (/^ADR-\d{3}$/.test(tok)) return { adr: tok };
  if (tok.startsWith('§')) {
    const num = tok.slice(1).split(/[-~–]/)[0].replace(/\.$/, '');
    return { section: num };
  }
  if (tok === '부록') { const m = /^부록\s+([A-Z](?:\.\d+)?)/.exec(tokRaw.trim()); return m ? { appendix: m[1] } : null; }
  if (tok.endsWith('*')) return { prefix: tok.slice(0, -1) };
  if (tok.includes('~')) {
    const [a, b] = tok.split('~');
    const lo = a;
    let hi = b;
    if (!/^[A-Z]/.test(b)) hi = a.slice(0, a.lastIndexOf('-') + 1) + b; // AC-SOAP-01.1~01.3, F-VIZ-03.7~03.10
    return { ids: [lo, hi] };
  }
  if (/^[A-Z][A-Z0-9]*-?[A-Za-z0-9.-]*$/.test(tok) || /^D\d+$/.test(tok) || /^T\d{2}$/.test(tok)) return { ids: [tok] };
  return null;
}

function checkTrace(f, key, trace) {
  for (const t of trace) {
    const e = expand(t);
    if (!e) continue;
    if (e.adr) { if (!adrs.includes(e.adr)) err(f, key, `trace ${t} ADR file not found`); continue; }
    if (e.section) {
      const re = new RegExp(`^#{1,6} (\\S+ )?${esc(e.section)}(\\.|\\s)`);
      if (!prdHeadings.some((h) => re.test(h))) err(f, key, `trace ${t} section not found in PRD`);
      continue;
    }
    if (e.appendix) { if (!prd.includes(`부록 ${e.appendix.split('.')[0]}`) || !prd.includes(e.appendix)) err(f, key, `trace ${t} not found in PRD`); continue; }
    if (e.prefix) { if (!prd.includes(e.prefix)) err(f, key, `trace ${t} not found in PRD`); continue; }
    for (const id of e.ids) if (!inPrd(id)) err(f, key, `trace ${id} not found in PRD`);
  }
}

// 카드·색인·스프린트 교차 검사 준비
const cardDir = join(root, 'docs/v1/backlog');
const cardKeys = new Set();
if (existsSync(cardDir)) for (const f of readdirSync(cardDir).filter((x) => x.endsWith('.md'))) {
  for (const m of readFileSync(join(cardDir, f), 'utf8').matchAll(/^### (DF-\d{3}) /gm)) cardKeys.add(m[1]);
}
const indexPath = join(root, 'docs/v1/02_PRODUCT_BACKLOG.md');
const indexKeys = new Set(existsSync(indexPath) ? [...readFileSync(indexPath, 'utf8').matchAll(/^\| (DF-\d{3}) \|/gm)].map((m) => m[1]) : []);
const indexEpics = new Set(existsSync(indexPath) ? [...readFileSync(indexPath, 'utf8').matchAll(/^\| (EP-\d{2}) \|/gm)].map((m) => m[1]) : []);

let total = 0;
for (const f of files) {
  const doc = JSON.parse(readFileSync(resolve(f), 'utf8'));
  const items = Array.isArray(doc) ? doc : doc.issues;
  total += items.length;
  const keys = new Map();
  for (const it of items) {
    const k = it.key ?? '(no key)';
    for (const r of schema.required) if (!(r in it)) err(f, k, `missing required ${r}`);
    for (const [p, s] of Object.entries(schema.properties)) {
      if (!(p in it)) continue;
      if (s.type && !typeOk(it[p], s.type)) err(f, k, `${p} type`);
      if (s.enum && !s.enum.includes(it[p])) err(f, k, `${p} not in enum: ${it[p]}`);
      if (s.items?.type && Array.isArray(it[p]) && it[p].some((x) => !typeOk(x, s.items.type))) err(f, k, `${p} item type`);
    }
    if (keys.has(k)) err(f, k, 'duplicate key');
    keys.set(k, it);
    if (!it.title?.startsWith(`[${k}] `)) err(f, k, 'title must start with [KEY]');
    for (const l of it.labels ?? []) if (!labels.has(l)) err(f, k, `label ${l} not in labels.json`);
    const count = (re) => (it.labels ?? []).filter((l) => re.test(l)).length;
    if (it.kind === 'epic') { if (count(/^type\//) !== 1 || !it.labels.includes('type/epic')) err(f, k, 'epic needs type/epic only'); }
    else {
      for (const g of ['type', 'phase', 'prio']) if (count(new RegExp(`^${g}/`)) !== 1) err(f, k, `needs exactly one ${g}/ label`);
      if (count(/^size\//) > 1) err(f, k, 'more than one size/ label');
      if (it.ownerAction && !it.labels.includes('owner-action')) err(f, k, 'owner-action label missing');
      if (it.proposal && !it.labels.includes('status/needs-decision')) err(f, k, 'proposal needs status/needs-decision');
      if (it.milestone !== null && !milestones.has(it.milestone)) err(f, k, `milestone ${it.milestone} not in milestones.json`);
      if (it.points > 5 && !it.labels.includes('size/XL')) err(f, k, 'points > 5 must be split');
      if (!indexKeys.has(k)) err(f, k, 'not in 02 index');
      if (!cardKeys.has(k)) err(f, k, 'no card in docs/v1/backlog');
    }
    checkTrace(f, k, it.trace ?? []);
  }
  for (const it of items) {
    if (it.epic && !keys.has(it.epic)) err(f, it.key, `epic ${it.epic} not found`);
    for (const d of [...(it.deps ?? []), ...(it.cardDeps ?? [])]) if (!keys.has(d)) err(f, it.key, `dependency ${d} not found`);
    for (const c of it.children ?? []) if (!keys.has(c)) err(f, it.key, `child ${c} not found`);
  }
  for (const e of indexEpics) if (!keys.has(e)) err(f, e, 'epic in 02 index but not in issues');
  for (const k of indexKeys) if (!keys.has(k)) err(f, k, 'in 02 index but not in issues');
  // 순환 검사(deps ∪ cardDeps)
  const color = new Map();
  const visit = (k, stack) => {
    color.set(k, 1);
    const it = keys.get(k);
    for (const d of [...(it?.deps ?? []), ...(it?.cardDeps ?? [])]) {
      if (color.get(d) === 1) { err(f, k, `dependency cycle ${[...stack, k, d].join(' -> ')}`); continue; }
      if (!color.has(d) && keys.has(d)) visit(d, [...stack, k]);
    }
    color.set(k, 2);
  };
  for (const k of keys.keys()) if (!color.has(k)) visit(k, []);
  // 스프린트 문서 교차 검사
  const sprintDir = join(root, 'docs/v1/sprints');
  if (existsSync(sprintDir)) for (const sf of readdirSync(sprintDir).filter((x) => /^SPRINT_\d{2}\.md$/.test(x))) {
    const sid = `S${sf.slice(7, 9)}`;
    const text = readFileSync(join(sprintDir, sf), 'utf8');
    for (const it of items) if (it.sprint === sid && !it.proposal && !text.includes(it.key)) err(f, it.key, `assigned to ${sid} but missing in sprints/${sf}`);
  }
}

for (const w of warns) console.error(`warn: ${w}`);
if (errors.length) { for (const e of errors) console.error(e); console.error(`FAIL: ${errors.length} error(s) in ${total} items`); process.exit(1); }
console.log(`OK: ${total} items, ${labels.size} labels, ${milestones.size} milestones, PRD ${basename(prdPath)}`);

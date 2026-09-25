#!/usr/bin/env node
// TL-14 build_issues.mjs (TL-13은 01 ASM-01-17의 brief.mjs 후보 번호)
// docs/v1/02_PRODUCT_BACKLOG.md(§6 에픽, §8 색인)와 docs/v1/backlog/*.md 카드에서
// tool/backlog/issues.json을 만든다. 손으로 issues.json을 고치지 않는다.
// 정본: 키·제목·유형·에픽·영역·단계·스프린트·점수·우선·의존·PRD 추적 = 02 §8 색인.
//       본문(사용자 스토리·수용 기준·구현 노트·테스트) = 단계별 카드.
// 사용: node tool/backlog/build_issues.mjs [--check] [--repo-root <dir>]
//   --check  : 파일을 쓰지 않고 현재 issues.json과 다르면 exit 1(CI 드리프트 검사)
// Node 22+ 내장 모듈만 쓴다.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, posix } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const here = dirname(fileURLToPath(import.meta.url));
let root = resolve(here, '..', '..');
const ri = args.indexOf('--repo-root');
if (ri >= 0) root = resolve(args[ri + 1]);
const CHECK = args.includes('--check');

const REPO = 'TEhyeok/DFET_Coach';
const BLOB = `https://github.com/${REPO}/blob/main/`;
const INDEX = 'docs/v1/02_PRODUCT_BACKLOG.md';
const CARD_DIR = 'docs/v1/backlog';
const OUT = 'tool/backlog/issues.json';
const MAX_BODY = 60000; // GitHub 한도 65536자 아래로 여유
// DEC-22: scope/mvp·scope/carryover가 없는 항목은 연기(scope/deferred)다. 이슈 sprint는 DEFERRED_SPRINT로 두고
// 색인의 옛 계획 스프린트는 plannedSprint에 남긴다(MVP 스프린트 번호와 섞이지 않게).
const DEFERRED_SPRINT = 'MVP 뒤';
const MVP_PLAN = 'docs/v1/03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22';

const read = (p) => readFileSync(join(root, p), 'utf8');
const cells = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());

// ---------- 1. 색인 파싱 ----------
const indexText = read(INDEX);
const lines = indexText.split('\n');
const sec = (startRe, endRe) => {
  const s = lines.findIndex((l) => startRe.test(l));
  if (s < 0) throw new Error(`section not found: ${startRe}`);
  let e = lines.findIndex((l, i) => i > s && endRe.test(l));
  if (e < 0) e = lines.length;
  return lines.slice(s, e);
};

const epics = [];
for (const l of sec(/^## 6\. 에픽/, /^## 7\./)) {
  if (!/^\| EP-\d{2} /.test(l)) continue;
  const c = cells(l);
  epics.push({ key: c[0], name: c[1], goal: c[2], prdRefs: c[3], phases: c[4], points: Number(c[5]), count: Number(c[6]) });
}

const rows = [];
const sec8 = sec(/^## 8\. 전체 스토리 색인/, /^## 9\./);
let inProposals = false;
for (const l of sec8) {
  if (/^#### 8\.8\.1/.test(l)) inProposals = true;
  if (/^#### 8\.8\.2/.test(l)) inProposals = false;
  if (!/^\| DF-\d{3} /.test(l)) continue;
  const c = cells(l);
  const r = {
    key: c[0], title: c[1], type: c[2], epic: c[3], area: c[4], phase: c[5], sprint: c[6],
    points: Number(c[7]), prio: c[8], depsRaw: c[9], traceRaw: c[10],
    proposal: inProposals || /추가 제안·채택 대기/.test(c[1]),
  };
  if (inProposals) r.decisionAt = c[12];
  rows.push(r);
}

// ---------- 2. 카드 파싱 ----------
const cardFiles = readdirSync(join(root, CARD_DIR)).filter((f) => f.endsWith('.md')).sort();
const cards = new Map();
for (const f of cardFiles) {
  const rel = posix.join(CARD_DIR, f);
  const ls = read(rel).split('\n');
  for (let i = 0; i < ls.length; i++) {
    const m = /^### (DF-\d{3}) (.*)$/.exec(ls[i]);
    if (!m) continue;
    let j = i + 1;
    while (j < ls.length && !/^### DF-\d{3} /.test(ls[j]) && !/^## /.test(ls[j]) && !/^<a id="df-\d{3}"><\/a>/.test(ls[j])) j++;
    let body = ls.slice(i + 1, j);
    while (body.length && /^(---|\s*)$/.test(body[body.length - 1])) body.pop();
    while (body.length && /^\s*$/.test(body[0])) body.shift();
    const meta = {};
    for (const b of body) {
      const mm = /^\| (Epic|Type|Phase|Sprint|Points|Priority|Area|Labels|Depends on|PRD refs|Gate) \| (.*) \|$/.exec(b);
      if (mm && !(mm[1] in meta)) meta[mm[1]] = mm[2];
    }
    if (cards.has(m[1])) throw new Error(`duplicate card ${m[1]} in ${rel} and ${cards.get(m[1]).file}`);
    cards.set(m[1], { file: rel, heading: m[2], body: body.join('\n'), meta });
  }
}

// ---------- 3. 보조 함수 ----------
const splitList = (s) => s.split(/,\s*/).map((x) => x.trim()).filter(Boolean);
const depsOf = (s) => [...new Set((s.match(/DF-\d{3}/g) || []))];
const SIZE = { 1: 'XS', 2: 'S', 3: 'M', 5: 'L', 8: 'XL' };
const sprintNo = (s) => { const m = /^S(\d+)/.exec(s); return m ? Number(m[1]) : null; };
const MS = { P0: 'P0 정리·기반', P1a: 'P1a 알파-기록', P1b: 'P1b 알파-평가', P2: 'P2 베타', P3: 'P3 센터 출시', V2: 'V2(보류)' };
// 02 §7.2 ASM-02-02: P0 키이지만 S06 이후 배정 항목은 MS-P1a
const milestoneOf = (r) => (r.phase === 'P0' && (sprintNo(r.sprint) ?? 0) >= 6 ? MS.P1a : MS[r.phase]);
const SINGLE = /^(type|phase|prio|size)\//;
const labelsDoc = JSON.parse(read('tool/backlog/labels.json'));
const knownLabels = new Set(labelsDoc.labels.map((l) => l.name));

// 상대 링크를 GitHub blob 절대 링크로 바꾼다(이슈 본문에서 상대 링크는 깨진다).
function absolutize(md, fileRel) {
  const dir = posix.dirname(fileRel);
  return md.replace(/\]\(([^)\s]+)\)/g, (all, target) => {
    if (/^(https?:|mailto:)/.test(target)) return all;
    if (target.startsWith('#')) return `](${BLOB}${fileRel}${target})`;
    const [p, anchor] = target.split('#');
    const resolved = posix.normalize(posix.join(dir, p));
    if (resolved.startsWith('..')) return all; // 저장소 밖(예: BodyPath) 링크는 그대로 둔다
    return `](${BLOB}${resolved}${anchor !== undefined ? '#' + anchor : ''})`;
  });
}

const warnings = [];
const byKey = new Map(rows.map((r) => [r.key, r]));

// ---------- 4. 이슈 객체 ----------
const issues = [];
for (const r of rows) {
  const card = cards.get(r.key);
  if (!card) warnings.push(`${r.key}: 카드 없음`);
  const deps = depsOf(r.depsRaw);
  const cardDeps = card?.meta['Depends on'] ? depsOf(card.meta['Depends on']).filter((d) => d !== r.key && !deps.includes(d)) : [];
  const trace = splitList(r.traceRaw);
  const ownerAction = r.type === 'owner-action';
  const typeLabel = ownerAction ? 'type/task' : `type/${r.type}`;
  const computed = [typeLabel, `area/${r.area}`, `phase/${r.phase}`, `prio/${r.prio}`];
  if (SIZE[r.points]) computed.push(`size/${SIZE[r.points]}`);
  if (ownerAction) {
    computed.push('owner-action', 'agent/human');
    for (const t of trace) if (/^G-(0[1-9]|10)[ab]?$/.test(t) && knownLabels.has(`gate/${t}`)) computed.push(`gate/${t}`);
  }
  if (r.proposal) computed.push('status/needs-decision');
  if (r.phase === 'V2') computed.push('status/blocked');
  const fromCard = card?.meta.Labels ? (card.meta.Labels.match(/`([^`]+)`/g) || []).map((x) => x.slice(1, -1)) : [];
  const labels = [...computed];
  for (const l of fromCard) {
    if (SINGLE.test(l)) {
      if (!computed.includes(l)) warnings.push(`${r.key}: 카드 라벨 ${l}이 색인과 다름(색인 값 사용)`);
      continue;
    }
    if (!knownLabels.has(l)) { warnings.push(`${r.key}: 알 수 없는 카드 라벨 ${l}(제외)`); continue; }
    if (l === 'scope/deferred') continue; // 생성기가 붙인다
    if (!labels.includes(l)) labels.push(l);
  }
  const scopes = labels.filter((l) => /^scope\//.test(l));
  if (scopes.length > 1) warnings.push(`${r.key}: scope/ 라벨이 둘 이상(${scopes.join(', ')})`);
  const deferred = scopes.length === 0;
  if (deferred) labels.push('scope/deferred');
  const sprint = deferred ? DEFERRED_SPRINT : r.sprint;
  // 카드 메타와 색인 불일치 보고(색인이 정본)
  if (card) {
    const cp = card.meta.Points && Number((/^(\d+)/.exec(card.meta.Points) || [])[1]);
    if (card.meta.Points && cp !== r.points) warnings.push(`${r.key}: 카드 Points ${card.meta.Points} ≠ 색인 ${r.points}`);
    if (card.meta.Phase && card.meta.Phase.split(/[ (]/)[0] !== r.phase) warnings.push(`${r.key}: 카드 Phase ${card.meta.Phase} ≠ 색인 ${r.phase}`);
    const cd = card.meta['Depends on'] ? depsOf(card.meta['Depends on']) : [];
    const missing = deps.filter((d) => !cd.includes(d));
    if (card.meta['Depends on'] && missing.length) warnings.push(`${r.key}: 색인 의존 ${missing}이 카드에 없음`);
  }
  const anchor = `#${r.key.toLowerCase()}`;
  const sourceDoc = card ? `${card.file}${anchor}` : INDEX;
  const kind = ownerAction ? 'owner-action' : r.type;
  const head = [
    `> **${r.key}** · ${kind} · ${r.epic} · ${r.phase} · ${deferred ? `${DEFERRED_SPRINT}(옛 계획 ${r.sprint})` : r.sprint} · ${r.points}점 · ${r.prio}${r.proposal ? ' · **추가 제안(채택 대기)**' : ''}`,
    `> 원본 카드: [${sourceDoc}](${BLOB}${sourceDoc}) · 색인: [02 §8](${BLOB}${INDEX}#8-전체-스토리-색인)`,
    `> 이 본문은 \`tool/backlog/build_issues.mjs\`가 카드에서 생성했다. 수정은 카드에서 하고 다시 생성한다.`,
    ...(deferred ? [`> **연기(DEC-22), MVP 뒤 재계획.** 1인 알파 MVP 범위가 아니다. 지금 구현하지 않고 MVP 스프린트에 넣지 않는다. 카드의 Sprint 값(${r.sprint})은 DEC-22 이전 계획이다. [03 MVP 계획](${BLOB}${MVP_PLAN})`] : []),
    ...(labels.includes('scope/carryover') ? [`> **MVP 밖, 진행 중이라 마친다(DEC-22).** PR이 이미 열려 있다. 새 범위를 더하지 않는다. [03 MVP 계획](${BLOB}${MVP_PLAN})`] : []),
    '',
    '<!-- df-links:start -->',
    `**에픽**: ${r.epic}`,
    '',
    `**먼저 끝나야 하는 항목**: ${deps.length ? '' : '없음'}`,
    ...deps.map((d) => `- ${d} ${byKey.get(d)?.title ?? ''}`.trimEnd()),
    ...(cardDeps.length ? ['', '**카드가 더한 의존**(채택 대기 제안 키. 02 §8.8.1에 따라 채택 시 색인에 추가):',
      ...cardDeps.map((d) => `- ${d} ${byKey.get(d)?.title ?? ''}${byKey.get(d)?.proposal ? ' (제안)' : ''}`.trimEnd())] : []),
    '<!-- df-links:end -->',
    '',
    `**PRD 추적**: ${trace.join(', ')}`,
    '',
  ];
  let body = head.join('\n') + '\n' + (card ? absolutize(card.body, card.file) : '_카드 없음. 색인 행만 있다._');
  if (body.length > MAX_BODY) {
    body = body.slice(0, MAX_BODY - 200) + `\n\n…(길이 한도로 잘림. 전문은 원본 카드: ${BLOB}${sourceDoc})`;
    warnings.push(`${r.key}: 본문 잘림`);
  }
  issues.push({
    key: r.key, kind, title: `[${r.key}] ${r.title}`, type: ownerAction ? 'task' : r.type,
    epic: r.epic, phase: r.phase, sprint, ...(deferred ? { plannedSprint: r.sprint } : {}), points: r.points, prio: r.prio, area: r.area,
    labels, milestone: milestoneOf(r), deps, cardDeps, trace, ownerAction, proposal: r.proposal,
    status: r.proposal ? 'proposed' : 'adopted', ...(r.decisionAt ? { decisionAt: r.decisionAt } : {}),
    sourceDoc, body,
  });
}

// 에픽 이슈
const epicIssues = epics.map((e) => {
  const children = issues.filter((i) => i.epic === e.key);
  const adopted = children.filter((i) => !i.proposal);
  const body = [
    `> **${e.key}** · 에픽 · 단계 ${e.phases} · 채택 ${adopted.length}건 ${adopted.reduce((s, i) => s + i.points, 0)}점`,
    `> 정본: [02 §6 에픽](${BLOB}${INDEX}#6-에픽) · 색인: [02 §8](${BLOB}${INDEX}#8-전체-스토리-색인)`,
    '',
    `**목표**: ${e.goal}`,
    '',
    `**PRD 근거**: ${e.prdRefs}`,
    '',
    '**완료 기준**: 하위 항목이 모두 Done이고, 에픽에 걸린 PRD 수용 기준이 모두 테스트 증빙을 가진다. 여러 단계에 걸친 에픽은 마지막 단계 종료 검토(V1-T06)에서 닫는다.',
    '',
    '<!-- df-links:start -->',
    '**하위 항목**',
    ...children.map((i) => `- [ ] ${i.key} ${i.title.replace(/^\[DF-\d{3}\] /, '')}${i.proposal ? ' (제안)' : ''}`),
    '<!-- df-links:end -->',
  ].join('\n');
  return {
    key: e.key, kind: 'epic', title: `[${e.key}] ${e.name}`, type: 'epic', epic: null, phase: e.phases,
    sprint: null, points: 0, prio: null, area: null, labels: ['type/epic'], milestone: null,
    deps: [], cardDeps: [], trace: splitList(e.prdRefs), ownerAction: false, proposal: false, status: 'adopted',
    children: children.map((i) => i.key), sourceDoc: `${INDEX}#6-에픽`, body,
  };
});

// ---------- 5. 합계 ----------
const all = [...epicIssues, ...issues];
const adopted = issues.filter((i) => !i.proposal);
const phases = ['P0', 'P1a', 'P1b', 'P2', 'P3', 'V2'];
const totals = {
  epics: epicIssues.length,
  adopted: { count: adopted.length, points: adopted.reduce((s, i) => s + i.points, 0) },
  proposals: { count: issues.length - adopted.length, points: issues.filter((i) => i.proposal).reduce((s, i) => s + i.points, 0) },
  byKind: Object.fromEntries(['story', 'chore', 'spike', 'owner-action'].map((k) => [k, adopted.filter((i) => i.kind === k).length])),
  byPhase: Object.fromEntries(phases.map((p) => { const a = adopted.filter((i) => i.phase === p); return [p, { count: a.length, points: a.reduce((s, i) => s + i.points, 0) }]; })),
  byMilestone: Object.fromEntries(Object.values(MS).map((m) => { const a = adopted.filter((i) => i.milestone === m); return [m, { count: a.length, points: a.reduce((s, i) => s + i.points, 0) }]; })),
  byScope: Object.fromEntries(['scope/mvp', 'scope/carryover', 'scope/deferred'].map((l) => { const a = adopted.filter((i) => i.labels.includes(l)); return [l.slice(6), { count: a.length, points: a.reduce((s, i) => s + i.points, 0) }]; })),
  // 연기 항목은 sprint가 'MVP 뒤'라 한 행으로 모인다. S02~S13 행은 MVP와 진행 중(carryover) 항목만 센다.
  bySprint: Object.fromEntries([...new Set(adopted.map((i) => i.sprint))].sort((a, b) => (sprintNo(a) ?? 999) - (sprintNo(b) ?? 999)).map((s) => { const a = adopted.filter((i) => i.sprint === s); return [s, { count: a.length, points: a.reduce((t, i) => t + i.points, 0) }]; })),
};

const out = {
  docId: 'TL-05',
  title: 'D-FET Coach v1 GitHub 이슈 데이터(에픽·스토리·스파이크·잡무·소유자 행동)',
  version: '1.0',
  generatedFrom: [INDEX, ...cardFiles.map((f) => posix.join(CARD_DIR, f))],
  generator: 'tool/backlog/build_issues.mjs',
  repo: REPO,
  note: '생성물. 손으로 고치지 않는다. 키·점수·의존은 02 §8 색인, 본문은 카드가 정본이다. proposal=true 항목은 채택 대기(status/needs-decision)이고 합계에서 뺀다. DEC-22: scope/mvp·scope/carryover가 없는 항목은 scope/deferred이고 sprint는 \'MVP 뒤\', 옛 계획 스프린트는 plannedSprint다.',
  totals,
  issues: all,
};
const json = JSON.stringify(out, null, 2) + '\n';

for (const w of warnings) console.error(`warn: ${w}`);
if (CHECK) {
  const cur = existsSync(join(root, OUT)) ? read(OUT) : '';
  if (cur !== json) { console.error(`${OUT} is stale. Run: node tool/backlog/build_issues.mjs`); process.exit(1); }
  console.log(`${OUT} up to date (${all.length} issues)`);
} else {
  writeFileSync(join(root, OUT), json);
  console.log(`wrote ${OUT}: ${epicIssues.length} epics + ${issues.length} items (adopted ${adopted.length}/${totals.adopted.points}pt, proposals ${totals.proposals.count}/${totals.proposals.points}pt), warnings ${warnings.length}`);
}

// 변경 이력
// | 버전 | 날짜 | 내용 |
// |---|---|---|
// | v1.0.1 | 2026-09-24 | 교차 정합성 조정: '카드가 더한 의존' 본문 머리글을 02 §8.8.1(채택 시 색인에 추가) 기준으로 바꿈(R3). 로직 변경 없음 |
// | v1.1 | 2026-09-25 | DEC-22: scope/mvp·scope/carryover가 없는 항목에 scope/deferred를 붙이고 sprint를 'MVP 뒤'(옛 값은 plannedSprint)로, 본문 머리에 연기 안내. totals.byScope 추가, bySprint는 MVP 스프린트와 연기를 나눈다 |

#!/usr/bin/env node
// TL-13 brief.mjs — 백로그 카드와 issues.json에서 AI 에이전트 작업 지시서(V1-T08)를 만든다.
// Node 22+ 내장 모듈만 쓴다. 파일만 읽고 네트워크·gh·git을 부르지 않는다(ASM-01-17, 00_README K-04).
//
// 사용: node tool/backlog/brief.mjs DF-NNN [--sprint SNN] [--agent claude|codex] [--slug <kebab>]
//                                   [--allow-deferred] [--files <issues.json>] [--repo-root <dir>] > brief.md
//
// DEC-22 범위: scope/mvp·scope/carryover 항목만 지시서를 만든다. scope/deferred(또는 scope/ 라벨 없음)는
// exit 1이다. --allow-deferred를 주면 stderr 경고와 지시서 맨 위 '연기 항목' 경고를 달고 만든다(MVP 뒤 재계획 검토용).
// --sprint의 같은 스프린트 목록은 scope/mvp·scope/carryover만 센다.
//
// 채우는 절(V1-T08 '사용법' 표)
//   0·10·11  고정문(템플릿)
//   1 목표          카드 '사용자 스토리'
//   2 추적          issues.json key·epic·phase·sprint·flag/ 라벨·trace, 카드 안 ADR 언급
//   3 컨텍스트 팩   카드 링크, 01 DoD·권한 경계, 13 §7, area별 필독(13 §6), trace의 PRD §, 스프린트 문서 '필독'
//   4 작업 범위     스프린트 문서의 수정 허용·금지 경로(§5 레인 표, §8 지시서 표), 카드 '에이전트 브리프'
//                   --sprint를 주면 같은 스프린트의 다른 에이전트 스토리와 그 경로를 덧붙인다
//   5 인터페이스    카드 '구현 노트'(원문)
//   6 수용 기준     카드 '수용 기준'과 '테스트'(원문)
//   7 구현 메모     카드 '배경·맥락', '비고·가정', 'DoR'
//   8 검증 명령     area별 기본 명령(01 영역별 DoD, 13 §4) + 카드·스프린트 문서의 명령
//                   (--apply, firebase deploy, 자리 표시자가 든 명령은 넣지 않는다. 소유자가 실행하는 수용 기준·테스트 줄의
//                   명령, 에뮬레이터 밖의 functions/scripts/(migrations|research)/, 명령이 아닌 낱말·CI 전용 줄도 뺀다)
//   9 브랜치·커밋   브랜치는 스프린트 문서 → --slug → 제목의 영문 낱말 순서로 정한다
//                   에이전트는 --agent → (--sprint를 줬으면) 스프린트 문서 레인·브랜치 → agent/ 라벨 순서로 정한다.
//                   스프린트 문서와 라벨이 다르면 stderr에 경고한다
//
// 종료 코드: 0 성공, 1 대상이 아님(없는 키, 에픽, 소유자 행동, 연기 항목, 에이전트 미정, 카드 없음), 2 사용법 오류
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, posix } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = 'TEhyeok/DFET_Coach';
const BLOB = `https://github.com/${REPO}/blob/main/`;
const CARD_DIR = 'docs/v1/backlog';
const SPRINT_DIR = 'docs/v1/sprints';

// ---------- 인자 ----------
const USAGE = 'usage: node tool/backlog/brief.mjs DF-NNN [--sprint SNN] [--agent claude|codex] [--slug <kebab>] [--allow-deferred] [--files <issues.json>] [--repo-root <dir>]';
const here = dirname(fileURLToPath(import.meta.url));
const opts = { root: resolve(here, '..', '..'), key: null, sprint: null, agent: null, slug: null, files: null, allowDeferred: false };
{
  const argv = process.argv.slice(2);
  const need = (i) => { if (i >= argv.length || argv[i].startsWith('--')) usage(`${argv[i - 1]} needs a value`); return argv[i]; };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-h' || a === '--help') { console.log(USAGE); process.exit(0); }
    else if (a === '--sprint') opts.sprint = need(++i);
    else if (a === '--agent') opts.agent = need(++i);
    else if (a === '--slug') opts.slug = need(++i);
    else if (a === '--files') opts.files = need(++i);
    else if (a === '--allow-deferred') opts.allowDeferred = true;
    else if (a === '--repo-root') opts.root = resolve(need(++i));
    else if (a.startsWith('--')) usage(`unknown option ${a}`);
    else if (!opts.key) opts.key = a;
    else usage(`unexpected argument ${a}`);
  }
  if (!opts.key || !/^DF-\d{3}$/.test(opts.key)) usage('first argument must be a story key like DF-011');
  if (opts.sprint && !/^S\d{2}$/.test(opts.sprint)) usage('--sprint must look like S01');
  if (opts.agent && !['claude', 'codex'].includes(opts.agent)) usage('--agent must be claude or codex');
  if (opts.slug && !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(opts.slug)) usage('--slug must be kebab-case ascii');
}
function usage(msg) { console.error(`error: ${msg}\n${USAGE}`); process.exit(2); }
function fail(msg) { console.error(`error: ${msg}`); process.exit(1); }

const rootRel = (p) => join(opts.root, p);
const read = (p) => readFileSync(rootRel(p), 'utf8');

// ---------- 데이터 ----------
const issuesPath = opts.files ? resolve(opts.files) : rootRel('tool/backlog/issues.json');
const issues = JSON.parse(readFileSync(issuesPath, 'utf8')).issues;
const byKey = new Map(issues.map((x) => [x.key, x]));
const item = byKey.get(opts.key);
if (!item) fail(`${opts.key} not found in ${issuesPath}`);
if (item.kind === 'epic') fail(`${opts.key} is an epic`);
const labelAgent = (it) => (it.labels.find((l) => /^agent\/(claude|codex)$/.test(l)) || '').slice(6) || null;
if (item.ownerAction || (item.labels.includes('agent/human') && !labelAgent(item))) fail(`${opts.key} is an owner/human task (agent/human); no agent brief`);
// DEC-22 범위. scope/ 라벨이 없는 옛 issues.json도 연기로 본다.
const inMvp = (it) => it.labels.includes('scope/mvp') || it.labels.includes('scope/carryover');
const deferred = !inMvp(item);
const MVP_PLAN_URL = `${BLOB}docs/v1/03_RELEASE_AND_SPRINT_PLAN.md#mvp-계획dec-22`;
if (deferred) {
  const was = item.plannedSprint || item.sprint || '-';
  if (!opts.allowDeferred) fail(`${opts.key} is deferred (scope/deferred, DEC-22; old plan ${was}): not in the 1-person alpha MVP, so no agent brief. Re-plan it after the MVP exit review (03 MVP 계획), or pass --allow-deferred to build one anyway`);
  console.error(`warning: ${opts.key} is deferred (scope/deferred, DEC-22; old plan ${was}); building the brief because --allow-deferred was given`);
}

// ---------- 마크다운 도구 ----------
// 상대 링크를 GitHub blob 절대 링크로 바꾼다(지시서는 이슈 코멘트로 붙으므로 상대 링크가 깨진다). build_issues.mjs와 같은 규칙.
function absolutize(md, fileRel) {
  const dir = posix.dirname(fileRel);
  return md.replace(/\]\(([^)\s]+)\)/g, (all, target) => {
    if (/^(https?:|mailto:)/.test(target)) return all;
    if (target.startsWith('#')) return `](${BLOB}${fileRel}${target})`;
    const [p, anchor] = target.split('#');
    const resolved = posix.normalize(posix.join(dir, p));
    if (resolved.startsWith('..')) return all;
    return `](${BLOB}${resolved}${anchor !== undefined ? '#' + anchor : ''})`;
  });
}
const cells = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, '|'));
// 인라인 코드만 모은다(코드 펜스 안은 명령이 아니라 예시다).
const ticks = (s) => [...s.replace(/```[\s\S]*?```/g, '').matchAll(/`([^`\n]+)`/g)].map((m) => m[1]);
const trimBlock = (s) => s.replace(/^\s*\n/, '').replace(/\s+$/, '');

// 마크다운 표들을 {header, rows}로 모은다(구분선 행 기준).
function tables(text) {
  const out = [];
  const ls = text.split('\n');
  for (let i = 0; i + 1 < ls.length; i++) {
    if (!/^\s*\|/.test(ls[i]) || !/^\s*\|[\s:|-]+\|\s*$/.test(ls[i + 1])) continue;
    const header = cells(ls[i]);
    const rows = [];
    let j = i + 2;
    for (; j < ls.length && /^\s*\|/.test(ls[j]); j++) rows.push(cells(ls[j]));
    out.push({ header, rows, line: i });
    i = j - 1;
  }
  return out;
}

// ---------- 카드 ----------
const MVP_HEADING = /^### MVP 범위\(DEC-22\)\s*$/;
function findCard(key) {
  const files = [];
  const src = item.sourceDoc?.split('#')[0];
  if (src && src.startsWith(`${CARD_DIR}/`) && existsSync(rootRel(src))) files.push(src);
  if (existsSync(rootRel(CARD_DIR))) for (const f of readdirSync(rootRel(CARD_DIR)).sort()) if (f.endsWith('.md')) files.push(`${CARD_DIR}/${f}`);
  for (const file of new Set(files)) {
    const ls = read(file).split('\n');
    const s = ls.findIndex((l) => l.startsWith(`### ${key} `));
    if (s < 0) continue;
    // '### MVP 범위(DEC-22)'는 카드 안의 절이다(02 §3 scope/mvp). 카드 끝으로 보지 않는다.
    let e = ls.findIndex((l, i) => i > s && (/^---\s*$/.test(l) || (/^#{1,3} /.test(l) && !MVP_HEADING.test(l))));
    if (e < 0) e = ls.length;
    return { file, lines: ls.slice(s, e) };
  }
  return null;
}
const card = findCard(opts.key);
if (!card) fail(`${opts.key}: no card in ${CARD_DIR}/*.md`);

// 카드 절: 줄 머리의 굵은 표제(**사용자 스토리.** 등)로 나눈다. P0·P1a·P1b·P2_P3 카드 형식을 모두 받는다.
const SECTION_LABELS = {
  story: '사용자 스토리', context: '배경·맥락', ac: '수용 기준', notes: '구현 노트',
  tests: '테스트', remarks: '비고·가정', dor: 'DoR', brief: '에이전트 브리프',
};
const labelRe = new RegExp(`^\\*\\*(${Object.values(SECTION_LABELS).join('|')})(?: 체크)?[.:]?\\*\\*\\s*(?:[—–:-]\\s*)?(.*)$`);
const section = {};
{
  let cur = null;
  for (const line of card.lines.slice(1)) {
    if (MVP_HEADING.test(line)) { cur = 'mvp'; section.mvp = []; continue; }
    const m = labelRe.exec(line);
    if (m) {
      cur = Object.keys(SECTION_LABELS).find((k) => SECTION_LABELS[k] === m[1]);
      section[cur] = m[2] ? [m[2]] : [];
      continue;
    }
    if (cur) section[cur].push(line);
  }
  for (const k of Object.keys(section)) section[k] = absolutize(trimBlock(section[k].join('\n')), card.file);
}
const cardText = card.lines.join('\n');
const cardUrl = `${BLOB}${card.file}#${opts.key.toLowerCase()}`;
const orNone = (s, fallback = '_카드에 없음._') => (s && s.trim() ? s : fallback);

// ---------- 스프린트 문서 ----------
function sprintFile(s) {
  const m = /^S(\d{2})$/.exec(s || '');
  if (!m) return null;
  const f = `${SPRINT_DIR}/SPRINT_${m[1]}.md`;
  return existsSync(rootRel(f)) ? f : null;
}
// 스프린트 문서에서 키 하나의 브랜치·수정 허용/금지 경로·필독·명령을 찾는다.
//  (a) '### … DF-NNN' 아래 항목|내용 표(§8.1~8.3), (b) 첫 칸이 DF-NNN인 행 표(§8.4), (c) 레인 표(§5, '순서' 칸에 키)
function sprintInfo(key, file) {
  const info = { branch: null, allowed: null, forbidden: null, lane: null, reading: null, commands: [] };
  if (!file) return info;
  const text = read(file);
  const ls = text.split('\n');
  const setIf = (k, v) => { if (v && !info[k]) info[k] = v; };
  const branchOf = (s) => ticks(s || '').find((t) => new RegExp(`^(claude|codex|[a-z]+)/${key}-`).test(t)) || null;
  // (a) 키가 제목에 든 절마다(작업 분해 절과 지시서 절이 따로 있을 수 있다)
  for (let h = 0; h < ls.length; h++) {
    if (!new RegExp(`^#{2,4} .*\\b${key}\\b`).test(ls[h])) continue;
    let e = ls.findIndex((l, i) => i > h && /^#{2,4} /.test(l));
    if (e < 0) e = ls.length;
    for (const t of tables(ls.slice(h, e).join('\n'))) {
      for (const [k, v] of t.rows) {
        if (k === '브랜치') setIf('branch', branchOf(v));
        else if (k === '수정 허용 경로') setIf('allowed', v);
        else if (/^금지 경로/.test(k)) setIf('forbidden', v);
        else if (k === '필독') setIf('reading', v);
        else if (k === '실행할 명령') info.commands.push(...ticks(v));
      }
    }
  }
  for (const t of tables(text)) {
    const col = (name) => t.header.findIndex((c) => c.includes(name));
    // (b)
    if (col('수정 허용 경로') >= 0) {
      for (const r of t.rows) {
        if (r[0] !== key) continue;
        setIf('allowed', r[col('수정 허용 경로')]);
        if (col('필독') >= 0) setIf('reading', r[col('필독')]);
        if (col('실행할 명령') >= 0) info.commands.push(...ticks(r[col('실행할 명령')]));
        if (col('브랜치') >= 0) setIf('branch', branchOf(r[col('브랜치')]));
      }
    }
    // (c)
    if (col('쓰기 허용 경로') >= 0 && col('순서') >= 0) {
      for (const r of t.rows) {
        if (!new RegExp(`\\b${key}\\b`).test(r[col('순서')] || '')) continue;
        if (col('브랜치') >= 0) setIf('branch', branchOf(r[col('브랜치')]));
        info.lane = { name: r[0], agent: col('에이전트') >= 0 ? r[col('에이전트')] : '', allowed: r[col('쓰기 허용 경로')], forbidden: col('쓰기 금지 경로') >= 0 ? r[col('쓰기 금지 경로')] : null };
      }
    }
  }
  if (!info.allowed && info.lane) info.allowed = info.lane.allowed;
  else if (info.lane && /레인/.test(info.allowed) && !info.allowed.includes(info.lane.allowed)) info.allowed = `${info.allowed}: ${info.lane.allowed}`;
  return info;
}
const inSprint = (it, s) => {
  if (!it.sprint) return false;
  if (it.sprint === s) return true;
  const m = /^S(\d+)-S(\d+)$/.exec(it.sprint);
  const n = Number(s.slice(1));
  return !!m && n >= Number(m[1]) && n <= Number(m[2]);
};

// ---------- area별 기본값(01 영역별 DoD, 13 §4 명령 모음, 13 §6 컨텍스트 팩) ----------
const AREA = {
  'trainer-app': {
    dod: '트레이너 iOS', scope: 'trainer',
    reading: ['docs/v1/04_ARCHITECTURE.md — 저장소 배치·TrainerKit 모듈·의존 그래프', 'docs/v1/07_TRAINER_APP_SPEC.md — 해당 TR 절', 'docs/v1/adr/ADR-001-independent-trainer-app.md', 'docs/v1/adr/ADR-002-local-first-swiftdata-outbox.md'],
    commands: ['xcodegen generate --spec trainer_app/project.yml --project trainer_app && git diff --exit-code -- trainer_app/DFETTrainer.xcodeproj', 'swift test --package-path trainer_app/Packages/TrainerCore', "xcodebuild test -project trainer_app/DFETTrainer.xcodeproj -scheme DFETTrainer -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'"],
  },
  'member-app': {
    dod: 'Flutter 회원 앱', scope: 'member',
    reading: ['docs/v1/08_MEMBER_APP_AND_ADMIN_SPEC.md — 해당 MB 절', 'docs/v1/adr/ADR-006-member-summaries.md'],
    commands: ['flutter analyze', 'flutter test'],
  },
  functions: {
    dod: 'Functions', scope: 'functions',
    reading: ['docs/v1/06_API_SPEC.md — 해당 함수 계약', 'docs/v1/adr/ADR-017-functions-structure.md', 'docs/v1/10_TEST_PLAN.md — §8 Functions 단위·e2e 테스트'],
    commands: ['npm --prefix functions run lint', 'npm --prefix functions test', 'firebase emulators:exec --only functions,firestore,storage --project dfet-e2e "npm --prefix functions run test:e2e"'],
  },
  rules: {
    dod: '보안 규칙·Storage·인덱스', scope: 'rules',
    reading: ['docs/v1/05_DATA_MODEL_AND_RULES.md — 규칙 설계·R/S 테스트 설계', 'docs/v1/10_TEST_PLAN.md — §7 보안 규칙·Storage 테스트', 'docs/v1/adr/ADR-003-uid-identity-pending-members.md'],
    commands: ['firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"'],
  },
  storage: {
    dod: '보안 규칙·Storage·인덱스', scope: 'storage',
    reading: ['docs/v1/05_DATA_MODEL_AND_RULES.md — 규칙 설계·R/S 테스트 설계', 'docs/v1/adr/ADR-007-storage-binaries-lidar-local.md'],
    commands: ['firebase emulators:exec --only firestore,storage --project dfet-rules-test "npm --prefix functions run test:rules"'],
  },
  'admin-web': {
    dod: '관리자 웹', scope: 'admin',
    reading: ['docs/v1/08_MEMBER_APP_AND_ADMIN_SPEC.md — 해당 AD 절', 'docs/v1/adr/ADR-018-admin-claim-unification.md'],
    commands: ['npm --prefix admin_web run lint', 'npm --prefix admin_web run typecheck', 'npm --prefix admin_web test', 'npm --prefix admin_web run build'],
  },
  contracts: {
    dod: '계약', scope: 'contracts',
    reading: ['docs/v1/adr/ADR-005-soap-schema-v2-contracts.md', 'docs/v1/05_DATA_MODEL_AND_RULES.md — contracts JSON 스키마 절', 'docs/v1/10_TEST_PLAN.md — §6 계약·교차 클라이언트 테스트'],
    commands: ['node tool/contracts/generate.mjs --check', 'jq empty schemas/*.json'],
  },
  privacy: {
    dod: 'Functions', scope: null,
    reading: ['docs/v1/adr/ADR-011-consent-model.md', 'docs/v1/adr/ADR-015-analytics-privacy.md', 'docs/v1/12_COPY_ANALYTICS_AND_LINT.md — 이벤트 레지스트리'],
    commands: [],
  },
  analytics: {
    dod: null, scope: null,
    reading: ['docs/v1/adr/ADR-015-analytics-privacy.md', 'docs/v1/12_COPY_ANALYTICS_AND_LINT.md — 이벤트 레지스트리'],
    commands: [],
  },
  design: {
    dod: null, scope: null,
    reading: ['docs/v1/12_COPY_ANALYTICS_AND_LINT.md — 문구 키', 'docs/v1/adr/ADR-016-regulatory-copy-lint.md'],
    commands: [],
  },
  ci: {
    dod: '문서', scope: 'ci',
    reading: ['docs/v1/10_TEST_PLAN.md — §19 CI 워크플로', 'tool/backlog/README.md (TL-01)', 'docs/v1/adr/ADR-014-branching-release.md'],
    commands: [],
  },
  docs: {
    dod: '문서', scope: 'docs',
    reading: ['docs/v1/00_README.md — 문서 지도'],
    commands: ['node tool/lint/doc-headers.mjs --links docs/v1'],
  },
  bodypath: {
    dod: null, scope: 'bodypath',
    reading: ['docs/v1/adr/ADR-012-bodypath-result-package.md', 'docs/v1/10_TEST_PLAN.md — §3.7 BodyPathCore'],
    commands: [],
  },
};
const PATH_COMMANDS = [ // 인라인 코드로 적힌 수정 경로 → 명령(스프린트 문서 수정 허용 경로, 카드 구현 노트·에이전트 브리프)
  [/^tool\/backlog\//, ['node tool/backlog/build_issues.mjs --check', 'node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md tool/backlog/issues.json', 'bash tool/backlog/test/run.sh', 'bash tool/backlog/create_backlog.sh --dry-run --offline']],
  [/^docs\/v1\//, ['node tool/lint/doc-headers.mjs --links docs/v1']],
];
const areas = item.labels.filter((l) => l.startsWith('area/')).map((l) => l.slice(5));
const primaryArea = item.area || areas[0] || null;

// ---------- 계산 ----------
const sprintForLookup = opts.sprint || (/^S\d{2}$/.test(item.sprint || '') ? item.sprint : null);
const sFile = sprintFile(sprintForLookup);
const sInfo = sprintInfo(opts.key, sFile);

// 스프린트 문서가 정한 에이전트: 레인 표의 '에이전트' 칸, 없으면 브랜치 접두(claude/…, codex/…)
function sprintAgent(info) {
  const lane = /^(claude|codex)$/i.exec((info.lane?.agent || '').trim());
  if (lane) return lane[1].toLowerCase();
  const b = /^(claude|codex)\//.exec(info.branch || '');
  return b ? b[1] : null;
}
// --agent → (--sprint를 줬으면) 스프린트 문서 → 라벨. 문서와 라벨이 다르면 경고한다(조용히 버리지 않는다).
function resolveAgent(it, info, sprintGiven, warn) {
  const lab = labelAgent(it);
  const doc = sprintAgent(info);
  if (doc && lab && doc !== lab && warn) {
    console.error(`warning: ${it.key}: sprint doc assigns ${doc}${info.branch ? ` (\`${info.branch}\`)` : ''} but issues.json label is agent/${lab}; ` +
      (opts.agent ? `using --agent ${opts.agent}` : sprintGiven ? `using the sprint doc (${doc})` : `using the label (${lab}); pass --sprint or --agent to override`) +
      '. Fix the label or the sprint doc in a docs follow-up.');
  }
  return (sprintGiven && doc) ? doc : lab;
}
const agent = opts.agent ?? resolveAgent(item, sInfo, !!opts.sprint, true);
if (!agent) fail(`${opts.key} has no agent/claude or agent/codex label; pass --agent claude|codex`);

function slugFromTitle(t) {
  const stop = new Set(['json', 'md', 'mjs', 'js', 'sh', 'yml', 'v1', 'v2', 'the', 'and', 'ci']);
  const words = (t.replace(/^\[[^\]]+\]\s*/, '').match(/[A-Za-z][A-Za-z0-9]*/g) || []).map((w) => w.toLowerCase()).filter((w) => !stop.has(w) && w.length > 1);
  const uniq = [...new Set(words)].slice(0, 3);
  return uniq.length ? uniq.join('-') : (primaryArea || 'story');
}
// 스프린트 문서의 브랜치는 배정 에이전트와 맞을 때만 쓴다(다른 에이전트 접두면 버린다. 예: docs/DF-001-…는 그대로 쓴다).
let branch = sInfo.branch && (sInfo.branch.startsWith(`${agent}/`) || !/^(claude|codex)\//.test(sInfo.branch)) ? sInfo.branch : null;
if (opts.slug) branch = `${agent}/${opts.key}-${opts.slug}`;
if (!branch) branch = `${agent}/${opts.key}-${slugFromTitle(item.title)}`;

const COMMIT_TYPE = { story: 'feat', chore: 'chore', spike: 'docs', docs: 'docs', test: 'test', bug: 'fix', migration: 'feat', task: 'chore' };
const ctype = COMMIT_TYPE[item.type] || 'chore';
const scope = AREA[primaryArea]?.scope;
const flags = item.labels.filter((l) => l.startsWith('flag/')).map((l) => l.slice(5));
const traceIds = item.trace.join(', ');
const adrs = [...new Set([...item.trace.filter((t) => /^ADR-\d{3}$/.test(t)), ...(cardText.match(/ADR-\d{3}/g) || [])])].sort();
const prdSections = item.trace.filter((t) => t.startsWith('§'));
const epic = item.epic ? byKey.get(item.epic) : null;
const epicTitle = epic ? epic.title.replace(/^\[[^\]]+\]\s*/, '') : '';

// 검증 명령: area 기본 + 경로 기반 + 스프린트 문서 + 카드. 위험하거나 자리 표시자가 든 명령은 뺀다.
// 실행 파일 이름 바로 뒤에 공백이 와야 한다(node:test, swift-snapshot-testing, swift-tools-version:5.9 같은 낱말을 거른다).
const COMMAND_RE = /^(?:(?:node|npm|npx|bash|flutter|swift|xcodebuild|xcodegen|jq|shellcheck)\s+\S|firebase emulators:exec\s|git diff\s)/;
// 운영 데이터를 읽을 수 있는 스크립트: 에뮬레이터 안(firebase emulators:exec 또는 --emulator)에서만 허용한다(13 §7).
const PROD_SCRIPT_RE = /\bfunctions\/scripts\/(migrations|research)\//;
const inEmulator = (c) => /^firebase emulators:exec\s/.test(c) || /(^|\s)--emulator(\s|=|$)/.test(c);
const unsafe = (c) =>
  /^(xcodebuild|swift) \w+$/.test(c) || (/^xcodebuild\s/.test(c) && !/ -(project|workspace|scheme) /.test(c)) ||
  /--apply\b|firebase deploy|\bgh\s|…|\.\.\.|<[^>]*>|DF-NNN|\bSNN\b/.test(c) || /\bgh (issue|label|api|project)\b/.test(c) ||
  /\$\{?GITHUB_/.test(c) || // CI 전용 줄
  (PROD_SCRIPT_RE.test(c) && !inEmulator(c)) ||
  /^node tool\/contracts\/generate\.mjs(?!.*\s--check\b)/.test(c) || // --check 없는 생성기는 파일을 쓴다
  /^node\s.*(\s|")test\//.test(c); // cwd 기준 test/(패키지 안에서만 뜻이 있다. 루트 test/는 Flutter 테스트다)
const commands = [];
// Node 22의 --test는 디렉터리 인자를 펼치지 않는다. 'node --test dir/'는 'node --test dir/*.test.mjs'로 바꾼다.
const addCmd = (c) => { const x = c.trim().replace(/^node --test (\S+)\/$/, 'node --test $1/*.test.mjs'); if (x && COMMAND_RE.test(x) && !unsafe(x) && !commands.includes(x)) commands.push(x); };
for (const a of areas) for (const c of AREA[a]?.commands ?? []) addCmd(c);
const scopeText = [sInfo.allowed || '', section.notes || '', section.brief || ''].join('\n');
const scopePaths = ticks(scopeText);
for (const [re, cs] of PATH_COMMANDS) if (scopePaths.some((p) => re.test(p))) cs.forEach(addCmd);
sInfo.commands.forEach(addCmd);
// 수용 기준·테스트에서 소유자가 실행하는 줄(예: 'Given 소유자가 `… --dry-run`을 실행')의 명령은 에이전트 검증 명령이 아니다.
const OWNER_ACTOR = /소유자가/;
const agentLines = (s) => (s || '').split('\n').filter((l) => !OWNER_ACTOR.test(l)).join('\n');
for (const k of ['ac', 'tests']) for (const t of ticks(agentLines(section[k]))) addCmd(t);
for (const k of ['notes', 'brief']) for (const t of ticks(section[k] || '')) addCmd(t);

// 컨텍스트 팩
const reading = [
  `이 스토리 카드 전문: ${cardUrl}`,
  'docs/v1/01_AGILE_WORKING_AGREEMENT.md — \'에이전트 권한 경계\', \'완료 정의(DoD)\' 공통' + ([...new Set(areas.map((a) => AREA[a]?.dod).filter(Boolean))].map((d) => ` + '${d}'`).join('')),
  'docs/v1/13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md — §7 금지 행동과 비밀·실데이터 규칙',
];
if (!deferred) reading.push('docs/v1/03_RELEASE_AND_SPRINT_PLAN.md — \'MVP 계획(DEC-22)\': 지금 적용되는 범위·스프린트·MVP 공통 규칙(01 스프린트 달력은 DEC-22 이전 계획)');
if (prdSections.length) reading.push(`docs/PRD_V1.md — ${prdSections.join(', ')} (절 단위로만 읽는다)`);
for (const a of areas) for (const r of AREA[a]?.reading ?? []) if (!reading.includes(r)) reading.push(r);
for (const adr of adrs) {
  const f = existsSync(rootRel('docs/v1/adr')) ? readdirSync(rootRel('docs/v1/adr')).find((x) => x.startsWith(adr)) : null;
  const p = f ? `docs/v1/adr/${f}` : `${adr}`;
  if (!reading.some((r) => r.startsWith(p))) reading.push(p);
}
if (sFile) reading.push(`${sFile} — 이 스토리의 작업 분해와 레인 규칙`);

// 같은 스프린트의 다른 에이전트 작업(--sprint)
const others = [];
if (opts.sprint) {
  const sf = sprintFile(opts.sprint);
  for (const it of issues) {
    if (it.key === opts.key || it.kind === 'epic' || it.proposal || it.ownerAction) continue;
    if (!labelAgent(it) || !inMvp(it) || !inSprint(it, opts.sprint)) continue;
    const info = sprintInfo(it.key, sf);
    const ag = resolveAgent(it, info, true, false);
    const paths = info.allowed ? info.allowed : `area ${it.area ?? '-'}, 카드 ${BLOB}${it.sourceDoc}`;
    others.push(`  - ${it.key} (${ag}${info.branch ? `, \`${info.branch}\`` : ''}): ${paths}`);
  }
}

// ---------- 출력 ----------
const title = item.title;
const genCmd = ['node tool/backlog/brief.mjs', opts.key, ...(opts.sprint ? ['--sprint', opts.sprint] : []), ...(opts.agent ? ['--agent', opts.agent] : []), ...(opts.slug ? ['--slug', opts.slug] : []), ...(opts.allowDeferred ? ['--allow-deferred'] : [])].join(' ');
const out = [];
const push = (...xs) => out.push(...xs);
push(
  `# 작업 지시서: ${title}`,
  '',
  `> \`${genCmd}\`가 카드(${card.file})와 \`tool/backlog/issues.json\`에서 생성했다(V1-T08). 카드를 고친 뒤 다시 생성한다. 손으로 고치지 않는다.`,
  '',
  ...(deferred ? [`> **연기 항목(DEC-22, \`scope/deferred\`). 1인 알파 MVP 범위가 아니다.** 소유자가 MVP 뒤 재계획에서 이 항목을 스프린트에 다시 넣기 전에는 구현하지 않는다. 옛 계획 스프린트: ${item.plannedSprint || item.sprint || '-'}. [03 MVP 계획](${MVP_PLAN_URL})`, ''] : []),
  `너는 D-FET Coach v1 저장소(${REPO}, 트렁크 main)에서 **이 스토리 하나만** 구현하는 코딩 에이전트다.`,
  '결과물은 draft PR 하나와 이슈 완료 보고 하나다.',
  '',
  '## 0. 절대 규칙',
  `- 브랜치: \`${branch}\`만 쓴다. main 푸시·병합·태그·자동 병합 금지.`,
  '- GitHub 이슈를 만들지 않는다. 라벨·마일스톤·Projects를 바꾸지 않는다.',
  '- 비밀 파일(.env*, functions/.secret.local, GoogleService-Info.plist 값, 인증서, 키)과 output/·tmp/·내보내기·회원 데이터를 열거나 출력하지 않는다.',
  '- 운영 Firebase 프로젝트(dfetmanage)를 가리키는 명령(firebase deploy, 이관 --apply 등)을 실행하지 않는다. 에뮬레이터와 합성 데이터만 쓴다.',
  '- docs/PRD_V1.md를 수정하지 않는다. 고칠 점은 PR 본문 \'PRD 수정 제안\'에 적는다.',
  '- 아래 \'수정 허용 경로\' 밖을 고쳐야 하면 멈추고 완료 보고의 \'막힘\'에 적는다.',
  '- 새 의존성(npm, SPM, pub)을 추가하지 않는다(지시서가 허용한 것 제외).',
  '- PRD가 모호하면 추측하지 말고 가장 보수적인 해석(숨김, 저장 안 함, 판정 안 함)을 택하고 \'AS-DEV-후보\'로 보고한다.',
  '',
  '## 1. 목표',
  orNone(section.story),
  '',
  '## 2. 추적',
  `- 스토리: ${opts.key} (에픽 ${item.epic ?? '-'}${epicTitle ? ` ${epicTitle}` : ''}, 단계 ${item.phase}, 스프린트 ${item.sprint ?? '-'}${item.plannedSprint ? `(옛 계획 ${item.plannedSprint})` : ''}, ${item.points}점, 우선 ${item.prio ?? '-'}, 플래그 ${flags.length ? flags.join(', ') : '없음'})`,
  `- PRD: ${traceIds || '없음'}`,
  `- 관련 ADR: ${adrs.length ? adrs.join(', ') : '없음'}`,
  `- 먼저 끝나야 하는 항목: ${item.deps.length ? item.deps.join(', ') : '없음'}${item.cardDeps.length ? ` (카드가 더한 의존: ${item.cardDeps.join(', ')})` : ''}`,
  `- 라벨: ${item.labels.map((l) => `\`${l}\``).join(' ')}`,
  '',
  '## 3. 컨텍스트 팩(이 순서로 읽는다)',
  ...reading.map((r, i) => `${i + 1}. ${r}`),
);
if (sInfo.reading) push('', `스프린트 문서의 필독: ${absolutize(sInfo.reading, sFile)}`);
push(
  '',
  '## 4. 작업 범위',
  `- 수정 허용 경로(생성·수정): ${sInfo.allowed ? absolutize(sInfo.allowed, sFile) : '카드 \'구현 노트\'(5절)와 \'에이전트 브리프\'(아래)에 적힌 파일만. 그 밖은 멈추고 보고한다.'}`,
  `- 금지 경로(열지도 않음): 비밀 파일, output/, tmp/, 회원 데이터. 수정 금지: docs/PRD_V1.md${sInfo.forbidden ? `, ${absolutize(sInfo.forbidden, sFile)}` : ''}${sInfo.lane?.forbidden ? `, 레인 ${sInfo.lane.name} 쓰기 금지 경로 ${absolutize(sInfo.lane.forbidden, sFile)}` : ''}`,
);
if (opts.sprint) push(`- 같은 스프린트(${opts.sprint})의 다른 에이전트 작업(건드리지 않음):`, ...(others.length ? others : ['  - 없음']));
if (section.mvp) push('', 'MVP 범위(DEC-22, 카드 원문). \'MVP 뒤로 미룬다\'에 적힌 것은 만들지 않는다:', '', section.mvp);
if (item.labels.includes('scope/mvp')) push('', 'MVP 공통 규칙(DEC-22, 03 \'MVP 공통 규칙\'): 분석 이벤트는 MVP 뒤다(DF-126·DF-033). 카드의 분석 이벤트 수용 기준·`TrainerAnalyticsTests` 테스트·이벤트 전송 코드는 만들지 않는다. 연기 항목(`scope/deferred`)의 코드·API에 기대지 않는다.');
push(
  '',
  '카드의 에이전트 브리프(소유자 작성):',
  '',
  orNone(section.brief),
  '',
  '## 5. 인터페이스 계약',
  '카드 \'구현 노트\' 원문이다. 경로·시그니처·예시는 이대로 따른다.',
  '',
  orNone(section.notes),
  '',
  '## 6. 수용 기준(원문)',
  `카드 원문을 그대로 옮겼다(바꿔 쓰지 않는다). 테스트 이름에는 수용 기준 ID를 넣는다(01 DoD).`,
  '',
  orNone(section.ac),
  '',
  '테스트(카드):',
  '',
  orNone(section.tests),
  '',
  '## 7. 구현 메모',
  '배경·맥락(카드):',
  '',
  orNone(section.context),
  '',
  `- 비고·가정: ${orNone(section.remarks, '없음')}`,
  `- DoR: ${orNone(section.dor, '카드에 없음')}`,
  '',
  '## 8. 검증 명령(모두 통과해야 PR을 Ready로 올릴 수 있다)',
  '```bash',
  ...(commands.length ? commands : ['# 카드와 area에서 찾은 명령이 없다. 카드 \'테스트\' 표의 검증을 수행하고 결과를 PR에 적는다']),
  '```',
  '- 로컬에서 못 돌리는 검증(macOS 전용 등)은 CI 결과 링크로 대신하고 보고에 적는다.',
  '- `--apply`, `firebase deploy`, gh 쓰기 명령은 이 목록에 넣지 않는다. 카드에 있더라도 에이전트는 실행하지 않는다.',
  '',
  '## 9. 브랜치·커밋·PR',
  `- 브랜치: ${branch}`,
  `- 커밋 제목: ${ctype}${scope ? `(${scope})` : ''}: <요약, 72자 이하>  (스쿼시 제목 끝에 \` (${opts.key})\`)`,
  '- 커밋 footer:',
  `  Refs: ${opts.key}`,
  `  Trace: ${traceIds || '-'}`,
  '- PR: draft로 열고 .github/pull_request_template.md를 모두 채운다. 본문 첫 줄 `Closes #<이슈 번호>`.',
  '',
  '## 10. 막혔을 때',
  '- 30분 이상 같은 오류가 반복되면 멈추고 보고한다(우회 구현 금지).',
  '- 범위 밖 수정이 필요하면 멈추고 보고한다.',
  '- 테스트를 끄거나 skip하지 않는다.',
  '',
  '## 11. 완료 보고(이슈 코멘트, 이 형식 그대로)',
  '```markdown',
  `## 완료 보고 ${opts.key}`,
  `- 브랜치 / PR: ${branch} / #<PR>`,
  '- 수용 기준: <ID>: 통과(<test name>) | <ID>: 수동 확인 필요(<사유>)',
  '- 실행한 명령과 결과: `<cmd>` → pass (<n> tests)',
  '- 수정한 경로: <목록> (허용 경로 안: 예/아니오)',
  '- 가정(AS-DEV-후보): 없음 | <내용, 관련 PRD Q-/AS->',
  '- PRD 수정 제안: 없음 | <내용>',
  '- 남은 위험·후속(부채 후보): 없음 | <내용>',
  '- 막힘: 없음 | <내용>',
  '- 비밀·실데이터 접근: 없음',
  '```',
  '',
);
process.stdout.write(out.join('\n'));

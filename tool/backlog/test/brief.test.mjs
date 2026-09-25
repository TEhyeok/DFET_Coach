// brief.mjs(TL-13, ASM-01-17, 00_README K-04) 테스트. node:test, Node 22 내장 모듈만. 네트워크 없음.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..', '..');
const script = join(root, 'tool/backlog/brief.mjs');
const issues = JSON.parse(readFileSync(join(root, 'tool/backlog/issues.json'), 'utf8')).issues;
const p0 = readFileSync(join(root, 'docs/v1/backlog/P0.md'), 'utf8');

const brief = (...args) => {
  const r = spawnSync(process.execPath, [script, ...args], { cwd: root, encoding: 'utf8' });
  return { code: r.status, out: r.stdout, err: r.stderr };
};
const sectionOf = (md, n) => {
  const s = md.indexOf(`\n## ${n}. `);
  const e = md.indexOf('\n## ', s + 1);
  return s < 0 ? '' : md.slice(s, e < 0 ? undefined : e);
};
const commandsOf = (md) => {
  const s8 = sectionOf(md, 8);
  const m = /```bash\n([\s\S]*?)\n```/.exec(s8);
  return m ? m[1].split('\n').filter((l) => l && !l.startsWith('#')) : [];
};
const SECTIONS = ['0. 절대 규칙', '1. 목표', '2. 추적', '3. 컨텍스트 팩', '4. 작업 범위', '5. 인터페이스 계약', '6. 수용 기준(원문)', '7. 구현 메모', '8. 검증 명령', '9. 브랜치·커밋·PR', '10. 막혔을 때', '11. 완료 보고'];

test('brief DF-002 --sprint S01 fills every V1-T08 section from the card and issues.json', () => {
  const r = brief('DF-002', '--sprint', 'S01');
  assert.equal(r.code, 0, r.err);
  assert.ok(r.out.startsWith('# 작업 지시서: [DF-002] '));
  let last = -1;
  for (const s of SECTIONS) {
    const i = r.out.indexOf(`\n## ${s}`);
    assert.ok(i > last, `section "${s}" present and in order`);
    last = i;
  }
  // 2 추적: issues.json 값
  assert.match(sectionOf(r.out, 2), /스토리: DF-002 \(에픽 EP-01 .*단계 P0, 스프린트 S01, 2점/);
  assert.match(sectionOf(r.out, 2), /PRD: §0\.5, §12\.1/);
  // 6 수용 기준: 카드 원문 그대로(AC-DF-002.4 문구)
  const acLine = p0.split('\n').find((l) => l.includes('issues.json: DF-00x trace F-SOAP-99 not found in PRD'));
  assert.ok(acLine, 'fixture: card has the AC-DF-002.4 line');
  assert.ok(sectionOf(r.out, 6).includes(acLine.trim()), 'AC quoted verbatim');
  for (const k of [1, 2, 3, 4, 5]) assert.ok(sectionOf(r.out, 6).includes(`AC-DF-002.${k}`));
  // 9 브랜치·커밋: 스프린트 문서의 브랜치, footer
  assert.match(r.out, /^- 브랜치: claude\/DF-002-backlog-tooling$/m);
  assert.match(r.out, /^ {2}Refs: DF-002$/m);
  assert.match(r.out, /^ {2}Trace: §0\.5, §12\.1$/m);
  assert.match(r.out, /^- 커밋 제목: chore\(ci\): /m);
  // 4 작업 범위: SPRINT_01 §8.4의 허용 경로
  assert.match(sectionOf(r.out, 4), /수정 허용 경로\(생성·수정\): `tool\/backlog\/\*\*`만\(ci\.yml 금지\)/);
});

test('brief --sprint lists the other agent stories of the sprint (not itself, not owner actions)', () => {
  const r = brief('DF-002', '--sprint', 'S01');
  const s4 = sectionOf(r.out, 4);
  const expected = issues
    .filter((i) => i.sprint === 'S01' && i.key !== 'DF-002' && !i.ownerAction && i.labels.some((l) => /^agent\/(claude|codex)$/.test(l)))
    .map((i) => i.key);
  assert.ok(expected.length >= 3, 'fixture: S01 has other agent stories');
  for (const k of expected) assert.match(s4, new RegExp(`^ {2}- ${k} \\(`, 'm'));
  assert.doesNotMatch(s4, /^ {2}- DF-002 /m);
  assert.doesNotMatch(s4, /^ {2}- DF-9\d\d /m);
  assert.match(s4, /DF-008 \(claude, `claude\/DF-008-trainer-app-skeleton`\): `trainer_app\/\*\*`/);
});

test('brief without --sprint has no same-sprint list', () => {
  const r = brief('DF-002');
  assert.equal(r.code, 0, r.err);
  assert.doesNotMatch(r.out, /같은 스프린트\(S\d{2}\)의 다른 에이전트 작업/);
});

test('brief verification commands include the card commands and never --apply or deploy', () => {
  const cmds = commandsOf(brief('DF-002').out);
  for (const c of [
    'node tool/backlog/validate_backlog.mjs --prd docs/PRD_V1.md tool/backlog/issues.json',
    'bash tool/backlog/test/run.sh',
    'bash tool/backlog/create_backlog.sh --dry-run --offline',
    'node --test tool/backlog/test/*.test.mjs',
  ]) assert.ok(cmds.includes(c), `has: ${c}`);
  assert.ok(cmds.every((c) => !/--apply|firebase deploy|\bgh /.test(c)), cmds.join('\n'));
});

test('brief is deterministic', () => {
  assert.equal(brief('DF-011', '--sprint', 'S03').out, brief('DF-011', '--sprint', 'S03').out);
});

test('brief --agent and --slug override the branch', () => {
  const r = brief('DF-002', '--agent', 'codex', '--slug', 'backlog-tools');
  assert.equal(r.code, 0, r.err);
  assert.match(r.out, /^- 브랜치: codex\/DF-002-backlog-tools$/m);
});

test('brief builds for every agent-assigned story without placeholders for card sections', () => {
  const keys = issues.filter((i) => i.kind !== 'epic' && !i.ownerAction && i.labels.some((l) => /^agent\/(claude|codex)$/.test(l))).map((i) => i.key);
  assert.ok(keys.length > 50);
  for (const k of keys) {
    const r = brief(k);
    assert.equal(r.code, 0, `${k}: ${r.err}`);
    assert.ok(!sectionOf(r.out, 1).includes('_카드에 없음._'), `${k}: story`);
    assert.ok(!sectionOf(r.out, 6).includes('_카드에 없음._'), `${k}: acceptance criteria`);
    assert.match(r.out, new RegExp(`^- 브랜치: (claude|codex|docs)/${k}-[a-z0-9-]+$`, 'm'), `${k}: branch`);
    assert.ok(commandsOf(r.out).every((c) => !/--apply|firebase deploy/.test(c)), `${k}: unsafe command`);
  }
});

test('brief refuses owner actions, epics, unknown keys; bad usage exits 2', () => {
  const owner = brief('DF-901');
  assert.equal(owner.code, 1);
  assert.match(owner.err, /DF-901 is an owner\/human task/);
  assert.equal(brief('DF-999').code, 1);
  assert.equal(brief('EP-01').code, 2);
  assert.equal(brief().code, 2);
  assert.equal(brief('DF-002', '--sprint', 'week1').code, 2);
  assert.equal(brief('DF-002', '--agent', 'gpt').code, 2);
});

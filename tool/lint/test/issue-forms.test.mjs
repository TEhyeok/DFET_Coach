// .github/ISSUE_TEMPLATE 이슈 폼 구조 테스트(DF-001: AC-DF-001.4, TC-DF001-04 자동 보조).
// 실행: node --test tool/lint/test/issue-forms.test.mjs
// GitHub가 렌더를 거부하는 흔한 오류(이름 3자 미만, 빈 description·body, id·label 중복)를 줄 단위로 잡는다.
// Node 22 내장 모듈만 쓴다(ASM-S01-03). YAML 전체 파서가 아니라 이 저장소 폼의 들여쓰기 규약(2칸)을 전제한다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const formsDir = path.join(repoRoot, '.github/ISSUE_TEMPLATE');

// P0 DF-001 카드 001-1: config + 폼 6종 = 7종
const EXPECTED_FORMS = ['bug.yml', 'epic.yml', 'owner_action.yml', 'spike.yml', 'story.yml', 'task.yml'];

function unquote(v) {
  const s = v.trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) return s.slice(1, -1);
  return s;
}

/** 최상위 스칼라와 body 요소 목록을 뽑는다. */
function parseForm(text) {
  const lines = text.split(/\r?\n/);
  const top = {};
  const body = [];
  let inBody = false;
  let cur = null;
  lines.forEach((line, idx) => {
    if (/^\s*#/.test(line) || line.trim() === '') return;
    const topMatch = line.match(/^([A-Za-z_]+):\s*(.*)$/);
    if (topMatch) {
      top[topMatch[1]] = unquote(topMatch[2]);
      inBody = topMatch[1] === 'body';
      cur = null;
      return;
    }
    if (!inBody) return;
    const typeMatch = line.match(/^ {2}- type:\s*(\S+)/);
    if (typeMatch) {
      cur = { type: typeMatch[1], line: idx + 1, id: null, label: null };
      body.push(cur);
      return;
    }
    if (!cur) return;
    const idMatch = line.match(/^ {4}id:\s*(.+)$/);
    if (idMatch) cur.id = unquote(idMatch[1]);
    const labelMatch = line.match(/^ {6}label:\s*(.+)$/);
    if (labelMatch) cur.label = unquote(labelMatch[1]);
  });
  return { top, body };
}

test('AC-DF-001.4 이슈 폼 6종과 config.yml이 있다(7종)', () => {
  const files = readdirSync(formsDir).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml')).sort();
  assert.deepEqual(files, ['config.yml', ...EXPECTED_FORMS].sort());
});

test('config.yml은 빈 이슈를 막고 비공개 보안 신고 링크를 둔다', () => {
  const text = readFileSync(path.join(formsDir, 'config.yml'), 'utf8');
  assert.match(text, /^blank_issues_enabled:\s*false\s*$/m);
  assert.match(text, /security\/advisories\/new/);
});

for (const file of EXPECTED_FORMS) {
  test(`AC-DF-001.4 ${file}: GitHub 이슈 폼 필수 규칙`, () => {
    const { top, body } = parseForm(readFileSync(path.join(formsDir, file), 'utf8'));

    // GitHub: "Name is too short (minimum is 3 characters)"
    assert.ok(top.name, 'name이 없다');
    assert.ok([...top.name].length >= 3, `name '${top.name}'이 3자 미만이다`);
    assert.ok(top.description && top.description.length > 0, 'description이 비어 있다');
    assert.equal(top.body, '', 'body는 목록이어야 한다');
    assert.ok(body.length > 0, 'body가 비어 있다');

    const fields = body.filter((e) => e.type !== 'markdown');
    assert.ok(fields.length > 0, 'body에 markdown이 아닌 입력 요소가 없다');

    const ids = new Set();
    const labels = new Set();
    for (const e of fields) {
      assert.ok(e.label, `${e.line}행 ${e.type}에 label이 없다`);
      assert.ok(!labels.has(e.label), `label '${e.label}'이 중복된다(${e.line}행)`);
      labels.add(e.label);
      if (e.id !== null) {
        assert.match(e.id, /^[A-Za-z0-9_-]+$/, `${e.line}행 id '${e.id}' 형식이 잘못됐다`);
        assert.ok(!ids.has(e.id), `id '${e.id}'가 중복된다(${e.line}행)`);
        ids.add(e.id);
      }
    }
  });
}

test('parseForm은 짧은 이름과 중복 id를 드러낸다(음성 대조)', () => {
  const bad = [
    'name: "버그"',
    'description: "x"',
    'body:',
    '  - type: input',
    '    id: a',
    '    attributes:',
    '      label: "A"',
    '  - type: input',
    '    id: a',
    '    attributes:',
    '      label: "B"',
  ].join('\n');
  const { top, body } = parseForm(bad);
  assert.equal([...top.name].length, 2);
  assert.deepEqual(body.map((e) => e.id), ['a', 'a']);
  assert.deepEqual(body.map((e) => e.label), ['A', 'B']);
});

// tool/lint/doc-headers.mjs 테스트(DF-001: TC-DF001-01, TC-DF001-02). 실행: node --test tool/lint/test/doc-headers.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { HEADER_ROWS, checkHeader, checkLinks, extractLinks, lint } from '../doc-headers.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const cli = path.join(repoRoot, 'tool/lint/doc-headers.mjs');
const fixtures = path.join(here, 'fixtures');
const docsV1 = path.join(repoRoot, 'docs/v1');

function run(...args) {
  return spawnSync(process.execPath, [cli, ...args], { cwd: repoRoot, encoding: 'utf8' });
}

// docs/v1만 복사하고 나머지 저장소 항목은 심볼릭 링크로 둔다. 문서 밖(../PRD_V1.md, ../../.github/...)으로
// 가는 상대 링크가 원본과 똑같이 풀리게 하기 위해서다.
function withTempCopy(fn) {
  const root = mkdtempSync(path.join(tmpdir(), 'doc-headers-'));
  try {
    for (const name of readdirSync(repoRoot)) {
      if (name !== 'docs' && name !== '.git') symlinkSync(path.join(repoRoot, name), path.join(root, name));
    }
    mkdirSync(path.join(root, 'docs'));
    for (const name of readdirSync(path.join(repoRoot, 'docs'))) {
      if (name !== 'v1') symlinkSync(path.join(repoRoot, 'docs', name), path.join(root, 'docs', name));
    }
    const copy = path.join(root, 'docs/v1');
    cpSync(docsV1, copy, { recursive: true });
    return fn(copy);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('AC-DF-001.1 docs/v1 전체가 헤더 표준을 통과한다(종료 코드 0)', () => {
  const r = run('docs/v1');
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^OK: \d+개 파일/);
});

test('AC-DF-001.5 docs/v1 상대 파일 링크 깨짐 0(--links, 종료 코드 0)', () => {
  const r = run('--links', 'docs/v1');
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /헤더 표준 \+ 상대 링크/);
});

test('경로를 주지 않으면 docs/v1을 검사한다', () => {
  const r = run();
  assert.equal(r.status, 0, r.stderr);
  const expected = lint([docsV1]).files.length;
  assert.match(r.stdout, new RegExp(`^OK: ${expected}개 파일`));
});

test('TC-DF001-01 헤더 행 하나를 지운 임시 사본은 종료 코드 1', () => {
  withTempCopy((copy) => {
    const f = path.join(copy, '04_ARCHITECTURE.md');
    const text = readFileSync(f, 'utf8');
    const stripped = text.replace(/^\| 작성일 \|.*\n/m, '');
    assert.notEqual(stripped, text, '작성일 행을 지우지 못했다');
    writeFileSync(f, stripped);
    const r = run(copy);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /04_ARCHITECTURE\.md:\d+: 헤더 표에 '작성일' 행이 없다/);
  });
});

test('TC-DF001-02 없는 파일로 가는 링크를 넣은 임시 사본은 --links에서 종료 코드 1과 파일:줄 보고', () => {
  withTempCopy((copy) => {
    const f = path.join(copy, '13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md');
    const text = readFileSync(f, 'utf8');
    const broken = `${text.replace(/\n*$/, '\n')}[깨진 링크](no-such-file.md#x)\n`;
    const line = broken.split('\n').length - 1; // 마지막 줄 번호
    writeFileSync(f, broken);
    const headersOnly = run(copy);
    assert.equal(headersOnly.status, 0, '링크 검사는 --links일 때만 한다');
    const r = run('--links', copy);
    assert.equal(r.status, 1);
    assert.ok(
      r.stderr.includes(`13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md:${line}: 깨진 상대 링크: no-such-file.md#x`),
      r.stderr,
    );
  });
});

test('AC-DF-001.1 01_AGILE_WORKING_AGREEMENT.md에 문서 변경 절이 없으면 실패', () => {
  withTempCopy((copy) => {
    const f = path.join(copy, '01_AGILE_WORKING_AGREEMENT.md');
    writeFileSync(f, readFileSync(f, 'utf8').replace(/^## 문서 변경$/m, '## 문서 바꾸기'));
    const r = run(copy);
    assert.equal(r.status, 1);
    assert.match(r.stderr, /01_AGILE_WORKING_AGREEMENT\.md:1: '## 문서 변경' 절이 없다/);
  });
});

test('픽스처 good.md는 헤더·링크 모두 통과', () => {
  const r = run('--links', 'tool/lint/test/fixtures/good.md');
  assert.equal(r.status, 0, r.stderr);
});

test('픽스처 missing-toc.md는 목차 없음으로 실패', () => {
  const r = run('tool/lint/test/fixtures/missing-toc.md');
  assert.equal(r.status, 1);
  assert.match(r.stderr, /missing-toc\.md:14: 헤더 표 다음에 '## 목차'가 없다/);
});

test('픽스처 bad-link.md는 헤더는 통과하고 --links에서 깨진 링크 한 건', () => {
  assert.equal(run('tool/lint/test/fixtures/bad-link.md').status, 0);
  const r = run('--links', 'tool/lint/test/fixtures/bad-link.md');
  assert.equal(r.status, 1);
  const reported = r.stderr.split('\n').filter((l) => l.includes('깨진 상대 링크'));
  assert.deepEqual(reported, ['tool/lint/test/fixtures/bad-link.md:21: 깨진 상대 링크: does-not-exist.md#어딘가']);
});

test('첫 줄 제목, 헤더 표, 중복·빈 값·정의되지 않은 행을 각각 보고한다', () => {
  const rows = HEADER_ROWS.map((h) => `| ${h} | 값 |`);
  const ok = ['# 제목', '', '| 항목 | 내용 |', '|---|---|', ...rows, '', '## 목차', ''].join('\n');
  assert.deepEqual(checkHeader('x.md', ok), []);

  assert.match(checkHeader('x.md', ok.replace('# 제목', '제목'))[0].message, /첫 줄이 '# '/);
  assert.match(checkHeader('x.md', '# 제목\n\n## 목차\n')[0].message, /헤더 표가 없다/);

  const dup = ok.replace('| 버전 | 값 |', '| 버전 | 값 |\n| 버전 | 값 |');
  assert.ok(checkHeader('x.md', dup).some((e) => /'버전' 행이 두 번/.test(e.message)));
  const empty = ok.replace('| 소유자 | 값 |', '| 소유자 |  |');
  assert.ok(checkHeader('x.md', empty).some((e) => /'소유자' 값이 비어/.test(e.message)));
  const extra = ok.replace('| 버전 | 값 |', '| 버전 | 값 |\n| 비고 | 값 |');
  assert.ok(checkHeader('x.md', extra).some((e) => /정의되지 않은 행 '비고'/.test(e.message)));
});

test('링크 추출은 코드 블록·인라인 코드를 건너뛰고 외부 URL과 앵커 단독 링크는 검사하지 않는다(ASM-P0-23)', () => {
  const text = [
    '[a](a.md) `[b](b.md)` [c](<c d.md> "제목") [e](#앵커) [f](https://example.com/x.md)',
    '```',
    '[g](g.md)',
    '```',
    '~~~~',
    '```',
    '[h](h.md)',
    '~~~~',
    '![그림](img/i.png)',
  ].join('\n');
  assert.deepEqual(
    extractLinks(text).map((l) => `${l.line}:${l.target}`),
    ['1:a.md', '1:c d.md', '1:#앵커', '1:https://example.com/x.md', '9:img/i.png'],
  );
  const errs = checkLinks(path.join(fixtures, 'x.md'), text, { repoRoot });
  assert.deepEqual(errs.map((e) => e.message), [
    '깨진 상대 링크: a.md',
    '깨진 상대 링크: c d.md',
    '깨진 상대 링크: img/i.png',
  ]);
});

test('알 수 없는 옵션·없는 경로는 종료 코드 2', () => {
  assert.equal(run('--bogus').status, 2);
  assert.equal(run('no/such/dir').status, 2);
});

for (const entry of ['AGENTS.md', 'CLAUDE.md']) {
  test(`AC-DF-001.2 ${entry}에 'D-FET Coach v1 개발' 절이 있고 V1-00·V1-13 링크가 풀린다`, () => {
    const file = path.join(repoRoot, entry);
    const text = readFileSync(file, 'utf8');
    const start = text.indexOf('\n## D-FET Coach v1 개발\n');
    assert.ok(start >= 0, '절 제목이 없다');
    const section = text.slice(start + 1).split(/\n(?=## )/)[0];
    const targets = extractLinks(section).map((l) => l.target);
    assert.ok(targets.includes('docs/v1/00_README.md'));
    assert.ok(targets.includes('docs/v1/13_DEV_ENVIRONMENT_AND_AGENT_PLAYBOOK.md'));
    assert.deepEqual(checkLinks(file, section, { repoRoot }), []);
    const bullets = section.split('\n').filter((l) => l.startsWith('- '));
    assert.equal(bullets.length, 5, '절 본문은 5줄');
    assert.equal(bullets.filter((l) => l.startsWith('- 금지:')).length, 2);
  });
}

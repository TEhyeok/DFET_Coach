// tool/lint/prohibited-terms.mjs 테스트(DF-010: TC-DF010-01~04, AC-DF-010.1~.5).
// 실행: node --test tool/lint/test/prohibited-terms.test.mjs   (Node 22 내장 모듈만)
// 입력 샘플: tool/lint/test/fixtures/prohibited-terms/. CLI 테스트는 임시 저장소 루트를 만들어 돌린다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  RULES_FILE,
  compileRules,
  extractContractLabels,
  extractDart,
  extractSwift,
  extractTs,
  extractXcstrings,
  formatViolation,
  globToRegExp,
  lintSource,
  normalize,
  ruleSetsFor,
  scanText,
  targetFiles,
} from '../prohibited-terms.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const cli = path.join(repoRoot, 'tool/lint/prohibited-terms.mjs');
const fixtures = path.join(here, 'fixtures/prohibited-terms');
const rulesDoc = JSON.parse(readFileSync(path.join(repoRoot, RULES_FILE), 'utf8'));
const compiled = compileRules(rulesDoc);

const DISCLAIMER = '운동 지도와 건강관리 기록용이며 진단이나 치료를 위한 정보가 아닙니다.';
const LINE_FORMAT = /^(\S.*?):(\d+):(\d+) \[(common|member|trainer|causal)\/([A-Za-z0-9-]+)\] .+ → .+$/;

const fixture = (name) => readFileSync(path.join(fixtures, name), 'utf8');
const hasHangul = (s) => /[가-힣]/.test(s);
// 추출 결과에서 한글이 든 텍스트만 원문 순서대로.
const texts = (items) => items.map((i) => i.text).filter(hasHangul);
const ids = (hits) => [...new Set(hits.map((h) => h.ruleId))].sort();
const scan = (text, ruleSets, extra = {}) => scanText(text, compiled, { ruleSets, ...extra });

function run(root, ...args) {
  const r = spawnSync(process.execPath, [cli, '--root', root, ...args], { encoding: 'utf8' });
  return { code: r.status, stdout: r.stdout, stderr: r.stderr };
}

// 규칙 파일 + {상대 경로: 내용} 파일로 임시 저장소 루트를 만든다.
function withRepo(files, fn) {
  const root = mkdtempSync(path.join(tmpdir(), 'copy-lint-'));
  try {
    mkdirSync(path.join(root, 'contracts'));
    cpSync(path.join(repoRoot, RULES_FILE), path.join(root, RULES_FILE));
    for (const [rel, content] of Object.entries(files)) {
      mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
      writeFileSync(path.join(root, rel), content);
    }
    return fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------------------------
// AC-DF-010.1 규칙 파일 구조(스키마 검증 자체는 tool/contracts/test/prohibited-terms.test.mjs가 ajv로 한다)

const C1_IDS = [
  'C1-01', 'C1-02', 'C1-03', 'C1-04', 'C1-05', 'C1-06', 'C1-07', 'C1-08', 'C1-09', 'C1-10', 'C1-11', 'C1-11b',
  'C1-12', 'C1-13', 'C1-14', 'C1-15', 'C1-16', 'C1-17', 'C1-18', 'C1-19', 'C1-20', 'C1-21', 'C1-22', 'C1-23',
];

test('AC-DF-010.1 ruleSets.common holds every appendix C.1 row with id, terms, alternatives, scopes, clinicalModeNote', () => {
  assert.deepEqual(rulesDoc.ruleSets.common.map((r) => r.id), C1_IDS);
  for (const r of rulesDoc.ruleSets.common) {
    assert.ok(r.terms.length > 0, `${r.id}.terms`);
    assert.ok(r.alternatives.length > 0, `${r.id}.alternatives`);
    assert.ok(r.scopes.length > 0, `${r.id}.scopes`);
    assert.equal(typeof r.clinicalModeNote, 'string', `${r.id}.clinicalModeNote`);
    assert.equal(r.severity, 'block', `${r.id}.severity`);
  }
  // C.1 대상 행 원문 용어가 빠지지 않았다(카드 구현 노트의 행 목록).
  const allTerms = rulesDoc.ruleSets.common.flatMap((r) => r.terms);
  for (const t of ['진단', '치료', '치료됨', '완치', '교정', '재활 보조', '재활 트레이닝', '회복', '재활훈련', '처방', '환자',
    '진료', 'KCD', '원인은', '거북목 개선', '통증 완화', '예방', '도수', '신체교정운동', '근골격 기능 등급', '체형 점수',
    '임상적으로 검증', '의료기관 수준', '정상', '비정상', '측정값']) {
    assert.ok(allTerms.includes(t), `term ${t}`);
  }
  // '측정값'은 LiDAR 베타 경로 한정 규칙이다.
  const c123 = rulesDoc.ruleSets.common.find((r) => r.id === 'C1-23');
  assert.ok(c123.onlyIn.globs.includes('trainer_app/Packages/TrainerKit/Sources/FeatureLidarBeta/**'));
});

test('AC-DF-010.1 member and trainer sets, causal patterns, trainer abbreviations, allow lists', () => {
  assert.deepEqual(rulesDoc.ruleSets.member.map((r) => r.id), ['C3-M-01', 'C3-M-02', 'C3-M-03', 'C3-M-04']);
  assert.deepEqual(rulesDoc.ruleSets.member.flatMap((r) => r.terms).slice(0, 4), ['개선', '악화', '판정', '의미 있는']);
  assert.deepEqual(rulesDoc.ruleSets.trainer, []);
  assert.deepEqual(rulesDoc.causalPatterns.map((p) => [p.id, p.severity]), [
    ['C2-01', 'warn'], ['C2-02', 'warn'], ['C2-03', 'warn'], ['C2-04', 'warn'],
  ]);
  assert.deepEqual(rulesDoc.abbreviationAllowlist.trainer, ['SOAP', 'ROM', 'AROM', 'PROM', 'MMT', 'NRS', 'MDC']);
  for (const p of ['docs/**', 'contracts/prohibited-terms.v1.json', 'contracts/fixtures/**', 'test/**', '**/Tests/**', 'functions/test/**', 'tool/lint/test/**']) {
    assert.ok(rulesDoc.allowPaths.includes(p), `allowPaths ${p}`);
  }
  // 예외 목록의 실제 문장은 §3.1 고지 원문뿐이다(카드 에이전트 브리프).
  assert.deepEqual(rulesDoc.allowEntries.map((e) => [e.id, e.kind, e.active]), [
    ['AE-01', 'regulatoryDisclaimer', true],
    ['AE-02', 'regulatoryDisclaimer', true],
  ]);
  assert.equal(rulesDoc.allowEntries[0].exactString, DISCLAIMER);
  assert.equal(rulesDoc.allowEntries[0].reason, '§3.1 고지 문구, 부정문');
  const ruleIds = new Set([...rulesDoc.ruleSets.common, ...rulesDoc.ruleSets.member].map((r) => r.id));
  for (const e of rulesDoc.allowEntries) for (const id of e.rules) assert.ok(ruleIds.has(id), `${e.id} → ${id}`);
});

// ---------------------------------------------------------------------------------------------
// TC-DF010-01 언어별 리터럴 추출(주석 제외, 보간 처리)

test('TC-DF010-01 Swift: literals only, comments skipped, interpolation masked, nested and multi-line literals', () => {
  const src = fixture('sample.swift');
  const got = texts(extractSwift(src));
  assert.ok(got.includes('체형 교정'));
  assert.ok(got.includes('치료계획') && got.includes('운동 계획'), 'strings nested in \\( ) are extracted');
  assert.ok(got.includes('재활 "트레이닝"'), 'raw string #"…"#');
  assert.ok(got.some((t) => t.includes('예방 안내')), 'multi-line """ literal');
  assert.ok(!got.some((t) => /처방|진료/.test(t)), 'nested block comment');
  assert.ok(!got.some((t) => t.includes('교정 in a trailing comment')));
  // 보간 바깥 텍스트만 검사한다: '진\(name)단'은 '진단'이 되지 않는다.
  const hits = lintSource('trainer_app/App/Sample.swift', src, compiled);
  const at = (term) => hits.filter((h) => h.term === term).map((h) => `${h.line}:${h.col}`);
  assert.deepEqual(at('진단'), ['11:24'], "only '회원 \\(name) 진단 기록' (line 11), not '진\\(name)단' or comments");
  assert.deepEqual(at('체형 교정'), ['10:13']);
  assert.deepEqual(at('치료계획'), ['13:31']);
  assert.deepEqual(at('예방'), ['17:9']);
  assert.ok(!hits.some((h) => h.line <= 3), 'comment lines 1-3 have no hits');
});

test('TC-DF010-01 Dart: single, double, triple and raw strings; ${…} and $name masked; comments skipped', () => {
  const src = fixture('sample.dart');
  const got = texts(extractDart(src));
  assert.ok(got.includes('자세교정'));
  assert.ok(got.some((t) => t.startsWith('회원 ') && t.endsWith(' 진단')));
  assert.ok(got.some((t) => t.includes('예방')), "'''…''' literal");
  assert.ok(got.includes('재활 $raw'), "r'…' keeps $ as text");
  assert.ok(got.includes("It's 치료"));
  assert.ok(!got.some((t) => t.includes('처방') || t.includes('comment')), 'comments (incl. nested /* */) are not extracted');
  assert.equal(got.filter((t) => t.includes('교정')).length, 1, "only '자세교정'; the trailing // 교정 comment is skipped");
  const hits = lintSource('lib/screens/insights/sample.dart', src, compiled);
  const terms = hits.map((h) => `${h.line}:${h.term}`);
  assert.deepEqual(terms, ['6:자세 교정', '7:진단', '9:개선', '12:예방', '13:재활', '14:치료']);
});

test('TC-DF010-01 TS/TSX: quoted and template literals outside ${…}, JSX text nodes and attributes, comments skipped', () => {
  const src = fixture('sample.tsx');
  const got = texts(extractTs(src));
  assert.ok(got.includes('처방 목록'));
  assert.ok(got.includes('진료 안내'));
  assert.ok(got.includes('재활'), "string inside ${…} is extracted on its own");
  assert.ok(got.includes('재활 트레이닝'), 'JSX text node');
  assert.ok(got.includes('명 예방 관리'), 'JSX text after {expr}');
  assert.ok(got.includes('정상 범위'), 'JSX attribute string');
  assert.ok(!got.some((t) => t.includes('comment')), 'line, block and JSX comments are skipped');
  const hits = lintSource('admin_web/app/sample/page.tsx', src, compiled);
  assert.deepEqual(hits.map((h) => `${h.line}:${h.col}:${h.ruleId}`), [
    '6:18:C1-08', '7:17:C1-10', '8:36:C1-06', '10:21:C1-22', '12:10:C1-06', '13:18:C1-15',
  ]);
});

test('TC-DF010-01 xcstrings: ko stringUnit values with their keys; comments and other languages skipped', () => {
  const raw = fixture('Localizable.xcstrings');
  const items = extractXcstrings(raw);
  assert.deepEqual(items.map((i) => [i.key, i.text]), [
    ['tr05.plan.title', '치료계획, 홈운동, 다음 세션'],
    ['tr13.title', '관측 단면 측정값'],
    ['tr11.title', '측정값을 하나 이상 입력하세요'],
  ]);
  const hits = lintSource('trainer_app/App/Resources/Localizable.xcstrings', raw, compiled);
  // TC-X-LINT-01: 파일·키·위치를 보고한다. '측정값'은 tr13. 키에서만 위반이다(C1-23 onlyIn).
  assert.deepEqual(hits.map((h) => [h.key, h.ruleId, h.line]), [
    ['tr05.plan.title', 'C1-03', 17],
    ['tr13.title', 'C1-23', 28],
  ]);
  assert.match(formatViolation(hits[0]), /^trainer_app\/App\/Resources\/Localizable\.xcstrings:17:\d+ \[common\/C1-03\] 치료계획 → .+ \(key tr05\.plan\.title\)$/);
});

test('TC-DF010-01 contracts: only nameKo and labelsKo values are checked', () => {
  const raw = `${JSON.stringify({
    contract: 'vocab',
    source: '치료 (not a label)',
    enums: { x: { values: ['a', 'b'], labelsKo: { a: '관찰', b: '치료 기록' } } },
    metrics: [{ metricCode: 'm', nameKo: '체형 점수' }],
  }, null, 2)}\n`;
  assert.deepEqual(extractContractLabels(raw).map((i) => i.text), ['관찰', '치료 기록', '체형 점수']);
  const hits = lintSource('contracts/vocab.v1.json', raw, compiled);
  assert.deepEqual(hits.map((h) => [h.ruleId, h.key]), [['C1-03', 'enums.x.labelsKo.b'], ['C1-19', 'metrics.0.nameKo']]);
});

// ---------------------------------------------------------------------------------------------
// TC-DF010-02 경로별 규칙 세트(AC-DF-010.4, ASM-P0-08)

test('AC-DF-010.4 TC-DF010-02 첫 일치 경로 규칙: insights는 member, trainer는 통과', () => {
  const src = "const label = '개선됐어요';\n";
  assert.deepEqual(ruleSetsFor('lib/screens/insights/insights_screen.dart', rulesDoc), ['common', 'member']);
  assert.deepEqual(ruleSetsFor('lib/screens/trainer/trainer_home.dart', rulesDoc), ['common', 'trainer']);
  const member = lintSource('lib/screens/insights/insights_screen.dart', src, compiled);
  assert.deepEqual(member.map((h) => `${h.ruleSet}/${h.ruleId}`), ['member/C3-M-01']);
  assert.deepEqual(lintSource('lib/screens/trainer/trainer_home.dart', src, compiled), []);
  // TC-X-LINT-03: 트레이너 경로의 '의미 있는 개선'은 통과, 회원 경로는 위반
  assert.deepEqual(lintSource('lib/widgets/shells/trainer_shell.dart', "'의미 있는 개선'", compiled), []);
  assert.deepEqual(ids(lintSource('lib/screens/home.dart', "'의미 있는 개선'", compiled)), ['C3-M-01', 'C3-M-04']);
});

test('TC-DF010-02 mapping for every scanned root; AppDelegate uses the trainer set', () => {
  const cases = {
    'trainer_app/App/AppDelegate.swift': ['common', 'trainer'],
    'trainer_app/App/Resources/Localizable.xcstrings': ['common', 'trainer'],
    'ios/Runner/AppDelegate.swift': ['common', 'trainer'],
    'ios/Runner/SceneDelegate.swift': ['common', 'member'],
    'lib/widgets/shells/trainer_shell.dart': ['common', 'trainer'],
    'lib/admin/admin_home.dart': ['common'],
    'lib/main.dart': ['common', 'member'],
    'admin_web/app/(console)/page.tsx': ['common'],
    'contracts/metric-catalog.v1.json': ['common', 'trainer'],
    'contracts/vocab.v1.json': ['common', 'trainer'],
  };
  for (const [rel, want] of Object.entries(cases)) assert.deepEqual(ruleSetsFor(rel, rulesDoc), want, rel);
  const trainerRunner = lintSource('ios/Runner/AppDelegate.swift', 'let s = "주호소, 악화/완화 요인"\n', compiled);
  assert.deepEqual(trainerRunner, [], "Runner trainer screens may say '악화' (ASM-12-17)");
});

test('TC-DF010-02 glob semantics and C1-23 path-only rule', () => {
  assert.ok(globToRegExp('**/Tests/**').test('trainer_app/Packages/TrainerCore/Tests/X/Y.swift'));
  assert.ok(globToRegExp('**/*.md').test('README.md'));
  assert.ok(!globToRegExp('lib/*.dart').test('lib/a/b.dart'));
  const lidar = 'trainer_app/Packages/TrainerKit/Sources/FeatureLidarBeta/LidarView.swift';
  assert.deepEqual(ids(lintSource(lidar, 'Text("관측 단면 측정값")', compiled)), ['C1-23']);
  assert.deepEqual(lintSource('trainer_app/Packages/TrainerKit/Sources/FeatureBodyComposition/X.swift', 'Text("측정값 입력")', compiled), []);
});

test('AC-DF-010.2 TC-DF010-02 scanned files: target roots only, allow and exclude paths skipped', () => {
  withRepo({
    'trainer_app/App/A.swift': 'let a = "치료"\n',
    'trainer_app/App/Resources/Localizable.xcstrings': fixture('Localizable.xcstrings'),
    'trainer_app/Packages/TrainerCore/Tests/XTests/XTests.swift': 'let a = "치료"\n',
    'trainer_app/Packages/TrainerCore/Sources/TrainerContracts/Generated/ProhibitedTerms.swift': 'let a = "치료"\n',
    'trainer_app/Packages/TrainerCore/.build/checkouts/dep/A.swift': 'let a = "치료"\n',
    'ios/Runner/AppDelegate.swift': 'let a = "치료"\n',
    'lib/main.dart': "const a = '치료';\n",
    'lib/contracts/generated/vocab.g.dart': "const a = '치료';\n",
    'admin_web/app/page.tsx': 'export default () => <p>치료</p>;\n',
    'admin_web/components/nav.ts': "export const a = '치료';\n",
    'admin_web/lib/copy.ts': "export const a = '치료';\n",
    'admin_web/lib/generated/contracts.ts': "export const a = '치료';\n",
    'admin_web/test/page.test.ts': "export const a = '치료';\n",
    'functions/src/index.js': "const a = '치료';\n",
    'contracts/vocab.v1.json': '{"enums": {"x": {"labelsKo": {"a": "치료"}}}}\n',
    'contracts/metric-catalog.v1.json': '{"metrics": [{"nameKo": "관찰"}]}\n',
    'docs/v1/notes.md': '치료\n',
  }, (root) => {
    assert.deepEqual(targetFiles(root, rulesDoc), [
      'admin_web/app/page.tsx',
      'admin_web/components/nav.ts',
      'admin_web/lib/copy.ts',
      'contracts/metric-catalog.v1.json',
      'contracts/vocab.v1.json',
      'ios/Runner/AppDelegate.swift',
      'lib/main.dart',
      'trainer_app/App/A.swift',
      'trainer_app/App/Resources/Localizable.xcstrings',
    ]);
    const r = run(root, '--mode=report');
    assert.equal(r.code, 0, r.stderr);
    const lines = r.stdout.trim().split('\n');
    const summary = lines.pop();
    for (const l of lines) assert.match(l, LINE_FORMAT);
    assert.match(summary, /^copy-lint \(report\): 9 violation\(s\) — 9 block, 0 warn — in 8 of 9 file\(s\)$/);
  });
});

// ---------------------------------------------------------------------------------------------
// TC-DF010-03 report exit 0 / block exit 1 / causal는 경고만(AC-DF-010.2, AC-DF-010.3, AC-DF-010.6)

const BLOCKING = { 'lib/screens/insights/x.dart': "const a = '체형교정 프로그램';\n" };
const CAUSAL_ONLY = { 'lib/screens/insights/x.dart': "const a = '스트레칭 때문에 CVA가 좋아졌어요';\n" };

test('AC-DF-010.2 TC-DF010-03 --mode=report exits 0 and prints path:line:col [ruleSet/id] term → 대체어', () => {
  withRepo(BLOCKING, (root) => {
    const r = run(root, '--mode=report');
    assert.equal(r.code, 0, r.stderr);
    assert.equal(r.stdout.split('\n')[0], 'lib/screens/insights/x.dart:1:12 [common/C1-05] 체형 교정 → 자세 정렬 관찰 | 자세 균형 운동 | 정렬 변화 기록');
    assert.equal(run(root).code, 0, 'report is the default mode');
    assert.equal(run(root, '--mode', 'report').code, 0);
  });
});

test('AC-DF-010.3 TC-DF010-03 --mode=block exits 1 on a block violation, 0 when clean', () => {
  withRepo(BLOCKING, (root) => {
    const r = run(root, '--mode=block');
    assert.equal(r.code, 1);
    assert.match(r.stderr, /1 block violation/);
  });
  withRepo({ 'lib/main.dart': "const a = '측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요';\n" }, (root) => {
    const r = run(root, '--mode=block');
    assert.equal(r.code, 0, r.stderr);
    assert.match(r.stdout, /0 violation\(s\)/);
  });
});

test('AC-DF-010.3 TC-DF010-03 causal patterns are warnings in both modes', () => {
  withRepo(CAUSAL_ONLY, (root) => {
    for (const mode of ['report', 'block']) {
      const r = run(root, `--mode=${mode}`);
      assert.equal(r.code, 0, `${mode}: ${r.stderr}`);
      assert.match(r.stdout, /^lib\/screens\/insights\/x\.dart:1:\d+ \[causal\/C2-01\] 때문에 → .+ \(warn\)$/m);
      assert.match(r.stdout, /1 violation\(s\) — 0 block, 1 warn/);
    }
  });
});

test('AC-DF-010.6 TC-DF010-03 --summary appends a Markdown table report', () => {
  withRepo({ ...BLOCKING, 'lib/screens/y.dart': "const b = '스트레칭 때문에 좋아졌어요 | 기록';\n" }, (root) => {
    const summary = path.join(root, 'step-summary.md');
    writeFileSync(summary, '# existing\n');
    const r = run(root, '--mode=report', '--summary', summary);
    assert.equal(r.code, 0, r.stderr);
    const md = readFileSync(summary, 'utf8');
    assert.ok(md.startsWith('# existing\n## copy-lint (report 모드)'), 'appends, does not overwrite');
    assert.match(md, /\| 위반 합계 \| 2 \|/);
    assert.match(md, /\| block \| 1 \|/);
    assert.match(md, /\| common\/C1-05 \| block \| 1 \|/);
    assert.match(md, /\| lib\/screens\/insights\/x\.dart:1:12 \| common\/C1-05 \| 체형 교정 \| 자세 정렬 관찰 \/ 자세 균형 운동 \/ 정렬 변화 기록 \|/);
    assert.match(md, /\| causal\/C2-01 \(warn\) \|/);
  });
});

test('TC-DF010-03 usage errors exit 2', () => {
  withRepo({}, (root) => {
    assert.equal(run(root, '--mode=strict').code, 2);
    assert.equal(run(root, '--bogus').code, 2);
    assert.equal(run(root, '--summary').code, 2);
    rmSync(path.join(root, RULES_FILE));
    const r = run(root);
    assert.equal(r.code, 2);
    assert.match(r.stderr, /prohibited-terms\.v1\.json not found/);
  });
});

// ---------------------------------------------------------------------------------------------
// TC-DF010-04 §3.1 정확 문자열 허용, 변형 문장 위반(AC-DF-010.5)

test('AC-DF-010.5 TC-DF010-04 exact §3.1 disclaimer is allowed; the same words elsewhere are violations', () => {
  assert.deepEqual(scan(DISCLAIMER, ['common', 'member']), []);
  assert.deepEqual(scan(DISCLAIMER, ['common', 'trainer']), []);
  assert.deepEqual(ids(scan('운동 지도와 건강관리 기록용이며 진단이 아닙니다.', ['common', 'trainer'])), ['C1-01']);
  assert.deepEqual(ids(scan(`${DISCLAIMER} 치료 안내`, ['common'])), ['C1-01', 'C1-03'], 'partial match is not allowed');
  assert.deepEqual(ids(scan('진단이나 치료를 위한 기록', ['common'])), ['C1-01', 'C1-03']);
  // 앱 파일 안에서도 같다: Dart 리터럴의 정확 문자열은 통과, 다른 문장은 위반
  const src = `const a = '${DISCLAIMER}';\nconst b = '이 점수는 건강관리 참고용이며 의료 진단이 아닙니다.';\n`;
  assert.deepEqual(lintSource('lib/screens/settings.dart', src, compiled).map((h) => `${h.line}:${h.ruleId}`), ['2:C1-01']);
});

test('TC-DF010-04 allow entries match after normalization only and inactive entries are ignored', () => {
  assert.deepEqual(scan(DISCLAIMER.replace(' ', '  ').replace('진단', '진​단'), ['common']), [], 'spacing and zero-width variants of the exact string');
  const doc = structuredClone(rulesDoc);
  doc.allowEntries[0].active = false;
  assert.deepEqual(ids(scanText(DISCLAIMER, compileRules(doc), { ruleSets: ['common'] })), ['C1-01', 'C1-03']);
});

// ---------------------------------------------------------------------------------------------
// 일치 규칙 벡터(docs/v1/12 §7.11 중 common·member·trainer·causal 세트 21개. ABBR·IDT 벡터는 해당 세트 도입 스토리에서)

const VECTORS = [
  ['PT-V01', ['common'], '체형교정 프로그램', ['C1-05']],
  ['PT-V02', ['common'], '자세 · 교정 운동', ['C1-05']],
  ['PT-V03', ['common', 'trainer'], '치료계획, 홈운동, 다음 세션', ['C1-03']],
  ['PT-V04', ['common'], '주간 빈도수 기록', []],
  ['PT-V05', ['common'], '도수치료 기록', ['C1-03', 'C1-16']],
  ['PT-V06', ['common'], '회원 기록과 일정이 정상적으로 정리되어 있습니다.', []],
  ['PT-V07', ['common'], '정상 범위 안이에요', ['C1-22']],
  ['PT-V08', ['common', 'member'], '측정 오차보다 큰 변화가 정한 목표 방향으로 나타났어요', []],
  ['PT-V09', ['common', 'member'], '의미있는 개선이 보여요', ['C3-M-01', 'C3-M-04']],
  ['PT-V10', ['common', 'trainer'], '의미 있는 개선', []],
  ['PT-V13', ['common', 'trainer'], '관측 단면 측정값', ['C1-23'], { key: 'tr13.title' }],
  ['PT-V14', ['common', 'trainer'], '측정값을 하나 이상 입력하세요', [], { key: 'tr11.title' }],
  ['PT-V15', ['common', 'trainer'], DISCLAIMER, []],
  ['PT-V16', ['common', 'trainer'], '운동 지도와 건강관리 기록용이며 진단이 아닙니다.', ['C1-01']],
  ['PT-V17', ['common'], '거북목 개선 프로그램', ['C1-11', 'C1-13']],
  ['PT-V18', ['common'], '재활 트레이닝', ['C1-06']],
  ['PT-V19', ['common'], '수술 후 환자용 코스', ['C1-09']],
  ['PT-V20', ['common'], '분석 정확도 95%', ['C1-21']],
  ['PT-V21', ['common'], '스트레칭 때문에 CVA가 좋아졌어요', ['C2-01']],
  ['PT-V24', ['common'], '체​형 교정', ['C1-05']],
  ['PT-V25', ['common', 'member'], '통증 점수(0–10)', []],
];

for (const [id, sets, text, want, extra = {}] of VECTORS) {
  test(`${id} [${sets.join('+')}] ${JSON.stringify(text).slice(0, 40)} → ${want.join(', ') || '위반 없음'}`, () => {
    assert.deepEqual(ids(scan(text, sets, extra)), want);
  });
}

test('one hit per rule for nested terms; different rules on the same span are both reported', () => {
  const hits = scan('체형 교정 운동', ['common']);
  assert.deepEqual(hits.map((h) => [h.ruleId, h.term, h.start, h.end]), [['C1-05', '체형 교정', 0, 5]]);
  assert.deepEqual(scan('거북목증후군', ['common']).map((h) => h.term), ['거북목증후군']);
  assert.deepEqual(scan('거북목 개선', ['common']).map((h) => h.ruleId), ['C1-11', 'C1-13']);
  assert.equal(scan('causal only in common: 때문에', ['trainer']).length, 0, 'causal patterns ride on the common set');
});

test('normalize keeps a map back to the input offsets', () => {
  const { text, map } = normalize('체​형  　교정');
  assert.equal(text, '체형 교정');
  assert.deepEqual(map, [0, 2, 3, 6, 7, 8]);
});

test('literals without Hangul are skipped (identifiers such as "diagnosis", "kcd")', () => {
  assert.deepEqual(scan('diagnosis', ['common']), []);
  assert.deepEqual(scan('kcdCode', ['common']), []);
  assert.deepEqual(ids(scan('KCD 코드 입력', ['common'])), ['C1-11']);
});

// ---------------------------------------------------------------------------------------------
// TC-DF010-05 현재 저장소 보고서(CI copy-lint job도 같은 명령을 돈다)

test('TC-DF010-05 report on this checkout exits 0 and every line has the report format', () => {
  const r = spawnSync(process.execPath, [cli, '--mode=report'], { cwd: repoRoot, encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  const lines = r.stdout.trim().split('\n');
  const summary = lines.pop();
  assert.match(summary, /^copy-lint \(report\): \d+ violation\(s\) — \d+ block, \d+ warn — in \d+ of \d+ file\(s\)$/);
  for (const l of lines) assert.match(l, LINE_FORMAT);
  const files = targetFiles(repoRoot, rulesDoc);
  for (const rel of ['ios/Runner/AppDelegate.swift', 'trainer_app/App/Resources/Localizable.xcstrings', 'contracts/metric-catalog.v1.json', 'contracts/vocab.v1.json']) {
    assert.ok(files.includes(rel), `${rel} is scanned`);
  }
  for (const prefix of ['lib/', 'admin_web/app/', 'admin_web/components/', 'trainer_app/']) {
    assert.ok(files.some((f) => f.startsWith(prefix)), `${prefix} is scanned`);
  }
  assert.ok(!files.some((f) => /\/generated\/|\/Generated\/|\/Tests\//.test(f)), 'generated and test files are not scanned');
});

'use strict';

// DF-109 MVP: the test consent document publish script. Builder output, argument guards and the default dry-run.
// No test here runs the script with --apply; the emulator e2e test calls publishConsentDocuments() directly.

const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const path = require('node:path');
const test = require('node:test');
const {
  EXIT_GUARD,
  PublishError,
  TEST_TITLE_PREFIX,
  TEST_TYPES,
  buildTestConsentDocuments,
  loadDeck,
  parseArgs,
  resolveTarget,
  splitItems,
} = require('../../../scripts/publish-test-consent-documents');

const SCRIPT = path.resolve(__dirname, '../../../scripts/publish-test-consent-documents.js');
const deck = loadDeck();

test('builds ①②③ as published test documents with IDs <type>--test-1 from the deck consentDraft texts', () => {
  const documents = buildTestConsentDocuments(deck);
  assert.deepEqual([...TEST_TYPES], ['required', 'healthData', 'bodyImaging']);
  assert.deepEqual(documents.map((d) => d.id), ['required--test-1', 'healthData--test-1', 'bodyImaging--test-1']);
  for (const {id, data} of documents) {
    assert.deepEqual(Object.keys(data).sort(), [
      'consentType', 'items', 'privacyPolicyVersion', 'purpose', 'recipient', 'refusalNotice', 'retention',
      'schemaVersion', 'status', 'title', 'version',
    ], id);
    assert.equal(id, `${data.consentType}--${data.version}`);
    assert.equal(data.status, 'published');
    assert.equal(data.schemaVersion, 1);
    assert.equal(data.recipient, null);
    assert.equal(data.privacyPolicyVersion, 'test-placeholder');
    // Test marker on the title, deck text verbatim after it.
    assert.equal(data.title, `${TEST_TITLE_PREFIX}${deck.strings[`consentDraft.${data.consentType}.title`].ko}`);
    assert.equal(data.purpose, deck.strings[`consentDraft.${data.consentType}.purpose`].ko);
    assert.equal(data.refusalNotice, deck.strings[`consentDraft.${data.consentType}.refusalNotice`].ko);
    // The five notice fields are filled (V1-05 §4.13) and no deck placeholder is left.
    for (const field of ['title', 'purpose', 'retention', 'refusalNotice']) {
      assert.ok(data[field].trim().length > 0, `${id}.${field}`);
      assert.doesNotMatch(data[field], /[{}]/, `${id}.${field}`);
    }
    assert.ok(data.items.length >= 1, `${id}.items`);
  }
});

test('the undecided retention month count (Q-24) stays the marked placeholder N', () => {
  const healthData = buildTestConsentDocuments(deck).find((d) => d.data.consentType === 'healthData');
  assert.match(healthData.data.retention, /^\[법률 검토 대기\] .* N개월 /);
});

test('splitItems keeps commas inside parentheses', () => {
  assert.deepEqual(splitItems('체성분 결과(체중, 체지방률), 키, 둘레'), ['체성분 결과(체중, 체지방률)', '키', '둘레']);
});

test('dry-run is the default; --apply needs --project', () => {
  assert.deepEqual(resolveTarget(parseArgs([]), {}), {mode: 'dry-run'});
  assert.deepEqual(resolveTarget(parseArgs(['--project', 'demo-dfet']), {}), {mode: 'dry-run'});
  assert.throws(() => resolveTarget(parseArgs(['--apply']), {}), PublishError);
  assert.throws(() => parseArgs(['--force']), PublishError);
  assert.throws(() => parseArgs(['--project']), PublishError);
});

test('guards: an emulator project needs FIRESTORE_EMULATOR_HOST, a real project refuses it (exit 2)', () => {
  const guard = (argv, env) => assert.throws(() => resolveTarget(parseArgs(argv), env),
    (error) => error instanceof PublishError && error.exitCode === EXIT_GUARD);
  guard(['--apply', '--project', 'demo-dfet'], {});
  guard(['--apply', '--project', 'dfetmanage'], {FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080'});
  assert.deepEqual(resolveTarget(parseArgs(['--apply', '--project', 'demo-dfet']), {FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080'}),
    {mode: 'apply', projectId: 'demo-dfet', emulator: true});
  assert.deepEqual(resolveTarget(parseArgs(['--apply', '--project', 'dfetmanage']), {}),
    {mode: 'apply', projectId: 'dfetmanage', emulator: false});
});

test('running the script without flags prints the three documents and writes nothing', () => {
  const env = {...process.env};
  delete env.FIRESTORE_EMULATOR_HOST;
  delete env.GOOGLE_APPLICATION_CREDENTIALS;
  const output = execFileSync(process.execPath, [SCRIPT], {env, encoding: 'utf8'});
  assert.match(output, /consentDocumentVersions\/required--test-1/);
  assert.match(output, /consentDocumentVersions\/healthData--test-1/);
  assert.match(output, /consentDocumentVersions\/bodyImaging--test-1/);
  assert.match(output, /\[dry-run\] 3 test consent documents\. Nothing was written\./);
});

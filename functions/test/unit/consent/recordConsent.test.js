'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {core, handler} = require('../../../src/consent/recordConsent');
const {buildDocuments, parseArgs, main} = require('../../../scripts/dev/publish-test-consent-documents');

test('AC-DF-109.9 callable uses v2 and Seoul; auth is checked before database access', async () => {
  assert.equal(handler.__endpoint.platform, 'gcfv2');
  assert.deepEqual(handler.__endpoint.region, ['asia-northeast3']);
  assert.ok(handler.__endpoint.callableTrigger);
  await assert.rejects(core(null, null, null, {}), error => error.code === 'unauthenticated');
  await assert.rejects(core(null, null, {uid: 'synthMember', token: {}}, {}),
    error => error.code === 'permission-denied');
});

test('AC-DF-109.5 publication has all notice fields and is dry-run unless explicitly applied', async () => {
  const documents = buildDocuments();
  assert.equal(Object.keys(documents).length, 3);
  for (const [id, value] of Object.entries(documents)) {
    assert.equal(id, `${value.consentType}--${value.version}`);
    for (const field of ['title', 'purpose', 'retention', 'refusalNotice', 'privacyPolicyVersion']) {
      assert.equal(typeof value[field], 'string');
      assert.ok(value[field].length > 0);
    }
    assert.ok(Array.isArray(value.items) && value.items.length > 0);
    assert.equal(value.status, 'published');
    assert.match(value.title, /테스트 전용/);
  }
  assert.deepEqual(parseArgs([]), {apply: false, project: null});
  assert.throws(() => parseArgs(['--apply']), /explicit --project/);
  await assert.rejects(main(['--apply', '--project', 'demo-dfet'], {}), /requires FIRESTORE_EMULATOR_HOST/);
  await assert.rejects(main(['--apply', '--project', 'unrecognized-project'], {}), /owner-only/);
});

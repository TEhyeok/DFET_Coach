// DF-035 인사이트 정책 읽기: R-25. 트레이너는 승인·활성 bodyChange 정책만 읽는다(V1-05 §7.9).
// 모든 식별자와 값은 합성이다.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {collection, doc, getDoc, getDocs, query, where} = require('firebase/firestore');
const h = require('./_harness');

let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-policies'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    'insightPolicyVersions/fx-policy-active': {kind: 'bodyChange', version: 'fx-1', status: 'approved', active: true},
    // 거부 사례는 조건 하나만 어긋난다: 상태만 draft / active만 false / kind만 다름
    'insightPolicyVersions/fx-policy-draft': {kind: 'bodyChange', version: 'fx-2', status: 'draft', active: true},
    'insightPolicyVersions/fx-policy-inactive': {kind: 'bodyChange', version: 'fx-3', status: 'approved', active: false},
    'insightPolicyVersions/fx-policy-other-kind': {kind: 'integrated', version: 'fx-4', status: 'approved', active: true},
  });
});

describe('insightPolicyVersions trainer read (R-25)', () => {
  test('R-25 trainer cannot read a draft bodyChange policy (active=true, only status differs)', async () => {
    await assertFails(getDoc(doc(h.trainerDb(env), 'insightPolicyVersions/fx-policy-draft')));
  });

  test('R-25 trainer cannot read an approved but inactive bodyChange policy', async () => {
    await assertFails(getDoc(doc(h.trainerDb(env), 'insightPolicyVersions/fx-policy-inactive')));
  });

  test('R-25 trainer cannot read an approved active policy of another kind', async () => {
    await assertFails(getDoc(doc(h.trainerDb(env), 'insightPolicyVersions/fx-policy-other-kind')));
  });

  test('R-25 trainer reads the approved active bodyChange policy', async () => {
    await assertSucceeds(getDoc(doc(h.trainerDb(env), 'insightPolicyVersions/fx-policy-active')));
  });

  test('R-25 trainer list with kind, status and active in where is allowed; without active it is denied', async () => {
    const policies = collection(h.trainerDb(env), 'insightPolicyVersions');
    await assertSucceeds(getDocs(query(policies,
      where('kind', '==', 'bodyChange'), where('status', '==', 'approved'), where('active', '==', true))));
    await assertFails(getDocs(query(policies, where('kind', '==', 'bodyChange'), where('status', '==', 'approved'))));
  });
});

// DF-022 담당 관계 규칙: R-05~R-07 (V1-05 §9.2, AC-DF-022.1, AC-DF-022.2, AC-LINK-03.1·03.2).
// posture·bodyComposition·pendingMembers 문서는 withSecurityRulesDisabled로 시드한다(규칙은 DF-021).
const assert = require('node:assert/strict');
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {
  collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2, pendA} = h.IDS;
let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-assignment'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function baseSeed({memberIdsA = [member1]} = {}) {
  return {
    ...h.seedTrainer(trainerA, memberIdsA),
    ...h.seedTrainer(trainerB, [member2]),
    ...h.seedConsent(member1, {healthData: true, bodyImaging: true}),
    ...h.seedConsent(member2, {healthData: true}),
    ...h.seedFlags(),
  };
}

// 목록 쿼리가 거부되거나, 허용되더라도 결과에 금지 문서가 없어야 한다.
async function assertListHides(q, forbiddenIds) {
  let snap;
  try {
    snap = await getDocs(q);
  } catch (err) {
    assert.equal(err.code, 'permission-denied', `unexpected error ${err.code}`);
    return;
  }
  const ids = snap.docs.map((d) => d.id);
  for (const id of forbiddenIds) {
    assert.ok(!ids.includes(id), `list exposed ${id}`);
  }
}

describe('another trainer cannot reach trainerA documents (AC-DF-022.1)', () => {
  const A_DOCS = {
    'soap_notes/N1': () => h.storedV2SoapDoc(),
    'postureAssessments/P1': () => h.rawRecordDoc('postureAssessments'),
    'bodyCompositionRecords/B1': () => h.rawRecordDoc('bodyCompositionRecords'),
    [`pendingMembers/${pendA}`]: () => h.pendingMemberDoc(),
  };

  async function seedR05() {
    const docs = baseSeed();
    for (const [p, make] of Object.entries(A_DOCS)) docs[p] = make();
    await h.seed(env, docs);
  }

  test('R-05 trainerB get of trainerA soap, posture, bodyComposition and pendingMembers documents is denied', async () => {
    await seedR05();
    const db = h.trainerDb(env, trainerB);
    for (const p of Object.keys(A_DOCS)) {
      await assertFails(getDoc(doc(db, p)));
    }
  });

  test('R-05 trainerB list with where trainerId == trainerA is denied on every collection', async () => {
    await seedR05();
    const db = h.trainerDb(env, trainerB);
    for (const p of Object.keys(A_DOCS)) {
      const col = p.split('/')[0];
      await assertFails(getDocs(query(collection(db, col), where('trainerId', '==', trainerA))));
    }
  });

  test('R-05 trainerB list with where trainerId == trainerB does not expose trainerA documents', async () => {
    await seedR05();
    const db = h.trainerDb(env, trainerB);
    for (const p of Object.keys(A_DOCS)) {
      const [col, id] = p.split('/');
      await assertListHides(query(collection(db, col), where('trainerId', '==', trainerB)), [id]);
    }
  });
});

describe('unassignment after realignment: trainerId=null (AC-DF-022.2 second stage)', () => {
  async function seedR06() {
    await h.seed(env, {
      ...baseSeed({memberIdsA: []}),
      'soap_notes/N1': h.storedV2SoapDoc({trainerId: null}),
    });
  }

  test('R-06 trainerA get of the realigned note is denied', async () => {
    await seedR06();
    await assertFails(getDoc(doc(h.trainerDb(env), 'soap_notes/N1')));
  });

  test('R-06 trainerA list cannot reach the realigned note', async () => {
    await seedR06();
    const notes = collection(h.trainerDb(env), 'soap_notes');
    // 키 없는 목록(memberUid만, trainerId==null)은 규칙이 증명할 수 없어 거부된다.
    await assertFails(getDocs(query(notes, where('memberUid', '==', member1))));
    await assertFails(getDocs(query(notes, where('trainerId', '==', null))));
    // 자기 키 목록은 쿼리 자체는 증명되지만 N1은 결과에 없다(V1-05 §9.2 R-06 '결과 0건').
    const snap = await assertSucceeds(getDocs(query(notes, where('trainerId', '==', trainerA))));
    assert.equal(snap.size, 0);
  });

  test('R-06 trainerA update of the realigned note is denied', async () => {
    await seedR06();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      quickNote: '합성 수정', updatedAt: serverTimestamp(),
    }));
  });

  test('R-06 trainerA delete of the realigned note is denied', async () => {
    await seedR06();
    await assertFails(deleteDoc(doc(h.trainerDb(env), 'soap_notes/N1')));
  });
});

describe('unassignment before realignment: memberIds=[] but trainerId=trainerA (AC-DF-022.2 first stage)', () => {
  async function seedR07() {
    await h.seed(env, {
      ...baseSeed({memberIdsA: []}),
      'soap_notes/N1': h.storedV2SoapDoc({trainerId: trainerA}),
    });
  }

  test('R-07 trainerA update of the draft is denied (canWriteFor)', async () => {
    await seedR07();
    await assertFails(updateDoc(doc(h.trainerDb(env), 'soap_notes/N1'), {
      quickNote: '합성 수정', updatedAt: serverTimestamp(),
    }));
  });

  test('R-07 trainerA new create for member1 is denied', async () => {
    await seedR07();
    await assertFails(setDoc(doc(h.trainerDb(env), 'soap_notes/fx-new-070'), h.v2SoapDoc()));
  });

  test('R-07 trainerA get is still allowed until realignment (read projection lag, RISK-10)', async () => {
    await seedR07();
    await assertSucceeds(getDoc(doc(h.trainerDb(env), 'soap_notes/N1')));
  });
});

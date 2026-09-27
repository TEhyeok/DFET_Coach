// R-32 (DF-104): deleting a draft is idempotent. A draft delete sent again after its reply was lost (the document is gone)
// succeeds for a trainer, so the Outbox never fails it for good; an existing document keeps its delete conditions.
// Synthetic data only.
const {after, before, beforeEach, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {deleteDoc, doc} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1} = h.IDS;
let env;

before(async () => { env = await h.initRulesEnv({projectId: 'dfet-rules-idempotent-delete'}); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await h.seed(env, {
    ...h.seedTrainer(trainerA, [member1]),
    ...h.seedTrainer(trainerB, []),
    ...h.seedConsent(member1, {healthData: true, bodyImaging: true}),
    ...h.seedFlags(),
    'soap_notes/fx-draft-a': h.storedV2SoapDoc(),
    'soap_notes/fx-final-a': h.storedV2SoapDoc({status: 'finalized', finalizedAt: h.hoursAgo(1)}),
    'postureAssessments/fx-posture-a': {...h.postureDoc(), createdAt: h.hoursAgo(2), updatedAt: h.hoursAgo(2)},
  });
});

test('R-32 DF-104 a trainer deleting a draft twice: the second delete of the missing document succeeds', async () => {
  const db = h.trainerDb(env);
  await assertSucceeds(deleteDoc(doc(db, 'soap_notes/fx-draft-a')));
  await assertSucceeds(deleteDoc(doc(db, 'soap_notes/fx-draft-a')));
  await assertSucceeds(deleteDoc(doc(db, 'postureAssessments/fx-posture-a')));
  await assertSucceeds(deleteDoc(doc(db, 'postureAssessments/fx-posture-a')));
});

test('R-32 DF-104 a missing document can be "deleted" only by a trainer', async () => {
  await assertFails(deleteDoc(doc(h.memberDb(env), 'soap_notes/fx-never-a')));
  await assertFails(deleteDoc(doc(h.memberDb(env), 'postureAssessments/fx-never-a')));
  await assertFails(deleteDoc(doc(env.unauthenticatedContext().firestore(), 'soap_notes/fx-never-a')));
});

test('R-32 DF-104 existing documents keep their delete conditions', async () => {
  await assertFails(deleteDoc(doc(h.trainerDb(env), 'soap_notes/fx-final-a')));          // finalized
  await assertFails(deleteDoc(doc(h.trainerDb(env, trainerB), 'soap_notes/fx-draft-a')));  // another trainer's draft
  await assertFails(deleteDoc(doc(h.trainerDb(env, trainerB), 'postureAssessments/fx-posture-a')));
});

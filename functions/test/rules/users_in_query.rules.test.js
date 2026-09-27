// DF-013 AC-DF-013.3 (TC-DF013-03, ASM-P0-09): the assigned trainer may read its members with
// `users where documentId in [...]`; one uid outside `trainers/{uid}.memberIds` makes the whole query fail.
// Auxiliary test without an R number. All identifiers are synthetic.
const {after, before, beforeEach, describe, test} = require('node:test');
const {assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {collection, documentId, getDocs, query, where} = require('firebase/firestore');
const h = require('./_harness');

const {trainerA, trainerB, member1, member2} = h.IDS;
const assigned = Array.from({length: 10}, (_, i) => `synthMember${String(i + 1).padStart(4, '0')}`);
let env;

before(async () => {
  env = await h.initRulesEnv({projectId: 'dfet-rules-users-in-query'});
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  const users = {};
  for (const uid of [...assigned, member2]) {
    users[`users/${uid}`] = {displayName: `가상 회원 ${uid.slice(-4)}`, trainerId: trainerA, role: 'member'};
  }
  await h.seed(env, {
    ...h.seedTrainer(trainerA, assigned),
    ...h.seedTrainer(trainerB, [member2]),
    ...users,
  });
});

function usersIn(db, uids) {
  return getDocs(query(collection(db, 'users'), where(documentId(), 'in', uids)));
}

describe('users documentId in query (AC-DF-013.3)', () => {
  test('assigned trainer reads a chunk of 10 assigned members', async () => {
    const snapshot = await assertSucceeds(usersIn(h.trainerDb(env, trainerA), assigned));
    if (snapshot.size !== 10) throw new Error(`expected 10 members, got ${snapshot.size}`);
  });

  test('one uid outside memberIds makes the whole query fail', async () => {
    await assertFails(usersIn(h.trainerDb(env, trainerA), [...assigned.slice(0, 9), member2]));
  });

  test('another trainer cannot read these members', async () => {
    await assertFails(usersIn(h.trainerDb(env, trainerB), assigned.slice(0, 3)));
  });

  test('a signed-in member without the trainer claim cannot read other members', async () => {
    await assertFails(usersIn(h.memberDb(env, member1), assigned.slice(0, 3)));
  });
});

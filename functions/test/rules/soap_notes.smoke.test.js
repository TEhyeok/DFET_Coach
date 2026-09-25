// TC-DF020-01: soap_notes v2 규칙 스모크(R-01~R-04 최소, AC-DF-020.1~020.9).
// 매트릭스 전체(R-01~R-13, R-21, R-23, R-24)는 DF-022가 test/rules/*.rules.test.js로 맡는다.
// 모든 식별자와 값은 합성이다(contracts/fixtures 규약의 fx- 접두사).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {after, before, beforeEach, describe, test} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const REPO_ROOT = path.join(__dirname, '../../..');
const RULES_TEXT = fs.readFileSync(path.join(REPO_ROOT, 'firestore.rules'), 'utf8');

const T_A = 'fx-trainer-001';
const T_B = 'fx-trainer-002';
const M1 = 'fx-member-001';
const M2 = 'fx-member-002';
const P1 = 'fx-pending-001';
const TRAINER = {trainer: true, role: 'trainer'};

let env;

function hoursAgo(h) {
  return Timestamp.fromMillis(Date.now() - h * 3600 * 1000);
}

function dbFor(uid, token = {}) {
  return env.authenticatedContext(uid, token).firestore();
}

function trainerDb(uid = T_A) {
  return dbFor(uid, TRAINER);
}

// 트레이너 A가 담당 회원 M1에게 쓰는 v2 draft create 페이로드
function v2Create(overrides = {}) {
  return {
    schemaVersion: 2,
    trainerId: T_A,
    authorUid: T_A,
    memberUid: M1,
    memberId: M1,
    sessionDate: hoursAgo(1),
    status: 'draft',
    quickNote: '가상 회원 A, 오른쪽 어깨가 뻐근하다고 말함',
    subjective: {chiefComplaint: '어깨를 들 때 불편하다고 함', painNrs: 4, painRegions: ['shoulderRight']},
    plan: {nextSession: '어깨 가동성 다시 확인', homeExercise: ''},
    legalNature: 'coachingRecord',
    isSharedWithMember: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

// 이미 저장된 v2 문서(시드용, 서버 시각 대신 고정 과거 시각)
function v2Stored(overrides = {}) {
  return {
    ...v2Create(),
    createdAt: hoursAgo(2),
    updatedAt: hoursAgo(2),
    ...overrides,
  };
}

// contracts/fixtures의 타입 태그를 Firestore 값으로 바꾼다($ts는 과거 시각으로, 서버 시각 자리는 serverTimestamp).
function decodeFixture(value) {
  if (Array.isArray(value)) return value.map(decodeFixture);
  if (value && typeof value === 'object') {
    if ('$int' in value) return value.$int;
    if ('$ts' in value) return hoursAgo(1);
    if ('$serverTimestamp' in value) return serverTimestamp();
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, decodeFixture(v)]));
  }
  return value;
}

function fixtureCreatePayload(name) {
  const fixture = JSON.parse(fs.readFileSync(
    path.join(REPO_ROOT, 'contracts/fixtures/soap_v2', `${name}.json`), 'utf8',
  ));
  const data = decodeFixture(fixture.data);
  data.createdAt = serverTimestamp();
  data.updatedAt = serverTimestamp();
  return {path: fixture.path, data};
}

// 동결 앱(Flutter SoapNote.toFirestore) 형식의 v1 문서
function v1FrozenAppDoc(overrides = {}) {
  return {
    trainerId: T_A,
    trainerName: '가상 트레이너',
    memberId: M1,
    memberName: '가상 회원 A',
    memberEmail: 'member-a@example.invalid',
    date: Date.now(),
    diagnosis: '',
    subjective: '합성 주관 메모',
    assessment: '',
    isSharedWithMember: true,
    structured: {},
    createdAt: Date.now(),
    updatedAt: Date.now(),
    ...overrides,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'dfet-rules-soap-notes-smoke',
    firestore: {rules: RULES_TEXT},
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, `trainers/${T_A}`), {memberIds: [M1, M2]}),
      setDoc(doc(db, `trainers/${T_B}`), {memberIds: []}),
      setDoc(doc(db, `pendingMembers/${P1}`), {trainerId: T_A, status: 'pending'}),
      setDoc(doc(db, `memberConsentStates/${M1}`), {healthData: {granted: true}}),
      setDoc(doc(db, `memberConsentStates/${M2}`), {healthData: {granted: false}}),
      setDoc(doc(db, `memberConsentStates/${P1}`), {healthData: {granted: true}}),
      setDoc(doc(db, 'appConfig/features'), {soapV2: true}),
      setDoc(doc(db, 'soap_notes/fx-draft-001'), v2Stored()),
      setDoc(doc(db, 'soap_notes/fx-draft-002'), v2Stored({memberUid: M2, memberId: M2})),
      setDoc(doc(db, 'soap_notes/fx-final-001'), v2Stored({
        status: 'finalized', finalizedAt: hoursAgo(1),
      })),
      setDoc(doc(db, 'soap_notes/fx-final-001/addenda/fx-add-001'), {
        authorUid: T_A, createdAt: hoursAgo(1), reason: '오기 정정', text: '합성 정정 문장',
      }),
      setDoc(doc(db, 'soap_notes/fx-legacy-001'), v1FrozenAppDoc()),
    ]);
  });
});

describe('AC-DF-020.1 helpers exist in firestore.rules', () => {
  test('AC-DF-020.1 v2 helpers are declared and isAssignedTrainer is kept', () => {
    for (const name of [
      'isAssignedTrainer', 'isAccessTrainer', 'isPendingOwner', 'memberKeyOf', 'canWriteFor',
      'hasConsent', 'featureOn', 'measuredAtOk', 'legacyV1WritesOpen',
    ]) {
      assert.match(RULES_TEXT, new RegExp(`function ${name}\\(`), `missing helper ${name}`);
    }
    assert.match(RULES_TEXT, /ts <= request\.time \+ duration\.value\(5, 'm'\)/);
  });

  test('AC-DF-020.1 the @mig03-switch line is a single true line the rollback sed can find', () => {
    const switchLines = RULES_TEXT.split('\n').filter((l) => l.includes('@mig03-switch'));
    assert.equal(switchLines.length, 1);
    assert.ok(switchLines[0].includes('function legacyV1WritesOpen() { return true; }'));
  });

  test('AC-DF-020.9 soap_notes block has no member or admin read clause', () => {
    const start = RULES_TEXT.indexOf('match /soap_notes/{noteId}');
    const end = RULES_TEXT.indexOf('// --- Community (Posts) ---');
    const block = RULES_TEXT.slice(start, end);
    assert.ok(start > 0 && end > start);
    assert.doesNotMatch(block, /isAdmin\(\)/);
    assert.doesNotMatch(block, /isSharedWithMember == true/);
  });
});

describe('R-01 / R-02 v2 create (AC-DF-020.2)', () => {
  test('R-01 AC-DF-020.2 assigned trainer with consent and soapV2 creates a v2 draft', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), 'soap_notes/fx-new-001'), v2Create()));
  });

  test('R-01 AC-DF-020.2 Dart codec fixture payload is accepted', async () => {
    const {path: notePath, data} = fixtureCreatePayload('flutter_written_draft_rom_mmt_pain');
    await assertSucceeds(setDoc(doc(trainerDb(), notePath), data));
  });

  test('R-01 AC-DF-020.2 pending owner creates the pending-member fixture draft (memberUid null)', async () => {
    const {path: notePath, data} = fixtureCreatePayload('pending_member_draft');
    assert.equal(data.memberUid, null);
    await assertSucceeds(setDoc(doc(trainerDb(), notePath), data));
  });

  test('R-02 AC-DF-020.2 trainer not holding the member in memberIds is denied even with trainerId == uid', async () => {
    await assertFails(setDoc(doc(trainerDb(T_B), 'soap_notes/fx-new-002'), v2Create({
      trainerId: T_B, authorUid: T_B,
    })));
  });

  test('R-02 AC-DF-020.2 non-owner of a pending member is denied', async () => {
    const {path: notePath, data} = fixtureCreatePayload('pending_member_draft');
    await assertFails(setDoc(doc(trainerDb(T_B), notePath), {...data, trainerId: T_B, authorUid: T_B}));
  });

  test('AC-DF-020.2 create without healthData consent is denied', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/fx-new-003'), v2Create({
      memberUid: M2, memberId: M2,
    })));
  });

  test('AC-DF-020.2 create is denied while soapV2 is off', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appConfig/features'), {soapV2: false});
    });
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/fx-new-004'), v2Create()));
  });

  test('AC-DF-020.2 client clock createdAt is denied (server time only)', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/fx-new-005'), v2Create({
      createdAt: Timestamp.now(),
    })));
  });

  test('AC-DF-020.1 measuredAtOk denies a sessionDate more than 5 minutes ahead', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/fx-new-006'), v2Create({
      sessionDate: Timestamp.fromMillis(Date.now() + 30 * 60 * 1000),
    })));
  });

  test('AC-DF-020.2 both memberUid and pendingMemberId, finalized create, shared flag, painNrs 11 are denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'soap_notes/fx-new-007'), v2Create({pendingMemberId: P1})));
    await assertFails(setDoc(doc(db, 'soap_notes/fx-new-008'), v2Create({status: 'finalized'})));
    await assertFails(setDoc(doc(db, 'soap_notes/fx-new-009'), v2Create({isSharedWithMember: true})));
    await assertFails(setDoc(doc(db, 'soap_notes/fx-new-010'), v2Create({
      subjective: {painNrs: 11},
    })));
  });

  test('AC-DF-020.2 member token cannot create a v2 note', async () => {
    await assertFails(setDoc(doc(dbFor(M1), 'soap_notes/fx-new-011'), v2Create({
      trainerId: M1, authorUid: M1,
    })));
  });
});

describe('R-04 whitelist (AC-DF-020.3)', () => {
  test('R-04 AC-DF-020.3 v2 create with diagnosis is denied', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/fx-new-020'), v2Create({
      diagnosis: '합성 진단명',
    })));
  });

  test('R-04 AC-DF-020.3 v2 update adding diagnosis is denied, plain draft edit is allowed', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-draft-001');
    await assertFails(updateDoc(ref, {diagnosis: '합성 진단명', updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(ref, {quickNote: '수정한 합성 메모', updatedAt: serverTimestamp()}));
  });
});

describe('R-03 / R-08 draft update and finalize (AC-DF-020.4)', () => {
  test('R-03 AC-DF-020.4 draft update cannot change memberUid or trainerId', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-draft-001');
    await assertFails(updateDoc(ref, {memberUid: M2, updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {trainerId: T_B, updatedAt: serverTimestamp()}));
  });

  test('R-03 AC-DF-020.4 draft update without server updatedAt is denied', async () => {
    await assertFails(updateDoc(doc(trainerDb(), 'soap_notes/fx-draft-001'), {
      quickNote: '합성 메모', updatedAt: Timestamp.now(),
    }));
  });

  test('AC-DF-020.4 draft update is denied when healthData consent is not granted', async () => {
    await assertFails(updateDoc(doc(trainerDb(), 'soap_notes/fx-draft-002'), {
      quickNote: '합성 메모', updatedAt: serverTimestamp(),
    }));
  });

  test('R-08 AC-DF-020.4 finalized note cannot be updated', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-final-001');
    await assertFails(updateDoc(ref, {
      exerciseAssessment: {summary: '합성 요약'}, updatedAt: serverTimestamp(),
    }));
    // 확정 전환 조건(서버 finalizedAt, nextSession)을 다시 채워도 finalized 문서는 고칠 수 없다.
    await assertFails(updateDoc(ref, {
      exerciseAssessment: {summary: '합성 요약'}, finalizedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-020.4 finalize with finalizedAt != request.time is denied', async () => {
    await assertFails(updateDoc(doc(trainerDb(), 'soap_notes/fx-draft-001'), {
      status: 'finalized', finalizedAt: Timestamp.now(), updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-020.4 finalize with empty plan.nextSession is denied', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-draft-001');
    for (const nextSession of ['', '   ']) {
      await assertFails(updateDoc(ref, {
        status: 'finalized', finalizedAt: serverTimestamp(), updatedAt: serverTimestamp(),
        plan: {nextSession, homeExercise: ''},
      }));
    }
  });

  test('AC-DF-020.4 finalize with server finalizedAt and nextSession is allowed', async () => {
    await assertSucceeds(updateDoc(doc(trainerDb(), 'soap_notes/fx-draft-001'), {
      status: 'finalized', finalizedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-020.4 draft can be deleted, finalized cannot', async () => {
    const db = trainerDb();
    await assertSucceeds(deleteDoc(doc(db, 'soap_notes/fx-draft-001')));
    await assertFails(deleteDoc(doc(db, 'soap_notes/fx-final-001')));
  });
});

describe('R-09 addenda (AC-DF-020.5)', () => {
  const addendum = (overrides = {}) => ({
    authorUid: T_A, createdAt: serverTimestamp(), reason: '정보주체 정정 요구',
    text: '합성 정정 문장', changedFields: ['plan.nextSession'],
    previousValues: {'plan.nextSession': '이전 합성 계획'}, ...overrides,
  });

  test('R-09 AC-DF-020.5 addendum create on a finalized parent is allowed (reason 1 and 500 chars)', async () => {
    const db = trainerDb();
    await assertSucceeds(setDoc(doc(db, 'soap_notes/fx-final-001/addenda/fx-add-010'), addendum({reason: '가'})));
    await assertSucceeds(setDoc(doc(db, 'soap_notes/fx-final-001/addenda/fx-add-011'), addendum({
      reason: '가'.repeat(500),
    })));
  });

  test('R-09 AC-DF-020.5 empty or 501-char reason, and draft parent are denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'soap_notes/fx-final-001/addenda/fx-add-012'), addendum({reason: ''})));
    await assertFails(setDoc(doc(db, 'soap_notes/fx-final-001/addenda/fx-add-013'), addendum({
      reason: '가'.repeat(501),
    })));
    await assertFails(setDoc(doc(db, 'soap_notes/fx-draft-001/addenda/fx-add-014'), addendum()));
  });

  test('R-09 AC-DF-020.5 addendum update and delete are denied', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-final-001/addenda/fx-add-001');
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, {text: '바꾼 문장'}));
    await assertFails(deleteDoc(ref));
  });
});

describe('R-24 native document IDs (AC-DF-020.6)', () => {
  test('R-24 AC-DF-020.6 v2 create with native_ document ID is denied', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'soap_notes/native_x_2026-09-24'), v2Create()));
  });
});

describe('R-13 list queries (AC-DF-020.7)', () => {
  test('R-13 AC-DF-020.7 list filtered only by memberUid is denied', async () => {
    await assertFails(getDocs(query(collection(trainerDb(), 'soap_notes'), where('memberUid', '==', M1))));
  });

  test('R-13 AC-DF-020.7 list filtered by trainerId == uid is allowed', async () => {
    const notes = collection(trainerDb(), 'soap_notes');
    await assertSucceeds(getDocs(query(notes, where('trainerId', '==', T_A))));
    await assertSucceeds(getDocs(query(notes, where('trainerId', '==', T_A), where('memberUid', '==', M1))));
  });
});

describe('R-21 legacy v1 path while the switch is open (AC-DF-020.8)', () => {
  test('R-21 AC-DF-020.8 frozen-app v1 create for an assigned member is allowed', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), 'soap_notes/fx-legacy-002'), v1FrozenAppDoc()));
  });

  test('R-21 AC-DF-020.8 v1 create for an unassigned member is denied', async () => {
    await assertFails(setDoc(doc(trainerDb(T_B), 'soap_notes/fx-legacy-003'), v1FrozenAppDoc({
      trainerId: T_B,
    })));
  });

  test('R-21 AC-DF-020.8 v1 update keeps trainerId fixed and cannot upgrade to v2', async () => {
    const ref = doc(trainerDb(), 'soap_notes/fx-legacy-001');
    await assertSucceeds(setDoc(ref, v1FrozenAppDoc({subjective: '수정한 합성 메모'})));
    await assertFails(updateDoc(ref, {trainerId: T_B}));
    await assertFails(updateDoc(ref, {schemaVersion: 2}));
  });

  test('R-21 AC-DF-020.8 v1 delete by the writing trainer only', async () => {
    await assertFails(deleteDoc(doc(trainerDb(T_B), 'soap_notes/fx-legacy-001')));
    await assertSucceeds(deleteDoc(doc(trainerDb(), 'soap_notes/fx-legacy-001')));
  });
});

describe('R-10 / R-23 read (AC-DF-020.9)', () => {
  test('R-10 AC-DF-020.9 member token cannot get soap_notes even when shared (legacy)', async () => {
    const member = dbFor(M1);
    await assertFails(getDoc(doc(member, 'soap_notes/fx-legacy-001')));
    await assertFails(getDoc(doc(member, 'soap_notes/fx-draft-001')));
  });

  test('R-23 AC-DF-020.9 admin claim without trainer claim cannot get soap_notes', async () => {
    const admin = dbFor('fx-admin-001', {admin: true, role: 'admin'});
    await assertFails(getDoc(doc(admin, 'soap_notes/fx-draft-001')));
  });

  test('AC-DF-020.9 writing trainer can get, another trainer cannot', async () => {
    await assertSucceeds(getDoc(doc(trainerDb(), 'soap_notes/fx-draft-001')));
    await assertFails(getDoc(doc(trainerDb(T_B), 'soap_notes/fx-draft-001')));
  });
});

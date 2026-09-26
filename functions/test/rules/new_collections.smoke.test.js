// TC-DF021-01: 새 컬렉션 규칙 스모크(AC-DF-021.1~021.7). 컬렉션마다 허용·거부 사례를 한 쌍 이상 둔다.
// R 매트릭스 전체(R-14~R-20, R-22, R-25~R-31)는 DF-035가 test/rules/*.rules.test.js로 맡는다.
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
const M1 = 'fx-member-001'; // ② ③ ⑤ 모두 있음
const M2 = 'fx-member-002'; // ② ③ 있음, ⑤ 없음
const M3 = 'fx-member-003'; // ② 있음, ③ 없음
const M4 = 'fx-member-004'; // ③ 있음, ② 없음
const P1 = 'fx-pending-001'; // A의 대기 회원, ② ③ 있음
const P2 = 'fx-pending-002'; // A의 대기 회원, ② 없음
const P3 = 'fx-pending-003'; // A의 대기 회원, cancelled
const ADMIN = 'fx-admin-001';
// 20자 [A-Za-z0-9] uid(커스텀 uid 가정). 대기 회원 ID 형식과 겹쳐도 exists() 검사로 막혀야 한다.
const M_ID20 = 'FxMemberCustomUid001';
const M_ID20_NOCONSENT = 'FxMemberCustomUid002';
// 클라이언트가 만드는 대기 회원 ID는 DocumentID.make()/자동 ID 형식(20자 [A-Za-z0-9])이다(V1-04 §9.1).
function newPid(n) {
  return `FxPendingNew${String(n).padStart(8, '0')}`;
}
const TRAINER = {trainer: true, role: 'trainer'};
const ADMIN_CLAIMS = {admin: true, role: 'admin'};

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

function adminDb() {
  return dbFor(ADMIN, ADMIN_CLAIMS);
}

// request.time.year()는 UTC 기준이다.
const THIS_YEAR = new Date().getUTCFullYear();

function stored(createPayload, overrides = {}) {
  return {...createPayload, createdAt: hoursAgo(2), updatedAt: hoursAgo(2), ...overrides};
}

// --- 페이로드 ---

function pendingCreate(overrides = {}) {
  return {
    trainerId: T_A,
    displayName: '가상 대기 회원',
    sex: 'female',
    birthYear: 1990,
    ageConfirmed14: true,
    status: 'pending',
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

// MVP 체형 문서 모양(DF-203 MVP 조각): 기본 스테이션, 체크리스트 세 불리언 false, levelDeg·pitchDeg 없음
function postureCreate(overrides = {}) {
  return {
    memberUid: M1,
    trainerId: T_A,
    authorUid: T_A,
    capturedAt: hoursAgo(1),
    protocolVersion: 'posture-v1',
    stationProfileId: 'default-v1',
    landmarkEngine: {name: 'appleVision2D', version: 'iOS17.4-r1'},
    device: {model: 'iPad14,5', osVersion: '17.4'},
    captureConditions: {
      clothing: 'fitted', barefoot: false, markersPlaced: false, verbalConsentCheck: false,
      cameraHeightCm: 100, cameraDistanceM: 3,
    },
    views: [{view: 'front', photoPath: null, thumbPath: null, imageRotationDeg: 0, landmarks: []}],
    status: 'draft',
    isBaseline: false,
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

const POSTURE_METRIC = {
  metricCode: 'fx-metric', value: 4.2, unit: 'deg', side: 'none', sourceGrade: 'photoManual',
};

function bcCreate(overrides = {}) {
  return {
    memberUid: M1,
    trainerId: T_A,
    enteredBy: T_A,
    source: 'manualEntry',
    sourceGrade: 'device',
    deviceModel: 'InBody 570',
    measuredAt: hoursAgo(1),
    fasting: 'yes',
    timeOfDayBand: 'morning',
    values: {weightKg: 62.4, bodyFatPercent: 24.1},
    status: 'active',
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function circCreate(overrides = {}) {
  return {
    memberUid: M1,
    trainerId: T_A,
    authorUid: T_A,
    metricCode: 'waistCircumference',
    side: 'none',
    valueCm: 78.4,
    sourceGrade: 'tape',
    protocolId: 'waistMidpoint',
    protocolVersion: 'circ-v1',
    measuredAt: hoursAgo(1),
    trialIndex: 1,
    validationStatus: 'validated',
    isBeta: false,
    status: 'active',
    legalNature: 'coachingRecord',
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function observedSectionCreate(overrides = {}) {
  return circCreate({
    sourceGrade: 'observedSection',
    validationStatus: 'unvalidated',
    isBeta: true,
    scanId: 'fx-scan-001',
    ...overrides,
  });
}

async function setFeatures(features) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'appConfig/features'), features);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'dfet-rules-new-collections-smoke',
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
    const granted = {granted: true};
    const denied = {granted: false};
    await Promise.all([
      setDoc(doc(db, `trainers/${T_A}`), {memberIds: [M1, M2, M3, M4, M_ID20]}),
      setDoc(doc(db, `users/${M_ID20}`), {role: 'member', trainerId: T_A}),
      setDoc(doc(db, `users/${M_ID20_NOCONSENT}`), {role: 'member'}),
      setDoc(doc(db, `memberConsentStates/${M_ID20}`), {healthData: granted, bodyImaging: granted}),
      setDoc(doc(db, `trainers/${T_B}`), {memberIds: []}),
      setDoc(doc(db, `pendingMembers/${P1}`), stored(pendingCreate())),
      setDoc(doc(db, `pendingMembers/${P2}`), stored(pendingCreate({displayName: '가상 대기 회원 2'}))),
      setDoc(doc(db, `pendingMembers/${P3}`), stored(pendingCreate({status: 'cancelled'}))),
      setDoc(doc(db, `memberConsentStates/${M1}`), {healthData: granted, bodyImaging: granted, research: granted}),
      setDoc(doc(db, `memberConsentStates/${M2}`), {healthData: granted, bodyImaging: granted, research: denied}),
      setDoc(doc(db, `memberConsentStates/${M3}`), {healthData: granted, bodyImaging: denied}),
      setDoc(doc(db, `memberConsentStates/${M4}`), {healthData: denied, bodyImaging: granted}),
      setDoc(doc(db, `memberConsentStates/${P1}`), {healthData: granted, bodyImaging: granted}),
      setDoc(doc(db, `memberConsentStates/${P2}`), {healthData: denied}),
      setDoc(doc(db, 'appConfig/features'), {
        bodyAssessment: true, bodyComposition: true, soapV2: true, lidarBeta: false,
      }),
      setDoc(doc(db, 'postureAssessments/fx-posture-draft'), stored(postureCreate())),
      setDoc(doc(db, 'postureAssessments/fx-posture-confirmed'), stored(postureCreate({
        status: 'confirmed', metrics: [POSTURE_METRIC],
      }))),
      setDoc(doc(db, 'postureAssessments/fx-posture-voided'), stored(postureCreate({
        status: 'voided', metrics: [POSTURE_METRIC],
      }))),
      setDoc(doc(db, 'bodyCompositionRecords/fx-bc-001'), stored(bcCreate())),
      setDoc(doc(db, 'bodyCompositionRecords/fx-bc-002'), stored(bcCreate({
        reportPhotoPath: 'bodyCompositionRecords/fx-bc-002/report.jpg',
      }))),
      setDoc(doc(db, 'bodyCompositionRecords/fx-bc-003'), stored(bcCreate({
        status: 'voided', voidedAt: hoursAgo(1), voidReason: '전사 오류',
      }))),
      setDoc(doc(db, 'circumferenceMeasurements/fx-circ-001'), stored(circCreate())),
      setDoc(doc(db, 'consentRecords/fx-consent-001'), {
        subjectUid: M1, pendingMemberId: null, consentType: 'healthData', action: 'grant',
        documentVersion: 'fx-v1', channel: 'memberApp', recordedAt: hoursAgo(3), recordedBy: M1,
        schemaVersion: 1,
      }),
      setDoc(doc(db, 'consentRecords/fx-consent-002'), {
        subjectUid: null, pendingMemberId: P1, consentType: 'healthData', action: 'grant',
        documentVersion: 'fx-v1', channel: 'trainerDeviceInPerson', recordedAt: hoursAgo(3),
        recordedBy: T_A, schemaVersion: 1,
      }),
      setDoc(doc(db, 'consentDocumentVersions/fx-doc-published'), {
        consentType: 'healthData', version: 'fx-v1', status: 'published',
      }),
      setDoc(doc(db, 'consentDocumentVersions/fx-doc-draft'), {
        consentType: 'healthData', version: 'fx-v2', status: 'draft',
      }),
      setDoc(doc(db, 'insightPolicyVersions/fx-policy-active'), {
        kind: 'bodyChange', version: 'fx-1', status: 'approved', active: true,
      }),
      setDoc(doc(db, 'insightPolicyVersions/fx-policy-draft'), {
        kind: 'bodyChange', version: 'fx-2', status: 'draft', active: false,
      }),
      setDoc(doc(db, 'insightPolicyVersions/fx-policy-unapproved-active'), {
        kind: 'bodyChange', version: 'fx-3', status: 'draft', active: true,
      }),
      setDoc(doc(db, 'insightPolicyVersions/fx-policy-inactive'), {
        kind: 'bodyChange', version: 'fx-4', status: 'approved', active: false,
      }),
      setDoc(doc(db, 'insightPolicyVersions/fx-policy-other-kind'), {
        kind: 'integrated', version: 'fx-5', status: 'approved', active: true,
      }),
      setDoc(doc(db, 'memberSummaries/fx-summary-001'), {
        memberUid: M1, trainerId: T_A, sourceType: 'soapNote', status: 'shared',
      }),
      setDoc(doc(db, 'rightsRequests/fx-rights-001'), {
        memberUid: M1, type: 'access', channel: 'memberApp', status: 'received',
      }),
      setDoc(doc(db, 'opsMetrics/2026-W40'), {weekSoapFinalized: 3}),
    ]);
  });
});

describe('TC-DF021-01 helpers', () => {
  test('AC-DF-021 DF-020 helpers are declared once (not redefined) and V1-05 §7.2 leftovers are added', () => {
    for (const name of [
      'isAccessTrainer', 'isPendingOwner', 'memberKeyOf', 'canWriteFor', 'hasConsent',
      'featureOn', 'measuredAtOk', 'rawRecordCreateBase', 'strRange', 'changed',
      'numIn', 'numPosMax', 'identityUnchanged',
    ]) {
      const count = RULES_TEXT.split(`function ${name}(`).length - 1;
      assert.equal(count, 1, `function ${name} must be declared exactly once`);
    }
  });
});

describe('AC-DF-021.1 pendingMembers', () => {
  test('AC-DF-021.1 creating trainer with the nine required keys is allowed', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), `pendingMembers/${newPid(1)}`), pendingCreate()));
  });

  test('AC-DF-021.1 phone, email, heightCm or server-only keys at create are denied', async () => {
    const db = trainerDb();
    for (const [i, extra] of [
      {phone: '000-0000-0000'},
      {email: 'pending@example.invalid'},
      {heightCm: 165},
      {inviteCodeId: 'fx-code'},
      {promotedUid: M1},
    ].entries()) {
      await assertFails(setDoc(doc(db, `pendingMembers/${newPid(10 + i)}`), pendingCreate(extra)));
    }
  });

  test('AC-DF-021.1 missing required key, non-pending status or ageConfirmed14 false is denied', async () => {
    const db = trainerDb();
    const {sex, ...withoutSex} = pendingCreate();
    assert.ok(sex);
    await assertFails(setDoc(doc(db, `pendingMembers/${newPid(20)}`), withoutSex));
    await assertFails(setDoc(doc(db, `pendingMembers/${newPid(21)}`), pendingCreate({status: 'promoted'})));
    await assertFails(setDoc(doc(db, `pendingMembers/${newPid(22)}`), pendingCreate({ageConfirmed14: false})));
    await assertFails(setDoc(doc(db, `pendingMembers/${newPid(23)}`), pendingCreate({trainerId: T_B})));
  });

  test('R-31 AC-DF-021.1 birthYear == year - 14 is allowed, year - 13 is denied', async () => {
    const db = trainerDb();
    await assertSucceeds(setDoc(doc(db, `pendingMembers/${newPid(30)}`), pendingCreate({
      birthYear: THIS_YEAR - 14,
    })));
    await assertFails(setDoc(doc(db, `pendingMembers/${newPid(31)}`), pendingCreate({
      birthYear: THIS_YEAR - 13,
    })));
  });

  test('R-30 AC-DF-021.1 heightCm update without consent ② is denied, with ② is allowed', async () => {
    const db = trainerDb();
    const height = {heightCm: 165, heightMeasuredAt: hoursAgo(1), updatedAt: serverTimestamp()};
    await assertFails(updateDoc(doc(db, `pendingMembers/${P2}`), height));
    await assertSucceeds(updateDoc(doc(db, `pendingMembers/${P1}`), height));
  });

  test('AC-DF-021.1 pending→cancelled is allowed, cancelled doc cannot be edited', async () => {
    const db = trainerDb();
    await assertSucceeds(updateDoc(doc(db, `pendingMembers/${P1}`), {
      status: 'cancelled', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, `pendingMembers/${P3}`), {
      displayName: '바꾼 이름', updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.1 trainerId change, promoted status and delete are denied', async () => {
    const db = trainerDb();
    await assertFails(updateDoc(doc(db, `pendingMembers/${P1}`), {trainerId: T_B, updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(db, `pendingMembers/${P1}`), {status: 'promoted', updatedAt: serverTimestamp()}));
    await assertFails(deleteDoc(doc(db, `pendingMembers/${P1}`)));
  });

  test('R-05 AC-DF-021.1 pendingMembers id must be a 20-char auto ID that is not a member uid or consent key', async () => {
    const db = trainerDb(T_B);
    // 기존 회원 uid(비자동 ID 형식)로 대기 회원을 만들어 isPendingOwner를 통과하려는 시도
    await assertFails(setDoc(doc(db, `pendingMembers/${M1}`), pendingCreate({trainerId: T_B})));
    // 자동 ID 형식이어도 기존 동의 상태 키 또는 users 문서와 겹치면 거부
    await assertFails(setDoc(doc(db, `pendingMembers/${M_ID20}`), pendingCreate({trainerId: T_B})));
    await assertFails(setDoc(doc(db, `pendingMembers/${M_ID20_NOCONSENT}`), pendingCreate({trainerId: T_B})));
    // 형식 위반(길이, 문자)
    await assertFails(setDoc(doc(db, 'pendingMembers/FxPendingShort01'), pendingCreate({trainerId: T_B})));
    await assertFails(setDoc(doc(db, 'pendingMembers/FxPending_New_000001'), pendingCreate({trainerId: T_B})));
    await assertSucceeds(setDoc(doc(db, `pendingMembers/${newPid(40)}`), pendingCreate({trainerId: T_B})));
  });

  test('R-05 AC-DF-021.1 unassigned trainer cannot read a member consent state or borrow its consent after a pending create attempt', async () => {
    const db = trainerDb(T_B);
    await assertFails(setDoc(doc(db, `pendingMembers/${M1}`), pendingCreate({trainerId: T_B})));
    await assertFails(setDoc(doc(db, `pendingMembers/${M_ID20}`), pendingCreate({trainerId: T_B})));
    await assertFails(getDoc(doc(db, `memberConsentStates/${M1}`)));
    await assertFails(getDoc(doc(db, `memberConsentStates/${M_ID20}`)));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-borrow-01'), bcCreate({
      memberUid: null, pendingMemberId: M1, trainerId: T_B, enteredBy: T_B,
    })));
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-borrow-01'), postureCreate({
      memberUid: null, pendingMemberId: M_ID20, trainerId: T_B, authorUid: T_B,
    })));
  });

  test('R-05 AC-DF-021.1 creator reads and lists by trainerId, another trainer cannot', async () => {
    await assertSucceeds(getDoc(doc(trainerDb(), `pendingMembers/${P1}`)));
    await assertSucceeds(getDocs(query(collection(trainerDb(), 'pendingMembers'), where('trainerId', '==', T_A))));
    await assertFails(getDoc(doc(trainerDb(T_B), `pendingMembers/${P1}`)));
  });
});

describe('AC-DF-021.2 postureAssessments', () => {
  test('AC-DF-021.2 MVP posture shape (default-v1, three false booleans, no levelDeg/pitchDeg) is allowed', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), 'postureAssessments/fx-posture-new-01'), postureCreate()));
  });

  test('AC-DF-021.2 pending member with ② ③ is allowed', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), 'postureAssessments/fx-posture-new-02'), postureCreate({
      memberUid: null, pendingMemberId: P1,
    })));
  });

  test('R-15 AC-DF-021.2 missing ③ or missing ② is denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-03'), postureCreate({memberUid: M3})));
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-04'), postureCreate({memberUid: M4})));
  });

  test('AC-DF-021.2 bodyAssessment flag off is denied', async () => {
    await setFeatures({bodyAssessment: false, bodyComposition: true});
    await assertFails(setDoc(doc(trainerDb(), 'postureAssessments/fx-posture-new-05'), postureCreate()));
  });

  test('R-16 AC-DF-021.2 retestGroupId needs research consent ⑤', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-06'), postureCreate({
      memberUid: M2, retestGroupId: 'fx-retest-001',
    })));
    await assertSucceeds(setDoc(doc(db, 'postureAssessments/fx-posture-new-07'), postureCreate({
      retestGroupId: 'fx-retest-001',
    })));
  });

  test('AC-DF-021.2 same shape without landmarkEngine, or with an unknown captureConditions key, is denied', async () => {
    const db = trainerDb();
    const {landmarkEngine, ...withoutEngine} = postureCreate();
    assert.ok(landmarkEngine);
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-08'), withoutEngine));
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-09'), postureCreate({
      captureConditions: {...postureCreate().captureConditions, faceVisible: true},
    })));
  });

  test('AC-DF-021.2 draft→confirmed with metrics is allowed', async () => {
    await assertSucceeds(updateDoc(doc(trainerDb(), 'postureAssessments/fx-posture-draft'), {
      status: 'confirmed', metrics: [POSTURE_METRIC], updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.2 confirmed metrics or views update is denied', async () => {
    const ref = doc(trainerDb(), 'postureAssessments/fx-posture-confirmed');
    await assertFails(updateDoc(ref, {
      metrics: [{...POSTURE_METRIC, value: 9.9}], updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(ref, {views: [], updatedAt: serverTimestamp()}));
  });

  test('AC-DF-021.2 confirmed isBaseline toggle and confirmed→voided are allowed', async () => {
    const ref = doc(trainerDb(), 'postureAssessments/fx-posture-confirmed');
    await assertSucceeds(updateDoc(ref, {isBaseline: true, updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(ref, {status: 'voided', updatedAt: serverTimestamp()}));
  });

  test('AC-DF-021.2 confirmed document cannot go back to draft', async () => {
    await assertFails(updateDoc(doc(trainerDb(), 'postureAssessments/fx-posture-confirmed'), {
      status: 'draft', updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.2 voided update is denied', async () => {
    await assertFails(updateDoc(doc(trainerDb(), 'postureAssessments/fx-posture-voided'), {
      isBaseline: true, updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.2 unassigned trainer create and update for a member outside memberIds are denied', async () => {
    const db = trainerDb(T_B);
    await assertFails(setDoc(doc(db, 'postureAssessments/fx-posture-new-20'), postureCreate({
      trainerId: T_B, authorUid: T_B,
    })));
    await assertFails(updateDoc(doc(db, 'postureAssessments/fx-posture-draft'), {
      status: 'confirmed', metrics: [POSTURE_METRIC], updatedAt: serverTimestamp(),
    }));
  });

  test('R-10 AC-DF-021.2 member cannot read own raw posture record', async () => {
    await assertFails(getDoc(doc(dbFor(M1), 'postureAssessments/fx-posture-draft')));
  });

  test('R-05 R-23 AC-DF-021.2 writer reads, another trainer and admin claim cannot', async () => {
    await assertSucceeds(getDoc(doc(trainerDb(), 'postureAssessments/fx-posture-draft')));
    await assertFails(getDoc(doc(trainerDb(T_B), 'postureAssessments/fx-posture-draft')));
    await assertFails(getDoc(doc(adminDb(), 'postureAssessments/fx-posture-draft')));
  });
});

describe('AC-DF-021.3 bodyCompositionRecords', () => {
  test('AC-DF-021.3 manual entry with ② and bodyComposition flag is allowed (bodyFatPercent 0 too)', async () => {
    const db = trainerDb();
    await assertSucceeds(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-01'), bcCreate()));
    await assertSucceeds(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-02'), bcCreate({
      values: {bodyFatPercent: 0},
    })));
    await assertSucceeds(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-03'), bcCreate({
      memberUid: null, pendingMemberId: P1,
      derived: {bmi: 22.9, heightCmUsed: 165, heightMeasuredAt: hoursAgo(24), sourceGrade: 'derived'},
    })));
  });

  test('R-17 AC-DF-021.3 empty deviceModel, weightKg 0, empty values or bodyFatPercent 101 is denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-10'), bcCreate({deviceModel: ''})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-11'), bcCreate({
      deviceModel: 'x'.repeat(65),
    })));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-12'), bcCreate({values: {weightKg: 0}})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-13'), bcCreate({values: {}})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-14'), bcCreate({
      values: {bodyFatPercent: 101},
    })));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-15'), bcCreate({
      values: {bmi: 22.9},
    })));
  });

  test('AC-DF-021.3 non-manual source, server-only keys, enteredBy mismatch are denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-20'), bcCreate({source: 'inbodyApi'})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-21'), bcCreate({externalId: 'fx-ext'})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-22'), bcCreate({idempotencyKey: 'fx-key'})));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-23'), bcCreate({
      rawPath: 'clinical-ingest/bodycomp/fx-job/payload.json',
    })));
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-24'), bcCreate({enteredBy: T_B})));
  });

  test('R-14 AC-DF-021.3 missing ② or bodyComposition flag off is denied', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'bodyCompositionRecords/fx-bc-new-30'), bcCreate({memberUid: M4})));
    await setFeatures({bodyAssessment: true, bodyComposition: false});
    await assertFails(setDoc(doc(trainerDb(), 'bodyCompositionRecords/fx-bc-new-31'), bcCreate()));
  });

  test('AC-DF-021.3 reportPhotoPath null→value once is allowed, second set is denied', async () => {
    const db = trainerDb();
    await assertSucceeds(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc-001'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-001/report.jpg', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc-002'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-002/report.heic', updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.3 reportPhotoPath must be exactly this record path, regex metacharacters in the id do not widen it', async () => {
    const db = trainerDb();
    await assertSucceeds(setDoc(doc(db, 'bodyCompositionRecords/fx-bc.*'), bcCreate()));
    await assertFails(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc.*'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-001/report.jpg', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc-001'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-001/report.png', updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc.*'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc.*/report.heic', updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.3 active→voided with server voidedAt and 1–200 char reason is allowed', async () => {
    await assertSucceeds(updateDoc(doc(trainerDb(), 'bodyCompositionRecords/fx-bc-001'), {
      status: 'voided', voidedAt: serverTimestamp(), voidReason: '전사 오류', updatedAt: serverTimestamp(),
    }));
  });

  test('AC-DF-021.3 other updates and delete are denied', async () => {
    const db = trainerDb();
    const ref = doc(db, 'bodyCompositionRecords/fx-bc-001');
    await assertFails(updateDoc(ref, {values: {weightKg: 70}, updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {
      status: 'voided', voidedAt: Timestamp.now(), voidReason: '전사 오류', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(ref, {
      status: 'voided', voidedAt: serverTimestamp(), voidReason: '', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(ref, {voidReason: '상태 전환 없는 사유', updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc-003'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-003/report.jpg', updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(ref));
  });

  test('AC-DF-021.3 unassigned trainer create and update for a member outside memberIds are denied', async () => {
    const db = trainerDb(T_B);
    await assertFails(setDoc(doc(db, 'bodyCompositionRecords/fx-bc-new-40'), bcCreate({
      trainerId: T_B, enteredBy: T_B,
    })));
    await assertFails(updateDoc(doc(db, 'bodyCompositionRecords/fx-bc-001'), {
      reportPhotoPath: 'bodyCompositionRecords/fx-bc-001/report.jpg', updatedAt: serverTimestamp(),
    }));
  });

  test('R-10 AC-DF-021.3 member cannot read own raw body composition record', async () => {
    await assertFails(getDoc(doc(dbFor(M1), 'bodyCompositionRecords/fx-bc-001')));
  });

  test('R-05 AC-DF-021.3 writer reads, another trainer cannot', async () => {
    await assertSucceeds(getDoc(doc(trainerDb(), 'bodyCompositionRecords/fx-bc-001')));
    await assertFails(getDoc(doc(trainerDb(T_B), 'bodyCompositionRecords/fx-bc-001')));
  });
});

describe('AC-DF-021.4 circumferenceMeasurements', () => {
  test('AC-DF-021.4 tape waist with bodyComposition flag is allowed', async () => {
    await assertSucceeds(setDoc(doc(trainerDb(), 'circumferenceMeasurements/fx-circ-new-01'), circCreate()));
  });

  test('R-26 AC-DF-021.4 custom protocol without landmarkNote is denied, with a note is allowed', async () => {
    const db = trainerDb();
    const thigh = {metricCode: 'thighCircumference', side: 'left', protocolId: 'custom'};
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-02'), circCreate(thigh)));
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-03'), circCreate({
      ...thigh, landmarkNote: '',
    })));
    await assertSucceeds(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-04'), circCreate({
      ...thigh, landmarkNote: '슬개골 상연 위 15cm',
    })));
  });

  test('AC-DF-021.4 thighCircumference with side none is denied', async () => {
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-20'), circCreate({
      metricCode: 'thighCircumference', side: 'none', protocolId: 'custom', landmarkNote: '슬개골 상연 위 15cm',
    })));
  });

  test('AC-DF-021.4 unassigned trainer create and update for a member outside memberIds are denied', async () => {
    const db = trainerDb(T_B);
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-21'), circCreate({
      trainerId: T_B, authorUid: T_B,
    })));
    await assertFails(updateDoc(doc(db, 'circumferenceMeasurements/fx-circ-001'), {
      status: 'voided', voidedAt: serverTimestamp(), voidReason: '잘못 잰 값', updatedAt: serverTimestamp(),
    }));
  });

  test('R-10 AC-DF-021.4 member cannot read own raw circumference record', async () => {
    await assertFails(getDoc(doc(dbFor(M1), 'circumferenceMeasurements/fx-circ-001')));
  });

  test('R-29 AC-DF-021.4 tape with bodyComposition flag off is denied', async () => {
    await setFeatures({bodyAssessment: true, bodyComposition: false});
    await assertFails(setDoc(doc(trainerDb(), 'circumferenceMeasurements/fx-circ-new-05'), circCreate()));
  });

  test('R-22 AC-DF-021.4 observedSection with lidarBeta off is denied, with lidarBeta on is allowed', async () => {
    await assertFails(setDoc(doc(trainerDb(), 'circumferenceMeasurements/fx-circ-new-06'), observedSectionCreate()));
    await setFeatures({bodyAssessment: true, bodyComposition: true, lidarBeta: true});
    await assertSucceeds(setDoc(doc(trainerDb(), 'circumferenceMeasurements/fx-circ-new-07'), observedSectionCreate()));
  });

  test('AC-DF-021.4 observedSection without ③, validated, isBeta false, no scanId or pending member is denied', async () => {
    await setFeatures({bodyAssessment: true, bodyComposition: true, lidarBeta: true});
    const db = trainerDb();
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-10'), observedSectionCreate({memberUid: M3})));
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-11'), observedSectionCreate({
      validationStatus: 'validated',
    })));
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-12'), observedSectionCreate({isBeta: false})));
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-13'), observedSectionCreate({scanId: null})));
    await assertFails(setDoc(doc(db, 'circumferenceMeasurements/fx-circ-new-14'), observedSectionCreate({
      memberUid: null, pendingMemberId: P1,
    })));
  });

  test('AC-DF-021.4 active→voided is allowed, value edit and delete are denied', async () => {
    const ref = doc(trainerDb(), 'circumferenceMeasurements/fx-circ-001');
    await assertFails(updateDoc(ref, {valueCm: 80, updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(ref, {
      status: 'voided', voidedAt: serverTimestamp(), voidReason: '잘못 잰 값', valueCm: 80,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(ref));
    await assertSucceeds(updateDoc(ref, {
      status: 'voided', voidedAt: serverTimestamp(), voidReason: '잘못 잰 값', updatedAt: serverTimestamp(),
    }));
  });
});

describe('AC-DF-021.5 bodyScans (MVP 뒤: 규칙 블록 없음, 기본 거부)', () => {
  test('R-22 AC-DF-021.5 bodyScans create and read are denied for every client while the block is absent', async () => {
    await setFeatures({bodyAssessment: true, bodyComposition: true, lidarBeta: true});
    const scan = {
      memberUid: M1, trainerId: T_A, authorUid: T_A, takenAt: hoursAgo(1), sourceApp: 'bodypath',
      rawLocation: 'deviceLocal', sections: [], isBeta: true, legalNature: 'coachingRecord',
      schemaVersion: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertFails(setDoc(doc(trainerDb(), 'bodyScans/fx-scan-001'), scan));
    await assertFails(getDoc(doc(trainerDb(), 'bodyScans/fx-scan-001')));
  });
});

describe('AC-DF-021.6 server-only collections reject client writes', () => {
  const SERVER_ONLY = [
    'consentRecords', 'memberConsentStates', 'inviteCodes', 'memberSummaries',
    'rightsRequests', 'opsMetrics', 'consentDocumentVersions', 'insightPolicyVersions',
  ];
  const clients = () => [
    ['member', dbFor(M1)],
    ['trainer', trainerDb()],
    ['admin', adminDb()],
  ];

  test('R-20 AC-DF-021.6 member, trainer and admin claim tokens cannot create in server-only collections', async () => {
    for (const [who, db] of clients()) {
      for (const name of SERVER_ONLY) {
        await assertFails(setDoc(doc(db, `${name}/fx-client-${who}`), {
          memberUid: M1, subjectUid: M1, trainerId: T_A, status: 'published',
        }));
      }
    }
  });

  test('R-20 AC-DF-021.6 existing server-written documents cannot be updated or deleted by any client', async () => {
    const existing = [
      'consentRecords/fx-consent-001', `memberConsentStates/${M1}`, 'memberSummaries/fx-summary-001',
      'rightsRequests/fx-rights-001', 'opsMetrics/2026-W40', 'consentDocumentVersions/fx-doc-published',
      'insightPolicyVersions/fx-policy-active',
    ];
    for (const [, db] of clients()) {
      for (const p of existing) {
        await assertFails(updateDoc(doc(db, p), {status: 'fx-changed'}));
        await assertFails(deleteDoc(doc(db, p)));
      }
    }
  });

  test('AC-DF-021.6 appConfig stays read-only (auth read allowed, admin claim write denied)', async () => {
    await assertSucceeds(getDoc(doc(dbFor(M1), 'appConfig/features')));
    await assertFails(setDoc(doc(adminDb(), 'appConfig/features'), {lidarBeta: true}));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'appConfig/features')));
  });
});

describe('AC-DF-021.7 read rules', () => {
  test('R-11 R-12 AC-DF-021.7 memberSummaries: own memberUid or access trainer', async () => {
    await assertSucceeds(getDocs(query(collection(dbFor(M1), 'memberSummaries'), where('memberUid', '==', M1))));
    await assertSucceeds(getDoc(doc(trainerDb(), 'memberSummaries/fx-summary-001')));
    await assertFails(getDocs(query(collection(dbFor(M2), 'memberSummaries'), where('memberUid', '==', M1))));
    await assertFails(getDoc(doc(trainerDb(T_B), 'memberSummaries/fx-summary-001')));
  });

  test('R-28 AC-DF-021.7 consentRecords: subject, assigned trainer, pending owner, admin', async () => {
    await assertSucceeds(getDoc(doc(dbFor(M1), 'consentRecords/fx-consent-001')));
    await assertSucceeds(getDoc(doc(trainerDb(), 'consentRecords/fx-consent-001')));
    await assertSucceeds(getDocs(query(collection(trainerDb(), 'consentRecords'), where('subjectUid', '==', M1))));
    await assertSucceeds(getDoc(doc(trainerDb(), 'consentRecords/fx-consent-002')));
    await assertSucceeds(getDoc(doc(adminDb(), 'consentRecords/fx-consent-001')));
    await assertFails(getDoc(doc(trainerDb(T_B), 'consentRecords/fx-consent-001')));
    await assertFails(getDoc(doc(trainerDb(T_B), 'consentRecords/fx-consent-002')));
    await assertFails(getDoc(doc(dbFor(M2), 'consentRecords/fx-consent-001')));
  });

  test('AC-DF-021.7 memberConsentStates/{k}: k == uid, assigned trainer, pending owner, admin', async () => {
    await assertSucceeds(getDoc(doc(dbFor(M1), `memberConsentStates/${M1}`)));
    await assertSucceeds(getDoc(doc(trainerDb(), `memberConsentStates/${M1}`)));
    await assertSucceeds(getDoc(doc(trainerDb(), `memberConsentStates/${P1}`)));
    await assertSucceeds(getDoc(doc(adminDb(), `memberConsentStates/${M1}`)));
    await assertFails(getDoc(doc(dbFor(M2), `memberConsentStates/${M1}`)));
    await assertFails(getDoc(doc(trainerDb(T_B), `memberConsentStates/${M1}`)));
    await assertFails(getDoc(doc(trainerDb(T_B), `memberConsentStates/${P1}`)));
  });

  test('AC-DF-021.7 consentDocumentVersions: published only for signed-in users', async () => {
    const member = dbFor(M1);
    await assertSucceeds(getDoc(doc(member, 'consentDocumentVersions/fx-doc-published')));
    await assertSucceeds(getDocs(query(collection(member, 'consentDocumentVersions'), where('status', '==', 'published'))));
    await assertSucceeds(getDoc(doc(adminDb(), 'consentDocumentVersions/fx-doc-draft')));
    await assertFails(getDoc(doc(member, 'consentDocumentVersions/fx-doc-draft')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'consentDocumentVersions/fx-doc-published')));
  });

  test('R-25 AC-DF-021.7 insightPolicyVersions: trainer reads approved active bodyChange only', async () => {
    const db = trainerDb();
    await assertSucceeds(getDoc(doc(db, 'insightPolicyVersions/fx-policy-active')));
    await assertSucceeds(getDocs(query(collection(db, 'insightPolicyVersions'),
      where('kind', '==', 'bodyChange'), where('status', '==', 'approved'), where('active', '==', true))));
    await assertSucceeds(getDoc(doc(adminDb(), 'insightPolicyVersions/fx-policy-draft')));
    for (const id of ['fx-policy-draft', 'fx-policy-unapproved-active', 'fx-policy-inactive', 'fx-policy-other-kind']) {
      await assertFails(getDoc(doc(db, `insightPolicyVersions/${id}`)));
    }
    await assertFails(getDoc(doc(dbFor(M1), 'insightPolicyVersions/fx-policy-active')));
  });

  test('AC-DF-021.7 rightsRequests: own memberUid or admin', async () => {
    await assertSucceeds(getDoc(doc(dbFor(M1), 'rightsRequests/fx-rights-001')));
    await assertSucceeds(getDoc(doc(adminDb(), 'rightsRequests/fx-rights-001')));
    await assertFails(getDoc(doc(dbFor(M2), 'rightsRequests/fx-rights-001')));
    await assertFails(getDoc(doc(trainerDb(), 'rightsRequests/fx-rights-001')));
  });

  test('AC-DF-021.7 opsMetrics and inviteCodes: admin only / nobody', async () => {
    await assertSucceeds(getDoc(doc(adminDb(), 'opsMetrics/2026-W40')));
    await assertFails(getDoc(doc(trainerDb(), 'opsMetrics/2026-W40')));
    await assertFails(getDoc(doc(adminDb(), 'inviteCodes/fx-code-hash')));
  });
});

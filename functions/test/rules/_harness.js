// DF-022 규칙 테스트 공통 하네스(V1-05 §9.1, §16).
// - 파일마다 서로 다른 projectId(`dfet-rules-<파일명>`)로 에뮬레이터 환경을 만든다(ASM-P0-26).
// - 시드는 withSecurityRulesDisabled로 넣고, 모든 식별자와 값은 합성이다(실데이터·실제 이름 금지).
// - firestore.rules는 읽기만 한다. rulesTransform은 메모리 사본에만 적용한다(DF-022 금지 사항).
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {Timestamp, doc, serverTimestamp, setDoc} = require('firebase/firestore');

const REPO_ROOT = path.join(__dirname, '../../..');
const RULES_PATH = path.join(REPO_ROOT, 'firestore.rules');

// V1-05 §16 짧은 합성 ID
const IDS = Object.freeze({
  trainerA: 'trainerA',
  trainerB: 'trainerB',
  member1: 'member1',
  member2: 'member2',
  pendA: 'pendA',
  adminX: 'adminX',
});

// V1-05 §9.1 인증 컨텍스트
const TOKENS = Object.freeze({
  trainer: Object.freeze({trainer: true, role: 'trainer'}),
  member: Object.freeze({}),
  admin: Object.freeze({admin: true, role: 'admin'}),
});

// 원 기록 컬렉션(R-05, R-10, R-23). soap_notes 밖은 DF-021 규칙 대상이다.
const RAW_RECORD_COLLECTIONS = Object.freeze([
  'soap_notes',
  'postureAssessments',
  'bodyCompositionRecords',
  'circumferenceMeasurements',
  'bodyScans',
]);

function readRulesText() {
  return fs.readFileSync(RULES_PATH, 'utf8');
}

// `// @mig03-switch` 줄을 `return false;`로 바꾼 메모리 사본(AC-DF-022.3, V1-11 §13.2 롤백 sed와 같은 대상).
// 스위치 줄이 정확히 한 줄이 아니거나 치환 뒤에도 true가 남으면 던진다(조용히 원본을 쓰지 않는다).
function closeLegacySwitch(rulesText) {
  const lines = rulesText.split('\n');
  const hits = lines.map((line, i) => [line, i]).filter(([line]) => line.includes('@mig03-switch'));
  if (hits.length !== 1) {
    throw new Error(`expected exactly one @mig03-switch line, found ${hits.length}`);
  }
  const [line, index] = hits[0];
  const replaced = line.replace(/\{\s*return\s+true\s*;\s*\}/, '{ return false; }');
  if (replaced === line || !/function legacyV1WritesOpen\(\) \{ return false; \}/.test(replaced)) {
    throw new Error('the @mig03-switch line is not in the `{ return true; }` form');
  }
  lines[index] = replaced;
  return lines.join('\n');
}

async function initRulesEnv({projectId, rulesTransform} = {}) {
  if (!projectId || !projectId.startsWith('dfet-rules-')) {
    throw new Error('projectId must start with dfet-rules- (ASM-P0-26)');
  }
  const original = readRulesText();
  const rules = rulesTransform ? rulesTransform(original) : original;
  return initializeTestEnvironment({projectId, firestore: {rules}});
}

function hoursAgo(h) {
  return Timestamp.fromMillis(Date.now() - h * 3600 * 1000);
}

function dbAs(env, uid, token) {
  return env.authenticatedContext(uid, token).firestore();
}

const trainerDb = (env, uid = IDS.trainerA) => dbAs(env, uid, TOKENS.trainer);
const memberDb = (env, uid = IDS.member1) => dbAs(env, uid, TOKENS.member);
const adminDb = (env, uid = IDS.adminX) => dbAs(env, uid, TOKENS.admin);

// 시드: 규칙을 끈 컨텍스트에서 {경로: 데이터}를 한 번에 쓴다.
async function seed(env, docs) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(Object.entries(docs).map(([p, data]) => setDoc(doc(db, p), data)));
  });
}

// ---- 합성 문서 생성기 ----

function seedTrainer(uid, memberIds = []) {
  return {[`trainers/${uid}`]: {trainerId: uid, memberIds, approvalStatus: 'approved'}};
}

// memberConsentStates/{memberKey}. types: {healthData: true, bodyImaging: false, …}
function seedConsent(memberKey, types = {healthData: true}) {
  const past = hoursAgo(24);
  const state = {updatedAt: past, schemaVersion: 1, required: {granted: true, updatedAt: past}};
  for (const [type, granted] of Object.entries(types)) {
    state[type] = {granted, updatedAt: past};
  }
  return {[`memberConsentStates/${memberKey}`]: state};
}

function seedFlags(overrides = {}) {
  return {
    'appConfig/features': {
      gut: false, blood: false, insights: false,
      soapV2: true, bodyComposition: true, bodyAssessment: true, memberShare: true, lidarBeta: false,
      ...overrides,
    },
  };
}

// v2 draft create 페이로드. 타임스탬프는 serverTimestamp()로 보내 `== request.time`을 만족한다.
function v2SoapDoc(overrides = {}) {
  return {
    schemaVersion: 2,
    trainerId: IDS.trainerA,
    authorUid: IDS.trainerA,
    memberUid: IDS.member1,
    memberId: IDS.member1,
    sessionDate: hoursAgo(1),
    status: 'draft',
    quickNote: '합성 메모: 가상 회원이 오른쪽 어깨가 뻐근하다고 말함',
    subjective: {chiefComplaint: '합성 주호소', painNrs: 3, painRegions: ['shoulderRight']},
    plan: {nextSession: '합성 계획: 어깨 가동성 다시 확인', homeExercise: ''},
    legalNature: 'coachingRecord',
    isSharedWithMember: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

// 이미 저장된 v2 문서(시드용). 서버 시각 자리에 고정 과거 시각을 넣는다.
function storedV2SoapDoc(overrides = {}) {
  return {
    ...v2SoapDoc(),
    createdAt: hoursAgo(2),
    updatedAt: hoursAgo(2),
    ...overrides,
  };
}

// 동결 앱(Flutter SoapNote.toFirestore) 형식의 v1 문서. schemaVersion 키가 없다.
function v1SoapDoc(overrides = {}) {
  return {
    trainerId: IDS.trainerA,
    trainerName: '가상 트레이너',
    memberId: IDS.member1,
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

// 원 기록(체형·신체조성·둘레·bodyScans) 최소 합성 문서. 규칙은 DF-021이 만들므로 시드만 한다.
function rawRecordDoc(collectionName, overrides = {}) {
  const base = {
    schemaVersion: 1,
    trainerId: IDS.trainerA,
    memberUid: IDS.member1,
    measuredAt: hoursAgo(3),
    legalNature: 'coachingRecord',
    createdAt: hoursAgo(3),
  };
  const byCollection = {
    postureAssessments: {authorUid: IDS.trainerA, status: 'draft', stationProfileId: 'default-v1', updatedAt: hoursAgo(3)},
    bodyCompositionRecords: {enteredBy: IDS.trainerA, deviceModel: '합성 기기', fasting: true, values: {weightKg: 70.5}},
    circumferenceMeasurements: {authorUid: IDS.trainerA, metricCode: 'waist', valueCm: 80.2, sourceGrade: 'tape'},
    bodyScans: {authorUid: IDS.trainerA, status: 'uploaded'},
  };
  return {...base, ...(byCollection[collectionName] || {}), ...overrides};
}

function pendingMemberDoc(overrides = {}) {
  return {
    trainerId: IDS.trainerA,
    displayName: '가상회원 대기',
    sex: 'unspecified',
    birthYear: 1995,
    ageConfirmed14: true,
    status: 'pending',
    schemaVersion: 1,
    createdAt: hoursAgo(48),
    updatedAt: hoursAgo(48),
    ...overrides,
  };
}

function memberSummaryDoc(overrides = {}) {
  return {
    memberUid: IDS.member1,
    trainerId: IDS.trainerA,
    sharedByUid: IDS.trainerA,
    sourceType: 'soapNote',
    sourceIds: ['fx-note-001'],
    status: 'shared',
    title: '합성 요약',
    sharedAt: hoursAgo(1),
    schemaVersion: 1,
    ...overrides,
  };
}

module.exports = {
  IDS,
  TOKENS,
  RAW_RECORD_COLLECTIONS,
  readRulesText,
  closeLegacySwitch,
  initRulesEnv,
  hoursAgo,
  dbAs,
  trainerDb,
  memberDb,
  adminDb,
  seed,
  seedTrainer,
  seedConsent,
  seedFlags,
  v2SoapDoc,
  storedV2SoapDoc,
  v1SoapDoc,
  rawRecordDoc,
  pendingMemberDoc,
  memberSummaryDoc,
};

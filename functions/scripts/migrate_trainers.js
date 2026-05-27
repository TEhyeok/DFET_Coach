/**
 * 일회성 마이그레이션 스크립트
 *
 * 목적:
 *   - users 컬렉션에서 role == 'trainer' 인 문서를 모두 찾는다
 *   - 각 트레이너에 대해 trainers/{uid} 문서를 (없으면) 생성하고
 *     Custom Claim { trainer: true }를 설정한다
 *   - 기존 soap_notes 문서는 변경하지 않는다 (trainerId가 이미 정합)
 *
 * 사용:
 *   cd functions
 *   node scripts/migrate_trainers.js              # dry-run (변경 없음, 보고만)
 *   node scripts/migrate_trainers.js --apply      # 실제 적용
 *
 * 사전 준비:
 *   functions/service-account-key.json 이 존재해야 함
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const apply = process.argv.includes('--apply');

async function migrate() {
  const db = admin.firestore();
  const usersSnap = await db
    .collection('users')
    .where('role', '==', 'trainer')
    .get();

  console.log(`[info] 트레이너 후보: ${usersSnap.size}명`);

  const report = {
    scanned: usersSnap.size,
    claimSet: 0,
    docCreated: 0,
    docAlreadyExists: 0,
    failures: [],
  };

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const data = userDoc.data();
    const email = data.email || null;
    const displayName = data.displayName || data.name || '';

    try {
      // Custom Claim 확인 및 설정
      const userRecord = await admin.auth().getUser(uid);
      const claims = userRecord.customClaims || {};
      const needsClaim = claims.trainer !== true;

      if (apply && needsClaim) {
        await admin.auth().setCustomUserClaims(uid, { ...claims, trainer: true });
      }
      if (needsClaim) report.claimSet++;

      // trainers/{uid} 문서 확인 및 생성
      const trainerRef = db.collection('trainers').doc(uid);
      const trainerSnap = await trainerRef.get();

      if (trainerSnap.exists) {
        report.docAlreadyExists++;
        console.log(`[skip] trainers/${uid} 이미 존재`);
        continue;
      }

      if (apply) {
        await trainerRef.set({
          trainerId: uid,
          email,
          displayName,
          approvalStatus: 'approved',
          memberIds: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          migratedFromUsers: true,
        });
      }
      report.docCreated++;
      console.log(
        `[${apply ? 'apply' : 'dry'}] trainers/${uid} 생성 (email=${email})`
      );
    } catch (error) {
      console.error(`[error] uid=${uid}:`, error.message);
      report.failures.push({ uid, error: error.message });
    }
  }

  console.log('\n=== 결과 ===');
  console.log(JSON.stringify(report, null, 2));
  if (!apply) {
    console.log('\n실제로 적용하려면 --apply 플래그를 추가하세요.');
  }
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal:', err);
    process.exit(1);
  });

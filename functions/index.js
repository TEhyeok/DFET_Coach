/**
 * Firebase Functions for D-FET Admin Dashboard
 *
 * Functions:
 * - setAdminClaim: 사용자에게 관리자 권한 부여
 * - removeAdminClaim: 사용자의 관리자 권한 제거
 * - listAllUsers: 모든 사용자 목록 조회 (관리자 전용)
 * - setTrainerClaim: 사용자에게 트레이너 권한 부여
 * - removeTrainerClaim: 사용자의 트레이너 권한 제거
 * - assignMemberToTrainer: 트레이너에게 담당 회원 배정
 * - removeMemberFromTrainer: 트레이너 담당 회원 배정 해제
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * 관리자 권한 확인 헬퍼 함수
 */
async function verifyAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }

  const callerUid = context.auth.uid;
  const callerToken = context.auth.token;

  if (!callerToken.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '관리자 권한이 필요합니다.'
    );
  }

  return callerUid;
}

/**
 * 사용자에게 관리자 Custom Claim 부여
 *
 * 사용 방법:
 * const setAdminClaim = httpsCallable(functions, 'setAdminClaim');
 * await setAdminClaim({ email: 'admin@example.com' });
 */
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // 초기 관리자 설정을 위해 특정 이메일만 허용 (필요 시 수정)
  const SUPER_ADMIN_EMAILS = [
    // 여기에 초기 관리자 이메일을 추가하세요
    // 예: 'your-email@example.com'
  ];

  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }

  // 첫 관리자 설정이 아니라면 기존 관리자 권한 확인
  const callerToken = context.auth.token;
  const isSuperAdmin = SUPER_ADMIN_EMAILS.includes(context.auth.token.email);

  if (!callerToken.admin && !isSuperAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '관리자 권한이 필요합니다.'
    );
  }

  const { email } = data;

  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '이메일이 필요합니다.'
    );
  }

  try {
    // 이메일로 사용자 조회
    const user = await admin.auth().getUserByEmail(email);

    // 관리자 Custom Claim 설정
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });

    // Firestore에 관리자 정보 저장 (선택적)
    await admin.firestore().collection('admins').doc(user.uid).set({
      email: user.email,
      displayName: user.displayName || '',
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
      grantedBy: context.auth.uid,
    });

    return {
      success: true,
      message: `${email}에게 관리자 권한이 부여되었습니다.`,
      uid: user.uid,
    };
  } catch (error) {
    console.error('Error setting admin claim:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 사용자의 관리자 Custom Claim 제거
 */
exports.removeAdminClaim = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { email } = data;

  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '이메일이 필요합니다.'
    );
  }

  try {
    // 이메일로 사용자 조회
    const user = await admin.auth().getUserByEmail(email);

    // 관리자 Custom Claim 제거
    await admin.auth().setCustomUserClaims(user.uid, { admin: false });

    // Firestore에서 관리자 정보 삭제
    await admin.firestore().collection('admins').doc(user.uid).delete();

    return {
      success: true,
      message: `${email}의 관리자 권한이 제거되었습니다.`,
      uid: user.uid,
    };
  } catch (error) {
    console.error('Error removing admin claim:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 모든 사용자 목록 조회 (관리자 전용)
 * 페이지네이션 지원
 */
exports.listAllUsers = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { maxResults = 100, pageToken } = data;

  try {
    const listUsersResult = await admin.auth().listUsers(maxResults, pageToken);

    const users = listUsersResult.users.map((userRecord) => ({
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName,
      photoURL: userRecord.photoURL,
      disabled: userRecord.disabled,
      metadata: {
        creationTime: userRecord.metadata.creationTime,
        lastSignInTime: userRecord.metadata.lastSignInTime,
        lastRefreshTime: userRecord.metadata.lastRefreshTime,
      },
      providerData: userRecord.providerData.map((p) => ({
        providerId: p.providerId,
        uid: p.uid,
        displayName: p.displayName,
        email: p.email,
      })),
      customClaims: userRecord.customClaims || {},
    }));

    return {
      users,
      pageToken: listUsersResult.pageToken,
    };
  } catch (error) {
    console.error('Error listing users:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 특정 사용자의 상세 정보 조회 (관리자 전용)
 * Firestore 데이터 포함
 */
exports.getUserDetails = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { uid } = data;

  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID가 필요합니다.'
    );
  }

  try {
    // Auth 정보 조회
    const userRecord = await admin.auth().getUser(uid);

    // Firestore 프로필 조회
    const profileDoc = await admin.firestore().collection('users').doc(uid).get();
    const profileData = profileDoc.exists ? profileDoc.data() : null;

    // 최근 식사 기록 조회 (최근 7일)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const mealsSnapshot = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('meals')
      .where('timestamp', '>=', sevenDaysAgo)
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();

    const meals = mealsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // 최근 운동 기록 조회 (최근 7일)
    const workoutsSnapshot = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('workouts')
      .where('timestamp', '>=', sevenDaysAgo)
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();

    const workouts = workoutsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      auth: {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName,
        photoURL: userRecord.photoURL,
        disabled: userRecord.disabled,
        metadata: userRecord.metadata,
        providerData: userRecord.providerData,
        customClaims: userRecord.customClaims || {},
      },
      profile: profileData,
      recentMeals: meals,
      recentWorkouts: workouts,
    };
  } catch (error) {
    console.error('Error getting user details:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 사용자 데이터 삭제 (관리자 전용)
 * Auth + Firestore 데이터 완전 삭제
 */
exports.deleteUserData = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { uid } = data;

  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID가 필요합니다.'
    );
  }

  try {
    // Firestore 데이터 삭제
    const userRef = admin.firestore().collection('users').doc(uid);

    // 하위 컬렉션 삭제 (meals, workouts)
    const collections = ['meals', 'workouts'];
    for (const collectionName of collections) {
      const snapshot = await userRef.collection(collectionName).get();
      const batch = admin.firestore().batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
    }

    // 사용자 프로필 삭제
    await userRef.delete();

    // Auth 계정 삭제
    await admin.auth().deleteUser(uid);

    return {
      success: true,
      message: `사용자 ${uid}의 모든 데이터가 삭제되었습니다.`,
    };
  } catch (error) {
    console.error('Error deleting user data:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 사용자에게 트레이너 Custom Claim 부여 (관리자 전용)
 *
 * 사용 방법:
 * const setTrainerClaim = httpsCallable(functions, 'setTrainerClaim');
 * await setTrainerClaim({ email: 'trainer@example.com', displayName: '홍길동' });
 */
exports.setTrainerClaim = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { email, displayName, specialty } = data;

  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '이메일이 필요합니다.'
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    // 기존 Claims 보존 + trainer 추가
    const existingClaims = (await admin.auth().getUser(user.uid)).customClaims || {};
    await admin.auth().setCustomUserClaims(user.uid, {
      ...existingClaims,
      trainer: true,
    });

    // trainers 컬렉션 문서 생성 (없으면 새로, 있으면 approvalStatus 갱신)
    await admin.firestore().collection('trainers').doc(user.uid).set(
      {
        trainerId: user.uid,
        email: user.email,
        displayName: displayName || user.displayName || '',
        specialty: specialty || null,
        approvalStatus: 'approved',
        memberIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        grantedBy: context.auth.uid,
      },
      { merge: true }
    );

    return {
      success: true,
      message: `${email}에게 트레이너 권한이 부여되었습니다.`,
      uid: user.uid,
    };
  } catch (error) {
    console.error('Error setting trainer claim:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 사용자의 트레이너 Custom Claim 제거 (관리자 전용)
 * trainers 문서는 approvalStatus를 'revoked'로 변경 (감사 목적 보존)
 */
exports.removeTrainerClaim = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { email } = data;

  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '이메일이 필요합니다.'
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);

    const existingClaims = (await admin.auth().getUser(user.uid)).customClaims || {};
    const { trainer: _omit, ...remainingClaims } = existingClaims;
    await admin.auth().setCustomUserClaims(user.uid, remainingClaims);

    await admin.firestore().collection('trainers').doc(user.uid).set(
      {
        approvalStatus: 'revoked',
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        revokedBy: context.auth.uid,
      },
      { merge: true }
    );

    return {
      success: true,
      message: `${email}의 트레이너 권한이 제거되었습니다.`,
      uid: user.uid,
    };
  } catch (error) {
    console.error('Error removing trainer claim:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 트레이너에게 담당 회원을 배정 (관리자 전용)
 * trainers/{trainerUid}.memberIds에 추가 + users/{memberUid}.trainerId 세팅
 */
exports.assignMemberToTrainer = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { trainerUid, memberUid } = data;

  if (!trainerUid || !memberUid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'trainerUid와 memberUid가 필요합니다.'
    );
  }

  try {
    const db = admin.firestore();
    const trainerRef = db.collection('trainers').doc(trainerUid);
    const memberRef = db.collection('users').doc(memberUid);

    await db.runTransaction(async (tx) => {
      const trainerSnap = await tx.get(trainerRef);
      if (!trainerSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          '대상 트레이너 문서가 존재하지 않습니다.'
        );
      }
      const memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          '대상 회원 문서가 존재하지 않습니다.'
        );
      }

      tx.update(trainerRef, {
        memberIds: admin.firestore.FieldValue.arrayUnion(memberUid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(memberRef, {
        trainerId: trainerUid,
        trainerAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      success: true,
      message: `회원 ${memberUid}이(가) 트레이너 ${trainerUid}에게 배정되었습니다.`,
    };
  } catch (error) {
    console.error('Error assigning member to trainer:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 트레이너 담당 회원 배정 해제 (관리자 전용)
 */
exports.removeMemberFromTrainer = functions.https.onCall(async (data, context) => {
  await verifyAdmin(context);

  const { trainerUid, memberUid } = data;

  if (!trainerUid || !memberUid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'trainerUid와 memberUid가 필요합니다.'
    );
  }

  try {
    const db = admin.firestore();
    const trainerRef = db.collection('trainers').doc(trainerUid);
    const memberRef = db.collection('users').doc(memberUid);

    await db.runTransaction(async (tx) => {
      const trainerSnap = await tx.get(trainerRef);
      if (trainerSnap.exists) {
        tx.update(trainerRef, {
          memberIds: admin.firestore.FieldValue.arrayRemove(memberUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      const memberSnap = await tx.get(memberRef);
      if (memberSnap.exists && memberSnap.data().trainerId === trainerUid) {
        tx.update(memberRef, {
          trainerId: admin.firestore.FieldValue.delete(),
          trainerUnassignedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    return {
      success: true,
      message: `회원 ${memberUid}의 트레이너 배정이 해제되었습니다.`,
    };
  } catch (error) {
    console.error('Error removing member from trainer:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message);
  }
});

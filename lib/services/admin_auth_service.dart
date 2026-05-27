import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_profile.dart';
import '../core/utils/app_logger.dart';

/// 관리자 전용 Firestore 서비스
class AdminAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Admins 컬렉션 참조
  CollectionReference get _adminsCollection => _firestore.collection('admins');

  /// 관리자 프로필 조회
  Future<DocumentSnapshot> getAdminProfile(String uid) async {
    try {
      return await _adminsCollection.doc(uid).get();
    } catch (e, stackTrace) {
      AppLogger.error('관리자 프로필 조회 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 관리자 승인 요청 생성
  Future<void> createAdminRequest({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    try {
      final adminProfile = AdminProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        approvalStatus: 'pending',
        role: 'admin',
      );

      await _adminsCollection.doc(uid).set(adminProfile.toMap());
      AppLogger.info('관리자 승인 요청 생성 완료: $email');
    } catch (e, stackTrace) {
      AppLogger.error('관리자 승인 요청 생성 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 승인 상태 확인
  Future<String> checkApprovalStatus(String uid) async {
    try {
      final doc = await getAdminProfile(uid);
      if (!doc.exists) {
        return 'not_found';
      }
      final profile = AdminProfile.fromMap(doc.data() as Map<String, dynamic>, uid);
      return profile.approvalStatus;
    } catch (e, stackTrace) {
      AppLogger.error('승인 상태 확인 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 슈퍼 어드민 계정 보장 (없으면 생성, 있으면 업데이트)
  Future<void> ensureSuperAdmin(User user) async {
    try {
      final doc = await _adminsCollection.doc(user.uid).get();
      
      if (!doc.exists) {
        // 없으면 생성
        final adminProfile = AdminProfile(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName ?? 'Super Admin',
          createdAt: DateTime.now(),
          approvalStatus: 'approved',
          role: 'super_admin',
          lastLoginAt: DateTime.now(),
        );
        await _adminsCollection.doc(user.uid).set(adminProfile.toMap());
        AppLogger.info('슈퍼 어드민 계정 생성 완료');
      } else {
        // 있으면 권한/상태 강제 업데이트
        await _adminsCollection.doc(user.uid).update({
          'role': 'super_admin',
          'approvalStatus': 'approved',
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('슈퍼 어드민 계정 보장 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 승인 대기 중인 관리자 목록 조회
  Stream<List<AdminProfile>> getPendingAdminsStream() {
    return _adminsCollection
        .where('approvalStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// 모든 관리자 목록 조회
  Stream<List<AdminProfile>> getAllAdminsStream() {
    return _adminsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// 관리자 승인
  Future<void> approveAdmin(String uid) async {
    try {
      await _adminsCollection.doc(uid).update({
        'approvalStatus': 'approved',
      });
      AppLogger.info('관리자 승인 완료: $uid');
    } catch (e, stackTrace) {
      AppLogger.error('관리자 승인 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 관리자 거부
  Future<void> rejectAdmin(String uid) async {
    try {
      await _adminsCollection.doc(uid).update({
        'approvalStatus': 'rejected',
      });
      AppLogger.info('관리자 거부 완료: $uid');
    } catch (e, stackTrace) {
      AppLogger.error('관리자 거부 실패', e, stackTrace);
      rethrow;
    }
  }

  /// 마지막 로그인 시간 업데이트
  Future<void> updateLastLogin(String uid) async {
    try {
      await _adminsCollection.doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      AppLogger.error('마지막 로그인 시간 업데이트 실패', e, stackTrace);
      // 로그만 남기고 에러는 무시 (중요하지 않은 작업)
    }
  }
}

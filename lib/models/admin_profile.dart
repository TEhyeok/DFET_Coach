import 'package:cloud_firestore/cloud_firestore.dart';

/// 관리자 프로필 모델
class AdminProfile {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final String approvalStatus; // 'pending', 'approved', 'rejected'
  final String role; // 'admin', 'super_admin'
  final DateTime? lastLoginAt;

  AdminProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.approvalStatus,
    this.role = 'admin',
    this.lastLoginAt,
  });

  /// Firestore에서 가져온 데이터로부터 생성
  factory AdminProfile.fromMap(Map<String, dynamic> map, String uid) {
    return AdminProfile(
      uid: uid,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      approvalStatus: map['approvalStatus'] as String? ?? 'pending',
      role: map['role'] as String? ?? 'admin',
      lastLoginAt: map['lastLoginAt'] != null
          ? (map['lastLoginAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvalStatus': approvalStatus,
      'role': role,
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  /// copyWith 메서드
  AdminProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    String? approvalStatus,
    String? role,
    DateTime? lastLoginAt,
  }) {
    return AdminProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      role: role ?? this.role,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// 승인 여부 확인
  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';
}

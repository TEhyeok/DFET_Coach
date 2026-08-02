enum CareType {
  microbiome,
  fitness,
  both;

  String get wireValue => name;

  static CareType fromWire(Object? value) {
    return CareType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => CareType.fitness,
    );
  }
}

/// 기존 호출부의 의미를 보존하면서 문자열 대신 [CareType]을 사용한다.
abstract final class UserCareType {
  static const microbiome = CareType.microbiome;
  static const fitness = CareType.fitness;
  static const both = CareType.both;

  static const all = CareType.values;

  static String label(CareType? type) {
    switch (type) {
      case microbiome:
        return '장내미생물 케어';
      case fitness:
        return '운동·신체조성';
      case both:
        return '통합 케어';
      default:
        return '운동·신체조성';
    }
  }
}

/// 사용자 프로필 모델
class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? provider; // 'google', 'apple'
  final DateTime createdAt;
  final DateTime lastLoginAt;

  // Onboarding Data
  final String? gender;
  final int? age;
  final double? height;
  final double? weight;
  final String? activityLevel;
  final String? goal; // Added goal field
  final CareType careType;
  final int careTypeVersion;
  final DateTime? careTypeConfirmedAt;
  final bool isOnboardingComplete;

  // Subscription Data
  final bool isPremium;
  final DateTime? subscriptionExpiryDate;

  // Admin Data
  final bool isApproved; // 관리자 승인 여부
  final String role; // 'user', 'trainer', 'admin'

  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.provider,
    required this.createdAt,
    required this.lastLoginAt,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.activityLevel,
    this.goal,
    this.careType = UserCareType.fitness,
    this.careTypeVersion = 0,
    this.careTypeConfirmedAt,
    this.isOnboardingComplete = false,
    this.isPremium = false,
    this.subscriptionExpiryDate,
    this.isApproved = false,
    this.role = 'user',
  });

  bool get isTrainer => role == 'trainer';

  bool get isAdmin => role == 'admin';

  /// Firestore에서 가져온 데이터로부터 생성
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      provider: map['provider'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLoginAt'] as int)
          : DateTime.now(),
      gender: map['gender'] as String?,
      age: map['age'] as int?,
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      activityLevel: map['activityLevel'] as String?,
      goal: map['goal'] as String?,
      careType: CareType.fromWire(map['careType']),
      careTypeVersion: map['careTypeVersion'] as int? ?? 0,
      careTypeConfirmedAt: map['careTypeConfirmedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['careTypeConfirmedAt'] as int,
            )
          : null,
      isOnboardingComplete: map['isOnboardingComplete'] as bool? ?? false,
      isPremium: map['isPremium'] as bool? ?? false,
      subscriptionExpiryDate: map['subscriptionExpiryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['subscriptionExpiryDate'] as int)
          : null,
      isApproved: map['isApproved'] as bool? ?? false,
      role: map['role'] as String? ?? 'user',
    );
  }

  /// Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'provider': provider,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt.millisecondsSinceEpoch,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'goal': goal,
      'careType': careType.wireValue,
      'careTypeVersion': careTypeVersion,
      'careTypeConfirmedAt': careTypeConfirmedAt?.millisecondsSinceEpoch,
      'isOnboardingComplete': isOnboardingComplete,
      'isPremium': isPremium,
      'subscriptionExpiryDate': subscriptionExpiryDate?.millisecondsSinceEpoch,
      'isApproved': isApproved,
      'role': role,
    };
  }

  /// copyWith 메서드
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? provider,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? activityLevel,
    String? goal,
    CareType? careType,
    int? careTypeVersion,
    DateTime? careTypeConfirmedAt,
    bool? isOnboardingComplete,
    bool? isPremium,
    DateTime? subscriptionExpiryDate,
    bool? isApproved,
    String? role,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      careType: careType ?? this.careType,
      careTypeVersion: careTypeVersion ?? this.careTypeVersion,
      careTypeConfirmedAt: careTypeConfirmedAt ?? this.careTypeConfirmedAt,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      isPremium: isPremium ?? this.isPremium,
      subscriptionExpiryDate:
          subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      isApproved: isApproved ?? this.isApproved,
      role: role ?? this.role,
    );
  }
}

/// User body calibration data for personalized pose assessment
class UserCalibration {
  final String userId;
  final DateTime calibratedAt;

  // Body proportions (normalized ratios)
  final double armLengthRatio; // Upper arm to forearm ratio
  final double legLengthRatio; // Thigh to lower leg ratio
  final double torsoLengthRatio; // Torso to leg ratio
  final double shoulderWidthRatio; // Shoulder width to torso length

  // Resting angles (user's natural joint positions)
  final double naturalKneeAngle; // Standing knee angle
  final double naturalHipAngle; // Standing hip angle
  final double naturalShoulderAngle; // Natural shoulder position

  // Flexibility ranges (determined during calibration)
  final double maxKneeFlexion; // Maximum comfortable knee bend
  final double maxHipFlexion; // Maximum comfortable hip bend

  UserCalibration({
    required this.userId,
    required this.calibratedAt,
    this.armLengthRatio = 1.0,
    this.legLengthRatio = 1.0,
    this.torsoLengthRatio = 0.5,
    this.shoulderWidthRatio = 0.4,
    this.naturalKneeAngle = 175.0,
    this.naturalHipAngle = 175.0,
    this.naturalShoulderAngle = 15.0,
    this.maxKneeFlexion = 90.0,
    this.maxHipFlexion = 90.0,
  });

  /// Create calibration from standing pose measurement
  factory UserCalibration.fromStandingPose({
    required String userId,
    required Map<String, double> measurements,
  }) {
    return UserCalibration(
      userId: userId,
      calibratedAt: DateTime.now(),
      armLengthRatio: measurements['armLengthRatio'] ?? 1.0,
      legLengthRatio: measurements['legLengthRatio'] ?? 1.0,
      torsoLengthRatio: measurements['torsoLengthRatio'] ?? 0.5,
      shoulderWidthRatio: measurements['shoulderWidthRatio'] ?? 0.4,
      naturalKneeAngle: measurements['naturalKneeAngle'] ?? 175.0,
      naturalHipAngle: measurements['naturalHipAngle'] ?? 175.0,
      naturalShoulderAngle: measurements['naturalShoulderAngle'] ?? 15.0,
    );
  }

  /// Get adjusted squat angle threshold based on user's body proportions
  double getSquatTargetAngle() {
    // Users with longer legs relative to torso may need different angles
    // Base target is 90 degrees, adjust based on leg ratio
    final adjustment = (legLengthRatio - 1.0) * 10;
    return 90.0 + adjustment;
  }

  /// Get minimum acceptable squat depth based on user's flexibility
  double getMinSquatDepth() {
    // Allow 20% less than max flexion as comfortable target
    return maxKneeFlexion * 0.8;
  }

  /// Check if calibration is still valid (within 30 days)
  bool get isValid {
    final daysSinceCalibration = DateTime.now().difference(calibratedAt).inDays;
    return daysSinceCalibration <= 30;
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'calibratedAt': calibratedAt.toIso8601String(),
      'armLengthRatio': armLengthRatio,
      'legLengthRatio': legLengthRatio,
      'torsoLengthRatio': torsoLengthRatio,
      'shoulderWidthRatio': shoulderWidthRatio,
      'naturalKneeAngle': naturalKneeAngle,
      'naturalHipAngle': naturalHipAngle,
      'naturalShoulderAngle': naturalShoulderAngle,
      'maxKneeFlexion': maxKneeFlexion,
      'maxHipFlexion': maxHipFlexion,
    };
  }

  /// Create from stored map
  factory UserCalibration.fromMap(Map<String, dynamic> map) {
    return UserCalibration(
      userId: map['userId'] as String,
      calibratedAt: DateTime.parse(map['calibratedAt'] as String),
      armLengthRatio: (map['armLengthRatio'] as num?)?.toDouble() ?? 1.0,
      legLengthRatio: (map['legLengthRatio'] as num?)?.toDouble() ?? 1.0,
      torsoLengthRatio: (map['torsoLengthRatio'] as num?)?.toDouble() ?? 0.5,
      shoulderWidthRatio:
          (map['shoulderWidthRatio'] as num?)?.toDouble() ?? 0.4,
      naturalKneeAngle: (map['naturalKneeAngle'] as num?)?.toDouble() ?? 175.0,
      naturalHipAngle: (map['naturalHipAngle'] as num?)?.toDouble() ?? 175.0,
      naturalShoulderAngle:
          (map['naturalShoulderAngle'] as num?)?.toDouble() ?? 15.0,
      maxKneeFlexion: (map['maxKneeFlexion'] as num?)?.toDouble() ?? 90.0,
      maxHipFlexion: (map['maxHipFlexion'] as num?)?.toDouble() ?? 90.0,
    );
  }
}

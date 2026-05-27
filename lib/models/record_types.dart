enum RecordSection {
  meals,
  workouts,
  posture,
}

enum RecordEntryMode {
  manualMeal,
  photoMeal,
  workout,
  posture,
}

extension RecordSectionLabel on RecordSection {
  String get label {
    switch (this) {
      case RecordSection.meals:
        return '식단';
      case RecordSection.workouts:
        return '운동';
      case RecordSection.posture:
        return '자세';
    }
  }
}

extension RecordEntryModeLabel on RecordEntryMode {
  String get title {
    switch (this) {
      case RecordEntryMode.manualMeal:
        return '식단 직접 입력';
      case RecordEntryMode.photoMeal:
        return '사진으로 식단 분석';
      case RecordEntryMode.workout:
        return '운동 기록 추가';
      case RecordEntryMode.posture:
        return '자세 평가 시작';
    }
  }
}

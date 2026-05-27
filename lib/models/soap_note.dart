enum SoapCategory {
  meta,
  subjective,
  objective,
  assessment,
  plan,
  sharing,
}

class SoapMetric {
  const SoapMetric({
    this.type = 'general',
    this.label = '',
    this.side = '',
    this.value = '',
    this.unit = '',
    this.score,
    this.note = '',
  });

  final String type;
  final String label;
  final String side;
  final String value;
  final String unit;
  final int? score;
  final String note;

  factory SoapMetric.fromMap(Map<String, dynamic> map) {
    return SoapMetric(
      type: map['type'] as String? ?? 'general',
      label: map['label'] as String? ?? '',
      side: map['side'] as String? ?? '',
      value: '${map['value'] ?? ''}',
      unit: map['unit'] as String? ?? '',
      score: (map['score'] as num?)?.toInt(),
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'side': side,
      'value': value,
      'unit': unit,
      'score': score,
      'note': note,
    };
  }
}

class SoapWorkflow {
  const SoapWorkflow({
    this.status = 'draft',
    this.completedCategories = const [],
    this.riskLevel = 'low',
    this.followUpDate,
  });

  final String status;
  final List<String> completedCategories;
  final String riskLevel;
  final DateTime? followUpDate;

  factory SoapWorkflow.fromMap(Map<String, dynamic> map) {
    return SoapWorkflow(
      status: map['status'] as String? ?? 'draft',
      completedCategories: (map['completedCategories'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      riskLevel: map['riskLevel'] as String? ?? 'low',
      followUpDate: _nullableDateFromMillis(map['followUpDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'completedCategories': completedCategories,
      'riskLevel': riskLevel,
      'followUpDate': followUpDate?.millisecondsSinceEpoch,
    };
  }
}

class SoapStructuredData {
  const SoapStructuredData({
    this.subjective = const {},
    this.objective = const {},
    this.assessment = const {},
    this.plan = const {},
    this.metrics = const [],
    this.workflow = const SoapWorkflow(),
  });

  final Map<String, dynamic> subjective;
  final Map<String, dynamic> objective;
  final Map<String, dynamic> assessment;
  final Map<String, dynamic> plan;
  final List<SoapMetric> metrics;
  final SoapWorkflow workflow;

  factory SoapStructuredData.fromMap(Map<String, dynamic> map) {
    return SoapStructuredData(
      subjective: _stringKeyMap(map['subjective']),
      objective: _stringKeyMap(map['objective']),
      assessment: _stringKeyMap(map['assessment']),
      plan: _stringKeyMap(map['plan']),
      metrics: (map['metrics'] as List<dynamic>?)
              ?.whereType<Map>()
              .map(
                  (item) => SoapMetric.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          const [],
      workflow: map['workflow'] is Map
          ? SoapWorkflow.fromMap(
              Map<String, dynamic>.from(map['workflow'] as Map),
            )
          : const SoapWorkflow(),
    );
  }

  factory SoapStructuredData.fromLegacy(SoapNote note) {
    final completed = <String>[];

    if (note.memberName.trim().isNotEmpty) completed.add('meta');
    if (note.subjective.trim().isNotEmpty ||
        note.painSite.trim().isNotEmpty ||
        note.painNow != null) {
      completed.add('subjective');
    }
    if (note.observation.trim().isNotEmpty ||
        note.rom.trim().isNotEmpty ||
        note.mmt.trim().isNotEmpty ||
        note.functionalTests.trim().isNotEmpty) {
      completed.add('objective');
    }
    if (note.assessment.trim().isNotEmpty ||
        note.shortTermGoal.trim().isNotEmpty ||
        note.longTermGoal.trim().isNotEmpty) {
      completed.add('assessment');
    }
    if (note.treatmentPlan.trim().isNotEmpty ||
        note.homeExercise.trim().isNotEmpty ||
        note.nextPlan.trim().isNotEmpty) {
      completed.add('plan');
    }
    completed.add('sharing');

    return SoapStructuredData(
      subjective: {
        'chiefComplaint': note.subjective,
        'painSite': note.painSite,
        'painPattern': note.painPattern,
        'painNow': note.painNow,
        'painBest': note.painBest,
        'painWorst': note.painWorst,
      },
      objective: {
        'observation': note.observation,
        'neurologicalTests': note.neurologicalTests,
        'specialTests': note.specialTests,
        'functionalTests': note.functionalTests,
      },
      assessment: {
        'problemList': note.assessment,
        'shortTermGoal': note.shortTermGoal,
        'longTermGoal': note.longTermGoal,
      },
      plan: {
        'treatmentPlan': note.treatmentPlan,
        'homeExercise': note.homeExercise,
        'nextPlan': note.nextPlan,
      },
      metrics: [
        if (note.rom.trim().isNotEmpty)
          SoapMetric(type: 'rom', label: 'ROM', value: note.rom, unit: 'deg'),
        if (note.mmt.trim().isNotEmpty)
          SoapMetric(type: 'mmt', label: 'MMT', value: note.mmt, unit: 'grade'),
      ],
      workflow: SoapWorkflow(
        status: completed.length >= SoapCategory.values.length
            ? 'complete'
            : 'draft',
        completedCategories: completed,
        riskLevel: _riskFromPain(note.painWorst ?? note.painNow),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'workflow': workflow.toMap(),
    };
  }

  SoapStructuredData copyWith({
    Map<String, dynamic>? subjective,
    Map<String, dynamic>? objective,
    Map<String, dynamic>? assessment,
    Map<String, dynamic>? plan,
    List<SoapMetric>? metrics,
    SoapWorkflow? workflow,
  }) {
    return SoapStructuredData(
      subjective: subjective ?? this.subjective,
      objective: objective ?? this.objective,
      assessment: assessment ?? this.assessment,
      plan: plan ?? this.plan,
      metrics: metrics ?? this.metrics,
      workflow: workflow ?? this.workflow,
    );
  }
}

class SoapNote {
  const SoapNote({
    required this.id,
    required this.trainerId,
    this.trainerName,
    this.memberId,
    required this.memberName,
    this.memberEmail,
    required this.date,
    this.visitType = 'initial',
    this.setting = 'field',
    this.diagnosis = '',
    this.bodyRegion = '',
    this.caseStatus = 'active',
    this.subjective = '',
    this.painSite = '',
    this.painPattern = '',
    this.painNow,
    this.painBest,
    this.painWorst,
    this.observation = '',
    this.rom = '',
    this.mmt = '',
    this.neurologicalTests = '',
    this.specialTests = '',
    this.functionalTests = '',
    this.assessment = '',
    this.shortTermGoal = '',
    this.longTermGoal = '',
    this.treatmentPlan = '',
    this.homeExercise = '',
    this.nextPlan = '',
    this.isSharedWithMember = true,
    this.structured,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String trainerId;
  final String? trainerName;
  final String? memberId;
  final String memberName;
  final String? memberEmail;
  final DateTime date;
  final String visitType;
  final String setting;
  final String diagnosis;
  final String bodyRegion;
  final String caseStatus;
  final String subjective;
  final String painSite;
  final String painPattern;
  final int? painNow;
  final int? painBest;
  final int? painWorst;
  final String observation;
  final String rom;
  final String mmt;
  final String neurologicalTests;
  final String specialTests;
  final String functionalTests;
  final String assessment;
  final String shortTermGoal;
  final String longTermGoal;
  final String treatmentPlan;
  final String homeExercise;
  final String nextPlan;
  final bool isSharedWithMember;
  final SoapStructuredData? structured;
  final DateTime createdAt;
  final DateTime updatedAt;

  SoapStructuredData get effectiveStructured =>
      structured ?? SoapStructuredData.fromLegacy(this);

  int get completionPercent {
    final completed = effectiveStructured.workflow.completedCategories.toSet();
    final count = SoapCategory.values
        .where((category) => completed.contains(category.name))
        .length;
    return ((count / SoapCategory.values.length) * 100).round().clamp(0, 100);
  }

  String get riskLevel => effectiveStructured.workflow.riskLevel;

  DateTime? get followUpDate => effectiveStructured.workflow.followUpDate;

  factory SoapNote.fromFirestore(Map<String, dynamic> data, String id) {
    final note = SoapNote(
      id: id,
      trainerId: data['trainerId'] as String? ?? '',
      trainerName: data['trainerName'] as String?,
      memberId: data['memberId'] as String?,
      memberName: data['memberName'] as String? ?? '이름 없음',
      memberEmail: data['memberEmail'] as String?,
      date: _dateFromMillis(data['date']),
      visitType: data['visitType'] as String? ?? 'initial',
      setting: data['setting'] as String? ?? 'field',
      diagnosis: data['diagnosis'] as String? ?? '',
      bodyRegion: data['bodyRegion'] as String? ?? '',
      caseStatus: data['caseStatus'] as String? ?? 'active',
      subjective: data['subjective'] as String? ?? '',
      painSite: data['painSite'] as String? ?? '',
      painPattern: data['painPattern'] as String? ?? '',
      painNow: (data['painNow'] as num?)?.toInt(),
      painBest: (data['painBest'] as num?)?.toInt(),
      painWorst: (data['painWorst'] as num?)?.toInt(),
      observation: data['observation'] as String? ?? '',
      rom: data['rom'] as String? ?? '',
      mmt: data['mmt'] as String? ?? '',
      neurologicalTests: data['neurologicalTests'] as String? ?? '',
      specialTests: data['specialTests'] as String? ?? '',
      functionalTests: data['functionalTests'] as String? ?? '',
      assessment: data['assessment'] as String? ?? '',
      shortTermGoal: data['shortTermGoal'] as String? ?? '',
      longTermGoal: data['longTermGoal'] as String? ?? '',
      treatmentPlan: data['treatmentPlan'] as String? ?? '',
      homeExercise: data['homeExercise'] as String? ?? '',
      nextPlan: data['nextPlan'] as String? ?? '',
      isSharedWithMember: data['isSharedWithMember'] as bool? ?? true,
      structured: data['structured'] is Map
          ? SoapStructuredData.fromMap(
              Map<String, dynamic>.from(data['structured'] as Map),
            )
          : null,
      createdAt: _dateFromMillis(data['createdAt']),
      updatedAt: _dateFromMillis(data['updatedAt']),
    );

    return note.structured == null
        ? note.copyWith(structured: SoapStructuredData.fromLegacy(note))
        : note;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'trainerId': trainerId,
      'trainerName': trainerName,
      'memberId': memberId,
      'memberName': memberName,
      'memberEmail': memberEmail,
      'date': date.millisecondsSinceEpoch,
      'visitType': visitType,
      'setting': setting,
      'diagnosis': diagnosis,
      'bodyRegion': bodyRegion,
      'caseStatus': caseStatus,
      'subjective': subjective,
      'painSite': painSite,
      'painPattern': painPattern,
      'painNow': painNow,
      'painBest': painBest,
      'painWorst': painWorst,
      'observation': observation,
      'rom': rom,
      'mmt': mmt,
      'neurologicalTests': neurologicalTests,
      'specialTests': specialTests,
      'functionalTests': functionalTests,
      'assessment': assessment,
      'shortTermGoal': shortTermGoal,
      'longTermGoal': longTermGoal,
      'treatmentPlan': treatmentPlan,
      'homeExercise': homeExercise,
      'nextPlan': nextPlan,
      'isSharedWithMember': isSharedWithMember,
      'structured': effectiveStructured.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  SoapNote copyWith({
    String? id,
    String? trainerId,
    String? trainerName,
    String? memberId,
    String? memberName,
    String? memberEmail,
    DateTime? date,
    String? visitType,
    String? setting,
    String? diagnosis,
    String? bodyRegion,
    String? caseStatus,
    String? subjective,
    String? painSite,
    String? painPattern,
    int? painNow,
    int? painBest,
    int? painWorst,
    String? observation,
    String? rom,
    String? mmt,
    String? neurologicalTests,
    String? specialTests,
    String? functionalTests,
    String? assessment,
    String? shortTermGoal,
    String? longTermGoal,
    String? treatmentPlan,
    String? homeExercise,
    String? nextPlan,
    bool? isSharedWithMember,
    SoapStructuredData? structured,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SoapNote(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberEmail: memberEmail ?? this.memberEmail,
      date: date ?? this.date,
      visitType: visitType ?? this.visitType,
      setting: setting ?? this.setting,
      diagnosis: diagnosis ?? this.diagnosis,
      bodyRegion: bodyRegion ?? this.bodyRegion,
      caseStatus: caseStatus ?? this.caseStatus,
      subjective: subjective ?? this.subjective,
      painSite: painSite ?? this.painSite,
      painPattern: painPattern ?? this.painPattern,
      painNow: painNow ?? this.painNow,
      painBest: painBest ?? this.painBest,
      painWorst: painWorst ?? this.painWorst,
      observation: observation ?? this.observation,
      rom: rom ?? this.rom,
      mmt: mmt ?? this.mmt,
      neurologicalTests: neurologicalTests ?? this.neurologicalTests,
      specialTests: specialTests ?? this.specialTests,
      functionalTests: functionalTests ?? this.functionalTests,
      assessment: assessment ?? this.assessment,
      shortTermGoal: shortTermGoal ?? this.shortTermGoal,
      longTermGoal: longTermGoal ?? this.longTermGoal,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      homeExercise: homeExercise ?? this.homeExercise,
      nextPlan: nextPlan ?? this.nextPlan,
      isSharedWithMember: isSharedWithMember ?? this.isSharedWithMember,
      structured: structured ?? this.structured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

Map<String, dynamic> _stringKeyMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

DateTime _dateFromMillis(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

DateTime? _nullableDateFromMillis(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

String _riskFromPain(int? pain) {
  if (pain == null) return 'low';
  if (pain >= 8) return 'high';
  if (pain >= 5) return 'medium';
  return 'low';
}

import 'package:dfet_coach/models/soap_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy string-only SOAP notes gain structured fallback data', () {
    final now = DateTime(2026, 4, 30, 10);
    final note = SoapNote.fromFirestore(
      {
        'trainerId': 'trainer-1',
        'memberName': '김회원',
        'date': now.millisecondsSinceEpoch,
        'diagnosis': 'low back pain',
        'subjective': '허리 통증',
        'painSite': 'lumbar',
        'painNow': 6,
        'painWorst': 8,
        'observation': 'squat 시 trunk shift',
        'rom': 'hip flexion 95',
        'mmt': 'glute med 4',
        'assessment': 'lumbopelvic control deficit',
        'treatmentPlan': 'mobility and motor control',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      },
      'legacy-1',
    );

    expect(note.structured, isNotNull);
    expect(
      note.effectiveStructured.subjective['chiefComplaint'],
      '허리 통증',
    );
    expect(note.effectiveStructured.metrics.map((metric) => metric.type), [
      'rom',
      'mmt',
    ]);
    expect(note.riskLevel, 'high');
    expect(note.completionPercent, greaterThan(50));
    expect(note.toFirestore()['structured'], isA<Map<String, dynamic>>());
  });

  test('structured SOAP note serializes and deserializes without data loss',
      () {
    final now = DateTime(2026, 4, 30, 14);
    final followUp = DateTime(2026, 5, 14);
    final note = SoapNote(
      id: 'note-1',
      trainerId: 'trainer-1',
      memberName: '이회원',
      memberEmail: 'member@example.com',
      date: now,
      diagnosis: 'knee pain',
      subjective: '계단 하강 시 통증',
      painNow: 7,
      observation: 'dynamic valgus',
      assessment: 'load tolerance deficit',
      treatmentPlan: 'strength progression',
      structured: SoapStructuredData(
        subjective: const {
          'chiefComplaint': '계단 하강 시 통증',
          'painNow': 7,
          'painWorst': 9,
        },
        objective: const {
          'observation': 'dynamic valgus',
          'palpation': 'lateral joint line tenderness',
        },
        assessment: const {
          'problemList': 'load tolerance deficit',
          'clinicalJudgement': 'monitor swelling response',
        },
        plan: {
          'treatmentPlan': 'strength progression',
          'followUpDate': followUp.millisecondsSinceEpoch,
        },
        metrics: const [
          SoapMetric(
            type: 'rom',
            label: 'Knee flexion',
            side: 'R',
            value: '125',
            unit: 'deg',
            score: 4,
            note: 'mild pain end range',
          ),
        ],
        workflow: SoapWorkflow(
          status: 'complete',
          completedCategories:
              SoapCategory.values.map((category) => category.name).toList(),
          riskLevel: 'high',
          followUpDate: followUp,
        ),
      ),
      createdAt: now,
      updatedAt: now,
    );

    final encoded = note.toFirestore();
    final decoded = SoapNote.fromFirestore(encoded, note.id);

    expect(decoded.effectiveStructured.metrics.single.label, 'Knee flexion');
    expect(decoded.effectiveStructured.objective['palpation'],
        'lateral joint line tenderness');
    expect(decoded.riskLevel, 'high');
    expect(decoded.followUpDate, followUp);
    expect(decoded.completionPercent, 100);
  });
}

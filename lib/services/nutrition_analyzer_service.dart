import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import '../core/utils/app_logger.dart';

/// Gemini Vision API를 사용한 음식 영양소 분석 서비스
class NutritionAnalyzerService {
  /// 음식 사진을 분석하여 영양소 정보를 반환
  Future<Map<String, dynamic>> analyzeFood(Uint8List imageBytes) async {
    AppLogger.info('[NutritionAnalyzer] 분석 시작...');

    try {
      // Gemini 2.0 Flash 모델 초기화
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash-exp',
      );

      AppLogger.debug('[NutritionAnalyzer] Gemini 모델 초기화 완료');

      // 프롬프트 생성
      final prompt = _buildPrompt();
      AppLogger.debug('[NutritionAnalyzer] 프롬프트 준비 완료');

      // Gemini API 호출 (30초 타임아웃)
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ])
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.warning('[NutritionAnalyzer] API 요청 타임아웃 (30초)');
          throw TimeoutException('AI 분석 요청이 30초를 초과했습니다');
        },
      );

      AppLogger.info('[NutritionAnalyzer] Gemini 응답 받음');

      final responseText = response.text ?? '{}';
      AppLogger.debug('[NutritionAnalyzer] 응답 텍스트 길이: ${responseText.length}');

      // JSON 파싱
      final jsonText = _extractJson(responseText);
      final result = jsonDecode(jsonText) as Map<String, dynamic>;

      // 토큰 사용량 추가
      if (response.usageMetadata != null) {
        result['aiTokenUsage'] = {
          'promptTokens': response.usageMetadata!.promptTokenCount,
          'responseTokens': response.usageMetadata!.candidatesTokenCount,
          'totalTokens': response.usageMetadata!.totalTokenCount,
          'model': 'gemini-2.0-flash-exp',
        };
      }

      AppLogger.info('[NutritionAnalyzer] 분석 완료: ${result['name']}');

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[NutritionAnalyzer] 분석 중 에러 발생', e, stackTrace);

      // 에러 발생 시 기본값 반환
      return {
        'name': '분석 실패',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'confidence': '낮음',
        'error': e.toString(),
      };
    }
  }

  /// 프롬프트 생성
  String _buildPrompt() {
    return '''
당신은 영양 전문가입니다. 아래 이미지를 분석하세요.

**중요**: 먼저 이미지가 음식인지 판단하세요.

음식이 아닌 경우 (예: 사람, 동물, 사물, 풍경 등):
- is_food를 false로 설정
- name을 "음식이 아님"으로 설정
- reason에 무엇이 보이는지 설명 (예: "노트북 컴퓨터", "강아지", "책상")
- 나머지 필드는 모두 0

음식인 경우:
- is_food를 true로 설정
- 다음 기준으로 분석:
  1. 음식명: 정확한 한국어 또는 영어 이름
  2. 칼로리: 일반적인 1인분 기준 (kcal)
  3. 영양소: 단백질/탄수화물/지방 (그램 단위)
  4. 신뢰도: 분석의 확실성 (높음/중간/낮음)

출력 형식 (JSON만 출력하고 다른 텍스트는 넣지 마세요):
{
  "is_food": true,
  "name": "음식명",
  "reason": "",
  "calories": 500,
  "protein": 30,
  "carbs": 60,
  "fat": 15,
  "confidence": "높음"
}

주의사항:
- 한국 음식은 한식영양성분표 기준 사용
- 그릇 크기로 양 추정
- 소스/양념도 포함해서 계산
- 반드시 JSON 형식으로만 출력
- 음식이 아니면 is_food를 false로 설정하고 이유를 명확히 작성
''';
  }

  /// JSON 텍스트 추출 (마크다운 코드 블록 제거)
  String _extractJson(String text) {
    // ```json ... ``` 형식 제거
    final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(1)!.trim();
    }

    // ``` ... ``` 형식 제거
    final codeMatch = RegExp(r'```\s*([\s\S]*?)\s*```').firstMatch(text);
    if (codeMatch != null) {
      return codeMatch.group(1)!.trim();
    }

    // { ... } JSON 객체 추출
    final jsonObjMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonObjMatch != null) {
      return jsonObjMatch.group(0)!.trim();
    }

    // 그대로 반환
    return text.trim();
  }
}

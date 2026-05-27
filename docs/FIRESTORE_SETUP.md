# Firestore 설정 가이드

## 1. Firebase Console에서 Firestore 활성화

1. [Firebase Console](https://console.firebase.google.com/project/dfetmanage/overview) 접속
2. 왼쪽 메뉴에서 **Build** → **Firestore Database** 선택
3. **Create database** 클릭
4. 보안 규칙 선택:
   - **Production mode** 선택 (이미 firestore.rules에 규칙 정의되어 있음)
5. 위치 선택:
   - **asia-northeast3 (Seoul)** 권장 (한국 사용자 대상)
6. **Enable** 클릭

## 2. Firestore Rules 배포 확인

터미널에서 다음 명령어 실행:

```bash
firebase deploy --only firestore:rules
```

출력 예시:
```
✔  firestore: released rules firestore.rules to cloud.firestore
✔  Deploy complete!
```

## 3. Firestore 데이터 구조

### Collections

#### `meals` 컬렉션
각 문서 ID는 Meal의 고유 ID이며, 필드는 다음과 같습니다:

```json
{
  "time": "07:40",
  "name": "오트+계란",
  "calories": 450,
  "protein": 25,
  "carbs": 50,
  "fat": 12,
  "timestamp": "2025-01-15T07:40:00Z"
}
```

#### `workouts` 컬렉션
각 문서 ID는 Workout의 고유 ID이며, 필드는 다음과 같습니다:

```json
{
  "name": "벤치프레스",
  "category": "strength",
  "sets": [
    {"reps": 10, "weight": 60.0},
    {"reps": 8, "weight": 65.0},
    {"reps": 6, "weight": 70.0}
  ],
  "duration": 0,
  "timestamp": "2025-01-15T10:00:00Z",
  "postureScore": 85.5,
  "formFeedback": "무릎이 발끝을 넘지 않도록 주의하세요",
  "assessmentVideoPath": null
}
```

## 4. 보안 규칙

현재 개발 환경에서는 모든 읽기/쓰기를 허용합니다:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /meals/{mealId} {
      allow read, write: if true;
    }

    match /workouts/{workoutId} {
      allow read, write: if true;
    }
  }
}
```

**⚠️ 프로덕션 환경 주의사항**:
프로덕션 배포 전에 사용자 인증을 추가해야 합니다:

```javascript
// 프로덕션 규칙 예시 (Firebase Authentication 필요)
match /meals/{mealId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## 5. 오프라인 지속성 (선택사항)

Firestore는 기본적으로 오프라인 캐싱을 지원합니다. 추가 설정 없이도:
- 오프라인 시 로컬 캐시 사용
- 온라인 복귀 시 자동 동기화

명시적으로 활성화하려면 `lib/main.dart`에 추가:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// Firestore 오프라인 지속성 활성화
final firestore = FirebaseFirestore.instance;
firestore.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## 6. 테스트

앱을 실행하고 다음을 확인:

1. **초기 로드**: 앱 시작 시 Firestore에서 데이터 로드
2. **데이터 추가**: 식단/운동 추가 시 Firestore에 저장
3. **데이터 삭제**: 식단/운동 삭제 시 Firestore에서 삭제
4. **앱 재시작**: 데이터가 유지되는지 확인

로그에서 확인:
```
🐛 [FirestoreService] 식단 데이터 로드 중...
💡 [FirestoreService] 식단 4개 로드 완료
🐛 [FirestoreService] 식단 추가: 바나나
💡 [FirestoreService] 식단 추가 성공: 식단ID
```

## 7. 문제 해결

### "Permission denied" 오류
- Firebase Console에서 Firestore Rules가 올바르게 배포되었는지 확인
- 개발 환경에서는 `allow read, write: if true;` 사용

### "Timeout" 오류 (10초)
- 인터넷 연결 확인
- Firebase 프로젝트가 올바른지 확인
- Firestore 데이터베이스가 활성화되었는지 확인

### "Collection not found" 오류
- 첫 실행 시 자동으로 컬렉션이 생성됩니다
- Firebase Console에서 수동으로 생성할 필요 없음

## 8. 모니터링

Firebase Console → Firestore Database에서 실시간 모니터링:
- 문서 수
- 읽기/쓰기 작업 수
- 네트워크 사용량
- 인덱스 사용량

## 참고

- Firestore 무료 할당량: 읽기 50k/일, 쓰기 20k/일, 삭제 20k/일
- 현재 앱 사용 패턴: 일일 ~100회 읽기/쓰기 예상
- 무료 할당량 내에서 충분히 운영 가능

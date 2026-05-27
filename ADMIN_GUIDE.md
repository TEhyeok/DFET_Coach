# D-FET 관리자 대시보드 가이드

## 개요

D-FET 관리자 대시보드는 앱 사용자 데이터를 관리하고 모니터링할 수 있는 웹 기반 관리 도구입니다.

## 주요 기능

### 1. **개요 대시보드**
- 총 사용자 수
- 관리자 수
- 활성 사용자 통계
- 최근 가입 사용자 목록

### 2. **사용자 관리**
- 전체 사용자 목록 조회
- 사용자 검색 (이메일/이름)
- 사용자 상세 정보 조회
  - 계정 정보
  - 최근 식사 기록
  - 최근 운동 기록
- 사용자 데이터 삭제

### 3. **관리자 설정**
- 관리자 권한 부여
- 관리자 권한 제거
- 관리자 목록 조회

## 설정 및 배포

### 1. Firebase Web App 설정

Firebase Console에서 Web 앱을 추가해야 합니다.

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. `dfetmanage` 프로젝트 선택
3. 프로젝트 설정 > 일반 > 내 앱
4. "웹 앱 추가" 클릭
5. 앱 닉네임 입력: "Admin Dashboard"
6. Firebase Hosting 설정 체크
7. 앱 등록

설정 값을 복사한 후, `web/admin.html` 파일의 다음 부분을 업데이트하세요:

```javascript
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "dfetmanage.firebaseapp.com",
    projectId: "dfetmanage",
    storageBucket: "dfetmanage.firebasestorage.app",
    messagingSenderId: "1011088994661",
    appId: "YOUR_APP_ID"
};
```

### 2. Firebase Functions 배포

```bash
# dfet_coach 디렉토리로 이동
cd dfet_coach

# Functions 배포
firebase deploy --only functions
```

배포된 Functions:
- `setAdminClaim` - 관리자 권한 부여
- `removeAdminClaim` - 관리자 권한 제거
- `listAllUsers` - 모든 사용자 조회
- `getUserDetails` - 사용자 상세 정보 조회
- `deleteUserData` - 사용자 데이터 삭제

### 3. Firestore 보안 규칙 배포

```bash
firebase deploy --only firestore:rules
```

업데이트된 보안 규칙은 관리자가 모든 사용자 데이터를 읽을 수 있도록 설정되어 있습니다.

### 4. 관리자 대시보드 배포

#### 방법 1: Firebase Hosting 사용

```bash
# 프로젝트 빌드 (관리자 페이지는 이미 web 디렉토리에 있음)
# admin.html을 hosting 디렉토리로 복사
cp web/admin.html build/web/admin.html

# Hosting 배포
firebase deploy --only hosting
```

배포 후 접속 URL: `https://dfetmanage.web.app/admin.html`

#### 방법 2: 로컬 테스트

```bash
# Firebase Emulator 시작
firebase emulators:start

# 브라우저에서 접속
# http://localhost:5000/admin.html
```

## 초기 관리자 설정

첫 관리자를 설정하는 방법:

### 방법 1: Functions 코드에 Super Admin 이메일 추가 (권장)

`functions/index.js` 파일의 `setAdminClaim` 함수에서 다음 부분을 수정:

```javascript
const SUPER_ADMIN_EMAILS = [
    'your-email@example.com'  // 여기에 본인의 이메일 추가
];
```

그 다음 Functions를 다시 배포:

```bash
firebase deploy --only functions
```

이제 해당 이메일로 로그인한 후, 관리자 대시보드에서 다른 사용자에게 관리자 권한을 부여할 수 있습니다.

### 방법 2: Firebase CLI로 직접 Custom Claim 설정

```bash
# Firebase CLI로 로그인
firebase login

# 관리자 권한 부여 (UID 필요)
firebase auth:export users.json
# users.json에서 본인의 UID 확인 후:

# Functions Emulator를 통해 실행하거나
# Firebase Console > Functions에서 직접 실행
```

### 방법 3: Firebase Console에서 수동 설정

Firebase Console의 Authentication에서 사용자 UID를 확인한 후, Firestore에 직접 추가:

1. Firebase Console > Firestore Database
2. `admins` 컬렉션 생성 (없는 경우)
3. 문서 추가:
   - 문서 ID: 본인의 UID
   - 필드:
     - `email`: 본인 이메일
     - `grantedAt`: 타임스탬프

그 다음 Firebase Console > Authentication > 사용자 선택 > "커스텀 클레임 설정":
```json
{"admin": true}
```

## 사용 방법

### 1. 로그인
1. 관리자 대시보드 URL 접속
2. "Google로 로그인" 클릭
3. 관리자 권한이 있는 계정으로 로그인

### 2. 사용자 조회
1. "사용자 관리" 탭 클릭
2. 검색창에 이메일 또는 이름 입력
3. "검색" 버튼 클릭
4. 사용자 목록에서 "상세" 버튼 클릭하여 상세 정보 확인

### 3. 관리자 권한 부여
1. "관리자 설정" 탭 클릭
2. 관리자로 지정할 이메일 입력
3. "권한 부여" 버튼 클릭
4. 해당 사용자가 다음 로그인 시 관리자 권한 활성화

### 4. 사용자 삭제
1. 사용자 상세 정보 모달에서 "사용자 삭제" 버튼 클릭
2. 확인 대화상자에서 확인
3. 사용자 Auth 계정 및 모든 Firestore 데이터 영구 삭제

## 보안 고려사항

### Custom Claims
- 관리자 권한은 Firebase Authentication의 Custom Claims로 관리됩니다
- 토큰은 1시간마다 자동 갱신됩니다
- 권한 변경 후 사용자는 재로그인이 필요할 수 있습니다

### Firestore 보안 규칙
- 일반 사용자는 본인 데이터만 읽기/쓰기 가능
- 관리자는 모든 사용자 데이터 읽기 가능
- 관리자는 특정 데이터 삭제 가능

### Functions 보안
- 모든 관리자 Functions는 인증 필요
- 관리자 권한 확인 후 실행
- 에러 로그는 Firebase Console에서 확인 가능

## 문제 해결

### "관리자 권한이 없습니다" 오류
- 본인의 계정에 관리자 Custom Claim이 설정되어 있는지 확인
- 재로그인 시도 (토큰 갱신)
- Firebase Console > Authentication에서 Custom Claims 확인

### Functions 호출 실패
- Firebase Functions가 정상 배포되었는지 확인: `firebase deploy --only functions`
- Functions 로그 확인: `firebase functions:log`
- Firebase Console > Functions에서 함수 실행 상태 확인

### 사용자 목록이 로드되지 않음
- Firebase Console > Functions에서 `listAllUsers` 함수 로그 확인
- 브라우저 개발자 도구에서 네트워크 오류 확인
- Firestore 보안 규칙이 정상 배포되었는지 확인

## 향후 개선 사항

- [ ] 사용자 데이터 내보내기 (CSV/JSON)
- [ ] 통계 차트 시각화 (Chart.js 등)
- [ ] 사용자 활동 로그 조회
- [ ] 푸시 알림 발송 기능
- [ ] 사용자 그룹 관리
- [ ] 다국어 지원

## 지원

문제가 발생하거나 기능 개선 제안이 있으시면 개발팀에 문의하세요.

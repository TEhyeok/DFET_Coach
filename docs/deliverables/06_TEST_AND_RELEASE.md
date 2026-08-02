# 테스트·출시·롤백 명세

## 자동 검증 명령

```bash
flutter analyze
flutter test
npm --prefix functions run lint
npm --prefix functions test
firebase emulators:exec --only firestore,storage --project dfet-rules-test \
  "npm --prefix functions run test:rules"
npm --prefix admin_web run lint
npm --prefix admin_web run typecheck
npm --prefix admin_web test
npm --prefix admin_web run build
flutter build apk --debug
flutter build ios --no-codesign
tool/ios_simulator.sh build
```

## 테스트 매트릭스

| 계층 | 필수 시나리오 |
|---|---|
| Functions 단위 | envelope, 날짜 순서, 13종 변환, 미지원 단위, band 경계, 정책 버전, 누락축, HMAC, idempotency 충돌 |
| Rules | 본인/타회원/담당/비담당/lab/admin, 전문가본, 서버 전용 쓰기, 프로필 승격 차단, Storage |
| Flutter 모델 | unscored, 부분 혈액, 누락축, 날짜 파싱 |
| Flutter 위젯 | 320/390/430px, text scale 1.0/1.3/2.0, light/dark, overflow 없음 |
| 관리자 계약 | 관리자 envelope가 Functions validator와 일치, HMAC 형식 일치 |
| E2E staging | 케어유형→가입→재로그인, API/CSV→리포트, 2회 혈액→추이, 검사→snapshot, expert 차단 |

테스트 데이터는 합성 데이터만 사용한다. Golden은 실제 `matchesGoldenFile` 비교와 `FlutterError` 수집을 적용하고 변경 시 사람의 시각 검토 후에만 갱신한다.

## 환경 승격

1. 로컬 Emulator: Functions·Firestore·Storage 계약/권한
2. 별도 staging Firebase: 검사기관 샌드박스, App Hosting preview, UAT
3. production: 승인 정책·보존 동의·비밀키·모니터링 확인 후 배포

staging과 production은 서로 다른 Firebase 프로젝트, Storage bucket, HMAC key set, App Hosting backend를 사용한다. `.env`와 서비스 계정은 저장소에 커밋하지 않는다.

## 출시 순서

1. 모바일/관리자 배포, 모든 임상 플래그 false
2. `gut=true` 제한 그룹 활성화
3. 지표 안정 후 `blood=true`
4. 승인 통합 정책과 최소 데이터 확인 후 `insights=true`

## 롤백 기준

| 조건 | 즉시 조치 | 복구 |
|---|---|---|
| 비인가 데이터 노출 | 관련 플래그 off, 세션 폐기 | Rules/API 수정·감사검토 |
| 단위/정책 오류 | blood/insights off, 활성 정책 비활성 | 새 버전 게시, 기존 보고서 보존 |
| 수집 오류율 급증 | 해당 키 비활성, 업로드 중단 | job 재처리 전 원인 확인 |
| 모바일 crash/overflow | 영향 플래그 off | 수정 빌드·회귀 테스트 |

승인된 정책 문서는 수정하지 않는다. 롤백은 이전 승인 버전 활성화 또는 기능 플래그 비활성으로 수행해 과거 보고서의 재현성을 보존한다.

## production 출시 게이트

- 기관 승인 정상범위·가중치·생활가이드
- 실제 건강데이터 동의·보존·삭제 정책
- HMAC key rotation/폐기 절차
- App Check와 Auth 공급자 production 설정
- 장애 알림·감사로그 검토 담당자
- iOS/Android 서명, 개인정보 고지, 스토어 심사

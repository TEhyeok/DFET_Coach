# API·JSON 인터페이스

## 엔드포인트

- `POST /v1/ingestions/gut`
- `POST /v1/ingestions/blood`

Functions 직접 URL 또는 Hosting rewrite를 사용한다. Content-Type은 `application/json`이다.

## 인증 서명

| 헤더 | 값 |
|---|---|
| `x-dfet-key-id` | 발급된 키 ID |
| `x-dfet-timestamp` | Unix seconds/milliseconds 또는 ISO 시각 |
| `x-dfet-signature` | lowercase/uppercase hex SHA-256 HMAC |

서명 대상은 `timestamp + "." + raw HTTP body bytes`이다. 서버 허용 시계 오차는 ±5분이다. JSON을 파싱 후 다시 직렬화한 문자열이 아니라 실제 전송 바이트로 서명해야 한다.

```text
signature = hex(HMAC_SHA256(secret, timestamp + "." + rawBody))
```

## 공통 envelope

```json
{
  "schemaVersion": "1.0",
  "source": "partner-lab",
  "externalReportId": "LAB-2026-0001",
  "revision": 1,
  "memberRef": { "type": "externalId", "value": "MEMBER-100" },
  "sampledAt": "2026-08-01T01:00:00.000Z",
  "reportedAt": "2026-08-02T01:00:00.000Z",
  "payload": {},
  "kit": { "udi": "UDI-001", "lot": "LOT-001", "expiresAt": "2027-01-01" },
  "idempotencyKey": "partner-lab:LAB-2026-0001:r1"
}
```

`memberRef` 문자열은 Firebase UID로 해석한다. 외부 ID는 관리자가 `memberAliases`에 먼저 매핑해야 한다. `reportedAt`은 `sampledAt`보다 빠를 수 없다.

## 응답

| HTTP | 의미 |
|---:|---|
| 200 | 완료 또는 동일 요청의 완료 결과 |
| 202 | 같은 idempotency 요청이 처리 중 |
| 400 | JSON/요청 형식 오류 |
| 401 | 키·서명·타임스탬프 오류 |
| 404 | 엔드포인트 없음 |
| 409 | 같은 idempotency key에 다른 본문 또는 같은 외부 리포트 revision의 재정의 |
| 413 | 원문 본문이 10 MiB를 초과 |
| 422 | envelope, 검사값, 단위, 회원 별칭 검증 오류 |
| 500 | 내부 처리 실패 |

성공 예:

```json
{
  "data": {
    "jobId": "…",
    "reportId": "…",
    "snapshotId": "…",
    "status": "completed",
    "duplicate": false
  }
}
```

오류 예:

```json
{
  "error": {
    "code": "invalid_payload",
    "message": "Clinical ingestion payload is invalid",
    "details": ["payload.biomarkers[0].unit must be a non-empty string"]
  }
}
```

## Schema와 CSV

- `/schemas/ingestion-envelope.schema.json`
- `/schemas/gut-ingestion.schema.json`
- `/schemas/blood-ingestion.schema.json`

혈액 CSV 열: `code,value,unit`.
장 CSV 열: `section,name,value,pc1,pc2,label,group,isSubject`. `section`은 `alpha`, `pcoa`, `explainedVariance`, `phylum`, `genus`, `unifrac`, `metadata` 중 하나다.

관리자 JSON/CSV는 Next.js가 `source=admin_json|admin_csv` envelope로 만들고 동일 Functions 처리기를 호출한다.

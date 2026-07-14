# GA4 파이프라인 작업 전 주의사항

> 작성일: 2026-07-02 · 대상: Bronze_GA4 → Silver GA4 파이프라인 개발자

> **[2026-07-10 실적재 검증 — 후속 정정]**
> - 🟥 **샤드 테이블명 대소문자 버그**: 실적재 샤드가 **소문자** `events_20260501` → §1 동적조회의 `LIKE 'EVENTS_%'`·`REPLACE(...,'EVENTS_','')`(대문자)는 **0건 매칭**. `ILIKE`/`UPPER(table_name)`로 수정하고 UNION의 `FROM` 식별자도 소문자라 따옴표 필요. (dbt 버전 짝 문서와 동일 이슈.)
> - **샤드 1일만 적재**(`events_20260501` 287,025행) — §5 "전체 기간 적재 완료" 미충족.
> - 🟥 **`user_id` 채움률 4.2%** → §4-⑤ GA4_IDENTITY 활성 시 커버리지 DQ 필요.

---

## 1. Bronze 구조 — date-shard 고정

- `BRONZE_GA4.EVENTS_YYYYMMDD` 형식으로 날짜별 테이블 생성 (개발환경 제약)
- **trial dbt deps 불가** → **동적 스크립트 기반 Stored Procedure**로 대체
- 테이블 목록은 하드코딩 금지 — `INFORMATION_SCHEMA.TABLES`에서 동적 조회

```sql
-- 처리 대상 테이블 자동 발견
SELECT table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE_GA4'
  AND table_name LIKE 'EVENTS_%'
  AND REPLACE(table_name, 'EVENTS_', '') BETWEEN :START_DATE AND :END_DATE
ORDER BY table_name;
```

---

## 2. 증분 전략 — GA4 72시간 보정 필수

GA4는 이벤트 발생 후 **최대 72시간(D+3)** 이내에 데이터가 소급 수정된다.
단순 어제 날짜 INSERT는 오래된 값이 Silver에 잔존하는 오류를 유발한다.

**올바른 처리 흐름:**
```
1. Silver에서 event_date >= TODAY()-3 행 삭제
2. Bronze D-3~D-1 테이블 동적 발견
3. UNION ALL 조립 → EXECUTE IMMEDIATE → Silver INSERT
```

**TASK 스케줄 권장:**
```sql
CALL SP_REFINE_GA4(
    TO_VARCHAR(CURRENT_DATE - 3, 'YYYYMMDD'),  -- D-3
    TO_VARCHAR(CURRENT_DATE - 1, 'YYYYMMDD')   -- 어제
);
```

---

## 3. 동적 SQL 주의사항

| 항목 | 내용 |
|------|------|
| **디버깅** | `EXECUTE IMMEDIATE` 에러는 원인 파악이 어려움 → 실행 전 `v_sql`을 로그 테이블에 기록 권장 |
| **UNION ALL 범위** | 날짜 범위를 최대 30일로 제한 권장 — 이상 시 성능 저하 |
| **컬럼 불일치** | 스키마 변경으로 날짜별 컬럼이 다를 수 있음 → VARIANT 컬럼(event_params 등)은 흡수되나 스칼라 컬럼 추가 시 `ALTER TABLE ADD COLUMN` 선행 필요 |
| **VARCHAR 필수** | `USER_ID`(회원번호)는 선행0·S접두 보존 — **NUMBER 캐스팅 절대 금지** |

---

## 4. 처리 대상 Silver 테이블 (4개 · 순서 준수)

```
① GA4_TRAFFIC_SOURCE   ← session_traffic_source_last_click 추출
② GA4_EVENT_DIM        ← event_params FLATTEN → category/label/action DISTINCT
③ GA4_DEVICE           ← device OBJECT + platform → PC/M/APP 파생
④ GA4_EVENT            ← 전체 FLATTEN (메인 팩트 소스 — 가장 무거움)
⑤ GA4_IDENTITY         ← user_id 접두사 분기 (Q1 행매칭 실증 후 활성화)
```

---

## 5. 착수 전 선결 확인

- [ ] Bronze 전체 기간 날짜별 CSV 적재 완료 여부
- [ ] `BRONZE_GA4.GA4_CSV_FMT` 파일 포맷 존재 확인
- [ ] Silver 테이블 26개 DDL 생성 완료 확인 (`SILVER_DDL_20260702.sql`)
- [ ] GA4_IDENTITY는 Q1 행매칭 실증 전까지 TASK 체인에서 **제외**

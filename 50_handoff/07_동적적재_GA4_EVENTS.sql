-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   GN_DW.BRONZE_BIGQUERY 의 GA4 events 를 **단일 통합 테이블 EVENTS 1개**에
--   동적 생성 COPY(프로시저)로 적재한다.
--   06번 문서의 A.5(GA4 개별 COPY) 를 대체한다. — 테이블 수가 늘어도 이 문서는 늘어나지 않는다.
--
-- 실행 계정 / 역할
--   C (Target), ACCOUNTADMIN, WH=COMPUTE_WH
--   4장만 **A 계정**에서 실행한다. 그 외 전부 C 계정이다.
--   실행 직전에 `SELECT CURRENT_ACCOUNT();` 로 계정을 확인한다.
--
-- 연계 문서 / RELATED DOCUMENTS
--   [상위 절차] 50_handoff/06_데이터마이그 C_CONSUMER.sql
--              → A.1(스테이지 검증) / A.2(파일포맷 FF_CSV_LOAD) 는 그 문서를 그대로 쓴다.
--              → A.5(GA4 개별 COPY) 는 **본 문서로 대체**한다.
--   [선행 필수] 06번 A.2 — 본 문서는 FF_CSV_LOAD 를 그대로 재사용한다(2장 참조).
--   [선행 필수] 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql
--              → BRONZE_BIGQUERY 스키마 · 시퀀스 · SYNC_ERR_INFO 생성 목적으로만 필요하다.
--   [불필요]   99_provided_definition/15_bronze_ga4_ddl.sql  (20,527행 · events 676개)
--              → 🔴 **실행하지 않는다.** 3장 EVENTS 1개가 대체한다. 더구나 이 문서는
--                 원천 911개 중 676개(~20251107)만 담고 있어 235개가 누락돼 있다. 0장 (1).
--   [정본]     99_provided_definition/14_bronze_ga4_events_schema.md (컬럼 코멘트 출처)
--   [갱신필요] 50_handoff/01_데이터마이그레이션 20260730.md §대조표
--              → 🔴 BRONZE_BIGQUERY 기준선 '3테이블 / 576,441행' 이 무효가 된다. 0장 (5) 참조.
--
-- 개정 이력
--   2026-08-18 1판 — 최초 작성
--   2026-08-18 2판 — 아키텍처 검토 반영. 아래 7건은 1판의 **결함 수정**이므로 1판을 쓰지 말 것.
--     ① TRY_PARSE_JSON → PARSE_JSON (엄격). 1판은 깨진 JSON 을 조용히 NULL 로 만들었다
--     ② 8장 판정식 LIKE → STARTSWITH. 1판은 '_' 와일드카드 때문에 불일치를 통과시켰다
--     ③ FF_CSV_GA4 폐기 → FF_CSV_LOAD 재사용. 1판의 인과 설명이 거짓이었다(0장 (3)ⓑ)
--     ④ PATTERN 매칭 기준 정정 — FROM 경로 **상대** 경로다. 1판은 '스테이지 루트 기준'이라 썼다
--     ⑤ 감사 컬럼 SRC_FILE_NAME / LOAD_TS 추가. 1판은 중복 적재를 검출할 수단이 없었다
--     ⑥ 통제총계(A 실측 행수) 대조 절차 신설(4장/7장). 1판은 완료를 증명할 수 없었다
--     ⑦ 복구 경로 CREATE OR REPLACE ... LIKE → TRUNCATE. 1판은 테이블 코멘트를 소실시켰다
--
-- ▣▣ 적재 상태 : ✅ **완료 (2026-08-18)** ▣▣
--     GN_DW.BRONZE_BIGQUERY.EVENTS = 285,676,588행 / 911일(2024-01-01~2026-07-19) / 6,517파일
--     통제총계 대조(7장 (2)) = 911테이블 전수 일치, **불일치 0건** · 중복 파일 0건 · errors 0
--     남은 작업 = 01번 문서 §대조표의 BRONZE_BIGQUERY 행 갱신(0장 (5)) → 그 후 SILVER 착수
--
-- 🔴🔴🔴 최우선 경고 — 04번 DDL 을 **다시 실행하지 마라** 🔴🔴🔴
--     04번은 `create or replace schema GN_DW.BRONZE_BIGQUERY` 를 한다 ⇒ **EVENTS 전량 삭제.**
--     2026-08-18 실제로 이 사고가 났고 UNDROP 으로 복구했다(Time Travel 1일 · 상세는 9장 A-2).
--     같은 위험이 BRONZE_CRM · BRONZE_AGENCY · BRONZE_ERP · ML 에도 있다.
--     ⇒ 적재 완료 후 04번을 돌려야 하면 **반드시 9장 A-2 의 '올바른 순서' 를 먼저 읽어라.**
--
-- =====================================================================
-- 0장. 왜 기존 방식(테이블당 COPY 1개)을 쓸 수 없는가 — 2026-08-18 실측
-- =====================================================================
--   (1) 규모 — 2026-08-18 A 계정 실측으로 확정
--       A 실측 = **911 테이블 / 285,676,588 행 / 48,362,186,752 B**
--                events_20240101 ~ events_20260719 (일별, 결번 없음)
--       스테이지 = 911 폴더 / 6,517 파일 / 63,725,277,056 B (GZIP CSV)
--       → 06번 A.5 방식(테이블당 COPY 1개 + VARIANT 위치 수동 나열)이면 SQL 이 911블록이 된다.
--         작성·검토·유지 모두 불가능하다.
--       🔴 15_bronze_ga4_ddl.sql (20,527행 · CREATE TABLE 677개 = SYNC_ERR_INFO 1 + events 676)
--          은 **원천의 일부만 담고 있다.** 수록 범위가 events_20240101~20251107 이어서
--          실제 911개 중 **235개가 빠져 있다.** 그 문서를 실행해 일별 테이블을 만들었다면
--          2025-11-08 이후 전 구간이 조용히 누락됐을 것이다.
--          ⇒ 15번 DDL 을 쓰지 않는 결정이 규모 문제만이 아니라 **정확성 문제**이기도 하다.
--
--   (2) 스키마가 변한다 (일별 테이블 구조가 동일하지 않다)
--       15번 DDL 문서 기준 = 5종. 단 그 문서는 20251107 까지만 담고 있다(위 (1)).
--       ┌ 컬럼수 ┬ 구간 ────────────────────────┬ 추가된 컬럼 ─────────────────────────┐
--       │  25   │ events_20240101 ~ 20240717   │ (기준)                               │
--       │  28   │ events_20240718 ~ 20240725   │ +batch_event_index/page_id/ordering_id│
--       │  29   │ events_20240726 ~ 20241010   │ +session_traffic_source_last_click    │
--       │  30   │ events_20241011 ~            │ +publisher                            │
--       │  31   │ 2026년 구간                   │ +event_original_occurrence_timestamp  │
--       └───────┴──────────────────────────────┴───────────────────────────────────────┘
--       🟢 결정적 성질 — 변화가 **전부 꼬리 추가(additive prefix)** 다.
--          25 ⊂ 28 ⊂ 29 ⊂ 30 ⊂ 31. 앞쪽 컬럼의 순서·이름이 바뀐 적이 한 번도 없다.
--          실측: 폴더별 CSV 헤더의 DISTINCT 값이 모든 구간에서 정확히 1 (혼재 0건).
--       ✅ 전량 적재 후 사후 확증 (7장 (4) 실측) — 위 경계가 데이터에서 그대로 재현됐다:
--            batch_event_index                  최초 비-NULL = events_20240719
--            session_traffic_source_last_click  최초 비-NULL = **events_20250426**
--          🟢 후자는 15번 DDL 에서 독립적으로 도출한 VARIANT 구간 시작일과 **정확히 일치**한다.
--             컬럼이 한 칸이라도 밀렸다면 이 경계가 어긋난다. ⇒ 911폴더 전체의 위치 정렬 확증.
--       ⚠️ 단 하나의 예외 = 29번째 session_traffic_source_last_click 의 **타입**이 바뀐다.
--          15번 DDL 기준 events_20241011~20251028 구간은 NUMBER(전부 NULL),
--          events_20250426~20251107 구간은 VARIANT. 두 구간의 날짜가 겹쳐 있어
--          **날짜로는 판별할 수 없다.** → 통합 테이블에서 VARIANT 로 통일해 해소한다(3장).
--       ✅ 원천 언로드가 **전 구간 NULL** 인 컬럼 (7장 (4) 실측, 285,676,588행 전수):
--            app_info · event_dimensions · publisher · event_original_occurrence_timestamp
--          🔴 1판은 event_original_occurrence_timestamp 를 '2026년 구간만 값 존재' 라고 썼다.
--             틀렸다. 2026-07 원천 CSV 헤더가 31컬럼이고 31번째가 이 컬럼임을 확인했으나
--             (즉 컬럼은 실재한다) 값은 전 구간 0건이다. NUMBER 로 언로드된 BigQuery
--             STRUCT 컬럼 4개가 모두 같은 상태다.
--
--   (3) 위 (2) 덕분에 성립하는 것 — 실측 검증 완료
--       ⓐ 컬럼 수가 부족한 파일에서 초과 위치를 참조하면 **오류가 아니라 NULL** 이다.
--          검증: events_20240101(25컬럼) 파일에서 $26, $31 → 둘 다 NULL. $25 → 'true' 정상.
--       ⓑ 컬럼 수가 다른 파일을 **한 COPY 문장에 섞어도 된다.**
--          검증: events_20240101(25컬럼, 14,495행) + events_20250308(30컬럼, 4,103행)
--                을 COPY 1문장으로 적재 → 둘 다 LOADED · errors_seen=0 · 거부행 0.
--          🔴 1판 정정 — 1판은 이것을 `ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE` 덕분이라고
--             설명했다. **거짓이다.** 같은 적재를 이 옵션이 TRUE 인 포맷으로 실행해도
--             LOADED / errors_seen=0 이었다. 변환 COPY(`FROM (SELECT ...)`)는 이 옵션을
--             **아예 적용하지 않는다.** 성립 근거는 순전히 ⓐ(초과 위치 = NULL)다.
--             ⇒ 따라서 이 옵션을 TRUE 로 두어도 컬럼수 드리프트를 막아주지 못한다.
--                실제 방어선은 **8장 하나뿐**이다. 8장을 건너뛰지 말 것.
--       ⇒ 그래서 **31컬럼 상위집합(superset) 테이블 1개**로 전 기간을 적재할 수 있다.
--
--   (4) 실전 실측 — **전량 적재 완료 (2026-08-18, COMPUTE_WH = X-Small)**
--       ┌ 단계 ─────────────────────────────┬ files ┬ rows ────────┬ 비고 ───────────────┐
--       │ 스모크 202503 1회차                │  177 │   8,396,742 │ errors=0            │
--       │ 스모크 202503 2회차(재실행)        │    2 │     139,264 │ 1회차 이후 도착분   │
--       │ 전량 CALL(NULL,NULL,FALSE)        │ 6,338│ 277,140,582 │ months=31, errors=0 │
--       │ **누계**                          │ 6,517│ **285,676,588** │ = A 실측과 완전일치 │
--       └───────────────────────────────────┴──────┴─────────────┴─────────────────────┘
--       🟢 엄격 PARSE_JSON 이 6,517파일 2.86억행에서 오류 0건 → 원천 JSON 이 깨끗하다.
--          조용한 NULL 을 감수할 이유가 없으므로 TRY_ 를 쓰지 않는다(①).
--       🟢 통제총계 대조(7장 (2)) — 911테이블 전수 행수 일치, 불일치 **0건**. 중복 파일 0건.
--       🔴 위 '2회차' 가 이 문서의 가장 중요한 경고다 —
--          **업로드가 진행 중인 상태에서 1회만 적재하면 조용히 누락된다.**
--          COPY 는 그 시점에 존재하는 파일만 처리하고 status=LOADED, errors=0 을 반환한다.
--          검출 수단은 7장 (2) 통제총계 대조뿐이다. 폴더 존재 확인만으로는 잡히지 않는다.
--
--   (5) 🔴 규모가 500배다 — 프로젝트 대조표를 갱신해야 한다
--       01번 문서 기준선 : A 원천 BRONZE_BIGQUERY = 3테이블 /     576,441행 (2026-08-12)
--       실제 확정        : A 원천 events_*        = 911테이블 / **285,676,588행** (2026-08-18)
--       C 적재 결과      : EVENTS **1테이블** = 285,676,588행 (+ SYNC_ERR_INFO, 빈 테이블 2개)
--       배수            : 약 **496배**
--       비교            : BRONZE_CRM 45테이블 합계 = 1.16억 행 → EVENTS 가 그 2.5배다
--       ⇒ EVENTS 한 테이블이 나머지 웨어하우스 전체의 2배가 넘는다.
--         · 01번 §대조표의 BRONZE_BIGQUERY 행을 위 값으로 대체한다.
--         · 06번 A.6 의 기대값 '3테이블 576,441행' 은 무효다.
--         · 🔴 SILVER/SV 설계에서 EVENTS 를 항상 EVENT_DT 로 제한해 읽도록 강제해야 한다.
--           2.86억행 × VARIANT 11개를 무제한 스캔하면 비용이 즉시 문제가 된다.
--         · ✅ 클러스터링은 불필요로 확정됐다(7장 (6) 프루닝 실측: 3,006 중 19 파티션).

-- =====================================================================


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA SANDBOX.TOOLS;

-- 월 단위 COPY 1건의 상한을 6시간으로 **제한**한다(기본값 172,800초=48시간을 낮추는 것이다).
-- 목적은 타임아웃 방지가 아니라, 비정상적으로 오래 걸리는 COPY 를 방치하지 않는 것이다.
-- 실측이 월당 수십 초 수준이므로 6시간은 충분히 여유롭다.
ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 21600;


------------------------------------------------------------
-- 1장. 선행 확인 + 디렉터리 테이블 활성화
--   🔴 디렉터리 테이블은 **필수**다. 5장 프로시저가 처리 대상 연월을 여기서 읽는다.
--      이유 — `LIST` 는 저장 프로시저 안에서 실행할 수 없다(실측:
--      "Unsupported statement type 'LIST_FILES'"). DIRECTORY() 는 일반 테이블처럼
--      조회되므로 프로시저 안에서 쓸 수 있고, 데이터 파일을 읽지 않아 비용이 거의 없다.
--   🟢 REFRESH 는 5장 프로시저가 매 호출 첫머리에서 자동 실행한다(실측: 프로시저 내부
--      EXECUTE IMMEDIATE 'ALTER STAGE ... REFRESH' 는 허용된다).
------------------------------------------------------------
SELECT CURRENT_ACCOUNT() AS acct, CURRENT_ROLE() AS role, CURRENT_WAREHOUSE() AS wh;

ALTER STAGE SANDBOX.TOOLS.MIG_LOAD_STAGE SET DIRECTORY = (ENABLE = TRUE);
ALTER STAGE SANDBOX.TOOLS.MIG_LOAD_STAGE REFRESH;
-- REFRESH 결과는 파일당 1행(REGISTERED_NEW 등)이 나온다. 첫 실행은 전량 등록이므로 행이 많다.

-- 스테이지 GA4 현황 (디렉터리 테이블 = 데이터 미스캔)
SELECT COUNT(DISTINCT REGEXP_SUBSTR(RELATIVE_PATH,'events_[0-9]{8}')) AS folders,
       COUNT(*)                                                       AS files,
       TO_VARCHAR(SUM(SIZE))                                          AS bytes,
       MIN(REGEXP_SUBSTR(RELATIVE_PATH,'events_[0-9]{8}'))            AS min_folder,
       MAX(REGEXP_SUBSTR(RELATIVE_PATH,'events_[0-9]{8}'))            AS max_folder
FROM DIRECTORY(@SANDBOX.TOOLS.MIG_LOAD_STAGE)
WHERE RELATIVE_PATH RLIKE 'BRONZE_BIGQUERY/events_[0-9]{8}/.*';
-- 2026-08-18 실측 추이(업로드가 진행 중이었다) — 값이 계속 늘어났다:
--   04:05 시점 = 432폴더 / 2,216파일 / 16,910,429,920 B / ~events_20250309
--   02:20 시점 = 462폴더 / 2,377파일 / 18,125,502,848 B / ~events_20250408
--   ✅ 업로드 완료 = **911폴더 / 6,517파일 / 63,725,277,056 B / ~events_20260719**
-- 🔴 업로드 완료 전에는 적재를 '완료'로 판정하지 말 것. 0장 (4) 2회차 경고 참조.
--    완료 판정의 유일한 근거는 7장 (2) 통제총계 대조다.


------------------------------------------------------------
-- 2장. 파일 포맷 — 06번 A.2 의 FF_CSV_LOAD 를 **그대로 재사용**한다
--   🔴 1판은 GA4 전용 FF_CSV_GA4 를 별도로 만들었다. 폐기한다. 이유:
--      두 포맷의 차이는 ERROR_ON_COLUMN_COUNT_MISMATCH 하나뿐인데(SHOW FILE FORMATS 대조),
--      그 옵션은 변환 COPY 에서 무효다(0장 (3)ⓑ). 즉 차별점이 아무 일도 하지 않는
--      객체를 하나 더 유지하면서, 운영자에게 "이 옵션이 안전장치다" 라는 오해를 준다.
--   ⇒ 06번 A.2 를 먼저 실행해 FF_CSV_LOAD 가 존재해야 한다. 아래로 확인만 한다.
------------------------------------------------------------
SHOW FILE FORMATS LIKE 'FF_CSV_LOAD' IN SCHEMA SANDBOX.TOOLS;
-- 0건이면 06번 A.2 를 먼저 실행한다.

-- 1판 잔존 객체 정리
DROP FILE FORMAT IF EXISTS SANDBOX.TOOLS.FF_CSV_GA4;


------------------------------------------------------------
-- 3장. 통합 테이블 DDL — 676개 일별 테이블을 대체하는 1개
--   · 1~31번 = events_20260719(31컬럼 최신본) 구조 무변경 채용. 컬럼명·순서·타입·코멘트 동일.
--     ⇒ 위치 기반 적재가 성립한다(0장 (2) additive prefix).
--   · 29번 session_traffic_source_last_click 은 **VARIANT 로 고정**한다.
--     0장 (2) 예외 해소 — NUMBER 구간은 원천이 전부 NULL 이므로 손실이 없다.
--   · 32~35번 = 계보/조회/감사 키. CSV 에 없고 METADATA$* 에서 파생한다.
--       SRC_TABLE     원본 일별 테이블명(= 스테이지 폴더명). 7장 (2) 대조 키
--       EVENT_DT      DATE. 모든 조회의 파티션 키
--       SRC_FILE_NAME 파일 단위 계보. **중복 적재 검출의 유일한 수단**(7장 (3))
--       LOAD_TS       적재 배치 식별. 업무일자(EVENT_DT)와 명확히 구분된다
--     🔴 1판에는 SRC_FILE_NAME / LOAD_TS 가 없었다. 그래서 5장이 스스로 경고한
--        '64일 후 중복 적재' 를 **검출조차 할 수 없었고** 처방이 전량 재적재뿐이었다.
--     · 메타데이터 4컬럼 전부 NOT NULL 이다. 파생이 실패하면 사후 검증이 아니라
--       **그 달의 COPY 가 즉시 중단**된다(fail-fast).
--     ⚠️ EVENT_DT 는 폴더명에서 파생한다. 1번 "event_date"(GA4 속성 시간대 기준)와
--        불일치하는 행이 있을 수 있다. 7장 (5) 에서 실측한다.
--
--   🟢 클러스터링 키는 두지 않는다 — 단, 0장 (5) 규모(약 1.86억행) 때문에 재검토 대상이다.
--      6장이 **월 단위로 순차 적재**하므로 마이크로파티션이 자연히 EVENT_DT 로 정렬된다.
--      7장 (6) 프루닝 실측 후 미달이면 CLUSTER BY (EVENT_DT) 를 검토한다.
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS GN_DW.BRONZE_BIGQUERY.EVENTS (
  "event_date"                          VARCHAR(16777216) COMMENT '이벤트가 기록된 날짜(YYYYMMDD, 속성 시간대 기준)',
  "event_timestamp"                     NUMBER(38,0)      COMMENT 'GA4 서버가 이벤트를 수신한 시각(UTC 마이크로초)',
  "event_name"                          VARCHAR(16777216) COMMENT '이벤트 이름(자동수집/커스텀 이벤트명)',
  "event_params"                        VARIANT           COMMENT '이벤트 파라미터 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)',
  "event_previous_timestamp"            NUMBER(38,0)      COMMENT '동일 기기 직전 이벤트 수신 시각(UTC 마이크로초)',
  "event_value_in_usd"                  FLOAT             COMMENT '이벤트 value 파라미터의 USD 환산값',
  "event_bundle_sequence_id"            NUMBER(38,0)      COMMENT '기기→서버 전송 배치(bundle) 요청 순번 ID',
  "event_server_timestamp_offset"       NUMBER(38,0)      COMMENT '기기 수집 시각과 서버 업로드 시각의 차이(마이크로초)',
  "user_id"                             VARCHAR(16777216) COMMENT '개발자가 설정한 사용자 고유 ID(로그인 사용자, CRM 연계 키)',
  "user_pseudo_id"                      VARCHAR(16777216) COMMENT 'GA4 자동 생성 익명 사용자 식별자',
  "privacy_info"                        VARIANT           COMMENT '동의모드 데이터 저장 동의 정보(RECORD → OBJECT)',
  "user_properties"                     VARIANT           COMMENT '사용자 속성 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)',
  "user_first_touch_timestamp"          NUMBER(38,0)      COMMENT '사용자 최초 앱실행/웹방문 시각(UTC 마이크로초)',
  "user_ltv"                            VARIANT           COMMENT '사용자 생애가치(LTV) 정보(RECORD → OBJECT)',
  "device"                              VARIANT           COMMENT '기기 정보(RECORD → OBJECT)',
  "geo"                                 VARIANT           COMMENT '지리 정보(IP 기반, RECORD → OBJECT)',
  "app_info"                            NUMBER(38,0)      COMMENT '앱 정보(RECORD → OBJECT) — 원천 언로드에서 전부 NULL',
  "traffic_source"                      VARIANT           COMMENT '최초 유입 트래픽 소스(First-touch, User-scoped, RECORD → OBJECT)',
  "stream_id"                           VARCHAR(16777216) COMMENT '이벤트가 수집된 GA4 데이터 스트림 고유 ID',
  "platform"                            VARCHAR(16777216) COMMENT '이벤트 발생 플랫폼(WEB/ANDROID/IOS)',
  "event_dimensions"                    NUMBER(38,0)      COMMENT '이벤트 차원 정보(hostname 등, RECORD → OBJECT) — 원천 언로드에서 전부 NULL',
  "ecommerce"                           VARIANT           COMMENT '전자상거래 정보(RECORD → OBJECT)',
  "items"                               VARIANT           COMMENT '상품 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)',
  "collected_traffic_source"            VARIANT           COMMENT '이벤트 시점 원시 UTM 트래픽 소스(Event-scoped, RECORD → OBJECT)',
  "is_active_user"                      BOOLEAN           COMMENT '해당 날짜 사용자 활성 여부(True=활성)',
  "batch_event_index"                   NUMBER(38,0)      COMMENT '동일 배치 내 이벤트 발생 순번. 최초 비-NULL = events_20240719(실측)',
  "batch_page_id"                       NUMBER(38,0)      COMMENT '세션 내 페이지뷰 순번. 최초 비-NULL = events_20240719(실측)',
  "batch_ordering_id"                   NUMBER(38,0)      COMMENT '페이지 내 네트워크 요청 단조 증가 순번. 최초 비-NULL = events_20240719(실측)',
  "session_traffic_source_last_click"   VARIANT           COMMENT '세션 마지막 클릭 트래픽 소스(Session-scoped, GA4 UI 일치, RECORD → OBJECT). 최초 비-NULL = events_20250426(실측). 그 이전 구간은 원천이 NUMBER 타입 전부 NULL',
  "publisher"                           NUMBER(38,0)      COMMENT '퍼블리셔 광고 수익 정보(RECORD → OBJECT) — 원천 언로드에서 전부 NULL',
  "event_original_occurrence_timestamp" NUMBER(38,0)      COMMENT '이벤트가 기기에서 실제 발생한 원본 시각(UTC 마이크로초). 2026년 헤더에 실재하나 원천 언로드에서 전 구간 NULL(실측 285,676,588행 전수 0건)',
  SRC_TABLE                             VARCHAR(64)   NOT NULL COMMENT '[계보] 원본 일별 테이블명 = 스테이지 폴더명(events_YYYYMMDD). 7장 (2) 통제총계 대조 키',
  EVENT_DT                              DATE          NOT NULL COMMENT '[조회] SRC_TABLE 에서 파생한 이벤트 일자. 모든 조회의 파티션 키',
  SRC_FILE_NAME                         VARCHAR(512)  NOT NULL COMMENT '[감사] 이 행이 나온 스테이지 파일 경로(METADATA$FILENAME). 파일 단위 계보·중복 검출 키',
  LOAD_TS                               TIMESTAMP_LTZ NOT NULL COMMENT '[감사] COPY 스캔 시각(METADATA$START_SCAN_TIME). 적재 배치 식별 — 업무일자 EVENT_DT 와 구분된다'
)
COMMENT = 'GA4 events 통합 테이블 — 원천 일별 911개 테이블(events_20240101~20260719, 285,676,588행)을 SRC_TABLE/EVENT_DT 로 통합. 31컬럼 상위집합(additive prefix) + 감사 4컬럼. 적재=SANDBOX.TOOLS.LOAD_GA4_EVENTS. 조회 시 반드시 EVENT_DT 로 범위 제한할 것';

-- 1판으로 이미 만들었다면 아래로 승격한다(1판 = 33컬럼, 2판 = 35컬럼).
-- ALTER TABLE GN_DW.BRONZE_BIGQUERY.EVENTS
--   ADD COLUMN SRC_FILE_NAME VARCHAR(512) COMMENT '[감사] ...',
--              LOAD_TS       TIMESTAMP_LTZ COMMENT '[감사] ...';
-- TRUNCATE TABLE GN_DW.BRONZE_BIGQUERY.EVENTS;   -- 기존 행에는 감사값이 없으므로 비운다
-- ALTER TABLE GN_DW.BRONZE_BIGQUERY.EVENTS
--   ALTER COLUMN SRC_TABLE SET NOT NULL, EVENT_DT SET NOT NULL,
--                SRC_FILE_NAME SET NOT NULL, LOAD_TS SET NOT NULL;

-- 🔴 재적재(전량 초기화)가 필요할 때 — **TRUNCATE 를 쓴다.**
--    실측 확인: TRUNCATE 는 COPY 적재 메타데이터도 초기화하므로 같은 파일이 다시 적재된다.
--    1판은 `CREATE OR REPLACE TABLE EVENTS LIKE EVENTS` 를 권했다. 쓰지 말 것 —
--    실측: 컬럼 코멘트는 보존되지만 **테이블 코멘트가 소실**되고,
--          GRANT·TAG·마스킹/행접근 정책도 승계되지 않는다.
-- TRUNCATE TABLE GN_DW.BRONZE_BIGQUERY.EVENTS;

------------------------------------------------------------
-- 3-B. 데이터 컬럼 목록의 단일 근거(single source of truth)
--   5장 프로시저와 8장 검사가 **같은 정의**를 봐야 한다.
--   1판은 제외 목록을 두 곳에 하드코딩해서, 감사 컬럼을 추가하면 두 곳을 동시에
--   고쳐야 했고 한쪽을 놓치면 위치가 밀렸다. 뷰 하나로 고정한다.
--   ⇒ GA4 가 32번째 데이터 컬럼을 추가하면 EVENTS 에 ALTER TABLE ADD COLUMN 만 하면 되고,
--     이 뷰도 프로시저도 고치지 않는다(꼬리 추가이므로 pos 가 자동으로 32가 된다).
------------------------------------------------------------
CREATE OR REPLACE VIEW SANDBOX.TOOLS.V_GA4_EVENTS_DATA_COLS
COMMENT = 'EVENTS 의 CSV 대응 데이터 컬럼만(메타데이터 4컬럼 제외) + CSV 위치 pos. LOAD_GA4_EVENTS 와 8장 검사의 공통 근거'
AS
SELECT column_name, data_type,
       ROW_NUMBER() OVER (ORDER BY ordinal_position) AS pos
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'BRONZE_BIGQUERY'
  AND table_name   = 'EVENTS'
  AND column_name NOT IN ('SRC_TABLE', 'EVENT_DT', 'SRC_FILE_NAME', 'LOAD_TS');

-- 확인 — 31컬럼 / VARIANT 11개 / pos 1..31 연속이어야 한다
SELECT COUNT(*) AS n_data_cols, MIN(pos) AS min_pos, MAX(pos) AS max_pos,
       COUNT_IF(data_type='VARIANT') AS n_variant,
       LISTAGG(CASE WHEN data_type='VARIANT' THEN pos::VARCHAR END, ',')
         WITHIN GROUP (ORDER BY pos) AS variant_pos
FROM SANDBOX.TOOLS.V_GA4_EVENTS_DATA_COLS;
-- ✅ 2026-08-18 실측 = 31 / 1 / 31 / 11 / '4,11,12,14,15,16,18,22,23,24,29'
-- 🔴 max_pos <> n_data_cols 이면 즉시 중단하라 — 위치가 밀린다는 뜻이다.

------------------------------------------------------------
-- 3-C. 부속 테이블 — 적재 이력 + 통제총계
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SANDBOX.TOOLS.MIG_GA4_LOAD_LOG (
  RUN_ID        VARCHAR       COMMENT '한 번의 CALL 을 묶는 ID',
  YM            VARCHAR(6)    COMMENT '적재 대상 연월(YYYYMM)',
  N_FOLDERS     NUMBER        COMMENT '해당 연월의 스테이지 폴더 수(일수)',
  STATUS        VARCHAR       COMMENT 'LOADED / NO_FILES / DRY_RUN / ERROR',
  FILES_LOADED  NUMBER        COMMENT 'COPY 가 실제 처리한 파일 수(이미 적재된 파일은 0)',
  ROWS_LOADED   NUMBER        COMMENT '적재 행수',
  ELAPSED_SEC   NUMBER        COMMENT '소요 초',
  ERROR_MESSAGE VARCHAR       COMMENT 'ERROR 일 때 원문',
  COPY_QUERY_ID VARCHAR       COMMENT 'COPY 의 query_id — COPY_HISTORY 추적용',
  COPY_SQL      VARCHAR       COMMENT '실제 실행된 COPY 문장 전문(DRY_RUN 검토용)',
  STARTED_AT    TIMESTAMP_LTZ,
  ENDED_AT      TIMESTAMP_LTZ
)
COMMENT = 'LOAD_GA4_EVENTS 적재 이력';

-- 통제총계(control total). 4장에서 A 계정 실측을 여기에 넣고, 7장 (2) 에서 대조한다.
-- 🔴 이 테이블이 비어 있으면 적재 완료를 증명할 수 없다. 1판에 없던 통제다.
CREATE TABLE IF NOT EXISTS SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT (
  SRC_TABLE     VARCHAR(64)   COMMENT 'A 계정 원천 테이블명(events_YYYYMMDD)',
  SRC_ROW_COUNT NUMBER        COMMENT 'A 계정 INFORMATION_SCHEMA.TABLES.row_count 실측',
  SRC_BYTES     NUMBER        COMMENT 'A 계정 bytes 실측',
  CAPTURED_AT   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT '등재 시각'
)
COMMENT = 'A 계정 GA4 원천 행수 통제총계. 7장 (2) 대조의 기준선. 출처=본 문서 4장';


-- =====================================================================
-- 4장. 🅰️ **A 계정에서 실행할 쿼리** — 통제총계 확보
--   목적: "적재가 끝났는가" 를 판정할 수 있는 유일한 기준선을 만든다.
--         일별 테이블이 676개이므로 눈으로 대조할 수 없다. 기계 대조용 데이터로 가져온다.
--   실행 위치: 🔴 **A 계정 (Producer)**. C 계정이 아니다.
--   전제: A 의 GA4 원천은 C 와 같은 이름이다 — GN_DW.BRONZE_BIGQUERY (02번 문서 확인)
--   근거: 02_데이터마이그 A_PRODUCER.sql 5단계와 동일한
--         INFORMATION_SCHEMA.TABLES(row_count, bytes) 패턴을 events_* 로 확장한 것이다.
-- =====================================================================

-- ── A-1. 요약 (먼저 이것부터. 0장 (5) 추정치와 자리수가 맞는지 본다) ────────────
/*
USE ROLE ACCOUNTADMIN;      -- A 계정에서 원천을 볼 수 있는 역할
SELECT COUNT(*)                AS n_tables,
       SUM(row_count)          AS total_rows,
       TO_VARCHAR(SUM(bytes))  AS total_bytes,
       MIN(table_name)         AS min_table,
       MAX(table_name)         AS max_table
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE_BIGQUERY'
  AND table_type   = 'BASE TABLE'
  AND table_name RLIKE 'events_[0-9]{8}';
*/
-- 🔴 `LIKE 'events_%'` 를 쓰지 말 것 — '_' 가 LIKE 와일드카드다. RLIKE 로 정확히 8자리만 잡는다.
-- ✅ 2026-08-18 A 계정 실측 결과 —
--      n_tables    = 911
--      total_rows  = 285,676,588
--      total_bytes = 48,362,186,752
--      min_table   = events_20240101
--      max_table   = events_20260719
--    🔴 15번 DDL 문서는 676개(~20251107)만 담고 있다 → 235개 누락. 0장 (1) 참조.

-- ── A-2. 등재용 INSERT 문 생성 (연월별 1문장) ────────────────────────────────
--   출력된 insert_stmt 컬럼을 전부 복사해 **C 계정**에 붙여 실행한다.
--   연월로 쪼개는 이유: 911건을 한 문장으로 만들면 셀에서 잘려 복사 사고가 난다.
--   ✅ 2026-08-18 실측 = 31행 출력(202401~202607). n_tables 합계 911, ym_rows 합계
--      285,676,588 로 A-1 과 완전히 일치했다. 마지막 202607 은 1테이블(events_20260719).
/*
SELECT SUBSTR(table_name, 8, 6) AS ym,
       COUNT(*)                 AS n_tables,
       SUM(row_count)           AS ym_rows,
       'INSERT INTO SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT (SRC_TABLE, SRC_ROW_COUNT, SRC_BYTES) VALUES '
       || LISTAGG('(''' || table_name || ''',' || row_count || ',' || bytes || ')', ',')
            WITHIN GROUP (ORDER BY table_name)
       || ';' AS insert_stmt
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE_BIGQUERY'
  AND table_type   = 'BASE TABLE'
  AND table_name RLIKE 'events_[0-9]{8}'
GROUP BY 1
ORDER BY 1;
*/
-- ⚠️ row_count / bytes 는 메타데이터다(테이블 스캔 없음). 즉시 반환된다.
-- ⚠️ A 에서 이후에 원천이 더 늘어나면 통제총계도 다시 뽑아야 한다.
--    그때는 C 에서 아래로 비우고 재등재한다:
--    TRUNCATE TABLE SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT;

-- ── A-3. (C 계정) 등재 확인 ──────────────────────────────────────────────
SELECT COUNT(*) AS n_tables, SUM(SRC_ROW_COUNT) AS total_rows, MAX(CAPTURED_AT) AS captured
FROM SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT;
-- A-1 의 n_tables / total_rows 와 **정확히** 일치해야 한다. 다르면 붙여넣기가 누락된 것이다.
-- ✅ 2026-08-18 실측 = 911 / 285,676,588 / 48,362,186,752 → A-1 과 완전 일치


------------------------------------------------------------
-- 5장. 동적 적재 프로시저
--
--   ▣ 왜 '월 단위 COPY' 인가
--     · 폴더당 COPY 1개(911문장) → 문장 오버헤드가 지배적이고 로그도 911행이 된다.
--     · 전체 1문장 → 63.7 GB 를 한 트랜잭션으로 처리한다. 마지막 파일에서 실패하면 전량 롤백.
--     · 월 단위(31문장) = 중단 지점이 명확하고, 롤백 단위가 1개월로 제한되며,
--       마이크로파티션이 EVENT_DT 순으로 쌓여 프루닝까지 확보된다.
--       ✅ 실측 = 31개월 / 6,338파일 / 277,140,582행 / errors=0 을 CALL 1회로 완주.
--
--   ▣ 왜 '동적 생성' 인가 — 06번 A.5 의 `TRY_PARSE_JSON($4), ... , $31` 수동 나열을 없앤다.
--     대상 컬럼 목록과 SELECT 전개식을 **V_GA4_EVENTS_DATA_COLS 뷰(3-B)** 에서 만든다.
--     VARIANT 판정도 타입에서 자동으로 나온다.
--
--   ▣ 엄격 모드(PARSE_JSON) — 1판 정정 ①
--     1판은 TRY_PARSE_JSON 을 썼다. TRY_ 계열은 **예외를 던지지 않으므로**
--     깨진 JSON 이 조용히 NULL 이 되고 ON_ERROR=ABORT_STATEMENT 가 아무 역할을 못 한다.
--     그리고 사후에는 원본 문자열이 없으므로 '원천 NULL' 과 '파싱 실패' 를 구별할 수 없다.
--     실측 근거 — VARIANT 11개 중 user_ltv 5.8% / ecommerce 2.9% / traffic_source 22% 만
--     비-NULL 이다. 1판의 검사(COUNT>0, TYPEOF)는 두 경우 모두 통과한다.
--     ⇒ PARSE_JSON 으로 바꾼다. 실측: **6,517파일 285,676,588행에서 오류 0건**이므로 비용이 없다.
--     ⇒ 어느 달이 파싱으로 중단되면 7장 (4) 진단 쿼리로 불량 행을 특정한다.
--
--   ▣ 재실행 안전성
--     COPY 는 FORCE=TRUE 가 없으면 이미 적재한 파일을 건너뛴다(적재 메타데이터 64일).
--     실측: 202503 재호출 → 신규 도착 2파일만 적재, 중복 0건.
--     🔴 64일이 지난 뒤 재실행하면 스킵 판정이 사라져 중복 적재된다.
--        1판과 달리 이제 **검출은 가능하다** — 7장 (3). 처방은 TRUNCATE 후 전량 재적재.
--
--   ▣ 파라미터
--     P_YM_FROM  '202401' 형식. NULL/'' = 스테이지에 있는 최소 연월
--     P_YM_TO    '202412' 형식. NULL/'' = 스테이지에 있는 최대 연월
--     P_DRY_RUN  TRUE  = COPY 를 실행하지 않고 생성된 문장만 로그에 남긴다(반드시 먼저 1회)
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SANDBOX.TOOLS.LOAD_GA4_EVENTS(
  P_YM_FROM STRING, P_YM_TO STRING, P_DRY_RUN BOOLEAN)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'GA4 스테이지 폴더를 월 단위로 GN_DW.BRONZE_BIGQUERY.EVENTS 에 동적 COPY. 엄격 PARSE_JSON(fail-fast). 컬럼목록=SANDBOX.TOOLS.V_GA4_EVENTS_DATA_COLS. 이력=SANDBOX.TOOLS.MIG_GA4_LOAD_LOG'
AS
$$
DECLARE
  v_run_id   STRING;
  v_cols     STRING;          -- COPY INTO 의 대상 컬럼 목록
  v_sel      STRING;          -- FROM ( SELECT ... ) 전개식
  v_sql      STRING;
  v_ym       STRING;
  v_nfold    NUMBER;
  v_qid      STRING;
  v_files    NUMBER;
  v_rows     NUMBER;
  v_t0       TIMESTAMP_LTZ;
  v_n_ym     NUMBER  DEFAULT 0;
  v_tot_rows NUMBER  DEFAULT 0;
  v_tot_file NUMBER  DEFAULT 0;
  v_err_cnt  NUMBER  DEFAULT 0;
  c_ym CURSOR FOR
    SELECT ym, n_folders FROM ga4_months ORDER BY ym;
BEGIN
  v_run_id := UUID_STRING();

  LET v_exists NUMBER := (
    SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE_BIGQUERY' AND table_name = 'EVENTS');
  IF (v_exists = 0) THEN
    RETURN 'ABORT — GN_DW.BRONZE_BIGQUERY.EVENTS 가 없다. 3장 DDL 을 먼저 실행하라.';
  END IF;

  ----------------------------------------------------------
  -- (1) 전개식 생성. 데이터 컬럼의 유일한 근거는 3-B 뷰다.
  --     VARIANT → PARSE_JSON (엄격). 깨진 JSON 은 NULL 이 아니라 COPY 중단으로 드러난다.
  ----------------------------------------------------------
  SELECT LISTAGG('"' || column_name || '"', ',') WITHIN GROUP (ORDER BY pos),
         LISTAGG(CASE WHEN data_type = 'VARIANT'
                      THEN 'PARSE_JSON($' || pos || ')'
                      ELSE '$' || pos END, ',') WITHIN GROUP (ORDER BY pos)
    INTO :v_cols, :v_sel
  FROM SANDBOX.TOOLS.V_GA4_EVENTS_DATA_COLS;

  IF (v_cols IS NULL) THEN
    RETURN 'ABORT — V_GA4_EVENTS_DATA_COLS 가 비어 있다. 3-B 를 먼저 실행하라.';
  END IF;

  -- 메타데이터 4컬럼. 🔴 경로 '위치'에 의존하지 않도록 REGEXP 로 폴더명을 뽑는다.
  --    1판은 SPLIT_PART(...,'/',2) 였다. FROM 경로를 바꾸면 조용히 깨지는 구조였고,
  --    이 문서가 06번의 위치 하드코딩을 비판하면서 같은 실수를 재도입한 것이었다.
  v_cols := :v_cols || ',SRC_TABLE,EVENT_DT,SRC_FILE_NAME,LOAD_TS';
  v_sel  := :v_sel
         || ',REGEXP_SUBSTR(METADATA$FILENAME,''events_[0-9]{8}'')'
         || ',TRY_TO_DATE(RIGHT(REGEXP_SUBSTR(METADATA$FILENAME,''events_[0-9]{8}''),8),''YYYYMMDD'')'
         || ',METADATA$FILENAME'
         || ',METADATA$START_SCAN_TIME';

  ----------------------------------------------------------
  -- (2) 처리 대상 연월 (하드코딩 없음)
  --     🔴 LIST 는 프로시저 안에서 금지된 문장이다 → 디렉터리 테이블을 쓴다(1장).
  ----------------------------------------------------------
  EXECUTE IMMEDIATE 'ALTER STAGE SANDBOX.TOOLS.MIG_LOAD_STAGE REFRESH';

  CREATE OR REPLACE TEMPORARY TABLE ga4_folders AS
  SELECT DISTINCT REGEXP_SUBSTR(RELATIVE_PATH, 'events_[0-9]{8}') AS folder
  FROM DIRECTORY(@SANDBOX.TOOLS.MIG_LOAD_STAGE)
  WHERE RELATIVE_PATH RLIKE 'BRONZE_BIGQUERY/events_[0-9]{8}/.*';

  CREATE OR REPLACE TEMPORARY TABLE ga4_months AS
  SELECT SUBSTR(RIGHT(folder, 8), 1, 6) AS ym, COUNT(*) AS n_folders
  FROM ga4_folders GROUP BY 1;

  DELETE FROM ga4_months
  WHERE (:P_YM_FROM IS NOT NULL AND :P_YM_FROM <> '' AND ym < :P_YM_FROM)
     OR (:P_YM_TO   IS NOT NULL AND :P_YM_TO   <> '' AND ym > :P_YM_TO);

  ----------------------------------------------------------
  -- (3) 연월별 COPY
  ----------------------------------------------------------
  FOR r IN c_ym DO
    v_ym    := r.ym;
    v_nfold := r.n_folders;
    v_t0    := CURRENT_TIMESTAMP();
    v_files := 0;
    v_rows  := 0;
    v_qid   := NULL;

    -- 🔴 PATTERN 은 FROM 경로(@stage/BRONZE_BIGQUERY/) 기준 **상대 경로**에 매칭된다.
    --    1판은 '스테이지 루트 기준'이라고 썼다. 틀렸다.
    --    실측: PATTERN => 'events_20250301/.*[.]csv[.]gz' 가 선행 '.*' 없이 4파일 매칭.
    --    ⚠️ 그래서 선행 '/' 를 붙이면 **0건이 되고, 오류 없이 조용히 넘어간다.**
    --       (실제로 그 실수로 files=0 / errors=0 을 한 번 만들었다.)
    v_sql := 'COPY INTO GN_DW.BRONZE_BIGQUERY.EVENTS (' || :v_cols || ') '
          || 'FROM (SELECT ' || :v_sel
          || ' FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/) '
          || 'PATTERN = ''events_' || :v_ym || '[0-9]{2}/.*[.]csv[.]gz'' '
          || 'FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD) '
          || 'ON_ERROR = ABORT_STATEMENT PURGE = FALSE';

    IF (P_DRY_RUN) THEN
      INSERT INTO SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
        (RUN_ID, YM, N_FOLDERS, STATUS, FILES_LOADED, ROWS_LOADED, ELAPSED_SEC,
         ERROR_MESSAGE, COPY_QUERY_ID, COPY_SQL, STARTED_AT, ENDED_AT)
      SELECT :v_run_id, :v_ym, :v_nfold, 'DRY_RUN', NULL, NULL, 0,
             NULL, NULL, :v_sql, :v_t0, CURRENT_TIMESTAMP();
      v_n_ym := :v_n_ym + 1;
    ELSE
      BEGIN
        EXECUTE IMMEDIATE :v_sql;
        v_qid := SQLID;

        -- COPY 결과 파싱. 처리할 파일이 0건이면 결과 컬럼 구성이 달라지므로 예외로 흡수한다.
        BEGIN
          SELECT COUNT(*), COALESCE(SUM("rows_loaded"), 0)
            INTO :v_files, :v_rows
          FROM TABLE(RESULT_SCAN(:v_qid));
        EXCEPTION
          WHEN OTHER THEN
            v_files := 0;
            v_rows  := 0;
        END;

        INSERT INTO SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
          (RUN_ID, YM, N_FOLDERS, STATUS, FILES_LOADED, ROWS_LOADED, ELAPSED_SEC,
           ERROR_MESSAGE, COPY_QUERY_ID, COPY_SQL, STARTED_AT, ENDED_AT)
        SELECT :v_run_id, :v_ym, :v_nfold,
               CASE WHEN :v_files = 0 THEN 'NO_FILES' ELSE 'LOADED' END,
               :v_files, :v_rows,
               DATEDIFF('second', :v_t0, CURRENT_TIMESTAMP()),
               NULL, :v_qid, :v_sql, :v_t0, CURRENT_TIMESTAMP();

        v_n_ym     := :v_n_ym + 1;
        v_tot_rows := :v_tot_rows + :v_rows;
        v_tot_file := :v_tot_file + :v_files;
      EXCEPTION
        WHEN OTHER THEN
          -- 한 달이 실패해도 나머지 달은 계속 적재한다. 실패 월은 로그로 특정된다.
          INSERT INTO SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
            (RUN_ID, YM, N_FOLDERS, STATUS, FILES_LOADED, ROWS_LOADED, ELAPSED_SEC,
             ERROR_MESSAGE, COPY_QUERY_ID, COPY_SQL, STARTED_AT, ENDED_AT)
          SELECT :v_run_id, :v_ym, :v_nfold, 'ERROR', NULL, NULL,
                 DATEDIFF('second', :v_t0, CURRENT_TIMESTAMP()),
                 :SQLCODE || ' | ' || :SQLERRM, NULL, :v_sql, :v_t0, CURRENT_TIMESTAMP();
          v_err_cnt := :v_err_cnt + 1;
      END;
    END IF;
  END FOR;

  RETURN 'run_id=' || :v_run_id
      || ' | months=' || :v_n_ym
      || ' | files=' || :v_tot_file
      || ' | rows='  || :v_tot_rows
      || ' | errors=' || :v_err_cnt
      || CASE WHEN :v_err_cnt > 0 THEN '  🔴 실패 월 있음 — MIG_GA4_LOAD_LOG 확인' ELSE '' END
      || CASE WHEN :P_DRY_RUN THEN ' | DRY_RUN (COPY 미실행)' ELSE '' END;
END;
$$;


------------------------------------------------------------
-- 6장. 실행
------------------------------------------------------------
-- (1) 🔴 먼저 DRY_RUN 으로 생성될 COPY 문장을 눈으로 확인한다. 데이터는 건드리지 않는다.
CALL SANDBOX.TOOLS.LOAD_GA4_EVENTS(NULL, NULL, TRUE);

SELECT YM, N_FOLDERS,
       REGEXP_COUNT(COPY_SQL, 'PARSE_JSON')      AS n_parse_json,
       REGEXP_COUNT(COPY_SQL, 'TRY_PARSE_JSON')  AS n_try_parse_json,
       CONTAINS(COPY_SQL, 'FF_CSV_LOAD')         AS uses_ff_csv_load,
       REGEXP_SUBSTR(COPY_SQL, 'PATTERN = ''[^'']*''') AS pattern_part,
       COPY_SQL
FROM SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
WHERE STATUS = 'DRY_RUN'
  AND RUN_ID = (SELECT RUN_ID FROM SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
                WHERE STATUS = 'DRY_RUN' ORDER BY STARTED_AT DESC LIMIT 1)
ORDER BY YM;
-- 🔴 WHERE 에 STATUS='DRY_RUN' 이 두 번 들어간 것은 의도다. 1판은 이 필터가 없어서
--    실적재 후 실행하면 엉뚱한 run 을 보여줬다.
-- 확인 사항
--   · YM 목록과 N_FOLDERS 합계가 1장 folders 실측과 일치하는가
--     ✅ 실측(432폴더 시점) — months=15(202401~202503), N_FOLDERS 합계 = 432 일치
--     ✅ 실측(업로드 완료)  — months=31(202401~202607), N_FOLDERS 합계 = 911 일치
--   · n_parse_json = 11 이고 n_try_parse_json = 0 인가        ✅ 실측 11 / 0
--   · uses_ff_csv_load = TRUE 인가                            ✅ 실측 TRUE
--   · pattern_part 가 'events_YYYYMM[0-9]{2}/.*[.]csv[.]gz' 인가 (선행 '/' 나 '.*' 없음)
--     ✅ 실측 — PATTERN = 'events_202503[0-9]{2}/.*[.]csv[.]gz'

-- (2) 한 달만 실전 적재해 스모크 테스트
CALL SANDBOX.TOOLS.LOAD_GA4_EVENTS('202503', '202503', FALSE);
-- ✅ 2026-08-18 실측(X-Small) = 177파일 / 8,396,742행 / errors=0
--    이어서 7장 (1)(3)(4)(5) 를 이 한 달에 대해 먼저 통과시킨 뒤 (3) 전량으로 넘어간다.

-- (3) 전량 적재
--   ✅ 2026-08-18 실측(X-Small) = **months=31 / files=6,338 / rows=277,140,582 / errors=0**
--      (스모크로 이미 적재한 202503 의 179파일은 자동 스킵 → 누계 6,517파일 285,676,588행)
--   웨어하우스를 키우면 파일 단위로 병렬화되어 거의 선형으로 줄지만,
--   위 실측이면 X-Small 로도 충분했다. 키웠으면 반드시 원복한다(과금).
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';
CALL SANDBOX.TOOLS.LOAD_GA4_EVENTS(NULL, NULL, FALSE);
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';
--   🟢 재실행해도 안전하다 — 이미 적재한 파일은 건너뛴다.
--   🔴 **업로드가 끝난 뒤 반드시 한 번 더 호출하라.** 0장 (4) 2회차 실측 참조:
--      진행 중에 적재하면 그 시점 파일만 들어가고 status=LOADED / errors=0 을 반환한다.
--      재호출이 files>0 을 반환하면 그 직전 상태는 '누락'이었다는 뜻이다.
--      files=0 이 나올 때까지 반복한다. 그 다음 7장 (2) 로 확정한다.

-- (4) 적재 이력 — 진행/중단 상황의 정본
SELECT YM, STATUS, N_FOLDERS, FILES_LOADED, ROWS_LOADED, ELAPSED_SEC, ERROR_MESSAGE
FROM SANDBOX.TOOLS.MIG_GA4_LOAD_LOG
WHERE STATUS <> 'DRY_RUN'
ORDER BY STARTED_AT DESC, YM;
-- STATUS='ERROR'    → ERROR_MESSAGE 확인 후 그 달만 재호출.
--                     PARSE_JSON 실패면 7장 (4) 진단 쿼리로 불량 행을 특정한다.
-- STATUS='NO_FILES' → 그 달의 모든 파일이 이미 적재됨(정상) 또는 그 달 파일이 없음.
--                     N_FOLDERS 로 구분한다.

-- (5) COPY 단위 실패 상세
SELECT file_name, status, row_count, row_parsed, error_count,
       first_error_message, last_load_time
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE table_schema_name = 'BRONZE_BIGQUERY' AND table_name = 'EVENTS'
  AND last_load_time >= DATEADD('day', -2, CURRENT_TIMESTAMP())
  AND (status <> 'Loaded' OR error_count > 0)
ORDER BY last_load_time DESC;
-- → 0건이어야 정상. (ACCOUNT_USAGE 는 최대 2시간 지연. 즉시 확인은 아래.)
-- SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.COPY_HISTORY(
--          TABLE_NAME => 'GN_DW.BRONZE_BIGQUERY.EVENTS',
--          START_TIME => DATEADD('hour', -6, CURRENT_TIMESTAMP())))
-- WHERE STATUS <> 'Loaded' OR ERROR_COUNT > 0;


------------------------------------------------------------
-- 7장. 검증 — 06번 A.6 (3) GA4 항목을 대체한다
--   🔴 (2) 통제총계 대조가 **완료 판정의 유일한 근거**다. 나머지는 보조 검사다.
------------------------------------------------------------
-- (1) 총량 개요
SELECT COUNT(*)                      AS n_rows,
       COUNT(DISTINCT SRC_TABLE)     AS n_src_tables,
       COUNT(DISTINCT EVENT_DT)      AS n_days,
       COUNT(DISTINCT SRC_FILE_NAME) AS n_files,
       COUNT(DISTINCT LOAD_TS)       AS n_load_batches,
       MIN(EVENT_DT) AS min_dt, MAX(EVENT_DT) AS max_dt,
       MIN(LOAD_TS)  AS first_load, MAX(LOAD_TS) AS last_load
FROM GN_DW.BRONZE_BIGQUERY.EVENTS;
-- 기대: n_src_tables = n_days = 1장 folders · n_files = 1장 files
-- ✅ 2026-08-18 **최종 실측** = 285,676,588행 / 911 / 911 / 6,517 / 6,517
--    2024-01-01 ~ 2026-07-19. 스테이지 911폴더·6,517파일과 완전 일치.
--    (EVENT_DT NULL 은 구조적으로 불가능하다 — 3장에서 NOT NULL 이다)

-- (2) 🔴 통제총계 대조 — A 실측 대비 SRC_TABLE 단위 행수 일치
--     폴더 존재만 보는 검사로는 '폴더 안 파일 1개 누락' 을 절대 못 잡는다.
WITH tgt AS (
  SELECT SRC_TABLE, COUNT(*) AS c_rows, COUNT(DISTINCT SRC_FILE_NAME) AS c_files
  FROM GN_DW.BRONZE_BIGQUERY.EVENTS GROUP BY 1
),
src AS (
  SELECT SRC_TABLE, SRC_ROW_COUNT FROM SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT
)
SELECT COALESCE(s.SRC_TABLE, t.SRC_TABLE)   AS src_table,
       s.SRC_ROW_COUNT                      AS a_rows,
       t.c_rows                              AS c_rows,
       t.c_rows - s.SRC_ROW_COUNT            AS diff,
       t.c_files,
       CASE WHEN s.SRC_TABLE IS NULL        THEN 'NOT_IN_CONTROL_TOTAL — A 실측 미등재(4장 미실행)'
            WHEN t.SRC_TABLE IS NULL        THEN 'MISSING_IN_C — 미적재. 그 연월 재호출'
            WHEN t.c_rows < s.SRC_ROW_COUNT THEN 'SHORT_LOAD — 파일 누락. 6장 (3) 재호출'
            WHEN t.c_rows > s.SRC_ROW_COUNT THEN 'OVER_LOAD — 중복 적재 의심. (3) 확인'
            ELSE 'OK' END                    AS diagnosis
FROM src s FULL OUTER JOIN tgt t ON s.SRC_TABLE = t.SRC_TABLE
WHERE s.SRC_TABLE IS NULL OR t.SRC_TABLE IS NULL OR t.c_rows <> s.SRC_ROW_COUNT
ORDER BY 1;
-- 🔴 **0건이어야 적재 완료다.** 이 쿼리가 0건이 되기 전에는 어떤 후속 작업도 시작하지 말 것.
-- ✅ 2026-08-18 **최종 실측 = 0건** (911테이블 전수 행수 일치) → 적재 완료 확정
-- 총계 한 줄 확인:
SELECT (SELECT SUM(SRC_ROW_COUNT) FROM SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT) AS a_total,
       (SELECT COUNT(*)           FROM GN_DW.BRONZE_BIGQUERY.EVENTS)        AS c_total,
       (SELECT COUNT(*)           FROM GN_DW.BRONZE_BIGQUERY.EVENTS)
     - (SELECT SUM(SRC_ROW_COUNT) FROM SANDBOX.TOOLS.MIG_GA4_SRC_ROWCOUNT)  AS diff;
-- ✅ 최종 실측 = 285,676,588 / 285,676,588 / **diff = 0**
-- 🟢 이 a_total 값으로 01번 문서 §대조표의 BRONZE_BIGQUERY 행을 갱신한다(0장 (5)).

-- (3) 중복 적재 검출 — SRC_FILE_NAME / LOAD_TS 로만 가능하다(1판에는 불가능했다)
SELECT SRC_FILE_NAME, COUNT(DISTINCT LOAD_TS) AS n_load_batches, COUNT(*) AS n_rows
FROM GN_DW.BRONZE_BIGQUERY.EVENTS
GROUP BY 1
HAVING COUNT(DISTINCT LOAD_TS) > 1
ORDER BY 1;
-- → 0건이어야 정상. ✅ **최종 실측 0건** (6,517파일 전수, 3회에 걸친 적재 후에도 중복 없음).
-- 나오면 같은 파일이 두 배치에서 적재됐다는 뜻이다(64일 경과 재실행 등).
-- 처방: TRUNCATE TABLE GN_DW.BRONZE_BIGQUERY.EVENTS 후 6장부터 전량 재적재.

-- (4) VARIANT 파싱 확인 — **월 단위로** 본다
--     🔴 1판은 SAMPLE(1000000 ROWS) 로 전체를 한 줄로 요약했다. 잘못이다 —
--        2.86억행에서 100만 표본은 '특정 하루만 이상' 한 경우를 놓친다.
--     🟢 엄격 PARSE_JSON(5장 ▣)이므로 파싱 실패는 애초에 COPY 중단으로 드러난다.
--        따라서 이 검사의 역할은 '타입이 기대와 같은지' 와 '구간별 커버리지' 확인이다.
SELECT DATE_TRUNC('month', EVENT_DT)                          AS ym,
       COUNT(*)                                               AS n_rows,
       COUNT(DISTINCT TYPEOF("event_params"))                 AS ep_typecnt,
       MAX(TYPEOF("event_params"))                            AS ep_type,     -- ARRAY
       MAX(TYPEOF("device"))                                  AS dev_type,    -- OBJECT
       COUNT("event_params"[0])                               AS ep_indexable,
       COUNT("device":category)                               AS dev_key,
       COUNT("geo":country)                                   AS geo_key,
       COUNT("batch_event_index")                             AS c26,
       COUNT("session_traffic_source_last_click")             AS c29,
       MAX(TYPEOF("session_traffic_source_last_click"))        AS c29_type,
       COUNT("event_original_occurrence_timestamp")            AS c31
FROM GN_DW.BRONZE_BIGQUERY.EVENTS
GROUP BY 1 ORDER BY 1;
-- 기대 (0장 (2) 표와 일치해야 한다)
--   ep_type='ARRAY' · dev_type='OBJECT' · ep_typecnt=1 (전 구간)
--   c26 은 어느 달부터 > 0 / c29 는 그보다 늦게 > 0, c29_type='OBJECT'
--   app_info / event_dimensions / publisher / event_original_occurrence_timestamp
--     → 전 구간 0 이 정상(원천 언로드가 NULL)
-- ✅ 2026-08-18 **최종 실측 (31개월 전수)** —
--     ep_typecnt = 1 · ep_type='ARRAY' · dev_type='OBJECT' → 31개월 모두 동일. VARCHAR 오염 0.
--     c26 : 2024-01~06 = 0 → 2024-07 부분(3,895,880 / 8,171,653) → 2024-08 이후 전량
--           최초 비-NULL 테이블 = events_20240719
--     c29 : 2025-03 까지 0 → 2025-04 부터 값 발생(156,233), c29_type='OBJECT'
--           최초 비-NULL 테이블 = **events_20250426**
--           🟢 15번 DDL 에서 독립적으로 도출한 VARIANT 구간 시작일과 정확히 일치.
--              컬럼이 밀렸다면 이 경계가 어긋난다 ⇒ 911폴더 위치 정렬 확증(0장 (2)).
--     c30 (publisher) = 전 구간 0 · c31 = 전 구간 0
--     🔴 c31 은 1판이 '2026년 구간만 값 존재' 라고 썼지만 실제로는 전 구간 0 이다.
--        2026-07 원천 CSV 헤더가 31컬럼이고 31번째가 그 컬럼임을 확인했으므로
--        컬럼 누락이 아니라 원천 언로드 값이 NULL 인 것이다. 0장 (2) 참조.
--
-- ── PARSE_JSON 으로 어느 달이 중단됐을 때의 진단 (불량 행 특정) ──────────────
--    스테이지를 다시 읽어 '원본은 값이 있는데 파싱이 안 되는' 행만 뽑는다.
/*
SELECT METADATA$FILENAME AS f, METADATA$FILE_ROW_NUMBER AS rn,
       IFF($4  IS NOT NULL AND TRY_PARSE_JSON($4)  IS NULL, LEFT($4,200),  NULL) AS bad_event_params,
       IFF($11 IS NOT NULL AND TRY_PARSE_JSON($11) IS NULL, LEFT($11,200), NULL) AS bad_privacy_info,
       IFF($12 IS NOT NULL AND TRY_PARSE_JSON($12) IS NULL, LEFT($12,200), NULL) AS bad_user_properties,
       IFF($14 IS NOT NULL AND TRY_PARSE_JSON($14) IS NULL, LEFT($14,200), NULL) AS bad_user_ltv,
       IFF($15 IS NOT NULL AND TRY_PARSE_JSON($15) IS NULL, LEFT($15,200), NULL) AS bad_device,
       IFF($16 IS NOT NULL AND TRY_PARSE_JSON($16) IS NULL, LEFT($16,200), NULL) AS bad_geo,
       IFF($18 IS NOT NULL AND TRY_PARSE_JSON($18) IS NULL, LEFT($18,200), NULL) AS bad_traffic_source,
       IFF($22 IS NOT NULL AND TRY_PARSE_JSON($22) IS NULL, LEFT($22,200), NULL) AS bad_ecommerce,
       IFF($23 IS NOT NULL AND TRY_PARSE_JSON($23) IS NULL, LEFT($23,200), NULL) AS bad_items,
       IFF($24 IS NOT NULL AND TRY_PARSE_JSON($24) IS NULL, LEFT($24,200), NULL) AS bad_cts,
       IFF($29 IS NOT NULL AND TRY_PARSE_JSON($29) IS NULL, LEFT($29,200), NULL) AS bad_stslc
FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/
     (FILE_FORMAT => 'SANDBOX.TOOLS.FF_CSV_LOAD',
      PATTERN => 'events_202504[0-9]{2}/.*[.]csv[.]gz')     -- ← 중단된 연월로 바꾼다
WHERE COALESCE($4,$11,$12,$14,$15,$16,$18,$22,$23,$24,$29) IS NOT NULL
  AND (   ($4  IS NOT NULL AND TRY_PARSE_JSON($4)  IS NULL)
       OR ($11 IS NOT NULL AND TRY_PARSE_JSON($11) IS NULL)
       OR ($12 IS NOT NULL AND TRY_PARSE_JSON($12) IS NULL)
       OR ($14 IS NOT NULL AND TRY_PARSE_JSON($14) IS NULL)
       OR ($15 IS NOT NULL AND TRY_PARSE_JSON($15) IS NULL)
       OR ($16 IS NOT NULL AND TRY_PARSE_JSON($16) IS NULL)
       OR ($18 IS NOT NULL AND TRY_PARSE_JSON($18) IS NULL)
       OR ($22 IS NOT NULL AND TRY_PARSE_JSON($22) IS NULL)
       OR ($23 IS NOT NULL AND TRY_PARSE_JSON($23) IS NULL)
       OR ($24 IS NOT NULL AND TRY_PARSE_JSON($24) IS NULL)
       OR ($29 IS NOT NULL AND TRY_PARSE_JSON($29) IS NULL))
LIMIT 100;
*/
-- ⚠️ 위 $번호는 3-B 뷰의 VARIANT pos 와 일치해야 한다. GA4 가 컬럼을 추가해도
--    꼬리 추가이므로 기존 번호는 바뀌지 않지만, 3-B 확인 쿼리로 대조하고 쓸 것.
-- 불량 행이 특정되면 판단한다:
--   · 원천 결함이 확실하고 소수면 → 그 컬럼만 TRY_PARSE_JSON 으로 예외 처리(사유를 기록)
--   · 언로드 파손이면 → B 에서 그 폴더만 재언로드·재업로드 후 재적재

-- (5) EVENT_DT(파일 기준) ↔ "event_date"(GA4 기준) 불일치 — SRC_TABLE 단위
SELECT SRC_TABLE, COUNT(*) AS n_rows,
       SUM(IFF(TO_CHAR(EVENT_DT,'YYYYMMDD') <> "event_date", 1, 0)) AS mismatch
FROM GN_DW.BRONZE_BIGQUERY.EVENTS
GROUP BY 1
HAVING SUM(IFF(TO_CHAR(EVENT_DT,'YYYYMMDD') <> "event_date", 1, 0)) > 0
ORDER BY 1;
-- → 0건이면 두 컬럼을 구분할 필요가 없다.
-- ✅ 2026-08-18 **최종 실측 = 0건** (911테이블 285,676,588행 전수).
--    ⇒ EVENT_DT(파일 기준)와 "event_date"(GA4 기준)가 완전히 일치한다. 늦게 도착한
--      이벤트가 다른 일자 테이블에 섞인 사례가 없다. 두 컬럼을 구분해 쓸 필요가 없다.
-- 나오면 늦게 도착한 이벤트가 있다는 뜻 →
--   적재 대조는 EVENT_DT(파일 기준), 업무 집계는 "event_date"(GA4 기준)로 분리해 쓴다.
--   7장 (2) 대조는 EVENT_DT 가 아니라 SRC_TABLE 기준이므로 영향 없다.

-- (6) 프루닝 실측 — 클러스터링 키가 필요한지 판단(3장 참조)
--     🔴 1판은 날짜를 하드코딩해서 부분 적재 상태면 0행이 나와 판정이 무의미했다.
--        실제 적재된 구간에서 7일을 자동으로 고른다.
SET prune_from = (SELECT MIN(EVENT_DT) FROM GN_DW.BRONZE_BIGQUERY.EVENTS);
SELECT COUNT(*) AS n_rows_7d
FROM GN_DW.BRONZE_BIGQUERY.EVENTS
WHERE EVENT_DT BETWEEN $prune_from AND DATEADD('day', 6, $prune_from);
-- 실행 후 Query Profile 의 TableScan → 'Partitions scanned / Partitions total' 확인.
-- 판정 기준: scanned/total 이 (7 / 전체적재일수) 의 2배 이내면 정상 → CLUSTER BY 불필요.
--            그보다 크게 나오면 ALTER TABLE ... CLUSTER BY (EVENT_DT) 를 검토한다.
-- ✅ 2026-08-18 **최종 실측 (2024-01-01~07, 1,955,659행)** —
--      partitions_scanned = 19 / partitions_total = 3,006 → **0.632%**
--      이상치(7일 / 911일)           →  0.768%
--      bytes_scanned = 319,280,640 (전체 압축 63.7GB 대비 0.5%) · 0.09초
--    🟢 실측 프루닝이 이상치보다 오히려 **더 좋다**(초기 2024년 일평균 행수가 적기 때문).
--       ⇒ **CLUSTER BY 불필요 확정.** 월 단위 순차 적재만으로 EVENT_DT 프루닝이 확보됐다.
--         자동 클러스터링 비용을 들일 이유가 없다.
--    ⚠️ 단, 향후 증분 적재를 무작위 순서로 하면 이 성질이 깨진다. 증분도 월/일 단위 순차로.
--    참고: 전체 3,006 마이크로파티션 / 285,676,588행 ≈ 파티션당 9.5만행.
-- 쿼리 실행 후 프루닝 실측은 아래로 확인한다(Query Profile 대신 정량 조회):
-- SELECT operator_type,
--        operator_statistics:pruning:partitions_scanned::NUMBER AS part_scanned,
--        operator_statistics:pruning:partitions_total::NUMBER   AS part_total
-- FROM TABLE(GET_QUERY_OPERATOR_STATS('<위 SELECT 의 query_id>'))
-- WHERE operator_type = 'TableScan';
-- ⚠️ QUERY_HISTORY 테이블 함수에는 partitions_scanned 컬럼이 없다(실측 확인).
--    ACCOUNT_USAGE.QUERY_HISTORY 는 최대 45분 지연된다. 즉시 확인은 위 함수를 쓴다.


------------------------------------------------------------
-- 8장. GA4 전용 사전 검증 — 06번 A.1 (4) 를 대체
--   A.1 (4) 는 '폴더 ↔ 동명 테이블' 을 대조하므로 통합 테이블에는 쓸 수 없다.
--   대신 **모든 폴더의 CSV 헤더가 EVENTS 데이터 컬럼의 접두(prefix)인지** 를 검사한다.
--   🔴 0장 (3)ⓑ 정정에 따라, 이것이 위치 기반 적재의 **유일한** 방어선이다.
--      파일 포맷 옵션은 아무 것도 막아주지 않는다. 6장 전에 반드시 통과시킨다.
--   ⚠️ 스테이지 전량 스캔이라 시간·비용이 든다(06번 A.1 (3) 과 동일 수준. 63.7GB 압축 해제).
--      업로드 확정 후 1회. 진행 중에 돌리면 나중에 다시 돌려야 한다.
--
--   🟢 2026-08-18 이관에서는 이 검사를 **사후 확증으로 대체**했다. 근거 3중:
--      ① 통제총계 대조 — 911테이블 전수 행수 일치, 불일치 0건 (7장 (2))
--      ② 엄격 PARSE_JSON 이 11개 VARIANT 위치 × 285,676,588행에서 오류 0건.
--         컬럼이 밀렸다면 VARCHAR 컬럼(platform='WEB' 등)이 VARIANT 위치로 들어와
--         PARSE_JSON 이 실패하고 그 달이 중단됐을 것이다.
--      ③ 타입 변이 경계 재현 — session_traffic_source_last_click 최초 비-NULL 이
--         events_20250426 으로, 15번 DDL 에서 독립 도출한 경계와 정확히 일치 (7장 (4))
--      ⇒ 다음 이관(신규 폴더 추가)에서는 아래 검사를 정식으로 1회 돌리는 것을 권한다.
--         사후 확증은 '이미 적재한 뒤' 판정이므로 사전 방어가 아니다.
------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT SANDBOX.TOOLS.FF_CSV_PEEK
  TYPE = CSV COMPRESSION = GZIP FIELD_DELIMITER = NONE SKIP_HEADER = 0;

WITH stage_hdr AS (
  SELECT REGEXP_SUBSTR(METADATA$FILENAME, 'events_[0-9]{8}')                AS folder,
         MIN(CASE WHEN METADATA$FILE_ROW_NUMBER = 1 THEN $1::VARCHAR END)   AS hdr
  FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/
       (FILE_FORMAT => 'SANDBOX.TOOLS.FF_CSV_PEEK', PATTERN => 'events_[0-9]{8}/.*[.]csv[.]gz')
  GROUP BY 1
),
f AS (
  SELECT folder,
         ARRAY_SIZE(SPLIT(hdr, ','))  AS file_cols,
         UPPER(REPLACE(hdr, '"', ''))  AS file_col_list
  FROM stage_hdr
  WHERE folder IS NOT NULL
),
t AS (
  SELECT COUNT(*)                                                          AS tbl_cols,
         UPPER(LISTAGG(column_name, ',') WITHIN GROUP (ORDER BY pos))       AS tbl_col_list
  FROM SANDBOX.TOOLS.V_GA4_EVENTS_DATA_COLS      -- 3-B 뷰 = 5장 프로시저와 같은 근거
)
SELECT f.folder, f.file_cols, t.tbl_cols,
       CASE
         WHEN t.tbl_cols = 0             THEN 'VIEW_EMPTY — 3-B 뷰/EVENTS 확인'
         WHEN f.file_cols > t.tbl_cols   THEN 'TOO_MANY_COLS — GA4 신규 컬럼. EVENTS 에 ADD COLUMN 필요'
         WHEN NOT STARTSWITH(t.tbl_col_list, f.file_col_list)
                                         THEN 'NOT_A_PREFIX — 컬럼 순서/이름 불일치. 위치 적재 시 값 밀림'
       END AS diagnosis,
       f.file_col_list
FROM f CROSS JOIN t
WHERE t.tbl_cols = 0
   OR f.file_cols > t.tbl_cols
   OR NOT STARTSWITH(t.tbl_col_list, f.file_col_list)
ORDER BY 1;
-- 🔴 0건이어야 6장을 실행한다.
--
-- 🔴 1판 정정 ② — 1판은 `t.tbl_col_list NOT LIKE f.file_col_list || '%'` 였다.
--    LIKE 에서 '_' 는 임의 1문자 와일드카드이고 **GA4 컬럼명은 전부 언더스코어**다.
--    실측: 'EVENTXDATE,...' LIKE 'EVENT_DATE%' → TRUE (불일치인데 통과)
--          STARTSWITH('EVENTXDATE,...','EVENT_DATE') → FALSE (정상 검출)
--    즉 1판의 '유일한 방어선' 이 무력화된 상태였다. STARTSWITH 로 교체했다.
--
--   TOO_MANY_COLS  : GA4 신규 컬럼이다. 정상적인 스키마 진화다.
--                    → ALTER TABLE GN_DW.BRONZE_BIGQUERY.EVENTS
--                        ADD COLUMN "<신규컬럼>" <타입> COMMENT '...';
--                      을 **꼬리에** 추가하고 이 검사를 다시 돌린다.
--                      3-B 뷰와 5장 프로시저는 고치지 않는다.
--   NOT_A_PREFIX   : 앞쪽 컬럼이 바뀐 것이다. 지금까지 한 번도 없었다(0장 (2)).
--                    🔴 절대 적재하지 말고 해당 폴더를 별도 처리로 분리한다.


------------------------------------------------------------
-- 9장. 기존 문서 처리 지침
------------------------------------------------------------
--   Q. 04번 DDL 에서 bigquery 부분을 빼고 실행할까? 15번 GA4 DDL 을 실행할까?
--
--   A-1. 99_provided_definition/15_bronze_ga4_ddl.sql (20,527행 · 676테이블)
--        🔴 **실행하지 않는다.** 3장 EVENTS 1개가 전부 대체한다.
--            원천 구조 정본으로서 참조용으로만 보관한다(0장 (2) 표의 근거 문서다).
--
--   A-2. 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql
--        🔴🔴 **실행 순서 제약 — 이걸 놓치면 EVENTS 가 전량 삭제된다.** 🔴🔴
--        04번 1397행 = `create or replace schema GN_DW.BRONZE_BIGQUERY with managed access ...`
--        `CREATE OR REPLACE SCHEMA` 는 **스키마를 통째로 드롭하고 다시 만든다.**
--        ⇒ 04번을 **적재 이후에** 실행하면 EVENTS 가 경고 없이 사라진다.
--        ⚠️ 2026-08-18 **실제 사고 발생** — 적재 완료(18:14) 후 04번 재실행(18:59)으로
--           EVENTS 285,676,588행이 삭제됐다. Time Travel 1일 안이라 아래로 복구했다:
--             ALTER SCHEMA GN_DW.BRONZE_BIGQUERY RENAME TO GN_DW.BRONZE_BIGQUERY_04DDL_20260818;
--             UNDROP SCHEMA GN_DW.BRONZE_BIGQUERY;      -- EVENTS 포함 버전 복원
--             DROP SCHEMA   GN_DW.BRONZE_BIGQUERY_04DDL_20260818;   -- 복구본이 상위집합
--           복구 후 7장 (2) 재검증 = 911테이블 285,676,588행 일치, 불일치 0.
--           🔴 Time Travel 은 기본 **1일**이다(SHOW SCHEMAS 의 retention_time). 하루가 지나면
--              복구 불가이고 63.7GB 재적재(약 30~40분 + 크레딧)뿐이다.
--
--        ▣ 올바른 순서 (반드시 이 순서)
--            ① 04번 DDL 전량 실행        ← 스키마·시퀀스·SYNC_ERR_INFO 생성
--            ② 3장 EVENTS DDL · 3-B 뷰 · 3-C 부속 테이블
--            ③ 4장 통제총계 확보 → 6장 적재 → 7장 검증
--          ⇒ ② 이후에는 **04번을 절대 다시 실행하지 않는다.**
--            04번을 다시 돌려야 하는 상황이면 BRONZE_BIGQUERY 블록(1395~1470행 부근)을
--            먼저 주석 처리하거나, 다른 스키마만 골라 실행한다.
--          ⚠️ 같은 위험이 BRONZE_CRM · BRONZE_AGENCY · BRONZE_ERP · ML 에도 있다.
--             04번은 4개 스키마 전부를 `create or replace schema` 한다 ⇒ 적재 후 재실행하면
--             그 스키마들도 전량 삭제된다. 재적재 전 항상 이 절을 먼저 읽을 것.
--
--        ▣ BRONZE_BIGQUERY 블록을 편집해서 빼지는 않는다 (①에서는 그대로 전량 실행)
--          · CREATE SCHEMA BRONZE_BIGQUERY  → 필요하다 (EVENTS 가 들어갈 스키마)
--          · SEQ_SYNC_ERR_INFO · SYNC_ERR_INFO → 필요하다 (운영 오류 로그, EVENTS 와 무관)
--          · "events_20260501"(30컬럼) · "events_20260719"(31컬럼)
--            → EVENTS 로 흡수되므로 적재 대상이 아니다. 그러나 04번을 편집해서 빼는 것보다
--              **그대로 만들어 두고 비워 두는 것**이 낫다. 04번은 A 계정 GET_DDL 실측 정본이고,
--              편집하면 원천 대조 근거가 깨진다. 빈 테이블 2개의 비용은 0이다.
--            ⇒ 정리하고 싶으면 7장 (2) 가 0건이 된 뒤에만 실행한다.
--               -- DROP TABLE IF EXISTS GN_DW.BRONZE_BIGQUERY."events_20260501";
--               -- DROP TABLE IF EXISTS GN_DW.BRONZE_BIGQUERY."events_20260719";
--
--   A-3. 50_handoff/06_데이터마이그 C_CONSUMER.sql — 다음과 같이 나눠 쓴다.
--          A.1 (1)(2)(3)  스테이지 검증        → 그대로 사용 (GA4 포함 전체 대상)
--          A.1 (4)        헤더↔테이블 대조     → 브론즈/ML 용으로만 사용.
--                                               🔴 GA4 는 제외. events_* 는 EVENTS 로
--                                               통합되어 동명 테이블이 없으므로 전량
--                                               TABLE_MISSING 이 된다. → 8장으로 대체.
--          A.2            FF_CSV_LOAD          → 🔴 **본 문서도 이것을 쓴다.** 필수 선행.
--          A.3 · A.4      브론즈 일괄 적재      → 그대로 사용
--          A.5            GA4 개별 COPY        → 🔴 **본 문서로 대체. 실행하지 않는다.**
--                                               단 A.5.3 SYNC_ERR_INFO 는 그대로 필요하다.
--          A.5-B          ML 적재              → 그대로 사용 (또는 부록)
--          A.6 (3)        GA4 JSON 파싱 확인    → 🔴 7장 (4) 로 대체
--          A.6 (1)(2)(4)  행수 대조            → 그대로 사용. 단 BRONZE_BIGQUERY 기대값
--                                               '3테이블 576,441행' 은 **무효**다.
--                                               0장 (5) / 7장 (2) 로 대체한다.


------------------------------------------------------------
-- 10장. 정리(Teardown)
--   ⚠️ 7장 (2) 가 0건이 된 뒤에만 실행한다.
------------------------------------------------------------
-- 스테이지 GA4 구간만 비우기 (브론즈/ML 은 06번 A.7 에서 처리)
-- REMOVE @SANDBOX.TOOLS.MIG_LOAD_STAGE/BRONZE_BIGQUERY/;

-- 🟢 아래는 남겨 두는 것을 권한다 — 재적재·감사·차기 이관의 근거다.
--    V_GA4_EVENTS_DATA_COLS · MIG_GA4_LOAD_LOG · MIG_GA4_SRC_ROWCOUNT · LOAD_GA4_EVENTS
-- DROP FILE FORMAT IF EXISTS SANDBOX.TOOLS.FF_CSV_PEEK;

-- 디렉터리 테이블을 끄면 DIRECTORY() 조회가 실패한다. 재적재 계획이 없을 때만.
-- ALTER STAGE SANDBOX.TOOLS.MIG_LOAD_STAGE SET DIRECTORY = (ENABLE = FALSE);


-- =====================================================================
-- 부록. 범용 동적 로더 — 06번 A.3 / A.5-B 를 하나로 합친다 (선택)
--   06번은 브론즈용 프로시저 1개 + ML용 프로시저 1개 + ML VARIANT 개별 COPY 4개를 쓴다.
--   VARIANT 위치를 사람이 나열하기 때문에 종류마다 코드가 갈렸다.
--   아래 1개는 대상 테이블의 타입에서 VARIANT 를 스스로 판정하므로 스키마를 가리지 않는다.
--   ⚠️ 06번 A.3/A.5-B 는 이미 검증된 경로다. 급하면 그것을 쓰고, 이 부록은 다음 이관부터.
--   ⚠️ 본문과 달리 여기는 TRY_PARSE_JSON 이 아니라 PARSE_JSON 을 쓴다(fail-fast 일관성).
--      ML 원천의 JSON 청결도는 아직 실측하지 않았다. 중단되면 그것이 신호다 —
--      7장 (4) 진단 쿼리를 그 테이블에 맞춰 쓰면 불량 행을 특정할 수 있다.
-- =====================================================================
CREATE OR REPLACE PROCEDURE SANDBOX.TOOLS.LOAD_SCHEMA_DYNAMIC(
  P_SCHEMA STRING, P_TABLE_LIKE STRING, P_DRY_RUN BOOLEAN)
RETURNS TABLE(TARGET_TABLE STRING, N_COLS NUMBER, N_VARIANT NUMBER,
              STATUS STRING, FILES_LOADED NUMBER, ROWS_LOADED NUMBER,
              ERROR_MESSAGE STRING, COPY_SQL STRING)
LANGUAGE SQL
COMMENT = 'GN_DW 임의 스키마를 대상 테이블 타입 기반으로 동적 COPY. VARIANT 는 자동 PARSE_JSON(엄격).'
AS
$$
DECLARE
  v_sql   STRING;
  v_sel   STRING;
  v_tbl   STRING;
  v_nc    NUMBER;
  v_nv    NUMBER;
  v_qid   STRING;
  v_files NUMBER;
  v_rows  NUMBER;
  res     RESULTSET;
  c1 CURSOR FOR
    SELECT table_name FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = ? AND table_type = 'BASE TABLE' AND table_name LIKE ?
    ORDER BY table_name;
BEGIN
  CREATE OR REPLACE TEMPORARY TABLE dyn_log (
    TARGET_TABLE STRING, N_COLS NUMBER, N_VARIANT NUMBER, STATUS STRING,
    FILES_LOADED NUMBER, ROWS_LOADED NUMBER, ERROR_MESSAGE STRING, COPY_SQL STRING);

  -- 식별자 방어. 이 프로시저는 소유자 권한으로 실행되고 P_SCHEMA 를 문자열로 조립한다.
  -- (P_TABLE_LIKE 는 커서 바인드 변수라 조립되지 않으므로 검증 불필요)
  -- ✅ 실측 — CALL ...('ML"; DROP TABLE X; --','%',TRUE) → INVALID_SCHEMA_NAME 반환, 실행 차단
  IF (NOT (P_SCHEMA RLIKE '^[A-Za-z_][A-Za-z0-9_$]*$')) THEN
    INSERT INTO dyn_log
    SELECT 'ABORT', NULL, NULL, 'INVALID_SCHEMA_NAME', NULL, NULL,
           '허용되지 않는 스키마명: ' || :P_SCHEMA, NULL;
    res := (SELECT * FROM dyn_log);
    RETURN TABLE(res);
  END IF;

  OPEN c1 USING (P_SCHEMA, P_TABLE_LIKE);
  LOOP
    v_tbl := NULL;
    FETCH c1 INTO v_tbl;
    IF (v_tbl IS NULL) THEN BREAK; END IF;

    -- 대상 테이블 타입에서 전개식을 만든다. VARIANT/OBJECT/ARRAY → PARSE_JSON.
    SELECT COUNT(*),
           COUNT_IF(data_type IN ('VARIANT','OBJECT','ARRAY')),
           LISTAGG(CASE WHEN data_type IN ('VARIANT','OBJECT','ARRAY')
                        THEN 'PARSE_JSON($' || ordinal_position || ')'
                        ELSE '$' || ordinal_position END, ',')
             WITHIN GROUP (ORDER BY ordinal_position)
      INTO :v_nc, :v_nv, :v_sel
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = :P_SCHEMA AND table_name = :v_tbl;

    -- VARIANT 가 없으면 변환 없는 일반 COPY 가 더 빠르다.
    -- 🟢 이 경로에서는 FF_CSV_LOAD 의 ERROR_ON_COLUMN_COUNT_MISMATCH=TRUE 가 **실제로 작동**한다
    --    (변환 COPY 가 아니므로). 브론즈/ML 의 컬럼 누락 사고를 여기서 잡아준다.
    IF (:v_nv = 0) THEN
      v_sql := 'COPY INTO GN_DW."' || :P_SCHEMA || '"."' || :v_tbl || '" '
            || 'FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/' || :P_SCHEMA || '/' || :v_tbl || '/ '
            || 'FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD) '
            || 'ON_ERROR = ABORT_STATEMENT PURGE = FALSE';
    ELSE
      v_sql := 'COPY INTO GN_DW."' || :P_SCHEMA || '"."' || :v_tbl || '" '
            || 'FROM (SELECT ' || :v_sel
            || ' FROM @SANDBOX.TOOLS.MIG_LOAD_STAGE/' || :P_SCHEMA || '/' || :v_tbl || '/) '
            || 'FILE_FORMAT = (FORMAT_NAME = SANDBOX.TOOLS.FF_CSV_LOAD) '
            || 'ON_ERROR = ABORT_STATEMENT PURGE = FALSE';
    END IF;

    IF (P_DRY_RUN) THEN
      INSERT INTO dyn_log SELECT :v_tbl, :v_nc, :v_nv, 'DRY_RUN', NULL, NULL, NULL, :v_sql;
    ELSE
      BEGIN
        EXECUTE IMMEDIATE :v_sql;
        v_qid := SQLID;
        BEGIN
          SELECT COUNT(*), COALESCE(SUM("rows_loaded"), 0) INTO :v_files, :v_rows
          FROM TABLE(RESULT_SCAN(:v_qid));
        EXCEPTION WHEN OTHER THEN v_files := 0; v_rows := 0;
        END;
        INSERT INTO dyn_log SELECT :v_tbl, :v_nc, :v_nv,
          CASE WHEN :v_files = 0 THEN 'NO_FILES' ELSE 'LOADED' END,
          :v_files, :v_rows, NULL, :v_sql;
      EXCEPTION
        WHEN OTHER THEN
          -- 한 테이블이 실패해도 나머지는 계속한다 (06번 A.3 은 전체가 중단된다).
          INSERT INTO dyn_log SELECT :v_tbl, :v_nc, :v_nv, 'ERROR',
            NULL, NULL, :SQLCODE || ' | ' || :SQLERRM, :v_sql;
      END;
    END IF;
  END LOOP;
  CLOSE c1;

  res := (SELECT * FROM dyn_log ORDER BY TARGET_TABLE);
  RETURN TABLE(res);
END;
$$;

-- 사용 예 — 반드시 DRY_RUN 을 먼저 본다.
-- CALL SANDBOX.TOOLS.LOAD_SCHEMA_DYNAMIC('ML', 'ML_RST_DATA_%', TRUE);
-- CALL SANDBOX.TOOLS.LOAD_SCHEMA_DYNAMIC('ML', 'ML_RST_DATA_%', FALSE);   -- 16종 전부
-- CALL SANDBOX.TOOLS.LOAD_SCHEMA_DYNAMIC('BRONZE_CRM', '%', FALSE);
--
-- ✅ 2026-08-18 DRY_RUN 실측 — CALL ...('ML','ML_RST_DATA_%',TRUE) → 16행 반환.
--    VARIANT 판정이 06번 A.5-B.2 의 수동 목록과 **완전히 일치**했다(독립 재현):
--      ML_RST_DATA_SPNSR_CHURN_12M  18컬럼 · $18
--      ML_RST_DATA_MBER_CHURN_12M   18컬럼 · $18
--      ML_RST_DATA_MBER_INC_12M     21컬럼 · $21
--      ML_RST_DATA_LOYAL_MBER       22컬럼 · $22
--      나머지 12종 → N_VARIANT=0 이므로 변환 없는 일반 COPY 로 생성됨
--    ⇒ 06번의 프로시저 2개 + 개별 COPY 4개를 이 1개가 정확히 대체한다.
--
-- 🔴 BRONZE_BIGQUERY 에는 쓰지 않는다 — events_* 는 EVENTS 통합이므로 폴더/테이블이 1:1 이 아니다.
--    (SYNC_ERR_INFO 만 필요하면 06번 A.5.3 을 쓴다.)

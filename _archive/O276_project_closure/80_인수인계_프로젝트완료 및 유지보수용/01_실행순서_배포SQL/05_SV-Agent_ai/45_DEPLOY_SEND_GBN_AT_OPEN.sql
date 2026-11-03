-- =============================================================================
-- Purpose    : O265 — 알림톡·이메일 발송구분(대/중/소) 배선 · 메시지 형식 · 알림톡 GA 열람(클릭) (기존 환경 갱신)
-- Target     : SILVER.CRM_SEND_REQUEST · GOLD.DIM_SEND_REQUEST · DIM_SEND_TYPE · FACT_MESSAGE_DISPATCH · SERVING.SV_SERVICE
-- Run order  : 기존 환경 갱신 #43 ([D1] → MANUAL: dbt 재배포·build → [D2] → 05_04 SV 재배포 → [D3])
-- Depends on : 44_DEPLOY_CATEGORY_GOLD.sql(#41) 선행 · 06_DDL 2026-10-28 판
-- Issue      : O265 (현업 문의 = 회원서비스기획팀 · 회원참여팀)
-- =============================================================================
-- 왜 이 파일이 필요한가
--   ① 발송구분(대/중/소)이 SILVER 에서 EMAIL·MSG_AT 에 NULL 로 고정돼 있었다(원천에는 SNDNG_CD_ID·SNDNG_DTL_CD_ID 로 있다).
--      ⇒ Agent 가 「ACPI회원발송은 문자에만 있다」고 답했다(이전 계정 BRONZE = 알림톡 1,526 · 이메일 1,044 요청 실재).
--   ② 알림톡은 원천에 오픈 기록이 없다 ⇒ GA URL memnum(=회원번호) + 카카오 경로 유입을 열람으로 대신한다(사용자 결정 = 회원+기간).
--   ③ 문자 시스템(SND)도 알림톡을 보낸다(MSG_TYPE 1 = 템플릿 AT 코드 1,560/2,329) ⇒ 메시지 형식 컬럼을 분리한다.
--   WARN: #160 서비스(명)/#161 은 이메일 MS054 가 들어와 **값이 늘어난다**(사용자 결정 = 전 채널 확대 · 현업 공지 대상).
--   WARN: 06_DDL 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ 데이터 소실 · R2-9). 새 환경은 이 파일이 필요 없다.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 변경 전 기준값 (build 전에 실행 · 결과를 기록한다)
SELECT 'before' AS phase,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)                 AS fmd_rows,
       (SELECT SUM(SERVICE_MEMBERS) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)     AS service_members,
       (SELECT COUNT(*) FROM GN_DW.GOLD.DIM_SEND_TYPE)                         AS send_type_rows,
       (SELECT COUNT_IF(SEND_TYPE_SK <> 0) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH) AS fmd_send_type_mapped;

-- [D1] 열 추가 (dbt build 전) — 맨 끝 · 재실행 무해
ALTER TABLE GN_DW.GOLD.DIM_SEND_REQUEST ADD COLUMN IF NOT EXISTS SEND_FORMAT_NAME VARCHAR
    COMMENT '실제 메시지 형식(알림톡·SMS·LMS·MMS·문자·이메일·우편) (O265). 🔴 채널과 다르다 — SND 시스템도 알림톡을 보낸다.';
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS GA_CLICK_MEMBERS NUMBER(1,0)
    COMMENT '알림톡 링크 클릭(GA 유입) 1/0 [알림톡 전용 · 그 밖 NULL] (O265)';
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS GA_CLICK_TS TIMESTAMP_NTZ
    COMMENT '그 발송에 귀속된 최초 GA 클릭 시각 [알림톡 전용] (O265)';
-- [O265-B-3] B 축 = 수신일~D+5 어떤 알림톡이라도 열람(현업 결정 2026-10-28) · 맨 끝
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS ANY_AT_GA_OPEN_MEMBERS NUMBER(1,0)
    COMMENT '수신일~D+5 어떤 알림톡이라도 열람(GA 유입) 1/0 [알림톡 전용 · 그 밖 NULL] (O265-B-3) · GA_CLICK_MEMBERS ⊆ 이 값';
-- 신규 브리지(회원참여팀 문의 · 사용자 결정 = 브리지 팩트) — 구조 정본 = 06_DDL FACT_COHORT_DISPATCH 블록(IF NOT EXISTS 로 옮김)
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_COHORT_DISPATCH (
    EVENT_MONTH_KEY   NUMBER(6,0)   NOT NULL COMMENT '사건월 YYYYMM ※비강제 FK→FACT_MEMBER_EVENT_COHORT(4열 복합키)',
    MEMBER_DK         VARCHAR       NOT NULL COMMENT '회원 ※비강제 FK→DIM_MEMBER.MEMBER_DK',
    DVLP_DIV_CD       VARCHAR       NOT NULL COMMENT '개발구분 코드(MM015) — 코호트 키',
    MONTHS_AFTER      NUMBER(2,0)   NOT NULL COMMENT '항상 0 — 코호트 복합키 참조용',
    SEND_DATE         DATE          NOT NULL COMMENT '발송일',
    DAYS_FROM_EVENT   NUMBER(3,0)   NOT NULL COMMENT '첫 사건일 대비 발송일(-30~+5)',
    SEND_WINDOW       VARCHAR       NOT NULL COMMENT '구간 라벨 D-30~D-1 · D0 · D+1~D+5',
    SEND_REQUEST_SK   NUMBER(38,0)  NOT NULL COMMENT '발송요청 ※비강제 FK→DIM_SEND_REQUEST',
    SEND_TYPE_SK      NUMBER(38,0)  COMMENT '발송구분(대/중/소) ※비강제 FK→DIM_SEND_TYPE',
    SEND_CHANNEL      VARCHAR       COMMENT '발송 채널(MSG_AT·SND·EMAIL)',
    SEND_FORMAT_NAME  VARCHAR       COMMENT '실제 메시지 형식 — 채널과 다르다',
    ATMC_YN           VARCHAR(1)    COMMENT '알림톡 템플릿 자동발송 여부',
    SEND_TITLE        VARCHAR       COMMENT '발송 제목',
    SEND_ROWS         NUMBER(18,0)  COMMENT '같은 (회원, 요청, 발송일)의 원 발송 행 수',
    SND_OPENED        NUMBER(1,0)   COMMENT '문자 링크 클릭 1/0 · 판정 불가 NULL',
    GA_CLICKED        NUMBER(1,0)   COMMENT '알림톡 GA 유입 1/0 · 비알림톡·GA 범위 밖 NULL',
    DW_SOURCE_SYSTEM  VARCHAR       NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS        TIMESTAMP_NTZ NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS      TIMESTAMP_NTZ COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID       VARCHAR       COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) CLUSTER BY (EVENT_MONTH_KEY, DVLP_DIV_CD)
  COMMENT = '개발사건 코호트 × 사건 전후 발송 브리지(O265). [Grain: 사건월 × 회원 × 개발구분 × 발송요청 × 발송일]. 창 = 첫 사건일 D-30~D+5.';
-- [O265-B-3] 브리지 B 축 — 테이블이 이미 있든 방금 만들었든 같은 위치(감사 4컬럼 뒤 맨 끝) · 재실행 무해
ALTER TABLE GN_DW.GOLD.FACT_COHORT_DISPATCH ADD COLUMN IF NOT EXISTS ANY_AT_GA_OPENED NUMBER(1,0)
    COMMENT '수신일~D+5 어떤 알림톡이라도 열람 1/0(O265-B-3) · GA_CLICKED ⊆ 이 값 · 비알림톡·GA 범위 밖 NULL';

-- [D1-C] [O265-C] A 우선순위(① 질문 시 템플릿 > ② 고정 매핑 > ③ 추정) — 신규 seed 1 · GOLD 2 · FMD 1열 · 재실행 무해
--   구조 정본 = 08 SILVER DDL MAP_AT_GA_LINK 블록 · 06_DDL FACT_AT_GA_LINK_MAP·FACT_AT_GA_CLICK 블록(IF NOT EXISTS 로 옮김)
--   WARN: 06_DDL·08 SILVER DDL **전체 실행 금지**(CREATE OR REPLACE · TRUNCATE 로 기존 적재가 사라진다)
CREATE TABLE IF NOT EXISTS GN_DW.SILVER.MAP_AT_GA_LINK (
    TEMPLATE_ID VARCHAR, MATCH_TYPE VARCHAR, MATCH_VALUE VARCHAR, MAP_SRC VARCHAR,
    CONFIRMED_BY VARCHAR, CONFIRMED_DT VARCHAR, NOTE VARCHAR
) COMMENT = '알림톡 템플릿 → GA 최종 랜딩 패턴 고정 매핑(O265-C). [Grain: 템플릿 × 패턴]. [원천: 10_dbt_pipeline/seeds/MAP_AT_GA_LINK.csv].';
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_AT_GA_LINK_MAP (
    TEMPLATE_ID VARCHAR NOT NULL, MATCH_PATTERN VARCHAR NOT NULL, MAP_SRC VARCHAR NOT NULL,
    MAP_PRIORITY NUMBER(1,0) NOT NULL, RECV_CLICK_MEMBERS NUMBER(18,0), ALL_CLICK_MEMBERS NUMBER(18,0),
    DW_SOURCE_SYSTEM VARCHAR NOT NULL, DW_LOAD_TS TIMESTAMP_NTZ NOT NULL, DW_UPDATE_TS TIMESTAMP_NTZ, DW_BATCH_ID VARCHAR
) COMMENT = '알림톡 템플릿 → GA 최종 랜딩 패턴 매핑(O265-C). [Grain: TEMPLATE_ID × MATCH_PATTERN]. 컬럼 주석 정본 = 06_DDL.';
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_AT_GA_CLICK (
    DATE_SK NUMBER(8,0) NOT NULL, MEMBER_DK VARCHAR NOT NULL, SEND_REQUEST_SK NUMBER(38,0) NOT NULL,
    SEND_CHANNEL VARCHAR NOT NULL, TEMPLATE_ID VARCHAR, SEND_TS TIMESTAMP_NTZ, CLICK_TS TIMESTAMP_NTZ,
    DAYS_FROM_SEND NUMBER(3,0), LANDING_PATH VARCHAR, UTM_CAMPAIGN VARCHAR, UTM_CONTENT VARCHAR,
    MAP_SRC VARCHAR, MAP_MATCHED NUMBER(1,0),
    DW_SOURCE_SYSTEM VARCHAR NOT NULL, DW_LOAD_TS TIMESTAMP_NTZ NOT NULL, DW_UPDATE_TS TIMESTAMP_NTZ, DW_BATCH_ID VARCHAR
) CLUSTER BY (DATE_SK)
  COMMENT = '알림톡 수신 후 D+5 카카오 경로 GA 클릭 팩트(O265-C). [Grain: 발송요청 × 채널 × 회원 × 클릭 시각 × 랜딩]. 컬럼 주석 정본 = 06_DDL.';
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS GA_CLICK_MAP_SRC VARCHAR
    COMMENT 'A(GA_CLICK_MEMBERS) 판정 근거 = 템플릿 매핑 출처 MANUAL·WEB_TEAM·DIRECT·INFER · 매핑 없음 NONE(A=NULL) · 비알림톡 NULL (O265-C)';
-- MANUAL: [D1-C 다음] dbt 재배포 후(에이전트는 실행하지 않는다)
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='seed --select MAP_AT_GA_LINK';
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select MAP_AT_GA_LINK+';
--    MAP_AT_GA_LINK+ = FACT_AT_GA_LINK_MAP → FACT_AT_GA_CLICK → FACT_MESSAGE_DISPATCH → FACT_COHORT_DISPATCH 를 모두 덮는다

-- MANUAL: [D1 다음] dbt 재배포 후 build (에이전트는 실행하지 않는다 · R4-1)
--   /10_dbt_pipeline/01_deploy_dbt_project.sql 로 재배포 →
--   build --select CRM_SEND_REQUEST+
--    FACT_COHORT_DISPATCH 는 FACT_MESSAGE_DISPATCH 하류라 위 선택에 포함된다(신규 모델 · 첫 build).
--    --full-refresh 불요 — SILVER = TRUNCATE+재적재 · FMD = gold_fact_purge · DIM 2종 = merge(is_incremental 필터 없음)

-- [D2-0] 브리지 대사 — 기대값(개발 환경 이전 계정 실측 · 2026-10-28 · 첫 build 후)
--   cdp_rows 2,538,548 · dup_keys 0 · orphan_cohort 0 · windows 3 · send_type_mapped 2,538,548 · GA_CLICKED 합 1,668 · ANY_AT_GA_OPENED 합 2,187
--   WARN: 운영계는 행수가 다를 수 있다 — 등식(중복 0 · 고아 0 · 구간 3)으로 판정한다
--   판정식 = 키 중복 0 · 코호트 고아 0 · 브리지 회원 ⊆ 코호트 MONTHS_AFTER=0 회원 · 구간 3종
SELECT COUNT(*)                                                                                  AS cdp_rows,
       COUNT(*) - COUNT(DISTINCT c.EVENT_MONTH_KEY, c.MEMBER_DK, c.DVLP_DIV_CD, c.SEND_REQUEST_SK, c.SEND_DATE) AS dup_keys,
       COUNT_IF(m.MEMBER_DK IS NULL)                                                             AS orphan_cohort,
       COUNT(DISTINCT c.SEND_WINDOW)                                                             AS windows,
       COUNT_IF(c.SEND_TYPE_SK <> 0)                                                             AS send_type_mapped
FROM GN_DW.GOLD.FACT_COHORT_DISPATCH c
LEFT JOIN GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT m
  ON m.MEMBER_DK = c.MEMBER_DK AND m.EVENT_MONTH_KEY = c.EVENT_MONTH_KEY
 AND m.DVLP_DIV_CD = c.DVLP_DIV_CD AND m.MONTHS_AFTER = c.MONTHS_AFTER;

-- [D2] 대사 — 기대값(이전 계정 BRONZE 실측 · 2026-10-28)
--   fmd_rows 불변 = 44,626,415 · 채널별 대분류 채움 100%(EMAIL 546,420 · MSG_AT 1,256,998 요청) · 우편 0
--   GA_CLICK_MEMBERS 합 = MSG_AT 8,524 · SND 7,610 (GA 적재가 늘면 증가)
--    [2026-10-28 첫 build 후 실측 · 같은 개발 환경 · 원천 재적재로 행수 증가] fmd_rows 44,652,641 · 대분류 채움 100%
--     (EMAIL 548,203 · MSG_AT 1,262,622 · SND 2,347 요청 · 우편 0) · GA_CLICK_MEMBERS 합 MSG_AT 8,559 · SND 4,893
--     · ANY_AT_GA_OPEN_MEMBERS 합 MSG_AT 10,019 · SND 4,925 · A ⊆ B 위반 0 · 비알림톡 GA 컬럼 전부 NULL
--     NOTE: SND 는 사전 측정 7,610 대비 4,893 — 사전값은 build 전 SILVER 시뮬레이션이다 · 차이 원인 미규명(후속 대조 대상)
--      [O266-C 규명] 사전값 = O265-A 규칙(SND **전체 발송**에 귀속) · 실측 = O265-B 결정(SND **알림톡만** · MSG_TYPE '1').
--        재시뮬(ZS83821 · 같은 GA) = SND 전체 7,967 · SND 알림톡만 4,901(실측 4,893 과 8 차 = 귀속 tie-break) ⇒ 결함 아님 · 정의 변경분
SELECT 'after' AS phase,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)                 AS fmd_rows,
       (SELECT SUM(SERVICE_MEMBERS) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)     AS service_members,
       (SELECT COUNT(*) FROM GN_DW.GOLD.DIM_SEND_TYPE)                         AS send_type_rows,
       (SELECT COUNT_IF(SEND_TYPE_SK <> 0) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH) AS fmd_send_type_mapped;

SELECT SEND_CHANNEL,
       COUNT(*)                  AS req_rows,
       COUNT(SEND_GBN_TOP)       AS top_filled,
       COUNT(SEND_GBN_TOP_NM)    AS top_label,
       COUNT(SEND_GBN_BOT_NM)    AS bot_label,
       COUNT_IF(SEND_GBN_MID_NM = 'ACPI회원발송') AS acpi_req
FROM GN_DW.SILVER.CRM_SEND_REQUEST
GROUP BY 1 ORDER BY 1;

SELECT r.SEND_CHANNEL, r.SEND_FORMAT_NAME,
       COUNT(*)                     AS fmd_rows,
       COUNT(f.GA_CLICK_MEMBERS)    AS ga_in_scope,
       SUM(f.GA_CLICK_MEMBERS)      AS ga_clicked
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH f
LEFT JOIN GN_DW.GOLD.DIM_SEND_REQUEST r ON r.SEND_REQUEST_SK = f.SEND_REQUEST_SK
GROUP BY 1, 2 ORDER BY 1, 2;

-- [D2-1] 알림톡 열람 2축 대사(O265-B-3) — 기대값(개발 환경 이전 계정 실측 · 2026-10-28)
--   행운의 카드 알림톡: 수신 27,881명(MSG_AT 19,285 · SND 8,646) · A 22 · B 22 · a_not_b 0 · 중단 A 0 · B 0
--   WARN: 개발 환경는 샘플링이라 표본이 작다 — 운영계는 등식(a_not_b 0 · B ≥ A)으로 판정한다
--   판정식 = a_not_b 0(A ⊆ B) · b_members ≥ a_members · NULL 행 수 두 축 동일
--   A = 그 알림톡 열람(GA_CLICK_MEMBERS) · B = 수신일~D+5 어떤 알림톡이라도 열람(ANY_AT_GA_OPEN_MEMBERS)
--   중단 = D5_STOP_MEMBERS(발송 다음날~D+5 중단 · 처리통보성 제목 제외 = 기존 #139~#146 규칙)
--    운영계 표본 확인용으로 그대로 쓴다 — 제목 조건만 바꾸면 다른 알림톡도 같은 판정식
SELECT r.SEND_CHANNEL,
       COUNT(f.GA_CLICK_MEMBERS)                                             AS in_scope_rows,
       COUNT(f.ANY_AT_GA_OPEN_MEMBERS)                                       AS in_scope_rows_b,
       COUNT_IF(f.GA_CLICK_MEMBERS = 1 AND COALESCE(f.ANY_AT_GA_OPEN_MEMBERS, 0) = 0) AS a_not_b,
       COUNT(DISTINCT f.MEMBER_DK)                                           AS recv_members,
       COUNT(DISTINCT IFF(f.GA_CLICK_MEMBERS = 1, f.MEMBER_DK, NULL))        AS a_members,
       COUNT(DISTINCT IFF(f.ANY_AT_GA_OPEN_MEMBERS = 1, f.MEMBER_DK, NULL))  AS b_members,
       COUNT(DISTINCT IFF(f.GA_CLICK_MEMBERS = 1 AND f.D5_STOP_MEMBERS = 1, f.MEMBER_DK, NULL))       AS a_stop_d5,
       COUNT(DISTINCT IFF(f.ANY_AT_GA_OPEN_MEMBERS = 1 AND f.D5_STOP_MEMBERS = 1, f.MEMBER_DK, NULL)) AS b_stop_d5
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH f
JOIN GN_DW.GOLD.DIM_SEND_REQUEST r ON r.SEND_REQUEST_SK = f.SEND_REQUEST_SK
WHERE r.SEND_FORMAT_NAME = '알림톡'
  AND f.SEND_TITLE ILIKE '%행운의%카드%'
GROUP BY ROLLUP (r.SEND_CHANNEL)
ORDER BY 1;

-- [D2-2] [O265-C] A 우선순위 대사 — 사전 기대값(build 전 모델 렌더 실측 · 2026-10-28)
--   매핑 템플릿 MANUAL 4 · DIRECT 2,500 · INFER 66 · 템플릿당 출처 1(mixed 0) · 패턴 중복 0
--   클릭 108,107행 · (발송, 회원) 14,992 · 판정 가능 10,750 · A 8,236 · 행운의 카드 A 9 / B 22(종전 A 22 = 타 캠페인 혼입)
--    [O266-C 실측 · build 후] FMD A 합 = 8,220 = 8,236 − 16 · 16쌍 = GA 적재 시작(2024-01-16) 직전 발송(2024-01-12~15)
--      ⇒ FMD 는 「창 일부만 관측 = 판정 불가 NULL」(R2-7) · FACT_AT_GA_CLICK 은 관측된 클릭을 남긴다 · 결함 아님(경계 정의 차)
--   판정식 = mixed_src 0 · FMD a_not_b 0 · FMD A NULL 행 = GA_CLICK_MAP_SRC 'NONE' 행(알림톡 · GA 범위 안)
SELECT MAP_SRC, COUNT(DISTINCT TEMPLATE_ID) AS templates, COUNT(*) AS patterns,
       (SELECT COUNT(*) FROM (SELECT TEMPLATE_ID FROM GN_DW.GOLD.FACT_AT_GA_LINK_MAP
                              GROUP BY 1 HAVING COUNT(DISTINCT MAP_SRC) > 1)) AS mixed_src
FROM GN_DW.GOLD.FACT_AT_GA_LINK_MAP GROUP BY 1 ORDER BY 1;

SELECT COALESCE(GA_CLICK_MAP_SRC, '(비알림톡)') AS map_src,
       COUNT(*)                                                         AS fmd_rows,
       COUNT(GA_CLICK_MEMBERS)                                          AS a_judged,
       SUM(GA_CLICK_MEMBERS)                                            AS a_sum,
       SUM(ANY_AT_GA_OPEN_MEMBERS)                                      AS b_sum,
       COUNT_IF(GA_CLICK_MEMBERS = 1 AND COALESCE(ANY_AT_GA_OPEN_MEMBERS, 0) = 0) AS a_not_b
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
GROUP BY 1 ORDER BY 1;

-- MANUAL: [D2 다음] 05_04_SV_DDL_SERVICE.sql 재배포(SV_SERVICE) · 05_28_SV_DDL_MEMBER_EVENT_COHORT.sql 재배포(브리지·발송구분 배선)

-- [D3] SV 반영 확인 — 새 차원·지표 4종 실재 · 「문자 요청 전용」 문구 잔존 0
SELECT NAME, LEFT(COMMENT, 60) AS comment_head
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
WHERE SEMANTIC_VIEW_NAME = 'SV_SERVICE'
  AND NAME IN ('REQ_SEND_GBN_TOP_NM', 'REQ_SEND_GBN_MID_NM', 'REQ_SEND_GBN_BOT_NM', 'REQ_SEND_FORMAT_NAME', 'GA_CLICK_TS')
UNION ALL
SELECT NAME, LEFT(COMMENT, 60)
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS
WHERE SEMANTIC_VIEW_NAME = 'SV_SERVICE'
  AND NAME IN ('AT_GA_CLICK_MEMBERS_DISTINCT', 'AT_GA_CLICK_RATE', 'AT_ANY_GA_OPEN_MEMBERS_DISTINCT')
ORDER BY 1;

-- =============================================================================
-- Purpose    : O265 — 알림톡·이메일 발송구분(대/중/소) 배선 · 메시지 형식 · 알림톡 GA 열람(클릭) (기존 환경 갱신)
-- Target     : SILVER.CRM_SEND_REQUEST · GOLD.DIM_SEND_REQUEST · DIM_SEND_TYPE · FACT_MESSAGE_DISPATCH · SERVING.SV_SERVICE
-- Run order  : 기존 환경 갱신 #43 ([D1] → 👤 dbt 재배포·build → [D2] → 05_04 SV 재배포 → [D3])
-- Depends on : 44_DEPLOY_CATEGORY_GOLD.sql(#41) 선행 · 06_DDL 2026-10-28 판
-- Issue      : O265 (현업 문의 = 회원서비스기획팀 · 회원참여팀)
-- =============================================================================
-- 왜 이 파일이 필요한가
--   ① 발송구분(대/중/소)이 SILVER 에서 EMAIL·MSG_AT 에 NULL 로 고정돼 있었다(원천에는 SNDNG_CD_ID·SNDNG_DTL_CD_ID 로 있다).
--      ⇒ Agent 가 「ACPI회원발송은 문자에만 있다」고 답했다(UM80684 BRONZE = 알림톡 1,526 · 이메일 1,044 요청 실재).
--   ② 알림톡은 원천에 오픈 기록이 없다 ⇒ GA URL memnum(=회원번호) + 카카오 경로 유입을 열람으로 대신한다(사용자 결정 = 회원+기간).
--   ③ 문자 시스템(SND)도 알림톡을 보낸다(MSG_TYPE 1 = 템플릿 AT 코드 1,560/2,329) ⇒ 메시지 형식 컬럼을 분리한다.
--   🔴 #160 서비스(명)/#161 은 이메일 MS054 가 들어와 **값이 늘어난다**(사용자 결정 = 전 채널 확대 · 현업 공지 대상).
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

-- 👤 [D1 다음] dbt 재배포 후 build (에이전트는 실행하지 않는다 · R4-1)
--   /10_dbt_pipeline/01_deploy_dbt_project.sql 로 재배포 →
--   build --select CRM_SEND_REQUEST+
--   🟢 FACT_COHORT_DISPATCH 는 FACT_MESSAGE_DISPATCH 하류라 위 선택에 포함된다(신규 모델 · 첫 build).
--   🟢 --full-refresh 불요 — SILVER = TRUNCATE+재적재 · FMD = gold_fact_purge · DIM 2종 = merge(is_incremental 필터 없음)

-- [D2-0] 브리지 대사 — 🔴 기대값 미실측(개발계 계정 정지로 O265 에서 측정 불가 · 첫 build 후 기록)
--   판정식 = 키 중복 0 · 코호트 고아 0 · 브리지 회원 ⊆ 코호트 MONTHS_AFTER=0 회원 · 구간 3종
SELECT COUNT(*)                                                                                  AS cdp_rows,
       COUNT(*) - COUNT(DISTINCT EVENT_MONTH_KEY, MEMBER_DK, DVLP_DIV_CD, SEND_REQUEST_SK, SEND_DATE) AS dup_keys,
       COUNT_IF(m.MEMBER_DK IS NULL)                                                             AS orphan_cohort,
       COUNT(DISTINCT c.SEND_WINDOW)                                                             AS windows,
       COUNT_IF(c.SEND_TYPE_SK <> 0)                                                             AS send_type_mapped
FROM GN_DW.GOLD.FACT_COHORT_DISPATCH c
LEFT JOIN GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT m
  ON m.MEMBER_DK = c.MEMBER_DK AND m.EVENT_MONTH_KEY = c.EVENT_MONTH_KEY
 AND m.DVLP_DIV_CD = c.DVLP_DIV_CD AND m.MONTHS_AFTER = c.MONTHS_AFTER;

-- [D2] 대사 — 기대값(UM80684 BRONZE 실측 · 2026-10-28)
--   fmd_rows 불변 = 44,626,415 · 채널별 대분류 채움 100%(EMAIL 546,420 · MSG_AT 1,256,998 요청) · 우편 0
--   GA_CLICK_MEMBERS 합 = MSG_AT 8,524 · SND 7,610 (GA 적재가 늘면 증가)
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

-- 👤 [D2 다음] 05_04_SV_DDL_SERVICE.sql 재배포(SV_SERVICE) · 05_28_SV_DDL_MEMBER_EVENT_COHORT.sql 재배포(브리지·발송구분 배선)

-- [D3] SV 반영 확인 — 새 차원·지표 4종 실재 · 「문자 요청 전용」 문구 잔존 0
SELECT NAME, LEFT(COMMENT, 60) AS comment_head
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
WHERE SEMANTIC_VIEW_NAME = 'SV_SERVICE'
  AND NAME IN ('REQ_SEND_GBN_TOP_NM', 'REQ_SEND_GBN_MID_NM', 'REQ_SEND_GBN_BOT_NM', 'REQ_SEND_FORMAT_NAME', 'GA_CLICK_TS')
UNION ALL
SELECT NAME, LEFT(COMMENT, 60)
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS
WHERE SEMANTIC_VIEW_NAME = 'SV_SERVICE'
  AND NAME IN ('AT_GA_CLICK_MEMBERS_DISTINCT', 'AT_GA_CLICK_RATE')
ORDER BY 1;

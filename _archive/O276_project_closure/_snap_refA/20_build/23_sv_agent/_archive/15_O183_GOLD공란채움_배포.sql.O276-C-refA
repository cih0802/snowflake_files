-- GN_DW O183 — GOLD 공란 컬럼 배선 후속 배포 (dbt build 이후 실행)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 선행 = 사용자 실행 `dbt build` (R4-1 · 에이전트는 실행하지 않는다)
--     대상 모델 = FACT_MEMBER_EVENT → FACT_MEMBER_MONTHLY → FACT_MESSAGE_DISPATCH · FACT_EVENT_ATTENDANCE
-- ▶ 규칙 정본 = 20_issue/30_설계_의사결정_조각/30_설계_의사결정-016.md DEC-55
-- ▶ 순서 = [1] 채움 재계측 → [2] 컬럼 COMMENT → [3] SV 4종 → [4] Agent 버전업 → [5] 스모크
-- 🔴 [1] 에서 대상 컬럼이 여전히 0 이면 [2] 이후를 진행하지 않는다(빌드 누락 · R2-8-4).
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [1] 채움 재계측 — 모든 값이 0 보다 커야 한다(행수는 계정·시점마다 다르므로 절대값을 기대하지 않는다)
SELECT
    COUNT_IF(UNPAID_CNT <> 0)          AS unpaid_cnt,
    COUNT(ACTIVE_CUM_CNT)              AS active_cum_cnt,
    COUNT_IF(INCREASE_CNT <> 0)        AS increase_cnt,
    COUNT_IF(DECREASE_CNT <> 0)        AS decrease_cnt,
    COUNT_IF(CHURN_CNT <> 0)           AS churn_cnt,
    COUNT_IF(STATUS_UNPAID_CNT <> 0)   AS status_unpaid_cnt,
    COUNT(DEV_TYPE)                    AS dev_type,
    COUNT_IF(INCREASE_FLAG)            AS increase_flag,
    COUNT_IF(REDONATE_FLAG)            AS redonate_flag,
    COUNT(JOIN_DATE)                   AS join_date,
    COUNT(STOP_DATE)                   AS stop_date,
    COUNT(AMOUNT_BAND1)                AS amount_band1,
    COUNT(PERIOD_BAND2)                AS period_band2,
    COUNT_IF(PAID_MONTHS > 0)          AS paid_months,
    COUNT(NEW_EXISTING_FLAG)           AS new_existing
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;

SELECT COUNT(NEW_EXISTING_FLAG) AS fme_new_existing
FROM GN_DW.GOLD.FACT_MEMBER_EVENT;

SELECT
    SUM(D5_LETTER_PART_MEMBERS)   AS d5_letter,
    SUM(D5_GIFT_PART_MEMBERS)     AS d5_gift,
    SUM(D5_INCREASE_PART_MEMBERS) AS d5_increase,
    SUM(D5_STOP_MEMBERS)          AS d5_stop,
    SUM(SERVICE_MEMBERS)          AS service_members
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH;

SELECT
    SUM(CONFIRM_CNT)          AS confirm_cnt,
    MAX(PARTICIPATION_TIMES)  AS max_part_times,
    MAX(CUM_APPLY_TIMES)      AS max_cum_apply
FROM GN_DW.GOLD.FACT_EVENT_ATTENDANCE;

-- fan-out 0 불변식 — 행수가 build 전과 같아야 한다(FMM 월×회원 유일)
SELECT COUNT(*) AS n, COUNT(DISTINCT MONTH_KEY, MEMBER_DK) AS n_key
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;
--   판정: n == n_key

-- [2] 컬럼 COMMENT — 정본 = 03_top-down_gold/06_DDL.sql (O183 수정분과 같은 문안)
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY ALTER COLUMN
    ACTIVE_CUM_CNT    COMMENT '활동누계(건) (#159). 당해년도 1월~조회월 활동(건) 누계.',
    DEV_TYPE          COMMENT '개발구분 (#121). 그 달 개발구분이 하나로 확정될 때만 값. 코드id:MM015.',
    NEW_FLAG          COMMENT '신규 (#32). 최초가입 연도 = 조회년도.',
    INCREASE_FLAG     COMMENT '증액 (#33). 그 달 증액 개발 사건 존재.',
    REDONATE_FLAG     COMMENT '재후원 (#34). 그 달 재후원 개발 사건 존재.',
    JOIN_DATE         COMMENT '최초가입일 (#28) = LEAST(회원 등록일, 최초 개발일, 첫 청구월). 가입 전 월은 NULL.',
    STOP_DATE         COMMENT '최종중단일 as-of (#30). 조회월까지의 최대 중단일.',
    AMOUNT_BAND1      COMMENT '후원금액대1 5만 (#72). 약정 없음 NULL.',
    AMOUNT_BAND2      COMMENT '후원금액대2 1만 (#73). 약정 없음 NULL.',
    PERIOD_BAND1      COMMENT '후원기간대1 5년 (#74). 기준일 없음 NULL.',
    PERIOD_BAND2      COMMENT '후원기간대2 1년 (#75). 기준일 없음 NULL.',
    NEW_EXISTING_FLAG COMMENT '신규/기존 구분 (#113). 기준일 없음 NULL.';

ALTER TABLE GN_DW.GOLD.FACT_MEMBER_EVENT ALTER COLUMN
    NEW_EXISTING_FLAG COMMENT '신규기존 (#113). 사건연도 = 최초가입연도 신규. 기준일 없음 NULL.';

-- [3] SV 4종 — 각 파일을 **통째로** 실행한다(CREATE OR ALTER · GRANT 보존)
--   05_SV-Agent_ai/05_1_SV_DDL_MEMBER_MONTHLY.sql
--   05_SV-Agent_ai/05_2_SV_DDL_MEMBER_EVENT.sql
--   05_SV-Agent_ai/05_4_SV_DDL_SERVICE.sql
--   05_SV-Agent_ai/05_5_SV_DDL_EVENT_PARTICIPATION.sql
--   🟢 사전 컴파일 = O183 이 4종을 임시 이름으로 생성·DESCRIBE·DROP 해 통과 확인(2026-09-28 · xf98254)

-- [4] Agent — AGENT_MEMBER 만 사양이 바뀌었다(cortex_project/agents/AGENT_MEMBER/agent_spec.yaml)
--   절차 정본 = 05_SV-Agent_ai/09_2_AGENT_버전업.sql 의 [1] stage 복사 → [2] live 소진 → [3] ADD VERSION
--   (AGENT_MEMBER 블록만 실행 · EXECUTIVE·MARKETING 은 변경 없음)

-- [5] 스모크 — SV 집계 == 팩트 직접 집계
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT (SELECT UNPAID_CNT_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS UNPAID_CNT_SUM)) AS sv_val,
       (SELECT SUM(UNPAID_CNT) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY)                                      AS fact_val;
SELECT (SELECT D5_STOP_MEMBERS_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS D5_STOP_MEMBERS_SUM)) AS sv_val,
       (SELECT SUM(D5_STOP_MEMBERS) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)                                   AS fact_val;
--   판정: sv_val == fact_val

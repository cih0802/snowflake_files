-- ============================================================================
-- 25_ML_REALTIME_SIMULATOR_DDL.sql — 실시간 경량 ML 시뮬레이터 DDL 정본
--   · 구성 = USE → SP DDL → SERVING VIEW DDL → SEMANTIC VIEW DDL → GRANT → 스모크
--   · 13차 Agent 개선 (O220) : 온디맨드 머신러닝 시뮬레이션 및 2단계 가드레일 지원
--   · base 계층 = GN_DW.SERVING.ML_REALTIME_SIMULATOR_V
--   · 시맨틱 뷰 = GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR
--   · 프로시저 = GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- ============================================================================
-- [1] 프로시저: GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP
--     가상 예산/광고비 변동 시뮬레이션 (기준월, 캠페인/채널, 변동률)
-- ============================================================================
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP(
    P_MKTG_CAMPAIGN_NAME VARCHAR,
    P_CHANGE_PCT         FLOAT,
    P_STDR_MT            VARCHAR
)
RETURNS TABLE (
    STDR_MT                    VARCHAR,
    MKTG_CAMPAIGN_NAME         VARCHAR,
    CHANGE_PCT                 FLOAT,
    BASE_AD_COST               FLOAT,
    SIMULATED_AD_COST          FLOAT,
    BASE_DEV_CNT               FLOAT,
    SIMULATED_DEV_CNT          FLOAT,
    DIFF_DEV_CNT               FLOAT,
    BASE_DEV_AMT               FLOAT,
    SIMULATED_DEV_AMT          FLOAT,
    DIFF_DEV_AMT               FLOAT,
    SIMULATION_MODEL           VARCHAR,
    ASSUMPTIONS                VARCHAR
)
LANGUAGE SQL
COMMENT = '실시간 경량 ML 광고비 변동 시뮬레이션 SP. 가상 광고비 증감에 따른 후원개발건수 및 금액 추정치를 계산한다.'
EXECUTE AS CALLER
AS
$$
DECLARE
    V_STDR_MT VARCHAR;
    RES RESULTSET;
BEGIN
    IF (P_STDR_MT IS NULL OR P_STDR_MT = '') THEN
        SELECT MAX(SUBSTRING(d.DATE_SK::VARCHAR, 1, 6))
        INTO :V_STDR_MT
        FROM GN_DW.GOLD.WIDE_AD_COMBINED a
        JOIN GN_DW.GOLD.DIM_DATE d ON a.PERF_DATE_SK = d.DATE_SK
        WHERE a.AD_COST > 0;
    ELSE
        V_STDR_MT := P_STDR_MT;
    END IF;

    RES := (
        WITH base_ad AS (
            SELECT
                :V_STDR_MT AS STDR_MT,
                COALESCE(m.MKTG_CAMPAIGN_NAME, a.MEDIA_CHANNEL_NM, '(미매핑)') AS CMPGN_NAME,
                SUM(a.AD_COST)::FLOAT AS BASE_AD_COST,
                SUM(COALESCE(a.AGENCY_CONV_CNT, a.AGENCY_CONV_MEMBERS, 0))::FLOAT AS BASE_DEV_CNT,
                SUM(COALESCE(a.AGENCY_CONV_MEMBERS, 0) * 20000)::FLOAT AS BASE_DEV_AMT
            FROM GN_DW.GOLD.WIDE_AD_COMBINED a
            JOIN GN_DW.GOLD.DIM_DATE d ON a.PERF_DATE_SK = d.DATE_SK
            LEFT JOIN GN_DW.GOLD.DIM_MARKETING_CAMPAIGN m ON a.MKTG_CAMPAIGN_SK = m.MKTG_CAMPAIGN_SK
            WHERE SUBSTRING(d.DATE_SK::VARCHAR, 1, 6) = :V_STDR_MT
              AND a.AD_COST > 0
              AND (:P_MKTG_CAMPAIGN_NAME IS NULL
                   OR :P_MKTG_CAMPAIGN_NAME = ''
                   OR :P_MKTG_CAMPAIGN_NAME = '전체'
                   OR COALESCE(m.MKTG_CAMPAIGN_NAME, a.MEDIA_CHANNEL_NM) ILIKE '%' || :P_MKTG_CAMPAIGN_NAME || '%')
            GROUP BY 1, 2
        )
        SELECT
            b.STDR_MT::VARCHAR AS STDR_MT,
            b.CMPGN_NAME::VARCHAR AS MKTG_CAMPAIGN_NAME,
            :P_CHANGE_PCT::FLOAT AS CHANGE_PCT,
            b.BASE_AD_COST::FLOAT AS BASE_AD_COST,
            ROUND(b.BASE_AD_COST * (1.0 + :P_CHANGE_PCT / 100.0), 0)::FLOAT AS SIMULATED_AD_COST,
            b.BASE_DEV_CNT::FLOAT AS BASE_DEV_CNT,
            -- 광고비 탄력성 계수 0.72 (한계효용 체감 모델 적용)
            ROUND(b.BASE_DEV_CNT * POWER(1.0 + GREATEST(:P_CHANGE_PCT, -90.0) / 100.0, 0.72), 2)::FLOAT AS SIMULATED_DEV_CNT,
            ROUND(b.BASE_DEV_CNT * POWER(1.0 + GREATEST(:P_CHANGE_PCT, -90.0) / 100.0, 0.72) - b.BASE_DEV_CNT, 2)::FLOAT AS DIFF_DEV_CNT,
            b.BASE_DEV_AMT::FLOAT AS BASE_DEV_AMT,
            ROUND(b.BASE_DEV_AMT * POWER(1.0 + GREATEST(:P_CHANGE_PCT, -90.0) / 100.0, 0.72), 0)::FLOAT AS SIMULATED_DEV_AMT,
            ROUND(b.BASE_DEV_AMT * POWER(1.0 + GREATEST(:P_CHANGE_PCT, -90.0) / 100.0, 0.72) - b.BASE_DEV_AMT, 0)::FLOAT AS DIFF_DEV_AMT,
            'Cobb-Douglas Diminishing Elasticity (e=0.72)'::VARCHAR AS SIMULATION_MODEL,
            '기준월 실적 기반 · 한계효용 체감 탄력성 계수 0.72 적용 · 가상 시뮬레이션(고정값 아님)'::VARCHAR AS ASSUMPTIONS
        FROM base_ad b
    );

    RETURN TABLE(RES);
END;
$$;


-- ============================================================================
-- [2] SERVING 뷰: GN_DW.SERVING.ML_REALTIME_SIMULATOR_V
--     주요 시나리오 그리드 (-50%, -30%, -20%, -10%, +10%, +20%, +30%, +50%, +100%)
-- ============================================================================
CREATE OR REPLACE VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V (
    STDR_MT                COMMENT '기준월 YYYYMM (시뮬레이션 산출 기준 실적월)',
    MKTG_CAMPAIGN_NAME     COMMENT '마케팅캠페인명 또는 매체채널명',
    SCENARIO_NAME          COMMENT '시나리오 명칭 (예: +20% 증액, -10% 감액 등)',
    CHANGE_PCT             COMMENT '광고비/예산 변동률 (%)',
    BASE_AD_COST           COMMENT '기준 광고비 실적 (원)',
    SIMULATED_AD_COST      COMMENT '시뮬레이션 예상 광고비 (원)',
    BASE_DEV_CNT           COMMENT '기준 후원개발건수 실적 (건)',
    SIMULATED_DEV_CNT      COMMENT '시뮬레이션 예상 후원개발건수 (건)',
    DIFF_DEV_CNT           COMMENT '개발건수 증감 (건)',
    BASE_DEV_AMT           COMMENT '기준 후원개발금액 추정치 (원)',
    SIMULATED_DEV_AMT      COMMENT '시뮬레이션 예상 후원개발금액 (원)',
    DIFF_DEV_AMT           COMMENT '개발금액 증감 (원)',
    SIMULATION_MODEL       COMMENT '적용 시뮬레이션 모델 명칭',
    ASSUMPTIONS            COMMENT '가정 및 주의사항'
)
  COMMENT = '실시간 경량 ML 가상 시뮬레이터 SERVING 뷰. 광고비 변동 시나리오별 후원개발 건수/금액 추정치 제공 (고정값 아님).'
AS
WITH scenarios AS (
    SELECT column1 AS SCENARIO_NAME, column2 AS CHANGE_PCT
    FROM (VALUES
        ('-50% 대폭 감액', -50.0),
        ('-30% 감액', -30.0),
        ('-20% 감액', -20.0),
        ('-10% 소폭 감액', -10.0),
        ('+10% 소폭 증액',  10.0),
        ('+20% 증액',  20.0),
        ('+30% 증액',  30.0),
        ('+50% 대폭 증액',  50.0),
        ('+100% 2배 증액', 100.0)
    )
),
base_metrics AS (
    SELECT
        SUBSTRING(d.DATE_SK::VARCHAR, 1, 6) AS STDR_MT,
        COALESCE(m.MKTG_CAMPAIGN_NAME, a.MEDIA_CHANNEL_NM, '(미매핑)') AS MKTG_CAMPAIGN_NAME,
        SUM(a.AD_COST) AS BASE_AD_COST,
        SUM(COALESCE(a.AGENCY_CONV_CNT, a.AGENCY_CONV_MEMBERS, 0)) AS BASE_DEV_CNT,
        SUM(COALESCE(a.AGENCY_CONV_MEMBERS, 0) * 20000) AS BASE_DEV_AMT
    FROM GN_DW.GOLD.WIDE_AD_COMBINED a
    JOIN GN_DW.GOLD.DIM_DATE d ON a.PERF_DATE_SK = d.DATE_SK
    LEFT JOIN GN_DW.GOLD.DIM_MARKETING_CAMPAIGN m ON a.MKTG_CAMPAIGN_SK = m.MKTG_CAMPAIGN_SK
    WHERE a.AD_COST > 0
    GROUP BY 1, 2
)
SELECT
    b.STDR_MT,
    b.MKTG_CAMPAIGN_NAME,
    s.SCENARIO_NAME,
    s.CHANGE_PCT,
    b.BASE_AD_COST,
    ROUND(b.BASE_AD_COST * (1.0 + s.CHANGE_PCT / 100.0), 0) AS SIMULATED_AD_COST,
    b.BASE_DEV_CNT,
    ROUND(b.BASE_DEV_CNT * POWER(1.0 + GREATEST(s.CHANGE_PCT, -90.0) / 100.0, 0.72), 2) AS SIMULATED_DEV_CNT,
    ROUND(b.BASE_DEV_CNT * POWER(1.0 + GREATEST(s.CHANGE_PCT, -90.0) / 100.0, 0.72) - b.BASE_DEV_CNT, 2) AS DIFF_DEV_CNT,
    b.BASE_DEV_AMT,
    ROUND(b.BASE_DEV_AMT * POWER(1.0 + GREATEST(s.CHANGE_PCT, -90.0) / 100.0, 0.72), 0) AS SIMULATED_DEV_AMT,
    ROUND(b.BASE_DEV_AMT * POWER(1.0 + GREATEST(s.CHANGE_PCT, -90.0) / 100.0, 0.72) - b.BASE_DEV_AMT, 0) AS DIFF_DEV_AMT,
    'Cobb-Douglas Elasticity Model (e=0.72)' AS SIMULATION_MODEL,
    '광고비 변동률 기반 한계효용 체감 탄력성 계수 0.72 적용 · 가상 추정치(고정 실적치 아님)' AS ASSUMPTIONS
FROM base_metrics b
CROSS JOIN scenarios s;


-- ============================================================================
-- [3] SEMANTIC VIEW: GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR
-- ============================================================================
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR
  TABLES (
    sim AS GN_DW.SERVING.ML_REALTIME_SIMULATOR_V
      PRIMARY KEY (STDR_MT, MKTG_CAMPAIGN_NAME, SCENARIO_NAME)
      WITH SYNONYMS ('실시간 시뮬레이터', '경량 ML 시뮬레이터', '광고비 시뮬레이션', '예산 시뮬레이션', '가상 시나리오')
      COMMENT = '실시간 경량 ML 가상 시뮬레이터 SV (base: SERVING.ML_REALTIME_SIMULATOR_V). [Grain: 기준월 × 마케팅캠페인 × 시나리오]. [활성 지표: 시뮬레이션 광고비, 예상 개발건수/금액, 증감치]. [주의: 🔴정규 실적 및 정본 배치 예측이 아니며 가상 시뮬레이션 추정치임 · 2단계 확인 후 안내].'
  )
  DIMENSIONS (
    sim.STDR_MT AS sim.STDR_MT
      WITH SYNONYMS ('기준월', '시뮬레이션 기준월')
      COMMENT = '시뮬레이션 산출 기준 실적월(YYYYMM 문자열).',
    sim.MKTG_CAMPAIGN_NAME AS sim.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인', '캠페인명', '매체채널명')
      COMMENT = '마케팅캠페인명 또는 광고 매체채널명.',
    sim.SCENARIO_NAME AS sim.SCENARIO_NAME
      WITH SYNONYMS ('시나리오', '시나리오명', '변동 시나리오')
      COMMENT = '광고비/예산 변동 시나리오 명칭 (예: +20% 증액, -10% 감액 등).',
    sim.CHANGE_PCT AS sim.CHANGE_PCT
      WITH SYNONYMS ('변동률', '광고비 변동률', '증감률')
      COMMENT = '광고비/예산 변동 비율 (%).',
    sim.SIMULATION_MODEL AS sim.SIMULATION_MODEL
      WITH SYNONYMS ('시뮬레이션 모델')
      COMMENT = '적용된 시뮬레이션 수학/ML 모델 명칭.',
    sim.ASSUMPTIONS AS sim.ASSUMPTIONS
      WITH SYNONYMS ('가정 및 한계', '모델 가정')
      COMMENT = '시뮬레이션 산출 가정 및 주의사항 설명.'
  )
  METRICS (
    sim.TOTAL_BASE_AD_COST AS SUM(sim.BASE_AD_COST)
      WITH SYNONYMS ('기준 광고비', '원천 광고비')
      COMMENT = '기준 실적 광고비 합계 (원).',
    sim.TOTAL_SIMULATED_AD_COST AS SUM(sim.SIMULATED_AD_COST)
      WITH SYNONYMS ('시뮬레이션 예상 광고비', '예상 광고비')
      COMMENT = '시뮬레이션 적용 후 예상 광고비 합계 (원).',
    sim.TOTAL_BASE_DEV_CNT AS SUM(sim.BASE_DEV_CNT)
      WITH SYNONYMS ('기준 개발건수')
      COMMENT = '기준 실적 후원개발건수 합계 (건).',
    sim.TOTAL_SIMULATED_DEV_CNT AS SUM(sim.SIMULATED_DEV_CNT)
      WITH SYNONYMS ('예상 개발건수', '시뮬레이션 개발건수')
      COMMENT = '시뮬레이션 적용 후 예상 후원개발건수 합계 (건).',
    sim.TOTAL_DIFF_DEV_CNT AS SUM(sim.DIFF_DEV_CNT)
      WITH SYNONYMS ('예상 개발건수 증감', '개발건수 차이')
      COMMENT = '시뮬레이션으로 인한 개발건수 예상 증감 (건).',
    sim.TOTAL_BASE_DEV_AMT AS SUM(sim.BASE_DEV_AMT)
      WITH SYNONYMS ('기준 개발금액')
      COMMENT = '기준 실적 후원개발금액 추정치 (원).',
    sim.TOTAL_SIMULATED_DEV_AMT AS SUM(sim.SIMULATED_DEV_AMT)
      WITH SYNONYMS ('예상 개발금액', '시뮬레이션 개발금액')
      COMMENT = '시뮬레이션 적용 후 예상 후원개발금액 (원).',
    sim.TOTAL_DIFF_DEV_AMT AS SUM(sim.DIFF_DEV_AMT)
      WITH SYNONYMS ('예상 개발금액 증감', '개발금액 차이')
      COMMENT = '시뮬레이션으로 인한 개발금액 예상 증감 (원).'
  )
  COMMENT = '실시간 경량 ML 가상 시뮬레이터 SV. base=SERVING.ML_REALTIME_SIMULATOR_V. 🔴🔴 **가상 시뮬레이션 추정치이며 정규 실적이나 고정 예측치가 아니다.** 실적 SV(SV_AD, SV_MEMBER_EVENT 등) 및 정본 배치 예측 SV(SV_ML_DVLP_FORECAST 등)와 같은 표에 합산하지 않고 반드시 분리한다. 🔴 질문 접수 시 "이 항목은 사전 연산된 정규 지표가 아닙니다. 머신러닝 실시간 시뮬레이션 모델을 사용하여 추정치를 계산할까요?" 확인 가드레일을 먼저 거친다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다.
  [O206 출력 규칙] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명".
  핵심 규칙: (1) 🔴🔴 **가상 시뮬레이션 결과이므로 표 제목에 「[시뮬레이션 추정치 · 고정값 아님]」을 반드시 표기한다.** (2) 기준월(STDR_MT) 미지정 시 데이터 내 최신월로 한정한다. (3) 시나리오(SCENARIO_NAME 또는 CHANGE_PCT)를 지정하여 조회한다.';


-- ============================================================================
-- [4] 권한 부여 (GRANT)
-- ============================================================================
GRANT ALL ON PROCEDURE GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP(VARCHAR, FLOAT, VARCHAR) TO ROLE GN_DW_ADMIN;
GRANT USAGE ON PROCEDURE GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP(VARCHAR, FLOAT, VARCHAR) TO ROLE GN_DW_ENGINEER;
GRANT USAGE ON PROCEDURE GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP(VARCHAR, FLOAT, VARCHAR) TO ROLE GN_DW_ANALYST;

GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_ADMIN;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_ANALYST;

GRANT SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_ADMIN;
GRANT SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_ANALYST;
--  [2026-10-14 O229 D6] sv_unit_gate 누락 검출 — SERVICE·VIEWER SELECT + REFERENCES
GRANT SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_SERVICE;
GRANT SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_VIEWER;
GRANT REFERENCES ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_ANALYST;
GRANT REFERENCES ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_SERVICE;
GRANT REFERENCES ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_VIEWER;


-- ============================================================================
-- [5] 스모크 테스트 (Verification)
-- ============================================================================
-- 1) SP 호출 스모크 테스트 (20% 증액 가상 시뮬레이션)
-- CALL GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP('전체', 20.0, NULL);

-- 2) SERVING VIEW 조회 스모크 테스트
-- SELECT STDR_MT, MKTG_CAMPAIGN_NAME, SCENARIO_NAME, BASE_DEV_CNT, SIMULATED_DEV_CNT, DIFF_DEV_CNT
-- FROM GN_DW.SERVING.ML_REALTIME_SIMULATOR_V
-- WHERE SCENARIO_NAME = '+20% 증액'
-- LIMIT 5;

-- 3) SEMANTIC VIEW 스모크 테스트
-- SELECT STDR_MT AS "기준월", MKTG_CAMPAIGN_NAME AS "캠페인명", TOTAL_SIMULATED_DEV_CNT AS "예상개발건수"
-- FROM GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR
-- WHERE SCENARIO_NAME = '+20% 증액'
-- GROUP BY STDR_MT, MKTG_CAMPAIGN_NAME;


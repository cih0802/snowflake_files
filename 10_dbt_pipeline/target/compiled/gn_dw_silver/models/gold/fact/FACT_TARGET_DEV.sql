-- FACT_TARGET_DEV: 회원개발 목표 팩트 (CRM_DEV_TARGET, 월×조직×개발구분)
-- Co-authored with CoCo
-- ORG_SK 는 DIM_ORG.ORG_DK(=ABS(HASH(DEPT_ID)))로 해소. Bronze 입고 후 실행.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
--
-- ============================================================================
-- [2026-08-05 O38] MONTH_KEY 연도 소실 교정 — 규약 위반 + 무증상 목표 팽창
-- ----------------------------------------------------------------------------
-- 결함: 종전 산식이 `TRY_TO_NUMBER(t.STDR_MT)`(기준월)만 써서 `STDYY`(기준연)를 버렸다.
--   정본 DDL 은 `MONTH_KEY NUMBER(6,0) '목표월 YYYYMM (FK→DIM_DATE, 월 conform)'` 로
--   YYYYMM 을 명시하는데 실적재는 **1~12 월 번호**였다 → 정본 규약 위반.
--
-- 무증상이었던 이유(P60/P63 계열 의미 결함):
--   · 행수·SUM·참조무결성이 전부 정상이다. GOAL 합계는 원천과 정확히 일치한다.
--   · `MONTH_KEY` 에는 dbt 테스트가 **한 건도 없다**(yml 에 ORG_SK 만 있었다).
--   · 그래서 어떤 품질 게이트도 잡지 못했고, "2026년 1월 목표"를 물으면
--     **2012~2026년 1월 목표의 합**이 조용히 반환됐다.
--
-- grain 파괴 규모(실측 2026-08-05):
--   · BRONZE `TM_CM_MBER_DVLP_GOAL` 25,344행 · `STDYY` 15개 연도(2012~2026) · grain 유일
--   · 연도를 버린 결과 GOLD 7,272행 = **3.49배 병합**(부서·구분별 관측 연도 수만큼 목표가 누적)
--   · 팽창 배수는 균일하지 않다 — 15배는 상한이지 전건 배수가 아니다
--
-- 교정 후 실측 기대치(사전 시뮬레이션 완료):
--   · grain `(YYYYMM, ORG_SK, DEV_TYPE)` = **25,344 유일** · 변환 실패 0
--   · 범위 201201~202612 · `SUM(GOAL_CNT)` 4,622,103 **불변**(연도 복원은 재분배이지 값 변경이 아니다)
--
-- 이 한 건이 정본 지표 **#1(월 목표 달성율)·#2(누계)·#3(연)** 세 개를 동시에 막고 있었다.
--   연 목표는 별도 저장 지표가 아니라 월 목표의 연 합계이므로 컬럼 신설은 불요하다.
--
-- `month_key_clamp` 적용: 다른 월 팩트(FMM·FBD)와 동일 규약. 캘린더 범위(199101~203512)·
--   월 01~12 를 모두 만족할 때만 통과하고 무효는 Unknown(0)으로 라우팅한다.
--   ⚠️ `STDR_MT` 는 원천이 '01'~'12' TEXT 라 LPAD 로 2자리를 보장한 뒤 결합한다
--      (한 자리로 결합하면 20121 처럼 5자리 유령 월키가 만들어진다).
-- ============================================================================


with t as (
    select * from GN_DW.SILVER.CRM_DEV_TARGET
)

select
    -- [O38] 연 + 월 결합 YYYYMM. 종전 `TRY_TO_NUMBER(t.STDR_MT)` 는 연도를 버렸다.
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) END, 0) as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    t.MBER_DVLP_DIV_CD                            as DEV_TYPE,
    SUM(t.GOAL_CNT)                               as GOAL_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5480bee1-eeb7-40d8-9796-8ba5b55af8b6'                    AS DW_BATCH_ID
from t
left join GN_DW.GOLD.DIM_ORG o
    on o.ORG_DK = ABS(HASH(t.DEPT_ID))
group by
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0')) END, 0),
    COALESCE(o.ORG_SK, 0),
    t.MBER_DVLP_DIV_CD
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- warn_erp_budget_procedure_merge: 예산과목 키가 **편성 차수를 뭉개는지** 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (2026-08-29 O114-B 신설 · DEC-44 의 관측 장치)
--   원천 `BDGT_ACMSLT_LEDGER` 가 2026-08-29 자로 `BDGT_PRCD_NM`(편성 차수 = 연사업 / 추가경정)을
--   신설했다. 그런데 `ERP_BUDGET_ITEM`·`ERP_BUDGET`·`ERP_BUDGET_YEARLY` 세 모델이 공유하는
--   `BUDGET_ITEM_DK` **MD5 10컬럼 산식에 그 컬럼이 없다** ⇒ 본예산과 추경이 **같은 키로 붕괴**한다.
--   결과: `DIM_BUDGET_ITEM` 으로 GROUP BY 하면 「추경 얼마?」에 **합산된 총계**가 돌아온다.
--   ⚠️ 이 사고는 오류를 내지 않는다 — 그래서 기존 테스트 전부(당시 `not_null` 1개)가 침묵했다.
--
-- 🔴 왜 원천을 보는가 (SILVER 결과가 아니라)
--   이 결함의 정체는 **키 산식이 원천의 구분 축을 버리는 것**이다. SILVER 를 보면 이미 뭉개진
--   뒤라서 「무엇을 잃었는지」가 보이지 않는다 ⇒ 판정은 원천에서 해야 진단이 된다.
--   ⇒ 산식은 세 모델과 **글자 그대로 같게** 유지한다(다르면 이 테스트가 거짓 안심을 준다).
--
-- ⚠️ 이 테스트가 보지 못하는 것
--   ⓐ **차수 외의 붕괴는 이 축으로 안 보인다** — `BDGT_ITEM_NM`·`DVLP_INBOUND_PATH` 도 키에 없어서
--      추가로 뭉개진다. 그 총량은 `warn_erp_budget_yearly_grain.sql` 이 센다(이 테스트는 원인 축).
--   ⓑ **합산이 옳은지 틀린지는 판정하지 않는다** — 추경이 「증분」이면 합산이 맞고 「재작성」이면
--      틀린다. 🔴 그 의미는 **현업 확인 대상**이고 이 테스트는 **구분이 사라졌다는 사실**만 알린다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 차수가 섞인 예산과목 키 1건.
--   🟢 정상 상태 = 0행(= 키가 차수를 구분한다).
--   🔴 DEC-44 결정 후 `severity` 를 error 로 올려라 — 그것이 이 항목의 종결 조건이다.


WITH b AS (
    SELECT
        -- 🔴 세 모델과 동일 산식 — 바꿀 때는 4곳을 함께 바꾼다.
        MD5(COALESCE(TO_VARCHAR(YEAR),'')||'|'||COALESCE(INCOME_EXPS_DIV_NM,'')||'|'||COALESCE(BDGT_UNIT_NM,'')||'|'||
            COALESCE(JANG_NM,'')||'|'||COALESCE(KWAN_NM,'')||'|'||COALESCE(HANG_NM,'')||'|'||
            COALESCE(MOK_NM,'')||'|'||COALESCE(DTL_ITEM_NM,'')||'|'||COALESCE(SUBDTL_ITEM_NM,'')||'|'||
            COALESCE(FUND_SOURCE_NM,''))                                  AS BUDGET_ITEM_DK,
        NULLIF(TRIM(BDGT_PRCD_NM),'')                                     AS BDGT_PRCD_NM,
        YEAR_BDGT_TOT_AMT                                                 AS YEAR_BDGT_TOT_AMT
    FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
    WHERE INCOME_EXPS_DIV_NM <> 'TOTAL'      -- 모델 3종과 동일 필터
)

SELECT
    BUDGET_ITEM_DK                                        AS BUDGET_ITEM_DK,
    COUNT(DISTINCT BDGT_PRCD_NM)                          AS N_PROCEDURES,
    LISTAGG(DISTINCT BDGT_PRCD_NM, ' + ')                 AS MERGED_PROCEDURES,
    COUNT(*)                                              AS N_SOURCE_ROWS,
    SUM(YEAR_BDGT_TOT_AMT)                                AS MERGED_YEAR_BUDGET_AMT
FROM b
GROUP BY BUDGET_ITEM_DK
HAVING COUNT(DISTINCT BDGT_PRCD_NM) > 1
ORDER BY MERGED_YEAR_BUDGET_AMT DESC
      
    ) dbt_internal_test
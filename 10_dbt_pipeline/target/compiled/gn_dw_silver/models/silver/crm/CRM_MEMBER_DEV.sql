-- CRM_MEMBER_DEV: 개발약정 실적 정제 + AREA_CD(CM018)·DVLP_DIV_CD(MM015) 라벨 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-03 O24] DVLP_DIV_NM 신설. 원천 DVLP_DIV_CD 는 정본 컬럼정의서(167행)가 코드그룹 MM015 를 지정하며
--   1=신규 · 2=증액 · 3=감액 · 4=재후원 · 5=후원중단 5종이다(USE_YN 전부 Y). 종전에는 코드만 전파하고
--   라벨을 만들지 않아 하류 GOLD 가 5종을 EVENT_TYPE='DEV' 한 값으로 뭉갰다(O24).
--   컬럼명은 정본 컬럼정의서 504행이 명시한 현업 용어쌍 `DVLP_DIV_CD`/`DVLP_DIV_NM` 을 그대로 쓴다.
-- [2026-08-25 안내1] 캠페인 속성 비정규화 신설. 종전에는 CMPGN_CD 를 raw FK 로만 전파하고
--   캠페인 속성은 공용 차원(CRM_CAMPAIGN → GOLD DIM_CAMPAIGN)에만 두었다. 현업이 Streamlit/Cowork 에서
--   "회원 기준" 집계를 요청 → CMPGN_CD 로 DIM_CAMPAIGN 을 매번 조인하지 말고, SILVER 빌드 시점에
--   이 모델(CRM_MEMBER_DEV, 개발건 grain)에 캠페인 9속성을 직접 비정규화해 넣는다.
--   ⚠️ 이 모델은 "회원 1건 개발=1행=1 CMPGN_CD" grain 이라 대표값 선택 문제(O8 다중캠페인 19%, LAST_CAMPAIGN
--   DROP 판정)가 발생하지 않는다 — 그 문제는 "회원 단일값" grain 에서만 생긴다.
--   조인원본 = CRM_CAMPAIGN(이미 CMPGN_CD 로 TM_CM_CMPGN_MNG·TM_CM_MKTNG_UTM 등을 라벨까지 조인해 둔 모델).
--   fan-out 안전: TM_CM_CMPGN_MNG.CMPGN_CD 36,163=36,163 유일(2026-08-25 실측) → CRM_CAMPAIGN 도 CMPGN_CD 유일.
--   적재 시점 값으로 고정(SCD 없음, 현업 확정) — 캠페인 마스터가 이후 바뀌어도 과거 개발이력 행은 재계산하지 않는다.
-- [DEC-43] 캠페인 SV 3종(COHORT·FEE·SPONSOR_BIZ) 스냅샷 동결 결정으로 위 9속성에
--   BRND_NM·PARENT_CAMPAIGN_NAME·PROMO_METHOD_NAME 3속성을 더해 12속성 전체를 동결한다.
--   하류(FACT_MEMBER_EVENT·FACT_MEMBER_COHORT·FACT_MEMBER_SPONSOR_BIZ·DIM_MEMBER_ACQUISITION)는
--   이 12컬럼을 그대로 승계하며 DIM_CAMPAIGN 실시간 조인을 대체한다.
--
-- [2026-08-25 증분 전략 오버라이드] 🔴 이 모델은 폴더 기본값(dbt_project.yml `models.gn_dw_silver.silver`:
--   +materialized:incremental·+incremental_strategy:append·+pre-hook:silver_purge(TRUNCATE)·+full_refresh:false)
--   을 이 파일에서 명시적으로 **오버라이드**한다. 그 기본값은 "매 run 전량 TRUNCATE 후 전량 재적재"이고
--   실질적으로 is_incremental() 필터를 걸 수 없다(TRUNCATE 가 걸리면 필터링된 신규분만 남고 과거행이 사라진다).
--   현업이 "1개월 주기 변경분 증분 적재"를 요청했으므로 이 모델만 **merge + is_incremental() 날짜필터**로 바꾼다.
--   ⚠️ 그 대신 unique_key 가 필요해졌다 — 이 모델의 자연키는 이미 WHERE 절이 강제하던
--   (SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO) 4컬럼 복합키다(개발건 1행 grain).
--   ⚠️ full_refresh 는 그대로 false 로 둔다 — true 로 풀면 --full-refresh 가 CTAS 로 이 테이블을 다시 만들어
--   `04_silver_design/08_SILVER_테이블DDL` 이 선언한 타입·주석·제약을 파괴한다(순서9 G-1/G-2 사고와 동일 위험).
--   "SILVER 전체를 덮어써야 하는 상황"(안내1 후반부)은 대신 --full-refresh 플래그가 아니라
--   `--vars '{"crm_member_dev_full_reload": true}'` 로 처리한다 — merge 는 구조를 보존하며
--   전량을 다시 흘려도 안전하다(신규는 INSERT, 기존은 UPDATE, 삭제는 없음 — 원천 행이 삭제되면 잔존 — 하단 한계 참조).
SELECT
  NULLIF(TRIM(s.SPNSR_NO),'')      AS SPNSR_NO,
  s.SPNSR_BSNS_NO                  AS SPNSR_BSNS_NO,
  NULLIF(TRIM(s.OCCRRNC_DE),'')    AS OCCRRNC_DE,
  s.SER_NO                         AS SER_NO,
  NULLIF(TRIM(s.MBER_NO),'')       AS MBER_NO,
  NULLIF(TRIM(s.SPNSR_BSNS_ID),'') AS SPNSR_BSNS_ID,
  s.SPNSR_AMT                      AS SPNSR_AMT,
  NULLIF(TRIM(s.DVLP_DIV_CD),'')   AS DVLP_DIV_CD,
  v.DTL_CD_NM                      AS DVLP_DIV_NM,
  NULLIF(TRIM(s.ACT_DEPT_CD),'')   AS ACT_DEPT_CD,
  NULLIF(TRIM(s.ACMSLT_DEPT_CD),'')AS ACMSLT_DEPT_CD,
  NULLIF(TRIM(s.CMPGN_CD),'')      AS CMPGN_CD,
  NULLIF(TRIM(s.SETLE_CD),'')      AS SETLE_CD,
  NULLIF(TRIM(s.AREA_CD),'')       AS AREA_CD,
  a.DTL_CD_NM                      AS AREA_NM,
  s.AGE                            AS AGE,
  -- [2026-08-03 G3] 정본 코드컬럼 raw 전파(라벨 미배선 — 수요 확인 후 별도).
  NULLIF(TRIM(s.CANCL_RDCAMT_RSN_CD),'') AS CANCL_RDCAMT_RSN_CD,  -- MM002 (31종 중 18종 폐지코드)
  NULLIF(TRIM(s.MBER_DIV_CD),'')   AS MBER_DIV_CD,   -- MM018
  NULLIF(TRIM(s.SEX),'')           AS SEX,           -- CM013 raw. ⚠️CRM_MEMBER.SEX 는 M/F/U 정규화값 — 동명이의
  NULLIF(TRIM(s.SPNSR_AMT_CD),'')  AS SPNSR_AMT_CD,  -- CM012
  -- [2026-08-25 안내1] 캠페인 9속성 비정규화(CRM_CAMPAIGN 조인). CMPGN_CD 가 NULL 이면 전부 NULL(정상 — 결측 아님).
  cp.MBER_INFLOW_PATH_CD           AS MBER_INFLOW_PATH_CD,   -- MM293 개발인입경로
  cp.MBER_INFLOW_PATH_NM           AS MBER_INFLOW_PATH_NM,
  cp.CMPGN_CTGR_CD                 AS CMPGN_CTGR_CD,         -- MM294 캠페인카테고리
  cp.CMPGN_CTGR_NM                 AS CMPGN_CTGR_NM,
  cp.CMPGN_TYPE1_BSN               AS CMPGN_TYPE1_BSN,       -- MM295 국내/통합/해외
  cp.CMPGN_TYPE1_NM                AS CMPGN_TYPE1_NM,
  cp.CMPGN_TYPE2_BSN               AS CMPGN_TYPE2_BSN,       -- MM296 굿즈/기타/사례/사업
  cp.CMPGN_TYPE2_NM                AS CMPGN_TYPE2_NM,
  cp.MKTG_CMPGN_NM                 AS MKTG_CMPGN_NM,         -- 마케팅캠페인 코드
  cp.MK_CMPGN_NM                   AS MK_CMPGN_NM,
  cp.CMMN_BRND                     AS CMMN_BRND,             -- MM297 공통브랜드
  cp.CMMN_BRND_NM                  AS CMMN_BRND_NM,
  cp.MKTG_UTM                      AS MKTG_UTM,              -- TM_CM_MKTNG_UTM 코드
  cp.MKTG_UTM_NM                   AS MKTG_UTM_NM,
  -- [2026-08-25 안내2] 세부캠페인 후원구분·법인구분(Gold 까지 적재 요건, 홍보방법은 미사용 — 제외).
  cp.SPNSR_DIV_CD                  AS SPNSR_DIV_CD,          -- CM035 정기후원/일시후원
  cp.SPNSR_DIV_NM                  AS SPNSR_DIV_NM,
  cp.CPR_DIV_CD                    AS CPR_DIV_CD,             -- CM019 통합/사단/사복
  cp.CPR_DIV_NM                    AS CPR_DIV_NM,
  -- [DEC-43] 캠페인 SV 3종 스냅샷 동결 12속성 중 잔여 3속성(브랜드·상위캠페인명·홍보방법).
  --   BRND_NM 은 종전 "미사용 — 제외" 결정(위 주석)을 DEC-43 로 뒤집는다 — 이제 동결 대상이다.
  cp.BRND_NM                       AS BRND_NM,               -- 브랜드명
  cp.PARENT_CAMPAIGN_NAME          AS PARENT_CAMPAIGN_NAME,  -- 상위캠페인명
  cp.PROMO_METHOD_NAME             AS PROMO_METHOD_NAME,     -- CM008 홍보방법 라벨
  'CRM'                            AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID,
  -- [2026-08-25 증분 전략] 원천 적재시각 워터마크. is_incremental() 필터가 다음 run 에서 비교할 기준값을
  -- **여기(SILVER)에 그대로 저장**한다 — DW_LOAD_TS 는 매 run CURRENT_TIMESTAMP() 로 덮이는 "빌드 시각"이라
  -- 워터마크로 못 쓴다(재실행하면 항상 지금 시각이 됨). SRC_LOAD_DT 는 "원천이 이 행을 적재한 시각"을
  -- 그대로 보존해야 다음 run 이 "그 이후에 새로 들어온/바뀐 행만" 가려낼 수 있다.
  s._LOAD_DT                       AS SRC_LOAD_DT
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT s
LEFT JOIN GN_DW.SILVER.CRM_CODE a ON a.CD_ID='CM018' AND a.DTL_CD_ID=NULLIF(TRIM(s.AREA_CD),'')
-- MM015 = 정본 컬럼정의서 167행이 DVLP_DIV_CD 에 지정한 코드그룹. CRM_CODE PK=(CD_ID,DTL_CD_ID) 이므로
-- 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
LEFT JOIN GN_DW.SILVER.CRM_CODE v ON v.CD_ID='MM015' AND v.DTL_CD_ID=NULLIF(TRIM(s.DVLP_DIV_CD),'')
-- [2026-08-25 안내1] CRM_CAMPAIGN.CMPGN_CD 유일(fan-out 없음) → 개발건 grain 그대로 보존.
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN cp ON cp.CMPGN_CD = NULLIF(TRIM(s.CMPGN_CD),'')
WHERE s.SPNSR_NO IS NOT NULL AND s.SPNSR_BSNS_NO IS NOT NULL AND s.OCCRRNC_DE IS NOT NULL AND s.SER_NO IS NOT NULL

  -- [증분 분기] 두 조건 모두 참일 때만 활성화된다:
  --   ① is_incremental() = 대상 테이블이 이미 존재(첫 run·CTAS 아님) — dbt 가 자동 판정.
  --   ② var('crm_member_dev_full_reload', false) = false(기본값) — 사용자가 전체 재적재를 명시하지 않음.
  -- 필터 = 이미 적재된 최대 SRC_LOAD_DT 이후 원천 행만. 3일 lookback 을 두는 이유:
  --   원천(BRONZE_CRM)이 과거 발생분을 늦게 정정·재적재하는 경우(늦은 도착 데이터)를
  --   놓치지 않기 위함이다 — 정확히 "MAX 이후"만 보면 정정분이 원래 OCCRRNC_DE/적재일 언저리에서
  --   과거로 재기입될 때 누락될 수 있다. merge 이므로 겹쳐서 재선택해도 중복 행이 생기지 않는다(unique_key).
  AND s._LOAD_DT > (
        SELECT DATEADD('day', -3, COALESCE(MAX(SRC_LOAD_DT), '1900-01-01'::timestamp_ntz))
        FROM GN_DW.SILVER.CRM_MEMBER_DEV
      )

-- [전량 재적재 분기] --vars '{"crm_member_dev_full_reload": true}' 로 실행하면 위 증분 필터가 꺼지고
-- WHERE 절 나머지(SPNSR_NO 등 NOT NULL) 만 적용돼 원천 전량이 다시 select 된다.
-- ⚠️ 이 모델은 full_refresh=false + incremental_strategy='merge' 라 --full-refresh 플래그는 CTAS 를 트리거하지
-- 않는다(DDL 보호) — "전체를 다시 흘린다"는 이 var 로만 표현한다. merge 는 신규 INSERT·기존 UPDATE 는 하지만
-- **원천에서 삭제된 행을 지우지는 않는다**(delete+insert 가 아님) — 원천이 물리 삭제를 하는 원천이면
-- 별도 정합성 점검(고아 행 잔존 여부)이 필요하다(이번 요건 범위 밖 — 별도 확인 필요).
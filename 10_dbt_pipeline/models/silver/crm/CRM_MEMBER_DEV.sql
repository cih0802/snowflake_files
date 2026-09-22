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
--   하류(FACT_MEMBER_EVENT·FACT_MEMBER_COHORT·FACT_MEMBER_SPONSORSHIP_SPAN·DIM_MEMBER_ACQUISITION)는
--   이 12컬럼을 그대로 승계하며 DIM_CAMPAIGN 실시간 조인을 대체한다.
--
-- 🆕 🔴🔴 [2026-09-22 O180 · 사용자 결정 ⓐ′] **증분 오버라이드를 철회하고 SILVER 표준 패턴으로 정렬했다.**
--   적재 전략 = 폴더 기본값 그대로 = `incremental` + `append` + `pre-hook: silver_purge(TRUNCATE)`
--               + `full_refresh:false` (`dbt_project.yml:195-198`) = **매 run 전량 재적재 · 멱등**.
--
--   ▣ 종전 상태(2026-08-25 ~ 2026-09-22) — 이 자리에 「증분 전략 오버라이드」 절이 있었다.
--     선언 = `merge` + `unique_key=(SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO)` + `pre_hook=[]`
--            + `is_incremental()` 3일 lookback 워터마크 + `--vars` 전량 재적재 탈출구.
--     근거 = *"현업이 「1개월 주기 변경분 증분 적재」를 요청했다"* **한 줄**.
--
--   ▣ 🔴🔴 그 근거를 O180 이 전수 검색했고 **워크스페이스 정본 어디에도 없다.**
--     · `07_현업의사결정 회신/현업의사결정 회신.md` 전량 47줄 = **0건**
--     · `20_issue/` 전체에서 「1개월」·「변경분」·「증분 적재」·「안내1」 4축 = 요건 원문 **0건**
--     · 이력 `01_세션이력-033.md:81` 은 2026-08-25 「안내1/안내2」를 **캠페인 9속성 비정규화**
--       요건으로만 기록한다 ⇒ 증분 요건은 **어느 안내에도 귀속되지 않는 출처 미기재 요건**이었고
--       그것을 발행한 선행 세션은 이력 항목도 남기지 않았다.
--     🟢 판정식 = **모델 주석이 인용한 현업 발언은 정본이 아니다** — 회신 문서에 없으면 검증 불가다.
--
--   ▣ 🔴 그 오버라이드는 세 가지를 동시에 망가뜨리고 있었다(O179 실측):
--     ① `pre_hook=[]` 는 폴더 pre-hook 을 **취소하지 못한다** — dbt 는 hook 을 **누적**한다
--        (`macros/silver_purge.sql:4-11` 가 경고한 성질) ⇒ `TRUNCATE` 가 매 run 실제로 돌았다.
--     ② 그래서 증분 필터가 **빈 테이블**에서 `MAX(SRC_LOAD_DT)`=NULL → `COALESCE('1900-01-01')`
--        → **전량 통과**했다 ⇒ 증분이 미집행인데 **결과는 맞고 아무 테스트도 깨지지 않았다**(무증상).
--        🟢 판정식 = **「증분이 도는가」는 행수로 검증할 수 없다 — pre-hook 이 무엇을 냈는지 보아야 한다.**
--     ③ 그 결과 매 run **빈 테이블에 전량 `merge`** 했다 — matched 가 항상 0 인데 `append` 보다
--        비싼 경로를 냈다. SILVER 31모델 중 **이 모델만** 이 조합이었다.
--
--   ▣ 🟢🟢 표준 패턴 정렬이 동시에 닫은 것 = **O175 마감월 유령행 이월**(상세 = 파일 하단).
--     `merge` 는 원천 물리 삭제를 전파하지 못하지만 `TRUNCATE`+`append` 는 원리적으로 유령행 0 이다.
--     이슈 B 고아 제거(`:129`)도 계속 집행된다.
--
--   ▣ 🔴 대가 = **「1개월 주기 증분」 요건은 폐기한다.** 근거 부재 + 28일간 미집행 + 삭제 반영 상충이
--     겹쳤다. 되살릴 근거(현업 회신)가 나오면 그때 다시 설계한다.
--     🔴 그때 쓸 경로는 `pre_hook=[]` 가 **아니라** `macros/silver_purge.sql` 의 정본 등재부다
--        (`dbt_project.yml:192`·`:194` · 모델 파일 `pre_hook` 은 명문 금지).
--     🔴 그리고 `--vars` 탈출구를 다시 만들지 마라 — **이 환경에서 조용히 무시된다**(O179 실측).
--        오버라이드는 **파일에 적는 것만 신뢰**한다.
--
--   ⚠️ `full_refresh:false` 승계 이유는 불변이다 — `--full-refresh` 가 CTAS 로 이 테이블을 다시 만들어
--      `04_silver_design/08_SILVER_테이블DDL` 이 선언한 타입·주석·제약을 파괴한다(순서9 G-1/G-2 사고).
--   🟢 `unique_key` 는 불필요해졌다 — `append` 전량 재적재는 grain 비유일이어도 행소실이 없다
--      (`dbt_project.yml:181`).
{#- 🆕 🟢 [2026-09-22 O180 · 사용자 결정 ⓐ′] **모델 레벨 `config()` 를 제거했다 — 폴더 기본값만 쓴다.**
    정본 = `dbt_project.yml:195-198` = `incremental` + `append` + `full_refresh:false`
           + `pre-hook: "{{ silver_purge(this) }}"`.
    🔴 **이 파일에 `pre_hook` 을 다시 쓰지 마라** — `dbt_project.yml:194` 와
       `macros/silver_purge.sql:11` 이 명문으로 금지한다(dbt 는 hook 을 누적하므로 무효이고,
       O179 가 실측한 그 무증상 결함이 그대로 재발한다).
    🔴 이 모델을 다시 예외로 빼야 하면 **`macros/silver_purge.sql` 의 `RANGED_MODELS`
       (또는 신설 no-op 축)에 등재**하는 것이 유일한 정본 경로다(`dbt_project.yml:192`). -#}
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
  cp.MKTG_UTM                      AS MKTG_UTM,              -- TC_MKTNG_DTL_CD (U001) 코드
  cp.MKTG_UTM_NM                   AS MKTG_UTM_NM,
  -- [2026-09-16 O162] 마케팅채널(C002)
  cp.MKTG_CHANNEL                  AS MKTG_CHANNEL,          -- TC_MKTNG_DTL_CD (C002) 코드
  cp.MKTG_CHANNEL_NM               AS MKTG_CHANNEL_NM,       -- TC_MKTNG_DTL_CD (C002) 라벨
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
  -- 🆕 [2026-09-22 O180 · ⓐ′] **`SRC_LOAD_DT` 는 유지한다 — 다만 워터마크가 아니라 계보 컬럼이다.**
  --   종전 이 주석은 *"is_incremental() 필터가 다음 run 에서 비교할 기준값"* 이라 설명했으나
  --   그 증분 필터는 제거됐다(파일 하단) ⇒ 이 컬럼은 이제 **원천 적재시각의 보존**만 담당한다.
  --   🟢 컬럼을 지우지 않는 이유 = ㉠ `08_SILVER_테이블DDL` 이 선언한 구조를 바꾸지 않는다
  --      ㉡ 「원천이 이 행을 적재한 시각」은 진단·정합 대조에 계속 쓰인다(하류 영향 0)
  --      ㉢ 증분을 되살릴 근거가 나오면 워터마크 원천으로 다시 쓸 수 있다.
  --   ⚠️ `DW_LOAD_TS` 와 혼동하지 마라 — 그쪽은 매 run `CURRENT_TIMESTAMP()` 로 덮이는 **빌드 시각**이고
  --      재실행하면 항상 지금 시각이 된다(워터마크로 쓸 수 없다).
  s._LOAD_DT                       AS SRC_LOAD_DT
FROM {{ source('bronze_crm','TM_MM_FDRM_MBER_DVLP_AMT') }} s
LEFT JOIN {{ ref('CRM_CODE') }} a ON a.CD_ID='CM018' AND a.DTL_CD_ID=NULLIF(TRIM(s.AREA_CD),'')
-- MM015 = 정본 컬럼정의서 167행이 DVLP_DIV_CD 에 지정한 코드그룹. CRM_CODE PK=(CD_ID,DTL_CD_ID) 이므로
-- 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
LEFT JOIN {{ ref('CRM_CODE') }} v ON v.CD_ID='MM015' AND v.DTL_CD_ID=NULLIF(TRIM(s.DVLP_DIV_CD),'')
-- [2026-08-25 안내1] CRM_CAMPAIGN.CMPGN_CD 유일(fan-out 없음) → 개발건 grain 그대로 보존.
LEFT JOIN {{ ref('CRM_CAMPAIGN') }} cp ON cp.CMPGN_CD = NULLIF(TRIM(s.CMPGN_CD),'')
WHERE s.SPNSR_NO IS NOT NULL AND s.SPNSR_BSNS_NO IS NOT NULL AND s.OCCRRNC_DE IS NOT NULL AND s.SER_NO IS NOT NULL
  -- 🔴 [2026-09-22 O179 · 이슈 B] 회원 마스터 정본 미실재 회원 제거 · 정의 = macros/gn_member_master_filter.sql
  --    📏 실측 = 고아 271행(회원 16명) 제거 완료 · 3,654,929 → **3,654,658** · 고아 잔존 **0**.
  --    🟢 이 제거는 `TRUNCATE` + `append` 전량 재적재가 매 run 필터를 다시 적용하므로 집행된다
  --       (마스터에서 빠진 회원은 다음 run 에 자동 이탈 · 별도 1회성 `DELETE` 불필요).
  --    🔴 [2026-09-22 O180] 종전 이 자리에는 *"선택지 ⓑ 를 고르면 1회성 DELETE 가 필요해진다"* 는
  --       조건부 처방이 적혀 있었다. **ⓑ 는 채택되지 않았다**(사용자 결정 = ⓐ′ 표준 패턴 정렬)
  --       ⇒ 그 `DELETE` 는 **집행 대상이 아니다**. 🔴 이 문장을 조건 충족 시 실행할 지시로 읽지 마라
  --          (`J5` — 폐기된 예약 조치를 남겨 두면 나중에 아무도 전제를 재검증하지 않고 실행한다).
  AND {{ gn_member_master_filter("NULLIF(TRIM(s.MBER_NO),'')") }}
{#- 🆕 🟢 [2026-09-22 O180 · ⓐ′] **증분 분기를 제거했다.**
    종전 이 자리에는 `{% if is_incremental() and not var('crm_member_dev_full_reload', false) %}`
    블록이 있었고 `s._LOAD_DT > (SELECT DATEADD('day',-3, COALESCE(MAX(SRC_LOAD_DT),'1900-01-01')) FROM {{ this }})`
    로 3일 lookback 워터마크를 걸었다.
    🔴 그 필터는 **한 번도 실효가 없었다** — 폴더 `pre-hook` 의 `TRUNCATE` 가 매 run 먼저 돌아
       테이블을 비우므로 `MAX(SRC_LOAD_DT)` 가 항상 NULL 이 되고 `COALESCE('1900-01-01')` 이
       **전량을 통과**시켰다(O179 실측 · `QUERY_HISTORY` 2026-09-22 00:41:12 TRUNCATE → 00:41:14 MERGE).
    🟢 이제 `append` 전량 재적재가 정본이므로 워터마크 자체가 불필요하다 —
       멱등성은 `TRUNCATE` 가 보장한다(재실행 Δ0 · `dbt_project.yml:181`).
    🔴 lookback 개념 자체는 폐기가 아니다 — 늦은 도착 데이터는 **전량 재적재가 더 강하게 포괄**한다
       (창이 없으므로 놓칠 과거가 없다). W2 판정(O179)과 같은 축이다. -#}
-- 🆕 🟢🟢 [2026-09-22 O180 · ⓐ′] **O175 유령행 결함이 이 전환으로 구조적으로 닫혔다.**
--   종전 이 자리에는 `--vars '{"crm_member_dev_full_reload": true}'` 전량 재적재 분기 설명과,
--   그 위에 O175 가 적은 「마감월 유령행」 경고가 있었다. 요지 =
--     · 원천 운영 방식(사용자 정본) = 일별 적재 후 **데이터 마감일**이 오면 그 달을 지우고
--       마감 확정본으로 다시 밀어넣는다(단위 = BRONZE `_STDR_YM` 월 파티션 재적재 키).
--     · 🔴 `merge` 는 **삭제를 전파하지 않으므로** 마감월에 유령행이 남는다.
--     · 🔴 O175 가 둔 대책(위 `--vars` 런북)은 「이후 누락을 막는다」였고
--       「이미 남은 유령을 청소한다」가 아니었다 ⇒ 청소는 `delete+insert` 전환 설계 결정으로 이월됐다.
--   🟢 **그 이월이 소멸했다** — `TRUNCATE` + `append` 는 매 run 원천 적격 전량을 다시 흘리므로
--      원천에서 사라진 행은 **다음 run 에 자동으로 사라진다** ⇒ 유령행이 **원리적으로 0** 이다.
--      마감 재적재·물리 삭제·늦은 도착 정정이 전부 같은 한 경로로 흡수되고 런북 장치가 불필요해진다.
--   🔴 그 `--vars` 런북은 애초에 **이 환경에서 동작하지 않았다**(O179 실측 = `--vars` 는 조용히 무시된다)
--      ⇒ O175 의 방어는 기재만 있고 집행이 없었다. 이 전환이 그 공백까지 함께 닫는다.
--   🟢 이슈 B 고아 제거(위 `:129-137`)도 계속 집행된다 — 매 run `TRUNCATE` 후 필터를 통과한 행만
--      다시 들어오므로, 마스터에서 빠진 회원은 별도 `DELETE` 없이 자동 이탈한다.
--   ⚠️ 잔존 전제 = `04_silver_design/08_SILVER_테이블DDL` 선행 실행(테이블 미존재 시 첫 run 이
--      CTAS 로 구조 없이 만든다) · `full_refresh:false` 가 `--full-refresh` CTAS 를 차단한다.
--   📏 기대값 = 이 전환은 **행수를 바꾸지 않는다**. `WHERE` 절과 조인이 전부 무변경이고
--      종전에도 실질적으로 전량 재적재였으므로 build 후 **3,654,658 행 Δ0** 이어야 한다.
--      🔴 값이 다르면 그것은 이 전환의 결과가 아니라 **원천 변동**이므로 그쪽을 먼저 조사하라.

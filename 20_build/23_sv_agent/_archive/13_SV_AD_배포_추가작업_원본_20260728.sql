-- SV_AD 신설에 따른 잔여 배포 작업 — 05/09 실행 외에 사용자가 추가로 수행해야 하는 SQL
-- Co-authored with CoCo
--
-- 작성: 2026-07-28 · 대상 계정: cs94293 (트라이얼, TRIALADMIN)
-- 근거 문서: 04_SV_설계.md §6 · 03_SV_metric_배속.md §5 · 08_AGENT_spec.md §3.2 · 01_작업계획.md 진행상태표 #9
--
-- ═══════════════════════════════════════════════════════════════════════════════════════
-- ▶ 이 문서가 필요한 이유 (질문: "05와 09만 실행하면 되나?")
-- ═══════════════════════════════════════════════════════════════════════════════════════
--   **신규 계정에 처음부터 재현**하는 경우 → 05·09만으로는 부족(0단계 RBAC 선행 필요)하지만
--   05·09 자체는 자기완결적이다. 아래 §0 순서표 참조.
--
--   **현재 계정(cs94293)을 정상화**하는 경우 → 05·09 재실행만으로는 **불충분**하다. 이유:
--     (1) SV_AD·FACT_AD_COMBINED가 2026-07-28 CoCo 세션에서 **ACCOUNTADMIN 소유로 생성**됨
--         → 05 파일은 `USE ROLE GN_DW_ADMIN`으로 시작하지만, 이미 존재하는 객체를
--           GN_DW_ADMIN이 `CREATE OR REPLACE` 하려면 기존 객체 OWNERSHIP이 필요 → **권한 오류**.
--         → 소유권을 먼저 이전해야 05 재실행이 가능하다(§1).
--     (2) 09의 `CREATE OR REPLACE AGENT`는 **USAGE grant 3건 + CoWork SI 등록을 파괴**한다
--         → 재부여·재등록 필요(§3). 또는 비파괴 대안 사용(§2, 권장).
--
-- ═══════════════════════════════════════════════════════════════════════════════════════
-- ▶ §0. 전체 실행 순서 (신규 계정 재현 시)
-- ═══════════════════════════════════════════════════════════════════════════════════════
--   순서 | 파일                                              | 비고
--   -----|---------------------------------------------------|--------------------------------
--    1   | 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql    | 0단계 필수 선행(WH 3·역할 6·스키마 grant·
--        |   (= 05_SV-Agent_ai/02_SERVING_setup.sql 의 정본)  |  SERVING·CoWork object·helper뷰 2)
--    2   | (BRONZE→GOLD 파이프라인 = dbt 프로젝트)            | GOLD FACT/DIM 적재. GOLD는 FUTURE grant가
--        |                                                   |  걸려 있어 신규 FACT_AD_* 는 자동 커버 ✅
--    3   | 05_SV-Agent_ai/05_SV_DDL.sql                       | SV 6개 + FACT_AD_COMBINED helper뷰 + GRANT
--    4   | 05_SV-Agent_ai/09_AGENT_spec_구현.sql              | Agent 2개 + 소유권 + USAGE + SI 연결
--    5   | 05_SV-Agent_ai/13_SV_AD_배포_추가작업.sql (본 파일) | 위 3·4를 GN_DW_ADMIN으로 정상 실행했다면
--        |                                                   |  §1·§3 불요. §4 검증·§5 스모크만 수행
--
--   ⚠ 05를 **ACCOUNTADMIN이 아닌 GN_DW_ADMIN 역할로 통째 실행**하면 소유권 문제가 애초에 없다.
--     (05 파일 38행 `USE ROLE GN_DW_ADMIN;`이 이미 그 의도)
--
-- ═══════════════════════════════════════════════════════════════════════════════════════


/* =====================================================================================
   §1. 소유권 정상화 — SV_AD · FACT_AD_COMBINED (현재 계정 한정, 1회성)
        현상(2026-07-28 실측):
          FACT_AD_COMBINED owner = ACCOUNTADMIN  ❌ (DIM_MONTH·DIM_MEMBER_CURRENT = GN_DW_ADMIN)
          SV_AD            owner = ACCOUNTADMIN  ❌ (나머지 5 SV = GN_DW_ADMIN)
        목표: P7 serving_separation 원칙대로 전부 GN_DW_ADMIN 소유로 통일.
        ⚠ COPY CURRENT GRANTS 로 기존 GRANT(REFERENCES/SELECT ×3역할)를 보존한다.
   ===================================================================================== */
USE ROLE ACCOUNTADMIN;

GRANT OWNERSHIP ON VIEW          GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SEMANTIC VIEW GN_DW.SERVING.SV_AD            TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;

-- 검증: 두 객체 owner = GN_DW_ADMIN
SELECT TABLE_NAME, TABLE_OWNER
FROM   GN_DW.INFORMATION_SCHEMA.VIEWS
WHERE  TABLE_SCHEMA = 'SERVING'
  AND  TABLE_NAME IN ('FACT_AD_COMBINED', 'DIM_MONTH', 'DIM_MEMBER_CURRENT');
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;   -- 6행 전부 owner=GN_DW_ADMIN 확인


/* =====================================================================================
   §2. AGENT_OVERALL 갱신 — **권장: 비파괴 방식**
        배경: 09 [1-ALT-b]의 `CREATE OR REPLACE AGENT`는 아래를 전부 삭제한다.
              · USAGE grant 3건(ANALYST/VIEWER/SERVICE)  → §3.1로 재부여 필요
              · CoWork SI object 등록                    → §3.2로 재등록 필요
        대안: 이미 존재하는 Agent는 `ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION`
              으로 **스펙만 교체**하면 grant·SI 등록이 그대로 유지된다.
              (semantic_studio 의 cortex_agent_save/deploy 가 내부적으로 이 경로를 사용)

        ▶ 실행 방법 2가지 중 택1:
          (A) CoCo에게 요청 — "09의 AGENT_OVERALL 스펙으로 cortex_agent_deploy 해줘"
              → semantic_studio cortex_agent_deploy (save=ALTER MODIFY LIVE VERSION + publish)
              → grant·SI 유지되므로 §3 전체 SKIP ✅  **← 권장**
          (B) 09 파일의 CREATE OR REPLACE 를 직접 실행
              → §3.1·§3.2를 **반드시** 이어서 실행 ⚠

        ※ 09 파일에 `ALTER AGENT` 버전을 추가하지 않은 이유: Agent 스펙 본문(YAML)이 09에
          이미 정본으로 있고, 스펙 전문을 두 곳에 중복 보관하면 drift가 생긴다.
          (A) 경로는 09의 스펙을 그대로 읽어 적용하므로 단일정본이 유지된다.
   ===================================================================================== */
-- (참고) 현재 배포본이 문서보다 구버전인지 확인 — tools 배열에 analyst_ad 가 없으면 구버전
DESCRIBE AGENT GN_DW.SERVING.AGENT_OVERALL;


/* =====================================================================================
   §3. (B 경로 선택 시에만) CREATE OR REPLACE AGENT 후 복구 작업
   ===================================================================================== */
-- §3.1 USAGE grant 재부여 (CREATE OR REPLACE 로 소실됨)
USE ROLE GN_DW_ADMIN;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_SERVICE;

-- §3.2 CoWork(Snowflake Intelligence) 재등록 확인/복구
--   SI object owner=ACCOUNTADMIN 이므로 역할 전환 필요.
--   먼저 SHOW로 등록 여부를 보고, AGENT_OVERALL 행이 없을 때만 ADD AGENT 실행.
USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행이어야 정상
-- ↓ AGENT_OVERALL 이 목록에 없을 때만 실행
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT GN_DW.SERVING.AGENT_OVERALL;


/* =====================================================================================
   §4. 최종 검증 (§1~§3 완료 후 필수)
   ===================================================================================== */
USE ROLE GN_DW_ADMIN;

-- (4-1) SV 6개 · owner 통일
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
--   기대: 6행(SV_MEMBER_MONTHLY·SV_MEMBER_EVENT·SV_SERVICE·SV_EVENT_PARTICIPATION·SV_BUDGET·SV_AD)
--         전부 owner = GN_DW_ADMIN

-- (4-2) SV_AD grant 3역할 (CREATE OR REPLACE 후에는 소실되므로 05 §7의 3줄 재실행 필요)
SHOW GRANTS ON SEMANTIC VIEW GN_DW.SERVING.SV_AD;
--   기대: OWNERSHIP(GN_DW_ADMIN) + REFERENCES/SELECT × ANALYST·VIEWER·SERVICE

-- (4-3) helper 뷰 grant
SHOW GRANTS ON VIEW GN_DW.SERVING.FACT_AD_COMBINED;
--   기대: OWNERSHIP(GN_DW_ADMIN) + SELECT × ANALYST·VIEWER·SERVICE

-- (4-4) Agent grant·SI
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;   -- OWNERSHIP + USAGE×3 = 4행
USE ROLE ACCOUNTADMIN;
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행


/* =====================================================================================
   §5. SV_AD 스모크 검증 (04 §0.1 DoD — fan-out 0 · 지표 산출)
        ※ 05 파일 §7-4·7-5와 동일. 재배포 후 회귀 확인용으로 여기에도 둔다.
   ===================================================================================== */
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- (5-1) fan-out 0: SV 집계 == 코어 FACT 직접 SUM  (위성 2개 1:1 조인 검증)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST)  FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                           AS fact_val;
--   기대: 두 값 동일 = 51,439,193,917.80 (2026-07-28 실측)

-- (5-2) 수직분할 완결성: 디지털 + 방송 = 코어 전건 (helper 뷰 LEFT JOIN 안전성 근거)
SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE) AS fap,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL)     AS dig,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)   AS brc,
       (SELECT COUNT(*) FROM GN_DW.SERVING.FACT_AD_COMBINED) AS combined;
--   기대: fap=235,572 · dig=197,686 · brc=37,886 · combined=235,572
--         (dig + brc = fap 이고 combined = fap → 중복 팽창 없음)

-- (5-3) 디지털 지표 산출 (CTR·CVR·개발단가)
--   ※ SEMANTIC_VIEW(...) 내부에 FILTER 절로 `ad.컬럼` 을 쓰면 문법 오류다.
--     차원을 DIMENSIONS 에 넣고 **바깥 WHERE 에서 별칭 없는 컬럼명**으로 걸러야 한다(실측).
SELECT CAL_YEAR, AD_SOURCE_TYPE, TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR, ad.AD_SOURCE_TYPE
  METRICS TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
)
WHERE AD_SOURCE_TYPE = 'DIGITAL'
ORDER BY 1;
--   기대(2026-07-28 실측): 2024 CTR 0.199%·단가 131,367원 / 2025 0.286%·110,335원 / 2026 0.345%·103,066원
--   ⚠ 2026 단가가 103,066원인 것이 정상 — 2026-06은 개발건수 미적재라 분자에서도 제외된다(§6-4).

-- (5-4) 상호배타 확인 + 기기 차원 조인
SELECT AD_SOURCE_TYPE, DEVICE_TYPE, TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.AD_SOURCE_TYPE, device.DEVICE_TYPE
  METRICS TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
)
ORDER BY 1, 2;
--   기대(2026-07-28 실측) — 4행, 상호배타·기기코드 확인:
--     DIGITAL     · M          : 클릭 23,269,035 / 인바운드콜·방송횟수 NULL
--     DIGITAL     · PC         : 클릭  7,498,255 / 인바운드콜·방송횟수 NULL
--     REBROADCAST · (해당없음) : 인바운드콜 113,241 · 방송횟수  2,059 / 클릭 NULL
--     VIDEO       · (해당없음) : 인바운드콜  52,221 · 방송횟수 34,653 / 클릭 NULL
--   → 기기 코드가 'M'/'PC'/'(해당없음)' 임을 확인(=SV comment 와 일치). 'MOBILE' 아님.

-- (5-5) 방송 전용 축 조인 (채널사 61종)
SELECT CHANNEL_COMPANY, TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.CHANNEL_COMPANY
  METRICS TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
)
WHERE CHANNEL_COMPANY IS NOT NULL
ORDER BY TOTAL_AD_COST DESC
LIMIT 10;
--   ⚠ TOTAL_DVLP_CNT 는 커버리지 5.2% 부분합 — 채널사별 개발 규모 비교에 쓰지 말 것(§6-5).

-- (5-6) 방송 개발단가 미노출 확인 — 아래는 **에러가 나야 정상**(metric 미존재)
--   SELECT BRDC_DEV_UNIT_PRICE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS BRDC_DEV_UNIT_PRICE);
--   → "invalid identifier" 계열 오류 기대. 2026-07-28 커버리지 결함(41% 왜곡)으로 제거됨(04 §6.4.1).

-- (5-7) 배포된 SV 구조 확인 — dim 20 · metric 15
DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_AD;


/* =====================================================================================
   §6. 현업 확인 필요 항목 (SQL 아님 — 어의 확정용 근거 쿼리)
        03 §8.5 §6-H·§6-I 로 등록된 잔여 합의 플래그.
   ===================================================================================== */
-- (6-1) §6-H: CRM_DEV_CNT 소수값 실태 — "개발건수"인데 소수인 이유 확인 필요
SELECT COUNT(*)                                        AS rows_with_val,
       COUNT_IF(CRM_DEV_CNT != FLOOR(CRM_DEV_CNT))     AS non_integer_rows,
       MIN(CRM_DEV_CNT)                                AS min_val,
       MAX(CRM_DEV_CNT)                                AS max_val,
       SUM(CRM_DEV_CNT)                                AS total_val
FROM GN_DW.GOLD.FACT_AD_DIGITAL
WHERE CRM_DEV_CNT IS NOT NULL;
--   소수 행이 존재하면 → 기여도 배분(fractional attribution) 가능성 → 현업 확인 전 "건수" 단정 금지
--   ▶ 2026-07-28 실측 결과: rows_with_val=189,252 · **non_integer_rows=24,614(13.0%)** ·
--     min=0.0 · max=322.0 · total=249,390.45 → **소수값 실재 확정**. 03 §8.5 §6-H 로 등록.

-- (6-2) §6-H: 2026-06 NULL 여부 (적재 지연인지 확인)
SELECT d.YEAR, d.MONTH,
       COUNT(*)                        AS rows_total,
       COUNT(c.CRM_DEV_CNT)            AS rows_with_dev_cnt,
       SUM(c.CRM_DEV_CNT)              AS sum_dev_cnt
FROM GN_DW.SERVING.FACT_AD_COMBINED c
JOIN GN_DW.GOLD.DIM_DATE d ON c.PERF_DATE_SK = d.DATE_SK
WHERE c.AD_SOURCE_TYPE = 'DIGITAL' AND d.YEAR = 2026
GROUP BY 1, 2
ORDER BY 1, 2;

-- (6-3) §6-G/§6-J: 자체계산 개발단가 vs 대행사 산정 DEV_UNIT_PRICE_SRC
SELECT d.YEAR,
       SUM(CASE WHEN c.CRM_DEV_CNT IS NOT NULL THEN c.AD_COST END)
         / NULLIF(SUM(c.CRM_DEV_CNT), 0)              AS dev_unit_price_calc,
       AVG(c.DEV_UNIT_PRICE_SRC)                      AS dev_unit_price_src_avg,
       COUNT(c.CRM_DEV_CNT)                           AS rows_crm_dev,
       COUNT(c.DEV_UNIT_PRICE_SRC)                    AS rows_src
FROM GN_DW.SERVING.FACT_AD_COMBINED c
JOIN GN_DW.GOLD.DIM_DATE d ON c.PERF_DATE_SK = d.DATE_SK
WHERE c.AD_SOURCE_TYPE = 'DIGITAL'
GROUP BY 1
ORDER BY 1;
--   ▶ 2026-07-28 실측: 2024·2025 = calc만 존재(src 0행) / 2026 = calc 103,066원 + src_avg 29,018원(8,401행)
--     **교차검증 불가** — 두 컬럼은 완전 상호배타(아래 6-4가 근거). 같은 행에 공존하지 않으므로
--     "자체값 vs 대행사값 검증"이 아니라 **기간 보완 관계**다. 04 §6.4.2 · 03 §6-G 정정 반영됨.
--   ⚠ DEV_UNIT_PRICE_SRC 는 행 단위 비율(N, 비가산) — AVG는 분포 확인용 참고일 뿐
--     정본 지표로 쓰지 말 것(SV metric 미노출 · Agent instruction으로 재집계 차단됨)

-- (6-4) §6-J 근거: 2026-06 원천 포맷 변경 (적재 지연이 아님)
SELECT d.YEAR, d.MONTH,
       COUNT(*)                        AS rows_total,
       COUNT(c.CRM_DEV_CNT)            AS rows_crm_dev,
       COUNT(c.DEV_UNIT_PRICE_SRC)     AS rows_src
FROM GN_DW.SERVING.FACT_AD_COMBINED c
JOIN GN_DW.GOLD.DIM_DATE d ON c.PERF_DATE_SK = d.DATE_SK
WHERE c.AD_SOURCE_TYPE = 'DIGITAL' AND d.YEAR = 2026
GROUP BY 1, 2 ORDER BY 1, 2;
--   ▶ 2026-07-28 실측: 2026-01~05 = crm_dev 전건 / src 0  ‖  2026-06 = crm_dev **0** / src **8,401 전건**
--     → 원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 변경됨.
--     ▶▶ **현업·파이프라인 결정 필요**: 2026-06 이후 개발단가를 계속 추적하려면
--         (a) 원천에 개발건수 재요청  또는  (b) DEV_UNIT_PRICE_SRC 채택(정의가 다름 — 대행사 기준)

-- (6-5) 비율 metric 분자·분모 커버리지 정합 점검 (04 §6.4.1 — 신규 비율 metric 추가 시 필수 체크)
SELECT AD_SOURCE_TYPE,
       COUNT(*)                                                          AS rows_total,
       COUNT(CRM_DEV_CNT)                                                AS rows_denom_dig,
       COUNT(DVLP_CNT)                                                    AS rows_denom_brc,
       SUM(AD_COST)/NULLIF(SUM(CRM_DEV_CNT),0)                            AS dig_unaligned,
       SUM(CASE WHEN CRM_DEV_CNT IS NOT NULL THEN AD_COST END)
         /NULLIF(SUM(CRM_DEV_CNT),0)                                      AS dig_aligned,
       SUM(AD_COST)/NULLIF(SUM(DVLP_CNT),0)                               AS brc_unaligned,
       SUM(CASE WHEN DVLP_CNT IS NOT NULL THEN AD_COST END)
         /NULLIF(SUM(DVLP_CNT),0)                                         AS brc_aligned
FROM GN_DW.SERVING.FACT_AD_COMBINED
GROUP BY 1 ORDER BY 1;
--   ▶ 2026-07-28 실측 판정:
--     디지털 개발단가: 분모 커버리지 95.7% · 미정합 119,951 vs 정합 114,870 = +4.4% → **분자 정합 후 노출** ✅
--     방송 개발단가  : 분모 커버리지  5.2% · 미정합 223,466 vs 정합 157,969 = +41%  → **SV 미노출 결정** ❌
--   ▶ 규칙: 신규 SUM/SUM 비율 metric 은 (1) 분모 커버리지가 90% 미만이면 정합해도 노출 재검토,
--          (2) 분자는 항상 `CASE WHEN <분모> IS NOT NULL THEN <분자> END` 로 제한한다.


/* =====================================================================================
   §7. 이번 변경으로 확인된 구조적 제약 (재현·확장 시 참고)
   ===================================================================================== */
--   (7-1) Snowflake semantic view 의 METRIC 식은 **자기 logical table 컬럼만 참조 가능**.
--         cross-table 비율(예: SUM(fap.AD_COST) / SUM(dig.CRM_DEV_CNT))은 RELATIONSHIPS 가
--         선언돼 있어도 컴파일 실패 → "invalid identifier 'DIG.CRM_DEV_CNT'".
--         해결: 1:1 로 안전하게 결합되는 팩트는 **SERVING helper 뷰로 pre-join** 후 단일 base 사용.
--         (04 §6.0 · 기존 DIM_MONTH·DIM_MEMBER_CURRENT helper 패턴과 동일 계열)
--
--   (7-2) `CREATE OR REPLACE` 는 SEMANTIC VIEW·AGENT 공통으로 **GRANT를 전부 삭제**한다
--         (OWNERSHIP만 잔존). AGENT는 추가로 **CoWork SI 등록도 소실**.
--         → 단일 객체 재배포 시 해당 GRANT 재실행을 절차에 포함할 것.
--         → Agent는 `ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION`(비파괴) 우선.
--
--   (7-3) GOLD 스키마에 FUTURE TABLES/VIEWS grant 가 걸려 있어(07_ENVIRONMENT_RBAC_setup.sql
--         §D) 파이프라인이 새로 만든 FACT_AD_* · DIM_DEVICE 는 소비 3역할에 **자동 SELECT 부여**.
--         반면 SERVING 은 FUTURE grant 가 없어 helper 뷰는 **명시 GRANT 필요**(05 §6-0에 포함).
--
--   (7-4) FACT_AD_BROADCAST_CASE(5,327행)는 코어 FAP과 **1:N** → helper 뷰에 포함하면 광고비가
--         중복 팽창한다. 의도적으로 FACT_AD_COMBINED·SV_AD 에서 **제외**했다(04 §6.8).
--         사례 소구점(APPEAL_POINT 24·FAMILY_TYPE 13) 분석이 필요하면 **별도 SV**로 분리할 것.
--
--   (7-5) **저카디널리티 코드 차원은 comment에 실제 코드값을 열거해야 한다**.
--         2026-07-28 초기 배포본이 DEVICE_TYPE comment를 "PC/MOBILE/TABLET 등"으로 기재했는데
--         실제 코드값은 `M`(모바일) / `PC` / `(해당없음)`(방송) / `(unknown)`(센티넬) 4종이었다.
--         → Cortex Analyst 가 comment 를 근거로 `DEVICE_TYPE='MOBILE'` 을 생성하면 **0행 반환**(무증상 오답).
--         → 같은 세션에서 comment 정정 + AI_SQL_GENERATION 규칙(4) 추가 후 재배포·재GRANT 완료.
--         ▶ 재현 시 05 파일의 현재 버전에는 이미 정정본이 반영되어 있어 추가 조치 불요.
--         ▶ 교훈: 다른 SV의 코드 차원(회원상태·회원구분·발송상태·예산구분 등)도 동일 점검 대상.
--            아래 쿼리로 실제 코드값을 확인해 comment 와 대조할 것.
/*
SELECT 'MEMBER_STATUS' AS dim, MEMBER_STATUS AS code_value, COUNT(*) AS cnt
FROM GN_DW.SERVING.DIM_MEMBER_CURRENT GROUP BY 2
UNION ALL SELECT 'MEMBER_TYPE', MEMBER_TYPE, COUNT(*) FROM GN_DW.SERVING.DIM_MEMBER_CURRENT GROUP BY 2
ORDER BY 1, 3 DESC;
*/

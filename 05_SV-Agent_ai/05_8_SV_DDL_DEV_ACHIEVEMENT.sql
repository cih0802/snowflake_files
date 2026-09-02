-- GN_DW 3단계: Semantic View DDL 정본 — SV_DEV_ACHIEVEMENT (회원개발 목표 대비 실적)
-- Co-authored with CoCo
-- 🔴🔴 [2026-08-10 O53] **base 객체가 개명·테이블화됐다** — `GOLD.WIDE_DEV_ACHIEVEMENT`(뷰) →
--   `GOLD.FACT_DEV_ACHIEVEMENT`(테이블). 팩트 2종을 FULL OUTER 로 재구성하는 객체라 이름과 실질을 맞췄다.
--   ⚠️ 이 SV 는 **`CREATE OR ALTER SEMANTIC VIEW` 로 재배포**할 것 — `CREATE OR REPLACE` 는 GRANT 를
--      파괴한다(O52-B 에서 실제로 SV 2종의 GRANT 를 파괴했다 · P125). 재배포 후 GRANT 는 소유자 세션이
--      아니라 **소비 역할 세션으로 판정**한다(P126) — 검사는 `scripts/sv_unit_gate.py` 가 한다.
--   ⚠️ base 가 dbt 소유 객체이므로 이 SV 는 `dbt build` 이후에만 배포된다(DEC-34 ③ 계열).
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O38 신설]
--   대상 SV = **SV_DEV_ACHIEVEMENT** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
--   🔴 [2026-08-10 O54] 본문 DDL 은 **`CREATE OR ALTER SEMANTIC VIEW`** 다 — GRANT 를 보존하므로
--      재실행 시 아래 GRANT 절은 멱등 재확인 용도다(파괴 후 복구가 아니다 · P125).
--
-- ▶ 무엇을 답하는 SV 인가
--   마케팅 장표 **「1. 개발현황(목표, 실적)」** 의 정본이고, 정본 지표
--   **공#1 월 목표 달성율 · #2 누계 목표 달성율 · #3 연 목표 달성율** 을 산출한다.
--   base = `GN_DW.GOLD.FACT_DEV_ACHIEVEMENT`(FTG_D 목표 × FME 실적 FULL OUTER 월 conform).
--
--   🔴 **O38 이전에는 이 SV 를 만들 수 없었다** — 선행 결함 2건이 이번에 해소됐다:
--     ① `FACT_TARGET_DEV.MONTH_KEY` 가 1~12(월 번호)라 연도 conform 자체가 불가능했다
--     ② `FACT_MEMBER_EVENT.ORG_SK` 가 전건 센티넬이라 부서 축이 없었다(장표의 첫 축이 부서명이다)
--
--   🔴 **파일 규약·선행 조건·정본 근거의 정본 = `05_0_SV_DDL.sql` §공통 규약** (2026-08-10 O55 DUP-1).
--      독립 실행 · 파일 간 순서 무관 · 재실행 반영 · `CREATE OR ALTER`(GRANT·소유권 보존) ·
--      분할 이력(O37) · 선행 조건은 `dbt build` **하나** · 실행 역할 `GN_DW_ADMIN`.
--      ⛔ 이 항목들을 이 파일에 다시 복제하지 말 것 — 그것이 P140(9중 중복)의 원인이었다.
--
-- ▶ 설계 판단 4가지 — 각각 근거가 있다
--
--   **(1) 단일 논리테이블로 만든다** — R1 fan-out 규칙은 「월 팩트를 `DIM_MONTH` 로 조인해
--     fan-out 을 막으라」는 것인데, base 뷰가 이미 `CAL_YEAR`·`CAL_MONTH`·`ORG_DEPARTMENT`·
--     `DEV_TYPE_NAME` 을 degenerate 로 평탄화해 갖고 있다. 조인이 0 이면 fan-out 위험도 0 이다.
--     실측 PK 유일성: `(MONTH_KEY, ORG_SK, DEV_TYPE)` 37,522행 = 37,522 distinct.
--
--   **(2) 누계·연 metric 을 따로 만들지 않는다** — 이게 핵심이다.
--     base 뷰에는 `GOAL_CNT_YTD`·`GOAL_CNT_YEAR` 같은 사전계산 컬럼이 있지만
--     이들은 **월에 대해 비가산**이라 SV 에 measure 로 올리면 Analyst 가 월을 가로질러 SUM 해
--     같은 값을 반복 누적한다. `MAX()` 로 올려도 조직을 가로지를 때 합이 아니라 최대값이 되어 틀린다.
--     🟢 **필요가 없다**: 목표·실적은 가산이므로 **같은 metric 이 시간 필터에 따라 3개 지표를 다 답한다** —
--        · 월 목표/실적 = 단월 필터  · 누계 = 1월~기준월 필터  · 연 = 연 전체 필터
--     → 사전계산 컬럼은 **SV 에서 아예 제외**한다(오용 가능 축은 노출하지 않는다는 프로젝트 규약).
--        BI·직접 SQL 에서는 base 뷰의 해당 컬럼을 쓰면 된다.
--
--   **(3) 달성율의 분모 스코프를 metric 식에 못박는다** — 지시가 아니라 구조로 막는다.
--     목표는 일부 조직·기간에만 편성돼 있고 실적은 더 넓은 범위에서 발생한다. 목표가 없는
--     조직·월의 실적을 분자에 넣으면 달성율이 조용히 과대해진다. P18·P63 유형이다.
--     → 분자를 `CASE WHEN GOAL_CNT > 0 THEN ACTUAL_CNT END` 로 감싸 **Analyst 가 틀릴 수 없게** 했다.
--
--     🔴 **스코프 조건이 「행 존재」가 아니라 `GOAL_CNT > 0` 인 이유 — 최초 배포에서 내가 틀렸다.**
--        (base 뷰는 이후 `HAS_GOAL_ROW` / `HAS_POSITIVE_GOAL` 로 개명·분리됐다. 아래는 그 경위다.)
--        `HAS_GOAL`(목표 행 존재)로 스코프했더니 **증액 537.1% · 재후원 1700.9%** 가 나왔다.
--        원인: CRM 은 **목표를 0 으로 등록한 행**을 다수 보유한다(실측 목표 행의 절반 이상).
--        그 행들은 `HAS_GOAL=TRUE` 라 실적이 분자에 들어가는데 분모 기여는 0 이다 →
--        분모 없이 분자만 늘어 비율이 폭증했다.
--        교정 후: 신규 34.3% · 증액 65.9% · 재후원 74.3% (전부 100% 이하).
--        → 교훈: **「키가 존재한다」와 「값이 편성됐다」는 다르다.** 비율 스코프는 행 존재가 아니라
--          **분모 값의 유효성**으로 잡는다. 그리고 비율 metric 은 **100% 초과 여부를 반드시 스모크**한다
--          (O37 에서 같은 유형을 이미 겪었는데 조건을 잘못 골라 재발시켰다).
--     ⚠️ 그 결과 `ACHIEVEMENT_RATE` ≠ `TOTAL_ACTUAL_CNT / TOTAL_GOAL_CNT` 다. 의도된 불일치이며
--        검산용 분자를 `TOTAL_ACTUAL_CNT_ON_GOAL` metric 으로 별도 노출했다.
--
--     🟢 **[2026-08-05 후속] `HAS_POSITIVE_GOAL` 차원은 표현식이 아니라 base 뷰의 물리 컬럼을 참조한다.**
--        최초 배포 시점에는 뷰에 그 컬럼이 없어 `GOAL_CNT > 0` 식으로 선언했는데, 같은 규칙이 뷰와 SV
--        두 곳에 살면 한쪽만 바뀌어도 드리프트를 알 수 없다. 컬럼이 생긴 뒤 참조로 전환해 **판정 규칙의
--        정본을 뷰 하나로 모았다**(값 동일 — 전환 전후 달성율·플래그 카운트 실측 대조로 확인).
--        ⚠️ metric 식의 `GOAL_CNT > 0` 은 **의도적으로 남긴다** — 분모(`SUM(GOAL_CNT)`)와 분자 스코프가
--        같은 컬럼에서 나와야 둘이 어긋날 수 없다. 차원은 「사용자가 거는 필터」이고 metric 의 조건은
--        「Analyst 가 틀릴 수 없게 하는 구조 가드」로 역할이 다르다.
--
--   **(4) 전건 NULL 축은 노출하지 않는다** — `ORG_DIVISION`·`ORG_TEAM`·`ORG_CORP` 는 CONF-4 로
--     산출규칙 미확정·보류·산출불가 상태라 base 뷰에서 전건 NULL 이다. 노출하면 Analyst 가
--     "지부별로 보여줘"에 **0행 무증상 오답**을 낸다(§6.9-(5)·AD-4 유형). 부서(`ORG_DEPARTMENT`)만 낸다.
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R5 가산성  : F(flow)=SUM / 비율=분자·분모 각각 집계 후 division. ✅ 준수
--   PRIMARY KEY: 실측 유일한 것만 선언. ✅ (MONTH_KEY, ORG_SK, DEV_TYPE) 유일 실측
--   P65        : metric 명이 컬럼명을 가리지 않게 한다 → `TOTAL_` 접두로 base 컬럼명과 분리
--   COMMENT 규약: 🔴 **수치를 넣지 않는다**(Agent 가 인용 → 적재량 변하면 거짓이 된다).
--                단 **모집단 차이 경고**는 수치가 아니라 구조 서술이므로 남긴다.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   8. SV_DEV_ACHIEVEMENT (member Agent) — base FACT_DEV_ACHIEVEMENT(월×조직×개발구분)
      활성: 월 목표·월 실적·달성율(공#1) · 누계/연은 동일 metric + 기간 필터(공#2·#3)
            차원 = 연/월/연월 · 부서명 · 개발구분(코드·라벨) · 목표편성여부(GOAL_CNT>0) · 실적발생여부
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  TABLES (
    achv AS GN_DW.GOLD.FACT_DEV_ACHIEVEMENT
      PRIMARY KEY (MONTH_KEY, ORG_SK, DEV_TYPE)
      WITH SYNONYMS ('개발목표', '개발실적', '목표대비실적', '개발현황')
      COMMENT = '회원개발 목표 대비 실적(grain=월×조직×개발구분, 실측 유일 → PK). 목표와 실적을 FULL OUTER 로 결합해 한쪽만 있는 조합도 보존한다 — 목표는 미래월까지 편성돼 있고 실적은 목표 편성 이전 기간에도 존재한다. 🔴CRM 은 목표를 **0 으로 등록한 행**도 다수 보유한다(목표 행 존재 ≠ 목표 편성) — 달성율 분모·분자는 반드시 GOAL_CNT>0 으로 스코프해야 한다. [원천] 목표: 시스템=CRM · BRONZE=GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL(STDYY 기준연·STDR_MT 기준월·MBER_DVLP_DIV_CD 개발구분·DEPT_ID 부서·GOAL_CNT 목표수) → SILVER=CRM_DEV_TARGET → GOLD=FACT_TARGET_DEV. 실적: 시스템=CRM · BRONZE=GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT → SILVER=CRM_MEMBER_DEV → GOLD=FACT_MEMBER_EVENT(DEV_CNT 월 롤업). 조직 라벨=GOLD.DIM_ORG · 개발구분 라벨=CRM 코드사전 MM015.'
  )
  DIMENSIONS (
    achv.MONTH_KEY AS achv.MONTH_KEY
      WITH SYNONYMS ('연월', '목표월', '기준연월', '실적월')
      COMMENT = 'YYYYMM 정수. 목표와 실적의 공통 월 축.',
    achv.CAL_YEAR AS achv.CAL_YEAR
      WITH SYNONYMS ('연도', '년', '목표연도')
      COMMENT = '연도. 연 목표·연 실적(정본 공#3)은 이 축으로 그룹하면 산출된다 — 별도 metric 이 필요 없다.',
    achv.CAL_MONTH AS achv.CAL_MONTH
      WITH SYNONYMS ('월')
      COMMENT = '월(1~12). 누계(정본 공#2)는 이 값에 범위 조건(1~기준월)을 걸어 산출한다.',
    achv.ORG_DEPARTMENT AS achv.ORG_DEPARTMENT
      WITH SYNONYMS ('부서', '부서명', '실적부서', '담당부서')
      COMMENT = '부서명(정본 #116). 장표의 첫 축이다. 실적측은 실적부서(원천 ACMSLT_DEPT_CD) 기준으로 귀속된다. 값 ''(미매핑)''은 부서코드가 조직 마스터에 없는 소수 행이다. ⚠️본부/지부·팀·법인 축은 이 SV 에 없다 — 산출규칙 미확정(CONF-4)이라 값이 존재하지 않으며, 요청받으면 부서 단위까지만 가능하다고 답할 것(추정 금지). ⚠️조직 개편으로 목표만 편성되고 실적은 다른 부서로 귀속된 부서가 존재한다 — 달성율이 0 에 가까운 부서를 「실적 부진」으로 단정하지 말고 해당 연도에 실적이 아예 없는지 확인할 것. 🔴부서 목표 규모의 편차가 매우 크다 — 월 한 자리 수 목표인 소규모 센터와 수천 건 목표인 부서가 같은 축에 있다. **달성율 순위·「최우수 부서」 판정에는 반드시 TOTAL_GOAL_CNT 를 함께 제시**하고, 목표 규모가 극소한 부서를 단독 1위로 결론하지 말 것. 소규모 부서는 실적 몇 건으로 달성율이 100% 를 넘으며 이는 스코프 결함이 아니라 실제 초과 달성이다.',
    achv.DEV_TYPE AS achv.DEV_TYPE
      WITH SYNONYMS ('개발구분코드')
      COMMENT = '개발구분 코드 raw. 실제값은 1(신규)·2(증액)·4(재후원) 세 가지뿐이다 — 정본 공#121 개발 정의와 일치한다. 라벨은 DEV_TYPE_NAME. ⚠️감액(3)·후원중단(5)은 개발이 아니므로 목표·실적 양쪽에 없다. 실제값 3종: ''1''·''2''·''4''',
    achv.DEV_TYPE_NAME AS achv.DEV_TYPE_NAME
      WITH SYNONYMS ('개발구분', '개발구분명', '개발유형')
      COMMENT = '개발구분명(CRM 코드사전 MM015 라벨) — 신규/증액/재후원. 코드는 DEV_TYPE. 🔴목표 편성은 개발구분별로 관행이 크게 다르다 — 증액·재후원은 최근 연도에 목표가 0 으로 등록돼 있어 그 기간 달성율이 산출되지 않는다(현업 확인 대기). 구분별 달성율을 비교할 때 이 비대칭을 함께 밝힐 것. 실제값 3종: ''신규''·''증액''·''재후원''',
    achv.HAS_POSITIVE_GOAL AS achv.HAS_POSITIVE_GOAL
      WITH SYNONYMS ('목표편성여부', '목표있음', '목표편성')
      COMMENT = 'TRUE=해당 월×부서×구분에 **0 보다 큰 목표가 편성**돼 있다. 🔴달성율 metric 이 이 조건으로 분자를 이미 스코프하므로 사용자가 따로 필터할 필요는 없다. 「목표가 편성된 부서만」 같은 요청에 이 축을 쓴다. ⚠️CRM 에 목표 0 으로 등록된 행이 다수 있어 「목표 행이 존재한다」와 「목표가 편성됐다」는 다르다 — 이 축은 후자다.',
    achv.HAS_ACTUAL AS achv.HAS_ACTUAL
      WITH SYNONYMS ('실적발생여부', '실적있음')
      COMMENT = 'TRUE=해당 월×부서×구분에 개발 실적이 발생했다. FALSE 는 목표만 편성된 월이며 **아직 오지 않은 미래월도 포함**한다 — 「미달」로 단정하지 말 것.'
  )
  METRICS (
    achv.TOTAL_GOAL_CNT AS SUM(achv.GOAL_CNT)
      WITH SYNONYMS ('월 목표', '개발목표', '회원개발목표', '목표건수', '연 목표', '누계 목표')
      COMMENT = '회원개발목표(건) 합계. F(가산). 🟢단월 필터=월 목표 · 1월~기준월 필터=누계 목표 · 연 그룹=연 목표 — **하나의 metric 이 세 지표를 모두 답한다**(별도 누계·연 metric 이 없는 이유다).',
    achv.TOTAL_ACTUAL_CNT AS SUM(achv.ACTUAL_CNT)
      WITH SYNONYMS ('월 실적', '개발실적', '개발건', '개발건수', '연 실적', '누계 실적')
      COMMENT = '개발실적(건) 합계 — 정본 공#121 개발(신규·증액·재후원) 기준. F(가산). ⚠️여기에는 **목표가 편성되지 않은 부서·월의 실적도 포함**된다. 그래서 이 값을 TOTAL_GOAL_CNT 로 직접 나누면 달성율이 과대해진다 — 달성율은 반드시 ACHIEVEMENT_RATE 를 쓸 것.',
    achv.TOTAL_ACTUAL_CNT_ON_GOAL AS SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END)
      WITH SYNONYMS ('목표편성분 실적', '달성율 분자')
      COMMENT = '목표가 편성된(GOAL_CNT>0) 월×부서×구분의 개발실적(건). F(가산). ACHIEVEMENT_RATE 의 **분자**다 — 달성율을 검산하고 싶을 때 TOTAL_GOAL_CNT 와 함께 쓴다. TOTAL_ACTUAL_CNT 보다 작다(목표 미편성분 제외).',
    achv.ACHIEVEMENT_RATE AS SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) / NULLIF(SUM(achv.GOAL_CNT), 0) * 100
      WITH SYNONYMS ('목표 달성율', '달성율', '목표대비 개발', '월 목표 달성율', '누계 목표 달성율', '연 목표 달성율', '목표달성률')
      COMMENT = '목표 달성율(%) = 개발실적 ÷ 회원개발목표 ×100. 비율(N) — 상위 집계 시 분자·분모를 각각 합산해 재계산한다. 정본 공#1(월)·#2(누계)·#3(연)을 **동일 식**으로 답한다: 기간 필터만 바꾼다. 🔴**분자가 목표 편성분(GOAL_CNT>0)으로 스코프돼 있다** — 목표가 0 인 행의 실적이 분자에 들어가면 분모 없이 비율이 폭증하기 때문에 식에 못박았다. ⚠️따라서 TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 와 값이 다르다(그쪽이 과대). 손으로 검산하려면 TOTAL_ACTUAL_CNT_ON_GOAL ÷ TOTAL_GOAL_CNT 를 쓸 것.'
  )
  COMMENT = 'Phase-1 회원개발 목표 대비 실적 SV (base: GOLD.FACT_DEV_ACHIEVEMENT, grain: 월×부서×개발구분 1행). CRM 목표(FACT_TARGET_DEV) 및 실적(FACT_MEMBER_EVENT) 월 conform 기반 월/누계/연 목표(TOTAL_GOAL_CNT), 실적(TOTAL_ACTUAL_CNT), 정본 달성율(ACHIEVEMENT_RATE, %) 뷰. ⚠️ 주간 실적은 SV_MEMBER_EVENT(일/주차 grain) 소관이며, 본 뷰는 월 단위 목표 대비 실적의 정본.'
  AI_SQL_GENERATION '핵심 규칙: (1) 시간 스코프: 월 목표/실적/달성율은 단일 연월 필터, 누계는 당해 연도 1월~기준월 필터, 연간은 연도 필터 적용 (별도 누계 metric 불필요). (2) 달성율 정본: 달성율은 항상 ACHIEVEMENT_RATE (%) 사용 (TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 직접 계산 금지). (3) 목표 0 처리: 목표 편성 부서 한정 시 HAS_POSITIVE_GOAL=TRUE 사용. (4) 주간 분기: 주간 개발실적은 SV_MEMBER_EVENT 로 라우팅하며, 주간 목표는 원천 부재로 산출 불가.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다(§129 실측) →
         아래 GRANT 는 멱등 재확인이다. ⛔ `CREATE OR REPLACE` 로 되돌리면 GRANT 가 파괴된다(P125).
      🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로 한다(P126) — `scripts/sv_unit_gate.py`.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DEV_ACHIEVEMENT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DEV_ACHIEVEMENT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_DEV_ACHIEVEMENT TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 — 이 SV 만의 검증 (전체 배포 검증은 `05_0_SV_DDL.sql`)
   ===================================================================================== */

-- (D-1) fan-out 0 검증: SV 총계 == base 뷰 총계
--   판정: 두 행의 GOAL·ACTUAL 이 각각 일치해야 한다(단일 논리테이블이라 어긋나면 정의 오류다)
SELECT 'SV' AS SRC, TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT
)
UNION ALL
SELECT 'BASE', SUM(GOAL_CNT), SUM(ACTUAL_CNT)
FROM GN_DW.GOLD.FACT_DEV_ACHIEVEMENT;

-- (D-2) 정본 공#3 — 연 목표 달성율 (별도 metric 없이 연 그룹만으로 나오는가)
--   판정: 완결연도가 상식적 범위(수십 %)에 들어오고 **100% 를 넘지 않는다**. 진행 중 연도는 낮게
--         나오는 것이 정상이다(실적 미도달월이 분모에 포함되기 때문 — AI_SQL_GENERATION 이 스코프를 지시한다)
SELECT CAL_YEAR, TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ROUND(ACHIEVEMENT_RATE, 1) AS ACHV_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  DIMENSIONS achv.CAL_YEAR
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ACHIEVEMENT_RATE
)
ORDER BY CAL_YEAR;

-- (D-3) 🔴 스코프 가드 실증 — metric 의 달성율과 손으로 나눈 값이 다른지
--   판정: ACHV_PCT(스코프) < NAIVE_PCT(미스코프). 같게 나오면 가드가 식에서 빠진 것이다.
--   검산: ACHV_PCT == ON_GOAL_PCT (분자 metric 으로 손계산한 값과 일치해야 한다)
SELECT ROUND(ACHIEVEMENT_RATE, 2) AS ACHV_PCT,
       ROUND(TOTAL_ACTUAL_CNT_ON_GOAL / NULLIF(TOTAL_GOAL_CNT, 0) * 100, 2) AS ON_GOAL_PCT,
       ROUND(TOTAL_ACTUAL_CNT / NULLIF(TOTAL_GOAL_CNT, 0) * 100, 2) AS NAIVE_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, TOTAL_ACTUAL_CNT_ON_GOAL, ACHIEVEMENT_RATE
);

-- (D-3b) 🔴🔴 **비율 상한 불변식 — 이 SV 에서 가장 중요한 스모크다**
--   최초 배포에서 분자를 `HAS_GOAL`(목표 행 존재)로 스코프했더니 증액 537% · 재후원 1700% 가 나왔다.
--   원인은 CRM 이 **목표를 0 으로 등록한 행**을 다수 보유하는 것이었다(행은 있고 값은 0).
--   fan-out·행수·참조무결성은 전부 정상이었고 **100% 초과 검사만이 이걸 잡는다**.
--   판정: **0행이어야 한다.** 한 행이라도 나오면 분자 스코프가 분모와 어긋난 것이다.
SELECT DEV_TYPE_NAME, CAL_YEAR, ROUND(ACHIEVEMENT_RATE, 2) AS ACHV_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  DIMENSIONS achv.DEV_TYPE_NAME, achv.CAL_YEAR
  METRICS ACHIEVEMENT_RATE
)
WHERE ACHIEVEMENT_RATE > 100
ORDER BY ACHV_PCT DESC;

-- (D-3c) 목표 0 등록 행의 규모 — 가드가 왜 필요한지 base 에서 직접 확인
--   판정: ZERO_GOAL_ROWS 가 **과반 규모**로 존재한다(0 이면 원천의 행 생성 방식이 바뀐 것) ·
--         IMPOSSIBLE_MUST_BE_ZERO = **0**
--   [2026-08-05 후속] base 뷰의 플래그가 `HAS_GOAL_ROW`(행 존재) / `HAS_POSITIVE_GOAL`(값 편성)로
--   분리됐다 — 종전 단일 `HAS_GOAL` 은 이름이 오해를 불러 이 결함의 직접 원인이었다.
SELECT COUNT_IF(HAS_GOAL_ROW AND NOT HAS_POSITIVE_GOAL) AS ZERO_GOAL_ROWS,
       COUNT_IF(HAS_POSITIVE_GOAL)                     AS POSITIVE_GOAL_ROWS,
       SUM(CASE WHEN HAS_GOAL_ROW AND NOT HAS_POSITIVE_GOAL THEN ACTUAL_CNT END) AS ACTUAL_ON_ZERO_GOAL,
       -- 불변식: 목표가 편성됐으면 목표 행은 반드시 존재한다 → 0 이어야 한다
       COUNT_IF(HAS_POSITIVE_GOAL AND NOT HAS_GOAL_ROW) AS IMPOSSIBLE_MUST_BE_ZERO
FROM GN_DW.GOLD.FACT_DEV_ACHIEVEMENT;

-- (D-4) 장표 첫 축 — 부서별 달성율 (O38 로 배선된 축이 실제로 분해되는가)
--   판정: 부서가 다수 종으로 나오고 (미매핑) 이 지배적이지 않아야 한다.
--         🔴 **이 grain 에서는 100% 초과가 정상이다** — D-3b(개발구분×연) 는 집계 grain 이라 초과가
--           곧 스코프 결함이지만, 부서 grain 에는 목표가 월 한 자리 수인 소규모 센터가 있어 실적 몇 건으로
--           100% 를 넘는다(실측 확인: 초과 부서의 분자가 전부 GOAL_CNT>0 행에서만 나온다 = 스코프 정상).
--           초과 부서를 보면 P73 재발로 오판하지 말고 먼저 base 에서 해당 부서 행의 GOAL_CNT 를 확인할 것.
--         ⚠️달성율이 0 에 가까운 부서가 있다 — 조직 개편으로 목표만 남고 실적이 다른 부서로
--           귀속된 경우다(실적 부진이 아니다). SV COMMENT·AI_SQL_GENERATION 에 경고를 넣었다
SELECT ORG_DEPARTMENT, TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT_ON_GOAL, ROUND(ACHIEVEMENT_RATE, 1) AS ACHV_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  DIMENSIONS achv.ORG_DEPARTMENT
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT_ON_GOAL, ACHIEVEMENT_RATE
)
WHERE TOTAL_GOAL_CNT > 0
ORDER BY ACHV_PCT DESC NULLS LAST
LIMIT 20;
--   ⚠ FILTER 절에 별칭 컬럼을 쓸 수 없어 바깥 WHERE 로 거른다(04 §6.9-(6))

-- (D-5) 개발구분 축 — 목표·실적이 같은 도메인{신규·증액·재후원}으로 분해되는가
--   판정: 3종만 나오고 양쪽 모두 값이 있어야 한다(모집단 일치의 실증).
--         🔴 전 구분 **100% 이하**여야 한다 — 여기서 폭증이 처음 드러났다(D-3b 가 자동 검사한다)
SELECT DEV_TYPE_NAME, TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ROUND(ACHIEVEMENT_RATE, 1) AS ACHV_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  DIMENSIONS achv.DEV_TYPE_NAME
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ACHIEVEMENT_RATE
)
ORDER BY TOTAL_GOAL_CNT DESC NULLS LAST;

-- (D-6) 정본 공#2 — 누계 달성율이 기간 필터만으로 나오는가 (최신 연도 상반기 예시)
--   판정: 단월 대비 누계가 증가하고 비율이 상식적 범위에 있어야 한다
SELECT CAL_MONTH, TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ROUND(ACHIEVEMENT_RATE, 1) AS ACHV_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  DIMENSIONS achv.CAL_YEAR, achv.CAL_MONTH
  METRICS TOTAL_GOAL_CNT, TOTAL_ACTUAL_CNT, ACHIEVEMENT_RATE
)
WHERE CAL_YEAR = 2025
ORDER BY CAL_MONTH;

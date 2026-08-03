-- GN_DW 3단계: Phase-1 Semantic View DDL 정본 — 최초 배포·재배포 공용(단일 파일)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상
--   SV 6종(SV_MEMBER_MONTHLY·SV_MEMBER_EVENT·SV_SERVICE·SV_EVENT_PARTICIPATION·SV_BUDGET·SV_AD)
--   + helper 뷰 FACT_AD_COMBINED + GRANT + 스모크 검증의 **DDL 정본**.
--   최초 세팅과 변경 반영이 같은 파일이다 — 통째로 재실행하면 되고 별도 update 스크립트는 없다.
--   `CREATE OR REPLACE`가 GRANT를 파괴하지만 §7 GRANT가 같은 파일에 있어 자기완결적이다.
--   ※ 단일 SV만 재배포할 때는 해당 SV의 GRANT 3줄을 반드시 함께 실행할 것(§7 경고).
--   ※ (대안) `CREATE OR ALTER SEMANTIC VIEW`는 GRANT·materialization을 보존한다. 다만 tag 변경은
--     미지원이고 생략한 속성은 unset되므로, 전체 재배포에는 현행 `CREATE OR REPLACE` + GRANT 재실행을 유지한다.
--
-- ▶ 실행 순서 (신규 계정 재현)
--   02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql → dbt(BRONZE→GOLD) → **본 파일** → 09_AGENT_spec_구현.sql
--   ⚠ 본 파일을 반드시 `GN_DW_ADMIN` 역할로 실행한다(75행). ACCOUNTADMIN으로 만들면 소유권이 어긋나
--     이후 재배포가 권한 오류로 막힌다(복구 SQL은 §8-11 주석).
--
-- ▶ 정본 근거 (수치·이력·판정 경위는 본 파일에 두지 않고 아래 문서를 직독한다)
--   04_SV_설계.md            §0.1 helper뷰 · §0.3 가산성 · §1~6 SV구조 · **§6.9 구조적 제약 8건**
--   03_SV_metric_배속.md     지표별 분자/분모 직역 · **§8.5 미해결 플래그 + §8.5.1 근거 쿼리**
--   01_SV-Agent 작업계획.md  §3 3단계 · 원칙10(fan-out) · R1·R5 가산성 · 원칙6 한글 synonyms
--   02_SERVING_setup.sql     SERVING 스키마 · helper뷰(DIM_MONTH·DIM_MEMBER_CURRENT) · RBAC
--   30_output_share/04_컬럼계보매핑.md · 05_지표GOLD매핑.md   GOLD컬럼→SILVER→BRONZE 1:1 계보
--   Snowflake docs: /user-guide/views-semantic/sql
--
-- ▶ 가드레일 (위반 시 fan-out·가산성 오류)
--   R1 fan-out : 월팩트→SERVING.DIM_MONTH · 회원속성→SERVING.DIM_MEMBER_CURRENT ·
--                광고팩트→SERVING.FACT_AD_COMBINED(AD_PERF_DK 1:1 pre-join).
--                raw DIM_DATE/DIM_MEMBER 직접조인, 위성 3종 다중조인 금지.
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK)(다월 중복 방지) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: MEMBER_DK=VARCHAR(캐스팅 금지) · MONTH_KEY/DATE_SK/*_SK=NUMBER · AD_PERF_DK=VARCHAR(32).
--   PRIMARY KEY: 실측 유일한 것만 선언(FMM·FBD·ad). FME/FSE/FEP는 선언 grain이 비유일 → PK 미선언.
--                기저 FACT는 관계의 다측이라 참조되지 않아 PK 불요 · 집계 무해.
--   비활성 지표: 원천 미적재분은 SV에서 아예 제외한다. 빈 metric은 0/NULL을 사실처럼 반환하므로 금지.
--                적재 완결 시 metric만 추가(구조 불변).
--
-- ▶ COMMENT 작성 규약 🔴
--   1) **수치를 넣지 않는다** — 행수·합계·커버리지%·건수·금액·적재기간을 COMMENT에 쓰지 않는다.
--      Agent(Cortex Analyst)가 COMMENT를 답변 근거로 인용하므로, 박아둔 수치는 적재량이 바뀌는 순간
--      Agent가 틀린 값을 사실로 말하게 된다(계정 재현 시 전 수치 불일치 실측 · 04 §6.9-(8)).
--      수치가 필요한 판정은 03 §8.5.1 근거 쿼리로 그때그때 실행해 확인한다.
--   2) `[원천]` 절은 **테이블·컬럼 이름만** 적는다 — 형식:
--      `[원천] 시스템=<원천시스템> · BRONZE=<DB.스키마.테이블(핵심컬럼)> · SILVER=<정제테이블>`
--      BRONZE 스키마 4종: GN_DW.BRONZE_CRM(eCRM·UMS) · GN_DW.BRONZE_ERP(예산원장) ·
--                        GN_DW.BRONZE_AGENCY(대행사 일별 리포트) · GN_DW.BRONZE_GA4(GA4 일별 샤드)
--      컬럼 단위 완전 매핑은 넣지 않는다(토큰 낭비·이중화) → 30_output_share/04_컬럼계보매핑.md로 안내.
--   3) 저카디널리티 코드 차원은 **실제 코드값을 열거**한다. 코드값이 틀리면 Analyst가 0행을 반환하는
--      무증상 오답이 된다(DEVICE_TYPE 사례 · 04 §6.9-(5)).
--   4) 원천이 바뀌면 04_컬럼계보매핑.md 재생성 후 본 파일의 `[원천]` 절을 동기화한다.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;


/* =====================================================================================
   1. SV_MEMBER_MONTHLY (회원 Agent) — base FMM(월×회원)
      활성: 납입/청구 총액 · 공64 납부율 · 공80 미납회원 감소율 · 개발/중단 총건(A1)
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY
  TABLES (
    fmm AS GN_DW.GOLD.FACT_MEMBER_MONTHLY
      PRIMARY KEY (MONTH_KEY, MEMBER_DK)
      WITH SYNONYMS ('회원 월별 실적', '월간 회원 팩트')
      COMMENT = '회원 월별 스냅샷 팩트(grain=월×회원, 실측 유일 → PK). 회비/개발/중단 월 롤업. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 회비/청구 TM_PM_MBRFEE_ACMSLT(PAY_AMT·RQEST_AMT·PAY_STAT_CD)+TM_PM_DNTN_DTLS(PAY_AMT) · 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC · 증감 TM_MM_FDRM_MBER_IRSD(SPNSR_AMT·RDCAMT_YN) · SILVER=CRM_PAYMENT_BILLING·CRM_MEMBER_DEV·CRM_MEMBER_DISCONTINUE·CRM_MEMBER_AMT_CHANGE.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '조회월', '기간')
      COMMENT = '월 차원(DIM_DATE 월 grain DISTINCT). fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷(SCD2 IS_CURRENT). 불변/현재 속성 전용. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO(SEX·MBER_STAT_CD·RELATNSP_DIV_CD) ∪ TM_MM_ONCE_MBER_INFO(일시회원) + TH_MM_FDRM_MBER_STNG_DTLS(상태이력 SCD2) · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fmm_to_month  AS fmm (MONTH_KEY) REFERENCES month,
    fmm_to_member AS fmm (MEMBER_DK) REFERENCES member
  )
  DIMENSIONS (
    month.MONTH_KEY   AS month.MONTH_KEY WITH SYNONYMS ('연월', '조회연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR    AS month.YEAR      WITH SYNONYMS ('연도', '년', '해') COMMENT = '조회 연도',
    month.CAL_MONTH   AS month.MONTH     WITH SYNONYMS ('월', '몇월')       COMMENT = '월(1~12)',
    month.CAL_QUARTER AS month.QUARTER   WITH SYNONYMS ('분기')            COMMENT = '분기(1~4)',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')             COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(코드사전 CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'')을 노출했었다 — ''U''는 미상이 아니라 미상+법인+단체 혼합이었다(O26 교정)',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드')         COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종: ''1''국내남·''2''국내여·''3''외국남·''4''외국여·''5''외국기타·''6''단체·''7''기업·''8''기타 (+미기재 NULL 421행). ⚠회원 마스터에 ''0''은 존재하지 않는다 — sentinel ''0''은 개발·증감 원천(CRM_MEMBER_DEV 9행·CRM_MEMBER_AMT_CHANGE 1행)에만 있으므로 이 차원에 ''0'' 조건을 걸면 0행이다. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨. 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 국내/외국인 구분이 필요할 때 쓴다',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태', '상태') COMMENT = '현재 회원상태 라벨(정본 공#132, MM010). 실제값: ''1활동회원''~''12후원중단'' 라벨. 과거월 조회 시에도 현재 기준',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드')     COMMENT = '회원상태 원천코드(MM010 1~12). 라벨은 MEMBER_STATUS_NAME',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분', '구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드')     COMMENT = '회원구분 원천코드(MM018 1개인·2기업·3단체). 라벨은 MEMBER_TYPE_NAME',
    fmm.HAS_BILLING      AS fmm.HAS_BILLING      WITH SYNONYMS ('회비출처여부', '청구대상') COMMENT = 'TRUE=회비(billing) 원천 존재 행. 회비 지표는 TRUE 전제 권장.'
  )
  METRICS (
    fmm.TOTAL_PAID_FEE   AS SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('납입회비', '납입회비 총액', '수납액') COMMENT = '납입회비 합계(원). F(가산).',
    fmm.TOTAL_BILLED_AMT AS SUM(fmm.BILLED_AMT)
      WITH SYNONYMS ('청구금액', '청구액 총액') COMMENT = '청구금액 합계(원, 재청구 중복 포함). F(가산).',
    fmm.PAYMENT_RATE     AS SUM(fmm.PAID_FEE) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('납부율', '수납율') COMMENT = '공64 납부율(%) = 납입회비 ÷ 청구금액 ×100. 비율(N, 재집계 금지).',
    fmm.TOTAL_DEV_CNT    AS SUM(fmm.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건', '신규개발수') COMMENT = '개발(신규 후원) 건수 합계. F(가산). FME 월 롤업(A1).',
    fmm.TOTAL_STOP_CNT   AS SUM(fmm.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단(해지) 건수 합계. F(가산). FME 월 롤업(A1).',
    fmm.UNPAID_MEMBERS_BOM AS COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END)
      WITH SYNONYMS ('월초 미납회원수') COMMENT = '월초(BOM) 미납 회원 고유수. D(distinct). 다월 합산 금지.',
    fmm.UNPAID_MEMBERS_EOM AS COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_EOM THEN fmm.MEMBER_DK END)
      WITH SYNONYMS ('월말 미납회원수') COMMENT = '월말(EOM) 미납 회원 고유수. D(distinct). 다월 합산 금지.',
    fmm.UNPAID_REDUCTION_RATE AS
      (COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END)
       - COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_EOM THEN fmm.MEMBER_DK END))
      / NULLIF(COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END), 0) * 100
      WITH SYNONYMS ('미납회원 감소율') COMMENT = '공80 미납회원 감소율(%) = (월초미납−월말미납) ÷ 월초미납 ×100. 비율(N).',
    fmm.TOTAL_UNPAID_AMT AS SUM(fmm.BILLED_AMT) - SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('총미납금액', '미납액 총액') COMMENT = '총미납금액(원) = 청구 − 납입. F(가산). 재청구 중복 포함 주의(PoC UNPAID_RATIO 로직 이식).',
    fmm.UNPAID_RATIO AS (SUM(fmm.BILLED_AMT) - SUM(fmm.PAID_FEE)) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율') COMMENT = '미납비중(%) = (청구−납입) ÷ 청구 ×100 (=100−납부율). 비율(N, 재집계 금지). 기간 스코프 전제 권장(무필터 시 재청구·이월 왜곡). PoC UNPAID_RATIO 로직 이식.',
    fmm.AVG_PAID_FEE AS AVG(fmm.PAID_FEE)
      WITH SYNONYMS ('평균납입회비', '평균회비') COMMENT = '행(월×회원)당 평균 납입회비(원). HAS_BILLING=TRUE 전제 권장. PoC AVG_PAID 로직 이식.'
  )
  COMMENT = 'Phase-1 회원 월별 실적 SV(base FMM). [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(회비 TM_PM_MBRFEE_ACMSLT·기부 TM_PM_DNTN_DTLS·개발 TM_MM_FDRM_MBER_DVLP_AMT·중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC·증감 TM_MM_FDRM_MBER_IRSD·회원 TM_MM_FDRM_MBER_INFO) → SILVER(CRM_*) → GOLD(FMM). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 납입/청구 총액·납부율(공64)·미납회원 감소율(공80)·개발/중단 총건·총미납금액·미납비중·평균납입회비. 시간=전체가능. 회비 지표는 HAS_BILLING=TRUE 전제 권장. 회원상태/성별/구분은 현재 스냅샷 기준(과거월도 현재값). 비활성(적재 대기): 캠페인/납입방식/후원사업/사유별 분해, 활동/누계/미납 카운트 비율, 신규기존 분해, 지역/연령대.'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(회원구분·성별·회원상태 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 납부율·미납비중 등 비율은 총계 행에서 SUM 기반으로 정확히 산출한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';

-- 비활성(Phase-2/적재 후) — 구조 불변, 적재 완결 시 metric만 추가:
--   공45~47 활동율·공54~57 중단율·공76~78 미납율(ACTIVE/MONTH_END/YEAR_START_ACTIVE_CNT 미적재)
--   신12~29 캠페인/납입방식별 · 공79 후원사업별 (해당 FK 미적재)
--   공1~3 목표대비 (BRG_DEV_VS_TARGET 브리지 · 04 §8.1) · 공81 미납서비스 전환율 (GA identity 브리지 · P2)


/* =====================================================================================
   2. SV_MEMBER_EVENT (회원 Agent) — base FME(일×회원×상태전이)
      활성: 개발/중단 총건·고유회원수 · 사건일/주차
      ※ 유지기간·유지율·LTV(신4·6~8)는 가입↔중단 페어링이 필요해 Phase-1 산출 불가 → 04 §6.7
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT
  TABLES (
    fme AS GN_DW.GOLD.FACT_MEMBER_EVENT
      WITH SYNONYMS ('회원 상태전이', '개발중단 사건')
      COMMENT = '회원 상태전이 사건 팩트. 1행=1개발/중단 사건. ⚠(DATE_SK,MEMBER_DK,EVENT_TYPE) 실측 비유일 → PK 미선언(기저 FACT·참조 안 됨·집계 무해). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT·MBER_NO) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC(SPNSR_DSCNTC_DE·DSCNTC_RSN_CD·DSCNTC_PATH) · SILVER=CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '일자', '사건일')
      COMMENT = '일 차원. [원천] ETL 생성(달력, 팩트 일자범위 기반) — 업무 원천 시스템 없음.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fme_to_date   AS fme (DATE_SK)   REFERENCES date,
    fme_to_member AS fme (MEMBER_DK) REFERENCES member
  )
  DIMENSIONS (
    date.EVENT_DATE   AS date.FULL_DATE     WITH SYNONYMS ('사건일', '발생일', '일자') COMMENT = '상태전이 발생일',
    date.CAL_YEAR     AS date.YEAR          WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH         WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.WEEK_OF_YEAR AS date.WEEK_OF_YEAR  WITH SYNONYMS ('주차', '주')   COMMENT = '연중 주차',
    date.DAY_OF_WEEK  AS date.DAY_OF_WEEK   WITH SYNONYMS ('요일')        COMMENT = '요일',
    fme.EVENT_TYPE    AS fme.EVENT_TYPE     WITH SYNONYMS ('원천계통', '사건원천') COMMENT = '원천 계통 구분. 실제값 2종뿐: ''DEV''(개발원천) / ''STOP''(중단원천). ⚠ 상태(신규·증액·감액·재후원·후원중단)는 이 컬럼이 아니라 DVLP_DIV_NM 을 쓴다 — O24. 종전 COMMENT 가 "개발/중단/증액/미납중단"이라 적혀 있어 ''증액'' 필터 생성 시 0행 무증상 오답이 가능했다(AD-4 유형)',
    fme.DVLP_DIV_NM   AS fme.DVLP_DIV_NM    WITH SYNONYMS ('개발구분', '상태구분', '증액감액구분', '개발구분명') COMMENT = '개발구분(정본 MM015). 실제값 5종: ''신규''·''증액''·''감액''·''재후원''·''후원중단''. 중단원천 행은 NULL. ⚠ ''후원중단''(1,010,680건)은 EVENT_TYPE=''STOP''(1,038,262건)과 동일 사건이 두 원천에 중복 존재 → 두 축 합산 금지(O24 현업확인 대기)',
    fme.DVLP_DIV_CD   AS fme.DVLP_DIV_CD    WITH SYNONYMS ('개발구분코드') COMMENT = '개발구분 원천코드(1=신규 2=증액 3=감액 4=재후원 5=후원중단). 라벨은 DVLP_DIV_NM',
    fme.JOIN_DATE     AS fme.JOIN_DATE      WITH SYNONYMS ('가입일')      COMMENT = '회원 가입일(유지기간 산출 기준)',
    fme.STOP_DATE     AS fme.STOP_DATE      WITH SYNONYMS ('중단일', '해지일') COMMENT = '회원 중단일',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010)',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12)',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018)'
  )
  METRICS (
    fme.TOTAL_DEV_CNT     AS SUM(fme.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건') COMMENT = '개발 건수 합계. F(가산). 정본 공#121 개발구분 = 신규·증액·재후원 한정(감액·후원중단 제외). ⚠ 2026-08-03 O24 교정 이전 값은 감액·후원중단까지 포함해 56.86% 과대(3,594,843→2,291,878) — 과거 리포트와 대조 시 주의.',
    fme.TOTAL_STOP_CNT    AS SUM(fme.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단 건수 합계. F(가산). 중단원천(EVENT_TYPE=''STOP'') 기준. ⚠ DVLP_DIV_NM=''후원중단'' 행수와 더하지 말 것(동일 사건 중복, O24).',
    -- [2026-08-03 O24] 증액·감액 사건 measure 신설.
    --   🔴 명명 주의: 정본 공#150 증액(명)·#151 증액(건)·#38 감액(건)은 **월 마감 시 전월 대비 활동(건) 증감**
    --      = FMM 월말 스냅샷 비교 정의이고, 아래 metric 은 **사건 발생일 기준**이다. 두 정의는 값이 다르며
    --      어느 쪽을 정본으로 삼을지 **미확정**(O24 잔여) → 정본 지표번호를 자칭하지 않는 이름을 쓴다.
    --   금액 기준인 이유: 정본이 `(건)` = 금액÷10,000 으로 정의하므로(CONF-2) 행수로 세면 정의 파괴.
    fme.INCREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('증액금액', '증액 총액') COMMENT = '증액 사건 금액 합계(원). F(가산). 사건 발생일 기준 — 정본 공#150·#151(월말 스냅샷 대비)과 정의가 다르다(O24 미확정).',
    fme.DECREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('감액금액', '감액 총액') COMMENT = '감액 사건 금액 합계(원, **음수**). F(가산). 사건 발생일 기준 — 정본 공#38(감액(건)=금액÷10,000)과 단위·정의가 다르다(O24 미확정).',
    fme.INCREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('증액회원수') COMMENT = '증액 고유 회원수. D(distinct). 사건 기준.',
    fme.DECREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('감액회원수') COMMENT = '감액 고유 회원수. D(distinct). 사건 기준.',
    fme.DEV_MEMBER_COUNT  AS COUNT(DISTINCT CASE WHEN fme.DEV_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('개발회원수', '신규 회원수') COMMENT = '개발 고유 회원수. D(distinct). 다기간도 중복 없음.',
    fme.STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('중단회원수', '해지 회원수') COMMENT = '중단 고유 회원수. D(distinct).'
    -- ⚠ AVG_RETENTION_MONTHS(신4 유지기간) 미노출: 개발행에 JOIN_DATE·중단행에 STOP_DATE가 서로 다른 행에
    --   있어 행별 DATEDIFF가 전건 NULL이고 LAST_STOP_DATE도 미적재 → 산출 불가. 근거·경위 = 04 §6.9-(2) 계열.
  )
  COMMENT = 'Phase-1 회원 상태전이 SV(base FME, 일 grain). [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(개발 TM_MM_FDRM_MBER_DVLP_AMT·중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC) → SILVER(CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE) → GOLD(FME). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 개발/중단 건·고유회원수 · **개발구분 5종(신규·증액·감액·재후원·후원중단, 정본 MM015) · 증액/감액 금액·회원수**(2026-08-03 O24 신설). 시간=전체가능. 유지기간/유지율/LTV(신4·6~8)는 가입↔중단 페어링(LAST_STOP_DATE 미적재·FME 행별 단일일자)으로 Phase-1 산출 불가 → Agent/Phase-2 확장. 비활성(적재 대기): 조직/캠페인/후원사업/사유별 분해, 신규기존 분해, 미납중단.'
  AI_SQL_GENERATION '핵심 규칙: (1) **상태(증액·감액·신규·재후원·후원중단)를 묻는 질문은 EVENT_TYPE 이 아니라 DVLP_DIV_NM 으로 필터한다** — EVENT_TYPE 은 실제값이 ''DEV''/''STOP'' 2종뿐인 원천 계통축이라 ''증액'' 등으로 필터하면 0행이 된다(O24). (2) **중단 이중계상 금지**: 중단 규모는 TOTAL_STOP_CNT(중단원천) 하나만 쓴다. DVLP_DIV_NM=''후원중단'' 행수를 여기에 더하면 동일 사건이 두 번 세어진다(동일 회원·일자 99.99% 중복, O24 현업확인 대기). 사용자가 "전체 중단"을 물으면 TOTAL_STOP_CNT 로 답하고 개발원천 측 중단 기록이 별도로 존재함을 각주로 밝힌다. (3) **개발 규모는 TOTAL_DEV_CNT 를 쓴다** — 정본 공#121 개발구분 = 신규·증액·재후원 한정이며 감액·후원중단은 제외된다. DVLP_DIV_NM 전체 행수를 개발실적으로 세지 않는다. (4) 증액·감액 금액은 원금액이다. 정본 `(건)` 지표는 금액÷10,000 이므로 "증액(건)"을 물으면 금액÷10,000 로 산출하고 단위를 명시한다. 감액 금액은 **음수**로 저장돼 있으니 규모를 말할 때 절대값 여부를 밝힌다. (5) 증액·감액 metric 은 **사건 발생일 기준**이며 정본 공#150·#151·#38(월 마감 시 전월 대비 활동 증감 = 월말 스냅샷)과 **정의가 다르다** — 정본 수치와 대조하는 질문에는 이 차이를 반드시 명시한다. (6) 적용 조건(기간·그룹 모두 미지정 시): 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   3. SV_SERVICE (회원 Agent) — base FSE(일×회원×서비스×캠페인)
      활성: 발송수 총량·고유회원수 · 서비스구분(A3 SERVICE_SK)·발송상태
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_SERVICE_EVENT
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송')
      COMMENT = '서비스 발송 팩트. ⚠(DATE_SK,MEMBER_DK,SERVICE_SK) 실측 비유일 → PK 미선언(기저 FACT·집계 무해). [원천] 시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM: 발송마스터 TM_MS_EMAIL_SNDNG·TM_MS_MSG_AT_SNDNG·TM_MS_PSTMTR_SNDNG · 발송상세 TD_MS_EMAIL_SNDNG_DTLS·TD_MS_MSG_AT_SNDNG_DTLS·TD_MS_PSTMTR_SNDNG_DTL(MBER_NO·SNDNG_RST_CD) · 성과 TD_MS_*_LQY_SNDNG(성공/실패, 현재 미적재) · SILVER=CRM_SEND_REQUEST·CRM_SEND_MEMBER·CRM_SEND_RESULT.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK). 미매칭=Unknown(SK=0). [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST(SEND_GBN_TOP/MID/BOT 대·중·소분류 코드) · SILVER=CRM_SEND_REQUEST.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fse_to_date    AS fse (DATE_SK)    REFERENCES date,
    fse_to_service AS fse (SERVICE_SK) REFERENCES service,
    fse_to_member  AS fse (MEMBER_DK)  REFERENCES member
  )
  DIMENSIONS (
    date.SEND_DATE  AS date.FULL_DATE  WITH SYNONYMS ('발송일', '일자') COMMENT = '발송일',
    date.CAL_YEAR   AS date.YEAR       WITH SYNONYMS ('연도', '년')     COMMENT = '연도',
    date.CAL_MONTH  AS date.MONTH      WITH SYNONYMS ('월')            COMMENT = '월(1~12)',
    service.SUBTYPE AS service.SUBTYPE WITH SYNONYMS ('서비스유형', '발송소분류') COMMENT = '서비스 subtype',
    service.CHANNEL AS service.CHANNEL WITH SYNONYMS ('채널', '발송채널') COMMENT = '발송 채널(CRM_UMS/ADMIN 등)',
    fse.SEND_STATUS AS fse.SEND_STATUS WITH SYNONYMS ('발송상태') COMMENT = '발송 상태',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010)',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12)',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018)'
  )
  METRICS (
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송 회원수') COMMENT = '발송수 합계. F(가산).',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 고유회원수', '수신 대상 회원수') COMMENT = '발송 대상 고유 회원수. D(distinct). 다기간 중복 방지.'
  )
  COMMENT = 'Phase-1 서비스 발송 SV(base FSE). [원천 요약] 원천시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM(TM_MS_EMAIL/MSG_AT/PSTMTR_SNDNG + TD_MS_*_SNDNG_DTLS + SND_REQ_MST) → SILVER(CRM_SEND_*) → GOLD(FSE). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 발송수·고유 발송회원수, 서비스구분/발송상태/발송일별. 시간=전체가능. 비활성(적재 대기): 수신/성공/실패/오픈, 서신/선물금/증액 참여·+5일 코호트(신31~53), 캠페인별.'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(채널·서비스유형·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   4. SV_EVENT_PARTICIPATION (회원 Agent) — base FEP(일×회원×행사)
      활성: 참여자수·참여건수·고유 참여회원수 · 행사명/종류/구분
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
  TABLES (
    fep AS GN_DW.GOLD.FACT_EVENT_PARTICIPATION
      WITH SYNONYMS ('행사 참여', '이벤트 참여')
      COMMENT = '행사 참여 팩트. ⚠(DATE_SK,MEMBER_DK,EVENT_SK) 실측 비유일 → PK 미선언(기저 FACT·집계 무해). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: 참여상세 TD_MS_EVENT_PRTCPNT_DTL(MBER_NO·PARTCPT_STAT_CD·RCPMNY_AMT) ∪ TD_MS_CRMN_PRTCPNT(캠페인행사) · SILVER=CRM_EVENT_PARTICIPATION.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '참여일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    event AS GN_DW.GOLD.DIM_EVENT
      PRIMARY KEY (EVENT_SK)
      WITH SYNONYMS ('행사', '이벤트')
      COMMENT = '행사 차원. EVENT_SK 고아분은 Unknown(SK=0)으로 라우팅되므로 행사명별 집계는 부분집합이다(이슈 E). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: TM_MS_EVENT(EVENT_NM·STRT_DE) ∪ TM_MS_CRMN(캠페인행사) · SILVER=CRM_EVENT.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fep_to_date   AS fep (DATE_SK)   REFERENCES date,
    fep_to_event  AS fep (EVENT_SK)  REFERENCES event,
    fep_to_member AS fep (MEMBER_DK) REFERENCES member
  )
  DIMENSIONS (
    date.PART_DATE       AS date.FULL_DATE       WITH SYNONYMS ('참여일', '행사일', '일자') COMMENT = '참여일',
    date.CAL_YEAR        AS date.YEAR            WITH SYNONYMS ('연도', '년')  COMMENT = '연도',
    date.CAL_MONTH       AS date.MONTH           WITH SYNONYMS ('월')         COMMENT = '월(1~12)',
    event.EVENT_NAME     AS event.EVENT_NAME     WITH SYNONYMS ('행사명', '이벤트명') COMMENT = '행사명',
    event.EVENT_KIND     AS event.EVENT_KIND     WITH SYNONYMS ('행사종류', '온오프라인') COMMENT = '행사 종류(온라인/오프라인)',
    event.EVENT_CATEGORY AS event.EVENT_CATEGORY WITH SYNONYMS ('행사구분') COMMENT = '행사 구분',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010)',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12)',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018)'
  )
  METRICS (
    fep.TOTAL_PARTICIPANTS AS SUM(fep.PARTICIPANT_CNT)
      WITH SYNONYMS ('참여자수', '참가자수') COMMENT = '참여자수 합계. F(가산).',
    fep.TOTAL_PARTICIPATE_CNT AS SUM(fep.PARTICIPATE_CNT)
      WITH SYNONYMS ('참여건수') COMMENT = '참여 건수 합계. F(가산).',
    fep.DISTINCT_PARTICIPANTS AS COUNT(DISTINCT fep.MEMBER_DK)
      WITH SYNONYMS ('고유 참여회원수') COMMENT = '고유 참여 회원수. D(distinct).'
  )
  COMMENT = 'Phase-1 행사 참여 SV(base FEP). [원천 요약] 원천시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM(행사 TM_MS_EVENT∪TM_MS_CRMN · 참여 TD_MS_EVENT_PRTCPNT_DTL∪TD_MS_CRMN_PRTCPNT) → SILVER(CRM_EVENT+CRM_EVENT_PARTICIPATION) → GOLD(FEP). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분·참여일별. ⚠행사 미매칭분이 Unknown(EVENT_SK=0)으로 라우팅되므로 행사명별 집계는 부분집합이다 — 확정치로 단정 금지. 비활성(적재 대기): 모집/총원, 캠페인/후원사업별.'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(행사종류·행사명·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 행사명별 집계를 낼 때는 미매칭분이 Unknown으로 빠져 부분집합임을 답변에 명시한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   5. SV_BUDGET (overall Agent) — base FBD(월×조직×세세목)
      활성: 편성예산(월)·집행예산(ERP)·집행율 · 세세목명/예산구분
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 팩트(grain=월×세세목, 실측 유일 → PK). 편성/집행. ⚠편성·집행 금액에 음수(조정/환입)가 존재한다. [원천] 시스템=ERP(예산관리, Snowflake 파일 업로드 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(예산·실적 원장): 편성 YEAR_BDGT_AMT_n · 집행 EXEC_AMT_n — 12개월 wide 컬럼을 월 long으로 언피벗 · SILVER=ERP_BUDGET.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] 시스템=ERP · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(JANG_NM~SUBDTL_ITEM_NM 장·관·항·목·세목·세세목 계층 + BDGT_UNIT_NM 예산단위) — DISTINCT 마스터화·MD5 대리키 · SILVER=ERP_BUDGET_ITEM.'
  )
  RELATIONSHIPS (
    fbd_to_month AS fbd (MONTH_KEY)      REFERENCES month,
    fbd_to_item  AS fbd (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    month.MONTH_KEY  AS month.MONTH_KEY WITH SYNONYMS ('예산연월', '연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR   AS month.YEAR      WITH SYNONYMS ('연도', '년')      COMMENT = '연도',
    month.CAL_MONTH  AS month.MONTH     WITH SYNONYMS ('월')             COMMENT = '월(1~12)',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BUDGET_CATEGORY  AS item.BUDGET_CATEGORY  WITH SYNONYMS ('예산구분', '예산카테고리') COMMENT = '예산 구분'
  )
  METRICS (
    fbd.TOTAL_PLAN_BUDGET AS SUM(fbd.PLAN_BUDGET_MONTH)
      WITH SYNONYMS ('편성예산', '월 편성예산', '예산 편성액') COMMENT = '월 편성예산 합계(원). F(가산).',
    fbd.TOTAL_EXEC_BUDGET AS SUM(fbd.EXEC_BUDGET_ERP)
      WITH SYNONYMS ('집행예산', 'ERP 집행액', '예산 집행액') COMMENT = 'ERP 집행예산 합계(원). F(가산).',
    fbd.EXEC_RATE AS SUM(fbd.EXEC_BUDGET_ERP) / NULLIF(SUM(fbd.PLAN_BUDGET_MONTH), 0) * 100
      WITH SYNONYMS ('집행율', '예산 집행율') COMMENT = '집행율(%) = 집행예산 ÷ 편성예산 ×100. 비율(N). ⚠편성은 12개월 전량이지만 집행은 적재된 월까지만 존재하므로, 집행 미적재 월을 분모에 넣으면 집행율이 구조적으로 낮게 나온다 — 스코프 정합 규칙은 AI_SQL_GENERATION 참조.'
  )
  COMMENT = 'Phase-1 예산 SV(base FBD). [원천 요약] 원천시스템=ERP(예산관리 · Snowflake 파일 업로드로 bronze 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(편성 YEAR_BDGT_AMT_n·집행 EXEC_AMT_n 월 언피벗, 세세목 JANG_NM~SUBDTL_ITEM_NM) → SILVER(ERP_BUDGET+ERP_BUDGET_ITEM) → GOLD(FBD). ⚠광고비는 이 SV의 원천(ERP)에 없다 — 광고비는 AGENCY 원천의 SV_AD 소관(예산 원장에 광고비 컬럼 부재, E-4). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 편성예산(월)·집행예산(ERP)·집행율, 세세목/예산구분/월별. 비활성(적재 대기): 연 편성예산, 집행추정/모금성비용/광고비, 조직/캠페인별, 개발단가·ROI(신9~11).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(세세목·예산구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계(합계·집행율) 행을 함께 반환해 편성예산·집행예산·집행율을 월별로 보여준다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다. ⚠집행율 산정 주의: 편성예산은 12개월 전량 적재돼 있으나 집행예산(EXEC_BUDGET_ERP)은 적재가 진행된 월까지만 값이 있고 나머지 월은 0이다. 집행율을 연 합계(전체 편성 ÷ 일부 집행)로 내면 분모가 과대해 집행율이 구조적으로 낮게 나온다. 이를 방지하기 위해 — (A) 집행율은 집행 데이터가 있는 월만 편성 분모에 포함한다: 분모 SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN PLAN_BUDGET_MONTH END), 분자 SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN EXEC_BUDGET_ERP END). (B) 집행 미적재 월은 "집행 미반영"으로 표기하고 편성만 보여준다. (C) 답변에 집행이 적재된 기간 범위와 그 이후는 미반영임을 반드시 명시한다 — 기간은 하드코딩하지 말고 데이터에서 EXEC_BUDGET_ERP<>0 인 최소·최대 연월을 조회해 쓴다. (D) 월별 ROLLUP 총계도 (A) 스코프로 산정한다.';


/* =====================================================================================
   6. SV_AD (overall Agent) — base FACT_AD_COMBINED(helper, FAP+FAD+FAB 1:1 pre-join)
      활성: 광고비·노출·클릭·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7) [디지털]
            인바운드콜·방송횟수 [방송] · 재방송개발건·재방송 개발단가(공8) [재방송 전용]
      ⚠ 디지털/방송 measure 상호배타 — AD_SOURCE_TYPE 필터 없이 혼합집계 시 왜곡
      ⚠ 캠페인/소재 연결키 미적재 → 캠페인·소재별 분해 불가(Phase-2)
      ⚠ 전환콜(CONV_CALL_CNT)·방송 전체 개발단가는 의도적 미노출 — 근거 = 04 §6.9
   ===================================================================================== */

-- 6-0. helper 뷰: FAP+FAD+FAB 1:1 pre-join (세 팩트가 AD_PERF_DK로 완전분할, fan-out 0)
--   존재 이유: semantic view metric 식은 자기 logical table 컬럼만 참조 가능 → 개발단가(AD_COST÷CRM_DEV_CNT)
--   등 cross-satellite 비율 metric을 SV에서 직접 계산할 수 없다(04 §6.9-(1)). DIM_MEMBER_CURRENT 패턴과 동일.
CREATE OR REPLACE VIEW GN_DW.SERVING.FACT_AD_COMBINED AS
SELECT
  -- FAP core
  fap.AD_PERF_DK,
  fap.PERF_DATE_SK,
  fap.CAMPAIGN_SK,
  fap.AD_CREATIVE_SK,
  fap.DEVICE_SK,
  fap.AD_COST,
  fap.IMPRESSIONS,
  fap.CLICKS,
  fap.INBOUND_CALL,
  fap.GA_CONV_MEMBERS,
  fap.GA_CONV_CNT,
  fap.DAY_OF_WEEK,
  fap.WEEK_OF_YEAR,
  fap.AD_SOURCE_TYPE,
  -- FAD (digital satellite) — NULL for broadcast rows
  dig.PAGE_TYPE,
  dig.AD_GROUP_NM,
  dig.GROUP_DIV,
  dig.CREATIVE_TYPE,
  dig.AD_TYPE_NM,
  dig.READ_CNT,
  dig.MEDIA_POTENTIAL_CUST_CNT,
  dig.CRM_DEV_CNT,
  dig.CTR_SRC,
  dig.CVR_SRC,
  dig.CPC_SRC,
  dig.CPM_SRC,
  dig.CPA_SRC,
  dig.DEV_UNIT_PRICE_SRC,
  dig.VTR_SRC,
  -- FAB (broadcast satellite) — NULL for digital rows
  brc.TIME_BAND,
  brc.CM_POSITION,
  brc.RT_TYPE,
  brc.PROGRAM_NM,
  brc.CHANNEL_COMPANY,
  brc.CHANNEL_COMPANY_TYPE,
  brc.SPOT_TYPE,
  brc.DURATION_SEC,
  brc.DAY_DIV,
  brc.BRDC_DIV,
  brc.CTV_DIV,
  brc.AD_CNT,
  brc.CONV_CALL_CNT,
  brc.DVLP_MEMBER_CNT,
  brc.DVLP_CNT,
  brc.AD_VIEW_RT_SRC  AS BRDC_AD_VIEW_RT_SRC,
  brc.CPC_SRC         AS BRDC_CPC_SRC
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE fap
LEFT JOIN GN_DW.GOLD.FACT_AD_DIGITAL dig ON fap.AD_PERF_DK = dig.AD_PERF_DK
LEFT JOIN GN_DW.GOLD.FACT_AD_BROADCAST brc ON fap.AD_PERF_DK = brc.AD_PERF_DK;

-- helper 뷰 COMMENT — 뷰는 `ALTER VIEW ... SET COMMENT` 사용(`COMMENT ON VIEW` 미지원).
ALTER VIEW GN_DW.SERVING.FACT_AD_COMBINED SET COMMENT =
  'GOLD 광고 팩트 3종(FAP 코어 + FAD 디지털·FAB 방송 위성)을 AD_PERF_DK 로 1:1 pre-join — SV_AD 의 단일 base. PK=AD_PERF_DK(전건 유일, fan-out 0). 위성은 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(디지털행=방송컬럼 NULL, 방송행=디지털컬럼 NULL — 결측이 아니라 원천 부재). 존재 이유: semantic view metric 식은 자기 logical table 컬럼만 참조 가능해 개발단가(AD_COST÷CRM_DEV_CNT) 등 cross-satellite 비율을 SV 에서 직접 계산할 수 없다.';

-- helper 뷰 GRANT (SERVING 에는 FUTURE grant 가 없어 명시 부여 필요 — 04 §6.9-(3))
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_SERVICE;

-- 6-1. SV_AD 본체
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.SERVING.FACT_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '광고 실적 통합 팩트(FAP+FAD+FAB pre-join). AD_SOURCE_TYPE으로 디지털/방송 구분. [원천] 시스템=대행사(Agency) 일별 리포트(Google Sheet · Google Drive Excel · MS SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY: 디지털 DGT_AD_CMPGN_DTLS(광고비·노출·클릭·CRM개발건·MEDIA_NM) · 방송(비디오) VIDEO_AD_CMPGN_DTLS · 방송(재방) REBRDC_AD_CMPGN_DTLS(광고비·인입콜·방송횟수·개발건수) / GN_DW.BRONZE_GA4.events_YYYYMMDD(GA 전환·기기) · SILVER=AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT. ⚠_SRC 접미 컬럼은 대행사가 원천에서 이미 계산해 제공한 비율 원값(재집계 금지).',
    device AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스', '매체기기')
      COMMENT = '기기(디바이스) 차원. [원천] 시스템=GA4(BigQuery→Snowflake) · BRONZE=GN_DW.BRONZE_GA4.events_YYYYMMDD(device.category) · SILVER=GA4_DEVICE. 방송 행은 기기 개념이 없어 (해당없음).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '실적일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.'
  )
  RELATIONSHIPS (
    ad_to_date   AS ad (PERF_DATE_SK) REFERENCES date (DATE_SK),
    ad_to_device AS ad (DEVICE_SK)    REFERENCES device
  )
  DIMENSIONS (
    -- 시간
    date.PERF_DATE    AS date.FULL_DATE  WITH SYNONYMS ('실적일', '광고일', '일자') COMMENT = '광고 실적 발생일',
    date.CAL_YEAR     AS date.YEAR       WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH      WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.CAL_QUARTER  AS date.QUARTER    WITH SYNONYMS ('분기')        COMMENT = '분기(1~4)',
    -- 코어 차원
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형. 코드값: ''DIGITAL'' · ''VIDEO''(방송 본방) · ''REBROADCAST''(재방송). 디지털/방송 measure 필터 필수.',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    -- 기기
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC') COMMENT = '기기 유형. 실제 코드값: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    -- 디지털 전용 차원
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용.',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용. 원천에 일부 행만 채워져 있어 부분집합이다.',
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용.',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용.',
    -- 방송 전용 차원
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사') COMMENT = '방송 채널사. VIDEO/REBROADCAST 전용. ⚠광고비 기준 정렬 시 광고비가 없는 채널사가 섞이므로 NULLS LAST 를 명시할 것.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대. 방송 전용.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(고카디널리티 — Cortex Search 백킹 후보). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용.',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서') COMMENT = 'CM 내 위치. 방송 전용.',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분') COMMENT = '본방/재방 유형. 방송 전용.'
  )
  METRICS (
    -- 공통 measure
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL) — VIDEO·REBROADCAST 모두 존재.',
    ad.TOTAL_GA_CONV_MEMBERS AS SUM(ad.GA_CONV_MEMBERS)
      WITH SYNONYMS ('GA전환회원', '전환회원수') COMMENT = 'GA 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용.',
    ad.CVR AS SUM(ad.GA_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = GA전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    -- 디지털 전용 measure
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). ⚠원천에 비정수(소수) 값이 섞여 있어 기여도 배분값일 가능성이 있다 → "건수"로 정수 단정 금지(어의 미확정, 03 §8.5 §6-H). ⚠원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 바뀐 시점 이후는 미적재다 — 적재 구간은 데이터에서 확인할 것(03 §8.5.1).',
    -- 분자를 분모 적재행으로 정합(CASE WHEN): 미적재행 광고비를 분자에 넣으면 단가가 과대계상된다(04 §6.9 · 03 §8.5.1-(4)).
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외). ⚠원천 포맷 변경 이후 구간은 개발건수가 없어 산출 불가(NULL) — 산출 가능한 최신 구간은 데이터에서 확인할 것.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산).',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산).',
    -- 방송 전용 measure
    --   ⚠ 전환콜(CONV_CALL_CNT)은 의도적 미노출 — 대행사 원천(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)이
    --     전건 비어 있어 빈 metric이 된다. helper 뷰 컬럼은 무손실 원칙상 유지하고 SV 노출만 차단한다.
    --     원천이 실제 제공을 시작하면 이 metric만 되살린다(구조 불변). 근거·선례 = 04 §6.9 · 현업확인 AD-6.
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '재방송 개발건수 합계. F(가산). **REBROADCAST 전용** — VIDEO는 원천(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 **구조적으로 부재**하므로(대행사 비디오 리포트는 개발 대신 전환콜 보고) 결손이 아니다. ⚠VIDEO를 포함한 "방송 전체" 개발 규모로 확대 해석 금지.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '재방송 개발회원수 합계. F(가산). **REBROADCAST 전용**(VIDEO 원천에 컬럼 부재).',
    -- 공8 재방송 개발단가 — 명명이 `BRDC_`(방송)가 아니라 `REBRDC_`(재방송)인 이유: VIDEO 원천에 개발 개념이
    --   없어 "방송 개발단가"라는 이름이 스코프를 오인시킨다. 판정 경위 = 03 §8.5 §6-I · 04 §6.4.1.
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '공8 재방송 개발단가(원) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(VIDEO 원천에 개발 컬럼 부재 → 방송 전체 단가가 아님). 분자를 개발건수 적재행으로 정합. ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 과대계상된다.'
  )
  COMMENT = 'Phase-1 광고 실적 SV(base FACT_AD_COMBINED helper). [원천 요약] 원천시스템=대행사(Agency) 일별 리포트(Google Sheet·Drive Excel·SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY(디지털 DGT_AD_CMPGN_DTLS · 방송 VIDEO_AD_CMPGN_DTLS+REBRDC_AD_CMPGN_DTLS) + GN_DW.BRONZE_GA4.events_YYYYMMDD → SILVER(AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT) → GOLD(FAP+FAD+FAB). ⚠예산(SV_BUDGET)은 ERP 원천으로 서로 다른 시스템 — 교차 집계 불가. 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 광고비·노출·클릭·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7) [디지털] / 인바운드콜·방송횟수 [방송] / 재방송개발건·재방송 개발단가(공8) [재방송 전용]. ⚠디지털/방송 measure 상호배타. ⚠캠페인/소재별 분해 불가(연결키 미적재, Phase-2). ⚠개발단가(공7)는 원천 포맷 변경 이후 구간 산출 불가(원천이 개발건수 대신 단가 제공). ⚠개발건수/개발단가는 **REBROADCAST 전용** — VIDEO 원천(VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 구조적으로 부재하므로 "방송 전체" 지표가 아니다. ⚠전환콜(CONV_CALL_CNT)은 대행사 원천이 전건 비어 있어 이 SV에 measure가 없다 — 질문받으면 미제공으로 안내(추정치 생성 금지). ⚠수치·기간은 이 COMMENT에 두지 않는다 — 반드시 SV를 조회해 답할 것.'
  AI_SQL_GENERATION '핵심 규칙: (1) AD_SOURCE_TYPE 필터가 없는 질문에서 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객은 반드시 AD_SOURCE_TYPE=''DIGITAL'' 필터를 자동 추가한다. 인바운드콜·방송횟수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 필터를 자동 추가한다. **개발건수(재방송개발건·재방송개발회원)와 재방송 개발단가(공8)는 AD_SOURCE_TYPE=''REBROADCAST'' 필터를 자동 추가한다** — VIDEO 원천에 개발 컬럼이 없어 혼합 시 과대계상된다. 광고비만 전체 합산 허용. (2) 적용 조건(기간·그룹 미지정 시): 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고, GROUP BY ROLLUP((연,월))로 월별 행 + 총계 행을 함께 반환한다. (3) 캠페인별·소재별 분해 요청은 캠페인/소재 연결키 미적재(Phase-2)로 안내하고 SQL 생성하지 않는다. (4) 기기 필터: 모바일은 DEVICE_TYPE=''M''(''MOBILE''/''TABLET'' 아님), 데스크톱은 ''PC''. 방송은 ''(해당없음)''이므로 기기별 분석은 디지털에만 적용한다. (5) 개발단가(공7, 디지털)는 원천이 개발건수 제공을 중단한 시점 이후 NULL이다. 기간을 하드코딩하지 말고 CRM_DEV_CNT 가 존재하는 최신 연월을 데이터에서 조회해 그 시점까지로 한정하고, 그 이후는 원천 포맷 변경으로 산출 불가임을 답변에 명시한다. (6) 개발건수·개발단가를 "방송"으로 묻더라도 **재방송(REBROADCAST) 전용 지표**임을 답변에 명시한다 — VIDEO는 대행사 원천에 개발 컬럼이 없어 집계 대상이 아니며(결손이 아니라 구조적 부재), 방송 전체 개발 규모로 단정하면 안 된다. (7) **전환콜**은 이 SV에 measure가 없다 — 대행사 원천(VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT)이 전건 비어 있기 때문이다. 질문받으면 SQL을 생성하지 말고 미제공 사유를 답하고, 인바운드콜(INBOUND_CALL)로 대체 가능한지 되묻는다. 전환콜 수치를 추정·창작하지 않는다. (8) 채널사·프로그램 등 방송 차원을 광고비 기준으로 정렬할 때는 ORDER BY ... DESC NULLS LAST 를 쓴다 — 기본값 NULLS FIRST 면 광고비 없는 항목이 상위를 점유한다.';


/* =====================================================================================
   7. GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST가 VIEWER를 상속(계층)하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🔴 CREATE OR REPLACE는 기존 GRANT를 전부 삭제(OWNERSHIP만 잔존)한다 → **단일 SV 재배포 시 해당 SV의
         GRANT 3줄을 반드시 재실행**. (SV_MEMBER_EVENT 재배포 시 grant 소실 실측·재부여 확인.)
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY      TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY      TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY      TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT        TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT        TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT        TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE             TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE             TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE             TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET              TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET              TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET              TO ROLE GN_DW_SERVICE;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD                  TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD                  TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD                  TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   8. 스모크 검증 · 배포 검증 (배포 직후 실행) — 04 §0.1 DoD
      핵심 원리: SEMANTIC_VIEW(...) 집계 == 단일 FACT 직접 SUM 일치 → 조인 fan-out 0 검증.

      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         "sv_val == fact_val", "dig + brc == fap == combined" 같은 관계식이 참인지만 본다.
         기대 절대값을 문서에 박으면 재현 시 전항 오탐이 된다(04 §6.9-(8)).
   ===================================================================================== */
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- ─── 8-A. SV 공통 fan-out 검증 ─────────────────────────────────────────────────────
-- (8-1) SV_MEMBER_MONTHLY 납입회비 총액 == FMM 직접 SUM
SELECT (SELECT TOTAL_PAID_FEE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_PAID_FEE)) AS sv_val,
       (SELECT SUM(PAID_FEE) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY)                                        AS fact_val;
--   판정: sv_val == fact_val

-- (8-2) SV_SERVICE 발송수 총합 == FSE 직접 SUM (서비스 조인 fan-out 0)
SELECT (SELECT TOTAL_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS TOTAL_SEND_MEMBERS)) AS sv_val,
       (SELECT SUM(SEND_MEMBERS) FROM GN_DW.GOLD.FACT_SERVICE_EVENT)                                       AS fact_val;
--   판정: sv_val == fact_val

-- (8-3) 차원 조인 스모크: 회원 성별별 개발건 (O26: GENDER→GENDER_NAME 라벨 노출)
SELECT * FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_EVENT
  DIMENSIONS member.GENDER_NAME
  METRICS TOTAL_DEV_CNT
) ORDER BY 1;

-- ─── 8-B. SV_AD 스모크 ─────────────────────────────────────────────────────────────
-- (8-4) fan-out 0: SV 집계 == 코어 FACT 직접 SUM (위성 2개 1:1 조인 검증)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST)  FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                           AS fact_val;
--   판정: sv_val == fact_val

-- (8-5) 수직분할 완결성: 디지털 + 방송 == 코어 전건 (helper 뷰 LEFT JOIN 안전성 근거)
SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE) AS fap,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL)     AS dig,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)   AS brc,
       (SELECT COUNT(*) FROM GN_DW.SERVING.FACT_AD_COMBINED) AS combined;
--   판정: dig + brc == fap  AND  combined == fap  (→ 중복 팽창 없음)

-- (8-6) 디지털 지표 산출 (CTR·CVR·개발단가)
--   🔴 SEMANTIC_VIEW(...) 내부에 FILTER 절로 `ad.컬럼` 을 쓰면 **문법 오류**다
--      ("syntax error ... unexpected 'ad'"). 차원을 DIMENSIONS 에 넣고 **바깥 WHERE 에서
--      별칭 없는 컬럼명**으로 걸러야 한다(04 §6.9-(6)).
SELECT CAL_YEAR, AD_SOURCE_TYPE, TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR, ad.AD_SOURCE_TYPE
  METRICS TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
)
WHERE AD_SOURCE_TYPE = 'DIGITAL'
ORDER BY 1;
--   판정: 연도별 행이 나오고 CTR/CVR 이 NULL 아님. 개발단가는 최신 구간에서 NULL 일 수 있다(원천 포맷 변경).

-- (8-7) 상호배타 확인 + 기기 차원 조인
SELECT AD_SOURCE_TYPE, DEVICE_TYPE, TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.AD_SOURCE_TYPE, device.DEVICE_TYPE
  METRICS TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
)
ORDER BY 1, 2;
--   판정(구조 불변식):
--     DIGITAL     · M / PC       : 클릭 있음 · 인바운드콜·방송횟수 **NULL**
--     REBROADCAST · (해당없음)   : 인바운드콜·방송횟수 있음 · 클릭 **NULL**
--     VIDEO       · (해당없음)   : 인바운드콜·방송횟수 있음 · 클릭 **NULL**
--   → 기기 코드가 'M'/'PC'/'(해당없음)' 임을 확인(=SV comment 와 일치). 'MOBILE' 아님.

-- (8-8) 방송 전용 축 조인 (채널사)
--   🔴 `ORDER BY <metric> DESC` 는 Snowflake 기본이 **NULLS FIRST** → 광고비 NULL 채널사가
--      상위를 차지해 "top N" 이 오염된다 → `NULLS LAST` 필수(04 §6.9-(7)).
SELECT CHANNEL_COMPANY, TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.CHANNEL_COMPANY
  METRICS TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
)
WHERE CHANNEL_COMPANY IS NOT NULL
ORDER BY TOTAL_AD_COST DESC NULLS LAST
LIMIT 10;
--   ⚠ TOTAL_DVLP_CNT 는 REBROADCAST 전용 부분합 — 채널사별 개발 규모 비교에 쓰지 말 것.

-- (8-9) 미노출 metric 확인 — 아래는 **에러가 나야 정상**
--   SELECT BRDC_DEV_UNIT_PRICE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS BRDC_DEV_UNIT_PRICE);
--   SELECT TOTAL_CONV_CALL_CNT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_CONV_CALL_CNT);
--   판정: 둘 다 `invalid identifier` — 방송 전체 개발단가와 전환콜은 의도적 미노출이다(04 §6.9).
--     재방송 한정 단가는 `REBRDC_DEV_UNIT_PRICE`(AD_SOURCE_TYPE='REBROADCAST' 필터 전제)로 노출된다.

-- (8-10) 배포된 SV 구조 확인 — DDL 과 배포본 일치 검사
DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_AD;
SELECT SEMANTIC_VIEW_NAME,
       (SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS m
          WHERE m.SEMANTIC_VIEW_NAME = d.SEMANTIC_VIEW_NAME AND m.SEMANTIC_VIEW_SCHEMA = 'SERVING') AS metrics,
       COUNT(*) AS dims
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS d
WHERE SEMANTIC_VIEW_SCHEMA = 'SERVING'
GROUP BY 1 ORDER BY 1;
--   판정: 6행. 각 SV 의 metric·dimension 수가 위 DDL 의 METRICS/DIMENSIONS 절 항목 수와 일치.
--   ⚠ 개수를 주석에 박지 않는다 — DDL 을 세는 것이 정본이다(04 §6.3 이 "dim 20" 으로 틀렸던 사례).

-- ─── 8-C. 배포 검증: 소유권·GRANT ──────────────────────────────────────────────────
-- (8-11) SV 6개 · owner 통일
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
--   판정: 6행 전부 owner = GN_DW_ADMIN
--   ⚠ owner 가 ACCOUNTADMIN 이면 이 파일을 GN_DW_ADMIN 이 아닌 역할로 실행한 것이다. 복구:
--     USE ROLE ACCOUNTADMIN;
--     GRANT OWNERSHIP ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
--     GRANT OWNERSHIP ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;

-- (8-12) SV_AD grant 3역할
SHOW GRANTS ON SEMANTIC VIEW GN_DW.SERVING.SV_AD;
--   판정: OWNERSHIP(GN_DW_ADMIN) + REFERENCES/SELECT × ANALYST·VIEWER·SERVICE

-- (8-13) helper 뷰 grant
SHOW GRANTS ON VIEW GN_DW.SERVING.FACT_AD_COMBINED;
--   판정: OWNERSHIP(GN_DW_ADMIN) + SELECT × ANALYST·VIEWER·SERVICE

--   ▶ Agent(AGENT_MEMBER·AGENT_OVERALL) 의 grant·CoWork SI 검증은 이 파일 소관이 아니다
--     → 09_AGENT_spec_구현.sql [5] 참조.

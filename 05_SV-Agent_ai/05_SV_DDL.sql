-- GN_DW 3단계: Phase-1 Semantic View DDL (CREATE SEMANTIC VIEW) — 실측 활성 measure/metric만 노출
-- Co-authored with CoCo
--
-- 정본 근거:
--   05_SV-Agent_ai/01_SV-Agent 작업계획.md  §3 3단계 · 원칙10(fan-out)·R1·R5 가산성 · 원칙6 한글 synonyms
--   05_SV-Agent_ai/04_SV_설계.md            §0.1 helper뷰 · §0.3 가산성 · §1~5 SV구조 · §0.6 적재 완결성
--   05_SV-Agent_ai/03_SV_metric_배속.md     공64 납부율 · 공80 미납회원감소율 등 분자/분모 직역
--   05_SV-Agent_ai/02_SERVING_setup.sql     SERVING 스키마 · helper뷰(DIM_MONTH·DIM_MEMBER_CURRENT) · RBAC
--   03_top-down_gold/04_SV파생 매핑.md       derived 81→분자/분모 base 매핑(stale; 공64·공80·유지기간 공식 정합 확인 참고)
--   Snowflake docs: /user-guide/views-semantic/sql (CREATE SEMANTIC VIEW DDL 구문 · COMMENT = 필수 · GRANT REFERENCES,SELECT)
--
-- ▶ 실측 활성 매트릭스 (2026-07-29 재검증 · SV 6종 = SV_MEMBER_MONTHLY·SV_MEMBER_EVENT·SV_SERVICE·SV_EVENT_PARTICIPATION·SV_BUDGET·SV_AD):
--   ⚠ 아래 수치는 모두 **COUNT_IF = 값이 채워진 행 수**이다. SV에 노출되는 metric은 **SUM 집계**이므로 값이 다르다.
--     예) FMM DEV_CNT: COUNT_IF(행수)=2,970,417 이나 TOTAL_DEV_CNT=SUM(DEV_CNT)=3,594,843.
--         FMM STOP_CNT: COUNT_IF(행수)=972,376 이나 TOTAL_STOP_CNT=SUM(STOP_CNT)=1,038,262.
--     → 06/07 검증·평가셋의 metric 값(SUM 기준)과 대조할 때 이 구분에 유의(모순 아님).
--     FMM 40.05M : PAID_FEE 36.09M · BILLED_AMT 37.15M · DEV_CNT 2.97M · STOP_CNT 0.97M · UNPAID_FLAG_BOM 3.19M/EOM 3.30M · HAS_BILLING 37.79M ✅
--                  ACTIVE/CUM/MONTH_END/INCREASE 건·명 · CAMPAIGN/PAYMENT/SPONSORSHIP/REASON_SK · NEW_EXISTING_FLAG = 전건 0 ❌
--     FME 4.63M  : DEV_CNT/DEV_MEMBERS 3.59M · STOP_CNT/STOP_MEMBERS 1.04M · JOIN/STOP_DATE ✅ / ORG_SK·FK·NEF = 0 ❌
--     FSE 38.47M : SEND_MEMBERS(전행) · SEND_STATUS 35.75M · SERVICE_SK 99.97% · SEND_TITLE ✅ / SUCCESS/FAIL/OPEN/D5/LETTER/GIFT·CAMPAIGN_SK = 0 ❌
--     FEP 1.13M  : PARTICIPANT_CNT/PARTICIPATE_CNT(전행) · EVENT_SK 76.8%(고아 23%) ✅ / TOTAL/RECRUIT_CNT·CAMPAIGN/SPONSORSHIP_SK = 0 ❌
--     FBD 24,480 : PLAN_BUDGET_MONTH 7,290 · EXEC_BUDGET_ERP 3,244 · BUDGET_ITEM_SK(전행) ✅ / 연예산·집행추정·모금성/광고비·ORG/CAMPAIGN_SK = 0 ❌
--                  ⚠ FBD 두 금액은 **≠0 기준** 카운트다(음수 존재 — PLAN 1행·EXEC 24행 조정/환입).
--                    >0 기준으로는 각각 7,289 · 3,220. 집행율 분모·분자 스코프 정의 시 이 차이에 유의.
--     AD  235,572: [2026-07-28 순서9-I 신설 · base=SERVING.FACT_AD_COMBINED helper]
--                  AD_COST 224,399행(총 514.4억) · DEVICE_SK 전행(unknown 0) ✅
--                  [디지털 전용] IMPRESSIONS 190,440 · CLICKS · GA_CONV_MEMBERS · READ_CNT · MEDIA_POTENTIAL ·
--                    CRM_DEV_CNT 189,252(2024-01~2026-05만 — 2026-06부터 원천이 단가로 대체, AD-3)
--                  [방송 전용] INBOUND_CALL 165,462(REBRDC 113,241 + VIDEO 52,221) · AD_CNT 36,712(REBRDC 2,059 + VIDEO 34,653)
--                  🔴 CONV_CALL_CNT = **전건 NULL**(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS 원천부터 35,822행 전량 NULL).
--                     배포된 metric TOTAL_CONV_CALL_CNT 의 "총 49,093" 은 현 데이터에 근거가 없다
--                     → metric 제거(SV_AD METRICS 절 상단 근거 주석). ⚠재배포 필요.
--                  [재방송 전용] DVLP_CNT 1,982/2,064(96.03%) · DVLP_MEMBER_CNT — VIDEO 원천에 개발 컬럼 구조적 부재(AD-5)
--                  ❌ CAMPAIGN_SK · AD_CREATIVE_SK = 전건 0 → 캠페인/소재별 분해 불가(Phase-2)
--     활성 dim속성: 회원 GENDER 1.76M·MEMBER_STATUS 1.59M·MEMBER_TYPE 1.76M ✅ / REGION·AGE_BAND·FIRST_SPONSORSHIP = 0 ❌
--                   서비스 SUBTYPE·CHANNEL ✅ / SEND_TYPE_L/M/S = 0 ❌ · 행사 EVENT_NAME/KIND/CATEGORY ✅ / APPLY_CHANNEL = 0 ❌ · 세세목 NAME/CATEGORY ✅
--
-- ▶ 배포 실측 대조 (2026-07-29): SHOW SEMANTIC VIEWS/METRICS/DIMENSIONS IN SCHEMA GN_DW.SERVING
--     = SV 6종 · metric 39개 · dimension 61개 — 구조는 일치했으나 SV_AD 의 TOTAL_CONV_CALL_CNT 가
--       **빈 metric(원천 전건 NULL)** 으로 확인돼 본 파일에서 제거했다 → 재배포 후 metric 38개(SV_AD 15).
--       metric  : SV_AD 15(배포본 16) · SV_MEMBER_MONTHLY 11 · SV_MEMBER_EVENT 4 · SV_BUDGET 3 · SV_EVENT_PARTICIPATION 3 · SV_SERVICE 2
--       dimension: SV_AD 19 · SV_MEMBER_EVENT 11 · SV_SERVICE 9 · SV_EVENT_PARTICIPATION 9 · SV_MEMBER_MONTHLY 8 · SV_BUDGET 5
--
-- ▶ 가드레일 준수:
--     R1 fan-out : 월팩트→SERVING.DIM_MONTH(월 grain) · 회원속성→SERVING.DIM_MEMBER_CURRENT(현재행) — raw DIM_DATE/DIM_MEMBER 직접조인 금지.
--                  광고팩트→SERVING.FACT_AD_COMBINED(AD_PERF_DK 1:1 pre-join) — 위성 3종 직접 다중조인 금지.
--     R5 가산성  : F(flow)=SUM metric / D(distinct 회원)=COUNT(DISTINCT MEMBER_DK) metric(다월 중복 방지) / 비율=분자·분모 각각 집계 후 division.
--     조인키 타입: MEMBER_DK=VARCHAR(캐스팅 금지) · MONTH_KEY/DATE_SK/*_SK=NUMBER · AD_PERF_DK=VARCHAR(32).
--     PRIMARY KEY: 실측 유일한 것만 선언 — FMM(MONTH_KEY,MEMBER_DK) · FBD(MONTH_KEY,BUDGET_ITEM_SK) ·
--                 ad(AD_PERF_DK, 235,572행 전건 유일 · 2026-07-28 추가).
--                 FME/FSE/FEP는 선언 grain이 실측 비유일(FME 4.63M→4.05M·FSE 38.47M→36.65M·FEP 1.13M→0.84M) → PK 미선언.
--                 기저 FACT는 다른 테이블에서 참조되지 않아(관계의 다측) PK 불요 · fan-out/집계 무해(compile 확인).
--     비활성    : 실측 0/NULL(FK·SUCCESS·D5·연예산 등)은 SV에서 제외(하단 비활성 주석) — 적재 완결 시 metric만 추가(구조 불변).
--
-- ▶ 배포: 본 파일은 DDL 정본(에이전트 작성). CREATE/GRANT 실행은 사용자가 GN_DW_ADMIN 역할로 수행.
--     소유=GN_DW_ADMIN · 위치=GN_DW.SERVING(P7 serving_separation) · base=GN_DW.GOLD cross-schema 참조.
--
-- ▶ [원천] 절 규약 (2026-07-29 신설 · BRONZE lineage 노출):
--     모든 SV의 **테이블 COMMENT**와 **SV 최상위 COMMENT**에 `[원천]`/`[원천 요약]` 절을 기입한다.
--     목적: Agent(Cortex Analyst)가 SV 메타데이터를 context로 읽으므로, "이 수치 어디서 온 거야?"
--           류의 데이터 출처(provenance) 질문에 **창작 없이** 답할 수 있게 한다.
--     형식: `[원천] 시스템=<원천시스템> · BRONZE=<DB.스키마.테이블(핵심컬럼)> · SILVER=<정제테이블>`
--     BRONZE 스키마 4종(02_DB_BRONZE_SILVER.md §원천 목록):
--       GN_DW.BRONZE_CRM    — CRM(eCRM·UMS) 직적재 (43테이블/927컬럼 실측)
--       GN_DW.BRONZE_ERP    — ERP 예산·실적 원장 (파일 업로드 → 테이블화)
--       GN_DW.BRONZE_AGENCY — 대행사 일별 리포트 (Google Sheet·Drive Excel·SharePoint Excel, 3테이블)
--       GN_DW.BRONZE_GA4    — BigQuery GA4 events 일별 샤드
--     정본 계보: 30_output_share/04_컬럼계보매핑.md (GOLD컬럼→SILVER→BRONZE 1:1 · 자동생성)
--               30_output_share/05_지표GOLD매핑.md (지표#→GOLD배속→SILVER→BRONZE, 215지표)
--               03_top-down_gold/08_silver의존.md  (SILVER→BRONZE lineage 확정)
--     ⚠ 컬럼 단위 완전 매핑은 SV COMMENT에 넣지 않는다(토큰 낭비·유지보수 이중화). SV에는 **테이블 수준**만
--       기입하고, 세부는 위 정본 문서로 안내하도록 Agent instructions에 규칙을 둔다(09_AGENT_spec_구현.sql).
--     ⚠ 원천이 바뀌면 04_컬럼계보매핑.md 재생성(scripts/gen_column_mapping.py) 후 본 파일의 [원천] 절도 동기화.

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
      COMMENT = '회원 월별 스냅샷 팩트(grain=월×회원, 40.05M · 실측 유일 → PK). 회비/개발/중단 월 롤업. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 회비/청구 TM_PM_MBRFEE_ACMSLT(PAY_AMT·RQEST_AMT·PAY_STAT_CD)+TM_PM_DNTN_DTLS(PAY_AMT) · 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC · 증감 TM_MM_FDRM_MBER_IRSD(SPNSR_AMT·RDCAMT_YN) · SILVER=CRM_PAYMENT_BILLING·CRM_MEMBER_DEV·CRM_MEMBER_DISCONTINUE·CRM_MEMBER_AMT_CHANGE.',
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
    member.GENDER        AS member.GENDER        WITH SYNONYMS ('성별')             COMMENT = '회원 성별',
    member.MEMBER_STATUS AS member.MEMBER_STATUS WITH SYNONYMS ('회원상태', '상태') COMMENT = '현재 회원상태(과거월 조회 시에도 현재 기준)',
    member.MEMBER_TYPE   AS member.MEMBER_TYPE   WITH SYNONYMS ('회원구분', '구분') COMMENT = '회원 구분',
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
  COMMENT = 'Phase-1 회원 월별 실적 SV(base FMM). [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(회비 TM_PM_MBRFEE_ACMSLT·기부 TM_PM_DNTN_DTLS·개발 TM_MM_FDRM_MBER_DVLP_AMT·중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC·증감 TM_MM_FDRM_MBER_IRSD·회원 TM_MM_FDRM_MBER_INFO) → SILVER(CRM_*) → GOLD(FMM). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 납입/청구 총액·납부율(공64)·미납회원 감소율(공80)·개발/중단 총건·총미납금액·미납비중·평균납입회비(PoC 이식). 시간=전체가능. 회비 지표는 HAS_BILLING=TRUE 전제 권장. 회원상태/성별/구분은 현재 스냅샷 기준(과거월도 현재값). 비활성(적재 대기): 캠페인/납입방식/후원사업/사유별 분해(FK=0), 활동/누계/미납 카운트 비율(ACTIVE_CNT=0), 신규기존 분해(NEF=0), 지역/연령대(dim 공란).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(회원구분·성별·회원상태 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 12개 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 납부율·미납비중 등 비율은 총계 행에서 SUM 기반으로 정확히 산출한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';

-- 비활성(Phase-2/적재 후) — 구조 불변, 적재 완결 시 metric만 추가:
--   공45~47 활동율·공54~57 중단율·공76~78 미납율(ACTIVE/MONTH_END/YEAR_START_ACTIVE_CNT = 전건 0)
--   신12~29 캠페인/납입방식별 (CAMPAIGN_SK·PAYMENT_SK = 0) · 공79 후원사업별 (SPONSORSHIP_SK = 0)
--   공1~3 목표대비 (BRG_DEV_VS_TARGET 브리지 · 04 §8.1) · 공81 미납서비스 전환율 (GA identity 브리지 · P2)


/* =====================================================================================
   2. SV_MEMBER_EVENT (회원 Agent) — base FME(일×회원×상태전이)
      활성: 개발/중단 총건·고유회원수 · 사건일/주차 (유지기간 신4는 데이터 부재로 Phase-2 유예)
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT
  TABLES (
    fme AS GN_DW.GOLD.FACT_MEMBER_EVENT
      WITH SYNONYMS ('회원 상태전이', '개발중단 사건')
      COMMENT = '회원 상태전이 사건 팩트(4.63M). 1행=1개발/중단 사건. ⚠(DATE_SK,MEMBER_DK,EVENT_TYPE) 실측 비유일(distinct 4,052,797) → PK 미선언(기저 FACT·참조 안 됨·집계 무해, 2026-07-22). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT·MBER_NO) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC(SPNSR_DSCNTC_DE·DSCNTC_RSN_CD·DSCNTC_PATH) · SILVER=CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE.',
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
    fme.EVENT_TYPE    AS fme.EVENT_TYPE     WITH SYNONYMS ('전이유형', '사건유형', '개발중단구분') COMMENT = '상태전이 유형(개발/중단/증액/미납중단 등)',
    fme.JOIN_DATE     AS fme.JOIN_DATE      WITH SYNONYMS ('가입일')      COMMENT = '회원 가입일(유지기간 산출 기준)',
    fme.STOP_DATE     AS fme.STOP_DATE      WITH SYNONYMS ('중단일', '해지일') COMMENT = '회원 중단일',
    member.GENDER        AS member.GENDER        WITH SYNONYMS ('성별')     COMMENT = '회원 성별',
    member.MEMBER_STATUS AS member.MEMBER_STATUS WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태',
    member.MEMBER_TYPE   AS member.MEMBER_TYPE   WITH SYNONYMS ('회원구분') COMMENT = '회원 구분'
  )
  METRICS (
    fme.TOTAL_DEV_CNT     AS SUM(fme.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건') COMMENT = '개발 건수 합계. F(가산).',
    fme.TOTAL_STOP_CNT    AS SUM(fme.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단 건수 합계. F(가산).',
    fme.DEV_MEMBER_COUNT  AS COUNT(DISTINCT CASE WHEN fme.DEV_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('개발회원수', '신규 회원수') COMMENT = '개발 고유 회원수. D(distinct). 다기간도 중복 없음.',
    fme.STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('중단회원수', '해지 회원수') COMMENT = '중단 고유 회원수. D(distinct).'
    -- ⚠ AVG_RETENTION_MONTHS(신4 유지기간) 제거(2026-07-22 검증): FME는 개발행에 JOIN_DATE·중단행에 STOP_DATE가
    --   서로 다른 행에 있어 행별 DATEDIFF가 전건 NULL, DIM_MEMBER_CURRENT.LAST_STOP_DATE도 미적재 → 산출 불가.
    --   유지기간/유지율/LTV(신4·6~8)는 회원 가입↔중단 페어링(코호트) 필요 → Agent/Phase-2 확장.
  )
  COMMENT = 'Phase-1 회원 상태전이 SV(base FME, 일 grain). [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(개발 TM_MM_FDRM_MBER_DVLP_AMT·중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC) → SILVER(CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE) → GOLD(FME). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 개발/중단 건·고유회원수. 시간=전체가능. 유지기간/유지율/LTV(신4·6~8)는 가입↔중단 페어링(LAST_STOP_DATE 미적재·FME 행별 단일일자)로 Phase-1 산출 불가 → Agent/Phase-2 확장. 비활성(적재 대기): 조직/캠페인/후원사업/사유별 분해(ORG_SK·FK=0), 신규기존 분해(NEF=0), 미납중단(UNPAID_STOP=0).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(회원구분·전이유형·성별 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 12개 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   3. SV_SERVICE (회원 Agent) — base FSE(일×회원×서비스×캠페인)
      활성: 발송수 총량·고유회원수 · 서비스구분(A3 SERVICE_SK)·발송상태
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_SERVICE_EVENT
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송')
      COMMENT = '서비스 발송 팩트(38.47M). ⚠(DATE_SK,MEMBER_DK,SERVICE_SK) 실측 비유일(distinct 36,651,766) → PK 미선언(기저 FACT·집계 무해, 2026-07-22). [원천] 시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM: 발송마스터 TM_MS_EMAIL_SNDNG·TM_MS_MSG_AT_SNDNG·TM_MS_PSTMTR_SNDNG · 발송상세 TD_MS_EMAIL_SNDNG_DTLS·TD_MS_MSG_AT_SNDNG_DTLS·TD_MS_PSTMTR_SNDNG_DTL(MBER_NO·SNDNG_RST_CD) · 성과 TD_MS_*_LQY_SNDNG(성공/실패, 현재 미적재) · SILVER=CRM_SEND_REQUEST·CRM_SEND_MEMBER·CRM_SEND_RESULT.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK 99.97% 커버). 미매칭=Unknown(SK=0). [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST(SEND_GBN_TOP/MID/BOT 대·중·소분류 코드) · SILVER=CRM_SEND_REQUEST.',
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
    member.GENDER        AS member.GENDER        WITH SYNONYMS ('성별')     COMMENT = '회원 성별',
    member.MEMBER_STATUS AS member.MEMBER_STATUS WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태',
    member.MEMBER_TYPE   AS member.MEMBER_TYPE   WITH SYNONYMS ('회원구분') COMMENT = '회원 구분'
  )
  METRICS (
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송 회원수') COMMENT = '발송수 합계. F(가산).',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 고유회원수', '수신 대상 회원수') COMMENT = '발송 대상 고유 회원수. D(distinct). 다기간 중복 방지.'
  )
  COMMENT = 'Phase-1 서비스 발송 SV(base FSE). [원천 요약] 원천시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM(TM_MS_EMAIL/MSG_AT/PSTMTR_SNDNG + TD_MS_*_SNDNG_DTLS + SND_REQ_MST) → SILVER(CRM_SEND_*) → GOLD(FSE). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 발송수·고유 발송회원수, 서비스구분/발송상태/발송일별. 시간=전체가능. 비활성(적재 대기): 수신/성공/실패/오픈(SUCCESS/FAIL/OPEN=0), 서신/선물금/증액 참여·+5일 코호트(D5_*=0, 신31~53), 캠페인별(CAMPAIGN_SK=0).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(채널·서비스유형·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 12개 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   4. SV_EVENT_PARTICIPATION (회원 Agent) — base FEP(일×회원×행사)
      활성: 참여자수·참여건수·고유 참여회원수 · 행사명/종류/구분(EVENT_SK 76.8%)
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
  TABLES (
    fep AS GN_DW.GOLD.FACT_EVENT_PARTICIPATION
      WITH SYNONYMS ('행사 참여', '이벤트 참여')
      COMMENT = '행사 참여 팩트(1.13M). ⚠(DATE_SK,MEMBER_DK,EVENT_SK) 실측 비유일(distinct 843,414) → PK 미선언(기저 FACT·집계 무해, 2026-07-22). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: 참여상세 TD_MS_EVENT_PRTCPNT_DTL(MBER_NO·PARTCPT_STAT_CD·RCPMNY_AMT) ∪ TD_MS_CRMN_PRTCPNT(캠페인행사) · SILVER=CRM_EVENT_PARTICIPATION.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '참여일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    event AS GN_DW.GOLD.DIM_EVENT
      PRIMARY KEY (EVENT_SK)
      WITH SYNONYMS ('행사', '이벤트')
      COMMENT = '행사 차원. EVENT_SK 고아 23%(이슈 E) → Unknown(SK=0) 라우팅, 행사명별 집계는 부분. [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: TM_MS_EVENT(EVENT_NM·STRT_DE) ∪ TM_MS_CRMN(캠페인행사) · SILVER=CRM_EVENT.',
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
    member.GENDER        AS member.GENDER        WITH SYNONYMS ('성별')     COMMENT = '회원 성별',
    member.MEMBER_STATUS AS member.MEMBER_STATUS WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태',
    member.MEMBER_TYPE   AS member.MEMBER_TYPE   WITH SYNONYMS ('회원구분') COMMENT = '회원 구분'
  )
  METRICS (
    fep.TOTAL_PARTICIPANTS AS SUM(fep.PARTICIPANT_CNT)
      WITH SYNONYMS ('참여자수', '참가자수') COMMENT = '참여자수 합계. F(가산).',
    fep.TOTAL_PARTICIPATE_CNT AS SUM(fep.PARTICIPATE_CNT)
      WITH SYNONYMS ('참여건수') COMMENT = '참여 건수 합계. F(가산).',
    fep.DISTINCT_PARTICIPANTS AS COUNT(DISTINCT fep.MEMBER_DK)
      WITH SYNONYMS ('고유 참여회원수') COMMENT = '고유 참여 회원수. D(distinct).'
  )
  COMMENT = 'Phase-1 행사 참여 SV(base FEP). [원천 요약] 원천시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM(행사 TM_MS_EVENT∪TM_MS_CRMN · 참여 TD_MS_EVENT_PRTCPNT_DTL∪TD_MS_CRMN_PRTCPNT) → SILVER(CRM_EVENT+CRM_EVENT_PARTICIPATION) → GOLD(FEP). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분·참여일별. 행사 미매칭 23%(EVENT_SK=0 Unknown 라우팅) → 행사명별 집계는 부분, 확정치로 단정 금지. 비활성(적재 대기): 모집/총원(TOTAL/RECRUIT_CNT=0), 캠페인/후원사업별(FK=0).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(행사종류·행사명·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 12개 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   5. SV_BUDGET (overall Agent) — base FBD(월×조직×세세목)
      활성: 편성예산(월)·집행예산(ERP)·집행율 · 세세목명/예산구분
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 팩트(grain=월×세세목, 24.5K · 실측 유일 → PK). 편성/집행. [원천] 시스템=ERP(예산관리, Snowflake 파일 업로드 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(예산·실적 원장): 편성 YEAR_BDGT_AMT_n · 집행 EXEC_AMT_n — 12개월 wide 컬럼을 월 long으로 언피벗 · SILVER=ERP_BUDGET.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] 시스템=ERP · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(JANG_NM~SUBDTL_ITEM_NM 장·관·항·목·세목·세세목 6단계 계층 + BDGT_UNIT_NM 예산단위) — DISTINCT 마스터화·MD5 대리키 · SILVER=ERP_BUDGET_ITEM.'
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
      WITH SYNONYMS ('집행율', '예산 집행율') COMMENT = '집행율(%) = 집행예산 ÷ 편성예산 ×100. 비율(N).'
  )
  COMMENT = 'Phase-1 예산 SV(base FBD). [원천 요약] 원천시스템=ERP(예산관리 · Snowflake 파일 업로드로 bronze 적재) · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(편성 YEAR_BDGT_AMT_n·집행 EXEC_AMT_n 월 언피벗, 세세목 JANG_NM~SUBDTL_ITEM_NM) → SILVER(ERP_BUDGET+ERP_BUDGET_ITEM) → GOLD(FBD). ⚠광고비는 이 SV의 원천(ERP)에 없다 — 광고비는 AGENCY 원천의 SV_AD 소관(예산 원장에 광고비 컬럼 부재, E-4). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 편성예산(월)·집행예산(ERP)·집행율, 세세목/예산구분/월별. 비활성(적재 대기): 연 편성예산(PLAN_BUDGET_YEAR=0), 집행추정/모금성비용/광고비(=0), 조직/캠페인별(ORG/CAMPAIGN_SK=0), 개발단가·ROI(신9~11, O3·E-6 대기).'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(세세목·예산구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 12개 월별 행 + 전체 총계(합계·집행율) 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 편성예산·집행예산·집행율을 월별로 보여준다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다. ⚠집행율 산정 주의: 현재 집행예산(EXEC_BUDGET_ERP)은 특정 월까지만 적재돼 있고 나머지 월은 0이다(2026-07-29 실측: 202601~202605만 실질 집행 존재). 편성은 12개월 전량이므로, 집행율을 연 합계(전체 편성 ÷ 일부 집행)로 내면 분모가 과대해 집행율이 구조적으로 낮게 나온다. 이를 방지하기 위해 — (A) 집행율을 구할 때는 집행 데이터가 있는 월(EXEC_BUDGET_ERP<>0)만 편성 분모에 포함한다: SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN PLAN_BUDGET_MONTH END)을 분모로, SUM(CASE WHEN EXEC_BUDGET_ERP<>0 THEN EXEC_BUDGET_ERP END)을 분자로 쓴다. (B) 집행 미적재 월은 "집행 미반영"으로 표기하며 편성만 보여준다. (C) 답변에 "집행 적재 기간 = 202601~202605, 이후 미반영"임을 반드시 명시한다. (D) 월별 ROLLUP 총계도 (A) 스코프로 산정한다.';


/* =====================================================================================
   6. SV_AD (overall Agent) — base FACT_AD_COMBINED(helper, FAP+FAD+FAB 1:1 pre-join) + DIM_DEVICE + DIM_DATE
      선행: SERVING.FACT_AD_COMBINED helper 뷰 생성 필요 (아래 CREATE VIEW 포함)
      활성: 광고비·노출·클릭·CTR(디지털)·CVR(디지털)·CRM개발건·개발단가(디지털)
             인바운드콜·방송횟수(방송) · 재방송개발건·재방송 개발단가(재방송) · 기기·출처유형·매체사·시간대·프로그램 차원
       🔴 전환콜(CONV_CALL_CNT)은 원천 전건 NULL → metric 미노출(2026-07-29 제거 · METRICS 절 상단 근거 주석)
      ⚠ CAMPAIGN_SK·AD_CREATIVE_SK 전건 0 → 캠페인/소재별 분해 불가(Phase-2)
      ⚠ 디지털/방송 measure 상호배타 — AD_SOURCE_TYPE 필터 없이 혼합집계 시 왜곡 주의
   ===================================================================================== */

-- 6-0. helper 뷰: FAP+FAD+FAB 1:1 pre-join (세 팩트가 AD_PERF_DK로 완전분할, fan-out 0)
--   근거: Snowflake semantic view metric은 단일 테이블 컬럼만 참조 가능 → 개발단가(AD_COST÷CRM_DEV_CNT)
--   등 cross-satellite 비율 metric 산출을 위해 사전 조인. DIM_MEMBER_CURRENT helper 패턴 동일.
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

-- helper 뷰 COMMENT (2026-07-29 추가 — DIM_MONTH·DIM_MEMBER_CURRENT 와 동일 규약. ⚠재배포 필요: 현 DB의 본 뷰 COMMENT는 NULL)
--   ※ 뷰 COMMENT는 ALTER VIEW ... SET COMMENT 사용(COMMENT ON VIEW 는 미지원 — 10_WIDE VIEW 코멘트.sql §2 동일 규약).
ALTER VIEW GN_DW.SERVING.FACT_AD_COMBINED SET COMMENT =
  'GOLD 광고 팩트 3종(FAP 코어 + FAD_D·FAD_B 위성)을 AD_PERF_DK 로 1:1 pre-join — SV_AD 의 단일 base. PK=AD_PERF_DK(235,572행 전건 유일, fan-out 0). 위성은 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(디지털행=방송컬럼 NULL, 방송행=디지털컬럼 NULL — 결측이 아니라 원천 부재). 존재 이유: Snowflake semantic view metric 식은 자기 logical table 컬럼만 참조 가능해 개발단가(AD_COST÷CRM_DEV_CNT) 등 cross-satellite 비율을 SV 에서 직접 계산할 수 없다.';

-- helper 뷰 GRANT (소비 역할이 SV를 통해 간접 접근)
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.FACT_AD_COMBINED TO ROLE GN_DW_SERVICE;

-- 6-1. SV_AD 본체
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.SERVING.FACT_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '광고 실적 통합 팩트(FAP+FAD+FAB pre-join, 235,572행 유일). AD_SOURCE_TYPE으로 디지털/방송 구분. [원천] 시스템=대행사(Agency) 일별 리포트(Google Sheet · Google Drive Excel · MS SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY: 디지털 DGT_AD_CMPGN_DTLS(광고비·노출·클릭·CRM개발건·MEDIA_NM) · 방송(비디오) VIDEO_AD_CMPGN_DTLS · 방송(재방) REBRDC_AD_CMPGN_DTLS(광고비·인입콜·방송횟수·개발건수) / GN_DW.BRONZE_GA4.events_YYYYMMDD(GA 전환·기기) · SILVER=AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT. ⚠_SRC 접미 컬럼은 대행사가 원천에서 이미 계산해 제공한 비율 원값(재집계 금지).',
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
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형(DIGITAL/VIDEO/REBROADCAST). 디지털/방송 measure 필터 필수.',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    -- 기기
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC') COMMENT = '기기 유형. 실제 코드값 4종: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    -- 디지털 전용 차원
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용.',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용(39% 채움).',
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용.',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용.',
    -- 방송 전용 차원
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사') COMMENT = '방송 채널사(61종). VIDEO/REBROADCAST 전용.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대(24종). 방송 전용.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(1,837종, 94% 채움). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용.',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서') COMMENT = 'CM 내 위치(16종). 방송 전용.',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분') COMMENT = '본방/재방 유형. 방송 전용.'
  )
  METRICS (
    -- 공통 measure
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능. 총 514.4억원.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL). 총 165,462(REBROADCAST 113,241 + VIDEO 52,221).',
    ad.TOTAL_GA_CONV_MEMBERS AS SUM(ad.GA_CONV_MEMBERS)
      WITH SYNONYMS ('GA전환회원', '전환회원수') COMMENT = 'GA 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용. 실측 2024 0.199% / 2025 0.286% / 2026 0.345%.',
    ad.CVR AS SUM(ad.GA_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = GA전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    -- 디지털 전용 measure
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). 총 249,390. 소수값 포함(189,252행 중 24,614행 비정수 — 기여도 배분 추정) → 정수 단정 금지. 적재범위 2024-01~2026-05(2026-06부터 원천이 개발건수 대신 단가를 제공 → 미적재).',
    -- ⚠ 분자를 분모 적재행으로 정합(CASE WHEN) — 미적재행 광고비를 분자에 넣으면 단가가 과대계상된다.
    --   미정합 시 2026 단가 125,482원(오) vs 정합 103,066원(정) — 2026-06 광고비가 분모 없이 분자에만 들어간 탓.
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외) → 2026-06 이후는 산출 불가(NULL). 실측 2024 131,367원 / 2025 110,335원 / 2026(1~5월) 103,066원.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산). 총 8.17M.',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산).',
    -- 방송 전용 measure
    --   🔴 [2026-07-29 제거] ad.TOTAL_CONV_CALL_CNT (전환콜) — 원천 전건 NULL 이므로 **미노출**.
    --      실측: BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT 35,822행 전량 NULL
    --            → SILVER.AGENCY_AD_BROADCAST → GOLD.FACT_AD_BROADCAST → helper 전 계층 SUM=NULL.
    --      종전 배포 COMMENT의 "총 49,093" 은 현 데이터에 근거가 없다(실측 대조 실패).
    --      제거 근거: 20_issue/30_설계_의사결정.md — "빈 metric 은 0/NULL 을 사실처럼 반환" 🔴 금지.
    --                 선례 AVG_RETENTION_MONTHS(순9-E, 전건 NULL → 제거)와 동일 처리.
    --      ⚠ 순9-K(REBRDC_DEV_UNIT_PRICE 오진 제거)와는 다른 사안이다 — 그쪽은 값이 있는데 분모 모집단을
    --        잘못 잡은 경우였고, 이쪽은 값 자체가 원천에 없다.
    --      helper 뷰의 brc.CONV_CALL_CNT 컬럼은 무손실 원칙상 유지(SV 노출만 차단).
    --      → 대행사가 전환콜을 실제 제공하기 시작하면 이 metric 만 되살린다(구조 불변). 현업확인 AD-6.
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). 총 36,712(REBROADCAST 2,059 + VIDEO 34,653). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '재방송 개발건수 합계. F(가산). 총 96,321. **REBROADCAST 전용** — VIDEO는 원천(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 **구조적으로 부재**(대행사 비디오 리포트는 개발 대신 전환콜 보고)하므로 결손이 아니다. REBROADCAST 내 커버리지 **96.03%**(2,064행 중 1,982행). ⚠VIDEO를 포함한 "방송 전체" 개발 규모로 확대 해석 금지.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '재방송 개발회원수 합계. F(가산). **REBROADCAST 전용**(VIDEO 원천에 컬럼 부재). REBROADCAST 내 커버리지 96.03%.',
    -- ✅ 공8 재방송 개발단가 — 2026-07-29 실측 재검증 후 **복원**(종전 제거 결정은 오진).
    --    [오진 경위] 종전(2026-07-28) 근거 "커버리지 5.2% · 41% 과대계상"은 REBROADCAST의 개발건수를
    --      VIDEO까지 합친 분모(37,886행)로 나눈 값이다. VIDEO는 원천에 개발 컬럼이 **없어**(구조적 부재)
    --      결손으로 셀 대상이 아니다 → 범주 오류.
    --    [실측 2026-07-29] REBROADCAST 단독: 커버리지 1,982/2,064 = **96.03%**,
    --      미정합 158,933.27원 vs 정합 157,969.27원 = **왜곡 0.61%** (방송합계 기준이던 41.5%가 아님).
    --      또한 종전 주석의 "방송 광고비의 29%만 반영"은 수치가 뒤집힌 오기 —
    --      정합 분자 ₩15,215,758,016 / 방송합계 ₩21,524,449,226 = **70.7% 포함**(29%는 제외되는 VIDEO 몫).
    --    [명명] `BRDC_`(방송)가 아니라 `REBRDC_`(재방송)로 둔다. VIDEO(방송 광고비의 29%)에 개발 개념이
    --      없으므로 "방송 개발단가"는 여전히 스코프를 오인시킨다 — 종전 주석의 문제의식은 타당했고,
    --      해법이 "제거"가 아니라 "정확한 스코프 명명"이었다.
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '공8 재방송 개발단가(원) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(VIDEO 원천에 개발 컬럼 부재 → 방송 전체 단가가 아님). 분자를 개발건수 적재행으로 정합(미적재 82행 광고비 제외). 실측 157,969원(커버리지 96.03% · 정합 왜곡 0.61%). ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 41.5% 과대계상.'
  )
  COMMENT = 'Phase-1 광고 실적 SV(base FACT_AD_COMBINED helper, 235,572행). [원천 요약] 원천시스템=대행사(Agency) 일별 리포트(Google Sheet·Drive Excel·SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY(디지털 DGT_AD_CMPGN_DTLS · 방송 VIDEO_AD_CMPGN_DTLS+REBRDC_AD_CMPGN_DTLS) + GN_DW.BRONZE_GA4.events_YYYYMMDD → SILVER(AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT) → GOLD(FAP+FAD+FAB). ⚠예산(SV_BUDGET)은 ERP 원천으로 서로 다른 시스템 — 교차 집계 불가. 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 광고비(514.4억)·노출·클릭·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7) [디지털] / 인바운드콜·방송횟수 [방송] / 재방송개발건·재방송 개발단가(공8) [재방송 전용]. 기간: 디지털 2024-01 - 2026-06, 방송 2023-01 - 2026-07. ⚠디지털/방송 measure 상호배타. ⚠캠페인/소재별 분해 불가(FK=0, Phase-2). ⚠개발단가(공7)는 2026-06 이후 산출 불가(원천이 개발건수 대신 단가 제공). ⚠개발건수/개발단가는 **REBROADCAST 전용** — VIDEO 원천(VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 구조적으로 부재하므로 "방송 전체" 지표가 아니다(REBROADCAST 내 커버리지 96.03%). VIDEO 혼합 집계 시 41.5% 과대계상. ⚠전환콜(CONV_CALL_CNT)은 대행사 원천이 전건 비어 있어 이 SV에 measure가 없다 — 질문받으면 미제공으로 안내(추정치 생성 금지).'
  AI_SQL_GENERATION '핵심 규칙: (1) AD_SOURCE_TYPE 필터가 없는 질문에서 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객은 반드시 AD_SOURCE_TYPE=''DIGITAL'' 필터를 자동 추가한다. 인바운드콜·방송횟수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 필터를 자동 추가한다. **개발건수(재방송개발건·재방송개발회원)와 재방송 개발단가(공8)는 AD_SOURCE_TYPE=''REBROADCAST'' 필터를 자동 추가한다** — VIDEO 원천에 개발 컬럼이 없어 혼합 시 41.5% 과대계상된다. 광고비만 전체 합산 허용. (2) 적용 조건(기간·그룹 미지정 시): 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고, GROUP BY ROLLUP((연,월))로 월별 행 + 총계 행을 함께 반환한다. (3) 캠페인별·소재별 분해 요청은 캠페인/소재 연결키 미적재(Phase-2)로 안내하고 SQL 생성하지 않는다. (4) 기기 필터: 모바일은 DEVICE_TYPE=''M''(''MOBILE''/''TABLET'' 아님), 데스크톱은 ''PC''. 방송은 ''(해당없음)''이므로 기기별 분석은 디지털에만 적용한다. (5) 개발단가(공7, 디지털)는 2026-06 이후 원천 미적재로 NULL이다. 최신월 기준 질문에는 산출 가능한 최신월(2026-05)까지로 기간을 한정하고, 2026-06 이후는 원천 포맷 변경으로 산출 불가임을 답변에 명시한다. (6) 개발건수·개발단가를 "방송"으로 묻더라도 **재방송(REBROADCAST) 전용 지표**임을 답변에 명시한다 — VIDEO는 대행사 원천에 개발 컬럼이 없어 집계 대상이 아니며(결손이 아니라 구조적 부재), 따라서 방송 전체 개발 규모로 단정하면 안 된다. 재방송 내 커버리지는 96.03%다. (7) **전환콜**은 이 SV에 measure가 없다 — 대행사 원천(VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT)이 전건 비어 있기 때문이다. 질문받으면 SQL을 생성하지 말고 미제공 사유를 답하고, 인바운드콜(INBOUND_CALL)로 대체 가능한지 되묻는다. 전환콜 수치를 추정·창작하지 않는다.';


/* =====================================================================================
   7. GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST가 VIEWER를 상속(계층)하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      ⚠ CREATE OR REPLACE는 기존 GRANT를 전부 삭제(OWNERSHIP만 잔존)한다 → **단일 SV 재배포 시 해당 SV의
        GRANT 3줄을 반드시 재실행**. (2026-07-22 SV_MEMBER_EVENT 재배포 시 grant 소실 실측·재부여 확인.)
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

/*
=====================================================================================
   7. 스모크 검증 (배포 후 사용자 실행) — fan-out 차단 확인 (04 §0.1 DoD)
      SEMANTIC_VIEW(...) 집계 = 단일 FACT 직접 SUM 일치 → 월/회원 조인 fan-out 0 검증.
   =====================================================================================;
-- (7-1) SV_MEMBER_MONTHLY 납입회비 총액 == FMM 직접 SUM
SELECT (SELECT TOTAL_PAID_FEE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_PAID_FEE)) AS sv_val,
       (SELECT SUM(PAID_FEE) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY)                                        AS fact_val;

-- (7-2) SV_SERVICE 발송수 총합 == FSE 직접 SUM (서비스 조인 fan-out 0)
SELECT (SELECT TOTAL_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS TOTAL_SEND_MEMBERS)) AS sv_val,
       (SELECT SUM(SEND_MEMBERS) FROM GN_DW.GOLD.FACT_SERVICE_EVENT)                                       AS fact_val;

-- (7-3) 차원 조인 스모크: 회원 성별별 개발건
SELECT * FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_EVENT
  DIMENSIONS member.GENDER
  METRICS TOTAL_DEV_CNT
) ORDER BY 1;

-- (7-4) SV_AD 광고비 총액 == FAP 직접 SUM (위성 조인 fan-out 0)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                            AS fact_val;

-- (7-5) SV_AD 디지털 CTR 스모크
SELECT * FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR
  METRICS TOTAL_AD_COST, CTR
  FILTER fap.AD_SOURCE_TYPE = 'DIGITAL'
) ORDER BY 1;

-- (7-6) 확인: SHOW SEMANTIC VIEWS
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
=====================================================================================
*/
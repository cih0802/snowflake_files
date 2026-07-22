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
-- ▶ 실측 활성 매트릭스 (COUNT_IF, 2026-07-22 · A1/A3 적재 반영):
--   ⚠ 아래 수치는 모두 **COUNT_IF = 값이 채워진(>0) 행 수**이다. SV에 노출되는 metric은 **SUM 집계**이므로 값이 다르다.
--     예) FMM DEV_CNT: COUNT_IF(행수)=2,970,417 이나 TOTAL_DEV_CNT=SUM(DEV_CNT)=3,594,843.
--         FMM STOP_CNT: COUNT_IF(행수)=972,376 이나 TOTAL_STOP_CNT=SUM(STOP_CNT)=1,038,262.
--     → 06/07 검증·평가셋의 metric 값(SUM 기준)과 대조할 때 이 구분에 유의(모순 아님).
--     FMM 40.05M : PAID_FEE 36.1M · BILLED_AMT 37.1M · DEV_CNT 2.97M · STOP_CNT 0.97M · UNPAID_FLAG_BOM 3.19M/EOM 3.30M · HAS_BILLING 37.79M ✅
--                  ACTIVE/CUM/MONTH_END/INCREASE 건·명 · CAMPAIGN/PAYMENT/SPONSORSHIP/REASON_SK · NEW_EXISTING_FLAG = 전건 0 ❌
--     FME 4.63M  : DEV_CNT/DEV_MEMBERS 3.59M · STOP_CNT/STOP_MEMBERS 1.04M · JOIN/STOP_DATE ✅ / ORG_SK·FK·NEF = 0 ❌
--     FSE 38.47M : SEND_MEMBERS(전행) · SEND_STATUS 35.75M · SERVICE_SK 99.97% · SEND_TITLE ✅ / SUCCESS/FAIL/OPEN/D5/LETTER/GIFT·CAMPAIGN_SK = 0 ❌
--     FEP 1.13M  : PARTICIPANT_CNT/PARTICIPATE_CNT(전행) · EVENT_SK 76.8%(고아 23%) ✅ / TOTAL/RECRUIT_CNT·CAMPAIGN/SPONSORSHIP_SK = 0 ❌
--     FBD 24.5K  : PLAN_BUDGET_MONTH 7,290 · EXEC_BUDGET_ERP 3,244 · BUDGET_ITEM_SK(전행) ✅ / 연예산·집행추정·모금성/광고비·ORG/CAMPAIGN_SK = 0 ❌
--     활성 dim속성: 회원 GENDER 1.76M·MEMBER_STATUS 1.59M·MEMBER_TYPE 1.76M ✅ / REGION·AGE_BAND·FIRST_SPONSORSHIP = 0 ❌
--                   서비스 SUBTYPE·CHANNEL ✅ / SEND_TYPE_L/M/S = 0 ❌ · 행사 EVENT_NAME/KIND/CATEGORY ✅ / APPLY_CHANNEL = 0 ❌ · 세세목 NAME/CATEGORY ✅
--
-- ▶ 가드레일 준수:
--     R1 fan-out : 월팩트→SERVING.DIM_MONTH(월 grain) · 회원속성→SERVING.DIM_MEMBER_CURRENT(현재행) — raw DIM_DATE/DIM_MEMBER 직접조인 금지.
--     R5 가산성  : F(flow)=SUM metric / D(distinct 회원)=COUNT(DISTINCT MEMBER_DK) metric(다월 중복 방지) / 비율=분자·분모 각각 집계 후 division.
--     조인키 타입: MEMBER_DK=VARCHAR(캐스팅 금지) · MONTH_KEY/DATE_SK/*_SK=NUMBER.
--     PRIMARY KEY(2026-07-22 정정): 실측 유일한 FMM(MONTH_KEY,MEMBER_DK)·FBD(MONTH_KEY,BUDGET_ITEM_SK)만 선언.
--                 FME/FSE/FEP는 선언 grain이 실측 비유일(FME 4.63M→4.05M·FSE 38.47M→36.65M·FEP 1.13M→0.84M) → PK 미선언.
--                 기저 FACT는 다른 테이블에서 참조되지 않아(관계의 다측) PK 불요 · fan-out/집계 무해(compile 확인).
--     비활성    : 실측 0/NULL(FK·SUCCESS·D5·연예산 등)은 SV에서 제외(하단 비활성 주석) — 적재 완결 시 metric만 추가(구조 불변).
--
-- ▶ 배포: 본 파일은 DDL 정본(에이전트 작성). CREATE/GRANT 실행은 사용자가 GN_DW_ADMIN 역할로 수행.
--     소유=GN_DW_ADMIN · 위치=GN_DW.SERVING(P7 serving_separation) · base=GN_DW.GOLD cross-schema 참조.

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
      COMMENT = '회원 월별 스냅샷 팩트(grain=월×회원, 40.05M · 실측 유일 → PK). 회비/개발/중단 월 롤업.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '조회월', '기간')
      COMMENT = '월 차원(DIM_DATE 월 grain DISTINCT). fan-out 차단용 helper 뷰.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷(SCD2 IS_CURRENT). 불변/현재 속성 전용. fan-out 차단용 helper 뷰.'
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
      WITH SYNONYMS ('미납회원 감소율') COMMENT = '공80 미납회원 감소율(%) = (월초미납−월말미납) ÷ 월초미납 ×100. 비율(N).'
  )
  COMMENT = 'Phase-1 회원 월별 실적 SV(base FMM). 활성: 납입/청구 총액·납부율(공64)·미납회원 감소율(공80)·개발/중단 총건. 시간=전체가능. 회비 지표는 HAS_BILLING=TRUE 전제 권장. 회원상태/성별/구분은 현재 스냅샷 기준(과거월도 현재값). 비활성(적재 대기): 캠페인/납입방식/후원사업/사유별 분해(FK=0), 활동/누계/미납 카운트 비율(ACTIVE_CNT=0), 신규기존 분해(NEF=0), 지역/연령대(dim 공란).';

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
      COMMENT = '회원 상태전이 사건 팩트(4.63M). 1행=1개발/중단 사건. ⚠(DATE_SK,MEMBER_DK,EVENT_TYPE) 실측 비유일(distinct 4,052,797) → PK 미선언(기저 FACT·참조 안 됨·집계 무해, 2026-07-22).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '일자', '사건일')
      COMMENT = '일 차원.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰.'
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
  COMMENT = 'Phase-1 회원 상태전이 SV(base FME, 일 grain). 활성: 개발/중단 건·고유회원수. 시간=전체가능. 유지기간/유지율/LTV(신4·6~8)는 가입↔중단 페어링(LAST_STOP_DATE 미적재·FME 행별 단일일자)로 Phase-1 산출 불가 → Agent/Phase-2 확장. 비활성(적재 대기): 조직/캠페인/후원사업/사유별 분해(ORG_SK·FK=0), 신규기존 분해(NEF=0), 미납중단(UNPAID_STOP=0).';


/* =====================================================================================
   3. SV_SERVICE (회원 Agent) — base FSE(일×회원×서비스×캠페인)
      활성: 발송수 총량·고유회원수 · 서비스구분(A3 SERVICE_SK)·발송상태
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_SERVICE_EVENT
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송')
      COMMENT = '서비스 발송 팩트(38.47M). ⚠(DATE_SK,MEMBER_DK,SERVICE_SK) 실측 비유일(distinct 36,651,766) → PK 미선언(기저 FACT·집계 무해, 2026-07-22).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK 99.97% 커버). 미매칭=Unknown(SK=0).',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰.'
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
  COMMENT = 'Phase-1 서비스 발송 SV(base FSE). 활성: 발송수·고유 발송회원수, 서비스구분/발송상태/발송일별. 시간=전체가능. 비활성(적재 대기): 수신/성공/실패/오픈(SUCCESS/FAIL/OPEN=0), 서신/선물금/증액 참여·+5일 코호트(D5_*=0, 신31~53), 캠페인별(CAMPAIGN_SK=0).';


/* =====================================================================================
   4. SV_EVENT_PARTICIPATION (회원 Agent) — base FEP(일×회원×행사)
      활성: 참여자수·참여건수·고유 참여회원수 · 행사명/종류/구분(EVENT_SK 76.8%)
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
  TABLES (
    fep AS GN_DW.GOLD.FACT_EVENT_PARTICIPATION
      WITH SYNONYMS ('행사 참여', '이벤트 참여')
      COMMENT = '행사 참여 팩트(1.13M). ⚠(DATE_SK,MEMBER_DK,EVENT_SK) 실측 비유일(distinct 843,414) → PK 미선언(기저 FACT·집계 무해, 2026-07-22).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '참여일')
      COMMENT = '일 차원.',
    event AS GN_DW.GOLD.DIM_EVENT
      PRIMARY KEY (EVENT_SK)
      WITH SYNONYMS ('행사', '이벤트')
      COMMENT = '행사 차원. EVENT_SK 고아 23%(이슈 E) → Unknown(SK=0) 라우팅, 행사명별 집계는 부분.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰.'
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
  COMMENT = 'Phase-1 행사 참여 SV(base FEP). 활성: 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분·참여일별. 행사 미매칭 23%(EVENT_SK=0 Unknown 라우팅) → 행사명별 집계는 부분, 확정치로 단정 금지. 비활성(적재 대기): 모집/총원(TOTAL/RECRUIT_CNT=0), 캠페인/후원사업별(FK=0).';


/* =====================================================================================
   5. SV_BUDGET (overall Agent) — base FBD(월×조직×세세목)
      활성: 편성예산(월)·집행예산(ERP)·집행율 · 세세목명/예산구분
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 팩트(grain=월×세세목, 24.5K · 실측 유일 → PK). 편성/집행.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원.'
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
  COMMENT = 'Phase-1 예산 SV(base FBD). 활성: 편성예산(월)·집행예산(ERP)·집행율, 세세목/예산구분/월별. 비활성(적재 대기): 연 편성예산(PLAN_BUDGET_YEAR=0), 집행추정/모금성비용/광고비(=0), 조직/캠페인별(ORG/CAMPAIGN_SK=0), 개발단가·ROI(신9~11, O3·E-6 대기).';


/* =====================================================================================
   6. GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
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

-- (7-4) 확인: SHOW SEMANTIC VIEWS
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
=====================================================================================
*/
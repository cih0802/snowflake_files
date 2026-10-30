-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_MEMBER_SPONSOR_BIZ
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
-- Run order  : 운영계 #27 · 기존 환경 갱신 #31
-- Depends on : GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN, GN_DW.GOLD.DIM_SPONSORSHIP, GN_DW.GOLD.DIM_CAMPAIGN, GN_DW.GOLD.FACT_SPONSORSHIP_MONTHLY, GN_DW.GOLD.DIM_ORG_SUCCESSION
-- Issue      : DEC-63, O237-C, DEC-56
-- =============================================================================
-- ============================================================================
-- 05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql — Semantic View DDL 정본: SV_MEMBER_SPONSOR_BIZ
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · WARN: SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
--   · 2026-10-21 DEC-63 = 현재 부서 귀속 축(org_succ = GOLD.DIM_ORG_SUCCESSION) · 지표 STOP_REGISTRATIONS ·
--       규칙 (5) · VQR 1 추가 — 기존 환경 배포순서 = 37_DEPLOY_ORG_SUCCESSION.sql(WARN: dbt build 다음에 실행)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
  TABLES (
    fmsb AS GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
      WITH SYNONYMS ('회원 후원약정', '캠페인별 활동회원', '후원사업별 활동회원')
      COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업 차원')
      COMMENT = '후원사업 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인 차원')
      COMMENT = '캠페인 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.',
    --  [2026-10-16 O237-C] 공#79 후원사업별 미납율 — 월 × 후원사업 팩트(FMM 스파인 · 월 합 = FMM 합)
    fsm AS GN_DW.GOLD.FACT_SPONSORSHIP_MONTHLY
      PRIMARY KEY (BASE_MONTH_KEY, SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업별 월 지표', '후원사업 월 팩트')
      COMMENT = '후원사업별 월 지표(활동(건)·납입회비·미납회비) 팩트. [Grain: 기준연월 × 후원사업]. 전 후원사업 합 = FACT_MEMBER_MONTHLY 같은 월 합. [원천: CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · FACT_MEMBER_FEE → GOLD.FACT_SPONSORSHIP_MONTHLY].',
    --  [2026-10-21 DEC-63] 폐지·개편 실적부서 → 현재 활성 부서 귀속 차원(약정 실적부서 SPNSR_ACMSLT_DEPT_CD 로 조인)
    org_succ AS GN_DW.GOLD.DIM_ORG_SUCCESSION
      UNIQUE (OLD_DEPT_ID)
      WITH SYNONYMS ('부서 귀속', '현재 부서 귀속', '폐지부서 귀속')
      COMMENT = '폐지·개편 부서 현재 조직 귀속 차원. 원천 실적부서당 한 행(OLD_DEPT_ID 유일)이라 조인이 행수를 늘리지 않는다. 활성 부서는 자기 자신으로 귀속(SELF). [원천: SILVER.CRM_ORG · GOLD.DIM_ORG · seed ORG_SUCCESSION_MANUAL → GOLD.DIM_ORG_SUCCESSION].'
  )
  RELATIONSHIPS (
    fmsb_to_sponsorship AS fmsb (SPONSORSHIP_SK) REFERENCES sponsorship,
    fmsb_to_campaign    AS fmsb (CAMPAIGN_SK)    REFERENCES campaign,
    fsm_to_sponsorship  AS fsm (SPONSORSHIP_SK)  REFERENCES sponsorship,
    fmsb_to_org_succ    AS fmsb (SPNSR_ACMSLT_DEPT_CD) REFERENCES org_succ (OLD_DEPT_ID)
  )
  DIMENSIONS (
    fmsb.MEMBER_DK        AS fmsb.MEMBER_DK    WITH SYNONYMS ('회원번호', '공110') COMMENT = '회원 (불변키)',
    fmsb.SPNSR_BSNS_NO    AS fmsb.SPNSR_BSNS_NO WITH SYNONYMS ('후원사업번호', '약정번호') COMMENT = '회원별 후원약정 일련번호. 🔴단독 유일키 아니다 — 공동후원 쌍(부부 등)이 2개 회원에 공유되는 사례가 실재한다. 분류축이 아니다(분류는 SPONSORSHIP 축)',
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '사업', '공123') COMMENT = '후원사업명(마스터). 미매핑 없음(전건 매칭 실측 확인)',
    sponsorship.SPONSORSHIP_DIV AS sponsorship.SPONSORSHIP_DIV_NAME WITH SYNONYMS ('정기일시구분') COMMENT = '정기후원/일시후원 구분(CM035). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''정기후원''·''일시후원''.',
    sponsorship.SPONSORSHIP_ABBR_CATEGORY AS sponsorship.SPONSORSHIP_GROUP_NAME WITH SYNONYMS ('후원사업 약칭', '후원사업 카테고리', '공124') COMMENT = '후원사업 약칭 그룹(CM003). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결연''·''국내''·''기타''·''북한''·''해외''·''해외구호''.',
    sponsorship.DNTN_TY_CD AS sponsorship.DNTN_TY_CD WITH SYNONYMS ('기부유형코드') COMMENT = '후원사업 기부유형 코드 raw(코드군 미확정 ⇒ 의미 추정 금지 · O262-B). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''1''·''3''',
    campaign.CAMPAIGN     AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명') COMMENT = '대표캠페인명. 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규사건이 있으면 그 신규사건 ②없으면 최초사건(동률 0 확인). 사건 자체가 없는 약정은 "(미매핑)"(0). ⚠️단일 회원-grain 캠페인 분해(FACT_MEMBER_MONTHLY 기준)와는 다른 축이다 — 이 SV 는 약정grain 이라 값이 다르게 나올 수 있다',
    fmsb.ACQ_CMPGN_CTGR_NM AS fmsb.ACQ_CMPGN_CTGR_NM WITH SYNONYMS ('캠페인 카테고리', '주요캠페인') COMMENT = '대표캠페인 카테고리 라벨(MM294). 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체)',
    fmsb.IS_MULTI_CAMPAIGN AS fmsb.IS_MULTI_CAMPAIGN WITH SYNONYMS ('다중캠페인 여부') COMMENT = '참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 캠페인이 2개 이상이었는지. 대표캠페인 채택 규칙과는 별개. 🟢실측상 극소수이며 최대 2개다9 참조)',
    fmsb.START_MONTH_KEY  AS fmsb.START_MONTH_KEY WITH SYNONYMS ('활동개시월') COMMENT = '활동 개시 월키 YYYYMM. 특정월 as-of 활동 판정 시 이 축과 DSCNTC_MONTH_KEY 를 함께 WHERE 절로 비교한다(AI_SQL_GENERATION 참조)',
    fmsb.DSCNTC_MONTH_KEY AS fmsb.DSCNTC_MONTH_KEY WITH SYNONYMS ('중단월') COMMENT = '중단 월키 YYYYMM. 🔴NULL=미중단(현재까지 활동)이며 결측이 아니다',
    campaign.CAMPAIGN_MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 마케팅채널') COMMENT = '캠페인 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 근거 = 문서20 N-29 머리 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    fmsb.SPNSR_JOIN_PATH_NM AS fmsb.SPNSR_JOIN_PATH_NM WITH SYNONYMS ('후원 가입경로', '가입경로') COMMENT = '후원(약정) 단위 가입경로(MM014 · REG·홈페이지·모바일웹·모바일앱·외주콜센터·CRM). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''CRM''·''REG''·''모바일앱''·''모바일웹''·''외주콜센터''·''홈페이지''',
    sponsorship.SPONSORSHIP_GROUP4_NAME AS sponsorship.SPONSORSHIP_GROUP4_NAME WITH SYNONYMS ('후원사업 4그룹', '후원사업그룹') COMMENT = '후원사업 4그룹(국내/결연/해외프로젝트/기타 · CM003 라벨 접기 · 규칙 밖 라벨은 NULL). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결연''·''국내''·''기타''·''해외프로젝트''',
    --  [2026-10-16 O237-C] 후원사업 월 팩트 기준연월
    fsm.BASE_MONTH_KEY AS fsm.BASE_MONTH_KEY WITH SYNONYMS ('기준연월', '조회연월') COMMENT = '후원사업별 월 지표의 기준연월 YYYYMM(정수). 🔴 후원사업별 미납율은 기준연월 하나를 고정해 조회한다(여러 달이면 연월별로 나눈다).',
    fsm.BASE_YEAR AS fsm.BASE_YEAR WITH SYNONYMS ('기준연도') COMMENT = '기준연도 YYYY.',
    --  [2026-10-21 DEC-63] 현재 조직 기준 부서 축(원천 실적부서값은 바꾸지 않는다 · DEC-56)
    org_succ.CUR_DEPARTMENT AS COALESCE(org_succ.CUR_DEPARTMENT, '(미매핑 폐지부서)')
      WITH SYNONYMS ('현재 부서', '현재 부서-팀', '귀속 부서', '현재 조직 기준 부서')
      COMMENT = '약정 실적부서를 **현재 활성 부서-팀**으로 귀속한 부서명. 활성 부서는 자기 자신 · 폐지·개편 부서는 현업 확정(MANUAL) 또는 자동 추정 규칙으로 귀속한다. ''(미매핑 폐지부서)'' = 귀속 대상 없음(합계 보존용 묶음 · 결측 아님). 🔴 「부서별 중단」·「현재 부서 기준」 드릴다운의 기본 축이다.',
    org_succ.CUR_DEPT_ID AS org_succ.CUR_DEPT_ID
      WITH SYNONYMS ('현재 부서코드', '귀속 부서코드')
      COMMENT = '귀속 현재 부서코드. NULL = 귀속 대상 없음(CUR_DEPARTMENT 가 ''(미매핑 폐지부서)'' 인 행).',
    org_succ.CUR_ORG_PATH AS COALESCE(org_succ.CUR_ORG_PATH, '(미매핑 폐지부서)')
      WITH SYNONYMS ('현재 부서-팀 경로', '현재 조직 경로', '본부 실 팀')
      COMMENT = '귀속 현재 부서의 조직 경로(예: 본부 > 회원실 > 회원서비스기획팀 · 루트 제외). 대시보드 부서-팀 드릴다운과 같은 축이다(현업 안내서 §6). 부서장이 본부·실 단위로 자기 부서를 찾을 때 쓴다. ''(미매핑 폐지부서)'' = 귀속 대상 없음.',
    org_succ.OLD_DEPARTMENT AS org_succ.OLD_DEPARTMENT
      WITH SYNONYMS ('원천 실적부서', '당시 부서', '실적부서')
      COMMENT = '약정 당시 원천 실적부서명(폐지 부서는 옛 이름 그대로). 「당시 부서 기준」을 명시할 때만 쓴다.',
    org_succ.MAP_METHOD AS org_succ.MAP_METHOD
      WITH SYNONYMS ('귀속 근거', '귀속 방법')
      COMMENT = '귀속 근거. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''SELF''(활성 부서)·''AUTO_NAME''·''AUTO_MEMBER_FLOW''·''AUTO_ACMSLT_PARENT''·''AUTO_ORG_PARENT''(자동 추정)·''UNMAPPED''. 현업 확정 seed(GOLD.ORG_SUCCESSION_MANUAL)가 적재되면 ''MANUAL''(현업 확정)·''MANUAL_UNMAPPED''(현업 확정 미귀속)도 생긴다 — seed 가 비어 있으면 0행이므로 이 두 값으로 거르기 전에 조회로 있는지 확인한다.',
    org_succ.IS_CONFIRMED AS org_succ.IS_CONFIRMED
      WITH SYNONYMS ('귀속 확정 여부')
      COMMENT = 'TRUE = 활성 부서 또는 현업 확정 귀속 · FALSE = 자동 추정 귀속(현업 검토 전). 자동 추정이 섞인 결과는 답변에서 밝힌다.'
  )
  METRICS (
    --  [2026-10-16 O237-C] 공#79 후원사업별 미납율 = 미납(건) ÷ 활동(건) × 100 · 미납(건) = 미납회비 ÷ 10,000
    fsm.SPONSORSHIP_UNPAID_RATE AS SUM(fsm.UNPAID_BILLED_AMT) / 10000 / NULLIF(SUM(fsm.ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('후원사업별 미납율', '후원사업별 미납률', '사업별 미납율')
      COMMENT = '공#79 후원사업별 미납율(%) = 후원사업 미납(건) ÷ 후원사업 활동(건) × 100. 미납(건) = 미납회비(원) ÷ 10,000 · 활동(건) = 월말 활동 약정금액 ÷ 10,000. 🔴 기준연월(BASE_MONTH_KEY) 하나를 고정한다 · 분자·분모를 함께 보이고 전체 합 행은 붙이지 않는다(필요하면 전체 합 열 · 표 밖 본문 1줄)(전체 = SV_CAMPAIGN_MONTHLY 전체 미납율과 같다).',
    fsm.SPONSORSHIP_UNPAID_CNT AS SUM(fsm.UNPAID_BILLED_AMT) / 10000
      WITH SYNONYMS ('후원사업 미납(건)', '후원사업별 미납건') COMMENT = '후원사업 미납(건) = 미납회비 ÷ 10,000. F(가산 · 같은 기준월 안에서).',
    fsm.SPONSORSHIP_ACTIVE_CNT AS SUM(fsm.ACTIVE_CNT)
      WITH SYNONYMS ('후원사업 활동(건)', '후원사업별 활동건') COMMENT = '후원사업 월말 활동(건) = 활동 약정금액 ÷ 10,000. F(가산 · 같은 기준월 안에서 · 여러 달 합산 금지).',
    fsm.SPONSORSHIP_UNPAID_FEE AS SUM(fsm.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('후원사업별 미납회비') COMMENT = '후원사업별 미납회비(원). F(가산).',
    fmsb.CURRENTLY_ACTIVE_MEMBERS AS COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL))
      WITH SYNONYMS ('지금 활동회원수', '현재 활동회원')
      COMMENT = '**지금 시점** 활동회원수(명) = 미중단 약정을 보유한 고유회원. N(비가산). 🔴전체 활동회원수 정본은 SV_MEMBER_MONTHLY.ACTIVE_MEMBERS 다 — 이 metric 을 캠페인·후원사업으로 GROUP BY 하면 한 회원이 여러 축에 중복 집계될 수 있어 **합계가 전체보다 클 수 있다**(다중 후원 정상 현상). 특정 과거월 as-of 는 이 metric 이 아니라 START_MONTH_KEY·DSCNTC_MONTH_KEY 원시축으로 직접 WHERE 를 구성한다.',
    fmsb.TOTAL_REGISTRATIONS AS COUNT(*)
      WITH SYNONYMS ('약정건수', '등록건수')
      COMMENT = '약정(SPNSR_BSNS_NO) 행수. F(가산). 🔴"명"이 아니다 — 회원당 여러 약정을 가질 수 있다',
    fmsb.DISTINCT_MEMBERS AS COUNT(DISTINCT fmsb.MEMBER_DK)
      WITH SYNONYMS ('고유회원수', '약정보유회원수')
      COMMENT = '활동여부 무관, 이 팩트에 약정이 하나라도 있는 고유 회원수(명). N(비가산)',
    fmsb.CURRENTLY_ACTIVE_SPNSR_AMT AS SUM(IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.SPNSR_AMT, 0))
      WITH SYNONYMS ('지금 활동 약정금액', '현재 활동 후원금액')
      COMMENT = '**지금 시점** 미중단 약정의 SPNSR_AMT 합(원). F(가산). 🔴정본 (건) 표기로 바꾸려면 이 값을 만원 단위로 환산한다(규약) — 이 SV 는 원단위로 노출하고 환산은 소비 시 명시한다.',
    fmsb.TOTAL_SPNSR_AMT AS SUM(fmsb.SPNSR_AMT)
      WITH SYNONYMS ('약정금액 총계')
      COMMENT = '활동여부 무관 SPNSR_AMT 합(원). F(가산)',
    --  [2026-10-21 DEC-63] 중단 약정건수(중단월 기준 · 현재 부서 드릴다운용)
    fmsb.STOP_REGISTRATIONS AS COUNT_IF(fmsb.DSCNTC_MONTH_KEY IS NOT NULL)
      WITH SYNONYMS ('중단 약정건수', '중단건', '부서별 중단건')
      COMMENT = '중단된 약정(SPNSR_BSNS_NO) 개수(행 수) — 정본 중단(건)(금액 ÷ 10,000)이 아니다. F(가산). 기간은 DSCNTC_MONTH_KEY(중단월)로 건다. 🔴 「명」이 아니다 · SV_MEMBER_EVENT 의 TOTAL_STOP_CNT(사건 grain)와 같은 표에서 합산하지 않는다.'
  )
  COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 활동회원 총계 vs 분해: 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 로 라우팅. 캠페인별/후원사업별 분해 시에만 본 뷰의 CURRENTLY_ACTIVE_MEMBERS 사용. (2) 다중후원 안내: 캠페인/후원사업별 합계 > 전체 활동회원수(다중 후원 정상 현상)임을 명시. (3) 특정 과거월 as-of: 과거 특정월 활동 판정은 START_MONTH_KEY <= 월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 월) 조건으로 직접 구성. (4) 회원 식별: 회원 식별은 항상 MEMBER_DK 기준. (5) 🆕 [DEC-63] 부서별 중단·활동 드릴다운: 기본은 현재 조직 기준 CUR_DEPARTMENT(폐지·개편 부서를 현재 부서-팀에 합산) 이고 「당시 부서」를 명시할 때만 OLD_DEPARTMENT 를 쓴다. 결과에 ''(미매핑 폐지부서)'' 행을 빼지 않고 함께 보인다(합계 보존). IS_CONFIRMED = FALSE(자동 추정) 행이 포함되면 「일부 폐지 부서는 자동 추정 귀속」이라고 밝힌다. (6) 🆕 [DEC-63-D] 부서별 중단률: 분자(그 달 중단 약정)와 분모(전월말 활동 약정 = START_MONTH_KEY <= 전월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 전월))를 **같은 CUR_ORG_PATH(또는 CUR_DEPARTMENT) 축**으로 묶는다 — 분자만 현재 부서로 옮기고 분모를 당시 부서로 두면 흡수 부서의 중단률이 실제보다 크게 부풀려진다. 분자·분모·비율을 함께 보이고 전체 합 행은 붙이지 않는다(필요하면 전체 합 열 · 표 밖 본문 1줄). 🔴 이 비율은 **약정 개수 기준(행 수)**이다 — 정본 (건) = 약정금액 ÷ 10,000 이 아니다. 공식 중단율(SV_CAMPAIGN_MONTHLY · 금액 ÷ 10,000 · 분모 = 개발 + 전월말 활동)은 부서 축이 없고 이 팩트에는 증액 개발분이 없어 같은 산식으로 맞출 수 없다 — 답변에서 「약정 개수 기준(행 수) · 공식 중단율과 산식 다름」이라고 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_active_by_sponsorship AS (
      QUESTION '후원사업별 지금 활동회원 수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT SPONSORSHIP AS "후원사업", CURRENTLY_ACTIVE_MEMBERS AS "현재 활동회원수(명)" FROM (SELECT sponsorship.SPONSORSHIP, COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL)) AS CURRENTLY_ACTIVE_MEMBERS FROM fmsb LEFT JOIN sponsorship ON fmsb.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK GROUP BY sponsorship.SPONSORSHIP ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST) ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST'
    ),
    vqr_stop_by_current_dept AS (
      QUESTION '2026년 현재 부서별 중단 약정건수'
      VERIFIED_BY '(DW = DEC-63)'
      SQL 'SELECT COALESCE(CUR_DEPARTMENT, ''(미매핑)'') AS "현재 부서", STOP_REGISTRATIONS AS "중단 약정건수" FROM (SELECT org_succ.CUR_DEPARTMENT, COUNT_IF(fmsb.DSCNTC_MONTH_KEY IS NOT NULL) AS STOP_REGISTRATIONS FROM fmsb LEFT JOIN org_succ ON fmsb.SPNSR_ACMSLT_DEPT_CD = org_succ.OLD_DEPT_ID WHERE fmsb.DSCNTC_MONTH_KEY BETWEEN 202601 AND 202612 GROUP BY org_succ.CUR_DEPARTMENT) ORDER BY STOP_REGISTRATIONS DESC'
    ),
    vqr_stop_rate_by_current_dept AS (
      QUESTION '2026년 9월 현재 부서-팀별 중단률'
      VERIFIED_BY '(DW = DEC-63-D)'
      SQL 'SELECT COALESCE(CUR_ORG_PATH, ''(미매핑)'') AS "현재 부서-팀 경로", STOP_CNT AS "중단 약정 개수(행 수)", PREV_ACTIVE AS "전월말 활동 약정 개수(행 수)", ROUND(STOP_CNT * 100 / NULLIF(PREV_ACTIVE, 0), 2)::NUMBER(38,2) AS "중단률(%, 약정 개수 기준)" FROM (SELECT org_succ.CUR_ORG_PATH, COUNT_IF(fmsb.DSCNTC_MONTH_KEY = 202609) AS STOP_CNT, COUNT_IF(fmsb.START_MONTH_KEY <= 202608 AND (fmsb.DSCNTC_MONTH_KEY IS NULL OR fmsb.DSCNTC_MONTH_KEY > 202608)) AS PREV_ACTIVE FROM fmsb LEFT JOIN org_succ ON fmsb.SPNSR_ACMSLT_DEPT_CD = org_succ.OLD_DEPT_ID GROUP BY org_succ.CUR_ORG_PATH) ORDER BY STOP_CNT DESC'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_AR_SRC_COMMON;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_SERVICE;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS sv_val,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN)                                                   AS fact_val;

SELECT (SELECT DISTINCT_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS DISTINCT_MEMBERS)) AS distinct_members,
       (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS total_regs;

SELECT SPONSORSHIP, CAMPAIGN, CURRENTLY_ACTIVE_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS SPONSORSHIP, CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS)
ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST
LIMIT 20;

SELECT SUM(CURRENTLY_ACTIVE_MEMBERS) AS sum_by_campaign
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS);
SELECT CURRENTLY_ACTIVE_MEMBERS AS total_no_axis
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS CURRENTLY_ACTIVE_MEMBERS);

--  [DEC-63] 현재 부서 축 합계 보존 — 두 값이 같아야 한다(조인이 행을 늘리거나 잃지 않는다)
SELECT (SELECT SUM(STOP_REGISTRATIONS)
          FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
                 DIMENSIONS CUR_DEPARTMENT METRICS STOP_REGISTRATIONS)) AS sv_by_dept,
       (SELECT COUNT_IF(DSCNTC_MONTH_KEY IS NOT NULL)
          FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN)                  AS fact_val;

SHOW SEMANTIC VIEWS LIKE 'SV_MEMBER_SPONSOR_BIZ' IN SCHEMA GN_DW.SERVING;

-- ============================================================================
-- 23_MSTR_SV_DDL.sql — MSTR 서빙뷰 + Semantic View DDL 정본: MSTR_SPNSR_DVLP_V · SV_MSTR_SPNSR_DVLP
--   · 구성 = USE → CREATE OR REPLACE VIEW → CREATE OR ALTER SEMANTIC VIEW → GRANT. 파일 단독 실행 가능.
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 🆕 2026-10-02 O200-B 신설. 선행 = GN_DW.MSTR 배포·적재(15_MSTR 이관 PoC/tools · mstr_pipeline.py).
--   · 서빙뷰를 GN_DW.MSTR 가 아니라 SERVING 에 두는 이유 = MSTR 매니페스트(1차.json) 대상이 아니다
--       ⇒ `mstr_deploy.py --check` 에 잉여 객체로 잡히지 않게 한다(ML 서빙뷰 21번과 같은 관례).
--   · 서빙뷰 SELECT·JOIN 은 05_mstr_1차_이관_대상_쿼리.sql [1] 과 동일(집계만 제거 · 회원번호 보존).
--   · Agent = AGENT_MSTR(4번째 · cortex_project/agents/AGENT_MSTR/) · 현업 승인 후 기존 Agent 에 같은 SV 를 도구로 추가.
-- ============================================================================
-- 🔴 [2026-10-03 O200-C] 이 파일은 O200-B 에서 ACCOUNTADMIN 세션으로 실행돼 서빙뷰·SV owner 가 ACCOUNTADMIN 이 됐다
--    (아래 `USE ROLE` 미실행 · `10_진단_원인분석-015.md:57` 과 같은 사고) ⇒ `24_MSTR_AGENT_배포.sql` [0] 으로 교정했다.
--    🔴 `CREATE OR REPLACE VIEW` 는 재실행 시 owner = 실행 역할이 된다 ⇒ 반드시 아래 USE ROLE 부터 실행한다.
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR REPLACE VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V (
  STRD_MT COMMENT '기준년월(YYYYMM 문자열)',
  STRD_DE COMMENT '발생일자(YYYYMMDD 문자열)',
  DVLP_DIV_CD COMMENT '개발구분코드(MSTR)',
  DVLP_DIV_NM COMMENT '개발구분명(MSTR D_DVLP_DIV_CD)',
  CPR_DIV_CD COMMENT '법인구분코드',
  CPR_DIV_NM COMMENT '법인구분명',
  DEPT4_ID COMMENT '실적부서4(구분_팀) ID',
  DEPT4_NM COMMENT '실적부서4(구분_팀) 명',
  DEPT3_ID COMMENT '실적부서3(본부/지부) ID',
  DEPT3_NM COMMENT '실적부서3(본부/지부) 명',
  DEPT2_ID COMMENT '실적부서2(팀/지부) ID',
  DEPT2_NM COMMENT '실적부서2(팀/지부) 명',
  DEPT_ID COMMENT '실적부서 ID',
  DEPT_NM COMMENT '실적부서명',
  BRND_ID COMMENT '브랜드 ID',
  BRND_NM COMMENT '브랜드명',
  UPPER_CMPGN_CD COMMENT '상위캠페인코드',
  UPPER_CMPGN_NM COMMENT '상위캠페인명',
  CMPGN_CD COMMENT '캠페인코드',
  CMPGN_NM COMMENT '캠페인명',
  PR_MTH_CD COMMENT '홍보방법코드',
  PR_MTH_NM COMMENT '홍보방법명',
  SPNSR_BSNS_ID COMMENT '후원사업 ID',
  SPNSR_BSNS_NM COMMENT '후원사업명',
  SPNSR_BSNS2_ID COMMENT '후원사업2 ID(MSTR 재분류)',
  SPNSR_BSNS2_NM COMMENT '후원사업2 명(MSTR 재분류)',
  SEX_CD COMMENT '성별코드',
  SEX_NM COMMENT '성별명(MSTR 표기)',
  AGE_TERM_CD COMMENT '연령대코드',
  AGE_TERM_NM COMMENT '연령대명',
  MBER_NO COMMENT '회원번호(개발 명 = 중복제거 전용)',
  SPNSR_AMT_CNT COMMENT 'MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름)',
  SPNSR_AMT COMMENT '후원금액(원)',
  DVLP_CNT COMMENT '개발구분건수(원천 행 단위 건수)'
)
COMMENT = 'MSTR 정기회원 후원개발 리포트 서빙뷰(O200-B). 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM + MSTR 차원(D_*) — MSTR(구 SQL Server mart) 로직을 Snowflake 로 이관한 결과다(원천 BRONZE_CRM). grain = 팩트 1행. 🔴 MSTR 기준 정의이며 GN_DW GOLD 정의와 다를 수 있다.'
AS
SELECT
  a11.STRD_MT, a11.OCCRRNC_DE,
  a11.DVLP_DIV_CD, a12.DVLP_DIV_NM,
  a11.CPR_DIV_CD, a14.CPR_DIV_NM,
  a11.ACMSLT_DEPT4_CD, a15.DEPT4_NM,
  a11.ACMSLT_DEPT3_CD, a18.DEPT3_NM,
  a11.ACMSLT_DEPT2_CD, a113.DEPT2_NM,
  a11.ACMSLT_DEPT_CD, a16.DEPT_NM,
  a11.BRND_ID, a17.BRND_NM,
  a11.UPPER_CMPGN_CD, a19.UPPER_CMPGN_NM,
  a11.CMPGN_CD, a112.CMPGN_NM,
  a11.PR_MTH_CD, a114.PR_MTH_NM,
  a11.SPNSR_BSNS_ID, a115.SPNSR_BSNS_NM,
  a11.SPNSR_BSNS2_ID, a116.SPNSR_BSNS_NM,
  a11.SEX, a110.SEX_NM,
  a11.AGE_TERM_CD, a111.AGE_TERM_NM,
  a11.MBER_NO, a11.SPNSR_AMT_CNT, a11.SPNSR_AMT, a11.DVLP_CNT
FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM a11
LEFT JOIN GN_DW.MSTR.D_DVLP_DIV_CD     a12  ON a11.DVLP_DIV_CD     = a12.DVLP_DIV_CD
LEFT JOIN GN_DW.MSTR.D_CPR_DIV_CD      a14  ON a11.CPR_DIV_CD      = a14.CPR_DIV_CD
LEFT JOIN GN_DW.MSTR.D_DEPT4_CD        a15  ON a11.ACMSLT_DEPT4_CD = a15.DEPT4_ID
LEFT JOIN GN_DW.MSTR.D_DEPT_CD         a16  ON a11.ACMSLT_DEPT_CD  = a16.DEPT_ID
LEFT JOIN GN_DW.MSTR.D_BRND_CD         a17  ON a11.BRND_ID         = a17.BRND_ID
LEFT JOIN GN_DW.MSTR.D_DEPT3_CD        a18  ON a11.ACMSLT_DEPT3_CD = a18.DEPT3_ID
LEFT JOIN GN_DW.MSTR.D_UP_CMPGN_CD     a19  ON a11.UPPER_CMPGN_CD  = a19.UPPER_CMPGN_CD
LEFT JOIN GN_DW.MSTR.D_SEX_CD          a110 ON a11.SEX             = a110.SEX_CD
LEFT JOIN GN_DW.MSTR.D_AGE_TERM_CD     a111 ON a11.AGE_TERM_CD     = a111.AGE_TERM_CD
LEFT JOIN GN_DW.MSTR.D_CMPGN_CD        a112 ON a11.CMPGN_CD        = a112.CMPGN_CD
LEFT JOIN GN_DW.MSTR.D_DEPT2_CD        a113 ON a11.ACMSLT_DEPT2_CD = a113.DEPT2_ID
LEFT JOIN GN_DW.MSTR.D_PR_MTH_CD       a114 ON a11.PR_MTH_CD       = a114.PR_MTH_CD
LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO a115 ON a11.SPNSR_BSNS_ID   = a115.SPNSR_BSNS_ID
LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO a116 ON a11.SPNSR_BSNS2_ID  = a116.SPNSR_BSNS_ID;

GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP
  TABLES (
    md AS GN_DW.SERVING.MSTR_SPNSR_DVLP_V
      WITH SYNONYMS ('MSTR 개발', 'MSTR 후원개발', 'MSTR 리포트', '정기회원 후원개발')
      COMMENT = 'MSTR 정기회원 후원개발 리포트 (base: SERVING.MSTR_SPNSR_DVLP_V). [Grain: 개발 팩트 1행]. [활성 지표: MSTR 개발(건)·개발(명)·후원금액]. [주의: MSTR 기준 정의, GN_DW 지표와 합산 금지, 개발(명) 비가산]. [원천: BRONZE_CRM → GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM(MSTR 이관 로직) → SERVING.MSTR_SPNSR_DVLP_V].'
  )
  DIMENSIONS (
    md.STRD_MT AS md.STRD_MT
      WITH SYNONYMS ('기준년월', '기준월')
      COMMENT = '기준년월(YYYYMM 문자열). 🔴 적재 범위는 조회해서 확인한다(열거하지 않는다).',
    md.STRD_DE AS md.STRD_DE
      WITH SYNONYMS ('기준일자', '발생일자')
      COMMENT = '발생일자(YYYYMMDD 문자열).',
    md.DVLP_DIV_CD AS md.DVLP_DIV_CD
      WITH SYNONYMS ('개발구분코드')
      COMMENT = 'MSTR 개발구분코드. 라벨은 DVLP_DIV_NM.',
    md.DVLP_DIV_NM AS md.DVLP_DIV_NM
      WITH SYNONYMS ('개발구분')
      COMMENT = 'MSTR 개발구분명(신규/증액/감액/재후원/후원중단). 🔴 MSTR 「개발」 리포트 기본 범위는 신규·증액·재후원이다.',
    md.CPR_DIV_NM AS md.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분')
      COMMENT = '법인구분명(MSTR 표기).',
    md.DEPT4_NM AS md.DEPT4_NM
      WITH SYNONYMS ('구분_팀', '부서4')
      COMMENT = 'MSTR 실적부서4(리포트 「구분_팀」).',
    md.DEPT3_NM AS md.DEPT3_NM
      WITH SYNONYMS ('본부/지부', '부서3')
      COMMENT = 'MSTR 실적부서3(리포트 「본부/지부」).',
    md.DEPT2_NM AS md.DEPT2_NM
      WITH SYNONYMS ('팀/지부', '부서2')
      COMMENT = 'MSTR 실적부서2(리포트 「팀/지부」).',
    md.DEPT_NM AS md.DEPT_NM
      WITH SYNONYMS ('부서', '실적부서')
      COMMENT = 'MSTR 실적부서명(리포트 「부서」). 🔴 GN_DW 부서 차원과 같은 조직이라 단정하지 않는다.',
    md.BRND_NM AS md.BRND_NM
      WITH SYNONYMS ('브랜드')
      COMMENT = '브랜드명.',
    md.UPPER_CMPGN_NM AS md.UPPER_CMPGN_NM
      WITH SYNONYMS ('상위캠페인')
      COMMENT = '상위캠페인명.',
    md.CMPGN_CD AS md.CMPGN_CD
      WITH SYNONYMS ('캠페인코드', 'CP')
      COMMENT = '캠페인코드(리포트 「CP」).',
    md.CMPGN_NM AS md.CMPGN_NM
      WITH SYNONYMS ('캠페인')
      COMMENT = '캠페인명.',
    md.PR_MTH_NM AS md.PR_MTH_NM
      WITH SYNONYMS ('홍보방법')
      COMMENT = '홍보방법명.',
    md.SPNSR_BSNS_NM AS md.SPNSR_BSNS_NM
      WITH SYNONYMS ('후원사업')
      COMMENT = '후원사업명.',
    md.SPNSR_BSNS2_NM AS md.SPNSR_BSNS2_NM
      WITH SYNONYMS ('후원사업2')
      COMMENT = 'MSTR 후원사업2(재분류 그룹 · 리포트 「후원사업2」).',
    md.SEX_NM AS md.SEX_NM
      WITH SYNONYMS ('성별')
      COMMENT = '성별명(MSTR 표기).',
    md.AGE_TERM_NM AS md.AGE_TERM_NM
      WITH SYNONYMS ('연령대')
      COMMENT = '연령대명(MSTR 구간).',
    md.MBER_NO AS md.MBER_NO
      WITH SYNONYMS ('회원번호')
      COMMENT = '회원번호. 개발(명) 중복제거 전용 — 회원 목록 질의에는 쓰지 않는다.'
  )
  METRICS (
    md.MSTR_DVLP_CNT AS SUM(md.SPNSR_AMT_CNT)
      WITH SYNONYMS ('개발(건)', 'MSTR 개발건', '개발 건수')
      COMMENT = 'MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 가능). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',
    md.MSTR_DVLP_MEMBERS AS COUNT(DISTINCT md.MBER_NO)
      WITH SYNONYMS ('개발(명)', 'MSTR 개발 회원수', '개발 명')
      COMMENT = 'MSTR 개발(명) = 회원번호 중복제거. 🔴 비가산 — 하위 그룹 값을 더해 상위 값을 만들지 않는다.',
    md.MSTR_SPNSR_AMT AS SUM(md.SPNSR_AMT)
      WITH SYNONYMS ('후원금액', '개발 금액')
      COMMENT = '후원금액 합계(원). 감액·후원중단 구분은 음수다.',
    md.MSTR_ROW_CNT AS SUM(md.DVLP_CNT)
      WITH SYNONYMS ('개발 행수', '원천 건수')
      COMMENT = '원천 개발구분건수 합계(행 단위). MSTR 리포트 「개발(건)」이 아니다.'
  )
  COMMENT = 'MSTR 정기회원 후원개발 SV(MSTR 1차 이관 · O197/O200-B). base=SERVING.MSTR_SPNSR_DVLP_V. 🔴🔴 **MSTR 기준 정의다** — GN_DW 회원 SV(SV_MEMBER_EVENT 등)의 개발건수·회원수와 정의가 달라 같은 표에 합산·차감하지 않는다. 🔴🔴 **MSTR 개발(건) = 후원금액 ÷ 10,000** 이다(사건 건수가 아니다). 🔴 개발(명)은 중복제거라 비가산이다. 🔴 MSTR 「개발」 리포트의 기본 범위는 개발구분 신규·증액·재후원이다 — 감액·후원중단을 섞지 않는다. 🔴 적재 기준월은 PoC 범위로 제한돼 있다 — 조회로 확인한다. 활성: 개발(건)·개발(명)·후원금액 · 기준년월/기준일자/개발구분/법인/부서4·3·2·부서/브랜드/상위캠페인/캠페인/홍보방법/후원사업/후원사업2/성별/연령대 축. 비활성: 목표·달성률(이 리포트 범위 밖).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **개발구분 미지정 시 MSTR 개발 리포트 범위인 신규·증액·재후원(DVLP_DIV_CD IN (''1'',''2'',''4''))으로 한정하고 그 사실을 밝힌다.** 감액·후원중단은 사용자가 명시할 때만 포함하며 개발과 합산하지 않는다. (2) 🔴🔴 **「개발(건)」은 MSTR_DVLP_CNT(후원금액÷10,000 합)다** — 행 수(COUNT)나 MSTR_ROW_CNT 로 바꾸지 않는다. 답변에 「MSTR 기준」임을 밝힌다. (3) 🔴 **개발(명)은 COUNT(DISTINCT md.MBER_NO)로 그 그룹에서 직접 센다** — 하위 그룹 합으로 만들지 않는다. (4) 🔴 **기준년월 미지정 시 데이터에 존재하는 최신 기준년월 하나로 한정하고 밝힌다.** (5) 🔴 **GN_DW 지표와 섞지 않는다.** (6) **금액은 원 단위다.** (7) 적용 조건(그룹 미지정 시): 최신 기준년월 + 신규·증액·재후원으로 한정해 개발구분별 개발(건)·개발(명)·후원금액을 반환한다. (8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(SUM(md.SPNSR_AMT_CNT) 등)으로 집계한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_SERVICE;

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
  NEW_OLD_DIV_CD COMMENT '신규기존구분코드(MSTR · DMMM07 1=신규 2=기존 99=없음)',
  NEW_OLD_DIV_NM COMMENT '신규기존구분명(MSTR 원천 판정값 · 가입일 계산이 아니다)',
  MBER_NO COMMENT '회원번호(개발 명 = 중복제거 전용)',
  SPNSR_AMT_CNT COMMENT 'MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름) · 🆕 [O206-D] 원천 FLOAT 를 NUMBER(18,4) 로 고정(부동소수 꼬리 제거 · 합계 불변)',
  SPNSR_AMT COMMENT '후원금액(원)',
  DVLP_CNT COMMENT '개발구분건수(원천 행 단위 건수)',
  -- 🆕 [O207 W2] 미노출 27컬럼 중 노출 판정 10축(판정표 = 12_agent개선과제/00_작업계획.md §10-5) · 목표 2컬럼은 별도 grain 뷰(아래)
  SPNSR_TERM_CD COMMENT '후원기간대코드(CM016 · 첫 후원일 → 발생일 연수)',
  SPNSR_TERM_NM COMMENT '후원기간대명(1년 미만 · 1년 이상~5년 미만 · 5년 이상~10년 미만 · 10년 이상)',
  SPNSR_TERM2_CD COMMENT '후원기간대2코드(DMMM08 · 1년 단위)',
  SPNSR_TERM2_NM COMMENT '후원기간대2명(1년미만 ~ 10년이상 · 1년 단위)',
  SPNSR_AMT_CD COMMENT '후원금액범위코드(CM012 · 원천 판정값 — 그 행 후원금액의 구간이 아니다)',
  SPNSR_AMT_NM COMMENT '후원금액범위명(CM012 · 원천 판정값)',
  SPNSR_AMT2_CD COMMENT '후원금액대2코드(DMMM09 · 후원사업별 최초 정상 개발건(신규·증액·재후원) 금액 구간 · 999 = 매칭 없음)',
  SPNSR_AMT2_NM COMMENT '후원금액대2명(1만원 단위 구간 · 최초 정상 개발금액 기준)',
  SETLE_CD COMMENT '결제수단코드(PM040)',
  SETLE_NM COMMENT '결제수단명(자동이체·신용카드·휴대폰·네이버페이 등)',
  MBER_DIV_CD COMMENT '회원구분코드(MM018)',
  MBER_DIV_NM COMMENT '회원구분명(개인·기업·단체)',
  AREA_CD COMMENT '시도코드(CM011 · 0·NULL = 라벨 없음)',
  AREA_NM COMMENT '시도명(CM011 · 기타 = 원천 「기타」 · 코드 0 은 라벨이 없어 NULL)',
  SPNSR_BSNS_ABRV_CD COMMENT '후원약칭코드(CM003)',
  SPNSR_BSNS_ABRV_NM COMMENT '후원약칭명(국내·결연·해외 등)',
  CANCL_RDCAMT_RSN_CD COMMENT '중단·감액 사유코드 — 개발구분 후원중단 = MM005 · 감액 = MM002 · 그 외 NULL',
  CANCL_RDCAMT_RSN_NM COMMENT '중단·감액 사유명 — 후원중단 = 후원중단사유(MM005) · 감액 = 후원사업취소사유(MM002) · 그 외 개발구분은 NULL(개념 없음)',
  PRE_CMPGN_CD COMMENT '직전캠페인코드 — 재후원·금액>0 에만 값 · 그 외 NULL',
  PRE_CMPGN_NM COMMENT '직전캠페인명(재후원 전 마지막 캠페인)',
  -- 🆕 [O212] 캠페인 분류 4축 — SILVER.CRM_CAMPAIGN(캠페인코드 1행) 조인 · 202608 매칭 25,337/25,337 · 캠페인 마스터 현재값(GN_DW FME 의 적재 시점 동결값과 다를 수 있다)
  CMMN_BRND_NM COMMENT '공통브랜드(MM297 · 대분류 16종) — 원천 브랜드(BRND_NM · 세부 60여 종)의 상위 묶음이나 엄격한 계층은 아니다',
  DVLP_INFLOW_PATH_NM COMMENT '개발인입경로(MM293 · 12종 · 캠페인 모집채널)',
  CMPGN_TYPE2_NM COMMENT '캠페인유형2(원천 COMMENT = 캠페인유형(사업/사례) · MM296 · 4종 = 사례·사업·굿즈·기타)',
  CMPGN_CTGR_NM COMMENT '캠페인카테고리(MM294 · 주요캠페인 · 세부 40여 종) — 캠페인유형2 와 교차 축(엄격한 하위 계층 아님)',
  CMPGN_TYPE1_NM COMMENT '🆕 [O212-B] 캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등)',
  -- 🆕 [O213 Y3-A] 캠페인 마스터 마케팅 3축 + 후원구분 — 같은 SILVER.CRM_CAMPAIGN 조인 · 키 중복 0 · 행 수 불변(821,991) · 캠페인 마스터 현재값
  MK_CMPGN_NM COMMENT '마케팅캠페인(원천 COMMENT = 마케팅 캠페인명 · TC_MKTNG_DTL_CD C001 라벨 · 나마본캠페인) · 캠페인 마스터 현재값',
  MKTG_UTM_NM COMMENT '마케팅 UTM(원천 COMMENT = 마케팅 UTM 라벨 · U001) · 🔴 원천에 값이 있는 캠페인에만 값이 있다(그 외 NULL)',
  MKTG_CHANNEL_NM COMMENT '마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) · 캠페인 마스터 현재값',
  SPNSR_DIV_NM COMMENT '후원구분(원천 COMMENT = 후원구분명 · CM035 · 정기후원/일시후원) · 캠페인 마스터 현재값'
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
  a11.NEW_OLD_DIV_CD, a117.DTL_CD_NM,
  a11.MBER_NO, ROUND(a11.SPNSR_AMT_CNT, 4)::NUMBER(18,4), a11.SPNSR_AMT, a11.DVLP_CNT,
  a11.SPNSR_TERM_CD, c_t1.DTL_CD_NM,
  a11.SPNSR_TERM2_CD, c_t2.DTL_CD_NM,
  a11.SPNSR_AMT_CD, c_m1.DTL_CD_NM,
  a11.SPNSR_AMT2_CD, c_m2.DTL_CD_NM,
  a11.SETLE_CD, c_st.DTL_CD_NM,
  a11.MBER_DIV_CD, c_md.DTL_CD_NM,
  a11.AREA_CD, c_ar.DTL_CD_NM,
  a11.SPNSR_BSNS_ABRV_CD, c_ab.DTL_CD_NM,
  a11.CANCL_RDCAMT_RSN_CD, COALESCE(c_r5.DTL_CD_NM, c_r3.DTL_CD_NM),
  NULLIF(a11.PRE_CMPGN_CD, '0'), c_pc.CMPGN_NM,
  cc.CMMN_BRND_NM, cc.MBER_INFLOW_PATH_NM, cc.CMPGN_TYPE2_NM, cc.CMPGN_CTGR_NM, cc.CMPGN_TYPE1_NM,
  cc.MK_CMPGN_NM, cc.MKTG_UTM_NM, cc.MKTG_CHANNEL_NM, cc.SPNSR_DIV_NM
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
LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO a116 ON a11.SPNSR_BSNS2_ID  = a116.SPNSR_BSNS_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     a117 ON a117.CD_ID = 'DMMM07' AND a11.NEW_OLD_DIV_CD = a117.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_t1 ON c_t1.CD_ID = 'CM016'  AND a11.SPNSR_TERM_CD      = c_t1.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_t2 ON c_t2.CD_ID = 'DMMM08' AND a11.SPNSR_TERM2_CD     = c_t2.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_m1 ON c_m1.CD_ID = 'CM012'  AND a11.SPNSR_AMT_CD       = c_m1.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_m2 ON c_m2.CD_ID = 'DMMM09' AND a11.SPNSR_AMT2_CD      = c_m2.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_st ON c_st.CD_ID = 'PM040'  AND a11.SETLE_CD           = c_st.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_md ON c_md.CD_ID = 'MM018'  AND a11.MBER_DIV_CD        = c_md.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_ar ON c_ar.CD_ID = 'CM011'  AND a11.AREA_CD            = c_ar.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_ab ON c_ab.CD_ID = 'CM003'  AND a11.SPNSR_BSNS_ABRV_CD = c_ab.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_r5 ON a11.DVLP_DIV_CD = '5' AND c_r5.CD_ID = 'MM005' AND a11.CANCL_RDCAMT_RSN_CD = c_r5.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     c_r3 ON a11.DVLP_DIV_CD = '3' AND c_r3.CD_ID = 'MM002' AND a11.CANCL_RDCAMT_RSN_CD = c_r3.DTL_CD_ID
LEFT JOIN GN_DW.MSTR.D_CMPGN_CD        c_pc ON a11.PRE_CMPGN_CD <> '0' AND a11.PRE_CMPGN_CD = c_pc.CMPGN_CD
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN    cc   ON a11.CMPGN_CD        = cc.CMPGN_CD;

GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_SPNSR_DVLP_V TO ROLE GN_DW_SERVICE;

-- 🆕 [O207 W2] 목표 grain 뷰 — 팩트의 MT/YY_GOAL_CNT 는 행마다 반복돼 합산하면 틀린다 ⇒ 목표는 이 뷰로만 낸다.
--   grain = 실적부서 × 기준년월 × 개발구분 · 목표 원천 = D_MBER_DVLP_GOAL_CD(일 배치 프로시저 USP_F_MM_SPNSR_DVLP_SUM 04_sp_script.sql:807-813 과 같은 키 · O207-C 좌표 정정)
--   실적 = 같은 키의 MSTR 개발(건) 합 · 범위 = 팩트 최소 기준월 ~ 최신 기준월이 속한 해의 12월
CREATE OR REPLACE VIEW GN_DW.SERVING.MSTR_DVLP_GOAL_V (
  STRD_MT COMMENT '기준년월(YYYYMM 문자열)',
  STRD_YY COMMENT '기준연도(YYYY 문자열)',
  DVLP_DIV_CD COMMENT '개발구분코드(MSTR)',
  DVLP_DIV_NM COMMENT '개발구분명 · 🔴 실질 목표는 신규만 있다(증액·재후원 목표 0)',
  DEPT4_NM COMMENT '실적부서4(구분_팀) 명',
  DEPT3_NM COMMENT '실적부서3(본부/지부) 명',
  DEPT2_NM COMMENT '실적부서2(팀/지부) 명',
  DEPT_ID COMMENT '실적부서 ID',
  DEPT_NM COMMENT '실적부서명',
  CLOSED_MONTH_YN COMMENT '마감월 여부(Y = 최신 기준월보다 이전 · N = 최신 기준월(진행 중) 또는 미래 월)',
  GOAL_CNT COMMENT '월 개발 목표(건 · MSTR 개발(건) 단위) · 목표 미등록 = NULL',
  ACT_CNT COMMENT 'MSTR 개발(건) 실적(후원금액 ÷ 10,000 합 · 소수 4자리) · 실적 없음 = NULL'
)
COMMENT = '🆕 [O207] MSTR 개발 목표·실적 월 grain 뷰. 원천 = GN_DW.MSTR.D_MBER_DVLP_GOAL_CD(목표) + F_MM_SPNSR_DVLP_SUM(실적). 🔴 MSTR 기준이다(GN_DW GOLD FACT_TARGET_MEMBER_DEV 와 같은 원천 목표).'
AS
WITH mx AS (
  SELECT MAX(STRD_MT) AS CUR_MT, MIN(STRD_MT) AS MIN_MT FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM
), act AS (
  SELECT ACMSLT_DEPT_CD AS DEPT_ID, STRD_MT, DVLP_DIV_CD, SUM(SPNSR_AMT_CNT) AS ACT_CNT
  FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM
  GROUP BY 1, 2, 3
), gl AS (
  SELECT DEPT_ID, STDYY || STDR_MT AS STRD_MT, MBER_DVLP_DIV_CD AS DVLP_DIV_CD, GOAL_CNT
  FROM GN_DW.MSTR.D_MBER_DVLP_GOAL_CD
), m AS (
  SELECT COALESCE(a.DEPT_ID, g.DEPT_ID) AS DEPT_ID,
         COALESCE(a.STRD_MT, g.STRD_MT) AS STRD_MT,
         COALESCE(a.DVLP_DIV_CD, g.DVLP_DIV_CD) AS DVLP_DIV_CD,
         g.GOAL_CNT, a.ACT_CNT
  FROM act a
  FULL OUTER JOIN gl g
    ON a.DEPT_ID = g.DEPT_ID AND a.STRD_MT = g.STRD_MT AND a.DVLP_DIV_CD = g.DVLP_DIV_CD
)
SELECT
  m.STRD_MT, LEFT(m.STRD_MT, 4), m.DVLP_DIV_CD, dv.DVLP_DIV_NM,
  d4.DEPT4_NM, d3.DEPT3_NM, d2.DEPT2_NM, m.DEPT_ID, d.DEPT_NM,
  IFF(m.STRD_MT < mx.CUR_MT, 'Y', 'N'),
  m.GOAL_CNT, ROUND(m.ACT_CNT, 4)::NUMBER(18,4)
FROM m
CROSS JOIN mx
LEFT JOIN GN_DW.MSTR.D_DEPT_CD     d  ON m.DEPT_ID = d.DEPT_ID
LEFT JOIN GN_DW.MSTR.D_DEPT2_CD    d2 ON d.DEPT2_ID = d2.DEPT2_ID
LEFT JOIN GN_DW.MSTR.D_DEPT3_CD    d3 ON d.DEPT3_ID = d3.DEPT3_ID
LEFT JOIN GN_DW.MSTR.D_DEPT4_CD    d4 ON d.DEPT4_ID = d4.DEPT4_ID
LEFT JOIN GN_DW.MSTR.D_DVLP_DIV_CD dv ON m.DVLP_DIV_CD = dv.DVLP_DIV_CD
WHERE m.STRD_MT BETWEEN mx.MIN_MT AND LEFT(mx.CUR_MT, 4) || '12';

-- 🆕 [O207 W2] 연도말 개발 추세 참고치 뷰 — MSTR 에 예측 로직은 없다(목표·실적만) ⇒ T3 규칙 그대로의 「추세 참고치」다.
--   grain = 실적부서 × 기준연도 × 개발구분 · 산식 = 마감월 실적 합 + (12 − 마감월 수) × 직전 3개 마감월 평균
--   (진행 중인 최신 기준월은 부분 실적이라 산식에서 평균으로 대체한다 · 지난 연도는 남은 월 0 ⇒ 참고치 = 실적)
CREATE OR REPLACE VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_V (
  STRD_YY COMMENT '기준연도(YYYY 문자열)',
  AS_OF_MT COMMENT '산출 기준 최신 기준년월(진행 중 · 부분 실적)',
  DVLP_DIV_CD COMMENT '개발구분코드(MSTR)',
  DVLP_DIV_NM COMMENT '개발구분명 · 🔴 실질 목표는 신규만 있다',
  DEPT4_NM COMMENT '실적부서4(구분_팀) 명',
  DEPT3_NM COMMENT '실적부서3(본부/지부) 명',
  DEPT2_NM COMMENT '실적부서2(팀/지부) 명',
  DEPT_ID COMMENT '실적부서 ID',
  DEPT_NM COMMENT '실적부서명',
  YY_GOAL_CNT COMMENT '연 개발 목표(건) = 월 목표 합',
  CLOSED_ACT_CNT COMMENT '그 해 마감월 MSTR 개발(건) 실적 합',
  CUR_MONTH_ACT_CNT COMMENT '진행 중 최신 기준월의 부분 실적(건 · 참고 · 추세 산식에는 쓰지 않는다)',
  CLOSED_MONTHS COMMENT '그 해 마감월 수',
  LAST3_AVG_CNT COMMENT '직전 3개 마감월 월평균 실적(건 · 현재 연도만 · 지난 연도 0)',
  YE_TREND_CNT COMMENT '연도말 개발 추세 참고치(건) = 마감월 실적 + (12 − 마감월 수) × 직전 3개월 평균 · 🔴 모델 예측이 아니다'
)
COMMENT = '🆕 [O207] MSTR 연도말 개발 추세 참고치. 원천 = SERVING.MSTR_DVLP_GOAL_V. 🔴🔴 MSTR 에 예측 로직은 없다 — 이 값은 직전 3개월 평균을 남은 달에 이어 붙인 「추세 참고치」이며 모델 예측이 아니다. 🔴 MSTR 기준.'
AS
WITH cur AS (
  SELECT MAX(IFF(CLOSED_MONTH_YN = 'N' AND ACT_CNT IS NOT NULL, STRD_MT, NULL)) AS CUR_MT
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V
), l3 AS (
  SELECT g.DEPT_ID, g.DVLP_DIV_CD, SUM(g.ACT_CNT) / 3 AS L3
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V g CROSS JOIN cur
  WHERE g.STRD_MT < cur.CUR_MT
    AND g.STRD_MT >= TO_CHAR(DATEADD(MONTH, -3, TO_DATE(cur.CUR_MT, 'YYYYMM')), 'YYYYMM')
  GROUP BY 1, 2
), y AS (
  SELECT STRD_YY, DVLP_DIV_CD, ANY_VALUE(DVLP_DIV_NM) AS DVLP_DIV_NM,
         ANY_VALUE(DEPT4_NM) AS DEPT4_NM, ANY_VALUE(DEPT3_NM) AS DEPT3_NM, ANY_VALUE(DEPT2_NM) AS DEPT2_NM,
         DEPT_ID, ANY_VALUE(DEPT_NM) AS DEPT_NM,
         SUM(GOAL_CNT) AS YY_GOAL_CNT,
         SUM(IFF(CLOSED_MONTH_YN = 'Y', ACT_CNT, 0)) AS CLOSED_ACT_CNT,
         SUM(IFF(CLOSED_MONTH_YN = 'N', ACT_CNT, 0)) AS CUR_MONTH_ACT_CNT
  FROM GN_DW.SERVING.MSTR_DVLP_GOAL_V
  GROUP BY STRD_YY, DVLP_DIV_CD, DEPT_ID
)
SELECT
  y.STRD_YY, cur.CUR_MT, y.DVLP_DIV_CD, y.DVLP_DIV_NM,
  y.DEPT4_NM, y.DEPT3_NM, y.DEPT2_NM, y.DEPT_ID, y.DEPT_NM,
  y.YY_GOAL_CNT,
  ROUND(y.CLOSED_ACT_CNT, 4)::NUMBER(18,4),
  ROUND(y.CUR_MONTH_ACT_CNT, 4)::NUMBER(18,4),
  -- 🆕 [O207] 마감월 수 = 달력 기준(실적 없는 달도 마감월로 센다 · 행 존재로 세면 결측 월이 남은 월로 부풀려진다)
  IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), TO_NUMBER(RIGHT(cur.CUR_MT, 2)) - 1, IFF(y.STRD_YY < LEFT(cur.CUR_MT, 4), 12, 0)),
  ROUND(IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), COALESCE(l3.L3, 0), 0), 4)::NUMBER(18,4),
  ROUND(y.CLOSED_ACT_CNT
        + IFF(y.STRD_YY = LEFT(cur.CUR_MT, 4), COALESCE(l3.L3, 0) * (13 - TO_NUMBER(RIGHT(cur.CUR_MT, 2))), 0), 4)::NUMBER(18,4)
FROM y
CROSS JOIN cur
LEFT JOIN l3 ON l3.DEPT_ID = y.DEPT_ID AND l3.DVLP_DIV_CD = y.DVLP_DIV_CD;

GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_GOAL_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_GOAL_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_GOAL_V TO ROLE GN_DW_SERVICE;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_V TO ROLE GN_DW_SERVICE;

-- 🆕 [O207 W2-b] 후원사업2 별 연도말 개발 추세 참고치 — 기획실 「후원사업별 연도말 개발 예측치」(피드백 CSV 기획실 2)
--   🔴 목표는 부서 단위로만 등록돼 있어 후원사업 축에는 목표가 없다 ⇒ 목표·달성률 컬럼을 두지 않는다.
--   산식 = MSTR_DVLP_YE_TREND_V 와 동일(마감월 실적 + (12 − 마감월 수) × 직전 3개 마감월 평균) · grain = 후원사업2 × 기준연도 × 개발구분
CREATE OR REPLACE VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V (
  STRD_YY COMMENT '기준연도(YYYY 문자열)',
  AS_OF_MT COMMENT '산출 기준 최신 기준년월(진행 중 · 부분 실적)',
  DVLP_DIV_CD COMMENT '개발구분코드(MSTR)',
  DVLP_DIV_NM COMMENT '개발구분명',
  SPNSR_BSNS2_ID COMMENT '후원사업2 ID(MSTR 재분류)',
  SPNSR_BSNS2_NM COMMENT '후원사업2 명(MSTR 재분류)',
  CLOSED_ACT_CNT COMMENT '그 해 마감월 MSTR 개발(건) 실적 합',
  CUR_MONTH_ACT_CNT COMMENT '진행 중 최신 기준월의 부분 실적(건 · 참고)',
  CLOSED_MONTHS COMMENT '그 해 마감월 수',
  LAST3_AVG_CNT COMMENT '직전 3개 마감월 월평균 실적(건 · 현재 연도만 · 지난 연도 0)',
  YE_TREND_CNT COMMENT '연도말 개발 추세 참고치(건) · 🔴 모델 예측이 아니다 · 후원사업 축에는 목표가 없다'
)
COMMENT = '🆕 [O207] MSTR 후원사업2 별 연도말 개발 추세 참고치. 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM. 🔴🔴 모델 예측이 아니다 · 목표 없음(목표는 부서 단위만 등록). 🔴 MSTR 기준.'
AS
WITH mx AS (
  SELECT MAX(STRD_MT) AS CUR_MT FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM
), m AS (
  SELECT f.SPNSR_BSNS2_ID, f.STRD_MT, f.DVLP_DIV_CD, SUM(f.SPNSR_AMT_CNT) AS ACT_CNT
  FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM f
  GROUP BY 1, 2, 3
), y AS (
  SELECT m.SPNSR_BSNS2_ID, LEFT(m.STRD_MT, 4) AS STRD_YY, m.DVLP_DIV_CD,
         SUM(IFF(m.STRD_MT < mx.CUR_MT, m.ACT_CNT, 0)) AS CLOSED_ACT_CNT,
         SUM(IFF(m.STRD_MT = mx.CUR_MT, m.ACT_CNT, 0)) AS CUR_MONTH_ACT_CNT
  FROM m CROSS JOIN mx
  GROUP BY 1, 2, 3
), l3 AS (
  SELECT m.SPNSR_BSNS2_ID, m.DVLP_DIV_CD, SUM(m.ACT_CNT) / 3 AS L3
  FROM m CROSS JOIN mx
  WHERE m.STRD_MT < mx.CUR_MT
    AND m.STRD_MT >= TO_CHAR(DATEADD(MONTH, -3, TO_DATE(mx.CUR_MT, 'YYYYMM')), 'YYYYMM')
  GROUP BY 1, 2
)
SELECT
  y.STRD_YY, mx.CUR_MT, y.DVLP_DIV_CD, dv.DVLP_DIV_NM, y.SPNSR_BSNS2_ID, b.SPNSR_BSNS_NM,
  ROUND(y.CLOSED_ACT_CNT, 4)::NUMBER(18,4),
  ROUND(y.CUR_MONTH_ACT_CNT, 4)::NUMBER(18,4),
  -- 마감월 수 = 달력 기준(실적 없는 달도 마감월로 센다 · 부서 뷰와 같은 기준)
  IFF(y.STRD_YY = LEFT(mx.CUR_MT, 4), TO_NUMBER(RIGHT(mx.CUR_MT, 2)) - 1, 12),
  ROUND(IFF(y.STRD_YY = LEFT(mx.CUR_MT, 4), COALESCE(l3.L3, 0), 0), 4)::NUMBER(18,4),
  ROUND(y.CLOSED_ACT_CNT
        + IFF(y.STRD_YY = LEFT(mx.CUR_MT, 4), COALESCE(l3.L3, 0) * (13 - TO_NUMBER(RIGHT(mx.CUR_MT, 2))), 0), 4)::NUMBER(18,4)
FROM y
CROSS JOIN mx
LEFT JOIN l3 ON l3.SPNSR_BSNS2_ID = y.SPNSR_BSNS2_ID AND l3.DVLP_DIV_CD = y.DVLP_DIV_CD
LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO b ON y.SPNSR_BSNS2_ID = b.SPNSR_BSNS_ID
LEFT JOIN GN_DW.MSTR.D_DVLP_DIV_CD dv ON y.DVLP_DIV_CD = dv.DVLP_DIV_CD;

GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V TO ROLE GN_DW_ANALYST;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V TO ROLE GN_DW_SERVICE;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP
  TABLES (
    md AS GN_DW.SERVING.MSTR_SPNSR_DVLP_V
      WITH SYNONYMS ('MSTR 개발', 'MSTR 후원개발', 'MSTR 리포트', '정기회원 후원개발')
      COMMENT = 'MSTR 정기회원 후원개발 리포트 (base: SERVING.MSTR_SPNSR_DVLP_V). [Grain: 개발 팩트 1행]. [활성 지표: MSTR 개발(건)·개발(명)·후원금액]. [주의: MSTR 기준 정의, GN_DW 지표와 합산 금지, 개발(명) 비가산]. [원천: BRONZE_CRM → GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM(MSTR 이관 로직) → SERVING.MSTR_SPNSR_DVLP_V].',
    gl AS GN_DW.SERVING.MSTR_DVLP_GOAL_V
      WITH SYNONYMS ('MSTR 개발 목표', '개발 목표', '목표 달성')
      COMMENT = '🆕 [O207] MSTR 개발 목표·실적 (base: SERVING.MSTR_DVLP_GOAL_V). [Grain: 실적부서 × 기준년월 × 개발구분]. [활성 지표: 월 목표(건)·실적(건)·달성률]. [주의: 실질 목표는 신규만 · md 테이블과 조인하지 않는다].',
    ye AS GN_DW.SERVING.MSTR_DVLP_YE_TREND_V
      WITH SYNONYMS ('연도말 개발 예측', '연말 개발 전망', '연도말 추세')
      COMMENT = '🆕 [O207] MSTR 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_V). [Grain: 실적부서 × 기준연도 × 개발구분]. [활성 지표: 연 목표·마감월 실적·추세 참고치·목표 대비 %]. [주의: 모델 예측 아님 · 직전 3개 마감월 평균 기반].',
    yb AS GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V
      WITH SYNONYMS ('후원사업별 연도말 개발 예측', '후원사업별 연말 전망')
      COMMENT = '🆕 [O207] MSTR 후원사업2 별 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_BSNS_V). [Grain: 후원사업2 × 기준연도 × 개발구분]. [주의: 모델 예측 아님 · 후원사업 축에는 목표가 없다].'
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
      WITH SYNONYMS ('브랜드', '브랜드명', '세부 브랜드', 'CRM 브랜드')
      COMMENT = '브랜드명(원천 COMMENT = 브랜드 · 60여 종). 🆕 [O212-B 원천 컬럼명 원칙] 「브랜드」는 이 축이다 — 「공통브랜드」를 말할 때만 CMMN_BRND_NM 을 쓴다.',
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
    md.NEW_OLD_DIV_NM AS md.NEW_OLD_DIV_NM
      WITH SYNONYMS ('신규기존구분', '신규/기존', '신규 기존')
      COMMENT = '🆕 [O206-D] MSTR 신규기존구분명. 실제값: ''신규''·''기존''(코드 99 = ''없음''). 🔴 MSTR 원천이 개발 건마다 판정해 둔 값이다 — 가입일로 다시 계산하지 않는다(MSTR 에는 가입일 컬럼이 없다).',
    md.MBER_NO AS md.MBER_NO
      WITH SYNONYMS ('회원번호')
      COMMENT = '회원번호. 개발(명) 중복제거 전용 — 회원 목록 질의에는 쓰지 않는다.',
    md.SPNSR_TERM_NM AS md.SPNSR_TERM_NM
      WITH SYNONYMS ('후원기간대', '후원기간')
      COMMENT = '🆕 [O207] 후원기간대(CM016 · 1년 미만/1~5년/5~10년/10년 이상 · 첫 후원일 → 발생일).',
    md.SPNSR_TERM2_NM AS md.SPNSR_TERM2_NM
      WITH SYNONYMS ('후원기간대2', '후원기간 1년 단위')
      COMMENT = '🆕 [O207] 후원기간대2(DMMM08 · 1년 단위 11구간).',
    md.SPNSR_AMT_NM AS md.SPNSR_AMT_NM
      WITH SYNONYMS ('후원금액범위', '후원금액대')
      COMMENT = '🆕 [O207] 후원금액범위(CM012 · 원천 판정값). 🔴 그 행 후원금액의 구간이 아니다 — 개발금액 구간은 후원금액대2 를 쓴다.',
    md.SPNSR_AMT2_NM AS md.SPNSR_AMT2_NM
      WITH SYNONYMS ('후원금액대2', '개발금액대')
      COMMENT = '🆕 [O207] 후원금액대2(DMMM09 · 1만원 단위 · 후원사업별 최초 정상 개발건 금액 기준 · 「없음」 = 매칭 없음).',
    md.SETLE_NM AS md.SETLE_NM
      WITH SYNONYMS ('결제수단', '결제방법', '납입방법')
      COMMENT = '🆕 [O207] 결제수단(PM040 · 자동이체·신용카드·휴대폰·네이버페이 등).',
    md.MBER_DIV_NM AS md.MBER_DIV_NM
      WITH SYNONYMS ('회원구분', '개인/기업/단체')
      COMMENT = '🆕 [O207] 회원구분(MM018 · 개인·기업·단체).',
    md.AREA_NM AS md.AREA_NM
      WITH SYNONYMS ('지역', '시도')
      COMMENT = '🆕 [O207] 시도(CM011). 🔴 「기타」가 큰 비중을 차지한다 · 라벨 없는 코드는 NULL.',
    md.SPNSR_BSNS_ABRV_NM AS md.SPNSR_BSNS_ABRV_NM
      WITH SYNONYMS ('후원약칭', '국내/해외/결연')
      COMMENT = '🆕 [O207] 후원약칭(CM003 · 국내·결연·해외·해외구호·북한 등).',
    md.CANCL_RDCAMT_RSN_NM AS md.CANCL_RDCAMT_RSN_NM
      WITH SYNONYMS ('중단사유', '감액사유', '중단·감액 사유')
      COMMENT = '🆕 [O207] 중단·감액 사유. 🔴 개발구분 후원중단 = 후원중단사유(MM005) · 감액 = 후원사업취소사유(MM002) · 그 외 개발구분은 NULL(개념 없음). 사유 질문은 개발구분을 후원중단 또는 감액 하나로 고정한다.',
    md.PRE_CMPGN_NM AS md.PRE_CMPGN_NM
      WITH SYNONYMS ('직전캠페인', '이전 캠페인')
      COMMENT = '🆕 [O207] 직전캠페인(재후원 전 마지막 캠페인). 🔴 재후원·금액>0 행에만 값이 있다.',
    md.CMMN_BRND_NM AS md.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드', '공통 브랜드')
      COMMENT = '🆕 [O212] 공통브랜드(MM297 · 예: 디지털·교육기관·지역개발·대면모금·영상광고·재송출·방송). 「공통브랜드」를 말할 때 쓴다(「브랜드」는 BRND_NM). 캠페인 마스터 현재값.',
    md.DVLP_INFLOW_PATH_NM AS md.DVLP_INFLOW_PATH_NM
      WITH SYNONYMS ('개발인입경로', '인입경로', '개발 인입경로', '모집채널')
      COMMENT = '🆕 [O212] 개발인입경로(MM293 · 12종 · 예: 디지털·방송·대면모금·교육기관·지역개발·콜개발·영상광고·재송출). 캠페인 마스터 현재값. 🔴 공통브랜드와 라벨이 겹쳐 보여도 다른 축이다 — 한쪽 값으로 다른 쪽을 필터하지 않는다.',
    md.CMPGN_TYPE2_NM AS md.CMPGN_TYPE2_NM
      WITH SYNONYMS ('캠페인유형2', '캠페인유형(사업/사례)', '사업사례구분', '사업/사례')
      COMMENT = '🆕 [O212] 캠페인유형2(원천 COMMENT = 캠페인유형(사업/사례) · MM296 · 4종 = 사례·사업·굿즈·기타). 「캠페인유형2」·「사업/사례」를 말할 때 쓴다 — 「캠페인유형」은 CMPGN_TYPE1_NM(국내/해외)이다. 캠페인 마스터 현재값.',
    md.CMPGN_CTGR_NM AS md.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인', '캠페인 카테고리', '캠페인 소분류')
      COMMENT = '🆕 [O212] 캠페인카테고리(MM294 · 세부 40여 종 · 예: 초등캠페인·국내사례캠페인·해외캠페인·희망TV). 「캠페인카테고리」「주요캠페인」을 명시할 때만 쓴다. 🔴 캠페인유형2 의 엄격한 하위가 아니다(한 카테고리가 여러 유형2 에 걸친다).',
    md.CMPGN_TYPE1_NM AS md.CMPGN_TYPE1_NM
      WITH SYNONYMS ('캠페인유형', '캠페인 유형', '캠페인유형(국내/해외)', '국내해외', '국내/해외')
      COMMENT = '🆕 [O212-B] 캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등). 「캠페인유형」을 말할 때 쓴다(「캠페인유형2」는 사업/사례 CMPGN_TYPE2_NM). 캠페인 마스터 현재값.',
    md.MK_CMPGN_NM AS md.MK_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인', '나마본캠페인')
      COMMENT = '마케팅캠페인(원천 COMMENT = 마케팅 캠페인명 · C001 · 500여 종). 「마케팅캠페인」을 말할 때 쓴다(「캠페인」은 CMPGN_NM 개발캠페인). 캠페인 마스터 현재값.',
    md.MKTG_UTM_NM AS md.MKTG_UTM_NM
      WITH SYNONYMS ('UTM', '마케팅 UTM', '유입 UTM')
      COMMENT = '마케팅 UTM(원천 COMMENT = 마케팅 UTM 라벨 · U001). 🔴 일부 캠페인에만 값이 있다 — NULL 은 UTM 미등록 캠페인이며 「UTM별」 합계는 전체보다 작다(총계는 축 없이 답한다).',
    md.MKTG_CHANNEL_NM AS md.MKTG_CHANNEL_NM
      WITH SYNONYMS ('마케팅채널', '마케팅 채널', '캠페인 채널')
      COMMENT = '마케팅채널(원천 COMMENT = 마케팅 채널명 · C002 · 100여 종). 캠페인 마스터 현재값. 🔴 개발인입경로(MM293)와 다른 축이다. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 캠페인 37,204 중 5,211 · 2026-10-08 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    md.SPNSR_DIV_NM AS md.SPNSR_DIV_NM
      WITH SYNONYMS ('후원구분', '정기/일시')
      COMMENT = '후원구분(원천 COMMENT = 후원구분명 · CM035 · 정기후원/일시후원). 캠페인 마스터 기준(캠페인이 정기·일시 중 어디에 쓰이는지)이다.',
    gl.STRD_MT AS gl.STRD_MT
      WITH SYNONYMS ('목표 기준년월')
      COMMENT = '🆕 [O207] 목표·실적 기준년월(YYYYMM).',
    gl.STRD_YY AS gl.STRD_YY
      WITH SYNONYMS ('목표 기준연도')
      COMMENT = '🆕 [O207] 목표·실적 기준연도(YYYY).',
    gl.DVLP_DIV_CD AS gl.DVLP_DIV_CD
      WITH SYNONYMS ('목표 개발구분코드')
      COMMENT = '🆕 [O207] 개발구분코드(1 = 신규).',
    gl.DVLP_DIV_NM AS gl.DVLP_DIV_NM
      WITH SYNONYMS ('목표 개발구분')
      COMMENT = '🆕 [O207] 개발구분. 🔴 실질 목표는 신규만 있다 — 목표 질문은 신규로 고정한다.',
    gl.DEPT4_NM AS gl.DEPT4_NM
      WITH SYNONYMS ('목표 구분_팀')
      COMMENT = '🆕 [O207] 실적부서4(구분_팀).',
    gl.DEPT3_NM AS gl.DEPT3_NM
      WITH SYNONYMS ('목표 본부/지부')
      COMMENT = '🆕 [O207] 실적부서3(본부/지부).',
    gl.DEPT2_NM AS gl.DEPT2_NM
      WITH SYNONYMS ('목표 팀/지부')
      COMMENT = '🆕 [O207] 실적부서2(팀/지부).',
    gl.DEPT_NM AS gl.DEPT_NM
      WITH SYNONYMS ('목표 부서')
      COMMENT = '🆕 [O207] 실적부서명(목표 등록 단위).',
    gl.CLOSED_MONTH_YN AS gl.CLOSED_MONTH_YN
      WITH SYNONYMS ('마감월 여부')
      COMMENT = '🆕 [O207] Y = 마감월 · N = 진행 중인 최신 기준월 또는 미래 월(부분 실적).',
    ye.STRD_YY AS ye.STRD_YY
      WITH SYNONYMS ('전망 기준연도')
      COMMENT = '🆕 [O207] 연도말 추세 참고치 기준연도(YYYY).',
    ye.AS_OF_MT AS ye.AS_OF_MT
      WITH SYNONYMS ('산출 기준월')
      COMMENT = '🆕 [O207] 산출 기준 최신 기준년월(진행 중 · 부분 실적).',
    ye.DVLP_DIV_CD AS ye.DVLP_DIV_CD
      WITH SYNONYMS ('전망 개발구분코드')
      COMMENT = '🆕 [O207] 개발구분코드(1 = 신규).',
    ye.DVLP_DIV_NM AS ye.DVLP_DIV_NM
      WITH SYNONYMS ('전망 개발구분')
      COMMENT = '🆕 [O207] 개발구분. 🔴 목표 대비 % 는 신규에만 의미가 있다.',
    ye.DEPT4_NM AS ye.DEPT4_NM
      WITH SYNONYMS ('전망 구분_팀')
      COMMENT = '🆕 [O207] 실적부서4(구분_팀).',
    ye.DEPT3_NM AS ye.DEPT3_NM
      WITH SYNONYMS ('전망 본부/지부')
      COMMENT = '🆕 [O207] 실적부서3(본부/지부).',
    ye.DEPT2_NM AS ye.DEPT2_NM
      WITH SYNONYMS ('전망 팀/지부')
      COMMENT = '🆕 [O207] 실적부서2(팀/지부).',
    ye.DEPT_NM AS ye.DEPT_NM
      WITH SYNONYMS ('전망 부서')
      COMMENT = '🆕 [O207] 실적부서명.',
    yb.STRD_YY AS yb.STRD_YY
      WITH SYNONYMS ('후원사업 전망 기준연도')
      COMMENT = '🆕 [O207] 기준연도(YYYY).',
    yb.AS_OF_MT AS yb.AS_OF_MT
      WITH SYNONYMS ('후원사업 전망 산출 기준월')
      COMMENT = '🆕 [O207] 산출 기준 최신 기준년월(진행 중).',
    yb.DVLP_DIV_CD AS yb.DVLP_DIV_CD
      WITH SYNONYMS ('후원사업 전망 개발구분코드')
      COMMENT = '🆕 [O207] 개발구분코드(1 = 신규).',
    yb.DVLP_DIV_NM AS yb.DVLP_DIV_NM
      WITH SYNONYMS ('후원사업 전망 개발구분')
      COMMENT = '🆕 [O207] 개발구분.',
    yb.SPNSR_BSNS2_NM AS yb.SPNSR_BSNS2_NM
      WITH SYNONYMS ('전망 후원사업2', '후원사업별 전망')
      COMMENT = '🆕 [O207] 후원사업2(MSTR 재분류).'
  )
  METRICS (
    md.MSTR_DVLP_CNT AS ROUND(SUM(md.SPNSR_AMT_CNT), 4)
      WITH SYNONYMS ('개발(건)', 'MSTR 개발건', '개발 건수')
      COMMENT = 'MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 4자리). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',
    md.MSTR_DVLP_MEMBERS AS COUNT(DISTINCT md.MBER_NO)
      WITH SYNONYMS ('개발(명)', 'MSTR 개발 회원수', '개발 명')
      COMMENT = 'MSTR 개발(명) = 회원번호 중복제거. 🔴 비가산 — 하위 그룹 값을 더해 상위 값을 만들지 않는다.',
    md.MSTR_SPNSR_AMT AS SUM(md.SPNSR_AMT)
      WITH SYNONYMS ('후원금액', '개발 금액')
      COMMENT = '후원금액 합계(원). 감액·후원중단 구분은 음수다.',
    md.MSTR_ROW_CNT AS SUM(md.DVLP_CNT)
      WITH SYNONYMS ('개발 행수', '원천 건수')
      COMMENT = '원천 개발구분건수 합계(행 단위). MSTR 리포트 「개발(건)」이 아니다.',
    gl.GOAL_DVLP_CNT AS SUM(gl.GOAL_CNT)
      WITH SYNONYMS ('개발 목표(건)', '목표(건)', '월 목표')
      COMMENT = '🆕 [O207] MSTR 개발 목표(건) 합. 🔴 실질 목표는 신규만 있다.',
    gl.GOAL_ACT_CNT AS ROUND(SUM(gl.ACT_CNT), 4)
      WITH SYNONYMS ('목표 대비 실적(건)', '실적(건)')
      COMMENT = '🆕 [O207] 목표와 같은 키(부서×월×개발구분)의 MSTR 개발(건) 실적 합(소수 4자리).',
    gl.GOAL_ACHV_RATE AS ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1)
      WITH SYNONYMS ('목표 달성률(%)', '달성률', '달성율')
      COMMENT = '🆕 [O207] 목표 달성률(%) = 목표가 있는 부서·월 실적 ÷ 목표 × 100(소수 1자리). 🔴 목표 없는 부서 실적은 분자에서 뺀다.',
    ye.YE_GOAL_CNT AS SUM(ye.YY_GOAL_CNT)
      WITH SYNONYMS ('연 개발 목표(건)', '연간 목표')
      COMMENT = '🆕 [O207] 연 개발 목표(건) = 월 목표 합.',
    ye.YE_CLOSED_ACT_CNT AS ROUND(SUM(ye.CLOSED_ACT_CNT), 4)
      WITH SYNONYMS ('마감월 누적 실적(건)', '연누적 실적')
      COMMENT = '🆕 [O207] 그 해 마감월 MSTR 개발(건) 실적 합.',
    ye.YE_CUR_MONTH_ACT_CNT AS ROUND(SUM(ye.CUR_MONTH_ACT_CNT), 4)
      WITH SYNONYMS ('진행 월 부분 실적(건)')
      COMMENT = '🆕 [O207] 진행 중 최신 기준월의 부분 실적(참고 · 추세 산식에 쓰지 않는다).',
    ye.YE_LAST3_AVG_CNT AS ROUND(SUM(ye.LAST3_AVG_CNT), 4)
      WITH SYNONYMS ('직전 3개월 평균(건)')
      COMMENT = '🆕 [O207] 직전 3개 마감월 월평균 실적(건 · 현재 연도만).',
    ye.YE_TREND_DVLP_CNT AS ROUND(SUM(ye.YE_TREND_CNT), 4)
      WITH SYNONYMS ('연도말 개발 추세 참고치(건)', '연도말 예측(건)', '연말 전망(건)')
      COMMENT = '🆕 [O207] 연도말 개발 추세 참고치(건) = 마감월 실적 + 남은 월 × 직전 3개월 평균. 🔴🔴 모델 예측이 아니다 — 답변에 「추세 참고치(모델 예측 아님)」를 밝힌다.',
    ye.YE_TREND_GOAL_RATE AS ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1)
      WITH SYNONYMS ('연 목표 대비 추세(%)', '연말 달성 전망(%)')
      COMMENT = '🆕 [O207] 연 목표 대비 추세 참고치(%) = 목표가 있는 부서의 추세 참고치 ÷ 연 목표 × 100(소수 1자리).',
    yb.YB_CLOSED_ACT_CNT AS ROUND(SUM(yb.CLOSED_ACT_CNT), 4)
      WITH SYNONYMS ('후원사업 마감월 누적 실적(건)')
      COMMENT = '🆕 [O207] 후원사업2 별 그 해 마감월 MSTR 개발(건) 실적 합.',
    yb.YB_LAST3_AVG_CNT AS ROUND(SUM(yb.LAST3_AVG_CNT), 4)
      WITH SYNONYMS ('후원사업 직전 3개월 평균(건)')
      COMMENT = '🆕 [O207] 후원사업2 별 직전 3개 마감월 월평균 실적(건).',
    yb.YB_TREND_DVLP_CNT AS ROUND(SUM(yb.YE_TREND_CNT), 4)
      WITH SYNONYMS ('후원사업 연도말 개발 추세 참고치(건)', '후원사업별 연도말 예측(건)')
      COMMENT = '🆕 [O207] 후원사업2 별 연도말 개발 추세 참고치(건). 🔴 모델 예측이 아니다 · 목표 없음.'
  )
  COMMENT = 'MSTR 정기회원 후원개발 SV(MSTR 1차 이관 · O197/O200-B). base=SERVING.MSTR_SPNSR_DVLP_V. 🔴🔴 **MSTR 기준 정의다** — GN_DW 회원 SV(SV_MEMBER_EVENT 등)의 개발건수·회원수와 정의가 달라 같은 표에 합산·차감하지 않는다. 🔴🔴 **MSTR 개발(건) = 후원금액 ÷ 10,000** 이다(사건 건수가 아니다). 🔴 개발(명)은 중복제거라 비가산이다. 🔴 MSTR 「개발」 리포트의 기본 범위는 개발구분 신규·증액·재후원이다 — 감액·후원중단을 섞지 않는다. 🔴 적재 기준월은 PoC 범위로 제한돼 있다 — 조회로 확인한다. 활성: 개발(건)·개발(명)·후원금액 · 기준년월/기준일자/개발구분/법인/부서4·3·2·부서/브랜드/상위캠페인/캠페인/홍보방법/후원사업/후원사업2/성별/연령대/신규기존구분 축 · 🆕 [O207] 후원기간대·후원기간대2·후원금액범위·후원금액대2·결제수단·회원구분·시도·후원약칭·중단/감액 사유·직전캠페인 축 · 🆕 [O212] 공통브랜드·개발인입경로·캠페인유형(국내/해외)·캠페인유형2(사업/사례)·캠페인카테고리 축(캠페인 마스터 현재값) · 마케팅캠페인·마케팅 UTM·마케팅채널·후원구분 축(캠페인 마스터 현재값) · 목표(gl: 월 목표·실적·달성률) · 연도말 추세 참고치(ye: 부서 · yb: 후원사업2 · 모델 예측 아님). 🔴 md·gl·ye·yb 네 테이블은 서로 조인하지 않는다(관계 없음 · 질문마다 한 테이블만 쓴다).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **개발구분 미지정 시 MSTR 개발 리포트 범위인 신규·증액·재후원(DVLP_DIV_CD IN (''1'',''2'',''4''))으로 한정하고 그 사실을 밝힌다.** 감액·후원중단은 사용자가 명시할 때만 포함하며 개발과 합산하지 않는다. (2) 🔴🔴 **「개발(건)」은 MSTR_DVLP_CNT(후원금액÷10,000 합)다** — 행 수(COUNT)나 MSTR_ROW_CNT 로 바꾸지 않는다. 답변에 「MSTR 기준」임을 밝힌다. (3) 🔴 **개발(명)은 COUNT(DISTINCT md.MBER_NO)로 그 그룹에서 직접 센다** — 하위 그룹 합으로 만들지 않는다. (4) 🔴 **기준년월 미지정 시 데이터에 존재하는 최신 기준년월 하나로 한정하고 밝힌다.** (5) 🔴 **GN_DW 지표와 섞지 않는다.** (6) **금액은 원 단위다.** (7) 적용 조건(그룹 미지정 시): 최신 기준년월 + 신규·증액·재후원으로 한정해 개발구분별 개발(건)·개발(명)·후원금액을 반환한다. (8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(ROUND(SUM(md.SPNSR_AMT_CNT), 4) 등)으로 집계한다. (9) 🆕 [O206-D] 개발(건)은 소수 4자리로 반올림해 낸다 — ROUND(SUM(md.SPNSR_AMT_CNT), 4). (10) 🆕 [O206-D] 「신규/기존」 구분은 md.NEW_OLD_DIV_NM 으로 그룹·필터한다 — 가입일이 없다고 산출 불가로 답하지 않는다.
  🆕 [O207 규칙] (11) 🔴🔴 **md·gl·ye·yb 는 서로 조인하지 않는다** — 개발 실적의 축 분해(후원기간대·결제수단·시도·사유 등)는 md, 목표·달성률은 gl, 부서별·전사 연도말 예측·전망은 ye, 후원사업별 연도말 예측·전망은 yb(목표 없음) 하나만 쓴다. (12) 🔴🔴 **목표는 gl·ye 로만 낸다** — 실질 목표는 신규만 있으므로 목표·달성률·연도말 전망 질문은 개발구분 신규(DVLP_DIV_CD = ''1'')로 고정하고 그 사실을 밝힌다. (13) 🔴🔴 **ye 의 연도말 값은 「추세 참고치(모델 예측 아님)」다** — 산식(마감월 실적 + 남은 월 × 직전 3개 마감월 평균)과 산출 기준월(ye.AS_OF_MT)을 함께 반환하고, 연도 미지정 시 ye.AS_OF_MT 가 속한 연도로 한정한다. 진행 중인 최신 기준월(gl.CLOSED_MONTH_YN = ''N'')의 실적은 부분 실적이라 달성률 비교에서 따로 밝힌다. 🆕 [O207-C] 누계·연간 달성률은 마감월(gl.CLOSED_MONTH_YN = ''Y'')만으로 계산한다 — 미래 월 목표와 부분 실적을 함께 더하면 달성률이 낮게 왜곡된다. (14) 🔴 중단·감액 사유(md.CANCL_RDCAMT_RSN_NM)는 개발구분을 후원중단 또는 감액 하나로 고정해 묻는다 — 두 개발구분의 사유 코드 체계가 다르다. (15) 🔴 후원금액범위(md.SPNSR_AMT_NM)는 원천 판정값이다 — 「개발금액 구간」 질문은 후원금액대2(md.SPNSR_AMT2_NM)로 답한다. (16) 🔴 부서별 질문에서 목표 없는 부서는 달성률을 만들지 않고 「목표 미등록」으로 밝힌다. 🆕 [O212 분류 축 · 대분류 우선] (17) 🔴🔴 🆕 [O212-B 원천 컬럼명 원칙] 질문의 분류 이름은 원천 컬럼 COMMENT 의 한글 이름 그대로 축에 대응한다 — 「브랜드」 = md.BRND_NM · 「공통브랜드」 = md.CMMN_BRND_NM · 「캠페인유형」 = md.CMPGN_TYPE1_NM(국내/해외) · 「캠페인유형2」 = md.CMPGN_TYPE2_NM(사업/사례) · 「캠페인카테고리」·「주요캠페인」 = md.CMPGN_CTGR_NM · 「개발인입경로」·「인입경로」 = md.DVLP_INFLOW_PATH_NM. 묻지 않은 분류 축을 함께 GROUP BY 하지 않는다. (18) 🔴 네 분류 축은 캠페인 마스터 현재값이다 — 축 이름에 「공통브랜드」 등 업무명을 그대로 별칭으로 쓴다. (19) 「마케팅캠페인」 = md.MK_CMPGN_NM · 「UTM」 = md.MKTG_UTM_NM · 「마케팅채널」 = md.MKTG_CHANNEL_NM · 「후원구분」 = md.SPNSR_DIV_NM(모두 캠페인 마스터 현재값). 🔴 UTM 은 일부 캠페인에만 값이 있다 — UTM별 표를 낼 때 NULL 버킷을 함께 보여주고 전체 합계는 축 없이 따로 낸다.'
  AI_VERIFIED_QUERIES (
    vqr_o207_ye_trend_dept4 AS (
      QUESTION '구분_팀별 올해 연도말 신규 개발 예측(목표 대비)'
      VERIFIED_BY '(O207 · 원천 직접 집계 대조 · 2026 신규 전사 참고치 250,243.3201건 / 목표 352,702건 = 70.9% · 산출 기준월 202610)'
      SQL 'SELECT ye.DEPT4_NM AS "전망 구분_팀", MAX(ye.AS_OF_MT) AS "산출 기준월", SUM(ye.YY_GOAL_CNT) AS "연 개발 목표(건)", ROUND(SUM(ye.CLOSED_ACT_CNT), 4) AS "마감월 누적 실적(건)", ROUND(SUM(ye.LAST3_AVG_CNT), 4) AS "직전 3개월 평균(건)", ROUND(SUM(ye.YE_TREND_CNT), 4) AS "연도말 개발 추세 참고치(건)", ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1) AS "연 목표 대비 추세(%)" FROM ye WHERE ye.DVLP_DIV_CD = ''1'' AND ye.STRD_YY = LEFT(ye.AS_OF_MT, 4) GROUP BY ROLLUP(ye.DEPT4_NM) ORDER BY 6 DESC NULLS FIRST'
    ),
    vqr_o207_goal_month AS (
      QUESTION '올해 마감월까지 월별 신규 개발 목표와 실적, 달성률'
      VERIFIED_BY '(O207 · 2026-01 달성률 93.3% · 2026-09 76.5% · 마감월 누계 70.1% 원천 대조 · O207-C 마감월 한정 교정)'
      SQL 'SELECT gl.STRD_MT AS "목표 기준년월", SUM(gl.GOAL_CNT) AS "개발 목표(건)", ROUND(SUM(gl.ACT_CNT), 4) AS "목표 대비 실적(건)", ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1) AS "목표 달성률(%)" FROM gl WHERE gl.DVLP_DIV_CD = ''1'' AND gl.CLOSED_MONTH_YN = ''Y'' AND gl.STRD_YY = (SELECT LEFT(MAX(STRD_MT), 4) FROM gl WHERE CLOSED_MONTH_YN = ''Y'') GROUP BY ROLLUP(gl.STRD_MT) ORDER BY 1 NULLS LAST'
    ),
    vqr_o207_stop_reason AS (
      QUESTION '최신 기준월 후원중단 사유별 개발(건)·개발(명)'
      VERIFIED_BY '(O207 · 사유 = MM005 · 후원중단 한정)'
      SQL 'SELECT md.CANCL_RDCAMT_RSN_NM AS "중단사유", ROUND(SUM(md.SPNSR_AMT_CNT), 4) AS "개발(건)", COUNT(DISTINCT md.MBER_NO) AS "개발(명)" FROM md WHERE md.DVLP_DIV_CD = ''5'' AND md.STRD_MT = (SELECT MAX(STRD_MT) FROM md) GROUP BY md.CANCL_RDCAMT_RSN_NM ORDER BY 2'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP TO ROLE GN_DW_SERVICE;

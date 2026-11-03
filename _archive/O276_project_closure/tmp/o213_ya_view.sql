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
  MK_CMPGN_NM COMMENT '🆕 [O213] 마케팅캠페인(원천 COMMENT = 마케팅 캠페인명 · TC_MKTNG_DTL_CD C001 라벨 · 나마본캠페인) · 캠페인 마스터 현재값',
  MKTG_UTM_NM COMMENT '🆕 [O213] 마케팅 UTM(원천 COMMENT = 마케팅 UTM 라벨 · U001) · 🔴 원천에 값이 있는 캠페인에만 값이 있다(그 외 NULL)',
  MKTG_CHANNEL_NM COMMENT '🆕 [O213] 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) · 캠페인 마스터 현재값',
  SPNSR_DIV_NM COMMENT '🆕 [O213] 후원구분(원천 COMMENT = 후원구분명 · CM035 · 정기후원/일시후원) · 캠페인 마스터 현재값'
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
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN    cc   ON a11.CMPGN_CD        = cc.CMPGN_CD
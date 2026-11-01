-- =====================================================================
-- 14_현업의사결정_BRONZE_실증쿼리.sql
-- 목적: db검토_20260903.md 및 14_현업의사결정_DB실측근거.md 에 기술된 6대 영역별
--       현업 의사결정 이슈의 근거 데이터를 BRONZE 원천에서 직접 실증·조회하는 쿼리 모음.
-- 대상: GN_DW.BRONZE_CRM, GN_DW.BRONZE_AGENCY, GN_DW.INFORMATION_SCHEMA
-- 주의: 조회(SELECT) 전용 쿼리이며 데이터를 변경하지 않습니다.
-- Co-authored with CoCo
-- =====================================================================

-- =====================================================================
-- SECTION 1. 지표 정의 및 산출 기준 확정
-- =====================================================================

-- [1-1. L-1] 중단 회원의 직전 발송 간격 및 당일 발송 상위 제목
-- 원천: BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC (중단) × TD_MS_MSG_AT_SNDNG_DTLS (발송)
WITH stop AS (
    SELECT mber_no, TO_DATE(spnsr_dscntc_de, 'YYYYMMDD') AS stop_date
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC
    WHERE spnsr_dscntc_de BETWEEN '20250101' AND '20251231'
), prev_send AS (
    SELECT
        x.mber_no,
        x.stop_date,
        MAX(TO_DATE(s.sndng_dt)) AS last_send_date
    FROM stop x
    JOIN GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS s
        ON s.mber_no = x.mber_no
       AND TO_DATE(s.sndng_dt) <= x.stop_date
    GROUP BY x.mber_no, x.stop_date
)
SELECT
    CASE
        WHEN DATEDIFF(day, last_send_date, stop_date) = 0 THEN '당일(D+0)'
        WHEN DATEDIFF(day, last_send_date, stop_date) BETWEEN 1 AND 5 THEN 'D+1~5'
        WHEN DATEDIFF(day, last_send_date, stop_date) BETWEEN 6 AND 10 THEN 'D+6~10'
        WHEN DATEDIFF(day, last_send_date, stop_date) BETWEEN 11 AND 30 THEN 'D+11~30'
        WHEN DATEDIFF(day, last_send_date, stop_date) BETWEEN 31 AND 90 THEN 'D+31~90'
        ELSE 'D+91 이상'
    END AS "발송_중단_간격",
    COUNT(*) AS "중단건수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS "비중_PCT"
FROM prev_send
GROUP BY 1
ORDER BY 2 DESC;

-- [1-2. L-1 부속] 당일 발송(D+0)의 상위 메시지 제목 (행정/통보성 메시지 식별)
SELECT
    m.tit AS "발송제목",
    COUNT(*) AS "당일발송건수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC x
JOIN GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS s
    ON s.mber_no = x.mber_no
   AND TO_CHAR(s.sndng_dt, 'YYYYMMDD') = x.spnsr_dscntc_de
JOIN GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG m
    ON m.sndng_key = s.sndng_key
WHERE x.spnsr_dscntc_de BETWEEN '20250101' AND '20251231'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- [1-3. L-2] 중단보고 후원사업: 끊은 사업(가) vs 최초 유입 사업(나) 대조
WITH acq AS (
    SELECT mber_no,
           MIN_BY(spnsr_bsns_id, occrrnc_de) AS acq_spnsr_bsns_id
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
    WHERE spnsr_bsns_id IS NOT NULL
    GROUP BY mber_no
)
SELECT
    bn.spnsr_bsns_nm AS "획득_후원사업_나",
    bs.spnsr_bsns_nm AS "중단_후원사업_가",
    COUNT(*) AS "약정건수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS b
JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s
    ON s.spnsr_no = b.spnsr_no
JOIN acq a
    ON a.mber_no = s.mber_no
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO bn
    ON bn.spnsr_bsns_id = a.acq_spnsr_bsns_id
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO bs
    ON bs.spnsr_bsns_id = b.spnsr_bsns_id
WHERE b.spnsr_dscntc_yn = 'Y'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 30;

-- [1-4. K-2] 행사 참여: 인원(고유 회원수) vs 횟수(총 참여기록 건수)
SELECT '일반행사 TD_MS_EVENT_PRTCPNT_DTL' AS "참여원천",
    COUNT(*) AS "총_횟수(기록수)",
    COUNT(DISTINCT mber_no) AS "고유_인원(회원수)",
    ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT mber_no), 0), 2) AS "1인당_평균참여횟수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
UNION ALL
SELECT '캠페인행사 TD_MS_CRMN_PRTCPNT',
    COUNT(*),
    COUNT(DISTINCT mber_no),
    ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT mber_no), 0), 2)
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT;

-- [1-5. N-11] CONF-3 월말활동회원 판정: 2025년 중단 이력 회원의 재후원/타사업 유지 현황
WITH stop_ev AS (
    SELECT mber_no, TO_DATE(spnsr_dscntc_de, 'YYYYMMDD') AS stop_dt, ser_no AS stop_ser_no
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC
    WHERE spnsr_dscntc_de BETWEEN '20250101' AND '20251231'
), spnsr_act AS (
    SELECT s.mber_no, b.spnsr_bsns_id, b.spnsr_dscntc_yn, b.spnsr_amt
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS b
      ON b.spnsr_no = s.spnsr_no
)
SELECT 
    COUNT(DISTINCT st.mber_no) AS "2025년_중단기록_회원수",
    COUNT(DISTINCT CASE WHEN sa.spnsr_dscntc_yn = 'N' THEN st.mber_no END) AS "중단후_타사업_또는_재후원_유지회원수",
    COUNT(DISTINCT CASE WHEN sa.spnsr_dscntc_yn = 'Y' THEN st.mber_no END) AS "전건중단_회원수"
FROM stop_ev st
LEFT JOIN spnsr_act sa ON sa.mber_no = st.mber_no;

-- [1-6. N-10] 회원 마스터 FRST_REGIST_DT 적재 현황 (정기회원 vs 일시회원)
SELECT '정기 TM_MM_FDRM_MBER_INFO.FRST_REGIST_DT' AS "회원유형",
       COUNT(*) AS "전체행수",
       COUNT(frst_regist_dt) AS "최초등록일_값있는행",
       MIN(frst_regist_dt) AS "최소등록일",
       MAX(frst_regist_dt) AS "최대등록일"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
UNION ALL
SELECT '일시 TM_MM_ONCE_MBER_INFO.FRST_REGIST_DT',
       COUNT(*),
       COUNT(frst_regist_dt),
       MIN(frst_regist_dt),
       MAX(frst_regist_dt)
FROM GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO;

-- [1-7. N-1~N-4, N-6-A] 개발목표 원천 데이터 적재 범위 (연도/개발구분/부서수)
SELECT
    stdyy AS "기준연도",
    mber_dvlp_div_cd AS "개발구분코드",
    COUNT(*) AS "행수",
    COUNT(DISTINCT dept_id) AS "부서수",
    COUNT(DISTINCT stdr_mt) AS "월수",
    SUM(goal_cnt) AS "목표건수_합계"
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL
GROUP BY 1, 2
ORDER BY 1 DESC, 2;


-- =====================================================================
-- SECTION 2. 코드 라벨 매핑 및 표기 통합
-- =====================================================================

-- [2-1. I-2] 행사 참여상태 및 특수문자 ')' 침투 행 확인
SELECT
    TO_CHAR(partcpt_dt, 'YYYY-MM-DD') AS "참여일",
    COUNT(*) AS "이상값행수",
    COUNT(DISTINCT mber_no) AS "관여회원수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE mber_no = ')' OR partcpt_chnnl_cd = ')' OR partcpt_path_cd = ')'
   OR partcpt_stat_cd = ')' OR rm = ')' OR rm2 = ')'
GROUP BY 1
ORDER BY 1;

-- [2-2. I-2 부속] S+8자리 비표준 회원번호 실재 여부
SELECT DISTINCT mber_no AS "S형식_회원번호"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE REGEXP_LIKE(mber_no, '^S[0-9]{8}$')
ORDER BY 1
LIMIT 20;

-- [2-3. M-2] 채널별 발송 마스터의 SNDNG_TY_CD(발신유형) 코드값 분포
SELECT 'EMAIL TM_MS_EMAIL_SNDNG' AS "채널", sndng_ty_cd AS "발신유형코드", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_MS_EMAIL_SNDNG GROUP BY 1, 2
UNION ALL
SELECT 'MSG_AT TM_MS_MSG_AT_SNDNG', sndng_ty_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG GROUP BY 1, 2
UNION ALL
SELECT 'PSTMTR TM_MS_PSTMTR_SNDNG', sndng_ty_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MS_PSTMTR_SNDNG GROUP BY 1, 2
ORDER BY 1, 2;

-- [2-4. M-4] 이메일 및 SND 발송결과 코드값 분포
SELECT 'EMAIL SNDNG_RST_CD' AS "채널축", sndng_rst_cd AS "코드값", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS GROUP BY 1, 2
UNION ALL
SELECT 'SND SND_YN', snd_yn, COUNT(*)
FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- [2-5. M-5] 통신사 전송실패코드 17종 중 공통코드 사전(MS056~MS059) 미등재 현황
SELECT 'MSG_AT TRNSMS_FAILR_CD_ID' AS "채널축", trnsms_failr_cd_id AS "코드", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS
WHERE trnsms_failr_cd_id IS NOT NULL
  AND trnsms_failr_cd_id NOT IN (
        SELECT dtl_cd_id FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
        WHERE cd_id IN ('MS056', 'MS057', 'MS058', 'MS059'))
GROUP BY 1, 2
UNION ALL
SELECT 'SND CALL_STATUS', call_status, COUNT(*)
FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST
WHERE call_status IS NOT NULL
  AND call_status NOT IN (
        SELECT dtl_cd_id FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
        WHERE cd_id IN ('MS056', 'MS057', 'MS058', 'MS059'))
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- [2-6. N-8] MKTG_UTM 고아코드 192번 캠페인 점유율
SELECT
    c.mktg_utm AS "캠페인_UTM코드",
    u.mk_utm_nm AS "사전_라벨",
    CASE WHEN u.mk_utm IS NULL THEN '🔴 사전 미등재(고아)' ELSE '정상 매칭' END AS "사전등재여부",
    COUNT(*) AS "캠페인수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS "비율_PCT"
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM u
    ON u.mk_utm = c.mktg_utm
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- [2-7. H-3] 성별 원천값 및 CM017 코드 매핑
SELECT
    m.sex AS "성별_원천값",
    d.dtl_cd_nm AS "CM017_라벨",
    COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO m
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d
    ON d.cd_id = 'CM017' AND d.dtl_cd_id = m.sex
GROUP BY 1, 2
ORDER BY 3 DESC;


-- =====================================================================
-- SECTION 3. 파이프라인 및 정합성 검증 (dbt 의심 데이터)
-- =====================================================================

-- [3-1. A] 회비월(MBRFEE_MT) 자리수 및 5자리 비정상 값 실측
SELECT
    LENGTH(mbrfee_mt) AS "자리수",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mbrfee_mt) AS "값종류수",
    MIN(mbrfee_mt) AS "최소값",
    MAX(mbrfee_mt) AS "최대값"
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
GROUP BY 1
ORDER BY 1;

-- [3-2. A 부속] 5자리 및 범위 밖 회비월 상세 목록
SELECT
    mbrfee_mt AS "회비월_원천값",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mber_no) AS "회원수"
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
WHERE LENGTH(mbrfee_mt) <> 6
   OR mbrfee_mt < '199101'
   OR mbrfee_mt > '202607'
GROUP BY 1
ORDER BY 1;

-- [3-3. E] 행사 참여 외래키 고아행(행사 마스터 부재) 비율
SELECT '일반행사 TD_MS_EVENT_PRTCPNT_DTL' AS "참여원천",
    COUNT(*) AS "참여행_전체",
    COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) AS "고아행_마스터부재",
    ROUND(COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS "고아비율_PCT"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_EVENT e
    ON p.event_cd = e.event_cd
UNION ALL
SELECT '캠페인행사 TD_MS_CRMN_PRTCPNT',
    COUNT(*),
    COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END),
    ROUND(COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END) * 100.0 / COUNT(*), 2)
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_CRMN c
    ON p.crmn_cd = c.crmn_cd;

-- [3-4. B] 행사 참여 회원번호의 회원 마스터 부재 회원수
SELECT
    CASE
        WHEN REGEXP_LIKE(p.mber_no, '^[0-9]{7}$') THEN '정상 7자리 FDRM'
        WHEN REGEXP_LIKE(p.mber_no, '^S[0-9]{8}$') THEN 'ONCE S+8자리'
        WHEN LENGTH(p.mber_no) <= 2 THEN '짧은/비정상 ID'
        ELSE '기타'
    END AS "유형",
    COUNT(DISTINCT p.mber_no) AS "마스터부재_회원번호수",
    COUNT(*) AS "참여행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
WHERE NOT EXISTS (
        SELECT 1 FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO m
        WHERE m.mber_no = p.mber_no)
  AND NOT EXISTS (
        SELECT 1 FROM GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO o
        WHERE o.once_mber_no = p.mber_no)
GROUP BY 1
ORDER BY 2 DESC;

-- [3-5. D] 원천 값 100% NULL 컬럼 실측
SELECT 'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT' AS "대상",
       COUNT(*) AS "전체행수", COUNT(conv_call_cnt) AS "값있는행수"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
UNION ALL
SELECT 'BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG.TOT_CLICK_CNT_CTNT',
       COUNT(*), COUNT(tot_click_cnt_ctnt)
FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG;


-- =====================================================================
-- SECTION 4. ML 예측 요건 대조
-- =====================================================================

-- [4-1. F-1] 부서 계층 구조 및 본부/지부 명칭 분포
WITH RECURSIVE tree AS (
    SELECT d.dept_id, d.dept_nm, d.upper_dept_id, d.stats_dept_lvl, 1 AS lvl
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO d
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO p
        ON p.dept_id = d.upper_dept_id
    WHERE p.dept_id IS NULL
    UNION ALL
    SELECT d.dept_id, d.dept_nm, d.upper_dept_id, d.stats_dept_lvl, t.lvl + 1
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO d
    JOIN tree t ON d.upper_dept_id = t.dept_id
)
SELECT
    lvl AS "트리레벨",
    COUNT(*) AS "부서수",
    COUNT(CASE WHEN dept_nm LIKE '%본부%' THEN 1 END) AS "본부_명칭포함",
    COUNT(CASE WHEN dept_nm LIKE '%지부%' THEN 1 END) AS "지부_명칭포함",
    COUNT(DISTINCT stats_dept_lvl) AS "STATS_DEPT_LVL_값종류"
FROM tree
GROUP BY lvl
ORDER BY lvl;

-- [4-2. F-2] 후원사업 약어코드 및 후원구분코드 분포
SELECT
    spnsr_bsns_abrv_cd AS "사업약어코드",
    spnsr_div_cd AS "후원구분코드",
    COUNT(*) AS "사업수",
    LISTAGG(spnsr_bsns_id || '=' || spnsr_bsns_nm, ' · ')
        WITHIN GROUP (ORDER BY spnsr_bsns_id) AS "소속사업_목록"
FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
GROUP BY 1, 2
ORDER BY 1, 2;

-- [4-3. F-3] 이메일 오픈 데이터 부재 실측 (전건 0/NULL)
SELECT 'EMAIL 오픈 URL_OTHBC_CNT_CTNT' AS "항목",
    COUNT(*) AS "전체행수",
    COUNT(url_othbc_cnt_ctnt) AS "값있는행",
    COUNT(CASE WHEN TRY_TO_NUMBER(url_othbc_cnt_ctnt) > 0 THEN 1 END) AS "0초과행"
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG
UNION ALL
SELECT 'EMAIL 오픈율 URL_OTHBC_RT_CTNT',
    COUNT(*),
    COUNT(url_othbc_rt_ctnt),
    COUNT(CASE WHEN TRY_TO_NUMBER(url_othbc_rt_ctnt) > 0 THEN 1 END)
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG;

-- [4-4. F-5] 공휴일/근무일 캘린더 원천 테이블 입고 여부 (0행 확인)
SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE%'
  AND (table_name LIKE '%HOLIDAY%' OR table_name LIKE '%CALENDAR%'
    OR table_name LIKE '%HLDY%' OR table_name LIKE '%WORKDAY%')
ORDER BY 1, 2;


-- =====================================================================
-- SECTION 5. 대행사 광고 실적 및 초수 단위
-- =====================================================================

-- [5-1. AD-2] 디지털 광고 개발건수(CRM_DVLP_CNT) 소수점 유입 실측
SELECT
    COUNT(*) AS "값있는행수",
    COUNT(CASE WHEN crm_dvlp_cnt <> FLOOR(crm_dvlp_cnt) THEN 1 END) AS "소수점보유행수",
    ROUND(COUNT(CASE WHEN crm_dvlp_cnt <> FLOOR(crm_dvlp_cnt) THEN 1 END) * 100.0 / COUNT(*), 1) AS "소수점비율_PCT",
    MIN(crm_dvlp_cnt) AS "최소값",
    MAX(crm_dvlp_cnt) AS "최대값"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
WHERE crm_dvlp_cnt IS NOT NULL;

-- [5-2. AD-3] 2026-06 이후 개발건수(CRM_DVLP_CNT) ➔ 단가(DEV_UNIT_PRICE) 포맷 교체 실측
SELECT
    TO_CHAR(date, 'YYYY-MM') AS "기간",
    COUNT(*) AS "전체행수",
    COUNT(crm_dvlp_cnt) AS "개발건수_값있는행",
    COUNT(dev_unit_price) AS "단가_값있는행"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
WHERE date >= '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- [5-3. AD-5] 방송광고(VIDEO) 테이블 내 개발건수/전환수 보유 현황
SELECT
    COUNT(*) AS "전체행수",
    COUNT(conv_call_cnt) AS "전환콜_값있는행",
    COUNT(inbound_call_cnt) AS "인바운드콜_값있는행",
    SUM(actl_pur_ad_cost_krw) AS "총광고비"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

-- [5-4. N-12] 대행사 3개 테이블의 매체명/채널 상위 분포
SELECT 'DGT MEDIA_NM' AS "축", media_nm AS "매체명", COUNT(*) AS "건수"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
GROUP BY 1, 2
UNION ALL
SELECT 'VIDEO CHNNL_NM', chnnl_nm, COUNT(*)
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
GROUP BY 1, 2
UNION ALL
SELECT 'REBRDC CHNNL_CMPNY', chnnl_cmpny, COUNT(*)
FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS
GROUP BY 1, 2
ORDER BY 1, 3 DESC
LIMIT 30;

-- [5-5. J-2] 방송 광고 초수(AD_SEC) 숫자 및 시분초 혼재 표기 확인
SELECT
    CASE WHEN ad_sec LIKE '%:%' THEN '시:분:초 표기' ELSE '숫자 표기' END AS "표기방식",
    ad_sec AS "원천값",
    COUNT(*) AS "건수"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
WHERE ad_sec IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- =====================================================================
-- SECTION 6. 시점 동결(Snapshot) 적용
-- =====================================================================

-- [6-1. N-9] 캠페인 마스터의 최종변경일 및 캠페인별 획득 회원수 (이력 테이블 부재 실측)
SELECT
    c.cmpgn_cd AS "캠페인코드",
    c.cmpgn_nm AS "캠페인명_현재값",
    TO_CHAR(c.last_updt_dt, 'YYYY-MM-DD') AS "마스터_최종변경일",
    COUNT(DISTINCT s.mber_no) AS "획득회원수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s
JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
    ON c.cmpgn_cd = s.cmpgn_cd
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 30;

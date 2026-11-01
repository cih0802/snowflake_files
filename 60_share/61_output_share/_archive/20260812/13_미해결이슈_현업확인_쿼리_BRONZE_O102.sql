-- 미해결이슈_요약_O102.md 각 항목을 BRONZE 원천만으로 재확인하는 검증 쿼리 모음
-- Co-authored with CoCo
--
-- 목적: SILVER/GOLD 변환 로직을 거치지 않고 BRONZE 원천 테이블·컬럼을 직접 조회해
--       현업이 "우리 운영 시스템의 값" 그대로 대조할 수 있게 한다.
--       (SILVER/GOLD 판은 12_미해결이슈_현업확인_쿼리_O102.sql 참조)
-- 사용법: 각 섹션 제목의 문서좌표(예: 20-001:61~104)로 원문 질의를 대조하고,
--         결과를 캡처해 회신 요청 문서에 첨부한다.
-- 주의: 확인용 SELECT 뿐이며 데이터를 변경하지 않는다.
-- 원천 매핑·컬럼명·자료형은 2026-08-26 BRONZE 실측으로 확정했다.
-- 한글 별칭은 Snowflake 식별자 규칙상 큰따옴표로 인용한다.
--
-- ■ BRONZE 실측에서 새로 드러난 사실 (SILVER/GOLD 판에는 보이지 않던 것)
--   · 회비월 `TM_PM_MBRFEE_ACMSLT.MBRFEE_MT` 는 TEXT 이고 **5자리 값 9종
--     ('20251'~'20259') 2,274행**이 있다(zero-padding 누락) · 6자리는 252종
--     범위 190001~202911 · 46,389,346행.
--   · 개발일 `TM_MM_FDRM_MBER_DVLP_AMT.OCCRRNC_DE` 는 YYYYMMDD TEXT 이고
--     실측 범위가 **19000101 ~ 99991231**(센티넬 추정)이다.
--   · 목표 원천이 BRONZE 에 **실재**한다 — `TM_CM_MBER_DVLP_GOAL` 25,344행
--     (부서×연월 목표건수). 반면 `SILVER.CRM_BIZ_TARGET` 은 **0행**이다.
--   ⇒ 위 3건은 값 그대로의 사실이며, 원인·해석은 현업 회신 전까지 단정하지 않는다.

-- =====================================================================
-- A. 회비월 비정상 — 20-001:56~61
-- BRONZE 원천: TM_PM_MBRFEE_ACMSLT.MBRFEE_MT (TEXT)
-- 질문: 5자리 '20251'~'20259' 는 2025년 1~9월인가? 190001·202911 은 유효한가?
-- =====================================================================
SELECT
    LENGTH(mbrfee_mt) AS "자리수",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mbrfee_mt) AS "값종류수",
    MIN(mbrfee_mt) AS "최소값",
    MAX(mbrfee_mt) AS "최대값"
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
GROUP BY 1
ORDER BY 1;

-- 범위밖·비정상 회비월 전건 목록
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

-- =====================================================================
-- B. 회원번호 마스터 부재 — 20-001:63~73
-- BRONZE 원천: TD_MS_EVENT_PRTCPNT_DTL.MBER_NO vs 회원 마스터 2종
--              (TM_MM_FDRM_MBER_INFO.MBER_NO · TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO)
-- 질문: 마스터에 없는 회원번호가 실회원인가(스냅샷 누락), 폐기 대상인가?
-- =====================================================================
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

-- =====================================================================
-- C. 캘린더(1991~2035) 범위밖 날짜 — 20-001:75~78
-- BRONZE 원천 3경로: 개발 OCCRRNC_DE · 후원중단 SPNSR_DSCNTC_DE · 참여 PARTCPT_DT
-- 질문: 19000101·99991231 은 센티넬인가 실제 값인가? 2030년 이후는 예약일정인가?
-- =====================================================================
SELECT '개발 TM_MM_FDRM_MBER_DVLP_AMT.OCCRRNC_DE' AS "원천", occrrnc_de AS "날짜값",
       COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
WHERE occrrnc_de < '19910101' OR occrrnc_de > '20351231'
GROUP BY 1, 2
UNION ALL
SELECT '후원중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE', spnsr_dscntc_de,
       COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC
WHERE spnsr_dscntc_de < '19910101' OR spnsr_dscntc_de > '20351231'
GROUP BY 1, 2
UNION ALL
SELECT '참여 TD_MS_EVENT_PRTCPNT_DTL.PARTCPT_DT', TO_CHAR(partcpt_dt, 'YYYY-MM-DD'),
       COUNT(*)
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE partcpt_dt < '1991-01-01' OR partcpt_dt > '2035-12-31'
GROUP BY 1, 2
ORDER BY 1, 2;

-- =====================================================================
-- D. 원천 값 전무(100% NULL) 컬럼 — 20-001:80~89
-- 원문 5행의 dbt 모델(models/silver/**/*.sql) 리니지를 실제로 열어 확인한 참 매핑.
-- 🔴 [정정] 이전 판(초판)은 컬럼명을 추정으로 대응시켰다가 3건이 틀렸다 —
--    CRM_CAMPAIGN.MKTG_CMPGN_NM 의 진짜 BRONZE 소스는 TM_CM_CMPGN_MNG.MKTG_CMPGN_NM
--    으로 이름은 같았지만, AGENCY_AD_PERFORMANCE.CONV_CALL_CNT 의 진짜 소스는
--    DGT_AD_CMPGN_DTLS.GA_CONV_MBER_CNT 가 **아니라** VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT
--    였다(DIGITAL·REBROADCAST 분기는 모델이 CAST(NULL) 로 하드코딩 — AGENCY_AD_PERFORMANCE.sql
--    L33·L64 참조. VIDEO 분기만 진짜 컬럼을 그대로 옮긴다 · L95).
--    CRM_BIZ_TARGET 의 대응도 TM_CM_MBER_DVLP_GOAL 이 아니라 **원천 자체가 없다**
--    (CRM_BIZ_TARGET.sql 은 `WHERE 1=0` 스키마-only 스텁 — 참조하는 BRONZE 테이블이 코드에 없다.
--    TM_CM_MBER_DVLP_GOAL 은 이름이 비슷한 「부서 개발목표」 테이블일 뿐 이 모델이 참조하지 않는다).
-- 🟢 [실측 2026-08-26] 아래 재확인 결과 원문 5행 중 **2행은 이미 해소되어 stale 하다**:
--    · CRM_CAMPAIGN 5개 컬럼(CMPGN_CTGR_CD 등) — 현재 SILVER 33,918~34,032/36,163 값 보유
--      (2026-08-25 O101 재입고로 채워짐 — 원문 작성 시점 이후 해소, 판정 문구 갱신 필요)
--    · GA4_DEVICE.BROWSER — 현재 SILVER 1,165/1,173 값 보유(모델 L94: DEVICE_WEB_INFO_BROWSER
--      passthrough) — 이미 해소
--    남은 진짜 100% NULL 은 **CONV_CALL_CNT·TOT_CLICK_CNT·CRM_BIZ_TARGET 3건뿐**이다.
-- 질문: 원천 보유하는데 추출 누락인가, 원천 미수집인가?
-- =====================================================================
-- ① AGENCY_AD_PERFORMANCE.CONV_CALL_CNT 의 진짜 BRONZE 소스(VIDEO 분기만 유효)
SELECT 'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT' AS "대상",
       COUNT(*) AS "전체행수", COUNT(conv_call_cnt) AS "값있는행수"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
UNION ALL
-- ② CRM_SEND_RESULT.TOT_CLICK_CNT 의 진짜 BRONZE 소스(MSG_AT 분기만 유효)
SELECT 'BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG.TOT_CLICK_CNT_CTNT',
       COUNT(*), COUNT(tot_click_cnt_ctnt)
FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG
UNION ALL
-- ③ CRM_BIZ_TARGET — 참조 BRONZE 자체가 코드에 없다(스텁 모델). 존재 여부만 확인용
SELECT 'BRONZE 참조없음(CRM_BIZ_TARGET.sql=WHERE 1=0 스텁)',
       NULL, NULL
UNION ALL
-- ④ 참고: CRM_CAMPAIGN 5컬럼의 진짜 소스(이미 해소됐는지 BRONZE 원본으로 재확인)
SELECT 'BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CMPGN_NM(참고·이미해소)',
       COUNT(*), COUNT(mktg_cmpgn_nm)
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
UNION ALL
-- ⑤ 참고: GA4_DEVICE.BROWSER 의 진짜 소스(이미 해소됐는지 재확인)
SELECT 'SILVER.BIGQUERY_REFINED_DATA.DEVICE_WEB_INFO_BROWSER(참고·이미해소)',
       COUNT(*), COUNT(device_web_info_browser)
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA;

-- =====================================================================
-- E. 참조 무결성 gap (최우선) — 20-001:92~104
-- BRONZE 원천: 일반행사 TD_MS_EVENT_PRTCPNT_DTL.EVENT_CD vs TM_MS_EVENT.EVENT_CD
--              캠페인행사 TD_MS_CRMN_PRTCPNT.CRMN_CD vs TM_MS_CRMN.CRMN_CD
-- 질문: 행사 마스터 추출 범위/시점 문제가 맞는가? 마스터 없는 참여가 유효한가?
-- =====================================================================
SELECT '일반행사 TD_MS_EVENT_PRTCPNT_DTL' AS "참여원천",
    COUNT(*) AS "참여행_전체",
    COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) AS "고아행_마스터부재",
    ROUND(COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) * 100.0
        / COUNT(*), 2) AS "고아비율_PCT"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_EVENT e
    ON p.event_cd = e.event_cd
UNION ALL
SELECT '캠페인행사 TD_MS_CRMN_PRTCPNT',
    COUNT(*),
    COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END),
    ROUND(COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END) * 100.0
        / COUNT(*), 2)
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_CRMN c
    ON p.crmn_cd = c.crmn_cd;

-- =====================================================================
-- D(코드매핑). SV 코드→라벨 매핑 SVL-1~4 — 20-001:113~121
-- BRONZE 원천: 코드사전 TC_CMMN_CD(코드군) · TC_CMMN_DTL_CD(상세코드)
-- 질문: SNDNG_TY_CD·SNDNG_RST_CD·EVENT_DIV_CD 의 정확한 CD_ID 는?
-- =====================================================================
-- 실측 도메인(코드값)을 먼저 확정한다
SELECT 'EMAIL SNDNG_TY_CD' AS "축", sndng_ty_cd AS "코드값", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_MS_EMAIL_SNDNG GROUP BY 1, 2
UNION ALL
SELECT 'EMAIL SNDNG_RST_CD', sndng_rst_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS GROUP BY 1, 2
UNION ALL
SELECT '일반행사 EVENT_DIV_CD', event_div_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MS_EVENT GROUP BY 1, 2
ORDER BY 1, 2;

-- 그 도메인을 포함하는 코드군 후보를 사전에서 역추적한다
SELECT
    d.cd_id AS "코드군ID",
    c.cd_nm AS "코드군명",
    COUNT(*) AS "상세코드수",
    LISTAGG(d.dtl_cd_id || '=' || d.dtl_cd_nm, ' · ')
        WITHIN GROUP (ORDER BY d.sort_ordr) AS "코드_라벨"
FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_CD c
    ON d.cd_id = c.cd_id
WHERE d.cd_id IN ('MS282', 'MS303', 'MS304', 'MS004', 'MS006', 'CM017')
GROUP BY 1, 2
ORDER BY 1;

-- =====================================================================
-- AD-2. CRM 개발건수 소수값 — 20-001:130~142
-- BRONZE 원천: DGT_AD_CMPGN_DTLS.CRM_DVLP_CNT (대행사 제공 원본)
-- 질문: 실제 "건수"인가, 매체별 기여도 배분값인가? 정수 반올림 가능한가?
-- =====================================================================
SELECT
    COUNT(*) AS "값있는행수",
    COUNT(CASE WHEN crm_dvlp_cnt <> FLOOR(crm_dvlp_cnt) THEN 1 END) AS "소수행수",
    ROUND(COUNT(CASE WHEN crm_dvlp_cnt <> FLOOR(crm_dvlp_cnt) THEN 1 END)
        * 100.0 / COUNT(*), 1) AS "소수비율_PCT",
    MIN(crm_dvlp_cnt) AS "최소값",
    MAX(crm_dvlp_cnt) AS "최대값",
    SUM(crm_dvlp_cnt) AS "합계"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
WHERE crm_dvlp_cnt IS NOT NULL;

-- =====================================================================
-- AD-3. 2026-06부터 개발건수→단가 대체 — 20-001:144~163
-- BRONZE 원천: DGT_AD_CMPGN_DTLS.CRM_DVLP_CNT · DEV_UNIT_PRICE · DATE
-- 질문: 원천 포맷 변경이 의도된 것인가? 개발건수 재제공 vs 단가 채택?
-- =====================================================================
SELECT
    TO_CHAR(date, 'YYYY-MM') AS "기간",
    COUNT(*) AS "전체행수",
    COUNT(crm_dvlp_cnt) AS "개발건수_값있는행",
    COUNT(dev_unit_price) AS "대행사단가_값있는행"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
WHERE date >= '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- AD-5. VIDEO 광고 개발실적 원천 부재 — 20-001:180~198
-- BRONZE 원천: VIDEO_AD_CMPGN_DTLS (개발건수 컬럼 자체가 없음)
-- 질문: 비디오는 개발실적을 원래 집계하지 않는 것이 맞는가?
-- =====================================================================
SELECT
    COUNT(*) AS "전체행수",
    COUNT(conv_call_cnt) AS "전환콜_값있는행",
    COUNT(inbound_call_cnt) AS "인바운드콜_값있는행",
    SUM(actl_pur_ad_cost_krw) AS "비디오_총광고비"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

-- =====================================================================
-- F-1. 신규본부/신규지부 축 부재 — 20-002:10~29
-- BRONZE 원천: TM_CM_DEPT_INFO (DEPT_ID·DEPT_NM·UPPER_DEPT_ID·STATS_DEPT_LVL)
-- 질문: 본부/지부 구별 기준은? 조직유형 코드가 있는가, 명칭으로만 판별하는가?
-- =====================================================================
-- 루트 실측: UPPER_DEPT_ID 가 테이블에 없는 부모를 가리키는 9행
--            ('A000000' 5행 · 'ZV000000' 4행) — NULL 부모는 존재하지 않는다.
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

-- =====================================================================
-- F-2. 후원사업 그룹 — 4그룹 매핑과 "총 11개" 기준 — 20-002:31~57
-- BRONZE 원천: TM_CM_SPNSR_BSNS_INFO (SPNSR_BSNS_ABRV_CD = 약어/그룹코드)
-- 질문: 약어코드의 코드군 ID 는? 4(대북)/6(해외사례)는 어느 그룹인가?
--       "총 11개" 예측대상 사업 목록은?
-- =====================================================================
SELECT
    spnsr_bsns_abrv_cd AS "사업약어코드",
    spnsr_div_cd AS "후원구분코드",
    COUNT(*) AS "사업수",
    LISTAGG(spnsr_bsns_id || '=' || spnsr_bsns_nm, ' · ')
        WITHIN GROUP (ORDER BY spnsr_bsns_id) AS "소속사업_목록"
FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
GROUP BY 1, 2
ORDER BY 1, 2;

-- =====================================================================
-- F-3. 발송 오픈 — C-9 폐기 결정을 되돌려야 하는가 (최우선) — 20-002:59~83
-- BRONZE 원천: 이메일 오픈 TD_MS_EMAIL_LQY_SNDNG.URL_OTHBC_CNT_CTNT
--              알림톡 클릭 TD_MS_MSG_AT_LQY_SNDNG.TOT_CLICK_CNT_CTNT
-- 질문: 오픈 로그 추출 경로가 있는가? 클릭으로 대체 가능한가?
-- =====================================================================
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
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG
UNION ALL
SELECT 'MSG_AT 클릭 TOT_CLICK_CNT_CTNT',
    COUNT(*),
    COUNT(tot_click_cnt_ctnt),
    COUNT(CASE WHEN TRY_TO_NUMBER(tot_click_cnt_ctnt) > 0 THEN 1 END)
FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_LQY_SNDNG;

-- =====================================================================
-- F-4. 예측 등급 산출식 — 20-002:85~98
-- (업무 규칙 확정 항목 — 실측만으로는 답이 나오지 않는다)
-- BRONZE 원천: TM_MM_FDRM_MBER_INFO.MBER_STAT_CD (상태 원천값 그대로)
-- =====================================================================
SELECT
    mber_stat_cd AS "회원상태코드",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mber_no) AS "회원수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- F-5. 공휴일 캘린더 — 20-002:100~111
-- 🔴 BRONZE 원천 없음 — 공휴일·근무일 원천 테이블이 입고되어 있지 않다.
-- 질문: 사내 근무 캘린더(공휴일 목록) 원천을 제공해 주실 수 있는가?
--       (아래는 입고 여부 확인용 — 결과 0행이면 원천 부재 확정)
-- =====================================================================
SELECT table_schema, table_name
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema LIKE 'BRONZE%'
  AND (table_name LIKE '%HOLIDAY%' OR table_name LIKE '%CALENDAR%'
    OR table_name LIKE '%HLDY%' OR table_name LIKE '%WORKDAY%')
ORDER BY 1, 2;

-- =====================================================================
-- H-3. 성별축 코드그룹 CM017 확정 여부 — 20-002:153~160
-- BRONZE 원천: TM_MM_FDRM_MBER_INFO.SEX × 코드사전 CM017
-- 질문: 성별 라벨축을 CM017 로 확정해도 되는가? SEX 결측은 업무상 의미가 있는가?
-- =====================================================================
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
-- I-2. 특수문자(점검도구) 유입 흔적 — 20-003:111~123
-- BRONZE 원천: TD_MS_EVENT_PRTCPNT_DTL (6개 컬럼에 걸친 ')' 값)
-- 질문: 해당 날짜에 보안점검·외부진단 이력이 있는가? S+8자리 체계가 쓰이는가?
-- =====================================================================
SELECT
    TO_CHAR(partcpt_dt, 'YYYY-MM-DD') AS "참여일",
    COUNT(*) AS "이상값행수",
    COUNT(DISTINCT mber_no) AS "관여회원수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE mber_no = ')'
   OR partcpt_chnnl_cd = ')'
   OR partcpt_path_cd = ')'
   OR partcpt_stat_cd = ')'
   OR rm = ')'
   OR rm2 = ')'
GROUP BY 1
ORDER BY 1;

-- S+8자리 회원번호 체계 실재 여부
SELECT DISTINCT mber_no AS "S형식_회원번호"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE REGEXP_LIKE(mber_no, '^S[0-9]{8}$')
ORDER BY 1;

-- =====================================================================
-- J-2. 광고 초수(방송) 단위 — 20-003:155~163
-- BRONZE 원천: VIDEO_AD_CMPGN_DTLS.AD_SEC (두 표기 혼재 원본)
-- 질문: 30000000/60000000/90000000 은 각 30/60/90초인가?
-- =====================================================================
SELECT
    CASE WHEN ad_sec LIKE '%:%' THEN '시:분:초 표기' ELSE '숫자 표기' END AS "표기방식",
    ad_sec AS "원천값",
    COUNT(*) AS "건수"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
WHERE ad_sec IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- =====================================================================
-- K-2. 「인원」 vs 「횟수」 구분 — 20-004:8~29
-- BRONZE 원천: 일반행사 TD_MS_EVENT_PRTCPNT_DTL · 캠페인행사 TD_MS_CRMN_PRTCPNT
-- 질문: 인원=사람수(중복제거) / 횟수=기록수 로 구분이 맞는가?
--       "누적신청 횟수"의 누적 기준은?
-- =====================================================================
SELECT '일반행사 TD_MS_EVENT_PRTCPNT_DTL' AS "참여원천",
    COUNT(*) AS "횟수_기록수",
    COUNT(DISTINCT mber_no) AS "인원_회원수",
    COUNT(DISTINCT mber_no || '-' || event_cd) AS "회원행사쌍수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
UNION ALL
SELECT '캠페인행사 TD_MS_CRMN_PRTCPNT',
    COUNT(*),
    COUNT(DISTINCT mber_no),
    COUNT(DISTINCT mber_no || '-' || crmn_cd)
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT;

-- =====================================================================
-- L-1. 「발송 후 반응」 귀속 발송 구분 (최우선) — 20-004:46~98
-- BRONZE 원천: 발송 TD_MS_MSG_AT_SNDNG_DTLS.SNDNG_DT (+제목 TM_MS_MSG_AT_SNDNG.TIT)
--              중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE (YYYYMMDD TEXT)
-- 🟢 [O103 재검토] 원문 L 항목은 GOLD 서술뿐이나 SILVER CRM_MEMBER_DISCONTINUE.sql
--    리니지를 열어 대조 완료 — 소스가 정확히 TM_MM_FDRM_MBER_SPNSR_DSCNTC 다(models/
--    silver/crm/CRM_MEMBER_DISCONTINUE.sql L20 `source('bronze_crm','TM_MM_FDRM_MBER_SPNSR_DSCNTC')`).
-- 질문: 처리통보성 발송을 제외해야 하는가? 귀속기간 D+5 가 맞는가? 채널별로 다른가?
-- =====================================================================
-- 중단 1건당 「직전 발송」과의 간격 (중단 이전 발송만 대상)
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

-- 「당일 발송」의 제목 상위 — 처리통보성 vs 캠페인성 판별용
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

-- =====================================================================
-- L-2. 중단보고 「후원사업」 — 끊은 사업(가) vs 데려온 사업(나) — 20-004:100~115
-- BRONZE 원천: (가) TM_MM_FDRM_MBER_SPNSR_BSNS(SPNSR_DSCNTC_YN='Y')
--              (나) TM_MM_FDRM_MBER_DVLP_AMT 최초 개발행의 SPNSR_BSNS_ID
--              연결 TM_MM_FDRM_MBER_SPNSR(SPNSR_NO→MBER_NO) · 명칭 TM_CM_SPNSR_BSNS_INFO
-- 🟢 [O103 재검토] (가)는 CRM_MEMBER_SPONSOR_SPAN.sql(L27~46) 리니지와 정확히 일치
--    확인(bz=CRM_MEMBER_SPONSOR_BIZ ← TM_MM_FDRM_MBER_SPNSR_BSNS, MBER_NO 연결도 동일).
-- ⚠️ (나)는 근사다 — 실제 GOLD DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK 는
--    FACT_MEMBER_COHORT 경유이고, 그 우선순위는 ①MM015 코드1(신규) ②없으면 최초개발
--    사건(FALLBACK)이다(FACT_MEMBER_COHORT.sql L60·84). 아래는 ②만 근사(MIN_BY 최초행)
--    했고 ①신규 판정(MM015)은 반영하지 않았다 — 회신 요청 전 정확한 값 재계산 필요.
-- 질문: 중단 보고서 후원사업은 (가) 끊은 사업인가, (나) 데려온 사업인가?
-- =====================================================================
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
LIMIT 50;

-- =====================================================================
-- M-2. 발송 SUBTYPE(발신유형) 코드군 부재 — 20-005:65~81
-- BRONZE 원천: 채널별 발송 마스터의 SNDNG_TY_CD (SND 채널은 컬럼 자체가 없음)
-- 질문: 채널별 발신유형 코드값이 각각 무엇인가?
-- =====================================================================
SELECT 'EMAIL TM_MS_EMAIL_SNDNG' AS "채널", sndng_ty_cd AS "발신유형코드",
       COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_MS_EMAIL_SNDNG GROUP BY 1, 2
UNION ALL
SELECT 'MSG_AT TM_MS_MSG_AT_SNDNG', sndng_ty_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG GROUP BY 1, 2
UNION ALL
SELECT 'PSTMTR TM_MS_PSTMTR_SNDNG', sndng_ty_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_MS_PSTMTR_SNDNG GROUP BY 1, 2
ORDER BY 1, 2;

-- =====================================================================
-- M-4. 이메일·SND 발송결과 라벨 사전 미등재 — 20-005:108~125
-- BRONZE 원천: TD_MS_EMAIL_SNDNG_DTLS.SNDNG_RST_CD · SND_MEMBER_LIST.SND_YN
-- 질문: 두 채널의 코드값을 현업 화면·보고서에서 무엇이라 부르는가?
-- =====================================================================
SELECT 'EMAIL SNDNG_RST_CD' AS "채널축", sndng_rst_cd AS "코드값", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS
GROUP BY 1, 2
UNION ALL
SELECT 'SND SND_YN', snd_yn, COUNT(*)
FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- =====================================================================
-- M-5. 통신사 발송결과 코드 17종 사전 미등재 — 20-005:127~146
-- BRONZE 원천: TD_MS_MSG_AT_SNDNG_DTLS.TRNSMS_FAILR_CD_ID · SND_MEMBER_LIST.CALL_STATUS
--              사전 TC_CMMN_DTL_CD (MS056~MS059)
-- 질문: 미등재 코드의 뜻은? SND 한 자리 코드가 다른 체계인가?
-- =====================================================================
SELECT 'MSG_AT TRNSMS_FAILR_CD_ID' AS "채널축", trnsms_failr_cd_id AS "코드",
       COUNT(*) AS "행수"
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

-- =====================================================================
-- M-6. 「발송상태2」가 원천의 어느 컬럼인가 — 20-005:150~180
-- BRONZE 원천: 채널별 「상태성」 컬럼 개수가 다르다는 것을 원천에서 직접 확인
-- 질문: 발송상태2 = 전송실패코드/통화상태(축B)인가? 다른 컬럼인가? 폐기 필드인가?
-- =====================================================================
SELECT table_name AS "원천테이블", column_name AS "상태성컬럼", data_type AS "자료형"
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'BRONZE_CRM'
  AND table_name IN ('TD_MS_MSG_AT_SNDNG_DTLS', 'SND_MEMBER_LIST',
                     'TD_MS_EMAIL_SNDNG_DTLS', 'TD_MS_PSTMTR_SNDNG_DTL')
  AND (column_name LIKE '%STAT%' OR column_name LIKE '%RST%'
    OR column_name LIKE '%FAILR%' OR column_name = 'SND_YN')
ORDER BY 1, 2;

-- =====================================================================
-- N-1 · N-4. 목표 지표 원천 — 20-006:4~19, 69~85
-- 🟢 BRONZE 에 목표 원천이 실재한다: TM_CM_MBER_DVLP_GOAL (25,344행)
--    (STDYY 기준연도 · STDR_MT 기준월 · MBER_DVLP_DIV_CD 개발구분 · DEPT_ID 부서
--     · GOAL_CNT 목표건수) — 부서×연월 grain 이고 (원) 단위·후원사업축은 없다.
-- 질문: 「월 목표(건)」과 「연사업목표(건)」이 이 한 테이블의 같은 값인가?
--       (원) 단위 목표(171·172)·활동회원 목표(166·167)의 원천은 무엇인가?
-- =====================================================================
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
-- N-2. 단위/축 보완 10건 — 기존 번호 대체 여부 — 20-006:21~43
-- BRONZE 원천: TM_MM_FDRM_MBER_INFO (MBER_STAT_CD · STDR_DE 상태기준일)
-- ⚠️ 「월말 활동회원」은 as-of 시점 판정 로직이 필요하다 — BRONZE 원천만으로는
--    상태변경 이력 분포까지만 보인다(그 판정이 SILVER 로직의 본체다).
-- 질문: 165(월말활동회원(명)) = 공156(활동(명)) 이 같은 정의인가?
-- =====================================================================
SELECT
    TO_CHAR(stdr_de, 'YYYY-MM') AS "상태기준월",
    mber_stat_cd AS "회원상태코드",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mber_no) AS "회원수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
WHERE stdr_de >= '2026-01-01'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- =====================================================================
-- N-3 · N-6-A. 캠페인 축 4건 (최우선) — 20-006:45~67, 20-007:10~20
-- BRONZE 원천: TM_CM_CMPGN_MNG (MBER_INFLOW_PATH_CD 개발인입경로 ·
--              CMPGN_CTGR_CD 캠페인카테고리 · CMPGN_TYPE1_BSN · CMPGN_TYPE2_BSN)
-- 질문: 신규규칙이 기존 축을 대체하는가? 「전체사업」·「기타」가 실재하는가?
-- =====================================================================
SELECT '개발인입경로 MBER_INFLOW_PATH_CD' AS "축", mber_inflow_path_cd AS "코드값",
       COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG GROUP BY 1, 2
UNION ALL
SELECT '캠페인카테고리 CMPGN_CTGR_CD', cmpgn_ctgr_cd, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG GROUP BY 1, 2
UNION ALL
SELECT '캠페인유형1 CMPGN_TYPE1_BSN', cmpgn_type1_bsn, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG GROUP BY 1, 2
UNION ALL
SELECT '캠페인유형2 CMPGN_TYPE2_BSN', cmpgn_type2_bsn, COUNT(*)
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- =====================================================================
-- N-8. MKTG_UTM 라벨 사전 미등재 — 고아코드 192 — 20-007:167~191
-- BRONZE 원천: TM_CM_CMPGN_MNG.MKTG_UTM (36,163행) vs TM_CM_MKTNG_UTM.MK_UTM (191행)
-- 질문: MK_UTM=192 는 사전등재 누락인가, "UTM 없음" 센티넬인가?
--       센티넬이면 NULL 로 정규화해도 되는가?
-- =====================================================================
SELECT
    c.mktg_utm AS "캠페인_UTM코드",
    u.mk_utm_nm AS "사전_라벨",
    CASE WHEN u.mk_utm IS NULL THEN '🔴 사전 미등재(고아)' ELSE '정상 매칭' END
        AS "사전등재여부",
    COUNT(*) AS "캠페인수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS "비율_PCT"
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM u
    ON u.mk_utm = c.mktg_utm
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- 사전 등재 코드 범위 확인 (191종 = 1~191 인지)
SELECT
    COUNT(*) AS "사전_등재건수",
    MIN(mk_utm) AS "최소코드",
    MAX(mk_utm) AS "최대코드"
FROM GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM;

-- =====================================================================
-- N-9. 캠페인명 시점 혼합 — 20-007:195~215
-- BRONZE 원천: 획득 캠페인 TM_MM_FDRM_MBER_SPNSR.CMPGN_CD (회원×약정 시점 기록)
--              캠페인명 현재값 TM_CM_CMPGN_MNG.CMPGN_NM (마스터 · 개칭되면 바뀜)
-- 🟢 [O103 재검토] 실제 문제 지점을 GOLD 리니지에서 확인 완료 —
--    DIM_MEMBER_ACQUISITION.sql L75 `cmp.CAMPAIGN_NAME as ACQ_CAMPAIGN_NAME` 가
--    `DIM_CAMPAIGN` 실시간 조인이고, 나머지 8속성(L74·76·77 등)은 `c.ACQ_*`
--    (FACT_MEMBER_COHORT 동결값) passthrough 다 — 문서 N-9 서술과 정확히 일치.
--    다만 아래 쿼리의 TM_MM_FDRM_MBER_SPNSR.CMPGN_CD 는 「획득 시점 캠페인」의 근사이며
--    FACT_MEMBER_COHORT 의 정확한 ACQ_CAMPAIGN_SK 산정 로직(NEW/FALLBACK 우선순위,
--    FACT_MEMBER_COHORT.sql L60·84)을 그대로 재현하지는 않는다.
-- 질문: CAMPAIGN_NAME 도 획득 시점 동결로 확장해야 하는가, 실시간 유지인가?
-- ⇒ BRONZE 에는 캠페인명 이력이 없다(마스터 1행 = 현재값). 즉 「과거 이름」은
--   원천에 남아 있지 않으므로, 동결하려면 획득 시점에 스냅샷을 떠야 한다.
-- =====================================================================
SELECT
    c.cmpgn_cd AS "캠페인코드",
    c.cmpgn_nm AS "캠페인명_현재값",
    TO_CHAR(c.last_updt_dt, 'YYYY-MM-DD') AS "마스터_최종변경일",
    COUNT(DISTINCT s.mber_no) AS "이_캠페인으로_획득된_회원수"
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR s
JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
    ON c.cmpgn_cd = s.cmpgn_cd
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 50;

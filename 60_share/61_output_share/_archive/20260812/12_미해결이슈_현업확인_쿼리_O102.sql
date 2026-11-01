-- 미해결이슈_요약_O102.md 각 항목을 현업에 재확인하기 위한 검증 쿼리 모음
-- Co-authored with CoCo
--
-- 목적: 20_현업확인_요청-001~007.md 에 등재된 회신 대기 항목을 현업에 보낼 때,
--       질문과 함께 "우리가 이렇게 실측했다"를 즉시 재현할 수 있는 쿼리를 동봉한다.
-- 사용법: 각 섹션 제목의 문서좌표(예: 20-001:61~104)로 원문 질의를 대조하고,
--         쿼리 결과를 캡처해 회신 요청 메일/문서에 첨부한다.
-- 주의: 아래는 확인용 SELECT 뿐이며 데이터를 변경하지 않는다.
-- 컬럼명은 2026-08-26 GN_DW.INFORMATION_SCHEMA.COLUMNS 실측으로 확정한 것이다.
-- 한글 별칭은 Snowflake 식별자 규칙상 큰따옴표로 인용해야 한다.

-- =====================================================================
-- A. 회비월(MONTH_KEY) 비정상 — 20-001:56~61
-- 질문: MONTH_KEY=0(141행) · 미래월 202608~202911(1,211행)의 처리가 맞는가?
-- =====================================================================
SELECT
    CASE
        WHEN month_key = 0 THEN 'MONTH_KEY=0'
        WHEN month_key BETWEEN 202608 AND 202911 THEN '미래월(202608~202911)'
        WHEN month_key BETWEEN 199101 AND 202607 THEN '정상범위(199101~202607)'
        ELSE '기타'
    END AS "구간",
    COUNT(*) AS "행수",
    COUNT(DISTINCT member_dk) AS "DISTINCT_회원수"
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- B. 회원번호(MEMBER_DK) 마스터 부재 — 20-001:63~73
-- 질문: 정상 7자리 FDRM(8,803) · ONCE S+8자리(206) · 짧은/비정상 ID(~239)가
--       실회원인데 마스터 스냅샷 누락인가, 폐기 대상인가?
-- =====================================================================
SELECT
    CASE
        WHEN REGEXP_LIKE(mber_no, '^[0-9]{7}$') THEN '정상 7자리 FDRM'
        WHEN REGEXP_LIKE(mber_no, '^S[0-9]{8}$') THEN 'ONCE S+8자리'
        WHEN LENGTH(mber_no) <= 2 THEN '짧은/비정상 ID'
        ELSE '기타'
    END AS "유형",
    COUNT(DISTINCT mber_no) AS "DISTINCT_회원번호수"
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION
WHERE mber_no NOT IN (SELECT member_dk FROM GN_DW.GOLD.DIM_MEMBER)
GROUP BY 1
ORDER BY 2 DESC;

-- =====================================================================
-- C. 캘린더(1991~2035) 범위밖 날짜 — 20-001:75~78
-- 질문: 1910년 이전(88행)=과거이력, 2030년 이후(2행)=예약일정, 유효 여부?
-- (참여 경로만 예시. 개발 OCCRRNC_DE·후원중단 SPNSR_DSCNTC_DE 는 원천
--  BRONZE_CRM 테이블에서 동일 패턴으로 확인)
-- =====================================================================
SELECT
    partcpt_dt,
    COUNT(*) AS "행수"
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION
WHERE partcpt_dt < '1910-01-01' OR partcpt_dt > '2030-01-01'
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- D. 원천 값 전무(100% NULL) 컬럼 — 20-001:80~89
-- 질문: 원천 보유하는데 추출 누락인가, 원천 미수집인가?
-- =====================================================================
SELECT '대상' AS "대상_LABEL", 'AGENCY_AD_PERFORMANCE.CONV_CALL_CNT' AS "대상",
       COUNT(*) AS "전체행수",
       COUNT(conv_call_cnt) AS "값있는행수"
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE
UNION ALL
SELECT '대상', 'CRM_CAMPAIGN.MKTG_CMPGN_NM',
       COUNT(*),
       COUNT(mktg_cmpgn_nm)
FROM GN_DW.SILVER.CRM_CAMPAIGN
UNION ALL
SELECT '대상', 'CRM_SEND_RESULT.TOT_CLICK_CNT',
       COUNT(*),
       COUNT(tot_click_cnt)
FROM GN_DW.SILVER.CRM_SEND_RESULT
UNION ALL
SELECT '대상', 'CRM_BIZ_TARGET(전 컬럼)',
       COUNT(*),
       COUNT(*)
FROM GN_DW.SILVER.CRM_BIZ_TARGET;

-- =====================================================================
-- E. 참조 무결성 gap — 마스터 부재 외래키 (최우선) — 20-001:92~104
-- 질문: 행사 마스터(CRM_EVENT) 추출 범위/시점 문제가 맞는가? 23% 참여가 유효한가?
-- =====================================================================
SELECT
    COUNT(*) AS "참여행_전체",
    COUNT(CASE WHEN e.event_key IS NULL THEN 1 END) AS "고아행_행사마스터_미매칭",
    ROUND(COUNT(CASE WHEN e.event_key IS NULL THEN 1 END) * 100.0
        / COUNT(*), 2) AS "고아비율_PCT"
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION p
LEFT JOIN GN_DW.SILVER.CRM_EVENT e
    ON p.event_key = e.event_key;

-- =====================================================================
-- D(코드매핑). SV 코드→라벨 매핑 SVL-1~4 — 20-001:113~121
-- 질문: SNDNG_TY_CD(SVL-1)·SNDNG_RST_CD(SVL-2)·SEND_CHANNEL(SVL-3)·
--       EVENT_DIV_CD/CRMN_DIV_CD(SVL-4)의 정확한 CD_ID/라벨표는?
-- =====================================================================
SELECT DISTINCT send_status AS "SVL2_SNDNG_RST_CD_관측값"
FROM GN_DW.GOLD.FACT_SERVICE_EVENT
ORDER BY 1;

SELECT DISTINCT event_div_cd AS "SVL4_일반행사_구분코드"
FROM GN_DW.SILVER.CRM_EVENT
ORDER BY 1;

-- =====================================================================
-- AD-2. CRM_DVLP_CNT(CRM 개발건수) 소수값 — 20-001:130~142
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
-- 질문: 원천 포맷 변경이 의도된 것인가? 개발건수 재제공 요청 vs 단가 채택?
-- =====================================================================
SELECT
    TO_CHAR(date, 'YYYY-MM') AS "기간",
    COUNT(crm_dvlp_cnt) AS "개발건수_값있는행",
    COUNT(dev_unit_price) AS "대행사단가_값있는행"
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
WHERE date >= '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- AD-5. VIDEO 광고 개발실적 원천 부재 — 20-001:180~198
-- 질문: 비디오는 개발실적을 원래 집계하지 않는 것이 맞는가?
--       (전환콜 CONV_CALL_CNT로 성과를 보는 체계인지)
-- =====================================================================
SELECT
    COUNT(*) AS "전체행수",
    COUNT(conv_call_cnt) AS "전환콜_값있는행",
    SUM(actl_pur_ad_cost_krw) AS "비디오_총광고비"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

-- =====================================================================
-- F-1. 신규본부/신규지부 축 부재 — 20-002:10~29
-- 질문: 본부/지부 구별 기준은? "신규"는 조직신설 vs 신규회원 축인가?
-- =====================================================================
SELECT
    corp,
    division,
    department,
    team,
    COUNT(*) AS "부서수"
FROM GN_DW.GOLD.DIM_ORG
WHERE division ILIKE '%본부%' OR division ILIKE '%지부%'
   OR department ILIKE '%본부%' OR department ILIKE '%지부%'
GROUP BY corp, division, department, team
ORDER BY 5 DESC;

-- =====================================================================
-- F-2. 후원사업 그룹 — 4그룹 매핑과 "총 11개" 기준 — 20-002:31~57
-- 질문: SPONSORSHIP_ABBR의 정확한 CD_ID? 4(대북)/6(해외사례)는 어디로?
--       "총 11개" 예측대상 사업 목록은?
-- =====================================================================
SELECT
    sponsorship_abbr,
    COUNT(*) AS "사업수",
    LISTAGG(sponsorship_name, ' · ') WITHIN GROUP (ORDER BY sponsorship_name)
        AS "소속사업_목록"
FROM GN_DW.GOLD.DIM_SPONSORSHIP
GROUP BY sponsorship_abbr
ORDER BY sponsorship_abbr;

-- =====================================================================
-- F-3. 발송 오픈 — C-9 폐기 결정을 되돌려야 하는가 (최우선) — 20-002:59~83
-- 질문: ML 예측 3종이 오픈율에 의존한다. 오픈 로그 추출 경로가 있는가?
--       클릭 대체 가능한가?
-- =====================================================================
SELECT '원천' AS "구분", 'FACT_SERVICE_EVENT.OPEN_MEMBERS' AS "항목",
    COUNT(*) AS "전체행수",
    COUNT(open_members) AS "값있는행",
    SUM(open_members) AS "합계"
FROM GN_DW.GOLD.FACT_SERVICE_EVENT
UNION ALL
SELECT '원천', 'TD_MS_EMAIL_LQY_SNDNG.URL_OTHBC_CNT_CTNT',
    COUNT(*),
    COUNT(url_othbc_cnt_ctnt),
    SUM(url_othbc_cnt_ctnt)
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG
UNION ALL
SELECT '원천', 'CRM_SEND_RESULT.TOT_CLICK_CNT',
    COUNT(*),
    COUNT(tot_click_cnt),
    SUM(tot_click_cnt)
FROM GN_DW.SILVER.CRM_SEND_RESULT;

-- =====================================================================
-- F-4. 예측 등급 산출식 — 등급 구간/기준 미확정 — 20-002:85~98
-- (질의성 항목 — 현업의 사업 규칙 확정이 필요하며 실측 쿼리 대상이 아님)
-- 참고용: 등급 부여 대상 모집단 규모 확인
-- =====================================================================
SELECT COUNT(DISTINCT member_dk) AS "활동회원수"
FROM GN_DW.GOLD.DIM_MEMBER
WHERE mber_stat_cd BETWEEN 1 AND 11
  AND is_current = TRUE;

-- =====================================================================
-- F-5. 공휴일 캘린더 — 20-002:100~111
-- 질문: 법정공휴일도 제외해야 하는가, 주말만으로 충분한가?
--       사내 근무 캘린더 제공 가능한가?
-- =====================================================================
SELECT
    is_holiday,
    COUNT(*) AS "일수"
FROM GN_DW.GOLD.DIM_DATE
GROUP BY is_holiday;

-- =====================================================================
-- H-3. 성별축 코드그룹 CM017 확정 여부 — 20-002:153~160
-- 질문: 성별 라벨축을 CM017로 확정해도 되는가? SEX_NM 별도 축 유지 필요한가?
--       SEX NULL 421명은 업무상 의미가 있는가?
-- =====================================================================
SELECT
    gender_name,
    sex_nm,
    COUNT(*) AS "회원수"
FROM GN_DW.GOLD.DIM_MEMBER
WHERE is_current = TRUE
GROUP BY gender_name, sex_nm
ORDER BY 3 DESC;

-- =====================================================================
-- I-2. TD_MS_EVENT_PRTCPNT_DTL 특수문자(bxss.me) 침투 흔적 — 20-003:111~123
-- 질문: 4개 날짜(2023-12-16·2024-02-01·2024-02-14·2024-07-03)에 보안점검
--       이력이 있는가? S+8자리 회원번호 체계가 실제 쓰이는가?
-- =====================================================================
SELECT
    partcpt_dt,
    COUNT(*) AS "이상값행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE mber_no = ')'
   OR partcpt_chnnl_cd = ')'
   OR partcpt_path_cd = ')'
   OR partcpt_stat_cd = ')'
   OR rm = ')'
   OR rm2 = ')'
GROUP BY partcpt_dt
ORDER BY partcpt_dt;

SELECT DISTINCT mber_no
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE REGEXP_LIKE(mber_no, '^S[0-9]{8}$')
ORDER BY 1;

-- =====================================================================
-- J-2. 광고 초수(방송) 단위 — 100만분의 1초 여부 — 20-003:155~163
-- 질문: 30000000/60000000/90000000 = 각 30/60/90초를 뜻하는가?
-- =====================================================================
SELECT
    ad_sec,
    COUNT(*) AS "건수",
    ad_sec / 1000000.0 AS "백만분의1초_환산값"
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
WHERE ad_sec IN ('30000000', '60000000', '90000000')
GROUP BY ad_sec
ORDER BY ad_sec;

-- =====================================================================
-- K-2. 발송·참여 지표 "인원" vs "횟수" 구분 — 20-004:8~29
-- 질문: 인원=사람수(중복제거) / 횟수=기록수(중복포함)로 구분이 맞는가?
--       "누적신청 횟수"의 누적 기준은?
-- =====================================================================
SELECT
    COUNT(*) AS "참여기록_횟수",
    COUNT(DISTINCT mber_no || '-' || event_key) AS "참여인원_회원행사쌍수"
FROM GN_DW.SILVER.CRM_EVENT_PARTICIPATION;

-- =====================================================================
-- L-1. 「발송 후 반응」 귀속 발송 구분 (최우선) — 20-004:46~98
-- 질문: 캠페인성 발송만 코호트에 넣고 처리통보성 발송은 제외해야 하는가?
--       귀속기간 D+5가 맞는가? 채널별로 다른가?
-- =====================================================================
SELECT
    DATEDIFF(day, s.sndng_de, m.last_stop_date) AS "발송_중단_간격일",
    COUNT(*) AS "중단건수"
FROM GN_DW.SILVER.CRM_SEND_MEMBER s
JOIN GN_DW.GOLD.DIM_MEMBER m
    ON s.mber_no = m.member_dk
WHERE m.last_stop_date >= '2025-01-01'
  AND m.last_stop_date < '2026-01-01'
GROUP BY 1
ORDER BY 1;

-- 참고: 「당일 발송」의 발송건수 상위 확인용
SELECT
    s.sndng_de,
    COUNT(*) AS "발송건수"
FROM GN_DW.SILVER.CRM_SEND_MEMBER s
JOIN GN_DW.GOLD.DIM_MEMBER m
    ON s.mber_no = m.member_dk
WHERE s.sndng_de = m.last_stop_date
  AND m.last_stop_date >= '2025-01-01'
  AND m.last_stop_date < '2026-01-01'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- =====================================================================
-- L-2. 중단보고 「후원사업」 — 끊은 사업(가) vs 데려온 사업(나) — 20-004:100~115
-- 질문: 중단 보고서 후원사업은 (가)끊은 사업인가, (나)데려온 사업인가?
--       둘 다 필요하면 두 열로 병기 가능
-- =====================================================================
SELECT
    a.acq_sponsorship_name AS "획득_후원사업_나",
    d.sponsorship_name AS "중단_후원사업_가",
    COUNT(*) AS "회원수"
FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION a
JOIN GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ f
    ON a.member_dk = f.member_dk
JOIN GN_DW.GOLD.DIM_SPONSORSHIP d
    ON f.sponsorship_sk = d.sponsorship_sk
WHERE f.dscntc_month_key IS NOT NULL
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 50;

-- =====================================================================
-- M-2. 발송 서비스 SUBTYPE(발신유형) 코드군 부재 — 20-005:65~81
-- 질문: 채널별(EMAIL/MSG_AT/PSTMTR) 발신유형코드 SNDNG_TY_CD 값의 의미는?
-- =====================================================================
SELECT
    sv.channel,
    sv.subtype,
    COUNT(*) AS "행수"
FROM GN_DW.GOLD.FACT_SERVICE_EVENT fe
JOIN GN_DW.GOLD.DIM_SERVICE sv
    ON fe.service_sk = sv.service_sk
GROUP BY sv.channel, sv.subtype
ORDER BY sv.channel, sv.subtype;

-- =====================================================================
-- M-4. 이메일·SND 발송결과 라벨 사전 미등재 — 20-005:108~125
-- 질문: EMAIL(1/0), SND(Y/N) 코드값을 현업 화면·보고서에서 무엇이라 부르는가?
-- =====================================================================
SELECT 'EMAIL' AS "채널", sndng_rst_cd AS "코드값", COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS
GROUP BY sndng_rst_cd
UNION ALL
SELECT 'SND', snd_yn, COUNT(*)
FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST
GROUP BY snd_yn;

-- =====================================================================
-- M-5. 통신사 발송결과 코드 17종 사전 미등재 — 20-005:127~146
-- 질문: 미등재 코드(MSG_AT 7320·7319·9034·7321·7205 / SND 0·3~9 등)의 뜻은?
--       SND 한 자리 코드가 MSG_AT 4자리 체계와 다른 체계인가?
-- =====================================================================
SELECT
    'MSG_AT' AS "채널",
    trnsms_failr_cd_id AS "코드",
    COUNT(*) AS "행수"
FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS
WHERE trnsms_failr_cd_id NOT IN (
    SELECT dtl_cd_id FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
    WHERE cd_id IN ('MS056', 'MS057', 'MS058', 'MS059')
)
GROUP BY trnsms_failr_cd_id
ORDER BY 3 DESC;

-- =====================================================================
-- M-6. 「발송상태2」 원천 컬럼 미확정 — 20-005:150~180
-- 질문: 발송상태2 = 전송실패코드/통화상태(축B)가 맞는가? 다른 컬럼인가?
--       더 쓰지 않는 필드라 제거해도 되는가?
-- =====================================================================
SELECT
    COUNT(*) AS "전체행수",
    COUNT(send_status2) AS "발송상태2_값있는행",
    COUNT(send_result_cd) AS "후보축B_전송실패코드_값있는행"
FROM GN_DW.GOLD.FACT_SERVICE_EVENT;

-- =====================================================================
-- N-1. 「월 목표(건)」= 「연사업목표(건)」 동일 지표 여부 — 20-006:4~19
-- 질문: "월"과 "당월" 정의 표현 차이 외 실제로 같은 지표인가?
-- =====================================================================
-- (참고: 목표 원천 CRM_BIZ_TARGET 입고 대기 — 실측 대상 없음. 아래는 근접 확인용)
SELECT target_type, COUNT(*) AS "행수"
FROM GN_DW.SILVER.CRM_BIZ_TARGET
GROUP BY target_type;

-- =====================================================================
-- N-2. 단위/축 보완 10건 — 기존 번호 대체 여부 — 20-006:21~43
-- 질문: 165(월말활동회원(명))=공156(활동(명)) 동일 정의인가? 169 vs 공154
--       누계 기준(월 누계 vs 당해년 누계) 차이 확인
-- =====================================================================
SELECT
    month_key AS "회비월",
    active_members AS "월말활동회원_명수",
    active_cnt AS "활동_건수"
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
ORDER BY month_key DESC
LIMIT 12;

-- =====================================================================
-- N-3. 캠페인 축 4건 불일치 (최우선) — 20-006:45~67
-- 질문: 54(개발인입경로 14종) vs 공11(매체명 15개), 56(국내/해외/통합/전체
--       사업) vs 공15(국내/해외/전체/통합), 57(사업/사례/굿즈/기타) vs
--       공16(사례/사업/굿즈/통합) — 신규규칙이 기존 축을 대체하는가?
-- =====================================================================
SELECT inflow_path, COUNT(*) AS "행수"
FROM GN_DW.GOLD.DIM_CAMPAIGN
GROUP BY inflow_path
ORDER BY 2 DESC;

SELECT domestic_overseas, COUNT(*) AS "행수"
FROM GN_DW.GOLD.DIM_CAMPAIGN
GROUP BY domestic_overseas
ORDER BY 2 DESC;

SELECT biz_case_type, COUNT(*) AS "행수"
FROM GN_DW.GOLD.DIM_CAMPAIGN
GROUP BY biz_case_type
ORDER BY 2 DESC;

-- =====================================================================
-- N-4. 「데이터 출처」 칸 공백 14건 — 20-006:69~85
-- 질문: 166·167·168·171·172의 원천이 169·170과 같은 CRM인가?
--       CRM_BIZ_TARGET 입고범위를 넓혀야 하는가?
-- =====================================================================
SELECT column_name, comment AS "컬럼설명"
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'CRM_BIZ_TARGET'
ORDER BY ordinal_position;

-- =====================================================================
-- N-6-A. 캠페인 4축 값 실재 확인 — 20-007:10~20
-- 질문: 54는 "브랜드"가 아니라 "회원인입경로"가 맞는가?
--       56의 "전체사업"/"전체"는 폐기된 값인가?
-- =====================================================================
SELECT domestic_overseas, COUNT(*) AS "행수"
FROM GN_DW.GOLD.DIM_CAMPAIGN
WHERE domestic_overseas IN ('전체사업', '전체')
GROUP BY domestic_overseas;

-- =====================================================================
-- N-8. MKTG_UTM 라벨 사전 미등재 — 고아코드 192 = 캠페인 63.8% — 20-007:167~191
-- 질문: MK_UTM=192는 사전등재누락(㉠)인가, "UTM 없음" 센티넬(㉡)인가?
--       ㉡이면 192를 NULL로 정규화해도 되는가?
-- =====================================================================
SELECT
    mktg_utm,
    COUNT(*) AS "행수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS "비율_PCT"
FROM GN_DW.SILVER.CRM_CAMPAIGN
GROUP BY mktg_utm
ORDER BY 2 DESC;

SELECT mk_utm, COUNT(*) AS "사전등재건수"
FROM GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM
WHERE mk_utm = '192'
GROUP BY mk_utm;

-- =====================================================================
-- N-9. SV_MEMBER_COHORT.CAMPAIGN_NAME 시점 혼합 — 20-007:195~215
-- 질문: CAMPAIGN_NAME도 획득 시점 동결로 확장해야 하는가, 실시간 유지인가?
--       ACQ_CAMPAIGN_NAME이 이미 존재하는데 값이 동결값인지 실시간인지 확인
-- =====================================================================
SELECT
    a.acq_campaign_name AS "획득시점_동결값",
    c.campaign_name AS "캠페인마스터_현재값",
    COUNT(*) AS "회원수"
FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION a
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN c
    ON a.acq_campaign_sk = c.campaign_sk
WHERE a.acq_campaign_name <> c.campaign_name
   OR (a.acq_campaign_name IS NULL) <> (c.campaign_name IS NULL)
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 50;

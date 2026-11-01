-- 31. 공8 + 문서20 미회신 29건 — 질문 쿼리 근거 (문서 30 `30_공8및미회신29건_질문요약.md` 의 수치를 재현)
-- Co-authored with CoCo · 2026-09-29 O188-B · 계정 xf98254 · 읽기 전용(변경 없음)
-- 🔴 GA 원천 규칙(사용자 지시 O188-B) = GA/GA4 기준 데이터는
--    ① SILVER.BIGQUERY_REFINED_DATA(GA4 이벤트) ② BRONZE_AGENCY(대행사 리포트) 두 곳뿐이다. 그 외 GA 소스 없음.
-- 🔴 `-- 실측:` 줄은 이 파일을 2026-09-29 에 실행한 결과다(인용 전 재실행 · R2-8-4).
-- 선행본 = `31_공8_GA개발단가_쿼리근거.sql`(Q1~Q6 · 공8 1차 정의) — 이 파일이 승계한다.

-- ============================================================
-- [G8] 공8 GA 개발단가 — 분모 「GA 개발(건)」의 출처가 두 곳이다
-- ============================================================

-- [G8-1] GA4 전환 이벤트 분포 — 후원 완료 = purchase(정기 `정기후원` · 일시 `일시후원` 이벤트와 대응)
SELECT EVENT_NAME,
       COUNT(*)                          AS n,
       COUNT(DISTINCT EP_TRANSACTION_ID) AS tx,
       MIN(EVENT_DATE)                   AS mn,
       MAX(EVENT_DATE)                   AS mx
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
WHERE EVENT_NAME IN ('purchase', '정기후원', '일시후원', 'begin_checkout')
GROUP BY 1
ORDER BY 2 DESC;
-- 실측: purchase 8,218행·tx 8,216 · 정기후원 7,093 · 일시후원 1,132 · begin_checkout 188,577
--       기간 20240116~20260915 (GA4 는 09-15 까지 · 대행사는 09-22 까지)

-- [G8-2] 월별 대조 — GA4 purchase 거래수 vs 대행사 CONV_VU_CNT(「전환가치(건)」)
WITH g AS (
    SELECT SUBSTR(EVENT_DATE, 1, 6)          AS ym,
           COUNT(DISTINCT EP_TRANSACTION_ID) AS ga4_tx
    FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
    WHERE EVENT_NAME = 'purchase'
    GROUP BY 1
), a AS (
    SELECT TO_CHAR(YEAR) || LPAD(TO_CHAR(MONTH), 2, '0') AS ym,
           SUM(CONV_VU_CNT) AS conv_vu,
           SUM(AD_COST)     AS ad_cost
    FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
    GROUP BY 1
)
SELECT a.ym, g.ga4_tx, a.conv_vu,
       a.conv_vu / NULLIF(g.ga4_tx, 0) AS ratio,
       a.ad_cost / NULLIF(g.ga4_tx, 0) AS cost_per_ga4_tx,
       a.ad_cost / NULLIF(a.conv_vu, 0) AS cost_per_conv_vu
FROM a LEFT JOIN g ON g.ym = a.ym
ORDER BY 1;
-- 실측: 202606 314 / 13,415.4 · 202607 245 / 10,752.2 · 202608 150 / 3,592 · 202609 230 / 11,087.7
--       ⇒ 규모가 24~48배 다르다(ratio 42.7 · 43.9 · 23.9 · 48.2) · 단가 = GA4 기준 약 174만~471만원 ↔ CONV_VU 기준 7.3만~10.7만원

-- [G8-3] GA4 purchase 의 유입매체(세션 최종클릭) — 광고 기여분만 셀 것인가
SELECT COALESCE(STSLC_CRC_MEDIUM, '(null)') AS medium,
       COUNT(DISTINCT EP_TRANSACTION_ID)    AS tx
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
WHERE EVENT_NAME = 'purchase'
  AND EVENT_DATE BETWEEN '20260601' AND '20260930'
GROUP BY 1
ORDER BY 2 DESC;
-- 실측: cpc 301 · display 250 · (null) 230 · (none) 66 · referral 32 · organic 20 · CPV 14 · 기타 23
--       ⇒ 유료(cpc+display+CPV) 565 / 전체 939

-- ============================================================
-- [F] ML 예측 요건 (문서20 -002)
-- ============================================================

-- [F-1] 본부/지부 — 명칭 기준 레벨 분포(재귀 트리 · UPPER_DEPT_ID)
WITH RECURSIVE t AS (
    SELECT DEPT_ID, DEPT_NM, UPPER_DEPT_ID, 1 AS lvl
    FROM GN_DW.SILVER.CRM_ORG
    WHERE UPPER_DEPT_ID IS NULL
       OR UPPER_DEPT_ID NOT IN (SELECT DEPT_ID FROM GN_DW.SILVER.CRM_ORG)
    UNION ALL
    SELECT c.DEPT_ID, c.DEPT_NM, c.UPPER_DEPT_ID, t.lvl + 1
    FROM GN_DW.SILVER.CRM_ORG c
    JOIN t ON c.UPPER_DEPT_ID = t.DEPT_ID AND c.DEPT_ID <> c.UPPER_DEPT_ID
    WHERE t.lvl < 10
)
SELECT lvl,
       COUNT(*)                          AS depts,
       COUNT_IF(DEPT_NM LIKE '%본부%')   AS hq_named,
       COUNT_IF(DEPT_NM LIKE '%지부%')   AS branch_named
FROM t
GROUP BY 1
ORDER BY 1;
-- 실측: LVL1 9(본부명 2·지부명 0) · LVL2 38(6·4) · LVL3 351(50·65) · LVL4 672(67·280) · LVL5 238(4·5) · LVL6 6
--       ⇒ 「본부」「지부」 명칭이 LVL1~5 에 흩어져 있다 — 단일 레벨로 자를 수 없다(문서20 -002:22 재현)

-- [F-2] 후원사업 약어코드(ABBR) 6종 × 그룹명 현황
SELECT SPONSORSHIP_ABBR,
       SPONSORSHIP_GROUP_NAME,
       COUNT(*) AS biz_cnt
FROM GN_DW.GOLD.DIM_SPONSORSHIP
GROUP BY 1, 2
ORDER BY 1, 2;
-- 실측: 1 국내 17 · 2 결연 1 · 3 해외구호 6 · 4 북한 3 · 5 기타 21 · 6 해외 2 · NULL 1
--       🟢 J3 전제 변동 — SPONSORSHIP_GROUP_NAME 라벨이 이미 적재돼 있다(질문 1 「라벨표」는 사실상 답이 났다)
--       🔴 남은 것 = 6그룹(북한·해외 분리) ↔ ML 4그룹(국내/결연/해외프로젝트/기타) 접는 규칙 · 「11개」 목록

-- [F-3] 오픈 원천 — 이메일 오픈 컬럼 채움 / GOLD OPEN_MEMBERS 합
SELECT 'EMAIL_LQY_OPEN_CNT' AS axis, COUNT(*) AS n, COUNT(URL_OTHBC_CNT_CTNT) AS filled
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG
UNION ALL
SELECT 'FMD_OPEN_MEMBERS>0', COUNT(*), COUNT_IF(OPEN_MEMBERS > 0)
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH;
-- 실측: EMAIL_LQY 오픈건수 채움 0 / 524,033 · FMD OPEN_MEMBERS>0 = 490,762 / 41,935,344행
--       🟢 J3 전제 변동 — 문서20 은 OPEN_MEMBERS 「전건 0」이었으나 지금은 49만행 유값 ⇒ 어느 채널 값인지 재확인 필요

-- [F-4] 등급 산출식 — 데이터 질의 없음(현업 사업 규칙 · 정본 xlsx 원문 물음표 4건)

-- ============================================================
-- [H-3·K-2] 10~22번 문서에서 이미 닫힘 — 확인용 쿼리만
-- ============================================================

-- [H-3] 성별 3축 동시 보존(16 §3-1)
SELECT GENDER_NAME, COUNT(*) AS n
FROM GN_DW.GOLD.DIM_MEMBER
GROUP BY 1
ORDER BY 2 DESC;
-- 실측: 여자 960,139 · 남자 708,562 · 기타 60,341 · 기업 40,604 · 단체 15,159 · NULL 494 ⇒ 5종 라벨 배선 유지

-- [K-2] 인원 vs 횟수 이원화(16 §3-2)
SELECT EVENT_KIND_NAME,
       COUNT(DISTINCT MEMBER_DK) AS persons,
       COUNT(*)                  AS records
FROM GN_DW.GOLD.FACT_EVENT_ATTENDANCE
GROUP BY 1
ORDER BY 1;
-- 실측: 일반행사 408,163명 / 1,085,872건 · 캠페인행사 43,521명 / 162,855건 ⇒ 인원·횟수 이원화 유지

-- ============================================================
-- [J-2] 방송광고 초수 — 8자리 숫자 표기의 단위 (BRONZE_AGENCY)
-- ============================================================
SELECT IFF(AD_SEC LIKE '%:%', 'HMS', 'NUM') AS fmt,
       AD_SEC,
       COUNT(*) AS n
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
WHERE AD_SEC IS NOT NULL
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 12;
-- 실측(상위): HMS 00:01:00 27,971 · 00:01:30 3,392 · 00:02:00 1,082 · 00:00:30 488 · NUM 60000000 597 · 90000000 411
--       ⇒ 숫자 표기 ÷ 1,000,000 = {60, 90}초 ⊂ 시분초 도메인 {30,60,90,120}초 (µs 가설 유지 · 현업 승인만 남음)

-- ============================================================
-- [L] 발송 효과성 · 중단 (문서20 -004)
-- ============================================================

-- [L-1①] 중단 당일 발송 제목 상위 — 처리통보성 발송의 비중
SELECT SEND_TITLE,
       SUM(D5_STOP_CNT) AS d5_stop_cnt,
       COUNT(*)         AS rows_
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
GROUP BY 1
ORDER BY 2 DESC NULLS LAST
LIMIT 10;
-- 실측(상위): 결연_미납알림톡5 27,765.5 · 공통_미납알림톡5 26,096.9 · 증액 후원감사 알림톡 20,809.9 · 보건_미납알림톡5 18,996.9
--       ⇒ D5 중단 귀속 상위가 여전히 「미납·감사」 처리통보성 발송이다(인과 역전 위험 유지)

-- [L-1②] D+5 기본 적용 배선 확인(16 §4-1 · 결정됨)
SELECT SUM(D5_STOP_CNT)           AS d5_stop,
       SUM(D5_INCREASE_PART_CNT)  AS d5_increase,
       SUM(D5_LETTER_PART_CNT)    AS d5_letter,
       SUM(D5_GIFT_PART_CNT)      AS d5_gift
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH;
-- 실측: D5_STOP 183,579 · D5_INCREASE 1,496,720 · D5_LETTER 233,495 · D5_GIFT 168,948 ⇒ D+5 배선 실재(16 §4-1)

-- [L-1③] 채널별 차등 — 채널(SEND_TYPE)별 발송 규모
SELECT SEND_TYPE,
       COUNT(*)         AS rows_,
       SUM(D5_STOP_CNT) AS d5_stop
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
GROUP BY 1
ORDER BY 2 DESC;
-- 실측: EMAIL 7,823,562행 D5중단 14,230 · MSG_AT 21,958,206 / 155,732 · PSTMTR 1,969,939 / 3,545 · SND 10,183,637 / 10,072

-- [L-2] 중단 행의 후원사업 배선 — (가) 끊은 사업 축의 현재 채움
SELECT EVENT_TYPE,
       COUNT(*)                       AS n,
       COUNT_IF(SPONSORSHIP_SK <> 0)  AS biz_wired
FROM GN_DW.GOLD.FACT_MEMBER_EVENT
GROUP BY 1
ORDER BY 1;
-- 실측: DEV 3,654,658 전건 사업 배선 · STOP 1,061,430 중 979,762(92.31%) 배선 · 미배선 81,668(다중사업 = N-13)

-- ============================================================
-- [M] 발송 코드 체계 (문서20 -005)
-- ============================================================

-- [M-2] 발신유형 SEND_TYPE 채널별 값
SELECT DW_SOURCE_SYSTEM, SEND_TYPE, COUNT(*) AS n
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
GROUP BY 1, 2
ORDER BY 1, 2;
-- 실측: SEND_TYPE = 채널명(EMAIL·MSG_AT·PSTMTR·SND)만 적재 — 발신유형 코드(SNDNG_TY_CD)는 GOLD 에 라벨 없이 미노출

-- [M-4 → N-23③] 채널별 발송결과 코드 채움률
SELECT SEND_TYPE,
       COUNT(*)                        AS n,
       COUNT(SEND_RESULT_CD)           AS cd_filled,
       COUNT(DISTINCT SEND_RESULT_CD)  AS cd_kinds,
       COUNT(SEND_RESULT_NAME)         AS name_filled
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
GROUP BY 1
ORDER BY 1;
-- 실측: EMAIL 코드 0 / 7,823,562 · PSTMTR 0 / 1,969,939 · MSG_AT 19,595,426 / 21,958,206(33종) · SND 9,699,095 / 10,183,637(34종)

-- [M-5] 라벨 미매칭 결과코드 목록
SELECT SEND_TYPE, SEND_RESULT_CD, COUNT(*) AS n
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
WHERE SEND_RESULT_CD IS NOT NULL
  AND SEND_RESULT_NAME IS NULL
GROUP BY 1, 2
ORDER BY 3 DESC;
-- 실측: 라벨 미매칭 MSG_AT 5코드 537,994행 · SND 12코드 1,099,451행
--       (코드 9 355,044 · 7320 353,811 · 3 266,611 · 7319 252,490 · 5 144,605 · 0 136,358 · 4 106,681 …)

-- [M-6] 발송상태2 — 전건 NULL 여부
SELECT COUNT(*) AS n, COUNT(SEND_STATUS2) AS status2_filled, COUNT(SEND_RESULT_CD) AS axis_b_filled
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH;
-- 실측: SEND_STATUS2 0 / 41,935,344 · 축B(SEND_RESULT_CD) 29,294,521 채움

-- ============================================================
-- [N-1~N-4 · N-6-A] 지표사전 추가분 대조 (문서20 -006·-007)
-- ============================================================

-- [N-1·N-4] 목표 원천 2종 — 개발목표(구) vs 사업목표(신 · N-24)
SELECT 'TM_CM_MBER_DVLP_GOAL' AS src, COUNT(*) AS n, SUM(GOAL_CNT) AS goal_sum
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL
UNION ALL
SELECT 'TM_CM_MBER_DVLP_GOAL_DIV', COUNT(*),
       SUM(M01_GOAL_CNT + M02_GOAL_CNT + M03_GOAL_CNT + M04_GOAL_CNT + M05_GOAL_CNT + M06_GOAL_CNT
         + M07_GOAL_CNT + M08_GOAL_CNT + M09_GOAL_CNT + M10_GOAL_CNT + M11_GOAL_CNT + M12_GOAL_CNT)
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV;
-- 실측: TM_CM_MBER_DVLP_GOAL 25,344행 합 4,622,103 · TM_CM_MBER_DVLP_GOAL_DIV 290행 12개월 합 696,024(=348,024+348,000)

-- [N-3·N-6-A] 캠페인 4축 라이브 도메인
SELECT 'DOMESTIC_OVERSEAS' AS axis, DOMESTIC_OVERSEAS AS val, COUNT(*) AS n
FROM GN_DW.GOLD.DIM_CAMPAIGN GROUP BY 1, 2
UNION ALL
SELECT 'BIZ_CASE_TYPE', BIZ_CASE_TYPE, COUNT(*)
FROM GN_DW.GOLD.DIM_CAMPAIGN GROUP BY 1, 2
ORDER BY 1, 3 DESC;
-- 실측: BIZ_CASE_TYPE 사례 13,573 · 사업 9,242 · 기타 8,024 · 굿즈 4,455 · NULL 1,475
--       DOMESTIC_OVERSEAS 국내 13,433 · 해외 13,104 · 통합 8,010 · 🟢 전체사업 747 · NULL 1,475
--       🟢 J3 전제 변동 — N-6-A 질문2 「전체사업 라이브 0건」은 이제 거짓이다(747행 실재)

SELECT COUNT(DISTINCT INFLOW_PATH)   AS inflow_path_kinds,
       COUNT(DISTINCT BRAND)         AS brand_kinds,
       COUNT(DISTINCT CAMPAIGN_TYPE) AS campaign_type_kinds
FROM GN_DW.GOLD.DIM_CAMPAIGN;
-- 실측: INFLOW_PATH 12종(문서20 16종) · BRAND 84종 · CAMPAIGN_TYPE 59종(문서20 55종) ⇒ 도메인 변동 — 질문1·4 재확인

-- ============================================================
-- [N-19] 「그 밖」 항목 일괄 (문서20 -009:189 질문 1~7)
-- ============================================================

-- [N-19-4] 모금성비용 플래그 YN_1 × YN_2
SELECT DIRECT_MNYRS_YN_1, DIRECT_MNYRS_YN_2, COUNT(*) AS n
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
GROUP BY 1, 2
ORDER BY 3 DESC;
-- 실측: NULL/NULL 133 · Y/Y 91 · NULL/Y 34 ⇒ 차 34행 포함 여부가 질문 그대로 유효

-- [N-19-5] GSC 두 테이블 규모
SELECT 'GSC1' AS t, COUNT(*) AS n, SUM(CLICKS) AS clicks FROM GN_DW.BRONZE_GSC.SEARCH_CONSOLE_DATA
UNION ALL
SELECT 'GSC2', COUNT(*), SUM(CLICKS) FROM GN_DW.BRONZE_GSC.SEARCH_CONSOLE_DATA2;
-- 실측: GSC1 968,484행 클릭 64,820 · GSC2 941,298행 63,026 (GSC1 은 문서20 대비 +10,065행 증분)

-- [N-19-6] 예산 세세목 종류 수(캠페인 코드 부재)
SELECT COUNT(*) AS n, COUNT(DISTINCT SUBDTL_ITEM_NM) AS subdtl_kinds
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER;
-- 실측: 258행 · 세세목 48종 · 캠페인 코드 컬럼 없음

-- [N-19-7] VIDEO 전환콜·개발건 — 대행사 원천이 보고하는 것
SELECT COUNT(*)              AS n,
       COUNT(CPC_CALL_CNT)   AS cpc_call_filled,
       COUNT(INBOUND_CALL_CNT) AS inbound_call_filled,
       COUNT(DVLP_CNT)       AS dvlp_filled,
       SUM(DVLP_CNT)         AS dvlp_sum
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;
-- 실측: 46,353행 · CPC_CALL 33,693 채움 · INBOUND_CALL 19,393 · DVLP_CNT 8,756행 합 32,783.6
--       🟢 J3 전제 변동 — 「전환콜 전건 NULL」(CONV_CALL_CNT)은 원천 재편으로 컬럼이 CPC_CALL_CNT 로 바뀌어 유값

-- ============================================================
-- [D-2] 사업목표 원천 = CRM 확인 (실측상 답이 났다 · N-25)
-- ============================================================
SELECT GOAL_TYPE_NM, CPR_DIV_NM, COUNT(*) AS n
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
GROUP BY 1, 2
ORDER BY 1, 2;
-- 실측: 연사업/사단 154 · 팀/사단 68 · 팀/사복 68 ⇒ 사업목표가 BRONZE_CRM 에 있다(CRM 확인만 요청)

-- ============================================================
-- [W-1] GA4 UTM ↔ 캠페인 — 🔴 GA 원천 규칙상 BIGQUERY_REFINED_DATA 기준으로 잰다
-- ============================================================
WITH u AS (
    SELECT STSLC_MC_CAMPAIGN_NAME AS utm, COUNT(*) AS n
    FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
    WHERE STSLC_MC_CAMPAIGN_NAME IS NOT NULL
    GROUP BY 1
), c AS (
    SELECT MKTG_UTM_NM AS utm,
           COUNT(DISTINCT CAMPAIGN_SK)      AS campaigns,
           COUNT(DISTINCT MKTG_CAMPAIGN_SK) AS mktg_campaigns
    FROM GN_DW.GOLD.DIM_CAMPAIGN
    WHERE MKTG_UTM_NM IS NOT NULL
    GROUP BY 1
)
SELECT COUNT(*)                          AS utm_kinds,
       SUM(u.n)                          AS utm_rows,
       COUNT(c.utm)                      AS matched_kinds,
       SUM(IFF(c.utm IS NOT NULL, u.n, 0)) AS matched_rows,
       MAX(c.campaigns)                  AS max_campaigns_per_utm,
       MAX(c.mktg_campaigns)             AS max_mktg_per_utm
FROM u LEFT JOIN c ON c.utm = u.utm;
-- 실측: GA4 UTM(STSLC_MC_CAMPAIGN_NAME) 660종 5,820,013행 · 캠페인 UTM 매칭 98종 3,166,939행(54.4%)
--       1 UTM ↔ 캠페인 최대 902 · ↔ 마케팅캠페인 최대 6 ⇒ 문서20 W-1(BIGQUERY_EVENT 기준 700종·52.4%)과 같은 결론

-- ============================================================
-- [N-20] BRONZE AGE 코드/라벨 혼재
-- ============================================================
SELECT COUNT(*)            AS n,
       COUNT(AGE)          AS age_filled,
       COUNT_IF(AGE = '12') AS code12_rows
FROM GN_DW.BRONZE_CRM.SND_MEMBER_LIST;
-- 실측: 10,183,916행 · AGE 채움 4,760,225(46.74% · NULL 53.26%) · 코드 12 8행

-- ============================================================
-- [N-23] 회신 묶음 (문서20 -010:91~120)
-- ============================================================

-- [N-23①] 최초등록일 집중일 — 이관 시각 흔적
SELECT TO_DATE(FRST_REGIST_DT) AS d, COUNT(*) AS n
FROM GN_DW.SILVER.CRM_MEMBER
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
-- 실측(상위): 2022-12-21 11,659 · 2021-12-30 6,185 · 2026-05-27 6,152 · 2018-01-23 6,060 · 2018-12-17 4,331
--       ⇒ 특정일 집중 = 일괄 등록(이관) 흔적 후보 — 이관 일자를 현업에 확인

-- [N-23②] 행사 마스터 부재(EVENT_SK=0) 참여 상위 행사
SELECT EVENT_BK, COUNT(*) AS n
FROM GN_DW.GOLD.FACT_EVENT_ATTENDANCE
WHERE EVENT_SK = 0
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
-- 실측: EVENT_105 199,106 · EVENT_106 71,516 · EVENT_30 733 · EVENT_43 199 · EVENT_308 59

-- [N-23③] = [M-4 → N-23③] 위 쿼리

-- ============================================================
-- [N-24] 사업목표 두 유형 · 2024 월 편성
-- ============================================================

-- [N-24①] 목표유형별 12개월 합
SELECT GOAL_TYPE_NM,
       COUNT(*) AS n,
       SUM(M01_GOAL_CNT + M02_GOAL_CNT + M03_GOAL_CNT + M04_GOAL_CNT + M05_GOAL_CNT + M06_GOAL_CNT
         + M07_GOAL_CNT + M08_GOAL_CNT + M09_GOAL_CNT + M10_GOAL_CNT + M11_GOAL_CNT + M12_GOAL_CNT) AS goal_12m
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
GROUP BY 1
ORDER BY 1;
-- 실측: 연사업 154행 348,024 · 팀 136행 348,000 (차 24)

-- [N-24②] 연도별 월 편성 합 = 연 총액 여부
SELECT YEAR,
       COUNT(*) AS n,
       SUM(YEAR_BDGT_TOT_AMT) AS year_tot,
       SUM(YEAR_BDGT_AMT_1 + YEAR_BDGT_AMT_2 + YEAR_BDGT_AMT_3 + YEAR_BDGT_AMT_4 + YEAR_BDGT_AMT_5
         + YEAR_BDGT_AMT_6 + YEAR_BDGT_AMT_7 + YEAR_BDGT_AMT_8 + YEAR_BDGT_AMT_9 + YEAR_BDGT_AMT_10
         + YEAR_BDGT_AMT_11 + YEAR_BDGT_AMT_12) AS month_sum
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
GROUP BY 1
ORDER BY 1;
-- 실측: 2024 116행 연총액 39,114,331,159 · 월합 0 · 2025 72행 월합=연총액 · 2026 70행 월합=연총액

-- ============================================================================
-- 12_agent개선과제/03_O205_원천확인쿼리.sql — O205 신규 발견 2건 BRONZE 확인용
--   ① 캠페인행사 참여 날짜 1970-08 → 원천 문제인가 DW 변환 문제인가
--   ② 장기회원 서비스 2026 수신자 급감 → 진행 중 연도 탓인가 · 현업에 무엇을 확인할까
-- Co-authored with CoCo
-- ============================================================================
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- ── ①-1 BRONZE 참여 원천: 참여일(PARTCPT_DATE) 채움 · 신청일(RQST_DATE) 형식 ──────────
--   O205 실측: 167,050행 중 PARTCPT_DATE 채움 0 (전건 NULL) · RQST_DATE 8자리 164,606행(YYYYMMDD 정상 163,217)
SELECT COUNT(*)                                        AS total_rows,
       COUNT(PARTCPT_DATE)                             AS partcpt_date_filled,
       COUNT(TRY_TO_DATE(RQST_DATE, 'YYYYMMDD'))       AS rqst_date_valid,
       MIN(TRY_TO_DATE(RQST_DATE, 'YYYYMMDD'))         AS rqst_min,
       MAX(TRY_TO_DATE(RQST_DATE, 'YYYYMMDD'))         AS rqst_max
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT;

-- ── ①-2 BRONZE 행사 마스터: 행사 시작일은 정상인가 ───────────────────────────────
--   O205 실측: CRMN_STRT_DE 8자리 3,637행 · 20090228 ~ 20261016 (정상)
SELECT LENGTH(CRMN_STRT_DE) AS len, COUNT(*) AS n, MIN(CRMN_STRT_DE) AS min_v, MAX(CRMN_STRT_DE) AS max_v
FROM GN_DW.BRONZE_CRM.TM_MS_CRMN
GROUP BY 1;

-- ── ①-3 GOLD 비교: 같은 행사의 시작일이 GOLD 에서 1970 이 됐는가 ───────────────────
--   DIM_EVENT 가 'YYYYMMDD' 문자열을 형식 없이 DATE 로 넣어 epoch 초로 해석됐다 → O205 에서 DIM_EVENT.sql 수정(dbt build 필요)
SELECT EVENT_KIND, COUNT(*) AS n, MIN(EVENT_START_DATE) AS min_d, MAX(EVENT_START_DATE) AS max_d
FROM GN_DW.GOLD.DIM_EVENT
GROUP BY 1;

-- ── ②-1 장기회원 알림톡(제목 기준) 월별 발송·수신 회원 ─────────────────────────────
--   O205 실측: 2025 = 9월 41,789명 · 10월 30,551명에 집중 · 2026 = 9월까지 그 규모 발송 없음
SELECT LEFT(m.SNDNG_STDR_DE, 7)              AS ym,
       COUNT(DISTINCT m.SNDNG_KEY)           AS send_requests,
       COUNT(DISTINCT d.MBER_NO)             AS recipients,
       LISTAGG(DISTINCT m.TIT, ' | ')        AS titles
FROM GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG m
LEFT JOIN GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS d ON d.SNDNG_KEY = m.SNDNG_KEY
WHERE m.TIT ILIKE '%장기회원%'
  AND m.SNDNG_STDR_DE >= '2024-01-01'
GROUP BY 1
ORDER BY 1;

-- ── ②-2 같은 서비스코드(MS0505/0201)에서 2026 년 제목이 바뀌었는가 ─────────────────
--   현업 확인 근거: 2025 장기회원 감사카드가 실린 코드 묶음에 2026 년 어떤 제목이 실렸는지
SELECT LEFT(m.SNDNG_STDR_DE, 7) AS ym, m.TIT, COUNT(DISTINCT d.MBER_NO) AS recipients
FROM GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG m
LEFT JOIN GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS d ON d.SNDNG_KEY = m.SNDNG_KEY
WHERE m.SNDNG_CD_ID = 'MS0505' AND m.SNDNG_DTL_CD_ID = '0201'
  AND m.SNDNG_STDR_DE >= '2025-08-01'
GROUP BY 1, 2
HAVING COUNT(DISTINCT d.MBER_NO) >= 1000
ORDER BY 1, 3 DESC;

-- ── ②-3 메일·우편 채널에도 장기회원 서비스가 나갔는가(알림톡 외 채널) ───────────────
--   우편(TM_MS_PSTMTR_SNDNG)은 제목 컬럼이 없어 서비스코드로만 구분된다 → 현업에 코드 확인 필요
SELECT 'EMAIL' AS ch, LEFT(SNDNG_STDR_DE, 4) AS yr, COUNT(*) AS send_requests
FROM GN_DW.BRONZE_CRM.TM_MS_EMAIL_SNDNG
WHERE TIT ILIKE '%장기회원%'
GROUP BY 1, 2
ORDER BY 2;

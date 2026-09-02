-- IDENTITY_MEMBER_XREF: GA 신원↔CRM 회원 브리지 (교차소스 유일 예외), 정본 09 STEP7.
-- Co-authored with CoCo
-- 의존성(7-C): ref 로 BIGQUERY_IDENTITY·CRM_MEMBER 후행 강제. LEFT JOIN(UNMATCHED 보존, C1). CHILD_CODE 제외.
--
-- 🟢 [2026-08-19 O87] GA4-LEN-1 대응 — 매칭 분모에서 비회원 ID 를 분리한다.
--    무엇이 문제였나: GA4 `user_id` 는 전 기간 실측 **6종**이고 CRM 조인 가능한 것은
--    7자리(MBER_NO)·`S`+8자리(ONCE_MBER_NO) 두 종뿐이다. `app-`(241 id)·이메일(1)·문자열
--    `'null'`(1) 은 **애초에 회원번호가 아니다**. 종전 로직은 이들을 `MEMBER_DK IS NULL` 로
--    묶어 **'UNMATCHED'** 로 냈고, 그러면 「회원번호인데 CRM 에서 못 찾음」과
--    「회원번호가 아님」이 한 값으로 뭉개져 **채움률 분모가 조용히 왜곡**된다(R2-7-1 과 같은 축).
--    ⇒ MATCH_METHOD 에 **'NOT_A_MEMBER_ID'** 를 신설해 두 사건을 분리 표기한다.
--       채움률 계산 = MEMBER_ID_EXACT / (MEMBER_ID_EXACT + UNMATCHED) — NOT_A_MEMBER_ID 는 분모 밖.
--    🔴 라벨 창작이 아니다 — GA_MEMBER_ID 원문은 그대로 보존하고 분류만 부여한다(DEC-17-B).
--
-- ⚠️ GA_MEMBER_ID 는 VARCHAR(64) 다(GA4-LEN-1 조치①). MEMBER_DK 는 VARCHAR(10) 이므로
--    64자 값은 조인에서 자연히 불일치한다 — 그것을 UNMATCHED 로 세지 않기 위해 위 분기가 필요하다.

SELECT
    g.USER_PSEUDO_ID    AS USER_PSEUDO_ID,
    g.GA_MEMBER_ID      AS GA_MEMBER_ID,
    g.ID_SCHEME         AS ID_SCHEME,
    g.MEMBER_TYPE       AS MEMBER_TYPE,
    m.MEMBER_DK         AS MEMBER_DK,
    m.HMPG_ID           AS HOMEPAGE_ID,
    g.ID_RESOLUTION     AS ID_RESOLUTION,
    CASE WHEN m.MEMBER_DK IS NOT NULL                              THEN 'MEMBER_ID_EXACT'
         WHEN g.ID_SCHEME IN ('MBER_NO','ONCE_MBER_NO')            THEN 'UNMATCHED'
         ELSE 'NOT_A_MEMBER_ID' END                                AS MATCH_METHOD,
    CASE WHEN m.MEMBER_DK IS NULL        THEN 'NONE'
         WHEN g.ID_RESOLUTION = 'DIRECT' THEN 'HIGH'
         ELSE 'MEDIUM' END                                         AS MATCH_CONFIDENCE,
    'GA4+CRM'                       AS DW_SOURCE_SYSTEM,
    'SILVER.BIGQUERY_IDENTITY+CRM_MEMBER' AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()             AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()             AS DW_UPDATE_TS,
    NULL                            AS DW_BATCH_ID
FROM GN_DW.SILVER.BIGQUERY_IDENTITY g
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m
    ON g.GA_MEMBER_ID = m.MEMBER_DK
   -- 🔴 회원번호 체계인 행만 조인 대상이다. 이 조건이 없으면 64자 값이 조인을 타고
   --    (매칭은 어차피 안 되지만) 분모 판정이 MATCH_METHOD 한 곳에만 의존하게 된다.
   AND g.ID_SCHEME IN ('MBER_NO','ONCE_MBER_NO')
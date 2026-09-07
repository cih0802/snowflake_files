-- BIGQUERY_IDENTITY: 신원 1행/pseudo (Q1 접두 분기 + 세션 채움), 정본 09 STEP6.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards + LATERAL FLATTEN → ref('BIGQUERY_REFINED_DATA').
-- 🔄 [2026-08-21] BIGQUERY_REFINED_DATA 가 외부 Python 적재로 전환되며 파생을 잃었다 —
--    신설 `BIGQUERY_BASIC`(dbt) 이 그 파생을 되살리므로 ref() 로 되돌린다(source() → ref('BIGQUERY_BASIC')).
--    🟢 종전 주석 「단방향 유지 : BIGQUERY_EVENT 참조 금지 → BRONZE 에서 세션 채움 CTE 재계산」은 폐기.
--       그 제약이 만든 것은 **동일 로직의 중복 구현 2벌**이었고, 실제로 BIGQUERY_EVENT 와
--       이 모델의 GROUP BY 절이 서로 달랐다(11컬럼 ↔ 5컬럼). 계층 내 파생을 허용하면
--       기반 테이블 1곳에서 승격이 끝나므로 그 불일치가 구조적으로 사라진다.
--       허용 근거 = DEC-37(`20_issue/30_설계_의사결정.md`) · 선례 = AGENCY_AD_ROW_* 계열.
--    ⚠️ 여전히 BIGQUERY_EVENT 를 참조하지 않는다 — 둘은 **형제**이고 기반 테이블을 공유한다.
--       (팩트를 차원의 원천으로 삼으면 GOLD 의 팩트 재적재가 차원을 흔든다.)
--
-- 🟢 GA4-LEN-1 해소 — Q1 의 2분기(S% / else)로는 부족했다. 전 기간 `user_id` 실측
--    (O87-B · 계정 UA93987 · 정본 = `20_issue/90_해소완료_로그.md` §1-B-실측)에서
--    **CRM 조인 가능한 것은 `MBER_NO`(7자리)·`ONCE_MBER_NO`(S+8자리) 두 종뿐**이고
--    `APP`·`EMAIL`·`INVALID` 는 회원번호가 아니다. 종전 로직은 그것들을 전부
--    `else → FDRM/MBER_NO` 로 밀어넣어 IDENTITY_MEMBER_XREF 매칭 분모를 오염시켰다.
--    ⇒ ID_SCHEME 으로 분기한다: 회원 체계 2종만 채우고 나머지는 **둘 다 NULL**(MEMBER_TYPE 도 NULL).
--    🔴 R2-7 준수 — 값이 없는 자리를 라벨로 창작하지 않는다. 「왜 NULL 인가」는 ID_SCHEME 이 답한다.
--    🔴 **[O87-B 정정] 종전 문서의 「6종」은 불완전했다** — 리터럴 `undefined`(293행·1id)가
--       누락돼 `ONCE_MBER_NO` 버킷에 흡수 계상돼 있었다. 실측 확정 = **7종**이고
--       `ONCE_MBER_NO` 는 종전 기재 194,763행/16,907id → **194,470행/16,906id** 다.
--
-- grain = 1행 / USER_PSEUDO_ID. 🔴 범위 제한 없음(전기간) — 신원은 누적 상태이고,
--    범위 제한하면 그 창 밖에서만 로그인한 pseudo 가 익명으로 바뀐다.

WITH base AS (
    SELECT
        USER_PSEUDO_ID,
        USER_ID,
        GA_SESSION_KEY
    FROM GN_DW.SILVER.BIGQUERY_BASIC
),
-- 세션 단위 집계 → 2단계 채움(설계문서 07 §5-A). COUNT(DISTINCT) OVER 미지원 대응.
sess AS (
    SELECT
        GA_SESSION_KEY,
        COUNT(DISTINCT USER_ID) AS n_id,
        MAX(USER_ID)            AS sess_uid
    FROM base
    WHERE GA_SESSION_KEY IS NOT NULL
    GROUP BY GA_SESSION_KEY
),
filled AS (
    SELECT
        b.USER_PSEUDO_ID,
        CASE WHEN b.USER_ID IS NOT NULL                     THEN b.USER_ID
             WHEN b.GA_SESSION_KEY IS NOT NULL AND s.n_id = 1 THEN s.sess_uid
             ELSE NULL END AS member_id,
        CASE WHEN b.USER_ID IS NOT NULL                     THEN 'DIRECT'
             WHEN b.GA_SESSION_KEY IS NOT NULL AND s.n_id = 1 THEN 'SESSION_FILL'
             ELSE NULL END AS id_resolution
    FROM base b
    LEFT JOIN sess s
        ON b.GA_SESSION_KEY IS NOT NULL
       AND s.GA_SESSION_KEY = b.GA_SESSION_KEY
),
-- 채움 결과(member_id)에 ID 체계를 재부여한다. 세션 채움으로 들어온 값도 분류가 필요하므로
-- 기반 테이블의 ID_SCHEME 을 그대로 끌어오지 않고 **채움 후 값**을 기준으로 다시 판정한다.
agg AS (
    SELECT
        USER_PSEUDO_ID,
        MAX(member_id)                                          AS ga_member_id,
        IFF(MIN(IFF(id_resolution = 'DIRECT', 0, 1)) = 0,
            'DIRECT', 'SESSION_FILL')                           AS id_resolution
    FROM filled
    WHERE member_id IS NOT NULL
    GROUP BY USER_PSEUDO_ID
)
SELECT
    a.USER_PSEUDO_ID                                            AS USER_PSEUDO_ID,
    a.ga_member_id                                              AS GA_MEMBER_ID,
    CASE WHEN a.ga_member_id RLIKE '^[0-9]{7}$'  THEN 'MBER_NO'
         WHEN a.ga_member_id RLIKE '^S[0-9]{8}$' THEN 'ONCE_MBER_NO'
         WHEN STARTSWITH(a.ga_member_id, 'app-') THEN 'APP'
         WHEN POSITION('@', a.ga_member_id) > 0  THEN 'EMAIL'
         -- 원천 오류값 2종(프런트엔드 미정의/널이 문자열로 흘러든 것). 회원번호가 아니다.
         -- 🔴 `undefined` 는 O87-B 실측으로 발견됐다(293행 · 1id · 2024-03-25~2026-06-08) —
         --    종전 문서의 「6종」에 없었고 `ONCE_MBER_NO` 에 흡수 계상돼 그 버킷이 과대였다.
         WHEN LOWER(a.ga_member_id) IN ('null', 'undefined') THEN 'INVALID'
         ELSE 'UNCLASSIFIED' END                                AS ID_SCHEME,
    -- 🔴 회원구분은 CRM 회원번호 체계일 때만 부여한다. 그 밖은 NULL(창작 금지 · R2-7).
    CASE WHEN a.ga_member_id RLIKE '^S[0-9]{8}$' THEN 'ONCE'
         WHEN a.ga_member_id RLIKE '^[0-9]{7}$'  THEN 'FDRM'
         ELSE NULL END                                          AS MEMBER_TYPE,
    IFF(a.ga_member_id RLIKE '^[0-9]{7}$',  a.ga_member_id, NULL) AS MBER_NO,
    IFF(a.ga_member_id RLIKE '^S[0-9]{8}$', a.ga_member_id, NULL) AS ONCE_MBER_NO,
    a.id_resolution                                             AS ID_RESOLUTION,
    'GA4'                             AS DW_SOURCE_SYSTEM,
    'SILVER.BIGQUERY_BASIC'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
    NULL                              AS DW_BATCH_ID
FROM agg a
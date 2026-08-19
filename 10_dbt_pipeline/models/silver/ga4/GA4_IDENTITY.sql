-- GA4_IDENTITY: 신원 1행/pseudo (Q1 접두 분기 + 세션 채움), 정본 09 STEP6.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards + LATERAL FLATTEN → ref('BIGQUERY_REFINED_DATA').
--    🟢 종전 주석 「단방향 유지 : GA4_EVENT 참조 금지 → BRONZE 에서 세션 채움 CTE 재계산」은 폐기.
--       그 제약이 만든 것은 **동일 로직의 중복 구현 2벌**이었고, 실제로 GA4_EVENT 와
--       이 모델의 GROUP BY 절이 서로 달랐다(11컬럼 ↔ 5컬럼). 계층 내 파생을 허용하면
--       기반 테이블 1곳에서 승격이 끝나므로 그 불일치가 구조적으로 사라진다.
--       허용 근거 = DEC-36(`20_issue/30_설계_의사결정.md`) · 선례 = AGENCY_AD_ROW_* 계열.
--    ⚠️ 여전히 GA4_EVENT 를 참조하지 않는다 — 둘은 **형제**이고 기반 테이블을 공유한다.
--       (팩트를 차원의 원천으로 삼으면 GOLD 의 팩트 재적재가 차원을 흔든다.)
--
-- 🟢 GA4-LEN-1 해소 — Q1 의 2분기(S% / else)로는 부족했다. 전 기간 user_id 실측 6종 중
--    **CRM 조인 가능한 것은 7자리 포맷뿐**이고 `app-`(241id)·이메일(1)·문자열 'null'(1)은
--    회원번호가 아니다. 종전 로직은 그것들을 전부 `else → FDRM/MBER_NO` 로 밀어넣어
--    IDENTITY_MEMBER_XREF 매칭 분모를 오염시켰다.
--    ⇒ 기반 테이블의 ID_SCHEME 으로 분기한다:
--       MBER_NO → MBER_NO 채움 / ONCE_MBER_NO → ONCE_MBER_NO 채움 /
--       APP·EMAIL·INVALID·UNCLASSIFIED → **둘 다 NULL** (MEMBER_TYPE 도 NULL).
--    🔴 R2-7 준수 — 값이 없는 자리를 라벨로 창작하지 않는다. 「왜 NULL 인가」는 ID_SCHEME 이 답한다.
--
-- grain = 1행 / USER_PSEUDO_ID. 🔴 범위 제한 없음(전기간) — 신원은 누적 상태이고,
--    범위 제한하면 그 창 밖에서만 로그인한 pseudo 가 익명으로 바뀐다.
{{ config(materialized='incremental') }}
WITH base AS (
    SELECT
        USER_PSEUDO_ID,
        USER_ID,
        GA_SESSION_KEY
    FROM {{ ref('BIGQUERY_REFINED_DATA') }}
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
         WHEN LOWER(a.ga_member_id) = 'null'     THEN 'INVALID'
         ELSE 'UNCLASSIFIED' END                                AS ID_SCHEME,
    -- 🔴 회원구분은 CRM 회원번호 체계일 때만 부여한다. 그 밖은 NULL(창작 금지 · R2-7).
    CASE WHEN a.ga_member_id RLIKE '^S[0-9]{8}$' THEN 'ONCE'
         WHEN a.ga_member_id RLIKE '^[0-9]{7}$'  THEN 'FDRM'
         ELSE NULL END                                          AS MEMBER_TYPE,
    IFF(a.ga_member_id RLIKE '^[0-9]{7}$',  a.ga_member_id, NULL) AS MBER_NO,
    IFF(a.ga_member_id RLIKE '^S[0-9]{8}$', a.ga_member_id, NULL) AS ONCE_MBER_NO,
    a.id_resolution                                             AS ID_RESOLUTION,
    'GA4'                             AS DW_SOURCE_SYSTEM,
    'SILVER.BIGQUERY_REFINED_DATA'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
    NULL                              AS DW_BATCH_ID
FROM agg a

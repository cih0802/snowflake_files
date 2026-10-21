-- FACT_GA_CHILD_VIEW: GA 결연아동 페이지 조회 팩트 (공#122 결연아동코드)
-- Co-authored with CoCo
-- 🆕 [2026-10-16 O239 · G1 잔여 ① · 사용자 지시 = 추천안 2개 동시 구현 → Agent 실사용 후 현업 결정]
--   정의(지표사전 공#122) = 「페이지 경로+쿼리 문자열」에서 childnum= 뒤 값(예: CMR-0102-002758).
--   왜 새 팩트인가 = FACT_BIGQUERY_BEHAVIOR 는 PAGE_PATH(? 앞)로 group by 하고 PAGE_LOCATION 을 MAX 로만 남긴다
--     ⇒ 같은 페이지의 서로 다른 childnum 이 한 행으로 뭉개져 코드가 유실된다(그 팩트 grain 을 바꾸면 하류 SV·WIDE 가 흔들린다).
--   grain = DATE_SK × PAGE_PATH × CHILD_CODE_RAW × URL_MEMBER_DK(값 없음 = NULL 그룹).
--   추천안 2개를 플래그로 함께 싣는다(값은 원천 그대로 · 바꾸지 않는다):
--     · 안A(형식 기준) = IS_FORMAT_VALID — 영문3-숫자4-숫자6(예시와 같은 형태)인 코드만 결연아동코드로 센다.
--     · 안B(CRM 대조 기준) = IS_CRM_MATCHED — SILVER.CRM_CHILD.CHILD_NO 에 실재하는 코드만 센다(CHILD_CD 연결).
--   🔴 childnum= 값이 비어 있는 행은 CHILD_CODE_RAW = NULL 로 남긴다(창작 금지 · R2-7-1) — 두 안 모두 세지 않는다.
--   🔴 적재 = 일반 GOLD fact 경로(TRUNCATE 후 전량 재계산 · gold_fact_purge 의 RANGED_FACTS 비등재) —
--     SILVER.BIGQUERY_EVENT 전 기간에서 다시 만들므로 롤링 창 백필 의무가 없다.
{{ config(
    tags=['gold_ready']
) }}

with e as (
    select
        EVENT_DT,
        USER_PSEUDO_ID,
        EVENT_NAME,
        COALESCE(SPLIT_PART(PAGE_LOCATION, '?', 1), '(none)')                                   as PAGE_PATH,
        NULLIF(UPPER(TRIM(REGEXP_SUBSTR(PAGE_LOCATION, '[?&]childnum=([^&#]*)', 1, 1, 'ie', 1))), '') as CHILD_CODE_RAW,
        REGEXP_SUBSTR(PAGE_LOCATION, '[?&]memnum=([0-9]+)', 1, 1, 'ie', 1)                     as URL_MEMBER_DK
    from {{ ref('BIGQUERY_EVENT') }}
    where PAGE_LOCATION ilike '%childnum=%'
),
-- CHILD_NO → CHILD_CD 1:1 축약(중복 CHILD_NO 가 있어도 fan-out 0)
ch as (
    select UPPER(TRIM(CHILD_NO)) as CHILD_NO, MIN(CHILD_CD) as CHILD_CD
    from {{ ref('CRM_CHILD') }}
    where CHILD_NO is not null
    group by 1
)

select
    COALESCE({{ date_sk('e.EVENT_DT') }}, 0)                              as DATE_SK,
    e.PAGE_PATH                                                           as PAGE_PATH,
    e.CHILD_CODE_RAW                                                      as CHILD_CODE_RAW,
    COALESCE(REGEXP_LIKE(e.CHILD_CODE_RAW, '[A-Z]{3}-[0-9]{4}-[0-9]{6}'), FALSE) as IS_FORMAT_VALID,
    (MAX(ch.CHILD_CD) is not null)                                        as IS_CRM_MATCHED,
    MAX(ch.CHILD_CD)                                                      as CHILD_CD,
    e.URL_MEMBER_DK                                                       as URL_MEMBER_DK,
    COUNT(*)                                                              as EVENT_CNT,
    COUNT_IF(e.EVENT_NAME = 'page_view')                                  as VIEW_CNT,
    COUNT(DISTINCT e.USER_PSEUDO_ID)                                      as USER_CNT,
    {{ gold_meta('BIGQUERY') }}
from e
left join ch
       on ch.CHILD_NO = e.CHILD_CODE_RAW
group by e.EVENT_DT, e.PAGE_PATH, e.CHILD_CODE_RAW, e.URL_MEMBER_DK

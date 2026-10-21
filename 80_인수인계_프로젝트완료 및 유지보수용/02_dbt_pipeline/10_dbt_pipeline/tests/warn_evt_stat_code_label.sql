-- =============================================================================
-- Purpose    : [2026-10-15 O232] 행사 참여상태 코드 ↔ 라벨 드리프트 경고 — FACT_EVENT_ATTENDANCE 는 이제 **코드**로 판정한다.
-- Target     : dbt singular test warn_evt_stat_code_label (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_EVENT_PARTICIPATION
-- Issue      : O232
-- =============================================================================
-- [2026-10-15 O232] 행사 참여상태 코드 ↔ 라벨 드리프트 경고 — FACT_EVENT_ATTENDANCE 는 이제 **코드**로 판정한다.
--
-- 왜: 종전 판정은 라벨 문자열(`'참여'`·`'대기%'`·`'Success'` 등)이라 원천 라벨이 바뀌면 지표가 조용히 0 이 됐다.
--   O232 에서 상태코드 판정(`macros/gn_biz_codes.sql` gn_evt_stat · gn_evt_attended)으로 바꿨다(실측 결과 동일).
--   이제 반대 위험이 남는다 — 원천이 **같은 코드의 뜻을 바꾸거나 새 코드를 추가**하면 코드 판정이 낡는다.
-- 반환 행 = ㉠ 판정에 쓰는 코드의 라벨이 기대와 다름 ㉡ MS006 에 미등록 코드 출현(1~6 밖).
-- 판정: 반환 행이 있으면 WARN → gn_biz_codes.sql 의 EVT_* 키와 이 표를 함께 고친다.
{{ config(severity = 'warn') }}

with expected as (
    select column1 as GRP, column2 as CD, column3 as NM
    from values
        ('MS006', '1', '신청'),
        ('MS006', '2', '참여'),
        ('MS006', '3', '불참'),
        ('MS006', '4', '대기'),
        ('MS006', '5', '취소'),
        ('MS006', '6', '대기(결제)'),
        ('MS304', '110', 'Success')
),
actual as (
    select distinct PARTCPT_STAT_GROUP as GRP, PARTCPT_STAT_CD as CD, PARTCPT_STAT_NM as NM
    from {{ ref('CRM_EVENT_PARTICIPATION') }}
    where PARTCPT_STAT_GROUP in ('MS006', 'MS304')
)
select 'LABEL_CHANGED:' || a.GRP || '-' || a.CD as CHECK_NM, a.NM as ACTUAL_NM, e.NM as EXPECTED_NM
from actual a
join expected e on e.GRP = a.GRP and e.CD = a.CD
where COALESCE(a.NM, '') <> e.NM
union all
select 'UNREGISTERED_CODE:' || a.GRP || '-' || COALESCE(a.CD, 'NULL'), a.NM, NULL
from actual a
where a.GRP = 'MS006'
  and COALESCE(a.CD, '') not in (select CD from expected where GRP = 'MS006')

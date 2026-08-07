-- DIM_GA_SOURCE: 트래픽소스 차원 (GA4_TRAFFIC_SOURCE → source/medium grain)
-- Co-authored with CoCo
-- ⚠️ grain=(UTM_SOURCE,UTM_MEDIUM): GA4_EVENT 팩트가 조인 가능한 유일 grain(content/term은 이벤트에 부재).
--    content/term/source_medium 은 대표값(MAX) 보조표시 — 팩트 팬아웃 방지 위해 grain에서 제외.


with src as (
    select
        UTM_SOURCE,
        UTM_MEDIUM,
        MAX(UTM_CONTENT)    as UTM_CONTENT,
        MAX(UTM_TERM)       as UTM_TERM,
        MAX(SOURCE_MEDIUM)  as SOURCE_MEDIUM,
        -- 🟢 [DEC-30 2026-08-04 E군 배선] GA4 표준 채널그룹 — GOLD 에 대응 컬럼이 없었다.
        --   실측: 채움 2,167/2,167=**100%** · 14종 · grain (UTM_SOURCE,UTM_MEDIUM) 에
        --   **93.8% 함수종속**(다중값 9/146·최대 4종) → 기존 UTM_CONTENT/TERM 과 동일한
        --   MAX() 대표값 패턴으로 안전하다(그쪽은 다중 55/146·최대 125, 40/146·최대 266).
        --   ⚠️ `SOURCE_MEDIUM` 은 source/medium 을 이어붙인 파생 문자열이고, 이 컬럼은
        --      GA4 가 산정한 **표준 채널 분류**다 — 다른 개념이므로 대체하지 않는다.
        MAX(DEFAULT_CHANNEL_GROUP) as DEFAULT_CHANNEL_GROUP
    from GN_DW.SILVER.GA4_TRAFFIC_SOURCE
    group by UTM_SOURCE, UTM_MEDIUM
)

select
    ABS(HASH(COALESCE(CAST(UTM_SOURCE AS VARCHAR), '∅') || '‖' || COALESCE(CAST(UTM_MEDIUM AS VARCHAR), '∅'))) as GA_SOURCE_SK,
    UTM_SOURCE                      as UTM_SOURCE,
    UTM_MEDIUM                      as UTM_MEDIUM,
    UTM_CONTENT                     as UTM_CONTENT,
    UTM_TERM                        as UTM_TERM,
    SOURCE_MEDIUM                   as SOURCE_MEDIUM,
    DEFAULT_CHANNEL_GROUP           as DEFAULT_CHANNEL_GROUP,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b21b7934-7c9a-4bb8-bfb2-a3d18e0205f5'                    AS DW_BATCH_ID
from src
union all
-- 순서9 Unknown 멤버(GA_SOURCE_SK=0): fact 의 미매핑 GA_SOURCE_SK 센티넬 라우팅 대상.
select 0, '(unknown)', '(unknown)', NULL, NULL, NULL, NULL, 'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b21b7934-7c9a-4bb8-bfb2-a3d18e0205f5'                    AS DW_BATCH_ID
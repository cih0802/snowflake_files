-- DIM_DEVICE: 디바이스 차원 (GA4_DEVICE → DEVICE_TYPE DISTINCT, GOLD 축약)
-- Co-authored with CoCo
-- ⚠️ [2026-07-28 DEC-10] 멤버 2종 신설/보강 — 근거: 문서30 §1-A · 설계 §3-A-5
--   1) `(해당없음)` 멤버 신설: 방송광고(VIDEO·REBRDC)는 **기기 개념 자체가 없다**(실측 37,886행 전량 NULL).
--      이를 `(unknown)`(진짜 미상)과 한 멤버에 담으면 지표 공14(기기별)를 해석할 수 없으므로 의미를 분리한다.
--      `(해당없음)`은 *값이 확정된 정상 멤버*이므로 **해시 SK** 를 부여한다 — `0` 은 진짜 미상 전용으로 보존.
--      프로젝트 센티넬 원칙 유지: `-1` 미사용 · `0`=Unknown 정본.
--   2) `DEVICE_SCOPE_DESC` 컬럼 신설: 멤버 의미 자기설명. 분석가가 **차원만 조회해도** `(해당없음)`의
--      뜻을 알 수 있게 한다(팩트 조인·문서 참조 없이 식별 가능 — DEC-10 전제조건).
-- ⚠️ `APP` 은 GA4 platform=WEB 단일 실측으로 현 데이터에 미생성(G-5). 분류 로직(GA4_DEVICE)은 유지.


with src as (
    select distinct DEVICE_TYPE
    from GN_DW.SILVER.GA4_DEVICE
    where DEVICE_TYPE is not null
      -- SILVER 미분류값은 아래 Unknown 멤버(SK=0)로 라우팅 — 중복 행 방지(2026-07-27)
      and DEVICE_TYPE <> '(unknown)'
)

select
    ABS(HASH(COALESCE(CAST(DEVICE_TYPE AS VARCHAR), '∅')))  as DEVICE_SK,
    DEVICE_TYPE                     as DEVICE_TYPE,
    case DEVICE_TYPE
         when 'PC'  then '데스크톱(GA4 platform=WEB × device.category=desktop)'
         when 'M'   then '모바일(GA4 device.category=mobile/tablet)'
         when 'APP' then '앱(GA4 platform=ANDROID/IOS) — 현 데이터 미생성(G-5)'
    end                             as DEVICE_SCOPE_DESC,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '0a0f03d1-d7c1-4e10-a7c3-7a79d0fcb1ad'                    AS DW_BATCH_ID
from src
union all
-- DEC-10 `(해당없음)` 멤버: 방송광고 전용. 해시 SK(정상 멤버) — FAD.AD_TYPE IN ('VIDEO','REBROADCAST') 과 동반.
select ABS(HASH(COALESCE(CAST('(해당없음)' AS VARCHAR), '∅'))), '(해당없음)',
       '방송광고(TV·재방송) — 기기 개념 없음', 'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '0a0f03d1-d7c1-4e10-a7c3-7a79d0fcb1ad'                    AS DW_BATCH_ID
union all
-- 순서9 Unknown 멤버(DEVICE_SK=0): fact 의 미매핑 DEVICE_SK 센티넬 라우팅 대상.
select 0, '(unknown)', '기기 정보 미상 또는 매핑 실패(센티넬)', 'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '0a0f03d1-d7c1-4e10-a7c3-7a79d0fcb1ad'                    AS DW_BATCH_ID
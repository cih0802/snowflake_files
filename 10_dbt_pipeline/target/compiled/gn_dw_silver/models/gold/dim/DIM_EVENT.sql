-- DIM_EVENT: 행사 차원 스캐폴드 (CRM_EVENT, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ APPLY_CHANNEL 원천/파생규칙 미정(ADMIN A-10 대기).


with e as (
    select * from GN_DW.SILVER.CRM_EVENT
)

select
    ABS(HASH(COALESCE(CAST(EVENT_KEY AS VARCHAR), '∅')))                  as EVENT_SK,
    EVENT_KEY                                     as EVENT_BK,
    EVENT_SOURCE                                  as EVENT_KIND,
    -- [2026-08-03 O27] `ELSE '미상'` 제거 — P31: ELSE 절은 도메인 확장을 조용히 삼킨다.
    --   실측 `EVENT_SOURCE` 도메인은 'EVENT'·'CRMN' 2종뿐이므로 현 데이터에서 동작 변화는 없고,
    --   원천에 3번째 값이 생기면 **NULL 로 드러난다**(종전에는 '미상'으로 은폐됐다).
    --   ⚠️ 이 컬럼은 코드사전에 대응 그룹이 없는 **파생 라벨**이라 CRM_CODE 조인 대상이 아니다.
    CASE EVENT_SOURCE WHEN 'EVENT' THEN '일반행사' WHEN 'CRMN' THEN '캠페인행사' END as EVENT_KIND_NAME,
    EVENT_DIV_CD                                  as EVENT_CATEGORY,
    EVENT_NM                                      as EVENT_NAME,
    TRY_TO_DATE(STRT_DE, 'YYYYMMDD')              as EVENT_START_DATE,
    TRY_TO_DATE(END_DE, 'YYYYMMDD')               as EVENT_END_DATE,
    CAST(NULL AS VARCHAR)                          as APPLY_CHANNEL,   -- ⚠️ A-10 대기
    -- 🟢 [DEC-30 2026-08-04] 모집인원 이관 — 참여 팩트가 아니라 **행사 차원**이 정본이다.
    --   원천 `CRM_EVENT.RCRIT_PSNNL_CO` 채움 3,361/3,786=88.8%·74종.
    --   🔴 종전엔 `FACT_EVENT_PARTICIPATION.RECRUIT_CNT`(전건 0) 자리에 넣으려 했으나
    --      모집인원은 행사 속성이라 참여행마다 반복되면 SUM 이 **101.0배 과대계상**된다
    --      (행사 grain 참값 4,513,184 vs 참여 grain 456,007,553 · 최대 3,718참여/행사).
    --      §18-D ②(grain 함수종속) 실패 사례 → FEP 컬럼은 DROP 하고 여기로 옮겼다.
    RCRIT_PSNNL_CO                                as RECRUIT_HEADCOUNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '17b6585e-5115-4071-a904-810c19eaeb12'                    AS DW_BATCH_ID,
    -- 🟢 [2026-08-11 O59-N · DEC-35 2단계] 행사구분 코드→라벨. 전파만 한다 — 코드사전 조인은 SILVER 소관이다
    --    (같은 조인을 두 계층에 두면 갈라진다 · 문서30 §23-J). 신설 위치 = 감사컬럼 뒤(정본 DDL 규약).
    EVENT_DIV_GROUP                               as EVENT_CATEGORY_GROUP,
    EVENT_DIV_NM                                  as EVENT_CATEGORY_NAME
from e

union all
-- unknown 멤버(SK=0): 팩트 EVENT_SK=0(미매핑) 조인 유실 방지
-- [2026-08-03 O27] 센티넬 표기 통일: EVENT_KIND_NAME 도 '(미매핑)' 을 쓴다.
--   종전에는 같은 한 행 안에서 다른 컬럼은 '(미매핑)' 인데 이 컬럼만 '미상' 이었다(표기 분열).
--   이 1행이 GOLD 전체에 남아 있던 마지막 '미상' 이다(문서10 §14-D 실측) → 이로써 GOLD '미상' 은 소멸.
select 0, '(미매핑)', NULL, '(미매핑)', NULL, '(미매핑)', NULL, NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '17b6585e-5115-4071-a904-810c19eaeb12'                    AS DW_BATCH_ID,
    -- ⚠️ 센티넬 행도 컬럼 수를 맞춰야 한다(UNION ALL 위치 대응). 코드군·라벨은 값이 없으므로 NULL —
    --    '(미매핑)' 을 넣지 않는다: 이 행은 「행사 미매핑」을 뜻하고 코드군·라벨 축의 미매핑이 아니다.
    NULL, NULL
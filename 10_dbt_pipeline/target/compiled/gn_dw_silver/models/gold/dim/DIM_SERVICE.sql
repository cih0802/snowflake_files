-- DIM_SERVICE: 발송 서비스 차원 (CRM_SEND_REQUEST DISTINCT) — grain=(CHANNEL, SUBTYPE) 10행 + 센티넬
-- Co-authored with CoCo
-- 🟢 [DEC-30 2026-08-04] `SEND_TYPE_L/M/S` 3컬럼을 **DIM_SEND_TYPE 으로 이관**하고 여기서 제거했다.
--   종전 주석 *"코드체계 검수 대기(설계 §8)"* 는 **원인 오진이었다** — 코드체계는 확정 가능했고
--   (TOP=`CRM_CODE.CD_ID` 12종·MID 16·BOT 42·경로 65) 실제 문제는 **grain 불일치**였다:
--   본 차원 grain 은 10행인데 대/중/소를 넣으면 74행이 되어 함수종속이 깨지고 `SERVICE_SK` 산식이
--   바뀌어 이미 99.97% 적재된 `FACT_SERVICE_EVENT.SERVICE_SK` 를 파괴한다.
--   → 정본 소재지 = `DIM_SEND_TYPE`(경로 grain) · FSE 는 `SEND_TYPE_SK` 로 별도 참조한다.
--   ⚠️ 정본 지표 #133·#134·#135 는 **소멸하지 않는다** — 소재지만 옮겼다(DEC-28 §18-C "DROP 금지"의 취지 = 대체 소재지 없이 지우지 말라).


with src as (
    select distinct SEND_CHANNEL, SNDNG_TY_CD
    from GN_DW.SILVER.CRM_SEND_REQUEST
)

select
    ABS(HASH(COALESCE(CAST(SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(SNDNG_TY_CD AS VARCHAR), '∅'))) as SERVICE_SK,
    SNDNG_TY_CD                                   as SUBTYPE,
    SEND_CHANNEL                                  as CHANNEL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b293c87f-c2c1-42e5-b50c-69029085db76'                    AS DW_BATCH_ID
from src

union all
-- unknown 멤버(SK=0): 팩트 SERVICE_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)',
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b293c87f-c2c1-42e5-b50c-69029085db76'                    AS DW_BATCH_ID
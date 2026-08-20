-- DIM_SPONSORSHIP: 후원사업 차원 스캐폴드 (CRM_SPONSORSHIP, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- [2026-08-19 O89] 분류 3계층 라벨 배선 — DIV_CD/DIV_NAME(CM035) + GROUP_NAME(CM003).
--   현업 요구 = "후원사업 상위/하위 분류를 각각 라벨로". 실측으로 대상 컬럼이 교정됐다:
--   🔴 현업이 지목한 `SPNSR_BSNS_NO` 는 분류가 아니라 **회원별 후원약정 일련번호**다
--      (distinct 2,170,574 vs ID 29 · 99.999% 가 단일 회원 전속 · 동일 ID 아래 복수 NO).
--      라벨 원천이 없어 배선 불가다. 하위 실체는 결연 아동(469,402)이고 라벨 가능 축은
--      사업장(220)·국가(34)지만 **해외아동결연 한정 + 회원 다중결연**이라 이 50행 차원에
--      들어갈 수 없다(O8 과 동일 fan-out) → 별건 설계 대기.
--   ✅ 실재하는 3계층 = DIV_NAME(정기/일시) → GROUP_NAME(약칭 6종) → SPONSORSHIP_NAME(사업명).
--      `SPONSORSHIP_ABBR` 은 기존 컬럼이고 라벨만 없었다(O25/G3/O37 동일 패턴).
--   🟡 SPB-G 근거 확보 · 라이브 대조 대기 — ABBR 코드사전이 CM003(후원약칭)으로 특정됐다.
--      🔴 「종결」이라고 적었던 것은 오판정이라 격하했다(라이브 0행이라 대조 불가 · R2-8-4-c · 계정 NX55103).
--   🔴 `SPNSR_BSNS_NO` 는 Q15 가 이미 닫은 항목이다 — "ID=DIM 키(마스터 50)·NO=관계번호·크로스워크"
--      (크로스워크 = SILVER.CRM_SPONSOR_RELATION). 위 기술은 Q15 와 일치하며 신규 발견이 아니다.
--   ⚠️ 코드 조인은 USE_YN 무필터다(O37 선례). 원천 코드 부재 시 NULL 이며 '(미매핑)' 창작 금지(P21).


with s as (
    select * from GN_DW.SILVER.CRM_SPONSORSHIP
),
-- CM035 정기일시후원구분: 1=정기후원 · 2=일시후원
cd_div as (
    select DTL_CD_ID, DTL_CD_NM
    from GN_DW.SILVER.CRM_CODE
    where CD_ID = 'CM035'
),
-- CM003 후원약칭: 1=국내 · 2=결연 · 3=해외구호 · 4=북한 · 5=기타 · 6=해외 · 7=선물금(미사용)
cd_grp as (
    select DTL_CD_ID, DTL_CD_NM
    from GN_DW.SILVER.CRM_CODE
    where CD_ID = 'CM003'
)

select
    ABS(HASH(COALESCE(CAST(s.SPNSR_BSNS_ID AS VARCHAR), '∅')))            as SPONSORSHIP_SK,
    s.SPNSR_BSNS_ID                               as SPONSORSHIP_BK,
    s.SPNSR_BSNS_NM                               as SPONSORSHIP_NAME,
    s.SPNSR_BSNS_ABRV_CD                          as SPONSORSHIP_ABBR,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '1d13a601-ad24-41f9-ace2-8e070d87b9ca'                    AS DW_BATCH_ID,
    s.SPNSR_DIV_CD                                as SPONSORSHIP_DIV_CD,
    cd_div.DTL_CD_NM                              as SPONSORSHIP_DIV_NAME,
    cd_grp.DTL_CD_NM                              as SPONSORSHIP_GROUP_NAME
from s
left join cd_div on cd_div.DTL_CD_ID = s.SPNSR_DIV_CD
left join cd_grp on cd_grp.DTL_CD_ID = s.SPNSR_BSNS_ABRV_CD

union all
-- unknown 멤버(SK=0): 팩트 SPONSORSHIP_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', '(미매핑)', NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '1d13a601-ad24-41f9-ace2-8e070d87b9ca'                    AS DW_BATCH_ID,
    NULL, NULL, NULL
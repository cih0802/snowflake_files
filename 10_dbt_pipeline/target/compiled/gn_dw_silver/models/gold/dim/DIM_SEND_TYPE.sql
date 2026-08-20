-- DIM_SEND_TYPE: 발송구분 차원 — 대/중/소 3단 계층 평탄화 (정본 지표 #133·#134·#135)
-- Co-authored with CoCo
-- 정본 = 20_issue/30_설계_의사결정.md §20(DEC-30) · DEC-28 §18-C 의 "②차원 분리" 안 실행.
--
-- 🟢 왜 별도 차원인가 (DIM_SERVICE grain 확장 대신)
--   `DIM_SERVICE` grain 은 (CHANNEL, SUBTYPE) = 10행이고 대/중/소를 추가하면 74행이 된다
--   → 함수종속 불성립이며 `SERVICE_SK` 산식이 바뀌어 **이미 99.97% 적재된
--   `FACT_SERVICE_EVENT.SERVICE_SK`(A3 배선)를 파괴**한다. 차원 분리는 기존 적재를 보존한다.
--
-- 🟢 자연키 = (대,중,소) **전체 경로** — 단일 레벨로는 만들 수 없다 (2026-08-04 실측)
--   TOP 코드 12종 · MID 코드 16종인데 **MID 라벨은 26종**이다 → 같은 중분류 코드가
--   부모 그룹에 따라 다른 의미를 갖는다(BOT 도 코드 42 vs 라벨 56).
--   (TOP,MID,BOT) 65조합 = 라벨 결합 65 · 계층 NULL 0 → **라벨이 전체 경로에 100% 함수종속**.
--
-- 🟢 커버리지 — 소비 grain 으로 재측정하면 21.58% 다 (P39)
--   DEC-28 §18-C 는 0.106%(1,707/1,614,397 **요청**)로 적어 저가치로 판단했으나,
--   실제 소비 grain 인 발송×회원(`FACT_SERVICE_EVENT`)에서는
--   **8,300,272 / 38,470,780 = 21.58%** 다. send-type 이 붙은 요청은 평균 4,862.5명 발송
--   (없는 요청 18.7명)이라 **260배** 차이가 난다 → 요청 grain 분모가 가치를 200배 과소평가했다.
--
-- ⚠️ 라벨은 원천 비정규화 컬럼(`_NM`)을 그대로 승계한다 — `SEND_GBN_TOP` 이 코드값이 아니라
--    `CRM_CODE.CD_ID`(코드그룹 ID) 자체라서 일반적인 코드사전 조인(P31)이 성립하지 않는다.
--    실측: TOP = MS046 결연·MS047 회원·MS048 회비·MS049 서비스·MS050 사업보고 … 12종.
--    지표사전 #134 값 열거가 MS046 라벨과 일치해 교차확인됨(DEC-28 §18-C).
-- 🔴 DEC-25 준수: 코드(원천명 `SEND_GBN_*`)와 라벨(분석용어 `SEND_TYPE_L/M/S`)을 **병기**한다.
-- 🔴 [2026-08-04 자기검토] **정본 #133 과 라벨이 불일치한다** — #133 은 6종(결연/회비/서비스/사업보고/
--    참여/기타)인데 실측 `SEND_TYPE_L` 은 **9종**이다(추가: 회원만족 MS052 · 회원서비스 MS054 · 회원 MS047+MS053).
--    #133 은 생략기호가 없어 완전열거로 읽히므로 불일치가 실재한다 → 문서20 §L 현업 확인.
--    데이터를 임의 통합·삭제하지 않는다(DEC-26 참고본 강등 · 원천 우선).
-- ⚠️ **대분류는 코드그룹과 1:1 이 아니다**: 라벨 하나가 복수 코드그룹에서 온다
--    (결연=MS046+MS051 경로21 · 기타=MS0505+MS055 경로4 · 회원=MS047+MS053 경로2) → 코드그룹 12종 → 라벨 9종.
-- 🟢 `SEND_GBN_TOP` 12종 전부 `CRM_CODE.CD_ID` 로 실재 확인(MS0501·MS0505 포함 — 오염값 아님).


with src as (
    -- 계층 경로 DISTINCT. 라벨이 경로에 함수종속하므로 group by 로 대표값 규칙이 불요하다.
    select
        SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT,
        MAX(SEND_GBN_TOP_NM) as SEND_GBN_TOP_NM,
        MAX(SEND_GBN_MID_NM) as SEND_GBN_MID_NM,
        MAX(SEND_GBN_BOT_NM) as SEND_GBN_BOT_NM
    from GN_DW.SILVER.CRM_SEND_REQUEST
    where SEND_GBN_TOP is not null
    group by SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT
)

select
    ABS(HASH(COALESCE(CAST(SEND_GBN_TOP AS VARCHAR), '∅') || '‖' || COALESCE(CAST(SEND_GBN_MID AS VARCHAR), '∅') || '‖' || COALESCE(CAST(SEND_GBN_BOT AS VARCHAR), '∅'))) as SEND_TYPE_SK,
    SEND_GBN_TOP || '>' || SEND_GBN_MID || '>' || SEND_GBN_BOT    as SEND_TYPE_BK,
    SEND_GBN_TOP        as SEND_GBN_TOP,
    SEND_GBN_TOP_NM     as SEND_TYPE_L,
    SEND_GBN_MID        as SEND_GBN_MID,
    SEND_GBN_MID_NM     as SEND_TYPE_M,
    SEND_GBN_BOT        as SEND_GBN_BOT,
    SEND_GBN_BOT_NM     as SEND_TYPE_S,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b293c87f-c2c1-42e5-b50c-69029085db76'                    AS DW_BATCH_ID
from src

union all
-- unknown 멤버(SK=0): FSE.SEND_TYPE_SK=0(발송요청에 구분값 부재 78.42%) 조인 유실 방지 센티넬.
-- ⚠️ 표기는 프로젝트 규약 '(미매핑)' 으로 통일한다(문서00 센티넬 규약).
select 0, '(미매핑)', NULL, '(미매핑)', NULL, '(미매핑)', NULL, '(미매핑)',
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b293c87f-c2c1-42e5-b50c-69029085db76'                    AS DW_BATCH_ID
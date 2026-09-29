-- DIM_ORG: 조직 차원 SCD1 (DEPT_ID grain, 안정 SK) — CRM_ORG
-- Co-authored with CoCo
-- ⚠️ SK=hash(DEPT_ID) 안정키(재실행 멱등). DEC-2 SCD1 확정 — 조직 변경이력 소스 없음·as-was org 지표 요구 없음(4개 정의서 검토) → SCD2 예약컬럼(EFFECTIVE_*/IS_CURRENT) 삭제(2026-07-07).
--    향후 조직 이력추적 필요 시 별도 변경이력 소스 확보 후 재설계.
--
-- ✅ CONF-4(2026-07-31, 정본대조 PROC-2): D6 4단(법인>본부/지부>부서>팀) 중 정본 정합은 DEPARTMENT 1축뿐.
--    부서 트리가 **2개**임을 확인 — 조직트리 UPPER_DEPT_ID(보고계통) vs 실적트리 ACMSLT_UPPER_DEPT_ID(집계계통).
--      · 레벨 분포: 조직 9/38/351/672/238/6 vs 실적 300/10/72/422/509/1 (441건 상이·573건 동일·NULL 300)
--      · 실적부서(455) LVL5 집중도: 조직트리 26% vs 실적트리 **98.0%** → DEC-5 "5th=실적부서"는 실적트리 기준으로 성립
--
--    ① DIVISION = **실적지부로 재정의**. 정본 용어사전 430(실적 지부 명)·431(실적지부(본부/지부) 구분).
--       정본 보고서는 "본부/지부" 단독 사용 0건이고 "실적지부(본부/지부)"(05:275)·"실적지부"(05:311)로만 쓴다.
--       🔴 산출 규칙 미확정 → 값 NULL 유지. 명칭기반 최근접 본부/지부 도달률 418/455=91.9%(미도달 37)이고
--          명칭 판정은 범주오류 위험(O16 자체 오판 이력) → 규칙 확정 전 채우지 않는다.
--    ② TEAM = **보류**. 정본 근거는 지표 #152~155(연사업/추경 목표) "각 팀별" 뿐이고 용어사전·회원보고서·
--       마케팅보고서 실질 0건(검출 3건은 전부 "원천팀/원본팀" 편집주석). 원천 CRM_BIZ_TARGET 미입고(E-6) → 소비처 부재.
--    ③ CORP = **부서 차원에서 산출 불가**. 부서→법인 1:1 아님 — 200부서에 복수법인 혼재
--       (2종 69부서/23,130명 · 3종 131부서/1,544,005명=98.6%). 부서트리 LVL1도 부적합
--       (ZA 구조노드 587부서가 법인 루트 미연결 + 직위 B000007 이사장 + 회원0 재단법인 2개 혼재).
--       법인 정본 원천 = **회원 속성 CPR_DIV_CD**(CM019: I=사단/S=사복/A=통합) → DIM_MEMBER/팩트 degen 배속 판단 필요.
--
-- 🟢 원천 계통 3컬럼을 **원천 그대로**(추론 0) 노출 — 후속 규칙 확정 시 즉시 활용.
-- 🔴 USE_YN='N' 764개(58.1%) 제외 금지(O16): 팩트가 대량 참조(ACT_DEPT_CD 미사용 156부서에 410,506명 ·
--    AMT_CHANGE 미사용 189부서에 100,931건) + 필터 시 트리 파편화(LVL1 9→42, 총 1,314→550). 1,314행 전체 유지.
--
-- 🆕 [2026-09-29 O188-E] 활성 조직 트리 3컬럼 — 정본 = `90_provided_definition/gni_실적부서.csv`(현업 제공 조직표).
--    규칙(하드코딩 0) = 자기와 **모든 상위**(UPPER_DEPT_ID)가 USE_YN='Y' 이고 LAST_UPDT_DT 가 NULL·9999-12-31 이 아님.
--    📏 xf98254 = 223노드 ⊇ CSV 222 · 경로 222/222 일치 · 초과 = B000006 해외파견(사용자 결정 O188-E: 포함).
--    🔴 행을 지우지 않는다(위 O16) — 판정은 IS_ACTIVE_ORG 플래그로만 한다.
{{ config(
    materialized='incremental',
    unique_key='ORG_SK',
    tags=['gold_pending']
) }}

with recursive o as (
    select * from {{ ref('CRM_ORG') }}
),
b as (
    select x.DEPT_ID, x.DEPT_NM, x.UPPER_DEPT_ID,
           COALESCE(x.USE_YN = 'Y'
                    and x.LAST_UPDT_DT is not null
                    and TO_DATE(x.LAST_UPDT_DT) <> '9999-12-31', FALSE) as SELF_LIVE,
           -- 루트 = 상위가 마스터에 없는 노드(법인 루트 등). 🔴 재귀 CTE 안의 NOT IN 서브쿼리는 Snowflake 가
           --   「Unsupported subquery type」으로 거부한다(O188-F 컴파일 검증 적발) ⇒ anti-join 플래그로 미리 계산한다.
           (p.DEPT_ID is null)                                                 as IS_ROOT
    from o x
    left join o p on p.DEPT_ID = x.UPPER_DEPT_ID
),
tree as (
    -- 경로는 루트를 뺀 형태(조직표 규격)
    select DEPT_ID, SELF_LIVE as IS_LIVE, 0 as LVL, CAST(NULL AS VARCHAR) as PATH
    from b
    where IS_ROOT
    union all
    select c.DEPT_ID, t.IS_LIVE and c.SELF_LIVE, t.LVL + 1,
           IFF(t.LVL = 0, c.DEPT_NM, t.PATH || ' > ' || c.DEPT_NM)
    from b c
    join tree t on c.UPPER_DEPT_ID = t.DEPT_ID and c.DEPT_ID <> c.UPPER_DEPT_ID
    where t.LVL < 12
)

select
    {{ gold_sk(['o.DEPT_ID']) }}                  as ORG_SK,
    ABS(HASH(o.DEPT_ID))                          as ORG_DK,
    CAST(NULL AS VARCHAR)                          as CORP,        -- ③ 부서 차원 산출 불가(CONF-4)
    CAST(NULL AS VARCHAR)                          as DIVISION,    -- ① 실적지부 재정의 · 산출규칙 확정 대기
    o.DEPT_NM                                     as DEPARTMENT,   -- ✅ 정본 정합
    CAST(NULL AS VARCHAR)                          as TEAM,        -- ② 보류(E-6 입고 시 재개)
    o.ACMSLT_UPPER_DEPT_ID                        as ACMSLT_UPPER_DEPT_ID,  -- 원천 그대로
    o.ACMSLT_DEPT_YN                              as ACMSLT_DEPT_YN,        -- 원천 그대로
    o.USE_YN                                      as USE_YN,                -- 원천 그대로(제외 금지)
    {{ gold_meta('CRM') }},
    COALESCE(t.IS_LIVE, FALSE)                    as IS_ACTIVE_ORG,  -- 🆕 O188-E 활성 조직 트리 소속
    t.PATH                                        as ORG_PATH,       -- 🆕 O188-E 조직표 「부서 경로」(루트 제외 · 순환 노드는 NULL)
    t.LVL                                         as ORG_LEVEL       -- 🆕 O188-E 루트=0
from o
left join tree t on t.DEPT_ID = o.DEPT_ID

union all
-- unknown 멤버(SK=0): 팩트 ORG_SK=0(미매핑) 조인 유실 방지
select 0, 0, NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL,
    {{ gold_meta('CRM') }},
    FALSE, NULL, NULL

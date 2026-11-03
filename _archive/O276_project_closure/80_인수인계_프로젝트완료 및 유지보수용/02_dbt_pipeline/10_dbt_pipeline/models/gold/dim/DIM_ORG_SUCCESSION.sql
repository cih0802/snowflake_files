-- =============================================================================
-- Purpose    : 폐지·개편 부서 → 현재 활성 부서 귀속 차원 (O252 · DEC-63 = DEC-56 보완)
-- Target     : GOLD.DIM_ORG_SUCCESSION (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_ORG_SUCCESSION (O259 · 규칙 정본) · 종전 ref CRM_ORG·DIM_ORG·CRM_MEMBER_DEV·CRM_MEMBER_SPONSOR_SPAN·ORG_SUCCESSION_MANUAL
-- Issue      : O252, DEC-63, DEC-56, O259
-- =============================================================================
-- DIM_ORG_SUCCESSION: 폐지·개편 부서 → 현재 활성 부서 귀속 차원 (O252 · DEC-63 = DEC-56 보완)
-- grain = 부서(SILVER.CRM_ORG.DEPT_ID) 1행 · DIM_ORG 와 1:1 (ORG_SK 동일 · 활성 부서는 자기 자신으로 귀속).
-- WARN: DEC-56 유지 — 원천 실적부서값은 바꾸지 않는다. 이 차원은 「현재 조직 기준 조회」용 별도 축이다.
--    팩트의 부서 컬럼 → 이 차원의 OLD_ORG_SK(=DIM_ORG.ORG_SK) 로 조인하고 CUR_* 를 쓴다.
--
-- 귀속 규칙(우선순위 · 근거 = tmp/o252/evidence.md · 개발 환경 이전 계정 2026-10-21 실측):
--   0 SELF 활성 부서(DIM_ORG.IS_ACTIVE_ORG) = 자기 자신
--   1 MANUAL seed ORG_SUCCESSION_MANUAL(현업 확정) — CUR_DEPT_ID 비우면 MANUAL_UNMAPPED
--   2 AUTO_NAME 활성 부서 중 같은 이름이 유일
--   3 AUTO_MEMBER_FLOW 그 부서 후원 회원의 2022년~ 개발 실적부서 분포에서
--                        lift(점유율 ÷ 전체 기준선) ≥ var('org_succ_min_lift') 이고 근거 ≥ var('org_succ_min_evidence') 건
--                        WARN: 최빈값을 쓰지 않는다 — 매체운영팀이 전체 개발의 43.8% 라 전부 그리로 쏠린다
--   4 AUTO_ACMSLT_PARENT 실적트리(ACMSLT_UPPER_DEPT_ID) 상위 중 첫 활성 노드 또는 활성 동명 유일 노드
--   5 AUTO_ORG_PARENT 조직트리(UPPER_DEPT_ID) 최근접 활성 상위 · 단 ORG_LEVEL ≥ 1(법인 루트 귀속은 무의미)
--                        WARN: 폐지 부서는 조직트리에서 「폐지부서(사복)」 컨테이너로 옮겨져 있어 원래 상위를 잃는다 ⇒ 실적트리를 먼저 본다
--   6 UNMAPPED CUR_* NULL — 소비 측은 '(미매핑 폐지부서)' 로 노출(합계 보존 · R2-7-3 축)
{{ config(
    materialized='incremental',
    unique_key='OLD_ORG_SK'
) }}

-- [2026-10-23 O259] 귀속 규칙(0~6)은 SILVER.CRM_ORG_SUCCESSION 으로 이관했다(규칙 정본 = 그 파일).
--   이 모델은 SK 만 붙인다 — 출력 컬럼·순서 무변경(신구 MINUS 0 이 검증 기준).
--   상위부서 축(OLD_UPPER_*·CUR_UPPER_DEPT_ID)은 Silver 에만 둔다(GOLD DDL 무변경).
select
    {{ gold_sk(['s.OLD_DEPT_ID']) }}               as OLD_ORG_SK,
    s.OLD_DEPT_ID                                  as OLD_DEPT_ID,
    s.OLD_DEPARTMENT                               as OLD_DEPARTMENT,
    s.OLD_IS_ACTIVE_ORG                            as OLD_IS_ACTIVE_ORG,
    IFF(s.CUR_DEPT_ID is null, NULL, {{ gold_sk(['s.CUR_DEPT_ID']) }})  as CUR_ORG_SK,
    s.CUR_DEPT_ID                                  as CUR_DEPT_ID,
    s.CUR_DEPARTMENT                               as CUR_DEPARTMENT,
    s.CUR_ORG_PATH                                 as CUR_ORG_PATH,
    s.CUR_ORG_LEVEL                                as CUR_ORG_LEVEL,
    s.MAP_METHOD                                   as MAP_METHOD,
    s.IS_REMAPPED                                  as IS_REMAPPED,
    s.IS_CONFIRMED                                 as IS_CONFIRMED,
    s.FLOW_CAND_DEPT_ID                            as FLOW_CAND_DEPT_ID,
    s.FLOW_EVIDENCE_CNT                            as FLOW_EVIDENCE_CNT,
    s.FLOW_SHARE                                   as FLOW_SHARE,
    s.FLOW_LIFT                                    as FLOW_LIFT,
    s.CONFIRMED_BY                                 as CONFIRMED_BY,
    s.CONFIRMED_DT                                 as CONFIRMED_DT,
    s.NOTE                                         as NOTE,
    {{ gold_meta('CRM') }}
from {{ ref('CRM_ORG_SUCCESSION') }} s

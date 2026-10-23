"""O259 — GOLD.DIM_ORG_SUCCESSION 본문(32행~끝)을 Silver ref 로 교체. 헤더(1~31행)는 보존."""
import hashlib, io, sys
P = "/workspace/10_dbt_pipeline/models/gold/dim/DIM_ORG_SUCCESSION.sql"
EXPECT = "77d67966e89b28d560ab764297bd9ae0f471f0aa3db239560928fcb71c53be27"
raw = open(P, "rb").read()
if hashlib.sha256(raw).hexdigest() != EXPECT:
    sys.exit("ABORT hash")
L = raw.decode("utf-8").split("\n")
assert L[4].startswith("-- Depends on"), L[4]
assert L[31].startswith("with recursive o as ("), L[31]
L[4] = "-- Depends on : ref CRM_ORG_SUCCESSION (O259 · 규칙 정본) · 종전 ref CRM_ORG·DIM_ORG·CRM_MEMBER_DEV·CRM_MEMBER_SPONSOR_SPAN·ORG_SUCCESSION_MANUAL"
L[5] = L[5] + ", O259"
head = L[:28]           # 1~28행 = 헤더 주석 + config 시작 직전까지
assert L[23].startswith("{{ config("), L[23]
body = '''{{ config(
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
'''
out = "\n".join(L[:23]) + "\n" + body
open(P, "wb").write(out.encode("utf-8"))
assert open(P, "rb").read() == out.encode("utf-8")
print("OK", hashlib.sha256(out.encode()).hexdigest()[:12], len(out.split("\n")))

"""08 SILVER DDL 정본 끝에 O259 블록(39 파일의 [D1]·[D2]) 덧붙이기. 해시 대조 후 쓰기."""
import hashlib, io, re, sys
P = "/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql"
S = "/workspace/05_SV-Agent_ai/39_DEPLOY_SILVER_ORG_CLEAN.sql"
raw = open(P, "rb").read()
h0 = hashlib.sha256(raw).hexdigest()
src = io.open(S, encoding="utf-8").read()
blk = src[src.index("CREATE TABLE IF NOT EXISTS GN_DW.SILVER.CRM_ORG_CLEAN"):src.index("-- [D3]")].rstrip() + "\n"
t = raw.decode("utf-8")
if "GN_DW.SILVER.CRM_ORG_CLEAN" in t:
    sys.exit("already present")
head = """
-- ============================================================================
-- [2026-10-23 O259] 조직도 Silver 정제 — CRM_ORG_CLEAN · CRM_ORG_SUCCESSION(dbt 적재) + V_ORG_PICKER(DDL 소유 뷰)
--   WARN: GN_DW_DBT 는 SILVER CREATE TABLE 권한이 없다(07 RBAC §D.9) ⇒ 구조는 이 DDL 이 먼저 만든다.
--   WARN: V_ORG_PICKER 는 dbt 모델이 아니다 — SILVER pre-hook(silver_purge = TRUNCATE)이 뷰에서 실패한다.
--   기존 환경 = /05_SV-Agent_ai/39_DEPLOY_SILVER_ORG_CLEAN.sql (이 블록 사본 · 이 파일 전체 재실행 금지 = SILVER 전량 비워짐).
-- ============================================================================
"""
out = t.rstrip("\n") + "\n" + head + blk
if hashlib.sha256(open(P, "rb").read()).hexdigest() != h0:
    sys.exit("ABORT hash")
open(P, "wb").write(out.encode("utf-8"))
assert open(P, "rb").read() == out.encode("utf-8")
assert out.startswith(t.rstrip("\n"))
print("OK +%d lines" % (out.count("\n") - t.count("\n")))

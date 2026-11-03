"""O260 음성 테스트 — EXCLUDE 테이블이 인수인계에 생기면 축1 「인수인계에만」으로 잡혀야 한다."""
import io, sys, tempfile, shutil
from pathlib import Path
from contextlib import redirect_stdout
sys.path.insert(0, "/workspace/scripts")
import handoff_ddl_gate as G

d = Path(tempfile.mkdtemp())
try:
    for sub in ("90_provided_definition", "50_handoff"):
        shutil.copytree(G.ROOT / sub, d / sub)
    p = d / "50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql"
    p.write_text(p.read_text(encoding="utf-8")
                 + "\ncreate or replace TABLE GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT_TEST (\n  X NUMBER(1,0) COMMENT 'x'\n);\n",
                 encoding="utf-8")
    G.ROOT = d
    rep = G.Report()
    with redirect_stdout(io.StringIO()):
        G.compare("BRONZE_CRM", ["90_provided_definition/11_bronze_crm_ddl.sql"],
                  "50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql", "BRONZE_CRM.", rep, True)
    hit = [l for l in rep.lines if "인수인계에만" in l and "_TEST" in l]
    print("axis1=%d hit=%d" % (rep.axes[1], len(hit)))
    print("PASS" if rep.axes[1] == 1 and hit else "FAIL")
finally:
    shutil.rmtree(d)

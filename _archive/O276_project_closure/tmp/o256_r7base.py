"""O256 — sv_rule7 라이브 위반이 O256 이전부터 있었는지 백업본으로 판정(읽기 전용)."""
import sys, io, contextlib
sys.path.insert(0, "/workspace/scripts")
import sv_rule7_scan as R
B = "/workspace/95_작업기록_인수인계정제/_backup_O256_원본_20261021/05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql"
N = "/workspace/05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql"
for tag, p in (("backup(O256 이전)", B), ("current", N)):
    R.TARGETS = [p]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            R.main()
    except SystemExit as e:
        rc = e.code
    else:
        rc = 0
    lines = [l for l in buf.getvalue().split("\n") if "라이브" in l or "COMMENT" in l or "·" in l][:6]
    print("==", tag, "rc", rc)
    for l in lines:
        print("  ", l[:300])

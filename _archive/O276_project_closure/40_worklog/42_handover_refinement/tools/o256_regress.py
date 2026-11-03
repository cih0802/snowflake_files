"""O256 — 80 재빌드 회귀 대조(읽기 전용)."""
import importlib.util, io, os, re, sys
sys.path.insert(0, "/workspace/95_작업기록_인수인계정제/tools")
from scrub_acct import ACC
W = "/workspace/"; OUTD = W + "80_인수인계_프로젝트완료 및 유지보수용/"
spec = importlib.util.spec_from_file_location("bh", OUTD + "build_handoff.py")
bh = importlib.util.module_from_spec(spec); spec.loader.exec_module(bh)
ACC_RE = re.compile("(?<![A-Za-z0-9])(" + "|".join(ACC) + ")(?![0-9])", re.I)
entries = bh.MANIFEST[:1] + bh.extract_run_order_sql() + bh.MANIFEST[1:]
seen, ok, bad, hdr, sqln = set(), 0, [], 0, 0
for sub, pat, _ in entries:
    for src, rel in bh.expand(pat):
        if (sub, rel) in seen:
            continue
        seen.add((sub, rel)); r80 = f"{sub}/{rel}"
        data = bh.run_order_text().encode() if str(rel) == bh.RUN_ORDER_DOC else src.read_bytes()
        exp = bh.hook(r80, data); cur = open(OUTD + r80, "rb").read()
        (bad.append(r80) if cur != exp else None); ok += cur == exp
        if r80.endswith(".sql") and "mstr DDL 원본" not in r80:
            sqln += 1; hdr += b"-- Purpose    :" in cur[:3000]
acc = ih = 0; hits = []
for d, ds, fs in os.walk(OUTD):
    ds[:] = [x for x in ds if x not in ("_archive", "__pycache__")]
    for f in fs:
        if f.endswith(".py") or f.endswith(".xlsx") or f.endswith(".docx"):
            continue
        try:
            t = io.open(os.path.join(d, f), encoding="utf-8").read()
        except Exception:
            continue
        a, i = len(ACC_RE.findall(t)), len(re.findall("init_ihcho", t, re.I))
        if a or i:
            hits.append((os.path.relpath(os.path.join(d, f), OUTD), a, i))
        acc += a; ih += i
print(f"대상 {len(seen)} · 80==hook(원본) {ok} · 불일치 {len(bad)}")
for b in bad[:10]:
    print("  ≠", b)
print(f"SQL 헤더 {hdr}/{sqln}")
print(f"_archive 밖 계정 {acc} · init_ihcho {ih}")
for h in hits[:10]:
    print("  hit", h)

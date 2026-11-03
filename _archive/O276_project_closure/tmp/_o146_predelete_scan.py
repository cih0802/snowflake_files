# 07_O작업정리 접두에 걸리는 실체를 전수 나열한다 (R1-7-7 삭제 전 선나열)
# Co-authored with CoCo
import os

ROOT = "/workspace"
PREFIX = "07_O작업정리"

hits = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    rel = os.path.relpath(dirpath, ROOT)
    if rel.startswith(PREFIX) or PREFIX in rel:
        for f in filenames:
            p = os.path.join(rel, f)
            hits.append((p, os.path.getsize(os.path.join(dirpath, f))))
    if rel == ".":
        for f in filenames:
            if f.startswith(PREFIX):
                hits.append((f, os.path.getsize(os.path.join(dirpath, f))))

print("접두 '%s' 에 걸리는 실체 = %d건" % (PREFIX, len(hits)))
for p, n in sorted(hits):
    print("  %s  (%d B)" % (p, n))

# 다른 문서가 이 경로를 인용하는지 확인 (삭제 후 죽은 좌표가 되는 자리)
refs = []
for base in ("20_issue", "99_NEXT_SESSION_조각", "00_guides", "scripts", "60_repeat", "30_output_share"):
    for dirpath, _dirnames, filenames in os.walk(os.path.join(ROOT, base)):
        if "_archive" in dirpath:
            continue
        for f in filenames:
            if not f.endswith((".md", ".py", ".sql", ".yml")):
                continue
            fp = os.path.join(dirpath, f)
            try:
                txt = open(fp, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if PREFIX in txt:
                refs.append((os.path.relpath(fp, ROOT), txt.count(PREFIX)))

print("")
print("경로 인용처 = %d파일" % len(refs))
for p, c in sorted(refs):
    print("  %s  (%d회)" % (p, c))

#!/usr/bin/env python3
"""O255 · 05_SV-Agent_ai 이름 변경 대상의 참조 위치 전수 스캔(읽기 전용).
분모 = /workspace 전체 텍스트 파일 · _archive/ · __pycache__ · .git 제외 · 결과 = tmp/o255/ref_scan.tsv
"""
import os
import sys
from collections import Counter

OLD = [
    "13_SV_AD_배포_추가작업.sql",
    "27_O237_산식대응_배포순서.sql",
    "28_O237C_G1해소_배포순서.sql",
    "29_O239_G1잔여_배포순서.sql",
    "30_O240_실데이터이상치_배포순서.sql",
    "32_O241_AB병기_SV배선_배포순서.sql",
    "33_O241C_O242_운영계반영_배포순서.sql",
    "34_O246D_운영계반영_SV_ML_폴백각주.sql",
    "35_O249_SV_신설_광고비배분_개발사건코호트.sql",
    "36_O250_ML예측_7축확장.sql",
]
STEMS = {o: o[:-4] for o in OLD}
EXT = (".md", ".sql", ".py", ".yml", ".yaml", ".csv", ".txt", ".html", ".json", ".sh", ".tsv")
SKIP = ("_archive", "__pycache__", ".git", "node_modules")
rows, per_dir = [], Counter()
for root, dirs, files in os.walk("/workspace/", followlinks=True):
    dirs[:] = [d for d in dirs if not d.startswith(SKIP) and "_backup_" not in d]
    for fn in files:
        if not fn.endswith(EXT):
            continue
        p = os.path.join(root, fn)
        try:
            txt = open(p, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        for o, stem in STEMS.items():
            n = txt.count(stem)
            if n:
                rel = os.path.relpath(p, "/workspace")
                rows.append((o, rel, n))
                per_dir[rel.split("/")[0]] += n
with open("/workspace/tmp/o255/ref_scan.tsv", "w", encoding="utf-8") as w:
    for r in rows:
        w.write("\t".join(map(str, r)) + "\n")
print("files_with_refs", len({r[1] for r in rows}), "refs", sum(r[2] for r in rows))
for d, n in per_dir.most_common():
    print(f"{n:6d}  {d}")
sys.exit(0)

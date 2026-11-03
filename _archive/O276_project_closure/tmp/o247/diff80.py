#!/usr/bin/env python3
"""O247 · 80번 패키지 ↔ 원본 차이 목록 (읽기 전용)."""
import importlib.util
from pathlib import Path

ROOT = Path("/workspace")
spec = importlib.util.spec_from_file_location(
    "bh", ROOT / "80_인수인계_프로젝트완료 및 유지보수용" / "build_handoff.py")
bh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bh)

entries = bh.MANIFEST[:1] + bh.extract_run_order_sql() + bh.MANIFEST[1:]
seen, diff, new, same = set(), [], [], 0
for sub, pat, _ in entries:
    for src, rel in bh.expand(pat):
        if (sub, rel) in seen:
            continue
        seen.add((sub, rel))
        dst = bh.OUT / sub / rel
        if not dst.exists():
            new.append(f"{sub}/{rel}")
        elif dst.read_bytes() != src.read_bytes():
            diff.append(f"{sub}/{rel}")
        else:
            same += 1
print(f"same={same} diff={len(diff)} new={len(new)}")
for d in diff:
    print("DIFF", d)
for n in new:
    print("NEW ", n)

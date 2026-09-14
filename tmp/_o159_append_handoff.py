#!/usr/bin/env python3
"""O159 임시 — 인수인계 절을 99_NEXT 조각 말미에 append 한다.

R1-7-9 준수: 본문(백틱 포함)을 셸에 태우지 않고 파일→파일로 옮긴다.
R1-7-1 준수: 전체 재작성이 아니라 append 모드다(기존 바이트 불변).
"""
import hashlib
import pathlib
import sys

chunk = pathlib.Path("99_NEXT_SESSION_조각/99_NEXT_SESSION-031.md")
entry = pathlib.Path("tmp/_o159_handoff.md")

before = chunk.read_bytes()
add = entry.read_bytes()

if b"## 0-GGGG" in before:
    print("이미 append 됨 — 중단(멱등 차단)")
    sys.exit(2)

with chunk.open("ab") as fh:
    fh.write(add)

after = chunk.read_bytes()
assert after.startswith(before), "기존 바이트가 보존되지 않았다"
assert after == before + add, "append 결과가 기대와 다르다"
print("🟢 append 완료")
print("  before %d B / after %d B / delta %d B" % (len(before), len(after), len(add)))
print("  before sha256 =", hashlib.sha256(before).hexdigest()[:16])
print("  after  sha256 =", hashlib.sha256(after).hexdigest()[:16])
print("  0-GGGG 실재 =", b"0-GGGG" in after)

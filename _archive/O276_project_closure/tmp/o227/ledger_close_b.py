import hashlib, io
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
i = [k for k, s in enumerate(L) if s.startswith("| 🟢 **`O227`**")]
assert len(i) == 1, i
row = ("| 🟢 **`O227`** — O226-A 잔여 ②·③-①·③-② 집행 (2026-10-14 · xh20001 · ㉡ · 사용자 승인 · 확정위반 2 = R1-3-7-b 독해 토큰 사후 기록 · "
       "블록 스칼라 YAML 파손(복구 · 유실 0) · 단위 O227-A·B) "
       "| 🟢 MEMBER V$9(교차 집계 예외 · 롤백 V$8) · C3 테이블 21 · 뷰 12 · GOLD 컬럼 298(테이블 29 라이브 · 뷰 269 👤 build 대기) · "
       "거짓 주장 36 실측 덮어쓰기 · 기준선 V4 AC EXEC 0.9524 · MEMBER 0.9746 · 🟠 MKT 0.8814(Q31) "
       "| `tmp/o227/01_evidence.md` · `tmp/o227/02_col_evidence.md` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0227-B.md` |")
assert len(row) < 1900
L[i[0]] = row
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("updated L", i[0] + 1, len(row))

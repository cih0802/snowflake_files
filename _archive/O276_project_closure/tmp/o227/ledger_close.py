import hashlib, io, sys
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
i = [k for k, s in enumerate(L) if s.startswith("| 🟡 **`O227`**")]
assert len(i) == 1, i
row = ("| 🟢 **`O227`** — O226-A 잔여 ②·③-① 집행 (2026-10-14 · xh20001 · ㉡ · 사용자 승인 · 확정위반 1 = R1-3-7-b 독해 토큰 사후 기록 · 유실 0 · 단위 O227-A) "
       "| 🟢 MEMBER V$9(교차 집계 예외 = 새 비율·효과 지표 이름 없으면 분포 조회 · 롤백 V$8) · eval V4 AC 0.8715 → 0.9231 · R14 0.33 → 1.0 · 🟠 D3 1.0 → 0.33 · "
       "C3 테이블 COMMENT 21 라이브(잔여 ID 0) · 뷰 10 파일(👤 dbt build 대기) · stale 주장 3 삭제 "
       "| `tmp/o227/01_evidence.md` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0227-A.md` |")
assert len(row) < 1900
L[i[0]] = row
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("updated L", i[0] + 1, len(row))

import hashlib, io
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
i = [k for k, s in enumerate(L) if s.startswith("| 🟡 **`O228`**")]
assert len(i) == 1, i
row = ("| 🟢 **`O228`** — 계정 이전(jw08094) 후 O227-B ② 마감 + COMMENT C3 단계 ③·④·잔여 + MEMBER 정답지 V5 "
       "(2026-10-14 · jw08094 · ㉡ · 사용자 승인 · 확정위반 2 = 빈 대조 덮어쓰기(재생성 · 유실 0) · R1-3-7-b 사후 기록 · 단위 O228-A) "
       "| 🟢 드리프트 0 · MKT V4 jw1 AC 0.9764(Q31 회복) · SV 22 · Agent 3종 VERSION$4(👤 SQL · 롤백 V$3) · "
       "COMMENT ALTER 49 · GN_DW 잔여 이슈ID = OPS 메타 3(의도) · MEMBER 정답지 V5 · IRSD 보류 확정 · eval 재측정 대기 "
       "| `tmp/o228/04_c3_sv.md` · `tmp/o228/history_entry.md` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0228-A.md` |")
assert len(row) < 1900
L[i[0]] = row
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("updated L", i[0] + 1, len(row))

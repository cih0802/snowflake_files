import hashlib, io
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
idx = [k for k, s in enumerate(L) if "**`O229`**" in s]
assert len(idx) == 1, idx
L[idx[0]] = (
    "| 🟢 **`O229`** — O228-A 잔여(eval·현업회신 제외) 전건 + Inspection O202~O228 "
    "(2026-10-14 · jw08094 · ㉡ · 사용자 승인 · 확정위반 1 = R1-7-2 병렬 edit(유실 0) · 단위 O229-A) "
    "| 🟢 Q29 원인 = 정답지 메모·기대도구 stale · WIDE_AD_BROADCAST_CASE 0행 = 설계 · GAP 11→10(SV_SERVICE CAMPAIGN_OPEN_DATE) · "
    "DIM_CAMPAIGN IS_PARENT_CAMPAIGN_YN(👤 build 대기) · 런북 §7 · Inspection D1~D11(GRANT 5 · 게이트 5종 시정 · "
    "Agent COMMENT 소관 SV 종수 · ACMSLT_RATE %) · 소급 `REBUILD:ALL` = 2026-10-14 jw08094 GN_DW·SV·Agent 전량 재구축(O228) "
    "| — | `20_issue/_o229_inspection_evidence.md` |"
)
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("row", idx[0] + 1)

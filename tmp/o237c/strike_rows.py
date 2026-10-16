import io
D = "/workspace/99_NEXT_SESSION_조각/"
plan = {
    "99_NEXT_SESSION-O0237-A.md": {
        "| ① |": " ➔ 🟢 [O237-C] 라이브 확인 완료(ua91864 · metric 12 · 코퍼스 146 · 스모크 통과)",
        "| ② |": " ➔ 🟢 [O237-B] FACT_CAMPAIGN_MONTHLY · SV_CAMPAIGN_MONTHLY(라이브 대사 BAD 0)",
        "| ③ |": " ➔ 🟢 [O237-B] WIDE_MEMBER_SERVICE_COHORT +6열 · SV 05_18(라이브)",
        "| ④ |": " ➔ 🟡 [O237-C] 3건 작성(28_O237C 배포 대기) · 잔여 2 = O237-C-2 ③",
        "| ⑤ |": " ➔ [O237-C] O237-C-2 ⑤ 로 흡수",
    },
    "99_NEXT_SESSION-O0237-B.md": {
        "| ① |": " ➔ 🟢 [O237-C] 배포 확인 · 05_25b 대사 · 스모크 8문항 통과(ua91864)",
        "| ② |": " ➔ [O237-C] O237-C-2 ② 로 승계(C 배포 후 🟢)",
        "| ③ |": " ➔ 🟡 [O237-C] 3건 작성 · 잔여 2 = O237-C-2 ③",
        "| ④ |": " ➔ [O237-C] O237-C-2 ⑤ 로 흡수",
        "| ⑤ |": " ➔ 🟡 [O237-C] W1·W2·W3-L4 작성 · 잔여 = O237-C-2 ④",
    },
}
for fn, rows in plan.items():
    p = D + fn
    src = io.open(p, encoding="utf-8").read()
    L = src.split("\n")
    s = next(i for i, x in enumerate(L) if "㉠ 잔여" in x and x.startswith("###"))
    e = next(i for i in range(s + 1, len(L)) if L[i].startswith("㉡") or L[i].startswith("###"))
    hit = 0
    for i in range(s, e):
        for key, note in rows.items():
            if L[i].startswith(key):
                cells = L[i].split(" | ")
                # | ① | 작업 | 판정 |  → 순·작업 셀 취소선 + 대체 처방
                num = key.strip("| ").strip()
                body = L[i][len(key):].rstrip()
                assert body.endswith("|"), L[i]
                parts = body[:-1].rsplit("|", 1)
                work, judge = parts[0].strip(), parts[1].strip()
                L[i] = "| ~~%s~~ | ~~%s~~%s | %s |" % (num, work, note, judge)
                hit += 1
    assert hit == len(rows), (fn, hit)
    out = "\n".join(L)
    io.open(p, "w", encoding="utf-8", newline="").write(out)
    assert io.open(p, encoding="utf-8").read() == out
    print(fn, "rows", hit, "lines", len(L))

import io
P = "/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
src = io.open(P, encoding="utf-8").read()
L = src.split("\n")
i = next(k for k, x in enumerate(L) if x.startswith("| 🟡 **`O237`**"))
new = ("| 🟢 **`O237`** — 산식 대응 개선: 지표사전 산식 전건 ↔ SV metric·RAG 배선(LLM용 매핑표) + 캠페인 월 팩트·서비스 코호트 확장"
       " (2026-10-16 · ua91864 · ㉡ · 사용자 지시·승인(C·D = dbt 실행 권한 승인) · 확정위반 1(A) + 3(C) · 단위 O237-A·B·C·D)"
       " | 🟢 라이브 집행·확인(ua91864 2026-10-16) = A·B 대사 465개월 BAD 0 · 스모크 8 통과"
       " · D: GA 백필(사용자 · SILVER 11,324,179 · 갭 경고 0) · FSM 생성·FK · 열 3 ALTER · dbt 프로젝트 버전 O237C_20261016_B · build PASS"
       " · 대사 FSM 465개월 BAD 0 · 중복 0 · LAST_CAMPAIGN 1,621,462 · 클릭 126,799/377/1,839 · 영상 UPPER_CODE 3,406행"
       " · SV 5종 · 코퍼스 146(G1 2) · Agent MEMBER V$6 · MARKETING V$5 · EXECUTIVE V$5(공79·공31 라우팅 규칙)"
       " · 스모크 최종캠페인·후원사업별 미납율 15.70%·클릭 0.30/1.45%·특집 = 방송 통과"
       " · ➡️ 잔여 = G1 2(GA 기반) · O238 W3~W6 · 현업 확인"
       " | `05_SV-Agent_ai/28_O237C_G1해소_배포순서.sql` · `12_agent개선과제/output/O238_link_key_gap.csv`"
       " | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0237-D.md` |")
assert new.count("|") == 5 and len(new) <= 1900, len(new)
L[i] = new
out = "\n".join(L)
io.open(P, "w", encoding="utf-8", newline="").write(out)
assert io.open(P, encoding="utf-8").read() == out
print("row", i + 1, "len", len(new))

H = "/workspace/99_NEXT_SESSION_조각/99_NEXT_SESSION-O0237-C.md"
src = io.open(H, encoding="utf-8").read()
L = src.split("\n")
rows = {"| ① |": " ➔ 🟢 [O237-D] 집행 완료(ua91864 · 대사·스모크 통과)",
        "| ② |": " ➔ 🟢 [O237-D] 원장 O237 🟢"}
hit = 0
for k, x in enumerate(L):
    for key, note in rows.items():
        if x.startswith(key):
            body = x[len(key):].rstrip()[:-1]
            work, judge = body.rsplit("|", 1)
            L[k] = "| ~~%s~~ | ~~%s~~%s | %s |" % (key.strip("| ").strip(), work.strip(), note, judge.strip())
            hit += 1
assert hit == 2, hit
out = "\n".join(L)
io.open(H, "w", encoding="utf-8", newline="").write(out)
assert io.open(H, encoding="utf-8").read() == out
print("handoff C rows struck", hit)

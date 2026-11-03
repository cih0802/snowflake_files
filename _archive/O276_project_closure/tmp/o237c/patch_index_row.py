import io, hashlib
P = "/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
src = io.open(P, encoding="utf-8").read()
L = src.split("\n")
old = L[104]
assert old.startswith("| 🟡 **`O237`** — 산식 대응 개선"), old[:40]
assert old.count("|") == 5
new = ("| 🟡 **`O237`** — 산식 대응 개선: 지표사전 산식 전건 ↔ SV metric·RAG 배선(LLM용 매핑표) + 캠페인 월 팩트·서비스 코호트 확장"
       " (2026-10-16 · ua91864 · ㉡ · 사용자 지시·승인 · 확정위반 1(A) + 3(C) · 단위 O237-A·B·C)"
       " | 🟢 A·B 라이브 확인(ua91864 2026-10-16) = 05_25b 대사 465개월 BAD 0 · 신규 metric 12 실재 · 코퍼스 146 = 기대 분포 · Agent 3종 배선 ·"
       " 스모크 8문항 통과(⑥ 태그 노출 비재현 2/2 · ⑤ VQR 경로 · ④ 기대값 표기 정정)"
       " · 🟡 C 작성 완료 · 👤 배포 대기 = 28_O237C [C1]→[C2]→[C0] GA 백필→[C3] build→[C4] 대사→[C5] SV 5종→[C6] 코퍼스"
       " · G1 5 → 2(최종캠페인 LAST_CAMPAIGN 잠정 · FACT_SPONSORSHIP_MONTHLY · 클릭 전환 5일·30일)"
       " · 이상치 규칙(분모 100건 미만 순위 제외) · O238 W1 특집=방송 · W2 갭표 · W3-L4 영상 코드형 연결"
       " · 🔴 GA 계열 0행(전체 빌드 롤링 창) = 백필 필요"
       " | `05_SV-Agent_ai/28_O237C_G1해소_배포순서.sql` · `12_agent개선과제/output/O238_link_key_gap.csv`"
       " | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0237-C.md` |")
assert new.count("|") == 5, new.count("|")
assert len(new) <= 1900, len(new)
L[104] = new
out = "\n".join(L)
io.open(P, "w", encoding="utf-8", newline="").write(out)
back = io.open(P, encoding="utf-8").read()
assert back == out
print("len", len(new), "lines", len(back.split("\n")), "sha", hashlib.sha256(back.encode()).hexdigest()[:16])

import hashlib, io
P = "/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(P, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1]
L = io.open(P, encoding="utf-8").read().split("\n")
idx = [i for i, x in enumerate(L) if x.startswith("| 🟡 **`O240`**")]
assert len(idx) == 1
L[idx[0]] = ("| 🟡 **`O240`** — 운영계 실데이터 기반 지표사전 계산 가능성·이상치 점검 → 파이프라인·SV·Agent 보강 "
             "(2026-10-16 · ua91864 · ㉡ · 사용자 승인(전부 진행) · 확정위반 1 = 1차 분석 거짓 이상치 6건 · 단위 O240-A·B) "
             "| 🟡 파일 집행 완료 · 🔴 라이브 미배포(Restricted Session Scope 가 DBT PROJECT·SV OWNERSHIP·DATA_AGENT_RUN 거부) = "
             "실재 이상치 VIDEO 에포크 1,573행 · 회비원장 2022-01 이전 미입고(누계중단율 2019~2021 85~99%) · 미래 선납월 1,197행 · GA 이탈율·세션시간 NULL · 2026 연 편성 0 · "
             "수정 = AGENCY_AD 2모델 · FCM·FCCS 기준월 202201~당월 · SV_GA_SESSION metric 2 · SV_AD CTR 가드 · Agent 3종 규칙 · 코퍼스 불변 · 게이트 6종 PASS · "
             "➡️ 잔여 = 👤 배포순서 30 D1~D5 · 현업·운영계 확인 4 "
             "| `05_SV-Agent_ai/30_O240_실데이터이상치_배포순서.sql` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0240-B.md` |")
io.open(P, "w", encoding="utf-8").write("\n".join(L))
print("ok")

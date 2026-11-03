
## O274 — O273 계획 집행 = 지표사전 현업 확정 지표 7종(RT-31~37) 등재 · 개발계 A1~A8 + 원장 재균형(2026-10-30 · TRIALADMIN · TQ68205 개발계 · ㉡ 적용 · 확정위반 1(sed -i 시도 · 유실 0))

- 착수 = `--next O` → O274 · 원장 §1 행 선점을 첫 쓰기로 했다(R1-4-3 지연 3세션 연속 해소) · §1 재실측 = 2,156행 · 광고 단독 NOT_MKTG 0 · TQ68205.
- A1 = `tools/O217_routing_curated.csv` RT-31~37 7행(37행 · 문안 = 05_31 SV COMMENT 40~69행만) · RT-33 「9·10월 원천 미입력」은 SV 설명에 없어 넣지 않았다 · 도구명 `analyst_mktg_campaign_cost` = 라이브 AGENT_MARKETING spec 실재(첫 grep rc=1 은 거짓 음성 · R0-8-4).
- A2 = 생성기 `[O273]` 규칙(overlay 뒤 · TOOL_NAME = analyst_ad 단독 → MARKETING) · A3 = 2,163행 · 옛 CSV 스냅샷 = `_archive/O217_biz_definition_corpus.csv.O274-A-pre_O274_corpus`.
- A4 = `tools/o274_corpus_diff.py` 신설 · 🆕 개발계 R3 실재 = RT-14·27·29 의 SV_FIELD·LIMITATION·DEFINITION 이 표에만 SURV_LTV_CAP_AVG_ACTIVE_MONTHS(05_03 정본) · curated CSV 는 SURV_LTV_CAP_MONTHS(낡음) → CSV 를 표에 맞춤 → 차이 = 추가 7행뿐 · 그 밖 0.
- A5·A6 = `05_SV-Agent_ai/54_DEPLOY_CORPUS_O273.sql` 신설·개발계 실행 · [0-B] SQL 대조 NEW 7 · COPY 2,163/2,163 · REFRESH(inserted 1,009) · ①2,163 ②0 ③7/7 · ④ 1순위 RT-31·RT-33·RT-36 · ⑤ 권한 5건 전후 동일(AR_SRC_COMMON 유지) · REFRESH 문법 = cortex search docs 확인.
- A7 = 26번 [5] 앞 경고 주석 · A8 = 현업 회신문 Q3 1줄 · 롤 작업순서 ⑨ 앞 경고 · 계획서 상태 헤더 갱신.
- 원장 `-002` = 41,639 B(상한 초과 · 내 행 추가 전에도 40,719 B) → 사용자 승인 후 `--rebalance` 조각 19 → 20 · max 28,517 B · 본문 바이트 동일 · 유실 0 · 스냅샷 = `_archive/00_INDEX_이슈원장.md.O274-A-prerebalance`.
- 확정위반 1건 = `sed -i` 로 o274_corpus_diff.py 수정 시도(R1-7-1) → 마운트 I/O 오류로 미적용 · 파일 무손상 확인 → `edit` 로 재수행.
- read 미반환 0 · 재호출 0 · 인수인계 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0274-A.md`.

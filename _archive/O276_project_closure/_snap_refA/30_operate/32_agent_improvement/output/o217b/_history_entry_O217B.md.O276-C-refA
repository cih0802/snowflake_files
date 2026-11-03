## O217-B — 10차 마감 · 새 개발계 ua91864 재현 · 증액 ML × 마케팅캠페인 · 운영계 런북 (2026-10-13 · ua91864 · ㉡ 적용 · 일괄 승인 · 확정위반 1)

- 착수 = `init_ihcho` 브리핑(BRIEF_RC=0 · 지침 304줄 · 인수인계 O217-A 59줄 전량) → 사용자 지시(계획 6단계 · 「승인이 필요한 작업은 전부 승인」).
- 🔴 확정위반 1 = `split_doc.py --rebalance --dry-run` 이 **조각 18개를 실제로 재기록**했다(13:29 · 스냅샷 `_archive/00_INDEX_이슈원장.md.O217-B-prerebalance` · 게이트 PASS · 유실 0).
  재균형은 승인 범위였으나 「dry-run 이 쓴다」는 결함을 확인하지 않고 실행했다 ⇒ 인수인계 ▣ O217-B-2 에 도구 결함으로 등재.
- 독해 기록(R1-3-7-b):
  · `00_guides/00_작업지침_세션운영규칙.md` 1~304 도착 · `R0-8-4` · `R4-4-4`.
  · `99_NEXT_SESSION-O0217-A.md` 1~59 도착 · `O217-A-2` · `VERSION$5`.
  · `90_provided_definition/agent 질의 피드백_2.csv` 1~45 도착 · `회원실,15` · `나눔마케팅,26`.
  · 라벨 파일 26개(O210-A~O217-A) = 서브에이전트 전량 독해 · 미독 0.
  · read 미반환 0 · 재호출 0.
- 실측 · 라이브(ua91864):
  · 새 계정 = O216 상태(SV 33 · Agent 3종 VERSION$3) · O217-A 객체 부재 → 15_ 백업 spec 과 라이브 diff 3종 0.
  · 코퍼스 테이블 생성 + 적재 2,145행(RT-19 추가) · Search 생성·REFRESH · GRANT 6.
  · SV_AD = GA_DEV_CNT 이미 보유 → 배포 생략.
  · 신규 `SERVING.ML_INC_BY_MKTG_CMPGN_V` · `SV_ML_INC_CAMPAIGN`(정본 `05_SV-Agent_ai/23_ML_INC_MKTG_CMPGN_DDL.sql`) · 원천 대조 202609 = 70,158 / 귀속 28,324.
  · Agent 3종 VERSION$3 → VERSION$4(MARKETING 19_O217B · MEMBER/EXECUTIVE 17_O217) · 라이브↔정본 diff 0.
- 측정 = `12_agent개선과제/output/o217b/00_O217B_전후비교.md` — 채팅 증액 질문 🔴→🟢 · 회귀 5 중 🟢3 🟡2 · 피드백 8 중 🟢1 🟡5 🔴1 ⚪1.
- 문서 = 런북 `18_O217_운영계_재현_런북.md` + `18_O217_운영계_재현_검증.sql`(개발계 실행 검증) · 잔여 `20_O21X_잔여작업_정리.md`(28건).
- 원장 §1 O217 행 등재(재균형 후 · `index_row_gate` PASS).

_Co-authored with CoCo_

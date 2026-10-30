<!-- LLM-METADATA
doc_id: HANDOFF_O0273_A
doc_role: 인수인계 — 세션 `O273-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-30
created_by: O273-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0273-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O273-A-0 🔴 먼저 알아라

- O272-D-1 ①②는 끝났다. 운영계 O272 결과를 받아 처리했다.
  - enum NEW 2 → `05_20` OS 3값 추가 + 게이트에서 빈 문자열·`/` 포함 값 제외(O273-A).
  - EXECUTIVE 19 = default `VERSION$20` 고정 드리프트 → 53번으로 `VERSION$23`(도구 17) 반영(O273-B).
- 🔴 개발계 17 이 정답이다(O270 W3 = `analyst_ad`·`analyst_ml_realtime_simulator` 제거). 경영 Agent 에 두 도구를 다시 넣지 마라.
- 🔴 `ADD VERSION` 만으로 default 가 옮겨진다고 믿지 마라 — `tmp/o250/deploy_agents.py deploy` [5] 가 「default = 최신」 아니면 rc 1 을 낸다(`09_2` [3] 주석).
- O272-D-2 ② 는 끝났다 = 회신문·롤 설계서·작업순서 3종 파일 저장(아래).

## ▣ O273-A-1 ㉠ 이 작업의 잔여

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 운영계 O270 단계 6 게이트 재실행(`rbac_source_gate.py --live` · 음성 테스트) | 👤 운영계 |
| ② | 롤 전환 = `12_agent개선과제/O273_롤전환_작업순서.md` 표 3(A 앱 서비스 사용자 · B 앱 10개 이전 · C 팀장 앱 · D 배정 9명 「확정」 · E SERVICE 회수 여부) | 👤 IT팀·사용자 |
| ③ | 현업 회신문 발송 `12_agent개선과제/O273_현업회신_마케팅Agent_3차피드백.md` + W9 공지 | 👤 데이터팀 |
| ④ | 현업 회신(LTV 이상치 규칙 · 방송 총비용 9·10월 입력) · R96(제작비 변동 · 영상 실적) | 👤 현업·운영계 |
| ⑤ | 구 역할 회수(48번 [6]) — ② 의 ⑦·⑨ 완료 후에만 | 🔴 사용자 승인 |

## ▣ O273-A-2 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 enum 게이트 조각 2/4·3/4 미실행(개발계 4조각 NEW 0) | 선택 |
| ② | 운영계 default 고정 원인(SET DEFAULT_VERSION 이력) 미확인 · MEMBER·MARKETING 은 정상 이동 | 필요 시 |
| ③ | 산출물 = `05_SV-Agent_ai/53_FIX_PROD_AGENT_EXECUTIVE_DEFAULT_ZL50263.sql` · `12_agent개선과제/O273_롤설계_추가역할.md` | 참고 |

_Co-authored with CoCo_

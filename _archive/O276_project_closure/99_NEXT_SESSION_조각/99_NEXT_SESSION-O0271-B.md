<!-- LLM-METADATA
doc_id: HANDOFF_O0271_B
doc_role: 인수인계 — 세션 `O271-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-30
created_by: O271-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0271-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O271-B-0 🔴 먼저 알아라

- 사용자 결정(2026-10-30) = 잔존 뷰 4 = 「dbt·SV 미사용이면 DROP」 · OWNERSHIP 이전 승인 · 분석가 보조 역할 () 승인 · CHOIH·CRM_ETL·LEESH·SWLEE = 개발자(배정 제외).
- 운영계 실행용 신규 프롬프트 = `12_agent개선과제/O271_운영계_LLM_프롬프트_잔존뷰_소유자.md`(R98 → 조건부 DROP → 목록 재확인 → OWNERSHIP → O270 프롬프트 단계 2 복귀).
- R98 Q09 추가 = SV base 검사(`INFORMATION_SCHEMA.SEMANTIC_TABLES` · 스키마 SERVING 한정) · 개발계 실행 0행.
- 🔴 GOLD.DIM_MONTH 는 SV_BUDGET·SV_MEMBER_MONTHLY 가 쓴다(개발계 실측) — SERVING.DIM_MONTH 와 동명 · 혼동 금지.
- 개발계 FACT_MKTG_CAMPAIGN_MONTHLY_COST 소유자 = GN_DW_ADMIN(재실측) ⇒ 개발계 변경 없음.

## ▣ O271-B-1 ㉠ 이 작업의 잔여

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 👤 운영계에서 O271 프롬프트 실행(DROP 은 뷰별 승인) | 운영계 |
| ② | 배정표 분석가 행 「확정」 열 기입 | 👤 사용자 |
| ③ | 팀장 역할 앱 USAGE = R97 Q03 앱 이름 목록 받은 뒤 작성 | 운영계 CSV |

_Co-authored with CoCo_

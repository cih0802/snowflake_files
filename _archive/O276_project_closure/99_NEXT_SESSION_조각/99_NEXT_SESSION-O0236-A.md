<!-- LLM-METADATA
doc_id: HANDOFF_O0236_A
doc_role: 인수인계 — 세션 `O236-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O236-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0236-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O236-A-0 🔴 먼저 알아라

- 작성 = ua91864(GOLD·SERVING 부재 · 라이브 대사 불가) · 반영 = jw08094(👤) · 2026-10-15 · ㉡ 적용.
- 🔴 운영계에서 `03_top-down_gold/06_DDL.sql` 전체를 다시 돌리지 마라(CREATE OR REPLACE · GOLD 전량 비움) — 신규 테이블은 `05_24b` [0] 만.
- 🔴 대형 yml·DDL 수정은 `edit` 툴 금지 — 이 세션에서 `_gold_ready_schema.yml` 519줄 유실 사고(사용자 복구). 백업 + 앵커 assert + 파싱 diff 스크립트로 고친다(예 = `tmp/o236/patch_agents.py`).
- 확정위반 1(위 사고 · R1-7-1·R1-7-2).

### ▣ O236-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 원인 실측 | FMM 연도초 월 반복 8.66배 · 「그 달 캠페인」 중단 미귀속 58.3% · 전사 누계중단율 13.78%(jw08094) |
| ② GOLD | `FACT_CAMPAIGN_CUM_STOP`(기준연월×CAMPAIGN_SK) · 06_DDL 블록+FK · schema yml 등재 |
| ③ SV | `05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql` · 대사 `05_24b_대사_CAMPAIGN_CUM_STOP.sql` |
| ④ 코퍼스·Agent | RT-30 TOOL_NAME · 2,156행 · Agent 3종 도구 +1 · [O236] 규칙 1문장 |

### ▣ O236-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 jw08094 = `05_24b` [0] → `dbt build --select FACT_CAMPAIGN_CUM_STOP` → `05_24` → `26` 코퍼스 → `09_2` → `05_24b` [1]~[5] 결과 회신 | #35 |
| ② | 대사 [1] DIFF 3개 = 0 확인 후 원장 O236 🟡 → 🟢 · 0 아니면 원인 분해(스파인·월 경계·FMSS 중복) | 검증 |
| ③ | [3] 캠페인 규칙 불일치율이 크면 현업 확인(중단·연도초 = 후원사업 대표캠페인 vs 개발 = 사건 캠페인) | 현업 |

㉡ 워크스페이스 백로그 = O235-A·B 승계 · 🟠 공54 `STOP_RATE_1`·공45 `ACTIVE_RATE` 다월 SUM 시 같은 분모 과대(이번 범위 밖 · COMMENT 경고 후보).

### ▣ O236-A-4 ⚪ 결정 완료(재론 금지)

- 캠페인 귀속 = A. 후원건(후원사업) 캠페인(사용자 · 2026-10-15). B(최초 캠페인)·C(그 달 캠페인) 기각.
- 대상 집합 = FMM 스파인(합계가 FMM 과 일치해야 한다) · 비율은 저장하지 않고 SV 「합의 비」.

_Co-authored with CoCo_

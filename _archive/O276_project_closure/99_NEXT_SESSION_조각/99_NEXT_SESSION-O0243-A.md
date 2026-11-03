<!-- LLM-METADATA
doc_id: HANDOFF_O0243_A
doc_role: 인수인계 — 세션 `O243-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-18
created_by: O243-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0243-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O243-A-0 🔴 먼저 알아라

- `O243` = O242-B 승계(2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 = eval·③·라이브 배포·신설 전부 · 확정위반 0).
- 🔴 계정이 **iw20760** 으로 바뀌었다. 사용자 확인 = iw20760 VERSION$3 ≡ mn11232 VERSION$8(같은 spec).
- 🔴 정답지 테이블은 이 계정에 없었다 ⇒ `tmp/o224_eval_ds.py apply` → `tmp/o224_eval_ds_v4.py apply` → `tmp/o241b/ds_v5.py` → `tmp/o242/ds_v6.py` 로 재구성(V3~V6 · DS 12 · 21/13/14행).
- 🔴 ACCOUNTADMIN 에는 GN_DW_ADMIN 객체가 안 보인다(SHOW·INFORMATION_SCHEMA 0행) ⇒ 판정은 `sfconn` + `USE ROLE GN_DW_ADMIN` 로 한다.

### ▣ O243-A-1 이번 단위 결과

| 단위 | 결과 |
|---|---|
| ① eval o242b | EXEC 0.968/0.858/0.952/0.733 · MKT 0.976/0.859/0.952/0.979 · MEM 0.795/0.746/0.568/0.522(AC/LC/TS/TE) · 근거 = `tmp/o242b/eval_b/state.json` |
| ① 비교 | o241s 대비 MKT 전 지표 상승 · EXEC LC 0.779→0.858 · EXEC TE 0.807→0.733 하락 · MEM AC 0.845→0.795 하락 · MEM Q01 AC 1.0 · TS/TE 0.5 |
| ③ 보류 실측 | 판정표 = ㉠ 117 · 보류 12 · 기처리 1(공19) — 인수인계 「115 · 14」는 집계 오기 |
| ③ 공91 | 생성기 MEASURE_OVERRIDE GIFT_PART_AMT(전건 0 · 44,406,102행) → D5_GIFT_PART_AMT · `scripts/gen_metric_gold_mapping.py:101` |
| ③ 라이브 | SV 3종 재배포 = 공13 토큰(AD_TYPE_NM·CHANNEL_COMPANY_TYPE) · 공48 YEAR_START_ACTIVE_MEMBERS · 공93 ACTIVE_USERS_ROWSUM · 공107 AVG/MAX_SCROLL_DEPTH |
| ③ 검증 | 임시 이름 3/3 PASS · 공48 202609 = 658,911 = GOLD 직접 집계 · 05_지표GOLD매핑 재생성(공13·48·91·93·107 배선) |

### ▣ O243-A-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 공112 GA member id 차원 — 원 ID 노출 · 마스킹 · 현행(Y/N) 중 결정 | 👤 결정 |
| ② | 공66 회비유형 축 = DIM_PAYMENT.FEE_TYPE 전건 NULL ⇒ 원천 주입 후 배선 | 운영계 |
| ③ | eval 하락 문항 분해 = MEM D3·R14·R15 · EXEC Q13 · EXEC TE 하락 | 다음 세션 |
| ④ | 👤 운영계 = 32 D1~D5 후 33 D0~D4 + O243 SV 3파일(05_01·05_07·05_15) | 👤 사용자 |

### ▣ O243-A-3 ㉡ 워크스페이스 백로그(승계)

| 순 | 작업 | 판정 |
|---|---|---|
| ⑤ | 현업 확인 = 공11 15개 정의 · 공147 공통캠페인 체계 · 공153·155 추경 | 현업 |
| ⑥ | O240 배포순서 30 D2 대사 · D5 스모크 5문항 | 👤 사용자 |
| ⑦ | 현업 A/B 결정 후 다른 안 회수(공#122·공#81·공91·공98) | 현업 → dbt |
| ⑧ | O238 W5·W6 · 미매칭 41행 · 현업 확인 목록 · 회비원장 2022-01 이전 · 2026 편성 0 | 현업·운영계 |

### ▣ O243-A-4 ⚪ 결정 완료(재론 금지)

- iw20760 VERSION$3 = mn11232 VERSION$8 · 정답지 V6 그대로 사용(사용자 2026-10-18).
- 공13 = 디지털 AD_TYPE_NM + 방송 CHANNEL_COMPANY_TYPE 조합 배선(O241-B-4 overlay 조합 규칙).
- 공93 은 행 내부 고유값 합이다 — 하루·이벤트 하나·페이지 하나 고정에서만 쓴다(COMMENT 정본).
- 공59·60 = Agent 규칙 소관 유지.

_Co-authored with CoCo_

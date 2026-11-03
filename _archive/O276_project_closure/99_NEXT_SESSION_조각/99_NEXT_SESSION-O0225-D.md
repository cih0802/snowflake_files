<!-- LLM-METADATA
doc_id: HANDOFF_O0225_D
doc_role: 인수인계 — 세션 `O225-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-14
created_by: O225-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0225-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O225-D-0 🔴 먼저 알아라

- O225-C 의 build 대기가 풀렸다 — 사용자 build PASS=118 WARN=5 ERROR=0. 착수점 = 이 파일(O225-C 의 ① ② 완료 · ③ ④ 승계).
- SV 5종 라이브 배포 완료(xh20001 · 2026-10-14): `SV_EXPENSE_RESOLUTION` · `SV_AD` · `SV_PAYMENT_BILLING_STATUS` · `SV_SERVICE` · `SV_MEMBER_MONTHLY`.

### ▣ O225-D-1 이번 단위 결과 (xh20001 실측)

| 검증 | 값 |
|---|---|
| FPBS 행 · 원천 청구행 보존 | 1,104,308행 · SUM(BILLING_ROWS) 50,835,411 · 캠페인 미매핑 금액 1.14% |
| FMM 다중 캠페인 비중 · 단일 미매핑 | 4.57% · 0.11% (경고 임계 10% 미만) |
| FMD SND 매핑 비율 | 42.72% (임계 35% 이상) |
| FER 연결 | 2,791행 · 금액 1.04% · 1:N 0 |
| SV 합계 = 팩트 (캠페인 축 그룹 포함) | 5종 전부 원 단위 일치(지출 278,905,240,613 · 납입 945,321,724,538 · 발송 43,919,141 · 광고 56,601,066,552.92) |
| 마케팅 Agent 원문 질문 재검증 | `analyst_expense_resolution` 선택 ⭕ · 마케팅캠페인 축 + (미매핑) ROLLUP ⭕ · 2026 제작비 493,537,156원 = 연결 674,000 + 미매핑 492,863,156(결의 496 · 코드 22종) 직접 집계와 일치 |

- 🟠 WARN 5건 = 이번 신규 테스트 3종은 조건 미충족(실측) ⇒ 기존 경고로 판단 · 로그 원문 미확인(`system$get_dbt_log` 로 확인 필요).
- 🟠 Agent 의 (미매핑) 설명 「마스터에 등록되지 않은 코드」는 부분적으로만 맞다 — 미매핑 중 코드 기재 447행은 CRM 캠페인에는 있고 **마케팅캠페인이 미지정**이다(전 기간 1,016행 · 30코드).

### ▣ O225-D-2 다음 세션 작업

- ① WARN 5건 원문 확인(`select system$get_dbt_log('<invocation>')`).
- ② `campaign_axis_gate` 🟠 GAP 15건 처리 순서 결정(우선 = `DIM_MEMBER.FIRST_CAMPAIGN` · IRSD 증감액 캠페인 · DGT 캠페인유형1·2).
- ③ ERP 「코드는 있으나 마케팅캠페인 미지정」 30코드 → 현업 확인(문서20 등재 후보).
- ④ O225-A 승계 = 1:N 안전장치 전수(`tmp/o224/onen_inventory.txt`) · 작업계획 §15-9 규칙 순서 갱신 · 원장 §1 행 · 세션이력 등재.

_Co-authored with CoCo_

_Co-authored with CoCo_

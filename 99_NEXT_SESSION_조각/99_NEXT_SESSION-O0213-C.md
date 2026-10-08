<!-- LLM-METADATA
doc_id: HANDOFF_O0213_C
doc_role: 인수인계 — 세션 `O213-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-C 인수인계 (Y3-D build 후속 = SV_PAYMENT_BILLING_STATUS 라이브)

### ▣ O213-C-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 확정위반 0)

- 🟢 사용자 build PASS=5 → `GOLD.FACT_PAYMENT_BILLING_STATUS` 12,102행 · 청구·납입·미납 FACT_MEMBER_FEE 와 원 단위 일치.
- 🟢 `SERVING.SV_PAYMENT_BILLING_STATUS` 배포(GN_DW_ADMIN · 차원 10 · 지표 5 · GRANT 3) · 스모크 = SV·팩트·FMF 청구액 955,144,520,496원.
- 🔴 정본 05_19 머리말 수치 정정(코드 NULL 16 → 1,116 · 원인 = 회비월 NULL 납입행의 납입월 폴백 1,100건 · 원천 실측).
- 🟠 Agent 3종은 이 SV 를 아직 도구로 갖지 않는다(Y4).
- 🟢 O213-B 인수인계의 나머지 항목은 그대로 유효하다(`99_NEXT_SESSION-O0213-B.md` ▣ O213-B-1 #2~#7) — 이 파일은 #1 의 종결만 적는다.

### ▣ O213-C-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | Y3-C·E·F·G·J·K dbt 적재 93건(L·P 99 중 D 6 제외 · `GN_DW.OPS.O213_Y2_FINAL`) | 도메인별 세션 · 다음 = C(회원) |
| 2 | 라벨 해소 6건 · S3 147건 판정 | O213-B-1 #3·#4 |
| 3 | Y4 Agent 도구 배선(신규 SV + 새 차원 축 이름) → ADD VERSION | AGENT_MEMBER 우선 |
| 4 | Y5 스모크 · Y6 eval(과금) · OPS 임시 객체 DROP | 마지막 |

### ▣ O213-C-2 ⚪ 결정 완료(재론 금지)

- O213-A·O213-B 결정 전건 유지.

_Co-authored with CoCo_

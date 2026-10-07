<!-- LLM-METADATA
doc_id: HANDOFF_O0205_A
doc_role: 인수인계 — 세션 `O205-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-07
created_by: O205-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0205-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O205-A 인수인계

### ▣ O205-A-0 🔴 먼저 알아라 (2026-10-07 · JU93656 · ㉡ 적용 · 확정위반 0)

- 🟢 2차 Agent 개선 계획 = `12_agent개선과제/00_작업계획.md` §8(U1~U4) · 라벨 O205 원장 선점 등재.
- 🟢 파일 완료(라이브 미배포): WIDE_MEMBER_FEE(+획득 8축) · WIDE_MEMBER_SERVICE_COHORT(신설) · `_wide_schema.yml` · 05_9 · 05_18(신설).
- 🟢 사전 검증 = 원천 직접 집계로 같은 로직 실행 · 질문1 = 선넘는좋은일 상위캠페인 2026-01~09 가입 4,174명(수신 3,508 · 미수신 666).
- 🔴 「선넘는좋은일 캠페인 가입」은 캠페인명이 아니라 상위캠페인명(ACQ_PARENT_CAMPAIGN_NAME)에 있다.
- 🔴 신규 발견 = 캠페인행사(CRMN) FEA.DATE_SK 166,962행 전부 1970-08 계열(날짜 깨짐 · 문서50 미등재).

### ▣ O205-A-1 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 👤 dbt build | `dbt build --select WIDE_MEMBER_FEE WIDE_MEMBER_SERVICE_COHORT --project-dir /10_dbt_pipeline` |
| 2 | SV 배포 | 05_9 재배포 · 05_18 신설 배포 · 스모크(수신 3,508 · 미수신 666) |
| 3 | AGENT_MEMBER | 도구 `analyst_service_cohort` 추가 · analyst_member_fee 설명에 8축 · 「SV 간 교차계산 금지」에 예외 1줄 · 질문1~3·회비 질문 재질문 |
| 4 | 👤 현업 확인 3 | ① 서비스명 ↔ 발송 제목 규칙 ② 문화이벤트 = 캠페인행사? ③ 효과 대조군 기준 → 문서20 등재 |
| 5 | 이슈 등재 | CRMN DATE_SK 1970 계열 → 문서50 |

㉡ 워크스페이스 백로그

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 9 | ㉡ 👤 MSTR 일일 적재(전월+당월) | ⏸ 현업 회신 대기(O203-A-1 승계) |

### ▣ O205-A-2 ⚪ 결정 완료(재론 금지)

- 서비스 코호트 grain = 회원 × 서비스그룹 × 수신연도(제목 grain 은 28,884,126 조합이라 폐기).
- 서비스그룹 규칙 = 모델 내 rules CTE(seed 아님) · 현업 확정 시 CTE 만 교체.
- 회비 8축 = DIM_MEMBER_ACQUISITION 기존 컬럼 노출(조인 추가 없음 · 획득 시점 동결값).

_Co-authored with CoCo_

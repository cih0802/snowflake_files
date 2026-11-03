<!-- LLM-METADATA
doc_id: HANDOFF_O0198_B
doc_role: 인수인계 — 세션 `O198-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-02
created_by: O198-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0198-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O198-B-0 🔴 먼저 알아라 (2026-10-02 · 개발계 pw69582 · 사용자 결정 4건 집행 + 부서 질의 분류)

- 🟢 dbt build(사용자 PASS 18) 판정 = FACT_BUDGET 1,488행 · 편성 44,707,991,168 · 집행 55,094,546,656 불변 · grain 중복 0 · 경로 7 · 예산단위 6 · DIM 단위 NULL 0 ⇒ DEC-60 종결.
- 🟢 Agent = MEMBER V7 · EXEC V8 · MKT V8(도구 10 · `analyst_ml_dvlp_forecast`·`analyst_ml_member_risk` 신규 배선) · 롤백 = V6 · V7 · V7.
- 🟢 3 Agent response 신규 규칙 2 = **합계 규칙**(도구 합계 행 사용 · 암산 금지) · **부재값 응답 규칙**(조회 안 됨 + 조회되는 유사 항목과 값 · 동일 조직 단정 금지).
- 🟢 GN_DW_ANALYST 스모크 4/4 라우팅 HIT · 실측 대조 일치(`tmp/nlsmoke_o198_b/`).

### ▣ O198-B-1 부서 질의 분류(실측 2026-10-02 · ANALYST 권한 기준)

| 부서 | 질의 | 분류 | 근거 |
|---|---|---|---|
| 기획실 | 부서별·후원사업별·전체 연도말 개발 예측치(자체 수식) | ⛔ 데이터 없음 | `SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA` 계정 전역 부재(ACCOUNT_USAGE 0 · 문서 0) · ML 3종은 O195 DROP |
| 회원실 | 연사업·월·추경 회비예측(자체 수식) | ⛔ 데이터 없음 | `SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA`·`MM_SPNSR_CLS_AGGR_DATA` 부재 |
| 나눔마케팅 | 익월·연말·향후 3개월 회원개발 **건수** 예측 | 🟠 데이터 있음 · 단위 불일치 | ML 원천 = 금액(만원)만 · 건수 예측 0 ⇒ 금액으로 답하고 건수 미제공 고지 |
| 나눔마케팅 | 계절성·휴일 반영 여부 | 🟠 메타 없음 | 모델 설정이 데이터에 없다 |
| 나눔마케팅/회원실 | 증액 캠페인 우선 제안 대상 회원 | 🟢 배선 완료(회원 목록) · 🟠 캠페인 추천은 grain 부재 | INC 원천 91,423행 → 뷰 74,949명(회원당 1행) · 캠페인 축 없음 |

### ▣ O198-B-2 🟠 남은 작업

| 순 | 작업 | 대기 |
|---|---|---|
| 1 | 기획실·회원실 SILVER 집계 3종 | 현업에 테이블 DDL·자체 계산 수식 요청 → SILVER 신설 · 적재 · SV |
| 2 | ML 12종 재공유 | A 계정 02번 6.3 결과로 05번 신규 2종 확정 · SERVING LTV 뷰 2종 재배선 |
| 3 | O197 계열 | MSTR 원 리포트 대조 · 이력 재적재 · 스킬화 |

_Co-authored with CoCo_

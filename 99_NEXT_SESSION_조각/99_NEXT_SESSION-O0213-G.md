<!-- LLM-METADATA
doc_id: HANDOFF_O0213_G
doc_role: 인수인계 — 세션 `O213-G` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-G
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-G -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-G 인수인계 (Y3-F 라이브 · Y3-G·J·I·K 반영 · dbt 정지점 · Y3 전 도메인 착수 완료)

### ▣ O213-G-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 0 · 자가 결함 2 = BIGQUERY_SESSION 주석 이중중괄호 Jinja 컴파일 에러(사용자 deploy 적발 · 수정) · _wide_schema.yml edit 1행 탈락(즉시 복원 · yaml 파싱 검증))

- 🟢 Y3-F 라이브 = build+백필 · 6테이블 원천 행수 일치 · SV 3종 3값 일치 · VQR 3 · GN_DW_ANALYST 조회 확인.
- 🟢 Y3-G·J·I·K = 모델·DDL·물리(ALTER 6 · 선생성 3) · SV 정본 반영 완료 — **데이터·배포는 build 후**.
  · G = `FACT_AD_PERFORMANCE` +10 → `WIDE_AD_COMBINED` +10(yml 61=61) → SV_AD +10
  · J = 신규 `DIM_RELATIONSHIP`(결연 grain) + `FACT_RELATION_ACTIVITY` 정산은행 +2 → SV_RELATION_ACTIVITY(rel 연결 + 4차원)
  · I = `PART_USE_YN` → SV_EVENT_PARTICIPATION +1
  · K = `DIM_BUDGET_ITEM` +4 → SV_BUDGET·SV_BUDGET_YEARLY 각 +4 · 신규 `ERP_EXPENSE_RESOLUTION` → `FACT_EXPENSE_RESOLUTION` → `SV_EXPENSE_RESOLUTION`(0행 라이브 · Agent 미연결)
- 🔴 목표 팀명·후원사업구분 2축은 **이미 배선**이었다(SILVER 개명 → SV_TARGET_BIZ) — Y1 lineage NONE 의 개명 미추적 오판.
- 🔴 신규 현업 확인 = 문서20 N-29 ⑥(상위캠페인 코드·이름 혼재 · 보류) ⑦(결연 중단사유 MM002 잠정) ⑧(지출결의 동일 행 7,287 보존).

### ▣ O213-G-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 dbt build(아래) → 비NULL 검증 → SV 6종 배포(`tmp/o213_y3_deploy.py SV_AD SV_RELATION_ACTIVITY SV_EVENT_PARTICIPATION SV_BUDGET SV_BUDGET_YEARLY SV_EXPENSE_RESOLUTION`) → 스모크(G 10 · J 4 · I 1 · K 8 · 지출결의 3값 212,342,534,942) | ⏸ 정지점 |
| 2 | 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드) · S3 잔여 판정 | |
| 3 | **Y4** Agent 도구 배선 — 신규 SV 5종(PAYMENT_BILLING_STATUS · GA_SESSION · SEARCH_CONSOLE · GA_DEMOGRAPHIC · EXPENSE_RESOLUTION) + 기존 SV 신규 축 동의어·규칙 → ADD VERSION | 다음 큰 단계 |
| 4 | Y5 스모크 · Y6 eval(과금) · OPS 임시 객체 DROP(O213_* 7표 · 프로시저 5) | 마지막 |

- dbt 명령(사용자 실행): `dbt build --select FACT_AD_PERFORMANCE+ CRM_RELATION_ACTIVITY+ DIM_RELATIONSHIP+ CRM_EVENT+ DIM_BUDGET_ITEM+ ERP_EXPENSE_RESOLUTION+ --project-dir 10_dbt_pipeline`

### ▣ O213-G-2 ⚪ 결정 완료(재론 금지)

- O213-A~F 결정 전건 유지 + 아래 추가:
- 광고 분류 축은 코어 팩트(AD_PERF_DK 1:1)에 degen 으로 붙인다(소재 차원 SK 는 전건 0 이라 경유 불가).
- 결연 상태·중단사유는 신규 결연 차원(RELATNSP_KEY PK)에 둔다(사건 팩트 3종에 넣지 않는다).
- 지출결의는 예산 원장과 별도 팩트·SV — 금액 대조·합산 금지 · 원천 동일 행은 현업 회신 전까지 보존.
- dbt 파일 주석에 이중 중괄호를 쓰지 않는다(Jinja 선파싱).

_Co-authored with CoCo_

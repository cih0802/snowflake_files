### ▣ O259-A-0 🔴 먼저 알아라

- `O259-A` = 조직도 Silver 정제 · Agent 소계(ROLLUP) 제거 · 광고 원천 개명(보류) (2026-10-23 · TRIALADMIN(SR61467) · ㉡ · 사용자 승인 「전부 승인」 · 확정위반 0).
- 직전 단위 = `99_NEXT_SESSION-O0258-A.md` (그 ①② 와 ㉡ 는 그대로 유효 · 아래 ㉡ 로 승계).
- 근거 정본 = `tmp/o259/evidence.md`(E1~E6 · 판정 전 기록) · 계획 = `tmp/o259/O259_작업계획_조직도정제_소계제거_광고원천개명.md`.
- 결정 = **DEC-64**(`30_설계_의사결정-017.md` 말미 · 폐기 정의 = 활성 트리 단일화 · 규칙 Silver 이관).

### ▣ O259-A-1 현재 작업 계정 (🔴 이 단위의 라이브 판정은 전부 이 계정 기준)

| 항목 | 값 |
|---|---|
| 계정 | `SR61467` (개발계 · 트라이얼) |
| 사용자 | `TRIALADMIN` |
| 역할 | 작업 = `ACCOUNTADMIN` · 배포 DDL = `GN_DW_ADMIN` · dbt 실행 = `GN_DW_DBT` |
| 웨어하우스 | `COMPUTE_WH`(세션 기본) · `GN_DW_DEV_WH`(배포 파일) · `GN_DW_ETL_WH`(dbt) |
| 워크스페이스 | `USER$.PUBLIC."snowflake_files"` |
| 이 계정 반영 상태 | 요건 1·2 라이브 완료 · 요건 3 미반영(원천에 신규 컬럼 없음) |

- 🔴 **사용자 결정(2026-10-23)**: 요건 3 은 **새 개발계를 구성해서** 진행한다 ⇒ 이 계정에서 요건 3 을 착수하지 마라.
- 🔴 새 계정에서는 이 표의 수치를 인용하지 말고 다시 잰다(`R2-8-4-a` · 계정 표기 없는 판정은 근거가 아니다).

### ▣ O259-A-2 결과 (SR61467 · 2026-10-23)

| 요건 | 결과 |
|---|---|
| 1 조직도 | 신규 `SILVER.CRM_ORG_CLEAN`·`CRM_ORG_SUCCESSION`(dbt) + `V_ORG_PICKER`(DDL 뷰) · GOLD `DIM_ORG`·`DIM_ORG_SUCCESSION` = Silver ref(SK 만) · 렌더 MINUS 양방향 0 · 👤 build PASS=35 · CLEAN 1,314 / ACTIVE 223 · picker 폐기 0 · Gold↔Silver 차이 0 |
| 2 소계 | SV 30파일(05_01~05_26 · 22 · 25 · 34 · MSTR `05_MSTR_SV_DDL.sql`) 지시문·VQR 14건 평면화 · 전체 합 = 행이 아니라 열(O241-T 1회 호출과 정합) · Agent 정본 3종 합계 규칙 개정 · 라이브 SV 44 중 ROLLUP 잔존 0 · Agent MEMBER $6 · EXECUTIVE $6 · MARKETING $7(default) · Analyst 재질의 3/3 평면 GROUP BY |
| 게이트 | 신설 `scripts/sv_no_rollup_gate.py`(분모 35) + `test_sv_no_rollup_gate.py` 8/8 · `session_brief.py` GATES 등재 |
| 3 광고 개명 | ⏸ 보류 — 원천 미반영(E1) · 아래 ㉠ ② |

### ▣ O259-A-3 ㉠ 잔여 — 🔴 계정이 바뀌면 진행할 작업

| 순 | 작업 | 판정 |
|---|---|---|
| ① | **새 개발계 구축 시 O259 반영 확인** — 신규 구축은 문서실행순서 본 순서(08 SILVER DDL 끝에 O259 블록 포함 · dbt build 전체 · SV 전체)로 들어간다 · 증분이면 「기존 환경 갱신」 34 → 35 · 확인 = `39_DEPLOY_SILVER_ORG_CLEAN.sql` [D3](picker 폐기 0) · `sv_no_rollup_gate` PASS · 라이브 SV ROLLUP 잔존 0(E6 블록) | 새 계정 |
| ② | **요건 3 광고 원천 컬럼 개명** — 새 계정 BRONZE 에서 `INFORMATION_SCHEMA.COLUMNS` 로 `VIDEO_AD_CMPGN_DTLS.UPPER_CMPGN_CD` · `REBRDC_AD_CMPGN_DTLS.MKTG_CMPGN_NM` 실재·값 분포 실측 → `AGENCY_AD_ROW_VIDEO.sql:39·82` · `AGENCY_AD_ROW_REBRDC.sql:38·59` · `AGENCY_AD_PERFORMANCE.sql:165`(주석 `:23·:130`) 수정(VIDEO = 이름→코드 축 · REBRDC = 코드→명칭 축 · 🔴 `CMPGN_CD` 전역 치환 금지) → `_sources.yml:195~196` · `_wide_schema.yml` · `32_컬럼개명표.md` · SV 05_07 → 👤 build → 행수·합계 신구 대조(새 계정 기준값으로) | 새 계정 · 원천 반영 후 |
| ③ | 운영계 = 문서실행순서 「기존 환경 갱신」 33 → 34 → 35(백필 없음 · `R2-9`) · 원천 개명이 운영계에 오는 시점 확인 후 요건 3 배포 | 👤 운영계 |
| ④ | 현업 안내 — Streamlit 개발자에게 Silver 소비 객체(`CRM_ORG_CLEAN`·`CRM_ORG_SUCCESSION`·`V_ORG_PICKER`) 공지 · 폐기 판정은 `ORG_STATUS` 하나(`USE_YN` 단독 금지 · DEC-64) | 현업 |

- 🔴 Silver 에 뷰를 dbt 모델로 만들지 마라 — pre-hook `silver_purge`(TRUNCATE)가 뷰에서 실패한다.
- 🔴 SV 재배포 순서 = 05_* → 22 → 25 → 34(34 가 SV_ML 3종 최신본) · MSTR SV 는 `15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql`.
- 🔴 05_* SV 는 `CREATE OR ALTER` 라 `created_on` 이 바뀌지 않는다 — 반영 확인은 `GET_DDL` 내용으로 한다.

### ▣ O259-A-4 ㉡ 워크스페이스 백로그

- O258-A-2 ② · O258-A-3 그대로 승계.
- 🟠 SV 6종(SV_AD_INFLOW_ALLOC · SV_MEMBER_EVENT_COHORT · SV_ML_FEE_FORECAST_AXIS · SV_ML_INC_CAMPAIGN · SV_ML_MEMBER_PRED_AXIS · SV_ML_REALTIME_SIMULATOR)은 O206-C 공통 블록 자체가 없다(ROLLUP 지시도 없음) — 공통 규칙 일원화 여부는 별건.

_Co-authored with CoCo_

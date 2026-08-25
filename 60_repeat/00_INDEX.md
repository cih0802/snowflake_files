# GN_DW 재현(replay) 파일 묶음 — 60_repeat

> 목적: **다른 계정(신규/paid)에 GN_DW 구조(환경·RBAC·BRONZE→SILVER→GOLD→dbt→SERVING SV/Agent)를 처음부터 재현**하는 데 필요한 파일만 모은 폴더.
> 실행 절차 정본 = `PAID_재현_런북_20260722.md`(본 폴더에 동봉). Phase 0~6 순서를 그대로 따른다.
> ⚠️ 이 폴더는 원본의 **복사본**이다. 원본 경로(`02_GN_DW_building/`, `04_silver_design/` 등)가 최신 원천이며, 이후 원본이 갱신되면 본 폴더도 다시 복사해야 한다.
> ⚠️ 데이터 자체(BRONZE 원천 데이터, ML 예측결과)는 포함하지 않는다 — 신규 계정에서 원천을 새로 적재하는 시나리오 기준(A→B→C 데이터 이관 시나리오는 별도, `50_handoff/`의 A_PRODUCER/B_BROKER/C_CONSUMER 참고).

## 폴더 구성 (Phase 순서 = 폴더 번호)

| 폴더 | Phase | 원본 경로 | 역할 |
|---|---|---|---|
| `01_rbac/` | 0·1 | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` | §A~C(WH 3·역할 6·계층·grant) + §B.5(DB 생성·ADMIN 소유·9스키마) + §D·D.5(적재 grant) + §E·G(SERVING grant·helper) + §F(CoWork). **통째 실행 금지 — 런북의 Phase별 분할 실행표 따를 것** |
| `02_bronze/` | 2 | `50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql` | BRONZE 4스키마 테이블 구조 DDL(`CREATE DATABASE`~`USE ROLE GN_DW_ADMIN` 포함). 런북이 가리키던 구 파일(0713판)의 최신본 |
| `03_silver/` | 3 | `04_silver_design/08_SILVER_테이블DDL_20260714.sql` | SILVER 32테이블 구조 DDL(`USE ROLE GN_DW_ADMIN` 프리앰블 포함) |
| `04_gold/` | 3 | `03_top-down_gold/06_DDL.sql` | GOLD 24테이블(15 DIM+9 FACT) 구조·컬럼 COMMENT·FK DDL |
| `05_dbt/` | 4 | `10_dbt_pipeline/` (전체, `logs/`·`target/`·`_archive/` 제외) | dbt 프로젝트 — SILVER/GOLD 증분 모델 56 + WIDE 뷰 9 + 테스트 167. `CREATE DBT PROJECT` 뒤 `EXECUTE DBT PROJECT ARGS='build'`로 실행 |
| `06_serving_sv/` | 5 | `05_SV-Agent_ai/05_0_SV_DDL.sql` ~ `05_10_...sql` | Semantic View DDL. `05_0`은 정의 없는 인덱스+검증 파일, `05_1`~`05_10`이 실제 SV(현재 SV 9~10종, 파일 간 순서 무관·각자 완결) |
| `07_agent/` | 5·6 | `05_SV-Agent_ai/09_1_AGENT_생성.sql`·`09_2_AGENT_버전업.sql`·`12_paid_테스트_실행가이드.md` | Agent 껍데기 생성(09_1) → 스펙 본문 적용(09_2, `cortex_project/agents/*/agent_spec.yaml` 필요) → paid 이관 후 NL 스모크 가이드(12) |
| `08_cortex_project/` | 5 | `cortex_project/agents/*/agent_spec.yaml`·`cortex_project/cortex-project.yaml` | `09_2`가 읽는 Agent 스펙 YAML + 매니페스트. **원본 위치(`cortex_project/`)는 이동/개명 금지**(semantic_studio 툴이 그 경로에서만 탐색) — 신규 계정에서는 이 복사본을 새 워크스페이스의 `cortex_project/`에 그대로 두고 시작 |
| `PAID_재현_런북_20260722.md` | — | 루트 | 전체 실행 순서 정본(Phase 0~6, 07 분할표, 완료 검증 체크리스트) |

## 참고 — 런북 작성 시점(07-22) 이후 갱신된 부분

런북 본문의 일부 파일명은 이후(O37·O38·O45·O54~O57) 분할·개명되었다. 본 폴더는 **현재 시점(2026-08-25) 기준 최신 파일**로 채웠다:
- `05_SV_DDL.sql`(단일) → `05_1`~`05_10`(SV 단위 분할, 2026-08-05 O37)
- `09_AGENT_spec_구현.sql` → `09_1_AGENT_생성.sql` + `09_2_AGENT_버전업.sql`(2026-07-31 분해)
- `02_SERVING_setup.sql`은 DEPRECATED 스텁이라 미포함(RBAC 정본은 `01_rbac/`)
- SV 개수: 런북 작성 시 "5" → 현재 실측 9~10종(`SV_MEMBER_SPONSOR_BIZ` 포함 시 10)

## 실행 순서 요약 (상세는 `PAID_재현_런북_20260722.md`)
1. `01_rbac/`의 §A~C·§B.5 (분할 실행)
2. `02_bronze/` → 원천 데이터 적재
3. `03_silver/` → `04_gold/` (빈 구조)
4. `01_rbac/`의 §D·D.5 → `05_dbt/`로 `CREATE DBT PROJECT` + `EXECUTE ... ARGS='build'`
5. `01_rbac/`의 §E·G → `06_serving_sv/` → `07_agent/09_1`·`09_2`(+ `08_cortex_project/`)
6. `01_rbac/`의 §F(CoWork) → `07_agent/12_...`로 NL 스모크

_Co-authored with CoCo_

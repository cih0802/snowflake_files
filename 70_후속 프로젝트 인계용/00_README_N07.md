# 후속 프로젝트 인계용 — 범용 표준 템플릿 패키지 (N07)

> doc_id: N07 · as_of: 2026-10-20 · 작성 O247 · 원본 = GN_DW(굿네이버스) 프로젝트 산출물
> 목적 = 다른 고객·다른 계정에서 Snowflake DW(메달리온 + dbt + Semantic View + Cortex Agent)를 만들 때 처음부터 쓰는 골격.
> 🔴 고객명·실제 객체명은 `<PRJ>`(프로젝트 접두) · `<DB>` · `<WH_*>` 자리표시자로 바꿨다. 실행 전에 전부 치환한다.

## 구성

| 파일 | 무엇 | GN_DW 원본 |
|---|---|---|
| `01_RBAC_골격.sql` | 롤 7종 · 스키마 계층 · FUTURE GRANT 골격(🔴 미실행 템플릿) | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` · `85_…/A2_롤별_접근권한_설계.csv` |
| `02_dbt_골격.md` | dbt 프로젝트 레이어 규약 · 배포 · 실행 롤 · 하지 말 것 | `10_dbt_pipeline/` · `85_…/A4` |
| `03_SV_Agent_작성규칙.md` | SV DDL · metric · VQR · Agent spec 버전업 규칙 | `05_SV-Agent_ai/` · `85_…/A5` · DEC-49 · DEC-52 |
| `04_모니터링_SQL.sql` | 비용 · 일배치 · 권한 · 보안 감시 쿼리(읽기 전용) | `85_…/_근거쿼리/N06_*` · `D10_*` · A6 |
| `05_인수인계문서_규약.md` | 산출물 헤더 · `[공통]/[ENV]` 분리 · 근거 SQL · 드리프트 · 미실행 SQL 표기 | `85_…/00_작업계획서.md` §1 |

## 쓰는 순서

1. `05` 규약으로 문서 틀을 먼저 정한다(계정 값과 공통 값을 처음부터 나눈다).
2. `01` → 원천 적재 → `02`(dbt) → `03`(SV → Agent) 순서로 만든다. 🔴 SV 를 Agent 보다 먼저 만든다.
3. 운영 시작과 함께 `04` 를 주 1회 돌린다.

## GN_DW 에서 실제로 겪은 함정 (그대로 다시 겪지 않게)

| 함정 | 결과 | 막는 법 |
|---|---|---|
| 정본 DDL(`CREATE OR REPLACE TABLE`)을 운영 중에 다시 실행 | 데이터·FK·GRANT 전부 소실 · dbt ERROR 3 · SKIP 68 | 평상시 변경은 `ALTER` + 같은 세션에 정본 DDL 수정 |
| SV · Agent 를 `CREATE OR REPLACE` | GRANT 소실 · Agent 버전 소실 | SV = `CREATE OR ALTER` · Agent = `ADD VERSION` |
| 롤 권한 점검을 보조 롤이 켜진 채로 | 차단돼야 할 것이 통과(오탐) | `USE SECONDARY ROLES NONE` 먼저 |
| 분류기(`SYSTEM$CLASSIFY`)만 믿고 개인정보 점검 | 한국어 이름·국내 휴대폰 미검출 | COMMENT·값 형태 집계를 함께 |
| 비용 가드 스크립트의 「미적용」 주석만 믿고 전체 실행 | 한도·차단이 바로 켜짐 | 옵션 구문은 반드시 주석 처리 · 실행 전 `GET_CONFIG()` |
| Resource Monitor 로 AI 비용을 막으려 함 | 막히지 않는다(웨어하우스 전용) | AI = per-user quota · Budget |
| CoCo 사용량을 인터페이스별 뷰와 통합 뷰에서 함께 합산 | 2배 과대 | 도메인별 정본 뷰 1개만 |
| 플래그 컬럼(`*_MEMBERS`)을 「명」으로 합산 | 20~45% 과대 | 「명」은 `COUNT(DISTINCT 회원)` |
| 실행순서 문서의 줄 앞에 표기(🆕 등)를 붙임 | 패키지 생성 정규식이 그 줄을 놓침 | 경로를 줄 맨 앞(번호 바로 뒤)에 둔다 |

_Co-authored with CoCo_

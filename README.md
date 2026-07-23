# GN_DW — 굿네이버스 데이터웨어하우스 프로젝트

> 워크스페이스 **최상위 진입점(색인)** 문서. 전체 폴더의 역할·관계·진행 흐름을 한곳에 정리한다.
> 프로젝트: 굿네이버스(Good Neighbors) GN_DW. PoC를 운영 등급 DW로 이관하며, **BRONZE → SILVER → GOLD → SERVING** 메달리온 아키텍처 위에 Semantic View·Cortex Agent 기반 AI 분석 서비스를 구축한다.
> 각 폴더는 독립 README(진입점 색인)를 가진다. 상세는 해당 폴더 README 참조.
> 2026-06-24 갱신: 회의 정의서 4종 반영 → 데이터 도메인 확장(CRM·GA4·ERP·AGENCY + **GADS·ADMIN**). 단 **GADS·ADMIN은 AGENCY 또는 CRM으로 통합 예정(목적지·접두사 미정)** → 물리 원천 수 4~6으로 가변. 또한 **CRM 테이블은 현재(라이브) 43개**(2026-06-24 기준 40개에서 확장). 변경분 정본은 `03_top-down_gold/GOLD_정의서_업데이트 20260624.md`.

---

## 전체 흐름

```
00_PoC_bak ──► 01_project_sample_legacy ──► 02_GN_DW_building ──► 03_top-down_gold ──► 04_silver_design ──► 05_SV-Agent_ai
 (PoC 백업)      (1차 구축안·레거시)    (설계 정본·SERVING)    (GOLD 정본)         (SILVER 설계)        (SV·Agent 설계)
```

프로젝트는 PoC(원천) → 운영 이관 설계 → 계층별 상세 설계(GOLD→SILVER) → 의미계층(SV/Agent) 순으로 **top-down** 진행된다.

---

## 폴더 명세

| # | 폴더 | 역할 | 상태 |
|---|------|------|------|
| 0 | `00_PoC_bak/` | **PoC 산출물 백업**. PoC 당시 구축한 파이프라인(Excel→RAW→ANALYTICS)·Semantic View 7·Cortex Agent의 DDL/해설 기록. | 완료(원천·참조용) |
| 1 | `01_project_sample_legacy/` | **1차 구축안**. PoC를 운영 DW(`GN_DW`)로 재설계하는 메달리온(BRONZE→SILVER→GOLD) 구축 문서·SQL 8단계. | 문서화 완료(레거시·참고용) |
| 2 | `02_GN_DW_building/` | **설계 정본(작업계획서)**. 운영 등급 이관 설계. `01` 대비 핵심 변경점 = **SERVING 계층 분리(4계층)**. | 설계 문서화 단계(라이브 전) |
| 3 | `03_top-down_gold/` | **GOLD 정본**. 지표 215개(top) 기반 GOLD star schema(down) 설계 = **15 DIM + 9 FACT**. | Top-down 1~7단계 완료 |
| 4 | `04_silver_design/` | **SILVER 설계**. GOLD 요구(역산) + BRONZE 적재현황 2축으로 SILVER 정제 레이어 설계. SILVER 32테이블(라이브). | 문서화 완료(CRM 즉시 가능) |
| 5 | `05_SV-Agent_ai/` | **SERVING 의미계층**. GOLD 위 Semantic View 5 배포 + Cortex Agent 2 배포(회원·overall). derived 81 metric 배속. 배포 산출물=루트 `cortex_project/`. | 0~7단계 완료(SV 배포·검증·평가셋·Agent 배포·CoWork 연결·거버넌스), NL 스모크만 paid 대기 |

> 폴더 위상 요약: `03`(GOLD)·`04`(SILVER)·`05`(SV/Agent)가 **현행 정본 트랙**. `02`는 상위 설계 정본이며 GOLD 상세는 `03`에 위임. `00`·`01`은 원천/레거시 참조용.

---

## 아키텍처 (4계층 메달리온)

```
BRONZE  원천 1:1 적재 (CRM 43테이블 전수 ✅ / AGENCY 3·ERP 1·GA4 1 부분 입고: 광고 스캐폴드·예산원장·GA4 1일 샤드 / 전기간·모금성비용·사업목표 등 잔여 입고 대기 / GADS·ADMIN 통합 예정·미정)
  ▼  정제 (타입·NULL·코드라벨·중복제거, 행 granularity 유지)
SILVER  GN_DW.SILVER 단일 스키마 (소스 접두사 CRM_*/GA4_*/ERP_*/AGENCY_*; GADS·ADMIN은 통합 결정 후 접두사 확정), 32테이블
  ▼  집계·통합 (star schema)
GOLD    15 DIM + 9 FACT (지표 215 → measure 60 + derived 81)
  ▼  의미계층
SERVING Semantic View 5 배포(회원월·회원이벤트·서비스·행사참여·예산 / 최종 7) + Cortex Agent 2 배포(회원·overall / 최종 3)
```

- 계층 규칙: `SERVING → GOLD → SILVER → BRONZE` **단방향 참조**. GOLD의 BRONZE 직접 참조 금지.
- 데이터 현황(라이브 2026-07-22): **CRM 전수 수령**(BRONZE_CRM 43) + **GA4·ERP·AGENCY 부분 입고**(BRONZE_AGENCY 3·ERP 1·GA4 1 → GOLD FACT_AD 235K 스캐폴드·FACT_BUDGET 24.5K·FACT_GA 44.9K 1일 샤드). 전기간·모금성비용·사업목표 등 잔여는 입고 대기 → 해당 metric은 입고 후 활성(의도된 대기).

---

## 핵심 정합 수치
- 지표 **215** = 공통 162 + 신규 53 → measure 60 + dimension 74 + derived 81
- GOLD **24** 물리테이블 = 15 DIM + 9 FACT (base measure 61)
- 데이터 도메인 = CRM·GA4·ERP·AGENCY + **GADS·ADMIN**. 단 GADS·ADMIN은 AGENCY/CRM으로 통합 예정(목적지 미정) → **물리 원천 4~6 가변**. GOLD 귀속(GADS→FAD / ADMIN→FSE)은 통합 경로와 무관하게 확정.
- SILVER **32** = CRM 22 + GA4 5 + ERP 2 + AGENCY 2 + bridge 1 (라이브 실측 2026-07-22; CRM은 확장 가능 / GADS·ADMIN은 통합 prefix에 흡수)
- SERVING = SV **5** 배포(최종 7) / Agent **2** 배포(최종 3) (derived 81 전수 배속)

---

## 부속 폴더 (루트 정리 2026-07-22)
| 폴더 | 내용 |
|------|------|
| `00_guides/` | 데이터설계 방법론(킴볼)·엔터프라이즈 아키텍처 가이드 2종·MFA 로그인 가이드 |
| `06_reference/` | 스크립트 생성 스키마 컬럼 인벤토리(SILVER·GOLD, 20260716) |
| `50_handoff/` | 인계·크로스커팅 산출물: `IT팀_전달 인덱스.md`·`ETL_프로시저 설계.md`·`GOLD_개발자 전달노트`·`문서검토_체크리스트`·`예산 안.md`·데이터마이그레이션 3종(md+DDL+setup) |
| `99_provided_definition/` | 현업 제공 정의: 지표사전·용어·`컬럼정의서`·`테이블정의`·`GA4스키마`·`BRONZE_CRM 테이블 정보.MD` |
| `08_mornitoring/`·`10_dbt_pipeline/`·`20_issue/`·`30_output_share/` | 거버넌스 근거·dbt 파이프라인·이슈 원장·현업 공유 산출물 |
| `scripts/` | 인벤토리 재생성·코멘트 주입 등 파이썬/SQL 도구 |
| `_archive/` | 구설계·레거시 스냅샷(구 인벤토리 CSV·연동 테스트 기록 등). **참조 정본 아님** |

## 루트 참고 파일
| 파일 | 역할 |
|------|------|
| `PAID_재현_런북_20260722.md` | **paid 계정 재현(replay) 정본** — 환경·RBAC·BRONZE→SILVER→GOLD→dbt→SV/Agent 의존성-안전 실행 순서. 07 분할·DB 소유·DBT PROJECT 최초생성 등 함정 정리. |
| `OPS.sql` / `TEARDOWN.sql` / `setup_20260702.sql` / `로그인 인증 …_Account Admin.sql` | 운영·셋업·일회성 스크립트(스크래치). |
| `Untitled*.sql` | 임시 스크래치 쿼리. |
| `cortex_project/` | **semantic_studio 툴 관리 배포 폴더(비번호·이동/개명 금지)**. Cortex Agent 스펙 YAML + `cortex-project.yaml`(artifact→Snowflake FQN 매니페스트). `05_SV-Agent_ai/08_AGENT_spec.md`가 사람용 설계 정본이고, 이 폴더는 그 **배포 산출물(IaC)**. 툴이 `cortex_project/` 또는 루트에서만 매니페스트를 탐색하므로 번호부여/이동 시 배포가 깨진다. |

> `GA 커넥터 테스트.md`·`sharepoint 데이터 테스트.sql`(원천 연동 테스트 기록)는 `_archive/`로 이관됨(2026-07-22).

---

## 읽는 순서 (신규 진입자)
1. 본 문서(전체 조감) → 2. `02_GN_DW_building/README.md`(설계 정본·아키텍처) → 3. `03_top-down_gold/`(GOLD) → 4. `04_silver_design/`(SILVER) → 5. `05_SV-Agent_ai/`(SV·Agent)
   - 배경 이해가 필요하면 `00_PoC_bak/` → `01_project_sample_legacy/` 먼저 참조.

## 현재 상태 (요약)
- 설계 트랙: GOLD ✅ / SILVER ✅(문서) / SV·Agent ✅(SV 5·Agent 2 배포·검증·평가셋·CoWork 연결·거버넌스 완료; NL 스모크만 paid 이관 대기).
- 데이터 트랙: BRONZE CRM 전수(43) + GA4·ERP·AGENCY **부분 입고**(GA4 1일 샤드·ERP 예산·AGENCY 스캐폴드) → 전기간·잔여 입고 시 SILVER/GOLD/SV 확장.

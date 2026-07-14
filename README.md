# GN_DW — 굿네이버스 데이터웨어하우스 프로젝트

> 워크스페이스 **최상위 진입점(색인)** 문서. 전체 폴더의 역할·관계·진행 흐름을 한곳에 정리한다.
> 프로젝트: 굿네이버스(Good Neighbors) GN_DW. PoC를 운영 등급 DW로 이관하며, **BRONZE → SILVER → GOLD → SERVING** 메달리온 아키텍처 위에 Semantic View·Cortex Agent 기반 AI 분석 서비스를 구축한다.
> 각 폴더는 독립 README(진입점 색인)를 가진다. 상세는 해당 폴더 README 참조.
> 2026-06-24 갱신: 회의 정의서 4종 반영 → 데이터 도메인 확장(CRM·GA4·ERP·AGENCY + **GADS·ADMIN**). 단 **GADS·ADMIN은 AGENCY 또는 CRM으로 통합 예정(목적지·접두사 미정)** → 물리 원천 수 4~6으로 가변. 또한 **CRM 테이블은 현재 40개 기준이며 추후 확장 가능**. 변경분 정본은 `03_top-down_gold/GOLD_정의서_업데이트 20260624.md`.

---

## 전체 흐름

```
00_PoC_bak ──► 01_project_sample ──► 02_GN_DW_building ──► 03_top-down_gold ──► 04_silver_design ──► 05_SV-Agent_ai
 (PoC 백업)      (1차 구축안·레거시)    (설계 정본·SERVING)    (GOLD 정본)         (SILVER 설계)        (SV·Agent 설계)
```

프로젝트는 PoC(원천) → 운영 이관 설계 → 계층별 상세 설계(GOLD→SILVER) → 의미계층(SV/Agent) 순으로 **top-down** 진행된다.

---

## 폴더 명세

| # | 폴더 | 역할 | 상태 |
|---|------|------|------|
| 0 | `00_PoC_bak/` | **PoC 산출물 백업**. PoC 당시 구축한 파이프라인(Excel→RAW→ANALYTICS)·Semantic View 7·Cortex Agent의 DDL/해설 기록. | 완료(원천·참조용) |
| 1 | `01_project_sample/` | **1차 구축안**. PoC를 운영 DW(`GN_DW`)로 재설계하는 메달리온(BRONZE→SILVER→GOLD) 구축 문서·SQL 8단계. | 문서화 완료(레거시·참고용) |
| 2 | `02_GN_DW_building/` | **설계 정본(작업계획서)**. 운영 등급 이관 설계. `01` 대비 핵심 변경점 = **SERVING 계층 분리(4계층)**. | 설계 문서화 단계(라이브 전) |
| 3 | `03_top-down_gold/` | **GOLD 정본**. 지표 215개(top) 기반 GOLD star schema(down) 설계 = **12 DIM + 6 FACT**. | Top-down 1~7단계 완료 |
| 4 | `04_silver_design/` | **SILVER 설계**. GOLD 요구(역산) + BRONZE 적재현황 2축으로 SILVER 정제 레이어 설계. SILVER 24테이블. | 문서화 완료(CRM 14 즉시 가능) |
| 5 | `05_SV-Agent_ai/` | **SERVING 의미계층**. GOLD 위 Semantic View 4 + Cortex Agent 3 설계. derived 81 metric 배속. | 0~1단계 완료, 2~7 대기 |

> 폴더 위상 요약: `03`(GOLD)·`04`(SILVER)·`05`(SV/Agent)가 **현행 정본 트랙**. `02`는 상위 설계 정본이며 GOLD 상세는 `03`에 위임. `00`·`01`은 원천/레거시 참조용.

---

## 아키텍처 (4계층 메달리온)

```
BRONZE  원천 1:1 적재 (CRM 40테이블 수령 ✅[현재 기준·확장 가능] / GA4·ERP·AGENCY 입고 대기 / GADS·ADMIN 통합 예정·미정)
  ▼  정제 (타입·NULL·코드라벨·중복제거, 행 granularity 유지)
SILVER  GN_DW.SILVER 단일 스키마 (소스 접두사 CRM_*/GA4_*/ERP_*/AGENCY_*; GADS·ADMIN은 통합 결정 후 접두사 확정), 24테이블+α
  ▼  집계·통합 (star schema)
GOLD    12 DIM + 6 FACT (지표 215 → measure 60 + derived 81)
  ▼  의미계층
SERVING Semantic View 4 (MEMBER·SERVICE·AD·GA) + Cortex Agent 3
```

- 계층 규칙: `SERVING → GOLD → SILVER → BRONZE` **단방향 참조**. GOLD의 BRONZE 직접 참조 금지.
- 데이터 현황: **CRM 원천만 전수 수령**, GA4·ERP·AGENCY 미수령 → 관련 객체는 입고 후 설계/활성(의도된 대기).

---

## 핵심 정합 수치
- 지표 **215** = 공통 162 + 신규 53 → measure 60 + dimension 74 + derived 81
- GOLD **18** 물리테이블 = 12 DIM + 6 FACT (base measure 61)
- 데이터 도메인 = CRM·GA4·ERP·AGENCY + **GADS·ADMIN**. 단 GADS·ADMIN은 AGENCY/CRM으로 통합 예정(목적지 미정) → **물리 원천 4~6 가변**. GOLD 귀속(GADS→FAD / ADMIN→FSE)은 통합 경로와 무관하게 확정.
- SILVER **24+α** = CRM 14 + GA4 5 + ERP 2 + AGENCY 3 (CRM은 확장 가능 / GADS·ADMIN은 통합 prefix에 흡수, 수량 S-6 이후 확정)
- SERVING = SV **4** / Agent **3** (derived 81 전수 배속)

---

## 루트 참고 파일
| 파일 | 역할 |
|------|------|
| `BRONZE_CRM 테이블 정보.MD` | 입고팀 회신 CRM 원천 인벤토리(40테이블/882컬럼). `04` SILVER 설계의 BRONZE 측 입력. |
| `GA 커넥터 테스트.md` / `sharepoint 데이터 테스트.sql` / `stagefile_download.md` | 원천 연동·적재 테스트 기록. |
| `OPS.sql` / `TEARDOWN.sql` | 운영·정리 스크립트. |
| `예산 안.md` | 프로젝트 예산 안. |

---

## 읽는 순서 (신규 진입자)
1. 본 문서(전체 조감) → 2. `02_GN_DW_building/README.md`(설계 정본·아키텍처) → 3. `03_top-down_gold/`(GOLD) → 4. `04_silver_design/`(SILVER) → 5. `05_SV-Agent_ai/`(SV·Agent)
   - 배경 이해가 필요하면 `00_PoC_bak/` → `01_project_sample/` 먼저 참조.

## 현재 상태 (요약)
- 설계 트랙: GOLD ✅ / SILVER ✅(문서) / SV·Agent 🔵(1단계까지). 라이브 배포 전.
- 데이터 트랙: BRONZE CRM 수령 완료, GA4·ERP·AGENCY 입고 대기 → 입고 시 SILVER/GOLD/SV 확장.

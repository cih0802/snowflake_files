# 04_silver_design — SILVER 정제 설계

> `04_silver_design/` 폴더의 **진입점(색인)**. 각 파일의 역할·읽는 순서·현재 상태를 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: GOLD star schema 요구와 BRONZE 적재 현황을 잇는 **SILVER 정제 레이어 설계**.
> **★ 정본(작업 기준) = `02_SILVER_작업계획_BRONZE-GOLD연결 20260630.md`** (전체 33객체·4원천·트랙 A~D·S-1~S-7). 물리 구조 정본 = `04_SILVER_DDL_20260702.sql`.

> **설계 2축(top-down)**:
> 1. **GOLD가 요구하는 SILVER** — `03_top-down_gold/08_silver의존.md` (GOLD star schema **24테이블 = 15 DIM + 9 FACT** → SILVER 소스·엔티티 역산)
> 2. **BRONZE에서 구성 가능한 SILVER** — `99_provided_definition/BRONZE_CRM 테이블 정보.MD` (CRM 원천정의 41테이블/876컬럼) · **물리 실측(2026-07-13) `GN_DW.BRONZE_CRM` = 43테이블/927컬럼**(템플릿 2테이블 추가) + 입고 소스
> 위치: `GN_DW.SILVER` 단일 스키마. 테이블명 소스 접두사(`CRM_*`·`GA4_*`·`ERP_*`·`AGENCY_*`)로 구분.
> GADS·ADMIN은 **AGENCY 또는 CRM으로 통합 예정(목적지 미정)** → 독립 접두사 미확정. 변경 정본 = `03_top-down_gold/_archive/GOLD_정의서_업데이트 20260624.md`.

---

## 폴더 간 위상
- **이 폴더 = SILVER 설계** (GOLD 역산 + BRONZE 구성가능성 2축)
- `03_top-down_gold/` — **GOLD 정본**(24테이블). 입력: `08_silver의존.md`·`06_DDL.sql`
- `10_dbt_pipeline/` — **SILVER/GOLD 실제 dbt 구현**(GA4 매크로 등 실행 코드; GA4 샤드 매크로는 대소문자 안전 수정본)
- `02_GN_DW_building`의 PoC 기반 SILVER 23·GOLD View 35는 **본 설계 입력 아님**(제외)

---

## 파일 명세 (번호 순 = 읽는 순서)

| 파일 | 역할 |
|------|------|
| `00_README.md` | (본 문서) 폴더 색인 |
| `01_SILVER_작업계획_축약본 20260630.md` | master 요약 — 빠른 전체 파악 |
| `02_SILVER_작업계획_BRONZE-GOLD연결 20260630.md` | ★ **정본 master** — 33객체·4원천·트랙 A~D·단계 S-1~S-7·§5 선결 Q표 |
| `03_SILVER_작업계획_CRM전용 20260630.md` | master의 **CRM 21객체 실행 슬라이스**(S-1~S-5) |
| `04_SILVER_DDL_20260702.sql` | **물리 구조 정본** — SILVER 26테이블(CRM 21 + GA4 5) CREATE, 타입·PK 소유 |
| `05_SILVER_이슈해결 핸드오버.md` | 선결 Q(P1~P6 진단패턴·Q4~Q15 이슈카드) 대응 노트 |
| `06_GA4_SILVER_샤드통합 설계결정.md` | GA4 date-shard 통합 설계 결정 |
| `07_GA4_파이프라인_dbt로 작업전_주의사항.md` | GA4 dbt 구축 가이드 (**권장**) |
| `08_GA4_파이프라인_SP로 작업전_주의사항.md` | GA4 Stored Procedure 구축 가이드 (대안) |
| `S1_CRM_entity_design_legacy/` | CRM 엔티티 설계서(구버전 15개, 참고용). 상위 참조가 `_archive/SILVER_설계_작업 계획.md`(구 정본)임 |
| `_archive/` | 구 설계(25테이블·GOLD 18=12 DIM+6 FACT)·검토 결과 — 현 설계로 대체됨(보관) |

---

## 설계 요약
- **SILVER 26테이블(즉시 구축 대상) = CRM 21 + GA4 5** — `04_SILVER_DDL_20260702.sql` 완비. ERP·AGENCY·GADS·ADMIN 관련 테이블은 입고 후 추가(master 전체 **33객체**).
- **정제 범위**: 타입 캐스팅 · NULL/빈값 표준화 · 코드→라벨 병행보존 · 중복제거(PK) · **동일 소스 내 JOIN**까지. 집계(GROUP BY)·교차소스 conform 조인은 GOLD.
- **계층 규칙(P2)**: `SERVING → GOLD → SILVER → BRONZE` 단방향. GOLD는 BRONZE 직접 참조 금지.
- **GOLD 24(15 DIM + 9 FACT) 커버**: CRM 21이 DIM 다수 + FACT(FMM·FME·FTG-D·FSE·FEP), GA4 5가 FGA 충족(즉시). **FTG-B·FBD·FAD + DIM_AD_CREATIVE·DIM_BUDGET_ITEM**은 ERP·AGENCY 입고 후(트랙 C/D).

---

## 현재 상태 (2026-07-13 실측)
- SILVER **설계 완료**(정본=02). **SILVER 스키마·테이블은 아직 미생성**(DDL 작성 완료, CREATE 미실행). GOLD 스키마도 미배포.
- BRONZE 적재 실측: **CRM 43테이블(수백만 행)·GA4 `events_20260501` 287,025행·AGENCY 3테이블·ERP `BDGT_ACMSLT_LEDGER` 2,041행 모두 적재됨** → 과거 "CRM만 수령·GA4/ERP/AGENCY 대기" 전제는 **해제**. 트랙 B/C/D 착수 가능.
- GA4 구축은 `10_dbt_pipeline/macros/ga4_union_shards.sql`(대소문자 안전 수정본) 기준. 06/07/08의 예시 매크로는 소문자 샤드 버그 참고용.
- 선결 확인(master §5): R1·R2·R3·R7 + Q1(**user_id 채움률 4.22% → 회원단위 GA 지표 부분 커버리지**)·Q5·Q6.

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `01_축약본`(빠른 파악) → 3. `02_BRONZE-GOLD연결`(정본 상세) → 4. `03_CRM전용`(실행) → 5. `04_DDL`(구조) → (문제 시) `05_핸드오버` → (GA4 트랙) `06_설계결정` → `07_dbt`(권장)/`08_SP`

# 04_silver_design — SILVER 정제 설계

> `04_silver_design/` 폴더의 **진입점(색인)**. 각 파일의 역할·읽는 순서·현재 상태를 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: GOLD star schema 요구와 BRONZE 적재 현황을 잇는 **SILVER 정제 레이어 설계**.
> **★ 정본(작업 기준) = `02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md`** (매핑 인덱스 — 원천별 4개 실행문서 03~06으로 분리). DDL/적재 정본 = `08_SILVER_테이블DDL_20260714.sql` + `09_SILVER_적재쿼리_20260714.sql`.

> **설계 2축(top-down)**:
> 1. **GOLD가 요구하는 SILVER** — `03_top-down_gold/08_silver의존.md` (GOLD star schema **24테이블 = 15 DIM + 9 FACT** → SILVER 소스·엔티티 역산)
> 2. **BRONZE에서 구성 가능한 SILVER** — 물리 실측(2026-07-14): `GN_DW.BRONZE_CRM` 43테이블 · `BRONZE_GA4` 1(287,025행) · `BRONZE_ERP` 1(2,041행) · `BRONZE_AGENCY` 3(235,572행) 모두 입고.
> 위치: `GN_DW.SILVER` 단일 스키마. 테이블명 소스 접두사(`CRM_*`·`GA4_*`·`ERP_*`·`AGENCY_*`)로 구분.

---

## 폴더 간 위상
- **이 폴더 = SILVER 설계** (GOLD 역산 + BRONZE 구성가능성 2축)
- `03_top-down_gold/` — **GOLD 정본**(24테이블). 입력: `08_silver의존.md`·`06_DDL.sql`
- `10_dbt_pipeline/` — **SILVER/GOLD 실제 dbt 구현**(GA4 샤드 매크로는 대소문자 안전 수정본)
- `02_GN_DW_building`의 PoC 기반 산출물은 **본 설계 입력 아님**(제외)

---

## 파일 명세 (번호 순)

| 파일 | 역할 |
|------|------|
| `00_README.md` | (본 문서) 폴더 색인 |
| `02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md` | ★ **정본 = 매핑 인덱스** — 원천→실행문서 매핑·공통원칙·GOLD24 커버리지·교차소스(신원브리지 S-7)·작업단계 |
| `03_SILVER_작업계획_CRM전용 20260714.md` | **CRM 21객체 실행본**(트랙 A · S-1~S-5 완료) |
| `04_SILVER_작업계획_GA4전용 20260714.md` | **GA4 5객체 실행본**(트랙 B) |
| `05_SILVER_작업계획_ERP전용 20260714.md` | **ERP 3객체 실행본**(트랙 C) |
| `06_SILVER_작업계획_AGENCY전용 20260714.md` | **AGENCY 3객체 실행본**(트랙 D · GADS·ADMIN 흡수) |
| `07_GA4_SILVER_샤드통합 설계결정.md` | GA4 date-shard 통합 설계 결정 |
| `08_SILVER_테이블DDL_20260714.sql` | **테이블 정의 정본** — STEP 1~2 CRM 21 + STEP 6 GA4 5 + STEP 7 신원브리지(ERP·AGENCY 포함) CREATE(타입·PK). 실행 1순위 |
| `09_SILVER_적재쿼리_20260714.sql` | **정제 적재 정본** — STEP 3 CRM INSERT + STEP 6 GA4 + STEP 7 브리지(+7-DQ) + **STEP 8 전체 통합검증(DQ-1/2/3)**. 실행 2순위(08 다음) |
| `10_SILVER_이슈해결 핸드오버.md` | 선결 Q(P1~P6 진단패턴·Q4~Q16 이슈카드) 대응 노트 |
| `11_SILVER_블로커_triage_Q1-Q16_20260714.md` | 블로커 질문 Q1~Q16 + 비-Q triage(트랙 게이트) |
| `14_GA4_작업지시 프롬프트_20260714.md` | GA4 트랙 B 작업지시 프롬프트 |
| `22_GA4_파이프라인_dbt로 작업전_주의사항.md` | GA4 dbt 구축 가이드 (**권장**) |
| `23_GA4_파이프라인_SP로 작업전_주의사항.md` | GA4 Stored Procedure 구축 가이드 (대안) |
| `S1_CRM_entity_design_legacy/` | CRM 엔티티 설계서(구버전 15개, 참고용) |
| `_archive/` | 구 설계·검토 결과·구버전(20260630 작업계획, `silver_stepbystep_ddl.sql`, `09_SILVER_DDL_20260702.sql` 등) — 현 문서로 대체됨(보관) |

---

## 설계 요약
- **SILVER 설계 33객체 = CRM 21 + GA4 5 + ERP 3 + AGENCY 3 + 신원브리지 1**(+`DIM_DATE` 생성). **물리 실측(2026-07-14): 32객체 존재·적재** — CRM 21 + GA4 5(PoC 1일샤드) + ERP 2적재+`ERP_BIZ_TARGET` 스키마-only + AGENCY 2(`AGENCY_COST`는 GOLD 이관) + 신원브리지 1. 전기간 GA4 샤드 입고 시 멱등 재적재만 잔여.
- **정제 범위**: 타입 캐스팅 · NULL/빈값 표준화 · 코드→라벨 병행보존 · 중복제거(PK) · **동일 소스 내 JOIN**까지. 집계(GROUP BY)·교차소스 conform 조인은 GOLD.
- **계층 규칙(P2)**: `SERVING → GOLD → SILVER → BRONZE` 단방향. GOLD는 BRONZE 직접 참조 금지.
- **GOLD 24(15 DIM + 9 FACT) 커버**: CRM 유래 15테이블 빌드·적재 가능(S-5 검증완료, G1·G2 해소). 잔여 9(FTG-B·FBD·FAD + DIM_AD_CREATIVE·DIM_BUDGET_ITEM·DIM_GA_*·DIM_DEVICE·FGA)는 GA4·ERP·AGENCY 입고 후(트랙 B/C/D).

---

## 현재 상태 (2026-07-14 갱신)
- **✅ CRM SILVER 트랙 A 완료** — `GN_DW.SILVER` 스키마 생성 + **CRM 21/21 테이블 정제 적재**(멱등 `INSERT OVERWRITE`, 각 행수 = BRONZE 일치). SQL 정본 = `08_SILVER_테이블DDL_20260714.sql` + `09_SILVER_적재쿼리_20260714.sql`. Q4·Q5·Q6·Q13·Q14·Q15·Q16 + 코드그룹(SEX/MBER_DIV/SETLE) 전건 해소 + **S-5 GOLD 역산 검증(G1·G2 해소)** 반영.
- **✅ GA4/ERP/AGENCY SILVER 적재완료** — GA4 5객체 PoC(1일샤드 271,544행·DQ 통과) · ERP 2객체(BUDGET 24,480·BUDGET_ITEM 2,040)+`ERP_BIZ_TARGET` 스키마-only · AGENCY 2객체(AD_PERFORMANCE 235,572·AD_CREATIVE 8,473). 전기간 GA4 샤드 입고(커넥터 소관) 시 멱등 재적재만 잔여.
- **✅ S-7 신원브리지 완료** — `IDENTITY_MEMBER_XREF` 1,348행(GA_MEMBER_ID=MEMBER_DK exact 100%·PK유일·CONFIDENCE HIGH). 09 STEP 7. **★GOLD 소비계약(C1~C4)**: FACT는 LEFT JOIN(익명 95%)·회원차원은 MEMBER_DK DISTINCT + UNMATCHED 제외 → master §6.
- **✅ 전체 SILVER 통합검증 완료** — 09 STEP 8: DQ-1 PK유일성 30객체 dup=0 · DQ-3 fan-out 논리충족 · DQ-2 통합앵커(identity·ERP·결연) orphan 0. ⚠️ `CRM_EVENT_PARTICIPATION` orphan 2건(EVENT_KEY 263,611=ADMIN행사 미입고·MBER_NO 9,480=탈퇴/비CRM) → GOLD `-1 UNKNOWN`+LEFT JOIN 흡수(순서 8 오픈액션). GOLD 스키마 미배포.
- BRONZE 적재 실측: **CRM 43테이블·GA4 `events_20260501` 287,025행·AGENCY 3테이블·ERP `BDGT_ACMSLT_LEDGER` 2,041행 모두 적재됨**. 트랙 B/C/D 착수 가능.
- GA4 구축은 `10_dbt_pipeline/macros/ga4_union_shards.sql`(대소문자 안전 수정본) 기준. 07/22/23의 예시 매크로는 소문자 샤드 버그 참고용.
- 선결 잔여: Q1(GA user_id 채움률 4.22%)·Q2·Q3(캠페인 라벨)·Q8(EVENT 코드체계)·Q9(AGENCY 출처)·Q10(ERP 세세목)·Q11(EHGT)·Q12(미사용컬럼 대조).

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `02_BRONZE-GOLD연결`(정본 매핑 인덱스) → 3. 원천별 실행문서 `03_CRM전용`(완료)·`04_GA4전용`·`05_ERP전용`·`06_AGENCY전용` → 4. `08_테이블DDL`·`09_적재쿼리`(구조·적재 SQL) → (문제 시) `10_이슈해결` → (GA4 트랙) `07_샤드통합 설계결정` → `22_dbt`(권장)/`23_SP`

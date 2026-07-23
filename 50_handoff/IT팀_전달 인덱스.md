# GN_DW IT팀 전달 인덱스 (배포 안내문)

> **목적**: BRONZE·SILVER·GOLD **전 계층을 구축하시는 IT팀**께 전달하는 **설계 문서 묶음 안내**입니다.
> **한 줄**: 분석 모델(GOLD)·정제(SILVER)·입고(BRONZE) 설계가 완료되었습니다. 아래 문서를 통해 **무엇을 적재·정제·생성**하고 **무엇을 회신**해야 하는지 확인하실 수 있습니다.
> **기준 정본**: GOLD = 15 DIM + 9 FACT (`GOLD_ddl 초안.sql`). 데이터 도메인 = CRM·GA4·ERP·AGENCY + GADS·ADMIN (2026-06-24 정의서 반영, GADS·ADMIN은 통합 예정·미정).
> **역할**: IT팀이 **BRONZE·SILVER·GOLD 전 계층 구축 + 변환 프로시저 작성 + BRONZE 컨트랙트 회신**을 담당합니다. SERVING(SV/Agent)·OPS·SECURITY는 본 전달 범위 밖(별도 트랙)입니다.

> **용어 안내** (처음 보시는 분께): **메달리온** = BRONZE(원본)→SILVER(정제)→GOLD(분석용)로 단계별 정제하는 적재 구조 · **DIM(차원)** = 분석 기준(회원·날짜·조직 등) · **FACT(팩트)** = 측정값(금액·건수 등) · **star schema** = FACT를 가운데 두고 DIM이 둘러싼 분석용 구조.

> **✅ IT팀이 하실 일 (요약)**
> 1. **BRONZE 적재** — 원천 데이터를 있는 그대로 적재 + `BRONZE_컨트랙트 요청서`(문서 #1) **3가지 회신**.
> 2. **SILVER 정제** — 정제 규칙대로 테이블 생성 (문서 #3·#4).
> 3. **GOLD 적재** — star schema 24개(15 DIM + 9 FACT) 구축 (문서 #5~#10; #5는 SILVER→GOLD 매핑).
> 4. **변환 SP 작성** — BRONZE→SILVER, SILVER→GOLD 프로시저 (문서 #11 골격 기반).
>
> 착수 전 **§4 체크리스트**(전달 방식·증분 여부·GADS/ADMIN 처리 등)를 먼저 합의해 주시면 진행이 매끄럽습니다.

---

## 1. 전달 문서 — 계층별

| # | 문서 | 계층 | 용도 |
|---|------|------|------|
| 1 | `03_top-down_gold/BRONZE_컨트랙트 요청서.md` | **BRONZE** | **입고 계약서**. ① 데이터 존재 확인 ② 필수 7건 ③ 정의 질문 9건 + 적재 준수사항 5건 + 기간 요건 |
| 2 | `03_top-down_gold/GOLD_정의서_업데이트 20260624.md` | 원천 정의 | 6도메인·전환수 명/건·집행예산 2종 등 **최신 원천 정의**(delta 정본) |
| 3 | `04_silver_design/SILVER_설계_작업 계획.md` | **SILVER** | 정제 정본. 테이블 전수목록·통합트리·개념↔물리명·결정 D1~D11·리스크 R1~R8 |
| 4 | `04_silver_design/S1_CRM_entity_design/` (01~15) | **SILVER** | **CRM 15개 엔티티 상세설계** — 테이블별 grain·PK·컬럼·정제규칙 (정제 SP의 직접 입력) |
| 5 | `03_top-down_gold/GOLD_SILVER 의존.md` | **연결고리** | GOLD 컬럼 ← SILVER 소스 매핑. **SILVER→GOLD 적재 로직의 핵심 근거** |
| 6 | `03_top-down_gold/GOLD_ddl 초안.sql` | **GOLD** | 24테이블 star schema DDL (15 DIM + 9 FACT). 재실행 안전(IF NOT EXISTS) |
| 7 | `03_top-down_gold/GOLD_차원 설계.md` | GOLD | DIM 15개 grain·SK/BK·SCD·컬럼 (DDL 부속 ①) |
| 8 | `03_top-down_gold/GOLD_팩트 설계.md` | GOLD | FACT 9개 grain·measure·가산성 (DDL 부속 ②) |
| 9 | `03_top-down_gold/GOLD_파생지표 매핑.md` | GOLD | derived 81 → 분자/분모 base measure 매핑 (DDL 부속 ③) |
| 10 | `03_top-down_gold/GOLD_메타제약 확인.md` | GOLD | 시간가용성·우선순위·미해결/합의 항목 + META 테이블 제안 |
| 11 | `ETL_프로시저_설계.md` | 프로시저 | BRONZE→SILVER 정제 SP·SILVER→GOLD 적재 SP·DAG 골격 (변환 로직 설계 정본) |

**읽는 순서**: ① BRONZE 컨트랙트 → ② 원천 정의 → ③ SILVER 작업계획 → ④ CRM 엔티티 15종 → ⑤ GOLD↔SILVER 의존 → ⑥ GOLD DDL → ⑦·⑧·⑨ GOLD 설계 3종 → ⑩ 메타제약 → ⑪ 프로시저 설계

> 역할 분담: **IT팀 = BRONZE·SILVER·GOLD 전 계층 구축 + 변환 프로시저 작성**. BRONZE 컨트랙트 회신 3종 필수. SERVING(SV/Agent)은 별도 트랙.

---

## 2. DB(스키마) 6개 구조 — `GN_DW` 단일 DB

| 스키마 | 용도 | 테이블 수 | 본 전달 범위 |
|---|---|---|---|
| BRONZE | 원천 1:1 적재 (가공 없음, 구조 보존) | 원천 6도메인 (CRM 40 ✅ + 5 입고 대기) | ✅ 구축 대상 |
| SILVER | 정제·통합 (타입/NULL/코드라벨/중복제거/JOIN) | 28 (CRM 15 + 입고 후 13; GADS·ADMIN 3 잠정) | ✅ 구축 대상 |
| GOLD | 분석 star schema (집계·통합) | 24 = 15 DIM + 9 FACT | ✅ 구축 대상 |
| SERVING | 의미계층 (Semantic View + Cortex Agent) | SV 4 + Agent 3 | 별도 트랙 |
| OPS | 운영 메타 (비용 리포트·적재 로그) | View 2 + 로그 | 별도 트랙 |
| SECURITY | 거버넌스 정책 (마스킹·네트워크 룰) | 정책 N | 별도 트랙 |

```mermaid
flowchart LR
  B["BRONZE<br/>원천 1:1 (6도메인)"]
  S["SILVER<br/>정제·통합 (25+)"]
  G["GOLD<br/>star schema (24 = 15+9)"]
  V["SERVING<br/>SV 4 / Agent 3 (별도 트랙)"]
  B --> S --> G --> V
```
> 단방향 참조: SERVING → GOLD → SILVER → BRONZE. **본 전달 = BRONZE·SILVER·GOLD 구축**. OPS·SECURITY·SERVING은 별도 트랙(적재 흐름과 무관).

### 2-1. BRONZE 원천 6종 적재 현황

| 원천 | 코드 | 테이블 | 상태 | 비고 |
|------|------|--------|------|------|
| CRM (회원·후원·발송) | `CRM` | **40** (882컬럼) | ✅ 수령·매핑 완료 | 현재 40 기준·확장 가능 / 잔여 정의 확인 3건 |
| GA4 (웹/앱 행동) | `GA4` | 미정 | ⏳ 입고 대기 | 적재 후 확인 |
| ERP (비용) | `ERP` | 미정 | ⏳ 입고 대기 | 모금성 비용(세세목) |
| 대행사 (광고) | `AGENCY` | 미정 | ⏳ 입고 대기 | 광고비·편성비·인입콜 |
| Google Ads | `GADS` | 미정 | ⏳ 보류 | **AGENCY/CRM 통합 예정·목적지 미정** |
| 어드민 | `ADMIN` | 미정 | ⏳ 보류 | 앱푸시·이벤트 / **AGENCY/CRM 통합 예정·미정** |

### 2-2. GOLD 24테이블 (DDL 정본)

```
DIM (15)  DIM_DATE  DIM_ORG  DIM_CAMPAIGN  DIM_MEMBER  DIM_MEMBER_IDENTITY
          DIM_SPONSORSHIP  DIM_AD_CREATIVE  DIM_GA_SOURCE  DIM_SERVICE
          DIM_PAYMENT  DIM_GA_EVENT  DIM_REASON  DIM_BUDGET_ITEM  DIM_DEVICE  DIM_EVENT
FACT (9)  FACT_MEMBER_MONTHLY(FMM)   FACT_MEMBER_EVENT(FME)      FACT_TARGET_DEV(FTG-D)
          FACT_TARGET_BIZ(FTG-B)     FACT_SERVICE_EVENT(FSE)     FACT_EVENT_PARTICIPATION(FEP)
          FACT_GA_BEHAVIOR(FGA)      FACT_AD_PERFORMANCE(FAD)    FACT_BUDGET(FBD)
          → base measure 61
```

---

## 3. IT팀(BRONZE) 회신 요청 (컨트랙트 요약)

| 요청 | 내용 | 위치 |
|------|------|------|
| ① 데이터 존재 확인 | 원천에 데이터가 있는지 `있음/일부/없음` | 컨트랙트 §4 확인란 |
| ② 필수 7건 | 없으면 지표 불가한 항목 확보 가능 여부 | 컨트랙트 §3 표 |
| ③ 정의 질문 9건 | 산출 기준 확정 질문 (일부 현업 확인) | 컨트랙트 §5 |

**적재 준수사항 5건** (컨트랙트 §6): ① 이력 덮어쓰기 금지(변경 시마다 이력 적재) ② 회원 연결키 3종 보존(회원번호·memnum·GA member id) ③ 금액 원본 보존(반올림/가공 전) ④ 발생 순서 식별값 보존(시각·후원사업 순번) ⑤ 발송·참여 시각 보존.

**데이터 기간 요건** (컨트랙트 §7): CRM 개발 1991~, 활동/서비스 2024~, 회비 2021~ / ERP 2025~ / AGENCY 2025~.

---

## 4. 프로시저(변환 로직) 설계 지침

> 변환 SP의 **완성 코드는 본 묶음에 없습니다**. 구조·적재에 능숙한 IT팀이 아래 설계 입력을 근거로 환경에 맞게 작성·조정합니다.
> **상세 골격·패턴·DAG는 `ETL_프로시저_설계.md`(문서 #11) 참조** — 본 절은 그 요약입니다.

**설계 입력 → SP 매핑**
- 정제 규칙: `SILVER_설계_작업 계획.md` + `S1_CRM_entity_design/`(테이블별 grain·PK·정제규칙)
- 변환 매핑: `GOLD_SILVER 의존.md`(GOLD 컬럼 ← SILVER 소스)
- 타깃 DDL: `GOLD_ddl 초안.sql`

**권장 SP 골격(스켈레톤 — IT팀 조정 전제)**
```
SP_LOAD_BRONZE_<SRC>        원천 → BRONZE 1:1 (구조 보존, 가공 금지)
SP_REFINE_<SRC>_<TABLE>     BRONZE → SILVER (타입/NULL/코드라벨/중복제거/동일소스 JOIN)
   └ CRM 15개: S1_CRM_entity_design/ 01~15 와 1:1 대응
SP_LOAD_GOLD_<DIM|FACT>     SILVER → GOLD (의존 매핑 기반 집계·MERGE)
SP_RUN_ALL_REFINEMENT       상위 호출 (원천별 SP 순차/병렬)
```

**실행 순서(DAG)**: `VALIDATE_BRONZE → REFINE(BRONZE→SILVER) → LOAD_GOLD(DIM 먼저 → FACT) → FINALIZER`

**규칙**
- 멱등성: GOLD는 키 기준 **MERGE(UPSERT)**, DDL은 `IF NOT EXISTS` → 재실행 안전
- **DIM 적재가 FACT보다 선행**(FK·SK 무결성). FACT는 SK 조인 후 적재
- 모듈화: 테이블 1개 = SP 1개 → CRM 확장·원천 추가 시 호출 한 줄만 추가

---

## 5. IT팀 전달 체크리스트

- [ ] **전달/적재 방식·형식**: Stage 경로, 포맷(CSV/Parquet), 인코딩(UTF-8), 구분자, 압축
- [ ] **증분 여부**: 최초 전량 적재 vs 이후 증분(CDC) 주기
- [ ] **GADS·ADMIN 처리**: 통합 목적지(AGENCY/CRM) **미정 → 현재 적재 보류**, 결정 후 진행
- [ ] **CRM 확장분**: 신규 CRM 테이블 발생 시 동일 규칙 적용(테이블=SP 1:1)
- [ ] **BRONZE 컨트랙트 회신 3종**(§3): 존재확인 / 필수7 / 정의9
- [ ] **담당자·기한·회신 채널** 명시

---

## 6. 현재 상태

- 설계: BRONZE 컨트랙트 ✅ / SILVER ✅(작업계획 + CRM 15 엔티티) / GOLD ✅(DDL+설계) — 라이브 배포 전.
- 데이터: **CRM만 전수 수령**. GA4·ERP·AGENCY 미수령, GADS·ADMIN 통합 미정 → 입고/결정 후 SILVER·GOLD 활성(S-6).
- 변환 SP: **미작성**(IT팀 작성 대상). §4 설계 입력으로 도출.

> 참고 수치 주의: 레거시 `02_GN_DW_building/02_DB_BRONZE_SILVER.md`의 BRONZE 54 / SILVER 23 / GOLD View 35는 **PoC 기반 구안**이며, 본 인덱스의 BRONZE(6도메인)·SILVER 28(CRM 15 + 입고 후 13, GADS·ADMIN 3 잠정)·GOLD 24(15 DIM+9 FACT)이 **현행 정본**입니다.

<!-- LLM-METADATA
doc_id: GOLD_INDEX
doc_role: folder_index
project: GN_DW (굿네이버스)
canonical_design: 03_테이블 설계.md
method: 01_작업 계획.md
authoritative_source: ../99_provided_definition/   # 현업 제공 원본(정본). 편집 금지(read-only).
structure: 15 DIM + 9 FACT + 9 WIDE VIEW
naming: NN_이름 (작업/읽기 순서)
status: CURRENT — Top-down 1~10단계 완료. 진행상태 정본=01_작업 계획.md
END-METADATA -->

# GN_DW GOLD Top-down 설계 — 폴더 색인

담당 범위: SILVER 정제 → **GOLD 설계 + 소비 계층(WIDE VIEW)** → Semantic View 매핑 → Agent.
파일명 = `NN_이름`. 번호는 작업/읽기 순서. 단계·진행상태 정본은 `01_작업 계획.md`.

## ⚠️ 권위있는 원본 (정본) = `../99_provided_definition/`
현업이 제공한 **원본은 모두 `99_provided_definition/`에 격리**되어 있다. 본 폴더(03)는 그 원본에서 **파생한 설계 산출물**만 둔다. 원본은 read-only — 편집·요약·이동 금지.

| 원본 파일 | 내용 | 원천 |
|---|---|---|
| `01_원천보고서_인벤토리 인덱스.md` | 인벤토리↔설계 연결·표준코드·사용규칙 | — |
| `02_지표사전_공통.md` | 공통 지표 162 (계산식 정본) | 현업 |
| `03_지표사전_신규.md` | 신규 지표 53 (계산식 정본) | 현업 |
| `04_마케팅_보고서필드_인벤토리.md` | 마케팅 보고서 5구분 × 필드 | CRM·ERP·AGENCY·GA4·GADS |
| `05_회원_보고서필드_인벤토리.md` | 회원 보고서 3영역 13보고서 × 필드 | CRM·GA4·CRM_UMS·ADMIN |
| `06_지표용어사전 20260624.md` | 용어 517(공통167·신규50·오버뷰300) | — |
| `09_bronze_crm_ddl.sql` | 확정 BRONZE CRM DDL(타입 정본) | 입고팀 |
| `BRONZE_CRM 테이블 정보.MD` | 수령 CRM 원천 41테이블 | 입고팀 |

## 본 폴더 파일 (번호 순 = 읽는 순서)
| 파일 | 역할 | 상태 |
|---|---|---|
| `00_README.md` | (본 문서) 폴더 색인 | 기준 |
| `01_작업 계획.md` | 방법·설계원칙(P1~P9)·작업단계(1~10)·용어 Glossary | 기준(정본) |
| `02_지표 분류.md` | 215 전수 태깅 → measure 60 / dimension 74 / derived 81 | 1단계 ✅ |
| `03_테이블 설계.md` | ⭐ **설계 정본** — 15 DIM + 9 FACT, 팩트×차원 참조, open 항목 | 2~3단계 ✅ |
| `04_SV파생 매핑.md` | derived 81 → 분자/분모 base + 소속 FACT (SV 입력) | 4단계 ✅ |
| `05_필드 인벤토리.md` | 테이블·컬럼·타입(제안)·키 인벤토리 | 5단계 ✅ draft(타입 확정 전) |
| `06_DDL.sql` | 15 DIM + 9 FACT DDL + 정보성 FK 35 | 6단계 ✅ (compile 검증 완료, **미배포** — 2026-07-13 실측 GN_DW.GOLD 스키마 미생성) |
| `07_메타.md` | 제약 정책·FK 결정·재실행 규칙·미해결 (사람 인수인계용) | 7단계 ✅ |
| `08_silver의존.md` | GOLD 컬럼 → SILVER(26테이블) lineage + 미수령 원천 격리 | 8단계 ✅ |
| `09_빅테이블 VIEW.md` | 소비용 WIDE VIEW 9개 DDL (팩트×참조DIM 평탄화) | 9단계 ✅ (DDL 작성·compile 검증, **미배포**) |
| `10_WIDE VIEW 코멘트.sql` | WIDE VIEW 컬럼 COMMENT (ALTER VIEW, 뷰당 1문) | 10단계 ✅ (스크립트 작성 완료, **미적용** — 배포 후 실행) |
| `30_BRONZE 컨트랙트.md` | 입고팀 전달: 데이터 존재 확인 / 차단 / 정의 질문 | 인계 |
| `32_BRONZE적재 컬럼대조.md` | 확정 BRONZE ↔ GOLD 필요데이터 충족 점검 (누락 없음) | 점검 |
| `99_next_prompt.md` | 다음 세션 인계 | 인계 |
| `_archive/` | 구 설계 산출물(12 DIM+6 FACT 기준) — 현 설계로 대체됨 | 보관 |

## 핵심 수치
- 지표 215 = 공통 162 + 신규 53 / measure 60 + dimension 74 + derived 81
- 코어: **15 DIM + 9 FACT = 24 테이블** (FMM·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD) + 정보성 FK 35
- 소비 계층: **WIDE VIEW 9개**(팩트당 1개, 330컬럼 전수 COMMENT)
- derived는 GOLD 미적재 → Semantic View metric

## 산출물 흐름
`02 분류 → 03 설계 → 04 SV파생매핑 → 05 인벤토리 → 06 DDL(+FK) → 07 메타 → 08 SILVER lineage → 09 WIDE VIEW → 10 VIEW COMMENT`

## 상태
- Top-down 설계 **1~10단계 완료**. 215 지표·overview 필드 전수 귀속(누락 0).
- 물리 배포: ⛔ **미배포(2026-07-13 실측)** — `GN_DW`에 GOLD·SILVER 스키마가 없음(BRONZE_CRM/GA4/ERP/AGENCY·OPS·SECURITY만 존재). `06_DDL.sql`·WIDE VIEW DDL은 **작성 완료이나 실제 CREATE 미실행**. (구 "24테이블 + WIDE VIEW 9개 생성됨" 기술은 실측과 상충 → 정정.) WIDE VIEW 설계(SCD2 dedup·조직 조인·330컬럼 COMMENT)는 유효.
- 잔여: 5·6단계 draft(타입 정밀화 — 정본 `06_지표용어사전` 확정 대기) / open 항목은 `03_테이블 설계.md §5`.
- 다음 트랙: SILVER→GOLD 적재 → (적재 후) WIDE VIEW 검증쿼리 재확인 → Semantic View 매핑.

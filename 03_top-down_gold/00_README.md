<!-- LLM-METADATA
doc_id: GOLD_INDEX
doc_role: folder_index
project: GN_DW (굿네이버스)
canonical_design: 03_테이블 설계.md
method: 01_작업 계획.md
authoritative_source: ../99_provided_definition/   # 현업 제공 원본(정본). 편집 금지(read-only).
structure: 17 DIM + 14 FACT (테이블 31) + GOLD 뷰 16 (WIDE 14 + dim 뷰 2)
naming: NN_이름 (작업/읽기 순서)
status: CURRENT — Top-down 1~10단계 완료. 🔴 **실측(2026-08-07) = 3차 재구축 직후 상태: GOLD 31T·SILVER 39T 생성 · 전 테이블 0행 · GOLD 뷰 0개**(=`dbt build` 미실행). 진행상태 정본=01_작업 계획.md
END-METADATA -->

# GN_DW GOLD Top-down 설계 — 폴더 색인

담당 범위: SILVER 정제 → **GOLD 설계 + 소비 계층(WIDE VIEW)** → Semantic View 매핑 → Agent.
파일명 = `NN_이름`. 번호는 작업/읽기 순서. 단계·진행상태 정본은 `01_작업 계획.md`.

## 🔴 [2026-08-07 O50] 객체 구조 소유주 규칙 (먼저 읽을 것)

트리거 = *"테이블은 DDL 로 뼈대를 만들고 dbt 가 채우는데 view 는 dbt 가 만든다. view 도 DDL 로 만드는 게 운영 거버넌스에 좋은가?"*
**답 = 아니다.** 거버넌스 이득은 「DDL 에 있음」이 아니라 **「소유주가 1개 + 게이트가 있음」** 에서 나온다.

| 객체 | 구조 소유주 | 근거 |
|---|---|---|
| GOLD 테이블 **31** (17 DIM + 14 FACT) | `06_DDL.sql` | CTAS 가 타입·COMMENT·FK 를 파괴(순서9 G-1/G-2 = fact FK 23개 드롭) → `+full_refresh:false` 로 물리 보호 |
| **GOLD 뷰 16** (WIDE 14 + dim 뷰 2) | **dbt** (`10_dbt_pipeline/models/gold/{wide,dim}/`) | 뷰는 보호할 물리 상태가 없다(멱등·저장 0). 대신 **의존성**이 있어 `ref()` 위상정렬·리니지·build 게이트가 필요(BLOCKING-4) |
| SILVER 테이블 39 | `../04_silver_design/08_SILVER_테이블DDL_*.sql` | 위 테이블과 동일 근거 |
| SERVING 일반 뷰 3 (helper) | 🔴 **소유주가 둘로 쪼개져 있다** — `DIM_MONTH`·`DIM_MEMBER_CURRENT` = `../02_GN_DW_building/08_After_Deploy_DBT.sql` **§G.1/§G.2** · `FACT_AD_COMBINED` = `../05_SV-Agent_ai/05_7_SV_DDL_AD.sql:57` (SV DDL 파일 **내부**) | 노출·SV 계약 경계 → 파이프라인 실행과 무관하게 존재해야 함. dbt 모델 없음(grep 확인) |

- 🔴 **[2026-08-07 O51 재정정] 뷰 COMMENT 정본 = `10_dbt_pipeline/models/gold/wide/_wide_schema.yml`**
  (`description` = 뷰 COMMENT · `columns[].description` = 컬럼 COMMENT) · 적용 = `materialized='gn_view_commented'`.
  ⚠️ **O50 에서 적었던 "post_hook 16/16 = 정본" 은 틀렸다** — 파일에 문장이 있는지만 세고 **효과를 확인하지 않았다**
  (**P33 위반**: 완료 판정은 `INFORMATION_SCHEMA` 스캔이다). 실측 GOLD 뷰 **520컬럼 중 COMMENT 0개(0.0%)** ·
  같은 시점 GOLD 테이블은 **535/535(100%)**. 원인 = `ALTER VIEW ... ALTER COLUMN ... COMMENT` 가
  **Snowflake 에 없는 문법**(4변형 전부 실패) → 15/16 뷰 build ERROR. `09`(12) · `10`(13) · post_hook(16)
  **세 사본이 모두 물리에 0 을 반영**했으므로 사본 개수 비교 자체가 무의미한 지표였다.
  ⇒ 뷰 컬럼 COMMENT 의 **유일 경로 = `CREATE VIEW` 인라인 컬럼목록**. probe(`WIDE_TARGET_DEV`) **10/10 물리 반영 확인**.
  `09`·`10` 의 참고본 강등은 유지(사유만 변경 — "뒤처졌다"가 아니라 "메커니즘이 애초에 작동하지 않았다").
- **GRANT 소실 우려는 해당 없음**: `07_ENVIRONMENT_RBAC_setup.sql` D.2 가 GOLD 에
  `GRANT SELECT ON FUTURE VIEWS`(ENGINEER·ANALYST·VIEWER·SERVICE)를 걸어 두어 `CREATE OR REPLACE VIEW`
  재생성분에 자동 적용된다. ⚠️ 이 FUTURE grant 는 **아키텍처의 전제**이므로 제거 금지.
- ⚠️ `05_SV-Agent_ai/02_SERVING_setup.sql` 은 **스텁(실행 라인 0)** 이다 — SERVING 뷰 소유주가 아니다(O36 ③ 기교정).
- 🟢 **[O50-C 해소] SV base 객체 선택 규칙 = DEC-34** — 정본 `../05_SV-Agent_ai/04_SV_설계.md` **§0.8**.
  **①** GOLD base FACT 직접(기본값·DDL·6 SV) → **②** SERVING helper 뷰(팩트 재구성 **없이** SV 엔진 제약만 우회·DDL·`SV_AD`)
  → **③** dbt 소유 GOLD 뷰(**팩트를 재구성**: 팩트↔팩트 조인·사전집계·행 단위 상호 스코프 → `ref()` 위상정렬 필수·`SV_DEV_ACHIEVEMENT`).
  **②/③ 경계 = 「팩트를 재구성하는가」.**
  ⚠️ ③ 선택의 대가 = 그 SV 는 `dbt build` 없이 **배포 불가**. 실증: 실측(2026-08-07) SERVING semantic view **7개**이고
  없는 2개가 정확히 ③ 계열(`SV_DEV_ACHIEVEMENT`·`SV_MEMBER_FEE`)이다 — DDL 계열 7 은 GOLD 0행에서도 생성됐다.
  🟠 `SV_MEMBER_FEE` 만 ②로 내릴 여지가 있으나 **판단 보류**(GOLD 0행 → `FACT_MEMBER_COHORT.MEMBER_DK` 유일성 실측 불가 · 트리거 §0.8-C).
- 게이트: `10_dbt_pipeline/tests/warn_gold_view_comment_coverage.sql`(warn → 첫 clean build 후 error 승격).

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
| `03_테이블 설계.md` | ⭐ **설계 정본** — 15 DIM + 12 FACT, 팩트×차원 참조, DEC-1~13, open 항목 | 2~3단계 ✅ |
| `04_SV파생 매핑.md` | derived 81 → 분자/분모 base + 소속 FACT (SV 입력) | 4단계 ✅ |
| `05_필드 인벤토리.md` | 테이블·컬럼·타입(제안)·키 인벤토리 | 5단계 ✅ draft(타입 확정 전) |
| `06_DDL.sql` | 15 DIM + 12 FACT DDL + 정보성 FK 38 | 6단계 ✅ (**배포·적재 완료** · 2026-07-28 광고 위성 3종 증설 · 2026-07-29 실측 대조 일치) |
| `07_메타.md` | 제약 정책·FK 결정·재실행 규칙·미해결 (사람 인수인계용) | 7단계 ✅ |
| `08_silver의존.md` | GOLD 컬럼 → SILVER(38테이블) lineage + 원천 갭 이력 | 8단계 ✅ |
| `09_빅테이블 VIEW.md` | WIDE VIEW 평탄화 **설계 참고본**(12/16 수록) | 9단계 ✅ · 🔴 **[O50] 비실행 강등** — 물리 정본 = dbt 모델 |
| `10_WIDE VIEW 코멘트.sql` | WIDE VIEW 컬럼 COMMENT **문안 참고본**(13/16) | 10단계 ✅ · 🔴 **[O50] 비실행 강등** — 물리 정본 = 모델 post_hook |
| `11_BRONZE적재 컬럼대조.md` | 확정 BRONZE ↔ GOLD 필요데이터 충족 점검 (누락 없음) | 점검 |
| `99_next_prompt.md` | 다음 세션 인계 | 인계 |
| `_archive/` | 구 설계 산출물(12 DIM+6 FACT 기준)·구 working 문서(BRONZE 컨트랙트·오픈액션·컬럼매핑 등) — 현 설계로 대체됨. **참조하지 말 것** | 보관 |

## 핵심 수치
- 지표 215 = 공통 162 + 신규 53 / measure 60 + dimension 74 + derived 81
- 코어: **17 DIM + 14 FACT = 31 테이블** (FMM·FMF·FMC·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD + 광고 위성 FAD_B·FAD_D·FAD_BC) + 정보성 FK 38
- 소비 계층: **GOLD 뷰 14** = WIDE 14 (`WIDE_AD_COMBINED` 신설 포함). 🔴 [2026-08-10 O53] 종전 「16 = WIDE 14 + dim 뷰 2」에서 갱신 — dim 뷰 2종(`DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION`)과 `WIDE_DEV_ACHIEVEMENT` 는 **테이블로 전환**됐고 `WIDE_AD_COMBINED` 가 신설됐다. 기반 계층 = **GOLD 테이블 35**(DIM 20 + FACT 15).
- derived는 GOLD 미적재 → Semantic View metric

## 산출물 흐름
`02 분류 → 03 설계 → 04 SV파생매핑 → 05 인벤토리 → 06 DDL(+FK) → 07 메타 → 08 SILVER lineage → 09 WIDE VIEW → 10 VIEW COMMENT`

## 상태
- Top-down 설계 **1~10단계 완료** + **배포·적재 완료(2026-07-20)**. 215 지표·overview 필드 전수 귀속(누락 0).
- 🔴 물리 배포: **[2026-08-07 O50 실측 정정] 「완료」가 아니다 — 3차 재구축 직후 DDL-only 상태다.**
  `GN_DW.INFORMATION_SCHEMA` 실측: `GOLD` **31테이블 / 뷰 0개 / 전 테이블 0행** · `SILVER` **39테이블 / 0행** ·
  `SERVING` 뷰 3(DDL 소유라 재구축을 넘어 생존). ⇒ **`dbt build` 미실행**. 소비 계층(GOLD 뷰 16)은 아직 존재하지 않는다.
  ⚠️ 종전 기재 *"✅ 완료 — 실측(2026-07-29) 27테이블 + WIDE VIEW 12개 · SILVER 38테이블 · FMM 40.05M…"* 은
  **재구축 이전 스냅샷**이었다(O43·P62-B 유형 = 생성기·문서가 스키마 변경을 따라오지 않음).
  기존 적재 실측치(FMM 40,054,883 · FMF 40,262,076 · FSE 38,470,780 · FME 4.63M · FEP 1.13M ·
  FAD 235,572 + 위성 FAD_D 197,686 · FAD_B 37,886 · FAD_BC 5,327 · `FACT_TARGET_BIZ` 0행=E-6)는
  **직전 빌드의 기대값(회귀 대조 기준)** 으로만 유효하다 — 현재 상태가 아니다.
- 잔여: 타입 정밀화(정본 `06_지표용어사전` 확정 대기) / 사업목표(`CRM_BIZ_TARGET`) 데이터 입고 / open 항목은 `03_테이블 설계.md §5`.
- GA4: `events_20260501` 1일 샤드(추가 입고 예정 없음)를 **전체로 간주**하고 적재·검증 완료. 추후 추가 입고 시 GA4 SILVER/GOLD 재적재·재검증 재작업 예정.
- 다음 트랙: Semantic View 매핑(derived 81 → metric).

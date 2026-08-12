<!-- LLM-METADATA
doc_id: GOLD_INDEX
doc_role: folder_index
project: GN_DW (굿네이버스)
canonical_design: 03_테이블 설계.md
method: 01_작업 계획.md
authoritative_source: ../99_provided_definition/   # 현업 제공 원본(정본). 편집 금지(read-only).
structure: 20 DIM + 15 FACT (테이블 35) + GOLD 뷰 14 (전부 WIDE_*)   # [2026-08-12 O64 실측 정정] 종전 「31 + 뷰 16(WIDE 14 + dim 뷰 2)」은 stale
naming: NN_이름 (작업/읽기 순서)
status: CURRENT — Top-down 1~10단계 완료. 🟢 **실측(2026-08-12 O64 · 계정 os09358)**: GOLD **35테이블(34 적재 · 139,962,567행) + 뷰 14** · SILVER **39테이블(38 적재 · 112,108,648행)** ⇒ `dbt build` 실행 완료 상태다. 빈 2개는 `GOLD.FACT_TARGET_BIZ`·`SILVER.CRM_BIZ_TARGET` = 기지 **E-6**(사업목표 원천 미입고)뿐이다. ⚠️ 종전 기재 「3차 재구축 직후 · GOLD 31T · 전 테이블 0행 · 뷰 0개」는 **2026-08-07 시점 스냅샷**이며 현재 상태가 아니다(`P169`). 진행상태 정본=01_작업 계획.md
END-METADATA -->

# GN_DW GOLD Top-down 설계 — 폴더 색인

담당 범위: SILVER 정제 → **GOLD 설계 + 소비 계층(WIDE VIEW)** → Semantic View 매핑 → Agent.
파일명 = `NN_이름`. 번호는 작업/읽기 순서. 단계·진행상태 정본은 `01_작업 계획.md`.

## 🔴 [2026-08-07 O50] 객체 구조 소유주 규칙 (먼저 읽을 것)

트리거 = *"테이블은 DDL 로 뼈대를 만들고 dbt 가 채우는데 view 는 dbt 가 만든다. view 도 DDL 로 만드는 게 운영 거버넌스에 좋은가?"*
**답 = 아니다.** 거버넌스 이득은 「DDL 에 있음」이 아니라 **「소유주가 1개 + 게이트가 있음」** 에서 나온다.

| 객체 | 구조 소유주 | 근거 |
|---|---|---|
| GOLD 테이블 **35** (20 DIM + 15 FACT) | `06_DDL.sql` | CTAS 가 타입·COMMENT·FK 를 파괴(순서9 G-1/G-2 = fact FK 23개 드롭) → `+full_refresh:false` 로 물리 보호 |
| **GOLD 뷰 14** (전부 `WIDE_*`) | **dbt** (`10_dbt_pipeline/models/gold/wide/`) | 뷰는 보호할 물리 상태가 없다(멱등·저장 0). 대신 **의존성**이 있어 `ref()` 위상정렬·리니지·build 게이트가 필요(BLOCKING-4) |
| SILVER 테이블 39 | `../04_silver_design/08_SILVER_테이블DDL_*.sql` | 위 테이블과 동일 근거 |
| SERVING 일반 뷰 **0** | 🔴 **[2026-08-12 O64 실측] helper 3종은 전부 GOLD 로 이관돼 SERVING 에는 일반 뷰가 없다** — `SERVING` 의 `INFORMATION_SCHEMA.TABLES` **0행**(semantic view 9종만 존재하고 SV 는 TABLES 에 안 나온다) | `DIM_MONTH`·`DIM_MEMBER_CURRENT` → **GOLD BASE TABLE**(dbt `models/gold/dim/`) · `FACT_AD_COMBINED` → **`GOLD.WIDE_AD_COMBINED` VIEW**(dbt `models/gold/wide/` · `SV_AD` 의 base). ⚠️ 종전 「SERVING 뷰 3 · 소유주 2분할(`08_After_Deploy_DBT.sql` §G.1/§G.2 · `05_7_SV_DDL_AD.sql:57`)」은 **역사 기록**이다 |

🔴 **[2026-08-12 O64] 위 표는 종전에 「테이블 31(17 DIM+14 FACT)」·「뷰 16(WIDE 14 + dim 뷰 2)」로 적혀 있었다** —
같은 문서 §핵심 수치(아래)는 이미 O53 에서 **35 / 14** 로 갱신돼 있었으므로 **한 문서 안에서 두 기재가 서로 어긋난 상태**였다.
「dim 뷰 2」의 유래 = `DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION` 이 뷰였다가 테이블로 전환된 것이고, 표가 따라오지 않았다.

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
  **①** GOLD base FACT 직접(기본값·DDL 소유) → **②** SERVING helper 뷰(팩트 재구성 **없이** SV 엔진 제약만 우회·DDL 소유)
  → **③** dbt 소유 GOLD 뷰(**팩트를 재구성**: 팩트↔팩트 조인·사전집계·행 단위 상호 스코프 → `ref()` 위상정렬 필수).
  **②/③ 경계 = 「팩트를 재구성하는가」.**
  ⚠️ ③ 선택의 대가 = 그 SV 는 `dbt build` 없이 **배포 불가**.
  🔴 **[2026-08-12 O64 실측] 계열별 SV 예시를 여기서 인용하지 말 것 — 종전 기재가 지금은 어긋난다.**
  실측(`DESCRIBE SEMANTIC VIEW` 의 `BASE_TABLE_NAME` × `TABLE_TYPE` · COMMENT 문안이 아니라 정의로 판정 `R2-3`) SV **9종**:
  base 가 전부 BASE TABLE = **7종**(`SV_BUDGET`·`SV_EVENT_PARTICIPATION`·`SV_MEMBER_COHORT`·`SV_MEMBER_EVENT`·`SV_MEMBER_MONTHLY`·`SV_SERVICE`·**`SV_DEV_ACHIEVEMENT`**) ·
  base 에 GOLD 뷰 포함 = **2종**(`SV_AD`→`WIDE_AD_COMBINED` · `SV_MEMBER_FEE`→`WIDE_MEMBER_FEE`).
  ⇒ 종전 「① 6 SV」는 실측 **7**, 「② = `SV_AD`」·「③ = `SV_DEV_ACHIEVEMENT`」는 **서로 반대**가 됐고, ② 는 SERVING helper 뷰가 0 이라 구현체가 없다.
  ⚠️ **계열 재분류는 설계 결정이라 여기서 하지 않는다** — 정본은 §0.8 이고 판단은 **미결 등재**(원장 §O64)다.
  확정된 실무 영향 = ③ 의 대가(build 없이 배포 불가)가 이제 **`SV_AD` 에도 걸린다**.
  ⚠️ 과거 기재(2026-08-07 시점): SERVING semantic view 7개 · 없는 2개 = `SV_DEV_ACHIEVEMENT`·`SV_MEMBER_FEE` · DDL 계열 7 은 GOLD 0행에서도 생성됐다 ·
  「`SV_MEMBER_FEE` 만 ②로 내릴 여지 · 판단 보류(트리거 §0.8-C)」는 ② 에 구현체가 없어져 **성립하지 않는다**.
- 게이트: `10_dbt_pipeline/tests/warn_gold_view_comment_coverage.sql` — **`severity=warn` 유지**(2026-08-10 O51-F 사용자 결정 · `P130`).
  🔴 **[2026-08-12 O64] 종전 이 자리의 「warn → 첫 clean build 후 error 승격」은 O53 이 이미 철회한 지시였다** —
  게이트 파일 헤더는 O53 에서 교정됐는데 이 줄과 `dbt_project.yml` 두 곳이 안 따라와, 이 줄만 읽은 세션은 **철회된 지시를 실행할 수 있었다**.
  승격은 **사용자가 명시 지시할 때만** 한다(원천 증량 시 새 뷰·컬럼이 build 전체를 세운다).

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
- 코어: **20 DIM + 15 FACT = 35 테이블** (FMM·FMF·FMC·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD + 광고 위성 FAD_B·FAD_D·FAD_BC + **`FACT_DEV_ACHIEVEMENT`**) + 정보성 FK 38
  🔴 [2026-08-12 O64] 종전 「17 DIM + 14 FACT = 31」은 stale 이었다 — 같은 절 다음 줄이 이미 O53 에서 **35(DIM 20 + FACT 15)** 로 갱신돼 있었다(문서 내 자기모순).
- 소비 계층: **GOLD 뷰 14** = WIDE 14 (`WIDE_AD_COMBINED` 신설 포함). 🔴 [2026-08-10 O53] 종전 「16 = WIDE 14 + dim 뷰 2」에서 갱신 — dim 뷰 2종(`DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION`)과 `WIDE_DEV_ACHIEVEMENT` 는 **테이블로 전환**됐고 `WIDE_AD_COMBINED` 가 신설됐다. 기반 계층 = **GOLD 테이블 35**(DIM 20 + FACT 15).
- derived는 GOLD 미적재 → Semantic View metric

## 산출물 흐름
`02 분류 → 03 설계 → 04 SV파생매핑 → 05 인벤토리 → 06 DDL(+FK) → 07 메타 → 08 SILVER lineage → 09 WIDE VIEW → 10 VIEW COMMENT`

## 상태
- Top-down 설계 **1~10단계 완료** + **배포·적재 완료(2026-07-20)**. 215 지표·overview 필드 전수 귀속(누락 0).
- 🟢 물리 배포: **[2026-08-12 O64 실측 · 계정 `os09358`] 적재까지 완료 상태다.**
  `GN_DW.INFORMATION_SCHEMA` 실측: `GOLD` **35테이블(34 적재 · 139,962,567행) + 뷰 14** ·
  `SILVER` **39테이블(38 적재 · 112,108,648행)** · `SERVING` 일반 뷰 **0** + semantic view **9**.
  빈 테이블은 `GOLD.FACT_TARGET_BIZ`·`SILVER.CRM_BIZ_TARGET` **2개뿐**이며 기지 **E-6**(사업목표 원천 미입고)이다.
  ⚠️ **[O50 시점 기재 무효]** 「3차 재구축 직후 DDL-only · GOLD 31테이블 / 뷰 0개 / 전 테이블 0행 · `dbt build` 미실행」은
  **2026-08-07 스냅샷**이다. 그 뒤 O51~O63 에서 build·적재가 이뤄졌고 O63 이 뷰 COMMENT까지 반영했다.
  ⚠️ 그보다 앞선 「✅ 완료 — 실측(2026-07-29) 27테이블 + WIDE VIEW 12개 · SILVER 38테이블」도 그 시점 스냅샷이다(`P169`).
  아래 수치는 **직전 빌드 기대값(회귀 대조 기준)** 으로만 쓴다 — 현재값은 위 실측을 보라:
  FMM 40,054,883 · FMF 40,262,076 · FSE 38,470,780 · FME 4.63M · FEP 1.13M ·
  FAD 235,572 + 위성 FAD_D 197,686 · FAD_B 37,886 · FAD_BC 5,327 · `FACT_TARGET_BIZ` 0행=E-6.
- 잔여: 타입 정밀화(정본 `06_지표용어사전` 확정 대기) / 사업목표(`CRM_BIZ_TARGET`) 데이터 입고 / open 항목은 `03_테이블 설계.md §5`.
- GA4: `events_20260501` 1일 샤드(추가 입고 예정 없음)를 **전체로 간주**하고 적재·검증 완료. 추후 추가 입고 시 GA4 SILVER/GOLD 재적재·재검증 재작업 예정.
- 다음 트랙: Semantic View 매핑(derived 81 → metric).

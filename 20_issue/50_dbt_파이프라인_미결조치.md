<!-- LLM-METADATA
doc_id: ISSUE_50_DBT_OPEN_ITEMS
doc_role: dbt 파이프라인 미결 후속조치 — BLOCKING·결정대기·배포·DONE (실행/운영)
project: GN_DW (굿네이버스)
created: 2026-07-15
index: 20_issue/00_INDEX_이슈원장.md
priority: HIGH — 후속 세션 착수 시 먼저 확인
END-METADATA -->

# 50. dbt 파이프라인 미결 후속조치 (업무단계: 실행/운영)

> ⛔ **후속 세션은 이 문서를 먼저 읽고 시작.** 순서 9-B 검토에서 발견·보류된 파이프라인 미결을 모음. 완료 시 `[DONE]` 표기 후 `DEPLOY_RUNBOOK.md` 이관.
> 현업 판정이 필요한 데이터 이슈(A~E)는 문서20, 외부 입고는 문서40.
> 전체 인덱스: `00_INDEX_이슈원장.md`

---

## 🔴 BLOCKING-1 — `severity: warn` 되돌리기 (회원 마스터 전량입고 후)
회원 마스터(`CRM_MEMBER`) 스냅샷 미완전 고아 때문에 참조무결성 테스트를 **임시 `warn` 강등**. 마스터 전량입고 시 **전부 `error` 복귀** 필요(무결성 게이트 복원).

| 파일 | 대상 테스트 | 건수 | 현재 |
|---|---|--:|---|
| `models/gold/_gold_ready_schema.yml` | FMM·FEP·FME·FSE 의 `MEMBER_DK→DIM_MEMBER` | 4 | warn |
| `models/silver/crm/_crm_schema.yml` | `MBER_NO/MEMBER_DK→CRM_MEMBER`(EVENT_PARTICIPATION·MEMBER_DEV·DISCONTINUE·AMT_CHANGE·RESPONSOR·STATUS_HIST·PAYMENT_BILLING·PAYMENT_METHOD·SEND_MEMBER·SPONSOR_RELATION) | 10 | warn |
| `models/silver/_silver_bridge_schema.yml` | `IDENTITY_MEMBER_XREF.MEMBER_DK→CRM_MEMBER` | 1 | warn |
| `models/silver/ga4/_ga4_schema.yml` | `GA4_IDENTITY.MBER_NO→CRM_MEMBER`(모델 disabled) | 1 | warn |

- **복귀 조건**: 현업이 "회원 마스터 추출 범위/시점 문제" 확인·수정 → 고아 해소 후(문서20-B·문서40 §3).
- **검증**: `dbt build --select path:models/silver path:models/gold` → ERROR=0 확인.

## 🔴 BLOCKING-2 — 현업 판정 대기 (데이터 이슈 A~E)
파이프라인이 무효/의심 처리했으나 **현업 회신 전 확정 불가**. 회신 오면 로직 반영. **상세 질문·규모는 문서20 §C.**

| # | 항목 | 현재 처리 | 회신 후 조치 |
|---|---|---|---|
| A | `MONTH_KEY` 비-YYYYMM(~2,043행) | 무효→납입월/0 라우팅 | 유효 판정 시 클램프 완화 |
| B | 회원번호 마스터 부재 9,248명+불량ID+NULL 750 | warn(보존) | 마스터 재추출 or 불량 폐기 |
| C | 캘린더 범위밖 날짜(~140행) | DATE_SK=0 | 유효 시 캘린더 확장 |
| D | 원천 값 전무 컬럼(5종) | NULL | 추출보완 or 정상NULL 확정 |
| **E** | **`EVENT_KEY→CRM_EVENT` 고아 263,611(참여 23%)** + `SNDNG_KEY` 11,313+9 | **warn 관측(순서9-C)** | 원인규명(마스터 누락 vs 키체계) 후 error 복귀 |

> ⚠️ **[순서9-C 개정]** 메달리온 베스트 프랙티스(Silver 참조무결성 = 알려진 원천 미완전이면 warn 관측, error 는 구조 불변식만)에 따라 **E 및 참조무결성 9건을 `severity:warn` 강등** → **full `dbt build` 는 이제 green**(ERROR=0). 마스터 전량입고·키체계 확정 시 `_crm_schema.yml`의 순서9-C warn 을 error 로 복귀. 대상 목록·복귀조건은 해당 yml 주석 참조.

## 🔴→🟡 BLOCKING-5 — GOLD 팩트 measure·차원FK 대규모 미적재 (SV/Agent 착수 시 실측 발견 2026-07-21 · A1/A3 부분해소 진행중)
> SV 설계(05_SV-Agent_ai 2단계) 중 **배포된 GOLD 실데이터**를 컬럼별 실측(`COUNT_IF`)한 결과, 행수는 있으나 **대부분의 카운트 measure·차원 FK가 전건 0/NULL**. 기존 Item D("원천 값 전무 5종")·D1(스캐폴드)·E(고아)의 범위를 **초과**하는 미적재. Cortex Analyst SV가 이 위에 서면 0/오답을 자신 있게 반환 → **배포 전 원인규명 필수**.
> 🟡 **[2026-07-21 진행] A1·A3 착수** — 입고된 SILVER 데이터로 채울 수 있는 것부터 구현(아래 §BLOCKING-5 진행분).

| FACT | ✅ 적재(활성 가능) | ❌ 전건 0/NULL (미적재) |
|---|---|---|
| FMM 37.8M→40.05M | PAID_FEE(36.09M)·BILLED_AMT·UNPAID_FLAG_BOM/EOM · ✅**DEV/STOP 건·명(A1: FME 롤업)** · ✅**HAS_BILLING(A1 출처플래그)** | UNPAID/ACTIVE/CUM/MONTH_END/YEAR_*·INCREASE 건·명·CAMPAIGN_UNPAID·STATUS_UNPAID·INBOUND/TS_CALL·REGULAR_FEE·SPONSOR/PAID_MONTHS·DEV_TYPE·밴드·JOIN_DATE·NEW_FLAG·NEW_EXISTING_FLAG·**CAMPAIGN/PAYMENT/SPONSORSHIP/REASON_SK** |
| FME 4.6M | DEV_CNT/MEMBERS·JOIN_DATE(3.59M)·STOP_CNT/MEMBERS/STOP_DATE(1.04M) | UNPAID_STOP·**ORG_SK·CAMPAIGN_SK·SPONSORSHIP_SK·REASON_SK·NEW_EXISTING_FLAG** |
| FSE 38.5M | SEND_MEMBERS(전행)·SEND_STATUS(35.75M) · ✅**SERVICE_SK(A3: 요청마스터 조인, 99.97%)** · ✅**SEND_TITLE(A3)** | SUCCESS/FAIL/OPEN/LETTER/GIFT·**D5_\*(증액·서신·선물·중단)**·**CAMPAIGN_SK**(원천 캠페인 컬럼 부재) |
| FEP 1.1M | MEMBER_DK·PARTICIPANT_CNT·EVENT_SK(76.8%) | TOTAL/RECRUIT_CNT·CAMPAIGN_SK·SPONSORSHIP_SK |
| FBD 24.5K | BUDGET_ITEM_SK(전행)·PLAN_BUDGET_MONTH(7,290)·EXEC_BUDGET_ERP(3,244) | PLAN_BUDGET_YEAR·FUNDRAISING_COST·AD_COST·CAMPAIGN_SK·ORG_SK |

- **영향**: 캠페인별/조직별/서비스구분별/납입방식별/신규기존별 지표, 활동·개발·중단 카운트 비율, 목표대비(공1~3), 서비스 수신/참여/증액/코호트(신31~53) = **전부 계산 불가**. Phase-1 실활성 = 납부율·미납회원감소·납입/청구/예산(세세목)·개발/중단 총건·유지기간·발송수·참여자수뿐.
- **원인 후보(규명 필요)**: ① dbt gold.fact 모델이 해당 measure/FK 매핑 미구현(스캐폴드 컬럼 잔존) ② SILVER 원천 컬럼 공란(=Item D 확장) ③ FK 조인 미결선(전건 센티넬 0). → **GOLD/ETL 담당 확인**: 의도된 NULL인가 vs 적재 로직 누락인가.
  - 🟡 **[2026-07-21 규명 결과]**: 원인은 대부분 **①(스캐폴드 컬럼 잔존, 로직 미구현)** — SILVER 원천은 입고돼 있음(FME dev/stop·CRM_SEND_REQUEST 등). 입고 대기(②/외부)는 소수(INBOUND/TS_CALL=C-8·FTG_BIZ=E-6·D5 코호트·FSE CAMPAIGN_SK[원천 캠페인 컬럼 부재]).
- **조치**: (a) 좁은 Phase-1 SV는 실적재 컬럼만으로 배포(진행), (b) 본 항목 원인규명 후 measure/FK 적재 → SV metric 순차 활성(구조 DDL 불변). 
- **검증 재현**: `SELECT COUNT_IF(<col><>0) FROM GN_DW.GOLD.<fact>` (상세 매트릭스 = `05_SV-Agent_ai/04_SV_설계.md §0.6`).

### 🟡 [2026-07-21 진행분] BLOCKING-5 A-계열 착수 (입고 데이터로 구현 가능분)
> "할 수 있는 것만" 원칙: 입고된 SILVER 데이터로 결정·외부의존 없이 채울 수 있는 항목을 우선 구현. build 는 사용자 실행.
- ✅ **A3 — FSE SERVICE_SK·SEND_TITLE** (`models/gold/fact/FACT_SERVICE_EVENT.sql`): `CRM_SEND_MEMBER × CRM_SEND_REQUEST`(SNDNG_KEY, unique) 조인 → `SERVICE_SK = gold_sk([SEND_CHANNEL, SNDNG_TY_CD])`(DIM_SERVICE 동일 산식)·`SEND_TITLE=TIT`. **시뮬 검증: 커버 99.97%(38.46M/38.47M)·DIM_SERVICE 미매칭 SK=0건**. 미매칭 → SERVICE_SK=0(Unknown).
- ✅ **A1 — FMM DEV/STOP 건·명 + HAS_BILLING** (`models/gold/fact/FACT_MEMBER_MONTHLY.sql` + `06_DDL.sql`): 스파인 = 회비(billing) ∪ 개발/중단(FME 월 롤업). `DEV_CNT/DEV_MEMBERS/STOP_CNT/STOP_MEMBERS` 실채움. **신규 컬럼 `HAS_BILLING BOOLEAN`**(출처 플래그)로 보수(billing-only)·정확(전체) 양립. **시뮬 검증: 40,054,883행=distinct grain(fan-out 0)·HAS_BILLING=TRUE 37,792,336(구 스파인과 정확 일치)·EVENT_ONLY 2,262,547·DEV 2.97M/STOP 0.97M 월×회원**.
  - ⚠️ **DDL 변경**: FMM에 `HAS_BILLING` 1컬럼 추가(06_DDL.sql). fact는 append+pre-hook TRUNCATE라 **build 전 06_DDL 재실행(ALTER/재생성) 필요** — 미실행 시 신컬럼 부재로 append 실패.
  - ⚠️ **DEV_CNT 의미**: FME 사건수(금액/10000 아님). 금액기반 "건"은 원천 금액컬럼+FME 변경 필요(별도트랙).
- 🔜 **잔여(B계열) — ⏸️ Agent 오픈(SV 배포) 후 진행 결정**: SV/Agent를 먼저 열어 실사용 피드백을 받은 뒤 우선순위대로 착수. 데이터·조인은 준비됨, 각 게이트만 남음.
  - **B1 FSE SUCCESS/FAIL_MEMBERS**: SNDNG_RST_CD 채워짐(2/1/Y/4/3/N/0) → **채널별 성공/실패 코드매핑 업무확정** 후 파생.
  - **B2 FMM SPONSORSHIP_SK·PAYMENT_SK**: 원천 컬럼(SPNSR_BSNS_ID·PAYMENT_TYPE 등) 존재 → **O8 다중후원(회원 9.9%·최대13) grain 규칙**(대표후원/최빈) 확정 후.
  - **B3 FMM/FSE CAMPAIGN_SK**: 발송/회비 원천에 캠페인 컬럼 부재 → **조인경로 확보 + O8 fan-out 검증**(§1-6 P3 패턴) 후.
  - **근거**: A1/A3로 Phase-1 SV 실활성 스코프(발송수·서비스구분·개발/중단 총건 등)는 충분 확보 → Agent 먼저 열고, B는 실사용 요구에 따라 순차.

## 🟡 결정 대기 — 누락/과잉 GOLD 6개
모델 작성 여부 결정 필요. **상세는 문서30 §6.** 요약: 소스 준비 4개(즉시 가능)·소스 입고대기 1개(FACT_TARGET_BIZ, 원천=**CRM** 확정·신규 목표 테이블 대기)·`DIM_MEMBER_IDENTITY`는 **2026-07-15 활성화 완료**(enabled=true·XREF dedup 조인, 1,274명 매칭).

## 🟢 [정정 2026-07-15 · 재생성 2026-07-21] BLOCKING-3 — dbt project 배포됨
**정정(2026-07-15)**: 앞선 "결과 공란"은 **조회 스키마 오류**(`SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER`)였음 — 프로젝트는 **`GN_DW.OPS`** 에 있음. dbt 버전관리·`build` 게이트·리니지 정상 작동.
- **[2026-07-21 계정이전 재생성]** 신 계정(cs94293)에 `GN_DW.OPS.DW_PIPELINE` **최초 재생성 완료** — `VERSION$1`(default=LAST, A1/A3 반영분). `CREATE DBT PROJECT` 권한을 GN_DW_ADMIN에 선부여 후 생성(`10_dbt_pipeline/deploy_dbt_project.sql`). source=`snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/`.
- **[2026-07-21 build 검증]** `build --target dev` (전체 232 노드) → **PASS=211 WARN=21 ERROR=0**. FMM 40,054,883·FSE 38,470,780 재적재. WARN 21 = 기존 참조무결성 warn(순서9-C 강등분).
- **후속**: 워크스페이스 편집분은 `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION` 으로 반영.
- **참고(구 계정 이력)**: 구 계정 default=VERSION$6 `IDENTITY_WIRED_20260715` — 신 계정은 versions/live 최신 코드가 곧 VERSION$1 이라 드리프트 무관.

## 🟢 [순서9-D 2026-07-15 배포·검증완료 / 2026-07-16 9/9 완결] BLOCKING-4 — GOLD WIDE VIEW: 9/9 배포완료(dbt view)
GOLD 스키마 COMMENT 는 "WIDE VIEW 9개 제공"이라 기재됐으나 실측 뷰 0개였음. **순서9-D 에서 dbt view 모델(`models/gold/wide/`, `ref()`·`materialized:view`)로 8종 저작→`ADD VERSION`→full `build` 배포 완료** — 미거버넌스 객체(BLOCKING-3) 재발 방지.
- ✅ **배포·검증완료 8종**: WIDE_MEMBER_MONTHLY·WIDE_MEMBER_EVENT·WIDE_TARGET_DEV·WIDE_SERVICE_EVENT·WIDE_GA_BEHAVIOR·WIDE_AD_PERFORMANCE·WIDE_EVENT_PARTICIPATION·WIDE_BUDGET. **full `dbt build` green(PASS=205 WARN=21 ERROR=0)**, 8 view models OK created.
- ✅ **COMMENT 적용 검증(실측)**: 각 모델 `post_hook`(`ALTER VIEW ... ALTER COLUMN` + `COMMENT ON VIEW`, 정본 `10_WIDE VIEW 코멘트.sql` verbatim)로 **뷰레벨 8/8 + 컬럼레벨 310/310(100%)** 적용 확인. (72+48+45+42+38+34+21+10=310. 330−310=보류된 WIDE_TARGET_BIZ 몫.)
- ⏳ **보류 1종 WIDE_TARGET_BIZ**: ✅ **[해소 2026-07-16]** `FACT_TARGET_BIZ`(스켈레톤)+`WIDE_TARGET_BIZ` dbt 모델 저작 → `build --select FACT_TARGET_BIZ WIDE_TARGET_BIZ` green(PASS=2, 0행). BLOCKING-4 이제 **9/9**. 단, 아래 §단위충돌·조인키 결함 처리분 참조.
- ✅ **WIDE_GA_BEHAVIOR IDENTITY 배선(2026-07-15 갱신)**: `DIM_MEMBER_IDENTITY` 활성화에 따라 IDENTITY_* 4컬럼 **NULL 플레이스홀더 → 실조인 복원**(`f.IDENTITY_SK = DIM_MEMBER_IDENTITY.IDENTITY_SK`). FACT_GA_BEHAVIOR.IDENTITY_SK 도 XREF(pseudo→회원)→DIM 매칭분으로 채움(미매칭=0 센티넬). ⚠️GA4 1일 기반·G-5 시 재검증(아래 §G-5 게이트).
- 🔜 **후속(저우선)**: GOLD 스키마 설명 "9개"→실 배포 9종 일치 확인 완료.

### ⚠️ [2026-07-16 비판적 검토] FACT_TARGET_BIZ 스켈레톤 — 잠복 결함 2건 처리
0행 스켈레톤이라 build 는 통과하나, 데이터 입고 시 **조용히 오작동**할 구조 2건을 사전 발견·교정.
- 🔴→✅**해소** **단위충돌(금액 vs 건)**: (구)SILVER `ERP_BIZ_TARGET.TARGET_AMT`=목표 **금액(원)** vs GOLD measure `ANNUAL/SUPP_GOAL_CNT`(#152~155)=목표 **건(件)**. 최초안은 `TARGET_AMT→ANNUAL_GOAL_CNT` 매핑 = 금액을 건 슬롯에 강제투입(`FACT_BUDGET` "재무 오귀속 방지" 원칙 위배). **[2026-07-20 해소] SILVER 테이블을 `CRM_BIZ_TARGET`(`TARGET_CNT` 건 + `TARGET_TYPE` 당초/추경)로 재구축 완료** → GOLD FACT는 TARGET_TYPE 피벗(당초→ANNUAL·추경→SUPP)으로 배선. ①금액 measure 신설안 폐기. 잔여 = 현업 데이터 입고(E-6). (원천=CRM 확정, 문서30 §6)
- 🔴 **조인키 타입 불일치(이름 vs 코드)**: 최초안이 DIM 코드 BK(`ORG_DK`=hash(DEPT_ID)·`SPONSORSHIP_BK`=SPNSR_BSNS_ID·`CAMPAIGN_BK`=CMPGN_CD)에 SILVER **이름**(ORG_NM·SPONSOR_BIZ_NM·CAMPAIGN_NM)을 조인 → 입고 시 100% Unknown(0) 라우팅될 뻔. → **이름기반 조인으로 교정**(`o.DEPARTMENT`·`s.SPONSORSHIP_NAME`·`c.CAMPAIGN_NAME`). ⚠️잔여: ERP 조직명=본부/지부 grain vs `DIM_ORG.DEPARTMENT`=부서 grain 불일치 가능 → **조직 이름 크로스워크**(문서32) 확보 전까지 미매칭 시 Unknown(0).
- **결론**: 구조·리니지·거버넌스는 완결(9/9). 측정치 실채움은 E-6 입고 + 위 2개 해소조건 충족 시.

## 🟢 [순서9-D 2026-07-15] 내부 후속 TODO 처리 (bronze 데이터·설계로직 범위)
순서9-D 종료 시점, 현업 회신·데이터 입고 없이 진행 가능한 잔여 내부작업을 전수 점검·처리.
- ✅ **[DONE] #3 `AGENCY_AD_PERFORMANCE.AD_DATE` warn→error 승격**: 실측 널 0/235,572 → `_silver_bridge_schema.yml` severity 제거(구조 불변식). build green 재확인.
- 🟠 **[결정대기] #1 `FACT_BUDGET.PLAN_BUDGET_YEAR` (현재 NULL)**: 원천 `ERP_BUDGET`에 `CHN_BUDGET_AMT`(추경)·`ADJ_BUDGET_AMT`(조정) 실재하나 GOLD FACT_BUDGET 대응 슬롯 부재. **`PLAN_BUDGET_YEAR`(연 편성)에 추경/조정 주입은 의미론적 오류**(개정버전≠연편성) + FACT_BUDGET 헤더 "재무 오귀속 방지" 원칙 위배. → **임의 매핑 금지.** 올바른 처리 = ①GOLD DDL에 추경/조정 전용 슬롯 신설(시맨틱 계약 변경) 또는 ②소비 정의 확정. 설계결정 문서30 §6. **순수 내부 기계작업 아님(설계/시맨틱 결정 필요).**
- ⏳ **[Q10 게이트] #2 `FACT_AD_PERFORMANCE` 캠페인 이름매칭 PoC**: AGENCY.CAMPAIGN_NM ↔ CRM_CAMPAIGN.CMPGN_NM 실구현은 Q10(현업 연결키 회신) 대기. 진단 PoC만 가능 → 실구현 제외.
- **결론**: bronze 데이터·설계로직만으로 안전 진행 가능한 내부작업은 #3로 종료. #1(설계결정)·#2(Q10)는 외부/결정 의존.

## 🟡 [순서9-C] GOLD 완성 진행 요건 — 내부분 착수·검증 완료 / 잔여 외부의존
파이프라인 골격(SILVER 32 + GOLD 24 base + WIDE 9 + build green) 완성. **내부 가능분은 순서9-C에서 작성·build 검증 완료(PASS=27 WARN=1 ERROR=0)**:
- ✅ **작성완료**: `DIM_BUDGET_ITEM`(2,041) · `DIM_AD_CREATIVE`(8,474) · `FACT_BUDGET`(24,480, 편성/집행만) · `FACT_AD_PERFORMANCE`(235,572, 스캐폴드: measure/날짜만·차원FK=0) · **#80 `FACT_MEMBER_MONTHLY.UNPAID_FLAG_EOM/BOM`**(미납 EOM=true 3,302,535).
- ✅ **이슈 E 진단완료**: 고아 99.98% 참여상세·동일기간·동일형식 → **마스터 누락(외부)** 확정. 내부 수정 불가·warn 유지.
- ✅ **데이터기반 설계결정**: A-2 `_SOURCE_SYSTEM='AGENCY'` 상수(매체구분은 속성) · DEVICE_TYPE PC/M(APP 휴면).
- ⏳ **잔여 외부 원천 입고**: `FACT_BUDGET.FUNDRAISING_COST`(E-1)·`.AD_COST`(E-4) · `FACT_TARGET_BIZ`(E-6) · GA4 분석(G-5) · 회원 마스터 전량입고(BLOCKING-1).
- ⏳ **잔여 현업 회신**: `FACT_AD_PERFORMANCE` CAMPAIGN_SK(Q10)·AD_CREATIVE_SK(소재 부분키)·DEVICE_SK(매핑)·GA_CONV(O5) · 이슈 A/C/D.
- 🔜 **다음 세션(내부 가능)**: WIDE VIEW 9종 dbt view화 + COMMENT(`03_top-down_gold/10_...sql`) → BLOCKING-4 해소.
- **요건 총괄표(정본)**: `10_dbt_pipeline/00_배포운영_통합_20260715.md` **§7**.

## 🟢 배포 미반영 (하위: 위 BLOCKING-3 로 격상)
순서 9·9-B 편집은 **워크스페이스 직접실행 검증만** 완료. ~~배포객체 `ALTER DBT PROJECT ... ADD VERSION` 미반영~~ → **실측 결과 객체 자체 부재로 BLOCKING-3 로 통합.** 최초 `CREATE` 후 이후 편집분은 `ADD VERSION` 으로 반영.

## ✅ [DONE 순서9-C 2026-07-15] dbt project 배포 + full build green 달성
**배포**: `CREATE DBT PROJECT GN_DW.OPS.DW_PIPELINE` (운영 전용 스키마 — 데이터 레이어 SILVER/GOLD와 분리, 접두어 중복·스코프 오칭 제거). 50 models(SILVER 32+GOLD 18, 07-15 시점)·153 data tests. *(이후 GOLD 확장: dim15+fact9+WIDE9 → 전체 65 models, 2026-07-16)*

**첫 build 에서 드러난 17 ERROR 처리** (153-test ERD suite가 배포 전 한 번도 실행 안 됨 → 잠재버그 일괄 표면화):
| 분류 | 건수 | 조치 |
|---|---|---|
| ① 테스트 정의 버그 (존재하지 않는 컬럼 not_null) | 7 | GA4_DEVICE→`DEVICE_TYPE`, GA4_TRAFFIC_SOURCE→테스트 제거, AGENCY/ERP→실제 `*_DK`/`AD_DATE` 로 교정 |
| ② `unique_GA4_EVENT_DIM_EVENT_NAME` 오탐(35) | 1 | **잘못된 unique 테스트 제거**(EVENT_NAME 은 브리지 grain상 다중행 정상). ※ 최초 시도한 "모델 EVENT_NAME 축약"은 GOLD DIM_GA_EVENT 의 (cat,label,action) 조합 커버리지를 파괴해 **원복** |
| ③ 참조무결성 실패 (E 263,611 포함) | 9 | `severity:warn` 강등 (메달리온 BP: 알려진 원천 미완전은 warn 관측, error 는 구조 불변식만) |

**결과**: full `dbt build` → **PASS=181 WARN=21 ERROR=0 SKIP=0** (2026-07-15 실측 검증). 50 models 전량 SUCCESS. ⚠️ ②원복분 재배포·DIM_GA_EVENT 정리는 아래 참조.

### ⚠️ 아키텍처 비평 · 보수적 주석 (누락 금지 후속검토)
- **E 23% warn 전환 리스크**: 참여 팩트의 23%가 이벤트 마스터 고아 = 단순 "known gap" 이상. GOLD `FACT_EVENT_PARTICIPATION` 이 `COALESCE(EVENT_SK,0)` 로 Unknown(SK=0) 라우팅하므로 **분석 파손은 없으나**, 23% 가 Unknown 이벤트로 집계됨 = 분석 한계. **근본원인(마스터 누락 vs 키체계) 진단 최우선.** warn→error 복귀 조건: 마스터 전량입고/키체계 확정.
- **`GA4_EVENT_DIM` = (event_name×cat×label×action) 브리지 grain 유지**: GOLD `DIM_GA_EVENT` 가 여기서 distinct (cat,label,action) 추출 → **조합 커버리지 필수**. `unique(EVENT_NAME)` 은 오탐이라 제거(모델 원복). **사고교훈**: 다운스트림(merge 차원) 추적 없이 상류 grain 변경 금지. **merge 차원(GOLD dim)은 pre-hook TRUNCATE 없어 상류 grain 변경 시 stale 행 잔존**(R1) → 중간빌드 잔재로 `GOLD.DIM_GA_EVENT` 2,842→2,846. **✅ [2026-07-16 해소] 실측 `GOLD.DIM_GA_EVENT`=2,842(목표 복원 확인)** → 잔재 정리 완료. **R1 표준 대응(2026-07-16 확립)**: 완전 재산출 차원은 merge 대신 **append+pre-hook TRUNCATE**(fact 패턴)로 전환하면 grain 변경에도 잔존행 원천 차단 — `DIM_MEMBER`가 이 패턴으로 SCD2 활성화(D2). 나머지 merge 차원도 grain 변경 이력 있으면 동일 검토 권장.
- **`AGENCY_AD_PERFORMANCE.AD_DATE` not_null**: ✅ **[DONE 순서9-D]** 실측 널 0/235,572 확인 → `severity:warn` 제거·error 승격(구조 불변식). (참고: CREATIVE_DK·BUDGET_ITEM_DK 는 COALESCE-해시 생성이라 구조상 non-null → error 유지 안전.)
- **프로세스 교훈**: 테스트는 저작만으로 검증된 게 아님 — 반드시 `build`(run+test)로 실행해야 잠재버그가 드러남(`run` 단독 금지, 통합 문서 R2).

### warn→error 복귀 추적표 (마스터 전량입고/확정 시)
| 대상 | 파일 | 현 severity | 복귀 트리거 |
|---|---|---|---|
| EVENT_KEY→CRM_EVENT (이슈 E) | `_crm_schema.yml` | warn | 마스터/키체계 확정 |
| SNDNG_KEY→CRM_SEND_REQUEST ×2 | `_crm_schema.yml` | warn | 발송요청 마스터 전량입고 |
| SPNSR_BSNS_ID→CRM_SPONSORSHIP ×2 | `_crm_schema.yml` | warn | 후원사업 마스터 전량입고 |
| CMPGN_CD→CRM_CAMPAIGN ×2 | `_crm_schema.yml` | warn | 캠페인 마스터 확정 |
| not_null MBER_NO ×2 (SEND_MEMBER 745·PAYMENT_BILLING 5) | `_crm_schema.yml` | warn | 이슈 B/D 판정·마스터 재추출 |
| MBER_NO/MEMBER_DK→CRM_MEMBER 다수 (BLOCKING-1) | `_crm_schema.yml`·`_gold_ready_schema.yml`·bridge·ga4 | warn | 회원 마스터 전량입고 |
| ~~AGENCY_AD_PERFORMANCE.AD_DATE not_null~~ | `_silver_bridge_schema.yml` | ✅ **error (순서9-D 승격완료)** | ~~널 여부 실데이터 검증~~ 완료(0/235,572) |

## ✅ [DONE 2026-07-15] 검토 항목 4 — 정제규칙 drift 없음
SILVER 32모델 ↔ `04_silver_design/09_SILVER_적재쿼리_20260714.sql`(912줄) 정밀 대조 완료. **drift 0건 → 수정 없음.**
- CRM 21/21·ERP 3/3·AGENCY 2/2·GA4 5/5·bridge 1/1 일치.
- GA4는 정본 주석대로 단일샤드→`ga4_union_shards` 매크로(전기간 UNION)로 업그레이드(의도된 설계).
- 결론: 09 정본 이후 SILVER drift 없음. 순서 9-B 검토 전 항목 완료.

## 🔜 [G-5 게이트] SILVER identity 2모델 — merge 전략 전환 (전기간 샤드 입고 시)
> 트리거: **G-5(GA4 전기간 샤드 입고) 확정 시점.** 그 전까지는 현행 유지(착수 불요).

**배경(아키텍처 검토 2026-07-15)**: `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF`는 grain=`user_pseudo_id`. 활성 회원은 기기·쿠키이탈(ITP 7일 만료·시크릿 등)로 pseudo가 지속 증가 → 두 모델은 계속 성장. 현재는 프로젝트 SILVER 설정(`incremental_strategy: append` + `pre-hook: TRUNCATE` + `ga4_union_shards(var)` 윈도우)이 **매 실행 TRUNCATE 후 윈도우 전량 재계산**이라 크기에 상한은 걸리나, 전기간·상시운영 전환 시 **매 실행 전기간 재스캔 = 비용 급증**.
> GOLD `DIM_MEMBER_IDENTITY`·FACT(`IDENTITY_SK`)는 **회원 grain이라 pseudo 증가와 무관·bounded**(안전). 조치 대상은 SILVER pseudo-grain 2모델뿐.

**조치(G-5 시)**:
1. `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF` → `incremental_strategy: merge`, `unique_key='USER_PSEUDO_ID'`(XREF는 동일), `pre-hook: TRUNCATE` 제거 → 신규 pseudo만 upsert(전량 재스캔 회피).
2. **보존/시점 정책** 결정: pseudo→member 매핑에 `VALID_FROM/VALID_TO`(SCD2) 부여 or 롤링 보존(예: 24개월).
3. **충돌·지연도착 규칙** 명문화: pseudo가 나중에 user_id 획득(NULL→DIRECT)·타회원 재매핑(공용기기, n_id≥2=CONFLICT) 시 last-wins/신뢰도 우선.
4. 성장 시 `CLUSTER BY`(member 또는 event_date)로 조인 프루닝 검토.
- **주의**: 이 전환은 프로젝트 SILVER 공통설정(append+TRUNCATE)과 다르므로 **모델별 config 오버라이드**로 격리(다른 SILVER 모델 영향 금지).
- **검증**: 전환 후 `dbt build --select GA4_IDENTITY IDENTITY_MEMBER_XREF` green + 행수 단조증가(재계산 아님) 확인.

> 참고: `DIM_MEMBER_IDENTITY`는 2026-07-15 세션에서 `enabled=true` 전환·XREF dedup 조인 배선 완료(문서40 E-6 인접). 위 §"결정 대기 GOLD 6"의 "disabled 유지 권고"는 이로써 갱신됨.
>
> **⚠️ [G-5 재확인·재실행 필수] identity 결선 다운스트림 3모델** — `DIM_MEMBER_IDENTITY`·`FACT_GA_BEHAVIOR`(IDENTITY_SK)·`WIDE_GA_BEHAVIOR`(IDENTITY_* 4컬럼)는 **GA4 1일 샤드(커버리지 4.22%, 매칭 1,274명) 기반으로 배선**된 상태. GA4 전기간 입고(G-5) 시 반드시: ① `GA4_IDENTITY`·`IDENTITY_MEMBER_XREF` 재적재 → ② `DIM_MEMBER_IDENTITY`·`FACT_GA_BEHAVIOR`·`WIDE_GA_BEHAVIOR` 재빌드 → ③ 매칭 커버리지·fan-out(IDENTITY_SK 유일성)·FK 무결성 재검증. 커버리지 급증으로 매칭수·grain이 크게 변동하므로 **1일 기반 수치를 확정치로 오인 금지**.

---
_생성: 순서 9-B 세션. 갱신 시 항목별 `[DONE]`·날짜 표기._
_Co-authored with CoCo_

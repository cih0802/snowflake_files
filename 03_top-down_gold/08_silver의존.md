# GOLD → SILVER 의존(lineage) 설명서 (8단계 산출물 · 인수인계용)

**대상 독자**: GOLD ↔ SILVER 적재(ETL) 파이프라인을 구현·운영할 데이터 엔지니어
**목적**: GOLD 24개 테이블의 각 컬럼이 **실제 SILVER 물리 테이블·컬럼** 중 무엇에서 오는지 명시. SILVER가 아직 못 채우는 부분(미수령 원천)을 분리해, 후속 적재에서 헷갈리지 않도록 한다.
**짝 문서**: `06_DDL.sql`(GOLD), `04_silver_design/SILVER_DDL_20260702.sql`(SILVER), `07_메타.md`(제약).
**작성일**: 2026-07-02 (개정 2026-07-03: 현업 4레이어 원천 재정의 §0 반영)

> ⚠️ 이전 버전(`_archive/GOLD_SILVER 의존.md`)은 "SILVER 미설계" 전제라 소스를 개념엔티티 수준으로만 적었습니다. 본 문서는 **SILVER 물리 스키마(26테이블)가 확정된 후** 작성되어 실제 테이블·컬럼까지 내려갑니다.

---

## 0. 소스 레이어 맵 — 중요 (현업 2026-07 원천 재정의 반영)

BRONZE(원천 1:1) → **SILVER(정제·통합)** → GOLD(star schema). GOLD FACT에서만 소스가 횡단 통합됩니다.

현업이 원천을 **4개 레이어**로 재정의했습니다. 레이어별 BRONZE 스키마 권장 명칭·수집 방식·현황:

| # | 원천 레이어(현업 용어) | BRONZE 스키마(권장) | 수집 방식 | 현황 | 지표정의 원천코드 |
|---|---|---|---|---|---|
| 1 | CRM | `GN_DW.BRONZE_CRM` | CRM 시스템 직적재 | ✅ 적재(샘플) | CRM, CRM(UMS) |
| 2 | BigQuery(GA4) | `GN_DW.BRONZE_GA4` | 현업이 보는 GA4 데이터 — Snowflake 미적재. **BigQuery에서 가져와 구성** | frame 완료(적재 대기) | GA, GA4 |
| 3 | ERP | `GN_DW.BRONZE_ERP` | Snowflake에 파일 업로드 → 테이블화(bronze) | frame 완료(적재 대기) | ERP |
| 4 | 대행사(Agency) | `GN_DW.BRONZE_AGENCY` | Google Sheet · Google Drive Excel · MS SharePoint Excel | frame 완료(적재 대기) | AGENCY(대행사 일별레포트), GADS |

**원천 귀속 판정 (지표정의 문서 대조):**
- **GADS(Google Ads) → 대행사 레이어(4)**. 지표정의(04 마케팅)에서 광고비·노출·클릭이 `"대행사 자료(일별레포트) / Google Ads"`로 병기 → Google Ads 수치가 대행사 일별레포트 시트에 실려 전달됨. ✓ 현업 판단과 일치.
- **ADMIN(어드민) → ❌제외 확정(2026-07-09)**. 지표정의(05 회원)의 `"어드민 화면 수집"`(이벤트 조회수·앱푸시 발송/성공, A-5/6/10)은 **원천 미채택**. **순수 어드민 전용 컬럼은 삭제**: `FSE.APP_PUSH_SEND_CNT`·`APP_PUSH_SUCCESS_CNT`·`FEP.VIEW_CNT`(내년 어드민 구현 시 `ADD COLUMN` 재추가). ⚠️ **행사기간·참여경로·참여채널은 CRM-backed라 삭제 안 함**(`DIM_EVENT.EVENT_START/END_DATE`=`CRM_EVENT.STRT_DE/END_DE`, `FEP.PART_PATH/PART_CHANNEL`=CRM). → `BRONZE_ADMIN` 스키마 불요.
- **CRM(UMS)** = CRM 메시지발송(UMS) 영역 → CRM 레이어(1)에 포함.

**SILVER 설계 확정 = 26개 테이블 (CRM 21 + GA4 5).** CRM은 물리 스키마 확정, GA4는 BigQuery 적재 후 구성 대상. ERP·대행사는 아직 SILVER 없음. **어드민(ADMIN)은 ❌제외 확정 → SILVER 불요.**

| GOLD가 기대하는 원천 | SILVER 상태 | 비고 |
|---|---|---|
| CRM (+UMS) | ✅ 구현 (`SILVER.CRM_*` 21개) | 회원·약정·납입·발송·행사·조직·코드 등 |
| BigQuery(GA4) | ⏳ 설계 확정 (`SILVER.GA4_*` 5개) | BigQuery 적재 후 구성 (샤드 통합 → `04_silver_design/GA4_SILVER_샤드통합_설계결정.md`) |
| ERP | ⏳ frame 완료 · SILVER 미생성 | 사업목표·편성/집행예산·모금성비용 |
| 대행사(Agency, GADS 포함) | ⏳ frame 완료 · SILVER 미생성 | 광고소재·광고비·노출/클릭/인입콜·편성비 |
| 어드민(ADMIN) | ❌ 제외 확정(2026-07-09) | 앱푸시 발송/성공·이벤트 조회수·행사기간/참여경로/채널 → **원천 미채택**. 의존 GOLD 컬럼 미채움 고정 |

> ERP·대행사에 의존하는 GOLD 구조는 **컬럼만 설계**되어 있고 SILVER 소스가 없습니다(§4에 격리). GA4는 BigQuery 적재 후 §2 매핑대로 구성. **어드민(ADMIN)은 ❌제외 확정 → 의존 컬럼 미채움 고정.** 데이터 준비 전까지 적재하지 마세요.

SILVER 테이블 26개 목록: CRM_MEMBER, CRM_MEMBER_STATUS_HIST, CRM_MEMBER_DEV, CRM_MEMBER_AMT_CHANGE, CRM_MEMBER_DISCONTINUE, CRM_MEMBER_RESPONSOR, CRM_MEMBER_SPONSOR_BIZ, CRM_SPONSOR_RELATION, CRM_PAYMENT_BILLING, CRM_PAYMENT_METHOD, CRM_CAMPAIGN, CRM_SPONSORSHIP, CRM_ORG, CRM_DEV_TARGET, CRM_SEND_REQUEST, CRM_SEND_MEMBER, CRM_SEND_RESULT, CRM_EVENT, CRM_EVENT_PARTICIPATION, CRM_RELATION_ACTIVITY, CRM_CODE / GA4_TRAFFIC_SOURCE, GA4_EVENT_DIM, GA4_DEVICE, GA4_EVENT, GA4_IDENTITY.

---

## 1. DIM 의존 (15)

> 표기: `SILVER테이블.컬럼`. 대리키(`_SK`)는 ETL이 생성(SILVER에 없음). `파생`=SILVER/ETL 정제 산출. ⚠️=원천·규칙 확인 필요.

| GOLD 차원.컬럼(군) | SILVER 소스.컬럼 | 비고 |
|---|---|---|
| **DIM_DATE**.* | (없음) | ETL 생성 캘린더. 팩트 일자 범위로 채움. 소스 무관 |
| **DIM_ORG** 법인/본부/부서/팀 | `CRM_ORG.DEPT_NM`(+`UPPER_DEPT_ID`·`ACMSLT_UPPER_DEPT_ID` 계층 전개) | ORG_DK ← `CRM_ORG.DEPT_ID`. 계층 라벨은 재귀 전개 |
| **DIM_MEMBER**.MEMBER_DK | `CRM_MEMBER.MEMBER_DK` | 불변 회원키(VARCHAR(10)) |
| DIM_MEMBER.GENDER | `CRM_MEMBER.SEX` | |
| DIM_MEMBER.MEMBER_STATUS | `CRM_MEMBER.MBER_STAT_CD` + `CRM_MEMBER_STATUS_HIST`(SCD2) | 현재상태/이력 |
| DIM_MEMBER.MEMBER_TYPE | `CRM_MEMBER.MEMBER_TYPE` | 정기/일시(파생) |
| DIM_MEMBER.FIRST_JOIN_DATE | `CRM_MEMBER.JOIN_DT` | |
| DIM_MEMBER.ENROLL_PATH | `CRM_MEMBER.JOIN_PATH_CD`(+`CRM_CODE` 라벨) | |
| DIM_MEMBER.FIRST/LAST_CAMPAIGN | `CRM_MEMBER_DEV.CMPGN_CD`(min/max) | DIM_CAMPAIGN 조인으로 SK 해소 |
| DIM_MEMBER.FIRST/CURRENT_SPONSORSHIP | `CRM_MEMBER_DEV.SPNSR_BSNS_ID` / `CRM_MEMBER_SPONSOR_BIZ` | |
| DIM_MEMBER.LAST_STOP_DATE | `CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE`(max) | |
| DIM_MEMBER.NEW_EXISTING_FLAG | 파생(약정 이력 기반) | 정의 합의 전 ⚠️ |
| DIM_MEMBER.EFFECTIVE_FROM/TO·IS_CURRENT | 파생(SCD2, ETL) | |
| DIM_MEMBER.**REGION** | `CRM_MEMBER_DEV`/`CRM_MEMBER_AMT_CHANGE`(개발·증감 시점 AREA_CD 스냅샷) | MBER_INFO엔 없음 — 거래테이블서 취득(doc 12). SILVER 편입 확인 → §5-A |
| DIM_MEMBER.**AGE_BAND** | `CRM_MEMBER_DEV`/`CRM_MEMBER_AMT_CHANGE`(개발·증감 시점 AGE 스냅샷) | 생년 raw 미적재, AGE 코드화로 충족(doc 12). SILVER 편입 확인 → §5-A |
| **DIM_MEMBER_IDENTITY**.MEMBER_DK/MEMBER_NO | `CRM_MEMBER.MEMBER_DK` / `GA4_IDENTITY.MBER_NO`·`ONCE_MBER_NO` | 브리지(P5) |
| DIM_MEMBER_IDENTITY.GA_MEMBER_ID | `GA4_IDENTITY.GA_MEMBER_ID` | = user_id(회원번호) |
| DIM_MEMBER_IDENTITY.HOMEPAGE_ID | `CRM_MEMBER.HMPG_ID` | |
| DIM_MEMBER_IDENTITY.CHILD_CODE | `CRM_SPONSOR_RELATION.CHILD_CD` | 결연아동코드 |
| DIM_MEMBER_IDENTITY.MEMNUM | `CRM_MEMBER.MEMBER_DK`(=회원번호 문자) | doc 99: memnum = member id = 회원번호 문자, **별도 키 아님** |
| **DIM_CAMPAIGN**.CAMPAIGN_BK/NAME | `CRM_CAMPAIGN.CMPGN_CD`/`CMPGN_NM` | |
| DIM_CAMPAIGN.BRAND/PARENT/PROMO_METHOD | `CRM_CAMPAIGN.BRND_NM`/`UPPER_CMPGN_CD`/`PR_MTH_CD` | |
| DIM_CAMPAIGN.CAMPAIGN_TYPE/DOMESTIC_OVERSEAS/BIZ_CASE_TYPE | `CRM_CAMPAIGN.CMPGN_TYPE1_BSN`·`CMPGN_TYPE2_BSN`·`CMPGN_CTGR_CD`(+`CRM_CODE`) | ⚠️Q2/Q3 코드→라벨 |
| DIM_CAMPAIGN.CAMPAIGN_OPEN_DATE | `CRM_CAMPAIGN.CMPGN_STRT_DE` | |
| ⚠️ DIM_CAMPAIGN.ORG_SK | (캠페인↔조직 연결원천 미확정) | `CRM_CAMPAIGN`에 부서 컬럼 없음 → §5-A |
| **DIM_SPONSORSHIP**.BK/NAME/ABBR | `CRM_SPONSORSHIP.SPNSR_BSNS_ID`/`SPNSR_BSNS_NM`/`SPNSR_BSNS_ABRV_CD` | 실측 50개 |
| **DIM_GA_SOURCE**.UTM_*·SOURCE_MEDIUM | `GA4_TRAFFIC_SOURCE.UTM_SOURCE`·`UTM_MEDIUM`·`UTM_CONTENT`·`UTM_TERM`·`SOURCE_MEDIUM` | |
| **DIM_GA_EVENT**.CATEGORY/LABEL/ACTION | `GA4_EVENT_DIM.EVENT_CATEGORY`·`EVENT_LABEL`·`EVENT_ACTION` | |
| **DIM_DEVICE**.DEVICE_TYPE | `GA4_DEVICE.DEVICE_TYPE` | PC/M/APP |
| **DIM_SERVICE**.SEND_TYPE_L/M/S·SUBTYPE·CHANNEL | `CRM_SEND_REQUEST.SNDNG_TY_CD`·`SEND_CHANNEL`(+`CRM_CODE` 라벨) | ⚠️발송 대/중/소·subtype 코드체계 확인 → §5-A |
| **DIM_PAYMENT**.PAYMENT_METHOD/SETTLE_METHOD | `CRM_PAYMENT_METHOD.CARD_DIV_CD`·`SETLE_CD`(+`SETLE_NM`) | |
| DIM_PAYMENT.FEE_TYPE | `CRM_PAYMENT_BILLING.GFT_DIV_CD` / 파생(정기·일시) | ⚠️회비유형 이중표현 보류 |
| **DIM_REASON**.REASON_CODE/NAME | `CRM_MEMBER_DISCONTINUE.DSCNTC_RSN_CD`·`DSCNTC_RSN_NM` (또는 `CRM_CODE` MM005) | ⚠️사유코드 체계 확인 |
| DIM_REASON.REASON_TYPE | 파생(미납/중단 구분) | |
| **DIM_EVENT**.EVENT_BK/KIND/NAME | `CRM_EVENT.EVENT_KEY`/`EVENT_DIV_CD`/`EVENT_NM` | 이벤트∪캠페인행사 |
| DIM_EVENT.EVENT_START/END_DATE | `CRM_EVENT.STRT_DE`/`END_DE` | |
| ⚠️ DIM_EVENT.EVENT_CATEGORY·APPLY_CHANNEL | `CRM_EVENT`(원천 확인) / 파생 | → §5-A |
| **DIM_AD_CREATIVE**.* | 🟢 **AGENCY 3테이블 적재** — 유형별 정제→UNION(실측 검토 §4·02 §3) | §4 |
| **DIM_BUDGET_ITEM**.* | 🟢 **ERP 원장 적재** — 예산과목(장~세세목) 매핑 가능(§4) | §4 |

---

## 2. FACT 의존 (9) — measure/degenerate별 소스

| GOLD 팩트 | 컬럼군 | SILVER 소스.컬럼 | 비고 |
|---|---|---|---|
| **FACT_MEMBER_MONTHLY** (FMM) | 개발(DEV_*) | `CRM_MEMBER_DEV`(SPNSR_AMT/10000, MBER_NO distinct) | basis: 금액/10000 |
| FMM | 중단/활동/미납 스냅샷(ACTIVE_*·UNPAID_*·STOP_*·CHURN_*·*_ACTIVE_CNT·UNPAID_FLAG_*) | `CRM_MEMBER_STATUS_HIST` + `CRM_MEMBER_SPONSOR_BIZ` | 시점 스냅샷 |
| FMM | 증감(INCREASE_*·DECREASE_*) | `CRM_MEMBER_AMT_CHANGE`(SPNSR_AMT, RDCAMT_YN) | |
| FMM | 회비/청구(REGULAR_FEE·PAID_FEE·BILLED_AMT 등) | `CRM_PAYMENT_BILLING`(PAY_AMT·RQEST_AMT) | ⚠️Q14 납입 dedup·청구 행기준 |
| FMM | 재후원(REDONATE_FLAG) | `CRM_MEMBER_RESPONSOR` | |
| FMM | degenerate(DEV_TYPE·NEW_FLAG·JOIN_DATE·STOP_DATE·금액대·기간대·SPONSOR_MONTHS 등) | `CRM_MEMBER_DEV`·`CRM_MEMBER_DISCONTINUE`·`CRM_PAYMENT_BILLING` | 월 스냅샷(시변) |
| ⚠️ FMM | INBOUND_CALL_CNT·TS_CALL_CNT | ❌ **CRM 부재 — 현업 별도입력(비-CRM)** | doc 13 C-8 회신 확정 → §4 성격 |
| **FACT_MEMBER_EVENT** (FME) | 개발/중단 건·명 | `CRM_MEMBER_DEV` + `CRM_MEMBER_DISCONTINUE` | |
| FME | STOP_REASON/STOP_CHANNEL | `CRM_MEMBER_DISCONTINUE.DSCNTC_RSN_CD`·`DSCNTC_PATH` | |
| **FACT_TARGET_DEV** (FTG_D) | GOAL_CNT | ✅ `CRM_DEV_TARGET`(STDYY+STDR_MT→MONTH_KEY, DEPT_ID→ORG, MBER_DVLP_DIV_CD→DEV_TYPE, GOAL_CNT) | 소스 확정 |
| **FACT_SERVICE_EVENT** (FSE) | 발송/성공/실패(SEND_*·SUCCESS_*·FAIL_*) | `CRM_SEND_REQUEST`+`CRM_SEND_MEMBER`+`CRM_SEND_RESULT` | 명=MBER_NO distinct |
| FSE | 서신/선물금 참여(LETTER_*·GIFT_*·D5_*) | `CRM_RELATION_ACTIVITY`(GFTMNEY, LETTER_DIV_CD) × `CRM_SEND_*` | 발송+5일 윈도우 매칭 |
| FSE | degenerate(SEND_TITLE·SEND_STATUS) | `CRM_SEND_REQUEST.TIT` / `CRM_SEND_MEMBER.SNDNG_RST_CD` | |
| ❌ FSE | APP_PUSH_SEND_CNT·APP_PUSH_SUCCESS_CNT | ❌ **ADMIN ❌제외 확정(2026-07-09) → 컬럼 유지·미채움 고정** | §4 |
| **FACT_GA_BEHAVIOR** (FGA) | 방문/세션/이벤트/스크롤/체류(VISITS·SESSION_CNT·EVENT_CNT·SCROLL_DEPTH·ENGAGEMENT_*·BOUNCE_RATE 등) | `GA4_EVENT`(GA_SESSION_ID·PERCENT_SCROLLED·ENGAGEMENT_TIME_MSEC·IS_ACTIVE_USER 등) | 비/준가산 주의 |
| FGA | IDENTITY_SK(회원 귀속) | `GA4_IDENTITY` | §3 |
| FGA | degenerate(PAGE_PATH·PAGE_LOCATION) | `GA4_EVENT.PAGE_LOCATION` | |
| **FACT_AD_PERFORMANCE** (FAD) | GA_CONV_* | `GA4_EVENT`(전환 이벤트) | ⚠️전환 정의(O5) |
| FAD | AD_COST·IMPRESSIONS·CLICKS·INBOUND_CALL | 🟢 **AGENCY 3테이블 적재** — 유형별 정제→UNION(실측 검토 §4·02 §3). 노출·클릭=DGT만·인입콜 REBRDC TEXT/VIDEO NUMBER·`_SOURCE_SYSTEM` SILVER 부여 | §4 |
| **FACT_EVENT_PARTICIPATION** (FEP) | 모집/참여/취소/당첨 등 | `CRM_EVENT` + `CRM_EVENT_PARTICIPATION`(PARTCPT_STAT_CD·PRZWIN_CD·RCPMNY_AMT) | |
| **FACT_TARGET_BIZ** (FTG_B) | 사업목표(ANNUAL_*·SUPP_*) | ⛔ **원천 부재** — 적재된 ERP 예산원장은 사업목표 아님, 별도 입고(33 E-6) | §4 |
| **FACT_BUDGET** (FBD) | 편성/집행예산·모금성비용·광고비 | ◐ **ERP 원장 적재** — 편성/집행 O · 모금성비용 원천 부재 · 광고비 AGENCY 보강(§4·02 §3) | §4 |

---

## 3. Cross-source 통합 지점 (GOLD FACT에서만 발생 — SILVER는 1:1 유지)

| GOLD 위치 | 통합 SILVER 소스 | 통합 키 | 비고 |
|---|---|---|---|
| FGA → 회원 귀속 | `GA4_EVENT`/`GA4_IDENTITY` → `CRM_MEMBER` | `DIM_MEMBER_IDENTITY`(GA_MEMBER_ID ↔ MEMBER_DK, 1:N) | 모든 GA↔회원 통합의 근간. **user_id 4.22% → session-fill(`USER_ID_FILLED`·`ID_RESOLUTION`, 06_GA4 §5-A)로 커버리지 보강**, 파생지표는 신뢰도 필터 |
| FMM × 발송(신33) | `CRM_MEMBER_*` + `CRM_SEND_*` | MEMBER_DK | |
| FAD = GA전환(GA4) + 노출/클릭/비용(AGENCY·ERP) | `GA4_EVENT` + AGENCY 3테이블(🟢적재, 스키마 상이) | CAMPAIGN_SK(이름매칭) · `DW_SOURCE_SYSTEM`(SILVER 부여) | 실측 검토 게이트 §4·02 §3 |

> **핵심**: 회원 cross-source 통합은 전부 `DIM_MEMBER_IDENTITY` 브리지(`GA4_IDENTITY` 기반)에 의존. 이 브리지의 행매칭 정밀도가 GA 기반 회원지표의 선결 조건.

---

## 4. SILVER 부재 = GOLD 설계만 존재 (미수령 원천, 적재 금지) — 인수인계 필독

아래는 GOLD에 **컬럼은 있으나 SILVER 소스 테이블이 아직 없는** 항목입니다. 설계원칙 P9(“컬럼은 만들되 적재는 원천 입고 후”)에 따른 것입니다.

> 🔄 **[실측 2026-07-13]** ERP·AGENCY는 **BRONZE에 적재됨**(더 이상 "미수령" 아님) — 단 실측 결과 **설계와 구조가 달라** 그대로 적재 금지. **실측 검토·잠정 결정·검증 게이트는 `04_silver_design/02_…BRONZE-GOLD연결 §3 "우리끼리 선행 확정"`** 참조. 게이트 통과 전에는 여전히 스키마-only. GA4도 적재(287,025행/1일 샤드). ADMIN·CRM콜은 실제 미적재/제외 유지.

| GOLD 구조 | 원천 상태(실측 2026-07-13) | 입고/검토 후 필요한 SILVER 신설 |
|---|---|---|
| `DIM_AD_CREATIVE` (전체) | 🟢 AGENCY 3테이블 적재(스키마 상이) | `SILVER.AGENCY_AD_CREATIVE`(가칭) — 매체·소재·CM위치·초수는 **원천별 산재/부분**(DGT `MEDIA_NM`·VIDEO `CM_AREA/AD_SEC` 등). 유형별 정제→UNION(02 §3 게이트) |
| `DIM_BUDGET_ITEM` (전체) | 🟢 ERP 원장 적재 | `SILVER.ERP_BUDGET_ITEM` — 예산과목(장/관/항/목/세목/세세목) 매핑 가능 |
| `FACT_TARGET_BIZ` (전체) | ⛔ **원천 부재** | 사업목표(조직×후원사업). **예산원장≠사업목표** → 별도 입고 필요(33 E-6) |
| `FACT_BUDGET` (전체) | ◐ ERP 원장 적재(편성/집행 O) | 편성/집행 O · **모금성비용 원천 부재** · 광고비는 AGENCY 보강 |
| `FACT_AD_PERFORMANCE.AD_COST·IMPRESSIONS·CLICKS·INBOUND_CALL` | 🟢 AGENCY 적재(불균일) | measure 원천별 상이(노출·클릭=DGT만/인입콜=REBRDC TEXT·VIDEO NUMBER/광고비 컬럼 3종). `_SOURCE_SYSTEM` SILVER 부여·인입콜 `TRY_TO_NUMBER`(02 §3). `GA_CONV_*`=GA4 |
| `FACT_SERVICE_EVENT.APP_PUSH_*` | ⛔ 어드민(ADMIN) ❌제외 확정 | 앱푸시 발송/성공 — 원천 미채택 → 미채움 고정 |
| `FMM.INBOUND_CALL_CNT`·`TS_CALL_CNT` | ⛔ 비-CRM(현업 수기입력) | 회원 개발실적 콜 — CRM 부재 확정(doc 13 C-8). ※광고 인입콜(FAD)과 별개 |

---

## 5. 정합성 점검 (데이터 아키텍처 비판적 검토)

### 5-A. 확인/해소 현황 (정본 `99_provided_definition/BRONZE_CRM 테이블 정보.MD`[41테이블] 재검증)

**해소됨 — 근거 확인 완료(추정 아님)**
- ✅ **DIM_MEMBER.REGION / AGE_BAND** — 개발/증감 테이블(`TM_MM_FDRM_MBER_DVLP_AMT`·`IRSD`)의 **시점 스냅샷** `AREA_CD`(코드 **CM018**)·`AGE`에서 취득(정본 확인). REGION은 CM018 코드→라벨. 남은 확인은 SILVER `CRM_MEMBER_DEV`/`CRM_MEMBER_AMT_CHANGE` projection 편입 여부뿐.
- ✅ **DIM_MEMBER_IDENTITY.MEMNUM** — memnum = member id = 회원번호(문자)와 **동일**, 별도 키 아님 (정본 R4 해소 — `BRONZE_CRM 테이블 정보.MD` TODO §5).
- ✅ **FMM.INBOUND_CALL_CNT·TS_CALL_CNT** — **정본 41테이블에 콜 컬럼 부재** 확인 + 현업 별도입력(비-CRM)(C-8) → §4(미수령류)로 취급, CRM 적재 대상 아님.
- ✅ 관련 정의 확정: '미납' = `PAY_STAT_CD` **F∪NULL**(C-3) · '팀' = `UPPER_DEPT_ID` **5레벨=실적부서**(C-7) · `EHGT`=환율 **SILVER 제외**(C-10).

**미해소 — 확인 후 적재(추정 금지)**
- ⚠️ **DIM_CAMPAIGN.ORG_SK** — 캠페인 마스터(`TM_CM_CMPGN_MNG`)엔 부서 컬럼 없음(정본 확인). 단 **개발 테이블에 `CMPGN_CD`와 `ACT_DEPT_CD`·`ACMSLT_DEPT_CD` 병존** → 캠페인↔조직 파생은 가능하나 '캠페인 주관조직' 정의(활동 vs 실적) 확정 필요(O10).
- ⚠️ **DIM_SERVICE.SEND_TYPE_L/M/S·SUBTYPE** — 발송구분 대/중/소 = `SND_REQ_MST.SEND_GBN_TOP/MID/BOT`(+`_NM`) — 정본에 컬럼 **존재**하나 설명이 `(LLM생성)`이라 **의미 검수 대기**. SILVER `CRM_SEND_REQUEST` 매핑·SUBTYPE 확인 필요.
- ⚠️ **DIM_EVENT.EVENT_CATEGORY·APPLY_CHANNEL** — `CRM_EVENT` 원천 컬럼 확인 또는 파생 규칙. ※ 행사기간(`EVENT_START/END_DATE`=`CRM_EVENT.STRT_DE/END_DE`)·참여경로/채널(`FEP.PART_PATH/PART_CHANNEL`=CRM)은 **CRM-backed → 유지**. ADMIN A-10 제외는 이 컬럼들에 영향 없음(어드민 전용 조회수/앱푸시만 삭제).
- ⚠️ **DIM_PAYMENT.FEE_TYPE** — 회비유형 정기/일시 이중표현 보류(설계 결정 대기).

> 교차검증(정본 재확인) 결과: 종전 확인대상 7건 중 **3건 해소**(REGION·AGE_BAND / MEMNUM / 콜) — 콜은 비-CRM 확정으로 §4 이관. **잔여 4건**(ORG_SK·SEND_TYPE·EVENT·FEE_TYPE)은 추정 금지·확인 후 적재. 근거 정본: `99_provided_definition/BRONZE_CRM 테이블 정보.MD`(41테이블) + `09_bronze_crm_ddl.sql`(타입). working docs `30/32/99_next`는 참고용이며 결론은 전부 정본으로 재검증(§5-D).
> 🔄 **[2026-07-13 현업 위임]** 잔여 4건(ORG_SK·SEND_TYPE·EVENT·FEE_TYPE) + O8·O10은 **우리끼리 잠정 확정 + 검증 게이트**로 전환(상세 `04_silver_design/02_…BRONZE-GOLD연결 §3`, `33 §B`). 실측 근거: SEND_GBN 대/중/소+라벨 실재·EVENT_DIV_CD 5값·ACMSLT는 거래테이블. 게이트 미통과 객체는 스키마-only.

### 5-B. 지켜진 원칙 (positive)
- **소스 1:1 원칙**: SILVER는 CRM/GA4 각각 1:1 정제, 통합은 GOLD FACT(§3)에서만 발생 ✓
- **회원 식별 일관**: 모든 회원 cross-source가 `DIM_MEMBER_IDENTITY`(MEMBER_DK↔GA_MEMBER_ID) 경유 ✓
- **회원키 타입 일관**: SILVER `MEMBER_DK`·`MBER_NO`·GA `GA_MEMBER_ID` 모두 VARCHAR → GOLD `MEMBER_DK VARCHAR(10)`와 정합(선행0·S접두 보존) ✓
- **원금액 보존**: SILVER measure 원천(SPNSR_AMT·PAY_AMT·GFTMNEY 등)이 원금액(NUMBER) → GOLD `(건)`=금액/10000 basis 계산 가능 ✓
- **grain 정합**: 월 팩트(FMM·FTG_*·FBD)는 SILVER 일자/약정에서 MONTH_KEY 롤업, 일 팩트(FGA·FSE·FEP)는 DATE_SK — 혼재 없음 ✓

### 5-C. 커버리지 요약
- GOLD 24테이블 중 **SILVER(CRM·GA4)로 적재 가능**: DIM 13 + FACT 5(FMM·FME·FTG_D·FSE·FGA·FEP 중 CRM/GA4분) — 부분 갭은 5-A.
- **적재됨·실측 검토 대기(적재 전 게이트)**: DIM 2(AD_CREATIVE·BUDGET_ITEM) + FACT(FBD 편성/집행·FAD 대부분) → §4·02 §3. **원천 부재(입고 대기)**: FTG_B 사업목표·FBD 모금성비용.

### 5-D. 레거시 문서 오염 점검 (2026-07-02)
`99_next_prompt.md`는 구설계(12 DIM+6 FACT·40테이블) 기준 **세션 핸드오프(레거시)**, `10`·`12`·`13`은 파생 working 문서다. 본 lineage 결론이 이들에 오염됐는지 **정본 `BRONZE_CRM 테이블 정보.MD`(41테이블)로 전수 재확인**한 결과:
- **결론 변경 없음** — §5-A 해소 3건·잔여 4건 모두 정본과 일치(사실 오류 없음).
- **인용 근거 정정** — MEMNUM·SEND_TYPE·REGION/AGE의 근거를 레거시(`99_next`)·working(`12`)에서 **정본(R4·SND_REQ_MST·AREA_CD CM018)** 으로 교체.
- **테이블 수 정정** — CRM 원천 = **41테이블**(구 40 아님; 2026-06 현업 +1 `TM_CM_MKTNG_CMPGN_MNG`). 본 문서 SILVER 기준(26=CRM 21+GA4 5)엔 영향 없음.
- **구설계 흔적 미유입** — 15 DIM/9 FACT 정본(`03_테이블 설계.md`) 기준 유지, 12/6 흔적 없음.
- 신규 확인 단서 — 개발 테이블에 `CMPGN_CD`+`ACT_DEPT_CD`/`ACMSLT_DEPT_CD` 병존(ORG_SK 파생 근거, §5-A).

> 🔄 **[2026-07-13 실측 갱신]** (a) `99_next_prompt.md`는 이후 **현재 24설계(15 DIM+9 FACT)로 갱신**됨 — 위 "구설계 12/6/40 레거시" 표기는 2026-07-02 시점 기준. (b) CRM 원천정의는 41테이블/876컬럼이나, **물리 `GN_DW.BRONZE_CRM` 실측 = 43테이블/927컬럼**(템플릿 2 `TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG` 추가). SILVER lineage(26=CRM 21+GA4 5)엔 영향 없음. (c) GOLD/SILVER 스키마 **미배포**(현재 BRONZE_*·OPS·SECURITY만).

---

## 6. 후속 작업 트리거

| 트리거 | 해소 대상 |
|---|---|
| 캠페인↔조직 연결원천 확정 | §5-A `DIM_CAMPAIGN.ORG_SK` — 🟡우리끼리 잠정(02 §3 게이트) |
| 발송·이벤트·회비유형 코드체계·SILVER 컬럼 매핑 확인 | §5-A `DIM_SERVICE`·`DIM_EVENT`·`DIM_PAYMENT` — 🟡우리끼리 잠정(02 §3 게이트) |
| REGION·AGE_BAND SILVER projection 편입 확인 | §5-A(해소분, projection만 잔여) |
| ✅ERP 적재됨(2,041행) → 실측 검토(02 §3) | `DIM_BUDGET_ITEM`·`FACT_BUDGET`(편성/집행) 착수 가능 / `FACT_TARGET_BIZ`(사업목표)·모금성비용은 **원천 부재**(33 E-6) |
| ✅AGENCY 3테이블 적재됨 → 실측 검토(02 §3) | `DIM_AD_CREATIVE`·`FACT_AD_PERFORMANCE` — 유형별 정제→UNION·`_SOURCE_SYSTEM`·인입콜 캐스팅·캠페인 이름매칭 게이트 |
| ~~ADMIN 입고~~ ❌제외 확정 | `FSE.APP_PUSH_*`·`FEP.VIEW_CNT` **컬럼 삭제**(2026-07-09, 내년 재추가). 행사기간/참여경로/채널은 CRM-backed 유지(§4) |
| GOLD 타입 정밀화(정본 06_지표용어사전) | `07_메타.md` PENDING과 동일 |

이후 단계: SILVER → GOLD 적재 INSERT 구현 및 Semantic View 매핑.

---

*문의: 조인환 프로*
*Co-authored
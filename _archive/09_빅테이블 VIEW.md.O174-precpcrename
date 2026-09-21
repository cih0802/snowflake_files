<!-- LLM-METADATA
doc_id: GOLD_WIDE_VIEWS
doc_role: consumption_wide_view (GOLD 빅테이블 뷰 14종 통합 정의서)
project: GN_DW (굿네이버스)
derived_from: 10_dbt_pipeline/models/gold/wide/*.sql + _wide_schema.yml
generator: scripts/build_wide_doc.py
validator: scripts/verify_wide_doc.py
structure: WIDE VIEW 14종 전수 수록 (개요 + 조인 로직 + 확장 컬럼 정의서)
status: 🟢 정본 최신화 완료 (물리 dbt 뷰 14종 100% 일치)
updated: 2026-09-14
END-METADATA -->

# GOLD 빅테이블 VIEW (Wide View) 통합 정의서

> **문서 목적**: GN_DW GOLD 계층에 배포된 **비정규화 리포팅 뷰(WIDE VIEW 14종)**의 통합 설계 및 컬럼 정의서입니다.
> 리포팅 및 BI, Semantic View, Cortex Agent 조회 성능과 편의성을 위해 **Fact 테이블과 Dimension 테이블을 LEFT JOIN으로 평탄화**한 구조를 표준화된 양식으로 제공합니다.
> 
> 🟢 **물리 정본 위치**: `10_dbt_pipeline/models/gold/wide/*.sql` (dbt view 모델 14종) 및 `_wide_schema.yml`
> 🛠️ **자동 생성/동기화 도구**: `python3 scripts/build_wide_doc.py` (dbt 모델 변경 시 이 정의서를 자동 갱신)
> 🔍 **정합성 전수 검증 게이트**: `python3 scripts/verify_wide_doc.py` (Live Snowflake ↔ dbt SQL ↔ 이 문서 간 575컬럼 100% 일치 검증)
> 📊 **자동 계보 매핑 산출물**: `30_output_share/04_컬럼계보매핑.md` (BRONZE→SILVER→GOLD→WIDE 역방향 실측 계보)

---

## 1. 아키텍처 및 공통 설계 원칙

| 설계 항목 | 공통 표준 규칙 | 비즈니스 목적 및 효과 |
|---|---|---|
| **조인 방향** | 전부 **LEFT JOIN** (Fact 중심) | Fact 테이블의 실적 행 유실을 방지하고, 미매칭 차원 키는 `(미매핑)` 또는 NULL로 보존 |
| **SCD2 회원 Dedup** | `DIM_MEMBER_STATUS_HISTORY` 조인 시 `IS_CURRENT = TRUE` + 최신 1행 서브쿼리 | 회원 상태 이력 다중 버전으로 인한 팩트 행 증폭(Fan-out)을 원천 차단 |
| **조직 조인 (DIM_ORG)** | `ORG_SK` 직결 조인 (SCD1 current-value) | 팩트 발생 시점의 부서 식별을 유지하되 최신 부서명·계층 체계로 일관성 제공 |
| **시간/날짜 파생** | 월 grain은 `FLOOR(MONTH_KEY/100)`, `MOD(MONTH_KEY,100)` 파생 / 일 grain은 `DIM_DATE` 조인 | 일자 fan-out 방지 및 연도·월별 집계 편의성 제공 |
| **라벨 전파** | 원천 시스템 코드(`*_CD`)와 함께 표준 한글/영문 분석 라벨(`*_NAME`, `*_NM`) 동시 제공 | 현업이 별도 코드표를 찾지 않고도 즉시 대시보드 및 리포트 작성 가능 |
| **감사 컬럼** | 팩트 `DW_SOURCE_SYSTEM`을 유지하여 원천 시스템 역추적 지원 | 다중 원천 적재 시 시스템별 데이터 추적성 확보 |

---

## 2. WIDE VIEW 14종 상세 정의서

### 2.1 `WIDE_MEMBER_MONTHLY` — 회원 월별 실적 평탄화 뷰 (Member Monthly Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 회원×월 단위 집계 실적(청구·납입·미납·활동·개발·중단)과 회원 현재 속성 및 마스터 코드 라벨을 결합한 통합 분석용 뷰
- **분석 Grain**: `월(MONTH_KEY) × 회원(MEMBER_DK)`
- **기준 Fact 테이블**: `GOLD.FACT_MEMBER_MONTHLY (f)`
- **조인 Dimension 테이블**: 5개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_MEMBER_MONTHLY (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK`
  - `LEFT JOIN GOLD.DIM_PAYMENT (p) ON f.PAYMENT_SK = p.PAYMENT_SK`
  - `LEFT JOIN GOLD.DIM_REASON (r) ON f.REASON_SK = r.REASON_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **월키(YYYYMM)** | `MONTH_KEY` | NUMBER | NO | GOLD.FACT_MEMBER_MONTHLY (f) | YYYYMM |
| **연도(YYYY)** | `CAL_YEAR` | NUMBER | YES | 파생 (DERIVED 계산식) | FLOOR(MONTH_KEY/100) — 연도 |
| **월(MM)** | `CAL_MONTH` | NUMBER | YES | 파생 (DERIVED 계산식) | MOD(MONTH_KEY,100) — 월 |
| **회원식별키(DK)** | `MEMBER_DK` | TEXT | NO | GOLD.FACT_MEMBER_MONTHLY (f) | 불변 회원키(조인용) |
| **개발건수** | `DEV_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 개발(건) SUM(금액)/10000 (#4·5·149) |
| **개발회원수(플래그)** | `DEV_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 개발(명) COUNT (#148) |
| **중단건수** | `STOP_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 중단(건) (#35, FME 롤업) |
| **미납** | `UNPAID_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 미납(건) (#36) |
| **활동건수** | `ACTIVE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 활동(건) (#37·157) |
| **활동회원수** | `ACTIVE_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 활동(명) (#156) |
| **활동누계** | `ACTIVE_CUM_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 활동누계(건) (#159) |
| **활동누계** | `ACTIVE_CUM_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 활동누계(명) (#158) |
| **증액건수** | `INCREASE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 증액(건) (#151) |
| **증액** | `INCREASE_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 증액(명) (#150) |
| **감액건수** | `DECREASE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 감액(건) SUM(감액금액)/10000 (#38) |
| **이탈건수** | `CHURN_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 이탈(건) SUM(취소+감액)/10000 (신규#20) |
| **연도초 활동회원** | `YEAR_START_ACTIVE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 연도초 활동회원(건) (#49) |
| **연도말 활동회원** | `YEAR_END_ACTIVE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 연도말 활동회원(건) (#50) |
| **월말활동회원** | `MONTH_END_ACTIVE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 월말활동회원(건) (#52) |
| **전월말 활동회원** | `PREV_MONTH_END_ACTIVE_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 전월말 활동회원(건) (#53) |
| **캠페인별 미납** | `CAMPAIGN_UNPAID_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 캠페인별 미납(건) (#83) |
| **회원상태별 미납** | `STATUS_UNPAID_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 회원상태별 미납(건) (#84) |
| **정기회비(원)** | `REGULAR_FEE` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 정기회비(원) (#66) |
| **정기회원 일시회비** | `REGULAR_ONETIME_FEE` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 정기회원 일시회비(원) (#67) |
| **일시회원 일시회비** | `ONETIME_ONETIME_FEE` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 일시회원 일시회비(원) (#68) |
| **납입회비(원)** | `PAID_FEE` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 납입회비(원) (#69·70 단일화) |
| **청구회비(원)** | `BILLED_AMT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 청구(원) (#71) |
| **인바운드콜수** | `INBOUND_CALL_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 인바운드콜수 (overview) |
| **TS콜수** | `TS_CALL_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | TS콜수 (overview) |
| **개발구분** | `DEV_TYPE` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 개발구분 (#121) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.DEV_TYPE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **신규여부** | `NEW_FLAG` | BOOLEAN | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 신규여부 (#32) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **증액여부** | `INCREASE_FLAG` | BOOLEAN | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 증액여부 (#33) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.INCREASE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **재후원여부** | `REDONATE_FLAG` | BOOLEAN | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 재후원여부 (#34) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.REDONATE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인 가입일** | `JOIN_DATE` | DATE | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 캠페인 가입일 (#27) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.JOIN_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_FIRST_JOIN_DATE`(DIM_MEMBER 경유). |
| **가입캠페인 중단일** | `STOP_DATE` | DATE | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 가입캠페인 중단일 (#26) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.STOP_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT. |
| **후원금액대1 5만** | `AMOUNT_BAND1` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원금액대1 5만 (#72) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **후원금액대2 1만** | `AMOUNT_BAND2` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원금액대2 1만 (#73) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **후원기간대1 5년** | `PERIOD_BAND1` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원기간대1 5년 (#74) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **후원기간대2 1년** | `PERIOD_BAND2` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원기간대2 1년 (#75) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **후원기간** | `SPONSOR_MONTHS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원기간(개월) (#127) |
| **후원기간** | `SPONSOR_YEARS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 후원기간(년) (#128) |
| **납입개월수** | `PAID_MONTHS` | NUMBER | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 납입개월수 (#129) |
| **신규/기존** | `NEW_EXISTING_FLAG` | TEXT | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 신규/기존(시점귀속, #113) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **월초 미납회원 여부** | `UNPAID_FLAG_BOM` | BOOLEAN | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 월초 미납회원 여부(=전월말 상태, #80) |
| **월말 미납회원 여부** | `UNPAID_FLAG_EOM` | BOOLEAN | YES | GOLD.FACT_MEMBER_MONTHLY (f) | 월말 미납회원 여부 (#80) |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_MEMBER_MONTHLY (f) | 원천 시스템 식별 |
| **SEX** | `SEX` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · 실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. ⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. 라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **SEX_NM** | `SEX_NM` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. CM013 은 코드와 라벨이 1:1 이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_GENDER_NAME** | `MEMBER_GENDER_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_AREA_CD** | `MEMBER_AREA_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원지역** | `MEMBER_REGION` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128). |
| **MEMBER_AGE_CD** | `MEMBER_AGE_CD` | NUMBER | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원연령대** | `MEMBER_AGE_BAND` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128). |
| **MBER_STAT_CD** | `MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_STATUS_NAME** | `MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **PREV_MBER_STAT_CD** | `PREV_MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.PREV_MBER_STAT_CD — 상태전이의 **이전상태** 코드 raw(MM010). 현재상태 MBER_STAT_CD 와 짝지어 전이를 표현한다. 원천 `TH_MM_FDRM_MBER_STNG_DTLS.BF_STAT_CD` 에 **사전 전종이 등장**한다. ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — '이전상태가 없다'가 아니라 '이력이 없다'. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실). 라벨 = PREV_MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **PREV_MEMBER_STATUS_NAME** | `PREV_MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.PREV_MEMBER_STATUS_NAME — 이전상태명(MM010 라벨). 코드 = PREV_MBER_STAT_CD. 사전과 실적재가 일치한다. 이력 미보유행은 NULL. 🔷(PREV_MEMBER_STATUS_NAME → MEMBER_STATUS_NAME) 쌍이 전이 매트릭스의 두 축이다 — 이 버전행 자체가 전이 사건이므로 fan-out 0. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MBER_DIV_CD** | `MBER_DIV_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_TYPE_NAME** | `MEMBER_TYPE_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **최초가입일자** | `MEMBER_FIRST_JOIN_DATE` | DATE | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.FIRST_JOIN_DATE — 최초가입일 (#28) |
| **최초가입캠페인** | `MEMBER_FIRST_CAMPAIGN` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.FIRST_CAMPAIGN — 최초캠페인 (#29) |
| **JOIN_PATH_CD** | `JOIN_PATH_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.JOIN_PATH_CD — 가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** ⇒ 가입경로 분포에서 이 두 값을 기대하지 말 것. 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = MEMBER_ENROLL_PATH_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_ENROLL_PATH_NAME** | `MEMBER_ENROLL_PATH_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **최초후원사업** | `MEMBER_FIRST_SPONSORSHIP` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.FIRST_SPONSORSHIP — 최초후원사업 |
| **MEMBER_LAST_STOP_DATE** | `MEMBER_LAST_STOP_DATE` | DATE | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.LAST_STOP_DATE — 최종 중단일. 원천 BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE. 🔴**그 버전 시점까지의 as-of max** 다(전체 단순 max 가 아니다). 단순 max 는 미래 정보를 과거 버전에 누설해 예측 피처(LTV·유지기간)를 오염시킨다. ⚠️중단 이력이 없는 회원·중단 이전 버전은 NULL 이며 '중단하지 않았다'와 '이력이 없다'를 구분하지 않는다. 🔴이 뷰의 STOP_DATE(월 팩트 measure)와 다른 축이다. |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **상위캠페인** | `CAMPAIGN_PARENT` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **홍보방법** | `CAMPAIGN_PROMO_METHOD` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인유형** | `CAMPAIGN_TYPE` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **후원사업코드(BK)** | `SPONSORSHIP_BK` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **후원사업약칭** | `SPONSORSHIP_ABBR` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. 🟢[2026-08-19 O89] 이 컬럼은 **코드(1~6)** 이고 라벨은 SPONSORSHIP_GROUP_NAME 이다 — 코드사전 CM003(후원약칭)으로 특정됐다(SPB-G 종결). |
| **SPONSORSHIP_DIV_NAME** | `SPONSORSHIP_DIV_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🔴🔴 이 뷰에서는 `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 가 **전건 센티넬(0)** 이라 이 라벨도 `'(미매핑)'` 이다 — 분류별 분해는 `WIDE_MEMBER_FEE`(거의 전건 채움) 또는 `WIDE_MEMBER_EVENT`(DEV 브랜치 배선)를 쓸 것. 센티넬 원인은 O8(다중후원·다중캠페인 귀속 규칙 현업 미회신)이다. |
| **SPONSORSHIP_GROUP_NAME** | `SPONSORSHIP_GROUP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. 🔴🔴 이 뷰에서는 팩트 FK 가 전건 센티넬이라 `'(미매핑)'` 이다(위 DIV_NAME 주석과 동일). |
| **결제방법** | `PAYMENT_METHOD` | TEXT | YES | GOLD.DIM_PAYMENT (납입/결제수단 차원) | DIM_PAYMENT.PAYMENT_METHOD — 납입방식 (#125) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.PAYMENT_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **정산방식** | `PAYMENT_SETTLE_METHOD` | TEXT | YES | GOLD.DIM_PAYMENT (납입/결제수단 차원) | DIM_PAYMENT.SETTLE_METHOD — 결제방식 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **회비구분** | `PAYMENT_FEE_TYPE` | TEXT | YES | GOLD.DIM_PAYMENT (납입/결제수단 차원) | DIM_PAYMENT.FEE_TYPE — 회비유형(정기/일시) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. ⚠️게다가 `DIM_PAYMENT.FEE_TYPE` 자체도 전건 비어 있다(이중 결손). |
| **사유코드** | `REASON_CODE` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_CODE — 사유코드 |
| **사유명** | `REASON_NAME` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_NAME — 중단사유·미납사유 (#162·#82) |
| **사유유형** | `REASON_TYPE` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_TYPE — 중단/미납 구분 |

---

### 2.2 `WIDE_MEMBER_EVENT` — 회원 개발/중단 이벤트 평탄화 뷰 (Member Event Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 회원의 가입, 증액, 감액, 재후원, 후원중단 등 상태전이 사건(Event)에 일자·회원·캠페인·사업·부서·사유 차원을 결합한 사건 추적 뷰
- **분석 Grain**: `사건일(DATE_SK) × 회원(MEMBER_DK) × 개발구분(DVLP_DIV_CD)`
- **기준 Fact 테이블**: `GOLD.FACT_MEMBER_EVENT (f)`
- **조인 Dimension 테이블**: 6개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_MEMBER_EVENT (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK`
  - `LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (개발 사건 당시 소속 부서 기준)`
  - `LEFT JOIN GOLD.DIM_REASON (r) ON f.REASON_SK = r.REASON_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **일자키(YYYYMMDD)** | `DATE_SK` | NUMBER | NO | GOLD.FACT_MEMBER_EVENT (f) | 사건일 YYYYMMDD |
| **회원식별키(DK)** | `MEMBER_DK` | TEXT | NO | GOLD.FACT_MEMBER_EVENT (f) | 상태전이 대상 회원 (불변키) |
| **상태전이 유형** | `EVENT_TYPE` | TEXT | NO | GOLD.FACT_MEMBER_EVENT (f) | 상태전이 유형(개발/중단/증액/미납중단) |
| **DVLP_DIV_CD** | `DVLP_DIV_CD` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.DVLP_DIV_CD — 개발구분 코드 raw. 코드그룹 **MM015(개발구분)**. 코드사전 = 1신규·2증액·3감액·4재후원·5후원중단. 실적재(TM_MM_FDRM_MBER_DVLP_AMT.DVLP_DIV_CD)에 **사전 전종이 등장**한다. 🔴MM015 는 회원상태 MM010 이 **아니다** — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다(회원상태는 MBER_STAT_CD). ⚠️중단원천(EVENT_TYPE='STOP') 행은 원천에 이 컬럼이 부재해 NULL 이다. 라벨 = DVLP_DIV_NM. |
| **DVLP_DIV_NM** | `DVLP_DIV_NM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.DVLP_DIV_NM — 개발구분명(MM015 라벨): 신규·증액·감액·재후원·후원중단. 코드 = DVLP_DIV_CD. MM015 는 폐지코드가 없고 실적재가 사전과 일치한다. 🔴🔴값 '후원중단' 은 EVENT_TYPE='STOP' 과 **동일 사건이 거의 전부 중복 존재**한다(동일 회원·일자) — 두 축을 합산하면 이중계상이다(O24 · 현업확인 대기). |
| **SPNSR_AMT** | `SPNSR_AMT` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.SPNSR_AMT — 후원금액(원) raw. 원천 TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT 무변환 전파. 🔴감액·후원중단 사건은 **음수**다 — 무조건 SUM 하면 개발금액이 상계된다. 🔴정본 공#38 감액(건)·#151 증액(건)이 **금액을 만원 단위로 나눈 값**이라는 규약이므로 원금액을 보존한다(설계 §1·CONF-2) — 이 컬럼을 그대로 '건수'로 쓰지 말 것. ⚠️중단원천 행은 NULL. |
| **개발건수** | `DEV_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 개발(건) (#149) |
| **개발회원수(플래그)** | `DEV_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 개발(명) (#148) |
| **중단건수** | `STOP_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 중단(건) (#35) |
| **중단회원수(플래그)** | `STOP_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 중단(명) |
| **미납중단건수** | `UNPAID_STOP_CNT` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 미납중단(건) |
| **미납중단회원수** | `UNPAID_STOP_MEMBERS` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | 미납중단(명) |
| **JOIN_DATE** | `JOIN_DATE` | DATE | YES | GOLD.FACT_MEMBER_EVENT (f) | 가입일 |
| **STOP_DATE** | `STOP_DATE` | DATE | YES | GOLD.FACT_MEMBER_EVENT (f) | 중단일 |
| **STOP_REASON** | `STOP_REASON` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 중단사유 |
| **STOP_CHANNEL** | `STOP_CHANNEL` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 중단채널 |
| **STOP_REASON_NM** | `STOP_REASON_NM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.STOP_REASON_NM — 중단사유명(정본 공#162). 코드그룹 **MM005(후원중단사유)**. 코드 = STOP_REASON. 코드사전에는 **폐지코드(USE_YN='N')가 다수 섞여** 있고 실적재는 사전의 일부만 쓴다. 최빈 코드 = 1개인(경제적)사유 · 14장기미납 · 16신규미납 · 8다른곳지원. 🔴🔴**USE_YN 필터 금지** — 실적재에 **폐지코드가 실재**한다(26은행자동납부해지 · 13반송미납 · 21~25 지라니 계열) ⇒ USE_YN='Y' 로 걸면 그 행들의 라벨이 사라진다. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️사전에만 있고 실적재에 없는 코드도 다수다. |
| **STOP_CHANNEL_NM** | `STOP_CHANNEL_NM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.STOP_CHANNEL_NM — 중단경로명. 코드그룹 **MM287(중단경로)**. 코드 = STOP_CHANNEL. 코드사전 = 1 SYSTEM · 2 CRM · 3 홈페이지 · 실적재에 **사전 전종이 등장**한다. ⚠️'SYSTEM' 은 배치가 자동 처리한 중단(장기미납 등)이며 회원의 능동적 해지 채널이 아니다 — 채널 분석 시 분리할 것. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️215지표 밖 — 현업 수요 확인 대상(O25). |
| **NEW_EXISTING_FLAG** | `NEW_EXISTING_FLAG` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 신규기존 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_EVENT.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **AGE_AT_EVENT** | `AGE_AT_EVENT` | NUMBER | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.AGE_AT_EVENT — 연령대 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM014**. 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 사건행별 값을 무변환 전파한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지(1'10대 미만'~9'70대 이상'·10단체·11기업·12기타). 🔴MEMBER_AGE_CD(=현재버전 경유 '최근 약정' 스냅샷)와 **다른 축**이며 같은 회원도 사건마다 값이 다를 수 있다 — 이 컬럼이 그 사건 당시의 정확값이다. ⚠️중단원천 행은 원천 컬럼 부재로 NULL(0 아님, P21). 라벨 = AGE_BAND_AT_EVENT. |
| **AGE_BAND_AT_EVENT** | `AGE_BAND_AT_EVENT` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.AGE_BAND_AT_EVENT — **사건 시점** 연령대명(CM014 사전 조인, 하드코딩 아님 P31). 코드 = AGE_AT_EVENT. ✅'10대 미만'이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 🔴MEMBER_AGE_BAND(현재버전 스냅샷)와 값이 다를 수 있다. 중단원천 행은 NULL. |
| **AREA_CD_AT_EVENT** | `AREA_CD_AT_EVENT` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.AREA_CD_AT_EVENT — 지역 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM018**(지표 공#131). 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD` 무변환 전파 · 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. 🔴MEMBER_AREA_CD(현재버전 경유 최근 약정 스냅샷)와 **다른 축** — 이사 등으로 사건마다 값이 다를 수 있다. ⚠️**현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가(O34). ⚠️중단원천 행은 원천 컬럼 부재로 NULL. 라벨 = REGION_AT_EVENT. |
| **REGION_AT_EVENT** | `REGION_AT_EVENT` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | FACT_MEMBER_EVENT.REGION_AT_EVENT — **사건 시점** 지역명(CM018 약칭 라벨, 지표 공#131). 코드 = AREA_CD_AT_EVENT. ⚠️센티넬 코드 '0' 은 사전에 라벨이 없어 NULL 이다 — '미상'으로 창작하지 않는다. ⚠️**현재 거주지가 아니다**(O34). 🔴MEMBER_REGION(현재버전 스냅샷)과 값이 다를 수 있다. 중단원천 행은 NULL. 🟢이 뷰 안에 캠페인 축이 함께 있어 지역 × 캠페인 교차가 성립한다. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_MEMBER_EVENT (f) | 원천 시스템 식별 |
| **전체일자** | `FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실제 일자 |
| **연도** | `YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 년 |
| **월** | `MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 월 |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.DAY_OF_WEEK — 요일 |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.WEEK_OF_YEAR — 주차 |
| **분기** | `QUARTER` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.QUARTER — 분기 |
| **휴일여부** | `IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 휴일여부 |
| **SEX** | `SEX` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · 실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. ⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. 라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **SEX_NM** | `SEX_NM` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. CM013 은 코드와 라벨이 1:1 이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_GENDER_NAME** | `MEMBER_GENDER_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_AREA_CD** | `MEMBER_AREA_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원지역** | `MEMBER_REGION` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128). |
| **MEMBER_AGE_CD** | `MEMBER_AGE_CD` | NUMBER | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원연령대** | `MEMBER_AGE_BAND` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128). |
| **MBER_STAT_CD** | `MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_STATUS_NAME** | `MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **PREV_MBER_STAT_CD** | `PREV_MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.PREV_MBER_STAT_CD — 상태전이의 **이전상태** 코드 raw(MM010). 현재상태 MBER_STAT_CD 와 짝지어 전이를 표현한다. 원천 `TH_MM_FDRM_MBER_STNG_DTLS.BF_STAT_CD` 에 **사전 전종이 등장**한다. ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — '이전상태가 없다'가 아니라 '이력이 없다'. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실). 라벨 = PREV_MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **PREV_MEMBER_STATUS_NAME** | `PREV_MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.PREV_MEMBER_STATUS_NAME — 이전상태명(MM010 라벨). 코드 = PREV_MBER_STAT_CD. 사전과 실적재가 일치한다. 이력 미보유행은 NULL. 🔷(PREV_MEMBER_STATUS_NAME → MEMBER_STATUS_NAME) 쌍이 전이 매트릭스의 두 축이다 — 이 버전행 자체가 전이 사건이므로 fan-out 0. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MBER_DIV_CD** | `MBER_DIV_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_TYPE_NAME** | `MEMBER_TYPE_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **JOIN_PATH_CD** | `JOIN_PATH_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.JOIN_PATH_CD — 가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** ⇒ 가입경로 분포에서 이 두 값을 기대하지 말 것. 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = MEMBER_ENROLL_PATH_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_ENROLL_PATH_NAME** | `MEMBER_ENROLL_PATH_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) |
| **상위캠페인** | `CAMPAIGN_PARENT` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) |
| **홍보방법** | `CAMPAIGN_PROMO_METHOD` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) |
| **CAMPAIGN_CATEGORY** | `CAMPAIGN_CATEGORY` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. ⚠️ 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 코드사전 미등재 코드가 실재해 그 행은 라벨이 비고, 미채움 행도 있다(규모는 이슈원장 참조). ⚠️ **사전 자체에 동일 라벨 중복**이 있어 라벨로 GROUP BY 하면 두 코드가 합쳐진다. ⚠️ 업무용어는 '카테고리'이고 상위캠페인은 CAMPAIGN_PARENT 다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_CTGR_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_INFLOW_PATH** | `CAMPAIGN_INFLOW_PATH` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. 🔴 이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다**(O37) — 모집 채널이다. 캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MBER_INFLOW_PATH_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_DOMESTIC_OVERSEAS** | `CAMPAIGN_DOMESTIC_OVERSEAS` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 캠페인 국내/통합/해외 라벨. 코드그룹 **MM295**. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE1_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_BIZ_CASE_TYPE** | `CAMPAIGN_BIZ_CASE_TYPE` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 캠페인 굿즈/기타/사례/사업 구분 라벨. 코드그룹 **MM296**. ⚠️ CAMPAIGN_DOMESTIC_OVERSEAS(유형1=국내/해외 축)와 다른 축이다 — 혼동 금지. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE2_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **마케팅캠페인명 라벨** | `CAMPAIGN_MARKETING_CAMPAIGN` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 마케팅캠페인명 라벨(Q16 해소). 🔴 광고비 결합은 이 라벨이 아니라 MKTG_CAMPAIGN_SK(FK)를 쓴다 — 라벨로 결합하면 안 된다(O44/O45). 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_CMPGN_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_CMMN_BRND** | `CAMPAIGN_CMMN_BRND` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 공통브랜드 라벨. 코드그룹 **MM297**. ⚠️ 라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지한다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMMN_BRND_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_MKTG_UTM** | `CAMPAIGN_MKTG_UTM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | UTM 라벨. 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. ⚠️ 원천 미등재 코드가 많아 라벨 채움이 낮다 — **결측이 아니라 미등재**다. 🔴 채움 비율은 규칙7 상 여기 적지 않는다(재적재마다 stale 이 된다) ⇒ 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_UTM_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_SPNSR_DIV_CD** | `CAMPAIGN_SPNSR_DIV_CD` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 세부캠페인 후원구분 원천코드. 코드그룹 **CM035**: 1=정기후원 · 2=일시후원. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_SPNSR_DIV_NM. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_SPNSR_DIV_NM** | `CAMPAIGN_SPNSR_DIV_NM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | CAMPAIGN_SPNSR_DIV_CD 를 CM035 로 해소한 라벨(정기후원/일시후원). ⚠️ DIM_SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 **적용 대상이 다르다** — 이 컬럼은 세부캠페인 단위 구분이다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_CPR_DIV_CD** | `CAMPAIGN_CPR_DIV_CD` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | 세부캠페인 법인구분 원천코드. 코드그룹 **CM019**: A=통합 · I=사단 · S=사복. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_CPR_DIV_NM. 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — ORG_CORP 는 전건 비어 있고 이 축은 채워진다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **CAMPAIGN_CPR_DIV_NM** | `CAMPAIGN_CPR_DIV_NM` | TEXT | YES | GOLD.FACT_MEMBER_EVENT (f) | CAMPAIGN_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — 「법인별」 질문은 어느 축인지 먼저 가린다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`). |
| **후원사업코드(BK)** | `SPONSORSHIP_BK` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) |
| **SPONSORSHIP_DIV_NAME** | `SPONSORSHIP_DIV_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢DEV 브랜치는 O45 로 배선(3,594,843)이라 **분류별 개발실적 집계가 된다.** ⚠️STOP 브랜치는 `SPONSORSHIP_SK` 센티넬 0 이라 `'(미매핑)'` 이다 — 중단 분해는 개발원천 코드5 경로를 쓸 것(DEC-32 철회·O47). 🔴DEV·STOP 을 합산하면 이중계상이다(O24). |
| **SPONSORSHIP_GROUP_NAME** | `SPONSORSHIP_GROUP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️STOP 브랜치 센티넬은 위 DIV_NAME 주석과 동일. |
| **법인구분** | `ORG_CORP` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C. |
| **본부명** | `ORG_DIVISION` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C. |
| **부서명** | `ORG_DEPARTMENT` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 중단원천 행은 부서가 없다. 부서별 집계 시 이 그룹이 상위권 규모로 나타나며 **실재 부서가 아니다.** 실측 규모는 이슈원장 §O51-D-C. |
| **팀명** | `ORG_TEAM` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C. |
| **사유코드** | `REASON_CODE` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_CODE — 사유코드 |
| **사유명** | `REASON_NAME` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_NAME — 중단/미납사유 |
| **사유유형** | `REASON_TYPE` | TEXT | YES | GOLD.DIM_REASON (사유 차원) | DIM_REASON.REASON_TYPE — 중단/미납 구분 |

---

### 2.3 `WIDE_MEMBER_FEE` — 회비 분해 평탄화 뷰 (Member Fee Breakdown Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 후원사업·납입방식·결제수단별 회비 청구/납입 상세 팩트에 회원 1행 현재 속성 및 획득 코호트(DIM_MEMBER_ACQUISITION)를 결합한 재무 분석 뷰
- **분석 Grain**: `회원(MEMBER_DK) × 회비월(MONTH_KEY) × 후원사업 × 회비구분 × 납입유형 × 결제수단`
- **기준 Fact 테이블**: `GOLD.FACT_MEMBER_FEE (f)`
- **조인 Dimension 테이블**: 5개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_MEMBER_FEE (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK (납입 대상 후원사업)`
  - `LEFT JOIN GOLD.DIM_PAYMENT (p) ON f.PAYMENT_SK = p.PAYMENT_SK (결제수단 및 납입방식)`
  - `LEFT JOIN GOLD.DIM_DATE (dp) ON f.LAST_PAY_DATE_SK = dp.DATE_SK (최근 수납일자)`
  - `LEFT JOIN GOLD.DIM_MEMBER (mem) ON f.MEMBER_DK = mem.MEMBER_DK (회원 1행 현재 기준 속성)`
  - `LEFT JOIN GOLD.DIM_MEMBER_ACQUISITION (acq) ON f.MEMBER_DK = acq.MEMBER_DK (획득 시점 캠페인·부서·사업 코호트 귀속축)`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **월키(YYYYMM)** | `MONTH_KEY` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 회비월 YYYYMM (무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 — FMM 과 동일 규칙) |
| **연도(YYYY)** | `CAL_YEAR` | NUMBER | YES | 파생 (DERIVED 계산식) | FLOOR(MONTH_KEY/100) — 연도 |
| **월(MM)** | `CAL_MONTH` | NUMBER | YES | 파생 (DERIVED 계산식) | MOD(MONTH_KEY,100) — 월 |
| **회원식별키(DK)** | `MEMBER_DK` | TEXT | YES | GOLD.FACT_MEMBER_FEE (f) | 회원 자연키(= 팩트 조인키, FK→DIM_MEMBER.MEMBER_DK). 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측. 🔴기부금 지류(BRONZE_CRM.TM_PM_DNTN_DTLS)에는 MBER_NO 컬럼이 **아예 없다**(회원키가 ONCE_MBER_NO) — 기부금 행의 회원 축은 구조적으로 부재하다. ⚠️FMM 규약과 일치시키기 위해 MBER_NO IS NOT NULL 을 적용한다(O45-C). |
| **SPONSORSHIP_SK** | `SPONSORSHIP_SK` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 🔴**납입 대상** 후원사업 대리키(FK→DIM_SPONSORSHIP) ← 원천 SPNSR_BSNS_ID. 0=미매핑. [O51-D 실측] **거의 전건 채움**이며 후원사업 종류는 수십 개다. 🔴획득 후원사업 ACQ_SPONSORSHIP_SK 와 **의미가 다르다** — 같은 라벨로 두 축이 존재한다. 이 축이 grain 에 들어간 것이 이 팩트를 FMM 과 분리한 이유다 — [O51-D 실측] 이 축을 붙이면 **회원-월 조합 수가 늘어 grain 이 깨진다**(증가율은 이슈원장 §O45·§O51-D). ⚠️인용 시 스코프를 함께 적을 것 — 종전 수치는 **BRONZE 회비 지류만**(MBER_NO not null) 스코프여서 분모가 다르다. |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | 🔴**납입 대상** 후원사업 — 회비 행에 붙은 값이다(원천 SPNSR_BSNS_ID · 거의 전건 채움). 획득 후원사업(ACQ_SPONSORSHIP_NAME)과 다르다: 한 회원이 여러 후원사업에 낸다. 🔴이 축을 grain 에 넣으면 회원-월 조합 수가 늘어난다 — 그것이 이 팩트를 FMM 과 분리한 이유다(증가율 실측은 이슈원장 §O45·§O51-D). |
| **SPONSORSHIP_DIV_NAME** | `SPONSORSHIP_DIV_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 납입 대상 후원사업 분류의 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢**이 뷰가 분류 집계의 정본 경로다** — `SPONSORSHIP_SK` 가 거의 전건 채움이라 FMM(전건 센티넬)과 달리 실제 분해가 된다. ⚠️획득 후원사업 축(ACQ_*)과 다른 축이다 — 같은 표에서 섞지 말 것. |
| **SPONSORSHIP_GROUP_NAME** | `SPONSORSHIP_GROUP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | [2026-08-19 O89] 납입 대상 후원사업 분류의 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️인용 시 스코프 병기 — 기부금 지류는 회비구분이 구조적으로 부재하다(O40). |
| **FEE_DIV_CD** | `FEE_DIV_CD` | TEXT | YES | GOLD.FACT_MEMBER_FEE (f) | 회비구분 코드 raw. 코드그룹 **PM010(회비구분)**. [O51-D BRONZE 실측] 사전 4종이며 **숫자가 아니라 알파벳 코드**다 — E정기·I일시·U긴급구호·G선물금. 실적재에 **사전 전종이 등장**하며 **E(정기)가 압도적**이다. 🔴기부금 행은 원천에 이 컬럼이 없어 NULL 이다 — **결측이 아니라 해당없음**(P21). 라벨 = FEE_DIV_NAME. |
| **회비구분** | `FEE_DIV_NAME` | TEXT | YES | GOLD.FACT_MEMBER_FEE (f) | 회비구분(PM010 실측 확정): 정기·선물금·일시·긴급구호. 🔴기부금 행은 원천이 NULL 이다 — 결측이 아니라 해당없음(P21) |
| **PAYMENT_TYPE** | `PAYMENT_TYPE` | TEXT | YES | GOLD.FACT_MEMBER_FEE (f) | 납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프할 것 — 기부금은 원천에 청구(RQEST_AMT)가 전건 NULL 이라 분모에 들어갈 수 없다(O40) |
| **결제수단 대리키** | `PAYMENT_SK` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 결제수단 대리키(FK→DIM_PAYMENT) ← SETLE_CD 를 gold_sk 로 해싱. 0=미매핑. ⚠️라벨 커버리지가 완전하지 않다 — 원본 코드는 SETLE_CD 로 보존한다. 🟢[O51-D 실측] 미매핑 원인이 규명됐다 — DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 만으로 만들어지는데 회비 원천에는 **마스터에 없는 코드가 존재**한다. 사전(PM040) 기준으로 만들면 전건 라벨화된다(O45-B 처방). |
| **PAYMENT_METHOD_NAME** | `PAYMENT_METHOD_NAME` | TEXT | YES | GOLD.DIM_PAYMENT (납입/결제수단 차원) | DIM_PAYMENT.SETTLE_METHOD — 결제수단 라벨. 코드그룹 **PM040(결제정보)**. 원본 코드는 SETLE_CD. [O51-D BRONZE 실측 2026-08-07] 🟢**O45-B(코드그룹 미특정)가 해소됐다** — SETLE_CD 의 코드그룹은 PM040 이고 회비 원천 실적재 값(1자동이체·2신용카드·3신용카드즉시·4회비통장·5휴대폰·6휴대폰즉시·7MICR·8OCR·10실시간계좌이체·12네이버페이·13가상계좌즉시)이 **전부 PM040 사전에 존재**한다. 🔴미매핑 원인은 코드그룹 부재가 아니라 **DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 로만 만들어지고 그 마스터에 이 5종이 없다**는 것이다 ⇒ 처방 = DIM_PAYMENT 를 PM040 사전 기준으로 생성(재배선은 O51-D 범위 밖·별건 미결). 미라벨 행은 **코드는 있으나 차원에 행이 없는 5종(3·6·7·10·13)** 과 **SETLE_CD 자체가 NULL 인 행** 으로 나뉜다(규모는 이슈원장 §O45·§O51-D). ⚠️종전 문안의 *'코드그룹 미특정 · 6개 그룹이 전부 의미 무관'* 은 이 실측으로 폐기한다. |
| **degenerate key** | `SETLE_CD` | TEXT | YES | GOLD.FACT_MEMBER_FEE (f) | degenerate key: 결제수단 원본 코드 ← 원천 SETLE_CD(코드그룹 **PM040 결제정보**). 차원 라벨이 없는 코드를 잃지 않기 위해 보존한다. [O51-D 실측] 회비 원천 실적재 값 = 1자동이체 · 2신용카드 · 12네이버페이 · 8OCR · 4회비통장 · 3신용카드즉시 · 5휴대폰 · 10실시간계좌이체 · 6휴대폰즉시 · 13가상계좌즉시 · 7MICR (앞쪽이 최빈). 🟢**실적재 전종이 PM040 사전에 라벨을 갖는다** — 라벨화 공백은 코드 미상이 아니라 DIM_PAYMENT 생성 소스 문제다(O45-B 해소, 상세는 PAYMENT_METHOD_NAME). |
| **LAST_PAY_DATE_SK** | `LAST_PAY_DATE_SK` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 해당 조합의 **최종 납입일** (FK→DIM_DATE). 🔴합계가 아니라 시점 축이다. FMM 은 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 뷰에서만 답한다 |
| **최종 납입일** | `LAST_PAY_DATE` | DATE | YES | GOLD.DIM_DATE (최근 수납일자) | 최종 납입일(달력일) ← DIM_DATE.FULL_DATE, 키는 LAST_PAY_DATE_SK. 🔴시점 축이며 합계가 아니다 — 이 컬럼으로 GROUP BY 하면 회비월(MONTH_KEY)과 다른 분포가 나온다(납입 지연·선납 때문). 「기준일(납입일) 기준 조회」 요구는 이 컬럼으로 답하고, 「회비월 기준」은 MONTH_KEY 로 답한다. ⚠️미납 조합은 납입일이 없어 NULL. |
| **해당 조합의 최종 청구일 대리키** | `LAST_BILL_DATE_SK` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 해당 조합의 최종 청구일 대리키(FK→DIM_DATE) ← 원천 RQEST_DE. 0=캘린더 범위밖·무효. 🔴시점 축이며 합계가 아니다. ⚠️최종 청구일만 보존하므로 조합 내 여러 청구건의 개별 일자는 이 팩트에서 복원할 수 없다 — 청구 건별 분해가 필요하면 SILVER.CRM_PAYMENT_BILLING 을 쓴다. |
| **MBER_STAT_CD** | `MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · 실적재에 **사전 전종이 등장**한다. 🔴🔴**이 뷰의 미납 축(UNPAID_FLAG·UNPAID_BILLED_AMT)과 다른 개념**이다 — MM010 은 회원 **상태 코드**이고 미납 measure 는 **청구 실적**이다. 회원 단위 상태 기반 미납은 WIDE_MEMBER_MONTHLY 소관. 🔴현재버전 스냅샷이므로 과거 회비월에 현재 상태를 붙이면 시점이 어긋난다. 라벨 = MEMBER_STATUS_NAME. |
| **MEMBER_STATUS_NAME** | `MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다. 🔴현재버전 스냅샷이다. |
| **MBER_DIV_CD** | `MBER_DIV_CD` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**: 1개인·2기업·3단체. 실적재에 **사전 전종이 등장**한다 · 교차검증으로 `2`(기업)=`SEX 7` · `3`(단체)=`SEX 6` **완전 일치**. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 다른 축이다. 라벨 = MEMBER_TYPE_NAME. |
| **MEMBER_TYPE_NAME** | `MEMBER_TYPE_NAME` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다**. |
| **SEX** | `SEX` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전 = 1국내(남자)~5외국인(기타)·6단체·7기업·8기타 · 실적재에 **사전 전종이 등장**한다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축은 GENDER_NAME 을 쓴다. 🔴회원 **현재버전**(IS_CURRENT 1건) 스냅샷이며 회비월 시점 값이 아니다. 획득 시점 성별은 DIM_MEMBER_ACQUISITION.ACQ_SEX_CD. |
| **GENDER_NAME** | `GENDER_NAME` | TEXT | YES | GOLD.DIM_MEMBER (회원 1행 현재 기준) | DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. [O51-D BRONZE 실측] CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 🔴이 뷰에는 SEX_NM(국내·외국인 축)이 없다 — 그 축이 필요하면 WIDE_MEMBER_MONTHLY 를 쓴다. 🔴현재버전 스냅샷이다. |
| **ACQ_CAMPAIGN_SK** | `ACQ_CAMPAIGN_SK` | NUMBER | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_SK — **획득(가입) 캠페인** 대리키(FK→DIM_CAMPAIGN). 0=미매핑. 🔴회비를 낸 캠페인이 아니라 **이 회원을 데려온** 캠페인이다 — FMM/FMF 의 회비 자체에는 캠페인 축이 없어(전건 센티넬) 획득 시점 규칙으로 귀속시킨 것이다(O45·O8 우회). 🔴LEFT JOIN 필수 — 개발 사건이 없는 회원은 NULL 이다. 🔴🔴손실 규모는 **회원 기준으로 읽어야** 한다 — INNER 조인이 잃는 것은 회원이며, 행 가중 비율은 손실을 크게 축소해 보이게 한다(O51-D 정정 · 규모는 이슈원장 §O51-D). |
| **ACQ_BRAND** | `ACQ_BRAND` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 캠페인의 브랜드 ← DIM_CAMPAIGN.BRAND. 🔴획득 시점 귀속이며 회비 납입 대상과 무관하다. ⚠️획득 판정 근거가 FALLBACK(신규 사건 부재 → 최초 개발 사건 대체)인 회원은 신뢰도가 낮다 — 브랜드 비교는 DIM_MEMBER_ACQUISITION.ACQ_BASIS='NEW' 로 한정할 것을 권한다. |
| **ACQ_CAMPAIGN_NAME** | `ACQ_CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 캠페인명 ← DIM_CAMPAIGN.CAMPAIGN_NAME. 🔴획득 시점 귀속. ⚠️광고비와 결합할 때는 이 축이 아니라 ACQ_MARKETING_CAMPAIGN 을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃). |
| **ACQ_PARENT_CAMPAIGN_NAME** | `ACQ_PARENT_CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 캠페인의 **상위캠페인**명 ← DIM_CAMPAIGN.PARENT_CAMPAIGN_NAME (원천 UPPER_CMPGN_CD 계층). 🔴캠페인 카테고리(MM294)와 다른 축이다 — 카테고리는 코드 기반 분류, 상위캠페인은 캠페인 자체의 부모다. |
| **ACQ_PROMO_METHOD_NAME** | `ACQ_PROMO_METHOD_NAME` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 캠페인의 홍보방법명 ← DIM_CAMPAIGN.PROMO_METHOD_NAME. 코드그룹 **CM008(홍보방법)**. [O51-D BRONZE 실측] CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293)를 쓴다. |
| **획득 캠페인의 마케팅캠페인** | `ACQ_MARKETING_CAMPAIGN` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 캠페인의 마케팅캠페인(O45 conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃) |
| **ACQ_ORG_SK** | `ACQ_ORG_SK` | NUMBER | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | DIM_MEMBER_ACQUISITION.ACQ_ORG_SK — **획득 시점 담당조직** 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(WIDE_MEMBER_EVENT.ORG_*) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 두 값은 다르며 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(O34 규약). |
| **ACQ_DEPARTMENT** | `ACQ_DEPARTMENT` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 🔴**획득(최초개발) 시점 부서**다. 개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용) |
| **ACQ_SPONSORSHIP_SK** | `ACQ_SPONSORSHIP_SK` | NUMBER | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK — **획득 시점 후원사업** 대리키(FK→DIM_SPONSORSHIP). 0=미매핑. 🔴🔴같은 뷰의 SPONSORSHIP_SK(=회비 **납입 대상** 후원사업)와 **의미가 다르다** — 같은 라벨로 두 축이다. 한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다. |
| **ACQ_SPONSORSHIP_NAME** | `ACQ_SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 시점 후원사업명 ← DIM_SPONSORSHIP.SPONSORSHIP_NAME. 코드 = ACQ_SPONSORSHIP_SK. 🔴납입 대상 후원사업명(SPONSORSHIP_NAME)과 **다른 컬럼**이다 — 두 컬럼을 같은 표에 두면 반드시 혼동되므로 접두 ACQ_ 로 구분한다. |
| **획득 시점 연령대명** | `ACQ_AGE_BAND` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 시점 연령대명(**CM014** 라벨) ← FACT_MEMBER_COHORT.ACQ_AGE_BAND. 코드 = FMC.ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가(O34). 🔴연속형이 아니므로 평균·재구간화 금지. ✅'10대 미만'이 상위인 것은 오류가 아니다(편지쓰기대회 계열 아동 모집 캠페인) — 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 '70대'·'70대 이상'이 의미 중복으로 공존한다. |
| **획득 시점 지역명** | `ACQ_REGION` | TEXT | YES | GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축) | 획득 시점 지역명(**CM018** 약칭 라벨) ← FACT_MEMBER_COHORT.ACQ_REGION. 코드 = FMC.ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 코드 '0'(개발약정 실적재에 존재)은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다. |
| **청구회비(원)** | `BILLED_AMT` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 청구액(원) = SUM(RQEST_AMT). 🔴FMM 과 **동일한 식**이므로 두 팩트의 전체 합계가 일치해야 한다 — 이 일치가 검증 관문이다(GATE-D · 기준값은 이슈원장 §O45). 🔴🔴WIDE_MEMBER_MONTHLY 의 회비 measure 와 **같은 표에서 합산 금지**(DEC-31) — 동일 원천을 다른 grain 으로 담은 형제 팩트라 이중계상된다. |
| **납입회비(원)** | `PAID_FEE` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40) — PAID_FEE_BILLABLE 을 쓴다 |
| **회비 납입액** | `PAID_FEE_BILLABLE` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 회비 납입액(원) — 납부율 분자 정본(O40) |
| **미납 청구액** | `UNPAID_BILLED_AMT` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식(청구−납입) 아님. ⚠️조회 시점 스냅샷 — 과거 미납이 이후 납입되면 값이 바뀐다 |
| **BILLING_ROWS** | `BILLING_ROWS` | NUMBER | YES | GOLD.FACT_MEMBER_FEE (f) | 집계된 원천 회비행 수. 🔴금액이 아니다 — 「건수」로 쓰지 말 것(정본 (건) 정의는 CONF-2 미결) |
| **해당 조합에 미납 청구행이 하나라도 있는가** | `UNPAID_FLAG` | BOOLEAN | YES | GOLD.FACT_MEMBER_FEE (f) | 해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG). 회원 단위 미납 여부는 WIDE_MEMBER_MONTHLY 의 UNPAID_FLAG_EOM 을 쓴다 |

---

### 2.4 `WIDE_SERVICE_EVENT` — 메시지/서비스 발송 평탄화 뷰 (Message Dispatch Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 알림톡, 문자, 이메일, 우편 등 대고객 메시지 발송 팩트에 발송유형·서비스코드·회원·캠페인 차원을 결합한 발송 이력 뷰
- **분석 Grain**: `발송일(DATE_SK) × 회원(MEMBER_DK) × 발송유형(SEND_TYPE_SK)`
- **기준 Fact 테이블**: `GOLD.FACT_MESSAGE_DISPATCH (f)`
- **조인 Dimension 테이블**: 5개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_MESSAGE_DISPATCH (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)`
  - `LEFT JOIN GOLD.DIM_SEND_TYPE (st) ON f.SEND_TYPE_SK = st.SEND_TYPE_SK (발송 채널 및 유형)`
  - `LEFT JOIN GOLD.DIM_SERVICE (sv) ON f.SERVICE_SK = sv.SERVICE_SK (서비스 분류)`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **일자키(YYYYMMDD)** | `DATE_SK` | NUMBER | NO | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송일 YYYYMMDD |
| **회원식별키(DK)** | `MEMBER_DK` | TEXT | NO | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송 대상 회원 (불변키) |
| **발송수** | `SEND_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송수(명) (#85) |
| **성공수** | `SUCCESS_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 성공수(명) (#86) |
| **실패수** | `FAIL_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 실패수(명) (#87) |
| **오픈** | `OPEN_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 오픈(명) (overview) |
| **서신참여** | `LETTER_PART_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 서신참여(명) (#88) |
| **서신참여** | `LETTER_PART_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 서신참여(건) (#89) |
| **선물금참여** | `GIFT_PART_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 선물금참여(명) (#90) |
| **선물금참여** | `GIFT_PART_AMT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 선물금참여(원) (#91) |
| **D5_LETTER_PART_MEMBERS** | `D5_LETTER_PART_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 서신참여(명) (#139) |
| **D5_LETTER_PART_CNT** | `D5_LETTER_PART_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 서신참여(건) (#140) |
| **D5_GIFT_PART_MEMBERS** | `D5_GIFT_PART_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 선물금참여(명) (#141) |
| **D5_GIFT_PART_CNT** | `D5_GIFT_PART_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 선물금참여(건) (#142) |
| **D5_INCREASE_PART_MEMBERS** | `D5_INCREASE_PART_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 증액참여(명) (#143) |
| **D5_INCREASE_PART_CNT** | `D5_INCREASE_PART_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 증액참여(건) (#144) |
| **D5_STOP_MEMBERS** | `D5_STOP_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 중단(명) (#145) |
| **D5_STOP_CNT** | `D5_STOP_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | +5일차 중단(건) (#146) |
| **서비스** | `SERVICE_MEMBERS` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 서비스(명) (#160) |
| **서비스** | `SERVICE_CNT` | NUMBER | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 서비스(건) (#161) |
| **제목** | `SEND_TITLE` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 제목 (#136) |
| **발송상태** | `SEND_STATUS` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송상태 (#138) |
| **SEND_STATUS2** | `SEND_STATUS2` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송상태2 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.SEND_STATUS2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `SEND_STATUS`(대부분 채워져 있다). |
| **SEND_TYPE** | `SEND_TYPE` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 발송유형 |
| **축A** | `SEND_STATUS_GROUP` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 축A(채널상태) 코드군 ID (조인키 · MSG_AT→MS282). 🔴`SEND_STATUS` 는 채널별로 다른 코드체계가 한 컬럼에 모여 있다 — **`SEND_TYPE` 또는 이 컬럼 동반 필수**(단독 필터는 채널 간 오조인). EMAIL·SND·PSTMTR 은 NULL |
| **축A 라벨** | `SEND_STATUS_NAME` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 축A 라벨 (CRM_CODE 조인). 🔴EMAIL·SND 는 **의도적 NULL** — 코드값은 있으나 코드사전에 라벨 문자열이 없어 조인으로 얻을 수 없고 의미 해석을 라벨로 넣는 것은 창작이다(문서30 §23-J 결정 3 · 현업 문서20 §M-4). PSTMTR 은 원천 컬럼 부재 |
| **축B** | `SEND_RESULT_CD` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 축B(통신사 결과) 코드 raw — MSG_AT 은 전송실패코드 · SND 는 통화상태. 🟢**conformed 축**이다: 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 체계가 유지된다. 원천에 값이 없는 채널은 NULL |
| **축B 코드군 ID** | `SEND_RESULT_GROUP` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 축B 코드군 ID — 코드사전 MS283 이 정의한 4종(공통·알림톡·SMS·MMS). 🟢리터럴 지정이 아니라 **조인 결과에서 얻는다**(4그룹에 걸쳐 코드값 중복이 없어 값 자체가 그룹을 결정한다) |
| **축B 라벨** | `SEND_RESULT_NAME` | TEXT | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + dbt warn 관측(DEC-17-B · 센티넬 창작 금지) — 미매칭 규모는 이슈원장 §O59-N·문서20 §M-5 |
| **MAIL_RECEIVE_FLAG** | `MAIL_RECEIVE_FLAG` | BOOLEAN | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 메일수신여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MAIL_RECEIVE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **MEMBER_STOP_FLAG** | `MEMBER_STOP_FLAG` | BOOLEAN | YES | GOLD.FACT_MESSAGE_DISPATCH (f) | 결연회원 중단여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MEMBER_STOP_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_MESSAGE_DISPATCH (f) | 원천 시스템 식별 |
| **전체일자** | `FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실제 일자 |
| **연도** | `YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 년 |
| **월** | `MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 월 |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.DAY_OF_WEEK — 요일 |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.WEEK_OF_YEAR — 주차 |
| **휴일여부** | `IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 휴일여부 |
| **SEX** | `SEX` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · 실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. ⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. 라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **SEX_NM** | `SEX_NM` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. CM013 은 코드와 라벨이 1:1 이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_GENDER_NAME** | `MEMBER_GENDER_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_AREA_CD** | `MEMBER_AREA_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원지역** | `MEMBER_REGION` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128). |
| **MEMBER_AGE_CD** | `MEMBER_AGE_CD` | NUMBER | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원연령대** | `MEMBER_AGE_BAND` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128). |
| **MBER_STAT_CD** | `MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_STATUS_NAME** | `MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MBER_DIV_CD** | `MBER_DIV_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_TYPE_NAME** | `MEMBER_TYPE_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **SEND_TYPE_L_CD** | `SEND_TYPE_L_CD` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_GBN_TOP — 발송구분(대) 코드 raw. 🔴🔴**이 값은 상세코드가 아니라 CRM_CODE 의 코드그룹 ID(CD_ID) 자체다.** [O51-D 실측] `SND_REQ_MST.SEND_GBN_TOP` 실적재 값 = **MS046·MS047·MS048·MS049·MS050·MS0501·MS0505·MS051·MS052·MS053·MS054·MS055** 이며 **전부 `TC_CMMN_CD.CD_ID` 에 실재**한다. ⇒ 상세코드 사전(`TC_CMMN_DTL_CD`)에서 찾으면 나오지 않는다. 라벨 = SEND_TYPE_L. |
| **SEND_TYPE_L** | `SEND_TYPE_L` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_TYPE_L — 발송구분(대) 분석 라벨(정본 공#133) ← SND_REQ_MST.SEND_GBN_TOP_NM. 코드 = SEND_TYPE_L_CD. [O51-D 실측] **여러 코드가 같은 라벨로 축약**된다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053. ⇒ 라벨로 GROUP BY 하면 코드가 합쳐진다(대분류는 코드그룹과 1:1 이 아니다). 🔴정본 공#133 과 **불일치**: #133 은 결연/회비/서비스/사업보고/참여/기타 만 열거하는데 실측 라벨에는 **회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053)이 더 있다.** #133 에 생략기호가 없어 완전열거로 읽히므로 불일치는 실재한다 → 현업 확인 대상, 데이터 우선 보존(DEC-26). ⚠️커버리지가 낮다 — 비매칭은 센티넬 '(미매핑)'(DEC-30). 규모는 이슈원장 §O51-D-C 참조. 🔴🔴[O51-D 실측] `'(미매핑)'` 이 **과반을 크게 넘는다** — 발송구분 대분류는 매칭되는 행이 소수다. 커버리지를 모르고 대분류별 비중을 내면 **결론이 뒤집힌다.** 실측 규모는 이슈원장 §O51-D-C. |
| **SEND_TYPE_M_CD** | `SEND_TYPE_M_CD` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_GBN_MID — 발송구분(중) 코드 raw ← SND_REQ_MST.SEND_GBN_MID. 🔴🔴**코드 단독 사용 금지 — 이 코드는 부모(대) 그룹 안에서만 유일하다.** [O51-D BRONZE 실측] 값 '01' 이 부모에 따라 '결제오류'·'모바일소식지(사단)'·'기타_사단'·'기부금영수증(사단)'·'기타' 등 서로 다른 뜻이며 실적재 (코드,라벨) 쌍 37종이 나온다. ⇒ 반드시 **(대,중) 쌍**으로 해석할 것. 라벨 = SEND_TYPE_M. |
| **SEND_TYPE_M** | `SEND_TYPE_M` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_TYPE_M — 발송구분(중) 분석 라벨(정본 공#134) ← SND_REQ_MST.SEND_GBN_MID_NM. 코드 = SEND_TYPE_M_CD. 예: 결제오류·APR회원발송·ACL회원발송·만18세아동종결(종결예정)·후원참여·회원개발·아동답신(서신/선물금/회소카). 🔴같은 라벨이 여러 부모(대) 아래 반복되므로 라벨 단독 GROUP BY 는 대분류를 섞는다. ⚠️비매칭은 '(미매핑)'. |
| **SEND_TYPE_S_CD** | `SEND_TYPE_S_CD` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_GBN_BOT — 발송구분(소) 코드 raw ← SND_REQ_MST.SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴**코드 단독 모호** — [O51-D 실측] 같은 코드('0101'·'0401' 등)가 부모에 따라 다른 뜻이다. ⇒ **(대,중,소) 경로**로만 해석할 것. 라벨 = SEND_TYPE_S. |
| **SEND_TYPE_S** | `SEND_TYPE_S` | TEXT | YES | GOLD.DIM_SEND_TYPE (발송 채널/유형 차원) | DIM_SEND_TYPE.SEND_TYPE_S — 발송구분(소) 분석 라벨(정본 공#135) ← SND_REQ_MST.SEND_GBN_BOT_NM. 코드 = SEND_TYPE_S_CD. 예: APR발송예정안내·ACL발송예정안내·기존회원개발메일(사단)·겨울 소식지_사단·답신발송알림·자동이체결제오류(사단)·네이버페이(사단). 🔴라벨도 부모 경로 없이는 유일하지 않다(답신발송알림이 여러 중분류에 존재). ⚠️비매칭은 '(미매핑)'. |
| **SERVICE_SUBTYPE** | `SERVICE_SUBTYPE` | TEXT | YES | GOLD.DIM_SERVICE (서비스 분류 차원) | DIM_SERVICE.SUBTYPE — 발송/참여 subtype |
| **SERVICE_CHANNEL** | `SERVICE_CHANNEL` | TEXT | YES | GOLD.DIM_SERVICE (서비스 분류 차원) | DIM_SERVICE.CHANNEL — CRM_UMS / ADMIN |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **상위캠페인** | `CAMPAIGN_PARENT` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **홍보방법** | `CAMPAIGN_PROMO_METHOD` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |

---

### 2.5 `WIDE_EVENT_PARTICIPATION` — 행사 참여 평탄화 뷰 (Event Attendance Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 일반행사 및 캠페인행사 참여 이력 팩트에 행사 마스터, 회원 속성, 캠페인, 후원사업 차원을 결합한 행사 성과 뷰
- **분석 Grain**: `참여일(DATE_SK) × 회원(MEMBER_DK) × 행사(EVENT_SK)`
- **기준 Fact 테이블**: `GOLD.FACT_EVENT_ATTENDANCE (f)`
- **조인 Dimension 테이블**: 5개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_EVENT_ATTENDANCE (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)`
  - `LEFT JOIN GOLD.DIM_EVENT (e) ON f.EVENT_SK = e.EVENT_SK (행사구분·카테고리)`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **일자키(YYYYMMDD)** | `DATE_SK` | NUMBER | NO | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여일 YYYYMMDD |
| **회원식별키(DK)** | `MEMBER_DK` | TEXT | NO | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여 회원 (불변키) |
| **TOTAL_CNT** | `TOTAL_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 총인원 |
| **WAIT_CNT** | `WAIT_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 대기인원 |
| **CANCEL_CNT** | `CANCEL_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 취소인원 |
| **CONFIRM_CNT** | `CONFIRM_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 신청확정인원 |
| **PARTICIPATE_CNT** | `PARTICIPATE_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여인원 |
| **ABSENT_CNT** | `ABSENT_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 불참인원 |
| **PARTICIPANT_CNT** | `PARTICIPANT_CNT` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여자수 |
| **PARTICIPATION_TIMES** | `PARTICIPATION_TIMES` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여횟수 |
| **WAIT_TIMES** | `WAIT_TIMES` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 대기횟수 |
| **ABSENT_TIMES** | `ABSENT_TIMES` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 불참횟수 |
| **CUM_APPLY_TIMES** | `CUM_APPLY_TIMES` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 누적신청횟수 |
| **정기후원금** | `REGULAR_DONATION` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 정기후원금(원) |
| **WIN_FLAG** | `WIN_FLAG` | BOOLEAN | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 당첨여부 |
| **SELF_PART_FLAG** | `SELF_PART_FLAG` | BOOLEAN | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 본인참여여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_EVENT_ATTENDANCE.SELF_PART_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. |
| **PART_STATUS** | `PART_STATUS` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여상태 |
| **PART_PATH** | `PART_PATH` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여경로 |
| **PART_CHANNEL** | `PART_CHANNEL` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여채널 |
| **참여상태 코드군 ID** | `PART_STATUS_GROUP` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여상태 코드군 ID (조인키 · 일반행사→MS304 · 캠페인행사→MS006). 🔴O28 다체계의 **구조적 해소축**이다 — `PART_STATUS` 단독 필터·GROUP BY 는 두 체계를 섞는다(판별자 = 이 컬럼 또는 `EVENT_KIND`). 🔴두 원천의 「참여」 정의 자체가 다르므로 합산 금지 |
| **참여상태 라벨** | `PART_STATUS_NAME` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여상태 라벨 (CRM_CODE 조인). ⚠️일반행사(MS304) 라벨은 코드사전에 **영문**으로 등록돼 있다(Success·N_step_right 계열) — 현업 한글 표기 회신 대기(문서20 §M-1)이며 우리가 창작하지 않았다. 미등재·오염 코드는 NULL |
| **참여경로 코드군 ID** | `PART_PATH_GROUP` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여경로 코드군 ID (조인키 · 일반행사→MS303 · 캠페인행사→MS004=신청경로). 🟢운영서버 코드사전 대조로 확정(2026-08-11) |
| **참여경로 라벨** | `PART_PATH_NAME` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여경로 라벨 (CRM_CODE 조인 · 코드군 확정). 미등재·오염 코드는 NULL 유지 |
| **참여채널 코드군 ID** | `PART_CHANNEL_GROUP` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여채널 코드군 ID (조인키 · 일반행사→MS302). 캠페인행사는 원천에 채널 축이 없어 NULL(구조적 부재 · P21) |
| **참여채널 라벨** | `PART_CHANNEL_NAME` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | 참여채널 라벨 (CRM_CODE 조인). 미등재·오염 코드는 NULL 유지 |
| **PART_EVENT_BK** | `PART_EVENT_BK` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | FACT_EVENT_ATTENDANCE.EVENT_BK — degenerate key: **팩트가 보유한 원천 행사키**(전건 채움). 🔴같은 뷰의 EVENT_BK(=DIM_EVENT 매칭분)와 **다르다** — 행사 마스터가 없는 **고아 행사**가 EVENT_SK=0 으로 뭉개져 서로 구별되지 않으므로 이 컬럼으로 식별을 보존한다. 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 **PART_EVENT_BK 는 원천값을 그대로 갖는다.** 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 PART_EVENT_BK 는 원천값을 그대로 갖는다. 🔷행 유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ). ⚠️접두(EVENT_/CRMN_)가 원천 코드체계 판별자(O28). |
| **PARTCPT_SEQ** | `PARTCPT_SEQ` | NUMBER | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | FACT_EVENT_ATTENDANCE.PARTCPT_SEQ — degenerate key: 참여 일련번호 ← `BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL.PARTCPT_SEQ`. 🔷(PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ) 가 행을 유일 식별한다 — **(행사,회원)만으로는 중복**이다. 🔴**전역 순번이 아니다**((행사,SEQ) 조합도 유일하지 않다) · **음수·INT_MIN 값이 존재**한다 ⇒ **식별자 전용**이며 정렬·범위조건·MAX 로 '참여 횟수'를 세지 말 것. |
| **PART_EVENT_KIND** | `PART_EVENT_KIND` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | FACT_EVENT_ATTENDANCE.EVENT_KIND — **팩트가 보유한 원천 계열 판별 코드**(전건 채움 · 값 EVENT/CRMN). 🔴같은 뷰의 EVENT_KIND(=DIM_EVENT 유래)와 **다르다** — 차원축은 행사 마스터 미매칭 구간이 '(미매핑)' 이라 계열을 알려주지 못한다. ⇒ **계열 분해·O28 다체계 판별은 이 컬럼**으로 한다. 라벨은 PART_EVENT_KIND_NAME. |
| **PART_EVENT_KIND_NAME** | `PART_EVENT_KIND_NAME` | TEXT | YES | GOLD.FACT_EVENT_ATTENDANCE (f) | FACT_EVENT_ATTENDANCE.EVENT_KIND_NAME — **팩트가 보유한 원천 계열 판별 라벨**(전건 채움 · 값 일반행사/캠페인행사). 🔴차원 유래 EVENT_KIND_NAME 과 달리 **(미매핑) 사각지대가 없다.** 🔴원천 계열을 뜻하며 온·오프라인 구분이 아니다. ⚠️파생 라벨이므로 코드사전 조인 대상이 아니다. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_EVENT_ATTENDANCE (f) | 원천 시스템 식별 |
| **전체일자** | `FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실제 일자 |
| **연도** | `YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 년 |
| **월** | `MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 월 |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.DAY_OF_WEEK — 요일 |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.WEEK_OF_YEAR — 주차 |
| **휴일여부** | `IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 휴일여부 |
| **SEX** | `SEX` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · 실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. ⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. 라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **SEX_NM** | `SEX_NM` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. CM013 은 코드와 라벨이 1:1 이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_GENDER_NAME** | `MEMBER_GENDER_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_AREA_CD** | `MEMBER_AREA_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원지역** | `MEMBER_REGION` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128). |
| **MEMBER_AGE_CD** | `MEMBER_AGE_CD` | NUMBER | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **회원연령대** | `MEMBER_AGE_BAND` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128). |
| **MBER_STAT_CD** | `MBER_STAT_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_STATUS_NAME** | `MEMBER_STATUS_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MBER_DIV_CD** | `MBER_DIV_CD` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **MEMBER_TYPE_NAME** | `MEMBER_TYPE_NAME` | TEXT | YES | GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전) | DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조) |
| **EVENT_BK** | `EVENT_BK` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_BK — 행사 업무키 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 행사 마스터 없는 고아 행사가 한 그룹으로 뭉친다. 행사 식별은 `PART_EVENT_BK` 를 쓴다. 실측 규모는 이슈원장 §O51-D-C. |
| **EVENT_KIND** | `EVENT_KIND` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_KIND — 🔴[O59-P 정정] 종전 설명 「온라인/오프라인」은 **거짓이었다**. 실제 값은 `EVENT`(일반행사) · `CRMN`(캠페인행사) = **원천 판별자**다(온·오프라인 구분은 `EVENT_CATEGORY` 소관). 🔴이 컬럼이 O28 다체계의 판별자다 — 참여상태·경로를 이 축 없이 합산하면 정의가 다른 두 체계를 섞는다. 라벨축 = `EVENT_KIND_NAME` |
| **EVENT_KIND_NAME** | `EVENT_KIND_NAME` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_KIND_NAME — 행사종류 라벨(일반행사/캠페인행사). ⚠️판별자 라벨은 코드사전에 존재할 수 없어 `CASE` 로 만든다(DEC-35 §23-B 헛점4 의 명문 예외 · 미등재 값은 NULL 로 떨어져 warn 이 잡는다) |
| **EVENT_CATEGORY** | `EVENT_CATEGORY` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_CATEGORY — 행사구분 코드 raw. 🔴원천별 2체계다: 일반행사=100~500(MS286) · 캠페인행사=1~16(MS002) ⇒ **코드 단독 GROUP BY 금지**(판별자 = `EVENT_KIND` 또는 `EVENT_CATEGORY_GROUP`) |
| **행사구분 코드군 ID** | `EVENT_CATEGORY_GROUP` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | 행사구분 코드군 ID (조인키 · 일반행사→MS286 · 캠페인행사→MS002). 두 체계는 코드값이 겹치지 않으나 **의미가 다르므로 합산하지 말 것** |
| **행사구분 라벨** | `EVENT_CATEGORY_NAME` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | 행사구분 라벨 (CRM_CODE 조인). ⚠️센티넬 행('(미매핑)')은 라벨이 NULL 이다 — 코드가 없으므로 조인 대상이 아니다 |
| **EVENT_NAME** | `EVENT_NAME` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_NAME — 행사명 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 고아 행사들이 한 이름으로 합쳐진다. 실측 규모는 이슈원장 §O51-D-C. |
| **EVENT_START_DATE** | `EVENT_START_DATE` | DATE | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_START_DATE — 행사기간 시작 |
| **EVENT_END_DATE** | `EVENT_END_DATE` | DATE | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.EVENT_END_DATE — 행사기간 종료 |
| **EVENT_APPLY_CHANNEL** | `EVENT_APPLY_CHANNEL` | TEXT | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.APPLY_CHANNEL — 신청경로 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_EVENT.APPLY_CHANNEL`. 행사 신청채널은 원천 행사 마스터에 값이 없다 ⇒ **신청채널 분석은 불가**하다. 실측 규모는 이슈원장 §O51-D-C. |
| **EVENT_RECRUIT_HEADCOUNT** | `EVENT_RECRUIT_HEADCOUNT` | NUMBER | YES | GOLD.DIM_EVENT (행사 차원) | DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원) ← `SILVER CRM_EVENT.RCRIT_PSNNL_CO`. 일부 행사는 정원이 없다. 🔴🔴**행사 grain 속성이므로 참여행에서 SUM 금지** — 참여행마다 반복되어 **두 자리 배수로 과대계상**된다(실측 배율은 이슈원장 §O51-D-C). 정원 대비 참여율은 행사 단위로 집계한 뒤 나눌 것. 🔧[DEC-30] 종전 팩트의 RECRUIT_CNT 를 제거하고 이 행사 차원 값으로 대체했다. |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **후원사업코드(BK)** | `SPONSORSHIP_BK` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C. |

---

### 2.6 `WIDE_BUDGET` — 예산 편성/집행 평탄화 뷰 (Budget & Expense Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 예산과목별 월 편성예산 및 ERP 집행 실적 팩트에 조직(부서) 및 예산과목 차원을 결합한 예산 관리 뷰
- **분석 Grain**: `예산월(MONTH_KEY) × 부서(ORG_SK) × 예산과목(BUDGET_ITEM_SK)`
- **기준 Fact 테이블**: `GOLD.FACT_BUDGET (f)`
- **조인 Dimension 테이블**: 4개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_BUDGET (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (예산 관할 부서)`
  - `LEFT JOIN GOLD.DIM_BUDGET_ITEM (bi) ON f.BUDGET_ITEM_SK = bi.BUDGET_ITEM_SK (계정과목·관항목)`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **월키(YYYYMM)** | `MONTH_KEY` | NUMBER | NO | GOLD.FACT_BUDGET (f) | 예산월 YYYYMM |
| **연도(YYYY)** | `CAL_YEAR` | NUMBER | YES | 파생 (DERIVED 계산식) | FLOOR(MONTH_KEY/100) — 연도 |
| **월(MM)** | `CAL_MONTH` | NUMBER | YES | 파생 (DERIVED 계산식) | MOD(MONTH_KEY,100) — 월 |
| **월편성예산(원)** | `PLAN_BUDGET_MONTH` | NUMBER | YES | GOLD.FACT_BUDGET (f) | 편성예산(월, 원). 🔴🔴 **[2026-08-29 O114-B] 이 컬럼을 12개월 합산해도 `FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR` 와 일치하지 않는다** — 원천 원장의 **월 배분이 부분적**이어서 연 총액의 상당 부분이 월 컬럼에 배분되지 않는다(원천 특성 · 모델 결함 아님 · 실측 규모는 이슈원장·이력 소관 `R2-6`). ⇒ 🔴 **「편성예산」을 답할 때 월·연 중 어느 축인지 밝혀라** — 밝히지 않으면 두 답이 갈린다. 🟢 대비: **집행은 연=월 정합**이다(`EXEC_BUDGET_ERP` 월합 = `FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR`). 🔴🔴 **또한 이 값은 예산 편성 차수(본예산 `연사업` / `추가경정`)가 합산된 값이다** — 원천이 신설한 `BDGT_PRCD_NM` 이 `BUDGET_ITEM_DK` 산식에 없어 두 차수가 같은 과목 키로 붕괴한다 ⇒ **차수별 분해는 현재 불가능**하다(처방 = `99_NEXT §0-UUU ▣UUU6` · `DEC-44`). |
| **월집행예산(원)** | `EXEC_BUDGET_ERP` | NUMBER | YES | GOLD.FACT_BUDGET (f) | 집행예산(ERP 월, 원) |
| **집행예산** | `EXEC_BUDGET_EST` | NUMBER | YES | GOLD.FACT_BUDGET (f) | 집행예산(추정, 원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 집행 추정 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(E-1/E-4 하드블로커). 실측 규모는 이슈원장 §O51-F. |
| **모금성비용** | `FUNDRAISING_COST` | NUMBER | YES | GOLD.FACT_BUDGET (f) | 모금성비용(원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 모금성비용 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(**E-1** 하드블로커) — 모금성비용은 원천 확정 대기다. 실측 규모는 이슈원장 §O51-F. |
| **광고비(원)** | `AD_COST` | NUMBER | YES | GOLD.FACT_BUDGET (f) | 광고비(원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 예산 원장의 광고비 컬럼`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴예산 원장에는 광고비 항목이 없다(**E-4**) — 광고비는 대행사 원천(`WIDE_AD_PERFORMANCE`)에서 가져오며 **예산과 같은 표에 합산하지 말 것**(원천이 다르다 · 순서9-K 표 분리 근거). 실측 규모는 이슈원장 §O51-F. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_BUDGET (f) | 원천 시스템 식별 |
| **법인구분** | `ORG_CORP` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |
| **본부명** | `ORG_DIVISION` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |
| **부서명** | `ORG_DEPARTMENT` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.ORG_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴예산 원장은 **부서별 분해가 현재 불가능**하다 — 「부서별 예산·집행」 요구에 총계 1행이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **팀명** | `ORG_TEAM` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |
| **BUDGET_ITEM_NAME** | `BUDGET_ITEM_NAME` | TEXT | YES | GOLD.DIM_BUDGET_ITEM (예산과목 차원) | DIM_BUDGET_ITEM.BUDGET_ITEM_NAME — 세세목명 |
| **BUDGET_CATEGORY** | `BUDGET_CATEGORY` | TEXT | YES | GOLD.DIM_BUDGET_ITEM (예산과목 차원) | DIM_BUDGET_ITEM.BUDGET_CATEGORY — 예산구분 |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **후원사업코드(BK)** | `SPONSORSHIP_BK` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |

---

### 2.7 `WIDE_TARGET_DEV` — 회원개발 목표 평탄화 뷰 (Member Development Target Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 부서별 월 회원개발 목표 팩트에 부서(조직) 차원을 결합한 목표 관리 뷰
- **분석 Grain**: `목표월(MONTH_KEY) × 부서(ORG_SK) × 개발구분(DEV_TYPE)`
- **기준 Fact 테이블**: `GOLD.FACT_TARGET_MEMBER_DEV (f)`
- **조인 Dimension 테이블**: 1개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_TARGET_MEMBER_DEV (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (목표 수립 부서)`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **월키(YYYYMM)** | `MONTH_KEY` | NUMBER | NO | GOLD.FACT_TARGET_MEMBER_DEV (f) | 목표월 YYYYMM |
| **연도(YYYY)** | `CAL_YEAR` | NUMBER | YES | 파생 (DERIVED 계산식) | FLOOR(MONTH_KEY/100) — 연도 |
| **월(MM)** | `CAL_MONTH` | NUMBER | YES | 파생 (DERIVED 계산식) | MOD(MONTH_KEY,100) — 월 |
| **개발구분** | `DEV_TYPE` | TEXT | NO | GOLD.FACT_TARGET_MEMBER_DEV (f) | 개발구분 (#121 conform) |
| **목표건수** | `GOAL_CNT` | NUMBER | YES | GOLD.FACT_TARGET_MEMBER_DEV (f) | 회원개발목표(건) (CRM TM_CM_MBER_DVLP_GOAL) |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_TARGET_MEMBER_DEV (f) | 원천 시스템 식별 |
| **법인구분** | `ORG_CORP` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |
| **본부명** | `ORG_DIVISION` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |
| **부서명** | `ORG_DEPARTMENT` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). |
| **팀명** | `ORG_TEAM` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F. |

---

### 2.8 `WIDE_TARGET_BIZ` — 사업 목표 평탄화 뷰 (Project Target Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 부서 및 후원사업별 연간/추경 사업목표 팩트에 부서, 후원사업, 캠페인 차원을 결합한 사업 목표 뷰
- **분석 Grain**: `목표월(MONTH_KEY) × 부서(ORG_SK) × 후원사업(SPONSORSHIP_SK)`
- **기준 Fact 테이블**: `GOLD.FACT_TARGET_PROJECT (f)`
- **조인 Dimension 테이블**: 3개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_TARGET_PROJECT (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK`
  - `LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **월키(YYYYMM)** | `MONTH_KEY` | NUMBER | NO | GOLD.FACT_TARGET_PROJECT (f) | 목표월 YYYYMM 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **연도(YYYY)** | `CAL_YEAR` | NUMBER | YES | 파생 (DERIVED 계산식) | FLOOR(MONTH_KEY/100) — 연도 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **월(MM)** | `CAL_MONTH` | NUMBER | YES | 파생 (DERIVED 계산식) | MOD(MONTH_KEY,100) — 월 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **연간목표건수** | `ANNUAL_GOAL_CNT` | NUMBER | YES | GOLD.FACT_TARGET_PROJECT (f) | 연사업목표(건) (#152) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **추경목표건수** | `SUPP_GOAL_CNT` | NUMBER | YES | GOLD.FACT_TARGET_PROJECT (f) | 추경목표(건) (#153) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **연사업누계목표** | `ANNUAL_CUM_GOAL_CNT` | NUMBER | YES | GOLD.FACT_TARGET_PROJECT (f) | 연사업누계목표(건) (#154) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **추경누계목표** | `SUPP_CUM_GOAL_CNT` | NUMBER | YES | GOLD.FACT_TARGET_PROJECT (f) | 추경누계목표(건) (#155) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_TARGET_PROJECT (f) | 원천 시스템 식별 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **법인구분** | `ORG_CORP` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **본부명** | `ORG_DIVISION` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **부서명** | `ORG_DEPARTMENT` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **팀명** | `ORG_TEAM` | TEXT | YES | GOLD.DIM_ORG (조직/부서 차원) | DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **후원사업코드(BK)** | `SPONSORSHIP_BK` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **후원사업명** | `SPONSORSHIP_NAME` | TEXT | YES | GOLD.DIM_SPONSORSHIP (후원사업 차원) | DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. ⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. 실측 규모는 이슈원장 §O51-F. |

---

### 2.9 `WIDE_AD_PERFORMANCE` — 광고 성과 코어 평탄화 뷰 (Core Ad Performance Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 디지털, 방송, 비디오 등 전 매체 광고 성과 공통 코어 팩트에 일자, 캠페인, 광고소재, 디바이스 차원을 결합한 기본 광고 성과 뷰
- **분석 Grain**: `광고성과식별자(AD_PERF_DK) — 실적일 × 매체 × 소재`
- **기준 Fact 테이블**: `GOLD.FACT_AD_PERFORMANCE (f)`
- **조인 Dimension 테이블**: 4개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_AD_PERFORMANCE (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK`
  - `LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **광고성과 행 식별자** | `AD_PERF_DK` | TEXT | NO | GOLD.FACT_AD_PERFORMANCE (f) | 광고성과 행 식별자(grain) — 위성 뷰 조인키 |
| **PERF_DATE_SK** | `PERF_DATE_SK` | NUMBER | NO | GOLD.FACT_AD_PERFORMANCE (f) | 광고 실적일 YYYYMMDD |
| **광고비(원)** | `AD_COST` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 광고비(원) |
| **노출수** | `IMPRESSIONS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 노출수(디지털 전용) |
| **클릭수** | `CLICKS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 클릭수(디지털 전용) |
| **INBOUND_CALL** | `INBOUND_CALL` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 인입콜수 |
| **대행사 전환수** | `AGENCY_CONV_MEMBERS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 대행사 전환수(명) — 디지털 전용(O16 교정: 재방송 개발실적 제외) |
| **대행사 전환수** | `AGENCY_CONV_CNT` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 대행사 전환수(건/VU) — 디지털 전용(O16 교정: 재방송 개발실적 제외) |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.FACT_AD_PERFORMANCE (f) | 요일(팩트 degen) |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (f) | 주차(팩트 degen) |
| **AD_SOURCE_TYPE** | `AD_SOURCE_TYPE` | TEXT | YES | GOLD.FACT_AD_PERFORMANCE (f) | 광고 원천유형 DIGITAL/VIDEO/REBROADCAST — 출처 명시축(팩트 degen, DEC-8) |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_AD_PERFORMANCE (f) | 원천 시스템 식별 (GA4/AGENCY/GADS) |
| **PERF_FULL_DATE** | `PERF_FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실적일 일자 |
| **PERF_YEAR** | `PERF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 실적일 년 |
| **PERF_MONTH** | `PERF_MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 실적일 월 |
| **PERF_QUARTER** | `PERF_QUARTER` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.QUARTER — 실적일 분기 |
| **PERF_IS_HOLIDAY** | `PERF_IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F. |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **상위캠페인** | `CAMPAIGN_PARENT` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **홍보방법** | `CAMPAIGN_PROMO_METHOD` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인유형** | `CAMPAIGN_TYPE` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **AD_CREATIVE_BK** | `AD_CREATIVE_BK` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.AD_CREATIVE_BK — 광고소재 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_MEDIA_NAME** | `AD_MEDIA_NAME` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.MEDIA_NAME — 매체명 (#11) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_PLATFORM** | `AD_PLATFORM` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.PLATFORM — 플랫폼 (#12) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **AD_PLATFORM_TYPE** | `AD_PLATFORM_TYPE` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.PLATFORM_TYPE — 플랫폼/매체유형 (#13) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL**. 🆕🔴🔴[2026-09-01 O129 정정] 종전 문안의 *「원인은 차원이 아니라 팩트 FK 가 전건 센티넬이다 · 차원 자체는 채워져 있다」* 는 **이 컬럼에 대해 거짓이었다**(O51-F 오버레이가 여러 컬럼에 같은 문안을 도포한 결과 · O96 이 재검증 대상으로 지목한 그 건이다). 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.PLATFORM_TYPE`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = BRONZE AGENCY 3테이블에 「매체유형」 축이 없다(인접 유형축은 전부 다른 목적지에 배선돼 대체물이 아니다) ⇒ 요건 #13 은 현업 확인 대상. 정본 = 문서30 §7-C-1. |
| **AD_CREATIVE** | `AD_CREATIVE` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.CREATIVE — 소재 (#20) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_CREATIVE_TYPE** | `AD_CREATIVE_TYPE` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.AD_TYPE — 소재 광고유형 (⚠️AD_SOURCE_TYPE 과 다른 개념) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_TARGET_GROUP** | `AD_TARGET_GROUP` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL**. 🆕🔴🔴[2026-09-01 O129 정정] 종전 문안의 *「차원 자체는 채워져 있다」* 는 **이 컬럼에 대해 거짓이었다**(O51-F 도포본 · O96 이 재검증 대상으로 지목한 그 건이다). 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.TARGET_GROUP`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = 원천 트랙이 **GA4** 다(잠재고객=타겟그룹은 원천표기 GA → `GA4_USER` 정제 예정 · phase-2 미착수) ⇒ **대행사 축으로는 영구히 NULL** 이다. 정본 = 문서30 §7-C-1. |
| **DEVICE_TYPE** | `DEVICE_TYPE` | TEXT | YES | GOLD.DIM_DEVICE (디바이스 차원) | DIM_DEVICE.DEVICE_TYPE — PC / M / (해당없음)방송 / (unknown) |
| **DEVICE_SCOPE_DESC** | `DEVICE_SCOPE_DESC` | TEXT | YES | GOLD.DIM_DEVICE (디바이스 차원) | DIM_DEVICE.DEVICE_SCOPE_DESC — 기기축 적용범위 자기설명(DEC-10) |

---

### 2.10 `WIDE_AD_DIGITAL` — 디지털 광고 위성 평탄화 뷰 (Digital Ad Satellite Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 디지털 광고(검색/배너/SNS) 전용 노출, 클릭, 전환, 랜딩 지표를 코어 성과 및 차원과 1:1 결합한 디지털 특화 뷰
- **분석 Grain**: `광고성과식별자(AD_PERF_DK)`
- **기준 Fact 테이블**: `GOLD.FACT_AD_DIGITAL (g)`
- **조인 Dimension 테이블**: 5개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_AD_DIGITAL (g)`
- **조인 상세 규칙**:
  - `JOIN GOLD.FACT_AD_PERFORMANCE (f) ON g.AD_PERF_DK = f.AD_PERF_DK (코어 팩트와 1:1 결합)`
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK`
  - `LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **광고성과 행 식별자** | `AD_PERF_DK` | TEXT | NO | GOLD.FACT_AD_DIGITAL (g) | 광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키 |
| **AD_SOURCE_TYPE** | `AD_SOURCE_TYPE` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 광고 원천유형. 🔴본 뷰는 **DIGITAL 단일값**이다(위성이 원천유형으로 수직분할되어 있다) — GROUP BY 대상이 아니며, 유형 간 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다. |
| **PERF_DATE_SK** | `PERF_DATE_SK` | NUMBER | NO | GOLD.FACT_AD_DIGITAL (g) | 광고 실적일 YYYYMMDD |
| **광고비(원)** | `AD_COST` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | [코어] 광고비(원) |
| **노출수** | `IMPRESSIONS` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | [코어] 노출수 — CTR 분모 |
| **클릭수** | `CLICKS` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | [코어] 클릭수 — CTR 분자 |
| **AGENCY_CONV_MEMBERS** | `AGENCY_CONV_MEMBERS` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | [코어] 대행사 전환수(명) — CVR 분자(O16 교정 후 디지털 전용) |
| **AGENCY_CONV_CNT** | `AGENCY_CONV_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | [코어] 대행사 전환수(건/VU) — CPA 분모(O16 교정 후 디지털 전용) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴비율 metric 의 분모로 쓸 때는 분자 커버리지를 먼저 맞출 것 — 분모만 부분이면 조용히 과대계상된다(P18). 실측 규모는 이슈원장 §O51-F. |
| **PAGE_TYPE** | `PAGE_TYPE` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 페이지유형 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **AD_GROUP_NM** | `AD_GROUP_NM` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 광고그룹명 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **GROUP_DIV** | `GROUP_DIV` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 그룹구분 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **소재유형** | `CREATIVE_TYPE` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 소재유형(원천 표기) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **광고유형명** | `AD_TYPE_NM` | TEXT | YES | GOLD.FACT_AD_DIGITAL (g) | 광고유형명(대행사 표기). [O51-F BRONZE 실측] 실적재 값 = **하단DA·DA·CPT·BSA·SA·CPM**. 🔴`AD_SOURCE_TYPE`(VIDEO/REBROADCAST/DIGITAL)과 **다른 개념**이다 — 이름이 비슷해 혼용되기 쉽다. |
| **READ_CNT** | `READ_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | 읽음수 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **MEDIA_POTENTIAL_CUST_CNT** | `MEDIA_POTENTIAL_CUST_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | 매체 잠재고객수 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-F. |
| **CRM_DEV_CNT** | `CRM_DEV_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CRM 개발건수 |
| **CTR** | `CTR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **CVR** | `CVR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(AGENCY_CONV_MEMBERS)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **CPC** | `CPC_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CPC(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **CPM** | `CPM_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **CPA** | `CPA_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(AGENCY_CONV_CNT) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **개발단가** | `DEV_UNIT_PRICE_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | 개발단가(대행사 산정) — 비가산 N 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️원천 포맷 변경으로 개발건수와 **상호배타**다(AD-3) — 개발단가는 두 컬럼이 기간을 보완하는 관계이며 교차검증 관계가 아니다. 실측 규모는 이슈원장 §O51-F. |
| **VTR** | `VTR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL (g) | VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. base 가 원천에 없어 DW 재계산도 불가하다. 실측 규모는 이슈원장 §O51-F. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_AD_DIGITAL (g) | 원천 시스템 식별 |
| **PERF_FULL_DATE** | `PERF_FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실적일 일자 |
| **PERF_YEAR** | `PERF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 실적일 년 |
| **PERF_MONTH** | `PERF_MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 실적일 월 |
| **PERF_QUARTER** | `PERF_QUARTER` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.QUARTER — 실적일 분기 |
| **PERF_IS_HOLIDAY** | `PERF_IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F. |
| **AD_MEDIA_NAME** | `AD_MEDIA_NAME` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_CREATIVE** | `AD_CREATIVE` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **DEVICE_TYPE** | `DEVICE_TYPE` | TEXT | YES | GOLD.DIM_DEVICE (디바이스 차원) | DIM_DEVICE.DEVICE_TYPE — M / PC (디지털은 기기 실존) |

---

### 2.11 `WIDE_AD_BROADCAST` — 방송 광고 위성 평탄화 뷰 (Broadcast Ad Satellite Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: TV/케이블 방송 및 재방송 광고 전용 방송일시, 채널, 방영형태, 인입콜 지표를 코어 성과 및 차원과 결합한 방송 특화 뷰
- **분석 Grain**: `광고성과식별자(AD_PERF_DK)`
- **기준 Fact 테이블**: `GOLD.FACT_AD_BROADCAST (b)`
- **조인 Dimension 테이블**: 4개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_AD_BROADCAST (b)`
- **조인 상세 규칙**:
  - `JOIN GOLD.FACT_AD_PERFORMANCE (f) ON b.AD_PERF_DK = f.AD_PERF_DK (코어 팩트와 1:1 결합)`
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **광고성과 행 식별자** | `AD_PERF_DK` | TEXT | NO | GOLD.FACT_AD_BROADCAST (b) | 광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키 |
| **광고 원천유형** | `AD_SOURCE_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 광고 원천유형 — 본 뷰는 방송 2종(**VIDEO·REBROADCAST**)만 담는다. 🔴두 원천은 보고 항목이 다르다: 전용 컬럼이 서로 배타적이며 NULL 은 결측이 아니라 개념 부재다. 디지털은 본 뷰에 없다 — 전 유형 집계는 코어 `WIDE_AD_PERFORMANCE`. |
| **PERF_DATE_SK** | `PERF_DATE_SK` | NUMBER | NO | GOLD.FACT_AD_BROADCAST (b) | 광고 실적일 YYYYMMDD |
| **광고비(원)** | `AD_COST` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | [코어] 광고비(원) — VIDEO=실집행·REBRDC=편성비용 |
| **INBOUND_CALL** | `INBOUND_CALL` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | [코어] 인입콜수 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴채널·시간대별 인입콜 비교 시 미보고 행이 0 이 아니라 NULL 이므로 평균이 왜곡될 수 있다. 실측 규모는 이슈원장 §O51-F. |
| **TIME_BAND** | `TIME_BAND` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 시간대 |
| **CM위치** | `CM_POSITION` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | CM위치 (VIDEO 전용) |
| **RT** | `RT_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | RT(재방송)유형 (REBRDC 전용) |
| **광고시작시간** | `AD_START_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 광고시작시간 (VIDEO 전용) |
| **광고종료시간** | `AD_END_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 광고종료시간 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️시작시간은 더 많이 채워져 있어 **시작·종료를 함께 요구하면 표본이 줄어든다**. 실측 규모는 이슈원장 §O51-F. |
| **송출일** | `BROADCAST_DATE` | DATE | YES | GOLD.FACT_AD_BROADCAST (b) | 송출일 — 실적일(PERF_DATE_SK)과 다를 수 있음 |
| **PROGRAM_NM** | `PROGRAM_NM` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 프로그램/편성명 |
| **CHANNEL_COMPANY** | `CHANNEL_COMPANY` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 채널사 |
| **채널사유형** | `CHANNEL_COMPANY_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 채널사유형 (VIDEO 전용) |
| **SPOT유형** | `SPOT_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | SPOT유형 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **광고 초수** | `DURATION_SEC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 광고 초수 (VIDEO 전용) |
| **요일구분 평일/주말** | `DAY_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 요일구분 평일/주말 (VIDEO 전용) |
| **프로그램 시작시간** | `PRG_START_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 프로그램 시작시간 (VIDEO 전용) |
| **CTV구분** | `CTV_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | CTV구분 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서도 소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **방송구분** | `BRDC_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST (b) | 방송구분 (REBRDC 전용) 🔴[O51-F 실측] 채움이 **REBROADCAST 안에서도 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F. |
| **AD_CNT** | `AD_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 광고횟수 |
| **전환콜** | `CONV_CALL_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 전환콜 (VIDEO 전용) — 인입콜과 별개 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴🔴종전 문서가 *「VIDEO 는 개발실적 대신 전환콜을 보고한다」* 고 적었으나 **그 컬럼도 원천에서 전건 비어 있다** — 즉 VIDEO 구간은 개발도 전환콜도 측정할 수 없다(AD-5 보강). REBROADCAST 원천에는 컬럼 자체가 없다. 실측 규모는 이슈원장 §O51-F. |
| **개발회원수** | `DVLP_MEMBER_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 개발회원수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리) ⚠️**REBROADCAST 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다. |
| **개발건수** | `DVLP_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 개발건수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리) ⚠️**REBROADCAST 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다. |
| **광고시청률** | `AD_VIEW_RT_SRC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | 광고시청률(대행사 산정) — 비가산 N, 재합산 금지. ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. |
| **CPC** | `CPC_SRC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST (b) | CPC(대행사 산정) — 비가산 N, 재합산 금지. ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다. |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_AD_BROADCAST (b) | 원천 시스템 식별 |
| **PERF_FULL_DATE** | `PERF_FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실적일 일자 |
| **PERF_YEAR** | `PERF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 실적일 년 |
| **PERF_MONTH** | `PERF_MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 실적일 월 |
| **PERF_QUARTER** | `PERF_QUARTER` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.QUARTER — 실적일 분기 |
| **PERF_IS_HOLIDAY** | `PERF_IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F. |
| **AD_MEDIA_NAME** | `AD_MEDIA_NAME` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |
| **AD_CREATIVE** | `AD_CREATIVE` | TEXT | YES | GOLD.DIM_AD_CREATIVE (광고소재/매체 차원) | DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F. |

---

### 2.12 `WIDE_AD_BROADCAST_CASE` — 재방송 사례 위성 평탄화 뷰 (Rebroadcast Case Satellite Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 재방송 광고 내 소개된 후원 아동/사례별 언피벗 세부 실적(CASE 1~3)을 방송 및 코어 성과와 결합한 뷰
- **분석 Grain**: `광고성과식별자(AD_PERF_DK) × 사례순번(CASE_SEQ)`
- **기준 Fact 테이블**: `GOLD.FACT_AD_BROADCAST_CASE (bc)`
- **조인 Dimension 테이블**: 4개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_AD_BROADCAST_CASE (bc)`
- **조인 상세 규칙**:
  - `JOIN GOLD.FACT_AD_PERFORMANCE (f) ON bc.AD_PERF_DK = f.AD_PERF_DK`
  - `LEFT JOIN GOLD.FACT_AD_BROADCAST (b) ON bc.AD_PERF_DK = b.AD_PERF_DK`
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **grain 1/2 · 광고성과 행 식별자** | `AD_PERF_DK` | TEXT | NO | GOLD.FACT_AD_BROADCAST_CASE (bc) | grain 1/2 · 광고성과 행 식별자 — 코어 WIDE_AD_PERFORMANCE 조인키(1:N) |
| **CASE_SEQ** | `CASE_SEQ` | NUMBER | NO | GOLD.FACT_AD_BROADCAST_CASE (bc) | grain 2/2 · 사례 순번 1~3 (원천 CASE1~CASE3 언피벗축) |
| **광고 원천유형** | `AD_SOURCE_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 광고 원천유형 — 본 뷰는 REBROADCAST 만 🔴[O51-F 실측] **단일값 REBROADCAST 뿐이다** — 본 뷰는 재방송 사례 전용이라 VIDEO 사례가 없다. GROUP BY 대상이 아니며, **이 뷰로 VIDEO 대비 재방송을 비교하면 재방송만 보고 결론을 낸다.** 원천유형 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다. 실측 규모는 이슈원장 §O51-F. |
| **PERF_DATE_SK** | `PERF_DATE_SK` | NUMBER | NO | GOLD.FACT_AD_BROADCAST_CASE (bc) | 광고 실적일 YYYYMMDD |
| **BIZ_DIV** | `BIZ_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 사례 사업구분 |
| **FAMILY_TYPE** | `FAMILY_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 사례 가족유형 |
| **APPEAL_POINT** | `APPEAL_POINT` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 사례 어필포인트 |
| **CASE_DIV** | `CASE_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 사례구분 |
| **RT** | `RT_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | RT(재방송)유형 — 위성 FAD_B 에서 동반 |
| **프로그램/편성명** | `PROGRAM_NM` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 프로그램/편성명 — 위성 FAD_B 에서 동반 |
| **채널사** | `CHANNEL_COMPANY` | TEXT | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 채널사 — 위성 FAD_B 에서 동반 |
| **송출일** | `BROADCAST_DATE` | DATE | YES | GOLD.FACT_AD_BROADCAST_CASE (bc) | 송출일 — 위성 FAD_B 에서 동반 |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_AD_BROADCAST_CASE (bc) | 원천 시스템 식별 |
| **PERF_FULL_DATE** | `PERF_FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실적일 일자 |
| **PERF_YEAR** | `PERF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 실적일 년 |
| **PERF_MONTH** | `PERF_MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 실적일 월 |
| **PERF_QUARTER** | `PERF_QUARTER` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.QUARTER — 실적일 분기 |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |

---

### 2.13 `WIDE_AD_COMBINED` — 광고 3종 통합 평탄화 뷰 (Combined Ad Performance Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: 코어 성과(FAP)에 디지털(FAD) 및 방송(FAB) 위성 팩트를 AD_PERF_DK 기준으로 1:1 pre-join하여 단일 뷰에서 전 매체를 분석할 수 있도록 구성한 통합 뷰
- **분석 Grain**: `광고성과식별자(AD_PERF_DK)`
- **기준 Fact 테이블**: `GOLD.FACT_AD_PERFORMANCE (fap)`
- **조인 Dimension 테이블**: 2개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_AD_PERFORMANCE (fap)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.FACT_AD_DIGITAL (dig) ON fap.AD_PERF_DK = dig.AD_PERF_DK (디지털 매체 실적)`
  - `LEFT JOIN GOLD.FACT_AD_BROADCAST (brc) ON fap.AD_PERF_DK = brc.AD_PERF_DK (방송 매체 실적)`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **행 식별자** | `AD_PERF_DK` | TEXT | NO | GOLD.FACT_AD_PERFORMANCE (fap) | 행 식별자(GRAIN·PK) MD5(AD_SOURCE_TYPE·ROW_HASH·DUP_SEQ). 위성 3종 조인키. 발급지점=SILVER.AGENCY_AD_ROW_* (DEC-11) |
| **실적일** | `PERF_DATE_SK` | NUMBER | NO | GOLD.FACT_AD_PERFORMANCE (fap) | 실적일 (분석축, FK→DIM_DATE) |
| **캠페인** | `CAMPAIGN_SK` | NUMBER | NO | GOLD.FACT_AD_PERFORMANCE (fap) | 캠페인 (분석축, FK→DIM_CAMPAIGN). ⚠️현재 0 스캐폴드 — Q10 이름매칭 대기 |
| **MKTG_CAMPAIGN_SK** | `MKTG_CAMPAIGN_SK` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | [O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 🔴미도달 행은 0(미매핑) 버킷이며 이 버킷을 「미집행」으로 읽지 말 것 — 도달률 실측은 이슈원장 §O45. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 광고비가 대규모로 팬아웃한다(배수 실측 = 이슈원장 §O45). |
| **광고소재/매체** | `AD_CREATIVE_SK` | NUMBER | NO | GOLD.FACT_AD_PERFORMANCE (fap) | 광고소재/매체 (분석축, FK→DIM_AD_CREATIVE). ⚠️현재 0 스캐폴드 — 부분키 매칭 설계 대기 |
| **디바이스** | `DEVICE_SK` | NUMBER | NO | GOLD.FACT_AD_PERFORMANCE (fap) | 디바이스 (분석축, FK→DIM_DEVICE). DEC-10 실배선: 실기기 해시SK / 방송=(해당없음) / 미매핑=0 |
| **광고비(원)** | `AD_COST` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 광고비(원) (#6). 원천별 컬럼 상이 — COST_TYPE 은 SILVER 보유 |
| **노출수** | `IMPRESSIONS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 노출수 (#23). DIGITAL 전용(방송 원천 부재) |
| **클릭수** | `CLICKS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 클릭수(행동 횟수, ≠회원명) (#24). DIGITAL 전용. CTR 분자 공#9 |
| **인입콜** | `INBOUND_CALL` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 인입콜 (#25). REBRDC(TEXT→TRY_TO_NUMBER)·VIDEO 보유, DGT 부재 |
| **대행사 전환수** | `AGENCY_CONV_MEMBERS` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 대행사 전환수(명) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발회원수가 혼입돼 있었다 — 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관했다. 혼입 규모 = 이슈원장 §O16. |
| **대행사 전환수** | `AGENCY_CONV_CNT` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 대행사 전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발건수가 혼입돼 있었고 그 비중이 과반이었다 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 혼입 규모 = 이슈원장 §O16. ⚠️합계가 소수로 나오므로 건수가 아니다 — 어의 현업확인 잔여(O5). |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 요일 (degen, AD_DATE 파생) |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 주차 (degen, AD_DATE 파생) |
| **AD_SOURCE_TYPE** | `AD_SOURCE_TYPE` | TEXT | YES | GOLD.FACT_AD_PERFORMANCE (fap) | 광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(DEC-8·§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단 |
| **PAGE_TYPE** | `PAGE_TYPE` | TEXT | YES | GOLD.FACT_AD_DIGITAL | 페이지유형 ← DGT.PAGE_TYPE_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **AD_GROUP_NM** | `AD_GROUP_NM` | TEXT | YES | GOLD.FACT_AD_DIGITAL | 광고그룹명 ← DGT.AD_GRP_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **GROUP_DIV** | `GROUP_DIV` | TEXT | YES | GOLD.FACT_AD_DIGITAL | 그룹구분 ← DGT.GRP_DIV_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CREATIVE_TYPE** | `CREATIVE_TYPE` | TEXT | YES | GOLD.FACT_AD_DIGITAL | 소재유형 ← DGT.MATR_TY_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **광고유형명** | `AD_TYPE_NM` | TEXT | YES | GOLD.FACT_AD_DIGITAL | 광고유형명(대행사 표기) ← DGT.AD_TY_NM. ⚠️코어 AD_SOURCE_TYPE(원천 출처축 DIGITAL/VIDEO/REBROADCAST)과 다른 개념 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **READ_CNT** | `READ_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | 읽음수 ← DGT.READ_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **MEDIA_POTENTIAL_CUST_CNT** | `MEDIA_POTENTIAL_CUST_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | 매체 잠재고객수 ← DGT.MEDIA_PTNT_CUST_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **디지털행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다. ⇒ 🔴 스코프를 디지털로 좁혀도 값은 나오지 않는다 — 이 컬럼은 현재 **어떤 스코프에서도 집계 불가**다(0/'해당없음' 대체 해석 금지 · P21). 정본 = 문서30 §7-C. |
| **CRM_DEV_CNT** | `CRM_DEV_CNT` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | CRM 개발건수 ← DGT.CRM_DVLP_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CTR_SRC** | `CTR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 CTR ← DGT.CTR. DW 재계산=CLICKS/IMPRESSIONS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CVR_SRC** | `CVR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 CVR ← DGT.CVR. DW 재계산=AGENCY_CONV_MEMBERS/CLICKS (O5 확정) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CPC_SRC** | `CPC_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 CPC ← DGT.CPC. DW 재계산=AD_COST/CLICKS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CPM_SRC** | `CPM_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 CPM ← DGT.CPM. DW 재계산=AD_COST/IMPRESSIONS×1000 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CPA_SRC** | `CPA_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 CPA ← DGT.CPA. DW 재계산=AD_COST/AGENCY_CONV_CNT ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **DEV_UNIT_PRICE_SRC** | `DEV_UNIT_PRICE_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 개발단가 ← DGT.DEV_UNIT_PRICE. DW 재계산=AD_COST/개발건수 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **VTR_SRC** | `VTR_SRC` | NUMBER | YES | GOLD.FACT_AD_DIGITAL | [비가산 N] 대행사 산정 VTR ← DGT.VTR. base 부재로 재계산 불가(대조 대상 아닌 유일값) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **TIME_BAND** | `TIME_BAND` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 시간대 ← VIDEO.TIME_RNG / REBRDC.TIME_RNG_DIV_NM(1순위)·BRDC_TIME(대체). 코어에서 이관(종전 CAST(NULL) 하드코딩) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CM_POSITION** | `CM_POSITION` | TEXT | YES | GOLD.FACT_AD_BROADCAST | CM위치 ← VIDEO.CM_AREA [VIDEO 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **RT** | `RT_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST | RT(재방송)유형 ← REBRDC.RE_BRDC_TY_NM [REBRDC 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **AD_START_TIME** | `AD_START_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429. |
| **AD_END_TIME** | `AD_END_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429. |
| **BROADCAST_DATE** | `BROADCAST_DATE` | DATE | YES | GOLD.FACT_AD_BROADCAST | 송출일 ← VIDEO.BRDC_DATE / REBRDC.DATE. ⚠️코어 PERF_DATE_SK(실적일)와 구분. 코어에서 이관 🔴[WIDE_AD_COMBINED] **송출일이며 코어의 실적일(PERF_DATE_SK)과 다른 축**이다 — 둘을 같은 시간축으로 섞지 말 것. 🟢본방송(VIDEO)·재방송(REBRDC) **양 원천 모두에 있다**(BRONZE `VIDEO_AD_CMPGN_DTLS.BRDC_DATE` · `REBRDC_AD_CMPGN_DTLS.DATE`) — 같은 방송 위성의 시각 3컬럼(AD_START_TIME·AD_END_TIME·PRG_START_TIME)이 VIDEO 전용인 것과 **다르다**. ⇒ 재방송을 포함한 **일자 단위** 방송 분석은 이 컬럼으로 가능하다. 디지털행은 원천 부재로 NULL. |
| **PROGRAM_NM** | `PROGRAM_NM` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 프로그램/편성명 ← VIDEO.SCHDL_NM / REBRDC.BRDC_NM ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CHANNEL_COMPANY** | `CHANNEL_COMPANY` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 채널사 ← VIDEO.CHNNL_NM / REBRDC.CHNNL_CMPNY ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CHANNEL_COMPANY_TYPE** | `CHANNEL_COMPANY_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 채널사유형 ← VIDEO.CHNNL_CMPNY_TY_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **SPOT_TYPE** | `SPOT_TYPE` | TEXT | YES | GOLD.FACT_AD_BROADCAST | SPOT유형 ← VIDEO.SPOT_TY [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **DURATION_SEC** | `DURATION_SEC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | 🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값의 스케일이 「초」로 읽으면 맞지 않는다(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 형식 행이 캐스팅에서 무성 소실돼 유효 커버리지가 매우 낮다(파싱하면 대부분 회복) — 규모 실측은 이슈원장 §O29. REBRDC NULL 은 결손이 아니라 원천 부재. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **DAY_DIV** | `DAY_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 요일구분 평일/주말 ← VIDEO.DAY_DIV_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **PRG_START_TIME** | `PRG_START_TIME` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용] 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429. |
| **CTV_DIV** | `CTV_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST | CTV구분 ← VIDEO.CTV_DIV_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **BRDC_DIV** | `BRDC_DIV` | TEXT | YES | GOLD.FACT_AD_BROADCAST | 방송구분 ← REBRDC.BRDC_DIV_NM [REBRDC 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **AD_CNT** | `AD_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | 광고횟수 ← VIDEO·REBRDC.AD_CNT (가산) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **CONV_CALL_CNT** | `CONV_CALL_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | 전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **VIDEO 행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다(REBROADCAST 원천에는 컬럼 자체가 없다). ⇒ 🔴 스코프를 VIDEO 로 좁혀도 값은 나오지 않는다 — **어떤 스코프에서도 집계 불가**다. ⚠️ 인입콜(`REBRDC.INBOUND_CALL_CNT`)은 채워져 있으니 **두 축을 혼동하지 말 것**. 정본 = 문서30 §7-C. |
| **DVLP_MEMBER_CNT** | `DVLP_MEMBER_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | 개발회원수 ← REBRDC.DVLP_MBER_CNT [REBRDC 전용]. ⚠️O16 이관: 종전에 코어 AGENCY_CONV_MEMBERS 로 혼입돼 있었다(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도를 유지하는 이유 = 원천에 0.5 단위 값이 실존해 정수 타입으로 내리면 반올림이 총합을 왜곡한다 — 해당 행·왜곡 규모는 이슈원장 §O16. 원천값 보존 우선. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **DVLP_CNT** | `DVLP_CNT` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | 개발건수 ← REBRDC.DVLP_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. |
| **BRDC_AD_VIEW_RT_SRC** | `BRDC_AD_VIEW_RT_SRC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | [비가산 N] 대행사 산정 광고시청률 ← VIDEO.AD_VIEW_RT [VIDEO 전용]. base 부재로 DW 재계산 불가 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것. |
| **BRDC_CPC_SRC** | `BRDC_CPC_SRC` | NUMBER | YES | GOLD.FACT_AD_BROADCAST | [비가산 N] 대행사 산정 CPC ← VIDEO.CPC(TEXT) [VIDEO 전용]. DW 재계산=AD_COST/CLICKS (DEC-9 대조용) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것. |

---

### 2.14 `WIDE_BIGQUERY_BEHAVIOR` — 웹/앱 BigQuery 행동 평탄화 뷰 (Web/App Behavior Mart)

#### 1. 뷰 개요 (Overview)
- **목적**: Google Analytics / Firebase BigQuery 원천의 웹/앱 페이지뷰, 이벤트, 사용자 행동 로그 팩트에 일자·이벤트·유입소스·디바이스·캠페인·회원식별 차원을 결합한 행동 분석 뷰
- **분석 Grain**: `행동일(DATE_SK) × 세션/이벤트 × 디바이스`
- **기준 Fact 테이블**: `GOLD.FACT_BIGQUERY_BEHAVIOR (f)`
- **조인 Dimension 테이블**: 6개 차원 결합

#### 2. 조인 및 관계 정의 (Join Logic)
- **기준 테이블**: `GOLD.FACT_BIGQUERY_BEHAVIOR (f)`
- **조인 상세 규칙**:
  - `LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK`
  - `LEFT JOIN GOLD.DIM_BIGQUERY_EVENT (ge) ON f.BIGQUERY_EVENT_SK = ge.BIGQUERY_EVENT_SK`
  - `LEFT JOIN GOLD.DIM_BIGQUERY_SOURCE (gs) ON f.BIGQUERY_SOURCE_SK = gs.BIGQUERY_SOURCE_SK`
  - `LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK`
  - `LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK`
  - `LEFT JOIN GOLD.DIM_MEMBER_IDENTITY (mi) ON f.IDENTITY_SK = mi.IDENTITY_SK`

#### 3. 확장 컬럼 정의서 (Column Definition Sheet)

| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |
|---|---|---|---|---|---|
| **일자키(YYYYMMDD)** | `DATE_SK` | NUMBER | NO | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 행동 발생일 YYYYMMDD |
| **PAGE_PATH** | `PAGE_PATH` | TEXT | NO | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 페이지경로+쿼리 (#105) |
| **페이지위치** | `PAGE_LOCATION` | TEXT | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 페이지위치(URL 전체) |
| **방문수** | `VISITS` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 방문수 |
| **EVENT_CNT** | `EVENT_CNT` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 이벤트수 |
| **VIEW_CNT** | `VIEW_CNT` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 조회수 |
| **SESSION_CNT** | `SESSION_CNT` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 세션수 |
| **ENGAGED_SESSIONS** | `ENGAGED_SESSIONS` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 참여세션수 |
| **SCROLL_DEPTH** | `SCROLL_DEPTH` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 스크롤깊이 — 재합산 금지 |
| **ACTIVE_USERS** | `ACTIVE_USERS` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 활성사용자 — 재합산 금지 |
| **TOTAL_USERS** | `TOTAL_USERS` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 총사용자 — 재합산 금지 |
| **AVG_SESSION_DURATION** | `AVG_SESSION_DURATION` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 평균세션시간 — 재합산 금지 (#98) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. BigQuery 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F. |
| **BOUNCE_RATE** | `BOUNCE_RATE` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 이탈율 — 재합산 금지 (#108) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. BigQuery 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F. |
| **ENGAGEMENT_RATE** | `ENGAGEMENT_RATE` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 참여율 — 재합산 금지 |
| **AVG_ENGAGEMENT_TIME_PER_SESSION** | `AVG_ENGAGEMENT_TIME_PER_SESSION` | NUMBER | YES | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | [비가산] 세션당 평균참여시간 — 재합산 금지 |
| **원천시스템** | `DW_SOURCE_SYSTEM` | TEXT | NO | GOLD.FACT_BIGQUERY_BEHAVIOR (f) | 원천 시스템 식별 |
| **전체일자** | `FULL_DATE` | DATE | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.FULL_DATE — 실제 일자 |
| **연도** | `YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.YEAR — 년 🔴🔴[O51-F 실측] **단일값이다 — BigQuery 실적재가 한 해의 일부 구간뿐이다**(G-5 하드블로커). 연도별·계절별 추이를 이 뷰로 산출하면 **구간 하나를 전체로 오독**한다. ⇒ 기간 비교는 광고·회원 팩트로 하고, BigQuery 지표는 해당 구간 내부 분석에만 쓸 것. 실측 규모는 이슈원장 §O51-F. |
| **월** | `MONTH` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.MONTH — 월 |
| **요일** | `DAY_OF_WEEK` | TEXT | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.DAY_OF_WEEK — 요일 |
| **주차** | `WEEK_OF_YEAR` | NUMBER | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.WEEK_OF_YEAR — 주차 |
| **휴일여부** | `IS_HOLIDAY` | BOOLEAN | YES | GOLD.DIM_DATE (일자 차원) | DIM_DATE.IS_HOLIDAY — 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F. |
| **IDENTITY_MEMBER_DK** | `IDENTITY_MEMBER_DK` | TEXT | YES | GOLD.DIM_MEMBER_IDENTITY (회원 식별 차원) | DIM_MEMBER_IDENTITY.MEMBER_DK — 불변 회원키 |
| **IDENTITY_MEMBER_NO** | `IDENTITY_MEMBER_NO` | TEXT | YES | GOLD.DIM_MEMBER_IDENTITY (회원 식별 차원) | DIM_MEMBER_IDENTITY.MEMBER_NO — 회원번호 (#110) |
| **IDENTITY_MEMNUM** | `IDENTITY_MEMNUM` | TEXT | YES | GOLD.DIM_MEMBER_IDENTITY (회원 식별 차원) | DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BIGQUERY_BEHAVIOR.IDENTITY_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴익명 세션이 다수라 회원번호가 붙지 않는다 — 회원 귀속 분석은 `IDENTITY_SK` 를 `DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 unknown 비중을 분모에서 제외할지 먼저 정할 것(O49). 실측 규모는 이슈원장 §O51-F. |
| **IDENTITY_BIGQUERY_MEMBER_ID** | `IDENTITY_BIGQUERY_MEMBER_ID` | TEXT | YES | GOLD.DIM_MEMBER_IDENTITY (회원 식별 차원) | DIM_MEMBER_IDENTITY.BIGQUERY_MEMBER_ID — BigQuery member_id (#112) |
| **BIGQUERY_EVENT_CATEGORY** | `BIGQUERY_EVENT_CATEGORY` | TEXT | YES | GOLD.DIM_BIGQUERY_EVENT (BigQuery 이벤트 차원) | DIM_BIGQUERY_EVENT.EVENT_CATEGORY — 이벤트 카테고리 (#99) |
| **BIGQUERY_EVENT_LABEL** | `BIGQUERY_EVENT_LABEL` | TEXT | YES | GOLD.DIM_BIGQUERY_EVENT (BigQuery 이벤트 차원) | DIM_BIGQUERY_EVENT.EVENT_LABEL — 이벤트 라벨 (#100) |
| **BIGQUERY_EVENT_ACTION** | `BIGQUERY_EVENT_ACTION` | TEXT | YES | GOLD.DIM_BIGQUERY_EVENT (BigQuery 이벤트 차원) | DIM_BIGQUERY_EVENT.EVENT_ACTION — 이벤트 액션 (#101) |
| **BIGQUERY_UTM_SOURCE** | `BIGQUERY_UTM_SOURCE` | TEXT | YES | GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원) | DIM_BIGQUERY_SOURCE.UTM_SOURCE — source |
| **BIGQUERY_UTM_MEDIUM** | `BIGQUERY_UTM_MEDIUM` | TEXT | YES | GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원) | DIM_BIGQUERY_SOURCE.UTM_MEDIUM — medium |
| **BIGQUERY_UTM_CONTENT** | `BIGQUERY_UTM_CONTENT` | TEXT | YES | GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원) | DIM_BIGQUERY_SOURCE.UTM_CONTENT — 세션 수동 광고 콘텐츠 (#103) |
| **BIGQUERY_UTM_TERM** | `BIGQUERY_UTM_TERM` | TEXT | YES | GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원) | DIM_BIGQUERY_SOURCE.UTM_TERM — 세션 수동 검색어 (#104) |
| **BIGQUERY_SOURCE_MEDIUM** | `BIGQUERY_SOURCE_MEDIUM` | TEXT | YES | GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원) | DIM_BIGQUERY_SOURCE.SOURCE_MEDIUM — 세션 소스/매체 (#109) |
| **DEVICE_TYPE** | `DEVICE_TYPE` | TEXT | YES | GOLD.DIM_DEVICE (디바이스 차원) | DIM_DEVICE.DEVICE_TYPE — PC / M / APP |
| **캠페인코드(BK)** | `CAMPAIGN_BK` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인브랜드** | `CAMPAIGN_BRAND` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F. |
| **캠페인명** | `CAMPAIGN_NAME` | TEXT | YES | GOLD.DIM_CAMPAIGN (캠페인 차원) | DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F. |

---

_Co-authored with CoCo_


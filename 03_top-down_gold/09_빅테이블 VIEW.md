<!-- LLM-METADATA
doc_id: GOLD_WIDE_VIEWS
doc_role: consumption_wide_view (설계 참고본 — 비실행. 물리 정본 = dbt 모델)
project: GN_DW (굿네이버스)
derived_from: 06_DDL.sql + 03_테이블 설계.md §4 팩트×차원 참조
structure: 12 WIDE VIEW 수록 — ⚠️ 실제 GOLD dbt 뷰는 16개(O50). 이 문서는 12/16 만 담는다.
status: 🔴 강등(2026-08-07 O50) — 비실행 설계 참고본. 물리 뷰·COMMENT 정본 = `10_dbt_pipeline/models/gold/{wide,dim}/*.sql`
END-METADATA -->

# GOLD 빅테이블 VIEW (GN_DW.GOLD)

> 🔴🔴 **[2026-08-07 O50] 위상 강등 — 이 문서의 `CREATE OR REPLACE VIEW` 문을 실행하지 말 것.**
> **물리 뷰의 소유주는 dbt** 다(`models/gold/wide/` 14 + `models/gold/dim/` 2 = **16 view 모델**).
> 이 문서는 그중 **12개만** 수록하며 `FACT_DEV_ACHIEVEMENT (구 `WIDE_DEV_ACHIEVEMENT` · 2026-08-10 O53 개명·테이블화)`(O38) · `WIDE_MEMBER_FEE`(O45) ·
> `DIM_MEMBER_CURRENT` · `DIM_MEMBER_ACQUISITION` **4종이 누락**돼 있다.
> ⚠️ 누락 2종은 하위 Semantic View 의 **base** 다(`SV_DEV_ACHIEVEMENT` · `SV_MEMBER_FEE`) —
> 이 문서만 보고 뷰 계층을 파악하면 **소비 계층의 절반을 놓친다.**
> ⚠️ 여기의 DDL 을 실행하면 dbt 가 만든 뷰를 **구 정의로 덮고**, 다음 `dbt build` 가 다시 되돌린다
> (조용한 왕복 drift). 정의를 바꾸려면 **dbt 모델을 고칠 것.**
> 용도: 평탄화 **설계 의도·조인 시맨틱·DEC 근거**의 열람. 아래 §1 설계 원칙은 여전히 유효하다.
> ⚠️ §1 의 *"팩트 12개 = 1 per FACT"* 전제도 **이미 깨졌다** — `FACT_DEV_ACHIEVEMENT` 는 팩트 2개
> (FTG_D×FME)의 conform 뷰이고, `FACT_MEMBER_COHORT` 에는 대응 WIDE 가 없다.

팩트를 각각 참조 DIM과 LEFT JOIN하여 평탄화한 소비용 VIEW. 스타스키마 정합성은 원본 테이블이 유지하고, VIEW는 현업 셀프서비스용(물리 저장 0).

> ⚠️ **[2026-07-28 순서9-I] 개수 정정** — AGENCY 광고 위성 팩트 3종 신설(DEC-8)로 WIDE 는 **9 → 12개**다.
> 문서50·문서00 의 "13종" 표기는 `models/gold/wide/` 파일 수(`.sql` 12 + `_wide_schema.yml` 1)를
> 모델 수로 오산한 값이었다(실측: GOLD VIEW 12 · dbt view 모델 12). **정본 = 12.**

---

## 1. 설계 원칙

| 항목 | 규칙 |
|------|------|
| 스키마 / 네이밍 | `GN_DW.GOLD` · `WIDE_<FACT명>` |
| **DIM_MEMBER** | 팩트가 `MEMBER_DK`(durable) 보유 → 현재버전 속성: `IS_CURRENT=TRUE` + **DK당 1행 dedup 서브쿼리**(§2) |
| **DIM_ORG** | 팩트가 `ORG_SK`(버전 SK) 보유 → **PK 직결 조인(as-was)**, `IS_CURRENT` 미사용 |
| **월 grain** | `DIM_DATE` 미조인(월당 다수 일자와 fan-out). `CAL_YEAR=FLOOR(MONTH_KEY/100)`, `CAL_MONTH=MOD(MONTH_KEY,100)` 파생 |
| **일 grain** | `DIM_DATE`를 `DATE_SK`(PK) LEFT JOIN |
| 조인 방향 | 전부 LEFT JOIN(팩트 행 보존) |
| 컬럼 | SK 제외, BK/명칭 포함. DIM 속성은 `DIM약칭_` 접두로 출력명 유일성 확보 |
| 비가산 measure | 컬럼 유지 + 뷰 COMMENT에 재합산 금지 명시(FGA) |
| **위성 팩트 measure 노출 (DEC-13)** | **1:1 위성**(FAD_B·FAD_D)은 코어 measure **동반 노출**(fan-out 없음 → 단일 뷰 완결). **1:N 위성**(FAD_BC)은 코어 measure **미노출**(사례 수만큼 중복 합산). ⚠️ 위성 뷰와 코어 뷰를 **함께 합산하면 이중계상** — 전 유형 집계는 코어 뷰만 사용 |
| **대행사 파생 `_SRC` (DEC-9)** | 비가산(N) — 행 단위 참조·대조 전용. 집계는 base 재계산(예: `SUM(CLICKS)/SUM(IMPRESSIONS)`) |
| 감사컬럼 | 팩트 `DW_SOURCE_SYSTEM`만 유지 |

**조인 시맨틱**: 회원=현재버전 속성(팩트에 SK 부재로 as-was 불가), 조직=**SCD1 current-value**. 팩트의 `ORG_SK`는 사건 시점 부서 *식별*은 주지만 부서명·계층 속성은 최신값(SCD1)이다. 조직 재편 이전 편제로의 as-was 조회는 미지원(요구 없음·조직 이력소스 없음).

---

## 2. SCD2 회원 dedup 패턴

모든 회원 조인은 아래 서브쿼리를 사용(뷰마다 필요한 컬럼만 SELECT). `IS_CURRENT` 다중행·중복 적재가 있어도 DK당 1행만 남아 fan-out을 차단한다.

```sql
LEFT JOIN (
    SELECT MEMBER_DK, <needed cols...>
    FROM GN_DW.GOLD.DIM_MEMBER
    WHERE IS_CURRENT = TRUE
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC
    ) = 1
) m ON f.MEMBER_DK = m.MEMBER_DK
```

---

## 3. VIEW DDL (14개)

### 1. WIDE_MEMBER_MONTHLY (FMM)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_MEMBER_MONTHLY
  COMMENT = '회원 월 팩트 평탄화 (FMM × MEMBER[현재버전]·CAMPAIGN·SPONSORSHIP·PAYMENT·REASON). 월 grain=MONTH_KEY.'
AS
SELECT
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100)   AS CAL_YEAR,
    MOD(f.MONTH_KEY, 100)      AS CAL_MONTH,
    f.MEMBER_DK,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.UNPAID_CNT,
    f.ACTIVE_CNT, f.ACTIVE_MEMBERS,
    f.ACTIVE_CUM_CNT, f.ACTIVE_CUM_MEMBERS,
    f.INCREASE_CNT, f.INCREASE_MEMBERS,
    f.DECREASE_CNT, f.CHURN_CNT,
    f.YEAR_START_ACTIVE_CNT, f.YEAR_END_ACTIVE_CNT,
    f.MONTH_END_ACTIVE_CNT, f.PREV_MONTH_END_ACTIVE_CNT,
    f.CAMPAIGN_UNPAID_CNT, f.STATUS_UNPAID_CNT,
    f.REGULAR_FEE, f.REGULAR_ONETIME_FEE, f.ONETIME_ONETIME_FEE,
    f.PAID_FEE, f.BILLED_AMT,
    f.INBOUND_CALL_CNT, f.TS_CALL_CNT,
    f.DEV_TYPE, f.NEW_FLAG, f.INCREASE_FLAG, f.REDONATE_FLAG,
    f.JOIN_DATE, f.STOP_DATE,
    f.AMOUNT_BAND1, f.AMOUNT_BAND2, f.PERIOD_BAND1, f.PERIOD_BAND2,
    f.SPONSOR_MONTHS, f.SPONSOR_YEARS, f.PAID_MONTHS,
    f.NEW_EXISTING_FLAG, f.UNPAID_FLAG_BOM, f.UNPAID_FLAG_EOM,
    f.DW_SOURCE_SYSTEM,
    m.GENDER              AS MEMBER_GENDER,
    m.REGION              AS MEMBER_REGION,
    m.AGE_BAND            AS MEMBER_AGE_BAND,
    m.MEMBER_STATUS       AS MEMBER_STATUS,
    m.MEMBER_TYPE         AS MEMBER_TYPE,
    m.NEW_EXISTING_FLAG   AS MEMBER_NEW_EXISTING,
    m.FIRST_JOIN_DATE     AS MEMBER_FIRST_JOIN_DATE,
    m.FIRST_CAMPAIGN      AS MEMBER_FIRST_CAMPAIGN,
    m.ENROLL_PATH         AS MEMBER_ENROLL_PATH,
    m.FIRST_SPONSORSHIP   AS MEMBER_FIRST_SPONSORSHIP,
    m.CURRENT_SPONSORSHIP AS MEMBER_CURRENT_SPONSORSHIP,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     AS CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME,
    c.PROMO_METHOD        AS CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       AS CAMPAIGN_TYPE,
    s.SPONSORSHIP_BK      AS SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    AS SPONSORSHIP_NAME,
    s.SPONSORSHIP_ABBR    AS SPONSORSHIP_ABBR,
    p.PAYMENT_METHOD      AS PAYMENT_METHOD,
    p.SETTLE_METHOD       AS PAYMENT_SETTLE_METHOD,
    p.FEE_TYPE            AS PAYMENT_FEE_TYPE,
    r.REASON_CODE         AS REASON_CODE,
    r.REASON_NAME         AS REASON_NAME,
    r.REASON_TYPE         AS REASON_TYPE
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY f
LEFT JOIN (
    SELECT MEMBER_DK, GENDER, REGION, AGE_BAND, MEMBER_STATUS, MEMBER_TYPE,
           NEW_EXISTING_FLAG, FIRST_JOIN_DATE, FIRST_CAMPAIGN, ENROLL_PATH,
           FIRST_SPONSORSHIP, CURRENT_SPONSORSHIP
    FROM GN_DW.GOLD.DIM_MEMBER
    WHERE IS_CURRENT = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m ON f.MEMBER_DK = m.MEMBER_DK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN     c ON f.CAMPAIGN_SK    = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP  s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
LEFT JOIN GN_DW.GOLD.DIM_PAYMENT      p ON f.PAYMENT_SK     = p.PAYMENT_SK
LEFT JOIN GN_DW.GOLD.DIM_REASON       r ON f.REASON_SK      = r.REASON_SK;
```

### 2. WIDE_MEMBER_EVENT (FME)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_MEMBER_EVENT
  COMMENT = '회원 이벤트 팩트 평탄화 (FME × DATE·MEMBER[현재버전]·CAMPAIGN·SPONSORSHIP·ORG[as-was]·REASON).'
AS
SELECT
    f.DATE_SK, f.MEMBER_DK, f.EVENT_TYPE,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.STOP_MEMBERS,
    f.UNPAID_STOP_CNT, f.UNPAID_STOP_MEMBERS,
    f.JOIN_DATE, f.STOP_DATE, f.STOP_REASON, f.STOP_CHANNEL, f.NEW_EXISTING_FLAG,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.QUARTER, d.IS_HOLIDAY,
    m.GENDER              AS MEMBER_GENDER,
    m.REGION              AS MEMBER_REGION,
    m.AGE_BAND            AS MEMBER_AGE_BAND,
    m.MEMBER_STATUS       AS MEMBER_STATUS,
    m.MEMBER_TYPE         AS MEMBER_TYPE,
    m.ENROLL_PATH         AS MEMBER_ENROLL_PATH,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     AS CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME,
    c.PROMO_METHOD        AS CAMPAIGN_PROMO_METHOD,
    s.SPONSORSHIP_BK      AS SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    AS SPONSORSHIP_NAME,
    o.CORP                AS ORG_CORP,
    o.DIVISION            AS ORG_DIVISION,
    o.DEPARTMENT          AS ORG_DEPARTMENT,
    o.TEAM                AS ORG_TEAM,
    r.REASON_CODE         AS REASON_CODE,
    r.REASON_NAME         AS REASON_NAME,
    r.REASON_TYPE         AS REASON_TYPE
FROM GN_DW.GOLD.FACT_MEMBER_EVENT f
LEFT JOIN GN_DW.GOLD.DIM_DATE d ON f.DATE_SK = d.DATE_SK
LEFT JOIN (
    SELECT MEMBER_DK, GENDER, REGION, AGE_BAND, MEMBER_STATUS, MEMBER_TYPE, ENROLL_PATH
    FROM GN_DW.GOLD.DIM_MEMBER
    WHERE IS_CURRENT = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m ON f.MEMBER_DK = m.MEMBER_DK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN    c ON f.CAMPAIGN_SK    = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
LEFT JOIN GN_DW.GOLD.DIM_ORG         o ON f.ORG_SK         = o.ORG_SK
LEFT JOIN GN_DW.GOLD.DIM_REASON      r ON f.REASON_SK      = r.REASON_SK;
```

### 3. WIDE_TARGET_DEV (FTG_D)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_TARGET_DEV
  COMMENT = '회원개발 목표 평탄화 (FTG_D × ORG[as-was]). 월 grain=MONTH_KEY.'
AS
SELECT
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) AS CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    AS CAL_MONTH,
    f.DEV_TYPE, f.GOAL_CNT, f.DW_SOURCE_SYSTEM,
    o.CORP AS ORG_CORP, o.DIVISION AS ORG_DIVISION,
    o.DEPARTMENT AS ORG_DEPARTMENT, o.TEAM AS ORG_TEAM
FROM GN_DW.GOLD.FACT_TARGET_DEV f
LEFT JOIN GN_DW.GOLD.DIM_ORG o ON f.ORG_SK = o.ORG_SK;
```

> 🔴 **[2026-08-05 O38]** `CAL_YEAR` 는 O38 이전에 **전건 0** 이었다. DIM_DATE 조인 실패나 센티넬이
> 아니라 `FACT_TARGET_DEV.MONTH_KEY` 가 **1~12 월 번호**여서 `FLOOR(MONTH_KEY/100)` 이 0 을 낸
> 자릿수 문제였다. 연도 복원으로 해소. 목표 대비 실적은 아래 `FACT_DEV_ACHIEVEMENT` 소관.

### 3-A. FACT_DEV_ACHIEVEMENT (FTG_D × FME) — 목표 대비 실적 [신설 2026-08-05 O38]

마케팅 장표 「1. 개발현황(목표, 실적)」 정본이며 정본 지표 **공#1(월 목표 달성율)·#2(누계)·#3(연)** 의 산출 base 다.
정본 SQL = dbt 모델 `models/gold/wide/FACT_DEV_ACHIEVEMENT.sql`(설계 근거·실측치는 모델 헤더 주석).

설계 요점 5가지 — 각각 실측 근거가 있다:

1. **grain = `MONTH_KEY × ORG_SK × DEV_TYPE`** (목표 팩트 grain). 실적(일 grain)을 월로 롤업해 맞춘다.
   conform 성립 근거: `DEV_TYPE` 목표 도메인 `{1,2,4}` = 정본 공#121 개발 정의와 **정확히 일치**하고
   목표 조직 234종 ⊆ 실적 조직 349종(목표에만 있는 조직 **0**).
2. **FULL OUTER JOIN** — 한쪽만 있는 조합이 양방향으로 실재한다(목표는 미래월까지, 실적은 목표 편성
   이전 기간까지). INNER 로 묶으면 목표 미달 부서가 집계에서 조용히 사라져 달성율이 과대해진다.
3. **달성율 컬럼 미보유** — `SUM(실적)/SUM(목표)` 로 재계산한다. 행 단위 비율을 저장하면 상위 집계가
   **비율의 평균**을 내게 되고 이는 항상 틀린다. `WIDE_BUDGET`(집행율 미보유·`SV_BUDGET` 산출) 선례.
4. **달성율 스코프 가드 = `HAS_POSITIVE_GOAL`(=`GOAL_CNT > 0`)** (🔴 `HAS_GOAL_ROW` 가 아니다).
   실측 대조(2026-08-05): 정본 스코프 **34.60%** / 미스코프(전체 실적÷전체 목표) **49.59%** /
   `HAS_GOAL` 스코프 **41.16%(틀린 값)**.
   🔴 **왜 「행 존재」로 스코프하면 틀리는가**: 목표 행의 과반이 `GOAL_CNT` 0 또는 NULL 이다
   (25,344 중 **14,667행 = 57.9%** — 0 이 14,660 · NULL 이 7). 그 행들은 행이 존재하므로
   실적 **303,235건**이 분자에 들어가는데 분모 기여는 0 이다 → 비율이 폭증했다
   (실측 증액 **537.1%** · 재후원 **1700.9%**). 교정 후 전 구분 100% 이하
   (신규 34.3% · 증액 65.9% · 재후원 74.3%).
   🔴 **원인은 결측이 아니라 원천의 행 생성 방식이다**(BRONZE 재스캔으로 확인):
   **2020년부터** CRM 이 `부서 × 월 × 개발구분 3코드` 조합을 **전량 행으로 만들고 미편성분을 0 으로
   채운다**(2019년 1,008행 → 2020년 2,844행. 2021년만 축소). 그 결과 개발목표는 사실상
   **「신규」에만 편성**되고 증액은 4개 연도·재후원은 1개 연도에만 있다(O38-D 현업 확인 대기).
   ✅ **조치는 COMMENT 가 아니라 개명이었다**: 단일 `HAS_GOAL` 은 이름이 「목표 편성」으로 읽혀
   계속 오용될 수 있으므로 **`HAS_GOAL_ROW`(행 존재) / `HAS_POSITIVE_GOAL`(값 편성)** 으로 분리했다.
   → 교훈: **「키가 존재한다」와 「값이 편성됐다」는 다르다.** 비율 스코프는 행 존재가 아니라
     **분모 값의 유효성**으로 잡고, 비율 metric 은 **100% 초과 여부를 반드시 스모크**한다.
     그리고 오해를 부르는 식별자는 주석이 아니라 **이름으로** 고친다.
5. **일별 실적 미포함** — 월 목표를 일자에 반복 배치하면 일수만큼 목표가 부풀어 이중계상된다.
   장표의 「일별 실적」축은 `WIDE_MEMBER_EVENT`(일 grain, O38 로 부서 축 활성)에서 조회한다.

⚠️ `_YTD`·`_YEAR` 컬럼은 **월에 대해 비가산**(semi-additive) — 조직·구분 축으로는 더해도 되지만
월을 가로질러 더하면 같은 값이 반복 누적된다.
⚠️ 장표의 **매체명(브랜드2)** 축은 이 뷰에 없다 — 정본 마케팅 인벤토리 §1 이 *"현재 CRM상에 부서별
목표만 존재하며 매체별 목표는 확인 불가"* 로 명시한다. 실적측 매체 축은 `DIM_AD_CREATIVE.MEDIA_NAME`
(106종)에 실재하나 `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 가 전건 센티넬이라 **도달 불가**(P52).

### 4. WIDE_TARGET_BIZ (FTG_B)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_TARGET_BIZ
  COMMENT = '사업 목표 평탄화 (FTG_B × ORG[as-was]·SPONSORSHIP·CAMPAIGN). 월 grain=MONTH_KEY.'
AS
SELECT
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) AS CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    AS CAL_MONTH,
    f.ANNUAL_GOAL_CNT, f.SUPP_GOAL_CNT,
    f.ANNUAL_CUM_GOAL_CNT, f.SUPP_CUM_GOAL_CNT,
    f.DW_SOURCE_SYSTEM,
    o.CORP AS ORG_CORP, o.DIVISION AS ORG_DIVISION,
    o.DEPARTMENT AS ORG_DEPARTMENT, o.TEAM AS ORG_TEAM,
    s.SPONSORSHIP_BK AS SPONSORSHIP_BK, s.SPONSORSHIP_NAME AS SPONSORSHIP_NAME,
    c.CAMPAIGN_BK AS CAMPAIGN_BK, c.BRAND AS CAMPAIGN_BRAND, c.CAMPAIGN_NAME AS CAMPAIGN_NAME
FROM GN_DW.GOLD.FACT_TARGET_BIZ f
LEFT JOIN GN_DW.GOLD.DIM_ORG         o ON f.ORG_SK         = o.ORG_SK
LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN    c ON f.CAMPAIGN_SK    = c.CAMPAIGN_SK;
```

### 5. WIDE_SERVICE_EVENT (FSE)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_SERVICE_EVENT
  COMMENT = '서비스/발송 팩트 평탄화 (FSE × DATE·MEMBER[현재버전]·SERVICE·CAMPAIGN).'
AS
SELECT
    f.DATE_SK, f.MEMBER_DK,
    f.SEND_MEMBERS, f.SUCCESS_MEMBERS, f.FAIL_MEMBERS, f.OPEN_MEMBERS,
    f.LETTER_PART_MEMBERS, f.LETTER_PART_CNT,
    f.GIFT_PART_MEMBERS, f.GIFT_PART_AMT,
    f.D5_LETTER_PART_MEMBERS, f.D5_LETTER_PART_CNT,
    f.D5_GIFT_PART_MEMBERS, f.D5_GIFT_PART_CNT,
    f.D5_INCREASE_PART_MEMBERS, f.D5_INCREASE_PART_CNT,
    f.D5_STOP_MEMBERS, f.D5_STOP_CNT,
    f.SERVICE_MEMBERS, f.SERVICE_CNT,
    f.SEND_TITLE, f.SEND_STATUS, f.SEND_STATUS2, f.SEND_TYPE,
    f.MAIL_RECEIVE_FLAG, f.MEMBER_STOP_FLAG,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    m.GENDER              AS MEMBER_GENDER,
    m.REGION              AS MEMBER_REGION,
    m.AGE_BAND            AS MEMBER_AGE_BAND,
    m.MEMBER_STATUS       AS MEMBER_STATUS,
    m.MEMBER_TYPE         AS MEMBER_TYPE,
    sv.SEND_TYPE_L        AS SERVICE_SEND_TYPE_L,
    sv.SEND_TYPE_M        AS SERVICE_SEND_TYPE_M,
    sv.SEND_TYPE_S        AS SERVICE_SEND_TYPE_S,
    sv.SUBTYPE            AS SERVICE_SUBTYPE,
    sv.CHANNEL            AS SERVICE_CHANNEL,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     AS CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME,
    c.PROMO_METHOD        AS CAMPAIGN_PROMO_METHOD
FROM GN_DW.GOLD.FACT_SERVICE_EVENT f
LEFT JOIN GN_DW.GOLD.DIM_DATE d ON f.DATE_SK = d.DATE_SK
LEFT JOIN (
    SELECT MEMBER_DK, GENDER, REGION, AGE_BAND, MEMBER_STATUS, MEMBER_TYPE
    FROM GN_DW.GOLD.DIM_MEMBER
    WHERE IS_CURRENT = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m ON f.MEMBER_DK = m.MEMBER_DK
LEFT JOIN GN_DW.GOLD.DIM_SERVICE  sv ON f.SERVICE_SK  = sv.SERVICE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN c  ON f.CAMPAIGN_SK = c.CAMPAIGN_SK;
```

### 6. WIDE_GA_BEHAVIOR (FGA)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_GA_BEHAVIOR
  COMMENT = 'GA 행동 팩트 평탄화 (FGA × DATE·IDENTITY·GA_EVENT·GA_SOURCE·DEVICE·CAMPAIGN). 비가산 지표(율·평균·사용자수) 상위 재합산 금지.'
AS
SELECT
    f.DATE_SK, f.PAGE_PATH, f.PAGE_LOCATION,
    f.VISITS, f.EVENT_CNT, f.VIEW_CNT, f.SESSION_CNT, f.ENGAGED_SESSIONS,
    f.SCROLL_DEPTH, f.ACTIVE_USERS, f.TOTAL_USERS,
    f.AVG_SESSION_DURATION, f.BOUNCE_RATE, f.ENGAGEMENT_RATE,
    f.AVG_ENGAGEMENT_TIME_PER_SESSION,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    i.MEMBER_DK           AS IDENTITY_MEMBER_DK,
    i.MEMBER_NO           AS IDENTITY_MEMBER_NO,
    i.MEMNUM             AS IDENTITY_MEMNUM,
    i.GA_MEMBER_ID        AS IDENTITY_GA_MEMBER_ID,
    ge.EVENT_CATEGORY     AS GA_EVENT_CATEGORY,
    ge.EVENT_LABEL        AS GA_EVENT_LABEL,
    ge.EVENT_ACTION       AS GA_EVENT_ACTION,
    gs.UTM_SOURCE         AS GA_UTM_SOURCE,
    gs.UTM_MEDIUM         AS GA_UTM_MEDIUM,
    gs.UTM_CONTENT        AS GA_UTM_CONTENT,
    gs.UTM_TERM           AS GA_UTM_TERM,
    gs.SOURCE_MEDIUM      AS GA_SOURCE_MEDIUM,
    dv.DEVICE_TYPE        AS DEVICE_TYPE,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME
FROM GN_DW.GOLD.FACT_GA_BEHAVIOR f
LEFT JOIN GN_DW.GOLD.DIM_DATE            d  ON f.DATE_SK      = d.DATE_SK
LEFT JOIN GN_DW.GOLD.DIM_MEMBER_IDENTITY i  ON f.IDENTITY_SK  = i.IDENTITY_SK
LEFT JOIN GN_DW.GOLD.DIM_GA_EVENT        ge ON f.GA_EVENT_SK  = ge.GA_EVENT_SK
LEFT JOIN GN_DW.GOLD.DIM_GA_SOURCE       gs ON f.GA_SOURCE_SK = gs.GA_SOURCE_SK
LEFT JOIN GN_DW.GOLD.DIM_DEVICE          dv ON f.DEVICE_SK    = dv.DEVICE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN        c  ON f.CAMPAIGN_SK  = c.CAMPAIGN_SK;
```

### 7. WIDE_AD_PERFORMANCE (FAD) — 코어

> ⚠️ **[2026-07-28 순서9-I DEC-8]** 코어에서 위성으로 **이관된 방송 degen 5종**
> (`TIME_BAND`·`CM_POSITION`·`RT_TYPE`·`AD_START_TIME`·`BROADCAST_DATE`)은 본 뷰에서 **제거**됐다 → `WIDE_AD_BROADCAST`.
> ⚠️ **`AD_SOURCE_TYPE`(코어 degen = 원천 출처축)** 과 **`AD_CREATIVE_TYPE`(`DIM_AD_CREATIVE.AD_TYPE` = 소재 광고유형)** 은
> **다른 개념**이다(DEC-12 분리 명명). 종전 둘 다 `AD_TYPE` 이라 WIDE 평탄화에서 충돌했다.
> ⚠️ `AD_PERF_DK`(DEC-11) = grain 겸 **위성 뷰 조인키**. `DEVICE_SK` 는 DEC-10 으로 실배선(방송행 = `(해당없음)`).
> ⚠️ `CAMPAIGN_SK`·`AD_CREATIVE_SK` 는 여전히 0 스캐폴드(Q10·소재 부분키 대기) → 관련 컬럼 NULL.
> 구현 = `10_dbt_pipeline/models/gold/wide/WIDE_AD_PERFORMANCE.sql`

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_AD_PERFORMANCE
  COMMENT = '광고 성과 코어 팩트 평탄화 (FAD × DATE·CAMPAIGN·AD_CREATIVE·DEVICE, grain=AD_PERF_DK). DIM_DATE 파생은 PERF_ 접두. 유형 고유속성은 WIDE_AD_BROADCAST/DIGITAL/BROADCAST_CASE 참조.'
AS
SELECT
    f.AD_PERF_DK,
    f.PERF_DATE_SK,
    f.AD_COST, f.IMPRESSIONS, f.CLICKS, f.INBOUND_CALL,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,          -- O16 교정 후 디지털 전용
    f.DAY_OF_WEEK, f.WEEK_OF_YEAR,
    f.AD_SOURCE_TYPE,                          -- DIGITAL/VIDEO/REBROADCAST (출처 명시축)
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE           AS PERF_FULL_DATE,
    d.YEAR                AS PERF_YEAR,
    d.MONTH               AS PERF_MONTH,
    d.QUARTER             AS PERF_QUARTER,
    d.IS_HOLIDAY          AS PERF_IS_HOLIDAY,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     AS CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME,
    c.PROMO_METHOD        AS CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       AS CAMPAIGN_TYPE,
    ac.AD_CREATIVE_BK     AS AD_CREATIVE_BK,
    ac.MEDIA_NAME         AS AD_MEDIA_NAME,
    ac.PLATFORM           AS AD_PLATFORM,
    ac.PLATFORM_TYPE      AS AD_PLATFORM_TYPE,
    ac.CREATIVE           AS AD_CREATIVE,
    ac.AD_TYPE            AS AD_CREATIVE_TYPE,  -- 소재 광고유형 (≠ AD_SOURCE_TYPE)
    ac.TARGET_GROUP       AS AD_TARGET_GROUP,
    dv.DEVICE_TYPE        AS DEVICE_TYPE,
    dv.DEVICE_SCOPE_DESC  AS DEVICE_SCOPE_DESC  -- DEC-10 자기설명
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE f
LEFT JOIN GN_DW.GOLD.DIM_DATE        d  ON f.PERF_DATE_SK  = d.DATE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN    c  ON f.CAMPAIGN_SK   = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_AD_CREATIVE ac ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
LEFT JOIN GN_DW.GOLD.DIM_DEVICE      dv ON f.DEVICE_SK     = dv.DEVICE_SK;
```

### 7-A. WIDE_AD_BROADCAST (FAD_B) — 위성 1:1 · 신설 2026-07-28

> grain = `AD_PERF_DK` (FAD_B 와 1:1, 코어와도 1:1). 실측 **37,886행**(VIDEO 35,822 + REBRDC 2,064).
> **코어 measure 동반 노출**(DEC-13 1:1 규칙) → "채널사별 방송 광고비"·"시간대별 인입콜"을 조인 없이 답한다.
> ⚠️ **이중계상 금지**: `AD_COST`·`INBOUND_CALL` 은 코어 뷰에도 있다. 두 뷰를 함께 합산하면 방송 행이 2번 센다.
> ⚠️ 컬럼 NULL 은 **두 방송 원천 중 한쪽 전용 속성**이며 결측이 아니다.
> · VIDEO 전용: `CM_POSITION`·`AD_START_TIME`·`AD_END_TIME`·`CHANNEL_COMPANY_TYPE`·`SPOT_TYPE`·`DURATION_SEC`·`DAY_DIV`·`PRG_START_TIME`·`CTV_DIV`·`CONV_CALL_CNT`·`AD_VIEW_RT_SRC`·`CPC_SRC`
> · REBRDC 전용: `RT_TYPE`·`BRDC_DIV`·`DVLP_MEMBER_CNT`·`DVLP_CNT`
> ⚠️ **`DVLP_*` = 재방송 개발실적** — 종전 코어 `GA_CONV_*` 에 혼입돼 있던 값(O16). **GA 전환과 다른 개념.**
> 구현 = `models/gold/wide/WIDE_AD_BROADCAST.sql`

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_AD_BROADCAST
  COMMENT = '방송광고 위성 팩트 평탄화 (FAD_B × DATE·CAMPAIGN·AD_CREATIVE, grain=AD_PERF_DK, 37,886행). 코어 measure 동반 노출(1:1이라 fan-out 없음) — 단 WIDE_AD_PERFORMANCE 와 합산 시 이중계상 주의. 방송 전용(디지털 제외).'
AS
SELECT
    b.AD_PERF_DK,
    f.AD_SOURCE_TYPE,                          -- VIDEO / REBROADCAST
    f.PERF_DATE_SK,
    f.AD_COST, f.INBOUND_CALL,                 -- [코어 measure] 1:1 이므로 동반 안전
    b.TIME_BAND, b.CM_POSITION, b.RT_TYPE,
    b.AD_START_TIME, b.AD_END_TIME, b.BROADCAST_DATE,
    b.PROGRAM_NM, b.CHANNEL_COMPANY, b.CHANNEL_COMPANY_TYPE,
    b.SPOT_TYPE, b.DURATION_SEC, b.DAY_DIV, b.PRG_START_TIME,
    b.CTV_DIV, b.BRDC_DIV,
    b.AD_CNT, b.CONV_CALL_CNT,
    b.DVLP_MEMBER_CNT, b.DVLP_CNT,             -- 재방송 개발실적 (≠ GA 전환)
    b.AD_VIEW_RT_SRC, b.CPC_SRC,               -- 대행사 산정 · 비가산 N
    b.DW_SOURCE_SYSTEM,
    d.FULL_DATE  AS PERF_FULL_DATE,  d.YEAR    AS PERF_YEAR,
    d.MONTH      AS PERF_MONTH,      d.QUARTER AS PERF_QUARTER,
    d.IS_HOLIDAY AS PERF_IS_HOLIDAY,
    c.CAMPAIGN_NAME  AS CAMPAIGN_NAME,
    ac.MEDIA_NAME    AS AD_MEDIA_NAME,
    ac.CREATIVE      AS AD_CREATIVE
FROM GN_DW.GOLD.FACT_AD_BROADCAST b
JOIN      GN_DW.GOLD.FACT_AD_PERFORMANCE f  ON b.AD_PERF_DK    = f.AD_PERF_DK
LEFT JOIN GN_DW.GOLD.DIM_DATE            d  ON f.PERF_DATE_SK  = d.DATE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN        c  ON f.CAMPAIGN_SK   = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_AD_CREATIVE     ac ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK;
```

### 7-B. WIDE_AD_DIGITAL (FAD_D) — 위성 1:1 · 신설 2026-07-28

> grain = `AD_PERF_DK` (FAD_D 와 1:1). 실측 **197,686행**(DGT).
> **코어 measure 동반 노출**(DEC-13) → "페이지유형별 CTR"·"광고그룹별 전환수"를 조인 없이 답한다.
> ⚠️ **이중계상 금지** — 전 유형 집계는 코어 뷰만.
> ⚠️ **기기축 동반**: 디지털은 기기(M/PC)가 실존하므로 `DEVICE_TYPE` 노출(DEC-10 실배선).
> ⚠️ **`_SRC` 비가산(DEC-9)** — 집계는 반드시 base 재계산. `VTR_SRC` 는 base 부재로 재계산 불가(대조 대상 아님).
> 구현 = `models/gold/wide/WIDE_AD_DIGITAL.sql`

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_AD_DIGITAL
  COMMENT = '디지털광고 위성 팩트 평탄화 (FAD_D × DATE·CAMPAIGN·AD_CREATIVE·DEVICE, grain=AD_PERF_DK, 197,686행). 코어 measure 동반 노출(1:1이라 fan-out 없음) — 단 WIDE_AD_PERFORMANCE 와 합산 시 이중계상 주의. _SRC 는 비가산(N), 집계는 base 재계산.'
AS
SELECT
    g.AD_PERF_DK,
    f.AD_SOURCE_TYPE,                          -- DIGITAL 만
    f.PERF_DATE_SK,
    f.AD_COST, f.IMPRESSIONS, f.CLICKS,        -- [코어 measure] = 비율 재계산 base
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    g.PAGE_TYPE, g.AD_GROUP_NM, g.GROUP_DIV, g.CREATIVE_TYPE, g.AD_TYPE_NM,
    g.READ_CNT, g.MEDIA_POTENTIAL_CUST_CNT, g.CRM_DEV_CNT,
    g.CTR_SRC, g.CVR_SRC, g.CPC_SRC, g.CPM_SRC, g.CPA_SRC,   -- 비가산 N
    g.DEV_UNIT_PRICE_SRC, g.VTR_SRC,
    g.DW_SOURCE_SYSTEM,
    d.FULL_DATE  AS PERF_FULL_DATE,  d.YEAR    AS PERF_YEAR,
    d.MONTH      AS PERF_MONTH,      d.QUARTER AS PERF_QUARTER,
    d.IS_HOLIDAY AS PERF_IS_HOLIDAY,
    c.CAMPAIGN_NAME  AS CAMPAIGN_NAME,
    ac.MEDIA_NAME    AS AD_MEDIA_NAME,
    ac.CREATIVE      AS AD_CREATIVE,
    dv.DEVICE_TYPE   AS DEVICE_TYPE
FROM GN_DW.GOLD.FACT_AD_DIGITAL g
JOIN      GN_DW.GOLD.FACT_AD_PERFORMANCE f  ON g.AD_PERF_DK    = f.AD_PERF_DK
LEFT JOIN GN_DW.GOLD.DIM_DATE            d  ON f.PERF_DATE_SK  = d.DATE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN        c  ON f.CAMPAIGN_SK   = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_AD_CREATIVE     ac ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
LEFT JOIN GN_DW.GOLD.DIM_DEVICE          dv ON f.DEVICE_SK     = dv.DEVICE_SK;
```

### 7-C. WIDE_AD_BROADCAST_CASE (FAD_BC) — 위성 1:N · 신설 2026-07-28

> grain = `AD_PERF_DK × CASE_SEQ` (FAD_BC 와 1:1, **코어에는 1:N**). 실측 **5,327행**.
> ⚠️ **코어 measure 를 의도적으로 미노출**(DEC-13 1:N 규칙). 광고비·인입콜을 함께 두면 사례 수만큼 fan-out 된다.
> 형제 뷰가 코어 measure 를 노출하는 것은 그쪽이 1:1 이기 때문이며, **본 뷰는 카디널리티가 달라 규칙이 반대다.**
> → **사례 속성 분포·빈도 분석 전용.** 금액·건수 집계는 `WIDE_AD_BROADCAST` 사용.
> ⚠️ `COUNT(*)` = **사례 수**(방송 횟수 아님). 방송 횟수는 `COUNT(DISTINCT AD_PERF_DK)`.
> ⚠️ 전 속성 NULL 사례는 미적재(희소행 방지) → 방송 1건당 사례 수는 **0~3 가변**.
> ⚠️ 아동명(`CASEn_CHILD_NM`) **미노출** — PII 판정 대기(O14). SILVER staging 에 원형 보존.
> 구현 = `models/gold/wide/WIDE_AD_BROADCAST_CASE.sql`

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_AD_BROADCAST_CASE
  COMMENT = '재방송 사례 위성 팩트 평탄화 (FAD_BC × DATE·CAMPAIGN, grain=AD_PERF_DK×CASE_SEQ, 5,327행). ⚠️코어에 1:N — 코어 measure 미노출(fan-out 방지). 사례 속성 분포 분석 전용. 방송 횟수는 COUNT(DISTINCT AD_PERF_DK). 아동명 미노출(PII O14).'
AS
SELECT
    bc.AD_PERF_DK,
    bc.CASE_SEQ,                               -- 1~3 (원천 CASE1~CASE3 언피벗축)
    f.AD_SOURCE_TYPE,                          -- REBROADCAST 만
    f.PERF_DATE_SK,
    bc.BIZ_DIV, bc.FAMILY_TYPE, bc.APPEAL_POINT, bc.CASE_DIV,
    b.RT_TYPE, b.PROGRAM_NM, b.CHANNEL_COMPANY, b.BROADCAST_DATE,  -- 방송 맥락(measure 제외)
    bc.DW_SOURCE_SYSTEM,
    d.FULL_DATE AS PERF_FULL_DATE, d.YEAR    AS PERF_YEAR,
    d.MONTH     AS PERF_MONTH,     d.QUARTER AS PERF_QUARTER,
    c.CAMPAIGN_NAME AS CAMPAIGN_NAME
FROM GN_DW.GOLD.FACT_AD_BROADCAST_CASE bc
JOIN      GN_DW.GOLD.FACT_AD_PERFORMANCE f ON bc.AD_PERF_DK   = f.AD_PERF_DK
LEFT JOIN GN_DW.GOLD.FACT_AD_BROADCAST   b ON bc.AD_PERF_DK   = b.AD_PERF_DK
LEFT JOIN GN_DW.GOLD.DIM_DATE            d ON f.PERF_DATE_SK  = d.DATE_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN        c ON f.CAMPAIGN_SK   = c.CAMPAIGN_SK;
```

### 8. WIDE_EVENT_PARTICIPATION (FEP)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_EVENT_PARTICIPATION
  COMMENT = '행사 참여 팩트 평탄화 (FEP × DATE·MEMBER[현재버전]·EVENT·CAMPAIGN·SPONSORSHIP).'
AS
SELECT
    f.DATE_SK, f.MEMBER_DK,
    f.RECRUIT_CNT, f.TOTAL_CNT, f.WAIT_CNT, f.CANCEL_CNT,
    f.CONFIRM_CNT, f.PARTICIPATE_CNT, f.ABSENT_CNT,
    f.PARTICIPANT_CNT, f.PARTICIPATION_TIMES,
    f.WAIT_TIMES, f.ABSENT_TIMES, f.CUM_APPLY_TIMES,
    f.REGULAR_DONATION,
    f.WIN_FLAG, f.SELF_PART_FLAG, f.PART_STATUS,
    f.PART_PATH, f.PART_CHANNEL, f.INCREASE_FLAG,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    m.GENDER              AS MEMBER_GENDER,
    m.REGION              AS MEMBER_REGION,
    m.AGE_BAND            AS MEMBER_AGE_BAND,
    m.MEMBER_STATUS       AS MEMBER_STATUS,
    m.MEMBER_TYPE         AS MEMBER_TYPE,
    e.EVENT_BK            AS EVENT_BK,
    e.EVENT_KIND          AS EVENT_KIND,
    e.EVENT_CATEGORY      AS EVENT_CATEGORY,
    e.EVENT_NAME          AS EVENT_NAME,
    e.EVENT_START_DATE    AS EVENT_START_DATE,
    e.EVENT_END_DATE      AS EVENT_END_DATE,
    e.APPLY_CHANNEL       AS EVENT_APPLY_CHANNEL,
    c.CAMPAIGN_BK         AS CAMPAIGN_BK,
    c.BRAND               AS CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       AS CAMPAIGN_NAME,
    s.SPONSORSHIP_BK      AS SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    AS SPONSORSHIP_NAME
FROM GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
LEFT JOIN GN_DW.GOLD.DIM_DATE d ON f.DATE_SK = d.DATE_SK
LEFT JOIN (
    SELECT MEMBER_DK, GENDER, REGION, AGE_BAND, MEMBER_STATUS, MEMBER_TYPE
    FROM GN_DW.GOLD.DIM_MEMBER
    WHERE IS_CURRENT = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m ON f.MEMBER_DK = m.MEMBER_DK
LEFT JOIN GN_DW.GOLD.DIM_EVENT       e ON f.EVENT_SK       = e.EVENT_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN    c ON f.CAMPAIGN_SK    = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK;
```

### 9. WIDE_BUDGET (FBD)

```sql
CREATE OR REPLACE VIEW GN_DW.GOLD.WIDE_BUDGET
  COMMENT = '예산 팩트 평탄화 (FBD × ORG[as-was]·BUDGET_ITEM·CAMPAIGN·SPONSORSHIP). 월 grain=MONTH_KEY.'
AS
SELECT
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) AS CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    AS CAL_MONTH,
    f.PLAN_BUDGET_MONTH, f.PLAN_BUDGET_YEAR,
    f.EXEC_BUDGET_ERP, f.EXEC_BUDGET_EST,
    f.FUNDRAISING_COST, f.AD_COST,
    f.DW_SOURCE_SYSTEM,
    o.CORP AS ORG_CORP, o.DIVISION AS ORG_DIVISION,
    o.DEPARTMENT AS ORG_DEPARTMENT, o.TEAM AS ORG_TEAM,
    bi.BUDGET_ITEM_NAME AS BUDGET_ITEM_NAME, bi.BUDGET_CATEGORY AS BUDGET_CATEGORY,
    c.CAMPAIGN_BK AS CAMPAIGN_BK, c.BRAND AS CAMPAIGN_BRAND, c.CAMPAIGN_NAME AS CAMPAIGN_NAME,
    s.SPONSORSHIP_BK AS SPONSORSHIP_BK, s.SPONSORSHIP_NAME AS SPONSORSHIP_NAME
FROM GN_DW.GOLD.FACT_BUDGET f
LEFT JOIN GN_DW.GOLD.DIM_ORG         o  ON f.ORG_SK         = o.ORG_SK
LEFT JOIN GN_DW.GOLD.DIM_BUDGET_ITEM bi ON f.BUDGET_ITEM_SK = bi.BUDGET_ITEM_SK
LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN    c  ON f.CAMPAIGN_SK    = c.CAMPAIGN_SK
LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP s  ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK;
```

---

### 10. WIDE_MEMBER_FEE (FMF) — 회비 분해 소비뷰 [신설 2026-08-06 O45]

> **왜 신설했는가**: `WIDE_MEMBER_MONTHLY` 는 회원×월 grain 이라 **후원사업·납입방식별 회비 분해가 불가**했다.
> 후원사업을 붙이면 회원-월 37,148,615 → 회원-월-후원사업 39,563,730 (**+6.5%**) 로 grain 이 깨진다.
> ⇒ grain 이 다르면 팩트를 나눈다. `FACT_MEMBER_FEE` 를 신설하고 이 뷰가 라벨을 비정규화한다.
>
> 🔴 **`WIDE_MEMBER_MONTHLY` 와 한 표에서 조인 금지** — 두 뷰는 같은 원천(`SILVER.CRM_PAYMENT_BILLING`)의
> **형제 팩트**다. 실측: 조인 시 청구액 891,959,790,888 → **1,056,821,121,099 (+18.5%)**.
>
> - base: `FACT_MEMBER_FEE` (**40,262,076행** · 2026-08-07 O45-C 재빌드 확정)
> - 조인: `DIM_SPONSORSHIP`(납입 대상 후원사업) · `DIM_PAYMENT`(결제수단) · `DIM_MEMBER_CURRENT`(회원 속성 스냅샷)
>   · **`DIM_MEMBER_ACQUISITION`**(획득 귀속축 — `ACQ_*`)
> - fan-out 검증: 뷰 행수 == FMF 행수 (GATE-C)
> - 🔴 축 이름에 시점을 박았다: `SPONSORSHIP_NAME`(납입 대상) vs `ACQ_SPONSORSHIP_NAME`(획득) ·
>   `ACQ_DEPARTMENT`(획득 부서) vs `WIDE_MEMBER_EVENT.ORG_DEPARTMENT`(사건 부서). **같은 라벨, 다른 축**이다.
> - 상세 컬럼 = `05_필드 인벤토리.md` **FMF-W**

### 11. DIM_MEMBER_ACQUISITION — 획득 귀속축 뷰 [신설 2026-08-06 O45]

> WIDE 계열은 아니지만 **소비 계층 뷰**라 여기 등재한다(정본 컬럼 목록 = `05_필드 인벤토리.md` **D17**).
>
> - base: `FACT_MEMBER_COHORT` (1,585,949행 = 1행/회원)
> - 🔴 **왜 테이블이 아니라 뷰인가**: 같은 사실을 두 곳에 저장하면 반드시 어긋난다(O43 P85).
>   `FACT_MEMBER_COHORT` 가 **단일 정의 지점**이다.
> - 🔴 **O8(다중귀속)을 임의로 푼 것이 아니다** — **「획득 시점」이라는 명시 규칙**을 쓴 것이다.
>   회원-월 grain 의 다중 후원사업 귀속 문제는 여전히 미결이다(P87: 이슈는 grain 별로 쪼개서 판정한다).
> - 팬아웃 실측(등록 전 측정 · 네 앵커 모두 조인 후 행수 불변):
>   `FMM` 40,054,883 · `FSE` 38,470,780 · `FEP` 1,134,126 · `FME` 4,633,105
> - 미매칭 645,136 = **1.61%**


## 4. 검증 쿼리

Snowflake는 PK/UNIQUE를 강제하지 않으므로 조인 유일성을 데이터로 확인한다.

```sql
-- V1. 회원 dedup 전제: MEMBER_DK당 IS_CURRENT 다중행 (기대: 0행)
SELECT MEMBER_DK, COUNT(*) c FROM GN_DW.GOLD.DIM_MEMBER
WHERE IS_CURRENT = TRUE GROUP BY MEMBER_DK HAVING COUNT(*) > 1;

-- V2. 대리키 유일성 (기대: 각 0행)
SELECT ORG_SK, COUNT(*) c FROM GN_DW.GOLD.DIM_ORG GROUP BY ORG_SK HAVING COUNT(*) > 1;
SELECT CAMPAIGN_SK, COUNT(*) c FROM GN_DW.GOLD.DIM_CAMPAIGN GROUP BY CAMPAIGN_SK HAVING COUNT(*) > 1;

-- V3. fan-out 감지: 뷰 행수 = 팩트 행수 (LEFT JOIN + 유일 차원 전제)
SELECT
  (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY) AS fact_rows,
  (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_MEMBER_MONTHLY) AS view_rows;

-- V4. [순서9-I] 위성 WIDE fan-out 감지 — 위성 뷰 행수 = 위성 팩트 행수 (기대: 각 쌍 일치)
SELECT 'FAD_B'  AS pair, (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)      AS fact_rows,
                          (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_BROADCAST)      AS view_rows
UNION ALL SELECT 'FAD_D',  (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL),
                          (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_DIGITAL)
UNION ALL SELECT 'FAD_BC', (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST_CASE),
                          (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_BROADCAST_CASE);

-- V5. [순서9-I] 위성 1:1 전제 검증 — AD_PERF_DK 중복 (기대: 각 0행)
SELECT AD_PERF_DK, COUNT(*) c FROM GN_DW.GOLD.FACT_AD_BROADCAST GROUP BY 1 HAVING COUNT(*) > 1;
SELECT AD_PERF_DK, COUNT(*) c FROM GN_DW.GOLD.FACT_AD_DIGITAL   GROUP BY 1 HAVING COUNT(*) > 1;
-- FAD_BC 는 1:N 이 정상 → grain 은 (AD_PERF_DK, CASE_SEQ) 조합으로 검증
SELECT AD_PERF_DK, CASE_SEQ, COUNT(*) c FROM GN_DW.GOLD.FACT_AD_BROADCAST_CASE GROUP BY 1,2 HAVING COUNT(*) > 1;
```

---

## 5. 배포 · 모니터링

- FACT/DIM **27개** 생성 후 실행. **12개 VIEW**는 상호 의존 없어 순서 무관 일괄 실행.
  ⚠️ 단 위성 WIDE 3종은 코어 팩트(`FACT_AD_PERFORMANCE`)를 조인하므로 **팩트 적재 후**여야 행이 나온다.
- 배포 직후 §4 V1·V3로 fan-out 없음 확인. **위성은 V4·V5 추가 확인**(DEC-13 카디널리티 전제).

| 조회 성능 | 액션 |
|------|------|
| < 5초 | 유지 |
| 5~15초 | 대상 FACT 클러스터링 키 검토 |
| > 15초 + 반복 조회 | Dynamic Table 승급(TARGET_LAG='1 hour') |

-- GN_DW 3단계: Semantic View DDL 정본 — SV_MEMBER_FEE (회비 분해)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-06 O45 신설]
--   대상 SV = **SV_MEMBER_FEE**. 이 파일 하나로 **독립 실행**된다
--   (역할·웨어하우스·스키마 설정 + SV 정의 + GRANT + 스모크가 모두 들어 있다).
--   🔴 다른 `05_*_SV_DDL_*.sql` 과 **실행 순서 의존이 없다** — 필요한 파일만 단독 실행한다.
--   `CREATE OR REPLACE` 가 GRANT 를 파괴하지만 GRANT 절이 같은 파일에 있어 자기완결적이다.
--
-- ▶ 무엇을 답하는 SV 인가
--   **회비를 「후원사업 · 납입방식(결제수단) · 회비구분 · 납입유형 · 납입일」로 분해**한다.
--   base = `GN_DW.GOLD.WIDE_MEMBER_FEE`(FMF × 후원사업·결제수단·회원속성·획득귀속 라벨 비정규화).
--
--   🔴 **`SV_MEMBER_MONTHLY` 가 이 질문에 답할 수 없었던 이유는 「적재 대기」가 아니라 grain 이다.**
--      `FACT_MEMBER_MONTHLY` 는 **회원 × 월 정확히 1행**이다. 후원사업을 붙이면 조합 수가 늘어
--      grain 이 깨지고, 귀속 규칙을 넣으면 후원사업별 합계가 원천과 어긋난다.
--      ⇒ **grain 이 다르면 팩트를 나눈다**(O45). 그 결과가 `FACT_MEMBER_FEE` 이고 이 SV 다.
--      종전 `SV_MEMBER_MONTHLY` COMMENT 의 *"비활성(적재 대기): 납입방식/후원사업별 분해"* 는
--      **원인을 틀리게 적은 부정형 서술**이었고 이번에 회수했다(P61 · P87 — 「축이 없다」와 「축을 안 붙였다」는 다르다).
--
-- ▶ 🔴🔴 이 SV 의 최대 위험 = `SV_MEMBER_MONTHLY` 와의 **이중계상**
--   두 SV 는 **같은 원천**(`SILVER.CRM_PAYMENT_BILLING`)을 **다른 grain** 으로 담은 형제 팩트다.
--   실측(2026-08-06 · `MEMBER_DK`+`MONTH_KEY` 조인):
--     행    40,054,883 → 40,262,076
--     청구액 891,959,790,888 → **1,056,821,121,099 (+18.5% 과대계상)**
--   🔴 이것은 자동 검사기가 **「조립가능」으로 통과시킨** 실제 사례다(O45-D) — 두 팩트가 시간축·엔티티축이
--      같아서 축 비교만으로는 걸러지지 않았다. **COMMENT 는 사람만 읽고 검사기는 읽지 않는다.**
--   ⇒ 방어를 3중으로 둔다: ① 이 SV COMMENT ② `SV_MEMBER_MONTHLY` COMMENT ③ Agent instruction.
--      그리고 **두 SV 를 한 도구 호출로 합칠 수 없다**는 구조적 사실이 마지막 방어선이다
--      (`SEMANTIC_VIEW()` 는 단일 뷰 대상이므로 Agent 는 각각 호출해 **표를 분리**할 수밖에 없다).
--
-- ▶ 선행 조건
--   ① GOLD 적재 완료(`dbt build`) — `WIDE_MEMBER_FEE` 가 존재해야 한다
--   ⚠ 이 SV 는 **단일 논리테이블**이므로 SERVING helper 뷰(`DIM_MONTH`·`DIM_MEMBER_CURRENT`)에
--     의존하지 않는다 — base 뷰가 라벨을 이미 평탄화해 갖고 있다(조인 0 → fan-out 위험 0).
--   ⚠ 반드시 `GN_DW_ADMIN` 역할로 실행한다. ACCOUNTADMIN 으로 만들면 소유권이 어긋난다(P74).
--
-- ▶ 설계 판단
--   **(1) 단일 논리테이블** — base 뷰가 `SPONSORSHIP_NAME`·`PAYMENT_METHOD_NAME`·`FEE_DIV_NAME`·
--     `ACQ_*` 를 degenerate 로 갖고 있어 조인이 불필요하다. 조인이 0 이면 fan-out 도 0 이다.
--   **(2) 납부율은 여기서도 정본 식을 쓴다**(O40) — 분자 `PAID_FEE_BILLABLE`(회비 납입) ÷
--     분모 `BILLED_AMT`(회비 청구). 🔴 `PAID_FEE`(회비+기부금)를 분자로 쓰면 모집단이 달라
--     전 기간 100% 를 넘는다. 결함 metric 은 이 SV 에 **아예 만들지 않는다**(신규 SV 이므로
--     하위호환 보존 의무가 없다 — 처음부터 정본만 노출하는 것이 옳다).
--   **(3) `BILLING_ROWS` 는 measure 로 노출하지만 「건수」라 부르지 않는다** — 정본 `(건)` 은
--     금액÷10,000 규약(CONF-2)이라 행 수를 「건」으로 쓰면 정의가 깨진다. synonym 에서 '건수' 를 뺐다.
--   **(4) 획득 귀속축(`ACQ_*`)을 함께 노출한다** — 이것이 이 SV 의 부가가치다:
--     **회비 × 획득 캠페인·부서·후원사업 교차**가 성립한다(캠페인별 LTV 계열 질문).
--     🔴 단 `ACQ_SPONSORSHIP` 과 `SPONSORSHIP`(납입 대상)은 **다른 축**이므로 이름으로 구분했다.
--   **(5) 라벨 없는 결제수단 5종을 숨기지 않는다** — `SETLE_CD`(원본 코드)를 degen 차원으로 남겼다.
--     라벨 커버리지가 100% 가 아닌 사실을 소비자가 알 수 있어야 한다(O45-B 현업 확인 대상).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   9. SV_MEMBER_FEE (member Agent) — base WIDE_MEMBER_FEE
      grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE
  TABLES (
    fee AS GN_DW.GOLD.WIDE_MEMBER_FEE
      WITH SYNONYMS ('회비', '회비 분해', '납입 상세', '후원사업별 회비')
      COMMENT = '회비 분해 소비뷰(base FACT_MEMBER_FEE). grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단. 🔴`SV_MEMBER_MONTHLY`(회원×월)와 **같은 원천을 다른 grain 으로 담은 형제 팩트**다 — 두 SV 의 회비 금액을 한 표에서 합산하면 과대계상된다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_PM_MBRFEE_ACMSLT(회비 · SPNSR_BSNS_ID·SETLE_CD·MBRFEE_DIV_CD·RQEST_AMT·PAY_AMT·PAY_STAT_CD) + TM_PM_DNTN_DTLS(기부금) + TM_CM_SPNSR_BSNS_INFO(후원사업 마스터) · SILVER=CRM_PAYMENT_BILLING + CRM_SPONSOR_BIZ + CRM_CODE · GOLD=FACT_MEMBER_FEE → WIDE_MEMBER_FEE.'
  )
  DIMENSIONS (
    -- ── 시간 (월 grain · degen) ────────────────────────────────────────────────
    fee.MONTH_KEY        AS fee.MONTH_KEY   WITH SYNONYMS ('회비월', '기준년월', '연월') COMMENT = '회비월 YYYYMM. 🔴청구·납입의 귀속 월이며 실제 납입일과 다를 수 있다 — 납입 **일자**는 LAST_PAY_DATE 를 쓴다. 회비월이 무효면 납입월로 폴백하고 둘 다 무효면 0(Unknown월)이다',
    fee.CAL_YEAR         AS fee.CAL_YEAR    WITH SYNONYMS ('연도', '년') COMMENT = '회비 연도',
    fee.CAL_MONTH        AS fee.CAL_MONTH   WITH SYNONYMS ('월') COMMENT = '회비 월(1~12)',
    fee.LAST_PAY_DATE    AS fee.LAST_PAY_DATE WITH SYNONYMS ('납입일', '기준일(납입일)', '최종납입일') COMMENT = '해당 조합의 **최종 납입일**. 🔴시점 축이며 합계가 아니다. `SV_MEMBER_MONTHLY` 는 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 SV 에서만 답한다. ⚠️여러 번 납입한 조합은 마지막 납입일만 남는다 — 납입 횟수·일별 추이를 이 축으로 세지 말 것',
    -- ── 🔴 납입 대상 후원사업 (획득 후원사업과 다른 축) ──────────────────────────
    fee.SPONSORSHIP      AS fee.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '납입 후원사업', '사업') COMMENT = '🔴**납입 대상** 후원사업명(정본 #123) — 그 회비가 어느 사업으로 들어갔는가다. ⚠️**획득 시점 후원사업과 다른 축**이다: 그 회원을 데려온 사업은 `SV_MEMBER_COHORT` 의 획득 후원사업(또는 이 SV 의 ACQ_SPONSORSHIP)이며, 한 회원이 여러 후원사업에 내므로 두 축의 값이 다르다. ⚠️개발 사건의 후원사업(`SV_MEMBER_EVENT`)과도 또 다른 축이다 — 세 축을 합산하지 말고 어느 축으로 답했는지 밝힌다. ⚠️미매칭은 ''(미매핑)''',
    -- ── 회비 구분·납입유형 (코드값 전수 열거 — §6.9-(5)) ────────────────────────
    fee.FEE_DIV          AS fee.FEE_DIV_NAME WITH SYNONYMS ('회비구분', '회비 종류') COMMENT = '회비구분명(정본 PM010). 실제값 4종: ''정기''·''선물금''·''일시''·''긴급구호''. 🔴**기부금 행은 원천이 NULL** 이다 — 결측이 아니라 「해당없음」이며 ''미상''으로 창작하지 말 것(P21). 기부금을 보려면 PAYMENT_TYPE 을 쓴다',
    fee.FEE_DIV_CD       AS fee.FEE_DIV_CD  WITH SYNONYMS ('회비구분코드') COMMENT = '회비구분 원천코드(PM010: E=정기 · G=선물금 · I=일시 · U=긴급구호). 라벨은 FEE_DIV',
    fee.PAYMENT_TYPE     AS fee.PAYMENT_TYPE WITH SYNONYMS ('납입유형', '회비/기부금 구분') COMMENT = '납입유형. 실제값 2종: ''회비''·''기부금''. 🔴**납부율·미납 분석은 회비만으로 스코프해야 한다** — 기부금은 원천에 청구액(RQEST_AMT)이 전건 NULL 이라 분모에 들어갈 수 없다(O40). 정본 납부율 metric 은 이 스코프를 이미 반영하고 있다',
    -- ── 납입방식(결제수단) ─────────────────────────────────────────────────────
    fee.PAYMENT_METHOD   AS fee.PAYMENT_METHOD_NAME WITH SYNONYMS ('납입방식', '결제수단', '결제방식', '수납방법') COMMENT = '결제수단 라벨. 실제값 6종: ''자동이체''·''신용카드''·''네이버페이''·''회비통장''·''OCR''·''휴대폰''. 🔴**라벨 커버리지가 100% 가 아니다** — 원천 결제수단 코드 11종 중 5종은 코드그룹이 특정되지 않아 ''(미매핑)''으로 모인다(O45-B 현업 확인 대상). 따라서 **결제수단별 합계는 전체 합계보다 작다** — 총계는 이 축 없이 답한다. 원본 코드는 SETLE_CD 로 확인한다. ⚠️CRM_CODE 에서 11종을 덮는 그룹이 여럿 나왔으나 전부 의미 무관(간사/질병/취미…)이어서 **추측하지 않았다**(숫자 코드 우연 일치 · P36)',
    fee.SETLE_CD         AS fee.SETLE_CD    WITH SYNONYMS ('결제수단코드', '수납코드') COMMENT = 'degen: 결제수단 **원본 코드**. 라벨이 없는 5종을 잃지 않기 위해 보존한다 — ''(미매핑)'' 버킷의 정체를 이 축으로 확인할 수 있다(O45-B). 🔴코드값 자체의 업무 의미는 현업 미확인이므로 **코드로 의미를 추정해 답하지 말 것**',
    fee.UNPAID_FLAG      AS fee.UNPAID_FLAG WITH SYNONYMS ('미납여부') COMMENT = '해당 조합에 미납 청구행이 하나라도 있는가(TRUE/FALSE). ⚠️**회원 단위 미납 여부가 아니다** — 회원 월말 미납 여부는 `SV_MEMBER_MONTHLY` 의 UNPAID_FLAG_EOM 이다',
    -- ── 회원 속성 (현재 스냅샷) ────────────────────────────────────────────────
    fee.MEMBER_STATUS    AS fee.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '회원상태 라벨(MM010). 🔴**현재 스냅샷**이다 — 과거 회비월 행에도 현재 상태가 붙는다',
    fee.MEMBER_TYPE      AS fee.MEMBER_TYPE_NAME   WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''. 🔴현재 스냅샷',
    fee.MEMBER_GENDER    AS fee.GENDER_NAME        WITH SYNONYMS ('성별') COMMENT = '회원 성별 라벨(CM017). 실제값 5종: ''남자''·''여자''·''기타''·''단체''·''기업''. 🔴현재 스냅샷. ⚠️`SV_MEMBER_COHORT` 의 획득시점 성별(CM013)과 **코드체계가 다르다** — 합산 금지',
    -- ── 🔴 획득 귀속축 (회비 × 획득 캠페인 교차 = 이 SV 의 부가가치) ─────────────
    fee.ACQ_BRAND        AS fee.ACQ_BRAND        WITH SYNONYMS ('브랜드', '획득 브랜드', '최초브랜드') COMMENT = '🔴**획득 시점** 캠페인의 공통브랜드. 회비를 획득 캠페인별로 볼 때 쓴다(캠페인별 LTV 계열). 현재 속성이 아니다',
    fee.ACQ_CAMPAIGN     AS fee.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명', '가입캠페인', '획득캠페인') COMMENT = '🔴**획득 시점** 캠페인명. `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 다중귀속 규칙 미확정(O8)으로 센티넬이라 회원-월 팩트로는 캠페인 분해가 안 되지만, **획득 시점이라는 명시 규칙**으로 이 축이 성립한다. 카디널리티가 높으니 규모가 작은 캠페인의 비율은 불안정하다',
    fee.ACQ_PARENT_CAMPAIGN AS fee.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인') COMMENT = '획득 캠페인의 상위캠페인명. 상위가 없으면 NULL 이며 ''(미매핑)''이 아니다',
    fee.ACQ_PROMO_METHOD AS fee.ACQ_PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법', '광고방법') COMMENT = '획득 캠페인의 홍보방법 라벨(CM008). 🔴원천 코드는 숫자라 코드로 필터하면 0행이 된다 — 반드시 이 라벨로 필터한다',
    fee.ACQ_MARKETING_CAMPAIGN AS fee.ACQ_MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인') COMMENT = '획득 캠페인의 마케팅캠페인명(광고↔CRM conformed 축 · O45). 광고비와 대응시킬 때 이 축을 쓴다 — 단 광고비 자체는 `SV_AD` 소관이며 두 SV 를 조인할 수 없다(각각 조회해 표를 분리한다)',
    fee.ACQ_DEPARTMENT   AS fee.ACQ_DEPARTMENT   WITH SYNONYMS ('부서', '가입부서', '획득부서') COMMENT = '🔴**획득 시점 부서명**. ⚠️개발실적보고의 「부서」는 **사건 부서**(`SV_MEMBER_EVENT.ORG_DEPARTMENT`)이며 **다른 축**이다 — 같은 라벨, 다른 값. 연간분석(회비)의 부서가 이 축이다. ⚠️상위 조직(본부/지부·팀·법인)은 산출 불가(CONF-4)',
    fee.ACQ_SPONSORSHIP  AS fee.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('획득 후원사업', '가입 후원사업') COMMENT = '🔴**획득 시점** 후원사업명(그 회원을 데려온 사업). ⚠️이 SV 의 SPONSORSHIP(=납입 대상)과 **다른 축**이다 — 회비가 들어간 사업과 회원을 데려온 사업은 다를 수 있다',
    fee.ACQ_AGE_BAND     AS fee.ACQ_AGE_BAND     WITH SYNONYMS ('연령대', '나이대') COMMENT = '🔴**획득 시점** 연령대(CM014) — **현재 나이가 아니다**(현재 연령은 BRONZE 에 생년월일이 없어 산출 불가 · O34). ''10대 미만''이 많은 것은 오류가 아니며 편지쓰기대회 계열 아동 모집 캠페인 때문이다 — 결측·오염으로 설명하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외한다',
    fee.ACQ_REGION       AS fee.ACQ_REGION       WITH SYNONYMS ('지역', '시도') COMMENT = '🔴**획득 시점** 지역(CM018 약칭) — **현재 거주지가 아니다**(O34). 센티넬은 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다'
  )
  METRICS (
    -- ── 금액 (🔴 metric 명은 컬럼명과 달라야 한다 — 같으면 컴파일 실패, P65) ─────
    fee.TOTAL_BILLED_AMT AS SUM(fee.BILLED_AMT)
      WITH SYNONYMS ('청구액', '청구회비', '청구', '총청구액')
      COMMENT = '청구액(원) 합계 = SUM(RQEST_AMT) · 정본 #71. F(가산). 🔴재청구 중복을 포함한다 — 정본 #71 비고가 「청구회비금액: 재청구 중복 포함」을 명시하므로 이것이 정본 정의다(DEC-23). 🔴`SV_MEMBER_MONTHLY` 의 청구액과 **같은 원천**이므로 두 SV 의 값을 더하지 말 것 — 전체 합계는 두 SV 가 일치해야 한다(GATE-D).',
    fee.TOTAL_PAID_FEE_BILLABLE AS SUM(fee.PAID_FEE_BILLABLE)
      WITH SYNONYMS ('납입회비', '회비 납입액', '수납회비')
      COMMENT = '**회비** 납입액(원) 합계 — 납부율 분자 **정본**(O40). F(가산). 기부금을 제외한다.',
    fee.TOTAL_PAID_ALL AS SUM(fee.PAID_FEE)
      WITH SYNONYMS ('총수납액')
      COMMENT = '납입 총액(원) = 회비 + **기부금**. F(가산). 🔴**납부율 분자로 쓰지 말 것** — 기부금은 청구액이 없어 분모에 못 들어가므로 비율이 100% 를 넘는다(O40 실사고). 「총수납액(회비+기부금)」을 명시적으로 물을 때만 쓰고 그때도 기부금 포함임을 밝힌다.',
    fee.TOTAL_UNPAID_AMT AS SUM(fee.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('미납금액', '총미납금액', '미납액')
      COMMENT = '미납 청구액(원) 합계 — **DEC-3 정본**(결제상태 실패 F 또는 NULL 인 청구액). F(가산). 🔴「청구−납입」 차감식이 아니다(차감식은 기부금이 미납을 상쇄해 음수가 나온다 · O40). ⚠️**조회 시점 스냅샷**이다 — 과거 연도 미납이 이후에 납입되면 값이 바뀐다. 「마감·확정」이라 단정하지 말 것.',
    -- ── 비율 (N 비가산 — 재집계 금지) ──────────────────────────────────────────
    fee.PAYMENT_RATE_FEE AS SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0)
      WITH SYNONYMS ('납부율', '납입율', '수납율')
      COMMENT = '납부율 = **회비** 납입액 ÷ **회비** 청구액. N(비가산 — 분자·분모를 각각 집계한 뒤 나눈다). 🔴분자·분모가 모두 회비라 모집단이 일치한다. `TOTAL_PAID_ALL` 을 분자로 바꾸면 기부금이 섞여 100% 를 넘는다(O40 에서 실제로 100.36% 가 배포됐다). ⚠️기간 스코프 없이 답하지 말 것 — 미납이 이후 납입되는 구조라 최근 기간은 낮게 보인다.',
    fee.UNPAID_RATIO AS SUM(fee.UNPAID_BILLED_AMT) / NULLIF(SUM(fee.BILLED_AMT), 0)
      WITH SYNONYMS ('미납비중', '미납율', '미납률')
      COMMENT = '미납비중 = 미납 청구액 ÷ 회비 청구액. N(비가산). DEC-3 정본 분자.',
    -- ── 규모 ──────────────────────────────────────────────────────────────────
    fee.DISTINCT_PAYING_MEMBERS AS COUNT(DISTINCT fee.MEMBER_DK)
      WITH SYNONYMS ('납입 회원수', '회비 회원수', '납입(명)')
      COMMENT = '**고유 회원수(명)** = COUNT(DISTINCT 회원). N(비가산 — 기간·축을 가로질러 더하면 중복된다). 🔴이 팩트는 회원당 여러 행이므로 **행 수를 「명」으로 쓰면 크게 과대**해진다(`*_MEMBERS` 계열 함정과 같은 유형 · O39). 「납입 회원수」 질문은 반드시 이 metric 으로 답한다.',
    fee.TOTAL_BILLING_ROWS AS SUM(fee.BILLING_ROWS)
      WITH SYNONYMS ('청구행수', '원천 회비행수')
      COMMENT = '집계된 원천 회비행 수. F(가산). 🔴**금액도 「건수」도 아니다** — 정본 `(건)` 은 금액÷10,000 규약(CONF-2)이므로 이 값을 「건」이라 부르면 정의가 깨진다. 재청구 시도 강도를 볼 때만 쓴다.'
  )
  COMMENT = 'Phase-1 회비 분해 SV(base WIDE_MEMBER_FEE). grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단. **후원사업·납입방식(결제수단)·회비구분·납입일별 회비 청구/납입/미납의 정본**이다. [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(회비 TM_PM_MBRFEE_ACMSLT · 기부 TM_PM_DNTN_DTLS · 후원사업 TM_CM_SPNSR_BSNS_INFO) → SILVER(CRM_PAYMENT_BILLING·CRM_SPONSOR_BIZ·CRM_CODE) → GOLD(FACT_MEMBER_FEE→WIDE_MEMBER_FEE). 테이블별 상세 원천은 테이블 COMMENT 의 [원천] 절 참조. 활성: 청구액·납입회비·총수납액·미납금액·납부율·미납비중·고유 납입회원수 · 후원사업·납입방식·회비구분·납입유형·납입일 축 · 회원 속성(현재 스냅샷) · **획득 귀속축**(브랜드·캠페인·상위캠페인·홍보방법·마케팅캠페인·부서·후원사업·연령대·지역). 시간=전체가능. 🔴🔴 **`SV_MEMBER_MONTHLY` 와 한 표에 합산 금지 — 이중계상이다.** 두 SV 는 같은 원천을 다른 grain 으로 담은 형제 팩트이며, 실측(2026-08-06) 조인 시 청구액이 891,959,790,888 → 1,056,821,121,099 (+18.5%)로 부풀어 오른다. ⇒ 회원-월 요약·상태별 분해는 `SV_MEMBER_MONTHLY`, 회비 분해는 이 SV **중 하나만** 앵커로 쓰고 둘 다 필요하면 **표를 분리**한다(전체 합계는 두 SV 가 일치해야 한다 = GATE-D). 🔴 **「후원사업」은 세 축이 있다** — 이 SV=납입 대상 · `SV_MEMBER_EVENT`=개발 사건 시점 · `SV_MEMBER_COHORT`=획득 시점. 어느 축으로 답했는지 반드시 밝힌다. 🔴 **「부서」는 두 축이 있다** — 이 SV 의 ACQ_DEPARTMENT=획득 시점 · `SV_MEMBER_EVENT.ORG_DEPARTMENT`=사건 부서. 비활성: 회원 단위 미납 플래그(SV_MEMBER_MONTHLY 소관) · 결제수단 라벨 미특정 5종(O45-B 현업 확인) · 상위 조직 분해(CONF-4).'
  AI_SQL_GENERATION '핵심 규칙: (1) 🔴🔴 **`SV_MEMBER_MONTHLY` 의 회비 measure 와 이 SV 의 measure 를 같은 답변의 같은 표에 넣지 않는다** — 같은 원천을 다른 grain 으로 담은 형제 팩트라 합치면 청구·납입액이 과대계상된다(실측 +18.5%). 둘 다 필요하면 **표를 분리하고 각 표의 grain 을 명시**한다. 「회원-월 요약·납부율 추이」는 SV_MEMBER_MONTHLY, 「후원사업·납입방식·회비구분·납입일 분해」는 이 SV 다. (2) **납부율은 PAYMENT_RATE_FEE 를 쓴다** — TOTAL_PAID_ALL(회비+기부금)을 분자로 만들지 않는다. 기부금은 청구액이 없어 분모에 못 들어가므로 비율이 100% 를 넘는다(O40 실사고). 「총수납액」을 명시적으로 물을 때만 TOTAL_PAID_ALL 을 쓰고 기부금 포함임을 밝힌다. (3) **「명」은 DISTINCT_PAYING_MEMBERS 로만 답한다** — 이 팩트는 회원당 여러 행이라 행 수·BILLING_ROWS 를 「명」으로 쓰면 크게 과대해진다. 그리고 이 metric 은 비가산이므로 월별 값을 더해 연간 회원수를 만들지 않는다. (4) **BILLING_ROWS 를 「건수」라 부르지 않는다** — 정본 (건) 은 금액÷10,000 규약이다(CONF-2). (5) **결제수단·후원사업별 합계는 전체 합계보다 작다** — 결제수단 라벨 미특정 5종과 후원사업 미매칭이 ''(미매핑)''으로 모인다. 캠페인·결제수단별로 답할 때는 미매핑 버킷의 존재를 밝히고, **총계는 축 없이** 답한다. (6) **「후원사업」·「부서」는 어느 축인지 반드시 밝힌다**: 이 SV 의 SPONSORSHIP=**납입 대상**, ACQ_SPONSORSHIP=**획득 시점**, ACQ_DEPARTMENT=**획득 시점 부서**다. 「부서별 개발실적」은 SV_MEMBER_EVENT(사건 부서), 「후원사업별 개발·중단 건수」도 SV_MEMBER_EVENT, 「캠페인별 이탈률」은 SV_MEMBER_COHORT 로 라우팅한다. 🔴 축을 밝히지 않으면 값이 맞아도 사용자가 틀린 결론을 얻는다. (7) **획득 귀속축은 현재 속성이 아니다** — ACQ_* 는 전부 최초 약정 당시 값이다. 「현재 연령대·현재 거주지·현재 소속 부서」 질문에는 산출 불가를 밝히고 획득 시점 기준으로 답하되 전제를 명시한다. (8) **미납·납부율에 「마감·확정」이라 단정하지 않는다** — 조회 시점 적재 스냅샷이며 과거 미납이 이후 납입되면 값이 바뀐다. 회비월은 미래월까지 존재한다. (9) 적용 조건(기간·그룹 모두 미지정 시): 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE 가 아니라 데이터 최신월), GROUP BY ROLLUP((연,월))로 월별 행 + 총계 행을 함께 반환한다. 비율은 총계 행에서 SUM 기반으로 산출한다. (10) metric 정렬에는 `NULLS LAST` 를 명시한다 — 회비구분이 NULL 인 기부금 행 등이 상위를 점유하는 것을 막는다. (11) 🔴 **비율 순위는 규모를 반드시 동반 제시한다**(P77 · O38-E 선례): 납부율 100% 인 구간이 실제로 존재하는데 전부 **청구 규모가 주력 연도의 수천분의 일**인 초기 연도·미래월이다(실측 2026-08-06 확인). 「납부율이 가장 높은 연도/후원사업/결제수단」을 물으면 `TOTAL_BILLED_AMT` 를 **같은 표에 함께** 내고, 극소 규모 항목을 단독 1위로 결론하지 않는다. 하한을 적용했으면 그 사실을 밝히고, 사용자가 하한을 정하지 않았으면 되묻는다. (12) 🔴 **`MONTH_KEY=0`(=Unknown월) 버킷을 실적 연월로 읽지 않는다** — 회비월·납입월이 모두 무효인 행이 모이는 자리다. 연월 추이를 낼 때는 이 버킷을 별도로 표기하고 「0년」·「0월」처럼 연월인 척 제시하지 않는다.';

-- ── GRANT (🔴 CREATE OR REPLACE 가 GRANT 를 파괴하므로 같은 파일에서 재부여한다) ──
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_SERVICE;

/* =====================================================================================
   스모크 — 🔴 절대값이 아니라 **불변식**으로 판정한다(§6.9-(8)).
   ===================================================================================== */

-- (F-1) fan-out 0 : SV 청구 총액 == 팩트 직접 SUM
SELECT (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS TOTAL_BILLED_AMT)) AS sv_val,
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_MEMBER_FEE)                                           AS fact_val;
--   판정: sv_val == fact_val

-- (F-2) 🔴 형제 팩트 총계 일치 (GATE-D) — 두 SV 의 청구액이 같아야 한다
SELECT (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS TOTAL_BILLED_AMT))         AS fee_billed,
       (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_BILLED_AMT))     AS monthly_billed;
--   판정: 두 값이 **동일**. 다르면 한쪽 팩트의 measure 식·필터가 어긋난 것이다.
--   ⚠️ metric 명이 다르면 SV_MEMBER_MONTHLY 쪽 이름으로 교체할 것(정본 = 05_1 파일).

-- (F-3) 🔴 비율 상한 불변식 — 납부율이 100% 를 넘지 않는가 (O40 재발 감시 · P73/P80)
SELECT MAX(PAYMENT_RATE_FEE) AS max_rate
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS CAL_YEAR
       METRICS PAYMENT_RATE_FEE);
--   판정: max_rate <= 1.0

-- (F-4) 🔴 「명」이 행수와 다른가 — DISTINCT 가 실제로 작동하는지 확인(O39 유형)
SELECT (SELECT DISTINCT_PAYING_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS DISTINCT_PAYING_MEMBERS)) AS distinct_members,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_FEE)                                                                AS fact_rows;
--   판정: distinct_members << fact_rows (같으면 DISTINCT 가 안 걸린 것)

-- (F-5) 신규 축이 실제로 분해되는가 — 후원사업·결제수단·회비구분
SELECT SPONSORSHIP, PAYMENT_METHOD, FEE_DIV, TOTAL_BILLED_AMT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS SPONSORSHIP, PAYMENT_METHOD, FEE_DIV
       METRICS TOTAL_BILLED_AMT)
ORDER BY TOTAL_BILLED_AMT DESC NULLS LAST
LIMIT 20;
--   판정: 세 축 모두 값이 나오고 ''(미매핑)'' 버킷이 보인다(숨기지 않는 것이 정상이다)

-- (F-6) 획득 귀속축 교차 — 회비 × 획득 캠페인(이 SV 의 부가가치)
SELECT ACQ_BRAND, TOTAL_PAID_FEE_BILLABLE, DISTINCT_PAYING_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS ACQ_BRAND
       METRICS TOTAL_PAID_FEE_BILLABLE, DISTINCT_PAYING_MEMBERS)
ORDER BY TOTAL_PAID_FEE_BILLABLE DESC NULLS LAST
LIMIT 15;
--   판정: 브랜드별로 분해된다(종전에는 회원-월 팩트로 불가했던 교차다)

-- (F-7) 소유권 — 다른 SV 와 동일해야 한다(P74)
SHOW SEMANTIC VIEWS LIKE 'SV_MEMBER_FEE' IN SCHEMA GN_DW.SERVING;
--   판정: owner = GN_DW_ADMIN

-- ============================================================================
-- _Co-authored with CoCo_
-- ============================================================================

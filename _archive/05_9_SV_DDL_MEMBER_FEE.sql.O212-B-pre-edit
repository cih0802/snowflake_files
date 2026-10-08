-- ============================================================================
-- 05_9_SV_DDL_MEMBER_FEE.sql — Semantic View DDL 정본: SV_MEMBER_FEE
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE
  TABLES (
    fee AS GN_DW.GOLD.WIDE_MEMBER_FEE
      WITH SYNONYMS ('회비', '회비 분해', '납입 상세', '후원사업별 회비')
      COMMENT = '회비 세부 분해 및 납입/미납 정밀 분석 (base: GOLD.WIDE_MEMBER_FEE). [Grain: 회원 × 회비월 × 사업 × 납입방식 × 결제수단]. [활성 지표: 청구액/납입액/미납액/수납률(%)]. [주의: 배분규칙필요 형제팩트중복 앵커_경합 이중계상 방지(SV_MEMBER_MONTHLY와 합산 금지)]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE].'
  )
  DIMENSIONS (
    fee.MONTH_KEY        AS fee.MONTH_KEY   WITH SYNONYMS ('회비월', '기준년월', '연월') COMMENT = '회비월 YYYYMM. 🔴청구·납입의 귀속 월이며 실제 납입일과 다를 수 있다 — 납입 **일자**는 LAST_PAY_DATE 를 쓴다. 회비월이 무효면 납입월로 폴백하고 둘 다 무효면 0(Unknown월)이다',
    fee.CAL_YEAR         AS fee.CAL_YEAR    WITH SYNONYMS ('연도', '년') COMMENT = '회비 연도',
    fee.CAL_MONTH        AS fee.CAL_MONTH   WITH SYNONYMS ('월') COMMENT = '회비 월(1~12)',
    fee.LAST_PAY_DATE    AS fee.LAST_PAY_DATE WITH SYNONYMS ('납입일', '기준일(납입일)', '최종납입일') COMMENT = '해당 조합의 **최종 납입일**. 🔴시점 축이며 합계가 아니다. `SV_MEMBER_MONTHLY` 는 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 SV 에서만 답한다. ⚠️여러 번 납입한 조합은 마지막 납입일만 남는다 — 납입 횟수·일별 추이를 이 축으로 세지 말 것',
    fee.SPONSORSHIP      AS fee.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '납입 후원사업', '사업') COMMENT = '🔴**납입 대상** 후원사업명(정본 #123) — 그 회비가 어느 사업으로 들어갔는가다. ⚠️**획득 시점 후원사업과 다른 축**이다: 그 회원을 데려온 사업은 `SV_MEMBER_COHORT` 의 획득 후원사업(또는 이 SV 의 ACQ_SPONSORSHIP)이며, 한 회원이 여러 후원사업에 내므로 두 축의 값이 다르다. ⚠️개발 사건의 후원사업(`SV_MEMBER_EVENT`)과도 또 다른 축이다 — 세 축을 합산하지 말고 어느 축으로 답했는지 밝힌다. ⚠️미매칭은 ''(미매핑)''',
    fee.FEE_DIV          AS fee.FEE_DIV_NAME WITH SYNONYMS ('회비구분', '회비 종류') COMMENT = '회비구분명(정본 PM010). 실제값 4종: ''정기''·''선물금''·''일시''·''긴급구호''. 🔴**기부금 행은 원천이 NULL** 이다 — 결측이 아니라 「해당없음」이며 ''미상''으로 창작하지 말 것(P21). 기부금을 보려면 PAYMENT_TYPE 을 쓴다',
    fee.FEE_DIV_CD       AS fee.FEE_DIV_CD  WITH SYNONYMS ('회비구분코드') COMMENT = '회비구분 원천코드(PM010: E=정기 · G=선물금 · I=일시 · U=긴급구호). 라벨은 FEE_DIV. 실제값 4종: ''E''·''G''·''I''·''U'' + NULL',
    fee.PAYMENT_TYPE     AS fee.PAYMENT_TYPE WITH SYNONYMS ('납입유형', '회비/기부금 구분') COMMENT = '납입유형. 실제값 2종: ''회비''·''기부금''. 🔴**납부율·미납 분석은 회비만으로 스코프해야 한다** — 기부금은 원천에 청구액(RQEST_AMT)이 전건 NULL 이라 분모에 들어갈 수 없다(O40). 정본 납부율 metric 은 이 스코프를 이미 반영하고 있다',
    fee.PAYMENT_METHOD   AS fee.PAYMENT_METHOD_NAME WITH SYNONYMS ('납입방식', '결제수단', '결제방식', '수납방법') COMMENT = '결제수단 라벨. 실제값 6종: ''자동이체''·''신용카드''·''네이버페이''·''회비통장''·''OCR''·''휴대폰''. 🔴**라벨 커버리지가 100% 가 아니다** — 원천 결제수단 코드 11종 중 5종은 코드그룹이 특정되지 않아 ''(미매핑)''으로 모인다(O45-B 현업 확인 대상). 따라서 **결제수단별 합계는 전체 합계보다 작다** — 총계는 이 축 없이 답한다. 원본 코드는 SETLE_CD 로 확인한다. ⚠️CRM_CODE 에서 11종을 덮는 그룹이 여럿 나왔으나 전부 의미 무관(간사/질병/취미…)이어서 **추측하지 않았다**(숫자 코드 우연 일치 · P36)',
    fee.SETLE_CD         AS fee.SETLE_CD    WITH SYNONYMS ('결제수단코드', '수납코드') COMMENT = 'degen: 결제수단 **원본 코드**. 라벨이 없는 5종을 잃지 않기 위해 보존한다 — ''(미매핑)'' 버킷의 정체를 이 축으로 확인할 수 있다(O45-B). 🔴코드값 자체의 업무 의미는 현업 미확인이므로 **코드로 의미를 추정해 답하지 말 것**. 실제값 11종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''10''·''12''·''13'' + NULL',
    fee.UNPAID_FLAG      AS fee.UNPAID_FLAG WITH SYNONYMS ('미납여부') COMMENT = '해당 조합에 미납 청구행이 하나라도 있는가(TRUE/FALSE). ⚠️**회원 단위 미납 여부가 아니다** — 회원 월말 미납 여부는 `SV_MEMBER_MONTHLY` 의 UNPAID_FLAG_EOM 이다',
    fee.MEMBER_STATUS    AS fee.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '회원상태 라벨(MM010). 🔴**현재 스냅샷**이다 — 과거 회비월 행에도 현재 상태가 붙는다. 실제값 13종: ''활동회원''·''후원중단''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''(해당없음)'' + NULL',
    fee.MEMBER_TYPE      AS fee.MEMBER_TYPE_NAME   WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''. 🔴현재 스냅샷',
    fee.MEMBER_GENDER    AS fee.GENDER_NAME        WITH SYNONYMS ('성별') COMMENT = '회원 성별 라벨(CM017). 실제값 5종: ''남자''·''여자''·''기타''·''단체''·''기업''. 🔴현재 스냅샷. ⚠️`SV_MEMBER_COHORT` 의 획득시점 성별(CM013)과 **코드체계가 다르다** — 합산 금지',
    fee.ACQ_BRAND        AS fee.ACQ_BRAND        WITH SYNONYMS ('브랜드', '획득 브랜드', '최초브랜드') COMMENT = '🔴**획득 시점** 캠페인의 공통브랜드. 회비를 획득 캠페인별로 볼 때 쓴다(캠페인별 LTV 계열). 현재 속성이 아니다',
    fee.ACQ_CAMPAIGN     AS fee.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명', '가입캠페인', '획득캠페인') COMMENT = '🔴**획득 시점** 캠페인명. `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 다중귀속 규칙 미확정(O8)으로 센티넬이라 회원-월 팩트로는 캠페인 분해가 안 되지만, **획득 시점이라는 명시 규칙**으로 이 축이 성립한다. 카디널리티가 높으니 규모가 작은 캠페인의 비율은 불안정하다',
    fee.ACQ_PARENT_CAMPAIGN AS fee.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인') COMMENT = '획득 캠페인의 상위캠페인명. 상위가 없으면 NULL 이며 ''(미매핑)''이 아니다',
    fee.ACQ_PROMO_METHOD AS fee.ACQ_PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법', '광고방법') COMMENT = '획득 캠페인의 홍보방법 라벨(CM008). 🔴원천 코드는 숫자라 코드로 필터하면 0행이 된다 — 반드시 이 라벨로 필터한다',
    fee.ACQ_MARKETING_CAMPAIGN AS fee.ACQ_MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인') COMMENT = '획득 캠페인의 마케팅캠페인명(광고↔CRM conformed 축 · O45). 광고비와 대응시킬 때 이 축을 쓴다 — 단 광고비 자체는 `SV_AD` 소관이며 두 SV 를 조인할 수 없다(각각 조회해 표를 분리한다)',
    fee.ACQ_DEPARTMENT   AS fee.ACQ_DEPARTMENT   WITH SYNONYMS ('부서', '가입부서', '획득부서') COMMENT = '🔴**획득 시점 부서명**. ⚠️개발실적보고의 「부서」는 **사건 부서**(`SV_MEMBER_EVENT.ORG_DEPARTMENT`)이며 **다른 축**이다 — 같은 라벨, 다른 값. 연간분석(회비)의 부서가 이 축이다. ⚠️상위 조직(본부/지부·팀·법인)은 산출 불가(CONF-4)',
    fee.ACQ_SPONSORSHIP  AS fee.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('획득 후원사업', '가입 후원사업') COMMENT = '🔴**획득 시점** 후원사업명(그 회원을 데려온 사업). ⚠️이 SV 의 SPONSORSHIP(=납입 대상)과 **다른 축**이다 — 회비가 들어간 사업과 회원을 데려온 사업은 다를 수 있다',
    fee.ACQ_AGE_BAND     AS fee.ACQ_AGE_BAND     WITH SYNONYMS ('연령대', '나이대') COMMENT = '🔴**획득 시점** 연령대(CM014) — **현재 나이가 아니다**(현재 연령은 BRONZE 에 생년월일이 없어 산출 불가 · O34). ''10대 미만''이 많은 것은 오류가 아니며 편지쓰기대회 계열 아동 모집 캠페인 때문이다 — 결측·오염으로 설명하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외한다. 실제값 12종: ''기업''·''기타''·''단체''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''10대 미만''·''70대 이상'' + NULL',
    fee.ACQ_REGION       AS fee.ACQ_REGION       WITH SYNONYMS ('지역', '시도') COMMENT = '🔴**획득 시점** 지역(CM018 약칭) — **현재 거주지가 아니다**(O34). 센티넬은 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다. 실제값 18종: ''강원''·''경기''·''경남''·''경북''·''광주''·''기타''·''대구''·''대전''·''부산''·''서울''·''세종''·''울산''·''인천''·''전남''·''전북''·''제주''·''충남''·''충북'' + NULL',
    -- [2026-10-07 O205] 획득 캠페인 분류 8축(DIM_MEMBER_ACQUISITION 동결값 · WIDE_MEMBER_FEE 에 노출)
    fee.ACQ_CAMPAIGN_TYPE AS fee.ACQ_CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '주요캠페인', '캠페인 카테고리', '캠페인카테고리 구분') COMMENT = '[O205] 🔴**획득 시점** 캠페인카테고리(=주요캠페인). 「캠페인카테고리별 납입회비·회비흐름」은 이 축으로 답한다. ⚠️`SV_MEMBER_EVENT` 의 캠페인카테고리는 **사건 시점**이라 다른 축이다. 🔴ML 회비 예측(`SV_ML_FEE_FORECAST`)의 캠페인카테고리와 이름이 같아도 실적·예측을 한 표에 합산하지 않는다',
    fee.ACQ_INFLOW_PATH  AS fee.ACQ_INFLOW_PATH  WITH SYNONYMS ('개발인입경로', '인입경로', '유입경로', '회원인입경로') COMMENT = '[O205] 🔴**획득 시점** 개발인입경로(MM293 라벨). 적재 시점 동결값',
    fee.ACQ_DOMESTIC_OVERSEAS AS fee.ACQ_DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '[O205] 🔴**획득 시점** 캠페인 국내해외 구분. 적재 시점 동결값. ⚠️납입 대상 후원사업의 국내·해외 분류(SPONSORSHIP)와 다른 축이다',
    fee.ACQ_BIZ_CASE_TYPE AS fee.ACQ_BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업사례구분') COMMENT = '[O205] 🔴**획득 시점** 캠페인 사업사례구분. 적재 시점 동결값',
    fee.ACQ_CMMN_BRAND   AS fee.ACQ_CMMN_BRND_NM WITH SYNONYMS ('공통브랜드', '공동브랜드') COMMENT = '[O205] 🔴**획득 시점** 공통브랜드(MM297). ⚠️ACQ_BRAND(캠페인 브랜드)와 다른 축이다 — 「공통브랜드」를 물으면 이 축을 쓴다',
    fee.ACQ_UTM          AS fee.ACQ_MKTG_UTM_NM  WITH SYNONYMS ('UTM', 'utm') COMMENT = '[O205] 🔴**획득 시점** UTM 라벨. ⚠️채움이 낮다(코드사전 미등재분 NULL · 결측이 아니라 미등재) — UTM 별 합계는 전체보다 작으므로 부분집합임을 밝히고 채움 비율은 조회로 확인한다',
    fee.ACQ_SPNSR_DIV    AS fee.ACQ_SPNSR_DIV_NM WITH SYNONYMS ('후원구분', '세부캠페인 후원구분', '정기일시구분(캠페인)') COMMENT = '[O205] 🔴**획득 세부캠페인** 후원구분(CM035 정기후원/일시후원). ⚠️회비구분(FEE_DIV)·납입유형과 다른 축이다',
    fee.ACQ_CPR_DIV      AS fee.ACQ_CPR_DIV_NM   WITH SYNONYMS ('법인구분', '세부캠페인 법인구분', '법인') COMMENT = '[O205] 🔴**획득 세부캠페인** 법인구분(CM019 통합/사단/사복). 🔴조직 계층 법인(산출 불가)과 다른 축이다 — 「사단 회원 회비」는 이 축으로 답하고 캠페인 법인구분 기준임을 밝힌다'
  )
  METRICS (
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
    fee.PAYMENT_RATE_FEE AS SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('납부율', '납입율', '수납율')
      COMMENT = '납부율(**%**) = **회비** 납입액 ÷ **회비** 청구액 ×100. N(비가산 — 분자·분모를 각각 집계한 뒤 나눈다). 🔴분자·분모가 모두 회비라 모집단이 일치한다. `TOTAL_PAID_ALL` 을 분자로 바꾸면 기부금이 섞여 **100% 를 넘는다** — O40 에서 실제로 그 상태가 배포된 적이 있다(실측치는 이슈원장 §O40·§O56-C 참조). ⚠️기간 스코프 없이 답하지 말 것 — 미납이 이후 납입되는 구조라 최근 기간은 낮게 보인다. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. `SV_MEMBER_MONTHLY.PAYMENT_RATE_FEE`(공64 정본)와 **같은 단위**이므로 전체 합계는 두 SV 가 일치해야 한다(GATE-D).',
    fee.UNPAID_RATIO AS SUM(fee.UNPAID_BILLED_AMT) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율', '미납률')
      COMMENT = '미납비중(**%**) = 미납 청구액 ÷ 회비 청구액 ×100. N(비가산). DEC-3 정본 분자. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. `SV_MEMBER_MONTHLY.UNPAID_RATIO` 와 **같은 이름·같은 식·같은 단위**이며 전체 합계가 일치해야 한다(GATE-D 실측 일치 확인 · 값은 이슈원장 §O55·§O56 참조). 🔴 종전 그쪽 정본 이름은 `UNPAID_RATIO_DEC3` 였고 짧은 이름은 폐기된 차감식이 쓰고 있었다 — 차감식 제거 후 이름이 일치했다.',
    fee.DISTINCT_PAYING_MEMBERS AS COUNT(DISTINCT fee.MEMBER_DK)
      WITH SYNONYMS ('납입 회원수', '회비 회원수', '납입(명)')
      COMMENT = '**고유 회원수(명)** = COUNT(DISTINCT 회원). N(비가산 — 기간·축을 가로질러 더하면 중복된다). 🔴이 팩트는 회원당 여러 행이므로 **행 수를 「명」으로 쓰면 크게 과대**해진다(`*_MEMBERS` 계열 함정과 같은 유형 · O39). 「납입 회원수」 질문은 반드시 이 metric 으로 답한다.',
    fee.TOTAL_BILLING_ROWS AS SUM(fee.BILLING_ROWS)
      WITH SYNONYMS ('청구행수', '원천 회비행수')
      COMMENT = '집계된 원천 회비행 수. F(가산). 🔴**금액도 「건수」도 아니다** — 정본 `(건)` 은 금액÷10,000 규약(CONF-2)이므로 이 값을 「건」이라 부르면 정의가 깨진다. 재청구 시도 강도를 볼 때만 쓴다.'
  )
  COMMENT = 'Phase-1 회비 분해 SV (base: GOLD.WIDE_MEMBER_FEE, grain: 회원×회비월×후원사업×회비구분×납입유형×결제수단). 후원사업, 납입방식(결제수단), 회비구분, 납입일별 회비 청구/납입/미납 정본 뷰. ⚠️ 회원-월 요약(SV_MEMBER_MONTHLY)과 동일 표 합산 금지(이중계상). 후원사업은 납입 대상 후원사업 기준임.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 이중계상 방지: SV_MEMBER_MONTHLY 와 본 뷰의 measure 를 한 표에 합산하지 말 것(표 분리). (2) 납부율: 납부율=PAYMENT_RATE_FEE (회비만 기준, %), 총수납액(회비+기부금)=TOTAL_PAID_ALL. (3) 회원수: 납입 회원수는 DISTINCT_PAYING_MEMBERS (distinct) 사용. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 후원사업 분기: 본 뷰의 SPONSORSHIP 은 납입 대상 후원사업이며, 개발 사건 시점은 SV_MEMBER_EVENT, 획득 시점은 SV_MEMBER_COHORT 로 라우팅. (6) 정렬: 비율 metric 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (7) 판정 라벨 [형제팩트중복]: 「납입(원)」·납입방식별 금액은 이 뷰를 앵커로 답한다. SV_MEMBER_MONTHLY 와 한 표에 합치지 않고 표를 분리하며 각 표의 grain 을 밝힌다. (8) 판정 라벨 [배분규칙필요]: 발송·사건 grain 으로 이 뷰의 회비 measure 를 요구받으면 SQL 을 만들지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다. 회비 measure 를 자기 grain(회원×회비월×후원사업)에서 묻는 질의는 정상 답변한다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 월은 **비상관 CTE 1개**(SELECT MAX(fee.MONTH_KEY) AS mk FROM fee)로 구하고 본 쿼리를 FROM fee CROSS JOIN 그 CTE 로 쓴다 — 본 쿼리 FROM 에서 fee 를 빼지 않는다. 후원사업은 **논리 차원 fee.SPONSORSHIP**, 납입방식은 **fee.PAYMENT_METHOD** 이다(🔴 종전 이 자리의 「fee.SPONSORSHIP 은 없다」는 **거꾸로 쓴 오기**였다 — 물리 컬럼명 SPONSORSHIP_NAME·PAYMENT_METHOD_NAME 을 CTE 컬럼으로 쓰지 말고 논리 차원명을 쓴다). 월 경계는 TO_DATE(TO_VARCHAR(MONTH_KEY), ''YYYYMM'') 로 날짜화해 DATEADD 한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_last12m_by_sponsorship AS (
      QUESTION '최근 12개월 후원사업별·납입방식별 회비 청구액과 납부율'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(fee.MONTH_KEY) AS mk FROM fee) SELECT fee.SPONSORSHIP, fee.PAYMENT_METHOD, SUM(fee.BILLED_AMT) AS TOTAL_BILLED_AMT, SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100 AS PAYMENT_RATE_FEE FROM fee CROSS JOIN mx WHERE fee.MONTH_KEY > TO_NUMBER(TO_CHAR(DATEADD(MONTH, -12, TO_DATE(TO_VARCHAR(mx.mk), ''YYYYMM'')), ''YYYYMM'')) AND fee.MONTH_KEY <= mx.mk GROUP BY fee.SPONSORSHIP, fee.PAYMENT_METHOD ORDER BY TOTAL_BILLED_AMT DESC NULLS LAST'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE TO ROLE GN_DW_SERVICE;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS TOTAL_BILLED_AMT)) AS sv_val,
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_MEMBER_FEE)                                           AS fact_val;

SELECT (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS TOTAL_BILLED_AMT))         AS fee_billed,
       (SELECT TOTAL_BILLED_AMT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_BILLED_AMT))     AS monthly_billed;

SELECT MAX(PAYMENT_RATE_FEE) AS max_rate
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS CAL_YEAR
       METRICS PAYMENT_RATE_FEE);

SELECT (SELECT DISTINCT_PAYING_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE METRICS DISTINCT_PAYING_MEMBERS)) AS distinct_members,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_FEE)                                                                AS fact_rows;

SELECT SPONSORSHIP, PAYMENT_METHOD, FEE_DIV, TOTAL_BILLED_AMT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS SPONSORSHIP, PAYMENT_METHOD, FEE_DIV
       METRICS TOTAL_BILLED_AMT)
ORDER BY TOTAL_BILLED_AMT DESC NULLS LAST
LIMIT 20;

SELECT ACQ_BRAND, TOTAL_PAID_FEE_BILLABLE, DISTINCT_PAYING_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_FEE
       DIMENSIONS ACQ_BRAND
       METRICS TOTAL_PAID_FEE_BILLABLE, DISTINCT_PAYING_MEMBERS)
ORDER BY TOTAL_PAID_FEE_BILLABLE DESC NULLS LAST
LIMIT 15;

SHOW SEMANTIC VIEWS LIKE 'SV_MEMBER_FEE' IN SCHEMA GN_DW.SERVING;

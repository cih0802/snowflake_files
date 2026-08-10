create or replace view GN_DW.GOLD.WIDE_MEMBER_FEE
    (
      MONTH_KEY COMMENT $$회비월 YYYYMM (무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 — FMM 과 동일 규칙)$$,
      CAL_YEAR COMMENT $$FLOOR(MONTH_KEY/100) — 연도$$,
      CAL_MONTH COMMENT $$MOD(MONTH_KEY,100) — 월$$,
      MEMBER_DK COMMENT $$회원 자연키(= 팩트 조인키, FK→DIM_MEMBER.MEMBER_DK). 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측. 🔴기부금 지류(BRONZE_CRM.TM_PM_DNTN_DTLS)에는 MBER_NO 컬럼이 **아예 없다**(회원키가 ONCE_MBER_NO) — 기부금 행의 회원 축은 구조적으로 부재하다. ⚠️FMM 규약과 일치시키기 위해 MBER_NO IS NOT NULL 을 적용한다(O45-C).$$,
      SPONSORSHIP_SK COMMENT $$🔴**납입 대상** 후원사업 대리키(FK→DIM_SPONSORSHIP) ← 원천 SPNSR_BSNS_ID. 0=미매핑. [O51-D 실측] **거의 전건 채움**이며 후원사업 종류는 수십 개다. 🔴획득 후원사업 ACQ_SPONSORSHIP_SK 와 **의미가 다르다** — 같은 라벨로 두 축이 존재한다. 이 축이 grain 에 들어간 것이 이 팩트를 FMM 과 분리한 이유다 — [O51-D 실측] 이 축을 붙이면 **회원-월 조합 수가 늘어 grain 이 깨진다**(증가율은 이슈원장 §O45·§O51-D). ⚠️인용 시 스코프를 함께 적을 것 — 종전 수치는 **BRONZE 회비 지류만**(MBER_NO not null) 스코프여서 분모가 다르다.$$,
      SPONSORSHIP_NAME COMMENT $$🔴**납입 대상** 후원사업 — 회비 행에 붙은 값이다(원천 SPNSR_BSNS_ID · 거의 전건 채움). 획득 후원사업(ACQ_SPONSORSHIP_NAME)과 다르다: 한 회원이 여러 후원사업에 낸다. 🔴이 축을 grain 에 넣으면 회원-월 조합 수가 늘어난다 — 그것이 이 팩트를 FMM 과 분리한 이유다(증가율 실측은 이슈원장 §O45·§O51-D).$$,
      FEE_DIV_CD COMMENT $$회비구분 코드 raw. 코드그룹 **PM010(회비구분)**. [O51-D BRONZE 실측] 사전 4종이며 **숫자가 아니라 알파벳 코드**다 — E정기·I일시·U긴급구호·G선물금. 실적재에 **사전 전종이 등장**하며 **E(정기)가 압도적**이다. 🔴기부금 행은 원천에 이 컬럼이 없어 NULL 이다 — **결측이 아니라 해당없음**(P21). 라벨 = FEE_DIV_NAME.$$,
      FEE_DIV_NAME COMMENT $$회비구분(PM010 실측 확정): 정기·선물금·일시·긴급구호. 🔴기부금 행은 원천이 NULL 이다 — 결측이 아니라 해당없음(P21)$$,
      PAYMENT_TYPE COMMENT $$납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프할 것 — 기부금은 원천에 청구(RQEST_AMT)가 전건 NULL 이라 분모에 들어갈 수 없다(O40)$$,
      PAYMENT_SK COMMENT $$결제수단 대리키(FK→DIM_PAYMENT) ← SETLE_CD 를 gold_sk 로 해싱. 0=미매핑. ⚠️라벨 커버리지가 완전하지 않다 — 원본 코드는 SETLE_CD 로 보존한다. 🟢[O51-D 실측] 미매핑 원인이 규명됐다 — DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 만으로 만들어지는데 회비 원천에는 **마스터에 없는 코드가 존재**한다. 사전(PM040) 기준으로 만들면 전건 라벨화된다(O45-B 처방).$$,
      PAYMENT_METHOD_NAME COMMENT $$DIM_PAYMENT.SETTLE_METHOD — 결제수단 라벨. 코드그룹 **PM040(결제정보)**. 원본 코드는 SETLE_CD. [O51-D BRONZE 실측 2026-08-07] 🟢**O45-B(코드그룹 미특정)가 해소됐다** — SETLE_CD 의 코드그룹은 PM040 이고 회비 원천 실적재 값(1자동이체·2신용카드·3신용카드즉시·4회비통장·5휴대폰·6휴대폰즉시·7MICR·8OCR·10실시간계좌이체·12네이버페이·13가상계좌즉시)이 **전부 PM040 사전에 존재**한다. 🔴미매핑 원인은 코드그룹 부재가 아니라 **DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 로만 만들어지고 그 마스터에 이 5종이 없다**는 것이다 ⇒ 처방 = DIM_PAYMENT 를 PM040 사전 기준으로 생성(재배선은 O51-D 범위 밖·별건 미결). 미라벨 행은 **코드는 있으나 차원에 행이 없는 5종(3·6·7·10·13)** 과 **SETLE_CD 자체가 NULL 인 행** 으로 나뉜다(규모는 이슈원장 §O45·§O51-D). ⚠️종전 문안의 *'코드그룹 미특정 · 6개 그룹이 전부 의미 무관'* 은 이 실측으로 폐기한다.$$,
      SETLE_CD COMMENT $$degenerate key: 결제수단 원본 코드 ← 원천 SETLE_CD(코드그룹 **PM040 결제정보**). 차원 라벨이 없는 코드를 잃지 않기 위해 보존한다. [O51-D 실측] 회비 원천 실적재 값 = 1자동이체 · 2신용카드 · 12네이버페이 · 8OCR · 4회비통장 · 3신용카드즉시 · 5휴대폰 · 10실시간계좌이체 · 6휴대폰즉시 · 13가상계좌즉시 · 7MICR (앞쪽이 최빈). 🟢**실적재 전종이 PM040 사전에 라벨을 갖는다** — 라벨화 공백은 코드 미상이 아니라 DIM_PAYMENT 생성 소스 문제다(O45-B 해소, 상세는 PAYMENT_METHOD_NAME).$$,
      LAST_PAY_DATE_SK COMMENT $$해당 조합의 **최종 납입일** (FK→DIM_DATE). 🔴합계가 아니라 시점 축이다. FMM 은 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 뷰에서만 답한다$$,
      LAST_PAY_DATE COMMENT $$최종 납입일(달력일) ← DIM_DATE.FULL_DATE, 키는 LAST_PAY_DATE_SK. 🔴시점 축이며 합계가 아니다 — 이 컬럼으로 GROUP BY 하면 회비월(MONTH_KEY)과 다른 분포가 나온다(납입 지연·선납 때문). 「기준일(납입일) 기준 조회」 요구는 이 컬럼으로 답하고, 「회비월 기준」은 MONTH_KEY 로 답한다. ⚠️미납 조합은 납입일이 없어 NULL.$$,
      LAST_BILL_DATE_SK COMMENT $$해당 조합의 최종 청구일 대리키(FK→DIM_DATE) ← 원천 RQEST_DE. 0=캘린더 범위밖·무효. 🔴시점 축이며 합계가 아니다. ⚠️최종 청구일만 보존하므로 조합 내 여러 청구건의 개별 일자는 이 팩트에서 복원할 수 없다 — 청구 건별 분해가 필요하면 SILVER.CRM_PAYMENT_BILLING 을 쓴다.$$,
      MBER_STAT_CD COMMENT $$DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · 실적재에 **사전 전종이 등장**한다. 🔴🔴**이 뷰의 미납 축(UNPAID_FLAG·UNPAID_BILLED_AMT)과 다른 개념**이다 — MM010 은 회원 **상태 코드**이고 미납 measure 는 **청구 실적**이다. 회원 단위 상태 기반 미납은 WIDE_MEMBER_MONTHLY 소관. 🔴현재버전 스냅샷이므로 과거 회비월에 현재 상태를 붙이면 시점이 어긋난다. 라벨 = MEMBER_STATUS_NAME.$$,
      MEMBER_STATUS_NAME COMMENT $$DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 미매핑은 '미상'. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다. 🔴현재버전 스냅샷이다.$$,
      MBER_DIV_CD COMMENT $$DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**: 1개인·2기업·3단체. 실적재에 **사전 전종이 등장**한다 · 교차검증으로 `2`(기업)=`SEX 7` · `3`(단체)=`SEX 6` **완전 일치**. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 다른 축이다. 라벨 = MEMBER_TYPE_NAME.$$,
      MEMBER_TYPE_NAME COMMENT $$DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 미매핑은 '미상'. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다**.$$,
      SEX COMMENT $$DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전 = 1국내(남자)~5외국인(기타)·6단체·7기업·8기타 · 실적재에 **사전 전종이 등장**한다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축은 GENDER_NAME 을 쓴다. 🔴회원 **현재버전**(IS_CURRENT 1건) 스냅샷이며 회비월 시점 값이 아니다. 획득 시점 성별은 DIM_MEMBER_ACQUISITION.ACQ_SEX_CD.$$,
      GENDER_NAME COMMENT $$DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. [O51-D BRONZE 실측] CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 🔴이 뷰에는 SEX_NM(국내·외국인 축)이 없다 — 그 축이 필요하면 WIDE_MEMBER_MONTHLY 를 쓴다. 🔴현재버전 스냅샷이다.$$,
      ACQ_CAMPAIGN_SK COMMENT $$DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_SK — **획득(가입) 캠페인** 대리키(FK→DIM_CAMPAIGN). 0=미매핑. 🔴회비를 낸 캠페인이 아니라 **이 회원을 데려온** 캠페인이다 — FMM/FMF 의 회비 자체에는 캠페인 축이 없어(전건 센티넬) 획득 시점 규칙으로 귀속시킨 것이다(O45·O8 우회). 🔴LEFT JOIN 필수 — 개발 사건이 없는 회원은 NULL 이다. 🔴🔴손실 규모는 **회원 기준으로 읽어야** 한다 — INNER 조인이 잃는 것은 회원이며, 행 가중 비율은 손실을 크게 축소해 보이게 한다(O51-D 정정 · 규모는 이슈원장 §O51-D).$$,
      ACQ_BRAND COMMENT $$획득 캠페인의 브랜드 ← DIM_CAMPAIGN.BRAND. 🔴획득 시점 귀속이며 회비 납입 대상과 무관하다. ⚠️획득 판정 근거가 FALLBACK(신규 사건 부재 → 최초 개발 사건 대체)인 회원은 신뢰도가 낮다 — 브랜드 비교는 DIM_MEMBER_ACQUISITION.ACQ_BASIS='NEW' 로 한정할 것을 권한다.$$,
      ACQ_CAMPAIGN_NAME COMMENT $$획득 캠페인명 ← DIM_CAMPAIGN.CAMPAIGN_NAME. 🔴획득 시점 귀속. ⚠️광고비와 결합할 때는 이 축이 아니라 ACQ_MARKETING_CAMPAIGN 을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃).$$,
      ACQ_PARENT_CAMPAIGN_NAME COMMENT $$획득 캠페인의 **상위캠페인**명 ← DIM_CAMPAIGN.PARENT_CAMPAIGN_NAME (원천 UPPER_CMPGN_CD 계층). 🔴캠페인 카테고리(MM294)와 다른 축이다 — 카테고리는 코드 기반 분류, 상위캠페인은 캠페인 자체의 부모다.$$,
      ACQ_PROMO_METHOD_NAME COMMENT $$획득 캠페인의 홍보방법명 ← DIM_CAMPAIGN.PROMO_METHOD_NAME. 코드그룹 **CM008(홍보방법)**. [O51-D BRONZE 실측] CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293)를 쓴다.$$,
      ACQ_MARKETING_CAMPAIGN COMMENT $$획득 캠페인의 마케팅캠페인(O45 conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃)$$,
      ACQ_ORG_SK COMMENT $$DIM_MEMBER_ACQUISITION.ACQ_ORG_SK — **획득 시점 담당조직** 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(WIDE_MEMBER_EVENT.ORG_*) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 두 값은 다르며 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(O34 규약).$$,
      ACQ_DEPARTMENT COMMENT $$🔴**획득(최초개발) 시점 부서**다. 개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용)$$,
      ACQ_SPONSORSHIP_SK COMMENT $$DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK — **획득 시점 후원사업** 대리키(FK→DIM_SPONSORSHIP). 0=미매핑. 🔴🔴같은 뷰의 SPONSORSHIP_SK(=회비 **납입 대상** 후원사업)와 **의미가 다르다** — 같은 라벨로 두 축이다. 한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다.$$,
      ACQ_SPONSORSHIP_NAME COMMENT $$획득 시점 후원사업명 ← DIM_SPONSORSHIP.SPONSORSHIP_NAME. 코드 = ACQ_SPONSORSHIP_SK. 🔴납입 대상 후원사업명(SPONSORSHIP_NAME)과 **다른 컬럼**이다 — 두 컬럼을 같은 표에 두면 반드시 혼동되므로 접두 ACQ_ 로 구분한다.$$,
      ACQ_AGE_BAND COMMENT $$획득 시점 연령대명(**CM014** 라벨) ← FACT_MEMBER_COHORT.ACQ_AGE_BAND. 코드 = FMC.ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가(O34). 🔴연속형이 아니므로 평균·재구간화 금지. ✅'10대 미만'이 상위인 것은 오류가 아니다(편지쓰기대회 계열 아동 모집 캠페인) — 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 '70대'·'70대 이상'이 의미 중복으로 공존한다.$$,
      ACQ_REGION COMMENT $$획득 시점 지역명(**CM018** 약칭 라벨) ← FACT_MEMBER_COHORT.ACQ_REGION. 코드 = FMC.ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 코드 '0'(개발약정 실적재에 존재)은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다.$$,
      BILLED_AMT COMMENT $$청구액(원) = SUM(RQEST_AMT). 🔴FMM 과 **동일한 식**이므로 두 팩트의 전체 합계가 일치해야 한다 — 이 일치가 검증 관문이다(GATE-D · 기준값은 이슈원장 §O45). 🔴🔴WIDE_MEMBER_MONTHLY 의 회비 measure 와 **같은 표에서 합산 금지**(DEC-31) — 동일 원천을 다른 grain 으로 담은 형제 팩트라 이중계상된다.$$,
      PAID_FEE COMMENT $$납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40) — PAID_FEE_BILLABLE 을 쓴다$$,
      PAID_FEE_BILLABLE COMMENT $$회비 납입액(원) — 납부율 분자 정본(O40)$$,
      UNPAID_BILLED_AMT COMMENT $$미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식(청구−납입) 아님. ⚠️조회 시점 스냅샷 — 과거 미납이 이후 납입되면 값이 바뀐다$$,
      BILLING_ROWS COMMENT $$집계된 원천 회비행 수. 🔴금액이 아니다 — 「건수」로 쓰지 말 것(정본 (건) 정의는 CONF-2 미결)$$,
      UNPAID_FLAG COMMENT $$해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG). 회원 단위 미납 여부는 WIDE_MEMBER_MONTHLY 의 UNPAID_FLAG_EOM 을 쓴다$$
    )
    comment = $$회비 분해 팩트(FMF) 평탄화 — SPONSORSHIP·PAYMENT·DATE(최종납입일)·MEMBER[현재버전]·ACQUISITION[획득귀속]. grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단. 계보(BRONZE 실측 2026-08-07): BRONZE_CRM.TM_PM_MBRFEE_ACMSLT(회비) ∪ TM_PM_DNTN_DTLS(기부금) → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE. 🔴기부금 지류의 청구액·회비구분 NULL 은 결측이 아니라 **구조적 부재**다 — TM_PM_DNTN_DTLS 30컬럼 전수 확인 결과 RQEST_AMT·MBRFEE_DIV_CD·MBER_NO 컬럼이 **아예 없다**(회원키는 ONCE_MBER_NO). ⇒ 납부율·미납 분모는 회비로 스코프(O40) · 분자는 PAID_FEE_BILLABLE. 🔴🔴WIDE_MEMBER_MONTHLY 와 **같은 표에서 회비 measure 합산 금지** — 같은 원천을 다른 grain 으로 담은 형제 팩트이며 실측 청구액이 **두 자리 % 로 부풀어 오른다**(DEC-31·GATE-D · 기준값은 이슈원장 §O45). 🔴「후원사업」·「부서」는 축이 둘이다 — SPONSORSHIP_NAME/ACQ_DEPARTMENT=획득·납입 대상, 사건 축은 WIDE_MEMBER_EVENT 소관.$$
    as (
      -- WIDE_MEMBER_FEE: 회비 분해 소비뷰 — 후원사업 × 회비구분 × 결제수단 × 획득귀속
-- Co-authored with CoCo
-- [2026-08-06 O45] 신설. base = FACT_MEMBER_FEE(회원×회비월×후원사업×회비구분×납입유형×결제수단).
--
-- 🔴 이 뷰가 답하는 것 / 답하지 않는 것
--   답한다: 후원사업별·회비구분별(정기/선물금/일시/긴급구호)·결제수단별 청구·납입·미납,
--           납입일 기준 조회, 획득 캠페인·부서·후원사업별 회비 분해
--   답하지 않는다: 회원 **상태**(활동/미납 플래그)·개발/중단 건수 → `WIDE_MEMBER_MONTHLY` 를 쓴다
--   🔴 두 뷰의 회비를 **같은 표에서 합하지 말 것** — 같은 원천이라 이중계상이다.
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100)                    as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)                       as CAL_MONTH,
    f.MEMBER_DK,
    -- ── 납입 대상 축 ──────────────────────────────────────────────────────────
    f.SPONSORSHIP_SK,
    s.SPONSORSHIP_NAME                          as SPONSORSHIP_NAME,
    f.FEE_DIV_CD,
    f.FEE_DIV_NAME                              as FEE_DIV_NAME,
    f.PAYMENT_TYPE                              as PAYMENT_TYPE,
    f.PAYMENT_SK,
    p.SETTLE_METHOD                             as PAYMENT_METHOD_NAME,
    f.SETLE_CD                                  as SETLE_CD,
    f.LAST_PAY_DATE_SK,
    dp.FULL_DATE                                as LAST_PAY_DATE,
    f.LAST_BILL_DATE_SK,
    -- ── 회원 현재 속성 (SCD2 현재행 1건) ──────────────────────────────────────
    mem.MBER_STAT_CD                            as MBER_STAT_CD,
    mem.MEMBER_STATUS_NAME                      as MEMBER_STATUS_NAME,
    mem.MBER_DIV_CD                             as MBER_DIV_CD,
    mem.MEMBER_TYPE_NAME                        as MEMBER_TYPE_NAME,
    mem.SEX                                     as SEX,
    mem.GENDER_NAME                             as GENDER_NAME,
    -- ── 획득 귀속 축 (O45 · LEFT JOIN 필수 — 개발사건 없는 회원 1.61% 존재) ───
    acq.ACQ_CAMPAIGN_SK,
    acq.ACQ_BRAND                               as ACQ_BRAND,
    acq.ACQ_CAMPAIGN_NAME                       as ACQ_CAMPAIGN_NAME,
    acq.ACQ_PARENT_CAMPAIGN_NAME                as ACQ_PARENT_CAMPAIGN_NAME,
    acq.ACQ_PROMO_METHOD_NAME                   as ACQ_PROMO_METHOD_NAME,
    acq.ACQ_MARKETING_CAMPAIGN                  as ACQ_MARKETING_CAMPAIGN,
    acq.ACQ_ORG_SK,
    acq.ACQ_DEPARTMENT                          as ACQ_DEPARTMENT,
    acq.ACQ_SPONSORSHIP_SK,
    acq.ACQ_SPONSORSHIP_NAME                    as ACQ_SPONSORSHIP_NAME,
    acq.ACQ_AGE_BAND                            as ACQ_AGE_BAND,
    acq.ACQ_REGION                              as ACQ_REGION,
    -- ── measure ──────────────────────────────────────────────────────────────
    f.BILLED_AMT,
    f.PAID_FEE,
    f.PAID_FEE_BILLABLE,
    f.UNPAID_BILLED_AMT,
    f.BILLING_ROWS,
    f.UNPAID_FLAG
from GN_DW.GOLD.FACT_MEMBER_FEE f
left join GN_DW.GOLD.DIM_SPONSORSHIP s        on s.SPONSORSHIP_SK  = f.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_PAYMENT p            on p.PAYMENT_SK      = f.PAYMENT_SK
left join GN_DW.GOLD.DIM_DATE dp              on dp.DATE_SK        = f.LAST_PAY_DATE_SK
-- 회원 차원은 SCD2 → 현재행 1건만 (WIDE 공통 패턴)
left join (
    select MEMBER_DK, SEX, GENDER_NAME, MBER_STAT_CD, MEMBER_STATUS_NAME,
           MBER_DIV_CD, MEMBER_TYPE_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) mem on mem.MEMBER_DK = f.MEMBER_DK
-- [O45] 회원 귀속 차원. 1행/회원이므로 fan-out 0(실측 확인).
left join GN_DW.GOLD.DIM_MEMBER_ACQUISITION acq on acq.MEMBER_DK = f.MEMBER_DK
    );
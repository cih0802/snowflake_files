create or replace view GN_DW.GOLD.DIM_MEMBER_ACQUISITION
    (
      MEMBER_DK COMMENT $$회원 자연키(= 팩트 조인키). 🔴본 뷰는 **1행 = 1회원**이다(O51-D 실측: base FACT_MEMBER_COHORT 의 행수 = 고유회원 수) ⇒ 팩트와 조인해도 팬아웃 0. 🔴단 **LEFT JOIN 필수** — 개발 사건이 없는 회원은 이 뷰에 존재하지 않는다🔴🔴[O51-D 실측] 손실 규모는 **분모를 무엇으로 잡느냐로 크게 달라진다** — INNER 조인이 잃는 것은 **회원**이므로 **회원 기준 비율이 정본**이다(FMM·FSE·FEP 실측치는 이슈원장 §O51-D-B). ⚠️종전 문안이 쓰던 비율은 **행 가중**이어서 손실을 크게 축소해 보이게 했다(O51-D 정정).$$,
      ACQ_CAMPAIGN_SK COMMENT $$획득 캠페인 대리키(FK→DIM_CAMPAIGN). 0=미매핑·부재. 🔴**회원을 처음 데려온** 캠페인이다 — 회비·월실적 팩트의 캠페인 축은 전건 센티넬인데, 그 이유는 원천 부재가 아니라 **다중캠페인 후원의 귀속 규칙이 없었다**는 것이다(O45 판정) 이 뷰가 「획득 시점」이라는 명시된 규칙으로 대체한다(O45·O8 우회).$$,
      ACQ_ORG_SK COMMENT $$획득 시점 담당조직 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(FACT_MEMBER_EVENT.ORG_SK) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(O34 규약).$$,
      ACQ_SPONSORSHIP_SK COMMENT $$획득 시점 후원사업 대리키(FK→DIM_SPONSORSHIP). 0=미매핑. 🔴🔴회비 **납입 대상** 후원사업(FACT_MEMBER_FEE.SPONSORSHIP_SK)과 **의미가 다르다** — 같은 라벨로 두 축이다. 한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다.$$,
      ACQ_DATE_SK COMMENT $$획득일 대리키(FK→DIM_DATE) — 획득 사건의 발생일. 0=캘린더 범위밖·무효. ⚠️회원번호 생성일(DIM_MEMBER_CURRENT.FIRST_JOIN_DATE)과 다르다 — 이 값은 **개발약정 사건일**이다.$$,
      ACQ_BASIS COMMENT $$획득 판정 근거. 'NEW'=개발구분 **신규**(MM015 코드 '1') 사건으로 판정 / 'FALLBACK'=신규 사건이 없어 **최초 개발 사건**으로 대체 판정. 🔴FALLBACK 은 획득캠페인 신뢰도가 낮다 — 캠페인·브랜드 비교 시 ACQ_BASIS='NEW' 로 한정할 것을 권한다. ⚠️개발 이력이 아예 없는 중단회원은 획득 캠페인을 알 수 없어 이 뷰에 **존재하지 않는다**(중단 총계는 FACT_MEMBER_EVENT 를 쓴다).$$,
      ACQ_DVLP_DIV_CD COMMENT $$획득 사건의 개발구분 코드. 코드그룹 **MM015(개발구분)**. 코드사전 = 1신규·2증액·3감액·4재후원·5후원중단 · 실적재에 **사전 전종이 등장**한다. ⚠️ACQ_BASIS='NEW' 이면 이 값은 항상 '1'이다 — 그 외 값은 FALLBACK 경로를 뜻한다. 🔴MM015 는 회원상태 MM010 이 아니다(두 그룹 모두 '후원중단'을 포함한다).$$,
      ACQ_AGE_CD COMMENT $$획득 시점 연령대 코드. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. ⚠️사전 자체에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 라벨 = ACQ_AGE_BAND.$$,
      ACQ_AGE_BAND COMMENT $$획득 시점 연령대명(CM014 라벨, 사전 조인 — 하드코딩 아님 P31). 코드 = ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가(O34). ✅'10대 미만'이 상위인 것은 오류가 아니다 — 편지쓰기대회 계열 캠페인이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B).$$,
      ACQ_AREA_CD COMMENT $$획득 시점 지역 코드. 코드그룹 **CM018**. 코드사전은 시·도 목록이고 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드는 전부 시·도다. 라벨 = ACQ_REGION.$$,
      ACQ_REGION COMMENT $$획득 시점 지역명(CM018 약칭 라벨, 정본 공#131). 코드 = ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 '0' 은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다.$$,
      ACQ_SEX_CD COMMENT $$획득 시점 성별 코드. 코드그룹 **CM013(성별)**. 실적재(`TM_MM_FDRM_MBER_DVLP_AMT.SEX`)에 **사전 전종 + 사전에 없는 센티넬 '0'** 이 나타난다. 🔴DIM_MEMBER 의 분석 성별(GENDER_NAME·CM017 계열)과 **라벨 체계가 다르다** — 이 축은 국내/외국인 구분을 보존한다. 라벨 = ACQ_GENDER.$$,
      ACQ_GENDER COMMENT $$획득 시점 성별명(CM013 라벨): 국내(남자)·국내(여자)·외국인(남자)·외국인(여자)·외국인(기타)·단체·기업·기타. 코드 = ACQ_SEX_CD. 🔴DIM_MEMBER_CURRENT.GENDER_NAME(CM017 · 5종)과 값 집합이 다르다 — 두 축을 같은 표에서 비교하지 말 것. ⚠️센티넬 '0' 은 사전 라벨이 없어 NULL.$$,
      ACQ_SPNSR_AMT COMMENT $$획득 사건의 후원금액(원, raw) ← TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT. 🔴**건수로 환산하지 말 것** — 정본 공#38·#151 이 **금액을 만원 단위로 나눈 값**이라는 규약이라 혼용하면 정의가 깨진다(CONF-2). ⚠️획득 시점 약정액이며 이후 증액·감액은 반영되지 않는다(현재 약정액이 아니다).$$,
      ACQ_BRAND COMMENT $$획득 캠페인의 브랜드 ← DIM_CAMPAIGN.BRAND. 차원 단독 조회로도 뜻이 통하게 라벨을 비정규화했다(DEC-10). ⚠️ACQ_BASIS='FALLBACK' 인 회원은 귀속 신뢰도가 낮다.$$,
      ACQ_CAMPAIGN_NAME COMMENT $$획득 캠페인명 ← DIM_CAMPAIGN.CAMPAIGN_NAME. ⚠️광고비와 결합할 때는 이 축이 아니라 ACQ_MARKETING_CAMPAIGN 을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃).$$,
      ACQ_PARENT_CAMPAIGN_NAME COMMENT $$획득 캠페인의 **상위캠페인**명 ← DIM_CAMPAIGN.PARENT_CAMPAIGN_NAME (원천 UPPER_CMPGN_CD 계층). 🔴캠페인 카테고리(MM294)와 다른 축이다 — 카테고리는 코드 기반 분류, 상위캠페인은 캠페인 자체의 부모다.$$,
      ACQ_PROMO_METHOD_NAME COMMENT $$획득 캠페인의 홍보방법명 ← DIM_CAMPAIGN.PROMO_METHOD_NAME. 코드그룹 **CM008(홍보방법)**. [O51-D BRONZE 실측] CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293 · DIM_CAMPAIGN.INFLOW_PATH)를 쓴다.$$,
      ACQ_MARKETING_CAMPAIGN COMMENT $$획득 캠페인의 마케팅캠페인(O45 conformed 축) ← DIM_CAMPAIGN.MARKETING_CAMPAIGN (원천 MKTG_CMPGN_NM). 🟢**광고비와 결합하는 정본 축**이다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃).$$,
      ACQ_DEPARTMENT COMMENT $$획득 시점 부서명 ← DIM_ORG.DEPARTMENT. 코드 = ACQ_ORG_SK. 🔴**획득(최초개발) 시점 부서**다 — 개발실적보고의 「부서」(=사건 부서)와 다르다. 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용). ⚠️DIM_ORG 는 SCD1(DEC-2)이라 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다.$$,
      ACQ_SPONSORSHIP_NAME COMMENT $$획득 시점 후원사업명 ← DIM_SPONSORSHIP.SPONSORSHIP_NAME(정본 공#123). 코드 = ACQ_SPONSORSHIP_SK. 🔴회비 **납입 대상** 후원사업명(WIDE_MEMBER_FEE.SPONSORSHIP_NAME)과 다른 축이다.$$,
      FIRST_STOP_DATE_SK COMMENT $$최초 중단일 대리키(FK→DIM_DATE) — 중단원천(EVENT_TYPE='STOP') 기준 최초 사건. 🔴**미중단 회원은 NULL** 이며 0 이 아니다 — 0 은 「날짜 미상」이라는 다른 뜻이다(P21). 중단했으나 일자가 캘린더 범위밖이면 0.$$,
      FIRST_STOP_REASON_NM COMMENT $$최초 중단의 사유명. 코드그룹 **MM005(후원중단사유)**. 미중단 회원은 NULL. 코드사전에는 **폐지코드(USE_YN='N')가 다수 섞여** 있고 실적재는 사전의 일부만 쓴다. 🔴🔴**USE_YN 필터 금지** — 실적재 20종 중 6종(366행)이 폐지코드이며 필터를 걸면 그 라벨이 사라진다.$$,
      TENURE_DAYS COMMENT $$유지기간(일) = 최초 중단일 − 획득일. 🔴**미중단 회원은 NULL** 이다 — 아직 종료되지 않은 관측(우측 절단)이며 0 이나 '현재까지 경과일'로 채우면 평균 유지기간이 조용히 틀린다. 획득일·중단일 중 하나가 무효면 NULL. ⇒ 평균 유지기간은 중단 회원만으로 계산하거나 생존분석을 쓸 것.$$,
      IS_12M_OBSERVABLE COMMENT $$12개월 관측 가능 여부 = 획득일 + 12개월 ≤ 데이터 최종 사건일. 🔴🔴**12개월 이탈률의 분모 자격**이다 — 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 포함시키면 최근 캠페인이 실제보다 이탈률이 낮게 보인다(분모에 아직 이탈할 시간이 없는 회원이 섞인다).$$
    )
    comment = $$회원 획득(가입) 귀속 차원 — 1행=1회원. base=FACT_MEMBER_COHORT(단일 정의 지점·저장 중복 0). 🔴모든 ACQ_* 는 **획득 시점** 값이며 현재 속성이 아니다(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가·O34). 🔴「부서」·「후원사업」은 같은 라벨로 두 축이 존재한다 — 사건 부서=FACT_MEMBER_EVENT.ORG_SK · 납입 대상 후원사업=FACT_MEMBER_FEE.SPONSORSHIP_SK. 🔴팩트와는 반드시 LEFT JOIN — 개발 사건이 없는 회원이 사라진다 — 🔴손실은 **회원 기준**으로 읽어야 한다(행 가중 비율은 손실을 축소해 보이게 한다 · 규모는 이슈원장 §O51-D-B). 신설 경위(O45): FMM 의 CAMPAIGN_SK·SPONSORSHIP_SK 가 전건 센티넬인 것은 원천 부재가 아니라 **다중캠페인 후원의 귀속 규칙이 없어서**였고, 임의 귀속 대신 「획득 시점」이라는 명시된 규칙을 채택했다(O8 우회).$$
    as (
      -- DIM_MEMBER_ACQUISITION: 회원 획득 귀속 차원 (1행=1회원) — `FACT_MEMBER_COHORT` 위의 뷰
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O45] 신설 — O8(다중후원 귀속 규칙 미확정)의 우회로
-- ----------------------------------------------------------------------------
-- 🔴 문제: `FACT_MEMBER_MONTHLY` 의 `CAMPAIGN_SK`·`SPONSORSHIP_SK` 는 **전건 센티넬**이다.
--    원천에 캠페인이 없어서가 아니다 — 회원-월 grain 에서 다중캠페인 후원(7.98% · 단일
--    회원-월 최대 60개)을 어디에 귀속시킬지 규칙이 없어서 0 으로 둔 것이다.
--    그 결과 보고서필드 **41필드 · 11섹션**이 「브랜드·상위캠페인·캠페인명·홍보방법·후원사업·부서」를
--    분해할 수 없었다(O44 실측).
--
-- 🟢 해법: **임의 귀속을 하지 말고 「획득 시점」이라는 명시된 규칙**을 쓴다.
--    `FACT_MEMBER_COHORT` 는 이미 회원 1행이고 획득 사건의 캠페인·연령·지역·성별을 갖고 있다.
--    거기에 **획득 부서·획득 후원사업 2축만** 더하면 회원 귀속 차원이 완성된다.
--
-- 🔴 왜 테이블이 아니라 뷰인가: 같은 사실을 두 곳에 저장하면 반드시 어긋난다(O43 P85 교훈).
--    FMC 가 단일 정의 지점이고 이 뷰는 **차원으로서의 의미만 부여**한다(저장 중복 0).
--    SV 에서는 이 뷰를 dimension 으로 선언해 팩트-팩트 조인처럼 보이지 않게 한다.
--
-- ── 조인 안전성 실측(2026-08-06) — 팬아웃 0 ────────────────────────────────────
--   `FACT_MEMBER_COHORT` 1,585,949행 = 1,585,949 고유회원 → **1행/회원 확인**
--   ⋈ `FACT_MEMBER_MONTHLY`      40,054,883 → 39,409,747  (미매칭 1.61%)
--   ⋈ `FACT_SERVICE_EVENT`       38,470,780 → 38,339,810  (99.66%)
--   ⋈ `FACT_EVENT_PARTICIPATION`  1,134,126 →  1,119,559  (98.70%)
--   ⇒ 반드시 **LEFT JOIN** 할 것. INNER 로 걸면 개발 사건이 없는 회원(일시회원 등)이 사라진다.
--
-- 🔴 네이밍 규약 — O34 교훈(`_AT_PLEDGE` vs `_AT_EVENT`)의 재적용:
--    「부서」라는 같은 라벨이 보고서마다 다른 축을 뜻한다.
--      · **개발실적보고**의 부서 = **사건 부서** → `FACT_MEMBER_EVENT.ORG_SK` 를 쓴다
--      · **연간분석(회비)**의 부서 = **획득 부서** → 이 차원의 `ACQ_ORG_*` 를 쓴다
--    두 값은 다르다. 이름으로 구분되지 않으면 소비 측이 조용히 틀린다.
-- ============================================================================
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    c.MEMBER_DK                                     as MEMBER_DK,          -- 자연키(= 팩트 조인키)
    -- ── 획득 귀속 축 ─────────────────────────────────────────────────────────
    c.ACQ_CAMPAIGN_SK                               as ACQ_CAMPAIGN_SK,
    c.ACQ_ORG_SK                                    as ACQ_ORG_SK,
    c.ACQ_SPONSORSHIP_SK                            as ACQ_SPONSORSHIP_SK,
    c.ACQ_DATE_SK                                   as ACQ_DATE_SK,
    c.ACQ_BASIS                                     as ACQ_BASIS,          -- NEW=신규사건 / FALLBACK=최초개발사건
    c.ACQ_DVLP_DIV_CD                               as ACQ_DVLP_DIV_CD,
    -- ── 획득 시점 회원 속성 (현재 값이 아니다 — O34) ──────────────────────────
    c.ACQ_AGE_CD                                    as ACQ_AGE_CD,
    c.ACQ_AGE_BAND                                  as ACQ_AGE_BAND,
    c.ACQ_AREA_CD                                   as ACQ_AREA_CD,
    c.ACQ_REGION                                    as ACQ_REGION,
    c.ACQ_SEX_CD                                    as ACQ_SEX_CD,
    c.ACQ_GENDER                                    as ACQ_GENDER,
    c.ACQ_SPNSR_AMT                                 as ACQ_SPNSR_AMT,
    -- ── 라벨(차원 단독 조회로도 뜻이 통하게 — DEC-10 전제) ────────────────────
    cmp.BRAND                                       as ACQ_BRAND,
    cmp.CAMPAIGN_NAME                               as ACQ_CAMPAIGN_NAME,
    cmp.PARENT_CAMPAIGN_NAME                        as ACQ_PARENT_CAMPAIGN_NAME,
    cmp.PROMO_METHOD_NAME                           as ACQ_PROMO_METHOD_NAME,
    cmp.MARKETING_CAMPAIGN                          as ACQ_MARKETING_CAMPAIGN,
    org.DEPARTMENT                                  as ACQ_DEPARTMENT,
    spb.SPONSORSHIP_NAME                            as ACQ_SPONSORSHIP_NAME,
    -- ── 코호트 결과 measure (중단률·유지기간은 이 차원이 아니라 FMC 에서 집계) ──
    c.FIRST_STOP_DATE_SK                            as FIRST_STOP_DATE_SK,
    c.FIRST_STOP_REASON_NM                          as FIRST_STOP_REASON_NM,
    c.TENURE_DAYS                                   as TENURE_DAYS,
    c.IS_12M_OBSERVABLE                             as IS_12M_OBSERVABLE
from GN_DW.GOLD.FACT_MEMBER_COHORT c
left join GN_DW.GOLD.DIM_CAMPAIGN     cmp on cmp.CAMPAIGN_SK     = c.ACQ_CAMPAIGN_SK
left join GN_DW.GOLD.DIM_ORG          org on org.ORG_SK          = c.ACQ_ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP  spb on spb.SPONSORSHIP_SK  = c.ACQ_SPONSORSHIP_SK
    );
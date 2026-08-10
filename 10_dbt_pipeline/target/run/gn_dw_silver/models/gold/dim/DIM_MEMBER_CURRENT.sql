create or replace view GN_DW.GOLD.DIM_MEMBER_CURRENT
    (
      MEMBER_SK COMMENT $$DIM_MEMBER 의 **버전 대리키**. ⚠️본 뷰는 IS_CURRENT 행만 담으므로 회원 1명당 1값이지만, 그 의미는 여전히 '현재 버전 행의 키'다 — 회원 식별에는 MEMBER_DK 를 쓴다(MEMBER_SK 는 재빌드 시 달라질 수 있다).$$,
      MEMBER_DK COMMENT $$불변 회원키(조인용 자연키). 🔴모든 회원 팩트(FMM·FME·FSE·FEP·FMF)가 이 키로 조인한다. 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측.$$,
      MEMBER_TYPE COMMENT $$회원 **등록계통** 구분 — FDRM=정기회원(원천 `BRONZE_CRM.TM_MM_FDRM_MBER_INFO`) / ONCE=일시회원(원천 `TM_MM_ONCE_MBER_INFO`). 🔴🔴일시회원은 회원상태(MM010)·가입경로(MM014) 개념이 **원천에 없다** — 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE='FDRM' 으로 한정할 것. ⚠️MEMBER_TYPE_NAME(개인/기업/단체, MM018)은 이 컬럼의 라벨이 **아니다** — 완전히 다른 축이며 코드는 MBER_DIV_CD 다.$$,
      SEX COMMENT $$성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전 = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타. 정기회원·일시회원 **양쪽 원천 모두 사전 전종이 등장**한다(일시회원은 소수의 NULL 이 있다). 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축은 GENDER_NAME 을 쓴다. 라벨 = SEX_NM·GENDER_NAME.$$,
      SEX_NM COMMENT $$CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — GENDER_NAME(CM017)은 그 축을 지운다.$$,
      GENDER_NAME COMMENT $$성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. [O51-D BRONZE 실측] CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 5종을 3종으로 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정).$$,
      MBER_STAT_CD COMMENT $$회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD, 무이력행은 MBER_STAT_CD 에서 온다. 🔴개발구분 MM015 가 아니다(두 그룹 모두 '후원중단'을 포함한다). 🔴일시회원(ONCE)은 NULL. 라벨 = MEMBER_STATUS_NAME.$$,
      MEMBER_STATUS_NAME COMMENT $$회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 미매핑은 '미상'. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). ⚠️미납 단계(1~5)는 경과 차수이며 금액 규모가 아니다.$$,
      MEMBER_STATUS_GROUP COMMENT $$회원상태 **대분류**(파생): MM010 코드 1→'정상' · 2~11→'미납' · 12→'중단' · NULL→'미상'. 🔴신규미납(2~6)과 장기미납(7~11)을 한 값으로 묶는다 — 두 단계를 구분해야 하면 MEMBER_STATUS_NAME 을 쓴다. ⚠️원천 코드그룹이 아니라 DW 파생 축이다(DIM_MEMBER.sql 단일 소유).$$,
      MBER_DIV_CD COMMENT $$회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**: 1개인·2기업·3단체. 정기회원·일시회원 **양쪽 모두 사전 전종이 등장**한다. 🟢독립 교차검증: `2`(기업)·`3`(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다. 🔴MEMBER_TYPE(FDRM/ONCE)과 다른 축이다. 라벨 = MEMBER_TYPE_NAME.$$,
      MEMBER_TYPE_NAME COMMENT $$회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 미매핑은 '미상'. 🔴🔴이름이 비슷한 MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 이 뷰에 두 컬럼이 나란히 있어 특히 혼동되기 쉽다.$$,
      JOIN_PATH_CD COMMENT $$가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = ENROLL_PATH_NAME.$$,
      ENROLL_PATH_NAME COMMENT $$가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 미매핑은 '미상'.$$,
      FIRST_JOIN_DATE COMMENT $$최초가입일 = 회원번호 생성일(정본 공#28). ⚠️후원 개시일이 아니다 — 첫 개발약정일은 DIM_MEMBER_ACQUISITION.ACQ_DATE_SK 로 답한다.$$,
      FIRST_CAMPAIGN COMMENT $$최초캠페인(정본 공#29). ⚠️획득 귀속 캠페인(DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_NAME)과 **판정 규칙이 다르다** — 획득 축은 개발구분 '신규' 사건(없으면 최초 개발 사건)을 근거로 정한다(ACQ_BASIS).$$,
      EFFECTIVE_FROM COMMENT $$SCD2 유효 시작 시각. 🔴본 뷰는 현재행만 담으므로 이 값은 '현재 상태가 시작된 시점'이다. 🔴과거 시점 상태가 필요하면 이 뷰가 아니라 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 그 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별(공통감사). 업무 축이 아니다 — GROUP BY 대상이 아니다.$$,
      DW_LOAD_TS COMMENT $$최초 적재 시각(공통감사). 업무 축이 아니다.$$,
      DW_UPDATE_TS COMMENT $$최종 갱신 시각(공통감사). ⚠️원천 변경 시각이 아니라 DW 적재 시각이다.$$,
      DW_BATCH_ID COMMENT $$적재 배치 식별자 = dbt invocation_id(공통감사). 재현·감사 추적용.$$
    )
    comment = $$🟢 GOLD 직접조회 분석가의 기본 진입점 — 회원 1명 = 1행. DIM_MEMBER 는 **SCD2 다버전**이므로 FACT 와 MEMBER_DK 직접 조인 시 팬아웃한다(단월·회비 측정에서 배수 과대 실측 — 규모는 이슈원장 §O51-D). 과거 시점 상태가 필요할 때만 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 이 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다. 🔴 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE='FDRM' 으로 한정할 것(일시회원 ONCE 는 회원상태·가입경로 개념이 원천에 없다). 본 뷰는 DIM_MEMBER 의 순수 투영이며 라벨 정의는 DIM_MEMBER.sql 단일 소유. 전건 NULL 7컬럼은 오답 방지를 위해 미노출(문서30 DEC-27 §17-C). ⚠️SERVING.DIM_MEMBER_CURRENT 와 동명이나 컬럼 집합이 다르다.$$
    as (
      -- DIM_MEMBER_CURRENT: 회원 차원 현재행(SCD2 IS_CURRENT) 소비뷰 — 분석가 기본 진입점 (DEC-27 §17-A)
-- Co-authored with CoCo
--
-- 🔴 왜 필요한가 (실측 근거)
--   회원 FACT 4개(FMM·FME·FSE·FEP)가 전부 MEMBER_DK 로 조인하는데 DIM_MEMBER 는 SCD2다
--   — 회원 1명 = 평균 4.50행(최대 218 · 56.5%가 다버전). 순진한 조인은 **조용히** 팬아웃한다.
--   실측(202606 단월): FACT 734,521행 → join 후 2,645,714행(3.60배) · 납입회비 171.3억 → 507.5억(2.96배 과대).
--   에러도 경고도 없다. 그런데 GOLD 에는 비-WIDE 뷰가 0개여서 **안전한 기본값이 아예 없었다**.
--
-- ⚠️ 본 뷰는 DIM_MEMBER 의 **순수 투영**이다 — 파생·라벨 로직을 두지 않는다.
--   라벨 정의 단일 소유 = models/gold/dim/DIM_MEMBER.sql. 초판이 라벨 CASE 를 뷰에 중복
--   정의했다가 P33(정의 중복 → drift) 위반으로 제거했다.
--
-- ⚠️ 전건 NULL 7컬럼(REGION·AGE_BAND·NEW_EXISTING_FLAG·LAST_STOP_DATE·LAST_CAMPAIGN·
--   FIRST_SPONSORSHIP·CURRENT_SPONSORSHIP)은 **의도적으로 미노출** — 컬럼이 보이는데 항상 NULL 이면
--   분석가가 "값이 없다"로 오해하고 GROUP BY 한다(P15). 판정·근거 = 문서30 DEC-27 §17-C.
--
-- ⚠️ SERVING.DIM_MEMBER_CURRENT(SV 소비용, 02_SERVING_setup/08_After_Deploy 소관)와 동명이다.
--   양쪽 다 DIM_MEMBER 순수 투영이라 **값은 항상 일치**하나 컬럼 집합이 다르다
--   (SERVING 은 7여 포함·MEMBER_TYPE 미포함). SV 영향 점검 없이 통합하지 말 것.
--
-- ⚠️ GRANT 불요 — GOLD 스키마에 VIEW future grant(SELECT → ANALYST/VIEWER/SERVICE)가 이미 있어
--   매 build 시 자동 부여된다(실측 확인 2026-08-03).
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    MEMBER_SK,
    MEMBER_DK,
    MEMBER_TYPE,
    SEX,
    SEX_NM,
    GENDER_NAME,
    MBER_STAT_CD,
    MEMBER_STATUS_NAME,
    MEMBER_STATUS_GROUP,
    MBER_DIV_CD,
    MEMBER_TYPE_NAME,
    JOIN_PATH_CD,
    ENROLL_PATH_NAME,
    FIRST_JOIN_DATE,
    FIRST_CAMPAIGN,
    EFFECTIVE_FROM,
    DW_SOURCE_SYSTEM,
    DW_LOAD_TS,
    DW_UPDATE_TS,
    DW_BATCH_ID
from GN_DW.GOLD.DIM_MEMBER
where IS_CURRENT
    );
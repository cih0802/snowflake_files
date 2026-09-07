create or replace view GN_DW.GOLD.WIDE_MEMBER_MONTHLY
    (
      MONTH_KEY COMMENT $$YYYYMM$$,
      CAL_YEAR COMMENT $$FLOOR(MONTH_KEY/100) — 연도$$,
      CAL_MONTH COMMENT $$MOD(MONTH_KEY,100) — 월$$,
      MEMBER_DK COMMENT $$불변 회원키(조인용)$$,
      DEV_CNT COMMENT $$개발(건) SUM(금액)/10000 (#4·5·149)$$,
      DEV_MEMBERS COMMENT $$개발(명) COUNT (#148)$$,
      STOP_CNT COMMENT $$중단(건) (#35, FME 롤업)$$,
      UNPAID_CNT COMMENT $$미납(건) (#36)$$,
      ACTIVE_CNT COMMENT $$활동(건) (#37·157)$$,
      ACTIVE_MEMBERS COMMENT $$활동(명) (#156)$$,
      ACTIVE_CUM_CNT COMMENT $$활동누계(건) (#159)$$,
      ACTIVE_CUM_MEMBERS COMMENT $$활동누계(명) (#158)$$,
      INCREASE_CNT COMMENT $$증액(건) (#151)$$,
      INCREASE_MEMBERS COMMENT $$증액(명) (#150)$$,
      DECREASE_CNT COMMENT $$감액(건) SUM(감액금액)/10000 (#38)$$,
      CHURN_CNT COMMENT $$이탈(건) SUM(취소+감액)/10000 (신규#20)$$,
      YEAR_START_ACTIVE_CNT COMMENT $$연도초 활동회원(건) (#49)$$,
      YEAR_END_ACTIVE_CNT COMMENT $$연도말 활동회원(건) (#50)$$,
      MONTH_END_ACTIVE_CNT COMMENT $$월말활동회원(건) (#52)$$,
      PREV_MONTH_END_ACTIVE_CNT COMMENT $$전월말 활동회원(건) (#53)$$,
      CAMPAIGN_UNPAID_CNT COMMENT $$캠페인별 미납(건) (#83)$$,
      STATUS_UNPAID_CNT COMMENT $$회원상태별 미납(건) (#84)$$,
      REGULAR_FEE COMMENT $$정기회비(원) (#66)$$,
      REGULAR_ONETIME_FEE COMMENT $$정기회원 일시회비(원) (#67)$$,
      ONETIME_ONETIME_FEE COMMENT $$일시회원 일시회비(원) (#68)$$,
      PAID_FEE COMMENT $$납입회비(원) (#69·70 단일화)$$,
      BILLED_AMT COMMENT $$청구(원) (#71)$$,
      INBOUND_CALL_CNT COMMENT $$인바운드콜수 (overview)$$,
      TS_CALL_CNT COMMENT $$TS콜수 (overview)$$,
      DEV_TYPE COMMENT $$개발구분 (#121) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.DEV_TYPE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      NEW_FLAG COMMENT $$신규여부 (#32) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      INCREASE_FLAG COMMENT $$증액여부 (#33) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.INCREASE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      REDONATE_FLAG COMMENT $$재후원여부 (#34) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.REDONATE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      JOIN_DATE COMMENT $$캠페인 가입일 (#27) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.JOIN_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_FIRST_JOIN_DATE`(DIM_MEMBER 경유).$$,
      STOP_DATE COMMENT $$가입캠페인 중단일 (#26) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.STOP_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT.$$,
      AMOUNT_BAND1 COMMENT $$후원금액대1 5만 (#72) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      AMOUNT_BAND2 COMMENT $$후원금액대2 1만 (#73) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      PERIOD_BAND1 COMMENT $$후원기간대1 5년 (#74) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      PERIOD_BAND2 COMMENT $$후원기간대2 1년 (#75) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSOR_MONTHS COMMENT $$후원기간(개월) (#127)$$,
      SPONSOR_YEARS COMMENT $$후원기간(년) (#128)$$,
      PAID_MONTHS COMMENT $$납입개월수 (#129)$$,
      NEW_EXISTING_FLAG COMMENT $$신규/기존(시점귀속, #113) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      UNPAID_FLAG_BOM COMMENT $$월초 미납회원 여부(=전월말 상태, #80)$$,
      UNPAID_FLAG_EOM COMMENT $$월말 미납회원 여부 (#80)$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      SEX COMMENT $$DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. 코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · 실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. ⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. 🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. 라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      SEX_NM COMMENT $$DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). 코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. CM013 은 코드와 라벨이 1:1 이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_GENDER_NAME COMMENT $$DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_AREA_CD COMMENT $$DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_REGION COMMENT $$DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128).$$,
      MEMBER_AGE_CD COMMENT $$DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_AGE_BAND COMMENT $$DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128).$$,
      MBER_STAT_CD COMMENT $$DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_STATUS_NAME COMMENT $$DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      PREV_MBER_STAT_CD COMMENT $$DIM_MEMBER.PREV_MBER_STAT_CD — 상태전이의 **이전상태** 코드 raw(MM010). 현재상태 MBER_STAT_CD 와 짝지어 전이를 표현한다. 원천 `TH_MM_FDRM_MBER_STNG_DTLS.BF_STAT_CD` 에 **사전 전종이 등장**한다. ⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — '이전상태가 없다'가 아니라 '이력이 없다'. ⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실). 라벨 = PREV_MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      PREV_MEMBER_STATUS_NAME COMMENT $$DIM_MEMBER.PREV_MEMBER_STATUS_NAME — 이전상태명(MM010 라벨). 코드 = PREV_MBER_STAT_CD. 사전과 실적재가 일치한다. 이력 미보유행은 NULL. 🔷(PREV_MEMBER_STATUS_NAME → MEMBER_STATUS_NAME) 쌍이 전이 매트릭스의 두 축이다 — 이 버전행 자체가 전이 사건이므로 fan-out 0. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MBER_DIV_CD COMMENT $$DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_TYPE_NAME COMMENT $$DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_FIRST_JOIN_DATE COMMENT $$DIM_MEMBER.FIRST_JOIN_DATE — 최초가입일 (#28)$$,
      MEMBER_FIRST_CAMPAIGN COMMENT $$DIM_MEMBER.FIRST_CAMPAIGN — 최초캠페인 (#29)$$,
      JOIN_PATH_CD COMMENT $$DIM_MEMBER.JOIN_PATH_CD — 가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** ⇒ 가입경로 분포에서 이 두 값을 기대하지 말 것. 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = MEMBER_ENROLL_PATH_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_ENROLL_PATH_NAME COMMENT $$DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_FIRST_SPONSORSHIP COMMENT $$DIM_MEMBER.FIRST_SPONSORSHIP — 최초후원사업$$,
      MEMBER_LAST_STOP_DATE COMMENT $$DIM_MEMBER.LAST_STOP_DATE — 최종 중단일. 원천 BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE. 🔴**그 버전 시점까지의 as-of max** 다(전체 단순 max 가 아니다). 단순 max 는 미래 정보를 과거 버전에 누설해 예측 피처(LTV·유지기간)를 오염시킨다. ⚠️중단 이력이 없는 회원·중단 이전 버전은 NULL 이며 '중단하지 않았다'와 '이력이 없다'를 구분하지 않는다. 🔴이 뷰의 STOP_DATE(월 팩트 measure)와 다른 축이다.$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_PARENT COMMENT $$DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_PROMO_METHOD COMMENT $$DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_TYPE COMMENT $$DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSORSHIP_BK COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSORSHIP_NAME COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSORSHIP_ABBR COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. 🟢[2026-08-19 O89] 이 컬럼은 **코드(1~6)** 이고 라벨은 SPONSORSHIP_GROUP_NAME 이다 — 코드사전 CM003(후원약칭)으로 특정됐다(SPB-G 종결).$$,
      SPONSORSHIP_DIV_NAME COMMENT $$[2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🔴🔴 이 뷰에서는 `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 가 **전건 센티넬(0)** 이라 이 라벨도 `'(미매핑)'` 이다 — 분류별 분해는 `WIDE_MEMBER_FEE`(거의 전건 채움) 또는 `WIDE_MEMBER_EVENT`(DEV 브랜치 배선)를 쓸 것. 센티넬 원인은 O8(다중후원·다중캠페인 귀속 규칙 현업 미회신)이다.$$,
      SPONSORSHIP_GROUP_NAME COMMENT $$[2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. 🔴🔴 이 뷰에서는 팩트 FK 가 전건 센티넬이라 `'(미매핑)'` 이다(위 DIV_NAME 주석과 동일).$$,
      PAYMENT_METHOD COMMENT $$DIM_PAYMENT.PAYMENT_METHOD — 납입방식 (#125) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.PAYMENT_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      PAYMENT_SETTLE_METHOD COMMENT $$DIM_PAYMENT.SETTLE_METHOD — 결제방식 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      PAYMENT_FEE_TYPE COMMENT $$DIM_PAYMENT.FEE_TYPE — 회비유형(정기/일시) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. ⚠️게다가 `DIM_PAYMENT.FEE_TYPE` 자체도 전건 비어 있다(이중 결손).$$,
      REASON_CODE COMMENT $$DIM_REASON.REASON_CODE — 사유코드$$,
      REASON_NAME COMMENT $$DIM_REASON.REASON_NAME — 중단사유·미납사유 (#162·#82)$$,
      REASON_TYPE COMMENT $$DIM_REASON.REASON_TYPE — 중단/미납 구분$$
    )
    comment = $$회원 월 팩트(FMM) 평탄화 — MEMBER[현재버전]·CAMPAIGN·SPONSORSHIP·PAYMENT·REASON. 월 grain=MONTH_KEY.$$
    as (
      -- WIDE_MEMBER_MONTHLY: 회원 월 팩트(FMM) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.1)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100)   as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)      as CAL_MONTH,
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
    -- [2026-08-03 O26] 회원 속성 노출 재구성 — 코드=BRONZE 원천명 · 라벨=분석 용어.
    --   종전은 코드만(`MEMBER_GENDER`=M/F/U 등) 노출해 현업이 WIDE 에서 코드만 보던 상태였다.
    m.SEX                 as SEX,                     -- CM013 코드 raw
    m.SEX_NM              as SEX_NM,                  -- CM013 원천 라벨(국내/외국인 축)
    m.GENDER_NAME         as MEMBER_GENDER_NAME,      -- CM017 분석 라벨 = 정본 공#130
    m.AREA_CD             as MEMBER_AREA_CD,          -- [O27] CM018 코드 raw (라벨=MEMBER_REGION)
    m.REGION              as MEMBER_REGION,
    m.AGE                 as MEMBER_AGE_CD,           -- [O27] CM014 코드 raw. ⚠️연속형 나이 아님
    m.AGE_BAND            as MEMBER_AGE_BAND,
    m.MBER_STAT_CD        as MBER_STAT_CD,            -- MM010 코드 raw
    m.MEMBER_STATUS_NAME  as MEMBER_STATUS_NAME,      -- MM010 분석 라벨(#132)
    m.PREV_MBER_STAT_CD   as PREV_MBER_STAT_CD,       -- [O27] 상태전이 이전상태 코드(MM010)
    m.PREV_MEMBER_STATUS_NAME as PREV_MEMBER_STATUS_NAME,  -- [O27] 이전상태 라벨(MM010)
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    m.FIRST_JOIN_DATE     as MEMBER_FIRST_JOIN_DATE,
    m.FIRST_CAMPAIGN      as MEMBER_FIRST_CAMPAIGN,
    m.JOIN_PATH_CD        as JOIN_PATH_CD,            -- MM014 코드 raw
    m.ENROLL_PATH_NAME    as MEMBER_ENROLL_PATH_NAME, -- MM014 분석 라벨
    m.FIRST_SPONSORSHIP   as MEMBER_FIRST_SPONSORSHIP,
    m.LAST_STOP_DATE      as MEMBER_LAST_STOP_DATE,   -- [O27] as-of 최종중단일(그 시점까지)
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       as CAMPAIGN_TYPE,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME,
    s.SPONSORSHIP_ABBR    as SPONSORSHIP_ABBR,
    -- [2026-08-19 O89] 후원사업 분류 3계층 라벨. ⚠️ 이 뷰의 SPONSORSHIP_SK 는 O8 미회신으로 전건 센티넬(0)
    --   이므로 이 두 라벨도 '(미매핑)' 이다 — 실제 분류 분석은 WIDE_MEMBER_FEE·WIDE_MEMBER_EVENT 를 쓸 것.
    s.SPONSORSHIP_DIV_NAME   as SPONSORSHIP_DIV_NAME,
    s.SPONSORSHIP_GROUP_NAME as SPONSORSHIP_GROUP_NAME,
    p.PAYMENT_METHOD      as PAYMENT_METHOD,
    p.SETTLE_METHOD       as PAYMENT_SETTLE_METHOD,
    p.FEE_TYPE            as PAYMENT_FEE_TYPE,
    r.REASON_CODE         as REASON_CODE,
    r.REASON_NAME         as REASON_NAME,
    r.REASON_TYPE         as REASON_TYPE
from GN_DW.GOLD.FACT_MEMBER_MONTHLY f
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, PREV_MBER_STAT_CD, PREV_MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME, JOIN_PATH_CD, ENROLL_PATH_NAME,
           FIRST_JOIN_DATE, FIRST_CAMPAIGN, FIRST_SPONSORSHIP, LAST_STOP_DATE
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_CAMPAIGN     c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP  s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_PAYMENT      p on f.PAYMENT_SK     = p.PAYMENT_SK
left join GN_DW.GOLD.DIM_REASON       r on f.REASON_SK      = r.REASON_SK
    );
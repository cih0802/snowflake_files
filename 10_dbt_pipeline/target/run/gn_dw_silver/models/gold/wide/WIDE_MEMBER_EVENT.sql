create or replace view GN_DW.GOLD.WIDE_MEMBER_EVENT
    (
      DATE_SK COMMENT $$사건일 YYYYMMDD$$,
      MEMBER_DK COMMENT $$상태전이 대상 회원 (불변키)$$,
      EVENT_TYPE COMMENT $$상태전이 유형(개발/중단/증액/미납중단)$$,
      DVLP_DIV_CD COMMENT $$FACT_MEMBER_EVENT.DVLP_DIV_CD — 개발구분 코드 raw. 코드그룹 **MM015(개발구분)**. 코드사전 = 1신규·2증액·3감액·4재후원·5후원중단. 실적재(TM_MM_FDRM_MBER_DVLP_AMT.DVLP_DIV_CD)에 **사전 전종이 등장**한다. 🔴MM015 는 회원상태 MM010 이 **아니다** — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다(회원상태는 MBER_STAT_CD). ⚠️중단원천(EVENT_TYPE='STOP') 행은 원천에 이 컬럼이 부재해 NULL 이다. 라벨 = DVLP_DIV_NM.$$,
      DVLP_DIV_NM COMMENT $$FACT_MEMBER_EVENT.DVLP_DIV_NM — 개발구분명(MM015 라벨): 신규·증액·감액·재후원·후원중단. 코드 = DVLP_DIV_CD. MM015 는 폐지코드가 없고 실적재가 사전과 일치한다. 🔴🔴값 '후원중단' 은 EVENT_TYPE='STOP' 과 **동일 사건이 거의 전부 중복 존재**한다(동일 회원·일자) — 두 축을 합산하면 이중계상이다(O24 · 현업확인 대기).$$,
      SPNSR_AMT COMMENT $$FACT_MEMBER_EVENT.SPNSR_AMT — 후원금액(원) raw. 원천 TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT 무변환 전파. 🔴감액·후원중단 사건은 **음수**다 — 무조건 SUM 하면 개발금액이 상계된다. 🔴정본 공#38 감액(건)·#151 증액(건)이 **금액을 만원 단위로 나눈 값**이라는 규약이므로 원금액을 보존한다(설계 §1·CONF-2) — 이 컬럼을 그대로 '건수'로 쓰지 말 것. ⚠️중단원천 행은 NULL.$$,
      DEV_CNT COMMENT $$개발(건) (#149)$$,
      DEV_MEMBERS COMMENT $$개발(명) (#148)$$,
      STOP_CNT COMMENT $$중단(건) (#35)$$,
      STOP_MEMBERS COMMENT $$중단(명)$$,
      UNPAID_STOP_CNT COMMENT $$미납중단(건)$$,
      UNPAID_STOP_MEMBERS COMMENT $$미납중단(명)$$,
      JOIN_DATE COMMENT $$가입일$$,
      STOP_DATE COMMENT $$중단일$$,
      STOP_REASON COMMENT $$중단사유$$,
      STOP_CHANNEL COMMENT $$중단채널$$,
      STOP_REASON_NM COMMENT $$FACT_MEMBER_EVENT.STOP_REASON_NM — 중단사유명(정본 공#162). 코드그룹 **MM005(후원중단사유)**. 코드 = STOP_REASON. 코드사전에는 **폐지코드(USE_YN='N')가 다수 섞여** 있고 실적재는 사전의 일부만 쓴다. 최빈 코드 = 1개인(경제적)사유 · 14장기미납 · 16신규미납 · 8다른곳지원. 🔴🔴**USE_YN 필터 금지** — 실적재에 **폐지코드가 실재**한다(26은행자동납부해지 · 13반송미납 · 21~25 지라니 계열) ⇒ USE_YN='Y' 로 걸면 그 행들의 라벨이 사라진다. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️사전에만 있고 실적재에 없는 코드도 다수다.$$,
      STOP_CHANNEL_NM COMMENT $$FACT_MEMBER_EVENT.STOP_CHANNEL_NM — 중단경로명. 코드그룹 **MM287(중단경로)**. 코드 = STOP_CHANNEL. 코드사전 = 1 SYSTEM · 2 CRM · 3 홈페이지 · 실적재에 **사전 전종이 등장**한다. ⚠️'SYSTEM' 은 배치가 자동 처리한 중단(장기미납 등)이며 회원의 능동적 해지 채널이 아니다 — 채널 분석 시 분리할 것. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️215지표 밖 — 현업 수요 확인 대상(O25).$$,
      NEW_EXISTING_FLAG COMMENT $$신규기존 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_EVENT.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      AGE_AT_EVENT COMMENT $$FACT_MEMBER_EVENT.AGE_AT_EVENT — 연령대 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM014**. 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 사건행별 값을 무변환 전파한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지(1'10대 미만'~9'70대 이상'·10단체·11기업·12기타). 🔴MEMBER_AGE_CD(=현재버전 경유 '최근 약정' 스냅샷)와 **다른 축**이며 같은 회원도 사건마다 값이 다를 수 있다 — 이 컬럼이 그 사건 당시의 정확값이다. ⚠️중단원천 행은 원천 컬럼 부재로 NULL(0 아님, P21). 라벨 = AGE_BAND_AT_EVENT.$$,
      AGE_BAND_AT_EVENT COMMENT $$FACT_MEMBER_EVENT.AGE_BAND_AT_EVENT — **사건 시점** 연령대명(CM014 사전 조인, 하드코딩 아님 P31). 코드 = AGE_AT_EVENT. ✅'10대 미만'이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 🔴MEMBER_AGE_BAND(현재버전 스냅샷)와 값이 다를 수 있다. 중단원천 행은 NULL.$$,
      AREA_CD_AT_EVENT COMMENT $$FACT_MEMBER_EVENT.AREA_CD_AT_EVENT — 지역 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM018**(지표 공#131). 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD` 무변환 전파 · 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. 🔴MEMBER_AREA_CD(현재버전 경유 최근 약정 스냅샷)와 **다른 축** — 이사 등으로 사건마다 값이 다를 수 있다. ⚠️**현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가(O34). ⚠️중단원천 행은 원천 컬럼 부재로 NULL. 라벨 = REGION_AT_EVENT.$$,
      REGION_AT_EVENT COMMENT $$FACT_MEMBER_EVENT.REGION_AT_EVENT — **사건 시점** 지역명(CM018 약칭 라벨, 지표 공#131). 코드 = AREA_CD_AT_EVENT. ⚠️센티넬 코드 '0' 은 사전에 라벨이 없어 NULL 이다 — '미상'으로 창작하지 않는다. ⚠️**현재 거주지가 아니다**(O34). 🔴MEMBER_REGION(현재버전 스냅샷)과 값이 다를 수 있다. 중단원천 행은 NULL. 🟢이 뷰 안에 캠페인 축이 함께 있어 지역 × 캠페인 교차가 성립한다.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실제 일자$$,
      YEAR COMMENT $$DIM_DATE.YEAR — 년$$,
      MONTH COMMENT $$DIM_DATE.MONTH — 월$$,
      DAY_OF_WEEK COMMENT $$DIM_DATE.DAY_OF_WEEK — 요일$$,
      WEEK_OF_YEAR COMMENT $$DIM_DATE.WEEK_OF_YEAR — 주차$$,
      QUARTER COMMENT $$DIM_DATE.QUARTER — 분기$$,
      IS_HOLIDAY COMMENT $$DIM_DATE.IS_HOLIDAY — 휴일여부$$,
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
      JOIN_PATH_CD COMMENT $$DIM_MEMBER.JOIN_PATH_CD — 가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. 코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** ⇒ 가입경로 분포에서 이 두 값을 기대하지 말 것. 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = MEMBER_ENROLL_PATH_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_ENROLL_PATH_NAME COMMENT $$DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)$$,
      CAMPAIGN_PARENT COMMENT $$DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)$$,
      CAMPAIGN_PROMO_METHOD COMMENT $$DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)$$,
      CAMPAIGN_CATEGORY COMMENT $$캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. ⚠️ 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 코드사전 미등재 코드가 실재해 그 행은 라벨이 비고, 미채움 행도 있다(규모는 이슈원장 참조). ⚠️ **사전 자체에 동일 라벨 중복**이 있어 라벨로 GROUP BY 하면 두 코드가 합쳐진다. ⚠️ 업무용어는 '카테고리'이고 상위캠페인은 CAMPAIGN_PARENT 다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_CTGR_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_INFLOW_PATH COMMENT $$개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. 🔴 이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다**(O37) — 모집 채널이다. 캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MBER_INFLOW_PATH_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_DOMESTIC_OVERSEAS COMMENT $$캠페인 국내/통합/해외 라벨. 코드그룹 **MM295**. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE1_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_BIZ_CASE_TYPE COMMENT $$캠페인 굿즈/기타/사례/사업 구분 라벨. 코드그룹 **MM296**. ⚠️ CAMPAIGN_DOMESTIC_OVERSEAS(유형1=국내/해외 축)와 다른 축이다 — 혼동 금지. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE2_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_MARKETING_CAMPAIGN COMMENT $$마케팅캠페인명 라벨(Q16 해소). 🔴 광고비 결합은 이 라벨이 아니라 MKTG_CAMPAIGN_SK(FK)를 쓴다 — 라벨로 결합하면 안 된다(O44/O45). 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_CMPGN_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_CMMN_BRND COMMENT $$공통브랜드 라벨. 코드그룹 **MM297**. ⚠️ 라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지한다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMMN_BRND_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_MKTG_UTM COMMENT $$UTM 라벨. 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. ⚠️ 원천 미등재 코드가 많아 라벨 채움이 낮다 — **결측이 아니라 미등재**다. 🔴 채움 비율은 규칙7 상 여기 적지 않는다(재적재마다 stale 이 된다) ⇒ 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_UTM_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_SPNSR_DIV_CD COMMENT $$세부캠페인 후원구분 원천코드. 코드그룹 **CM035**: 1=정기후원 · 2=일시후원. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_SPNSR_DIV_NM. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_SPNSR_DIV_NM COMMENT $$CAMPAIGN_SPNSR_DIV_CD 를 CM035 로 해소한 라벨(정기후원/일시후원). ⚠️ DIM_SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 **적용 대상이 다르다** — 이 컬럼은 세부캠페인 단위 구분이다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_CPR_DIV_CD COMMENT $$세부캠페인 법인구분 원천코드. 코드그룹 **CM019**: A=통합 · I=사단 · S=사복. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_CPR_DIV_NM. 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — ORG_CORP 는 전건 비어 있고 이 축은 채워진다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      CAMPAIGN_CPR_DIV_NM COMMENT $$CAMPAIGN_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — 「법인별」 질문은 어느 축인지 먼저 가린다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).$$,
      SPONSORSHIP_BK COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키$$,
      SPONSORSHIP_NAME COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)$$,
      SPONSORSHIP_DIV_NAME COMMENT $$[2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢DEV 브랜치는 O45 로 배선(3,594,843)이라 **분류별 개발실적 집계가 된다.** ⚠️STOP 브랜치는 `SPONSORSHIP_SK` 센티넬 0 이라 `'(미매핑)'` 이다 — 중단 분해는 개발원천 코드5 경로를 쓸 것(DEC-32 철회·O47). 🔴DEV·STOP 을 합산하면 이중계상이다(O24).$$,
      SPONSORSHIP_GROUP_NAME COMMENT $$[2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️STOP 브랜치 센티넬은 위 DIV_NAME 주석과 동일.$$,
      ORG_CORP COMMENT $$DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.$$,
      ORG_DIVISION COMMENT $$DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.$$,
      ORG_DEPARTMENT COMMENT $$DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 중단원천 행은 부서가 없다. 부서별 집계 시 이 그룹이 상위권 규모로 나타나며 **실재 부서가 아니다.** 실측 규모는 이슈원장 §O51-D-C.$$,
      ORG_TEAM COMMENT $$DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.$$,
      REASON_CODE COMMENT $$DIM_REASON.REASON_CODE — 사유코드$$,
      REASON_NAME COMMENT $$DIM_REASON.REASON_NAME — 중단/미납사유$$,
      REASON_TYPE COMMENT $$DIM_REASON.REASON_TYPE — 중단/미납 구분$$
    )
    comment = $$회원 이벤트 팩트(FME) 평탄화 — DATE·MEMBER[현재버전]·CAMPAIGN·SPONSORSHIP·ORG·REASON.$$
    as (
      -- WIDE_MEMBER_EVENT: 회원 이벤트 팩트(FME) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.2)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.DATE_SK, f.MEMBER_DK, f.EVENT_TYPE,
    -- [2026-08-03 O24] 개발구분 축 노출. 컬럼명은 BRONZE 원천명 그대로(현업 혼동 방지).
    --   ⚠️ DVLP_DIV_NM='후원중단' 과 EVENT_TYPE='STOP' 은 동일 사건 중복 → 합산 금지.
    f.DVLP_DIV_CD, f.DVLP_DIV_NM, f.SPNSR_AMT,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.STOP_MEMBERS,
    f.UNPAID_STOP_CNT, f.UNPAID_STOP_MEMBERS,
    f.JOIN_DATE, f.STOP_DATE, f.STOP_REASON, f.STOP_CHANNEL,
    -- [2026-08-03 O25] 중단사유·중단경로 라벨 노출. 종전엔 raw 코드(1/14/16 · 1/2/3)만 있어
    --   현업이 WIDE 를 조회하면 숫자만 보였다. 계보 계약(04_컬럼계보매핑 §4)이 STOP_REASON 을
    --   "사유코드→라벨"로 명시한 것과 실적재가 어긋난 상태를 해소한다(정본 공#162).
    f.STOP_REASON_NM, f.STOP_CHANNEL_NM,
    f.NEW_EXISTING_FLAG,
    -- [2026-08-04 O35] 사건시점 연령대·지역. 아래 MEMBER_AGE_* / MEMBER_REGION(=DIM_MEMBER 현재버전
    --   경유 '최근 약정' 스냅샷)과 **다른 축**이며 값이 다를 수 있다. 이 축이 사건 당시 정확값이다.
    --   같은 뷰 안에 캠페인 축이 있어 연령대 × 캠페인 교차가 성립한다. 중단(STOP)행은 원천 부재로 NULL.
    f.AGE_AT_EVENT, f.AGE_BAND_AT_EVENT, f.AREA_CD_AT_EVENT, f.REGION_AT_EVENT,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.QUARTER, d.IS_HOLIDAY,
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
    m.JOIN_PATH_CD        as JOIN_PATH_CD,            -- MM014 코드 raw
    m.ENROLL_PATH_NAME    as MEMBER_ENROLL_PATH_NAME, -- MM014 분석 라벨
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    -- [2026-07-30 D2] 캠페인 분석 2축 노출. DIM_CAMPAIGN 컬럼명↔업무용어 매핑에 주의:
    --   CAMPAIGN_TYPE(MM294 CMPGN_CTGR_NM) = 캠페인'카테고리'  → CAMPAIGN_CATEGORY 로 노출
    --   INFLOW_PATH(MM293 MBER_INFLOW_PATH_NM) = 현업 '주요캠페인' → CAMPAIGN_INFLOW_PATH 로 노출
    -- 🔴🔴 [2026-08-28 O105] **소스 축 전환 — DIM_CAMPAIGN 실시간 조인 → FME 적재시점 동결값.**
    --   왜: 같은 9속성을 SV_MEMBER_EVENT 는 이미 `fme.*_AT_EVENT`(동결값)로 쓰는데(2026-08-25 설계부채
    --   해소 · DEC-43 축) 이 뷰만 `c.*` 실시간 조인으로 남아 **같은 이름의 축이 두 표면에서 다른 값이
    --   될 수 있었다**(Streamlit=WIDE ↔ Cowork=SV). 전환 시점 실측으로 두 소스의 값은 전건 동일했다
    --   (불일치 0 / DEV 3,594,843 · CAMPAIGN_SK PK 조인) ⇒ **지금 바꾸면 값 변화가 없고**, 캠페인
    --   마스터가 정정된 뒤에 바꾸면 과거 리포트가 조용히 달라진다. 규모·근거 = 이슈원장 §O105.
    --   🔴 **컬럼명은 바꾸지 않았다**(`CAMPAIGN_*` 유지) — 소비측(Streamlit·산출물) 파괴를 피하기 위한
    --   의도적 선택이며 SV 가 친화명을 유지한 것과 같은 판단이다. 의미는 「사건 시점 캠페인 속성」이다.
    --   🟢 **NULL 의 의미는 바뀌지 않는다**(전환 前 라이브 실측으로 확인) — 중단(STOP) 행에서 이 9축은
    --   **전환 전에도 이미 전건 NULL** 이었고 `'(미매핑)'` 은 0건이었다. `DIM_CAMPAIGN` 의 SK=0 시드가
    --   **이름 컬럼(CAMPAIGN_NAME)만** `'(미매핑)'` 으로 채우고 속성 컬럼은 NULL 로 두기 때문이다
    --   (`R2-7-3` = 식별 컬럼 `(미매핑)` / 속성 컬럼 NULL). ⚠️ 초판 주석은 *「NULL 의 뜻이 바뀐다」*
    --   고 적었는데 **실측 반증으로 철회**했다 — 규모·경위는 이슈원장 §O105. STOP 행 NULL 은
    --   「개발원천에 그 컬럼이 없다」는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`).
    --   🟢 캠페인 자체 속성(BK·BRAND·PARENT·NAME·PROMO_METHOD)은 캠페인 차원에 남긴다(SV 와 동일 경계).
    f.CMPGN_CTGR_NM_AT_EVENT        as CAMPAIGN_CATEGORY,
    f.MBER_INFLOW_PATH_NM_AT_EVENT  as CAMPAIGN_INFLOW_PATH,
    -- [2026-08-25 안내1 후속] 회원 개발이력 비정규화 요건 잔여 5축.
    f.CMPGN_TYPE1_NM_AT_EVENT       as CAMPAIGN_DOMESTIC_OVERSEAS,   -- MM295 국내/통합/해외
    f.CMPGN_TYPE2_NM_AT_EVENT       as CAMPAIGN_BIZ_CASE_TYPE,       -- MM296 굿즈/기타/사례/사업
    f.MKTG_CMPGN_NM_AT_EVENT        as CAMPAIGN_MARKETING_CAMPAIGN,  -- Q16 마케팅캠페인명
    f.CMMN_BRND_NM_AT_EVENT         as CAMPAIGN_CMMN_BRND,           -- MM297 공통브랜드 라벨
    f.MKTG_UTM_NM_AT_EVENT          as CAMPAIGN_MKTG_UTM,            -- TM_CM_MKTNG_UTM 라벨
    -- [2026-08-25 안내2] 세부캠페인 후원구분·법인구분. WIDE 는 현업 가독성이 원칙이라(DIM/FACT 는
    --   개발자·AI 추적성) 다른 캠페인 축들 바로 옆에 코드+라벨을 나란히 둔다 — ALTER ADD COLUMN 규약은
    --   물리 테이블(DIM/FACT)에만 적용되고 뷰(WIDE)는 CREATE OR REPLACE 라 매번 전체 재정의되므로
    --   물리 ordinal 제약이 없다. 그래서 뷰에서는 의미 순서로 자유롭게 재배치해도 안전하다.
    f.SPNSR_DIV_CD_AT_EVENT         as CAMPAIGN_SPNSR_DIV_CD,   -- CM035 1=정기후원·2=일시후원
    f.SPNSR_DIV_NM_AT_EVENT         as CAMPAIGN_SPNSR_DIV_NM,
    f.CPR_DIV_CD_AT_EVENT           as CAMPAIGN_CPR_DIV_CD,     -- CM019 A=통합·I=사단·S=사복
    f.CPR_DIV_NM_AT_EVENT           as CAMPAIGN_CPR_DIV_NM,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME,
    -- [2026-08-19 O89] 후원사업 분류 3계층 라벨(정기일시 → 약칭 → 사업명).
    --   🟢 DEV 브랜치는 O45 로 배선(3,594,843) — 분류별 개발실적 집계 경로.
    --   ⚠️ STOP 브랜치는 SPONSORSHIP_SK 센티넬 0 이라 라벨도 '(미매핑)' 이다(DEC-32 철회 근거·O47).
    --   🔴🔴 GROUP_NAME 단독으로 「해외」를 세지 말 것 — 해외구호(3)와 해외(6)가 갈라진다. (DIV, GROUP) 쌍으로 볼 것.
    s.SPONSORSHIP_DIV_NAME   as SPONSORSHIP_DIV_NAME,
    s.SPONSORSHIP_GROUP_NAME as SPONSORSHIP_GROUP_NAME,
    o.CORP                as ORG_CORP,
    o.DIVISION            as ORG_DIVISION,
    o.DEPARTMENT          as ORG_DEPARTMENT,
    o.TEAM                as ORG_TEAM,
    r.REASON_CODE         as REASON_CODE,
    r.REASON_NAME         as REASON_NAME,
    r.REASON_TYPE         as REASON_TYPE
from GN_DW.GOLD.FACT_MEMBER_EVENT f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, PREV_MBER_STAT_CD, PREV_MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME, JOIN_PATH_CD, ENROLL_PATH_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_ORG         o on f.ORG_SK         = o.ORG_SK
left join GN_DW.GOLD.DIM_REASON      r on f.REASON_SK      = r.REASON_SK
    );
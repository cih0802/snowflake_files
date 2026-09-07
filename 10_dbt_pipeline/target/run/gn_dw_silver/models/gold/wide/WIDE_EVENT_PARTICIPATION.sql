create or replace view GN_DW.GOLD.WIDE_EVENT_PARTICIPATION
    (
      DATE_SK COMMENT $$참여일 YYYYMMDD$$,
      MEMBER_DK COMMENT $$참여 회원 (불변키)$$,
      TOTAL_CNT COMMENT $$총인원$$,
      WAIT_CNT COMMENT $$대기인원$$,
      CANCEL_CNT COMMENT $$취소인원$$,
      CONFIRM_CNT COMMENT $$신청확정인원$$,
      PARTICIPATE_CNT COMMENT $$참여인원$$,
      ABSENT_CNT COMMENT $$불참인원$$,
      PARTICIPANT_CNT COMMENT $$참여자수$$,
      PARTICIPATION_TIMES COMMENT $$참여횟수$$,
      WAIT_TIMES COMMENT $$대기횟수$$,
      ABSENT_TIMES COMMENT $$불참횟수$$,
      CUM_APPLY_TIMES COMMENT $$누적신청횟수$$,
      REGULAR_DONATION COMMENT $$정기후원금(원)$$,
      WIN_FLAG COMMENT $$당첨여부$$,
      SELF_PART_FLAG COMMENT $$본인참여여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_EVENT_PARTICIPATION.SELF_PART_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      PART_STATUS COMMENT $$참여상태$$,
      PART_PATH COMMENT $$참여경로$$,
      PART_CHANNEL COMMENT $$참여채널$$,
      PART_STATUS_GROUP COMMENT $$참여상태 코드군 ID (조인키 · 일반행사→MS304 · 캠페인행사→MS006). 🔴O28 다체계의 **구조적 해소축**이다 — `PART_STATUS` 단독 필터·GROUP BY 는 두 체계를 섞는다(판별자 = 이 컬럼 또는 `EVENT_KIND`). 🔴두 원천의 「참여」 정의 자체가 다르므로 합산 금지$$,
      PART_STATUS_NAME COMMENT $$참여상태 라벨 (CRM_CODE 조인). ⚠️일반행사(MS304) 라벨은 코드사전에 **영문**으로 등록돼 있다(Success·N_step_right 계열) — 현업 한글 표기 회신 대기(문서20 §M-1)이며 우리가 창작하지 않았다. 미등재·오염 코드는 NULL$$,
      PART_PATH_GROUP COMMENT $$참여경로 코드군 ID (조인키 · 일반행사→MS303 · 캠페인행사→MS004=신청경로). 🟢운영서버 코드사전 대조로 확정(2026-08-11)$$,
      PART_PATH_NAME COMMENT $$참여경로 라벨 (CRM_CODE 조인 · 코드군 확정). 미등재·오염 코드는 NULL 유지$$,
      PART_CHANNEL_GROUP COMMENT $$참여채널 코드군 ID (조인키 · 일반행사→MS302). 캠페인행사는 원천에 채널 축이 없어 NULL(구조적 부재 · P21)$$,
      PART_CHANNEL_NAME COMMENT $$참여채널 라벨 (CRM_CODE 조인). 미등재·오염 코드는 NULL 유지$$,
      PART_EVENT_BK COMMENT $$FACT_EVENT_PARTICIPATION.EVENT_BK — degenerate key: **팩트가 보유한 원천 행사키**(전건 채움). 🔴같은 뷰의 EVENT_BK(=DIM_EVENT 매칭분)와 **다르다** — 행사 마스터가 없는 **고아 행사**가 EVENT_SK=0 으로 뭉개져 서로 구별되지 않으므로 이 컬럼으로 식별을 보존한다. 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 **PART_EVENT_BK 는 원천값을 그대로 갖는다.** 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 PART_EVENT_BK 는 원천값을 그대로 갖는다. 🔷행 유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ). ⚠️접두(EVENT_/CRMN_)가 원천 코드체계 판별자(O28).$$,
      PARTCPT_SEQ COMMENT $$FACT_EVENT_PARTICIPATION.PARTCPT_SEQ — degenerate key: 참여 일련번호 ← `BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL.PARTCPT_SEQ`. 🔷(PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ) 가 행을 유일 식별한다 — **(행사,회원)만으로는 중복**이다. 🔴**전역 순번이 아니다**((행사,SEQ) 조합도 유일하지 않다) · **음수·INT_MIN 값이 존재**한다 ⇒ **식별자 전용**이며 정렬·범위조건·MAX 로 '참여 횟수'를 세지 말 것.$$,
      PART_EVENT_KIND COMMENT $$FACT_EVENT_PARTICIPATION.EVENT_KIND — **팩트가 보유한 원천 계열 판별 코드**(전건 채움 · 값 EVENT/CRMN). 🔴같은 뷰의 EVENT_KIND(=DIM_EVENT 유래)와 **다르다** — 차원축은 행사 마스터 미매칭 구간이 '(미매핑)' 이라 계열을 알려주지 못한다. ⇒ **계열 분해·O28 다체계 판별은 이 컬럼**으로 한다. 라벨은 PART_EVENT_KIND_NAME.$$,
      PART_EVENT_KIND_NAME COMMENT $$FACT_EVENT_PARTICIPATION.EVENT_KIND_NAME — **팩트가 보유한 원천 계열 판별 라벨**(전건 채움 · 값 일반행사/캠페인행사). 🔴차원 유래 EVENT_KIND_NAME 과 달리 **(미매핑) 사각지대가 없다.** 🔴원천 계열을 뜻하며 온·오프라인 구분이 아니다. ⚠️파생 라벨이므로 코드사전 조인 대상이 아니다.$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실제 일자$$,
      YEAR COMMENT $$DIM_DATE.YEAR — 년$$,
      MONTH COMMENT $$DIM_DATE.MONTH — 월$$,
      DAY_OF_WEEK COMMENT $$DIM_DATE.DAY_OF_WEEK — 요일$$,
      WEEK_OF_YEAR COMMENT $$DIM_DATE.WEEK_OF_YEAR — 주차$$,
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
      MBER_DIV_CD COMMENT $$DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_TYPE_NAME COMMENT $$DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      EVENT_BK COMMENT $$DIM_EVENT.EVENT_BK — 행사 업무키 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 행사 마스터 없는 고아 행사가 한 그룹으로 뭉친다. 행사 식별은 `PART_EVENT_BK` 를 쓴다. 실측 규모는 이슈원장 §O51-D-C.$$,
      EVENT_KIND COMMENT $$DIM_EVENT.EVENT_KIND — 🔴[O59-P 정정] 종전 설명 「온라인/오프라인」은 **거짓이었다**. 실제 값은 `EVENT`(일반행사) · `CRMN`(캠페인행사) = **원천 판별자**다(온·오프라인 구분은 `EVENT_CATEGORY` 소관). 🔴이 컬럼이 O28 다체계의 판별자다 — 참여상태·경로를 이 축 없이 합산하면 정의가 다른 두 체계를 섞는다. 라벨축 = `EVENT_KIND_NAME`$$,
      EVENT_KIND_NAME COMMENT $$DIM_EVENT.EVENT_KIND_NAME — 행사종류 라벨(일반행사/캠페인행사). ⚠️판별자 라벨은 코드사전에 존재할 수 없어 `CASE` 로 만든다(DEC-35 §23-B 헛점4 의 명문 예외 · 미등재 값은 NULL 로 떨어져 warn 이 잡는다)$$,
      EVENT_CATEGORY COMMENT $$DIM_EVENT.EVENT_CATEGORY — 행사구분 코드 raw. 🔴원천별 2체계다: 일반행사=100~500(MS286) · 캠페인행사=1~16(MS002) ⇒ **코드 단독 GROUP BY 금지**(판별자 = `EVENT_KIND` 또는 `EVENT_CATEGORY_GROUP`)$$,
      EVENT_CATEGORY_GROUP COMMENT $$행사구분 코드군 ID (조인키 · 일반행사→MS286 · 캠페인행사→MS002). 두 체계는 코드값이 겹치지 않으나 **의미가 다르므로 합산하지 말 것**$$,
      EVENT_CATEGORY_NAME COMMENT $$행사구분 라벨 (CRM_CODE 조인). ⚠️센티넬 행('(미매핑)')은 라벨이 NULL 이다 — 코드가 없으므로 조인 대상이 아니다$$,
      EVENT_NAME COMMENT $$DIM_EVENT.EVENT_NAME — 행사명 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 고아 행사들이 한 이름으로 합쳐진다. 실측 규모는 이슈원장 §O51-D-C.$$,
      EVENT_START_DATE COMMENT $$DIM_EVENT.EVENT_START_DATE — 행사기간 시작$$,
      EVENT_END_DATE COMMENT $$DIM_EVENT.EVENT_END_DATE — 행사기간 종료$$,
      EVENT_APPLY_CHANNEL COMMENT $$DIM_EVENT.APPLY_CHANNEL — 신청경로 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_EVENT.APPLY_CHANNEL`. 행사 신청채널은 원천 행사 마스터에 값이 없다 ⇒ **신청채널 분석은 불가**하다. 실측 규모는 이슈원장 §O51-D-C.$$,
      EVENT_RECRUIT_HEADCOUNT COMMENT $$DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원) ← `SILVER CRM_EVENT.RCRIT_PSNNL_CO`. 일부 행사는 정원이 없다. 🔴🔴**행사 grain 속성이므로 참여행에서 SUM 금지** — 참여행마다 반복되어 **두 자리 배수로 과대계상**된다(실측 배율은 이슈원장 §O51-D-C). 정원 대비 참여율은 행사 단위로 집계한 뒤 나눌 것. 🔧[DEC-30] 종전 팩트의 RECRUIT_CNT 를 제거하고 이 행사 차원 값으로 대체했다.$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_PARTICIPATION.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_EVENT_PARTICIPATION.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_PARTICIPATION.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSORSHIP_BK COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_PARTICIPATION.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      SPONSORSHIP_NAME COMMENT $$DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_PARTICIPATION.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$
    )
    comment = $$행사 참여 팩트(FEP) 평탄화 — DATE·MEMBER[현재버전]·EVENT·CAMPAIGN·SPONSORSHIP.$$
    as (
      -- WIDE_EVENT_PARTICIPATION: 행사 참여 팩트(FEP) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.8)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
    f.DATE_SK, f.MEMBER_DK,
    -- [DEC-30] f.RECRUIT_CNT 제거 → e.RECRUIT_HEADCOUNT(행사 차원)으로 대체
    f.TOTAL_CNT, f.WAIT_CNT, f.CANCEL_CNT,
    f.CONFIRM_CNT, f.PARTICIPATE_CNT, f.ABSENT_CNT,
    f.PARTICIPANT_CNT, f.PARTICIPATION_TIMES,
    f.WAIT_TIMES, f.ABSENT_TIMES, f.CUM_APPLY_TIMES,
    f.REGULAR_DONATION,
    f.WIN_FLAG, f.SELF_PART_FLAG, f.PART_STATUS,
    f.PART_PATH, f.PART_CHANNEL,
    -- 🔴 [2026-09-01 O130] f.INCREASE_FLAG 드랍(O96 §7-B A군 집행) — 컬럼 제거.
    -- [2026-08-11 O59-P · DEC-35 3단계] 코드+라벨 병기를 **WIDE 층까지 전파**한다(DEC-25 15-D).
    --   🔴 O59-N 이 GOLD 에 라벨을 붙였는데 WIDE 는 코드축만 노출하고 있었다 — 소비계층이 라벨을 못 본다.
    --   🔴 PART_STATUS 는 원천 2체계가 한 컬럼에 있다(O28): EVENT=MS304(단계 통과) · CRMN=MS006(신청/참여).
    --      **두 원천의 「참여」 정의가 다르므로 코드 단독 합산·GROUP BY 금지** — 판별자 = *_GROUP 또는 EVENT_KIND.
    --   ⚠️ 라벨 NULL 6행은 O28 오염값이다(라벨을 붙이지 않는다 · 정본 = 원장 §O59-O ③).
    f.PART_STATUS_GROUP, f.PART_STATUS_NAME,
    f.PART_PATH_GROUP, f.PART_PATH_NAME,
    f.PART_CHANNEL_GROUP, f.PART_CHANNEL_NAME,
    -- [DEC-30] degen key 2종. 🔷유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ).
    --   ⚠️PART_EVENT_BK(팩트·고아 포함 전건) 와 EVENT_BK(차원 매칭·고아는 '(미매핑)') 는 다르다.
    f.EVENT_BK            as PART_EVENT_BK,
    f.PARTCPT_SEQ         as PARTCPT_SEQ,
    -- [2026-08-12 O61 · D2] 🔴 **팩트가 자체 보유한 계열 판별자**를 WIDE 까지 전파한다(P204).
    --   아래 e.EVENT_KIND(_NAME) 은 **차원**에서 오므로 행사 미매칭 구간이 '(미매핑)' 이고 계열을 못 가른다.
    --   이 두 컬럼은 원천 분기에서 와 전건 값을 가진다 ⇒ **계열 분해는 이 축(PART_*)으로 한다.**
    f.EVENT_KIND          as PART_EVENT_KIND,
    f.EVENT_KIND_NAME     as PART_EVENT_KIND_NAME,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
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
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    e.EVENT_BK            as EVENT_BK,
    e.EVENT_KIND          as EVENT_KIND,
    -- [O59-P · DEC-35 R1] 🔴 판별자 라벨축이 WIDE 에 없었다 — O58-C 와 같은 유형(라벨이 옆에 있는데 코드축만 노출).
    e.EVENT_KIND_NAME     as EVENT_KIND_NAME,
    e.EVENT_CATEGORY      as EVENT_CATEGORY,
    e.EVENT_CATEGORY_GROUP as EVENT_CATEGORY_GROUP,
    e.EVENT_CATEGORY_NAME  as EVENT_CATEGORY_NAME,
    e.EVENT_NAME          as EVENT_NAME,
    e.EVENT_START_DATE    as EVENT_START_DATE,
    e.EVENT_END_DATE      as EVENT_END_DATE,
    e.APPLY_CHANNEL       as EVENT_APPLY_CHANNEL,
    e.RECRUIT_HEADCOUNT   as EVENT_RECRUIT_HEADCOUNT,  -- [DEC-30] 행사 정원(행사 grain) — 참여행 반복 합산 금지
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_EVENT       e on f.EVENT_SK       = e.EVENT_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
    );
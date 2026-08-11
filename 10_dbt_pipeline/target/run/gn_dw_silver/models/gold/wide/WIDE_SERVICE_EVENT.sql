create or replace view GN_DW.GOLD.WIDE_SERVICE_EVENT
    (
      DATE_SK COMMENT $$발송일 YYYYMMDD$$,
      MEMBER_DK COMMENT $$발송 대상 회원 (불변키)$$,
      SEND_MEMBERS COMMENT $$발송수(명) (#85)$$,
      SUCCESS_MEMBERS COMMENT $$성공수(명) (#86)$$,
      FAIL_MEMBERS COMMENT $$실패수(명) (#87)$$,
      OPEN_MEMBERS COMMENT $$오픈(명) (overview)$$,
      LETTER_PART_MEMBERS COMMENT $$서신참여(명) (#88)$$,
      LETTER_PART_CNT COMMENT $$서신참여(건) (#89)$$,
      GIFT_PART_MEMBERS COMMENT $$선물금참여(명) (#90)$$,
      GIFT_PART_AMT COMMENT $$선물금참여(원) (#91)$$,
      D5_LETTER_PART_MEMBERS COMMENT $$+5일차 서신참여(명) (#139)$$,
      D5_LETTER_PART_CNT COMMENT $$+5일차 서신참여(건) (#140)$$,
      D5_GIFT_PART_MEMBERS COMMENT $$+5일차 선물금참여(명) (#141)$$,
      D5_GIFT_PART_CNT COMMENT $$+5일차 선물금참여(건) (#142)$$,
      D5_INCREASE_PART_MEMBERS COMMENT $$+5일차 증액참여(명) (#143)$$,
      D5_INCREASE_PART_CNT COMMENT $$+5일차 증액참여(건) (#144)$$,
      D5_STOP_MEMBERS COMMENT $$+5일차 중단(명) (#145)$$,
      D5_STOP_CNT COMMENT $$+5일차 중단(건) (#146)$$,
      SERVICE_MEMBERS COMMENT $$서비스(명) (#160)$$,
      SERVICE_CNT COMMENT $$서비스(건) (#161)$$,
      SEND_TITLE COMMENT $$제목 (#136)$$,
      SEND_STATUS COMMENT $$발송상태 (#138)$$,
      SEND_STATUS2 COMMENT $$발송상태2 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_SERVICE_EVENT.SEND_STATUS2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `SEND_STATUS`(대부분 채워져 있다).$$,
      SEND_TYPE COMMENT $$발송유형$$,
      SEND_STATUS_GROUP COMMENT $$축A(채널상태) 코드군 ID (조인키 · MSG_AT→MS282). 🔴`SEND_STATUS` 는 채널별로 다른 코드체계가 한 컬럼에 모여 있다 — **`SEND_TYPE` 또는 이 컬럼 동반 필수**(단독 필터는 채널 간 오조인). EMAIL·SND·PSTMTR 은 NULL$$,
      SEND_STATUS_NAME COMMENT $$축A 라벨 (CRM_CODE 조인). 🔴EMAIL·SND 는 **의도적 NULL** — 코드값은 있으나 코드사전에 라벨 문자열이 없어 조인으로 얻을 수 없고 의미 해석을 라벨로 넣는 것은 창작이다(문서30 §23-J 결정 3 · 현업 문서20 §M-4). PSTMTR 은 원천 컬럼 부재$$,
      SEND_RESULT_CD COMMENT $$축B(통신사 결과) 코드 raw — MSG_AT 은 전송실패코드 · SND 는 통화상태. 🟢**conformed 축**이다: 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 체계가 유지된다. 원천에 값이 없는 채널은 NULL$$,
      SEND_RESULT_GROUP COMMENT $$축B 코드군 ID — 코드사전 MS283 이 정의한 4종(공통·알림톡·SMS·MMS). 🟢리터럴 지정이 아니라 **조인 결과에서 얻는다**(4그룹에 걸쳐 코드값 중복이 없어 값 자체가 그룹을 결정한다)$$,
      SEND_RESULT_NAME COMMENT $$축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + dbt warn 관측(DEC-17-B · 센티넬 창작 금지) — 미매칭 규모는 이슈원장 §O59-N·문서20 §M-5$$,
      MAIL_RECEIVE_FLAG COMMENT $$메일수신여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_SERVICE_EVENT.MAIL_RECEIVE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
      MEMBER_STOP_FLAG COMMENT $$결연회원 중단여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_SERVICE_EVENT.MEMBER_STOP_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.$$,
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
      MEMBER_REGION COMMENT $$DIM_MEMBER.REGION — 지역 (#131)$$,
      MEMBER_AGE_CD COMMENT $$DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_AGE_BAND COMMENT $$DIM_MEMBER.AGE_BAND — 연령대$$,
      MBER_STAT_CD COMMENT $$DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. 코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · `TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). 🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_STATUS_NAME COMMENT $$DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 미매핑은 '미상'. ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MBER_DIV_CD COMMENT $$DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. 코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. 🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. 🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      MEMBER_TYPE_NAME COMMENT $$DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 미매핑은 '미상'. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)$$,
      SEND_TYPE_L_CD COMMENT $$DIM_SEND_TYPE.SEND_GBN_TOP — 발송구분(대) 코드 raw. 🔴🔴**이 값은 상세코드가 아니라 CRM_CODE 의 코드그룹 ID(CD_ID) 자체다.** [O51-D 실측] `SND_REQ_MST.SEND_GBN_TOP` 실적재 값 = **MS046·MS047·MS048·MS049·MS050·MS0501·MS0505·MS051·MS052·MS053·MS054·MS055** 이며 **전부 `TC_CMMN_CD.CD_ID` 에 실재**한다. ⇒ 상세코드 사전(`TC_CMMN_DTL_CD`)에서 찾으면 나오지 않는다. 라벨 = SEND_TYPE_L.$$,
      SEND_TYPE_L COMMENT $$DIM_SEND_TYPE.SEND_TYPE_L — 발송구분(대) 분석 라벨(정본 공#133) ← SND_REQ_MST.SEND_GBN_TOP_NM. 코드 = SEND_TYPE_L_CD. [O51-D 실측] **여러 코드가 같은 라벨로 축약**된다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053. ⇒ 라벨로 GROUP BY 하면 코드가 합쳐진다(대분류는 코드그룹과 1:1 이 아니다). 🔴정본 공#133 과 **불일치**: #133 은 결연/회비/서비스/사업보고/참여/기타 만 열거하는데 실측 라벨에는 **회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053)이 더 있다.** #133 에 생략기호가 없어 완전열거로 읽히므로 불일치는 실재한다 → 현업 확인 대상, 데이터 우선 보존(DEC-26). ⚠️커버리지가 낮다 — 비매칭은 센티넬 '(미매핑)'(DEC-30). 규모는 이슈원장 §O51-D-C 참조. 🔴🔴[O51-D 실측] `'(미매핑)'` 이 **과반을 크게 넘는다** — 발송구분 대분류는 매칭되는 행이 소수다. 커버리지를 모르고 대분류별 비중을 내면 **결론이 뒤집힌다.** 실측 규모는 이슈원장 §O51-D-C.$$,
      SEND_TYPE_M_CD COMMENT $$DIM_SEND_TYPE.SEND_GBN_MID — 발송구분(중) 코드 raw ← SND_REQ_MST.SEND_GBN_MID. 🔴🔴**코드 단독 사용 금지 — 이 코드는 부모(대) 그룹 안에서만 유일하다.** [O51-D BRONZE 실측] 값 '01' 이 부모에 따라 '결제오류'·'모바일소식지(사단)'·'기타_사단'·'기부금영수증(사단)'·'기타' 등 서로 다른 뜻이며 실적재 (코드,라벨) 쌍 37종이 나온다. ⇒ 반드시 **(대,중) 쌍**으로 해석할 것. 라벨 = SEND_TYPE_M.$$,
      SEND_TYPE_M COMMENT $$DIM_SEND_TYPE.SEND_TYPE_M — 발송구분(중) 분석 라벨(정본 공#134) ← SND_REQ_MST.SEND_GBN_MID_NM. 코드 = SEND_TYPE_M_CD. 예: 결제오류·APR회원발송·ACL회원발송·만18세아동종결(종결예정)·후원참여·회원개발·아동답신(서신/선물금/회소카). 🔴같은 라벨이 여러 부모(대) 아래 반복되므로 라벨 단독 GROUP BY 는 대분류를 섞는다. ⚠️비매칭은 '(미매핑)'.$$,
      SEND_TYPE_S_CD COMMENT $$DIM_SEND_TYPE.SEND_GBN_BOT — 발송구분(소) 코드 raw ← SND_REQ_MST.SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴**코드 단독 모호** — [O51-D 실측] 같은 코드('0101'·'0401' 등)가 부모에 따라 다른 뜻이다. ⇒ **(대,중,소) 경로**로만 해석할 것. 라벨 = SEND_TYPE_S.$$,
      SEND_TYPE_S COMMENT $$DIM_SEND_TYPE.SEND_TYPE_S — 발송구분(소) 분석 라벨(정본 공#135) ← SND_REQ_MST.SEND_GBN_BOT_NM. 코드 = SEND_TYPE_S_CD. 예: APR발송예정안내·ACL발송예정안내·기존회원개발메일(사단)·겨울 소식지_사단·답신발송알림·자동이체결제오류(사단)·네이버페이(사단). 🔴라벨도 부모 경로 없이는 유일하지 않다(답신발송알림이 여러 중분류에 존재). ⚠️비매칭은 '(미매핑)'.$$,
      SERVICE_SUBTYPE COMMENT $$DIM_SERVICE.SUBTYPE — 발송/참여 subtype$$,
      SERVICE_CHANNEL COMMENT $$DIM_SERVICE.CHANNEL — CRM_UMS / ADMIN$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_SERVICE_EVENT.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_SERVICE_EVENT.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_PARENT COMMENT $$DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_SERVICE_EVENT.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_SERVICE_EVENT.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.$$,
      CAMPAIGN_PROMO_METHOD COMMENT $$DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_SERVICE_EVENT.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.$$
    )
    comment = $$서비스/발송 팩트(FSE) 평탄화 — DATE·MEMBER[현재버전]·SERVICE·CAMPAIGN.$$
    as (
      -- WIDE_SERVICE_EVENT: 서비스/발송 팩트(FSE) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.5)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.


select
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
    -- [2026-08-11 O59-P · DEC-35 3단계] 코드+라벨 병기를 **WIDE 층까지 전파**한다(DEC-25 15-D).
    --   🔴 O59-N 이 SILVER·GOLD 에 라벨을 붙였지만 WIDE 는 **코드축만** 노출하고 있었다 —
    --      소비계층(SV·Analyst·현업 직접조회)이 라벨을 볼 수 없으면 라벨을 만든 목적이 달성되지 않는다.
    --   축A(채널상태) = SEND_STATUS 옆에 코드군·라벨 / 축B(통신사 결과) = 3컬럼 세트 전량.
    --   ⚠️ SEND_STATUS 단독 필터는 채널 간 오조인이다 — SEND_TYPE 또는 SEND_STATUS_GROUP 동반 필수(§23-G).
    f.SEND_STATUS_GROUP, f.SEND_STATUS_NAME,
    f.SEND_RESULT_CD, f.SEND_RESULT_GROUP, f.SEND_RESULT_NAME,
    f.MAIL_RECEIVE_FLAG, f.MEMBER_STOP_FLAG,
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
    -- [DEC-30 2026-08-04] 발송구분 대/중/소를 DIM_SERVICE(전건 NULL) → DIM_SEND_TYPE 으로 재배선.
    --   코드+라벨 병기(DEC-25). 커버리지 21.58%(비매칭은 센티넬 '(미매핑)').
    st.SEND_GBN_TOP       as SEND_TYPE_L_CD,
    st.SEND_TYPE_L        as SEND_TYPE_L,
    st.SEND_GBN_MID       as SEND_TYPE_M_CD,
    st.SEND_TYPE_M        as SEND_TYPE_M,
    st.SEND_GBN_BOT       as SEND_TYPE_S_CD,
    st.SEND_TYPE_S        as SEND_TYPE_S,
    sv.SUBTYPE            as SERVICE_SUBTYPE,
    sv.CHANNEL            as SERVICE_CHANNEL,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD
from GN_DW.GOLD.FACT_SERVICE_EVENT f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_SEND_TYPE st ON f.SEND_TYPE_SK = st.SEND_TYPE_SK
left join GN_DW.GOLD.DIM_SERVICE  sv on f.SERVICE_SK  = sv.SERVICE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN c  on f.CAMPAIGN_SK = c.CAMPAIGN_SK
    );
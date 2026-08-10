# -*- coding: utf-8 -*-
# [2026-08-07 O51-D] WIDE 뷰 공통 회원속성 컬럼 COMMENT 문안.
# 근거 = BRONZE 코드사전(TC_CMMN_CD/TC_CMMN_DTL_CD) × 실적재 distinct 전수 스캔($HOME/work/codescan.txt).

_SNAP = ("🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — "
         "SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)")

MEMBER_COMMON = {
 "SEX":
  "DIM_MEMBER.SEX — 성별 원천코드 raw. 코드그룹 **CM013(성별)**. "
  "코드사전(BRONZE `TC_CMMN_DTL_CD`) = 1국내(남자)·2국내(여자)·3외국인(남자)·4외국인(여자)·5외국인(기타)·6단체·7기업·8기타 · "
  "실적재(TM_MM_FDRM_MBER_INFO)에 **사전 전종이 등장**하며 폐지코드는 없다. "
  "⚠️개발약정 원천(TM_MM_FDRM_MBER_DVLP_AMT.SEX)에는 사전에 없는 **사전에 없는 센티넬 '0'** 이 더 있다. "
  "🔴정본 비고가 '성별만으로는 사용하지 않음'을 명시한다 — 성별 단일축 분석은 MEMBER_GENDER_NAME 을 쓴다. "
  "라벨 = SEX_NM(원천 라벨)·MEMBER_GENDER_NAME(분석 라벨). " + _SNAP,
 "SEX_NM":
  "DIM_MEMBER.SEX_NM — CM013 **원천 라벨 그대로**(국내(남자)/국내(여자)/외국인(남자)/외국인(여자)/외국인(기타)/단체/기업/기타). "
  "코드 = SEX. 🔴이 컬럼만이 **국내·외국인 축**을 보존한다 — MEMBER_GENDER_NAME(CM017)은 그 축을 지운다. "
  "CM013 은 코드와 라벨이 1:1 이다. " + _SNAP,
 "MEMBER_GENDER_NAME":
  "DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. "
  "CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — "
  "1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. "
  "⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). "
  "⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). " + _SNAP,
 "MEMBER_AREA_CD":
  "DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. "
  "코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · "
  "실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. "
  "⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). "
  "🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). "
  "라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. " + _SNAP,
 "MEMBER_AGE_CD":
  "DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. "
  "코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · "
  "실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. "
  "🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). "
  "⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. "
  "⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. " + _SNAP,
 "MBER_STAT_CD":
  "DIM_MEMBER.MBER_STAT_CD — 회원상태 원천코드 raw(정본 공#132 '회원상태코드'). 코드그룹 **MM010(회원상태)**. "
  "코드사전 = 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단 · "
  "`TH_MM_FDRM_MBER_STNG_DTLS.CHN_STAT_CD` 와 `TM_MM_FDRM_MBER_INFO.MBER_STAT_CD` **양쪽 모두 사전 전종이 등장**한다. "
  "SCD2 버전행은 CHN_STAT_CD(변경상태코드), 무이력행은 MBER_STAT_CD 에서 온다(둘 다 MM010). "
  "🔴MM010 은 개발구분 MM015 가 아니다 — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. "
  "🔴일시회원(MEMBER_TYPE='ONCE')은 회원상태 개념이 원천에 없어 NULL 이다. 라벨 = MEMBER_STATUS_NAME. " + _SNAP,
 "MEMBER_STATUS_NAME":
  "DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. "
  "MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). "
  "값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 미매핑은 '미상'. "
  "⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. " + _SNAP,
 "MBER_DIV_CD":
  "DIM_MEMBER.MBER_DIV_CD — 회원구분 원천코드 raw. 코드그룹 **MM018(회원구분)**. "
  "코드사전 = 1개인·2기업·3단체 · 실적재에 **사전 전종이 등장**한다. "
  "🟢독립 교차검증: `MBER_DIV_CD`='2'(기업)·'3'(단체) 의 행수가 `SEX`='7'(기업)·'6'(단체) 와 **완전히 일치**한다 — 두 축이 같은 사실을 다르게 표현한다. "
  "🔴DIM_MEMBER.MEMBER_TYPE(FDRM/ONCE 등록계통)과 **완전히 다른 축**이다. 라벨 = MEMBER_TYPE_NAME. " + _SNAP,
 "MEMBER_TYPE_NAME":
  "DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. "
  "MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 미매핑은 '미상'. "
  "🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. " + _SNAP,
}

MEMBER_TRANSITION = {
 "PREV_MBER_STAT_CD":
  "DIM_MEMBER.PREV_MBER_STAT_CD — 상태전이의 **이전상태** 코드 raw(MM010). 현재상태 MBER_STAT_CD 와 짝지어 전이를 표현한다. "
  "원천 `TH_MM_FDRM_MBER_STNG_DTLS.BF_STAT_CD` 에 **사전 전종이 등장**한다. "
  "⚠️이력 미보유행(FDRM 무이력·ONCE 전체)은 NULL — '이전상태가 없다'가 아니라 '이력이 없다'. "
  "⚠️동일자 다중전이는 최종 전이로 축약된다(중간 단계 소실). 라벨 = PREV_MEMBER_STATUS_NAME. " + _SNAP,
 "PREV_MEMBER_STATUS_NAME":
  "DIM_MEMBER.PREV_MEMBER_STATUS_NAME — 이전상태명(MM010 라벨). 코드 = PREV_MBER_STAT_CD. "
  "사전과 실적재가 일치한다. 이력 미보유행은 NULL. "
  "🔷(PREV_MEMBER_STATUS_NAME → MEMBER_STATUS_NAME) 쌍이 전이 매트릭스의 두 축이다 — 이 버전행 자체가 전이 사건이므로 fan-out 0. " + _SNAP,
 "JOIN_PATH_CD":
  "DIM_MEMBER.JOIN_PATH_CD — 가입경로 원천코드 raw. 코드그룹 **MM014(가입경로)**. "
  "코드사전 = 1홈페이지·2CRM·3모바일웹·4희망TV·5외주콜센터·6모바일앱·7REG·8EDU 이나 "
  "실적재에는 **1·2·3·5·6·7 만 나타난다** — 🔴**4(희망TV)·8(EDU)는 실적재에 없다.** "
  "⇒ 가입경로 분포에서 이 두 값을 기대하지 말 것. 🔴일시회원(ONCE)은 가입경로 개념이 원천에 없어 NULL. 라벨 = MEMBER_ENROLL_PATH_NAME. " + _SNAP,
 "MEMBER_ENROLL_PATH_NAME":
  "DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. "
  "실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — "
  "사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 미매핑은 '미상'. " + _SNAP,
}

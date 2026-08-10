# -*- coding: utf-8 -*-
# [2026-08-07 O51-D] 뷰별 고유 컬럼 COMMENT 문안. 근거 = BRONZE 전수 스캔(codescan.txt).

MONTHLY_OWN = {
 "MEMBER_LAST_STOP_DATE":
  "DIM_MEMBER.LAST_STOP_DATE — 최종 중단일. 원천 BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE. "
  "🔴**그 버전 시점까지의 as-of max** 다(전체 단순 max 가 아니다). 단순 max 는 미래 정보를 과거 버전에 누설해 "
  "예측 피처(LTV·유지기간)를 오염시킨다. ⚠️중단 이력이 없는 회원·중단 이전 버전은 NULL 이며 '중단하지 않았다'와 "
  "'이력이 없다'를 구분하지 않는다. 🔴이 뷰의 STOP_DATE(월 팩트 measure)와 다른 축이다.",
}

EVENT_OWN = {
 "DVLP_DIV_CD":
  "FACT_MEMBER_EVENT.DVLP_DIV_CD — 개발구분 코드 raw. 코드그룹 **MM015(개발구분)**. "
  "코드사전 = 1신규·2증액·3감액·4재후원·5후원중단. "
  "실적재(TM_MM_FDRM_MBER_DVLP_AMT.DVLP_DIV_CD)에 **사전 전종이 등장**한다. "
  "🔴MM015 는 회원상태 MM010 이 **아니다** — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다(회원상태는 MBER_STAT_CD). "
  "⚠️중단원천(EVENT_TYPE='STOP') 행은 원천에 이 컬럼이 부재해 NULL 이다. 라벨 = DVLP_DIV_NM.",
 "DVLP_DIV_NM":
  "FACT_MEMBER_EVENT.DVLP_DIV_NM — 개발구분명(MM015 라벨): 신규·증액·감액·재후원·후원중단. 코드 = DVLP_DIV_CD. "
  "MM015 는 폐지코드가 없고 실적재가 사전과 일치한다. "
  "🔴🔴값 '후원중단' 은 EVENT_TYPE='STOP' 과 **동일 사건이 거의 전부 중복 존재**한다(동일 회원·일자) — "
  "두 축을 합산하면 이중계상이다(O24 · 현업확인 대기).",
 "SPNSR_AMT":
  "FACT_MEMBER_EVENT.SPNSR_AMT — 후원금액(원) raw. 원천 TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT 무변환 전파. "
  "🔴감액·후원중단 사건은 **음수**다 — 무조건 SUM 하면 개발금액이 상계된다. "
  "🔴정본 공#38 감액(건)·#151 증액(건)이 **금액을 만원 단위로 나눈 값**이라는 규약이므로 원금액을 보존한다(설계 §1·CONF-2) — "
  "이 컬럼을 그대로 '건수'로 쓰지 말 것. ⚠️중단원천 행은 NULL.",
 "STOP_REASON_NM":
  "FACT_MEMBER_EVENT.STOP_REASON_NM — 중단사유명(정본 공#162). 코드그룹 **MM005(후원중단사유)**. 코드 = STOP_REASON. "
  "코드사전에는 **폐지코드(USE_YN='N')가 다수 섞여** 있고 실적재는 사전의 일부만 쓴다. "
  "최빈 코드 = 1개인(경제적)사유 · 14장기미납 · 16신규미납 · 8다른곳지원. "
  "🔴🔴**USE_YN 필터 금지** — 실적재에 **폐지코드가 실재**한다(26은행자동납부해지 · 13반송미납 · 21~25 지라니 계열) ⇒ "
  "USE_YN='Y' 로 걸면 그 행들의 라벨이 사라진다. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️사전에만 있고 실적재에 없는 코드도 다수다.",
 "STOP_CHANNEL_NM":
  "FACT_MEMBER_EVENT.STOP_CHANNEL_NM — 중단경로명. 코드그룹 **MM287(중단경로)**. 코드 = STOP_CHANNEL. "
  "코드사전 = 1 SYSTEM · 2 CRM · 3 홈페이지 · 실적재에 **사전 전종이 등장**한다. "
  "⚠️'SYSTEM' 은 배치가 자동 처리한 중단(장기미납 등)이며 회원의 능동적 해지 채널이 아니다 — 채널 분석 시 분리할 것. "
  "⚠️개발원천 행은 개념 부재로 NULL. ⚠️215지표 밖 — 현업 수요 확인 대상(O25).",
 "AGE_AT_EVENT":
  "FACT_MEMBER_EVENT.AGE_AT_EVENT — 연령대 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM014**. "
  "원천 `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 사건행별 값을 무변환 전파한다. "
  "🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지(1'10대 미만'~9'70대 이상'·10단체·11기업·12기타). "
  "🔴MEMBER_AGE_CD(=현재버전 경유 '최근 약정' 스냅샷)와 **다른 축**이며 같은 회원도 사건마다 값이 다를 수 있다 — "
  "이 컬럼이 그 사건 당시의 정확값이다. ⚠️중단원천 행은 원천 컬럼 부재로 NULL(0 아님, P21). 라벨 = AGE_BAND_AT_EVENT.",
 "AGE_BAND_AT_EVENT":
  "FACT_MEMBER_EVENT.AGE_BAND_AT_EVENT — **사건 시점** 연령대명(CM014 사전 조인, 하드코딩 아님 P31). 코드 = AGE_AT_EVENT. "
  "✅'10대 미만'이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 "
  "학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B). "
  "⚠️사전에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 🔴MEMBER_AGE_BAND(현재버전 스냅샷)와 값이 다를 수 있다. 중단원천 행은 NULL.",
 "AREA_CD_AT_EVENT":
  "FACT_MEMBER_EVENT.AREA_CD_AT_EVENT — 지역 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM018**(지표 공#131). "
  "원천 `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD` 무변환 전파 · 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. "
  "🔴MEMBER_AREA_CD(현재버전 경유 최근 약정 스냅샷)와 **다른 축** — 이사 등으로 사건마다 값이 다를 수 있다. "
  "⚠️**현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가(O34). "
  "⚠️중단원천 행은 원천 컬럼 부재로 NULL. 라벨 = REGION_AT_EVENT.",
 "REGION_AT_EVENT":
  "FACT_MEMBER_EVENT.REGION_AT_EVENT — **사건 시점** 지역명(CM018 약칭 라벨, 지표 공#131). 코드 = AREA_CD_AT_EVENT. "
  "⚠️센티넬 코드 '0' 은 사전에 라벨이 없어 NULL 이다 — '미상'으로 창작하지 않는다. "
  "⚠️**현재 거주지가 아니다**(O34). 🔴MEMBER_REGION(현재버전 스냅샷)과 값이 다를 수 있다. 중단원천 행은 NULL. "
  "🟢이 뷰 안에 캠페인 축이 함께 있어 지역 × 캠페인 교차가 성립한다.",
 "CAMPAIGN_CATEGORY":
  "DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. "
  "🔴[O51-D 실측] 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 **사전에 없는 코드 '58' 이 실재**하므로 그 값은 (미매핑)이 된다. "
  "미채움 행도 있다. "
  "⚠️**사전 자체에 동일 라벨 중복**이 있다(코드 44·45 둘 다 '콜 기타') — 라벨로 GROUP BY 하면 두 코드가 합쳐진다. "
  "⚠️컬럼명 주의: DIM_CAMPAIGN 의 컬럼명은 CAMPAIGN_TYPE 이지만 업무용어는 '카테고리'다. 상위캠페인은 CAMPAIGN_PARENT.",
 "CAMPAIGN_INFLOW_PATH":
  "DIM_CAMPAIGN.INFLOW_PATH — 개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. "
  "코드사전 = (교육기관·기업·뉴미디어·대면모금·디지털·마케팅콜개발·방송·영상광고·일시·재송출·지역개발·회원 기타·"
  "회원 오프라인개발·회원 온라인개발·회원 콜개발·직원개발) · 실적재에 **사전 전종이 등장**하며 "
  "**'디지털'(5)이 압도적 최빈값**이다. "
  "🔴이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다**(O37) — 모집 채널이다. "
  "캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT.",
}

SERVICE_OWN = {
 "SEND_TYPE_L_CD":
  "DIM_SEND_TYPE.SEND_GBN_TOP — 발송구분(대) 코드 raw. "
  "🔴🔴**이 값은 상세코드가 아니라 CRM_CODE 의 코드그룹 ID(CD_ID) 자체다.** "
  "[O51-D 실측] `SND_REQ_MST.SEND_GBN_TOP` 실적재 값 = **MS046·MS047·MS048·MS049·MS050·MS0501·MS0505·MS051·MS052·MS053·MS054·MS055** 이며 "
  "**전부 `TC_CMMN_CD.CD_ID` 에 실재**한다. ⇒ 상세코드 사전(`TC_CMMN_DTL_CD`)에서 찾으면 나오지 않는다. 라벨 = SEND_TYPE_L.",
 "SEND_TYPE_L":
  "DIM_SEND_TYPE.SEND_TYPE_L — 발송구분(대) 분석 라벨(정본 공#133) ← SND_REQ_MST.SEND_GBN_TOP_NM. 코드 = SEND_TYPE_L_CD. "
  "[O51-D 실측] **여러 코드가 같은 라벨로 축약**된다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053. "
  "⇒ 라벨로 GROUP BY 하면 코드가 합쳐진다(대분류는 코드그룹과 1:1 이 아니다). "
  "🔴정본 공#133 과 **불일치**: #133 은 결연/회비/서비스/사업보고/참여/기타 만 열거하는데 실측 라벨에는 **회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053)이 더 있다.** "
  "#133 에 생략기호가 없어 완전열거로 읽히므로 불일치는 실재한다 → 현업 확인 대상, 데이터 우선 보존(DEC-26). "
  "⚠️커버리지가 낮다 — 비매칭은 센티넬 '(미매핑)'(DEC-30). 규모는 이슈원장 §O51-D-C 참조.",
 "SEND_TYPE_M_CD":
  "DIM_SEND_TYPE.SEND_GBN_MID — 발송구분(중) 코드 raw ← SND_REQ_MST.SEND_GBN_MID. "
  "🔴🔴**코드 단독 사용 금지 — 이 코드는 부모(대) 그룹 안에서만 유일하다.** "
  "[O51-D BRONZE 실측] 값 '01' 이 부모에 따라 '결제오류'·'모바일소식지(사단)'·'기타_사단'·'기부금영수증(사단)'·'기타' 등 서로 다른 뜻이며 "
  "실적재 (코드,라벨) 쌍 37종이 나온다. ⇒ 반드시 **(대,중) 쌍**으로 해석할 것. 라벨 = SEND_TYPE_M.",
 "SEND_TYPE_M":
  "DIM_SEND_TYPE.SEND_TYPE_M — 발송구분(중) 분석 라벨(정본 공#134) ← SND_REQ_MST.SEND_GBN_MID_NM. 코드 = SEND_TYPE_M_CD. "
  "예: 결제오류·APR회원발송·ACL회원발송·만18세아동종결(종결예정)·후원참여·회원개발·아동답신(서신/선물금/회소카). "
  "🔴같은 라벨이 여러 부모(대) 아래 반복되므로 라벨 단독 GROUP BY 는 대분류를 섞는다. ⚠️비매칭은 '(미매핑)'.",
 "SEND_TYPE_S_CD":
  "DIM_SEND_TYPE.SEND_GBN_BOT — 발송구분(소) 코드 raw ← SND_REQ_MST.SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). "
  "🔴**코드 단독 모호** — [O51-D 실측] 같은 코드('0101'·'0401' 등)가 부모에 따라 다른 뜻이다. "
  "⇒ **(대,중,소) 경로**로만 해석할 것. 라벨 = SEND_TYPE_S.",
 "SEND_TYPE_S":
  "DIM_SEND_TYPE.SEND_TYPE_S — 발송구분(소) 분석 라벨(정본 공#135) ← SND_REQ_MST.SEND_GBN_BOT_NM. 코드 = SEND_TYPE_S_CD. "
  "예: APR발송예정안내·ACL발송예정안내·기존회원개발메일(사단)·겨울 소식지_사단·답신발송알림·자동이체결제오류(사단)·네이버페이(사단). "
  "🔴라벨도 부모 경로 없이는 유일하지 않다(답신발송알림이 여러 중분류에 존재). ⚠️비매칭은 '(미매핑)'.",
}

PART_OWN = {
 "PART_EVENT_BK":
  "FACT_EVENT_PARTICIPATION.EVENT_BK — degenerate key: **팩트가 보유한 원천 행사키**(전건 채움). "
  "🔴같은 뷰의 EVENT_BK(=DIM_EVENT 매칭분)와 **다르다** — 행사 마스터가 없는 **고아 행사**가 "
  "EVENT_SK=0 으로 뭉개져 서로 구별되지 않으므로 이 컬럼으로 식별을 보존한다. "
  "차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 **PART_EVENT_BK 는 원천값을 그대로 갖는다.** "
  "차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 PART_EVENT_BK 는 원천값을 그대로 갖는다. "
  "🔷행 유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ). ⚠️접두(EVENT_/CRMN_)가 원천 코드체계 판별자(O28).",
 "PARTCPT_SEQ":
  "FACT_EVENT_PARTICIPATION.PARTCPT_SEQ — degenerate key: 참여 일련번호 ← `BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL.PARTCPT_SEQ`. "
  "🔷(PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ) 가 행을 유일 식별한다 — **(행사,회원)만으로는 중복**이다. "
  "🔴**전역 순번이 아니다**((행사,SEQ) 조합도 유일하지 않다) · **음수·INT_MIN 값이 존재**한다 "
  "⇒ **식별자 전용**이며 정렬·범위조건·MAX 로 '참여 횟수'를 세지 말 것.",
 "EVENT_RECRUIT_HEADCOUNT":
  "DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원) ← `SILVER CRM_EVENT.RCRIT_PSNNL_CO`. 일부 행사는 정원이 없다. "
  "🔴🔴**행사 grain 속성이므로 참여행에서 SUM 금지** — 참여행마다 반복되어 **두 자리 배수로 과대계상**된다"
  "(실측 배율은 이슈원장 §O51-D-C). 정원 대비 참여율은 행사 단위로 집계한 뒤 나눌 것. "
  "🔧[DEC-30] 종전 팩트의 RECRUIT_CNT 를 제거하고 이 행사 차원 값으로 대체했다.",
}

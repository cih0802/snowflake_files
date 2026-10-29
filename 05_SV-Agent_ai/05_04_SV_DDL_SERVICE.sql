-- =============================================================================
-- Purpose    : 05_4_SV_DDL_SERVICE.sql — Semantic View DDL 정본: SV_SERVICE
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
-- Run order  : 운영계 #21
-- Depends on : GN_DW.GOLD.FACT_MESSAGE_DISPATCH, GN_DW.GOLD.DIM_DATE, GN_DW.GOLD.DIM_SERVICE, GN_DW.BRONZE_CRM.SND_REQ_MST, GN_DW.GOLD.DIM_MEMBER, GN_DW.GOLD.DIM_SEND_REQUEST 외 2
-- Issue      : O225-C, O229, O241, O237 외 1
-- =============================================================================
-- ============================================================================
-- 05_4_SV_DDL_SERVICE.sql — Semantic View DDL 정본: SV_SERVICE
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · WARN: SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_MESSAGE_DISPATCH
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송', '메시지 발송')
      COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 캠페인 축 = 문자(SND) 발송 캠페인만 배선(원천 SND_MEMBER_LIST.CMPGN_CD) — 이메일·알림톡·우편은 원천에 캠페인 키가 없어 (미매핑)(구조적 부재) ⇒ 「캠페인별 발송」은 SND 기준임을 밝힌다]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK). 미매칭=Unknown(SK=0). [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST(SEND_GBN_TOP/MID/BOT 대·중·소분류 코드) · SILVER=CRM_SEND_REQUEST.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.',
    req AS GN_DW.GOLD.DIM_SEND_REQUEST
      PRIMARY KEY (SEND_REQUEST_SK)
      WITH SYNONYMS ('발송 요청', '발송 요청 차원')
      COMMENT = '발송 요청 차원(요청당 한 행). 메시지구분(MS010)·발송시간구분(MS267)·우편처리상태(MS061)·법인유형(CM019)·분할발송유형. [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST · SILVER=CRM_SEND_REQUEST · GOLD=DIM_SEND_REQUEST.',
    --  [2026-10-14 O225-C] 발송 캠페인 축(SND 채널만 값 · 그 외 채널 = (미매핑) SK=0)
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '발송 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 🔴 문자(SND) 발송만 캠페인코드가 있다 — 이메일·알림톡·우편은 전건 (미매핑). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM.SND_MEMBER_LIST.CMPGN_CD → TM_CM_CMPGN_MNG · SILVER=CRM_CAMPAIGN.',
    --  [2026-10-28 O265-C] 알림톡 수신 후 D+5 카카오 경로 GA 클릭(클릭 1건 = 1행)
    atclk AS GN_DW.GOLD.FACT_AT_GA_CLICK
      WITH SYNONYMS ('알림톡 클릭', '알림톡 링크 클릭', 'GA 클릭')
      COMMENT = '알림톡 수신 후 D+5 카카오 경로 GA 클릭(O265-C). [Grain: 발송요청 × 채널 × 회원 × 클릭 시각 × 랜딩]. 질문에 템플릿 ID·링크(경로·utm_campaign)가 주어지면 이 표에서 직접 거른다(우선순위 ①). 🔴 회원수는 COUNT DISTINCT.'
  )
  RELATIONSHIPS (
    fse_to_date    AS fse (DATE_SK)    REFERENCES date,
    fse_to_service AS fse (SERVICE_SK) REFERENCES service,
    fse_to_member  AS fse (MEMBER_DK)  REFERENCES member,
    fse_to_req     AS fse (SEND_REQUEST_SK) REFERENCES req,
    fse_to_campaign AS fse (CAMPAIGN_SK) REFERENCES campaign,
    --  [2026-10-28 O265-C] 알림톡 수신 후 D+5 GA 클릭(① 질문 시 템플릿·링크 패턴 필터용)
    atclk_to_member AS atclk (MEMBER_DK) REFERENCES member,
    atclk_to_req    AS atclk (SEND_REQUEST_SK) REFERENCES req,
    atclk_to_date   AS atclk (DATE_SK) REFERENCES date
  )
  DIMENSIONS (
    date.SEND_DATE  AS date.FULL_DATE  WITH SYNONYMS ('발송일', '일자', '날짜', '공137') COMMENT = '발송일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — SEND_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR   AS date.YEAR       WITH SYNONYMS ('연도', '년')     COMMENT = '연도',
    date.CAL_MONTH  AS date.MONTH      WITH SYNONYMS ('월')            COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    service.SUBTYPE AS service.SUBTYPE WITH SYNONYMS ('서비스유형', '발송소분류') COMMENT = '서비스 subtype. ⚠️ **라벨이 아니라 원천 숫자 코드**다 — 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''0''·''1''·''2''·''3''·''(미매핑)'' + NULL. 🔴🔴 **CHANNEL 과 함께 보지 않으면 서로 다른 체계를 섞는다** — 이 컬럼도 `SEND_STATUS` 와 **같은 구조적 결함**이다: 채널별로 도메인이 다르다(EMAIL ''0''·''1''·''2''+NULL / MSG_AT ''0''·''1'' / PSTMTR ''1''·''2''·''3'' / SND 는 NULL). 같은 ''1'' 이 채널에 따라 다른 것을 뜻하므로 이 축 단독 그루핑·필터는 오답이다. 🔴 **라벨은 만들지 않았다 — 코드군을 특정할 수 없어서다**(채널별 도메인이 2~3종뿐이라 사전 후보가 과다하고, 의미가 맞는 그룹이 없다 · 등급 D). 의미를 창작하지 말고 **코드값 그대로 + 채널 동반**으로 제시하고 라벨 부재를 밝힌다(현업 확인 =)',
    service.CHANNEL AS service.CHANNEL WITH SYNONYMS ('채널', '발송채널') COMMENT = '발송 채널. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''MSG_AT''·''SND''·''EMAIL''·''PSTMTR''·''(미매핑)''. 🔴🔴 **위 5종 외의 값은 이 축에 존재하지 않는다** — 다른 값으로 필터하면 0행 무증상 오답이다. ⚠️ ''(미매핑)''은 원천 채널코드가 사전에 없는 행이다',
    fse.SEND_STATUS AS fse.SEND_STATUS WITH SYNONYMS ('발송상태코드') COMMENT = '발송 상태 **축A 원천 코드**(라벨 아님). 🔴🔴 **반드시 CHANNEL 과 함께 볼 것 — 채널마다 코드체계가 다르다.** BRONZE 원천 대조 결과 이 컬럼은 채널별로 **서로 다른 원천 컬럼**을 받는다: EMAIL 계열은 ''0''·''1'' · MSG_AT 계열은 ''2''·''3''·''4'' · SND 계열은 ''Y''·''N'' · PSTMTR 계열은 **원천에 결과코드 컬럼이 아예 없어 전건 NULL**(결측이 아니라 구조적 부재). 🔴 따라서 CHANNEL 없이 이 축만 그루핑하면 **서로 다른 체계를 한 표에 섞는다.** ✅ **사람이 읽는 라벨은 SEND_STATUS_NAME 축을 쓴다**(R1 — 현업은 코드를 모른다). 🟢 통신사 도달 결과는 **축B**(SEND_RESULT_CD·SEND_RESULT_GROUP·SEND_RESULT_NAME)가 따로 담으며 그쪽은 채널 간 conformed 다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''0''·''1''·''2''·''3''·''4''·''N''·''Y'' + NULL',
    fse.SEND_STATUS_NAME AS fse.SEND_STATUS_NAME WITH SYNONYMS ('발송상태', '발송상태명', '공138', '공86', '공87', '신규31') COMMENT = '발송 상태 **축A 라벨 — 현업 응답용 정본 축**이다(코드군 MS282 · 원천 교차로 의미 확정). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''발송완료''·''에러''·''예약취소'' + NULL. 🔴🔴 **NULL 은 결측이 아니다** — 라벨은 **MSG_AT 계열만** 채워진다: EMAIL·SND 는 코드값만 있고 **사전에 라벨 문자열이 없어 의도적 NULL** 이며(「성공/실패」는 원천 교차로 얻은 우리 해석이라 라벨로 창작하지 않는다 · 현업 확인 =), PSTMTR 은 원천 자체가 없다. ⇒ 이 축으로 분해할 때는 **NULL 덩어리를 함께 밝히고 CHANNEL 을 동반**한다. 🔴 **성공/실패 판정은 MSG_AT 한정으로만 가능**하며 전 채널 성공률로 단정하지 말 것',
    fse.SEND_RESULT_CD AS fse.SEND_RESULT_CD WITH SYNONYMS ('통신사결과코드', '전송실패코드') COMMENT = '**축B 통신사 결과 코드 raw**(MSG_AT 전송실패코드 · SND 수신결과상태). 🟢 **축A 와 달리 conformed 다** — 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 코드체계가 유지된다. 라벨은 SEND_RESULT_NAME · 코드군은 SEND_RESULT_GROUP 을 쓴다(복합키 = 코드군 + 코드). ⚠️ 카디널리티가 커 열거하지 않는다 — 특정 사유를 찾으려면 라벨축이나 코드군축을 먼저 쓴다. ⚠️ **운영 코드사전에도 없는 통신사 코드가 실재**한다 ⇒ 그 행은 라벨 NULL 이며 센티넬을 창작하지 않는다(사전 갱신 요청 =)',
    fse.SEND_RESULT_GROUP AS fse.SEND_RESULT_GROUP WITH SYNONYMS ('통신사결과코드군', '메시지타입코드군') COMMENT = '**축B 코드군 ID** — 사전 MS283 이 정의한 4그룹이며 **메시지 타입 판별자**다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''MS056''·''MS057''·''MS058''·''MS059'' + NULL(축B 코드가 없는 행). MS056=공통 · MS057=알림톡 · MS058=SMS · MS059=MMS. 🟢 이 값은 리터럴 지정이 아니라 **사전 조인 결과에서 얻는다**(코드값이 4그룹에 걸쳐 중복 없음). 🔴 축B 코드를 필터할 때 이 축을 동반하면 오조인이 구조로 차단된다',
    fse.SEND_RESULT_NAME AS fse.SEND_RESULT_NAME WITH SYNONYMS ('통신사결과', '전송실패사유', '발송결과사유') COMMENT = '**축B 라벨 — 통신사가 반환한 도달 결과 사유**(사전 MS056~MS059). ⚠️ 카디널리티가 커 열거하지 않는다 — 「전달」이 도달 성공이고 나머지는 실패 사유다(타임아웃·전화번호 오류·템플릿 없음 등). 🔴🔴 **축A(SEND_STATUS_NAME) 와 의미가 다르다** — 축A 는 **우리 발송 시스템의 상태**(발송완료/에러/예약취소), 축B 는 **통신사 도달 결과**다. 한 표에 섞거나 합산하지 말고 어느 축으로 답했는지 밝힌다. 🔴 코드는 있으나 **사전에 라벨이 없는 행은 NULL** 이다 — 도달률·실패율의 분모를 낼 때 그 덩어리를 함께 밝힌다',
    fse.ALTRTV_MSG_SNDNG_YN AS fse.ALTRTV_MSG_SNDNG_YN WITH SYNONYMS ('대체문자', '대체문자 발송여부', '알림톡 대체발송') COMMENT = '대체문자 발송 여부 — **알림톡(CHANNEL=''MSG_AT'') 전용** 원천 값이다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''Y'' + NULL. 🔴 다른 채널(EMAIL·SND·PSTMTR)은 원천에 이 컬럼이 없어 전건 NULL 이다(구조적 부재) ⇒ 반드시 CHANNEL=''MSG_AT'' 로 한정한다. 🔴 원천에 ''N'' 값이 없다 — MSG_AT 의 NULL 을 「대체문자 미발송」으로 단정하지 말고 「Y 표기 없음」으로 표현한다',
    fse.SEND_TITLE AS fse.SEND_TITLE WITH SYNONYMS ('발송제목', '발송명', '메시지 제목', '알림톡 제목', '캠페인 메시지명', '공136') COMMENT = '발송 제목(발송요청 원천 제목 · 자유 텍스트). 🔴 고유값이 수만 종인 자유 텍스트다 — 「행운의 카드」처럼 이름으로 물으면 **ILIKE ''%행운%카드%''** 처럼 부분일치로 필터하고 정확일치를 가정하지 않는다. 일치한 제목 목록을 함께 보여준다. ⚠️ 제목이 없는 발송은 NULL 이다(원천 미입력). 🔴 캠페인 축이 아니다 — 제목으로 캠페인을 추정하지 않는다',
    fse.RESPONSED_YN AS fse.RESPONSED_YN WITH SYNONYMS ('확인여부', '발송확인여부', '수신확인') COMMENT = '발송 확인 여부 — **문자(CHANNEL=''SND'') 전용** 원천 값이다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''Y''·''N'' + NULL. 🔴 다른 채널은 원천에 컬럼이 없어 전건 NULL(구조적 부재) ⇒ CHANNEL=''SND'' 로 한정한다. 🔴🔴 **오픈(링크 클릭 · TOTAL_OPEN_MEMBERS)과 다른 축이다** — 확인여부를 오픈·클릭으로 바꿔 말하거나 두 값을 합산·비교해 하나의 반응률로 만들지 말 것. ⚠️ SND 에도 값이 없는 소수 행은 NULL 이다',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 발송 시점 값이 아니다). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''Y''·''N'' + NULL. 🔴 과거 발송을 이 축으로 나누면 「발송 당시 수신 상태」가 아니라 **현재 상태**로 나뉜다 — 그 전제를 밝힌다. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨).',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''1''~''8''(+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다. ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''1''·''2''·''3''',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014) — 회원 마스터 현재값. 일시회원은 (해당없음). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''(해당없음)''·''CRM''·''REG''·''모바일앱''·''모바일웹''·''외주콜센터''·''홈페이지''',
    member.MEMBER_JOIN_CMMN_BRND_NM AS member.JOIN_CMMN_BRND_NM WITH SYNONYMS ('가입 공통브랜드', '회원 가입 공통브랜드') COMMENT = '회원 가입 시 공통브랜드(MM297) — 회원 마스터 기준. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기업''·''뉴미디어''·''대면모금''·''디지털''·''마케팅콜개발''·''방송''·''영상광고''·''재송출''·''지역개발''·''콜개발''·''회원 기타''·''회원 오프라인개발''·''회원 온라인개발''·''회원 콜개발''',
    fse.FRST_BRND_NM AS fse.FRST_BRND_NM WITH SYNONYMS ('최초 브랜드', '발송 시점 최초 브랜드') COMMENT = '발송 시점 회원의 최초 브랜드명(원천 SND_MEMBER_LIST · 발송 원천 스냅샷).',
    fse.LST_BRND_NM AS fse.LST_BRND_NM WITH SYNONYMS ('최종 브랜드', '발송 시점 최종 브랜드') COMMENT = '발송 시점 회원의 최종 브랜드명(원천 SND_MEMBER_LIST · 발송 원천 스냅샷).',
    fse.SEND_TYPE AS fse.SEND_TYPE WITH SYNONYMS ('발송채널 원천구분', '발송 원천') COMMENT = '발송 원천 계열(EMAIL·PSTMTR(우편)·MSG_AT(알림톡)·SND(문자)). 🔴 채널(CHANNEL) 라벨과 같은 축의 원천 코드다 — 채널 질문은 채널 차원을 먼저 쓴다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''EMAIL''·''MSG_AT''·''PSTMTR''·''SND''',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME WITH SYNONYMS ('결연구분', '결연/비결연') COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결연회원''·''비결연회원''·''중단회원''·''혼합회원''',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분') COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''GMN이관''·''교육전문위원''·''나눔원정대''·''더네이버스레거시클럽''·''더네이버스아너스클럽''·''더네이버스클럽''·''블랙리스트''·''연예인''·''유명인''·''유아전문위원''·''이사회''·''일반''·''임효진이음''·''정회원''·''좋은이웃가게''·''지역협력위원''·''테스트회원''·''특별결연회원''·''홍보대사''·''회원부지정회원''',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME WITH SYNONYMS ('최초후원사업', '최초 후원사업') COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태') COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결번''·''정상''·''타인번호''',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME WITH SYNONYMS ('이메일상태', '이메일 상태') COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''계정없음''·''도메인오류''·''정상''',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절') COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''TM 거절''·''TMTS거절''·''TS 거절''',
    member.MEMBER_ETC_CTTPC_STAT_NAME AS member.ETC_CTTPC_STAT_NAME WITH SYNONYMS ('기타연락처 상태') COMMENT = '기타연락처 상태(MM008 · 정상·결번·타인번호). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결번''·''정상''·''타인번호''',
    member.MEMBER_EMAIL_RECV_REFUSE_YN AS member.EMAIL_RECV_REFUSE_YN WITH SYNONYMS ('이메일 수신거부 수신', '이메일 수신항목 수신거부') COMMENT = '이메일 수신 항목에 「수신거부」(MS028 코드 1)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_REGULAR_YN AS member.EMAIL_RECV_REGULAR_YN WITH SYNONYMS ('이메일 정기우편물 수신', '이메일 수신항목 정기우편물') COMMENT = '이메일 수신 항목에 「정기우편물」(MS028 코드 2)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_RELATION_YN AS member.EMAIL_RECV_RELATION_YN WITH SYNONYMS ('이메일 결연이메일 수신', '이메일 수신항목 결연이메일') COMMENT = '이메일 수신 항목에 「결연이메일」(MS028 코드 3)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_THANKS_YN AS member.EMAIL_RECV_THANKS_YN WITH SYNONYMS ('이메일 감사서비스 수신', '이메일 수신항목 감사서비스') COMMENT = '이메일 수신 항목에 「감사서비스」(MS028 코드 4)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_WEBZINE_YN AS member.EMAIL_RECV_WEBZINE_YN WITH SYNONYMS ('이메일 웹진 수신', '이메일 수신항목 웹진') COMMENT = '이메일 수신 항목에 「웹진」(MS028 코드 5)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_DEV_YN AS member.EMAIL_RECV_DEV_YN WITH SYNONYMS ('이메일 개발이메일 수신', '이메일 수신항목 개발이메일') COMMENT = '이메일 수신 항목에 「개발이메일」(MS028 코드 6)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_REFUSE_YN AS member.POST_RECV_REFUSE_YN WITH SYNONYMS ('우편물 수신거부 수신', '우편물 수신항목 수신거부') COMMENT = '우편물 수신 항목에 「수신거부」(MS027 코드 1)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_REGULAR_YN AS member.POST_RECV_REGULAR_YN WITH SYNONYMS ('우편물 정기우편 수신', '우편물 수신항목 정기우편') COMMENT = '우편물 수신 항목에 「정기우편」(MS027 코드 2)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_RELATION_YN AS member.POST_RECV_RELATION_YN WITH SYNONYMS ('우편물 결연우편 수신', '우편물 수신항목 결연우편') COMMENT = '우편물 수신 항목에 「결연우편」(MS027 코드 3)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_NEW_THANKS_YN AS member.POST_RECV_NEW_THANKS_YN WITH SYNONYMS ('우편물 신규/감사 우편 수신', '우편물 수신항목 신규/감사 우편') COMMENT = '우편물 수신 항목에 「신규/감사 우편」(MS027 코드 4)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    req.REQ_SEND_GBN_TOP_NM AS req.SEND_GBN_TOP_NM WITH SYNONYMS ('발송 카테고리(대)', '발송구분 대분류', '발송 대분류', '발송구분(대)', '공133') COMMENT = '발송구분 대분류 — 문자(SND)·알림톡(MSG_AT)·이메일(EMAIL) 요청 모두 값이 있다(O265 · 알림톡·이메일 = 원천 SNDNG_CD_ID 코드그룹명). 우편(PSTMTR)만 NULL(원천 컬럼 없음). 채널을 묻지 않은 발송구분 질문은 세 채널을 함께 본다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결연''·''기타''·''데이터''·''사업보고''·''서비스''·''참여''·''회비''·''회원''·''회원만족''·''회원서비스''',
    req.REQ_SEND_GBN_MID_NM AS req.SEND_GBN_MID_NM WITH SYNONYMS ('발송 카테고리(중)', '발송구분 중분류', '발송 중분류', '발송구분(중)', '공134') COMMENT = '발송구분 중분류(예: ACPI회원발송·신규결연회원발송·아동답신·기부금영수증·결제오류·장기회원감사서비스) — 문자·알림톡·이메일 요청 모두 값이 있다(O265) · 우편만 NULL. 🔴 같은 이름이 여러 대분류 아래 반복된다 ⇒ 대분류와 함께 해석한다.',
    req.REQ_SEND_GBN_BOT_NM AS req.SEND_GBN_BOT_NM WITH SYNONYMS ('발송 카테고리(소)', '발송구분 소분류', '발송 소분류', '발송구분(소)', '공135') COMMENT = '발송구분 소분류 — 문자·알림톡·이메일 요청 모두 값이 있다(O265) · 우편만 NULL. 🔴 같은 이름이 여러 중분류 아래 반복된다 ⇒ 대·중분류와 함께 해석한다.',
    req.REQ_MSG_DIV_NAME AS req.MSG_DIV_NAME WITH SYNONYMS ('메시지 구분', 'SMS/LMS/MMS', '문자 종류') COMMENT = '메시지 구분(MS010 · SMS·LMS·MMS·알림톡) — 알림톡(MSG_AT) 요청 전용 · 타 채널 NULL. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''LMS''·''MMS''·''SMS''·''알림톡''',
    req.REQ_SNDNG_TIME_DIV_NAME AS req.SNDNG_TIME_DIV_NAME WITH SYNONYMS ('발송 시간 구분', '즉시/예약/분할') COMMENT = '발송 시간 구분(MS267 · 즉시발송·분할발송·예약발송) — 알림톡 요청 전용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''분할발송''·''예약발송''·''즉시발송''',
    req.REQ_PSTMTR_PRCS_STAT_NAME AS req.PSTMTR_PRCS_STAT_NAME WITH SYNONYMS ('우편물 처리상태', '우편 발송완료 여부') COMMENT = '우편물 처리상태(MS061 · 발송대기·발송완료) — 우편(PSTMTR) 요청 전용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''발송대기''·''발송완료''',
    req.REQ_RE_SNDNG_YN AS req.RE_SNDNG_YN WITH SYNONYMS ('재발송 여부', '재발신 여부') COMMENT = '재발신 여부(Y/N) — 우편 요청 전용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''N''·''Y''',
    req.REQ_LQY_YN AS req.LQY_YN WITH SYNONYMS ('대량발송 여부', '대량 여부') COMMENT = '대량 발송 여부(Y/N) — 우편 요청 전용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''N''·''Y''',
    req.REQ_CORP_TYPE_NAME AS req.CORP_TYPE_NAME WITH SYNONYMS ('발송 법인구분', '요청 법인') COMMENT = '발송 요청 법인구분(CM019 · 사단·사복) — 문자(SND) 요청 일부에만 값(대다수 NULL). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''사단''·''사복''',
    req.REQ_SEND_SPLIT_TYPE AS req.SEND_SPLIT_TYPE WITH SYNONYMS ('문자 분할 방식', '일괄/분할') COMMENT = '문자 발송 분할 방식 원천값(once = 일괄 · divide = 분할) — 문자(SND) 요청 전용. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''divide''·''once''',
    req.REQ_SEND_FORMAT_NAME AS req.SEND_FORMAT_NAME WITH SYNONYMS ('메시지 형식', '발송 형식', '알림톡 여부', '실제 발송 매체') COMMENT = '실제 메시지 형식(O265). 🔴 발송 채널(SEND_TYPE)과 다르다 — 문자 시스템(SND)도 알림톡을 보낸다(예: 2025-09-17 「행운의 카드」). ⇒ 「알림톡」을 물으면 채널이 아니라 이 차원으로 거른다. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''알림톡''·''LMS''·''MMS''·''SMS''·''문자''·''이메일''·''우편''',
    fse.GA_CLICK_TS AS fse.GA_CLICK_TS WITH SYNONYMS ('알림톡 클릭 시각', '알림톡 열람 시각') COMMENT = '그 알림톡 템플릿 링크의 최초 GA 클릭 시각(O265-C) — 알림톡(MSG_AT·문자 시스템 알림톡) 전용 · 그 밖 NULL.',
    --  [2026-10-28 O265-C] A 판정 근거 · 클릭 grain 차원(① 질문 시 템플릿·링크 필터)
    fse.GA_CLICK_MAP_SRC AS fse.GA_CLICK_MAP_SRC WITH SYNONYMS ('열람 판정 근거', '알림톡 열람 판정 근거') COMMENT = '그 알림톡 열람(A) 판정 근거 = 템플릿 링크 매핑 출처. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''MANUAL''(분석 확정)·''DIRECT''(템플릿 원문 URL)·''INFER''(수신자 클릭 전용성 추정)·''NONE''(매핑 없음 = A 판정 불가) · 비알림톡 NULL. 🆕 [O269] 웹팀 리다이렉트 대상표가 들어오면 값 WEB_TEAM 이 추가된다(현재 0행 · 이 값으로 필터하면 0행).',
    atclk.CLICK_TEMPLATE_ID AS atclk.TEMPLATE_ID WITH SYNONYMS ('알림톡 템플릿 ID', '템플릿 ID', '템플릿 코드') COMMENT = '클릭이 일어난 수신 알림톡의 템플릿 ID(AT…). 질문에 템플릿 ID 가 있으면 이 값으로 거른다(우선순위 ①).',
    atclk.CLICK_LANDING_PATH AS atclk.LANDING_PATH WITH SYNONYMS ('랜딩 경로', '클릭 링크 경로', '링크 URL 경로') COMMENT = '클릭 랜딩 경로(호스트 뒤 · 소문자 · 예 /app/event/25kaomgift/acpi2025.gn). 질문에 링크가 주어지면 ILIKE 로 거른다(우선순위 ①).',
    atclk.CLICK_UTM_CAMPAIGN AS atclk.UTM_CAMPAIGN WITH SYNONYMS ('utm 캠페인', 'utm_campaign', '링크 캠페인') COMMENT = '클릭 URL 의 utm_campaign(소문자). 질문에 utm 캠페인이 주어지면 이 값으로 거른다(우선순위 ①).',
    atclk.CLICK_UTM_CONTENT AS atclk.UTM_CONTENT WITH SYNONYMS ('utm 콘텐츠', 'utm_content') COMMENT = '클릭 URL 의 utm_content(소문자).',
    atclk.CLICK_MAP_MATCHED AS atclk.MAP_MATCHED WITH SYNONYMS ('템플릿 링크 일치') COMMENT = '그 클릭이 템플릿의 매핑 패턴(②③)에 맞으면 1 · 아니면 0 · 템플릿 매핑이 없으면 NULL.',
    atclk.CLICK_DAYS_FROM_SEND AS atclk.DAYS_FROM_SEND WITH SYNONYMS ('수신 후 경과일') COMMENT = '수신일 대비 클릭일(0~5).',
    fse.SND_SPNSR_NM AS fse.SND_SPNSR_NM WITH SYNONYMS ('발송 시점 후원사업', '발송 당시 후원사업') COMMENT = '문자(SND) 발송 시점 수신 회원의 후원사업명(원천 발송 스냅샷) — 타 채널 NULL. 현재 후원사업과 다를 수 있다.',
    fse.SND_FRST_SPNSR AS fse.SND_FRST_SPNSR WITH SYNONYMS ('발송 시점 최초 후원사업') COMMENT = '문자(SND) 발송 시점 수신 회원의 최초 후원사업명 [SND 전용 · 그 밖 채널 NULL · O262-B].',
    fse.SND_CHILD_DTL_NM AS fse.SND_CHILD_DTL_NM WITH SYNONYMS ('발송 시점 결연상태', '결연 상세상태') COMMENT = '문자(SND) 발송 시점 결연 상세상태명 [SND 전용 · O262-B]. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''결연중''·''비지정결연''·''퇴소예정''·''캠페인지정''·''자동결연지정''·''사업장퇴소대기''·''매칭제한''·''연령제한''·''퇴소''·''홈페이지지정''·''기타''',
    fse.SND_NATION_NM AS fse.SND_NATION_NM WITH SYNONYMS ('발송 시점 결연아동 국가', '결연 국가') COMMENT = '문자(SND) 발송 시점 결연아동 국가명 [SND 전용 · O262-B].',
    fse.SND_BPLC_KOR_NM AS fse.SND_BPLC_KOR_NM WITH SYNONYMS ('발송 시점 결연 사업장', '결연 사업장') COMMENT = '문자(SND) 발송 시점 결연아동 사업장명 [SND 전용 · O262-B].',
    fse.SND_DSCNTC_RSN_NM AS fse.SND_DSCNTC_RSN_NM WITH SYNONYMS ('발송 시점 중단사유', '발송 당시 중단사유') COMMENT = '문자(SND) 발송 시점 수신 회원의 중단사유명(중단 이력 회원만 값 · 원천 스냅샷) — 타 채널 NULL. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''개인(경제적)사유''·''기업후원종료''·''기타''·''다른곳지원''·''만18세아동퇴소''·''명의변경''·''반송미납''·''사업장종결''·''신규미납''·''아동퇴소''·''약정후원''·''은행자동납부해지''·''이중가입''·''일시후원이었음''·''장기미납''·''지라니이관''·''회원항의''',
    fse.SND_CHILD_PROJECT_COUNTRY AS fse.SND_CHILD_PROJECT_COUNTRY WITH SYNONYMS ('결연아동 사업국', '신규 결연아동 국가') COMMENT = '문자(SND) 발송 시점 신규 결연아동 사업국(방글라데시·우간다·에티오피아 등) — 결연 안내 발송 분석용 · 타 채널 NULL.',
    fse.SND_CHILD_WORKPLACE_NM AS fse.SND_CHILD_WORKPLACE_NM WITH SYNONYMS ('결연아동 사업장', '신규 결연아동 사업장') COMMENT = '문자(SND) 발송 시점 신규 결연아동 사업장명 — 타 채널 NULL.',
    --  [2026-10-14 O225-C] 발송 캠페인 속성(DIM_CAMPAIGN) + SND 회원 최종·현재 캠페인코드
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '발송 캠페인', '캠페인') COMMENT = '문자(SND) 발송 캠페인명. 타 채널 = (미매핑)(원천에 캠페인코드 없음).',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인 카테고리', '주요캠페인', '캠페인유형') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''국내''·''전체사업''·''통합''·''해외''',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업/사례') COMMENT = '캠페인유형 굿즈/기타/사례/사업(MM296). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''굿즈''·''기타''·''사례''·''사업''',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('인입경로', '회원인입', '개발인입경로') COMMENT = '캠페인 개발인입경로(MM293). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발''',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002). 발송 채널(CHANNEL)과 다른 축이다.',
    campaign.CAMPAIGN_TARGET_NAME AS campaign.CAMPAIGN_TARGET_NAME WITH SYNONYMS ('캠페인대상', '캠페인 대상', '대상 구분') COMMENT = '캠페인 대상 구분(CM002 라벨 · O262-B). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''일반인''·''정기회원''·''후원중단회원''·''기업임직원''·''웹진구독회원''·''일시회원''·''정기/일시회원''·''GNI USA''·''직원''·''일반인/일시회원''. 코드 없음 = NULL(값이 없는 캠페인 · 미매핑 아님).',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('UTM', 'UTM 캠페인') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명') COMMENT = '상위캠페인명. 상위가 없으면 NULL.',
    campaign.PROMO_METHOD_NAME AS campaign.PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법') COMMENT = '홍보방법명(CM008).',
    campaign.CMMN_BRND_NM AS campaign.CMMN_BRND_NM WITH SYNONYMS ('공통브랜드') COMMENT = '공통브랜드명(MM297). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''교육기관''·''기업''·''뉴미디어''·''대면모금''·''디지털''·''마케팅콜개발''·''방송''·''영상광고''·''일시''·''재송출''·''지역개발''·''콜개발''·''회원 기타''·''회원 오프라인개발''·''회원 온라인개발''·''회원 콜개발''',
    campaign.CPR_DIV_NM AS campaign.CPR_DIV_NM WITH SYNONYMS ('캠페인 법인구분') COMMENT = '캠페인 법인구분명(CM019). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''사단''·''사복''·''통합''',
    campaign.SPNSR_DIV_NM AS campaign.SPNSR_DIV_NM WITH SYNONYMS ('캠페인 후원구분') COMMENT = '캠페인 후원구분명(CM035 정기/일시). 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''일시후원''·''정기후원''',
    --  [2026-10-14 O229] campaign_axis_gate GAP 해소 = CMPGN_STRT_DE → DIM_CAMPAIGN.CAMPAIGN_OPEN_DATE
    campaign.CAMPAIGN_OPEN_DATE AS campaign.CAMPAIGN_OPEN_DATE WITH SYNONYMS ('캠페인 시작일', '캠페인 개설일', '공19') COMMENT = '캠페인 시작일(원천 캠페인관리 시작일자). 시작일이 없는 캠페인은 NULL.',
    campaign.IS_PARENT_CAMPAIGN_YN AS campaign.IS_PARENT_CAMPAIGN_YN WITH SYNONYMS ('상위캠페인여부', '상위캠페인 여부') COMMENT = '상위캠페인 여부. 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): ''Y''(그 자신이 상위캠페인)·''N''(하위캠페인) + NULL(미매핑 멤버).',
    fse.SND_LAST_CMPGN AS fse.SND_LAST_CMPGN WITH SYNONYMS ('발송 시점 최종캠페인코드') COMMENT = '문자(SND) 발송 시점 수신 회원의 최종 캠페인코드(코드값 · 라벨은 캠페인 SV 로) — 타 채널 NULL.',
    fse.SND_CURRENT_CMPGN AS fse.SND_CURRENT_CMPGN WITH SYNONYMS ('발송 시점 현재캠페인코드') COMMENT = '문자(SND) 발송 시점 수신 회원의 현재 캠페인코드(코드값) — 타 채널 NULL.'
  )
  METRICS (
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송건', '발송 횟수', '공85')
      COMMENT = '발송 **건수** 합계. F(가산). 🔴**회원수가 아니다** — 같은 회원에게 여러 번 발송되면 그만큼 중복 계수된다. 회원 「명」 수를 묻는 질문(발송 회원수·수신 대상 몇 명)에는 이 metric 을 쓰지 말고 DISTINCT_SEND_MEMBERS 를 쓴다. ⚠️metric 명에 MEMBERS 가 들어간 것은 기저 컬럼명(SEND_MEMBERS) 을 따른 역사적 잔재이며 의미는 건수다.',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 회원수', '발송 고유회원수', '발송(명)', '발송명', '수신 대상 회원수', '수신자수', '몇 명에게 발송', '신규30')
      COMMENT = '발송 대상 **고유 회원수(명)**. D(distinct) — 🔴가산 금지: 월별로 뽑아 합산하면 여러 달 수신한 회원이 중복된다. 기간을 바꾸면 반드시 재집계할 것. 정본 「발송(명)」이 이 metric 이다(발송 건수는 TOTAL_SEND_MEMBERS).',
    fse.D5_LETTER_MEMBERS AS SUM(fse.D5_LETTER_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 서신참여(명)', 'D5 서신참여', '공88') COMMENT = '공#139 발송 다음날(D+1)~+5일 안에 서신 접수가 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_LETTER_CNT AS SUM(fse.D5_LETTER_PART_CNT)
      WITH SYNONYMS ('발송후 5일 서신참여(건)', '공89') COMMENT = '공#140 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_GIFT_MEMBERS AS SUM(fse.D5_GIFT_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 선물금참여(명)', 'D5 선물금참여', '공90') COMMENT = '공#141 발송 다음날(D+1)~+5일 안에 선물금 참여가 있는 발송 대상 수(중복 포함). ⚠️ 선물금 원천에 접수일이 없어 선물금 발송일로 매칭한다. F(가산).',
    fse.D5_GIFT_CNT AS SUM(fse.D5_GIFT_PART_CNT)
      WITH SYNONYMS ('발송후 5일 선물금참여(건)') COMMENT = '공#142 위 매칭 회원의 활동(건) 합. F(가산).',
    --  [2026-10-16 O241] 공91 추천안B(잠정) — 발송 매칭 선물금(원) · A = SV_RELATION_ACTIVITY.TOTAL_GIFT_AMT
    fse.D5_GIFT_AMT AS SUM(fse.D5_GIFT_PART_AMT)
      WITH SYNONYMS ('선물금참여(원)(추천안B)', '발송 매칭 선물금', '발송후 5일 선물금(원)', '공91B')
      COMMENT = '공91 추천안B(잠정) 선물금참여(원) = 발송 다음날(D+1)~+5일 안 선물금 합. 선물금 1건은 창 안 가장 가까운 직전 발송일 1개에만 귀속되므로 기간 합이 중복 없이 가산된다. F(가산). 🔴 추천안A(결연활동 전체 선물금 = SV_RELATION_ACTIVITY.TOTAL_GIFT_AMT)와 다른 팩트다 — 한 쿼리로 결합하지 말고 두 도구 결과를 병기한다. 처리통보성 제목 발송은 귀속 후보에서 제외. 인과가 아니라 시간 창 매칭이다.',
    fse.D5_INCREASE_MEMBERS AS SUM(fse.D5_INCREASE_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 증액참여(명)', 'D5 증액') COMMENT = '공#143 발송 다음날(D+1)~+5일 안에 증액 개발(MM015 ''2'')이 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_INCREASE_CNT AS SUM(fse.D5_INCREASE_PART_CNT)
      WITH SYNONYMS ('발송후 5일 증액참여(건)') COMMENT = '공#144 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_STOP_MEMBERS_SUM AS SUM(fse.D5_STOP_MEMBERS)
      WITH SYNONYMS ('발송후 5일 중단(명)', 'D5 중단') COMMENT = '공#145 발송 다음날(D+1)~+5일 안에 후원중단이 있는 발송 대상 수(중복 포함). F(가산). 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.D5_STOP_CNT_SUM AS SUM(fse.D5_STOP_CNT)
      WITH SYNONYMS ('발송후 5일 중단(건)') COMMENT = '공#146 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_STOP_DISTINCT_MEMBERS AS COUNT(DISTINCT CASE WHEN fse.D5_STOP_MEMBERS > 0 THEN fse.MEMBER_DK END)
      WITH SYNONYMS ('발송후 5일 중단 고유회원수', '발송 후 5일 내 중단한 회원 수', 'D5 중단 회원수')
      COMMENT = '발송 다음날(D+1)~+5일 안에 후원중단이 있는 **고유 회원수(명)**. D(distinct · 가산 금지). 「몇 명이 중단했나」 질문은 이 지표, 발송 행 기준 중복 포함 수는 D5_STOP_MEMBERS_SUM. 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.SERVICE_MEMBERS_SUM AS SUM(fse.SERVICE_MEMBERS)
      WITH SYNONYMS ('서비스(명)', '회원서비스 발송(명)') COMMENT = '공#160 발송구분(대) 「회원서비스」 발송 대상 수(발송 행 기준 · 중복 포함). 고유 회원수가 필요하면 DISTINCT_SEND_MEMBERS 에 같은 조건을 건다. ⚠️ 발송구분이 없는 발송은 포함되지 않는다.',
    fse.SERVICE_CNT_SUM AS SUM(fse.SERVICE_CNT)
      WITH SYNONYMS ('서비스(건)') COMMENT = '공#161 「회원서비스」 발송 대상 회원의 활동(건) 합(약정금액 ÷ 10,000). F(가산).',
    fse.TOTAL_OPEN_MEMBERS AS SUM(fse.OPEN_MEMBERS)
      WITH SYNONYMS ('오픈수', '오픈(명)', '링크 클릭수', '문자 클릭수', '클릭(명)')
      COMMENT = '문자 오픈 수 = **링크 클릭**(현업 회신 44). 발송 행별 0/1 플래그 합이라 중복 포함이다(고유 회원은 DISTINCT_SEND_MEMBERS 에 조건을 건다). 🔴 **문자(SND) 채널에만 값이 있다** — 다른 채널은 오픈 원천이 없어 NULL 이다(0 이 아니다) ⇒ 오픈율 분모는 SND 발송으로만 잡고 CHANNEL=''SND'' 를 반드시 건다. F(가산).',
    fse.OPEN_RATE_SND AS SUM(fse.OPEN_MEMBERS) / NULLIF(SUM(CASE WHEN fse.OPEN_MEMBERS IS NOT NULL THEN fse.SEND_MEMBERS END), 0) * 100
      WITH SYNONYMS ('오픈율', '클릭률', '링크 클릭률', '문자 오픈율', '신규32')
      COMMENT = '문자 오픈율(%) = 링크 클릭 ÷ 오픈 기록이 있는 발송(SND) ×100(현업 회신 44). 비율(N · 재집계 금지). 🔴 SND 전용 — 다른 채널 발송은 분모에서 빠진다(오픈 원천 부재).',
    --  [O237] 신규 #44·#49·#34 서비스별 참여율·증액율(잠정 · 분모 = 발송 행 · 현업 확인 대상)
    fse.D5_LETTER_RATE AS SUM(fse.D5_LETTER_PART_MEMBERS) / NULLIF(SUM(fse.SEND_MEMBERS), 0) * 100
      WITH SYNONYMS ('서비스별 서신 참여율(%)', '서신 참여율', '신규44')
      COMMENT = '신규 #44 서비스별 서신 참여율(%) 잠정 = 발송 후 D+1~D+5 서신 참여(D5_LETTER_PART_MEMBERS) ÷ 발송(SEND_MEMBERS) ×100. 비율(N · 재집계 금지). 🔴 분모 = 발송 행(중복 포함) — 사전 분모 「해당 서비스 참여회원」을 발송 대상으로 해석했다(현업 확인 대상) ⇒ 답변에 이 해석을 밝힌다. 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.D5_GIFT_RATE AS SUM(fse.D5_GIFT_PART_MEMBERS) / NULLIF(SUM(fse.SEND_MEMBERS), 0) * 100
      WITH SYNONYMS ('서비스별 선물금 참여율(%)', '선물금 참여율', '신규49')
      COMMENT = '신규 #49 서비스별 선물금 참여율(%) 잠정 = 발송 후 D+1~D+5 선물금 참여 ÷ 발송 ×100. 비율(N). 🔴 분모 해석·시간 창 주의는 D5_LETTER_RATE 와 같다 · 선물금 원천에 접수일이 없어 선물금 발송일로 매칭한다.',
    fse.D5_INCREASE_RATE AS SUM(fse.D5_INCREASE_PART_MEMBERS) / NULLIF(SUM(fse.SEND_MEMBERS), 0) * 100
      WITH SYNONYMS ('서비스별 증액율(%)', '서비스 증액율', '신규34')
      COMMENT = '신규 #34 서비스별 증액율(%) 잠정 = 발송 후 D+1~D+5 증액 개발 매칭 ÷ 발송 ×100. 비율(N). 🔴 사전 분모는 「발송 성공 회원」이나 성공 판정이 알림톡(SEND_STATUS_NAME)만 가능해 전체 발송을 분모로 쓴다 — 답변에 이 차이를 밝힌다(현업 확인 대상).',
    --  [2026-10-16 O237-C] 신규 #33 클릭대비 전환율 — 5일·30일 두 창(사용자 결정 · 잠정) · 고유 회원(명) 기준
    fse.CLICK_MEMBERS_DISTINCT AS COUNT(DISTINCT IFF(fse.OPEN_MEMBERS = 1, fse.MEMBER_DK, NULL))
      WITH SYNONYMS ('클릭 회원수', '서비스 클릭수(명)', '클릭(고유 명)')
      COMMENT = '링크 클릭(오픈) 고유 회원수(명). 문자(SND) 전용. N(비가산 · 그룹 합 금지 · 전체는 따로 COUNT DISTINCT).',
    fse.CLICK_DEV_D5_MEMBERS_DISTINCT AS COUNT(DISTINCT IFF(fse.CLICK_DEV_D5_MEMBERS = 1, fse.MEMBER_DK, NULL))
      WITH SYNONYMS ('클릭 후 5일 개발회원', '5일 전환 회원수')
      COMMENT = '클릭 후 D+1~D+5 안에 인정 개발이 있는 고유 회원수(명) · 잠정. 처리통보성 제목 발송 제외.',
    fse.CLICK_DEV_D30_MEMBERS_DISTINCT AS COUNT(DISTINCT IFF(fse.CLICK_DEV_D30_MEMBERS = 1, fse.MEMBER_DK, NULL))
      WITH SYNONYMS ('클릭 후 30일 개발회원', '30일 전환 회원수')
      COMMENT = '클릭 후 D+1~D+30 안에 인정 개발이 있는 고유 회원수(명) · 잠정(5일 회원을 포함한다).',
    fse.CLICK_TO_DEV_RATE_D5 AS COUNT(DISTINCT IFF(fse.CLICK_DEV_D5_MEMBERS = 1, fse.MEMBER_DK, NULL)) / NULLIF(COUNT(DISTINCT IFF(fse.OPEN_MEMBERS = 1, fse.MEMBER_DK, NULL)), 0) * 100
      WITH SYNONYMS ('클릭대비 전환율', '클릭대비 전환율 5일', '신규33')
      COMMENT = '신규 #33 클릭대비 전환율(%) 5일 = 클릭 후 5일 내 개발회원(명) ÷ 클릭 회원(명) ×100 · 잠정. 🔴 답변은 5일·30일 두 값을 함께 낸다(사용자 결정) — CLICK_TO_DEV_RATE_D30 과 회원수 2종을 같이 보인다. 문자(SND) 클릭만 · 인과가 아니라 시간 창 매칭.',
    fse.CLICK_TO_DEV_RATE_D30 AS COUNT(DISTINCT IFF(fse.CLICK_DEV_D30_MEMBERS = 1, fse.MEMBER_DK, NULL)) / NULLIF(COUNT(DISTINCT IFF(fse.OPEN_MEMBERS = 1, fse.MEMBER_DK, NULL)), 0) * 100
      WITH SYNONYMS ('클릭대비 전환율 30일', '30일 클릭대비 전환율')
      COMMENT = '신규 #33 클릭대비 전환율(%) 30일 = 클릭 후 30일 내 개발회원(명) ÷ 클릭 회원(명) ×100 · 잠정. 5일 값과 함께 답한다.',
    --  [2026-10-28 O265] 알림톡 열람(대용) = GA 링크 유입 · 회원+기간 매칭(사용자 결정)
    fse.AT_GA_CLICK_MEMBERS_DISTINCT AS COUNT(DISTINCT IFF(fse.GA_CLICK_MEMBERS = 1, fse.MEMBER_DK, NULL))
      WITH SYNONYMS ('알림톡 오픈 회원수', '알림톡 열람 회원수', '알림톡 클릭 회원수', '알림톡 오픈(명)')
      COMMENT = '그 알림톡 열람(오픈) 고유 회원수(명) = 알림톡(MSG_AT + 문자 시스템 SND 알림톡) 수신 후 5일 안 카카오 경로로 **그 템플릿의 링크**를 클릭(GA memnum = 회원번호)한 회원(O265-C 재정의). 🔴 원천에 알림톡 오픈 기록이 없어 **GA 링크 클릭을 열람으로 대신한다** — 답변에 이 정의와 판정 근거(GA_CLICK_MAP_SRC)를 밝힌다. 템플릿 링크 매핑이 없는 알림톡·GA 적재 범위 밖 발송은 대상이 아니다(NULL). N(비가산).',
    fse.AT_GA_CLICK_RATE AS SUM(fse.GA_CLICK_MEMBERS) / NULLIF(COUNT(fse.GA_CLICK_MEMBERS), 0) * 100
      WITH SYNONYMS ('알림톡 오픈율', '알림톡 열람률', '알림톡 클릭률')
      COMMENT = '알림톡 열람률(%) = GA 링크 유입 (발송, 회원) ÷ GA 적재 범위 안 알림톡 (발송, 회원) ×100. 비율(N · 재집계 금지). 🔴 정의는 AT_GA_CLICK_MEMBERS_DISTINCT 와 같다 · 문자 오픈율(OPEN_RATE_SND)과 다른 원천이다 ⇒ 두 값을 한 비율로 합치지 마라.',
    --  [2026-10-28 O265-B-3] B 축 = 수신일~D+5 어떤 알림톡이라도 열람(현업 결정) · A(AT_GA_CLICK_MEMBERS_DISTINCT) ⊆ B
    fse.AT_ANY_GA_OPEN_MEMBERS_DISTINCT AS COUNT(DISTINCT IFF(fse.ANY_AT_GA_OPEN_MEMBERS = 1, fse.MEMBER_DK, NULL))
      WITH SYNONYMS ('알림톡 임의 열람 회원수', '어떤 알림톡이라도 열람한 회원수', '알림톡 아무거나 열람 회원수')
      COMMENT = '수신일~D+5 안에 어떤 알림톡이라도 열람(GA 링크 유입)한 고유 회원수(명) — 그 알림톡 외 다른 알림톡 열람도 포함한다. 거른 알림톡(예: 행운의 카드) 수신 행에서 세면 「그 알림톡 수신자 중 기간 내 어떤 알림톡이라도 연 회원」이 된다. 🔴 AT_GA_CLICK_MEMBERS_DISTINCT(그 알림톡 열람) ⊆ 이 값. N(비가산).',
    --  [2026-10-28 O265-C] 우선순위 ① — 질문에 템플릿·링크가 주어졌을 때 그 조건(CLICK_* 차원)으로 거른 클릭 회원수
    atclk.AT_LINK_CLICK_MEMBERS_DISTINCT AS COUNT(DISTINCT atclk.MEMBER_DK)
      WITH SYNONYMS ('지정 링크 클릭 회원수', '템플릿 링크 클릭 회원수', '해당 링크 열람 회원수')
      COMMENT = '알림톡 수신 후 D+5 안에 카카오 경로로 클릭한 고유 회원수(명) — 클릭 grain 표(atclk)에서 센다. 질문에 템플릿 ID·링크 경로·utm 캠페인이 주어지면 CLICK_TEMPLATE_ID·CLICK_LANDING_PATH·CLICK_UTM_CAMPAIGN 으로 걸러 이 지표를 쓴다(우선순위 ①). 조건 없이 쓰면 B 와 같은 집합이다. N(비가산).'
  )
  COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 캠페인 축 = 문자(SND) 발송 캠페인만 배선(원천 SND_MEMBER_LIST.CMPGN_CD) — 이메일·알림톡·우편은 원천에 캠페인 키가 없어 (미매핑)(구조적 부재) ⇒ 「캠페인별 발송」은 SND 기준임을 밝힌다]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 건수 vs 회원수: 발송 건수는 TOTAL_SEND_MEMBERS, 수신 회원수(명)는 DISTINCT_SEND_MEMBERS (distinct) 사용. (2) 상태 라벨 분기: 발송상태 질의는 SEND_STATUS_NAME(시스템 상태) 또는 SEND_RESULT_NAME(통신사 도달결과)을 사용하며 두 축을 혼합 합산하지 않음. (3) 채널 동반 필터: SEND_STATUS 는 채널별 코드체계가 상이하므로 CHANNEL 조건을 동반할 것. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 연·월 평면 GROUP BY 로 반환(합계 행 없음). (5) 교차 불가: 발송 앵커 개발실적/중단 결합 요청은 배분 규칙 부재로 SQL 생성 불가 사유 안내. 단 정본 「발송(+5일차)」 지표(D5_* metric: 서신·선물금·증액·중단)는 정의된 시간창 매칭이므로 그 metric 으로 답한다(인과가 아니라 D+1~D+5 창 매칭이며 발송 당일은 처리 통보 역인과 때문에 제외됨을 밝힌다 · DEC-33). 🆕 [O237-C] 「클릭대비 전환율」(신규 #33)도 정의된 시간창 매칭이다 — CLICK_TO_DEV_RATE_D5·CLICK_TO_DEV_RATE_D30 과 회원수(CLICK_MEMBERS_DISTINCT·CLICK_DEV_D5/D30_MEMBERS_DISTINCT)를 **함께** 내고 「클릭일 기준 D+1~5 · D+1~30 · 잠정」을 밝힌다.
  🆕 [O241] 「선물금참여(원)」(공91)은 추천안 A/B 병기 대상이다 — 이 SV 는 B(발송 매칭 선물금 = D5_GIFT_AMT)만 낸다. A(결연활동 전체 선물금)는 SV_RELATION_ACTIVITY 소관이므로 이 SV 에서 다른 팩트와 결합하지 않는다.
  🆕 [O265 발송구분·알림톡] (가) 발송구분(대)(중)(소) = req.SEND_GBN_TOP_NM·SEND_GBN_MID_NM·SEND_GBN_BOT_NM 은 문자·알림톡·이메일 모두 값이 있다 — 「문자에만 있다」고 답하지 않는다 · 채널 조건 없이 세 채널을 함께 거르고 결과에 채널(SEND_TYPE)을 함께 보인다. (나) 「알림톡」은 채널이 아니라 req.SEND_FORMAT_NAME = ''알림톡'' 으로 거른다(문자 시스템 SND 도 알림톡을 보낸다). (다) 「알림톡을 오픈(열람·클릭)한 회원」은 fse.GA_CLICK_MEMBERS = 1 로 거르고 답변에 「원천에 알림톡 오픈 기록이 없어 수신 후 5일 안 카카오 경로 홈페이지 유입(GA)으로 판정」을 밝힌다 · 이 값은 MSG_AT 과 문자 시스템(SND) 알림톡 모두에 있다 · fse.OPEN_MEMBERS(문자 링크 클릭)와 합치지 않는다. (라) 오픈 회원 수가 30명 미만이면 특성·전략을 일반화하지 말고 표본 수를 먼저 밝힌 뒤 수신 전체·미오픈 집단과 비교해 보인다. (마) 「오픈·열람·클릭」 조건이 붙은 서비스(행운의 카드 등) 질문은 이 SV 소관이다 — 서비스 수신 코호트 SV 에는 오픈 축이 없다.
  🆕 [O265-B-3 알림톡 열람 2축 · 현업 결정 2026-10-28] (바) 「○○ 알림톡을 열람(오픈)한 회원」 질문은 **두 결과를 나란히** 낸다 — A = 그 알림톡 열람(fse.GA_CLICK_MEMBERS = 1 · 지표 AT_GA_CLICK_MEMBERS_DISTINCT) · B = 그 알림톡 수신자 중 수신일~D+5 에 어떤 알림톡이라도 열람(fse.ANY_AT_GA_OPEN_MEMBERS = 1 · 지표 AT_ANY_GA_OPEN_MEMBERS_DISTINCT). 두 축 모두 대상 알림톡 수신 행(req.SEND_FORMAT_NAME = ''알림톡'' + 제목·발송구분 조건)에서 거른다. (사) 「열람 후 D+5 안 중단」 같은 후속 사건은 같은 행의 D5_STOP_MEMBERS = 1 로 A·B 각각 따로 세고, 표·속성 분석도 A·B 를 분리해 보인다(합치지 않는다 · A ⊆ B). 답변에 「열람 = GA 링크 클릭(카카오 경로) · B 기간 = 수신일~D+5」를 밝힌다.
  🆕 [O265-C A 판정 우선순위 · 사용자 결정 2026-10-28] (아) 「그 알림톡을 열람」(A)의 근거는 ① 질문에 템플릿 ID·링크(경로·utm 캠페인)가 있으면 그 조건 > ② 고정 매핑표 > ③ 추정표 순이다. ① 이면 atclk 표에서 atclk.CLICK_TEMPLATE_ID·CLICK_LANDING_PATH(ILIKE)·CLICK_UTM_CAMPAIGN 으로 거르고 지표 AT_LINK_CLICK_MEMBERS_DISTINCT 로 센다 — fse.GA_CLICK_MEMBERS 를 쓰지 않는다. 🆕 [O268] ①-a 템플릿 ID 만 있으면 atclk.CLICK_MAP_MATCHED = 1 을 반드시 함께 건다(= 그 템플릿의 링크 클릭 · 이 조건이 없으면 「그 템플릿을 받은 회원의 모든 클릭」이 되어 B 와 섞인다) · ①-b 링크(경로·utm)만 있으면 그 링크 조건으로만 거르고 「같은 링크를 쓴 다른 템플릿 수신자의 클릭도 포함」이라고 밝힌다 · ①-c 둘 다 있으면 두 조건을 함께 건다. ①이 없으면 fse.GA_CLICK_MEMBERS(②③ 적용 결과)를 쓰고 판정 근거 fse.GA_CLICK_MAP_SRC 별 회원수를 함께 보인다 · ''INFER'' 는 「추정 매핑」, ''NONE'' 은 「링크 매핑이 없어 판정 불가」라고 밝힌다(0 으로 세지 않는다). (자) ① 결과와 중단 같은 후속 사건을 함께 물으면 atclk 결과 회원·발송요청(SEND_REQUEST_SK)으로 fse 행을 좁혀 D5_STOP_MEMBERS 를 센다.
  (6) 판정 라벨 [배분규칙필요]: 발송 grain 으로 회비·회원월 measure(개발/중단 건·명, 납입방식)를 요구받으면 도구를 억지로 고르지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다 — SQL 을 만들지 않으며 「데이터가 없다」로도 답하지 않는다(데이터는 있고 귀속 규칙이 없다). (7) 판정 라벨 [앵커_경합]: 개발실적보고 3-x 섹션은 이 뷰와 다른 팩트가 경합하므로 하나를 골라 섹션 전체를 답하지 않는다 — 각 팩트를 따로 호출해 표를 분리하고 표마다 grain 을 밝힌다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라 서브쿼리·상관 서브쿼리·ORDER BY … LIMIT/OFFSET 서브쿼리로 기준 시점을 구하지 않는다. CTE 안에서 그 CTE 의 FROM 에 없는 별칭을 쓰지 않는다. 날짜 조건은 DIMENSIONS 에 선언된 날짜 차원(date.FULL_DATE · 월키 MONTH_KEY)으로만 걸고 팩트에 없는 날짜 컬럼을 팩트 별칭에 붙이지 않는다. metric 이름을 컬럼처럼 참조하지 말고 metric 정의식(SUM(원천컬럼))으로 집계한다. ORDER BY 에는 SELECT 에서 정의한 별칭을 글자 그대로 쓴다. (🆕 O206 서비스명 매핑) 「○○서비스」처럼 서비스(카테고리) 이름으로 물으면, 이 SV 에는 원천 서비스 카테고리 축이 없으므로 fse.SEND_TITLE 부분일치로 매핑하고 답변에 「상위 카테고리 정의에 없어 발송 제목으로 매핑했다(매핑한 제목 패턴: …)」를 반드시 밝힌다. 선넘는좋은일 즉시·개별화 신규(사단)·행운의 카드·장기회원 서비스 4종의 수신 회원 분석은 서비스코드 기준 판정이 있는 서비스 수신 코호트 SV 소관이다. (🆕 O225-C 캠페인 축) 발송 캠페인별 질문은 campaign 차원으로 묶는다 — 캠페인코드는 문자(SND) 발송에만 있으므로 결과에 「(미매핑)」(이메일·알림톡·우편 + 코드 미기재 SND)을 그룹 행으로 함께 표시하고 「문자(SND) 발송 기준」이라고 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_monthly_send_members AS (
      QUESTION '월별 발송 대상 회원수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT YEAR AS "연도", MONTH AS "월", TOTAL_SEND_MEMBERS AS "발송 대상 회원수(명)" FROM (SELECT date.YEAR, date.MONTH, SUM(fse.SEND_MEMBERS) AS TOTAL_SEND_MEMBERS FROM fse LEFT JOIN date ON fse.DATE_SK = date.DATE_SK GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH) ORDER BY YEAR, MONTH'
    ),
    vqr_o191_last6m_d5 AS (
      QUESTION '최근 6개월 월별 발송 후 5일 내 증액·중단 매칭 회원수'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT YEAR AS "연도", MONTH AS "월", D5_INCREASE_MEMBERS AS "발송 후 5일 내 증액 회원수(명)", D5_STOP_MEMBERS_SUM AS "발송 후 5일 내 중단 회원수(명)" FROM (WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK) SELECT date.YEAR, date.MONTH, SUM(fse.D5_INCREASE_PART_MEMBERS) AS D5_INCREASE_MEMBERS, SUM(fse.D5_STOP_MEMBERS) AS D5_STOP_MEMBERS_SUM FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK CROSS JOIN mx WHERE date.FULL_DATE > DATEADD(MONTH, -6, mx.md) AND date.FULL_DATE <= mx.md GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH) ORDER BY YEAR, MONTH'
    ),
    vqr_o203_title_d5_stop AS (
      QUESTION '2025년 9월 행운의 카드 알림톡 발송 회원 중 발송 후 5일 내 중단한 회원 수'
      VERIFIED_BY '(DW = O203 · 기대 30명)'
      SQL 'SELECT D5_STOP_DISTINCT_MEMBERS AS "발송 후 5일 내 중단 회원수(명)", DISTINCT_SEND_MEMBERS AS "발송 회원수(명)" FROM (SELECT COUNT(DISTINCT CASE WHEN fse.D5_STOP_MEMBERS > 0 THEN fse.MEMBER_DK END) AS D5_STOP_DISTINCT_MEMBERS, COUNT(DISTINCT fse.MEMBER_DK) AS DISTINCT_SEND_MEMBERS FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK JOIN service ON fse.SERVICE_SK = service.SERVICE_SK WHERE fse.SEND_TITLE ILIKE ''%행운%카드%'' AND service.CHANNEL = ''MSG_AT'' AND date.YEAR = 2025 AND date.MONTH = 9)'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS TOTAL_SEND_MEMBERS)) AS sv_val,
       (SELECT SUM(SEND_MEMBERS) FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH)                                     AS fact_val;

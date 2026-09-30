-- ============================================================================
-- 05_4_SV_DDL_SERVICE.sql — Semantic View DDL 정본: SV_SERVICE
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_MESSAGE_DISPATCH
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송', '메시지 발송')
      COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 🔴🔴 **캠페인 축은 이 SV 에 없다** — 종전 문안이 grain 에 「캠페인」을 적었으나 캠페인 차원이 배선돼 있지 않고 base 의 캠페인 키도 전건 센티넬이다(원천 CRM_SEND* 에 캠페인 키가 부재 · 결측이 아니라 구조적 부재) ⇒ 「캠페인별 발송」 질문에는 **축 부재를 밝히고** 캠페인으로 분해하지 말 것]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].',
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
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.'
  )
  RELATIONSHIPS (
    fse_to_date    AS fse (DATE_SK)    REFERENCES date,
    fse_to_service AS fse (SERVICE_SK) REFERENCES service,
    fse_to_member  AS fse (MEMBER_DK)  REFERENCES member
  )
  DIMENSIONS (
    date.SEND_DATE  AS date.FULL_DATE  WITH SYNONYMS ('발송일', '일자', '날짜') COMMENT = '발송일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — SEND_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR   AS date.YEAR       WITH SYNONYMS ('연도', '년')     COMMENT = '연도',
    date.CAL_MONTH  AS date.MONTH      WITH SYNONYMS ('월')            COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    service.SUBTYPE AS service.SUBTYPE WITH SYNONYMS ('서비스유형', '발송소분류') COMMENT = '서비스 subtype. ⚠️ **라벨이 아니라 원천 숫자 코드**다 — 실제값 5종: ''0''·''1''·''2''·''3''·''(미매핑)'' + NULL. 🔴🔴 **CHANNEL 과 함께 보지 않으면 서로 다른 체계를 섞는다** — 이 컬럼도 `SEND_STATUS` 와 **같은 구조적 결함**이다: 채널별로 도메인이 다르다(EMAIL ''0''·''1''·''2''+NULL / MSG_AT ''0''·''1'' / PSTMTR ''1''·''2''·''3'' / SND 는 NULL). 같은 ''1'' 이 채널에 따라 다른 것을 뜻하므로 이 축 단독 그루핑·필터는 오답이다. 🔴 **라벨은 만들지 않았다 — 코드군을 특정할 수 없어서다**(채널별 도메인이 2~3종뿐이라 사전 후보가 과다하고, 의미가 맞는 그룹이 없다 · 등급 D). 의미를 창작하지 말고 **코드값 그대로 + 채널 동반**으로 제시하고 라벨 부재를 밝힌다(DEC-17-B · 현업 확인 = 문서20 §M-2)',
    service.CHANNEL AS service.CHANNEL WITH SYNONYMS ('채널', '발송채널') COMMENT = '발송 채널. 실제값 5종: ''MSG_AT''·''SND''·''EMAIL''·''PSTMTR''·''(미매핑)''. 🔴🔴 **위 5종 외의 값은 이 축에 존재하지 않는다** — 다른 값으로 필터하면 0행 무증상 오답이다(종전 COMMENT 가 실재하지 않는 값을 열거하고 있었다 · 경위는 원장 §O58-C). ⚠️ ''(미매핑)''은 원천 채널코드가 사전에 없는 행이다',
    fse.SEND_STATUS AS fse.SEND_STATUS WITH SYNONYMS ('발송상태코드') COMMENT = '발송 상태 **축A 원천 코드**(라벨 아님). 🔴🔴 **반드시 CHANNEL 과 함께 볼 것 — 채널마다 코드체계가 다르다.** BRONZE 원천 대조 결과 이 컬럼은 채널별로 **서로 다른 원천 컬럼**을 받는다: EMAIL 계열은 ''0''·''1'' · MSG_AT 계열은 ''2''·''3''·''4'' · SND 계열은 ''Y''·''N'' · PSTMTR 계열은 **원천에 결과코드 컬럼이 아예 없어 전건 NULL**(결측이 아니라 구조적 부재). 🔴 따라서 CHANNEL 없이 이 축만 그루핑하면 **서로 다른 체계를 한 표에 섞는다.** ✅ **사람이 읽는 라벨은 SEND_STATUS_NAME 축을 쓴다**(DEC-35 R1 — 현업은 코드를 모른다). 🟢 통신사 도달 결과는 **축B**(SEND_RESULT_CD·SEND_RESULT_GROUP·SEND_RESULT_NAME)가 따로 담으며 그쪽은 채널 간 conformed 다. 실제값 7종: ''0''·''1''·''2''·''3''·''4''·''N''·''Y'' + NULL',
    fse.SEND_STATUS_NAME AS fse.SEND_STATUS_NAME WITH SYNONYMS ('발송상태', '발송상태명') COMMENT = '발송 상태 **축A 라벨 — 현업 응답용 정본 축**이다(코드군 MS282 · 원천 교차로 의미 확정). 실제값 3종: ''발송완료''·''에러''·''예약취소'' + NULL. 🔴🔴 **NULL 은 결측이 아니다** — 라벨은 **MSG_AT 계열만** 채워진다: EMAIL·SND 는 코드값만 있고 **사전에 라벨 문자열이 없어 의도적 NULL** 이며(「성공/실패」는 원천 교차로 얻은 우리 해석이라 라벨로 창작하지 않는다 · 현업 확인 = 문서20 §M-4), PSTMTR 은 원천 자체가 없다. ⇒ 이 축으로 분해할 때는 **NULL 덩어리를 함께 밝히고 CHANNEL 을 동반**한다. 🔴 **성공/실패 판정은 MSG_AT 한정으로만 가능**하며 전 채널 성공률로 단정하지 말 것',
    fse.SEND_RESULT_CD AS fse.SEND_RESULT_CD WITH SYNONYMS ('통신사결과코드', '전송실패코드') COMMENT = '**축B 통신사 결과 코드 raw**(MSG_AT 전송실패코드 · SND 수신결과상태). 🟢 **축A 와 달리 conformed 다** — 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 코드체계가 유지된다. 라벨은 SEND_RESULT_NAME · 코드군은 SEND_RESULT_GROUP 을 쓴다(복합키 = 코드군 + 코드 · DEC-21 §11-C). ⚠️ 카디널리티가 커 열거하지 않는다 — 특정 사유를 찾으려면 라벨축이나 코드군축을 먼저 쓴다. ⚠️ **운영 코드사전에도 없는 통신사 코드가 실재**한다 ⇒ 그 행은 라벨 NULL 이며 센티넬을 창작하지 않는다(DEC-17-B · 사전 갱신 요청 = 문서20 §M-5)',
    fse.SEND_RESULT_GROUP AS fse.SEND_RESULT_GROUP WITH SYNONYMS ('통신사결과코드군', '메시지타입코드군') COMMENT = '**축B 코드군 ID** — 사전 MS283 이 정의한 4그룹이며 **메시지 타입 판별자**다. 실제값 4종: ''MS056''·''MS057''·''MS058''·''MS059'' + NULL(축B 코드가 없는 행). MS056=공통 · MS057=알림톡 · MS058=SMS · MS059=MMS. 🟢 이 값은 리터럴 지정이 아니라 **사전 조인 결과에서 얻는다**(코드값이 4그룹에 걸쳐 중복 없음). 🔴 축B 코드를 필터할 때 이 축을 동반하면 오조인이 구조로 차단된다',
    fse.SEND_RESULT_NAME AS fse.SEND_RESULT_NAME WITH SYNONYMS ('통신사결과', '전송실패사유', '발송결과사유') COMMENT = '**축B 라벨 — 통신사가 반환한 도달 결과 사유**(사전 MS056~MS059). ⚠️ 카디널리티가 커 열거하지 않는다 — 「전달」이 도달 성공이고 나머지는 실패 사유다(타임아웃·전화번호 오류·템플릿 없음 등). 🔴🔴 **축A(SEND_STATUS_NAME) 와 의미가 다르다** — 축A 는 **우리 발송 시스템의 상태**(발송완료/에러/예약취소), 축B 는 **통신사 도달 결과**다. 한 표에 섞거나 합산하지 말고 어느 축으로 답했는지 밝힌다. 🔴 코드는 있으나 **사전에 라벨이 없는 행은 NULL** 이다(DEC-17-B) — 도달률·실패율의 분모를 낼 때 그 덩어리를 함께 밝힌다(문서20 §M-5)',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다(경위는 원장 §O58-C). ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3'''
  )
  METRICS (
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송건', '발송 횟수')
      COMMENT = '발송 **건수** 합계. F(가산). 🔴**회원수가 아니다** — 같은 회원에게 여러 번 발송되면 그만큼 중복 계수된다. 회원 「명」 수를 묻는 질문(발송 회원수·수신 대상 몇 명)에는 이 metric 을 쓰지 말고 DISTINCT_SEND_MEMBERS 를 쓴다. ⚠️metric 명에 MEMBERS 가 들어간 것은 기저 컬럼명(SEND_MEMBERS) 을 따른 역사적 잔재이며 의미는 건수다.',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 회원수', '발송 고유회원수', '발송(명)', '발송명', '수신 대상 회원수', '수신자수', '몇 명에게 발송')
      COMMENT = '발송 대상 **고유 회원수(명)**. D(distinct) — 🔴가산 금지: 월별로 뽑아 합산하면 여러 달 수신한 회원이 중복된다. 기간을 바꾸면 반드시 재집계할 것. 정본 「발송(명)」이 이 metric 이다(발송 건수는 TOTAL_SEND_MEMBERS).',
    fse.D5_LETTER_MEMBERS AS SUM(fse.D5_LETTER_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 서신참여(명)', 'D5 서신참여') COMMENT = '공#139 발송 다음날(D+1)~+5일 안에 서신 접수가 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_LETTER_CNT AS SUM(fse.D5_LETTER_PART_CNT)
      WITH SYNONYMS ('발송후 5일 서신참여(건)') COMMENT = '공#140 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_GIFT_MEMBERS AS SUM(fse.D5_GIFT_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 선물금참여(명)', 'D5 선물금참여') COMMENT = '공#141 발송 다음날(D+1)~+5일 안에 선물금 참여가 있는 발송 대상 수(중복 포함). ⚠️ 선물금 원천에 접수일이 없어 선물금 발송일로 매칭한다. F(가산).',
    fse.D5_GIFT_CNT AS SUM(fse.D5_GIFT_PART_CNT)
      WITH SYNONYMS ('발송후 5일 선물금참여(건)') COMMENT = '공#142 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_INCREASE_MEMBERS AS SUM(fse.D5_INCREASE_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 증액참여(명)', 'D5 증액') COMMENT = '공#143 발송 다음날(D+1)~+5일 안에 증액 개발(MM015 ''2'')이 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_INCREASE_CNT AS SUM(fse.D5_INCREASE_PART_CNT)
      WITH SYNONYMS ('발송후 5일 증액참여(건)') COMMENT = '공#144 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_STOP_MEMBERS_SUM AS SUM(fse.D5_STOP_MEMBERS)
      WITH SYNONYMS ('발송후 5일 중단(명)', 'D5 중단') COMMENT = '공#145 발송 다음날(D+1)~+5일 안에 후원중단이 있는 발송 대상 수(중복 포함). F(가산). 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.D5_STOP_CNT_SUM AS SUM(fse.D5_STOP_CNT)
      WITH SYNONYMS ('발송후 5일 중단(건)') COMMENT = '공#146 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.SERVICE_MEMBERS_SUM AS SUM(fse.SERVICE_MEMBERS)
      WITH SYNONYMS ('서비스(명)', '회원서비스 발송(명)') COMMENT = '공#160 발송구분(대) 「회원서비스」 발송 대상 수(발송 행 기준 · 중복 포함). 고유 회원수가 필요하면 DISTINCT_SEND_MEMBERS 에 같은 조건을 건다. ⚠️ 발송구분이 없는 발송은 포함되지 않는다.',
    fse.SERVICE_CNT_SUM AS SUM(fse.SERVICE_CNT)
      WITH SYNONYMS ('서비스(건)') COMMENT = '공#161 「회원서비스」 발송 대상 회원의 활동(건) 합(약정금액 ÷ 10,000). F(가산).',
    fse.TOTAL_OPEN_MEMBERS AS SUM(fse.OPEN_MEMBERS)
      WITH SYNONYMS ('오픈수', '오픈(명)', '링크 클릭수', '문자 클릭수', '클릭(명)')
      COMMENT = '문자 오픈 수 = **링크 클릭**(현업 회신 44). 발송 행별 0/1 플래그 합이라 중복 포함이다(고유 회원은 DISTINCT_SEND_MEMBERS 에 조건을 건다). 🔴 **문자(SND) 채널에만 값이 있다** — 다른 채널은 오픈 원천이 없어 NULL 이다(0 이 아니다) ⇒ 오픈율 분모는 SND 발송으로만 잡고 CHANNEL=''SND'' 를 반드시 건다. F(가산).',
    fse.OPEN_RATE_SND AS SUM(fse.OPEN_MEMBERS) / NULLIF(SUM(CASE WHEN fse.OPEN_MEMBERS IS NOT NULL THEN fse.SEND_MEMBERS END), 0) * 100
      WITH SYNONYMS ('오픈율', '클릭률', '링크 클릭률', '문자 오픈율')
      COMMENT = '문자 오픈율(%) = 링크 클릭 ÷ 오픈 기록이 있는 발송(SND) ×100(현업 회신 44). 비율(N · 재집계 금지). 🔴 SND 전용 — 다른 채널 발송은 분모에서 빠진다(오픈 원천 부재).'
  )
  COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 🔴🔴 **캠페인 축은 이 SV 에 없다** — 종전 문안이 grain 에 「캠페인」을 적었으나 캠페인 차원이 배선돼 있지 않고 base 의 캠페인 키도 전건 센티넬이다(원천 CRM_SEND* 에 캠페인 키가 부재 · 결측이 아니라 구조적 부재) ⇒ 「캠페인별 발송」 질문에는 **축 부재를 밝히고** 캠페인으로 분해하지 말 것]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].'
  AI_SQL_GENERATION '핵심 규칙: (1) 건수 vs 회원수: 발송 건수는 TOTAL_SEND_MEMBERS, 수신 회원수(명)는 DISTINCT_SEND_MEMBERS (distinct) 사용. (2) 상태 라벨 분기: 발송상태 질의는 SEND_STATUS_NAME(시스템 상태) 또는 SEND_RESULT_NAME(통신사 도달결과)을 사용하며 두 축을 혼합 합산하지 않음. (3) 채널 동반 필터: SEND_STATUS 는 채널별 코드체계가 상이하므로 CHANNEL 조건을 동반할 것. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 교차 불가: 발송 앵커 개발실적/중단 결합 요청은 배분 규칙 부재로 SQL 생성 불가 사유 안내. 단 정본 「발송(+5일차)」 지표(D5_* metric: 서신·선물금·증액·중단)는 정의된 시간창 매칭이므로 그 metric 으로 답한다(인과가 아니라 D+1~D+5 창 매칭이며 발송 당일은 처리 통보 역인과 때문에 제외됨을 밝힌다 · DEC-33). (6) 판정 라벨 [배분규칙필요]: 발송 grain 으로 회비·회원월 measure(개발/중단 건·명, 납입방식)를 요구받으면 도구를 억지로 고르지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다 — SQL 을 만들지 않으며 「데이터가 없다」로도 답하지 않는다(데이터는 있고 귀속 규칙이 없다). (7) 판정 라벨 [앵커_경합]: 개발실적보고 3-x 섹션은 이 뷰와 다른 팩트가 경합하므로 하나를 골라 섹션 전체를 답하지 않는다 — 각 팩트를 따로 호출해 표를 분리하고 표마다 grain 을 밝힌다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라 서브쿼리·상관 서브쿼리·ORDER BY … LIMIT/OFFSET 서브쿼리로 기준 시점을 구하지 않는다. CTE 안에서 그 CTE 의 FROM 에 없는 별칭을 쓰지 않는다. 날짜 조건은 DIMENSIONS 에 선언된 날짜 차원(date.FULL_DATE · 월키 MONTH_KEY)으로만 걸고 팩트에 없는 날짜 컬럼을 팩트 별칭에 붙이지 않는다. metric 이름을 컬럼처럼 참조하지 말고 metric 정의식(SUM(원천컬럼))으로 집계한다. ORDER BY 에는 SELECT 에서 정의한 별칭을 글자 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_monthly_send_members AS (
      QUESTION '월별 발송 대상 회원수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT date.YEAR, date.MONTH, SUM(fse.SEND_MEMBERS) AS TOTAL_SEND_MEMBERS FROM fse LEFT JOIN date ON fse.DATE_SK = date.DATE_SK GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH'
    ),
    vqr_o191_last6m_d5 AS (
      QUESTION '최근 6개월 월별 발송 후 5일 내 증액·중단 매칭 회원수'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK) SELECT date.YEAR, date.MONTH, SUM(fse.D5_INCREASE_PART_MEMBERS) AS D5_INCREASE_MEMBERS, SUM(fse.D5_STOP_MEMBERS) AS D5_STOP_MEMBERS_SUM FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK CROSS JOIN mx WHERE date.FULL_DATE > DATEADD(MONTH, -6, mx.md) AND date.FULL_DATE <= mx.md GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH'
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

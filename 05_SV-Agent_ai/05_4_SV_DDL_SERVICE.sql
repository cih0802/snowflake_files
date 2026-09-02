-- GN_DW 3단계: Semantic View DDL 정본 — SV_SERVICE (서비스·발송)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_SERVICE** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
--
--   🔴 **파일 규약·선행 조건·정본 근거의 정본 = `05_0_SV_DDL.sql` §공통 규약** (2026-08-10 O55 DUP-1).
--      독립 실행 · 파일 간 순서 무관 · 재실행 반영 · `CREATE OR ALTER`(GRANT·소유권 보존) ·
--      분할 이력(O37) · 선행 조건은 `dbt build` **하나** · 실행 역할 `GN_DW_ADMIN`.
--      ⛔ 이 항목들을 이 파일에 다시 복제하지 말 것 — 그것이 P140(9중 중복)의 원인이었다.
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`GOLD.DIM_MONTH` · 회원속성→`GOLD.DIM_MEMBER_CURRENT` ·
--                광고팩트→`GOLD.WIDE_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
--                🔴 [2026-08-10 O54·O55] SERVING helper 3종 → GOLD 재배선 완료 후 **물리 DROP 완료**(DEC-34 §0.8-D).
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: `MEMBER_DK`=VARCHAR(캐스팅 금지) · `MONTH_KEY`/`DATE_SK`/`*_SK`=NUMBER.
--   PRIMARY KEY: 실측 유일한 것만 선언. 비유일 grain 은 PK 미선언.
--   비활성 지표: 원천 미적재분은 SV 에서 아예 제외한다(빈 metric 이 0/NULL 을 사실처럼 반환).
--   COMMENT 규약: 🔴 **수치를 넣지 않는다**(Agent 가 COMMENT 를 근거로 인용 → 적재량 변하면 거짓이 된다) ·
--                `[원천]` 절은 테이블·컬럼 이름만 · 저카디널리티 코드 차원은 **실제 코드값을 열거**.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   3. SV_SERVICE (회원 Agent) — base FSE(일×회원×서비스×캠페인)
      활성: 발송수 총량·고유회원수 · 서비스구분(A3 SERVICE_SK)·발송상태
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_SERVICE_EVENT
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송')
      COMMENT = '서비스 발송 팩트. ⚠(DATE_SK,MEMBER_DK,SERVICE_SK) 실측 비유일 → PK 미선언(기저 FACT·집계 무해). [원천] 시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM: 발송마스터 TM_MS_EMAIL_SNDNG·TM_MS_MSG_AT_SNDNG·TM_MS_PSTMTR_SNDNG · 발송상세 TD_MS_EMAIL_SNDNG_DTLS·TD_MS_MSG_AT_SNDNG_DTLS·TD_MS_PSTMTR_SNDNG_DTL(MBER_NO·SNDNG_RST_CD) · 성과 TD_MS_*_LQY_SNDNG(성공/실패, 현재 미적재) · SILVER=CRM_SEND_REQUEST·CRM_SEND_MEMBER·CRM_SEND_RESULT.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK). 미매칭=Unknown(SK=0). [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST(SEND_GBN_TOP/MID/BOT 대·중·소분류 코드) · SILVER=CRM_SEND_REQUEST.',
    member AS GN_DW.GOLD.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fse_to_date    AS fse (DATE_SK)    REFERENCES date,
    fse_to_service AS fse (SERVICE_SK) REFERENCES service,
    fse_to_member  AS fse (MEMBER_DK)  REFERENCES member
  )
  DIMENSIONS (
    date.SEND_DATE  AS date.FULL_DATE  WITH SYNONYMS ('발송일', '일자') COMMENT = '발송일',
    date.CAL_YEAR   AS date.YEAR       WITH SYNONYMS ('연도', '년')     COMMENT = '연도',
    date.CAL_MONTH  AS date.MONTH      WITH SYNONYMS ('월')            COMMENT = '월(1~12)',
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
    -- [2026-08-05 O39] 🔴 synonym '발송 회원수' 를 이 metric 에서 **제거**하고 아래 DISTINCT 로 옮겼다.
    --   기저 컬럼 `FSE.SEND_MEMBERS` 는 이름에 MEMBERS 가 붙었지만 실측 **전 행이 1 인 발송 플래그**이고
    --   SUM 은 행수(=발송 건수)와 같다. 실측: SUM=38,470,780 vs 고유회원 1,031,971 = **37.3배**.
    --   종전엔 「발송 회원수」 질문이 이 metric 으로 라우팅돼 37배 과대값을 답할 수 있었다(무증상 오답).
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송건', '발송 횟수')
      COMMENT = '발송 **건수** 합계. F(가산). 🔴**회원수가 아니다** — 같은 회원에게 여러 번 발송되면 그만큼 중복 계수된다. 회원 「명」 수를 묻는 질문(발송 회원수·수신 대상 몇 명)에는 이 metric 을 쓰지 말고 DISTINCT_SEND_MEMBERS 를 쓴다. ⚠️metric 명에 MEMBERS 가 들어간 것은 기저 컬럼명(SEND_MEMBERS) 을 따른 역사적 잔재이며 의미는 건수다.',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 회원수', '발송 고유회원수', '발송(명)', '발송명', '수신 대상 회원수', '수신자수', '몇 명에게 발송')
      COMMENT = '발송 대상 **고유 회원수(명)**. D(distinct) — 🔴가산 금지: 월별로 뽑아 합산하면 여러 달 수신한 회원이 중복된다. 기간을 바꾸면 반드시 재집계할 것. 정본 「발송(명)」이 이 metric 이다(발송 건수는 TOTAL_SEND_MEMBERS).'
  )
  COMMENT = 'Phase-1 서비스 발송 SV (base: GOLD.FACT_SERVICE_EVENT, grain: 발송 1행). CRM UMS 발송 건수(TOTAL_SEND_MEMBERS), 수신 고유 회원수(DISTINCT_SEND_MEMBERS), 발송상태(축A: SEND_STATUS_NAME) 및 통신사 도달결과(축B: SEND_RESULT_NAME) 뷰. ⚠️ 발송 건수(TOTAL_SEND_MEMBERS)와 고유 회원수(DISTINCT_SEND_MEMBERS)를 혼동하지 말 것. 발송 앵커 개발/중단 결합 질의는 배분규칙 부재로 생성 불가.'
  AI_SQL_GENERATION '핵심 규칙: (1) 건수 vs 회원수: 발송 건수는 TOTAL_SEND_MEMBERS, 수신 회원수(명)는 DISTINCT_SEND_MEMBERS (distinct) 사용. (2) 상태 라벨 분기: 발송상태 질의는 SEND_STATUS_NAME(시스템 상태) 또는 SEND_RESULT_NAME(통신사 도달결과)을 사용하며 두 축을 혼합 합산하지 않음. (3) 채널 동반 필터: SEND_STATUS 는 채널별 코드체계가 상이하므로 CHANNEL 조건을 동반할 것. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 교차 불가: 발송 앵커 개발실적/중단 결합 요청은 배분 규칙 부재로 SQL 생성 불가 사유 안내.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →
         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로
         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 검증 (배포 직후 실행) — 04 §0.1 DoD
      원리: `SEMANTIC_VIEW(...)` 집계 == 단일 FACT 직접 SUM 일치 → 조인 fan-out 0 검증.
      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         "sv_val == fact_val" 같은 관계식이 참인지만 본다. 기대 절대값을 문서에 박으면
         재현 시 전항 오탐이 된다(04 §6.9-(8)).
      ▶ SV 9종 전체를 아우르는 배포 검증(소유권·GRANT·구조 대조·base 스키마) = `05_0_SV_DDL.sql`
   ===================================================================================== */
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- (8-2) SV_SERVICE 발송수 총합 == FSE 직접 SUM (서비스 조인 fan-out 0)
SELECT (SELECT TOTAL_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS TOTAL_SEND_MEMBERS)) AS sv_val,
       (SELECT SUM(SEND_MEMBERS) FROM GN_DW.GOLD.FACT_SERVICE_EVENT)                                       AS fact_val;
--   판정: sv_val == fact_val

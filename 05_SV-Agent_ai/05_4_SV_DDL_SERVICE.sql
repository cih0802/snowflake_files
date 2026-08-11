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
    service.SUBTYPE AS service.SUBTYPE WITH SYNONYMS ('서비스유형', '발송소분류') COMMENT = '서비스 subtype. ⚠️ **라벨이 아니라 원천 숫자 코드**다 — 실제값: ''0''·''1''·''2''·''3'' + ''(미매핑)'' + NULL. 🔴 라벨 사전이 아직 배선되지 않았으므로 이 축으로 그루핑하면 사람이 읽을 수 없는 값이 나온다 — 의미를 창작하지 말고 코드값 그대로 제시하고 라벨 미배선을 밝힌다(O58-C 등재)',
    service.CHANNEL AS service.CHANNEL WITH SYNONYMS ('채널', '발송채널') COMMENT = '발송 채널. 실제값 5종: ''MSG_AT''·''SND''·''EMAIL''·''PSTMTR''·''(미매핑)''. 🔴🔴 **위 5종 외의 값은 이 축에 존재하지 않는다** — 다른 값으로 필터하면 0행 무증상 오답이다(종전 COMMENT 가 실재하지 않는 값을 열거하고 있었다 · 경위는 원장 §O58-C). ⚠️ ''(미매핑)''은 원천 채널코드가 사전에 없는 행이다',
    fse.SEND_STATUS AS fse.SEND_STATUS WITH SYNONYMS ('발송상태') COMMENT = '발송 상태 원천값. 🔴🔴 **반드시 CHANNEL 과 함께 볼 것 — 채널마다 코드체계가 다르다.** BRONZE 원천 대조 결과 이 컬럼은 채널별로 **서로 다른 원천 컬럼**을 받는다: EMAIL 계열은 ''0''·''1'' · MSG_AT 계열은 ''2''·''3''·''4'' · SND 계열은 ''Y''·''N'' · PSTMTR 계열은 **원천에 결과코드 컬럼이 아예 없어 전건 NULL**(결측이 아니라 구조적 부재). 🔴 따라서 CHANNEL 없이 이 축만 그루핑하면 **서로 다른 체계를 한 표에 섞는다.** 🔴 **라벨 미배선 상태다** — 코드그룹이 확정되지 않아 성공/실패 판정에 쓸 수 없다(값이 작은 숫자 집합이라 사전의 여러 그룹에 동시 포함돼 그룹 식별이 되지 않는다). 성공률·실패율을 묻는 질문에는 **산출 불가**로 답하고 추정하지 말 것. 발송 규모는 이 축 없이 measure 로 답한다. 실제값 7종: ''0''·''1''·''2''·''3''·''4''·''N''·''Y'' + NULL',
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
  COMMENT = 'Phase-1 서비스 발송 SV(base FSE). [원천 요약] 원천시스템=CRM(UMS 발송) · BRONZE=GN_DW.BRONZE_CRM(TM_MS_EMAIL/MSG_AT/PSTMTR_SNDNG + TD_MS_*_SNDNG_DTLS + SND_REQ_MST) → SILVER(CRM_SEND_*) → GOLD(FSE). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 발송수·고유 발송회원수, 서비스구분/발송상태/발송일별. 시간=전체가능. 비활성(적재 대기): 수신/성공/실패/오픈, 서신/선물금/증액 참여·+5일 코호트(신31~53), 캠페인별.'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(채널·서비스유형·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


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

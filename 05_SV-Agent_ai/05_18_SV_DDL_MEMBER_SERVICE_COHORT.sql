-- ============================================================================
-- 05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql — Semantic View DDL 정본: SV_MEMBER_SERVICE_COHORT (🆕 O205 · 2차 Agent 개선 B)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `WIDE_MEMBER_SERVICE_COHORT`(사용자 실행 · R4-1). 뷰가 없으면 이 DDL 은 실패한다.
--   · 근거(2026-10-07 O205 실측 · 원천 직접 집계):
--     선넘는좋은일 상위캠페인 가입(2026-01~09) 4,174명 = 즉시 알림톡 수신 3,508 · 미수신 666
--     일반행사 참여 회원 = 수신 1,173(33.44%) · 미수신 265(39.79%) · D5 중단 매칭 수신 121
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT
  TABLES (
    svc AS GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT
      WITH SYNONYMS ('서비스 수신 코호트', '알림톡 수신 회원', '서비스 수신 회원', '수신 미수신 비교')
      COMMENT = '서비스 수신 코호트(grain = 회원 × 서비스그룹 × 수신연도 · 미수신은 연도 NULL 단일 행). 발송·획득 코호트·중단·행사참여를 회원 단위로 미리 결합했다. [원천: CRM(eCRM·UMS) → BRONZE_CRM(TM_MS_MSG_AT_SNDNG · TC_CMMN_DTL_CD 서비스코드 MS049 · TM_MS_AT_TMPLAT_MNG 템플릿) → GOLD.FACT_MESSAGE_DISPATCH·DIM_SEND_REQUEST·DIM_MEMBER_ACQUISITION·FACT_MEMBER_EVENT·FACT_EVENT_ATTENDANCE → GOLD.WIDE_MEMBER_SERVICE_COHORT]. 🟢 [O206] 서비스그룹 = 서비스코드(원천 서비스 카테고리) 우선 · 카테고리가 없으면 발송 제목 매핑.'
  )
  DIMENSIONS (
    svc.SERVICE_GROUP_CD AS svc.SERVICE_GROUP_CD WITH SYNONYMS ('서비스그룹코드') COMMENT = '서비스그룹 코드. 실제값 4종: ''SNG_INSTANT''(선넘는좋은일 신규 즉시 · 개별화서비스신규(사단)의 선넘는좋은일 즉시 알림톡)·''PERSONAL_NEW_SADAN''(개별화 신규 사단)·''LUCKY_CARD''(행운의 카드)·''LONGTERM_THANKS''(장기회원 서비스). 🔴 반드시 하나로 고정한다',
    svc.SERVICE_GROUP_NAME AS svc.SERVICE_GROUP_NAME WITH SYNONYMS ('서비스그룹', '서비스명', '알림톡 서비스') COMMENT = '서비스그룹 이름. 실제값 4종: ''선넘는좋은일 신규 즉시''·''개별화 신규(사단)''·''행운의 카드''·''장기회원 서비스''',
    svc.MATCH_BASIS AS svc.MATCH_BASIS WITH SYNONYMS ('매핑근거', '판정근거') COMMENT = '🆕 [O206] 그 수신 행이 서비스그룹에 든 근거. 실제값 3종: ''서비스코드''(원천 서비스 카테고리 · 발송코드 MS049 상위코드) · ''발송제목''(카테고리가 없어 제목으로 매핑) · ''서비스코드+발송제목''. 미수신 행은 NULL',
    svc.SVC_CATEGORY_NAMES AS svc.SVC_CATEGORY_NAMES WITH SYNONYMS ('원천 서비스분류', '서비스 카테고리') COMMENT = '🆕 [O206] 그 연도 수신 발송의 원천 서비스 카테고리명(발송코드 MS049 상위코드명 · 여러 개면 · 로 이음). 발송제목으로만 매핑된 행은 NULL',
    svc.CHRG_DEPT_NAMES AS svc.CHRG_DEPT_NAMES WITH SYNONYMS ('담당부서', '발송 담당부서', '서비스 실적부서') COMMENT = '🆕 [O206] 그 연도 수신 발송의 알림톡·메일 템플릿 담당부서명(여러 개면 · 로 이음). 🔴 처리자→부서 마스터는 원천에 없어 템플릿 담당부서로 대신한다 — 템플릿이 없는 발송은 NULL',
    svc.RECEIVED_SADAN_FLAG AS svc.RECEIVED_SADAN_FLAG WITH SYNONYMS ('사단 수신', '사단법인 발송 수신') COMMENT = '🆕 [O206] 그 연도 사단 법인 발송을 1회 이상 받았는가. 법인 = 서비스코드명의 (사단)/(사복)/(통합) → 없으면 템플릿 법인구분(CM019)',
    svc.RECEIVED_SABOK_FLAG AS svc.RECEIVED_SABOK_FLAG WITH SYNONYMS ('사복 수신', '사회복지법인 발송 수신') COMMENT = '🆕 [O206] 그 연도 사복 법인 발송 수신 여부(판정 규칙은 사단과 같다)',
    svc.RECEIVED_TONGHAP_FLAG AS svc.RECEIVED_TONGHAP_FLAG WITH SYNONYMS ('통합 수신', '통합 법인 발송 수신') COMMENT = '🆕 [O206] 그 연도 통합 법인 발송 수신 여부(판정 규칙은 사단과 같다)',
    svc.RECEIVE_YEAR AS svc.RECEIVE_YEAR WITH SYNONYMS ('수신연도', '발송연도') COMMENT = '수신연도. 미수신 행은 NULL',
    svc.RECEIVED_FLAG AS svc.RECEIVED_FLAG WITH SYNONYMS ('수신여부', '수신 여부', '받은 회원') COMMENT = 'TRUE = 그 그룹 수신 · FALSE = 획득 코호트 회원 중 미수신',
    svc.FIRST_RECEIVE_DATE AS svc.FIRST_RECEIVE_DATE WITH SYNONYMS ('첫 수신일', '수신일') COMMENT = '그 연도 첫 수신일',
    svc.D5_STOP_FLAG AS svc.D5_STOP_FLAG WITH SYNONYMS ('5일 내 중단', '발송 후 5일 이내 중단') COMMENT = '발송 다음날~+5일(D+1~D+5) 중단 매칭 여부. 🔴 인과가 아니라 시간창 매칭',
    svc.D5_INCREASE_FLAG AS svc.D5_INCREASE_FLAG WITH SYNONYMS ('5일 내 증액') COMMENT = 'D+1~D+5 증액 매칭 여부. 🔴 시간창 매칭',
    svc.D5_STOP_REASON AS svc.D5_STOP_REASON WITH SYNONYMS ('중단사유') COMMENT = 'D+1~D+5 첫 중단 사건의 중단사유',
    svc.D5_STOP_CHANNEL AS svc.D5_STOP_CHANNEL WITH SYNONYMS ('중단경로') COMMENT = 'D+1~D+5 첫 중단 사건의 중단경로',
    svc.D5_STOP_SPONSORSHIP AS svc.D5_STOP_SPONSORSHIP WITH SYNONYMS ('중단 후원사업', '후원사업') COMMENT = 'D+1~D+5 첫 중단 사건이 끊은 후원사업',
    svc.ACQ_DATE AS svc.ACQ_DATE WITH SYNONYMS ('가입일', '획득일') COMMENT = '획득(가입) 일자 — 「○월부터 ○월까지 가입한 회원」은 이 축으로 거른다',
    svc.ACQ_YEAR AS svc.ACQ_YEAR WITH SYNONYMS ('가입연도') COMMENT = '획득 연도',
    svc.ACQ_MONTH_KEY AS svc.ACQ_MONTH_KEY WITH SYNONYMS ('가입연월', '가입월') COMMENT = '🆕 [O206] 획득 연월(YYYYMM 정수) — 대조군 후보 「같은 가입월 미수신 회원」을 만들 때 고정한다',
    svc.ACQ_CAMPAIGN_NAME AS svc.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('가입캠페인', '캠페인명') COMMENT = '획득 캠페인명',
    svc.ACQ_PARENT_CAMPAIGN_NAME AS svc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '가입 상위캠페인') COMMENT = '획득 상위캠페인명. 🔴 「선넘는좋은일 캠페인으로 가입」은 ILIKE ''%선넘는좋은일%'' 로 이 축을 거른다(캠페인명에는 없다)',
    svc.ACQ_CAMPAIGN_TYPE AS svc.ACQ_CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '주요캠페인') COMMENT = '획득 캠페인카테고리',
    svc.ACQ_INFLOW_PATH AS svc.ACQ_INFLOW_PATH WITH SYNONYMS ('개발인입경로', '인입경로') COMMENT = '획득 개발인입경로',
    svc.ACQ_CPR_DIV_NM AS svc.ACQ_CPR_DIV_NM WITH SYNONYMS ('가입 법인구분', '획득 법인구분') COMMENT = '획득 세부캠페인 법인구분(통합/사단/사복). 🔴 발송(서비스) 법인이 아니다 — 서비스 법인은 RECEIVED_SADAN_FLAG·RECEIVED_SABOK_FLAG·RECEIVED_TONGHAP_FLAG',
    svc.ACQ_SPONSORSHIP_NAME AS svc.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('가입 후원사업', '획득 후원사업') COMMENT = '획득 후원사업',
    svc.ACQ_AGE_BAND AS svc.ACQ_AGE_BAND WITH SYNONYMS ('연령대') COMMENT = '획득 시점 연령대 — 현재 나이가 아니다',
    svc.ACQ_REGION AS svc.ACQ_REGION WITH SYNONYMS ('지역') COMMENT = '획득 시점 지역 — 현재 거주지가 아니다',
    svc.ACQ_GENDER AS svc.ACQ_GENDER WITH SYNONYMS ('성별') COMMENT = '획득 시점 성별',
    svc.EVER_STOPPED_FLAG AS svc.EVER_STOPPED_FLAG WITH SYNONYMS ('중단 이력') COMMENT = '최초 중단 이력 여부'
  )
  METRICS (
    svc.MEMBER_COUNT AS COUNT(DISTINCT svc.MEMBER_DK)
      WITH SYNONYMS ('회원수', '명')
      COMMENT = '고유 회원수(명). 🔴 서비스그룹 하나로 고정한 상태에서 쓴다.',
    svc.GENERAL_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('일반행사 참여 회원수', '이벤트 전체 참여 회원수')
      COMMENT = '일반행사(EVENT 원천 · 온라인·앱전용·회지·리플렛·오프라인 전 구분) 참여 기록이 있는 고유 회원수.',
    svc.GENERAL_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('일반행사 참여율', '이벤트 전체 참여율')
      COMMENT = '일반행사 참여율(%) = 참여 회원 ÷ 회원. N(비가산).',
    svc.CAMPAIGN_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('캠페인행사 참여 회원수')
      COMMENT = '캠페인행사(CRMN 원천 · 전 행사구분) 참여 기록이 있는 고유 회원수.',
    svc.CAMPAIGN_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('캠페인행사 참여율')
      COMMENT = '캠페인행사 참여율(%). N(비가산).',
    svc.CULTURE_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.CULTURE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('문화이벤트 참여 회원수', '문화서비스 참여 회원수')
      COMMENT = '🆕 [O206] 캠페인행사 중 원천 행사구분(MS002)이 문화서비스·문화서비스_전시·서적·공연인 행사 참여 고유 회원수. 🔴 「문화이벤트」라는 이름의 원천 코드는 없다 — 유사 값(문화서비스 계열)으로 매핑했음을 답변에 밝힌다.',
    svc.CULTURE_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.CULTURE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('문화이벤트 참여율', '문화서비스 참여율')
      COMMENT = '🆕 [O206] 문화서비스 계열 캠페인행사 참여율(%). N(비가산).',
    svc.ONLINE_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.ONLINE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('온라인 이벤트 참여 회원수')
      COMMENT = '🆕 [O206] 일반행사 중 원천 이벤트구분(MS286)이 온라인(100)인 이벤트 참여 고유 회원수. 🔴 「온라인 이벤트」 = 원천 구분 「온라인」으로 매핑했다(앱전용·회지·리플렛·오프라인은 제외).',
    svc.ONLINE_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.ONLINE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('온라인 이벤트 참여율')
      COMMENT = '🆕 [O206] 온라인 구분 일반행사 참여율(%). N(비가산).',
    svc.AVG_GENERAL_EVENT_PART_ROWS AS AVG(svc.GENERAL_EVENT_PART_ROWS)
      WITH SYNONYMS ('평균 이벤트 참여횟수', '1인당 참여횟수')
      COMMENT = '행당 평균 일반행사 참여 기록 수. 🔴 수신연도를 고정한 상태에서 쓴다(연도별 행 중복).',
    svc.AVG_GENERAL_EVENT_PART_ROWS_AFTER AS AVG(svc.GENERAL_EVENT_PART_ROWS_AFTER)
      WITH SYNONYMS ('수신 후 평균 참여횟수')
      COMMENT = '첫 수신일 이후 평균 일반행사 참여 기록 수(수신 행만 · 미수신은 NULL 이라 제외된다).',
    svc.D5_STOP_MEMBERS AS COUNT(DISTINCT IFF(svc.D5_STOP_FLAG, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('5일 내 중단 회원수')
      COMMENT = 'D+1~D+5 중단 매칭 고유 회원수(시간창 매칭 · 인과 아님).',
    svc.AVG_TENURE_DAYS AS AVG(svc.TENURE_DAYS)
      WITH SYNONYMS ('이탈 회원 평균 유지기간', '중단 회원 평균 유지일수')
      COMMENT = '🔴 **이탈(최초 중단)한 회원만**의 평균 유지기간(일) = 최초 중단일 − 획득일(SV_MEMBER_COHORT 와 같은 정의 · O205-C). 미중단 회원은 NULL 이라 빠진다 ⇒ 「수신회원 평균 후원유지기간」으로 쓰지 않는다 — 그 질문은 AVG_SPONSOR_DAYS_TO_DATE 를 쓴다. 🔴 수신연도를 고정한 상태에서 쓴다.',
    svc.AVG_SPONSOR_DAYS_TO_DATE AS AVG(COALESCE(svc.TENURE_DAYS, DATEDIFF('day', svc.ACQ_DATE, CURRENT_DATE())))
      WITH SYNONYMS ('평균 후원유지기간', '평균 유지기간(일)', '평균 후원기간')
      COMMENT = '🆕 [O205-C] 수신회원 평균 후원유지기간(일) — 중단 회원은 획득일 → 최초 중단일, 미중단 회원은 획득일 → 오늘. 「후원유지기간」 질문의 기본 지표다. ⚠️ 미중단 회원은 아직 진행 중인 기간이라 관측 시점에 따라 값이 늘어난다(조회일을 밝힌다). 🔴 수신연도를 고정한 상태에서 쓴다.',
    svc.EVER_STOPPED_RATE AS DIV0(COUNT(DISTINCT IFF(svc.EVER_STOPPED_FLAG, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('중단 이력 비율', '누적 중단 비율')
      COMMENT = '🆕 [O205-C] 최초 중단 이력이 있는 회원 비율(%) · 관측 기간 무보정 누적값 — 캠페인별 이탈률 정본(12개월 고정)은 SV_MEMBER_COHORT 다. N(비가산).',
    svc.AVG_ACQ_SPNSR_AMT AS AVG(svc.ACQ_SPNSR_AMT)
      WITH SYNONYMS ('평균 후원금액', '평균 약정금액')
      COMMENT = '획득 시점 평균 약정 후원금액(원).',
    svc.AVG_D5_STOP_SPONSOR_DAYS AS AVG(svc.D5_STOP_SPONSOR_DAYS)
      WITH SYNONYMS ('중단 회원 평균 후원기간')
      COMMENT = 'D5 중단 회원의 평균 후원기간(일 · 획득일 → D5 중단일 · O205-B). 🔴 중단 사건 원천에는 후원금액이 없다 — 중단 회원의 후원금액은 AVG_ACQ_SPNSR_AMT(획득 시점 약정금액)로 답하고 그 전제를 밝힌다.'
  )
  COMMENT = '서비스 수신 코호트 SV(🆕 O205). 「서비스 수신/미수신 회원의 이벤트 참여율 비교」·「발송 후 5일 이내 중단한 회원의 가입캠페인·중단사유·후원금액·연령대·후원사업·후원기간」·「연도별 수신회원 유지기간·참여횟수」에 쓴다. 🔴 수신·미수신 차이는 인과(서비스 효과)가 아니다.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 반드시 svc.SERVICE_GROUP_CD 를 하나로 고정한다. (2) 연도별 질문은 svc.RECEIVE_YEAR 로 고정하고, 수신/미수신 비교는 svc.RECEIVED_FLAG 로 나눈다(미수신은 RECEIVE_YEAR 가 NULL 이므로 연도 조건을 걸면 사라진다 — 미수신 비교가 필요하면 연도 조건을 RECEIVED_FLAG = TRUE 쪽에만 건다). (3) 회원수·참여율은 반드시 COUNT(DISTINCT svc.MEMBER_DK) 기반 지표를 쓴다. (4) 「선넘는좋은일 캠페인으로 가입」은 svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'', 가입기간은 svc.ACQ_DATE 로 거른다. (5) 「온라인 이벤트」 = ONLINE_EVENT_PART_* 지표(일반행사 중 원천 이벤트구분 「온라인」), 「문화이벤트」 = CULTURE_EVENT_PART_* 지표(캠페인행사 중 원천 행사구분 「문화서비스」 계열)로 답한다 — 원천에 같은 이름의 코드가 없어 정의가 되지 않았으므로 「유사한 원천 값(온라인 / 문화서비스·전시·서적·공연)으로 매핑했다」고 답변에 반드시 밝힌다. 「이벤트 전체」를 물으면 GENERAL_EVENT_PART_*·CAMPAIGN_EVENT_PART_* 를 쓴다. (6) 「효과가 높다/낮다」를 인과로 단정하지 않는다 — 지표 차이로만 표현한다. (7) 「오픈」 조건은 이 SV 에 없다(알림톡 오픈 원천 부재) — 수신 기준으로 답하고 그 사실을 밝힌다. (8) 🔴 「수신 회원」·「발송 후 5일 내 중단」·「수신회원 유지기간·참여횟수」 질문은 반드시 svc.RECEIVED_FLAG = TRUE 로 거른다 — 거르지 않으면 미수신(획득 코호트 전체) 회원이 모수에 섞인다. 수신 회원수를 말할 때는 이 조건을 건 값만 쓴다. (9) 🆕 [O206] 서비스 법인(사단·사복·통합)은 RECEIVED_SADAN_FLAG·RECEIVED_SABOK_FLAG·RECEIVED_TONGHAP_FLAG = TRUE 로 거른다(법인 = 서비스코드명의 법인 표기 → 없으면 알림톡 템플릿 법인구분). 「(사단)」 질문은 RECEIVED_SADAN_FLAG 로 답하고, 법인 플래그가 모두 FALSE 인 수신(템플릿·코드가 없는 발송)이 있으면 「법인 미판별」로 따로 밝힌다. 서비스 담당부서는 CHRG_DEPT_NAMES(템플릿 담당부서)로 답한다. 획득 세부캠페인 법인구분(svc.ACQ_CPR_DIV_NM)은 발송 법인과 다른 축이므로 대신 쓰지 않는다. (10) 「후원유지기간」은 AVG_SPONSOR_DAYS_TO_DATE 로 답한다 — AVG_TENURE_DAYS 는 이탈 회원만의 평균이다. (11) 연도 간 지표가 달라진 원인(구성 변화 등)을 말하려면 그 분해(연령대·가입연도 등)를 실제로 조회해 보여준 뒤에만 말하고, 조회하지 않은 원인을 단정하지 않는다. (12) 🆕 [O206] 결과에 MATCH_BASIS(매핑근거)를 함께 GROUP BY 해 보여준다 — 🔴 [O206-C] 수신 회원 지표를 내는 모든 쿼리(연도별·연령대별 등 분해 포함)에 MATCH_BASIS 를 GROUP BY 열로 넣거나, 넣지 않으면 별도 쿼리로 MATCH_BASIS 별 회원수를 함께 반환한다(생략 금지) — 「발송제목」 근거 행이 있으면 「원천 상위 카테고리(서비스코드) 정의에 없어 발송 제목으로 매핑했다」고 답변에 명시한다. (13) 🆕 [O206] 대조군은 원천·DW 에 정의가 없다 — 「서비스 효과」·「대조군 대비」를 물으면 먼저 「정의된 대조군이 없다」고 답하고, 대조군 후보를 제시한다: ① 같은 가입월(ACQ_MONTH_KEY) 미수신 회원 ② 같은 가입캠페인(ACQ_CAMPAIGN_NAME·ACQ_PARENT_CAMPAIGN_NAME) 미수신 회원 ③ 같은 후원사업(ACQ_SPONSORSHIP_NAME)·가입 법인구분 미수신 회원 ④ 같은 연령대 미수신 회원. 사용자가 후보를 고르면 그 축을 고정해 RECEIVED_FLAG 로 나눠 비교하되 인과로 단정하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o205_sng_part AS (
      QUESTION '선넘는좋은일 캠페인으로 2026년 1월부터 9월까지 가입한 회원 중 선넘는좋은일 즉시 알림톡 수신/미수신 회원의 온라인 이벤트·문화이벤트 참여율 비교'
      VERIFIED_BY '(DW = O205 원천 직접 집계 · 기대값은 파일 머리 주석)'
      SQL 'SELECT svc.RECEIVED_FLAG, COUNT(DISTINCT svc.MEMBER_DK) AS MEMBER_COUNT, DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS GENERAL_EVENT_PART_RATE, DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS CAMPAIGN_EVENT_PART_RATE FROM svc WHERE svc.SERVICE_GROUP_CD = ''SNG_INSTANT'' AND svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'' AND svc.ACQ_DATE BETWEEN ''2026-01-01'' AND ''2026-09-30'' GROUP BY svc.RECEIVED_FLAG ORDER BY svc.RECEIVED_FLAG'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — VQR 기대값 = 수신 3,508 · 미수신 666 (O205 원천 직접 집계)
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT
  DIMENSIONS svc.RECEIVED_FLAG
  METRICS svc.MEMBER_COUNT, svc.GENERAL_EVENT_PART_RATE, svc.CAMPAIGN_EVENT_PART_RATE
  WHERE svc.SERVICE_GROUP_CD = 'SNG_INSTANT'
    AND svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE '%선넘는좋은일%'
    AND svc.ACQ_DATE BETWEEN '2026-01-01' AND '2026-09-30');

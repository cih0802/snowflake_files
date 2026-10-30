-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_MKTG_CAMPAIGN_COST (🆕 O266 · 현업 피드백 2)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST
-- Run order  : 운영계 기존 환경 갱신 #45(46 [D3] 다음) · 신규 구축 = 05_30 다음
-- Depends on : GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST, GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
-- Issue      : O266
-- =============================================================================
-- ============================================================================
-- 05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql — 「마케팅캠페인별 광고비 / 개발(건) / 제작비」 한 표 SV
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 선행 = GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST(46 [D1] · dbt build) · 대사 = 46 [D2]
--   · 개발(건) = MSTR 기준(사용자 결정 2026-10-28) · 제작비 = 지출결의 세부캠페인코드 기재분(세세목 필터 없음 · 가정)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST
  TABLES (
    mcc AS GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST
      PRIMARY KEY (MKTG_CAMPAIGN_SK, MONTH_KEY)
      WITH SYNONYMS ('마케팅캠페인 비용 개발', '캠페인별 광고비 개발건 제작비', '캠페인 투입 대비 성과')
      COMMENT = '마케팅캠페인 × 월 결합 팩트(base: GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST). [Grain: 마케팅캠페인 × 연월]. 광고비(대행사 3원천) · 디지털 최종정산금액 · 제작비(지출결의 세부캠페인코드 기재분) · 개발(건)(MSTR 기준)을 한 행에 담는다. SK=0 = (미매핑) 버킷 — 광고·개발이 마케팅캠페인에 닿지 않은 분(제작비는 0 버킷에 없다).',
    mktg AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인')
      COMMENT = '마케팅캠페인 conformed 차원(PK 유일 · fan-out 0) — 광고·개발·제작비를 잇는 결합축. SK=0 = (미매핑).'
  )
  RELATIONSHIPS (
    mcc_to_mktg AS mcc (MKTG_CAMPAIGN_SK) REFERENCES mktg
  )
  DIMENSIONS (
    mcc.MONTH_KEY AS mcc.MONTH_KEY WITH SYNONYMS ('연월', '기준연월', '월') COMMENT = '연월 YYYYMM 정수(광고 = 실적일 · 제작비 = 결의 작성일 · 개발 = MSTR 기준년월). 기간 합계는 이 차원으로 범위를 건다(합산 가능 measure 만).',
    mcc.CAL_YEAR AS FLOOR(mcc.MONTH_KEY / 100) WITH SYNONYMS ('연도', '년') COMMENT = '연도(MONTH_KEY 의 앞 4자리).',
    mktg.MARKETING_CAMPAIGN AS mktg.MKTG_CAMPAIGN_NAME WITH SYNONYMS ('마케팅캠페인명', '마케팅캠페인', '캠페인명') COMMENT = '마케팅캠페인명. SK=0 행 = ''(미매핑)'' — 빼지 않고 그대로 보인다(전체 합 정합).',
    mktg.CMPGN_CTGR_NM AS mktg.CMPGN_CTGR_NM WITH SYNONYMS ('캠페인카테고리', '캠페인 카테고리') COMMENT = '마케팅캠페인 대표 캠페인카테고리(매핑 행수 최다 · 대표값). 🔴 마케팅채널·인입경로는 이 SV 에 없다 — 마케팅캠페인 하나 아래 값이 갈려 대표값이 왜곡된다(SV_AD 규칙과 같다).',
    mktg.MKTG_UTM_NM AS mktg.MKTG_UTM_NM WITH SYNONYMS ('마케팅UTM', 'UTM') COMMENT = '마케팅캠페인의 UTM 라벨(CRM U001).'
  )
  METRICS (
    mcc.TOTAL_AD_COST AS SUM(mcc.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비(원) = 디지털+영상+재방송 대행사 광고비 합. F(가산). 디지털은 마크업·부가세 제외 금액이다 — 정산액은 AD_SETTLE_AMT.',
    mcc.AD_COST_DIGITAL_SUM AS SUM(mcc.AD_COST_DIGITAL)
      WITH SYNONYMS ('디지털 광고비') COMMENT = '디지털 광고비(원). F(가산).',
    mcc.AD_COST_VIDEO_SUM AS SUM(mcc.AD_COST_VIDEO)
      WITH SYNONYMS ('영상 광고비', 'TV 광고비') COMMENT = '영상 광고비(원). F(가산).',
    mcc.AD_COST_REBROADCAST_SUM AS SUM(mcc.AD_COST_REBROADCAST)
      WITH SYNONYMS ('방송 편성비', '재방송 편성비') COMMENT = '방송(재송출·방송) 편성비(원). F(가산). 🔴 방송 광고비를 물으면 이 값이 아니라 FINAL_AD_COST_REBROADCAST_SUM(총비용)을 쓴다(현업 확정 · O270).',
    mcc.AD_SETTLE_AMT AS SUM(mcc.LAST_STMT_AMT)
      WITH SYNONYMS ('디지털 최종정산금액', '정산금액') COMMENT = '디지털 최종정산금액(원) = 광고비 + 마크업 + 부가세. F(가산). DIGITAL 전용 컬럼 — 영상·방송의 같은 개념은 각각 최종광고비·총비용이다(FINAL_AD_COST 에 통합 · O270). 영상·방송 질문에 「최종정산금액이 없다」고 답하지 않는다.',
    mcc.FINAL_AD_COST_SUM AS SUM(mcc.FINAL_AD_COST)
      WITH SYNONYMS ('최종 광고비', '최종광고비', '최종정산금액', '광고비(최종)') COMMENT = '최종 광고비(원) = 디지털 최종정산금액(LAST_STMT_AMT) + 영상 최종광고비(LAST_AD_COST) + 방송 총비용(TOT_COST). F(가산). 현업 확정 정의(데분_6 · O270) — 세 원천의 같은 개념. 원천 값이 NULL 인 행은 더해지지 않는다 ⇒ FINAL_AD_COST_NULL_ROWS_SUM 이 0 보다 크면 「일부 원천 값 미입력 · 하한값」을 밝힌다.',
    mcc.FINAL_AD_COST_REBROADCAST_SUM AS SUM(mcc.AD_COST_REBROADCAST_TOT)
      WITH SYNONYMS ('방송 광고비', '방송 총비용', '재송출 광고비', '재방송 광고비') COMMENT = '방송(재송출·방송) 최종 광고비(원) = 총비용 TOT_COST(편성비+콘텐츠구입비+콜센터운영비). F(가산). 현업 확정(O270).',
    mcc.FINAL_AD_COST_NULL_ROWS_SUM AS SUM(mcc.FINAL_AD_COST_NULL_ROWS)
      WITH SYNONYMS ('최종 광고비 미입력 행수') COMMENT = '최종 광고비 원천 값이 NULL 인 광고 행 수. F(가산). 0 보다 크면 최종 광고비는 하한값이다.',
    mcc.TOTAL_PROD_COST AS SUM(mcc.PROD_COST)
      WITH SYNONYMS ('제작비', '캠페인 제작비', '지출액') COMMENT = '제작비(원) = 지출결의 금액 중 콘텐츠구분자(CONTENTS_DELIMITER = 세부캠페인코드) 기재분 전체. F(가산). 현업 확정 규칙(데분_2 · O270). 콘텐츠구분자 미기재(NULL·「-」) 지출은 캠페인을 알 수 없어 빠진다. 🔴 지출결의 원천은 매 적재 시 전량 재적재되므로 원천(RPA 등)이 과거 결의의 콘텐츠구분자를 바꾸면 과거 월 제작비도 바뀐다.',
    mcc.TOTAL_DEV_CNT_CRM AS SUM(mcc.DEV_CNT_CRM)
      WITH SYNONYMS ('CRM 기반 개발(건)', 'CRM 개발(건)', 'CRM 개발건수', '개발(건)', '개발건수', '개발건') COMMENT = 'CRM 기반 개발(건) = CRM 개발 사건 금액 ÷ 10,000(상계 규칙 적용 · 신규·증액·재후원 · 굿네이버스 기본 건수 정의). F(가산). 🔴 [O270-D 사용자 결정] **이 SV 의 개발건수·개발단가 기본 지표**다 — 답변에 「CRM 기반 개발건수」임을 밝힌다(다른 SV·도구의 개발건수는 MSTR 기준). 마케팅캠페인 연결 = 사건 시점 마케팅캠페인 코드. 소수가 있다.',
    mcc.DEV_UNIT_PRICE_CRM AS SUM(mcc.FINAL_AD_COST) / NULLIF(SUM(mcc.DEV_CNT_CRM), 0)
      WITH SYNONYMS ('CRM 개발단가', 'CRM 기준 개발단가', '개발단가', '건당 광고비', 'CPA') COMMENT = 'CRM 개발단가(원/건) = 최종 광고비 ÷ CRM 개발(건). 비율(N · 재합산 금지). 🆕 [O270].',
    mcc.TOTAL_DEV_CNT_MSTR AS SUM(mcc.DEV_CNT_MSTR)
      WITH SYNONYMS ('MSTR 개발(건)', 'MSTR 개발건수') COMMENT = '개발(건) MSTR 기준 = 후원금액 ÷ 10,000 · 신규·증액·재후원. F(가산). 🔴 [O270-D] 이 SV 에서는 사용자가 「MSTR 기준」을 명시할 때만 쓴다(기본 = TOTAL_DEV_CNT_CRM). 소수가 있다(정수로 단정 금지).',
    mcc.TOTAL_NEW_DEV_CNT_MSTR AS SUM(mcc.NEW_DEV_CNT_MSTR)
      WITH SYNONYMS ('신규 개발(건)', '신규개발건') COMMENT = '신규 개발(건) MSTR 기준(개발구분 1). F(가산).',
    mcc.DEV_UNIT_PRICE_MSTR AS SUM(mcc.AD_COST) / NULLIF(SUM(mcc.DEV_CNT_MSTR), 0)
      WITH SYNONYMS ('MSTR 개발단가', 'MSTR 기준 개발단가') COMMENT = '개발단가(원) = 광고비 ÷ MSTR 개발(건). 비율(N · 재합산 금지). 🔴 SV_AD 공7(대행사 CRM 개발건 기준)과 분모가 다르다.',
    mcc.TOTAL_COST_UNIT_PRICE_MSTR AS (SUM(COALESCE(mcc.AD_COST, 0)) + SUM(COALESCE(mcc.PROD_COST, 0))) / NULLIF(SUM(mcc.DEV_CNT_MSTR), 0)
      WITH SYNONYMS ('제작비 포함 개발단가', '총비용 개발단가') COMMENT = '(광고비 + 제작비) ÷ MSTR 개발(건)(원). 비율(N). 제작비는 코드 기재분만이라 하한값이다.'
  )
  COMMENT = '마케팅캠페인 × 월 광고비·디지털 정산액·제작비·MSTR 개발(건) 결합 SV(O266). 「마케팅캠페인별 광고비 / 개발건수 / 제작비를 한 표로」 질문의 1순위 도구 — 세 값을 한 SELECT 로 낸다. 🔴 마케팅채널·인입경로별 비용은 내지 않는다(대표값 왜곡). 🔴 개발(건)·개발단가는 이 SV 에서 CRM 기반(금액 ÷ 10,000 · TOTAL_DEV_CNT_CRM · DEV_UNIT_PRICE_CRM)이 기본이다 — 답변에 「CRM 기반 개발건수」를 밝힌다 · MSTR 기준은 명시 요청 시만(O270-D).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 마케팅캠페인별 질문은 mktg.MARKETING_CAMPAIGN 으로 그루핑하고 광고비·디지털 최종정산금액·제작비·개발(건)을 **같은 SELECT 에 나란히** 낸다(표 하나 · 다른 SV 를 따로 부르지 않는다). (2) 기간 미지정이면 데이터가 있는 최신 연도(1월~최신월)로 한정하고 밝힌다 — 기준 시점은 비상관 CTE 1개에서 MAX(mcc.MONTH_KEY) 로 구해 CROSS JOIN 한다. (3) (미매핑) 행을 빼지 않는다 — 캠페인별 합 + (미매핑) = 같은 기간 전체임을 맞춘다. (4) 개발단가는 SUM 비로 계산한다(행별 단가 평균 금지) · 개발(건)이 0·NULL 인 캠페인은 단가 NULL. (5) 답변에 「제작비 = 콘텐츠구분자(세부캠페인코드)가 기재된 지출결의 전체(현업 확정 규칙)」「개발(건) = CRM 기반 개발건수(금액 ÷ 10,000 · TOTAL_DEV_CNT_CRM) · 개발단가 = 최종 광고비 ÷ CRM 기반 개발(건)(DEV_UNIT_PRICE_CRM)」「최종 광고비 = 디지털 최종정산금액 + 영상 최종광고비 + 방송 총비용」 3줄을 표 밖에 밝힌다. (5-1) 🆕 [O270] 광고비를 묻거나 표에 광고비를 낼 때 FINAL_AD_COST_SUM(최종 광고비)을 함께 낸다 — 원천별로 나눌 때 디지털 = AD_SETTLE_AMT · 영상 = AD_COST_VIDEO_SUM · 방송 = FINAL_AD_COST_REBROADCAST_SUM. 영상·방송에 「최종정산금액이 없다」고 쓰지 않는다. FINAL_AD_COST_NULL_ROWS_SUM > 0 이면 「일부 원천 값 미입력(하한값)」을 밝힌다. (6) 정렬은 ORDER BY ... DESC NULLS LAST.'
  AI_VERIFIED_QUERIES (
    vqr_o266_campaign_cost_dev_2026 AS (
      QUESTION '2026년 마케팅캠페인별 광고비, 개발건수, 제작비를 한 표로'
      VERIFIED_BY '(DW = O266 · O270-D 최종 광고비 · CRM 기반 개발(건)·개발단가)'
      SQL 'SELECT MC AS "마케팅캠페인명", FINAL AS "최종 광고비(원)", AD AS "광고비(원)", PROD AS "제작비(원)", DEV AS "CRM 기반 개발(건)", ROUND(UNIT, 2)::NUMBER(38,2) AS "CRM 개발단가(원/건)" FROM (SELECT COALESCE(mktg.MKTG_CAMPAIGN_NAME, ''(미매핑)'') AS MC, SUM(mcc.FINAL_AD_COST) AS FINAL, SUM(mcc.AD_COST) AS AD, SUM(mcc.PROD_COST) AS PROD, SUM(mcc.DEV_CNT_CRM) AS DEV, SUM(mcc.FINAL_AD_COST) / NULLIF(SUM(mcc.DEV_CNT_CRM), 0) AS UNIT FROM mcc LEFT JOIN mktg ON mcc.MKTG_CAMPAIGN_SK = mktg.MKTG_CAMPAIGN_SK WHERE mcc.MONTH_KEY BETWEEN 202601 AND 202612 GROUP BY 1) ORDER BY FINAL DESC NULLS LAST'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST TO ROLE GN_DW_AR_SRC_AGENCY_ERP;  -- O270 원천별 접근 역할
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — SV 광고비·개발(건) 합 = 팩트 직접 합(2026)
SELECT (SELECT SUM(TOTAL_AD_COST) FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST DIMENSIONS mcc.MONTH_KEY METRICS mcc.TOTAL_AD_COST) WHERE MONTH_KEY BETWEEN 202601 AND 202612) AS sv_ad,
       (SELECT SUM(AD_COST) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST WHERE MONTH_KEY BETWEEN 202601 AND 202612) AS fact_ad,
       (SELECT SUM(TOTAL_DEV_CNT_MSTR) FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST DIMENSIONS mcc.MONTH_KEY METRICS mcc.TOTAL_DEV_CNT_MSTR) WHERE MONTH_KEY BETWEEN 202601 AND 202612) AS sv_dev,
       (SELECT SUM(DEV_CNT_MSTR) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST WHERE MONTH_KEY BETWEEN 202601 AND 202612) AS fact_dev;

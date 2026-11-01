-- =============================================================================
-- 51_FIX_PROD_BUILD_ZL50263.sql — 운영계 build 실패 20건 복구(전체 선택 → 순서대로 실행)
-- O271-D · 2026-10-30 · 대상 = 운영계 ZL50263 전용(개발계는 이미 이 상태 · 실행 불필요)
--
-- 원인 ① WIDE 뷰 003509 = 운영계 GOLD 가 MANAGED ACCESS → dbt 역할이 +grants·copy grants 를 못 한다
--        설계 정본 = 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:134
--        「BRONZE_*·SECURITY = MANAGED ACCESS. SILVER/GOLD/SERVING/OPS = 일반.」 ⇒ 설계로 되돌린다(사용자 결정 ㉮)
-- 원인 ② FACT_MKTG_CAMPAIGN_MONTHLY_COST 003001 = 47번 [D1] 컬럼 5개 미추가 → dbt 가 ALTER 시도 → 소유자 권한 필요
--        소유자 = GN_DW_ADMIN(O271 단계 4 이전 완료) ⇒ GN_DW_ADMIN 으로 [D1] 실행
-- 🟢 모든 문장은 재실행해도 안전하다(IF NOT EXISTS · DISABLE 은 멱등)
-- =============================================================================

-- [1] 진단(읽기 전용) — 결과 options 열에 MANAGED ACCESS 가 있는 스키마 확인(기대 = BRONZE_* · SECURITY · GOLD)
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
SHOW SCHEMAS IN DATABASE GN_DW;

-- [2] 원인 ② — 47번 [D1] 물리 컬럼 추가(05_SV-Agent_ai/47_DEPLOY_FINAL_AD_COST.sql [D1] 원문 그대로)
USE ROLE GN_DW_ADMIN;
USE DATABASE GN_DW;
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS AD_COST_REBROADCAST_TOT NUMBER(38,2)
  COMMENT '방송(재송출·방송) 총비용(원) = 원천 REBRDC TOT_COST 합(편성비+콘텐츠구입비+콜센터운영비). 원천이 NULL 이면 NULL 로 둔다(0 으로 채우지 않는다).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS FINAL_AD_COST NUMBER(38,2)
  COMMENT '최종 광고비(원) = 디지털 LAST_STMT_AMT(최종정산금액) + 영상 LAST_AD_COST(최종광고비) + 방송 TOT_COST(총비용) — 현업 확정(데분_6). 원천 값이 NULL 인 행은 더해지지 않는다 ⇒ FINAL_AD_COST_NULL_ROWS 를 함께 본다.';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS FINAL_AD_COST_NULL_ROWS NUMBER(38,0)
  COMMENT '최종 광고비 원천 값이 NULL 인 광고 행 수(그 달). 0 보다 크면 FINAL_AD_COST 는 하한값이다(예: 방송 총비용 미입력 월).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS DEV_CNT_CRM NUMBER(18,4)
  COMMENT '🆕 [O270] CRM 개발(건) = FACT_MEMBER_EVENT.DEV_CNT 합(금액 ÷ 10,000 · 상계 규칙 적용 · 신규·증액·재후원) · 결합 = 사건 시점 마케팅캠페인 코드. 소수가 있다.';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ADD COLUMN IF NOT EXISTS NEW_DEV_CNT_CRM NUMBER(18,4)
  COMMENT '🆕 [O270] CRM 신규 개발(건)(개발구분 1).';
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST MODIFY COLUMN PROD_COST
  COMMENT '제작비(원) = 지출결의 금액 중 콘텐츠구분자(CONTENTS_DELIMITER = 세부캠페인코드) 기재분 전체 — 현업 확정 규칙(데분_2 · 2026-10-29). 미기재(NULL·「-」) 지출은 캠페인을 알 수 없어 빠진다.';

-- [2-확인] 기대 = 5행
SELECT COLUMN_NAME, DATA_TYPE
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_NAME = 'FACT_MKTG_CAMPAIGN_MONTHLY_COST'
  AND COLUMN_NAME IN ('AD_COST_REBROADCAST_TOT', 'FINAL_AD_COST', 'FINAL_AD_COST_NULL_ROWS', 'DEV_CNT_CRM', 'NEW_DEV_CNT_CRM');

-- [3] 원인 ① — GOLD managed access 해제(설계 정본 복귀)
--     🆕 [O271-D 2차] 운영계 실측 = 「One or more future grants exist in the schema. They must be revoked first.」
--     ⇒ FUTURE GRANT 백업 → 회수 → 해제 → 같은 내용으로 재부여(블록 1개 · 문장별 오류는 백업표에 기록하고 계속)
--     🟢 기존 객체 GRANT 는 그대로 유지된다(FUTURE 만 잠시 비었다가 복원)
-- [3-0] 🆕 [O271-D 4차] 백업 복구 — 이전 판(CREATE OR REPLACE)을 재실행해 백업이 0건으로 덮였으면
--       Time Travel 로 직전 판(원본 41건)을 되살린다 · 백업이 이미 1건 이상이면 아무것도 하지 않는다
USE ROLE ACCOUNTADMIN;
EXECUTE IMMEDIATE $$
DECLARE n INTEGER DEFAULT -1; i INTEGER DEFAULT 0; nm VARCHAR;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO :n FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;
  EXCEPTION WHEN OTHER THEN
    RETURN 'SKIP — 백업 표 없음(첫 실행)';
  END;
  IF (n > 0) THEN
    RETURN 'OK — 백업 ' || n || '건 그대로 사용';
  END IF;
  -- 0건이면 현재 판을 비켜 두고 직전 판을 되살린다(덮어쓴 횟수만큼 · 최대 5회)
  WHILE (n = 0 AND i < 5) DO
    i := i + 1;
    nm := 'GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK_EMPTY_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3') || '_' || i;
    EXECUTE IMMEDIATE 'ALTER TABLE GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK RENAME TO ' || nm;
    BEGIN
      UNDROP TABLE GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;
    EXCEPTION WHEN OTHER THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ' || nm || ' RENAME TO GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK';
      RETURN 'FAIL — 되살릴 이전 판 없음(Time Travel 밖) · 다음 단계로 가지 말고 알려 달라';
    END;
    SELECT COUNT(*) INTO :n FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;
  END WHILE;
  RETURN 'RECOVERED — Time Travel 복구 ' || n || '건(기대 = 41)';
END;
$$;

-- [3-0b] 진단 — DB 수준 FUTURE GRANT(있으면 스키마 해제를 막을 수 있다 · 개발계 = 0건)
SHOW FUTURE GRANTS IN DATABASE GN_DW;

-- 🔴 [O271-D 3차] 백업은 최초 1회만 만든다(IF NOT EXISTS) — 재실행해도 원본 41건이 덮이지 않는다
USE ROLE ACCOUNTADMIN;
SHOW FUTURE GRANTS IN SCHEMA GN_DW.GOLD;
CREATE TABLE IF NOT EXISTS GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK AS
SELECT "privilege" AS PRIV, "grant_on" AS GRANT_ON, "grant_to" AS GRANT_TO, "grantee_name" AS GRANTEE,
       "grant_option" AS GRANT_OPT, CAST(NULL AS VARCHAR) AS REVOKE_ERR, CAST(NULL AS VARCHAR) AS REGRANT_ERR
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
-- 기대 = 원본 건수(운영계 41) · 이미 있던 표면 그 건수가 그대로 나온다
SELECT COUNT(*) AS FUTURE_GRANTS_BACKED_UP FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;

-- 블록 = ① 역할·객체유형별 REVOKE ALL ② 남은 FUTURE 가 있으면 해제하지 않고 백업으로 복원 후 남은 목록 반환
--        ③ 0 이면 해제 ④ 백업 그대로 재부여 · 반환값 = 'DONE' 또는 'ABORT …'
EXECUTE IMMEDIATE $$
DECLARE
  c1 CURSOR FOR SELECT DISTINCT GRANT_ON, GRANT_TO, GRANTEE FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;
  c2 CURSOR FOR SELECT PRIV, GRANT_ON, GRANT_TO, GRANTEE, GRANT_OPT::STRING AS GO FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK;
  p VARCHAR; o VARCHAR; g VARCHAR; tgt VARCHAR; stmt VARCHAR; err VARCHAR; left_cnt INTEGER; left_list VARCHAR; alter_err VARCHAR;
BEGIN
  UPDATE GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK SET REVOKE_ERR = NULL, REGRANT_ERR = NULL;
  FOR r IN c1 DO
    o := r.GRANT_ON; g := r.GRANTEE;
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || g;
    stmt := 'REVOKE ALL PRIVILEGES ON FUTURE ' || REPLACE(o, '_', ' ') || 'S IN SCHEMA GN_DW.GOLD FROM ' || tgt;
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM;
      UPDATE GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK SET REVOKE_ERR = :err WHERE GRANT_ON = :o AND GRANTEE = :g;
    END;
  END FOR;

  SHOW FUTURE GRANTS IN SCHEMA GN_DW.GOLD;
  SELECT COUNT(*), LISTAGG("privilege" || ' ON ' || "grant_on" || ' TO ' || "grantee_name", ' | ')
    INTO :left_cnt, :left_list FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  IF (left_cnt = 0) THEN
    BEGIN
      ALTER SCHEMA GN_DW.GOLD DISABLE MANAGED ACCESS;
    EXCEPTION WHEN OTHER THEN
      alter_err := SQLERRM;   -- 🔴 [O271-D 4차] 실패해도 아래 재부여는 반드시 돈다
    END;
  END IF;

  FOR r IN c2 DO
    p := r.PRIV; o := r.GRANT_ON; g := r.GRANTEE;
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || g;
    stmt := 'GRANT ' || p || ' ON FUTURE ' || REPLACE(o, '_', ' ') || 'S IN SCHEMA GN_DW.GOLD TO ' || tgt
            || IFF(LOWER(r.GO) = 'true', ' WITH GRANT OPTION', '');
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM;
      UPDATE GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK SET REGRANT_ERR = :err
       WHERE PRIV = :p AND GRANT_ON = :o AND GRANTEE = :g;
    END;
  END FOR;

  IF (left_cnt > 0) THEN
    RETURN 'ABORT — 회수 후에도 FUTURE ' || left_cnt || '건 잔존(해제 안 함 · 백업으로 복원함): ' || left_list;
  END IF;
  IF (alter_err IS NOT NULL) THEN
    RETURN 'ABORT — 해제 실패(FUTURE 는 백업으로 복원함): ' || alter_err;
  END IF;
  RETURN 'DONE';
END;
$$;

-- [3-확인 a] 기대 = 블록 반환 'DONE' + 아래 0행 · 'ABORT' 이거나 행이 있으면 멈추고 결과를 알려 달라
SELECT * FROM GN_DW.OPS.O271_GOLD_FUTURE_GRANTS_BAK WHERE REVOKE_ERR IS NOT NULL OR REGRANT_ERR IS NOT NULL;
-- [3-확인 b] 기대 = 백업 건수와 같은 행 수
SHOW FUTURE GRANTS IN SCHEMA GN_DW.GOLD;
-- [3-확인 c] 기대 = GOLD 의 IS_MANAGED_ACCESS = NO
SELECT SCHEMA_NAME, SCHEMA_OWNER, IS_MANAGED_ACCESS
FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('GOLD', 'SERVING', 'SILVER', 'OPS');

-- [4] dbt retry — 직전 실행에서 실패·건너뜀 모델만 재실행(GN_DW_DBT)
USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

-- [5] 결과 확인 — 실패 모델이 이제 GRANT 를 가졌는가(기대 = GN_DW_AR_SRC_AGENCY 행 존재)
USE ROLE ACCOUNTADMIN;
SHOW GRANTS ON VIEW GN_DW.GOLD.WIDE_AD_COMBINED;
-- 이후 = O270 운영계 LLM 프롬프트 단계 4(Agent 재배포)부터 · 47번 [D2] 대사는 그 전에 1회 실행 권장

-- =============================================================================
-- 52_FIX_PROD_MANAGED_ACCESS_OPS_SILVER_ZL50263.sql — 운영계 OPS·SILVER managed access 해제(설계 정본 복귀)
-- O272-B · 2026-10-30 · 대상 = 운영계 ZL50263 전용 · 사용자 결정(2026-10-30) = 51번 방식으로 해제
--
-- 근거 = 설계 정본 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:134
--        「BRONZE_*·SECURITY = MANAGED ACCESS. SILVER/GOLD/SERVING/OPS = 일반.」
--        신규 구축 실측(개발 환경 TQ68205 · 2026-10-30) = OPS NO · SILVER NO ⇒ 운영계 YES 는 구축 후 드리프트
-- 방식 = 51번 [3] 과 같다(O271-D 4차판) — 스키마 하나당 블록 하나
--        ① FUTURE GRANT 백업(최초 1회 · IF NOT EXISTS) ② 회수 ③ 잔존 0 일 때만 해제
--        ④ 해제 성공·실패와 무관하게 백업 그대로 재부여 ⑤ 반환 = 'DONE' 또는 'ABORT …'
--  기존 객체 GRANT 는 건드리지 않는다(FUTURE 만 잠시 비었다가 복원)
--  재실행 안전 — 백업 표가 이미 있으면 다시 만들지 않는다(재실행해도 원본 건수가 덮이지 않는다)
-- WARN: 개발 환경 사전 검증 = SANDBOX 임시 스키마에서 이 블록 그대로(실패 경로 · 성공 경로) · 결과 = 인수인계 O272-B
-- WARN: dbt retry 는 없다 — 설계 복귀이고 build 실패 원인이 아니다(운영계 build 는 51번으로 이미 ERROR 0)
-- =============================================================================

-- [1] 진단(읽기 전용) — 기대 = OPS·SILVER 의 IS_MANAGED_ACCESS = YES(해제 전)
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
SELECT SCHEMA_NAME, SCHEMA_OWNER, IS_MANAGED_ACCESS
FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('GOLD', 'SERVING', 'SILVER', 'OPS')
ORDER BY 1;

-- [2] OPS 해제 — 반환값을 그대로 보고한다
EXECUTE IMMEDIATE $$
DECLARE
  sch VARCHAR DEFAULT 'GN_DW.OPS';
  bak VARCHAR DEFAULT 'GN_DW.OPS.O272_OPS_FUTURE_GRANTS_BAK';
  n_bak INTEGER; left_cnt INTEGER; left_list VARCHAR; alter_err VARCHAR; err VARCHAR; stmt VARCHAR; tgt VARCHAR;
  p VARCHAR; o VARCHAR; g VARCHAR;
  rs RESULTSET;
BEGIN
  -- ① 백업(최초 1회)
  EXECUTE IMMEDIATE 'SHOW FUTURE GRANTS IN SCHEMA ' || sch;
  EXECUTE IMMEDIATE 'CREATE TABLE IF NOT EXISTS ' || bak || ' AS '
    || 'SELECT "privilege" AS PRIV, "grant_on" AS GRANT_ON, "grant_to" AS GRANT_TO, "grantee_name" AS GRANTEE, '
    || '"grant_option" AS GRANT_OPT, CAST(NULL AS VARCHAR) AS REVOKE_ERR, CAST(NULL AS VARCHAR) AS REGRANT_ERR '
    || 'FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = NULL, REGRANT_ERR = NULL';
  rs := (EXECUTE IMMEDIATE 'SELECT COUNT(*) AS N FROM ' || bak);
  LET c0 CURSOR FOR rs;
  FOR r IN c0 DO n_bak := r.N; END FOR;

  -- ② 회수(역할·객체유형 단위)
  rs := (EXECUTE IMMEDIATE 'SELECT DISTINCT GRANT_ON, GRANT_TO, GRANTEE FROM ' || bak);
  LET c1 CURSOR FOR rs;
  FOR r IN c1 DO
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || r.GRANTEE;
    stmt := 'REVOKE ALL PRIVILEGES ON FUTURE ' || REPLACE(r.GRANT_ON, '_', ' ') || 'S IN SCHEMA ' || sch || ' FROM ' || tgt;
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM; o := r.GRANT_ON; g := r.GRANTEE;   -- USING 에는 레코드 필드를 못 넘긴다(TQ68205 001003)
      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = ? WHERE GRANT_ON = ? AND GRANTEE = ?'
        USING (err, o, g);
    END;
  END FOR;

  -- ③ 잔존 0 일 때만 해제
  EXECUTE IMMEDIATE 'SHOW FUTURE GRANTS IN SCHEMA ' || sch;
  SELECT COUNT(*), LISTAGG("privilege" || ' ON ' || "grant_on" || ' TO ' || "grantee_name", ' | ')
    INTO :left_cnt, :left_list FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
  IF (left_cnt = 0) THEN
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SCHEMA ' || sch || ' DISABLE MANAGED ACCESS';
    EXCEPTION WHEN OTHER THEN
      alter_err := SQLERRM;   -- 실패해도 아래 재부여는 반드시 돈다(O271-D 4차 교훈)
    END;
  END IF;

  -- ④ 재부여(백업 그대로)
  rs := (EXECUTE IMMEDIATE 'SELECT PRIV, GRANT_ON, GRANT_TO, GRANTEE, GRANT_OPT::STRING AS GO FROM ' || bak);
  LET c2 CURSOR FOR rs;
  FOR r IN c2 DO
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || r.GRANTEE;
    stmt := 'GRANT ' || r.PRIV || ' ON FUTURE ' || REPLACE(r.GRANT_ON, '_', ' ') || 'S IN SCHEMA ' || sch || ' TO ' || tgt
            || IFF(LOWER(r.GO) = 'true', ' WITH GRANT OPTION', '');
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM; p := r.PRIV; o := r.GRANT_ON; g := r.GRANTEE;
      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REGRANT_ERR = ? WHERE PRIV = ? AND GRANT_ON = ? AND GRANTEE = ?'
        USING (err, p, o, g);
    END;
  END FOR;

  -- ⑤ 반환
  IF (left_cnt > 0) THEN
    RETURN sch || ' ABORT — 회수 후에도 FUTURE ' || left_cnt || '건 잔존(해제 안 함 · 백업 ' || n_bak || '건으로 복원함): ' || left_list;
  END IF;
  IF (alter_err IS NOT NULL) THEN
    RETURN sch || ' ABORT — 해제 실패(FUTURE 백업 ' || n_bak || '건으로 복원함): ' || alter_err;
  END IF;
  RETURN sch || ' DONE — 백업 ' || n_bak || '건';
END;
$$;

-- [3] SILVER 해제 — [2] 와 같은 블록 · 첫 두 줄(sch · bak)만 다르다
EXECUTE IMMEDIATE $$
DECLARE
  sch VARCHAR DEFAULT 'GN_DW.SILVER';
  bak VARCHAR DEFAULT 'GN_DW.OPS.O272_SILVER_FUTURE_GRANTS_BAK';
  n_bak INTEGER; left_cnt INTEGER; left_list VARCHAR; alter_err VARCHAR; err VARCHAR; stmt VARCHAR; tgt VARCHAR;
  p VARCHAR; o VARCHAR; g VARCHAR;
  rs RESULTSET;
BEGIN
  EXECUTE IMMEDIATE 'SHOW FUTURE GRANTS IN SCHEMA ' || sch;
  EXECUTE IMMEDIATE 'CREATE TABLE IF NOT EXISTS ' || bak || ' AS '
    || 'SELECT "privilege" AS PRIV, "grant_on" AS GRANT_ON, "grant_to" AS GRANT_TO, "grantee_name" AS GRANTEE, '
    || '"grant_option" AS GRANT_OPT, CAST(NULL AS VARCHAR) AS REVOKE_ERR, CAST(NULL AS VARCHAR) AS REGRANT_ERR '
    || 'FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = NULL, REGRANT_ERR = NULL';
  rs := (EXECUTE IMMEDIATE 'SELECT COUNT(*) AS N FROM ' || bak);
  LET c0 CURSOR FOR rs;
  FOR r IN c0 DO n_bak := r.N; END FOR;

  rs := (EXECUTE IMMEDIATE 'SELECT DISTINCT GRANT_ON, GRANT_TO, GRANTEE FROM ' || bak);
  LET c1 CURSOR FOR rs;
  FOR r IN c1 DO
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || r.GRANTEE;
    stmt := 'REVOKE ALL PRIVILEGES ON FUTURE ' || REPLACE(r.GRANT_ON, '_', ' ') || 'S IN SCHEMA ' || sch || ' FROM ' || tgt;
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM; o := r.GRANT_ON; g := r.GRANTEE;   -- USING 에는 레코드 필드를 못 넘긴다(TQ68205 001003)
      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REVOKE_ERR = ? WHERE GRANT_ON = ? AND GRANTEE = ?'
        USING (err, o, g);
    END;
  END FOR;

  EXECUTE IMMEDIATE 'SHOW FUTURE GRANTS IN SCHEMA ' || sch;
  SELECT COUNT(*), LISTAGG("privilege" || ' ON ' || "grant_on" || ' TO ' || "grantee_name", ' | ')
    INTO :left_cnt, :left_list FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
  IF (left_cnt = 0) THEN
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SCHEMA ' || sch || ' DISABLE MANAGED ACCESS';
    EXCEPTION WHEN OTHER THEN
      alter_err := SQLERRM;
    END;
  END IF;

  rs := (EXECUTE IMMEDIATE 'SELECT PRIV, GRANT_ON, GRANT_TO, GRANTEE, GRANT_OPT::STRING AS GO FROM ' || bak);
  LET c2 CURSOR FOR rs;
  FOR r IN c2 DO
    tgt := IFF(r.GRANT_TO = 'DATABASE_ROLE', 'DATABASE ROLE ', 'ROLE ') || r.GRANTEE;
    stmt := 'GRANT ' || r.PRIV || ' ON FUTURE ' || REPLACE(r.GRANT_ON, '_', ' ') || 'S IN SCHEMA ' || sch || ' TO ' || tgt
            || IFF(LOWER(r.GO) = 'true', ' WITH GRANT OPTION', '');
    BEGIN
      EXECUTE IMMEDIATE :stmt;
    EXCEPTION WHEN OTHER THEN
      err := SQLERRM; p := r.PRIV; o := r.GRANT_ON; g := r.GRANTEE;
      EXECUTE IMMEDIATE 'UPDATE ' || bak || ' SET REGRANT_ERR = ? WHERE PRIV = ? AND GRANT_ON = ? AND GRANTEE = ?'
        USING (err, p, o, g);
    END;
  END FOR;

  IF (left_cnt > 0) THEN
    RETURN sch || ' ABORT — 회수 후에도 FUTURE ' || left_cnt || '건 잔존(해제 안 함 · 백업 ' || n_bak || '건으로 복원함): ' || left_list;
  END IF;
  IF (alter_err IS NOT NULL) THEN
    RETURN sch || ' ABORT — 해제 실패(FUTURE 백업 ' || n_bak || '건으로 복원함): ' || alter_err;
  END IF;
  RETURN sch || ' DONE — 백업 ' || n_bak || '건';
END;
$$;

-- [4-확인 a] 기대 = 0행(회수·재부여 오류 없음) · 행이 있으면 멈추고 결과를 알려 달라
SELECT 'OPS' AS SCH, * FROM GN_DW.OPS.O272_OPS_FUTURE_GRANTS_BAK WHERE REVOKE_ERR IS NOT NULL OR REGRANT_ERR IS NOT NULL
UNION ALL
SELECT 'SILVER', * FROM GN_DW.OPS.O272_SILVER_FUTURE_GRANTS_BAK WHERE REVOKE_ERR IS NOT NULL OR REGRANT_ERR IS NOT NULL;

-- [4-확인 b] 기대 = 백업 건수와 같은 행 수(스키마별)
SELECT 'OPS' AS SCH, COUNT(*) AS BACKED_UP FROM GN_DW.OPS.O272_OPS_FUTURE_GRANTS_BAK
UNION ALL
SELECT 'SILVER', COUNT(*) FROM GN_DW.OPS.O272_SILVER_FUTURE_GRANTS_BAK;
SHOW FUTURE GRANTS IN SCHEMA GN_DW.OPS;
SHOW FUTURE GRANTS IN SCHEMA GN_DW.SILVER;

-- [4-확인 c] 기대 = GOLD · SERVING · SILVER · OPS 전부 IS_MANAGED_ACCESS = NO
SELECT SCHEMA_NAME, SCHEMA_OWNER, IS_MANAGED_ACCESS
FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('GOLD', 'SERVING', 'SILVER', 'OPS')
ORDER BY 1;

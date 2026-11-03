-- O188-E 설계 실측(읽기 전용) — 활성 조직 트리 규칙 × 사업목표 팀명 매칭률
WITH RECURSIVE b AS (
    SELECT DEPT_ID, DEPT_NM, UPPER_DEPT_ID,
           (USE_YN = 'Y' AND LAST_UPDT_DT IS NOT NULL AND TO_DATE(LAST_UPDT_DT) <> '9999-12-31') AS self_live
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
), t AS (
    SELECT DEPT_ID, DEPT_NM, self_live AS live, 0 AS lvl, CAST('' AS VARCHAR) AS path
    FROM b WHERE UPPER_DEPT_ID NOT IN (SELECT DEPT_ID FROM b) OR UPPER_DEPT_ID IS NULL
    UNION ALL
    SELECT c.DEPT_ID, c.DEPT_NM, t.live AND c.self_live, t.lvl + 1,
           IFF(t.lvl = 0, c.DEPT_NM, t.path || ' > ' || c.DEPT_NM)
    FROM b c JOIN t ON c.UPPER_DEPT_ID = t.DEPT_ID
    WHERE t.lvl < 12
), a AS (SELECT * FROM t WHERE live),
g AS (SELECT DISTINCT TEAM_NM FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV)
SELECT
    (SELECT COUNT(*) FROM a)                                                        AS active_nodes,
    (SELECT COUNT(*) FROM g)                                                        AS goal_teams,
    (SELECT COUNT(*) FROM g WHERE TEAM_NM IN (SELECT DEPT_NM FROM b GROUP BY 1 HAVING COUNT(*) = 1)) AS match_now_unique_all,
    (SELECT COUNT(*) FROM g WHERE TEAM_NM IN (SELECT DEPT_NM FROM a GROUP BY 1 HAVING COUNT(*) = 1)) AS match_active_unique,
    (SELECT COUNT(*) FROM g WHERE TEAM_NM IN (SELECT DEPT_NM FROM a GROUP BY 1 HAVING COUNT(*) > 1)) AS active_dup_name,
    (SELECT COUNT(*) FROM g WHERE TEAM_NM NOT IN (SELECT DEPT_NM FROM a))           AS no_active_match,
    (SELECT LISTAGG(TEAM_NM, ', ') FROM g WHERE TEAM_NM NOT IN (SELECT DEPT_NM FROM a)) AS no_match_list,
    (SELECT LISTAGG(TEAM_NM, ', ') FROM g WHERE TEAM_NM IN (SELECT DEPT_NM FROM a GROUP BY 1 HAVING COUNT(*) > 1)) AS dup_list;

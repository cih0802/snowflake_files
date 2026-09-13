-- ==================================================================================
-- 조직 계층 전개 쿼리 (최상위 ~ 최하위 Leaf 조직 기준 Flat 테이블)
-- 원천 테이블: GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO (또는 사용자 환경의 조직 테이블)
-- 주요 컬럼: DEPT_ID(조직코드), DEPT_NM(조직명), UPPER_DEPT_ID(상위조직코드)
-- ==================================================================================

-- [방법 1] Recursive CTE 방식 (가장 유연하며 가변 Depth 1~6단계 자동 대응)
WITH RECURSIVE org_tree AS (
    -- 1) Anchor: 최상위(Root) 조직 추출
    -- 상위조직코드가 NULL이거나, 공백이거나, 부모 조직이 원장 테이블에 존재하지 않는 경우
    SELECT 
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID,
        USE_YN,
        1 AS LVL,
        ARRAY_CONSTRUCT(DEPT_ID) AS PATH_CD,
        ARRAY_CONSTRUCT(DEPT_NM) AS PATH_NM
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID IS NULL 
       OR UPPER_DEPT_ID = '' 
       OR UPPER_DEPT_ID NOT IN (SELECT DEPT_ID FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO WHERE DEPT_ID IS NOT NULL)
    
    UNION ALL
    
    -- 2) Recursive: 하위 조직 순차 조인 및 경로 확장
    SELECT 
        c.DEPT_ID,
        c.DEPT_NM,
        c.UPPER_DEPT_ID,
        c.USE_YN,
        p.LVL + 1 AS LVL,
        ARRAY_APPEND(p.PATH_CD, c.DEPT_ID),
        ARRAY_APPEND(p.PATH_NM, c.DEPT_NM)
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO c
    JOIN org_tree p 
      ON c.UPPER_DEPT_ID = p.DEPT_ID
    -- WHERE c.UPPER_DEPT_ID NOT LIKE 'Z%'
      -- AND p.DEPT_ID NOT LIKE 'Z%'
),
leaf_orgs AS (
    -- 3) 최하위(Leaf Node) 조직 필터링: 하위 자식 조직이 없는 조직
    SELECT 
        t.*
    FROM org_tree t
    WHERE NOT EXISTS (
        SELECT 1 
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO c 
        WHERE c.UPPER_DEPT_ID = t.DEPT_ID
    )
)
SELECT 
    -- 1단계: 최상위 조직
    PATH_CD[0]::VARCHAR AS LV1_ORG_CD,
    PATH_NM[0]::VARCHAR AS LV1_ORG_NM,
    
    -- 2단계 조직
    PATH_CD[1]::VARCHAR AS LV2_ORG_CD,
    PATH_NM[1]::VARCHAR AS LV2_ORG_NM,
    
    -- 3단계 조직
    PATH_CD[2]::VARCHAR AS LV3_ORG_CD,
    PATH_NM[2]::VARCHAR AS LV3_ORG_NM,
    
    -- 4단계 조직
    PATH_CD[3]::VARCHAR AS LV4_ORG_CD,
    PATH_NM[3]::VARCHAR AS LV4_ORG_NM,
    
    -- 5단계 조직
    PATH_CD[4]::VARCHAR AS LV5_ORG_CD,
    PATH_NM[4]::VARCHAR AS LV5_ORG_NM,
    
    -- 6단계 조직
    PATH_CD[5]::VARCHAR AS LV6_ORG_CD,
    PATH_NM[5]::VARCHAR AS LV6_ORG_NM,
    
    -- 최하위(Leaf) 조직 정보
    DEPT_ID             AS LEAF_ORG_CD,
    DEPT_NM             AS LEAF_ORG_NM,
    LVL                 AS LEAF_DEPTH,
    
    -- 전체 계층 경로 (한눈에 보기용)
    ARRAY_TO_STRING(PATH_NM, ' > ') AS ORG_PATH_NM,
    ARRAY_TO_STRING(PATH_CD, ' > ') AS ORG_PATH_CD
FROM leaf_orgs
ORDER BY 
    PATH_CD[0], PATH_CD[1], PATH_CD[2], PATH_CD[3], PATH_CD[4], PATH_CD[5];


-- ==================================================================================
-- [방법 2] Self LEFT JOIN 다단 방식 (고전적 조인 방식)
-- ==================================================================================
/*
WITH root_nodes AS (
    SELECT * 
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID IS NULL 
       OR UPPER_DEPT_ID = '' 
       OR UPPER_DEPT_ID NOT IN (SELECT DEPT_ID FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO WHERE DEPT_ID IS NOT NULL)
)
SELECT 
    -- LV1 (최상위)
    lv1.DEPT_ID AS LV1_ORG_CD,
    lv1.DEPT_NM AS LV1_ORG_NM,
    -- LV2
    lv2.DEPT_ID AS LV2_ORG_CD,
    lv2.DEPT_NM AS LV2_ORG_NM,
    -- LV3
    lv3.DEPT_ID AS LV3_ORG_CD,
    lv3.DEPT_NM AS LV3_ORG_NM,
    -- LV4
    lv4.DEPT_ID AS LV4_ORG_CD,
    lv4.DEPT_NM AS LV4_ORG_NM,
    -- LV5
    lv5.DEPT_ID AS LV5_ORG_CD,
    lv5.DEPT_NM AS LV5_ORG_NM,
    -- LV6
    lv6.DEPT_ID AS LV6_ORG_CD,
    lv6.DEPT_NM AS LV6_ORG_NM,
    -- 최하위 조직 (COALESCE로 가장 깊은 단계 추출)
    COALESCE(lv6.DEPT_ID, lv5.DEPT_ID, lv4.DEPT_ID, lv3.DEPT_ID, lv2.DEPT_ID, lv1.DEPT_ID) AS LEAF_ORG_CD,
    COALESCE(lv6.DEPT_NM, lv5.DEPT_NM, lv4.DEPT_NM, lv3.DEPT_NM, lv2.DEPT_NM, lv1.DEPT_NM) AS LEAF_ORG_NM
FROM root_nodes lv1
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO lv2 ON lv2.UPPER_DEPT_ID = lv1.DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO lv3 ON lv3.UPPER_DEPT_ID = lv2.DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO lv4 ON lv4.UPPER_DEPT_ID = lv3.DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO lv5 ON lv5.UPPER_DEPT_ID = lv4.DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO lv6 ON lv6.UPPER_DEPT_ID = lv5.DEPT_ID
-- 최하위 노드만 남기기 위한 조건
WHERE NOT EXISTS (
    SELECT 1 
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO c 
    WHERE c.UPPER_DEPT_ID = COALESCE(lv6.DEPT_ID, lv5.DEPT_ID, lv4.DEPT_ID, lv3.DEPT_ID, lv2.DEPT_ID, lv1.DEPT_ID)
);
*/

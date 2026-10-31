연도	목표구분	법인 구분	조직 구분	팀명	신규기존	후원사업구분	상세목표구분	1월 목표치	2월 목표치	3월 목표치	4월 목표치	5월 목표치	6월 목표치	7월 목표치	8월 목표치	9월 목표치	10월 목표치	11월 목표치	12월 목표치
-- 260928 인입 완료. 
CREATE STAGE IF NOT EXISTS GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE
DIRECTORY = (ENABLE = TRUE);
ALTER STAGE GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE SET DIRECTORY = (ENABLE = TRUE);
ALTER STAGE GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE REFRESH;

-- =============================================================================
-- 3 파일 포맷 (GN_CSV_FORMAT_EUCKR) 사용
-- =============================================================================
CREATE FILE FORMAT IF NOT EXISTS GN_DW.BRONZE_CRM.GN_CSV_FORMAT
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

SELECT YEAR, BDGT_PRCD_NM, GOAL_TYPE_NM, CPR_DIV_NM, NEW_OLD_DIV_NM, ORG_DIV_NM, TEAM_NM, SPNSR_BSNS_DIV_NM, M06_GOAL_CNT
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
WHERE BDGT_PRCD_NM = '연사업' AND GOAL_TYPE_NM = '후원사업' AND TEAM_NM = '매체운영팀'

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
WHERE GOAL_TYPE_NM = '월말활동회원'

-- 260930 허지혜 차장 요청
-- SPNSR_BSNS_DIV_NM 전체사업후원 -> 전체사업지원 변경 요청
UPDATE GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV 
SET SPNSR_BSNS_DIV_NM = '전체사업지원'
WHERE SPNSR_BSNS_DIV_NM = '전체사업후원'

create or replace TABLE GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV (
	YEAR VARCHAR(16777216) COMMENT '연도',
    BDGT_PRCD_NM VARCHAR(16777216) COMMENT '예산절차', --260929 컬럼추가
	GOAL_TYPE_NM VARCHAR(16777216) COMMENT '목표구분',
	CPR_DIV_NM VARCHAR(16777216) COMMENT '법인구분',
    NEW_OLD_DIV_NM VARCHAR(16777216) COMMENT '신규기존구분',
    ORG_DIV_NM VARCHAR(16777216) COMMENT '조직구분',
	TEAM_NM VARCHAR(16777216) COMMENT '팀명',
	SPNSR_BSNS_DIV_NM VARCHAR(16777216) COMMENT '후원사업구분',
	DTL_DIV_NM VARCHAR(16777216) COMMENT '상세목표구분',
    --M01_GOAL_CNT FLOAT COMMENT '1월 목표치',
    M01_GOAL_CNT NUMBER(38, 10) COMMENT '1월 목표치',
    M02_GOAL_CNT NUMBER(38, 10) COMMENT '2월 목표치',
    M03_GOAL_CNT NUMBER(38, 10) COMMENT '3월 목표치',
    M04_GOAL_CNT NUMBER(38, 10) COMMENT '4월 목표치',
    M05_GOAL_CNT NUMBER(38, 10) COMMENT '5월 목표치',
    M06_GOAL_CNT NUMBER(38, 10) COMMENT '6월 목표치',
    M07_GOAL_CNT NUMBER(38, 10) COMMENT '7월 목표치',
    M08_GOAL_CNT NUMBER(38, 10) COMMENT '8월 목표치',
    M09_GOAL_CNT NUMBER(38, 10) COMMENT '9월 목표치',
    M10_GOAL_CNT NUMBER(38, 10) COMMENT '10월 목표치',
    M11_GOAL_CNT NUMBER(38, 10) COMMENT '11월 목표치',
    M12_GOAL_CNT NUMBER(38, 10) COMMENT '12월 목표치'
) COMMENT='목표구분별 회원개발목표';

--팀별
COPY INTO GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
FROM (
SELECT
    $1, $2, $3, $4, NULL,
    $5, $6, $7, $8, $9, 
    $10, $11, $12, $13, $14, 
    $15, $16, $17, $18, $19, $20
FROM @GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE
(FILE_FORMAT => 'GN_DW.BRONZE_CRM.GN_CSV_FORMAT', PATTERN => '.*2026_team_goal\\.csv')
)

--후원사업별
COPY INTO GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
FROM (
SELECT
    $1, $2, $3, $4, $5, 
    $6, $7, $8, NULL, $9, 
    $10, $11, $12, $13, $14, 
    $15, $16, $17, $18, $19, $20
FROM @GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE
(FILE_FORMAT => 'GN_DW.BRONZE_CRM.GN_CSV_FORMAT', PATTERN => '.*2026_spnsr_bsns_goal\\.csv')
)


--활동별 260928 추가
COPY INTO GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
FROM (
SELECT
    $1, $2, $3, $4, $5, 
    $6, $7, $8, NULL, $9, 
    $10, $11, $12, $13, $14, 
    $15, $16, $17, $18, $19, $20
FROM @GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE
(FILE_FORMAT => 'GN_DW.BRONZE_CRM.GN_CSV_FORMAT', PATTERN => '.*2026_act_goal\\.csv')
)

--회비별 260928 추가
COPY INTO GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
FROM (
SELECT
    $1, $2, $3, $4, $5, 
    $6, $7, $8, NULL, $9, 
    $10, $11, $12, $13, $14, 
    $15, $16, $17, $18, $19, $20
FROM @GN_DW.BRONZE_CRM.CSV_UPLOAD_STAGE
(FILE_FORMAT => 'GN_DW.BRONZE_CRM.GN_CSV_FORMAT', PATTERN => '.*2026_mbrfee_goal\\.csv')
);

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
GROUP BY GOAL_TYPE_NM



SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV

-- 국내 
SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV;

-- 4 50 
SELECT SPNSR_BSNS_ID, *
FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
WHERE SPNSR_BSNS_NM IN (
    '국내아동권리보호사업(사단법인)'
);


SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
WHERE SPNSR_BSNS_NM IN (
    '국내사업', '국내아동권리보호사업(사단법인)'	
);
SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG a
WHERE MBER_INFLOW_PATH_CD = 4;



SELECT 
    LEFT(OCCRRNC_DE, 6), DVLP_DIV_CD, SPNSR_BSNS_ID, SUM(SPNSR_AMT) / 10000
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT 
WHERE CMPGN_CD IN (
    SELECT a.CMPGN_CD
    FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG a
        LEFT OUTER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD b ON b.CD_ID = 'MM293' and a.MBER_INFLOW_PATH_CD = b.DTL_CD_ID
    WHERE 
        -- a.USE_DEPT_CD = 'D000111'
        -- AND (SPNSR_BSNS_ID = '4' or SPNSR_BSNS_ID = '50')
        b.DTL_CD_ID = '4'    
)
AND SPNSR_BSNS_ID = '4'
AND LEFT(OCCRRNC_DE, 6) = '202608'
GROUP BY 
    LEFT(OCCRRNC_DE, 6), DVLP_DIV_CD, SPNSR_BSNS_ID
ORDER BY SUM(SPNSR_AMT) / 10000


SELECT a.*, c.DTL_CD_ID
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT a
    LEFT OUTER JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG b ON a.CMPGN_CD = b.CMPGN_CD
    LEFT OUTER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD c ON c.CD_ID = 'MM293' and b.MBER_INFLOW_PATH_CD = c.DTL_CD_ID
WHERE a.SPNSR_BSNS_ID = '4'
AND c.DTL_CD_ID = '4'
AND LEFT(a.OCCRRNC_DE, 6) = '202608'

SELECT MBER_INFLOW_PATH_CD, *
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
WHERE SPNSR_BSNS_ID like ('%50')
AND MBER_INFLOW_PATH_CD = '4';

SELECT MBER_INFLOW_PATH_CD, *
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
WHERE CMPGN_CD = 'FA2026031896';
SELECT SPNSR_BSNS_ID, count(*)
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT a
WHERE LEFT(a.OCCRRNC_DE, 6) = '202608'
AND CMPGN_CD = 'FA2026031896'
GROUP BY SPNSR_BSNS_ID

SELECT *
FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
WHERE CD_ID = 'MM293' 
AND MBER_INFLOW_PATH_CD = 'MM293'
--260903 자료 전달받아 시작.
--기존 CRM 목표치 연도/월/부서별/ 개발구분별 목표치
SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL
WHERE STDYY = '2026';


SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO;

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
WHERE DEPT_NM = '교육기관';

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
WHERE DEPT_ID = 'E001140'
ORDER BY DEPT_NM





WITH RECURSIVE ORG_TREE AS (
    -- 최상위 조직
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID,
        0 AS LVL,
        DEPT_NM AS ORG_PATH
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID = 'A000000'

    UNION ALL

    -- 하위 조직
    SELECT
        C.DEPT_ID,
        C.DEPT_NM,
        C.UPPER_DEPT_ID,
        P.LVL + 1 AS LVL,
        P.ORG_PATH || ' > ' || C.DEPT_NM AS ORG_PATH
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN ORG_TREE P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
)
SELECT ORG_PATH
FROM ORG_TREE
WHERE ORG_PATH not like '%폐지%'
GROUP BY ORG_PATH
HAVING count(*) > 1;
-- SELECT
--     DEPT_ID,
--     DEPT_NM,
--     UPPER_DEPT_ID,
--     LVL,
--     ORG_PATH
-- FROM ORG_TREE
-- ORDER BY DEPT_NM;

--260903 자료 전달받아 시작.
WITH RECURSIVE ORG_TREE AS (
    -- 최상위 조직
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID,
        0 AS LVL,
        DEPT_NM AS ORG_PATH,

        -- LEVEL별 조직명
        DEPT_NM AS LVL0_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL1_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL2_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL3_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID = 'A000000'

    UNION ALL

    -- 하위 조직
    SELECT
        C.DEPT_ID,
        C.DEPT_NM,
        C.UPPER_DEPT_ID,
        P.LVL + 1 AS LVL,
        P.ORG_PATH || ' > ' || C.DEPT_NM AS ORG_PATH,

        -- LEVEL별 조직명 유지
        P.LVL0_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 1 THEN C.DEPT_NM
            ELSE P.LVL1_DEPT_NM
        END AS LVL1_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 2 THEN C.DEPT_NM
            ELSE P.LVL2_DEPT_NM
        END AS LVL2_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 3 THEN C.DEPT_NM
            ELSE P.LVL3_DEPT_NM
        END AS LVL3_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 4 THEN C.DEPT_NM
            ELSE P.LVL4_DEPT_NM
        END AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN ORG_TREE P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
    WHERE C.USE_YN = 'Y'    
),
TARGET_ORG AS (
    SELECT
        DEPT_ID
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    UNION ALL

    SELECT
        C.DEPT_ID
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN TARGET_ORG P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
    WHERE C.USE_YN = 'Y'
)
SELECT
    O.DEPT_ID,
    O.DEPT_NM,
    O.UPPER_DEPT_ID,
    O.LVL,
    O.ORG_PATH,
    O.LVL0_DEPT_NM,
    O.LVL1_DEPT_NM,
    O.LVL2_DEPT_NM,
    O.LVL3_DEPT_NM,
    O.LVL4_DEPT_NM
FROM ORG_TREE O
INNER JOIN TARGET_ORG T
    ON O.DEPT_ID = T.DEPT_ID
WHERE T.DEPT_ID = 'D000111'    
ORDER BY O.ORG_PATH;

-- SELECT

--     LVL0_DEPT_NM,
--     LVL1_DEPT_NM,
--     LVL2_DEPT_NM,
--     LVL3_DEPT_NM,
--     LVL4_DEPT_NM,
--     DEPT_ID,
--     DEPT_NM,
--     UPPER_DEPT_ID,
--     LVL,
--     -- ORG_PATH
-- FROM ORG_TREE
-- WHERE 
--     (
--         LVL = 3 
--         AND 
--         LVL3_DEPT_NM IN (
--             '매체운영팀',
--             '마케팅기획1팀',
--             '마케팅기획2팀',
--             '회원참여팀',
--             '컬쳐콘텐츠팀'
--         )   
--     )
--     OR 
--     (
--         LVL = 4 
--         AND 
--         LVL4_DEPT_NM IN (
--             '캠페인기획1팀',
--             '캠페인기획2팀'
--         )  
--     )
-- ORDER BY
--     LVL0_DEPT_NM,
--     LVL1_DEPT_NM,
--     LVL2_DEPT_NM,
--     LVL3_DEPT_NM,
--     LVL4_DEPT_NM;







-- 상위 조직 + 해당 조직 + 하위 조직 전체 조회
SET DEPT_ID = 'D000111';
WITH RECURSIVE ORG_TREE AS (

    /* =========================================================
       1. 전체 조직의 계층정보 생성
       ========================================================= */
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID,
        0 AS LVL,
        DEPT_NM AS ORG_PATH,

        -- LEVEL별 조직명
        DEPT_NM AS LVL0_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL1_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL2_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL3_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID = 'A000000'

    UNION ALL

    SELECT
        C.DEPT_ID,
        C.DEPT_NM,
        C.UPPER_DEPT_ID,
        P.LVL + 1 AS LVL,
        P.ORG_PATH || ' > ' || C.DEPT_NM AS ORG_PATH,

        P.LVL0_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 1 THEN C.DEPT_NM
            ELSE P.LVL1_DEPT_NM
        END AS LVL1_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 2 THEN C.DEPT_NM
            ELSE P.LVL2_DEPT_NM
        END AS LVL2_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 3 THEN C.DEPT_NM
            ELSE P.LVL3_DEPT_NM
        END AS LVL3_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 4 THEN C.DEPT_NM
            ELSE P.LVL4_DEPT_NM
        END AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN ORG_TREE P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
),
/* =========================================================
   2. 입력한 DEPT_ID의 상위 조직 찾기
   ========================================================= */
UPPER_ORG AS (

    -- 기준 조직
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO

    WHERE DEPT_ID = $DEPT_ID

    UNION ALL

    -- 상위 조직으로 올라감
    SELECT
        P.DEPT_ID,
        P.DEPT_NM,
        P.UPPER_DEPT_ID

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO P

    INNER JOIN UPPER_ORG C
        ON P.DEPT_ID = C.UPPER_DEPT_ID
),


/* =========================================================
   3. 입력한 DEPT_ID의 하위 조직 찾기
   ========================================================= */
LOWER_ORG AS (

    -- 기준 조직
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO

    WHERE DEPT_ID = $DEPT_ID

    UNION ALL

    -- 하위 조직으로 내려감
    SELECT
        C.DEPT_ID,
        C.DEPT_NM,
        C.UPPER_DEPT_ID

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C

    INNER JOIN LOWER_ORG P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
),


/* =========================================================
   4. 상위 + 기준 + 하위 조직 합치기
   ========================================================= */
TARGET_ORG AS (

    SELECT DEPT_ID
    FROM UPPER_ORG

    UNION

    SELECT DEPT_ID
    FROM LOWER_ORG
)
/* =========================================================
   5. 최종 조회
   ========================================================= */
SELECT
    O.DEPT_ID,
    O.DEPT_NM,
    O.UPPER_DEPT_ID,
    O.LVL,

    O.LVL0_DEPT_NM,
    O.LVL1_DEPT_NM,
    O.LVL2_DEPT_NM,
    O.LVL3_DEPT_NM,
    O.LVL4_DEPT_NM,

    O.ORG_PATH

FROM ORG_TREE O

INNER JOIN TARGET_ORG T
    ON O.DEPT_ID = T.DEPT_ID

ORDER BY
    O.LVL0_DEPT_NM,
    O.LVL1_DEPT_NM,
    O.LVL2_DEPT_NM,
    O.LVL3_DEPT_NM,
    O.LVL4_DEPT_NM;    


-- 매체운영팀. D000111 하위부서 없음. 
-- 마케팅기획1팀 F001050 하위부서 없음. 
-- 마케팅기획2팀 D000023 하위부서 없음. 
-- 컬쳐콘텐츠팀. 나마본. 왜 2개있음? 둘다 사용중임. E001176 E001188 둘다 사용중임. 
SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
WHERE DEPT_NM = '컬쳐콘텐츠팀'

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
WHERE DEPT_ID = 'E001188';

SELECT *
FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
WHERE UPPER_DEPT_ID = 'E001188'


SET TARGET_DEPT_ID = 'D000111';

WITH RECURSIVE ORG_TREE AS (
    -- 최상위 조직
    SELECT
        DEPT_ID,
        DEPT_NM,
        UPPER_DEPT_ID,
        0 AS LVL,
        DEPT_NM AS ORG_PATH,

        DEPT_NM AS LVL0_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL1_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL2_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL3_DEPT_NM,
        CAST(NULL AS VARCHAR) AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE UPPER_DEPT_ID = 'A000000'

    UNION ALL

    -- 하위 조직
    SELECT
        C.DEPT_ID,
        C.DEPT_NM,
        C.UPPER_DEPT_ID,
        P.LVL + 1 AS LVL,
        P.ORG_PATH || ' > ' || C.DEPT_NM AS ORG_PATH,

        P.LVL0_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 1 THEN C.DEPT_NM
            ELSE P.LVL1_DEPT_NM
        END AS LVL1_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 2 THEN C.DEPT_NM
            ELSE P.LVL2_DEPT_NM
        END AS LVL2_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 3 THEN C.DEPT_NM
            ELSE P.LVL3_DEPT_NM
        END AS LVL3_DEPT_NM,

        CASE
            WHEN P.LVL + 1 = 4 THEN C.DEPT_NM
            ELSE P.LVL4_DEPT_NM
        END AS LVL4_DEPT_NM

    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN ORG_TREE P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
    WHERE C.USE_YN = 'Y'
),

TARGET_ORG AS (
    -- 지정 조직
    SELECT
        DEPT_ID
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    WHERE DEPT_ID = $TARGET_DEPT_ID

    UNION ALL

    -- 지정 조직의 하위 조직
    SELECT
        C.DEPT_ID
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
    INNER JOIN TARGET_ORG P
        ON C.UPPER_DEPT_ID = P.DEPT_ID
    WHERE C.USE_YN = 'Y'
)

SELECT
    O.DEPT_ID,
    O.DEPT_NM,
    O.UPPER_DEPT_ID,
    O.LVL,
    O.ORG_PATH,
    O.LVL0_DEPT_NM,
    O.LVL1_DEPT_NM,
    O.LVL2_DEPT_NM,
    O.LVL3_DEPT_NM,
    O.LVL4_DEPT_NM
FROM ORG_TREE O
INNER JOIN TARGET_ORG T
    ON O.DEPT_ID = T.DEPT_ID
ORDER BY O.ORG_PATH;    
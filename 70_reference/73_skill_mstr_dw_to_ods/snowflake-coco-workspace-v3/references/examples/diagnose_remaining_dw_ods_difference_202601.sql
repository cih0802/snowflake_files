/*
    목적
      ods_fee_forecast_decrease_new_old_202601.sql 실행 결과에서 남은
      202601 / I의 차이를 행 단위로 찾는다.

    현재 확인된 차이
      - 활동 행        : DW 689,677 / ODS 689,678 (+1)
      - 활동 회원      : 양쪽 616,418
      - 활동 금액건수  : 소수점 자료형 차이를 제외하면 동일
      - 감액 행/회원   : 양쪽 1,316
      - 감액 금액건수  : DW 2,923.3702 / ODS 2,924.8702 (+1.5000)

    실행 방법
      1) ods_fee_forecast_decrease_new_old_202601.sql을 먼저 실행한다.
      2) 같은 SSMS 쿼리 창(같은 세션)에서 이 파일을 실행한다.
         #ACTIVE_FACT와 #DECREASE_FACT가 세션 임시테이블이기 때문이다.

    주의
      - 이 파일은 원인 진단용이므로 MSTR_DW와 MSTR_ODS를 함께 조회한다.
      - 데이터 변경은 전혀 수행하지 않는다.
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @DIAG_STRD_MT    CHAR(6)     = '202601';
DECLARE @DIAG_CPR_DIV_CD VARCHAR(10) = 'I';
DECLARE @DIAG_MONTH_31   CHAR(8)     = @DIAG_STRD_MT + '31';

IF OBJECT_ID('tempdb..#ACTIVE_FACT') IS NULL
   OR OBJECT_ID('tempdb..#DECREASE_FACT') IS NULL
BEGIN
    THROW 50011,
          N'먼저 ods_fee_forecast_decrease_new_old_202601.sql을 같은 SSMS 쿼리 창에서 실행해야 합니다.',
          1;
END;

IF DB_ID(N'MSTR_DW') IS NULL
BEGIN
    THROW 50012, N'MSTR_DW 데이터베이스를 찾을 수 없습니다.', 1;
END;

DROP TABLE IF EXISTS #ACTIVE_DIFF_KEYS;
DROP TABLE IF EXISTS #DECREASE_DIFF_MEMBERS;
DROP TABLE IF EXISTS #SOURCE_DIFF;

/* -------------------------------------------------------------------------
   결과 1. 활동 팩트 차이 요약
      안정적인 업무키인 회원+후원번호+후원사업번호로 먼저 비교한다.
      금액은 DECIMAL(38,7)로 맞춰 DW의 부동소수점 표시 오차를 제외한다.
   ------------------------------------------------------------------------- */
;WITH ODS_ACTIVE AS
(
    SELECT
        A.MBER_NO,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO,
        COUNT_BIG(*) AS ODS_ROW_CNT,
        SUM(CAST(A.SPNSR_AMT_CNT AS DECIMAL(38, 7))) AS ODS_AMT_CNT,
        MIN(A.SPNSR_BSNS_ID) AS ODS_SPNSR_BSNS_ID,
        MIN(A.DEPT4_ID) AS ODS_DEPT4_ID,
        MIN(A.NEW_OLD_DIV_CD) AS ODS_NEW_OLD_DIV_CD
    FROM #ACTIVE_FACT A
    WHERE A.STRD_MT = @DIAG_STRD_MT
      AND A.CPR_DIV_CD = @DIAG_CPR_DIV_CD
    GROUP BY
        A.MBER_NO,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO
),
DW_ACTIVE AS
(
    SELECT
        F.MBER_NO,
        F.SPNSR_NO,
        F.SPNSR_BSNS_NO,
        COUNT_BIG(*) AS DW_ROW_CNT,
        SUM(CAST(F.SPNSR_AMT_CNT AS DECIMAL(38, 7))) AS DW_AMT_CNT,
        MIN(F.SPNSR_BSNS_ID) AS DW_SPNSR_BSNS_ID,
        MIN(F.ACMSLT_DEPT4_CD) AS DW_DEPT4_ID,
        MIN(F.NEW_OLD_DIV_CD) AS DW_NEW_OLD_DIV_CD
    FROM MSTR_DW.mart.F_MM_SPNSR_ACT F
    WHERE F.STRD_MT = @DIAG_STRD_MT
      AND F.CPR_DIV_CD = @DIAG_CPR_DIV_CD
      AND F.ACT_DSCNTC_DIV_CD = '1'
    GROUP BY
        F.MBER_NO,
        F.SPNSR_NO,
        F.SPNSR_BSNS_NO
)
SELECT
    CASE
        WHEN D.DW_ROW_CNT IS NULL THEN 'ODS_ONLY'
        WHEN O.ODS_ROW_CNT IS NULL THEN 'DW_ONLY'
        WHEN O.ODS_ROW_CNT <> D.DW_ROW_CNT THEN 'ROW_COUNT_DIFF'
        WHEN O.ODS_AMT_CNT <> D.DW_AMT_CNT THEN 'AMOUNT_DIFF'
        ELSE 'DIMENSION_DIFF'
    END AS DIFF_TYPE,
    COALESCE(O.MBER_NO, D.MBER_NO) AS MBER_NO,
    COALESCE(O.SPNSR_NO, D.SPNSR_NO) AS SPNSR_NO,
    COALESCE(O.SPNSR_BSNS_NO, D.SPNSR_BSNS_NO) AS SPNSR_BSNS_NO,
    O.ODS_ROW_CNT,
    D.DW_ROW_CNT,
    O.ODS_AMT_CNT,
    D.DW_AMT_CNT,
    ISNULL(O.ODS_AMT_CNT, 0) - ISNULL(D.DW_AMT_CNT, 0) AS AMT_DIFF_CNT,
    O.ODS_SPNSR_BSNS_ID,
    D.DW_SPNSR_BSNS_ID,
    O.ODS_DEPT4_ID,
    D.DW_DEPT4_ID,
    O.ODS_NEW_OLD_DIV_CD,
    D.DW_NEW_OLD_DIV_CD
INTO #ACTIVE_DIFF_KEYS
FROM ODS_ACTIVE O
FULL OUTER JOIN DW_ACTIVE D
  ON O.MBER_NO = D.MBER_NO
 AND O.SPNSR_NO = D.SPNSR_NO
 AND O.SPNSR_BSNS_NO = D.SPNSR_BSNS_NO
WHERE O.ODS_ROW_CNT IS NULL
   OR D.DW_ROW_CNT IS NULL
   OR O.ODS_ROW_CNT <> D.DW_ROW_CNT
   OR O.ODS_AMT_CNT <> D.DW_AMT_CNT
   OR ISNULL(O.ODS_SPNSR_BSNS_ID, '') <> ISNULL(D.DW_SPNSR_BSNS_ID, '')
   OR ISNULL(O.ODS_DEPT4_ID, '') <> ISNULL(D.DW_DEPT4_ID, '')
   OR ISNULL(O.ODS_NEW_OLD_DIV_CD, '') <> ISNULL(D.DW_NEW_OLD_DIV_CD, '');

SELECT
    DIFF_TYPE,
    COUNT_BIG(*) AS DIFF_KEY_CNT,
    SUM(ISNULL(ODS_ROW_CNT, 0) - ISNULL(DW_ROW_CNT, 0)) AS ROW_DIFF_CNT,
    SUM(ISNULL(ODS_AMT_CNT, 0) - ISNULL(DW_AMT_CNT, 0)) AS AMT_DIFF_CNT
FROM #ACTIVE_DIFF_KEYS
GROUP BY DIFF_TYPE
ORDER BY DIFF_TYPE;

/* -------------------------------------------------------------------------
   결과 2. 활동 차이 상세
   ------------------------------------------------------------------------- */
SELECT *
FROM #ACTIVE_DIFF_KEYS
ORDER BY
    ABS(AMT_DIFF_CNT) DESC,
    MBER_NO,
    SPNSR_NO,
    SPNSR_BSNS_NO;

/* -------------------------------------------------------------------------
   결과 3. 감액 팩트 차이 요약
      202601/I는 양쪽 모두 회원별 1행이므로 회원번호로 직접 비교한다.
   ------------------------------------------------------------------------- */
;WITH ODS_DECREASE AS
(
    SELECT
        D.MBER_NO,
        COUNT_BIG(*) AS ODS_ROW_CNT,
        SUM(CAST(D.SPNSR_AMT_CNT AS DECIMAL(38, 7))) AS ODS_AMT_CNT,
        MIN(D.SPNSR_NO) AS ODS_SPNSR_NO,
        MIN(D.SPNSR_BSNS_NO) AS ODS_SPNSR_BSNS_NO,
        MIN(D.SPNSR_BSNS_ID) AS ODS_SPNSR_BSNS_ID,
        MIN(D.DEPT4_ID) AS ODS_DEPT4_ID,
        MIN(D.NEW_OLD_DIV_CD) AS ODS_NEW_OLD_DIV_CD
    FROM #DECREASE_FACT D
    WHERE D.STRD_MT = @DIAG_STRD_MT
      AND D.CPR_DIV_CD = @DIAG_CPR_DIV_CD
    GROUP BY D.MBER_NO
),
DW_DECREASE AS
(
    SELECT
        F.MBER_NO,
        COUNT_BIG(*) AS DW_ROW_CNT,
        SUM(CAST(F.SPNSR_AMT_CNT AS DECIMAL(38, 7))) AS DW_AMT_CNT,
        MIN(F.SPNSR_NO) AS DW_SPNSR_NO,
        MIN(F.SPNSR_BSNS_NO) AS DW_SPNSR_BSNS_NO,
        MIN(F.SPNSR_BSNS_ID) AS DW_SPNSR_BSNS_ID,
        MIN(F.ACMSLT_DEPT4_CD) AS DW_DEPT4_ID,
        MIN(F.NEW_OLD_DIV_CD) AS DW_NEW_OLD_DIV_CD
    FROM MSTR_DW.mart.F_MM_SPNSR_ACT F
    WHERE F.STRD_MT = @DIAG_STRD_MT
      AND F.CPR_DIV_CD = @DIAG_CPR_DIV_CD
      AND F.ACT_DSCNTC_DIV_CD = '4'
    GROUP BY F.MBER_NO
)
SELECT
    CASE
        WHEN W.DW_ROW_CNT IS NULL THEN 'ODS_ONLY'
        WHEN O.ODS_ROW_CNT IS NULL THEN 'DW_ONLY'
        WHEN O.ODS_ROW_CNT <> W.DW_ROW_CNT THEN 'ROW_COUNT_DIFF'
        WHEN O.ODS_AMT_CNT <> W.DW_AMT_CNT THEN 'AMOUNT_DIFF'
        ELSE 'KEY_OR_DIMENSION_DIFF'
    END AS DIFF_TYPE,
    COALESCE(O.MBER_NO, W.MBER_NO) AS MBER_NO,
    O.ODS_ROW_CNT,
    W.DW_ROW_CNT,
    O.ODS_AMT_CNT,
    W.DW_AMT_CNT,
    ISNULL(O.ODS_AMT_CNT, 0) - ISNULL(W.DW_AMT_CNT, 0) AS SIGNED_AMT_DIFF_CNT,
    ABS(ISNULL(O.ODS_AMT_CNT, 0)) - ABS(ISNULL(W.DW_AMT_CNT, 0)) AS ABS_AMT_DIFF_CNT,
    O.ODS_SPNSR_NO,
    W.DW_SPNSR_NO,
    O.ODS_SPNSR_BSNS_NO,
    W.DW_SPNSR_BSNS_NO,
    O.ODS_SPNSR_BSNS_ID,
    W.DW_SPNSR_BSNS_ID,
    O.ODS_DEPT4_ID,
    W.DW_DEPT4_ID,
    O.ODS_NEW_OLD_DIV_CD,
    W.DW_NEW_OLD_DIV_CD
INTO #DECREASE_DIFF_MEMBERS
FROM ODS_DECREASE O
FULL OUTER JOIN DW_DECREASE W
  ON O.MBER_NO = W.MBER_NO
WHERE O.ODS_ROW_CNT IS NULL
   OR W.DW_ROW_CNT IS NULL
   OR O.ODS_ROW_CNT <> W.DW_ROW_CNT
   OR O.ODS_AMT_CNT <> W.DW_AMT_CNT
   OR ISNULL(CONVERT(VARCHAR(100), O.ODS_SPNSR_NO), '')
      <> ISNULL(CONVERT(VARCHAR(100), W.DW_SPNSR_NO), '')
   OR ISNULL(CONVERT(VARCHAR(100), O.ODS_SPNSR_BSNS_NO), '')
      <> ISNULL(CONVERT(VARCHAR(100), W.DW_SPNSR_BSNS_NO), '')
   OR ISNULL(O.ODS_SPNSR_BSNS_ID, '') <> ISNULL(W.DW_SPNSR_BSNS_ID, '')
   OR ISNULL(O.ODS_DEPT4_ID, '') <> ISNULL(W.DW_DEPT4_ID, '')
   OR ISNULL(O.ODS_NEW_OLD_DIV_CD, '') <> ISNULL(W.DW_NEW_OLD_DIV_CD, '');

SELECT
    DIFF_TYPE,
    COUNT_BIG(*) AS DIFF_MBER_CNT,
    SUM(ISNULL(ODS_ROW_CNT, 0) - ISNULL(DW_ROW_CNT, 0)) AS ROW_DIFF_CNT,
    SUM(ABS_AMT_DIFF_CNT) AS ABS_AMT_DIFF_CNT
FROM #DECREASE_DIFF_MEMBERS
GROUP BY DIFF_TYPE
ORDER BY DIFF_TYPE;

/* -------------------------------------------------------------------------
   결과 4. 감액 차이 상세
      ABS_AMT_DIFF_CNT의 합이 현재 확인된 +1.5000000이어야 한다.
   ------------------------------------------------------------------------- */
SELECT *
FROM #DECREASE_DIFF_MEMBERS
ORDER BY
    ABS(ABS_AMT_DIFF_CNT) DESC,
    MBER_NO;

/* -------------------------------------------------------------------------
   결과 5. 차이 대상의 ODS 현재 원천과 DW 월별 원천 스냅샷 비교

      결과가 나오면:
        ODS_ONLY / DW_ONLY / AMOUNT_OR_CODE_DIFF
          -> 월마감 후 ODS 과거 원천의 추가·삭제·수정 가능성이 높다.

      결과가 0행이면:
          -> 원천행 자체보다 활동회원, 결제법인, 사업/부서 차원 또는
             월마감 적재 시점 조인을 추가로 비교해야 한다.
   ------------------------------------------------------------------------- */
;WITH ODS_SOURCE AS
(
    SELECT
        A.OCCRRNC_DE,
        A.MBER_NO,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO,
        A.SER_NO,
        COUNT_BIG(*) AS ODS_ROW_CNT,
        SUM(CAST(A.SPNSR_AMT AS DECIMAL(38, 4))) AS ODS_SPNSR_AMT,
        MIN(A.DVLP_DIV_CD) AS ODS_DVLP_DIV_CD,
        MAX(A.DVLP_DIV_CD) AS ODS_DVLP_DIV_CD_MAX,
        MIN(A.SPNSR_BSNS_ID) AS ODS_SPNSR_BSNS_ID,
        MAX(A.SPNSR_BSNS_ID) AS ODS_SPNSR_BSNS_ID_MAX,
        MIN(A.ACMSLT_DEPT_CD) AS ODS_ACMSLT_DEPT_CD,
        MAX(A.ACMSLT_DEPT_CD) AS ODS_ACMSLT_DEPT_CD_MAX
    FROM MSTR_ODS.dbo.TM_MM_FDRM_MBER_DVLP_AMT A
    WHERE A.OCCRRNC_DE <= @DIAG_MONTH_31
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM #ACTIVE_DIFF_KEYS K
              WHERE K.MBER_NO = A.MBER_NO
                AND K.SPNSR_NO = A.SPNSR_NO
                AND K.SPNSR_BSNS_NO = A.SPNSR_BSNS_NO
          )
          OR
          (
              LEFT(A.OCCRRNC_DE, 6) = @DIAG_STRD_MT
              AND EXISTS
              (
                  SELECT 1
                  FROM #DECREASE_DIFF_MEMBERS M
                  WHERE M.MBER_NO = A.MBER_NO
              )
          )
      )
    GROUP BY
        A.OCCRRNC_DE,
        A.MBER_NO,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO,
        A.SER_NO
),
DW_SOURCE AS
(
    SELECT
        F.OCCRRNC_DE,
        F.MBER_NO,
        F.SPNSR_NO,
        F.SPNSR_BSNS_NO,
        F.SER_NO,
        COUNT_BIG(*) AS DW_ROW_CNT,
        SUM(CAST(F.SPNSR_AMT AS DECIMAL(38, 4))) AS DW_SPNSR_AMT,
        MIN(F.DVLP_DIV_CD) AS DW_DVLP_DIV_CD,
        MAX(F.DVLP_DIV_CD) AS DW_DVLP_DIV_CD_MAX,
        MIN(F.SPNSR_BSNS_ID) AS DW_SPNSR_BSNS_ID,
        MAX(F.SPNSR_BSNS_ID) AS DW_SPNSR_BSNS_ID_MAX,
        MIN(F.ACMSLT_DEPT_CD) AS DW_ACMSLT_DEPT_CD,
        MAX(F.ACMSLT_DEPT_CD) AS DW_ACMSLT_DEPT_CD_MAX
    FROM MSTR_DW.mart.F_MM_SPNSR_DVLP F
    WHERE F.STRD_MT <= @DIAG_STRD_MT
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM #ACTIVE_DIFF_KEYS K
              WHERE K.MBER_NO = F.MBER_NO
                AND K.SPNSR_NO = F.SPNSR_NO
                AND K.SPNSR_BSNS_NO = F.SPNSR_BSNS_NO
          )
          OR
          (
              F.STRD_MT = @DIAG_STRD_MT
              AND EXISTS
              (
                  SELECT 1
                  FROM #DECREASE_DIFF_MEMBERS M
                  WHERE M.MBER_NO = F.MBER_NO
              )
          )
      )
    GROUP BY
        F.OCCRRNC_DE,
        F.MBER_NO,
        F.SPNSR_NO,
        F.SPNSR_BSNS_NO,
        F.SER_NO
)
SELECT
    CASE
        WHEN W.DW_ROW_CNT IS NULL THEN 'ODS_ONLY'
        WHEN O.ODS_ROW_CNT IS NULL THEN 'DW_ONLY'
        WHEN O.ODS_ROW_CNT <> W.DW_ROW_CNT THEN 'ROW_COUNT_DIFF'
        ELSE 'AMOUNT_OR_CODE_DIFF'
    END AS DIFF_TYPE,
    COALESCE(O.OCCRRNC_DE, W.OCCRRNC_DE) AS OCCRRNC_DE,
    COALESCE(O.MBER_NO, W.MBER_NO) AS MBER_NO,
    COALESCE(O.SPNSR_NO, W.SPNSR_NO) AS SPNSR_NO,
    COALESCE(O.SPNSR_BSNS_NO, W.SPNSR_BSNS_NO) AS SPNSR_BSNS_NO,
    COALESCE(O.SER_NO, W.SER_NO) AS SER_NO,
    O.ODS_ROW_CNT,
    W.DW_ROW_CNT,
    O.ODS_SPNSR_AMT,
    W.DW_SPNSR_AMT,
    ISNULL(O.ODS_SPNSR_AMT, 0) - ISNULL(W.DW_SPNSR_AMT, 0) AS SPNSR_AMT_DIFF,
    O.ODS_DVLP_DIV_CD,
    W.DW_DVLP_DIV_CD,
    O.ODS_DVLP_DIV_CD_MAX,
    W.DW_DVLP_DIV_CD_MAX,
    O.ODS_SPNSR_BSNS_ID,
    W.DW_SPNSR_BSNS_ID,
    O.ODS_SPNSR_BSNS_ID_MAX,
    W.DW_SPNSR_BSNS_ID_MAX,
    O.ODS_ACMSLT_DEPT_CD,
    W.DW_ACMSLT_DEPT_CD,
    O.ODS_ACMSLT_DEPT_CD_MAX,
    W.DW_ACMSLT_DEPT_CD_MAX
INTO #SOURCE_DIFF
FROM ODS_SOURCE O
FULL OUTER JOIN DW_SOURCE W
  ON O.OCCRRNC_DE = W.OCCRRNC_DE
 AND O.MBER_NO = W.MBER_NO
 AND O.SPNSR_NO = W.SPNSR_NO
 AND O.SPNSR_BSNS_NO = W.SPNSR_BSNS_NO
 AND O.SER_NO = W.SER_NO
WHERE O.ODS_ROW_CNT IS NULL
   OR W.DW_ROW_CNT IS NULL
   OR O.ODS_ROW_CNT <> W.DW_ROW_CNT
   OR O.ODS_SPNSR_AMT <> W.DW_SPNSR_AMT
   OR ISNULL(O.ODS_DVLP_DIV_CD, '') <> ISNULL(W.DW_DVLP_DIV_CD, '')
   OR ISNULL(O.ODS_DVLP_DIV_CD_MAX, '') <> ISNULL(W.DW_DVLP_DIV_CD_MAX, '')
   OR ISNULL(O.ODS_SPNSR_BSNS_ID, '') <> ISNULL(W.DW_SPNSR_BSNS_ID, '')
   OR ISNULL(O.ODS_SPNSR_BSNS_ID_MAX, '') <> ISNULL(W.DW_SPNSR_BSNS_ID_MAX, '')
   OR ISNULL(O.ODS_ACMSLT_DEPT_CD, '') <> ISNULL(W.DW_ACMSLT_DEPT_CD, '')
   OR ISNULL(O.ODS_ACMSLT_DEPT_CD_MAX, '') <> ISNULL(W.DW_ACMSLT_DEPT_CD_MAX, '');

SELECT
    DIFF_TYPE,
    COUNT_BIG(*) AS DIFF_SOURCE_KEY_CNT,
    SUM(ISNULL(ODS_ROW_CNT, 0) - ISNULL(DW_ROW_CNT, 0)) AS ROW_DIFF_CNT,
    SUM(SPNSR_AMT_DIFF) AS SPNSR_AMT_DIFF
FROM #SOURCE_DIFF
GROUP BY DIFF_TYPE
ORDER BY DIFF_TYPE;

/* -------------------------------------------------------------------------
   결과 6. 원천 차이 상세
   ------------------------------------------------------------------------- */
SELECT *
FROM #SOURCE_DIFF
ORDER BY
    ABS(SPNSR_AMT_DIFF) DESC,
    MBER_NO,
    SPNSR_NO,
    SPNSR_BSNS_NO,
    OCCRRNC_DE,
    SER_NO;

/* -------------------------------------------------------------------------
   결과 7. ODS 원천 테이블의 시간 관련 컬럼
      원천 차이가 확인되면 과거 시점 필터를 만들 수 있는 등록/수정일 컬럼이
      존재하는지 확인한다.
   ------------------------------------------------------------------------- */
SELECT
    C.column_id,
    C.name AS COLUMN_NAME,
    T.name AS DATA_TYPE,
    C.max_length,
    C.precision,
    C.scale
FROM MSTR_ODS.sys.columns C
JOIN MSTR_ODS.sys.types T
  ON C.user_type_id = T.user_type_id
WHERE C.object_id = OBJECT_ID(N'MSTR_ODS.dbo.TM_MM_FDRM_MBER_DVLP_AMT')
  AND
  (
      C.name LIKE '%REGIST%'
      OR C.name LIKE '%UPDT%'
      OR C.name LIKE '%WORK%'
      OR C.name LIKE '%DATE%'
      OR C.name LIKE '%\_DT' ESCAPE '\'
      OR C.name LIKE '%\_DE' ESCAPE '\'
  )
ORDER BY C.column_id;


/*
    보고서
      01.부서별 회원개발

    목적
      - MSTR_DW / MART 객체를 참조하지 않고 MSTR_ODS(CRM) 원천만 사용
      - dbo.FN_MM_SPNSR_DVLP + mart.USP_F_MM_SPNSR_DVLP_SUM의
        보고서용 개발구분 1/2/4 계산을 재현

    원본 MSTR 지표
      WJXBFS1 : 선택월 개발(건)      = SUM(SPNSR_AMT_CNT)
      WJXBFS2 : 선택월 개발회원(명)  = COUNT(DISTINCT MBER_NO)
      WJXBFS3 : 선택월 개발금액(원)  = SUM(SPNSR_AMT)
      WJXBFS4 : 당해연도 누계개발(건)
      WJXBFS5 : 당해연도 누계개발회원(명)

    2026년 6월 MSTR 전체법인 참고값
      DVLP_DIV_CD  FACT_ROW_CNT  MBER_CNT  SPNSR_AMT_CNT  SPNSR_AMT
      1            12,832        11,969    25,713.8900    257,138,900
      2             2,318         2,014     4,999.9501     49,999,501
      4             1,605         1,465     3,350.7500     33,507,500

    검증 결과 (2026-08-19, MSTR_ODS 실행)
      - 개발구분 1/2/4의 FACT_ROW_CNT, MBER_CNT,
        SPNSR_AMT_CNT, SPNSR_AMT가 위 MSTR 기준값과 모두 일치
      - 12개 비교항목의 차이값이 모두 0
      - 법인 I의 선택월 상세 301개 키를 원본 MSTR 상세와 대사:
        누락/추가 키 0, WJXBFS1~3 차이 키 0

    별도 대사가 남은 범위
      - WJXBFS4/5(당해연도 누계)는 D_STRD_ADD_MT_CD 정의대로 재현했으나,
        원본 MSTR의 동일 조건 누계 결과값과는 아직 독립 대사하지 않음

    핵심 계산
      1. 신규/재후원(1/4)
         - 후원번호+후원사업번호+월별 금액합계가 양수
         - 해당 월 말일 이후까지 유지되는 후원사업만 포함

      2. 증액(2)
         - CRM 원천 개발구분 2/3/5를 회원+월 단위로 순액 계산
         - 회원 월 순액이 양수인 회원만 포함
         - 후원번호+후원사업번호 단위 증감과 회원 누적금액을 이용해
           FN_MM_SPNSR_DVLP의 RAMT 배분식을 동일하게 적용
         - 후원번호+후원사업번호+월별 SER_NO 오름차순 첫 행에 배분금액 귀속

      3. 누계
         - D_STRD_ADD_MT_CD와 동일하게 기준연도의 1월~기준월
         - 누계회원은 월별 회원 수의 합이 아니라 전체 기간 DISTINCT 회원 수

    운영 확장 시 확인사항
      - MART.D_SPNSR_BSNS_V의 DSC_DE를 CRM의
        TM_MM_FDRM_MBER_SPNSR_BSNS.SPNSR_DSCNTC_DE로 재현했다.
        202606 대사값은 일치했다. 다른 기간까지 일반화할 때 해당 뷰가
        DSC_DE를 별도로 가공하는지 정의를 확인하면 장기 운영 안정성을 높일 수 있다.
*/

USE MSTR_ODS;
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @STRD_MT       CHAR(6)     = '202606';
DECLARE @CPR_DIV_CD    VARCHAR(10) = 'I';  -- NULL이면 법인 전체
DECLARE @DEBUG         BIT         = 0;    -- 운영 0, 개발구분별 MSTR 참고값 재대사 시 1
DECLARE @YEAR_START_MT CHAR(6)     = LEFT(@STRD_MT, 4) + '01';

IF @STRD_MT NOT LIKE '[12][0-9][0-9][0-9][01][0-9]'
   OR RIGHT(@STRD_MT, 2) NOT BETWEEN '01' AND '12'
BEGIN
    THROW 50001, N'@STRD_MT는 YYYYMM 형식의 유효한 기준년월이어야 합니다.', 1;
END;

DROP TABLE IF EXISTS #DEPT_DIM;
DROP TABLE IF EXISTS #DEPT3_DIM;
DROP TABLE IF EXISTS #DEPT4_DIM;
DROP TABLE IF EXISTS #CPR_DIM;
DROP TABLE IF EXISTS #ABRV_DIM;
DROP TABLE IF EXISTS #DVLP_DIM;
DROP TABLE IF EXISTS #BUSINESS_DIM;
DROP TABLE IF EXISTS #DVLP_SOURCE;
DROP TABLE IF EXISTS #DVLP_FACT;
DROP TABLE IF EXISTS #MONTH_AGG;
DROP TABLE IF EXISTS #YTD_AGG;

/* -------------------------------------------------------------------------
   1. 부서 차원 재현
      MART.D_DEPT_CD / D_DEPT3_CD / D_DEPT4_CD 정의와 동일한 계층 사용
   ------------------------------------------------------------------------- */
SELECT
    E.DEPT_ID,
    E.DEPT_NM,
    D.DEPT_ID AS DEPT2_ID,
    C.DEPT_ID AS DEPT3_ID,
    B.DEPT_ID AS DEPT4_ID,
    E.SORT_ORDR
INTO #DEPT_DIM
FROM dbo.TM_CM_DEPT_INFO A
JOIN dbo.TM_CM_DEPT_INFO B
  ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
JOIN dbo.TM_CM_DEPT_INFO C
  ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
JOIN dbo.TM_CM_DEPT_INFO D
  ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
JOIN dbo.TM_CM_DEPT_INFO E
  ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
WHERE A.UPPER_DEPT_ID = 'ZV000000'
  AND C.DEPT_ID <> 'ZC000029';

INSERT INTO #DEPT_DIM
(
    DEPT_ID, DEPT_NM, DEPT2_ID, DEPT3_ID, DEPT4_ID, SORT_ORDR
)
VALUES
(
    'Z~', N'없음', 'Z~', 'Z~', 'Z~', 999
);

CREATE INDEX IX_DEPT_DIM_ID ON #DEPT_DIM (DEPT_ID);

SELECT
    C.DEPT_ID AS DEPT3_ID,
    C.DEPT_NM AS DEPT3_NM,
    B.DEPT_ID AS DEPT4_ID,
    C.SORT_ORDR
INTO #DEPT3_DIM
FROM dbo.TM_CM_DEPT_INFO A
JOIN dbo.TM_CM_DEPT_INFO B
  ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
JOIN dbo.TM_CM_DEPT_INFO C
  ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
WHERE A.UPPER_DEPT_ID = 'ZV000000'
  AND A.USE_YN = 'Y'
  AND C.DEPT_ID <> 'ZC000029';

INSERT INTO #DEPT3_DIM (DEPT3_ID, DEPT3_NM, DEPT4_ID, SORT_ORDR)
VALUES ('Z~', N'없음', 'Z~', 999);

CREATE INDEX IX_DEPT3_DIM_ID ON #DEPT3_DIM (DEPT3_ID);

SELECT
    B.DEPT_ID AS DEPT4_ID,
    B.DEPT_NM AS DEPT4_NM,
    B.SORT_ORDR
INTO #DEPT4_DIM
FROM dbo.TM_CM_DEPT_INFO A
JOIN dbo.TM_CM_DEPT_INFO B
  ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
WHERE A.UPPER_DEPT_ID = 'ZV000000'
  AND A.USE_YN = 'Y';

INSERT INTO #DEPT4_DIM (DEPT4_ID, DEPT4_NM, SORT_ORDR)
VALUES ('Z~', N'없음', 999);

CREATE INDEX IX_DEPT4_DIM_ID ON #DEPT4_DIM (DEPT4_ID);

/* -------------------------------------------------------------------------
   2. 공통코드 및 후원사업 차원
      D_CPR_DIV_CD             : CM019
      D_SPNSR_BSNS_ABRV_CD     : CM003
      D_DVLP_DIV_CD            : MM015
   ------------------------------------------------------------------------- */
SELECT
    D.DTL_CD_ID AS CPR_DIV_CD,
    D.DTL_CD_NM AS CPR_DIV_NM,
    D.SORT_ORDR
INTO #CPR_DIM
FROM dbo.TC_CMMN_DTL_CD D
WHERE D.CD_ID = 'CM019';

SELECT
    D.DTL_CD_ID AS SPNSR_BSNS_ABRV_CD,
    D.DTL_CD_NM AS SPNSR_BSNS_ABRV_NM,
    D.SORT_ORDR
INTO #ABRV_DIM
FROM dbo.TC_CMMN_DTL_CD D
WHERE D.CD_ID = 'CM003';

SELECT
    D.DTL_CD_ID AS DVLP_DIV_CD,
    D.DTL_CD_NM AS DVLP_DIV_NM,
    D.SORT_ORDR
INTO #DVLP_DIM
FROM dbo.TC_CMMN_DTL_CD D
WHERE D.CD_ID = 'MM015';

SELECT
    S.SPNSR_BSNS_ID,
    S.SPNSR_BSNS_NM,
    S.SPNSR_BSNS_ABRV_CD,
    S.SORT_ORDR,
    CASE
        WHEN S.CPR_DIV_CD = '1' THEN 'I'
        WHEN S.CPR_DIV_CD = '2' THEN 'S'
        ELSE S.CPR_DIV_CD
    END AS CPR_DIV_CD
INTO #BUSINESS_DIM
FROM dbo.TM_CM_SPNSR_BSNS_INFO S;

CREATE INDEX IX_BUSINESS_DIM_ID ON #BUSINESS_DIM (SPNSR_BSNS_ID);

/* -------------------------------------------------------------------------
   3. dbo.FN_MM_SPNSR_DVLP 중 개발구분 1/2/4 재현
   ------------------------------------------------------------------------- */
;WITH NEW_REJOIN_BASE AS
(
    SELECT
        LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
        SUM(A.SPNSR_AMT) OVER
        (
            PARTITION BY
                A.SPNSR_NO,
                A.SPNSR_BSNS_NO,
                LEFT(A.OCCRRNC_DE, 6)
        ) AS MAMT,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO,
        A.OCCRRNC_DE,
        A.SER_NO,
        A.MBER_NO,
        A.ACMSLT_DEPT_CD,
        A.SPNSR_BSNS_ID,
        A.SPNSR_AMT,
        A.DVLP_DIV_CD
    FROM dbo.TM_MM_FDRM_MBER_DVLP_AMT A
    JOIN dbo.TM_MM_FDRM_MBER_SPNSR_BSNS B
      ON A.SPNSR_NO = B.SPNSR_NO
     AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
     AND ISNULL(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231')
         > LEFT(A.OCCRRNC_DE, 6) + '31'
    WHERE A.OCCRRNC_DE BETWEEN @YEAR_START_MT + '01' AND @STRD_MT + '31'
      AND A.DVLP_DIV_CD IN ('1', '4')
),
NEW_REJOIN AS
(
    SELECT
        N.STRD_MT,
        N.SPNSR_NO,
        N.SPNSR_BSNS_NO,
        N.OCCRRNC_DE,
        N.SER_NO,
        N.MBER_NO,
        ISNULL(N.ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
        N.SPNSR_BSNS_ID,
        N.DVLP_DIV_CD,
        N.SPNSR_AMT
    FROM NEW_REJOIN_BASE N
    WHERE N.MAMT > 0
),
CHANGE_BASE AS
(
    SELECT
        LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
        SUM
        (
            CASE WHEN A.DVLP_DIV_CD IN ('2', '3')
                 THEN A.SPNSR_AMT ELSE 0 END
        ) OVER
        (
            PARTITION BY
                A.SPNSR_NO,
                A.SPNSR_BSNS_NO,
                LEFT(A.OCCRRNC_DE, 6)
        ) AS SAMT,
        SUM(A.SPNSR_AMT) OVER
        (
            PARTITION BY A.MBER_NO, LEFT(A.OCCRRNC_DE, 6)
        ) AS MAMT,
        A.SPNSR_NO,
        A.SPNSR_BSNS_NO,
        A.OCCRRNC_DE,
        A.SER_NO,
        A.MBER_NO,
        A.ACMSLT_DEPT_CD,
        A.SPNSR_BSNS_ID,
        A.SPNSR_AMT,
        A.DVLP_DIV_CD
    FROM dbo.TM_MM_FDRM_MBER_DVLP_AMT A
    WHERE A.OCCRRNC_DE BETWEEN @YEAR_START_MT + '01' AND @STRD_MT + '31'
      AND A.DVLP_DIV_CD IN ('2', '3', '5')
),
CHANGE_MEMBER AS
(
    SELECT
        SUM
        (
            CASE WHEN C.DVLP_DIV_CD = '3'
                 THEN C.SPNSR_AMT ELSE 0 END
        ) OVER
        (
            PARTITION BY C.MBER_NO, C.STRD_MT
        ) AS DAMT,
        C.*
    FROM CHANGE_BASE C
    WHERE C.MAMT > 0
      AND
      (
          (C.SAMT > 0 AND C.DVLP_DIV_CD = '2')
          OR
          (C.SAMT < 0 AND C.DVLP_DIV_CD = '3')
      )
),
CHANGE_RUNNING AS
(
    SELECT
        SUM(C.SAMT) OVER
        (
            PARTITION BY C.MBER_NO, C.STRD_MT
            ORDER BY C.OCCRRNC_DE, C.SER_NO
        ) AS AAMT,
        C.*
    FROM CHANGE_MEMBER C
    WHERE C.DVLP_DIV_CD = '2'
),
CHANGE_ALLOC AS
(
    SELECT
        ROW_NUMBER() OVER
        (
            PARTITION BY C.STRD_MT, C.SPNSR_NO, C.SPNSR_BSNS_NO
            ORDER BY C.SER_NO
        ) AS RNUM,
        CASE
            WHEN C.MAMT <= C.SAMT
             AND C.AAMT + C.DAMT <= C.MAMT
                THEN C.AAMT + C.DAMT
            WHEN C.MAMT > C.SAMT
             AND C.AAMT + C.DAMT <= C.SAMT
                THEN C.AAMT + C.DAMT
            WHEN C.MAMT <= C.SAMT
                THEN C.MAMT
            ELSE C.SAMT
        END AS RAMT,
        C.*
    FROM CHANGE_RUNNING C
    WHERE C.AAMT - ABS(C.DAMT) > 0
),
INCREASE AS
(
    SELECT
        C.STRD_MT,
        C.SPNSR_NO,
        C.SPNSR_BSNS_NO,
        C.OCCRRNC_DE,
        C.SER_NO,
        C.MBER_NO,
        ISNULL(C.ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
        C.SPNSR_BSNS_ID,
        CAST('2' AS VARCHAR(3)) AS DVLP_DIV_CD,
        C.RAMT AS SPNSR_AMT
    FROM CHANGE_ALLOC C
    WHERE C.RNUM = 1
),
TRANSFORMED AS
(
    SELECT
        N.STRD_MT,
        N.SPNSR_NO,
        N.SPNSR_BSNS_NO,
        N.OCCRRNC_DE,
        N.SER_NO,
        N.MBER_NO,
        N.DEPT_ID,
        N.SPNSR_BSNS_ID,
        N.DVLP_DIV_CD,
        N.SPNSR_AMT
    FROM NEW_REJOIN N

    UNION ALL

    SELECT
        I.STRD_MT,
        I.SPNSR_NO,
        I.SPNSR_BSNS_NO,
        I.OCCRRNC_DE,
        I.SER_NO,
        I.MBER_NO,
        I.DEPT_ID,
        I.SPNSR_BSNS_ID,
        I.DVLP_DIV_CD,
        I.SPNSR_AMT
    FROM INCREASE I
)
SELECT
    T.STRD_MT,
    T.SPNSR_NO,
    T.SPNSR_BSNS_NO,
    T.OCCRRNC_DE,
    T.SER_NO,
    T.MBER_NO,
    T.DEPT_ID,
    T.SPNSR_BSNS_ID,
    T.DVLP_DIV_CD,
    CAST(T.SPNSR_AMT AS DECIMAL(38, 4)) AS SPNSR_AMT
INTO #DVLP_SOURCE
FROM TRANSFORMED T;

CREATE INDEX IX_DVLP_SOURCE_MONTH_CODE
    ON #DVLP_SOURCE (STRD_MT, DVLP_DIV_CD, MBER_NO);

/* -------------------------------------------------------------------------
   4. mart.USP_F_MM_SPNSR_DVLP_SUM의 보고서용 차원/금액 생성
   ------------------------------------------------------------------------- */
SELECT
    S.STRD_MT,
    ISNULL(B.SPNSR_BSNS_ABRV_CD, '0') AS SPNSR_BSNS_ABRV_CD,
    S.SPNSR_BSNS_ID,
    D.DEPT3_ID,
    S.DEPT_ID,
    D.DEPT4_ID,
    ISNULL(B.CPR_DIV_CD, '0') AS CPR_DIV_CD,
    S.DVLP_DIV_CD,
    S.MBER_NO,
    S.SPNSR_AMT,
    CAST(S.SPNSR_AMT AS DECIMAL(38, 7)) / 10000.0 AS SPNSR_AMT_CNT
INTO #DVLP_FACT
FROM #DVLP_SOURCE S
LEFT JOIN #DEPT_DIM D
  ON S.DEPT_ID = D.DEPT_ID
LEFT JOIN #BUSINESS_DIM B
  ON S.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID;

CREATE INDEX IX_DVLP_FACT_GROUP
    ON #DVLP_FACT
       (STRD_MT, CPR_DIV_CD, DEPT4_ID, DEPT3_ID, DEPT_ID,
        SPNSR_BSNS_ABRV_CD, SPNSR_BSNS_ID, DVLP_DIV_CD);

/* -------------------------------------------------------------------------
   5. 선택월 집계: 원본 ##T9N01SP3MMD000 재현
   ------------------------------------------------------------------------- */
SELECT
    F.SPNSR_BSNS_ABRV_CD,
    F.SPNSR_BSNS_ID,
    F.DEPT3_ID,
    F.DEPT_ID,
    F.DEPT4_ID,
    F.CPR_DIV_CD,
    F.STRD_MT,
    F.DVLP_DIV_CD,
    SUM(F.SPNSR_AMT_CNT) AS WJXBFS1,
    COUNT(DISTINCT F.MBER_NO) AS WJXBFS2,
    SUM(F.SPNSR_AMT) AS WJXBFS3
INTO #MONTH_AGG
FROM #DVLP_FACT F
WHERE F.STRD_MT = @STRD_MT
GROUP BY
    F.SPNSR_BSNS_ABRV_CD,
    F.SPNSR_BSNS_ID,
    F.DEPT3_ID,
    F.DEPT_ID,
    F.DEPT4_ID,
    F.CPR_DIV_CD,
    F.STRD_MT,
    F.DVLP_DIV_CD;

/* -------------------------------------------------------------------------
   6. 당해연도 누계 집계: D_STRD_ADD_MT_CD 조인과 동일
   ------------------------------------------------------------------------- */
SELECT
    F.SPNSR_BSNS_ABRV_CD,
    F.SPNSR_BSNS_ID,
    F.DEPT3_ID,
    F.DEPT_ID,
    F.DEPT4_ID,
    F.CPR_DIV_CD,
    @STRD_MT AS STRD_MT,
    F.DVLP_DIV_CD,
    SUM(F.SPNSR_AMT_CNT) AS WJXBFS1,
    COUNT(DISTINCT F.MBER_NO) AS WJXBFS2
INTO #YTD_AGG
FROM #DVLP_FACT F
WHERE F.STRD_MT BETWEEN @YEAR_START_MT AND @STRD_MT
GROUP BY
    F.SPNSR_BSNS_ABRV_CD,
    F.SPNSR_BSNS_ID,
    F.DEPT3_ID,
    F.DEPT_ID,
    F.DEPT4_ID,
    F.CPR_DIV_CD,
    F.DVLP_DIV_CD;

/* -------------------------------------------------------------------------
   결과 1. 개발구분별 대사
   ------------------------------------------------------------------------- */
IF @DEBUG = 1
BEGIN
    ;WITH CRM_TOTAL AS
    (
        SELECT
            S.DVLP_DIV_CD,
            COUNT(*) AS FACT_ROW_CNT,
            COUNT(DISTINCT S.MBER_NO) AS MBER_CNT,
            SUM(CAST(S.SPNSR_AMT AS DECIMAL(38, 7))) / 10000.0 AS SPNSR_AMT_CNT,
            SUM(CAST(S.SPNSR_AMT AS DECIMAL(38, 4))) AS SPNSR_AMT
        FROM #DVLP_SOURCE S
        WHERE S.STRD_MT = @STRD_MT
        GROUP BY S.DVLP_DIV_CD
    ),
    MSTR_202606 AS
    (
        SELECT *
        FROM
        (
            VALUES
                ('1', 12832, 11969, CAST(25713.8900000 AS DECIMAL(38, 7)), CAST(257138900 AS DECIMAL(38, 4))),
                ('2',  2318,  2014, CAST( 4999.9501000 AS DECIMAL(38, 7)), CAST( 49999501 AS DECIMAL(38, 4))),
                ('4',  1605,  1465, CAST( 3350.7500000 AS DECIMAL(38, 7)), CAST( 33507500 AS DECIMAL(38, 4)))
        ) V (DVLP_DIV_CD, FACT_ROW_CNT, MBER_CNT, SPNSR_AMT_CNT, SPNSR_AMT)
        WHERE @STRD_MT = '202606'
    )
    SELECT
        C.DVLP_DIV_CD,
        C.FACT_ROW_CNT AS CRM_FACT_ROW_CNT,
        M.FACT_ROW_CNT AS MSTR_FACT_ROW_CNT,
        C.FACT_ROW_CNT - M.FACT_ROW_CNT AS FACT_ROW_DIFF,
        C.MBER_CNT AS CRM_MBER_CNT,
        M.MBER_CNT AS MSTR_MBER_CNT,
        C.MBER_CNT - M.MBER_CNT AS MBER_DIFF,
        C.SPNSR_AMT_CNT AS CRM_SPNSR_AMT_CNT,
        M.SPNSR_AMT_CNT AS MSTR_SPNSR_AMT_CNT,
        C.SPNSR_AMT_CNT - M.SPNSR_AMT_CNT AS SPNSR_AMT_CNT_DIFF,
        C.SPNSR_AMT AS CRM_SPNSR_AMT,
        M.SPNSR_AMT AS MSTR_SPNSR_AMT,
        C.SPNSR_AMT - M.SPNSR_AMT AS SPNSR_AMT_DIFF
    FROM CRM_TOTAL C
    LEFT JOIN MSTR_202606 M
      ON C.DVLP_DIV_CD = M.DVLP_DIV_CD
    ORDER BY C.DVLP_DIV_CD;
END;

/* -------------------------------------------------------------------------
   결과 2. 최종 보고서
      원본과 동일한 FULL OUTER JOIN을 유지해 NULL 키의 결합 방식도 보존한다.
   ------------------------------------------------------------------------- */
SELECT
    COALESCE(M.STRD_MT, Y.STRD_MT) AS STRD_MT,
    LEFT(COALESCE(M.STRD_MT, Y.STRD_MT), 4)
        + '-'
        + RIGHT(COALESCE(M.STRD_MT, Y.STRD_MT), 2) AS STRD_NM,
    COALESCE(M.DEPT4_ID, Y.DEPT4_ID) AS DEPT4_ID,
    D4.DEPT4_NM,
    D4.SORT_ORDR,
    COALESCE(M.DEPT3_ID, Y.DEPT3_ID) AS DEPT3_ID,
    D3.DEPT3_NM,
    D3.SORT_ORDR AS SORT_ORDR0,
    COALESCE(M.SPNSR_BSNS_ABRV_CD, Y.SPNSR_BSNS_ABRV_CD) AS SPNSR_BSNS_ABRV_CD,
    AB.SPNSR_BSNS_ABRV_NM,
    COALESCE(M.SPNSR_BSNS_ID, Y.SPNSR_BSNS_ID) AS SPNSR_BSNS_ID,
    B.SPNSR_BSNS_NM,
    B.SORT_ORDR AS SORT_ORDR1,
    COALESCE(M.DVLP_DIV_CD, Y.DVLP_DIV_CD) AS DVLP_DIV_CD,
    DV.DVLP_DIV_NM,
    DV.SORT_ORDR AS SORT_ORDR2,
    COALESCE(M.CPR_DIV_CD, Y.CPR_DIV_CD) AS CPR_DIV_CD,
    CPR.CPR_DIV_NM,
    COALESCE(M.DEPT_ID, Y.DEPT_ID) AS DEPT_ID,
    D.DEPT_NM,
    M.WJXBFS1,
    M.WJXBFS2,
    M.WJXBFS3,
    Y.WJXBFS1 AS WJXBFS4,
    Y.WJXBFS2 AS WJXBFS5
FROM #MONTH_AGG M
FULL OUTER JOIN #YTD_AGG Y
  ON M.CPR_DIV_CD = Y.CPR_DIV_CD
 AND M.DEPT3_ID = Y.DEPT3_ID
 AND M.DEPT4_ID = Y.DEPT4_ID
 AND M.DEPT_ID = Y.DEPT_ID
 AND M.DVLP_DIV_CD = Y.DVLP_DIV_CD
 AND M.SPNSR_BSNS_ABRV_CD = Y.SPNSR_BSNS_ABRV_CD
 AND M.SPNSR_BSNS_ID = Y.SPNSR_BSNS_ID
 AND M.STRD_MT = Y.STRD_MT
LEFT JOIN #DVLP_DIM DV
  ON COALESCE(M.DVLP_DIV_CD, Y.DVLP_DIV_CD) = DV.DVLP_DIV_CD
LEFT JOIN #CPR_DIM CPR
  ON COALESCE(M.CPR_DIV_CD, Y.CPR_DIV_CD) = CPR.CPR_DIV_CD
LEFT JOIN #DEPT4_DIM D4
  ON COALESCE(M.DEPT4_ID, Y.DEPT4_ID) = D4.DEPT4_ID
LEFT JOIN #DEPT3_DIM D3
  ON COALESCE(M.DEPT3_ID, Y.DEPT3_ID) = D3.DEPT3_ID
LEFT JOIN #DEPT_DIM D
  ON COALESCE(M.DEPT_ID, Y.DEPT_ID) = D.DEPT_ID
LEFT JOIN #BUSINESS_DIM B
  ON COALESCE(M.SPNSR_BSNS_ID, Y.SPNSR_BSNS_ID) = B.SPNSR_BSNS_ID
LEFT JOIN #ABRV_DIM AB
  ON COALESCE(M.SPNSR_BSNS_ABRV_CD, Y.SPNSR_BSNS_ABRV_CD)
     = AB.SPNSR_BSNS_ABRV_CD
WHERE @CPR_DIV_CD IS NULL
   OR COALESCE(M.CPR_DIV_CD, Y.CPR_DIV_CD) = @CPR_DIV_CD
ORDER BY
    COALESCE(M.CPR_DIV_CD, Y.CPR_DIV_CD),
    D4.SORT_ORDR,
    D3.SORT_ORDR,
    AB.SORT_ORDR,
    B.SORT_ORDR,
    DV.SORT_ORDR,
    D.SORT_ORDR;

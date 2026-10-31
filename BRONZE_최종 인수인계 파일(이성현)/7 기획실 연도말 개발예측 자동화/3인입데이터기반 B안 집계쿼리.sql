--GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA 목표 / 실적으로 구분
--B안. 기준월까지는 실적치. 기준월 이후부터는 계산식. 
SET YEAR = '2026';
SET STDR_MT = '08';
SET ADJ_COEF = 1.00; --조정 계수
WITH
/* ============================================================
   1. 공휴일
   ============================================================ */
TM_CM_SCHDUL_MNG AS (
    SELECT 
        SCHDUL_DE, SCHDUL_TIT
    FROM GN_DW.BRONZE_CRM.TM_CM_SCHDUL_MNG
    WHERE 
        TO_VARCHAR(SCHDUL_DE, 'YYYY') = $YEAR
        AND SCHDUL_DIV_CD = '0' 
    ORDER BY SCHDUL_DE
    -- SELECT
    --     COLUMN1::DATE AS SCHDUL_DE,
    --     COLUMN2 AS SCHDUL_TIT
    -- FROM VALUES
    --     ('2026-01-01', '신정'),
    --     ('2026-02-16', '설날 연휴'),
    --     ('2026-02-17', '설날'),
    --     ('2026-02-18', '설날 연휴'),
    --     ('2026-03-02', '삼일절 대체공휴일(3/1 일)'),
    --     ('2026-05-05', '어린이날'),
    --     ('2026-05-25', '부처님오신날 대체공휴일(5/24 일)'),
    --     ('2026-06-03', '제9회 전국동시지방선거(임시공휴일, 확인필요)'),
    --     ('2026-06-06', '현충일(토)'),
    --     ('2026-08-15', '광복절(토)'),
    --     ('2026-09-24', '추석 연휴'),
    --     ('2026-09-25', '추석'),
    --     ('2026-09-28', '추석 대체공휴일(9/26 토)'),
    --     ('2026-10-03', '개천절(토)'),
    --     ('2026-10-05', '개천절 대체공휴일'),
    --     ('2026-10-09', '한글날'),
    --     ('2026-12-25', '성탄절')
),

/* ============================================================
   2. 전체 날짜
   ============================================================ */
ALL_DAYS AS (
    SELECT
        DATEADD(
            DAY,
            SEQ4(),
            TO_DATE($YEAR || '0101', 'YYYYMMDD')
        ) AS DE
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(
              DAY,
              SEQ4(),
              TO_DATE($YEAR || '0101', 'YYYYMMDD')
          ) < DATEADD(
                  YEAR,
                  1,
                  TO_DATE($YEAR || '0101', 'YYYYMMDD')
              )
),

/* ============================================================
   3. 영업일
   ============================================================ */
BUSINESS_DAYS AS (
    SELECT
        D.DE
    FROM ALL_DAYS D
    LEFT JOIN TM_CM_SCHDUL_MNG S
        ON D.DE = S.SCHDUL_DE
    WHERE DAYOFWEEKISO(D.DE) NOT IN (6, 7)
      AND S.SCHDUL_DE IS NULL
),

/* ============================================================
   4. 월별 영업일수
   ============================================================ */
WORK_DAYS AS (
    SELECT
        YEAR(DE) AS YEAR,

        COUNT_IF(MONTH(DE) = 1)  AS M01,
        COUNT_IF(MONTH(DE) = 2)  AS M02,
        COUNT_IF(MONTH(DE) = 3)  AS M03,
        COUNT_IF(MONTH(DE) = 4)  AS M04,
        COUNT_IF(MONTH(DE) = 5)  AS M05,
        COUNT_IF(MONTH(DE) = 6)  AS M06,
        COUNT_IF(MONTH(DE) = 7)  AS M07,
        COUNT_IF(MONTH(DE) = 8)  AS M08,
        COUNT_IF(MONTH(DE) = 9)  AS M09,
        COUNT_IF(MONTH(DE) = 10) AS M10,
        COUNT_IF(MONTH(DE) = 11) AS M11,
        COUNT_IF(MONTH(DE) = 12) AS M12

    FROM BUSINESS_DAYS
    GROUP BY YEAR(DE)
),

/* ============================================================
   5. 목표 대상
      - 목표 데이터 자체의 월별 값은 사용하지 않고
        결과를 만들 기준 KEY만 사용
   ============================================================ */
GOAL AS (
    SELECT DISTINCT
        *, 
        CASE TO_NUMBER($STDR_MT)
            WHEN 1  THEN COALESCE(M01, 0)
            WHEN 2  THEN COALESCE(M01, 0) + COALESCE(M02, 0)
            WHEN 3  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0)
            WHEN 4  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0)
            WHEN 5  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0)
            WHEN 6  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0)
            WHEN 7  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0)
            WHEN 8  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0) + COALESCE(M08, 0)
            WHEN 9  THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0) + COALESCE(M08, 0) + COALESCE(M09, 0)
            WHEN 10 THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0) + COALESCE(M08, 0) + COALESCE(M09, 0) + COALESCE(M10, 0)
            WHEN 11 THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0) + COALESCE(M08, 0) + COALESCE(M09, 0) + COALESCE(M10, 0) + COALESCE(M11, 0)
            WHEN 12 THEN COALESCE(M01, 0) + COALESCE(M02, 0) + COALESCE(M03, 0) + COALESCE(M04, 0) + COALESCE(M05, 0) + COALESCE(M06, 0) + COALESCE(M07, 0) + COALESCE(M08, 0) + COALESCE(M09, 0) + COALESCE(M10, 0) + COALESCE(M11, 0) + COALESCE(M12, 0)
        END AS CMLT_GOAL_CNT,
        (M01 + M02 + M03 + M04 + M05 + M06 + M07 + M08 + M09 +M10 + M11 + M12) AS ANNUAL_GOAL_CNT
    FROM GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA
    WHERE YEAR = '2026'
    -- WHERE YEAR = $YEAR
      AND DATA_TYPE_NM = '목표'
),
/* ============================================================
   6. 실적을 월별 ROW로 변환
   ============================================================ */
REAL_MONTHLY AS (
    SELECT
        YEAR,
        DEPT_DIV_NM,
        NEW_EXST_DIV_NM,
        SPNSR_BSNS_GRP_NM,
        TO_NUMBER(REPLACE(MT, 'M', '')) AS MT,
        DVLP_CNT
    FROM (
        SELECT
            YEAR,
            DEPT_DIV_NM,
            NEW_EXST_DIV_NM,
            SPNSR_BSNS_GRP_NM,
            M01, M02, M03, M04, M05, M06,
            M07, M08, M09, M10, M11, M12
        FROM GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA
        WHERE YEAR = $YEAR
          AND DATA_TYPE_NM = '실적'
    )
    UNPIVOT (
        DVLP_CNT FOR MT IN (
            M01, M02, M03, M04, M05, M06,
            M07, M08, M09, M10, M11, M12
        )
    )
),

/* ============================================================
   7. 영업일수를 월별 ROW로 변환
   ============================================================ */
WORK_DAYS_MONTHLY AS (
    SELECT
        YEAR,
        TO_NUMBER(REPLACE(MT, 'M', '')) AS MT,
        WORK_DAY_CNT
    FROM WORK_DAYS
    UNPIVOT (
        WORK_DAY_CNT FOR MT IN (
            M01, M02, M03, M04, M05, M06,
            M07, M08, M09, M10, M11, M12
        )
    )
),

/* ============================================================
   8. 실적 + 영업일수
   ============================================================ */
MONTHLY AS (
    SELECT
        G.YEAR,
        G.DEPT_DIV_NM,
        G.NEW_EXST_DIV_NM,
        G.SPNSR_BSNS_GRP_NM,

        M.MT,

        COALESCE(R.DVLP_CNT, 0) AS REAL_DVLP_CNT,

        W.WORK_DAY_CNT,

        /* 기준월까지 실적 누계 : 누계실측 */
        SUM(
            CASE
                WHEN M.MT <= TO_NUMBER($STDR_MT)
                THEN COALESCE(R.DVLP_CNT, 0)
                ELSE 0
            END
        ) OVER (
            PARTITION BY
                G.YEAR,
                G.DEPT_DIV_NM,
                G.NEW_EXST_DIV_NM,
                G.SPNSR_BSNS_GRP_NM
        ) AS ACT_DVLP_CNT, 

        /* 기준월까지 영업일수 누계 */
        SUM(
            CASE
                WHEN M.MT <= TO_NUMBER($STDR_MT)
                THEN W.WORK_DAY_CNT
                ELSE 0
            END
        ) OVER (
            PARTITION BY
                G.YEAR,
                G.DEPT_DIV_NM,
                G.NEW_EXST_DIV_NM,
                G.SPNSR_BSNS_GRP_NM
        ) AS ACT_WORK_DAY_CNT,
        /* 기준월까지 누계 달성율  누계실측 / 목표의 누계목표 */ 
        COALESCE(ACT_DVLP_CNT / NULLIF(G.CMLT_GOAL_CNT, 0), 0) AS CMLT_ATNMNT_RT,
        /* 연간목표치 목표 연간목표 합계 : 연도말 예측 / 연간목표 */
        G.ANNUAL_GOAL_CNT,
        G.M01, G.M02, G.M03, G.M04, G.M05, G.M06, G.M07, G.M08, G.M09, G.M10, G.M11, G.M12
    FROM GOAL G

    CROSS JOIN (
        SELECT SEQ4() + 1 AS MT
        FROM TABLE(GENERATOR(ROWCOUNT => 12))
    ) M

    LEFT JOIN REAL_MONTHLY R
        ON G.YEAR = R.YEAR
        AND G.DEPT_DIV_NM = R.DEPT_DIV_NM
        AND G.NEW_EXST_DIV_NM = R.NEW_EXST_DIV_NM
        AND G.SPNSR_BSNS_GRP_NM = R.SPNSR_BSNS_GRP_NM
        AND M.MT = R.MT

    INNER JOIN WORK_DAYS_MONTHLY W
        ON G.YEAR = W.YEAR
        AND M.MT = W.MT
),
/* ============================================================
   9. 기준월까지는 실적
      기준월 이후는 일평균 × 해당월 영업일수
   ============================================================ */
CALC AS (
    SELECT
        YEAR,
        DEPT_DIV_NM,
        NEW_EXST_DIV_NM,
        SPNSR_BSNS_GRP_NM,
        MT,
        CASE
            WHEN MT <= TO_NUMBER($STDR_MT)
                THEN REAL_DVLP_CNT
            -- 목표값 * 누계달성율 * 조정계수     
            ELSE
                CASE MT
                WHEN 1  THEN M01
                WHEN 2  THEN M02
                WHEN 3  THEN M03
                WHEN 4  THEN M04
                WHEN 5  THEN M05
                WHEN 6  THEN M06
                WHEN 7  THEN M07
                WHEN 8  THEN M08
                WHEN 9  THEN M09
                WHEN 10 THEN M10
                WHEN 11 THEN M11
                WHEN 12 THEN M12
            END * CMLT_ATNMNT_RT * $ADJ_COEF
        END AS DVLP_CNT,
        CMLT_ATNMNT_RT,
        ANNUAL_GOAL_CNT,
    FROM MONTHLY
),
/* ============================================================
   10. 누계실측 / 잔여예측
   ============================================================ */
SUMMARY AS (
    SELECT
        YEAR,
        DEPT_DIV_NM,
        NEW_EXST_DIV_NM,
        SPNSR_BSNS_GRP_NM,

        SUM(
            CASE
                WHEN MT <= TO_NUMBER($STDR_MT)
                THEN DVLP_CNT
                ELSE 0
            END
        ) AS CMLT_ACTL_CNT,

        SUM(
            CASE
                WHEN MT > TO_NUMBER($STDR_MT)
                THEN DVLP_CNT
                ELSE 0
            END
        ) AS RSDL_PRDT_CNT,
        MAX(CMLT_ATNMNT_RT) AS CMLT_ATNMNT_RT,
        MAX(ANNUAL_GOAL_CNT) AS ANNUAL_GOAL_CNT,
    FROM CALC

    GROUP BY
        YEAR,
        DEPT_DIV_NM,
        NEW_EXST_DIV_NM,
        SPNSR_BSNS_GRP_NM
)

/* ============================================================
   11. 최종 결과
   ============================================================ */
SELECT
    P.YEAR,
    P.DEPT_DIV_NM,
    P.NEW_EXST_DIV_NM,
    P.SPNSR_BSNS_GRP_NM,

    P.M01,
    P.M02,
    P.M03,
    P.M04,
    P.M05,
    P.M06,
    P.M07,
    P.M08,
    P.M09,
    P.M10,
    P.M11,
    P.M12,
    S.CMLT_ACTL_CNT, --누계실측
    S.RSDL_PRDT_CNT, --잔여예측
    S.CMLT_ACTL_CNT + S.RSDL_PRDT_CNT AS EOF_PRDT_CNT, --연도말예측(A안)
    S.CMLT_ATNMNT_RT, --누계 달성율
    S.ANNUAL_GOAL_CNT, -- 연간목표
    COALESCE((S.CMLT_ACTL_CNT + S.RSDL_PRDT_CNT) / NULLIF(S.ANNUAL_GOAL_CNT, 0), 0) AS EXPC_GOAL_ATNMNT_RT -- 예상 목표 달성율
FROM (
    SELECT *
    FROM CALC
    PIVOT (
        MAX(DVLP_CNT)
        FOR MT IN (
            1  AS M01,
            2  AS M02,
            3  AS M03,
            4  AS M04,
            5  AS M05,
            6  AS M06,
            7  AS M07,
            8  AS M08,
            9  AS M09,
            10 AS M10,
            11 AS M11,
            12 AS M12
        )
    )
) P
INNER JOIN SUMMARY S
    ON P.YEAR = S.YEAR
    AND P.DEPT_DIV_NM = S.DEPT_DIV_NM
    AND P.NEW_EXST_DIV_NM = S.NEW_EXST_DIV_NM
    AND P.SPNSR_BSNS_GRP_NM = S.SPNSR_BSNS_GRP_NM
ORDER BY
    P.DEPT_DIV_NM,
    P.NEW_EXST_DIV_NM DESC,
    P.SPNSR_BSNS_GRP_NM;

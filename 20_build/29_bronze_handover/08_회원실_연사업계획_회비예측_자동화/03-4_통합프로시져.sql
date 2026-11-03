-- 실측치, 예측치 재계산 통합 프로시져
-- 실측치 인입 프로시져
    -- CALL GN_DW.SILVER.SP_UPDATE_ANNUAL_MBRFEE_PRDT_ACTL_DATA1(YYYYMM)는 파라미터에 해당하는 연월 집계치 인입
-- 예측치 재계산 업데이트 프로시져 
    --CALL GN_DW.SILVER.SP_UPDATE_ANNUAL_MBRFEE_PRDT_ACTL_DATA1 
-- 회비관련 계산식의 소숫점 차이로 몇백원 단위 차이가 남. 

CALL GN_DW.SILVER.SP_RECALC_ANNUAL_MBRFEE_PRDT_ACTL_DATA('202602');
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_RECALC_ANNUAL_MBRFEE_PRDT_ACTL_DATA(
    input_yyyymm VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_STDR_DATE DATE;
    V_END_DATE DATE;
    V_STDR_MT VARCHAR;
    V_MONTH_CNT NUMBER DEFAULT 0;
    V_EXEC_CNT NUMBER DEFAULT 0;
BEGIN

    -- ============================================================
    -- 0. 입력 파라미터 유효성 검증
    -- ============================================================

    -- YYYYMM 형식 검증
    IF (NOT REGEXP_LIKE(input_yyyymm, '^[0-9]{6}$')) THEN
        RETURN 'ERROR: input_yyyymm은 YYYYMM 형식이어야 합니다. 입력값=['
               || input_yyyymm || ']';
    END IF;

    -- 실제 존재하는 년월인지 검증
    IF (TRY_TO_DATE(input_yyyymm || '01', 'YYYYMMDD') IS NULL) THEN
        RETURN 'ERROR: 유효하지 않은 년월입니다. 입력값=['
               || input_yyyymm || ']';
    END IF;


    -- ============================================================
    -- 1. 최초 INSERT
    --    입력받은 input_yyyymm 그대로 사용
    -- ============================================================

    CALL GN_DW.SILVER.SP_INSERT_ANNUAL_MBRFEE_PRDT_ACTL_DATA(
        :input_yyyymm
    );


    -- ============================================================
    -- 2. 입력 기준월이 12월이면
    --    INSERT만 실행하고 종료
    -- ============================================================

    IF (RIGHT(input_yyyymm, 2) = '12') THEN
        RETURN '처리 완료: 기준월=' || input_yyyymm
               || ', INSERT=1회'
               || ', UPDATE 처리 월수=0'
               || ', UPDATE 실행 횟수=0';
    END IF;


    -- ============================================================
    -- 3. 다음 달부터 시작
    -- ============================================================

    V_STDR_DATE := DATEADD(
        MONTH,
        1,
        TO_DATE(input_yyyymm || '01', 'YYYYMMDD')
    );


    -- 입력 기준월이 속한 연도의 12월
    V_END_DATE := DATE_FROM_PARTS(
        YEAR(TO_DATE(input_yyyymm || '01', 'YYYYMMDD')),
        12,
        1
    );


    -- ============================================================
    -- 4. 다음 달 ~ 해당 연도 12월까지 UPDATE
    -- ============================================================

    WHILE (V_STDR_DATE <= V_END_DATE) DO

        V_STDR_MT := TO_CHAR(V_STDR_DATE, 'YYYYMM');


        -- UPDATE 1
        CALL GN_DW.SILVER.SP_UPDATE_ANNUAL_MBRFEE_PRDT_ACTL_DATA1(
            :V_STDR_MT
        );


        -- UPDATE 2
        CALL GN_DW.SILVER.SP_UPDATE_ANNUAL_MBRFEE_PRDT_ACTL_DATA2(
            :V_STDR_MT
        );


        V_EXEC_CNT := V_EXEC_CNT + 1;
        V_MONTH_CNT := V_MONTH_CNT + 1;


        -- 다음 달
        V_STDR_DATE := DATEADD(
            MONTH,
            1,
            V_STDR_DATE
        );

    END WHILE;


    -- ============================================================
    -- 5. 결과 반환
    -- ============================================================

    RETURN
        '처리 완료: 기준월=' || input_yyyymm
        || ', INSERT=1회'
        || ', UPDATE 처리 월수=' || V_MONTH_CNT
        || ', UPDATE 실행 횟수=' || V_EXEC_CNT;

END;
$$;
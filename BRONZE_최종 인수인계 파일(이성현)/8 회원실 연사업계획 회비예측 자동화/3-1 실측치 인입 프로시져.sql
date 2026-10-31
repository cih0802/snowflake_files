-- 연간 회비 실측 데이터 생성 프로시저
-- MSTR 기준 집계치와 당월 예측 데이터를 기반으로 실측 데이터를 인입한다. 
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 실측 데이터(DATA_TYPE_NM='실측')를 삭제 후 재산출한다.
-- MM_SPNSR_CLS_AGGR_DATA의 개발·중단·감액·활동·회비 집계 데이터를 기준으로 월별 개발건수, 중단건수, 감액건수, 월말 활동회원수, 회비금액 및 누계회비를 산출한다.
-- 신규 회원은 본부·지부별 실적과 본부지부 합계를 함께 구성하고, 기존 회원은 기존으로 통합하여 예측 데이터와 실측 데이터를 동일한 기준으로 비교한다.
-- 당월 예측 실측 데이터를 활용하여 개발 누계, 중단 누계, 활동회원 누계, 누계회비 등 누계 지표를 계산하고, 기준월의 실측값을 반영한다.
-- 개발건수 대비 중단·감액 및 활동회원 비율을 활용하여 중단율, 감액율, 활동율, 월납입율 및 누계납입율 등의 산출 지표를 계산한다.
-- 기준월의 실측 회비 및 활동회원 데이터를 기반으로 회비(누적), 회비 차액 등의 계산값을 산출하여 예측값과 실측값의 차이를 관리한다.
-- 최종 결과는 DATA_TYPE_NM='실측'으로 저장하며, 기준월·후원사업 그룹·신규/기존·본부/지부 구분을 기준으로 ANNUAL_MBRFEE_PRDT_ACTL_DATA에 적재한다.

전월 실측 데이터를 활용하여 개발 누계, 중단 누계, 활동회원 누계, 누계회비 등 누계 지표를 계산하고, 기준월의 실측값을 반영한다.




CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_ANNUAL_MBRFEE_PRDT_ACTL_DATA(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    STDR_MT VARCHAR;
    BEFORE_MT VARCHAR;
    LYEAR VARCHAR;
BEGIN
    -- 0. 파라미터
    IF (NOT REGEXP_LIKE(input_yyyymm, '^[0-9]{6}$')) THEN
        RETURN 'ERROR: input_yyyymm은 YYYYMM 형식이어야 합니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    IF (TRY_TO_DATE(input_yyyymm || '01', 'YYYYMMDD') IS NULL) THEN
        RETURN 'ERROR: 유효하지 않은 년월입니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    IF (
        TRY_TO_DATE(input_yyyymm || '01', 'YYYYMMDD')
        > DATE_TRUNC('MONTH', CURRENT_DATE())
    ) THEN
        RETURN 'ERROR: 미래 년월은 입력할 수 없습니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    STDR_MT := input_yyyymm;
    BEFORE_MT := 
        TO_CHAR(
           DATEADD(MONTH, -1, TO_DATE(:STDR_MT, 'YYYYMM')),
           'YYYYMM'
        );
    LYEAR := 
        TO_CHAR(
            DATEADD(YEAR, -1, TO_DATE(:STDR_MT, 'YYYYMM')),
            'YYYY'
        );
    DELETE 
    FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
    WHERE DATA_TYPE_NM = '실측'
        AND STDR_MT = :STDR_MT; 
    
    INSERT INTO GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
    WITH BASE AS (
        SELECT
            STDR_MT,
            SPNSR_BSNS_GRP_NM,
            NEW_EXST_DIV_NM,
            CASE
                WHEN NEW_EXST_DIV_NM = '신규' THEN HDQ_BRNCH_GRP_NM
                ELSE '기존'
            END AS HDQ_BRNCH_GRP_NM,
            /* 개발 */
            SUM(CASE
                WHEN AGGR_TY_NM = '개발'
                THEN VALUE1 ELSE 0
            END) AS DVLP_CNT,
    
            /* 중단 */
            SUM(CASE
                WHEN AGGR_TY_NM = '중단'
                THEN VALUE1 ELSE 0
            END) AS ADJ_DSCNTC_CNT,
    
            /* 감액 */
            SUM(CASE
                WHEN AGGR_TY_NM = '감액'
                THEN VALUE1 ELSE 0
            END) AS ADJ_RDCAMT_CNT,
    
            /* 활동 */
            SUM(CASE
                WHEN AGGR_TY_NM = '활동'
                THEN VALUE1 ELSE 0
            END) AS CMLT_EOM_ACT_MBER_CNT,
    
            /* 회비 */
            SUM(CASE
                WHEN AGGR_TY_NM = '회비'
                THEN VALUE1 ELSE 0
            END) AS ADJ_MBRFEE_AMT,
    
            /* 누계회비 */
            SUM(CASE
                WHEN AGGR_TY_NM = '회비'
                THEN VALUE2 ELSE 0
            END) AS ADJ_CMLT_MBRFEE_AMT
        FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
        WHERE STDR_MT = :STDR_MT
        GROUP BY
            STDR_MT,
            SPNSR_BSNS_GRP_NM,
            NEW_EXST_DIV_NM,
            CASE
                WHEN NEW_EXST_DIV_NM = '신규' THEN HDQ_BRNCH_GRP_NM
                ELSE '기존'
            END
    )
        -- A는 예측치. 후원사업별로 4행씩 존재. 신규본부 / 신규지부 / 신규본부지부 / 기존통합 
        -- SCAD는 CRM데이터 기반 집계값. 후원사업별로 3행씩 존재. 신규본부 / 신규지부 / 기존기존
        -- 261020 SCAD는 MSTR 데이터 기반 집계값. 후원사업별로 3행씩 존재. 신규본부 / 신규지부 / 기존기존. 마감후 현업이 파일 전달하기로 함. 
        -- 실측은 실측치 그대로 사용
        -- BF는 이전달 실측치
        -- 예측은 예측치 그대로 사용
        -- 계산은 계산식 필요
        -- 기준월까지는 해당 월의 예측치 명칭 사용
        SELECT 
            '실측' AS "생성용 예측 실측 구분 명",
            A.SPNSR_BSNS_GRP_NM,
            A.NEW_EXST_DIV_NM,
            A.HDQ_BRNCH_GRP_NM,
            A.STDR_MT,
            SCAD.DVLP_CNT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.DVLP_CNT
                ELSE BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT
            END AS CMLT_DVLP_CNT,
            A.ADJ_DSCNTC_RT AS ADJ_DSCNTC_RT, 
            SCAD.ADJ_DSCNTC_CNT AS ADJ_DSCNTC_CNT, 
            A.ADJ_RDCAMT_RT AS ADJ_RDCAMT_RT, 
            CASE
                WHEN SCAD.HDQ_BRNCH_GRP_NM != '기존' AND RIGHT(:STDR_MT, 2) = '01' THEN A.ADJ_DSCNTC_RT * SCAD.DVLP_CNT
                ELSE SCAD.ADJ_RDCAMT_CNT
            END AS ADJ_RDCAMT_CNT,
            CASE
                WHEN A.NEW_EXST_DIV_NM = '기존' THEN A.ADJ_DSCNTC_RT
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.ADJ_DSCNTC_CNT / NULLIF(SCAD.DVLP_CNT, 0), 0)
                ELSE COALESCE(SCAD.ADJ_DSCNTC_CNT / NULLIF((BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT), 0), 0)
            END AS ADJ_RECALC_DSCNTC_RT, 
            SCAD.ADJ_DSCNTC_CNT AS ADJ_DSCNTC_CNT2,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.ADJ_DSCNTC_CNT
                ELSE SCAD.ADJ_DSCNTC_CNT + BF.ADJ_CMLT_DSCNTC_CNT
            END AS ADJ_CMLT_DSCNTC_CNT,
            CASE
                WHEN A.NEW_EXST_DIV_NM = '기존' THEN 
                    CASE
                        WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.ADJ_DSCNTC_CNT / (BOY_ACT_CNT.EOF_ACT_MBER_CNT + SCAD.DVLP_CNT)
                        ELSE COALESCE(
                            SCAD.ADJ_DSCNTC_CNT
                            / NULLIF((BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT), 0),
                            0
                        )
                    END
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.ADJ_DSCNTC_CNT / NULLIF(SCAD.DVLP_CNT, 0), 0)
                ELSE COALESCE(SCAD.ADJ_DSCNTC_CNT / NULLIF((BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT), 0), 0)
            END AS DSCNTC_RT,
            SCAD.ADJ_DSCNTC_CNT AS DSCNTC_CNT,
            CASE
                WHEN A.NEW_EXST_DIV_NM = '기존' THEN 
                    CASE
                        WHEN RIGHT(:STDR_MT, 2) = '01' THEN ((BOY_ACT_CNT.EOF_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT) + SCAD.ADJ_RDCAMT_CNT) / (BOY_ACT_CNT.EOF_ACT_MBER_CNT + SCAD.DVLP_CNT)
                        ELSE COALESCE((SCAD.ADJ_DSCNTC_CNT + SCAD.ADJ_RDCAMT_CNT) / NULLIF((BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT), 0), 0)
                    END
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE((SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT + SCAD.ADJ_RDCAMT_CNT) / NULLIF(SCAD.DVLP_CNT, 0), 0)
                ELSE COALESCE((BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT + SCAD.ADJ_RDCAMT_CNT) / NULLIF((BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT), 0), 0)
            END AS RDCAMT_RT,
            CASE
                WHEN A.NEW_EXST_DIV_NM = '기존' THEN 
                    CASE
                        WHEN RIGHT(:STDR_MT, 2) = '01' THEN BOY_ACT_CNT.EOF_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT
                        ELSE BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT
                        -- D134+E120-E134-E130-E133
                        -- BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT
                    END                    
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT
                ELSE BF.CMLT_EOM_ACT_MBER_CNT + SCAD.DVLP_CNT - SCAD.CMLT_EOM_ACT_MBER_CNT - SCAD.ADJ_DSCNTC_CNT - SCAD.ADJ_RDCAMT_CNT
            END AS SPNSR_BSNS_CHN_DEC_CNT,
            SCAD.ADJ_RDCAMT_CNT AS RDCAMT_CNT,
            SCAD.CMLT_EOM_ACT_MBER_CNT AS CMLT_EOM_ACT_MBER_CNT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.CMLT_EOM_ACT_MBER_CNT
                ELSE BF.CMLT_ACT_MBER_CNT + SCAD.CMLT_EOM_ACT_MBER_CNT
            END AS CMLT_ACT_MBER_CNT,
            CASE
                WHEN A.NEW_EXST_DIV_NM = '기존' AND RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.CMLT_EOM_ACT_MBER_CNT / NULLIF((BOY_ACT_CNT.EOF_ACT_MBER_CNT  + SCAD.DVLP_CNT), 0), 0)
                WHEN A.NEW_EXST_DIV_NM = '기존' AND RIGHT(:STDR_MT, 2) != '01' THEN COALESCE(SCAD.CMLT_EOM_ACT_MBER_CNT / NULLIF((BF.CMLT_EOM_ACT_MBER_CNT  + BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT), 0), 0)
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.CMLT_EOM_ACT_MBER_CNT / NULLIF(SCAD.DVLP_CNT, 0), 0)
                ELSE COALESCE(SCAD.CMLT_EOM_ACT_MBER_CNT / NULLIF((BF.CMLT_DVLP_CNT + SCAD.DVLP_CNT), 0), 0)
            END AS ACT_RT,   
            COALESCE(SCAD.ADJ_MBRFEE_AMT / NULLIF((SCAD.CMLT_EOM_ACT_MBER_CNT * 10000), 0), 0) AS ADJ_MT_PAY_RT,
            SCAD.ADJ_MBRFEE_AMT AS ADJ_MBRFEE_AMT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.ADJ_MBRFEE_AMT / NULLIF((SCAD.CMLT_EOM_ACT_MBER_CNT * 10000), 0), 0)
                ELSE COALESCE((SCAD.ADJ_MBRFEE_AMT + BF.CMLT_MBRFEE_AMT) / NULLIF(((BF.CMLT_ACT_MBER_CNT + SCAD.CMLT_EOM_ACT_MBER_CNT) * 10000), 0), 0)
            END AS ADJ_CMLT_PAY_RT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.ADJ_MBRFEE_AMT
                ELSE SCAD.ADJ_MBRFEE_AMT + BF.CMLT_MBRFEE_AMT
            END AS ADJ_CMLT_MBRFEE_AMT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN COALESCE(SCAD.ADJ_MBRFEE_AMT / NULLIF((SCAD.CMLT_EOM_ACT_MBER_CNT * 10000), 0), 0)
                ELSE COALESCE((SCAD.ADJ_MBRFEE_AMT + BF.CMLT_MBRFEE_AMT) / NULLIF(((BF.CMLT_ACT_MBER_CNT + SCAD.CMLT_EOM_ACT_MBER_CNT) * 10000), 0), 0)
            END AS CMLT_PAY_RT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN SCAD.ADJ_MBRFEE_AMT
                ELSE (BF.CMLT_ACT_MBER_CNT + SCAD.CMLT_EOM_ACT_MBER_CNT) * COALESCE((SCAD.ADJ_MBRFEE_AMT + BF.CMLT_MBRFEE_AMT) / NULLIF((BF.CMLT_ACT_MBER_CNT + SCAD.CMLT_EOM_ACT_MBER_CNT) * 10000, 0) * 10000, 0)
            END AS CMLT_MBRFEE_AMT, 
            0 AS MBRFEE_DIFF_AMT
            -- --계산 해당월 회비(누적) - 전년도 동월 회비(누적)
        FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA A
        LEFT OUTER JOIN (
            SELECT *
            FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
            WHERE STDR_MT = :BEFORE_MT
            AND DATA_TYPE_NM = '실측'
        ) BF ON A.SPNSR_BSNS_GRP_NM = BF.SPNSR_BSNS_GRP_NM AND A.NEW_EXST_DIV_NM = BF.NEW_EXST_DIV_NM AND A.HDQ_BRNCH_GRP_NM = BF.HDQ_BRNCH_GRP_NM
        LEFT OUTER JOIN (
            SELECT
                STDR_MT,
                SPNSR_BSNS_GRP_NM,
                NEW_EXST_DIV_NM,
                HDQ_BRNCH_GRP_NM,
                DVLP_CNT,
                ADJ_DSCNTC_CNT,
                ADJ_RDCAMT_CNT,
                CMLT_EOM_ACT_MBER_CNT,
                ADJ_MBRFEE_AMT,
                ADJ_CMLT_MBRFEE_AMT
            FROM BASE
            UNION ALL
            /* 신규 + 본부/지부 합계 */
            SELECT
                STDR_MT,
                SPNSR_BSNS_GRP_NM,
                '신규' AS NEW_EXST_DIV_NM,
                '본부지부' AS HDQ_BRNCH_GRP_NM,
                SUM(DVLP_CNT) AS DVLP_CNT,
                SUM(ADJ_DSCNTC_CNT) AS ADJ_DSCNTC_CNT,
                SUM(ADJ_RDCAMT_CNT) AS ADJ_RDCAMT_CNT,
                SUM(CMLT_EOM_ACT_MBER_CNT) AS CMLT_EOM_ACT_MBER_CNT,
                SUM(ADJ_MBRFEE_AMT) AS ADJ_MBRFEE_AMT,
                SUM(ADJ_CMLT_MBRFEE_AMT) AS ADJ_CMLT_MBRFEE_AMT
            FROM BASE
            WHERE NEW_EXST_DIV_NM = '신규'
              AND HDQ_BRNCH_GRP_NM IN ('본부', '지부')
            GROUP BY
                STDR_MT,
                SPNSR_BSNS_GRP_NM
        ) SCAD ON A.STDR_MT = SCAD.STDR_MT AND A.SPNSR_BSNS_GRP_NM = SCAD.SPNSR_BSNS_GRP_NM AND A.NEW_EXST_DIV_NM = SCAD.NEW_EXST_DIV_NM AND A.HDQ_BRNCH_GRP_NM = SCAD.HDQ_BRNCH_GRP_NM
        LEFT OUTER JOIN (
            SELECT *
            FROM VALUES
                ('2025', '해외아동결연', 601882.5),
                ('2025', '국내(사단)', 297289.58),
                ('2025', '보건의료지원사업', 205097.57),
                ('2025', '식수위생지원사업', 40782.59),
                ('2025', '해외교육지원사업', 35145.75),
                ('2025', '희망학교지원사업', 16274.54),
                ('2025', '재난구호지원사업', 11019.15),
                ('2025', '해외지역개발사업', 83321.72),
                ('2025', '대북지원사업', 3366.45),
                ('2025', '좋은이웃', 2384.23),
                ('2025', '전체사업지원', 14743.99)
            AS T (LYEAR, SPNSR_BSNS_GRP_NM, EOF_ACT_MBER_CNT)
            UNION ALL
            SELECT 
                LEFT(STDR_MT, 4) AS LYEAR, SPNSR_BSNS_GRP_NM, SUM(CMLT_EOM_ACT_MBER_CNT) AS EOF_ACT_MBER_CNT
            FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
            WHERE 
                DATA_TYPE_NM = '실측'
                AND (
                    (STDR_MT = LEFT(:LYEAR, 4) || '11' AND HDQ_BRNCH_GRP_NM = '기존') or
                    (STDR_MT = LEFT(:LYEAR, 4) || '12' AND HDQ_BRNCH_GRP_NM IN ('본부', '지부'))
                )
            GROUP BY 
                LEFT(STDR_MT, 4), SPNSR_BSNS_GRP_NM
        ) BOY_ACT_CNT ON A.SPNSR_BSNS_GRP_NM = BOY_ACT_CNT.SPNSR_BSNS_GRP_NM AND BOY_ACT_CNT.LYEAR = :LYEAR
    WHERE A.DATA_TYPE_NM = '예측' 
        AND A.STDR_MT = :STDR_MT
    ORDER BY
        A.STDR_MT,
        A.SPNSR_BSNS_GRP_NM,
        A.NEW_EXST_DIV_NM;
    
    RETURN 'SUCCESS: ' || :STDR_MT;
END;
$$;



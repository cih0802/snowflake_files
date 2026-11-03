-- 실측치 인입 후 기존 예측치 값 일괄 업데이트. 
-- 당월 실측 데이터를 기반으로 회원회비 관련 실측·누계·비율·차이 지표를 산출하여 이후 기존 예측 월간 데이터를 갱신
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 실측 데이터(DATA_TYPE_NM='실측')를 삭제 후 재산출한다.
-- MM_SPNSR_CLS_AGGR_DATA의 개발·중단·감액·활동·회비 집계 데이터를 기준으로 월별 개발건수, 중단건수, 감액건수, 월말 활동회원수, 회비금액 및 누계회비를 산출한다.
-- 신규 회원은 본부·지부별 실적과 본부지부 합계를 함께 구성하고, 기존 회원은 기존으로 통합하여 예측 데이터와 실측 데이터를 동일한 기준으로 비교한다.
-- 전월 실측 데이터를 활용하여 개발 누계, 중단 누계, 활동회원 누계, 누계회비 등 누계 지표를 계산하고, 기준월의 실측값을 반영한다.
-- 개발건수 대비 중단·감액 및 활동회원 비율을 활용하여 중단율, 감액율, 활동율, 월납입율 및 누계납입율 등의 산출 지표를 계산한다.
-- 기준월의 실측 회비 및 활동회원 데이터를 기반으로 회비(누적), 회비 차액 등의 계산값을 산출하여 예측값과 실측값의 차이를 관리한다.
-- 최종 결과는 DATA_TYPE_NM='실측'으로 저장하며, 기준월·후원사업 그룹·신규/기존·본부/지부 구분을 기준으로 ANNUAL_MBRFEE_PRDT_ACTL_DATA을 갱신한다.


CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_UPDATE_ANNUAL_MBRFEE_PRDT_ACTL_DATA2(STDR_MT VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    LYEAR_MT VARCHAR;
    BEFORE_MT VARCHAR;
BEGIN
    -- 여기에 질문에서 제공한 UPDATE문 전체를 넣습니다.
    -- 계산식, JOIN, WHERE 조건은 그대로 유지합니다.
    --
    LYEAR_MT := 
        TO_CHAR(
           DATEADD(YEAR, -1, TO_DATE(:STDR_MT, 'YYYYMM')),
           'YYYY'
        ) || '12';
    -- UPDATE문 실행 
    BEFORE_MT := 
        TO_CHAR(
            DATEADD(MONTH, -1, TO_DATE(:STDR_MT, 'YYYYMM')),
            'YYYYMM'
        );
    UPDATE GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA T
    SET
        T.CMLT_DVLP_CNT = C.CMLT_DVLP_CNT,
        T.ADJ_DSCNTC_CNT = C.ADJ_DSCNTC_CNT,
        T.ADJ_RDCAMT_CNT = C.ADJ_RDCAMT_CNT,
        T.ADJ_DSCNTC_CNT2 = C.ADJ_DSCNTC_CNT2,
        T.ADJ_CMLT_DSCNTC_CNT = C.ADJ_CMLT_DSCNTC_CNT,
        T.DSCNTC_RT = C.DSCNTC_RT,
        T.DSCNTC_CNT = C.DSCNTC_CNT,
        T.RDCAMT_RT = C.RDCAMT_RT,
        T.SPNSR_BSNS_CHN_DEC_CNT = C.SPNSR_BSNS_CHN_DEC_CNT,
        T.RDCAMT_CNT = C.RDCAMT_CNT,
        T.CMLT_EOM_ACT_MBER_CNT = C.CMLT_EOM_ACT_MBER_CNT,
        T.CMLT_ACT_MBER_CNT = C.CMLT_ACT_MBER_CNT,
        T.ACT_RT = C.ACT_RT,
        T.ADJ_MT_PAY_RT = C.ADJ_MT_PAY_RT,
        T.ADJ_MBRFEE_AMT = C.ADJ_MBRFEE_AMT,
        T.ADJ_CMLT_PAY_RT = C.ADJ_CMLT_PAY_RT,
        T.ADJ_CMLT_MBRFEE_AMT = C.ADJ_CMLT_MBRFEE_AMT,
        T.CMLT_PAY_RT = C.CMLT_PAY_RT,
        T.CMLT_MBRFEE_AMT = C.CMLT_MBRFEE_AMT
        -- T.MBRFEE_DIFF_AMT = C.MBRFEE_DIFF_AMT
    FROM (
            SELECT 
            A.DATA_TYPE_NM,
            A.SPNSR_BSNS_GRP_NM,
            A.NEW_EXST_DIV_NM,
            A.HDQ_BRNCH_GRP_NM,
            A.STDR_MT,
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN A.DVLP_CNT
                ELSE BF.CMLT_DVLP_CNT + A.DVLP_CNT
            END AS CMLT_DVLP_CNT, --121 L121+M120
            (A.DVLP_CNT + BF.CMLT_EOM_ACT_MBER_CNT) * A.ADJ_DSCNTC_RT AS ADJ_DSCNTC_CNT, --123 (M120+L134)*M122
            (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT AS ADJ_RDCAMT_CNT, --125 (L134+M120)*M124                       
            (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT AS ADJ_DSCNTC_CNT2, --127 (L134+M120)*M126    
            ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) + BF.ADJ_CMLT_DSCNTC_CNT AS ADJ_CMLT_DSCNTC_CNT, 
                -- D95+C93
                -- ADJ_DSCNTC_CNT2 + BF.ADJ_CMLT_DSCNTC_CNT
            ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) / (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) AS DSCNTC_RT, 
                --ADJ_DSCNTC_CNT2 / (BF.CMLT_EOM_ACT_MBER_CNT +  A.DVLP_CNT)
            (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT AS DSCNTC_CNT, 
                -- A.ADJ_DSCNTC_CNT2
            COALESCE(
                (
                    (
                        BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT 
                        - (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) 
                        - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) 
                        - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)
                    )
                    + 
                    ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)
                ) 
                / (NULLIF(BF.CMLT_EOM_ACT_MBER_CNT, 0) + NULLIF(A.DVLP_CNT, 0)), 0) AS RDCAMT_RT, 
                --(SPNSR_BSNS_CHN_DEC_CNT+RDCAMT_CNT)/(BF.CMLT_EOM_ACT_MBER_CNT+DVLP_CNT)
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN A.DVLP_CNT - A.CMLT_EOM_ACT_MBER_CNT - A.ADJ_DSCNTC_CNT - A.ADJ_RDCAMT_CNT
                ELSE BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT 
                - (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) 
                - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) 
                - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)
            END AS SPNSR_BSNS_CHN_DEC_CNT,
                --(C99+D85-D99-D95-D98)
                --(BF.CMLT_EOM_ACT_MBER_CNT + DVLP_CNT - CMLT_EOM_ACT_MBER_CNT - DSCNTC_CNT - RDCAMT_CNT)
            (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT AS RDCAMT_CNT, --ADJ_RDCAMT_CNT
            BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT) AS CMLT_EOM_ACT_MBER_CNT,  
                --C99+D85-D92-D90
                --(BF.CMLT_EOM_ACT_MBER_CNT + DVLP_CNT - ADJ_DSCNTC_CNT2 - ADJ_RDCAMT_CNT)          
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN A.CMLT_EOM_ACT_MBER_CNT
                ELSE BF.CMLT_ACT_MBER_CNT + (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT))
            END AS CMLT_ACT_MBER_CNT, 
                -- C100+D99
                -- BF.CMLT_ACT_MBER_CNT + CMLT_EOM_ACT_MBER_CNT                
            (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) / (LYEAR.EOF_ACT_MBER_CNT + (BF.CMLT_DVLP_CNT + A.DVLP_CNT)) AS ACT_RT,  
            -- D99/($C$84+D86)
            -- BF.CMLT_EOM_ACT_MBER_CNT / (EOF_ACT_MBER_CNT + BF.CMLT_DVLP_CNT)
            -- 261015 허지혜 차장에게 문의 기존표의 월말활동회원건수 12월 수치
            A.ADJ_MT_PAY_RT, --137 
            (
                (
                    BF.CMLT_EOM_ACT_MBER_CNT 
                    + A.DVLP_CNT 
                    - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RECALC_DSCNTC_RT) 
                    - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)
                ) * 10000
            ) * A.ADJ_MT_PAY_RT AS ADJ_MBRFEE_AMT, 
                --(D99*10000)*D102   
                -- (CMLT_EOM_ACT_MBER_CNT * 10000) * ADJ_MT_PAY_RT
            ((((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) * 10000) * A.ADJ_MT_PAY_RT) + BF.CMLT_MBRFEE_AMT) /
            ((BF.CMLT_ACT_MBER_CNT + (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT))) * 10000)
            AS ADJ_CMLT_PAY_RT,
                -- D105/(D100*10000)
                -- ADJ_CMLT_MBRFEE_AMT / (CMLT_ACT_MBER_CNT * 10000)
            CASE
                WHEN RIGHT(:STDR_MT, 2) = '01' THEN A.ADJ_MBRFEE_AMT
                ELSE (((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) * 10000) * A.ADJ_MT_PAY_RT) + BF.CMLT_MBRFEE_AMT
            END AS ADJ_CMLT_MBRFEE_AMT, 
                -- D103+C107
                -- ADJ_MBRFEE_AMT + BF.CMLT_MBRFEE_AMT
            ((((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) * 10000) * A.ADJ_MT_PAY_RT) + BF.CMLT_MBRFEE_AMT) /
            ((BF.CMLT_ACT_MBER_CNT + (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)))* 10000) 
            AS CMLT_PAY_RT, 
            ((BF.CMLT_ACT_MBER_CNT + (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT))) * 10000) *
            (
                ((((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)) * 10000) * A.ADJ_MT_PAY_RT) + BF.CMLT_MBRFEE_AMT) /
                ((BF.CMLT_ACT_MBER_CNT + (BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) *  A.ADJ_RECALC_DSCNTC_RT) - ((BF.CMLT_EOM_ACT_MBER_CNT + A.DVLP_CNT) * A.ADJ_RDCAMT_RT)))* 10000) 
            )
            AS CMLT_MBRFEE_AMT, 
                --(D100*10000)*D106
                -- (CMLT_ACT_MBER_CNT * 10000) * CMLT_PAY_RT
            -- 0 AS MBRFEE_DIFF_AMT  
        FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA A
        LEFT OUTER JOIN (
            SELECT *
            FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA INA
            WHERE INA.STDR_MT = :BEFORE_MT
            AND (
                INA.DATA_TYPE_NM = '실측'
                OR (
                    INA.DATA_TYPE_NM = '예측'
                    AND NOT EXISTS (
                        SELECT 1
                        FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA INB
                        WHERE INB.STDR_MT = INA.STDR_MT
                            AND INB.SPNSR_BSNS_GRP_NM = INA.SPNSR_BSNS_GRP_NM
                            AND INB.NEW_EXST_DIV_NM = INA.NEW_EXST_DIV_NM
                            AND INB.HDQ_BRNCH_GRP_NM = INA.HDQ_BRNCH_GRP_NM
                            AND INB.DATA_TYPE_NM = '실측'
                  )
              )
            )
        ) BF ON A.SPNSR_BSNS_GRP_NM = BF.SPNSR_BSNS_GRP_NM AND A.NEW_EXST_DIV_NM = BF.NEW_EXST_DIV_NM AND A.HDQ_BRNCH_GRP_NM = BF.HDQ_BRNCH_GRP_NM
        LEFT OUTER JOIN (
            -- 연도초활동회원(건) 계산 수식 
            -- 최년도인 2026년의 경우 하드코딩해서 쓴다.....어쩔수가 없다.....
            -- 다음년도부턴 계산 
            -- (전년도 12월 신규본부+지부표 12월 활동회원건수(누적) - 11월 활동회원건수(누적)) + 전년도 12월 기존표 12월 활동회원건수(누적)  
            SELECT *
            FROM VALUES
                ('202512', 601882.5, '해외아동결연'),
                ('202512', 297289.58, '국내(사단)'),
                ('202512', 205097.57, '보건의료지원사업'),
                ('202512', 40782.59, '식수위생지원사업'),
                ('202512', 35145.75, '해외교육지원사업'),
                ('202512', 16274.54, '희망학교지원사업'),
                ('202512', 11019.15, '재난구호지원사업'),
                ('202512', 83321.72, '해외지역개발사업'),
                ('202512', 3366.45, '대북지원사업'),
                ('202512', 2384.23, '좋은이웃'),
                ('202512', 14743.99, '전체사업지원')
            AS T (STDR_MT, EOF_ACT_MBER_CNT, SPNSR_BSNS_GRP_NM)
            UNION ALL
            SELECT STDR_MT, CMLT_EOM_ACT_MBER_CNT AS EOF_ACT_MBER_CNT, SPNSR_BSNS_GRP_NM
            FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
            WHERE 
                DATA_TYPE_NM = '실측'
                AND HDQ_BRNCH_GRP_NM = '기존'
                AND STDR_MT = :LYEAR_MT
        ) LYEAR ON A.SPNSR_BSNS_GRP_NM = LYEAR.SPNSR_BSNS_GRP_NM AND LYEAR.STDR_MT = :LYEAR_MT
    WHERE A.DATA_TYPE_NM = '예측' 
        AND A.STDR_MT = :STDR_MT
    ) C
    WHERE T.STDR_MT = C.STDR_MT
      AND T.SPNSR_BSNS_GRP_NM = C.SPNSR_BSNS_GRP_NM
      AND T.NEW_EXST_DIV_NM = C.NEW_EXST_DIV_NM
      AND T.HDQ_BRNCH_GRP_NM = C.HDQ_BRNCH_GRP_NM
      AND T.DATA_TYPE_NM = '예측'
      AND T.HDQ_BRNCH_GRP_NM = '기존';

    RETURN 'UPDATE 완료';
END;
$$;



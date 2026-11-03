-- 예측 타입 데이터는 연초 csv 파일로 인입. 
-- 연간 회원회비 예측 CSV 파일을 기준으로 해당 연도 데이터를 초기화
-- 연도초예측/예측 데이터를 ANNUAL_MBRFEE_PRDT_ACTL_DATA에 적재
-- 기준연도를 입력받아 연간 회원회비 예측치 CSV 파일을 조회하고, 기존 해당 연도 데이터를 삭제한 후 예측 데이터를 적재한다.
-- 기준연도(YYYY)를 기준으로 대상 파일명 {YEAR}_ANNUAL_MBRFEE_PRDT_ACTL_DATA.csv를 생성한다.
-- CSV 업로드 스테이지의 디렉터리 메타데이터를 갱신한 후, 해당 연도의 기존 ANNUAL_MBRFEE_PRDT_ACTL_DATA 데이터를 삭제한다.
-- 대상 파일이 존재하는지 확인하고, 파일이 없을 경우 적재를 종료한다.
-- UTF-8 CSV 파일을 대상으로 첫 번째 헤더 행을 제외하고 데이터를 적재하며, 적재 데이터의 구분값은 연도초예측/예측으로 설정한다.
-- CSV 내 월별 회원회비 데이터를 쉼표 제거 후 숫자형으로 변환하며, 변환할 수 없는 값은 0으로 처리한다.
-- 기존 연도 데이터를 삭제 후 전체 예측 데이터를 재적재하여 연도별 회원회비 예측 데이터를 관리한다.

CREATE OR REPLACE TABLE GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA (
    DATA_TYPE_NM VARCHAR COMMENT '예측 실측 구분 명',
    SPNSR_BSNS_GRP_NM VARCHAR COMMENT '후원 사업 그룹 명',
    NEW_EXST_DIV_NM VARCHAR COMMENT '신규기존구분명',
    HDQ_BRNCH_GRP_NM VARCHAR COMMENT '본부 지부 그룹 명',
    STDR_MT VARCHAR COMMENT	'기준월',
    DVLP_CNT NUMBER(38, 18) COMMENT '개발건수',
    CMLT_DVLP_CNT NUMBER(38, 18) COMMENT '누적개발건수',
    ADJ_DSCNTC_RT NUMBER(38, 18) COMMENT '조정 중단율',
    ADJ_DSCNTC_CNT NUMBER(38, 18) COMMENT '조정 중단건수',
    ADJ_RDCAMT_RT NUMBER(38, 18) COMMENT '조정 감액율',
    ADJ_RDCAMT_CNT NUMBER(38, 18) COMMENT '조정 감액건수',
    ADJ_RECALC_DSCNTC_RT NUMBER(38, 18) COMMENT '조정 재산출 중단율',
    ADJ_DSCNTC_CNT2 NUMBER(38, 18) COMMENT '조정 중단건수2',
    ADJ_CMLT_DSCNTC_CNT NUMBER(38, 18) COMMENT '조정 누계 중단건수',
    DSCNTC_RT NUMBER(38, 18) COMMENT '중단율',
    DSCNTC_CNT NUMBER(38, 18) COMMENT '중단건수',
    RDCAMT_RT NUMBER(38, 18) COMMENT '감액율',
    SPNSR_BSNS_CHN_DEC_CNT NUMBER(38, 18) COMMENT '후원사업변경감소건수',
    RDCAMT_CNT NUMBER(38, 18) COMMENT '2 감액 건수2',
    CMLT_EOM_ACT_MBER_CNT NUMBER(38, 18) COMMENT '누적 월말활동회원건수',
    CMLT_ACT_MBER_CNT NUMBER(38, 18) COMMENT '누적 활동회원건수',
    ACT_RT NUMBER(38, 18) COMMENT '활동율',
    ADJ_MT_PAY_RT NUMBER(38, 18) COMMENT '조정 월납입율',
    ADJ_MBRFEE_AMT NUMBER(38, 18) COMMENT '조정 회비',
    ADJ_CMLT_PAY_RT NUMBER(38, 18) COMMENT '조정 누계납입율',
    ADJ_CMLT_MBRFEE_AMT NUMBER(38, 18) COMMENT '조정 누계회비',
    CMLT_PAY_RT NUMBER(38, 18) COMMENT '누계납입율',
    CMLT_MBRFEE_AMT NUMBER(38, 18) COMMENT '누적 회비',
    MBRFEE_DIFF_AMT NUMBER(38, 18) COMMENT '회비 차액'
) COMMENT='회원실 연간 회비 예측 실측 데이터';



CREATE STAGE IF NOT EXISTS GN_DW.SILVER.CSV_UPLOAD_STAGE
DIRECTORY = (ENABLE = TRUE);
ALTER STAGE GN_DW.SILVER.CSV_UPLOAD_STAGE SET DIRECTORY = (ENABLE = TRUE);
ALTER STAGE GN_DW.SILVER.CSV_UPLOAD_STAGE REFRESH;


-- UTF-8 전용
CREATE OR REPLACE FILE FORMAT GN_DW.SILVER.GN_CSV_FORMAT_UTF8
    TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"';


-- 예측/ 연도초예측만 인입
SET YEAR = '2026';
SET FILE_NAME = $YEAR || '_' || 'ANNUAL_MBRFEE_PRDT_ACTL_DATA_261026.csv';
SELECT $YEAR, $FILE_NAME;
DECLARE
    v_file_name VARCHAR;
    v_delete_sql VARCHAR;
    v_copy_sql VARCHAR;
BEGIN
    -- 디렉터리 메타데이터 갱신
    ALTER STAGE GN_DW.SILVER.CSV_UPLOAD_STAGE REFRESH;

    
    -- 해당 기준연월 기존 데이터 삭제
    v_delete_sql := 'DELETE FROM GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA WHERE LEFT(STDR_MT, 4) = ''' || $YEAR || '''';
    EXECUTE IMMEDIATE v_delete_sql;
   
    -- 대상 파일 조회
    SELECT RELATIVE_PATH
      INTO :v_file_name
    FROM DIRECTORY(@GN_DW.SILVER.CSV_UPLOAD_STAGE)
    WHERE RELATIVE_PATH = $FILE_NAME;

    -- 파일이 없으면 종료
    IF (v_file_name IS NULL) THEN
        RETURN $FILE_NAME || ' 파일이 존재하지 않아 종료합니다.';
    END IF;

    v_copy_sql := '
        COPY INTO GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
        FROM (
            SELECT
                ''연도초예측'', $1,$2,$3,$4,
                NVL(TRY_TO_NUMBER(REPLACE($5, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($6, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($7, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($8, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($9, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($10, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($11, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($12, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($13, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($14, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($15, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($16, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($17, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($18, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($19, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($20, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($21, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($22, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($23, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($24, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($25, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($26, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($27, '','', ''''), 38, 18), 0), 
                0
            FROM @GN_DW.SILVER.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''GN_DW.SILVER.GN_CSV_FORMAT_UTF8'', PATTERN => ''^' || v_file_name || '$'')
            
        ) FORCE = TRUE';
    EXECUTE IMMEDIATE v_copy_sql;
    
    -- 해당 파일 데이터 적재
    v_copy_sql := '
        COPY INTO GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA
        FROM (
            SELECT
                ''예측'', $1,$2,$3,$4,
                NVL(TRY_TO_NUMBER(REPLACE($5, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($6, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($7, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($8, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($9, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($10, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($11, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($12, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($13, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($14, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($15, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($16, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($17, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($18, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($19, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($20, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($21, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($22, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($23, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($24, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($25, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($26, '','', ''''), 38, 18), 0),
                NVL(TRY_TO_NUMBER(REPLACE($27, '','', ''''), 38, 18), 0),
                0
            FROM @GN_DW.SILVER.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''GN_DW.SILVER.GN_CSV_FORMAT_UTF8'', PATTERN => ''^' || v_file_name || '$'')
            
        ) FORCE = TRUE';
    EXECUTE IMMEDIATE v_copy_sql;
    RETURN '전체 CSV 파일 적재완료';
END;

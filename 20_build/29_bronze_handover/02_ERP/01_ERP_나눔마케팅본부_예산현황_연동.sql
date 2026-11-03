-- ERP 예산 데이터 스테이지 자동 적재 파이프라인
-- 1. load_erp_to_snowflake.bat 실행파일
--     1-1. 개발 목적
--         ERP 예산 CSV 파일을 Snowflake에 자동 업로드하고, 연도별 예산 데이터를 적재할 수 있도록 Windows 배치 파일(BAT)을 개발함.
--         SnowSQL을 이용하여 파일 업로드 및 적재 프로시저를 실행하며, 처리 결과에 따라 정상 및 오류 여부를 확인할 수 있도록 구성함.
    
--     1-2. 입력 파일 및 처리 기준
--         대상 폴더: C:\data
--         대상 파일 패턴: *_budget.csv
--         파일명 규칙: YYYY_budget.csv (예: 2026_budget.csv)
--         연도 추출 기준: 파일명의 앞 4자리를 연도로 사용함.
--         대상 파일이 여러 개 존재하는 경우 파일 수정 일시를 기준으로 최신 파일을 선택하여 처리함.
--         파일명에서 추출한 연도가 4자리 숫자인지 확인하고, 나머지 파일명이 _budget 형식인지 검증함.
--         대상 파일이 없거나 파일명 규칙에 맞지 않는 경우 오류 로그를 생성하고 처리를 종료함.
    
    
--     1-3. Snowflake 연계 및 데이터 적재
--         SnowSQL을 통해 Snowflake에 접속하여 CSV 파일을 지정된 스테이지에 업로드함.
--         대상 스테이지: GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE
--         파일 업로드 완료 후 연도별 예산 적재 프로시저를 실행함.
--         실행 프로시저: GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR
--         파일명에서 추출한 연도를 프로시저 파라미터로 전달하여 해당 연도의 예산 데이터를 적재함.
--         Snowflake 접속 시 지정된 계정, 사용자, 데이터베이스, 스키마, 웨어하우스 및 역할 정보를 사용하며, 개인키 기반 인증을 적용함.
    
--     1-4. 오류 처리 및 로그 관리
--         파일 검색 실패, 파일 존재 여부 확인 실패, 파일명 형식 오류, 개인키 파일 누락 및 CSV 업로드 실패 등 단계별 오류를 확인함.
--         프로시저 실행 시 SnowSQL 종료 코드와 프로시저 반환 결과를 확인하여 오류 여부를 판별함.
--         프로시저 반환 결과가 ERROR:로 시작하는 경우 적재 오류로 판단하고 오류 메시지를 기록함.
--         오류 로그는 발생 일시, 처리 단계, 대상 파일, 대상 연도 및 오류 내용을 포함하도록 구성함.
--         로그 구분
--         error_budget_file_*.txt: 파일 확인, 파일명 검증, 인증 파일 확인 및 업로드 등 일반 처리 오류
--         error_budget_data_*.txt: 프로시저 실행 및 데이터 적재 관련 오류
--         로그는 날짜별 폴더에 저장하여 오류 발생 시 원인 확인 및 사후 추적이 가능하도록 함.

-- 1-5. 처리 결과 및 종료 기준
--     파일 업로드 및 프로시저 실행이 정상 완료되면 완료 메시지를 출력하고 정상 종료
--     처리 중 오류가 발생하면 해당 오류 내용을 로그로 기록
--     프로시저 실행 결과를 확인하여 SnowSQL 자체 실행은 성공했으나 데이터 적재 과정에서 오류가 발생한 경우도 구분할 수 있도록 함.


-- 2. GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR 프로시져
--     예산 실적 원장 연도별 적재
--     프로시저명: GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR
--     입력 파라미터: 적재 대상 연도(P_YEAR, YYYY 형식)
--     입력값 검증
--     입력 연도가 4자리 숫자 형식인지 확인하고, 유효하지 않은 경우 오류 처리함.
--     대상 파일 조회
--     지정된 Snowflake 스테이지(CSV_UPLOAD_STAGE)의 파일 메타데이터를 갱신함.
--     입력 연도로 시작하고 _budget.csv로 끝나는 파일 중 최종 수정 일시 기준 최신 파일을 선택함.
    
--     기존 데이터 삭제 및 신규 적재
--     대상 연도의 기존 데이터를 예산 원장 테이블(BDGT_ACMSLT_LEDGER)에서 삭제함.
--     선택한 CSV 파일을 지정된 EUC-KR CSV 파일 형식으로 읽어 예산 데이터를 적재함.
--     파일을 찾을 수 없는 경우 오류 처리함.
    
--     오류 처리 및 알림
--         처리 중 발생한 오류 코드, 상태값, 오류 메시지 및 대상 연도·파일명을 오류 로그 테이블(SYNC_ERR_INFO)에 기록함.
--         오류 발생 시 담당자 이메일로 알림을 발송하고 오류 내용을 반환함.
--         정상 처리 시 대상 연도와 파일명을 포함한 적재 완료 메시지를 반환함.


create or replace TABLE GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER (
	YEAR VARCHAR(16777216) COMMENT '연도',
	INCOME_EXPS_DIV_NM VARCHAR(16777216) COMMENT '수지구분',
	BDGT_PRCD_NM VARCHAR(16777216) COMMENT '예산절차',
	BDGT_UNIT_NM VARCHAR(16777216) COMMENT '예산단위',
	JANG_NM VARCHAR(16777216) COMMENT '장',
	KWAN_NM VARCHAR(16777216) COMMENT '관',
	HANG_NM VARCHAR(16777216) COMMENT '항',
	MOK_NM VARCHAR(16777216) COMMENT '목',
	DTL_ITEM_NM VARCHAR(16777216) COMMENT '세목',
	SUBDTL_ITEM_NM VARCHAR(16777216) COMMENT '세세목',
	FUND_SOURCE_NM VARCHAR(16777216) COMMENT '재원',
	BDGT_ITEM_NM VARCHAR(16777216) COMMENT '예산과목',
	VENDOR VARCHAR(16777216) COMMENT '거래처',
	DVLP_INBOUND_PATH VARCHAR(16777216) COMMENT '개발인입경로',
	DIRECT_MNYRS_YN_1 VARCHAR(16777216) COMMENT '직접모금비1',
	DIRECT_MNYRS_YN_2 VARCHAR(16777216) COMMENT '직접모금비2',
	YEAR_BDGT_TOT_AMT NUMBER(38,0) COMMENT '연예산_합계',
	CHN_BDGT_TOT_AMT NUMBER(38,0) COMMENT '변경예산_합계',
	ADJ_BDGT_TOT_AMT NUMBER(38,0) COMMENT '조정예산_합계',
	EXEC_TOT_AMT NUMBER(38,0) COMMENT '집행금액_합계',
	YEAR_BDGT_AMT_1 NUMBER(38,0) COMMENT '연예산_01',
	CHN_BDGT_AMT_1 NUMBER(38,0) COMMENT '변경예산_01',
	ADJ_BDGT_AMT_1 NUMBER(38,0) COMMENT '조정예산_01',
	EXEC_AMT_1 NUMBER(38,0) COMMENT '집행금액_01',
	YEAR_BDGT_AMT_2 NUMBER(38,0) COMMENT '연예산_02',
	CHN_BDGT_AMT_2 NUMBER(38,0) COMMENT '변경예산_02',
	ADJ_BDGT_AMT_2 NUMBER(38,0) COMMENT '조정예산_02',
	EXEC_AMT_2 NUMBER(38,0) COMMENT '집행금액_02',
	YEAR_BDGT_AMT_3 NUMBER(38,0) COMMENT '연예산_03',
	CHN_BDGT_AMT_3 NUMBER(38,0) COMMENT '변경예산_03',
	ADJ_BDGT_AMT_3 NUMBER(38,0) COMMENT '조정예산_03',
	EXEC_AMT_3 NUMBER(38,0) COMMENT '집행금액_03',
	YEAR_BDGT_AMT_4 NUMBER(38,0) COMMENT '연예산_04',
	CHN_BDGT_AMT_4 NUMBER(38,0) COMMENT '변경예산_04',
	ADJ_BDGT_AMT_4 NUMBER(38,0) COMMENT '조정예산_04',
	EXEC_AMT_4 NUMBER(38,0) COMMENT '집행금액_04',
	YEAR_BDGT_AMT_5 NUMBER(38,0) COMMENT '연예산_05',
	CHN_BDGT_AMT_5 NUMBER(38,0) COMMENT '변경예산_05',
	ADJ_BDGT_AMT_5 NUMBER(38,0) COMMENT '조정예산_05',
	EXEC_AMT_5 NUMBER(38,0) COMMENT '집행금액_05',
	YEAR_BDGT_AMT_6 NUMBER(38,0) COMMENT '연예산_06',
	CHN_BDGT_AMT_6 NUMBER(38,0) COMMENT '변경예산_06',
	ADJ_BDGT_AMT_6 NUMBER(38,0) COMMENT '조정예산_06',
	EXEC_AMT_6 NUMBER(38,0) COMMENT '집행금액_06',
	YEAR_BDGT_AMT_7 NUMBER(38,0) COMMENT '연예산_07',
	CHN_BDGT_AMT_7 NUMBER(38,0) COMMENT '변경예산_07',
	ADJ_BDGT_AMT_7 NUMBER(38,0) COMMENT '조정예산_07',
	EXEC_AMT_7 NUMBER(38,0) COMMENT '집행금액_07',
	YEAR_BDGT_AMT_8 NUMBER(38,0) COMMENT '연예산_08',
	CHN_BDGT_AMT_8 NUMBER(38,0) COMMENT '변경예산_08',
	ADJ_BDGT_AMT_8 NUMBER(38,0) COMMENT '조정예산_08',
	EXEC_AMT_8 NUMBER(38,0) COMMENT '집행금액_08',
	YEAR_BDGT_AMT_9 NUMBER(38,0) COMMENT '연예산_09',
	CHN_BDGT_AMT_9 NUMBER(38,0) COMMENT '변경예산_09',
	ADJ_BDGT_AMT_9 NUMBER(38,0) COMMENT '조정예산_09',
	EXEC_AMT_9 NUMBER(38,0) COMMENT '집행금액_09',
	YEAR_BDGT_AMT_10 NUMBER(38,0) COMMENT '연예산_10',
	CHN_BDGT_AMT_10 NUMBER(38,0) COMMENT '변경예산_10',
	ADJ_BDGT_AMT_10 NUMBER(38,0) COMMENT '조정예산_10',
	EXEC_AMT_10 NUMBER(38,0) COMMENT '집행금액_10',
	YEAR_BDGT_AMT_11 NUMBER(38,0) COMMENT '연예산_11',
	CHN_BDGT_AMT_11 NUMBER(38,0) COMMENT '변경예산_11',
	ADJ_BDGT_AMT_11 NUMBER(38,0) COMMENT '조정예산_11',
	EXEC_AMT_11 NUMBER(38,0) COMMENT '집행금액_11',
	YEAR_BDGT_AMT_12 NUMBER(38,0) COMMENT '연예산_12',
	CHN_BDGT_AMT_12 NUMBER(38,0) COMMENT '변경예산_12',
	ADJ_BDGT_AMT_12 NUMBER(38,0) COMMENT '조정예산_12',
	EXEC_AMT_12 NUMBER(38,0) COMMENT '집행금액_12'
)COMMENT='나눔마케팅본부 예산현황'
;

-- =============================================================================
-- 파일 포맷 (GN_CSV_FORMAT_EUCKR) 사용... 261008 헤더 첫번째 줄로 수정
-- TYPE = 'CSV' SKIP_HEADER = 2 FIELD_OPTIONALLY_ENCLOSED_BY = '"' ENCODING = 'EUC-KR';  
-- =============================================================================
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR
    TYPE = 'CSV' SKIP_HEADER = 2 FIELD_OPTIONALLY_ENCLOSED_BY = '"' ENCODING = 'EUC-KR'; 

CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR(P_YEAR VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_file_name VARCHAR;
    v_delete_sql VARCHAR;
    v_copy_sql VARCHAR;

    v_sqlcode NUMBER;
    v_sqlstate VARCHAR;
    v_sqlerrm VARCHAR;

    e_invalid_year EXCEPTION;
    e_file_not_found EXCEPTION;
BEGIN
    -- P_YEAR YYYY 형태 검증 (4자리 숫자)
    IF (:P_YEAR IS NULL OR LENGTH(:P_YEAR) != 4 OR TRY_TO_NUMBER(:P_YEAR) IS NULL) THEN
        RAISE e_invalid_year;
    END IF;

    -- 디렉터리 메타데이터 갱신
    ALTER STAGE GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE REFRESH;

    -- P_YEAR로 시작하고 _budget.csv로 끝나는 파일 중 가장 최근 업로드된 파일 선택
    SELECT RELATIVE_PATH INTO :v_file_name
    FROM DIRECTORY(@GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE)
    WHERE RELATIVE_PATH LIKE :P_YEAR || '%_budget.csv'
    ORDER BY LAST_MODIFIED DESC
    LIMIT 1;

    IF (v_file_name IS NULL) THEN
        RAISE e_file_not_found;
    END IF;

    -- 해당 연도 기존 데이터 삭제
    v_delete_sql := 'DELETE FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER WHERE YEAR = ''' || :P_YEAR || '''';
    EXECUTE IMMEDIATE v_delete_sql;

    -- 해당 파일 데이터 적재
    v_copy_sql := '
        COPY INTO GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
        FROM (
            SELECT
                $1,$2,$3,$4,$5,
                $6,$7,$8,$9,$10,
                $11, $12, $13, $14, $15,
                $16,
                $17,
                $18,
                $19,
                $20,
                $21,
                $22,
                $23,
                $24,
                $25,
                $26,
                $27,
                $28,
                $29,
                $30,
                $31,
                $32,
                $33,
                $34,
                $35,
                $36,
                $37,
                $38,
                $39,
                $40,
                $41,
                $42,
                $43,
                $44,
                $45,
                $46,
                $47,
                $48,
                $49,
                $50,
                $51,
                $52,
                $53,
                $54,
                $55,
                $56,
                $57,
                $58,
                $59,
                $60,
                $61,
                $62,
                $63,
                $64,
                $65,
                $66,
                $67,
                $68
            FROM @GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR'', PATTERN => ''.*' || v_file_name || ''')
        ) FORCE = TRUE';
    EXECUTE IMMEDIATE v_copy_sql;

    RETURN :P_YEAR || ': ' || v_file_name || ' 적재완료';
-- ================================================================
-- 예외 처리
-- ================================================================
EXCEPTION

    WHEN OTHER THEN
        -- 예외 정보 변수에 저장
        v_sqlcode := SQLCODE;
        v_sqlstate := SQLSTATE;
        v_sqlerrm := SQLERRM;
        
        -- 에러 로그 저장
        INSERT INTO GN_DW.BRONZE_ERP.SYNC_ERR_INFO
        (
            ERR_DATETIME,
            DATA_TYPE,
            ERR_INFO
        )
        VALUES
        (
            CURRENT_TIMESTAMP(),
            '예산',
            'P_YEAR='
            || NVL(:P_YEAR, 'NULL')
            || ', FILE='
            || NVL(:v_file_name, 'NULL')
            || ', SQLCODE='
            || :v_sqlcode
            || ', SQLSTATE='
            || :v_sqlstate
            || ', SQLERRM='
            || :v_sqlerrm
        );
        CALL SYSTEM$SEND_EMAIL('EMAIL_ALERT_INTEGRATION',
            'it@gni.kr',
            'ERP 예산 원장 적재 실패',
            'ERROR: '
               || 'P_YEAR='
               || NVL(:P_YEAR, 'NULL')
               || ', FILE='
               || NVL(:v_file_name, 'NULL')
               || ', SQLCODE='
               || :v_sqlcode
               || ', SQLSTATE='
               || :v_sqlstate
               || ', SQLERRM='
               || :v_sqlerrm,
            'text/html'
        );
        RETURN 'ERROR: '
               || 'P_YEAR='
               || NVL(:P_YEAR, 'NULL')
               || ', FILE='
               || NVL(:v_file_name, 'NULL')
               || ', SQLCODE='
               || :v_sqlcode
               || ', SQLSTATE='
               || :v_sqlstate
               || ', SQLERRM='
               || :v_sqlerrm;   
END;
$$;


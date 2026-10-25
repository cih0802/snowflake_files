create or replace schema GN_DW.BRONZE_ERP with managed access COMMENT='원천 데이터 적재 - ERP (SMS/알림톡/마케팅 발송)';

create or replace sequence GN_DW.BRONZE_ERP.SEQ_SYNC_ERR_INFO start with 1 increment by 1 order;
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
create or replace TABLE GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION (
	YEAR VARCHAR(16777216) COMMENT '연도',
	WRITE_DATE DATE COMMENT '작성일자',
	RESOLUTION_NO VARCHAR(16777216) COMMENT '결의번호',
	RESOLUTION_DEPT_NM VARCHAR(16777216) COMMENT '결의부서',
	EXPS_RESOLUTION_NM VARCHAR(16777216) COMMENT '지출결의명',
	SOURCE_DIV_NM VARCHAR(16777216) COMMENT '원천구분',
	SOURCE_NO VARCHAR(16777216) COMMENT '원천번호',
	BDGT_UNIT_NM VARCHAR(16777216) COMMENT '예산단위',
	MOK_NM VARCHAR(16777216) COMMENT '목',
	DTL_ITEM_NM VARCHAR(16777216) COMMENT '세목',
	SUBDTL_ITEM_NM VARCHAR(16777216) COMMENT '세세목',
	FUND_SOURCE_NM VARCHAR(16777216) COMMENT '재원',
	BDGT_ITEM_NM VARCHAR(16777216) COMMENT '예산과목',
	DESCRIPTIONVARCHAR VARCHAR(16777216) COMMENT '적요',
	SUM_AMT NUMBER(38,0) COMMENT '합계금액',
	CONTENTS_DELIMITER VARCHAR(16777216) COMMENT '콘텐츠구분자'
)COMMENT='마케팅 캠페인 제작 비용 / 나눔마케팅본부 캠페인 제작비 지출현황'
;
create or replace TABLE GN_DW.BRONZE_ERP.SYNC_ERR_INFO (
	ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_ERP.SEQ_SYNC_ERR_INFO.NEXTVAL COMMENT '오류 이력 일련번호',
	ERR_DATETIME TIMESTAMP_NTZ(9) COMMENT '오류 발생 일시',
	DATA_TYPE VARCHAR(16777216) COMMENT '오류 데이터 유형',
	ERR_INFO VARCHAR(16777216) COMMENT '오류 상세 내용'
)COMMENT='ERP 외부 파일 업로드 및 데이터 적재 오류 이력'
;
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_ERP.GN_CSV_FORMAT
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
;
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR
	SKIP_HEADER = 2
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
	ENCODING = 'EUC-KR'
;
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR2
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
	ENCODING = 'EUC-KR'
;
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR("P_YEAR" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
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
    WHERE RELATIVE_PATH LIKE :P_YEAR || ''%_budget.csv''
    ORDER BY LAST_MODIFIED DESC
    LIMIT 1;

    IF (v_file_name IS NULL) THEN
        RAISE e_file_not_found;
    END IF;

    -- 해당 연도 기존 데이터 삭제
    v_delete_sql := ''DELETE FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER WHERE YEAR = '''''' || :P_YEAR || '''''''';
    EXECUTE IMMEDIATE v_delete_sql;

    -- 해당 파일 데이터 적재
    v_copy_sql := ''
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
            (FILE_FORMAT => ''''GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR'''', PATTERN => ''''.*'' || v_file_name || '''''')
        ) FORCE = TRUE'';
    EXECUTE IMMEDIATE v_copy_sql;

    RETURN :P_YEAR || '': '' || v_file_name || '' 적재완료'';
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
            ''예산'',
            ''P_YEAR=''
            || NVL(:P_YEAR, ''NULL'')
            || '', FILE=''
            || NVL(:v_file_name, ''NULL'')
            || '', SQLCODE=''
            || :v_sqlcode
            || '', SQLSTATE=''
            || :v_sqlstate
            || '', SQLERRM=''
            || :v_sqlerrm
        );
        CALL SYSTEM$SEND_EMAIL(''EMAIL_ALERT_INTEGRATION'',
            ''it@gni.kr'',
            ''ERP 예산 원장 적재 실패'',
            ''ERROR: ''
               || ''P_YEAR=''
               || NVL(:P_YEAR, ''NULL'')
               || '', FILE=''
               || NVL(:v_file_name, ''NULL'')
               || '', SQLCODE=''
               || :v_sqlcode
               || '', SQLSTATE=''
               || :v_sqlstate
               || '', SQLERRM=''
               || :v_sqlerrm,
            ''text/html''
        );
        RETURN ''ERROR: ''
               || ''P_YEAR=''
               || NVL(:P_YEAR, ''NULL'')
               || '', FILE=''
               || NVL(:v_file_name, ''NULL'')
               || '', SQLCODE=''
               || :v_sqlcode
               || '', SQLSTATE=''
               || :v_sqlstate
               || '', SQLERRM=''
               || :v_sqlerrm;   
END;
';
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_ERP.SP_LOAD_EXPENSE_RESOLUTION_BY_YEAR("P_YEAR" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
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
    ALTER STAGE GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE2 REFRESH;

    -- P_YEAR로 시작하고 _expense.csv로 끝나는 파일 중 가장 최근 업로드된 파일 선택
    SELECT RELATIVE_PATH INTO :v_file_name
    FROM DIRECTORY(@GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE2)
    WHERE RELATIVE_PATH LIKE :P_YEAR || ''%_expense.csv''
    ORDER BY LAST_MODIFIED DESC
    LIMIT 1;

    IF (v_file_name IS NULL) THEN
        RAISE e_file_not_found;
    END IF;

    -- 해당 연도 기존 데이터 삭제
    v_delete_sql := ''DELETE FROM GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION WHERE YEAR = '''''' || :P_YEAR || '''''''';
    EXECUTE IMMEDIATE v_delete_sql;

    -- 해당 파일 데이터 적재
    v_copy_sql := ''
        COPY INTO GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION
        FROM (
            SELECT
                '''''' || :P_YEAR || '''''',
                $1,$2,$3,$4,$5,
                $6,$7,$8,$9,$10,
                $11, $12, $13, 
                $14,
                $15 
            FROM @GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE2
            (FILE_FORMAT => ''''GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR2'''', PATTERN => ''''.*'' || v_file_name || '''''')
        ) FORCE = TRUE'';
    EXECUTE IMMEDIATE v_copy_sql;

    RETURN :P_YEAR || '': '' || v_file_name || '' 적재완료'';
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
            ''지출'',
            ''P_YEAR=''
            || NVL(:P_YEAR, ''NULL'')
            || '', FILE=''
            || NVL(:v_file_name, ''NULL'')
            || '', SQLCODE=''
            || :v_sqlcode
            || '', SQLSTATE=''
            || :v_sqlstate
            || '', SQLERRM=''
            || :v_sqlerrm
        );
        CALL SYSTEM$SEND_EMAIL(''EMAIL_ALERT_INTEGRATION'',
            ''it@gni.kr'',
            ''ERP 제작비 적재 실패'',
            ''ERROR: ''
               || ''P_YEAR=''
               || NVL(:P_YEAR, ''NULL'')
               || '', FILE=''
               || NVL(:v_file_name, ''NULL'')
               || '', SQLCODE=''
               || :v_sqlcode
               || '', SQLSTATE=''
               || :v_sqlstate
               || '', SQLERRM=''
               || :v_sqlerrm,
            ''text/html''
        );
        RETURN ''ERROR: ''
               || ''P_YEAR=''
               || NVL(:P_YEAR, ''NULL'')
               || '', FILE=''
               || NVL(:v_file_name, ''NULL'')
               || '', SQLCODE=''
               || :v_sqlcode
               || '', SQLSTATE=''
               || :v_sqlstate
               || '', SQLERRM=''
               || :v_sqlerrm;      
END;
';
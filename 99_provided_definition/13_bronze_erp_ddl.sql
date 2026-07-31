create or replace schema GN_DW.BRONZE_ERP with managed access COMMENT='원천 데이터 적재 - ERP (SMS/알림톡/마케팅 발송)';

create or replace TABLE GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER (
	YEAR VARCHAR(16777216) COMMENT '연도',
	INCOME_EXPS_DIV_NM VARCHAR(16777216) COMMENT '수지구분',
	BDGT_UNIT_NM VARCHAR(16777216) COMMENT '예산단위',
	JANG_NM VARCHAR(16777216) COMMENT '장',
	KWAN_NM VARCHAR(16777216) COMMENT '관',
	HANG_NM VARCHAR(16777216) COMMENT '항',
	MOK_NM VARCHAR(16777216) COMMENT '목',
	DTL_ITEM_NM VARCHAR(16777216) COMMENT '세목',
	SUBDTL_ITEM_NM VARCHAR(16777216) COMMENT '세세목',
	FUND_SOURCE_NM VARCHAR(16777216) COMMENT '재원',
	BDGT_ITEM_NM VARCHAR(16777216) COMMENT '예산과목',
	DVLP_INBOUND_PATH VARCHAR(16777216) COMMENT '개발인입경로',
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
)COMMENT='예산 실적 원장'
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
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_ERP.SP_LOAD_BUDGET_BY_YEAR("P_YEAR" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    v_file_name VARCHAR;
    v_delete_sql VARCHAR;
    v_copy_sql VARCHAR;
BEGIN
    -- P_YEAR YYYY 형태 검증 (4자리 숫자)
    IF (:P_YEAR IS NULL OR LENGTH(:P_YEAR) != 4 OR TRY_TO_NUMBER(:P_YEAR) IS NULL) THEN
        RETURN ''ERROR: P_YEAR는 YYYY 형태의 4자리 연도여야 합니다 (입력값: '' || NVL(:P_YEAR, ''NULL'') || '')'';
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
        RETURN :P_YEAR || ''_budget.csv 패턴에 맞는 파일을 찾을 수 없습니다'';
    END IF;

    -- 해당 연도 기존 데이터 삭제
    v_delete_sql := ''DELETE FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER WHERE YEAR = '''''' || :P_YEAR || '''''''';
    EXECUTE IMMEDIATE v_delete_sql;

    -- 해당 파일 데이터 적재
    v_copy_sql := ''
        COPY INTO GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER
        FROM (
            SELECT
                '''''' || :P_YEAR || '''''',$1,$2,$3,$4,
                $5,$6,$7,$8,$9,
                $10,$11,
                TRY_TO_NUMBER(REPLACE(REPLACE($12, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($13, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($14, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($15, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($16, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($17, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($18, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($19, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($20, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($21, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($22, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($23, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($24, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($25, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($26, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($27, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($28, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($29, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($30, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($31, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($32, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($33, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($34, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($35, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($36, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($37, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($38, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($39, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($40, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($41, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($42, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($43, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($44, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($45, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($46, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($47, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($48, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($49, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($50, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($51, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($52, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($53, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($54, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($55, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($56, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($57, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($58, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($59, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($60, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($61, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($62, ''''('''', ''''-''''), '''')'''', '''''''')),
                TRY_TO_NUMBER(REPLACE(REPLACE($63, ''''('''', ''''-''''), '''')'''', ''''''''))
            FROM @GN_DW.BRONZE_ERP.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''''GN_DW.BRONZE_ERP.GN_CSV_FORMAT_EUCKR'''', PATTERN => ''''.*'' || v_file_name || '''''')
        ) FORCE = TRUE'';
    EXECUTE IMMEDIATE v_copy_sql;

    RETURN :P_YEAR || '': '' || v_file_name || '' 적재완료'';
END;
';
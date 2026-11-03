-- 기획실 연사업목표 인입 작업
-- 연간목표 인입시, 동일 행수의 실적 행 인입
-- 연초 연간목표 확정 데이터 인입 필요. 
-- GN_DW.SILVER.CSV_UPLOAD_STAGE 스테이지 해당연도_annual_dvlp_goal.csv 파일명으로 CSV 파일 업로드.
-- csv 파일명은 YYYY_annual_dvlp_goal.csv 로 업로드 되어야 함. 
-- csv 파일 인코딩은 UTF-8
-- csv 파일 기준은 2026_annual_dvlp_goal.csv 참고
-- 연도(YEAR)를 기준으로 연간 개발 목표 CSV 파일을 조회하고, 기존 해당 연도 데이터를 삭제 후 목표 및 실적 구분 데이터를 적재하여 연간 개발 목표·실적 집계 데이터를 갱신한다.
-- CSV 파일은 UTF-8 인코딩 및 첫 번째 행을 헤더로 제외하는 파일 포맷을 사용한다.
-- 대상 파일은 YYYY_annual_dvlp_goal.csv 형식으로 조회하며, 해당 연도의 파일이 없으면 적재를 종료한다.
-- 적재 대상 연도의 기존 데이터를 삭제한 후, CSV 파일의 데이터를 목표와 실적으로 구분하여 각각 적재한다.
-- 목표 데이터는 부서 구분, 신규·기존 구분, 후원사업 그룹 및 1~12월 월별 목표값을 적재한다.
-- 월별 목표값은 NUMBER(38,13) 형식으로 변환하며, CSV 내 쉼표를 제거한 후 숫자형으로 처리한다.
-- 실적 데이터는 동일한 구분 정보를 기준으로 적재하되, 현재 적재 로직에서는 월별 실적값을 NULL로 설정한다.
-- 최종 데이터는 ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA 테이블에서 연도·목표실적구분·부서·신규기존·후원사업 그룹별로 관리한다.



CREATE OR REPLACE FILE FORMAT GN_DW.SILVER.GN_CSV_FORMAT_UTF8
    TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE TABLE GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA (
	YEAR VARCHAR(16777216) COMMENT '연도',
	DATA_TYPE_NM VARCHAR(16777216) COMMENT '목표 실적 구분 명',
	DEPT_DIV_NM VARCHAR(16777216) COMMENT '부서 구분 명',
	NEW_EXST_DIV_NM VARCHAR(16777216) COMMENT '신규기존구분명',
	SPNSR_BSNS_GRP_NM VARCHAR(16777216) COMMENT '후원 사업 그룹 명',
	M01 NUMBER(38,13) COMMENT '1월 건수',
	M02 NUMBER(38,13) COMMENT '2월 건수',
	M03 NUMBER(38,13) COMMENT '3월 건수',
	M04 NUMBER(38,13) COMMENT '4월 건수',
	M05 NUMBER(38,13) COMMENT '5월 건수',
	M06 NUMBER(38,13) COMMENT '6월 건수',
	M07 NUMBER(38,13) COMMENT '7월 건수',
	M08 NUMBER(38,13) COMMENT '8월 건수',
	M09 NUMBER(38,13) COMMENT '9월 건수',
	M10 NUMBER(38,13) COMMENT '10월 건수',
	M11 NUMBER(38,13) COMMENT '11월 건수',
	M12 NUMBER(38,13) COMMENT '12월 건수'
)COMMENT='기획실 연간 개발 목표 실적 집계 데이터'
;

--연초 목표치 인입 + 실적치 데이터 
--파일명 및 아래 변수 맞추어서 작업. 
--파일기준으로 목표 값 인입 / 동일한 행으로 실적 값 인입. 실적행은 월마감이후 실행 프로시저에서 UPDATE
SET YEAR = '2026';
SET FILE_NAME = $YEAR || '_' || 'annual_dvlp_goal.csv';
SELECT $YEAR, $FILE_NAME;
DECLARE
    v_file_name VARCHAR;
    v_delete_sql VARCHAR;
    v_copy_sql VARCHAR;
BEGIN
    -- 디렉터리 메타데이터 갱신
    ALTER STAGE GN_DW.SILVER.CSV_UPLOAD_STAGE REFRESH;

    -- 대상 파일 조회
    SELECT RELATIVE_PATH
      INTO :v_file_name
    FROM DIRECTORY(@GN_DW.SILVER.CSV_UPLOAD_STAGE)
    WHERE RELATIVE_PATH = $FILE_NAME;

    -- 파일이 없으면 종료
    IF (v_file_name IS NULL) THEN
        RETURN $FILE_NAME || ' 파일이 존재하지 않아 종료합니다.';
    END IF;

    -- 해당 기준연월 기존 데이터 삭제
    v_delete_sql := 'DELETE FROM GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA WHERE YEAR = ''' || $YEAR || '''';
    EXECUTE IMMEDIATE v_delete_sql;
    -- 해당 파일 데이터 적재
    v_copy_sql := '
        COPY INTO GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA
        FROM (
            SELECT
                ''' || $YEAR || ''', ''목표'',
                $1,$2,$3,
                TRY_TO_NUMBER(REPLACE($4, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($5, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($6, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($7, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($8, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($9, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($10, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($11, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($12, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($13, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($14, '','', ''''), 38, 13),
                TRY_TO_NUMBER(REPLACE($15, '','', ''''), 38, 13)
            FROM @GN_DW.SILVER.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''GN_DW.SILVER.GN_CSV_FORMAT_UTF8'', PATTERN => ''^' || v_file_name || '$'')
            
        ) FORCE = TRUE';
    EXECUTE IMMEDIATE v_copy_sql;
    v_copy_sql := '
        COPY INTO GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA
        FROM (
            SELECT
                ''' || $YEAR || ''', ''실적'',
                $1,$2,$3,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL
            FROM @GN_DW.SILVER.CSV_UPLOAD_STAGE
            (FILE_FORMAT => ''GN_DW.SILVER.GN_CSV_FORMAT_UTF8'', PATTERN => ''^' || v_file_name || '$'')
        ) FORCE = TRUE';
    EXECUTE IMMEDIATE v_copy_sql;
    RETURN '전체 CSV 파일 적재완료';
END;


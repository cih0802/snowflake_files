-- BigQuery 원천 데이터를 Snowflake에 적재하는 프로시저
-- BigQuery의 이벤트 데이터를 조회·수집하고, 원천 테이블 구조를 유지하여 BRONZE_BIGQUERY 영역에 일자별 테이블로 적재한다.
-- Google 서비스 계정 인증을 통해 BigQuery 및 BigQuery Storage API에 접근하고, BigQuery 클라이언트를 생성한다.
-- 입력 일자(YYYYMMDD)를 기준으로 대상 ** 이벤트 테이블 events_YYYYMMDD**를 지정하며, 입력값이 없으면 실행 전일을 기준일자로 사용한다.
-- 입력 일자의 날짜 형식 및 실제 날짜 여부를 검증하여 잘못된 날짜 입력을 사전에 차단한다.
-- BigQuery Storage API를 활용하여 대상 이벤트 테이블의 전체 데이터를 DataFrame으로 조회한다.
-- BigQuery 원천 테이블명인 events_YYYYMMDD를 그대로 사용하여 GN_DW.BRONZE_BIGQUERY에 일자별 원천 테이블 형태로 적재하며, 기존 동일 테이블이 존재할 경우 덮어쓴다.
-- GOOGLE_BQ_NETWORK_RULE 및 GOOGLE_BQ_ACCESS_INTEGRATION을 통해 BigQuery 및 Google 인증 관련 API에 대한 외부 접근을 허용한다.
-- 프로시저 실행 시 GN_DW_ETL_WH 웨어하우스를 사용하고, SP_LOAD_BIGQUERY를 QUERY_TAG로 설정하여 작업을 식별할 수 있도록 한다.
-- 데이터 조회 및 적재 중 오류가 발생하면 SYNC_ERR_INFO에 발생일시, 데이터 유형, 오류정보를 기록하고 처리 결과를 반환한다.

------------------------------------------------------------
-- 1. 스키마 생성
------------------------------------------------------------
CREATE SCHEMA GN_DW.BRONZE_BIGQUERY;

------------------------------------------------------------
-- 2 내부 스테이지 생성 및 json 파일 업로드
-- gn_google_bq_service_account.json은 박종찬 팀장에게 전달받은 정보임. 
------------------------------------------------------------
CREATE OR REPLACE STAGE GN_DW.BRONZE_BIGQUERY.CREDENTIALS_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

------------------------------------------------------------
-- 3 Network Rule 생성
------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE GN_DW.BRONZE_BIGQUERY.GOOGLE_BQ_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'bigquerystorage.googleapis.com',
        'bigquery.googleapis.com',
        'oauth2.googleapis.com',
        'www.googleapis.com'
    );

------------------------------------------------------------
-- 4. External Access Integration 생성
------------------------------------------------------------
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GOOGLE_BQ_ACCESS_INTEGRATION
    ALLOWED_NETWORK_RULES = (GN_DW.BRONZE_BIGQUERY.GOOGLE_BQ_NETWORK_RULE)
    ENABLED = TRUE;    

------------------------------------------------------------
-- 5 원천 데이터 저장 테이블 생성
------------------------------------------------------------
-- 원천 데이터의 경우 인입시 자동 생성. 
-- GN_DW.BRONZE_BIGQUERY."events_YYYYMMDD" 테이블에 저장



------------------------------------------------------------
-- 6. 프로시져 중 익셉션 발생시 아래 에러 테이블에 데이터 인입
------------------------------------------------------------
CREATE OR REPLACE SEQUENCE GN_DW.BRONZE_BIGQUERY.SEQ_SYNC_ERR_INFO
    START = 1
    INCREMENT = 1
    ORDER;
CREATE OR REPLACE TABLE GN_DW.BRONZE_BIGQUERY.SYNC_ERR_INFO (
    ERR_SEQ      NUMBER DEFAULT GN_DW.BRONZE_BIGQUERY.SEQ_SYNC_ERR_INFO.NEXTVAL,
    ERR_INFO     VARCHAR,
    ERR_DATETIME DATETIME
);


------------------------------------------------------------
-- 7. [프로시저 본체] BigQuery 원천 데이터 -> Snowflake 적재(원천 형태 유지)
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_BIGQUERY.SP_LOAD_BIGQUERY(INPUT_YYYYMMDD VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'google-cloud-bigquery', 'google-cloud-bigquery-storage', 'google-auth', 'db-dtypes')
IMPORTS = ('@GN_DW.BRONZE_BIGQUERY.CREDENTIALS_STAGE/gn_google_bq_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_BQ_ACCESS_INTEGRATION)
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
import json
import pandas
import os
import sys
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.cloud import bigquery_storage
from google.oauth2 import service_account

def main(session, input_yyyymmdd=None):
    logs = []
    project_id = 'snowflakegdconnector'

    try:
        session.sql("ALTER SESSION SET QUERY_TAG = 'SP_LOAD_BIGQUERY'").collect()
        session.sql("USE WAREHOUSE GN_DW_ETL_WH").collect()
        # input_yyyymmdd가 None인 경우 처리
        if input_yyyymmdd is None:
            yesterday = datetime.now() - timedelta(days=1)
            input_yyyymmdd = yesterday.strftime("%Y%m%d")
            logs.append(f"[안내] 시작일이 None이므로 실행 전날 날짜({input_yyyymmdd})로 대체합니다.")

        # 시작일의 날짜 형식 유효성 검사
        if len(str(input_yyyymmdd)) != 8:
            raise Exception(f"[오류] 날짜의 길이가 올바르지 않습니다. (입력값: {input_yyyymmdd})")
        try:
            current_date = datetime.strptime(str(input_yyyymmdd), "%Y%m%d")
        except ValueError:
            raise Exception(f"[오류] 잘못된 날짜 형식입니다. 실제 날짜로 변경 가능한지 확인하세요. 입력값: ({input_yyyymmdd})")

        # 서비스 계정 인증 및 BigQuery 클라이언트 생성 (IMPORTS 파일 사용)
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, 'gn_google_bq_service_account.json')
        with open(sa_file_path, 'r') as f:
            sa_info = json.load(f)
        credentials = service_account.Credentials.from_service_account_info(sa_info)

        bq_client = bigquery.Client(project=project_id, credentials=credentials)
        bqstorage_client = bigquery_storage.BigQueryReadClient(credentials=credentials)
        logs.append("빅쿼리 인증 성공 및 클라이언트 생성 완료!")

        # 대상 테이블 지정
        BQ_PROJECT_ID = "snowflakegdconnector"
        # BQ_DATASET_ID = "todayreport_goodneighbors_ga4"
        BQ_DATASET_ID = "analytics_547487290"
        BQ_TABLE_ID = f"events_{current_date.strftime('%Y%m%d')}"

        table_ref = f"{BQ_PROJECT_ID}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"
        start_time = datetime.now()
        logs.append(f"{table_ref} 인입 시작 시간 : {start_time}")

        # Storage API를 사용하여 데이터프레임으로 변환
        df = bq_client.list_rows(table_ref).to_dataframe(bqstorage_client=bqstorage_client)

        # 6. Snowflake 적재
        session.write_pandas(
            df=df,
            database="GN_DW",
            schema="BRONZE_BIGQUERY",
            table_name=BQ_TABLE_ID,
            auto_create_table=True,
            overwrite=True
        )
        end_time = datetime.now()
        logs.append(f"{table_ref} 인입 종료 시간 : {end_time}")
        
    except Exception as global_err:
        error_msg = str(global_err)

        try:
            session.sql(
                """
                INSERT INTO GN_DW.BRONZE_BIGQUERY.SYNC_ERR_INFO
                    (ERR_DATETIME, ERR_INFO)
                VALUES (CURRENT_TIMESTAMP(), ?)
                """,
                params=[error_msg]
            ).collect()

        except Exception as log_err:
            return (
                f"ERROR: {error_msg}\n"
                f"LOG INSERT ERROR: {str(log_err)}"
            )

        return f"ERROR: {error_msg}\n[안내] 오류 로그 기록 완료"
    
    logs.append("[완료] 데이터 적재가 정상적으로 완료되었습니다.")
    if not logs:
        return "결과가 없음"
    return "\n".join(logs)
$$;



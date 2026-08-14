create or replace schema GN_DW.BRONZE_BIGQUERY with managed access COMMENT='원천 데이터 적재 - GA4 (웹/앱 방문, Google 광고)';

create or replace sequence GN_DW.BRONZE_BIGQUERY.SEQ_SYNC_ERR_INFO start with 1 increment by 1 noorder;
create or replace TABLE GN_DW.BRONZE_BIGQUERY.SYNC_ERR_INFO (
	ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_BIGQUERY.SEQ_SYNC_ERR_INFO.NEXTVAL,
	ERR_DATETIME TIMESTAMP_NTZ(9),
	DATA_TYPE VARCHAR(16777216),
	ERR_INFO VARCHAR(16777216)
);
create or replace TABLE GN_DW.BRONZE_BIGQUERY."events_20260501" (
	"event_date" VARCHAR(16777216),
	"event_timestamp" NUMBER(38,0),
	"event_name" VARCHAR(16777216),
	"event_params" VARIANT,
	"event_previous_timestamp" NUMBER(38,0),
	"event_value_in_usd" FLOAT,
	"event_bundle_sequence_id" NUMBER(38,0),
	"event_server_timestamp_offset" NUMBER(38,0),
	"user_id" VARCHAR(16777216),
	"user_pseudo_id" VARCHAR(16777216),
	"privacy_info" VARIANT,
	"user_properties" VARIANT,
	"user_first_touch_timestamp" NUMBER(38,0),
	"user_ltv" VARIANT,
	"device" VARIANT,
	"geo" VARIANT,
	"app_info" NUMBER(38,0),
	"traffic_source" VARIANT,
	"stream_id" VARCHAR(16777216),
	"platform" VARCHAR(16777216),
	"event_dimensions" NUMBER(38,0),
	"ecommerce" VARIANT,
	"items" VARIANT,
	"collected_traffic_source" VARIANT,
	"is_active_user" BOOLEAN,
	"batch_event_index" NUMBER(38,0),
	"batch_page_id" NUMBER(38,0),
	"batch_ordering_id" NUMBER(38,0),
	"session_traffic_source_last_click" VARIANT,
	"publisher" NUMBER(38,0)
);
create or replace TABLE GN_DW.BRONZE_BIGQUERY."events_20260719" (
	"event_date" VARCHAR(16777216),
	"event_timestamp" NUMBER(38,0),
	"event_name" VARCHAR(16777216),
	"event_params" VARIANT,
	"event_previous_timestamp" NUMBER(38,0),
	"event_value_in_usd" FLOAT,
	"event_bundle_sequence_id" NUMBER(38,0),
	"event_server_timestamp_offset" NUMBER(38,0),
	"user_id" VARCHAR(16777216),
	"user_pseudo_id" VARCHAR(16777216),
	"privacy_info" VARIANT,
	"user_properties" VARIANT,
	"user_first_touch_timestamp" NUMBER(38,0),
	"user_ltv" VARIANT,
	"device" VARIANT,
	"geo" VARIANT,
	"app_info" NUMBER(38,0),
	"traffic_source" VARIANT,
	"stream_id" VARCHAR(16777216),
	"platform" VARCHAR(16777216),
	"event_dimensions" NUMBER(38,0),
	"ecommerce" VARIANT,
	"items" VARIANT,
	"collected_traffic_source" VARIANT,
	"is_active_user" BOOLEAN,
	"batch_event_index" NUMBER(38,0),
	"batch_page_id" NUMBER(38,0),
	"batch_ordering_id" NUMBER(38,0),
	"session_traffic_source_last_click" VARIANT,
	"publisher" NUMBER(38,0),
	"event_original_occurrence_timestamp" NUMBER(38,0)
);
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_BIGQUERY.SP_LOAD_BIGQUERY("INPUT_YYYYMMDD" VARCHAR DEFAULT null)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python','pandas','google-cloud-bigquery','google-cloud-bigquery-storage','google-auth','db-dtypes')
HANDLER = 'main'
IMPORTS = ('@GN_DW.BRONZE_BIGQUERY.CREDENTIALS_STAGE/gn_google_bq_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_BQ_ACCESS_INTEGRATION)
EXECUTE AS CALLER
AS '
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
    project_id = ''snowflakegdconnector''

    try:
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
        sa_file_path = os.path.join(import_dir, ''gn_google_bq_service_account.json'')
        with open(sa_file_path, ''r'') as f:
            sa_info = json.load(f)
        credentials = service_account.Credentials.from_service_account_info(sa_info)

        bq_client = bigquery.Client(project=project_id, credentials=credentials)
        bqstorage_client = bigquery_storage.BigQueryReadClient(credentials=credentials)
        logs.append("빅쿼리 인증 성공 및 클라이언트 생성 완료!")

        # 대상 테이블 지정
        BQ_PROJECT_ID = "snowflakegdconnector"
        BQ_DATASET_ID = "todayreport_goodneighbors_ga4"
        BQ_TABLE_ID = f"events_{current_date.strftime(''%Y%m%d'')}"

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
        try:
            error_msg = str(global_err).replace("''", "''''")
            error_query = f"INSERT INTO GN_DW.BRONZE_BIGQUERY.SYNC_ERR_INFO VALUES (CURRENT_TIMESTAMP(), ''{error_msg}'')"
            session.sql(error_query).collect()
        except:
            pass
        return f"ERROR: {str(global_err)}"

    logs.append("[완료] 데이터 적재가 정상적으로 완료되었습니다.")
    if not logs:
        return "결과가 없음"
    return "\\n".join(logs)
';
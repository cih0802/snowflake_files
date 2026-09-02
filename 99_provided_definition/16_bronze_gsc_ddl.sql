create or replace schema GN_DW.BRONZE_GSC;

create or replace sequence GN_DW.BRONZE_GSC.SEQ_SYNC_ERR_INFO start with 1 increment by 1 noorder;
create or replace TABLE GN_DW.BRONZE_GSC.SEARCH_CONSOLE_DATA (
	DATE DATE COMMENT '검색 발생 날짜',
	QUERY VARCHAR(16777216) COMMENT '사용자 검색 쿼리(키워드)',
	PAGE VARCHAR(16777216) COMMENT '검색 결과에 노출된 페이지 URL',
	COUNTRY VARCHAR(16777216) COMMENT '검색이 발생한 국가 코드',
	DEVICE VARCHAR(16777216) COMMENT '검색에 사용된 디바이스 유형',
	CLICKS NUMBER(38,0) COMMENT '검색 결과 클릭 수',
	IMPRESSIONS NUMBER(38,0) COMMENT '검색 결과 노출 수',
	CTR FLOAT COMMENT '클릭률',
	POSITION FLOAT COMMENT '평균 검색결과 위치',
	RESPONSE_AGGREGATION_TYPE VARCHAR(16777216) COMMENT '응답 집계 유형'
)COMMENT='구글 서치 콘솔 검색 데이터'
;
create or replace TABLE GN_DW.BRONZE_GSC.SYNC_ERR_INFO (
	ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_GSC.SEQ_SYNC_ERR_INFO.NEXTVAL,
	ERR_DATETIME TIMESTAMP_NTZ(9),
	ERR_INFO VARCHAR(16777216)
);
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_GSC.SP_LOAD_GOOGLE_SEARCH()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python','pandas','requests','pyjwt','cryptography')
HANDLER = 'main'
IMPORTS = ('@GN_DW.BRONZE_GSC.CREDENTIALS_STAGE/gn_google_searchConsole_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_GSC_ACCESS)
EXECUTE AS CALLER
AS '
import io
import json
import os
import sys
import time
import requests
import pandas
import datetime as dt
from datetime import datetime, timedelta
import jwt
from cryptography.hazmat.primitives import serialization
from urllib.parse import quote

def get_access_token(sa_info):
    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": "https://www.googleapis.com/auth/webmasters.readonly",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600
    }
    private_key = serialization.load_pem_private_key(
        sa_info["private_key"].encode(), password=None
    )
    encoded_jwt = jwt.encode(payload, private_key, algorithm="RS256")

    resp = requests.post(
        "https://oauth2.googleapis.com/token", data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": encoded_jwt
        },
        timeout=60
    )
    resp.raise_for_status()
    return resp.json()["access_token"]

def main(session):
    try:
        table_name = ''SEARCH_CONSOLE_DATA''
        logs = []
        # 1. 둘 다 입력되지 않은 경우 → 기본값 사용
        start_date = (datetime.now() - timedelta(days=7)).strftime(''%Y-%m-%d'')
        end_date = (datetime.now() - timedelta(days=1)).strftime(''%Y-%m-%d'')
  

        logs.append(f"[작업 기준일자] {start_date} ~ {end_date} 데이터 수집 프로세스를 시작합니다.")
        
        current_dir = os.path.dirname(os.path.abspath(__file__)) if ''__file__'' in globals() else os.getcwd()
        import_dir = sys._xoptions.get("snowflake_import_directory", current_dir)
        sa_file_path = os.path.join(import_dir, "gn_google_searchConsole_service_account.json")
        with open(sa_file_path, ''r'') as f:
            sa_info = json.load(f)
        token = get_access_token(sa_info)

        # REST API Endpoint 및 Header 설정
        encoded_site_url = quote(''sc-domain:goodneighbors.kr'', safe="")
        url = (
            "https://www.googleapis.com/webmasters/v3/sites/"
            f"{encoded_site_url}/searchAnalytics/query"
        )

        # 요청 설정
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        dimensions = [
            "date",
            "query",
            "page",
            "country",
            "device",
        ]
        payload = {
            "startDate": f"{start_date}",
            "endDate": f"{end_date}",
            "dimensions": dimensions,
            "type": "web",
            "rowLimit": 25000,
            "startRow": 0
        }
        response = requests.post(
            url,
            headers=headers,
            json=payload,
            timeout=60
        )

        if response.status_code != 200:
            print("API ERROR")
            raise Exception(f"{response.status_code} / {response.text} / Search Console API 호출 실패")

        data = response.json()
        result = []
        for row in data.get("rows", []):
            record = {}
            # Dimension
            keys = row.get("keys", [])
            for i, dimension in enumerate(dimensions):
                record[dimension.upper()] = (
                    keys[i] if i < len(keys) else None
                )
            # Metric
            record["CLICKS"] = row.get("clicks", 0)
            record["IMPRESSIONS"] = row.get("impressions", 0)
            record["CTR"] = row.get("ctr", 0)
            record["POSITION"] = row.get("position", 0)
            # API 응답 정보
            record["RESPONSE_AGGREGATION_TYPE"] = data.get(
                "responseAggregationType"
            )

            result.append(record)

        df = pandas.DataFrame(result)

        if df.empty:
            print("조회된 데이터가 없어 Snowflake 적재를 건너뜁니다.")
        else:
            # 기존 데이터 삭제
            delete_query = f"DELETE FROM GN_DW.BRONZE_GSC.{table_name} WHERE DATE BETWEEN ''{start_date}'' AND ''{end_date}''"
            delete_result = session.sql(delete_query).collect()
            deleted_cnt = delete_result[0][0] if delete_result else 0
            logs.append(f"기존 {start_date} ~ {end_date} 데이터 삭제 완료 ({deleted_cnt} 건 처리)")
            
            # 7. Snowflake 적재
            session.write_pandas(
                df=df,
                database="GN_DW",
                schema="BRONZE_GSC",
                table_name=f"{table_name}",
            )
        logs.append(f"  [성공] [{table_name}] 테이블에 적재 완료! {len(df)} 행 인입!")
    except Exception as global_err:
        error_msg = str(global_err).replace("''", "''''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_GSC.SYNC_ERR_INFO (ERR_DATETIME, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), ''{error_msg}'')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\\n".join(logs)
';
create or replace task GN_DW.BRONZE_GSC.TASK_GOOGLE_SEARCH
	warehouse=GN_DW_ETL_WH
	schedule='USING CRON 30 1 * * * Asia/Seoul'
	as BEGIN
    CALL GN_DW.BRONZE_GSC.SP_LOAD_GOOGLE_SEARCH();
END;
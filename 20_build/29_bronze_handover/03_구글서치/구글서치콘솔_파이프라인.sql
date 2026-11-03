-- 구글 서치 데이터를 Snowflake에 적재하는 프로시저
-- Google Search Console API를 통해 검색어·페이지·국가·디바이스별 검색 데이터를 조회·수집하고, 검색 성과 지표를 SEARCH_CONSOLE_DATA에 적재한다.
-- Google 서비스 계정 인증을 통해 Google Search Console API에 접근하고 JWT 방식으로 인증 토큰을 발급받는다.
-- 검색 발생 일자, 검색어, 노출 페이지, 국가, 디바이스를 기준으로 검색 데이터를 조회하고, 클릭수, 노출수, CTR, 평균 검색결과 위치 등의 검색 성과 지표를 수집한다.
-- 데이터 변경 가능성을 고려하여 실행일 기준 7일 전부터 1일 전까지의 데이터를 조회 대상으로 설정한다.
-- 적재 대상 기간의 기존 SEARCH_CONSOLE_DATA 데이터를 삭제한 후 API 조회 결과를 재적재하여 최근 데이터 변경 및 중복 적재를 방지한다.
-- API 응답의 검색 차원 및 성과 지표를 DataFrame으로 변환하고, RESPONSE_AGGREGATION_TYPE 등 API 응답 정보를 함께 저장한다.
-- GOOGLE_SC_NETWORK_RULE 및 GOOGLE_GSC_ACCESS를 통해 www.googleapis.com, oauth2.googleapis.com 외부 API 접근을 허용한다.
-- API 조회 또는 적재 중 오류가 발생하면 SYNC_ERR_INFO에 발생일시와 오류정보를 기록하고 처리 결과를 반환한다.

------------------------------------------------------------
-- 1. 스키마 생성
------------------------------------------------------------
CREATE SCHEMA GN_DW.BRONZE_GSC;

------------------------------------------------------------
-- 2 내부 스테이지 생성 및 json 파일 업로드
-- gn_google_searchConsole_service_account.json은 박종찬 팀장에게 전달받은 정보임. 
------------------------------------------------------------
CREATE STAGE GN_DW.BRONZE_GSC.CREDENTIALS_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
    
------------------------------------------------------------
-- 3 Network Rule 생성
------------------------------------------------------------
CREATE NETWORK RULE GN_DW.BRONZE_GSC.GOOGLE_SC_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'www.googleapis.com',
        'oauth2.googleapis.com'
    );

------------------------------------------------------------
-- 4. External Access Integration 생성
------------------------------------------------------------
CREATE EXTERNAL ACCESS INTEGRATION GOOGLE_GSC_ACCESS
    ALLOWED_NETWORK_RULES = (GN_DW.BRONZE_GSC.GOOGLE_SC_NETWORK_RULE)
    ENABLED = TRUE;    

------------------------------------------------------------
-- 5. 결과저장 테이블 생성
------------------------------------------------------------
CREATE TABLE GN_DW.BRONZE_GSC.SEARCH_CONSOLE_DATA (
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
) COMMENT='재송출 광고 성과 내역';


------------------------------------------------------------
-- 6. 프로시져 중 익셉션 발생시 아래 에러 테이블에 데이터 인입
------------------------------------------------------------
CREATE OR REPLACE SEQUENCE GN_DW.BRONZE_GSC.SEQ_SYNC_ERR_INFO START = 1 INCREMENT = 1 ORDER;
CREATE OR REPLACE TABLE GN_DW.BRONZE_GSC.SYNC_ERR_INFO (
    ERR_SEQ      NUMBER DEFAULT GN_DW.BRONZE_GSC.SEQ_SYNC_ERR_INFO.NEXTVAL,
    ERR_DATETIME DATETIME,
    ERR_INFO     VARCHAR
);



------------------------------------------------------------
-- [프로시저 본체] 구글 서치 -> Snowflake 적재
------------------------------------------------------------
-- 프로시져 언제 구동되게 할 지 task화 필요. 현업에게 물어봐야함. 
-- 실행시점 이전 8일부터 실행시점 이전일까지 데이터 삭제후 재인입. 
--72시간이내 데이터 수정될 수 있기 때문. 또한 당일, 이전일은 데이터 없을 수도 있는데, 데이터 반영이 시간소요되는 듯?
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_GSC.SP_LOAD_GOOGLE_SEARCH()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'requests', 'pyjwt', 'cryptography')
IMPORTS = ('@GN_DW.BRONZE_GSC.CREDENTIALS_STAGE/gn_google_searchConsole_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_GSC_ACCESS)
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
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
        table_name = 'SEARCH_CONSOLE_DATA'
        logs = []
        # 1. 둘 다 입력되지 않은 경우 → 기본값 사용
        start_date = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        end_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        logs.append(f"[작업 기준일자] {start_date} ~ {end_date} 데이터 수집 프로세스를 시작합니다.")
        
        current_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
        import_dir = sys._xoptions.get("snowflake_import_directory", current_dir)
        sa_file_path = os.path.join(import_dir, "gn_google_searchConsole_service_account.json")
        with open(sa_file_path, 'r') as f:
            sa_info = json.load(f)
        token = get_access_token(sa_info)

        # REST API Endpoint 및 Header 설정
        encoded_site_url = quote('sc-domain:goodneighbors.kr', safe="")
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
            delete_query = f"DELETE FROM GN_DW.BRONZE_GSC.{table_name} WHERE DATE BETWEEN '{start_date}' AND '{end_date}'"
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
        error_msg = str(global_err).replace("'", "''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_GSC.SYNC_ERR_INFO (ERR_DATETIME, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), '{error_msg}')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\n".join(logs)
$$;




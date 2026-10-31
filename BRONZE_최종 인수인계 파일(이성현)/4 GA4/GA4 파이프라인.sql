-- GA 데이터를 Snowflake에 적재하는 프로시저
-- GA4 API를 통해 사용자 인구통계 데이터를 조회·수집하고, 일자·기기·성별·연령별 데이터를 GA4_USER_DEMOGRAPHIC에 적재한다.
-- Google 서비스 계정 인증을 통해 GA4 Analytics Data API에 접근하고, JWT 방식으로 인증 토큰을 발급받는다.
-- GA4 Property의 일자, 기기 카테고리, 성별, 연령을 기준으로 신규 사용자 수, 세션수, 총 사용자 데이터를 조회한다.
-- 데이터 변경 가능성을 고려하여 전전일~전일(최근 5일 전부터 1일 전까지) 범위의 데이터를 GA4 API에서 조회한다.
-- 적재 대상 기간의 기존 GA4_USER_DEMOGRAPHIC 데이터를 삭제한 후 API 조회 결과를 재적재하여 중복 및 변경 데이터 발생을 방지한다.
-- API 응답 데이터를 DataFrame으로 변환하고, GA4의 컬럼명을 Snowflake 표준 영문 컬럼명 형식으로 변환하여 적재한다.
-- GA4 API의 조회 결과가 100,000건을 초과할 수 있도록 페이지 단위 조회 및 반복 적재를 수행한다.
-- GOOGLE_GA4_NETWORK_RULE 및 GOOGLE_GA4_ACCESS를 통해 analyticsdata.googleapis.com, oauth2.googleapis.com 외부 API 접근을 허용한다.
-- API 조회 및 적재 중 오류가 발생하면 SYNC_ERR_INFO에 발생일시와 오류정보를 기록하고 처리 결과를 반환한다.

------------------------------------------------------------
-- 1. 스키마 생성
------------------------------------------------------------
CREATE SCHEMA GN_DW.BRONZE_GA4;
------------------------------------------------------------
-- 2 내부 스테이지 생성 및 json 파일 업로드
-- gn_google_ga4_service_account.json은 박종찬 팀장에게 전달받은 정보임. 
------------------------------------------------------------
-- gn_google_service_account
CREATE STAGE GN_DW.BRONZE_GA4.CREDENTIALS_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

------------------------------------------------------------
-- 3 Network Rule 생성
------------------------------------------------------------
CREATE NETWORK RULE GN_DW.BRONZE_GA4.GOOGLE_GA4_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'analyticsdata.googleapis.com',
        'oauth2.googleapis.com'
    );

------------------------------------------------------------
-- 4. External Access Integration 생성
------------------------------------------------------------
CREATE EXTERNAL ACCESS INTEGRATION GOOGLE_GA4_ACCESS
    ALLOWED_NETWORK_RULES = (GN_DW.BRONZE_GA4.GOOGLE_GA4_NETWORK_RULE)
    ENABLED = TRUE;    

------------------------------------------------------------
-- 5. 결과저장 테이블 생성
------------------------------------------------------------
create TABLE GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC (
	DATE VARCHAR(16777216) COMMENT '일자',
	DEVICE_CATEGORY VARCHAR(16777216) COMMENT '기기 카테고리',
	USER_GENDER VARCHAR(16777216) COMMENT '성별',
	USER_AGE_BRACKET VARCHAR(16777216) COMMENT '연령',
	NEW_USERS VARCHAR(16777216) COMMENT '새 사용자 수',
	SESSIONS VARCHAR(16777216) COMMENT '세션수',
	TOTAL_USERS VARCHAR(16777216) COMMENT '총 사용자'
)COMMENT='GA4 사용자 인구통계별 일자 집계 데이터';

SELECT DATE
FROM  GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC
GROUP BY DATE
ORDER BY DATE
------------------------------------------------------------
-- 6. 프로시져 중 익셉션 발생시 아래 에러 테이블에 데이터 인입
------------------------------------------------------------
CREATE SEQUENCE GN_DW.BRONZE_GA4.SEQ_SYNC_ERR_INFO START = 1 INCREMENT = 1;
CREATE TABLE GN_DW.BRONZE_GA4.SYNC_ERR_INFO (
    ERR_SEQ      NUMBER DEFAULT GN_DW.BRONZE_GA4.SEQ_SYNC_ERR_INFO.NEXTVAL,
    ERR_DATETIME DATETIME,
    ERR_INFO     VARCHAR
);

------------------------------------------------------------
-- [실행 예시]
------------------------------------------------------------
-- 기본값 (아전일 기준) 실행
CALL GN_DW.BRONZE_GA4.SP_LOAD_GA_USER_DEMOGRAPHIC();

------------------------------------------------------------
-- [프로시저 본체] 구글 서치 -> Snowflake 적재
------------------------------------------------------------
-- 프로시져 언제 구동되게 할 지 task화 필요. 현업에게 물어봐야함. 
-- 연결정보 대행사 것과 동일히 사용
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_GA4.SP_LOAD_GA_USER_DEMOGRAPHIC()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'requests', 'pyjwt', 'cryptography')
IMPORTS = ('@GN_DW.BRONZE_GA4.CREDENTIALS_STAGE/gn_google_ga4_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_GA4_ACCESS)
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
import re
from cryptography.hazmat.primitives import serialization

def get_access_token(sa_info):
    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": "https://www.googleapis.com/auth/analytics.readonly",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600
    }
    private_key = serialization.load_pem_private_key(
        sa_info["private_key"].encode(), password=None
    )
    encoded_jwt = jwt.encode(payload, private_key, algorithm="RS256")
    resp = requests.post("https://oauth2.googleapis.com/token", data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": encoded_jwt
    })
    resp.raise_for_status()
    return resp.json()["access_token"]

def to_snake_upper(name):
    name = name.split(":")[-1]
    name = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name)
    name = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', name)
    return name.upper()

def main(session):
    try:
        logs = []
        # GA property ID 
        PROPERTY_ID = "344866426"
        table_name = 'GA4_USER_DEMOGRAPHIC'
        
        
        current_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
        import_dir = sys._xoptions.get("snowflake_import_directory", current_dir)
        sa_file_path = os.path.join(import_dir, "gn_google_ga4_service_account.json")
        with open(sa_file_path, 'r') as f:
            sa_info = json.load(f)
        token = get_access_token(sa_info)

        url = f"https://analyticsdata.googleapis.com/v1beta/properties/{PROPERTY_ID}:runReport"
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        start_date = (datetime.now() - timedelta(days=5)).strftime('%Y-%m-%d')
        end_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        
        payload = {
            "dimensions": [
                {"name": "date"},
                {"name": "deviceCategory"},
                {"name": "userGender"},
                {"name": "userAgeBracket"}
            ],
            "metrics": [
                {"name": "newUsers"},
                {"name": "sessions"},
                {"name": "totalUsers"}
            ],
            "dateRanges": [
                {
                    "startDate": f"{start_date}",
                    "endDate": f"{end_date}"
                }
            ],
            "returnPropertyQuota": True
        }

        # 결과 파싱
        dimension_names = [
            d["name"] for d in payload.get("dimensions", [])
        ]

        metric_names = [
            m["name"] for m in payload.get("metrics", [])
        ]
        
        column_names = dimension_names + metric_names
        limit = 100000
        offset = 0

        # 기존 데이터 삭제
        del_start_date = (datetime.now() - timedelta(days=5)).strftime('%Y%m%d')
        del_end_date = (datetime.now() - timedelta(days=1)).strftime('%Y%m%d')
        delete_query = f"DELETE FROM GN_DW.BRONZE_GA4.{table_name} WHERE DATE BETWEEN '{del_start_date}' AND '{del_end_date}'"
        delete_result = session.sql(delete_query).collect()
        deleted_cnt = delete_result[0][0] if delete_result else 0
        logs.append(f"기존 {del_start_date} ~ {del_end_date} 데이터 삭제 완료 ({deleted_cnt} 건 처리)")
        while True:
            payload["limit"] = str(limit)
            payload["offset"] = str(offset)
            response = requests.post(
                url,
                headers=headers,
                json=payload
            )
            data = response.json()
            # API 오류 확인
            if "error" in data:
                raise Exception(f"GA4 API Error: {data['error']}")

            rows = data.get("rows", [])
            rowCount = data.get('rowCount')
            logs.append(
                f"[GA4 조회] " 
                f"rowCount={rowCount}"
            )

            # GA4 rows → DataFrame
            df = pandas.DataFrame(
                [
                    [
                        value["value"]
                        for value in row["dimensionValues"]
                    ]
                    +
                    [
                        value["value"]
                        for value in row["metricValues"]
                    ]
                    for row in rows
                ],
                columns=column_names
            )

            # 컬럼명 변환
            df.columns = [
                to_snake_upper(col)
                for col in df.columns
            ]

            if not df.empty:
                session.write_pandas(
                    df=df,
                    database="GN_DW",
                    schema="BRONZE_GA4",
                    table_name=table_name,
                )
                logs.append(f"  [성공] [{table_name}] 테이블에 적재 완료! {len(df)} 행 인입")
            # ========================================================
            # 마지막 페이지 확인
            # ========================================================
            if len(rows) < limit:
                break
            offset += limit
        return "\n".join(logs)
    except Exception as global_err:
        error_msg = str(global_err).replace("'", "''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_GA4.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), '{error_msg}')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\n".join(logs)
$$;


--260831 실행. 260831 기준 데이터 인입. 
-- 익일부터 프로시져화 
SELECT DATE, count(*)
FROM GN_DW.BRONZE_GA4.GA4_USER_DEMOGRAPHIC
GROUP BY DATE
ORDER BY DATE

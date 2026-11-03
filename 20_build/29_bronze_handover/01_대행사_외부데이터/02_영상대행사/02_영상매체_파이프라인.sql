-- 영상매체 파이프라인: Google Drive에서 영상 광고 데이터를 수집하여 Snowflake에 적재하는 프로세스
-- 기준년월을 입력받아 Google Drive의 영상 광고 엑셀 데이터를 조회·전처리하고, 컬럼 매핑 및 데이터 정제를 수행하여 VIDEO_AD_CMPGN_DTLS에 적재한다.
-- 기준년월(YYYYMM)을 기준으로 대상 월을 YYYY년 M월 형식으로 변환하여 해당 월이 포함된 영상 광고 엑셀 파일만 선별한다. 입력값이 없으면 전일 기준 월을 사용한다.
-- Google 서비스 계정 인증을 통해 Google Drive 및 Google Sheets API에 접근하고, 지정된 폴더의 스프레드시트 파일을 조회한다.
-- 전체송출내역(집계용) 시트만 대상으로 하며, 2행 이후 데이터를 조회하고 컬럼명을 정제하여 Snowflake 테이블 COMMENT와 컬럼을 자동 매핑한다.
-- 캠페인유형 데이터를 국내해외구분·사업사례구분으로 분리하고, 영상 광고의 채널·방송일자·프로그램·광고시간·광고시청률·광고비·후원자수·개발건수·노출수·클릭수 등의 데이터를 적재한다.
-- 프로그램시작시간과 방송일자의 원천 데이터 형식을 정제하여 시간 및 날짜 정보를 표준 형식으로 변환한다.
-- 대상 월의 기존 VIDEO_AD_CMPGN_DTLS 데이터를 삭제 후 재적재하여 월 단위 데이터 중복 적재를 방지한다.
-- 적재 또는 파일 처리 중 오류가 발생하면 SYNC_ERR_INFO에 발생일시, 데이터 유형(영상매체), 오류정보를 기록하고 처리 결과를 반환한다.

------------------------------------------------------------
-- 1. 스키마 생성
------------------------------------------------------------
CREATE SCHEMA GN_DW.BRONZE_AGENCY;

------------------------------------------------------------
-- 2 내부 스테이지 생성 및 json 파일 업로드
-- gn_google_service_account.json은 박종찬 팀장에게 전달받은 정보임. 
------------------------------------------------------------
CREATE STAGE GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
    
------------------------------------------------------------
-- 3 Network Rule 생성
------------------------------------------------------------
CREATE NETWORK RULE GN_DW.BRONZE_AGENCY.GOOGLE_API_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('oauth2.googleapis.com', 'www.googleapis.com', 'sheets.googleapis.com');

------------------------------------------------------------
-- 4. External Access Integration 생성
------------------------------------------------------------
CREATE EXTERNAL ACCESS INTEGRATION GOOGLE_API_ACCESS
    ALLOWED_NETWORK_RULES = (GN_DW.BRONZE_AGENCY.GOOGLE_API_RULE)
    ENABLED = TRUE;


------------------------------------------------------------
-- 5. 결과저장 테이블 생성
------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS (
	CHNNL_NM VARCHAR(16777216) COMMENT '채널',
	DOW VARCHAR(16777216) COMMENT '요일',
	BRDC_DATE DATE COMMENT '방송일자',
	TIME_RNG VARCHAR(16777216) COMMENT '시간대',
	DAY_DIV_NM VARCHAR(16777216) COMMENT '주중/토/일',
	PRG_STRT_TIME VARCHAR(16777216) COMMENT '프로그램시작시간',
	SCHDL_NM VARCHAR(16777216) COMMENT '편성명',
	CM VARCHAR(16777216) COMMENT 'CM',
	CM_AREA VARCHAR(16777216) COMMENT 'CM위치',
	AD_STRT_TIME VARCHAR(16777216) COMMENT '광고시작시간',
	AD_END_TIME VARCHAR(16777216) COMMENT '광고종료시간',
	SPOT_TY VARCHAR(16777216) COMMENT 'SpotType',
	AD_VIEW_RT FLOAT COMMENT '광고시청률',
	AD_CNT FLOAT COMMENT '횟수',
	AD_SEC VARCHAR(16777216) COMMENT '초수',
	LAST_AD_COST FLOAT COMMENT '최종광고비',
	INBOUND_CALL_CNT FLOAT COMMENT '인입콜',
	CPC_CALL_CNT FLOAT COMMENT 'CPC_CALL',
	UPPER_CMPGN_CD VARCHAR(16777216) COMMENT '상위캠페인코드',
	MATR_NM VARCHAR(16777216) COMMENT '소재',
	DMST_OVSEA_DIV_NM VARCHAR(16777216) COMMENT '캠페인유형(국내/해외)',
	BSNS_CASE_DIV_NM VARCHAR(16777216) COMMENT '캠페인유형(사업/사례)',
	CMPGN_TY_NM VARCHAR(16777216) COMMENT '캠페인유형',
	CHNNL_CMPNY_TY_NM VARCHAR(16777216) COMMENT '채널사유형',
	WEEK VARCHAR(16777216) COMMENT '주차',
	MONTH VARCHAR(16777216) COMMENT '월',
	AD_TY_NM VARCHAR(16777216) COMMENT '광고유형',
	BDGT_SOURCE_NM VARCHAR(16777216) COMMENT '예산출처',
	DEVICE_NM VARCHAR(16777216) COMMENT '기기',
	YEAR VARCHAR(16777216) COMMENT '연도',
	DAY VARCHAR(16777216) COMMENT '일자',
	SPNSER_CNT FLOAT COMMENT '후원자수',
	DVLP_CNT FLOAT COMMENT '개발건수',
	CMPGN_NM VARCHAR(16777216) COMMENT '캠페인명',
	MATR_TY_NM VARCHAR(16777216) COMMENT '소재유형',
	EXPSR_CNT FLOAT COMMENT '노출수',
	CLICK_CNT FLOAT COMMENT '클릭수'
)COMMENT='영상 광고 성과 내역'
;

------------------------------------------------------------
-- [프로시저 본체] Google Sheets -> Snowflake 적재
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_VIDEO_AD_FROM_GSHEET(INPUT_YYYYMM VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'openpyxl', 'requests', 'PyJWT', 'cryptography')
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/gn_google_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_API_ACCESS)
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
import openpyxl
import pandas
from datetime import datetime, timedelta
import jwt
from cryptography.hazmat.primitives import serialization

def get_google_access_token(sa_info):
    """서비스 계정 JSON으로 JWT를 생성하고 Google OAuth2 토큰을 발급받는다."""
    scopes = [
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/spreadsheets.readonly'
    ]
    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": " ".join(scopes),
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600
    }
    private_key = serialization.load_pem_private_key(
        sa_info["private_key"].encode(), password=None
    )
    encoded_jwt = jwt.encode(payload, private_key, algorithm="RS256")

    resp = requests.post(
        "https://oauth2.googleapis.com/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": encoded_jwt
        }
    )
    if resp.status_code != 200:
        raise Exception(f"Google OAuth2 토큰 발급 실패: {resp.status_code} - {resp.text}")
    return resp.json()["access_token"]


def drive_list_files(access_token, folder_id):
    """Google Drive API로 폴더 내 스프레드시트 파일 목록을 가져온다."""
    query = f"'{folder_id}' in parents and mimeType='application/vnd.google-apps.spreadsheet'"
    url = "https://www.googleapis.com/drive/v3/files"
    params = {
        "q": query,
        "fields": "files(id, name)",
        "supportsAllDrives": "true",
        "includeItemsFromAllDrives": "true"
    }
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(url, headers=headers, params=params)
    if resp.status_code != 200:
        raise Exception(f"Drive API 오류: {resp.status_code} - {resp.text}")
    return resp.json().get("files", [])


def sheets_get_metadata(access_token, spreadsheet_id):
    """스프레드시트의 시트(탭) 메타데이터를 가져온다."""
    url = f"https://sheets.googleapis.com/v4/spreadsheets/{spreadsheet_id}"
    params = {"fields": "sheets.properties"}
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(url, headers=headers, params=params)
    if resp.status_code != 200:
        raise Exception(f"Sheets metadata API 오류: {resp.status_code} - {resp.text}")
    return resp.json().get("sheets", [])


def sheets_get_values(access_token, spreadsheet_id, range_str):
    """스프레드시트의 특정 범위 값을 가져온다."""
    url = f"https://sheets.googleapis.com/v4/spreadsheets/{spreadsheet_id}/values/{range_str}"
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(url, headers=headers)
    if resp.status_code != 200:
        raise Exception(f"Sheets values API 오류: {resp.status_code} - {resp.text}")
    return resp.json().get("values", [])


def main(session, input_yyyymm):
    logs = []

    # input_yyyymm 유효성 검증
    try:
        datetime.strptime(input_yyyymm, '%Y%m')
    except (ValueError, TypeError):
        raise Exception(
            f"input_yyyymm 파라미터 오류: '{input_yyyymm}' "
            f"(YYYYMM 형식의 유효한 연월을 입력해주세요.)"
        )
    logs.append(f"[작업 기준월] {input_yyyymm} 데이터 수집 프로세스를 시작합니다.")

    try:
        table_name = 'VIDEO_AD_CMPGN_DTLS'
        # 구글 서비스 계정 인증 (JWT 방식)
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "gn_google_service_account.json")
        with open(sa_file_path, 'r') as f:
            sa_info = json.load(f)
        access_token = get_google_access_token(sa_info)
        logs.append(f"구글 API 인증 성공")

        # 대상 월 문자열 (예: "2026년 7월")
        try:
            target_yyyy = input_yyyymm[:4]
            target_mm = input_yyyymm[4:]
            clean_mm = str(int(target_mm))
            date_match_string = f"영상광고_{target_yyyy}년 {clean_mm}월"
        except Exception as date_err:
            print(f"[-] input_yyyymm({input_yyyymm}) 파싱 중 오류 발생: {date_err}")
            raise Exception(f"input_yyyymm({input_yyyymm}) 파싱 중 오류 발생: {date_err}")
        
        # 구글 드라이브 파일 목록 가져오기
        folder_id = "1WKPv87d1-nmo4SAFpHaLpzwRw8_oJ5Wv"
        files = drive_list_files(access_token, folder_id)

        if not files:
            raise Exception("접근 가능한 스프레드시트 파일이 구글 드라이브에 존재하지 않습니다.")

        logs.append(f"총 {len(files)}개의 파일을 찾았습니다.")

        metadata_cache = {}
        HEADER_ROW_NUM = 2
        metadata_cache = {}

        target_file_found = False
        # 파일 목록 순회
        for file in files:
            file_id = file['id']
            file_name = file['name']
            logs.append(f"--- [파일명: {file_name}] (ID: {file_id}) ---")

            if date_match_string not in file_name:
                logs.append(f"[-] 파일명 규칙에 해당 안되는 파일 패스합니다. [파일명]: '{file_name}'")
                continue
            
            target_file_found = True
            # 메타데이터(컬럼 정보) 가져오기 (캐시 활용)
            if table_name not in metadata_cache:
                metadata_query = f"""
                    SELECT COLUMN_NAME, DATA_TYPE, COMMENT
                    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = 'BRONZE_AGENCY'
                        AND TABLE_NAME = '{table_name}'
                    ORDER BY ORDINAL_POSITION
                """
                db_rows = session.sql(metadata_query).collect()
                if not db_rows:
                    logs.append(f"[-] '{table_name}' 메타데이터 없음")
                    raise Exception(f"[-] '{table_name}' 메타데이터 없음")

                comment_to_eng_map = {}
                eng_col_to_type_map = {}

                for row in db_rows:
                    eng_col = row['COLUMN_NAME'].strip().upper()
                    dtype = row['DATA_TYPE'].strip().upper()
                    comment = row['COMMENT'].strip().upper() if row['COMMENT'] else eng_col

                    comment_to_eng_map[comment] = eng_col
                    eng_col_to_type_map[eng_col] = dtype

                db_all_columns_eng = [row['COLUMN_NAME'].strip().upper() for row in db_rows]

                metadata_cache[table_name] = {
                    "map": comment_to_eng_map,
                    "types": eng_col_to_type_map,
                    "set": set(comment_to_eng_map.keys()),
                    "eng_cols": db_all_columns_eng
                }

            current_meta = metadata_cache[table_name]
            comment_to_eng_map = current_meta["map"]
            db_comments_set = current_meta["set"]
            db_all_columns_eng = current_meta["eng_cols"]
            eng_col_to_type_map = current_meta["types"]

            # 스프레드시트의 내부 탭(시트) 목록 조회
            sheets_list = sheets_get_metadata(access_token, file_id)

            for sheet in sheets_list:
                properties = sheet.get('properties', {})
                sheet_title = properties.get('title')
        
                if properties.get('hidden', False):
                    continue
                if sheet_title != '전체송출내역(집계용)':
                   continue
                logs.append(f"  [탭 탐색] {sheet_title}")

                # 탭별 데이터 호출 (범위: A2부터 끝까지)
                range_str = f"'{sheet_title}'!A{HEADER_ROW_NUM}:ZZ"
                raw_values = sheets_get_values(access_token, file_id, range_str)

                if not raw_values or len(raw_values) < 2:
                    logs.append(f"  [-] [{sheet_title}] 유효한 데이터가 부족하여 패스합니다.")
                    continue

                # 헤더 정제 및 검증
                if not raw_values[0] or all(str(col).strip() == "" for col in raw_values[0]):
                    raise Exception(f"시트 헤더 정의 오류 파일: '{file_name}' -> 탭: '{sheet_title}' [원인] 헤더 행({HEADER_ROW_NUM}번째 행)")

                header_columns_clean = [
                    "".join(str(col).split()).upper()
                    for col in raw_values[0] if str(col).strip() != ""
                ]
                header_set = set(header_columns_clean)

                if not header_set.issubset(db_comments_set):
                    missing_cols = header_set - db_comments_set
                    raise Exception(f"DB 매핑 오류 파일: '{file_name}' -> 탭: '{sheet_title}' [원인] DB COMMENT에 정의되지 않은 컬럼: {list(missing_cols)}")

                # 헤더 행과 데이터 행 분리
                headers = raw_values[0]
                data_contents = raw_values[1:]
                
                # DataFrame 생성
                df = pandas.DataFrame(data=data_contents, columns=headers)
                
                # 데이터 클렌징: 모든 값이 비어 있는 행 제거
                df = df.dropna(how='all')
                if df.empty:
                    raise Exception(f"DB 매핑 오류 파일: '{file_name}' -> 탭: '{sheet_title}' [원인] 행 데이터 없음")
                df.columns = header_columns_clean

                # [추가] 전체 컬럼 문자열 값의 앞뒤 공백 제거
                df = df.map(
                    lambda val: val.strip() if isinstance(val, str) else val
                )
                
                # 빈 문자열 및 공백만 있는 문자열을 None으로 변환
                df = df.replace(r'^\s*$', None, regex=True)
                # NaN을 None으로 변환
                df = df.astype(object).where(pandas.notnull(df), None)

                # 캠페인유형 분리
                if '캠페인유형' in df.columns:
                    split_data = df['캠페인유형'].str.split(' ', n=1, expand=True)
                    df['캠페인유형(국내/해외)'] = split_data[0]
                    df['캠페인유형(사업/사례)'] = split_data[1] if split_data.shape[1] > 1 else ""

                for col in header_columns_clean:
                    if col not in comment_to_eng_map:
                        comment_to_eng_map[col] = col

                # 스키마 동기화 및 구조화
                df_eng_named = df.rename(columns=comment_to_eng_map)
                
                df_cleaned = df_eng_named.reindex(columns=db_all_columns_eng, fill_value=None)
                
                # 숫자형 컬럼의 쉼표 제거 및 공백 정리
                for col, dtype in eng_col_to_type_map.items():
                    if col in df_cleaned.columns and dtype in ('FLOAT', 'REAL', 'DOUBLE'):
                        df_cleaned[col] = (
                            df_cleaned[col]
                            .astype('string')
                            .str.replace(',', '', regex=False)
                            .str.strip()
                            .replace('', None)
                        )
                # NaN을 None으로 변환
                df_cleaned = df_cleaned.astype(object).where(
                    pandas.notnull(df_cleaned),
                    None
                )                        
                
                # PRG_STRT_TIME 정제
                if 'PRG_STRT_TIME' in df_cleaned.columns:
                    cleaned_times = []
                    for val in df_cleaned['PRG_STRT_TIME']:
                        val_str_raw = str(val).strip()
                        if val is None or val_str_raw in ['', 'None', 'NaN', 'nat', 'NaT']:
                            cleaned_times.append(None)
                            continue
                        val_str = val_str_raw
                        if " " in val_str:
                            val_str = val_str.split(" ")[1]
                        cleaned_times.append(val_str)
                    df_cleaned['PRG_STRT_TIME'] = cleaned_times

                # BRDC_DATE 정제
                if 'BRDC_DATE' in df_cleaned.columns:
                    cleaned_dates = []
                    for val in df_cleaned['BRDC_DATE']:
                        val_str_raw = str(val).strip()
                        if val is None or val_str_raw in ['', 'None', 'NaN', 'nat', 'NaT']:
                            cleaned_dates.append(None)
                            continue
                        val_str = val_str_raw
                        if " " in val_str:
                            val_str = val_str.split(" ")[0]
                        cleaned_dates.append(val_str)
                    df_cleaned['BRDC_DATE'] = cleaned_dates


                

                # 대상 월의 기존 데이터 삭제
                delete_query = f"DELETE FROM GN_DW.BRONZE_AGENCY.{table_name} WHERE TO_CHAR(BRDC_DATE, 'YYYYMM') = '{input_yyyymm}'"
                delete_result = session.sql(delete_query).collect()
                deleted_cnt = delete_result[0][0] if delete_result else 0
                logs.append(f"기존 {input_yyyymm} 데이터 삭제 완료 ({deleted_cnt} 건 처리)")

                # 15. Snowflake 최종 적재 실행
                session.write_pandas(
                    df=df_cleaned,
                    database="GN_DW",
                    schema="BRONZE_AGENCY",
                    table_name=table_name,
                    overwrite=False
                )

                logs.append(f"  [성공] [{table_name}] 테이블에 적재 완료! {len(df_cleaned)} 행 인입!")
        if not target_file_found:
            raise Exception(
                f"대상 파일이 존재하지 않습니다. "
                f"[파일명: DIGITAL_{input_yyyymm}_*]"
            )
    except Exception as global_err:
        error_msg = str(global_err).replace("'", "''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), '영상매체', '{error_msg}')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\n".join(logs)
$$;
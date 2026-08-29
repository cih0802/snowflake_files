create or replace schema GN_DW.BRONZE_AGENCY with managed access COMMENT='원천 데이터 적재 - 대행사 (디지털/DRTV/재송출 광고)';

create or replace sequence GN_DW.BRONZE_AGENCY.SEQ_SYNC_ERR_INFO start with 1 increment by 1 noorder;
create or replace TABLE GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS (
	TIME VARCHAR(16777216) COMMENT '시간',
	YEAR VARCHAR(16777216) COMMENT '연도',
	CPR_NM VARCHAR(16777216) COMMENT '법인',
	DMST_OVSEA_DIV_NM VARCHAR(16777216) COMMENT '국내해외구분',
	BSNS_CASE_DIV_NM VARCHAR(16777216) COMMENT '사업사례구분',
	CMPGN_TY_NM VARCHAR(16777216) COMMENT '캠페인유형',
	AD_TY_NM VARCHAR(16777216) COMMENT '광고유형',
	MONTH VARCHAR(16777216) COMMENT '월',
	DEVICE VARCHAR(16777216) COMMENT '기기',
	MEDIA_NM VARCHAR(16777216) COMMENT '매체',
	WEEK VARCHAR(16777216) COMMENT '주차',
	DAY VARCHAR(16777216) COMMENT '일자',
	DOW VARCHAR(16777216) COMMENT '요일',
	CMPGN_NM VARCHAR(16777216) COMMENT '캠페인명',
	MATR VARCHAR(16777216) COMMENT '소재',
	MATR_TY_NM VARCHAR(16777216) COMMENT '소재유형',
	EXPS_CNT FLOAT COMMENT '노출수',
	CLICK_CNT FLOAT COMMENT '클릭수',
	GA_AD_COST FLOAT COMMENT '광고비',
	GA_CONV_MBER_CNT FLOAT COMMENT '후원자수(명)',
	CONV_VU_CNT FLOAT COMMENT '전환가치(건)',
	CPA FLOAT COMMENT 'CPA',
	DEV_UNIT_PRICE FLOAT COMMENT '개발단가',
	CTR FLOAT COMMENT 'CTR',
	CVR FLOAT COMMENT 'CVR',
	CPC FLOAT COMMENT 'CPC',
	CPM FLOAT COMMENT 'CPM',
	UPPER_CMPGN_NM VARCHAR(16777216) COMMENT '상위캠페인',
	READ_CNT FLOAT COMMENT '조회수',
	MEDIA_PTNT_CUST_CNT FLOAT COMMENT '잠재고객수(매체)',
	DATE DATE COMMENT '날짜',
	VTR FLOAT COMMENT 'VTR',
	PAGE_TYPE_NM VARCHAR(16777216) COMMENT '지면구분',
	CRM_DVLP_CNT FLOAT COMMENT 'CRM개발건수',
	AD_GRP_NM VARCHAR(16777216) COMMENT '광고그룹',
	GRP_DIV_NM VARCHAR(16777216) COMMENT '그룹구분'
)COMMENT='디지털 광고 성과 내역'
;
create or replace TABLE GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS (
	RE_BRDC_TY_NM VARCHAR(16777216) COMMENT '재송출유형',
	DIV_NM VARCHAR(16777216) COMMENT '구분',
	YEAR VARCHAR(16777216) COMMENT '년도',
	BRDC_MT VARCHAR(16777216) COMMENT '방송월',
	CHNNL_CMPNY VARCHAR(16777216) COMMENT '채널사',
	BRDC_NM VARCHAR(16777216) COMMENT '방송명',
	BRDC_DIV_NM VARCHAR(16777216) COMMENT '본방송구분',
	DATE DATE COMMENT '날짜',
	DOW VARCHAR(16777216) COMMENT '요일',
	BRDC_TIME VARCHAR(16777216) COMMENT '방송시간',
	INBOUND_CALL_CNT VARCHAR(16777216) COMMENT '인입콜',
	DVLP_MBER_CNT FLOAT COMMENT '회원개발(명)',
	DVLP_CNT FLOAT COMMENT '회원개발(건)',
	BRDC_SCHDL_COST FLOAT COMMENT '방송편성비',
	WEEK VARCHAR(16777216) COMMENT '주차',
	AD_CNT FLOAT COMMENT '횟수',
	TIME_RNG_DIV_NM VARCHAR(16777216) COMMENT '시간대구분',
	CELEB_NM VARCHAR(16777216) COMMENT '셀럽',
	DMST_OVSEA_DIV_NM VARCHAR(16777216) COMMENT '국내/해외구분',
	CASE1_BSNS_DIV_NM VARCHAR(16777216) COMMENT '사업구분1',
	CASE1_FAM_TY_NM VARCHAR(16777216) COMMENT '가정유형1',
	CASE1_APPEAL_POINT_NM VARCHAR(16777216) COMMENT '소구포인트1',
	CASE1_CHILD_NM VARCHAR(16777216) COMMENT '아동명1',
	CASE1_CASE_DIV_NM VARCHAR(16777216) COMMENT '사례구분1',
	CASE2_BSNS_DIV_NM VARCHAR(16777216) COMMENT '사업구분2',
	CASE2_FAM_TY_NM VARCHAR(16777216) COMMENT '가정유형2',
	CASE2_APPEAL_POINT_NM VARCHAR(16777216) COMMENT '소구포인트2',
	CASE2_CHILD_NM VARCHAR(16777216) COMMENT '아동명2',
	CASE2_CASE_DIV_NM VARCHAR(16777216) COMMENT '사례구분2',
	CASE3_BSNS_DIV_NM VARCHAR(16777216) COMMENT '사업구분3',
	CASE3_FAM_TY_NM VARCHAR(16777216) COMMENT '가정유형3',
	CASE3_APPEAL_POINT_NM VARCHAR(16777216) COMMENT '소구포인트3',
	CASE3_CHILD_NM VARCHAR(16777216) COMMENT '아동명3',
	CASE3_CASE_DIV_NM VARCHAR(16777216) COMMENT '사례구분3'
)COMMENT='재송출 광고 성과 내역'
;
create or replace TABLE GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (
	ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_AGENCY.SEQ_SYNC_ERR_INFO.NEXTVAL,
	ERR_DATETIME TIMESTAMP_NTZ(9),
	DATA_TYPE VARCHAR(16777216),
	ERR_INFO VARCHAR(16777216)
);
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
	AD_CNT NUMBER(38,0) COMMENT '횟수',
	AD_SEC VARCHAR(16777216) COMMENT '초수',
	ACTL_PUR_AD_COST_KRW NUMBER(38,0) COMMENT '실구매광고비(원)',
	INBOUND_CALL_CNT NUMBER(38,0) COMMENT '인입콜',
	CPC VARCHAR(16777216) COMMENT 'CPC',
	UPPER_CMPGN_NM VARCHAR(16777216) COMMENT '상위캠페인',
	MATR_NM VARCHAR(16777216) COMMENT '소재명',
	CMPGN_TY_NM VARCHAR(16777216) COMMENT '캠페인유형',
	DUR_PD_MATR_CHN VARCHAR(16777216) COMMENT '중도소재변경',
	CHNNL_CMPNY_TY_NM VARCHAR(16777216) COMMENT '채널사유형',
	WEEK VARCHAR(16777216) COMMENT '주차',
	CONV_CALL_CNT FLOAT COMMENT '전환콜',
	BRDC_MT VARCHAR(16777216) COMMENT '방송월',
	YEAR VARCHAR(16777216) COMMENT '해당연도',
	CTV_DIV_NM VARCHAR(16777216) COMMENT 'CTV 구분',
	MKT_CMPGN_NM VARCHAR(16777216) COMMENT '마케팅 캠페인명',
	SPNSR_BSNS_NM VARCHAR(16777216) COMMENT '후원사업구분',
	DMST_OVSEA_DIV_NM VARCHAR(16777216) COMMENT '캠페인유형(국내/해외)',
	BSNS_CASE_DIV_NM VARCHAR(16777216) COMMENT '캠페인유형(사업/사례)'
)COMMENT='영상 광고 성과 내역'
;
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_AGENCY.GN_CSV_FORMAT
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
;
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_DGT_AD_FROM_GSHEET("INPUT_YYYYMM" VARCHAR DEFAULT null)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python','pandas','requests','pyjwt','cryptography')
HANDLER = 'main'
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/gn_google_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_API_ACCESS)
EXECUTE AS CALLER
AS '
import sys
import os
import json
import time
import pandas
import requests
import jwt
from cryptography.hazmat.primitives import serialization
from datetime import datetime, timedelta

def get_google_access_token(sa_info):
    """서비스 계정 JSON으로 JWT를 생성하고 Google OAuth2 토큰을 발급받는다."""
    scopes = [
        ''https://www.googleapis.com/auth/drive.readonly'',
        ''https://www.googleapis.com/auth/spreadsheets.readonly''
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
    query = f"''{folder_id}'' in parents and mimeType=''application/vnd.google-apps.spreadsheet''"
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


def main(session, input_yyyymm=None):
    logs = []

    if not input_yyyymm:
        input_yyyymm = (datetime.now() - timedelta(days=1)).strftime(''%Y%m'')
    logs.append(f"[작업 기준월] {input_yyyymm} 데이터 수집 프로세스를 시작합니다.")

    try:
        table_name = ''DGT_AD_CMPGN_DTLS''
        # 구글 서비스 계정 인증 (JWT 방식)
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "gn_google_service_account.json")
        with open(sa_file_path, ''r'') as f:
            sa_info = json.load(f)
        access_token = get_google_access_token(sa_info)
        logs.append(f"구글 API 인증 성공")

        # 구글 드라이브 파일 목록 가져오기
        folder_id = "1D0tCZdM0oquThfviLoLowC4eSuZexfvC"
        files = drive_list_files(access_token, folder_id)

        if not files:
            raise Exception("접근 가능한 스프레드시트 파일이 구글 드라이브에 존재하지 않습니다.")

        logs.append(f"총 {len(files)}개의 파일을 찾았습니다.")

        metadata_cache = {}
        FILTER_TARGET_COLUMN = "소재"
        HEADER_ROW_NUM = 3

        # 파일 목록 순회
        for file in files:
            file_id = file[''id'']
            file_name = file[''name'']
            logs.append(f"--- [파일명: {file_name}] (ID: {file_id}) ---")

            parts = file_name.split(''_'')
            if len(parts) < 2:
                logs.append(f"[-] 파일명 형식이 규칙에 맞지 않아 패스합니다. (구분자 ''_'' 부족)")
                continue

            file_type = parts[0].upper()
            file_yyyymm = parts[1]

            if input_yyyymm != file_yyyymm:
                logs.append(f"[-] 해당 월에 해당 안되는 파일 패스합니다. [파일명]: ''{file_name}''")
                continue
            if file_type != ''DIGITAL'' or input_yyyymm != file_yyyymm:
                raise Exception(f"파라미터 오류 [파일명]: ''{file_name}'' / [대상년월 파라미터] : {input_yyyymm}")

            # 메타데이터(컬럼 정보) 가져오기 (캐시 활용)
            if table_name not in metadata_cache:
                metadata_query = f"""
                    SELECT COLUMN_NAME, DATA_TYPE, COMMENT
                    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = ''BRONZE_AGENCY''
                        AND TABLE_NAME = ''{table_name}''
                    ORDER BY ORDINAL_POSITION
                """
                db_rows = session.sql(metadata_query).collect()
                if not db_rows:
                    raise Exception(f"Snowflake DB에 ''{table_name}'' 테이블이 없거나 컬럼 설정(메타데이터)이 존재하지 않습니다.")

                comment_to_eng_map = {}
                eng_col_to_type_map = {}

                for row in db_rows:
                    eng_col = row[''COLUMN_NAME''].strip().upper()
                    dtype = row[''DATA_TYPE''].strip().upper()
                    comment = row[''COMMENT''].strip().upper() if row[''COMMENT''] else eng_col

                    comment_to_eng_map[comment] = eng_col
                    eng_col_to_type_map[eng_col] = dtype

                db_all_columns_eng = [row[''COLUMN_NAME''].strip().upper() for row in db_rows]

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

            # 대상 월의 기존 데이터 삭제
            delete_query = f"DELETE FROM GN_DW.BRONZE_AGENCY.{table_name} WHERE TO_CHAR(DATE, ''YYYYMM'') = ''{input_yyyymm}''"
            delete_result = session.sql(delete_query).collect()
            deleted_cnt = delete_result[0][0] if delete_result else 0
            logs.append(f"기존 {input_yyyymm} 데이터 삭제 완료 ({deleted_cnt} 건 처리)")

            # 스프레드시트의 내부 탭(시트) 목록 조회
            sheets_list = sheets_get_metadata(access_token, file_id)

            for sheet in sheets_list:
                properties = sheet.get(''properties'', {})
                sheet_title = properties.get(''title'')

                if properties.get(''hidden'', False):
                    continue

                logs.append(f"  [탭 탐색] {sheet_title}")

                # 탭별 데이터 호출 (범위: B3부터 끝까지)
                range_str = f"''{sheet_title}''!B{HEADER_ROW_NUM}:ZZ"
                raw_values = sheets_get_values(access_token, file_id, range_str)

                if not raw_values or len(raw_values) < 2:
                    logs.append(f"  [-] [{sheet_title}] 유효한 데이터가 부족하여 패스합니다.")
                    continue

                # 헤더 정제 및 검증
                if not raw_values[0] or all(str(col).strip() == "" for col in raw_values[0]):
                    raise Exception(f"시트 헤더 정의 오류 파일: ''{file_name}'' -> 탭: ''{sheet_title}'' [원인] 헤더 행({HEADER_ROW_NUM}번째 행)")

                header_columns_clean = [
                    "".join(str(col).split()).upper()
                    for col in raw_values[0] if str(col).strip() != ""
                ]
                header_set = set(header_columns_clean)

                if not header_set.issubset(db_comments_set):
                    missing_cols = header_set - db_comments_set
                    raise Exception(f"DB 매핑 오류 파일: ''{file_name}'' -> 탭: ''{sheet_title}'' [원인] DB COMMENT에 정의되지 않은 컬럼: {list(missing_cols)}")

                # 필터링 기준 컬럼 인덱스 찾기
                target_upper = FILTER_TARGET_COLUMN.strip().upper()
                target_idx = -1
                if target_upper in header_columns_clean:
                    target_idx = header_columns_clean.index(target_upper)

                # 유령 행 및 특정 열 빈값 필터링
                valid_data_rows = []
                for offset, row in enumerate(raw_values[1:], start=1):
                    if not row or all(str(cell).strip() == "" for cell in row):
                        continue

                    if target_idx != -1:
                        if len(row) <= target_idx or str(row[target_idx]).strip() == "" or str(row[target_idx]).strip() == "-":
                            continue

                    actual_row_num = HEADER_ROW_NUM + offset
                    valid_data_rows.append((actual_row_num, row))

                if not valid_data_rows:
                    logs.append(f" [{sheet_title}] 적재할 유효한 행이 없습니다.")
                    continue

                # Pandas DataFrame 생성
                row_numbers = [r[0] for r in valid_data_rows]
                data_contents = [r[1] for r in valid_data_rows]

                df = pandas.DataFrame(data=data_contents, columns=header_columns_clean, index=row_numbers)

                # 데이터 타입별 전처리 및 로우 레벨 상세 예외 추적
                for col in df.columns:
                    if col not in comment_to_eng_map:
                        df[col] = None
                        continue

                    eng_col_name = comment_to_eng_map[col]
                    db_type = eng_col_to_type_map[eng_col_name]

                    df[col] = df[col].fillna("").astype(str).str.strip()
                    df[col] = df[col].apply(lambda x: "" if x.upper() in [''-'', ''NULL'', ''NAN''] else x)

                    if ''CHAR'' in db_type or ''TEXT'' in db_type:
                        df[col] = df[col].apply(lambda x: '''' if x == "" else x)

                    elif any(num_type in db_type for num_type in [''INT'', ''BIGINT'', ''NUMBER'', ''FLOAT'', ''DECIMAL'']):
                        df[col] = df[col].str.replace('','', '''', regex=False)

                        has_percent = df[col].str.contains(''%'', regex=False)
                        if has_percent.any():
                            df[col] = df[col].str.replace(''%'', '''', regex=False)
                            df[col] = df[col].apply(lambda x: ''0'' if x == "" else x)

                            for idx, val in df[col].items():
                                try:
                                    df.at[idx, col] = float(val) / 100
                                except ValueError:
                                    raise Exception(f"데이터 형변환 에러 파일: ''{file_name}'' -> 탭: ''{sheet_title}'' -> 행: [{idx}행] [원인] ''{col}'' 속성에 잘못된 퍼센트 값(''{val}%'')이 입력되었습니다. (DB 타입: {db_type})")
                        else:
                            df[col] = df[col].apply(lambda x: ''0'' if x == "" else x)

                            for idx, val in df[col].items():
                                try:
                                    if ''INT'' in db_type:
                                        df.at[idx, col] = int(float(val))
                                    else:
                                        df.at[idx, col] = float(val)
                                except ValueError:
                                    raise Exception(f"데이터 형변환 에러 [위치] 파일: ''{file_name}'' -> 탭: ''{sheet_title}'' -> 행: [{idx}행] [원인] ''{col}'' 속성에 숫자가 아닌 값(''{val}'')이 입력되었습니다. (DB 타입: {db_type})")

                # CMPGN_TY_NM 컬럼 분리
                if ''캠페인유형'' in df.columns:
                    split_data = df[''캠페인유형''].str.split('' '', n=1, expand=True)
                    df[''국내해외구분''] = split_data[0]
                    df[''사업사례구분''] = split_data[1] if len(split_data.columns) > 1 else ""

                # YEAR, MONTH, DAY 날짜 조합
                if all(col in df.columns for col in [''연도'', ''월'', ''일자'']):
                    if ''날짜'' not in df.columns:
                        clean_year = df[''연도''].astype(str).str.strip()
                        clean_month = df[''월''].astype(str).str.strip().str.zfill(2)
                        clean_day = df[''일자''].astype(str).str.strip().str.zfill(2)
                        df[''날짜''] = clean_year + ''-'' + clean_month + ''-'' + clean_day

                # 스키마 동기화 및 구조화
                df_eng_named = df.rename(columns=comment_to_eng_map)
                df_cleaned = df_eng_named.reindex(columns=db_all_columns_eng, fill_value=None)

                # 15. Snowflake 최종 적재 실행
                session.write_pandas(
                    df=df_cleaned,
                    database="GN_DW",
                    schema="BRONZE_AGENCY",
                    table_name=table_name,
                    overwrite=False
                )

                logs.append(f"  [성공] [{table_name}] 테이블에 적재 완료! {len(df_cleaned)} 행 인입!")

    except Exception as global_err:
        error_msg = str(global_err).replace("''", "''''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), ''디지털'', ''{error_msg}'')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\\n".join(logs)
';
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_REBRDC_FROM_SHAREPOINT()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python','pandas','requests')
HANDLER = 'main'
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/msSharePointInfo.json')
EXTERNAL_ACCESS_INTEGRATIONS = (MS_GRAPH_ACCESS)
EXECUTE AS CALLER
AS '
import os
import sys
import json
import pandas as pd
import requests

def main(session):
    log_messages = []
    table_name = ''REBRDC_AD_CMPGN_DTLS''

    try:
        # 설정 정보
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "msSharePointInfo.json")
        with open(sa_file_path, ''r'') as f:
            sa_info = json.load(f)
        
        TENANT_ID = sa_info["TENANT_ID"]
        CLIENT_ID = sa_info["CLIENT_ID"]
        USERNAME = sa_info["USERNAME"]
        PASSWORD = sa_info["PASSWORD"]
        SITE_ID = sa_info["SITE_ID"]
        ITEM_ID = sa_info["ITEM_ID"]            

        # 엑세스 토큰 발급
        token_res = requests.post(
            f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
            data={
                "grant_type": "password",
                "client_id": CLIENT_ID,
                "username": USERNAME,
                "password": PASSWORD,
                "scope": "https://graph.microsoft.com/.default",
            },
        ).json()

        if "access_token" not in token_res:
            return f"ERROR: 토큰 획득 실패 - {token_res}"

        token = token_res["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 워크시트 목록 조회
        ws_res = requests.get(
            f"https://graph.microsoft.com/v1.0/sites/{SITE_ID}/drive/items/{ITEM_ID}/workbook/worksheets",
            headers=headers,
        )

        if ws_res.status_code != 200:
            raise Exception(f"워크시트 목록 조회 실패: {ws_res.json()}")

        worksheets = ws_res.json().get("value", [])
        if not worksheets:
            raise Exception("대상 엑셀 파일 내에 워크시트(탭)가 존재하지 않습니다.")

        # 메타데이터 조회
        metadata_query = f"""
            SELECT COLUMN_NAME, ORDINAL_POSITION, COMMENT
            FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ''BRONZE_AGENCY''
              AND TABLE_NAME = ''{table_name}''
            ORDER BY ORDINAL_POSITION
        """
        db_rows = session.sql(metadata_query).collect()
        if not db_rows:
            raise Exception(f"''{table_name}'' 테이블 메타데이터 없음")

        comment_to_eng_map = {
            row["COMMENT"].strip().replace("\\n", "").replace(" ", "").upper(): row["COLUMN_NAME"].strip().upper()
            for row in db_rows
            if row["COMMENT"]
        }
        db_all_columns_eng = [row["COLUMN_NAME"].strip().upper() for row in db_rows]
        db_comments_set = set(comment_to_eng_map.keys())

        # 기존 데이터 삭제
        delete_result = session.sql(f"DELETE FROM GN_DW.BRONZE_AGENCY.{table_name}").collect()
        deleted_cnt = delete_result[0][0] if delete_result else 0
        log_messages.append(f"[삭제] 기존 {deleted_cnt}건 삭제 완료")

        # 대상 시트 순회 및 데이터 정제/적재
        TARGET_SHEET_NAMES = ["데이터관리 양식(특집)", "데이터관리 양식(재송출)"]

        for sheet in worksheets:
            sheet_name = sheet.get("name")

            if sheet_name not in TARGET_SHEET_NAMES:
                continue

            if sheet_name == ''데이터관리 양식(특집)'':
                TARGET_RANGE = "A2:CQ5000"
            else:
                TARGET_RANGE = "A2:AZ5000"

            data_res = requests.get(
                f"https://graph.microsoft.com/v1.0/sites/{SITE_ID}/drive/items/{ITEM_ID}/workbook/worksheets/{sheet_name}/range(address=''{TARGET_RANGE}'')",
                headers=headers,
            )

            if data_res.status_code != 200:
                log_messages.append(f"[-] ''{sheet_name}'' 데이터 조회 실패")
                continue

            all_rows = data_res.json().get("values", [])
            if not all_rows or len(all_rows) <= 1:
                log_messages.append(f"[-] ''{sheet_name}'' 데이터 없음")
                continue

            # DataFrame 변환
            header_cols = all_rows[0]
            data_rows = all_rows[1:]
            df = pd.DataFrame(data_rows, columns=header_cols)
            df = df.replace(r"^\\s*$", None, regex=True).infer_objects(copy=False)
            df = df[df["방송명"].astype(str).str.strip() != ""]
            df = df[df["날짜"].notna()]

            if df.empty:
                log_messages.append(f"[-] ''{sheet_name}'' 유효 데이터 없음")
                continue

            # ''사례구분3'' 이후 컬럼 제거
            col_list_clean = [str(c).replace("\\n", "").replace(" ", "").strip() for c in df.columns]
            target_col = "사례구분3"
            if target_col in col_list_clean:
                target_index = col_list_clean.index(target_col)
                columns_after_target = df.columns[target_index + 1:]
                if len(columns_after_target) > 0:
                    df.drop(columns=columns_after_target, errors="ignore", inplace=True)

            # 컬럼 정제
            columns_to_drop = []
            renamed_columns_map = {}

            for col in df.columns:
                col_str = str(col).strip()
                if "Unnamed:" in col_str:
                    columns_to_drop.append(col)
                    continue
                clean_col = col_str.replace("\\n", "").replace(" ", "").strip().upper()

                if col_str == "방송시간":
                    cleaned_values = []
                    for val in df[col]:
                        if pd.isnull(val) or val is None:
                            cleaned_values.append(None)
                        elif type(val).__name__ in [''time'', ''datetime'', ''date'']:
                            cleaned_values.append(val.strftime(''%H:%M:%S''))
                        else:
                            val_str = str(val).strip()
                            if val_str.replace(''.'', '''', 1).isdigit():
                                try:
                                    serial_f = float(val_str)
                                    if serial_f >= 0:
                                        total_seconds = round(serial_f * 24 * 3600)
                                        hours = total_seconds // 3600
                                        minutes = (total_seconds % 3600) // 60
                                        seconds = total_seconds % 60
                                        val_str = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
                                except ValueError:
                                    pass
                            if " " in val_str and "-" in val_str and ":" in val_str:
                                val_str = val_str.split(" ")[1] if "1900-01-01" in val_str else val_str.split(" ")[0]
                            if val_str in [0, 1, ''0'', ''1'']:
                                val_str = "00:00:00" if val_str in [0, ''0''] else "24:00:00"
                            cleaned_values.append(val_str)
                    df[col] = cleaned_values

                elif col_str == "날짜":
                    cleaned_dates = []
                    for val in df[col]:
                        if pd.isnull(val) or val is None:
                            cleaned_dates.append(None)
                        elif type(val).__name__ in [''datetime'', ''date'']:
                            cleaned_dates.append(val.strftime(''%Y-%m-%d''))
                        else:
                            val_str = str(val).strip()
                            if val_str.replace(''.0'', '''', 1).isdigit():
                                try:
                                    excel_date = pd.to_datetime(float(val_str), unit=''D'', origin=''1899-12-30'')
                                    val_str = excel_date.strftime(''%Y-%m-%d'')
                                except Exception:
                                    pass
                            elif " " in val_str:
                                val_str = val_str.split(" ")[0]
                            cleaned_dates.append(val_str)
                    df[col] = cleaned_dates

                if clean_col in db_comments_set:
                    renamed_columns_map[col] = clean_col
                else:
                    columns_to_drop.append(col)

            if columns_to_drop:
                df.drop(columns=columns_to_drop, errors="ignore", inplace=True)
            df.rename(columns=renamed_columns_map, inplace=True)
            current_columns = [str(col) for col in df.columns]
            header_set = set(current_columns)

            if not header_set.issubset(db_comments_set):
                missing_cols = header_set - db_comments_set
                raise Exception(f"[검증 실패] DB COMMENT에 없는 컬럼: {list(missing_cols)}")

            df.columns = current_columns
            if ''본방송구분'' not in df.columns:
                df[''본방송구분''] = None
            df.rename(columns=comment_to_eng_map, inplace=True)

            if ''RE_BRDC_TY_NM'' not in df.columns:
                if sheet_name.upper() == ''데이터관리 양식(특집)'':
                    df.insert(loc=0, column=''RE_BRDC_TY_NM'', value=''특집'')
                else:
                    df.insert(loc=0, column=''RE_BRDC_TY_NM'', value=''재송출'')

            if ''INBOUND_CALL_CNT'' in df.columns:
                df[''INBOUND_CALL_CNT''] = df[''INBOUND_CALL_CNT''].fillna('''').astype(str)
                df[''INBOUND_CALL_CNT''] = df[''INBOUND_CALL_CNT''].apply(
                    lambda x: None if x in ['''', ''None'', ''NaN''] else x
                )

            # Snowflake 적재
            session.write_pandas(
                df=df,
                table_name=table_name,
                database="GN_DW",
                schema="BRONZE_AGENCY",
                overwrite=False
            )
            log_messages.append(f"[+] ''{sheet_name}'' {len(df)}건 적재 완료")

    except Exception as global_err:
        try:
            error_msg = str(global_err).replace("''", "''''")
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), ''재송출'', ''{error_msg}'')"
            session.sql(error_query).collect()
        except:
            pass
        return f"ERROR: {str(global_err)}"

    if not log_messages:
        return "처리 결과 없음"
    return "\\n".join(log_messages)
';
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_VIDEO_AD_FROM_GDRIVE("INPUT_YYYYMM" VARCHAR DEFAULT null)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python','pandas','openpyxl','requests','PyJWT','cryptography')
HANDLER = 'main'
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/gn_google_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_API_ACCESS)
EXECUTE AS CALLER
AS '
import io
import json
import os
import sys
import time
import requests
import openpyxl
import pandas
import datetime as dt
from datetime import datetime, timedelta
import jwt
from cryptography.hazmat.primitives import serialization


def get_access_token(sa_info):
    now = int(time.time())
    payload = {
        "iss": sa_info["client_email"],
        "scope": "https://www.googleapis.com/auth/drive.readonly",
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
    if resp.status_code != 200:
        raise Exception(f"Google OAuth2 토큰 발급 실패: {resp.status_code} - {resp.text}")
    return resp.json()["access_token"]


def drive_list_files(token, folder_id):
    q = f"''{folder_id}'' in parents and mimeType=''application/vnd.openxmlformats-officedocument.spreadsheetml.sheet''"
    resp = requests.get(
        "https://www.googleapis.com/drive/v3/files",
        headers={"Authorization": f"Bearer {token}"},
        params={
            "q": q,
            "fields": "files(id,name)",
            "supportsAllDrives": "true",
            "includeItemsFromAllDrives": "true"
        }
    )
    resp.raise_for_status()
    return resp.json().get("files", [])


def drive_download(token, file_id):
    resp = requests.get(
        f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media",
        headers={"Authorization": f"Bearer {token}"}
    )
    resp.raise_for_status()
    return io.BytesIO(resp.content)


def main(session, input_yyyymm=None):
    if not input_yyyymm:
        input_yyyymm = (datetime.now() - timedelta(days=1)).strftime(''%Y%m'')

    log_messages = []
    log_messages.append(f"[작업 기준월] {input_yyyymm} 데이터 수집 프로세스를 시작합니다.")
    try:
        # Google 인증 (스테이지에서 IMPORT한 JSON 파일 읽기)
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "gn_google_service_account.json")
        with open(sa_file_path, ''r'') as f:
            sa_info = json.load(f)
        token = get_access_token(sa_info)
        log_messages.append(f"구글 API 인증 성공")
        
        # 대상 월 문자열 (예: "2026년 7월")
        try:
            target_yyyy = input_yyyymm[:4]
            target_mm = input_yyyymm[4:]
            clean_mm = str(int(target_mm))
            date_match_string = f"{target_yyyy}년 {clean_mm}월"
        except Exception as date_err:
            print(f"[-] input_yyyymm({input_yyyymm}) 파싱 중 오류 발생: {date_err}")
            raise Exception(f"input_yyyymm({input_yyyymm}) 파싱 중 오류 발생: {date_err}")
        # Google Drive 파일 목록
        folder_id = "1NO0ZAOWEoHjclENDrmzSzAgiWp7fNkLi"
        files = drive_list_files(token, folder_id)

        if not files:
            raise Exception("접근 가능한 엑셀(.xlsx) 파일이 없습니다.")

        log_messages.append(f"[+] 총 {len(files)}개 파일 발견")

        # 상수
        table_name = ''VIDEO_AD_CMPGN_DTLS''
        HEADER_ROW_NUM = 1
        metadata_cache = {}

        for file in files:
            file_id = file[''id'']
            file_name = file[''name'']

            if date_match_string not in file_name:
                log_messages.append(f"[-] 해당 월에 해당 안되는 파일 패스합니다. [파일명]: ''{file_name}''")
                continue

            try:
                # 메타데이터 캐시
                if table_name not in metadata_cache:
                    metadata_query = f"""
                        SELECT COLUMN_NAME, ORDINAL_POSITION, COMMENT
                        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
                        WHERE TABLE_SCHEMA = ''BRONZE_AGENCY''
                          AND TABLE_NAME = ''{table_name}''
                        ORDER BY ORDINAL_POSITION
                    """
                    db_rows = session.sql(metadata_query).collect()
                    if not db_rows:
                        log_messages.append(f"[-] ''{table_name}'' 메타데이터 없음")
                        raise Exception(f"[-] ''{table_name}'' 메타데이터 없음")

                    comment_to_eng_map = {}
                    db_comments_set_clean = set()
                    for row in db_rows:
                        if row[''COMMENT'']:
                            clean_comment = str(row[''COMMENT'']).replace("\\n", "").replace(" ", "").strip().upper()
                            comment_to_eng_map[clean_comment] = row[''COLUMN_NAME''].strip().upper()
                            db_comments_set_clean.add(clean_comment)

                    db_all_columns_eng = [row[''COLUMN_NAME''].strip().upper() for row in db_rows]
                    metadata_cache[table_name] = {
                        "map": comment_to_eng_map,
                        "set": db_comments_set_clean,
                        "eng_cols": db_all_columns_eng
                    }

                current_meta = metadata_cache[table_name]
                comment_to_eng_map = current_meta["map"].copy()
                db_comments_set_clean = current_meta["set"]
                db_all_columns_eng = current_meta["eng_cols"]

                # 기존 데이터 삭제
                delete_query = f"DELETE FROM GN_DW.BRONZE_AGENCY.{table_name} WHERE TO_CHAR(BRDC_DATE, ''YYYYMM'') = ''{input_yyyymm}''"
                delete_result = session.sql(delete_query).collect()
                deleted_cnt = delete_result[0][0] if delete_result else 0
                log_messages.append(f"[삭제] {input_yyyymm} 기존 {deleted_cnt}건 삭제")

                # 파일 다운로드
                file_stream = drive_download(token, file_id)

                wb = openpyxl.load_workbook(file_stream, read_only=True)
                sheet_names = [s for s in wb.sheetnames if wb[s].sheet_state == ''visible'']
                wb.close()

                for sheet_title in sheet_names:
                    if sheet_title != ''전체송출내역(집계용)'':
                        continue

                    file_stream.seek(0)
                    df_raw = pandas.read_excel(
                        file_stream,
                        sheet_name=sheet_title,
                        skiprows=HEADER_ROW_NUM,
                        usecols=lambda col_idx: 0 <= col_idx <= 25,
                        header=None
                    )

                    if df_raw.empty or len(df_raw) < 2:
                        continue

                    # 헤더 정제
                    header_columns_clean = []
                    header_counts = {}
                    for idx, col in enumerate(df_raw.iloc[0]):
                        if pandas.notnull(col) and str(col).strip().upper() != ''NAN'' and str(col).strip() != "":
                            clean_name = str(col).replace("\\n", "").replace(" ", "").strip().upper()
                        else:
                            clean_name = f"EMPTY_COL_{idx}"
                        if clean_name in header_counts:
                            header_counts[clean_name] += 1
                            header_columns_clean.append(f"{clean_name}_{header_counts[clean_name]}")
                        else:
                            header_counts[clean_name] = 0
                            header_columns_clean.append(clean_name)

                    header_set = {c.split(''_'')[0] for c in header_columns_clean if not c.startswith("EMPTY_COL_")}
                    if not header_set.issubset(db_comments_set_clean):
                        missing_cols = header_set - db_comments_set_clean
                        log_messages.append(f"[-] ''{file_name}'' 미정의 컬럼: {list(missing_cols)}")
                        continue

                    # 데이터 클렌징
                    df = df_raw.iloc[1:].dropna(how=''all'')
                    if df.empty:
                        continue
                    df.columns = header_columns_clean
                    df = df.astype(object).where(pandas.notnull(df), None)

                    # 캠페인유형 분리
                    if ''캠페인유형'' in df.columns:
                        split_data = df[''캠페인유형''].str.split('' '', n=1, expand=True)
                        df[''국내해외구분''] = split_data[0]
                        df[''사업사례구분''] = split_data[1] if split_data.shape[1] > 1 else ""

                    for col in header_columns_clean:
                        if col not in comment_to_eng_map:
                            comment_to_eng_map[col] = col

                    df_cleaned = df.rename(columns=comment_to_eng_map).reindex(columns=db_all_columns_eng, fill_value=None)

                    # PRG_STRT_TIME 정제
                    if ''PRG_STRT_TIME'' in df_cleaned.columns:
                        cleaned_times = []
                        for val in df_cleaned[''PRG_STRT_TIME'']:
                            val_str_raw = str(val).strip()
                            if val is None or val_str_raw in ['''', ''None'', ''NaN'', ''nat'', ''NaT'']:
                                cleaned_times.append(None)
                                continue
                            val_str = val_str_raw
                            if " " in val_str:
                                val_str = val_str.split(" ")[1]
                            cleaned_times.append(val_str)
                        df_cleaned[''PRG_STRT_TIME''] = cleaned_times

                    # BRDC_DATE 정제
                    if ''BRDC_DATE'' in df_cleaned.columns:
                        cleaned_dates = []
                        for val in df_cleaned[''BRDC_DATE'']:
                            val_str_raw = str(val).strip()
                            if val is None or val_str_raw in ['''', ''None'', ''NaN'', ''nat'', ''NaT'']:
                                cleaned_dates.append(None)
                                continue
                            val_str = val_str_raw
                            if " " in val_str:
                                val_str = val_str.split(" ")[0]
                            cleaned_dates.append(val_str)
                        df_cleaned[''BRDC_DATE''] = cleaned_dates

                    session.write_pandas(
                        df=df_cleaned,
                        database="GN_DW",
                        schema="BRONZE_AGENCY",
                        table_name=table_name,
                        overwrite=False
                    )
                    log_messages.append(f"[+] ''{file_name}'' [{sheet_title}] {len(df_cleaned)}건 적재 완료")

            except Exception as file_err:
                log_messages.append(f"[-] ''{file_name}'' 오류: {str(file_err)}")
                raise Exception(f"input_yyyymm({input_yyyymm}) 파싱 중 오류 발생: {file_err}")

    except Exception as global_err:
        try:
            error_msg = str(global_err).replace("''", "''''")
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), ''영상매체'', ''{error_msg}'')"
            session.sql(error_query).collect()
        except:
            pass
        return f"ERROR: {str(global_err)}"

    if not log_messages:
        return f"''{date_match_string}'' 결과가 없음"
    return "\\n".join(log_messages)
';
create or replace task GN_DW.BRONZE_AGENCY.TASK_REBRDC
	warehouse=GN_DW_ETL_WH
	as BEGIN
    CALL GN_DW.BRONZE_AGENCY.SP_LOAD_REBRDC_FROM_SHAREPOINT();
END;
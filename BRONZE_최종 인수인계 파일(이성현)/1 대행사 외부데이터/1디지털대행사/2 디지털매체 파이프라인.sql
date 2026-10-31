-- Google Sheets 데이터를 requests+JWT 방식으로 Snowflake BRONZE_AGENCY 테이블에 적재하는 프로시저
-- DGT_AD_CMPGN_DTLS 테이블
-- YYYYMM에 해당하는 데이터 삭제 후, 데아터 인입 
-- 기준년월을 입력받아 Google Sheets의 디지털 광고 운영 데이터를 조회·전처리하고, 컬럼 매핑 및 데이터 타입을 검증하여 DGT_AD_CMPGN_DTLS에 적재한다.
-- Google 서비스 계정 인증을 통해 Google Drive 및 Google Sheets API에 접근하고, 지정된 폴더의 스프레드시트 파일을 조회한다.
-- 파일명에서 기준년월을 확인하여 DIGITAL_{YYYYMM}_* 형식의 대상 파일만 선별하고, 대상 월의 기존 데이터를 삭제 후 재적재한다.
-- 스프레드시트의 공개된 탭을 순회하며 3행을 헤더로 사용하고 B3:ZZ 범위의 데이터를 조회하며, 소재가 없거나 빈 행 등 유효하지 않은 데이터는 제외한다.
-- 테이블 COMMENT와 스프레드시트 컬럼명을 매핑하여 광고유형, 캠페인, 매체, 소재, 광고비, 후원자 수, 전환 및 광고성과 등의 데이터를 표준 컬럼으로 변환한다.
-- 데이터 타입에 따라 문자열·숫자·비율 데이터를 전처리하고, 콤마 제거, % 변환, 빈값 및 NULL 처리, 숫자형 변환 등을 수행하여 적재 데이터의 형식을 검증한다.
-- 캠페인유형을 캠페인유형1·캠페인유형2로 분리하고, 연도·월·일자를 조합하여 날짜 컬럼을 생성하는 등 분석용 데이터를 추가 가공한다.
-- 적재 중 오류가 발생하면 오류 내용을 SYNC_ERR_INFO에 발생일시·데이터 유형·오류정보로 기록하고, 정상 처리 시 적재 결과 및 처리 건수를 반환한다.
-- CRT,CVR 속성의 경우, 제일 마지막 % 기호흫 떼고 -> 100으로 나눈 값을 저장한다.
-- CPA, 개발단가, 통합CPA, 통합개발단가 속성의 경우, 공백인 경우 0으로 치환하여 저장한다.
-- 그 외의 숫자속성열의 경우, 숫자로 변환 불가능 할 시에는 오류를 발생시킨다.


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
create or replace TABLE GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS (
	TIME VARCHAR(16777216) COMMENT '시간',
	YEAR VARCHAR(16777216) COMMENT '연도',
	BDGT_SOURCE_NM VARCHAR(16777216) COMMENT '예산출처',
	CMPGN_TYPE1_BSN_NM VARCHAR(16777216) COMMENT '캠페인유형1',
	CMPGN_TYPE2_BSN_NM VARCHAR(16777216) COMMENT '캠페인유형2',
	CMPGN_TYPE_BSN_NM VARCHAR(16777216) COMMENT '캠페인유형',
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
	AD_COST FLOAT COMMENT '광고비',
	SPNSER_MBER_CNT FLOAT COMMENT '후원자수(명)',
	CONV_VU_CNT FLOAT COMMENT '전환가치(건)',
	CPA FLOAT COMMENT 'CPA',
	DVLP_UNIT_PRICE FLOAT COMMENT '개발단가',
	CTR FLOAT COMMENT 'CTR',
	CVR FLOAT COMMENT 'CVR',
	CPC FLOAT COMMENT 'CPC',
	CPM FLOAT COMMENT 'CPM',
	UTM_CMPGN_NM VARCHAR(16777216) COMMENT 'utm_campaign',
	READ_CNT FLOAT COMMENT '조회수',
	MEDIA_PTNT_CUST_CNT FLOAT COMMENT '잠재고객수(매체)',
	DATE DATE COMMENT '날짜',
	VTR FLOAT COMMENT 'VTR',
	PAGE_TYPE_NM VARCHAR(16777216) COMMENT '지면구분',
	CRM_DVLP_CNT FLOAT COMMENT 'CRM개발건수',
	AD_GRP_NM VARCHAR(16777216) COMMENT '광고그룹',
	GRP_DIV_NM VARCHAR(16777216) COMMENT '그룹구분',
	MARKUP_AMT FLOAT COMMENT '마크업',
	VAT_AMT FLOAT COMMENT '부가세',
	LAST_STMT_AMT FLOAT COMMENT '최종정산금액',
	TOTAL_CPA FLOAT COMMENT '통합CPA',
	TOTAL_DVLP_UNIT_PRICE FLOAT COMMENT '통합개발단가'
)COMMENT='디지털 광고 성과 내역'
;


------------------------------------------------------------
-- [프로시저 본체] Google Sheets -> Snowflake 적재
------------------------------------------------------------
-- 261023 이소연 과장 요청
-- 숫자값 변환 로직. 
-- CRT,CVR: 백분율(%) 처리 후 숫자형식 적재
--  => 따라서, %제거 후, 나누기 100 하여 적재
 
-- CPA, 개발단가, 통합CPA, 통합개발단가: 수식 입력
-- => 형식 오류 다수 발생 (- 입력)
-- => 입력값 없을 시, ""처리 예정
-- => 공백인 경우 데이터 인입 NULL 처리. -> 0처리로 변경
-- 그 외 숫자값 영역값들이 숫자변환 안되는 경우 오류 

CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_DGT_AD_FROM_GSHEET(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'requests', 'pyjwt', 'cryptography')
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/gn_google_service_account.json')
EXTERNAL_ACCESS_INTEGRATIONS = (GOOGLE_API_ACCESS)
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
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
        table_name = 'DGT_AD_CMPGN_DTLS'
        # 구글 서비스 계정 인증 (JWT 방식)
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "gn_google_service_account.json")
        with open(sa_file_path, 'r') as f:
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

        target_file_found = False
        # 파일 목록 순회
        for file in files:
            file_id = file['id']
            file_name = file['name']
            logs.append(f"--- [파일명: {file_name}] (ID: {file_id}) ---")

            parts = file_name.split('_')
            if len(parts) < 2:
                logs.append(f"[-] 파일명 형식이 규칙에 맞지 않아 패스합니다. (구분자 '_' 부족)")
                continue

            file_type = parts[0].upper()
            file_yyyymm = parts[1]

            if input_yyyymm != file_yyyymm:
                logs.append(f"[-] 해당 월에 해당 안되는 파일 패스합니다. [파일명]: '{file_name}'")
                continue
            if file_type != 'DIGITAL':
                raise Exception(f"파라미터 오류 [파일명]: '{file_name}' / [대상년월 파라미터] : {input_yyyymm}")
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
                    raise Exception(f"Snowflake DB에 '{table_name}' 테이블이 없거나 컬럼 설정(메타데이터)이 존재하지 않습니다.")

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

            # 대상 월의 기존 데이터 삭제
            delete_query = f"DELETE FROM GN_DW.BRONZE_AGENCY.{table_name} WHERE TO_CHAR(DATE, 'YYYYMM') = '{input_yyyymm}'"
            delete_result = session.sql(delete_query).collect()
            deleted_cnt = delete_result[0][0] if delete_result else 0
            logs.append(f"기존 {input_yyyymm} 데이터 삭제 완료 ({deleted_cnt} 건 처리)")

            # 스프레드시트의 내부 탭(시트) 목록 조회
            sheets_list = sheets_get_metadata(access_token, file_id)

            for sheet in sheets_list:
                properties = sheet.get('properties', {})
                sheet_title = properties.get('title')

                if properties.get('hidden', False):
                    continue

                logs.append(f"  [탭 탐색] {sheet_title}")

                # 탭별 데이터 호출 (범위: B3부터 끝까지)
                range_str = f"'{sheet_title}'!B{HEADER_ROW_NUM}:ZZ"
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
                    #df[col] = df[col].apply(lambda x: "" if x.upper() in ['NULL', 'NAN'] else x)
                    #df[col] = df[col].apply(lambda x: "" if x.upper() in ['-', 'NULL', 'NAN'] else x)

                    if 'CHAR' in db_type or 'TEXT' in db_type:
                        df[col] = df[col].apply(lambda x: '' if x == "" else x)
                    elif any(num_type in db_type for num_type in ['INT', 'BIGINT', 'NUMBER', 'FLOAT', 'DECIMAL']):
                        df[col] = df[col].str.replace(',', '', regex=False)
                    
                        # CTR, CVR 컬럼에만 퍼센트 처리 적용
                        if col in ['CTR', 'CVR']:
                            df[col] = df[col].str.replace('%', '', regex=False)
                            # df[col] = df[col].apply(lambda x: '0' if x == "" else x)
                    
                            for idx, val in df[col].items():
                                try:
                                    df.at[idx, col] = float(val) / 100
                                except ValueError:
                                    raise Exception(
                                        f"데이터 형변환 에러 파일: '{file_name}' "
                                        f"-> 탭: '{sheet_title}' -> 행: [{idx}행] "
                                        f"[원인] '{col}' 속성에 잘못된 퍼센트 값('{val}')이 "
                                        f"입력되었습니다. (DB 타입: {db_type})"
                                    )
                        elif col in ['CPA', '개발단가', '통합CPA', '통합개발단가']:
                            df[col] = df[col].apply(lambda x: 0 if x == "" else x) 
                            df[col] = df[col].apply(lambda x: '0' if pandas.isna(x) or x == "" else x)
                            for idx, val in df[col].items():
                                try:
                                    if 'INT' in db_type:
                                        df.at[idx, col] = int(float(val))
                                    else:
                                        df.at[idx, col] = float(val)
                                except ValueError:
                                    raise Exception(
                                        f"데이터 형변환 에러 [위치] 파일: '{file_name}' "
                                        f"-> 탭: '{sheet_title}' -> 행: [{idx}행] "
                                        f"[원인] '{col}' 속성에 숫자가 아닌 값('{val}')이 "
                                        f"입력되었습니다. (DB 타입: {db_type})"
                                    )             
                        else:
                            # df[col] = df[col].apply(lambda x: '0' if x == "" else x) 
                            for idx, val in df[col].items():
                                try:
                                    if 'INT' in db_type:
                                        df.at[idx, col] = int(float(val))
                                    else:
                                        df.at[idx, col] = float(val)
                                except ValueError:
                                    raise Exception(
                                        f"데이터 형변환 에러 [위치] 파일: '{file_name}' "
                                        f"-> 탭: '{sheet_title}' -> 행: [{idx}행] "
                                        f"[원인] '{col}' 속성에 숫자가 아닌 값('{val}')이 "
                                        f"입력되었습니다. (DB 타입: {db_type})"
                                    )

                # CMPGN_TY_NM 컬럼 분리
                if '캠페인유형' in df.columns:
                    split_data = df['캠페인유형'].str.split(' ', n=1, expand=True)
                    df['캠페인유형1'] = split_data[0]
                    df['캠페인유형2'] = split_data[1] if len(split_data.columns) > 1 else ""

                # YEAR, MONTH, DAY 날짜 조합
                if all(col in df.columns for col in ['연도', '월', '일자']):
                    if '날짜' not in df.columns:
                        clean_year = df['연도'].astype(str).str.strip()
                        clean_month = df['월'].astype(str).str.strip().str.zfill(2)
                        clean_day = df['일자'].astype(str).str.strip().str.zfill(2)
                        df['날짜'] = clean_year + '-' + clean_month + '-' + clean_day

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
        if not target_file_found:
            raise Exception(
                f"대상 파일이 존재하지 않습니다. "
                f"[파일명: DIGITAL_{input_yyyymm}_*]"
            )
    except Exception as global_err:
        error_msg = str(global_err).replace("'", "''")
        logs.append(f"[ERROR] {global_err}")

        try:
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), '디지털', '{error_msg}')"
            session.sql(error_query).collect()
            logs.append("에러 로그 [SYNC_ERR_INFO]에 기록 완료.")
        except Exception as log_err:
            logs.append(f"에러 로그 DB 기록 실패: {log_err}")

        return "\n".join(logs)

    logs.append("[완료] 모든 데이터 적재가 정상적으로 완료되었습니다.")
    return "\n".join(logs)
$$;



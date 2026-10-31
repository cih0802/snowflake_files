-- SharePoint Excel 데이터를 Graph API로 읽어 Snowflake에 적재하는 기능
-- SharePoint에 저장된 재송출 광고 엑셀 데이터를 Microsoft Graph API로 조회·전처리하고, 컬럼 매핑 및 데이터 정제를 수행하여 REBRDC_AD_CMPGN_DTLS에 적재한다.
-- Microsoft Graph API를 통해 SharePoint 내 지정된 Excel 파일에 접근하고, 서비스 계정 정보를 이용하여 인증 토큰을 발급받는다.
-- 대상 Excel 파일의 워크시트를 조회하고, 1-1. 특집, 1-2. 재송출 시트만 선별하여 B6:V10000 범위의 데이터를 수집한다.
-- Snowflake 테이블 COMMENT를 기준으로 Excel의 한글 컬럼명을 대상 테이블 영문 컬럼명과 자동 매핑하고, DB에 정의되지 않은 컬럼 및 불필요한 컬럼은 제외한다.
-- 방송일자와 방송시간의 원천 데이터 형식을 정제하고, Excel 날짜·시간 형식 및 빈값 등을 Snowflake 적재에 적합한 형태로 변환한다.
-- 방송명과 방송일자가 없는 데이터를 제외하여 유효한 재송출 광고 데이터만 선별한다.
-- 적재 전 REBRDC_AD_CMPGN_DTLS의 기존 데이터를 삭제한 후, 대상 시트별 데이터를 write_pandas를 통해 일괄 적재한다.
-- 적재 과정에서 오류가 발생하면 SYNC_ERR_INFO에 발생일시, 데이터 유형(재송출), 오류정보를 기록하고 처리 결과를 반환한다.
-- MS_GRAPH_API_RULE 및 MS_GRAPH_ACCESS를 통해 login.microsoftonline.com, graph.microsoft.com에 대한 외부 API 접근을 허용한다.
-- 연동 파일 주소. https://gnikor.sharepoint.com/:x:/r/sites/fundraising2/_layouts/15/Doc.aspx?sourcedoc=%7BD1950F94-BEC9-4432-99B7-D33F18DCC291%7D&file=%25ub098%25ub214%25ub9c8%25ucf00%25ud305%25ubcf8%25ubd80%20%25ubaa8%25uae08%25ubc29%25uc1a1%20%25ud1b5%25ud569%20%25uad00%25ub9ac%20%25uc2dc%25ud2b8.xlsx&action=default&mobileredirect=true
------------------------------------------------------------
-- 1. 스키마 생성
------------------------------------------------------------
CREATE SCHEMA GN_DW.BRONZE_AGENCY;

------------------------------------------------------------
-- 2 내부 스테이지 생성 및 json 파일 업로드
-- msSharePointInfo.json 은 박종찬 팀장에게 전달받은 정보임. 
------------------------------------------------------------
CREATE STAGE GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

------------------------------------------------------------
-- 3 Network Rule 생성
------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE GN_DW.BRONZE_AGENCY.MS_GRAPH_API_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('login.microsoftonline.com', 'graph.microsoft.com');

------------------------------------------------------------
-- 4. External Access Integration 생성
------------------------------------------------------------
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION MS_GRAPH_ACCESS
    ALLOWED_NETWORK_RULES = (GN_DW.BRONZE_AGENCY.MS_GRAPH_API_RULE)
    ENABLED = TRUE;

------------------------------------------------------------
-- 5. 결과저장 테이블 생성
------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS (
	DIV_NM VARCHAR(16777216) COMMENT '구분',
	YEAR VARCHAR(16777216) COMMENT '연도',
	MONTH VARCHAR(16777216) COMMENT '월',
	DAY VARCHAR(16777216) COMMENT '일',
	CHNNL_NM VARCHAR(16777216) COMMENT '채널',
	BRDC_DATE DATE COMMENT '방송일자',
	DOW VARCHAR(16777216) COMMENT '요일',
	WEEK VARCHAR(16777216) COMMENT '주차',
	BRDC_TIME VARCHAR(16777216) COMMENT '방송시간',
	BRDC_NM VARCHAR(16777216) COMMENT '방송명',
	BRDC_DIV_NM VARCHAR(16777216) COMMENT '방송구분',
	AD_CNT FLOAT COMMENT '횟수',
	INBOUND_CALL_CNT VARCHAR(16777216) COMMENT '인입콜',
	DVLP_MBER_CNT FLOAT COMMENT '개발(명)',
	DVLP_CNT FLOAT COMMENT '개발(건)',
	UPPER_CMPGN_CD VARCHAR(16777216) COMMENT '상위캠페인코드',
	MKTG_CMPGN_NM VARCHAR(16777216) COMMENT '마케팅캠페인명',
	BRDC_SCHDL_COST FLOAT COMMENT '편성비',
	CONTENTS_PUR_COST FLOAT COMMENT '콘텐츠구입비',
	CALL_CTR_OPER_COST FLOAT COMMENT '콜센터운영비',
	TOT_COST FLOAT COMMENT '총비용'
)COMMENT='재송출 광고 성과 내역'
;

-- =============================================================================
-- [프로시저 본체] MS SharePoint -> Snowflake 적재
-- =============================================================================
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_AGENCY.SP_LOAD_REBRDC_FROM_SHAREPOINT()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'requests')
IMPORTS = ('@GN_DW.BRONZE_AGENCY.CREDENTIALS_STAGE/msSharePointInfo.json')
EXTERNAL_ACCESS_INTEGRATIONS = (MS_GRAPH_ACCESS)
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
import os
import sys
import json
import pandas as pd
import requests

def main(session):
    log_messages = []
    table_name = 'REBRDC_AD_CMPGN_DTLS'

    try:
        # 설정 정보
        import_dir = sys._xoptions.get("snowflake_import_directory", "/tmp")
        sa_file_path = os.path.join(import_dir, "msSharePointInfo.json")
        with open(sa_file_path, 'r') as f:
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
            raise Exception(f"토큰 획득 실패 - {token_res}")

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
            WHERE TABLE_SCHEMA = 'BRONZE_AGENCY'
              AND TABLE_NAME = '{table_name}'
            ORDER BY ORDINAL_POSITION
        """
        db_rows = session.sql(metadata_query).collect()
        if not db_rows:
            raise Exception(f"'{table_name}' 테이블 메타데이터 없음")

        comment_to_eng_map = {
            row["COMMENT"].strip().replace("\n", "").replace(" ", "").upper(): row["COLUMN_NAME"].strip().upper()
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
        TARGET_SHEET_NAMES = ["1-1. 특집", "1-2. 재송출"]

        for sheet in worksheets:
            sheet_name = sheet.get("name")

            if sheet_name not in TARGET_SHEET_NAMES:
                continue

            TARGET_RANGE = "B6:V10000"

            data_res = requests.get(
                f"https://graph.microsoft.com/v1.0/sites/{SITE_ID}/drive/items/{ITEM_ID}/workbook/worksheets/{sheet_name}/range(address='{TARGET_RANGE}')",
                headers=headers,
            )

            if data_res.status_code != 200:
                log_messages.append(f"[-] '{sheet_name}' 데이터 조회 실패")
                continue

            all_rows = data_res.json().get("values", [])
            if not all_rows or len(all_rows) <= 1:
                log_messages.append(f"[-] '{sheet_name}' 데이터 없음")
                continue

            # DataFrame 변환
            header_cols = all_rows[0]
            data_rows = all_rows[1:]
            df = pd.DataFrame(data_rows, columns=header_cols)
            df = df.replace(r"^\s*$", None, regex=True).infer_objects(copy=False)
            df = df[df["방송명"].astype(str).str.strip() != ""]
            df = df[df["방송일자"].notna()]

            if df.empty:
                log_messages.append(f"[-] '{sheet_name}' 유효 데이터 없음")
                continue

            # 컬럼 정제
            columns_to_drop = []
            renamed_columns_map = {}

            for col in df.columns:
                col_str = str(col).strip()
                if "Unnamed:" in col_str:
                    columns_to_drop.append(col)
                    continue
                clean_col = col_str.replace("\n", "").replace(" ", "").strip().upper()

                if col_str == "방송시간":
                    cleaned_values = []
                    for val in df[col]:
                        if pd.isnull(val) or val is None:
                            cleaned_values.append(None)
                        elif type(val).__name__ in ['time', 'datetime', 'date']:
                            cleaned_values.append(val.strftime('%H:%M:%S'))
                        else:
                            val_str = str(val).strip()
                            if val_str.replace('.', '', 1).isdigit():
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
                            if val_str in [0, 1, '0', '1']:
                                val_str = "00:00:00" if val_str in [0, '0'] else "24:00:00"
                            cleaned_values.append(val_str)
                    df[col] = cleaned_values

                elif col_str == "방송일자":
                    cleaned_dates = []
                    for val in df[col]:
                        if pd.isnull(val) or val is None:
                            cleaned_dates.append(None)
                        elif type(val).__name__ in ['datetime', 'date']:
                            cleaned_dates.append(val.strftime('%Y-%m-%d'))
                        else:
                            val_str = str(val).strip()
                            if val_str.replace('.0', '', 1).isdigit():
                                try:
                                    excel_date = pd.to_datetime(float(val_str), unit='D', origin='1899-12-30')
                                    val_str = excel_date.strftime('%Y-%m-%d')
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
            df.rename(columns=comment_to_eng_map, inplace=True)

            if 'INBOUND_CALL_CNT' in df.columns:
                df['INBOUND_CALL_CNT'] = df['INBOUND_CALL_CNT'].fillna('').astype(str)
                df['INBOUND_CALL_CNT'] = df['INBOUND_CALL_CNT'].apply(
                    lambda x: None if x in ['', 'None', 'NaN'] else x
                )

            # Snowflake 적재
            session.write_pandas(
                df=df,
                table_name=table_name,
                database="GN_DW",
                schema="BRONZE_AGENCY",
                overwrite=False
            )
            log_messages.append(f"[+] '{sheet_name}' {len(df)}건 적재 완료")

    except Exception as global_err:
        try:
            error_msg = str(global_err).replace("'", "''")
            error_query = f"INSERT INTO GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (ERR_DATETIME, DATA_TYPE, ERR_INFO) VALUES (CURRENT_TIMESTAMP(), '재송출', '{error_msg}')"
            session.sql(error_query).collect()
        except:
            # pass
            return (
                f"ERROR: {error_msg} "
                f"| 로그 기록 실패: {str(log_err)}"
            )
        return f"ERROR: {str(global_err)}"

    if not log_messages:
        return "처리 결과 없음"
    return "\n".join(log_messages)
$$;



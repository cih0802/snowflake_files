# MSTR 이관 도구 공통 설정 — 경로 · 연결 · 원본 파서 (15_MSTR 이관 PoC/tools 안에서만 완결)
import io, os, re

TOOLS = os.path.dirname(os.path.abspath(__file__))
POC = os.path.dirname(TOOLS)
SRC = os.path.join(POC, 'mstr DDL 원본')                    # 원본 4종(UTF-16LE · 읽기 전용)
SRC_FILES = {
    'TABLE': 'table_script.sql',
    'VIEW': 'view_script.sql',
    'PROCEDURE': 'sp_script.sql',
    'FUNCTION': 'function_script.sql',
}
OUT_DDL = os.path.join(POC, 'snowflake 적용 ddl')
TEMPLATES = os.path.join(TOOLS, 'templates')

TARGET_DB = 'GN_DW'
TARGET_SCHEMA = 'MSTR'
SOURCE_SCHEMA = 'BRONZE_CRM'                                # MSTR_ODS.DBO.<T> → GN_DW.BRONZE_CRM.<T>


def conn(role='ACCOUNTADMIN', warehouse='COMPUTE_WH'):
    import snowflake.connector
    tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
    return snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
        token=tok, authenticator='oauth', role=role, warehouse=warehouse,
        database=TARGET_DB, client_session_keep_alive=True)


def read_src(kind):
    p = os.path.join(SRC, SRC_FILES[kind])
    return io.open(p, encoding='utf-16').read().replace('\r\n', '\n')


def parse_blocks(kind):
    """원본 파일 → {객체명(대문자): (schema, 원문 블록)} · 블록 = CREATE 부터 첫 GO 까지"""
    text = read_src(kind)
    starts = [m.start() for m in re.finditer(r'(?im)^CREATE\s+(?:TABLE|VIEW|PROCEDURE|PROC|FUNCTION)\b', text)]
    starts.append(len(text))
    out = {}
    for s, e in zip(starts, starts[1:]):
        b = text[s:e]
        m = re.match(r'CREATE\s+\w+\s+(?:\[?(\w+)\]?\.)?\[?(\w+)\]?', b, re.I)
        g = re.search(r'(?im)^GO\s*$', b)
        if g:
            b = b[:g.end()]
        out[m.group(2).upper()] = ((m.group(1) or '').upper(), b.strip())
    return out


def load_all():
    return {k: parse_blocks(k) for k in SRC_FILES}

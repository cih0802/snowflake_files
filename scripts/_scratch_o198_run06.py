"""O198 임시 실행기 — sfconn 연결로 Snowpark 세션을 만들어 06 생성기를 돌린다(생성기 무수정)."""
import os, runpy, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/tmp")
from sfconn import conn
from snowflake.snowpark import Session

Session.builder.configs({"connection": conn()}).create()
sys.argv = ["gen_bronze_exposure_audit.py"]
runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_bronze_exposure_audit.py"),
               run_name="__main__")

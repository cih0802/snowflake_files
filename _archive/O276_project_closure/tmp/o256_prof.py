import os
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
os.makedirs("/tmp/o256prof", exist_ok=True)
y = f"""default:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "sr61467.eu-central-1"
      user: "TRIALADMIN"
      authenticator: oauth
      token: "{tok}"
      role: GN_DW_DBT
      database: GN_DW
      warehouse: GN_DW_ETL_WH
      schema: SILVER
      threads: 4
"""
open("/tmp/o256prof/profiles.yml", "w").write(y)
os.chmod("/tmp/o256prof/profiles.yml", 0o600)
print("ok")

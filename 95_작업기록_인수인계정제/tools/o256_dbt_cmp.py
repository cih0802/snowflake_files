"""O256 — dbt parse/compile 대조 실행기(현재본 vs 변경 전 기준선 · 로컬 /tmp 에서).
로그·요약 = /workspace/tmp/o256/ (토큰 프로필은 /tmp 에만 둔다)."""
import os, shutil, subprocess, sys
W = "/workspace/"
S = W + "10_dbt_pipeline"; B = W + "95_작업기록_인수인계정제/_backup_O256_원본_20261021/10_dbt_pipeline"
LOG = W + "tmp/o256/"
os.makedirs(LOG, exist_ok=True)
IGN = shutil.ignore_patterns("target", "logs", "dbt_packages", "_archive", "__pycache__", "profiles.yml")
for d in ("/tmp/new", "/tmp/base"):
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(S, d, ignore=IGN, copy_function=shutil.copyfile)
n = 0
for d, _, fs in os.walk(B):
    for f in fs:
        src = os.path.join(d, f); shutil.copyfile(src, os.path.join("/tmp/base", os.path.relpath(src, B))); n += 1
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
os.makedirs("/tmp/o256prof", exist_ok=True)
open("/tmp/o256prof/profiles.yml", "w").write(
    "default:\n  target: dev\n  outputs:\n    dev:\n      type: snowflake\n"
    '      account: "sr61467.eu-central-1"\n      user: "TRIALADMIN"\n      authenticator: oauth\n'
    f'      token: "{tok}"\n      role: GN_DW_DBT\n      database: GN_DW\n      warehouse: GN_DW_ETL_WH\n'
    "      schema: SILVER\n      threads: 4\n")
os.chmod("/tmp/o256prof/profiles.yml", 0o600)
summary = [f"restored {n}"]
for name in ("new", "base"):
    for cmd in ("parse", "compile"):
        r = subprocess.run(["dbt", cmd, "--profiles-dir", "/tmp/o256prof"], cwd="/tmp/" + name,
                           stdin=subprocess.DEVNULL, capture_output=True, text=True)
        open(f"{LOG}{name}_{cmd}.log", "w").write(r.stdout[-200000:] + "\n--STDERR--\n" + r.stderr[-50000:])
        summary.append(f"{name} {cmd} rc={r.returncode}")
        print(summary[-1], flush=True)
open(LOG + "dbt_summary.txt", "w").write("\n".join(summary) + "\n")

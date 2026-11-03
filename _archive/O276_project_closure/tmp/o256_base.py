import os, shutil
S = "/workspace/10_dbt_pipeline"; B = "/workspace/95_작업기록_인수인계정제/_backup_O256_원본_20261021/10_dbt_pipeline"
D = "/tmp/base"
shutil.rmtree(D, ignore_errors=True)
shutil.copytree(S, D, ignore=shutil.ignore_patterns("target", "logs", "dbt_packages", "_archive", "__pycache__"), copy_function=shutil.copyfile)
n = 0
for d, _, fs in os.walk(B):
    for f in fs:
        src = os.path.join(d, f); dst = os.path.join(D, os.path.relpath(src, B))
        shutil.copyfile(src, dst); n += 1
print("restored", n)

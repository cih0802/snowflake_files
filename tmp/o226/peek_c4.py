import io
for p, ln in [('10_dbt_pipeline/models/gold/wide/_wide_schema.yml', 220), ('10_dbt_pipeline/models/gold/wide/_wide_schema.yml', 606)]:
    print(p, ln, '|', io.open('/workspace/' + p, encoding='utf-8').read().splitlines()[ln - 1].strip())
for p, tok in [('05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql', '840,471')]:
    for i, l in enumerate(io.open('/workspace/' + p, encoding='utf-8').read().splitlines(), 1):
        if tok in l:
            print(p, i, '|', l.strip()[:700])

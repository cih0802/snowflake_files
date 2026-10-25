"""O261 · 「값 N종」 변형 종 수 표기 제거(1차 치환은 「실제값 N종」만 다뤘다). 값 자체·문장은 그대로 두고 「N종」만 뺀다."""
import io, glob, re, sys
APPLY = '--apply' in sys.argv
PAT = re.compile(r"(값)\s*[0-9]+\s*종")
files = sorted(glob.glob('/workspace/05_SV-Agent_ai/*.sql')) + ['/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
tot = 0
for f in files:
    t = io.open(f, encoding='utf-8').read()
    # SQL 주석 줄(-- …)은 이력 기록이므로 건드리지 않는다 — 문자열(COMMENT) 안만 대상
    out, n = [], 0
    for line in t.split('\n'):
        if line.lstrip().startswith('--'):
            out.append(line)
            continue
        new, k = PAT.subn(r'\1', line)
        out.append(new)
        n += k
    if n:
        tot += n
        print(f.split('/')[-1], n)
        if APPLY:
            io.open(f, 'w', encoding='utf-8').write('\n'.join(out))
print('합계', tot, 'APPLY' if APPLY else 'DRY-RUN')

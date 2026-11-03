"""O261 · 34_(O246-D 폴백 각주)의 SV_ML 3종 COMMENT 를 정본 22_·25_ 로 이식 — 신규 구축 순서(1~59)에 34 가 없어 각주가 빠지던 결함.
사용: python3 port_34.py [--apply]   · 이식 대상 = 34 와 COMMENT 가 다른 차원·지표만(이름 집합 동일 확인 후)
"""
import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from run_sql_file import parse_statements

APPLY = '--apply' in sys.argv
SVN = re.compile(r'SEMANTIC\s+VIEW\s+GN_DW\.\w+\.(\w+)', re.I)
IT = r"(\w+\.%s\s+AS\s+(?:(?!\bCOMMENT\b)(?!,\s*\w+\.\w+\s+AS\b)[^;])*?COMMENT\s*=\s*')((?:[^']|'')*)(')"


def raw_svs(text):
    """SV 이름 → 원문 안 (시작, 끝) 범위(CREATE … SEMANTIC VIEW 문)."""
    out = {}
    for m in re.finditer(r'CREATE\s+OR\s+(?:ALTER|REPLACE)\s+SEMANTIC\s+VIEW\s+GN_DW\.\w+\.(\w+)', text, re.I):
        end = text.find(';\n', m.end())
        out[m.group(1).upper()] = (m.start(), end if end > 0 else len(text))
    return out


def comments(seg):
    return {m.group(1).split('.')[1].split()[0].upper(): m.group(2)
            for m in re.finditer(IT % r'\w+', seg, re.I | re.S)}


src = io.open('/workspace/05_SV-Agent_ai/34_DEPLOY_SV_ML_FALLBACK_NOTE.sql', encoding='utf-8').read()
src_sv = raw_svs(src)
total = 0
for f in ('22_ML_SV_DDL.sql', '25_ML_CHURN_CMPGN_CTGR_DDL.sql'):
    p = '/workspace/05_SV-Agent_ai/' + f
    text = io.open(p, encoding='utf-8').read()
    n = 0
    for sv, (a, b) in sorted(raw_svs(text).items(), key=lambda x: -x[1][0]):   # 뒤에서부터 치환(좌표 보존)
        if sv not in src_sv:
            continue
        ca = comments(src[src_sv[sv][0]:src_sv[sv][1]])
        seg = text[a:b]
        cb = comments(seg)
        assert set(ca) == set(cb), (f, sv, set(ca) ^ set(cb))
        for name in [k for k in cb if cb[k] != ca[k]]:
            m = re.search(IT % re.escape(name), seg, re.I | re.S)
            seg = seg[:m.start(2)] + ca[name] + seg[m.end(2):]
            print(f, sv, name)
            n += 1
        text = text[:a] + seg + text[b:]
    total += n
    if APPLY and n:
        io.open(p, 'w', encoding='utf-8').write(text)
print('이식', total, '· APPLY' if APPLY else '· DRY-RUN')

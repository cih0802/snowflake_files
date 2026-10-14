# O224 P3a — 「계산 전 확인」 규칙 위치(블록별) + 로컬↔라이브 diff 요약(읽기 전용)
import io, json, re, sys, difflib
import yaml
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
PAT = re.compile(r'사전에 정해진 산식|산식이 없|계산할까요|미정의 지표')
for ag in ['AGENT_MARKETING', 'AGENT_EXECUTIVE', 'AGENT_MEMBER']:
    c.execute(f'DESCRIBE AGENT GN_DW.SERVING.{ag}')
    cols = [d[0] for d in c.description]
    live = json.loads(c.fetchone()[cols.index('agent_spec')])
    loc = yaml.safe_load(io.open(f'/workspace/cortex_project/agents/{ag}/agent_spec.yaml', encoding='utf-8'))
    for name, sp in (('live', live), ('local', loc)):
        ins = sp.get('instructions', {})
        pos = {k: [m.start() for m in PAT.finditer(v or '')][:3] for k, v in ins.items() if isinstance(v, str)}
        print(ag, name, 'len', {k: len(v) for k, v in ins.items() if isinstance(v, str)}, '| 계산전확인 위치', pos)
    for k in ('orchestration', 'response', 'system'):
        a, b = live['instructions'].get(k, ''), loc['instructions'].get(k, '')
        if a != b:
            sm = difflib.SequenceMatcher(None, a, b)
            ch = [(op, a[i1:i2][:120], b[j1:j2][:200]) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != 'equal']
            print('  diff', k, len(ch), ch[:3])
    lt = {t['tool_spec']['name'] for t in live['tools']}
    ot = {t['tool_spec']['name'] for t in loc['tools']}
    print('  tools live-only', lt - ot, 'local-only', ot - lt)
    ld = {t['tool_spec']['name']: t['tool_spec'].get('description') for t in live['tools']}
    od = {t['tool_spec']['name']: t['tool_spec'].get('description') for t in loc['tools']}
    print('  tool desc diff', [n for n in ld if n in od and ld[n] != od[n]])

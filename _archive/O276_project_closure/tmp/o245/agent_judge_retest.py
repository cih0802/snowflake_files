# O245 — Agent 응답 재판정: 최종 결과표(content.table) · 실행 SQL(tool_use.input) · 도구 오류(tool_result status) 추출
#   → tmp/o245/agent_test/_judge.md (질문 · 실행 SQL · 결과표 앞 8행 · 기대값 · 최종 답변 말미)
import io, json, glob, os
OUT = '/workspace/tmp/o245/agent_test_retest'
exp = json.load(io.open(OUT + '/_expected.json', encoding='utf-8'))
summ = {r['tag']: r for r in json.load(io.open(OUT + '/_summary.json', encoding='utf-8'))}
sys_path = __import__('sys').path
sys_path.insert(0, '/workspace/tmp/o245')
import agent_test as T
Q = {q[0]: q for q in T.Q}
md = io.open(OUT + '/_judge.md', 'w', encoding='utf-8')
for tag in ['C1','M4','M5']:
    j = json.loads(io.open('%s/%s.txt' % (OUT, tag), encoding='utf-8').read())
    sqls, tables, errs, tools, texts = [], [], [], [], []
    for c in j.get('content', []):
        t = c.get('type')
        if t == 'tool_use':
            tu = c['tool_use']
            tools.append(tu.get('name'))
            inp = tu.get('input') or {}
            for k in ('sql', 'query'):
                if isinstance(inp.get(k), str):
                    sqls.append(inp[k])
        elif t == 'tool_result':
            tr = c['tool_result']
            st = tr.get('status')
            for cc in tr.get('content', []):
                js = cc.get('json') or {}
                if isinstance(js, dict):
                    if js.get('sql'):
                        sqls.append(js['sql'])
                    e = js.get('error') or js.get('message') if st == 'error' or js.get('error') else None
                    if e:
                        errs.append(str(e)[:200])
            if st and st != 'success':
                errs.append('status=%s' % st)
        elif t == 'table':
            rs = c['table'].get('result_set', {})
            names = [x['name'] for x in rs.get('resultSetMetaData', {}).get('rowType', [])]
            tables.append((names, rs.get('data', [])[:8]))
        elif t == 'text':
            texts.append(c.get('text', ''))
    q = Q[tag]
    md.write('## %s · %s\n- 질문: %s\n- 도구: %s\n- 도구 오류: %s\n' % (tag, q[1], q[2], ', '.join(t for t in tools if t), errs or '0'))
    for s in sqls[-2:]:
        md.write('- SQL: `%s`\n' % ' '.join(s.split())[:700])
    for names, data in tables[-2:]:
        md.write('- 결과표: %s\n' % ' | '.join(names))
        for r in data:
            md.write('  - %s\n' % ' | '.join(str(x) for x in r))
    md.write('- 기대값: %s\n' % (str(exp.get(tag))[:500] if tag in exp else '(데이터 없음 응답)'))
    md.write('- 최종 답변(말미 600자): %s\n\n' % ' '.join('\n'.join(texts).split())[-600:])
md.close()
print('ok')

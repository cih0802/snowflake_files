#!/usr/bin/env python3
"""NL 라우팅 스모크 러너 (착수표 ㉗) — 3종 Agent × sample_questions 전량.

🔴 판정 축 = ㉠ 라우팅(질문 → 어떤 도구/SV 로 갔는가) ㉡ SQL 생성 여부·행수 ㉢ 오류.
🔴 응답 원문은 tmp/nlsmoke/ 로 흘린다 — 세션 컨텍스트에 적재하지 않는다(비용 축).
🔴 호출 형식 = DATA_AGENT_RUN(agent, 요청 JSON) — 질문 문자열을 그대로 넘기면 malformed.
"""
import io, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tmp', 'nlsmoke')
SPECS = {
    'AGENT_MEMBER':    'cortex_project/agents/AGENT_MEMBER/agent_spec.yaml',
    'AGENT_MARKETING': 'cortex_project/agents/AGENT_MARKETING/agent_spec.yaml',
    'AGENT_EXECUTIVE': 'cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml',
}

def questions(path):
    L = io.open(os.path.join(ROOT, path), encoding='utf-8').read().splitlines()
    out, on = [], False
    for l in L:
        s = l.strip()
        if s.startswith('sample_questions:'):
            on = True; continue
        if on:
            m = re.match(r'^-\s*question:\s*(.+)$', s)
            if m:
                out.append(m.group(1).strip()); continue
            if s and not s.startswith('#') and not s.startswith('-'):
                break
    return out

def digest(raw):
    """응답에서 도구·SV·SQL·행수를 뽑는다. 구조를 모르면 문자열로 훑는다."""
    txt = raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False)
    tools = sorted(set(re.findall(r'"(?:tool_name|name)"\s*:\s*"([A-Za-z0-9_]+)"', txt)))
    svs = sorted(set(re.findall(r'\b(SV_[A-Z0-9_]+)\b', txt)))
    tabs = sorted(set(re.findall(r'\b(?:GOLD|SERVING|ML)\.([A-Z0-9_]+)\b', txt)))
    sql = bool(re.search(r'"sql"\s*:\s*"', txt)) or bool(re.search(r'\bselect\b.+\bfrom\b', txt, re.I))
    err = re.findall(r'"(?:error|message)"\s*:\s*"([^"]{0,160})"', txt)
    return dict(tools=tools, svs=svs, tables=tabs, sql=sql, errors=err[:3], bytes=len(txt))

def main():
    os.makedirs(OUT, exist_ok=True)
    cn = conn(); cur = cn.cursor()
    rows = []
    for agent, spec in SPECS.items():
        qs = questions(spec)
        for i, qtext in enumerate(qs, 1):
            req = json.dumps({"messages": [{"role": "user",
                  "content": [{"type": "text", "text": qtext}]}]}, ensure_ascii=False)
            tag = f'{agent}_{i:02d}'
            t0 = time.time()
            try:
                cur.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)",
                            (f'GN_DW.SERVING.{agent}', req))
                raw = cur.fetchall()[0][0]
                ok = True
            except Exception as e:
                raw = f'__CALL_FAILED__ {type(e).__name__}: {e}'
                ok = False
            dt = time.time() - t0
            io.open(os.path.join(OUT, tag + '.txt'), 'w', encoding='utf-8').write(
                str(raw) if not isinstance(raw, str) else raw)
            d = digest(raw) if ok else dict(tools=[], svs=[], tables=[], sql=False,
                                            errors=[raw[:160]], bytes=len(raw))
            d.update(agent=agent, n=i, q=qtext, ok=ok, sec=round(dt, 1))
            rows.append(d)
            print(f'{tag} ok={ok} {dt:5.1f}s B={d["bytes"]:>7} sql={d["sql"]} '
                  f'sv={",".join(d["svs"])[:60]} tab={",".join(d["tables"])[:70]} '
                  f'err={d["errors"][:1]}', flush=True)
    cn.close()
    json.dump(rows, io.open(os.path.join(OUT, '_summary.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    n = len(rows); okn = sum(1 for r in rows if r['ok']); sq = sum(1 for r in rows if r['sql'])
    print(f'\n총 {n}문항 · 호출성공 {okn} · SQL생성 {sq} · 실패 {n-okn}')

if __name__ == '__main__':
    main()

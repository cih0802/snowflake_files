# O224 — 표적 스모크(DATA_AGENT_RUN · 지정 문항만 · 원문은 tmp/o224/smoke_<tag>/ 로) · 🔴 과금(LLM 호출)
# 사용: python3 tmp/o224_smoke.py <AGENT> <tag> <QID|"질문 원문"> [...]
#   QID 는 EVAL_O224_<AGENT>_V3 의 QUESTION_ID 로 질문을 찾는다 · 따옴표 원문은 그대로 묻는다
# 판정 보조(사람이 원문을 본다) = 호출 도구 · 「계산할까요/산식이 없」 확인 문구 · 거절 문구 · 응답 앞 300자
# Co-authored with CoCo
import io, json, os, re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

agent, tag, items = sys.argv[1], sys.argv[2], sys.argv[3:]
out = f'/workspace/tmp/o224/smoke_{tag}'
os.makedirs(out, exist_ok=True)
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
CONF = re.compile(r'계산할까요|산식이 없|진행할까요|알려 주세요|알려주세요|정해 주시면|확인해 주세요')
REFUSE = re.compile(r'답변할 수 없|산출할 수 없|차단|결합할 수 없|직접 뽑을 수 없')
for i, it in enumerate(items, 1):
    if re.fullmatch(r'[A-Z]\d{2}', it):
        c.execute(f'SELECT INPUT_QUERY FROM GN_DW.SERVING.EVAL_O224_{agent}_V3 WHERE QUESTION_ID = %s', (it,))
        q, qid = c.fetchone()[0], it
    else:
        q, qid = it, f'X{i:02d}'
    req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    t0 = time.time()
    try:
        c.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', (f'GN_DW.SERVING.{agent}', req))
        raw = c.fetchall()[0][0]
    except Exception as e:  # noqa: BLE001
        raw = f'__CALL_FAILED__ {e}'
    dt = time.time() - t0
    io.open(f'{out}/{qid}.json', 'w', encoding='utf-8').write(raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False))
    txt = raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False)
    try:
        js = json.loads(txt)
        cont = js.get('content', [])
        tools = [x.get('tool_use', {}).get('name') for x in cont if x.get('type') == 'tool_use']
        body = ' '.join(x.get('text', '') for x in cont if x.get('type') == 'text')
    except Exception:  # noqa: BLE001
        tools, body = re.findall(r'"name"\s*:\s*"(analyst_[a-z0-9_]+|search_biz_definition|data_to_chart)"', txt), txt
    body = re.sub(r'\s+', ' ', body)
    print(f'{qid} {dt:5.1f}s tools={tools} 확인={bool(CONF.search(body))} 거절={bool(REFUSE.search(body))} | {body[:300]}', flush=True)

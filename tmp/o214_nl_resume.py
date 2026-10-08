#!/usr/bin/env python3
"""O214 — nl_routing_smoke 재개 러너. 같은 세션(2026-10-08 17:00 UTC 이후)에 이미 받은 응답 파일은 재사용하고
나머지만 호출한다(샌드박스 재시작으로 1차 실행이 MARKETING_12 이후 중단 · 재과금 방지).
판정 = 원 스크립트 judge() 그대로 · _summary.json 은 전 문항으로 다시 쓴다.
사용: python3 tmp/o214_nl_resume.py --apply
Co-authored with CoCo
"""
import datetime
import io
import json
import os
import sys
import time

sys.path.insert(0, '/workspace/scripts')
import nl_routing_smoke as s  # noqa: E402
from mutating_guard import require_apply  # noqa: E402

CUT = datetime.datetime(2026, 10, 8, 17, 0, tzinfo=datetime.timezone.utc).timestamp()
require_apply(__file__, 'NL 스모크 재개 — 🔴 LLM 호출(과금 · 미수신 문항만)')
cn = s.conn()
cur = cn.cursor()
rows, reused, called = [], 0, 0
for agent, spec in s.SPECS.items():
    for i, qtext in enumerate(s.questions(spec), 1):
        tag = f'{agent}_{i:02d}'
        p = os.path.join(s.OUT, tag + '.txt')
        if os.path.exists(p) and os.path.getmtime(p) >= CUT:
            raw = io.open(p, encoding='utf-8').read()
            ok = not raw.startswith('__CALL_FAILED__')
            dt = None
            reused += 1
        else:
            req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": qtext}]}]},
                             ensure_ascii=False)
            t0 = time.time()
            try:
                cur.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", (f'GN_DW.SERVING.{agent}', req))
                raw = cur.fetchall()[0][0]
                ok = True
            except Exception as e:  # noqa: BLE001
                raw = f'__CALL_FAILED__ {type(e).__name__}: {e}'
                ok = False
            dt = round(time.time() - t0, 1)
            io.open(p, 'w', encoding='utf-8').write(raw if isinstance(raw, str) else str(raw))
            called += 1
        d = s.digest(raw) if ok else dict(tools=[], svs=[], tables=[], sql=False, errors=[raw[:160]], bytes=len(raw))
        d.update(agent=agent, n=i, q=qtext, ok=ok, sec=dt)
        rows.append(d)
        print(f'{tag} ok={ok} reuse={dt is None} sv={",".join(d["svs"])[:60]} err={d["errors"][:1]}', flush=True)
cn.close()
json.dump(rows, io.open(os.path.join(s.OUT, '_summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
n = len(rows)
print(f'\n총 {n}문항 · 재사용 {reused} · 신규 호출 {called} · 호출성공 {sum(r["ok"] for r in rows)} · SQL생성 {sum(r["sql"] for r in rows)}')
sys.exit(s.judge(rows))

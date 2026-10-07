#!/usr/bin/env python3
"""NL 라우팅 스모크 러너 (착수표 ㉗) — Agent 4종(🆕 O201 · MSTR 편입) × sample_questions 전량.

🔴 판정 축 = ㉠ 라우팅(질문 → 어떤 도구/SV 로 갔는가) ㉡ SQL 생성 여부·행수 ㉢ 오류.
🔴 응답 원문은 tmp/nlsmoke/ 로 흘린다 — 세션 컨텍스트에 적재하지 않는다(비용 축).
🔴 호출 형식 = DATA_AGENT_RUN(agent, 요청 JSON) — 질문 문자열을 그대로 넘기면 malformed.
"""
import io, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn
# 🔴 [O181 · I2] MUTATES 무플래그 집행 차단 가드 (경로는 위 `sys.path.insert` 로 이미 확보)
from mutating_guard import require_apply  # noqa: E402  🔴 `--apply` 없으면 드라이런 종료

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tmp', 'nlsmoke')
SPECS = {
    'AGENT_MEMBER':    'cortex_project/agents/AGENT_MEMBER/agent_spec.yaml',
    'AGENT_MARKETING': 'cortex_project/agents/AGENT_MARKETING/agent_spec.yaml',
    'AGENT_EXECUTIVE': 'cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml',
    # 🔴 [O207-C] AGENT_MSTR 은퇴(DROP · 스펙 파일 삭제) — 항목 제거
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
    require_apply(__file__, 'Agent 4종 NL 스모크 — 🔴 LLM 대량 호출(크레딧 과금)')
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
    sys.exit(judge(rows))


def judge(rows):
    """🔴 [2026-09-29 O189 · D안 ㉢] 「중간 오류 0」 판정 축.
    종전에는 호출 성공(ok)만 셌다 — Agent 가 invalid identifier·syntax error 를 내고 **스스로 재시도해
    최종 답을 낸 문항**도 PASS 였다(O188-E 실측 13문항). 자동 복구는 비용·지연·오답 위험이므로
    **중간 SQL 오류가 1건이라도 있으면 FAIL** 로 본다. 판정 대상 = digest 의 `errors` 중 SQL 오류 문구.
    🆕 [2026-09-30 O190 · 사용자 결정 「추천안 1ⓒ」] 판정을 **두 축으로 분리**한다.
      ① 최종 응답 축(blocking) = 호출 실패 0.
      ② 중간 오류 축(추이) = 기준선(`_baseline.json`) 대비 **증가하면 FAIL** · 같거나 줄면 PASS(개선 과제로 추적).
      🔴 `--strict` = 종전 판정(중간 오류 0 이어야 PASS) · 기준선 갱신 = `--set-baseline`(판정 후 현재 수를 기록).
      🔴 기준선이 없으면 ② 는 종전처럼 「0 이어야 PASS」로 판정한다(없는 기준선을 통과로 읽지 않는다)."""
    pat = re.compile(r'invalid identifier|syntax error|SQL compilation error', re.I)
    bad = [r for r in rows if r['ok'] and any(pat.search(e) for e in r['errors'])]
    for r in bad:
        print(f"  🔴 중간 오류 {r['agent']}_{r['n']:02d}: {r['errors'][0][-110:]}")
    fail = sum(1 for r in rows if not r['ok'])
    bp = os.path.join(OUT, '_baseline.json')
    base = json.load(io.open(bp, encoding='utf-8')).get('mid_errors') if os.path.exists(bp) else None
    if '--strict' in sys.argv or base is None:
        axis2 = not bad
        rule = '중간 오류 0(strict)' if '--strict' in sys.argv else '중간 오류 0(기준선 없음)'
    else:
        axis2 = len(bad) <= base
        rule = f'기준선 {base} 이하'
    ok = (fail == 0) and axis2
    print(f'① 최종 응답 실패 {fail} ⇒ ' + ('🟢' if fail == 0 else '🔴')
          + f' · ② 중간 오류 {len(bad)} ({rule}) ⇒ ' + ('🟢' if axis2 else '🔴')
          + ' ⇒ ' + ('🟢 PASS' if ok else '🔴 FAIL'))
    if '--set-baseline' in sys.argv:
        json.dump({'mid_errors': len(bad)}, io.open(bp, 'w', encoding='utf-8'))
        print(f'  기준선 갱신 = {len(bad)}')
    return 0 if ok else 1

if __name__ == '__main__':
    if '--judge-only' in sys.argv:  # 과금 없이 직전 `_summary.json` 만 재판정
        sys.exit(judge(json.load(io.open(os.path.join(OUT, '_summary.json'), encoding='utf-8'))))
    main()

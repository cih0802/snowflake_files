#!/usr/bin/env python3
"""NL 라우팅 스모크 판정기 (착수표 ㉗ 판정 축 ㉠·㉡).

🔴 판정 축
  ㉠ **라우팅 정확도** = 질문이 **의도한 도구**로 갔는가. 정답은 사람이 정해야 하므로
     이 도구는 「어떤 도구를 몇 번 썼는가」를 **관측**하고, 도구 0개(=SQL 미생성)와
     **오류**만 기계로 판정한다. 🔴 「도구를 썼다」 ≠ 「올바른 도구를 썼다」.
  ㉡ **산출물 유형** = SQL 을 만들었는가 · 표가 왔는가 · 서술만 왔는가.
  ㉢ **오류** = 응답 안의 error 표면 + 호출 실패.

🔴 이 도구는 응답 원문을 **요약만** 출력한다 — 본문을 세션에 싣지 않는다(비용 축).
사용 = `python3 scripts/nl_routing_judge.py [tmp/nlsmoke]`
"""
import glob
import io
import json
import os
import re
import sys


def walk_content(d):
    """content 항목을 (type, payload) 로 흘린다."""
    for it in d.get('content', []) or []:
        t = it.get('type') or next((k for k in it if k != 'type'), '?')
        yield t, it


def judge(path):
    raw = io.open(path, encoding='utf-8').read()
    tag = os.path.basename(path)[:-4]
    if raw.startswith('__CALL_FAILED__'):
        return dict(tag=tag, ok=False, tools=[], sql=0, rows=None,
                    err=raw[:120], text=0, toks=None)
    try:
        d = json.loads(raw)
    except Exception as e:
        return dict(tag=tag, ok=False, tools=[], sql=0, rows=None,
                    err=f'JSON 파싱 실패 {e}', text=0, toks=None)
    tools, sql, text_len, errs, sqls = [], 0, 0, [], []
    for t, it in walk_content(d):
        if t == 'tool_use':
            u = it.get('tool_use') or it
            nm = u.get('name') or u.get('tool_name') or '?'
            tools.append(nm)
            # 🔴🔴 [O167 자기정정] 초판은 `tool_results` 안의 `"sql":` 를 셌고 **전건 0** 을 냈다.
            #   그런데 같은 응답에 `system_execute_sql` 이 63회 있었다 ⇒ 0 은 사실이 아니라 **분모 오류**였다.
            #   🟢 SQL 은 **`tool_use.input.sql`** 에 있다. 판정식은 여기서 센다.
            s = (u.get('input') or {}).get('sql')
            if s:
                sql += 1
                sqls.append(s)
        elif t == 'tool_results':
            blob = json.dumps(it, ensure_ascii=False)
            errs += re.findall(r'"error[^"]*"\s*:\s*"([^"]{0,120})"', blob)
        elif t == 'text':
            text_len += len(str(it.get('text') or ''))
        elif t == 'thinking':
            pass
    toks = None
    try:
        u = d['metadata']['usage']['tokens_consumed']
        toks = sum(int(x.get('total_tokens') or x.get('tokens') or 0) for x in u) or None
    except Exception:
        pass
    return dict(tag=tag, ok=(d.get('status') or '').lower() in ('', 'success', 'completed', 'done'),
                tools=tools, sql=sql, rows=None, err=(errs[0] if errs else ''),
                text=text_len, toks=toks, status=d.get('status'))


def audit_units(path):
    """🆕 [O167] 착수표 ㉗ **축 ㉢** — 단위 표기 · 예측/실적 분리를 관측한다.

    🔴 **기계 판정이 아니라 관측이다.** 「단위를 밝혔는가」는 문장 의미이므로 최종 판단은 사람이 한다.
    이 함수는 **사람이 볼 곳을 좁혀 준다** = ㉠ 금액 문항인데 단위 토큰이 없는 응답
    ㉡ 예측 문항인데 「예측」 표기가 없는 응답 ㉢ 한 응답에 예측·실적이 섞인 것.
    """
    raw = io.open(path, encoding='utf-8').read()
    tag = os.path.basename(path)[:-4]
    try:
        d = json.loads(raw)
    except Exception:
        return dict(tag=tag, err='JSON 파싱 실패')
    text = ' '.join(str(it.get('text') or '') for t_, it in walk_content(d) if t_ == 'text')
    q = ''
    for t_, it in walk_content(d):
        if t_ == 'tool_use':
            u = it.get('tool_use') or it
            q = q or str((u.get('input') or {}).get('pruning_question') or '')
    money = bool(re.search(r'(금액|회비|예산|광고비|납입|청구|단가|LTV|총액)', q + text))
    # 🔴🔴 [O167 자기정정] 초판은 이 정규식의 `\b` 가 **백스페이스 문자(0x08)로 굳어** 있었고
    #   그래서 「…199원」이 든 응답을 **단위 미표기로 오탐**했다(금액 문항 7건 전부).
    #   🔴 원인 = heredoc 을 경유해 파일을 쓰면서 이스케이프가 한 겹 벗겨졌다(`R1-7-9` 축).
    #   🟢 판정식 = **정규식을 셸 경유로 쓰지 말고 쓴 뒤 실제 문자열로 한 건 시험하라.**
    unit = bool(re.search(r'만원|억원|억|천원|원', text))
    pred_q = bool(re.search(r'(예측|전망|스코어|기여 요인|위험|확률)', q))
    pred_mark = bool(re.search(r'(예측|전망|모델)', text))
    # 🔴🔴 [O167 자기정정] 초판은 *"예측치이며 실적이 아닙니다"* 를 **혼재로 오탐**했다 —
    #   그 문장은 위반이 아니라 **축 ㉢ 준수의 증거**다(예측과 실적을 명시적으로 갈랐다).
    #   🟢 부정 문맥을 먼저 걷어낸 뒤 남은 「실적」 언급만 센다.
    _t = re.sub(r'실적(이|은|과|를)?\s*아[니닙][^.]*', '', text)
    mixed = bool(re.search(r'예측', _t)) and bool(re.search(r'실적|실측|실제 값', _t))
    return dict(tag=tag, money=money, unit=unit, pred_q=pred_q, pred_mark=pred_mark,
                mixed=mixed, chars=len(text))


def main_units(outdir):
    rows = [audit_units(p) for p in sorted(glob.glob(os.path.join(outdir, 'AGENT_*.txt')))]
    rows = [r for r in rows if not r.get('err')]
    if not rows:
        raise SystemExit('[미판정] 응답 파일이 0건이다 — 판정식 실패다(O111 ㉠).')
    print(f'{"문항":<22}{"금액":>4}{"단위":>4}{"예측문항":>8}{"예측표기":>8}{"혼재":>5}  서술자')
    for r in rows:
        print(f'{r["tag"]:<22}{"O" if r["money"] else "-":>4}{"O" if r["unit"] else "-":>4}'
              f'{"O" if r["pred_q"] else "-":>8}{"O" if r["pred_mark"] else "-":>8}'
              f'{"O" if r["mixed"] else "-":>5}  {r["chars"]}')
    no_unit = [r['tag'] for r in rows if r['money'] and not r['unit']]
    no_mark = [r['tag'] for r in rows if r['pred_q'] and not r['pred_mark']]
    mixed = [r['tag'] for r in rows if r['mixed']]
    print(f'\n총 {len(rows)}문항 · 금액 문항 {sum(1 for r in rows if r["money"])} · '
          f'예측 문항 {sum(1 for r in rows if r["pred_q"])}')
    print(f'  {"🟠" if no_unit else "🟢"} 금액인데 단위 토큰 없음 {len(no_unit)}: {", ".join(no_unit) or "없음"}')
    print(f'  {"🟠" if no_mark else "🟢"} 예측인데 예측 표기 없음 {len(no_mark)}: {", ".join(no_mark) or "없음"}')
    print(f'  {"🟠" if mixed else "🟢"} 예측·실적 문구 혼재 {len(mixed)}: {", ".join(mixed) or "없음"}')
    print('🔴 위 🟠 는 **사람이 원문을 열어 판정**한다 — 기계는 토큰 유무만 본다(축 ㉢ 은 의미 판정이다).')
    return 0


def main(outdir):
    rows = [judge(p) for p in sorted(glob.glob(os.path.join(outdir, 'AGENT_*.txt')))]
    if not rows:
        raise SystemExit('[미판정] 응답 파일이 0건이다 — 판정식 실패다(O111 ㉠).')
    print(f'{"문항":<22}{"상태":<10}{"SQL":>4}  {"서술자":>6}  도구')
    for r in rows:
        st = r.get('status') or ('OK' if r['ok'] else 'FAIL')
        print(f'{r["tag"]:<22}{str(st):<10}{r["sql"]:>4}  {r["text"]:>6}  '
              f'{",".join(r["tools"])[:70]}{("  ⚠️ " + r["err"][:60]) if r["err"] else ""}')
    n = len(rows)
    nosql = [r['tag'] for r in rows if r['sql'] == 0]
    notool = [r['tag'] for r in rows if not r['tools']]
    bad = [r['tag'] for r in rows if r['err']]
    print(f'\n총 {n}문항 · SQL 생성 {n - len(nosql)} · 도구 사용 {n - len(notool)} · 오류표면 {len(bad)}')
    if nosql:
        print(f'  🟠 SQL 미생성 {len(nosql)}: {", ".join(nosql)}')
    if bad:
        print(f'  🔴 오류표면 {len(bad)}: {", ".join(bad)}')
    from collections import Counter
    c = Counter(t for r in rows for t in r['tools'])
    print('  도구 사용 분포:', dict(c))
    return 0


if __name__ == '__main__':
    _args = [x for x in sys.argv[1:] if not x.startswith('--')]
    _out = _args[0] if _args else '/workspace/tmp/nlsmoke'
    sys.exit(main_units(_out) if '--units' in sys.argv else main(_out))

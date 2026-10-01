# -*- coding: utf-8 -*-
"""[2026-10-01 O193] Agent 도구 **원천 리니지 게이트** — 도구 description 이 적은 BRONZE 테이블이 정말 그 SV 의 dbt 원천인가.

🔴 왜 필요한가(실측 경위):
   O193 이 AGENT_MEMBER 도구 8종의 원천을 `원천=CRM(eCRM) → GN_DW.BRONZE_CRM`(스키마까지)에서
   **테이블명까지**로 올렸다(현업 요청 = 「원천 답변에 BRONZE 테이블도 나오게」). 스펙 응답 규칙이
   *"BRONZE 테이블명은 도구 description 의 원천 괄호에 적힌 이름만 옮겨 쓴다"* 이므로,
   **description 이 틀리면 Agent 는 틀린 테이블을 자신 있게 답한다**(무증상 오답 계열).
   그런데 기존 게이트 어느 것도 이 축을 보지 않는다:
   · `agent_object_ref_gate` = 이름이 **라이브에 실재**하는가만 본다(그 지표의 원천인가는 안 본다 · 그 docstring 말미).
   · `agent_tool_claim_gate` = 같은 SV 도구 간 **가불가 모순**만 본다.
   ⇒ 「dbt 리니지 ↔ 스펙 원천 문구」를 대조하는 축이 없었다. dbt 모델이 바뀌면 스펙 원천이 조용히 낡는다.

판정 축
  ① 🔴 blocking · **리니지 밖 BRONZE 테이블** — 도구 description 에 적힌 BRONZE 테이블이
     그 SV 의 base 테이블(FACT/WIDE/DIM 전부)에서 dbt `ref()`/`source()` 를 전이적으로 따라간
     집합(ALLOWED)에 없다. = 틀린 원천을 발행 중이거나 dbt 변경으로 낡았다.
  ② 🔴 blocking · **리니지 밖 GOLD 객체** — description 의 `GOLD.<X>` 가 그 SV 의 base 테이블이나
     그 조상 팩트(FACT_/WIDE_ ref 사슬)에 없다.
  ③ 🟠 advisory · **핵심 원천 누락** — 팩트가 **직접** 참조하는 SILVER 의 BRONZE source(CORE ·
     코드사전 `TC_*` 제외)가 description 에 없다. 직접 SILVER 가 없으면(파생 팩트) 조상 팩트로 내려가 잰다.
     🔴 advisory 다 — 각주 가독성을 위해 일부만 적는 것은 정당한 편집 판단이다.
  ④ 🟠 advisory · **원천 괄호 미기재** — dbt 리니지가 있는 SV 인데 description 에 BRONZE 테이블이 0개.
     `--strict` 를 주면 blocking. (선례 관례 = 위반 0 을 실측한 뒤 blocking 으로 승격한다.)
  ⑤ ⚪ 관측 · **dbt 밖 SV** — base 가 dbt 모델이 아니다(예: `SERVING.ML_*_V` = GN_DW.ML 산출물).
     판정 대상이 아님을 분모로 보여준다.

생성 모드 `--suggest [--agent A] [--sv SV]`
  SV 를 Agent 에 배선할 때 description 에 붙일 원천 문구(CORE 기준)를 출력한다. **파일을 쓰지 않는다.**
  🔴 테이블의 업무 라벨(「개발사건」·「중단」 등)은 자동으로 만들지 않는다 — 라벨 창작 금지. 사람이 붙인다.

🔴 이 게이트는 **파일만 읽는다**(dbt 모델 · SV DDL · Agent 스펙). 라이브 접속 없음 ⇒ 데이터 없는 문서작업 계정에서도 돈다.
🔴 dbt 파싱은 정규식이다 — `ref('X')`·`source('s','T')` 리터럴만 인식한다(동적 ref 는 보지 못한다).

종료코드 = 0 통과 · 1 위반 · 2 사용법 오류.
"""
import sys
import os
import re
import glob
import argparse

import yaml

ROOT = '/workspace'
AGENT_GLOB = 'cortex_project/agents/*/agent_spec.yaml'
DBT_GLOBS = ('10_dbt_pipeline/models/**/*.sql', '10_dbt_pipeline/snapshots/**/*.sql')
SV_DDL_GLOB = '05_SV-Agent_ai/*.sql'          # `_archive/` 는 glob 이 내려가지 않는다(의도)

# 코드사전 — CORE(핵심 원천)에서 뺀다. ALLOWED 에는 남는다(적어도 틀린 것은 아니다).
CODE_TABLE_RE = re.compile(r'^TC_')

REF_RE = re.compile(r"""ref\(\s*['"](\w+)['"]\s*\)""")
SRC_RE = re.compile(r"""source\(\s*['"](\w+)['"]\s*,\s*['"](\w+)['"]\s*\)""")
SNAP_RE = re.compile(r'\{%-?\s*snapshot\s+(\w+)')
SV_HEAD_RE = re.compile(r'CREATE\s+OR\s+(?:ALTER|REPLACE)\s+SEMANTIC\s+VIEW\s+GN_DW\.SERVING\.(\w+)', re.I)
SV_TABLE_RE = re.compile(r'\bAS\s+GN_DW\.(\w+)\.(\w+)', re.I)
GOLD_CITE_RE = re.compile(r'\bGOLD\.([A-Z][A-Z0-9_]+)')
TOKEN_RE = re.compile(r'[A-Z][A-Z0-9_]{3,}')


def _strip_sql_comments(t):
    t = re.sub(r'\{#.*?#\}', '', t, flags=re.S)
    return re.sub(r'--[^\n]*', '', t)


def source_schema(src_name):
    """dbt source 이름 → 물리 스키마. `bronze_crm`·`bronze_crm_ref` → BRONZE_CRM.
    🔴 `_sources.yml` 의 schema 는 Jinja(target 분기)라 파싱하지 않고 이름 규약으로 정한다."""
    n = src_name.lower()
    if n.endswith('_ref'):
        n = n[:-4]
    return n.upper()


def load_models(root=None):
    root = root or ROOT
    models = {}
    for g in DBT_GLOBS:
        for p in glob.glob(os.path.join(root, g), recursive=True):
            t = _strip_sql_comments(open(p, encoding='utf-8').read())
            name = os.path.basename(p)[:-4]
            m = SNAP_RE.search(t)
            if m and '/snapshots/' in p:
                name = m.group(1)
            models[name] = {
                'refs': sorted(set(REF_RE.findall(t))),
                'srcs': sorted({(source_schema(a), b) for a, b in SRC_RE.findall(t)}),
                'layer': 'silver' if '/models/silver/' in p else ('gold' if '/models/gold/' in p else 'other'),
            }
    return models


def load_sv_tables(root=None):
    """SV 이름 → 그 SV 가 논리테이블로 선언한 (스키마, 객체) 목록. 파일 순서대로 CREATE 블록을 자른다."""
    root = root or ROOT
    out = {}
    for p in sorted(glob.glob(os.path.join(root, SV_DDL_GLOB))):
        t = _strip_sql_comments(open(p, encoding='utf-8').read())
        heads = list(SV_HEAD_RE.finditer(t))
        for i, h in enumerate(heads):
            end = heads[i + 1].start() if i + 1 < len(heads) else len(t)
            body = t[h.end():end]
            tables = []
            for s, o in SV_TABLE_RE.findall(body):
                k = (s.upper(), o.upper())
                if k not in tables:
                    tables.append(k)
            out.setdefault(h.group(1).upper(), tables)
    return out


def closure(models, start):
    """start 모델에서 ref 를 전이적으로 따라간 BRONZE source 집합(ALLOWED)."""
    seen, stack, out = set(), [start], set()
    while stack:
        n = stack.pop()
        if n in seen or n not in models:
            continue
        seen.add(n)
        out |= {(s, t) for s, t in models[n]['srcs'] if s.startswith('BRONZE_')}
        stack.extend(models[n]['refs'])
    return out


def _is_fact(n):
    return n.startswith(('FACT_', 'WIDE_'))


def fact_ancestors(models, start):
    """start 와 그 FACT_/WIDE_ ref 사슬(DIM 은 따라가지 않는다)."""
    seen, stack = [], [start]
    while stack:
        n = stack.pop()
        if n in seen or n not in models:
            continue
        seen.append(n)
        stack.extend(r for r in models[n]['refs'] if _is_fact(r))
    return seen


def core(models, fact):
    """팩트가 **직접** 참조하는 SILVER 의 BRONZE source(TC_* 제외).
    직접 SILVER 가 없으면(파생 팩트) 직계 조상 팩트로 한 단계씩 내려간다."""
    out, frontier, seen = set(), [fact], set()
    while frontier and not out:
        nxt = []
        for f in frontier:
            if f in seen or f not in models:
                continue
            seen.add(f)
            for r in models[f]['refs']:
                m = models.get(r)
                if m and m['layer'] == 'silver':
                    out |= {(s, t) for s, t in m['srcs']
                            if s.startswith('BRONZE_') and not CODE_TABLE_RE.match(t)}
                elif _is_fact(r):
                    nxt.append(r)
        frontier = nxt
    return out


def sv_lineage(models, sv_tables, sv):
    """SV → {'dbt': bool, 'facts', 'allowed', 'core', 'gold_ok'}"""
    tabs = sv_tables.get(sv, [])
    dbt_tabs = [o for s, o in tabs if s == 'GOLD' and o in models]
    facts = [o for o in dbt_tabs if _is_fact(o)]
    allowed, core_set, gold_ok = set(), set(), set(o for s, o in tabs if s == 'GOLD')
    for o in dbt_tabs:
        allowed |= closure(models, o)
    for f in facts:
        core_set |= core(models, f)
        gold_ok |= set(fact_ancestors(models, f))
    return {'dbt': bool(dbt_tabs), 'facts': facts, 'allowed': allowed,
            'core': core_set, 'gold_ok': gold_ok, 'tables': tabs}


def bronze_universe(models):
    return {t for m in models.values() for s, t in m['srcs'] if s.startswith('BRONZE_')}


def dim_sources(models):
    """🆕 [O196-D · DEC-59 #7] GOLD `DIM_*` 모델이 직접 ref 하는 SILVER 의 BRONZE source(= 차원 원천)."""
    out = set()
    for n, m in models.items():
        if not n.startswith('DIM_'):
            continue
        for r in m['refs']:
            s = models.get(r)
            if s and s['layer'] == 'silver':
                out |= {t for sch, t in s['srcs'] if sch.startswith('BRONZE_')}
    return out


def load_spec(path):
    d = yaml.safe_load(open(path, encoding='utf-8')) or {}
    res = d.get('tool_resources') or {}
    tools = []
    for i, t in enumerate(d.get('tools') or []):
        ts = (t or {}).get('tool_spec') or {}
        name = ts.get('name')
        sv = ((res.get(name) or {}).get('semantic_view') or '')
        tools.append({'idx': i, 'name': name, 'desc': ts.get('description') or '',
                      'sv': sv.split('.')[-1].upper() if sv else ''})
    return tools


def judge(root=None, strict=False, out=sys.stdout):
    root = root or ROOT
    models = load_models(root)
    sv_tables = load_sv_tables(root)
    universe = bronze_universe(models)
    dim_src = dim_sources(models)
    block, adv, obs = [], [], []
    n_tools = 0
    for path in sorted(glob.glob(os.path.join(root, AGENT_GLOB))):
        agent = os.path.basename(os.path.dirname(path))
        for t in load_spec(path):
            if not t['sv']:
                continue
            n_tools += 1
            tag = '%s/%s(%s)' % (agent, t['name'], t['sv'])
            if t['sv'] not in sv_tables:
                obs.append('%s → SV DDL 파일에서 정의를 찾지 못함(판정 생략)' % tag)
                continue
            L = sv_lineage(models, sv_tables, t['sv'])
            if not L['dbt']:
                obs.append('%s → dbt 밖 base(%s) · 판정 대상 아님' % (
                    tag, ', '.join('%s.%s' % x for x in L['tables']) or '없음'))
                continue
            cited = {x for x in TOKEN_RE.findall(t['desc']) if x in universe}
            allowed_names = {tb for s, tb in L['allowed']}
            for x in sorted(cited - allowed_names):
                block.append('① %s → `%s` 는 이 SV 의 dbt 리니지 밖이다' % (tag, x))
            for g in sorted(set(GOLD_CITE_RE.findall(t['desc'])) - L['gold_ok']):
                block.append('② %s → `GOLD.%s` 는 이 SV 의 base·조상 팩트가 아니다' % (tag, g))
            if not cited:
                msg = '④ %s → 원천 괄호에 BRONZE 테이블 0개 (`--suggest --sv %s` 로 문구 생성)' % (tag, t['sv'])
                (block if strict else adv).append(msg)
            else:
                # 🆕 [2026-10-01 O196-D · DEC-59 #7] 「차원 원천 제외」 — GOLD DIM_* 가 SILVER 경유로
                #   읽는 BRONZE 는 조인용 차원 원천이다 ⇒ 답변에 쓸 「핵심 테이블」이 아니므로 누락으로 세지 않는다.
                miss = sorted(tb for s, tb in L['core'] if tb not in cited and tb not in dim_src)
                if miss:
                    adv.append('③ %s → 핵심 원천 미기재 %d: %s (차원 원천 제외 후 · DEC-59 #7 = 사용자 결정으로 수용)'
                               % (tag, len(miss), ' · '.join(miss)))
    print('[원천 리니지 게이트] Agent 도구 %d개 · dbt 모델 %d개 · SV 정의 %d개 · BRONZE 테이블 모집단 %d개'
          % (n_tools, len(models), len(sv_tables), len(universe)), file=out)
    for title, rows in (('⚪ 관측', obs), ('🟠 advisory', adv)):
        if rows:
            print('\n%s %d건' % (title, len(rows)), file=out)
            for r in rows:
                print('  ' + r, file=out)
    print('=' * 72, file=out)
    if block:
        print('🔴 FAIL — blocking 위반 %d건' % len(block), file=out)
        for r in block:
            print('  ' + r, file=out)
        return 1
    print('🟢 PASS — blocking 0건%s' % (' (strict)' if strict else ''), file=out)
    return 0


def suggest(root=None, agent=None, sv=None, out=sys.stdout):
    root = root or ROOT
    models = load_models(root)
    sv_tables = load_sv_tables(root)
    targets = []
    if sv:
        targets.append((None, None, sv.split('.')[-1].upper()))
    else:
        for path in sorted(glob.glob(os.path.join(root, AGENT_GLOB))):
            a = os.path.basename(os.path.dirname(path))
            if agent and a.upper() != agent.upper():
                continue
            targets += [(a, t['name'], t['sv']) for t in load_spec(path) if t['sv']]
    if not targets:
        print('대상 없음 — --agent/--sv 를 확인하라', file=out)
        return 2
    for a, name, s in targets:
        head = '%s/%s(%s)' % (a, name, s) if a else s
        if s not in sv_tables:
            print('## %s\n   (SV DDL 정의 없음)' % head, file=out)
            continue
        L = sv_lineage(models, sv_tables, s)
        if not L['dbt']:
            print('## %s\n   (dbt 밖 base — 수동 기재: %s)' % (
                head, ', '.join('%s.%s' % x for x in L['tables'])), file=out)
            continue
        by_schema = {}
        for sc, tb in sorted(L['core']):
            by_schema.setdefault(sc, []).append(tb)
        src = ' · '.join('GN_DW.%s(%s)' % (sc, '·'.join(tbs)) for sc, tbs in by_schema.items())
        print('## %s\n   원천=%s → %s' % (head, src or '(직접 SILVER 원천 없음)',
                                       ' → '.join('GOLD.' + f for f in L['facts'])), file=out)
        print('   🔴 업무 라벨(예: 「개발사건 TM_…」)은 사람이 붙인다 — 자동 창작 금지', file=out)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description='Agent 도구 description 의 BRONZE/GOLD 원천을 dbt 리니지와 대조한다.')
    ap.add_argument('--strict', action='store_true', help='원천 괄호 미기재(④)를 blocking 으로 센다')
    ap.add_argument('--suggest', action='store_true', help='판정 대신 원천 문구를 제안한다(파일 쓰기 없음)')
    ap.add_argument('--agent', help='--suggest 대상 Agent 폴더명(예: AGENT_MEMBER)')
    ap.add_argument('--sv', help='--suggest 대상 SV 이름(예: SV_MEMBER_EVENT) — Agent 배선 전에도 쓸 수 있다')
    a = ap.parse_args(argv)
    if (a.agent or a.sv) and not a.suggest:
        ap.error('--agent/--sv 는 --suggest 와 함께 쓴다')
    if a.suggest:
        return suggest(agent=a.agent, sv=a.sv)
    return judge(strict=a.strict)


if __name__ == '__main__':
    sys.exit(main())

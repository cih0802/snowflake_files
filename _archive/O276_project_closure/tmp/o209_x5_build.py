# O209 X5 — 정본 agent_spec.yaml 3종 재생성 · 본문 = tmp/o209_x5_text.py
# 사용: python3 tmp/o209_x5_build.py [AGENT_EXECUTIVE ...] [--write]   (기본 = 점검만)
# 백업 = tmp/o209_x5/<AGENT>_before.yaml(최초 1회 · 덮지 않는다)
# Co-authored with CoCo
import copy, os, re, shutil, sys, yaml
sys.path.insert(0, '/workspace/tmp')
import o209_x5_text as T
BASE = '/workspace/cortex_project/agents'
BK = '/workspace/tmp/o209_x5'
MOVE_TO_EXEC = ['analyst_member_event', 'analyst_dev_achievement', 'analyst_member_monthly_kpi',
                'analyst_mbrfee_prdt_actl', 'analyst_spnsr_cls_aggr', 'analyst_dvlp_goal_acmslt',
                'analyst_ml_fee_forecast']
MSTR_NEW = ' 「신규 개발」의 「신규」는 기본적으로 개발구분 = 신규로 해석하고, 사용자가 「신규/기존」을 명시할 때만 신규기존구분 축을 쓴다(O209).'
BODY = {
    'AGENT_EXECUTIVE': (T.EXEC_SYS, T.EXEC_ORCH, T.EXEC_SAMPLES),
    'AGENT_MEMBER': (T.MEMBER_SYS, T.MEMBER_ORCH, T.MEMBER_SAMPLES),
    'AGENT_MARKETING': (T.MKT_SYS, T.MKT_ORCH, T.MKT_SAMPLES),
}
TAG = re.compile(r'O\d{2,3}(?:-[A-Z])?|공#?\d+|DEC-\d+')


def load(a):
    p = f'{BK}/{a}_before.yaml'
    if not os.path.exists(p):
        shutil.copyfile(f'{BASE}/{a}/agent_spec.yaml', p)
    return yaml.safe_load(open(p, encoding='utf-8'))


def tags(ins):
    return set(TAG.findall(' '.join(v for k, v in ins.items() if isinstance(v, str))))


def build(a):
    old = load(a); new = copy.deepcopy(old)
    sysb, orch, samples = BODY[a]
    new['instructions'] = {
        'system': sysb + '\n' + T.COMMON_BOUNDARY,
        'orchestration': T.COMMON_ORCH + '\n' + orch,
        'response': T.COMMON_RESP,
        'sample_questions': [{'question': q} for q in samples],
    }
    if a == 'AGENT_EXECUTIVE':
        mem = load('AGENT_MEMBER')
        have = {t['tool_spec']['name'] for t in new['tools']}
        for t in mem['tools']:
            n = t['tool_spec']['name']
            if n in MOVE_TO_EXEC and n not in have:
                new['tools'].append(copy.deepcopy(t)); new['tool_resources'][n] = copy.deepcopy(mem['tool_resources'][n])
    for t in new['tools']:
        if t['tool_spec']['name'] == 'analyst_mstr_spnsr_dvlp' and 'O209' not in t['tool_spec']['description']:
            t['tool_spec']['description'] = t['tool_spec']['description'].rstrip() + MSTR_NEW
    lost = sorted(tags(old['instructions']) - tags(new['instructions']))
    return old, new, lost


if __name__ == '__main__':
    targets = [x for x in sys.argv[1:] if x.startswith('AGENT_')] or list(BODY)
    for a in targets:
        old, new, lost = build(a)
        ins = new['instructions']
        print(a, 'tools', len(old['tools']), '->', len(new['tools']),
              {k: len(v) for k, v in ins.items() if isinstance(v, str)},
              'old', {k: len(v) for k, v in old['instructions'].items() if isinstance(v, str)})
        print('  사라진 규칙 표식:', lost)
        if '--write' in sys.argv:
            out = yaml.safe_dump(new, allow_unicode=True, sort_keys=False, width=110)
            open(f'{BASE}/{a}/agent_spec.yaml', 'w', encoding='utf-8').write(out)
            back = yaml.safe_load(open(f'{BASE}/{a}/agent_spec.yaml', encoding='utf-8'))
            print('  write ok · 되읽기 일치', back == new)

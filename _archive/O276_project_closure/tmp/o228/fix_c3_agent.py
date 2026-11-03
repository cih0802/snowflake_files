#!/usr/bin/env python3
"""O228 ④ C3 AGENT_TOOL — agent_spec.yaml 3종의 tools[].tool_spec.description 에서 이슈ID·경위 서사 제거.
scrub = tmp/o228/fix_c3_sv.py(= O227 규칙 + SV 후처리) 그대로 + 도구 설명 전용 후처리 TPOST.
대상 = `tools:` ~ `tool_resources:` 구간의 `description:` 한 줄 스칼라만(instructions 는 대상 아님).
사용: python3 tmp/o228/fix_c3_agent.py [--apply]  · 산출 = tmp/o228/c3_agent_diff.md · 잔여 ID 있으면 ABORT.
Co-authored with CoCo
"""
import hashlib, io, json, re, sys
import yaml

src = io.open('/workspace/tmp/o228/fix_c3_sv.py', encoding='utf-8').read()
ns = {}
exec(compile(src[:src.index('FILES = sorted')], 'sv', 'exec'), ns)
ID, scrub_sv = ns['ID'], ns['scrub']
TPOST = [
    (r'\[\s*(?:T\d+\s*)?배선\]\s*', ''), (r'\[\s*T\d+ 2차\]\s*', ''), (r'\[\s*\d+차\]\s*', ''),
    (r'^\s*(?:7차|13차|\d+차)\s+', ''),
    (r'\(종전 "캠페인별 분해 불가" 서술은 회수됐다\)', ''),
    (r'\s*🔴 종전 "캠페인별 중단건은 산출 불가"라는 서술은 거짓이므로 회수됐다\.', ' 🟢 캠페인별 중단건은 산출할 수 있다.'),
    (r'\(종전 처방의 사각지대\)', ''),
    (r' · 7차 `캠페인유형` 축\)', ')'),
    (r'\[나눔마케팅 배선\]\s*', ''),
]


def scrub(t):
    t = scrub_sv(t)
    for a, b in TPOST:
        t = re.sub(a, b, t)
    t = re.sub(r'\(\s*·\s*', '(', t)
    return re.sub(r'\s{2,}', ' ', t).strip()


NARR = re.compile(r'종전|거짓이|철회|이슈원장|문서\d0 §')
OUT = '/workspace/tmp/o228/c3_agent_diff.md'
apply = '--apply' in sys.argv
diff, resid, touched = [], [], {}
for a in ('EXECUTIVE', 'MEMBER', 'MARKETING'):
    p = f'/workspace/cortex_project/agents/AGENT_{a}/agent_spec.yaml'
    h = [hashlib.sha256(open(p, 'rb').read()).hexdigest() for _ in range(2)]
    assert h[0] == h[1], 'hash unstable ' + p
    L = io.open(p, encoding='utf-8').read().split('\n')
    i0 = next(i for i, s in enumerate(L) if s.startswith('tools:'))
    i1 = next(i for i, s in enumerate(L) if s.startswith('tool_resources:'))
    n, name, i, out = 0, None, i0, L[:i0]
    while i < i1:
        m = re.match(r'^(\s+)name: (\S+)', L[i])
        if m:
            name = m.group(2)
        m = re.match(r'^(\s+)description: (.*)$', L[i])
        if not m:
            out.append(L[i]); i += 1
            continue
        # 여러 줄 스칼라 — 파싱이 될 때까지 다음 줄을 붙인다
        j, old = i, None
        while j < i1:
            try:
                old = yaml.safe_load('d: ' + '\n'.join([m.group(2)] + [x.strip() and '  ' + x.strip() or '' for x in L[i + 1:j + 1]]))['d']
                nxt = L[j + 1] if j + 1 < len(L) else ''
                if not nxt.strip() or len(nxt) - len(nxt.lstrip()) <= len(m.group(1)):
                    break
            except yaml.YAMLError:
                pass
            j += 1
        if not isinstance(old, str) or not (re.search(r'\b' + ID + r'\b', old) or NARR.search(old)):
            out.extend(L[i:j + 1]); i = j + 1
            continue
        new = scrub(old)
        left = sorted(set(re.findall(r'\b' + ID + r'\b', new)))
        if left:
            resid.append(f'{a}.{name} {left}')
        dumped = yaml.dump({'description': new}, allow_unicode=True, width=700, default_style='"').rstrip('\n').split('\n')
        dumped[0] = dumped[0].replace('"description":', 'description:', 1)
        block = [m.group(1) + dumped[0]] + [m.group(1) + '  ' + x.strip() for x in dumped[1:]]
        assert yaml.safe_load('\n'.join(x[len(m.group(1)):] for x in block))['description'] == new, name
        out.extend(block)
        diff.append(f'### AGENT_{a}.{name}\n- 전: {old}\n- 후: {new}\n')
        n += 1
        i = j + 1
    L = out + L[i1:]
    if n:
        touched[p] = (n, L)
if diff:
    io.open(OUT, 'w', encoding='utf-8').write('# O228 C3 AGENT_TOOL 전후 대조\n\n' + '\n'.join(diff) + '\n_Co-authored with CoCo_\n')
print('변경 파일', len(touched), '· 설명', len(diff), '· 잔여ID', len(resid))
for p, (n, _) in touched.items():
    print('  ', p.split('/')[-2], n)
for r in resid:
    print('  잔여', r)
if resid:
    sys.exit('🔴 ABORT — 잔여 ID')
if apply:
    sys.path.insert(0, '/workspace/scripts')
    from snapshot_util import snapshot
    for p, (_, L) in touched.items():
        snap, st = snapshot(p, 'prec3agent', label='O228', archive='/workspace/tmp/o228/bak/' + p.split('/')[-2])
        print('   snap', st, snap.split('/')[-1])
        io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
        yaml.safe_load(open(p, encoding='utf-8'))
    print('APPLIED', len(touched))
else:
    print('DRY-RUN')

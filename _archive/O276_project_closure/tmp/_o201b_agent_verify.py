#!/usr/bin/env python3
# O201-B — Agent 4종 기본 버전 + 라이브 스펙에 [O201-B] 규칙이 실렸는지 판정 · owner
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
cn = conn()
for a in ['AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER', 'AGENT_MSTR']:
    c, r = q('DESCRIBE AGENT GN_DW.SERVING.%s' % a, cn)
    d = dict(zip([x.lower() for x in c], r[0]))
    spec = json.loads(d['agent_spec'])
    print(a, 'owner=%s' % d['owner'], 'default=%s' % d['default_version_name'],
          'aliases=%s' % d['aliases'], 'rule=%s' % ('[O201-B]' in spec['instructions']['orchestration']))
cn.close()

#!/usr/bin/env python3
"""a2_matrix_build 음성 테스트 (R3-2) — 부여 제거 ⇒ MISSING · 일부 제거 ⇒ PARTIAL · 설계 밖 추가 ⇒ 설계외부여 · 소유 ⇒ OK."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a2_matrix_build as m  # noqa: E402

fails = 0


def check(name, cond):
    global fails
    print(('🟢 ' if cond else '🔴 ') + name)
    fails += 0 if cond else 1


design = [
    {'ROLE': 'GN_DW_ANALYST', 'GRANTED_ON': 'SCHEMA', 'MODE': 'OBJ', 'SCOPE': 'GOLD', 'PRIVILEGE': 'USAGE', 'SOURCE': 't', 'NOTE': ''},
    {'ROLE': 'GN_DW_ANALYST', 'GRANTED_ON': 'TABLE', 'MODE': 'ALL', 'SCOPE': 'GOLD', 'PRIVILEGE': 'SELECT', 'SOURCE': 't', 'NOTE': ''},
    {'ROLE': 'GN_DW_ANALYST', 'GRANTED_ON': 'FUTURE TABLE', 'MODE': 'FUTURE', 'SCOPE': 'GOLD', 'PRIVILEGE': 'SELECT', 'SOURCE': 't', 'NOTE': ''},
    {'ROLE': 'GN_DW_ADMIN', 'GRANTED_ON': 'TABLE', 'MODE': 'ALL', 'SCOPE': 'GOLD', 'PRIVILEGE': 'ALL', 'SOURCE': 't', 'NOTE': ''},
]


def base():
    d = {
        ('GN_DW_ADMIN', 'TABLE', 'GN_DW.GOLD.T1'): {'OWNERSHIP'},
        ('GN_DW_ADMIN', 'TABLE', 'GN_DW.GOLD.T2'): {'OWNERSHIP'},
        ('GN_DW_ANALYST', 'SCHEMA', 'GN_DW.GOLD'): {'USAGE'},
        ('GN_DW_ANALYST', 'TABLE', 'GN_DW.GOLD.T1'): {'SELECT'},
        ('GN_DW_ANALYST', 'TABLE', 'GN_DW.GOLD.T2'): {'SELECT'},
    }
    f = {('GN_DW_ANALYST', 'FUTURE TABLE', 'GN_DW.GOLD'): {'SELECT'}}
    return d, f


def run(d, f):
    owned = m.denominators(d)
    j, cov = m.judge(design, d, f, owned)
    return {(r[0], r[1], r[4]): r[5] for r in j}, m.extras(d, f, cov)


d, f = base()
st, ex = run(d, f)
check('정상 = 전건 OK · 설계외 0', set(st.values()) == {'OK'} and not ex)

d, f = base(); del d[('GN_DW_ANALYST', 'SCHEMA', 'GN_DW.GOLD')]
st, _ = run(d, f)
check('스키마 USAGE 제거 ⇒ MISSING', st[('GN_DW_ANALYST', 'SCHEMA', 'USAGE')] == 'MISSING')

d, f = base(); del d[('GN_DW_ANALYST', 'TABLE', 'GN_DW.GOLD.T2')]
st, _ = run(d, f)
check('테이블 1/2 제거 ⇒ PARTIAL', st[('GN_DW_ANALYST', 'TABLE', 'SELECT')] == 'PARTIAL')

d, f = base(); f.clear()
st, _ = run(d, f)
check('FUTURE 제거 ⇒ MISSING', st[('GN_DW_ANALYST', 'FUTURE TABLE', 'SELECT')] == 'MISSING')

d, f = base(); d[('GN_DW_ANALYST', 'TABLE', 'GN_DW.GOLD.T1')].add('DELETE')
_, ex = run(d, f)
check('설계 밖 DELETE 추가 ⇒ 설계외부여 1', len(ex) == 1 and ex[0][3] == 'DELETE')

d, f = base()
st, _ = run(d, f)
check('소유자 ALL ⇒ OK(역방향 오탐 없음)', st[('GN_DW_ADMIN', 'TABLE', 'ALL')] == 'OK')

check('정규화 = 따옴표·인자 절단', m.norm('GN_DW.ML."SP_X(VARCHAR):VARCHAR"') == 'GN_DW.ML.SP_X')

sys.exit(1 if fails else 0)

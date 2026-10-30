#!/usr/bin/env python3
"""O270 원천별 접근통제 3축 대조(Agent 배선 ↔ 분류표 ↔ 라이브 GRANT) · 위반 1건 이상 rc=1

🆕 [O270-F 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `JUDGE`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 종료코드가 판정이다 — 위반이면 1, 통과면 0. 🔴 음성 테스트 = `scripts/test_rbac_source_gate.py`(`R3-2`).

축(정본 = 계획서 `12_agent개선과제/O270_원천별_접근통제_작업계획.md` C9 「게이트 1개로 한정」)
  A1 배선   = Agent 스펙(`cortex_project/agents/*/agent_spec.yaml`)의 SV 원천 분류 ⊆ 그 Agent 허용 원천
  A2 파일   = SV·SERVING 뷰 DDL 파일의 접근 역할 GRANT 줄이 분류표와 같다(누락·오배정 0)
  A3 라이브 = (`--live` 일 때만) 접근 역할 4종의 실제 GRANT 가 분류표와 같다(오배정·누락 0)
분류표 정본 = `12_agent개선과제/output/O270_source_class.csv`(W1).

사용법
    python3 scripts/rbac_source_gate.py           # A1·A2(파일만 · 라이브 무접속)
    python3 scripts/rbac_source_gate.py --live    # A1·A2·A3
"""
import csv
import glob
import os
import re
import sys

W = '/workspace'
CLASS_CSV = W + '/12_agent개선과제/output/O270_source_class.csv'
AR = {'COMMON': 'GN_DW_AR_SRC_COMMON', 'AGENCY': 'GN_DW_AR_SRC_AGENCY',
      'ERP': 'GN_DW_AR_SRC_ERP', 'AGENCY+ERP': 'GN_DW_AR_SRC_AGENCY_ERP'}
AR_INV = {v: k for k, v in AR.items()}
ALLOWED = {'AGENT_MARKETING': {'COMMON', 'AGENCY', 'ERP', 'AGENCY+ERP'},
           'AGENT_MEMBER': {'COMMON'},
           'AGENT_EXECUTIVE': {'COMMON', 'ERP'}}
# dbt 밖 · 분류표 미등재지만 48번 SQL 이 COMMON 으로 준 객체(생성기 EXTRA 와 같은 집합)
EXTRA = {'SERVING.BIZ_DEFINITION_CORPUS': 'COMMON', 'GOLD.ORG_SUCCESSION_MANUAL': 'COMMON'}
DDL_FILES = sorted(glob.glob(W + '/05_SV-Agent_ai/*.sql')) + [W + '/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
GRANT_RE = re.compile(r'^\s*GRANT\s+[A-Z, ]+?\s+ON\s+(?:SEMANTIC VIEW|VIEW)\s+(?:GN_DW\.)?(?:SERVING\.)?([A-Z0-9_]+)\s+'
                      r'TO\s+ROLE\s+(GN_DW_AR_SRC_[A-Z_]+)\s*;', re.I)


# ---------------------------------------------------------------- 판정(순수 함수 · 테스트 대상)
def check_wiring(agent_svs, cls):
    """agent_svs = {agent: [SV 이름]} · cls = {'SERVING.SV_x': class}"""
    v = []
    for a, svs in agent_svs.items():
        allow = ALLOWED.get(a)
        if allow is None:
            continue
        for sv in svs:
            c = cls.get('SERVING.' + sv)
            if c is None:
                v.append('A1 %s → %s : 분류표 미등재' % (a, sv))
            elif not set(c.split('+')) <= allow and c not in allow:
                v.append('A1 %s → %s : 원천 %s 금지(허용 %s)' % (a, sv, c, '·'.join(sorted(allow))))
    return v


def check_ddl(ddl_grants, cls):
    """ddl_grants = [(객체 이름, 접근 역할)] · SERVING SV·뷰 대상"""
    v, seen = [], {}
    for obj, role in ddl_grants:
        c = cls.get('SERVING.' + obj)
        if c is None:
            v.append('A2 DDL %s → %s : 분류표 미등재 객체' % (obj, role))
            continue
        if AR_INV.get(role) != c:
            v.append('A2 DDL %s → %s : 분류 %s 와 불일치(기대 %s)' % (obj, role, c, AR[c]))
        seen.setdefault(obj, set()).add(role)
    for k, c in cls.items():
        s, n = k.split('.', 1)
        if s == 'SERVING' and n not in seen and k not in EXTRA:  # EXTRA = 테이블(코퍼스) · DDL 파일 축 밖
            v.append('A2 DDL %s : 접근 역할 GRANT 줄 부재(기대 %s)' % (n, AR[c]))
    return v


def check_live(live_grants, cls, live_objects):
    """live_grants = [(접근 역할, 'SCHEMA.NAME')] · live_objects = 라이브에 실재하는 'SCHEMA.NAME' 집합"""
    v, have = [], {}
    for role, obj in live_grants:
        c = cls.get(obj)
        if c is None:
            v.append('A3 LIVE %s → %s : 분류표 미등재 객체에 GRANT' % (role, obj))
            continue
        if AR_INV.get(role) != c:
            v.append('A3 LIVE %s → %s : 분류 %s 와 불일치' % (role, obj, c))
        have.setdefault(obj, set()).add(role)
    for obj in sorted(live_objects):
        c = cls.get(obj)
        if c and AR[c] not in have.get(obj, set()):
            v.append('A3 LIVE %s : %s GRANT 누락' % (obj, AR[c]))
    return v


# ---------------------------------------------------------------- 입력 수집
def load_class():
    cls = dict(EXTRA)
    for r in csv.DictReader(open(CLASS_CSV, encoding='utf-8')):
        if r['layer'] in ('GOLD', 'SERVING'):
            cls[r['layer'] + '.' + r['object']] = r['source_class']
    return cls


def load_agent_svs():
    import yaml
    out = {}
    for a in ALLOWED:
        d = yaml.safe_load(open(W + '/cortex_project/agents/%s/agent_spec.yaml' % a, encoding='utf-8'))
        out[a] = [str(r['semantic_view']).split('.')[-1] for r in d.get('tool_resources', {}).values()
                  if isinstance(r, dict) and r.get('semantic_view')]
    return out


def load_ddl_grants():
    g = []
    for f in DDL_FILES:
        for line in open(f, encoding='utf-8'):
            m = GRANT_RE.match(line)
            if m:
                g.append((m.group(1).upper(), m.group(2).upper()))
    return g


def load_live():
    import snowflake.connector
    tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
    con = snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                      authenticator='oauth', token=tok, role='SECURITYADMIN')
    cur = con.cursor()
    grants = []
    for role in AR.values():
        cur.execute('SHOW GRANTS TO ROLE %s' % role)
        cols = [c[0] for c in cur.description]
        for r in cur.fetchall():
            d = dict(zip(cols, r))
            if d['privilege'] != 'SELECT' or d['granted_on'] not in ('TABLE', 'VIEW', 'SEMANTIC_VIEW', 'SEMANTIC VIEW'):
                continue
            parts = d['name'].replace('"', '').split('.')
            if parts[0] == 'GN_DW' and parts[1] in ('GOLD', 'SERVING'):
                grants.append((role, parts[1] + '.' + parts[2]))
    # 객체 목록은 GN_DW_ADMIN 으로 본다(SECURITYADMIN 은 GN_DW USAGE 가 없다 · 실측 002003)
    con2 = snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                       authenticator='oauth', token=tok, role='GN_DW_ADMIN', warehouse='GN_DW_DEV_WH')
    cur = con2.cursor()
    cur.execute("SELECT TABLE_SCHEMA||'.'||TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_SCHEMA IN ('GOLD','SERVING')")
    objs = {r[0] for r in cur.fetchall()}
    cur.execute('SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING')
    objs |= {'SERVING.' + r[1] for r in cur.fetchall()}
    return grants, objs


def main(argv):
    cls = load_class()
    v = check_wiring(load_agent_svs(), cls) + check_ddl(load_ddl_grants(), cls)
    axes = 'A1·A2'
    if '--live' in argv:
        g, objs = load_live()
        v += check_live(g, cls, objs)
        axes = 'A1·A2·A3'
    for x in v:
        print('🔴', x)
    if v:
        print('🔴 FAIL — %s 위반 %d건' % (axes, len(v)))
        return 1
    print('🟢 PASS — %s 위반 0건 · 분류표 %d객체' % (axes, len(cls)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

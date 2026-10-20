#!/usr/bin/env python3
"""A2 롤 권한 매트릭스 생성 — _ENV/<계정>/A2_Q01·Q02 csv × 설계 csv 대조 → 매트릭스·설계대조·설계외부여 csv + xlsx

🆕 [UNLABELED 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `GEN`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.

사용법
    python3 scripts/a2_matrix_build.py <계정>        # 예: IW20760
    선행 = python3 scripts/env_capture.py --id A2 "85_실제 인수인계 문서/10_실무자_인수인계/A2_롤별_접근권한_근거.sql"

입력
    · 설계 = 85_실제 인수인계 문서/10_실무자_인수인계/A2_롤별_접근권한_설계.csv ([공통])
    · 라이브 = _ENV/<계정>/A2_Q01_*.csv(SHOW GRANTS TO ROLE) · A2_Q02_*.csv(SHOW FUTURE GRANTS)
출력(_ENV/<계정>/ · 전부 [ENV])
    · A2_매트릭스.csv      롤 × 객체종류 × 범위 × 권한 집합 × 객체수/분모 (직접 부여만 · 상속 제외)
    · A2_설계대조.csv      설계 행 펼침 × 판정(OK · PARTIAL · MISSING · NA)
    · A2_설계외부여.csv    라이브에 있으나 설계 행이 덮지 않는 부여(OWNERSHIP 제외)
    · A2_롤별_권한매트릭스.xlsx  요약(롤×스키마) · 설계대조 · 설계외부여 · 매트릭스 · 롤별 시트

판정 규칙
    · 분모 = 그 스키마·종류의 객체 중 **수집한 롤 어딘가에 OWNERSHIP 이 있는 것**(7롤 밖 소유 객체는 분모에서 빠진다).
    · 소유자는 모든 권한을 가진 것으로 본다. 설계 권한 `ALL` = OWNERSHIP 또는 객체 종류별 핵심 권한 집합 보유.
    · FUTURE 의 `ALL` = 그 롤의 FUTURE 행에 SELECT 가 있으면 충족(근사 · 비고에 표시).

종료코드 = 0 성공 · 1 입력 부재 · 2 사용법 오류.
"""
import collections
import csv
import glob
import io
import os
import re
import sys

BASE = '85_실제 인수인계 문서'
DESIGN = os.path.join(BASE, '10_실무자_인수인계', 'A2_롤별_접근권한_설계.csv')
ROLES = ['GN_DW_ADMIN', 'GN_DW_ENGINEER', 'GN_DW_DBT', 'GN_DW_LOADER',
         'GN_DW_SERVICE', 'GN_DW_ANALYST', 'GN_DW_VIEWER']
CORE = {
    'TABLE': {'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'},
    'VIEW': {'SELECT'},
    'PROCEDURE': {'USAGE'},
    'SCHEMA': {'USAGE', 'CREATE TABLE', 'CREATE VIEW'},
}
SCHEMA_SCOPED = ('TABLE', 'VIEW', 'PROCEDURE', 'FUNCTION', 'SEMANTIC_VIEW', 'CORTEX_AGENT',
                 'CORTEX_SEARCH_SERVICE', 'STAGE', 'SEQUENCE', 'FILE_FORMAT', 'DBT_PROJECT',
                 'ALERT', 'TASK', 'DATASET')


def read_csv(path):
    lines = [l for l in io.open(path, encoding='utf-8').read().splitlines() if not l.startswith('#')]
    return list(csv.DictReader(lines))


def norm(name):
    """따옴표 제거 · 프로시저/함수 인자·반환형 절단 · 대문자."""
    n = name.replace('"', '')
    n = re.split(r'[(:]', n, 1)[0]
    return n.strip().upper()


def schema_of(granted_on, name):
    parts = name.split('.')
    if granted_on == 'SCHEMA':
        return parts[1] if len(parts) > 1 else name
    if granted_on in SCHEMA_SCOPED and len(parts) >= 3:
        return parts[1]
    return ''


def fq_scope(granted_on, mode, s):
    """설계 SCOPE 값을 라이브 이름 체계로."""
    if s == '*':
        return '*'
    if granted_on == 'SCHEMA' or mode in ('ALL', 'FUTURE'):
        return s if s.startswith('GN_DW.') else 'GN_DW.' + s
    return s.upper()


def load_live(env_dir):
    direct = collections.defaultdict(set)      # (role, granted_on, obj) -> privs
    for f in sorted(glob.glob(os.path.join(env_dir, 'A2_Q01_*.csv'))):
        for r in read_csv(f):
            role = r.get('grantee_name', '').upper()
            if role not in ROLES:
                continue
            go = r['granted_on'].upper()
            obj = norm(r['name']) if go != 'ACCOUNT' else '*'
            direct[(role, go, obj)].add(r['privilege'].upper())
    future = collections.defaultdict(set)      # (role, 'FUTURE '+type, 'GN_DW.SCH') -> privs
    for f in sorted(glob.glob(os.path.join(env_dir, 'A2_Q02_*.csv'))):
        for r in read_csv(f):
            role = r.get('grantee_name', '').upper()
            if role not in ROLES:
                continue
            sch = '.'.join(norm(r['name']).split('.')[:2])
            future[(role, 'FUTURE ' + r['grant_on'].upper(), sch)].add(r['privilege'].upper())
    return direct, future


def denominators(direct):
    owned = collections.defaultdict(set)       # (granted_on, 'GN_DW.SCH') -> objs
    for (role, go, obj), privs in direct.items():
        if 'OWNERSHIP' in privs:
            sch = schema_of(go, obj)
            if sch:
                owned[(go, 'GN_DW.' + sch)].add(obj)
    return owned


def has(privs, want, go):
    if 'OWNERSHIP' in privs:
        return True
    if want == 'ALL':
        return CORE.get(go, {'USAGE'}) <= privs
    return want in privs


def judge(design, direct, future, owned):
    out, covered = [], set()
    for d in design:
        role, go, mode = d['ROLE'], d['GRANTED_ON'].upper(), d['MODE'].upper()
        for s in d['SCOPE'].split():
            scope = fq_scope(go, mode, s)
            for p in d['PRIVILEGE'].upper().split('+'):
                n = den = ''
                note = d.get('NOTE', '')
                if mode == 'OBJ':
                    privs = direct.get((role, go, scope), set())
                    st = 'OK' if has(privs, p, go) else 'MISSING'
                    covered.add((role, go, scope, p))
                elif mode == 'ALL':
                    objs = owned.get((go, scope), set())
                    hit = [o for o in objs if has(direct.get((role, go, o), set()), p, go)]
                    n, den = len(hit), len(objs)
                    st = 'NA' if den == 0 else ('OK' if n == den else ('MISSING' if n == 0 else 'PARTIAL'))
                    for o in objs:
                        covered.add((role, go, o, p))
                else:
                    privs = future.get((role, go, scope), set())
                    if p == 'ALL':
                        st = 'OK' if 'SELECT' in privs or 'USAGE' in privs else 'MISSING'
                        note = (note + ' · ' if note else '') + 'FUTURE ALL = SELECT/USAGE 존재로 근사'
                        covered.update((role, go, scope, q) for q in privs)
                    else:
                        st = 'OK' if p in privs else 'MISSING'
                    covered.add((role, go, scope, p))
                out.append([role, go, mode, scope, p, st, n, den, d['SOURCE'], note])
    return out, covered


def extras(direct, future, covered):
    agg = collections.Counter()
    for (role, go, obj), privs in direct.items():
        for p in privs:
            if p == 'OWNERSHIP' or (role, go, obj, p) in covered or (role, go, obj, 'ALL') in covered:
                continue
            sch = schema_of(go, obj)
            agg[(role, go, ('GN_DW.' + sch) if sch and go != 'SCHEMA' else obj, p)] += 1
    for (role, go, sch), privs in future.items():
        for p in privs:
            if (role, go, sch, p) not in covered and (role, go, sch, 'ALL') not in covered:
                agg[(role, go, sch, p)] += 1
    return [[k[0], k[1], k[2], k[3], v] for k, v in sorted(agg.items())]


def matrix(direct, future, owned):
    agg = collections.defaultdict(lambda: collections.defaultdict(set))
    for (role, go, obj), privs in direct.items():
        sch = schema_of(go, obj)
        scope = ('GN_DW.' + sch) if sch and go != 'SCHEMA' else obj
        agg[(role, go, scope)]['|'.join(sorted(privs))].add(obj)
    rows = []
    for (role, go, scope), m in sorted(agg.items()):
        den = len(owned.get((go, scope), set())) if go in SCHEMA_SCOPED else ''
        for privset, objs in sorted(m.items()):
            rows.append([role, go, scope, privset.replace('|', '+'), len(objs), den])
    for (role, go, sch), privs in sorted(future.items()):
        rows.append([role, go, sch, '+'.join(sorted(privs)), 'FUTURE', ''])
    return rows


def summary(direct, future):
    """롤 × 스키마 한 칸 요약."""
    cell = collections.defaultdict(list)
    schemas = set()
    for (role, go, obj), privs in direct.items():
        if go == 'SCHEMA':
            sch = schema_of(go, obj)
            schemas.add(sch)
            tag = 'OWN' if 'OWNERSHIP' in privs else ','.join(sorted(p.replace('CREATE ', 'C:') for p in privs))
            cell[(role, sch)].insert(0, 'S[' + tag + ']')
    tbl = collections.defaultdict(set)
    for (role, go, obj), privs in direct.items():
        if go in ('TABLE', 'VIEW', 'SEMANTIC_VIEW', 'CORTEX_AGENT', 'PROCEDURE'):
            sch = schema_of(go, obj)
            tbl[(role, sch, go)].update(['OWN'] if 'OWNERSHIP' in privs else privs)
    for (role, sch, go), privs in tbl.items():
        schemas.add(sch)
        cell[(role, sch)].append(go[0:4] + '[' + ','.join(sorted(privs))[:80] + ']')
    for (role, go, sch), privs in future.items():
        s = sch.split('.')[-1]
        schemas.add(s)
        cell[(role, s)].append('F-' + go.split()[-1][0:4] + '[' + ','.join(sorted(privs))[:60] + ']')
    cols = sorted(x for x in schemas if x)
    return cols, [[r] + [' '.join(cell.get((r, c), [])) for c in cols] for r in ROLES]


def write_csv(path, head, rows, foot):
    sio = io.StringIO()
    sio.write(foot + '\n')
    w = csv.writer(sio, lineterminator='\n')
    w.writerow(head)
    w.writerows(rows)
    io.open(path, 'w', encoding='utf-8').write(sio.getvalue())


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    acct = sys.argv[1].upper()
    env_dir = os.path.join(BASE, '_ENV', acct)
    if not glob.glob(os.path.join(env_dir, 'A2_Q01_*.csv')) or not os.path.exists(DESIGN):
        print('🔴 입력 부재: %s 의 A2_Q01 또는 설계 csv' % env_dir)
        return 1
    design = read_csv(DESIGN)
    direct, future = load_live(env_dir)
    owned = denominators(direct)
    judged, covered = judge(design, direct, future, owned)
    ext = extras(direct, future, covered)
    mat = matrix(direct, future, owned)
    cols, summ = summary(direct, future)
    foot = '# doc_id: A2 · account: %s · 생성 = scripts/a2_matrix_build.py · 설명 = A2_롤별_접근권한_매트릭스.md' % acct

    H1 = ['ROLE', 'GRANTED_ON', 'MODE', 'SCOPE', 'PRIVILEGE', 'STATUS', 'N_HIT', 'N_DENOM', 'SOURCE', 'NOTE']
    H2 = ['ROLE', 'GRANTED_ON', 'SCOPE', 'PRIVILEGE', 'N_OBJECTS']
    H3 = ['ROLE', 'GRANTED_ON', 'SCOPE', 'PRIVILEGES', 'N_OBJECTS', 'N_DENOM']
    write_csv(os.path.join(env_dir, 'A2_설계대조.csv'), H1, judged, foot)
    write_csv(os.path.join(env_dir, 'A2_설계외부여.csv'), H2, ext, foot)
    write_csv(os.path.join(env_dir, 'A2_매트릭스.csv'), H3, mat, foot)

    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Font, PatternFill
    wb = Workbook()
    ws = wb.active
    ws.title = '요약'
    ws.append([foot.lstrip('# ')])
    ws.append(['범례: S[..]=스키마 권한 · TABL/VIEW/SEMA/CORT/PROC[..]=객체 권한 합집합 · F-[..]=FUTURE · OWN=소유'])
    ws.append(['ROLE'] + cols)
    for r in summ:
        ws.append(r)
    for row in ws.iter_rows(min_row=4):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical='top')
    for i, head, rows in (('설계대조', H1, judged), ('설계외부여', H2, ext), ('매트릭스', H3, mat)):
        s = wb.create_sheet(i)
        s.append(head)
        for r in rows:
            s.append(r)
        for c in s[1]:
            c.font = Font(bold=True)
        if i == '설계대조':
            fill = {'MISSING': 'F8CBAD', 'PARTIAL': 'FFE699', 'OK': 'C6EFCE'}
            for row in s.iter_rows(min_row=2):
                color = fill.get(row[5].value)
                if color:
                    row[5].fill = PatternFill('solid', fgColor=color)
    for role in ROLES:
        s = wb.create_sheet(role.replace('GN_DW_', ''))
        s.append(H3)
        for r in mat:
            if r[0] == role:
                s.append(r)
    # 🔴 스테이지 마운트는 seek 미지원(zip 쓰기 Errno 95) ⇒ 메모리에 저장한 뒤 바이트로 한 번에 쓴다
    #    [2026-10-20 실측] 직접 save 실패가 남긴 마운트 유령 때문에 종전 이름(…_접근권한_매트릭스.xlsx)은 열 수 없다(Errno 2 · 스테이지엔 없음)
    buf = io.BytesIO()
    wb.save(buf)
    with open(os.path.join(env_dir, 'A2_롤별_권한매트릭스.xlsx'), 'wb') as fh:
        fh.write(buf.getvalue())

    st = collections.Counter(r[5] for r in judged)
    print('🟢 A2 · account=%s · 설계대조 %d (OK %d · PARTIAL %d · MISSING %d · NA %d) · 설계외부여 %d · 매트릭스 %d'
          % (acct, len(judged), st['OK'], st['PARTIAL'], st['MISSING'], st['NA'], len(ext), len(mat)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

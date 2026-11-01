# 4단계 — 배포: snowflake 적용 ddl/<NN>_*.sql 을 문장 단위로 실행(첫 오류에서 정지) + 사후 실재 점검
#   사용: python3 mstr_deploy.py manifests/1차.json 00 01 02 03 04
#         python3 mstr_deploy.py manifests/1차.json --drop D_CMPGN_EXPL_CD:TABLE   (제외 결정 객체 정리)
#         python3 mstr_deploy.py manifests/1차.json --check                     (매니페스트 ↔ 라이브 대조)
#   🔴 개발계 전용 — 운영 배포는 DCM/정식 절차로. 선두 주석 줄은 떼고 실행(헤더 주석+USE 가 빈 문장 처리되는 사례)
import argparse, glob, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C
from snowflake.connector.util_text import split_statements

KIND_SHOW = {'TABLE': 'TABLES', 'VIEW': 'VIEWS', 'PROCEDURE': 'PROCEDURES', 'FUNCTION': 'USER FUNCTIONS'}


def run_file(cur, path):
    n = 0
    for stmt, _ in split_statements(io.StringIO(io.open(path, encoding='utf-8').read()), remove_comments=False):
        body = re.sub(r'\A(?:\s*--[^\n]*\n)+', '', stmt + '\n').strip()
        if not body or body == ';':
            continue
        n += 1
        try:
            cur.execute(body)
        except Exception as e:
            print('FAIL', os.path.basename(path), 'stmt', n, '::', ' '.join(body.split())[:120])
            print('     ', str(e)[:600])
            return False
    print('DONE', os.path.basename(path), 'stmts', n)
    return True


def live_names(cur, kind):
    cur.execute('SHOW %s IN SCHEMA %s.%s' % (KIND_SHOW[kind], C.TARGET_DB, C.TARGET_SCHEMA))
    cols = [c[0] for c in cur.description]
    rows = cur.fetchall()
    if kind == 'TABLE':
        return {r[cols.index('name')].upper() for r in rows if r[cols.index('kind')] == 'TABLE'}
    if kind == 'PROCEDURE':                                   # SHOW PROCEDURES 는 시스템 내장도 반환
        return {r[cols.index('name')].upper() for r in rows
                if r[cols.index('schema_name')].upper() == C.TARGET_SCHEMA and r[cols.index('is_builtin')] == 'N'}
    return {r[cols.index('name')].upper() for r in rows}


def check(cur, m):
    rc = 0
    want = {k: set(v) for k, v in m['objects'].items()}
    for k, v in m.get('new_objects', {}).items():
        want.setdefault(k, set()).update(v)
    for kind in KIND_SHOW:
        have = live_names(cur, kind)
        miss, extra = sorted(want.get(kind, set()) - have), sorted(have - want.get(kind, set()))
        print('%-9s want %2d live %2d  missing %s  extra %s' % (kind, len(want.get(kind, ())), len(have), miss, extra))
        rc |= bool(miss) or bool(extra)
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('files', nargs='*')
    ap.add_argument('--drop', nargs='*', default=[], metavar='NAME:KIND')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    m = json.load(io.open(a.manifest, encoding='utf-8'))
    cur = C.conn().cursor()
    for d in a.drop:
        name, kind = d.split(':')
        cur.execute('DROP %s IF EXISTS %s.%s.%s' % (kind, C.TARGET_DB, C.TARGET_SCHEMA, name))
        print('DROPPED', kind, name, cur.fetchone())
    for p in a.files:
        f = sorted(glob.glob(os.path.join(C.OUT_DDL, p + '_*.sql')))
        if not f or not run_file(cur, f[0]):
            sys.exit(1)
    if a.check:
        sys.exit(check(cur, m))


if __name__ == '__main__':
    main()

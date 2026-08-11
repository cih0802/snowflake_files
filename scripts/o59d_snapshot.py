# -*- coding: utf-8 -*-
"""[2026-08-11 O59-D] SV 재배포 전/후 불변 대조 스냅샷.

🔴 왜 필요한가: COMMENT 만 고친 재배포라도 **정의·권한이 함께 보존됐는지는 실측해야** 한다
   (P125/P126: `CREATE OR ALTER` 가 GRANT 를 보존한다는 것도 실측으로 확인된 사실이다).
사용: python3 o59d_snapshot.py before|after <SV...>   → /tmp/o59d_<단계>.json
비교: python3 o59d_snapshot.py diff
"""
import sys, os, json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn, q

SCHEMA = 'GN_DW.SERVING'
OUT = '/tmp/o59d_%s.json'


def snap(cn, svs):
    d = {}
    for s in svs:
        _, rows = q(f'desc semantic view {SCHEMA}.{s}', cn)
        expr = {f'{k}.{n}': v for k, n, p, prop, v in rows if prop == 'EXPRESSION'}
        c, g = q(f'show grants on semantic view {SCHEMA}.{s}', cn)
        ci = {x.lower(): i for i, x in enumerate(c)}
        grants = sorted(f"{r[ci['privilege']]}→{r[ci['grantee_name']]}@{r[ci['created_on']]}" for r in g)
        d[s] = {'expr': expr, 'grants': grants}
    return d


def main(argv):
    if argv[0] == 'diff':
        a = json.load(open(OUT % 'before'))
        b = json.load(open(OUT % 'after'))
        bad = 0
        for s in sorted(a):
            for key in ('expr', 'grants'):
                if a[s][key] != b[s][key]:
                    bad += 1
                    print(f'  🔴 {s}.{key} 변동')
                    if key == 'expr':
                        for m in sorted(set(a[s][key]) | set(b[s][key])):
                            if a[s][key].get(m) != b[s][key].get(m):
                                print(f'      {m}: {a[s][key].get(m)!r} → {b[s][key].get(m)!r}')
                    else:
                        print(f'      before {a[s][key]}\n      after  {b[s][key]}')
        n_e = sum(len(a[s]['expr']) for s in a)
        n_g = sum(len(a[s]['grants']) for s in a)
        print(f'[O59-D 불변 대조] SV {len(a)}종 · 정의식 {n_e}개 · GRANT {n_g}건 → '
              + ('🔴 변동 %d건' % bad if bad else '✅ 전건 불변(GRANT created_on 포함)'))
        return 1 if bad else 0
    cn = conn()
    d = snap(cn, argv[1:])
    cn.close()
    json.dump(d, open(OUT % argv[0], 'w'), ensure_ascii=False, indent=1)
    print(f"{argv[0]}: SV {len(d)}종 · 정의식 {sum(len(v['expr']) for v in d.values())}개 · "
          f"GRANT {sum(len(v['grants']) for v in d.values())}건 → {OUT % argv[0]}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

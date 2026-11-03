# 5단계 — 검증: templates/<batch>_verify.sql 의 @CHECK 블록을 실행해 매니페스트 baseline 과 대조
#   사용: python3 mstr_verify.py manifests/1차.json --ym 202601            (대조 · 불일치 시 rc=1)
#         python3 mstr_verify.py manifests/1차.json --ym 202601 --set-baseline  (기준선 기록)
#   🔴 baseline 은 「Snowflake 전환본 자기 회귀」 기준이다. MSTR 원 리포트 대조는 mstr_reference 로 별도 입력
import argparse, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C


def checks(batch, ym):
    text = io.open(os.path.join(C.TEMPLATES, batch + '_verify.sql'), encoding='utf-8').read()
    for m in re.finditer(r'-- @CHECK (\w+)[^\n]*\n(.*?)(?=\n-- @CHECK |\Z)', text, re.S):
        yield m.group(1), m.group(2).strip().rstrip(';').replace('{YM}', ym)


def norm(v):
    # Decimal → float(JSON 비교) · float 는 소수 6자리 반올림
    # 🔴 [O200-D] 부동소수 SUM 은 실행마다 끝자리가 흔들린다(29407.72 ↔ 29407.719999999998) → 오탐 DIFF 방지
    if hasattr(v, 'is_finite'):
        v = float(v)
    return round(v, 6) if isinstance(v, float) else v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--ym', required=True)
    ap.add_argument('--set-baseline', action='store_true')
    a = ap.parse_args()
    m = json.load(io.open(a.manifest, encoding='utf-8'))
    cur = C.conn().cursor()
    got = {}
    for name, sql in checks(m['batch'], a.ym):
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        got[name] = [dict(zip(cols, map(norm, r))) for r in cur.fetchall()]
        print('%-16s %s' % (name, got[name]))
    base = m.setdefault('baseline', {})
    if a.set_baseline:
        base[a.ym] = got
        io.open(a.manifest, 'w', encoding='utf-8').write(json.dumps(m, ensure_ascii=False, indent=1))
        print('BASELINE SET', a.ym)
        return
    if a.ym not in base:
        sys.exit('baseline 없음 — --set-baseline 으로 먼저 기록')
    diff = [k for k in got if got[k] != base[a.ym].get(k)]
    print('PASS' if not diff else 'DIFF ' + ' '.join(diff))
    sys.exit(1 if diff else 0)


if __name__ == '__main__':
    main()

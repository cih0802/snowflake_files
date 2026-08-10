# -*- coding: utf-8 -*-
"""[2026-08-10 O54] SV base 재배선 값 불변 게이트.

base 를 SERVING helper → GOLD 정본으로 바꾼 것은 **값이 같은 객체로의 교체**여야 한다
(행수·PK 유일성 실측 동일 확인). 그 전제를 metric 총계로 실증한다.

사용
  python3 scripts/o54_sv_value_gate.py --snap  before.json   # 배포 전
  python3 scripts/o54_sv_value_gate.py --snap  after.json    # 배포 후
  python3 scripts/o54_sv_value_gate.py --diff  before.json after.json

🔴 P106: 대상이 없는 상태의 통과는 검증이 아니다 → metric 0 개인 SV 는 실패로 본다.
"""
import json
import sys

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn, q

SCHEMA = 'GN_DW.SERVING'
TARGETS = ['SV_MEMBER_MONTHLY', 'SV_MEMBER_EVENT', 'SV_SERVICE',
           'SV_EVENT_PARTICIPATION', 'SV_BUDGET', 'SV_AD', 'SV_DEV_ACHIEVEMENT']


def snap(path):
    cn = conn()
    out, bad = {}, []
    for s in TARGETS:
        _, rows = q(f'desc semantic view {SCHEMA}.{s}', cn)
        mets = [r[1] for r in rows if r[0] == 'METRIC' and r[3] == 'EXPRESSION']
        mets = sorted(set(mets))
        if not mets:
            bad.append(s)
            continue
        cols, vals = q(f"select * from semantic_view({SCHEMA}.{s} metrics "
                       + ', '.join(mets) + ')', cn)
        out[s] = {c: (str(v) if v is not None else None) for c, v in zip(cols, vals[0])}
        print(f'  {s}: metric {len(mets)}개 수집')
    cn.close()
    for b in bad:
        print(f'  🔴 metric 0개 — 공집합 통과 방지(P106): {b}')
    json.dump(out, open(path, 'w'), ensure_ascii=False, indent=1)
    print(f'⇒ {path} 저장 · SV {len(out)}종')
    return 1 if bad else 0


def diff(a, b):
    A, B = json.load(open(a)), json.load(open(b))
    bad = 0
    for s in sorted(set(A) | set(B)):
        if s not in A or s not in B:
            print(f'  🔴 한쪽에만 존재: {s}')
            bad += 1
            continue
        ka, kb = set(A[s]), set(B[s])
        for k in sorted(ka | kb):
            va, vb = A[s].get(k), B[s].get(k)
            if va != vb:
                print(f'  🔴 값 변동 {s}.{k}: {va} → {vb}')
                bad += 1
    print('✅ 전 metric 값 불변' if not bad else f'🔴 불일치 {bad}건')
    return 1 if bad else 0


if __name__ == '__main__':
    if sys.argv[1] == '--snap':
        sys.exit(snap(sys.argv[2]))
    sys.exit(diff(sys.argv[2], sys.argv[3]))

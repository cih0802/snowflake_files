# -*- coding: utf-8 -*-
"""[2026-08-18 O84 / 2026-08-29 O118-B] ML SERVING 뷰 배포 러너 — `21_ML_SERVING_뷰_DDL.sql` 을 문장 단위로 집행한다.

🔴 왜 스크립트인가: 뷰 7 + GRANT 21 = 28문장이고, **소유자가 반드시 `GN_DW_ADMIN`** 이어야 한다
   (DDL §위상-2 = 뷰가 소유자 권한으로 ML 을 읽어 학습 37종을 차폐하는 설계).
   ⇒ 한 세션에서 `USE ROLE` 를 잡고 순서대로 돌린다.

🟢 [O118-B] `ML_MEMBER_RISK_V` dedup 원천이 `SILVER.CRM_MEMBER_STATUS_HIST` 로 교체되어
   7개 뷰 전건 정상 배포 가능하다.
"""
import sys, re, os

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

DDL = '/workspace/05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql'
SKIP_TOKEN = None


def statements(path):
    txt = open(path, encoding='utf-8').read()
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)          # 블록 주석 제거
    txt = '\n'.join(l for l in txt.splitlines() if not l.strip().startswith('--'))
    for raw in txt.split(';'):
        s = raw.strip()
        if s:
            yield s


def label(s):
    m = re.search(r'CREATE OR REPLACE VIEW\s+([A-Za-z0-9_.]+)', s, re.I)
    if m:
        return 'VIEW  ' + m.group(1).split('.')[-1]
    m = re.search(r'GRANT SELECT ON VIEW\s+([A-Za-z0-9_.]+)\s+TO ROLE\s+(\S+)', s, re.I)
    if m:
        return f'GRANT {m.group(1).split(".")[-1]} → {m.group(2)}'
    return s.splitlines()[0][:60]


def main(dry):
    cn = conn()
    cur = cn.cursor()
    ok = skipped = failed = 0
    try:
        for s in statements(DDL):
            lb = label(s)
            if SKIP_TOKEN and SKIP_TOKEN in s:
                print(f'  ⏭  SKIP  {lb}  (MBER_MONTHLY_INFO 부재)')
                skipped += 1
                continue
            if dry:
                print(f'  ·  DRY   {lb}')
                continue
            try:
                cur.execute(s)
                print(f'  🟢 OK    {lb}')
                ok += 1
            except Exception as e:
                print(f'  🔴 FAIL  {lb}\n        {str(e).splitlines()[0][:160]}')
                failed += 1
    finally:
        cur.close()
        cn.close()
    print(f'\n집행 = 성공 {ok} · 건너뜀 {skipped} · 실패 {failed}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main('--dry-run' in sys.argv))

# -*- coding: utf-8 -*-
"""[2026-08-18 O84] ML SERVING 뷰 배포 러너 — `21_ML_SERVING_뷰_DDL.sql` 을 문장 단위로 집행한다.

🔴 왜 스크립트인가: 뷰 6 + GRANT 18 = 24문장이고, **소유자가 반드시 `GN_DW_ADMIN`** 이어야 한다
   (DDL §위상-2 = 뷰가 소유자 권한으로 ML 을 읽어 학습 37종을 차폐하는 설계).
   ⇒ 한 세션에서 `USE ROLE` 를 잡고 순서대로 돌린다.

🔴 `ML_MEMBER_RISK_V` 는 **건너뛴다** — dedup CTE 가 `GN_DW.ML.MBER_MONTHLY_INFO` 를 읽는데
   그 테이블은 사용자가 확정한 「결과 16종만」 이관 범위에서 제외된 학습·중간 37종에 속하고
   계정 전역 조회로 **부재를 확정**했다(`SNOWFLAKE.ACCOUNT_USAGE.TABLES` 0건).
   ⇒ 대체 dedup 을 임의로 만들지 않는다 — O74 가 **dedup 이 지표를 움직인다**고 실측했으므로
     (확률평균 0.3829→0.4418 · ≥0.5 건수 29,690→29,121) 규칙을 바꾸면 발행 설계와 값이 갈린다.
"""
import sys, re, os

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

DDL = '/workspace/05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql'
SKIP_TOKEN = 'ML_MEMBER_RISK_V'      # 차단 대상 — 생성문과 GRANT 전부 건너뛴다.


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
            if SKIP_TOKEN in s:
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

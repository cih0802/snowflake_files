# -*- coding: utf-8 -*-
"""[2026-08-18 O84] ML Semantic View 배포 러너 — `22_ML_SV_DDL.sql` 을 문장 단위로 집행한다.

🔴 왜 별 러너인가: SV DDL 은 `COMMENT`·`AI_SQL_GENERATION` 에 **긴 한국어 문안**을 담는다.
   단순 `split(';')` 은 그 문안 안의 세미콜론에서 문장을 쪼개 **조용히 잘못된 DDL** 을 만든다.
   ⇒ **단일 인용부호 상태를 추적하는 분할기**를 쓴다(`''` 이스케이프 처리 포함).
   🟢 분할 결과는 실행 전에 자기검사한다(문장 수 · 각 문장의 인용부호 짝).

🔴 `SV_ML_MEMBER_RISK` 는 건너뛴다 — base `SERVING.ML_MEMBER_RISK_V` 가 없다.
   그 뷰는 dedup 에 `GN_DW.ML.MBER_MONTHLY_INFO` 를 쓰는데 사용자가 확정한
   「결과 16종만」 이관 범위에서 제외된 테이블이고 계정 전역에 부재다.
"""
import sys, re, os

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

DDL = '/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql'
SKIP_TOKEN = 'SV_ML_MEMBER_RISK'


def strip_comments(txt):
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
    out = []
    for line in txt.splitlines():
        # 🔴 줄 안의 '--' 는 문안에도 나올 수 있으므로 **줄 선두 주석만** 제거한다.
        if line.lstrip().startswith('--'):
            continue
        out.append(line)
    return '\n'.join(out)


def split_sql(txt):
    """단일 인용부호를 인식하는 문장 분할. `''` 는 리터럴 인용부호다."""
    stmts, buf, i, in_q = [], [], 0, False
    while i < len(txt):
        ch = txt[i]
        if ch == "'":
            if in_q and i + 1 < len(txt) and txt[i + 1] == "'":
                buf.append("''")
                i += 2
                continue
            in_q = not in_q
            buf.append(ch)
        elif ch == ';' and not in_q:
            s = ''.join(buf).strip()
            if s:
                stmts.append(s)
            buf = []
        else:
            buf.append(ch)
        i += 1
    s = ''.join(buf).strip()
    if s:
        stmts.append(s)
    return stmts


def target(s):
    """이 문장이 **대상으로 삼는** 객체명. 🔴 문장 전체 부분일치로 판정하면 안 된다 —
    SV COMMENT 는 다른 SV 이름을 **참조 문구**로 담는다(예: SV_ML_SPONSOR_RISK 의 COMMENT 가
    *"회원단위 예측(SV_ML_MEMBER_RISK)과 조인하지 않는다"* 를 담는다).
    초판은 `SKIP_TOKEN in s` 로 판정해 **SV_ML_SPONSOR_RISK 를 잘못 건너뛰었다**(dry-run 이 잡았다).
    ⇒ O82-C 의 「제외 목록이 문자열로 안 맞아 풀렸다」와 같은 계열의 결함이고 처방도 같다: **정규화**."""
    m = re.search(r'CREATE OR ALTER SEMANTIC VIEW\s+([A-Za-z0-9_.]+)', s, re.I)
    if m:
        return m.group(1).split('.')[-1]
    m = re.search(r'GRANT .*?ON SEMANTIC VIEW\s+([A-Za-z0-9_.]+)', s, re.I | re.S)
    if m:
        return m.group(1).split('.')[-1]
    return None


def label(s):
    m = re.search(r'CREATE OR ALTER SEMANTIC VIEW\s+([A-Za-z0-9_.]+)', s, re.I)
    if m:
        return 'SV    ' + m.group(1).split('.')[-1]
    m = re.search(r'GRANT .*ON SEMANTIC VIEW\s+([A-Za-z0-9_.]+)\s+TO ROLE\s+(\S+)', s, re.I | re.S)
    if m:
        return f'GRANT {m.group(1).split(".")[-1]} → {m.group(2)}'
    return s.splitlines()[0][:60]


def main(dry):
    stmts = split_sql(strip_comments(open(DDL, encoding='utf-8').read()))

    # 🔴 자기검사 — 분할이 문안을 쪼갰다면 인용부호 개수가 홀수로 남는다.
    bad = [i for i, s in enumerate(stmts) if s.count("'") % 2 or s.replace("''", '').count("'") % 2]
    print(f'분할 = {len(stmts)}문장 · 인용부호 불균형 {len(bad)}건')
    if bad:
        print('🔴 분할 실패 — 실행하지 않는다')
        return 1

    cn = conn()
    cur = cn.cursor()
    ok = skipped = failed = 0
    try:
        for s in stmts:
            lb = label(s)
            if target(s) == SKIP_TOKEN:
                print(f'  ⏭  SKIP  {lb}  (base ML_MEMBER_RISK_V 부재)')
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
                print(f'  🔴 FAIL  {lb}\n        {str(e).splitlines()[0][:200]}')
                failed += 1
    finally:
        cur.close()
        cn.close()
    print(f'\n집행 = 성공 {ok} · 건너뜀 {skipped} · 실패 {failed}')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main('--dry-run' in sys.argv))

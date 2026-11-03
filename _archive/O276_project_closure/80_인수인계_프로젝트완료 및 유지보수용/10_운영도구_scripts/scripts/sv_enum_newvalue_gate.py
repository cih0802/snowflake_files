#!/usr/bin/env python3
"""SV COMMENT 열거 목록에 없는 라이브 신규값 0 · '실제값 N종' 종수 잔존 0 · O261

🔴 분류 = `JUDGE` — 종료코드가 판정이다(0 통과 · 1 위반 · 2 실행 오류). 음성 테스트 = `scripts/test_sv_enum_newvalue_gate.py`.

축
  STALE_COUNT  COMMENT 에 「실제값 N종」 종수 표기 잔존(O261 에서 폐지 — 값이 늘면 즉시 거짓이 된다)
  NEW          COMMENT 의 ''값'' 목록이 라이브 DISTINCT 의 MIN_COVER 이상을 덮는 차원(=열거 목록 차원)에서
               목록에 없는 라이브 값 — 목록이 낡아 Agent 가 실재 값을 누락한 답을 낸다
대조 제외(오탐 방지) = 라이브 DISTINCT > MAX_LIVE · 목록이 라이브를 MIN_COVER 미만으로 덮음(예시 나열·범위·단위 문구)
                     · 식이 단일 컬럼 참조가 아님.
처방 = NEW 값을 해당 SV 소스 COMMENT 목록에 추가 후 재배포(`tmp/o261/enum_rewrite.py` 참고). 결과 CSV = --out.
"""
import sys
import os
import re
import csv
import json
import argparse

MAX_LIVE, MIN_COVER = 60, 0.5
# 🆕 [O261] 「실제값 N종」만 보던 1판은 변형(「원값 55종」·「실측 값 6종」·「값 3종:」) 18건을 놓쳤다 ⇒ `값 N종` 전반
N_PAT = re.compile(r'값\s*[0-9]+\s*종')
VAL_PAT = re.compile(r"''((?:[^']|'''')*?)''|'((?:[^'])*?)'")
COL_PAT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)$')


def stale_count(comment):
    return bool(N_PAT.search(comment or ''))


def listed_values(comment):
    return [a or b for a, b in VAL_PAT.findall(comment or '')]


def new_values(comment, live_vals):
    """열거 목록 차원이면 목록 밖 라이브 값 리스트, 대조 대상이 아니면 None."""
    listed = listed_values(comment)
    # 🆕 [O273-A] 운영계 ZL50263 실측 — 빈 문자열('')·'/' 든 값(GA4 가 OS 칸에 넣은 Android 빌드 지문
    #   samsung/q4qksx/...:user/release-keys)은 열거 값이 아니다 ⇒ NULL 처럼 대조에서 뺀다
    vals = [v for v in live_vals if v is not None and v.strip() and '/' not in v]
    if not listed or not vals or len(vals) > MAX_LIVE:
        return None
    if sum(v in listed for v in vals) / len(vals) < MIN_COVER:
        return None
    # 🆕 [O272] 아포스트로피가 든 값(I'm your pen)은 따옴표 목록으로 적을 수 없다 ⇒ COMMENT 본문에 그대로 있으면 목록 안으로 본다
    return sorted(v for v in vals if v not in listed and not ("'" in v and v in (comment or '')))


def scan(cur, shard=(0, 1)):
    cur.execute('USE WAREHOUSE ' + os.environ.get('GN_DW_WAREHOUSE', 'GN_DW_DEV_WH'))  # [O262] 덮어쓰기(기본값 불변)
    svs = []
    for sch in ('SERVING', 'MSTR'):
        cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
        ni = [c[0] for c in cur.description].index('name')
        svs += [(sch, r[ni]) for r in cur.fetchall()]
    # 🆕 [O266-B] 분해 실행 — SV 를 이름순으로 정렬해 k/n 조각만 본다(조각끼리 겹치지 않고 합집합 = 전체)
    k, n = shard
    svs = [x for i, x in enumerate(sorted(svs)) if i % n == k]
    rows, cand = [], []
    for sch, sv in svs:
        cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.{sch}.{sv}')
        cols = [c[0].lower() for c in cur.description]
        base, dims = {}, {}
        for d in (dict(zip(cols, r)) for r in cur.fetchall()):
            if d['object_kind'] == 'TABLE':
                base.setdefault(d['object_name'], {})[d['property']] = d['property_value']
            elif d['object_kind'] == 'DIMENSION':
                dims.setdefault((d['parent_entity'], d['object_name']), {})[d['property']] = d['property_value']
        for (tbl, dname), p in dims.items():
            cm = p.get('COMMENT') or ''
            if stale_count(cm):
                rows.append([sv, dname, 'STALE_COUNT', ''])
            m = COL_PAT.match((p.get('EXPRESSION') or '').strip())
            b = base.get(tbl, {})
            fq = '.'.join(x for x in (b.get('BASE_TABLE_DATABASE_NAME'), b.get('BASE_TABLE_SCHEMA_NAME'), b.get('BASE_TABLE_NAME')) if x)
            if not (listed_values(cm) and m and fq.count('.') == 2):
                continue
            cand.append((fq, m.group(1).upper(), sv, dname, cm))
    # 🆕 [O266-B] 컬럼마다 스캔하던 것을 **테이블당 2회**로 묶는다 — 실측(ZS83821) = 무거운 뷰(WIDE_*·ML_*_V)는
    #   컬럼 1개 스캔에 17~42초 · 같은 뷰의 컬럼이 10개 이상이라 조각 1개도 300초를 넘겼다.
    #   ① APPROX_COUNT_DISTINCT 로 고카디널리티 컬럼을 거른다(오차 여유 ×1.2) ② 남은 컬럼만 ARRAY_UNIQUE_AGG 로 값 확보
    #   ③ 정확한 개수(len) 로 MAX_LIVE 를 다시 판정한다 ⇒ 판정식은 종전과 같다.
    checked = 0
    by_fq = {}
    for c in cand:
        by_fq.setdefault(c[0], []).append(c)
    for fq, items in by_fq.items():
        ucols = sorted({c[1] for c in items})
        cur.execute('SELECT ' + ', '.join(f'APPROX_COUNT_DISTINCT("{c}")' for c in ucols) + f' FROM {fq}')
        approx = dict(zip(ucols, cur.fetchone()))
        low = [c for c in ucols if (approx[c] or 0) <= MAX_LIVE * 1.2]
        live = {}
        if low:
            cur.execute('SELECT ' + ', '.join(f'ARRAY_UNIQUE_AGG("{c}"::VARCHAR)' for c in low) + f' FROM {fq}')
            for c, arr in zip(low, cur.fetchone()):
                live[c] = json.loads(arr) if isinstance(arr, str) else (arr or [])
        for _fq, col, sv, dname, cm in items:
            vals = live.get(col)
            if vals is None or len(vals) > MAX_LIVE:
                continue
            new = new_values(cm, vals)
            if new is None:
                continue
            checked += 1
            if new:
                rows.append([sv, dname, 'NEW', '|'.join(new)])
    return len(svs), checked, rows


def main():
    ap = argparse.ArgumentParser()
    # [O262] 기본값 = 워크스페이스면 종전 경로 · 그 밖(80 패키지·로컬)은 실행 폴더
    _ws = '/workspace/tmp'
    ap.add_argument('--out', default=os.path.join(_ws if os.path.isdir(_ws) else os.getcwd(), 'sv_enum_newvalue.csv'))
    # 🆕 [O266-B] 분해 실행 `--shard k/n`(0 ≤ k < n) — 세션 브리핑이 조각을 순차로 돌려 조각당 timeout 을 지킨다
    ap.add_argument('--shard', default='0/1')
    a = ap.parse_args()
    k, n = (int(x) for x in a.shard.split('/'))
    if not 0 <= k < n:
        print(f'🔴 --shard 형식 오류(미판정): {a.shard}')
        return 2
    if n > 1:
        root, ext = os.path.splitext(a.out)
        a.out = f'{root}_{k}of{n}{ext}'
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # [O262] 자기 폴더 기준
        import sfconn
        cn = sfconn.conn()
        try:
            nsv, checked, rows = scan(cn.cursor(), (k, n))
        finally:
            cn.close()
    except Exception as e:  # 실행 실패를 「위반 0」으로 읽지 않게 rc=2
        print(f'🔴 실행 오류(미판정): {e}')
        return 2
    with open(a.out, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['sv', 'dimension', 'kind', 'values'])
        w.writerows(rows)
    for r in rows:
        print(f'  🔴 {r[2]}: {r[0]}.{r[1]} {r[3]}')
    nst = sum(r[2] == 'STALE_COUNT' for r in rows)
    nnew = sum(r[2] == 'NEW' for r in rows)
    print(f'조각 {k}/{n} · SV {nsv} · 목록 대조 차원 {checked} · STALE_COUNT {nst} · NEW {nnew} · 결과 {a.out}')
    if nsv == 0:
        print('🔴 SV 0 = 미판정(조각 분모 없음 · 탐지 경로 고장 의심)')
        return 2
    if checked == 0 and n == 1:
        print('🔴 대조 차원 0 = 미판정(탐지 경로 고장 의심)')
        return 2
    print('✅ 게이트 통과' if not rows else '❌ 게이트 실패')
    return 1 if rows else 0


if __name__ == '__main__':
    sys.exit(main())

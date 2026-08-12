#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""COMMENT 드리프트 상설 게이트 — **파일 정본 ↔ 라이브 물리** 전수 대조.

🔴 왜 필요한가(신설 근거 · O63):
  폐기된 `'미상'` 규약이 O26 → O61 → O62 를 **세 세션 통과해 살아남았다.** 통과한 이유는 단순하다 —
  파일과 라이브를 **전수로 대조하는 상설 장치가 없었다.** 매번 그 세션이 의심한 몇 컬럼만 손으로 봤고,
  O62 는 그 손대조에서 이스케이프를 값으로 착각해 「드리프트가 있다」고 **반대로** 판정했다(P223).
  ⇒ 이 게이트는 「몇 개를 봤나」가 아니라 **분모를 고정**한다.

대조 축(소유주 규약 = `dbt_project.yml` 소유주 표):
  · GOLD **테이블** 컬럼 COMMENT  ← `03_top-down_gold/06_DDL.sql`      (라이브 반영 = `ALTER` 직접 · P199)
  · GOLD **뷰**   컬럼 COMMENT  ← `10_dbt_pipeline/.../_wide_schema.yml` (라이브 반영 = `dbt build` 만 · O51)
  · SILVER **테이블** 컬럼 COMMENT ← `04_silver_design/08_SILVER_테이블DDL_*.sql` (라이브 반영 = `ALTER` 직접)

🔴 **범위를 이름과 맞춰야 한다(O63 자기검토 2회차 적발)**: 최초 판본은 이름이 `comment_drift_gate` 인데
   GOLD 만 대조하고 **SILVER 717컬럼을 통째로 빼놓았다.** 「분모를 고정한다」고 쓰면서 분모가 부분집합이면
   그것은 O63 이 직접 정정한 「전체 재스캔」 과대주장과 같은 결함이다 ⇒ SILVER 축을 추가했다.

⚠️ 값 비교 규약(P223): 파일은 SQL 리터럴/YAML 이라 `''`·인용이 **저장 표현**이다.
   언이스케이프한 **값**으로 비교하고 판정은 **SHA256** 으로 낸다. 길이 일치는 보조 근거일 뿐이다.
⚠️ 뷰 계열은 `dbt build` 전에는 불일치가 **정상**이다 — 그 상태를 숨기지 않고 `PENDING` 으로 분류해 보고한다
   (`P214`: 부재·미반영을 기준선에 굳히지 않는다).

🔴 **[2026-08-12 O64] 금지 문안 검사를 이 게이트로 흡수했다 — 「일치」만 보면 놓치는 결함이 있다.**
   드리프트 대조는 파일 == 라이브만 판정하므로 **양쪽이 같이 틀린 문안을 발행하고 있으면 통과**한다.
   그것이 O63 이 실제로 발견한 상태였다(폐기 `'미상'` 규약을 파일·라이브가 함께 보유 = 드리프트 0 · 결함 20곳).
   ⇒ 일치 축과 **별개로 값 자체를 검사**하는 축이 필요하다. 두 축을 넣었다:
     · **폐기 규약 토큰**(`R2-7-1`) — 「미매핑은 '미상'」·「NULL→'미상'」 계열. 종전엔 `verify_o63_comments.py` 가
       8컬럼에만 걸어 뒀고 그 스크립트는 파일측만 봤다 ⇒ 여기서 **전 표면 × 파일·라이브 양측**으로 넓혔다.
     · **자기 지칭 오표기**(O63-J ③) — BASE TABLE 컬럼 COMMENT 가 자기를 「이 뷰/본 뷰」로 부르는 것.
       유래 = SERVING helper **뷰** → GOLD BASE TABLE 승격 시 문안이 안 따라온 것이라 재발 경로가 상존한다.
   ⚠️ 자기 지칭 검사는 **BASE TABLE 표면에만** 적용한다 — `WIDE_*` 는 실제 VIEW 라 「본 뷰」가 정상이다.

사용법
  python3 scripts/comment_drift_gate.py                 # 전 표면
  python3 scripts/comment_drift_gate.py --surface table # GOLD 테이블만 (build 무관 · 항상 0 이어야 한다)
  python3 scripts/comment_drift_gate.py --detail        # 불일치 스니펫
종료코드: 테이블 계열 불일치·금지 문안이 있으면 1. 뷰 계열 불일치는 `--strict-view` 를 주면 1, 기본은 경고.
Co-authored with CoCo
"""
import argparse
import hashlib
import io
import re
import sys

sys.path.insert(0, '/workspace/scripts')
import sfconn  # noqa: E402

DDL = '/workspace/03_top-down_gold/06_DDL.sql'
SILVER_DDL = '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'
YML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'

RE_TABLE = re.compile(r'CREATE (?:OR REPLACE )?TABLE (?:IF NOT EXISTS )?GN_DW\.GOLD\.(\w+)\s*\(')
RE_SILVER = re.compile(r'CREATE (?:OR REPLACE )?TABLE (?:IF NOT EXISTS )?GN_DW\.SILVER\.(\w+)\s*\(')
RE_COL = re.compile(r"^\s+([A-Z][A-Z0-9_]*)\s+\S+.*?COMMENT\s+'(.*)'\s*,?\s*(?:--.*)?$")
RE_YML_MODEL = re.compile(r'^  - name: (\w+)\s*$')
RE_YML_COL = re.compile(r'^      - name: (\w+)\s*$')
RE_YML_DESC = re.compile(r'^        description: "(.*)"\s*$')

# 폐기 규약(R2-7-1) 재유입 차단. 부정형 인용까지 잡지 않도록 「지시 형태」만 좁게 본다.
BANNED = [(re.compile(r"미매핑\s*(?:은|→)\s*'?미상"), "미매핑을 '미상' 으로 지시"),
          (re.compile(r"NULL\s*→\s*'?미상"), "NULL 을 '미상' 으로 지시")]
# BASE TABLE 이 자기를 뷰로 부르는 문안(O63-J ③). VIEW 표면에는 적용하지 않는다.
SELF_VIEW = [(re.compile(r'(?:이|본)\s*뷰(?:는|에|가|를|의|와|도)?\b'), '자기를 「뷰」로 지칭')]


def sha(s):
    return hashlib.sha256(s.encode()).hexdigest()[:16]


def parse_ddl(path=DDL, rx=RE_TABLE):
    """DDL 의 테이블 컬럼 COMMENT 를 값으로 뽑는다(`''`→`'` 언이스케이프)."""
    src = io.open(path, encoding='utf-8').read()
    hits = [(m.start(), m.group(1)) for m in rx.finditer(src)]
    out = {}
    for i, (pos, tbl) in enumerate(hits):
        end = hits[i + 1][0] if i + 1 < len(hits) else len(src)
        for line in src[pos:end].split('\n'):
            m = RE_COL.match(line)
            if m:
                out[f'{tbl}.{m.group(1)}'] = m.group(2).replace("''", "'")
    return out


def parse_yml():
    """_wide_schema.yml 의 columns[].description 을 값으로 뽑는다(YAML 이중인용 언이스케이프)."""
    out, model, col = {}, None, None
    for line in io.open(YML, encoding='utf-8'):
        line = line.rstrip('\n')
        m = RE_YML_MODEL.match(line)
        if m:
            model, col = m.group(1), None
            continue
        m = RE_YML_COL.match(line)
        if m:
            col = m.group(1)
            continue
        m = RE_YML_DESC.match(line)
        if m and model and col:
            out[f'{model}.{col}'] = m.group(1).replace('\\"', '"')
            col = None
    return out


def live(cn, kinds, schema='GOLD'):
    sql = f"""
        SELECT c.TABLE_NAME||'.'||c.COLUMN_NAME, COALESCE(c.COMMENT,'')
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS c
        JOIN GN_DW.INFORMATION_SCHEMA.TABLES t
          ON t.TABLE_SCHEMA=c.TABLE_SCHEMA AND t.TABLE_NAME=c.TABLE_NAME
        WHERE c.TABLE_SCHEMA='{schema}' AND t.TABLE_TYPE IN ({kinds})
    """
    _, rows = sfconn.q(sql, cn)
    return {k: v for k, v in rows}


def compare(label, want, got, detail, pending):
    same = diff = only_file = 0
    bad = []
    for k, v in sorted(want.items()):
        if k not in got:
            only_file += 1
            continue
        if sha(v) == sha(got[k]):
            same += 1
        else:
            diff += 1
            bad.append(k)
    tag = 'PENDING(build 대기)' if pending and diff else ''
    print(f'  {label}: 파일 {len(want)} · 대조 {same + diff} · '
          f'🟢일치 {same} · {"🟡" if pending else "🔴"}불일치 {diff} {tag} · ⚪라이브부재 {only_file}')
    if bad:
        print(f'    불일치 컬럼: {", ".join(bad[:12])}{" …" if len(bad) > 12 else ""}')
        if detail:
            for k in bad[:5]:
                print(f'    · {k}\n      파일 = {want[k][:110]}\n      라이브 = {got[k][:110]}')
    return diff


def scan_banned(label, mapping, rules):
    """값 자체를 검사하는 축 — 드리프트(일치) 축이 못 잡는 결함을 잡는다."""
    hits = []
    for k, v in sorted(mapping.items()):
        for rx, why in rules:
            if rx.search(v):
                hits.append((k, why))
                break
    mark = '🔴' if hits else '🟢'
    print(f'  {mark} {label}: 검사 {len(mapping)} · 위반 {len(hits)}')
    for k, why in hits[:12]:
        print(f'    · {k} — {why}')
    if len(hits) > 12:
        print(f'    … 외 {len(hits) - 12}건')
    return len(hits)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--surface', choices=['table', 'view', 'silver', 'all'], default='all')
    ap.add_argument('--detail', action='store_true')
    ap.add_argument('--strict-view', action='store_true')
    a = ap.parse_args()

    print('[COMMENT 드리프트 게이트] 파일 정본 ↔ 라이브 물리 · 판정 = SHA256(언이스케이프 값) · P223')
    cn = sfconn.conn()
    try:
        fail = 0
        gold_tbl_file = gold_tbl_live = None
        slv_file = slv_live = None
        if a.surface in ('table', 'all'):
            gold_tbl_file, gold_tbl_live = parse_ddl(), live(cn, "'BASE TABLE'")
            fail += compare('GOLD 테이블 (06_DDL.sql)', gold_tbl_file,
                            gold_tbl_live, a.detail, pending=False)
        if a.surface in ('silver', 'all'):
            slv_file = parse_ddl(SILVER_DDL, RE_SILVER)
            slv_live = live(cn, "'BASE TABLE'", 'SILVER')
            fail += compare('SILVER 테이블 (08_SILVER_테이블DDL)', slv_file,
                            slv_live, a.detail, pending=False)
        view_file = view_live = None
        if a.surface in ('view', 'all'):
            view_file, view_live = parse_yml(), live(cn, "'VIEW'")
            d = compare('GOLD 뷰 (_wide_schema.yml)', view_file,
                        view_live, a.detail, pending=not a.strict_view)
            fail += d if a.strict_view else 0
            if d and not a.strict_view:
                print('    ⛔ 뷰 계열은 `dbt build` 로만 반영된다(O51) — 위 불일치는 build 전 정상 상태다.')

        # [O64] 값 검사 축 — 파일·라이브 양측 모두 본다(한쪽만 보면 O63 상태를 놓친다)
        print('\n[금지 문안 검사] 폐기 규약(R2-7-1) · BASE TABLE 자기 「뷰」 지칭(O63-J ③)')
        surfaces = [('GOLD 테이블 파일', gold_tbl_file, True), ('GOLD 테이블 라이브', gold_tbl_live, True),
                    ('SILVER 테이블 파일', slv_file, True), ('SILVER 테이블 라이브', slv_live, True),
                    ('GOLD 뷰 파일', view_file, False), ('GOLD 뷰 라이브', view_live, False)]
        for label, mapping, is_table in surfaces:
            if mapping is None:
                continue
            rules = BANNED + SELF_VIEW if is_table else BANNED
            fail += scan_banned(label, mapping, rules)
    finally:
        cn.close()

    if fail:
        print(f'\n🔴 게이트 실패 — 위반 {fail}건. 파일이 정본이므로 파일을 확정한 뒤 라이브에 반영할 것.')
        sys.exit(1)
    print('\n✅ 게이트 통과 — 드리프트 0 · 금지 문안 0')


if __name__ == '__main__':
    main()

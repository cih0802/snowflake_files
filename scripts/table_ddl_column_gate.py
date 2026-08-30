#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
O53 — **DDL 선언 ↔ dbt 모델 SELECT 컬럼 대조 게이트** (테이블 전용).
Co-authored with CoCo

⛔ 왜 이 파일이 필요한가 (거짓 안전 차단)
   `scripts/o51d_view_comments/gate.py` 는 **뷰**만 본다 — 모델 SELECT alias ↔ yml `columns[]` 순서를
   대조하는 게이트이고, 그 전제는 「`CREATE VIEW` 컬럼목록이 SELECT 와 일치해야 한다」는 Snowflake 제약이다.
   O53 에서 3객체를 **테이블**로 전환하면서 그 3종을 gate.py 대상에서 제외했는데,
   🔴 제외만 하고 **대체 검사를 만들지 않으면 그 3종은 아무 게이트도 보지 않는 상태**가 된다(P16).
   실제로 O53 4단계 자기검토에서 이 공백을 적발했다 — 본 파일이 그 공백을 메운다.

무엇을 검사하는가
   `06_DDL.sql` 이 선언한 컬럼(이름·순서) ↔ dbt 모델의 **실제 출력 컬럼**(이름·순서)
   · 불일치 유형 3종을 구분해 보고한다: **누락**(DDL 에만) · **초과**(모델에만) · **순서 어긋남**
   · 왜 중요한가: dbt fact/dim 은 `incremental + append` 라 **INSERT 가 컬럼 위치로 매칭**된다.
     이름 집합이 같아도 **순서가 다르면 값이 엉뚱한 컬럼에 들어간다** — 에러 없이 조용히.
     `on_schema_change: append_new_columns` 는 「모델에만 있는 신규 컬럼」만 ALTER 하고
     순서 문제는 전혀 보지 않는다(O42 실측).

어떻게 판정하는가 (정규식 파싱을 신뢰하지 않는다)
   모델 SQL 을 최소 렌더(`ref()`·`gold_meta()`·`config()`)한 뒤 **Snowflake 에 `LIMIT 0` 으로 물어**
   커서 메타데이터에서 컬럼명·순서를 받는다. 정규식으로 SELECT 를 해석하면 CTE·윈도우·주석에서 틀린다.
   ⚠️ 이 판정은 `dbt build` **이전**에 가능하다 — 물리 테이블이 아니라 모델 정의를 보기 때문이다(P120).
"""
import io
import re
import sys

sys.path.insert(0, '/workspace/scripts')
import sfconn  # noqa: E402

DDL = '/workspace/03_top-down_gold/06_DDL.sql'
MB = '/workspace/10_dbt_pipeline/models/gold/'
TARGETS = {
    'DIM_MONTH':              MB + 'dim/DIM_MONTH.sql',
    'DIM_MEMBER_CURRENT':     MB + 'dim/DIM_MEMBER_CURRENT.sql',
    'DIM_MEMBER_ACQUISITION': MB + 'dim/DIM_MEMBER_ACQUISITION.sql',
    'FACT_DEV_ACHIEVEMENT':   MB + 'fact/FACT_DEV_ACHIEVEMENT.sql',
    # 🔴 [2026-08-11 O59-N] **분모 확장.** 종전 대상은 O53 신규 4종뿐이어서, 다른 테이블에 컬럼을
    #   추가하면 **어떤 게이트도 순서를 보지 않았다**(P197 계열: 게이트의 분모를 세지 않으면 공백이 보이지 않는다).
    #   DEC-35 1·2단계로 이 3종에 라벨 컬럼을 신설했으므로 함께 검사한다.
    #   ⚠️ 여기 없는 GOLD 테이블은 여전히 미검사다 — 컬럼을 건드리면 이 표에 추가할 것.
    'DIM_EVENT':                MB + 'dim/DIM_EVENT.sql',
    'FACT_EVENT_PARTICIPATION': MB + 'fact/FACT_EVENT_PARTICIPATION.sql',
    'FACT_SERVICE_EVENT':       MB + 'fact/FACT_SERVICE_EVENT.sql',
}
AUDIT_SQL = ("'{src}' AS DW_SOURCE_SYSTEM,\n"
             "CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS,\n"
             "CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS,\n"
             "'gate' AS DW_BATCH_ID")


def ddl_columns(table):
    """06_DDL.sql 의 CREATE 블록에서 선언 컬럼을 순서대로 뽑는다(정본)."""
    s = io.open(DDL, encoding='utf-8').read()
    i = s.index(f'CREATE OR REPLACE TABLE GN_DW.GOLD.{table} (')
    # 🔴 [2026-08-11 O59-N] 종전 경계는 `s.index(';', i)` 였다 — **COMMENT 문안 속 `;` 에 걸려 블록이
    #   조용히 잘린다**(같은 결함을 `audit_ddl_rule7.py` 에서 실측 확인: 파싱 579/619 · 진짜 위반 11건 은닉).
    #   블록이 잘리면 이 게이트는 **DDL 컬럼을 적게 읽고 「누락 0」을 보고**한다 = 거짓 안전.
    #   ⇒ 경계를 블록 종료 토큰 `\n) COMMENT =` 로 잡는다(P195: 같은 규약은 판정식을 1벌로).
    j = s.index('\n) COMMENT =', i)
    out = []
    for line in s[i:j].split('\n')[1:]:
        t = line.strip()
        if not t or t.startswith('--') or t.startswith('PRIMARY KEY') or t.startswith(')'):
            continue
        m = re.match(r'([A-Z0-9_]+)\s+', t)
        if m:
            out.append(m.group(1))
    return out


def resolve_ref(cn, name):
    """ref(name) → 실제 FQN. GOLD 우선, 없으면 SILVER."""
    cur = cn.cursor()
    for sch in ('GOLD', 'SILVER'):
        cur.execute(f"""select count(*) from GN_DW.INFORMATION_SCHEMA.TABLES
                        where table_schema='{sch}' and table_name='{name}'""")
        if cur.fetchone()[0]:
            return f'GN_DW.{sch}.{name}'
    sys.exit(f'🔴 ref 해석 실패: {name} (GOLD·SILVER 어디에도 없다)')


def render(cn, path):
    s = io.open(path, encoding='utf-8').read()
    # config 블록은 내부에 `{{ this }}` 가 중첩될 수 있어 정규식 [^}]* 로는 끊긴다 → 스캔으로 제거
    while '{{ config(' in s:
        i = s.index('{{ config(')
        j = s.index(') }}', s.index('(', i + 8))
        # 중첩 jinja 를 지나 실제 config 종료 지점을 찾는다
        k = i
        while True:
            j = s.find(') }}', k)
            if j == -1:
                sys.exit('🔴 config 블록 종료를 찾지 못했다')
            # ') }}' 뒤가 SQL 본문 시작(빈줄/select/with/주석)이면 그 지점이 종료다
            tail = s[j + 4:j + 40].lstrip()
            if tail.startswith(('select', 'with', '--', '\n')) or tail == '':
                break
            k = j + 4
        s = s[:i] + s[j + 4:]
    s = re.sub(r"\{\{\s*gold_meta\('([A-Z0-9_]+)'\)\s*\}\}",
               lambda m: AUDIT_SQL.format(src=m.group(1)), s)
    s = re.sub(r"\{\{\s*ref\('([A-Z0-9_]+)'\)\s*\}\}",
               lambda m: resolve_ref(cn, m.group(1)), s)
    # 프로젝트 매크로 — 정본 = macros/gold_helpers.sql. 컬럼 이름·순서 판정에만 쓰이므로 식은 등가면 된다.
    # 🔴 [2026-08-11 O59-N] 인자 따옴표를 벗겨야 한다 — 종전 패턴은 `"` 만 고려해 `date_sk('x::DATE')`
    #   에서 **작은따옴표째로 치환**돼 `TO_CHAR('p.PARTCPT_DT::DATE','YYYYMMDD')` 가 됐다(실측 컴파일 에러).
    #   대상을 넓히기 전에는 이 형태를 쓰는 모델이 없어 드러나지 않았다(P197: 분모가 좁으면 결함도 숨는다).
    def _arg(x):
        return x.strip().strip('\'"')
    s = re.sub(r'\{\{\s*month_key\(\s*[\'"]?([^\'")]+)[\'"]?\s*\)\s*\}\}',
               lambda m: f"TRY_TO_NUMBER(TO_CHAR({_arg(m.group(1))}, 'YYYYMM'))", s)
    s = re.sub(r'\{\{\s*date_sk\(\s*[\'"]?([^\'")]+)[\'"]?\s*\)\s*\}\}',
               lambda m: f"TRY_TO_NUMBER(TO_CHAR({_arg(m.group(1))}, 'YYYYMMDD'))", s)
    s = re.sub(r'\{\{\s*month_key_clamp\(\s*[\'"]?([^\'")]+)[\'"]?\s*\)\s*\}\}',
               lambda m: f"({_arg(m.group(1))})", s)
    # 🔴 [2026-08-11 O59-N] `gold_sk()` 미지원이라 대상을 넓히자마자 게이트가 죽었다(leftover jinja).
    #   정본 = macros/gold_helpers.sql `gold_sk` = ABS(HASH(COALESCE(CAST(c AS VARCHAR),'∅') || '‖' || …)).
    #   ⚠️ 컬럼 이름·순서 판정용이므로 **값이 아니라 타입·개수만 등가**면 된다.
    def _gold_sk(m):
        cols = [c.strip().strip('\'"') for c in m.group(1).split(',')]
        expr = " || '‖' || ".join(f"COALESCE(CAST({c} AS VARCHAR), '∅')" for c in cols)
        return f"ABS(HASH({expr}))"
    s = re.sub(r"\{\{\s*gold_sk\(\[([^\]]*)\]\)\s*\}\}", _gold_sk, s)
    leftover = re.findall(r'\{\{[^}]*\}\}', s)
    if leftover:
        sys.exit(f'🔴 렌더되지 않은 jinja 가 남았다 — 게이트를 신뢰할 수 없다: {leftover[:3]}')
    return s.strip().rstrip(';')


def model_columns(cn, path):
    sql = render(cn, path)
    cur = cn.cursor()
    cur.execute(f'select * from (\n{sql}\n) limit 0')
    return [d[0] for d in cur.description]


def self_check(cn):
    """게이트 탐지력 실증(P106) — 일치 상태에서만 돌린 게이트는 검증이 아니다.
    DDL 측 컬럼목록을 일부러 훼손해 3가지 불일치 유형을 각각 잡는지 본다."""
    print('게이트 자기검사 (P106 — 탐지력 실증)\n')
    table, path = 'DIM_MONTH', TARGETS['DIM_MONTH']
    base_d = ddl_columns(table)
    base_m = model_columns(cn, path)
    swapped = base_d[:]
    swapped[1], swapped[2] = swapped[2], swapped[1]
    cases = [
        ('정상(대조군)',   base_d,                    []),
        ('DDL 에만 1건',   base_d + ['GHOST_COL'],     ['누락']),
        ('모델에만 1건',   [c for c in base_d if c != 'QUARTER'], ['초과']),
        ('순서만 어긋남',  swapped,                    ['순서']),
    ]
    ok = 0
    for label, d, expect in cases:
        missing = [c for c in d if c not in base_m]
        extra = [c for c in base_m if c not in d]
        got = ([] + (['누락'] if missing else []) + (['초과'] if extra else [])
               + (['순서'] if d != base_m and not missing and not extra else []))
        hit = sorted(set(got)) == sorted(set(expect))
        ok += hit
        print(f"  {label:<16} 기대={expect or '없음'} 실제={got or '없음'} {'✅' if hit else '🔴'}")
    print(f"\n자기검사 {ok}/{len(cases)} 일치")
    if ok != len(cases):
        sys.exit('🔴 게이트가 기대대로 탐지하지 못한다')

    # 🔴🔴 [2026-08-30 O121-B 신설 축] **severity 매핑이 무력화가 아님을 단정한다.**
    #    O121-B 가 「순서 드리프트」를 blocking → advisory 로 강등했다(O120 실측 근거).
    #    🔴 강등이 「검사 끄기」로 기울면 진짜 위험(집합 불일치)까지 조용해진다 ⇒ 양방향으로 못박는다.
    #    판정식 = 누락·초과는 **blocking** 이고 순서만 어긋난 경우는 **blocking 이 아니다**.
    print('\nseverity 매핑 자기검사 (강등이 무력화가 아님을 단정)')
    sev_cases = [
        ('누락 → blocking', base_d + ['GHOST_COL'], True),
        ('초과 → blocking', [c for c in base_d if c != 'QUARTER'], True),
        ('순서만 → advisory(blocking 아님)', swapped, False),
        ('정상 → blocking 아님', base_d, False),
    ]
    sok = 0
    for label, d, want_block in sev_cases:
        missing = [c for c in d if c not in base_m]
        extra = [c for c in base_m if c not in d]
        got_block = bool(missing or extra)
        hit = (got_block == want_block)
        sok += hit
        print(f"  {label:<34} blocking 기대={want_block} 실제={got_block} {'✅' if hit else '🔴'}")
    print(f"\nseverity 자기검사 {sok}/{len(sev_cases)} 일치")
    if sok != len(sev_cases):
        sys.exit('🔴 severity 매핑이 어긋난다 — 강등이 진짜 위험까지 껐을 수 있다')


def main():
    cn = sfconn.conn()
    cn.cursor().execute('USE WAREHOUSE GN_DW_DEV_WH')
    if '--self-check' in sys.argv:
        self_check(cn)
        cn.close()
        return
    cn.cursor().execute('USE WAREHOUSE GN_DW_DEV_WH')
    fails = 0
    drift = 0
    print('DDL 선언 ↔ dbt 모델 출력 컬럼 대조 (적재 전 판정 · P120)')
    print('  🔴 blocking = **집합** 불일치(누락·초과) · 🟠 advisory = **순서** 드리프트(문서 축)\n')
    for table, path in TARGETS.items():
        d = ddl_columns(table)
        m = model_columns(cn, path)
        missing = [c for c in d if c not in m]          # DDL 에만 = 모델이 안 채운다
        extra = [c for c in m if c not in d]            # 모델에만 = append 시 자동 ALTER 대상(드리프트)
        order_ok = (d == m)
        mism = [] if order_ok else [f'{k+1}:{a}≠{b}' for k, (a, b)
                                    in enumerate(zip(d, m)) if a != b][:5]
        # 🔴🔴 [2026-08-30 O121-B] **두 축을 분리했다 — 종전에는 둘을 합쳐 blocking 이었다.**
        #    · 집합 불일치(누락·초과) = 🔴 **blocking**. 모델이 컬럼을 안 채우거나 물리가 정본을
        #      앞서 나간 것이므로 실데이터 위험이다.
        #    · 순서 드리프트 = 🟠 **advisory(문서 축)**. O120 이 실측으로 확정했다:
        #      dbt 가 실제로 실행한 SQL 은 `insert into T ("A","B",…) (select "A","B",… )` 로
        #      **양측 모두 이름 지정**이므로(`10_dbt_pipeline/logs/dbt.log:314-316`)
        #      **위치 오삽입은 원리적으로 불가**하다.
        #    🔴 종전 경고문(*"append 는 위치로 INSERT 한다 ⇒ 값이 다른 컬럼에 들어간다"*)은
        #      **사실과 달랐고**, O120 은 그것을 알면서 문안을 고치지 않아 게이트가 **영구 빨강**이었다.
        #      영구 빨강 게이트는 무력화된다(`O119-B` 원칙 = *"항상 빨간 게이트는 무력화된다"*).
        blocking = bool(missing or extra)
        fails += blocking
        drift += (not order_ok)
        print(f"  {table:<24} DDL {len(d):>2} · 모델 {len(m):>2} · "
              f"누락 {len(missing)} · 초과 {len(extra)} · 순서 {'일치' if order_ok else '불일치'} "
              f"{'🔴' if blocking else ('🟠' if not order_ok else '✅')}")
        if missing:
            print(f"     🔴 DDL 에만(모델이 채우지 않는다): {', '.join(missing)}")
        if extra:
            print(f"     🔴 모델에만(물리가 정본보다 앞서 나간다 · O30 유형): {', '.join(extra)}")
        if mism:
            print(f"     🟠 순서 드리프트(앞 5건): {', '.join(mism)}")
            print("        🟢 적재는 안전하다 — dbt insert 는 **양측 이름 지정**이라 위치 오삽입이")
            print("           원리적으로 불가하다(O120 실측 · logs/dbt.log:314-316).")
            print("        🔴 이 경고를 근거로 모델·DDL 을 고치지 마라 — 고칠 것은 **DDL 파일의")
            print("           컬럼 선언 순서**이고 그것은 문서 축이다(집합은 이미 일치한다).")
    cn.close()
    print()
    print(f'집합 불일치(blocking) {fails}건 · 순서 드리프트(advisory) {drift}건 / 대상 {len(TARGETS)}개')
    if fails:
        sys.exit(f'🔴 {fails}/{len(TARGETS)} 객체 **집합** 불일치 — 모델이 컬럼을 채우지 않거나 '
                 f'물리가 정본을 앞서 나갔다. 적재 전에 정본을 맞출 것.')
    if drift:
        print(f'🟠 순서 드리프트 {drift}건 — **문서 축이며 적재 위험이 아니다**(종료코드 무영향).')
        print('   🔴 다만 「파일이 정본」 주장은 약해진다 ⇒ DDL 파일 선언 순서를 모델에 맞출 것.')
    print(f'✅ 집합 일치 {len(TARGETS)}/{len(TARGETS)} — 적재 안전')


if __name__ == '__main__':
    main()

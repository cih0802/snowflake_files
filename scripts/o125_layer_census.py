# O125 — 설계 정본(dbt 모델 · SV DDL · 배포 스크립트) ↔ 라이브 SILVER/GOLD/SERVING 실재 대조
# Co-authored with CoCo
#
# 🔴🔴 이 도구가 판정하는 축과 판정하지 않는 축을 먼저 읽어라(O125-B 자기검토 처방).
#   판정한다   = ㉠ 객체 실재(테이블·뷰·시맨틱뷰 이름 집합) ㉡ 컬럼 **이름 집합**
#   판정하지 않는다 = ㉢ 컬럼 **값 적재**(전건 0/NULL 센티넬) ㉣ 컬럼 **선언 순서**
#                     ㉤ SV metric 값의 정합성 ㉥ 설계 「청사진」 절과의 대조
#   🔴 ㉢ 을 이 도구의 ✅ 로 덮어 읽으면 **「구성됐다」를 「작동한다」로 오독**한다 —
#      GOLD 팩트의 measure·차원FK 는 지금도 대규모로 전건 0 이다(정본 = 문서50 `BLOCKING-5`).
#   🔴 ㉣ 은 `table_ddl_column_gate` 소관(순서 드리프트) · ㉤ 은 `sv_unit_gate`·VQR 소관 ·
#      ㉥ 은 `05_SV-Agent_ai/04_SV_설계.md` **§0.9**(배포 상태 정본)가 담당한다.
#   🟢 그래서 이 도구는 마지막에 **값 축 표본을 함께 재고** 정본 좌표를 출력한다(단정 대체 금지).
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sfconn  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / '10_dbt_pipeline' / 'models'
SV_DIR = ROOT / '05_SV-Agent_ai'


def model_names(subdir):
    base = MODELS / subdir
    return {p.stem.upper() for p in base.rglob('*.sql')}


def sv_names_from_files():
    """SV DDL 파일 · 배포 스크립트에서 CREATE ... SEMANTIC VIEW 이름을 뽑는다."""
    # 🔴 정본 DDL 은 `CREATE OR ALTER SEMANTIC VIEW` 다(OR REPLACE 가 아니다).
    #    초판이 OR REPLACE 만 봐서 분모 0 을 냈다 — 「0건」은 판정식 결함 신호였다.
    pat = re.compile(
        r'CREATE\s+(?:OR\s+(?:REPLACE|ALTER)\s+)?SEMANTIC\s+VIEW\s+([A-Za-z0-9_.$"]+)',
        re.IGNORECASE,
    )
    names = {}
    files = list(SV_DIR.glob('*.sql')) + [ROOT / 'scripts' / 'deploy_ml_semantic_views.py']
    for f in files:
        if not f.exists():
            continue
        for m in pat.finditer(f.read_text(encoding='utf-8', errors='replace')):
            nm = m.group(1).split('.')[-1].strip('"').upper()
            names.setdefault(nm, f.relative_to(ROOT).as_posix())
    return names


def serving_view_names():
    """SERVING 스키마 뷰(ML_*_V 등) 이름을 DDL 정본·배포 스크립트에서 뽑는다.

    🔴 스키마 한정이 필수다 — 같은 폴더 SQL 이 GOLD 뷰도 담을 수 있어
       한정 없이 뽑으면 GOLD 뷰가 「SERVING 미생성」으로 오탐된다.
    """
    pat = re.compile(
        r'CREATE\s+(?:OR\s+(?:REPLACE|ALTER)\s+)?VIEW\s+([A-Za-z0-9_.$"{}]+)', re.IGNORECASE
    )
    names = {}
    files = list(SV_DIR.glob('*.sql')) + [ROOT / 'scripts' / 'deploy_ml_serving_views.py']
    for f in files:
        if not f.exists():
            continue
        for m in pat.finditer(f.read_text(encoding='utf-8', errors='replace')):
            raw = m.group(1)
            if '{' in raw:
                continue
            parts = [p.strip('"').upper() for p in raw.split('.')]
            if len(parts) >= 2 and parts[-2] != 'SERVING':
                continue
            names.setdefault(parts[-1], f.relative_to(ROOT).as_posix())
    return names


def yml_declared_models():
    """dbt schema yml 에 `- name:` 으로 등재된 모델 이름 집합."""
    names = set()
    for f in MODELS.rglob('*.yml'):
        text = f.read_text(encoding='utf-8', errors='replace')
        if re.search(r'^\s*sources\s*:', text, re.MULTILINE) and 'models:' not in text:
            continue
        for m in re.finditer(r'^\s*-\s*name:\s*([A-Za-z0-9_]+)', text, re.MULTILINE):
            names.add(m.group(1).upper())
    return names


TYPE_TOKENS = (
    'VARCHAR', 'CHAR', 'STRING', 'TEXT', 'NUMBER', 'NUMERIC', 'DECIMAL', 'INT',
    'INTEGER', 'BIGINT', 'SMALLINT', 'FLOAT', 'DOUBLE', 'BOOLEAN', 'DATE',
    'DATETIME', 'TIME', 'TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ',
    'TIMESTAMP', 'VARIANT', 'OBJECT', 'ARRAY', 'BINARY',
)


def ddl_table_columns(path, schema):
    """DDL 파일에서 `CREATE TABLE <schema>.<name>` 블록의 컬럼명 집합을 뽑는다.

    🔴 판정식 한계를 명시한다 — 컬럼 선언은 「줄 머리 = 컬럼명 + 타입토큰」으로만
       인식한다. 주석 처리된 CREATE 문은 제외되고, 제약절(PRIMARY KEY 등)은 타입
       토큰이 없어 자연히 빠진다. 순서는 판정하지 않는다(집합만).
    """
    text = Path(path).read_text(encoding='utf-8', errors='replace')
    head = re.compile(
        r'^[^\S\n]*CREATE\s+(?:OR\s+REPLACE\s+)?(?:TRANSIENT\s+)?TABLE\s+'
        r'(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z0-9_."]+)', re.IGNORECASE | re.MULTILINE)
    coldecl = re.compile(
        r'^\s{1,12}([A-Z][A-Z0-9_]*)\s+(' + '|'.join(TYPE_TOKENS) + r')\b', re.IGNORECASE)
    out = {}
    heads = list(head.finditer(text))
    for i, m in enumerate(heads):
        parts = [p.strip('"').upper() for p in m.group(1).split('.')]
        if len(parts) >= 2 and parts[-2] != schema:
            continue
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        cols = set()
        for line in text[m.end():end].splitlines():
            if line.lstrip().startswith('--'):
                continue
            cm = coldecl.match(line)
            if cm:
                cols.add(cm.group(1).upper())
        if cols:
            out[parts[-1]] = cols
    return out


def column_report(label, ddl_map, live_cols):
    """DDL 선언 컬럼 집합 ↔ 라이브 컬럼 집합 대조(집합만 · 순서 제외)."""
    bad = 0
    checked = 0
    for tname, dcols in sorted(ddl_map.items()):
        lcols = live_cols.get(tname)
        if lcols is None:
            print(f'   🔴 {tname}: 라이브 테이블 부재')
            bad += 1
            continue
        checked += 1
        missing = sorted(dcols - lcols)
        extra = sorted(lcols - dcols)
        if missing or extra:
            bad += 1
            print(f'   🔴 {tname}: DDL {len(dcols)} · 라이브 {len(lcols)}'
                  f' · 라이브 누락 {len(missing)} · DDL 밖 {len(extra)}')
            if missing:
                print(f'        누락: {", ".join(missing[:8])}')
            if extra:
                print(f'        DDL 밖: {", ".join(extra[:8])}')
    mark = '✅' if bad == 0 else '🔴'
    print(f'{mark} {label}: DDL 선언 테이블 {len(ddl_map)}개 · 대조 {checked}개'
          f' · 불일치 {bad}건')
    return bad


SENTINEL_PROBE = [
    # 🔴 표본은 `BLOCKING-5` 표가 지목한 축만 고른다(전 컬럼 스캔은 비용이 크다).
    ('FACT_MEMBER_MONTHLY',
     ['CAMPAIGN_SK', 'PAYMENT_SK', 'SPONSORSHIP_SK', 'REASON_SK']),
    ('FACT_MEMBER_EVENT', ['CAMPAIGN_SK', 'SPONSORSHIP_SK', 'ORG_SK']),
    ('FACT_SERVICE_EVENT', ['CAMPAIGN_SK', 'SERVICE_SK']),
    ('FACT_EVENT_PARTICIPATION', ['CAMPAIGN_SK', 'SPONSORSHIP_SK', 'EVENT_SK']),
    ('FACT_BUDGET', ['CAMPAIGN_SK', 'ORG_SK', 'BUDGET_ITEM_SK']),
]


def probe_sentinel(cn, fact, cols):
    """센티넬 0 채움률 표본 관측. 🔴 판정이 아니라 관측이다."""
    sel = ', '.join(f'count_if({c} <> 0) as {c}' for c in cols)
    try:
        names, rows = sfconn.q(
            f'select count(*) as __ROWS__, {sel} from GN_DW.GOLD.{fact}', cn)
    except Exception:
        return None
    out = {}
    for name, val in zip(names, rows[0]):
        out['__rows__' if name.upper() == '__ROWS__' else name.upper()] = val
    return out


def report(label, design, live):
    missing = sorted(design - live)
    extra = sorted(live - design)
    mark = '✅' if not missing else '🔴'
    print(f'{mark} {label}: 설계 {len(design)} · 라이브 {len(live)} '
          f'· 설계에 있고 라이브에 없음 {len(missing)} · 라이브에만 있음 {len(extra)}')
    for n in missing:
        print(f'   🔴 미생성: {n}')
    for n in extra:
        print(f'   🟠 설계 목록 밖(라이브에만): {n}')
    return len(missing), len(extra)


def main():
    cn = sfconn.conn()
    cn_probe = cn
    _, rows = sfconn.q(
        "select table_schema, table_type, table_name, row_count "
        "from GN_DW.INFORMATION_SCHEMA.TABLES "
        "where table_schema in ('SILVER','GOLD','SERVING')", cn)
    live = {}
    row_counts = {}
    for sch, typ, name, rc in rows:
        live.setdefault((sch, typ), set()).add(name.upper())
        if typ == 'BASE TABLE':
            row_counts[f'{sch}.{name.upper()}'] = rc if rc is not None else -1
    _, svrows = sfconn.q('show semantic views in schema GN_DW.SERVING', cn)
    live_sv = {r[1].upper() for r in svrows}
    _, colrows = sfconn.q(
        "select table_schema, table_name, column_name "
        "from GN_DW.INFORMATION_SCHEMA.COLUMNS "
        "where table_schema in ('SILVER','GOLD')", cn)
    live_cols = {}
    for sch, tname, col in colrows:
        live_cols.setdefault(sch, {}).setdefault(tname.upper(), set()).add(col.upper())
    # 🔴 값 축 표본을 뒤에서 재므로 여기서 닫지 않는다(마지막에 닫는다).

    print('=' * 72)
    print('O125 — 설계 정본 ↔ 라이브 실재 대조 (읽기 전용)')
    print('  분모 = dbt 모델 파일 · SV DDL 파일 · 배포 스크립트  |  라이브 = INFORMATION_SCHEMA + SHOW')
    print('  🔴 판정 축 = 객체 실재 + 컬럼 이름 집합. 값 적재·선언 순서·SV 값 정합은 판정하지 않는다.')
    print('  🔴 배포 상태 정본 = 05_SV-Agent_ai/04_SV_설계.md §0.9 · 값 축 정본 = 문서50 BLOCKING-5')
    print('=' * 72)

    miss = extra = 0
    for label, design, key in [
        ('SILVER 테이블 (dbt models/silver)', model_names('silver'), ('SILVER', 'BASE TABLE')),
        ('GOLD 테이블 (models/gold/dim+fact)',
         model_names('gold/dim') | model_names('gold/fact'), ('GOLD', 'BASE TABLE')),
        ('GOLD 뷰 (models/gold/wide)', model_names('gold/wide'), ('GOLD', 'VIEW')),
        ('SERVING 뷰 (ML 배포 스크립트)', set(serving_view_names()), ('SERVING', 'VIEW')),
    ]:
        m, e = report(label, design, live.get(key, set()))
        miss += m
        extra += e

    m, e = report('SERVING 시맨틱뷰 (SV DDL·배포 스크립트)', set(sv_names_from_files()), live_sv)
    miss += m
    extra += e

    print('-' * 72)
    print(f'미생성(blocking) {miss}건 · 설계 목록 밖 {extra}건')
    print('🔴 「설계 목록 밖」은 결함이 아닐 수 있다 — 원천 랜딩·수동 객체를 포함한다(사람 판단).')

    # ── 컬럼 축: DDL 정본 선언 ↔ 라이브 컬럼 집합 ────────────────────────────────
    print('-' * 72)
    print('컬럼 집합 대조 (DDL 정본 ↔ 라이브 · 순서는 판정하지 않는다)')
    colbad = column_report(
        'GOLD (03_top-down_gold/06_DDL.sql)',
        ddl_table_columns(ROOT / '03_top-down_gold' / '06_DDL.sql', 'GOLD'),
        live_cols.get('GOLD', {}))
    colbad += column_report(
        'SILVER (04_silver_design/08_SILVER_테이블DDL_20260714.sql)',
        ddl_table_columns(
            ROOT / '04_silver_design' / '08_SILVER_테이블DDL_20260714.sql', 'SILVER'),
        live_cols.get('SILVER', {}))

    # ── 부차 축: dbt schema yml 등재 커버리지(문서 축 · 적재 위험 아님) ──────────
    all_models = (model_names('silver') | model_names('gold/dim')
                  | model_names('gold/fact') | model_names('gold/wide'))
    declared = yml_declared_models()
    undocumented = sorted(all_models - declared)
    print('-' * 72)
    print(f'🟠 yml 미등재 모델 {len(undocumented)}건 / 모델 파일 {len(all_models)}개'
          ' — 문서 축이며 라이브 실재와 무관하다')
    for n in undocumented:
        print(f'   🟠 yml 미등재: {n}')

    # ── 값 축 표본(관측) — 🔴 판정이 아니다 · 「구성됐다 ≠ 작동한다」를 눈에 보이게 한다 ──
    print('-' * 72)
    print('값 적재 축 [관측] — 🔴 이 절은 판정이 아니다. 정본 = 문서50 `BLOCKING-5`')
    empty = sorted(t for t, c in row_counts.items() if c == 0)
    print(f'   0행 테이블 {len(empty)}건: {", ".join(empty) if empty else "없음"}')
    for fact, cols in SENTINEL_PROBE:
        counts = probe_sentinel(cn_probe, fact, cols)
        if counts is None:
            print(f'   ⚠️ {fact}: 표본 조회 실패(권한·부재) — 「0」으로 읽지 마라')
            continue
        total = counts.pop('__rows__')
        parts = [f'{c} {v:,}/{total:,}' for c, v in counts.items()]
        print(f'   {fact}: ' + ' · '.join(parts))
    print('   🔴 비-0 이 0 인 축은 「컬럼은 있고 값이 없다」는 뜻이다 — 지표 산출 불가.')
    print('   🔴 부분 채움 축(예: DEV 한정)은 「해소」가 아니다 — 한정 표기와 함께 읽어라.')

    print('-' * 72)
    print(f'요약 = 객체 미생성 {miss}건 · 컬럼 집합 불일치 {colbad}건'
          f' · yml 미등재 {len(undocumented)}건 · 0행 테이블 {len(empty)}건')
    print('🔴 이 요약은 실재·이름 축이다. 값 적재·순서·SV 값 정합은 다른 도구 소관이다(머리말 참조).')
    cn_probe.close()
    return 1 if miss else 0


if __name__ == '__main__':
    sys.exit(main())

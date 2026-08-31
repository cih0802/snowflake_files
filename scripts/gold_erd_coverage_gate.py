# GOLD ERD 의 FK 커버리지를 감사한다 — 두 소스 어디에도 없는 「고립 키 컬럼」을 적발한다.
# Co-authored with CoCo
#
# 왜 필요한가 (2026-08-31 O126 신설):
#   gen_gold_erd.py 는 dbt YAML FK 와 물리 FK 의 **합집합**을 쓴다. 그러나 합집합도 전량이 아니다 —
#   🔴 **두 소스 어디에도 선언되지 않은 조인 경로**가 남는다.
#   대표 = MONTH_KEY → DIM_MONTH. Snowflake 는 비유일 대상에 FK 를 못 걸고(06_DDL [관계 제약] [보류]),
#   dbt 쪽에도 relationships 테스트가 없으면 **ERD 에서 그 관계가 사라진다.**
#   ⚠️ 이것이 위험한 이유 = DIM_MONTH 는 **fan-out 차단 차원**이다. ERD 에 월 축이 안 보이면
#   독자는 월 팩트를 DIM_DATE(일 grain)에 조인해 금액을 **월당 일수만큼 과대**하게 만든다
#   (DIM_MONTH.MONTH_KEY COMMENT 의 🔴🔴 경고가 바로 그것이다).
#
# 판정식 = FACT 의 키 형태 컬럼(_SK / _KEY / _DK) 중 병합 FK 집합에 없는 것 = 「고립」.
#   🔴 고립이 0 이어야 한다는 뜻이 아니다 — degenerate key(AD_PERF_DK 등)는 정상적으로 고립이다.
#   ⇒ 이 게이트는 **분류**를 강제한다: 고립 1건마다 KNOWN_ORPHANS 에 사유를 적어야 통과한다.
#   🟢 즉 「모르는 고립 0」을 보증한다. 새 컬럼이 생기면 즉시 FAIL 이 나 사람의 판정을 강제한다.
#
# 🆕🆕 [2026-08-31 O128 · 착수표 ㊲] **분모를 DIM 까지 확대했다.**
#   🔴 종전 `fetch_fact_key_columns()` 는 `TABLE_NAME LIKE 'FACT_%'` 만 봤다 ⇒
#     DIM → DIM 참조(`DIM_CAMPAIGN.ORG_SK`·`DIM_MEMBER_ACQUISITION.ACQ_*` 등)는
#     **고립 판정 분모 밖**이었다. 그래서 종전 「고립 7 · 미분류 0」은 **FACT 한정 판정**이었고,
#     DIM 에 새 키가 생기면 이 게이트가 **조용히 침묵**했다(`O111 ㉠` — 「0건」이 「없다」가 아니다).
#   🟢 확대 실측(2026-08-31) = DIM 키 컬럼 32 · 그중 고립 10 ⇒ 전건 분류해 등재했다(아래).
#   🔴 분모는 `KEY_TABLE_PREFIXES` 한 곳에서만 정한다 — 두 곳에 적으면 한 곳이 낡는다(`R3-9 ㉡`).
#   🟢 음성 테스트 = `test_gold_erd.py` 축14(분모 오염 축 · 선례 = `test_doc_census.py` 축6).
#
# 사용:
#   python3 scripts/gold_erd_coverage_gate.py            # 판정 (미분류 고립 있으면 exit 1)
#   python3 scripts/gold_erd_coverage_gate.py --list      # 고립 전량 나열(분류 여부 포함)

import os
import sys
import importlib.util
from collections import defaultdict

ROOT = "/workspace"
sys.path.insert(0, os.path.join(ROOT, "scripts"))

LIST_ONLY = "--list" in sys.argv


# ══════════════════════════════════════════════════════════════════════════════
# 분류 등재부 — 고립 1건마다 사유를 적는다. 🔴 사유 없는 고립은 FAIL 이다.
#   키 = (테이블, 컬럼) 또는 ('*', 컬럼) 으로 컬럼 전역 규칙
#   값 = (분류, 사유)
#   분류 = 'DEGEN'   : degenerate key — 차원이 없는 것이 설계다(ERD 관계 없음이 정상)
#          'CONFORM' : conform 축인데 FK 선언 불가 — 🔴 ERD 에 **논리 관계로 표기해야 한다**
#          'SELFREF' : 같은 팩트군 내부 참조(위성 → 코어)
# ══════════════════════════════════════════════════════════════════════════════
KNOWN_ORPHANS = {
    ("*", "MONTH_KEY"): (
        "CONFORM",
        "월 conform 축 → DIM_MONTH.MONTH_KEY. 🔴 물리 FK 도 dbt relationships 도 **둘 다 없다** "
        "— 06_DDL [관계 제약] 이 월 conform 키를 비유일 참조로 보아 선언을 보류했고, "
        "yml 에도 테스트가 없다. ⇒ 두 소스 합집합으로도 잡히지 않는 축이다. "
        "🔴 ERD 에 논리 관계로 반드시 표기한다 — 누락하면 독자가 DIM_DATE(일 grain)로 "
        "조인해 월당 일수만큼 fan-out 한다(DIM_MONTH.MONTH_KEY COMMENT 🔴🔴).",
    ),
    ("*", "START_MONTH_KEY"): (
        "CONFORM",
        "역할기반 월 축(개시월) → DIM_MONTH.MONTH_KEY. 역할별 별칭이라 FK 대상이 비유일 취급. "
        "🔴 ERD 에 논리 관계로 표기한다.",
    ),
    ("*", "DSCNTC_MONTH_KEY"): (
        "CONFORM",
        "역할기반 월 축(중단월) → DIM_MONTH.MONTH_KEY. 위와 같은 사유. "
        "🔴 ERD 에 논리 관계로 표기한다.",
    ),
    ("*", "AD_PERF_DK"): (
        "DEGEN",
        "광고 성과 degenerate key. 코어 FACT_AD_PERFORMANCE 의 PK 이고 위성 3종이 이를 참조한다 "
        "(위성 참조는 물리 FK 로 선언되어 있어 고립이 아니다). "
        "코어 자신의 AD_PERF_DK 는 PK 이므로 FK 가 없는 것이 정상이다.",
    ),

    # ══════════════════════════════════════════════════════════════════════════
    # 🆕🆕 [2026-08-31 O128 · 착수표 ㊲] DIM 측 고립 10건 — 분모 확대로 처음 드러났다.
    #   🔴 **분류 전에 실측했다**(`_o128_dim_probe.py` · 2026-08-31):
    #     축 두 개를 함께 봤다 = ㉠ 제안 부모로 100% 해소되는가 ㉡ 자기 테이블에서 유일한가.
    #     ⇒ ㉡ 이 유일이면 **자연키(FK 아님)** 후보이고, 비유일이면 **참조** 후보다.
    #   🔴 이름만 보고 분류하지 마라 — `MEMBER_DK` 는 같은 이름으로 두 성격이 다 있다
    #     (DIM_MEMBER 에서는 자연키 · DIM_MEMBER_IDENTITY 에서는 참조) ⇒ **테이블 한정 키로 적는다.**
    # ══════════════════════════════════════════════════════════════════════════
    ("DIM_MEMBER", "MEMBER_DK"): (
        "DEGEN",
        "SCD2 차원의 자연키(업무키). 실측 = 7,925,716행 · distinct 1,763,065 ⇒ 버전 반복이라 "
        "비유일이지만 **자기 테이블의 업무키이고 다른 차원을 참조하지 않는다**. "
        "🔴 이름이 같은 DIM_MEMBER_IDENTITY.MEMBER_DK 와 성격이 다르다(그쪽은 이 컬럼을 참조한다) "
        "⇒ 컬럼 전역 규칙으로 적으면 두 성격이 뭉개진다.",
    ),
    ("DIM_ORG", "ORG_DK"): (
        "DEGEN",
        "조직 차원의 자연키(업무키). 실측 = 1,315행 · distinct 1,315(유일) · 미해소 0 ⇒ "
        "자기 테이블의 키이고 FK 가 아니다.",
    ),
    ("DIM_MEMBER_IDENTITY", "MEMBER_DK"): (
        "CONFORM",
        "회원 식별 차원 → DIM_MEMBER.MEMBER_DK 참조. 실측 = 1,763,066행 · 유일 · "
        "🟠 **미해소 1행**(DIM_MEMBER 에 없는 MEMBER_DK 가 1건) ⇒ 관계는 실재하고 "
        "결손은 회원 마스터 미완전 축(문서50 §O116 ㉠)의 1행이다. "
        "🔴 물리 FK 도 dbt relationships 도 없다 ⇒ ERD 에 논리 관계로 표기한다.",
    ),
    ("DIM_MEMBER_CURRENT", "MEMBER_SK"): (
        "CONFORM",
        "현재행 투영 차원 → DIM_MEMBER.MEMBER_SK 참조(1:1 투영). 실측 = 1,763,065행 · "
        "distinct 1,763,065(유일) · 미해소 0. ⚠️ 이 컬럼은 **자기 차원의 grain 키이면서 동시에 "
        "참조**다 — 물리 PK 가 선언돼 있지 않아 고립으로 잡힌다. "
        "🔴 CONFORM 으로 적는 이유 = ERD 에 투영 관계선이 보여야 독자가 "
        "**DIM_MEMBER 와 DIM_MEMBER_CURRENT 를 둘 다 조인해 팬아웃시키는 것**을 피할 수 있다.",
    ),
    ("DIM_MEMBER_ACQUISITION", "ACQ_CAMPAIGN_SK"): (
        "CONFORM",
        "획득 귀속 차원의 역할기반 캠페인 축 → DIM_CAMPAIGN.CAMPAIGN_SK. "
        "실측 = 1,585,949행 · distinct 13,038 · 미해소 0. base 인 FACT_MEMBER_COHORT 쪽에는 "
        "relationships 가 있으나 **이 차원에는 물리 FK 도 dbt 테스트도 없다**(파생 테이블).",
    ),
    ("DIM_MEMBER_ACQUISITION", "ACQ_DATE_SK"): (
        "CONFORM",
        "역할기반 일자 축(획득일) → DIM_DATE.DATE_SK. 실측 = 1,585,949행 · distinct 10,040 · 미해소 0.",
    ),
    ("DIM_MEMBER_ACQUISITION", "ACQ_ORG_SK"): (
        "CONFORM",
        "역할기반 조직 축(획득 조직) → DIM_ORG.ORG_SK. 실측 = 1,585,949행 · distinct 344 · 미해소 0.",
    ),
    ("DIM_MEMBER_ACQUISITION", "ACQ_SPONSORSHIP_SK"): (
        "CONFORM",
        "역할기반 후원유형 축 → DIM_SPONSORSHIP.SPONSORSHIP_SK. "
        "실측 = 1,585,949행 · distinct 29 · 미해소 0.",
    ),
    ("DIM_MEMBER_ACQUISITION", "FIRST_STOP_DATE_SK"): (
        "CONFORM",
        "역할기반 일자 축(최초 중단일) → DIM_DATE.DATE_SK. 실측 = 1,585,949행 · "
        "NOT NULL **901,577**(미중단은 NULL · 0 아님) · distinct 6,405 · 미해소 0. "
        "🔴 NULL 이 정상인 축이다 — not_null 을 요구하지 않는다(`R2-7-1`).",
    ),
    # 🟢 DIM_DATE.MONTH_KEY 는 위 ("*", "MONTH_KEY") 전역 규칙이 이미 덮는다
    #   (실측 = 16,437행 · distinct 541 · 미해소 0) ⇒ 여기 중복 등재하지 않는다.
}

# 🔴 논리 관계로 ERD 에 추가해야 하는 분류 — gen_gold_erd.py 가 이 규칙을 읽어 관계선을 만든다.
#   키 = `"컬럼"`(전역) 또는 `("테이블", "컬럼")`(테이블 한정 · 전역보다 우선).
#   🆕🆕 [2026-08-31 O128 · 착수표 ㊲] **테이블 한정 키를 추가했다.**
#     🔴 왜 필요했나 = 분모를 DIM 까지 넓히자 **같은 컬럼 이름이 테이블마다 다른 대상**을 가리켰다.
#       실물 = `MEMBER_DK` 는 DIM_MEMBER 에서 자연키(FK 아님)이고 DIM_MEMBER_IDENTITY 에서는
#       DIM_MEMBER 를 참조한다 · `MEMBER_SK` 도 마찬가지다.
#       ⇒ 컬럼 전역 규칙만 있으면 **엉뚱한 테이블에 관계선을 그린다**(FACT 에 MEMBER_SK 가 생기면 즉시).
#     🔴 조회는 반드시 `logical_target()` 을 쓴다 — `LOGICAL_FK.get(col)` 를 직접 부르면
#       테이블 한정 규칙을 건너뛴다(`test_gold_erd.py` 축14-d 가 그 우회를 검출한다).
LOGICAL_FK = {
    "MONTH_KEY": ("DIM_MONTH", "MONTH_KEY"),
    "START_MONTH_KEY": ("DIM_MONTH", "MONTH_KEY"),
    "DSCNTC_MONTH_KEY": ("DIM_MONTH", "MONTH_KEY"),

    # 🆕 [O128] DIM 측 논리 관계 7건 — 근거·실측은 위 KNOWN_ORPHANS 의 같은 키에 있다.
    ("DIM_MEMBER_IDENTITY", "MEMBER_DK"):        ("DIM_MEMBER", "MEMBER_DK"),
    ("DIM_MEMBER_CURRENT", "MEMBER_SK"):         ("DIM_MEMBER", "MEMBER_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_CAMPAIGN_SK"):    ("DIM_CAMPAIGN", "CAMPAIGN_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_DATE_SK"):        ("DIM_DATE", "DATE_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_ORG_SK"):         ("DIM_ORG", "ORG_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_SPONSORSHIP_SK"): ("DIM_SPONSORSHIP", "SPONSORSHIP_SK"),
    ("DIM_MEMBER_ACQUISITION", "FIRST_STOP_DATE_SK"): ("DIM_DATE", "DATE_SK"),
}

#: 고립 판정의 **분모**가 되는 테이블 접두. 🔴 이 한 곳에서만 정한다(`R3-9 ㉡`).
#:   🆕 [O128] 종전에는 `('FACT',)` 만이었다 ⇒ DIM 측 고립이 판정 밖이었다.
KEY_TABLE_PREFIXES = ("DIM", "FACT")

#: 키로 간주하는 컬럼 접미. 🔴 분모의 다른 절반이므로 여기서만 정한다.
KEY_COLUMN_SUFFIXES = ("_SK", "_KEY", "_DK")


def logical_target(table, col):
    """논리 관계 대상 `(부모테이블, 부모컬럼)` 또는 None.

    🔴 테이블 한정 규칙이 컬럼 전역 규칙보다 우선한다(`classify()` 와 같은 순서).
      두 함수의 우선순위가 어긋나면 「분류는 CONFORM 인데 대상은 엉뚱한 차원」이 된다.
    """
    return LOGICAL_FK.get((table, col)) or LOGICAL_FK.get(col)


def classify(table, col):
    """(분류, 사유) 또는 None. 테이블 한정 규칙이 컬럼 전역 규칙보다 우선한다."""
    return KNOWN_ORPHANS.get((table, col)) or KNOWN_ORPHANS.get(("*", col))


def load_generator():
    spec = importlib.util.spec_from_file_location(
        "gen_gold_erd", os.path.join(ROOT, "scripts", "gen_gold_erd.py"))
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv
    sys.argv = ["gen_gold_erd"]          # --list 가 생성기에 새지 않게 한다
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = saved
    return mod


def fetch_key_columns(cn, prefixes=None, suffixes=None):
    """DIM·FACT 의 키 형태 컬럼(_SK / _KEY / _DK)을 라이브에서 가져온다.

    🆕 [2026-08-31 O128 · 착수표 ㊲] 종전 `fetch_fact_key_columns()` 는 `FACT_` 만 봤다.
      🔴 분모는 `KEY_TABLE_PREFIXES` / `KEY_COLUMN_SUFFIXES` 가 정본이고 여기서 조립한다 —
        접두를 이 함수 안에 리터럴로 박으면 **같은 분모를 두 곳에서 정하는** 상태가 된다(`R3-9 ㉡`).
      🟢 인자로 덮어쓸 수 있게 둔 이유는 **음성 테스트가 분모를 일부러 좁혀** 오염을 만들고
        게이트가 그것을 검출하는지 단정하기 위함이다(축14 · 선례 = `test_doc_census.py` 축6).
    """
    prefixes = tuple(prefixes if prefixes is not None else KEY_TABLE_PREFIXES)
    suffixes = tuple(suffixes if suffixes is not None else KEY_COLUMN_SUFFIXES)
    if not prefixes or not suffixes:
        raise ValueError(
            "분모가 비었다 — 접두 %r · 접미 %r. 분모가 비면 「고립 0」이 자동으로 참이 된다"
            "(`O111 ㉠`)." % (prefixes, suffixes))

    tbl_pred = " OR ".join(
        "c.TABLE_NAME LIKE '%s/_%%' ESCAPE '/'" % p for p in prefixes)
    col_pred = " OR ".join(
        "c.COLUMN_NAME LIKE '%%%s' ESCAPE '/'" % s.replace("_", "/_")
        for s in suffixes)

    cur = cn.cursor()
    cur.execute("""
        SELECT c.TABLE_NAME, c.COLUMN_NAME
          FROM GN_DW.INFORMATION_SCHEMA.COLUMNS c
          JOIN GN_DW.INFORMATION_SCHEMA.TABLES t
            ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
           AND t.TABLE_NAME   = c.TABLE_NAME
         WHERE c.TABLE_SCHEMA = 'GOLD'
           AND t.TABLE_TYPE   = 'BASE TABLE'
           AND (%s)
           AND (%s)
         ORDER BY c.TABLE_NAME, c.COLUMN_NAME
    """ % (tbl_pred, col_pred))
    return [(r[0], r[1]) for r in cur.fetchall()]


#: 🔴 종전 이름의 호환 별칭 — **분모가 FACT 한정이라는 뜻이 아니다**(O128 확대 후).
#:   🟠 새 코드는 `fetch_key_columns` 를 쓴다. 이 별칭은 이름이 판정을 오해시키므로 남기지 않는다.
#:   ⇒ 호출자(`gen_gold_erd.py`)를 같은 커밋에서 함께 고쳤다(`R3-9 ㉡` — 이름만 남기면 낡는다).


def compute(g, cn):
    """(고립 목록, 통계) 반환. 고립 = 키 컬럼 중 병합 FK 에 없는 것."""
    models = g.parse_dbt_schema(g.SCHEMA_YML)
    live_fk = g.fetch_live_fk(cn)
    keys = fetch_key_columns(cn)
    models, stats = g.merge_fk_sources(models, live_fk)

    covered = {(m, fk["col"]) for m, mi in models.items() for fk in mi["fk"]}
    # PK 는 FK 가 아니어도 정상 — 물리 PK 를 커버로 인정한다
    live_pk = g.fetch_live_pk(cn)
    pk_cols = {(t, c) for t, cols in live_pk.items() for c in cols}

    orphans = [k for k in keys if k not in covered and k not in pk_cols]
    return orphans, stats, len(keys), len(pk_cols)


def main():
    g = load_generator()
    import sfconn
    cn = sfconn.conn()
    try:
        orphans, stats, n_keys, n_pk = compute(g, cn)
    finally:
        cn.close()

    unclassified = [(t, c) for t, c in orphans if classify(t, c) is None]

    # 🆕 [O128] 관측 축을 판정 축과 분리해 낸다 — 분모가 어디서 왔는지 보이지 않으면
    #   「고립 N」이 FACT 한정인지 전체인지 읽는 사람이 알 수 없다(O126 이 그 상태였다).
    by_prefix = defaultdict(int)
    for t, _c in orphans:
        by_prefix[t.split("_", 1)[0]] += 1

    print(f"GOLD ERD FK 커버리지 게이트")
    print(f"  분모 = 접두 {'·'.join(KEY_TABLE_PREFIXES)} "
          f"× 접미 {'·'.join(KEY_COLUMN_SUFFIXES)}")
    print(f"  키 컬럼             = {n_keys}")
    print(f"  병합 FK 관계        = {stats['merged_total']} "
          f"(YAML {stats['yaml_total']} · 물리 {stats['live_total']} · "
          f"YAML만 {stats['yaml_only']} · 물리만 {stats['live_only']})")
    print(f"  고립 키 컬럼        = {len(orphans)}"
          + (f"  ({' · '.join(f'{k} {v}' for k, v in sorted(by_prefix.items()))})"
             if by_prefix else ""))
    print(f"  └ 분류됨            = {len(orphans) - len(unclassified)}")
    print(f"  └ 🔴 미분류         = {len(unclassified)}")

    if LIST_ONLY or unclassified:
        print()
        # 🔴 [O128] (테이블, 컬럼) 단위로 나열한다 — 컬럼으로만 묶으면 **테이블 한정 분류가
        #   첫 테이블의 것으로 뭉개져** 「같은 이름 다른 성격」(MEMBER_DK 축)을 잘못 보고한다.
        for t, c in sorted(orphans):
            cls = classify(t, c)
            tag = f"[{cls[0]}]" if cls else "[🔴 미분류]"
            tgt = logical_target(t, c)
            arrow = f" → {tgt[0]}.{tgt[1]}" if tgt else ""
            print(f"  {tag:14s} {t}.{c}{arrow}")
            if cls:
                print(f"                 └ {cls[1][:150]}")

    print()
    if unclassified:
        print(f"🔴 FAIL — 미분류 고립 {len(unclassified)}건. "
              f"KNOWN_ORPHANS 에 분류와 사유를 등재하라.")
        print("   🔴 사유를 적기 전에 그 컬럼이 conform 축인지 degenerate key 인지 판정하라 —")
        print("      conform 축을 DEGEN 으로 잘못 적으면 ERD 에서 관계가 영구히 사라진다.")
        return 1

    # 🔴 [O128] `c in LOGICAL_FK` 로 세면 **테이블 한정 키를 못 본다** ⇒ 해석기를 쓴다.
    n_logical = sum(1 for t, c in orphans if logical_target(t, c) is not None)
    print(f"🟢 PASS — 미분류 고립 0건 "
          f"(분류 {len(orphans)}건 중 논리 관계로 ERD 표기 대상 {n_logical}건)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

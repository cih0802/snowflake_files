#!/usr/bin/env python3
"""인수인계 DDL 게이트 — 원천 정의 문서(99_provided_definition) ↔ 인수인계 DDL(50_handoff) 대조.

왜 필요한가 (O113 실사고):
  O113 이 04번 DDL 을 손으로 고치고 「구조차이 0」이라고 판정했는데,
  그때 쓴 임시 도구는 **컬럼 COMMENT 와 DEFAULT 절을 아예 보지 않았다.**
  즉 「차이 0」은 「차이가 없다」가 아니라 **「내 판정식이 그 축을 못 본다」**였다
  (작업지침 「0건은 없다가 아니다」 축 ㉠).
  ⇒ 이 게이트는 축을 6개로 늘리고, 각 축을 **따로 숫자로** 낸다.

검사 축:
  축1 테이블 집합        (원천에만 / 인수인계에만)
  축2 컬럼 이름·순서
  축3 컬럼 타입
  축4 컬럼 DEFAULT 절
  축5 컬럼 COMMENT       (원천이 준 COMMENT 의 무변경 여부 + 누락 여부)
  축6 테이블 COMMENT

COMMENT 정책 (04번 「병합 규칙」 2항 = **컬럼 단위**로 판정한다):
  · 원천에 COMMENT 가 **있으면** → 인수인계도 같아야 한다 (다르면 blocking).
  · 원천에 COMMENT 가 **없으면** → 인수인계가 보강한 것은 **정상**이다 (보강 건수만 집계).
    다만 양쪽 다 없으면 「누락」으로 잡는다 — 04번이 「컬럼 코멘트 전 컬럼 부여 완료」를 주장하기 때문이다.
  🔴 종전 구현은 이 정책을 **스키마 단위**(BRONZE_CRM 만 예외)로 넣었다가
     BRONZE_AGENCY.SYNC_ERR_INFO(원천 COMMENT 없음)를 **오탐 5건**으로 잡았다.
     제외 규칙은 **그 근거가 성립하는 축**에만 적용해야 한다(작업지침 판정 일반화 ㉡).

사용:
  python3 scripts/handoff_ddl_gate.py            # 전 축 검사 (차이 있으면 exit 1)
  python3 scripts/handoff_ddl_gate.py --quiet    # 요약만
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CREATE_RE = re.compile(
    r"^\s*create\s+or\s+replace\s+TABLE\s+([A-Za-z0-9_.\"]+)\s*\(",
    re.IGNORECASE,
)
# 컬럼 줄: 공백/탭 들여쓰기 + 이름 + 타입(괄호 허용) + 나머지(DEFAULT / COMMENT)
COL_RE = re.compile(
    r"^[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]+"
    r"([A-Za-z][A-Za-z0-9_]*(?:\([^)]*\))?)"
    r"(?P<rest>.*)$"
)
DEFAULT_RE = re.compile(r"\bDEFAULT\s+(.+?)(?=\s+COMMENT\b|\s*,\s*$|\s*$)", re.IGNORECASE)
COMMENT_RE = re.compile(r"\bCOMMENT\s+'((?:[^']|'')*)'", re.IGNORECASE)
# 테이블 종료 줄: ")" 또는 ")COMMENT='...'"
END_RE = re.compile(r"^\)\s*(?:COMMENT\s*=\s*'((?:[^']|'')*)')?", re.IGNORECASE)


class Table:
    __slots__ = ("name", "cols", "comment")

    def __init__(self, name):
        self.name = name
        self.cols = []          # [(이름, 타입, DEFAULT, COMMENT)]
        self.comment = None     # 테이블 COMMENT


def parse(path):
    """SCHEMA.TABLE -> Table 을 돌려준다."""
    tables = {}
    cur = None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = CREATE_RE.match(line)
        if m:
            parts = [p.strip('"') for p in m.group(1).split(".")]
            key = ".".join(parts[-2:]) if len(parts) >= 2 else parts[-1]
            cur = Table(key)
            tables[key] = cur
            continue
        if cur is None:
            continue
        em = END_RE.match(line)
        if em:
            cur.comment = em.group(1)
            cur = None
            continue
        cm = COL_RE.match(line)
        if cm:
            rest = cm.group("rest")
            dm = DEFAULT_RE.search(rest)
            com = COMMENT_RE.search(rest)
            cur.cols.append((
                cm.group(1),
                cm.group(2).upper(),
                (dm.group(1).strip().rstrip(",").strip().upper() if dm else None),
                (com.group(1) if com else None),
            ))
    return tables


def parse_many(paths):
    out = {}
    for p in paths:
        out.update(parse(ROOT / p))
    return out


class Report:
    def __init__(self):
        self.axes = {i: 0 for i in range(1, 7)}
        self.enriched = 0        # 원천 미제공 → 인수인계 보강 (정상 · 관측 축)
        self.missing_soft = []   # 양쪽 부재 · 「전건 부여」를 주장하지 않는 대상 (🟠 경고)
        self.lines = []

    def hit(self, axis, msg):
        self.axes[axis] += 1
        self.lines.append("   [축%d] %s" % (axis, msg))

    def warn(self, msg):
        self.missing_soft.append(msg)
        self.lines.append("   🟠 %s" % msg)

    @property
    def total(self):
        return sum(self.axes.values())


def cmp_comment(rep, axis, where, s_com, d_com, require=True, soft=False):
    """컬럼 단위 COMMENT 정책 (모듈 docstring 참조).

    🔴 판정 축과 관측 축을 분리한다 — 「보강」은 정상이므로 FAIL 로 세지 않고 따로 센다
       (작업지침 판정 일반화 ㉢).
    require=False : 누락 검사를 끈다 (테이블 COMMENT 용 — 04번은 「컬럼」 전건 부여만 주장한다).
    soft=True     : 누락을 blocking 이 아니라 🟠 경고로 낸다 —
                    그 문서가 「전 컬럼 코멘트 부여 완료」를 **주장하지 않는** 대상에 쓴다.
    """
    if s_com is not None:
        if s_com != d_com:
            rep.hit(axis, "%s COMMENT 변형 : 원천 %r ↔ 인수인계 %r" % (where, s_com, d_com))
    elif d_com:
        rep.enriched += 1
    elif require:
        msg = "%s COMMENT 없음 (원천·인수인계 양쪽 부재)" % where
        if soft:
            rep.warn(msg)
        else:
            rep.hit(axis, msg)


def compare(label, src_paths, dst_path, prefix, rep, quiet, soft_comment=False):
    src = {k: v for k, v in parse_many(src_paths).items() if k.startswith(prefix)}
    dst = {k: v for k, v in parse(ROOT / dst_path).items() if k.startswith(prefix)}

    head = "== %s  (원천 %d · 인수인계 %d)" % (label, len(src), len(dst))
    start = len(rep.lines)

    for t in sorted(set(src) - set(dst)):
        rep.hit(1, "원천에만 있다: %s (%d컬럼)" % (t, len(src[t].cols)))
    for t in sorted(set(dst) - set(src)):
        rep.hit(1, "인수인계에만 있다: %s (%d컬럼)" % (t, len(dst[t].cols)))

    for t in sorted(set(src) & set(dst)):
        s, d = src[t], dst[t]
        sn = [c[0] for c in s.cols]
        dn = [c[0] for c in d.cols]
        if sn != dn:
            add = [c for c in sn if c not in dn]
            rem = [c for c in dn if c not in sn]
            detail = []
            if add:
                detail.append("원천에만 %s" % ", ".join(add))
            if rem:
                detail.append("인수인계에만 %s" % ", ".join(rem))
            if not detail:
                detail.append("순서만 다르다")
            rep.hit(2, "%s : %d ↔ %d — %s" % (t, len(sn), len(dn), " / ".join(detail)))
            continue  # 컬럼 집합이 다르면 아래 축은 의미가 없다

        for i, (sc, dc) in enumerate(zip(s.cols, d.cols)):
            if sc[1] != dc[1]:
                rep.hit(3, "%s.%s 타입 : 원천 %s ↔ 인수인계 %s" % (t, sc[0], sc[1], dc[1]))
            if sc[2] != dc[2]:
                rep.hit(4, "%s.%s DEFAULT : 원천 %s ↔ 인수인계 %s" % (t, sc[0], sc[2], dc[2]))
            cmp_comment(rep, 5, "%s.%s" % (t, sc[0]), sc[3], dc[3], soft=soft_comment)
        cmp_comment(rep, 6, "%s(테이블)" % t, s.comment, d.comment, require=False)

    if not quiet or len(rep.lines) > start:
        print(head)
        for ln in rep.lines[start:]:
            print(ln)
        if len(rep.lines) == start:
            print("   ✅ 6축 전건 일치")
        print("")


TARGETS = [
    # (라벨, 원천 목록, 인수인계 파일, 접두, COMMENT 누락을 경고로 낮출지)
    #   soft=False = 그 문서가 「컬럼 코멘트 전 컬럼 부여 완료」를 **주장한다** ⇒ 누락은 blocking.
    #   soft=True  = 주장하지 않는다 ⇒ 누락은 🟠 경고(현업 확인 대상).
    ("BRONZE_CRM", ["99_provided_definition/11_bronze_crm_ddl.sql"],
     "50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql", "BRONZE_CRM.", False),
    ("BRONZE_AGENCY", ["99_provided_definition/12_bronze_agency_ddl.sql"],
     "50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql", "BRONZE_AGENCY.", False),
    ("BRONZE_ERP", ["99_provided_definition/13_bronze_erp_ddl.sql"],
     "50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql", "BRONZE_ERP.", False),
    ("SILVER", ["99_provided_definition/18_silver_bigquery_refined.sql"],
     "50_handoff/06_데이터마이그 GN_DW_SILVER_DDL_20260820.sql", "SILVER.", True),
    ("ML_RST_DATA", ["99_provided_definition/20_ML_ddl.sql"],
     "50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql", "ML.ML_RST_DATA_", True),
]

# ---------------------------------------------------------------------------
# 축7 — 문서에 박아 둔 「수」가 DDL 실측과 같은가
#
# 🔴 왜 필요한가 (O113 실사고):
#   04·05·06번 DDL 을 고친 뒤 「끝났다」고 보고했는데, 같은 폴더의 01·02·02_1·03·07번이
#   전부 옛 수치(67 · 브론즈 50 · CRM 45 · ERP 1)를 인용하고 있었다.
#   ⇒ 절반만 고친 문서군은 **고치지 않은 것보다 나쁘다**(독자가 어느 값이 현행인지 모른다).
#   또 이 stale 을 손으로 grep 할 때 패턴 두 개를 놓쳤다
#   (「67개 테이블」·「`BRONZE_CRM`(45)」) ⇒ 사람 grep 은 분모가 불안정하다.
# 판정식: 아래 STALE_TOKENS 의 옛 표기가 **현행값 없이 단독으로** 나오면 위반이다.
#   ⚠️ 정정을 설명하는 줄(「50 → 52」)과 과거 실측 기록은 면제한다 — 아래 주석 참조.
# ---------------------------------------------------------------------------
DOC_DIR = "50_handoff"
# (옛 표기, 같은 줄에 있으면 면제되는 현행 표기들, 설명)
#   🟢 판정식 = **「그 줄이 독자에게 현행값을 함께 알려주는가」**.
#      「50 → 52」·「04_2번 → 06번」처럼 정정을 설명하는 줄은 오해를 만들 수 없으므로 면제한다.
#      키워드 면제 목록(「stale」·「종전」…)을 쓰다가 오탐 7건이 났다 —
#      면제 근거는 **문장의 어휘가 아니라 현행값의 동반 여부**여야 한다(판정 일반화 ㉡).
STALE_TOKENS = [
    ("67 테이블", ("69",), "이관 총계 (현행 69)"),
    ("67개 테이블", ("69",), "이관 총계 (현행 69)"),
    ("= 67", ("69",), "이관 총계 (현행 69)"),
    ("브론즈 50", ("52",), "브론즈 소계 (현행 52)"),
    ("04_2번", ("06번", "06_데이터마이그"), "SILVER DDL 옛 번호 (현행 06번)"),
    ("04_2_데이터마이그", ("06_데이터마이그",), "SILVER DDL 옛 파일명 (현행 06_)"),
]
# 과거 실측 기록은 값을 고칠 수 없으므로 별도 면제한다(그 줄에 측정일이 붙어 있어야 한다).
MEASURED_MARKS = ("2026-08-12 측정", "2026-08-12 A 실측")


def axis7(quiet):
    """문서 기재 수치 ↔ 현행값 대조. (위반 목록, 검사한 파일 수) 를 돌려준다."""
    hits = []
    files = sorted(
        p for p in (ROOT / DOC_DIR).iterdir()
        if p.is_file() and p.suffix in (".sql", ".md")
    )
    for p in files:
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if any(m in line for m in MEASURED_MARKS):
                continue
            for tok, cures, why in STALE_TOKENS:
                if tok not in line:
                    continue
                if any(c in line for c in cures):
                    continue        # 같은 줄에 현행값이 있다 ⇒ 오해 불가
                hits.append((p.name, n, tok, why, line.strip()[:110]))
    if hits and not quiet:
        print("== 축7 문서 기재 수치 ↔ 현행값")
        for name, n, tok, why, txt in hits:
            print("   🔴 %s:%d  「%s」 (%s)" % (name, n, tok, why))
            print("        %s" % txt)
        print("")
    return hits, len(files)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--quiet", action="store_true", help="일치한 대상은 출력하지 않는다")
    args = ap.parse_args(argv)

    rep = Report()
    for label, srcs, dst, pref, soft in TARGETS:
        compare(label, srcs, dst, pref, rep, args.quiet, soft_comment=soft)

    a7, n_docs = axis7(args.quiet)

    names = {
        1: "테이블 집합", 2: "컬럼 이름·순서", 3: "컬럼 타입",
        4: "컬럼 DEFAULT", 5: "컬럼 COMMENT", 6: "테이블 COMMENT",
    }
    print("[축별 집계 — 판정 축]")
    for i in range(1, 7):
        print("   축%d %-14s : %d건" % (i, names[i], rep.axes[i]))
    print("   축7 %-14s : %d건  (문서 %d개 검사)" % ("문서 stale 수치", len(a7), n_docs))
    print("[관측 축] 원천 미제공 → 인수인계 COMMENT 보강 : %d건 (정상 · 판정에 넣지 않는다)"
          % rep.enriched)
    print("[관측 축] COMMENT 양쪽 부재 (경고 대상)          : %d건" % len(rep.missing_soft))

    fail = rep.total + len(a7)
    if fail:
        print("🔴 FAIL — 판정 축 총 %d건 (축별 집계 참조)" % fail)
        return 1
    if rep.missing_soft:
        print("🟠 PASS(경고) — 판정 축 0건 · COMMENT 양쪽 부재 %d건은 현업 확인 대상이다"
              % len(rep.missing_soft))
        return 0
    print("🟢 PASS — 7축 전건 일치 · DDL 대상 %d군 · 문서 %d개" % (len(TARGETS), n_docs))
    return 0


if __name__ == "__main__":
    sys.exit(main())

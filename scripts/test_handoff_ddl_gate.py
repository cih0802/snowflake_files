#!/usr/bin/env python3
"""handoff_ddl_gate 음성 테스트 — 오염 기반.

🔴 왜 오염 기반인가: 정상 입력만 넣으면 「0건」이 나오는데, 그 0건이
   「차이가 없다」인지 「내 판정식이 못 본다」인지 구별되지 않는다.
   O113 이 실제로 그 함정에 빠졌다(COMMENT·DEFAULT 축을 안 보는 도구로 「구조차이 0」 판정).
   ⇒ 각 축을 **일부러 깨뜨려** 검출되는지, 그리고 **정상 변형은 검출되지 않는지**를 양방향 단정한다.

축:
  축1 정상 입력            → 판정 축 0건
  축2 테이블 유실          → 축1 검출
  축3 컬럼 유실            → 축2 검출
  축4 컬럼 타입 변형        → 축3 검출
  축5 DEFAULT 유실         → 축4 검출
  축6 COMMENT 변형         → 축5 검출
  축7 원천 미제공 → 보강    → 검출 0 · enriched 증가 (🔴 오탐 재발 방지 축)
  축8 양쪽 부재 · soft=F   → 축5 검출(blocking)
  축9 양쪽 부재 · soft=T   → 판정 0 · 경고로만
 축10 테이블COMMENT 양쪽부재 → 검출 0 (require=False)
 축11 문서 stale 단독 표기   → 축7 검출
 축12 문서 stale + 현행값 동반 → 검출 0 (🔴 오탐 7건 재발 방지 축)
"""
import io
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import handoff_ddl_gate as G  # noqa: E402

PASSED = 0
FAILED = 0


def check(name, cond, detail=""):
    global PASSED, FAILED
    if cond:
        PASSED += 1
        print("   ✅ %s" % name)
    else:
        FAILED += 1
        print("   ❌ %s  %s" % (name, detail))


def run(src_text, dst_text, prefix="S.", soft=False):
    """임시 파일 2개로 compare 를 돌리고 Report 를 돌려준다."""
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        (d / "src.sql").write_text(src_text, encoding="utf-8")
        (d / "dst.sql").write_text(dst_text, encoding="utf-8")
        old_root = G.ROOT
        G.ROOT = d
        try:
            rep = G.Report()
            with redirect_stdout(io.StringIO()):
                G.compare("T", ["src.sql"], "dst.sql", prefix, rep, True, soft_comment=soft)
            return rep
        finally:
            G.ROOT = old_root


BASE_SRC = (
    "create or replace TABLE DB.S.A (\n"
    "  C1 NUMBER(38,0) DEFAULT DB.S.SEQ.NEXTVAL COMMENT 'c1',\n"
    "  C2 VARCHAR(50) COMMENT 'c2'\n"
    ")COMMENT='tblA'\n"
    ";\n"
    "create or replace TABLE DB.S.B (\n"
    "  D1 VARCHAR(10) COMMENT 'd1'\n"
    ");\n"
)


def main():
    print("== 축1 정상 입력")
    rep = run(BASE_SRC, BASE_SRC)
    check("판정 축 0건", rep.total == 0, "total=%d %s" % (rep.total, rep.lines))

    print("== 축2 테이블 유실")
    dst = BASE_SRC.split("create or replace TABLE DB.S.B")[0]
    rep = run(BASE_SRC, dst)
    check("축1 검출", rep.axes[1] == 1, "axes=%s" % rep.axes)

    print("== 축3 컬럼 유실")
    dst = BASE_SRC.replace("  C2 VARCHAR(50) COMMENT 'c2'\n", "")
    dst = dst.replace("DEFAULT DB.S.SEQ.NEXTVAL COMMENT 'c1',", "DEFAULT DB.S.SEQ.NEXTVAL COMMENT 'c1'")
    rep = run(BASE_SRC, dst)
    check("축2 검출", rep.axes[2] == 1, "axes=%s" % rep.axes)

    print("== 축4 컬럼 타입 변형")
    rep = run(BASE_SRC, BASE_SRC.replace("C2 VARCHAR(50)", "C2 VARCHAR(200)"))
    check("축3 검출", rep.axes[3] == 1, "axes=%s" % rep.axes)
    check("다른 축은 조용", rep.axes[2] == 0 and rep.axes[5] == 0, "axes=%s" % rep.axes)

    print("== 축5 DEFAULT 유실")
    rep = run(BASE_SRC, BASE_SRC.replace(" DEFAULT DB.S.SEQ.NEXTVAL", ""))
    check("축4 검출", rep.axes[4] == 1, "axes=%s" % rep.axes)

    print("== 축6 COMMENT 변형")
    rep = run(BASE_SRC, BASE_SRC.replace("COMMENT 'c2'", "COMMENT 'c2-변형'"))
    check("축5 검출", rep.axes[5] == 1, "axes=%s" % rep.axes)

    print("== 축7 원천 미제공 → 인수인계 보강 (오탐 재발 방지)")
    src = BASE_SRC.replace(" COMMENT 'c2'", "")
    rep = run(src, BASE_SRC)
    check("판정 축 0건", rep.total == 0, "axes=%s %s" % (rep.axes, rep.lines))
    check("보강으로 집계", rep.enriched == 1, "enriched=%d" % rep.enriched)

    print("== 축8 양쪽 부재 · soft=False → blocking")
    both = BASE_SRC.replace(" COMMENT 'c2'", "")
    rep = run(both, both, soft=False)
    check("축5 검출", rep.axes[5] == 1, "axes=%s" % rep.axes)
    check("경고로 세지 않는다", len(rep.missing_soft) == 0, "soft=%s" % rep.missing_soft)

    print("== 축9 양쪽 부재 · soft=True → 경고만")
    rep = run(both, both, soft=True)
    check("판정 축 0건", rep.total == 0, "axes=%s" % rep.axes)
    check("경고 1건", len(rep.missing_soft) == 1, "soft=%s" % rep.missing_soft)

    print("== 축10 테이블 COMMENT 양쪽 부재 → 검출 0 (require=False)")
    no_tbl = BASE_SRC.replace(")COMMENT='tblA'\n", ")\n")
    rep = run(no_tbl, no_tbl)
    check("축6 0건", rep.axes[6] == 0, "axes=%s" % rep.axes)

    print("== 축11/12 문서 stale 검사 (축7)")
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        docs = d / G.DOC_DIR
        docs.mkdir(parents=True)
        # 단독 표기 3건 = 위반 / 현행값 동반 3건 = 면제 / 과거 실측 1건 = 면제
        (docs / "x.md").write_text(
            "총 67 테이블 이다\n"
            "브론즈 50 개\n"
            "04_2번 을 실행한다\n"
            "총계 67 테이블 → 69 로 정정\n"
            "브론즈 50 → 52 로 정정\n"
            "04_2번 은 실제로 06번 이다\n"
            "2026-08-12 측정 기준 브론즈 50\n",
            encoding="utf-8",
        )
        old_root = G.ROOT
        G.ROOT = d
        try:
            with redirect_stdout(io.StringIO()):
                hits, n_docs = G.axis7(True)
        finally:
            G.ROOT = old_root
    toks = sorted(h[2] for h in hits)
    check("축11 단독 표기 3건 검출", len(hits) == 3, "hits=%s" % toks)
    check("축12 현행값 동반·과거 실측은 면제",
          toks == ["04_2번", "67 테이블", "브론즈 50"], "toks=%s" % toks)
    check("검사 파일 수 1", n_docs == 1, "n_docs=%d" % n_docs)

    print("")
    print("합계: 단정 %d개 · 통과 %d · 실패 %d" % (PASSED + FAILED, PASSED, FAILED))
    if FAILED:
        print("🔴 FAIL")
        return 1
    print("🟢 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

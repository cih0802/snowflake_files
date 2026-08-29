#!/usr/bin/env python3
"""merge_check.py 음성 테스트 — 오염 기반.

🔴 왜 음성 테스트인가: `merge_check` 는 **삭제를 승인하는 판정기**다. 통과만 보면
「무엇이든 안전하다고 말하는 도구」와 구별되지 않는다(초판이 실제로 산문 파일 4건을
「토큰 0개 ⇒ 판정 불가」로 뭉갰다). ⇒ **일부러 깨서 검출되는지**를 단정한다.

축:
  1 재현율   — 정본에 없는 내용을 넣으면 🔴 로 잡는가
  2 정밀도   — 정본에 전부 있는 내용은 🟢 로 통과하는가
  3 임계값   — threshold 를 올리면 경계 사례가 뒤집히는가
  4 장식 무시 — `**`·백틱·`~~` 차이만 있으면 포함으로 볼 것인가
  5 잡음 제외 — 구분선·상투구만 있는 파일은 「내용 없음」으로 안전 판정하는가
  6 짧은 줄  — 30자 미만 줄은 분모에서 빠지는가(우연 일치 방지)
  7 종료코드 — 보류가 있으면 exit 1, 없으면 exit 0
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path("/workspace/scripts/merge_check.py")

PASS = []
FAIL = []


def check(name: str, cond: bool, detail: str = "") -> None:
    (PASS if cond else FAIL).append(name)
    print("  %s %s%s" % ("PASS" if cond else "FAIL", name,
                         ("  — " + detail) if detail else ""))


def run(tmp: Path, target: str, threshold: float = 0.95) -> tuple:
    """merge_check 를 임시 정본/대상으로 돌린다 (모듈을 직접 import 해 경로를 패치)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("mc_%s" % target.replace(".", "_"), SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.ROOT = tmp
    mod.CANON_DIRS = [tmp / "canon"]
    sys.argv = ["merge_check.py", target, "--threshold", str(threshold)]
    import io
    from contextlib import redirect_stdout
    buf = io.StringIO()
    try:
        with redirect_stdout(buf):
            rc = mod.main()
    except SystemExit as e:  # pragma: no cover
        rc = e.code
    return rc, buf.getvalue()


def main() -> int:
    print("=" * 74)
    print("merge_check.py 음성 테스트 (오염 기반)")
    print("=" * 74)

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        (tmp / "canon").mkdir()

        canon_line_a = "브론즈 적재가 예산 팩트의 그레인을 깼다 — 편성 차수가 키에 없다"
        canon_line_b = "집행 합계 99,006,005,048 은 실제 55,094,546,653 대비 79.7% 과대다"
        (tmp / "canon" / "c-001.md").write_text(
            "\n".join(["# 정본", canon_line_a, canon_line_b]), encoding="utf-8")

        # 축2 정밀도 — 정본에 전부 있는 파일
        (tmp / "_clean.md").write_text(
            "\n".join([canon_line_a, canon_line_b]), encoding="utf-8")
        rc, out = run(tmp, "_clean.md")
        check("축2.정밀도-정상통과", "🟢 삭제 안전 = 1건" in out and rc == 0,
              "포함율 100%% 기대")

        # 축1 재현율 — 정본에 없는 줄을 섞는다
        orphan = "이 문장은 정본 어디에도 없는 고유 내용이며 반드시 검출되어야 한다"
        (tmp / "_dirty.md").write_text(
            "\n".join([canon_line_a, canon_line_b, orphan]), encoding="utf-8")
        rc, out = run(tmp, "_dirty.md")
        check("축1.재현율-오염검출", "삭제 보류" in out and rc == 1,
              "미포함 1줄 ⇒ 보류 기대")
        check("축1.미포함줄-노출", orphan[:40] in out, "미포함 줄을 표본으로 보여야 한다")

        # 축7 종료코드
        check("축7.종료코드-보류시1", rc == 1)

        # 축3 임계값 — 2/3 포함(66.7%)은 0.95 에서 보류, 0.6 에서 안전
        rc_low, out_low = run(tmp, "_dirty.md", threshold=0.6)
        check("축3.임계값-완화시통과", "🟢 삭제 안전 = 1건" in out_low and rc_low == 0,
              "66.7%% ≥ 60%% ⇒ 안전")

        # 축4 장식 무시 — 같은 문장에 ** 과 백틱만 덧붙인다
        (tmp / "_decor.md").write_text(
            "**" + canon_line_a + "**\n~~" + canon_line_b + "~~", encoding="utf-8")
        rc, out = run(tmp, "_decor.md")
        check("축4.장식무시-정규화", "🟢 삭제 안전 = 1건" in out and rc == 0,
              "마크다운 장식 차이는 미포함으로 보지 않는다")

        # 축5 잡음만 있는 파일
        (tmp / "_noise.md").write_text(
            "---\n===\n\n# \n_Co-authored with CoCo_\n", encoding="utf-8")
        rc, out = run(tmp, "_noise.md")
        check("축5.잡음제외-내용없음", "유의 줄 0" in out and rc == 0,
              "구분선·상투구는 분모에서 빠진다")

        # 축6 짧은 줄은 분모 제외 — 정본에 없는 29자 줄만 담은 파일
        short = "짧은줄은분모에서빠져야한다우연일치"  # < 30자
        assert len(short) < 30
        (tmp / "_short.md").write_text(short + "\n", encoding="utf-8")
        rc, out = run(tmp, "_short.md")
        check("축6.짧은줄-분모제외", "유의 줄 0" in out and rc == 0,
              "30자 미만은 세지 않는다(우연 일치 방지)")

    print("-" * 74)
    print("PASS %d · FAIL %d" % (len(PASS), len(FAIL)))
    if FAIL:
        print("🔴 실패 축: %s" % ", ".join(FAIL))
        return 1
    print("🟢 PASS — 7축 %d단정 전건 통과" % len(PASS))
    return 0


if __name__ == "__main__":
    sys.exit(main())

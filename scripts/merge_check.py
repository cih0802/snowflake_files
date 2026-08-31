#!/usr/bin/env python3
"""임시 파일 병합 검증 — 삭제 전 실행 (O115 신설 · 개선판).

목적 = 루트의 `_oNNN_*.md` 임시 작업 파일을 지우기 전에 **그 내용이 정본에 실재하는지**
기계로 대조한다. 정본에 없는 내용을 담은 파일을 지우면 그 문장은 워크스페이스에서
영구히 사라진다(`R2-8-3`).

🔴 판정식 = **줄 단위 포함율**. 토큰(숫자)만 보면 숫자 없는 산문 파일이 「판정 불가」가 되어
   보수적으로 보류되지만, 그 보류는 「근거 있는 보류」가 아니라 「판정식이 못 본 것」이다
   (초판이 실제로 4/8 을 그렇게 만들었다 · `R3-9 ㉡` 축).
🔴 이 스크립트는 **삭제하지 않는다** — 판정만 낸다(`R1-7-7` 「삭제 전 영향 범위 실측」).

사용:
    python3 scripts/merge_check.py                 # 기본 대상 자동 탐색
    python3 scripts/merge_check.py _o115_entry.md  # 특정 파일만
    python3 scripts/merge_check.py --threshold 0.9
"""
import argparse
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path("/workspace")

CANON_DIRS = [
    ROOT / "20_issue" / "01_세션이력_조각",
    ROOT / "20_issue" / "00_INDEX_이슈원장_조각",
    ROOT / "20_issue" / "30_설계_의사결정_조각",
    ROOT / "20_issue" / "50_dbt_파이프라인_미결조치_조각",
    ROOT / "20_issue" / "10_진단_원인분석_조각",
    ROOT / "20_issue" / "02_상태상세_대시보드_갱신형_조각",
    ROOT / "99_NEXT_SESSION_조각",
]

# 이 접두를 가진 루트 파일이 기본 대상이다.
DEFAULT_GLOB = "_o*.md"

# 정본 대조에서 무의미한 줄(장식·구분선·공통 상투구)은 분모에서 뺀다.
NOISE = re.compile(
    r"^\s*(?:[-=*_]{3,}|#{1,6}\s*$|\|[\s\-:|]+\||>?\s*)$"
)
BOILERPLATE = ("Co-authored with CoCo", "LLM-METADATA", "END-METADATA")


def norm(s: str) -> str:
    """비교용 정규화 — 공백 축약 + 마크다운 장식 제거 + NFC."""
    s = unicodedata.normalize("NFC", s)
    s = s.replace("~~", "").replace("**", "").replace("`", "")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def canon_text() -> tuple:
    parts = []
    used = []
    for d in CANON_DIRS:
        if not d.is_dir():
            continue
        used.append(d.name)
        for f in sorted(d.glob("*.md")):
            parts.append(f.read_text(encoding="utf-8", errors="replace"))
    return norm("\n".join(parts)), used


def significant_lines(text: str) -> list:
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or NOISE.match(line):
            continue
        if any(b in line for b in BOILERPLATE):
            continue
        n = norm(line)
        # 너무 짧은 줄은 우연 일치가 흔하다 ⇒ 분모에서 제외(관측만)
        if len(n) < 30:
            continue
        out.append(n)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", help="검사할 파일(기본 = 루트 _o*.md)")
    ap.add_argument("--threshold", type=float, default=0.95,
                    help="삭제 안전 판정 포함율 하한 (기본 0.95)")
    ap.add_argument("--show", type=int, default=3, help="미포함 줄 표본 개수")
    args = ap.parse_args()

    canon, used = canon_text()
    print("정본 분모 = %d 문자 · 폴더 %d개(%s)"
          % (len(canon), len(used), ", ".join(used)))
    print("판정 = 줄 단위 포함율 ≥ %.0f%% 이면 🟢 삭제 안전" % (args.threshold * 100))
    print()

    if args.files:
        targets = [ROOT / f for f in args.files]
    else:
        targets = sorted(ROOT.glob(DEFAULT_GLOB))

    safe, unsafe = [], []
    unreadable = []
    for p in targets:
        if not p.exists():
            print("  ⚪ %-36s 파일 없음" % p.name)
            continue
        # 🆕 [2026-08-31 O126] OSError 를 잡는다 — 종전 판본은 여기서 **크래시해 전수 스캔을 못 끝냈다.**
        #   원인 = `_archive/` 로 이관된 파일의 **낡은 마운트 엔트리**가 남아 `exists()` 는 True 인데
        #   `read()` 가 `Errno 5` 를 낸다(`OPS-3` 「낡은 뷰」 · 실물 = `_o125e_entry.md`).
        #   🔴 실해 = 착수표 ㉝(`_o114b` 미이관분 판정)의 도구가 **한 파일 때문에 통째로 막혀 있었다.**
        #   🟢 판정식 = 「읽을 수 없는 것」은 「내용이 없는 것」과 다르다 ⇒ **삭제 안전으로 세지 않고
        #      별 축으로 보고**한다(안전으로 오분류하면 실제 원고를 지울 수 있다).
        try:
            raw = p.read_text(encoding="utf-8", errors="replace")
        except OSError as e:
            print("  🔴 %-36s 읽기 실패(%s) — 스테이지 실체를 `cortex ws ls` 로 확인하라"
                  % (p.name, e.__class__.__name__))
            unreadable.append(p)
            continue
        lines = significant_lines(raw)
        if not lines:
            print("  🟠 %-36s 유의 줄 0 ⇒ 내용 없음(삭제 무해)" % p.name)
            safe.append(p)
            continue
        missing = [ln for ln in lines if ln not in canon]
        ratio = 1.0 - len(missing) / len(lines)
        ok = ratio >= args.threshold
        mark = "🟢" if ok else "🔴"
        print("  %s %-36s 유의 줄 %4d · 포함 %4d · 미포함 %4d · 포함율 %5.1f%%"
              % (mark, p.name, len(lines), len(lines) - len(missing),
                 len(missing), ratio * 100))
        for ln in missing[: args.show]:
            print("        ↳ 미포함: %s" % (ln[:110] + ("…" if len(ln) > 110 else "")))
        (safe if ok else unsafe).append(p)

    print()
    print("🟢 삭제 안전 = %d건" % len(safe))
    for p in safe:
        print("   · %s" % p.name)
    if unsafe:
        print("🔴 삭제 보류(정본에 없는 내용 보유) = %d건" % len(unsafe))
        for p in unsafe:
            print("   · %s" % p.name)
        print("   ⇒ 🔴 지우려면 **먼저 그 내용을 정본으로 이관**하라(`R2-8-1` 토큰 대조).")
    if unreadable:
        print("🔴 읽기 불가(판정 불가) = %d건" % len(unreadable))
        for p in unreadable:
            print("   · %s" % p.name)
        print("   🔴 **「삭제 안전」이 아니다 — 판정을 하지 못한 것이다.**")
        print("   ⇒ `cortex ws ls 'USER$.PUBLIC.\"snowflake_files\":/'` 로 스테이지 실체를 보라.")
        print("      · 스테이지에 없고 `_archive/` 에 있으면 **이미 이관된 것**이고 마운트 엔트리만")
        print("        낡은 것이다(`OPS-3`) ⇒ 그 항목은 처리 완료로 보아도 된다.")
        print("      · 스테이지에 **있는데도** 읽기가 실패하면 손상 가능성이다 ⇒ 지우지 마라.")
    print()
    print("🔴 이 스크립트는 삭제하지 않는다 — 판정만 낸다.")
    return 0 if not (unsafe or unreadable) else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# O170 — 승계 인수인계 절 은퇴 드라이버.
# 🔴 승인 = 2026-09-17 사용자 「retire_sections.py 를 승인」 (`R4-4-3`).
# 🔴 판정식은 창작하지 않는다 — 승계 여부는 `session_brief.superseded()` 가 정한다(분모 일원화 · J8).
#
# 안전 계약(도구가 보증하는 것) =
#   ㉠ 제목 줄은 `##`·`###` 전건 **원본에 남는다**(`body_lines` 가 제목을 제외한다)
#      ⇒ `doc_heading_gate` 유실 0 · `§` 인용 생존.
#   ㉡ `##` 절의 span 은 다음 **동급 이상** 제목까지이므로 하위 `###` 본문이 함께 간다.
#   ㉢ 목적지가 허브면 `--rollover` 경로를 쓴다(허브 직접 append 금지 · O107 자기시정).
# 🔴 이 드라이버가 추가하는 것 = **배치 + 실패 즉시 중단 + 조각별 rc 기록**.
#   `--force` 를 쓴다 — 승계 절 제목은 🔴 로 시작해 「열림」으로 판정되지만
#   **승계 표기가 곧 「다음 세션이 읽지 않는다」는 계약**이고 현행 정보는 현행 절에 있다.
import argparse
import glob
import io
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_brief import superseded  # noqa: E402

HEAD2 = re.compile(r"^## ")
HEADANY = re.compile(r"^#{2,6} ")
# 🔴🔴 [dry-run 적발] `--sections` 는 **제목 부분문자열** 매치다 ⇒ 라벨(`0-DDDD`)을 선택자로 쓰면
#   **그 라벨을 언급하는 다른 절까지 잡는다**(실측 = `0-CCCC` 절이 *"§0-DDDD 로 승계됨"* 을 적어
#   함께 매칭 · `0-YYY` 가 하위 `▣ YYY1`(그 제목이 `§0-YYY` 를 담는다)을 매칭).
#   🟢 처방 = 선택자를 **`날짜 + 세션 라벨`**(`2026-08-31 O126`)로 바꾼다 — 절 제목의 발행 서명이라
#   다른 절이 인용하지 않는다. 🔴 그리고 **그 조각 안 전 제목에서 유일한지 단정**한 뒤 넘긴다.
#   🟢 판정식 = **부분문자열 선택자는 「유일함」을 증명한 뒤에만 쓴다**(`R1-7-8` 앵커 규율의 도구 판본).
SIG = re.compile(r"\[?(\d{4}-\d{2}-\d{2} O\d+(?:-[A-Z])?)")


def targets(chunk):
    """그 조각의 **승계된 level-2 절** 선택자 목록.

    🔴 선택자는 `날짜 + 세션 라벨` 이고 **그 조각의 전 제목에서 유일**해야 통과한다.
    유일하지 않거나 서명이 없으면 **건너뛰고 보고**한다(사람이 손으로 처리한다).
    """
    lines = io.open(chunk, encoding="utf-8").read().split("\n")
    heads = [l for l in lines if HEADANY.match(l)]
    out, skipped = [], []
    for l in lines:
        if not HEAD2.match(l):
            continue
        if not superseded(l):
            continue
        m = SIG.search(l)
        if not m:
            skipped.append(("서명 없음", l[:90]))
            continue
        tok = m.group(1)
        hits = [h for h in heads if tok in h]
        if len(hits) != 1:
            skipped.append(("유일하지 않음(%d)" % len(hits), l[:90]))
            continue
        out.append(tok)
    return out, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chunks", required=True, help="조각 번호 범위 예: 1-5 또는 1,3,9")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    nums = []
    for part in a.chunks.split(","):
        if "-" in part:
            s, e = part.split("-")
            nums.extend(range(int(s), int(e) + 1))
        else:
            nums.append(int(part))

    allc = sorted(glob.glob("99_NEXT_SESSION_조각/99_NEXT_SESSION-*.md"))
    bynum = {int(re.search(r"-(\d{3})\.md$", p).group(1)): p for p in allc}

    total = 0
    for n in nums:
        p = bynum.get(n)
        if not p:
            print("SKIP %03d (조각 없음)" % n)
            continue
        labs, skipped = targets(p)
        for why, t in skipped:
            print("  ⚠️ 건너뜀(%s): %s" % (why, t))
        if not labs:
            print("SKIP %s (승계 level-2 절 0)" % os.path.basename(p))
            continue
        cmd = ["python3", "scripts/retire_sections.py",
               "--src", p,
               "--sections", ",".join(labs),
               "--to", "20_issue/90_해소완료_로그.md",
               "--to-section", "🟢 [O170 은퇴] 99_NEXT 승계 인수인계 절 — %s" % os.path.basename(p),
               "--label", "O170",
               "--force"]
        if a.apply:
            cmd.append("--apply")
        print("▶ %s  절 %d개 = %s" % (os.path.basename(p), len(labs), ",".join(labs)))
        r = subprocess.run(cmd, capture_output=True, text=True)
        # 🔴🔴 사후 단정 = 도구가 잡은 절 수가 **지정한 수와 같은가** · **전건 lv2 인가**.
        #   dry-run 에서 부분문자열 오매칭(lv3 자식 · 타 절)이 실제로 났으므로 이 단정을 코드에 박는다.
        rows = [l for l in r.stdout.split("\n") if re.search(r"\blv\d\b", l)]
        lv2 = [l for l in rows if " lv2 " in l]
        if r.returncode != 0 or len(rows) != len(labs) or len(lv2) != len(labs):
            print("🔴 중단 — rc=%d · 매칭 %d(lv2 %d) ≠ 지정 %d"
                  % (r.returncode, len(rows), len(lv2), len(labs)))
            for l in rows:
                print("    %s" % l[:160])
            print(r.stdout[-1500:])
            print(r.stderr[-800:])
            sys.exit(1)
        tail = [l for l in r.stdout.split("\n") if l.strip()][-2:]
        for l in tail:
            print("   %s" % l)
        total += len(labs)
    print("")
    print("완료 · 절 %d개 처리 (apply=%s)" % (total, a.apply))


if __name__ == "__main__":
    main()

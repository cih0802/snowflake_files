#!/usr/bin/env python3
# O170 — 인수인계 절 §0-XXXX/O170 을 99_NEXT-035 조각 말미에 붙인다.
# 🔴 `cat >>` 는 이 마운트에서 조용히 유실된다(O167 실사고) ⇒ python 전량 쓰기 + 도달 토큰 재검사.
# 🔴 붙인 뒤 §0-WWWW/O171 의 「여기서 시작한다」를 취소선으로 승계 표기한다.
import io
import sys

CHUNK = "99_NEXT_SESSION_조각/99_NEXT_SESSION-035.md"
ENTRY = "tmp/_o170_handoff.md"
TAIL = "_Co-authored with CoCo_"

OLD_START = "## 0-WWWW/O171. 🔴🔴 [2026-09-17 O171 필독 — **여기서 시작한다.** §0-VVVV/O169 는 승계됐다]"
NEW_START = ("## 0-WWWW/O171. 🔴🔴 [2026-09-17 O171 — ~~여기서 시작한다.~~ "
             "**§0-XXXX/O170 로 승계** · §0-VVVV/O169 는 승계됐다]")

src = io.open(CHUNK, encoding="utf-8").read()
entry = io.open(ENTRY, encoding="utf-8").read()

if "0-XXXX/O170" in src:
    print("SKIP: 이미 등재")
    sys.exit(0)

# ㉠ 승계 표기 — 🔴 제목줄 전체를 앵커로 쓴다(부분 접두 금지 · R1-7-8)
if OLD_START not in src:
    print("ABORT: 승계 대상 제목줄을 찾지 못했다")
    print(repr([l for l in src.split("\n") if l.startswith("## 0-WWWW")]))
    sys.exit(1)
src = src.replace(OLD_START, NEW_START, 1)

# ㉡ 말미 서명 앞에 절을 삽입한다(서명은 조각 1개당 1회여야 하므로 재사용)
idx = src.rfind(TAIL)
if idx < 0:
    print("ABORT: 말미 서명을 찾지 못했다")
    sys.exit(1)
out = src[:idx] + entry.rstrip("\n") + "\n\n" + src[idx:]

io.open(CHUNK, "w", encoding="utf-8").write(out)

# ㉢ 도달 재검사 — 「썼다」와 「닿았다」는 다르다
back = io.open(CHUNK, encoding="utf-8").read()
checks = {
    "절 제목 0-XXXX/O170": back.count("## 0-XXXX/O170."),
    "▣ O170-0": back.count("▣ O170-0"),
    "▣ O170-4": back.count("▣ O170-4"),
    "승계 표기": back.count("§0-XXXX/O170 로 승계"),
    "구 시작문구 잔존(0 이어야)": back.count("**여기서 시작한다.** §0-VVVV/O169"),
    "새 시작문구": back.count("**여기서 시작한다.** §0-WWWW/O171 은 승계됐다"),
}
print("바이트 %d → %d" % (len(src.encode()), len(back.encode())))
for k, v in checks.items():
    print("  %s = %d" % (k, v))

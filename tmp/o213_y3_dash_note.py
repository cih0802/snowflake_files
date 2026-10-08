"""O213 — 마케팅채널 차원 COMMENT 4곳에 「-」 코드 실측 사실을 덧붙인다(앵커 정확히 1회일 때만)."""
import io, sys

APPLY = "--apply" in sys.argv
D = "/workspace/05_SV-Agent_ai/"
ADD = " 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 캠페인 37,204 중 5,211 · 2026-10-08 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다."
T = [
    ("23_MSTR_SV_DDL.sql", "C002 · 100여 종). 캠페인 마스터 현재값. 🔴 개발인입경로(MM293)와 다른 축이다.'"),
    ("05_2_SV_DDL_MEMBER_EVENT.sql", "— 사건 시점 동결값. 🔴 개발인입경로(MM293)와 다른 축이다.'"),
    ("05_3_SV_DDL_MEMBER_COHORT.sql", "획득 캠페인의 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값.'"),
    ("05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql", "캠페인 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값.'"),
]
bad = 0
for f, anchor in T:
    t = io.open(D + f, encoding="utf-8").read()
    n = t.count(anchor)
    print(("OK " if n == 1 else "🔴 ") + f + f" ×{n}")
    if n != 1:
        bad += 1
        continue
    if APPLY:
        io.open(D + f, "w", encoding="utf-8").write(t.replace(anchor, anchor[:-1] + ADD + "'"))
print("bad", bad, "APPLY" if APPLY and not bad else "DRY-RUN")
sys.exit(1 if bad else 0)

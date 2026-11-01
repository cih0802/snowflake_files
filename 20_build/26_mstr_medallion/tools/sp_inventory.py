"""MSTR 원본 sp_script.sql(UTF-16) → 프로시저별 대상·원천 인벤토리(O202).

사용: python3 sp_inventory.py  → ../01_MSTR_SP_인벤토리.md 생성
"""
import collections
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "15_MSTR 이관 PoC", "mstr DDL 원본")
OUT = os.path.join(HERE, "..", "01_MSTR_SP_인벤토리.md")
DONE = os.path.join(HERE, "..", "..", "15_MSTR 이관 PoC", "snowflake 적용 ddl", "04_sp_script.sql")

ODS = re.compile(r"(?i)\b(T[MDCN]_[A-Z]{2}_[A-Z0-9_]+|FN_[A-Z]{2}_[A-Z0-9_]+)\b")
TGT = re.compile(r"(?i)\b(?:insert\s+into|merge\s+into|truncate\s+table|update)\s+\[?(?:mart\]?\.)\[?([DF]_[A-Z0-9_]+)")


def load(name):
    return io.open(os.path.join(SRC, name), encoding="utf-16").read()


def main():
    sp = load("sp_script.sql")
    done = io.open(DONE, encoding="utf-8").read().upper() if os.path.exists(DONE) else ""
    parts = re.split(r"(?im)^\s*create\s+(?:procedure|proc)\s+", sp)[1:]
    rows = []
    for p in parts:
        name = re.sub(r"[\[\]]", "", p.split(None, 1)[0]).replace("mart.", "").split("(")[0]
        tg = sorted(set(m.upper() for m in TGT.findall(p)))
        srcs = collections.Counter(m.upper() for m in ODS.findall(p))
        dom = collections.Counter(s.split("_")[1] for s in srcs)
        kind = "D" if name.upper().startswith("USP_D_") else ("F" if name.upper().startswith("USP_F_") else "기타")
        rows.append((kind, name, len(p.splitlines()), tg, srcs, dom, name.upper() in done))
    lines = [
        "# 01. MSTR SP 인벤토리 (자동 생성 · O202)",
        "",
        "> 생성 = `tools/sp_inventory.py` · 원본 = `15_MSTR 이관 PoC/mstr DDL 원본/sp_script.sql`(UTF-16).",
        "> 🔴 손으로 고치지 마라 — 재생성하면 사라진다. 정규식 추출이라 동적 SQL 안의 대상은 빠질 수 있다.",
        "",
    ]
    tot = collections.Counter(r[0] for r in rows)
    lines.append("| 구분 | 프로시저 수 | 1차 이관 완료 |")
    lines.append("|---|---|---|")
    for k in ("D", "F", "기타"):
        lines.append("| %s | %d | %d |" % (k, tot[k], sum(1 for r in rows if r[0] == k and r[6])))
    lines.append("")
    lines.append("| 구분 | 프로시저 | 줄 | 1차 | 적재 대상 | 원천 도메인 | 주요 원천(상위 4) |")
    lines.append("|---|---|---|---|---|---|---|")
    for kind, name, n, tg, srcs, dom, d in sorted(rows):
        lines.append("| %s | `%s` | %d | %s | %s | %s | %s |" % (
            kind, name, n, "✅" if d else "",
            " · ".join(tg[:3]) + (" 외" if len(tg) > 3 else ""),
            " · ".join("%s %d" % x for x in dom.most_common(3)),
            " · ".join(s for s, _ in srcs.most_common(4)),
        ))
    lines.append("")
    lines.append("_Co-authored with CoCo_")
    io.open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("rows=%d D=%d F=%d etc=%d done=%d" % (len(rows), tot["D"], tot["F"], tot["기타"], sum(r[6] for r in rows)))


if __name__ == "__main__":
    main()

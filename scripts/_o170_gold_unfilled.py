#!/usr/bin/env python3
# O170 ④ — GOLD 미주입 컬럼 전수 재집계 (판정식 = O43/O167 판본 그대로)
#   미주입 = nonzero == 0  (감사컬럼 DW_* 제외 · 0행 테이블은 별도 축)
# 🔴 이 도구는 census 를 스스로 세지 않고 /tmp/census.json 을 읽는다(분모를 하나로 둔다 · J8).
import json
import io

CEN = json.load(open("/tmp/census.json", encoding="utf-8"))

gold = {k: v for k, v in CEN.items() if k.startswith("GOLD.")}

tot_cols = 0
injected = 0
zero_all = []      # 전건 0 (nonnull > 0, nonzero == 0)
null_all = []      # 전건 NULL (nonnull == 0)
zerorow = []       # 0행 테이블 소속
n_tbl = 0

for key in sorted(gold):
    ent = gold[key]
    rows = ent["rows"]
    n_tbl += 1
    for c, m in ent["cols"].items():
        if c.startswith("DW_"):
            continue
        tot_cols += 1
        nn = m["nonnull"] or 0
        nz = m["nonzero"] or 0
        if rows == 0:
            zerorow.append((key, c, m["type"]))
        elif nz == 0:
            if nn == 0:
                null_all.append((key, c, m["type"]))
            else:
                zero_all.append((key, c, m["type"], nn))
        else:
            injected += 1

unfilled = len(zero_all) + len(null_all) + len(zerorow)

out = []
out.append("# O170 ④ GOLD 미주입 전수 재집계 (라이브 RY53492 · 2026-09-17)")
out.append("")
out.append("| 구분 | 건수 | 비중 |")
out.append("|---|---:|---:|")
out.append("| GOLD 기본테이블 | %d | — |" % n_tbl)
out.append("| DATA 컬럼(`DW_*` 제외) | **%d** | 100%% |" % tot_cols)
out.append("| 값 주입됨 | **%d** | %.1f%% |" % (injected, 100.0 * injected / tot_cols))
out.append("| 전건 `0` | **%d** | %.1f%% |" % (len(zero_all), 100.0 * len(zero_all) / tot_cols))
out.append("| 전건 `NULL` | **%d** | %.1f%% |" % (len(null_all), 100.0 * len(null_all) / tot_cols))
out.append("| 0행 테이블 소속 | **%d** | %.1f%% |" % (len(zerorow), 100.0 * len(zerorow) / tot_cols))
out.append("| **미주입 합계** | **%d** | **%.1f%%** |" % (unfilled, 100.0 * unfilled / tot_cols))
out.append("")

out.append("## 전건 `NULL` %d건" % len(null_all))
out.append("")
out.append("| 테이블 | 컬럼 | 타입 |")
out.append("|---|---|---|")
for k, c, t in sorted(null_all):
    out.append("| `%s` | `%s` | %s |" % (k.replace("GOLD.", ""), c, t))
out.append("")

out.append("## 전건 `0` %d건" % len(zero_all))
out.append("")
out.append("| 테이블 | 컬럼 | 타입 | non-NULL |")
out.append("|---|---|---|---:|")
for k, c, t, nn in sorted(zero_all):
    out.append("| `%s` | `%s` | %s | %d |" % (k.replace("GOLD.", ""), c, t, nn))
out.append("")

out.append("## 0행 테이블 소속 %d건" % len(zerorow))
out.append("")
zt = sorted(set(k for k, _, _ in zerorow))
for k in zt:
    cs = [c for kk, c, _ in sorted(zerorow) if kk == k]
    out.append("- `%s` (%d컬럼) = %s" % (k.replace("GOLD.", ""), len(cs), " · ".join("`%s`" % c for c in cs)))
out.append("")

io.open("/tmp/o170_gold_unfilled.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("테이블 %d · DATA컬럼 %d · 주입 %d · 미주입 %d (전건0 %d · 전건NULL %d · 0행 %d) · 비중 %.1f%%"
      % (n_tbl, tot_cols, injected, unfilled, len(zero_all), len(null_all), len(zerorow),
         100.0 * unfilled / tot_cols))
print("WROTE /tmp/o170_gold_unfilled.md")

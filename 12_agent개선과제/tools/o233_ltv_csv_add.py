# O233 — O231_LTV_현업비교표.csv 에 회신 반영 열(상한80·무기한 × 최초/최종중단)을 키(분류축·분류값)로 덧붙인다.
# 값 출처 = GN_DW.PUBLIC.TMP_O233_SUM(jw08094 · 2026-10-15) · 기존 열은 건드리지 않는다.
# Co-authored with CoCo
import csv, io, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))
from sfconn import q

P = os.path.join(os.path.dirname(__file__), "..", "output", "O231_LTV_현업비교표.csv")
NEW = ["최대 관측월", "상한80 최초중단", "상한80 최종중단", "80개월 생존율 최초(%)", "80개월 생존율 최종(%)",
       "무기한 최초중단", "무기한 최종중단", "80 외삽 여부(최대 관측월<80)"]

_, rows = q("select AT, AV, MAXT, F80, L80, F_S80, L_S80, FINF, LINF from GN_DW.PUBLIC.TMP_O233_SUM")
m = {(r[0], r[1]): r[2:] for r in rows}

with io.open(P, encoding="utf-8-sig", newline="") as f:
    data = list(csv.reader(f))
hdr, body = data[0], data[1:]
if NEW[0] in hdr:
    # 재실행 = 앞선 실행이 붙인 열만 걷어낸다(원본 열 수 = NEW 시작 위치)
    k = hdr.index(NEW[0])
    hdr, body = hdr[:k], [r[:k] for r in body]
miss = 0
for r in body:
    v = m.get((r[0], r[1]))
    if v is None:
        miss += 1
        r.extend([""] * len(NEW))
        continue
    maxt = int(v[0])
    r.extend([str(maxt)] + [str(x) for x in v[1:]] + ["Y" if maxt < 80 else "N"])
with io.open(P, "w", encoding="utf-8-sig", newline="") as f:
    csv.writer(f).writerows([hdr + NEW] + body)
print(f"rows={len(body)} matched={len(body) - miss} missing={miss}")

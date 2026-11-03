"""O213 — 캠페인 마스터 분류 축 × SV 차원 배선 매트릭스(SHOW SEMANTIC DIMENSIONS 덤프 → 판정)."""
import csv, io, sys, collections

SRC = sys.argv[1]
OUT = sys.argv[2]

# 축 = 캠페인 마스터(SILVER.CRM_CAMPAIGN) 라벨 컬럼 · 판정 = 차원명 토큰 또는 동의어 토큰
AXES = [
    ("캠페인", ["CMPGN_NM", "CAMPAIGN_NAME", "CAMPAIGN_NM"], ["캠페인", "캠페인명"]),
    ("상위캠페인", ["PARENT_CAMPAIGN", "UPPER_CMPGN", "UPR_CMPGN"], ["상위캠페인"]),
    ("브랜드(BRND_NM)", ["BRND_NM", "BRAND_NAME", "BRAND_NM"], ["브랜드", "세부 브랜드", "원천 브랜드"]),
    ("공통브랜드(MM297)", ["CMMN_BRND", "COMMON_BRAND"], ["공통브랜드"]),
    ("홍보방법(CM008)", ["PROMO", "PR_MTH"], ["홍보방법"]),
    ("캠페인카테고리(MM294)", ["CMPGN_CTGR", "CAMPAIGN_CATEGORY", "CTGR"], ["캠페인카테고리", "카테고리"]),
    ("개발인입경로(MM293)", ["INFLOW_PATH", "INFLW"], ["개발인입경로", "인입경로"]),
    ("캠페인유형1(MM295)", ["CMPGN_TYPE1", "CAMPAIGN_TYPE1"], ["캠페인유형", "국내/해외"]),
    ("캠페인유형2(MM296)", ["CMPGN_TYPE2", "CAMPAIGN_TYPE2"], ["캠페인유형2"]),
    ("마케팅캠페인(C001)", ["MK_CMPGN", "MKTG_CMPGN", "MKTG_CAMPAIGN"], ["마케팅캠페인", "나마본캠페인"]),
    ("마케팅UTM(U001)", ["UTM"], ["UTM"]),
    ("마케팅채널(C002)", ["MKTG_CHANNEL", "MARKETING_CHANNEL"], ["마케팅채널"]),
    ("법인구분(CM019)", ["CPR_DIV", "CORP_DIV", "CPR_NM"], ["법인", "법인구분"]),
    ("후원구분(CM035)", ["SPNSR_DIV"], ["후원구분"]),
]

rows = list(csv.reader(io.open(SRC, encoding="utf-8")))
hdr_i = next(i for i, r in enumerate(rows) if r and r[0] == "database_name")
hdr = rows[hdr_i]
ix = {h: i for i, h in enumerate(hdr)}
sv_dims = collections.defaultdict(list)
for r in rows[hdr_i + 1:]:
    if len(r) < len(hdr):
        continue
    sv_dims[r[ix["semantic_view_name"]]].append(
        (r[ix["table_name"]], r[ix["name"]], r[ix["synonyms"]])
    )

def hit(axis, dim):
    _, names, syns = axis
    tbl, name, syn = dim
    if any(t in name.upper() for t in names):
        return True
    return any('"%s"' % s in syn for s in syns)

out = io.open(OUT, "w", encoding="utf-8")
out.write("SV\t" + "\t".join(a[0] for a in AXES) + "\n")
cover = collections.Counter()
for sv in sorted(sv_dims):
    cells = []
    for a in AXES:
        ds = [d[0] + "." + d[1] for d in sv_dims[sv] if hit(a, d)]
        if ds:
            cover[a[0]] += 1
        cells.append(",".join(ds) if ds else "-")
    if any(c != "-" for c in cells):
        out.write(sv + "\t" + "\t".join(cells) + "\n")
out.write("\n# 축별 배선 SV 수\n")
for a in AXES:
    out.write("%s\t%d\n" % (a[0], cover[a[0]]))
out.write("\n# SV 수 = %d\n" % len(sv_dims))
out.close()
print("OK", len(sv_dims))

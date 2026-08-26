# DEC-42 → DEC-43 개번 (O96 의 DEC42 와 라벨 충돌 해소 · R1-4-2 위반 시정)
# Co-authored with CoCo
# 안전 규약: R1-7-2 해시 안정성 2회 확인 → 치환 → 건수·해시 사후 검증.
#   O96 소관 표기(하이픈 없는 'DEC42')와 99_NEXT_SESSION-001.md 는 대상에서 제외한다.
import hashlib
import os
import sys

TARGETS = [
    "20_issue/30_설계_의사결정-009.md",
    "20_issue/50_dbt_파이프라인_미결조치-018.md",
    "10_dbt_pipeline/models/gold/dim/DIM_MEMBER_ACQUISITION.sql",
    "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_COHORT.sql",
    "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql",
    "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_SPONSOR_BIZ.sql",
    "10_dbt_pipeline/models/silver/crm/CRM_CAMPAIGN.sql",
    "10_dbt_pipeline/models/silver/crm/CRM_MEMBER_DEV.sql",
    "05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql",
    "05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql",
    "03_top-down_gold/06_DDL.sql",
    "04_silver_design/08_SILVER_테이블DDL_20260714.sql",
]

OLD = "DEC-42"
NEW = "DEC-43"


def read_stable(path):
    """R1-7-2: 같은 파일을 2회 읽어 크기·SHA256 이 동일해야 착수."""
    a = open(path, "rb").read()
    b = open(path, "rb").read()
    if a != b:
        return None
    return a


fail = 0
total_before = 0
total_after = 0

for rel in TARGETS:
    if not os.path.exists(rel):
        print("MISSING " + rel)
        fail += 1
        continue
    raw = read_stable(rel)
    if raw is None:
        print("UNSTABLE(중단) " + rel)
        fail += 1
        continue
    text = raw.decode("utf-8")
    n_before = text.count(OLD)
    # 하이픈 없는 DEC42(O96 소관)는 건드리지 않는다 — 치환 토큰에 하이픈이 있어 구조적으로 안전.
    n_o96 = text.count("DEC42")
    new_text = text.replace(OLD, NEW)
    n_after = new_text.count(NEW) - text.count(NEW)
    if n_after != n_before:
        print("COUNT-MISMATCH " + rel)
        fail += 1
        continue
    open(rel, "w", encoding="utf-8").write(new_text)
    verify = open(rel, encoding="utf-8").read()
    left = verify.count(OLD)
    got = verify.count(NEW) - text.count(NEW)
    o96_kept = verify.count("DEC42") == n_o96
    total_before += n_before
    total_after += got
    print(
        "OK %-58s %d건 치환 · 잔존 %d · O96(DEC42) %d건 보존=%s · SHA %s"
        % (
            rel.split("/")[-1],
            got,
            left,
            n_o96,
            o96_kept,
            hashlib.sha256(verify.encode("utf-8")).hexdigest()[:12],
        )
    )
    if left != 0 or not o96_kept:
        fail += 1

print("")
print("합계 = 치환 대상 %d · 치환 완료 %d · 실패 %d" % (total_before, total_after, fail))
sys.exit(1 if fail else 0)

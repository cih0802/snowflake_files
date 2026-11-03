#!/usr/bin/env python3
"""O250-E · 35_·36_ 의 SV 4종을 05_27~05_30 단독 정본 파일로, 뷰 2종을 21_ 말미로 이관한다.
원문 블록을 문자 그대로 옮기고(가필 = 머리말·스모크만) 이관 후 토큰 대조(R2-8-1)를 한다. 35_·36_ 본문은 지우지 않는다."""
import hashlib
import re
import sys
import time
from pathlib import Path

D = Path("/workspace/05_SV-Agent_ai")
F35 = D / "35_O249_SV_신설_광고비배분_개발사건코호트.sql"
F36 = D / "36_O250_ML예측_7축확장.sql"
F21 = D / "21_ML_SERVING_뷰_DDL.sql"


def stable(p):
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    time.sleep(1)
    if hashlib.sha256(p.read_bytes()).hexdigest() != h:
        sys.exit(f"🔴 해시 불안정 {p.name}")


for p in (F35, F36, F21):
    stable(p)
t35 = F35.read_text(encoding="utf-8")
t36 = F36.read_text(encoding="utf-8")


def block(text, start, end_pat):
    i = text.index(start)
    m = re.compile(end_pat, re.S).search(text, i)
    return text[i:m.end()].rstrip() + "\n"


def grants(text, obj):
    return "".join(l + "\n" for l in text.splitlines() if l.startswith("GRANT") and obj + " TO" in l)


SV = [
    ("05_27_SV_DDL_AD_INFLOW_ALLOC.sql", "SV_AD_INFLOW_ALLOC", t35, "O249",
     "광고비 → 개발인입경로 배분 · 인입경로별 개발단가 (마케팅 Agent · analyst_ad_inflow_alloc)",
     "GN_DW.GOLD.FACT_AD_INFLOW_ALLOC · DIM_MARKETING_CAMPAIGN(03_top-down_gold/06_DDL.sql · dbt build)",
     "SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD_INFLOW_ALLOC\n  DIMENSIONS aia.ROW_KIND METRICS aia.TOTAL_AD_COST_ALLOC, aia.TOTAL_DEV_CNT);\n"),
    ("05_28_SV_DDL_MEMBER_EVENT_COHORT.sql", "SV_MEMBER_EVENT_COHORT", t35, "O249",
     "회원 개발사건 × 경과월(0~12) 코호트 (회원 Agent · analyst_member_event_cohort)",
     "GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT(03_top-down_gold/06_DDL.sql · dbt build)",
     "SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT_COHORT\n  DIMENSIONS mec.DVLP_DIV_NM METRICS mec.EVENT_MEMBERS, mec.ACTIVE_RATE\n  WHERE mec.MONTHS_AFTER = 12);\n"),
    ("05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql", "SV_ML_MEMBER_PRED_AXIS", t36, "O250",
     "ML 회원예측(중단·증액) + 미납 실적 × 7축 (3 Agent · analyst_ml_pred_axis)",
     "GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V(21_ML_SERVING_뷰_DDL.sql [O250] 절) ⇒ 🔴 21_ 다음에 실행",
     "SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS\n  DIMENSIONS pa.STDR_MT METRICS pa.PREDICTED_MEMBERS, pa.EXPECTED_CHURN_MEMBERS, pa.EXPECTED_INC_MEMBERS);\n"),
    ("05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql", "SV_ML_FEE_FORECAST_AXIS", t36, "O250",
     "ML 회비 예측 × 7축 실적 비중 배분 추정 (MEMBER·MARKETING · analyst_ml_fee_axis)",
     "GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V(21_ML_SERVING_뷰_DDL.sql [O250] 절) ⇒ 🔴 21_ 다음에 실행",
     "SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS\n  DIMENSIONS fx.STDR_MT, fx.IS_ALLOCATED METRICS fx.TOTAL_ALLOC_FORECAST_FEE);\n"),
]

made = []
for fname, sv, src, ses, desc, pre, smoke in SV:
    out = D / fname
    if out.exists():
        sys.exit(f"🔴 이미 있다 — 덮지 않는다: {fname}")
    body = block(src, f"CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.{sv}\n", r"\n\s*;\s*\n|';\s*\n")
    if not body.rstrip().endswith(";"):
        body = body.rstrip() + "\n;\n"
    g = grants(src, f"SEMANTIC VIEW GN_DW.SERVING.{sv}")
    if g.count("GRANT") != 3:
        sys.exit(f"🔴 {sv} GRANT {g.count('GRANT')}건")
    head = (
        "-- ============================================================================\n"
        f"-- {fname} — Semantic View DDL 정본: {sv} (🆕 {ses} · O250-E 단독 파일로 이관)\n"
        "--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.\n"
        f"--   · 대상 = {desc}\n"
        f"--   · 선행 = {pre}\n"
        f"--   · 원 배포 파일 = {('35_O249_SV_신설_광고비배분_개발사건코호트.sql' if ses == 'O249' else '36_O250_ML예측_7축확장.sql')}"
        "(이력 보존 · 문면 무변경 이관)\n"
        "--   · 공통 규약 = 05_0_SV_DDL.sql\n"
        "-- Co-authored with CoCo\n"
        "-- ============================================================================\n"
        "USE ROLE GN_DW_ADMIN;\nUSE WAREHOUSE GN_DW_DEV_WH;\nUSE SCHEMA GN_DW.SERVING;\n\n"
    )
    text = head + body + "\n" + g + "\n-- 스모크\nUSE WAREHOUSE GN_DW_ANALYTICS_WH;\n" + smoke
    out.write_text(text, encoding="utf-8")
    made.append((out, body))

# 뷰 2종 → 21_ 말미
t21 = F21.read_text(encoding="utf-8")
if "ML_MEMBER_PRED_AXIS_V" not in t21:
    v1 = block(t36, "CREATE OR REPLACE VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V (", r"AND b\.MBER_NO = r\.MBER_NO;\n")
    v2 = block(t36, "CREATE OR REPLACE VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V (", r" AND s\.CMPGN_CTGR_CD = f\.CMPGN_CTGR_CD;\n")
    gv = grants(t36, "VIEW GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V") + grants(t36, "VIEW GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V")
    if gv.count("GRANT") != 6:
        sys.exit(f"🔴 뷰 GRANT {gv.count('GRANT')}건")
    sec = (
        "\n-- ============================================================================\n"
        "-- [O250] ML_MEMBER_PRED_AXIS_V · ML_FEE_FORECAST_AXIS_V — ML 회원예측·회비예측 × 7축\n"
        "--   (신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명 · 사용자 승인 2026-10-21)\n"
        "--   원 정의 = 36_O250_ML예측_7축확장.sql(문면 무변경 이관 · O250-E) · SV = 05_29 · 05_30\n"
        "--   본부지부 = DIM_ORG.ACMSLT_DIV_GROUP_NM 8종 → 본부/지부/기타 3분류 · 법인 = SPAN.ACQ_CPR_DIV_NM\n"
        "-- ============================================================================\n"
        + v1 + "\n" + v2 + gv
    )
    F21.write_text(t21.rstrip("\n") + "\n" + sec, encoding="utf-8")
    made.append((F21, v1 + v2))

# 토큰 대조(R2-8-1) — 이관 블록의 식별자·숫자 토큰이 목적지에 전부 있는가
bad = 0
for out, body in made:
    dst = out.read_text(encoding="utf-8")
    toks = set(re.findall(r"[A-Z][A-Z0-9_]{3,}|\d{3,}", body))
    miss = [x for x in toks if x not in dst]
    bad += len(miss)
    print(("🟢" if not miss else "🔴"), out.name, "토큰", len(toks), "부재", len(miss), miss[:5])
sys.exit(1 if bad else 0)

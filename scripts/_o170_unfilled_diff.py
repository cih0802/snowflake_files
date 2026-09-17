#!/usr/bin/env python3
# O170 ④-2 — O167 열거(95건) + O168 정정(+IS_HOLIDAY · -UNPAID_STOP 2종) ↔ 라이브 94건 집합 대조
# 🔴 판정식 = 총계가 아니라 집합 차이(해소 / 신규 / 누락)  (근거 = _o167_evidence.md:86)
import json

CEN = json.load(open("/tmp/census.json", encoding="utf-8"))

# --- O167 근거철 :92~:105 열거 (원문 그대로 전사) ---
O167 = {
    "FACT_MEMBER_MONTHLY": """CAMPAIGN_SK PAYMENT_SK UNPAID_CNT ACTIVE_CUM_CNT ACTIVE_CUM_MEMBERS
        INCREASE_CNT INCREASE_MEMBERS DECREASE_CNT CHURN_CNT CAMPAIGN_UNPAID_CNT STATUS_UNPAID_CNT
        INBOUND_CALL_CNT TS_CALL_CNT DEV_TYPE NEW_FLAG INCREASE_FLAG REDONATE_FLAG JOIN_DATE STOP_DATE
        AMOUNT_BAND1 AMOUNT_BAND2 PERIOD_BAND1 PERIOD_BAND2 SPONSOR_MONTHS SPONSOR_YEARS PAID_MONTHS
        NEW_EXISTING_FLAG""",
    "FACT_MESSAGE_DISPATCH": """CAMPAIGN_SK LETTER_PART_MEMBERS LETTER_PART_CNT GIFT_PART_MEMBERS
        GIFT_PART_AMT D5_LETTER_PART_MEMBERS D5_LETTER_PART_CNT D5_GIFT_PART_MEMBERS D5_GIFT_PART_CNT
        D5_INCREASE_PART_MEMBERS D5_INCREASE_PART_CNT D5_STOP_MEMBERS D5_STOP_CNT SERVICE_MEMBERS
        SERVICE_CNT SEND_STATUS2 MAIL_RECEIVE_FLAG MEMBER_STOP_FLAG""",
    "FACT_EVENT_ATTENDANCE": """CAMPAIGN_SK SPONSORSHIP_SK CONFIRM_CNT PARTICIPATION_TIMES WAIT_TIMES
        ABSENT_TIMES CUM_APPLY_TIMES SELF_PART_FLAG""",
    "FACT_TARGET_PROJECT": """MONTH_KEY ORG_SK SPONSORSHIP_SK CAMPAIGN_SK ANNUAL_GOAL_CNT SUPP_GOAL_CNT
        ANNUAL_CUM_GOAL_CNT SUPP_CUM_GOAL_CNT""",
    "FACT_BUDGET": "ORG_SK CAMPAIGN_SK SPONSORSHIP_SK EXEC_BUDGET_EST FUNDRAISING_COST AD_COST",
    "FACT_BUDGET_YEARLY": "ORG_SK CAMPAIGN_SK SPONSORSHIP_SK CHN_BUDGET_YEAR ADJ_BUDGET_YEAR",
    "DIM_ORG": "CORP DIVISION TEAM",
    "FACT_BIGQUERY_BEHAVIOR": "CAMPAIGN_SK AVG_SESSION_DURATION BOUNCE_RATE",
    "FACT_MEMBER_DEV_ACHIEVEMENT": "ORG_DIVISION ORG_TEAM ORG_CORP",
    "FACT_MEMBER_EVENT": "UNPAID_STOP_CNT UNPAID_STOP_MEMBERS NEW_EXISTING_FLAG",
    "DIM_AD_CREATIVE": "PLATFORM_TYPE TARGET_GROUP",
    "DIM_MEMBER_IDENTITY": "MEMNUM CHILD_CODE",
    "FACT_AD_PERFORMANCE": "CAMPAIGN_SK AD_CREATIVE_SK",
    "DIM_CAMPAIGN": "ORG_SK",
    "DIM_EVENT": "APPLY_CHANNEL",
    "DIM_PAYMENT": "FEE_TYPE",
    "FACT_AD_BROADCAST": "CONV_CALL_CNT",
    "FACT_AD_DIGITAL": "MEDIA_POTENTIAL_CUST_CNT",
}
prev = set()
for t, s in O167.items():
    for c in s.split():
        prev.add((t, c))
assert len(prev) == 95, "O167 열거 전사 오류: %d" % len(prev)

# O168 정정 반영 → 「직전 실제값 96」
prev_corrected = set(prev)
prev_corrected.add(("DIM_DATE", "IS_HOLIDAY"))  # O168 열거 누락 1건

# --- 라이브 현재 미주입 ---
cur = set()
for key in CEN:
    if not key.startswith("GOLD."):
        continue
    t = key[5:]
    ent = CEN[key]
    for c, m in ent["cols"].items():
        if c.startswith("DW_"):
            continue
        if (m["nonzero"] or 0) == 0:
            cur.add((t, c))

resolved = sorted(prev_corrected - cur)
newly = sorted(cur - prev_corrected)

print("직전(O167 열거 95 + O168 정정 1) = %d" % len(prev_corrected))
print("라이브 현재                      = %d" % len(cur))
print("")
print("해소(직전에 있고 지금 없다) = %d" % len(resolved))
for t, c in resolved:
    print("  🟢 %s.%s" % (t, c))
print("")
print("신규(지금 있고 직전에 없다) = %d" % len(newly))
for t, c in newly:
    print("  🔴 %s.%s" % (t, c))

#!/usr/bin/env python3
# O170 ① — 미배정 50컬럼의 **차단 근거를 컬럼 단위로** 판정한다.
# 🔴 판정만 한다(쓰기 없음). 🔴 묶음 이름으로 세지 않는다(O168 이 18종 중 16종을 그렇게 틀렸다).
#
# 판정 축 3개(각 컬럼마다 독립 실측) =
#   ㉠ 모델이 그 컬럼을 **어떻게 채우는가** — dbt 모델 SQL 에서 그 컬럼의 SELECT 항을 찾아
#      리터럴(`0`·`NULL`·`CAST(NULL …)`)인지 실산출인지 가른다.
#      🟢 리터럴이면 **「산출 로직 미구현」(버킷 B)** 이고 원천 유무와 무관하다.
#   ㉡ **원천에 그 이름의 컬럼이 있는가** — BRONZE 전 스키마 INFORMATION_SCHEMA 스냅샷과 대조.
#      🔴 이름 일치는 「원천 존재」의 **필요조건일 뿐**이다(어의는 사람이 본다) ⇒ 신호로만 쓴다.
#   ㉢ **SK 컬럼인가** — `*_SK` 는 차원 연결키이므로 차단 근거가 「연결키 부재」 계열이다.
#
# 🔴 이 도구는 버킷을 **확정하지 않는다** — 후보와 근거를 내고 사람이 가른다(`R1-6-24` 축).
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

CEN = {}
# 🔴 `/tmp` 는 턴 사이에 비워진다 ⇒ census 는 **선택 의존**이다.
#   🟢 이 도구의 핵심 판정(모델 구현 분류)은 census 없이도 성립한다 —
#   non-NULL 열만 `—` 가 된다. 🔴 없다고 판정을 미루지 마라(그것이 착수 지연의 경로다).
if os.path.exists("/tmp/census.json"):
    CEN = json.load(open("/tmp/census.json", encoding="utf-8"))
MODEL_DIRS = [
    "10_dbt_pipeline/models/gold/fact",
    "10_dbt_pipeline/models/gold/dim",
]

# §E4-5 + §E7-3 미배정 50컬럼 (근거철 전사)
UNASSIGNED = {
    "FACT_MEMBER_MONTHLY": """PAYMENT_SK CHURN_CNT INBOUND_CALL_CNT TS_CALL_CNT SPONSOR_MONTHS
        SPONSOR_YEARS PAID_MONTHS DEV_TYPE NEW_FLAG INCREASE_FLAG REDONATE_FLAG NEW_EXISTING_FLAG
        JOIN_DATE STOP_DATE AMOUNT_BAND1 AMOUNT_BAND2 PERIOD_BAND1 PERIOD_BAND2""",
    "FACT_MESSAGE_DISPATCH": """LETTER_PART_MEMBERS LETTER_PART_CNT GIFT_PART_MEMBERS GIFT_PART_AMT
        SERVICE_MEMBERS SERVICE_CNT MAIL_RECEIVE_FLAG MEMBER_STOP_FLAG""",
    "FACT_EVENT_ATTENDANCE": """CONFIRM_CNT PARTICIPATION_TIMES WAIT_TIMES ABSENT_TIMES
        CUM_APPLY_TIMES SELF_PART_FLAG""",
    "FACT_BUDGET": "EXEC_BUDGET_EST ORG_SK",
    "FACT_BUDGET_YEARLY": "CHN_BUDGET_YEAR ADJ_BUDGET_YEAR ORG_SK",
    "DIM_AD_CREATIVE": "PLATFORM_TYPE TARGET_GROUP",
    "DIM_MEMBER_IDENTITY": "MEMNUM CHILD_CODE",
    "FACT_BIGQUERY_BEHAVIOR": "AVG_SESSION_DURATION BOUNCE_RATE",
    "FACT_AD_BROADCAST": "CONV_CALL_CNT",
    "FACT_AD_DIGITAL": "MEDIA_POTENTIAL_CUST_CNT CRM_DEV_CNT",
    "DIM_CAMPAIGN": "ORG_SK",
    "DIM_EVENT": "APPLY_CHANNEL",
    "DIM_PAYMENT": "FEE_TYPE",
    "FACT_MEMBER_EVENT": "NEW_EXISTING_FLAG",
}

LIT_RX = [
    (re.compile(r"CAST\s*\(\s*NULL\s+AS", re.I), "CAST(NULL AS …)"),
    (re.compile(r"^\s*NULL\s*$", re.I), "NULL 리터럴"),
    (re.compile(r"^\s*0\s*$"), "0 리터럴"),
    (re.compile(r"^\s*FALSE\s*$", re.I), "FALSE 리터럴"),
    (re.compile(r"^\s*''\s*$"), "빈문자 리터럴"),
]


def model_path(tbl):
    for d in MODEL_DIRS:
        p = os.path.join(d, tbl + ".sql")
        if os.path.exists(p):
            return p
    return None


def split_top_level(src):
    """SELECT 목록을 **최상위 콤마**로 쪼갠다(괄호·따옴표 안의 콤마는 무시).

    🔴 [자기시정 3회] 이 함수 전의 세 판본이 전부 틀렸다:
      ㉠ `[^\\n,]*?`(콤마까지) — `CAST(NULL AS NUMBER(18,2))` 에서 **`2))` 만** 잡았다.
      ㉡ `[\\s\\S]{0,200}`(고정폭) — **앞 컬럼까지 삼켜** B 44 → 33 으로 회귀했다.
      ㉢ `^(.*?)`(줄 전체) — 이 코드베이스는 **한 줄에 여러 컬럼**을 쓰는 파일도 있어
         `0 as PARTICIPATION_TIMES, 0 as WAIT_TIMES, 0` 처럼 앞 항이 붙었다.
    🟢 **판정식 = 파서의 원자는 「구분자」도 「줄」도 「고정폭」도 아니라 「문법」이다.**
       SELECT 목록의 원자는 **괄호 균형을 지킨 최상위 콤마 구간**이다.
    🔴 이 워크스페이스가 파서로 네 번 틀린 지점이므로 여기에 근거를 남긴다.
    """
    out, buf, depth, q = [], [], 0, None
    for ch in src:
        if q:
            buf.append(ch)
            if ch == q:
                q = None
            continue
        if ch in "'\"":
            q = ch
            buf.append(ch)
            continue
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == ',' and depth <= 0:
            out.append(''.join(buf))
            buf = []
            continue
        buf.append(ch)
    out.append(''.join(buf))
    return out


AS_RX_TPL = r"\s+as\s+\"?%s\"?(?![0-9A-Za-z_])"


def select_expr(src, col):
    """`… as COL` 의 **좌변 식**을 돌려준다(최상위 콤마 구간 기준). 못 찾으면 None.

    🔴 앵커를 `$`(구간 끝)로 두면 **주석 제거 후 꼬리가 남은 구간**에서 놓친다(판정불가 급증).
    🟢 그래서 `as COL` **직후에 식별자 문자가 없음**만 요구하고 그 앞을 좌변으로 취한다.
    """
    rx = re.compile(AS_RX_TPL % re.escape(col), re.I)
    hit = None
    for part in split_top_level(src):
        # 🔴 주석(`-- …`)을 먼저 걷어낸다 — 주석 안의 `as` 가 오탐을 만든다.
        clean = re.sub(r"--[^\n]*", " ", part)
        clean = " ".join(clean.split())
        m = rx.search(clean)
        if m:
            hit = clean[:m.start()].strip()      # 마지막 정의를 쓴다(CTE 를 코어가 덮는다)
    return hit


def classify(expr):
    if expr is None:
        return "판정불가(모델에서 `as COL` 을 못 찾음)", "?"
    for rx, name in LIT_RX:
        if rx.search(expr):
            return "리터럴 주입 = %s" % name, "B"
    if re.match(r"^\s*(0|NULL|FALSE)\s*$", expr, re.I):
        return "리터럴 주입", "B"
    return "실산출식", "?"


def main():
    # 원천 컬럼 이름 집합(있으면 CSV, 없으면 건너뜀 · 신호로만 쓴다)
    src_cols = set()
    dump = "/tmp/bronze_cols.txt"
    if os.path.exists(dump):
        for l in io.open(dump, encoding="utf-8"):
            src_cols.add(l.strip().upper())

    rows = []
    for tbl, s in UNASSIGNED.items():
        cols = s.split()
        mp = model_path(tbl)
        src = io.open(mp, encoding="utf-8").read() if mp else ""
        for c in cols:
            expr = select_expr(src, c) if src else None
            verdict, bucket = classify(expr)
            ent = CEN.get("GOLD." + tbl, {}).get("cols", {}).get(c, {})
            nn = ent.get("nonnull")
            rows.append((tbl, c, ent.get("type", "?"), nn, bucket, verdict,
                         (expr or "")[:70], c.upper() in src_cols))

    n = len(rows)
    print("미배정 %d컬럼 판정 (모델 %d종)" % (n, len(UNASSIGNED)))
    print("")
    print("| 테이블 | 컬럼 | 타입 | non-NULL | 후보버킷 | 모델 구현 | SELECT 식(70자) | 원천 동명 |")
    print("|---|---|---|---:|---|---|---|---|")
    for t, c, ty, nn, b, v, e, insrc in sorted(rows):
        print("| `%s` | `%s` | %s | %s | **%s** | %s | `%s` | %s |"
              % (t, c, ty, "—" if nn is None else nn, b, v, e.replace("|", "/"),
                 "🟢" if insrc else "—"))
    print("")
    import collections
    cb = collections.Counter(r[4] for r in rows)
    print("후보버킷 분포 = %s" % dict(cb))
    print("🔴 `?` 는 사람이 가른다 — 실산출식이면 원천·규칙·연결키 중 어디서 막혔는지 본문을 읽어야 한다.")


main()

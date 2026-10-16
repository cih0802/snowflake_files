# O237-B — WIDE_MEMBER_SERVICE_COHORT 확장(D5 서신·선물금 플래그 · N개월 유지 · 수신 후 납입) + _wide_schema.yml 컬럼 COMMENT
# 방식 = 백업 → 앵커 1회 assert → 치환 → 삽입분 제거 시 원본 동일(바이트 보존) → yml 파싱 diff
# Co-authored with CoCo
import os
import shutil
import sys

import yaml

BAK = "/workspace/tmp/o237b/bak"
SQL = "/workspace/10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_SERVICE_COHORT.sql"
YML = "/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml"

# (앵커, 치환) — 각 앵커는 파일에 정확히 1회
SQL_REPL = [
    ("    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'CODE' as MATCH_BASIS, f.DATE_SK,\n"
     "           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME\n",
     "    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'CODE' as MATCH_BASIS, f.DATE_SK,\n"
     "           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME,\n"
     "           f.D5_LETTER_PART_MEMBERS, f.D5_GIFT_PART_MEMBERS   -- 🆕 [O237-B]\n"),
    ("    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'TITLE', f.DATE_SK,\n"
     "           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME\n",
     "    select f.MEMBER_DK, r.SERVICE_GROUP_CD, 'TITLE', f.DATE_SK,\n"
     "           f.D5_STOP_MEMBERS, f.D5_INCREASE_PART_MEMBERS, q.SEND_CPR_NM, q.CHRG_DEPT_NM, q.SVC_CATEGORY_NAME,\n"
     "           f.D5_LETTER_PART_MEMBERS, f.D5_GIFT_PART_MEMBERS   -- 🆕 [O237-B]\n"),
    ("        x.SVC_CATEGORY_NAME\n    from disp_raw x\n",
     "        x.SVC_CATEGORY_NAME,\n        x.D5_LETTER_PART_MEMBERS,\n        x.D5_GIFT_PART_MEMBERS\n    from disp_raw x\n"),
    ("        MAX(IFF(D5_INCREASE_PART_MEMBERS > 0, 1, 0)) = 1 as D5_INCREASE_FLAG,\n",
     "        MAX(IFF(D5_INCREASE_PART_MEMBERS > 0, 1, 0)) = 1 as D5_INCREASE_FLAG,\n"
     "        -- 🆕 [O237-B] 발송 후 D+1~D+5 서신·선물금 참여(FACT_MESSAGE_DISPATCH 와 같은 시간창 · 안내성 제목 제외 동일)\n"
     "        MAX(IFF(D5_LETTER_PART_MEMBERS > 0, 1, 0)) = 1 as D5_LETTER_FLAG,\n"
     "        MAX(IFF(D5_GIFT_PART_MEMBERS > 0, 1, 0)) = 1   as D5_GIFT_FLAG,\n"),
    ("        COALESCE(r.D5_INCREASE_FLAG, false)         as D5_INCREASE_FLAG,\n",
     "        COALESCE(r.D5_INCREASE_FLAG, false)         as D5_INCREASE_FLAG,\n"
     "        COALESCE(r.D5_LETTER_FLAG, false)           as D5_LETTER_FLAG,      -- 🆕 [O237-B]\n"
     "        COALESCE(r.D5_GIFT_FLAG, false)             as D5_GIFT_FLAG,        -- 🆕 [O237-B]\n"),
    ("    group by 1, 2, 3\n)\nselect\n",
     "    group by 1, 2, 3\n),\n"
     "-- 🆕 [O237-B] 첫 수신월 기준 N개월 유지 · 수신 후 납입(수신 행만 · 미수신 NULL)\n"
     "--   · 유지 = 첫 수신월 + N 개월 시점에 미중단 후원사업(FMSS span as-of · FMM 활동 판정과 같은 식)이 있는가\n"
     "--   · 관측 = 첫 수신월 + N 이 데이터 최신월(FMM 스파인 최대월) 이하일 때만 TRUE/FALSE · 넘으면 NULL(아직 관측 불가)\n"
     "--   · 🔴 수신 후 납입 = 첫 수신 **다음 달 ~ +3개월** 안에 회비 납입(PAID_FEE_BILLABLE > 0)이 있는가 — 창 길이 잠정(사용자 승인 2026-10-16 · 현업 확인 대상)\n"
     "max_mk as (\n"
     "    select MAX(MONTH_KEY) as MK from {{ ref('FACT_MEMBER_MONTHLY') }} where MONTH_KEY > 0\n"
     "),\n"
     "rcv_mk as (\n"
     "    select MEMBER_DK, SERVICE_GROUP_CD, RECEIVE_YEAR,\n"
     "           TRY_TO_NUMBER(TO_CHAR(FIRST_RECEIVE_DATE, 'YYYYMM')) as FRM\n"
     "    from base\n"
     "    where RECEIVED_FLAG\n"
     "),\n"
     "ret as (\n"
     "    select r.MEMBER_DK, r.SERVICE_GROUP_CD, r.RECEIVE_YEAR,\n"
     "           case when {{ month_key_offset('r.FRM', 3) }} <= mx.MK then\n"
     "                COUNT_IF(sn.START_MONTH_KEY <= {{ month_key_offset('r.FRM', 3) }}\n"
     "                         and (sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > {{ month_key_offset('r.FRM', 3) }})) > 0 end  as RETAINED_3M_FLAG,\n"
     "           case when {{ month_key_offset('r.FRM', 6) }} <= mx.MK then\n"
     "                COUNT_IF(sn.START_MONTH_KEY <= {{ month_key_offset('r.FRM', 6) }}\n"
     "                         and (sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > {{ month_key_offset('r.FRM', 6) }})) > 0 end  as RETAINED_6M_FLAG,\n"
     "           case when {{ month_key_offset('r.FRM', 12) }} <= mx.MK then\n"
     "                COUNT_IF(sn.START_MONTH_KEY <= {{ month_key_offset('r.FRM', 12) }}\n"
     "                         and (sn.DSCNTC_MONTH_KEY is null or sn.DSCNTC_MONTH_KEY > {{ month_key_offset('r.FRM', 12) }})) > 0 end as RETAINED_12M_FLAG\n"
     "    from rcv_mk r\n"
     "    cross join max_mk mx\n"
     "    left join {{ ref('FACT_MEMBER_SPONSORSHIP_SPAN') }} sn on sn.MEMBER_DK = r.MEMBER_DK\n"
     "    group by r.MEMBER_DK, r.SERVICE_GROUP_CD, r.RECEIVE_YEAR, r.FRM, mx.MK\n"
     "),\n"
     "paid_after as (\n"
     "    select r.MEMBER_DK, r.SERVICE_GROUP_CD, r.RECEIVE_YEAR,\n"
     "           case when {{ month_key_offset('r.FRM', 3) }} <= mx.MK then\n"
     "                COALESCE(SUM(fe.PAID_FEE_BILLABLE), 0) > 0 end as PAID_AFTER_3M_FLAG\n"
     "    from rcv_mk r\n"
     "    cross join max_mk mx\n"
     "    left join {{ ref('FACT_MEMBER_FEE') }} fe\n"
     "      on fe.MEMBER_DK = r.MEMBER_DK\n"
     "     and fe.MONTH_KEY between {{ month_key_offset('r.FRM', 1) }} and {{ month_key_offset('r.FRM', 3) }}\n"
     "    group by r.MEMBER_DK, r.SERVICE_GROUP_CD, r.RECEIVE_YEAR, r.FRM, mx.MK\n"
     ")\nselect\n"),
    ("    v.ONLINE_EVENT_PART_ROWS_AFTER                  as ONLINE_EVENT_PART_ROWS_AFTER\nfrom base b\n",
     "    v.ONLINE_EVENT_PART_ROWS_AFTER                  as ONLINE_EVENT_PART_ROWS_AFTER,\n"
     "    -- ── 🆕 [O237-B] 참여 플래그 · 유지 · 수신 후 납입(맨 끝 append) ──────────────────\n"
     "    b.D5_LETTER_FLAG,\n"
     "    b.D5_GIFT_FLAG,\n"
     "    rt.RETAINED_3M_FLAG,\n"
     "    rt.RETAINED_6M_FLAG,\n"
     "    rt.RETAINED_12M_FLAG,\n"
     "    pa.PAID_AFTER_3M_FLAG\n"
     "from base b\n"),
    (" and v.RECEIVE_YEAR is not distinct from b.RECEIVE_YEAR\n",
     " and v.RECEIVE_YEAR is not distinct from b.RECEIVE_YEAR\n"
     "left join ret rt\n"
     "  on rt.MEMBER_DK = b.MEMBER_DK\n"
     " and rt.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD\n"
     " and rt.RECEIVE_YEAR = b.RECEIVE_YEAR\n"
     "left join paid_after pa\n"
     "  on pa.MEMBER_DK = b.MEMBER_DK\n"
     " and pa.SERVICE_GROUP_CD = b.SERVICE_GROUP_CD\n"
     " and pa.RECEIVE_YEAR = b.RECEIVE_YEAR\n"),
]

YML_ANCHOR = ('      - name: ONLINE_EVENT_PART_ROWS_AFTER\n'
              '        description: "첫 수신일 이후 온라인 구분 일반행사 참여 기록 행 수. 미수신 행은 NULL(기준일 없음)."\n')
YML_ADD = (
    '      - name: D5_LETTER_FLAG\n'
    '        description: "🆕 O237-B 그 해 그 그룹 발송 후 D+1~D+5 안에 서신 참여가 있었는가(FACT_MESSAGE_DISPATCH D5_LETTER_PART_MEMBERS · 안내성 제목 제외). 미수신 행은 FALSE."\n'
    '      - name: D5_GIFT_FLAG\n'
    '        description: "🆕 O237-B 그 해 그 그룹 발송 후 D+1~D+5 안에 선물금 참여가 있었는가(선물금 원천에 접수일이 없어 선물금 발송일로 매칭). 미수신 행은 FALSE."\n'
    '      - name: RETAINED_3M_FLAG\n'
    '        description: "🆕 O237-B 첫 수신월 + 3개월 시점에 미중단 후원사업이 있는가(FMSS as-of). 그 시점이 데이터 최신월을 넘으면 NULL(관측 불가) · 미수신 행 NULL."\n'
    '      - name: RETAINED_6M_FLAG\n'
    '        description: "🆕 O237-B 첫 수신월 + 6개월 시점 유지 여부(규칙은 RETAINED_3M_FLAG 와 같다)."\n'
    '      - name: RETAINED_12M_FLAG\n'
    '        description: "🆕 O237-B 첫 수신월 + 12개월 시점 유지 여부(규칙은 RETAINED_3M_FLAG 와 같다)."\n'
    '      - name: PAID_AFTER_3M_FLAG\n'
    '        description: "🆕 O237-B 첫 수신 다음 달 ~ +3개월 안에 회비 납입(PAID_FEE_BILLABLE > 0)이 있는가. 창 길이 잠정(현업 확인 대상) · +3개월이 최신월을 넘으면 NULL · 미수신 행 NULL."\n'
)
NEW_COLS = ["D5_LETTER_FLAG", "D5_GIFT_FLAG", "RETAINED_3M_FLAG", "RETAINED_6M_FLAG", "RETAINED_12M_FLAG", "PAID_AFTER_3M_FLAG"]


def main():
    os.makedirs(BAK, exist_ok=True)
    for p in (SQL, YML):
        b = os.path.join(BAK, os.path.basename(p) + ".O237B-before")
        if not os.path.exists(b):
            shutil.copyfile(p, b)
        if open(b, encoding="utf-8").read() != open(p, encoding="utf-8").read():
            sys.exit("백업 ≠ 현재 — 중단: " + p)
    s = open(SQL, encoding="utf-8").read()
    if "O237-B" in s:
        sys.exit("모델 이미 확장")
    n = s
    for a, r in SQL_REPL:
        assert n.count(a) == 1, (a[:70], n.count(a))
        n = n.replace(a, r)
    back = n
    for a, r in reversed(SQL_REPL):
        back = back.replace(r, a)
    assert back == s, "되돌림 불일치"
    open(SQL, "w", encoding="utf-8").write(n)
    assert open(SQL, encoding="utf-8").read() == n
    print("model OK", len(s.splitlines()), "→", len(n.splitlines()))

    y = open(YML, encoding="utf-8").read()
    assert y.count(YML_ANCHOR) == 1
    ny = y.replace(YML_ANCHOR, YML_ANCHOR + YML_ADD)
    o, nn = yaml.safe_load(y), yaml.safe_load(ny)
    om = {m["name"]: m for m in o["models"]}
    nm = {m["name"]: m for m in nn["models"]}
    assert set(om) == set(nm)
    for k in om:
        if k != "WIDE_MEMBER_SERVICE_COHORT":
            assert om[k] == nm[k], k
    oc = [c["name"] for c in om["WIDE_MEMBER_SERVICE_COHORT"]["columns"]]
    nc = [c["name"] for c in nm["WIDE_MEMBER_SERVICE_COHORT"]["columns"]]
    assert nc == oc + NEW_COLS, nc[-8:]
    open(YML, "w", encoding="utf-8").write(ny)
    assert open(YML, encoding="utf-8").read() == ny
    print("yml OK cols", len(oc), "→", len(nc))


if __name__ == "__main__":
    main()

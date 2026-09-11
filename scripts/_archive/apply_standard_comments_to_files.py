#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEC-52 전사 코멘트 4블록 표준화 DDL 파일 일괄 적용 스크립트.

적용 대상:
  1. 03_top-down_gold/06_DDL.sql (Gold 테이블 37종)
  2. 04_silver_design/08_SILVER_테이블DDL_20260714.sql (Silver 테이블 43종)
  3. 05_SV-Agent_ai/05_1~10_SV_DDL_*.sql & 22_ML_SV_DDL.sql (Semantic View 17종)
"""
import sys
import re

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as cdg
from standardize_comments import (
    GOLD_TABLE_COMMENTS,
    SILVER_TABLE_COMMENTS,
    SV_COMMENTS,
)


def update_ddl_table_comments(path, rx, comments_dict):
    src = open(path, encoding='utf-8').read()
    hits = list(rx.finditer(src))
    print(f"[{path}] Found {len(hits)} table statements.")

    new_src_parts = []
    last_pos = 0

    for i, m in enumerate(hits):
        tbl_name = m.group(1)
        start_pos = m.start()
        end_pos = hits[i + 1].start() if i + 1 < len(hits) else len(src)

        block = src[start_pos:end_pos]
        if tbl_name in comments_dict:
            new_cmt = comments_dict[tbl_name].replace("'", "''")
            m_cmt = cdg.RE_TBL_COMMENT.search(block)
            if m_cmt:
                replacement = f") COMMENT = '{new_cmt}';"
                block = block[:m_cmt.start()] + replacement + block[m_cmt.end():]
            else:
                print(f"  Warning: No existing table comment found for {tbl_name}")

        new_src_parts.append(src[last_pos:start_pos])
        new_src_parts.append(block)
        last_pos = end_pos

    new_src_parts.append(src[last_pos:])
    new_src = "".join(new_src_parts)

    with open(path, "w", encoding="utf-8") as fp:
        fp.write(new_src)
    print(f"[{path}] Successfully updated table comments!")


def update_sv_comments():
    sv_files = [
        ("05_SV-Agent_ai/05_1_SV_DDL_MEMBER_MONTHLY.sql", "SV_MEMBER_MONTHLY"),
        ("05_SV-Agent_ai/05_2_SV_DDL_MEMBER_EVENT.sql", "SV_MEMBER_EVENT"),
        ("05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql", "SV_MEMBER_COHORT"),
        ("05_SV-Agent_ai/05_4_SV_DDL_SERVICE.sql", "SV_SERVICE"),
        ("05_SV-Agent_ai/05_5_SV_DDL_EVENT_PARTICIPATION.sql", "SV_EVENT_PARTICIPATION"),
        ("05_SV-Agent_ai/05_6_SV_DDL_BUDGET.sql", "SV_BUDGET"),
        ("05_SV-Agent_ai/05_7_SV_DDL_AD.sql", "SV_AD"),
        ("05_SV-Agent_ai/05_8_SV_DDL_DEV_ACHIEVEMENT.sql", "SV_DEV_ACHIEVEMENT"),
        ("05_SV-Agent_ai/05_9_SV_DDL_MEMBER_FEE.sql", "SV_MEMBER_FEE"),
        ("05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql", "SV_MEMBER_SPONSOR_BIZ"),
    ]

    for fpath, sv_name in sv_files:
        if sv_name not in SV_COMMENTS:
            continue
        src = open(fpath, encoding="utf-8").read()
        new_cmt = SV_COMMENTS[sv_name].replace("'", "''")
        # Match the first table COMMENT inside TABLES ( ... )
        rx_sv_cmt = re.compile(
            r"(TABLES\s*\(\s*[a-zA-Z0-9_]+\s+AS\s+[^\n]+\s+"
            r"(?:PRIMARY\s+KEY\s*\([^)]*\)\s+)?"
            r"(?:WITH\s+SYNONYMS\s*\([^)]*\)\s+)?"
            r"COMMENT\s*=\s*')((?:[^']|'')*)(')",
            re.S | re.I
        )
        m = rx_sv_cmt.search(src)
        if m:
            src = src[:m.start(2)] + new_cmt + src[m.end(2):]
            with open(fpath, "w", encoding="utf-8") as fp:
                fp.write(src)
            print(f"[{fpath}] Updated {sv_name} comment.")
        else:
            print(f"[{fpath}] Warning: could not match TABLES COMMENT for {sv_name}")

    # Update 22_ML_SV_DDL.sql which contains 7 SVs
    ml_fpath = "05_SV-Agent_ai/22_ML_SV_DDL.sql"
    ml_src = open(ml_fpath, encoding="utf-8").read()
    ml_svs = [
        "SV_ML_MEMBER_RISK",
        "SV_ML_SPONSOR_RISK",
        "SV_ML_DVLP_FORECAST",
        "SV_ML_FEE_FORECAST",
        "SV_ML_LTV_FORECAST",
        "SV_ML_LTV_SCORE",
        "SV_ML_FEATURE_IMPORTANCE",
    ]
    for sv_name in ml_svs:
        if sv_name not in SV_COMMENTS:
            continue
        new_cmt = SV_COMMENTS[sv_name].replace("'", "''")
        pattern = re.compile(
            rf"(CREATE\s+(?:OR\s+ALTER\s+|OR\s+REPLACE\s+)?SEMANTIC\s+VIEW\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:GN_DW\.SERVING\.)?{sv_name}\b.*?"
            r"TABLES\s*\(\s*[a-zA-Z0-9_]+\s+AS\s+[^\n]+\s+"
            r"(?:PRIMARY\s+KEY\s*\([^)]*\)\s+)?"
            r"(?:WITH\s+SYNONYMS\s*\([^)]*\)\s+)?"
            r"COMMENT\s*=\s*')((?:[^']|'')*)(')",
            re.S | re.I
        )
        m = pattern.search(ml_src)
        if m:
            ml_src = ml_src[:m.start(2)] + new_cmt + ml_src[m.end(2):]
            print(f"[{ml_fpath}] Updated {sv_name} comment.")
        else:
            print(f"[{ml_fpath}] Warning: could not match {sv_name} in 22_ML_SV_DDL.sql")

    with open(ml_fpath, "w", encoding="utf-8") as fp:
        fp.write(ml_src)
    print(f"[{ml_fpath}] Successfully updated all ML SV comments!")


def main():
    print("=== Step 1. Updating 06_DDL.sql ===")
    update_ddl_table_comments(cdg.DDL, cdg.RE_TABLE, GOLD_TABLE_COMMENTS)

    print("\n=== Step 2. Updating 08_SILVER_테이블DDL_20260714.sql ===")
    update_ddl_table_comments(cdg.SILVER_DDL, cdg.RE_SILVER, SILVER_TABLE_COMMENTS)

    print("\n=== Step 3. Updating Semantic View DDLs ===")
    update_sv_comments()

    print("\n=== All DDL files updated! ===")


if __name__ == '__main__':
    main()

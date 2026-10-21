#!/usr/bin/env python3
"""O250-C · Agent COMMENT 를 수치 없는 카테고리 설명으로 교체(09_1 CREATE·[5] 6곳 + 09_2 [3] 3곳) 후 라이브 SET."""
import os
import re
import sys
from pathlib import Path

import snowflake.connector

NEW = {
    "AGENT_MEMBER": "굿네이버스 회원 분석 Agent. 조회 데이터 = 회원(월실적·상태전이·후원약정·획득코호트·회원 속성) · "
                    "회비(청구·납입·미납·청구 처리) · 캠페인(캠페인·마케팅캠페인별 회원) · 서비스 발송·행사 참여·결연활동 · "
                    "개발 목표·실적 · 부서 자체 수식 집계(회원실·기획실) · 머신러닝 예측(중단·증액·충성·회비·일시회원 정기전환).",
    "AGENT_EXECUTIVE": "굿네이버스 경영·전사 분석 Agent. 조회 데이터 = 사업목표 · 예산(편성·집행·과목) · 광고(매체·실적) · "
                       "회원 월실적 · 서비스 발송 · 지출결의 · 회비 청구 처리 · 머신러닝 예측(개발금액·LTV·기여요인·중단·증액).",
    "AGENT_MARKETING": "굿네이버스 마케팅 분석 Agent. 조회 데이터 = 마케팅·광고(매체·광고비·개발효율) · "
                       "캠페인(캠페인·마케팅캠페인별 개발·회비·활동회원) · 예산(편성·집행) · 개발 목표·실적 · 회원(전환·획득코호트) · "
                       "홈페이지 방문(GA4)·검색어 · 지출결의 · 머신러닝 예측(개발금액·증액·중단·회비·LTV·일시회원 정기전환).",
}
F1 = Path("/workspace/05_SV-Agent_ai/09_1_AGENT_생성.sql")
F2 = Path("/workspace/05_SV-Agent_ai/09_2_AGENT_버전업.sql")

t = F1.read_text(encoding="utf-8")
n = 0
for a, c in NEW.items():
    pat = re.compile(r"((?:CREATE AGENT IF NOT EXISTS|ALTER AGENT) GN_DW\.SERVING\." + a + r"(?: SET)?\s*\n\s*COMMENT = ')[^'\n]*(')")
    t, k = pat.subn(lambda m: m.group(1) + c + m.group(2), t)
    if k != 2:
        sys.exit(f"🔴 09_1 {a}: {k}곳 일치(2곳이어야 한다)")
    n += k
F1.write_text(t, encoding="utf-8")
print("09_1 치환", n)

t = F2.read_text(encoding="utf-8")
for a, c in NEW.items():
    pat = re.compile(r"(ALTER AGENT GN_DW\.SERVING\." + a + r"\s*\n\s*ADD VERSION FROM [^\n]+\n\s*COMMENT = ')[^'\n]*(')")
    t, k = pat.subn(lambda m: m.group(1) + c + m.group(2), t)
    if k != 1:
        sys.exit(f"🔴 09_2 {a}: {k}곳 일치")
F2.write_text(t, encoding="utf-8")
print("09_2 치환 3")

if "--apply" in sys.argv:
    tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                      authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH")
    cur = con.cursor()
    for a, c in NEW.items():
        cur.execute(f"ALTER AGENT GN_DW.SERVING.{a} SET COMMENT = %s", (c,))
        print("SET", a)
    cur.execute("SHOW AGENTS IN SCHEMA GN_DW.SERVING")
    for r in cur.fetchall():
        print(r[1], "|", r[5])

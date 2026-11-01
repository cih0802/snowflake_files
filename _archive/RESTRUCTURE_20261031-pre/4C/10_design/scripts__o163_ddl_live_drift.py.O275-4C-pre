#!/usr/bin/env python3
"""o163_ddl_live_drift — DDL 파일(구조 정본) ↔ 라이브 테이블 컬럼 집합 대조.

용도: O162 이후 「DDL 파일은 최신인데 라이브가 낡은 세대」 가설의 전수 실증.

왜 필요한가
  · dbt build 실패 15건의 발화 문장은 `ALTER TABLE … ADD COLUMN` 이고 그 원인은
    「모델이 산출하는 컬럼이 라이브 테이블에 없다」 였다.
  · 그런데 그 컬럼들은 DDL 파일(06_DDL.sql · 08_SILVER_테이블DDL)에는 선언돼 있다.
    ⇒ 어긋난 축은 「모델 ↔ DDL 파일」이 아니라 **「DDL 파일 ↔ 라이브」**다.
  · 이 스크립트는 그 판정을 눈이 아니라 기계로 낸다(`R2-3`·`R2-4` 실측 축).

출력 = 3분류
  MISSING_TABLE : DDL 이 선언했으나 라이브에 테이블 자체가 없다
  DDL_ONLY      : DDL 에만 있는 컬럼 (라이브가 낡음 ⇒ dbt ADD COLUMN 실패의 직접 원인)
  LIVE_ONLY     : 라이브에만 있는 컬럼 (DDL 이 제거했거나 개명 전 이름이 남아 있다)

사용법
  python3 scripts/o163_ddl_live_drift.py --live /tmp/live_cols.tsv
    · --live 는 아래 SQL 결과를 TSV(헤더 없음 · SCHEMA<TAB>TABLE<TAB>COLUMN)로 받은 파일.
      SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
      FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA IN ('SILVER','GOLD') ORDER BY 1,2,ORDINAL_POSITION;

🔴 라이브 조회는 이 스크립트가 하지 않는다 — 커넥션 의존을 두지 않기 위해
   호출자가 SQL 로 받아 파일로 넘긴다(`R2-3` 원본 실측을 호출자 책임으로 고정).
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DDL_FILES = [
    ROOT / "03_top-down_gold" / "06_DDL.sql",
    ROOT / "04_silver_design" / "08_SILVER_테이블DDL_20260714.sql",
]

# CREATE OR REPLACE TABLE GN_DW.SILVER.FOO ( ... );
CREATE_RE = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"(?:GN_DW\.)?(\w+)\.(\w+)\s*\(",
    re.IGNORECASE,
)

# 컬럼 정의 줄의 선두 식별자. 제약·주석·닫는 괄호는 제외한다.
COL_RE = re.compile(r"^\s{2,}([A-Z_][A-Z0-9_]*)\s+[A-Z]", re.IGNORECASE)

# 컬럼이 아닌 선두 토큰(테이블 제약 · SQL 키워드).
# 🔴 [O163 시정] 초판은 아래 3종이 빠져 `FACT_MEMBER_SPONSORSHIP_SPAN` 에서
#   `BEGIN`·`CASE`·`AND` 를 컬럼으로 오탐했다(DDL 본문의 CASE 식 들여쓰기가 컬럼 정의와 같다).
#   ⇒ 오탐은 「DDL 에만 있는 컬럼」으로 보고되어 **없는 드리프트를 만든다**.
NOT_COL = {
    "PRIMARY", "FOREIGN", "UNIQUE", "CONSTRAINT", "CHECK",
    "COMMENT", "CLUSTER", "WITH", "AS", "SELECT", "REFERENCES",
    "BEGIN", "END", "CASE", "WHEN", "THEN", "ELSE",
    "AND", "OR", "NOT", "IF", "IFF", "COALESCE", "CAST",
    "FROM", "WHERE", "GROUP", "ORDER", "HAVING", "UNION",
    "INSERT", "UPDATE", "DELETE", "SET", "VALUES", "ON",
    "LEFT", "RIGHT", "INNER", "OUTER", "JOIN", "USING",
    "CREATE", "ALTER", "DROP", "TABLE", "VIEW", "INDEX",
}


def parse_ddl():
    """DDL 파일에서 {(schema, table): [col, ...]} 를 뽑는다.

    🔴🔴 [O163 시정 2] **주석 처리된 CREATE 문을 선언으로 세지 않는다.**
      초판은 `CREATE_RE.finditer(text)` 로 전체 텍스트를 훑어 `-- CREATE OR REPLACE TABLE …`
      까지 실제 선언으로 잡았다. 그 결과 `SILVER.BIGQUERY_REFINED_DATA`(08 DDL 1283행에서
      **커밋아웃**된 구 dbt 모델 DDL)가 「DDL 선언」에 포함되고 `LIVE_ONLY 118건` 이 나왔다.
      ⇒ 🔴 그 목록을 라이브 복원(`CREATE OR REPLACE`) 대상으로 삼으면 **외부 Python 적재
        11,600,680행이 영구 소실**된다(dbt 가 재적재하지 않는 테이블이다).
      ⇒ 판정식 = CREATE 매칭 위치가 속한 **줄의 선두가 `--` 면 선언이 아니다**.
    """
    tables = {}
    for path in DDL_FILES:
        if not path.exists():
            print(f"🔴 DDL 파일 부재: {path}", file=sys.stderr)
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        # CREATE 문 시작 위치를 모두 찾고, 다음 CREATE 까지를 그 테이블의 본문으로 본다.
        marks = []
        for m in CREATE_RE.finditer(text):
            # 그 매칭이 속한 줄을 잘라 주석 여부를 판정한다.
            line_start = text.rfind("\n", 0, m.start()) + 1
            line = text[line_start:m.start()]
            if line.lstrip().startswith("--"):
                continue  # 커밋아웃된 CREATE — 선언이 아니다
            marks.append((m.start(), m.group(1).upper(),
                          m.group(2).upper(), m.end()))
        for i, (_start, schema, table, body_at) in enumerate(marks):
            end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
            body = text[body_at:end]
            cols = []
            for line in body.splitlines():
                # 주석 줄은 건너뛴다(-- 로 시작하는 줄).
                if line.lstrip().startswith("--"):
                    continue
                m2 = COL_RE.match(line)
                if not m2:
                    continue
                name = m2.group(1).upper()
                if name in NOT_COL:
                    continue
                if name not in cols:
                    cols.append(name)
            tables[(schema, table)] = cols
    return tables


def parse_live(path):
    live = {}
    for raw in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        parts = [p.strip().strip('"') for p in raw.split("\t")]
        if len(parts) < 3:
            parts = [p.strip().strip('"') for p in raw.split(",")]
        if len(parts) < 3:
            continue
        schema, table, col = parts[0].upper(), parts[1].upper(), parts[2].upper()
        live.setdefault((schema, table), []).append(col)
    return live


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", required=True,
                    help="INFORMATION_SCHEMA.COLUMNS 결과 TSV/CSV 경로")
    args = ap.parse_args()

    ddl = parse_ddl()
    live = parse_live(args.live)

    print(f"DDL 선언 테이블 = {len(ddl)} · 라이브 테이블 = {len(live)}")
    print()

    missing = []
    drift = []
    for key in sorted(ddl):
        schema, table = key
        if key not in live:
            missing.append(key)
            continue
        d = ddl[key]
        lv = live[key]
        ddl_only = [c for c in d if c not in lv]
        live_only = [c for c in lv if c not in d]
        if ddl_only or live_only:
            drift.append((key, ddl_only, live_only))

    print(f"## MISSING_TABLE — DDL 선언 · 라이브 부재 : {len(missing)}건")
    for schema, table in missing:
        print(f"  {schema}.{table}")
    print()

    print(f"## COLUMN_DRIFT : {len(drift)}건")
    for (schema, table), ddl_only, live_only in drift:
        print(f"  {schema}.{table}")
        if ddl_only:
            print(f"     DDL_ONLY ({len(ddl_only)}) : {', '.join(ddl_only)}")
        if live_only:
            print(f"     LIVE_ONLY({len(live_only)}) : {', '.join(live_only)}")
    print()

    live_extra = [k for k in sorted(live) if k not in ddl]
    print(f"## LIVE_ONLY_TABLE — 라이브 존재 · DDL 미선언 : {len(live_extra)}건")
    for schema, table in live_extra:
        print(f"  {schema}.{table}")


if __name__ == "__main__":
    main()

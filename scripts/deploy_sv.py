#!/usr/bin/env python3
"""SV DDL 파일에서 DDL·GRANT 만 골라 실행한다(스모크 SELECT/SHOW 는 제외).

🔴 왜 필요한가: SV DDL 파일은 `USE`·`CREATE`·`GRANT`·스모크 쿼리가 한 파일에 섞여 있고
   COMMENT 문자열 안에 세미콜론이 들어 있어 단순 `split(';')` 로는 깨진다.
   또 문장 앞에 `--`·`/* */` 주석 블록이 붙어 있어 선두 키워드 매칭 전에 주석을 벗겨야 한다
   (실측: 이 처리를 빼면 CREATE 가 건너뛰어지고 GRANT 만 실행돼 "does not exist" 로 실패했다).

사용: python3 /tmp/deploy_sv.py <파일...>
"""
import re
import sys

sys.path.insert(0, '/tmp/ws/scripts')
from sfconn import conn


def split_sql(text):
    out, buf, in_s = [], [], False
    i = 0
    while i < len(text):
        c = text[i]
        if c == "'":
            if in_s and i + 1 < len(text) and text[i + 1] == "'":
                buf.append("''"); i += 2; continue
            in_s = not in_s
        if c == ';' and not in_s:
            out.append(''.join(buf)); buf = []; i += 1; continue
        buf.append(c); i += 1
    if ''.join(buf).strip():
        out.append(''.join(buf))
    return [s for s in out if s.strip()]


def strip_lead(s):
    t = s
    while True:
        t = t.lstrip()
        if t.startswith('--'):
            t = t.split('\n', 1)[1] if '\n' in t else ''
        elif t.startswith('/*'):
            j = t.find('*/'); t = t[j + 2:] if j >= 0 else ''
        else:
            return t


def main(paths):
    cn = conn(); cur = cn.cursor()
    cur.execute("USE ROLE GN_DW_ADMIN"); cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    for p in paths:
        txt = open(p, encoding='utf-8').read()
        n = 0
        for s in split_sql(txt):
            body = strip_lead(s)
            if body and re.match(r'(?is)^(use|create|alter|grant|comment)\b', body):
                try:
                    cur.execute(s); n += 1
                except Exception as e:
                    print(f'  ERR {p}: {body[:70]!r} :: {str(e)[:200]}')
                    raise
        print(f'{p.split("/")[-1]}: DDL {n} 실행')
    cn.close()


if __name__ == '__main__':
    main(sys.argv[1:])

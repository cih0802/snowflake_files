# -*- coding: utf-8 -*-
"""[2026-08-30 O121-B] `comment_drift_gate` **테이블레벨 축** 음성 테스트.

🔴🔴 왜 필요한가 — 이 축은 신설 직후 **거짓 드리프트 1건을 발행했다.**
   초판 정규식이 `'(.*)'\\s*;` + `re.S` 여서 **파일 마지막 테이블**에서 탐욕 매칭이 파일 끝까지
   삼켰다(실측 = 값 길이 **21,453자** ↔ 라이브 354자) ⇒ `FACT_MEMBER_SPONSOR_BIZ` 를
   「불일치」로 보고했다. 🟢 SQL 문자열 본문 패턴 `(?:[^']|'')*` 로 고쳤고, 이 테스트가 회귀를 막는다.

🔴 이 축이 왜 있어야 하는가(원 결함): 종전 드리프트 3축은 전부 **컬럼** COMMENT 였다
   ⇒ **테이블레벨 COMMENT 를 파일만 고치면 게이트가 🟢 를 내면서 드리프트가 생겼다.**
   O121 이 `SILVER.GA4_EVENT` 를 시정할 때 손으로 SHA256 대조해 피했다.

🟢 라이브 접속 없이 돈다 — 파서만 시험한다(라이브 대조는 `compare()` 공유 로직이며 3축이 이미 검증됐다).
"""
import sys
import os
import re
import tempfile

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as G

results = []


def check(name, cond, detail=''):
    results.append((name, cond, detail))
    print(('  🟢 PASS  ' if cond else '  🔴 FAIL  ') + name
          + ('  — %s' % detail if detail else ''))


def parse(text, schema='GOLD'):
    rx = G.RE_TABLE if schema == 'GOLD' else G.RE_SILVER
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False,
                                     encoding='utf-8') as fh:
        fh.write(text)
        p = fh.name
    try:
        return G.parse_ddl_table_level(p, rx)
    finally:
        os.remove(p)


def tbl(name, comment, schema='GOLD'):
    return ("CREATE OR REPLACE TABLE GN_DW.%s.%s (\n"
            "    A VARCHAR COMMENT '컬럼'\n"
            ") COMMENT = '%s';\n" % (schema, name, comment))


print('=' * 72)
print('comment_drift_gate 테이블레벨 축 음성 테스트')
print('=' * 72)

# ① 기본 — 한 줄 형태를 값으로 뽑는다.
got = parse(tbl('T1', '설명 하나'))
check('① `) COMMENT = ...;` 한 줄 형태를 뽑는다',
      got == {'T1': '설명 하나'}, repr(got))

# ② 🔴🔴 회귀 축 — **파일 마지막 테이블**에서 탐욕 매칭이 뒤 내용을 삼키지 않는다.
#    초판이 실제로 여기서 21,453자를 뽑아 거짓 드리프트를 냈다.
tail = ("\n\n-- ==========================================\n"
        "-- 아래는 FK 선언 블록이며 COMMENT 가 아니다\n"
        "ALTER TABLE GN_DW.GOLD.T2 ADD CONSTRAINT X FOREIGN KEY (A) REFERENCES Y(A);\n"
        "SELECT 'literal with quote' FROM DUAL;\n")
got = parse(tbl('T2', '마지막 테이블 설명') + tail)
check('② 🔴 파일 마지막 테이블에서 꼬리를 삼키지 않는다(탐욕 회귀 차단)',
      got.get('T2') == '마지막 테이블 설명', '길이=%s' % len(got.get('T2', '')))

# ③ `''` 이스케이프를 값으로 되돌린다(비탐욕이 `''` 에서 멈추면 안 된다).
got = parse(tbl('T3', "미매핑은 ''(미매핑)'' 표기를 쓴다"))
check('③ `\'\'` 이스케이프를 삼키고 값으로 언이스케이프',
      got.get('T3') == "미매핑은 '(미매핑)' 표기를 쓴다", repr(got.get('T3')))

# ④ `)` 와 `COMMENT =` 가 줄바꿈으로 분리된 형태도 받는다(문서10 §26-B 가 기록한 형태).
split_form = ("CREATE OR REPLACE TABLE GN_DW.GOLD.T4 (\n"
              "    A VARCHAR COMMENT '컬럼'\n"
              ")\n  COMMENT = '줄바꿈 분리 형태';\n")
got = parse(split_form)
check('④ `)` 와 `COMMENT =` 줄바꿈 분리 형태를 받는다',
      got.get('T4') == '줄바꿈 분리 형태', repr(got.get('T4')))

# ⑤ 여러 테이블을 각자 값으로 귀속한다(앞 블록으로 밀리지 않는다 · §26-B 부수적발 유형).
got = parse(tbl('T5', 'A 설명') + tbl('T6', 'B 설명'))
check('⑤ 다중 테이블을 각자에게 귀속(귀속 밀림 없음)',
      got == {'T5': 'A 설명', 'T6': 'B 설명'}, repr(got))

# ⑥ 테이블레벨 COMMENT 가 없는 테이블은 **키를 만들지 않는다**(부재를 불일치로 세지 않는다).
no_comment = ("CREATE OR REPLACE TABLE GN_DW.GOLD.T7 (\n"
              "    A VARCHAR COMMENT '컬럼'\n"
              ");\n")
got = parse(no_comment)
check('⑥ 테이블 COMMENT 부재는 키를 만들지 않는다', got == {}, repr(got))

# ⑦ 🔴 주석 처리된 선언은 값이 없으므로 분모에 들어오지 않는다 —
#    실측 = `SILVER.BIGQUERY_REFINED_DATA`(외부 Python 적재 · DEC-37)가 이 경우이고
#    그래서 이 축(42)과 `audit_ddl_rule7` 블록 수(43)가 **둘 다 옳게** 다르다.
commented = ("-- CREATE OR REPLACE TABLE GN_DW.SILVER.T8 (\n"
             "--     A VARCHAR COMMENT '컬럼'\n"
             "-- ) COMMENT = '주석이므로 선언이 아니다';\n")
got = parse(commented, 'SILVER')
check('⑦ 주석 처리된 선언은 분모에 들어오지 않는다', got == {}, repr(got))

# ⑧ 🔴 컬럼 COMMENT 를 테이블 COMMENT 로 오인하지 않는다(두 축이 섞이면 판정이 무의미해진다).
got = parse(tbl('T9', '테이블 설명'))
check('⑧ 컬럼 COMMENT 를 값으로 잡지 않는다',
      got == {'T9': '테이블 설명'} and '컬럼' not in got.values(), repr(got))

# ⑨ 정규식에 `re.S`(DOTALL)가 다시 붙지 않았는지 직접 단정 — 회귀 원인 그 자체를 못박는다.
check('⑨ 🔴 RE_TBL_COMMENT 에 DOTALL 이 없다(탐욕 회귀의 원인)',
      not (G.RE_TBL_COMMENT.flags & re.S), 'flags=%d' % G.RE_TBL_COMMENT.flags)

# ⑩ 실물 정본 2파일에서 파싱 결과가 **라이브 규모와 같은 자리수**인지(값이 폭주하지 않는지).
real_gold = G.parse_ddl_table_level()
real_slv = G.parse_ddl_table_level(G.SILVER_DDL, G.RE_SILVER)
worst = max([len(v) for v in list(real_gold.values()) + list(real_slv.values())] or [0])
check('⑩ 실물 정본에서 최대 값 길이가 상식 범위(< 4,000자)',
      0 < worst < 4000, 'GOLD %d개 · SILVER %d개 · 최대 %d자'
      % (len(real_gold), len(real_slv), worst))

print('=' * 72)
bad = [n for n, c, _ in results if not c]
if bad:
    print('🔴 음성 테스트 실패 %d/%d: %s' % (len(bad), len(results), bad))
    sys.exit(1)
print('🟢 음성 테스트 %d/%d 통과 — 탐욕 회귀 차단 + 분모 자격 조건 축 포함'
      % (len(results), len(results)))

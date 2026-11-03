#!/usr/bin/env python3
"""음성 테스트 — sv_common_block_gate (O262 · R3-2). 라이브 접속 없음(소스 축만).

축 = ㉠ 정본 PASS(역방향 오탐 0) ㉡ 블록 누락 FAIL ㉢ 블록 변형(1자) FAIL ㉣ 순서(고유 절이 앞) FAIL
     ㉤ '' 이스케이프 안의 따옴표에서 리터럴이 끊기지 않는다 ㉥ 정본 문서 부재 = rc 2 ㉦ 분모 0 = FAIL
"""
import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sv_common_block_gate as G  # noqa: E402

CANON = "[O216 공통] 지표를 컬럼처럼 쓰지 않는다. ''(미매칭)'' 표기. [O206-C 합계] 합계 행 금지."
DOC = '<!-- CANON-BEGIN -->\n%s\n<!-- CANON-END -->\n' % CANON


def sv(body):
    return "CREATE OR ALTER SEMANTIC VIEW X\n  AI_SQL_GENERATION '%s';\n" % body


def run(files, doc=True):
    d = tempfile.mkdtemp()
    try:
        if doc:
            io.open(os.path.join(d, G.CANON_DOC), 'w', encoding='utf-8').write(DOC)
        for name, text in files.items():
            io.open(os.path.join(d, name), 'w', encoding='utf-8').write(text)
        return G.main(['--sv-dir', d, '--source-only'])
    finally:
        shutil.rmtree(d)


CASES = [
    ('㉠ 정본 + 고유 규칙 = PASS', {'05_01_a.sql': sv(CANON + ' [O9 고유] 핵심 규칙: (1) x')}, True, 0),
    ('㉠ 소문자 키워드도 정본이면 PASS', {'34_b.sql': sv(CANON).replace('AI_SQL_GENERATION', 'ai_sql_generation')}, True, 0),
    ('㉡ 블록 누락 = FAIL', {'05_02_a.sql': sv('핵심 규칙: (1) x')}, True, 1),
    ('㉢ 1자 변형 = FAIL', {'05_03_a.sql': sv(CANON.replace('금지.', '금지') + ' 핵심 규칙:')}, True, 1),
    ('㉣ 고유 절이 앞 = FAIL', {'22_a.sql': sv('[O9 고유] ' + CANON)}, True, 1),
    ('㉤ 리터럴 하나라도 위반이면 FAIL(두 번째 SV)', {'25_a.sql': sv(CANON) + sv('변형')}, True, 1),
    ('㉥ 정본 문서 부재 = rc 2', {'05_04_a.sql': sv(CANON)}, False, 2),
    ('㉦ 분모 0 = FAIL', {'99_other.sql': sv(CANON)}, True, 1),
]


def main():
    fail = 0
    for name, files, doc, want in CASES:
        got = run(files, doc)
        ok = got == want
        fail += not ok
        print('%s %s · got %s · want %s' % ('✅' if ok else '❌', name, got, want))
    print('실패 %d' % fail)
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())

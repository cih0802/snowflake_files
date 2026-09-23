#!/usr/bin/env python3
"""test_jinja_config_gate — jinja_config_gate 음성 테스트 (2026-09-22 O180 신설 · R3-2).

🔴🔴 **왜 음성 테스트가 필요한가** = 이 게이트의 1차 구현은 **오탐 5건**을 냈고,
  그 오탐을 믿었다면 GOLD dim 4건의 **유일 hook** 을 지워 append 무한 누적 사고를 냈다.
  ⇒ 이 게이트의 위험은 「놓치는 것」과 **「잘못 잡는 것」이 대등하다** ⇒ 양방향을 단정한다.

축 구성
  · 오염 축 6개 — 결함을 일부러 심어 **검출**을 단정한다(축1~축6).
  · 역방향 오탐 축 3개 — 정상 관용구를 주고 **0건**을 단정한다
      ㉠ 따옴표 안 Jinja 태그(GOLD dim 의 pre_hook) ⇒ 축2 가 잡으면 FAIL
      ㉡ SQL 주석 안의 config 예시      ⇒ 축1 이 잡으면 FAIL
      ㉢ macros 관용구(문서 주석 뒤 매크로 정의) ⇒ blocking 이 되면 FAIL
  · 회귀 축 1개 — **고치기 전 구현**(따옴표 무시 · 주석줄을 블록 시작으로 인정)으로
      되돌리면 그 오탐이 **실제로 되살아나는지** 실증한다(R3-2 「실패 실증」).
  · 라이브 축 1개 — 현재 워크스페이스 분모에서 blocking 0 을 단정한다.

🔴 이 파일은 손으로 만든다(`new_tool.py` 등재 대상이 아니다 · `test_*` 규약).
종료코드 = 0 전 축 통과 · 1 하나라도 실패.
"""
import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jinja_config_gate as G  # noqa: E402

# 🔴 Jinja 구분자를 소스에 글자로 적지 않는다 — 조립해서 쓴다(이 파일 자체가 예시가 되지 않게).
OB = '{' + '#'          # 여는 Jinja 주석
CB = '#' + '}'          # 닫는 Jinja 주석
OE = '{' + '{'          # 여는 Jinja 표현식
CE = '}' + '}'          # 닫는 Jinja 표현식

RESULTS = []


def check(name, ok, detail=''):
    RESULTS.append((name, bool(ok), detail))


def write_model(dirpath, fname, body):
    path = os.path.join(dirpath, fname)
    io.open(path, 'w', encoding='utf-8', newline='').write(body)
    return path


def run_on(body):
    """한 모델 본문을 임시 파일로 써서 게이트를 돌리고 findings 를 돌려준다."""
    tmp = tempfile.mkdtemp(prefix='jcg_')
    try:
        path = write_model(tmp, 'M.sql', body)
        findings, files = G.scan([path])
        assert len(files) == 1, files
        return findings
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


CONFIG_OK = (
    OE + ' config(\n'
    "    materialized='incremental',\n"
    "    incremental_strategy='append',\n"
    "    tags=['gold_ready']\n"
    ') ' + CE + '\n'
)


# ─────────────────────────── 오염 축 6개 ───────────────────────────

def t_axis1_config_inner_sql_comment():
    """축1 = config 블록 안 SQL 주석 ⇒ 검출되어야 한다."""
    body = (
        '-- 머리말\n'
        + OE + ' config(\n'
        "    materialized='incremental',\n"
        '    -- 🔴 이 주석이 결함이다 (Jinja 가 연산자로 파싱한다)\n'
        "    tags=['gold_ready']\n"
        ') ' + CE + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축1 오염 검출', len(f['axis1']) >= 1, '검출 %d건' % len(f['axis1']))


def t_axis2_unquoted_nested_close():
    """축2 = config 블록 안 **따옴표 밖** 중첩 닫기 ⇒ 검출되어야 한다."""
    body = (
        OE + ' config(\n'
        "    materialized='incremental',\n"
        '    tags=[' + OE + ' x ' + CE + '],\n'
        "    alias='A'\n"
        ') ' + CE + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축2 오염 검출', len(f['axis2']) >= 1, '검출 %d건' % len(f['axis2']))


def t_axis3_jinja_in_sql_comment():
    """축3 = SQL 주석 줄 안 Jinja 태그 ⇒ 경고로 검출되어야 한다."""
    body = (
        '-- 참고: ' + OE + " ref('X') " + CE + ' 를 쓴다\n'
        + CONFIG_OK + 'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축3 오염 검출', len(f['axis3']) >= 1, '검출 %d건' % len(f['axis3']))


def t_axis4_strip_open_after_sql_comment():
    """축4 = SQL 주석 직후 공백제거형 Jinja 주석 ⇒ 검출되어야 한다.

    🔴 이것이 사용자 빌드를 깨뜨린 실제 형태다 — 아래 SELECT 가 위 주석에 먹힌다.
    """
    body = (
        CONFIG_OK
        + '-- 설명 줄\n'
        + OB + '- 이 블록이 앞 줄바꿈을 먹는다 -' + CB + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축4 오염 검출', len(f['axis4']) >= 1, '검출 %d건' % len(f['axis4']))


def t_axis5_strip_close_before_statement():
    """축5 = 공백제거형 닫기 직후가 실행문 ⇒ 경고로 검출되어야 한다."""
    body = (
        CONFIG_OK
        + OB + ' 설명 -' + CB + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축5 오염 검출', len(f['axis5']) >= 1, '검출 %d건' % len(f['axis5']))


def t_axis6_delimiter_imbalance():
    """축6 = 주석 블록 안에 닫는 구분자를 본문 인용 ⇒ 개수 불균형으로 검출되어야 한다.

    🔴 O180 이 실제로 낸 사고다 — 인용한 그 자리에서 주석이 끝나고 뒤가 live SQL 이 됐다.
    """
    body = (
        CONFIG_OK
        + OB + ' 설명: 닫을 때는 ' + CB + ' 를 쓴다 ' + CB + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('축6 오염 검출', len(f['axis6']) >= 1, '검출 %d건' % len(f['axis6']))


# ─────────────────── 역방향 오탐 축 3개 (0건을 단정) ───────────────────

def t_no_fp_quoted_jinja_in_config():
    """㉠ GOLD dim 관용구 = 따옴표 안 Jinja 태그 ⇒ 축2 가 **잡으면 안 된다**.

    🔴 1차 구현이 이것을 4건 오탐했고, 믿었다면 유일 hook 을 지워 append 무한 누적이 됐다.
    """
    body = (
        OE + ' config(\n'
        "    materialized='incremental',\n"
        "    incremental_strategy='append',\n"
        "    pre_hook='TRUNCATE TABLE IF EXISTS " + OE + ' this ' + CE + "',\n"
        "    tags=['gold_ready']\n"
        ') ' + CE + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('㉠ 따옴표 안 태그 오탐 0', len(f['axis2']) == 0,
          '오탐 %d건' % len(f['axis2']))
    check('㉠ blocking 0', G.blocking_count(f) == 0,
          'blocking %d건' % G.blocking_count(f))


def t_no_fp_config_example_in_comment():
    """㉡ SQL 주석 안의 config 예시 ⇒ 축1 이 **잡으면 안 된다**(블록이 아니다)."""
    body = (
        '-- 사용법:\n'
        '--   ' + OE + " config(materialized='gn_view_commented') " + CE + '\n'
        + CONFIG_OK + 'SELECT 1 AS X\n'
    )
    f = run_on(body)
    check('㉡ 주석 내 config 예시 축1 오탐 0', len(f['axis1']) == 0,
          '오탐 %d건' % len(f['axis1']))


def t_no_fp_clean_model():
    """㉢ 완전 정상 모델 ⇒ 전 축 0건."""
    body = (
        '-- 정상 모델\n'
        + CONFIG_OK
        + OB + ' 평범한 Jinja 주석 ' + CB + '\n'
        'SELECT 1 AS X\n'
    )
    f = run_on(body)
    total = sum(len(v) for v in f.values())
    check('㉢ 정상 모델 전 축 0', total == 0, '검출 %d건' % total)


# ─────────────────── 회귀 축 = 고치기 전 구현으로 되돌린다 ───────────────────

def t_regression_pre_fix_implementation():
    """🔴 R3-2 실증 = 고치기 전 판정식으로 되돌리면 그 오탐이 되살아나야 한다.

    고치기 전 = ㉠ 따옴표를 무시한다(strip_quoted 를 항등함수로)
                ㉡ 주석줄도 config 블록 시작으로 인정한다
    ⇒ 되살아나지 않으면 이 테스트는 **아무것도 지키지 않는다**.
    """
    quoted_body = (
        OE + ' config(\n'
        "    materialized='incremental',\n"
        "    pre_hook='TRUNCATE TABLE IF EXISTS " + OE + ' this ' + CE + "',\n"
        "    tags=['gold_ready']\n"
        ') ' + CE + '\n'
        'SELECT 1 AS X\n'
    )
    comment_body = (
        '--   ' + OE + " config(materialized='x') " + CE + '\n'
        + CONFIG_OK + 'SELECT 1 AS X\n'
    )

    # ㉠ 따옴표 무시로 되돌린다
    orig_strip = G.strip_quoted
    try:
        G.strip_quoted = lambda t: t
        f = run_on(quoted_body)
        check('회귀㉠ 따옴표 무시 시 축2 오탐 재현',
              len(f['axis2']) >= 1, '재현 %d건' % len(f['axis2']))
    finally:
        G.strip_quoted = orig_strip

    # ㉡ 주석줄을 블록 시작으로 인정하도록 되돌린다
    orig_spans = G.config_spans

    def spans_pre_fix(lines):
        import re
        out = []
        start = None
        for i, line in enumerate(lines, 1):
            if start is None and re.search(r'\{\{\s*config\s*\(', line):
                start = i
                if re.search(r'\)\s*\}\}', line[line.index('config'):]):
                    out.append((start, i))
                    start = None
                continue
            if start is not None and re.search(r'\)\s*\}\}', line):
                out.append((start, i))
                start = None
        if start is not None:
            out.append((start, len(lines)))
        return out

    try:
        G.config_spans = spans_pre_fix
        f = run_on(comment_body)
        check('회귀㉡ 주석줄 인정 시 축1 오탐 재현',
              len(f['axis1']) >= 1, '재현 %d건' % len(f['axis1']))
    finally:
        G.config_spans = orig_spans

    # 되돌림 해제 후 정상 판정 복귀
    f = run_on(quoted_body)
    check('회귀 해제 후 축2 정상 복귀', len(f['axis2']) == 0,
          '잔존 %d건' % len(f['axis2']))


# ─────────────────── 라이브 축 = 현재 분모 blocking 0 ───────────────────

def t_live_blocking_zero():
    f, files = G.scan()
    check('라이브 분모 blocking 0', G.blocking_count(f) == 0,
          '분모 %d파일 · blocking %d건' % (len(files), G.blocking_count(f)))


def main():
    for fn in (
        t_axis1_config_inner_sql_comment,
        t_axis2_unquoted_nested_close,
        t_axis3_jinja_in_sql_comment,
        t_axis4_strip_open_after_sql_comment,
        t_axis5_strip_close_before_statement,
        t_axis6_delimiter_imbalance,
        t_no_fp_quoted_jinja_in_config,
        t_no_fp_config_example_in_comment,
        t_no_fp_clean_model,
        t_regression_pre_fix_implementation,
        t_live_blocking_zero,
    ):
        try:
            fn()
        except Exception as exc:  # noqa: BLE001
            check(fn.__name__ + ' (예외)', False, repr(exc))

    fails = [r for r in RESULTS if not r[1]]
    print('[test_jinja_config_gate] 단정 %d개' % len(RESULTS))
    for (name, ok, detail) in RESULTS:
        print('  %s %s%s' % ('🟢' if ok else '🔴', name,
                             ('  — ' + detail) if detail else ''))
    print('\n판정 = 통과 %d / %d' % (len(RESULTS) - len(fails), len(RESULTS)))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())

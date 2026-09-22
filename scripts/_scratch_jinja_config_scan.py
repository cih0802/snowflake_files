#!/usr/bin/env python3
"""_scratch_jinja_config_scan — config() 블록 내 SQL 주석 · 주석 내 Jinja 태그 전수 탐지.

왜 임시 계측기인가 = O180 이 1회 전수 판정을 위해 만들었다.
🔴 영구화하려면 new_tool.py --promote-scratch 로 게이트로 승격해야 한다
   (gate_census --final 이 잔존을 FAIL 로 잡는다).

축1 = 진짜 config() 블록 안에 '--' 가 있는가              ⇒ Jinja 가 연산자로 파싱 ⇒ 컴파일 에러
축2 = 그 블록 안에 **따옴표 밖** 중첩 '}}' 가 있는가       ⇒ config 조기 종료
축3 = SQL 주석('--' 로 시작하는 줄) 안에 Jinja 태그이 있는가 ⇒ 주석이어도 렌더된다(경고)

🔴🔴 [O180 자체 정정] 1차 구현이 오탐 5건을 냈다 — 판정식이 틀렸다:
  ㉠ 축2 오탐 4건 = GOLD dim 의 `pre_hook='TRUNCATE TABLE IF EXISTS <this>'` 는
     **따옴표 문자열 안**이고 Jinja 렉서는 문자열을 존중한다 ⇒ 정상 관용구다.
     🔴 이 오탐을 믿고 지우면 그 4건은 `gold.dim:` 에 프로젝트 hook 이 없어 **유일 hook** 이므로
        TRUNCATE 가 사라져 append 가 무한 누적된다(정반대 사고).
  ㉡ 축1 오탐 1건 = `--` 주석 안의 config 예시를 블록 시작으로 오인했다
     ⇒ 블록 시작 판정에서 **주석줄을 제외**한다.
  🟢 판정식 = **「같은 모양」이 「같은 결함」은 아니다** — 따옴표 안인지, 주석인지를 먼저 본다.
"""
import io
import os
import re
import sys

ROOT = '/workspace/10_dbt_pipeline'
SCAN = [os.path.join(ROOT, 'models'), os.path.join(ROOT, 'macros')]

# 주석 안에서 렌더되는 Jinja 태그 = {{ ... }} 또는 {% ... %}
JINJA_IN_COMMENT = re.compile(r'\{\{.*?\}\}|\{%.*?%\}')


def strip_quoted(text):
    """따옴표로 감싼 구간을 공백으로 치환한다 — Jinja 렉서가 문자열을 존중하는 것을 모사."""
    out = []
    quote = None
    for ch in text:
        if quote is None and ch in ("'", '"'):
            quote = ch
            out.append(' ')
        elif quote is not None and ch == quote:
            quote = None
            out.append(' ')
        elif quote is not None:
            out.append(' ')
        else:
            out.append(ch)
    return ''.join(out)


def sql_files():
    out = []
    for base in SCAN:
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                if fn.endswith('.sql'):
                    out.append(os.path.join(dirpath, fn))
    return sorted(out)


def config_spans(lines):
    """{{ config( 로 시작해 ) }} 로 닫히는 줄 범위를 [(start, end)] 로 돌려준다(1-based).

    🔴 주석줄('--' 로 시작)은 블록 시작으로 보지 않는다(O180 오탐 ㉡).
    """
    spans = []
    start = None
    for i, line in enumerate(lines, 1):
        if start is None:
            if line.lstrip().startswith('--'):
                continue
            if re.search(r'\{\{\s*config\s*\(', line):
                start = i
                tail = line[line.index('config'):]
                if re.search(r'\)\s*\}\}', tail):
                    spans.append((start, i))
                    start = None
            continue
        if re.search(r'\)\s*\}\}', line):
            spans.append((start, i))
            start = None
    if start is not None:
        spans.append((start, len(lines)))
    return spans



def main():
    findings = {'axis1': [], 'axis2': [], 'axis3': []}
    files = sql_files()
    for path in files:
        with io.open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        spans = config_spans(lines)
        for (s, e) in spans:
            for ln in range(s, e + 1):
                body = lines[ln - 1]
                if '--' in body:
                    findings['axis1'].append((path, ln, body.strip()[:120]))
                # 🔴 중첩 닫기는 **따옴표 밖**일 때만 결함이다(O180 오탐 ㉠)
                if s < ln < e and '}}' in strip_quoted(body):
                    findings['axis2'].append((path, ln, body.strip()[:120]))
        for i, line in enumerate(lines, 1):
            stripped = line.lstrip()
            if not stripped.startswith('--'):
                continue
            hit = JINJA_IN_COMMENT.search(line)
            if hit:
                findings['axis3'].append((path, i, hit.group(0)[:80]))

    rel = lambda p: os.path.relpath(p, '/workspace')
    print('[_scratch_jinja_config_scan] 분모 = %d 파일' % len(files))
    for axis, label in (
        ('axis1', "축1 config() 안 '--' 주석 (컴파일 에러 · blocking)"),
        ('axis2', '축2 config() 안 중첩 닫기 (조기 종료 · blocking)'),
        ('axis3', '축3 SQL 주석 안 Jinja 태그 (렌더됨 · 위험)'),
    ):
        rows = findings[axis]
        mark = '✅' if not rows else '🔴'
        print('\n%s %s = %d건' % (mark, label, len(rows)))
        for (p, ln, body) in rows:
            print('   %s:%d  %s' % (rel(p), ln, body))

    blocking = len(findings['axis1']) + len(findings['axis2'])
    print('\n판정 = blocking %d건 · 축3 경고 %d건' % (blocking, len(findings['axis3'])))
    return 1 if blocking else 0


if __name__ == '__main__':
    sys.exit(main())

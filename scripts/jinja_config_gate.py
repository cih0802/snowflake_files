#!/usr/bin/env python3
"""jinja_config_gate — dbt Jinja 안전 게이트 (2026-09-22 O180 신설 · JUDGE).

🔴🔴 **왜 이 게이트가 있는가** = 이 class 가 **한 세션에 4회 재발**했고 매번 눈으로는 통과했다.
  ㉠ O179 가 리터럴 `pre_hook` 을 제거하며 설명 주석을 `config()` **안**에 남겼다(GOLD 팩트 4건)
     ⇒ `config` 호출은 Jinja 표현식이라 `--` 가 주석이 아니라 연산자로 파싱된다
     ⇒ `Compilation Error: invalid syntax for function call expression`.
  ㉡ O180 이 그 수정 설명에 Jinja 태그를 **인용**했다 ⇒ dbt 는 파일 전체를 렌더하므로
     `--` 도 백틱도 Jinja 를 막지 못한다(주석 안에서도 태그가 동작한다).
  ㉢ O180 이 공백제거형 Jinja 주석을 썼다 ⇒ 앞 공백 제거가 직전 줄바꿈을 삭제해
     바로 아래 `SELECT` 를 **위의 SQL 주석 안으로 끌어들였다** ⇒ 첫 토큰이 `NULLIF` 가 되어
     `syntax error line 65 at position 2 unexpected 'NULLIF'`(사용자 빌드 실패).
  ㉣ O180 이 그 설명에서 **닫는 구분자를 글자로 인용**했다 ⇒ 그 자리에서 주석이 끝나고
     뒤의 설명문이 live SQL 이 됐다.
  🟢 **판정식 = 이 결함은 전부 「세면 잡히고 읽으면 놓친다」** ⇒ 기계화가 유일한 처방이다.
  🔴 dbt 는 에이전트 정지점(`R4-1`)이라 편집자가 컴파일로 확인할 수 없다 —
     그래서 **컴파일 전에** 잡는 게이트가 필요하다. `dbt build` PASS 기준선은
     그 편집 **이전** 값이므로 변경을 보증하지 않는다.

축 (blocking = 축1·2·4·6 / 경고 = 축3·5)
  축1 진짜 config 블록 안에 `--` 가 있는가              ⇒ Jinja 가 연산자로 파싱 ⇒ 컴파일 에러
  축2 그 블록 안에 **따옴표 밖** 중첩 닫는 중괄호가 있는가 ⇒ config 조기 종료
  축3 SQL 주석 줄 안에 Jinja 태그이 있는가                ⇒ 주석이어도 렌더된다(경고)
  축4 SQL 주석 직후에 공백제거형 Jinja 주석이 열리는가    ⇒ 다음 실행문이 그 주석에 먹힌다
  축5 공백제거형 닫기 직후가 실행문인가                   ⇒ 붙는다(경고 · macros 는 정상 관용구)
  축6 Jinja 주석 여는/닫는 구분자 **개수 불균형**         ⇒ 본문 인용 ⇒ 조기 종료

🔴🔴 [O180 자체 정정] 1차 구현이 **오탐 5건**을 냈다 — 판정식이 틀렸다:
  ㉠ 축2 오탐 4건 = GOLD dim 의 `pre_hook='TRUNCATE TABLE IF EXISTS <this>'` 는
     **따옴표 문자열 안**이고 Jinja 렉서는 문자열을 존중한다 ⇒ 정상 관용구다.
     🔴 이 오탐을 믿고 지우면 그 4건은 `gold.dim:` 에 프로젝트 hook 이 없어 **유일 hook** 이므로
        TRUNCATE 가 사라져 append 가 무한 누적된다(**정반대 사고**).
  ㉡ 축1 오탐 1건 = `--` 주석 안의 config 예시를 블록 시작으로 오인했다
     ⇒ 블록 시작 판정에서 **주석줄을 제외**한다.
  🟢 판정식 = **「같은 모양」이 「같은 결함」은 아니다** — 따옴표 안인지, 주석인지를 먼저 본다.

🔴 이 파일 안에서 Jinja 구분자를 **문자열 리터럴로만** 다룬다(본문·docstring 에 글자로 적지 않는다).
   이 파일은 `.py` 라 렌더되지 않지만, 같은 규율을 지켜 예시가 사고를 재생산하지 않게 한다.

음성 테스트 = `scripts/test_jinja_config_gate.py`(오염 기반 6축 + 역방향 오탐 축).
종료코드 = 0 blocking 0건 · 1 blocking 1건 이상.
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


def sql_files(scan=None):
    out = []
    for base in (scan or SCAN):
        if os.path.isfile(base):
            if base.endswith('.sql'):
                out.append(base)
            continue
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



def scan(scan_paths=None):
    """분모를 받아 6축 결과 dict 를 돌려준다(음성 테스트가 오염 분모를 넘긴다)."""
    findings = {'axis%d' % n: [] for n in range(1, 7)}
    files = sql_files(scan_paths)
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
        # 축4 = '--' SQL 주석 직후의 '{#-' (앞 공백 제거가 다음 실행문을 주석에 먹인다)
        for i, line in enumerate(lines, 1):
            if i < 2:
                continue
            if '{#-' not in line:
                continue
            prev = lines[i - 2].lstrip()
            if prev.startswith('--'):
                findings['axis4'].append((path, i, line.strip()[:120]))
        # 축5 = '-#}' 직후 줄이 '--' 주석인가 (뒤 공백 제거가 다음 줄을 그 주석에 먹인다)
        for i, line in enumerate(lines, 1):
            if '-#}' not in line or i >= len(lines):
                continue
            nxt = lines[i].lstrip() if i < len(lines) else ''
            if nxt and not nxt.startswith('--'):
                findings['axis5'].append((path, i, ('다음줄: ' + nxt)[:120]))

        # 축6 = Jinja 주석 여는/닫는 구분자 **개수 불균형**
        #   🔴 O180 이 실제로 낸 사고의 기계 판정식이다 — 주석 블록 **안**에서 닫는 구분자를
        #      글자로 인용하면 Jinja 는 그 자리에서 주석을 끝내고 뒤의 설명문이 live SQL 이 된다.
        #   🟢 판정식 = 인용이 있으면 닫는 구분자가 여는 것보다 많아진다(세면 잡힌다).
        #      의도를 추측하지 않고 **개수만** 센다 ⇒ 오탐이 적고 놓치지 않는다.
        joined = '\n'.join(lines)
        n_open = joined.count('{#')
        n_close = joined.count('#}')
        if n_open != n_close:
            findings['axis6'].append(
                (path, 0, '여는 구분자 %d개 ≠ 닫는 구분자 %d개 (차 %+d)'
                 % (n_open, n_close, n_close - n_open)))

    return findings, files


BLOCKING_AXES = ('axis1', 'axis2', 'axis4', 'axis6')
WARN_AXES = ('axis3', 'axis5')

LABELS = (
    ('axis1', "축1 config 블록 안 SQL 주석 (Jinja 가 연산자로 파싱 ⇒ 컴파일 에러 · blocking)"),
    ('axis2', '축2 config 블록 안 따옴표 밖 중첩 닫기 (조기 종료 · blocking)'),
    ('axis3', '축3 SQL 주석 안 Jinja 태그 (주석이어도 렌더된다 · 경고)'),
    ('axis4', '축4 SQL 주석 직후 공백제거형 Jinja 주석 (다음 실행문을 먹는다 · blocking)'),
    ('axis5', '축5 공백제거형 닫기 직후가 실행문 (붙는다 · 경고 · macros 는 정상)'),
    ('axis6', '축6 Jinja 주석 구분자 개수 불균형 (본문 인용 ⇒ 조기 종료 · blocking)'),
)


def blocking_count(findings):
    return sum(len(findings[a]) for a in BLOCKING_AXES)


def main():
    findings, files = scan()
    rel = lambda p: os.path.relpath(p, '/workspace')
    print('[jinja_config_gate] 분모 = %d 파일' % len(files))
    for axis, label in LABELS:
        rows = findings[axis]
        mark = '✅' if not rows else '🔴'
        print('\n%s %s = %d건' % (mark, label, len(rows)))
        for (p, ln, body) in rows:
            print('   %s:%d  %s' % (rel(p), ln, body))

    blocking = blocking_count(findings)
    warn = sum(len(findings[a]) for a in WARN_AXES)
    print('\n판정 = blocking %d건(축1+축2+축4+축6) · 경고 %d건(축3+축5)' % (blocking, warn))
    if blocking:
        print('🔴 FAIL — dbt 컴파일이 깨지거나 SQL 이 조용히 잘린다. 고치기 전에 build 하지 마라.')
    else:
        print('✅ 게이트 통과 — blocking 0건')
    return 1 if blocking else 0


if __name__ == '__main__':
    sys.exit(main())

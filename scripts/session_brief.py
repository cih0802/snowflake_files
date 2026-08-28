#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""session_brief.py — 세션 착수 브리핑을 **정본에서 추출해 생성**한다.

[2026-08-28 O106 신설 · `R4-4-1`·`init_ihcho` Step 3 의 집행 장치]

🔴 왜 필요한가 — 브리핑이 「독해의 산출물」이라 구조적으로 위반이 났다
--------------------------------------------------------------------------
`R4-4-1` 은 *"브리핑은 Step 2 독해의 산출물이므로 생략은 미독의 증거다"* 라고 규정한다.
그런데 Step 2 가 요구하는 전량 독해는 **물리적으로 불가능**하다 — O106 실측:

    지침 18,109자 + 00_INDEX 114,934 + 50_dbt 190,010 + 99_NEXT 146,825
      = 「필수」만 469,878자  (전 문서군 1,678,616자)

⇒ 규약을 지키면 컨텍스트가 터지고, 터지지 않으려면 **읽지 않고 읽은 척**하게 된다.
   그것이 `R1-3-7` 이 잡으려던 실패의 **상류 원인**이고, `R4-4-1` 위반이
   **최소 6세션 연속** 등재된 이유와 같은 구조다(원인은 게으름이 아니라 조문 설계).

🟢 처방 = 브리핑을 **스크립트의 산출물**로 바꾼다
--------------------------------------------------------------------------
· 열린 작업·게이트 상태는 **표에서 기계로 추출**한다 ⇒ 읽지 않아도 정확하다.
· 「읽은 척」이 **원리적으로 불가능**해진다(수치의 출처가 파일이고 재현 가능하다).
· 에이전트는 브리핑에 실린 **좌표만 보고 필요한 조각을 골라** 읽는다.

🔴 이 도구가 **내용을 요약하지 않는다**
--------------------------------------------------------------------------
각 항목은 **제목 + 상태 + 좌표(파일:행)** 만 싣는다. 판정·수치는 싣지 않는다.
근거 = `R1-3-7` 「대체 근거 금지」 — 요약을 근거로 쓰면 정본 대체물이 된다.
⇒ 브리핑은 **색인**이고 정본이 아니다. 수치를 인용하려면 그 좌표를 읽어야 한다.

🔴 DB 를 보지 않는다 — 파일시스템만 읽는다(이 계정은 문서작업용).
   라이브 판정이 필요한 항목은 `92_실측필요_후속작업.md` 소관이다(`R2-8-4-c`).

사용
--------------------------------------------------------------------------
    python3 scripts/session_brief.py               # 브리핑을 stdout 에 출력
    python3 scripts/session_brief.py --no-gates    # 게이트 실행 생략(빠름)
    python3 scripts/session_brief.py --write       # `20_issue/00_BRIEF.md` 생성
"""

import argparse
import io
import os
import re
import subprocess
import sys
import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRIEF = os.path.join(ROOT, '20_issue', '00_BRIEF.md')
MAX_BRIEF_BYTES = 32 * 1024      # doc_type_gate 축3(여유 20%)을 만족하는 상한

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from doc_census import census, stale_check, chunk_paths      # noqa: E402

EMOJI_OPEN = ('🔴', '🟠', '🟡')
EMOJI_DONE = ('🟢', '✅')
STRIKE = re.compile(r'^\s*~~.*~~\s*$')
LEAD_EMO = re.compile(r'^([🟢🟡🟠🔴✅⚪⛔🆕🔒🔄🛠️❌⚠️\s]*)')


def read_text(p):
    with io.open(p, encoding='utf-8', errors='replace') as fh:
        return fh.read()


def strip_md(s):
    """표시용 축약 — 마크다운 장식을 걷어낸다(내용은 자르지 않는다)."""
    s = re.sub(r'<br\s*/?>', ' ', s)
    s = s.replace('**', '').replace('`', '')
    return re.sub(r'\s+', ' ', s).strip()


def clip(s, n):
    return s if len(s) <= n else s[:n - 1] + '…'


def family_lines(hub_rel, where='sibling'):
    """(파일상대경로, 행번호, 줄) 스트림 — 허브+조각을 순서대로."""
    out = []
    hub = os.path.join(ROOT, hub_rel)
    paths = [hub] + chunk_paths(hub_rel, where)
    for p in paths:
        if not os.path.exists(p):
            continue
        rel = os.path.relpath(p, ROOT)
        for i, line in enumerate(read_text(p).split('\n'), 1):
            out.append((rel, i, line))
    return out


# ── 표 범위 한정 헬퍼 ──────────────────────────────────────────────────
#   🔴🔴 [O106 자기시정] 첫 판본은 「4열 이상인 표 행」을 전부 착수표로 봤고
#     그 결과 허브의 **조각 목차 표**·**대조 표**·**결함 표** 등이 섞여
#     열린 작업이 **크게 과대**로 나왔다(허브 조각 목차 13행이 그대로 실렸다).
#     ⇒ 표는 **헤더 서명(첫 셀 이름들)으로 범위를 한정**한다. 열 수는 판정 근거가 못 된다.
def rows_of_table(lines, head_cells):
    """헤더 첫 셀이 `head_cells` 중 하나인 표의 **본문 행만** 돌려준다."""
    out, inside = [], False
    for rel, ln, line in lines:
        s = line.strip()
        if not s.startswith('|'):
            inside = False
            continue
        cells = [c.strip() for c in s.strip('|').split('|')]
        if not cells:
            continue
        if set(''.join(cells)) <= set('-: '):
            continue                       # 구분행
        first = strip_md(cells[0])
        if first in head_cells:
            inside = True                  # 헤더 행 — 다음부터 본문
            continue
        if inside:
            out.append((rel, ln, cells))
    return out


# ── ① 착수표(열린 작업) ─────────────────────────────────────────────────
#   🔴 열림 판정 = 「순」 셀이 **취소선이 아니다**. 취소선(`~~⑨~~`)은 완료 관례다.
#     근거 = `99_NEXT` 착수표가 완료 항목을 `~~순~~` + `✅` 로 표기한다.
def open_tasks(lines=None):
    if lines is None:
        lines = family_lines('99_NEXT_SESSION.md')
    rows = []
    for rel, ln, cells in rows_of_table(lines, ('순',)):
        if len(cells) < 4:
            continue
        order = cells[0]
        if STRIKE.match(order):
            continue                     # 완료
        if '✅' in cells[1][:8]:
            continue                     # 완료 표기가 작업 셀 선두에 온 경우
        rows.append({
            'order': strip_md(order),
            'task': clip(strip_md(cells[1]), 130),
            'stop': clip(strip_md(cells[2]), 34),
            'where': '%s:%d' % (rel, ln),
        })
    return rows


# ── ② 문서50 열린 절 ────────────────────────────────────────────────────
def open_sections(hub_rel, lines=None):
    out = []
    if lines is None:
        lines = family_lines(hub_rel)
    for rel, ln, line in lines:
        if not line.startswith('## '):
            continue
        t = line[3:].strip()
        lead = LEAD_EMO.match(t).group(1)
        if any(e in lead for e in EMOJI_DONE):
            continue
        if not any(e in lead for e in EMOJI_OPEN):
            continue
        out.append({'title': clip(strip_md(t), 130), 'where': '%s:%d' % (rel, ln)})
    return out


# ── ③ 현행 인수인계 절 ─────────────────────────────────────────────────
#   🔴 `99_NEXT` 는 「여기서 시작한다」가 **적층**된다(O106 실측 8겹).
#     승계된 것은 `~~여기서 시작한다~~` 취소선으로 표시되므로 **취소선이 아닌 것**만 고르고,
#     그중 **날짜가 가장 최신**인 절을 현행으로 판정한다.
DATE_RX = re.compile(r'(20\d\d-\d\d-\d\d)')


def current_handoff(lines=None):
    if lines is None:
        lines = family_lines('99_NEXT_SESSION.md')
    cands = []
    for rel, ln, line in lines:
        if not line.startswith('## '):
            continue
        if '여기서 시작한다' not in line or '~~여기서 시작한다' in line:
            continue
        m = DATE_RX.search(line)
        cands.append({'date': m.group(1) if m else '0000-00-00',
                      'title': clip(strip_md(line[3:]), 120),
                      'where': '%s:%d' % (rel, ln)})
    if not cands:
        return None, []
    cur = max(cands, key=lambda c: c['date'])
    # 그 절의 ▣ 하위 항목을 좌표와 함께 모은다
    subs, hit = [], False
    for rel, ln, line in lines:
        loc = '%s:%d' % (rel, ln)
        if loc == cur['where']:
            hit = True
            continue
        if hit and line.startswith('## '):
            break
        if hit and line.startswith('### '):
            subs.append({'title': clip(strip_md(line[4:]), 120), 'where': loc})
    return cur, subs


# ── ④ 원장 §1 최신 세션 행 ──────────────────────────────────────────────
SESSION_RX = re.compile(r'`(O\d+[A-Z\-]*)`')


def recent_sessions(n=6, lines=None):
    if lines is None:
        lines = family_lines('20_issue/00_INDEX_이슈원장.md')
    out = []
    for rel, ln, cells in rows_of_table(lines, ('현황',)):
        if len(cells) < 3:
            continue
        m = SESSION_RX.search(cells[0])
        if not m:
            continue
        out.append({'label': m.group(1),
                    'head': clip(strip_md(cells[0]), 100),
                    'state': clip(strip_md(cells[1]), 64),
                    'where': '%s:%d' % (rel, ln)})
        if len(out) >= n:
            break
    return out


# ── ⑤ 게이트 ───────────────────────────────────────────────────────────
GATES = [
    ('doc_census', ['scripts/doc_census.py']),
    ('doc_type_gate', ['scripts/doc_type_gate.py']),
    ('clause_order_gate', ['scripts/clause_order_gate.py']),
    ('index_row_gate', ['scripts/index_row_gate.py']),
    ('doc_heading_gate', ['scripts/doc_heading_gate.py']),
    # 🆕 [2026-08-28 O109] 인용 좌표 실재 — 폴더화·재균형이 좌표를 죽인다(축1a blocking).
    ('doc_coord_gate', ['scripts/doc_coord_gate.py']),
]


#: 게이트 판정 줄 = 상태 이모지로 시작하는 줄. 🔴 [2026-08-28 O110] 종전에는 **마지막 줄**을
#: 그대로 판정으로 썼는데, 여러 게이트가 판정 뒤에 **처방 힌트 줄**을 덧붙인다 ⇒
#: ㉠ `doc_type_gate` 는 힌트(`- 여유 부족 …`)가 실려 판정이 **🟡 인데 ✅ 로 표시**됐고
#: ㉡ `clause_order_gate` 는 「경고 **0**건」의 「경고」에 걸려 **✅ 인데 🟡 로 표시**됐다.
#: ⇒ **세션 시작이 의존하는 표가 두 방향으로 거짓말**을 했다(O109 D5).
STATUS_HEAD = re.compile(r'^(?:✅|🟢|🟡|🔴|⚪)')
#: 경고 「0건」은 경고가 아니다 — 수를 보고 판정한다.
WARN_RX = re.compile(r'🟡|경고\s*([1-9]\d*)\s*건|(?<![0-9])([1-9]\d*)건\s*(?:경고|·\s*사람 판단)')


def gate_verdict(tail):
    """게이트 stdout 에서 **판정 줄**을 고른다(힌트 줄이 아니라)."""
    for line in reversed(tail):
        if STATUS_HEAD.match(line.strip()):
            return line.strip()
    return tail[-1].strip() if tail else '(출력 없음)'


def gate_mark(rc, verdict):
    """rc + 판정 줄로 마크를 정한다 — 🔴 FAIL · 🟡 통과(경고 있음) · ✅ 통과."""
    if rc != 0:
        return '🔴'
    return '🟡' if WARN_RX.search(verdict) else '✅'


def run_gates():
    out = []
    for name, argv in GATES:
        try:
            r = subprocess.run([sys.executable] + argv, cwd=ROOT,
                               capture_output=True, text=True, timeout=300)
            tail = [l for l in r.stdout.strip().split('\n') if l.strip()]
            verdict = gate_verdict(tail)
            mark = gate_mark(r.returncode, verdict)
            out.append({'name': name, 'mark': mark, 'rc': r.returncode,
                        'verdict': clip(strip_md(verdict), 120)})
        except Exception as e:                       # pragma: no cover
            out.append({'name': name, 'mark': '⚪', 'rc': -1,
                        'verdict': '실행 실패: %s' % e})
    return out


# ── 조립 ───────────────────────────────────────────────────────────────
def build(with_gates=True):
    inv = census()
    stale = stale_check(inv)
    tasks = open_tasks()
    d50 = open_sections('20_issue/50_dbt_파이프라인_미결조치.md')
    cur, subs = current_handoff()
    recent = recent_sessions()
    gates = run_gates() if with_gates else []

    L = []
    a = L.append
    a('<!-- LLM-METADATA')
    a('doc_id: SESSION_BRIEF')
    a('doc_role: 세션 착수 브리핑 — 열린 작업·인수인계·게이트 상태의 **색인**(정본 아님)')
    a('project: GN_DW (굿네이버스)')
    a('created: 2026-08-28')
    a('created_by: O106')
    a('index: 20_issue/00_INDEX_이슈원장.md')
    a('END-METADATA -->')
    a('')
    a('# 00_BRIEF — 세션 착수 브리핑 (자동 생성)')
    a('')
    a('> 🔴🔴 **이 파일은 자동 생성물이다 — 여기에 내용을 쓰지 마라.**')
    a('> `python3 scripts/session_brief.py --write` 가 **통째로 다시 쓴다**')
    a('> ⇒ 손으로 적은 문장은 **조용히 사라진다**(허브와 같은 계약 · `R1-6` 축).')
    a('> 내용은 정본(원장 조각 · `99_NEXT` 조각 · 문서50 조각)에 쓰고 이 파일을 재생성한다.')
    a('')
    a('> 🔴 **이 브리핑은 색인이고 정본이 아니다.** 각 항목은 **제목 + 상태 + 좌표**만 싣는다.')
    a('> 판정·수치를 인용하려면 **그 좌표를 `read` 해야 한다**(`R1-3-7` 「대체 근거 금지」).')
    a('> 🟢 대신 **무엇을 읽어야 하는지**가 여기 다 있다 ⇒ 전량 독해가 불필요해진다.')
    a('')
    a('> 📏 생성 시각 기준 실측 = 아래 수치는 **전부 파일에서 센 것**이다(창작 0).')
    a('')

    a('## 1. 열린 작업 — 착수표 (정본 = `99_NEXT_SESSION` 착수 순서)')
    a('')
    a('> 판정 = 「순」 셀이 **취소선이 아닌 행**. 취소선(`~~⑨~~`)은 완료 관례다.')
    a('')
    if tasks:
        a('| 순 | 작업 | 정지점 | 정본 좌표 |')
        a('|---|---|---|---|')
        for t in tasks:
            a('| %s | %s | %s | `%s` |' % (t['order'], t['task'], t['stop'] or '—',
                                           t['where']))
    else:
        a('⚪ 착수표에서 열린 행을 찾지 못했다 — 표 형식이 바뀌었는지 확인하라.')
    a('')

    a('## 2. 직전 세션 인수인계 (현행 절만)')
    a('')
    if cur:
        a('> 🔴 **현행 시작점** = `%s`' % cur['title'])
        a('> · 좌표 = `%s`' % cur['where'])
        a('> · 판정법 = 「여기서 시작한다」가 **취소선이 아니고** 날짜가 최신인 절.')
        a('>   ⚠️ `99_NEXT` 는 이 절이 **적층**된다 — 과거 절은 취소선으로 승계 표시된다.')
        a('')
        if subs:
            a('| 항목 | 좌표 |')
            a('|---|---|')
            for s in subs:
                a('| %s | `%s` |' % (s['title'], s['where']))
    else:
        a('⚪ 현행 인수인계 절을 찾지 못했다.')
    a('')

    a('## 3. dbt 미결조치 — 열린 절 (정본 = `50_dbt_파이프라인_미결조치`)')
    a('')
    a('> 판정 = 절 제목 선두 이모지가 🔴/🟠/🟡. 🟢/✅ 는 제외한다.')
    a('')
    if d50:
        a('| 절 | 좌표 |')
        a('|---|---|')
        for s in d50:
            a('| %s | `%s` |' % (s['title'], s['where']))
    else:
        a('✅ 열린 절 0건.')
    a('')

    a('## 4. 최근 세션 (정본 = 원장 §1 상태 대시보드)')
    a('')
    a('| 라벨 | 표제 | 상태 | 좌표 |')
    a('|---|---|---|---|')
    for r in recent:
        a('| `%s` | %s | %s | `%s` |' % (r['label'], r['head'], r['state'], r['where']))
    a('')

    a('## 5. 문서군 규모 · 독해 예산 (실측)')
    a('')
    a('| 문서 | 조각 | 총 바이트 | max B | 여유 B |')
    a('|---|---|---|---|---|')
    for f in inv['families']:
        a('| `%s` | %d | %s | %s | %s%s |' % (
            f['stem'], f['chunks'], format(f['bytes'], ','),
            format(f['max_bytes'], ','), format(f['free'], ','),
            ' 🟠' if f['tight'] else ''))
    for s in inv['singles']:
        a('| `%s` | — | %s | %s | %s%s |' % (
            s['stem'], format(s['bytes'], ','), format(s['bytes'], ','),
            format(s['free'], ','), ' 🟠' if s['tight'] else ''))
    a('')
    tot = sum(f['chars'] for f in inv['families']) + \
        sum(s['chars'] for s in inv['singles'])
    a('> 전 문서군 = **%s 자**. 🔴 **전량 독해는 물리적으로 불가능하다** ⇒' % format(tot, ','))
    a('> 이 브리핑 + 지침만 읽고 착수하고, 필요한 조각을 좌표로 골라 읽는다.')
    a('')

    a('## 6. 게이트 상태')
    a('')
    if gates:
        a('| 게이트 | 판정 | 결론 |')
        a('|---|---|---|')
        for g in gates:
            a('| `%s` | %s | %s |' % (g['name'], g['mark'], g['verdict']))
    else:
        a('⚪ `--no-gates` 로 생략됐다. 착수 전 직접 실행하라.')
    a('')
    a('> 🔴 **게이트 전수 PASS 는 「지침 준수」의 증거가 아니다**(`R3-9`).')
    a('> 완료 보고 전에 **게이트가 보지 않는 축** ㉠~㉥ 를 자문한다.')
    a('')
    a('| 손으로 적은 조각 수 stale | %d건 |' % len(stale))
    a('|---|---|')
    for s in stale[:10]:
        a('| `%s:%d` %s | 기재 %d ↔ 실측 %d |' %
          (s['file'], s['line'], s['doc'], s['written'], s['actual']))
    a('')
    a('---')
    a('')
    a('> 🔴 **재생성** = `python3 scripts/session_brief.py --write`')
    a('> 🔴 **이 파일을 손으로 고치지 마라** — 다음 생성에서 사라진다.')
    a('')
    a('_Co-authored with CoCo_')
    return '\n'.join(L) + '\n', {'tasks': len(tasks), 'd50': len(d50),
                                 'subs': len(subs), 'stale': len(stale),
                                 'gates': gates}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true', help='20_issue/00_BRIEF.md 를 생성')
    ap.add_argument('--no-gates', action='store_true', help='게이트 실행 생략')
    a = ap.parse_args()

    text, meta = build(with_gates=not a.no_gates)
    nb = len(text.encode('utf-8'))

    if not a.write:
        print(text)
        print('── 생성 규모: %s B / %s 자 (상한 %s B)' %
              (format(nb, ','), format(len(text), ','), format(MAX_BRIEF_BYTES, ',')))
        return 0

    if nb > MAX_BRIEF_BYTES:
        print('🔴 %s B > 상한 %s B — 항목 축약 길이를 줄여라(쓰지 않았다).'
              % (format(nb, ','), format(MAX_BRIEF_BYTES, ',')))
        return 1
    with io.open(BRIEF, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)
    print('🟢 %s 생성 — %s B / %s 자 (여유 %s B)' %
          (os.path.relpath(BRIEF, ROOT), format(nb, ','), format(len(text), ','),
           format(MAX_BRIEF_BYTES - nb, ',')))
    print('   열린 착수표 %d · 문서50 열린 절 %d · 인수인계 항목 %d · stale %d'
          % (meta['tasks'], meta['d50'], meta['subs'], meta['stale']))
    print('   이어서: python3 scripts/line_len.py 20_issue/00_BRIEF.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())

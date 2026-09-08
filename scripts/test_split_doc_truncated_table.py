#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 게이트5b(절단 표 · 파이프 결손) 판정 함수의 음성 테스트 — D3 실사고 재현을 포함한다.
# Co-authored with CoCo
"""test_split_doc_truncated_table.py — 게이트5b 절단 표 검출 음성 테스트 (6축)

[2026-09-08 O144 신설 · `R3-2` 집행 · 후속과제 **후-3** 의 검증 장치]

🔴 왜 이 테스트가 필요한가 — **이 축은 「정상 입력만으로는 0건」이다.**
--------------------------------------------------------------------------
O143 이 D3 으로 확정한 실사고:
  `99_NEXT_SESSION-028.md` 에 **헤더 1행 + `|` 한 글자**로 끝난 표가 있었는데
  게이트5(`col_violations`)가 **원문 0 · 조각 0** 으로 통과시켰다.
🔴 원인 = `col_violations` 는 「`|`·`-`·`:` 를 지우면 빈 줄」을 **구분행으로 보고 continue** 한다.
   `|` 한 글자도 그 조건을 만족하므로 **결손이 구분행으로 위장**된다.
⇒ 이 파일은 그 입력을 **주입**해서 새 판정 함수가 실제로 **검출하는지**를 단정한다.
   🔴 「축을 넣었다」는 것과 「축이 잡는다」는 것은 다르다.

🟢 오탐 가드가 판정의 절반이다 — 정상 표·정렬 구분행·이스케이프 파이프·코드스팬을
   **위반으로 세면** 이 게이트는 모든 유지 연산을 막는다(게이트가 곧 장애가 된다).

사용
--------------------------------------------------------------------------
    python3 scripts/test_split_doc_truncated_table.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import split_doc as S  # noqa: E402

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


def v(text):
    return S.truncated_table_violations(text)


def main():
    print('[test_split_doc_truncated_table]')

    # ── 축1: 🔴🔴 D3 실사고 재현 ────────────────────────────────────────
    print('\n축1 — D3 재현: 헤더 1행 + `|` 한 글자')
    d3 = '\n'.join([
        '### 절 제목',
        '',
        '| 항목 | 성격 | 좌표 |',
        '|',
        '## 다음 절',
    ])
    got = v(d3)
    check(len(got) == 2, '축1-a',
          '위반 2건을 낸다(퇴화행 + 절단 표) · 실제 %d건' % len(got))
    check(any('퇴화행' in g for g in got), '축1-b',
          '`|` 한 글자를 **퇴화행**으로 잡는다 — 게이트5 가 구분행으로 오인했던 지점')
    check(any('절단 표' in g for g in got), '축1-c',
          '헤더만 있고 구분행·본문행이 없는 표를 **절단 표**로 잡는다')
    check(any('4행' in g for g in got), '축1-d',
          '퇴화행의 **행 번호(4행)** 를 보고한다 — 좌표 없는 보고는 조치가 불가능하다')

    # 🔴 대조군(재현율 증명) — 종전 판정식은 이 입력에서 0건이어야 한다.
    print('     ↳ 대조군: 종전 판정식(게이트5 규칙)은 같은 입력에서 0건이어야 한다')
    legacy = []
    hdr_n = None
    for n, line in enumerate(d3.split('\n'), 1):
        s = line.strip()
        if not s.startswith('|'):
            hdr_n = None
            continue
        if set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
            continue
        got_cols = s.count('|') - 1
        if hdr_n is None:
            hdr_n = got_cols
            continue
        if got_cols != hdr_n:
            legacy.append(n)
    check(len(legacy) == 0, '축1-e',
          '🔴 종전 규칙은 **0건** = 이 축이 없으면 D3 은 영구히 숨는다 · 실제 %d건' % len(legacy))

    # ── 축2: 🟢 오탐 가드 — 정상 표 ──────────────────────────────────────
    print('\n축2 — 오탐 가드: 정상 표는 위반 0')
    ok = '\n'.join([
        '| 순 | 작업 | 정지점 |',
        '|---|---|---|',
        '| ① | 배포 | 없음 |',
        '| ② | 검증 | 없음 |',
    ])
    check(v(ok) == [], '축2-a', '헤더 + 구분행 + 본문 2행 = 위반 0')
    aligned = '\n'.join([
        '| 순 | 작업 |',
        '|:--|--:|',
        '| ① | 배포 |',
    ])
    check(v(aligned) == [], '축2-b', '정렬 구분행(`:--`·`--:`)을 퇴화행으로 세지 않는다')
    check(v('| 순 | 작업 |\n| --- | --- |\n| ① | 배포 |') == [], '축2-c',
          '공백 있는 구분행(`| --- | --- |`)도 정상')

    # ── 축3: 🟢 오탐 가드 — 본문에 파이프·코드스팬이 있는 표 ──────────────
    print('\n축3 — 오탐 가드: 본문에 파이프·코드스팬이 있어도 정상')
    tricky = '\n'.join([
        '| 항목 | 설명 |',
        '|---|---|',
        '| 후-3 | 단일 파이프(`\\|`) 잔존 행을 검출한다 |',
        '| 후-4 | `a | b` 처럼 코드스팬 안에 파이프가 있다 |',
    ])
    check(v(tricky) == [], '축3-a',
          '이스케이프 `\\|` · 코드스팬 내 파이프를 위반으로 세지 않는다')

    # ── 축4: 구분행 없이 본문만 있는 표(느슨한 표기)는 허용 ────────────────
    print('\n축4 — 구분행이 없어도 본문행이 있으면 절단이 아니다')
    no_sep = '| 항목 | 값 |\n| 후-3 | 완료 |'
    check(v(no_sep) == [], '축4-a',
          '헤더 + 본문(구분행 없음)은 렌더가 깨질 뿐 **내용 소실이 아니다** ⇒ 통과')

    # ── 축5: 퇴화행 변형 — `||`·`| |` 는 잡고 `|--|` 는 통과 ───────────────
    print('\n축5 — 퇴화행 변형 판정')
    check(len(v('| a | b |\n||\n')) >= 1, '축5-a',
          '`||`(하이픈 없음)을 퇴화행으로 잡는다')
    check(len(v('| a | b |\n| |\n')) >= 1, '축5-b',
          '`| |`(빈 셀만 · 하이픈 없음)을 퇴화행으로 잡는다')
    check(v('| a | b |\n|--|--|\n| 1 | 2 |') == [], '축5-c',
          '`|--|--|` 는 정당한 구분행이므로 통과')
    check(len(v('| a | b |\n|-\n')) >= 1, '축5-d',
          '`|-`(하이픈은 있지만 파이프 1개)는 퇴화행 — 두 조건을 **모두** 요구한다')

    # ── 축6: 표가 여러 개일 때 상태가 초기화된다 ──────────────────────────
    print('\n축6 — 표가 여러 개일 때 상태 초기화')
    two = '\n'.join([
        '| a | b |',
        '|---|---|',
        '| 1 | 2 |',
        '',
        '| c | d |',
        '|',
        '텍스트',
    ])
    got2 = v(two)
    check(len(got2) == 2, '축6-a',
          '앞 표는 통과하고 뒤 표만 2건 위반 · 실제 %d건' % len(got2))
    check(all('5행' in g or '6행' in g for g in got2), '축6-b',
          '위반 좌표가 **뒤 표(5·6행)** 에만 잡힌다 — 앞 표로 번지지 않는다')

    print('\n[결과] 단정 %d건 · 실패 %d건' % (N[0], len(FAILS)))
    if FAILS:
        for f in FAILS:
            print('  🔴 %s' % f)
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 6축 %d단정 전건 통과' % N[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())

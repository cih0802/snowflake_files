#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O169 개명 축1 B군 집행 — `DIM_MEMBER_CURRENT` 68건의 「기록」 축 병기.

🔴🔴 이것은 **기계 치환기가 아니다.** 원문 문자를 하나도 지우지 않고
   병기만 **덧붙인다**. 이유 = 이 항목은 개명이 아니라 **객체 소멸**이고
   (라이브 실측 2026-09-16: `DIM_MEMBER_CURRENT` 부재 · `DIM_MEMBER` 1,785,299행 =
   회원 1행 grain · 팬아웃 0 · 상태 이력은 `DIM_MEMBER_STATUS_HISTORY` 8,069,279행),
   기계 치환하면 *"DIM_MEMBER 는 SCD2라 팬아웃하니 DIM_MEMBER 를 쓰라"* 같은
   자기모순이 생긴다(게이트 `RENAMES` 주석 O166-B 가 같은 경고를 한다).

🟢 분모는 게이트의 판정 함수에서 받아온다(J8 「같은 것을 다르게 재지 마라」).
🟢 병기 어휘는 창작하지 않고 게이트의 `NEAR`/`LINE_OK` 를 그대로 쓴다
   — 창작하면 게이트가 그 병기를 인정하지 않는다.

🔴 「지시」 축(독자·도구를 그 객체로 보내는 줄)은 이 도구가 **건드리지 않는다** —
   `EXCLUDE` 에 좌표로 등재하고 사람이 손으로 가른다.

음성 테스트 = `scripts/test_o169_axis1_biwi.py`
"""
import argparse
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rename_stale_gate as G  # noqa: E402
import snapshot_util  # noqa: E402

TOKEN = 'DIM_MEMBER_CURRENT'
MARK = '구 '          # `NEAR` 의 첫 항목 — 병기의 정형

#: 🔴 「지시」 축 = 독자·도구를 그 객체로 보내는 줄. 기계 병기 대상이 아니다.
#:   판정 근거는 `_o169_evidence.md` §E2 에 줄마다 적었다.
EXCLUDE = {
    ('02_GN_DW_building/06_RUNBOOK.md', 736),                        # 「분석가 진입점」
    ('20_issue/30_설계_의사결정_조각/30_설계_의사결정-005.md', 150),  # 「개명 시 소비처 전수 grep」
    ('20_issue/30_설계_의사결정_조각/30_설계_의사결정-009.md', 62),   # 「라벨이 이미 있는 축」
    ('10_dbt_pipeline/10_성능검토_정적코드분석_20260716.md', 66),      # 「권고」 = 폐기 대상
    ('10_dbt_pipeline/10_성능검토_정적코드분석_20260716.md', 97),      # 「권고」 = 폐기 대상
    ('scripts/gen_section_assembly.py', 283),                        # O56 판본 인용 = 원문 보존
}

#: 줄 말미 병기 문안. `LINE_OK` 의 「객체 소멸」·「라이브 부재」를 쓴다(창작 금지).
TAIL = (' 🔴 **[2026-09-16 O169 병기]** 위 인용 안의 `DIM_MEMBER_CURRENT` 는'
        ' **구 이름이고 객체 소멸**이다(라이브 부재 실측) — 현행 = `GOLD.DIM_MEMBER`'
        '(1,785,299행 · 회원 1행 grain · 팬아웃 0) · 상태 이력은'
        ' `GOLD.DIM_MEMBER_STATUS_HISTORY`(8,069,279행).'
        ' 🔴 인용문은 원문 보존이므로 안을 고치지 않는다(`R2-8-2`).')

#: 식별자 파손 탐지 — 이름·점수식 **안**에 병기가 끼었는가.
CORRUPT_RX = re.compile(r'[0-9A-Za-z_.]구 ')


def quote_spans(line):
    """`*"…"*` 인용 구간의 (시작, 끝) 목록.

    🔴 왜 필요한가 — 인용문 **내부**에 「구 」를 끼우면 그것은 병기가 아니라
      **인용 개변**이다(`R2-8-2` 「무변경 이관은 기계 대조로만 주장한다」).
      ⇒ 그 줄은 원문을 한 글자도 건드리지 않고 **줄 말미 병기**로 가른다.
    """
    spans = []
    i = 0
    while True:
        a = line.find('*"', i)
        if a < 0:
            break
        b = line.find('"*', a + 2)
        if b < 0:
            break
        spans.append((a, b + 2))
        i = b + 2
    return spans


def insert_point(line, start):
    """삽입점 = 그 이름을 감싼 **코드 스팬·점수식의 머리**.

    🔴 왜 필요한가(예행에서 적발) — `m.start()` 에 그대로 넣으면
      `` `GOLD.DIM_MEMBER_CURRENT` `` 가 `` `GOLD.구 DIM_MEMBER_CURRENT` `` 가 되어
      **식별자 내부를 깨뜨린다**. 병기는 이름 밖에 붙어야 한다.
    """
    i = start
    while i > 0 and (line[i - 1].isalnum() or line[i - 1] in '_.'):
        i -= 1
    if i > 0 and line[i - 1] == '`':
        i -= 1
    return i


def annotate(line):
    """자격 없는 `TOKEN` 출현을 병기한다. 이미 자격 있으면 무변경.

    축A(기본) = 이름 **밖**에 「구 」 삽입(원문 문자 무삭제).
    축B(인용 내부) = 원문 **무변경** + 줄 말미 `TAIL` 병기.
    """
    out = line
    guard = 0
    while True:
        guard += 1
        if guard > 20:
            raise RuntimeError('병기 삽입이 수렴하지 않는다: %r' % line[:120])
        changed = False
        for m in G.RX.finditer(out):
            if m.group(1) != TOKEN:
                continue
            if G.qualified(out, m.start(), m.group(1)):
                continue
            if any(a <= m.start() < b for a, b in quote_spans(out)):
                return out.rstrip() + TAIL   # 축B — 줄 전체가 자격을 얻으므로 즉시 종료
            ins = insert_point(out, m.start())
            out = out[:ins] + MARK + out[ins:]
            changed = True
            break
        if not changed:
            return out


def verify(old, new):
    """사후 단정 4축. 위반이면 사유 문자열, 통과면 None."""
    if new == old:
        return None
    left = [x for x in G.RX.finditer(new)
            if x.group(1) == TOKEN and not G.qualified(new, x.start(), x.group(1))]
    if left:
        return '잔여 미자격 %d건' % len(left)
    if CORRUPT_RX.search(new):
        return '식별자 파손(이름 안에 병기 삽입)'
    if len(new) > 2000:
        return '한 줄 2000자 초과(%d자 · R1-5-1)' % len(new)
    if new.endswith(TAIL):
        if new[:-len(TAIL)] != old.rstrip():
            return '축B 원문 개변'
    else:
        if new.replace(MARK, '') != old.replace(MARK, ''):
            return '축A 원문 개변'
    return None


def targets():
    """게이트 판정 함수에서 축1 `TOKEN` 좌표를 받아 파일별로 모은다."""
    hits, ok, scanned = G.scan()
    live = [h for h in hits['LIVE'] if h[2] == TOKEN]
    by_file = {}
    for rel, lineno, _ in live:
        by_file.setdefault(rel, set()).add(lineno)
    return by_file, len(live), ok, scanned


def main():
    ap = argparse.ArgumentParser(prog='_o169_axis1_biwi.py')
    ap.add_argument('--apply', action='store_true', help='실제로 쓴다(기본 = 예행)')
    ap.add_argument('--label', default='O169')
    a = ap.parse_args()

    by_file, n_live, ok, scanned = targets()
    print('스캔 %d파일 · 면제(병기) %d · 축1 %s = %d건 / %d파일'
          % (scanned, ok, TOKEN, n_live, len(by_file)))

    skipped = []
    axis_a = axis_b = files = 0
    fails = []
    for rel in sorted(by_file):
        path = os.path.join(G.ROOT, rel)
        body = io.open(path, encoding='utf-8').read().split('\n')
        todo = []
        for lineno in sorted(by_file[rel]):
            if (rel, lineno) in EXCLUDE:
                skipped.append((rel, lineno))
                continue
            old = body[lineno - 1]
            new = annotate(old)
            if new == old:
                continue
            bad = verify(old, new)
            if bad:
                fails.append((rel, lineno, bad))
                continue
            todo.append((lineno, new))
            if new.endswith(TAIL):
                axis_b += 1
            else:
                axis_a += 1
        if not todo:
            continue
        files += 1
        print('  %s — %d줄' % (rel, len(todo)))
        if not a.apply:
            continue
        snapshot_util.snapshot(path, 'o169-axis1-biwi', label=a.label, quiet=True)
        for lineno, new in todo:
            body[lineno - 1] = new
        io.open(path, 'w', encoding='utf-8').write('\n'.join(body))

    print('')
    print('병기 %d줄 / %d파일 (축A 「구 」삽입 %d · 축B 말미병기 %d)'
          % (axis_a + axis_b, files, axis_a, axis_b))
    print('제외(지시 축) %d줄' % len(skipped))
    for rel, lineno in sorted(skipped):
        print('  제외 %s:%d' % (rel, lineno))
    print('사후단정 위반 %d건' % len(fails))
    for rel, lineno, why in fails:
        print('  🔴 %s:%d — %s' % (rel, lineno, why))
    print('')
    print('모드 = %s' % ('APPLY' if a.apply else '예행(--apply 로 집행)'))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())

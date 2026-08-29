#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix_stale_counts.py — 문서에 손으로 적힌 「조각 수」를 **실측 포인터로 교체**한다.

[2026-08-28 O106 신설 · `doc_census.py` 의 짝]

🔴 왜 「올바른 수로 고치지」 않는가
--------------------------------------------------------------------------
이 워크스페이스는 그 방법을 **두 번 시도해서 두 번 실패했다**:
  · O83-H 가 분할표 **8행**을 올바른 수로 교정하고 *"다음 세션엔 또 어긋난다"* 를 적었다.
  · O90 이 유형등재표 **4건**을 올바른 수로 교정하고 *"인용하지 말고 실측하라"* 를 적었다.
  ⇒ O106 착수 시점 실측 = **다시 17건 stale.** 교정은 stale 을 **지연**시킬 뿐 없애지 못한다.

🟢 그래서 이 도구는 **숫자를 지우고 「재는 방법」을 남긴다.**
   근거 = 원장 §0 자신의 문장 *"값이 아니라 재는 방법이 정본이다"*.
   숫자가 없으면 stale 이 될 자리가 없다 ⇒ `doc_census.py` 가 영구히 0건을 유지한다.

⚠️ 이것은 `R2-8`(정본 이관) 대상이 **아니다** — 내용을 다른 문서로 옮기는 것이 아니고
   **틀린 수치를 제거**하는 시정이다. 판정·근거 문장은 건드리지 않는다.
   🔴 「분할 전 줄/바이트」 열은 **분할 당시 기록이라 의도적 고정**이므로 제외한다
   (원장 §0 이 명시: *"의도적으로 고정이다 — 그때 무엇을 쪼갰나의 기록"*).

사용
--------------------------------------------------------------------------
    python3 scripts/fix_stale_counts.py            # dry-run (기본)
    python3 scripts/fix_stale_counts.py --apply     # 실제로 쓴다(스냅샷 자동)

이어서 실행한다
    python3 scripts/split_doc.py 20_issue/00_INDEX_이슈원장.md --republish
    python3 scripts/doc_census.py                  # stale 0 확인
    python3 scripts/index_row_gate.py              # 행 키 유실 0 확인
"""

import argparse
import io
import os
import re
import sys

# 🔴 [2026-08-28 O110 · `R1-7-10`] 스냅샷은 이 헬퍼만 경유한다(덮어쓰기 금지 · 라벨 인자화).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from snapshot_util import (add_label_arg, resolve_label,  # noqa: E402
                          snapshot_content)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PTR = '`doc_census.py`'

# ── 교체 규칙 = (설명, 정규식, 치환) ─────────────────────────────────────
#   🔴 규칙은 **좁게** 쓴다. 넓은 정규식은 「분할 전 줄/바이트」 같은 고정 기록을
#     함께 지운다 ⇒ 그것은 `R2-8-3`(되돌릴 수 없다) 위반이다.
RULES = [
    # `-001` ~ `-004` (4개)   →   `-001` ~ 끝 (수 = doc_census.py)
    ('범위+개수', re.compile(r'`-001`\s*~\s*`-\d+`\s*\((\d+)개([^)]*)\)'),
     lambda m: '`-001` ~ 끝 (수 = %s%s)' % (PTR, m.group(2))),
    # 허브 + 조각 `-001`~`-014` (로)   →   허브 + 형제 조각(으로)
    #   🔴 뒤따르는 「로」를 함께 먹어 「조각 로 분할됐다」 같은 비문을 막는다.
    ('허브+범위', re.compile(r'허브\s*\+\s*(형제\s*)?조각\s*`-001`\s*~\s*`-\d+`(\s*로)?'),
     lambda m: '허브 + %s조각%s' % (m.group(1) or '', '으로' if m.group(2) else '')),
    # 조각 5개(최대 **29,677B**)   →   조각(수·최대크기 = …)
    ('조각N개(최대', re.compile(r'조각\s*(\d+)개\(최대\s*\*{0,2}[\d,]+B\*{0,2}\)'),
     lambda m: '조각(수·최대크기 = %s)' % PTR),
    # 조각 **26개**로 분할됐다   →   조각으로 분할됐다(수 = …)
    ('조각N개로', re.compile(r'조각\s*\*{0,2}(\d+)개\*{0,2}로\s*분할됐다'),
     lambda m: '조각으로 분할됐다(수 = %s)' % PTR),
    # 폴더 `01_세션이력_조각/` 31조각   →   폴더 `…/` (수 = …)
    ('폴더N조각', re.compile(r'(폴더\s*`[^`]+`)\s*(\d+)조각'),
     lambda m: '%s (수 = %s)' % (m.group(1), PTR)),
    # 조각 5 · `--rebalance`   →   조각 수 = `doc_census.py` · `--rebalance`
    ('조각N·', re.compile(r'조각\s+(\d+)\s*·'),
     lambda m: '조각 수 = %s ·' % PTR),
]

# 대상 파일 — `doc_census.COUNT_SOURCES` 와 같은 분모여야 한다.
#
# 🔴🔴 [2026-08-28 O107-D 자기비판으로 적발] 종전에는 **`00_INDEX` 조각 경로 7개를
#   하드코딩**했고, 그 목록이 **이미 stale** 이었다(실제 조각은 8개인데 `-008` 이 없어
#   그 조각의 stale 수치는 **검사 밖**이었다). 이것은 이 도구가 막으려던 실패
#   (「손으로 적은 수는 반드시 낡는다」)를 도구 자신이 갖고 있던 경우다(`P106`).
#   🔴 게다가 조각을 **폴더로 이전**하면 이 경로 7개가 전부 부재가 되어 도구가
#   **조용히 0건 처리**한다(경로 부재를 건너뛰기 때문이다).
# ⇒ **조각 경로는 적지 않고 허브만 적는다.** 조각은 `doc_census` 가
#   허브의 `SPLIT-OUTDIR` 마커를 보고 확장한다(형제·폴더 어느 쪽이든 자동 추종).
HUB_SOURCES = [
    '20_issue/00_INDEX_이슈원장.md',
    # 🆕 🔴 [2026-08-29 O112-B 자기시정] O112 가 이 문서를 **허브+조각으로 분할**했는데
    #   `FLAT_SOURCES` 에 남겨 둬 이 도구가 **허브만 보고 본문(조각)을 건너뛰고 있었다**.
    #   ⇒ 같은 세션이 `clause_order_gate`(조문 0개로 침묵)에서 지적한 **분모 파괴와 같은 축**이다.
    #   🔴 교훈 = **문서를 쪼개면 「그 문서를 읽는 도구」 전부의 분모를 점검하라**(분모 4곳으로 끝나지 않는다).
    '00_guides/01_문서분할_규약.md',
]
FLAT_SOURCES = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '.snowflake/cortex/skills/init_ihcho/SKILL.md',
]


def _targets():
    """허브는 조각으로 확장하고, 미분할 문서는 그대로 쓴다(정본 = 허브 마커)."""
    import doc_census as C
    out = []
    for hub in HUB_SOURCES:
        where = dict(C.FAMILIES).get(hub, 'sibling')
        chunks = [os.path.relpath(p, ROOT) for p in C.chunk_paths(hub, where)]
        out.extend(chunks if chunks else [hub])
    out.extend(FLAT_SOURCES)
    return out


TARGETS = _targets()

# 🔴 이 문구가 줄에 있으면 **건드리지 않는다** — 분할 당시 고정 기록이다.
SKIP_LINE = ('분할 전', '원문 줄', '구 행범위', 'presplit')

# 🔴🔴 [O106 자기시정] **문서 stem 가드** — 이것 없이 돌렸더니 오탐이 났다.
#   `01_문서분할_규약.md:118` 의 *"꼬리가 차면 새 조각 **1개**로 끝난다(O(1))"* 는
#   **특정 문서의 조각 수가 아니라 append형 동작의 일반 서술**인데 규칙이 물었다.
#   그대로 적용하면 조문의 뜻이 바뀐다 ⇒ `R2-8-3`(되돌릴 수 없다) 위반이다.
#   ⇒ **분할 문서 이름이 그 줄 또는 직전 2줄에 있을 때만** 치환한다.
#     (`init_ihcho:150` 처럼 문서명과 수가 다른 줄에 있는 형태를 덮기 위해 이월을 둔다.)
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from doc_census import FAMILIES as _FAM
    STEMS = [os.path.splitext(os.path.basename(h))[0] for h, _w in _FAM]
    STEMS += [w for _h, w in _FAM if w != 'sibling']
except Exception:                                        # pragma: no cover
    STEMS = []


def read_text(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def write_text(p, s):
    with io.open(p, 'w', encoding='utf-8', newline='') as fh:
        fh.write(s)


def fix_line(line, in_scope):
    """한 줄에 규칙을 적용. `in_scope` = 분할 문서 이름이 유효 범위에 있는가."""
    if any(t in line for t in SKIP_LINE) or not in_scope:
        return line, []
    applied = []
    for name, rx, rep in RULES:
        new = rx.sub(rep, line)
        if new != line:
            applied.append(name)
            line = new
    return line, applied


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='실제로 쓴다(기본은 dry-run)')
    add_label_arg(ap)
    a = ap.parse_args()
    a.label = resolve_label(a.label)

    total, touched = 0, []
    for rel in TARGETS:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            print('⚪ 부재 건너뜀: %s' % rel)
            continue
        text = read_text(p)
        lines = text.split('\n')
        out, hits = [], []
        scope_age = 99            # 분할 문서 이름이 마지막으로 나온 뒤 몇 줄 지났는가
        for i, line in enumerate(lines, 1):
            if any(s in line for s in STEMS):
                scope_age = 0
            else:
                scope_age += 1
            new, applied = fix_line(line, scope_age <= 2)
            if applied:
                hits.append((i, applied, line.strip()[:88], new.strip()[:88]))
            out.append(new)
        if not hits:
            continue
        new_text = '\n'.join(out)
        total += len(hits)
        touched.append((rel, p, text, new_text, hits))

    print('[stale 수치 제거] 대상 %d파일 · 치환 %d곳' % (len(touched), total))
    for rel, _p, old, new, hits in touched:
        print('\n── %s  (%s B → %s B)' % (rel, format(len(old.encode()), ','),
                                          format(len(new.encode()), ',')))
        for ln, applied, before, after in hits:
            print('  %5d [%s]' % (ln, ','.join(applied)))
            print('      - %s' % before)
            print('      + %s' % after)

    if not touched:
        print('✅ 치환 대상 0곳 — 이미 포인터화돼 있다')
        return 0

    if not a.apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    # `R1-7-6`: `head == live` 라 redo 경로가 없다 ⇒ 스냅샷이 유일한 되돌리기 수단이다.
    arch = os.path.join(ROOT, '_archive')
    if not os.path.isdir(arch):
        os.makedirs(arch)
    for rel, p, old, new, _h in touched:
        # 🔴 [2026-08-28 O110 · `R1-7-10`] 헬퍼 경유 — 라벨 하드코딩(`O106`) 제거 ·
        #   같은 파일을 두 번 고쳐도 최초 스냅샷을 덮지 않는다(O109 D2).
        snapshot_content(p, 'prefix', old, label=a.label, archive=arch)
        write_text(p, new)
        print('🟢 %s' % rel)

    print('\n🟢 완료. 이어서 실행하라:')
    print('   python3 scripts/split_doc.py 20_issue/00_INDEX_이슈원장.md --republish')
    print('   python3 scripts/doc_census.py          # stale 0 확인')
    print('   python3 scripts/index_row_gate.py      # 행 키 유실 0 확인')
    print('   python3 scripts/line_len.py <바뀐 파일들>')
    return 0


if __name__ == '__main__':
    sys.exit(main())

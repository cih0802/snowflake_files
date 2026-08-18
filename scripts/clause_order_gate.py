#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""조문 번호 순서 게이트 (2026-08-18 O83-H 신설)

🔴 **왜 필요한가**: O83-H 자기검증에서 `R1-7-8` 이 `R1-7-7` **앞**에, `R1-6-18` 이 `R1-6-17`
   **앞**에 놓여 있었고, 규약 전체가 `1,2 → 10~18 → 3~9` 였다. 신설 조문을 **문서 중간에**
   끼워넣은 결과다. 기존 게이트 6종은 전부 🟢 였다 — **아무도 이 축을 보지 않았다.**

🔴 왜 결함인가(단순 미관이 아니다):
  · 조문은 `R1-6-N` 으로 **번호 인용**된다. 번호와 문서 순서가 어긋나면 인용을 따라가는
    세션이 조문을 **못 찾거나 다른 조문을 읽는다**.
  · 기초 조문이 뒤로 밀린다 — 규약에서 `R1-6-3`(무변경 정의) ~ `R1-6-9`(읽는 쪽 규약)가
    **문서 맨 끝**에 있었다. 앞부분만 읽고 착수하면 정의를 모른 채 도구를 쓴다.
  · 🔴 **중간 삽입은 앵커 사고의 신호다** — 실제로 삽입 과정에서 `R1-7-7` 제목줄이 덮여
    지워졌다(같은 세션 5회 재발).

판정 3축:
  축1 **역전**(blocking) — 같은 계열 안에서 번호가 감소하면 FAIL.
  축2 **중복 정의**(blocking) — 같은 번호가 두 번 정의되면 FAIL.
  축3 **결번**(경고) — 은퇴·철회일 수 있으므로 🟠 로 보고만 한다.

접미 조문(`R1-3-7-a`)은 **부모 번호와 같은 자리**로 취급하고, 부모 직후에 와야 한다.

사용:
  python3 scripts/clause_order_gate.py
  python3 scripts/clause_order_gate.py --self-check
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 🔴 조문을 「정의」하는 문서만 넣는다. 다른 문서는 `R1-6-N` 을 **참조**만 하므로 분모가 아니다.
#   새 조문 문서를 만들면 여기에 손으로 편입한다(지침 `R1-6-18` ④ 와 같은 축).
DOCS = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '00_guides/01_문서분할_규약.md',
]

# 조문 정의 줄 = 불릿 + (선택)🆕 + **R<계열>-<번호>[-<접미>]
#   🔴 본문 중간의 인용(`R1-6-17` 처럼 백틱)은 매칭되지 않는다 — 정의만 센다.
DEF_RX = re.compile(
    r'^\s*\*\s*(?:🆕\s*)?\*\*(R\d+(?:-\d+)+)(-[A-Za-z0-9]+)?\b'
)


def collect(path):
    """문서에서 (줄번호, 계열, 번호, 접미, 원문라벨) 목록을 뽑는다."""
    text = path.read_text(encoding='utf-8')
    out = []
    for i, line in enumerate(text.split('\n'), 1):
        m = DEF_RX.match(line)
        if not m:
            continue
        key = m.group(1)
        suffix = (m.group(2) or '')[1:]
        family, num = key.rsplit('-', 1)
        out.append((i, family, int(num), suffix, key + (('-' + suffix) if suffix else '')))
    return out


def judge(items):
    """축1 역전 · 축2 중복 · 축3 결번을 판정한다."""
    fails, warns = [], []
    fams = {}
    for ln, fam, num, suf, label in items:
        fams.setdefault(fam, []).append((ln, num, suf, label))

    for fam in sorted(fams):
        seq = fams[fam]
        # 축1 — 역전
        for k in range(1, len(seq)):
            prev, cur = seq[k - 1], seq[k]
            if cur[1] < prev[1]:
                fails.append(
                    '역전 %s: %s(%d행) 가 %s(%d행) **앞**에 있다 — 번호 순서 말미로 옮겨라'
                    % (fam, cur[3], cur[0], prev[3], prev[0]))
        # 축2 — 중복 정의(접미가 다르면 중복이 아니다)
        seen = {}
        for ln, num, suf, label in seq:
            sig = (num, suf)
            if sig in seen:
                fails.append('중복 정의 %s: %s 가 %d행·%d행 두 번 정의됐다'
                             % (fam, label, seen[sig], ln))
            else:
                seen[sig] = ln
        # 축3 — 결번(경고)
        nums = sorted({n for _, n, s, _ in seq if not s})
        if nums:
            gaps = [x for x in range(min(nums), max(nums) + 1) if x not in nums]
            if gaps:
                warns.append('결번 %s: %s (은퇴·철회면 정상 · 아니면 번호를 메워라)'
                             % (fam, gaps))
    return fails, warns


def main(argv):
    all_items, missing = [], []
    per_doc = {}
    for rel in DOCS:
        p = ROOT / rel
        if not p.exists():
            missing.append(rel)
            continue
        items = collect(p)
        per_doc[rel] = items
        all_items.append((rel, items))

    fails, warns = [], []
    for rel in missing:
        fails.append('분모 문서가 없다: %s' % rel)

    total = 0
    print('[조문 번호 순서 게이트] 문서 %d종' % len(per_doc))
    for rel, items in all_items:
        f, w = judge(items)
        fails += ['%s — %s' % (rel, x) for x in f]
        warns += ['%s — %s' % (rel, x) for x in w]
        total += len(items)
        fams = sorted({fam for _, fam, _, _, _ in items})
        print('  %s: 조문 %d개 · 계열 %d종 (%s)'
              % (rel, len(items), len(fams), ' · '.join(fams)))

    for w in warns:
        print('  🟠 %s' % w)

    if fails:
        print('\n🔴 FAIL — 조문 순서 위반 %d건' % len(fails))
        for f in fails:
            print('  -', f)
        print('\n🔴 조치: **조문은 번호 순서 말미에 덧붙인다**(지침 `R1-7-8` O83-H 후속).')
        print('   중간 삽입은 그 자체가 앵커 사고의 신호다 — 이동은 줄 인덱스 치환으로 하고')
        print('   **줄 다중집합 일치**로 무변경을 실증한 뒤 제목 게이트를 즉시 돌려라.')
        return 1

    print('\n✅ 게이트 통과 — 조문 %d개 · 역전 0 · 중복 0 (경고 %d건)'
          % (total, len(warns)))
    return 0


def self_check():
    """게이트가 실제로 위반을 잡는지 확인한다(게이트 자체의 침묵 방지)."""
    ok = True

    # ① 역전을 잡아야 한다.
    bad = [(10, 'R1-7', 8, '', 'R1-7-8'), (20, 'R1-7', 7, '', 'R1-7-7')]
    f, _ = judge(bad)
    if not any('역전' in x for x in f):
        print('🔴 self-check 실패 — 역전을 못 잡는다')
        ok = False

    # ② 중복을 잡아야 한다.
    bad = [(10, 'R1-6', 3, '', 'R1-6-3'), (20, 'R1-6', 3, '', 'R1-6-3')]
    f, _ = judge(bad)
    if not any('중복' in x for x in f):
        print('🔴 self-check 실패 — 중복을 못 잡는다')
        ok = False

    # ③ 정상 배열은 통과해야 한다(오탐 방지).
    good = [(10, 'R1-6', 1, '', 'R1-6-1'), (20, 'R1-6', 2, '', 'R1-6-2'),
            (30, 'R1-6', 3, '', 'R1-6-3')]
    f, w = judge(good)
    if f:
        print('🔴 self-check 실패 — 정상 배열을 FAIL 로 오탐한다: %s' % f)
        ok = False

    # ④ 접미 조문은 중복이 아니다(`R1-3-7` + `R1-3-7-a`).
    suf = [(10, 'R1-3', 7, '', 'R1-3-7'), (20, 'R1-3', 7, 'a', 'R1-3-7-a')]
    f, _ = judge(suf)
    if f:
        print('🔴 self-check 실패 — 접미 조문을 중복으로 오탐한다: %s' % f)
        ok = False

    # ⑤ 결번은 경고여야 한다(blocking 이 아니다).
    gap = [(10, 'R2', 1, '', 'R2-1'), (20, 'R2', 3, '', 'R2-3')]
    f, w = judge(gap)
    if f or not w:
        print('🔴 self-check 실패 — 결번 처리가 잘못됐다 (fails=%s warns=%s)' % (f, w))
        ok = False

    # ⑥ 실제 문서에서 조문이 0개로 잡히면 정규식이 죽은 것이다(조용한 침묵 방지).
    for rel in DOCS:
        p = ROOT / rel
        if p.exists() and not collect(p):
            print('🔴 self-check 실패 — %s 에서 조문 0개: 정규식이 죽었다' % rel)
            ok = False

    print('🟢 self-check 통과 — 역전·중복·접미·결번·정규식 5축 확인' if ok
          else '🔴 self-check FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(self_check() if '--self-check' in sys.argv else main(sys.argv[1:]))

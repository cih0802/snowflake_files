#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""split_narrative.py — 조문에서 **경위 서사**를 분리해 사례집으로 무변경 이관한다.

[2026-08-28 O106 신설 · `R2-8` 집행 · `init_ihcho` Step 0.7(O92-C 다이어트) 패턴의 확장]

🔴 왜 필요한가
--------------------------------------------------------------------------
`00_작업지침_세션운영규칙.md` 는 **매 세션 Step 1 에서 반드시 읽는** 문서다.
그런데 본문의 상당 부분이 조문이 아니라 **「왜 이 규칙이 있는가」 사고 경위**다
(O106 실측 = 서사 블록 **14개**). 경위는 **사고를 조사할 때만** 필요하고
조문·판정식은 **매 세션** 필요하다 ⇒ 성격이 다른 둘이 한 파일에 섞여 있다.

🟢 이 분리는 이미 검증된 패턴이다 — O92-C 가 `init_ihcho` Step 0.7 에서
   **조문 9개를 하나도 빼지 않고 경위 서사만** 덜어냈고 가용성 손실이 없었다.
   이 도구는 그 수작업을 **재현 가능한 형태**로 만든 것이다.

🔴🔴 안전 불변식 3종 (전부 blocking)
--------------------------------------------------------------------------
1. **조문 ID 보존** — 이관 전후로 원본의 `R#-#…` 조문 ID **집합이 동일**해야 한다.
   🔴 이것이 없으면 `R1-5-2` 처럼 **조문 자신이 「왜 필요한가」로 시작하는 경우**
     조문이 통째로 사라진다(O106 이 실제로 그 후보를 잡았다).
2. **제목 보존** — `#`~`####` 제목 집합이 동일해야 한다(`doc_heading_gate` 축).
3. **`R2-8-1` 토큰 대조** — 이관한 서사의 수치·ID·백틱 토큰이 목적지에 **전건 실재**.
   1건이라도 부재면 **원본을 건드리지 않는다**.

⚠️ 기본은 dry-run 이다. 쓰려면 `--apply`.
   `R1-7-6`(head == live · redo 없음)에 따라 쓰기 직전 **스냅샷**을 남긴다.

사용
--------------------------------------------------------------------------
    python3 scripts/split_narrative.py                     # dry-run
    python3 scripts/split_narrative.py --apply             # 이관 실행
    python3 scripts/split_narrative.py --src <경로>         # 다른 정본에 적용
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
DEFAULT_SRC = '00_guides/00_작업지침_세션운영규칙.md'
DEFAULT_DST = '20_issue/91_사고사례집.md'

# ── 서사 시작 신호 ─────────────────────────────────────────────────────
#   🔴 문서에 **이미 쓰여 있는 표현**만 쓴다(창작 금지).
#   🆕 🔴 [2026-08-28 O111] **어미 변형 3종을 놓쳤다** — 초판은 리터럴 나열이라
#     `왜 바꿨나`(원본 48행) · `왜 예외가 필요한가`(68행) · `왜 이 규약이 있는가`(163행)
#     가 **하나도 잡히지 않아** dry-run 이 「서사 블록 0개 — 이미 분리돼 있다」를 냈다.
#     ⇒ 🔴 **「0개」가 「없다」를 의미하지 않았다**(리터럴 목록의 구조적 한계).
#     ⇒ 「왜 …」 골격을 어간+어미로 일반화한다. 오탐은 `CLAUSE_DEF` 가 계속 막는다.
NARRATIVE = re.compile(
    r'왜 [^:*\n]{0,12}(?:필요한가|있는가|바꿨나|분리했나|생겼는가)'
    r'|무슨 일이 있었나'
    r'|실증\s*=|승격 근거\s*=|실측 예\(')

# 🔴 조문 정의 = 이 패턴이 있으면 **서사가 아니라 조문**이므로 옮기지 않는다.
CLAUSE_DEF = re.compile(r'\*\*R\d+(?:-\d+)+[a-z]?\s')

# 조문 ID 추출(불변식 1) — 정의·참조 모두 센다.
CLAUSE_ID = re.compile(r'R\d+(?:-\d+)+[a-z]?')

HEAD = re.compile(r'^(?:>\s*)?(#{1,4})\s+(.*?)\s*$')

# 토큰(불변식 3) = `retire_rows.tokens` 와 같은 규칙.
TOK_NUM = re.compile(r'\d[\d,\.]{2,}')
TOK_ID = re.compile(r'\b(?:[A-Z]{1,6}-\d+[A-Za-z\-]*|[A-Z]\d+[A-Za-z\-]*|O\d+[A-Z\-]*)\b')
TOK_CODE = re.compile(r'`([^`]+)`')

BULLET = re.compile(r'^(\s*)([*\-]\s|·\s)')

# 🔴🔴 [O106 자기시정] **처방 마커 = 블록 종료.**
#   첫 판본은 「다음 불릿까지」를 블록으로 잡았는데, 한 불릿 안에서 **경위와 처방이
#   같은 들여쓰기로 교대**하는 형태가 있었다(`R3-9 ㉥` = 원본 283~291행).
#   그 결과 `§C11` 이 처방 **3줄**을 사례집으로 빼냈다:
#     · 🟢 「적발했다고 쓰는 것」과 「정본을 고치는 것」은 다르다
#     · 🟢 각 인용처는 ㉠ 병기해 닫거나 ㉡ 열린 이유를 그 자리에 적는다
#     · ⇒ 인용처를 닫을 때 무엇이 닫히고 무엇이 열려 있는지 함께 적는다
#   🔴 **조문이 지시를 잃는다** ⇒ 크기를 줄이려고 규칙을 없애는 것이라 목적이 전도된다.
#   ⇒ 🟢/⚠️ 로 시작하는 줄에서 블록을 끊는다(그 줄부터는 원본에 남는다).
PRESCRIPTION = re.compile(r'^\s*(🟢|⚠️|✅)')


def read_text(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def write_text(p, s):
    with io.open(p, 'w', encoding='utf-8', newline='') as fh:
        fh.write(s)


def indent_of(s):
    return len(s) - len(s.lstrip())


def tokens(s):
    out = set()
    for m in TOK_CODE.finditer(s):
        t = m.group(1).strip()
        if len(t) >= 3:
            out.add(t)
    for rx in (TOK_NUM, TOK_ID):
        for m in rx.finditer(s):
            t = m.group(0).strip()
            if len(t) >= 3:
                out.add(t)
    return out


def headings(text):
    out = set()
    for line in text.split('\n'):
        m = HEAD.match(line)
        if m:
            out.add('%d|%s' % (len(m.group(1)), re.sub(r'\s+', ' ', m.group(2))))
    return out


def find_blocks(lines):
    """서사 블록을 찾는다. 반환 = [(start_idx, end_idx_exclusive, indent)]."""
    blocks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not NARRATIVE.search(line) or CLAUSE_DEF.search(line):
            i += 1
            continue
        ind = indent_of(line)
        j = i + 1
        while j < len(lines):
            nxt = lines[j]
            if not nxt.strip():                    # 빈 줄 = 블록 종료
                break
            if nxt.lstrip().startswith('#') or nxt.strip() == '---':
                break
            if PRESCRIPTION.match(nxt):            # 처방 시작 = 경위 끝
                break
            m = BULLET.match(nxt)
            if m and len(m.group(1)) <= ind:       # 같거나 얕은 새 불릿
                break
            if indent_of(nxt) < ind:               # 더 얕은 본문
                break
            j += 1
        blocks.append((i, j, ind))
        i = j
    return blocks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default=DEFAULT_SRC)
    ap.add_argument('--dst', default=DEFAULT_DST)
    # 🔴 [2026-08-28 O110] 라벨 기본값 하드코딩(`O106`) 제거 · `R1-7-10`
    add_label_arg(ap)
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()
    a.label = resolve_label(a.label)

    src = os.path.join(ROOT, a.src)
    dst = os.path.join(ROOT, a.dst)
    if not os.path.exists(src):
        raise SystemExit('🔴 원본 부재: %s' % a.src)

    text = read_text(src)
    lines = text.split('\n')
    blocks = find_blocks(lines)
    if not blocks:
        print('✅ 서사 블록 0개 — 이미 분리돼 있다')
        return 0

    # ── 목적지 본문 조립 + 원본 치환 계획 ────────────────────────────────
    moved_lines, plan, entries = 0, {}, []
    for n, (i, j, ind) in enumerate(blocks, 1):
        body = lines[i:j]
        anchor = 'C%02d' % n
        # 그 블록이 속한 조문 = 위로 올라가며 가장 가까운 조문 정의
        owner = '(미지정)'
        for k in range(i, -1, -1):
            m = CLAUSE_DEF.search(lines[k])
            if m:
                owner = CLAUSE_ID.search(m.group(0)).group(0)
                break
            hm = HEAD.match(lines[k])
            if hm:
                owner = hm.group(2)[:40]
                break
        entries.append((anchor, owner, i + 1, body))
        plan[i] = (j, '%s· 🔎 **경위·실사고 근거 = `%s` §%s**(`R2-8` 무변경 이관 · `%s`)'
                   % (' ' * ind, os.path.basename(a.dst), anchor, a.label))
        moved_lines += len(body)

    dparts = []
    dparts.append('<!-- LLM-METADATA')
    dparts.append('doc_id: INCIDENT_CASEBOOK')
    dparts.append('doc_role: 조문의 「왜 필요한가」 경위 서사 — 무변경 이관 사례집(append형)')
    dparts.append('project: GN_DW (굿네이버스)')
    dparts.append('created: 2026-08-28')
    dparts.append('created_by: %s' % a.label)
    dparts.append('index: 20_issue/00_INDEX_이슈원장.md')
    dparts.append('END-METADATA -->')
    dparts.append('')
    dparts.append('# 91_사고사례집 — 조문 경위의 무변경 이관부')
    dparts.append('')
    dparts.append('> 🔴 **여기 있는 문장은 조문이 아니라 「그 조문이 왜 생겼는가」다.**')
    dparts.append('> 조문·판정식은 원본(`%s`)에 그대로 있다.' % a.src)
    dparts.append('> ⇒ **매 세션 읽을 필요가 없다.** 읽는 시점 = **쓰기 사고를 조사할 때** ·')
    dparts.append('>   조문을 개정하려 할 때 · 「이 규칙을 왜 지켜야 하나」가 의심될 때.')
    dparts.append('')
    dparts.append('> 🟢 **이관 계약**(`R2-8`) — 본문은 **무변경**이다(요약·가필 없음).')
    dparts.append('> 원본에는 이 문서의 `§C##` 를 가리키는 포인터 1줄이 남았다.')
    dparts.append('> 🔴 **원본의 조문 ID 집합·제목 집합은 이관 전후로 동일**하다(blocking 검증 통과).')
    dparts.append('')
    dparts.append('| 앵커 | 소관 조문 | 원본 행(이관 시점) |')
    dparts.append('|---|---|---|')
    for anchor, owner, ln, _b in entries:
        dparts.append('| `§%s` | `%s` | %d |' % (anchor, owner, ln))
    dparts.append('')
    dparts.append('---')
    dparts.append('')
    for anchor, owner, ln, body in entries:
        dparts.append('## %s — 소관 `%s`' % (anchor, owner))
        dparts.append('')
        dparts.append('> 원본 `%s` %d행에서 무변경 이관(`%s`).' % (a.src, ln, a.label))
        dparts.append('')
        dparts.extend(body)
        dparts.append('')
    dparts.append('_Co-authored with CoCo_')
    dtext = '\n'.join(dparts) + '\n'

    # ── 원본 치환 ───────────────────────────────────────────────────────
    out, i = [], 0
    while i < len(lines):
        if i in plan:
            j, ptr = plan[i]
            out.append(ptr)
            i = j
            continue
        out.append(lines[i])
        i += 1
    new_text = '\n'.join(out)

    print('[경위 서사 분리] %s' % a.src)
    print('  서사 블록 %d개 · 이관 줄 %d' % (len(blocks), moved_lines))
    print('  원본 %s B → %s B  (감소 %s B · %.1f%%)' % (
        format(len(text.encode()), ','), format(len(new_text.encode()), ','),
        format(len(text.encode()) - len(new_text.encode()), ','),
        100.0 * (len(text.encode()) - len(new_text.encode())) / len(text.encode())))
    print('  목적지 %s = %s B (신규)' % (a.dst, format(len(dtext.encode()), ',')))
    print('')
    for anchor, owner, ln, body in entries:
        print('  §%s  %-10s 원본 %4d행 · %d줄  %s'
              % (anchor, owner, ln, len(body), body[0].strip()[:58]))

    # ── 불변식 1: 조문 ID 집합 ──────────────────────────────────────────
    before = set(CLAUSE_ID.findall(text))
    after = set(CLAUSE_ID.findall(new_text))
    lost = sorted(before - after)
    print('')
    print('[불변식1 조문 ID] 이전 %d종 · 이후 %d종 · 소실 %d종'
          % (len(before), len(after), len(lost)))
    if lost:
        print('🔴 FAIL — 조문 ID 가 사라진다: %s' % ', '.join(lost))
        print('   ⇒ 원본을 건드리지 않았다. `CLAUSE_DEF` 예외를 넓혀라.')
        return 1

    # ── 불변식 2: 제목 집합 ─────────────────────────────────────────────
    hb, ha = headings(text), headings(new_text)
    hlost = sorted(hb - ha)
    print('[불변식2 제목] 이전 %d · 이후 %d · 소실 %d' % (len(hb), len(ha), len(hlost)))
    if hlost:
        print('🔴 FAIL — 제목 소실: %s' % '; '.join(hlost[:5]))
        return 1

    # ── 불변식 3: R2-8-1 토큰 대조 ──────────────────────────────────────
    need = set()
    for _a, _o, _l, body in entries:
        need |= tokens('\n'.join(body))
    missing = sorted(t for t in need if t not in dtext)
    print('[불변식3 토큰] 대상 %d종 · 목적지 부재 %d종' % (len(need), len(missing)))
    if missing:
        print('🔴 FAIL — 부재 토큰: %s' % ', '.join(missing[:10]))
        return 1
    print('🟢 불변식 3종 전건 통과')

    if not a.apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    arch = os.path.join(ROOT, '_archive')
    if not os.path.isdir(arch):
        os.makedirs(arch)
    # 🔴 [2026-08-28 O110 · `R1-7-10`] 헬퍼 경유 — 덮어쓰기 금지(O109 D2).
    snapshot_content(src, 'prenarrative', text, label=a.label, archive=arch)
    write_text(dst, dtext)
    write_text(src, new_text)
    print('\n🟢 이관 완료 (스냅샷 경로는 위 헬퍼 출력 참조)')
    print('   이어서 실행하라:')
    print('   python3 scripts/clause_order_gate.py')
    print('   python3 scripts/doc_heading_gate.py')
    print('   python3 scripts/line_len.py %s %s' % (a.src, a.dst))
    print('   python3 scripts/doc_type_gate.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())

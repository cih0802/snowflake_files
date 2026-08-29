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
#   🆕 [2026-08-28 O111] 변형 3종 추가 — **전부 원본 grep 실측으로 확인한 표현**이다.
#     · `왜 바꿨나`(48행) · `왜 예외가 필요한가`(68행) · `왜 이 규약이 있는가`(163행)
#     🔴 O106 판본은 `왜 필요한가`·`왜 이 규칙이 있는가` 만 알아서 이 3건을 **조용히 놓쳤다**
#       (「서사 블록 0개 — 이미 분리돼 있다」를 출력했다). ⇒ 0건 출력은 「없다」가 아니라
#       **「내 정규식이 못 본다」**일 수 있다. 신호어를 새로 만나면 여기에 추가한다.
NARRATIVE = re.compile(
    r'왜 필요한가|왜 이 규칙이 있는가|무슨 일이 있었나|왜 분리했나'
    r'|왜 바꿨나|왜 예외가 필요한가|왜 이 규약이 있는가'
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
#   🆕 🔴 [2026-08-28 O111-B] **불릿 뒤 처방도 처방이다** — 종전 `^\s*(🟢|⚠️|✅|⇒)` 는
#     `    * ⚠️ **절감 기대치를 낮게 잡아라** …` 처럼 **불릿이 앞에 붙은 처방**을 놓쳤고,
#     그 줄에서 블록이 시작돼 **처방이 이관 대상**이 됐다(실측 오탐 1건).
#     ⇒ 선행 불릿(`*`·`-`·`·`)을 허용한다. 시작 차단과 종료 판정 **양쪽에** 적용된다.
PRESCRIPTION = re.compile(r'^\s*(?:[*\-·]\s*)?(🟢|⚠️|✅|⇒)')

# 🆕 🔴🔴 [2026-08-28 O111 신설] **개념 인용 가드** — 신호어가 `「…」` **안에** 있으면 서사가 아니다.
#   실측 오탐 = `init_ihcho/SKILL.md` 336행
#     `· 🆕 **조문의 「왜 필요한가」 경위 서사**는 `split_narrative.py` 로 … 이관한다`
#   이 줄은 **처방(도구 사용 지시)**인데 종전 판정식은 서사로 잡았다.
#   🔴 옮기면 「처방(🟢/⚠️)은 옮기지 않는다」를 지시하는 줄 자체가 사라진다 —
#     O106 초판이 `§C11` 에서 처방 3줄을 빼낸 것과 **같은 실패**다(자기참조적 사고).
#   ⇒ 판정 전에 `「…」` 구간을 지우고 나서 신호어를 찾는다.
CONCEPT_QUOTE = re.compile(r'「[^」]*」')

# 🆕 [2026-08-28 O111] `⇒` 로 시작하는 줄도 처방이다(블록 종료).
#   실측 = 스킬 `[O109 실사고]` 블록의 꼬리 2줄이
#     `⇒ **코드 파일에도 `edit` 를 쓴다.** … ㉠ 꼬리 되읽기 ㉡ `py_compile` …`
#   로 **4축 사후검증 처방**이었다. 종전 판정식은 이것까지 경위로 끌고 갔다.

# 🆕 🔴🔴 [2026-08-28 O111 신설] **목적지 append 파싱** — 초판은 `write_text(dst, dtext)` 로
#   목적지를 **통째로 덮어썼다.** 1회차(O106)에는 무해했지만 2회차부터는
#   ㉠ 기존 `§C01`~`§C12` 본문이 **경고 없이 사라지고**
#   ㉡ 원본에 남은 포인터 12줄이 **다른 내용을 가리키게 된다**(앵커가 C01 부터 재발급되므로).
#   🔴 이 워크스페이스가 4번 당한 「조용한 소실」과 같은 유형이고, 기존 불변식 3종은
#     **원본만** 검사하므로 이것을 **원리적으로 잡지 못한다** ⇒ 불변식 4를 함께 신설한다.
EXIST_ROW = re.compile(r'^\| `§(C\d+)` \| (.*?) \| (\d+) \|$', re.M)
TABLE_HEAD = '| 앵커 | 소관 조문 | 원본 행(이관 시점) |'
FOOTER = '_Co-authored with CoCo_'
SECTION_HEAD = re.compile(r'^## C\d+ — 소관 ', re.M)


def parse_existing(dst_path):
    """기존 목적지를 파싱한다. 반환 = (머리말, 표 행 원문 리스트, 절 본문, 최대 번호).

    🔴 **원문을 그대로 보존**한다(재조립·재포맷 금지 · `R2-8` 무변경 계약).
    """
    if not os.path.exists(dst_path):
        return None, [], '', 0
    t = read_text(dst_path)
    rows = ['| `§%s` | %s | %s |' % (a, o, n) for a, o, n in EXIST_ROW.findall(t)]
    nums = [int(a[1:]) for a, _o, _n in EXIST_ROW.findall(t)]
    idx = t.find(TABLE_HEAD)
    prefix = t[:idx].rstrip('\n') if idx >= 0 else None
    sm = SECTION_HEAD.search(t)
    if sm:
        body = t[sm.start():]
        fi = body.rfind(FOOTER)
        if fi >= 0:
            body = body[:fi]
        body = body.rstrip('\n')
    else:
        body = ''
    return prefix, rows, body, (max(nums) if nums else 0)


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


def find_blocks(lines, extra=None):
    """서사 블록을 찾는다. 반환 = [(start_idx, end_idx_exclusive, indent)].

    `extra` = 이 원본에만 적용할 추가 신호 정규식(`--signal`).
    """
    signal = NARRATIVE if extra is None else re.compile(
        NARRATIVE.pattern + '|' + extra)
    blocks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # 🆕 [O111] 개념 인용(`「…」`)을 지운 뒤 신호어를 찾는다 — 336행 오탐 차단.
        probe = CONCEPT_QUOTE.sub('', line)
        # 🆕 🔴 [O111-B] **처방 줄은 블록의 시작이 될 수 없다.**
        #   종전 `PRESCRIPTION` 은 블록을 **끝내는** 데만 쓰였다 ⇒ 처방 줄 자신이 신호어를
        #   품고 있으면(예: `⚠️ **절감 기대치를 낮게 잡아라** — 실측 = 418 B …`) **그 줄에서
        #   블록이 시작돼 처방이 이관된다.** 실측으로 그 오탐을 만났고 그 때문에 `실측 =`·`실증 =`
        #   같은 유용한 신호어를 **아예 쓸 수 없었다**(신호를 좁히는 비용을 처방 보호가 대신 냈다).
        #   ⇒ 시작 판정에서도 같은 마커를 배제한다 ⇒ 신호어를 넓게 쓸 수 있게 된다.
        if PRESCRIPTION.match(line):
            i += 1
            continue
        if not signal.search(probe) or CLAUSE_DEF.search(line):
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
    # 🆕 [2026-08-28 O111] `--signal` = 그 원본에만 쓰는 **추가 신호어**.
    #   🔴 왜 전역 `NARRATIVE` 에 넣지 않는가: `init_ihcho/SKILL.md` 의 신호어는 `실사고` 인데
    #     지침에는 이관 포인터 줄 자체가 **「경위·실사고 근거 = …」** 라서, 전역에 넣으면
    #     **포인터를 다시 서사로 읽어 무한 재이관**한다. ⇒ 원본별로 좁게 준다.
    #   예 = --signal '\[O\d+ 실사고|^>\s*\*\*실사고\*\*|실사고\s*='
    ap.add_argument('--signal', default=None,
                    help='이 원본에만 추가할 서사 신호 정규식(대안 나열 · 창작 금지 = grep 실측한 표현만)')
    # 🆕 🔴 [2026-08-28 O111-B] `--exclude` = 그 블록을 **이관 대상에서 뺀다**(부분 문자열 매칭).
    #   🔴 왜 필요한가: 불변식1(조문 ID 보존)이 정당하게 blocking 할 때 **빠져나갈 길이 없었다.**
    #     실측 = `01_문서분할_규약.md` 의 한 서사 블록이 문서 전체에서 **유일한 `R1-3-2` 언급**을
    #     담고 있어 이관하면 조문 참조가 사라진다 ⇒ 게이트가 막는다(맞는 판정이다).
    #     그런데 종전에는 「전부 옮기거나 아무것도 못 옮기거나」였다 ⇒ 나머지 4블록도 함께 막혔다.
    #   🟢 처방 = 그 블록만 빼고 진행한다. **불변식을 끄는 것이 아니라 대상을 줄이는 것**이다
    #     (`R1-7-4` 「FAIL 을 골든으로 덮지 마라」와 같은 정신 — 검사는 그대로 두고 입력을 고친다).
    ap.add_argument('--exclude', action='append', default=None, metavar='SUBSTR',
                    help='이관에서 제외할 블록(소관 조문 또는 첫 줄의 부분 문자열 · 반복 가능)')
    a = ap.parse_args()
    a.label = resolve_label(a.label)

    src = os.path.join(ROOT, a.src)
    dst = os.path.join(ROOT, a.dst)
    if not os.path.exists(src):
        raise SystemExit('🔴 원본 부재: %s' % a.src)

    text = read_text(src)
    lines = text.split('\n')
    blocks = find_blocks(lines, a.signal)
    if not blocks:
        print('✅ 서사 블록 0개 — 이미 분리돼 있다')
        return 0

    # 🆕 [2026-08-28 O111] 기존 목적지를 먼저 읽어 **앵커를 이어서 발급**한다.
    ex_prefix, ex_rows, ex_body, ex_max = parse_existing(dst)

    # 🆕 🔴🔴 [2026-08-28 O111 · 음성 테스트 축6 이 잡았다] **불변식4 의 분모는
    #   `parse_existing` 의 반환값이 아니라 「디스크에 파일이 있는가」다.**
    #   초판 처방은 `if ex_prefix is None and ex_max == 0:` 으로 「신규」를 판정했는데,
    #   그러면 **파서가 기존 내용을 못 보는 바로 그 실패 모드**에서 불변식4 가 조용히
    #   건너뛴다(= 검사해야 할 때 침묵한다 · `R3-9 ㉢` 「분모 등재 없이는 0 을 내며 침묵」).
    #   ⇒ 목적지 원문을 **독립적으로 다시 읽어** 대조 분모로 쓴다.
    dst_pre = read_text(dst) if os.path.exists(dst) else ''

    # ── 목적지 본문 조립 + 원본 치환 계획 ────────────────────────────────
    #   🆕 [O111-B] **제외를 먼저 적용한 뒤 앵커를 발급한다** — 순서를 뒤집으면 제외된 블록이
    #   번호를 소비해 `§C##` 에 결번이 생긴다(좌표 인용에 혼선을 준다).
    def owner_of(i):
        for k in range(i, -1, -1):
            m = CLAUSE_DEF.search(lines[k])
            if m:
                return CLAUSE_ID.search(m.group(0)).group(0)
            hm = HEAD.match(lines[k])
            if hm:
                return hm.group(2)[:40]
        return '(미지정)'

    kept = []
    for (i, j, ind) in blocks:
        body = lines[i:j]
        owner = owner_of(i)
        # 🔴 [O111-B] 매칭 분모 = **소관 조문 + 블록 본문 전체**.
        #   첫 줄만 보면 못 잡는다 — 실측에서 막아야 할 토큰(`R1-3-2`)이 **2번째 줄**에 있었다.
        blob = owner + '\n' + '\n'.join(body)
        if a.exclude and any(x in blob for x in a.exclude):
            print('  ⚪ 제외 = 소관 %s · 원본 %d행 — `--exclude` 지정' % (owner, i + 1))
            continue
        kept.append((i, j, ind, owner, body))

    moved_lines, plan, entries = 0, {}, []
    for n, (i, j, ind, owner, body) in enumerate(kept, ex_max + 1):
        anchor = 'C%02d' % n
        entries.append((anchor, owner, i + 1, body))
        # 🆕 [2026-08-28 O111] 포인터에 **경로를 붙인다**(종전은 basename 뿐).
        #   🔴 근거 = `doc_coord_gate` 축5「모호한 파일명」— basename 만 쓰면 동명 파일이
        #     생겼을 때 어느 것인지 판정할 수 없다. 경로를 붙이면 그 경고가 원리적으로 사라진다.
        plan[i] = (j, '%s· 🔎 **경위·실사고 근거 = `%s` §%s**(`R2-8` 무변경 이관 · `%s`)'
                   % (' ' * ind, a.dst, anchor, a.label))
        moved_lines += len(body)

    dparts = []
    if ex_prefix is not None:
        # 🟢 기존 머리말은 **원문 그대로** 재사용한다(`created_by` 를 덮지 않는다).
        dparts.append(ex_prefix)
        dparts.append('')
    else:
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
    dparts.append(TABLE_HEAD)
    dparts.append('|---|---|---|')
    dparts.extend(ex_rows)                       # 🟢 기존 행 원문 보존
    for anchor, owner, ln, _b in entries:
        dparts.append('| `§%s` | `%s` | %d |' % (anchor, owner, ln))
    dparts.append('')
    dparts.append('---')
    dparts.append('')
    if ex_body:
        dparts.append(ex_body)                   # 🟢 기존 절 본문 원문 보존
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

    # ── 🆕 불변식 4: 기존 목적지 내용 보존 (2026-08-28 O111 신설) ────────
    #   🔴 불변식 1~3 은 **원본만** 본다 ⇒ 목적지를 덮어써도 전부 🟢 를 낸다.
    #     실제로 초판은 목적지를 통째로 재작성했다(2회차 실행 = `§C01`~ 전건 소실).
    #   🔴🔴 분모는 `dst_pre`(디스크 원문)다 — `parse_existing` 반환값이 아니다.
    #     음성 테스트 축6 = 파서를 눈감게 만들어도 이 검사가 **살아 있어야** 한다.
    if not dst_pre.strip():
        print('[불변식4 기존 보존] 목적지 신규(디스크 부재/공백) — 대조 대상 0')
    else:
        pre_rows = [l for l in dst_pre.split('\n') if EXIST_ROW.match(l)]
        pre_lines = [x for x in dst_pre.split('\n') if x.strip()]
        pre_anchors = set(re.findall(r'^## (C\d+) — 소관 ', dst_pre, re.M))
        lost_rows = [x for x in pre_rows if x not in dtext]
        lost_body = [x for x in pre_lines if x not in dtext]
        anchor_lost = sorted(pre_anchors - set(
            re.findall(r'^## (C\d+) — 소관 ', dtext, re.M)))
        # 🔴 번호 재사용 = 기존 앵커에 새 블록이 겹쳐 쓰이는 상태(포인터가 뒤틀린다).
        reused = sorted(pre_anchors & set(anchor for anchor, _o, _l, _b in entries))
        print('[불변식4 기존 보존] 기존 앵커 %d · 표 행 소실 %d · 본문 줄 소실 %d'
              ' · 앵커 소실 %d · 번호 재사용 %d'
              % (len(pre_anchors), len(lost_rows), len(lost_body),
                 len(anchor_lost), len(reused)))
        if entries:
            print('   신규 앵커 = %s ~ %s'
                  % (entries[0][0], entries[-1][0]))
        if lost_rows or lost_body or anchor_lost or reused:
            print('🔴 FAIL — 기존 목적지 내용이 사라진다(덮어쓰기).')
            for x in (lost_rows + lost_body)[:5]:
                print('   소실: %s' % x[:90])
            if anchor_lost:
                print('   앵커 소실: %s' % ', '.join(anchor_lost))
            if reused:
                print('   🔴 번호 재사용: %s ⇒ 원본 포인터가 다른 내용을 가리킨다'
                      % ', '.join(reused))
            print('   ⇒ 파일을 쓰지 않았다. `parse_existing` 이 목적지를 못 읽는다.')
            return 1
    print('🟢 불변식 4종 전건 통과')

    if not a.apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    arch = os.path.join(ROOT, '_archive')
    if not os.path.isdir(arch):
        os.makedirs(arch)
    # 🔴 [2026-08-28 O110 · `R1-7-10`] 헬퍼 경유 — 덮어쓰기 금지(O109 D2).
    snapshot_content(src, 'prenarrative', text, label=a.label, archive=arch)
    # 🆕 🔴 [2026-08-28 O111] **목적지도 스냅샷한다** — 초판은 원본만 남겨서
    #   목적지 재작성이 되돌릴 수 없었다(`R1-7-6` 「redo 경로 없음」).
    if os.path.exists(dst):
        snapshot_content(dst, 'prenarrative', read_text(dst), label=a.label, archive=arch)
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

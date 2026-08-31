#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-14 O82] 장문 정본 문서 → 연번 조각 + 허브 무변경 분할.

문제: 정본 문서가 `read` 1회 한도를 넘겨 여러 세션 연속 미독이 된다.
      `10_진단_원인분석.md` 3,318줄/355.6KB · `01_세션이력.md` 6,188줄/692.5KB.
      R1-3-6 이 규정한 대로 **크기는 증상이고 원인은 한 파일에 몰아쓴 형태**다.

처방: 절 경계에서만 잘라 **바이트 동일한 조각**으로 나누고, 원 파일명을
      **허브**(목차 + 좌표 대응표)로 바꾼다. 본문 문자 수정은 0 이다.

무변경의 정의(이 스크립트의 계약 · O59-J·O66 상속):
  조각 본문을 순서대로 이어붙인 바이트열이 원문과 **SHA256 완전 일치**해야 한다.
  조각 파일에는 머리말 주석이 붙지만 `BODY-BEGIN` 센티넬 **아래**만 본문이며,
  게이트는 센티넬 아래만 모아 대조한다. ⇒ 본문에 대한 추가·삭제·수정 0건.

조각 상한(직전 세션 실측 산출):
  **300줄 AND 40KB** 를 둘 다 만족한다. 줄 수가 적어도 바이트가 크면
  `read` 가 `Output too large` 로 본문을 돌려주지 않는다(인덱스 321줄/100.8KB 실패).

경계 우선순위:
  section 모드 = `## ` → `### ` → `#### ` → 빈 줄(문단) → 표 행
  entry   모드 = `> #### [날짜 O##]` → 빈 줄 → 표 행   (append-only 이력용)
  **경계에서만 자르고 경계를 못 찾으면 그 원자를 쪼개지 않는다**(초과를 보고한다).

실행:
  python3 scripts/split_doc.py 20_issue/10_진단_원인분석.md --dry-run
  python3 scripts/split_doc.py 20_issue/10_진단_원인분석.md
  python3 scripts/split_doc.py 20_issue/10_진단_원인분석.md --verify
"""
import argparse
import hashlib
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVE = os.path.join(ROOT, '_archive')

# 표 열수 판정은 O66 계약을 그대로 상속한다 — `|` 개수 세기는 백틱 코드스팬에서 오탐한다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from split_issue_index import split_row  # noqa: E402

# 🔴 [2026-08-28 O109] 스냅샷은 `snapshot_util` 만 경유한다(인수 ▣WWW ①).
#   종전에는 4개 지점이 세션 라벨을 **하드코딩**했고(`O82-presplit`·`O107-prehub`·
#   `O83B-prerebalance`·`O107-pretooutdir`) `shutil.copyfile` 이 기존 스냅샷을
#   **경고 없이 덮었다** ⇒ 되돌림 경로가 조용히 파괴됐다(O108 이 `00_INDEX` 를
#   3회 republish 해 최초 상태가 이미 없다). 음성 테스트 = `test_snapshot_util.py`.
from snapshot_util import add_label_arg, snapshot, snapshot_content  # noqa: E402

MAX_LINES = 300
MAX_BYTES = 40 * 1024

# 조각 파일에 붙는 머리말 3줄. 🔴 [2026-08-18 O83] 상한 판정은 **본문이 아니라 파일**을 재야 한다 —
#   `read` 가 읽는 것은 머리말이 붙은 **파일**이고 게이트 6 도 파일을 잰다.
#   실측 사고: 본문 299줄 조각이 파일 **302줄**이 되어 4개가 게이트 6 FAIL 이었다.
#   기존 6종은 본문 최대가 297줄이라 **우연히** 걸리지 않았다(잠복 결함).
HEADER_LINES = 3
# 🆕 [2026-08-18 O83-H] 실측 근거 확보 — 종전 400 은 관례값이었다(자기검토 C2 잔여 항목).
#   조각 머리말 **89개 전수 측정** = min 332 · median 349 · **max 381** B.
#   ⇒ 400 은 max 대비 마진이 **19B 뿐**이고, 파일명이 길거나 원문 행번호가 5자리가 되면
#   **예약이 부족해져** `fits()` 가 과소 예약하고 조각이 상한을 넘을 수 있다(잠복 결함).
#   ⇒ **max(381) + 여유 67 = 448**. 올리는 방향이므로 조각이 조금 작아지고 **안전측**이다.
HEADER_BYTES = 448

BODY_BEGIN = '<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->'

# [2026-08-18 O83] 폴더 분할 마커 — 허브가 조각 위치를 **자기기술**한다.
#   🔴 왜 마커인가: `--verify` 를 나중에 실행할 때 `--outdir` 을 다시 입력하게 만들면
#   입력을 빠뜨린 호출이 「조각이 없다」로 실패하고, 그 실패가 **분할 사고처럼 보인다**.
#   ⇒ 위치는 허브에 적어 두고 게이트가 읽는다(사람 입력에 의존하지 않는다).
OUTDIR_MARK = '<!-- SPLIT-OUTDIR: %s -->'
OUTDIR_RX = re.compile(r'<!--\s*SPLIT-OUTDIR:\s*(.+?)\s*-->')

# [2026-08-18 O83-B] 경계 모드 마커. 🔴 `--rebalance` 는 **원문이 아니라 현재 조각 내용**을
#   다시 쪼개므로 최초 분할과 **같은 경계 모드**를 써야 한다. 사람이 매번 `--boundary` 를
#   다시 입력하게 만들면 빠뜨린 호출이 `entry` 문서를 `section` 으로 쪼개
#   조각 배치를 조용히 망친다 ⇒ 허브가 자기기술한다(OUTDIR_MARK 와 같은 취지).
BOUNDARY_MARK = '<!-- SPLIT-BOUNDARY: %s -->'
BOUNDARY_RX = re.compile(r'<!--\s*SPLIT-BOUNDARY:\s*(section|entry)\s*-->')

LEVELS_SECTION = [r'^## ', r'^### ', r'^#### ']
LEVELS_ENTRY = [r'^> #### ']


def read_text(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read()


def write_text(path, text):
    with io.open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


def sha(s):
    return hashlib.sha256(s.encode('utf-8')).hexdigest()


def nbytes(s):
    return len(s.encode('utf-8'))


def seg_text(lines, a, b):
    """[a, b) 구간을 원문 그대로 복원한다(줄 사이 개행만 되살린다)."""
    return '\n'.join(lines[a:b])


def fits(lines, a, b, fill=1.0):
    """구간이 조각 상한에 맞는가. 🔴 머리말(HEADER_LINES/BYTES)을 **선반영**한다.

    🔴 [2026-08-18 O83-D] `fill` 인자 추가. **원자화도 fill 을 봐야 한다** —
    `pack(fill)` 만 부분 충전하고 `atomize()` 가 하드 상한으로 판정하면
    **하드 상한 이내의 큰 원자가 그대로 한 조각**이 되어 여유가 생기지 않는다.
    실측: `10_진단_원인분석` §13 이 **33,464B 원자**로 남아 재균형 후에도 여유가
    7,146B(<20%)였다. `pack(fill)` 을 도입할 때와 **같은 축의 누락**이었다.
    """
    lim_lines = max(1, int(MAX_LINES * fill))
    lim_bytes = max(1, int(MAX_BYTES * fill))
    if b - a + HEADER_LINES > lim_lines:
        return False
    return nbytes(seg_text(lines, a, b)) + HEADER_BYTES <= lim_bytes


def cut_points(lines, a, b, pat):
    """[a, b) 안에서 pat 이 매칭되는 줄 번호 목록(구간 시작은 항상 포함)."""
    rx = re.compile(pat)
    idx = [i for i in range(a, b) if rx.match(lines[i])]
    if not idx or idx[0] != a:
        idx = [a] + idx
    return sorted(set(idx))


def _unquote(s):
    """블록인용 접두(`>`·`> `·`>>`)를 벗긴 본문.

    🔴 [2026-08-18 O83 신설 · 첫 실사용에서 드러난 도구 결함] `01_세션이력.md` 는
    **항목 전체가 블록인용**이라 문단 구분선이 빈 줄이 아니라 **`>`** 이고, 표 행도
    **`> |`** 로 시작한다. 그래서 `blank_cuts`·`row_cuts` 가 경계를 **0개** 찾았고
    entry 모드가 큰 항목을 못 쪼개 조각 2개가 상한을 초과했다(485줄/58.3KB · 715줄/72.3KB).
    `-016` 의 72.3KB 는 실측 하드 한도 **(37.6KB, 71.6KB]** 를 넘어 `read` 가 본문을
    아예 돌려주지 못하는 크기다 ⇒ 「분할했지만 여전히 못 읽는」 상태가 된다.
    ⇒ 경계 판정을 **인용 접두에 무관**하게 만든다(`R1-6-7` ⑤ 가 `|` 개수 세기를
    금지한 것과 같은 축 — 마크다운 표면 문자를 그대로 믿으면 안 된다).
    """
    t = s.lstrip()
    while t.startswith('>'):
        t = t[1:].lstrip()
    return t


def blank_cuts(lines, a, b):
    """빈 줄 뒤(= 다음 문단 시작)를 경계로 삼는다. 인용 블록의 `>` 도 빈 줄로 본다."""
    idx = [a]
    for i in range(a + 1, b):
        if _unquote(lines[i - 1]) == '' and _unquote(lines[i]) != '':
            idx.append(i)
    return sorted(set(idx))


def row_cuts(lines, a, b):
    """표 행마다 경계. 헤더 2줄(제목·구분)은 붙여 둔다. 인용 접두(`> |`)를 허용한다."""
    idx = [a]
    for i in range(a + 1, b):
        prev = _unquote(lines[i - 1])
        cur = _unquote(lines[i])
        if not cur.startswith('|'):
            continue
        if set(prev.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
            continue
        idx.append(i)
    return sorted(set(idx))


def to_blocks(idx, end):
    return [(idx[k], idx[k + 1] if k + 1 < len(idx) else end) for k in range(len(idx))]


def atomize(lines, a, b, levels, depth=0, fill=1.0):
    """[a, b) 를 상한에 맞는 원자 목록으로 분해한다. 경계에서만 자른다.

    🔴 [2026-08-18 O83-D] `fill` 전파. 부분 충전 목표는 **원자화 단계에서** 적용해야
    효과가 있다(위 `fits` docstring 의 33,464B 실측 참조).
    """
    if fits(lines, a, b, fill):
        return [(a, b)]
    if depth < len(levels):
        idx = cut_points(lines, a, b, levels[depth])
    elif depth == len(levels):
        idx = blank_cuts(lines, a, b)
    elif depth == len(levels) + 1:
        idx = row_cuts(lines, a, b)
    else:
        return [(a, b)]          # 더 쪼갤 경계가 없다 — 초과를 그대로 보고한다
    blocks = to_blocks(idx, b)
    if len(blocks) <= 1:
        return atomize(lines, a, b, levels, depth + 1, fill)
    out = []
    for x, y in blocks:
        out.extend(atomize(lines, x, y, levels, depth + 1, fill))
    return out


def pack(lines, atoms, fill=1.0):
    """원자를 순서대로 그리디 적재한다. 원자 순서·내용은 바꾸지 않는다.

    🔴 [2026-08-18 O83-B] `fill` = 목표 채움 비율(0 < fill ≤ 1). 상한이 아니라
    **상한 × fill** 까지만 채운다.
    **왜 필요한가**: 그리디로 상한까지 채우면 앞 조각이 전부 포화되고, 갱신형 원장은
    신규 행이 **첫 조각**(표 머리 = 최신 우선)에 떨어지므로 재균형이 여유를
    **0 그대로** 남긴다 — 실측: 인덱스 재균형 전후 모두 최소 여유 **178B** 였다.
    ⇒ B-tree 가 노드를 **부분 충전**으로 유지하는 것과 같은 이유다: 삽입을 흡수할
    공간이 없으면 「재균형했다」가 아무 효과가 없다.
    ⚠️ 단일 원자가 상한×fill 을 넘으면 그 원자는 **상한 판정으로만** 통과시킨다 —
    더 쪼갤 경계가 없는 원자를 fill 때문에 버리면 분할 자체가 실패한다.
    """
    def ok(a, b):
        return fits(lines, a, b, fill)

    chunks = []
    cur = None
    for a, b in atoms:
        if cur is None:
            cur = [a, b]
            continue
        if ok(cur[0], b):
            cur[1] = b
        else:
            chunks.append(tuple(cur))
            cur = [a, b]
    if cur is not None:
        chunks.append(tuple(cur))
    return chunks


HEAD_RX = re.compile(r'^(#{2,4}|> #{4}) ')


def head_of(lines, a, b):
    """조각의 대표 제목 — 구간 안 첫 제목 줄."""
    for i in range(a, b):
        if HEAD_RX.match(lines[i]):
            return lines[i].lstrip('> ').lstrip('#').strip()
    return '(제목 없는 선두 구간)'


# ─────────────────────────────────────────────────────────────────────────────
# [2026-08-28 O107] 조각 선택표 — 허브 목차만으로 조각을 고를 수 있게 한다(▣GGG ①).
#
# 🔴 무엇이 문제였나: 「선두 절」 1개만 싣는 목차는 **선두 구간에 제목이 없으면 비어 버린다**.
#   실측(O106 인수) = `00_INDEX` 8조각 중 **5개**가 `(제목 없는 선두 구간)` 이었고,
#   재균형으로 4/7 → 5/8 로 **악화**됐다(§1 대시보드 표가 조각 경계에서 잘리기 때문이다).
#   ⇒ 허브를 읽어도 조각을 고를 수 없어 **전량 독해로 회귀하는 구조**가 남아 있었다.
# 🟢 처방: 조각마다 **포함 절 전체 목록**과 **포함 이슈 ID 목록**을 싣는다.
#   선두에 제목이 없어도 그 조각 안의 절·ID 로 고를 수 있다.
# ⚠️ 상한 방어: 허브도 문서이므로 40KB 상한을 받는다(`doc_type_gate`).
#   ⇒ 제목은 TITLE_MAX 자로 자르고, 항목 수는 캡을 두고 초과분은 「… 외 N건」으로 적는다.
#   ⚠️ `entry` 모드(이력·로그)는 **절 목록을 싣지 않는다** — 항목 제목이 길고 수가 많아
#   허브가 수십 KB로 커진다. 그 문서의 실제 선택자는 **세션 라벨(ID)** 이다(`R1-3-6`).
TITLE_MAX = 50            # 제목 표시 상한(자)
# 🆕 🔴🔴 [2026-08-30 O124-B] **70 → 50 인하 · 근거는 실측이다.**
#   문제 = 허브는 「목차」인데 **여유가 계속 줄어들어** `doc_type_gate` 축3 경고가 상주했다
#     (`99_NEXT_SESSION.md` 실측 = 인수 시점 여유 **6,994 B** → O124 가 인수인계 절을 넣자 **6,468 B**
#     ⇒ 🔴 **내 작업이 그 문제를 악화시켰다**).
#   🔴 인수 처방 「승계 절 은퇴」는 무효였다 — 허브는 100% 자동 색인이고 승계 절 본문은 **조각**에 있으며
#     `retire_sections` 는 **제목을 건드리지 않으므로** 색인이 줄지 않는다(O124 실측 · 여유 회복 0).
#   🟢 그래서 **색인 밀도**를 낮춘다. 이것이 「목차를 줄이는」 유일한 직접 수단이다.
#   🟢 **판정식 = 변별 붕괴 0** — 「서로 다른 절 제목이 같은 문자열로 잘려 조각을 고를 수 없게 되는가」.
#     실측(허브 11종 · 절+`▣` 제목 **967개**) = `TITLE_MAX` **70·60·55·50·45·40·35 전부 붕괴 0**
#     ⇒ 이 문서군의 제목은 **선두에 변별자**(`0-BBBB.` · `▣ ZZZ3` · 절 번호)를 두므로 앞부분만으로 갈린다.
#     제목 바이트 = 70 → 50 에서 **73,138 → 67,140**(−5,998 · 허브 전 종 합).
#   🔴 **더 낮추지 마라(45 이하)** — 붕괴는 0 이지만 사람이 제목을 **읽고 고르는** 여유가 사라진다.
#     🟢 값을 바꿀 때는 `test_split_doc_toc.py` 「변별 붕괴」 축을 먼저 보라(그 축이 0 을 강제한다).
TITLES_PER_CHUNK = 30     # 조각당 절 항목 캡
IDS_PER_CHUNK = 80        # 조각당 ID 항목 캡
PICK_LINE_SOFT = 600      # 한 줄 목표 길이(자) · R1-5 목표 1,000자의 절반 이하

# 🔴 `R\d+` 은 **넣지 않는다** — 그것은 지침 조문 번호이고 이슈 ID 가 아니다.
#   조각 선택자로서 의미가 없고, 모든 조각에 흔하게 나와 목록을 무의미하게 만든다.
PICK_ID_RX = re.compile(
    r'(?<![0-9A-Za-z])(?:DEC|BLOCKING|CONF|PROC|OPS|SVL|AD|[OPQ])-?\d+(?:-[0-9A-Z]+)?'
    r'(?![0-9A-Za-z])')


def clean_title(s):
    """제목 줄 → 표에 넣을 한 줄 라벨. 표 구분자(`|`)와 개행 위험 문자를 제거한다."""
    t = s.lstrip('> ').lstrip('#').strip()
    t = t.replace('|', '/')
    if len(t) > TITLE_MAX:
        t = t[:TITLE_MAX - 1] + '…'
    return t


def titles_in(lines, a, b):
    """[a, b) 안의 절 제목 전체(원문 순서 · 중복 유지 안 함)."""
    out = []
    for i in range(a, b):
        if HEAD_RX.match(lines[i]):
            t = clean_title(lines[i])
            if t and t not in out:
                out.append(t)
    return out


def _id_key(t):
    m = re.match(r'([A-Z]+)-?(\d+)(?:-(.*))?$', t)
    if not m:
        return (t, 0, '')
    return (m.group(1), int(m.group(2)), m.group(3) or '')


def ids_in(lines, a, b):
    """[a, b) 안의 이슈 ID 종류(정렬 · 중복 제거)."""
    found = set(PICK_ID_RX.findall(seg_text(lines, a, b)))
    return sorted(found, key=_id_key)


def wrap_items(prefix, items, cap, soft=PICK_LINE_SOFT):
    """`prefix` + 항목 나열을 **여러 줄로 나눠** 반환한다(R1-5 한 줄 2,000자 가드).

    🔴 캡을 넘긴 항목은 버리지 않고 **「… 외 N건」으로 남긴다** — 「전부 실렸다」로
    오해하면 이 표를 근거로 「그 조각에 없다」고 단정하게 된다(그것은 판정 오류다).
    """
    if not items:
        return ['%s(없음)' % prefix]
    shown, rest = items[:cap], len(items) - cap
    out, cur = [], prefix
    for k, it in enumerate(shown):
        piece = it if cur.endswith(' ') or cur == prefix else ' · ' + it
        if len(cur) + len(piece) > soft and cur != prefix:
            out.append(cur)
            cur = '  ' + it
        else:
            cur = cur + piece
    if rest > 0:
        cur = cur + ' · … 외 **%d건**' % rest
    out.append(cur)
    return out


def enclosing_title(lines, a):
    """조각 시작(`a`) **직전**의 가장 가까운 제목 — 「이어지는 절」.

    🔴 [2026-08-28 O107] `(제목 없는 선두 구간)` 의 정체는 **절이 없는 것이 아니라
    앞 조각에서 시작한 절이 이어지는 것**이다(§1 대시보드 표가 조각 경계에서 잘린다).
    ⇒ 「없다」고 쓰면 고를 수 없지만 **「§1 이 이어진다」**고 쓰면 고를 수 있다.
    """
    for i in range(a - 1, -1, -1):
        if HEAD_RX.match(lines[i]):
            return clean_title(lines[i])
    return None


def head_label(lines, a, b):
    """조각 목차의 「선두 절」 셀. 제목이 없으면 **이어지는 절**을 적는다."""
    for i in range(a, b):
        if HEAD_RX.match(lines[i]):
            return clean_title(lines[i])
    enc = enclosing_title(lines, a)
    return ('(이어짐) %s' % enc) if enc else '(선두 절 없음 · 문서 첫 구간)'


def pick_table(lines, chunks, stem, disp, mode):
    """조각 선택표 블록. 🔴 제목(`##`)은 **1개만** 늘린다 — 조각마다 `###` 를 쓰면
    `doc_heading_gate` 골든이 조각 수에 따라 매번 흔들려 게이트가 무의미해진다."""
    out = []
    out.append('## 조각 선택표 — **어느 조각을 읽어야 하는가**')
    out.append('')
    out.append('> 🔴 **조각을 고를 때는 「선두 절」 1개가 아니라 이 표를 본다.**')
    out.append('> 조각 경계가 표 중간에 떨어지면 선두에 제목이 없다 — 그때는 **앞 조각에서')
    out.append('> 시작한 절이 이어지는 것**이므로 `(이어짐) …` 으로 적는다.')
    out.append('> 🔴 이 표는 **색인이다** — 여기 있는 ID·절을 근거로 인용하지 말고 그 조각을 `read` 한다.')
    if mode == 'entry':
        out.append('> ⚠️ 이 문서는 `entry` 모드(append형)라 **절 목록을 싣지 않는다** —')
        out.append('> 항목 제목이 길고 수가 많아 허브가 상한을 넘는다. 선택자는 **세션 라벨**이다.')
    out.append('> ⚠️ 항목 캡(절 %d · ID %d)을 넘으면 「… 외 N건」으로 적는다 — **전량이 아니다.**'
               % (TITLES_PER_CHUNK, IDS_PER_CHUNK))
    out.append('')
    for n, (a, b) in enumerate(chunks, 1):
        out.append('**`%s%s-%03d.md`** (구 %d~%d행)' % (disp, stem, n, a + 1, b))
        if mode != 'entry':
            titles = titles_in(lines, a, b)
            enc = enclosing_title(lines, a) if not (titles and HEAD_RX.match(lines[a])) else None
            if enc:
                titles = ['(이어짐) %s' % enc] + titles
            out.extend(wrap_items('- 절: ', titles, TITLES_PER_CHUNK + 1))
        out.extend(wrap_items('- ID: ', ids_in(lines, a, b), IDS_PER_CHUNK))
        out.append('')
    return out


def chunk_path(src, n, outdir=None):
    """조각 경로. `outdir` 이 주어지면 **하위 폴더**에 둔다(허브는 원 위치·원 파일명 유지 · R1-6-5).

    🔴 [2026-08-18 O83 신설] 폴더 방식 사유 = `01_세션이력.md` 는 조각이 수십 개라
    형제로 두면 `20_issue/` 가 조각 파일로 덮여 **허브를 찾기 어려워진다**
    (사용자 지시 = 「폴더를 만들어 분리하고 기존 문서는 포인터만」).
    ⚠️ 폴더 방식은 **기존 게이트 분모를 벗어난다** — `doc_heading_gate`·`index_row_gate` 의
    `chunk_files()` 와 `doc_line_length_gate` 의 glob 을 함께 넓혀야 한다(`R1-6-8`).
    넓히지 않으면 조각으로 **이동한** 제목·표 행이 **유실로 대량 오탐**된다.
    """
    stem, ext = os.path.splitext(src)
    if outdir:
        return os.path.join(os.path.dirname(src), outdir,
                            '%s-%03d%s' % (os.path.basename(stem), n, ext))
    return '%s-%03d%s' % (stem, n, ext)


def hub_outdir(src):
    """허브에 기록된 조각 폴더명(없으면 None = 형제 조각 방식)."""
    if not os.path.exists(src):
        return None
    m = OUTDIR_RX.search(read_text(src))
    return m.group(1) if m else None


def hub_boundary(src, fallback='section'):
    """허브에 기록된 경계 모드. 마커가 없으면 `fallback`(구 허브 호환)."""
    if not os.path.exists(src):
        return fallback
    m = BOUNDARY_RX.search(read_text(src))
    return m.group(1) if m else fallback


def chunk_header(src, n, total, a, b):
    base = os.path.basename(src)
    return [
        '<!-- SPLIT-CHUNK %s | %03d/%03d | 허브 = %s | 원문 %d~%d행 -->' % (
            base, n, total, base, a + 1, b),
        '<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다'
        ' (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->',
        BODY_BEGIN,
    ]


def build_hub(src, lines, chunks, digest, outdir=None, mode='section', label='원문'):
    base = os.path.basename(src)
    stem = os.path.splitext(base)[0]
    disp = ('%s/' % outdir) if outdir else ''
    orig_meta = []
    for l in lines[:40]:
        orig_meta.append(l)
        if 'END-METADATA' in l:
            break
    else:
        orig_meta = []

    out = []
    out.append('<!-- LLM-METADATA')
    out.append('doc_id: %s_HUB' % re.sub(r'[^0-9A-Za-z]+', '_', stem).upper().strip('_'))
    out.append('doc_role: %s 의 허브 — 조각 목차 · 구 행번호 좌표 대응표' % base)
    out.append('project: GN_DW (굿네이버스)')
    out.append('created: 2026-08-14')
    out.append('created_by: O82')
    out.append('parent: %s' % base)
    out.append('END-METADATA -->')
    out.append('')
    if outdir:
        out.append(OUTDIR_MARK % outdir)
    out.append(BOUNDARY_MARK % mode)
    out.append('')
    out.append('# %s (허브)' % stem)
    out.append('')
    out.append('> 이 파일은 **목차**다. 본문은 `%s%s-001.md` … `-%03d.md` 조각에 있다.'
               % (disp, stem, len(chunks)))
    out.append('> 조각은 **원문 무변경**이다 — 조각 본문을 순서대로 이어붙이면')
    out.append('> 원문과 **SHA256 완전 일치**한다(`scripts/split_doc.py <허브> --verify`).')
    out.append('')
    out.append('> 🔴 **%s SHA256** = `%s`' % (label, digest))
    out.append('> · %s = **%d줄 / %s바이트** · 조각 **%d개** · 상한 **%d줄 AND %dKB**'
               % (label, len(lines), format(nbytes('\n'.join(lines)), ','),
                  len(chunks), MAX_LINES, MAX_BYTES // 1024))
    out.append('')
    out.append('> 🔴 **읽기 규약** — 특정 주제를 찾을 때 조각을 처음부터 다 읽지 말고')
    out.append('> 아래 목차에서 절 이름으로 조각을 고른 뒤 그 조각만 `read` 한다.')
    out.append('> 전량 독해가 필요하면 `-001` 부터 순서대로 읽는다(조각당 `read` 1회).')
    out.append('')
    out.append('> 🔴🔴 **이 허브는 자동 생성물이다 — 여기에 내용을 쓰지 마라.**')
    out.append('> `--republish`·`--rebalance`·`--rollover` 는 이 파일을 **통째로 다시 쓴다**')
    out.append('> ⇒ 허브에 손으로 적은 문장은 **조용히 사라진다**(경고도 나오지 않는다).')
    out.append('> 내용은 **조각(`-001`…)에 쓰고** 아래 명령으로 이 허브를 재발행한다.')
    out.append('')
    out.append('> 🔴 **편집 규약** — 조각 본문을 고치면 위 SHA256 이 깨진다.')
    out.append('> 내용을 갱신할 때는 조각을 직접 편집하고 **이 허브의 SHA256 을 재발행**한다')
    out.append('> (`--verify` 는 「분할 시점 원문과 동일한가」를 묻는 게이트다).')
    out.append('')
    out.append('## 조각 목차')
    out.append('')
    out.append('| 조각 | 구 행범위 | 줄 | KB | 선두 절 |')
    out.append('|---|---|---|---|---|')
    for n, (a, b) in enumerate(chunks, 1):
        t = seg_text(lines, a, b)
        out.append('| `%s%s-%03d.md` | %d~%d | %d | %.1f | %s |' % (
            disp, stem, n, a + 1, b, b - a, nbytes(t) / 1024.0, head_label(lines, a, b)))
    out.append('')
    out.extend(pick_table(lines, chunks, stem, disp, mode))
    out.append('## 구 행번호 → 신 좌표 대응표')
    out.append('')
    out.append('> 분할 전 이 문서를 **「N행」으로 인용한 기존 문장은 수정하지 않았다**')
    out.append('> (O59-K · R2-8 무변경 계약 유지). 대신 이 표로 좌표를 옮긴다.')
    out.append('> 환산식 = **신 행번호 = 구 행번호 − 구간시작 + 1 + %d**' % HEADER_LINES)
    out.append('> (`+%d` = 조각 머리말 %d줄).' % (HEADER_LINES, HEADER_LINES))
    out.append('')
    out.append('| 구 행범위 | 조각 | 그 조각에서의 행 |')
    out.append('|---|---|---|')
    for n, (a, b) in enumerate(chunks, 1):
        out.append('| %d~%d | `%s%s-%03d.md` | %d~%d |' % (
            a + 1, b, disp, stem, n, HEADER_LINES + 1, HEADER_LINES + (b - a)))
    out.append('')
    return '\n'.join(out) + '\n'


def expect_guard(where, text, expect, paths=None):
    """🆕 [2026-08-28 O111-B 신설] 유지 연산의 **신선도·영속성 가드**.

    🔴🔴 왜 필요한가 — 이 워크스페이스에서 **같은 지점에서 두 번** 편집이 사라졌다.
      ㉠ **O107** = `edit` 로 넣은 절(67줄)이 직후 실측으로 확인됐는데, 승인받아 돌린
         `--rebalance` 가 **낡은 내용을 읽어**(2,174줄 ↔ 2,107줄) 전 조각을 그것으로
         재기록해 **편집이 사라졌다**.
      ㉡ **O111** = 원장 §1 `O111` 행을 `edit` 로 넣고 **같은 명령에서 `grep -c` = 1** 을
         확인한 뒤 `--republish` 를 돌렸는데, 나중에 다시 세니 **행이 없었다**
         (조각 스냅샷이 없어 복원은 재작성뿐이었다).
    🔴 **게이트 6종이 두 번 다 전부 🟢 였다.** 이유가 분명하다:
      · `verify()` 는 **자기일관성**(concat ↔ 허브 해시)만 본다 — 내용이 낡아도 일관되면 🟢.
      · `R1-7-2`(해시 안정성)는 **같은 시점 2회 읽기**만 본다 — 이 사고는 **시점 간 불일치**다.
      ⇒ 두 축 모두 **원리적으로** 못 잡는다. 그래서 별도 가드가 필요하다.

    🟢 설계 = **호출자가 「지금 반드시 있어야 하는 토큰」을 선언**하고(`--expect`) 도구가
      ㉠ **쓰기 전** 방금 수집한 내용에 그 토큰이 있는지(신선도) ㉡ **쓴 뒤** 디스크에서
      다시 읽어 여전히 있는지(영속성)를 **둘 다** 단정한다.
      · ㉠ 이 O107 을 막고 ㉡ 가 O111 을 막는다 — **두 사고는 다른 축이므로 둘 다 필요하다.**
      · 🔴 토큰이 없으면 **쓰지 않고 중단**한다(경고가 아니다 — 되돌릴 수 없는 연산이다).

    ⚠️ 이것은 **선언 기반 가드**다 — `--expect` 를 안 주면 검사할 것이 없다.
      그래서 `R1-6-23` 이 「유지 연산에는 `--expect` 를 준다」를 의무로 만든다.
    """
    if not expect:
        return 0
    missing = [t for t in expect if t not in text]
    if missing:
        print('🔴 %s 신선도 FAIL — 방금 수집한 내용에 이 토큰이 없다: %s'
              % (where, ', '.join(missing)))
        print('   ⇒ 파일을 쓰지 않았다. 낡은 내용을 읽었을 가능성이 있다(O107 형).')
        print('   🟢 복구 = 그 편집을 다시 확인하고, 필요하면 다시 쓴 뒤 재실행하라.')
        return 1
    print('  🟢 신선도 가드 통과 — 기대 토큰 %d종 전건 실재' % len(expect))
    return 0


def persist_guard(where, paths, expect):
    """쓰기 **후** 디스크에서 되읽어 토큰 영속성을 단정한다(`expect_guard` ㉡ 축)."""
    if not expect:
        return 0
    blob = []
    for p in paths:
        if os.path.exists(p):
            blob.append(read_text(p))
    joined = '\n'.join(blob)
    missing = [t for t in expect if t not in joined]
    if missing:
        print('🔴🔴 %s 영속성 FAIL — 쓴 뒤 되읽으니 토큰이 없다: %s'
              % (where, ', '.join(missing)))
        print('   ⇒ 쓰기가 반영되지 않았거나 다른 주체가 덮었다(O111 형 · `R1-7-2` 축 밖).')
        print('   🔴 스냅샷 경로를 확인하고 **재작성 복원**을 준비하라.')
        return 1
    print('  🟢 영속성 가드 통과 — 되읽기에서 기대 토큰 %d종 전건 실재' % len(expect))
    return 0


def baseline_snapshot(src):
    """`verify()` 게이트2·3 이 「원문」으로 쓸 **최초 분할 스냅샷**을 찾는다.

    🔴 [2026-08-28 O109] 종전 이름은 `<base>.O82-presplit` **고정**이었다.
    라벨을 인자화하면(`snapshot_util`) 이름이 세션마다 달라지므로, 고정 이름을
    그대로 두면 **기준선을 못 찾아 게이트2·3 이 조용히 건너뛰어진다**
    (검사가 꺼지는 것은 FAIL 보다 나쁘다 · `P106`). ⇒ **패턴으로 찾는다.**
    · 대상 = `<base>.*-presplit` 및 그 접미(`.2` …)
    · 여러 개면 **mtime 가장 오래된 것**(최초 분할 시점)을 쓴다.
    · 없으면 종전 고정 이름을 돌려준다(호출부가 부재를 그대로 보고한다).
    """
    base = os.path.basename(src)
    legacy = os.path.join(ARCHIVE, '%s.O82-presplit' % base)
    if not os.path.isdir(ARCHIVE):
        return legacy
    pre = '%s.' % base
    cands = [os.path.join(ARCHIVE, f) for f in os.listdir(ARCHIVE)
             if f.startswith(pre) and '-presplit' in f[len(pre):]]
    if not cands:
        return legacy
    return min(cands, key=lambda p: (os.path.getmtime(p), p))


def build(src, dry_run, mode, outdir=None, label=None):
    text = read_text(src)
    lines = text.split('\n')
    digest = sha(text)
    levels = LEVELS_ENTRY if mode == 'entry' else LEVELS_SECTION

    atoms = atomize(lines, 0, len(lines), levels)
    chunks = pack(lines, atoms)

    print('원문 %s' % os.path.basename(src))
    print('  %d줄 · %s바이트 · SHA256 %s' % (len(lines), format(nbytes(text), ','), digest[:16]))
    print('  경계 모드 = %s · 원자 %d개 → 조각 %d개' % (mode, len(atoms), len(chunks)))
    over = []
    for n, (a, b) in enumerate(chunks, 1):
        t = seg_text(lines, a, b)
        flag = ''
        # 🔴 [2026-08-18 O83-H] 판정·표시를 「본문」이 아니라 **머리말 포함 파일**로 바꿨다(`R1-6-11`).
        #   종전 `b - a` · `nbytes(t)` 는 머리말 3줄/448B 를 빼고 재어, **파일이 상한을 넘어도
        #   🟢 「전 조각 상한 이내」로 표시**했다. 배치 자체는 `fits()` 가 머리말을 선반영하므로
        #   안전했고, 따라서 이 지점은 **표시상 과소보고**였다(`--verify` 게이트6 은 실제 파일을
        #   읽으므로 정확 — 두 축의 판정 기준이 어긋나 있었다).
        #   🔴 근인 = `HEADER_BYTES 400 → 448` 교정이 **이 지점에 전파되지 않았다** ⇒ `R1-6-17`
        #   「파라미터는 보는 지점을 전수 조사한다」의 3차 누락.
        f_lines = b - a + HEADER_LINES
        f_bytes = nbytes(t) + HEADER_BYTES
        if f_lines > MAX_LINES or f_bytes > MAX_BYTES:
            flag = '  🔴 상한 초과'
            over.append(n)
        print('  -%03d  %5d~%-5d  %3d줄  %5.1fKB  %s%s' % (
            n, a + 1, b, f_lines, f_bytes / 1024.0, head_label(lines, a, b)[:44], flag))
    if over:
        print('🔴 상한 초과 조각 %d개: %s' % (len(over), over))
    else:
        print('🟢 전 조각 상한 이내(%d줄 AND %dKB · 머리말 포함 파일 기준)'
              % (MAX_LINES, MAX_BYTES // 1024))

    if dry_run:
        print('\n--dry-run — 파일을 쓰지 않았다.')
        return 0

    if not os.path.isdir(ARCHIVE):
        os.makedirs(ARCHIVE)
    snapshot(src, 'presplit', label=label, archive=ARCHIVE)

    total = len(chunks)
    if outdir:
        d = os.path.join(os.path.dirname(src), outdir)
        if not os.path.isdir(d):
            os.makedirs(d)
        print('조각 폴더 = %s' % os.path.relpath(d, ROOT))
    for n, (a, b) in enumerate(chunks, 1):
        body = seg_text(lines, a, b)
        head = chunk_header(src, n, total, a, b)
        write_text(chunk_path(src, n, outdir), '\n'.join(head) + '\n' + body)
    write_text(src, build_hub(src, lines, chunks, digest, outdir, mode))
    print('조각 %d개 + 허브 1개 기록 완료.' % total)
    return verify(src)


def collect_bodies(src, outdir=None):
    """조각 본문(센티넬 아래)을 연번 순서로 모아 이어붙인다."""
    n = 1
    parts = []
    paths = []
    while True:
        p = chunk_path(src, n, outdir)
        if not os.path.exists(p):
            break
        t = read_text(p)
        if BODY_BEGIN not in t:
            raise SystemExit('🔴 센티넬 부재: %s' % p)
        body = t.split(BODY_BEGIN + '\n', 1)[1]
        parts.append(body)
        paths.append(p)
        n += 1
    return parts, paths


def family_text(src, chunk_paths):
    """같은 원장 폴더의 **다른 문서** 전문(자기 자신과 자기 조각은 제외).

    🔴 [2026-08-18 O83-B 신설] 게이트 3 이 「유실」과 「이동」을 구별하기 위한 분모다.
    은퇴 이관(`retire_rows.py`)은 토큰을 **같은 폴더의 append형 로그로** 옮기므로
    이 분모에서 찾히면 사고가 아니다. 찾히지 않으면 진짜 유실이다.
    ⚠️ 분모는 **1단계 하위 폴더까지** 본다(조각 폴더 = `01_세션이력_조각/`).
    """
    skip = set(os.path.abspath(p) for p in chunk_paths)
    skip.add(os.path.abspath(src))
    d = os.path.dirname(os.path.abspath(src))
    buf = []
    for root, dirs, files in os.walk(d):
        dirs[:] = [x for x in dirs if x not in ('_archive', '__pycache__', 'logs')]
        if os.path.relpath(root, d).count(os.sep) > 0:
            continue                       # 1단계 하위까지만
        for f in sorted(files):
            if not f.endswith(('.md', '.sql', '.yml', '.csv')):
                continue
            p = os.path.join(root, f)
            if os.path.abspath(p) in skip:
                continue
            try:
                buf.append(read_text(p))
            except (IOError, OSError, UnicodeDecodeError):
                continue
    return '\n'.join(buf)


def verify(src):
    fails = []
    hub = read_text(src)

    m = re.search(r'\*\*(?:원문|발행) SHA256\*\* = `([0-9a-f]{64})`', hub)
    if not m:
        print('🔴 허브에 SHA256 이 없다 — 허브가 아니거나 손상됐다.')
        print('   기대 형식: `> 🔴 **원문 SHA256** = ...` (분할 직후)')
        print('             `> 🔴 **발행 SHA256** = ...` (조각 편집 후 재발행 · R1-6-9)')
        return 1
    want = m.group(1)
    republished = '발행 SHA256' in hub

    parts, paths = collect_bodies(src, hub_outdir(src))
    if not parts:
        print('🔴 조각이 없다.')
        return 1
    joined = '\n'.join(parts)

    # 게이트 1 — 조각 본문 concat == 허브가 발행한 해시
    got = sha(joined)
    ok1 = (got == want)
    label = '발행' if republished else '원문'
    print('게이트1 concat SHA256: %s' % ('일치 (%s 기준)' % label if ok1
                                       else '불일치 (%s %s / 현재 %s)' % (label, want[:16], got[:16])))
    if not ok1:
        fails.append('SHA256 불일치 — 본문이 변경됐다')

    # 게이트 2·3 — 원문 스냅샷 대조.
    # 🔴 [2026-08-18 O82-C] **재발행 상태에서는 이 두 축이 정상적으로 어긋난다.**
    #   `R1-6-9` 는 조각을 편집한 뒤 허브 해시를 재발행하라고 규정하는데, 그렇게 하면
    #   내용이 원문과 달라지므로 「줄 수 동일·토큰 유실 0」을 요구하면 **정상 갱신이 FAIL** 이 된다.
    #   ⇒ 재발행 상태에서는 **토큰 유실만 관측**하고(갱신은 추가가 정상) FAIL 로 올리지 않는다.
    #   ⚠️ 단 **토큰이 줄어들면** 그것은 갱신이 아니라 소실이므로 그대로 보고한다.
    snap = baseline_snapshot(src)
    if os.path.exists(snap):
        orig = read_text(snap)
        ol = len(orig.split('\n'))
        nl = len(joined.split('\n'))
        print('게이트2 줄 수: 원문 %d · concat %d%s'
              % (ol, nl, '  (재발행 — 차이 허용)' if republished else ''))
        if ol != nl and not republished:
            fails.append('줄 수 불일치 %d ≠ %d' % (ol, nl))

        # 게이트 3 — 수치·ID 토큰 종수 보존(O66 정규식 상속)
        def toks(s):
            return set(re.findall(
                r'\d[\d,\.]*%?|(?:O|P|DEC|Q|CONF|PROC|OPS|BLOCKING|AD|SVL|R)\d+(?:-[0-9A-Z]+)?', s))
        ot, nt = toks(orig), toks(joined + hub)
        lost = sorted(ot - nt)
        print('게이트3 토큰 종수: 원문 %d · 이후 %d · 유실 %d' % (len(ot), len(nt), len(lost)))
        if lost:
            # 🔴 [2026-08-18 O83-B 교정] 종전 전제 **「갱신은 토큰을 늘리지 줄이지 않는다」는 깨졌다.**
            #   `retire_rows.py` 의 **은퇴 이관**(사용자 결정 C)은 닫힌 행의 장문 셀을
            #   `90_해소완료_로그.md` 로 **의도적으로** 내보낸다 ⇒ 이 문서에서 토큰이 줄어드는 것이
            #   **정상**이다. 실측: 은퇴 6행 후 이 게이트가 **33종 유실**로 FAIL 했다(오탐).
            #   🔴 그렇다고 검사를 끄면 진짜 유실이 조용해진다(`P106`) ⇒ **행선지를 찾는다**:
            #   같은 원장 폴더(문서 계열)에 그 토큰이 있으면 **「이동」**, 어디에도 없으면 **「유실」**이다.
            #   이것이 `R2-8-1`(삭제 전 토큰 대조)의 이 게이트판이다.
            elsewhere = family_text(src, paths)
            movedt = [t for t in lost if t in elsewhere]
            gone = [t for t in lost if t not in elsewhere]
            print('  ├ 이동 확인(같은 폴더 타 문서에 실재) %d종' % len(movedt))
            print('  └ 행선지 없음 %d종' % len(gone))
            if gone:
                fails.append('토큰 유실 %d종(행선지 없음): %s' % (len(gone), ', '.join(gone[:20])))
    else:
        print('게이트2·3 건너뜀 — 스냅샷 부재(%s)' % os.path.relpath(snap, ROOT))

    # 게이트 4 — 한 줄 2,000자 (R1-5-4)
    over = []
    for p in [src] + paths:
        for n, l in enumerate(read_text(p).split('\n'), 1):
            if len(l) > 2000:
                over.append('%s:%d (%d자)' % (os.path.basename(p), n, len(l)))
    print('게이트4 2,000자 초과 줄: %d' % len(over))
    if over:
        fails.append('한도 초과: ' + ', '.join(over[:10]))

    # 게이트 5 — 표 열수 정합(조각 경계가 표를 깨지 않았는가)
    #   🔴 `|` 개수를 세면 안 된다 — 백틱 코드스팬·이스케이프 `\|` 때문에 오탐이 난다
    #   (O66 최초 실행이 이 축이 없어 실제로 표를 깨뜨렸다) ⇒ split_row 를 상속한다.
    #   🔴 판정은 절대건수가 아니라 **원문 대비 증가분**이다. 원문에 이미 있던
    #   열수 결손을 이 스크립트가 고칠 권한은 없다(무변경 계약).
    def col_violations(text):
        bad = []
        hdr_n, hdr_line = None, 0
        for n, l in enumerate(text.split('\n'), 1):
            s = l.strip()
            if not s.startswith('|'):
                hdr_n = None
                continue
            if set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
                continue
            try:
                got = len(split_row(s))
            except AssertionError:
                continue
            if hdr_n is None:
                hdr_n, hdr_line = got, n
                continue
            if got != hdr_n:
                bad.append('%d행 %d열 (헤더 %d행 = %d열)' % (n, got, hdr_line, hdr_n))
        return bad

    chunk_bad = []
    for p in paths:
        for b in col_violations(read_text(p)):
            chunk_bad.append('%s:%s' % (os.path.basename(p), b))
    if os.path.exists(snap):
        orig_bad = col_violations(read_text(snap))
        print('게이트5 표 열수 결손: 원문 %d · 조각 %d (증가 %d)'
              % (len(orig_bad), len(chunk_bad), len(chunk_bad) - len(orig_bad)))
        if len(chunk_bad) > len(orig_bad):
            fails.append('분할이 표를 깼다(증가 %d): %s'
                         % (len(chunk_bad) - len(orig_bad), ' / '.join(chunk_bad[:10])))
        elif chunk_bad:
            print('  ⚠️ 원문에 이미 있던 결손 %d건이 조각에 그대로 있다(무변경 계약상 정상):'
                  % len(chunk_bad))
            for b in chunk_bad[:10]:
                print('     ', b)
    else:
        print('게이트5 표 열수 결손: 조각 %d (원문 대조 불가 — 스냅샷 부재)' % len(chunk_bad))
        if chunk_bad:
            fails.append('열수 결손: ' + ' / '.join(chunk_bad[:10]))

    # 게이트 6 — 조각 상한(300줄 AND 40KB)
    big = []
    for p in paths:
        t = read_text(p)
        n = len(t.split('\n'))
        if n > MAX_LINES or nbytes(t) > MAX_BYTES:
            big.append('%s (%d줄 %.1fKB)' % (os.path.basename(p), n, nbytes(t) / 1024.0))
    print('게이트6 조각 상한 초과: %d' % len(big))
    if big:
        fails.append('상한 초과: ' + ' / '.join(big[:10]))

    if fails:
        print('\n🔴 FAIL')
        for f in fails:
            print(' -', f)
        return 1
    print('\n🟢 PASS — 본문 바이트 동일 · 유실 0 · 상한 초과 0')
    return 0


def republish(src, snap_label=None, expect=None):
    """조각을 편집한 뒤 허브를 **다시 만든다**(`R1-6-9` 의 집행 도구).

    🔴 [2026-08-18 O83 신설] `R1-6-9` 는 「조각 편집 후 허브 SHA256 재발행」을 규정하고
    `verify()` 는 `발행 SHA256` 라벨을 **읽을 수** 있는데, 그 라벨을 **쓰는 도구가 없었다**
    (O82-C 가 읽는 쪽만 열었다). 그래서 사람이 64자 해시를 **손으로** 적어야 했고,
    그것은 오타 1글자로 게이트를 영구 FAIL 로 만드는 손 편집이다.
    ⇒ 규정만 있고 도구가 없는 구간을 닫는다(조문 = 집행 장치가 있어야 지켜진다).

    🔴 [2026-08-28 O107 교정] 종전 구현은 **해시 1줄만 정규식 치환**했다 ⇒ 두 결함이 있었다.
    * ㉠ **목차가 stale 이 된다**: 조각을 편집하면 줄 수·KB·구 행범위가 달라지는데
      목차는 분할 시점 값을 그대로 들고 있었다(`--rebalance`·`--rollover` 만 다시 썼다).
      ⇒ 「수를 문서에 박아 두면 stale 이 된다」는 `R3-9 ㉦` 와 **같은 축의 결함**이고,
      허브가 자동 생성물인데도 **자동으로 갱신되지 않는 구간**이 남아 있었다.
    * ㉡ 목차 형식을 보강해도 `--republish` 로는 **반영 경로가 없었다**.
    ⇒ 이제 **`build_hub` 로 통째로 다시 쓴다**. 허브는 자동 생성물이므로 이것이 계약이고
      (`R1-6` · 허브에 손으로 쓴 문장은 사라진다), 조각 파일은 **한 바이트도 건드리지 않는다**.
    ⚠️ 그래도 되돌림 경로를 남긴다 — 재작성 전 허브를 `_archive/<base>.<label>-prehub` 로 스냅샷한다(라벨 = `--label`)
      (`R1-7-6`: 스테이지에는 redo 가 없다).
    """
    if not os.path.exists(src):
        print('🔴 허브가 없다: %s' % src)
        return 1
    outdir = hub_outdir(src)
    mode = hub_boundary(src)
    parts, paths = collect_bodies(src, outdir)
    if not parts:
        print('🔴 조각이 없다 — 재발행 대상이 아니다.')
        return 1

    logical = '\n'.join(parts)
    lines = logical.split('\n')
    digest = sha(logical)

    # 조각 경계는 **현재 조각 파일 그대로**다(배치를 바꾸지 않는다 — 그것은 --rebalance 소관).
    chunks = []
    off = 0
    for p in parts:
        n = len(p.split('\n'))
        chunks.append((off, off + n))
        off += n

    # 🆕 [O111-B] 쓰기 전 **신선도 가드** — 낡은 내용을 읽었으면 여기서 멈춘다(O107 형).
    if expect_guard('republish', logical, expect):
        return 1

    if not os.path.isdir(ARCHIVE):
        os.makedirs(ARCHIVE)
    snap, _st = snapshot(src, 'prehub', label=snap_label, archive=ARCHIVE)

    write_text(src, build_hub(src, lines, chunks, digest, outdir, mode, label='발행'))
    print('🟢 허브 재구성 %s — 조각 %d개 · 발행 SHA256 %s'
          % (os.path.basename(src), len(parts), digest[:16]))
    print('   재작성 전 허브 스냅샷 = %s' % os.path.relpath(snap, ROOT))
    print('   허브 %s B (상한 %d B · 여유 %d B)'
          % (format(nbytes(read_text(src)), ','), MAX_BYTES,
             MAX_BYTES - nbytes(read_text(src))))
    # 🆕 [O111-B] 쓴 뒤 **영속성 가드** — 조각을 되읽어 토큰이 살아 있는지 본다(O111 형).
    #   🔴 `republish` 는 조각을 쓰지 않지만, 「조각이 지금도 그 내용인가」는 여기서 확인해야
    #     의미가 있다(허브를 그 내용으로 발행했다고 선언하는 시점이 여기다).
    if persist_guard('republish', paths, expect):
        return 1
    return verify(src)


def rebalance(src, mode=None, fill=0.7, snap_label=None, expect=None):
    """허브+조각을 **현재 내용**으로 재분할해 상한 여유를 회복한다(`R1-6-14`).

    🔴 왜 필요한가 (2026-08-18 O83-B 실측): 갱신형 원장은 신규 행이 표 머리(최신 우선)에
    떨어져 **항상 같은 조각**으로 간다. 인덱스 `-001` 여유 **178B** ↔ 세션당 추가 ≈ **1,200B**
    ⇒ 다음 편집에서 **반드시** 초과한다. 조각 편집은 국소 연산인데 상한 회복은
    **문서 전체 재분할**을 요구한다(B-tree 의 split 과 같은 구조) — 그 연산이 없었다.
    ⚠️ `--republish` 는 허브를 다시 쓸 뿐 **조각 배치는 그대로 둔다** ⇒ 초과를 해결하지 못한다.

    계약:
    * 기준은 **원문 스냅샷이 아니라 현재 조각 내용**이다(그 사이 편집이 정본이다).
    * 재분할 전 논리 문서를 `_archive/<base>.<label>-prerebalance` 로 스냅샷한다(라벨 = `--label`).
    * 조각 수가 줄면 **남는 조각 파일을 개별 삭제**한다 —
      🔴 폴더를 `rm -rf` 하지 않는다(`R1-6-10`: 스테이지 접두 삭제로 허브까지 지워진다).
    * 허브는 `발행 SHA256` 라벨로 재발행한다(원문과 이미 다르기 때문이다).
    """
    outdir = hub_outdir(src)
    mode = mode or hub_boundary(src)
    parts, paths = collect_bodies(src, outdir)
    if not parts:
        print('🔴 조각이 없다 — 재균형 대상이 아니다.')
        return 1
    logical = '\n'.join(parts)
    lines = logical.split('\n')
    digest = sha(logical)
    print('재균형 대상 %s' % os.path.basename(src))
    print('  현재 조각 %d개 · 논리 문서 %d줄 · %s바이트 · 경계 %s · 목표 채움 %.0f%%'
          % (len(paths), len(lines), format(nbytes(logical), ','), mode, fill * 100))

    levels = LEVELS_ENTRY if mode == 'entry' else LEVELS_SECTION
    chunks = pack(lines, atomize(lines, 0, len(lines), levels, 0, fill), fill)
    over = [n for n, (a, b) in enumerate(chunks, 1) if not fits(lines, a, b)]
    if over:
        print('🔴 재분할 후에도 상한 초과 조각 %s — 경계를 못 찾았다.' % over)
        return 1

    # 🆕 🔴🔴 [O111-B] **여기가 O107 사고 지점이다** — `collect_bodies` 가 낡은 내용을 읽으면
    #   그 낡은 내용으로 **전 조각을 재기록**해 편집이 사라진다. 쓰기 전에 반드시 막는다.
    if expect_guard('rebalance', logical, expect):
        return 1

    if not os.path.isdir(ARCHIVE):
        os.makedirs(ARCHIVE)
    snap, _st = snapshot_content(src, 'prerebalance', logical, label=snap_label, archive=ARCHIVE)
    print('  재균형 전 스냅샷 = %s' % os.path.relpath(snap, ROOT))

    total = len(chunks)
    for n, (a, b) in enumerate(chunks, 1):
        head = chunk_header(src, n, total, a, b)
        write_text(chunk_path(src, n, outdir), '\n'.join(head) + '\n' + seg_text(lines, a, b))
    # 조각 수가 줄었으면 잉여 파일을 개별 삭제한다(폴더 삭제 금지 · R1-6-10)
    removed = 0
    n = total + 1
    while True:
        p = chunk_path(src, n, outdir)
        if not os.path.exists(p):
            break
        os.remove(p)
        removed += 1
        n += 1
    write_text(src, build_hub(src, lines, chunks, digest, outdir, mode, label='발행'))
    print('  조각 %d개 재기록 · 잉여 삭제 %d개 · 허브 재발행 %s' % (total, removed, digest[:16]))
    sizes = [nbytes(read_text(chunk_path(src, k, outdir))) for k in range(1, total + 1)]
    print('  조각 크기 max %d B · 최소 여유 %d B' % (max(sizes), MAX_BYTES - max(sizes)))
    # 🆕 [O111-B] 재기록한 **새 조각 경로**를 되읽어 영속성을 단정한다.
    if persist_guard('rebalance',
                     [chunk_path(src, k, outdir) for k in range(1, total + 1)],
                     expect):
        return 1
    return verify(src)


def rollover(src, text_path=None):
    """append형 문서의 **꼬리 조각**에 항목을 추가한다. 차면 새 조각을 만든다(`R1-6-15`).

    🔴 왜 필요한가 (2026-08-18 O83-B): append형은 구조적으로 갱신형보다 쉽다 —
    추가가 **항상 꼬리**에 떨어지므로 기존 조각은 **불변**이고, 꼬리가 차면
    **새 조각 1개를 만들면 끝**이다(O(1) 국소 연산 · 재균형 불요).
    그런데 도구에는 그 연산이 없어 `--rebalance` 로 전체를 다시 쪼개야 했고,
    그러면 조각 경계가 매번 이동해 **append형의 유일한 장점인 불변성이 사라진다**.
    ⇒ 이 함수가 그 공백을 닫는다.

    사용:
      python3 scripts/split_doc.py <허브> --rollover --entry-file <추가할.md>

    계약:
    * 꼬리 조각에 넣어 **상한 이내면 append**, 넘치면 **다음 연번 조각을 신설**한다.
    * 기존 조각(`-001`…`-0NN-1`)은 **한 바이트도 건드리지 않는다**.
    * 허브는 `발행 SHA256` 으로 재발행하고 게이트 6종을 돌린다.
    """
    if not text_path:
        print('🔴 --entry-file 이 필요하다(추가할 본문 파일).')
        return 1
    if not os.path.exists(text_path):
        print('🔴 추가할 본문 파일이 없다: %s' % text_path)
        return 1
    entry = read_text(text_path).rstrip('\n')
    if not entry.strip():
        print('🔴 추가할 본문이 비어 있다.')
        return 1

    outdir = hub_outdir(src)
    parts, paths = collect_bodies(src, outdir)
    if not parts:
        print('🔴 조각이 없다 — 롤오버 대상이 아니다.')
        return 1

    tail_n = len(paths)
    tail_body = parts[-1]
    merged = tail_body.rstrip('\n') + '\n\n' + entry + '\n'
    mlines = merged.split('\n')
    if fits(mlines, 0, len(mlines)):
        # 꼬리 조각에 여유가 있다 — append
        head = read_text(paths[-1]).split(BODY_BEGIN + '\n', 1)[0] + BODY_BEGIN + '\n'
        write_text(paths[-1], head + merged)
        target, created = os.path.basename(paths[-1]), False
    else:
        # 꼬리가 찼다 — 다음 연번 조각을 신설한다(기존 조각 불변)
        new_n = tail_n + 1
        body = entry + '\n'
        blines = body.split('\n')
        if not fits(blines, 0, len(blines)):
            print('🔴 추가할 항목 자체가 상한을 넘는다(%d줄 / %s B) — 항목을 나눠라.'
                  % (len(blines), format(nbytes(body), ',')))
            return 1
        head = chunk_header(src, new_n, new_n, 0, len(blines))
        write_text(chunk_path(src, new_n, outdir), '\n'.join(head) + '\n' + body)
        target, created = os.path.basename(chunk_path(src, new_n, outdir)), True

    print('🟢 %s %s (항목 %s B)'
          % (target, '신설' if created else 'append', format(nbytes(entry), ',')))
    parts, paths = collect_bodies(src, outdir)
    logical = '\n'.join(parts)
    lines = logical.split('\n')
    chunks = []
    off = 0
    for p in parts:                     # 허브 목차용 구간 재계산(내용은 이미 확정이다)
        n = len(p.split('\n'))
        chunks.append((off, off + n))
        off += n
    write_text(src, build_hub(src, lines, chunks, sha(logical), outdir,
                              hub_boundary(src), label='발행'))
    sizes = [nbytes(read_text(p)) for p in paths]
    print('  조각 %d개 · max %d B · 최소 여유 %d B' % (len(paths), max(sizes), MAX_BYTES - max(sizes)))
    return verify(src)


def published_digest(src):
    """허브에 발행된 SHA256(원문|발행 라벨 무관). 없으면 None."""
    if not os.path.exists(src):
        return None
    m = re.search(r'\*\*(?:원문|발행) SHA256\*\* = `([0-9a-f]{64})`', read_text(src))
    return m.group(1) if m else None


def to_outdir(src, folder, apply=False, drop=False, snap_label=None):
    """이미 분할된 문서의 **형제 조각을 하위 폴더로 이전**한다(`R1-6-21`).

    🔴 [2026-08-28 O107 신설] `--outdir` 는 **최초 `build` 전용**이었다 ⇒ 이미 형제로 쪼갠 문서를
      폴더로 옮기는 연산이 **없었다**. 허브 마커만 손으로 바꾸면 `--rebalance` 가 폴더에 쓰지만
      **기존 형제 조각이 남아** 같은 본문이 두 곳에 존재한다(게이트가 중복·유실로 흔들린다).

    🔴🔴 [2026-08-28 O107-D 재설계 · 자기비판으로 적발] **초판은 위험했다.**
      초판은 ㉠ digest 를 **형제 읽기에서 뽑고** ㉡ 폴더를 되읽어 비교한 뒤 ㉢ 같은 실행에서
      형제를 **지웠다**. 형제 읽기가 stale 이면 **양쪽이 같이 stale** 이라 검증이 통과하고
      **fresh 내용을 담은 형제가 삭제**된다 — `§O107-B` 사고(재균형이 stale 을 읽어 편집 소실)의
      **증폭판**이다(그때는 원본이 남았지만 여기서는 지운다). 게다가 초판은
      **스냅샷을 만들지 않는 유일한 파괴 연산**이었다(`build`·`rebalance`·`republish` 는 만든다).

    ⇒ 방어 3중:
    * **선행 해시 대조(blocking)** — 허브에 **발행된 SHA256** ↔ 형제 concat 이 같아야 착수한다.
      다르면 「미재발행 편집」이거나 「stale 읽기」다 ⇒ 중단하고 `--republish` 를 먼저 요구한다.
      🔴 이것만으로는 부족하다(둘이 함께 stale 일 수 있다) — 그래서 아래 2단계가 있다.
    * **2단계 분리** — 1단계는 폴더에 **복사만** 하고 **형제·마커를 그대로 둔다**.
      2단계(`--drop-siblings`)에서 **형제·폴더·허브 해시를 그 시점에 다시 읽어** 3자 일치를
      확인한 뒤 삭제한다. ⇒ **시점이 다른 두 번째 읽기**가 생겨 시점 간 불일치를 잡는다
      (`R1-7-2` 의 「같은 시점 2회」로는 잡히지 않는 축이다).
    * **스냅샷** — 1단계에서 논리 문서를 `_archive/<base>.<label>-pretooutdir` 로 남긴다.

    계약:
    * 🔴 폴더명 **`_조각` 접미 필수** — 접두가 허브 파일명을 삼키면 `rm` 한 번에 허브가 날아간다
      (`R1-6-10` 실사고). 접미가 없으면 **거부**한다.
    * 🔴 삭제는 **파일 개별 삭제**(`R1-7-7`) · 기본 **dry-run**(쓰려면 `--apply`).
    * 🔴 **이미 폴더 방식이면 거부**(멱등).
    """
    if hub_outdir(src):
        print('🔴 이미 폴더 방식이다(마커 = %s) — 이전 대상이 아니다.' % hub_outdir(src))
        return 1
    if not folder.endswith('_조각'):
        print('🔴 폴더명에 `_조각` 접미가 없다: %r' % folder)
        print('   근거 = R1-6-10. 스테이지의 「폴더」는 경로 접두라 접미가 없으면')
        print('   그 접두가 허브 파일명까지 포함해 삭제 시 허브가 함께 지워진다(실사고 1회).')
        return 1
    parts, sib = collect_bodies(src, None)
    if not parts:
        print('🔴 형제 조각이 없다 — 이전 대상이 아니다.')
        return 1
    logical = '\n'.join(parts)
    lines = logical.split('\n')
    digest = sha(logical)

    # ── 방어 1: 선행 해시 대조 (blocking) ────────────────────────────────────
    pub = published_digest(src)
    if pub is None:
        print('🔴 허브에 SHA256 이 없다 — 이전할 수 없다(허브가 아니거나 손상됐다).')
        return 1
    if pub != digest:
        print('🔴 허브 발행 해시 ↔ 형제 concat 불일치 — **이전하지 않는다**.')
        print('   허브 %s / 형제 %s' % (pub[:16], digest[:16]))
        print('   원인 후보 = ㉠ 조각을 편집하고 `--republish` 를 안 했다')
        print('              ㉡ 스테이지가 낡은 내용을 반환했다(§O107-B 사고와 같은 축)')
        print('   ⇒ `--republish` 로 기준선을 맞추고, 그 뒤 이 명령을 다시 실행하라.')
        return 1
    print('🟢 선행 대조 통과 — 허브 발행 해시 == 형제 concat (%s)' % digest[:16])

    chunks, off = [], 0
    for p in parts:
        n = len(p.split('\n'))
        chunks.append((off, off + n))
        off += n
    d = os.path.join(os.path.dirname(src), folder)

    # ── 2단계: 형제 삭제 + 마커 갱신 ────────────────────────────────────────
    if drop:
        fparts, fpaths = collect_bodies(src, folder)
        if not fparts:
            print('🔴 폴더 조각이 없다 — 1단계(`--to-outdir … --apply`)를 먼저 실행하라.')
            return 1
        fdig = sha('\n'.join(fparts))
        print('2단계 삭제 대상 %s' % os.path.basename(src))
        print('  형제 %d개 · 폴더 %d개' % (len(sib), len(fpaths)))
        print('  해시 3자 = 허브 %s / 형제 %s / 폴더 %s'
              % (pub[:16], digest[:16], fdig[:16]))
        if len(fparts) != len(parts) or fdig != digest:
            print('🔴 폴더 ↔ 형제 불일치 — **삭제하지 않는다**.')
            print('   1단계를 다시 실행해 폴더를 갱신하라(그 사이 조각이 편집됐을 수 있다).')
            return 1
        print('  🟢 3자 일치 — 본문이 폴더에 온전하다(시점이 다른 두 번째 읽기로 확인)')
        if not apply:
            print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
            return 0
        removed = []
        for p in sib:
            os.remove(p)
            removed.append(os.path.basename(p))
        stem = os.path.splitext(os.path.basename(src))[0]
        left = [f for f in os.listdir(os.path.dirname(src) or '.')
                if re.match(re.escape(stem) + r'-\d{3}\.md$', f)]
        print('  형제 개별 삭제 %d개 · 잔존 %d개%s'
              % (len(removed), len(left), (' 🔴 %s' % left) if left else ''))
        if left:
            print('🔴 형제가 남았다 — 허브 마커를 바꾸지 않는다(중복 상태를 만들지 않기 위해).')
            return 1
        write_text(src, build_hub(src, lines, chunks, digest, folder,
                                  hub_boundary(src), label='발행'))
        print('  허브 재구성 완료 — SPLIT-OUTDIR 마커 = %s' % folder)
        rc = verify(src)
        print('\n🔴 이어서 실행하라(분모가 형제 파일명에 의존하는 곳이 있다):')
        print('   python3 scripts/doc_census.py            # FAMILIES 선언을 폴더명으로 고쳤는가')
        print('   python3 scripts/doc_line_length_gate.py --self-check  # glob 0건 자가검출')
        print('   python3 scripts/decision_closure_gate.py # 결정 분모가 0건이 되지 않았는가')
        print('   python3 scripts/session_brief.py --write # 착수표·인수인계가 비지 않았는가')
        print('   🔴 `cortex ws ls` 로 스테이지 실체를 확인하라(`ls` 는 낡은 뷰를 준다 · OPS-3).')
        return rc

    # ── 1단계: 폴더에 복사(형제·마커는 그대로 둔다) ──────────────────────────
    print('1단계 이전 대상 %s' % os.path.basename(src))
    print('  형제 조각 %d개 → 폴더 %s/ (복사만 · 형제와 마커는 유지)' % (len(sib), folder))
    print('  논리 문서 %d줄 · %s B · SHA256 %s'
          % (len(lines), format(nbytes(logical), ','), digest[:16]))
    if not apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    if not os.path.isdir(ARCHIVE):
        os.makedirs(ARCHIVE)
    snap, _st = snapshot_content(src, 'pretooutdir', logical, label=snap_label, archive=ARCHIVE)
    print('  삭제 전 논리 문서 스냅샷 = %s' % os.path.relpath(snap, ROOT))

    if not os.path.isdir(d):
        os.makedirs(d)
    total = len(chunks)
    for n, (a, b) in enumerate(chunks, 1):
        head = chunk_header(src, n, total, a, b)
        write_text(chunk_path(src, n, folder), '\n'.join(head) + '\n' + seg_text(lines, a, b))
    new_parts, _ = collect_bodies(src, folder)
    got = sha('\n'.join(new_parts))
    print('  폴더 조각 %d개 기록 · concat %s' % (total, got[:16]))
    if len(new_parts) != total or got != digest:
        print('🔴 폴더 concat 불일치 — 형제는 그대로 두었다(손실 0). 원인을 확인하고 다시 실행하라.')
        return 1
    print('  🟢 폴더 concat 일치 — 본문이 두 곳에 있다(형제 = 아직 정본 · 마커 미변경)')
    print('\n🔴 2단계는 **별도 호출**이다 — 그사이 게이트로 폴더를 검증하고 나서 실행하라:')
    print('   python3 scripts/split_doc.py %s --to-outdir %s --drop-siblings --apply'
          % (os.path.relpath(src, ROOT), folder))
    print('   ⚠️ 2단계는 형제·폴더·허브 해시를 **그 시점에 다시 읽어** 3자 일치를 확인한다')
    print('      (시점이 다른 두 번째 읽기 = stale read 방어 · `R1-7-2` 로는 잡히지 않는 축).')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('path', help='분할 대상(또는 --verify 시 허브) 경로')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--verify', action='store_true')
    ap.add_argument('--to-outdir', default=None,
                    help='이미 분할된 문서의 형제 조각을 이 하위 폴더로 **복사**한다(1단계 · `_조각` 접미 필수)')
    ap.add_argument('--drop-siblings', action='store_true',
                    help='2단계 — 해시 3자 일치 확인 후 형제를 개별 삭제하고 허브 마커를 갱신한다')
    ap.add_argument('--apply', action='store_true',
                    help='--to-outdir 를 실제로 집행한다(기본은 dry-run)')
    ap.add_argument('--republish', action='store_true',
                    help='조각 편집 후 허브를 다시 만든다(목차·선택표·발행 SHA256 · R1-6-9)')
    ap.add_argument('--rebalance', action='store_true',
                    help='현재 조각 내용으로 재분할해 상한 여유를 회복한다(R1-6-14)')
    ap.add_argument('--rollover', action='store_true',
                    help='append형 꼬리 조각에 항목 추가 · 차면 새 조각 신설(R1-6-15)')
    ap.add_argument('--entry-file', default=None,
                    help='--rollover 로 추가할 본문 파일 경로')
    # 🔴 default=None — 「미지정」과 「section 지정」을 구별해야 한다.
    #   `--rebalance` 는 미지정이면 허브의 SPLIT-BOUNDARY 마커를 따른다.
    ap.add_argument('--boundary', choices=['section', 'entry'], default=None)
    ap.add_argument('--fill', type=float, default=0.7,
                    help='--rebalance 목표 채움 비율(기본 0.7 = 조각당 약 12KB 여유 확보)')
    ap.add_argument('--outdir', default=None,
                    help='조각을 이 하위 폴더에 둔다(허브는 원 위치 유지). 예: 01_세션이력_조각')
    # 🔴 [2026-08-28 O109] 스냅샷 라벨 — 하드코딩된 세션 라벨을 대체한다(인수 ▣WWW ①).
    add_label_arg(ap)
    # 🆕 🔴🔴 [2026-08-28 O111-B] `--expect` = **이 연산 뒤에도 반드시 살아 있어야 하는 토큰**.
    #   두 번 편집이 사라진 지점(O107 `--rebalance` · O111 `--republish` 직후)에 가드를 건다.
    #   · 쓰기 **전** = 방금 수집한 내용에 있는가(신선도 · 낡은 읽기 차단)
    #   · 쓴 **뒤** = 디스크에서 되읽어도 있는가(영속성 · 조용한 소실 차단)
    #   🔴 없으면 **쓰지 않고 exit 1**. 여러 번 줄 수 있다.
    ap.add_argument('--expect', action='append', default=None, metavar='TOKEN',
                    help='유지 연산 전후로 실재를 단정할 토큰(반복 가능 · R1-6-23)')
    a = ap.parse_args()
    src = a.path if os.path.isabs(a.path) else os.path.join(ROOT, a.path)
    if not os.path.exists(src):
        raise SystemExit('🔴 경로 부재: %s' % src)
    if a.to_outdir:
        return to_outdir(src, a.to_outdir, a.apply, a.drop_siblings, snap_label=a.label)
    if a.rollover:
        p = a.entry_file
        if p and not os.path.isabs(p):
            p = os.path.join(ROOT, p)
        return rollover(src, p)
    if a.rebalance:
        return rebalance(src, a.boundary, a.fill, snap_label=a.label, expect=a.expect)
    if a.republish:
        return republish(src, snap_label=a.label, expect=a.expect)
    if a.verify:
        return verify(src)
    return build(src, a.dry_run, a.boundary or 'section', a.outdir, label=a.label)


if __name__ == '__main__':
    sys.exit(main())
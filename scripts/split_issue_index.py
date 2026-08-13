#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-13 O66] 이슈원장 INDEX 장문 표행 → 상세 문서 무변경 이관.

문제: `00_INDEX_이슈원장.md` 의 표 셀 하나에 세션 서술 전체가 들어가 1줄이
      2,000자를 넘고, `read` 툴이 그 행 말미를 절단한다(정본 미독 = R1-3 위반).
      마크다운 표 셀은 줄바꿈이 불가하므로 표에 둔 채로는 줄 길이를 줄일 수 없다.

처방: 장문 셀을 상세 문서로 **무변경 이관**하고 인덱스에는 verbatim 접두 + 포인터만 남긴다.

무변경의 정의(이 스크립트의 계약):
  이관은 **단일 공백을 줄바꿈으로 치환**하는 것만 허용한다. 문자 추가·삭제·수정 0.
  ⇒ 공백 정규화(`\\s+`→' ') 후 원문과 이관문이 **문자열로 완전 일치**해야 한다(gate).
  ⇒ 마크다운 렌더링 결과도 동일하다(단락 내 줄바꿈 = 공백).

실행:
  python3 scripts/split_issue_index.py --dry-run   # 대상만 출력
  python3 scripts/split_issue_index.py             # 이관 실행
  python3 scripts/split_issue_index.py --verify     # 보존 게이트만 재실행
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDX = os.path.join(ROOT, '20_issue', '00_INDEX_이슈원장.md')
DETAIL_STATUS = os.path.join(ROOT, '20_issue', '02_상태상세_대시보드_갱신형.md')
DETAIL_ISSUE = os.path.join(ROOT, '20_issue', '03_이슈상세.md')

# 이관 임계 = 표 행 전체 길이(문자). read 툴 한도 2,000자에 대해 넉넉한 여유를 둔다.
ROW_THRESHOLD = 1000
# 인덱스에 남길 verbatim 접두의 목표 길이
KEEP_TARGET = 170
KEEP_HARDCAP = 320
# 상세 문서 1줄 목표 길이
WRAP_TARGET = 150
WRAP_HARDCAP = 300


def read_text(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read()


def write_text(path, text):
    with io.open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


def norm(s):
    """공백 정규화 — 보존 판정의 유일한 기준."""
    return re.sub(r'\s+', ' ', s).strip()


def split_row(line):
    """표 행 → 셀 목록.

    🔴 `|` 는 세 경우에 구분자가 아니다: ① `\\|` 이스케이프 ② 백틱 코드스팬 내부
    ③ 앞뒤 파이프. ②를 놓치면 인용문 속 표(`` `| **DEC-8** | …` ``)가 셀을 쪼개
    행의 열수를 늘린다(O66 최초 실행에서 실제로 O64 행이 깨졌다).
    """
    body = line.strip()
    assert body.startswith('|') and body.endswith('|'), body[:40]
    body = body[1:-1]
    cells, buf, i, in_code = [], [], 0, False
    while i < len(body):
        ch = body[i]
        if ch == '\\' and i + 1 < len(body):
            buf.append(body[i:i + 2])
            i += 2
            continue
        if ch == '`':
            in_code = not in_code
            buf.append(ch)
            i += 1
            continue
        if ch == '|' and not in_code:
            cells.append(''.join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    cells.append(''.join(buf))
    return [c.strip() for c in cells]


def wrap_verbatim(text, target=WRAP_TARGET, hardcap=WRAP_HARDCAP):
    """단일 공백만 줄바꿈으로 치환해 여러 줄로 만든다(문자 보존)."""
    words = text.split(' ')
    lines, cur = [], ''
    for w in words:
        cand = w if not cur else cur + ' ' + w
        if not cur:
            cur = cand
            continue
        if len(cur) >= target and (cur.endswith(('.', '·', '다', ')', ':')) or len(cur) >= hardcap):
            lines.append(cur)
            cur = w
        else:
            cur = cand
    if cur:
        lines.append(cur)
    return lines


def keep_prefix(text):
    """인덱스에 남길 verbatim 접두. 문장 경계에서 끊고 절단을 `…` 로 명시한다."""
    if len(text) <= KEEP_HARDCAP:
        return text, False
    words = text.split(' ')
    cur = ''
    for w in words:
        cand = w if not cur else cur + ' ' + w
        if len(cand) > KEEP_HARDCAP:
            break
        cur = cand
        if len(cur) >= KEEP_TARGET and cur.endswith(('.', '·', '다')):
            break
    if not cur:
        cur = text[:KEEP_HARDCAP]
    return cur, True


EMOJI = re.compile(
    '[\U0001F300-\U0001FAFF\u2190-\u21FF\u2600-\u27BF\uFE0F\u2B00-\u2BFF\u3030\u303D]')
DATE_LABEL = re.compile(r'\[(?:신규\s*)?(\d{4}-\d{2}-\d{2})\s+(O[0-9]+(?:-[0-9A-Z]+)?)')


def clean_id(cell):
    """`대표 ID` 셀 → 앵커용 순수 ID."""
    s = re.sub(r'<br\s*/?>', ' ', cell)
    s = s.replace('*', '').replace('`', '').replace('~', '')
    s = EMOJI.sub(' ', s)
    s = re.sub(r'\[[^\]]*\]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def anchor_for(cells, kind):
    if kind == 'status':
        m = DATE_LABEL.search(cells[2])
        if m:
            return m.group(2)
        return clean_id(cells[0])
    return clean_id(cells[0])


def title_for(cells):
    s = re.sub(r'<br\s*/?>', ' ', cells[0])
    return re.sub(r'\s+', ' ', s).strip()


def collect(lines, header, kinds):
    """header 절 안의 표 행 중 임계 초과 행을 수집."""
    out = []
    start = None
    for i, l in enumerate(lines):
        if l.startswith(header):
            start = i
            break
    if start is None:
        raise SystemExit('절 미발견: %s' % header)
    for i in range(start + 1, len(lines)):
        l = lines[i]
        if l.startswith('## ') and not l.startswith(header):
            break
        if kinds == 'stop-on-heading' and l.startswith('### '):
            break
        if not l.startswith('|'):
            continue
        if set(l.replace('|', '').replace('-', '').strip()) == set():
            continue
        if len(l) > ROW_THRESHOLD:
            out.append(i)
    return out


def section_rows(lines, headings):
    """headings 목록의 각 절에서 임계 초과 표 행을 (행번호, 절제목) 으로 모은다."""
    idxs = []
    for h in headings:
        start = None
        for i, l in enumerate(lines):
            if l.startswith(h):
                start = i
                break
        if start is None:
            raise SystemExit('절 미발견: %s' % h)
        for i in range(start + 1, len(lines)):
            l = lines[i]
            if l.startswith('#'):
                break
            if not l.startswith('|'):
                continue
            if len(l) > ROW_THRESHOLD:
                idxs.append((i, h))
    return idxs


# §2-B 열 이름 — 🔴 원문 헤더는 5열인데 행 10건이 6열이었다(렌더러가 마지막 「문서」 열을
# 잘라 버려 상세 포인터가 화면에서 사라진다) ⇒ 6열로 정규화한다. 6번째 축의 정체는
# 실측으로 확인했다: 6열 행의 4번째 셀은 전부 「실측/근거」 서술이고 5번째가 「상태」다.
COLS_2B = ['대표 ID', '별칭', '이슈', '실측·근거', '상태', '문서']
COLS_2A = ['대표 ID', '별칭', '계층', '이슈', '상태', '문서']
COLS_STATUS = ['현황', '건수', '대표 항목', '관할 문서']


def normalize_2b(lines):
    """§2-B 표를 6열로 정규화한다. 5열 행은 「실측·근거」 자리에 `—` 를 넣는다."""
    start = None
    for i, l in enumerate(lines):
        if l.startswith('### 2-B.'):
            start = i
            break
    if start is None:
        raise SystemExit('§2-B 미발견')
    fixed = 0
    hdr_done = False
    for i in range(start + 1, len(lines)):
        l = lines[i]
        if l.startswith('#'):
            break
        if not l.startswith('|'):
            continue
        if not hdr_done:
            lines[i] = '| ' + ' | '.join(COLS_2B) + ' |'
            lines[i + 1] = '|' + '---|' * len(COLS_2B)
            hdr_done = True
            continue
        if set(l.replace('|', '').replace('-', '').strip()) == set():
            continue
        cells = split_row(l)
        if len(cells) == 5:
            cells.insert(3, '—')
            lines[i] = '| ' + ' | '.join(cells) + ' |'
            fixed += 1
    return fixed


STATUS_HEADS = ['## 1. 상태 대시보드']
ISSUE_HEADS = ['### 2-A.', '### 2-B.', '### 2-C.', '### 2-D.', '### 2-E.', '### 2-F.']

HDR_STATUS = """<!-- LLM-METADATA
doc_id: ISSUE_STATUS_DETAIL
doc_role: 상태 대시보드 상세 (갱신형) — 원장 §1 표의 장문 셀 무변경 이관부
project: GN_DW (굿네이버스)
created: 2026-08-13
created_by: O66
parent: 20_issue/00_INDEX_이슈원장.md §1
END-METADATA -->

# 상태 대시보드 상세 (갱신형)

> 허브 = `00_INDEX_이슈원장.md` **§1 상태 대시보드**. 이 문서는 그 표의 장문 셀을 **무변경 이관**한 것이다.
> 성격 = **갱신형**(항목 상태가 바뀌면 그 자리에서 고친다). append-only 이력은 `01_세션이력.md` 소관이다.

> 🔴 **이관 계약 (O66)**
> · 이관은 **단일 공백을 줄바꿈으로 치환**한 것뿐이다. 문자 추가·삭제·수정 **0건**.
> · 판정 = 공백 정규화(`\\s+`→' ') 후 원문과 **문자열 완전 일치**(`scripts/split_issue_index.py --verify`).
> · ⇒ 수치·판정 문장은 손대지 않았다. 마크다운 렌더링 결과도 이관 전과 같다.
> · 인덱스에는 각 행의 **verbatim 접두**만 남겼다. 접두가 잘린 곳은 `…` 로 명시했다.

> 🔴 **왜 옮겼나**: 표 셀 하나에 세션 서술 전체가 들어가 1줄이 **최대 5,259자**였고
> `read` 툴 1줄 한도 **2,000자**를 넘겨 행 말미가 절단됐다 — 정본을 읽을 수 없는 상태(`R1-3` 미충족).
> 마크다운 표 셀은 줄바꿈이 불가하므로 **표에 둔 채로는 줄 길이를 줄일 수 없다**.
> 지침 `R1-3-6` 이 규정한 「정본에 이력이 섞였다는 신호 ⇒ 분리」의 집행이다.

---
"""

HDR_ISSUE = """<!-- LLM-METADATA
doc_id: ISSUE_CROSSWALK_DETAIL
doc_role: 이슈 상세 — 원장 §2 크로스워크 표의 장문 셀 무변경 이관부
project: GN_DW (굿네이버스)
created: 2026-08-13
created_by: O66
parent: 20_issue/00_INDEX_이슈원장.md §2
END-METADATA -->

# 이슈 상세 (§2 크로스워크 이관부)

> 허브 = `00_INDEX_이슈원장.md` **§2 전체 이슈 크로스워크**. 이 문서는 그 표의 장문 셀을 **무변경 이관**한 것이다.
> 각 항목의 **업무단계 정본**은 원 표의 「문서」 열이 가리키는 문서(10·20·30·40·50·90)다.
> 이 문서는 그 정본을 대체하지 않는다 — 크로스워크 행의 서술을 담는 자리다.

> 🔴 **이관 계약 (O66)**
> · 이관은 **단일 공백을 줄바꿈으로 치환**한 것뿐이다. 문자 추가·삭제·수정 **0건**.
> · 판정 = 공백 정규화 후 원문과 **문자열 완전 일치**(`scripts/split_issue_index.py --verify`).
> · 인덱스에는 각 셀의 **verbatim 접두**만 남겼다. 접두가 잘린 곳은 `…` 로 명시했다.

---
"""


def build(dry_run=False):
    text = read_text(IDX)
    lines = text.split('\n')

    # 선행: 표 열수 정규화(원문 결함). 이걸 먼저 해야 셀 위치가 절 헤더와 일치한다.
    fixed_2b = 0 if dry_run else normalize_2b(lines)

    status_idx = section_rows(lines, STATUS_HEADS)
    issue_idx = section_rows(lines, ISSUE_HEADS)

    # 헤더 행(| 현황 | 건수 | …)과 구분행은 임계를 넘지 않으므로 자동 제외된다.
    plan = [(i, 'status', h) for i, h in status_idx] + [(i, 'issue', h) for i, h in issue_idx]
    plan.sort()

    if dry_run:
        for i, kind, head in plan:
            cells = split_row(lines[i])
            print('%-6s %4d  %5d자  %-8s  %s'
                  % (kind, i + 1, len(lines[i]), anchor_for(cells, kind), head[:12]))
        print('합계 %d행 (status %d · issue %d)' % (len(plan), len(status_idx), len(issue_idx)))
        return

    det_status, det_issue = [], []
    seen = {}
    moved = []
    colfix = []

    for i, kind, head in plan:
        raw = lines[i]
        cells = split_row(raw)
        anchor = anchor_for(cells, kind)
        seen[anchor] = seen.get(anchor, 0) + 1
        if seen[anchor] > 1:
            anchor = '%s (%d)' % (anchor, seen[anchor])

        ptr_doc = '02' if kind == 'status' else '03'
        body = []
        body.append('## §%s · %s' % (anchor, title_for(cells)))
        body.append('')
        body.append('| 필드 | 값 |')
        body.append('|---|---|')

        # 표 열 이름 — 절마다 다르다. 절 제목으로 고른다(셀 수 추측 금지).
        if kind == 'status':
            names = list(COLS_STATUS)
        elif head.startswith('### 2-A.'):
            names = list(COLS_2A)
        elif head.startswith('### 2-B.'):
            names = list(COLS_2B)
        else:
            names = []
        # 실제 셀 수와 어긋나면 이름을 잃지 않도록 보정한다(열수는 절마다 다르다).
        names = names[:len(cells)]
        while len(names) < len(cells):
            names.append('열%d' % (len(names) + 1))

        long_cells = []
        for n, c in enumerate(cells):
            if len(c) > KEEP_HARDCAP:
                long_cells.append(n)
            else:
                body.append('| %s | %s |' % (names[n], c))
        body.append('| 인덱스 행 | `00_INDEX_이슈원장.md` §%s |'
                    % ('1' if kind == 'status' else '2'))
        body.append('')

        new_cells = list(cells)
        for n in long_cells:
            body.append('### %s (무변경 이관)' % names[n])
            body.append('')
            body.extend(wrap_verbatim(cells[n]))
            body.append('')
            pre, truncated = keep_prefix(cells[n])
            tail = '… → 상세 **`%s §%s`**' % (ptr_doc, anchor) if truncated \
                else ' → 상세 **`%s §%s`**' % (ptr_doc, anchor)
            new_cells[n] = pre + tail
            moved.append((i + 1, anchor, names[n], cells[n], body))

        # 「문서」/「관할 문서」 열에 상세 포인터를 병기한다.
        # 🔴 열수가 헤더보다 적은 행이 실재한다(O63 은 원문부터 「관할 문서」 열 자체가 없는
        #    3열 행이었다) ⇒ 병기 대상 열이 없으므로 열을 채워서 표 구조를 복구한다.
        expected = 4 if kind == 'status' else None
        if expected and len(new_cells) < expected:
            while len(new_cells) < expected - 1:
                new_cells.append('—')
            new_cells.append('%s §%s' % (ptr_doc, anchor))
            colfix.append((i + 1, anchor, len(cells), expected))
        else:
            last = len(cells) - 1
            if last not in long_cells:
                new_cells[last] = '%s · %s §%s' % (new_cells[last], ptr_doc, anchor)

        lines[i] = '| ' + ' | '.join(new_cells) + ' |'
        (det_status if kind == 'status' else det_issue).append('\n'.join(body) + '\n---\n')

    write_text(IDX, '\n'.join(lines))
    write_text(DETAIL_STATUS, HDR_STATUS + '\n' + '\n'.join(det_status))
    write_text(DETAIL_ISSUE, HDR_ISSUE + '\n' + '\n'.join(det_issue))
    print('이관 완료: status %d행 → 02 · issue %d행 → 03' % (len(status_idx), len(issue_idx)))
    print('🔴 부수 적발 — §2-B 표 열수 결손 정규화: 헤더 5열 → 6열 · 5열 행 %d건에 `—` 보충' % fixed_2b)
    for row, anchor, had, exp in colfix:
        print('🔴 부수 적발 — 열수 결손 복구: %d행 §%s (%d열 → %d열)' % (row, anchor, had, exp))


def verify(original_path):
    """보존 게이트 — 원문 스냅샷 대비 유실 0 판정."""
    orig = read_text(original_path)
    now = read_text(IDX) + '\n' + read_text(DETAIL_STATUS) + '\n' + read_text(DETAIL_ISSUE)
    fails = []

    # 게이트 1: 원문 각 장문 행의 각 셀이 이관 산출물에 공백 정규화 기준 그대로 있는가
    olines = orig.split('\n')
    oidx = [i for i, _ in section_rows(olines, STATUS_HEADS) + section_rows(olines, ISSUE_HEADS)]
    nnow = norm(now)
    checked = 0
    for i in sorted(oidx):
        for c in split_row(olines[i]):
            if len(c) <= KEEP_HARDCAP:
                continue
            checked += 1
            if norm(c) not in nnow:
                fails.append('셀 유실: 원문 %d행 / %s…' % (i + 1, c[:60]))
    print('게이트1 셀 원문 완전일치: %d/%d' % (checked - len([f for f in fails if '셀 유실' in f]), checked))

    # 게이트 2: 수치·ID 토큰 종수 보존
    def toks(s):
        return set(re.findall(r'\d[\d,\.]*%?|(?:O|P|DEC|Q|CONF|PROC|OPS|BLOCKING|AD|SVL|R)\d+(?:-[0-9A-Z]+)?', s))
    ot, nt = toks(orig), toks(now)
    lost = sorted(ot - nt)
    print('게이트2 토큰 종수: 원문 %d · 이후 %d · 유실 %d' % (len(ot), len(nt), len(lost)))
    if lost:
        fails.append('토큰 유실 %d종: %s' % (len(lost), ', '.join(lost[:20])))

    # 게이트 3: 줄 길이 한도
    over = []
    for p in (IDX, DETAIL_STATUS, DETAIL_ISSUE):
        for n, l in enumerate(read_text(p).split('\n'), 1):
            if len(l) > 2000:
                over.append('%s:%d (%d자)' % (os.path.basename(p), n, len(l)))
    print('게이트3 2,000자 초과 줄: %d' % len(over))
    if over:
        fails.append('한도 초과: ' + ', '.join(over))

    # 게이트 4: 표 열수 정합 — 한 표의 모든 행이 헤더와 같은 열수인가
    #   이 축이 없어서 최초 실행이 O64 행을 깨뜨린 것을 게이트가 아니라 눈으로 잡았다.
    bad_cols = []
    for p in (IDX, DETAIL_STATUS, DETAIL_ISSUE):
        hdr_n, hdr_line = None, 0
        for n, l in enumerate(read_text(p).split('\n'), 1):
            if not l.startswith('|'):
                hdr_n = None
                continue
            if hdr_n is None:
                hdr_n, hdr_line = len(split_row(l)), n
                continue
            if set(l.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
                continue
            got = len(split_row(l))
            if got != hdr_n:
                bad_cols.append('%s:%d %d열 (헤더 %d행 = %d열)'
                                % (os.path.basename(p), n, got, hdr_line, hdr_n))
    print('게이트4 표 열수 정합 위반: %d' % len(bad_cols))
    if bad_cols:
        fails.append('열수 불일치: ' + ' / '.join(bad_cols[:10]))

    if fails:
        print('\n🔴 FAIL')
        for f in fails:
            print(' -', f)
        return 1
    print('\n🟢 PASS — 유실 0 · 한도 초과 0')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--verify', metavar='ORIGINAL_SNAPSHOT')
    a = ap.parse_args()
    if a.verify:
        sys.exit(verify(a.verify))
    build(dry_run=a.dry_run)

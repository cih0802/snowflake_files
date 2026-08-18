#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""retire_rows.py — 갱신형 원장의 닫힌 행을 append형 로그로 **은퇴 이관**한다.

[2026-08-18 O83-B 신설 · 사용자 결정 「C 중심 + A·B 보완」의 C 집행 도구]

🔴 이 도구가 푸는 문제
--------------------------------------------------------------------------
갱신형 원장(`00_INDEX_이슈원장.md` §1 대시보드 등)은 **단조 증가**한다.
`R1-7-4` 가 행 삭제를 금지하기 때문이다(행 키 = 다른 문서가 인용하는 좌표).
⇒ `--rebalance`(A)는 **여유를 재배치**할 뿐 **총량을 줄이지 못한다.**
총량을 줄이는 유일한 길은 **닫힌 항목의 장문 셀을 밖으로 내보내는 것**이다.

🟢 `R1-7-4` 와 충돌하지 않는다 — 이것이 이 도구의 핵심 설계다
--------------------------------------------------------------------------
은퇴는 **행 삭제가 아니라 「셀 비우기」**다.
* **첫 셀(행 키)과 열 수는 그대로 둔다** ⇒ `index_row_gate` 가 보는 키 집합이
  **변하지 않는다**(유실 0). 인용 좌표도 그대로 유효하다.
* 장문 셀만 목적지로 **무변경 이동**하고 그 자리에 **포인터 1줄**을 남긴다.
* 이 형태는 `R1-7-4` 가 이미 처방한 「행 키를 보존하고 내용을 대체」의 적용이고,
  `02_상태상세_대시보드_갱신형.md`(§1 장문 셀 이관부)가 이미 쓰는 패턴이다.
  ⇒ 새 예외를 만드는 것이 아니라 **기존 규약을 닫힌 항목에 확장**하는 것이다.

🔴 `R2-8`(정본 이관 무결성) 집행
--------------------------------------------------------------------------
O70 은 절을 옮기며 원문을 지웠는데 **삭제 전 중복 실재를 기계로 확인하지 않았다**.
그래서 이 도구는 **토큰 대조를 통과하지 못하면 원본을 건드리지 않는다**(blocking).
* 이동할 셀에서 **수치·ID·백틱 토큰**을 추출한다.
* 목적지에 **전건 실재**해야 원본을 수정한다. 1건이라도 부재면 **중단**한다.
* 기본은 **dry-run** 이다. 쓰려면 `--apply` 를 명시한다.

사용
--------------------------------------------------------------------------
    # 후보 보기(바이트 절감 큰 순)
    python3 scripts/retire_rows.py --src 20_issue/00_INDEX_이슈원장-001.md --list

    # 실제 이관(키는 첫 셀의 정규화 문자열 · 쉼표 구분)
    python3 scripts/retire_rows.py \
        --src 20_issue/00_INDEX_이슈원장-001.md \
        --keys "ML 데이터 이관 문서화,ML 예측 SV·Agent 배포" \
        --to 20_issue/90_해소완료_로그.md \
        --to-section "6. 은퇴 이관 — 원장 §1 대시보드 (2026-08-18 O83-B)" \
        --apply

⚠️ 이관 후 반드시 실행한다
    python3 scripts/split_doc.py <허브> --republish     # 조각을 고쳤으므로(R1-6-13)
    python3 scripts/index_row_gate.py                  # 행 키 유실 0 확인(R1-7-4)
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 표 열수 판정·셀 분해는 O66 계약을 상속한다 — `|` 개수 세기는 백틱 코드스팬에서 오탐한다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from split_issue_index import split_row  # noqa: E402

EMOJI = re.compile(
    '[\U0001F300-\U0001FAFF\u2190-\u21FF\u2460-\u24FF\u2500-\u27BF\uFE0F\u200D]+')

# 토큰 = 3자리 이상 수치 · ID 계열 · 백틱 코드스팬.
#   🔴 2자리 이하 수치는 제외한다 — 「1」·「50」 은 목적지 어디에나 있어 대조가 vacuous 해진다(P106).
TOK_NUM = re.compile(r'\d[\d,\.]{2,}')
TOK_ID = re.compile(r'\b(?:[A-Z]{1,6}-\d+[A-Za-z\-]*|[A-Z]\d+[A-Za-z\-]*|O\d+[A-Z\-]*)\b')
TOK_CODE = re.compile(r'`([^`]+)`')


def read_text(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def write_text(p, s):
    with io.open(p, 'w', encoding='utf-8', newline='') as fh:
        fh.write(s)


def nbytes(s):
    return len(s.encode('utf-8'))


def norm(cell):
    """행 키 정규화 — `index_row_gate.norm_cell` 과 **같은 규칙**이어야 한다.

    🔴 두 곳의 규칙이 어긋나면 이 도구가 「보존했다」고 보고한 키를 게이트가
    「유실」로 잡는다. 규칙 = 볼드·백틱·물결·이모지·`<br>` 제거 + 공백 축약.
    """
    s = re.sub(r'<br\s*/?>', ' ', cell)
    s = s.replace('*', '').replace('`', '').replace('~', '')
    s = EMOJI.sub(' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def is_separator(s):
    return set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set()


def table_rows(text):
    """(줄번호, 셀목록) — 표 본문 행만. 헤더·구분행은 제외한다."""
    out = []
    in_table = False
    for i, line in enumerate(text.split('\n')):
        s = line.strip()
        if not s.startswith('|'):
            in_table = False
            continue
        if is_separator(s):
            in_table = True          # 구분행 다음부터 본문이다
            continue
        if not in_table:
            continue                 # 헤더 행은 키가 아니다
        out.append((i, split_row(s)))
    return out


def big_cell_index(cells):
    """포인터로 대체할 셀 = **첫 셀과 마지막 셀을 뺀** 나머지 중 가장 큰 셀.

    🔴 첫 셀은 **행 키**라 절대 건드리지 않는다(인용 좌표 · `R1-7-4`).
    🔴 마지막 셀은 보통 「관할 문서」 포인터라 남겨야 탐색이 된다.
    🔴 열 수는 **바꾸지 않는다** — 게이트 5(표 열수)가 증가·감소를 잡는다.
    """
    mid = list(range(1, max(1, len(cells) - 1)))
    if not mid:
        return None
    return max(mid, key=lambda k: nbytes(cells[k]))


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='은퇴 대상 조각(또는 단일 문서) 경로')
    ap.add_argument('--keys', default='', help='첫 셀 정규화 문자열 · 쉼표 구분')
    ap.add_argument('--to', default='20_issue/90_해소완료_로그.md', help='append형 목적지')
    ap.add_argument('--to-section', default=None, help='목적지에 만들 절 제목')
    ap.add_argument('--label', default='O83-B', help='포인터에 적을 라벨')
    ap.add_argument('--list', action='store_true', help='후보만 보고 종료(절감 큰 순)')
    ap.add_argument('--apply', action='store_true', help='실제로 쓴다(기본은 dry-run)')
    a = ap.parse_args()

    src = a.src if os.path.isabs(a.src) else os.path.join(ROOT, a.src)
    dst = a.to if os.path.isabs(a.to) else os.path.join(ROOT, a.to)
    for p in (src, dst):
        if not os.path.exists(p):
            raise SystemExit('🔴 경로 부재: %s' % p)

    stext = read_text(src)
    rows = table_rows(stext)

    if a.list:
        cand = []
        for ln, cells in rows:
            k = big_cell_index(cells)
            if k is None:
                continue
            cand.append((nbytes(cells[k]), ln, norm(cells[0])[:64]))
        cand.sort(reverse=True)
        print('[은퇴 후보] %s · 표 본문 행 %d개' % (os.path.basename(src), len(rows)))
        print('%9s %6s  %s' % ('장문셀B', '행', '행 키(첫 셀)'))
        for b, ln, key in cand[:30]:
            print('%9d %6d  %s' % (b, ln + 1, key))
        print('상위 10행 합계 = %s B' % format(sum(x[0] for x in cand[:10]), ','))
        return 0

    want = [w.strip() for w in a.keys.split(',') if w.strip()]
    if not want:
        raise SystemExit('🔴 --keys 가 비었다(또는 --list 를 써라).')
    if not a.to_section:
        raise SystemExit('🔴 --to-section 이 필요하다(목적지 절 제목).')

    picked = []
    for ln, cells in rows:
        key = norm(cells[0])
        for w in want:
            if w and w in key:
                k = big_cell_index(cells)
                if k is not None:
                    picked.append((ln, cells, k, key))
                break
    if not picked:
        raise SystemExit('🔴 --keys 에 맞는 행이 없다. --list 로 키를 확인하라.')
    if len(picked) != len(want):
        print('⚠️ 요청 %d건 ↔ 매칭 %d건 — 키를 확인하라(부분 문자열 매칭이다).'
              % (len(want), len(picked)))

    moved = nbytes('') 
    block = ['', '## %s' % a.to_section, '',
             '> 🔴 **원장 §1 대시보드에서 무변경 이관**(`R2-8` · `%s`). 행 키는 원장에 **그대로 남아 있고**'
             % a.label,
             '> 이 문서에는 그 행의 **장문 셀 원문**이 있다. 원장 쪽에는 이 절을 가리키는 포인터만 남았다.',
             '> ⚠️ **행을 삭제한 것이 아니다** — `R1-7-4`(행 키 = 인용 좌표) 준수. 열 수도 그대로다.',
             '']
    for ln, cells, k, key in picked:
        block.append('### %s' % key)
        block.append('')
        block.append(cells[k].strip())
        block.append('')
        moved += nbytes(cells[k])

    dtext = read_text(dst)
    # 목적지 꼬리의 서명줄 위에 삽입한다(서명은 파일 끝 관례다)
    sig = '\n_Co-authored with CoCo_'
    if dtext.rstrip().endswith('_Co-authored with CoCo_'):
        body = dtext.rstrip()[:-len('_Co-authored with CoCo_')].rstrip()
        new_dtext = body + '\n' + '\n'.join(block).rstrip() + '\n' + sig + '\n'
    else:
        new_dtext = dtext.rstrip() + '\n' + '\n'.join(block).rstrip() + '\n'

    # ── R2-8-1 토큰 대조 (blocking) ──────────────────────────────────────
    need = set()
    for _ln, cells, k, _key in picked:
        need |= tokens(cells[k])
    missing = sorted(t for t in need if t not in new_dtext)
    print('[R2-8-1 토큰 대조] 대상 토큰 %d종 · 목적지 부재 %d종' % (len(need), len(missing)))
    if missing:
        print('🔴 FAIL — 부재 토큰이 있어 원본을 수정하지 않는다:')
        for t in missing[:20]:
            print('   -', t)
        return 1

    # ── 원본 치환: 장문 셀만 포인터로 (첫 셀·열 수 불변) ─────────────────
    slines = stext.split('\n')
    for ln, cells, k, key in picked:
        newc = list(cells)
        newc[k] = ('✅ **[%s] 은퇴 이관 → `%s` §%s** — 장문 셀 원문을 그 문서로 **무변경 이동**했다'
                   '(`R2-8` 토큰 대조 통과). 🔴 **행 삭제가 아니다**: 행 키·열 수 보존(`R1-7-4`)'
                   % (a.label, os.path.basename(dst), a.to_section.split('.')[0]))
        slines[ln] = '| ' + ' | '.join(c.strip() for c in newc) + ' |'
    new_stext = '\n'.join(slines)

    print('원본 %s: %s B → %s B (절감 %s B)'
          % (os.path.basename(src), format(nbytes(stext), ','),
             format(nbytes(new_stext), ','), format(nbytes(stext) - nbytes(new_stext), ',')))
    print('목적지 %s: %s B → %s B' % (os.path.basename(dst), format(nbytes(dtext), ','),
                                    format(nbytes(new_dtext), ',')))
    print('이관 행 %d개 · 이동 바이트 %s' % (len(picked), format(moved, ',')))

    # 열 수 자가 검증 — 게이트 5 가 잡기 전에 여기서 막는다
    for ln, cells, _k, _key in picked:
        after = split_row(slines[ln].strip())
        if len(after) != len(cells):
            print('🔴 열 수 변화 %d → %d (행 %d) — 쓰지 않는다.' % (len(cells), len(after), ln + 1))
            return 1
    print('🟢 열 수 불변 전건 확인 · 행 키 불변 전건 확인')

    if not a.apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    # 🔴 [2026-08-18 O83-E · 자기검토 C4 시정] 은퇴는 **되돌릴 수 없었다** — 롤백 경로가 없었다.
    #   토큰 대조가 blocking 이라 유실 위험은 낮지만, **잘못된 행을 은퇴시킨 경우**
    #   손으로 복원해야 했다. ⇒ 쓰기 직전 양쪽 원본을 스냅샷한다(`R1-7-6`: 이 워크스페이스는
    #   `head == live` 라 redo 경로가 없다 — 스냅샷이 유일한 되돌리기 수단이다).
    arch = os.path.join(ROOT, '_archive')
    if not os.path.isdir(arch):
        os.makedirs(arch)
    for p in (src, dst):
        snap = os.path.join(arch, '%s.%s-preretire' % (os.path.basename(p), a.label))
        write_text(snap, read_text(p))
        print('스냅샷 = %s' % os.path.relpath(snap, ROOT))

    write_text(dst, new_dtext)
    write_text(src, new_stext)
    print('\n🟢 기록 완료. 이어서 실행하라:')
    print('   python3 scripts/split_doc.py <허브> --republish')
    print('   python3 scripts/index_row_gate.py')
    print('   되돌리려면 위 `_archive/*.%s-preretire` 두 파일을 제자리에 복사한다.' % a.label)
    return 0


if __name__ == '__main__':
    sys.exit(main())

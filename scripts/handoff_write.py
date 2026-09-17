#!/usr/bin/env python3
"""인수인계 절을 **O단위 라벨 파일**로 쓰고 색인을 재생성한다.

🆕 🔴🔴 [2026-09-17 O172 신설 · 사용자 지시] **왜 이 도구가 있나 — 종전 6단계를 1단계로 줄인다.**

종전(조각에 append)은 세션 종료마다 아래를 요구했다:
  ㉠ 엔트리 파일 작성 → ㉡ python 전량 쓰기로 조각 말미에 삽입
     (🔴 `cat >>` 는 이 마운트에서 **조용히 유실**된다 · O167 실사고)
  ㉢ 이전 절의 「여기서 시작한다」를 취소선으로 승계 표기
  ㉣ 허브 `--republish --expect`
  ㉤ `doc_heading_gate --update-golden --reason`(㉢ 이 「제목 유실 1건」으로 잡힌다)
  ㉥ 조각이 상한에 닿으면 **재균형**(`R4-4-3` 승인 + 인용 좌표 전멸)

🟢 라벨 파일 방식은 ㉡~㉥ 를 없앤다:
  · 파일이 **신규**라 `write` 가 계약상 허용된다(`R1-7-1` 은 신규 파일 전용을 허용한다).
  · 1세션 1파일이라 **상한(300줄 AND 40KB)에 원리적으로 닿지 않는다** ⇒ ㉥ 소멸.
  · 「현행」을 **파일명 최대값**으로 판정하므로 ㉢ 취소선 관례가 불필요해진다 ⇒ ㉤ 도 소멸.
  · 조각을 건드리지 않으므로 허브 SHA256·목차가 그대로다 ⇒ ㉣ 는 **라벨 파일이 처음 생길 때만**
    필요하다(허브 머리말의 색인 포인터 1줄을 넣기 위해서다).

🔴 **판정식 = 「썼다」와 「닿았다」는 다르다**(O167). 쓴 뒤 **되읽어 토큰을 대조**하고,
   그 결과를 출력한다. 출력이 없으면 쓰지 않은 것으로 취급하라.

🔴 **규격 정본은 `doc_census.label_rx`·`label_paths` 다** — 이 파일에서 정규식을 다시 쓰지 않는다
   (`R3-9 ㉡`·`J8` 「같은 것을 다르게 재지 마라」).

사용법:
    python3 scripts/handoff_write.py --next
    python3 scripts/handoff_write.py --label O172-A --entry-file tmp/_o172_handoff.md
    python3 scripts/handoff_write.py --index
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from doc_census import label_paths, label_rx, outdir_marker   # noqa: E402

HUB_REL = '99_NEXT_SESSION.md'
INDEX_NAME = '00_인수인계_색인.md'
TAIL = '_Co-authored with CoCo_'
HARD = 2000        # `read` 의 1줄 절단 한도(문자) · `R1-5-1`
SOFT = 1000        # 권고
MAX_BYTES = 40 * 1024
MAX_LINES = 300

# 🔴 접미 규격 = **항상 붙인다**(사용자 결정 ⓑ). 최초 단위도 `-A` 이고 무접미는 거부한다.
#   🔎 A~Z 로 충분한가 = 실측 최대 **21단위**(`O59`) ⇒ 담기지만 여유 5뿐이므로 2자 확장을 허용한다.
LABEL_RX = re.compile(r'^O(\d{1,4})-([A-Z]{1,2})$')
LABEL_NO_SUFFIX = re.compile(r'^O(\d{1,4})$')


def hub_abs():
    return os.path.join(ROOT, HUB_REL)


def outdir():
    """조각 폴더명. 🔴 추측하지 않고 허브의 `SPLIT-OUTDIR` 마커를 읽는다."""
    return outdir_marker(hub_abs()) or 'sibling'


def chunk_dir():
    d = outdir()
    return ROOT if d == 'sibling' else os.path.join(ROOT, d)


def stem():
    return os.path.splitext(os.path.basename(HUB_REL))[0]


def parse_label(s):
    """`O172-A` → `(172, 'A')`. 규격 위반이면 SystemExit."""
    s = s.strip().lstrip('§').strip()
    if LABEL_NO_SUFFIX.match(s):
        raise SystemExit(
            '🔴 접미가 없다: %r — 규격은 **접미 필수**다(최초 단위도 `-A`).\n'
            '   🔎 왜 = 무접미와 `-B` 가 섞이면 파일명 폭이 흔들려 정렬이 발생 순서와 어긋난다.\n'
            '   예: --label %s-A' % (s, s))
    m = LABEL_RX.match(s)
    if not m:
        raise SystemExit('🔴 라벨 규격 위반: %r — 기대 형식 `O172-A`(O + 1~4자리 + `-` + A~Z 또는 2자)' % s)
    return int(m.group(1)), m.group(2)


def label_file(num, suf):
    return os.path.join(chunk_dir(), '%s-O%04d-%s.md' % (stem(), num, suf))


def existing():
    """라벨 파일 목록(발생 순). 정본 = `doc_census.label_paths`."""
    return label_paths(HUB_REL, outdir())


def suffix_seq(n):
    """0→A … 25→Z … 26→AA (정렬이 발생 순서와 일치하도록 **길이 우선**)."""
    if n < 26:
        return chr(ord('A') + n)
    n -= 26
    if n < 26 * 26:
        return chr(ord('A') + n // 26) + chr(ord('A') + n % 26)
    raise SystemExit('🔴 접미가 소진됐다(2자까지 = 702단위) — 규격을 늘려야 한다.')


def next_label(num=None):
    """같은 O번호의 **다음 접미**를 낸다. `num` 이 없으면 최신 O번호를 이어간다."""
    rx = label_rx(stem(), '.md')
    used = {}
    for p in existing():
        m = rx.match(os.path.basename(p))
        used.setdefault(int(m.group(1)), set()).add(m.group(2))
    if num is None:
        if not used:
            raise SystemExit(
                '🔴 라벨 파일이 아직 없어 O번호를 추론할 수 없다 — `--label O<번호>-A` 로 지정하라.\n'
                '   🔎 왜 추론하지 않나 = 세션 라벨은 `id_collision_gate.py --next O` 로 **선점**하는 것이고\n'
                '   이 도구가 창작하면 원장 선점과 어긋난다(`R1-4-3`).')
        num = max(used)
    taken = used.get(num, set())
    k = 0
    while suffix_seq(k) in taken:
        k += 1
    return num, suffix_seq(k)


def header(num, suf, date):
    return [
        '<!-- LLM-METADATA',
        'doc_id: HANDOFF_O%04d_%s' % (num, suf),
        'doc_role: 인수인계 — 세션 `O%d-%s` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)' % (num, suf),
        'project: GN_DW (굿네이버스)',
        'created: %s' % date,
        'created_by: O%d-%s' % (num, suf),
        'parent: %s' % HUB_REL,
        'index: 20_issue/00_INDEX_이슈원장.md',
        'END-METADATA -->',
        '',
        '<!-- HANDOFF-LABEL O%04d-%s -->' % (num, suf),
        '',
        '> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**',
        '> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).',
        '> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.',
        '> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.',
        '',
    ]


def scan_long(text):
    bad = []
    for i, l in enumerate(text.split('\n'), 1):
        if len(l) > HARD:
            bad.append((i, len(l)))
    return bad


def write_entry(num, suf, entry_path, date):
    dst = label_file(num, suf)
    if os.path.exists(dst):
        print('🟠 SKIP: 이미 있다 — %s' % os.path.relpath(dst, ROOT))
        print('   🔴 덮지 않는다(`R1-7-10` 축). 같은 세션의 후속 단위는 `--next` 로 접미를 받아라.')
        return 1
    if not os.path.exists(entry_path):
        raise SystemExit('🔴 엔트리 파일이 없다: %s' % entry_path)
    body = io.open(entry_path, encoding='utf-8').read().rstrip('\n')
    if not body.strip():
        raise SystemExit('🔴 엔트리 본문이 비었다 — 빈 인수인계를 쓰지 않는다.')

    text = '\n'.join(header(num, suf, date)) + body + '\n\n' + TAIL + '\n'

    # ㉠ 쓰기 전 가드 — 한 줄 2,000자(`R1-5-1`). 🔴 넘으면 쓰지 않는다(다음 세션이 전량 못 읽는다).
    bad = scan_long(text)
    if bad:
        print('🔴 한 줄 2,000자 초과 %d줄 — 쓰지 않았다. 의미 단위로 개행하라.' % len(bad))
        for i, n in bad[:10]:
            print('     엔트리 기준 %d행 · %d자' % (i, n))
        return 1

    nb = len(text.encode('utf-8'))
    nl = text.count('\n')
    io.open(dst, 'w', encoding='utf-8').write(text)

    # ㉡ 도달 재검사 — 「썼다」와 「닿았다」는 다르다(O167).
    back = io.open(dst, encoding='utf-8').read()
    toks = {
        '라벨 마커': back.count('<!-- HANDOFF-LABEL O%04d-%s -->' % (num, suf)),
        '본문 선두 40자': back.count(body.strip().split('\n')[0][:40]),
        '말미 서명': back.count(TAIL),
    }
    print('🟢 라벨 파일 생성 %s' % os.path.relpath(dst, ROOT))
    print('   %s B / %d줄 (상한 %s B AND %d줄 · 여유 %s B)'
          % (format(nb, ','), nl, format(MAX_BYTES, ','), MAX_LINES,
             format(MAX_BYTES - nb, ',')))
    print('   도달 재검사(전부 ≥1 이어야 한다):')
    for k, v in toks.items():
        print('     %s %s = %d' % ('🟢' if v >= 1 else '🔴', k, v))
    if nb > MAX_BYTES or nl > MAX_LINES:
        print('   🔴 상한 초과 — 이 세션의 인수인계를 접미로 쪼개라(`--next`).')
        return 1
    if min(toks.values()) < 1:
        print('   🔴 도달 실패 — 이 파일을 신뢰하지 마라.')
        return 1
    return 0


def title_of(text):
    for l in text.split('\n'):
        s = l.strip()
        if s.startswith('#') and 'HANDOFF' not in s:
            return s.lstrip('#').strip().replace('|', '/')[:80]
    for l in text.split('\n'):
        s = l.strip()
        if s.startswith('▣') or s.startswith('- ▣'):
            return s.lstrip('- ').replace('|', '/')[:80]
    return '(제목 없음)'


def date_of(text):
    m = re.search(r'created:\s*(\d{4}-\d{2}-\d{2})', text)
    if m:
        return m.group(1)
    m = re.search(r'(\d{4}-\d{2}-\d{2})', text)
    return m.group(1) if m else '—'


def build_index():
    """`00_인수인계_색인.md` 를 **통째로 다시 쓴다**(자동 생성물)."""
    paths = existing()
    rx = label_rx(stem(), '.md')
    disp = '' if outdir() == 'sibling' else '%s/' % outdir()
    out = [
        '<!-- LLM-METADATA',
        'doc_id: HANDOFF_INDEX',
        'doc_role: 인수인계 **라벨 파일** 색인(자동 생성 · 정본 아님) — O172 규격',
        'project: GN_DW (굿네이버스)',
        'created: 2026-09-17',
        'created_by: O172',
        'parent: %s' % HUB_REL,
        'END-METADATA -->',
        '',
        '# 인수인계 라벨 파일 색인 (자동 생성)',
        '',
        '> 🔴🔴 **이 파일은 자동 생성물이다 — 여기에 내용을 쓰지 마라.**',
        '> `python3 scripts/handoff_write.py --index` 가 **통째로 다시 쓴다**',
        '> ⇒ 손으로 적은 문장은 **조용히 사라진다**(허브·`00_BRIEF` 와 같은 계약).',
        '',
        '> 🔴 **이 표는 색인이고 정본이 아니다** — 판정·수치를 인용하려면 그 파일을 `read` 한다.',
        '> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미). 취소선 승계 표기는 쓰지 않는다.',
        '> 🔴 라벨 파일은 **조각이 아니다** — 허브 `발행 SHA256`·`--verify` concat 과 무관하다.',
        '',
    ]
    if not paths:
        out += ['> ⚠️ 라벨 파일이 아직 없다 — 인수인계는 조각의 `## 0-XXXX` 절에 있다.', '']
    else:
        cur = os.path.basename(paths[-1])
        out += ['> 🔴🔴 **현행 = `%s%s`**' % (disp, cur), '']
        out += ['| 라벨 | 날짜 | 제목 | 줄 | B | 파일 |', '|---|---|---|---|---|---|']
        for p in paths:
            m = rx.match(os.path.basename(p))
            t = io.open(p, encoding='utf-8').read()
            out.append('| `O%d-%s` | %s | %s | %d | %s | `%s%s` |'
                       % (int(m.group(1)), m.group(2), date_of(t), title_of(t),
                          t.count('\n'), format(len(t.encode('utf-8')), ','),
                          disp, os.path.basename(p)))
        out.append('')
    out += [
        '---',
        '',
        '> 🔴 **재생성** = `python3 scripts/handoff_write.py --index`',
        '> 🔴 **새 인수인계** = `python3 scripts/handoff_write.py --label O<번호>-<접미> --entry-file <파일>`',
        '',
        TAIL,
        '',
    ]
    text = '\n'.join(out)
    dst = os.path.join(chunk_dir(), INDEX_NAME)
    io.open(dst, 'w', encoding='utf-8').write(text)
    back = io.open(dst, encoding='utf-8').read()
    print('🟢 색인 재생성 %s — 라벨 파일 %d개 · %s B'
          % (os.path.relpath(dst, ROOT), len(paths), format(len(back.encode()), ',')))
    if paths:
        print('   현행 = %s' % os.path.basename(paths[-1]))
    bad = scan_long(back)
    print('   한 줄 2,000자 초과 = %d줄' % len(bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description='인수인계 라벨 파일 작성기(O172 규격)')
    ap.add_argument('--label', help='세션 라벨(접미 필수 · 예 `O172-A`)')
    ap.add_argument('--entry-file', help='인수인계 본문 파일(머리말·서명은 이 도구가 붙인다)')
    ap.add_argument('--date', default=None, help='created 날짜(기본 = 오늘)')
    ap.add_argument('--next', action='store_true', help='다음 접미를 제안만 한다')
    ap.add_argument('--index', action='store_true', help='색인만 재생성한다')
    a = ap.parse_args()

    if a.next:
        num, suf = next_label(parse_label(a.label)[0] if a.label else None)
        print('다음 라벨 = O%d-%s  ⇒  %s'
              % (num, suf, os.path.relpath(label_file(num, suf), ROOT)))
        print('기존 라벨 파일 %d개' % len(existing()))
        return 0
    if a.index and not a.label:
        return build_index()
    if not a.label or not a.entry_file:
        ap.error('--label 과 --entry-file 을 함께 주거나 --index/--next 를 쓰라')

    num, suf = parse_label(a.label)
    if a.date:
        date = a.date
    else:
        import datetime
        date = datetime.date.today().isoformat()
    rc = write_entry(num, suf, a.entry_file, date)
    if rc:
        return rc
    rc = build_index()
    print('')
    print('🔴 남은 1단계 = 허브 색인 포인터 반영(라벨 파일이 **처음** 생겼을 때만):')
    print('   python3 scripts/split_doc.py %s --republish --expect "<토큰>"' % HUB_REL)
    return rc


if __name__ == '__main__':
    sys.exit(main())

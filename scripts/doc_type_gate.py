#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""doc_type_gate.py — `20_issue/` 문서의 **유형 선언과 유형별 불변식**을 강제한다.

[2026-08-18 O83-D 신설 · `R1-6-16` 의 집행 장치]

🔴 왜 필요한가
--------------------------------------------------------------------------
`R1-6-14`(갱신형 용량 아키텍처)와 `R1-6-15`(append형 꼬리 롤오버)는 **유형별로 다른
처리**를 규정한다. 그런데 어떤 문서가 어떤 유형인지가 **어디에도 기계로 적혀 있지 않았다.**
⇒ 다음 세션은 유형을 **추측**하게 되고, 추측이 틀리면:
  * append형에 재균형을 돌려 **조각 불변성을 깬다**(인용 좌표가 매번 무효화된다).
  * 갱신형을 꼬리 롤오버로 다루어 **중간 삽입에서 조각이 터진다**.
🔴 이 세션에서 「추측」이 이미 두 번 사고를 냈다(폴더명 stem 추측 · 자동 분류 시도 3/4 불일치).
⇒ 유형은 **선언**하고, 이 게이트가 **선언 누락과 불변식 위반을 차단**한다.

정본 = `20_issue/00_INDEX_이슈원장.md` §0 **「문서 유형 등재표」**
--------------------------------------------------------------------------
표 형식 = `| 문서 | 유형 | 근거 | 처리 |` · 유형 값 = `갱신형` | `append형` | `정적`.
분할 문서는 **허브 파일명**으로 선언한다(조각은 소속 문서에 귀속된다).

검사 축 4종
--------------------------------------------------------------------------
1. **선언 분모** — `20_issue/` 의 모든 문서가 등재표에 있어야 한다.
   🔴 미선언 1건이라도 있으면 FAIL. 분모가 조용히 좁아지면 게이트가 착시가 된다(`P106`).
2. **상한** — 모든 조각(및 미분할 문서)이 `300줄 AND 40KB` 이내여야 한다(`R1-6-1`).
3. **갱신형 여유** — 조각 최대 크기가 `40KB × (1 - MIN_FREE)` 이하여야 한다.
   🔴 갱신형은 신규 행이 **같은 조각**에 떨어지므로 여유가 없으면 **다음 편집에서 확정 초과**다
   (실측: 인덱스 `-001` 여유 178B ↔ 세션당 추가 ≈1,200B) ⇒ 여유 부족은 **경고**로 조기 통보한다.
4. **append형 꼬리 여유** — 꼬리 조각(또는 미분할 파일)에 여유가 있어야 한다.
   append형은 꼬리만 자라므로 **꼬리 1개**만 보면 된다(비꼬리 조각은 불변이 정상이다).

⚠️ 3·4 는 **경고(관측)** 이고 1·2 는 **차단(FAIL)** 이다.
   여유 부족은 「지금 깨졌다」가 아니라 「다음에 깨진다」이므로 차단하면 정상 작업을 막는다.
   단 **경고를 0으로 만드는 것이 이 아키텍처의 목표**다 — 경고가 쌓이면 재균형·은퇴를 돌려라.
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC_DIR = os.path.join(ROOT, '20_issue')
INDEX = os.path.join(DOC_DIR, '00_INDEX_이슈원장.md')

# 🔴 [2026-08-18 O83-E] 분모를 `20_issue/` 밖으로 넓힌다.
#   **왜**: 분모가 `20_issue/` 뿐이라 **매 세션 반드시 읽는 두 문서**가 검사 밖이었다 —
#   `00_guides/…` 는 이 세션에서 조문 8개를 더해 **426줄 / 45,116B** 까지 커졌는데
#   게이트가 **한 번도 경고하지 않았다**(사람이 python 으로 따로 재서 발견했다).
#   `R1-6-8`(분모를 넓혀라)의 3번째 재발이고, 이번엔 **게이트 자신의 분모**였다.
#   ⇒ 상시 독해 문서는 폴더 밖이라도 명시 편입한다. 이 목록은 **손으로 유지**한다
#   (glob 로 워크스페이스 전체를 넣으면 산출물·백업까지 들어와 게이트가 상시 빨강이 된다 · `P130`).
EXTRA_DOCS = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '00_guides/01_문서분할_규약.md',
    '99_NEXT_SESSION.md',
]

MAX_LINES = 300
MAX_BYTES = 40 * 1024
MAX_CHARS = 40000        # `read` 출력 한도 실측 근거(O82-C · doc_line_length_gate.READ_OUTPUT 과 동일)
MIN_FREE = 0.20          # 갱신형·append형 꼬리에 요구하는 최소 여유 비율(= 8KB)

# 🔴 [2026-08-18 O83-E] **줄 수 축은 「조각」에만 차단으로 적용한다.**
#   왜: `read` 도구 한도는 **2,000줄/호출**이고 O82-C 가 측정한 실패 경계는 **문자(~40,000)·
#   바이트(37.6~71.6KB)** 축이었다. 300줄은 *성공 사례의 우연한 속성*이지 측정된 경계가 아니다.
#   실측 반례: 지침이 **377줄 / 21,695자 / 39,269B** 인데 **1회 반환에 성공**한다
#   ⇒ 줄 수로 차단하면 **정상 문서를 FAIL** 시킨다.
#   🔴 게다가 `R1-5-3`(긴 문장을 의미 단위로 개행하라)이 줄 수를 **의도적으로 늘린다** ⇒
#   두 조문이 서로 밀어낸다. 짧은 줄로 잘 쓴 문서가 줄 수 상한에 걸리는 것은 규칙 설계 오류다.
#   ⇒ 조각은 도구가 만드는 산출물이라 300줄을 granularity 관례로 유지하고,
#     **비분할 정본·허브는 바이트·문자 축으로만 차단**한다(줄 수는 관측).
#   ⚠️ 이것은 「내 실패를 없애려고 상한을 푼 것」이 아니다 — 실제로 나를 물었던 **바이트 축(45,116B)
#     은 차단으로 유지**하고, 근거 없는 축만 관측으로 내렸다.
CHUNK_RX = re.compile(r'-\d{3}\.[A-Za-z]+$')

KINDS = ('갱신형', 'append형', '정적')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def read_text(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def index_logical():
    """인덱스는 분할돼 있으므로 허브+조각을 이어붙여 읽는다(등재표가 조각에 있다)."""
    from split_doc import collect_bodies, hub_outdir
    parts, _paths = collect_bodies(INDEX, hub_outdir(INDEX))
    return '\n'.join([read_text(INDEX)] + parts)


def parse_registry(text):
    """§0 문서 유형 등재표 → {문서명: (유형, 처리)}."""
    reg = {}
    in_tbl = False
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('| 문서 | 유형 |'):
            in_tbl = True
            continue
        if in_tbl:
            if not s.startswith('|'):
                in_tbl = False
                continue
            if set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
                continue
            cells = [c.strip() for c in s.strip('|').split('|')]
            if len(cells) < 2:
                continue
            name = cells[0].replace('`', '').replace('*', '').strip()
            kind = None
            for k in KINDS:
                if k in cells[1]:
                    kind = k
                    break
            if name and kind:
                reg[name] = (kind, cells[3] if len(cells) > 3 else '')
    return reg


def hub_of(name):
    m = re.match(r'^(.*)-\d{3}(\.[A-Za-z]+)$', name)
    return (m.group(1) + m.group(2)) if m else name


def actual_docs():
    """실재 문서(허브 단위) → 소속 파일 목록. `20_issue/` + `EXTRA_DOCS`(폴더 밖 상시 독해)."""
    fam = {}
    for root, dirs, files in os.walk(DOC_DIR):
        dirs[:] = [d for d in dirs if d not in ('_archive', '__pycache__')]
        for f in sorted(files):
            if not f.endswith(('.md', '.sql')):
                continue
            fam.setdefault(hub_of(f), []).append(os.path.join(root, f))
    for rel in EXTRA_DOCS:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        hub = hub_of(os.path.basename(p))
        fam.setdefault(hub, []).append(p)
        # 그 문서의 형제 조각도 함께 편입한다(`99_NEXT_SESSION-001.md` 등)
        stem, ext = os.path.splitext(p)
        n = 1
        while True:
            c = '%s-%03d%s' % (stem, n, ext)
            if not os.path.exists(c):
                break
            fam[hub].append(c)
            n += 1
    return fam


def nlines(p):
    t = read_text(p)
    return t.count('\n') + (0 if t.endswith('\n') else 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--strict', action='store_true',
                    help='여유 경고도 FAIL 로 올린다(단계 종료 게이트용)')
    a = ap.parse_args()

    reg = parse_registry(index_logical())
    fam = actual_docs()
    fails, warns = [], []

    print('[문서 유형 게이트] 등재 %d건 · 실재 문서 %d건' % (len(reg), len(fam)))

    # ── 축 1: 선언 분모 ────────────────────────────────────────────────
    # 🔴 등재표는 파일명을 축약(`41_…_BRONZE_DDL.sql`)하거나 **경로 포함**(`00_guides/…`)으로
    #   적을 수 있다. 게이트는 **파일명 기준**으로 조회하므로 세 형태를 모두 허용한다.
    #   (O83-E 실측: 경로 포함으로 등재했더니 「미선언」으로 잡혔다 — 표기 규칙 불일치 오탐.)
    def declared(name):
        if name in reg:
            return reg[name]
        for k, v in reg.items():
            if os.path.basename(k) == name:
                return v
            if '…' in k:
                head, tail = k.split('…', 1)
                if name.startswith(os.path.basename(head).strip()) and name.endswith(tail.strip()):
                    return v
        return None

    undeclared = [n for n in sorted(fam) if declared(n) is None]
    print('  축1 선언 분모: 미선언 %d건' % len(undeclared))
    for n in undeclared:
        print('    🔴', n)
    if undeclared:
        fails.append('유형 미선언 %d건 — 등재표(§0)에 추가하라' % len(undeclared))

    # ── 축 2~4 ────────────────────────────────────────────────────────
    over, tight, long_lines = [], [], []
    print('  %-42s %-8s %5s %9s %9s' % ('문서', '유형', '파일', 'max B', '여유 B'))
    for name in sorted(fam):
        d = declared(name)
        if d is None:
            continue
        kind = d[0]
        paths = fam[name]
        # 허브는 자동 생성물이라 상한 판정에서 제외하지 않는다(read 대상이므로 함께 본다)
        sizes = [(p, os.path.getsize(p)) for p in paths]
        mx_p, mx = max(sizes, key=lambda x: x[1])
        for p, b in sizes:
            t = read_text(p)
            nl = t.count('\n') + (0 if t.endswith('\n') else 1)
            bad = []
            if b > MAX_BYTES:
                bad.append('%d B > 40KB' % b)
            if len(t) > MAX_CHARS:
                bad.append('%d 자 > %d' % (len(t), MAX_CHARS))
            if CHUNK_RX.search(os.path.basename(p)) and nl > MAX_LINES + 1:
                bad.append('%d 줄 > %d (조각)' % (nl, MAX_LINES))
            elif nl > MAX_LINES + 1:
                long_lines.append('%s (%d줄 · 관측)' % (os.path.relpath(p, ROOT), nl))
            if bad:
                over.append('%s: %s' % (os.path.relpath(p, ROOT), ' / '.join(bad)))

        if kind == 'append형':
            # 꼬리만 본다 — 비꼬리 조각은 불변이 정상이다
            tail_p, tail_b = sorted(sizes)[-1] if len(sizes) == 1 else sorted(
                sizes, key=lambda x: x[0])[-1]
            free = MAX_BYTES - tail_b
            label, watch = '꼬리', free
        else:
            free = MAX_BYTES - mx
            label, watch = 'max', free
        print('  %-42s %-8s %5d %9s %9s%s' % (
            name, kind, len(paths), format(mx, ','), format(watch, ','),
            '  ← %s' % label if kind == 'append형' else ''))
        if kind != '정적' and watch < MAX_BYTES * MIN_FREE:
            tight.append('%s: %s 여유 %s B (< %d%%)'
                         % (name, label, format(watch, ','), MIN_FREE * 100))

    print('  축2 상한 초과(바이트·문자 · 조각은 줄 수도): %d건' % len(over))
    for x in over:
        print('    🔴', x)
    if over:
        fails.append('상한 초과 %d건 — `--rebalance` 를 돌려라' % len(over))

    if long_lines:
        print('  ⚪ 300줄 초과(비분할 정본 · 관측만 · 근거 = 도구 한도 2,000줄): %d건' % len(long_lines))
        for x in long_lines:
            print('    ⚪', x)

    print('  축3·4 여유 부족(경고): %d건' % len(tight))
    for x in tight:
        print('    🟠', x)
    if tight:
        (fails if a.strict else warns).append(
            '여유 부족 %d건 — 갱신형은 `--rebalance`, 은퇴 가능하면 `retire_rows.py`' % len(tight))

    print('')
    if fails:
        print('🔴 게이트 실패 %d건' % len(fails))
        for f in fails:
            print(' -', f)
        return 1
    if warns:
        print('🟡 통과(경고 %d건)' % len(warns))
        for w in warns:
            print(' -', w)
        return 0
    print('✅ 게이트 통과 — 선언 누락 0 · 상한 초과 0 · 여유 부족 0')
    return 0


if __name__ == '__main__':
    sys.exit(main())

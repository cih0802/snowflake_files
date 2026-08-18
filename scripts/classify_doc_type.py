#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""classify_doc_type.py — `20_issue/` 문서의 **유형 신호를 관측**한다(분류의 보조 도구).

[2026-08-18 O83-D · 사용자 지시 「이슈 폴더 문서를 전부 분류한 뒤 처리 적용」]

🔴🔴 이 도구는 **분류기가 아니다 — 분류를 시도했고 실패했다.** 그 실패가 이 파일의 요지다.
--------------------------------------------------------------------------
처음 목표는 구조 신호로 갱신형/append형을 **자동 판정**하는 것이었다.
`--calibrate` 로 정답 라벨 4건(문서가 스스로 선언한 유형)을 대조하니 **3건이 불일치**했다:

    01_세션이력.md            판정 mixed  ↔ 정답 append  (ratio 0.40)
    02_상태상세_…_갱신형.md    판정 mixed  ↔ 정답 update  (ratio 0.44)
    90_해소완료_로그.md        판정 update ↔ 정답 append  (ratio 0.18)

원인은 임계값이 아니라 **신호 자체**였다:
* `01_세션이력` 은 append-only 인데 **항목 안에 상태 표가 들어 있어** state 신호가 오염된다(196행).
* `90_해소완료_로그` 는 **전부 표**로 되어 있어 갱신형과 구조가 구별되지 않는다.
* `02_…_갱신형` 은 `§O##` 절 제목이 많아 append 항목처럼 보인다.

⇒ **결론: 두 유형의 차이는 「구조」가 아니라 「쓴 뒤에 고치는가」다.**
   그것은 **시간에 걸친 쓰기 행위**이고 **스냅샷 1장으로는 관측할 수 없다.**
   (`inplace_edit` 신호도 못 가른다 — 이력은 *과거 판정의 철회를 서술*하므로
   「철회」 문자열이 386건 나오지만 그 텍스트 자체는 append 된 것이다.)

🟢 그래서 분류는 **선언**으로 하고, 이 도구는 **오분류 탐지 보조**로만 쓴다
--------------------------------------------------------------------------
* 정본 분류 = `00_INDEX_이슈원장.md` §0 **「문서 유형 등재표」**(사람이 선언).
* 강제 = `scripts/doc_type_gate.py`(선언 누락 차단 + 유형별 불변식 검사).
* 이 도구의 역할 = 신호를 출력해 **선언이 구조와 크게 어긋날 때 눈에 띄게** 하는 것.
  🔴 신호가 선언과 다르다고 **선언을 바꾸지 마라** — 위 실측대로 신호가 약하다.
  선언을 바꾸려면 그 문서의 **유지 방식**(고치는가 / 붙이는가)을 근거로 대라.

⚠️ `--calibrate` 는 **의도적으로 FAIL(exit 1) 상태로 남겨 둔다.** 통과하도록 임계값을
   맞추면 「자동 분류가 된다」는 착시가 생기고, 다음 세션이 그 착시를 근거로 쓴다(`P106` 계열).

신호 정의
--------------------------------------------------------------------------
* `append_head`   = 날짜·라벨이 붙은 **항목 제목** 수(`> #### [YYYY-MM-DD O##]` 등).
* `state_row`     = **상태 이모지를 가진 표 본문 행** 수(첫 셀 외 셀 기준).
* `inplace_edit`  = 제자리 수정 흔적 수(`대체됨`·`철회`·`정정`·`폐기`·`~~취소선~~`·`stale`).
                    🔴 위 경위대로 **서술과 편집을 구별하지 못한다.** 참고값이다.
* `date_span`     = 서로 다른 날짜 수.
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC_DIR = os.path.join(ROOT, '20_issue')

STATUS = '🟢🔴🟠🔵🔄⚠️✅❌⬜🔒🛠️⏸🆕🟡🟣'

# 항목 제목 = 인용 접두 허용 · 제목 레벨 1~5 · 안에 날짜(YYYY-MM-DD) 또는 O##/§O## 라벨
RX_APPEND_HEAD = re.compile(
    r'^\s*(?:>\s*)?#{1,5}\s+.*?(?:\d{4}-\d{2}-\d{2}|§?O\d+(?:-[A-Z]+)?)', re.M)
RX_DATE = re.compile(r'\d{4}-\d{2}-\d{2}')
RX_INPLACE = re.compile(r'대체됨|철회|정정|폐기|stale|~~[^~]+~~')


def read_text(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def is_separator(s):
    return set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set()


def signals(text):
    append_head = len(RX_APPEND_HEAD.findall(text))
    state_row = 0
    in_table = False
    for line in text.split('\n'):
        s = line.strip()
        # 인용 안의 표도 센다(이력 항목 안에 표가 있다)
        q = s
        while q.startswith('>'):
            q = q[1:].lstrip()
        if not q.startswith('|'):
            in_table = False
            continue
        if is_separator(q):
            in_table = True
            continue
        if not in_table:
            continue
        cells = q.strip('|').split('|')
        rest = '|'.join(cells[1:]) if len(cells) > 1 else ''
        if any(ch in rest for ch in STATUS):
            state_row += 1
    return {
        'append_head': append_head,
        'state_row': state_row,
        'inplace_edit': len(RX_INPLACE.findall(text)),
        'date_span': len(set(RX_DATE.findall(text))),
    }


def classify(sg):
    a, s = sg['append_head'], sg['state_row']
    if a + s < 5 and sg['date_span'] <= 2:
        return 'static', 0.0
    if a + s == 0:
        return 'static', 0.0
    ratio = a / float(a + s)
    if ratio >= 0.70:
        return 'append', ratio
    if ratio <= 0.30:
        return 'update', ratio
    return 'mixed', ratio


def hub_family(name):
    """조각 파일명 → 허브 파일명(연번 접미 제거). 분류는 **문서 단위**로 한다."""
    m = re.match(r'^(.*)-\d{3}(\.[A-Za-z]+)$', name)
    return (m.group(1) + m.group(2)) if m else name


def gather():
    """문서(허브) 단위로 본문을 모은다 — 조각은 소속 문서에 합산한다."""
    fam = {}
    for root, dirs, files in os.walk(DOC_DIR):
        dirs[:] = [d for d in dirs if d not in ('_archive', '__pycache__')]
        for f in sorted(files):
            if not f.endswith(('.md', '.sql')):
                continue
            key = hub_family(f)
            # 조각 폴더(`01_세션이력_조각`)의 조각도 허브명으로 합산된다
            fam.setdefault(key, []).append(os.path.join(root, f))
    return fam


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--calibrate', action='store_true',
                    help='정답 라벨 2건으로 임계값 타당성을 검증한다')
    a = ap.parse_args()

    fam = gather()
    rows = []
    for doc, paths in sorted(fam.items()):
        text = '\n'.join(read_text(p) for p in sorted(paths))
        sg = signals(text)
        kind, ratio = classify(sg)
        size = sum(os.path.getsize(p) for p in paths)
        rows.append((doc, kind, ratio, sg, len(paths), size))

    print('%-42s %-7s %6s %6s %6s %6s %5s %4s %9s' % (
        '문서', '유형', 'ratio', 'append', 'state', 'inpl', 'date', '파일', '합계B'))
    for doc, kind, ratio, sg, n, size in rows:
        print('%-42s %-7s %6.2f %6d %6d %6d %5d %4d %9s' % (
            doc, kind, ratio, sg['append_head'], sg['state_row'],
            sg['inplace_edit'], sg['date_span'], n, format(size, ',')))

    if a.calibrate:
        print('\n[임계값 타당성 — 정답 라벨 대조]')
        truth = {'01_세션이력.md': 'append',            # doc_role 에 append-only 선언
                 '90_해소완료_로그.md': 'append',        # doc_role 「이력 보존용」
                 '02_상태상세_대시보드_갱신형.md': 'update',   # 파일명·doc_role 「갱신형」
                 '00_INDEX_이슈원장.md': 'update'}       # 상태 대시보드 = 갱신형
        bad = 0
        for doc, kind, ratio, _sg, _n, _s in rows:
            if doc in truth:
                ok = (kind == truth[doc])
                if not ok:
                    bad += 1
                print('  %s %-42s 판정 %-7s ↔ 정답 %-7s (ratio %.2f)'
                      % ('🟢' if ok else '🔴', doc, kind, truth[doc], ratio))
        print('  ⇒ %s (불일치 %d건)' % ('🟢 임계값 타당' if not bad else '🔴 임계값 재조정 필요', bad))
        return 1 if bad else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())

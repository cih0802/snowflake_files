#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_unresolved_issue_summary.py — 미해결 이슈 요약을 **정본에서 추출해** 산출물로 낸다.
# Co-authored with CoCo

[2026-08-30 O124 신설 · 인수인계 「30_output_share 미생산 5종 방향 결정」의 참조 구현]

🔴 왜 필요한가
--------------------------------------------------------------------------
`30_output_share/미해결이슈_요약_O102.md` 는 **손으로 쓴 산출물**이었고, 그 결과
① 파일명에 세션 라벨(`_O102`)이 박혀 판본이 늘어나고
② 본문이 즉시 stale 이 됐다. O124 착수 시점 실측 = **2행이 거짓**이었다:
  · 「`decision_closure_gate` `DEC-41`(6)·`DEC-42`(7) 미봉합 인용처 13건」
    ⇒ O124 가 오탐 축 5종을 분리해 **미봉합 0건**이 됐다.
  · 「종결선언 오매칭(각주를 결정문으로 오인) — 게이트 로직 **미수정**」
    ⇒ O124 가 **수정했다**(축A 괄호 스코프 · 축B 미확정절/표행).
🔴 손으로 적은 목록은 이 워크스페이스에서 반복해 stale 이 됐다(`doc_census.py` docstring
   실측 17건 · `gen_measure_backlog.py` 와 같은 축) ⇒ **목록은 생성물로 만든다.**

🟢 이 도구의 계약 (다른 산출물 생성기도 같은 규격을 따른다)
--------------------------------------------------------------------------
㉠ **입력은 정본뿐이다** — 라이브에 접속하지 않고 수치를 창작하지 않는다(`R2-8-4-c`).
㉡ **분모를 출력에 선언한다** — 「무엇을 세었는가」를 문서가 스스로 밝힌다.
㉢ **닫힌 것을 조용히 버리지 않는다** — 상태 열로 함께 싣는다(`O111 ㉢` 판정축·관측축 분리).
   🔴 필터로 지우면 「없다」와 「내 판정식이 못 본다」를 구별할 수 없게 된다(`O111 ㉠`).
㉣ **좌표를 함께 싣는다** — 이 문서는 색인이고 판정 근거는 정본에 있다.
㉤ **파일명에 세션 라벨을 넣지 않는다** — 판본이 늘어나는 원인이었다.
㉥ **출력은 통째로 다시 쓴다** — 손으로 고치면 다음 생성에서 사라진다(허브와 같은 계약).

사용
--------------------------------------------------------------------------
    python3 scripts/gen_unresolved_issue_summary.py           # stdout 미리보기
    python3 scripts/gen_unresolved_issue_summary.py --write   # 30_output_share/11_… 생성
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, '30_output_share', '11_미해결이슈_요약.md')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_brief import (family_lines, open_sections, open_tasks,   # noqa: E402
                          strip_md, clip)

# ── 분모 정의 ──────────────────────────────────────────────────────────
#   🔴 분모는 **선언**이다. 바꾸면 건수가 바뀌므로 출력에 함께 싣는다.
HEAD_RX = re.compile(r'^#{2,4}\s+')

# 현업확인 항목의 ID 형태 — 이 문서의 실제 표기 체계(`A-7` · `F-1` · `M-1-B` · `N-6-C` · `#81`).
#   🔴 제목 선두 장식(이모지·`**`)을 먼저 걷어낸 뒤 판정한다.
DECO = re.compile(r'^(?:🔴|🟠|🟡|🟢|🔵|✅|❌|🆕|\*|\s)+')
ITEM_ID = re.compile(r'^(?:[A-Z]{1,4}-\d{1,2}(?:-[A-Z0-9]+)?|#\d+|[A-Z]{1,3}\d{1,3}(?:-[A-Z])?)\b')

# 상태 판정 — 🔴 **제목에 이미 적혀 있는 표기**만 읽는다(창작 금지).
STATUS = [
    ('❌ 철회', re.compile(r'❌|철회')),
    ('🟢 해소', re.compile(r'🟢|✅')),
    ('🔴 최우선', re.compile(r'🔴.*최우선|최우선.*🔴')),
    ('🔴 회신 대기', re.compile(r'🔴')),
    ('🟡 확인 요청', re.compile(r'🟡')),
    ('🟠 부분', re.compile(r'🟠')),
    ('🔵 참고', re.compile(r'🔵')),
]
# 하위 서술 절(질문이 아니라 경위·참고)은 **항목이 아니다** — 제목 문구로 판정한다.
NARRATIVE = re.compile(r'무엇을 (발견|바로잡)|왜 저희가|어떤 근거로|확인해 주시면|참고 —'
                       r'|내부 파급|회신 불요|설계 변경 범위')


def status_of(title):
    for name, rx in STATUS:
        if rx.search(title):
            return name
    return '⚪ 표기 없음'


def field_items():
    """`20_현업확인_요청` 의 **ID형 절 제목** 전건 — 상태와 좌표를 붙여 돌려준다."""
    out = []
    for rel, ln, line in family_lines('20_issue/20_현업확인_요청.md'):
        if not HEAD_RX.match(line):
            continue
        title = HEAD_RX.sub('', line).strip()
        bare = DECO.sub('', title)
        m = ITEM_ID.match(bare)
        if not m:
            continue
        out.append({
            'id': m.group(0),
            'title': clip(strip_md(bare), 116),
            'status': status_of(title),
            'kind': '서술' if NARRATIVE.search(bare) else '질의',
            'where': '%s:%d' % (rel, ln),
        })
    return out


def dbt_items():
    """`50_dbt_파이프라인_미결조치` 의 **열린 절**(제목 선두 🔴/🟠/🟡)."""
    hub = '20_issue/50_dbt_파이프라인_미결조치.md'
    return [{'title': clip(strip_md(s['title']), 128),
             'status': status_of(s['title']),
             'where': s['where']} for s in open_sections(hub)]


HEADER = """<!-- LLM-METADATA
doc_id: UNRESOLVED_ISSUE_SUMMARY
doc_role: 미해결 이슈 요약 — 현업 회신 대기 · dbt 미결조치 · 착수표 열린 항목의 **색인**
project: GN_DW (굿네이버스)
created: 2026-08-30
created_by: O124
generator: scripts/gen_unresolved_issue_summary.py
END-METADATA -->

# 미해결 이슈 요약 (자동 생성)

> 🔴🔴 **이 파일은 자동 생성물이다 — 여기에 내용을 쓰지 마라.**
> `python3 scripts/gen_unresolved_issue_summary.py --write` 가 **통째로 다시 쓴다**
> ⇒ 손으로 적은 문장은 **조용히 사라진다**. 내용은 정본에 쓰고 이 파일을 재생성한다.

> 🔴 **선행본 `미해결이슈_요약_O102.md` 는 손으로 쓴 판본이고 stale 이다.**
> 파일명에 세션 라벨이 박혀 판본이 늘어나는 것이 그 판본의 구조적 결함이었다
> ⇒ 이 판본은 **라벨 없는 고정 경로**를 쓴다.

> 🔴 **이 문서는 색인이고 정본이 아니다.** 각 항목은 제목 + 상태 + **좌표**만 싣는다.
> 판정·수치를 인용하려면 그 좌표를 열어라(`R1-3-7` 「대체 근거 금지」).

## 0. 분모 선언 — 무엇을 세었는가

> 🔴 **건수는 분모의 함수다.** 분모를 밝히지 않은 건수는 인용할 수 없다.

| 축 | 정본 | 판정식 |
|---|---|---|
| 현업 회신 대기 | `20_issue/20_현업확인_요청.md` (+ 조각) | `##`~`####` 제목 중 **선두 장식을 걷어낸 뒤 ID 형태**(`A-7`·`F-1`·`M-1-B`·`#81`)로 시작하는 절 **전건** |
| dbt 미결조치 | `20_issue/50_dbt_파이프라인_미결조치.md` (+ 조각) | 절 제목 선두 이모지가 🔴/🟠/🟡 인 것(🟢/✅ 제외) |
| 착수표 | `99_NEXT_SESSION.md` (+ 조각) | 「순」 셀이 **취소선이 아닌** 행 |

> 🔴 **닫힌 항목을 지우지 않는다** — 상태 열에 `🟢 해소`·`❌ 철회`로 함께 싣는다.
> 근거 = 필터로 지우면 「없다」와 「판정식이 못 본다」를 구별할 수 없다(`O111 ㉠`).
> 🟢 그래서 아래 §1 요약표는 **상태별 분해**로 낸다(합계 하나만 내지 않는다).

"""

FOOTER = """
---

## 재생성

```
python3 scripts/gen_unresolved_issue_summary.py --write
```

> 🟢 항목이 닫히면 **정본에서 상태를 바꾸고**(🟢/✅ 또는 취소선) 이 파일을 재생성한다.
> 🔴 이 파일에서 직접 지우지 마라 — 다음 생성에서 되살아난다.

_Co-authored with CoCo_
"""


def build():
    fi = field_items()
    di = dbt_items()
    ti = open_tasks()

    L = [HEADER]
    a = L.append

    a('## 1. 상태별 요약 (실측)')
    a('')
    a('| 축 | 상태 | 건수 |')
    a('|---|---|---:|')
    for axis, items in (('현업 회신 대기', fi), ('dbt 미결조치', di)):
        by = {}
        for it in items:
            by[it['status']] = by.get(it['status'], 0) + 1
        for k in sorted(by, key=lambda s: -by[s]):
            a('| %s | %s | %d |' % (axis, k, by[k]))
    a('| 착수표 | 🟠 열림 | %d |' % len(ti))
    a('')
    a('> 축별 합계 = 현업 **%d** · dbt **%d** · 착수표 **%d**.'
      % (len(fi), len(di), len(ti)))
    a('> 🔴 현업 축 합계에는 `🟢 해소`·`❌ 철회`·`서술` 절이 **포함**돼 있다 —'
      ' 「회신 대기 건수」로 그대로 인용하지 마라. 종류 열을 함께 보라.')
    a('')

    a('## 2. 현업 회신 대기 — 전건 (정본 좌표 포함)')
    a('')
    a('| ID | 상태 | 종류 | 제목 | 정본 좌표 |')
    a('|---|---|---|---|---|')
    for it in fi:
        a('| `%s` | %s | %s | %s | `%s` |'
          % (it['id'], it['status'], it['kind'], it['title'], it['where']))
    a('')

    a('## 3. dbt 파이프라인 미결조치 — 열린 절')
    a('')
    a('| 상태 | 절 | 정본 좌표 |')
    a('|---|---|---|')
    for it in di:
        a('| %s | %s | `%s` |' % (it['status'], it['title'], it['where']))
    a('')

    a('## 4. 착수표 — 열린 항목')
    a('')
    a('| 순 | 작업 | 정지점 | 정본 좌표 |')
    a('|---|---|---|---|')
    for it in ti:
        a('| %s | %s | %s | `%s` |'
          % (it['order'], it['task'], it['stop'], it['where']))
    a(FOOTER)
    return '\n'.join(L), len(fi), len(di), len(ti)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    args = ap.parse_args()
    text, nf, nd, nt = build()
    if not args.write:
        print(text)
        print('── 현업 %d · dbt %d · 착수표 %d · %s B'
              % (nf, nd, nt, format(len(text.encode()), ',')))
        return 0
    with io.open(OUT, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)
    print('🟢 %s 생성 — 현업 %d · dbt %d · 착수표 %d · %s B'
          % (os.path.relpath(OUT, ROOT), nf, nd, nt,
             format(len(text.encode()), ',')))
    return 0


if __name__ == '__main__':
    sys.exit(main())

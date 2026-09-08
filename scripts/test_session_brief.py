#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_session_brief.py — `session_brief.py` 추출기의 **음성 테스트**.

[2026-08-28 O106 신설 · `R3-2` 의 집행]

🔴 왜 음성 테스트인가
--------------------------------------------------------------------------
`R3-2` = *"새로 만든 게이트를 **실패 케이스**로 음성 테스트했는가? 통과만 보면
그 게이트가 무엇을 **못 잡는지** 모른다."*
O106 이 이 도구를 만들며 실제로 **두 번** 틀렸다:
  · 착수표 추출이 「4열 이상 표 행」을 전부 먹어 허브 조각 목차까지 실렸다.
  · stale 대조가 「같은 줄 문서명 1개」만 봐서 17건 중 13건만 잡았다.
⇒ 정상 입력만 돌려서는 **둘 다 발견되지 않았다.** 합성 입력으로 경계를 고정한다.

실행
--------------------------------------------------------------------------
    python3 scripts/test_session_brief.py        # 전건 통과해야 exit 0
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_brief as sb                                   # noqa: E402

FAILS = []
#: 🔴 [O112] 단정 수·축 수를 **손으로 적지 않는다** — 종전 머리 문구는 「6축 18개」였는데
#: 실측 단정은 **19개**였다(축을 늘리며 갱신하지 않으면 조용히 stale 이 된다 · `R3-9 ㉦`).
#: ⇒ `check()` 가 세고 `print(' 축…')` 가 축을 센다. 값이 아니라 **재는 방법**이 정본이다.
COUNTS = {'checks': 0, 'axes': 0}


def axis(title):
    COUNTS['axes'] += 1
    print(' 축%d %s' % (COUNTS['axes'], title))


def check(name, got, want):
    COUNTS['checks'] += 1
    if got == want:
        print('  ✅ %s' % name)
    else:
        print('  🔴 %s — got=%r want=%r' % (name, got, want))
        FAILS.append(name)


def L(text):
    """합성 입력을 `family_lines` 형식으로 만든다."""
    return [('SYNTH.md', i, ln) for i, ln in enumerate(text.split('\n'), 1)]


def LF(*pairs):
    """여러 **파일**의 스트림을 이어붙인다 — (파일명, 본문) 쌍을 순서대로.

    🔴 조각 경계 결함은 **한 파일 안에서는 재현되지 않는다** ⇒ 픽스처가 다중 파일이어야 한다.
    """
    out = []
    for rel, text in pairs:
        for i, ln in enumerate(text.split('\n'), 1):
            out.append((rel, i, ln))
    return out


#: 조각 머리말 3줄 — 🔴 실제 조각 선두를 그대로 쓴다(창작 금지 · `sb.BODY_BEGIN` 재사용).
PRE = ('<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 015/019 | 허브 = 99_NEXT_SESSION.md '
       '| 원문 1832~1896행 -->\n'
       '<!-- 🔴 이 파일은 원문 무변경 조각이다. -->\n' + sb.BODY_BEGIN + '\n')


# ── 축 1: 착수표 — 취소선 = 완료 ────────────────────────────────────────
TASKS = """
| 순 | 작업 | 정지점 | 왜 이 순서인가 |
|---|---|---|---|
| ~~①~~ | ~~끝난 일~~ | — | ✅ 완료 |
| **②** | 🔴 열린 일 | 없음 | 이유 |
| ~~③~~ | ✅ **[O99 완료]** 다른 끝난 일 | — | 이유 |
| **④** | 🟠 또 열린 일 | 🔴 승인 필요 | 이유 |
"""

# ── 축 2: 다른 표는 착수표가 아니다(헤더 서명 한정) ─────────────────────
NOT_TASKS = """
| 조각 | 구 행범위 | 줄 | KB | 선두 절 |
|---|---|---|---|---|
| `x-001.md` | 1~155 | 155 | 16.0 | 아무 절 |
| `x-002.md` | 156~310 | 155 | 13.7 | 다른 절 |

| # | 결함 | 조문 | 비고 |
|---|---|---|---|
| ㉠ | 뭔가 틀렸다 | R2-8 | — |
"""

# ── 축 3: 절 상태 이모지 ────────────────────────────────────────────────
SECTIONS = """
## 🟢 O91 — 끝난 절
본문
## 🔴🔴 O88-C — 열린 절
본문
## ✅ O70 — 닫힌 절
본문
## 🟠 O99 — 부분 미결
본문
## 제목만 있고 이모지 없는 절
본문
"""

# ── 축 4: 「여기서 시작한다」 적층 — 취소선 아닌 것 중 최신 ──────────────
HANDOFF = """
## 0-AAA. 🔴 [2026-08-19 O88 필독 — **여기서 시작한다.**]
### ▣ 옛 항목
## 0-BBB. 🔴 [2026-08-20 O91 필독 — ~~여기서 시작한다~~ ⇒ 위 절이 먼저다]
### ▣ 승계된 항목
## 0-CCC. 🔴 [2026-08-28 O105 필독 — **여기서 시작한다.**]
### ▣ 최신 항목 하나
### ▣ 최신 항목 둘
"""

# ── 축 4-B: 🔴🔴 blockquote 인수인계 (2026-08-30 O123-D 신설 · 오염 기반) ──
#   🔴 **이 축이 없어서 실사고를 놓쳤다.** 위 `HANDOFF` 는 `### ▣` 를 **비-quote** 로만 쓰는데,
#     실제 `99_NEXT_SESSION-001.md` 의 현행 절(`§0-AAAA`)은 **전부 `> ### ▣`** 였다
#     ⇒ 추출기가 **8건을 0건으로** 보고했고 정상 입력 테스트는 **전건 통과**했다.
#   ⇒ 🟢 판정식 = **테스트 픽스처는 「정본이 실제로 쓰는 형태」를 그대로 넣어라.**
#     내가 만든 깔끔한 형태만 넣으면 그 테스트는 **형식 드리프트를 구조적으로 못 잡는다.**
HANDOFF_QUOTED = """
## 0-ZZZ. 🔴 [2026-08-29 O119 필독 — ~~여기서 시작한다~~] → 승계됨
### ▣ ZZZ1 비-quote 형태(옛 판본)
## 0-AAAA. 🔴🔴 [2026-08-30 O123 필독 — **여기서 시작한다.** §0-ZZZ 는 승계됐다]
>
> ### ▣ AAAA1 quote 형태 하나
> 본문 줄
> ### ▣ AAAA2 quote 형태 둘
>   ### ▣ AAAA3 들여쓴 quote
>> ### ▣ AAAA4 이중 quote
## 0-BBBB. 🔴 [2026-08-01 O99 필독 — **여기서 시작한다.**] 날짜가 더 옛것
> ### ▣ 뽑히면 안 되는 항목
"""

# ── 축 4-C: 🔴🔴 취소선 관례 변경 + 동일 날짜 동시후보 (2026-09-08 O143 신설 · 오염 기반) ──
#   🔴 **이 축이 없어서 실사고를 놓쳤다.** 위 두 픽스처는 취소선을 전부 **구관례**로 쓴다
#     (`~~여기서 시작한다~~` = 기호가 그 문구에 **바로 붙는다**).
#     그런데 O129 이후 정본 관례가 **대괄호 전체를 감싸는 형태**로 바뀌었다:
#       `## 0-NNNN. ~~🔴🔴 [… **여기서 시작한다.** …]~~ ➔ 🟢 [… 승계됨]`
#     ⇒ 이 문안에는 `~~여기서 시작한다` 라는 **연속 부분문자열이 없다**
#       ⇒ 종전 배제 조건(`'~~여기서 시작한다' in t`)이 **승계된 절을 후보로 남겼다.**
#   🔴 그리고 O140·O141·O142 세 절의 **날짜가 모두 같아서**(`2026-09-07`)
#     `max(key=date)` 의 동점 규칙(**최초 등장**)이 **가장 오래된 절**을 골랐다.
#     ⇒ 원인이 **둘**이다. 한쪽만 고치면 다른 한쪽으로 같은 오선택이 재발한다.
#   🔴 실해 = 브리핑이 O140 의 열린 작업 목록을 실어, O141 이 이미 닫은 `㊵`·`⑫` 가
#     열림으로 보였다 ⇒ 다음 세션이 **닫힌 작업을 다시 한다**(브리핑 체계의 목적 무력화).
#   ⇒ 🟢 판정식 = **취소선은 리터럴 인접이 아니라 「그 문구가 취소선 구간 안에 있는가」로 본다.**
#     🟢 그리고 **동점은 문서 순서상 마지막**이 현행이다(`99_NEXT` 는 절이 적층된다).
#   🔴 픽스처는 `99_NEXT_SESSION_조각/99_NEXT_SESSION-028.md:19·50·81` 원문을 그대로 옮겼다(창작 0).
HANDOFF_WRAPPED = """
## 0-NNNN. ~~🔴🔴 [2026-09-07 O140 필독 — **여기서 시작한다.** §0-MMMM 은 승계됐다]~~ ➔ 🟢 [2026-09-07 O141 승계됨]
### ▣ NNNN1 승계된 항목 — 뽑히면 안 된다
## 0-OOOO. ~~🔴🔴 [2026-09-07 O141 필독 — **여기서 시작한다.** §0-NNNN 은 승계됐다]~~ ➔ 🟢 [2026-09-07 O142 승계됨]
### ▣ OOOO1 승계된 항목 — 뽑히면 안 된다
## 0-PPPP. 🔴🔴 [2026-09-07 O142 필독 — **여기서 시작한다.** §0-OOOO 은 승계됐다]
### ▣ PPPP1 현행 항목 하나
### ▣ PPPP2 현행 항목 둘
"""

#: 🔴 원인 2 를 **단독으로** 고정한다 — 취소선이 전혀 없어도 동일 날짜면 마지막이 현행이다.
HANDOFF_TIE = """
## 0-AAA. 🔴 [2026-09-07 O200 필독 — **여기서 시작한다.**]
### ▣ 옛 항목
## 0-BBB. 🔴 [2026-09-07 O201 필독 — **여기서 시작한다.**]
### ▣ 새 항목 하나
### ▣ 새 항목 둘
"""

#: 🔴 역방향 오탐 가드 — 취소선 구간이 **그 문구를 감싸지 않으면** 배제하지 않는다.
#:   (제목 어딘가에 무관한 취소선이 있다는 이유로 현행 절을 버리면 브리핑이 비어버린다.)
HANDOFF_UNRELATED_STRIKE = """
## 0-CCC. 🔴 [2026-09-07 O202 필독 — **여기서 시작한다.**] ~~옛 처방은 철회~~
### ▣ 살아야 하는 항목
"""


def main():
    print('[음성 테스트] session_brief 추출기')

    axis('착수표 — 취소선·✅ 는 완료로 제외')
    t = sb.open_tasks(L(TASKS))
    check('열린 행 수', len(t), 2)
    check('열린 순번', [x['order'] for x in t], ['②', '④'])
    check('정지점 추출', t[1]['stop'], '🔴 승인 필요')

    axis('헤더 서명 한정 — 조각목차·결함표는 착수표가 아니다')
    check('비착수표 0건', len(sb.open_tasks(L(NOT_TASKS))), 0)
    check('혼합 입력도 착수표만', len(sb.open_tasks(L(NOT_TASKS + TASKS))), 2)

    axis('절 상태 — 🟢/✅ 제외 · 무표기 제외')
    s = sb.open_sections('x', L(SECTIONS))
    check('열린 절 수', len(s), 2)
    check('열린 절 선두', s[0]['title'].startswith('🔴🔴 O88-C'), True)

    axis('인수인계 — 취소선 아닌 것 중 최신 날짜')
    cur, subs = sb.current_handoff(L(HANDOFF))
    check('현행 절 날짜', cur['date'], '2026-08-28')
    check('현행 절 O105', 'O105' in cur['title'], True)
    check('현행 절 하위 항목 수', len(subs), 2)

    axis('🔴🔴 인수인계 blockquote — 8건을 0건으로 본 실사고 (O123-D)')
    # 🔴 정상 형태(위 축4)만으로는 0건이었다. 아래가 실제 정본 형태다.
    check('dequote 단일', sb.dequote('> ### ▣ X'), '### ▣ X')
    check('dequote 들여쓰기', sb.dequote('>   ### ▣ X'), '### ▣ X')
    check('dequote 이중', sb.dequote('>> ### ▣ X'), '### ▣ X')
    check('dequote 비-quote 무변경', sb.dequote('### ▣ X'), '### ▣ X')
    cq, sq = sb.current_handoff(L(HANDOFF_QUOTED))
    check('현행 절 = 최신 O123', 'O123' in cq['title'], True)
    check('현행 절 날짜', cq['date'], '2026-08-30')
    check('quote 항목 전건 추출', len(sq), 4)
    check('AAAA1 추출', any('AAAA1' in s['title'] for s in sq), True)
    check('이중 quote 도 추출', any('AAAA4' in s['title'] for s in sq), True)
    # 🔴 역방향 = 다른 절의 항목을 삼키지 않는다(`## ` 경계 판정이 quote 정규화 후에도 유효).
    check('타 절 항목 미포함', any('뽑히면 안 되는' in s['title'] for s in sq), False)
    check('승계 절 항목 미포함', any('ZZZ1' in s['title'] for s in sq), False)

    axis('빈 입력 — 예외 없이 0건')
    check('빈 착수표', len(sb.open_tasks(L(''))), 0)
    check('빈 절', len(sb.open_sections('x', L(''))), 0)
    check('빈 인수인계', sb.current_handoff(L(''))[0], None)

    axis('게이트 판정 열 — 힌트 줄이 아니라 판정 줄을 본다 (O109 D5)')
    # 🔴 실제 출력 형태를 그대로 쓴다(창작 금지). 종전 구현은 아래 두 건을 반대로 표시했다.
    typ = ['[문서 유형 게이트] …', '🟡 통과(경고 1건)',
           ' - 여유 부족 1건 — 갱신형은 `--rebalance`, 은퇴 가능하면 `retire_rows.py`']
    cla = ['[조문 번호 순서 게이트] 문서 3종',
           '✅ 게이트 통과 — 조문 93개 · 역전 0 · 중복 0 (경고 0건)']
    crd = ['[문서 좌표 실재 게이트] 스캔 165파일',
           '✅ 게이트 통과 — 경로가 깨진 좌표 0건 (경고 9건은 사람 판단)']
    check('판정 줄 선택(힌트 줄 배제)', sb.gate_verdict(typ), '🟡 통과(경고 1건)')
    check('경고 있는 통과 = 🟡', sb.gate_mark(0, sb.gate_verdict(typ)), '🟡')
    check('경고 0건은 ✅', sb.gate_mark(0, sb.gate_verdict(cla)), '✅')
    check('경고 9건은 🟡', sb.gate_mark(0, sb.gate_verdict(crd)), '🟡')
    check('rc≠0 은 🔴', sb.gate_mark(1, '✅ 게이트 통과 — 0건'), '🔴')
    check('판정 줄 부재 시 마지막 줄', sb.gate_verdict(['[머리말]', '본문뿐']), '본문뿐')

    axis('조각 경계 — 표·절이 경계를 넘어도 세고, 경계를 빌미로 과대집계하지 않는다')
    # 🔴 이 축은 O112 가 신설했다. 종전 구현은 경계 뒤 본문 행을 **전부 탈락**시켜
    #   「열린 착수표」를 과소 보고했고, 그 감소는 「닫아서 줄었다」와 구별되지 않았다.
    #   ⇒ 재현율(경계 넘어 세는가)과 오탐(없는 표를 만들지 않는가)을 **양축으로** 고정한다.
    # 🔴 픽스처는 **실제 조각 형태**를 따른다 — 조각 파일은 **마지막 개행이 없다**
    #   (실측: `99_NEXT_SESSION-014/-015.md` 둘 다 `endswith('\n') == False`).
    #   근거 = `split_doc.collect_bodies` + `'\n'.join(parts)` 계약. 꼬리 개행을 붙이면
    #   스트림 끝에 빈 줄이 생겨 `inside` 가 꺼지는데, 그것은 **도구 결함이 아니라 픽스처 오류**다.
    head = '\n| 순 | 작업 | 정지점 | 왜 이 순서인가 |\n|---|---|---|---|\n'
    a_tail = head + '| **②** | 🔴 앞 조각의 열린 일 | 없음 | 이유 |'
    b_body = ('| ~~③~~ | ~~끝난 일~~ | — | ✅ 완료 |\n'
              '| **⑬** | 🟡 경계 뒤 열린 일 | 없음 | 이유 |')
    # 7-a 재현율: 헤더가 앞 조각에 있고 본문이 뒤 조각에 이어진다 ⇒ 둘 다 세어야 한다.
    t = sb.open_tasks(sb.strip_chunk_preamble(
        LF(('c-001.md', a_tail), ('c-002.md', PRE + b_body))))
    check('경계 넘어 열린 행 수', len(t), 2)
    check('경계 넘어 순번', [x['order'] for x in t], ['②', '⑬'])
    check('경계 뒤 행의 파일 좌표', t[1]['where'].split(':')[0], 'c-002.md')
    # 🔴 좌표의 행 번호는 **원본 그대로**여야 한다 — 머리말 3줄 + 취소선 행 1줄 뒤 = 5행.
    check('경계 뒤 행의 행번호 보존', t[1]['where'], 'c-002.md:5')
    # 7-b 오탐: 앞 조각의 표가 **닫힌 뒤**(비표 줄로 끝남) 뒤 조각이 헤더 없이 표 행으로
    #   시작하면 그것은 착수표가 아니다 ⇒ 머리말을 걷어냈다는 이유로 이어 붙이면 안 된다.
    check('헤더 없는 경계 표는 0건', len(sb.open_tasks(sb.strip_chunk_preamble(
        LF(('c-001.md', a_tail + '\n\n본문 문장(표 종료)'),
           ('c-002.md', PRE + b_body))))), 1)
    # 7-c 머리말이 없는 파일(허브)은 한 줄도 잃지 않는다.
    check('센티넬 없는 파일은 무손실', len(sb.strip_chunk_preamble(
        LF(('hub.md', 'a\nb\nc')))), 3)
    # 7-d 머리말은 센티넬 줄까지만 버린다(본문 첫 줄을 먹지 않는다).
    kept = sb.strip_chunk_preamble(LF(('c-002.md', PRE + '첫 본문\n')))
    check('센티넬 다음 줄이 본문 선두', kept[0][2], '첫 본문')
    check('센티넬 다음 줄의 번호', kept[0][1], 4)
    # 7-e 절 추출·인수인계도 같은 스트림을 쓴다 ⇒ 경계 뒤 절 제목이 살아야 한다.
    s = sb.open_sections('x', sb.strip_chunk_preamble(
        LF(('c-001.md', '## 🟢 닫힌 절\n'), ('c-002.md', PRE + '## 🔴 경계 뒤 열린 절\n'))))
    check('경계 뒤 열린 절 수', len(s), 1)
    check('경계 뒤 열린 절 좌표', s[0]['where'], 'c-002.md:4')

    axis('🔴🔴 인수인계 취소선 관례 변경 + 동일 날짜 동점 (O143)')
    # 🔴 원인 1+2 동시 재현 = 정본 §0-NNNN·§0-OOOO·§0-PPPP 원문 그대로.
    cw, sw = sb.current_handoff(L(HANDOFF_WRAPPED))
    check('현행 절 = O142(§0-PPPP)', 'O142' in cw['title'], True)
    check('현행 절 라벨 0-PPPP', '0-PPPP' in cw['title'], True)
    check('승계 절 O140 미선택', 'O140' in cw['title'], False)
    check('승계 절 O141 미선택', 'O141' in cw['title'], False)
    check('현행 절 하위 항목 수', len(sw), 2)
    check('승계 절 항목 NNNN1 미포함', any('NNNN1' in x['title'] for x in sw), False)
    check('승계 절 항목 OOOO1 미포함', any('OOOO1' in x['title'] for x in sw), False)
    # 🔴 원인 2 단독 = 취소선이 없어도 동일 날짜면 **문서 순서상 마지막**이 현행이다.
    ct, st = sb.current_handoff(L(HANDOFF_TIE))
    check('동점 시 마지막 절 채택', 'O201' in ct['title'], True)
    check('동점 시 첫 절 미채택', 'O200' in ct['title'], False)
    check('동점 절 하위 항목 수', len(st), 2)
    # 🔴 역방향 오탐 = 무관한 취소선 때문에 현행 절을 버리지 않는다.
    cu, su = sb.current_handoff(L(HANDOFF_UNRELATED_STRIKE))
    check('무관한 취소선은 배제 사유 아님', cu is not None and 'O202' in cu['title'], True)
    check('무관한 취소선 절의 항목 보존', len(su), 1)

    axis('🔴🔴 착수표 ↔ 인수인계 열린 목록 누락 대조 (O143 신설)')
    # 🔴 왜 이 축인가: 실측 = 착수표 열림 `② ④ ⑪ ⑭ ⑱ ㊳` ↔ `§0-PPPP` 목록 `② ④ ⑪ ⑱`
    #   ⇒ `⑭`(P1 🔴🔴 · 현업 결정 대기)와 `㊳` 가 **닫히지 않은 채 인수인계에서 사라졌다.**
    #   어느 게이트도 이 축을 보지 않았다 ⇒ 두 등록부의 결합이 사람 손에만 있었다.
    GAP_NEXT = (TASKS + """
## 0-QQQQ. 🔴🔴 [2026-09-08 O143 필독 — **여기서 시작한다.**]
### ▣ QQQQ2 다음 세션 열린 작업
- **[P1] ②** 🔴 열린 일
- **[P2] BLOCKING-9** 🟠 착수표 순번이 아닌 항목(역방향 오탐 유발원)
""")
    gl = L(GAP_NEXT)
    gt = sb.open_tasks(gl)
    check('픽스처 열린 착수표 2건', [x['order'] for x in gt], ['②', '④'])
    gap = sb.handoff_gap(gt, lines=gl)
    # ② 는 인수인계에 있고 ④ 는 없다 ⇒ 누락은 ④ 하나여야 한다.
    check('누락 1건 검출', [g['order'] for g in gap], ['④'])
    # 🔴 역방향 오탐 = 인수인계에만 있는 `BLOCKING-9` 를 결함으로 세지 않는다.
    check('역방향은 세지 않는다', all(g['order'] in ('②', '④') for g in gap), True)
    check('누락 항목은 착수표 좌표를 운반', gap[0]['where'].startswith('SYNTH.md:'), True)
    # 🔴 전건 등장 시 0건(오탐 방지) — 인수인계에 ④ 를 추가하면 누락이 사라져야 한다.
    gl2 = L(GAP_NEXT + '- **[P2] ④** 🟠 또 열린 일\n')
    check('전건 등장 시 0건', sb.handoff_gap(sb.open_tasks(gl2), lines=gl2), [])
    # 🔴 현행 절이 없으면 판정하지 않는다(빈 본문을 「전건 누락」으로 오판하면 안 된다).
    check('현행 절 부재 시 0건', sb.handoff_gap(sb.open_tasks(L(TASKS)), lines=L(TASKS)), [])

    print('')
    if FAILS:
        print('🔴 실패 %d건: %s' % (len(FAILS), ', '.join(FAILS)))
        return 1
    print('✅ 전건 통과 — %d축 %d개 단정' % (COUNTS['axes'], COUNTS['checks']))
    return 0


if __name__ == '__main__':
    sys.exit(main())

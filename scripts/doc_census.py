#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""doc_census.py — 문서군 규모를 **실측**하고, 문서에 손으로 적힌 수와 **대조**한다.

[2026-08-28 O106 신설 · `R1-6-16`·`R2-8-4-c` 의 집행 장치]

🔴 왜 필요한가 (실측 근거 · 이 도구의 존재 이유)
--------------------------------------------------------------------------
「조각 수」를 손으로 적은 자리가 **3곳**이고 O106 착수 시점 실측에서
**9문서 중 8문서 · 총 15건**이 stale 이었다. 세 곳이 **서로 다른 값**을 적고 있었다:

    문서            실측  §0분할표  §0유형등재표  init_ihcho
    00_INDEX          7      5         5           5
    02_상태상세        8      4         7           —
    20_현업확인        7      7 ✓       5           —
    30_설계            9      7         7           —
    50_dbt            18     12        13          12
    01_세션이력        35     26        31          26
    99_NEXT           13      6         8           6

🔴 **이 문제는 이미 두 번 「경고」로 처방됐고 두 번 다 재발했다.**
  · O83-H 가 분할표 **8행 전건 과소**를 교정하고 *"다음 세션에는 또 어긋난다 ⇒ 재라"* 를 적었다.
  · O90 이 유형등재표 **4건**을 교정하고 *"인용하지 말고 실측하라"* 를 적었다.
  ⇒ **경고를 적은 그 표가 다시 stale 이 됐다.** 진단은 끝났고 **집행 장치가 없었을 뿐이다.**

🟢 그래서 이 도구는 두 가지를 한다
--------------------------------------------------------------------------
1. **실측 출력** — 인용할 수를 여기서 얻는다(문서에서 읽지 않는다).
2. **stale 대조(blocking 가능)** — 문서에 적힌 수를 찾아 실측과 비교한다.
   ⇒ 손으로 적은 수가 남아 있으면 **게이트가 잡는다.** 경고문에 의존하지 않는다.

🔴 이 도구가 하지 않는 것
--------------------------------------------------------------------------
· **DB 를 보지 않는다.** 파일시스템만 읽는다(이 계정은 문서작업용 · `92_실측필요_후속작업.md`).
· 문서를 **고치지 않는다.** 대조 결과만 낸다(수정은 `fix_stale_counts.py`).

사용
--------------------------------------------------------------------------
    python3 scripts/doc_census.py              # 인벤토리 + stale 대조
    python3 scripts/doc_census.py --strict      # stale 1건이라도 있으면 exit 1
    python3 scripts/doc_census.py --json        # 기계 판독(session_brief.py 가 소비)
    python3 scripts/doc_census.py --read-budget # 세션 시작 독해량만
"""

import argparse
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC_DIR = os.path.join(ROOT, '20_issue')

# 🔴🔴 [O106 5차 자기시정] **이 한 줄이 없으면 형제 모듈 import 가 실패한다.**
#   `/workspace` 는 **심링크**라 `python3 scripts/doc_census.py` 로 실행할 때
#   스크립트 디렉터리가 `sys.path` 에 들어오지 않는다
#   ⇒ `from doc_type_gate import …` 가 `ModuleNotFoundError` 를 내고,
#     유형 판정이 **조용히 기본값(갱신형)으로 떨어져** `01_세션이력`(append형)을 🟠 로 오탐했다.
#   🔴 **import 경로로 부르면 정상**이라 「같은 함수가 다른 값을 낸다」로만 보였다.
#   `doc_type_gate.py`·`session_brief.py` 도 같은 이유로 이 줄을 갖고 있다 — 워크스페이스 관례다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MAX_BYTES = 40 * 1024
MIN_FREE = 0.20

# ── 분할 문서 = (허브 상대경로, 조각 위치) ────────────────────────────────
#   조각 위치 = 'sibling'(형제 파일 `-001.md`) | 폴더명(예: '01_세션이력_조각')
#   🔴 이 목록은 손으로 유지한다. glob 전체를 넣으면 산출물·백업이 섞여
#     게이트가 상시 빨강이 된다(`P130`). 신규 분할 문서를 만들면 여기 등재한다.
FAMILIES = [
    ('20_issue/00_INDEX_이슈원장.md', '00_INDEX_이슈원장_조각'),
    ('20_issue/01_세션이력.md', '01_세션이력_조각'),
    ('20_issue/02_상태상세_대시보드_갱신형.md', '02_상태상세_대시보드_갱신형_조각'),
    ('20_issue/03_이슈상세.md', '03_이슈상세_조각'),
    ('20_issue/10_진단_원인분석.md', '10_진단_원인분석_조각'),
    ('20_issue/20_현업확인_요청.md', '20_현업확인_요청_조각'),
    ('20_issue/30_설계_의사결정.md', '30_설계_의사결정_조각'),
    ('20_issue/50_dbt_파이프라인_미결조치.md', '50_dbt_파이프라인_미결조치_조각'),
    ('20_issue/90_해소완료_로그.md', '90_해소완료_로그_조각'),
    ('99_NEXT_SESSION.md', '99_NEXT_SESSION_조각'),
]

# ── 미분할 상시 독해 문서 ────────────────────────────────────────────────
SINGLES = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '00_guides/01_문서분할_규약.md',
    '00_guides/02_파일쓰기_안전규약.md',
    '20_issue/31_코드군_매핑등재부.md',
    '20_issue/40_입고대기_원천의존.md',
    '20_issue/91_사고사례집.md',
    '20_issue/92_실측필요_후속작업.md',
    '20_issue/00_BRIEF.md',
]

# ── 「조각 수」를 손으로 적은 자리 = 대조 분모 ────────────────────────────
#   🔴 분모가 좁으면 게이트가 착시가 된다(`P106`) ⇒ 적힌 곳을 전부 넣는다.
COUNT_SOURCES = [
    '20_issue/00_INDEX_이슈원장.md',          # §0 분할표 + §0 유형등재표(조각에 있다)
    '00_guides/01_문서분할_규약.md',
    '00_guides/00_작업지침_세션운영규칙.md',
    '.snowflake/cortex/skills/init_ihcho/SKILL.md',
]

# 세션 시작에 「반드시」 읽는 문서 — 이 목록이 독해 예산의 정본이다.
SESSION_START = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '20_issue/00_BRIEF.md',
]

# 손으로 적힌 수의 형태. 🔴 `(\d+)개` 는 「조각 N개」 이외에도 쓰이므로
#   **조각 문맥 토큰이 같은 줄에 있을 때만** 후보로 본다.
CTX = ('조각', '-001', '형제', '폴더')
PATS = [
    re.compile(r'\((\d+)\s*개\)'),
    re.compile(r'조각\s*\*{0,2}(\d+)\s*개'),
    re.compile(r'(\d+)\s*조각'),
    re.compile(r'조각\s+(\d+)\b'),
    re.compile(r'`-001`\s*~\s*`-0*(\d+)`'),
    re.compile(r'`-001`\s*~\s*`-(\d+)`'),
]

# 🔴🔴 [O106 2차 자기시정] **과거 기록은 stale 이 아니다.**
#   `90` 을 FAMILIES 에 넣자 원장 대시보드 행 2개가 오탐으로 잡혔다:
#     · *"`R1-1` 원장 **7조각 중 2개만** 읽고 착수"*  ← 그때의 위반 기록
#     · *"사용자 승인 `--rebalance` **7→8조각**으로 자리 확보"* ← 그때의 조치 기록
#   둘 다 **과거 상태의 서술**이라 「현재와 다르다」가 정상이다.
#   ⇒ 「분할 전 줄/바이트는 의도적 고정」과 같은 축이다(원장 §0 명시).
HISTORY = re.compile(r'\d+\s*→\s*\d+\s*조각|조각\s*중\s|분할 전|구 행범위|presplit|prerebalance')

# 🔴🔴 [O106 2차 자기시정] **긴 행에서는 「같은 줄」이 귀속 근거가 못 된다.**
#   원장 §1 행은 최대 **1,644자**이고 그 안에 문서명이 여러 개 나온다
#   ⇒ 「가장 긴 stem」으로 골랐더니 무관한 문서(`90`)에 귀속됐다.
#   ⇒ **수치 바로 앞 NEAR 자 안에서 가장 가까운 문서명**에 귀속한다.
NEAR = 80

# 🔴 [O106 3차 자기시정 · `test_doc_census.py` 가 적발] 「같은 줄 문서명 1개」 폴백은
#   **짧은 줄에서만** 유효하다. 긴 행(원장 §1 = 최대 1,644자)에서는 수치와 문서명이
#   수백 자 떨어져 있어도 폴백이 발동해 **무관한 문서에 귀속**했다.
#   ⇒ 폴백에 **줄 길이 가드**를 둔다. 긴 행은 근접 귀속만 허용한다.
SHORT_LINE = 300

# ── [O106] 바이트·분할여부 축 ───────────────────────────────────────────
#   🔴🔴 **왜 추가했나**: 첫 판본은 **조각 수만** 봤고, 그 결과 등재표 「처리」 열의
#     **바이트 수치와 `미분할` 표기가 검사 밖**이었다. O106 종료 점검에서 3건이 나왔다:
#       · `40_입고대기_원천의존` 기재 12,684B ↔ 실측 18,784B
#       · `01_문서분할_규약`     기재 17,131B ↔ 실측 21,231B
#       · `90_해소완료_로그`     기재 「미분할」 ↔ **O106 이 분할했다**(그 세션이 만든 stale)
#     🔴 조각 수 축만 닫고 「stale 0」이라 보고한 것은 **분모가 좁은 게이트**(`P106`)다 —
#       이 도구가 막으려던 바로 그 상태를 도구 자신이 갖고 있었다.
#   ⇒ 같은 근접 귀속 규칙으로 **바이트**와 **`미분할` 표기**도 대조한다.
BYTE_PATS = [
    re.compile(r'\(([\d,]{4,})\s*B\)'),          # 미분할(14,891B)
    re.compile(r'([\d,]{4,})\s*B\b'),            # … 21,231B …
]
UNSPLIT = re.compile(r'(?<!~)미분할')          # 🔴 `~~미분할~~`(취소선 = 과거 기록)은 제외
# 바이트 축의 과거 기록 제외 — 「N B → M B」 같은 변화 서술과 분할 당시 기록.
BYTE_HISTORY = re.compile(r'B\s*→|→\s*[\d,]+\s*B|분할 전|원문 줄|구 행범위|B\)\(')

# 🔴 [O106 8차 자기시정] **목표치·상한은 현재 크기 주장이 아니다.**
#   `00_BRIEF` 행의 *"목표 ≤32,768B(축3 여유 20%)"* 가 「기재 32,768 ↔ 실측 11,213」로 오탐됐다.
#   ⇒ 수치 **바로 앞**에 목표·상한 표지가 있으면 판정하지 않는다.
BYTE_TARGET = re.compile(r'(목표|상한|이내|최대|이하|≤|<=|<)\s*[~약]?\s*$')


def row_key_stem(line, keys):
    """표 행이면 **첫 셀(행 키)** 에서 문서 stem 을 찾는다. 표가 아니면 None.

    🔴🔴 [O106 7차 자기시정] `미분할`·바이트 축을 근접/이월 귀속으로 판정했더니
      등재표에서 **오탐 5건**이 났다. 원인 = 등재표 행은
      `| \\`문서명.md\\` | 유형 | 근거(장문) | 처리 |` 구조라 **문서명과 「미분할」이 80자 넘게 떨어져**
      근접 귀속이 실패하고 **직전 행의 carry 로 흘렀다**(`90_해소완료_로그` 가 3행에 번졌다).
      ⇒ 표 행에서는 **첫 셀이 곧 그 행의 주체**다 ⇒ 첫 셀로 귀속한다(가장 강한 신호).
    """
    s = line.strip()
    if not s.startswith('|'):
        return None
    first = s.strip('|').split('|')[0]
    hits = sorted([k for k in keys if k in first], key=len, reverse=True)
    return hits[0] if hits else None


def read_text(p):
    with io.open(p, encoding='utf-8', errors='replace') as fh:
        return fh.read()


def nbytes_of(p):
    return os.path.getsize(p)


def chunk_paths(hub_rel, where):
    """허브의 조각 파일 경로 목록(정렬).

    🔴🔴 [2026-08-28 O107] `where` 가 `'sibling'` 이면 **허브의 `SPLIT-OUTDIR` 마커를 먼저 본다.**
      근거 = 조각 위치의 **정본은 마커**다(`R1-6-10` · `doc_heading_gate`·`index_row_gate`·
      `doc_type_gate` 는 이미 마커를 읽는다). 이 함수만 호출자가 준 문자열을 믿으면
      **폴더로 이전한 문서를 「조각 0개」로 보고**하고, 그 값을 쓰는 `session_brief` 는
      **허브만 읽어 착수표·인수인계를 조용히 비운다**(세션 시작이 깨진다).
      ⇒ 선언(`FAMILIES`)과 실제(마커)가 어긋나면 **실제를 따르고**, 불일치는 stale 대조가 잡는다.
    """
    hub = os.path.join(ROOT, hub_rel)
    stem, ext = os.path.splitext(hub)
    out = []
    if where == 'sibling':
        marked = outdir_marker(hub)
        if marked:
            where = marked
    if where == 'sibling':
        n = 1
        while True:
            c = '%s-%03d%s' % (stem, n, ext)
            if not os.path.exists(c):
                break
            out.append(c)
            n += 1
    else:
        d = os.path.join(os.path.dirname(hub), where)
        if os.path.isdir(d):
            out = [os.path.join(d, f) for f in sorted(os.listdir(d))
                   if f.endswith(ext)]
    return out


OUTDIR_RX = re.compile(r'<!--\s*SPLIT-OUTDIR:\s*(.+?)\s*-->')


def outdir_marker(hub_abs):
    """허브에 기록된 조각 폴더명(없으면 None). `split_doc.hub_outdir` 와 같은 규칙이다."""
    if not os.path.exists(hub_abs):
        return None
    try:
        with io.open(hub_abs, encoding='utf-8') as fh:
            m = OUTDIR_RX.search(fh.read())
    except (IOError, OSError, UnicodeDecodeError):
        return None
    return m.group(1) if m else None


def kinds_from_registry():
    """문서 유형을 **원장 §0 등재표**에서 읽는다(정본 공유).

    🔴🔴 [O106 4차 자기시정] 첫 판본은 유형을 몰라서 **모든 문서의 여유를 `max` 로** 쟀다.
      그런데 `doc_type_gate` 는 **append형은 꼬리만** 본다(비꼬리 조각은 불변이 정상이므로).
      ⇒ `01_세션이력`(비꼬리 조각 38,225B · 꼬리 27,649B)이 여기서는 🟠, 저기서는 통과였다.
      🔴 이것이 `R3-9` 가 경고한 **「게이트끼리 판정 기준이 어긋난 지점」**이고
        O83-H 에서 실제로 결함 2건을 낸 유형이다 ⇒ **정본을 공유해 축을 맞춘다.**
    🔴🔴 [O106 5차 자기시정] 첫 판본은 실패를 `except Exception: return {}` 로 **조용히 삼켰다.**
      그 결과 유형 조회가 실패한 실행에서 **전 문서가 「갱신형」으로 표시**되고
      `01_세션이력`(append형)이 🟠 로 오탐됐다 — 그런데 **import 경로로 부르면 정상**이라
      「같은 함수가 다른 값을 낸다」는 현상으로만 보였다.
      🔴 **조용한 실패는 이 워크스페이스가 반복해 당한 유형**이다(`P106` 「게이트가 침묵」).
      ⇒ 실패하면 **stderr 에 경고를 내고** 표에도 `유형?` 로 표시한다.
    """
    try:
        from doc_type_gate import parse_registry, index_logical
        reg = parse_registry(index_logical())
        out = {os.path.splitext(os.path.basename(k))[0]: v[0]
               for k, v in reg.items()}
        if not out:
            sys.stderr.write('🟠 유형 등재표가 비었다 — 유형 판정을 신뢰하지 마라\n')
        return out
    except Exception as e:
        sys.stderr.write('🔴 유형 등재표 로드 실패(%s: %s) — 유형·여유 판정이 무효다\n'
                         % (type(e).__name__, e))
        return {}


def census():
    """실측 인벤토리. 반환 = {'families': [...], 'singles': [...]}"""
    kinds = kinds_from_registry()
    fams = []
    for hub_rel, where in FAMILIES:
        hub = os.path.join(ROOT, hub_rel)
        if not os.path.exists(hub):
            continue
        chunks = chunk_paths(hub_rel, where)
        allp = [hub] + chunks
        sizes = [nbytes_of(p) for p in allp]
        chars = sum(len(read_text(p)) for p in allp)
        mx = max(sizes) if sizes else 0
        stem = os.path.splitext(os.path.basename(hub_rel))[0]
        kind = kinds.get(stem, '갱신형')
        # append형은 **꼬리만** 자란다 ⇒ 감시 대상도 꼬리다(`doc_type_gate` 와 동일 축).
        watch_b = nbytes_of(chunks[-1]) if (kind == 'append형' and chunks) else mx
        fams.append({
            'hub': hub_rel,
            'stem': stem,
            'kind': kind,
            'where': where,
            'chunks': len(chunks),
            'files': len(allp),
            'bytes': sum(sizes),
            'chars': chars,
            'max_bytes': mx,
            'watch': watch_b,
            'free': MAX_BYTES - watch_b,
            'tight': (kind != '정적') and (MAX_BYTES - watch_b) < MAX_BYTES * MIN_FREE,
        })
    sing = []
    for rel in SINGLES:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        b = nbytes_of(p)
        stem = os.path.splitext(os.path.basename(rel))[0]
        kind = kinds.get(stem, '갱신형')
        sing.append({
            'path': rel,
            'stem': stem,
            'kind': kind,
            'bytes': b,
            'chars': len(read_text(p)),
            'free': MAX_BYTES - b,
            'tight': (kind != '정적') and (MAX_BYTES - b) < MAX_BYTES * MIN_FREE,
        })
    return {'families': fams, 'singles': sing}


def family_files_text(hub_rel, where):
    """허브+조각 전체 텍스트(대조 소스가 분할돼 있을 때 쓴다)."""
    hub = os.path.join(ROOT, hub_rel)
    parts = [(hub, read_text(hub))]
    for c in chunk_paths(hub_rel, where):
        parts.append((c, read_text(c)))
    return parts


def attribute(line, hits, carry, carry_age, pos, actual):
    """수치 위치 `pos` 를 어느 문서에 귀속할지 판정. 불가면 None."""
    window = line[max(0, pos - NEAR):pos]
    near = [(window.rfind(s), s) for s in actual if s in window]
    if near:
        return max(near)[1]
    if len(hits) == 1 and len(line) <= SHORT_LINE:
        return hits[0]
    # 🔴🔴 [2026-08-28 O108] **이월 귀속에도 줄 길이 가드가 필요하다**(인수 `99_NEXT §0-MMM ▣QQQ ⑥㉠`).
    #   O106 이 「같은 줄 문서명 1개」 폴백에만 `SHORT_LINE` 을 걸었고 **carry 축에는 걸지 않았다**
    #   ⇒ 원장 §1 에 문서명을 언급한 행을 넣자, **뒤따르는 1,458~1,911자 행의 무관한 수치**가
    #     그 문서의 「조각 수 기재」로 오인돼 stale 3건이 떴다(내가 적은 조각 수는 **0건**).
    #   🔴 O107 은 이것을 **표기를 바꿔 회피**했고 규칙은 그대로 남겼다 — 그래서 재발했다.
    #   ⇒ 설계 원칙(`SHORT_LINE` 주석)이 이미 「**긴 행은 근접 귀속만 허용한다**」이므로
    #     carry 도 같은 가드를 받는다. 긴 행의 수치를 **직전 행의 문서**에 귀속하는 것은 추측이다.
    if not hits and carry_age <= 2 and len(line) <= SHORT_LINE:
        return carry
    return None


def scan_text(text, actual, relname='SYNTH.md', sizes=None, split=None):
    """한 파일 텍스트에서 stale 후보를 찾는다(순수 함수 · 테스트 대상).

    `actual` = {stem: 조각수} · `sizes` = {stem: 바이트} · `split` = {stem: 분할됨(bool)}

    🔴 [O106 자기시정 6회] 이 함수는 **재현율·정밀도·분모**를 동시에 만족해야 한다.
      · 재현율: 첫 판본은 「같은 줄 문서명 1개」만 봐서 **17건 중 13건**만 잡았다(`P106`).
      · 정밀도: 분모를 넓히자 원장 §1 긴 행(최대 **1,644자**)에서 **오탐 2건**이 났다
        (`7→8조각` · `7조각 중 2개만` = **과거 기록**).
      · 분모: **조각 수만** 보고 「stale 0」이라 보고했는데 등재표의 **바이트·`미분할` 표기**가
        검사 밖이라 **3건이 남아 있었다**(그중 1건은 O106 자신이 만든 stale).
      ⇒ `HISTORY` 제외 + **근접 귀속** + **바이트·분할여부 축**을 함께 둔다.
    """
    sizes = sizes or {}
    split = split or {}
    found = []
    carry, carry_age = None, 99
    for i, line in enumerate(text.split('\n'), 1):
        hits = sorted([s for s in actual if s in line], key=len, reverse=True)
        if hits:
            carry, carry_age = hits[0], 0
        else:
            carry_age += 1

        def add(axis, stem, written, got):
            found.append({'file': relname, 'line': i, 'doc': stem, 'axis': axis,
                          'written': written, 'actual': got,
                          'text': line.strip()[:110]})

        # ── 축 A: 조각 수 ────────────────────────────────────────────────
        if any(t in line for t in CTX) and not HISTORY.search(line):
            for rx in PATS:
                for m in rx.finditer(line):
                    stem = attribute(line, hits, carry, carry_age, m.start(), actual)
                    if stem and int(m.group(1)) != actual[stem]:
                        add('조각수', stem, int(m.group(1)), actual[stem])

        # ── 축 B: 바이트 ────────────────────────────────────────────────
        if sizes and not BYTE_HISTORY.search(line):
            row = row_key_stem(line, sizes)
            for rx in BYTE_PATS:
                for m in rx.finditer(line):
                    if BYTE_TARGET.search(line[max(0, m.start() - 12):m.start()]):
                        continue           # 목표·상한 표기 ⇒ 현재 크기 주장이 아니다
                    stem = row or attribute(line, hits, carry, carry_age,
                                            m.start(), sizes)
                    if stem is None or stem not in sizes:
                        continue
                    got = int(m.group(1).replace(',', ''))
                    if got != sizes[stem]:
                        add('바이트', stem, got, sizes[stem])

        # ── 축 C: `미분할` 표기 ─────────────────────────────────────────
        #   🔴 이 축은 **표 행의 첫 셀로만** 귀속한다 — 근접/이월 귀속은 오탐 5건을 냈다.
        if split:
            m = UNSPLIT.search(line)
            if m:
                stem = row_key_stem(line, split)
                if stem is not None and split.get(stem):
                    add('미분할표기', stem, 0, 1)

    # 🔴 [O106] **중복 제거는 이 함수 안에서** 한다 — `PATS` 두 정규식이 같은 자리를
    #   물어 같은 항목이 2번 나왔다(`test_doc_census.py` 가 적발).
    seen, out = set(), []
    for f in found:
        k = (f['line'], f['doc'], f['axis'], f['written'])
        if k not in seen:
            seen.add(k)
            out.append(f)
    return out


def stale_check(inv):
    """문서에 적힌 조각 수·바이트·`미분할` 표기 ↔ 실측 대조."""
    actual, sizes, split = {}, {}, {}
    for f in inv['families']:
        keys = [f['stem']] + ([f['where'].rstrip('/')] if f['where'] != 'sibling' else [])
        for k in keys:
            actual[k] = f['chunks']
            split[k] = f['chunks'] > 0          # 분할된 문서에 「미분할」은 stale 이다
    for s in inv['singles']:
        sizes[s['stem']] = s['bytes']
        split[s['stem']] = False

    found = []
    for src in COUNT_SOURCES:
        p = os.path.join(ROOT, src)
        if not os.path.exists(p):
            continue
        # 대조 소스 자신이 분할돼 있으면 조각까지 본다
        where = dict(FAMILIES).get(src)
        files = family_files_text(src, where) if where else [(p, read_text(p))]
        for fp, text in files:
            found.extend(scan_text(text, actual, os.path.relpath(fp, ROOT),
                                   sizes=sizes, split=split))
    seen, out = set(), []
    for f in found:
        k = (f['file'], f['line'], f['doc'], f['axis'], f['written'])
        if k not in seen:
            seen.add(k)
            out.append(f)
    return out


def read_budget(inv):
    """세션 시작 필수 독해량 실측 + 「전량 독해 규약대로면」 비교값."""
    must = []
    for rel in SESSION_START:
        p = os.path.join(ROOT, rel)
        if os.path.exists(p):
            must.append((rel, nbytes_of(p), len(read_text(p))))
    tot_b = sum(x[1] for x in must)
    tot_c = sum(x[2] for x in must)
    everything = sum(f['chars'] for f in inv['families']) + \
        sum(s['chars'] for s in inv['singles'])
    return {'must': must, 'bytes': tot_b, 'chars': tot_c, 'all_chars': everything}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--strict', action='store_true', help='stale 1건이라도 있으면 exit 1')
    ap.add_argument('--json', action='store_true', help='기계 판독 출력')
    ap.add_argument('--read-budget', action='store_true', help='독해 예산만 출력')
    a = ap.parse_args()

    inv = census()
    stale = stale_check(inv)
    budget = read_budget(inv)

    if a.json:
        print(json.dumps({'inventory': inv, 'stale': stale, 'budget': budget},
                         ensure_ascii=False, indent=2))
        return 1 if (a.strict and stale) else 0

    if a.read_budget:
        print('[세션 시작 독해 예산]')
        for rel, b, c in budget['must']:
            print('  %-46s %9s B  %8s 자' % (rel, format(b, ','), format(c, ',')))
        print('  %-46s %9s B  %8s 자' % ('계', format(budget['bytes'], ','),
                                        format(budget['chars'], ',')))
        print('  참고: 전 문서군 합계 = %s 자' % format(budget['all_chars'], ','))
        return 0

    print('[문서 인벤토리] 실측 %d분할문서 · %d미분할문서' %
          (len(inv['families']), len(inv['singles'])))
    print('  %-38s %-8s %5s %5s %10s %9s %9s' %
          ('문서', '유형', '조각', '파일', '총 바이트', '감시 B', '여유 B'))
    for f in inv['families']:
        mark = '  🟠' if f['tight'] else ''
        tail = ' ←꼬리' if f['kind'] == 'append형' else ''
        print('  %-38s %-8s %5d %5d %10s %9s %9s%s%s' % (
            f['stem'], f['kind'], f['chunks'], f['files'], format(f['bytes'], ','),
            format(f['watch'], ','), format(f['free'], ','), mark, tail))
    for s in inv['singles']:
        print('  %-38s %-8s %5s %5d %10s %9s %9s%s' % (
            s['stem'], s['kind'], '—', 1, format(s['bytes'], ','),
            format(s['bytes'], ','), format(s['free'], ','),
            '  🟠' if s['tight'] else ''))
    tight = [f['stem'] for f in inv['families'] + inv['singles'] if f['tight']]
    print('  🟠 여유 부족 %d건%s' % (len(tight),
                                (' = ' + ', '.join(tight)) if tight else ''))

    print('')
    print('[세션 시작 독해 예산] %s 자 / %s B  (전 문서군 %s 자)' %
          (format(budget['chars'], ','), format(budget['bytes'], ','),
           format(budget['all_chars'], ',')))
    for rel, b, c in budget['must']:
        print('   · %-44s %8s 자' % (rel, format(c, ',')))

    print('')
    print('[stale 대조] 문서 기재 ↔ 실측 (축 = 조각수 · 바이트 · 미분할표기) : 불일치 %d건'
          % len(stale))
    for s in stale:
        if s['axis'] == '미분할표기':
            print('  🔴 %s:%d  [%s] %s — 「미분할」이라 적혀 있지만 **분할돼 있다**'
                  % (s['file'], s['line'], s['axis'], s['doc']))
        else:
            print('  🔴 %s:%d  [%s] %s 기재 %s ↔ 실측 %s'
                  % (s['file'], s['line'], s['axis'], s['doc'],
                     format(s['written'], ','), format(s['actual'], ',')))
        print('      %s' % s['text'])

    print('')
    if stale:
        print('🔴 stale %d건 — 숫자를 지우고 `doc_census.py` 포인터로 바꿔라' % len(stale))
        print('   (`scripts/fix_stale_counts.py --apply` 가 자동 처리한다)')
        return 1 if a.strict else 0
    print('✅ stale 0건 — 문서에 적힌 조각 수가 실측과 일치한다')
    return 0


if __name__ == '__main__':
    sys.exit(main())

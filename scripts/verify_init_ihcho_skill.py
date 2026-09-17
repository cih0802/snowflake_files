#!/usr/bin/env python3
"""`init_ihcho` 스킬 검증기 — 산출물이 정본과 같고, 형식 불변식을 지키는가.

본문 정본 = `00_guides/03_init_ihcho_스킬_본문.md`(마커 사이) · 명세 = `…_스킬_정본.md`
산출물 = `.snowflake/cortex/skills/init_ihcho/SKILL.md`.

🔴 **판정은 종료코드다**(`R0-8-2`) — 출력 문구가 아니라 `rc` 를 보라. 위반 1건이라도 있으면 `rc=1`.

불변식 (정본 §4 와 1:1)
  I1 본문 정본 ↔ `SKILL.md` **바이트 동일**          — 어긋나면 정본이 정본이 아니다
  I2 frontmatter `name: init_ihcho` + `description`  — 없으면 스킬이 **발동하지 않는다**
  I3 본문 **500줄 이내**                              — 초과하면 앞 지시를 잃는다
  I4 한 줄 **2000자 이내**                            — `read` 절단 = 다음 세션이 못 읽는다(`R1-5-1`)
  I5 `R1-7-1`~`R1-7-10` **집합** 전건 등장            — 매 세션 노출 담보(개수 대조가 아니다)
  I6 `R3-9` 자문 축 `㉠`~`㉨` 전건 등장               — 게이트가 보지 않는 축
  I7 하드코딩 수치 금지 패턴 부재                     — 적으면 stale 이 된다(`R3-9 ㉦`)
  I8 참조 산출물 **전건** 정본과 바이트 동일 + 본문이 **그 경로를 가리킨다**
     — 🔴 지연 로드는 「본문에서 뺐다」가 아니라 「본문이 가리키는 곳으로 옮겼다」여야 한다.
       가리키지 않으면 그 내용은 **영구 미독**이 된다(뺀 것이 아니라 잃은 것이다).

사용 = `python3 scripts/verify_init_ihcho_skill.py [--verbose]`
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from build_init_ihcho_skill import ARTIFACTS, BODY_DOC, SKILL, SPEC, extract_body  # noqa: E402

SKILL_DIR_LOCAL = os.path.dirname(SKILL)   # 참조 경로를 스킬 폴더 기준 상대경로로 만든다
MAX_LINES = 500
MAX_CHARS = 2000
CLAUSES = tuple(f'R1-7-{i}' for i in range(1, 11))
AXES = tuple('㉠㉡㉢㉣㉤㉥㉦㉧㉨')

#: 🔴 하드코딩 수치 금지 — 이 표현이 본문에 있으면 다음 세션에 stale 이 된다.
#:   판정은 **표현 단위**다(숫자 자체를 금지하면 조문 번호·상한값까지 걸린다).
FORBIDDEN = (
    (re.compile(r'조각\s*\d+\s*개'), '조각 수를 박았다 — `doc_census.py` 로 재라'),
    (re.compile(r'게이트\s*\d+\s*종'), '게이트 개수를 박았다 — `session_brief.GATES` 가 정본이다'),
    (re.compile(r'음성 테스트\s*\d+\s*종'), '테스트 개수를 박았다 — 각 테스트가 스스로 센다'),
    (re.compile(r'\d[\d,]*\s*자\s*/\s*\d'), '문서 크기를 박았다 — `doc_census.py` 로 재라'),
    (re.compile(r'조문\s*\d+\s*개'), '조문 개수를 박았다 — `clause_order_gate.py` 가 정본이다'),
)


def main():
    ap = argparse.ArgumentParser(prog='verify_init_ihcho_skill.py')
    ap.add_argument('--verbose', action='store_true')
    a = ap.parse_args()

    fails, warns = [], []
    body = extract_body()
    if not os.path.isfile(SKILL):
        print(f'🔴 산출물 부재: {SKILL} — `build_init_ihcho_skill.py --apply` 를 먼저 돌려라.')
        return 1
    got = io.open(SKILL, encoding='utf-8').read()

    # I1 — 바이트 동일
    if got != body:
        # 🔴 어디가 다른지 좌표로 낸다(「다르다」만 말하면 고칠 수 없다).
        gl, bl = got.splitlines(), body.splitlines()
        first = next((i for i in range(max(len(gl), len(bl)))
                      if (gl[i] if i < len(gl) else None) != (bl[i] if i < len(bl) else None)), 0)
        fails.append(f'I1 정본 ↔ 산출물 불일치 — 첫 차이 {first + 1}행 '
                     f'(산출물 {len(gl)}줄/{len(got.encode())}B · 정본 {len(bl)}줄/{len(body.encode())}B). '
                     f'🔴 `build_init_ihcho_skill.py --apply` 로 재생성하라(스킬을 손으로 고치지 마라).')
    else:
        print(f'✅ I1 바이트 동일 — {len(body.splitlines())}줄 · {len(body.encode())} B')

    # I2 — frontmatter
    head = got.split('\n---\n', 2)
    if not got.startswith('---\n'):
        fails.append('I2 frontmatter 가 파일 첫 줄에서 시작하지 않는다')
    if not re.search(r'^name:\s*init_ihcho\s*$', got, re.M):
        fails.append('I2 `name: init_ihcho` 부재 — 스킬 발견이 이 필드에 의존한다')
    m = re.search(r'^description:\s*"(.*)"\s*$', got, re.M)
    if not m:
        fails.append('I2 `description` 부재 또는 따옴표 형식 아님 — 발동 기전이 사라진다')
    else:
        d = m.group(1)
        if len(d) < 40:
            fails.append(f'I2 description 이 너무 짧다({len(d)}자) — 과소발동한다')
        for t in ('세션 시작', 'init_ihcho', '초기화'):
            if t not in d:
                warns.append(f'I2 트리거 `{t}` 가 description 에 없다(과소발동 위험)')
        if not fails:
            print(f'✅ I2 frontmatter — name/description OK (description {len(d)}자)')

    # I3 — 줄 수
    n = len(got.splitlines())
    if n > MAX_LINES:
        fails.append(f'I3 본문 {n}줄 > 상한 {MAX_LINES} — 절을 정본 §1~§5 나 참조 문서로 옮겨라')
    else:
        print(f'✅ I3 줄 수 {n} ≤ {MAX_LINES}')

    # I4 — 줄 길이(문자 기준 · awk 바이트 오탐 금지)
    over = [(i, len(l)) for i, l in enumerate(got.split('\n'), 1) if len(l) > MAX_CHARS]
    if over:
        fails.append(f'I4 {MAX_CHARS}자 초과 {len(over)}줄 = {over[:5]}')
    else:
        print(f'✅ I4 한 줄 {MAX_CHARS}자 초과 0')

    # I5 — 조문 집합
    miss = [c for c in CLAUSES if c not in got]
    if miss:
        fails.append(f'I5 `R1-7` 조문 누락 {len(miss)}건 = {miss} '
                     f'— 매 세션 노출 담보 계약이 깨진다(집합 대조다)')
    else:
        print(f'✅ I5 `R1-7-1`~`R1-7-10` 전건 등장')

    # I6 — R3-9 축
    miss = [c for c in AXES if c not in got]
    if miss:
        fails.append(f'I6 `R3-9` 자문 축 누락 = {miss}')
    else:
        print('✅ I6 `R3-9` 축 ㉠~㉨ 전건 등장')

    # I7 — 하드코딩 수치
    hits = []
    for rx, why in FORBIDDEN:
        for i, l in enumerate(got.split('\n'), 1):
            if rx.search(l):
                hits.append((i, why, l.strip()[:90]))
    if hits:
        for i, why, snippet in hits[:10]:
            fails.append(f'I7 {i}행 {why} ▸ {snippet}')
    else:
        print('✅ I7 하드코딩 수치 0')

    # I8 — 참조 산출물 전건 대조 + 본문 포인터 실재
    refs = {a: c for a, c in ARTIFACTS.items() if a != SKILL}
    for art, canon in refs.items():
        rel = os.path.relpath(art, ROOT)
        want = extract_body(canon)
        if not os.path.isfile(art):
            fails.append(f'I8 참조 산출물 부재: {rel} — `build_init_ihcho_skill.py --apply` 를 돌려라')
            continue
        if io.open(art, encoding='utf-8').read() != want:
            fails.append(f'I8 {rel} 이 정본과 다르다 — 재생성하라(손으로 고치지 마라)')
            continue
        # 🔴 본문이 그 파일을 가리키는가(가리키지 않으면 영구 미독이다)
        needle = os.path.relpath(art, SKILL_DIR_LOCAL).replace(os.sep, '/')
        if needle not in got:
            fails.append(f'I8 본문이 `{needle}` 를 가리키지 않는다 — 지연 로드가 아니라 유실이다')
        else:
            print(f'✅ I8 {rel} 바이트 동일 + 본문 포인터 실재({want.count(chr(10))}줄)')

    print('-' * 74)
    for w in warns:
        print(f'  🟠 {w}')
    if fails:
        for f in fails:
            print(f'  🔴 {f}')
        print(f'🔴 FAIL — 위반 {len(fails)}건 (경고 {len(warns)}건)')
        return 1
    # 🔴 개수를 문면에 박지 마라 — 불변식이 늘면 stale 이 된다(O167 초판이 「7종」으로 굳었다).
    print(f'🟢 PASS — 불변식 전건 통과 (경고 {len(warns)}건)')
    print(f'   본문 정본 = {os.path.relpath(BODY_DOC, ROOT)}')
    print(f'   명세     = {os.path.relpath(SPEC, ROOT)}')
    print(f'   산출물   = {os.path.relpath(SKILL, ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

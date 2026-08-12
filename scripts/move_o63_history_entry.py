#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63-J — `01_세션이력.md` 의 O63 항목을 **군집 최신 자리**로 이동한다.

🔴 왜 필요한가: 이 파일은 전체가 오래된→새로운 순인데 **O59 군집 안에서는 최신 우선**으로 쌓인다
   (`O59-S` 1310 → `O59-R` 1403 → … → `O59-K` 1989 → `O59-J` 2016).
   O63 을 1989행에 넣으면 **군집 중간**이라, 최신을 찾는 독자는 군집 머리에서 `O59-S`(2026-08-11)를 보고
   그것을 최신으로 읽는다. 정확한 최신 자리는 `O58-D` 종료 직후 = `O59-S` 바로 위다.
⚠️ 이동만 한다. 본문은 한 글자도 바꾸지 않는다(내용 변경과 위치 변경을 섞으면 검증이 불가능해진다).
Co-authored with CoCo
"""
import io
import sys

HIST = '/workspace/20_issue/01_세션이력.md'
HEAD = '> #### 🟡 [2026-08-12 O63] `06_DDL.sql` 전량 독해'
ANCHOR = '> #### 🟡 [2026-08-11 O59-S] **자기감사'


def main():
    src = io.open(HIST, encoding='utf-8').read()
    if src.count(HEAD) != 1 or src.count(ANCHOR) != 1:
        print(f'🔴 앵커 개수 이상 — O63 {src.count(HEAD)} · O59-S {src.count(ANCHOR)}')
        sys.exit(1)

    start = src.index(HEAD)
    # O63 블록의 끝 = 다음 `> #### ` 항목 시작 직전
    nxt = src.find('\n> #### ', start + len(HEAD))
    if nxt < 0:
        print('🔴 O63 블록의 끝을 찾지 못했다')
        sys.exit(1)
    block = src[start:nxt + 1]          # 말미 개행 포함
    rest = src[:start] + src[nxt + 1:]

    if ANCHOR not in rest:
        print('🔴 제거 후 앵커 소실 — 중단')
        sys.exit(1)
    at = rest.index(ANCHOR)
    out = rest[:at] + block + rest[at:]

    if out.count(HEAD) != 1:
        print('🔴 이동 후 O63 블록이 1개가 아니다 — 중단')
        sys.exit(1)
    if len(out) != len(src):
        print(f'🔴 길이 변동 {len(src)} → {len(out)} — 이동이 아니라 편집이 됐다. 중단')
        sys.exit(1)
    io.open(HIST, 'w', encoding='utf-8').write(out)
    print(f'🟢 이동 완료 — O63 블록 {len(block)}자 · 길이 불변({len(out)}자) · O59-S 바로 위')


if __name__ == '__main__':
    main()

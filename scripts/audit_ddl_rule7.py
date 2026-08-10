#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
`06_DDL.sql` 테이블 COMMENT 의 **규칙7 위반 감사** (실측 수치 혼입 탐지).
Co-authored with CoCo

규칙7(작업지침 §2) = *"코드의 COMMENT 에는 실측 수치를 넣지 않고 코드값만 기록한다.
수치는 문서10과 이슈 원장에 기록한다."*
왜 규칙인가: COMMENT 에 박힌 수치는 **재적재·원천 증량과 함께 조용히 stale 이 된다.**
소비 계층(Cortex Analyst)은 COMMENT 를 프롬프트 context 로 읽으므로 stale 수치는 오답 경로가 된다.

경위 (O53 · 2026-08-10)
  `WIDE_AD_COMBINED` 문안을 06_DDL 에서 이관하던 중 **생성기 게이트가 5건을 잡아** 발견했다.
  전수 스캔 결과 위반이 15테이블에 분포한다. 원인 = O51-D 가 규칙7 을 **뷰 문안에만** 적용했고
  테이블 COMMENT 는 그보다 앞서 작성돼 미적용 상태였다.
  ⚠️ O53 이 신설한 4테이블 84컬럼은 위반 0(물리 확인). 기존분만 남았다.

⬜ 잔여 작업(별건): 아래 목록의 수치를 「규모는 이슈원장 §… 참조」 형태로 치환한다.
   O51-D-B 가 같은 작업의 선례다. **재구축(전체 DB 재생성) 전에 처리하는 것이 좋다** —
   06_DDL 이 replay 스크립트이므로 지금 고치지 않으면 새 환경에도 그대로 복제된다.
   ⚠️ 일괄 치환은 의미 손실 위험이 있어 **컬럼별 판단**이 필요하다(자동 삭제 금지).

사용법
  python3 scripts/audit_ddl_rule7.py            # 요약
  python3 scripts/audit_ddl_rule7.py --detail   # 위반 스니펫까지
"""
import io
import re
import sys

DDL = '/workspace/03_top-down_gold/06_DDL.sql'

# 위반 패턴 — 실측 수치의 3가지 표기
NUM = [('천단위', re.compile(r'[0-9]{1,3}(?:,[0-9]{3})+')),
       ('백분율', re.compile(r'[0-9]+(?:\.[0-9]+)?%')),
       ('배수',   re.compile(r'[0-9]+(?:\.[0-9]+)?배'))]
# 오탐 제외 — 코드값·지표번호·타입·날짜형식은 수치가 아니다(P114: 금칙어 게이트는 오탐한다)
WHITE = re.compile(r'#[0-9]+|(?:CM|MM|MS|PM|CONF|DEC|O|P|E|G|Q|AD|SVL|R)-?[0-9]+|'
                   r'[0-9]+0대|[0-9]+대|NUMBER\([0-9,]+\)|VARCHAR\([0-9]+\)|YYYYMM(?:DD)?|'
                   # 🔴 [O53 정정] 규약 상수는 실측 수치가 아니라 **정의**다 — 오탐이었다.
                   #   예: 「공#38 감액(건) = 금액÷10,000」 은 지표 정의이고 원천이 늘어도 변하지 않는다.
                   #   반면 「218,402행」·「89.7%」·「181.6배」는 재적재로 바뀌는 실측값이다(진짜 위반).
                   r'÷\s*[0-9,]+|[0-9,]+\s*(?:원|건)\s*단위|÷[0-9,]+')


def blocks():
    s = io.open(DDL, encoding='utf-8').read()
    for t in re.findall(r'CREATE OR REPLACE TABLE GN_DW\.GOLD\.(\w+) \(', s):
        i = s.index(f'CREATE OR REPLACE TABLE GN_DW.GOLD.{t} (')
        yield t, s[i:s.index(';', i)]


def main():
    detail = '--detail' in sys.argv
    total = parsed = 0
    per = {}
    for t, body in blocks():
        for line in body.split('\n'):
            m = re.match(r"\s+([A-Z0-9_]+)\s+\S+.*?COMMENT\s+'(.*)'\s*,?\s*(?:--.*)?$", line)
            if not m:
                continue
            parsed += 1
            col, cmt = m.group(1), m.group(2)
            clean = WHITE.sub('', cmt)
            hits = [(name, rx.search(clean).group(0)) for name, rx in NUM if rx.search(clean)]
            if hits:
                total += 1
                per.setdefault(t, []).append((col, hits))

    print(f'06_DDL.sql 테이블 COMMENT 규칙7 감사')
    print(f'  파싱 컬럼 {parsed} · 위반 {total} · 위반 테이블 {len(per)}')
    print(f'  ⚠️ 파싱 실패분(다중행 COMMENT 등)은 검사되지 않는다 — 이 값은 **하한**이다\n')
    for t in sorted(per, key=lambda k: -len(per[k])):
        print(f'  {t:<26} {len(per[t]):>2}건')
        if detail:
            for col, hits in per[t]:
                kinds = ', '.join(f'{k}:{v}' for k, v in hits)
                print(f'      · {col:<26} {kinds}')
    if not detail:
        print('\n  (--detail 로 위반 스니펫 확인)')


if __name__ == '__main__':
    main()

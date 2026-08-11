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

sys.path.insert(0, '/workspace/scripts')
from sv_unit_gate import NUM_EXEMPT          # noqa: E402  의미 예외를 1벌로 공유(O59-E)

DDL = '/workspace/03_top-down_gold/06_DDL.sql'
# 🔴 [2026-08-11 O59-N] **두 번째 표면 추가.** 이 게이트는 `06_DDL`(GOLD)만 봤고 **SILVER 정본 DDL 은
#   분모에 없었다** — 그래서 O59-N 에서 내가 SILVER COMMENT 에 실측 수치(`8/8`)를 넣었을 때
#   아무 게이트도 잡지 못했다(자기검토에서 손으로 발견). 규칙7 은 계층을 가리지 않는다.
#   ⚠️ SILVER 는 **기지 부채 13건**(선행 세션 유래)이 있어 0 을 요구하면 매번 실패한다 ⇒
#      `sv_unit_gate.CMT_BASELINE` 선례대로 **신규 유입만 실패**시킨다.
SILVER_DDL = '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'
SILVER_BASELINE = 13

# 위반 패턴 — 실측 수치의 표기
NUM = [('천단위', re.compile(r'[0-9]{1,3}(?:,[0-9]{3})+')),
       # 🔴 [2026-08-11 O59-L] **`100%` 는 제외한다** — 불변식 임계이지 실측치가 아니다
       #   (`채움 100%` · `비율이 100%를 넘는다`). `sv_unit_gate` 는 소수점을 요구해 이미 제외하고 있었는데
       #   이 게이트만 잡아 **같은 규칙을 두 게이트가 다르게 판정**했다 ⇒ P182 재발. 실측 오탐 3건.
       #   🔴 **부정선행만으로는 부족하다** — `(?!100…)` 는 `100%` 의 첫 자리만 막고 매치가 뒤로 밀려
       #     `00%` 로 잡힌다(실측). **선행 숫자·소수점 차단 `(?<![0-9.])` 을 함께** 걸어야 한다.
       ('백분율', re.compile(r'(?<![0-9.])(?!100(?:\.0+)?\s*%)[0-9]+(?:\.[0-9]+)?%')),
       ('배수',   re.compile(r'[0-9]+(?:\.[0-9]+)?배')),
       # 🔴🔴 [2026-08-11 O59-E 신설] **소규모 실측치** — 이 게이트도 `sv_unit_gate` 와 **같은 공백**이 있었다.
       #   천단위 구분이 없는 「366행」·「53건」은 위 3패턴을 전부 빠져나간다. 그래서 종전 「위반 37건」은
       #   **하한이었다**(실측 재검: 진짜 2건 추가 = **39건**).
       #   정본은 이것을 이름으로 금지한다 — `05_0` COMMENT 작성 규약 (1) · `04_SV_설계.md` §6.9-(8)
       #   = *"행수·합계·커버리지%·건수·금액·적재기간"*. 규모가 아니라 **성질**이 기준이다.
       #   🔴 선행 문자 차단 `(?<![\d,§#])` 필수 — 없으면 절 참조·지표번호 뒤 단위어가 붙어 잡힌다
       #     (실측 오탐: `'…(정본 §3 건·명)'` → `'3 건'`).
       ('소규모', re.compile(r'(?<![0-9,§#])[0-9]+\s*(?:행|건|명|원)\b'))]
# 오탐 제외 — 코드값·지표번호·타입·날짜형식은 수치가 아니다(P114: 금칙어 게이트는 오탐한다)
WHITE = re.compile(r'#[0-9]+|(?:CM|MM|MS|PM|CONF|DEC|O|P|E|G|Q|AD|SVL|R)-?[0-9]+|'
                   r'[0-9]+0대|[0-9]+대|NUMBER\([0-9,]+\)|VARCHAR\([0-9]+\)|YYYYMM(?:DD)?|'
                   # 🔴 [O53 정정] 규약 상수는 실측 수치가 아니라 **정의**다 — 오탐이었다.
                   #   예: 「공#38 감액(건) = 금액÷10,000」 은 지표 정의이고 원천이 늘어도 변하지 않는다.
                   #   반면 「218,402행」·「89.7%」·「181.6배」는 재적재로 바뀌는 실측값이다(진짜 위반).
                   r'÷\s*[0-9,]+|[0-9,]+\s*(?:원|건)\s*단위|÷[0-9,]+')

# 컬럼 선언 라인 — 커버리지 분모 산정용(O59-M)
COLDECL = re.compile(r'^\s{2,}([A-Z0-9_]+)\s+'
                     r'(?:NUMBER|VARCHAR|TEXT|DATE|TIMESTAMP|BOOLEAN|FLOAT|TIME)\S*')


def hits_for(cmt):
    """WHITE 로 오탐군을 제거한 뒤 위반 토큰을 찾는다. 소규모 패턴에는 의미 예외를 적용한다.

    🔴 [O59-E] 「N종」·grain 정의(`1행=1회원`)·논리 공집합(`0행`)은 적재량과 무관하므로
       `sv_unit_gate.NUM_EXEMPT` 를 그대로 재사용한다 — 두 게이트가 같은 규칙을 다르게 판정하면
       한쪽 지식이 다른 쪽에 전파되지 않는다(P62-B 가 실제로 이 게이트에서 발생했다).
    """
    clean = WHITE.sub('', cmt)
    spans = [(m.start(), m.end()) for pat, _ in NUM_EXEMPT for m in pat.finditer(clean)]
    out = []
    for name, rx in NUM:
        for m in rx.finditer(clean):
            # 🔴 [2026-08-11 O59-L] 종전에는 이 면제를 **`소규모` 패턴에만** 걸었다(O59-E 설계 결함).
            #   의미 예외는 **패턴이 아니라 문맥**에 속하므로 전 패턴에 적용해야 한다 —
            #   실측: 규약 상수 `감액금액/10,000` 이 `천단위` 로 잡혀 면제를 빠져나갔다.
            if any(a <= m.start() and m.end() <= b for a, b in spans):
                continue
            out.append((name, m.group(0)))
            break
    return out


def blocks(path=None, schema='GOLD'):
    """테이블 블록을 **다음 CREATE 문**까지로 끊는다.

    🔴 [2026-08-11 O59-M] 종전 경계는 `s.index(';', i)` 였다 — **COMMENT 문안 속 `;` 에 걸려
       블록이 조용히 잘렸다**(실측: `DIM_ORG` 2줄 · `DIM_MEMBER` 2줄만 검사됨).
       그래서 파싱 컬럼이 **579/619** 였고 누락 40컬럼 안에 진짜 위반 11건이 들어 있었다.
       ⇒ 「하한이다」라는 docstring 경고는 원인을 다중행 COMMENT 로 잘못 지목하고 있었다(실제 미파싱 0).
    """
    s = io.open(path or DDL, encoding='utf-8').read()
    starts = [(m.start(), m.group(1))
              for m in re.finditer(r'CREATE OR REPLACE TABLE GN_DW\.' + schema + r'\.(\w+) \(', s)]
    for k, (i, t) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(s)
        yield t, s[i:end]


def main():
    detail = '--detail' in sys.argv
    total = parsed = declared = 0
    per = {}
    for t, body in blocks():
        for line in body.split('\n'):
            if COLDECL.match(line):
                declared += 1
            m = re.match(r"\s+([A-Z0-9_]+)\s+\S+.*?COMMENT\s+'(.*)'\s*,?\s*(?:--.*)?$", line)
            if not m:
                continue
            parsed += 1
            col, cmt = m.group(1), m.group(2)
            hits = hits_for(cmt)
            if hits:
                total += 1
                per.setdefault(t, []).append((col, hits))

    print(f'06_DDL.sql 테이블 COMMENT 규칙7 감사')
    print(f'  선언 컬럼 {declared} · 파싱 컬럼 {parsed} · 위반 {total} · 위반 테이블 {len(per)}')
    # 🔴 [O59-M] 커버리지 자기판정 — 분모를 출력만 하지 않고 **불일치면 실패**시킨다(P106·P138).
    #   종전 게이트는 「하한이다」라는 문장으로 미검사분을 넘겼고, 그 안에 진짜 위반 11건이 있었다.
    if declared != parsed:
        print(f'  🔴 커버리지 미달 — 선언 {declared} ≠ 파싱 {parsed} (차 {declared - parsed}). '
              f'미파싱 컬럼이 검사되지 않았다.')
    else:
        print(f'  🟢 커버리지 {parsed}/{declared} — 전 컬럼 검사됨\n')
    for t in sorted(per, key=lambda k: -len(per[k])):
        print(f'  {t:<26} {len(per[t]):>2}건')
        if detail:
            for col, hits in per[t]:
                kinds = ', '.join(f'{k}:{v}' for k, v in hits)
                print(f'      · {col:<26} {kinds}')
    # ── 두 번째 표면: SILVER 정본 DDL (신규 유입만 실패) ──────────────────────
    s_tot = s_bad = 0
    s_hits = []
    for tb, body in blocks(SILVER_DDL, 'SILVER'):
        for line in body.split('\n'):
            m = re.match(r"\s+([A-Z0-9_]+)\s+\S+.*?COMMENT\s+'(.*)',?\s*(?:--.*)?$", line)
            if not m:
                continue
            s_tot += 1
            h = hits_for(m.group(2))
            if h:
                s_bad += 1
                s_hits.append((tb, m.group(1), h[0]))
    print(f'\n  SILVER 정본 DDL — 파싱 {s_tot} · 위반 {s_bad} (기지 부채 {SILVER_BASELINE})')
    if s_bad > SILVER_BASELINE:
        print(f'  🔴 신규 유입 {s_bad - SILVER_BASELINE}건 — 지우기 전에 수치를 문서10 으로 옮길 것(P107)')
        if detail:
            for x in s_hits:
                print(f'      · {x[0]}.{x[1]}  {x[2][0]}:{x[2][1]}')
        sys.exit(1)
    print('  🟢 신규 유입 0')
    if not detail:
        print('\n  (--detail 로 위반 스니펫 확인)')


if __name__ == '__main__':
    main()

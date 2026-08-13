#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-13 O66 신설] 문서 줄길이 게이트 — 정본이 `read` 툴 한도를 넘지 않는지 검사.

🔴 왜 게이트가 필요한가 (P227 자기적용 — 「복구」와 「재발 방지」는 다른 작업)
  `read` 툴은 **1줄 2,000자**를 넘기면 그 줄의 말미를 조용히 절단한다. 절단은
  에러가 아니라 **정상 응답으로 보이는 손실**이라 읽은 쪽이 알아채지 못한다
  (O66 착수 시점 실측 = `00_INDEX_이슈원장.md` 15줄 초과 · 최대 5,259자).
  ⇒ 정본을 읽었다고 믿으면서 실제로는 못 읽는 상태가 **여러 세션 지속**될 수 있다.
  O59-J 는 같은 증상을 파일 크기 축에서 한 번 겪었고(4,686줄/612KB) 그때도
  상설 검사기를 만들지 않아 O66 에서 **줄 길이 축으로 재발**했다.

검사 축 3종
  ① 줄 길이 — 2,000자 초과 = FAIL(blocking) · 1,000자 초과 = 관측(경고)
  ② 파일 규모 — `read` 1회 출력 한도(10만자) 초과 = 관측(분할 읽기 필요 신호)
  ③ 표 열수 정합 — 한 표의 모든 행이 헤더와 같은 열수인가
     (열수가 헤더보다 많으면 렌더러가 **마지막 열을 잘라 버린다** — O66 에서
      §2-B 「문서」 열 10행이 실제로 화면에서 사라져 있었다)

실행
  python3 scripts/doc_line_length_gate.py              # 정본 검사
  python3 scripts/doc_line_length_gate.py --all        # 워크스페이스 전 .md
  python3 scripts/doc_line_length_gate.py --self-check  # 게이트가 결함을 잡는지 검증
"""
import argparse
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HARD_LINE = 2000    # read 툴 1줄 한도 = blocking
WARN_LINE = 1000    # 관측 임계
READ_OUTPUT = 100000  # read 1회 출력 한도

# 정본 목록 — 지침 R1-3-6 과 같은 집합을 유지한다(이력 파일은 제외 대상이 아니라
# 「전량 독해 의무 예외」일 뿐이고, 줄길이 절단은 이력에서도 손실이므로 검사한다).
CANON = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '20_issue/00_INDEX_이슈원장.md',
    '20_issue/01_세션이력.md',
    '20_issue/02_상태상세_대시보드_갱신형.md',
    '20_issue/03_이슈상세.md',
    '20_issue/10_진단_원인분석.md',
    '20_issue/20_현업확인_요청.md',
    '20_issue/30_설계_의사결정.md',
    '20_issue/31_코드군_매핑등재부.md',
    '20_issue/40_입고대기_원천의존.md',
    '20_issue/50_dbt_파이프라인_미결조치.md',
    '20_issue/90_해소완료_로그.md',
    '99_NEXT_SESSION.md',
]

# ── [2026-08-13 O68 신설] 🔴🔴 **분모 공백 메움 — 이 게이트는 `.md` 만 보고 있었다.**
#   지침 `R1-5` 는 *"`.md`, `.sql`, `.yml`, `.py`, `.csv` 등 **생성·수정하는 모든 파일**"* 을
#   대상으로 규정하는데 O66 이 만든 이 게이트의 분모는 정본 `.md` **13종뿐**이었다.
#   🔴 그 결과 O67 이 실제로 어긴 표면(`05_*_SV_DDL*.sql` 6줄 · `agent_spec.yaml` 2줄)이
#      **애초에 검사되지 않았고**, 게이트는 통과한 채 위반이 배포됐다 —
#      `P202`(표면 자체의 누락) · `P224`(게이트를 볼 때는 그 게이트가 가진 축을 본다)의 재현이다.
#   🔴 그리고 O67-B 가 센 「초과 8줄」도 **하한**이었다: 전 워크스페이스 재측정으로
#      미편집 SV(`05_5`)에서 1줄이 더 나왔다(`P187` — 「N건」으로 끝내지 않는다).
#   ⚠️ 대상 선정 기준 = **우리가 저작·유지하는 발행 표면**이다. 자동 생성 산출물(`30_output_share/*.csv`)과
#      legacy·PoC 는 넣지 않는다 — 항상 빨간 게이트는 무력화된다(`P130`). 그 잔여는 원장에 등재한다.
CANON_CODE = [
    '05_SV-Agent_ai/05_0_SV_DDL.sql',
    '05_SV-Agent_ai/05_1_SV_DDL_MEMBER_MONTHLY.sql',
    '05_SV-Agent_ai/05_2_SV_DDL_MEMBER_EVENT.sql',
    '05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql',
    '05_SV-Agent_ai/05_4_SV_DDL_SERVICE.sql',
    '05_SV-Agent_ai/05_5_SV_DDL_EVENT_PARTICIPATION.sql',
    '05_SV-Agent_ai/05_6_SV_DDL_BUDGET.sql',
    '05_SV-Agent_ai/05_7_SV_DDL_AD.sql',
    '05_SV-Agent_ai/05_8_SV_DDL_DEV_ACHIEVEMENT.sql',
    '05_SV-Agent_ai/05_9_SV_DDL_MEMBER_FEE.sql',
    'cortex_project/agents/AGENT_MEMBER/agent_spec.yaml',
    'cortex_project/agents/AGENT_OVERALL/agent_spec.yaml',
    '03_top-down_gold/06_DDL.sql',
    '04_silver_design/08_SILVER_테이블DDL_20260714.sql',
    '10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
    '10_dbt_pipeline/models/gold/_gold_ready_schema.yml',
]

# ── [2026-08-13 O71-C] 🔴 분모 **일괄 확장** — `P229` 자기위반 청산(착수표 ③)
#   경위: O68 이 `P229`(분모 = 조문의 적용 범위)를 신설했으나 **자기가 저작한 `scripts/*.py`
#   4개와 골든 json 을 분모 밖에 뒀고**(§O68-B C1), O70 이 신설한 `o70_stale_scan.py` 도
#   같은 상태였다(§O70-B 구조1). O70-B 는 **부분 확장이 「통과 착시」를 만든다**고 판단해
#   1개만 넣지 않고 이 자리(착수표 ③)로 모았다 — 그 판단대로 **일괄로 닫는다.**
#
#   🔴 규약(신설): **우리가 저작·유지하는 파일은 만들 때 분모에 들어온다.**
#      개별 파일명을 손으로 추가하는 방식은 새 파일이 생길 때마다 빠지므로(3세션 연속 재현)
#      **glob 패턴**으로 선언한다 — 파일이 늘면 분모가 자동으로 따라온다.
#   ⚠️ 제외 기준은 그대로다(`P130` — 항상 빨간 게이트는 무력화된다):
#      자동 생성 산출물(`30_output_share/*.csv` 등) · `_archive` · `logs` · legacy·PoC.
#   🟢 착수 전 실측(2026-08-13): 확장 후보 **149파일 전부 2,000자 초과 0 · 1,000자 관측 0**
#      ⇒ 넓혀도 FAIL 이 나지 않는다(부분 확장이 아니라 일괄이므로 통과 착시가 아니다).
CANON_GLOB = [
    'scripts/*.py',                              # 게이트·생성기 (우리 저작)
    'scripts/golden/*.json',                     # 회귀 기준선
    'scripts/o51d_view_comments/*.py',
    '99_provided_definition/07_추가_지표사전_*.md',  # O71 신설 정본
    '10_dbt_pipeline/models/**/*.sql',            # dbt 모델
    '10_dbt_pipeline/models/**/*.yml',            # dbt 스키마·테스트
]


def expand_globs(patterns=None):
    """glob 패턴 → 정렬된 상대경로 목록. `_archive`·`logs`·`__pycache__` 는 제외한다."""
    import glob as _glob
    out = []
    for pat in (patterns if patterns is not None else CANON_GLOB):
        for p in _glob.glob(os.path.join(ROOT, pat), recursive=True):
            rel = os.path.relpath(p, ROOT)
            parts = rel.replace('\\', '/').split('/')
            if any(x in ('_archive', 'logs', '__pycache__', 'target') for x in parts):
                continue
            if os.path.isfile(p):
                out.append(rel)
    return sorted(set(out))


def read_lines(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read().split('\n')


def split_row(line):
    """표 행 → 셀 목록. `\\|` 이스케이프와 백틱 코드스팬 내부의 `|` 는 구분자가 아니다."""
    body = line.strip()
    if not (body.startswith('|') and body.endswith('|')):
        return None
    body = body[1:-1]
    cells, buf, i, in_code = [], [], 0, False
    while i < len(body):
        ch = body[i]
        if ch == '\\' and i + 1 < len(body):
            buf.append(body[i:i + 2])
            i += 2
            continue
        if ch == '`':
            in_code = not in_code
            buf.append(ch)
            i += 1
            continue
        if ch == '|' and not in_code:
            cells.append(''.join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    cells.append(''.join(buf))
    return cells


def is_separator(line):
    return set(line.replace('|', '').replace('-', '').replace(':', '').strip()) == set()


def check_file(path, rel):
    """(violations, warnings) 반환."""
    v, w = [], []
    lines = read_lines(path)
    total = sum(len(l) for l in lines)

    for n, l in enumerate(lines, 1):
        if len(l) > HARD_LINE:
            v.append('%s:%d 줄길이 %d자 > %d (read 툴이 말미를 절단한다)'
                     % (rel, n, len(l), HARD_LINE))
        elif len(l) > WARN_LINE:
            w.append('%s:%d 줄길이 %d자 (관측 임계 %d)' % (rel, n, len(l), WARN_LINE))

    if total > READ_OUTPUT:
        w.append('%s 총 %d자 > read 1회 출력 한도 %d ⇒ 분할 읽기 필요(R1-3-2)'
                 % (rel, total, READ_OUTPUT))
    if len(lines) > 2000:
        w.append('%s 총 %d줄 > read 1회 줄 한도 2,000 ⇒ 분할 읽기 필요' % (rel, len(lines)))

    # 🔴 [2026-08-13 O68] 표 열수 축은 **마크다운에만** 적용한다 — SQL·YAML 의 `|` 는
    #   표 구분자가 아니라 문법 요소(`||`·블록 스칼라)이므로 전량 오탐이 된다.
    if not rel.lower().endswith('.md'):
        return v, w

    hdr_n, hdr_line = None, 0
    for n, l in enumerate(lines, 1):
        cells = split_row(l)
        if cells is None:
            hdr_n = None
            continue
        if hdr_n is None:
            hdr_n, hdr_line = len(cells), n
            continue
        if is_separator(l):
            continue
        if len(cells) != hdr_n:
            note = '렌더러가 초과 열을 잘라 버린다' if len(cells) > hdr_n else '열이 밀려 값이 엉뚱한 열로 읽힌다'
            v.append('%s:%d 표 열수 %d ≠ 헤더(%d행) %d — %s'
                     % (rel, n, len(cells), hdr_line, hdr_n, note))
    return v, w


def run(paths, label):
    allv, allw, missing = [], [], []
    for rel in paths:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            missing.append(rel)
            continue
        v, w = check_file(p, rel)
        allv.extend(v)
        allw.extend(w)

    print('== 문서 줄길이 게이트 (%s · 대상 %d파일) ==' % (label, len(paths) - len(missing)))
    if missing:
        print('🔴 대상 파일 부재 %d건 (정본 목록과 실체가 어긋난다):' % len(missing))
        for m in missing:
            print('   -', m)
    print('위반(blocking) %d건 · 관측 %d건' % (len(allv), len(allw)))
    for x in allv:
        print('  🔴', x)
    for x in allw:
        print('  ⚠️', x)

    failed = bool(allv) or bool(missing)
    print('\n%s' % ('🔴 FAIL' if failed else '🟢 PASS — 2,000자 초과 0 · 표 열수 위반 0'))
    return 1 if failed else 0


def self_check():
    """게이트가 실제로 결함을 잡는지 검증한다(P106 — 대상이 존재하는 상태에서 실행)."""
    import tempfile
    cases = [
        ('줄길이 초과', '# t\n\n' + 'x' * 2500 + '\n', 1, 0),
        ('줄길이 관측', '# t\n\n' + 'x' * 1500 + '\n', 0, 1),
        ('표 열수 초과', '# t\n\n| a | b |\n|---|---|\n| 1 | 2 | 3 |\n', 1, 0),
        ('표 열수 부족', '# t\n\n| a | b | c |\n|---|---|---|\n| 1 | 2 |\n', 1, 0),
        ('백틱 코드스팬 파이프 오탐 없음', '# t\n\n| a | b |\n|---|---|\n| 1 | `x \\| y` |\n', 0, 0),
        ('이스케이프 파이프 오탐 없음', '# t\n\n| a | b |\n|---|---|\n| 1 | x \\| y |\n', 0, 0),
        ('정상', '# t\n\n| a | b |\n|---|---|\n| 1 | 2 |\n', 0, 0),
    ]
    ok = 0
    for name, body, exp_v, exp_w in cases:
        fd, p = tempfile.mkstemp(suffix='.md')
        os.close(fd)
        with io.open(p, 'w', encoding='utf-8') as fh:
            fh.write(body)
        v, w = check_file(p, 'tmp.md')   # 🔴 [O68] 표 열수 축은 `.md` 한정이므로 확장자를 넘긴다
        got = (len(v), len(w))
        good = got == (exp_v, exp_w)
        ok += 1 if good else 0
        print('%s %-32s 위반 %d/%d · 관측 %d/%d' %
              ('🟢' if good else '🔴', name, len(v), exp_v, len(w), exp_w))
        if not good:
            for x in v + w:
                print('      ', x)
        os.unlink(p)
    print('\n자기검사 %d/%d' % (ok, len(cases)))

    # ── [O71-C 신설] 분모 확장 축 — glob 이 조용히 0건이 되면 「통과」가 착시가 된다(`P106`).
    #   각 패턴이 최소 1건을 잡는지, 제외 규칙이 실제로 작동하는지 검사한다.
    gok, gtotal = 0, len(CANON_GLOB) + 2
    for pat in CANON_GLOB:
        hit = expand_globs([pat])
        good = len(hit) > 0
        gok += 1 if good else 0
        print('%s glob %-42s %d건' % ('🟢' if good else '🔴', pat, len(hit)))
    every = expand_globs()
    excluded = [r for r in every
                if any(x in ('_archive', 'logs', '__pycache__', 'target')
                       for x in r.replace('\\', '/').split('/'))]
    print('%s 제외 규칙(_archive·logs·__pycache__·target) 잔존 %d건(0이어야 한다)'
          % ('🟢' if not excluded else '🔴', len(excluded)))
    gok += 1 if not excluded else 0
    dup = len(CANON) + len(CANON_CODE) + len(every) - len(set(CANON + CANON_CODE + every))
    print('%s 정적 목록 ↔ glob 중복 %d건(중복은 무해하나 관측한다)' % ('🟢', dup))
    gok += 1
    print('분모 확장 자기검사 %d/%d · 총 대상 %d파일'
          % (gok, gtotal, len(set(CANON + CANON_CODE + every))))

    return 0 if (ok == len(cases) and gok == gtotal) else 1


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true', help='워크스페이스 전 .md 검사')
    ap.add_argument('--self-check', action='store_true')
    a = ap.parse_args()
    if a.self_check:
        sys.exit(self_check())
    if a.all:
        targets = []
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d not in ('_archive', 'logs', '.git', 'target')]
            for f in files:
                if f.endswith('.md'):
                    targets.append(os.path.relpath(os.path.join(base, f), ROOT))
        sys.exit(run(sorted(targets), '전 .md'))
    sys.exit(run(CANON + CANON_CODE + expand_globs(), '정본 + 코드 발행표면 + glob 확장'))

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
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HARD_LINE = 2000    # read 툴 1줄 한도 = blocking
WARN_LINE = 1000    # 관측 임계
# read 1회 출력 한도.
# 🔴 [2026-08-18 O82-C 실측 교정] 종전 100000 은 **가정치이고 과대**였다.
#   하강 스윕 실측(`20_issue/50_dbt_파이프라인_미결조치.md`):
#     · offset=566 limit=300 → 300줄 · 22,499자 · 37.6KB → 🟢 **1회 전량 반환**
#     · offset=1   limit=565 → 565줄 · 약 40,000자 · 71.6KB → 🔴 `Output too large`(꼬리 미리보기만)
#   ⇒ 하드 한도는 (37.6KB, 71.6KB] 구간이고 문자 기준 약 40,000자에서 걸렸다.
# ⚠️ 이 상수는 **크기 원인의 실패(형태 ㉢)만** 예측한다.
#   `edited out to manage context size`(형태 ㉠)는 **남은 컨텍스트** 문제라 크기와 무관하게 나며
#   이 상수로 막을 수 없다 — `R1-3-7` 의 호출별 도착 확인만이 잡는다.
READ_OUTPUT = 40000

# 🆕 [2026-08-18 O85 신설 · 착수표 ㉖] 파일 읽기 실패 격리 파라미터.
#   🔴 왜: 이 워크스페이스의 파일은 **스테이지 마운트**라 타 세션 쓰기·동기화 중에 읽으면
#     torn read(UTF-8 절단)·`OSError [Errno 5]`·중도 소멸이 난다. O84 에서 게이트가 그 때문에
#     **두 번 크래시**해 나머지 파일 전체의 판정을 잃었다.
#   재시도 3회 = `R1-7-3` 의 「2~3회 재읽어 대조」를 코드에 옮긴 값이다(사람 규율과 동일).
#   🔴 이 값을 바꾸면 `--self-check` 의 재시도 케이스 기대값도 함께 본다(`R1-6-17` 축).
READ_RETRIES = 3
READ_RETRY_DELAY = 0.4   # 초 · 스테이지 동기화가 끝날 여유

# 정본 목록 — 지침 R1-3-6 과 같은 집합을 유지한다(이력 파일은 제외 대상이 아니라
# 「전량 독해 의무 예외」일 뿐이고, 줄길이 절단은 이력에서도 손실이므로 검사한다).
CANON = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '00_guides/01_문서분할_규약.md',   # [O83-E] R1-6 무변경 이관 신설
    '00_guides/02_파일쓰기_안전규약.md',   # [O85] R1-7 무변경 이관 신설
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
    # ── 아래 3패턴은 [2026-08-18 O82-B] 재도출분이다 ────────────────────────
    # 🔴 경위: 2026-08-18 사용자가 이 파일에 **파일 단위 discard** 를 실행해
    #   분모가 **209파일 → 195파일**로 되돌아갔다(O76 이 넣은 확장분 소실).
    #   `head == live` 인 USER$ 워크스페이스라 redo 경로가 없어 복원이 불가능했다
    #   (`LIST head` 와 `LIST live` 의 md5 가 동일함을 실측 확인).
    # ⇒ O76 의 원문 패턴은 알 수 없으므로 **증거 기반 재도출**이다: 세션 시작 시점
    #   게이트 출력에 실제로 등장했던 파일군을 패턴으로 되살렸다. 따라서 파일 수가
    #   O76 의 209 와 정확히 일치하지 않을 수 있다(그 시점 이후 파일이 늘었다).
    # 🔴 교훈 = `C7` — 동시 편집 환경에서 discard 는 「내 변경 취소」가 아니라
    #   **그 파일의 미커밋 변경 전부 취소**이며 타 세션 작업까지 지운다.
    'cortex_project/agents/*/agent_spec.yaml',    # Agent 스펙 (P229 — 신설 2파일이 분모 밖이었다)
    '03_top-down_gold/*.sql',                     # GOLD DDL 정본
    '05_SV-Agent_ai/*.md',                        # SV·Agent 설계 정본군
    # ── [2026-08-18 O82-C] 조각 분할 산출물 ──────────────────────────────
    # 🔴 `split_doc.py` 가 정본을 허브 + `-001…-0NN` 조각으로 나누면 CANON 정적 목록은
    #   **허브만** 가리키므로 조각이 검사 밖으로 빠진다. 조각도 사람이 읽는 정본이고
    #   줄길이 절단은 조각에서도 손실이므로 glob 으로 자동 편입한다(R1-6-8 의 이 게이트판).
    '20_issue/*-[0-9][0-9][0-9].md',              # 20_issue 조각 (10·02·03·20·30·50 …)
    # 🔴 [2026-08-18 O83] 폴더 분할분(`split_doc.py --outdir`) — `01_세션이력/` 등.
    #   위 패턴은 `20_issue/` 직속만 잡아 폴더 조각이 분모 밖으로 빠진다.
    '20_issue/*/*-[0-9][0-9][0-9].md',            # 20_issue 폴더 조각 (01_세션이력 …)
    '99_NEXT_SESSION-[0-9][0-9][0-9].md',         # 인수인계 조각
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


class Unreadable(Exception):
    """파일 단위 읽기 실패 — 게이트 전체를 죽이지 않고 이 파일만 격리한다.

    🔴 [2026-08-18 O85 신설 · 착수표 ㉖] 종전에는 read 실패가 **게이트 전체를 크래시**시켰다.
       실측 사고 2형태(O84):
         ㉠ 스테이지 동기화 중 읽어 `UnicodeDecodeError`
            (9,742B 파일이 8,081B 만 도착 = torn read · `C5`·`R1-7-3` 과 같은 축)
         ㉡ 타 세션 in-flight 파일이 스캔 도중 사라져 `OSError [Errno 5]`
       ⇒ 둘 다 **파일의 결함이 아니라 관측 시점의 문제**인데 게이트가 죽어서
         **나머지 300여 파일의 판정을 함께 잃었다.** 그것이 이 예외의 존재 이유다.
    """

    def __init__(self, kind, detail):
        super().__init__(detail)
        self.kind = kind        # 'torn' | 'vanished' | 'io'
        self.detail = detail


def read_lines(path, retries=READ_RETRIES, delay=READ_RETRY_DELAY):
    """UTF-8 로 전량 읽는다. 일시적 실패는 재시도하고, 끝내 실패하면 `Unreadable` 로 격리한다.

    🔴 재시도가 정당한 이유 = `R1-7-3`(「손상」 판정 전에 2~3회 재읽어라).
       O82-B 는 torn read 를 **영구 손상으로 오판**해 사용자에게 불필요한 복원을 요청했다.
       게이트도 같은 오판을 하고 있었다 ⇒ 사람과 같은 규율을 코드에 넣는다.
    ⚠️ 재시도는 `R0-6`(같은 명령 재시도 금지)의 예외다 — 미반환·부분반환 복구는 재호출이 정답이다.
    """
    last = None
    for attempt in range(1, retries + 1):
        try:
            with io.open(path, encoding='utf-8') as fh:
                return fh.read().split('\n')
        except FileNotFoundError as e:
            # 스캔 중 사라진 파일 = 타 세션 in-flight 임시파일. 내용이 없으니 위반도 없다.
            raise Unreadable('vanished', '스캔 도중 사라졌다(타 세션 in-flight 추정): %s' % e)
        except UnicodeDecodeError as e:
            last = ('torn', 'UTF-8 절단 — 부분 반환/동기화 중 추정 (시도 %d/%d): %s'
                    % (attempt, retries, e))
        except OSError as e:
            # Errno 5(EIO) 등 — 스테이지 마운트의 일시 오류. 사라진 경우도 여기로 온다.
            if not os.path.exists(path):
                raise Unreadable('vanished', '스캔 도중 사라졌다(OSError 후 부재 확인): %s' % e)
            last = ('io', 'OSError — 스테이지 일시 오류 추정 (시도 %d/%d): %s'
                    % (attempt, retries, e))
        if attempt < retries:
            time.sleep(delay)
    raise Unreadable(last[0], last[1])


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
    unreadable, vanished = [], []
    for rel in paths:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            missing.append(rel)
            continue
        # 🆕 [O85 · ㉖] 파일 단위 격리 — 한 파일의 읽기 실패로 게이트 전체를 죽이지 않는다.
        try:
            v, w = check_file(p, rel)
        except Unreadable as e:
            if e.kind == 'vanished':
                # 사라진 파일은 위반의 담지자가 아니다 ⇒ 관측만 하고 통과시킨다.
                vanished.append((rel, e.detail))
            else:
                # torn/io = **판정 불가**다. 「위반 0」이라고 말할 수 없으므로 blocking 이다.
                unreadable.append((rel, e.kind, e.detail))
            continue
        allv.extend(v)
        allw.extend(w)

    scanned = len(paths) - len(missing) - len(unreadable) - len(vanished)
    print('== 문서 줄길이 게이트 (%s · 대상 %d파일 · 판독 %d파일) =='
          % (label, len(paths) - len(missing), scanned))
    if missing:
        print('🔴 대상 파일 부재 %d건 (정본 목록과 실체가 어긋난다):' % len(missing))
        for m in missing:
            print('   -', m)
    if vanished:
        print('⚪ 스캔 중 소멸 %d건 (타 세션 in-flight 추정 · 위반 판정 대상 아님):' % len(vanished))
        for rel, detail in vanished:
            print('   -', rel, '·', detail)
    if unreadable:
        print('🔴 판독 불가 %d건 (재시도 %d회 후에도 실패 ⇒ 이 파일들의 위반 여부는 **미판정**이다):'
              % (len(unreadable), READ_RETRIES))
        for rel, kind, detail in unreadable:
            print('   -', rel, '[%s]' % kind, detail)
        print('   🔴 처방: 타 세션 쓰기가 끝난 뒤 재실행한다. 2회 연속 같은 파일이면 실제 손상을'
              ' 의심하고 `_archive/` 스냅샷과 해시를 대조한다(`R1-7-3`).')
        print('   🔴 **「판독 불가」를 「위반 0」으로 보고하지 마라** — 그것이 이 축을 만든 이유다.')
    print('위반(blocking) %d건 · 관측 %d건' % (len(allv), len(allw)))
    for x in allv:
        print('  🔴', x)
    for x in allw:
        print('  ⚠️', x)

    failed = bool(allv) or bool(missing) or bool(unreadable)
    if failed:
        print('\n🔴 FAIL')
    else:
        print('\n🟢 PASS — 2,000자 초과 0 · 표 열수 위반 0 · 판독 불가 0 (판독 %d파일)' % scanned)
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

    iok, itotal = read_isolation_self_check()
    return 0 if (ok == len(cases) and gok == gtotal and iok == itotal) else 1


def read_isolation_self_check():
    """🆕 [O85 · ㉖] 읽기 실패 격리 축의 **음성 테스트**.

    🔴 `R3` 게이트 2 = *"새로 만든 게이트를 실패 케이스로 음성 테스트했는가?"*
       통과만 보면 그 게이트가 무엇을 못 잡는지 모른다. ⇒ 실패를 **인공적으로 만들어** 확인한다.
    검사 3축 = ① torn read 를 blocking 으로 잡는가 ② 소멸 파일을 통과시키는가
              ③ **격리가 실제로 되는가**(나쁜 파일 1개가 있어도 정상 파일이 판정되는가)
    """
    import tempfile
    print('\n== 읽기 실패 격리 자기검사 (O85 · ㉖) ==')
    ok, total = 0, 3
    tmpdir = tempfile.mkdtemp(prefix='o85_iso_')

    # ① torn read — 유효하지 않은 UTF-8 바이트열을 심는다
    torn = os.path.join(tmpdir, 'torn.md')
    with io.open(torn, 'wb') as fh:
        fh.write('# 정상 머리\n본문 '.encode('utf-8') + b'\xed\x95\x9c'[:2])   # 3바이트 한글의 2바이트만
    try:
        read_lines(torn, retries=1, delay=0)
        got1 = 'no-error'
    except Unreadable as e:
        got1 = e.kind
    good1 = got1 == 'torn'
    ok += 1 if good1 else 0
    print('%s ① torn read 검출 = %s (기대 torn)' % ('🟢' if good1 else '🔴', got1))

    # ② 소멸 — 존재하지 않는 경로
    try:
        read_lines(os.path.join(tmpdir, 'gone.md'), retries=1, delay=0)
        got2 = 'no-error'
    except Unreadable as e:
        got2 = e.kind
    good2 = got2 == 'vanished'
    ok += 1 if good2 else 0
    print('%s ② 소멸 검출 = %s (기대 vanished)' % ('🟢' if good2 else '🔴', got2))

    # ③ 격리 — torn 1개 + 위반 있는 정상 1개를 함께 돌려 **정상 파일이 판정되는지** 본다
    bad = os.path.join(tmpdir, 'bad.md')
    with io.open(bad, 'wb') as fh:
        fh.write(b'# x\n' + b'\xff\xfe\xfd')
    okfile = os.path.join(tmpdir, 'ok.md')
    with io.open(okfile, 'w', encoding='utf-8') as fh:
        fh.write('# t\n\n' + 'x' * 2500 + '\n')
    crashed, v_bad, v_ok = False, None, None
    try:
        v_bad = read_lines(bad, retries=1, delay=0)
    except Unreadable:
        v_bad = 'isolated'
    try:
        v_ok, _w = check_file(okfile, 'ok.md')
    except Exception:            # noqa: BLE001 — 어떤 예외든 격리 실패로 본다
        crashed = True
    good3 = (v_bad == 'isolated') and (not crashed) and bool(v_ok)
    ok += 1 if good3 else 0
    print('%s ③ 격리 = 나쁜 파일 %s · 정상 파일 위반 %s건 (기대 isolated / 1건 이상)'
          % ('🟢' if good3 else '🔴', v_bad, 0 if v_ok is None else len(v_ok)))

    for f in (torn, bad, okfile):
        if os.path.exists(f):
            os.unlink(f)
    os.rmdir(tmpdir)
    print('읽기 실패 격리 자기검사 %d/%d' % (ok, total))
    return ok, total


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

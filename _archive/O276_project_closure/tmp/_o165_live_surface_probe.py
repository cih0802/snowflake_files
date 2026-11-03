"""[O165 Phase 2] 축1 529건 중 「라이브가 읽는 표면」이 실제로 몇 건인가.

🔴 왜 = 절차서 `11_O누적작업_점검_재현_절차.md` §4-6 규칙 ㉠ 은
  *"버킷을 하나 더 나눈다 = ④ 라이브가 읽는 표면(SV·Agent COMMENT 소스) · 기준선 금지"*
라고 처방하고, 규칙 ㉡ 은 *"가르는 것은 파일의 **역할**이다"* 라고 적었다.
⇒ 그 처방대로 **파일 역할**(`05_SV-Agent_ai/*.sql`)로 가르면 몇 건이 잡히는가,
  그리고 그중 **실제로 라이브 COMMENT 절 안에 있는 것**은 몇 건인가를 따로 센다.

🔴 판정식 #15 = 「판정식이 세는 것」과 「사람이 읽는 뜻」이 같은지 보려면 **매치의 이웃**을 봐야 한다.
  여기서 이웃 = ㉠ 그 줄이 SQL 주석(`--`)인가 ㉡ `COMMENT` 절 안의 문자열 리터럴인가.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: 좌표는 `rename_stale_gate.py --list` 출력에서 읽는다(창작 0).
LIST_OUT = '/tmp/rsl.out'

FILE_RX = re.compile(r'^    (\S.*?) \((\d+)건\)\s*$')
HIT_RX = re.compile(r'^        :(\d+)\s+(\S+) → (\S+)\s*$')

#: 🔴 「라이브가 읽는 표면」의 정의 = SV/Agent DDL 의 **COMMENT 절 문자열 안**.
#:   파일 역할이 아니라 **줄의 위치**다. `--` 주석은 배포되지 않는다.
COMMENT_CLAUSE_RX = re.compile(r"\bCOMMENT\s*=?\s*'", re.I)


def classify_line(path, lineno):
    """그 줄이 ㉠ 줄주석 ㉡ 블록주석 ㉢ COMMENT 절 ㉣ 실행 SQL 중 무엇인가.

    🔴 [O165 자기시정] 초판은 `--` 만 봤다 ⇒ `/* … */` 블록주석 안의 줄을 `exec_sql` 로
      **오탐 1건**을 냈다(`05_3_SV_DDL_MEMBER_COHORT.sql:61` · 실물은 fan-out 설명 문단이다).
      ⇒ 판정식 #15 의 **2회차 실물**이다 — 「매치의 이웃」에 블록주석 상태가 포함된다.
    """
    try:
        lines = open(os.path.join(ROOT, path), encoding='utf-8').read().split('\n')
    except OSError:
        return 'unreadable'
    if lineno > len(lines):
        return 'oob'
    ln = lines[lineno - 1]
    stripped = ln.lstrip()
    if stripped.startswith('--'):
        return 'sql_comment'
    #   🔴 블록주석 안인가 = 파일 선두부터 `/*`·`*/` 를 세어 상태를 추적한다(줄주석 제외).
    depth = 0
    for prev in lines[:lineno - 1]:
        if prev.lstrip().startswith('--'):
            continue
        depth += prev.count('/*') - prev.count('*/')
    if depth > 0:
        return 'block_comment'
    if COMMENT_CLAUSE_RX.search(ln):
        return 'comment_clause_open'
    #   🔴 COMMENT 절은 여러 줄에 걸친다 ⇒ **위로 거슬러** 열린 리터럴 안인지 본다.
    #     판정 = 직전 40줄 안에서 마지막으로 나온 `COMMENT '` 이후 홑따옴표 개수가 홀수면 안이다.
    window = lines[max(0, lineno - 41):lineno - 1]
    text = '\n'.join(window)
    m = None
    for m2 in COMMENT_CLAUSE_RX.finditer(text):
        m = m2
    if m:
        after = text[m.end():]
        # 주석 줄은 리터럴 계산에서 제외한다(`--` 안의 홑따옴표는 문법이 아니다)
        body = '\n'.join(x for x in after.split('\n') if not x.lstrip().startswith('--'))
        if body.count("'") % 2 == 0:
            return 'comment_clause_body'
    return 'exec_sql'


def main():
    if not os.path.exists(LIST_OUT):
        print('🔴 %s 가 없다 — 먼저 `python3 scripts/rename_stale_gate.py --list > %s` 를 돌려라.'
              % (LIST_OUT, LIST_OUT))
        return 2
    cur = None
    hits = []
    for ln in open(LIST_OUT, encoding='utf-8'):
        m = FILE_RX.match(ln)
        if m:
            cur = m.group(1)
            continue
        m2 = HIT_RX.match(ln)
        if m2 and cur:
            hits.append((cur, int(m2.group(1)), m2.group(2), m2.group(3)))

    #   ⚠️ `--list` 는 파일당 6건까지만 열거하고 나머지는 「… 외 N건」이다
    #     ⇒ 이 표본은 **하한**이다. 그 사실을 출력에 박는다(`O111 ㉠`).
    print('[O165 Phase 2] 축1 위반 좌표 표본 = %d건 (🔴 `--list` 는 파일당 6건까지 · **하한**이다)' % len(hits))

    sv = [h for h in hits if re.match(r'05_SV-Agent_ai/05_.*\.sql$', h[0])]
    print('')
    print('① 파일 역할로 가른 「④ 버킷 후보」(§4-6 규칙 ㉠ 문면 그대로) = %d건' % len(sv))

    buckets = {}
    for path, lineno, old, new in sv:
        kind = classify_line(path, lineno)
        buckets.setdefault(kind, []).append((path, lineno, old, new))

    print('② 그 후보를 **줄 위치**로 재분류 (판정식 #15 = 매치의 이웃)')
    for kind in sorted(buckets):
        print('   %-20s %3d건' % (kind, len(buckets[kind])))
    live = buckets.get('comment_clause_open', []) + buckets.get('comment_clause_body', [])
    print('')
    print('③ 🔴 판정 = 라이브 COMMENT 절 안에 있는 것 = **%d건** / 후보 %d건'
          % (len(live), len(sv)))
    if live:
        for path, lineno, old, new in live:
            print('     🔴 %s:%d  %s → %s' % (path, lineno, old, new))
    print('')
    if len(sv) and not live:
        print('🟢 결론 = 파일 역할로 가른 %d건은 **전건 SQL 주석/실행문**이고 배포되지 않는다.' % len(sv))
        print('   ⇒ §4-6 규칙 ㉠ 을 **파일 역할**로 구현하면 오탐 %d건 · 진짜 0건이 된다.' % len(sv))
        print('   ⇒ 🟢 정정 판정식 = 라이브 표면은 **줄 위치(COMMENT 절)** 로 가른다.')
        print('     그 축은 이미 `sv_comment_object_gate`(라이브 조회 · 기준선 없음)가 담당한다')
        print('     ⇒ `rename_stale_gate` 에 ④ 버킷을 두면 **같은 것을 다르게 재는 지점**이 된다(`R3-9 ㉡`).')
        return 0
    print('🔴 라이브 COMMENT 절 안에 잔여가 있다 ⇒ ④ 버킷(기준선 금지 · 해소 요구)이 필요하다.')
    return 1


if __name__ == '__main__':
    sys.exit(main())

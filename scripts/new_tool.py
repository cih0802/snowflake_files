#!/usr/bin/env python3
"""새 도구 파일 생성 + `gate_census` 등재를 **한 동작**으로 수행한다 (O174 신설 · 구조 결정).

🔴🔴 **왜 이 도구가 있는가** = 「도구를 만들고 나중에 등재한다」가 이 워크스페이스에서
  반복 결함이었다(`O170` 4회 방치 · `O171` 라벨 오용 유발 · `O173` 임시 계측기 5개).
  🔴 경고로는 멈추지 않는다 — 미분류는 **세션 끝**에 발견되고, 그때 등재하면
  「남의 파일을 등재해 유령을 만드는」 다른 결함으로 바뀐다.
  🟢 **처방 = 지연 자체를 없앤다** — 이 도구는 등재에 실패하면 **파일을 만들지 않는다**(원자성).

사용법
    python3 scripts/new_tool.py --name <도구명> --bucket <분류> --axis "<한 줄 축 설명>"
    python3 scripts/new_tool.py --name <도구명> --bucket <분류> --axis "..." --promote-scratch

분류(`gate_census` 6종 중 하나 · 🔴 이 목록은 `gate_census.BUCKETS` 가 정본이다)
    JUDGE      판정 게이트(rc=0/1) — 종료코드가 판정이다
    OBSERVE    관측 전용 — 🔴 판정이 아니다(수치를 위반 건수로 인용 금지)
    NEEDS_ARGS 인자 필수 — 무인자 실행은 **rc=2**(사용법) 규약
    GEN        산출물 생성기
    MUTATES    🔴🔴 라이브 DDL/DML 또는 다중 파일 재작성 — 실행 금지(`R4-4-3` 승인 대상)
    LIB        라이브러리·헬퍼(단독 실행 대상 아님)

🟢 임시 계측기는 이 도구를 쓰지 않는다 — 파일명을 `_scratch_*.py` 로 지으면 등재가 면제된다.
   🔴 대신 `python3 scripts/gate_census.py --final` 이 **잔존을 FAIL** 로 잡는다(수명 강제).
   승격하려면 `--promote-scratch` 로 이 도구를 호출한다(`_scratch_x.py` → `x.py` + 등재).

종료코드 = 0 성공 · 1 실패(등재 불가·이름 충돌 등 · **파일 미생성**) · 2 사용법 오류.
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, 'scripts')
CENSUS = os.path.join(SCRIPTS, 'gate_census.py')
BUCKET_NAMES = ('JUDGE', 'OBSERVE', 'NEEDS_ARGS', 'GEN', 'MUTATES', 'LIB')
NAME_RX = re.compile(r'^[a-z0-9][a-z0-9_]{2,59}$')

SKELETON = '''#!/usr/bin/env python3
"""%(axis)s

🆕 [%(label)s 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `%(bucket)s`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
%(contract)s
"""
import sys


def main():
    print('TODO: %(name)s 구현')
    return 0


if __name__ == '__main__':
    sys.exit(main())
'''

CONTRACT = {
    'JUDGE': '🔴 종료코드가 판정이다 — 위반이면 1, 통과면 0. 🔴 음성 테스트를 같이 만든다(`R3-2`).',
    'OBSERVE': '🔴 판정이 아니다 — 이 출력의 수치를 위반 건수로 인용하지 마라.',
    'NEEDS_ARGS': '🔴 무인자 실행은 `print(__doc__); sys.exit(2)` 여야 한다(위반 1 과 구별).',
    'GEN': '🔴 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.',
    'MUTATES': '🔴🔴 실행 금지 — 라이브 DDL/DML 또는 다중 파일 재작성(`R4-4-3` 별도 승인).',
    'LIB': '🟢 단독 실행 대상이 아니다 — import 로만 쓴다.',
}


def register(name, bucket, axis):
    """`gate_census.py` 의 해당 dict 말미에 한 줄 등재한다. 실패하면 `False`."""
    src = io.open(CENSUS, encoding='utf-8', newline='').read()
    if ("'%s'" % name) in src:
        print('🔴 이미 등재돼 있다 — %s' % name)
        return False
    # 🔴 dict 리터럴의 **닫는 중괄호 직전**에 넣는다(`R1-7-8` 「말미에 덧붙인다」).
    m = re.search(r'^%s = \{$' % re.escape(bucket), src, re.M)
    if not m:
        print('🔴 분류 dict 를 찾지 못했다 — %s' % bucket)
        return False
    end = src.find('\n}\n', m.end())
    if end < 0:
        print('🔴 분류 dict 의 끝을 찾지 못했다 — %s' % bucket)
        return False
    row = "\n    '%s': '%s'," % (name, axis.replace("'", '’'))
    out = src[:end] + row + src[end:]
    io.open(CENSUS, 'w', encoding='utf-8', newline='').write(out)
    chk = io.open(CENSUS, encoding='utf-8', newline='').read()
    if ("'%s'" % name) not in chk:
        print('🔴 등재가 파일에 닿지 않았다 — 「썼다」와 「닿았다」는 다르다(O167)')
        return False
    return True


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('--name')
    ap.add_argument('--bucket', choices=BUCKET_NAMES)
    ap.add_argument('--axis')
    ap.add_argument('--promote-scratch', action='store_true')
    ap.add_argument('--label', default=os.environ.get('SESSION_LABEL', 'UNLABELED'))
    ap.add_argument('-h', '--help', action='store_true')
    try:
        a = ap.parse_args()
    except SystemExit:
        print(__doc__)
        return 2
    if a.help or not a.name or not a.bucket or not a.axis:
        print(__doc__)
        return 2
    if not NAME_RX.match(a.name):
        print('🔴 도구명 규약 위반(소문자·숫자·`_` · 3~60자) — %r' % a.name)
        return 1

    dst = os.path.join(SCRIPTS, a.name + '.py')
    src_scratch = os.path.join(SCRIPTS, '_scratch_' + a.name + '.py')
    if os.path.exists(dst):
        print('🔴 파일이 이미 있다 — %s (덮지 않는다 · `R1-7-1`)' % dst)
        return 1
    if a.promote_scratch and not os.path.exists(src_scratch):
        print('🔴 승격 원본이 없다 — %s' % src_scratch)
        return 1

    # 🔴🔴 원자성 = **등재를 먼저** 한다. 등재가 실패하면 파일을 만들지 않는다
    #   ⇒ 「파일은 있고 등재는 없는」 상태가 **구조적으로 생길 수 없다**.
    if not register(a.name, a.bucket, a.axis):
        print('🔴 등재 실패 ⇒ 파일을 만들지 않았다(원자성 유지)')
        return 1

    if a.promote_scratch:
        body = io.open(src_scratch, encoding='utf-8', newline='').read()
        io.open(dst, 'w', encoding='utf-8', newline='').write(body)
        os.remove(src_scratch)
        print('🟢 승격 = %s → %s (임시 원본 제거)' % (src_scratch, dst))
    else:
        io.open(dst, 'w', encoding='utf-8', newline='').write(
            SKELETON % {'axis': a.axis, 'label': a.label, 'bucket': a.bucket,
                        'name': a.name, 'contract': CONTRACT[a.bucket]})
        print('🟢 생성 = %s' % dst)

    print('🟢 등재 = gate_census.%s · 축 = %s' % (a.bucket, a.axis))
    print('   이어서: python3 scripts/gate_census.py   (미분류 0 확인)')
    if a.bucket == 'JUDGE':
        print('   🔴 `R3-2` = 새 게이트는 **음성 테스트**를 같이 만든다 — scripts/test_%s.py' % a.name)
    return 0


if __name__ == '__main__':
    sys.exit(main())

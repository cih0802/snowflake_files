#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# snapshot_util 의 CLI 진입점 — `python3 -c` 인라인 호출(R1-7-9 위험 경로)을 없앤다.
# Co-authored with CoCo
"""snapshot_cli.py — `_archive/` 스냅샷을 **셸에서** 만드는 진입점.

[2026-09-08 O145-B 신설 · 자기검토 `D7` 처방]

🔴 이 도구가 푸는 결함
--------------------------------------------------------------------------
`snapshot_util.py` 는 모듈 API 만 제공했다(`R1-7-10` = 스냅샷은 이 모듈만 경유).
그래서 스크립트를 새로 만들지 않고 한 파일만 스냅샷하려면 **인라인 python** 밖에
경로가 없었고, 실제로 O145 가 아래를 실행했다:

    python3 -c "import sys; sys.path.insert(0,'scripts'); from snapshot_util import snapshot; ..."

🔴 이것은 `R1-7-9`(백틱·`$`·`!` 를 포함한 본문은 셸을 경유시키지 않는다)가
   **경로 자체를 금지**한 형태다. 그 호출은 우연히 백틱이 없어 실해가 0 이었지만,
   조문은 결과가 아니라 경로를 금지한다 ⇒ **금지된 경로가 유일한 경로였던 것이
   도구 결손**이다.

🟢 처방 — 스냅샷을 셸에서 만들 때는 이 파일을 쓴다. 인라인 python 을 쓰지 않는다.

사용법
--------------------------------------------------------------------------
    python3 scripts/snapshot_cli.py <경로> --op rewrite --label O145-B
    python3 scripts/snapshot_cli.py a.md b.md --op prefix   # 여러 파일
    SESSION_LABEL=O145-B python3 scripts/snapshot_cli.py a.md --op rewrite

종료코드 = 0 전건 성공 · 1 한 건 이상 실패 · 2 인자 오류
🔴 종료코드를 파이프 뒤에서 읽지 마라(`R0-8-2`) — `>/tmp/x.out 2>&1` 후 `rc=$?`.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from snapshot_util import (  # noqa: E402
    SnapshotError,
    add_label_arg,
    snapshot,
)


def build_parser():
    ap = argparse.ArgumentParser(
        prog='snapshot_cli.py',
        description='_archive/ 스냅샷을 만든다 (snapshot_util 단일 경로 · R1-7-10).',
    )
    ap.add_argument('paths', nargs='+', help='스냅샷할 파일 경로(1개 이상)')
    ap.add_argument(
        '--op', required=True,
        help='연산명 — 스냅샷 이름에 들어간다(예: rewrite · prerebalance · prehub)')
    ap.add_argument(
        '--keep-ext', action='store_true',
        help='충돌 접미를 확장자 앞에 넣는다(산출물 회전용 · 기본은 뒤)')
    # 🆕 [2026-09-10 O154-B 신설 · `R1-7-10` 의 집행 보강]
    #   🔴 왜 필요한가 = 종전에는 CLI 가 **실 `_archive/` 로만** 쓸 수 있었고,
    #     그래서 `test_o145_tools.py` 가 실 보관소에 쓰고 지웠다. 스테이지 마운트는
    #     삭제된 이름을 **음성 캐시(유령 엔트리)로 남겨** 같은 이름 재생성을 거부한다
    #     ⇒ 그 테스트가 이 워크스페이스에서 **영구 rc=1** 이 됐다(O154 실측·규명).
    #   🟢 `snapshot_util.snapshot()` 은 처음부터 `archive=` 를 받았는데 **CLI 만 그것을
    #     노출하지 않았다** ⇒ 「금지된 경로가 유일한 경로였다」는 이 파일 머리말의 결함이
    #     다른 축에서 반복된 것이다. 이제 테스트·도구가 격리 보관소를 지정할 수 있다.
    ap.add_argument(
        '--archive', default=None,
        help='스냅샷 보관 디렉터리(기본 = `_archive/`). '
             '🔴 테스트는 반드시 임시 경로를 지정해 실 보관소를 오염시키지 않는다.')
    ap.add_argument(
        '--quiet', action='store_true', help='성공 메시지를 억제한다')
    add_label_arg(ap)
    return ap


def main(argv=None):
    ap = build_parser()
    args = ap.parse_args(argv)

    made = 0
    failed = []
    for path in args.paths:
        try:
            snap, status = snapshot(
                path, args.op, label=args.label,
                archive=args.archive,
                quiet=args.quiet, keep_ext=args.keep_ext)
        except SnapshotError as exc:
            failed.append((path, str(exc)))
            sys.stderr.write('🔴 %s — %s\n' % (path, exc))
            continue
        except OSError as exc:
            failed.append((path, str(exc)))
            sys.stderr.write('🔴 %s — %s\n' % (path, exc))
            continue
        made += 1
        if args.quiet:
            sys.stdout.write('%s\t%s\n' % (status, snap))

    total = len(args.paths)
    sys.stdout.write(
        '\n%s 스냅샷 %d/%d 성공 · 실패 %d\n'
        % ('🟢' if not failed else '🔴', made, total, len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# O145-B 신설 도구 2종(snapshot_cli · o145_transcript_audit)의 음성 테스트.
# Co-authored with CoCo
"""test_o145_tools.py — `R3-2` 음성 테스트.

🔴 **왜 음성 테스트인가** — 정상 입력만 넣으면 그 도구가 **무엇을 못 잡는지** 모른다.
   이 워크스페이스에서 도구를 만들 때 나온 자기시정은 **전부 음성 축이 잡았다**.

대상 도구
--------------------------------------------------------------------------
① `scripts/snapshot_cli.py`        — `snapshot_util` 의 CLI 진입점 (`D7` 처방)
② `scripts/o145_transcript_audit.py` — 트랜스크립트 감사 추출기 (`D4` 처방)

🔴 축 설계 원칙 = **실패해야 하는 입력을 넣고 실패하는지** 본다.
   `rc` 는 리다이렉트로 받는다(`R0-8-2` — 파이프 뒤 `$?` 는 남의 것이다).
"""

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SNAP_CLI = os.path.join(HERE, 'snapshot_cli.py')
AUDIT = os.path.join(HERE, 'o145_transcript_audit.py')

PASS = []
FAIL = []


def check(axis, cond, detail=''):
    (PASS if cond else FAIL).append(axis)
    mark = '🟢' if cond else '🔴'
    sys.stdout.write('  %s %s%s\n' % (mark, axis, (' — ' + detail) if detail else ''))


def run(argv, cwd=None, env=None):
    """도구를 돌리고 (rc, stdout+stderr) 를 돌려준다.

    🔴 파이프를 쓰지 않는다 — `rc` 를 그 프로세스에서 직접 받는다.
    """
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.Popen(
        [sys.executable] + argv, cwd=cwd or ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=e)
    out, _ = p.communicate()
    return p.returncode, out.decode('utf-8', 'replace')


# ---------------------------------------------------------------- snapshot_cli

def test_snapshot_cli():
    sys.stdout.write('\n[1] snapshot_cli.py — 음성 축\n')

    tmp = tempfile.mkdtemp(prefix='o145t_')
    try:
        src = os.path.join(tmp, 'doc.md')
        with io.open(src, 'w', encoding='utf-8') as fh:
            fh.write('내용 A\n')

        # 🆕 🔴🔴 [2026-09-10 O154-B 격리] 스냅샷 목적지를 **임시 보관소**로 돌린다.
        #   🔴 왜 = 종전 판본은 실 `_archive/` 에 쓰고 `os.remove` 로 지웠다. 스테이지 마운트는
        #     지운 이름을 **음성 캐시(유령 엔트리)로 남겨** 같은 이름 재생성을 거부하므로
        #     (`os.path.exists`·`os.listdir` 둘 다 부재인데 쓰기가 `ENOENT`), 이 테스트가
        #     한 번 돌고 나면 **그 뒤로 영구히 rc=1** 이 됐다(O154 실측·규명 · 착수표 `㊳` 동일 유형).
        #   🟢 지침 `R1-7-10` 이 이미 *"`archive=` 를 넘겨라 — 안 넘기면 테스트가 실 `_archive/` 를
        #     더럽힌다"* 라고 경고했고 `test_snapshot_util.py` 는 지켰는데 **이 테스트만 위반**이었다.
        #   ⇒ `snapshot_cli.py --archive` 를 O154-B 가 신설해 그 규약을 CLI 축에서도 지킬 수 있게 했다.
        arch = os.path.join(tmp, '_archive')
        os.makedirs(arch)
        ARCH = ['--archive', arch]

        # 축1 — --op 없이 호출하면 argparse 가 거부(exit 2)해야 한다.
        rc, out = run([SNAP_CLI, src])
        check('축1 --op 누락 거부', rc == 2, 'rc=%d' % rc)

        # 축2 — 인자 0개면 거부해야 한다.
        rc, out = run([SNAP_CLI])
        check('축2 경로 0개 거부', rc == 2, 'rc=%d' % rc)

        # 축3 — 존재하지 않는 파일은 실패(rc=1)하고 조용히 성공하지 않아야 한다.
        rc, out = run([SNAP_CLI, os.path.join(tmp, 'nope.md'), '--op', 'x'])
        check('축3 부재 파일 실패', rc == 1 and '🔴' in out, 'rc=%d' % rc)

        # 축4 — op 에 경로 구분자가 있으면 거부해야 한다(경로 탈출 방지).
        rc, out = run([SNAP_CLI, src, '--op', 'a/b'])
        check('축4 op 경로구분자 거부', rc == 1, 'rc=%d' % rc)

        # 축5 — 라벨 미지정이면 UNLABELED 경고가 나와야 한다(중단은 하지 않는다).
        env = dict(os.environ)
        env.pop('SESSION_LABEL', None)
        rc, out = run([SNAP_CLI, src, '--op', 'nolabel'] + ARCH,
                      env={'SESSION_LABEL': ''})
        check('축5 라벨 미지정 경고 + 성공',
              rc == 0 and 'UNLABELED' in out, 'rc=%d' % rc)

        # 축6 — 같은 내용 재실행은 reused(덮어쓰기 0). 🔴 이것이 R1-7-10 의 핵심이다.
        rc1, o1 = run([SNAP_CLI, src, '--op', 'dup', '--label', 'TESTX'] + ARCH)
        rc2, o2 = run([SNAP_CLI, src, '--op', 'dup', '--label', 'TESTX'] + ARCH)
        check('축6 동일내용 재실행 = reused',
              rc1 == 0 and rc2 == 0 and '재사용' in o2, 'rc=%d,%d' % (rc1, rc2))

        # 축7 — 내용이 바뀌면 기존 스냅샷을 덮지 않고 접미를 붙여야 한다.
        with io.open(src, 'w', encoding='utf-8') as fh:
            fh.write('내용 B (바뀜)\n')
        rc3, o3 = run([SNAP_CLI, src, '--op', 'dup', '--label', 'TESTX'] + ARCH)
        base = 'doc.md.TESTX-dup'
        kept = os.path.exists(os.path.join(arch, base))
        suffixed = os.path.exists(os.path.join(arch, base + '.2'))
        check('축7 내용변경 시 원본보존 + 접미 신설',
              rc3 == 0 and kept and suffixed and '접미' in o3,
              'kept=%s suffixed=%s' % (kept, suffixed))

        # 축8 — 부분 실패가 있으면 전체 rc 가 1 이어야 한다(성공 건이 섞여도).
        rc4, o4 = run([SNAP_CLI, src, os.path.join(tmp, 'ghost.md'),
                       '--op', 'mixed', '--label', 'TESTX'] + ARCH)
        check('축8 부분실패 시 rc=1',
              rc4 == 1 and '실패 1' in o4, 'rc=%d' % rc4)

        # 🆕 축8-B [O154-B] 격리 단정 — 실 `_archive/` 를 건드리지 않았는가.
        #   🔴 이 축이 없으면 「격리했다」가 자기신고로 남는다(O111 ㉠ 축).
        real = os.path.join(ROOT, '_archive')
        leaked = []
        if os.path.isdir(real):
            leaked = [n for n in os.listdir(real)
                      if n.startswith('doc.md.TESTX-')
                      or n.startswith('doc.md.UNLABELED-nolabel')]
        check('축8-B 실 _archive 오염 0', not leaked, '유출 %d건' % len(leaked))

        # 🔴 정리 = tmp 통째로 지운다(finally). 실 `_archive/` 에서 지울 것이 없다
        #   ⇒ 종전의 `os.remove(실_archive/...)` 루프를 **삭제**했다(그것이 유령을 만들었다).
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ------------------------------------------------------- o145_transcript_audit

def test_transcript_audit():
    sys.stdout.write('\n[2] o145_transcript_audit.py — 음성 축\n')

    tmp = tempfile.mkdtemp(prefix='o145a_')
    try:
        # 축9 — 인자 없이 호출하면 사용법 + exit 2 (게이트 아님을 명시).
        rc, out = run([AUDIT])
        check('축9 인자 없음 → 사용법 + rc=2',
              rc == 2 and '사용법' in out, 'rc=%d' % rc)

        # 축10 — 없는 파일은 조용히 0 을 내지 않아야 한다.
        #   🔴 단정 문자열은 도구의 실제 출력('파일 없음')과 일치시킨다 —
        #      초판이 '없다' 로 잡아 도구가 정상인데 축이 실패했다(내 선언이 틀린 사례).
        rc, out = run([AUDIT, os.path.join(tmp, 'none.json')])
        check('축10 부재 파일 → rc=2', rc == 2 and '파일 없음' in out,
              'rc=%d' % rc)

        # 축11 — 완전히 깨진 파일은 파싱 실패로 중단해야 한다.
        bad = os.path.join(tmp, 'bad.json')
        with io.open(bad, 'w', encoding='utf-8') as fh:
            fh.write('이건 JSON 이 아니다\n{{{ 깨짐\n')
        rc, out = run([AUDIT, bad])
        check('축11 파싱 불가 → rc=2', rc == 2, 'rc=%d' % rc)

        # 축12 🔴 핵심 — JSONL(줄마다 JSON)을 받아야 한다.
        #   초판은 단일 json.loads 만 써서 "Extra data" 로 죽었다(실사고).
        jsonl = os.path.join(tmp, 'tr.jsonl')
        rows = [
            {'name': 'snowflake_sql_execute',
             'input': {'sql': 'SELECT 1 FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO'}},
            {'name': 'bash', 'input': {'command': 'python3 scripts/line_len.py a.md'}},
            {'name': 'edit', 'input': {'file_path': '/workspace/a.md'}},
        ]
        with io.open(jsonl, 'w', encoding='utf-8') as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + '\n')
        rc, out = run([AUDIT, jsonl])
        ok = (rc == 0 and 'SQL 1' in out and 'GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO' in out)
        check('축12 JSONL 파싱 + 대상표 추출', ok, 'rc=%d' % rc)

        # 축13 — 단일 JSON 배열도 받아야 한다(형태 2종 호환).
        arr = os.path.join(tmp, 'tr_arr.json')
        with io.open(arr, 'w', encoding='utf-8') as fh:
            fh.write(json.dumps(rows, ensure_ascii=False))
        rc, out = run([AUDIT, arr])
        check('축13 JSON 배열도 파싱', rc == 0 and 'SQL 1' in out, 'rc=%d' % rc)

        # 축14 🔴 핵심 — 위험 신호를 실제로 검출해야 한다(오탐이 아니라 미탐 방어).
        risky = os.path.join(tmp, 'risky.jsonl')
        with io.open(risky, 'w', encoding='utf-8') as fh:
            for cmd in ('rm -rf /tmp/x',
                        'dbt build --project-dir /x',
                        "awk 'length($0)>2000' a.md",
                        'python3 -c "print(1)"'):
                fh.write(json.dumps({'name': 'bash', 'input': {'command': cmd}},
                                    ensure_ascii=False) + '\n')
        rc, out = run([AUDIT, risky])
        hits = [
            'rm -rf 사용: 발견' in out,
            'R4-1 위반): 발견' in out,
            'R1-5-4 금지): 발견' in out,
            'R1-7-9 위험): 발견' in out,
        ]
        check('축14 위험 신호 4종 전건 검출',
              rc == 0 and all(hits), '검출 %d/4' % sum(hits))

        # 축15 — 위험이 없으면 「발견」으로 오탐하지 않아야 한다.
        rc, out = run([AUDIT, jsonl])
        check('축15 무위험 입력 오탐 0',
              rc == 0 and '발견' not in out.split('위험 신호')[-1],
              'rc=%d' % rc)

        # 축16 — 빈 파일은 「0건」을 조용히 내지 말고 파싱 실패로 잡아야 한다.
        empty = os.path.join(tmp, 'empty.json')
        with io.open(empty, 'w', encoding='utf-8') as fh:
            fh.write('')
        rc, out = run([AUDIT, empty])
        check('축16 빈 파일 → rc=2', rc == 2, 'rc=%d' % rc)

        # ── 🆕 [2026-09-08 O144-F 신설] 축17·축18 ──────────────────────────
        # 🔴🔴 **왜 신설했나** — 위 축14 픽스처에 **quoted heredoc 과 파이프 뒤 rc 가
        #    아예 없었다.** 그래서 그 두 판정식의 결함이 **영구히 숨어 있었다**:
        #      ㉠ heredoc 검사가 리터럴 `<<'EOF'` 만 봐서 실제 사용 `<<'PYEOF'` **7건을 놓쳤다**
        #      ㉡ 파이프 뒤 rc 검사가 리다이렉트 뒤 `$?` 까지 잡아 **오탐 2건**을 냈다
        #    ⇒ 이것이 `D2`(픽스처가 신관례를 담지 않아 게이트가 조용히 분모를 잃는다)의 재발이다.
        #    🔴 **판정식** = 아래 두 축은 **시정 전 코드에서 반드시 실패**해야 한다.
        #       축17 은 구 코드가 「없음」을 내므로 실패하고, 축18 은 구 코드가 「발견」을 내므로 실패한다.

        # 축17 🔴 heredoc 재현율 — 구분자가 EOF 가 아니어도 잡아야 한다.
        hd = os.path.join(tmp, 'heredoc.jsonl')
        with io.open(hd, 'w', encoding='utf-8') as fh:
            fh.write(json.dumps(
                {'name': 'bash',
                 'input': {'command': "cat > /tmp/p.py <<'PYEOF'\nimport io\nPYEOF"}},
                ensure_ascii=False) + '\n')
        rc, out = run([AUDIT, hd])
        check('축17 quoted heredoc 구분자 임의명 검출(PYEOF)',
              rc == 0 and 'quoted heredoc 사용(R1-7-9 위험): 발견' in out,
              'rc=%d' % rc)

        # 축18 🔴 파이프 뒤 rc — **재현율과 정밀도를 한 축에서 함께** 단정한다.
        #   ㉠ 파이프로 끝난 뒤의 `$?` = 위반이므로 검출돼야 한다.
        #   ㉡ 리다이렉트로 받은 뒤의 `$?` = 정상이므로 검출되면 **오탐**이다.
        pipe_bad = os.path.join(tmp, 'pipe_bad.jsonl')
        with io.open(pipe_bad, 'w', encoding='utf-8') as fh:
            fh.write(json.dumps(
                {'name': 'bash',
                 'input': {'command': 'grep -n x a.md | head -6; echo "rc=$?"'}},
                ensure_ascii=False) + '\n')
        rc_bad, out_bad = run([AUDIT, pipe_bad])

        pipe_ok = os.path.join(tmp, 'pipe_ok.jsonl')
        with io.open(pipe_ok, 'w', encoding='utf-8') as fh:
            fh.write(json.dumps(
                {'name': 'bash',
                 'input': {'command': 'python3 x.py >/tmp/o.out 2>&1; echo "rc=$?"'}},
                ensure_ascii=False) + '\n')
        rc_ok, out_ok = run([AUDIT, pipe_ok])

        detected = 'R0-8-2 위반): 발견' in out_bad
        false_pos = 'R0-8-2 위반): 발견' in out_ok
        check('축18 파이프 뒤 rc = 재현율 O · 리다이렉트 오탐 X',
              rc_bad == 0 and rc_ok == 0 and detected and not false_pos,
              '검출=%s 오탐=%s' % (detected, false_pos))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    sys.stdout.write('=' * 62 + '\n')
    sys.stdout.write('test_o145_tools.py — O145-B 신설 도구 음성 테스트\n')
    sys.stdout.write('=' * 62 + '\n')

    test_snapshot_cli()
    test_transcript_audit()

    total = len(PASS) + len(FAIL)
    sys.stdout.write('\n' + '-' * 62 + '\n')
    sys.stdout.write('%s 축 %d개 · 통과 %d · 실패 %d\n'
                     % ('🟢' if not FAIL else '🔴', total, len(PASS), len(FAIL)))
    if FAIL:
        for axis in FAIL:
            sys.stdout.write('   🔴 %s\n' % axis)
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())

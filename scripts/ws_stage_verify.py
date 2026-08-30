#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
워크스페이스 스테이지 반영 대조 — **패딩 허용** (P102 실행 + P133 교정).
Co-authored with CoCo

🔴 왜 전용 스크립트인가
   `/workspace` 마운트의 `ls` 성공은 스테이지 반영을 뜻하지 않는다(OPS-3 · P99 — 실측으로 산출물 3종 유실).
   그래서 `cortex ws ls` 로 대조해야 하는데, **그 size 는 원본 바이트가 아니라 16바이트 블록 패딩값**이다(P133).
   로컬 `getsize` 와 등호 비교하면 **정상 파일도 전건 「불일치」**로 나온다 — 실제로 O53 에서 32/32 오판했다.
   ⇒ 판정식 = `stage == ceil(local/16)*16` 또는 `ceil((local+1)/16)*16`.
   ⚠️ 이 검사는 「반영됐는가」만 본다. 내용 동일성까지 보려면 다운로드 후 해시 대조가 필요하다.

사용법
   python3 scripts/ws_stage_verify.py <파일목록.txt>
   python3 scripts/ws_stage_verify.py --o53          # O53 세션 수정분 프리셋
"""
import math
import os
import re
import subprocess
import sys

WS = 'USER$.PUBLIC."snowflake_files"'
# 🔴 [2026-08-11 O59-E] **경로를 워크스페이스 루트에 고정한다.** 종전에는 `os.path.exists(f)` 가
#   상대 경로였고, `scripts/` 에서 실행하면 `scripts/scripts/...` 를 찾아 **전건 「로컬 부재」**가 됐다.
#   O53 실행이 통과한 것은 그때 CWD 가 우연히 `/workspace` 였기 때문이다(P85 계열: 통과가 신선함을 뜻하지 않는다).
ROOT = '/workspace'

O53_FILES = [
    '99_NEXT_SESSION.md',
    '20_issue/00_INDEX_이슈원장.md', '20_issue/40_입고대기_원천의존.md',
    '03_top-down_gold/06_DDL.sql', '03_top-down_gold/00_README.md',
    '03_top-down_gold/09_빅테이블 VIEW.md', '03_top-down_gold/05_필드 인벤토리.md',
    '03_top-down_gold/10_WIDE VIEW 코멘트.sql',
    '02_GN_DW_building/03_GOLD_SERVING.md',
    '05_SV-Agent_ai/04_SV_설계.md', '05_SV-Agent_ai/05_8_SV_DDL_DEV_ACHIEVEMENT.sql',
    '05_SV-Agent_ai/05_0_SV_DDL.sql',
    '10_dbt_pipeline/dbt_project.yml',
    '10_dbt_pipeline/models/gold/_gold_ready_schema.yml',
    '10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
    '10_dbt_pipeline/models/gold/wide/WIDE_AD_COMBINED.sql',
    '10_dbt_pipeline/models/gold/dim/DIM_MONTH.sql',
    '10_dbt_pipeline/models/gold/dim/DIM_MEMBER_CURRENT.sql',
    '10_dbt_pipeline/models/gold/dim/DIM_MEMBER_ACQUISITION.sql',
    '10_dbt_pipeline/models/gold/fact/FACT_DEV_ACHIEVEMENT.sql',
    '10_dbt_pipeline/tests/assert_fact_dev_achv_goal_rows_preserved.sql',
    '10_dbt_pipeline/tests/warn_gold_view_comment_coverage.sql',
    'scripts/gen_o53_gold_ddl.py', 'scripts/gen_o53_ad_combined.py',
    'scripts/run_o53_new_tables.py', 'scripts/table_ddl_column_gate.py',
    'scripts/audit_ddl_rule7.py', 'scripts/ws_stage_verify.py',
    'scripts/o51d_view_comments/gate.py',
    'scripts/field_mapping_override.py', 'scripts/gen_section_assembly.py',
    'scripts/gen_column_mapping.py', 'scripts/gen_concept_diagram.py',
]
# 삭제되었어야 하는 파일 — 스테이지에 남아 있으면 실패
O53_DELETED = [
    '10_dbt_pipeline/models/gold/wide/WIDE_DEV_ACHIEVEMENT.sql',
    '10_dbt_pipeline/tests/assert_wide_dev_achv_goal_rows_preserved.sql',
]


def stage_index(dirs):
    idx = {}
    for d in sorted(dirs):
        pref = f'/{d}/' if d else '/'
        out = subprocess.run(['cortex', 'ws', 'ls', f'{WS}:{pref}'],
                             capture_output=True, text=True).stdout
        for line in out.split('\n'):
            m = re.match(r'(/versions/\w+/\S.*?)\s+(\d+)\s+([0-9a-f]{32})\s', line)
            if m:
                idx[m.group(1).split('/versions/live/', 1)[-1]] = int(m.group(2))
    return idx


def main():
    if '--o53' in sys.argv:
        files, deleted = O53_FILES, O53_DELETED
    elif len(sys.argv) > 1:
        files = [l.strip() for l in open(sys.argv[1], encoding='utf-8') if l.strip()]
        deleted = []
    else:
        # 🔴 [2026-08-30 O121-B] 종전 `sys.exit(__doc__)` 은 **rc=1** 이었다 — 사용법 출력이
        #    「위반」과 같은 코드를 내면 게이트 순회에서 **거짓 FAIL** 이 된다(O121 이 실제로 그렇게 셌다).
        #    ⇒ 규약 = **0 통과 · 1 위반 · 2 사용법 오류**(O120 이 `o54_sv_value_gate` 에서 확립).
        print(__doc__)
        sys.exit(2)

    idx = stage_index({os.path.dirname(f) for f in files} | {os.path.dirname(f) for f in deleted})
    ok = bad = miss = absent = 0
    for f in files:
        path = os.path.join(ROOT, f)
        if not os.path.exists(path):
            absent += 1
            print(f'  🔴 로컬 부재      {f}')
            continue
        loc = os.path.getsize(path)
        st = idx.get(f)
        allowed = {math.ceil(loc / 16) * 16, math.ceil((loc + 1) / 16) * 16}
        if st is None:
            miss += 1
            print(f'  🔴 스테이지 부재  {f}')
        elif st in allowed:
            ok += 1
        else:
            bad += 1
            print(f'  🔴 반영 불일치    {f}  로컬 {loc}B → 스테이지 {st}B (기대 {sorted(allowed)})')
    print(f'\n반영 확인 {ok} · 불일치 {bad} · 스테이지부재 {miss} · 로컬부재 {absent} / 대상 {len(files)}')
    for g in deleted:
        print(('  🔴 삭제 미반영  ' if g in idx else '  ✅ 삭제 반영    ') + g)
    # 🔴🔴 [2026-08-11 O59-E] **분모 0 은 SKIP 이 아니라 실패다**(P106 의 처방인데 이 게이트에 빠져 있었다).
    #   종전 판정은 `if bad or miss` 뿐이어서 **로컬 부재를 아무 카운터에도 넣지 않았고**,
    #   전건 부재여도 `반영 확인 0` 과 함께 **`✅ 전건 반영` 을 출력**했다 — 실측으로 재현했다(O59-E).
    if bad or miss or absent:
        sys.exit('🔴 스테이지 반영 실패 — 파일 단위 재복사 후 재검사할 것(P99)')
    if not ok:
        sys.exit('🔴 공집합 통과 — 검사한 파일이 0 이다(P106: 분모 0 은 통과가 아니다)')
    print(f'✅ 전건 반영 — {ok}/{len(files)}')


if __name__ == '__main__':
    main()

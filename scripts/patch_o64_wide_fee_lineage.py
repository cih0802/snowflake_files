#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[O64] `_wide_schema.yml` 의 `WIDE_MEMBER_FEE` 계보 오기 교정 — `DIM_MEMBER.` → `DIM_MEMBER_CURRENT.`

🔴 무엇이 틀렸나: 이 뷰의 회원 속성은 모델 76행이 **`DIM_MEMBER_CURRENT`** 를 조인해서 온다
   (`WIDE_MEMBER_FEE.sql:76` · O58 이 SCD2 자체 dedup 을 이 테이블로 치환했다).
   그런데 yml 문안은 `DIM_MEMBER.<컬럼>` 으로 계보를 적어, Cortex Analyst 가 읽는 문안이 **틀린 원천을 지목**했다.
   O59-T ㉢ 가 산출물 04 만 교정하고 yml 은 남긴 항목이다(그때 기재는 「6컬럼」이었으나 실측은 아래와 같다).

⚠️ 손으로 치환하지 않는다(O63-J ④ = 기계 치환이 조사를 깨뜨린 전례). 규칙:
   · 대상 = `WIDE_MEMBER_FEE` 모델 블록 **안에서만** 치환한다(다른 뷰는 실제로 `DIM_MEMBER` 를 조인한다 — 기계 대조로 확인).
   · **`FK→DIM_MEMBER.MEMBER_DK` 는 건드리지 않는다** — 그것은 팩트 컬럼의 FK 대상 선언이고 이 뷰의 조인 경로가 아니다.
   · 치환 후 기대 건수를 assert 한다. 어긋나면 아무것도 쓰지 않고 종료한다.

사용법
  python3 scripts/patch_o64_wide_fee_lineage.py --dry   # 대상만 출력
  python3 scripts/patch_o64_wide_fee_lineage.py         # 적용
Co-authored with CoCo
"""
import io
import re
import sys

YML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
MODEL = 'WIDE_MEMBER_FEE'
EXPECT = 9              # 계보 지목 9건(FK 선언 1건은 제외)
KEEP = 'FK→DIM_MEMBER.MEMBER_DK'   # 보존 대상 — 치환하면 FK 선언이 거짓이 된다

RE_MODEL = re.compile(r'^  - name: (\w+)\s*$')
# 계보 지목 형태만 좁게 잡는다: `DIM_MEMBER.` 뒤에 컬럼명이 오는 경우
RE_LINEAGE = re.compile(r'\bDIM_MEMBER\.([A-Z][A-Z0-9_]*)')


def main():
    dry = '--dry' in sys.argv
    src = io.open(YML, encoding='utf-8').read().split('\n')

    start = end = None
    for i, line in enumerate(src):
        m = RE_MODEL.match(line)
        if not m:
            continue
        if m.group(1) == MODEL:
            start = i
        elif start is not None and end is None:
            end = i
            break
    if start is None:
        print('🔴 모델 블록을 찾지 못했다 — 중단'); sys.exit(1)
    if end is None:
        end = len(src)
    print(f'대상 블록 = {MODEL} · {start + 1}~{end}행')

    out = list(src)
    hits, kept = [], 0
    for i in range(start, end):
        line = out[i]
        if KEEP in line:
            kept += line.count(KEEP)
        # KEEP 부분을 자리표시자로 빼두고 치환한 뒤 되돌린다
        stash = line.replace(KEEP, '\x00')
        new, n = RE_LINEAGE.subn(lambda m: f'DIM_MEMBER_CURRENT.{m.group(1)}', stash)
        if n:
            for m in RE_LINEAGE.finditer(stash):
                hits.append((i + 1, m.group(1)))
        out[i] = new.replace('\x00', KEEP)

    print(f'계보 지목 {len(hits)}건 · 보존(FK 선언) {kept}건')
    for ln, col in hits:
        print(f'  {ln}행 DIM_MEMBER.{col} → DIM_MEMBER_CURRENT.{col}')

    if len(hits) != EXPECT:
        print(f'🔴 기대 {EXPECT} ≠ 실제 {len(hits)} — 아무것도 쓰지 않고 중단(전제가 바뀌었다)'); sys.exit(1)
    if kept != 1:
        print(f'🔴 FK 선언 보존 기대 1 ≠ 실제 {kept} — 중단'); sys.exit(1)

    # 블록 밖은 한 글자도 바뀌지 않았음을 검증
    if src[:start] != out[:start] or src[end:] != out[end:]:
        print('🔴 블록 밖이 변경됐다 — 중단'); sys.exit(1)

    if dry:
        print('\n(dry) 미적용'); return
    io.open(YML, 'w', encoding='utf-8').write('\n'.join(out))
    print(f'\n✅ 적용 완료 — {len(hits)}건 치환 · 줄 수 {len(src)} → {len(out)}(불변이어야 한다)')


if __name__ == '__main__':
    main()

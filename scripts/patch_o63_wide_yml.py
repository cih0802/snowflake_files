#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63 — `_wide_schema.yml` 의 폐기 `'미상'` 규약을 **축별 NULL 사유**로 교체한다.

왜 스크립트인가: 같은 문구가 6개 WIDE 뷰에 12번 복제돼 있고 축은 3종뿐이다.
축을 `DIM_MEMBER.<컬럼>` 접두로 판별해 교체하므로 어느 축에 어느 문안이 갔는지 기계로 보증된다.
🔴 교체 후 반드시 잔존 0 을 재확인한다(이 스크립트가 스스로 검사한다).
⚠️ 규칙7: 문안에 실측 수치를 넣지 않는다 — 규모는 원장 §O63 참조.
Co-authored with CoCo
"""
import io
import re
import sys

YML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
OLD = "미매핑은 '미상'."

NEW = {
    'MEMBER_STATUS_NAME':
        "🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 "
        "**원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 "
        "**NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1).",
    'MEMBER_TYPE_NAME':
        "🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 "
        "코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1).",
    'ENROLL_PATH_NAME':
        "🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** "
        "센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다"
        "(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1).",
}
AXIS = re.compile(r'DIM_MEMBER\.(MEMBER_STATUS_NAME|MEMBER_TYPE_NAME|ENROLL_PATH_NAME)\b')


def main():
    src = io.open(YML, encoding='utf-8').read()
    lines = src.split('\n')
    hit = {k: 0 for k in NEW}
    for i, line in enumerate(lines):
        if OLD not in line:
            continue
        m = AXIS.search(line)
        if not m:
            print(f'🔴 {i + 1}행 — 축 판별 실패. 손으로 확인할 것.')
            sys.exit(1)
        axis = m.group(1)
        lines[i] = line.replace(OLD, NEW[axis])
        hit[axis] += 1
    out = '\n'.join(lines)
    if OLD in out:
        print('🔴 교체 후에도 잔존 — 중단')
        sys.exit(1)
    io.open(YML, 'w', encoding='utf-8').write(out)
    print(f'🟢 교체 완료 — 총 {sum(hit.values())}건')
    for k, v in hit.items():
        print(f'  {k:<22} {v}건')


if __name__ == '__main__':
    main()

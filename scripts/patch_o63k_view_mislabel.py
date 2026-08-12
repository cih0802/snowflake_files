#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63-K — `06_DDL.sql` 의 「뷰」 오표기를 교정한다. **대상은 BASE TABLE 이다.**

🔴 결함: `DIM_MEMBER_CURRENT`(5컬럼)·`DIM_MEMBER_ACQUISITION`(3컬럼)의 COMMENT 가 자기 객체를
   「본 뷰」·「이 뷰」로 부른다. 라이브 실측 = 두 객체 모두 `TABLE_TYPE='BASE TABLE'` 이다.
   ⇒ Analyst·Agent 가 COMMENT 를 근거로 「뷰라서 저장 비용이 없다 / 정의만 바꾸면 된다」로 답할 수 있고,
     실제로는 `+full_refresh:false` 로 보호되는 물리 테이블이라 조치 방향이 정반대다.
🔴 유래: `DIM_MEMBER_CURRENT` 는 원래 SERVING **helper 뷰**였고 O53~O55 에서 GOLD BASE TABLE 로 승격됐다.
   객체 타입은 바뀌었는데 **문안이 따라오지 않았다**(O63 이 O62 문안을 물려받으며 그대로 복제하기도 했다).
⚠️ 용례 전건을 육안 확인했다 — 모두 **자기 객체**를 가리키며 다른 뷰를 지목하는 경우는 없다.
Co-authored with CoCo
"""
import io
import sys

DDL = '/workspace/03_top-down_gold/06_DDL.sql'
# 긴 것부터 교체해야 짧은 패턴이 앞에서 먹지 않는다
PATCH = [('본 뷰는', '이 테이블은'), ('이 뷰에', '이 테이블에'), ('이 뷰', '이 테이블')]
EXPECT = {'본 뷰는': 5, '이 뷰에': 3, '이 뷰': 2}


def main():
    src = io.open(DDL, encoding='utf-8').read()
    # 사전 검증: 기대 분포와 다르면 대상이 달라진 것이므로 중단한다
    seen = {'본 뷰는': src.count('본 뷰는'),
            '이 뷰에': src.count('이 뷰에'),
            '이 뷰': src.count('이 뷰') - src.count('이 뷰에')}
    if seen != EXPECT:
        print(f'🔴 기대 분포 {EXPECT} · 실측 {seen} — 중단하고 손으로 확인할 것.')
        sys.exit(1)

    n = 0
    for old, new in PATCH:
        n += src.count(old)
        src = src.replace(old, new)
    for old, _ in PATCH:
        if old in src:
            print(f'🔴 교체 후 잔존: {old} — 중단')
            sys.exit(1)
    io.open(DDL, 'w', encoding='utf-8').write(src)
    print(f'🟢 「뷰」 오표기 교정 — {n}건(본 뷰는 5 · 이 뷰에 3 · 이 뷰 2)')


if __name__ == '__main__':
    main()

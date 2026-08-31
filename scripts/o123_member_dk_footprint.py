# MEMBER_DK 소비처 실측 — O122 기재 「178파일」의 재현 시도 + 배선 대상 분리.
# Co-authored with CoCo
#
# 🔴 왜 필요한가 (O123 자기검토):
#   O123 이 「178파일」을 O122 기재값 그대로 3개 문서에 인용했다(`R3-1` 위반 소지).
#   그 수치는 ㉠ `_archive` 포함 여부 ㉡ 문서(.md)와 코드의 혼재 여부가 선언돼 있지 않아
#   재현 불가능했다. ⇒ 축을 분리해 재고, 「소비처 grep」의 실제 대상을 확정한다.
#
# 🔴 판정식 = 개명이 깨뜨리는 것은 **코드·설정**이고 문서는 뒤따라 고칠 대상이다.
#   두 축을 한 수로 합치면 작업량이 과대해 보이고 우선순위가 사라진다.

import os
import sys
from collections import Counter

TOKEN = 'MEMBER_DK'
EXTS_ALL = ('.sql', '.yml', '.yaml', '.md', '.py', '.csv', '.ipynb', '.json', '.txt')
EXTS_CODE = ('.sql', '.yml', '.yaml', '.py', '.json', '.ipynb')
SKIP_DIRS = {'.git', '.snowflake'}


def scan(root, token, skip_archive):
    hits = []
    for dirpath, _dirnames, filenames in os.walk(root):
        parts = dirpath.split(os.sep)
        if SKIP_DIRS & set(parts):
            continue
        if skip_archive and '_archive' in parts:
            continue
        for name in filenames:
            if not name.endswith(EXTS_ALL):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, encoding='utf-8', errors='ignore') as handle:
                    if token in handle.read():
                        hits.append(path)
            except OSError:
                pass
    return hits


def main():
    token = sys.argv[1] if len(sys.argv) > 1 else TOKEN
    root = '/workspace'

    with_archive = scan(root, token, skip_archive=False)
    live = scan(root, token, skip_archive=True)
    code = [p for p in live if p.endswith(EXTS_CODE)]
    docs = [p for p in live if p not in set(code)]

    print(f'[{token} 소비처 실측] 🔴 축을 분리해 센다 — 한 수로 합치면 우선순위가 사라진다')
    print(f'  ㉠ 전체(`_archive` 포함)      = {len(with_archive):4d} 파일')
    print(f'  ㉡ 현행(`_archive` 제외)      = {len(live):4d} 파일')
    print(f'  ㉢ 🔴 배선 대상(코드·설정만)  = {len(code):4d} 파일  ← 개명이 **깨뜨리는** 것')
    print(f'  ㉣ 문서(후속 갱신 대상)       = {len(docs):4d} 파일  ← 깨지지 않고 stale 이 된다')

    top = Counter(
        (p.split(os.sep)[2] if len(p.split(os.sep)) > 2 else os.path.basename(p))
        for p in code
    )
    print('  ㉢ 의 최상위 분포:')
    for key, num in sorted(top.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f'      {num:4d}  {key}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

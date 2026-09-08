# O143 조사 스크립트 — os.path.getsize(stat) 와 실제 바이트 수를 전 문서에서 대조한다.
# Co-authored with CoCo
#
# 🔴 왜: 세션 착수 시 `session_brief.py` 가 낸 stale 1건이 오탐이었다.
#   기재 14,891 ↔ 「실측」 14,896 이고, 14,896 은 14,891 의 **16바이트 블록 반올림값**이다.
#   지침 `R2-5` 는 「`ws ls` size 는 블록 반올림값」이라고 이미 경고하는데,
#   `doc_census.nbytes_of` 는 `os.path.getsize` 를 써서 **같은 함정을 밟는다.**
# ⇒ 판정식 = stat 값과 실제 읽은 바이트 수가 **한 파일이라도 다르면** 측정축이 오염된 것이다.

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

targets = []
for base, dirs, files in os.walk(ROOT):
    if any(seg in base for seg in ('_archive', '__pycache__', '/tmp', '/.snowflake')):
        continue
    for f in files:
        if f.endswith('.md'):
            targets.append(os.path.join(base, f))
targets.sort()

diffs = []
for p in targets:
    stat_n = os.path.getsize(p)
    with open(p, 'rb') as fh:
        real_n = len(fh.read())
    if stat_n != real_n:
        diffs.append((os.path.relpath(p, ROOT), stat_n, real_n))

print('[O143 측정축 대조] .md 파일 %d개' % len(targets))
if diffs:
    print('🔴 stat ↔ 실제 바이트 불일치 %d건' % len(diffs))
    for rel, s, r in diffs:
        print('   %s  stat=%d  real=%d  차=%d' % (rel, s, r, s - r))
    sys.exit(1)
print('✅ 전건 일치 — 이 시점에는 stat 이 정확하다(파일이 이미 materialize 된 상태)')
print('⚠️ 그러나 이것은 「stat 이 항상 정확하다」의 근거가 아니다 —')
print('   착수 1차 브리핑의 실측 14,896 이 반올림값이었다는 관측은 그대로 유효하다.')
sys.exit(0)

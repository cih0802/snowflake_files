"""O275-C 실행순서 4종 본문 옛 경로 → 새 배치(MOVE_MAP 기준). dry-run 기본 · --apply 로 스냅샷 후 쓴다.
치환 순서 ㉠ 파일 단위 old_path 전문 일치(긴 것부터) ㉡ 폴더 접두(요약 MOVE_MAP 폴더 행 · 긴 것부터).
경계 = 앞 글자가 시작·공백·'/'·백틱·괄호·따옴표·'=' 일 때만(다른 경로의 중간을 바꾸지 않는다).
80·85·90 은 MOVE_MAP 에 이동 행이 없어 자연히 제외된다(사용자 결정 = 재배치 완료 후 별도 수정).
"""
import csv, io, os, re, sys
from collections import Counter
ROOT = '/workspace'
D = f'{ROOT}/50_handover/50_execution_order'
DOCS = ['문서실행순서.md', '문서실행순서_llm실행.md', '문서실행순서_보조주석.md', '문서실행순서_운영계_LLM실행카드.md']
APPLY = '--apply' in sys.argv
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
files = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
pairs = {}
for r in files:
    if r['old_path'] != r['new_path'] and '/' in r['old_path']:
        pairs[r['old_path']] = r['new_path']
for r in summ:
    o, n = r['old_path'], r['new_path']
    if o != n and r['action'] in ('move', 'rename'):
        pairs.setdefault(o, n)          # 폴더 행(끝 '/') · 루트 파일 행
keys = sorted(pairs, key=len, reverse=True)
B = r'(?:(?<=^)|(?<=[\s/`(\'"=]))'
pat = re.compile(B + '(' + '|'.join(re.escape(k) for k in keys) + ')', re.M)
if APPLY:
    sys.path.insert(0, f'{ROOT}/scripts')
    from snapshot_util import snapshot
tot = Counter()
for d in DOCS:
    p = f'{D}/{d}'
    t = io.open(p, encoding='utf-8').read()
    c = Counter()
    def sub(m):
        k = m.group(1)
        # 루트 파일 행(슬래시 없는 문서명)은 /workspace/ 접두일 때만 바꾼다(문서명 단독 언급은 같은 폴더 상대 참조)
        if '/' not in k and t[max(0, m.start() - 11):m.start()] != '/workspace/':
            return k
        c[k] += 1
        return pairs[k]
    nt = pat.sub(sub, t)
    tot[d] = sum(c.values())
    print(f'▣ {d} 치환 {sum(c.values())}건 · 키 {len(c)}종')
    for k, v in c.most_common(8):
        print(f'   {v:4d}  {k} → {pairs[k]}')
    if APPLY and nt != t:
        print('   ', snapshot(p, 'pre-bodypath', label='O275-C'))
        io.open(p, 'w', encoding='utf-8').write(nt)
        assert io.open(p, encoding='utf-8').read() == nt
print('합계', sum(tot.values()), 'APPLIED' if APPLY else 'DRY-RUN')

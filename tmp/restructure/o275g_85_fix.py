"""O275-G 85 문서 본문의 워크스페이스 옛 경로 → 새 배치(MOVE_MAP). dry-run 기본 · --apply.
제외 ㉠ `_archive`·`_ENV` 하위 ㉡ 80 패키지 내부 경로 문맥(직전에 80 서브폴더명/ · `80_인수인계…/` 가 붙은 경우)
㉢ 데이터 파일(csv·xlsx·html·json) — 값이지 경로 지시가 아니다.
"""
import csv, io, os, re, sys
from collections import Counter
ROOT = '/workspace'
T = f'{ROOT}/85_실제 인수인계 문서'
APPLY = '--apply' in sys.argv
pairs = {}
for mm in ('MOVE_MAP_files.csv', 'MOVE_MAP.csv'):
    for r in csv.DictReader(open(f'{ROOT}/{mm}', encoding='utf-8-sig')):
        o, n = r['old_path'], r['new_path']
        if o != n and '/' in o and r['action'] in ('move', 'rename', 'archive'):
            pairs.setdefault(o, n)
keys = sorted(pairs, key=len, reverse=True)
pat = re.compile(r'(?:(?<=^)|(?<=[\s/`(\'"=]))(' + '|'.join(re.escape(k) for k in keys) + ')', re.M)
SUB80 = ('01_실행순서_배포SQL/', '02_dbt_pipeline/', '03_MSTR_이관/', '04_SV_Agent_스펙/', '05_RAG_지표사전/',
         '06_일배치_모니터링/', '07_운영런북_이슈/', '08_현업공유_산출물/', '09_설계근거_참고/', '10_운영도구_scripts/',
         '80_인수인계_프로젝트완료 및 유지보수용/', '80_인수인계_프로젝트완료_및_유지보수용/')
if APPLY:
    sys.path.insert(0, f'{ROOT}/scripts')
    from snapshot_util import snapshot
tot, files, skipped80 = 0, 0, 0
for dp, dns, fns in os.walk(T):
    dns[:] = [d for d in dns if d not in ('_archive', '_ENV', '__pycache__')]
    for fn in fns:
        if not fn.endswith(('.md', '.sql', '.py', '.yml', '.yaml', '.txt', '.sh')):
            continue
        p = os.path.join(dp, fn)
        try:
            t = io.open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        c = Counter()
        def sub(m):
            global skipped80
            pre = t[max(0, m.start() - 60):m.start()]
            if pre.endswith(SUB80):
                skipped80 += 1
                return m.group(1)
            c[m.group(1)] += 1
            return pairs[m.group(1)]
        nt = pat.sub(sub, t)
        if c:
            files += 1; tot += sum(c.values())
            print(f'{sum(c.values()):4d}  {os.path.relpath(p, ROOT)}  e.g. {next(iter(c))}')
            if APPLY:
                snapshot(p, 'pre-movemap', label='O275-G')
                io.open(p, 'w', encoding='utf-8').write(nt)
                assert io.open(p, encoding='utf-8').read() == nt
print('합계', tot, '파일', files, '80 문맥 제외', skipped80, 'APPLIED' if APPLY else 'DRY-RUN')

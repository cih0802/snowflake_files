# 병렬 이동 효과 벤치마크(테스트 파일 전용 · 실제 대상 파일은 건드리지 않는다)
import os, shutil, time, sys
from concurrent.futures import ThreadPoolExecutor

B = '/workspace/_archive/O276_project_closure/_bench'
N = 24

def prep(tag):
    src = os.path.join(B, tag, 'src'); dst = os.path.join(B, tag, 'dst')
    os.makedirs(src, exist_ok=True); os.makedirs(dst, exist_ok=True)
    for i in range(N):
        open(os.path.join(src, f'f{i}.txt'), 'w').write('x' * 2000)
    return src, dst

def mv(a):
    s, d = a
    shutil.move(s, d)

for tag, workers in (('serial', 1), ('p8', 8), ('p16', 16)):
    src, dst = prep(tag)
    jobs = [(os.path.join(src, f'f{i}.txt'), os.path.join(dst, f'f{i}.txt')) for i in range(N)]
    t = time.time()
    if workers == 1:
        for j in jobs: mv(j)
    else:
        with ThreadPoolExecutor(workers) as ex: list(ex.map(mv, jobs))
    el = time.time() - t
    ok = sum(os.path.exists(d) and not os.path.exists(s) for s, d in jobs)
    print(f'{tag}: {N} files {el:.1f}s = {el/N:.2f}s/file · verified {ok}/{N}')
    sys.stdout.flush()

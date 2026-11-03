# 폴더 색인(00_FOLDER_INDEX.md) 생성기 — 루트 1·2단계 폴더 대상 (_archive · .snowflake · 숨김 · __pycache__ 제외)
# 사용: python3 scripts/build_folder_index.py [--apply]   (기본 = dry-run: 대상 폴더와 README 유무만 출력)
# 1단계 INDEX = 직속 파일 + 하위 폴더 요약(파일 수) · 2단계 INDEX = 하위 전체 재귀 목록
import datetime, os, sys

ROOT = __import__('kit_paths').ROOT  # [kit] 루트 = kit_paths.py
APPLY = '--apply' in sys.argv
SKIP = {'_archive', '__pycache__'}
INDEX = '00_FOLDER_INDEX.md'  # 기존 00_INDEX.md(21_env_rbac) 와 충돌 방지


def skip(name):
    return name in SKIP or name.startswith('.')


def subdirs(path):
    return sorted(d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d)) and not skip(d))


def files_in(path):
    return sorted(f for f in os.listdir(path)
                  if os.path.isfile(os.path.join(path, f)) and f not in (INDEX, '.folder'))


def walk_files(path):
    out = []
    for dp, dn, fn in os.walk(path):
        dn[:] = sorted(d for d in dn if not skip(d))
        for f in sorted(fn):
            if f in (INDEX, '.folder'):
                continue
            out.append(os.path.relpath(os.path.join(dp, f), path))
    return out


def readme_of(path):
    r = [f for f in files_in(path) if 'readme' in f.lower()]
    return r[0] if r else None


def size(p):
    try:
        n = os.path.getsize(p)
    except OSError:
        return '-'
    return f'{n:,}'


def header(rel, kind):
    today = datetime.date.today().isoformat()
    return [f'# INDEX — `{rel}/`', '',
            f'> 자동 생성(`scripts/build_folder_index.py` · {today}) · 손으로 고치지 말고 재실행한다.',
            f'> 범위 = {kind} · 제외 = `_archive/` · 숨김 폴더 · `__pycache__/` · `.folder`', '']


def build_l1(rel):
    path = os.path.join(ROOT, rel)
    lines = header(rel, '직속 파일 + 하위 폴더 요약(상세는 각 하위 폴더 `00_FOLDER_INDEX.md`)')
    subs = [d for d in subdirs(path) if rel + '/' + d not in GENERATED]
    lines += ['## 하위 폴더', '', '| 폴더 | 파일 수(재귀) | README |', '|---|---:|---|']
    for d in subs:
        p = os.path.join(path, d)
        lines.append(f'| `{d}/` | {len(walk_files(p))} | {readme_of(p) or "-"} |')
    if not subs:
        lines.append('| (없음) | | |')
    fs = files_in(path)
    lines += ['', f'## 직속 파일 ({len(fs)})', '', '| 파일 | 크기(B) |', '|---|---:|']
    lines += [f'| `{f}` | {size(os.path.join(path, f))} |' for f in fs] or ['| (없음) | |']
    return lines


def build_l2(rel):
    path = os.path.join(ROOT, rel)
    fs = walk_files(path)
    lines = header(rel, '하위 전체 재귀')
    lines += [f'## 파일 ({len(fs)})', '', '| 경로 | 크기(B) |', '|---|---:|']
    lines += [f'| `{f}` | {size(os.path.join(path, f))} |' for f in fs] or ['| (없음) | |']
    return lines


GENERATED = {'10_dbt_pipeline/logs', '10_dbt_pipeline/target'}  # dbt 실행 산출물 — 색인하지 않는다


def live(rel):  # 마운트 캐시에 남은 빈 껍데기(스테이지 실파일 0) 제외
    return rel not in GENERATED and len(walk_files(os.path.join(ROOT, rel))) > 0


targets = []
for d1 in subdirs(ROOT):
    if not live(d1):
        continue
    targets.append((d1, 1))
    for d2 in subdirs(os.path.join(ROOT, d1)):
        if live(d1 + '/' + d2):
            targets.append((d1 + '/' + d2, 2))

no_readme = []
for rel, lv in targets:
    rd = readme_of(os.path.join(ROOT, rel))
    if not rd:
        no_readme.append(rel)
    if APPLY:
        body = build_l1(rel) if lv == 1 else build_l2(rel)
        with open(os.path.join(ROOT, rel, INDEX), 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('\n'.join(body) + '\n')
    print(f'L{lv}', rel, '| README =', rd or '-')
print('targets', len(targets), 'no_readme', len(no_readme), 'applied' if APPLY else 'dry-run')

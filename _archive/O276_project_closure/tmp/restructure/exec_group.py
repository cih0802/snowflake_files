"""O275 4-C 그룹 실행기.

사용: python3 exec_group.py <group_prefix> [--apply]
  group_prefix = MOVE_MAP_files.csv new_path 접두(예: 70_reference/ · tmp/root_scratch/)

단계(계획서 §4-C): ① 시험 실행(이동 수 · 문서별 치환 수) ② 백업(치환 대상 원본 → snapshot_util)
  ③ 이동 = 복사 → SHA256 대조 → 원본 **파일 개별 삭제**(R1-7-7) → 빈 폴더만 rmdir
  ④ 경로 치환 = 현행 문서만(scripts · 00_guides · README/INDEX · 00_WORKSPACE_MAP.md)
  ⑤ 검증 = 원본 부재 · 대상 실재 · 치환 대상 잔존 0 · line_len
금지 영역(치환하지 않음): _archive · tmp · 20_issue · 99_NEXT_SESSION_조각 · 80 · 85 · 90 · 10_dbt_pipeline ·
  계획서 · MOVE_MAP*.csv · 99_NEXT_SESSION.md(허브 자동 생성물)
"""
import csv, hashlib, json, os, re, shutil, sys, time
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
GROUP = sys.argv[1]
APPLY = '--apply' in sys.argv
MOVE_ONLY = '--move-only' in sys.argv  # 대용량 분할 실행: 이동만(스냅샷·치환·잔존 검사 생략) · 치환은 그룹 접두로 별도 1회
TAG = GROUP.strip('/').replace('/', '_')
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4C/{TAG}'
LOG = f'{ROOT}/tmp/restructure/exec_{TAG}.json'
README = {'00_README.md', 'README.md', 'readme.md', '00_INDEX.md', '00_README_N07.md', '00_INDEX_산출물목록.md'}
TEXT = ('.py', '.md', '.sql', '.yml', '.yaml', '.json', '.txt', '.sh', '.toml')
FROZEN = re.compile(r'(^|/)(_archive|_backup_[^/]*|[^/]*_조각|__pycache__|target|logs)(/|$)')

files = [r for r in csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig'))
         if r['new_path'].startswith(GROUP)]
ALL = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


# ── 치환 쌍: 파일 단위(rename/archive/루트) → 하위 폴더 rename → 최상위 폴더 (긴 것 우선)
pairs = []
for r in files:
    o, n = r['old_path'], r['new_path']
    if r['action'] in ('rename', 'archive') or '/' not in o:
        pairs.append((o, n))
for r in summ:
    if r['old_path'].endswith('/') and r['new_path'].startswith(GROUP):
        pairs.append((r['old_path'].rstrip('/'), r['new_path'].rstrip('/')))
pairs = sorted(set(pairs), key=lambda x: -len(x[0]))
BOUND_L = r'(?<![\w/.\-])'
BOUND_R = r'(?=[/`\'"\s)\]|,:;>]|$)'
rx = [(re.compile(BOUND_L + re.escape(o) + BOUND_R), n) for o, n in pairs]
# 라이브 스테이지 경로는 앞이 `/` 라 위 경계에서 빠진다 → 전용 쌍
rx = [(re.compile(re.escape('versions/live/' + o) + BOUND_R), 'versions/live/' + n) for o, n in pairs] + rx


def targets():
    out = []
    for top in ('scripts', '00_guides'):
        for dp, dns, fns in os.walk(f'{ROOT}/{top}'):
            dns[:] = [d for d in dns if d not in ('__pycache__', '_archive')]
            out += [os.path.join(dp, f) for f in fns if f.endswith(TEXT)]
    out.append(f'{ROOT}/00_WORKSPACE_MAP.md')
    for r in ALL:  # 전 그룹 README/INDEX + 라이브 스테이지 경로(versions/live/)를 쓰는 배포 코드(그룹 간 교차 참조 포함)
        base = os.path.basename(r['new_path'])
        n, o = f'{ROOT}/{r["new_path"]}', f'{ROOT}/{r["old_path"]}'
        p = n if os.path.exists(n) else o
        if base in README:
            out.append(p)
        elif base.endswith(('.sql', '.py', '.yml', '.yaml')) and os.path.isfile(p) \
                and not FROZEN.search(r['old_path']):  # _archive·_backup_* 등 동결 영역은 치환 금지
            try:
                if 'versions/live/' in open(p, encoding='utf-8', errors='ignore').read():
                    out.append(p)
            except OSError:
                pass
    return [p for p in out if os.path.isfile(p)]


def subst(text):
    cnt = 0
    for c, n in rx:
        text, k = c.subn(n, text)
        cnt += k
    return text, cnt


def plan_subst():
    res = []
    for p in targets():
        try:
            t = open(p, encoding='utf-8').read()
        except (UnicodeDecodeError, OSError):
            continue
        nt, k = subst(t)
        if k:
            res.append((p, k))
    return res


# ① 시험 실행 (재개: 직전 로그 moved 에 있고 원본 부재 · 대상 실재면 이동 완료로 본다)
prev = set(json.load(open(LOG))['moved']) if os.path.exists(LOG) else set()
done = {r['old_path'] for r in files  # 이 실행기는 해시 일치 후에만 원본을 지운다 ⇒ 원본 부재 + 대상 실재 = 완료
        if not os.path.exists(f'{ROOT}/{r["old_path"]}') and os.path.exists(f'{ROOT}/{r["new_path"]}')}
miss = [r for r in files if r['old_path'] not in done and not os.path.exists(f'{ROOT}/{r["old_path"]}')]
def same_file(o, n):
    try:
        return sha(o) == sha(n)
    except OSError:  # 마운트 낡은 뷰 — 판정 보류(완료로 보지 않는다)
        return False


if APPLY:  # 중단 재개: 원본·대상 모두 있고 해시 동일 = 복사 완료 · 원본 삭제 전 끊김 → 원본 삭제로 마무리
    for r in files:
        o, n = f'{ROOT}/{r["old_path"]}', f'{ROOT}/{r["new_path"]}'
        if r['old_path'] not in done and os.path.exists(o) and os.path.exists(n) and same_file(o, n):
            os.remove(o)
            done.add(r['old_path'])
clash = [r['new_path'] for r in files if r['old_path'] not in done and os.path.exists(f'{ROOT}/{r["new_path"]}')
         and os.path.exists(f'{ROOT}/{r["old_path"]}')]
print(f'[{GROUP}] 이동 {len(files)} · 재개 완료분 {len(done)} · 치환쌍 {len(pairs)} · 원본 부재(소실) {len(miss)} · '
      f'부분 복사 재시도 {len(clash)}')  # 원본이 살아 있으므로 원본으로 다시 덮어쓴다
if not APPLY:
    ps = plan_subst()
    print(f'치환 예정 문서 {len(ps)} · 치환 {sum(k for _, k in ps)}')
    for p, k in sorted(ps, key=lambda x: -x[1])[:15]:
        print(f'  {k}\t{os.path.relpath(p, ROOT)}')
    sys.exit(0)

log = {'group': GROUP, 'start': time.strftime('%F %T'), 'moved': [], 'subst': [], 'errors': []}
# ② 백업(이동 전 위치의 치환 대상 = scripts·00_guides·MAP · README 는 이동 후 치환하므로 원본 경로로 스냅샷)
APPLY_SAVE = APPLY
APPLY = False
pre = [] if MOVE_ONLY else plan_subst()
APPLY = APPLY_SAVE
os.makedirs(ARCH, exist_ok=True)
for p, _ in pre:
    nm = os.path.relpath(p, ROOT).replace('/', '__').replace(' ', '_') + '.O275-4C-pre'
    snapshot(p, 'pre', label='O275', archive=ARCH, name=nm, quiet=True)
# ③ 이동 (재개분 건너뜀 · 파일당 3회 재시도 · 마운트 일시 I/O 오류 대비)
log['moved'] = sorted(done)
log['lost'] = [[r['old_path'], r['new_path'], '착수 전 원본 부재'] for r in miss]
skip = {r['old_path'] for r in miss}
for r in files:
    if r['old_path'] in done or r['old_path'] in skip:
        continue
    o, n = f'{ROOT}/{r["old_path"]}', f'{ROOT}/{r["new_path"]}'
    err = None
    for attempt in range(3):
        try:
            os.makedirs(os.path.dirname(n), exist_ok=True)
            h = sha(o)
            shutil.copy2(o, n)
            if sha(n) != h:
                raise RuntimeError('해시 불일치')
            os.remove(o)
            err = None
            break
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(3)
    if err:
        if not os.path.exists(o) and not os.path.exists(n):
            log['lost'].append([r['old_path'], r['new_path'], f'이동 중 소실: {err}'])
        else:
            log['errors'].append(f'{r["old_path"]}: {err}')
        continue
    log['moved'].append(r['old_path'])
json.dump(log, open(LOG, 'w'), ensure_ascii=False, indent=1)  # 중간 저장(재개 근거)
if MOVE_ONLY:
    print(f'move-only {GROUP}: moved {len(log["moved"])}/{len(files)} · 소실 {len(log["lost"])} · errors {len(log["errors"])}')
    sys.exit(0)
if True:
    tops = {r['old_path'].split('/')[0] for r in files if '/' in r['old_path']}
    for t in tops:
        for dp, dns, fns in sorted(os.walk(f'{ROOT}/{t}'), key=lambda x: -len(x[0])):
            if not os.listdir(dp):
                try:
                    os.rmdir(dp)
                except OSError:  # 마운트 낡은 뷰(OPS-3) — 빈 폴더 잔존은 무해
                    pass
    # ④ 치환
    for p in targets():
        try:
            raw = open(p, 'rb').read()
            t = raw.decode('utf-8')
        except (UnicodeDecodeError, OSError):
            continue
        nt, k = subst(t)
        if k:
            with open(p, 'wb') as fh:
                fh.write(nt.encode('utf-8'))
            assert open(p, 'rb').read() == nt.encode('utf-8')
            log['subst'].append([os.path.relpath(p, ROOT), k])
# ⑤ 검증
lost_old = {x[0] for x in log['lost']}
log['old_left'] = [r['old_path'] for r in files if os.path.exists(f'{ROOT}/{r["old_path"]}')]
log['new_missing'] = [r['new_path'] for r in files
                      if r['old_path'] not in lost_old and not os.path.exists(f'{ROOT}/{r["new_path"]}')]
log['residual'] = [[os.path.relpath(p, ROOT), k] for p, k in plan_subst()]
log['end'] = time.strftime('%F %T')
json.dump(log, open(LOG, 'w'), ensure_ascii=False, indent=1)
print(f'moved {len(log["moved"])}/{len(files)} · 소실 {len(log["lost"])} · errors {len(log["errors"])} · '
      f'old_left {len(log["old_left"])} · new_missing {len(log["new_missing"])} · '
      f'치환 문서 {len(log["subst"])}({sum(k for _, k in log["subst"])}) · 잔존 {len(log["residual"])}')
print('LOG', LOG)
sys.exit(1 if log['residual'] else 0)

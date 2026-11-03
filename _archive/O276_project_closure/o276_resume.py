# O276 이어하기 — CLOSURE_MOVE_MAP.csv(dry-run 1차) 를 정본 대응표로 보정한 뒤 남은 항목만 이동
# 사용: python3 o276_resume.py [--apply] [--max-sec N]
import csv, os, re, shutil, sys, time

ROOT = '/workspace'
MAP = os.path.join(ROOT, '_archive/O276_project_closure/CLOSURE_MOVE_MAP.csv')
APPLY = '--apply' in sys.argv
MAX = int(sys.argv[sys.argv.index('--max-sec') + 1]) if '--max-sec' in sys.argv else 600
ERP = {'ERP 나눔마케팅본부 예산현황 연동.sql': '01_',
       'ERP 마케팅 캠페인 제작 비용 나눔마케팅본부 캠페인 제작비 지출현황 연동.sql': '02_'}

rows = list(csv.DictReader(open(MAP, encoding='utf-8-sig')))
for r in rows:  # 1차 dry-run 뒤 반영한 두 보정(쉼표 → _ · ERP 번호)을 대응표에도 적용
    if r['old_path'].startswith('BRONZE_최종 인수인계 파일/'):
        d, f = os.path.split(r['new_path'])
        f = f.replace(',', '_')
        base = os.path.basename(r['old_path'])
        if base in ERP and not f.startswith(ERP[base]):
            f = ERP[base] + f
        r['new_path'] = d + '/' + f

PROG = os.path.join(ROOT, '_archive/O276_project_closure/_progress.txt')  # 마지막으로 처리한 행 번호(이어하기 · 끝나면 지워도 된다)
start = int(open(PROG).read()) if os.path.exists(PROG) and '--from-0' not in sys.argv else 0
t0, done, moved, missing = time.time(), start, 0, []
for i, r in enumerate(rows):
    if i < start:
        continue
    if APPLY and i % 20 == 0:
        open(PROG, 'w').write(str(i))
    src = os.path.join(ROOT, r['old_path'])
    dst = os.path.join(ROOT, r['new_path']) if r['new_path'] else ''
    if r['action'] == 'delete':
        if os.path.exists(src):
            if APPLY: os.remove(src)
            moved += 1
        else: done += 1
        continue
    if os.path.exists(src):
        if os.path.exists(dst):
            # 중단된 move 의 잔여(복사 완료 · 원본 미삭제): 내용이 같으면 원본만 지운다
            import hashlib
            h = lambda x: hashlib.sha256(open(x, 'rb').read()).hexdigest()
            try:
                same = h(src) == h(dst)
            except FileNotFoundError:  # 스테이지 반영 지연 — 원본이 이미 사라졌다
                done += 1; continue
            if APPLY and same:
                try: os.remove(src)
                except FileNotFoundError: pass
                moved += 1
            else:
                missing.append(('BOTH', r['old_path']))
            continue
        if APPLY:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
        moved += 1
    elif os.path.exists(dst):
        done += 1
    else:
        missing.append(('NONE', r['old_path']))
    if APPLY and time.time() - t0 > MAX:
        print('PAUSE (time limit)'); break

if '--write-map' in sys.argv:  # 보정은 1회 반영 완료 — timeout 강제 종료 중 손상을 피하려고 기본은 읽기 전용
    with open(MAP, 'w', encoding='utf-8-sig', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=['old_path', 'new_path', 'action', 'reason'])
        w.writeheader(); w.writerows(rows)
print('rows', len(rows), 'already', done, 'moved_now' if APPLY else 'to_move', moved, 'problems', len(missing))
for m in missing[:20]: print(' ', *m)

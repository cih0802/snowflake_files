# O276 프로젝트 종료 정리 — 파일 단위 이동 + CLOSURE_MOVE_MAP.csv 기록
# 사용: python3 o276_move.py [--apply]   (인자 없으면 dry-run: 대응표만 출력)
import csv, os, re, shutil, sys

ROOT = '/workspace'
ARC = '_archive/O276_project_closure'
APPLY = '--apply' in sys.argv
rows = []  # (old, new, action, reason)


def norm(name):
    """O275 규칙: 꼬리 공백 제거 · 공백→_ · 선두 번호 두 자리."""
    stem, ext = os.path.splitext(name)
    stem = re.sub(r'[\s,]+', '_', stem.strip())
    m = re.match(r'^(\d+)(-\d+)?_?(.*)$', stem)
    if m and len(m.group(1)) == 1:
        stem = '0' + m.group(1) + (m.group(2) or '') + ('_' + m.group(3) if m.group(3) else '')
    elif m and not stem[len(m.group(1) + (m.group(2) or '')):].startswith('_') and m.group(3):
        stem = m.group(1) + (m.group(2) or '') + '_' + m.group(3)
    return stem + ext


def files(d):
    for dp, dn, fn in os.walk(os.path.join(ROOT, d)):
        for f in fn:
            yield os.path.relpath(os.path.join(dp, f), ROOT)


# ---- A. BRONZE ----
SRC_A = 'BRONZE_최종 인수인계 파일'
DST_A = '20_build/29_bronze_handover'
for p in sorted(files(SRC_A)):
    rel = os.path.relpath(p, SRC_A)
    parts = rel.split(os.sep)
    if parts[-1] == '연목표 데이터화 copy.sql':
        rows.append((p, f'{DST_A}/_archive/연목표_데이터화_copy.sql', 'archive', '원본과 다른 부분 초안'))
        continue
    newparts = [norm(x) for x in parts]
    if parts[-1] in ('공통.sql', '로그테이블.sql'):
        newparts[-1] = '00_' + newparts[-1]
    erp = {'ERP 나눔마케팅본부 예산현황 연동.sql': '01_',
           'ERP 마케팅 캠페인 제작 비용 나눔마케팅본부 캠페인 제작비 지출현황 연동.sql': '02_'}
    if parts[-1] in erp:
        newparts[-1] = erp[parts[-1]] + newparts[-1]
    reason = '이름 정규화'
    if parts[-1] == '0 요구사항.sql':
        newparts[-1] = '00_요구사항.md'
        reason = '내용이 마크다운 → .md'
    rows.append((p, DST_A + '/' + '/'.join(newparts), 'move', reason))

# ---- B. STREAMLIT ----
SRC_B = '09_STREAMLIT'
DST_B = '20_build/22_streamlit_apps'
APPS = {
    'X39FI0ZHW8A02OFS': '기획실대시보드_X39FI0ZHW8A02OFS',
    'AE4O8Q2VQMKWF5KV': '_archive/기획실대시보드_구버전_AE4O8Q2VQMKWF5KV',
    'DEV_DASHBOARD': '회원통계보고서_DEV_DASHBOARD',
    'FXDDFO7Z_L_ORZG7': '시연통합_FXDDFO7Z_L_ORZG7',
    'HJTMD27EXFUUEWND': '납입방식보고서_HJTMD27EXFUUEWND',
    'K2HQP_3PE6IR6TWC': '데이터연동오류현황_K2HQP_3PE6IR6TWC',
    'KEBFFP885PVNIDUB': '월간회원개발실적_KEBFFP885PVNIDUB',
    'W8PBGER093T61MQA': '회원개발통합리포트_W8PBGER093T61MQA',
    'MJE2FT3IPENTUJQ7': '마케팅캠페인통합성과_MJE2FT3IPENTUJQ7',
    'UNTITLED_12': '주간중단보고_UNTITLED_12',
    'UT35Y5QEK457979C': '월마감회비예측_UT35Y5QEK457979C',
}
for p in sorted(files(SRC_B)):
    rel = os.path.relpath(p, SRC_B)
    parts = rel.split(os.sep)
    if '__pycache__' in parts:
        rows.append((p, '', 'delete', '바이트코드(재생성) · 사용자 승인 O276'))
    elif rel == 'STREAMLIT BAK.sql':
        rows.append((p, f'{DST_B}/00_STREAMLIT_BAK.sql', 'move', '배포 Streamlit 일괄 백업 프로시저'))
    elif rel == 'analyst-selfservice-streamlit.md':
        rows.append((p, f'{ARC}/09_STREAMLIT/analyst-selfservice-streamlit.md', 'archive',
                     '20_build/27_streamlit_auth 동명 파일과 SHA256 동일'))
    else:
        app = APPS[parts[0]]
        act = 'archive' if app.startswith('_archive') else 'move'
        rows.append((p, f'{DST_B}/{app}/' + '/'.join(parts[1:]), act,
                     'X39 의 구버전' if act == 'archive' else '앱 제목_원래ID'))

# ---- C. 종료 폴더 (이름 유지) ----
for d in ['80_인수인계_프로젝트완료 및 유지보수용', '20_issue', '99_NEXT_SESSION_조각', '40_worklog', 'tmp']:
    for p in sorted(files(d)):
        rows.append((p, f'{ARC}/{p}', 'archive', '프로젝트 종료 · 이름 유지'))
for f in ['99_NEXT_SESSION.md', '999_temp.txt']:
    rows.append((f, f'{ARC}/{f}', 'archive', '프로젝트 종료' + (' · 빈 파일' if f == '999_temp.txt' else '')))
for f in ['00_WORKSPACE_RESTRUCTURE_PLAN.md', 'MOVE_MAP.csv', 'MOVE_MAP_files.csv']:
    rows.append((f, f'_archive/RESTRUCTURE_20261031-pre/{f}', 'archive', 'O275 재편 완료 · 되돌리기 정본 옆 보관'))

# 충돌 검사
news = [r[1] for r in rows if r[1]]
dup = {n for n in news if news.count(n) > 1}
exist = [n for n in news if os.path.exists(os.path.join(ROOT, n))]
if dup or exist:
    print('CONFLICT', sorted(dup)[:10], exist[:10]); sys.exit(1)

if APPLY:
    for old, new, act, _ in rows:
        src = os.path.join(ROOT, old)
        if act == 'delete':
            os.remove(src); continue
        dst = os.path.join(ROOT, new)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
    # 빈 출발 폴더 정리(파일이 남아 있으면 지우지 않는다)
    for d in [SRC_A, SRC_B, '80_인수인계_프로젝트완료 및 유지보수용', '20_issue', '99_NEXT_SESSION_조각', '40_worklog', 'tmp']:
        top = os.path.join(ROOT, d)
        for dp, dn, fn in sorted(os.walk(top), key=lambda x: -len(x[0])):
            if not os.listdir(dp):
                os.rmdir(dp)

with open(os.path.join(ROOT, ARC, 'CLOSURE_MOVE_MAP.csv'), 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.writer(fh); w.writerow(['old_path', 'new_path', 'action', 'reason']); w.writerows(rows)
from collections import Counter
print('rows', len(rows), Counter(r[2] for r in rows), 'apply' if APPLY else 'dry-run')

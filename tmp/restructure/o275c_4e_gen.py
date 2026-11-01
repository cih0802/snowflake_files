"""O275-C 4-E 생성기 — 상위 폴더 README 7 · _archive 출처 색인 · 50_execution_order 진입점 · tmp 60일 삭제 후보.

🔴 신규 파일만 쓴다(기존 파일이 있으면 건너뛰고 SKIP 출력 · R1-7-1).
🔴 삭제는 하지 않는다 — tmp 후보는 CSV 목록만(별도 승인).
사용: python3 tmp/restructure/o275c_4e_gen.py [--apply]
"""
import csv, io, os, re, sys, time
from collections import Counter, defaultdict

ROOT = '/workspace'
APPLY = '--apply' in sys.argv
TODAY = '2026-11-01'
CUTOFF = time.mktime(time.strptime('2026-09-02', '%Y-%m-%d'))  # 2026-11-01 - 60일
#: 라벨 대체 기준 — O143 = 2026-09-08(지침 R0-8) ⇒ 여유를 두고 O135 이하만 60일 초과로 본다
OMAX = 135
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
files = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
out = {}

GROUPS = {
    '10_design': '설계 — Gold top-down · Silver · 스냅샷 설계 문서',
    '20_build': '구축 — 환경·RBAC · SV/Agent · 적재 파이프라인 · MSTR 이관 · Streamlit · Cortex 프로젝트',
    '30_operate': '운영 — 모니터링 · Agent 개선 · 어카운트 부트스트랩(재현)',
    '40_worklog': '작업기록 — 세션 핸드오프 · 인수인계 정제 작업본',
    '50_handover': '인수인계 — 배포 실행순서 · 후속 프로젝트 · 인계 요청 · 현업요청 인수인계',
    '60_share': '공유 — 산출물 공유본 · 현업 의사결정 회신',
    '70_reference': '참고 — PoC 백업 · 레거시 샘플 · MSTR 스킬 원본 2종',
}
NOTE = {
    '50_handover': [
        '- 🔴 `51`·`52` 번은 비워 둔다 — 납품물 `80_인수인계_프로젝트완료 및 유지보수용/`·`85_실제 인수인계 문서/` 는 **고정 영역**이라 루트에 남았다(O275 사용자 결정).',
        '- `50_execution_order/` = 루트에 흩어져 있던 `문서실행순서*.md` 4종의 집결지 → 진입점 = `50_execution_order/00_README.md`.',
    ],
    '20_build': ['- `22` 번은 결번이다(계획 v2 에서 배정 없음).'],
    '10_design': ['- 🔴 `14_provided_definition` 은 만들지 않았다 — `90_provided_definition/` 은 현업 제공 원본이라 **고정 영역**(O275).'],
}


def readme_name(d):
    for n in ('00_README.md', 'README.md', 'readme.md', '00_INDEX.md', '00_README_N07.md'):
        if os.path.isfile(os.path.join(d, n)):
            return n
    return '(없음)'


def count_files(d):
    n = 0
    for _, dns, fns in os.walk(d):
        dns[:] = [x for x in dns if x != '__pycache__']
        n += len(fns)
    return n


for g, purpose in GROUPS.items():
    gd = os.path.join(ROOT, g)
    rows = []
    for c in sorted(os.listdir(gd)):
        cd = os.path.join(gd, c)
        if not os.path.isdir(cd):
            continue
        olds = [r['old_path'].rstrip('/') for r in summ if r['new_path'].rstrip('/') == f'{g}/{c}' and r['action'] in ('move', 'rename')]
        rows.append(f'| `{c}/` | {" · ".join("`" + o + "/`" for o in olds) or "(신설 · 루트 파일 집결)"} | {count_files(cd)} | `{readme_name(cd)}` |')
    body = [
        '<!-- LLM-METADATA', f'doc_role: 상위 폴더 안내 — {g}', 'created: ' + TODAY, 'created_by: O275-C',
        'related: 00_WORKSPACE_MAP.md · MOVE_MAP.csv', 'END-METADATA -->', '',
        f'# {g} — {purpose.split(" — ")[0]}', '', f'> 목적 = {purpose}.',
        '> 옛 경로 → 새 경로 대조 = 루트 `MOVE_MAP.csv`(요약) · `MOVE_MAP_files.csv`(파일 단위).', '',
        '| 하위 폴더 | 옛 경로(O275 이전) | 파일 수 | 안내 파일 |', '|---|---|---|---|', *rows, '',
    ]
    if g in NOTE:
        body += ['## 참고', '', *NOTE[g], '']
    body += ['- 파일 수 = 생성 시점 실측(`__pycache__` 제외) · 🔴 이 수는 갱신되지 않는다 — 재려면 이 생성기를 다시 돌린다.', '', '_Co-authored with CoCo · O275-C_', '']
    out[f'{gd}/00_README.md'] = '\n'.join(body)

# ── 50_execution_order 진입점 ──
eo = f'{ROOT}/50_handover/50_execution_order'
out[f'{eo}/00_README.md'] = '\n'.join([
    '<!-- LLM-METADATA', 'doc_role: 배포 실행순서 4종 진입점(통합 색인) — 본문은 각 파일이 정본', 'created: ' + TODAY,
    'created_by: O275-C', 'related: 00_WORKSPACE_MAP.md §5 · 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/', 'END-METADATA -->', '',
    '# 50_execution_order — 배포 실행순서 (4종 통합 진입점)', '',
    '> O275 4-C 에서 루트의 `문서실행순서*.md` 4종을 이 폴더로 모았다. 4-E 「통합」은 **본문 병합이 아니라 이 진입점 + `00_WORKSPACE_MAP.md` §5 「작업 흐름」**으로 한다.',
    '> 🔴 본문을 합치지 않은 이유 ㉠ 4종 합계 822줄 · 86 KB = 분할 상한(300줄 AND 40 KB · `R1-6`) 초과',
    '> ㉡ 80 납품 패키지가 `01_실행순서_배포SQL/` 아래에 같은 파일명으로 사본을 두고 `00_INDEX.csv` 로 대조한다 — 파일을 합치거나 이름을 바꾸면 대조가 끊긴다.', '',
    '## 읽는 순서', '',
    '| 순 | 파일 | 역할 | 언제 |', '|---|---|---|---|',
    '| 1 | `문서실행순서.md` | **정본 순서** — 개발계 신규 구축 · 운영계 신규 구축 · 기존 환경 갱신(증분 1~60) | 항상 먼저 |',
    '| 2 | `문서실행순서_보조주석.md` | 단계별 상세 주석 · 덧입히기 절차 · 배포순서 파일 이름 변경표 | 단계의 「왜」가 필요할 때 |',
    '| 3 | `문서실행순서_llm실행.md` | LLM 집행 규칙 — 운영계 금지 · 병렬화 · 실행기 · 알려진 예외 · 확인 쿼리 · 보고 형식 | LLM 이 순서를 집행할 때 |',
    '| 4 | `문서실행순서_운영계_LLM실행카드.md` | 운영계 증분 43~58 단계 카드(저가형 LLM 용) | 운영계 증분 집행 시 |', '',
    '## 🔴 경로 표기 주의', '',
    '- 본문의 SQL 경로는 **O275 이전 이름**이다(`/05_SV-Agent_ai/…` · `/15_MSTR 이관 PoC/snowflake 적용 ddl/…` · `/02_GN_DW_building/…` 등).',
    '  - 워크스페이스에서 실행할 때 = `MOVE_MAP_files.csv` 의 `old_path` 로 새 위치를 찾는다(예: `05_SV-Agent_ai/` → `20_build/23_sv_agent/` · `15_MSTR 이관 PoC/snowflake 적용 ddl/` → `20_build/25_mstr_migration/snowflake_적용_ddl/`).',
    '  - 80 패키지 안에서 실행할 때 = 옛 이름이 **그대로 정답**이다(`01_실행순서_배포SQL/05_SV-Agent_ai/…`).',
    '- 🔴 본문 경로를 일괄 치환하지 마라 — 80 패키지 사본과 어긋난다. 치환 여부는 별도 결정 사항이다(O275-C 인수인계).',
    '- `문서실행순서_운영계_LLM실행카드.md` §2 ④ 의 `ls /workspace/문서실행순서.md` 는 이동 후 실패한다 → 새 위치 = `50_handover/50_execution_order/문서실행순서.md`.', '',
    '_Co-authored with CoCo · O275-C_', ''])

# ── _archive 출처 색인 ──
arc = f'{ROOT}/_archive'
names = sorted(os.listdir(arc))
dirs = [n for n in names if os.path.isdir(os.path.join(arc, n))]
fls = [n for n in names if not os.path.isdir(os.path.join(arc, n))]
LAB = re.compile(r'^(?P<base>.+?\.(?:md|py|sql|json|csv|yml|yaml|html|txt|sh))\.(?P<rest>.+)$')
by_base = Counter(); unmatched = 0
for n in fls:
    m = LAB.match(n)
    if m:
        by_base[m.group('base')] += 1
    else:
        unmatched += 1
locs = defaultdict(list)
for top in ('20_issue', '99_NEXT_SESSION_조각', '00_guides', 'scripts', '.snowflake'):
    for dp, dns, fns in os.walk(f'{ROOT}/{top}'):
        dns[:] = [d for d in dns if d not in ('__pycache__', '_archive', 'golden')]
        for fn in fns:
            locs[fn].append(os.path.relpath(os.path.join(dp, fn), ROOT))
for fn in os.listdir(ROOT):
    if os.path.isfile(os.path.join(ROOT, fn)):
        locs[fn].append(fn)
# 분할 문서는 허브명.md ↔ 조각명-NNN.md 로 스냅샷된다
def where(base):
    if base in locs:
        return ' · '.join('`' + p + '`' for p in locs[base][:2])
    hub = re.sub(r'-\d{3}\.md$', '.md', base)
    if hub != base and hub in locs:
        return '조각 → 허브 ' + '`' + locs[hub][0] + '`'
    return '(현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색)'
top_rows = [f'| `{b}` | {c} | {where(b)} |' for b, c in by_base.most_common(40)]
out[f'{arc}/00_README.md'] = '\n'.join([
    '<!-- LLM-METADATA', 'doc_role: _archive 출처 색인 — 스냅샷 명명 규칙 · 원래 문서 · 보존 정책', 'created: ' + TODAY, 'created_by: O275-C',
    'related: 00_guides/02_파일쓰기_안전규약.md R1-7-10 · scripts/snapshot_util.py', 'END-METADATA -->', '',
    '# _archive — 스냅샷 보관소 출처 색인', '',
    '> 🔴 **고정 영역** — 이동·이름 변경·본문 치환 금지(O275). 이 README 만 신규로 더했다.',
    f'> 생성 시점 실측 = 직속 파일 {len(fls)} · 하위 폴더 {len(dirs)} · 명명 규칙 불일치 {unmatched}. 🔴 수는 갱신되지 않는다.', '',
    '## 1. 명명 규칙', '',
    '- 파일 스냅샷 = `<원본 파일명>.<라벨>-<태그>` (예: `00_INDEX_이슈원장-001.md.O105-final` = 원장 조각 001 · 세션 O105 · 태그 final).',
    '  - 라벨 = `--label` 인자 → `SESSION_LABEL` → `UNLABELED`(`R1-7-10`) · 같은 이름이면 덮지 않고 `.2`·`.3` 접미.',
    '  - 생성 경로 = `scripts/snapshot_util.py` 만(`R1-7-10`) · 그 이전 스냅샷은 손으로 만든 이름이 섞여 있다.',
    '- 폴더 스냅샷 = 일괄 작업 단위 백업(아래 §2).', '',
    '## 2. 하위 폴더', '', '| 폴더 | 출처 |', '|---|---|',
    *[f'| `{d}/` | ' + ({'RESTRUCTURE_20261031-pre': 'O275 재편 백업(4A README · 4B MOVE_MAP v1 · 4C 치환 원본 · residual 정정 원본) — 되돌리기 정본'}.get(d) or f'세션 `{d.split("_")[0]}` 일괄 작업 백업') + ' |' for d in dirs], '',
    '## 3. 원본 문서별 스냅샷 수 (상위 40)', '', '| 원본 파일명 | 스냅샷 수 | 현행 위치 |', '|---|---|---|', *top_rows, '',
    '## 4. 보존 정책', '',
    '- **무기한 보존**(계획 §5 · 사용자 결정 2026-10-31) — 삭제하지 않는다. 되돌리기 수단이다.',
    '- 검색 시 = `ls _archive/ | grep <문서명>` 으로 파일명부터 좁힌다(대용량 · 60초 초과 · `R0-8-3`).',
    '- 각 폴더 아래의 `_archive/`(예: `20_build/23_sv_agent/_archive/`)는 **폴더별 구버전 보관**이다 — 이 색인 범위 밖.', '',
    '_Co-authored with CoCo · O275-C_', ''])

# ── tmp 60일 초과 삭제 후보 ──
corpus = []
for top in ('scripts', '00_guides', '.snowflake', '50_handover/50_execution_order', '99_NEXT_SESSION_조각'):
    for dp, dns, fns in os.walk(f'{ROOT}/{top}'):
        dns[:] = [d for d in dns if d not in ('__pycache__', '_archive', 'golden')]
        for fn in fns:
            if fn.endswith(('.py', '.md', '.sh', '.sql', '.yml', '.yaml')):
                try:
                    corpus.append(io.open(os.path.join(dp, fn), encoding='utf-8').read())
                except (UnicodeDecodeError, OSError):
                    pass
blob = '\n'.join(corpus)
cand = []; total = 0
for dp, dns, fns in os.walk(f'{ROOT}/tmp'):
    rel_dp = os.path.relpath(dp, ROOT)
    if rel_dp.startswith(('tmp/restructure', 'tmp/root_scratch')):
        dns[:] = []
        continue
    for fn in fns:
        total += 1
        p = os.path.join(dp, fn)
        st = os.stat(p)
        rel = os.path.relpath(p, ROOT)
        # 🔴 mtime 은 2026-10-31 00:43 일괄 재기록(마운트·ws ls 둘 다) → 경로 토큰으로 대체 판정
        #   첫 세션 라벨이 판정한다(`o228/bak/…20260714` = O228 산출물 · `_o201b_o18x` = O201) · 라벨이 없을 때만 날짜
        labs = [int(x) for x in re.findall(r'(?i)(?<![a-z0-9])o(\d{2,3})(?!\d)', rel)]
        dm = [d for d in re.findall(r'(?<!\d)(20\d{6})(?!\d)', rel) if d < '20260902'] if not labs else []
        om = labs[:1] if labs and labs[0] <= OMAX else []
        if st.st_mtime < CUTOFF or dm or om:
            basis = 'mtime' if st.st_mtime < CUTOFF else (f'date {dm[0]}' if dm else f'label O{om[0]} (<= O{OMAX})')
            cand.append((rel, basis, st.st_size, 'Y' if rel in blob or rel[4:] in blob else ''))
cand.sort()
csv_path = f'{ROOT}/tmp/restructure/TMP_DELETE_CANDIDATES_O275C.csv'

print('README targets:')
for p, t in out.items():
    print(('SKIP(exists) ' if os.path.exists(p) else 'NEW ') + os.path.relpath(p, ROOT), len(t.splitlines()), 'lines')
print(f'tmp files scanned {total} · candidates {len(cand)} · referenced {sum(1 for c in cand if c[3])} · bytes {sum(c[2] for c in cand)}')
print('archive files', len(fls), 'dirs', len(dirs), 'unmatched', unmatched, 'bases', len(by_base))
if APPLY:
    for p, t in out.items():
        if os.path.exists(p):
            continue
        io.open(p, 'w', encoding='utf-8').write(t)
        assert io.open(p, encoding='utf-8').read() == t
    with open(csv_path, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(['path', 'age_basis', 'bytes', 'referenced_by_current_docs', 'approved_delete'])
        for c in cand:
            w.writerow([*c, ''])
    print('APPLIED')

"""O275 4-B v2 — MOVE_MAP.csv(요약) + MOVE_MAP_files.csv(파일 단위 전수) 생성. 읽기 전용 스캔.

v2 변경(사용자 결정 2026-10-31):
  ㉠ 90_provided_definition = 현업 제공 원본 → 고정 영역(이동·이름 변경·파일 추가 없음)
  ㉡ 고정 영역 외 전부 이동 · 전후 매핑표 = 파일 단위 전수(MOVE_MAP_files.csv)
  ㉢ 파일명 날짜 < 20261001 이고 같은 폴더에 중복(날짜 제거 이름 동일 · 또는 내용 동일)이 있으면 → 같은 폴더 `_archive/`
  ㉣ _archive 행도 매핑표에 기재
참조 건수는 v1 MOVE_MAP.csv 의 reason 에서 승계(전체 텍스트 재스캔 25분 회피).
사용: python3 build_move_map_v2.py <v1_csv> <out_summary> <out_files>
"""
import csv, hashlib, os, re, sys
from collections import defaultdict

ROOT = '/workspace'
V1, OUT, OUT_F = sys.argv[1:4]
CUTOFF = 20261001
FOLDERS = [
    ('70_reference/71_poc_backup', '00_PoC_bak'),
    ('70_reference/72_sample_legacy', '01_project_sample_legacy'),
    ('70_reference/73_skill_mstr_dw_to_ods', 'snowflake-mstr-dw-to-ods'),
    ('70_reference/74_skill_mstr_ods_crm', 'snowflake-mstr-ods-crm'),
    ('60_share/61_output_share', '30_output_share'),
    ('60_share/62_business_decisions', '07_현업의사결정 회신'),
    ('10_design/11_gold_topdown', '03_top-down_gold'),
    ('10_design/12_silver_design', '04_silver_design'),
    ('10_design/13_snapshot_design', '06_snapshot'),
    ('30_operate/31_monitoring', '08_mornitoring'),
    ('30_operate/32_agent_improvement', '12_agent개선과제'),
    ('30_operate/33_account_bootstrap', '60_repeat_어카운트시작'),
    ('50_handover/51_maintenance_package', '80_인수인계_프로젝트완료 및 유지보수용'),
    ('50_handover/52_actual_handover_docs', '85_실제 인수인계 문서'),
    ('50_handover/53_followup_project', '70_후속 프로젝트 인계용'),
    ('50_handover/54_handover_requests', '88_인계요청'),
    ('50_handover/55_business_req_handover', '98_현업요청인수인계'),
    ('40_worklog/41_handoff', '50_handoff'),
    ('40_worklog/42_handover_refinement', '95_작업기록_인수인계정제'),
    ('20_build/21_env_rbac', '02_GN_DW_building'),
    ('20_build/23_sv_agent', '05_SV-Agent_ai'),
    ('20_build/24_daily_load_pipeline', '11_일적재pipeline 구성'),
    ('20_build/25_mstr_migration', '15_MSTR 이관 PoC'),
    ('20_build/26_mstr_medallion', '17_MSTR통한 메달리온 보완'),
    ('20_build/27_streamlit_auth', '09_streamlit 권한 설정'),
    ('20_build/28_cortex_project', 'cortex_project'),
]
SKILL = {'snowflake-mstr-dw-to-ods', 'snowflake-mstr-ods-crm'}
SCR = 'tmp/root_scratch'
EO = '50_handover/50_execution_order'
ROOT_FILES = [
    ('.20261016_GNI잔여작업.md', '40_worklog/41_handoff/.20261016_GNI잔여작업.md', '세션 인수인계 메모'),
    ('95_정식산출물_생성_프롬프트.md', '40_worklog/41_handoff/95_정식산출물_생성_프롬프트.md', '산출물 생성 프롬프트'),
    ('temp_20261014_작업내역 정리.md', '40_worklog/41_handoff/temp_20261014_작업내역_정리.md', '작업내역 메모'),
    ('.brief_run.out', f'{SCR}/.brief_run.out', 'BRIEF 실행 로그 잔재'),
    ('999_temp.txt', f'{SCR}/999_temp.txt', '빈 파일(0B)'),
    ('Untitled.sql', f'{SCR}/Untitled.sql', 'SANDBOX.TOOLS 생성 스크래치'),
    ('Untitled 1.sql', f'{SCR}/Untitled_1.sql', 'Git 시크릿 갱신 스크래치(PAT 자리표시자만)'),
    ('Untitled 2.sql', f'{SCR}/Untitled_2.sql', 'GN_DW 실존 점검 스크래치'),
    ('Untitled 3.sql', f'{SCR}/Untitled_3.sql', 'SELECT 확인 스크래치'),
    ('Untitled 4.sql', f'{SCR}/Untitled_4.sql', '빈 파일(0B)'),
    ('R96쿼리결과.md', f'{SCR}/R96쿼리결과.md', 'R95 실행 결과 메모(착수표 ③ R96 관련 · 🟡 검토)'),
    ('GNI조직도피벗.sql', '10_design/12_silver_design/GNI조직도피벗.sql', '조직 계층 Flat 전개 쿼리(90 은 원본 보존 → 설계 폴더)'),
    ('기준년월 보유 테이블 및 컬럼.md', '10_design/12_silver_design/기준년월_보유_테이블_및_컬럼.md', 'BRONZE 기준년월 인벤토리'),
    ('OPS.sql', '20_build/21_env_rbac/OPS.sql', '운영 스크립트(크레딧·권한·서비스계정)'),
    ('SECURITY.sql', '20_build/21_env_rbac/SECURITY.sql', 'Git 자격증명 시크릿 갱신'),
    ('TEARDOWN.sql', '20_build/21_env_rbac/TEARDOWN.sql', '환경 정리'),
    ('setup_20260702.sql', '20_build/21_env_rbac/setup_20260702.sql', 'SANDBOX 초기 셋업'),
    ('dbt_build.sql', '20_build/21_env_rbac/dbt_build.sql', 'DW_PIPELINE 수동 빌드 SQL(10_dbt_pipeline 고정 영역 회피)'),
    ('PAID_재현_런북_20260722.md', '30_operate/33_account_bootstrap/PAID_재현_런북_20260722.md', '새 계정 재현 순서 정본'),
    ('프로시저 내 email 보내기.sql', '30_operate/31_monitoring/프로시저_내_email_보내기.sql', '프로시저 에러 메일 알림 가이드'),
    ('agent 사용 이력 조회.sql', '30_operate/32_agent_improvement/agent_사용_이력_조회.sql', 'Agent 이력 자료'),
    ('custom tools 롤별 접근 가능성.md', '30_operate/32_agent_improvement/custom_tools_롤별_접근_가능성.md', 'Agent 도구 권한 자료'),
    ('gni_경영지원agent질문답변추출_20261021.csv', '30_operate/32_agent_improvement/gni_경영지원agent질문답변추출_20261021.csv', 'Agent 답변 추출'),
    ('부서별agent답변.md', '30_operate/32_agent_improvement/부서별agent답변.md', 'Agent 답변 자료'),
    ('현업공지용_20261026.md', '60_share/61_output_share/현업공지용_20261026.md', '현업 공유물'),
    ('문서실행순서.md', f'{EO}/문서실행순서.md', '실행순서 4종 집결(4-E 통합 예정)'),
    ('문서실행순서_llm실행.md', f'{EO}/문서실행순서_llm실행.md', '실행순서 4종 집결'),
    ('문서실행순서_보조주석.md', f'{EO}/문서실행순서_보조주석.md', '실행순서 4종 집결'),
    ('문서실행순서_운영계_LLM실행카드.md', f'{EO}/문서실행순서_운영계_LLM실행카드.md', '실행순서 4종 집결'),
]
# 이동은 하되 내부 이름·중복 판정을 하지 않는 하위 영역(원본 백업·분할 게이트·기존 보관소)
FROZEN = re.compile(r'(^|/)(_archive|_backup_[^/]*|[^/]*_조각|__pycache__|target|logs)(/|$)')
DATE = re.compile(r'(?<!\d)(20\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])(?!\d)')

refs = {}
for r in csv.DictReader(open(V1, encoding='utf-8-sig')):
    m = re.search(r'참조 (\d+)건', r['reason'])
    if m:
        refs[r['old_path']] = m.group(1)


def ref(p):
    return f' · 참조 {refs[p]}건' if p in refs else ''


def order(name):
    m = re.match(r'^(\d+)', name)
    return m.group(1) if m else ''


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def stem_key(fn):
    stem, ext = os.path.splitext(fn)
    s = DATE.sub('', stem).lower()
    s = re.sub(r'[\s_\-.()]+', '', s)
    return s + ext.lower()


def conv_rel(rel, keep_all):
    """동결 폴더(FROZEN) 이하와 스킬 내부는 이름 보존 · 그 위 경로만 공백 → `_`."""
    if keep_all or not rel:
        return rel
    out, inside = [], False
    for p in rel.split('/'):
        inside = inside or bool(FROZEN.search(p + '/'))
        out.append(p if inside else p.replace(' ', '_'))
    return '/'.join(out)


summary, files = [], []
stats = defaultdict(int)
for new, old in FOLDERS:
    summary.append((old + '/', new + '/', order(old), 'move', '§4-1 목적별 재편' + ref(old + '/')))
    base = os.path.join(ROOT, old)
    by_dir = defaultdict(list)
    for dp, dns, fns in os.walk(base):
        dns.sort()
        rel = os.path.relpath(dp, base)
        rel = '' if rel == '.' else rel
        for fn in sorted(fns):
            by_dir[rel].append(fn)
    for rel, fns in by_dir.items():
        frozen = bool(FROZEN.search(rel)) or old in SKILL
        nrel = conv_rel(rel, old in SKILL)
        parts = rel.split('/') if rel else []
        if parts and nrel.split('/')[-1] != parts[-1]:
            summary.append((f'{old}/{rel}/', f'{new}/{nrel}/', order(parts[-1]), 'rename', '공백 제거(폴더)'))
        stale = {}
        if not frozen:
            groups = defaultdict(list)
            hashes = defaultdict(list)
            hof = {fn: sha(os.path.join(base, rel, fn)) for fn in fns}
            for fn in fns:
                groups[stem_key(fn)].append(fn)
                hashes[hof[fn]].append(fn)
            for fn in fns:
                m = DATE.search(fn)
                if not m or int(''.join(m.groups())) >= CUTOFF:
                    continue
                sib = [x for x in groups[stem_key(fn)] if x != fn]
                same = [x for x in hashes[hof[fn]] if x != fn]
                if sib or same:
                    stale[fn] = ('이름 중복: ' + sib[0]) if sib else ('내용 동일: ' + same[0])
        for fn in fns:
            o = f'{old}/{rel}/{fn}' if rel else f'{old}/{fn}'
            nfn = fn if frozen else fn.replace(' ', '_')
            ndir = f'{new}/{nrel}' if nrel else new
            if fn in stale:
                n = f'{ndir}/_archive/{nfn}'
                act, why = 'archive', f'날짜<{CUTOFF} 중복 → stale · {stale[fn]}'
                summary.append((o, n, order(fn), act, why))
            elif nfn != fn:
                n, act, why = f'{ndir}/{nfn}', 'rename', '공백 제거'
                summary.append((o, n, order(fn), act, why + ref(o)))
            else:
                n, act, why = f'{ndir}/{nfn}', 'move', '폴더 이동'
            stats[act] += 1
            files.append((o, n, order(fn), act, why))
for old, new, why in ROOT_FILES:
    if os.path.exists(os.path.join(ROOT, old)):
        row = (old, new, order(old), 'move', '루트 산재 정리 · ' + why + ref(old))
        summary.append(row)
        files.append(row)
        stats['root'] += 1

hdr = ['old_path', 'new_path', 'old_order', 'action', 'reason']
for path, rows in ((OUT, summary), (OUT_F, files)):
    with open(path, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(hdr)
        w.writerows(rows)
news = [r[1] for r in files]
print('summary', len(summary), 'files', len(files), dict(stats), 'dup_new', len(news) - len(set(news)))

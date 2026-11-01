"""4-B MOVE_MAP.csv 생성 (읽기 전용 스캔 + CSV 1개 신규 작성).

열 = old_path, new_path, old_order, action(move/rename/archive), reason
행 종류: ① 폴더 이동(§4-1) ② 공백 제거(이동 대상 내부) ③ 루트 파일 ④ 중복·구버전 정리.
reason 에 참조 건수(현행 텍스트 파일 · _archive/tmp 제외)를 적는다.
"""
import csv, os, re, sys

ROOT = '/workspace'
OUT = sys.argv[1]
FOLDERS = [  # new, old
    ('70_reference/71_poc_backup', '00_PoC_bak'),
    ('70_reference/72_sample_legacy', '01_project_sample_legacy'),
    ('70_reference/73_skill_mstr_dw_to_ods', 'snowflake-mstr-dw-to-ods'),
    ('70_reference/74_skill_mstr_ods_crm', 'snowflake-mstr-ods-crm'),
    ('60_share/61_output_share', '30_output_share'),
    ('60_share/62_business_decisions', '07_현업의사결정 회신'),
    ('10_design/11_gold_topdown', '03_top-down_gold'),
    ('10_design/12_silver_design', '04_silver_design'),
    ('10_design/13_snapshot_design', '06_snapshot'),
    ('10_design/14_provided_definition', '90_provided_definition'),
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
SCR = 'tmp/root_scratch'
ROOT_FILES = [  # old, new, reason
    ('.20261016_GNI잔여작업.md', '40_worklog/41_handoff/.20261016_GNI잔여작업.md', '세션 인수인계 메모'),
    ('95_정식산출물_생성_프롬프트.md', '40_worklog/41_handoff/95_정식산출물_생성_프롬프트.md', '산출물 생성 프롬프트(세션 운영)'),
    ('temp_20261014_작업내역 정리.md', '40_worklog/41_handoff/temp_20261014_작업내역_정리.md', '작업내역 메모'),
    ('.brief_run.out', f'{SCR}/.brief_run.out', 'BRIEF 생성 실행 로그 잔재'),
    ('999_temp.txt', f'{SCR}/999_temp.txt', '빈 파일(0B)'),
    ('Untitled.sql', f'{SCR}/Untitled.sql', 'SANDBOX.TOOLS 생성 스크래치'),
    ('Untitled 1.sql', f'{SCR}/Untitled_1.sql', 'Git 시크릿 갱신 스크래치(PAT 자리표시자만 · 실값 없음)'),
    ('Untitled 2.sql', f'{SCR}/Untitled_2.sql', 'GN_DW 실존 점검 스크래치'),
    ('Untitled 3.sql', f'{SCR}/Untitled_3.sql', 'SELECT 확인 스크래치'),
    ('Untitled 4.sql', f'{SCR}/Untitled_4.sql', '빈 파일(0B)'),
    ('R96쿼리결과.md', f'{SCR}/R96쿼리결과.md', 'Untitled 4.sql(R95) 실행 결과 메모 · 🟡 근거로 남길지 검토'),
    ('GNI조직도피벗.sql', '10_design/14_provided_definition/GNI조직도피벗.sql', '조직 계층 Flat 전개 쿼리(조직도 csv 와 동거)'),
    ('기준년월 보유 테이블 및 컬럼.md', '10_design/12_silver_design/기준년월_보유_테이블_및_컬럼.md', 'BRONZE 기준년월 인벤토리(SILVER 설계 입력)'),
    ('OPS.sql', '20_build/21_env_rbac/OPS.sql', '운영 스크립트(크레딧·권한·서비스계정)'),
    ('SECURITY.sql', '20_build/21_env_rbac/SECURITY.sql', 'Git 자격증명 시크릿 갱신'),
    ('TEARDOWN.sql', '20_build/21_env_rbac/TEARDOWN.sql', '환경 정리'),
    ('setup_20260702.sql', '20_build/21_env_rbac/setup_20260702.sql', 'SANDBOX 초기 셋업'),
    ('dbt_build.sql', '20_build/21_env_rbac/dbt_build.sql', 'DW_PIPELINE 수동 빌드 SQL · 10_dbt_pipeline(배포 소스·고정 영역) 회피'),
    ('PAID_재현_런북_20260722.md', '30_operate/33_account_bootstrap/PAID_재현_런북_20260722.md', '새 계정 재현 순서 정본'),
    ('프로시저 내 email 보내기.sql', '30_operate/31_monitoring/프로시저_내_email_보내기.sql', '프로시저 에러 메일 알림 가이드'),
    ('agent 사용 이력 조회.sql', '30_operate/32_agent_improvement/agent_사용_이력_조회.sql', 'Agent 이력 자료'),
    ('custom tools 롤별 접근 가능성.md', '30_operate/32_agent_improvement/custom_tools_롤별_접근_가능성.md', 'Agent 도구 권한 자료'),
    ('gni_경영지원agent질문답변추출_20261021.csv', '30_operate/32_agent_improvement/gni_경영지원agent질문답변추출_20261021.csv', 'Agent 답변 추출'),
    ('부서별agent답변.md', '30_operate/32_agent_improvement/부서별agent답변.md', 'Agent 답변 자료'),
    ('현업공지용_20261026.md', '60_share/61_output_share/현업공지용_20261026.md', '현업 공유물'),
    ('문서실행순서.md', '50_handover/50_execution_order/문서실행순서.md', '실행순서 4종 집결 · 4-E 에서 WORKSPACE_MAP 「작업 흐름」으로 통합'),
    ('문서실행순서_llm실행.md', '50_handover/50_execution_order/문서실행순서_llm실행.md', '〃'),
    ('문서실행순서_보조주석.md', '50_handover/50_execution_order/문서실행순서_보조주석.md', '〃'),
    ('문서실행순서_운영계_LLM실행카드.md', '50_handover/50_execution_order/문서실행순서_운영계_LLM실행카드.md', '〃'),
]
ARCHIVE = [  # old(재편 전 경로), reason
    ('90_provided_definition/조직도_20260914.csv', '내용 동일(SHA256): gni_실적부서.csv'),
    ('30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v1.docx', '이전판(v3 존재)'),
    ('30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v2.docx', '이전판(v3 존재)'),
]
SKIP_SPACE = re.compile(r'(^|/)(_archive|_backup_[^/]*|[^/]*_조각|__pycache__|target|logs)(/|$)')
SKILL_INNER = ('snowflake-mstr-dw-to-ods/', 'snowflake-mstr-ods-crm/')

# 참조 건수 스캔 (현행 텍스트만)
TEXT_EXT = ('.md', '.py', '.sql', '.yml', '.yaml', '.txt', '.json', '.csv')
corpus = []
for dp, dns, fns in os.walk(ROOT):
    rel = os.path.relpath(dp, ROOT)
    dns[:] = [d for d in dns if not (rel == '.' and d in ('_archive', 'tmp')) and d not in ('__pycache__', 'target')]
    for fn in fns:
        if fn.endswith(TEXT_EXT):
            try:
                corpus.append(open(os.path.join(dp, fn), encoding='utf-8', errors='ignore').read())
            except OSError:
                pass


def refs(s):
    return sum(1 for t in corpus if s in t)


def order(name):
    m = re.match(r'^(\d+)', name)
    return m.group(1) if m else ''


rows = []
for new, old in FOLDERS:
    rows.append((old + '/', new + '/', order(old), 'move', f'§4-1 목적별 재편 · 참조 {refs(old)}건'))
    base = os.path.join(ROOT, old)
    if any(old.startswith(s.rstrip('/')) for s in SKILL_INNER):
        continue  # 스킬 내부 이름은 보존
    for dp, dns, fns in os.walk(base):
        rel = os.path.relpath(dp, base)
        rel = '' if rel == '.' else rel
        keep = []
        for d in dns:
            r = f'{rel}/{d}'.lstrip('/')
            if SKIP_SPACE.search(r):
                continue
            keep.append(d)
            if ' ' in d:
                rows.append((f'{old}/{r}/', f'{new}/{r.replace(" ", "_")}/', order(d), 'rename', '공백 제거(폴더)'))
        dns[:] = keep
        for fn in fns:
            if ' ' in fn:
                r = f'{rel}/{fn}'.lstrip('/')
                rows.append((f'{old}/{r}', f'{new}/{r.replace(" ", "_")}', order(fn), 'rename',
                             f'공백 제거 · 참조 {refs(fn)}건'))
for old, new, why in ROOT_FILES:
    if os.path.exists(os.path.join(ROOT, old)):
        rows.append((old, new, order(old), 'move', f'루트 산재 정리 · {why} · 참조 {refs(old)}건'))
for old, why in ARCHIVE:
    folder, fn = old.rsplit('/', 1)
    newf = dict((o, n) for n, o in FOLDERS)[folder]
    rows.append((old, f'{newf}/_archive/{fn}', order(fn), 'archive', why))

with open(OUT, 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh)
    w.writerow(['old_path', 'new_path', 'old_order', 'action', 'reason'])
    w.writerows(rows)
from collections import Counter
print(len(rows), Counter(r[3] for r in rows))

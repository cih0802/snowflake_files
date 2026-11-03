# O276 2단계 — 재사용 키트 추출(복사 + 해시 대조 + INVENTORY + 고유어 잔존 스캔) · 원본 무변경
import io, os, re, shutil, hashlib, glob

ROOT = '/workspace'
KIT = os.path.join(ROOT, '_reuse_kit')
S = 'scripts/'


def tests(*names):
    out = []
    for n in names:
        out += sorted(glob.glob(os.path.join(ROOT, S, 'test_%s*.py' % n)))
    return [os.path.relpath(p, ROOT) for p in out]


SESSION = ['session_brief', 'doc_census', 'doc_line_length_gate', 'doc_heading_gate', 'doc_coord_gate',
           'doc_type_gate', 'decision_closure_gate', 'split_doc', 'retire_sections', 'retire_rows',
           'handoff_ddl_gate', 'handoff_write', 'line_len', 'snapshot_util', 'snapshot_cli',
           'id_collision_gate', 'clause_order_gate', 'index_row_gate', 'stage_mount_size_gate',
           'gate_census', 'new_tool', 'mutating_guard', 'classify_doc_type', 'build_folder_index',
           'split_narrative', 'split_issue_index', 'wrap_for_read', 'ws_stage_verify', 'fix_stale_counts']
OPS = ['sfconn', 'run_sql_file', 'run_sql_block', 'sv_no_rollup_gate', 'sv_common_block_gate',
       'sv_code_label_gate', 'sv_enum_newvalue_gate', 'sv_identifier_gate', 'sv_unit_gate', 'sv_rule7_scan',
       'dbt_schema_lint', 'jinja_config_gate', 'comment_drift_gate', 'env_capture', 'live_change_gate',
       'rbac_source_gate', 'null_reason_registry_gate', 'table_ddl_column_gate']
GEN = ['a2_matrix_build', 'b_struct_build', 'n03_catalog_build', 'n05_report_build']


def py(names):
    return [S + n + '.py' for n in names] + tests(*names)


def tree(d, exts=None):
    out = []
    for dp, dn, fn in os.walk(os.path.join(ROOT, d)):
        dn[:] = [x for x in dn if x not in ('__pycache__', '_archive')]
        for f in fn:
            if f.endswith('.pyc') or (exts and not f.endswith(exts)):
                continue
            out.append(os.path.relpath(os.path.join(dp, f), ROOT))
    return sorted(out)


G = '00_guides/'
H = '85_실제 인수인계 문서/'
PLAN = {
    '01_agent_rules': [G + '00_작업지침_세션운영규칙.md', G + '01_문서분할_규약.md', G + '02_파일쓰기_안전규약.md',
                       G + '04_단계종료_게이트.md'] + tree(G + '01_문서분할_규약_조각'),
    '02_skill_init': [G + '03_init_ihcho_스킬_본문.md', G + '03_init_ihcho_스킬_정본.md',
                      G + '03_init_ihcho_스킬_참조_세션종료.md', G + '03_init_ihcho_스킬_개발이력.md',
                      S + 'build_init_ihcho_skill.py', S + 'verify_init_ihcho_skill.py']
                     + tree('.snowflake/cortex/skills/init_ihcho'),
    '03_session_tools': py(SESSION) + [S + 'optional_gates.sh'],
    '04_methodology': [G + '01_데이터설계 업무단계 방법론_킴볼 일반론.md', G + '02_모던 엔터프라이즈 데이터 아키텍처 설계 가이드.md',
                       G + '04_YAGNI_원천중심_과잉모델링_방지_원칙.md', G + 'MFA 로 인한 로그인 방법 가이드.md',
                       G + '로그인 인증 Authentication 설정을 위한 준비_Account Admin.sql'],
    '05_build_skeleton': tree('50_handover/53_followup_project'),
    '06_dbt_macros': ['10_dbt_pipeline/macros/' + m for m in
                      ('generate_schema_name.sql', 'gn_no_structural_alter.sql', 'gn_view_commented.sql',
                       'gold_fact_purge.sql', 'silver_purge.sql', 'gold_helpers.sql', 'silver_helpers.sql')],
    '07_ops_tools': py(OPS) + [S + 'README_운영도구.md'],
    '08_handover_templates': [H + '00_INDEX_산출물목록.md', H + '00_작업계획서.md']
                             + tree(H + '20_정식산출물', ('.md',)) + py(GEN),
    '09_skill_mstr': tree('.snowflake/cortex/skills/mstr-migration') + tree('70_reference/73_skill_mstr_dw_to_ods')
                     + tree('70_reference/74_skill_mstr_ods_crm'),
    '10_streamlit': tree('20_build/27_streamlit_auth'),
}

RESID = [('GN_DW', re.compile(r'GN_DW')), ('굿네이버스', re.compile(r'굿네이버스')),
         ('계정로케이터', re.compile(r'(?i)\b(?:tq68205|zl50263|xh20001|sr61467)\b')),
         ('세션라벨', re.compile(r'\bO\d{2,3}(?:-[A-Z])?\b'))]


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


rows, missing = [], []
for grp, files in PLAN.items():
    seen = set()
    for f in files:
        src = os.path.join(ROOT, f)
        if f in seen:
            continue
        seen.add(f)
        if not os.path.isfile(src):
            missing.append((grp, f))
            continue
        # 키트 경로 = 그룹/원본의 그룹 기준 상대 경로(스킬·조각 폴더는 하위 구조 유지)
        rel = f
        for pre in ('.snowflake/cortex/skills/', '70_reference/', '50_handover/', H + '20_정식산출물/', H,
                    '10_dbt_pipeline/macros/', '20_build/', G, S):
            if f.startswith(pre):
                rel = f[len(pre):]
                break
        dst = os.path.join(KIT, grp, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):  # 🔴 기존 사본은 덮지 않는다(일반화 편집 보존)
            shutil.copyfile(src, dst)
        h1, h2 = sha(src), sha(dst)
        txt = io.open(dst, encoding='utf-8', errors='replace').read() if dst.endswith(
            ('.md', '.py', '.sql', '.sh', '.yml', '.yaml', '.txt', '.csv')) else ''
        res = {k: len(rx.findall(txt)) for k, rx in RESID}
        rows.append((grp, f, os.path.relpath(dst, KIT), h1 == h2, res))

L = ['<!-- LLM-METADATA', 'doc_id: REUSE_KIT_INVENTORY',
     'doc_role: 재사용 키트 목록 — 원본 경로 · 키트 경로 · 해시 대조 · 고유어 잔존(일반화 대상)',
     'created: 2026-11-02', 'created_by: O276-C (00_REFERENCE_CLEANUP_PLAN.md §8)', 'END-METADATA -->', '',
     '# 재사용 키트 목록 (_reuse_kit)', '',
     '> 원본은 무변경이다. 이 폴더는 **복사본**이며 일반화 편집은 여기서만 한다.',
     '> 잔존 열 = 키트 사본 안의 고유어 출현 횟수(GN_DW · 굿네이버스 · 계정로케이터 · 세션라벨 `O##`) — 0 이 될 때까지 일반화 대상이다.', '',
     '## 1. 요약', '', '| 그룹 | 파일 | 해시 일치 | GN_DW | 굿네이버스 | 계정 | 라벨 |', '|---|---|---|---|---|---|---|']
for grp in PLAN:
    g = [r for r in rows if r[0] == grp]
    s = lambda k: sum(r[4][k] for r in g)
    L.append('| `%s` | %d | %d/%d | %d | %d | %d | %d |' % (grp, len(g), sum(r[3] for r in g), len(g),
             s('GN_DW'), s('굿네이버스'), s('계정로케이터'), s('세션라벨')))
L += ['', '- 원본 부재(목록에서 제외) = %d건' % len(missing)] + ['  - `%s` · `%s`' % m for m in missing]
L += ['', '## 2. 파일별', '', '| 그룹 | 키트 경로 | 원본 | 해시 | GN_DW | 굿네이버스 | 계정 | 라벨 |',
      '|---|---|---|---|---|---|---|---|']
for grp, f, k, ok, res in rows:
    L.append('| %s | `%s` | `%s` | %s | %d | %d | %d | %d |' % (grp, k, f, 'OK' if ok else 'FAIL', res['GN_DW'],
             res['굿네이버스'], res['계정로케이터'], res['세션라벨']))
io.open(os.path.join(KIT, '00_INVENTORY.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print('copied', len(rows), 'hash_fail', sum(not r[3] for r in rows), 'missing', len(missing))

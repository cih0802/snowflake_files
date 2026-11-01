"""4-A 조사: 재편 대상 폴더 직속 파일 메타 + 판정 후보 산출 (읽기 전용)."""
import hashlib, json, os, re, sys

ROOT = '/workspace'
TARGETS = [
    '03_top-down_gold', '04_silver_design', '06_snapshot', '90_provided_definition',
    '02_GN_DW_building', '05_SV-Agent_ai', '11_일적재pipeline 구성', '15_MSTR 이관 PoC',
    '17_MSTR통한 메달리온 보완', '09_streamlit 권한 설정', 'cortex_project', '08_mornitoring',
    '12_agent개선과제', '60_repeat_어카운트시작', '50_handoff', '95_작업기록_인수인계정제',
    '80_인수인계_프로젝트완료 및 유지보수용', '85_실제 인수인계 문서', '70_후속 프로젝트 인계용',
    '88_인계요청', '98_현업요청인수인계', '30_output_share', '07_현업의사결정 회신',
    '00_PoC_bak', '01_project_sample_legacy', 'snowflake-mstr-dw-to-ods', 'snowflake-mstr-ods-crm',
]
TEXT = ('.md', '.sql', '.py', '.yml', '.yaml', '.txt', '.csv', '.json')
README_NAMES = {'00_README.md', 'README.md', 'readme.md', '00_INDEX.md', '00_README_N07.md',
                '00_INDEX.csv', '00_INDEX_산출물목록.md'}


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def norm(name):
    s = os.path.splitext(name)[0].lower()
    s = re.sub(r'^\d+(_\d+)*[_\s-]*', '', s)          # 번호 접두
    s = re.sub(r'[_\s-]*(20\d{6}|v\d+|bak|backup|old|copy|\(\d\))$', '', s)
    s = re.sub(r'[\s_\-]+', '', s)
    return s


def head(p, n=12):
    try:
        with open(p, encoding='utf-8', errors='replace') as f:
            return [next(f).rstrip('\n')[:200] for _ in range(n)]
    except StopIteration:
        return []
    except Exception as e:
        return [f'<err {e}>']


out = {}
for t in TARGETS:
    d = os.path.join(ROOT, t)
    if not os.path.isdir(d):
        out[t] = {'missing': True}
        continue
    files, subdirs = [], []
    for e in sorted(os.listdir(d)):
        p = os.path.join(d, e)
        if os.path.isdir(p):
            n = sum(len(fs) for _, _, fs in os.walk(p))
            subdirs.append({'name': e, 'files': n})
            continue
        st = os.stat(p)
        rec = {'name': e, 'size': st.st_size, 'sha': sha(p), 'norm': norm(e)}
        if e.endswith(TEXT) and e not in README_NAMES:
            rec['head'] = head(p)
        files.append(rec)
    out[t] = {'files': files, 'subdirs': subdirs,
              'readmes': [f['name'] for f in files if f['name'] in README_NAMES]}

json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
print({t: (len(v.get('files', [])), len(v.get('subdirs', []))) for t, v in out.items()})

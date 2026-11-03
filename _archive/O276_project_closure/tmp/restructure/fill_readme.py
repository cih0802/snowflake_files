"""4-A README 채움 — 신규 README: 목적·상태 기입 / 기존 README: 누락 파일 보완 절 append.

안전(02_파일쓰기_안전규약): 2회 읽기 해시 일치 확인 · 스냅샷(snapshot_util) 선행 ·
신규 README 는 줄 수 불변 검증 · 기존 README 는 원본 바이트가 접두로 보존되는지 검증.
사용: python3 fill_readme.py [--apply]
"""
import hashlib, json, os, re, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
ARCH = os.path.join(ROOT, '_archive', 'RESTRUCTURE_20261031-pre', '4A')
LABEL = 'RESTRUCTURE-4A'
APPLY = '--apply' in sys.argv
V = json.load(open(os.path.join(ROOT, 'tmp/restructure/verdict.json')))

PURPOSE = {
    '06_snapshot': '월말 스냅샷(시점 고정) 계층의 아키텍처·네이밍 규칙, 구축 계획, 환경 구축·검증 SQL.',
    '07_현업의사결정 회신': '현업 의사결정 요청 과제(문서 20)에 대한 현업 회신 원문 보관.',
    '09_streamlit 권한 설정': 'Analyst 셀프서비스 Streamlit 의 설계와 권한 적용 런북.',
    '11_일적재pipeline 구성': 'BRONZE_CRM_2 → SILVER_2/GOLD_2 일배치 테스트 파이프라인(스키마 복제·권한·TASK·LOADER 임시권한).',
    '15_MSTR 이관 PoC': 'MSTR(구 SQL Server mart) 리포트 1차 이관 PoC — 작업계획, 원본/적용 DDL, 답안 대조, 스킬 검증. 하위 `tools/` 는 이관 도구.',
    '17_MSTR통한 메달리온 보완': 'MSTR SP 로직을 근거로 SILVER/GOLD(메달리온) 규칙을 보완하는 작업계획·SP 인벤토리·규칙카드.',
    '50_handoff': '1차 인계 묶음 — 계정 간 데이터 마이그레이션(A→B→C) SQL·문서, ETL/GOLD 개발 전달노트, IT팀 전달 인덱스, 예산 가이드.',
    '88_인계요청': '인수인계 자료 추가 전달 요청서와, 요청에 따라 모은 자료 사본(하위 폴더 = 원래 위치 이름).',
    '95_작업기록_인수인계정제': '80·85 인수인계 산출물 정제 작업의 계획·진행로그·분류표, 정제 전 원본 백업(`_backup_*`), 정제 도구(`tools/`).',
    '98_현업요청인수인계': '현업 요청사항 인수인계 목록(md/csv/xlsx 병행)과 현업 회신 문서.',
    'cortex_project': 'Cortex Agent 프로젝트 정의(`cortex-project.yaml`)와 Agent 스펙(`agents/`) · 이전 스펙·평가 결과(`_archive/`).',
    'snowflake-mstr-dw-to-ods': 'MSTR DW→ODS 이관 스킬 원본(참고용 사본). 스킬 내부는 손대지 않는다.',
    '12_agent개선과제': 'Agent 답변 품질 개선 회차별(O202~O273) 작업계획·스펙·SQL·현업 회신·운영계 프롬프트. `output/` = 측정 산출물, `tools/` = 패치·측정 도구.',
    '30_output_share': '현업·IT 공유 산출물 — 활용가이드, 스키마 인벤토리, 계보/지표 매핑, 감사·측정 결과, 현업 회신, ERD. `_ENV/` 환경별 판본, `_archive/` 회전 판본.',
}
# 이름 패턴 보정(규칙 판정 위에 덮어씀)
OVERRIDE = [
    (re.compile(r'(착수프롬프트|작업프롬프트|LLM_프롬프트)'), '참고', '지난 회차 세션 프롬프트(이력)'),
    (re.compile(r'백업_'), '참고', '변경 전 백업본(롤백용)'),
    (re.compile(r'^20261028_강지영'), '정본', '현업 회신'),
]
LEGEND = ('상태: 정본=현행 기준 문서 · 참고=근거/이력/롤백본 · 중복=내용 동일 사본 · '
          '구버전=최신판 존재 · 임시=측정/프로브 잔재 · 안내=README (4-A 판정 2026-10-31)')
EXISTING = {  # 기존 README 보유 폴더 → 안내 파일명
    '01_project_sample_legacy': 'README.md', '02_GN_DW_building': '00_INDEX.md',
    '03_top-down_gold': '00_README.md', '04_silver_design': '00_README.md',
    '04_silver_design/_archive': 'README.md', '05_SV-Agent_ai': '00_README.md',
    '08_mornitoring': '00_README.md', '15_MSTR 이관 PoC/tools': 'README.md',
    '60_repeat_어카운트시작': 'readme.md', '70_후속 프로젝트 인계용': '00_README_N07.md',
    '90_provided_definition': '00_README.md', 'cortex_project/_archive': '00_README.md',
    '12_agent개선과제': '00_README.md',  # 대용량 요약 양식 → 파일별 판정표 덧붙임
}
APPEND_HDR = '## 보완 — README 미기재 파일 (4-A 판정 · 2026-10-31)'


def stable_read(p):
    a = open(p, 'rb').read()
    b = open(p, 'rb').read()
    if hashlib.sha256(a).digest() != hashlib.sha256(b).digest():
        raise SystemExit(f'해시 불안정 — 중단: {p}')
    return a


def verdict_of(folder, name):
    st, why = '정본', '-'
    for r in V.get(folder, {}).get('rows', []):
        if r['name'] == name:
            st, why = r['status'], r['why']
    for rx, s, w in OVERRIDE:
        if rx.search(name):
            st, why = s, w
    if folder not in V:  # 하위 폴더(조사 범위 밖) — 이름 기반 최소 판정
        if re.search(r'(\.O\d+|before|BAK|_v\d+)', name):
            st, why = '구버전', '이름 패턴(이전판/백업)'
        elif name.endswith('.eval.yaml'):
            st, why = '참고', '평가 실행 결과'
    return st, why


def snap(p, folder):
    nm = folder.replace('/', '__').replace(' ', '_') + '__' + os.path.basename(p) + f'.{LABEL}-pre'
    os.makedirs(ARCH, exist_ok=True)
    return snapshot(p, 'pre', label=LABEL, archive=ARCH, name=nm, quiet=True)


def fill_new(folder):
    p = os.path.join(ROOT, folder, '00_README.md')
    raw = stable_read(p)
    lines = raw.decode('utf-8').split('\n')
    cnt = 0
    for i, ln in enumerate(lines):
        if ln == '- (작성 필요)' and folder in PURPOSE:
            lines[i] = '- ' + PURPOSE[folder]; cnt += 1
        m = re.match(r'^\| `([^`]+)` \| ([^|]*) \| ([^|]*) \| - \| (.*) \|$', ln)
        if m:
            st, why = verdict_of(folder, m.group(1))
            summ = m.group(4) if why == '-' else f'{m.group(4)} · _{why}_'
            lines[i] = f'| `{m.group(1)}` | {m.group(2)} | {m.group(3)} | {st} | {summ} |'; cnt += 1
        if ln.startswith('상태: 보관=_archive'):
            lines[i] = LEGEND; cnt += 1
    new = '\n'.join(lines).encode('utf-8')
    assert new.count(b'\n') == raw.count(b'\n'), '줄 수 변동'
    return p, raw, new, cnt


def fill_existing(folder, readme):
    d = os.path.join(ROOT, folder)
    p = os.path.join(d, readme)
    raw = stable_read(p)
    text = raw.decode('utf-8')
    if APPEND_HDR in text:
        return p, raw, raw, 0
    miss = [e for e in sorted(os.listdir(d))
            if os.path.isfile(os.path.join(d, e)) and e != readme and e not in text]
    if not miss:
        return p, raw, raw, 0
    rows = ['', '', APPEND_HDR, '',
            '> 기존 본문은 수정하지 않고 아래에 덧붙였습니다. 상태 기준은 루트 `00_WORKSPACE_RESTRUCTURE_PLAN.md` §4-A.', '',
            '| 파일 | 크기 | 상태 | 비고 |', '|---|---|---|---|']
    for e in miss:
        st, why = verdict_of(folder, e)
        kb = max(1, round(os.path.getsize(os.path.join(d, e)) / 1024))
        rows.append(f'| `{e}` | {kb}KB | {st} | {why} |')
    add = ('\n'.join(rows) + '\n').encode('utf-8')
    sep = b'' if raw.endswith(b'\n') else b'\n'
    new = raw + sep + add
    assert new.startswith(raw)
    return p, raw, new, len(miss)


jobs = [(f, fill_new) for f in PURPOSE] + [(f, lambda x, r=r: fill_existing(x, r)) for f, r in EXISTING.items()]
for folder, fn in jobs:
    p, raw, new, cnt = fn(folder)
    print(f'{"APPLY" if APPLY else "DRY"}\t{cnt}\t{folder}')
    if APPLY and new != raw:
        snap(p, folder)
        with open(p, 'wb') as fh:
            fh.write(new)
        assert stable_read(p) == new, f'쓰기 후 불일치: {p}'

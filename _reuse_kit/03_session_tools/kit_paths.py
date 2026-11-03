#!/usr/bin/env python3
"""재사용 키트 경로 설정 — 모든 세션 운영 도구·운영 도구가 루트를 여기서 받는다(설정 1곳).

설치 규약 = 이 파일과 도구(.py)를 새 프로젝트의 `<루트>/scripts/` 에 둔다.
  ROOT = 환경변수 `KIT_ROOT` 가 있으면 그 값 · 없으면 이 파일 폴더의 상위(= `<루트>`).

폴더 이름은 **관례 레이아웃**이다(아래 상수가 정본). 다른 이름을 쓰려면 이 표를 고치고
`python3 scripts/kit_paths.py --check` 로 실재를 확인한다.
🔴 도구 본문의 문자열·정규식·안내문에 같은 폴더 이름이 남아 있다 — 이름을 바꾸면
   `grep -rn '<옛 이름>' scripts/` 로 함께 치환해야 한다(이 파일만 바꾸면 반쪽이다).
"""
import os
import sys

ROOT = os.environ.get('KIT_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 관례 레이아웃(루트 기준 상대 경로) — 세션 운영 장치가 읽는 위치
# 🆕 [O277] 프로젝트 관리물(원장·결정·이력·인수인계·작업기록)은 PC_DIR 한 폴더에 모은다
#   ⇒ 프로젝트 종료 = 이 폴더 하나를 `_archive/` 로 옮기면 끝난다(표준 번호표 = 11_project_template/00_표준_폴더번호표.md).
PC_DIR = '01_project_control'          # 프로젝트 관리(전 단계 공통)
ISSUE_DIR = PC_DIR                     # 이슈 원장 · BRIEF · 사고사례집
ISSUE_INDEX = PC_DIR + '/00_INDEX_이슈원장.md'
NEXT_FILE = PC_DIR + '/99_NEXT_SESSION.md'   # 착수표(인수인계 허브)
NEXT_DIR = PC_DIR + '/99_NEXT_SESSION_조각'  # 인수인계 라벨 파일
GUIDES_DIR = '00_guides'               # 작업 지침 · 규약 · 스킬 정본
SCRIPTS_DIR = 'scripts'                # 게이트 · 도구 · 골든
ARCHIVE_DIR = '_archive'               # 스냅샷 보관소(snapshot_util)
WORKLOG_DIR = PC_DIR + '/98_worklog'   # (선택) 세션 작업기록 · handoff_ddl_gate 대상
DBT_DIR = '10_dbt_pipeline'            # (선택) dbt 프로젝트
SKILL_DIR = '.snowflake/cortex/skills/init_ihcho'
SV_DIR = '20_build/23_sv_agent'        # (선택) SV DDL 정본 — SV 게이트의 전제

REQUIRED = [PC_DIR, ISSUE_INDEX, NEXT_FILE, NEXT_DIR, GUIDES_DIR, SCRIPTS_DIR, ARCHIVE_DIR]
OPTIONAL = [WORKLOG_DIR, DBT_DIR, SKILL_DIR, SV_DIR]

#: 게이트 이름 접두 → 전제 경로. 전제가 없으면 브리핑이 그 게이트를 **⚪ 전제 부재(건너뜀)** 로 표시한다
#: (🔴 FAIL 도 🟢 PASS 도 아니다 — 대상이 생기면 자동으로 판정에 들어온다).
GATE_REQUIRES = [('sv_', SV_DIR), ('agent_', SV_DIR), ('eval_', SV_DIR), ('campaign_', SV_DIR),
                 ('jinja_config_gate', DBT_DIR), ('dbt_', DBT_DIR), ('handoff_ddl_gate', WORKLOG_DIR)]


def gate_prereq(name):
    """게이트 이름의 전제 경로 중 **없는 것**을 돌려준다(없으면 None)."""
    for pre, rel in GATE_REQUIRES:
        if name.startswith(pre) and not os.path.exists(path(rel)):
            return rel
    return None


def path(*parts):
    return os.path.join(ROOT, *parts)


def check():
    print('ROOT = %s%s' % (ROOT, '  (KIT_ROOT)' if os.environ.get('KIT_ROOT') else ''))
    miss = 0
    for rel in REQUIRED + OPTIONAL:
        ok = os.path.exists(path(rel))
        req = rel in REQUIRED
        miss += (not ok) and req
        print('  %s %-40s %s' % ('🟢' if ok else ('🔴' if req else '⚪'), rel, '필수' if req else '선택'))
    print('판정 = %s' % ('PASS' if not miss else 'FAIL · 필수 부재 %d' % miss))
    return 1 if miss else 0


if __name__ == '__main__':
    sys.exit(check() if '--check' in sys.argv else (print(ROOT) or 0))

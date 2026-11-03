# O277 — 키트(_reuse_kit) → 빈 프로젝트 루트 조립 (00_README §1 배치 규약 재현)
# 사용: python3 o277_kit_assemble.py <kit 경로> <새 루트 경로>   (새 루트는 지우고 다시 만든다)
# 이어서: KIT_ROOT=<루트> python3 o276_kit_selftest.py <루트> <결과.tsv>
import glob
import os
import shutil
import sys

kit, root = sys.argv[1:3]
if os.path.exists(root):
    shutil.rmtree(root)


def cp(src, dst):
    for p in glob.glob(os.path.join(kit, src)):
        d = os.path.join(root, dst, os.path.basename(p))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        (shutil.copytree if os.path.isdir(p) else shutil.copy2)(p, d)


cp('01_agent_rules/*', '00_guides')
cp('04_methodology/*', '00_guides')
cp('02_skill_init/*.md', '00_guides')
cp('02_skill_init/*.py', 'scripts')
cp('03_session_tools/*', 'scripts')
cp('07_ops_tools/*', 'scripts')
cp('08_handover_templates/*.py', 'scripts')  # 생성기 — gate_census 등재표가 scripts/ 에서 찾는다
cp('02_skill_init/init_ihcho', '.snowflake/cortex/skills')
tpl = os.path.join(kit, '11_project_template')
for n in os.listdir(tpl):
    if n.startswith('00_표준'):
        continue  # 참고 문서 — 루트에 두지 않는다
    s, d = os.path.join(tpl, n), os.path.join(root, n)
    (shutil.copytree if os.path.isdir(s) else shutil.copy2)(s, d)
os.makedirs(os.path.join(root, '_archive'), exist_ok=True)
print('assembled', root)

# O276 2단계-6 — 키트 gate_census 등재표를 키트 스크립트 집합으로 정리(유령 제거 · 미분류 등재) · 기본 dry-run
import ast, io, os, sys

KIT = '/workspace/_reuse_kit'
P = os.path.join(KIT, '03_session_tools', 'gate_census.py')
# 설치 후 scripts/ 에 함께 놓이는 키트 도구 집합(README §1)
DIRS = ['02_skill_init', '03_session_tools', '07_ops_tools', '08_handover_templates']
have = {f[:-3] for d in DIRS for f in os.listdir(os.path.join(KIT, d)) if f.endswith('.py')}
ADD = {'LIB': ("    'kit_paths': '키트 경로 설정 단일 정본(ROOT · 관례 레이아웃 · `--check`)',\n"),
       'MUTATES': ("    'build_folder_index': '폴더별 `00_FOLDER_INDEX.md` 일괄 재생성(다중 파일 재작성 · `R4-4-3`)',\n")}
BUCK = ('JUDGE', 'OBSERVE', 'NEEDS_ARGS', 'GEN', 'MUTATES', 'LIB')
src = io.open(P, encoding='utf-8').read()
lines = src.splitlines(keepends=True)
off = [0]
for l in lines:
    off.append(off[-1] + len(l))
pos = lambda ln, col: off[ln - 1] + len(lines[ln - 1].encode('utf-8')[:col].decode('utf-8'))
cut, ends, gone, kept = [], {}, [], 0
for node in ast.parse(src).body:
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and getattr(node.targets[0], 'id', '') in BUCK \
            and isinstance(node.value, ast.Dict):
        name = node.targets[0].id
        ends[name] = node.value.end_lineno  # 닫는 `}` 줄
        for k, v in zip(node.value.keys, node.value.values):
            if k.value in have:
                kept += 1
                continue
            a, b = pos(k.lineno, k.col_offset), pos(v.end_lineno, v.end_col_offset)
            rest = src[b:]
            if rest.lstrip(' ').startswith(','):
                b += len(rest) - len(rest.lstrip(' ')) + 1
            cut.append((a, b))
            gone.append(k.value)
out = src
for a, b in sorted(cut, reverse=True):
    out = out[:a] + out[b:]
# 키만 지워져 공백·콤마만 남은 줄 정리
out = ''.join(l for l in out.splitlines(keepends=True) if l.strip() not in ('', ',') or l.strip() == '' and l == '\n')
# 미분류 등재(각 버킷 닫는 `}` 앞)
tree = ast.parse(out)
ol = out.splitlines(keepends=True)
for node in sorted(tree.body, key=lambda n: -getattr(n, 'lineno', 0)):
    if isinstance(node, ast.Assign) and getattr(node.targets[0], 'id', '') in ADD:
        nm = node.targets[0].id
        if ADD[nm].split("'")[1] not in out:
            ol.insert(node.value.end_lineno - 1, ADD[nm])
out = ''.join(ol)
compile(out, P, 'exec')
print('kit tools', len(have), '· kept', kept, '· removed', len(gone))
if '--apply' in sys.argv:
    io.open(P, 'w', encoding='utf-8', newline='').write(out)
    print('APPLIED')

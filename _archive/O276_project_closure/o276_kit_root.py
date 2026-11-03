# O276 2단계 — 키트 도구의 루트 하드코딩을 kit_paths.ROOT 로 일원화 (기본 dry-run · --apply 적용)
# 대상 ㉠ 모듈 최상위 `ROOT = <...>` 정의 줄 ㉡ 코드 안 '/workspace…' 문자열 토큰(주석·독스트링 제외)
import io, os, re, sys, tokenize

KIT = '/workspace/_reuse_kit'
DIRS = ['02_skill_init', '03_session_tools', '07_ops_tools', '08_handover_templates']
K = "__import__('kit_paths').ROOT"
TAG = '  # [kit] 루트 = kit_paths.py'
ROOT_DEF = re.compile(r'^ROOT\s*=\s*(.+?)\s*$')
apply = '--apply' in sys.argv
tot_def = tot_lit = nfile = 0
for d in DIRS:
    for f in sorted(os.listdir(os.path.join(KIT, d))):
        if not f.endswith('.py') or f == 'kit_paths.py':
            continue
        p = os.path.join(KIT, d, f)
        lines = io.open(p, encoding='utf-8').read().splitlines(keepends=True)
        # ㉡ 문자열 토큰 위치 수집(같은 줄 안 열 기준 · 단일 줄 토큰만)
        subs = {}
        with io.open(p, encoding='utf-8') as fh:
            for t in tokenize.generate_tokens(fh.readline):
                s = t.string
                if t.type != tokenize.STRING or s.startswith(('"""', "'''")) or t.start[0] != t.end[0]:
                    continue
                m = re.match(r'^([rRbBfFuU]*)([\'"])/workspace(.*)$', s)
                if not m or 'f' in m.group(1).lower():
                    continue
                rest = m.group(2) + m.group(3)  # 닫는 따옴표 포함 나머지
                new = '(%s + %s%s)' % (K, m.group(1), rest) if rest != m.group(2) * 2 else K
                subs.setdefault(t.start[0], []).append((t.start[1], t.end[1], new))
        changed = []
        for i, l in enumerate(lines, 1):
            o = l
            md = ROOT_DEF.match(l.rstrip('\n'))
            if md:
                rhs = md.group(1)
                if rhs.startswith('Path('):
                    o = 'ROOT = Path(%s)%s\n' % (K, TAG)
                elif "'/workspace/" in rhs or '"/workspace/' in rhs:
                    o = None  # ㉡ 에서 처리(하위 경로 보존)
                else:
                    o = 'ROOT = %s%s\n' % (K, TAG)
                if o is not None:
                    tot_def += 1
                    subs.pop(i, None)
                else:
                    o = l
            if i in subs and o == l:
                for c0, c1, new in sorted(subs[i], reverse=True):
                    o = o[:c0] + new + o[c1:]
                    tot_lit += 1
            if o != l:
                changed.append((i, l.rstrip(), o.rstrip()))
                lines[i - 1] = o
        if changed:
            nfile += 1
            for i, a, b in changed:
                print('%s/%s:%d\n  - %s\n  + %s' % (d, f, i, a.strip()[:140], b.strip()[:140]))
            if apply:
                src = ''.join(lines)
                compile(src, p, 'exec')  # 🔴 구문 깨지면 쓰지 않는다
                io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('%s files %d · ROOT 정의 %d · /workspace 리터럴 %d' % ('APPLIED' if apply else 'DRY-RUN', nfile, tot_def, tot_lit))

# O244 B⑤ — handoff_ddl_gate 축7 위반 줄 전문 덤프(근거 기록용 · 읽기 전용)
import io, sys, re
sys.path.insert(0, '/workspace/scripts')
import handoff_ddl_gate as g
hits, _ = g.axis7(True)
seen = set()
out = io.open('/workspace/tmp/o244/b5_lines.md', 'w', encoding='utf-8')
for name, n, tok, why, _t in hits:
    if (name, n) in seen:
        continue
    seen.add((name, n))
    line = io.open('/workspace/50_handoff/' + name, encoding='utf-8').read().splitlines()[n - 1]
    out.write('### %s:%d\n%s\n\n' % (name, n, line))
out.close()
print('lines', len(seen), 'hits', len(hits))

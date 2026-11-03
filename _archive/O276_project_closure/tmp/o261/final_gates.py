import subprocess, io
G = [['scripts/doc_type_gate.py'], ['scripts/doc_census.py'], ['scripts/doc_line_length_gate.py'],
     ['scripts/doc_heading_gate.py'], ['scripts/jinja_config_gate.py'], ['scripts/gate_census.py', '--final'],
     ['scripts/test_handoff_write.py'], ['scripts/test_sv_enum_newvalue_gate.py'],
     ['scripts/sv_code_label_gate.py', '--self-check'], ['scripts/id_collision_gate.py'], ['scripts/index_row_gate.py']]
out = []
for g in G:
    try:
        r = subprocess.run(['python3'] + g, cwd='/workspace', stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=900)
        tail = [l for l in r.stdout.strip().split('\n') if l.strip()][-1:] or ['']
        out.append('%s rc=%d | %s' % (' '.join(g), r.returncode, tail[0][:200]))
    except subprocess.TimeoutExpired:
        out.append('%s TIMEOUT' % ' '.join(g))
io.open('/workspace/tmp/o261/final_gates.txt', 'w', encoding='utf-8').write('\n'.join(out) + '\n')

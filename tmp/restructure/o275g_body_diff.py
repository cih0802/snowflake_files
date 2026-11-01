"""O275-G — 새 빌더가 만들 실행순서 사본 3종 본문 ↔ 현재 80 사본 diff(쓰지 않음)."""
import difflib, importlib.util, sys
P = '/workspace/80_인수인계_프로젝트완료 및 유지보수용/build_handoff.py'
spec = importlib.util.spec_from_file_location('bh', P); bh = importlib.util.module_from_spec(spec); spec.loader.exec_module(bh)
for d in sorted(bh.EXEC_DOCS):
    src = bh.ROOT / bh.to_new(d)
    body = bh.run_order_text() if d == bh.RUN_ORDER_DOC else bh.text_to_old(src.read_text(encoding='utf-8'))
    new = bh.hook(f'01_실행순서_배포SQL/{d}', body.encode()).decode()
    cur = (bh.OUT / '01_실행순서_배포SQL' / d).read_text(encoding='utf-8')
    df = [l for l in difflib.unified_diff(cur.splitlines(), new.splitlines(), n=0, lineterm='') if l[:1] in '+-' and l[:3] not in ('+++', '---')]
    print(f'▣ {d} 차이 {len(df)}줄')
    for l in df[:12]:
        print('   ', l[:180])

#!/usr/bin/env python3
"""배포순서 파일의 [D…] 표지 블록만 문장 단위 실행(기본 dry-run · --apply 시 집행 · 원천 BRONZE 쓰기 차단)

🆕 [O268 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `MUTATES`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴🔴 `--apply` 없이는 **아무것도 실행하지 않는다**(실행될 문장 전문만 보여준다).

왜 필요한가
    `문서실행순서.md` 기존 환경 갱신 43~47·52 는 파일 **전체가 아니라 [D…] 블록 단위**로 실행한다.
    블록 경계(어디서 시작해 어디서 끝나는가)를 사람·LLM 이 눈으로 고르면 틀린다 —
    특히 저가형 모델은 다음 블록까지 이어 실행하거나 앞 블록을 빠뜨린다.
    ⇒ 경계를 **파일의 표지 줄**로 기계가 정한다.

블록 규약
    블록 = `-- [표지]` 로 시작하는 줄부터 **다음 `-- [D` 또는 `-- [숫자` 로 시작하는 표지 줄 직전**까지.
    `--blocks` 에 여러 표지를 주면 **파일 순서대로** 이어서 실행한다(주어진 순서가 아니다).

사용법
    python3 scripts/run_sql_block.py <파일> --blocks D0,D1            # dry-run(기본 · 라이브 무변경)
    python3 scripts/run_sql_block.py <파일> --blocks D0,D1 --apply    # 🔴 실제 실행(R4-4-3 승인 대상)
    python3 scripts/run_sql_block.py <파일> --list                    # 파일의 블록 표지 목록만

종료코드 = 0 성공 · 1 실행 실패(첫 실패 문장에서 멈춘다) · 2 사용법 오류·표지 부재·원천 쓰기 차단.
Co-authored with CoCo
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

MARK = re.compile(r'^--\s*\[((?:D\d[\w-]*)|(?:\d[\w-]*))\]')
#: 운영계 원천 보호(`문서실행순서_llm실행.md` §1 · 실행기 SRC_WRITE 와 같은 식) — dry-run 에서도 검사한다.
SRC_WRITE = re.compile(r'^\s*(INSERT|UPDATE|DELETE|MERGE|TRUNCATE|COPY\s+INTO|DROP|'
                       r'CREATE\s+OR\s+REPLACE\s+(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\b[^;]*\bBRONZE_',
                       re.I | re.S)


def split_blocks(text):
    """[(표지, 본문)] — 파일 순서. 첫 표지 앞부분은 버린다(머리 주석)."""
    out, cur, buf = [], None, []
    for line in text.split('\n'):
        m = MARK.match(line)
        if m:
            if cur is not None:
                out.append((cur, '\n'.join(buf)))
            cur, buf = m.group(1), [line]
        elif cur is not None:
            buf.append(line)
    if cur is not None:
        out.append((cur, '\n'.join(buf)))
    return out


def _code(s):
    """주석 줄을 뺀 실행 본문 — 블록 첫 문장은 표지 주석 줄로 시작하므로 `^\\s*DELETE` 같은 검사가
    주석에 가려 빗나간다(O268 음성 축 ④ 가 실측으로 잡았다)."""
    return '\n'.join(l for l in s.split('\n') if not l.strip().startswith('--')).strip()


def statements(body):
    from run_sql_file import parse_statements
    keep = []
    for s in parse_statements(body):
        code = _code(s)
        if code and code != ';':
            keep.append(s.strip())
    return keep


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('path')
    ap.add_argument('--blocks', default='')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--apply', action='store_true', help='🔴 실제 실행(없으면 dry-run)')
    a = ap.parse_args()
    if not os.path.isfile(a.path):
        print(f'🔴 파일 부재: {a.path}')
        return 2
    blocks = split_blocks(open(a.path, encoding='utf-8').read())
    names = [b for b, _ in blocks]
    if a.list:
        print('블록 표지(파일 순서): ' + ' · '.join(names))
        return 0
    want = [x.strip() for x in a.blocks.split(',') if x.strip()]
    if not want:
        print('🔴 --blocks 가 비었다(미판정) — 예: --blocks D0,D1')
        return 2
    missing = [w for w in want if w not in names]
    if missing:
        print(f'🔴 표지 부재: {missing} · 이 파일의 표지 = {names}')
        return 2
    plan = []
    for b, body in blocks:
        if b in want:
            plan += [(b, s) for s in statements(body)]
    bad = [(b, s) for b, s in plan if SRC_WRITE.search(_code(s))]
    if bad:
        print(f'🔴 BLOCKED — 원천(BRONZE) 쓰기 문장 {len(bad)}개 · 실행하지 않는다 · 사용자에게 보고하라')
        for b, s in bad:
            print(f'   [{b}] {s[:200]}')
        return 2
    print(f'대상 = {a.path} · 블록 {[b for b in names if b in want]} · 문장 {len(plan)}개')
    if not a.apply:
        for i, (b, s) in enumerate(plan, 1):
            print(f'--- #{i} [{b}]\n{s}')
        print('🟡 DRY-RUN — 라이브를 바꾸지 않았다. 집행하려면 --apply 를 붙여라(R4-4-3 승인 대상).')
        return 0
    import sfconn
    cn = sfconn.conn()
    cur = cn.cursor()
    try:
        for i, (b, s) in enumerate(plan, 1):
            try:
                cur.execute(s)
                rows = cur.fetchmany(20) if cur.description else []
                print(f'OK #{i} [{b}] ' + ' '.join(s.split())[:120])
                for r in rows:
                    print('    ' + ' | '.join(str(x) for x in r)[:300])
            except Exception as e:
                print(f'FAIL #{i} [{b}] {str(e)[:400]}\n--- SQL ---\n{s[:1500]}')
                return 1
    finally:
        cn.close()
    print(f'🟢 블록 {want} 실행 완료 — 문장 {len(plan)}개')
    return 0


if __name__ == '__main__':
    sys.exit(main())

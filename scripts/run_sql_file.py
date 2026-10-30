import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # [O262] 자기 폴더 기준(80 패키지 이식)
import sfconn

def parse_statements(sql_text):
    statements = []
    current = []
    in_single_quote = False
    in_double_quote = False
    in_line_comment = False
    in_block_comment = False
    in_dollar_block = False
    
    i = 0
    n = len(sql_text)
    while i < n:
        c = sql_text[i]
        c2 = sql_text[i:i+2]
        
        if in_line_comment:
            if c == '\n':
                in_line_comment = False
            current.append(c)
            i += 1
        elif in_block_comment:
            if c2 == '*/':
                in_block_comment = False
                current.append('*/')
                i += 2
            else:
                current.append(c)
                i += 1
        elif in_dollar_block:
            if c2 == '$$':
                in_dollar_block = False
                current.append('$$')
                i += 2
            else:
                current.append(c)
                i += 1
        elif in_single_quote:
            current.append(c)
            if c == "'":
                in_single_quote = False
            i += 1
        elif in_double_quote:
            current.append(c)
            if c == '"':
                in_double_quote = False
            i += 1
        else:
            if c2 == '--':
                in_line_comment = True
                current.append('--')
                i += 2
            elif c2 == '/*':
                in_block_comment = True
                current.append('/*')
                i += 2
            elif c2 == '$$':
                in_dollar_block = True
                current.append('$$')
                i += 2
            elif c == "'":
                in_single_quote = True
                current.append(c)
                i += 1
            elif c == '"':
                in_double_quote = True
                current.append(c)
                i += 1
            elif c == ';':
                stmt = ''.join(current).strip()
                if stmt:
                    statements.append(stmt)
                current = []
                i += 1
            else:
                current.append(c)
                i += 1
                
    stmt = ''.join(current).strip()
    if stmt:
        statements.append(stmt)
    return statements

def is_comment_only(stmt):
    # 🆕 [O272] `--` 줄 + `/* */` 블록을 지운 뒤 남는 것이 없으면 주석뿐인 문장(종전 판정은 `--` 줄만 봤다)
    body = re.sub(r'/\*.*?\*/', ' ', stmt, flags=re.S)
    body = '\n'.join(l for l in body.split('\n') if not l.strip().startswith('--'))
    return not body.strip()

def run_file(file_path):
    print(f'=== Running file: {file_path} ===')
    sql = open(file_path, encoding='utf-8').read()
    stmts = parse_statements(sql)
    print(f'Total parsed statements: {len(stmts)}')
    
    cn = sfconn.conn()
    cur = cn.cursor()
    cur.execute('USE ROLE ' + os.environ.get('GN_DW_ROLE', 'GN_DW_ADMIN'))            # [O262] 환경변수 덮어쓰기(기본값 불변)
    for ctx in ('WAREHOUSE ' + os.environ.get('GN_DW_WAREHOUSE', 'GN_DW_DEV_WH'), 'DATABASE GN_DW'):
        try:
            cur.execute('USE ' + ctx)
        except Exception as e:  # 🆕 [O272] 신규 계정 = 창고·GN_DW 부재 → 07 RBAC 이 만든다(종전 = 첫 문장 전 002043)
            print(f'WARN: USE {ctx} 실패 — 계속 진행(신규 계정이면 정상): {e}')
    
    success = 0
    failed = 0
    for idx, stmt in enumerate(stmts):
        if is_comment_only(stmt):  # 🆕 [O272] 주석뿐인 꼬리 블록 = 000900 오탐 방지
            continue
        try:
            cur.execute(stmt)
            success += 1
        except Exception as e:
            print(f'ERROR on stmt {idx+1}: {e}')
            print('Snippet:', stmt[:150].replace('\n', ' '))
            failed += 1
            break
            
    cur.close()
    cn.close()
    print(f'Finished {file_path}: {success} succeeded, {failed} failed.')
    return failed == 0

def dry_run(file_path):
    # 🆕 [O270] 접속 없이 파싱 결과만 보인다(라이브 무변경)
    stmts = parse_statements(open(file_path, encoding='utf-8').read())
    print(f'[dry-run] {file_path}: {len(stmts)} statements (집행 = --apply)')
    for idx, stmt in enumerate(stmts):
        print(f'  {idx+1:>3}. ' + stmt[:120].replace('\n', ' '))
    return True

if __name__ == '__main__':
    # 🆕 [O270 · O269-C-1 ②] 기본 = dry-run · `--apply` 가 있어야 라이브 집행(MUTATES 계약 · test_mutating_tool_safety 축③)
    args = [a for a in sys.argv[1:] if a != '--apply']
    apply = '--apply' in sys.argv[1:]
    if not args or args[0] in ('-h', '--help'):  # [O262] 접속 없이 사용법만
        print('사용: python3 run_sql_file.py <파일.sql> [...] [--apply]\n'
              '  기본 = dry-run(접속 없음 · 문장 목록만) · --apply = 문장 단위 순차 실행 · 첫 실패에서 멈춤(rc=1)\n'
              '  접속 = sfconn.conn() · 역할/웨어하우스 = GN_DW_ROLE(기본 GN_DW_ADMIN) · GN_DW_WAREHOUSE(기본 GN_DW_DEV_WH)')
        sys.exit(0)
    for f in args:
        ok = run_file(f) if apply else dry_run(f)
        if not ok:
            sys.exit(1)

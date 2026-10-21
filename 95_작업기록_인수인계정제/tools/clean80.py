"""80번 SQL 주석 정제 (주석만 수정 · 파일마다 '주석 제거 후 코드 동일'을 assert).

사용: python3 clean80.py <80번 루트> <결과 csv>
- 제거: `Co-authored with CoCo` 서명, 연속 중복 구분선/빈 주석줄
- 정규화: 이모지 → WARN:/NOTE:/MANUAL:/TODO: (완료·신규 표식 🟢✅🆕📏 은 삭제)
- 개발계 값: 계정 로케이터 제거(scrub_acct), '개발계' → '개발 환경'
- 대상: `--` 주석줄, `/* */` 블록, `{# #}` Jinja 주석, 따옴표 없는 코드 줄의 줄끝 `--` 주석
- 제외: `mstr DDL 원본/`(SQL Server 원문), `COMMENT '…'` 문자열(배포 메타데이터 = 코드)
"""
import re, os, sys, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scrub_acct import scrub

SKIP = ('mstr DDL 원본',)
TAG = [('🔴', 'WARN:'), ('⚠️', 'WARN:'), ('⚠', 'WARN:'), ('❌', 'WARN:'), ('🟠', 'NOTE:'), ('🟡', 'NOTE:'),
       ('👤', 'MANUAL:'), ('⬜', 'TODO:'), ('🟢', ''), ('✅', ''), ('🆕', ''), ('📏', '')]
SIG = re.compile(r'^\s*(--\s*)?_?Co-authored with CoCo_?\s*$', re.I)
SEP = re.compile(r'^\s*--\s*[-=─━#*·]{10,}\s*$')
EMPTY = re.compile(r'^\s*--\s*$')


def fix(s):
    s = re.sub(r'Co-authored with CoCo\s*·\s*', '', s)
    s = scrub(s)
    for e, t in TAG:
        s = s.replace(e, t)
    s = s.replace('개발계', '개발 환경')
    s = re.sub(r'(WARN:|NOTE:|MANUAL:|TODO:)\s*(?=\1)', '', s)
    return re.sub(r'(\S)  +', r'\1 ', s.rstrip())


def strip_comments(s):
    s = re.sub(r'\{#.*?#\}', '', s, flags=re.S)
    out, i, q = [], 0, False
    while i < len(s):
        c = s[i]
        if q:
            out.append(c); q = c != "'"; i += 1; continue
        if c == "'":
            q = True; out.append(c); i += 1; continue
        if s.startswith('/*', i):
            j = s.find('*/', i + 2); i = len(s) if j < 0 else j + 2; continue
        if s.startswith('--', i):
            j = s.find('\n', i); i = len(s) if j < 0 else j; continue
        out.append(c); i += 1
    return re.sub(r'\s+', ' ', ''.join(out)).strip()


def trailing_comment_at(line):
    """따옴표 밖 첫 `--` 위치(코드 뒤 줄끝 주석). 없으면 None."""
    q = False
    for i, c in enumerate(line):
        if c == "'":
            q = not q
        elif not q and line.startswith('--', i):
            return i if line[:i].strip() else None
    return None


def clean(text):
    text = re.sub(r'\{#.*?#\}', lambda m: fix(m.group(0)), text, flags=re.S)
    out, inb, rm = [], False, 0
    for l in text.split('\n'):
        is_line = bool(re.match(r'^\s*--', l))
        start = ('/*' in l) and not is_line
        s = l
        if SIG.match(l) and (is_line or inb):
            s = None
        elif is_line:
            if out and (SEP.match(l) or EMPTY.match(l)) and out[-1].strip() == l.strip():
                s = None
            else:
                body = l.split('--', 1)[1]
                s = l[:l.index('--') + 2] + (fix(body) if body.strip() else '')
                if s.strip() == '--' and body.strip():
                    s = None
        elif inb or start:
            s = fix(l)
        else:
            k = trailing_comment_at(l)
            if k is not None:
                s = l[:k] + fix(l[k:])
        if '*/' in l:
            inb = False
        elif start:
            inb = True
        if s is None:
            rm += 1
        else:
            out.append(s)
    return '\n'.join(out), rm


if __name__ == '__main__':
    root, out_csv = sys.argv[1], sys.argv[2]
    stat = []
    for d, _, fs in os.walk(root):
        for f in fs:
            if not f.endswith('.sql'):
                continue
            p = os.path.join(d, f); rel = os.path.relpath(p, root)
            if any(k in rel for k in SKIP):
                stat.append((rel, 0, '제외(원본)')); continue
            raw = open(p, encoding='utf-8', errors='surrogateescape').read()
            new, rm = clean(raw)
            assert strip_comments(new) == strip_comments(raw), rel
            if new != raw:
                open(p, 'w', encoding='utf-8', errors='surrogateescape').write(new)
            stat.append((rel, rm, '정제완료 · 코드동일 OK' if new != raw else '변경없음'))
    with open(out_csv, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh); w.writerow(['path', '삭제줄', 'status']); w.writerows(sorted(stat))
    print('files', len(stat), 'changed', sum(s[2].startswith('정제') for s in stat))

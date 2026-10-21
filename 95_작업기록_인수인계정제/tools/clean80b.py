"""80번 비SQL 파일의 개발·트라이얼 계정 로케이터 제거 (O253).

사용: python3 clean80b.py <80번 루트> <백업 루트> <결과 csv> [--dry]
- 대상: .md · .html · .csv = 본문 전체에 scrub_acct.scrub 적용
        .yml = `#` 주석 부분에만 적용(주석 제거 후 코드 동일을 assert)
- 제외: .py(`RUN_ORDER_SKIP_SECTIONS = ["개발계"]` 처럼 실행 로직에 쓰임) · .sql(clean80.py 소관)
- 단어 「개발계」는 바꾸지 않는다 — 80번은 개발계 배포 절차를 담은 유지보수 패키지라 의미어다.
- 변경 파일은 쓰기 전에 <백업 루트>/<상대경로> 로 복사한다(이미 있으면 덮지 않는다).
"""
import os, re, sys, csv, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scrub_acct import scrub, ACC

TEXT = ('.md', '.html', '.csv')
ACC_RE = re.compile('|'.join(ACC), re.I)
# 이슈 원장 사본은 「기재 계정 ↔ 실측 계정」 불일치 조사 이력이라 로케이터를 지우면 뜻이 사라진다(사용자 결정 대기).
SKIP = ('07_운영런북_이슈/20_issue/',)
POST = [(re.compile(r'(?:개발계|계정)\s*(\*\*)?이전 계정(\*\*)?'), lambda m: '개발계' if m.group(0).startswith('개발계') else '**이전 계정**' if m.group(1) else '이전 계정'),
        (re.compile(r'이전 계정 계정'), '이전 계정')]


def scrub2(s):
    s = scrub(s)
    for p, r in POST:
        s = p.sub(r, s)
    return s


def yml_comment_at(line):
    """따옴표 밖 첫 `#` 위치. 없으면 None."""
    q = None
    for i, c in enumerate(line):
        if q:
            q = None if c == q else q
        elif c in ('"', "'"):
            q = c
        elif c == '#' and (i == 0 or line[i - 1] in ' \t'):
            return i
    return None


def strip_yml(s):
    out = []
    for l in s.split('\n'):
        k = yml_comment_at(l)
        out.append((l if k is None else l[:k]).rstrip())
    return '\n'.join(out)


def clean_yml(s):
    out = []
    for l in s.split('\n'):
        k = yml_comment_at(l)
        out.append(l if k is None else l[:k] + scrub2(l[k:]))
    return '\n'.join(out)


if __name__ == '__main__':
    root, bak, out_csv = sys.argv[1:4]
    dry = '--dry' in sys.argv
    stat = []
    for d, _, fs in os.walk(root):
        for f in fs:
            ext = os.path.splitext(f)[1].lower()
            if ext not in TEXT + ('.yml', '.yaml'):
                continue
            p = os.path.join(d, f); rel = os.path.relpath(p, root)
            if any(rel.startswith(k) for k in SKIP):
                continue
            try:
                raw = open(p, encoding='utf-8').read()
            except UnicodeDecodeError:
                continue
            n0 = len(ACC_RE.findall(raw))
            if not n0:
                continue
            if ext in TEXT:
                new = scrub2(raw)
            else:
                new = clean_yml(raw)
                assert strip_yml(new) == strip_yml(raw), rel
            n1 = len(ACC_RE.findall(new))
            if new != raw and not dry:
                b = os.path.join(bak, rel)
                if not os.path.exists(b):
                    os.makedirs(os.path.dirname(b), exist_ok=True)
                    shutil.copyfile(p, b)  # copy2 는 마운트에서 xattr 오류
                    assert os.path.getsize(b) == os.path.getsize(p), rel
                open(p, 'w', encoding='utf-8').write(new)
            stat.append((rel, n0, n1, '정제완료' if new != raw else '변경없음'))
    with open(out_csv, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh); w.writerow(['path', '계정값_전', '계정값_후', 'status']); w.writerows(sorted(stat))
    print('files', len(stat), 'before', sum(s[1] for s in stat), 'after', sum(s[2] for s in stat))

# O276 2단계-4 — 키트 사본의 고유값을 자리표시자로 1회 치환(GN_DW → {{DB}} · 계정 로케이터 → {{ACCOUNT}})
# 세션 라벨(O##)·주석·굿네이버스 문구는 사용자 결정으로 유지한다.
import io, os, re, sys
from collections import Counter

KIT = '/workspace/_reuse_kit'
SKIP = {'apply_names.py', '00_INVENTORY.md', '01_PLACEHOLDERS.md'}
TEXT = ('.md', '.py', '.sql', '.sh', '.yml', '.yaml', '.txt', '.csv', '.toml', '.json')
LOCATORS = ['tq68205', 'zl50263', 'xh20001', 'sr61467', 'iw20760', 'ny60473', 'zs83821', 'ju93656', 'ad50130']
RULES = [('DB', re.compile(r'GN_DW')),
         ('ACCOUNT', re.compile(r'(?i)(?<![A-Za-z0-9])(?:%s)(?![0-9])' % '|'.join(LOCATORS)))]
CAND = re.compile(r'(?<![A-Za-z0-9])[A-Za-z]{2}\d{5}(?![0-9])')  # 목록 밖 로케이터 후보 탐지
apply = '--apply' in sys.argv
stat, per, cand = Counter(), [], Counter()
for dp, _, fs in os.walk(KIT):
    for f in sorted(fs):
        if f in SKIP or not f.endswith(TEXT):
            continue
        p = os.path.join(dp, f)
        if p == os.path.join(KIT, '00_README.md'):  # 키트 안내문 = 원래 값을 설명한다
            continue
        try:
            src = io.open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            stat['non_utf8'] += 1
            continue
        out, c = src, Counter()
        for key, rx in RULES:
            out, n = rx.subn('{{%s}}' % key, out)
            c[key] += n
        for t in CAND.findall(out):
            if t.lower() not in LOCATORS:
                cand[t] += 1
        if out != src:
            stat['files'] += 1
            stat['DB'] += c['DB']
            stat['ACCOUNT'] += c['ACCOUNT']
            if apply:
                io.open(p, 'w', encoding='utf-8', newline='').write(out)
        # 보고서는 이번 실행분이 아니라 **현재 키트 상태**(누적)를 센다 — 재실행해도 기록이 줄지 않는다
        nd, na = out.count('{{DB}}'), out.count('{{ACCOUNT}}')
        if nd or na:
            per.append((os.path.relpath(p, KIT), nd, na))
stat['DB'] = sum(r[1] for r in per)
stat['ACCOUNT'] = sum(r[2] for r in per)
L = ['<!-- LLM-METADATA', 'doc_id: REUSE_KIT_PLACEHOLDERS',
     'doc_role: 키트 자리표시자 치환 기록 — 무엇을 무엇으로 바꿨나 · 새 프로젝트 적용법', 'created: 2026-11-02',
     'END-METADATA -->', '', '# 자리표시자 (_reuse_kit)', '',
     '| 자리표시자 | 원래 값 | 치환 건수 |', '|---|---|---|',
     '| `{{DB}}` | `GN_DW` (역할·창고 접두 포함 · 예 `GN_DW_ADMIN` → `{{DB}}_ADMIN`) | %d |' % stat['DB'],
     '| `{{ACCOUNT}}` | 계정 로케이터 %s (대소문자 무관) | %d |' % (' · '.join('`%s`' % x for x in LOCATORS),
                                                              stat['ACCOUNT']),
     '', '- 유지(사용자 결정 2026-11-02) = 세션 라벨 `O##` · 주석 · `굿네이버스` 문구.',
     '- `00_INVENTORY.md` 의 해시·잔존 열은 **치환 전 복사 시점** 값이다.', '',
     '## 새 프로젝트 적용', '', '```',
     'python3 _reuse_kit/apply_names.py --check                                   # 남은 자리표시자',
     'python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345     # dry-run',
     'python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345 --apply', '```', '',
     '## 목록 밖 로케이터 후보(형식 `XX99999` · 확인 필요)', '']
L += ['- `%s` × %d' % kv for kv in cand.most_common()] or ['- 없음']
L += ['', '## 파일별', '', '| 파일 | DB | ACCOUNT |', '|---|---|---|']
L += ['| `%s` | %d | %d |' % r for r in per]
if apply:
    io.open(os.path.join(KIT, '01_PLACEHOLDERS.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print('APPLIED' if apply else 'DRY-RUN', dict(stat), 'candidates', dict(cand.most_common(10)))

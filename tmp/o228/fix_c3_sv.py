#!/usr/bin/env python3
"""O228 ③ C3 SV — SV DDL 파일의 COMMENT 리터럴에서 이슈ID·경위 서사를 찾는다(dry) / 치환한다(--apply).
규칙 = tmp/o227/fix_c3_col.py 의 ID·scrub 를 import 해 1벌로 쓴다(덮어쓰기 OVR 는 쓰지 않는다 · SV 축 전용 없음).
대상 = SQL `--` 주석 줄이 아닌 줄의 `COMMENT = '…'` 리터럴만(라이브로 들어가는 문안).
사용: python3 tmp/o228/fix_c3_sv.py [--apply]  · 산출 = tmp/o228/c3_sv_diff.md · 잔여 ID 가 있으면 ABORT.
Co-authored with CoCo
"""
import glob, hashlib, io, re, sys, importlib.util

spec = importlib.util.spec_from_file_location('c3', '/workspace/tmp/o227/fix_c3_col.py')
src = io.open('/workspace/tmp/o227/fix_c3_col.py', encoding='utf-8').read()
# 모듈 본문(파일 처리부)은 실행하지 않는다 — ID·scrub 정의까지만 잘라 실행
head = src[:src.index("rows = [l.rstrip")]
ns = {}
exec(compile(head, 'fix_c3_col_head', 'exec'), ns)
ID, scrub0 = ns['ID'], ns['scrub']

# SV 축 후처리 — 순수 경위는 삭제 · 사실이 든 문장은 현재형으로(실측 근거 = 원 문안 그대로의 사실 부분)
POST = [
    (r"\s*⚠ 종전 코드값\('M'/'F'/'U'\)(?:을 노출했었다 — 'U'는 미상이 아니라 미상\+법인\+단체 혼합이었다| 노출 →)", ''),
    (r"\s*🔴 종전 공존했던 `PAYMENT_RATE`[^.]*제거\*\*했다\.", ''),
    (r"\s*🔴 종전 이름은 `(?:TOTAL_UNPAID_AMT_|UNPAID_RATIO_)` 였고[^.]*\*\*승격\*\*했다\.", ''),
    (r"\s*🔴 종전 그쪽 정본 이름은 `UNPAID_RATIO_`[^.]*일치했다\.", ''),
    (r" —\. 종전 COMMENT 가 \"개발/중단/증액/미납중단\"이라 적혀 있어 '증액' 필터 생성 시 0행 무증상 오답이 가능했다\(유형\)",
     " — '증액' 등 상태값으로 이 컬럼을 필터하면 0행이 반환된다."),
    (r"🔴 \*\*종전 이 자리에 있던 \*\"캠페인별 중단건은 답이 나오지 않는다\"\* 는 서술은 회수됐다\*\* — "
     r"개발원천 코드5 행이 캠페인을 보유하므로 답이 나온다\.",
     '🟢 개발원천 후원중단 행은 캠페인을 보유하므로 캠페인별 중단건을 답할 수 있다.'),
    (r"\(2026-08-05 신설 — 종전에는 자기참조 코드만 있어 사람이 읽을 수 없었다\)", ''),
    (r"이며 종전에는 라벨이 없어 이 축을 쓸 수 없었다 —", '이다 —'),
    (r"\(2026-08-05 에서 종전 오표기 회수\)", ''),
    (r"\(종전 분수 시절의 쿼리를 재사용하면 100배 과대해진다\)", ''),
    (r"\(종전 COMMENT 가 실재하지 않는 값을 열거하고 있었다 · 경위는 원장 §\)", ''),
    (r"\(합치지 않는다 실측 정정 · 종전 4종\)", '(합치지 않는다)'),
    (r"🔴 종전 「VIDEO 원천에 개발 컬럼이 구조적으로 부재」는 \*\*원천 재편으로 거짓이 됐다\*\* — VIDEO 도", '🔴 VIDEO 도'),
    (r"\(정정: 종전 「VIDEO 컬럼 부재」 철회\)", ''),
    (r"🟢 \[현업 재회신\] 원래 계산식이 맞다\(의 「오타」 판정 철회\) ·", '🟢 원래 계산식이 맞다(현업 확인) ·'),
    (r"\(2026-10-02 원천 교체 — 종전 상위캠페인 회원평균 LTV·캠페인 총액 LTV·LTV 스코어 4종은 폐기됐다\)", ''),
    (r"\(2026-10-02 원천 교체로 종전 「관측월」 해석은 폐기\)", ''),
    (r" — 2026-10-02 원천 교체로 종전의 관측월·가입월·가입경과월 축은 폐기됐다\.", '. 관측월·가입월·가입경과월 축은 없다.'),
    # 좌표 잔재(ID 제거 후 남은 「원장 §」·문서 절번호)
    (r"\s*\(경위는 원장 §\)", ''), (r"\s*·\s*경위는 원장 §", ''), (r"\s*\(원장 §\)", ''),
    (r"\(개발사건 단위 실측·문서10 §19 참조\)", '(개발사건 단위 실측)'),
    (r"\s*\(연도별 실측치는 참조\)", ''), (r"\s*\(실측치는·§ 참조\)", ''), (r"\s*·\s*값은·§ 참조", ''),
    (r"(최대 2개다)\S*참조\)", r'\1'),
    (r"\s*·\s*§11-C\)", ')'),
    (r",\s*03 §8\.5 §6-H\)", ')'),
    (r"🔴 종전 이름은 `TOTAL_PAID_FEE` 였다 — `_FEE` 가 「회비」로 오해되므로 형제 SV `SV_MEMBER_FEE\.TOTAL_PAID_ALL` 과 "
     r"\*\*같은 이름으로 통일\*\*했다\(정의·값 불변\)\.",
     '형제 SV `SV_MEMBER_FEE.TOTAL_PAID_ALL` 과 같은 이름·같은 정의다.'),
    (r"\s*실측치는\s*§\s*참조\.", ''),
    (r"\(03 §8\.5\.1\)", ''),
]


def scrub(t):
    t = scrub0(t)
    for a, b in POST:
        t = re.sub(a, b, t)
    t = re.sub(r'\(\s*\)', '', t)
    return re.sub(r'\s{2,}', ' ', t).replace(' .', '.').replace('..', '.').strip()

FILES = sorted(glob.glob('/workspace/05_SV-Agent_ai/05_*_SV_DDL*.sql')) + [
    '/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql', '/workspace/05_SV-Agent_ai/23_ML_INC_MKTG_CMPGN_DDL.sql',
    '/workspace/05_SV-Agent_ai/24_ML_REALTIME_SIMULATOR_DDL.sql', '/workspace/05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql',
    '/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
OUT = '/workspace/tmp/o228/c3_sv_diff.md'
LIT = re.compile(r"COMMENT\s*=\s*'((?:[^']|'')*)'")
NARR = re.compile(r'종전|거짓이었다|철회|이슈원장|문서10 §|문서20 §|문서30 §')
apply = '--apply' in sys.argv
BAK = '--from-bak' in sys.argv  # 적용 후 전후 대조 재생성용 — 원본 = tmp/o228/bak/<파일>.O228-prec3sv (쓰기 금지)
assert not (apply and BAK)
diff, resid, unclosed, touched = [], [], [], {}
for p in FILES:
    rp = '/workspace/tmp/o228/bak/' + p.split('/')[-1] + '.O228-prec3sv' if BAK else p
    if BAK and not __import__('os').path.exists(rp):
        continue
    a, b = (hashlib.sha256(open(rp, 'rb').read()).hexdigest() for _ in range(2))
    assert a == b, 'hash unstable ' + rp
    L = io.open(rp, encoding='utf-8').read().split('\n')
    sv = None
    n = 0
    for i, s in enumerate(L):
        m = re.search(r'SEMANTIC VIEW (?:IF NOT EXISTS )?GN_DW\.SERVING\.(\w+)', s)
        if m and 'CREATE' in s:
            sv = m.group(1)
        if s.lstrip().startswith('--'):
            continue
        if sv is None:  # SV 문장 밖(VIEW·TABLE DDL)은 이 단계 대상이 아니다
            continue
        if s.rstrip().endswith(';'):
            end = True
        else:
            end = False
        if re.search(r"COMMENT\s*=\s*'", s) and not LIT.search(s):
            unclosed.append(f'{p}:{i + 1}')
            continue
        out, pos = [], 0
        for m in LIT.finditer(s):
            old = m.group(1).replace("''", "'")
            if not (re.search(r'\b' + ID + r'\b', old) or NARR.search(old)):
                continue
            new = scrub(old)
            left = sorted(set(re.findall(r'\b' + ID + r'\b', new)))
            if left:
                resid.append(f'{p.split("/")[-1]}:{i + 1} {sv} {left}')
            out.append(s[pos:m.start(1)] + new.replace("'", "''"))
            pos = m.end(1)
            diff.append(f'### {p.split("/")[-1]}:{i + 1} {sv}\n- 전: {old}\n- 후: {new}\n')
            n += 1
        if out:
            L[i] = ''.join(out) + s[pos:]
        if end:
            sv = None
    if n:
        touched[p] = (n, L)
if diff:  # 🔴 빈 대조로 기존 대조 파일을 덮지 않는다(O228 사고 · 적용 후 dry 가 대조를 지웠다)
    io.open(OUT, 'w', encoding='utf-8').write('# O228 C3 SV 전후 대조\n\n' + '\n'.join(diff) + '\n_Co-authored with CoCo_\n')
print('파일', len(FILES), '· 변경 파일', len(touched), '· 리터럴', len(diff), '· 잔여ID', len(resid), '· 미닫힘', len(unclosed))
for p, (n, _) in touched.items():
    print('  ', p.split('/')[-1], n)
for r in resid:
    print('  잔여', r)
for u in unclosed:
    print('  미닫힘', u)
if resid:
    sys.exit('🔴 ABORT — 잔여 ID')
if apply:
    sys.path.insert(0, '/workspace/scripts')
    from snapshot_util import snapshot
    for p, (_, L) in touched.items():
        snap, st = snapshot(p, 'prec3sv', label='O228', archive='/workspace/tmp/o228/bak')
        print('   snap', st, snap.split('/')[-1])
        io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
    print('APPLIED', len(touched))
else:
    print('DRY-RUN')

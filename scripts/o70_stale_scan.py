#!/usr/bin/env python3
"""발행 문안 stale 수치 스캔 (신설 2026-08-13 O70 · 보강 O70-B).

분모 = 발행 문안만(라이브로 나가는 것) = COMMENT = '...' · AI_SQL_GENERATION '...'.
파일 주석(-- , /* */)은 라이브에 나가지 않으므로 별건(문서50 §O68 잔여 「SV 9종 11줄」).
검출 축 = ① O67-B A4 가 지목한 구성 의존 토큰군 ② 콤마 자릿수 수치(적재량) ③ 백분율·배수.
「N종」은 sv_code_label_gate 가 실측과 대조하는 축이라 별도 열로 분리해 보고한다(금지 아님).

🔴 위상 = **일회용 검사이며 상설 게이트가 아니다**(문서50 §O70-B 구조2).
   기본 분모는 §O68-B A1 의 미독 편집 3파일이고, 인자로 임의 파일을 넘길 수 있다.
   발행 표면 **전체**로 넓히는 것은 착수표 ⑤(표면 정의 재확정) 소관이며, 그때
   `sv_unit_gate` 로 흡수할지 이 스크립트를 상설화할지 함께 결정한다.

사용법
   python3 scripts/o70_stale_scan.py                 # 기본 3파일
   python3 scripts/o70_stale_scan.py <파일...>       # 분모 지정
   python3 scripts/o70_stale_scan.py --self-check    # 자기검사 (O70-B A5 시정)
"""
import re, sys, io

DEFAULT_FILES = [
    '05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql',
    '05_SV-Agent_ai/05_5_SV_DDL_EVENT_PARTICIPATION.sql',
    '05_SV-Agent_ai/05_7_SV_DDL_AD.sql',
]
args = [a for a in sys.argv[1:] if not a.startswith('--')]
FILES = args if args else DEFAULT_FILES


# ① 구성 의존 토큰 (O67-B A4 · O68 ② 가 제거한 것과 같은 축)
COMPOSE = re.compile(r'SV\s*\d+\s*종|\d+\s*팩트|\d+\s*섹션|\d+\s*개\s*보고|Agent\s*\d+\s*종|도구\s*\d+')
# ② 적재량 수치 (콤마 자릿수)
LOADED = re.compile(r'\d{1,3}(?:,\d{3})+')
# ③ 백분율·배수
PCT = re.compile(r'\d+(?:\.\d+)?\s*%|\d+(?:\.\d+)?\s*배')
# 참조: 종수 선언 (금지 아님 — 게이트 대조축)
KIND = re.compile(r'실제값\s*(\d+)\s*종')

# 발행 문안 추출: 파일 주석 제거 후 COMMENT = '...' / AI_SQL_GENERATION '...'
def published_spans(text):
    # 라인 주석 · 블록 주석 제거 (문자열 리터럴 안의 -- 는 이 파일들에 없음을 육안 확인함)
    no_block = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    no_line = re.sub(r'^\s*--.*$', ' ', no_block, flags=re.M)
    out = []
    for m in re.finditer(r"(?:COMMENT\s*=\s*|AI_SQL_GENERATION\s+)'((?:[^']|'')*)'", no_line):
        out.append(m.group(1))
    return out

# 면제 = 적재·구성에 의존하지 않는 수치(처방 파라미터 · 산식 관계). 근거를 함께 적는다.
# 🔴 면제는 「값이 변하면 거짓이 되는가」로 판정한다 — 적재량이 바뀌어도 참인 수치는 stale 이 아니다.
EXEMPT = {
    '1,000': '처방 파라미터(소표본 배제 하한 예시) — 적재량이 바뀌어도 거짓이 되지 않는다',
    '100배': '산식 관계 설명(percent 승격 후 ×100 이중곱 경고) — 적재 무관',
}

def self_check():
    """양성·음성·면제·주석배제 4축. 🔴 [O70-B A5 시정] 신설 게이트에 자기검사가 없어
    「0건」이 정상인지 판정식 고장인지 구별할 수 없었다(P106·P230 의 거짓 통과 방향)."""
    cases = [
        # (이름, 원문, 기대 검출 토큰수(면제 제외))
        ('양성 구성의존', "COMMENT = 'SV 9종 중 3팩트를 잇는다'", 2),
        ('양성 적재량', "COMMENT = '행 40,054,883 기준'", 1),
        ('양성 백분율', "COMMENT = '커버리지 99.42% 다'", 1),
        ('음성 정상문안', "COMMENT = '회원 코호트 팩트. 실제값 3종: ''A''·''B''·''C''.'", 0),
        ('면제 처방파라미터', "COMMENT = '관측 가능 회원 1,000명 이상을 적용한다'", 0),
        ('면제 산식설명', "COMMENT = 'percent 이므로 100배 과대해진다'", 0),
        ('주석 배제', "-- SV 9종 전체 배포 검증\n/* 3팩트 */\nCOMMENT = '정상'", 0),
        ('AI_SQL 표면 포함', "AI_SQL_GENERATION '규칙: 3섹션 을 합친다'", 1),
    ]
    ok = 0
    for name, text, expect in cases:
        hits = []
        for s in published_spans(text):
            hits += COMPOSE.findall(s) + LOADED.findall(s) + PCT.findall(s)
        real = [h for h in hits if h not in EXEMPT]
        good = len(real) == expect
        ok += good
        print('   %s %-18s 기대 %d · 검출 %d %s' % ('✅' if good else '🔴', name, expect, len(real), real))
    print('   ⇒ 자기검사 %d/%d' % (ok, len(cases)))
    return 0 if ok == len(cases) else 1


if '--self-check' in sys.argv:
    print('[o70_stale_scan 자기검사]')
    sys.exit(self_check())

rc = 0
used_exempt = set()
for rel in FILES:
    text = io.open(rel, encoding='utf-8').read()
    spans = published_spans(text)
    hits_c, hits_l, hits_p, kinds = [], [], [], []
    for s in spans:
        hits_c += COMPOSE.findall(s)
        hits_l += LOADED.findall(s)
        hits_p += PCT.findall(s)
        kinds += KIND.findall(s)
    real = [t for t in set(hits_c) | set(hits_l) | set(hits_p) if t not in EXEMPT]
    exempted = sorted((set(hits_l) | set(hits_p) | set(hits_c)) & set(EXEMPT))
    print('== %s' % rel)
    print('   발행 문안 = %d 개' % len(spans))
    print('   ① 구성 의존 토큰 : %d %s' % (len(hits_c), sorted(set(hits_c))))
    print('   ② 적재량 수치    : %d %s' % (len(hits_l), sorted(set(hits_l))))
    print('   ③ 백분율·배수    : %d %s' % (len(hits_p), sorted(set(hits_p))))
    print('   (참조) 실제값 N종 : %d 곳 — sv_code_label_gate 가 실측과 대조하는 축(금지 아님)' % len(kinds))
    for t in exempted:
        print('   면제 %-8s : %s' % (t, EXEMPT[t]))
    if real:
        print('   🔴 stale 후보 : %s' % sorted(real))
        rc = 1
    used_exempt |= set(exempted)

# B2 시정 — 면제 목록 사문화 탐지(문서50 §O70-B B2)
# 🔴 면제는 「그 파일에 그 토큰이 있어서」 둔 것이다. 토큰이 사라졌는데 면제가 남으면
#    다음 세션이 재검토 없이 **넓은 면제를 승계**한다(C3 신선도 링크 부재와 같은 축).
dead = sorted(set(EXEMPT) - used_exempt)
if dead:
    print('\n🟠 사문화된 면제 %d건 — 분모에서 더 이상 검출되지 않는다: %s' % (len(dead), dead))
    print('   ⇒ 면제 항목을 삭제하거나, 남길 근거를 다시 적는다(승계 금지).')
else:
    print('\n🟢 면제 목록 신선도 = 전건 실사용(%d/%d)' % (len(used_exempt), len(EXEMPT)))

print('\n판정 = %s' % ('FAIL (stale 후보 실재)' if rc else 'PASS (발행 문안 stale 수치 0 · 면제는 근거 병기)'))
sys.exit(rc)


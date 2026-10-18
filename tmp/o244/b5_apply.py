# O244 B⑤ — 50_handoff 총계 현행화(80→81 · 브론즈 64→65 · ERP 2→3 · 원천 = BRONZE_ERP.SYNC_ERR_INFO 2026-10-16)
# 판정 = handoff_ddl_gate 축7 · 역사 줄은 값 보존 + 끝 주석만 현행으로 교체(R2-8). 각 치환은 기대 건수를 단언한다.
import io, os, hashlib, shutil

D = '/workspace/50_handoff/'
BK = '/workspace/tmp/o244/b5_before/'
OLD_NOTE = '(🔴 2026-10-02 현행 = 브론즈 64 · CRM 53 · SILVER 4 · ML 12 · 총계 80)'
NEW_NOTE = '(🔴 2026-10-16 현행 = 브론즈 65 · CRM 53 · ERP 3 · SILVER 4 · ML 12 · 총계 81)'
PLAN = {
    '01_데이터마이그레이션 20260730.md': [
        (OLD_NOTE, NEW_NOTE, 8),
        ('대상 80 테이블 CSV', '대상 81 테이블 CSV', 1),
        ('`BRONZE_ERP`(2) · `BRONZE_GA4`(2) · `BRONZE_GSC`(3) = **64 테이블**',
         '`BRONZE_ERP`(3) · `BRONZE_GA4`(2) · `BRONZE_GSC`(3) = **65 테이블**', 1),
        ('**80 테이블** (브론즈 64 + SILVER 4 + ML 12)', '**81 테이블** (브론즈 65 + SILVER 4 + ML 12)', 1),
        ('**80 테이블**(CRM 53 + AGENCY 4 + ERP 2 +', '**81 테이블**(CRM 53 + AGENCY 4 + ERP 3 +', 1),
        ('(64개 기대: CRM 53 / AGENCY 4 / ERP 2 /', '(65개 기대: CRM 53 / AGENCY 4 / ERP 3 /', 1),
        ('(**80** = 브론즈 64 +', '(**81** = 브론즈 65 +', 1),
        ('| **80** | — | 브론즈 64 + 위 16 |', '| **81** | — | 브론즈 65 + 위 16 |', 1),
        ('테이블 80개 생성 = 브론즈 64', '테이블 81개 생성 = 브론즈 65', 1),
        ('대조 (80 테이블)', '대조 (81 테이블)', 1),
    ],
    '02_데이터마이그 A_PRODUCER.sql': [
        (OLD_NOTE, NEW_NOTE, 2),
        ('테이블 80(브론즈 64 + SILVER 4 + ML 12)  🆕 [O198] ML 17→12 · SILVER 1→4(예측용 집계 3) · 총계 82→80',
         '테이블 81(브론즈 65 + SILVER 4 + ML 12)  🆕 [O198] ML 17→12 · SILVER 1→4(예측용 집계 3) · 총계 82→80 · 🆕 [O244] ERP 2→3 · 총계 80→81', 1),
        ('BRONZE_ERP(2) · BRONZE_GA4(2)', 'BRONZE_ERP(3) · BRONZE_GA4(2)', 1),
        ('ERP 2 · GA4 2 · GSC 3 · ML 12 · SILVER 4 = 80)', 'ERP 3 · GA4 2 · GSC 3 · ML 12 · SILVER 4 = 81)', 1),
    ],
    '03_데이터마이그 B_BROKER.sql': [
        (OLD_NOTE, NEW_NOTE, 3),
        ('후속 파일 번호 06번 → 07번(C_CONSUMER)', '후속 파일 번호 06번 → 07번(C_CONSUMER) · 🆕 2026-10-18 O244 = 범위 81(브론즈 65 · ERP 3)', 1),
        ('--   ③ BRONZE_ERP (2 테이블)', '--   ③ BRONZE_ERP (3 테이블)', 1),
        ('--   ⇒ 합계 80 테이블', '--   ⇒ 합계 81 테이블', 1),
        ('BRONZE_ERP 2 · BRONZE_GA4 2', 'BRONZE_ERP 3 · BRONZE_GA4 2', 1),
        ('· ML 12 · SILVER 4 = 80 테이블', '· ML 12 · SILVER 4 = 81 테이블', 1),
        ('BRONZE_ERP(2) · BRONZE_GA4(2)', 'BRONZE_ERP(3) · BRONZE_GA4(2)', 1),
        ('· SILVER(4) · ML(12) = 80', '· SILVER(4) · ML(12) = 81', 1),
        ("'UNLOAD 완료: 80개 테이블'", "'UNLOAD 완료: 81개 테이블'", 2),
    ],
    '08_데이터마이그 B-C 통합.sql': [
        ('(총 80개 테이블)', '(총 81개 테이블)', 1),
        ('--   ③ BRONZE_ERP (2 테이블)', '--   ③ BRONZE_ERP (3 테이블)', 1),
    ],
}


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


os.makedirs(BK, exist_ok=True)
for name, reps in PLAN.items():
    p = D + name
    a, b = h(p), h(p)
    assert a == b, 'hash unstable ' + name
    s = io.open(p, encoding='utf-8', newline='').read()
    for old, new, n in reps:
        c = s.count(old)
        assert c == n, '%s: %r count %d != %d' % (name, old[:40], c, n)
        s = s.replace(old, new)
    shutil.copyfile(p, BK + name)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK', name, 'before', a[:12], 'after', h(p)[:12])

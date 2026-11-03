# O266-C — sv_enum_newvalue_gate NEW 7 처방: COMMENT 값 목록에 라이브 값 추가(데이터 무변경 · R2-7)
#   `-`·`0` = BRONZE_AGENCY.DGT_AD_CMPGN_DTLS 원값(대행사 미분류 표기 · 디지털 1,582행 실측) ⇒ 값은 그대로 두고 뜻을 COMMENT 에 적는다
import io

MSTR = '/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql'
SENT = " · 🆕 [O266-C] ''-''·''0'' = 대행사 원천의 미분류 표기(원값 그대로 · 결측·코드 아님) · ''전체사업'' = 원천 원값"
PLAN = [
    ('/workspace/05_SV-Agent_ai/05_07_SV_DDL_AD.sql',
     "''통합 기타''·''통합 통합''·''해외 굿즈''·''해외 사례''·''해외 사업''',",
     "''통합 기타''·''통합 통합''·''해외 굿즈''·''해외 사례''·''해외 사업''·''전체사업''·''-''·''0''" + SENT + "',", 1),
    ('/workspace/05_SV-Agent_ai/05_07_SV_DDL_AD.sql',
     "''국내''·''해외''·''통합''·''전체''',",
     "''국내''·''해외''·''통합''·''전체''·''전체사업''·''-''·''0''" + SENT + "',", 1),
    ('/workspace/05_SV-Agent_ai/05_23_SV_DDL_EXPENSE_RESOLUTION.sql',
     "''가지급금''·''사업비''·''사회복지법인예산''·''옹호사업''',",
     "''가지급금''·''사업비''·''사회복지법인예산''·''옹호사업''·''업무추진비''·''운영비''',", 1),
    ('/workspace/05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql',
     "''Tizen''·''Windows''·''Windows Phone''·''iOS''',",
     "''Tizen''·''Windows''·''Windows Phone''·''iOS''·''PalmOS''·''UNIX''',", 1),
    (MSTR,
     "''지부''·''지부(사복)''·''지부외''·''협력시설''',",
     "''지부''·''지부(사복)''·''지부외''·''협력시설''·''없음''(원천 원값 · 부서4 미지정)',", 3),
]
for p, old, new, n in PLAN:
    t = io.open(p, encoding='utf-8').read()
    assert t.count(old) == n, (p, old[:30], t.count(old))
    io.open(p, 'w', encoding='utf-8').write(t.replace(old, new))
    print('ok', p.rsplit('/', 1)[1], n)

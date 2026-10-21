import io
p = '/workspace/05_SV-Agent_ai/35_O249_SV_신설_광고비배분_개발사건코호트.sql'
a = io.open(p, encoding='utf-8').read()
R = [
    ("mec.EVENT_MEMBERS AS COUNT(DISTINCT IFF(mec.MONTHS_AFTER = 0, mec.MEMBER_DK, NULL))",
     "mec.EVENT_MEMBERS AS COUNT(DISTINCT mec.MEMBER_DK)"),
    ("COMMENT = '사건 회원수(명) — 경과월 0 기준 중복제거.'",
     "COMMENT = '사건 회원수(명) — 중복제거(경과월 필터와 무관하게 같은 값).'"),
    ("COMMENT = '사건 개발(건) = MSTR 인정금액 ÷ 10,000 — 경과월 0 에서만 센다.'",
     "COMMENT = '사건 개발(건) = MSTR 인정금액 ÷ 10,000 — 경과월 0 행에만 값이 있다 ⇒ 경과월을 0 으로 두거나 경과월 필터 없이 쓴다.'"),
    ("COUNT(DISTINCT IFF(mec.MONTHS_AFTER = 0 AND (mec.AT_D0_AUTO_FLAG OR mec.AT_D0_MANUAL_FLAG), mec.MEMBER_DK, NULL))",
     "COUNT(DISTINCT IFF(mec.AT_D0_AUTO_FLAG OR mec.AT_D0_MANUAL_FLAG, mec.MEMBER_DK, NULL))"),
    ("COUNT(DISTINCT IFF(mec.MONTHS_AFTER = 0 AND mec.SND_D0_5_OPEN_FLAG, mec.MEMBER_DK, NULL))",
     "COUNT(DISTINCT IFF(mec.SND_D0_5_OPEN_FLAG, mec.MEMBER_DK, NULL))"),
]
t = a
for x, y in R:
    assert t.count(x) == 1, x[:50]
    t = t.replace(x, y)
io.open(p, 'w', encoding='utf-8').write(t)
print('ok')

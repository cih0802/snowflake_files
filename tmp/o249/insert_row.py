import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
row = ('| 🟡 **`O249`** — LTV 상한 계산형(CEIL(AVG(관측 중 회원 유지개월)) · LTV_CAP_AVG_ACTIVE_MONTHS) · 배분 개발구분 축 · SV 2종 · 3 Agent 예측 가드레일 · CoCo 차단 테스트 '
       '(2026-10-20 · TRIALADMIN(SR61467) · ㉡ · 사용자 승인 전부 · 확정위반 1 · 단위 O249-A) · 라이브 = FACT_MEMBER_COHORT_SURVIVAL(RENAME) · SV_MEMBER_COHORT · ML_DVLP_FORECAST_ALLOC_V · SV_ML_DVLP_FORECAST · SV_AD_INFLOW_ALLOC(신규) · SV_MEMBER_EVENT_COHORT(신규) · Agent EXEC $4 · MKT $5 · MEM $4 · GN_ANALYST_01 '
       '| 🟡 스모크 5/5 · 상한 80 재현 · 축 합 일치 · 👤 잔여 = dbt build FMCS · A3 ㉠~㉤ 사람 확인 · 미연결 캠페인 1,608건 현업 송부 '
       '| `tmp/o249/` · `05_SV-Agent_ai/35_O249_SV_신설_광고비배분_개발사건코호트.sql` '
       '| `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0249-A.md` |\n')
lines = io.open(p, encoding='utf-8').readlines()
assert not any('`O249`' in l for l in lines)
idx = next(i for i, l in enumerate(lines) if '**`O248`**' in l)
lines.insert(idx, row)
io.open(p, 'w', encoding='utf-8').write(''.join(lines))
print('inserted at', idx + 1)

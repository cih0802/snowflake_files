"""[O187-D] 단위 종료 기록 — 원장 행 · 이력 · 인수인계 본문(셸 파서 회피)."""
import io
P = '20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
L = io.open(P, encoding='utf-8').read().split('\n')
if not any(l.startswith('| 🔴 **`O187-D`**') for l in L):
    i = next(k for k, l in enumerate(L) if l.startswith('| 🟢 **`O187-C`**'))
    L.insert(i, '| 🔴 **`O187-D`** — 30_output_share 전체 재생성 + 수기 10종 최신화 · 🔴🔴 GA4 체인 전체 0행 발견(09-27 DDL 재생성 후 3일 창 적재) '
                '| 🔴 백필 대기 · 골든 갱신 보류 | **[2026-09-28 O187-D · xf98254 · 정본 = 라벨 `-O0187-D.md`]** | 원장 §1 · 이력 §O187-D |')
    o = '\n'.join(L); n = len(o.encode()); assert n <= 40960
    io.open(P, 'w', encoding='utf-8', newline='').write(o); print('ledger free', 40960 - n)

io.open('tmp/_o187d_hist.md', 'w', encoding='utf-8').write(
"\n> #### 🔴 [2026-09-28 O187-D] 30_output_share 최신화 · 🔴🔴 GA4 체인 전체 0행 발견\n\n"
"- 자동 생성 11종 재실행 전건 rc=0(선행 `dump_schema.py`·`census_columns.py` 필요 · 🔴 1차 셸 스크립트가 `>>` 로 로그를 쓰다 마운트에서 유실 ⇒ 단계별 `>` 로 재실행)\n"
"- 수기 10종(01·10·15~22) 머리에 「2026-09-28 최신화」 블록 · 거짓이 된 문장 3곳 옆 포인터 · 00 매핑에 12~14 아카이브 위치\n"
"- `test_generators.py` = PASS 19 · FAIL 2(골든 29차 · T5 freshness) ⇒ **골든 갱신 보류** — 09 차이의 주원인이 아래 결함이다\n"
"- 🔴🔴 **GA4 체인 0행** = `BIGQUERY_BASIC` 등 SILVER 6 · `FACT_BIGQUERY_BEHAVIOR`·DIM 2(1행 센티넬) · 원천 `BIGQUERY_REFINED_DATA` 11,468,600행(33일 · 2024-01-16~2026-09-15)\n"
"  · 원인 = `BIGQUERY_BASIC` 등이 **09-27 21:16 빈 채 재생성**(O182 08 DDL 전체 재실행) → 이후 run 은 `is_incremental()` = 창 3일만 적재 → 원천(월 1일 샘플)에 그 창이 없다\n"
"  · 🔴 O183-B 가 WARN 「BigQuery 적재 공백 1」 을 **「의도된 경보」로 분류**했다 — 그것이 이 결함의 실경보였다(오분류)\n"
"  · 처방 = O187-C 에서 검증한 ARGS 백필 1줄(사용자 실행 · R4-1)\n")

print('ok')

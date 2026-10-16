### ▣ O241-A-0 🔴 먼저 알아라

- 작성 = trialadmin(mn11232) · 2026-10-16 · ㉡ · 사용자 결정 = 공91 B 귀속 ㉡(직전 발송 1건) · B안 정의 계획대로 · ⑥ 누락은 목록 보고 후 결정.
- §0 라이브(이 계정) = A/B metric 9개 실재 · AGENT_MEMBER·MARKETING `VERSION$3`(새 계정 · 번호 재시작 ⇒ O240 의 $7·$5 기준점은 무효).
- 🔴 O241 변경은 **라이브 미배포**다 — `05_SV-Agent_ai/32_O241_AB병기_SV배선_배포순서.sql` D1~D5 👤 실행 대기(dbt → SV 3 → Agent 2 순서).
- 🔴 계획 §2-3 「--full-refresh 필수」는 틀렸다(silver·gold.fact = append_new_columns + purge) — 배포순서 32 를 따른다.

### ▣ O241-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① dbt | FMD `D5_GIFT_PART_AMT`(선물금 1건 = 직전 발송일 1개 · 사전 실측 1,303,750,000원 · 쌍별이면 +22%) · BQ SESSION_END_TS · FBS `SESSION_DURATION_SEC` · 06_DDL·yml 동기 |
| ② SV | SV_SERVICE.D5_GIFT_AMT · SV_RELATION_ACTIVITY 공91A 동의어 · SV_GA_SESSION.AVG_SESSION_DURATION_SEC + 병기 규칙 (6) + VQR |
| ③ Agent | MEMBER ⑤ 공91 A/B · MARKETING ⑤ 공98 A/B(EXECUTIVE = 도구 없음 · 코퍼스 = 빌더 거부로 비대상) |
| ④ ⑥ 생성기 | `SV_배선`·`Agent_배선` 열 · 상태 분포 불변 · `scripts/test_metric_sv_wiring.py` 14/14(음성 실증) · 골든 재발행 |

### ▣ O241-A-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 배포순서 32 D1~D5 실행 + D2 대사 기대값 확인 + 스모크 4문항 | 👤 사용자 |
| ② | ⑥ 누락 121건 처리 방식 결정 = 동의어 있음·토큰만 없음 31 / 동의어 없음 90 — 목록 `tmp/o241/unwired_121.csv` | 👤 사용자 결정 |
| ③ | 생성기 `MEASURE_OVERRIDE` 공91 = 죽은 컬럼 GIFT_PART_AMT 측정(WAIT 유지) — 배포 후 측정 대상 교체 여부 | 다음 세션 |

### ▣ O241-A-3 ㉡ 워크스페이스 백로그(승계)

- O240-A/B/C 의 ①(배포 30 D2·D5 미확인) · ②~⑤(현업·운영계 확인) 는 그대로 열려 있다.

### ▣ O241-A-4 ⚪ 결정 완료(재론 금지)

- 공91 B = 발송 D+1~D+5 선물금 · 선물금 1건은 가장 가까운 직전 발송일 1개 귀속 · 처리통보성 제목 제외.
- 공98 B = UA식 세션 지속시간(마지막 − 첫 이벤트) · 자정 경계 세션은 첫 일자 행에만.
- 05 매핑 = 상태(물리 채움률)와 배선 축을 섞지 않는다.

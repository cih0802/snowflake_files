### ▣ O245-B-0 🔴 먼저 알아라

- `O245-B` = O245-A 승계(같은 날 · trialadmin(iw20760) · 사용자 지시 = ML 특성 표 「○」 칸 Agent 응답 테스트).
- 근거 = `tmp/o245/agent_test/_judge.md`(17문항 원문 판정) · 재시험 = `tmp/o245/agent_test_retest/_judge.md` · 기대값 = `_expected.json`(SV 직접 질의).
- 🔴 러너 자체 판정(`_summary.json` 의 err·tok)은 쓰지 마라 — err 는 SV 지침 문구 「invalid identifier」 오탐 · tok 은 SQL 위치 오판이다. 판정은 `agent_judge.py`(결과표 ↔ 기대값).

### ▣ O245-B-1 이번 단위 결과

| 구분 | 결과 |
|---|---|
| 1차 17문항(AGENT_MEMBER) | 정답 14 · 오답 1(C1 후원사업별 → sponsor_risk 로 라우팅) · 표기 결함 2(M4·M5 ROLLUP 합계 행이 (미매칭)) · 데이터 없음 2/2(N1·N2) |
| 시정 | AGENT_MEMBER 54행 규칙 + 3종 churn_campaign 도구 설명에 cs 후원사업 축 · SV 3종 AI_SQL 에 ROLLUP 합계 행 규칙 · 법인구분 문안 = 통합·사단·사복(CM019 3종) |
| 재시험 C1·M4·M5 | 3/3 · C1 = 해외아동결연 183,235 / 1,386 등 기대값 일치 |
| 배포 | 21·22·25 재배포 · Agent 3종 신규 버전(MEMBER · EXECUTIVE · MARKETING · 롤백 = 직전 버전) |

### ▣ O245-B-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 운영계 반영 대상에 Agent MEMBER spec 추가(O245-A ② 와 합쳐 반영) | 👤 사용자 |

### ▣ O245-B-3 ㉡ 워크스페이스 백로그

- O245-A ㉡ ③~⑦ 그대로(현업 회신 · eval 은 사용자 제외 지시 유지).

### ▣ O245-B-4 ⚪ 결정 완료(재론 금지)

- O245-A ▣ -4 그대로.

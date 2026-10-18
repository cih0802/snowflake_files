<!-- LLM-METADATA
doc_id: HANDOFF_O0242_B
doc_role: 인수인계 — 세션 `O242-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-18
created_by: O242-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0242-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O242-B-0 🔴 먼저 알아라

- `O242-B` = O242-A 승계(같은 날 · trialadmin(mn11232) · 사용자 승인 = 발견 결함 3건 전부 시정).
- 🔴🔴 **계정 mn11232 가 정지됐다**(`000666 Your account is suspended due to lack of payment method` · 2026-10-18 04:30 무렵).
  메타데이터 조회는 되고 웨어하우스 연산은 전부 거부된다 ⇒ native eval o242b 는 **시작 전 실패(과금 없음)**.
  ⇒ 다음 세션은 결제 수단 복구 여부를 먼저 확인하고, 복구됐으면 `PYTHONDONTWRITEBYTECODE=1 python3 tmp/o242b/eval_b.py` 를 다시 돌린다(스모크는 끝나 있어 eval 만 시작한다).
- 정지 전 개발계 집행 완료 = SV 19파일 재배포 · Agent 3종 VERSION$8(default · 롤백 $7) · S4 재스모크 통과.
- 🔴 `py_compile` 을 마운트 아래 파일에 쓰지 마라 — `__pycache__` 쓰기에서 I/O 오류(Errno 5)가 난다 ⇒ `PYTHONDONTWRITEBYTECODE=1`.

### ▣ O242-B-1 이번 단위 결과

| 단위 | 결과 |
|---|---|
| ① VQR 31건 | 17파일 · 원 SQL 바깥 감싸기(한글 별칭 · 비율·평균·확률 ROUND(,2)::NUMBER) · 매핑 = `tmp/o242b/apply_vqr.py` · 임시 이름 검증 24 SV PASS · 잔여 결함 0 |
| ② 구축 순서 | ML_CHURN_BY_CMPGN_CTGR_V 정의(58줄 + GRANT 3) 25 → 21 이동 · 해시 동일 · 25 머리말·포인터 · 라이브 조회 정상 |
| ③ Agent | EXEC LC 하락 원인 = ③ 「system_execute_sql 직접 SQL 금지」가 플랫폼 정상 경로(analyst 문맥 → system_execute_sql)를 위반으로 읽게 했다(D4·D1·M1·Q15 판정문) ⇒ ③ 정정 · ㉥ 이물 문자 점검 · MEMBER 캠페인별 예측+특성 → churn_campaign 1회 |
| 재평가 | S4 F1~F5 통과(36.8초) · native eval 🔴 계정 정지로 미실행 |

### ▣ O242-B-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 계정 결제 수단 복구 후 eval o242b(V6 · VERSION$8) 실행 · o241s 와 비교(특히 EXEC LC · MEMBER Q01 TS) | 👤 계정 복구 → 다음 세션 |
| ② | 👤 운영계 = 32 D1~D5 후 33 D0~D4(O242-B 변경 포함) | 👤 사용자 |

### ▣ O242-B-3 ㉡ 워크스페이스 백로그(O242-A ㉡ 승계 · 변경 없음)

| 순 | 작업 | 판정 |
|---|---|---|
| ③ | O241-B ㉠ ②·③ = 배선 보류 14건 · MEASURE_OVERRIDE 공91 | 👤 결정 / 다음 세션 |
| ④ | O240 배포순서 30 D2 대사 · D5 스모크 5문항 | 👤 사용자 |
| ⑤ | 현업 A/B 결정 후 다른 안 회수(공#122·공#81·공91·공98) | 현업 → dbt |
| ⑥ | O238 W5·W6 · 미매칭 41행 · 현업 확인 목록 · 회비원장 2022-01 이전 · 2026 편성 0 | 현업·운영계 |

### ▣ O242-B-4 ⚪ 결정 완료(재론 금지)

- VQR 은 원 SQL 을 바꾸지 않고 바깥 SELECT 로 한글 별칭·반올림을 입힌다(CTE 내부 별칭 보존 · 값 무변경 보장).
- analyst 도구 → system_execute_sql 실행은 정상 경로다 — 지시는 「금지」가 아니라 「그 SQL 도 SV 규칙을 지킨다」로 쓴다.
- ML_CHURN_BY_CMPGN_CTGR_V 정의 정본 = 21(25 는 SV 만).

_Co-authored with CoCo_

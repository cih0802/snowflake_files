### ▣ O187-A-0 🟢 이 단위가 끝낸 것 (2026-09-28 · xf98254 · 사용자 포괄 승인)

- **3행** — 사용자 전체 build PASS 543·WARN 21·ERROR 0(GN_DW_DBT · 01:29) ⇒ WIDE_AD_COMBINED.RT_TYPE COMMENT `DIV_NM` 반영 확인 ·
  런북 2곳(`02_dbt_parse_compile_build.sql:110` · `11_일적재pipeline 구성/00_개요_및_실행순서.md:82`)을 「현상 · 원인 미확정 · 판별 실험」으로 정정 ·
  🔴 `--vars` 실험 A·B 는 **미실행**(전체 build 만 돌았다) ⇒ 원인 판정은 남는다
- **2행** — 열린 판정 36건 전수 좌표화(`tmp/_o187_open.tsv`) · 전제 변동 6건 판정 = 문서20 **N-25**
  (AD-5 전제 거짓 · AD-2 재현 불가 · AD-3 참 · E/M-4 N-23 로 재발행됨 · D-2 실측상 CRM)
- **10행** — 문서30 §30-I 「미실행」 stale 표기 정정 + ⑥ 원문 처방이 오처방임을 명시(원천 병합 키 42건 상존)
- **8행 진단** — 스모크 중간 오류의 원인 = Agent **agentic SQL 모드**(`system_execute_sql`)가 CTE(`__fee` 등)에 **베이스 컬럼**만 노출하는데
  LLM 이 **SV metric 이름**(`total_billed_amt`)을 컬럼처럼 쓴다 ⇒ SV 정의 결함이 아니다 · SV 수정으로 고쳐지지 않는다

---

### ▣ O187-A-1 🟠 미처리 작업 — 파이프라인 순 × 중요도

| 순 | 계층 | 중요도 | 작업 | 상태(O187 J3) | 정본 |
|---|---|---|---|---|---|
| 1 | 원천·현업 | 🔴 | 문서20 회신 — N-23 · N-24 · N-25(AD-5 폐기 확인 포함) · §N-13 · §D-2 · §L 외 **30건** | 회신 대기 | 문서20 `-010` · `tmp/_o187_open.tsv` |
| 2 | 운영 | 🟠 | `--vars` 실험 A·B(사용자) — 결과로 런북 금지문의 **원인** 확정 | dbt 정지점 | ▣2 |
| 3 | SILVER | 🔴 | CRM 사업목표 배선 | N-24 ① 회신 대기 | 문서20 N-24 |
| 4 | SILVER | 🟠 | AGENCY 신규 컬럼 GOLD 승격 | 요건 대기 | `-O0182-A` ▣2-4 |
| 5 | GOLD | ⚪ | 공란 잔여 | 원천·결정 대기 | DEC-55 §55-C |
| 6 | SV | 🟡 | 비율 지표 · VIDEO 방송 개발단가 metric | 정의 대기(N-25 AD-5 회신 연동) | `-O0183-A` ▣2-4 |
| 7 | Agent | ⚪ | agentic SQL 모드 metric/컬럼 혼동 — Agent orchestration 에 「`__` CTE 에는 metric 이 없다 · 베이스 컬럼을 집계하라」 1줄 추가 후 스모크 재측정(선택 · 과금) | 진단 완료 · 처방 선택 | ▣0 |
| 8 | 품질 | 🟠 | WARN 21 잔여 추적 | 원천 정정 대기 | `-O0183-B` ▣1 |
| 9 | 문서 | ⚪ | W3 8건 · B2~B12 · `sv_code_label_gate` 재측정 조건 · 해소로그 `-016` 여유 7,134 B | 변동 없음 | `-O0181-A` ▣3 |

🟢 닫힘(O187) = 구 2(36건 J3) · 구 3 중 RT_TYPE·런북 · 구 10(§30-I) · 구 8 은 진단으로 ⚪ 강등.
🔴 **이 표의 잔여는 전부 외부 입력 대기다**(현업 회신 · 요건 · 사용자 dbt · 선택 과금) — 에이전트 단독 착수 가능 항목은 7행뿐이다.

---

### ▣ O187-A-2 ⏸ dbt 정지점 (`R4-1`) — 사용자 실행

```sql
USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars ''{"bigquery_lookback_days": 999}''';   -- 실험 A
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars "{bigquery_lookback_days: 999}"';     -- 실험 B
```
· 판정 = 컴파일 SQL 의 BigQuery 창 하한이 **999일 전**이면 전달됨 · **3일 전**이면 실패 · 두 실행의 query_id 를 알려주면 에이전트가 컴파일 결과를 조회한다

---

### ▣ O187-A-3 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 1. 브리핑 생성 후 인수인계 99_NEXT_SESSION-O0187-A.md ▣1 표를 정본으로 삼는다.
2. 표의 각 항목을 착수 전에 J3 실측으로 재판정한다(이미 닫힌 것은 닫힘으로 표기 · 정본 좌표도 실재를 확인한다).
3. ▣2 실험 결과(사용자 붙여넣기)가 있으면 먼저 2행을 판정하고 런북 2곳의 원인 문안을 확정한다.
4. 문서20 에 회신이 들어왔는지 `**판정**:` 줄을 grep 해 확인하고, 들어온 것부터 배선한다.
5. 파이프라인 순(원천→권한→SILVER→GOLD→SV→Agent→문서)으로, 같은 계층은 🔴→🟠→🟡→⚪ 순으로 진행한다.
   - 승인 필요 작업은 사용자 포괄 승인 상태다 — SQL 을 먼저 보여주고 재조회로 확인한다.
   - dbt 명령은 제시 후 대기한다(R4-1) · 모델·profiles 를 고치면 DW_PIPELINE 재배포 명령까지 함께 제시한다.
6. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일을 갱신하고 게이트(gate_census --final · doc_census · index_row_gate · line_len)를 통과시킨다.
7. 끝나면 남은 작업을 같은 형식(파이프라인 순 × 중요도 표 + 복붙 프롬프트)으로 정리한다.
```

_Co-authored with CoCo_

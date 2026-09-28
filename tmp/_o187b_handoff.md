### ▣ O187-B-0 🟢 이 단위가 끝낸 것 (2026-09-28 · xf98254)

- **`--vars` 판정** — 실험 A·B 모두 창 하한 `20240103`(= 실행일 − 999일) ⇒ **`EXECUTE DBT PROJECT` 경로에서 전달된다**.
  종전 「동작하지 않는다」는 **Workspaces dbt 클라이언트 경로 한정** 사실이었다(공백 절단·인용부호 제거).
  🔴 판정식 = **「어디서 실패했는가」를 적지 않은 금지문은 일반화된다** — 같은 기능이 경로마다 다르게 동작했다.
- 정정 4곳(주석만 · 로직 무변경): `02_dbt_parse_compile_build.sql` Step 3 · `11_일적재pipeline 구성/00_개요_및_실행순서.md:82` ·
  `macros/bigquery_range_predicate.sql` 헤더 · `dbt_project.yml` vars 주석
- 문서20 회신 확인 = 판정줄 56 · 기록 20 · 미회신 36 ⇒ **신규 회신 0**(배선 착수 대상 없음)

---

### ▣ O187-B-1 🟠 미처리 작업 — 파이프라인 순 × 중요도

| 순 | 계층 | 중요도 | 작업 | 상태(O187-B J3) | 정본 |
|---|---|---|---|---|---|
| 1 | 원천·현업 | 🔴 | 문서20 회신 36건(N-23 · N-24 · N-25 · §N-13 · §D-2 · §L 외) | 회신 대기(신규 0) | 문서20 `-010` · `tmp/_o187_open.tsv` |
| 2 | 운영 | 🟡 | 리스트 var `bigquery_dt_ranges` 의 `--vars` 전달 실측(선택) — 되면 백필 런북을 「재배포 없이 ARGS 1줄」로 단순화 | dbt 정지점(선택) | ▣2 |
| 3 | SILVER | 🔴 | CRM 사업목표 배선 | N-24 ① 회신 대기 | 문서20 N-24 |
| 4 | SILVER | 🟠 | AGENCY 신규 컬럼 GOLD 승격 | 요건 대기 | `-O0182-A` ▣2-4 |
| 5 | GOLD | ⚪ | 공란 잔여 | 원천·결정 대기 | DEC-55 §55-C |
| 6 | SV | 🟡 | 비율 지표 · VIDEO 방송 개발단가 metric | 정의 대기 | `-O0183-A` ▣2-4 |
| 7 | Agent | ⚪ | agentic SQL metric/컬럼 혼동 처방 + 스모크 재측정(선택 · 과금) | 진단 완료 | `-O0187-A` ▣0 |
| 8 | 품질 | 🟠 | WARN 21 잔여 추적 | 원천 정정 대기 | `-O0183-B` ▣1 |
| 9 | 문서 | ⚪ | W3 8건 · B2~B12 · `sv_code_label_gate` 재측정 조건 | 변동 없음 | `-O0181-A` ▣3 |

🟢 닫힘(O187-B) = 구 2(`--vars` 원인) — 경로 한정으로 확정 · 런북 4곳 정정.
🔴 **에이전트 단독 착수 가능 항목 = 7행(선택)뿐이다** — 나머지는 현업 회신·요건·사용자 dbt 대기.

---

### ▣ O187-B-2 ⏸ dbt 정지점 (`R4-1`) — 선택 실험 + 주석 반영 재배포

```sql
USE ROLE GN_DW_ADMIN;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';  -- 주석 정정 반영(로직 무변경 · 선택)
USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars ''{"bigquery_dt_ranges": [["2025-06-01", "2025-06-30"]]}''';  -- 리스트 var
```
· 판정 = 컴파일 SQL 창이 `(EVENT_DATE between '20250601' and '20250630')` 이면 리스트도 전달된다 ⇒ 백필 런북 단순화 가능

---

### ▣ O187-B-3 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 1. 브리핑 생성 후 인수인계 99_NEXT_SESSION-O0187-B.md ▣1 표를 정본으로 삼는다.
2. 표의 각 항목을 착수 전에 J3 실측으로 재판정한다(이미 닫힌 것은 닫힘으로 표기 · 정본 좌표도 실재를 확인한다).
3. ▣2 실험 결과(사용자 붙여넣기)가 있으면 먼저 2행을 판정하고 백필 런북(02 Step 3 ㉠~㉤)을 갱신한다.
4. 문서20 에 회신이 들어왔는지 `**판정**:` 줄을 세어(기록 20 · 미회신 36 기준) 확인하고, 들어온 것부터 배선한다.
5. 파이프라인 순(원천→권한→SILVER→GOLD→SV→Agent→문서)으로, 같은 계층은 🔴→🟠→🟡→⚪ 순으로 진행한다.
   - 승인 필요 작업은 사용자 포괄 승인 상태다 — SQL 을 먼저 보여주고 재조회로 확인한다.
   - dbt 명령은 제시 후 대기한다(R4-1) · 모델·profiles 를 고치면 DW_PIPELINE 재배포 명령까지 함께 제시한다.
6. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일을 갱신하고 게이트(gate_census --final · doc_census · index_row_gate · line_len)를 통과시킨다.
7. 끝나면 남은 작업을 같은 형식(파이프라인 순 × 중요도 표 + 복붙 프롬프트)으로 정리한다.
```

_Co-authored with CoCo_

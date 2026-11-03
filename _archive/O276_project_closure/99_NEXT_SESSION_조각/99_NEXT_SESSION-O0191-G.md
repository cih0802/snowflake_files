<!-- LLM-METADATA
doc_id: HANDOFF_O0191_G
doc_role: 인수인계 — 세션 `O191-G` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191-G
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0191-G -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O191-G-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 사용자 보고: `dbt build`(SILVER 9종+) PASS=363 WARN=18 ERROR=0 ⇒ O191-F 반영 완료.
- 🟢 SILVER 2차-B 99컬럼 라이브 실측 = **99/99 채움**(0건 컬럼 0) · 근거 = `tmp/o191g_fill.txt`.
- ⏸ **dbt build 1회 필요** — GOLD 6종 모델 변경(2차-B GOLD 전파 38컬럼) · 06_DDL + ADMIN ALTER 38/38 선행
  · LIMIT 0 컴파일 6/6 · 라이브 ordinal 일치 6/6(`tmp/o191g_compile.txt`).
- 🔴 사용자 순서 지시 유지: ① 테이블 → ② SV → ③ 스모크 → ④ 신규 발견 작업 → ⑤ 산출물(프롬프트).
- 🔴🔴 **계정 정지** — 세션 말미 `gold_erd_coverage_gate` 재실행이 `000666 Your account is suspended due to lack of payment method`
  로 실패(bt97381). ⇒ 결제수단 등록 전에는 build·SV·스모크 전부 불가.
  · ERD 미분류 2건(FMD `RELATNSP_KEY`·`MSG_KEY`)은 DEGEN 등재 완료 · 🟠 라이브 재판정 미실행 · 오프라인 `test_gold_erd` 49/49.

### ▣ O191-G-1 🟢 이 단위가 끝낸 것

- GOLD 전파 = 문서32 §3 원칙(같은 grain degen) — DIM_EVENT 10 · DIM_CAMPAIGN 7 · DIM_MEMBER 3
  · DIM_SPONSORSHIP 2 · FACT_EVENT_ATTENDANCE 8 · FACT_MESSAGE_DISPATCH 8.
- 🟢 `FACT_EVENT_ATTENDANCE.SELF_PART_FLAG` 종전 전건 NULL → MS060(0 동반자만=FALSE · 1 본인만·2 함께=TRUE) 배선.
- 🟠 보류(받을 같은 grain GOLD 없음) = 발송요청 16 · 발송결과 7(요청 grain 차원 부재 · DIM_SERVICE 10행 집계)
  · 청구 7(FME/FMF 는 월 집계) · 결제수단 13(DIM_PAYMENT = 코드 grain) · 결연활동 12 · 코드 4 · 후원시간 2.
  ⇒ SILVER 에서 직접 조회 가능 · GOLD 신설(요청 grain 차원·결연활동 팩트)은 설계 결정 대상.

### ▣ O191-G-2 🟠 남은 작업

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | dbt build(GOLD 6종+) | 사용자 실행(`R4-1`) | ▣3 명령 |
| 2 | SV 반영 | COMMENT 실제값은 라이브 실측 규약 ⇒ build 후 | EVENT_PARTICIPATION(본인참여·동반수·장소) · SERVICE(확인여부·대체문자) · 회원(문자수신) |
| 3 | 스모크 재측정 | 과금 · ② 이후 | 기준선 2 대비 |
| 4 | 보류 55컬럼 GOLD 신설 여부 | 설계 결정 | 요청 grain 차원 · 결연활동 팩트 |
| 5 | `rename_stale_gate` 축1 +1 | 사용자 파일 `02_GN_DW_building/20_일배치테스트용.sql` | 사용자 확인 |
| 6 | 산출물 03~09 + 골든 | 지시 순서 ⑤ | 프롬프트 입력 시 |

### ▣ O191-G-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_EVENT+ DIM_CAMPAIGN+ DIM_MEMBER+ DIM_SPONSORSHIP+ FACT_EVENT_ATTENDANCE+ FACT_MESSAGE_DISPATCH+';
```

_Co-authored with CoCo_

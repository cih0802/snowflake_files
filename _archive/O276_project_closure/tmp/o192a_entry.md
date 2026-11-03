### ▣ O192-A-0 🔴 먼저 알아라 (2026-09-30 · 문서작업 계정 · DB 없음)

- 🔴🔴 **구 계정 bt97381 은 결제수단 부재로 정지**(`000666`)됐다 ⇒ O191-G 의 GOLD 전파 build · 라이브 ERD 재판정 · SV · 스모크가 **미실행으로 끊겼다**.
- 🟢 **다음 세션 = 새 개발 계정에서 데이터 입고 직후**다. 이 파일이 O191-A~G 7단위의 잔여를 **하나로 합친 현행 시작점**이다(O191 형제 파일은 근거로만 연다).
- 🔴 **이 파일의 수치는 전부 구 계정 실측이다** — 새 계정에서는 **기준선이 아니다**(`R2-8-4`). 기대값으로만 쓰고 재측정한다.
- 🆕 **[2026-09-30] 운영계 ML 결과 테이블 3종 삭제** — `ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT` · `_SPNSR_BSNS_ID_DVLP_AMT` · `_NEW_OLD_DVLP_AMT`.
  · 운영계 CoCo 가 문서를 이미 고쳤다: `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` 308·314·320행 `-- ⛔ [2026-09-30]` 표식(3구간 주석 · TOTAL·CAMPAIGN 2종만 활성)
    · `22_ML_SV_DDL.sql` [3] SV_ML_DVLP_FORECAST 2종 문안 · `cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml`(「부서·후원사업·신규기존 예측 미제공」).
  · 🔴 새 계정에서 **이 3종이 입고되더라도 주석을 임의로 되살리지 않는다** — 재활성은 사용자 결정 사항이다(▣3 D-3).

### ▣ O192-A-1 🔴 방안 변경 — 「부분 build 이어가기」가 아니라 「전체 재구축 1회」

| 축 | 구 계정 방식(O191) | 새 계정 방식(이번) | 이유 |
|---|---|---|---|
| DDL 반영 | DDL 파일 수정 + **ADMIN ALTER** 로 라이브 증설 | **DDL 파일로 처음부터 생성** · ALTER 불필요 | 빈 계정이라 증설할 기존 테이블이 없다. DDL 파일이 이미 최종 컬럼을 담고 있다(O191-A·E·F·G 모두 「DDL 선행」 완료) |
| dbt | 단위별 `--select` 5회(DIM_ORG · SILVER 5 · SILVER 9 · GOLD 6) | **전체 `build` 1회** | 부분 build 는 라이브에 앞 단계가 있을 때만 유효하다. 새 계정에는 없다 |
| SV·Agent | 변경분만 재배포 | `05_*` 전량 → `21`·`22` → `09_1` → `09_2` **순서 재생** | 새 계정엔 객체가 0개다. `09_1 [1]`(CREATE OR REPLACE) 은 **새 계정에서만 허용**(`99_next_prompt.md` §5) |
| 기준선 | 스모크 오류 2 · build PASS 577 | **새로 잰다** | 적재 범위가 바뀌면 분모가 바뀐다 |

> 🔴 ⇒ O191-A·E·F·G 의 **▣3 dbt 정지점 명령 4개는 새 계정에서 쓰지 않는다**(▣2 의 전체 build 로 대체).
> 🔴 절차 정본 = `60_repeat_어카운트시작/readme.md`(구조 재구축 · 실물 파일은 커밋 `20260825_가오픈정리` 에서 복원) · 그 뒤 판본 변경(05 분할 · 09 분해)은 `05_SV-Agent_ai/99_next_prompt.md` §5 실행 순서가 정본.

### ▣ O192-A-2 🟠 입고 후 작업 순서 (사용자 순서 지시 ①~⑤ 유지)

**0단계 — 착수 판정(에이전트 · 읽기 전용)**

| # | 확인 | 통과 조건 | 실패 시 |
|---|---|---|---|
| 0-1 | `SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_ROLE();` | 기록만(판정 근거 아님 · 문서92 §0) | — |
| 0-2 | BRONZE 입고 범위 — 스키마별 테이블 수 · 행 수 · 기간(MIN/MAX 기준월) | 사용자가 말한 입고 범위와 일치 | 멈추고 보고 · 부분 입고면 「적재 후에만 판정」 항목(문서92) 보류 |
| 0-3 | `SHOW TABLES IN SCHEMA GN_DW.ML` — 결과 16종 중 무엇이 왔는가 | 🔴 삭제 3종 **유무를 기록**만 한다 | 3종이 있어도 ▣0 규칙대로 주석 유지 · 사용자에게 보고 |
| 0-4 | 역할·WH·스키마 존재(`02_SERVING_setup.sql` 대상) | 6역할 · 3WH · SERVING 스키마 | 사용자 실행 대상으로 제시 |

**① 테이블 — 전체 재구축**(🔴 dbt 는 사용자 실행 · `R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';
```

- 🔴 DBT PROJECT 객체가 새 계정에 없으면 `CREATE DBT PROJECT` 가 먼저다(`dbt-projects-on-snowflake` 스킬 · 계정 재구축 런북).
- 판정(에이전트) — 구 계정 기대값과 **대조만** 한다:
  - build 결과 ERROR=0 (구 계정 PASS 577 · WARN 21 은 참고치).
  - SILVER 2차-B **99컬럼**(O191-E 21 + O191-F 78) 채움 — 0건 컬럼 0 이어야 한다(구 판정 근거 `tmp/o191g_fill.txt`).
  - GOLD 전파 **38컬럼**(DIM_EVENT 10 · DIM_CAMPAIGN 7 · DIM_MEMBER 3 · DIM_SPONSORSHIP 2 · FACT_EVENT_ATTENDANCE 8 · FACT_MESSAGE_DISPATCH 8) 채움 · 라이브 ordinal = DDL 순서.
  - `FACT_EVENT_ATTENDANCE.SELF_PART_FLAG` — 종전 전건 NULL 이었다 ⇒ TRUE/FALSE 분포가 나와야 한다(MS060 0=FALSE · 1·2=TRUE).
  - `DIM_ORG.ACMSLT_DIV_*` 도달(구 ZB 454 · ZC 450 · DEC-56 · 과거 실적부서 218 은 현재 부서와 **연결하지 않는다**).
  - 게이트 재실행: `gold_erd_coverage_gate`(🟠 FMD `RELATNSP_KEY`·`MSG_KEY` DEGEN 등재분 **라이브 재판정 미실행** — 이것이 구 계정 마지막 실패 지점) · `table_ddl_column_gate` · `sv_code_label_gate`.

**①-b ML 권한(DEC-57)** — `GN_DW.ML` 에 ANALYST USAGE·SELECT(ALL·FUTURE) 부여(종전 「권한 없음」 방침은 폐기됐다).
- 🔴 앞 대화의 교훈: `does not exist or not authorized` 는 **권한보다 객체 부재를 먼저 의심**한다(`SHOW TABLES` 로 실재 확인 → 그다음 GRANT). 삭제 3종은 GRANT 로 해결되지 않는다.

**② SV 전부** — 순서 = `02_SERVING_setup` → `05_0`·`05_1~05_11` → `21_ML_SERVING_뷰_DDL` → `22_ML_SV_DDL` → 각 파일 GRANT 절.
- 🆕 **SV 반영 대기분(O191-G 잔여 2)** — 실제값 COMMENT 는 **라이브 실측 후에만 적는다**(SV COMMENT 규약 · 수치 금지 · 코드값은 열거):
  - `SV_EVENT_PARTICIPATION` = 본인참여(`SELF_PART_FLAG`) · 동반수 · 장소
  - `SV_SERVICE` = 확인여부 · 대체문자
  - 회원 계열 SV = 문자수신
- 🆕 **Agent 도구 설명 — 본부/지부 축 반영**(O191-B 잔여 · 다음 스모크 전).
- `21` 은 TOTAL·CAMPAIGN 2구간만 활성인지 확인: `SELECT SERIES_TYPE, COUNT(*) FROM GN_DW.SERVING.ML_DVLP_FORECAST_V GROUP BY 1;` → 2행.
- 각 SV ANALYST 조회 1건씩 실증 · `sv_code_label_gate` blocking 0.
- Agent = `09_1_AGENT_생성.sql`(껍데기 · 새 계정이라 [1] 허용) → `09_2_AGENT_버전업.sql`(stage 정본 yaml 발행) · 3 Agent(MEMBER · EXECUTIVE · MARKETING) · CoWork ADD AGENT 멱등 블록.

**③ 스모크 재측정**(과금 · 사용자 승인 후) — `60_repeat_어카운트시작/10_NL스모크_재실행_절차.md` · 39문항.
- 새 계정 기준선을 **새로 세운다**(구 기준선 = 중간 오류 2 · 참고만).
- 🆕 ML 개발예측 가드 3문항 추가: ① 「최신 기준월 전사 개발금액 예측」→ 정상 · 만원 명시 ② 「부서별 개발 예측」→ **미제공 안내 · 추정 0** ③ 「캠페인별 개발 예측 상위 5」→ 정상.
- 구 잔여 패턴 재확인: 물리 컬럼명 누수(`__ad.MARKETING_CAMPAIGN` · `__fme.PARENT_CAMPAIGN_NAME` · O191-E 에서 규칙 추가 · **재스모크 미실행**) · MEMBER_14 `PREDICTED_ONCE_MEMBERS` · EXEC_09 `FI.AVG_SCORE`.

**④ 작업 중 신규 발견 작업** — 발견 즉시 원장에 적고 ⑤ 전에 처리.

**⑤ 산출물 03~09 재생성 + 골든** — 조건 「잔여 0」(① 판정 통과 · ② 배포 완료 · 2차-B 종결). 🔴 프롬프트 입력 시에만 착수(사용자 지시).

### ▣ O192-A-3 🟠 사용자 결정·외부 회신 대기 (입고와 무관하게 남는 것)

| # | 항목 | 대기 대상 | 정본 좌표 |
|---|---|---|---|
| D-1 | GOLD 보류 **55컬럼** 신설 여부 — 발송요청 16 · 발송결과 7 · 청구 7 · 결제수단 13 · 결연활동 12 · 코드 4 · 후원시간 2 (같은 grain GOLD 없음 · SILVER 직접 조회는 가능) | 설계 결정(요청 grain 차원 · 결연활동 팩트) | `99_NEXT_SESSION-O0191-G.md` ▣1 |
| D-2 | `rename_stale_gate` 축1 +1 — 사용자 파일 `02_GN_DW_building/20_일배치테스트용.sql` | 사용자 확인(개명 반영 또는 `--baseline --reason`) | `99_NEXT_SESSION-O0191-F.md` ▣2 순4 |
| D-3 | ML 개발예측 3종(부서·후원사업·신규기존) 재활성 | 운영계 재적재 여부 · 사용자 결정 → 재적재 시 `21` ⛔ 3구간 해제 · `22` 문안 5종 복원 · EXECUTIVE yaml 미제공 문구 제거 · 스모크 가드 ② 반전 | `21_ML_SERVING_뷰_DDL.sql` 308~325행 |
| D-4 | ML 일시전환 최신행 — 원천에 실행순번 없음(창작 금지) | ML 담당 회신(`30_output_share/45_`) | `99_NEXT_SESSION-O0191-C.md` ▣2 순1 |
| D-5 | 「오픈 = 링크 클릭 · SND 전용」 정의 ML 공유 | 사용자 전달(`44_`) | `99_NEXT_SESSION-O0191-C.md` ▣2 순3 |
| D-6 | 현업 요청서 `41`~`46` 발송·회신 | 사용자 | `99_NEXT_SESSION-O0191-A.md` ▣2 순3 |
| D-7 | 착수표 ⑭(다중사업 7.29% 현업 회신) · ⑩(이월 잔여 2축 결정) | 현업 · 사용자 | `99_NEXT_SESSION-022.md:114` · `-023.md:17` |

### ▣ O192-A-4 🔴 이 단위(문서작업 계정)가 하지 않은 것 · 다음 세션 주의

- 🔴 원장 행 · 세션 이력(`01`) · 허브는 **갱신하지 않았다**(O191-G 도 미갱신 상태로 끊겼다) ⇒ 다음 세션이 **O191-G + O192-A 두 건**을 원장에 함께 기록한다.
- 🔴 확정위반 재발 주의 — 세션 착수 브리핑(`R4-4-1`)을 **작업보다 먼저** 출력한다(O190-F · O191-A 2회 연속 위반).
- 🟢 라벨은 도구 제안(`O191-D` · 빈 번호)을 쓰지 않고 `O192-A` 로 발행했다 — 현행 판정이 「라벨 최대값」이라 D 로 쓰면 기존 G 에 가려진다.

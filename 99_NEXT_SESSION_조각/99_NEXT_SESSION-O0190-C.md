<!-- LLM-METADATA
doc_id: HANDOFF_O0190_C
doc_role: 인수인계 — 세션 `O190-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-C-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 🟢 사용자 결정 = 스모크 잔여 10건은 **Agent 개선 과제로 이관**(판정 기준 유지) · 승인 대상 작업 일괄 사전 승인.
- ⏸ **dbt build 1회 필요** — 이 단위가 모델 4개를 고쳤다(DDL·ADMIN ALTER 선행 완료 · 게이트 103/103):
  `FACT_BIGQUERY_BEHAVIOR`(W-1 UTM) · `DIM_SPONSORSHIP`(F-2 4그룹) · `CRM_BIZ_TARGET`·`FACT_TARGET_PROJECT`(주석만).
- 🔴 GA4 체인 이 계정 0행(`BIGQUERY_EVENT` 0) ⇒ W-1 은 배선만 · 데이터 검증은 백필 후.
- 🟢 INFORMATION_SCHEMA.COLUMNS 는 SERVING 뷰 컬럼 COMMENT 를 **반영 지연**했다(DESCRIBE·SHOW COLUMNS 는 즉시) ⇒ 뷰 COMMENT 판정은 SHOW COLUMNS 로(J2).

### ▣ O190-C-1 🟢 이 단위가 끝낸 것

- **SERVING ML 뷰 8종 컬럼 COMMENT 106/106**(SHOW COLUMNS 누락 0) — 근거 = 뷰 정의 + ML 원천 COMMENT · 규칙7 수치 0 ·
  `21_ML_SERVING_뷰_DDL.sql` 말미 [COMMENT] 절(🔴 뷰 재생성 시 함께 실행).
- **M-6** `SEND_STATUS2` — 전건 NULL 확인(4,193만 행) · COMMENT 를 축B(`SEND_RESULT_CD/NAME`) 안내로 교정(06_DDL · WIDE yml · 라이브).
- **W-1 ⓑ** `FACT_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN` 원값 degen(차원 없음) — 06_DDL → ADMIN ALTER(ordinal 25) → 모델(grain 포함).
- **F-2** `DIM_SPONSORSHIP.SPONSORSHIP_GROUP4_NAME` — 라벨 접기(해외구호·해외→해외프로젝트 · 북한→기타) · 라벨 6종 전건 매칭.
- 사업목표 코드 주석 잔여 교정(CRM_BIZ_TARGET 헤더 · FTP :36).
- 원장 §1 O190 행 등재(행키 게이트 PASS).

### ▣ O190-C-2 🟡 F-4 등급안 (DW 제안 · 사용자 결정 §4 #4 · 실측 = 기준월 202606)

| 예측 | 분포(p50 / p75 / p90 / p95) | 제안(기준월 내 백분위 등급) |
|---|---|---|
| 회원 중단 | 0.30 / 0.84 / 0.99 / 0.996 | 고위험 = 상위 10% · 주의 = 10~25% · 일반 = 나머지 |
| 충성회원 | ≈0 / ≈0 / 0.15 / 0.26 | 최상위 = 상위 5% · 상 = 5~10% · 중 = 10~25% · 하 = 나머지 |
| 후원건 중단 | 0.08 / 0.13 / 0.20 / 0.49 | 고위험 = 상위 5% · 주의 = 5~25% · 일반 = 나머지 |

- 🔴 확률 절대값 임계가 아니라 **백분위**를 제안하는 이유 = 분포가 모델마다 극단적으로 치우쳐(충성 p75 ≈ 0) 고정 임계가 무의미하다.
- 🔴 제안이며 미배선 — 현업 승인 후 뷰에 `*_GRADE` 컬럼으로 배선(모델 교체 시 등급 비율 불변).

### ▣ O190-C-3 🟠 남은 작업 (요약)

| 순 | 작업 | 상태 | 막는 것 |
|---|---|---|---|
| 1 | dbt build (FBB·DIM_SPONSORSHIP 반영) | ⏸ 사용자 실행 | — |
| 2 | Agent 개선 — 스모크 중간 오류 10(metric-as-CTE 7 · 추측 식별자 3) | 이관 | 설계 |
| 3 | ML ONCE_CONVERSION grain 붕괴(회원당 최대 6행 · 관측월 1종) | 👤 ML 담당 | 원천 |
| 4 | F-1 본부/지부 — 조직표에 「조직구분」 없음 · 「트리 2단계」는 지부(레벨3) 소실 ⇒ **결정 재요청** | 👤 결정 | 규칙 |
| 5 | F-4 등급안 승인(위 표) → 배선 | 👤 승인 | — |
| 6 | L-1① D5 제외 · L-2 병기 — 중단 보고 축 모델 변경 | 미착수 | 공수 |
| 7 | 2차-B 2단 32테이블 · 문서02 재서술 · W3 잔여 · 신규 19종 COMMENT 업무 문안 | 미착수 | 공수·현업 문안 |
| 8 | W-1 데이터 검증 · FBB 전량 백필 | 대기 | GA4 입고 |
| 9 | 현업 회신 — F-2 「11개」 목록 · F-3 SND 오픈 정의 · 문서20 👤 5건 · DGT 2026-06 이전분 | 👤 | 현업 |
| 10 | 산출물 03~09 재생성 + 골든 | ⏸ 잔여 0 일 때 | 1~9 |

### ▣ O190-C-4 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_SPONSORSHIP+ FACT_BIGQUERY_BEHAVIOR+ CRM_BIZ_TARGET+';
```

_Co-authored with CoCo_

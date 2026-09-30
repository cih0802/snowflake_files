<!-- LLM-METADATA
doc_id: HANDOFF_O0190_A
doc_role: 인수인계 — 세션 `O190-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-A-0 🔴 먼저 알아라 (2026-09-30 · bt97381 · 새 개발 계정)

- 🟢 **사용자 보고 build = PASS 576 · WARN 21 · ERROR 0 · TOTAL 597**(이 계정 · 🔴 재조회 판정은 아래 실측분만).
- 🔴🔴 **원천 구조가 인수인계 가정과 다르다** — `TM_CM_MBER_DVLP_GOAL_DIV`:
  - `BDGT_PRCD_NM`('예산절차') = 값 1종 **'연사업'** 438행 · ERP 같은 축 = 연사업 204 / 추가경정 54 ⇒ **편성 차수(당초/추경) 축**.
  - `GOAL_TYPE_NM` = 「연사업/팀」 2종이 **아니라 목표 지표 9종** — 후원사업 · 회원개발 · 월말활동회원 · 정기회비 ·
    후원사업활동율 · 신규기존활동율 · 후원사업납입율 · 신규기존납입율 · 신규기존누계납입율.
  - 대응(12개월 합 일치 실측) = 구 연사업 348,024 ≡ 현 **후원사업** · 구 팀 348,000 ≡ 현 **회원개발**.
  - ⇒ 종전 SV 기본 필터 `GOAL_TYPE='연사업'` 은 **0행**이었고 `TOTAL_GOAL_CNT` 에 건·명·원·비율이 섞였다.
- 🟢 **ML ONCE_CONVERSION VARCHAR 전환** = 3컬럼 이미 TEXT · 뷰가 숫자 연산을 하지 않아 **CAST 불요**.
  ⚠️ 이 계정 `STDR_MT` = **202609 1종**(36,664행) ⇒ 뷰 [8] 「회원당 연속 6개월」 전제 불성립 — 재실측 대상.

### ▣ O190-A-1 🟢 이 단위가 끝낸 것

- **SILVER CRM_BIZ_TARGET** — DDL(`08_SILVER` CREATE 말미 + O190 ALTER 절) → **GN_DW_ADMIN ALTER 적용**(ordinal 21) → 모델.
  - `BDGT_PRCD_NM` 보존 · `TARGET_TYPE` = 연사업→당초 · 추가경정→추경(GOLD `LIKE '추경%'` 로 SUPP) · DK 해시 포함.
  - 렌더 동등 실측 = 5,244행 · DK 유일 5,244 · TARGET_TYPE 당초 1종 · `accepted_values`(warn) 테스트 추가.
  - 게이트 = `table_ddl_column_gate` 103/103(CRM_BIZ_TARGET 21/21) · `line_len` · `jinja_config_gate` PASS.
- **SV_TARGET_BIZ 재배포**(사용자 결정 = 「단위별 metric 분리」) — `GOAL_CNT`(건 · 후원사업·회원개발) ·
  `GOAL_MEMBER_CNT`(명 · 월말 잔량) · `GOAL_AMT`(원) · `GOAL_RATE`(비율 AVG · 소계 행 합계/신규합계 규칙).
  - 기본 관점 = `GOAL_TYPE='후원사업'`(구 연사업 승계 · N-24①) · 스모크 **9/9 TRUE**.
  - 롤백 = 이 단위 착수 시 `GET_DDL` 로 확인한 구 정의(05_11 파일 직전 판본 · `TOTAL_GOAL_CNT` 단일 metric).
  - GOLD·WIDE 무변경(9종 이미 적재) ⇒ SV 는 dbt 재실행 없이 유효.

### ▣ O190-A-2 🟠 남은 작업

| 순 | 구분 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | ㉠ | 🔴 | dbt 재배포 + `build --select CRM_BIZ_TARGET+`(▣3) → BDGT_PRCD_NM 채움 · DK 재발급 확인 | 사용자 실행 | — |
| 2 | ㉠ | 🟠 | Agent 3종 `analyst_target_biz` 설명·지시문 stale(「연사업/팀」) → 9종·단위 metric 으로 교정 + 새 VERSION | 신규 | — |
| 3 | ㉠ | 🟠 | 모델·DDL·yml 주석의 「연사업/팀」 서술 교정(CRM_BIZ_TARGET 헤더 :5~:8 · 08_SILVER :972~:979 · FTP :36 · `_wide_schema.yml:1006`) | 신규 | — |
| 4 | ㉠ | 🟠 | ML 뷰 [8] 관측창 전제 재실측(STDR_MT 1종) · SV_ML_ONCE_CONVERSION COMMENT 정합 | 신규 | — |
| 5 | ㉠ | 🔴 | O189-C ▣2 2~9행 승계(새 계정 게이트 · 스모크 36 과금 재확인 · 배선 7건 · 2차-B · 문서02 · W3 · COMMENT · 현업) | 승계 | 1 |

### ▣ O190-A-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select CRM_BIZ_TARGET+';
```

_Co-authored with CoCo_

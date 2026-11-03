<!-- LLM-METADATA
doc_id: HANDOFF_O0190_D
doc_role: 인수인계 — 세션 `O190-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-D-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 🟢 사용자 build = PASS 151 · WARN 2 · ERROR 0(`DIM_SPONSORSHIP+ FACT_BIGQUERY_BEHAVIOR+ CRM_BIZ_TARGET+`).
- 🔴🔴 **BigQuery 체인 0행의 원인 = 적재 창**(모델 결함 아님 · O178 동형 재발).
  - 원천 `SILVER.BIGQUERY_REFINED_DATA` = 9,264,762행 · 2024-01-12~2026-09-02 · 33일 샘플(정상).
  - 체인 = REFINED_DATA → `BIGQUERY_BASIC` → EVENT/DEVICE/IDENTITY/TRAFFIC_SOURCE/EVENT_DIM → GOLD FBB.
  - 새 계정은 ADMIN DDL 로 테이블을 **먼저 만들었다** ⇒ dbt 가 첫 run 을 증분(`is_incremental()`=true)으로 보고
    롤링 창 [오늘−3일, ∞) 만 읽었다 ⇒ 원천 전 구간이 창 밖 ⇒ BASIC 이하 전부 0행.
  - 감시기는 이미 적발 중이었다 — `OPS.WARN_BIGQUERY_LOAD_GAP` 33행(원천에만 있는 일자 33).
  - 처방 = `bigquery_dt_ranges` 백필 1회(▣3 명령 · ARGS 경로 = O187-C 실증).
  - 🔴 `SILVER_2`/`GOLD_2`(dev2 타깃)도 같은 상태 — 필요 시 같은 명령을 dev2 로.

### ▣ O190-D-1 🟢 이 단위가 끝낸 것

- **L-1①** `FACT_MESSAGE_DISPATCH` D5 8지표 — 제목 「미납·중단·감사」 발송 귀속 제외(모델 · 컬럼 집합 불변).
  실측 영향(반영 전) = D5 중단 귀속 157,097 중 45,829(처리통보성).
- **L-2** `SV_MEMBER_EVENT` — `acq`(DIM_MEMBER_ACQUISITION · MEMBER_DK 1:1) 추가 · `ACQ_SPONSORSHIP`(데려온 사업) 병기.
  팬아웃 0 실증(중단 총계 1,061,430 불변). 🔴 stale 교정 = 중단행 후원사업 「전건 미매핑」 기재 → 실측 대부분 배선(끊은 사업).
- **F-4** 등급 배선(사용자 승인) — `ML_MEMBER_RISK_V.CHURN_GRADE·LOYAL_GRADE` · `ML_SPONSOR_RISK_V.CHURN_GRADE`
  (기준월 내 백분위 · 예측 없음 NULL 분리) → SV 2종 차원 노출 · 조회 실증.
  🔴 SV COMMENT 는 경계 숫자를 싣지 않는다(규칙7 · 경계 정본 = 뷰 정의).
- 게이트 = DDL 103/103 · Jinja · sv_rule7 라이브 0 · SV 객체 · comment_drift · line_len PASS.

### ▣ O190-D-2 🟠 남은 작업

| 순 | 작업 | 상태 | 막는 것 |
|---|---|---|---|
| 1 | BigQuery 백필(▣3) → FBB·W-1 UTM 데이터 검증 · `WARN_BIGQUERY_LOAD_GAP` 0 확인 | ⏸ 사용자 실행 | — |
| 2 | dbt build `FACT_MESSAGE_DISPATCH+`(L-1① 반영) | ⏸ 사용자 실행 | — |
| 3 | Agent 개선 — 스모크 중간 오류 10 · 새 차원(등급·ACQ_SPONSORSHIP) 도구 설명 반영 → 재버전 | 이관 | 설계 |
| 4 | ML ONCE_CONVERSION grain 붕괴(회원당 최대 6행) | 👤 ML 담당 | 원천 |
| 5 | F-1 본부/지부 — 조직표 「조직구분」 부재 · 「트리 2단계」는 지부 소실 | 👤 결정 재요청 | 규칙 |
| 6 | 2차-B 2단 32테이블 · 문서02 재서술 · W3 잔여 · 신규 19종 COMMENT 업무 문안 | 미착수 | 공수·현업 문안 |
| 7 | 현업 회신 — F-2 「11개」 · F-3 SND 오픈 정의 · 문서20 👤 5건 · DGT 2026-06 이전분 | 👤 | 현업 |
| 8 | 산출물 03~09 재생성 + 골든 | ⏸ 잔여 0 일 때 | 1~7 |

### ▣ O190-D-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select BIGQUERY_BASIC+ FACT_MESSAGE_DISPATCH+ --vars ''{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}''';
```

_Co-authored with CoCo_

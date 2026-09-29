### ▣ O188-E-0 🔴 먼저 알아라 (2026-09-29 · xf98254)

- ⏸ **dbt 정지점** — 모델 4개·yml 2개 수정 · 재배포 + build 는 사용자 실행(▣3). 🔴 build 전에는 `05_11` SV 배포 불가(새 컬럼 부재).
- 🟢 조직표 규칙 = 자기+모든 상위 `USE_YN='Y'` · `LAST_UPDT_DT` ≠ NULL·9999-12-31 ⇒ **223노드**(CSV 222 + 해외파견 · 사용자 결정 「포함」).
- 🟢 DGT 원천 연·월·일 = 29,048행 전건 커버(DATE 1970 3,531행도 YMD 로 복원 · SILVER 이미 반영 · 오류 0) · 🔴 2026-06 이전 **0행** ⇒ 재송부 요청 유지.
- 🔴 Agent 스모크 중간 invalid identifier = **7문항**(종전 기재 「2문항」 정정 · 전부 자동 복구 · 원천 `tmp/nlsmoke/_summary.json`) — 주범 `D.FULL_DATE`(4) · 기타 3.

### ▣ O188-E-1 🟢 이 단위가 끝낸 것

- `CRM_ORG` + `LAST_UPDT_DT` · `DIM_ORG` + `IS_ACTIVE_ORG`·`ORG_PATH`·`ORG_LEVEL`(재귀 · 1,314행 유지 · SK 불변)
- `FACT_TARGET_PROJECT` 매칭 모집단 = 활성 트리 ⇒ 팀명 유일 매칭 4 → 7 · degen 5축(`SRC_TEAM_NM` 외) 추가 · `WIDE_TARGET_BIZ` 전파 + yml columns 순서 동기
- 신규 `05_SV-Agent_ai/05_11_SV_DDL_TARGET_BIZ.sql`(연사업·팀 병렬 · 합산 금지 규칙 · 추경 제외 · 스모크 불변식 포함)

### ▣ O188-E-2 🟠 남은 작업

| 순 | 작업 | 상태 |
|---|---|---|
| 1 | ▣3 재배포 + build → `DIM_ORG` 223 · FTP 합 348,024/348,000 재조회 | 사용자 실행 대기 |
| 2 | build 후 `05_11` 배포 → Agent EXEC·MKT 에 `analyst_target_biz` 도구 추가(yaml → [0-B]→[0-C]→[2]→[3]) | 1 선행 |
| 3 | 30번 §2 질문 21건 회신 | 다음 프롬프트 |
| 4 | Agent invalid identifier 처방 선택(A~D) | 다음 프롬프트 |
| 5 | W3·B2~B12 처분 | 다음 프롬프트 |
| 6 | DGT 6월 이전분 재송부 | 사용자 확인 |
| 7 | `30_output_share` 03·08·09 재생성 + 골든 | 대기(사용자 지시) |

### ▣ O188-E-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select CRM_ORG DIM_ORG FACT_TARGET_PROJECT WIDE_TARGET_BIZ';
```

### ▣ O188-A-0 🔴 먼저 알아라 — dbt 재배포가 안 되어 있다 (2026-09-29 · xf98254)

- 사용자 `build --select DIM_DATE` = PASS 13 이었으나 `GOLD.DIM_DATE.IS_HOLIDAY=TRUE` **0건** —
  실행된 MERGE 에 `TM_CM_SCHDUL_MNG` 조인이 없다 ⇒ `DW_PIPELINE` 이 **수정 전 버전**이다.
- 🟢 판정식 = **build PASS 는 「배포된 코드가 돌았다」이지 「워크스페이스 코드가 돌았다」가 아니다.**
- 이번 세션에 모델 7개·yml 5개를 고쳤다 ⇒ ▣3 재배포 1회 + build 1회로 전부 반영된다.

---

### ▣ O188-A-1 🟢 이 단위가 끝낸 것

- 문서20 판정 7건 기록(공란 36→29) · AD-3 「÷10000」 근거 철회(사용자 정정)
- 배선(모델·DDL·ALTER 완료 · build 대기) = 공휴일(`DIM_DATE`) · 사업목표(`CRM_BIZ_TARGET`→`FACT_TARGET_PROJECT`→`WIDE_TARGET_BIZ`) ·
  REBRDC 비용 3컬럼(`AGENCY_AD_PERFORMANCE`→`FACT_AD_PERFORMANCE`)
- 🔴 `DIM_ORG.DEPARTMENT` 중복 4명 발견 → 목표 이름 조인을 유일 부서만 매칭으로 차단
- J5 「error 복귀」 예약 5곳 폐기 표기 · 08 DDL 머리 증분 백필 경고 · WARN 적재 공백 0행 확인
- Agent 3종 규칙 1줄 + 새 버전(MEMBER V6 · EXEC V5 · MKT V5) · 스모크 36/36 · 중간 오류 2문항(복구)

---

### ▣ O188-A-2 🟠 미처리 작업 — 독립 먼저 · 의존 나중

| 순 | 계층 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | 원천·현업 | 🔴 | 문서20 미회신 29건 | 사용자 답변 대기(표 제시됨) | — |
| 2 | 원천 | 🟠 | DGT 6월 이전 이력 소실 확인(`BRONZE_AGENCY.DGT_AD_CMPGN_DTLS` · `SILVER.AGENCY_AD_PERFORMANCE`) | 사용자 확인 | — |
| 3 | 운영 | 🔴 | ▣3 재배포 + build | 사용자 dbt | — |
| 4 | GOLD | 🔴 | build 후 판정 = IS_HOLIDAY 251 · CRM_BIZ_TARGET 3,480 · FTP 합 348,024/348,000 · REBRDC 3컬럼 비NULL | 대기 | 3 |
| 5 | GOLD | 🟠 | `DIM_ORG` 부서명 중복 4명 — 조직 크로스워크(부서코드) | 설계 대기 | — |
| 6 | SV | 🟡 | 공8 「GA 기준」 정의 — 산출 원천·산식 확정 후 SV_AD 반영 | 🔴 정의 질문 대기 | 사용자 |
| 7 | SV·Agent | 🟡 | 사업목표 SV·Agent 노출(기본 유형 = N-24 ② 회신) | 회신 대기 | 1·4 |
| 8 | Agent | ⚪ | 규칙 1줄로 invalid identifier 2문항 잔존 — 추가 처방 여부 | 선택 | — |
| 9 | Agent | ⚪ | `agent_tool_claim_gate` ③ 「회원당 1행」 NUM_EXEMPT 등재 여부 | 판단 | — |
| 10 | 문서 | ⚪ | W3 8건 · B2~B12 | 변동 없음 | — |
| 11 | 문서 | 🔴 | `30_output_share` 03·08·09 재생성 → `test_generators` 골든 갱신(`--reason`) | 세션 정리 직전 | 4 |

---

### ▣ O188-A-3 ⏸ dbt 정지점 (`R4-1`) — 사용자 실행

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_DATE CRM_BIZ_TARGET+ AGENCY_AD_PERFORMANCE+';
```

---

### ▣ O188-A-4 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 1. 브리핑 생성 후 인수인계 99_NEXT_SESSION-O0188-A.md ▣2 표를 정본으로 삼는다(▣0 재배포 누락을 먼저 읽는다).
2. 표의 각 항목을 착수 전에 J3 실측으로 재판정한다.
3. ▣3 build 결과(사용자 붙여넣기)가 있으면 4행 판정을 먼저 한다(재조회로 확인).
4. 문서20 공란 판정 29건 기준으로 회신을 확인하고 들어온 것부터 배선한다.
5. 독립 작업 먼저, 선행이 있는 작업은 뒤로 — 11행(30_output_share)은 세션 정리 직전.
   - 승인 필요 작업은 포괄 승인 상태다 — SQL 을 먼저 보여주고 재조회로 확인한다.
   - dbt 명령은 제시 후 대기(R4-1) · 모델을 고치면 DW_PIPELINE 재배포 명령을 함께 제시한다.
6. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일 갱신 + 게이트(gate_census --final · doc_census · index_row_gate · line_len).
7. 끝나면 남은 작업을 같은 형식으로 정리한다.
```

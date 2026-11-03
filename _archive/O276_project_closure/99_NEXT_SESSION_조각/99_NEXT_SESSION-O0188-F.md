<!-- LLM-METADATA
doc_id: HANDOFF_O0188_F
doc_role: 인수인계 — 세션 `O188-F` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-29
created_by: O188-F
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0188-F -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O188-F-0 🔴 먼저 알아라 (2026-09-29 · xf98254)

- ⏸ **dbt 정지점** — O188-E(조직·사업목표)와 이번 단위(1차·2차-A)를 **한 번에** 재배포 + build 한다(▣3).
- 🔴 O188-E 의 `DIM_ORG` 재귀 CTE `NOT IN` 서브쿼리는 **Snowflake 가 컴파일 거부**했다(「Unsupported subquery type」)
  ⇒ anti-join 플래그(`IS_ROOT`)로 수정 · EXPLAIN 통과 · 실측 1,315행 · 활성 223 · 경로 1,305.
- 🟢 사업목표 조직 매칭(활성 트리 기준) = 연사업 614/820 · 팀 338/440 · 합계 348,024 / 348,000 보존.
- 🟢 전 편집·신규 모델 **28개 EXPLAIN 컴파일 PASS**(Jinja 전개 후 실행 · build 는 아니다).

### ▣ O188-F-1 🟢 이 단위가 끝낸 것

- 1차(사용자 「셋 다」): ① `DIM_MEMBER.JOIN_CMMN_BRND(_NM)` ② `FACT_MEMBER_SPONSORSHIP_SPAN.SPNSR_JOIN_PATH_CD(_NM)` ③ `FACT_MESSAGE_DISPATCH` 최초·최종 브랜드 5컬럼
- 2차-A: 미연결 BRONZE_CRM 11종 → 신규 SILVER 10 · GOLD 9(DIM 6 · FACT 3) · 민감 컬럼 11개 SILVER 부터 제외 · source 8종 선언 · 유일성 테스트 6
- 설계 문서 `30_output_share/32_BRONZE_CRM_GOLD반영_설계.md`(2차-B 누락 컬럼 표 포함)

### ▣ O188-F-2 🟠 남은 작업

| 순 | 작업 | 상태 |
|---|---|---|
| 1 | ▣3 재배포 + build → 재조회 확인(행수·새 컬럼 채움률) | 사용자 실행 대기 |
| 2 | build 후 `05_11` SV_TARGET_BIZ 배포 + Agent 도구 | 1 선행 |
| 3 | 2차-B — 연결 테이블 누락 컬럼 보강(문서32 §3) | 설계 완료 · 다음 단위 |
| 4 | 새 GOLD 9종 SV 노출 여부 결정 | 사용자 결정 |
| 5 | O188-E ▣2 3~7행(질문 21 · Agent 처방 · W3/B · DGT · 03·08·09) | 다음 프롬프트 |

### ▣ O188-F-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select CRM_ORG DIM_ORG FACT_TARGET_PROJECT WIDE_TARGET_BIZ CRM_SEND_MEMBER FACT_MESSAGE_DISPATCH CRM_MEMBER_SPONSOR_SPAN FACT_MEMBER_SPONSORSHIP_SPAN DIM_MEMBER CRM_RELATION_DEV CRM_CHILD CRM_BIZ_PLACE CRM_RELATION_CHANGE CRM_MSG_TEMPLATE CRM_MSG_TEMPLATE_BUTTON CRM_CODE_GROUP CRM_PAYMENT_METHOD_HIST CRM_INSTT_ACCOUNT CRM_SETLE_CMPNY_ACCOUNT DIM_BIZ_PLACE DIM_CHILD DIM_MSG_TEMPLATE DIM_MSG_TEMPLATE_BUTTON DIM_CODE_GROUP DIM_PAYMENT_ACCOUNT FACT_RELATION_DEV FACT_RELATION_CHANGE FACT_PAYMENT_METHOD_CHANGE';
```

_Co-authored with CoCo_

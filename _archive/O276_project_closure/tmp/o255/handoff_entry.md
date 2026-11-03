### ▣ O255-A-0 🔴 먼저 알아라

- `O255-A` = O252(DEC-63) 후속 · 재현 문서화 + SV 배선 + 배포순서 파일명 정리 (2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시 · 확정위반 1 = R1-7-8 원장 edit 앵커가 O254 행 머리를 삼킴 → 즉시 복구 · index_row_gate PASS).
- 정본 = `05_SV-Agent_ai/37_DEPLOY_ORG_SUCCESSION.sql`([D0]~[D6]) · 실행순서 = `문서실행순서.md` 「기존 환경 갱신」 29~31 · `문서실행순서_llm실행.md` §3.6 · `문서실행순서_보조주석.md` DEC-63 절 · 이름 변경표.
- 🔴 이 세션은 dbt 를 실행하지 않았다(R4-1) · dbt 모델·seed 파일도 바꾸지 않았다 ⇒ O254-B 의 「dbt 수정 완료」 조건은 **사용자 확인으로 판정**한다.

### ▣ O255-A-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| GOLD | `06_DDL.sql` 2블록 기존 그대로(정본) · `37` [D1] = 같은 2문장 사본 · 소유자 GN_DW_ADMIN · DBT 권한 = FUTURE GRANT(07 RBAC) |
| SILVER | 변경 없음(CRM_ORG · CRM_MEMBER_DEV · CRM_MEMBER_SPONSOR_SPAN 만 읽음) |
| SV | `05_10` SV_MEMBER_SPONSOR_BIZ = org_succ 테이블 · 관계(SPNSR_ACMSLT_DEPT_CD → OLD_DEPT_ID) · 차원 5 · 지표 STOP_REGISTRATIONS · 규칙 (5) · VQR 1 · 개발계 배포 14/14 · 합계 1,381,827 = 1,381,827 · 2026 129,707 |
| 대사 | `37` 개발계 10/10 · 1,314 = 1,314 · 중복 0 · 미매핑 2024 1,000 · 2025 894(+원천 NULL 2) · 2026 621 |
| 파일명 | 27~36 배포순서 9건 → `NN_DEPLOY_<주제>.sql`(SHA 동일 · 스테이지 확인) · 현행 문서 참조 26건 치환 · 옛 이름 표 = 보조주석 |
| 게이트 | line_len 20 PASS · doc_coord · sv_identifier · agent_object_ref · agent_source_lineage · doc_heading · index_row PASS |

### ▣ O255-A-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 = `문서실행순서.md` 「기존 환경 갱신」 29 → 30(dbt) → 31 | 👤 운영계 |
| ② | 현업 검토 xlsx 회신 → seed CSV → `37` [D5] | 👤 현업 |
| ③ | 80 폴더 `00_README.md`·`00_INDEX.csv` 에 옛 파일명 잔존 — O254-B 의 80 재빌드(헤더 통일) 때 함께 반영(지금 재빌드 금지 · 정제 유실) | 👤 사용자 결정 |
| ④ | 드리프트 = `10_dbt_pipeline/dbt_build_fact_ad_performance_budget.sql` 본문이 O248 모델 build 로 덮여 「기존 환경 갱신」 16 설명(FACT_AD_PERFORMANCE+ …)과 다르다 | 👤 사용자 결정 |

### ▣ O255-A-3 ㉡ 워크스페이스 백로그

- O254-A-2 ①~④ · O254-B-2(80 헤더 통일 · 착수 조건 = 사용자 「dbt 수정 완료」) 그대로 승계.
- 이름 변경 보류분 = `21_`~`26_`(scripts 9종 경로 하드코딩) · `13_SV_AD_배포_추가작업.sql` — 바꾸려면 스크립트 경로 동시 수정 필요.

### ▣ O255-A-4 ⚪ 결정 완료(재론 금지)

- 배포순서 파일명 규칙 = `NN_DEPLOY_<주제(영문)>.sql` · 작업번호를 파일명에 넣지 않는다(사용자 지시).
- 이력 문서의 옛 파일명은 고치지 않는다(원문 무변경) — 변경표로 찾는다.

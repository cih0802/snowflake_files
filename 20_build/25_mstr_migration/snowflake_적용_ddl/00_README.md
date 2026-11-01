---
doc_role: 폴더 안내(README) · 자동 생성 초안
created: 2026-10-31
---

# 20_build/25_mstr_migration/snowflake_적용_ddl — 폴더 안내

> 이 파일은 정리 작업 1단계에서 자동 생성한 초안입니다.
> 「요약」은 각 파일의 제목/첫 주석을 기계적으로 뽑은 것이므로, 폴더 목적은 사람이 보완해 주세요.

## 목적

- (작성 필요)

## 현황

- 직속 파일 9개 · 하위 폴더 0개 · 하위 전체 파일 9개

## 파일 목록

| 파일 | 크기 | 수정일 | 상태 | 요약 |
|---|---|---|---|---|
| `00_mstr_schema_role.sql` | 5KB | 2026-10-31 | - | Purpose : 00. GN_DW.MSTR 스키마 생성 + 롤 매핑 (O197 · MSTR 1차 이관 PoC) |
| `01_table_script.sql` | 14KB | 2026-10-31 | - | Purpose : 01. GN_DW.MSTR 테이블 DDL (O197) — 원본 = mstr DDL 원본/1차 이관대상 관련 추출/table_script.sql |
| `02_view_script.sql` | 8KB | 2026-10-31 | - | Purpose : 02. GN_DW.MSTR 뷰 DDL (O197) — 원본 = mstr DDL 원본/1차 이관대상 관련 추출/view_script.sql |
| `03_function_script.sql` | 11KB | 2026-10-31 | - | Purpose : 03. GN_DW.MSTR 함수 (O197) — 원본 = mstr DDL 원본/1차 이관대상 관련 추출/function_script.sql |
| `04_sp_script.sql` | 48KB | 2026-10-31 | - | Purpose : 04. GN_DW.MSTR 프로시저 (O197) — 원본 = mstr DDL 원본/1차 이관대상 관련 추출/sp_script.sql |
| `05_MSTR_SV_DDL.sql` | 59KB | 2026-10-31 | - | Purpose : 23_MSTR_SV_DDL.sql — MSTR 서빙뷰 + Semantic View DDL 정본: MSTR_SPNSR_DVLP_V · SV_MSTR_SPNSR_DVLP |
| `06_MSTR_적재_실행.sql` | 6KB | 2026-10-31 | - | Purpose : GN_DW.MSTR 테이블 채우기(적재) · 검증 · 재실행 절차 |
| `07_MSTR_일일적재_TASK.sql` | 6KB | 2026-10-31 | - | Purpose : MSTR 일일 적재(전월 + 당월) Task 정본 · 🆕 O207-C 확정(2026-10-07 · 사용자 결정 「일일 적재 확정」) |
| `90_mstr_1차_이관_대상_쿼리.sql` | 8KB | 2026-10-31 | - | Purpose : 05. MSTR 1차 이관 대상 리포트 쿼리 — Snowflake 전환본 (O197) |

상태: 보관=_archive/legacy/backup · 임시 후보=Untitled/temp/tmp · 인수인계=next prompt/session · -=미분류

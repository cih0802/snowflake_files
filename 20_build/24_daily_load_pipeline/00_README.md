---
doc_role: 폴더 안내(README) · 자동 생성 초안
created: 2026-10-31
---

# 20_build/24_daily_load_pipeline — 폴더 안내

> 이 파일은 정리 작업 1단계에서 자동 생성한 초안입니다.
> 「요약」은 각 파일의 제목/첫 주석을 기계적으로 뽑은 것이므로, 폴더 목적은 사람이 보완해 주세요.

## 목적

- BRONZE_CRM_2 → SILVER_2/GOLD_2 일배치 테스트 파이프라인(스키마 복제·권한·TASK·LOADER 임시권한).

## 현황

- 직속 파일 6개 · 하위 폴더 0개 · 하위 전체 파일 6개

## 파일 목록

| 파일 | 크기 | 수정일 | 상태 | 요약 |
|---|---|---|---|---|
| `00_개요_및_실행순서.md` | 10KB | 2026-10-31 | 정본 | 20_build/24_daily_load_pipeline — BRONZE_CRM_2 일배치 테스트 파이프라인 |
| `01_스키마생성_및_구조복제.sql` | 5KB | 2026-10-31 | 정본 | Purpose : BRONZE_CRM_2 / SILVER_2 / GOLD_2 스키마 생성 + SILVER/GOLD 라이브 테이블 구조 CLONE(데이터 0행) |
| `02_권한부여_LOADER_ENGINEER_ADMIN.sql` | 9KB | 2026-10-31 | 정본 | Purpose : BRONZE_CRM_2 / SILVER_2 / GOLD_2 권한 부여 — LOADER / ENGINEER / ADMIN 3역할 한정 |
| `03_일배치_TASK_스케줄.sql` | 4KB | 2026-10-31 | 정본 | Purpose : 일배치 TASK 등록 — dbt build --target dev2 (BRONZE_CRM_2 → SILVER_2/GOLD_2) 자동화 |
| `04_LOADER_임시권한_CALL_DBT.sql` | 4KB | 2026-10-31 | 정본 | Purpose : 일/월배치를 돌리기 위해 GN_DW_LOADER 롤에 임시로 권한을 주는 쿼리문 |
| `04_LOADER_임시권한_SP_EXEC_MONTH_END.sql` | 5KB | 2026-10-31 | 정본 | Purpose : GN_DW_LOADER 임시권한 — CALL GN_DW.BRONZE_CRM.SP_EXEC_MONTH_END('YYYYMM') 한 줄만 허용 |

상태: 정본=현행 기준 문서 · 참고=근거/이력/롤백본 · 중복=내용 동일 사본 · 구버전=최신판 존재 · 임시=측정/프로브 잔재 · 안내=README (4-A 판정 2026-10-31)

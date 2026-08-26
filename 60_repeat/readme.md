커밋 메세지 '20260825_가오픈정리' 를 검색해서 참고할 것. 중복용량을 줄이기 위해 파일 삭제함. 

[작업이력]

모든 파일이 정상적으로 복사되었습니다 (dbt 127개 파일 포함). 이제 재현 순서와 각 파일의 역할을 담은 인덱스 문서를 작성하겠습니다.

60_repeat/ 폴더에 GN_DW 구조 재현("구조만 처음부터 재구축, 신규/paid 계정" 시나리오) 에 필요한 파일 151개를 정리해 복사했습니다.

구성 (Phase 순서대로):

00_INDEX.md — 전체 안내 및 파일-Phase 매핑표
PAID_재현_런북_20260722.md — 실행 순서 정본
01_rbac/ — RBAC/스키마 설정 (07_ENVIRONMENT_RBAC_setup.sql)
02_bronze/ — BRONZE 구조 DDL
03_silver/, 04_gold/ — SILVER/GOLD 구조 DDL
05_dbt/ — dbt 프로젝트 전체 (logs/target/_archive 제외, 127개 파일)
06_serving_sv/ — Semantic View DDL 10개
07_agent/ — Agent 생성/버전업 스크립트 + paid 스모크 가이드
08_cortex_project/ — Agent spec YAML + 매니페스트
작업 중 확인한 중요 사항: 런북(PAID_재현_런북_20260722.md)이 작성된 2026-07-22 이후 일부 파일이 분할/개명되었습니다(예: 05_SV_DDL.sql 단일 파일 → 05_1~05_10 개별 SV 파일로 분할, 09_AGENT_spec_구현.sql → 09_1+09_2로 분해). 00_INDEX.md에 이 점을 명시했고, 최신(2026-08-25 기준) 파일로 채웠습니다.

또한 워크스페이스에는 다른 목적의 "재현" 시나리오도 존재합니다 — 50_handoff/의 A_PRODUCER/B_BROKER/C_CONSUMER 스크립트는 실제 운영 데이터(BRONZE·SILVER·ML)를 Direct Share+CSV로 다른 리전 계정에 옮기는 데이터 이관용이며, 이번 요청 범위(구조 재현)에는 포함하지 않았습니다. 필요하시면 이것도 별도로 정리해 드릴 수 있습니다.
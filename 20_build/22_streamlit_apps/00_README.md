<!-- LLM-METADATA
doc_role: 폴더 안내 — Streamlit 앱 소스 모음
created: 2026-11-01
created_by: O276
related: 20_build/27_streamlit_auth/ · _archive/O276_project_closure/CLOSURE_MOVE_MAP.csv
END-METADATA -->

# 22_streamlit_apps — Streamlit 앱 소스

> 출처 = 루트 `09_STREAMLIT/` (O275 재편 누락분 · O276 편입). 폴더명 = `<앱 제목>_<원래 ID>`.
> ID 는 운영계 Streamlit 객체/워크스페이스 폴더를 찾는 키라 남겼다. 이 작업 계정(TQ68205)에는 배포돼 있지 않다(`SHOW STREAMLITS` 0건 · 2026-11-01).
> 권한 설계(VIEWER/ANALYST)는 `20_build/27_streamlit_auth/` 를 본다. `__pycache__` 는 삭제했다(재생성됨 · 사용자 승인).

| 폴더 | snowflake.yml title | 앱 내 제목 | 특이사항 |
|---|---|---|---|
| `기획실대시보드_X39FI0ZHW8A02OFS/` | 기획실 대시보드 | 주간개발보고 대시보드 | 최신본 · `monthly_target_ref.csv` 포함 |
| `회원통계보고서_DEV_DASHBOARD/` | 회원통계보고서1014 | 회원통계보고 | 스냅샷 SQL 1.5MB 포함 |
| `시연통합_FXDDFO7Z_L_ORZG7/` | 시연통합2 | — | yml name = `SPLA_J_TD6OXF93Z` |
| `납입방식보고서_HJTMD27EXFUUEWND/` | 납입방식보고서0909 | 납입방식별 활동회원현황 | |
| `데이터연동오류현황_K2HQP_3PE6IR6TWC/` | 오류탐색 | 데이터 연동 오류 현황 | |
| `월간회원개발실적_KEBFFP885PVNIDUB/` | (yml 에 title 없음) | 월간 회원개발실적 | 462줄 |
| `회원개발통합리포트_W8PBGER093T61MQA/` | (yml 에 title 없음) | — | 1,374줄 · README 있음 · KEBF 의 확장판일 수 있음(미확인) |
| `마케팅캠페인통합성과_MJE2FT3IPENTUJQ7/` | Untitled 2 | 마케팅 캠페인 통합 성과 | |
| `주간중단보고_UNTITLED_12/` | 주간중단보고_1007 | 주간중단보고 | MSSQL 대조 분석 md · 드릴다운 SQL 포함 |
| `월마감회비예측_UT35Y5QEK457979C/` | 월마감회비예측 | 월마감회비예측 | 멀티페이지 · `model.json` 1.6MB · `tools/build_model.py` |
| `00_STREAMLIT_BAK.sql` | — | — | 계정 내 Streamlit 일괄 백업 프로시저 |
| `_archive/기획실대시보드_구버전_AE4O8Q2VQMKWF5KV/` | 기획실 대시보드 | — | X39 의 이전 버전(yml name = X39) |

- 모든 앱의 query_warehouse = `GN_DW_ANALYTICS_WH`(yml 에 있는 경우).

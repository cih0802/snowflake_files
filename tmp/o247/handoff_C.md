## O247-C 마감 (2026-10-20 · iw20760 계정 정지로 종료)

### 상태
- 사용자 `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'` 완료 보고. 결과(ERROR/SKIP, `SILVER.CRM_HOLIDAY`=251)는 계정 정지로 **미검증**.
- iw20760 정지 → 이후 실측은 **새 개발계 계정**에서 수행. 이 세션 개발계 적용 내역(마스킹 12컬럼·A2·N01 DMF 136·CRM_HOLIDAY·dbt 버전)은 새 계정에 없음 → `85_…/_ENV/운영계_반영_체크리스트.md` ⑤ 9단계를 새 계정에 그대로 재적용.
- 원장 O248은 다른 세션 선점. 새 세션은 다음 빈 번호 선점.

### 미결 결정 (사용자 답 대기)
- **DMF 존폐**: DMF는 마스킹과 무관한 N01 품질점검(PK 62·FK 71·스키마 2), 사용자 Task 아님(스키마 `DATA_METRIC_SCHEDULE` 서버리스, 별도 크레딧). iw20760 과금 0건(첫 실행 전 정지) → 비용 실측 불가.
- 대안 = dbt 테스트 대체. 현 dbt: relationships 107 · not_null 157 · unique 9 · 복합키 유일성 0 · recency/row_count 0. 대체 시 복합 PK 유일성·신선도 테스트 추가 필요(DMF PK 62 1:1 대조 미수행).
- 사용자 결정 전까지 새 계정 체크리스트 ⑤의 N01 단계는 **보류 권장**(적용 시 서버리스 과금 발생).

### 새 계정 첫 작업
1. 체크리스트 ⑤ 재적용(N01은 결정 후) → 사용자 dbt build → `CRM_HOLIDAY`=251 · A6 Q01 확인.
2. `env_capture.py` ② → 생성기 ③ (`b_struct_build.py <ACCT>` → `n03_catalog_build.py <ACCT>`)로 D06 DIM_DATE 원천=CRM_HOLIDAY 반영 → DR-25 해소 처리 → `build_handoff.py --apply`.
3. DMF 유지 시 첫 실행 뒤 `ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY` 로 일 크레딧 실측 → N06·D11 반영.
4. 자기검토 6항(이전 세션 R1-7-2 위반 파일 재확인) 미착수.

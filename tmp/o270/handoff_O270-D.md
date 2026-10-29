### ▣ O270-D-0 🔴 먼저 알아라

- `O270-D` = 사용자 결정 반영(2026-10-29 · ZS83821 개발계 · ㉡) — **캠페인별 비용 SV(SV_MKTG_CAMPAIGN_COST) 안에서는 개발건수·개발단가 = CRM 기반**(답변에 「CRM 기반 개발건수」 명시) · 그 밖의 SV·도구의 개발건수 = MSTR.
- 배선 실측 = SV_MKTG_CAMPAIGN_COST 는 AGENT_MARKETING 에만 있다(소스 spec 3종 대조).

### ▣ O270-D-1 결과

| 순 | 작업 | 결과 |
|---|---|---|
| ① | 05_31 | CRM 지표 동의어 첫 항목 = 「CRM 기반 개발(건)」 + 일반 동의어(개발건수·개발건) 이동 · MSTR 지표 = 명시 요청 시만 · SV COMMENT·규칙 (5)·VQR = CRM 기반 · 개발계 재배포 9/0 |
| ② | Agent | response ③ 문안 = 캠페인별 비용 표만 CRM 기반 · 그 밖 MSTR · 재배포(AGENT_MARKETING 새 default) · 재질문 = 「CRM 기반 개발은 26,455.7011건」 표기 확인 |
| ③ | 접근 요건 실측(소스 spec · lineage --suggest) | AGENCY 유래 SV = SV_AD · SV_AD_INFLOW_ALLOC · SV_MKTG_CAMPAIGN_COST · ERP 유래 = SV_BUDGET · SV_BUDGET_YEARLY · SV_EXPENSE_RESOLUTION · SV_MKTG_CAMPAIGN_COST · 🔴 AGENT_EXECUTIVE 에 SV_AD(AGENCY) 배선 = 요건 위반 · AGENT_MEMBER = AGENCY·ERP SV 0 |

### ▣ O270-D-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 접근 통제 방식 결정(배선 수정 + SV 단위 GRANT 권장 · 마스킹은 혼합 테이블만) · 역할 4종(마케팅·회원·기획실 분석가 · 팀장 VIEWER) 설계 | 🔴 사용자 결정 |
| ② | AGENT_EXECUTIVE 에서 analyst_ad(SV_AD) 제거 | ① 결정 후 |
| ③ | ML 공용 SV(SV_ML_REALTIME_SIMULATOR · SV_ML_FEATURE_IMPORTANCE 등)의 AGENCY·ERP 피처 포함 여부 실측 | ① 결정 후 |

### ▣ O246-A-0 🔴 먼저 알아라

- 작성 = trialadmin(iw20760) · 2026-10-19 · ㉡ · 사용자 지시 = 「원천·DB 구성 조회 후 잔여작업 진행」(계획 승인 = proceed as planned).
- 🟢 라이브(개발계) = `ML_MEMBER_ATTR_ASOF_V`(폴백) · 🆕 `ML_FEE_FORECAST_ALLOC_V` · `SV_ML_FEE_FORECAST`(FA 표) · AGENT_MEMBER **VERSION$5**(롤백 = VERSION$4).
- 🔴 ACCOUNTADMIN 으로 CREATE OR REPLACE 해 소유권·GRANT 가 소실됐다가 복구했다 — 이후 DDL 은 `USE ROLE GN_DW_ADMIN` 으로 실행하라.
- 게이트 = agent_object_ref · sv_identifier · sv_unit · sv_comment_object · agent_tool_claim · table_ddl_column 전부 PASS.

### ▣ O246-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 미매칭 원인 | 고위험 7,016명 중 6,608명(94.2%) 미매칭 = **기준월(202609) 당월 FACT_MEMBER_MONTHLY 행 부재**(활동약정 보유 100% · 직전 12개월 실적 보유 100%) |
| ② 보정 | 금액대·기간대·신규기존·납입방식 = 직전 12개월 최근 월 폴백 · `ATTR_SOURCE_MONTH_KEY`·`ATTR_FALLBACK` 추가 · 고위험 미매칭 0 · 납입방식 잔여 220(3.1%) · grain 1,473,162 유일 |
| ③ 회비예측 배분 | 카테고리 예측 × 직전 12개월 PAID_FEE 비중 · 축 = 후원사업/마케팅캠페인명/공통브랜드 · 축별 합 = 원 예측(190,654,663,995원) · (실적 비중 없음) 27.6% |
| ④ 실적 측 | SV_MEMBER_FEE 에 ACQ_MARKETING_CAMPAIGN·ACQ_CMMN_BRAND 이미 존재 — 신규 작업 없음 |
| ⑤ 스모크 | F1 후원사업별 회비예측 → FA 라우팅·표기 정상 · R1 고위험×금액대 → (미매칭) 0 |
| ⑥ 정본 | 21·22 DDL · AGENT_MEMBER yaml 갱신 · 백업 = `tmp/o246/*.before` · `12_agent개선과제/O246_백업_*` |

### ▣ O246-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 반영 = `12_agent개선과제/O246_운영계_작업프롬프트.md`(O245-B ① 과 합쳐 1회) | 👤 사용자 |
| ② | R1 답변이 폴백 값을 「기준월 말 시점」으로 표기 — 각주 규칙을 SV_ML_MEMBER_RISK·CHURN_CAMPAIGN·SPONSOR_RISK 의 ma 차원 COMMENT 에도 넣을지 | 다음 세션 |
| ③ | 예측 카테고리(1~59) 에 회비 획득 카테고리 63(초등)·71(홈페이지) 부재 · 일시(49) 포함 — 모델 학습 범위 ML 담당 확인 | 👤 ML 담당 |
| ④ | 개발·중단·미납·회비·활동 5영역 회원 단위 통합 조인 설계 메모 | 다음 세션 |
| ⑤ | 지혜님 회신 = `12_agent개선과제/O246_현업회신_초안.md` 발송 | 👤 사용자 |

### ▣ O246-A-4 ⚪ 결정 완료(재론 금지)

- 회비예측 후원사업·마케팅캠페인명별 = **실적 비중 배분 추정(B안)** · 모델 재학습은 ML 담당 별도 과제(사용자 승인 2026-10-19).
- 배분 기준 기간 = 기준월 포함 직전 12개월 회비 납입액.

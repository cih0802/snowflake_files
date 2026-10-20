## O246 — 예측 특성 매칭 보정 · 예측 × 실적 브리지 · 추정치 문구 (2026-10-19 · trialadmin(iw20760) · ㉡)

- 지시 = 지혜님 메시지 기반 할 일 정리 → 원천 조회 후 잔여 진행(A) → 「모델 없는 축은 실적 매핑 추정치로 · 미매칭 많으면 보완」(B) → 추정치 문구 지정(C) → 세션 정리.
- 사용자 결정 = 회비예측 축 분해 = 실적 비중 배분 · 통합 와이드 뷰 대신 브리지 · 미매칭 절반 이상 보완 · 문구 「본 값은 ○○ 예측 머신러닝 데이터를 기반으로 실적 비중을 적용한 추정치입니다」 · 지혜님 회신 완료.
- ㉡ 적용 · 확정위반 1 = O246-A 에서 ACCOUNTADMIN 으로 CREATE OR REPLACE 해 소유권·GRANT 소실(즉시 복구 · sv_unit_gate 검출) · 이후 GN_DW_ADMIN 고정.
- 단위 = O246-A · O246-B · O246-C(인수인계 라벨 3개).

### 독해 기록(R1-3-7-b)

- `00_guides/00_작업지침_세션운영규칙.md` 1-305 도착 · R0-8-4 · R4-4-4.
- `20_issue/00_BRIEF.md` 1-132 도착 · O246-A:42 · doc_type 🟡.
- `05_SV-Agent_ai/22_ML_SV_DDL.sql` 263-326 도착 · vqr_total_forecast_by_month · 원천 삭제로 미제공.
- `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0243-B.md` 1-53 · `-O0244-A.md` 1-59 · `-O0245-A.md` 1-64 도착 · handoff_ddl 105 · live_change 41→0 · 12,211,671,575원.
- 스킬 참조 `references/session-end.md` 1-119 도착 · --rollover · 1-2 선택 게이트.
- read 미반환 0 · 재호출 0.

### 실측 근거(iw20760 · 2026-10-19)

- 고위험 7,016명 중 6,608(94.2%) 미매칭 = 기준월 202609 당월 FACT_MEMBER_MONTHLY 행 부재(직전 12개월 보유 100%) ⇒ 폴백 후 금액대·기간대 0 · 납입방식 220(3.1%).
- 회비예측 12개월 190,654,663,995원 ↔ 실적 194,834,682,855원 · 예측 카테고리 1~59(63·71 부재 · 49 일시 포함) · 배분 (실적 비중 없음) 27.6%.
- 브리지 202609 = 70,158 회원 유일 · 마케팅캠페인명 70,157 · UTM 22,910 · 기대 중단 30,996(추정).
- 개발예측 TOTAL 363,253만원 ↔ 실적 신규·증액·재후원 333,582만원 · 4축 배분 합 일치 · 마케팅채널 (미지정) 38.2%.
- SERVING ML 뷰 12 → 15 · SV_ML 10 → 11(라이브 재측정).

### 배포(라이브 · GN_DW_ADMIN)

- 뷰 = ML_MEMBER_ATTR_ASOF_V(변경) · 신설 ML_FEE_FORECAST_ALLOC_V · ML_MEMBER_PRED_BRIDGE_V · ML_DVLP_FORECAST_ALLOC_V.
- SV = SV_ML_FEE_FORECAST(FA) · SV_ML_DVLP_FORECAST(fa) · 신설 SV_ML_MEMBER_PRED_BRIDGE.
- Agent = MEMBER VERSION$5(A) → $6(B) → $7(C) · EXECUTIVE·MARKETING $6(B) → $7(C).
- 스모크 = F1·R1(A) · B1·B2·B3(B) 라우팅·라벨 정상 · 결함 2(answer 태그·상세 2회 / UTM 대체 축 미제안) → O246-C ㉠.
- 정본 = 21·22 DDL · Agent yaml 3종 · 요청·대응 = `12_agent개선과제/20261019_현업요청사항및대응.md`.

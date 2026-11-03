### ▣ O198-A-0 🔴 먼저 알아라 (2026-10-02 · 개발계 pw69582 · O196 계열 잔여 집행 · 사용자 일괄 승인 · ㉡ 적용)

- 🟢 원장 조각 002 재균형 PASS(40,752 → 27,385 B · 스냅샷 `_archive/00_INDEX_이슈원장.md.O198-prerebalance`) + O196-F·O198 행 등재.
- 🟢 산출물 04~09 전량 재생성 + 골든 재발행(PASS 21 · self-check 전건 검출) · 🆕 골든에 `08.row_keys` 신설(개수만 저장하던 결함 시정).
  · 08 +104 중 102 귀속(2차-B 99 · O190 `BDGT_PRCD_NM` 1 · O190-F `DIRECT_MNYRS_YN_1/2` 2) · 🔴 잔여 2 = 구 골든이 개수만 담아 검증 불가(사유에 명시).
- 🟢 DEC-60 = 예산단위 → `DIM_BUDGET_ITEM.BDGT_UNIT_NM` · 개발인입경로 → `FACT_BUDGET.DVLP_INBOUND_PATH`(grain 확장) — DDL·ADMIN ALTER·모델·grain 테스트·SV_BUDGET 배포 완료.
- 🔴 **dbt build 전이다** — 새 2컬럼은 라이브에 있으나 값 NULL · FACT_BUDGET 은 아직 1,332행(기대 1,488).
- 🟢 Agent = MEMBER V6(도구 13 · `analyst_relation_activity` 신설) · EXEC V7 · MKT V7 · 롤백 = V5 · V6 · V6.
- 🟢 스모크 39/39 PASS(중간 오류 1 = MKT_07) · 결연 가드 R1·R2 라우팅 HIT · 🔴 R1 답변 연간 선물금 암산 오류(+1,000,000 · SQL 결과는 정확).
- 🟠 자기결함 = 06 을 임시 실행기로 1회 잘못 생성(정식 러너 미사용 · 즉시 폐기·재생성) · 스냅샷 2건 `UNLABELED-regen.6·7` 로 남음(SESSION_LABEL 누락).

### ▣ O198-A-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | dbt build(사용자) | `ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';` → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_BUDGET_ITEM FACT_BUDGET+';` |
| 2 | build 후 판정 | FACT_BUDGET 1,488행 · 편성 44,707,991,168 · 집행 55,094,546,656 불변 · `warn_fact_budget_grain` 0 · DIM 단위 NULL 0(SK=0 제외) · 예산단위·인입경로 NL 가드 2문항 |
| 3 | 응답 암산 오류 처방 | 3 Agent response 에 「합계는 도구 결과의 합계 행을 쓰고 직접 더하지 않는다」 규칙 추가 여부 결정(추천 = 추가) |
| 4 | O197 계열 | MSTR 원 리포트 대조 · 이력 재적재 · 전체 이관 스킬화 |

### ▣ O198-A-2 🟠 남은 작업 — ㉡ 현업·사용자 결정

| 순 | 항목 | 추천안 |
|---|---|---|
| 1 | 「컬쳐콘텐츠팀」 ERP 예산단위 부재(실측 6종 · 유사 = 콘텐츠기획팀) | 현업에 「컬쳐콘텐츠팀 예산 = 콘텐츠기획팀인가」 확인 · 회신 전 매핑 금지(SV 에 「없음」 안내 배포됨) |
| 2 | 개발인입경로 NULL 1,596행(집행 0) | 수용 — 원장 미기재 그대로 NULL |
| 3 | 직접모금비 YN_1/YN_2 정의(문서20 -009) | 회신 전 두 지표 병기 유지 |

### ▣ O198-A-3 ⚪ 결정 완료(재론 금지)

- DEC-60(예산단위 = 차원 · 인입경로 = grain 확장) — 정본 = `30_설계_의사결정-017.md`.
- 골든 08 잔여 2행은 「검증 불가」로 종결 — 이번부터 행 키로 대조한다.

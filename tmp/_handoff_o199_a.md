### ▣ O199-A-0 🔴 먼저 알아라 (2026-10-02 · pw69582 · GN_DW 재구축 직후 · ㉡ 적용 · 확정위반 1건)

- 🟢 GN_DW 는 **재구축 완료 상태**다(사용자 · BRONZE → SILVER → GOLD → SV → Agent 전 파이프라인 실행).
  · 라이브 스키마 14 = BRONZE 6 · SILVER · GOLD · ML · SERVING · OPS · SECURITY · DBT_TEST__AUDIT · PUBLIC.
  · 🔴 **`GN_DW.MSTR` 는 없다**(SHOW SCHEMAS 실측) ⇒ O197 MSTR 뷰는 재배포 전이다.
- 🟢 ML 12 SERVING 재배선 = `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` · `22_ML_SV_DDL.sql`(사용자 실행 완료).
  · `ML_LTV_SCORE_V`·`SV_ML_LTV_SCORE` 폐기 · 라이브 부재 확인(DROP 불필요).
  · 회원 예측 원천 중복(202606 · 101,817 키 중 16,290 중복) = 확률 평균 · 판정 MAX 로 단일화.
  · 구 22번 = `05_SV-Agent_ai/_archive/22_ML_SV_DDL_pre_O198.sql` · 🔴 구 21번은 보관하지 않았다.
- 🟢 Agent 3종 스펙 갱신 + `09_2_AGENT_버전업.sql` 집행.
  · VERSION$3 default · 도구 MEMBER 13 · EXEC 8 · MKT 10 · 참조 SV 31/31 실재 · grant 4행씩 보존.
  · EXEC = `analyst_ml_ltv_score` 제거 · LTV 유형 `MKTG_CHANNEL_AVG_MEMBER`/`CMPGN_TOTAL` 로 교체.
  · MEMBER·MKT = 회원상태·결제수단·캠페인·관측월 축 삭제 문안 반영 · 질문 2건 교체.
  · 🔴 VERSION$1·$2 는 **도구 0**(재구축 빈 스펙) ⇒ 롤백 대상으로 쓰지 마라.
- 🟢 게이트 = `sv_identifier_gate` PASS · `line_len` PASS · `index_row_gate` PASS.
- 🟠 자기결함 1 = 원장 002 §1 행 삽입 시 `O198-C` 행 접두를 잘라냄 → 즉시 복구 · 게이트 PASS 확인.
- 🟠 임시 스크립트 3 = `tmp/_scratch_o199_exec.py` · `_scratch_o199_member_mkt.py` · `_scratch_o199_mkt.py`(삭제는 사용자 확인 후).

### ▣ O199-A-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | Agent 라우팅 스모크 | CoWork UI 에서 EXEC LTV 2문항 · MEMBER 등급/회원구분 2문항 · MKT 증액 1문항 |
| 2 | 설계 문서 stale | `20_ML_SV_설계.md` §표(SV 7종·LTV_SCORE) · `04_SV_설계.md:591` · `21_…설계이력_부록.md` [6] |
| 3 | 09_2 [0] 정적 목록 | 스펙 31건과 불일치(TARGET_BIZ·MKT ML 2종 누락) ⇒ 목록 갱신 또는 게이트 위임 명시 |
| 4 | 원천 확인 2건 | `CMPGN_SPNSR_AMT_LTV.MKTG_CHANNEL` 값 = 캠페인코드(50/50) · 회원 예측 중복행 |

### ▣ O199-A-2 🟠 남은 작업 — ㉡ 워크스페이스 백로그(O198-A/B/C 승계분)

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 🔴 SILVER 예측집계 3종 적재 | 라이브 3종 **0행**(코멘트 17/17·29/29·8/8) · A share 공유분 적재 확인 |
| 2 | SILVER 3종 SV 배선 | ▣3 추천안 결정 → 모델·SV·Agent 도구 |
| 3 | MSTR 재배포 + MSTR Agent | O197 도구로 `GN_DW.MSTR` 재생성 → ▣3 추천안 |
| 4 | 07 C_CONSUMER · 문서 stale | O198-C-1 ⑥ 축7 stale(01·02_1·03 의 82/17) |
| 5 | LOADER DML 권한 · O197 MSTR 대조 | O198-C-1 ⑦·⑧ 그대로 |
| 6 | 현업 회신 | 컬쳐콘텐츠팀 예산단위 · 직접모금비 YN_1/YN_2 · 기획실/회원실 자체 수식 |

### ▣ O199-A-3 🟡 설계 추천안 (사용자 결정 대기 · 재론 가능)

- **SILVER 3종 → GOLD**(ML 아님).
  · 근거 ① 이 3종은 ML 모델 산출물이 아니라 부서 자체 수식 집계다(`DATA_TYPE_NM` 이 목표/실적·예측/실측을 가른다) ⇒ ML 에 두면 「ML 예측치」 규칙과 섞인다.
  · 근거 ② `GN_DW_DBT` 는 SILVER 읽기·GOLD 쓰기를 이미 갖는다 ⇒ ML 권한 추가가 필요 없다.
  · 방식 = dbt **view 모델**(GOLD) + `persist_docs` 컬럼 코멘트 · M01~M12 언피벗 · `DATA_TYPE_NM` 분리.
  · 대안 = 06_DDL 에 plain view(SERVING ML 뷰처럼 뷰 정의 안 COMMENT) — dbt 없이 가능하나 테스트·계보가 빠진다.
  · 🟢 Agent 는 SV 메타(차원·지표 COMMENT)를 읽는다 · 컬럼 코멘트를 쓰지 않는다 ⇒ 뷰 COMMENT 로 충분하다.
- **MSTR Agent = 신설 4번째 · 도구 재사용 구조**.
  · `GN_DW.MSTR` 뷰 → `SERVING.SV_MSTR_*` → `SERVING.AGENT_MSTR`(스펙 = `cortex_project/agents/AGENT_MSTR/`).
  · 09_2 [0-B]·[0-C]·[2]·[3] 에 4번째 블록 추가 · `sv_identifier_gate` 는 스펙 폴더를 자동으로 읽는다.
  · 현업 승인 후 기존 Agent 에 **같은 SV 를 도구로 추가**한다(SV 복사 금지).
  · 🔴 같은 지표가 GN_DW 와 MSTR 에서 정의가 다를 수 있다 ⇒ 도구 description 에 「MSTR 기준」 명시 · 한 표 합산 금지 규칙.

### ▣ O199-A-4 ⚪ 결정 완료(재론 금지)

- ML 12 · SILVER 4 · SV_ML_LTV_SCORE 폐기 · ONCE_CONVERSION 다중 예측행 유지(DEC-59 #1).

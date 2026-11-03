### ▣ O193-B-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582 · 데이터 입고 완료)

- 🟢 이 계정은 이제 **데이터가 있다** — dbt build PASS 577 · WARN 21 · ERROR 0(사용자 보고) · SV 19 · Agent 3.
- 🟢 O192-A ▣2 의 **0단계 · ① 판정 · ② SV(2차-B 잔여)** 를 끝냈다. 근거 = `20_issue/_o193b_evidence.md`(실측 원문 · 좌표).
- 🔴 O192-A 가 「운영계 삭제」로 적은 ML 3종(`DEPT`·`SPNSR_BSNS_ID`·`NEW_OLD`)이 **이 계정에는 있다** — 주석은 되살리지 않았다(D-3 · 사용자 결정 대기).
- 🔴 **2차-B SILVER 99컬럼 판정식(COMMENT 태그)은 더 쓸 수 없다** — O192-B 가 태그를 지웠다. 명세 기반으로 다시 재라(`_scratch_o191g_gold.py` SPEC 이 GOLD 38 명세).

### ▣ O193-B-1 🟢 이 단위가 끝낸 것

- 라이브 게이트 9종 rc=0: table_ddl_column · gold_erd_coverage · sv_unit · sv_code_label · agent_object_ref · agent_source_lineage · comment_drift · sv_identifier · agent_tool_claim.
- SV 배포(`deploy_sv.py --apply`): 05_1·05_2 문자수신 · 05_4 대체문자(MSG_AT)·확인여부(SND)·문자수신 · 05_5 본인참여·자기참여코드(MS060)·행사장소·문자수신 + `TOTAL_COMPANION_CNT`.
- 05_2 AI_SQL_GENERATION (예측)절 = O193 절차로 정렬(다른 예측 SV 지목·추세값 허용 문구 제거).
- `SELF_PART_FLAG` COMMENT stale 교정 = `06_DDL.sql:929` + 라이브 ALTER · `_wide_schema.yml:910`(🟠 dbt build 후 반영).
- Agent 3종 도구 7개 description 에 신규 축 안내(`[O193-B]`) → 09_2 [0-B]·[0-C] OK → **VERSION$4 default** · 롤백 = `SET DEFAULT_VERSION = 'VERSION$3'`.

### ▣ O193-B-2 🟠 남은 작업

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | dbt build | WIDE 뷰 COMMENT(yml)는 build 로만 반영 · R4-1 | 사용자: `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select WIDE_EVENT_PARTICIPATION'` → `comment_drift_gate` |
| 2 | 스모크 재측정 | 과금 · 승인 대상(O192-A ③) | 39문항 + ML 가드 3 + O193 가드 2(원천 테이블명 · 예측 부재 시 실적 되묻기) |
| 3 | O192-A ④⑤ | 신규 발견 처리 · 산출물 03~09 재생성 | 프롬프트 입력 시 착수(사용자 지시) |
| 4 | 원장 미기록 | O191-G · O192-A · O192-B 행·이력 없음 | 그 단위 인수인계 파일을 근거로 등재 |
| 5 | 결정 대기 | O192-A ▣3 D-1~D-7 · EXECUTIVE/MARKETING 원천 괄호(lineage advisory) | 사용자 |
| 6 | 임시 계측기 | `scripts/_scratch_o193b_agent_desc.py` · `_scratch_o191*` | `gate_census --final` 전 삭제 또는 승격 |

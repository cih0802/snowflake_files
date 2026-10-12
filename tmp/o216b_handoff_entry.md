## O216-B 인수인계 (eval 롤·소유권 정리 + EXEC·MEMBER 문항별 분석 · 2026-10-12 · CK24285)

### ▣ O216-B-0 🔴 먼저 알아라 (㉡ 적용 · 승인 = 사용자 지시 3건 · 확정위반 0)

- `tmp/o216_eval_ds.py:20` · `tmp/o216_eval.py:21` 실행 롤 ACCOUNTADMIN → **GN_DW_ADMIN**(코드 수정 · 미실행).
- 소유권 이관 13종 → GN_DW_ADMIN(`GRANT OWNERSHIP … COPY CURRENT GRANTS` · 재조회 확인 13/13).
  · 테이블 6 = `EVAL_O211_AGENT_EXECUTIVE_V2` · `EVAL_O211_AGENT_MEMBER` · `EVAL_O211_AGENT_MARKETING_V2` · `EVAL_O216_AGENT_*_V3` 3.
  · 스테이지 1 = `SERVING.EVAL_CONFIG_STAGE` · 데이터셋 6 = `O211_*_DS*` 3 · `O216_*_DS_V3` 3.
  · 🟠 기존 eval run 기록(ACCOUNTADMIN 실행분)은 그대로다 · GN_DW_ADMIN 으로 새 run 실행은 아직 실증 안 함.
- 문항 매핑 = 해시 매핑 불요 — `GET_AI_EVALUATION_DATA` 의 `INPUT` 이 질문 원문이다 ⇒ 입력 테이블 `INPUT_QUERY` 와 조인.

### ▣ O216-B-1 EXEC AC 0.8738 문항별 분석 (run `o216_executive_v3_base3` = V$3 · `o216_executive_v3_v8` = V$4 · DS V3)

- 21문항 중 만점 14 · 감점 7 = Q03 · Q04 · Q05 · Q06 · Q13 · Q15 · Q18.

| 군 | 문항 | AC V$3→V$4 | 채점기 근거(원문 요지) | 처방 후보 |
|---|---|---|---|---|
| ㉠ 회비 안내 | Q03·Q04·Q05·Q06 | 1→0.67 · 1→0.67 · 0.33→0.67 · 0.33→0.33 | 「goes beyond the expected answer by offering to calculate estimates using assumptions」 | 정답지(「수치 만들지 않고 안내」) ↔ O207-C 미정의 지표 규칙(「가정 제시 후 계산할지 묻기」) **충돌** ⇒ EXEC 스펙에 「회비 예측·시뮬레이션 = 계산 제안 없이 AGENT_MEMBER 안내만」 1줄 · 또는 정답지 완화 |
| ㉡ 다도구 | Q13 | 0.33→0.67 · TS 0.5 | 「Missing: analyst_mstr_spnsr_dvlp」 · 「requires presenting 1-3 lines of assumptions and asking」 | 정답지가 2도구 + 가정 확인을 요구 — 정답지 재검토(MSTR 도구가 실제로 필요한가) |
| ㉢ 되묻기 | Q15 | 0.67→0.67 · TS 0.5 | 「when no specific campaign is designated, the system should ask back」 · 「Extra: analyst_ml_dvlp_forecast (+1)」 | 캠페인 미지정 시 되묻기 우선 규칙(스펙) |
| ㉣ 유의사항 | Q18 | 1→0.67 | 「'요인분석 = 3종 공통 · 단위를 정할 지표가 없다'는 내용이 … 반영되지 않았습니다」 | 피처 중요도 응답에 유의 1줄(스펙) |

- 판정 = V$3→V$4 순변화는 문항 단위 ±1단계(0.33)의 채점 변동이 섞인 결과다 · ㉠ 4문항이 감점의 주축(합 −1.33 / 21).
- O211-B 0.91 대비 −0.036 은 ㉠ 군 하나를 고치면 넘는 폭이다(4문항 ×0.33 ÷ 21 ≈ +0.063 · 추정).

### ▣ O216-B-2 MEMBER 도구선택 0.44 대 분석 (run `o216_member_v3_v8`)

- 🔴 O215 ㉣ **실측 확인** — 채점기는 호출을 **다중집합**으로 센다(같은 도구 반복 호출 = Extra 감점).
- 13문항 중 **도구 집합이 맞고 반복만 감점** = Q09 · R12 · Q08(+feature_importance) · Q02 · Q32 · R10 · Q01 · (Q28 · R14 만점).
- 실제 누락·오선택 3문항:

| 문항 | 정답지 | 호출 | 판정 |
|---|---|---|---|
| D3 | analyst_mstr_spnsr_dvlp | analyst_member_event | 오선택(또는 정답지 재검토 — 「후원중단 사유별」의 MSTR 소관 여부) |
| R15 | member_cohort · member_event · mstr_spnsr_dvlp | member_cohort ×8 | 2도구 누락 |
| R13 | service · service_cohort | service_cohort ×2 | analyst_service 누락 |

- 집합 기준 재현율(손계산) = 0+1/3+1/2+1+1+1/2+1+1+1+1+1+1+1 = 10.33/13 ≈ **0.79**.
- 처방 후보 = ㉮ 데이터셋 V4 — 반복 호출 허용 정답지(채점기 한계 상 직접 표현 불가 ⇒ 판정은 `tool_selection` 대신 집합 재현율을 별도 계산) ㉯ 스펙 — 「같은 도구는 한 질의에 축을 모아 1회」 규칙.

### ▣ O216-B-3 🟠 ㉠ 이 작업의 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | EXEC ㉠ 처방 택1(스펙 1줄 vs 정답지 완화) | 🔴 사용자 결정 · 스펙이면 VERSION$5 배포 + eval(과금) |
| 2 | Q15 되묻기 · Q18 유의사항 · MEMBER 반복 호출 규칙 스펙 반영 여부 | 결정 후 1회 배포로 묶는다 |
| 3 | D3 · Q13 정답지 재검토(MSTR 도구 필요성) | 현업 기준 확인 |
| 4 | GN_DW_ADMIN 으로 eval 1회 실행해 롤 변경 실증 | 과금 |

### ▣ O216-B-4 ⚪ 결정 완료(재론 금지)

- eval 객체 owner = GN_DW_ADMIN · eval 스크립트 롤 = GN_DW_ADMIN.

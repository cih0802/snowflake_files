<!-- LLM-METADATA
doc_id: HANDOFF_O0241_C
doc_role: 인수인계 — 세션 `O241-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-18
created_by: O241-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0241-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 🟢 현행 판정식 = 라벨 최대값 ⇒ 다음 세션은 **이 파일 1개만** 읽으면 된다(O241-B 의 ㉡ 백로그 ④~⑧ 은 이 파일 B-3 절로 승계).

### ▣ O241-C-0 🔴 먼저 알아라

- 🔴 이 세션은 **워크스페이스 마운트가 없었다**(/workspace 에 파일 1개). 모든 파일은 `cortex ws cp` 로 내려받아 `$HOME/w` 에서 고치고 다시 올렸다.
  - `handoff_write.py` · `split_doc.py` 는 실행하지 않았다 ⇒ 다음 세션(마운트 정상)에서 이 파일 기준으로 `split_doc.py --rollover/--republish` · 골든 갱신을 한다.
  - 원본 백업: 로컬 `$HOME/w/bak/`(휘발)뿐이다. 롤백은 아래 버전 번호로 한다.
- 개발계(mn11232) 라이브 배포 완료(사용자 승인 2026-10-18).
  - Agent 3종 = **VERSION$7**. 롤백 기준: $4 = O241 직전 · $5 = O241-F/T · $6 = O241-M.
  - SV 30종 재배포(05_01~05_26 · 22 · 25) · 뷰 1종 신설.

### ▣ O241-C-1 이 세션에서 한 것

| 단위 | 내용 | 결과 |
|---|---|---|
| V5 | 정답지 `EVAL_O224_AGENT_*_V5` · `O224_*_DS_V5` = V4 + MARKETING Q25(O224-B 대리지표+한계가 정답 · analyst_ga_behavior) | Q25 AC 0 → 1 |
| 원인 | MEMBER 도구 점수 저하 = 같은 SV 재호출(11/13문항) · search_biz_definition 불필요 호출(5) · 기대 도구 누락(Q01·R11·R15) | system_execute_sql 가설 기각 |
| O241-F | response 선두 「출력 전 자기점검 ㉠~㉤」(태그·쉼표·소수·요약 1회·한글 헤더) | 태그·요약중복 해소 |
| O241-T | orchestration 선두 「도구 호출 절약 ①~④」 · ③ = analyst 도구엔 자연어 질문 · 직접 SQL 금지 | MEMBER TS 0.42 → 0.55($5) |
| O241-R | SV 공통 AI_SQL_GENERATION 「반올림 = ROUND(식,2)::NUMBER(38,2)」(36곳) | 소수 결함 해소(S2·S5) |
| O241-M | `SERVING.ML_MEMBER_ATTR_ASOF_V`(기준월 × 회원 · 기준월 말 시점) → SV_ML_MEMBER_RISK · SV_ML_SPONSOR_RISK · SV_ML_CHURN_CAMPAIGN 에 `ma` 관계 + 차원 10 · Agent 지시의 「회원 속성 축 없음」 문장 교체 | 연령대 분해 합계 70,158 = 원본 일치 · 매칭 97~99% |

- O241-M 축(기준월 말 시점 · 모델 피처 아님) = 성별 · 연령대 · 지역 · 회원상태 · 회원구분(개인/기업/단체 = 법인구분) · 후원금액대 · 유지기간대 · 신규기존 · 납입방식(그 달 청구액 최대 결제수단 · 잠정) · 매칭여부.
- 원천:
  - DIM_MEMBER_STATUS_HISTORY(유효구간)
  - FACT_MEMBER_MONTHLY(AMOUNT_BAND1 · PERIOD_BAND1 · NEW_EXISTING_FLAG)
  - WIDE_MEMBER_FEE(PAYMENT_METHOD_NAME)
  - 🔴 FACT_MEMBER_MONTHLY.PAYMENT_SK 는 202609 전건 `(미매핑)` 이라 쓰지 않았다.
- 일시후원 전환 예측(ML_ONCE_CONVERSION_V)은 회원번호 체계가 달라 이 축을 붙이지 않았다(기존 성별·회원구분·등록부서 유지).

### ▣ O241-C-2 점수(native eval)

| Agent | O241(V4·$4) | o241f(V5·$5) | o241m(V5·$6) |
|---|---|---|---|
| EXECUTIVE AC/LC/TS/TE | 1.00/0.92/0.95/0.79 | 0.97/0.86/0.95/0.78 | **1.00/0.95/0.98/0.80** |
| MARKETING | 0.905/0.858/0.798/0.957 | 0.976/0.906/0.916/0.957 | **0.976/0.905/0.911/0.964** |
| MEMBER | 0.821/0.745/0.42/0.533 | 0.845/0.745/0.554/0.644 | **0.872**/0.719/0.479/0.494 |

- MEMBER $6 의 TS·TE 하락 = Q01 이 새 회원 특성 축으로 `analyst_ml_churn_campaign` 을 골랐다(정답지는 cohort + sponsor_risk) · 문항 13개라 편차 큼.
- VERSION$7 은 스모크만 돌렸다(native eval 미실행).

### ▣ O241-C-3 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 정답지 V6: MEMBER Q01 「캠페인별 회원 특성」 기대 도구에 analyst_ml_churn_campaign(+ma 축) 허용 여부 | 👤 결정 |
| ② | S4 「클릭월별 미납서비스 전환율」 — 3회 연속 analyst_ga_child_unpaid 를 거치지 않고 system_execute_sql 직접 SQL(영문 열) · 지시로 미해소 ⇒ SV_GA_CHILD_UNPAID VQR 추가 또는 Snowflake 지원 문의 | 다음 세션 |
| ③ | 쉼표 = 플랫폼 자동 렌더 결과표(제목 + 값 줄)에서만 누락 · Agent 가 쓴 표·요약은 정상 · SQL 문자열화는 차트를 깨므로 하지 않는다 | 수용(재론 시 근거 필요) |
| ④ | VERSION$7 native eval 1회(V5 · tag o241s) | 다음 세션 |
| ⑤ | 운영계 반영 = 배포순서 파일 신설(32 뒤 · SV 30파일 + 21 뷰 + 09_2 Agent 3종) · 문서실행순서 갱신 | 다음 세션(마운트 필요) |
| ⑥ | O241-B ㉠ ②·③(배선 보류 14건 · MEASURE_OVERRIDE 공91) | 👤 결정 / 다음 세션 |

### ▣ O241-C-B-3 ㉡ 워크스페이스 백로그(O241-B 승계 · 변경 없음)

- ④ O240 배포순서 30 D2 대사 · D5 스모크 5문항(👤)
- ⑤ 현업 A/B 결정 후 다른 안 회수(공#122·공#81·공91·공98)
- ⑥ O238 W5·W6 · 미매칭 41행 현업 회신
- ⑦ 현업 확인 목록(최종캠페인 정의 등)
- ⑧ 회비원장 2022-01 이전 입고 · 2026 연 편성예산 0

### ▣ O241-C-4 ⚪ 결정 완료(재론 금지)

- MARKETING Q25 정답 = 대리지표 + 한계 명시(O224-B) · V3 「답변 불가」 폐기.
- 회원 특성 축 시점 = **기준월 말 시점값**(현재값 아님).
- 반올림은 SQL 에서(ROUND + NUMBER 캐스팅) · 쉼표는 답변 단계에서 — 숫자를 문자열로 바꾸지 않는다.

### ▣ 산출물(워크스페이스)

- `tmp/o241b/`: ds_v5.py · patch_spec.py · deploy_agents.py · eval_v5.py · eval_m.py · eval_s7.py · patch_ml_attr.py · deploy_sv.py · attr_view.sql · eval/ · eval_m/ · eval_s7/(state.json · smoke 답변 · RESULT.md)
- 정본 수정: cortex_project/agents/*/agent_spec.yaml · 05_SV-Agent_ai/05_01~05_26 · 21 · 22 · 25

_Co-authored with CoCo_

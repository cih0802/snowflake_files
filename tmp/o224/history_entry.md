## O224-A 14차 Agent 개선 = 측정 우선 성능 향상 + 요건 R(회원 Agent 중단 예측 × 캠페인 결합 해제) (2026-10-14 · xh20001 · ㉡ 적용 · 과금·발행 승인 · 확정위반 2)

- 착수 = 사용자 지시 「성능 향상 방향(우선순위)을 작업계획 정본으로 보완하고 착수 · O02xx 선점」 · 라벨 = `id_collision_gate --next O` = O224(정의 196 · 참조 223) · 원장 §1 선점 후 착수.
- 선행 산출(같은 세션 · O224 이전 대화) = COMMENT 룰 전수조사 `05_SV-Agent_ai/코멘트_룰_전수조사_결과.xlsx` · Agent 연결 객체 메타 · BRONZE 계보 엑셀.
- P0 기준선(라이브 EXEC V$4 · MEMBER V$4 · MKT V$5):
  · eval 데이터셋이 이 계정에 없었다(계정 이관 손실) ⇒ `tmp/o224_eval_ds.py` 로 `O224_*_DS_V3` 재등록(정답 도구 부재 0).
  · native eval v3_0 = AC EXEC 0.9205 · MEMBER 0.8715 · MKT 0.6900 · 채점 실패 0.
  · 실패 원인 1순위 = 「계산 전 확인 미이행」 5건 · 기계 분류 「도구선택」 14건 대부분은 반복 호출·신규 도구 · 「도구 과다 → 오선택」 가설 기각에 가깝다 · VQR 수요 근거 0.
  · 🔴 발견 = O223 가드레일이 로컬 스펙에만 있고 라이브 3종 0회(원장 O223 행은 반영으로 읽혔다) ⇒ 이번 발행으로 최초 반영.
- P0-4 정답지 V4 = 근거 결정이 있는 6문항만 덮어쓰기(`tmp/o224_eval_ds_v4.py` · EXEC Q13·Q15·Q18 · MKT Q17·Q22·Q33) · 이번 비교는 V3.
- P3 = 3종 orchestration 맨 앞 `[O224 도구 호출 전 판정]` · 원인 실측 = MKT orchestration 에 일반 확인 규칙 부재(response 에만 있었다).
  · MKT V$6 = AC 0.6900 → 0.8329(+0.143) · 회귀 Q33 → O224-B(② 범위 축소) → V$7 스모크 5/5.
  · EXEC V$5 = AC 0.9205 → 0.9048(잡음 폭 안) · 회귀 Q18 → O224-C(예외 확장) → V$6 스모크 3/3.
  · MEMBER V$5 = AC 0.8715 → 0.8200(−0.05) · 과적용 R14 · 미적용 R12·R13(`[O217 정의 조회]` 선행) ⇒ O224-D 로 MEMBER 에서만 판정 블록 제거 → V$6 스모크 2/2.
- 요건 R = AGENT_MEMBER 「두 데이터셋 결합은 플랫폼이 차단」 응답 해제.
  · 실측 = Analyst 는 SV 1개만 조회 · `SV_ML_MEMBER_RISK` 에 캠페인 축 없음 · MKT 「해제」의 실체는 증액용 사전 결합 SV(`SV_ML_INC_CAMPAIGN`)이고 중단 × 캠페인은 MKT 도 불가였다(MKT V$7 실측 거절).
  · 후원건 단위 대안(`SV_ML_SPONSOR_RISK`)은 1,254명 · 요청 문장 기준(회원 단위 고위험 × 고려인 활동)은 137명 ⇒ 대안은 다른 질문의 답이다.
  · 처방 = `26_ML_CHURN_CMPGN_CTGR_DDL.sql`(`SERVING.ML_CHURN_BY_CMPGN_CTGR_V` + `SV_ML_CHURN_CAMPAIGN` · VQR 2) · MEMBER 도구 `analyst_ml_churn_campaign` · 라우팅 · `09_2` [0] 1행.
  · 배포 전 Analyst 시험으로 결함 2건 교정(활동 약정 수 COUNT 재집계 · 분모 CTE 등급 조건 혼입) · 스모크 17,753 / 2,033 / 137 / 1,254 일치 · 원문 질문 단일 호출 137명.
- 확정위반 2(유실 0):
  · `R1-7-2` = 작업계획 2번째 편집에서 해시 확인을 `edit` 와 같은 응답에 병렬로 보냈다 · 이후 단독 선행.
  · `R1-7-1` = YAML 왕복이 바이트 동일하지 않아 Agent 정본 3종을 전체 재작성했다 · 보강 = `snapshot_util` 스냅샷 + 편집 외 키 의미 동일 단정 + 쓰기 후 재읽기 일치.
- 라이브 변경(xh20001) = 뷰 `ML_CHURN_BY_CMPGN_CTGR_V` · SV `SV_ML_CHURN_CAMPAIGN` · eval 표 `EVAL_O224_AGENT_*_V3/V4` + 데이터셋 6 · `EVAL_CONFIG_STAGE` · Agent MKT V$5→V$7 · EXEC V$4→V$6 · MEMBER V$4→V$6 · native eval run 6 · 표적 스모크(DATA_AGENT_RUN) 16회.

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R2-8-4-d` · `R4-4-4`.
- `20_issue/00_BRIEF.md` 1~126 · 도착 · `O0223-A` · `3,216,080` · `조문 112개`.
- `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0223-A.md` 1~57 · 도착 · `O223-A-3` · `#12, #14, #17, #19`.
- `12_agent개선과제/00_작업계획.md` 1~933(4회) · 도착 · `T8 판단표` · `47/48 = 97.9%` · `VERSION$7 O216-F`.
- `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md` 1~117 · 도착 · `doc_type_gate.EXTRA_DOCS` · `O211`.
- `05_SV-Agent_ai/23_ML_INC_MKTG_CMPGN_DDL.sql` 1~136 · 도착 · `ML_INC_BY_MKTG_CMPGN_V` · `28,324`.
- `12_agent개선과제/tools/o217_agent_io.py` 1~96 · 도착 · `MODIFY LIVE VERSION` · `100,000`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_

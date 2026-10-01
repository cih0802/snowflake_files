<!-- LLM-METADATA
doc_id: HANDOFF_O0196_F
doc_role: 인수인계 — 세션 `O196-F` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O196-F
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0196-F -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O196-F-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582 · 세션 마무리)

- 🟢 FMD 재build(사용자 PASS 13) 판정 = 41,935,344행 불변 · `SEND_REQUEST_SK` 고아 FK **0** · 요청 미매칭 11,421 → 0 라우팅. ⇒ DEC-58 구현 종결.
- 🟢 O196 계열(A~F) 현행 = **이 파일**. 형제 A~E 의 잔여는 아래 표로 통합했다(그 파일들은 근거로만 연다).
- 🔴 사용자 지시 = **더 중요한 신규 요건을 먼저 수행** ⇒ 아래 잔여는 그 뒤로 미뤘다(취소 아님).
- 🔴 원장 조각 002 = 40,370 B(상한 40,960 B) — 이 단위는 원장 행을 추가하지 않았다(이력·인수인계만). 다음 행 추가 전 `--rebalance`(승인 완료분).

### ▣ O196-F-1 🟠 남은 작업 — ㉠ O196 계열 잔여 (신규 요건 뒤)

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | ERP 예산단위·개발인입경로 전파 | 사용자 승인 대기 · SILVER `ERP_BUDGET.BDGT_UNIT_NM`·`DVLP_INBOUND_PATH` → `06_DDL` FACT_BUDGET + 모델 → build → SV_BUDGET 차원 → Agent MKT·EXEC · 🔴 「컬쳐콘텐츠팀」 ERP 부재(실측 = 콘텐츠기획팀) 현업 확인 |
| 2 | SV_RELATION_ACTIVITY Agent 배선 | 대상 Agent 결정(추천 = MEMBER) → 도구 추가 + 버전업 |
| 3 | 스모크 재측정 | Agent 버전 변경(MEMBER V5 · EXEC V6 · MKT V6) · 과금 승인 |
| 4 | 산출물 골든 | 08 +104 행 중 5 미규명 분해 → `test_generators.py --update-golden --reason` |
| 5 | 원장 조각 002 재분할 + O196-E·F 원장 행 | `split_doc.py 20_issue/00_INDEX_이슈원장.md --rebalance` 후 행 추가 |

### ▣ O196-F-2 ⚪ 결정 완료(재론 금지)

- DEC-58(요청 차원·결연활동 팩트) · DEC-59 #1~#7(D-4 현행 유지 · D-5 종결 · ⑭ 귀속 · ⑩ 재분류·정의 소유 · 각주 차원 제외) — 정본 = `30_설계_의사결정-017.md`.

_Co-authored with CoCo_

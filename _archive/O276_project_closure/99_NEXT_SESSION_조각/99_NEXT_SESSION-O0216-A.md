<!-- LLM-METADATA
doc_id: HANDOFF_O0216_A
doc_role: 인수인계 — 세션 `O216-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-12
created_by: O216-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0216-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O216-A 인수인계 (신규 계정 CK24285 점검 + 8차 Agent 배포 · eval 기준선 재확정)

### ▣ O216-A-0 🔴 먼저 알아라 (2026-10-12 · CK24285 · ㉡ 적용 · 승인 = COMMENT apply · eval 방식 · 확정위반 1)

- 계정 = CK24285 · 역할 ACCOUNTADMIN(GN_DW_ADMIN 세션 포함) · GN_DW 스키마 15(BRONZE 5 포함) · 역할 7종 · 웨어하우스 4종.
- 🔴 이 계정의 Agent 버전 체계는 nj58180 과 다르다 — 이관 시 V$1~3 으로 재발행(V$3 = O213 7차 스펙 · 파일 정본과 차이 0).
  · 「VERSION$6」은 이 계정에 없다 ⇒ 6차 상태 eval 은 불가 · 사용자 결정 = V$3 로 기준선 대체.
  · 🆕 8차 = **VERSION$4**(3종 default · 도구 22·12·20 무변경) · 롤백 = `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$3'`.
- 🔴 eval 인프라는 이관되지 않았다 ⇒ O216 재구축 = `SERVING.EVAL_CONFIG_STAGE` · 데이터셋 6종.
  · V2(O211 규칙 재현) = `O211_EXECUTIVE_DS_V2`·`O211_MEMBER_DS`·`O211_MARKETING_DS_V2`.
  · V3(A안) = `O216_EXECUTIVE_DS_V3`·`O216_MEMBER_DS_V3`·`O216_MARKETING_DS_V3` · 생성기 `tmp/o216_eval_ds.py v2|v3`.
  · 러너 = `tmp/o216_eval.py start|status <VERSION> v2|v3 <tag>`(run = `o216_<agent>_<ds>_<tag>`).
- 🔴 확정위반 1 = `R1-7-8` 계열 — 05_18 장문 행 분할 스크립트가 후반부(`b`)를 누락해 유실 → 라이브 `GET_DDL` 원문으로 즉시 복원(913+1+1,093 = 원 2,007자 · 유실 0).
- 🔴 세션 말미 `/workspace` 마운트 분리(스테이지는 정상 · `cortex ws ls` 실증) ⇒ 6.1 게이트 재실행·6.2 원장 §1 갱신·라벨 파일 작성을 **다음 세션이 이 파일로 집행**한다.

### ▣ O216-A-1 실측 결과

| Phase | 결과 |
|---|---|
| 1 인프라 | BRONZE·SILVER·GOLD 적재 정상 · 빈 테이블 = GA4/BQ 계열(SYNC_ERR_INFO·BIGQUERY_* 등 · 기존 기재) · MSTR 함수 2종 실재 · WIDE 뷰 15 · PK 86 · FK 67 |
| 2 SV | SV 33종 실재 · 권한 ANALYST·SERVICE·VIEWER SELECT/REFERENCES · `sv_identifier_gate` PASS · `comment_drift_gate` 81건(BIGQUERY_SESSION GOLD 40·SILVER 41 · 라이브 NULL) → `--apply` 후 **드리프트 0** · 2,000자 근접 COMMENT 0 · 05_18 2,007자 행 분할(O214-A-1b 해소) |
| 3 기준선 | 같은 V$3 · 데이터셋만 V2→V3 = EXEC AC **0.7305→0.8886** ⇒ O215 ㉠(정답지↔도구 불일치 = 6차 롤백 귀결) **실측 확인** · 실행 잡음 폭 ≈ ±0.024(MKT 동일 정답 2회) |
| 4 8차 | 4.1 DS V3 · 4.2 MKT 가드레일 · 4.3 SV 33종 `AI_SQL_GENERATION` [O216 SQL 작성 규칙](CREATE OR ALTER · 권한 보존) + 3종 orchestration 요약 · 4.4 V$4 배포 |
| 4.5 eval(DS V3) | V$3 → V$4 · AC = EXEC 0.8886→0.8738 · MEMBER 0.8208→0.8454 · MKT 0.8093→**0.9050** · MKT 도구선택 0.643→0.738 |
| 5 NL | 49문항 최종 실패 **0** · 중간 SQL 오류 **0**(기준선 1 · MARKETING_14 CAL_YEAR 해소) · SQL 46 |
| 5.3 MSTR | 검증쿼리 V01~V09 **전건 PASS**(210행 · V02 고정 기준값 포함) |
| 6.1 게이트 | doc_census · clause_order · index_row · decision_closure · 음성 테스트 전건 rc=0(마운트 분리 전 실측) |

### ▣ O216-A-2 🟠 ㉠ 이 작업의 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 이 파일로 `handoff_write.py --label O216-A --entry-file tmp/o216a_handoff_entry.md` 집행 + 원장 §1 O216 행 갱신(🟡 선점 → 🟢) + `session_brief.py --write` | 마운트 복구 후 |
| 2 | EXEC AC 0.8738 — O211-B 기준 0.91 미달(−0.036) · 같은 정답지 기준 V$3 대비는 잡음 폭 내 | 문항별 분석(input_id 해시 → 질문 매핑 필요) |
| 3 | MEMBER 도구선택 0.44 대 — O215 ㉣(정답지 단일 도구 가정) 검토 | 데이터셋 V4 후보 |
| 4 | 기준선 비교는 같은 데이터셋끼리만(O215-A-2) — 기준선 = DS V3 · V$3 | — |

### ▣ O216-A-3 🟡 ㉡ 워크스페이스 백로그 · 차기 Inspection

- 차기 Inspection 범위 = **O201(점검 세션) 이후 ~ O216** · 원장 §1 결번 0 · 관측 2건 = O204 라벨 파일 부재 · O202-D 라벨 파일은 있으나 원장 행 없음.
- 트리거 = 세션 15개 누적 + 계정 재구축 직후(`11_O누적작업_점검_재현_절차.md` ㉠·㉢ 동시 충족).

### ▣ O216-A-4 ⚪ 결정 완료(재론 금지)

- A안(6차 롤백 존중 · 정답지 정정) 집행 · V$3 기준선 대체 · BIGQUERY_SESSION COMMENT 파일 정본 반영.

_Co-authored with CoCo_

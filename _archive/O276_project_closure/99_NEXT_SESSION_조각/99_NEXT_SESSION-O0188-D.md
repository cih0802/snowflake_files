<!-- LLM-METADATA
doc_id: HANDOFF_O0188_D
doc_role: 인수인계 — 세션 `O188-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-29
created_by: O188-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0188-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O188-D-0 🔴 먼저 알아라 (2026-09-29 · xf98254)

- 🟢 `90_provided_definition/gni_실적부서.csv`(222부서) = **`BRONZE_CRM.TM_CM_DEPT_INFO` 로 하드코딩 없이 재현 가능**(실측).
  · 경로 = `UPPER_DEPT_ID` 재귀 · 최상위 법인 노드만 경로에서 뺀 형태 · **222/222 일치**(부서명 222/222 일치)
  · 포함 규칙 = 자기와 **모든 상위**가 `USE_YN='Y'` 이고 `LAST_UPDT_DT` 가 NULL·`9999-12-31` 이 아님 ⇒ 223 ⊇ 222
  · 🔴 초과 1건 = `B000006 해외파견` — 하위 3개가 전부 비활성인 빈 노드. 「하위 전부 비활성이면 제외」로 일반화하면
    CSV 의 권역본부 10개가 빠진다(하위가 없어도 CSV 에 있다) ⇒ **규칙으로 닫히지 않는 1건** — 현업 로직 회신 대상.
  · `ACMSLT_UPPER_DEPT_ID`(실적상위) 경로는 9/222 만 일치 ⇒ 이 CSV 는 「실적 계층」이 아니라 **활성 조직 트리**다.
  · 🔴 이름 중복 4명(`DIM_ORG.DEPARTMENT`)은 이 규칙에서 **코드가 달라 구별된다**(CSV 도 예산기획팀·컬쳐콘텐츠팀 2코드씩 보유).
- 🟢 SV_AD `GA_DEV_UNIT_PRICE`(공8) 배포 · 재조회 DIGITAL **97,905.60원**(= 정의값) · Agent EXEC·MKT **VERSION$6** default

### ▣ O188-D-1 🟢 이 단위가 끝낸 것

- 문서20 `-001` 332 → 300줄(O188-A 판정 블록 6개를 블록당 1줄로 병합 · 내용 동일 검증) ⇒ `--republish`·`--verify`·`doc_coord_gate`·제목 게이트 PASS
- `05_7_SV_DDL_AD.sql` metric 신설 + 재방송 단가 「공8」 → 「참고(공8 아님)」 4곳 · 라이브 배포 + GRANT 3역할
- Agent yaml 2종 문구 8곳 정정 → OPS 스테이지 동기화(대조 3종 OK) → EXEC·MKT VERSION$6
- `sv_unit_gate.NOT_RATIO` 에 `GA_DEV_UNIT_PRICE` 등재 · sv_unit / agent_object_ref / agent_tool_claim 게이트 PASS · 음성 테스트 8축 PASS
- `_scratch_o188d_*` 8개 개별 삭제

### ▣ O188-D-2 🟠 O188 계열 남은 작업 (A·B·C·D 통합 정본)

| 순 | 출처 | 계층 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|---|
| 1 | D | GOLD | 🔴 | 조직 활성 트리 규칙(▣0)을 `DIM_ORG` 계층·목표 조인에 배선 — `A-5` 부서명 중복 해소 겸 | 설계 가능 · dbt 정지점 | — |
| 2 | D | 현업 | 🟠 | 조직표 로직 회신 — `해외파견` 1건 제외 사유 확인 | 회신 대기 | — |
| 3 | B·C | 현업 | 🔴 | 30번 §2 🔴16·🔄5 질문 발송(판정 공란 21) | 사용자 전달 대기 | — |
| 4 | A-2 | 원천 | 🟠 | DGT 원천 2026-06 이전분 대행사 재송부 | 사용자 확인 | — |
| 5 | A-7 | SV·Agent | 🟡 | 사업목표 SV·Agent 노출(연사업·팀 두 관점 · 합산 금지) | 설계 가능 | 3(N-24①) |
| 6 | A-8 | Agent | ⚪ | invalid identifier 2문항 추가 처방 | 선택 | — |
| 7 | A-10 | 문서 | ⚪ | W3 8건 · B2~B12 | 변동 없음 | — |
| 8 | A-11 | 문서 | 🔴 | `30_output_share` 03·08·09 재생성 → `test_generators` 골든 갱신(`--reason`) | 세션 정리 직전 | 1 |

_Co-authored with CoCo_

<!-- LLM-METADATA
doc_id: HANDOFF_O0197_A
doc_role: 인수인계 — 세션 `O197-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O197-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0197-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O197-A-0 🔴 먼저 알아라 (2026-10-01 · 개발계 pw69582 · MSTR 1차 이관 PoC)

- 🟢 신규 요건 = MSTR(구 SQL Server mart) 리포트 1건 → Snowflake `GN_DW.MSTR` 전환 · 원천 = `BRONZE_CRM` 만 사용.
- 🟢 라이브 = 테이블 10 · 뷰 13 · 함수 2 · 프로시저 13 — `tools/mstr_deploy.py --check` 매니페스트↔라이브 일치.
- 🟢 202601 회귀 기준선 PASS(리포트 10,227행 · 차원명 미매핑 0) · 기준선 = `15_MSTR 이관 PoC/tools/manifests/1차.json`.
- 🟢 ExplCampList 제외 확정(IT 확인 · 2년 미갱신 · skip) ⇒ `D_CMPGN_EXPL_CD` 라이브 DROP · 결정 X1.
- 🟢 도구 정본 = `15_MSTR 이관 PoC/tools/`(README · deps→extract→gen→deploy→run→verify) — 사용자 지시로 `/workspace/scripts` 미사용.

### ▣ O197-A-1 🟠 남은 작업 — ㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | MSTR 원 리포트 대조 | MSTR 측 202601 수치(건수·금액·회원수) 확보 → baseline 과 비교 |
| 2 | 과거 이력 재적재 | `mstr_pipeline.py manifests/1차.json --steps run --hist --apply`(장시간 · SPNSR_AMT2_CD 정확도용 · 리포트 미사용) |
| 3 | 전체 이관 스킬화 | `tools/README.md` 「새 배치 추가 절차」를 스킬 본문으로 · 배치 매니페스트 확장 |
| 4 | 원장 조각 002 재분할 | 40,752 B / 40,960 B — 다음 행 추가 전 `split_doc.py … --rebalance`(O196 승계) |

### ▣ O197-A-2 ⚪ 결정 완료(재론 금지)

- X1 ExplCampList 제외 · X2 `D_STRD_DE_CD` = VIEW · X3 `USP_F_MM_SPNSR_DVLP_INIT` 미이관 · K1~K3 — 정본 = `tools/manifests/1차.json` `decisions`.
- 🔴 자기결함 1 = 같은 파일 병렬 `edit` 4건(R1-7-2) · 해시 2회 대조로 반영 확인 · 이후 순차 편집.

_Co-authored with CoCo_

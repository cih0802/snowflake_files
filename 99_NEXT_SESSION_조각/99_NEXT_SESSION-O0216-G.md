<!-- LLM-METADATA
doc_id: HANDOFF_O0216_G
doc_role: 인수인계 — 세션 `O216-G` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-12
created_by: O216-G
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0216-G -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O216-G 인수인계 (Q10 「코드 없음」 확정 · NULL 사유 등록부 OPS 신설 · OPS 객체 목록 · 2026-10-12 · CK24285)

### ▣ O216-G-0 🔴 먼저 알아라 (㉡ 적용 · 승인 = 사용자 지시 · 확정위반 0)

- Q10 = 사용자 확정 「코드 없음」 → **문서50 O91-F 🟢 종결** · 문서20 `-009.md:197` 🟢.
  · 🔴 **정정** — 「문서50 열린 절 0」은 오보였다. 브리핑 추출기는 `##` 만 보고, 열린 항목 3건이 `###` 하위 절에 숨어 있었다
    (O99 SV 2종 실시간 조인 · 🔴 스냅샷 11종 미가동 = SNAPSHOT 스키마 0 · check_cols RM) ⇒ 문서50 `-024.md` 말미 `## 🟡 O216-G` 절로 끌어올렸다 · 열린 절 = **1(3항목)**.
  · 발견 경위 = `test_gen_unresolved_issue_summary` 축6-c 가 「dbt 축 0」을 FAIL 로 잡았고 독립 계수(26 = 상태 3 + 소제목 23)로 규명 · 테스트는 `##` 독립 계수 대조로 갱신.
  · AD 캠페인 컬럼 5개 `[O216-G Q10 영구 센티넬]`(`tmp/o216g_ad_yml.py`) · 생성 문서 `09_빅테이블 VIEW.md` 같은 턴 재생성(diff 10줄 = 태그 5행 · 스냅샷 `_archive/09_빅테이블 VIEW.md.O216-G-pre-regen`) · `test_verify_wide_doc` PASS.
  · 🟠 라이브 COMMENT = **다음 dbt build** 후 `comment_drift_gate`(뷰 PENDING 5 → 0).
- 🆕 OPS 수기 객체 3종 신설(정본 DDL = `08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql` · 재실행 안전):
  · `OPS.NULL_REASON_CODE` 9코드(DEC-55 §55-C 축 + `UNCLASSIFIED`) · `OPS.COLUMN_NULL_REGISTRY`(0행 · 다음 세션이 채운다) · `OPS.V_OPS_OBJECT_INVENTORY`.
- 🔴 발견 = `08_mornitoring/05~07`(AI·웨어하우스 비용 가드 · 알림 수신자) 정의 객체가 CK24285 에 **0건** — 재구축 런북에 단계가 없었다 ⇒ `12_GN_DW_재구축_실행순서.md` §2-1 순 18 등재(배포 여부 = 사용자 결정 · ACCOUNTADMIN · 알림 이메일).

### ▣ O216-G-1 OPS 관리 방식 (사용자 질문 「생성 쿼리를 남겨야 하나 · OPS 에 뭐가 있는지 모른다」)

- 🟢 **생성 쿼리는 남긴다** — 이유 = 재구축 때 OPS 수기 객체가 통째로 빠진 실사고(위 05~07)가 이 계정에서 실측됐다. 파일이 없으면 다음 계정에서 사라진다.
- 🟢 **목록은 손으로 관리하지 않는다** — `OPS.V_OPS_OBJECT_INVENTORY` 가 라이브에서 읽는다.
  · `MANAGED_BY` = owner `GN_DW_DBT` ⇒ `dbt`(store_failures · build 가 재생성 · 손대지 않는다) · 그 밖 ⇒ `수기`.
  · `DDL_FILE` = 객체 COMMENT 의 `[원천: 수기 · <경로>]` 에서 추출 ⇒ **수기인데 비어 있으면 「정본 미등록」**.
  · 실측 = dbt 테이블 10 · 수기 4(스테이지 1 · 테이블 2 · 뷰 1) · 정본 미등록 **0**(`AGENT_SPEC_STAGE` COMMENT 에 표식 추가 · 파일 `07_ENVIRONMENT_RBAC_setup.sql` + 라이브).
- 🔴 규약(신규 수기 OPS 객체) = ① DDL 을 `08_mornitoring/` 또는 해당 영역 파일에 둔다 ② COMMENT 끝에 `[원천: 수기 · <파일 경로>]` ③ 런북 §2-1 에 순번 1줄.

### ▣ O216-G-2 🟡 다음 세션 착수 계획 — SILVER·GOLD 전건 NULL 컬럼 사유 정리

| 순 | 할 일 | 산출 |
|---|---|---|
| 1 | 전건 NULL 컬럼 검출(SILVER·GOLD · 테이블+뷰 · `COUNT(col) = 0` · 0행 객체는 별도 표기) | 후보 목록 · 측정 계정·시각 |
| 2 | 후보 → `COLUMN_NULL_REGISTRY` 적재(초기 `UNCLASSIFIED`) | 등록부 N행 |
| 3 | 사유 판정 — 정본 순서 = DEC-55 §55-C → 문서30 DEC → 문서20 회신 → 원천 실측(BRONZE) · `UNCLASSIFIED` 0 이 목표 | REASON_CODE · BASIS · REWIRE_CONDITION |
| 4 | 컬럼 COMMENT 끝에 `[NULL: <코드>]` — 파일 정본(06_DDL · 08_SILVER · `_wide_schema.yml`) → 라이브(테이블 = ALTER · 뷰 = dbt build) | `comment_drift_gate` 드리프트 0 |
| 5 | 게이트 신설 = COMMENT 코드 ↔ 등록부 코드 일치 · 전건 NULL 인데 등록부 없음 = blocking · 음성 테스트 | `scripts/null_registry_gate.py` |

- 🔴 범위 = **전건 NULL 만**(부분 NULL 은 패스 · 사용자 결정) · 센티넬 단일값(`'(미매핑)'`)은 NULL 이 아니므로 대상 아님(별도 축 · A4-X/A4-W 태그로 이미 표기).
- 🔴 검출은 대형 팩트(4천만 행대)를 컬럼마다 스캔한다 ⇒ 테이블당 1쿼리(`COUNT(col1), COUNT(col2) …`)로 묶어 웨어하우스 비용을 줄인다.

### ▣ O216-G-3 ⚪ 결정 완료(재론 금지)

- Q10 = 코드 없음(영구 미연결) · NULL 사유 = 컬럼 COMMENT 코드 + `OPS.COLUMN_NULL_REGISTRY` + 원장(테이블 COMMENT 이력 방식 기각) · 범위 = 전건 NULL.

_Co-authored with CoCo_

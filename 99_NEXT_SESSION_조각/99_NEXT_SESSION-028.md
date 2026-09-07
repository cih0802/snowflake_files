<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 028/028 | 허브 = 99_NEXT_SESSION.md | 원문 4085~4167행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
## 0-FFFF. ~~🔴🔴 [2026-09-01 O129 필독 — **여기서 시작한다.** §0-EEEE 는 승계됐다]~~ ➔ 🟢 [2026-09-02 O132 승계됨]

> 🟢 **절차 불변** = `export SESSION_LABEL=O1NN` → 원장 §1 선점(`R1-4-3`) →
> `gate_census.py --run-tests`(🔴 rc 는 리다이렉트로) → `session_brief.py --write` → `00_BRIEF.md` 1회 `read`.
> 🔴 **이 절은 좌표만 운반한다** — 정본 = 이력 **§O129** · 처방 정본 = 문서30 **§7-C**.

### ▣ FFFF1 🔴🔴 먼저 알아라 — 착수 항목은 이제 **착수표에 있다**(O129-B 가 등재를 마쳤다)

O129 초판은 `99_NEXT_SESSION-020` 이 상한(여유 34 B)에 걸려 **등재하지 못했고**, 그 사실을
「등재했다」로 잘못 적었다(자력 적발). ✅ **O129-B 가 사용자 승인으로 해소했다** —
닫힌 행 `~~㉜~~` 의 장문 셀을 포인터화해 용량을 회복하고(행 키·열 수 보존 · `R2-8-1` 토큰 대조 선행)
**㊶㊷㊸㊹** 를 등재했다. ⇒ 🟢 **`00_BRIEF.md` 의 「열린 작업」만 봐도 놓치지 않는다.**

| 항목 | 성격 | 좌표 |
|
## 0-NNNN. ~~🔴🔴 [2026-09-07 O140 필독 — **여기서 시작한다.** §0-MMMM 은 승계됐다]~~ ➔ 🟢 [2026-09-07 O141 승계됨]

> 🟢 **절차 불변** = `export SESSION_LABEL=O1NN` → 원장 §1 선점(`R1-4-3`) →
> `gate_census.py --run-tests`(🔴 rc 는 리다이렉트로) → `session_brief.py --write` → `00_BRIEF.md` 1회 `read`.
> 🔴 **이 절은 좌표만 운반한다** — 정본 = 이력 **§O140** · 설계 정본 = 문서30 **§36(DEC-50)**.

### ▣ NNNN1 🟢 이번 세션 완결 작업 (O139~O140)

1. **[거버넌스 및 명칭 체계 전면 전환] DEC-50 완결**:
   - `BRONZE_GA4` 원천 레이어를 제외한 모든 가공 계층(SILVER, GOLD DIM/FACT/WIDE, SERVING, 산출물)에서 `GA`/`GA4` 명칭을 배제하고 `BIGQUERY`로 전면 전환 완료.
   - DDL 및 dbt 모델 신설: `DIM_BIGQUERY_EVENT`(`BIGQUERY_EVENT_SK`), `DIM_BIGQUERY_SOURCE`(`BIGQUERY_SOURCE_SK`), `FACT_BIGQUERY_BEHAVIOR`, `WIDE_BIGQUERY_BEHAVIOR`.
   - Snowflake Live DB 신규 테이블/뷰 생성 및 구 객체 Drop 정리 완료.
2. **[dbt 파이프라인 무결성 100% 빌드]**:
   - `WIDE_BIGQUERY_BEHAVIOR` 소유권 충돌 해소 및 `tests/warn_erp_budget_yearly_grain.sql` 컬럼 오타 수정.
   - `dbt build --target dev` 실행 결과 총 534개 노드 중 **PASS=495, WARN=39, ERROR=0, SKIP=0** 달성.
3. **[산출물 인벤토리 및 ERD 전수 재발행]**:
   - `02_{SILVER,gold} 스키마 컬럼 인벤토리`(테이블/컬럼 한글명 포함), `04_컬럼계보매핑`, `05_지표GOLD매핑`, `08_보존율`, `09_조립가능성`, `11_미해결이슈_요약`, `erd/*.html` 52종 전량 최신 동기화 완료.
   - `scripts/test_generators.py` 21/21 PASS (사유: `DEC-50 GA to BIGQUERY renaming`).

### ▣ NNNN2 🔴 다음 세션 열린 작업 (파이프라인 프로세스 / 중요도 순)

- **[P1/Gold] ⑫** 🔴🔴 활동 스냅샷 as-of 배선 (`CONF-3` 현업 회신 §N-11 후 배선 진행)
- **[P1/Gold] ⑭** 🔴🔴 `FME.SPONSORSHIP_SK(STOP)` 동시중단 다중사업 귀속 규칙 (현업 결정 후 배선)
- **[P1/Silver] ㊵** 🔴 `CRM_MEMBER.JOIN_DT` 현업 회신(문서20 §N-10) 후 개명/배선 반영
- **[P1/Gold] BLOCKING-5** 🔴 GOLD 팩트 measure 및 차원 FK 미적재분 순차 적재 (A1/A3)
- **[P1/Serving] ②** 🔴🔴 NL 자연어 질의 라우팅 스모크 테스트 (CoWork UI 브라우저 수동 확인)
- **[P2/Silver] O59-P-1** 🟠 `FACT_SERVICE_EVENT.SEND_STATUS2` 처분 현업 회신 대기 (문서20 §M-6)
- **[P2/Docs] ④/⑪/⑱** 🟠 문서50 B1 정의 확정 및 이전 세션 독해 검증 잔여
- **[P3/Silver] BLOCKING-1** 🟡 회원 마스터 원천 전량 입고 후 `severity: warn ➔ error` 승격
- **[P3/Silver] BLOCKING-2** 🟡 CRM/ERP 원천 결손(`CRM_BIZ_TARGET` E-6, 모금비용 E-1) 입고 대기

## 0-OOOO. 🔴🔴 [2026-09-07 O141 필독 — **여기서 시작한다.** §0-NNNN 은 승계됐다]

> 🟢 **절차 불변** = `export SESSION_LABEL=O1NN` → 원장 §1 선점(`R1-4-3`) →
> `gate_census.py --run-tests`(🔴 rc 는 리다이렉트로) → `session_brief.py --write` → `00_BRIEF.md` 1회 `read`.
> 🔴 **이 절은 좌표만 운반한다** — 정본 = 이력 **§O141** · 설계 정본 = 문서30 **§33(DEC-47)** · `32_컬럼개명표.md`.

### ▣ OOOO1 🟢 이번 세션 완결 작업 (O141)

1. **[착수표 ㊵ 완결] `CRM_MEMBER.JOIN_DT` ➔ `FRST_REGIST_DT` 원천명 복원**:
   - `30_output_share/16_파이프라인 배선 수정.md` §1-6 및 문서20 §N-10 현업 회신(지표 28번 정합) 확정 반영.
   - Snowflake Live DB `ALTER TABLE GN_DW.SILVER.CRM_MEMBER RENAME COLUMN JOIN_DT TO FRST_REGIST_DT;` 실행 및 COMMENT 정비.
   - `04_silver_design/08_SILVER_테이블DDL_20260714.sql`, `models/silver/crm/CRM_MEMBER.sql`, `models/gold/dim/DIM_MEMBER.sql` 전수 수정.
   - `20_issue/32_컬럼개명표.md` 13번째 개명 완료 반영 (SILVER 13건 100% 완료).
2. **[착수표 ⑫ 완결] 활동 스냅샷 as-of 배선 및 CONF-3 종결**:
   - `16_파이프라인 배선 수정.md` §1-5 및 문서20 §N-11 회신 확정에 따라 `CONF-3` 「재후원 우세 (후원사업 유효 기준)」 채택.
   - `CRM_MEMBER_SPONSOR_SPAN` 기반 `FACT_MEMBER_MONTHLY`, `FACT_MEMBER_SPONSOR_BIZ` as-of 산식 정합성 검증 완료.
   - `DEC-47` 설계 의사결정 종결 및 착수표 ⑫ 완료 처리.
3. **[착수표 ⑭ 및 BLOCKING-5 점검]**:
   - FME STOP 이벤트 1.56배 팬아웃 방지 0 센티넬 유지 조건 확인 및 모델 무결성 유지.
   - `08_SILVER_테이블DDL_20260714.sql` 내 `BIGQUERY_EVENT`(44열), `BIGQUERY_IDENTITY`(12열) 정본 DDL을 Live DB 및 dbt 모델과 100% 일치하도록 동기화.
   - `table_ddl_column_gate.py` 실행 결과 GOLD 37 + SILVER 42 = **총 79개 테이블 100% 집합 일치(blocking 0건)** 달성.
   - `30_output_share/erd/` 38종 재발행 및 `test_generators.py`(21/21), `test_pipeline_erd.py`(24/24), 음성 테스트 29종 전건 PASS.

### ▣ OOOO2 🔴 다음 세션 열린 작업 (파이프라인 프로세스 / 중요도 순)

- **[P1/Serving] ②** 🔴🔴 NL 자연어 질의 라우팅 스모크 테스트 (CoWork UI 브라우저 수동 확인)
- **[P2/Silver] O59-P-1** 🟠 `FACT_SERVICE_EVENT.SEND_STATUS2` 처분 현업 회신 대기 (문서20 §M-6)
- **[P2/Docs] ④/⑪/⑱** 🟠 문서50 B1 정의 확정 및 이전 세션 독해 검증 잔여
- **[P3/Silver] BLOCKING-1** 🟡 회원 마스터 원천 전량 입고 후 `severity: warn ➔ error` 승격
- **[P3/Silver] BLOCKING-2** 🟡 CRM/ERP 원천 결손(`CRM_BIZ_TARGET` E-6, 모금비용 E-1) 입고 대기

---
_Co-authored with CoCo_

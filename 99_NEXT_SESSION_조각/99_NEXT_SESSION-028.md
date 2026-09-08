<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 028/030 | 허브 = 99_NEXT_SESSION.md | 원문 4102~4246행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
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

## 0-OOOO. ~~🔴🔴 [2026-09-07 O141 필독 — **여기서 시작한다.** §0-NNNN 은 승계됐다]~~ ➔ 🟢 [2026-09-07 O142 승계됨]

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

## 0-PPPP. ~~🔴🔴 [2026-09-07 O142 필독 — **여기서 시작한다.** §0-OOOO 은 승계됐다]~~ ➔ 🟢 [2026-09-08 O143 승계됨]

> 🟢 **절차 불변** = `export SESSION_LABEL=O1NN` → 원장 §1 선점(`R1-4-3`) →
> `gate_census.py --run-tests`(🔴 rc 는 리다이렉트로) → `session_brief.py --write` → `00_BRIEF.md` 1회 `read`.
> 🔴 **이 절은 좌표만 운반한다** — 정본 = 이력 **§O142** · 설계 정본 = 문서30 **§37(DEC-51)** · `32_컬럼개명표.md`.

### ▣ PPPP1 🟢 이번 세션 완결 작업 (O142)

1. **[거버넌스 및 대행사 전환 지표 명칭 통일] DEC-51 완결**:
   - `FACT_AD_PERFORMANCE` 및 하류 뷰/SV에서 과거 GA 명칭으로 노출되던 대행사 실적 전환 지표를 `AGENCY_CONV_MEMBERS`(명) 및 `AGENCY_CONV_CNT`(건/VU)로 전면 일관화 확정 (`30_설계` DEC-51, `32_컬럼개명표` §8-D).
   - dbt 모델 4종(`FACT_AD_PERFORMANCE`, `WIDE_AD_PERFORMANCE`, `WIDE_AD_DIGITAL`, `WIDE_AD_COMBINED`) 및 `_wide_schema.yml` 전수 갱신.
2. **[Snowflake Live DB 배포 및 반영]**:
   - `ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE RENAME COLUMN` 2건 및 COMMENT 4건 실행 완료.
   - `WIDE_AD_PERFORMANCE`, `WIDE_AD_DIGITAL`, `WIDE_AD_COMBINED` 뷰 3종 재생성 및 Semantic View `SV_AD` 재배포 완료.
3. **[DDL 정본 및 산출물/ERD 전수 재발행]**:
   - `06_DDL.sql`, `10_WIDE VIEW 코멘트.sql`, `05_필드 인벤토리.md`, `04_SV파생 매핑.md`, `02_지표 분류.md` 갱신.
   - `30_output_share/` 산출물 전수 갱신, `table_ddl_column_gate`(79/79 PASS), `test_generators.py`(21/21 PASS).
   - 임시 폴더 `/07_bigquery 명칭 변경/` 삭제 완료.

### ▣ PPPP2 🔴 다음 세션 열린 작업 (파이프라인 프로세스 / 중요도 순)

- **[P1/Serving] ②** 🔴🔴 NL 자연어 질의 라우팅 스모크 테스트 (CoWork UI 브라우저 수동 확인)
- **[P2/Silver] O59-P-1** 🟠 `FACT_SERVICE_EVENT.SEND_STATUS2` 처분 현업 회신 대기 (문서20 §M-6)
- **[P2/Docs] ④/⑪/⑱** 🟠 문서50 B1 정의 확정 및 이전 세션 독해 검증 잔여
- **[P3/Silver] BLOCKING-1** 🟡 회원 마스터 원천 전량 입고 후 `severity: warn ➔ error` 승격
- **[P3/Silver] BLOCKING-2** 🟡 CRM/ERP 원천 결손(`CRM_BIZ_TARGET` E-6, 모금비용 E-1) 입고 대기

---

## 0-QQQQ. ~~🔴🔴 [2026-09-08 O143 필독 — **여기서 시작한다.** §0-PPPP 는 승계됐다]~~ ➔ 🟢 [2026-09-08 O144 승계됨]

> 🟢 **절차 불변** = `export SESSION_LABEL=O1NN` → 원장 §1 선점(`R1-4-3`) →
> `session_brief.py --write` → `00_BRIEF.md` 1회 `read`(🔴 rc 는 리다이렉트로).
> 🔴 **이 절은 좌표만 운반한다** — 정본 = 이력 **§O143** · 점검 원장 = `07_O작업정리/00_O작업_점검_계획서.md`.

### ▣ QQQQ1 🔴🔴 먼저 알아라 — 브리핑이 **틀린 인수인계 절을 뽑고 있었다**(O143 시정)

O143 착수 시 `00_BRIEF` §2 의 「현행 시작점」이 **`§0-NNNN`(O140 · 이미 승계됨)** 으로 나왔다.
원인이 **둘**이고 둘 다 고쳤다(정본 = 이력 §O143 · 코드 주석 = `session_brief.py`):
① 취소선 관례가 O129 부터 **대괄호 전체를 감싸는 형태**로 바뀌어 리터럴 인접 판정이 실패했다.
② O140·O141·O142 **날짜가 모두 같아서** `max` 동점 규칙이 **가장 오래된 절**을 골랐다.
🔴 **실해** = 브리핑이 O140 의 열린 목록을 실어 **O141 이 이미 닫은 `㊵`·`⑫` 가 열림으로 보였다.**
⇒ 🟢 이제 `struck_out()`(구간 포함 판정) + 정렬 키 `(date, idx)` 로 **문서 순서상 마지막**을 고른다.
🔴 **다음 세션은 브리핑 §2 를 그대로 믿어도 되지만, 새 절을 쓸 때 반드시 `~~취소선~~` 을 붙여라.**

### ▣ QQQQ2 🔴🔴 착수표 `②` 는 **사람 소관이 아니라 배포 미완**이다 (D9)

라이브 실측(2026-09-08) = `SHOW AGENTS` **0행** · `SHOW SEMANTIC VIEWS` **1종(`SV_AD`)뿐** ·
`SHOW SCHEMAS` **전 스키마 created_on = 2026-09-07 00:23~00:25**(계정 재구축).
DW 본체는 정상(GOLD 37+14 · SILVER 43 · ML 16 · OPS 4).
⇒ 🔴 **`②` 를 사람에게 넘겨도 UI 에 Agent 가 없어 아무것도 못 한다.**
🔴 **O134 「`VERSION$3` 11도구 일치」·O136 「28/28 PASS」를 라이브 근거로 인용하지 마라**(`R2-8-4-d`).
🟢 절차·선행조건·판정 5축 = `07_O작업정리/01_NL스모크_절차서.md`(**Q5 = 과잉 차단 오탐 가드**).

### ▣ QQQQ3 🟢 이번 세션 완결 작업 (O143)

1. **[브리핑 신뢰성 복구]** `session_brief.py` 승계 판정·동점 판정 2건 시정 ·
   음성 테스트 축 신설(**수정 전 코드에서 9건 실패** 실증 후 전건 통과).
2. **[측정축 고정]** `doc_census`·`doc_type_gate` 의 바이트 실측을 `os.path.getsize`(stat) →
   **읽은 바이트**로 교체. 착수 시 stale 1건은 **블록 반올림 오탐**이었다(기재 14,891 이 맞다).
3. **[등록부 결합 게이트화]** `handoff_gap` 신설 — 착수표 열림이 인수인계 절에 없으면
   `00_BRIEF` §2 에 좌표와 함께 경고. 실측 검출 = **`⑭`·`㊳` 2건**.
4. **[조문 신설]** 지침 **`R0-8`**(무성 0건 = `rc` 로 검증) + **`R3-9 ㉨`**(두 등록부 열린 집합 대조) ·
   스킬 `Step 0`·자문 ⑨ 반영. 조문 96 → **100** · 역전 0 · 중복 0.
5. **[⑭ 라이브 실증 + DDL 보강]** STOP 1,038,262행 **전건 SK=0**(가드 유지) ·
   `06_DDL.sql` FME 이력에 `· SPONSORSHIP_SK` 신설(DEV 한정 배선 · STOP 센티넬 사유 · ⑭ 정지점).

### ▣ QQQQ4 🔴 다음 세션 열린 작업 (중요도 순)

- **[P1/Serving] 후-1** 🔴🔴 **SV·Agent 재배포** — `②` 의 실제 선행조건(D9). `ADD VERSION FROM` 경로 준수(착수표 `⑳`)
- **[P1/Serving] ②** 🔴🔴 NL 스모크 — **후-1 이후에만** 착수 가능. 절차서 = `07_O작업정리/01_NL스모크_절차서.md`
- **[P1/Gold] ⑭** 🔴🔴 FME STOP 팬아웃 귀속 규칙 — 🔴 현업 결정 전 **배선 금지** · 가드(0 센티넬) 유지 확인됨
- **[P2/Docs] ㊳** 🟠 `_o125e_entry.md` 낡은 마운트 엔트리 — 🔴 `rm` 시도 금지(스테이지에 실체 없음)
- **[P2/Silver] O59-P-1** 🟠 `FACT_SERVICE_EVENT.SEND_STATUS2` 처분 현업 회신 대기 (문서20 §M-6)
- **[P2/Docs] ④/⑪/⑱** 🟠 문서50 B1 정의 확정 및 이전 세션 독해 검증 잔여
- **[P2/Docs] 후-2** 🟠 문서50 열린 절 18건 절별 재판정(O143 은 목록·좌표만 확보)
- **[P3/Tools] 후-3** 🟠 파이프 한 글자만 남은 줄을 잡는 표 결손 축 신설(D3 게이트 맹점)
- **[P3/Docs] 후-4** 🟠 라이브 실재 주장 문안에 「조회 시점」 병기 소급 정비(`R2-8-4-a`)
- **[P3/Silver] BLOCKING-1** 🟡 회원 마스터 원천 전량 입고 후 `severity: warn ➔ error` 승격
- **[P3/Silver] BLOCKING-2** 🟡 CRM/ERP 원천 결손(`CRM_BIZ_TARGET` E-6, 모금비용 E-1) 입고 대기

---

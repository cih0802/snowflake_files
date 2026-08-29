<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 014/023 | 허브 = 99_NEXT_SESSION.md | 원문 2004~2132행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
## 0-EEE. 🔴🔴 [2026-08-20 O91-G 필독 — ~~여기서 시작한다~~ **⇒ [O92] 시작점은 위 §0-FFF 다.** `▣4` 종결 · `▣2` 수치 변경]

> 🟢 **O91 세션은 종료됐다.** GA4 파이프라인이 BRONZE→SILVER→GOLD 차원까지 살아났고, 자기검토(`§O91-F`)와
> 그 처방 집행(`§O91-G`)까지 닫혔다. **§0-DDD 는 「build 2차」 시점 기재라 아래 ▣1 이 최신이다.**
> 정본 = `50_dbt_…-014` **§O91-F**(자기검토) · **§O91-G**(처방 집행) · `-015` **§O91-C·D·E** · `30 §26·§27`.

### ▣1 🟠 최우선 = ③ `dbt build` 재실행 — **stale 테스트 시정 후 미실행이다**

`EXECUTE DBT PROJECT FROM WORKSPACE "USER$"."PUBLIC"."snowflake_files" project_root='/10_dbt_pipeline' args='build --target dev'`

· 🔴 **`R4-1` 정지점** — 착수 전 사용자 승인을 받는다. O91 은 승인 범위 밖이어서 실행하지 않았다.
· 🟢 **직전 실행 결과**(`QUERY_ID 01c681ed-…-f6612` · 415초 · 계정 `NX55103`) =
  `PASS=385 WARN=33 ERROR=1 SKIP=19 TOTAL=438` · 모델 **86 성공**.
· 🟢 **그 `ERROR=1` 은 시정 완료다** — `_silver_bridge_schema.yml` `accepted_values` 에 `'NOT_A_MEMBER_ID'`
  추가(`parse` SUCCESS). ⇒ **다음 build 는 통과 예상이지만 실측 전에 단정하지 마라.**
· 🟠 **잔여 미도달 = 모델 3**(`DIM_MEMBER_IDENTITY` 0행 · `FACT_GA_BEHAVIOR` 0행 · `WIDE_GA_BEHAVIOR` 부재)
  **+ 테스트 16**. 🔴 `WIDE_GA_BEHAVIOR` 는 **SERVICE SV COMMENT 가 Agent 에게 안내하는 객체**인데
  라이브에 없다 ⇒ Agent 가 존재하지 않는 객체로 안내한다(답변 품질 누수 · 이 build 로 해소).
· 🔴 **통과 후 반드시 볼 것 3가지**:
  ㉠ `relationships GA4_IDENTITY.MBER_NO` — 직전 **153** ↔ 기지 **172**(범위가 달라 단순 비교 금지)
  ㉡ `warn_ga4_base_row_reconciliation` — `FOLDED` 값에서 **`DEC-40` 제외 111행이 「접힘」으로 오분류**된다
  ㉢ `FACT_BUDGET` **51,576**(대장 24.5K 대비 2배 · `PLAN_BUDGET_MONTH<>0` 1,112 = −85%) — **원인 미확정**
     ⇒ `COUNT(*)` vs `COUNT(DISTINCT <grain>)` 로 중복부터 가른다.
· 🔴 **판정식은 「WARN 총계」가 아니라 「항목 단위 대조」다** — 테스트가 추가되면 총계는 당연히 변한다
  (402→437→438 실측). 선례 = `-015` §O91-C ③.

### ▣2 🔴 WIDE 소비뷰 정보량 0 컬럼 제외 — **설계는 합의됐고 착수 승인만 남았다**

사용자 제안 원칙 = *"각 WIDE 별 grain 기준으로 채워넣을 수 있는 라벨은 다 넣고, grain 에 맞지 않은 컬럼은 제외"*.

🔴 **판정 기준은 NULL 개수가 아니라 `COUNT(DISTINCT) ≤ 1` 이다** — `WIDE_MEMBER_MONTHLY.SPONSORSHIP_NAME` 은
**100% 채워져 있는데 값이 `(미매핑)` 하나**다(정보량 0). NULL 로 세면 놓친다.

| WIDE | 삭제 후보 | 개수 |
|---|---|---:|
| `WIDE_MEMBER_MONTHLY` | `CAMPAIGN_*` 6 + `PAYMENT_*` 3 + `SPONSORSHIP_*` 5 | **14** |
| `WIDE_AD_PERFORMANCE` | `CAMPAIGN_*` 6 + `AD_CREATIVE` 계 7 | **13** |
| `WIDE_BUDGET` | `CAMPAIGN_*` 3 + `SPONSORSHIP_*` 2 + `ORG_*` 4 | **9** |
| `WIDE_EVENT_PARTICIPATION` | `CAMPAIGN_*` 3 + `SPONSORSHIP_*` 2 | **5** |
| `WIDE_SERVICE_EVENT` | `CAMPAIGN_*` 5 | **5** |
| `WIDE_AD_DIGITAL` · `WIDE_AD_BROADCAST` | 같은 축 확인(`D_CAMPAIGN` 1 · `D_CREATIVE` 0) · **컬럼 열거 미실시** | ~13×2 |

🔴🔴 **삭제 전에 원인을 분류하라 — 세 가지가 섞여 있다:**
· **grain 충돌**(삭제 타당) = `FMM.SPONSORSHIP`·`PAYMENT`·`CAMPAIGN` — 회원×월 1행인데 회원 9.9%가
  복수 후원사업(최대 13) ⇒ 대표 규칙 없이 구조적으로 불가.
· **원천 결손**(삭제 타당) = `FBD.ORG_*`(ERP 원장에 조직 귀속 없음 · 모델 주석 명시) · `FSE.CAMPAIGN_*`.
· **배선 미완**(🔴 **삭제 보류**) = `FEP.CAMPAIGN`·`SPONSORSHIP`(B3 조인경로 대기) · `FAD.CAMPAIGN`·`AD_CREATIVE`(**원인 미확인**).

🟢 **1차 권고 = 확정분 28개만 삭제**(`WIDE_MEMBER_MONTHLY` 14 · `WIDE_BUDGET` 9 · `WIDE_SERVICE_EVENT` 5).

🔴🔴 **[O91-H ① 실행 안전 — 이것을 먼저 읽어라] 접두·패턴으로 지우면 measure 가 파괴된다.**
`WIDE_MEMBER_MONTHLY` 의 `LIKE 'CAMPAIGN%'` 은 **7개**를 잡는데 7번째가 **`CAMPAIGN_UNPAID_CNT`**
(`ORDINAL_POSITION 21` · `NUMBER`) = **FMM 의 measure** 다. 라벨이 아니라 사실이므로 지우면 안 된다.
🟢 **안전한 특정 = `ORDINAL_POSITION` 연속 블록** — 라벨 14개는 **66~79 연속**이다
(66~71 `CAMPAIGN_*` 6 · 72~76 `SPONSORSHIP_*` 5 · 77~79 `PAYMENT_*` 3).
🟢 연속 블록이라 **SELECT 꼬리 절단**이고 `_wide_schema.yml` `columns[]` 중간 재배열이 없다.
🔴 **다른 뷰도 삭제 전에 ordinal 을 다시 재라** — 접두 일치만 믿지 마라. 정본 = `-014` §O91-H ①.

🟠 **착수 분할 선택지(사용자 결정 대기)** — `▣4` `O8` 결정을 기다리지 않고 진행하려면:
· **1-A 차 = `WIDE_BUDGET` 9 + `WIDE_SERVICE_EVENT` 5 = 14개** ⇒ `O8` 과 **무관**하므로 지금 가능.
· **1-B 차 = `WIDE_MEMBER_MONTHLY` 14개** ⇒ 🔴 `O8` 결정에 걸린다. 대표 규칙이 정해져
  `FMM.SPONSORSHIP_SK` 가 채워지면 **후원사업 5개는 삭제 대상이 아니라 살릴 컬럼**이 된다.
🟢 **SV 안전 확인 완료** — `05_1_SV_DDL_MEMBER_MONTHLY.sql` **0건** · `05_4_SV_DDL_SERVICE.sql` **0건** 참조 ⇒
두 뷰 삭제는 SV 를 깨지 않는다. `05_2`(7건)·`05_3`(5건)이 참조하는 컬럼은 전부 **유지 대상**이다.
🔴 **`_wide_schema.yml` `columns[]` 를 같은 커밋에서 고쳐라** — SELECT 순서 불일치는 **build ERROR** 다(O89 실증).
🔴 **삭제하는 뷰마다 대체 경로를 COMMENT 로 남겨라** — 안 남기면 「왜 없지?」가 반복된다:

| 삭제 라벨 | 대체 경로 | 채움률 |
|---|---|---|
| 후원사업 | `WIDE_MEMBER_FEE`(회비월 grain) | **99.82%** |
| 〃 | `FACT_MEMBER_COHORT.ACQ_SPONSORSHIP_SK`(회원 grain) | **100%** |
| 캠페인 | `WIDE_MEMBER_EVENT` | distinct **14,122** |
| 결제수단 | `WIDE_MEMBER_FEE.PAYMENT_SK` | **99.52%** |
| 조직 | `FACT_TARGET_DEV` 100% · `FACT_DEV_ACHIEVEMENT` 99.99% | |
| 광고 소재 · 발송 캠페인 | ❌ **대체 없음** | |

### ▣3 🔴 `DEC-40` 격리 테이블 — **결정 사안 · O91 자기검토가 지적한 최대 설계 결함**

`DEC-40`(GA4 `USER_PSEUDO_ID` 결측 111행 필터 제외)은 **행을 버리면서 감사 경로를 만들지 않았다.**
계보가 **코드 주석과 md 에만** 있어 **쿼리할 수 없다** ⇒ BRONZE↔SILVER 111행 괴리를 데이터로 재현할 방법이 없다.
🟢 정석 = **reject/quarantine 테이블**(`OPS.GA4_REJECT_LOG` 류)에 탈락 행 + 사유 코드를 적재.
🔴 **새 `DEC` 로 등재해야 하는 결정이다**(테이블 신설 + 모델 변경 + `DEC-40` 개정).
🟠 같은 축의 파생 = `warn_ga4_base_row_reconciliation` 이 「접힘」과 「의도적 제외」를 구분하지 못한다
(`FOLDED 623,660` = 접힘 **623,549** + `DEC-40` **111**) ⇒ 게이트 분자에서 제외분을 빼거나 별 컬럼으로 분리.

### ▣4 🟠 `O8` 다중후원 대표 규칙 — 업무 결정 대기 (`BLOCKING-5 B2`)

`FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` **전건 0** 의 원인이다. 회원 **9.9%**가 복수 후원사업(최대 13)이라
「월×회원 1행에 어느 사업을 대표로 내릴지」가 **모델링이 아니라 업무 판단**이다.
🟢 이것이 정해지면 ▣2 의 `FMM` 14개 삭제 판단이 바뀔 수 있다 ⇒ **▣2 착수 전에 이 결정을 먼저 물어라.**

### ▣5 🟢 O91 이 닫은 것 — **다시 손대지 마라**

· RBAC 3블로커 라이브 해소(GRANT 8문장 · FUTURE 4건 실측) · `07` A~D 4건 · `01_환경 Role.md` ㉠㉡㉢ 3건
· 라이브 프로시저 `[O89]` 라벨 도용 제거 · `DEC-39`(`30 §26`) · `DEC-40`(`30 §27`)
· GA4 필터 + 재발 감지 테스트(**음성 테스트 통과 확인** — 창 좁히면 3행 반환)
· `_silver_bridge_schema.yml` stale `accepted_values` 시정 · 재균형 3건 + 이력 등재
· 자기검토 `§O91-F`(확정위반 9 · 판정약점 4 · 아키텍처 결함 4) + `§O91-G` 처방 집행

### ▣6 🔴 O91 자기검토에서 배운 것 — **반복하지 말 것**

· 🔴🔴 **`R1-7-2` 해시 확인은 「배치로 첫 편집 전에」 한다** — O91 은 19건 중 **5건 누락**했고 원인은
  게으름이 아니라 **파일별 산발 확인**이었다. 🟢 O91-G 는 3대상을 1회 배치로 선확인해 해소했다.
· 🔴🔴 **`R2-6` 코드 COMMENT 에 실측 수치를 넣지 마라** — O89 에 이어 O91 도 위반했다. 특히
  `warn_ga4_null_user_pseudo_id.sql` 은 *"수치를 하드코딩하지 않는다"* 고 쓰고 `111행`을 박았다(**자기모순**).
· 🔴 **`R1-3-7-b`/`R1-3-7-c` 는 3세션 연속 미이행이다** — 독해 직후 토큰 기록, 판정 전 근거 파일화.
  🟢 이 턴에서는 지켰다(지침 재독 2건 + `-014` 독해 토큰 기록).
· 🔴 **원장 조각 전량 독해** — O91 은 7개 중 2개만 읽고 착수했다(`R1-1` 위반).
· 🔴🔴 **자기검토의 판정도 실측 대상이다** — O91-F 의 `A2`(센티넬 불일치)는 **전제가 거짓**이었고
  그대로 「시정」했다면 `P21` 라벨 창작 위반을 **만들었다**. ⇒ **처방 실행 전에 전제를 먼저 재라.**
· 🔴 **`R1-6-17`** — 범위 술어는 언제나 `macros/ga4_range_predicate.sql` 에서 읽는다(추측 재작성 금지).
  실제 범위 = **3개 6월 구간**(2024-06 · 2025-06 · 2026-06) · `dbt_project.yml:46~49`.
· 🟠 **환경 지뢰** — 로컬 `dbt --project-dir` 는 스테이지 경로 로깅이 `OSError: [Errno 95]` 로 죽는다.
  ⇒ 컴파일 검증은 **`EXECUTE DBT PROJECT … args='compile …'`** 로만 가능하다.
· 🟠 **`90_해소완료_로그` 분할 금지** — `retire_rows.py` 가 `--to` 경로에 직접 쓴다(`write_text(dst, …)`).
  분할하면 그 경로가 **허브**가 되고 허브에 쓴 내용은 재발행 때 **조용히 사라진다** ⇒ **스크립트 선수정 필요.**
  현재 꼬리 여유 **3,047B**(`doc_type_gate` 경고 1건).

### ▣7 🔴 세션 시작에 라이브를 다시 재라 (`P33`)

`SELECT COUNT(*), COUNT(DISTINCT SRC_TABLE) FROM GN_DW.BRONZE_BIGQUERY.EVENTS;` — 기지 **32,718,672 / 106**
`SHOW GRANTS TO ROLE GN_DW_ENGINEER;` · **`SHOW FUTURE GRANTS IN SCHEMA GN_DW.SILVER;`**
🔴🔴 **두 축을 따로 보라** — `SHOW GRANTS TO ROLE` 은 **FUTURE grant 를 보여주지 않는다**(O91 에서 실제로 갈렸다).
🔴 grant 가 또 0 이면 스키마가 재생성된 것이다 — `ACCOUNT_USAGE.SCHEMATA` 의 `DELETED` 를 보고 `07 §D` 전량 재실행.
🔴 **`06_DDL` 재실행은 데이터를 전부 지운다**(35테이블 전건 `CREATE OR REPLACE`) — 「재생성은 안전하다」는
**grant 축 한정**이다. 축 없이 인용하지 마라(`§O91-F` A3).

---

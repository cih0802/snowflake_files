<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 005/023 | 허브 = 99_NEXT_SESSION.md | 원문 718~903행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
### ▣ UUU8 🔴 O114-B 자기결함 — 다음 세션이 반복하지 않도록

㉠ 🔴🔴 **검토 범위를 스스로 좁혔고 그 사실을 먼저 말하지 않았다.** 사용자는 「추가되고 변경된
   데이터」 전체를 물었는데 나는 **O113 델타(ERP·CRM)만** 검토했다. 같은 적재에 들어온
   **`SILVER.BIGQUERY_REFINED_DATA` 285,387,172행 · `ML` 1,045,732행 · `AGENCY` 255,434행**
   축을 다루지 않았고, **그 중 GA4 축이 `severity` 기본값(error) 테스트를 3개 가지고 있다**
   ⇒ **build 차단 위험을 첫 보고에서 놓쳤다.** 🟢 뒤늦게 착수했으나 **컴퓨트 정지로 측정 불가**
   ⇒ `▣UUU3` 재측정 대기 ㉠~㉢ 으로 남겼다. 🔴 **범위를 좁힐 때는 좁힌 사실과 근거를 먼저 적어라.**
㉡ 🔴 **오류 메시지를 재조회 1회로 뒤집었다.** 컴퓨트 정지 오류 뒤 `COUNT(*)`·`CURRENT_TIMESTAMP()`
   가 성공하자 「일시적 오류」로 **판정하고 사용자에게 그렇게 말했다** — 두 쿼리는 **메타데이터만**
   읽으므로 컴퓨트를 증명하지 않는다. `SUM()` 으로 재확인해 **정지가 사실임을 확인하고 정정**했다.
   🔴 이것은 `▣TTT3`(「0건을 받으면 판정식을 먼저 의심하라」)의 **역방향 사례**다 —
   **성공 신호도 판정식을 의심해야 한다.** 🟢 처방 = 라이브 생사 판정은 **스캔 강제 쿼리**로 한다.
㉢ 🟠 **`R1-3-7-c` 를 어겼다** — 근거를 파일에 쓰기 **전에** 판정을 응답으로 냈다(순서 역전).
   근거 파일은 사후에 작성했다. 🟢 다행히 컴퓨트 정지 **전에** 기록해 두어 수치는 보전됐다 ⇒
   🔴 **그 조문의 값이 실증됐다**(정지 후에는 어떤 수치도 다시 얻을 수 없었다).

### ▣ UUU9 🔴🔴 [2026-08-29 O115 신설 · dbt 실행 전 필수] RBAC 누락 8건 — 이 계정에서 재실측했다

> 🔴 **문서50 §O90 은 「O91 에서 전건 해소」라고 병기돼 있으나 그것은 2026-08-20 · 다른 계정 판정이다.**
> `R3-9 ㉤`(라이브 실재 주장은 닫기 직전 재조회) 에 따라 **이 계정에서 다시 쟀고 누락이 나왔다.**
> 실측 = `SHOW GRANTS TO ROLE GN_DW_ENGINEER` **422행**(부여 시각 2026-08-29 00:20~00:22).
> 🟢 **O90 의 종전 블로커 3건(㉠ audit 스키마 · ㉡ SILVER grant · ㉢ OPS USAGE)은 이 계정에서 해소돼 있다.**
> 🔴 **그러나 그 부여 루프가 8건을 건너뛰었다.**

**🔴 A. `SELECT` 누락 5건 — 전부 `dbt build` 를 실패시킨다**

| 대상 | 왜 실패하는가 |
|---|---|
| `GOLD.DIM_GA_EVENT` | 🔴 dbt 가 **`merge into GN_DW.GOLD.DIM_GA_EVENT`** 를 낸다(`logs/dbt.log:8479` 실물) — Snowflake `MERGE` 는 대상에 **`SELECT` + DML 둘 다** 필요하다. 현재 `INSERT`·`UPDATE`·`DELETE`·`TRUNCATE` 만 있고 **`SELECT` 가 없다** |
| `GOLD.DIM_GA_SOURCE` | 🔴 같은 축(`logs/dbt.log:7136` `merge into … DIM_GA_SOURCE`) |
| `SILVER.AGENCY_AD_DIGITAL` | 🔴 하류 `FACT_AD_DIGITAL` 이 `ref()` 로 읽는다 + `_silver_bridge_schema.yml` `unique`·`relationships` 테스트가 읽는다 |
| `SILVER.AGENCY_AD_BROADCAST` | 🔴 같은 축(`FACT_AD_BROADCAST` + `unique`) |
| `SILVER.AGENCY_AD_BROADCAST_CASE` | 🔴 같은 축(`FACT_AD_BROADCAST_CASE` + `relationships` + 복합키 `unique`) |

🟢 **판정 근거 = 이 5건만 빠져 있다.** GOLD 다른 **35**(37−2) · SILVER 다른 **40**(43−3) 은
`SELECT` 를 전부 보유한다 ⇒ **설계 의도가 아니라 부여 루프의 누락**이다
(의도된 제외라면 다른 것도 빠져 있어야 한다).
🔴 **[O115 자기시정] 초판은 SILVER 를 「38」로 적었다 — 43−3=40 이므로 산술 오류였다.**
⇒ 🟢 **수를 적을 때는 뺄셈을 문서에 함께 적어라**(`37−2` · `43−3`) — 그러면 다음 독자가 검산한다.

**🟢 A-1. 🔴🔴 이 판정을 실측으로 확증했다 — 그리고 그 과정에서 판정식이 두 번 틀렸다**

🔴 **최종 결론은 초판과 같다**(5건 누락 = 차단). 🔴 **그러나 중간 검증 2회가 무효였다** ⇒
같은 함정을 다음 세션이 반복하지 않도록 **판정식 자체를 기록한다.**

| 시도 | 무엇을 했나 | 왜 무효였나 |
|---|---|---|
| 1차 ✗ | `USE ROLE GN_DW_ENGINEER` → `SELECT COUNT(*) FROM DIM_GA_EVENT` → **성공** | 🔴 **`COUNT(*)` 는 `SELECT` 권한 없이도 통과한다**(메타데이터 경로) ⇒ 「성공」이 권한을 증명하지 않는다. **`▣UUU8 ㉡` 이 경고한 바로 그 함정을 반복했다** |
| 2차 ✗ | 실컬럼 `MAX(GA_EVENT_SK)` 로 재시도 → **성공** | 🔴 **`CURRENT_SECONDARY_ROLES()` 에 `ACCOUNTADMIN` 이 `ALL` 로 활성**이었다 ⇒ 주 롤을 바꿔도 **이차 롤이 권한을 공급**한다. 「롤을 바꿨다」가 「그 롤로만 접근했다」를 뜻하지 않는다 |
| 3차 ✓ | **한 호출에** `USE ROLE …; USE SECONDARY ROLES NONE; SELECT MAX(<실컬럼>) …` | 🟢 `Insufficient privileges … must have SELECT granted on TABLE GN_DW.GOLD.DIM_GA_EVENT` ⇒ **차단 확증** |

🟢 **양성 대조도 함께 했다**(판정식의 변별력 증명) — `SELECT` 를 **보유한** `AGENCY_AD_ROW_DGT` 는
같은 조건에서 **권한 오류가 나지 않고** 「웨어하우스 미선택」에서 멈췄다
⇒ 🔴 **음성만 보면 「무엇이든 실패한다」와 구별되지 않는다.** 양성 대조가 그것을 가른다.

🔴🔴 **다음 세션을 위한 권한 검증 판정식**(이 3가지를 모두 지켜야 유효하다):
· ㉠ **`COUNT(*)` 금지** — 실컬럼 집계를 쓴다(`MAX(<컬럼>)`).
· ㉡ **`USE SECONDARY ROLES NONE` 필수** — 안 끄면 `ACCOUNTADMIN` 이 몰래 통과시킨다.
· ㉢ **`USE ROLE` 과 검증 쿼리를 한 호출에** 둔다 — 이 환경은 호출 간 롤 상태가 **불안정**하다
  (실측: `USE ROLE` 뒤 다음 호출에서 `CURRENT_ROLE()` 이 `ACCOUNTADMIN` 으로 되돌아간 사례 1회).
· 🔴 **끝나면 `USE ROLE ACCOUNTADMIN; USE SECONDARY ROLES ALL; USE WAREHOUSE …` 로 복구**한다.

**🟢 A-2. [2026-08-29 O115 집행 완료] 승인받아 부여했다 — 차단 해소**

🟢 부여 = 위 5건 `SELECT`(`GN_DW_ADMIN` 이 grantor · 다른 grant 와 일관) +
**재발 방지** `SELECT ON FUTURE TABLES IN SCHEMA GN_DW.SILVER`·`GN_DW.GOLD` +
`SELECT ON ALL TABLES` 2건(현존분 일괄).
🟢 **검증 2축** = ㉠ 기계 대조(`SHOW GRANTS` → `RESULT_SCAN` ↔ `INFORMATION_SCHEMA.TABLES`
`NOT EXISTS`) **누락 0건** ㉡ 위 3차 판정식으로 `GN_DW_ENGINEER` 단독 읽기 **성공**.
🔴 **그래도 이 절을 지우지 않는다** — 계정이 바뀌면 같은 누락이 재발하고(`R2-8-4-d`)
위 판정식이 그때 필요하다.

**🟠 B. 스키마 `USAGE` 누락 3건 — 그중 dbt 에 걸리는 것은 0건**

| 스키마 | dbt 영향 |
|---|---|
| `ML` | 🟢 **무영향** — dbt 프로젝트 전체 grep 에서 `ML_RST_DATA`·`GN_DW.ML` **0건**(`_sources.yml` sources 4종에도 없다) ⇒ dbt 는 `ML` 을 읽지 않는다 |
| `SERVING` | 🟢 dbt 무영향 · 🔴 **SV·Agent 배포 때 필요할 수 있다**(별개 축으로 남긴다) |
| `SECURITY` | 🟢 dbt 무영향 |

🔴 **`ML` 은 「dbt 무영향」이지 「불필요」가 아니다** — SV·Agent 가 ML 예측을 노출하면 그때 필요해진다.

**🟢 처방 — `GN_DW_ADMIN`(또는 `ACCOUNTADMIN`)으로 실행한다**
🟢 **[O115 집행 완료 — 이 계정에서는 다시 실행하지 않아도 된다**(멱등이므로 재실행해도 무해하다).
아래는 **다른 계정·재구축 시 재사용**할 정본이다. 위 `A-2` 가 집행·검증 기록이다.**

```sql
GRANT SELECT ON TABLE GN_DW.GOLD.DIM_GA_EVENT              TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON TABLE GN_DW.GOLD.DIM_GA_SOURCE             TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON TABLE GN_DW.SILVER.AGENCY_AD_DIGITAL       TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON TABLE GN_DW.SILVER.AGENCY_AD_BROADCAST     TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON TABLE GN_DW.SILVER.AGENCY_AD_BROADCAST_CASE TO ROLE GN_DW_ENGINEER;
```

🔴 **재발 방지가 본체다** — `07_ENVIRONMENT_RBAC_setup.sql` 이 `ON ALL TABLES` 를 쓰는데
그것은 **시점 grant** 라 이후 생성·재생성된 테이블을 덮지 않는다(§O90 `C` 가 이미 지적했다).
⇒ 🟢 **`FUTURE TABLES` 를 함께 부여**하고 **부여 후 검증 쿼리로 0건을 확인**하라:

```sql
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.GOLD   TO ROLE GN_DW_ENGINEER;
```

🟢 **검증법**(O115 가 쓴 것) = `SHOW GRANTS TO ROLE GN_DW_ENGINEER` 후
`RESULT_SCAN` 을 `INFORMATION_SCHEMA.TABLES` 와 `NOT EXISTS` 로 대조해 **누락 0건**을 단정한다.
🔴 **`SHOW GRANTS` 를 눈으로 읽어 판정하지 마라** — 422행이고 O115 도 처음엔 눈으로 보고
「전건 부여됐다」로 읽었다(정밀 대조 쿼리를 돌려야 5건이 나왔다).

---

## ~~0-TTT~~. 🔴🔴 [2026-08-29 O113 — ~~**여기서 시작한다.**~~ **§0-UUU 로 승계됐다**]

> 🟢 **세션 시작 절차는 O106 그대로다** = `python3 scripts/session_brief.py --write` → `20_issue/00_BRIEF.md` 1회 `read`.
> 🔴 O113 은 `20_issue/` 가 아니라 **`50_handoff/` 인수인계 문서군**을 다뤘다. 착수표 15건은 **그대로 열려 있다**.

### ▣ TTT1 🔴🔴 먼저 알아라 — 이관 대상이 67 → 69 로 바뀌었고 한 테이블은 컬럼 순서가 밀렸다

> 정본 = `50_handoff/04_..BRONZE_DDL` 「변경 이력 2026-08-29」 · 재현 = `python3 scripts/handoff_ddl_gate.py`

| 무엇 | 값 | 왜 중요한가 |
|---|---|---|
| 브론즈 | 50 → **52** | `TM_CM_MKTNG_UTM`(CRM) · `EXPENSE_RESOLUTION`(ERP) 신설 |
| 이관 총계 | 67 → **69** | `50_handoff/01`~`07` **8문서 전수 봉합 완료** |
| 🔴🔴 `BDGT_ACMSLT_LEDGER` | 65 → **67** · **컬럼 순서 변경** | `BDGT_PRCD_NM` 이 **3번째로 삽입**됐다 ⇒ CSV 위치 기반 적재라 **08-29 이전 적재분은 값이 한 칸씩 밀려 있다 = 전량 재적재 대상** · 🟢 **[2026-08-29 O114 병기] 그 「08-29 이전 적재분」은 실재하지 않았다** — C 측 `COUNT(*)` = 0행이고 라이브 컬럼 순서는 CSV 헤더와 `MATCH` ⇒ **이 계정에서는 재적재 대상이 아니다**(`▣TTT4 ㉤`). 🔴 위 조문은 **다른 계정·다른 시점에는 여전히 유효**하므로 지우지 않는다 |
| 파일 포맷 | 3 → **4** | `BRONZE_ERP.GN_CSV_FORMAT_EUCKR2`(지출결의 CSV 는 헤더 1줄) |
| 🔴 구조 정본 | `02_1_A DB정보.sql` → **`99_provided_definition/11~13`** | `02_1` 은 08-12 측정본이라 낡았다(CRM 45 · 삭제 컬럼 잔존 1341행) |

🔴 **`02_1` 을 다시 최우선 정본으로 올리려면 02번 5·6단계를 A 에서 재실행해 갱신한 뒤에 하라.**
   갱신 없이 우선순위만 되돌리면 O113 갱신분이 **되돌려진다** — 04번 병합 규칙에 그 경고를 적어 두었다.

### ▣ TTT2 🟢 신설 도구 — DDL 을 C 에 만들기 전에 이걸 먼저 돌려라

```
python3 scripts/handoff_ddl_gate.py          # 7축 · FAIL 이면 C 에 DDL 만들지 마라
python3 scripts/test_handoff_ddl_gate.py     # 오염 기반 음성 테스트 12축
```

> 축1~6 = `50_handoff/04·05·06` ↔ `99_provided_definition/11·12·13·18·20` 대조
>   (테이블집합 · 컬럼순서 · 타입 · **DEFAULT** · **컬럼COMMENT** · **테이블COMMENT**)
> 축7 = `50_handoff/` 13문서에 **옛 수치·옛 파일번호가 현행값 없이 단독으로** 남아 있는가
> 관측 축 2종 = COMMENT 보강 969건(정상) · COMMENT 양쪽 부재 9건(🟠 경고)
> 🟢 현재 판정 = **판정 축 0건 · 경고 9건** ⇒ `🟠 PASS(경고)`

### ▣ TTT3 🔴 O113 이 배운 것 — 「0건」을 받을 때마다 판정식을 먼저 의심하라

이 세션에 같은 뿌리의 사고가 **네 번** 났고 네 번 다 「검사했는데 못 봤다」였다.

| # | 무엇을 놓쳤나 | 뿌리 |
|---|---|---|
| ① | 임시 도구가 **COMMENT·DEFAULT 를 아예 비교하지 않고** 「구조차이 0」 | 판정 축이 좁았다 |
| ② | `grep '67 테이블'` 이 「**67개** 테이블」을 놓쳤다 | 사람 grep 의 분모가 불안정하다 |
| ③ | `grep 'CRM 45'` 가 「**`BRONZE_CRM`(45)**」·「CRM **43**」을 놓쳤다 | 표기 변형을 세지 않았다 |
| ④ | bash `grep -in "procedure"` 가 **0건**을 냈다(실제 14건) | 🔴 **환경 지뢰** — 아래 참조 |

🔴🔴 **환경 지뢰(신규) — 이 워크스페이스의 bash `grep` 은 대용량 파일에서 조용히 0건을 낸다.**
   실측 = `99_provided_definition/20_ML_ddl.sql`(139 KB)에 `grep -in "procedure"` → **0건**,
   같은 파일에 `grep` **툴**로 같은 패턴 → **14건**. 종료코드도 0 이었다(오류가 아니다).
   ⇒ 🟢 **내용 검색은 `grep` 툴을 쓴다.** bash `grep` 은 줄 수·크기 확인 용도로만 쓴다
   (기존 `R1-3-4` 「bash 로 문서 읽기 금지」와 같은 축이고, **검색까지** 확장된다).

### ▣ TTT4 🟠 승계 미결 — O113 이 닫지 못한 것

| # | 무엇 | 막힌 이유 |
|---|---|---|
| ㉠ | `SILVER` 컬럼 COMMENT 공백 **9건**(전부 `STSLC_` 계열) | 🔴 문안 창작 금지 — 원천 소관자 확인 후 **`99_provided_definition/18`번을 먼저 고치고** 06번에 옮긴다(06번만 채우면 축5 가 「변형」으로 잡는다) · 🟠 **[2026-08-29 O114 병기] 라이브 3번째 축도 부재였다** — `GN_DW.SILVER.BIGQUERY_REFINED_DATA` 9컬럼 `COMMENT` 전부 `None` ⇒ 부재는 **원천·인수인계·라이브 3곳 전부**다. 🔴 **그래도 열려 있다** — 3곳 부재는 「빠진 것」과 「의미 미확정」을 구별해 주지 않으므로 소관자 확인이 여전히 선행이다 |
| ㉡ | `02_1_A DB정보.sql` 재추출 | A 계정 접근 필요 · 그때 04번 병합 규칙 우선순위를 **함께** 되돌린다 · 🟠 **[2026-08-29 O114 병기] 이 계정에서는 불가하다** — `SHOW DATABASES` 실측 7건에 **A 원천 DB 가 없다**(`GN_DW`·`SANDBOX`·`ADMIN`·`SNOWFLAKE*`·`USER$`). 🔴 「없다」가 아니라 **「이 계정에서 접근 불가」**다 ⇒ 재측정 대기(`R2-8-4-c`) |
| ㉢ | 신규 2테이블 **행수 실측 없음** | `01`번 6.2 표가 공백 · 02번 5단계 재실행 필요 · 🟠 **[2026-08-29 O114 병기] C 측에서도 아직 못 잰다** — `GN_DW` 전 스키마 **총 0행**(`BRONZE_CRM` 0/46 · `BRONZE_ERP` 0/2 · `BRONZE_AGENCY` 0/4 · `ML` 0/16 · `SILVER` 0/43) ⇒ **적재 후에만 판정 가능**하다. 🔴 이 「0」은 「대상 아님」이 아니라 **「적재 전」**이다 |
| ㉣ | 신규 CRM 컬럼 3종(`CMMN_BRND`·`MKTG_UTM`·`TM_CM_MKTNG_UTM` 전체) 한글 COMMENT | 컬럼정의서 CSV 미수록 ⇒ **명명 규칙으로 부여**했다 · 현업 확인 대상 · 🟠 **[2026-08-29 O114 병기] 사람 소관이라 이 세션이 닫을 수 없다** — 확정 문안을 받기 전에는 04번을 고치지 않는다(고치면 창작이 정본이 된다) |
| ~~㉤~~ | ~~`BDGT_ACMSLT_LEDGER` 재적재~~ → 🟢 **[2026-08-29 O114 실측 판정 · 재적재 불필요]** | 🟢 **오염 없음이 확정됐다.** 근거 3축 = ㉠ 라이브 컬럼 **67개** · `BDGT_PRCD_NM` **3번째 실재** · `MNYRS_COST_DIV_YN` **부재** ㉡ 직접 `COUNT(*)` = **0행**(메타 `ROW_COUNT` 도 0 · `BYTES` 0) ㉢ 07번 A.1 (4) CSV 헤더 대조 = **67/67 `MATCH`**(이름·순서 동일). 🔴 **`TRUNCATE` 를 실행하지 마라 — 대상 행이 0이라 효과가 없고 오해만 남는다.** 🟢 남은 일은 「재적재」가 아니라 **최초 적재**(07번 A.4)다 |
| ㉥ | 스테이지 `BRONZE_CRM`·`SILVER` 완료 판정 | 측정 시점에 **업로드 진행 중**이라 보류(`R2-8-4-c`) ⇒ 적재 착수 직전 다시 `LIST` · 🟢 **[2026-08-29 O114 재실측 · `BRONZE_CRM` 만 닫혔다]** `BRONZE_CRM/` = 46 디렉터리 / 280 파일 / 3,101.4 MB · 최종 수정 04:44:23 UTC 로 **약 47분 무변화** + 스테이지 46 = DDL 46 **집합 일치** ⇒ 🟢 **업로드 완료**. 🔴 **`SILVER/` 은 아직 진행 중이다** — 05:30:02 UTC 1,623파일/25,973.4MB → 05:31:28 UTC **1,687파일/26,984.9MB**(105초에 +64파일 · +1,011.5MB). ⚠️ O113 의 「SILVER 0건」은 **「대상 아님」이 아니라 「아직 오지 않았다」**였음이 실물로 확인됐다(`▣TTT3` 의 실증 사례가 하나 늘었다) ⇒ **A.5 는 업로드 종료 후에 실행한다** |

### ▣ TTT5 🔴 O113 자기결함 5 — 다음 세션이 같은 걸 반복하지 않도록

㉠ 축 2개를 못 보는 도구로 판정하고 **완료 보고했다**.
㉡ 문서가 선언한 **최우선 정본을 열지 않고** 다른 파일을 따랐다(결과는 옳았지만 근거가 없었다).
㉢ **`R3-9 ㉥` 전수 검색 미이행** — 3문서만 고치고 끝냈고, 사용자가 「비판적으로 검토」를
   지시한 뒤에야 나머지 5문서의 stale 을 찾았다. 🔴 **내가 스스로 닫지 못했다.**
㉣ 게이트 초판이 COMMENT 정책을 **스키마 단위 제외**로 구현해 오탐 5건(근거는 컬럼 단위였다).
㉤ **라벨 선점을 착수 전에 하지 않았다**(`R1-4-3` · O110~O112 3세션 연속 이행을 끊었다).

🟢 **다음 세션이 먼저 할 것** = ㉠ 브리핑 → ㉡ **라벨 선점 등재** → ㉢ 착수표 15건 중 🔴🔴 2건
(`㉒ AGENT_MEMBER 버전업` · `⑫ 활동 스냅샷 as-of 배선`) 확인 → ㉣ 그 다음에 위 TTT4 승계분.

---

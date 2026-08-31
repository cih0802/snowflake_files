# O123-C 등재 근거철 (판정 전 기록 · `R1-3-7-c`)

> 🔴 이 파일은 **판정보다 먼저** 쓴 근거철이다. 원문 구절 + 좌표를 그대로 담는다(요약 금지).
> 목적 = O123-C 정본 등재의 각 문장이 **파일·산출물 실측**에 걸려 있음을 다음 세션이 재현할 수 있게 한다.
> 🔴 **인수인계 프롬프트의 서술은 근거가 아니다** — 아래는 전부 이 세션(O123-D)이 파일에서 다시 잰 것이다.

## E0. 착수 게이트 (프롬프트가 요구한 것 · 리다이렉트로 rc 수신)

- `python3 scripts/gate_census.py >/tmp/g1.out 2>&1` → **rc=0**
- `python3 scripts/gate_census.py --run-tests >/tmp/g2.out 2>&1` → **rc=0**
- `/tmp/g2.out` 발췌 = `🟢 대상 전건 rc=0` (TEST **22종**) ·
  `🟢 규약 준수 — 사용법은 전건 rc=2` (`line_len`·`o54_sv_value_gate`·`ws_stage_verify`)
- `/tmp/g1.out` 말미 = `🟢 PASS — 미분류 0 · 유령 0 · 중복 0`

## E1. O123-C 는 정본 미등재였다 (등재 착수의 전제)

- `grep -rl "O123-C" 20_issue/ 99_NEXT_SESSION_조각/` → 출력 0행 · **rc=1**(= 매칭 파일 0개).
- ⇒ 원장 §1 · 이력 · 인수인계 어디에도 O123-C 가 없었다. 프롬프트의 진단은 **재현됐다**.

## E2. 30_output_share 최신화 — 아카이브·재생성 실측

- `30_output_share/_archive/20260830/` 실재 · 항목 **23개**.
- 루트 ↔ 아카이브 SHA256(선두 16자) 대조 결과 = **변경 17 · 동일 5 · 루트부재 1**.
- **변경 17종**(= 재생성분) · 루트 mtime 전부 **2026-08-30**:
  · `03_GN_DW_개념도.html` 13:43
  · `04_컬럼계보매핑.{csv,md,xlsx}` 13:39
  · `05_지표GOLD매핑.{csv,md,xlsx}` 13:40
  · `06_BRONZE노출감사.{csv,md,xlsx}` 13:40
  · `07_코드체계_관문측정.md` 13:42
  · `08_SILVER→GOLD_보존율.{csv,md}` 13:42
  · `09_보고서필드_조립가능성.{csv,md}` 13:42
  · `09_섹션배너.json` 13:42
  · `20260826_아키텍처 지도 요약본.html` 14:16
- 🔴 **파일명 정정** = 프롬프트는 `20260826_아키텍처 지도.html` 이라 적었으나
  실제 파일명은 **`20260826_아키텍처 지도 요약본.html`**(「 요약본」 포함)이다.
- **동일 5종**(= 미생산 5종 · 해시 불변) = `01_DW_현업활용가이드.md` · `10_원천입고_결손요약.md` ·
  `12_미해결이슈_현업확인_쿼리_O102.sql` · `13_미해결이슈_현업확인_쿼리_BRONZE_O102.sql` ·
  `미해결이슈_요약_O102.md` — 루트 mtime 전건 **08-30 08:50**(재생성되지 않았다).
- **루트부재 1** = `_o122_alias_census.csv` ⇒ 아카이브로 **이동**됐다(루트 목록에 없다).
- 루트 목록에 `_probe.bin`·`_probe.txt` **부재** ⇒ 삭제 실증.

## E3. 「복사 후 제자리 덮어쓰기」를 택한 이유 (산출물 rm 0건)

- `scripts/gen_silver_gold_retention.py:28`
  = `PREV = os.environ.get("GN_DW_PREV", os.path.join(WS, "30_output_share"))`
- 같은 파일 `:89` = `ppath = os.path.join(PREV, BASENAME + ".csv")`
- ⇒ 08 생성기는 **이전 판본 CSV 를 델타 입력으로 읽는다**. 원본을 먼저 지우면
  08 의 「변동(2026-08-30)」 열이 근거를 잃는다. 이것이 승인 방식의 기술적 근거다.

## E4. 🔴🔴 gate_census 오분류 2건 시정 — 현재 분류 실측

- `/tmp/g1.out` 섹션 헤더 = `[JUDGE] 24개`(6행) · `[OBSERVE] 6개`(32) · `[NEEDS_ARGS] 3개`(41) ·
  `[GEN] 12개`(47) · `[MUTATES] 24개`(61) · `[LIB] 12개`(88) · `[TEST] 22개`(102).
- **`[GEN]` 안에 두 도구가 있다**(= MUTATES 에서 이동 완료):
  · `:52` = `gen_column_mapping   컬럼계보매핑 04 — 🔴 라이브 접속 0(모델 파싱 전용)`
  · `:58` = `run_bronze_audit_host   BRONZE 노출감사 06 **정본 러너** — 조회 전용(무인자 = 직접조회)`
- **같은 유형의 O121-B 선행 시정 3건은 `[JUDGE]` 에 있다**(DDL 을 **읽는** 도구):
  · `:9` = `audit_ddl_rule7   DDL COMMENT 규칙7(실측 수치 금지) — DDL 파일을 **읽는다**`
  · `:28` = `sv_unit_gate   SV COMMENT 단위·수치 — 라이브를 **읽는다**`
  · `:29` = `table_ddl_column_gate   DDL 파일 ↔ 모델 컬럼 순서 — 라이브를 **읽는다**`
- ⇒ 「DDL 문자열을 **입력으로 읽는** 도구」를 「DDL 을 **발행하는** 도구」로 오분류하는 축이
  O121-B 3건 → O123-C 2건으로 **재발**했다는 서술은 실측에 부합한다.

## E5. gen_arch_map.py 계정 하드코딩 시정

- `scripts/gen_arch_map.py:29-31` 원문 =
  `🆕 [2026-08-30 O123-C] sfconn 경유로 시정 — 종전 판본은 계정·사용자·역할·웨어하우스를`
  `**하드코딩**했다(account="zl50263.ap-northeast-2.aws" · user="CHOIH" ·`
  `role="GN_DW_ADMIN" · warehouse="GN_DW_DEV_WH").`
- `:35` = `🟢 판정식 = **접속 정보는 도구마다 적지 말고 단일 경유점(scripts/sfconn.py)에서 받는다**`
- `:40-41` = `import sfconn` / `return sfconn.conn()`
- ⚠️ `:735` 의 `account=account,` 는 **접속이 아니다** — `write_html(path, account, …)` 가
  HTML `HEAD.format(...)` 에 넘기는 **표시용 인자**다(같은 파일 `:731` `def write_html`).
  ⇒ 「하드코딩 잔존」으로 오판하지 말 것.

## E6. 🔴🔴 `/tmp` 지뢰 — 「신규」가 아니라 「기존 항목의 결과·처방이 신규」다

- 🔴 **프롬프트 ④ 「환경 지뢰 신규」는 과대 주장이다.** `/tmp` 소실은 **이미 등재돼 있다**:
  `99_NEXT_SESSION_조각/99_NEXT_SESSION-024.md:56` 원문 =
  `- **작업 사본은 $HOME/work/** — /tmp 는 세션 중에도 초기화되고 /workspace 루트는 쓴 파일이 사라진다.`
- ⇒ 신규인 것은 **그 지뢰가 골든 발행에서 일으킨 결과**와 **체인 처방**이다.
- 🔴 **좌표도 stale 이다** — 프롬프트는 `-013 §7` 이라 적었으나
  `grep -rn "운영 환경 지뢰"` 실측 = **`99_NEXT_SESSION-024.md:4`** = `## 7. 운영 환경 지뢰`.
  `-013` 에는 그 문자열이 **0건**이다(재균형으로 이동했다).

## E7. 골든 재발행 — 지문·라벨·사유 실측

- `scripts/golden/outputs.json:862` = `"schema_fingerprint": "12ffa5c63c8ce470"`
- `:20` `reason` 원문(발췌) = `O123-C 후속: 스키마 지문 정정. 직전 발행에서 /tmp/schema.json 이`
  `세션 중간에 소실돼(생성 13:36 → 발행 14:18 부재) O111-B 가드가 구 지문 3581c638b4260bd9 을`
  `보전했다 — 지우지는 않았지만 산출물은 신 스키마 기준이라 골든 지문과 어긋난 상태였다.`
  `이번 발행은 dump_schema 를 같은 셸 호출 안에서 체인해 지문을 산출물과 일치시킨다.`
  `산출물 수치 변경 0(직전 발행과 동일).`
- **라벨** = `:13` `"label": "UNLABELED"` · `:19` `"label": "UNLABELED"` (2건) ·
  대조군 `:7` `"label": "O111-B"`.
- 🔴 **⑦ 의 처방이 실측으로 뒤집혔다 — 도구는 `--label` 을 이미 지원한다**:
  · `scripts/test_generators.py:746` = `def update_golden(reason=None, label=None):`
  · CLI = `ap.add_argument("--label", default=None, …)` 및 `update_golden(a.reason, a.label)`
  · `:776-778` = `🔴 [2026-08-29 O114-B] 라벨 해소를 재구현하지 않는다 — snapshot_util.resolve_label() 이` /
    `import snapshot_util as _snap`
  · `scripts/snapshot_util.py:67` = `def resolve_label(explicit=None, env=None):`
    `:68` = `스냅샷 라벨을 정한다 — 인자 → 환경변수 → UNLABELED.`
  ⇒ **시정 대상은 도구가 아니라 절차다.** `--label` 도 `SESSION_LABEL` 도 주지 않았기 때문에
  `UNLABELED` 이 됐다. 🔴 이는 `§0-AAAA` 49행의
  `export SESSION_LABEL=O1NN 을 착수 직후 먼저 하라(R1-7-10)` **미이행**이다.

## E8. 08 보존율 델타 — 덮기 전 소실 0 실증

정본 = `30_output_share/08_SILVER→GOLD_보존율.csv` ↔ `_archive/20260830/` 동명 파일.
컬럼 = `SILVER_TABLE` · `COLUMN` · `STATUS` · `판정군` · `소비GOLD모델` · `SILVER내부소비` ·
`SILVER내부_컬럼참조` · `채움(non-null)` · `비영(non-zero)` · `고유값(근사)` · `변동(2026-08-30)`.

| 축 | 이전 | 현행 |
|---|---:|---:|
| 행수 | 536 | **752**(순증 216) |
| 키 `(SILVER_TABLE, COLUMN)` 중복 | 0 | **0** |
| 사라진 키 | — | **0** |
| 신규 키 | — | **216** |
| SILVER 테이블 수 | 39 | **43** |
| `SILVER_ONLY_CHAIN` | 127 | **292** |
| `REFERENCED` | 238 | 291 |
| `DROPPED` | 143 | 141 |
| `NO_CONSUMER` | 28 | 28 |

- 신규 테이블 4종 = `BIGQUERY_REFINED_DATA` · `CRM_MEMBER_SPONSOR_SPAN` ·
  `ERP_BUDGET_YEARLY` · `GA4_BASIC`.
- 신규 키 216 중 **GA 축 169**(`BIGQUERY_REFINED_DATA` **118** + `GA4_BASIC` **46** + 그 외 5).
- `SILVER_ONLY_CHAIN` 증가 상위 = `BIGQUERY_REFINED_DATA` **+118** · `GA4_BASIC` **+46** ·
  `GA4_IDENTITY` **+1** ⇒ 증가 165 의 대부분이 GA 축이다.
  ⇒ O120 이 실증한 「GA 축이 GOLD 에서 끊긴다」와 **정합**한다.
- 🔴 **키 정의 함정(이 세션이 실제로 걸렸다)** — 키에 `STATUS` 를 넣어 3열로 잡으면
  **「사라진 키 10 · 신규 226」** 이 나온다. 그 10건은 소실이 아니라 **상태 전이**다
  (`REFERENCED` 238→291 · `DROPPED` 143→141 이 그 전이의 총량이다).
  🟢 **판정식 = 소실 판정의 키는 「식별자」로만 잡아라. 판정값(STATUS)을 키에 넣으면 전이가 소실로 보인다.**

## E9. 라이브 변경 0건 — 판정 범위 명시

- 🔴 **이 세션(O123-D)은 O123-C 의 라이브 DDL/DML 0건을 사후 재현할 수 없다**
  (`R2-8-4-c` · 과거 시점의 부작용 부재는 파일로 증명되지 않는다).
- 🟢 파일 축으로 확인 가능한 것만 적는다 = `_archive/20260830/` 이후 `10_dbt_pipeline/` 하위
  모델 변경 없음 · 개명 확정 12건의 `ALTER TABLE … RENAME COLUMN` 은 미실행
  (완료 판정식 = `INFORMATION_SCHEMA.COLUMNS` 구 컬럼명 0건 · `§0-AAAA` AAAA5).
- ⇒ 등재 문안은 「라이브 0건」을 **O123-C 의 자기신고로 표기**하고 단정하지 않는다.

## E10. 독해 기록 (`R1-3-7-b`)

| 파일 | offset/limit | 도착 | 그 구간 고유 토큰 |
|---|---|---|---|
| `00_guides/00_작업지침_세션운영규칙.md` | 1-316(전량) | O | `R0-7 워크스페이스 파서 제약` · `R2-7-3` · `R4-4-4` |
| `20_issue/00_BRIEF.md` | 1-137(전량) | O | `열린 착수표 13` · `2,240,704 자` · `doc_coord_gate 🟡` |
| `99_NEXT_SESSION_조각/99_NEXT_SESSION-024.md` | 1-95 | O | `## 7. 운영 환경 지뢰` · `P231` · `hashlib.md5 는 FIPS` |
| `99_NEXT_SESSION_조각/99_NEXT_SESSION-001.md` | 40-120 | O | `▣ AAAA4` · `kind_hint` · `DEV_UNIT_PRICE_SRC` |
| `99_NEXT_SESSION_조각/99_NEXT_SESSION-001.md` | 120-192 | O | `▣ AAAA7` · `ERP_BUDGET_ITEM.sql 10-16행` · `▣ ZZZ7` |
| `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md` | 140-152 | O | `O123-B` 행 · `UNSOURCED 축 신설` · `169 → 160` |

- **`read` 미반환 0건 · 재호출 0건** (판정식 `재호출 ≥ 미반환` 충족).

## E11. 등재로 인해 프롬프트에서 정정되는 것 (4건)

1. `20260826_아키텍처 지도.html` → **`20260826_아키텍처 지도 요약본.html`**(E2).
2. 「환경 지뢰 **신규**」 → **기존 항목(`-024.md:56`)의 결과·처방이 신규**(E6).
3. 「`-013 §7` 에 등재하라」 → 좌표는 **`-024.md:4`**(E6).
4. 「`--label` 지원 여부를 확인하라」 → **이미 지원한다** ⇒ 시정 대상은 **절차**
   (`export SESSION_LABEL` 미이행)다(E7).

_Co-authored with CoCo_

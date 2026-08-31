> #### 🟢 [2026-08-30 O123-C] 30_output_share 최신화(17종 재생성) + gate_census 오분류 2건·계정 하드코딩 1건 시정
>
> 🔴 **등재 경위** — 이 항목은 **O123-C 가 스스로 쓰지 못했다.** 다음 세션(**O123-D**)이
> 인수인계 프롬프트를 유일한 운반체로 받아 **파일·산출물에서 전건 재실측한 뒤** 소급 등재했다.
> 근거철 = `_o123c_evidence.md`(판정보다 먼저 기록 · `R1-3-7-c`).
> 🔴 **프롬프트 서술을 정본으로 쓰지 않았다**(`R1-3-7` 대체 근거 금지) ⇒ **4건이 정정됐다**(§O123-D).
>
> **지시** = 「`_archive` 로 옮기고 오늘까지 기준으로 최신화」.
>
> ### 1. 🟢 산출물 최신화 — 아카이브 23종 · 재생성 17종 · 미생산 5종
>
> `30_output_share/_archive/20260830/` 신설 후 **23종 복사** · SHA256 전건 동일 검증.
> 🔴 **승인 방식 = 「복사 후 제자리 덮어쓰기」** ⇒ **산출물 `rm` 0건**(공백 위험 0).
> 🔴 **그 방식을 택한 이유가 기술적이다** — `scripts/gen_silver_gold_retention.py:28` 이
> `PREV = os.environ.get("GN_DW_PREV", os.path.join(WS, "30_output_share"))` 로 **이전 판본을
> 델타 입력으로 읽는다**(`:89` `ppath = os.path.join(PREV, BASENAME + ".csv")`)
> ⇒ 원본을 먼저 지우면 08 의 「변동」 열이 근거를 잃는다.
> · 정리 = `_probe.bin`·`_probe.txt` 삭제(`R1-7-7` 절차) · `_o122_alias_census.csv` 아카이브 이동.
> · **재생성 17종** = `03` · `04{md,csv,xlsx}` · `05{md,csv,xlsx}` · `06{md,csv,xlsx}` · `07` ·
>   `08{md,csv}` · `09{md,csv}` · `09_섹션배너.json` · `20260826_아키텍처 지도 요약본.html`.
> · 선행 입력 = `dump_schema.py` → `/tmp/schema.json` · `census_columns.py` → `/tmp/census.json`.
> · 🟠 **미생산 5종**(해시 불변 · mtime 08:50) = `01_DW_현업활용가이드.md` · `10_원천입고_결손요약.md` ·
>   `12`·`13` 미해결이슈 쿼리 `.sql` · `미해결이슈_요약_O102.md` — **제네레이터가 없다.**
> 🔴 **`01`·`10` 은 이미 stale 이다** — 헤더가 `companion:` 으로 선언한 04·05·03 을 이 세션이 갱신했다.
>
> ### 2. 🔴🔴 gate_census 오분류 2건 시정 — 재발 축이다
>
> `gen_column_mapping` 과 `run_bronze_audit_host` 가 **`MUTATES`(실행 금지)로 등재돼 있어
> 04·06 을 재생성할 수 없었다.** 실측 = 접속 참조 **0** · DDL/DML 키워드 **0**
> (`ALTER VIEW` 는 `post_hook` 을 **파싱하는 대상 문자열**이다) ⇒ **`GEN` 으로 이동**.
> 현재 상태 = `[GEN] 12개` 안에 두 도구가 있다(`gen_column_mapping` = 「라이브 접속 0(모델 파싱 전용)」 ·
> `run_bronze_audit_host` = 「조회 전용(무인자 = 직접조회)」).
> 🔴 **O121-B 가 `audit_ddl_rule7`·`sv_unit_gate`·`table_ddl_column_gate` 에서 고친 것과 같은 유형**이다
> (그 3종은 현재 `[JUDGE]` 에 「DDL 파일을 **읽는다**」·「라이브를 **읽는다**」로 있다)
> ⇒ 🔴 **판정식 = 「DDL 문자열을 입력으로 읽는 도구」를 「DDL 을 발행하는 도구」로 오분류하는 축이
> 3건 → 2건으로 재발했다.** 분류 근거는 **키워드 등장이 아니라 그 키워드의 역할**(입력이냐 출력이냐)이다.
>
> ### 3. 🔴 gen_arch_map.py 계정 하드코딩 시정 (`P169` 축)
>
> `account="zl50263.ap-northeast-2.aws"` · `user="CHOIH"` · `role="GN_DW_ADMIN"` ·
> `warehouse="GN_DW_DEV_WH"` 가 박혀 있어 **403 Forbidden** — **이 제네레이터만 실패한 유일한 원인**이었다.
> ⇒ `scripts/sfconn.py` 경유로 교체(`:40-41` `import sfconn` / `return sfconn.conn()`).
> 🟢 **판정식 = 접속 정보는 도구마다 적지 말고 단일 경유점에서 받는다.**
> ⚠️ 같은 파일 `:735` 의 `account=account,` 는 **접속이 아니라 HTML 표시용 인자**다
> (`:731` `def write_html(path, account, …)`) ⇒ 「하드코딩 잔존」으로 오판하지 말 것.
>
> ### 4. 🔴🔴 `/tmp` 지뢰가 골든 지문을 stale 로 만들었다 — 처방 = 같은 호출 안에서 체인
>
> `/tmp` 가 **세션 중간에 비워진다**(13:36 생성한 `/tmp/schema.json` 이 14:18 부재).
> 그래서 `test_generators` 골든의 **스키마 지문이 구 값으로 보전**됐다
> (🟢 O111-B 가드가 **지우지는 않았다** — 보전한 것이 오히려 어긋남을 남겼다).
> ⇒ `dump_schema` + 골든 발행을 **한 셸 호출 안에서 체인**해 정정
> (`3581c638b4260bd9` → **`12ffa5c63c8ce470`** · **산출물 수치 차이 0건**).
> 🟢 **판정식 = `/tmp` 산출물에 의존하는 도구는 생성과 소비를 같은 호출에 묶어라.**
> 🔴 **[O123-D 정정] 이것은 「환경 지뢰 신규」가 아니다** — `/tmp` 소실은 `99_NEXT_SESSION-024.md:56`
> 에 **이미 등재돼 있었다**. 신규인 것은 **그 지뢰의 결과(골든 지문)와 체인 처방**이다.
>
> ### 5. 🟢 골든 재발행 근거 — 덮기 전 소실 0 실증
>
> 08 행 **536 → 752**(순증 216)인데 키 `(SILVER_TABLE, COLUMN)` **중복 0 · 사라진 키 0 ·
> 신규 키 216 순수 증가**이고, 원인은 **SILVER 테이블 39 → 43**으로 규명된다
> (신규 = `BIGQUERY_REFINED_DATA` · `GA4_BASIC` · `CRM_MEMBER_SPONSOR_SPAN` · `ERP_BUDGET_YEARLY`).
> `SILVER_ONLY_CHAIN` **127 → 292** 급증은 대부분 **GA 축**(`BIGQUERY_REFINED_DATA` +118 ·
> `GA4_BASIC` +46 · `GA4_IDENTITY` +1)이고, O120 이 실증한 **「GA 축이 GOLD 에서 끊긴다」와 정합**한다.
> 🔴 **[O123-D 신설 판정식] 소실 판정의 키는 「식별자」로만 잡아라** — 키에 `STATUS` 를 넣어 3열로 재면
> **「사라진 키 10 · 신규 226」** 이 나오는데 그 10건은 소실이 아니라 **상태 전이**다
> (`REFERENCED` 238→291 · `DROPPED` 143→141). **판정값을 키에 넣으면 전이가 소실로 보인다.**
>
> ### 6. 🔴 라이브 변경 범위
>
> **라이브 DDL/DML 0건 · dbt 0건 · 개명 실행 0건**(O123-C 자기신고).
> 🔴 **[O123-D 한계 명시] 이 값은 사후 재현이 불가하다**(`R2-8-4-c`) — 과거 시점의 부작용 부재는
> 파일로 증명되지 않는다. 🟢 파일 축으로 확인된 것 = 개명 확정 12건은 미실행이고
> 완료 판정식은 여전히 `INFORMATION_SCHEMA.COLUMNS` 구 컬럼명 0건이다(`§0-AAAA` AAAA5).
>
> ### 7. 🟠 미결 — 골든 2회 발행이 `UNLABELED` 다
>
> `scripts/golden/outputs.json` 발행 이력 `:13`·`:19` 가 `"label": "UNLABELED"`
> (대조군 `:7` = `"label": "O111-B"`).
> 🔴 **[O123-D 정정] 도구는 `--label` 을 이미 지원한다** —
> `test_generators.py:746` `def update_golden(reason=None, label=None)` · CLI `--label` ·
> `snapshot_util.resolve_label()`(인자 → `SESSION_LABEL` → `UNLABELED`).
> ⇒ **시정 대상은 도구가 아니라 절차다.** `--label` 도 `SESSION_LABEL` 도 주지 않았다
> ⇒ 🔴 이는 `§0-AAAA:49` 의 `export SESSION_LABEL=O1NN 을 착수 직후 먼저 하라`(`R1-7-10`) **미이행**이다.
> 🟢 그 발행의 `--reason` 은 충실했다(`/tmp` 소실 경위·구 지문·수치 차이 0 을 전부 적었다)
> ⇒ **사유는 지켰고 라벨은 놓쳤다.**

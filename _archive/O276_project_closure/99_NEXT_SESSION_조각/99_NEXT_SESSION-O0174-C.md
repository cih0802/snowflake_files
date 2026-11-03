<!-- LLM-METADATA
doc_id: HANDOFF_O0174_C
doc_role: 인수인계 — 세션 `O174-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-21
created_by: O174-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0174-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## 0-AAAF/O174-C. 🟢 [2026-09-21 O174-C — dbt 성공 후 마감: 산출물 재생성 · 골든 재발행 · 누락 소비처 1건 시정]

> 🔴 이 세션은 단위 **3개**(`-A`·`-B`·`-C`)다 — **전부 읽어라**(형제다).

### ▣ O174-C-0 🔴🔴 먼저 알아라 — 이 단위가 확정한 판정식 3개

· ㉠ 🔴🔴 **「소비처 전수 실측」에 도구의 하드코딩 매핑표가 빠졌다** — 개명 대상을 파일 텍스트로만
  세면 **판정 로직 안의 매핑표**를 놓친다. 실사고 = `run_bronze_audit_host.LINEAGE_MAP` 의
  `("DGT…","CPC")→CPC_SRC` 2줄을 못 고쳐 감사 판정이 「노출됨(GOLD) 137 → 135」로 **뒤집혔다**
  (BRONZE `CPC` 가 「미노출 · 배선 필요」로 오판). 🟢 시정 후 **137 복원**.
  🟢 판정식 = **개명 소비처는 「그 이름을 쓰는 파일」이 아니라 「그 이름으로 판정하는 코드」까지다.**
· ㉡ 🔴 **골든 차이는 「건수」가 아니라 「항목별 원인」으로 규명해야 한다** — 21건을 6갈래로 분해했더니
  그중 2건이 **내 결함**이었다. 건수만 보고 `--update-golden` 했다면 결함을 기준선에 **굳혔다**.
· ㉢ 🟢 **JSON 파싱 실패가 곧 파일 손상은 아니다** — `outputs.json` 이 1회 `JSONDecodeError` 였고
  같은 파일을 다시 읽으면 유효했다(**torn read** · `R1-7-3`). 🔴 손상 판정 전에 재읽어라.

### ▣ O174-C-1 🟢 이 단위가 끝낸 것

· **빌드 대사 전건 일치**(사용자 `dbt build` PASS 524 / WARN 37 / ERROR 0 / 561) =
  SILVER `AGENCY_AD_DIGITAL` **203,138**(`CPC_CLICK_SRC` 9,080) · `AGENCY_AD_BROADCAST` **39,823**
  (`CPC_CALL_SRC` 34,719) · GOLD 두 팩트 불변 · `WIDE_AD_COMBINED` 242,961(9,080 / 34,719)
  ⇒ O174-B 가 예고한 기대값과 **4/4 일치** · 0행 피해 **복구 완료**.
· **산출물 재생성** = 02 인벤토리 · 04 컬럼계보 · 06 BRONZE노출감사 · 08 보존율 · 09 빅테이블 VIEW.
  선행 의존 2건을 먼저 만들었다(`/tmp` 는 턴 사이에 비워진다) = `dump_schema.py` → `/tmp/schema.json` ·
  `census_columns.py` → `/tmp/census.json`.
· **누락 소비처 시정** = `LINEAGE_MAP` 2줄(`CPC`→`CPC_CLICK_SRC`/`CPC_CALL_SRC`).
· **골든 재발행 1건**(`test_generators`) — 사유에 **6갈래 규명 전문**을 적었다:
  CPC 개명 짝 6 · 06 rows +50(`_STDR_YM` · O171) · 06 노출됨 137 복원(내 결함 시정) ·
  08 +34(개명 연쇄 + 신규 SILVER 테이블 컬럼) · `NO_CONSUMER` +30(미소비 신규 컬럼) · 측정일 3.
· **검증 전건** = 음성 테스트 **40/40 rc=0**(`test_generators` 21/0 · `test_verify_wide_doc` ALL PASS) ·
  `verify_wide_doc` **575컬럼 불일치 0** · `table_ddl_column_gate` **84/84** ·
  `sv_code_label_gate` blocking 0 · advisory 0 · `rename_stale_gate` 축1 0건 · `gate_census --final` rc=0.

### ▣ O174-C-2 🟠 다음이 할 일

· 🟠 **`E-1` FUNDRAISING_COST 는 사용자가 현업에 직접 확인한다**(2026-09-21 결정) ⇒ 에이전트는
  문항을 발행하지 않았다. 회신이 오면 분류를 확정하고 `FACT_BUDGET` 배선으로 내려라.
  실측 = 온라인모금 57행 54,553,600,496 · 미디어모금 64행 37,457,213,517 · 기관홍보사업 46행 195,840,457 ·
  `VENDOR` 는 미디어모금 **64행 중 6행**만 채움.
· 🔴 **§4 미착수 잔여** = `E-4` 광고비 집계 축 · `DEC-35`(라벨 5 + 열거 부적절 2) · `_STDR_YM` SILVER 취급 ·
  `D8 ⑩` · `D9 O91-F` 잔여 2 · `D11` BRD · 착수표 ⑭ · `SEARCH_CONSOLE_DATA2` 드롭 + GSC COMMENT 오기.
· 🟠 **문서20 회신 대기 6건**(`N-16` 패킷) — `CONF-2` → `DEC-33` 이 선행이다.
· 🟠 **개명 런북 미작성**(O174-B-3) — dbt role 이 소유자가 아니므로 컬럼 개명은 **항상 선행 ALTER** 가
  필요하다. 선택지 3안(현행 유지 / 소유권 이전 / 런북 문서화)은 **결정 대기**.
· 🟠 여유 부족 1건 = `03_init_ihcho_스킬_본문`(미분할 ⇒ 재균형 불가 · 분할 결정 대기).

### ▣ O174-C-3 📏 종료 기준선 (🔴 인용하지 말고 재라)

· 음성 테스트 **40종 전건 rc=0** · 게이트(브리핑 6종) rc=0 · 유형만 🟡(여유부족 1)
· 06 감사 = rows **1,254** · 노출됨 **137** · 미노출 592 · 08 보존율 **300/441 = 68.0%**(rows 793)
· 09 빅테이블 VIEW = 941줄 / 157,538 B · `verify_wide_doc` 575컬럼 일치
· 라이브 = `GOLD.FACT_AD_DIGITAL.CPC_CLICK_SRC` 9,080/203,138 · `FACT_AD_BROADCAST.CPC_CALL_SRC` 34,719/39,823
· 라벨 = 정의 축 최대 **174**(단위 A·B·C) ⇒ 다음 세션은 **O175**

_Co-authored with CoCo_

_Co-authored with CoCo_

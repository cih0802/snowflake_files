<!-- LLM-METADATA
doc_id: HANDOFF_O0216_E
doc_role: 인수인계 — 세션 `O216-E` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-12
created_by: O216-E
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0216-E -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O216-E 인수인계 (build 후 잔여 집행 · A4-W BIGQUERY 종결 · E-1 기결정 확인 · 게이트 결함 시정 · 2026-10-12 · CK24285)

### ▣ O216-E-0 🔴 먼저 알아라 (㉡ 적용 · 승인 = 사용자 지시 「잔여작업 진행」 · 확정위반 1 · 근접 1)

- build 확인(사용자 실행 · 새 배포본) = `OPS.WARN_FMM_FUTURE_MONTH_CAP` 0행 · A4-X 8 컬럼 라이브 COMMENT 반영 · `FACT_BIGQUERY_BEHAVIOR` 0 → **1,669,146행**.
- 🔴 확정위반 1 = **E-1 모금성비용을 YN_1 단일 정의로 배선했다가 같은 턴에 되돌렸다** — 현업 회신 42 · DEC-57(문서30 `-017.md:44`)
  「하나로 정하지 않는다 · 직접모금비1·2 를 이름 그대로 나란히」 위반. 원인 = O216-C·D 와 같은 축(결정 이력 미검색 · `R3-9 ㉥`).
  · 영향 = build 전이라 라이브 값 영향 0 · 라이브 COMMENT 는 DEC-57 문안으로 정정(파일·라이브 드리프트 0).
  · 🔴 처방 = **새 판정·배선 전에 `grep` 으로 그 항목 ID·지표명을 결정 문서(문서30)·회신표에서 먼저 찾는다** — 이 세션에서만 3회 반복됐다(개발건수 · BLOCKING-5/A1 · E-1).
- 🟠 근접 1 = `WIDE_BIGQUERY_BEHAVIOR.sql` `edit` 앵커가 `from` 줄을 삼켰다(`R1-7-8`) → 직후 컨텍스트에서 발견 · 즉시 복구 · 유실 0.

### ▣ O216-E-1 집행 결과

| 항목 | 판정 | 근거 |
|---|---|---|
| O91-F A4-W BIGQUERY 2 | 🟢 종결 | UTM ↔ `DIM_CAMPAIGN.MKTG_UTM_NM` 1:N(최대 902 · 1:1 67/950,082) ⇒ SK 배선 불가(DEC-41) · `WIDE_BIGQUERY_BEHAVIOR` 말미에 `UTM_CAMPAIGN` 노출 + 캠페인 3컬럼 영구 센티넬(`tmp/o216e_bq_yml.py` · 39 컬럼) |
| UTM 공백 | 📏 | 2025-06-26 이전 `UTM_CAMPAIGN` NULL = 원천 `SILVER.BIGQUERY_EVENT` 도 0/3,876,172 ⇒ 백필 불요 |
| O91-F A4-W AD 4 | 🟡 Q10 회신 대기 | AD UTM 112종 중 79 이름 일치 · 1:1 0행(최대 902) · `MKTG_CAMPAIGN_SK` 55.8% 기가동 · 문서20 `-009.md:197` 미회신 |
| 순서9-C E-1 | 🟢 종결(기결정) | DEC-57 · 정본 = `SV_BUDGET.DIRECT_FUNDRAISING_COST_1·2` · `FUNDRAISING_COST` = 의도적 NULL · 문서20 §N-17 🟢 |
| 순서9-C G-5 | 🟢 개발계 해소 | `FACT_BIGQUERY_BEHAVIOR` 1,669,146행(20240114~20261005) · 운영계는 반영 시 재측정 |
| `table_ddl_column_gate` | 🟢 시정 | 문자열 `set` · 문자열 리스트 `set`+`for` 렌더 · leftover DOTALL · **115/115 rc=0** · 음성 3/3 차단 · 종전 `BIGQUERY_SESSION` 조용한 오렌더 해소 |
| O59-P-1 판정식 잔여 | 🟢 충족 | 위 게이트에서 `FACT_MESSAGE_DISPATCH` DDL 55 = 모델 55 |

### ▣ O216-E-2 🟠 ㉠ 이 작업의 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 배포본 갱신(`ALTER DBT PROJECT … ADD VERSION`) 후 `build --select WIDE_BIGQUERY_BEHAVIOR FACT_BUDGET+` | 새 `UTM_CAMPAIGN` 컬럼 · COMMENT 3건 라이브 반영 · FACT_BUDGET 은 주석만 변경(값 무변경) |
| 2 | build 후 `comment_drift_gate` = GOLD 뷰 PENDING 4 → 0 · `WIDE_BIGQUERY_BEHAVIOR` 39 컬럼 확인 | 에이전트 |

### ▣ O216-E-3 🟡 ㉡ 개발계 회신·외부 대기 (운영계 반영 전 남은 것)

- **Q10** 1건(예산 세세목·광고 ↔ 개발캠페인 코드 · 문서20 `-009.md:197`) — 회신 「코드 없음」이면 AD 4건을 영구 센티넬로 종결.
- FACT_BUDGET 원천 규모(이 계정 BRONZE_ERP 원장 303행) — 운영계 대조로만 판정 가능(개발계 작업 아님).

### ▣ O216-E-4 ⚪ 결정 완료(재론 금지)

- 모금성비용 = DEC-57(하나로 정하지 않음) · GA4 캠페인 축 = `UTM_CAMPAIGN` 원값(CRM 캠페인 SK 배선 안 함).

_Co-authored with CoCo_

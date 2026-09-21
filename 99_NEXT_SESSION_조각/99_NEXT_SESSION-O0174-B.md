<!-- LLM-METADATA
doc_id: HANDOFF_O0174_B
doc_role: 인수인계 — 세션 `O174-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-21
created_by: O174-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0174-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## 0-AAAE/O174-B. 🟠 [2026-09-21 O174-B — dbt 실패 복구 · ALTER RENAME 경로 확정]

> 🔴 이 단위는 `O174-A` 와 **함께 읽어라**(같은 세션 · 접미가 다른 것은 형제다).

### ▣ O174-B-0 🔴🔴 먼저 알아라 — 이 단위가 확정한 판정식 3개

· ㉠ 🔴🔴 **최소권한 role 은 자기가 소유하지 않은 테이블의 「스키마」를 바꿀 수 없다** — 적재 권한
  (`INSERT`·`UPDATE`·`DELETE`·`TRUNCATE`)이 있어도 컬럼 개명은 막힌다. 실사고 = `dbt build` 가
  `GN_DW_ENGINEER` 로 돌아 *"must have MODIFY granted on TABLE"* 로 2모델 실패(561 중 2).
  🟢 실측 = SILVER/GOLD 기본 테이블 **84개 전부 소유자 `GN_DW_ADMIN`** · ENGINEER 는 48/48 동일 패턴.
· ㉡ 🔴🔴 **권한을 풀어도 그 경로는 「개명」이 아니다** — SILVER/GOLD 기본값이
  `incremental` + `on_schema_change: append_new_columns` 라서, 개명은 **새 컬럼 추가**로 처리된다
  ⇒ 옛 `CPC_SRC` 가 **남아** 두 이름이 공존하고 개명 목적(분모 혼동 제거)이 무너진다.
  🟢 판정식 = **개명을 「스키마 진화」 경로에 태우지 마라** — 진화는 더하기이고 개명은 바꾸기다.
· ㉢ 🔴🔴 **실패한 빌드가 데이터를 비울 수 있다** — `append` 전략이 **TRUNCATE 후 INSERT** 인데
  ALTER 단계에서 죽어 **SILVER 2테이블이 0행**으로 남았다(GOLD·staging 은 무손실).
  🟢 판정식 = **빌드 실패 후에는 「무엇이 실패했나」가 아니라 「무엇이 비었나」를 먼저 재라.**

### ▣ O174-B-1 🟢 이 단위가 한 것 (사용자 결정 = ALTER RENAME)

· 라이브 개명 **4건 집행**(소유 경로 · 데이터 재적재 0 · 권한 모델 무변경):
  `SILVER.AGENCY_AD_DIGITAL.CPC_SRC`→`CPC_CLICK_SRC` · `SILVER.AGENCY_AD_BROADCAST.CPC_SRC`→`CPC_CALL_SRC`
  · `GOLD.FACT_AD_DIGITAL.CPC_SRC`→`CPC_CLICK_SRC` · `GOLD.FACT_AD_BROADCAST.CPC_SRC`→`CPC_CALL_SRC`.
· 🟢 `WIDE_AD_*` 뷰 5종은 **소유자가 `GN_DW_ENGINEER`** 이므로 dbt 가 스스로 교체한다(개명 대상 아님).
· 🟢 **DDL 정본 점검**(사용자 요구 = 신규 환경 DDL ↔ dbt 일치) = 구명 **0건** · 신명만 실재
  (`08_SILVER_테이블DDL` 1+1 · `06_DDL.sql` 2+2 · `10_WIDE VIEW 코멘트.sql` 1+2) ·
  `table_ddl_column_gate` **84/84 집합 일치 · 순서 드리프트 0 · rc=0**.
· 🟢 GOLD 무손실 확인 = `FACT_AD_DIGITAL.CPC_CLICK_SRC` **9,080/203,138** ·
  `FACT_AD_BROADCAST.CPC_CALL_SRC` **34,719/39,823**(O174-A 기대값과 일치).

### ▣ O174-B-2 🔴 다음이 할 일 — 사용자 dbt 재실행이 선행이다

· 🔴🔴 **`dbt build` 재실행 필요**(`R4-1` · 에이전트 미실행). 지금 상태 =
  `SILVER.AGENCY_AD_DIGITAL` **0행** · `SILVER.AGENCY_AD_BROADCAST` **0행**(실패 빌드가 비웠다).
  🟢 staging 은 온전하므로 재적재로 복구된다 = `AGENCY_AD_ROW_DGT` 203,138 ·
  `ROW_VIDEO` 37,674 · `ROW_REBRDC` 2,149.
· **빌드 후 대사 기대값** = SILVER `AGENCY_AD_DIGITAL` **203,138**(`CPC_CLICK_SRC` 9,080) ·
  `AGENCY_AD_BROADCAST` **39,823**(`CPC_CALL_SRC` 34,719) · GOLD 두 팩트는 **불변**.
· 🔴 그 뒤에야 골든을 발행하라 = `test_generators`(G 축 12건 차이) · `test_verify_wide_doc`(AD 뷰 3건) ·
  `30_output_share` 산출물 재생성(04·05·06·08·09) · `rename_stale_gate --baseline`.
  🔴 **빌드 전에 덮으면 「구명 라이브 + 신명 문서」가 기준선으로 굳는다.**

### ▣ O174-B-3 🟠 남은 구조 위험 (결정 대기)

· 🟠 **개명이 또 필요해지면 같은 벽에 부딪힌다** — dbt role 이 소유자가 아니므로 **모든 컬럼 개명이
  수동 `ALTER RENAME` 선행**을 요구한다. 선택지 = ㉠ 현행 유지(개명 시 소유 role 이 선행 ALTER) ·
  ㉡ 테이블 소유권을 dbt role 로 이전(최소권한 설계 변경) · ㉢ 개명 전용 매크로·런북 문서화.
  🔴 어느 것도 이 단위에서 결정하지 않았다.
· 🟠 `CRM_BIZ_TARGET` 0행은 **이번 사고와 무관**하다(`LAST_ALTERED` 21:18 ↔ 사고 22:05~22:06).

_Co-authored with CoCo_

_Co-authored with CoCo_

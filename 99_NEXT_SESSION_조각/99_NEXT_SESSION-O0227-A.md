<!-- LLM-METADATA
doc_id: HANDOFF_O0227_A
doc_role: 인수인계 — 세션 `O227-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-14
created_by: O227-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0227-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O227-A-0 🔴 먼저 알아라

- O226-A 잔여 ②·③-① 을 집행했다(사용자 승인 · ㉡ · 확정위반 1 · 유실 0) · ①④ 는 👤 회신 대기라 미집행.
- 라이브(xh20001) = Agent **MEMBER V$9**(롤백 V$8) · EXEC V$7 · MKT V$8(변경 없음) · 테이블 COMMENT 21 반영.
- 🔴 dbt 정지점 = 뷰 COMMENT 10 은 파일만 고쳤다(나머지 2 = O226 반영 · 라이브 ID 0 실측) ⇒ 👤 `dbt build --select WIDE_BIGQUERY_BEHAVIOR WIDE_AD_PERFORMANCE WIDE_AD_BROADCAST WIDE_AD_DIGITAL WIDE_AD_BROADCAST_CASE WIDE_TARGET_BIZ WIDE_BUDGET WIDE_MEMBER_FEE WIDE_MEMBER_SERVICE_COHORT WIDE_SPNSR_CLS_AGGR --project-dir 10_dbt_pipeline`.
- 근거 = `tmp/o227/01_evidence.md`(eval 표 · ID↔객체 대응표 · stale 실측) · 스모크 원문 `tmp/o227/smoke_mem9/`.

### ▣ O227-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ② | MEMBER V$9 · V4 AC 0.8715 → 0.9231 · R14 0.33 → 1.0 · 🟠 D3 1.0 → 0.33(스모크 직접 집계 = 조문 원인 아님) |
| ③-① | C3 테이블 21 라이브(잔여 ID 0) · 뷰 2 기반영(O226) · 뷰 10 파일(build 대기) · stale 주장 3 삭제 |

### ▣ O227-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 출처 | 판정 |
|---|---|---|---|
| ① | 👤 IRSD 재확인 — 결정 「FME 증감 사건 신설」을 실측(FME DEV 2·3 과 같은 사건 · 이중계상)으로 보류 · 그래도 신설이면 착수 | O226-A ⑨ | 결정 기록 |
| ② | 👤 dbt build(뷰 10 · 위 명령) → 라이브 뷰 COMMENT 잔여 이슈ID 0 확인 → MEMBER·EXEC·MKT eval V4 기준선 재측정 | O227-A ③-① | INFORMATION_SCHEMA + AC 표 |
| ③ | COMMENT C3 단계 ②~④(컬럼 298 · SV_FIELD 180·SV 8 · AGENT_TOOL 58) = `tmp/o226/10_comment_fix.md` · 단계마다 eval | O226-A ⑩ | 단계별 게이트 |
| ④ | 👤 문서20 N-30 회신(ERP 30코드 · DIGITAL_MAP 위치 · SND 결과코드 13종 · `)` 2행 · 캠페인 속성 2) | O226-A ⑥ | 회신 반영 |
| ⑤ | MEMBER D3 회귀 · TS 0.43 · TE 0.50 — 재측정 1회 후 지속이면 D3 원인(MSTR 개발(건) 분수값 표기) 조사 | O227-A ② | AC 표 |

### ▣ O227-A-3 🟡 ㉡ 워크스페이스 백로그

- `12_agent개선과제/20_O21X_잔여작업_정리.md` 열림 4건(#12 · #14 · #17 · #19).
- 운영계 반영 미결 = O224 · O225 · O226 · O227(MEMBER V$9 스펙 · 테이블 COMMENT 21 · 뷰 COMMENT 10) → 런북 `18_O217_운영계_재현_런북.md` 단계 추가.
- campaign_axis_gate GAP 11(`tmp/o226/02_campaign_gap.md`).
- 🟠 GOLD.WIDE_AD_BROADCAST_CASE 라이브 0행 — 적재 경로 확인.

### ▣ O227-A-4 ⚪ 결정 완료(재론 금지)

- 요건 R = MKT 에도 붙인다(사용자 · V$8 기반영).
- 최초캠페인 = DIM_MEMBER.FIRST_CAMPAIGN → DIM_CAMPAIGN BK 별칭 조인 · 「그 달 후원 캠페인」과 별개 축.
- DGT 캠페인유형1·2 = 결합값 CMPGN_TYPE_BSN_NM 으로 제공(분리 노출 안 함).
- 교차 집계 예외 = 「새 비율·효과 지표 이름이 없으면 분포 조회」(O227 · V$9).

_Co-authored with CoCo_

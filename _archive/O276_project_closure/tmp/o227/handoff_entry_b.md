### ▣ O227-B-0 🔴 먼저 알아라

- O227-A 잔여 ②(① 반영 확인 + 기준선)와 C3 단계 ②(GOLD 컬럼 298)를 집행했다(사용자 「이어서 진행」 · ㉡ · 확정위반 1 · 유실 0).
- 라이브(xh20001) = Agent 변경 없음(EXEC V$7 · MEMBER V$9 · MKT V$8) · GOLD 테이블 컬럼 COMMENT 29 반영.
- 🔴 dbt 정지점 = 뷰 컬럼 269 는 파일만 고쳤다 ⇒ 👤 `dbt build --select WIDE_AD_BROADCAST WIDE_AD_BROADCAST_CASE WIDE_AD_COMBINED WIDE_AD_DIGITAL WIDE_AD_PERFORMANCE WIDE_BIGQUERY_BEHAVIOR WIDE_BUDGET WIDE_EVENT_PARTICIPATION WIDE_MEMBER_EVENT WIDE_MEMBER_FEE WIDE_MEMBER_MONTHLY WIDE_MEMBER_SERVICE_COHORT WIDE_SERVICE_EVENT WIDE_TARGET_BIZ WIDE_TARGET_DEV --project-dir 10_dbt_pipeline`.
- 근거 = `tmp/o227/02_col_evidence.md`(기준선 표 · 거짓 주장 36 실측 · 사고 복구) · 전후 = `tmp/o227/c3_col_diff.md`.

### ▣ O227-B-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 확인 | 뷰 COMMENT 12 라이브 잔여 ID 0 |
| 기준선 | V4 AC EXEC 0.9524 · MEMBER 0.9746(D3 회복 = 실행 변동) · 🟠 MKT 0.8814(Q31 1.0 → 0) |
| ② | 컬럼 298 = 이슈ID 0 · 거짓 주장 36 덮어쓰기(실측) · 테이블 29 라이브 · 뷰 269 PENDING |

### ▣ O227-B-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 출처 | 판정 |
|---|---|---|---|
| ① | 👤 IRSD 재확인 — 결정 「FME 증감 사건 신설」을 실측(FME DEV 2·3 과 같은 사건 · 이중계상)으로 보류 · 그래도 신설이면 착수 | O226-A ⑨ | 결정 기록 |
| ② | 👤 dbt build(뷰 15 · 위 명령) → comment_drift_gate PENDING 0 → eval V4 3종 재측정(MKT Q31 판정 포함) | O227-B ② | 드리프트 0 + AC 표 |
| ③ | COMMENT C3 단계 ③ SV_FIELD 180 · SEMANTIC_VIEW 8 → ④ AGENT_TOOL 58 = `tmp/o226/10_comment_fix.md` · 단계마다 eval | O226-A ⑩ | 단계별 게이트 |
| ④ | 👤 문서20 N-30 회신(ERP 30코드 · DIGITAL_MAP 위치 · SND 결과코드 13종 · `)` 2행 · 캠페인 속성 2) | O226-A ⑥ | 회신 반영 |
| ⑤ | MEMBER TS 0.48 · TE 0.56 저조 — search_biz_definition 선행 호출 영향(정답지에 search 없음) · 정답지 보강 여부 결정 | O227-A ② | AC 표 |
| ⑥ | C3 SILVER COLUMN 32 · SERVING VIEW 7·COLUMN 5·TABLE 1(계획 4단계 밖 잔여) | O227-B | 전수조사 재실행 |

### ▣ O227-B-3 🟡 ㉡ 워크스페이스 백로그

- `12_agent개선과제/20_O21X_잔여작업_정리.md` 열림 4건(#12 · #14 · #17 · #19).
- 운영계 반영 미결 = O224 · O225 · O226 · O227(MEMBER V$9 · 테이블 COMMENT 21 · 뷰 COMMENT 10 · 컬럼 COMMENT 298) → 런북 `18_O217_운영계_재현_런북.md` 단계 추가.
- campaign_axis_gate GAP 11(`tmp/o226/02_campaign_gap.md`).
- 🟠 GOLD.WIDE_AD_BROADCAST_CASE 라이브 0행 — 적재 경로 확인.
- 🟠 전수조사 결과(`코멘트_룰_전수조사_결과.xlsx`)는 O224 시점이라 거짓 주장 축(실측과 어긋난 COMMENT)을 보지 않는다 — SV_FIELD·AGENT_TOOL 에도 같은 stale 주장이 있을 수 있다(③ 착수 시 실측 대조).

### ▣ O227-B-4 ⚪ 결정 완료(재론 금지)

- 요건 R = MKT 에도 붙인다(사용자 · V$8 기반영).
- 최초캠페인 = DIM_MEMBER.FIRST_CAMPAIGN → DIM_CAMPAIGN BK 별칭 조인 · 「그 달 후원 캠페인」과 별개 축.
- DGT 캠페인유형1·2 = 결합값 CMPGN_TYPE_BSN_NM 으로 제공(분리 노출 안 함).
- 교차 집계 예외 = 「새 비율·효과 지표 이름이 없으면 분포 조회」(O227 · V$9).

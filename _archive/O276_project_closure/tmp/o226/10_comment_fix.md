# O226 ⑩ COMMENT 룰 확정 위반 시정 (xh20001 · 2026-10-14)

출처 = `05_SV-Agent_ai/코멘트_룰_전수조사_결과.xlsx` 4_위반상세(O224 전수조사 · 확정 654 = C7 15 · C4 4 · C9 13 · C3 622).

## 시정 완료 (32건)

| 규칙 | 건수 | 처리 | 라이브 |
|---|---|---|---|
| C7 실재하지 않는 객체 | 15 | 13 = BRONZE 원천명을 dbt `source()` 실명으로 교체(`tmp/o226/fix_c7.py` · 06_DDL 3 · 08_SILVER 10 · 05_02 SV 1) · 2 = WIDE_AD_COMBINED·WIDE_TARGET_DEV 경위 문안을 4블록으로 재작성(`_wide_schema.yml`) | GOLD 3 + FPBS 1(파일 정본 드리프트 동반) = `apply_table_comment_drift.py --apply` · SILVER 10 = `tmp/o226/apply_silver_tbl_comment.py --apply` · 유령 원천명 라이브 0건 · 05_02 SV 재배포 · WIDE 2종 = 👤 dbt build 대기 |
| C4 실측 수치 | 4 | 수치 삭제(의미 유지 · 근거는 원장 좌표로) — WIDE_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN · WIDE_MEMBER_EVENT.DEV_CNT · ML_SPONSOR_RISK_V · SV_MSTR_SPNSR_DVLP.MKTG_CHANNEL_NM | ML 뷰 ALTER · MSTR SV 재배포(합계 828,047,258 불변) · WIDE 2종 = 👤 build 대기 |
| C9 코멘트 누락 | 13 | 전건 WIDE_MEMBER_MONTHLY_KPI — yml 등재 + `materialized='gn_view_commented'` | 👤 build 대기 |

## C3 서사적 경위·이슈번호 622건 — 시정 계획 (미집행)

분포(스키마 × 레벨) = GOLD COLUMN 298 · SERVING SV_FIELD 180 · AGENT_TOOL 58 · SILVER COLUMN 32 · GOLD VIEW 12 · GOLD TABLE 11 · SILVER TABLE 10 · SEMANTIC_VIEW 8 · SERVING VIEW 7 · SERVING COLUMN 5 · SERVING TABLE 1.
상위 객체 = SV_MSTR_SPNSR_DVLP 55 · WIDE_MEMBER_EVENT 36 · WIDE_MEMBER_FEE 35 · WIDE_MEMBER_MONTHLY 34 · SV_MEMBER_EVENT 33.

- 🔴 판단(작업계획 §15 K1) = C3 은 Agent 오답 경로가 아니라 토큰 잡음일 가능성이 크다 ⇒ **eval 이 기준선을 잡은 뒤** 단계 집행한다(동시에 바꾸면 효과를 분리할 수 없다).
- 단계 = ① GOLD/SILVER 테이블·뷰 레벨 33(문안 4블록 재작성 · 소량) → ② `_wide_schema.yml` 컬럼 298(이슈ID 태그 `[O##]`·`(DEC-##)` 기계 제거 + 「종전·경위」 문장은 사람 검토) → ③ SV_FIELD 180 · SEMANTIC_VIEW 8(SV 파일별 · 재배포 + 합계 스모크) → ④ AGENT_TOOL 58(스펙 3종 · 버전업 + eval 재측정).
- 도구 = 규칙 C3 판정식(전수조사 스크립트)을 dry-run 으로 돌려 치환 목록을 파일로 낸 뒤 줄 지정 치환(`fix_c7.py` 방식) · 단계마다 `comment_drift_gate` · `sv_rule7_scan` · line_len.
- 🔴 이슈ID 를 지우면 근거 추적이 끊긴다 ⇒ 지운 ID ↔ 객체 대응표를 같은 단계에서 원장에 남긴다.

_Co-authored with CoCo_

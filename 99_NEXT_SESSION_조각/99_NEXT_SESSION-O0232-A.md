<!-- LLM-METADATA
doc_id: HANDOFF_O0232_A
doc_role: 인수인계 — 세션 `O232-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O232-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0232-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O232-A-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · **운영계 반영 없음** · ㉡ 적용(지시 동봉 · 사용자 일괄 승인).
- 🔴 확정위반 3 = `R4-1` 2건(O-HC·O231 에서 에이전트가 dbt 직접 실행 · 이번 단위부터 정지점 준수) · `R1-7-2` 1건(`sv_unit_gate.py` 편집 후 해시 확인 · 순서 역전).
- 🔴 운영계 dbt 실패(`CRM_SEND_MEMBER` 003001 MODIFY) 원인 = **운영계 라이브가 DDL 정본보다 낡음**(O225-C SND 캠페인 3컬럼 부재 추정) · 개발계 `o163_ddl_live_drift.py` = DDL ↔ 라이브 드리프트 0(116 테이블 · 2,755 컬럼).
  ⇒ 운영계 처방 = 그 도구로 전수 대조 → 소유자 롤 ADD COLUMN · `FACT_MEMBER_COHORT_SURVIVAL` 은 CREATE(06_DDL) 선행 → dbt build(런북 §7-A).
- 사용자 결정 = 회원월상계는 **의도된 규칙**(MSTR = 2026 프로젝트 기준값) · LTV 상한은 사용자가 직접 정한다.

### ▣ O232-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 게이트 | `agent_tool_claim_gate` 🔴 2 → 🟢 — 「0원·산출 불가로 답하지 않는다」(답변 규칙)를 `sv_unit_gate.NUM_EXEMPT` 에 면제(뒤 20자 「답하지」 한정 · 음성 테스트 「광고비 0원 캠페인」은 여전히 위반) |
| ② 하드코딩 | `gn_biz_codes.sql` 에 행사 상태코드(EVT_* · MS006 1~6 · MS304 110)·`gn_evt_stat`·`gn_evt_attended`·`gn_is_notice_title`·`gn_erp_not_total` · FEA 라벨 → **코드** 판정(라벨↔코드 1:1 · 5종 차이 0) · 신규 `tests/warn_evt_stat_code_label.sql`(음성 테스트 2건 적발) |
| ③ 생존 테이블 | 06_DDL `FACT_MEMBER_COHORT_SURVIVAL`(PK = AXIS_TYPE·AXIS_VALUE·ELAPSED_MONTH · CAST 규격) · ADMIN CREATE · 모델 `models/gold/fact/` · `tests/assert_fmcs_grain_and_survival.sql` · 옛 뷰 모델 삭제 · 옛 뷰 **DROP** |
| ④ LTV 정리 | 상한 = 컬럼 → **행 표지 `LTV_CAP_MONTHS`** ⇒ `ltv_caps` 만 바꾸면 DDL·yml·SV 불변 · SV_MEMBER_COHORT = `SURV_LTV_CAP_MONTHS` 차원 + `EXP_TENURE_MONTHS`·`SURVIVAL_AT_CAP`(종전 EXP_TENURE_36M·60M·SURVIVAL_12M/36M/60M 폐기) |
| ⑤ 검증 | 👤 build PASS=646 WARN=21 ERROR=0 · 회귀 FEA·FMD·ERP 3종 내용 해시 동일(ERP 는 Time Travel 대조) · 전체 RMST 27.3618 / 40.7316 · SV 스모크 = O231 비교표 일치 |
| ⑥ 백로그 | #33 = 회원월상계 결정 반영 · O-HC 「근거 없음 8건」 **오판정 정정**(DEC-59 · #113 · #72·#73 · #129 · 30-012 §29-A · 20 §I·M-1 · 30-013) · 🆕 #34 = 처리통보 키워드 「감사」(장기회원감사서비스 121,936건) |

### ▣ O232-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 LTV 상한·학습기간·셀최소 결정 → `dbt_project.yml` vars → `dbt build --select FACT_MEMBER_COHORT_SURVIVAL` → RT-14·27·Agent LTV 지침 교체 | #32 |
| ② | 👤 운영계 = `o163_ddl_live_drift.py` 전수 대조 → 소유자 롤 ADD COLUMN · SURVIVAL CREATE → dbt build → SV 2종 → 코퍼스·Agent | 런북 §7 ⑲·§7-A |
| ③ | 👤 현업 = 처리통보 키워드 정의(DEC-33 ①) | #34 |
| ④ | 코호트 획득건 「신규 우선」 결정문 미발견(30-012:47 언급만) — 근거 확정 또는 결정 등재 | #33 잔여 |

### ▣ O232-A-4 ⚪ 결정 완료(재론 금지)

- 회원월상계 = 의도된 규칙(MSTR 기준) · DEV_CNT 불변(사용자 O232).
- LTV 상한은 행 표지로 관리 · 기대 유지개월 = 표준 RMST(O231 결정 유지).
- O231-A-4 결정 전건 유지.

_Co-authored with CoCo_

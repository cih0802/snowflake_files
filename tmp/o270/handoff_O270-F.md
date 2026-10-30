## ▣ O270-F-0 🔴 먼저 알아라

- 원천별 접근통제(O270 계획서 W1~W9)를 **개발계 ZS83821 에서 끝냈다**(2026-10-29~30) · 운영계는 미반영.
- 사용자 결정 = W2 시뮬레이터 → 경영·회원 Agent 에서 제거(마케팅은 원래 배선) · W5 = ㉢ · 미분류 시드 ORG_SUCCESSION_MANUAL = COMMON.
- 🔴 계획서 §1 정정 = 회원 Agent 에도 SV_ML_REALTIME_SIMULATOR(AGENCY) 배선이 있었다 · GOLD 에는 FUTURE VIEWS GRANT 가 있다.
- 🔴 W5 정정 = WIDE 뷰 materialization `gn_view_commented` 가 grants 를 무시했다 ⇒ copy grants + apply_grants(should_revoke=False) 추가.
- 🔴 C1 실측 = 보조 역할 ALL 이면 차단 객체가 열린다(W6 증거 CSV) ⇒ 사용자 배정 시 DEFAULT_SECONDARY_ROLES = () 필수.

## ▣ O270-F-1 결과(개발계)

| 단위 | 결과 | 좌표 |
|---|---|---|
| W1 분류표 | dbt ref/source + OBJECT_DEPENDENCIES · 공통 차원 오염 0 · 혼합 1(FACT_MKTG_CAMPAIGN_MONTHLY_COST) | `12_agent개선과제/output/O270_source_class.csv` |
| W3 Agent | 경영 VERSION$6(analyst_ad·시뮬레이터 제거) · 회원 VERSION$7(시뮬레이터 제거) · 경영 COMMENT 광고 문구 제거 | `cortex_project/agents/*/agent_spec.yaml` · `09_1`·`09_2` |
| W4 역할 | 접근 역할 4 · 기능 역할 4 · 193문 적용 | `05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql` · 생성기 `output/O270_gen_rbac_sql.py` |
| C7 코퍼스 | 광고 단독 8행 AGENT_SCOPE = MARKETING | `05_SV-Agent_ai/49_DEPLOY_CORPUS_SCOPE_O270.sql` |
| W5 유지 | dbt wide `+grants` · 매크로 copy grants · DDL 40파일 76줄 · 👤 build 후 GRANT 유지 확인 | `12_agent개선과제/O270_W5_권한유지_설계안.md` §6 |
| W6 검증 | 보조 역할 OFF 52/52 PASS · 임시 부여 회수 잔존 0 | `12_agent개선과제/output/O270_W6_검증증거.csv` |
| W7 게이트 | `scripts/rbac_source_gate.py --live` PASS · 음성 테스트 PASS | `scripts/test_rbac_source_gate.py` |
| W8·W9 | R97 · 실행카드 · 권한 매트릭스 · 현업 공지 초안 | `12_agent개선과제/O270_W8_운영계_실행카드.md` |

## ▣ O270-F-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 👤 운영계 R97 실행 → CSV 회수 → 실행카드 §0 판정 | 운영계 |
| ② | 운영계 반영 = 실행카드 §1 순서(48번 [1]~[3] 먼저 → dbt build → Agent → 49번 → 게이트) | 🔴 단계별 승인 |
| ③ | 현업 공지 발송(`12_agent개선과제/O270_W9_현업공지_Agent조회범위.md`) | 운영계 반영 후 |
| ④ | 구 역할 회수(48번 [6]) | 🔴 R97 소비처 0 확인 후에만 |

## ▣ O270-F-3 ㉡ 워크스페이스 백로그

- 🔴 하지 마라 = W8 전 GN_DW_ANALYST·VIEWER·SERVICE 회수 · dbt grants 에 should_revoke 켜기 · 이름 매칭으로 원천 분류.
- 브리핑 🔴 `sv_enum_newvalue_gate 1/4`(SV_EVENT_PARTICIPATION.EVENT_CATEGORY_NAME 신규값)는 이 세션 범위 밖 · 미처리.

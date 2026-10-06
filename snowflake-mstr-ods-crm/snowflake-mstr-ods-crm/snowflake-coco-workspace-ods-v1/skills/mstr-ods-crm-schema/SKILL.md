---
name: mstr-ods-crm-schema
description: Explicitly invoked MSTR_ODS CRM reference skill for approved GN_DW.BRONZE_CRM sources. Supports natural-language planning, SQL, validation, Semantic Layer, and Streamlit work without requiring planners to know table or column names.
---

# MSTR_ODS CRM Schema Skill

## Activation Guard

현재 사용자 메시지에 `$mstr-ods-crm-schema`가 있을 때만 이 스킬을 적용한다. 자동으로 선택되었다면 스킬 규칙을 적용하지 말고 일반 작업으로 돌아간다.

## Core Workflow

1. 요청을 `ANALYZE`, `BUILD_APP`, `CHANGE_UI`, `VALIDATE_DATA`, `DIAGNOSE_DIFFERENCE`, `ONBOARD_REPORT` 중 하나로 분류한다.
2. `references/common/00_COCO_READ_FIRST_ODS_ONLY.md`를 읽는다.
3. 아래 라우팅 표에 따라 필요한 파일만 추가로 읽는다.
4. 구현 전에 업무 계약과 미확정 항목을 한국어로 보고한다.
5. 핵심 기준이 부족하면 쉬운 질문을 최대 3개만 하고 멈춘다.
6. 기준 확정 후 구현하고, `references/common/07_VALIDATION_GATES.yaml`을 통과시킨다.

## Reference Routing

| 요청 | 추가로 읽을 파일 |
|---|---|
| 테이블·컬럼·PK 확인 | `references/common/01_APPROVED_TABLES.md`, `02_SOURCE_PHYSICAL_CATALOG.json` |
| 여러 테이블 JOIN | `references/common/03_JOIN_CONTRACTS.md` |
| 수·건·금액·날짜 집계 | `references/common/04_BUSINESS_RULES.md` |
| 발송·오픈·클릭 | `references/common/05_SEND_KEY_CONTRACT.yaml` |
| 코드명·코드값 | `references/common/06_RELEVANT_CODE_MAP.json` |
| 검증 | `references/common/07_VALIDATION_GATES.yaml` |
| 현재 ODS와 월마감 차이 | `references/common/08_SNAPSHOT_AND_DIFFERENCE_POLICY.md` |
| 개인정보 | `references/common/09_PRIVACY_POLICY.md` |
| 확인 근거와 미확정 계약 | `references/common/10_EVIDENCE_REGISTER.yaml` |
| CRM 발송성과 화면 | `references/reports/CRM_SEND_PERFORMANCE/` 전체 |
| 기획자 자연어 요청 | `references/examples/`에서 해당 MODE 예시 |

## Non-negotiable Rules

- `GN_DW.BRONZE_CRM`의 승인된 50개 테이블만 사용한다.
- MSTR_DW를 조회하거나 ODS에 없는 MART·DIM을 존재한다고 가정하지 않는다.
- 실제 Snowflake 객체·컬럼·타입을 확인하기 전에 SQL을 확정하지 않는다.
- 컬럼명이 같다는 이유만으로 JOIN하지 않는다.
- SQL Server 원천 PK, Snowflake 물리키, 업무키, 화면 Grain을 구분한다.
- 원시 1:N 이벤트 두 개를 동시에 JOIN해 곱집계를 만들지 않는다.
- 고유 회원 수는 최종 조회 범위에서 다시 계산하며 행별 고유 수를 합산하지 않는다.
- 비율은 전체 분자 ÷ 전체 분모로 계산하며 행별 비율을 평균내지 않는다.
- 현재 ODS로 과거를 계산하면 `현재 ODS 기준 재계산`과 적재시각을 표시한다.
- 기획자에게 영문 컬럼이나 코드값을 선택하라고 요구하지 않는다.
- 이름·연락처·주소·이메일·아동정보·결제정보·메시지 본문은 기본 결과와 다운로드에 노출하지 않는다.

## Implementation Layers

```text
승인 BRONZE 원천
  → 필터·표준화 CORE
  → 중복 제거·상태 선택·행동 귀속 계산 계층
  → 화면 전용 APP View
  → Streamlit KPI·표·차트·다운로드
```

Streamlit Python에서 동일 업무 지표를 다시 계산하지 않는다. 모든 화면 요소는 하나의 검증된 APP 결과를 재사용한다.

## Pre-build Output

구현 전 다음을 한국어로 먼저 보여준다.

1. 판정: 구현 가능 / 업무기준 확인 필요 / 자료 필요
2. 사용할 업무 데이터와 한글 역할
3. 각 데이터의 1행 의미
4. 연결 기준과 예상 1:1·1:N 관계
5. 지표의 수·건·금액·비율·날짜 기준
6. 확인된 내용과 아직 결정되지 않은 내용
7. 중복·미매칭·다대다 위험
8. 기획자가 결정할 질문 최대 3개

## Completion Output

1. 판정: 완료 / 검증 필요 / 업무기준 확인 필요 / 자료 필요
2. 적용한 업무기준
3. 사용한 실제 FQN과 한글 역할
4. 검증 결과: 조건 | 기준값 | 결과값 | 차이 | 판정
5. 생성·변경 파일
6. 남은 결정사항 최대 3개

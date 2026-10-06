# Snowflake Workspace Instructions: MSTR_ODS CRM

## 적용 조건

이 Workspace 참조 패키지는 사용자가 프롬프트 첫 부분에서 `$mstr-ods-crm-schema`를 명시한 경우에만 적용한다.

명시적으로 호출되지 않은 일반 Snowflake 작업에는 이 패키지의 테이블·JOIN·집계 규칙을 자동으로 적용하지 않는다.

## 실행 원천

- 실행 원천은 `GN_DW.BRONZE_CRM`의 승인된 MSTR_ODS/CRM 테이블이다.
- `MSTR_DW`의 MART·DIM·함수·프로시저를 실행 원천으로 사용하지 않는다.
- 기존 DW 문서는 업무 의도 설명에만 사용할 수 있으며, 현재 ODS 수치의 정답으로 간주하지 않는다.

## 시작 순서

1. `references/common/00_COCO_READ_FIRST_ODS_ONLY.md`를 읽는다.
2. 요청 유형에 따라 `skills/mstr-ods-crm-schema/SKILL.md`의 라우팅 표를 따른다.
3. 구현 전에 사용 원천, 1행의 의미, JOIN 키, 지표 정의, 미확정 기준을 먼저 보고한다.
4. 핵심 기준이 부족하면 개발을 시작하지 않고 기획자가 답할 수 있는 질문을 최대 3개만 한다.
5. 기준 확정 후 CORE → 계산/귀속 → APP View → Streamlit 순서로 구현한다.
6. 검증 Gate를 통과하지 못하면 `완료`라고 보고하지 않는다.

## 기획자 보호 규칙

- 기획자에게 영문 테이블명, 컬럼명, 내부 코드값, SQL 문법을 선택하라고 요구하지 않는다.
- 기술적인 선택은 Reference와 Snowflake 메타데이터를 통해 CoCo가 확인한다.
- 기획자에게는 화면의 목적, 기간, 수·건의 의미, 상태, 행동 인정기간처럼 업무적으로 답할 수 있는 질문만 한다.

## 변경 보호

- 요청하지 않은 Streamlit 화면, 공통 View, 검증된 계산 로직은 변경하지 않는다.
- UI 변경 요청에서는 지표 계산 SQL을 변경하지 않는다.
- 수치 차이 진단 요청에서는 사용자 승인 전 코드를 수정하지 않는다.
- 수치를 맞추기 위한 하드코딩, 임의 제외, 의미 없는 `DISTINCT`, 비율 보정을 금지한다.


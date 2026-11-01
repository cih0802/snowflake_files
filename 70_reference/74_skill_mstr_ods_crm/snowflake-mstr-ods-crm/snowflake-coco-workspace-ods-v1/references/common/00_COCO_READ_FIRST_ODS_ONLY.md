# CoCo가 가장 먼저 읽을 ODS 전용 기준

## 이 패키지의 목적

이 Reference Pack은 `MSTR_DW` 리포트를 그대로 재현하는 도구가 아니라, Snowflake에 적재된 `MSTR_ODS/CRM` 데이터를 사용해 새로운 분석·Streamlit을 일관되게 만드는 기준이다.

## 데이터 범위

- 실행 범위: `GN_DW.BRONZE_CRM`
- 승인 범위: `01_APPROVED_TABLES.md`에 등록된 50개 테이블
- SQL Server 메타데이터 추출일: 2026-09-16
- Snowflake 메타데이터와 실제 프로파일 결과가 SQL Server 자료보다 우선한다.

## 사실의 우선순위

충돌이 있으면 다음 순서를 적용한다.

1. 현재 Snowflake에서 확인한 INFORMATION_SCHEMA와 실데이터 프로파일
2. 사용자가 명시적으로 확정한 업무 정의
3. 이 Reference Pack의 확정 계약
4. SQL Server MSTR_ODS의 PK·인덱스·컬럼 설명
5. 이름이나 설명을 기반으로 한 후보 추론

4~5번만으로 운영 JOIN이나 최종 지표를 확정하지 않는다.

## 상태값

| 상태 | 의미 |
|---|---|
| `CONFIRMED_SNOWFLAKE` | Snowflake 메타데이터 또는 실데이터로 확인 |
| `CONFIRMED_BUSINESS` | 담당자가 업무 기준으로 확정 |
| `CONFIRMED_SOURCE_STRUCTURE` | SQL Server 원천 구조에서 확인, Snowflake 검증 필요 |
| `CANDIDATE` | 가능한 후보지만 운영 적용 전 검증 필요 |
| `PENDING` | 자료 부족, 추정 금지 |

## 구현 중단 조건

다음 중 하나라도 핵심 지표에 영향을 주면 구현을 멈춘다.

- 발송/회원/후원/거래를 식별할 전체 키가 확인되지 않음
- 수와 건의 의미가 결정되지 않음
- 성공·완료·취소·환불 상태가 결정되지 않음
- 업무 이벤트 날짜가 결정되지 않음
- 한 행동이 여러 발송에 연결될 때 귀속 기준이 없음
- 현재값으로 과거 시점을 재현할 수 있는지 확인되지 않음

이때 기획자에게 영문 컬럼을 묻지 말고 업무적으로 답할 수 있는 질문을 최대 3개만 한다.


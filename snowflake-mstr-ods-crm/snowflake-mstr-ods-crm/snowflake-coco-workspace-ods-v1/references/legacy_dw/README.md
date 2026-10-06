# Legacy MSTR_DW 자료 사용 제한

이 ODS 전용 패키지에는 MSTR_DW SQL·MART·DIM 자료를 기본 Reference로 포함하지 않는다.

이 폴더는 기존 MSTR_DW 보고서와 현재 ODS 계산의 차이를 설명해야 하는 별도 전환 작업에서만 사용한다.

다음 작업에는 이 폴더를 읽지 않는다.

- MSTR_ODS 원천으로 만드는 신규 Streamlit
- 현재 ODS 회원·후원·납입·발송 분석
- ODS 테이블 간 JOIN 및 지표 정의

DW 자료가 추가되더라도 다음 규칙을 지킨다.

- 업무 의도 설명용으로만 사용한다.
- Snowflake 실행 원천으로 사용하지 않는다.
- DW 숫자에 맞추기 위해 ODS 값을 보정하지 않는다.
- 월마감 Snapshot과 현재 ODS 재계산의 차이를 명확히 표시한다.


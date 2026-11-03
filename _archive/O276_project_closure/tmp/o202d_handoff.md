## O202-D 인수인계

완료
- /부서별agent답변.md (38문항, 3개 부서) 작성
- SEND_STATUS2 제거 (파일 쪽 처리 완료)
- 12_agent개선과제/ 생성: 00_작업계획.md (T1~T9), 01_회원실_테스트_피드백.md
- 실측: GOLD 객체 66개 중 SV 참조 33개. 미배선 테이블 22개 (WIDE 11개는 BI용이라 미배선이 정상). ML_FEATURE_IMPORTANCE_V 정상 조회(22행)
- ML 회원예측 중복: 원천이 1행이라고 가정 (운영계는 수정 완료)

사람이 해야 할 일
1. ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE ADD VERSION 실행 → build --select FACT_MESSAGE_DISPATCH+ 실행
2. 1번이 끝나면 agent가 ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH DROP COLUMN SEND_STATUS2 실행 → D6 기록

다음 세션: 12_ 계획 T1·T6·T7부터 착수
입력 대기: 기획실 회비예측 산식, 테스터 역할명, MSTR tool A/B/C안

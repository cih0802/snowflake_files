## O255-A — DEC-63 현재 부서 귀속 재현 문서화 · SV_MEMBER_SPONSOR_BIZ 배선 · 배포순서 파일명 정리 (2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시 · 확정위반 1)

- 요청 = 중단된 현업 요건 dbt 작업(O252 · DEC-63) 할 일 정리 → 작업 진행 · gold/silver/sv DDL 과 문서실행순서 3종에 재현 가능하게 기록 · 05 폴더 배포순서 SQL 파일명에서 작업번호 제거.
- 라벨 = O254-B 예고 O255 · 원장 rc=1(미사용) 확인 후 선점 등재.
- 독해 = 지침 1~312 · `00_BRIEF` 1~138 · 인수인계 O0254-A 1~55 · O0254-B 1~45 · O0252-A 1~58 · 이력-089 전량 · DIM_ORG_SUCCESSION.sql 1~166 · evidence.md 1~64 · 05_10 전량 · 문서실행순서 3종 전량 · read 미반환 0 · 재호출 0.
- SV = 05_10 에 org_succ(GOLD.DIM_ORG_SUCCESSION · UNIQUE OLD_DEPT_ID) · 차원 5 · STOP_REGISTRATIONS · 규칙 (5) · VQR 1 → 개발계 14/14 · 합계 1,381,827 = 1,381,827 · 2026 현재 부서별 129,707.
- 배포순서 = 신규 `37_DEPLOY_ORG_SUCCESSION.sql` 개발계 10/10(D1 IF NOT EXISTS 무해 · D3 대사 = 1,314·0·연도별 일치) · 실행순서 「기존 환경 갱신」 29~31 · llm §3.6 · 보조주석 절.
- 파일명 = 27~36 9건 `NN_DEPLOY_<주제>.sql`(SHA 동일 · 마운트·스테이지 두 축 확인) · 현행 문서 참조 26건 치환 · 이력 문서 미수정 · 21~26 은 scripts 9종 하드코딩으로 보류.
- 🟠 확정위반 1 = R1-7-8 원장 edit 앵커가 O254 행 머리를 포함 → 행 병합 · 즉시 복구 · index_row_gate PASS.
- 기타 = 전수 참조 스캔 rc=143 2회(마운트 대용량) → 백그라운드 중단 후 경로 분해 grep 으로 재판정 · rename 1건 🔴 = 목록 지연(해시 재확인으로 정상).
- 정본 3곳 = 원장 O255 행 · 이 항목 · 인수인계 O0255-A · O0255-B.
- O255-B = 사용자 결정 4건: 36 분리 불필요(O250-E 정본 분리 완료) · `dbt_build_fact_ad_performance_budget.sql` 을 16번 정의로 복원(O248 build 는 개발·운영계 기반영) · 80 재빌드 승인(다음 세션) · 05_10 `CUR_ORG_PATH` 차원 추가(14/14 · docx 3번 표 일치) · 롤오버 승인.
- 🟠 기타 = heredoc + `</dev/null` 로 python 미실행 1회(O252·O253 와 같은 함정 · edit 도구로 대체).

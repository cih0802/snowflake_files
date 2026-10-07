USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
USE ROLE GN_DW_DBT;

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select WIDE_MEMBER_SERVICE_COHORT';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

SELECT 20261007;
-- USE ROLE ACCOUNTADMIN;
-- DROP DATABASE GN_DW;

use role gn_dw_analyst;
use warehouse gn_dw_analytics_wh;
SELECT COUNT(DISTINCT STRD_MT) loaded, MAX(CASE WHEN STRD_MT < '202601' THEN STRD_MT END) last_hist, COUNT(*) rows_ FROM GN_DW.MSTR.F_MM_SPNSR_DVLP;



📢 Cortex Agent 개선 작업 내용 (2~4차 통합 요약)
1. 데이터 마트 및 파이프라인(dbt/SQL) 개선

신규 마트 구축: 알림톡/메시지 발송 효과 분석을 위한 서비스 수신 코호트 마트 신설
원천 데이터 오류 보정:
캠페인 행사 일자 변환 오류(1970년대 표기 버그) 형식 수정
장기회원 서비스 제목 변경 패턴 보정(2026년 감사서비스 수신 모수 정상화)
MSTR 일일 적재 파이프라인 정비: 매일 아침 최신 실적이 자동 반영되도록 일일 적재 Task 설계
2. 시맨틱 뷰(Semantic View) 및 지표 정본화

MSTR 개발 실적 단일 정본 체계 구축: 분산되어 있던 개발 실적(건수/인원/금액) 로직을 MSTR 기준으로 통일
분석 축 확장: 획득 캠페인 8대 분석 축(유입경로, 카테고리 등) 및 MSTR 주요 축(후원기간대, 결제수단 등 12개 축) 신규 노출
목표/추세 지표 신설: 부서별 월/연 목표 전용 뷰 및 연도말 개발 실적 추세 뷰 추가 배선
3. Agent 라우팅 및 아키텍처 통합

Agent 구조 단순화: 독립 운영되던 AGENT_MSTR을 정리하고, 기존 3대 Agent(회원/마케팅/경영)가 MSTR 정본 도구를 직접 호출하도록 통합
라우팅 정확도 개선: '개발 실적' 관련 질문은 MSTR 정본 도구로, '교차/세부 분석'은 DW 도구로 자동 분기 처리
4. LLM 답변 품질 및 수치 검증 강화

표 헤더 한글 표준화: 전 Agent 및 서빙 뷰의 출력 컬럼명을 100% 한글 표준으로 강제
수치 환각(Hallucination) 방지: LLM의 임의 덧셈/연산을 금지하고, SQL 단에서 ROLLUP 및 중복제거(COUNT DISTINCT)를 수행하도록 프롬프트/규칙 고도화
답변 포맷 일관성 확보: 영문 사고문 노출 차단, 불필요한 반복 답변 제거, 결론 → 표 → 산식 형태의 응답 규격 적용
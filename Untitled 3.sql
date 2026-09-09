SELECT * FROM GN_DW.GOLD.DIM_MEMBER;
SELECT * FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

SELECT * FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG LIMIT 100;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE accountadmin;

select * from gn_dw.bronze_crm.TM_CM_MKTNG_UTM limit 10;


/*
@(skill:init_ihcho) 
1. `20_issue` 폴더의 문서들을 읽어 배경과 요구사항을 파악합니다.
2. 현재 세션의 전체 채팅 트랜스크립트를 `cortex conversations transcript`로 추출하고, `'/scripts/'` 폴더에 관련 제네레이터가 있는 경우 작업 조건 부합 여부 및 최신성(stale 여부)을 검토합니다.
3. 위 문서와 트랜스크립트를 바탕으로, 이번 세션에서 수행한 작업(실행한 SQL, 수정한 코드, 내린 판정)에 논리적 모순, 규칙 위반, 누락이 없는지 비판적으로 자기 검토합니다.
4. 승인이 필요한 작업은 모두 승인된 것으로 처리하고, 검토 결과를 바탕으로 작업물과 문서들을 최종 개선합니다.


이 세션에서 미처 처리하지 못한 작업을 파이프라인 프로세스 순과 중요도 순으로 표로 정리해서 보여주고, 다음 세션에서 이 작업들을 진행하도록 복붙 가능한 프롬프트 블록으로 만들어줘.
*/

show grants to role gn_dw_engineer;

agent 테스트 결과 요약


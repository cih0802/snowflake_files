SELECT * FROM GN_DW.GOLD.DIM_MEMBER;
SELECT * FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

SELECT * FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG LIMIT 100;

--snow dbt execute --project-dir 10_dbt_pipeline -- run --select FACT_MEMBER_SPONSOR_BIZ
;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE accountadmin;

select * from gn_dw.bronze_crm.TM_CM_MKTNG_UTM limit 10;


/*
오늘 진행된 세션들의 목표는, issue폴더 문서들과 next_session 문서를 읽고 작업을 진행할 때 불필요하게 많은 컨텍스트를 읽어서 작업 정확도가 떨어지는걸 잡아내려는 목표였어. 그에 대한 접근방법으로, 문서 양을 줄이거나 허브 문서의 매핑을 효율적으로 진행하는 작업을 진행했어. 이 목표를 달성했는지, 이전과 어떤 차이가 있는지 알려줘.

이슈문서들을 읽고 이번 세션에서 진행한 작업을 비판적으로 검토하고, 승인이 필요한 작업은 전부 승인하니, 작업과 문서들을 개선해줘.

지금 생성된걸 보니까 gold 스키마의 것들만 있는데, 내가 원하는건 bronze > silver > gold로 어떻게 넘어오냐거든. 이건 어렵나? 용량문제면, gold 스키마의 테이블별 html 문서가 생성되어도 좋다. 이 경우 erd 폴더를 생성하고 그 안에 만들어줘.

이번 세션에서 해결하지 못한 이슈들을 파이프라인 프로세스 순과 중요도 순으로 표로 정리해서 보여주고, 다음 세션에서 이 작업들을 진행하도록 복붙 가능한 프롬프트 블록으로 만들어줘.
*/
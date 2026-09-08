SELECT * FROM GN_DW.GOLD.DIM_MEMBER;
SELECT * FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS;

SELECT * FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG LIMIT 100;

--snow dbt execute --project-dir 10_dbt_pipeline -- run --select FACT_MEMBER_SPONSOR_BIZ
;
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

총 테스트 문항: 29문항
Cortex Analyst SQL 생성 성공: 28건 / 29건 (96.6%)
생성된 SQL Live 실행 성공: 28건 / 28건 (100.0% 성공)
미생성 1건(K9): SV_MEMBER_COHORT(유지기간·이탈률)와 SV_MEMBER_FEE(납입회비) 2개 팩트가 필요한 복합 질의로, Cross-Fact 가드레일에 의해 정상 거부됨 (단일 뷰 분리 질의 시 정상 응답).

;;
-- [2-1. I-2] 행사 참여상태 및 특수문자 ')' 침투 행 확인
SELECT
    *
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE mber_no = ')' OR partcpt_chnnl_cd = ')' OR partcpt_path_cd = ')'
   OR partcpt_stat_cd = ')' OR rm = ')' OR rm2 = ')'
ORDER BY 1;

-- SELECT count(*)
select *
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL
WHERE MBER_NO NOT REGEXP '^[0-9]{7}$'         -- 7자리 숫자가 아님
  AND MBER_NO NOT REGEXP '^S0[0-9]{7}$';     -- S0으로 시작하는 9자리가 아님 (S0 + 7자리)

select *
-- from GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
from GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO
WHERE 1=1
  -- and MBER_NO NOT REGEXP '^[0-9]{7}$'         -- 7자리 숫자가 아님
  AND ONCE_MBER_NO NOT REGEXP '^S0[0-9]{7}$';     -- S0으로 시작하는 9자리가 아님 (S0 + 7자리)

-- [2-6. N-8] MKTG_UTM 고아코드 192번 캠페인 점유율
SELECT
    c.mktg_utm AS "캠페인_UTM코드",
    u.mk_utm_nm AS "사전_라벨",
    CASE WHEN u.mk_utm IS NULL THEN '🔴 사전 미등재(고아)' ELSE '정상 매칭' END AS "사전등재여부",
    COUNT(*) AS "캠페인수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS "비율_PCT"
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM u
    ON u.mk_utm = c.mktg_utm
GROUP BY 1, 2, 3
ORDER BY 4 DESC;



-- [3-1. A] 회비월(MBRFEE_MT) 자리수 및 5자리 비정상 값 실측
SELECT
    LENGTH(mbrfee_mt) AS "자리수",
    COUNT(*) AS "행수",
    COUNT(DISTINCT mbrfee_mt) AS "값종류수",
    MIN(mbrfee_mt) AS "최소값",
    MAX(mbrfee_mt) AS "최대값"
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
GROUP BY 1
ORDER BY 1;

-- [3-3. E] 행사 참여 외래키 고아행(행사 마스터 부재) 비율
SELECT '일반행사 TD_MS_EVENT_PRTCPNT_DTL' AS "참여원천",
    COUNT(*) AS "참여행_전체",
    COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) AS "고아행_마스터부재",
    ROUND(COUNT(CASE WHEN e.event_cd IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS "고아비율_PCT"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_EVENT e
    ON p.event_cd = e.event_cd
UNION ALL
SELECT '캠페인행사 TD_MS_CRMN_PRTCPNT',
    COUNT(*),
    COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END),
    ROUND(COUNT(CASE WHEN c.crmn_cd IS NULL THEN 1 END) * 100.0 / COUNT(*), 2)
FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT p
LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_CRMN c
    ON p.crmn_cd = c.crmn_cd;

-- [3-4. B] 행사 참여 회원번호의 회원 마스터 부재 회원수
SELECT
    CASE
        WHEN REGEXP_LIKE(p.mber_no, '^[0-9]{7}$') THEN '정상 7자리 FDRM'
        WHEN REGEXP_LIKE(p.mber_no, '^S[0-9]{8}$') THEN 'ONCE S+8자리'
        WHEN LENGTH(p.mber_no) <= 2 THEN '짧은/비정상 ID'
        ELSE '기타'
    END AS "유형",
    COUNT(DISTINCT p.mber_no) AS "마스터부재_회원번호수",
    COUNT(*) AS "참여행수"
FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
WHERE NOT EXISTS (
        SELECT 1 FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO m
        WHERE m.mber_no = p.mber_no)
  AND NOT EXISTS (
        SELECT 1 FROM GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO o
        WHERE o.once_mber_no = p.mber_no)
GROUP BY 1
ORDER BY 2 DESC;



-- [2-6. N-8] MKTG_UTM 고아코드 192번 캠페인 점유율
SELECT
    c.mktg_utm AS "캠페인_UTM코드",
    u.mk_utm_nm AS "사전_라벨",
    CASE WHEN u.mk_utm IS NULL THEN '🔴 사전 미등재(고아)' ELSE '정상 매칭' END AS "사전등재여부",
    COUNT(*) AS "캠페인수",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS "비율_PCT"
FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_MKTNG_UTM u
    ON u.mk_utm = c.mktg_utm
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
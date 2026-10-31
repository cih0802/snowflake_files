-- GN_DW.BRONZE_AGENCY 스키마 내의 DIGITAL_ADS_FILE 스테이지 이용
-- 2024-2026_ADS_OPER_DETAIL.csv 파일 참고 
-- 원천 데이터의 연도, 예산출처, 캠페인 유형, 광고 유형, 월, 기기, 매체, 주차, 일자, 요일, 캠페인명, 소재 등의 광고 운영 정보를 매핑한다.
-- 소재유형, 노출수, 클릭수, 광고비, 후원자 수, 전환가치, UTM 캠페인명, 마크업 금액, 부가세 금액, 최종 정산금액 등의 광고 성과 및 비용 정보를 적재한다.
-- 원천 데이터에서 제공되지 않는 CPA, DEV_UNIT_PRICE, CTR, CVR, CPC, CPM, VTR, CRM 개발건수, 광고그룹명 등은 NULL로 처리한다.
-- FORCE = TRUE 옵션을 적용하여 동일 파일에 대한 적재 여부와 관계없이 강제 적재한다.
-- 적재 후 연도는 YYYY 형식으로, 월은 01월 → 1과 같이 숫자형 월 값으로 변환하고, 주차는 첫 번째 문자 기준으로 정규화한다.
-- 최종적으로 광고 운영 상세 데이터를 표준화하여 DGT_AD_CMPGN_DTLS에서 광고 운영 및 성과 분석에 활용할 수 있도록 관리한다.

COPY INTO GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
FROM (
SELECT
    NULL, $1, $2, SPLIT_PART($3, ' ', 1), REGEXP_REPLACE($3, '^[^ ]+[ ]*', ''),-- 시간 / 연도/ 예산출처 / 캠페인유형1 / 캠페인유형2
    $3, $4, $5, $6, $7, -- 캠페인유형 / 광고유형 / 월 / 기기 / 매체
    $8, $9, $10, $11, $12, -- 주차 /	일자 / 	요일 /	캠페인명	/ 소재
    $13, $14, $15, $16, $17, --소재유형	/ 노출수 / 클릭수 / 광고비 /후원자 수(명)
    $18, NULL, NULL, NULL, NULL, -- 전환가치(건) / CPA / DEV_UNIT_PRICE / CTR / CVR
    NULL, NULL, $20, NULL, NULL, -- CPC / CPM / UTM_CMPGN_NM / READ_CNT / MEDIA_PTNT_CUST_CNT
    NULL, NULL, NULL, NULL, NULL,  --DATE / VTR / PAGE_TYPE_NM / CRM_DVLP_CNT / AD_GRP_NM
    NULL,    -- GRP_DIV_NM
    $19, $21, $22, NULL, NULL --MARKUP_AMT  / VAT_AMT / LAST_STMT_AMT / TOTAL_CPA / TOTAL_DVLP_UNIT_PRICE 260917 추가
FROM @GN_DW.BRONZE_AGENCY.DIGITAL_ADS_FILE
(FILE_FORMAT => 'GN_DW.BRONZE_AGENCY.GN_CSV_FORMAT', PATTERN => '.*2024-2026_ADS_OPER_DETAIL\\.csv')
) FORCE = TRUE;


-- MONTH 값 변환: '01월' → '1', '12월' → '12'
UPDATE GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
SET     
    YEAR = SUBSTR(YEAR, 0, 4),
    MONTH = CAST(REPLACE(MONTH, '월', '') AS INT)::VARCHAR,
    WEEK = SUBSTR(WEEK, 0, 1)

-- 기존 데이터 업데이트 수식. 
UPDATE GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
SET     
    TOTAL_CPA = LAST_STMT_AMT / NULLIF(SPNSER_MBER_CNT, 0), --   => 통합 CPA = 최종정산금액 ÷후원자 수(명)
    TOTAL_DVLP_UNIT_PRICE = LAST_STMT_AMT / NULLIF(CONV_VU_CNT, 0), --   => 통합 개발단가 = 최종정산금액 ÷ 전환가치(건)
    CPA = AD_COST / NULLIF(SPNSER_MBER_CNT, 0), --   => CPA: 광고비 ÷ 후원자 수(명)
    DVLP_UNIT_PRICE = AD_COST / NULLIF(CONV_VU_CNT, 0), --  => 개발단가: 광고비 ÷ 전환가치(건)
    CPC = AD_COST / NULLIF(CLICK_CNT, 0),  -- => CPC = 광고비÷ 클릭수
    CPM = (AD_COST / NULLIF(EXPS_CNT, 0)) * 1000-- => CPM = 광고비 ÷ 노출수 × 1,000
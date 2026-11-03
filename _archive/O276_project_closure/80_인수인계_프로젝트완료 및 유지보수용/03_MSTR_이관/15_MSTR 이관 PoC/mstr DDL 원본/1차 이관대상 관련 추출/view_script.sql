CREATE VIEW [mart].[D_DVLP_DIV_CD] AS
SELECT   
 DTL_CD_ID  DVLP_DIV_CD
,DTL_CD_NM  DVLP_DIV_NM
,SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMMN_DTL_CD]
WHERE CD_ID = 'MM015'
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_STRD_DE_CD] AS
SELECT 
      YMD                                                STRD_DE ,                   -- 일자ID,
	  CONVERT( CHAR(10), SYMD, 121)                      STRD_NM ,
      CONVERT( CHAR(8), DATEADD(DAY  , -1, SYMD ) ,112)  STRD_PRE_DE ,               -- 전일자ID,
      CONVERT( CHAR(8), DATEADD(MONTH, -1, SYMD ) ,112)  STRD_PRE_MT_DE ,            -- 전월동일자ID,
      CONVERT( CHAR(8), DATEADD(YEAR , -1, SYMD ) ,112)  STRD_PRE_YMT_DE ,           -- 전년동월동일자ID,
      LEFT( YMD, 6) 									 STRD_MT ,                   -- 년월ID
      QQ 												 STRD_QT ,                   -- 쿼터ID
      YY 												 STRD_YY ,                   -- 년ID
      MM 												 MT_ID ,                     -- 월ID
	  CONVERT(CHAR(8), GETDATE() , 112)  		         WORK_DE                   -- 작업일자
   FROM MART.D_STRD_CAL_CD
    WHERE 1 = 1
	AND  YMD < '99991231'
	
UNION ALL	
SELECT 
      YMD                                                STRD_DE ,                   -- 일자ID,
	  'N/A'                     STRD_NM ,
      CONVERT( CHAR(8), DATEADD(DAY  , -1, SYMD ) ,112)  STRD_PRE_DE ,               -- 전일자ID,
      CONVERT( CHAR(8), DATEADD(MONTH, -1, SYMD ) ,112)  STRD_PRE_MT_DE ,            -- 전월동일자ID,
      CONVERT( CHAR(8), DATEADD(YEAR , -1, SYMD ) ,112)  STRD_PRE_YMT_DE ,           -- 전년동월동일자ID,
      LEFT( YMD, 6) 									 STRD_MT ,                   -- 년월ID
      QQ 												 STRD_QT ,                   -- 쿼터ID
      YY 												 STRD_YY ,                   -- 년ID
      MM 												 MT_ID ,                     -- 월ID
	  CONVERT(CHAR(8), GETDATE() , 112)  		         WORK_DE                   -- 작업일자
   FROM MART.D_STRD_CAL_CD
    WHERE 1 = 1
	AND  YMD = '99991231'

GO

-- ======================================================================

CREATE VIEW [mart].[D_CPR_DIV_CD] AS
SELECT   
 DTL_CD_ID  CPR_DIV_CD
,DTL_CD_NM  CPR_DIV_NM
,SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMMN_DTL_CD]
WHERE CD_ID = 'CM019'
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_DEPT4_CD] AS
SELECT    
         B.DEPT_ID DEPT4_ID,
         B.DEPT_NM DEPT4_NM,
         A.DEPT_ID DEPT5_ID,
         B.SORT_ORDR    SORT_ORDR,                 -- 정렬순서
		 B.USE_YN 	    USE_YN ,                   -- 사용여부
		 B.ACMSLT_DEPT_YN ACMSLT_DEPT_YN ,           -- 실적부서여부YN ,
		 ISNULL( CONVERT( CHAR(8), B.FRST_REGIST_DT ,112),'19000101')  FST_DE,
		 ISNULL( CONVERT( CHAR(8), B.LAST_UPDT_DT ,112),'99991231')   LST_DE,		 
		 CONVERT( CHAR(8), GETDATE(), 112)  WORK_DE                  -- 작업일자
	FROM  MART.D_CM_DEPT_INFO	A
	JOIN  MART.D_CM_DEPT_INFO	B
	  ON  B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID 
	WHERE A.UPPER_DEPT_ID = 'ZV000000' 
	AND   A.USE_YN ='Y'
	UNION ALL 
	SELECT 'Z~' , '없음' ,'Z~' ,999,'Y','Y','20191101','99991231',CONVERT( CHAR(8), GETDATE(), 112)
GO

-- ======================================================================

CREATE VIEW [mart].[D_DEPT_CD] AS
SELECT    
         E.DEPT_ID,
         E.DEPT_NM,
		 D.DEPT_ID DEPT2_ID,
         C.DEPT_ID DEPT3_ID,
         B.DEPT_ID DEPT4_ID,
         A.DEPT_ID DEPT5_ID,
         E.SORT_ORDR    SORT_ORDR,                 -- 정렬순서
		 E.USE_YN 	    USE_YN ,                   -- 사용여부
		 E.ACMSLT_DEPT_YN ACMSLT_DEPT_YN ,           -- 실적부서여부YN ,
		 ISNULL( CONVERT( CHAR(8), E.FRST_REGIST_DT ,112),'19000101')  FST_DE,
		 ISNULL( CONVERT( CHAR(8), E.LAST_UPDT_DT ,112),'99991231')   LST_DE,
		 CONVERT( CHAR(8), GETDATE(), 112)  WORK_DE                  -- 작업일자
	FROM  MART.D_CM_DEPT_INFO	A
	JOIN  MART.D_CM_DEPT_INFO	B
	  ON  B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID 
	JOIN  MART.D_CM_DEPT_INFO	C
	  ON  C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
    JOIN  MART.D_CM_DEPT_INFO	D
	  ON  D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
    JOIN  MART.D_CM_DEPT_INFO	E
	  ON  E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
	WHERE A.UPPER_DEPT_ID = 'ZV000000' 
	AND   A.USE_YN ='Y'
	AND   C.DEPT_ID != 'ZC000029'	
	UNION ALL 
	SELECT 'Z~' , '없음','Z~' ,'Z~' ,'Z~' ,'Z~' ,999,'Y','Y','20191101','99991231',CONVERT( CHAR(8), GETDATE(), 112)
GO

-- ======================================================================

CREATE VIEW [mart].[D_DEPT3_CD] AS
SELECT    
         C.DEPT_ID DEPT3_ID,
         C.DEPT_NM DEPT3_NM,
		 B.DEPT_ID DEPT4_ID,
         A.DEPT_ID DEPT5_ID,
         C.SORT_ORDR    SORT_ORDR,                 -- 정렬순서
		 C.USE_YN 	    USE_YN ,                   -- 사용여부
		 C.ACMSLT_DEPT_YN ACMSLT_DEPT_YN ,           -- 실적부서여부YN ,
		 CONVERT( CHAR(8), GETDATE(), 112)  WORK_DE                  -- 작업일자
	FROM  MART.D_CM_DEPT_INFO	A
	JOIN  MART.D_CM_DEPT_INFO	B
	  ON  B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID 
	JOIN  MART.D_CM_DEPT_INFO	C
	  ON  C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
	WHERE A.UPPER_DEPT_ID = 'ZV000000' 
	AND   A.USE_YN ='Y'
	AND   C.DEPT_ID != 'ZC000029'	
	UNION ALL 
	SELECT 'Z~' , '없음' ,'Z~' ,'Z~' ,999,'Y','Y',CONVERT( CHAR(8), GETDATE(), 112)
GO

-- ======================================================================

CREATE VIEW [mart].[D_UP_CMPGN_CD] AS
SELECT   
 CMPGN_CD  UPPER_CMPGN_CD
,CMPGN_NM  UPPER_CMPGN_NM
,ROW_NUMBER() OVER( ORDER BY CMPGN_CD ) SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMPGN_CD]
WHERE UPPER_CMPGN_YN = 'Y' 
UNION ALL 
SELECT   
 'Z~'   UPPER_CMPGN_CD
,'없음'   UPPER_CMPGN_NM
,99999  SORT_ORDR  
,'Y'    USE_YN  


;
GO

-- ======================================================================

CREATE VIEW [mart].[D_SEX_CD] AS
SELECT   
 DTL_CD_ID  SEX_CD
,DTL_CD_NM  SEX_NM
,SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMMN_DTL_CD]
WHERE CD_ID = 'CM013'
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_AGE_TERM_CD] AS
SELECT   
 DTL_CD_ID  AGE_TERM_CD
,DTL_CD_NM  AGE_TERM_NM
,SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMMN_DTL_CD]
WHERE CD_ID = 'CM014'
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_DEPT2_CD] AS
SELECT    
         D.DEPT_ID DEPT2_ID,
         D.DEPT_NM DEPT2_NM,
		 C.DEPT_ID DEPT3_ID,
         B.DEPT_ID DEPT4_ID,
         A.DEPT_ID DEPT5_ID,
         D.SORT_ORDR    SORT_ORDR,                 -- 정렬순서
		 D.USE_YN 	    USE_YN ,                   -- 사용여부
		 D.ACMSLT_DEPT_YN ACMSLT_DEPT_YN ,           -- 실적부서여부YN ,
		 ISNULL( CONVERT( CHAR(8), D.FRST_REGIST_DT ,112),'19000101')  FST_DE,
		 ISNULL( CONVERT( CHAR(8), D.LAST_UPDT_DT ,112),'99991231')   LST_DE,
		 CONVERT( CHAR(8), GETDATE(), 112)  WORK_DE                  -- 작업일자
	FROM  MART.D_CM_DEPT_INFO	A
	JOIN  MART.D_CM_DEPT_INFO	B
	  ON  B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID 
	JOIN  MART.D_CM_DEPT_INFO	C
	  ON  C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
    JOIN  MART.D_CM_DEPT_INFO	D
	  ON  D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
	WHERE A.UPPER_DEPT_ID = 'ZV000000' 
	AND   A.USE_YN ='Y'
	AND   C.DEPT_ID != 'ZC000029'	
	UNION ALL 
	SELECT 'Z~' , '없음','Z~' ,'Z~' ,'Z~' ,999,'Y','Y','20191101','99991231',CONVERT( CHAR(8), GETDATE(), 112)
GO

-- ======================================================================

CREATE VIEW [mart].[D_PR_MTH_CD] AS
SELECT   
 DTL_CD_ID  PR_MTH_CD
,DTL_CD_NM  PR_MTH_NM
,SORT_ORDR  
,USE_YN  
FROM   [MART].[D_CMMN_DTL_CD]
WHERE CD_ID = 'CM008'
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_STRD_MT_CD] AS
SELECT DISTINCT 
       LEFT( YMD , 6) STRD_MT ,                                                        -- 년월ID
	   CONVERT( CHAR(7),  SYMD , 121) STRD_NM,                             -- 년월명 
       CONVERT( CHAR(6) , DATEADD( MONTH ,-1,  SYMD ) , 112) PRE_STRD_MT ,			   -- 전월ID
	   CONVERT( CHAR(6) , DATEADD( YEAR  ,-1,  SYMD ) , 112) PRE_YY_STRD_MT ,		   -- 전년동월ID
	   YY STRD_YY,																			   -- 년ID
	   QQ STRD_QT,																			   -- 쿼터ID
	   MM STRD_MM,																			   -- 월ID
	   CONVERT( CHAR(4) , DATEADD( YEAR  ,-1,  SYMD ) , 112) + '12'   PRE_YY_12_MT ,   -- 전년12월
	   CONVERT( CHAR(4) , DATEADD( YEAR  ,-2,  SYMD ) , 112) + '12'  PPRE_YY_12_MT 	   -- 전전년12월
 FROM  [MART].[D_STRD_CAL_CD]
 WHERE 1 = 1 
;
GO

-- ======================================================================

CREATE VIEW [mart].[D_SPNSR_BSNS_V] AS
SELECT 
     CONVERT( CHAR(6),FRST_REGIST_DT,112) STRD_MT
    ,A.SPNSR_NO
	,SPNSR_BSNS_NO
	,SPNSR_BSNS_ID
	,MBER_NO
	,CMPGN_CD
	,ACMSLT_DEPT_CD
	,JOIN_PATH_CD
	,FRST_RGSTR_ID
	,CONVERT( CHAR(8),FRST_REGIST_DT,112) FST_DE
	,SPNSR_AMT
	,ISNULL( SPNSR_DSCNTC_DE ,'99991231' ) DSC_DE
	,SPNSR_DSCNTC_YN
	,SPNSR_DSCNTC_RSN_CD
  FROM  MSTR_ODS.DBO.TM_MM_FDRM_MBER_SPNSR A 
  JOIN  MSTR_ODS.DBO.TM_MM_FDRM_MBER_SPNSR_BSNS B
   ON A.SPNSR_NO = B.SPNSR_NO 
;
GO

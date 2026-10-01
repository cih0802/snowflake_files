CREATE PROCEDURE  [mart].[USP_F_MM_SPNSR_DVLP_SUM] (
	@i_ym   AS VARCHAR(6), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 
   

  BEGIN TRY 
  BEGIN TRAN	 
    SELECT 1
	WHILE @@ROWCOUNT > 0
	BEGIN
		DELETE TOP (10000)
		FROM  [MART].[F_MM_SPNSR_DVLP_SUM]  WITH( TABLOCK ) 
		WHERE STRD_MT = @i_ym 	  
	END
  
    SET @v_numrows = @@rowcount 
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Delete: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg
-----------------------------------------------------------
--JOB   : INSERT : [MART].[F_MM_SPNSR_DVLP]  
-----------------------------------------------------------	

    INSERT INTO  [MART].[F_MM_SPNSR_DVLP_SUM] 
    ( 
      STRD_MT ,                       -- 기준년월
      OCCRRNC_DE ,                    -- 발생일자
      SPNSR_NO ,                      -- 후원번호
      SPNSR_BSNS_NO ,                 -- 후원사업번호
      SER_NO ,                        -- 일련번호
      MBER_NO ,                       -- 회원번호
      ACT_DEPT_CD ,                   -- 활동부서코드
      ACMSLT_DEPT_CD ,                -- 실적부서코드
      ACMSLT_DEPT2_CD ,               -- 실적부서2코드
      ACMSLT_DEPT3_CD ,               -- 실적부서3코드
      ACMSLT_DEPT4_CD ,               -- 실적부서4코드
      CMPGN_CD ,                      -- 캠페인코드
      CMPGN_CLS1_CD ,                  -- 캠페인구분코드 희망TV
	  CMPGN_CLS2_CD ,                  -- 캠페인구분코드 희망편지쓰기 
	  CMPGN_CLS3_CD ,                  -- 캠페인구분코드 희망학교 
      UPPER_CMPGN_CD ,                -- 상위캠페인코드
      BRND_ID ,                       -- 브랜드ID
      PR_MTH_CD ,                     -- 홍보방법코드
      SPCL_CMPGN_YN ,                 -- 특정캠페인여부
	  PRE_CMPGN_CD ,                  -- 캠페인코드
      SETLE_CD ,                      -- 결제코드
      MBER_DIV_CD ,                   -- 회원구분코드
      SEX ,                           -- 성별
      AREA_CD ,                       -- 지역코드
      AGE_TERM_CD ,                   -- 연령대코드
      AGE ,                           -- 연령
      PAYER_AGE_TERM_CD ,             -- 결제자연령대코드
      SPNSR_TIME_CO ,                 -- 후원시간수
      SPNSR_TERM_MT_CNT ,             -- 후원기간월수
      SPNSR_TERM_CD ,                 -- 후원기간대코드
      SPNSR_AMT_CD ,                  -- 후원금액코드
      SPNSR_TERM2_CD ,                -- 후원기간대2코드
      SPNSR_AMT2_CD ,                 -- 후원금액2코드
      SPNSR_BSNS_ID ,                 -- 후원사업ID
	  SPNSR_BSNS2_ID ,                -- 후원사업2ID
      SPNSR_BSNS_ABRV_CD ,            -- 후원사업약칭코드
      CPR_DIV_CD ,                    -- 법인구분코드
      CANCL_RDCAMT_RSN_CD ,           -- 취소감액사유코드
      SPNSR_AMT ,                     -- 후원금액
      SPNSR_AMT_CNT ,                 -- 후원금액건수
      MT_GOAL_CNT ,                   -- 월목표후원건수
      YY_GOAL_CNT ,                   -- 년목표후원건수
      DVLP_DIV_CD ,                   -- 개발구분코드
      DVLP_CNT ,                      -- 개발구분건수
	  RDCAMT_YN ,                     -- 감액여부
      MT_ADD_SPNSR_AMT_YN ,           -- 증액여부
	  NEW_OLD_DIV_CD,                 -- 신규기존여부
      WORK_DE                         -- 작업일자
    )
    SELECT 
		  LEFT( A.OCCRRNC_DE, 6) STRD_MT ,                      
		  A.OCCRRNC_DE ,                   
		  A.SPNSR_NO ,                     
		  A.SPNSR_BSNS_NO ,                
		  A.SER_NO ,                       
		  A.MBER_NO ,                      
		  A.ACT_DEPT_CD ,                  
		  A.ACMSLT_DEPT_CD ,               
		  B.DEPT2_ID ACMSLT_DEPT2_CD ,
		  B.DEPT3_ID ACMSLT_DEPT3_CD ,
		  B.DEPT4_ID ACMSLT_DEPT4_CD ,            
		  A.CMPGN_CD ,                     
		  ISNULL( D1.CMPGN_CLS_CD,'99'  )CMPGN_CLS1_CD ,                 
		  ISNULL( D2.CMPGN_CLS_CD,'99'  )CMPGN_CLS2_CD ,                 
		  --ISNULL( D3.CMPGN_CLS_CD,'99'  )CMPGN_CLS3_CD , 
		  ISNULL( CASE WHEN H.DSC_DE > LEFT( A.OCCRRNC_DE, 6) AND H.SPNSR_BSNS_ID = '38' THEN '3' ELSE '99' END ,'99') CMPGN_CLS3_CD,
		  ISNULL( C.UPPER_CMPGN_CD,'Z~') UPPER_CMPGN_CD ,               
		  ISNULL( C.BRND_ID, 'Z~') BRND_ID ,                      
		  ISNULL( C.PR_MTH_CD,'9999') PR_MTH_CD ,                    
		  ISNULL( C.SPCL_CMPGN_YN,'N' ) SPCL_CMPGN_YN ,   
		  ISNULL( CASE WHEN  DVLP_DIV_CD = '4' AND SPNSR_AMT > 0 THEN PRE_CMPGN_CD END , '0' ) PRE_CMPGN_CD , 	  
		  A.SETLE_CD ,                     
		  A.MBER_DIV_CD ,                  
		  A.SEX ,                          
		  A.AREA_CD ,                      
		  A.AGE AS AGE_TERM_CD ,                  
		   CASE WHEN A.AGE IN ( '1','2','3','4','5','6','7','8','9' )  THEN  CONVERT( INT, LEFT( CASE WHEN A.OCCRRNC_DE < E.BRTHDY THEN  CONVERT( CHAR(8),E.FRST_REGIST_DT,112) ELSE A.OCCRRNC_DE END , 4)) - CONVERT( INT, LEFT( E.BRTHDY, 4))  ELSE 0 END   AS AGE ,
		  '0' PAYER_AGE_TERM_CD ,            
		  A.SPNSR_TIME_CO ,                
		  DATEDIFF( MONTH, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  DSC_DE END )  SPNSR_TERM_MT_CNT ,            
		  ISNULL( CASE 
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 1  THEN 1
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 5  THEN 2
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 10 THEN 3
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  >= 10 THEN 4
					ELSE '99' END, '99' )  SPNSR_TERM_CD ,                
		  A.SPNSR_AMT_CD ,                 
		  CASE WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  < 1 THEN 1 
			   WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  BETWEEN 1 AND 9  THEN  DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END ) +1
		       WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  >= 10 THEN  11
			   ELSE '999' END           	  SPNSR_TERM2_CD ,               
		  CASE   WHEN SPNSR_AMT2 < 10000  THEN '1'
				 WHEN SPNSR_AMT2 BETWEEN 10000 AND 19999 THEN  '2'
				 WHEN SPNSR_AMT2 BETWEEN 20000 AND 29999 THEN  '3'
				 WHEN SPNSR_AMT2 BETWEEN 30000 AND 39999 THEN  '4'
				 WHEN SPNSR_AMT2 BETWEEN 40000 AND 49999 THEN  '5'
				 WHEN SPNSR_AMT2 BETWEEN 50000 AND 59999 THEN  '6'
				 WHEN SPNSR_AMT2 BETWEEN 60000 AND 69999 THEN  '7'
				 WHEN SPNSR_AMT2 BETWEEN 70000 AND 79999 THEN  '8'
				 WHEN SPNSR_AMT2 BETWEEN 80000 AND 89999 THEN  '9'
				 WHEN SPNSR_AMT2 BETWEEN 90000 AND 99999 THEN  '10'
				 WHEN SPNSR_AMT2 BETWEEN 100000 AND 499999 THEN  '11'
				 WHEN SPNSR_AMT2 >= 500000 THEN  '12'
				 ELSE '999' END    SPNSR_AMT2_CD ,
		  A.SPNSR_BSNS_ID ,                
		  CASE WHEN A.SPNSR_BSNS_ID IN ('14','15','16','21','22') THEN  '4' ELSE A.SPNSR_BSNS_ID END SPNSR_BSNS2_ID ,
		  ISNULL( F.SPNSR_BSNS_ABRV_CD, '0')  SPNSR_BSNS_ABRV_CD ,           
		  ISNULL( F.CPR_DIV_CD ,'0') CPR_DIV_CD ,                   
		  CANCL_RDCAMT_RSN_CD ,          
		  SPNSR_AMT ,                    
		  SPNSR_AMT / 10000.0  AS SPNSR_AMT_CNT ,                
		  ISNULL( G.GOAL_CNT, 0 ) MT_GOAL_CNT ,                  
		  ISNULL( G.YYAMT, 0)  YY_GOAL_CNT ,                  
		  DVLP_DIV_CD ,                  
		  1 DVLP_CNT ,   
		  CASE WHEN DVLP_DIV_CD = '3' THEN 'Y' ELSE 'N' END RDCAMT_YN ,                     -- 감액여부
		  CASE WHEN DVLP_DIV_CD = '2' THEN 'Y' ELSE 'N' END MT_ADD_SPNSR_AMT_YN ,           -- 증액여부	  
		  CASE when substring( A.OCCRRNC_DE,1,4) =  substring( convert(char(10), E.FRST_REGIST_DT ,23),  1,4) then '1' else '2' end NEW_OLD_DIV_CD, --신규기존구분추가요청(KMY 20200519) 
		  CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM FN_MM_SPNSR_DVLP( @i_ym )       A
	LEFT OUTER JOIN [MART].[D_DEPT_CD]   B
	  ON A.ACMSLT_DEPT_CD = B.DEPT_ID  
    LEFT OUTER JOIN MART.D_CMPGN_CD      C
	  ON A.CMPGN_CD = C.CMPGN_CD
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D1 
      ON A.CMPGN_CD = D1.CMPGN_CD	  
	 AND D1.CMPGN_CLS_CD = '1'
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D2
      ON A.CMPGN_CD = D2.CMPGN_CD	    
	 AND D2.CMPGN_CLS_CD = '2' 
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D3 
      ON A.CMPGN_CD = D3.CMPGN_CD	    
	 AND D3.CMPGN_CLS_CD = '3' 
    LEFT OUTER JOIN MSTR_ODS.DBO.TM_MM_FDRM_MBER_INFO   E
	  ON A.MBER_NO = E.MBER_NO 
	LEFT OUTER JOIN MART.D_SPNSR_BSNS_INFO F 
	  ON A.SPNSR_BSNS_ID = F.SPNSR_BSNS_ID 
	LEFT OUTER JOIN ( SELECT SUM( GOAL_CNT) OVER ( PARTITION BY STDYY, DEPT_ID ,MBER_DVLP_DIV_CD ) YYAMT ,*
                        FROM [MART].[D_MBER_DVLP_GOAL_CD] 
			        ) G
	  ON A.ACMSLT_DEPT_CD =  G.DEPT_ID 
	 AND LEFT( A.OCCRRNC_DE, 6)  = G.STDYY + G.STDR_MT
     AND A.DVLP_DIV_CD = G.MBER_DVLP_DIV_CD  
	--LEFT OUTER JOIN FN_MM_ACT_DATE (@i_ym ) H 
	--  ON A.MBER_NO = H.MBER_NO 
	LEFT OUTER JOIN ( SELECT SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, FST_DE, DSC_DE  FROM  MART.D_SPNSR_BSNS_V ) H 
	  ON A.SPNSR_NO = H.SPNSR_NO 
	 AND A.SPNSR_BSNS_NO = H.SPNSR_BSNS_NO  
	LEFT OUTER JOIN (
		SELECT  SUM( SPNSR_AMT ) OVER ( PARTITION BY SPNSR_NO, SPNSR_BSNS_NO   ) SPNSR_AMT2 ,SPNSR_NO, SPNSR_BSNS_NO, STRD_MT ,DVLP_DIV_CD DVLP_DIV_CD2
		  FROM ( 
					SELECT 
							  ROW_NUMBER() OVER ( PARTITION BY  SPNSR_NO, SPNSR_BSNS_NO  ORDER BY SER_NO ) RNUM,   *
						FROM  MART.F_MM_SPNSR_DVLP
						WHERE 1 =1 --STRD_MT = @i_ym 
						AND   DVLP_DIV_CD IN ( '1', '2', '4' ) 
						AND   ISNULL( CANCL_RDCAMT_RSN_CD ,'999' ) = '999'
				) A
		WHERE RNUM = 1
    ) I	
	ON A.SPNSR_NO = I.SPNSR_NO 
	AND A.SPNSR_BSNS_NO = I.SPNSR_BSNS_NO 
	AND A.STRD_MT >= I.STRD_MT 
	AND A.DVLP_DIV_CD >= I.DVLP_DIV_CD2
   WHERE A.STRD_MT = @i_ym 		  

    SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

/*
   UPDATE MART.F_MM_SPNSR_DVLP_SUM 
      SET SPNSR_AMT2_CD = CASE  WHEN SPNSR_AMT2 < 10000  THEN '1'
								WHEN SPNSR_AMT2 BETWEEN 10000 AND 19999 THEN  '2'
								WHEN SPNSR_AMT2 BETWEEN 20000 AND 29999 THEN  '3'
								WHEN SPNSR_AMT2 BETWEEN 30000 AND 39999 THEN  '4'
								WHEN SPNSR_AMT2 BETWEEN 40000 AND 49999 THEN  '5'
								WHEN SPNSR_AMT2 BETWEEN 50000 AND 59999 THEN  '6'
								WHEN SPNSR_AMT2 BETWEEN 60000 AND 69999 THEN  '7'
								WHEN SPNSR_AMT2 BETWEEN 70000 AND 79999 THEN  '8'
								WHEN SPNSR_AMT2 BETWEEN 80000 AND 89999 THEN  '9'
								WHEN SPNSR_AMT2 BETWEEN 90000 AND 99999 THEN  '10'
								WHEN SPNSR_AMT2 BETWEEN 100000 AND 499999 THEN  '11'
								WHEN SPNSR_AMT2 >= 500000 THEN  '12'
								ELSE '999' END    
    FROM  MART.F_MM_SPNSR_DVLP_SUM  A
  	JOIN   (
			SELECT  SUM( SPNSR_AMT ) OVER ( PARTITION BY STRD_MT,SPNSR_NO, SPNSR_BSNS_NO  ,  DVLP_DIV_CD  ) SPNSR_AMT2 , STRD_MT, SPNSR_NO, SPNSR_BSNS_NO ,DVLP_DIV_CD
			  FROM ( 
						SELECT 
								ROW_NUMBER() OVER ( PARTITION BY   SPNSR_NO, SPNSR_BSNS_NO ,DVLP_DIV_CD  ORDER BY SER_NO   ) RNUM,   *
						  FROM  MART.F_MM_SPNSR_DVLP
						  WHERE 1 = 1 
						  AND   DVLP_DIV_CD IN ( '1', '2', '4' ) 
						  AND   ISNULL( CANCL_RDCAMT_RSN_CD ,'999' ) = '999'
					) A
			WHERE RNUM = 1
            ) I	
	 ON  A.SPNSR_NO = I.SPNSR_NO 
	AND  A.SPNSR_BSNS_NO = I.SPNSR_BSNS_NO
	AND  CASE WHEN A.DVLP_DIV_CD = 1
	WHERE A.STRD_MT = @i_ym
	
	SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Update: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg
*/	
  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_F_MM_SPNSR_DVLP_SUM_INIT] (
	@i_ym   AS VARCHAR(6), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[F_MM_SPNSR_DVLP_SUM] 

	SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Delete: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg
-----------------------------------------------------------
--JOB   : INSERT : [MART].[F_MM_SPNSR_DVLP]  
-----------------------------------------------------------	

    INSERT INTO  [MART].[F_MM_SPNSR_DVLP_SUM] 
    ( 
      STRD_MT ,                       -- 기준년월
      OCCRRNC_DE ,                    -- 발생일자
      SPNSR_NO ,                      -- 후원번호
      SPNSR_BSNS_NO ,                 -- 후원사업번호
      SER_NO ,                        -- 일련번호
      MBER_NO ,                       -- 회원번호
      ACT_DEPT_CD ,                   -- 활동부서코드
      ACMSLT_DEPT_CD ,                -- 실적부서코드
      ACMSLT_DEPT2_CD ,               -- 실적부서2코드
      ACMSLT_DEPT3_CD ,               -- 실적부서3코드
      ACMSLT_DEPT4_CD ,               -- 실적부서4코드
      CMPGN_CD ,                      -- 캠페인코드
      CMPGN_CLS1_CD ,                  -- 캠페인구분코드 희망TV
	  CMPGN_CLS2_CD ,                  -- 캠페인구분코드 희망편지쓰기 
	  CMPGN_CLS3_CD ,                  -- 캠페인구분코드 희망학교 
      UPPER_CMPGN_CD ,                -- 상위캠페인코드
      BRND_ID ,                       -- 브랜드ID
      PR_MTH_CD ,                     -- 홍보방법코드
      SPCL_CMPGN_YN ,                 -- 특정캠페인여부
	  PRE_CMPGN_CD ,                  -- 캠페인코드
      SETLE_CD ,                      -- 결제코드
      MBER_DIV_CD ,                   -- 회원구분코드
      SEX ,                           -- 성별
      AREA_CD ,                       -- 지역코드
      AGE_TERM_CD ,                   -- 연령대코드
      AGE ,                           -- 연령
      PAYER_AGE_TERM_CD ,             -- 결제자연령대코드
      SPNSR_TIME_CO ,                 -- 후원시간수
      SPNSR_TERM_MT_CNT ,             -- 후원기간월수
      SPNSR_TERM_CD ,                 -- 후원기간대코드
      SPNSR_AMT_CD ,                  -- 후원금액코드
      SPNSR_TERM2_CD ,                -- 후원기간대2코드
      SPNSR_AMT2_CD ,                 -- 후원금액2코드
      SPNSR_BSNS_ID ,                 -- 후원사업ID
	  SPNSR_BSNS2_ID ,                -- 후원사업2ID
      SPNSR_BSNS_ABRV_CD ,            -- 후원사업약칭코드
      CPR_DIV_CD ,                    -- 법인구분코드
      CANCL_RDCAMT_RSN_CD ,           -- 취소감액사유코드
      SPNSR_AMT ,                     -- 후원금액
      SPNSR_AMT_CNT ,                 -- 후원금액건수
      MT_GOAL_CNT ,                   -- 월목표후원건수
      YY_GOAL_CNT ,                   -- 년목표후원건수
      DVLP_DIV_CD ,                   -- 개발구분코드
      DVLP_CNT ,                      -- 개발구분건수
	  RDCAMT_YN ,                     -- 감액여부
      MT_ADD_SPNSR_AMT_YN ,           -- 증액여부
      WORK_DE                         -- 작업일자
    )
    SELECT 
		  LEFT( A.OCCRRNC_DE, 6) STRD_MT ,                      
		  A.OCCRRNC_DE ,                   
		  A.SPNSR_NO ,                     
		  A.SPNSR_BSNS_NO ,                
		  A.SER_NO ,                       
		  A.MBER_NO ,                      
		  A.ACT_DEPT_CD ,                  
		  A.ACMSLT_DEPT_CD ,               
		  B.DEPT2_ID ACMSLT_DEPT2_CD ,
		  B.DEPT3_ID ACMSLT_DEPT3_CD ,
		  B.DEPT4_ID ACMSLT_DEPT4_CD ,            
		  A.CMPGN_CD ,                     
		  ISNULL( D1.CMPGN_CLS_CD,'99'  )CMPGN_CLS1_CD ,                 
		  ISNULL( D2.CMPGN_CLS_CD,'99'  )CMPGN_CLS2_CD ,                 
		  --ISNULL( D3.CMPGN_CLS_CD,'99'  )CMPGN_CLS3_CD ,                 
		  ISNULL( CASE WHEN H.DSC_DE > LEFT( A.OCCRRNC_DE, 6) AND H.SPNSR_BSNS_ID = '38' AND DVLP_DIV_CD IN ( '1','2', '4')  THEN '3' ELSE '99' END ,'99') CMPGN_CLS3_CD,
		  ISNULL( C.UPPER_CMPGN_CD,'0') UPPER_CMPGN_CD ,               
		  ISNULL( C.BRND_ID, '0') BRND_ID ,                      
		  ISNULL( C.PR_MTH_CD,'0') PR_MTH_CD ,                    
		  ISNULL( C.SPCL_CMPGN_YN,'N' ) SPCL_CMPGN_YN ,   
		  ISNULL( CASE WHEN  DVLP_DIV_CD = '4' AND SPNSR_AMT > 0 THEN PRE_CMPGN_CD END , '0' ) PRE_CMPGN_CD , 	  
		  A.SETLE_CD ,                     
		  A.MBER_DIV_CD ,                  
		  A.SEX ,                          
		  A.AREA_CD ,                      
		  A.AGE AS AGE_TERM_CD ,                  
		   CASE WHEN A.AGE IN ( '1','2','3','4','5','6','7','8','9' )  THEN  CONVERT( INT, LEFT( CASE WHEN A.OCCRRNC_DE < E.BRTHDY THEN  CONVERT( CHAR(8),E.FRST_REGIST_DT,112) ELSE A.OCCRRNC_DE END , 4)) - CONVERT( INT, LEFT( E.BRTHDY, 4))  ELSE 0 END   AS AGE ,
		  '0' PAYER_AGE_TERM_CD ,            
		  A.SPNSR_TIME_CO ,                
		  DATEDIFF( MONTH, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  DSC_DE END )  SPNSR_TERM_MT_CNT ,            
		  ISNULL( CASE 
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 1  THEN 1
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 5  THEN 2
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  < 10 THEN 3
					WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END )  >= 10 THEN 4
					ELSE '99' END, '99' )  SPNSR_TERM_CD ,                
		  A.SPNSR_AMT_CD ,                 
		  CASE WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  < 1 THEN 1 
			   WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  BETWEEN 1 AND 9  THEN  DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  A.OCCRRNC_DE ELSE  H.DSC_DE END ) +1
		       WHEN DATEDIFF( YEAR, H.FST_DE , CASE WHEN  A.OCCRRNC_DE <  H.DSC_DE THEN  OCCRRNC_DE ELSE  H.DSC_DE END )  >= 10 THEN  11
			   ELSE '999' END           	  SPNSR_TERM2_CD ,               
		  '999' SPNSR_AMT2_CD ,     
								 
		  A.SPNSR_BSNS_ID ,
		  CASE WHEN A.SPNSR_BSNS_ID IN ('14','15','16','21','22') THEN  '4' ELSE A.SPNSR_BSNS_ID END SPNSR_BSNS2_ID ,	  
		  ISNULL( F.SPNSR_BSNS_ABRV_CD, '0')  SPNSR_BSNS_ABRV_CD ,           
		  ISNULL( F.CPR_DIV_CD ,'0') CPR_DIV_CD ,                   
		  CANCL_RDCAMT_RSN_CD ,          
		  SPNSR_AMT ,                    
		  SPNSR_AMT / 10000.0  AS SPNSR_AMT_CNT ,                
		  ISNULL( G.GOAL_CNT, 0 ) MT_GOAL_CNT ,                  
		  ISNULL( G.YYAMT, 0)  YY_GOAL_CNT ,                  
		  DVLP_DIV_CD ,                  
		  1 DVLP_CNT ,   
		  CASE WHEN DVLP_DIV_CD = '3' THEN 'Y' ELSE 'N' END RDCAMT_YN ,                     -- 감액여부
		  CASE WHEN DVLP_DIV_CD = '2' THEN 'Y' ELSE 'N' END MT_ADD_SPNSR_AMT_YN ,           -- 증액여부	  
		  CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM FN_MM_SPNSR_DVLP( @i_ym ) A
	LEFT OUTER JOIN [MART].[D_DEPT_CD]   B
	  ON A.ACMSLT_DEPT_CD = B.DEPT_ID  
    LEFT OUTER JOIN MART.D_CMPGN_CD      C
	  ON A.CMPGN_CD = C.CMPGN_CD
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D1 
      ON A.CMPGN_CD = D1.CMPGN_CD	  
	 AND D1.CMPGN_CLS_CD = '1'
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D2
      ON A.CMPGN_CD = D2.CMPGN_CD	    
	 AND D2.CMPGN_CLS_CD = '2' 
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D3 
      ON A.CMPGN_CD = D3.CMPGN_CD	    
	 AND D3.CMPGN_CLS_CD = '3' 	  
    LEFT OUTER JOIN MSTR_ODS.DBO.TM_MM_FDRM_MBER_INFO   E
	  ON A.MBER_NO = E.MBER_NO 
	LEFT OUTER JOIN MART.D_SPNSR_BSNS_INFO F 
	  ON A.SPNSR_BSNS_ID = F.SPNSR_BSNS_ID 
	LEFT OUTER JOIN ( SELECT SUM( GOAL_CNT) OVER ( PARTITION BY STDYY, DEPT_ID ,MBER_DVLP_DIV_CD ) YYAMT ,*
                        FROM [MART].[D_MBER_DVLP_GOAL_CD] 
			        ) G
	  ON A.ACMSLT_DEPT_CD =  G.DEPT_ID 
	 AND LEFT( A.OCCRRNC_DE, 6)  = G.STDYY + G.STDR_MT
     AND A.DVLP_DIV_CD = G.MBER_DVLP_DIV_CD  
	LEFT OUTER JOIN ( SELECT SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, FST_DE, DSC_DE  FROM  MART.D_SPNSR_BSNS_V ) H 
	  ON A.SPNSR_NO = H.SPNSR_NO 
	 AND A.SPNSR_BSNS_NO = H.SPNSR_BSNS_NO  
   WHERE 1 = 1 		  

    SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

   UPDATE MART.F_MM_SPNSR_DVLP_SUM 
      SET SPNSR_AMT2_CD = CASE  WHEN SPNSR_AMT2 < 10000  THEN '1'
								WHEN SPNSR_AMT2 BETWEEN 10000 AND 19999 THEN  '2'
								WHEN SPNSR_AMT2 BETWEEN 20000 AND 29999 THEN  '3'
								WHEN SPNSR_AMT2 BETWEEN 30000 AND 39999 THEN  '4'
								WHEN SPNSR_AMT2 BETWEEN 40000 AND 49999 THEN  '5'
								WHEN SPNSR_AMT2 BETWEEN 50000 AND 59999 THEN  '6'
								WHEN SPNSR_AMT2 BETWEEN 60000 AND 69999 THEN  '7'
								WHEN SPNSR_AMT2 BETWEEN 70000 AND 79999 THEN  '8'
								WHEN SPNSR_AMT2 BETWEEN 80000 AND 89999 THEN  '9'
								WHEN SPNSR_AMT2 BETWEEN 90000 AND 99999 THEN  '10'
								WHEN SPNSR_AMT2 BETWEEN 100000 AND 499999 THEN  '11'
								WHEN SPNSR_AMT2 >= 500000 THEN  '12'
								ELSE '999' END    
    FROM  MART.F_MM_SPNSR_DVLP_SUM  A
  	JOIN   (
			SELECT  SUM( SPNSR_AMT ) OVER ( PARTITION BY STRD_MT,SPNSR_NO, SPNSR_BSNS_NO  ,  DVLP_DIV_CD  ) SPNSR_AMT2 , STRD_MT, SPNSR_NO, SPNSR_BSNS_NO ,DVLP_DIV_CD
			  FROM ( 
						SELECT 
								ROW_NUMBER() OVER ( PARTITION BY   SPNSR_NO, SPNSR_BSNS_NO ,DVLP_DIV_CD  ORDER BY SER_NO   ) RNUM,   *
						  FROM  MART.F_MM_SPNSR_DVLP
						  WHERE 1 = 1 --STRD_MT = @i_ym 
						  AND   DVLP_DIV_CD IN ( '1', '2', '4' ) 
						  AND   ISNULL( CANCL_RDCAMT_RSN_CD ,'999' ) = '999'
					) A
			WHERE RNUM = 1
            ) I	
	 ON  A.SPNSR_NO = I.SPNSR_NO 
	AND  A.SPNSR_BSNS_NO = I.SPNSR_BSNS_NO
	AND  A.DVLP_DIV_CD = I.DVLP_DIV_CD
    SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Update: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg	
	
  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_F_MM_SPNSR_DVLP] (
	@i_ym   AS VARCHAR(6), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    DELETE  FROM [MART].[F_MM_SPNSR_DVLP] WITH(TABLOCK)
      WHERE STRD_MT = @i_ym 	

	SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Delete: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg
-----------------------------------------------------------
--JOB   : INSERT : [MART].[F_MM_SPNSR_DVLP]  
-----------------------------------------------------------	

    INSERT INTO  [MART].[F_MM_SPNSR_DVLP] 
    ( 
      STRD_MT ,                       -- 기준년월
      OCCRRNC_DE ,                    -- 발생일자
      SPNSR_NO ,                      -- 후원번호
      SPNSR_BSNS_NO ,                 -- 후원사업번호
      SER_NO ,                        -- 일련번호
      MBER_NO ,                       -- 회원번호
      ACT_DEPT_CD ,                   -- 활동부서코드
      ACMSLT_DEPT_CD ,                -- 실적부서코드
      ACMSLT_DEPT2_CD ,               -- 실적부서2코드
      ACMSLT_DEPT3_CD ,               -- 실적부서3코드
      ACMSLT_DEPT4_CD ,               -- 실적부서4코드
      CMPGN_CD ,                      -- 캠페인코드
      CMPGN_CLS1_CD ,                  -- 캠페인구분코드 희망TV
	  CMPGN_CLS2_CD ,                  -- 캠페인구분코드 희망편지쓰기 
	  CMPGN_CLS3_CD ,                  -- 캠페인구분코드 희망학교 
      UPPER_CMPGN_CD ,                -- 상위캠페인코드
      BRND_ID ,                       -- 브랜드ID
      PR_MTH_CD ,                     -- 홍보방법코드
      SPCL_CMPGN_YN ,                 -- 특정캠페인여부
	  PRE_CMPGN_CD ,                  -- 캠페인코드
      SETLE_CD ,                      -- 결제코드
      MBER_DIV_CD ,                   -- 회원구분코드
      SEX ,                           -- 성별
      AREA_CD ,                       -- 지역코드
      AGE_TERM_CD ,                   -- 연령대코드
      AGE ,                           -- 연령
      PAYER_AGE_TERM_CD ,             -- 결제자연령대코드
      SPNSR_TIME_CO ,                 -- 후원시간수
      SPNSR_TERM_MT_CNT ,             -- 후원기간월수
      SPNSR_TERM_CD ,                 -- 후원기간대코드
      SPNSR_AMT_CD ,                  -- 후원금액코드
      SPNSR_TERM2_CD ,                -- 후원기간대2코드
      SPNSR_AMT2_CD ,                 -- 후원금액2코드
      SPNSR_BSNS_ID ,                 -- 후원사업ID
      SPNSR_BSNS_ABRV_CD ,            -- 후원사업약칭코드
      CPR_DIV_CD ,                    -- 법인구분코드
      CANCL_RDCAMT_RSN_CD ,           -- 취소감액사유코드
      SPNSR_AMT ,                     -- 후원금액
      SPNSR_AMT_CNT ,                 -- 후원금액건수
      MT_GOAL_CNT ,                   -- 월목표후원건수
      YY_GOAL_CNT ,                   -- 년목표후원건수
      DVLP_DIV_CD ,                   -- 개발구분코드
      DVLP_CNT ,                      -- 개발구분건수
	  RDCAMT_YN ,                     -- 감액여부
      MT_ADD_SPNSR_AMT_YN ,           -- 증액여부
      WORK_DE                         -- 작업일자
    )
    SELECT 
      LEFT( A.OCCRRNC_DE, 6) STRD_MT ,                      
      A.OCCRRNC_DE ,                   
      A.SPNSR_NO ,                     
      A.SPNSR_BSNS_NO ,                
      A.SER_NO ,                       
      A.MBER_NO ,                      
      A.ACT_DEPT_CD ,                  
      A.ACMSLT_DEPT_CD ,               
      B.DEPT2_ID ACMSLT_DEPT2_CD ,
	  B.DEPT3_ID ACMSLT_DEPT3_CD ,
	  B.DEPT4_ID ACMSLT_DEPT4_CD ,            
      A.CMPGN_CD ,                     
      ISNULL( D1.CMPGN_CLS_CD,'99'  )CMPGN_CLS1_CD ,                 
	  ISNULL( D2.CMPGN_CLS_CD,'99'  )CMPGN_CLS2_CD ,                 
	  ISNULL( D3.CMPGN_CLS_CD,'99'  )CMPGN_CLS3_CD ,	  
      ISNULL( C.UPPER_CMPGN_CD,'Z~') UPPER_CMPGN_CD ,               
      ISNULL( C.BRND_ID, 'Z~') BRND_ID ,                      
      ISNULL( C.PR_MTH_CD,'9999') PR_MTH_CD ,                    
      ISNULL( C.SPCL_CMPGN_YN,'Z' ) SPCL_CMPGN_YN ,   
      ISNULL( CASE WHEN  DVLP_DIV_CD = '4' AND SPNSR_AMT > 0 THEN PRE_CMPGN_CD END , 'Z~' ) PRE_CMPGN_CD , 	  
      A.SETLE_CD ,                     
      A.MBER_DIV_CD ,                  
      A.SEX ,                          
      A.AREA_CD ,                      
      A.AGE AS AGE_TERM_CD ,                  
       CASE WHEN A.AGE IN ( '1','2','3','4','5','6','7','8','9' )  THEN  CONVERT( INT, LEFT( CASE WHEN A.OCCRRNC_DE < E.BRTHDY THEN  CONVERT( CHAR(8),E.FRST_REGIST_DT,112) ELSE A.OCCRRNC_DE END , 4)) - CONVERT( INT, LEFT( E.BRTHDY, 4))  ELSE 0 END   AS AGE ,
      '0' PAYER_AGE_TERM_CD ,            
      A.SPNSR_TIME_CO ,                
      '0' SPNSR_TERM_MT_CNT ,            
      '0' SPNSR_TERM_CD ,                
      A.SPNSR_AMT_CD ,                 
      '0' SPNSR_TERM2_CD ,               
      '0' SPNSR_AMT2_CD ,                
      A.SPNSR_BSNS_ID ,                
      ISNULL( F.SPNSR_BSNS_ABRV_CD, '99')  SPNSR_BSNS_ABRV_CD ,           
      ISNULL( F.CPR_DIV_CD ,'0') CPR_DIV_CD ,                   
      ISNULL( CANCL_RDCAMT_RSN_CD ,'999' ) CANCL_RDCAMT_RSN_CD,          
      SPNSR_AMT ,                    
      SPNSR_AMT / 10000.0  AS SPNSR_AMT_CNT ,                
      ISNULL( G.GOAL_CNT, 0 ) MT_GOAL_CNT ,                  
      ISNULL( G.YYAMT, 0)  YY_GOAL_CNT ,                  
      DVLP_DIV_CD ,                  
      0 DVLP_CNT ,
      'N' RDCAMT_YN ,                     -- 감액여부
      'N' MT_ADD_SPNSR_AMT_YN ,           -- 증액여부
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM ( SELECT 
		       LAG(CMPGN_CD , 1) OVER ( PARTITION BY SPNSR_NO, SPNSR_BSNS_NO  ORDER BY  OCCRRNC_DE ) PRE_CMPGN_CD, *
		   FROM MSTR_ODS.DBO.TM_MM_FDRM_MBER_DVLP_AMT 
		  WHERE 1 = 1
	        AND OCCRRNC_DE BETWEEN @i_ym + '01' AND @i_ym + '31'
		  ) A
	LEFT OUTER JOIN [MART].[D_DEPT_CD]   B
	  ON A.ACMSLT_DEPT_CD = B.DEPT_ID  
    LEFT OUTER JOIN MART.D_CMPGN_CD      C
	  ON A.CMPGN_CD = C.CMPGN_CD
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D1 
      ON A.CMPGN_CD = D1.CMPGN_CD	  
	 AND D1.CMPGN_CLS_CD = '1'
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D2
      ON A.CMPGN_CD = D2.CMPGN_CD	    
	 AND D2.CMPGN_CLS_CD = '2' 
	LEFT OUTER JOIN MART.D_CMPGN_EXPL_CD D3 
      ON A.CMPGN_CD = D3.CMPGN_CD	    
	 AND D3.CMPGN_CLS_CD = '3'	  
    LEFT OUTER JOIN MSTR_ODS.DBO.TM_MM_FDRM_MBER_INFO   E
	  ON A.MBER_NO = E.MBER_NO 
	LEFT OUTER JOIN MART.D_SPNSR_BSNS_INFO F 
	  ON A.SPNSR_BSNS_ID = F.SPNSR_BSNS_ID 
	LEFT OUTER JOIN ( SELECT SUM( GOAL_CNT) OVER ( PARTITION BY STDYY, DEPT_ID ,MBER_DVLP_DIV_CD ) YYAMT ,*
                        FROM [MART].[D_MBER_DVLP_GOAL_CD] 
			        ) G
	  ON A.ACMSLT_DEPT_CD =  G.DEPT_ID 
	 AND LEFT( A.OCCRRNC_DE, 6)  = G.STDYY + G.STDR_MT
     AND A.DVLP_DIV_CD = G.MBER_DVLP_DIV_CD  
   WHERE 1 = 1 		  

    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

     MERGE [MART].[F_MM_SPNSR_DVLP]  A
     USING (  	 
			   SELECT  *
				 FROM (
						SELECT DVLP_DIV_CD AS DVLP_DIV_CD2,
							   SUM(SPNSR_AMT) OVER ( PARTITION BY SPNSR_NO, SPNSR_BSNS_NO, STRD_MT ) SAMT ,
							   1 RNUM ,*
						  FROM MART.F_MM_SPNSR_DVLP A
						 WHERE DVLP_DIV_CD IN ( '1' ,'4' ) 
						   AND STRD_MT = @i_ym 
					  ) A
				WHERE A.SAMT > 0 
				UNION ALL
				SELECT  *
				  FROM ( 
						SELECT '2' DVLP_DIV_CD2,
							   SUM(SPNSR_AMT) OVER ( PARTITION BY MBER_NO ,STRD_MT ) MAMT,
							   ROW_NUMBER() OVER (PARTITION BY MBER_NO ,STRD_MT ORDER BY DVLP_DIV_CD )  RNUM, *
						  FROM MART.F_MM_SPNSR_DVLP  A
						 WHERE DVLP_DIV_CD IN ( '2','3','5') 
						   AND  STRD_MT = @i_ym 
					  )B 
				  WHERE MAMT > 0 
            ) C
	   ON A.STRD_MT       = C.STRD_MT 
      AND A.SPNSR_NO      = C.SPNSR_NO 
      AND A.SPNSR_BSNS_NO = C.SPNSR_BSNS_NO 
      AND A.SER_NO        = C.SER_NO 
      AND A.MBER_NO       = C.MBER_NO
      AND A.OCCRRNC_DE    = C.OCCRRNC_DE 
 	 WHEN MATCHED THEN 
	 UPDATE  SET DVLP_CNT = 1 ;
	             
	 
    SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  UPDATE2: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg


     MERGE [MART].[F_MM_SPNSR_DVLP]  A
     USING (  	 
			   SELECT 
		         SUM( SPNSR_AMT  ) OVER ( PARTITION BY  MBER_NO , STRD_MT  ORDER BY SPNSR_NO) RAMT ,
				 SUM( SPNSR_AMT  ) OVER ( PARTITION BY  SPNSR_NO, SPNSR_BSNS_NO , STRD_MT ) SAMT , *
			  FROM MART.F_MM_SPNSR_DVLP 
			 WHERE STRD_MT = @i_ym 
			   AND DVLP_DIV_CD  in ( 2,3 ) 
			   AND DVLP_CNT = 1
            ) C
	   ON A.STRD_MT       = C.STRD_MT 
      AND A.SPNSR_NO      = C.SPNSR_NO 
      AND A.SPNSR_BSNS_NO = C.SPNSR_BSNS_NO 
      AND A.SER_NO        = C.SER_NO 
      AND A.MBER_NO       = C.MBER_NO
      AND A.OCCRRNC_DE    = C.OCCRRNC_DE 
 	 WHEN MATCHED THEN 
	 UPDATE  SET MT_ADD_SPNSR_AMT_YN = CASE WHEN SAMT >0 AND RAMT >0 THEN 'Y' ELSE 'N' END ;
	             
	 
    SET @v_numrows = @@rowcount
    SET @o_msg = '초기화 : F_회원_정기회원후원개발(F_MM_SPNSR_DVLP)  UPDATE2: ' + CONVERT(VARCHAR(10), @v_numrows)	
    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg
	
  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_BRND_CD] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_BRND_CD] 

    INSERT INTO  [MART].[D_BRND_CD] 
    ( 
      BRND_ID ,                  -- 브랜드ID
      BRND_NM ,                  -- 브랜드명
      USE_DEPT_CD ,              -- 사용부서코드
      USE_YN ,                   -- 사용여부
      FRST_RGSTR_ID ,            -- 최초등록자ID
      FRST_REGIST_DT ,           -- 최초등록일시
      LAST_UPDUSR_ID ,           -- 최종수정자ID
      LAST_UPDT_DT ,             -- 최종수정일시
      PR_MTH_LIST ,              -- 홍보방법리스트
      WORK_DE                  -- 작업일자
    )
    SELECT 
      BRND_ID ,                 
      BRND_NM ,                 
      USE_DEPT_CD ,             
      USE_YN ,                  
      FRST_RGSTR_ID ,           
      FRST_REGIST_DT ,          
      LAST_UPDUSR_ID ,          
      LAST_UPDT_DT ,            
      PR_MTH_LIST ,             
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_BRND_MNG
    WHERE 1 = 1
	UNION ALL 
	SELECT TOP 1 
      'Z~' BRND_ID ,                 
      '없음' BRND_NM ,                 
      'Z~' USE_DEPT_CD ,             
      'Y' USE_YN ,                  
      FRST_RGSTR_ID ,           
      FRST_REGIST_DT ,          
      LAST_UPDUSR_ID ,          
      LAST_UPDT_DT ,            
      NULL PR_MTH_LIST ,             
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE 
	  FROM MSTR_ODS.DBO.TM_CM_BRND_MNG


    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : 브랜드관리Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_CMPGN_CD] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_CMPGN_CD] 

    INSERT INTO  [MART].[D_CMPGN_CD] 
    ( 
      CMPGN_CD ,                      -- 캠페인코드
      CMPGN_NM ,                      -- 캠페인명
      UPPER_CMPGN_CD ,                -- 상위캠페인코드
      UPPER_CMPGN_YN ,                -- 상위캠페인여부
      SPNSR_DIV_CD ,                  -- 후원구분코드
      CPR_DIV_CD ,                    -- 법인구분코드
      CMPGN_TRGET_CD ,                -- 캠페인대상코드
      USE_DEPT_CD ,                   -- 사용부서코드
      USE_SCOPE ,                     -- 사용범위
      SPNSR_ENTRPRS_ID ,              -- 후원기업ID
      BRND_ID ,                       -- 브랜드ID
      PR_MTH_CD ,                     -- 홍보방법코드
      CMPGN_STRT_DE ,                 -- 캠페인시작일
      MBRFEE_BNKB_LIST ,              -- 회비통장리스트
      INICIS_ACNT_NO ,                -- 이니시스계정번호
      USE_YN ,                        -- 사용여부
      REFER_URL ,                     -- 참고URL
      SPNSR_BSNS_ID ,                 -- 후원사업ID
      ATCHFL_ID ,                     -- 첨부파일ID
      FRST_RGSTR_ID ,                 -- 최초등록자ID
      FRST_REGIST_DT ,                -- 최초등록일시
      LAST_UPDUSR_ID ,                -- 최종수정자ID
      LAST_UPDT_DT ,                  -- 최종수정일시
      CMPGN_DC ,                      -- 캠페인설명
      EMRGNCY_AID_BPLC_CD ,           -- 긴급구호사업장코드
      SPCL_CMPGN_YN ,                 -- 특정캠페인여부
      WORK_DE                       -- 작업일자
    )
    SELECT 
      CMPGN_CD ,                     
      CMPGN_NM ,                     
      UPPER_CMPGN_CD ,               
      UPPER_CMPGN_YN ,               
      SPNSR_DIV_CD ,                 
      CPR_DIV_CD ,                   
      CMPGN_TRGET_CD ,               
      USE_DEPT_CD ,                  
      USE_SCOPE ,                    
      SPNSR_ENTRPRS_ID ,             
      ISNULL(BRND_ID,'0') ,   --NULL ->0 처리                      
      PR_MTH_CD ,                    
      CMPGN_STRT_DE ,                
      MBRFEE_BNKB_LIST ,             
      INICIS_ACNT_NO ,               
      USE_YN ,                       
      REFER_URL ,                    
      SPNSR_BSNS_ID ,                
      ATCHFL_ID ,                    
      FRST_RGSTR_ID ,                
      FRST_REGIST_DT ,               
      LAST_UPDUSR_ID ,               
      LAST_UPDT_DT ,                 
      CMPGN_DC ,                     
      EMRGNCY_AID_BPLC_CD ,          
      'N' SPCL_CMPGN_YN ,                
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_CMPGN_MNG
    WHERE 1 = 1

    UNION ALL
	  SELECT  TOP 1
      'Z~' CMPGN_CD ,                     
      '없음' CMPGN_NM ,                     
      'Z~' UPPER_CMPGN_CD ,               
      UPPER_CMPGN_YN ,               
      SPNSR_DIV_CD ,                 
      CPR_DIV_CD ,                   
      CMPGN_TRGET_CD ,               
      USE_DEPT_CD ,                  
      USE_SCOPE ,                    
      SPNSR_ENTRPRS_ID ,             
      ISNULL(BRND_ID,'Z~') ,   --NULL ->0 처리                      
      PR_MTH_CD ,                    
      CMPGN_STRT_DE ,                
      MBRFEE_BNKB_LIST ,             
      INICIS_ACNT_NO ,               
      USE_YN ,                       
      REFER_URL ,                    
      SPNSR_BSNS_ID ,                
      ATCHFL_ID ,                    
      FRST_RGSTR_ID ,                
      FRST_REGIST_DT ,               
      LAST_UPDUSR_ID ,               
      LAST_UPDT_DT ,                 
      CMPGN_DC ,                     
      EMRGNCY_AID_BPLC_CD ,          
      'N' SPCL_CMPGN_YN ,                
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_CMPGN_MNG
    WHERE 1 = 1
	AND  CMPGN_CD = 'U0027'
	
	
    UPDATE [MART].[D_CMPGN_CD] 
	SET  SPCL_CMPGN_YN = 'Y' 
	FROM [MART].[D_CMPGN_CD]  A
    JOIN MSTR_ODS.DBO.ExplCampList B 
	  ON A.CMPGN_CD = CONVERT( VARCHAR, B.CampaignCd  )
	 AND B.CampaignCls = '3' 
	WHERE 1 = 1 
/*	 
	WHERE CMPGN_CD IN   ('14','15','736','737','738','738','740','1054','1055','1056','1057','1058','1059','1064','1064','1219','1219','1245','1245','1254','1254',
						'1255','1255','1256','1256','1270','1271','1271','1275','1366','1366','1541','1542','1545','1546','1549','1550','1572','1573','1574','1577','1577','1581','1581',
						'1582','1582','1583','1583','1584','1584','1585','1585','1586','1586','1589','1589','1590','1590','1595','1599','1859','1860','1861','1865','1870','1883','1884',
						'1885','1886','1887','1888','1889','1890','1890','1891','1891','1892','1892','1893','1893','2025','2030','2037','2038','2083','2087','2088','2089','2091','2091',
						'2092','2093','2176','2177','2178','2179','2180','2194','2195','3054','3295','3296','3297','3298','3299','3300','3301','3302','3303','3304','3306','3315','3318',
						'357','519','522','630','732','733','735','1074','1075','1076','1077','1223','1224','1244','1272','1274','1276','1277','1278','1564','1565','1566','1567','1568',
						'1569','1570','1571','1814','1815','1842','1871','1872','1873','1874','1875','1876','1877','1878','1896','1911','1922','2026','2027','2028','2029','2039','2100',
						'2101','2102','2104','2106','2107','2113','2155','2156','2298','3160','3487','3495','3560','3627','3628','3248','3249','3250','3251','3252','3253','3254','3255',
						'3256','3257','3258','3259','3260','3261','3262','3263','3264','3265','3266','3267','3627','3724','3725','3726','3727','3686','3687','3688','3689','3690','3691',
						'3692','3693','3694','3695','3696','3698','3699','3700','3740','3741','3749','3750','3627','3724','3725','3726','3727','4338','4460','4505','4506','4507','4508',
						'4523','5064','5123','5266','5267','5293')
*/						
    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : 캠페인코드 Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 

GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_CMPGN_EXPL_CD] (
	@i_ym   AS VARCHAR(6), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_CMPGN_EXPL_CD] 

    INSERT INTO  [MART].[D_CMPGN_EXPL_CD] 
    ( 
      CMPGN_CLS_CD ,             -- 캠페인구분코드
      CMPGN_CD ,                 -- 캠페인코드
      CMPGN_NM ,                 -- 캠페인명
      UPPER_CMPGN_CD ,           -- 상위캠페인코드
      UPPER_CMPGN_NM ,           -- 상위캠페인명
      PR_MTH_CD ,                -- 홍보방법코드
      USE_DEPT_CD ,              -- 사용부서
      COMMENT ,                  -- 코멘트
      WORK_DE                    -- 작업일자
    )
    SELECT 
      CampaignCls     CMPGN_CLS_CD,
	  CampaignCd      CMPGN_CD ,                
      CampaignNm      CMPGN_NM ,                
      UpperCampaignCd UPPER_CMPGN_CD ,          
      UpperCampaignNm UPPER_CMPGN_NM ,          
      Prcd            PR_MTH_CD ,               
      UseDeptCd       USE_DEPT_CD ,             
      Comment         COMMENT ,                 
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.ExplCampList B
    WHERE 1 = 1

    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 :D_캠페인특별코드Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_SPNSR_BSNS_INFO] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_SPNSR_BSNS_INFO] 

    INSERT INTO  [MART].[D_SPNSR_BSNS_INFO] 
    ( 
      SPNSR_BSNS_ID ,                -- 후원사업ID
      SPNSR_DIV_CD ,                 -- 후원구분코드
      SPNSR_BSNS_NM ,                -- 후원사업명
      SPNSR_BSNS_ABRV_CD ,           -- 후원사업약칭코드
      DNTN_TY_CD ,                   -- 기부금유형코드
      SORT_ORDR ,                    -- 정렬순서
      CPR_DIV_CD ,                   -- 법인구분코드
      RM ,                           -- 비고
      USE_YN ,                       -- 사용여부
      FRST_RGSTR_ID ,                -- 최초등록자ID
      FRST_REGIST_DT ,               -- 최초등록일시
      LAST_UPDUSR_ID ,               -- 최종수정자ID
      LAST_UPDT_DT ,                 -- 최종수정일시
      WORK_DE                      -- 작업일자
    )
    SELECT 
      SPNSR_BSNS_ID ,               
      SPNSR_DIV_CD ,                
      SPNSR_BSNS_NM ,               
      SPNSR_BSNS_ABRV_CD ,          
      DNTN_TY_CD ,                  
      SORT_ORDR ,                   
      CASE WHEN CPR_DIV_CD = '1'  THEN 'I'
           WHEN CPR_DIV_CD = '2'  THEN 'S'	
           ELSE CPR_DIV_CD END CPR_DIV_CD,		   
      RM ,                          
      USE_YN ,                      
      FRST_RGSTR_ID ,               
      FRST_REGIST_DT ,              
      LAST_UPDUSR_ID ,              
      LAST_UPDT_DT ,                
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_SPNSR_BSNS_INFO
    WHERE 1 = 1
    UNION ALL 
	SELECT TOP 1
      '99' SPNSR_BSNS_ID ,               
      '0' SPNSR_DIV_CD ,                
      '없음' SPNSR_BSNS_NM ,               
      '99' SPNSR_BSNS_ABRV_CD ,          
      '0' DNTN_TY_CD ,                  
      999 SORT_ORDR ,                   
      'Z' CPR_DIV_CD,		   
      '' RM ,                          
      'Y' USE_YN ,                      
      FRST_RGSTR_ID ,               
      FRST_REGIST_DT ,              
      LAST_UPDUSR_ID ,              
      LAST_UPDT_DT ,                
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_SPNSR_BSNS_INFO
    WHERE 1 = 1
    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 :D_후원사업정보관리Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_STRD_DE_CD] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_STRD_DE_CD] 

    INSERT INTO  [MART].[D_STRD_DE_CD] 
    ( 
      STRD_DE ,                   -- 일자ID
      STRD_PRE_DE ,               -- 전일자ID
      STRD_PRE_MT_DE ,            -- 전월동일자ID
      STRD_PRE_YMT_DE ,           -- 전년동월동일자ID
      STRD_MT ,                   -- 년월ID
      STRD_QT ,                   -- 쿼터ID
      STRD_YY ,                   -- 년ID
      MT_ID ,                     -- 월ID
      WORK_DE                   -- 작업일자
    )
    SELECT 
      YMD ,
      CONVERT( CHAR(8), DATEADD(DAY  , -1, SYMD ) ,112)  ,
      CONVERT( CHAR(8), DATEADD(MONTH, -1, SYMD ) ,112)  ,
      CONVERT( CHAR(8), DATEADD(YEAR , -1, SYMD ) ,112)  ,
      LEFT( YMD, 6) ,
      QQ ,
      YY ,
      MM ,
	  CONVERT(CHAR(8), GETDATE() , 112) WORK_DE 
   FROM MART.D_STRD_CAL_CD
    WHERE 1 = 1

    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : 정기회원정보 Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

	RETURN ( @o_msg )

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_CM_DEPT_INFO] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_CM_DEPT_INFO] 

    INSERT INTO  [MART].[D_CM_DEPT_INFO] 
    ( 
      DEPT_ID ,                        -- 부서ID
      DEPT_NM ,                        -- 부서명
      UPPER_DEPT_ID ,                  -- 상위부서ID
      SORT_ORDR ,                      -- 정렬순서
      USE_YN ,                         -- 사용여부
      FRST_RGSTR_ID ,                  -- 최초등록자ID
      FRST_REGIST_DT ,                 -- 최초등록일시
      LAST_UPDUSR_ID ,                 -- 최종수정자ID
      LAST_UPDT_DT ,                   -- 최종수정일시
      ACMSLT_DEPT_YN ,                 -- 실적부서여부
      STATS_DEPT_LVL ,                 -- 통계부서레벨
      ACMSLT_UPPER_DEPT_ID ,           -- 실적상위부서ID
      WORK_DE                        -- 작업일자
    )
    SELECT 
      DEPT_ID ,                       
      DEPT_NM ,                       
      UPPER_DEPT_ID ,                 
      SORT_ORDR ,                     
      USE_YN ,                        
      FRST_RGSTR_ID ,                 
      FRST_REGIST_DT ,                
      LAST_UPDUSR_ID ,                
      LAST_UPDT_DT ,                  
      ACMSLT_DEPT_YN ,                
      STATS_DEPT_LVL ,                
      ACMSLT_UPPER_DEPT_ID ,          
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_DEPT_INFO
    WHERE 1 = 1
	UNION ALL 
	SELECT 
      'Z~' DEPT_ID ,                       
      'N/A'DEPT_NM ,                       
       'ZV000000' UPPER_DEPT_ID ,                 
      SORT_ORDR ,                     
      USE_YN ,                        
      FRST_RGSTR_ID ,                 
      FRST_REGIST_DT ,                
      LAST_UPDUSR_ID ,                
      LAST_UPDT_DT ,                  
      ACMSLT_DEPT_YN ,                
      STATS_DEPT_LVL ,                
      'A000001' ACMSLT_UPPER_DEPT_ID ,          
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_DEPT_INFO
    WHERE 1 = 1
	AND    DEPT_ID = 'A000000'
	
    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : D_부서정보Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_CMMN_DTL_CD] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  DECLARE  @JOBDE   VARCHAR(10)
  DECLARE  @WORKDE  VARCHAR(10)

  SET @JOBDE  = CONVERT( VARCHAR(10) , GETDATE(), 121) 
  SET @WORKDE = CONVERT( VARCHAR(8 ) , GETDATE(), 112) 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_CMMN_DTL_CD] 

    INSERT INTO  [MART].[D_CMMN_DTL_CD] 
    ( 
      CD_ID ,                    -- 코드ID
      DTL_CD_ID ,                -- 상세코드ID
      CD_NM ,                    -- 코드명
      DTL_CD_NM ,                -- 상세코드명
      SORT_ORDR ,                -- 정렬순서
      RM ,                       -- 비고
      USE_YN ,                   -- 사용여부
      CD_ATRB1 ,                 -- 코드속성1
      CD_ATRB2 ,                 -- 코드속성2
      CD_ATRB3 ,                 -- 코드속성3
      FRST_RGSTR_ID ,            -- 최초등록자ID
      FRST_REGIST_DT ,           -- 최초등록일시
      LAST_UPDUSR_ID ,           -- 최종수정자ID
      LAST_UPDT_DT ,             -- 최종수정일시
      UPPER_CD_ID ,              -- 상위코드ID
      CD_TYP_CD ,                -- 코드분류코드
      WORK_DE                  -- 작업일자
    )
   SELECT  DISTINCT  
    B.CD_ID ,                    -- 코드ID
    B.DTL_CD_ID ,                -- 상세코드ID
    A.CD_NM ,                    -- 코드명
    B.DTL_CD_NM ,                -- 상세코드명
    B.SORT_ORDR ,                -- 정렬순서
    B.RM ,                       -- 비고
    ISNULL( B.USE_YN ,'Y') USE_YN,                   -- 사용여부
    B.CD_ATRB1 ,                 -- 코드속성1
    B.CD_ATRB2 ,                 -- 코드속성2
    B.CD_ATRB3 ,                 -- 코드속성3
    B.FRST_RGSTR_ID ,            -- 최초등록자ID
    B.FRST_REGIST_DT ,           -- 최초등록일시
    B.LAST_UPDUSR_ID ,           -- 최종수정자ID
    B.LAST_UPDT_DT ,             -- 최종수정일시
    B.UPPER_CD_ID ,              -- 상위코드ID
    'CRM' CD_TYP_CD ,                -- 코드분류코드
    CONVERT( VARCHAR(8),GETDATE(), 112) WORK_DE                  -- 작업일자
FROM MSTR_ODS.DBO.TC_CMMN_CD     A  
JOIN MSTR_ODS.DBO.TC_CMMN_DTL_CD B
  ON A.CD_ID = B.CD_ID 
  
    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : MART공통코드 Insert01: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg  

INSERT INTO  [MART].[D_CMMN_DTL_CD] 
-- 코드ID  상세코드ID  코드명  상세코드명  정렬순서  비고  사용여부  코드속성1  코드속성2  코드속성3  최초등록자ID  최초등록일시  최종수정자ID  최종수정일시 상위코드ID  코드분류코드 작업일자
-- 코드분류코드 : CRM ,MART 
VALUES  -- 입입채널구분코드
        ( 'DMMS01',  '1', '입입채널구분코드', '온라인', 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMMS01',  '2', '입입채널구분코드', '콜센터'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 문자구분코드
	   ,( 'DMMS02',  '1', '문자구분코드', '알림톡'  , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS02',  '2', '문자구분코드', '문자'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 활동중단구분코드
	   ,( 'DMMS03',  '1', '활동중단구분코드', '활동'  , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS03',  '2', '활동중단구분코드', '중단'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS03',  '3', '활동중단구분코드', '증액'  , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS03',  '4', '활동중단구분코드', '감액'  , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 미납서비스코드
	   ,( 'DMMS05',  '1', '미납서비스코드', '우편'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS05',  '2', '미납서비스코드', '이메일'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS05',  '3', '미납서비스코드', '문자'    , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS05',  '4', '미납서비스코드', 'TS'      , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 성공여부(발송)
	   ,( 'DMMS06',  '1', '발신결과코드', '성공'      , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMS06',  '0', '발신결과코드', '실패'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 회원상태구분2코드
	   ,( 'DMMM01',  '1', '회원상태구분2코드', '활동'  , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM01',  '2', '회원상태구분2코드', '중단'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 여부코드
	   ,( 'DMMM02',  'Y', '여부코드', '예'      , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM02',  'N', '여부코드', '아니오'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 중단경로코드
	   ,( 'DMMM03',  '1', '중단경로코드', '시스템중단'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM03',  '2', '중단경로코드', '직원중단'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM03',  '3', '중단경로코드', '회원중단'    , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 캠페인구분코드
	   ,( 'DMMM04',  '1', '캠페인구분코드', '희망TV'              , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM04',  '2', '캠페인구분코드', '희망편지쓰기대회'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM04',  '3', '캠페인구분코드', '희망학교'            , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 가입회원구분코드
	   ,( 'DMMM05',  '1', '가입회원구분코드', '정기'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM05',  '2', '가입회원구분코드', '일시'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 성별구분코드
	   ,( 'DMMM06',  'M', '성별구분코드', '남자'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM06',  'F', '성별구분코드', '여자'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 신규기존회원구분코드
	   ,( 'DMMM07',  '1', '신규/기존회원구분코드', '신규'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM07',  '2', '신규/기존회원구분코드', '기존'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 후원기간대2코드
	   ,( 'DMMM08',  '1', '후원기간대2코드', '1년미만'            , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '2', '후원기간대2코드', '1년이상~2년미만'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '3', '후원기간대2코드', '2년이상~3년미만'   , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '4', '후원기간대2코드', '3년이상~4년미만'   , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '5', '후원기간대2코드', '4년이상~5년미만'   , 5, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '6', '후원기간대2코드', '5년이상~6년미만'   , 6, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '7', '후원기간대2코드', '6년이상~7년미만'   , 7, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '8', '후원기간대2코드', '7년이상~8년미만'   , 8, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '9', '후원기간대2코드', '8년이상~9년미만'   , 9, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '10', '후원기간대2코드', '9년이상~10년미만'   , 10, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM08',  '11', '후원기간대2코드', '10년이상'           , 11, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 후원금액2코드
	   ,( 'DMMM09',  '1', '후원금액2코드', '1만원미만'              , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '2', '후원금액2코드', '1만원이상~2만원미만'       , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '3', '후원금액2코드', '2만원이상~3만원미만'       , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '4', '후원금액2코드', '3만원이상~4만원미만'       , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '5', '후원금액2코드', '4만원이상~5만원미만'       , 5, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '6', '후원금액2코드', '5만원이상~6만원미만'       , 6, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '7', '후원금액2코드', '6만원이상~7만원미만'       , 7, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '8', '후원금액2코드', '7만원이상~8만원미만'       , 8, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '9', '후원금액2코드', '8만원이상~9만원미만'       , 9, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '10', '후원금액2코드', '9만원이상~10만원미만'      , 10, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMMM09',  '11', '후원금액2코드', '10만원이상~50만원미만'     , 11, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM09',  '12', '후원금액2코드', '50만원이상'             , 12, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   -- 중단사유분류코드
	   ,( 'DMMM10',  '1', '중단사유분류코드', '개인측면'     , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM10',  '2', '중단사유분류코드', '기관측면'     , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM10',  '3', '중단사유분류코드', '시스템측면'   , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMMM10',  '4', '중단사유분류코드', '기타'         , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   
	   -- 결연기록구분코드
	   ,( 'DMRM01',  '1', '결연기록구분코드', '결연기록있음'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM01',  '2', '결연기록구분코드', '결연기록없음'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 결연기록구분코드
	   ,( 'DMRM02',  '1', '사업장상태코드', '신규'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM02',  '2', '사업장상태코드', '기존'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM02',  '3', '사업장상태코드', '종결'   , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 결연유지기간코드
	   ,( 'DMRM03',  '1', '결연유지기간코드', '1년미만'           , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM03',  '2', '결연유지기간코드', '1년이상~5년미만'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM03',  '3', '결연유지기간코드', '5년이상~10년미만'  , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM03',  '4', '결연유지기간코드', '10년이상'          , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 결연회원유형코드
	   ,( 'DMRM04',  '1', '결연회원유형코드', '결연회원'            , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM04',  '2', '결연회원유형코드', '1:2이상&3만미만결연회원' , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM04',  '3', '결연회원유형코드', '1:2이상결연회원'       , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMRM04',  '4', '결연회원유형코드', '3만원미만결연회원'       , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 회원유형코드
	   ,( 'DMRM05',  '1', '회원유형코드', '일반회원'        , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM05',  '2', '회원유형코드', '기업매칭회원'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 아동성별코드
	   ,( 'DMRM06',  'F', '아동성별코드', '여자'        , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMRM06',  'M', '아동성별코드', '남자'        , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )


	   -- 기준년월구분코드
	   ,( 'DMPM01',  '1', '기준년월구분코드', '납입일자'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM01',  '2', '기준년월구분코드', '환급일자'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 정기일시회비구분코드
	   ,( 'DMPM02',  '1', '정기일시회비구분코드', '정기회비'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM02',  '2', '정기일시회비구분코드', '일시회비'    , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 함께출금구분코드
	   ,( 'DMPM03',  '1', '함께출금구분코드', '청구'      , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM03',  '2', '함께출금구분코드', '출금'      , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM03',  '3', '함께출금구분코드', '미출금'     , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM03',  '4', '함께출금구분코드', '미청구'     , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMPM03',  '5', '함께출금구분코드', '환급'      , 5, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMPM03',  '9', '함께출금구분코드', '함께출금'    , 6, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 회비통장작업구분코드
	   ,( 'DMPM04',  '1', '회비통장작업구분코드', '회비종류별'     , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM04',  '2', '회비통장작업구분코드', '후원사업별'     , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM04',  '3', '회비통장작업구분코드', '가입회원별'     , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM04',  '4', '회비통장작업구분코드', '정기66회원현황' , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )


	   -- 66회원구분코드
	   ,( 'DMPM05',  '1', '66회원구분코드', '일시(비지정)'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM05',  '2', '66회원구분코드', '확인불가'       , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM05',  '3', '66회원구분코드', '회원확인'       , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 선물금이관구분코드
	   ,( 'DMPM06',  '1', '선물금이관구분코드', '이관(입)'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM06',  '2', '선물금이관구분코드', '이관(출)'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   
	   -- 환급방식코드
	   ,( 'DMPM07',  '1', '환급방식코드', '계좌환급'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM07',  '2', '환급방식코드', '승인취소'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 회비유형코드
	   ,( 'DMPM08',  '1', '회비유형코드', '일반회비'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM08',  '2', '회비유형코드', '지정회비'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 회비유형코드
	   ,( 'DMPM09',  '1', '고액기준대코드', '10만원이상~100만원미만'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM09',  '2', '고액기준대코드', '100만원이상~1000만원미만'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM09',  '3', '고액기준대코드', '1000만원이상'              , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   
	  	   -- 회비유형코드
	   ,( 'DMPM10',  '1', '정기일시미처리코드', '정기'    , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM10',  '2', '정기일시미처리코드', '일시'  , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM10',  '3', '정기일시미처리코드', '미처리'              , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 일시회비유형코드
	   ,( 'DMPM11',  '1', '회비유형코드', '지정'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM11',  '2', '회비유형코드', '비지정'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
 
	   -- 회비/기부금
	   ,( 'DMPM12',  '1', '회비기부금유형코드', '회비'   , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM12',  '2', '회비기부금유형코드', '기부금'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 청구출금구분코드
	   ,( 'DMPM13',  '11', '청구출금구분코드', '신규'      , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '12', '청구출금구분코드', '기존지정'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '13', '청구출금구분코드', '전차수미청구' , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '14', '청구출금구분코드', '재청구'     , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '22', '청구출금구분코드', '출금'      , 5, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '33', '청구출금구분코드', '미출금'     , 6, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM13',  '44', '청구출금구분코드', '미청구'     , 7, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMPM13',  '55', '청구출금구분코드', '환급'      , 8, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMPM13',  '99', '청구출금구분코드', '함께출금'    , 9, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

	   -- 청구출금구분코드
	   ,( 'DMPM14',  '1', '청구출금구분코드', '청구'      , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM14',  '2', '청구출금구분코드', '출금'      , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM14',  '3', '청구출금구분코드', '미출금'     , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM14',  '4', '청구출금구분코드', '미청구'     , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
       ,( 'DMPM14',  '5', '청구출금구분코드', '환급'      , 5, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )

/*
	   -- 미납서비스코드
	   ,( 'DMPM10',  '1', '미납서비스코드', '우편'     , 1, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM10',  '2', '미납서비스코드', '이메일'   , 2, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM10',  '3', '미납서비스코드', '문자'     , 3, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
	   ,( 'DMPM10',  '4', '미납서비스코드', 'TS'       , 4, '', 'Y', 'NA', 'NA', 'NA', 'dwdev',	@JOBDE,	'dwdev', @JOBDE, '','MART',  @WORKDE )
*/

    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : MART공통코드 Insert02: ' + CONVERT(VARCHAR(10), @v_numrows)	

INSERT INTO  [MART].[D_CMMN_DTL_CD] 
 SELECT 
      CD_ID,
	   CASE WHEN MVAL > 'A' AND MSIZE = 1 THEN 'Z' 
	        WHEN MVAL > 'A' AND MSIZE > 1 THEN 'Z~'  
	        WHEN MVAL < 'A' AND MSIZE = 1 THEN '99' 
			WHEN MVAL < 'A' AND MSIZE = 2 THEN '999' 
			WHEN MVAL < 'A' AND MSIZE = 3 THEN '9999' 
			                              ELSE '99999'  END   DTL_CD_ID, 
	  CD_NM,
	  '없음' DTL_CD_NM,
	  999 SORT_ORDR,
	  '' RM ,
	  'Y' USE_YN,
	  '' CD_ATRB1,
	  '' CDATRB2,
	  '' CDATRB3,
	  FRST_RGSTR_ID,
	  FRST_REGIST_dT,
	  LAST_UPDUSR_ID,
	  LAST_UPDT_dT,
	  UPPER_CD_ID,
	  CD_TYP_CD,
	  WORK_DE
 FROM ( 
 SELECT  ROW_NUMBER() OVER ( PARTITION BY  CD_ID  ORDER BY DTL_CD_ID ASC ) RNUM, 
		 MAX( DATALENGTH( DTL_CD_ID ) )     OVER ( PARTITION BY  CD_ID  )  MSIZE,
         MAX(  DTL_CD_ID  )     OVER ( PARTITION BY  CD_ID  )  MVAL,
		 		  *
		   FROM MART.D_CMMN_DTL_CD
     ) A
WHERE  RNUM = 1 


    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : MART공통코드 Insert03: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_STRD_CAL_CD] (
	@i_ymd  AS VARCHAR(8), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_STRD_CAL_CD] 

DECLARE @i      AS INT
DECLARE @NOWDATE     AS DATETIME
DECLARE @WKDATE                  AS CHAR(8)

SET     @i = 1
WHILE   @i <= 365 * 60
BEGIN
  SET      @NOWDATE      = DATEADD(DAY, @i, '1969-12-31')
  SET      @WKDATE                   = CONVERT(CHAR(8), @NOWDATE, 112)

    INSERT INTO  [MART].[D_STRD_CAL_CD] WITH( TABLOCK ) 
    ( 
      SYMD ,              -- 기준일자
      YMD ,               -- 년월일
      YM ,                -- 년월  
      YY ,                -- 년
	  MM ,                -- 월
      DD ,                -- 일
      QQ ,                -- 분기
      BA ,                -- 반기
      DW ,                -- 요일
      HDAY_YN ,           -- 휴일유무
      HDAY_NM ,           -- 휴일명
      WORK_DE             -- 작업일자
    )

    SELECT
	  CONVERT(DATETIME,CONVERT(CHAR(10), @NOWDATE, 121))  SYMD,          -- 날짜
      CONVERT(CHAR(8), @NOWDATE, 112)  YMD ,          -- 날짜
	  CONVERT(CHAR(6), @NOWDATE, 112)  YM  ,          -- 년월
	  LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 4)  YY ,
	  RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2)  MM ,
	  RIGHT( CONVERT(CHAR(8), @NOWDATE, 112), 2)  DD ,
	  DATEPART(QQ,@NOWDATE) QQ, -- 분기 
	  CASE WHEN RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2) BETWEEN '01' AND '06' THEN '1' ELSE '2' END  BA, -- 전,후반기 
      DATENAME(DW, @NOWDATE) DW ,   -- 요일
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN 'Y' ELSE 'N' END HDAY_YN ,
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN DATENAME(DW, @NOWDATE)  END HDAY_NM ,
	  CONVERT(CHAR(8), GETDATE(), 112) WORK_DE 
SET      @i = @i + 1
END

SET      @NOWDATE      = DATEADD(DAY, 0, '9999-12-31')

    INSERT INTO  [MART].[D_STRD_CAL_CD] WITH( TABLOCK ) 
    ( 
      SYMD ,              -- 기준일자
      YMD ,               -- 년월일
      YM ,                -- 년월  
      YY ,                -- 년
	  MM ,                -- 월
      DD ,                -- 일
      QQ ,                -- 분기
      BA ,                -- 반기
      DW ,                -- 요일
      HDAY_YN ,           -- 휴일유무
      HDAY_NM ,           -- 휴일명
      WORK_DE             -- 작업일자
    )

    SELECT
	  CONVERT(DATETIME,CONVERT(CHAR(10), @NOWDATE, 121))  SYMD,          -- 날짜
      CONVERT(CHAR(8), @NOWDATE, 112)  YMD ,          -- 날짜
	  CONVERT(CHAR(6), @NOWDATE, 112)  YM  ,          -- 년월
	  LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 4)  YY ,
	  RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2)  MM ,
	  RIGHT( CONVERT(CHAR(8), @NOWDATE, 112), 2)  DD ,
	  DATEPART(QQ,@NOWDATE) QQ, -- 분기 
	  CASE WHEN RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2) BETWEEN '01' AND '06' THEN '1' ELSE '2' END  BA, -- 전,후반기 
      DATENAME(DW, @NOWDATE) DW ,   -- 요일
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN 'Y' ELSE 'N' END HDAY_YN ,
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN DATENAME(DW, @NOWDATE)  END HDAY_NM ,
	  CONVERT(CHAR(8), GETDATE(), 112) WORK_DE 


SET      @NOWDATE      = DATEADD(DAY, 0, '1900-01-01')

    INSERT INTO  [MART].[D_STRD_CAL_CD] WITH( TABLOCK ) 
    ( 
      SYMD ,              -- 기준일자
      YMD ,               -- 년월일
      YM ,                -- 년월  
      YY ,                -- 년
	  MM ,                -- 월
      DD ,                -- 일
      QQ ,                -- 분기
      BA ,                -- 반기
      DW ,                -- 요일
      HDAY_YN ,           -- 휴일유무
      HDAY_NM ,           -- 휴일명
      WORK_DE             -- 작업일자
    )

    SELECT
	  CONVERT(DATETIME,CONVERT(CHAR(10), @NOWDATE, 121))  SYMD,          -- 날짜
      CONVERT(CHAR(8), @NOWDATE, 112)  YMD ,          -- 날짜
	  CONVERT(CHAR(6), @NOWDATE, 112)  YM  ,          -- 년월
	  LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 4)  YY ,
	  RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2)  MM ,
	  RIGHT( CONVERT(CHAR(8), @NOWDATE, 112), 2)  DD ,
	  DATEPART(QQ,@NOWDATE) QQ, -- 분기 
	  CASE WHEN RIGHT( LEFT( CONVERT(CHAR(8), @NOWDATE, 112), 6),2) BETWEEN '01' AND '06' THEN '1' ELSE '2' END  BA, -- 전,후반기 
      DATENAME(DW, @NOWDATE) DW ,   -- 요일
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN 'Y' ELSE 'N' END HDAY_YN ,
	  CASE WHEN DATENAME(DW, @NOWDATE) IN ( '토요일','일요일' ) THEN DATENAME(DW, @NOWDATE)  END HDAY_NM ,
	  CONVERT(CHAR(8), GETDATE(), 112) WORK_DE 
	  
	  
    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 : 달력생성 Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END

GO

-- ======================================================================

CREATE PROCEDURE  [mart].[USP_D_MBER_DVLP_GOAL_CD] (
	@i_ym   AS VARCHAR(6), 
	@i_oper AS VARCHAR(20), 
	@o_msg  AS VARCHAR(1000) OUTPUT 
	)
AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DECLARE @v_numrows AS INT 

  BEGIN TRY 
  BEGIN TRAN	 

    TRUNCATE TABLE  [MART].[D_MBER_DVLP_GOAL_CD] 

    INSERT INTO  [MART].[D_MBER_DVLP_GOAL_CD] 
    ( 
      STDYY ,                      -- 기준년
      STDR_MT ,                    -- 기준년월
      MBER_DVLP_DIV_CD ,           -- 회원개발구분코드
      DEPT_ID ,                    -- 부서ID
      GOAL_CNT ,                   -- 목표건수
      FRST_RGSTR_ID ,              -- 최초등록자ID
      FRST_REGIST_DT ,             -- 최초등록일시
      LAST_UPDUSR_ID ,             -- 최종수정자ID
      LAST_UPDT_DT ,               -- 최종수정일시
      WORK_DE                    -- 작업일자
    )
    SELECT DISTINCT 
      STDYY ,                     
      STDR_MT ,                   
      MBER_DVLP_DIV_CD ,          
      DEPT_ID ,                   
      GOAL_CNT ,                  
      FRST_RGSTR_ID ,             
      FRST_REGIST_DT ,            
      LAST_UPDUSR_ID ,            
      LAST_UPDT_DT ,              
      CONVERT( CHAR(8) , GETDATE(), 112) WORK_DE  
    FROM MSTR_ODS.DBO.TM_CM_MBER_DVLP_GOAL
    WHERE 1 = 1

    SET @v_numrows = @@rowcount
    SET @o_msg = '일배치 :D_회원개발목표Insert: ' + CONVERT(VARCHAR(10), @v_numrows)	

    EXEC MART.USP_BCHLOG NULL, @@PROCID, @i_oper, @o_msg

  COMMIT TRAN;
  END TRY

  BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
    ROLLBACK TRAN
    END

    DECLARE @v_errnum AS INT
    SET @v_errnum = ERROR_NUMBER()

    EXEC MART.USP_BCHERR NULL, @@PROCID, @i_oper, @v_errnum OUTPUT, @o_msg OUTPUT
  END CATCH

END 
GO

-- ======================================================================

CREATE PROCEDURE [mart].[USP_BCHLOG]
	@i_runkey AS INT,
	@i_logproc AS INT,
	@i_logman AS VARCHAR(20),
	@i_logmsg AS NVARCHAR(1000)
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			
	BEGIN TRY
	    -- 배치로그 저장
		INSERT INTO mart.bchlog
				( 
				  logtime
				, runkey
				, logmsg
				, logproc
				, logman
				, almyn )
		VALUES	( 
		          GETDATE()
				, @i_runkey
				, @i_logmsg
				, OBJECT_NAME(@i_logproc)
				, @i_logman
				, 0 )

	 
	
	END TRY
	BEGIN CATCH
		-- Raise error so that caller will determine what to do with
		-- the failure in the proc
		PRINT 'Error ' + CONVERT(VARCHAR(50), ERROR_NUMBER()) +
					 ' , Severity '  + CONVERT(VARCHAR(5), ERROR_SEVERITY()) +
					 ' , State '     + CONVERT(VARCHAR(5), ERROR_STATE()) +
					 ' , Procedure ' + ISNULL(ERROR_PROCEDURE(), '-') +
					 ' , Line '      + CONVERT(VARCHAR(5), ERROR_LINE());
		PRINT ERROR_MESSAGE();
		
		RETURN -1;
	END CATCH
	
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
END;


GO

-- ======================================================================

CREATE PROCEDURE [mart].[USP_BCHERR]
	@i_runkey AS INT,
	@i_logproc AS INT,
	@i_logman AS VARCHAR(20),
	@o_errnum AS INT OUTPUT,
	@o_msg AS  VARCHAR(1000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @v_errnum AS INT,
			@v_logmsg AS NVARCHAR(1000),
			@v_errmsg AS NVARCHAR(2048),
			@v_errnote AS NVARCHAR(1000);

	IF ERROR_NUMBER() IS NULL
		RETURN;
			
	-- 사용자정의 에러 처리
	IF ERROR_NUMBER() = 50000
	BEGIN
		SET @v_errnum = @o_errnum;
		
		SELECT @v_errmsg = subcdnm 
		FROM   feecd
		WHERE  pricd = 9
		AND    subcd = CONVERT(VARCHAR(10), @v_errnum);
		
		SET @v_logmsg = 'Error#' + CONVERT(VARCHAR(5), @v_errnum) + ': ' + @v_errmsg; 
	END
	ELSE
	BEGIN
		SET @v_errnum = ERROR_NUMBER();
		SET @v_errmsg = ERROR_MESSAGE();
		SET @v_logmsg = 'Error#' + CONVERT(VARCHAR(5), @v_errnum) + ': 기타오류'; 
	END

	--상황에 맞는 사용자 친화적 메시지 세팅
	IF ERROR_NUMBER() = 2627
	BEGIN
		SET @v_errnote =  'PRIMARY KEY 또는 UNIQUE 위배함.(PK/AK 제약조건)'
	END
	ELSE IF ERROR_NUMBER() = 547
	BEGIN
		SET @v_errnote =  '다른 테이블에서 참조함.(FK 제약조건)'
	END
	ELSE IF ERROR_NUMBER() = 515
	BEGIN
		SET @v_errnote =  'NULL값이 들어갈수 없음.(NOT NULL 제약조건)'
	END
	ELSE IF ERROR_NUMBER() = 245
	BEGIN
		SET @v_errnote =  '데이터타입 변환 오류.'
	END
	ELSE IF ERROR_NUMBER() = 50000
	BEGIN
		SET @v_errnote =  '사용자정의 오류.'
	END
	ELSE
	BEGIN
		SET @v_errnote =  NULL --'Handling unknown error...'
	END
	
	SET @o_msg = @v_logmsg;
			
	BEGIN TRY
				
		-- 에러로그 파일쓰기
/* 2019-09-05 주석처리 소스 없음.
		SELECT mart.fnFileWriteLine(CONVERT(CHAR(23), CURRENT_TIMESTAMP, 21) +
								'|' + CONVERT(VARCHAR(10), @i_runkey) +
								'|' + @v_logmsg +
								'|' + OBJECT_NAME(@i_logproc) +
								'|' + @i_logman +
								'|' + CONVERT(VARCHAR(50), ERROR_NUMBER()) +
								'|' + CONVERT(VARCHAR(5), ERROR_SEVERITY()) +
								'|' + CONVERT(VARCHAR(5), ERROR_STATE()) +
								'|' + CONVERT(VARCHAR(5), ERROR_LINE()) +
								'|' + @v_errmsg +
								'|' + @v_errnote
								, 'X:/GOODCRM/04FeeFile/Log/' + CONVERT(VARCHAR(10), @i_runkey) + '.log', 1);
*/								
		-- 에러로그 저장
		INSERT INTO mart.bchlog
				( logtime
				, runkey
				, logmsg
				, logproc
				, logman
				, errnum
				, errseverity
				, errstts
				, errline
				, errmsg
				, errnote
				, almyn )
		VALUES	( GETDATE()
				, @i_runkey
				, @v_logmsg
				, OBJECT_NAME(@i_logproc)
				, @i_logman
				, @v_errnum
				, ERROR_SEVERITY()
				, ERROR_STATE()
				, ERROR_LINE()
				, @v_errmsg
				, @v_errnote
				, 0 );
    
	PRINT ERROR_MESSAGE();
	
	END TRY
	BEGIN CATCH
		-- Raise error so that caller will determine what to do with
		-- the failure in the proc
		PRINT 'Error ' + CONVERT(VARCHAR(50), ERROR_NUMBER()) +
					', Severity ' + CONVERT(VARCHAR(5), ERROR_SEVERITY()) +
					', State ' + CONVERT(VARCHAR(5), ERROR_STATE()) +
					', Procedure ' + ISNULL(ERROR_PROCEDURE(), '-') +
					', Line ' + CONVERT(VARCHAR(5), ERROR_LINE());
		PRINT ERROR_MESSAGE();
		
		RETURN -1;
	END CATCH
	
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
END;

GO

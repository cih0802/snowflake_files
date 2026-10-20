CREATE TABLE [mart].[F_MM_SPNSR_DVLP_SUM](
	[STRD_MT] [varchar](6) NOT NULL,
	[OCCRRNC_DE] [varchar](8) NOT NULL,
	[SPNSR_NO] [varchar](9) NOT NULL,
	[SPNSR_BSNS_NO] [bigint] NOT NULL,
	[SER_NO] [int] NOT NULL,
	[MBER_NO] [varchar](10) NULL,
	[ACT_DEPT_CD] [varchar](10) NULL,
	[ACMSLT_DEPT_CD] [varchar](10) NULL,
	[ACMSLT_DEPT2_CD] [varchar](10) NULL,
	[ACMSLT_DEPT3_CD] [varchar](10) NULL,
	[ACMSLT_DEPT4_CD] [varchar](10) NULL,
	[CMPGN_CD] [varchar](20) NULL,
	[CMPGN_CLS1_CD] [varchar](3) NULL,
	[CMPGN_CLS2_CD] [varchar](3) NULL,
	[CMPGN_CLS3_CD] [varchar](3) NULL,
	[UPPER_CMPGN_CD] [varchar](20) NULL,
	[BRND_ID] [varchar](30) NULL,
	[PR_MTH_CD] [varchar](3) NULL,
	[SPCL_CMPGN_YN] [char](1) NULL,
	[PRE_CMPGN_CD] [varchar](20) NULL,
	[SETLE_CD] [varchar](3) NULL,
	[MBER_DIV_CD] [varchar](3) NULL,
	[SEX] [varchar](2) NULL,
	[AREA_CD] [varchar](3) NULL,
	[AGE_TERM_CD] [varchar](3) NULL,
	[AGE] [int] NULL,
	[PAYER_AGE_TERM_CD] [varchar](3) NULL,
	[SPNSR_TIME_CO] [int] NULL,
	[SPNSR_TERM_MT_CNT] [smallint] NULL,
	[SPNSR_TERM_CD] [varchar](3) NULL,
	[SPNSR_AMT_CD] [varchar](3) NULL,
	[SPNSR_TERM2_CD] [varchar](3) NULL,
	[SPNSR_AMT2_CD] [varchar](3) NULL,
	[SPNSR_BSNS_ID] [varchar](20) NULL,
	[SPNSR_BSNS2_ID] [varchar](20) NULL,
	[SPNSR_BSNS_ABRV_CD] [varchar](3) NULL,
	[CPR_DIV_CD] [varchar](3) NULL,
	[CANCL_RDCAMT_RSN_CD] [varchar](3) NULL,
	[SPNSR_AMT] [bigint] NULL,
	[SPNSR_AMT_CNT] [float] NULL,
	[MT_GOAL_CNT] [int] NULL,
	[YY_GOAL_CNT] [int] NULL,
	[DVLP_DIV_CD] [varchar](3) NULL,
	[DVLP_CNT] [int] NULL,
	[RDCAMT_YN] [char](1) NULL,
	[MT_ADD_SPNSR_AMT_YN] [char](1) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
	[NEW_OLD_DIV_CD] [varchar](20) NULL,
 CONSTRAINT [F_MM_SPNSR_DVLP_SUM_PK] PRIMARY KEY NONCLUSTERED 
(
	[STRD_MT] ASC,
	[OCCRRNC_DE] ASC,
	[SPNSR_NO] ASC,
	[SPNSR_BSNS_NO] ASC,
	[SER_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[F_MM_SPNSR_DVLP](
	[STRD_MT] [varchar](6) NOT NULL,
	[OCCRRNC_DE] [varchar](8) NOT NULL,
	[SPNSR_NO] [varchar](9) NOT NULL,
	[SPNSR_BSNS_NO] [bigint] NOT NULL,
	[SER_NO] [int] NOT NULL,
	[MBER_NO] [varchar](10) NULL,
	[ACT_DEPT_CD] [varchar](10) NULL,
	[ACMSLT_DEPT_CD] [varchar](10) NULL,
	[ACMSLT_DEPT2_CD] [varchar](10) NULL,
	[ACMSLT_DEPT3_CD] [varchar](10) NULL,
	[ACMSLT_DEPT4_CD] [varchar](10) NULL,
	[CMPGN_CD] [varchar](20) NULL,
	[CMPGN_CLS1_CD] [varchar](3) NULL,
	[CMPGN_CLS2_CD] [varchar](3) NULL,
	[CMPGN_CLS3_CD] [varchar](3) NULL,
	[UPPER_CMPGN_CD] [varchar](20) NULL,
	[BRND_ID] [varchar](30) NULL,
	[PR_MTH_CD] [varchar](3) NULL,
	[SPCL_CMPGN_YN] [char](1) NULL,
	[PRE_CMPGN_CD] [varchar](20) NULL,
	[SETLE_CD] [varchar](3) NULL,
	[MBER_DIV_CD] [varchar](3) NULL,
	[SEX] [varchar](2) NULL,
	[AREA_CD] [varchar](3) NULL,
	[AGE_TERM_CD] [varchar](3) NULL,
	[AGE] [int] NULL,
	[PAYER_AGE_TERM_CD] [varchar](3) NULL,
	[SPNSR_TIME_CO] [int] NULL,
	[SPNSR_TERM_MT_CNT] [smallint] NULL,
	[SPNSR_TERM_CD] [varchar](3) NULL,
	[SPNSR_AMT_CD] [varchar](3) NULL,
	[SPNSR_TERM2_CD] [varchar](3) NULL,
	[SPNSR_AMT2_CD] [varchar](3) NULL,
	[SPNSR_BSNS_ID] [varchar](20) NULL,
	[SPNSR_BSNS_ABRV_CD] [varchar](3) NULL,
	[CPR_DIV_CD] [varchar](3) NULL,
	[CANCL_RDCAMT_RSN_CD] [varchar](3) NULL,
	[SPNSR_AMT] [bigint] NULL,
	[SPNSR_AMT_CNT] [float] NULL,
	[MT_GOAL_CNT] [int] NULL,
	[YY_GOAL_CNT] [int] NULL,
	[DVLP_DIV_CD] [varchar](3) NULL,
	[DVLP_CNT] [int] NULL,
	[RDCAMT_YN] [char](1) NULL,
	[MT_ADD_SPNSR_AMT_YN] [char](1) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [F_MM_SPNSR_DVLP_PK] PRIMARY KEY NONCLUSTERED 
(
	[STRD_MT] ASC,
	[OCCRRNC_DE] ASC,
	[SPNSR_NO] ASC,
	[SPNSR_BSNS_NO] ASC,
	[SER_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_BRND_CD](
	[BRND_ID] [varchar](30) NOT NULL,
	[BRND_NM] [varchar](200) NULL,
	[USE_DEPT_CD] [varchar](10) NULL,
	[USE_YN] [char](1) NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[PR_MTH_LIST] [varchar](4000) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_BRND_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[BRND_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_CMPGN_CD](
	[CMPGN_CD] [varchar](20) NOT NULL,
	[CMPGN_NM] [varchar](200) NULL,
	[UPPER_CMPGN_CD] [varchar](20) NULL,
	[UPPER_CMPGN_YN] [char](1) NULL,
	[SPNSR_DIV_CD] [varchar](3) NULL,
	[CPR_DIV_CD] [varchar](3) NULL,
	[CMPGN_TRGET_CD] [varchar](2) NULL,
	[USE_DEPT_CD] [varchar](10) NULL,
	[USE_SCOPE] [char](1) NULL,
	[SPNSR_ENTRPRS_ID] [varchar](20) NULL,
	[BRND_ID] [varchar](30) NOT NULL,
	[PR_MTH_CD] [varchar](3) NULL,
	[CMPGN_STRT_DE] [varchar](8) NULL,
	[MBRFEE_BNKB_LIST] [varchar](4000) NULL,
	[INICIS_ACNT_NO] [varchar](50) NULL,
	[USE_YN] [char](1) NULL,
	[REFER_URL] [varchar](255) NULL,
	[SPNSR_BSNS_ID] [varchar](100) NULL,
	[ATCHFL_ID] [varchar](20) NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[CMPGN_DC] [varchar](500) NULL,
	[EMRGNCY_AID_BPLC_CD] [int] NULL,
	[SPCL_CMPGN_YN] [char](1) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_CMPGN_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[CMPGN_CD] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_SPNSR_BSNS_INFO](
	[SPNSR_BSNS_ID] [varchar](20) NOT NULL,
	[SPNSR_DIV_CD] [varchar](3) NULL,
	[SPNSR_BSNS_NM] [varchar](50) NULL,
	[SPNSR_BSNS_ABRV_CD] [varchar](3) NULL,
	[DNTN_TY_CD] [varchar](3) NULL,
	[SORT_ORDR] [int] NULL,
	[CPR_DIV_CD] [varchar](3) NULL,
	[RM] [varchar](1000) NULL,
	[USE_YN] [char](1) NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_SPNSR_BSNS_INFO_PK] PRIMARY KEY NONCLUSTERED 
(
	[SPNSR_BSNS_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_CMMN_DTL_CD](
	[CD_ID] [varchar](20) NOT NULL,
	[DTL_CD_ID] [varchar](50) NOT NULL,
	[CD_NM] [varchar](500) NOT NULL,
	[DTL_CD_NM] [varchar](500) NOT NULL,
	[SORT_ORDR] [int] NULL,
	[RM] [varchar](1000) NULL,
	[USE_YN] [varchar](1) NULL,
	[CD_ATRB1] [varchar](100) NULL,
	[CD_ATRB2] [varchar](100) NULL,
	[CD_ATRB3] [varchar](100) NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[UPPER_CD_ID] [varchar](20) NULL,
	[CD_TYP_CD] [varchar](5) NULL,
	[WORK_DE] [varchar](8) NULL,
 CONSTRAINT [D_CMMN_DTL_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[CD_ID] ASC,
	[DTL_CD_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_STRD_CAL_CD](
	[SYMD] [date] NOT NULL,
	[YMD] [varchar](8) NULL,
	[YM] [varchar](6) NULL,
	[YY] [varchar](4) NULL,
	[MM] [varchar](2) NULL,
	[DD] [varchar](2) NULL,
	[QQ] [varchar](2) NULL,
	[BA] [varchar](2) NULL,
	[DW] [varchar](10) NULL,
	[HDAY_YN] [char](1) NULL,
	[HDAY_NM] [varchar](50) NULL,
	[WORK_DE] [varchar](8) NULL,
 CONSTRAINT [D_STRD_CAL_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[SYMD] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_CM_DEPT_INFO](
	[DEPT_ID] [varchar](20) NOT NULL,
	[DEPT_NM] [varchar](50) NULL,
	[UPPER_DEPT_ID] [varchar](20) NULL,
	[SORT_ORDR] [int] NULL,
	[USE_YN] [char](1) NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[ACMSLT_DEPT_YN] [char](1) NULL,
	[STATS_DEPT_LVL] [tinyint] NULL,
	[ACMSLT_UPPER_DEPT_ID] [varchar](20) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_CM_DEPT_INFO_PK] PRIMARY KEY NONCLUSTERED 
(
	[DEPT_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_MBER_DVLP_GOAL_CD](
	[STDYY] [varchar](4) NOT NULL,
	[STDR_MT] [varchar](6) NOT NULL,
	[MBER_DVLP_DIV_CD] [char](1) NOT NULL,
	[DEPT_ID] [varchar](20) NOT NULL,
	[GOAL_CNT] [int] NULL,
	[FRST_RGSTR_ID] [varchar](30) NULL,
	[FRST_REGIST_DT] [datetime] NULL,
	[LAST_UPDUSR_ID] [varchar](30) NULL,
	[LAST_UPDT_DT] [datetime] NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_MBER_DVLP_GOAL_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[STDYY] ASC,
	[STDR_MT] ASC,
	[MBER_DVLP_DIV_CD] ASC,
	[DEPT_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[BchLog](
	[LogKey] [int] IDENTITY(-2147483648,1) NOT NULL,
	[LogTime] [datetime] NOT NULL,
	[RunKey] [bigint] NULL,
	[LogMsg] [varchar](1000) NULL,
	[LogProc] [nvarchar](126) NULL,
	[LogMan] [varchar](20) NULL,
	[ErrNum] [int] NULL,
	[ErrSeverity] [int] NULL,
	[ErrStts] [int] NULL,
	[ErrLine] [int] NULL,
	[ErrMsg] [nvarchar](2048) NULL,
	[ErrNote] [nvarchar](1000) NULL,
	[AlmYn] [bit] NULL,
 CONSTRAINT [BchLog_PK] PRIMARY KEY NONCLUSTERED 
(
	[LogKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- ======================================================================

CREATE TABLE [mart].[D_CMPGN_EXPL_CD](
	[CMPGN_CD] [varchar](20) NOT NULL,
	[CMPGN_NM] [varchar](200) NULL,
	[CMPGN_CLS_CD] [varchar](20) NOT NULL,
	[UPPER_CMPGN_CD] [varchar](20) NULL,
	[UPPER_CMPGN_NM] [varchar](200) NULL,
	[PR_MTH_CD] [varchar](3) NULL,
	[USE_DEPT_CD] [varchar](20) NULL,
	[COMMENT] [varchar](200) NULL,
	[WORK_DE] [varchar](8) NOT NULL,
 CONSTRAINT [D_CMPGN_EXPL_CD_PK] PRIMARY KEY NONCLUSTERED 
(
	[CMPGN_CD] ASC,
	[CMPGN_CLS_CD] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

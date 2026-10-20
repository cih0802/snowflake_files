select	a11.STRD_MT  STRD_MT,
	max(a117.STRD_NM)  STRD_NM,
	a11.OCCRRNC_DE  STRD_DE,
	max(a13.STRD_NM)  STRD_NM0,
	a11.ACMSLT_DEPT4_CD  DEPT4_ID,
	max(a15.DEPT4_NM)  DEPT4_NM,
	max(a15.SORT_ORDR)  SORT_ORDR,
	a11.ACMSLT_DEPT3_CD  DEPT3_ID,
	max(a18.DEPT3_NM)  DEPT3_NM,
	max(a18.SORT_ORDR)  SORT_ORDR0,
	a11.ACMSLT_DEPT2_CD  DEPT2_ID,
	max(a113.DEPT2_NM)  DEPT2_NM,
	max(a113.SORT_ORDR)  SORT_ORDR1,
	a11.DVLP_DIV_CD  DVLP_DIV_CD,
	max(a12.DVLP_DIV_NM)  DVLP_DIV_NM,
	max(a12.SORT_ORDR)  SORT_ORDR2,
	a11.BRND_ID  BRND_ID,
	max(a17.BRND_NM)  BRND_NM,
	a11.CMPGN_CD  CMPGN_CD,
	max(a112.CMPGN_NM)  CMPGN_NM,
	a11.UPPER_CMPGN_CD  UPPER_CMPGN_CD,
	max(a19.UPPER_CMPGN_NM)  UPPER_CMPGN_NM,
	max(a19.SORT_ORDR)  SORT_ORDR3,
	a11.PR_MTH_CD  PR_MTH_CD,
	max(a114.PR_MTH_NM)  PR_MTH_NM,
	a11.CPR_DIV_CD  CPR_DIV_CD,
	max(a14.CPR_DIV_NM)  CPR_DIV_NM,
	a11.SPNSR_BSNS_ID  SPNSR_BSNS_ID,
	max(a115.SPNSR_BSNS_NM)  SPNSR_BSNS_NM,
	max(a115.SORT_ORDR)  SORT_ORDR4,
	a11.SPNSR_BSNS2_ID  SPNSR_BSNS2_ID,
	max(a116.SPNSR_BSNS_NM)  SPNSR_BSNS_NM0,
	max(a116.SORT_ORDR)  SORT_ORDR5,
	a11.ACMSLT_DEPT_CD  DEPT_ID,
	max(a16.DEPT_NM)  DEPT_NM,
	a11.SEX  SEX_CD,
	max(a110.SEX_NM)  SEX_NM,
	max(a110.SORT_ORDR)  SORT_ORDR6,
	a11.AGE_TERM_CD  AGE_TERM_CD,
	max(a111.AGE_TERM_NM)  AGE_TERM_NM,
	max(a111.SORT_ORDR)  SORT_ORDR7,
	sum(a11.SPNSR_AMT_CNT)  WJXBFS1,
	count(distinct a11.MBER_NO)  WJXBFS2,
	sum(a11.SPNSR_AMT)  WJXBFS3
from	mart.F_MM_SPNSR_DVLP_SUM	a11
	left outer join	mart.D_DVLP_DIV_CD	a12
	  on 	(a11.DVLP_DIV_CD = a12.DVLP_DIV_CD)
	left outer join	mart.D_STRD_DE_CD	a13
	  on 	(a11.OCCRRNC_DE = a13.STRD_DE)
	left outer join	mart.D_CPR_DIV_CD	a14
	  on 	(a11.CPR_DIV_CD = a14.CPR_DIV_CD)
	left outer join	mart.D_DEPT4_CD	a15
	  on 	(a11.ACMSLT_DEPT4_CD = a15.DEPT4_ID)
	left outer join	mart.D_DEPT_CD	a16
	  on 	(a11.ACMSLT_DEPT_CD = a16.DEPT_ID)
	left outer join	mart.D_BRND_CD	a17
	  on 	(a11.BRND_ID = a17.BRND_ID)
	left outer join	mart.D_DEPT3_CD	a18
	  on 	(a11.ACMSLT_DEPT3_CD = a18.DEPT3_ID)
	left outer join	mart.D_UP_CMPGN_CD	a19
	  on 	(a11.UPPER_CMPGN_CD = a19.UPPER_CMPGN_CD)
	left outer join	mart.D_SEX_CD	a110
	  on 	(a11.SEX = a110.SEX_CD)
	left outer join	mart.D_AGE_TERM_CD	a111
	  on 	(a11.AGE_TERM_CD = a111.AGE_TERM_CD)
	left outer join	mart.D_CMPGN_CD	a112
	  on 	(a11.CMPGN_CD = a112.CMPGN_CD)
	left outer join	mart.D_DEPT2_CD	a113
	  on 	(a11.ACMSLT_DEPT2_CD = a113.DEPT2_ID)
	left outer join	mart.D_PR_MTH_CD	a114
	  on 	(a11.PR_MTH_CD = a114.PR_MTH_CD)
	left outer join	mart.D_SPNSR_BSNS_INFO	a115
	  on 	(a11.SPNSR_BSNS_ID = a115.SPNSR_BSNS_ID)
	left outer join	mart.D_SPNSR_BSNS_INFO	a116
	  on 	(a11.SPNSR_BSNS2_ID = a116.SPNSR_BSNS_ID)
	left outer join	mart.D_STRD_MT_CD	a117
	  on 	(a11.STRD_MT = a117.STRD_MT)
where	(a11.OCCRRNC_DE >=  '20260101'
and a11.OCCRRNC_DE <=  '20260131'
and a11.DVLP_DIV_CD in ('1', '2', '4'))
group by	a11.STRD_MT,
	a11.OCCRRNC_DE,
	a11.ACMSLT_DEPT4_CD,
	a11.ACMSLT_DEPT3_CD,
	a11.ACMSLT_DEPT2_CD,
	a11.DVLP_DIV_CD,
	a11.BRND_ID,
	a11.CMPGN_CD,
	a11.UPPER_CMPGN_CD,
	a11.PR_MTH_CD,
	a11.CPR_DIV_CD,
	a11.SPNSR_BSNS_ID,
	a11.SPNSR_BSNS2_ID,
	a11.ACMSLT_DEPT_CD,
	a11.SEX,
	a11.AGE_TERM_CD
 
[분석엔진 계산 단계:
	1.  Perform dynamic aggregation over <사업부/시도권역, 홍보방법, 후원사업>
 
	
	select	[개발구분]@[DVLP_DIV_CD],
		[개발구분]@[DVLP_DIV_NM],
		[개발구분]@[SORT_ORDR],
		[기준년월]@[STRD_MT],
		[기준년월]@[STRD_NM],
		[기준일자]@[STRD_DE],
		[기준일자]@[STRD_NM],
		[법인]@[CPR_DIV_CD],
		[법인]@[CPR_DIV_NM],
		[본부/지부]@[DEPT4_ID],
		[본부/지부]@[DEPT4_NM],
		[본부/지부]@[SORT_ORDR],
		[부서]@[DEPT_ID],
		[부서]@[DEPT_NM],
		[브랜드]@[BRND_ID],
		[브랜드]@[BRND_NM],
		[상위캠페인]@[UPPER_CMPGN_CD],
		[상위캠페인]@[UPPER_CMPGN_NM],
		[상위캠페인]@[SORT_ORDR],
		[성별]@[SEX_CD],
		[성별]@[SEX_NM],
		[성별]@[SORT_ORDR],
		[연령대]@[AGE_TERM_CD],
		[연령대]@[AGE_TERM_NM],
		[연령대]@[SORT_ORDR],
		[캠페인]@[CMPGN_CD],
		[캠페인]@[CMPGN_NM],
		[팀/지부]@[DEPT2_ID],
		[팀/지부]@[DEPT2_NM],
		[팀/지부]@[SORT_ORDR],
		[후원사업2]@[SPNSR_BSNS2_ID],
		[후원사업2]@[SPNSR_BSNS_NM],
		[후원사업2]@[SORT_ORDR],
		sum([개발(건)])@{[개발구분],[기준일자],[법인],[본부/지부],[부서],[브랜드],[상위캠페인],[성별],[연령대],[캠페인],[팀/지부],[후원사업2]},
		sum([개발(명)])@{[개발구분],[기준일자],[법인],[본부/지부],[부서],[브랜드],[상위캠페인],[성별],[연령대],[캠페인],[팀/지부],[후원사업2]}
	from	일별&월별_로우(CP포함_4자리)
	2.  cross-tabbing 수행
]
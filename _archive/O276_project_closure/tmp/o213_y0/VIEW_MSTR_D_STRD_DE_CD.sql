create or replace view D_STRD_DE_CD(
	STRD_DE,
	STRD_NM,
	STRD_PRE_DE,
	STRD_PRE_MT_DE,
	STRD_PRE_YMT_DE,
	STRD_MT,
	STRD_QT,
	STRD_YY,
	MT_ID,
	WORK_DE
) COMMENT='기준일자. 9999-12-31 은 STRD_NM=N/A'
 as
SELECT
  YMD                                            AS STRD_DE,
  CASE WHEN YMD = '99991231' THEN 'N/A'
       ELSE TO_CHAR(SYMD, 'YYYY-MM-DD') END      AS STRD_NM,
  TO_CHAR(DATEADD(DAY,   -1, SYMD), 'YYYYMMDD')  AS STRD_PRE_DE,
  TO_CHAR(DATEADD(MONTH, -1, SYMD), 'YYYYMMDD')  AS STRD_PRE_MT_DE,
  TO_CHAR(DATEADD(YEAR,  -1, SYMD), 'YYYYMMDD')  AS STRD_PRE_YMT_DE,
  LEFT(YMD, 6)                                   AS STRD_MT,
  QQ                                             AS STRD_QT,
  YY                                             AS STRD_YY,
  MM                                             AS MT_ID,
  TO_CHAR(CURRENT_DATE(), 'YYYYMMDD')            AS WORK_DE
FROM GN_DW.MSTR.D_STRD_CAL_CD;
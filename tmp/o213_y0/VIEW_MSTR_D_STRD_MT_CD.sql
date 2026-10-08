create or replace view D_STRD_MT_CD(
	STRD_MT,
	STRD_NM,
	PRE_STRD_MT,
	PRE_YY_STRD_MT,
	STRD_YY,
	STRD_QT,
	STRD_MM,
	PRE_YY_12_MT,
	PPRE_YY_12_MT
) COMMENT='기준년월'
 as
SELECT DISTINCT
  LEFT(YMD, 6)                                          AS STRD_MT,
  TO_CHAR(SYMD, 'YYYY-MM')                              AS STRD_NM,
  TO_CHAR(DATEADD(MONTH, -1, SYMD), 'YYYYMM')           AS PRE_STRD_MT,
  TO_CHAR(DATEADD(YEAR,  -1, SYMD), 'YYYYMM')           AS PRE_YY_STRD_MT,
  YY                                                    AS STRD_YY,
  QQ                                                    AS STRD_QT,
  MM                                                    AS STRD_MM,
  TO_CHAR(DATEADD(YEAR, -1, SYMD), 'YYYY') || '12'      AS PRE_YY_12_MT,
  TO_CHAR(DATEADD(YEAR, -2, SYMD), 'YYYY') || '12'      AS PPRE_YY_12_MT
FROM GN_DW.MSTR.D_STRD_CAL_CD;
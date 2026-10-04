import io
OLD = """    -- 후원사업별 최초(일련번호 순) 정상 개발건의 금액 · 이력 전체 대상(원본 동일)
    SELECT SPNSR_NO, SPNSR_BSNS_NO, STRD_MT, DVLP_DIV_CD AS DVLP_DIV_CD2,
           SPNSR_AMT AS SPNSR_AMT2
    FROM GN_DW.MSTR.F_MM_SPNSR_DVLP
    WHERE DVLP_DIV_CD IN ('1', '2', '4')
      AND IFNULL(CANCL_RDCAMT_RSN_CD, '999') = '999'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY SPNSR_NO, SPNSR_BSNS_NO ORDER BY SER_NO) = 1
  ) I"""
NEW = """    -- 후원사업별 최초(일련번호 순) 정상 개발건의 금액 · 이력 전체 대상(원본 동일)
    --   🆕 [O201-D] F_MM_SPNSR_DVLP 대신 원천(BRONZE)을 직접 읽는다 — F 의 SER_NO·SPNSR_AMT·DVLP_DIV_CD·
    --   CANCL_RDCAMT_RSN_CD 는 원천 그대로 복사한 값이라 결과가 같고, F 를 과거 전 월로 채우지 않아도 된다
    --   (운영계 = 2026-01 이후만 적재 · 개발계 202601 대조 = 행·코드 분포 동일 실측)
    SELECT SPNSR_NO, SPNSR_BSNS_NO, LEFT(OCCRRNC_DE, 6) AS STRD_MT, DVLP_DIV_CD AS DVLP_DIV_CD2,
           SPNSR_AMT AS SPNSR_AMT2
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
    WHERE DVLP_DIV_CD IN ('1', '2', '4')
      AND IFNULL(CANCL_RDCAMT_RSN_CD, '999') = '999'
      AND OCCRRNC_DE <= :I_YM || '31'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY SPNSR_NO, SPNSR_BSNS_NO ORDER BY SER_NO) = 1
  ) I"""
for p in ['/workspace/15_MSTR 이관 PoC/tools/templates/1차_04_sp_script.tmpl.sql',
          '/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/04_sp_script.sql']:
    s = io.open(p, encoding='utf-8').read()
    assert s.count(OLD) == 1, (p, s.count(OLD))
    s = s.replace(OLD, NEW, 1)
    io.open(p, 'w', encoding='utf-8').write(s)
    print('OK', p.split('/')[-1])

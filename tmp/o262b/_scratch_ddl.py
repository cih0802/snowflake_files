import io,re,sys
COLS=[ # (ddl file, schema, table, col, type, comment)
('04_silver_design/08_SILVER_테이블DDL_20260714.sql','SILVER','CRM_SEND_MEMBER','SND_FRST_SPNSR','VARCHAR','SND 발송 시점 최초 후원사업명(원천 SND_MEMBER_LIST.FRST_SPNSR · 타 채널 NULL) [O262-B]'),
('04_silver_design/08_SILVER_테이블DDL_20260714.sql','SILVER','CRM_SEND_MEMBER','SND_CHILD_DTL_NM','VARCHAR','SND 발송 시점 결연 상세상태명(원천 CHILD_DTL_NM · 결연중 등 · 타 채널 NULL) [O262-B]'),
('04_silver_design/08_SILVER_테이블DDL_20260714.sql','SILVER','CRM_SEND_MEMBER','SND_NATION_NM','VARCHAR','SND 발송 시점 결연아동 국가명(원천 NATION_NM · 타 채널 NULL) [O262-B]'),
('04_silver_design/08_SILVER_테이블DDL_20260714.sql','SILVER','CRM_SEND_MEMBER','SND_BPLC_KOR_NM','VARCHAR','SND 발송 시점 결연아동 사업장명(원천 BPLC_KOR_NM · 타 채널 NULL) [O262-B]'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_AD_PERFORMANCE','CMPGN_TYPE1_BSN_NM','VARCHAR','캠페인유형1(사업) 국내·해외·통합·전체 원값 [DGT 전용 · 그 밖 NULL] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_AD_PERFORMANCE','CMPGN_TYPE2_BSN_NM','VARCHAR','캠페인유형2(사업) 사례·사업·굿즈·기타·통합 원값 [DGT 전용] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_AD_PERFORMANCE','CMPGN_TY_NM','VARCHAR','캠페인유형(국내외×사업사례 결합 원값 · 예 해외 사례) [VIDEO 전용 · CTV 시트 외 NULL] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','DIM_SPONSORSHIP','DNTN_TY_CD','VARCHAR','기부유형 코드 raw(1·3 · 코드군 미특정 ⇒ 라벨 없음) [SILVER.CRM_SPONSORSHIP 승계] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_EXPENSE_RESOLUTION','BDGT_ITEM_NM','VARCHAR','예산항목명(원천 BDGT_ITEM_NM · 목·세목·세세목과 다른 축) (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','DIM_MEMBER','REGIST_DEPT_CD','VARCHAR','회원 등록부서 코드 raw(정기·일시 공통 · 개발 실적부서와 다른 축) [SILVER.CRM_MEMBER 승계] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_MEMBER_EVENT','REGIST_DEPT_CD','VARCHAR','중단 등록부서 코드 raw(STOP 행만 · DEV 행 NULL = 개념 부재 · 실적부서 ORG_SK 와 다른 축) (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_MESSAGE_DISPATCH','SND_FRST_SPNSR','VARCHAR','SND 발송 시점 최초 후원사업명 [SND 전용 · 타 채널 NULL] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_MESSAGE_DISPATCH','SND_CHILD_DTL_NM','VARCHAR','SND 발송 시점 결연 상세상태명 [SND 전용] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_MESSAGE_DISPATCH','SND_NATION_NM','VARCHAR','SND 발송 시점 결연아동 국가명 [SND 전용] (O262-B)'),
('03_top-down_gold/06_DDL.sql','GOLD','FACT_MESSAGE_DISPATCH','SND_BPLC_KOR_NM','VARCHAR','SND 발송 시점 결연아동 사업장명 [SND 전용] (O262-B)'),
]
apply='--apply' in sys.argv
files={}
for f,s,tb,c,ty,cm in COLS: files.setdefault(f,[]).append((s,tb,c,ty,cm))
for f,items in files.items():
    L=io.open(f,encoding='utf-8').read().split('\n')
    for s,tb,c,ty,cm in items:
        st=[i for i,l in enumerate(L) if l.startswith('CREATE OR REPLACE TABLE GN_DW.%s.%s ('%(s,tb))]
        assert len(st)==1,(tb,st); i=st[0]+1
        while not L[i].startswith(')'): i+=1
        end=i; j=end-1
        while re.match(r'\s*(PRIMARY KEY|FOREIGN KEY|CONSTRAINT|UNIQUE)\b',L[j]) or L[j].strip().startswith('--') or not L[j].strip(): j-=1
        if any(re.match(r'\s+%s\s'%c,l) for l in L[st[0]:end]): print('exists',tb,c); continue
        hasconst = j<end-1 and any(re.match(r'\s*(PRIMARY KEY|FOREIGN KEY|CONSTRAINT|UNIQUE)\b',L[k]) for k in range(j+1,end))
        if not L[j].rstrip().endswith(','): L[j]=L[j].rstrip()+','
        new='    %-19s %-15s COMMENT \'%s\'%s'%(c,ty,cm,',' if hasconst else '')
        L.insert(j+1,new); print('insert',f.split('/')[-1],tb,c,'after',j+1)
    if apply: io.open(f,'w',encoding='utf-8',newline='').write('\n'.join(L))
# deploy SQL statements
out=[]
for f,s,tb,c,ty,cm in COLS:
    out.append("ALTER TABLE GN_DW.%s.%s ADD COLUMN IF NOT EXISTS %s %s\n    COMMENT '%s';"%(s,tb,c,ty,cm))
io.open('/workspace/tmp/o262b/d1_stmts.sql','w',encoding='utf-8').write('\n'.join(out)+'\n')

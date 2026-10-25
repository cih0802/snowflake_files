import io,sys,re,glob
def q(vs): return '·'.join("''%s''"%v for v in vs)
MV='주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): '
ADD=[ # file prefix, anchor regex (start of dim), new lines
('05_07', r'^\s*ad\.DMST_OVSEA_DIV_NM AS ', [
 "    ad.CMPGN_TYPE1_BSN_NM AS ad.CMPGN_TYPE1_BSN_NM WITH SYNONYMS ('디지털 국내해외', '캠페인유형1') COMMENT = '디지털 캠페인유형1(사업) 원값 [디지털 전용 · 그 밖 NULL · O262-B]. %s%s',"%(MV,q(['국내','해외','통합','전체'])),
 "    ad.CMPGN_TYPE2_BSN_NM AS ad.CMPGN_TYPE2_BSN_NM WITH SYNONYMS ('디지털 사업사례', '캠페인유형2') COMMENT = '디지털 캠페인유형2(사업) 원값 [디지털 전용 · O262-B]. %s%s',"%(MV,q(['사례','사업','굿즈','기타','통합'])),
 "    ad.CMPGN_TY_NM AS ad.CMPGN_TY_NM WITH SYNONYMS ('영상 캠페인유형', '영상 국내해외 사업사례') COMMENT = '영상 캠페인유형(국내외×사업사례 결합 원값) [영상 전용 · CTV 시트 외 NULL · O262-B]. %s%s',"%(MV,q(['해외 사례','국내 사례','해외 굿즈','국내 사업','통합 기타','해외 사업']))]),
('05_04', r'^\s*fse\.SND_SPNSR_NM AS ', [
 "    fse.SND_FRST_SPNSR AS fse.SND_FRST_SPNSR WITH SYNONYMS ('발송 시점 최초 후원사업') COMMENT = '문자(SND) 발송 시점 수신 회원의 최초 후원사업명 [SND 전용 · 그 밖 채널 NULL · O262-B].',",
 "    fse.SND_CHILD_DTL_NM AS fse.SND_CHILD_DTL_NM WITH SYNONYMS ('발송 시점 결연상태', '결연 상세상태') COMMENT = '문자(SND) 발송 시점 결연 상세상태명 [SND 전용 · O262-B]. %s%s',"%(MV,q(['결연중','비지정결연','퇴소예정','캠페인지정','자동결연지정','사업장퇴소대기','매칭제한','연령제한','퇴소','홈페이지지정','기타'])),
 "    fse.SND_NATION_NM AS fse.SND_NATION_NM WITH SYNONYMS ('발송 시점 결연아동 국가', '결연 국가') COMMENT = '문자(SND) 발송 시점 결연아동 국가명 [SND 전용 · O262-B].',",
 "    fse.SND_BPLC_KOR_NM AS fse.SND_BPLC_KOR_NM WITH SYNONYMS ('발송 시점 결연 사업장', '결연 사업장') COMMENT = '문자(SND) 발송 시점 결연아동 사업장명 [SND 전용 · O262-B].',"]),
('05_23', r'^\s*exp\.MOK_NM AS ', [
 "    exp.BDGT_ITEM_NM AS exp.BDGT_ITEM_NM WITH SYNONYMS ('예산항목', '예산항목명') COMMENT = '지출결의 예산항목명(원값 · 목·세목·세세목과 다른 축 · 미기재 NULL · O262-B).',"]),
('05_02', r'^\s*fme\.STOP_CHANNEL_NM AS ', [
 "    fme.REGIST_DEPT_CD AS fme.REGIST_DEPT_CD WITH SYNONYMS ('중단 등록부서코드') COMMENT = '중단 등록부서 코드 raw(🔴중단 STOP 사건 전용 · 개발 행 NULL · 실적부서 축과 다름 · O262-B).',"]),
('05_10', r'^\s*sponsorship\.SPONSORSHIP_ABBR_CATEGORY AS ', [
 "    sponsorship.DNTN_TY_CD AS sponsorship.DNTN_TY_CD WITH SYNONYMS ('기부유형코드') COMMENT = '후원사업 기부유형 코드 raw(코드군 미확정 ⇒ 의미 추정 금지 · O262-B). %s%s',"%(MV,q(['1','3']))]),
('05_01', r'^\s*member\.LAST_CAMPAIGN AS ', [
 "    member.REGIST_DEPT_CD AS member.REGIST_DEPT_CD WITH SYNONYMS ('회원 등록부서코드') COMMENT = '회원 등록부서 코드 raw(정기·일시 공통 · 개발 실적부서와 다른 축 · O262-B).',"]),
]
apply='--apply' in sys.argv
for pre,anc,new in ADD:
    p=glob.glob('05_SV-Agent_ai/%s_*.sql'%pre)[0]; L=io.open(p,encoding='utf-8').read().split('\n')
    if any(new[0].split(' AS ')[0].strip()+' AS' in l for l in L): print(p,'already'); continue
    idx=[i for i,l in enumerate(L) if re.match(anc,l)]; assert len(idx)==1,(p,idx)
    j=idx[0]
    while not L[j].rstrip().endswith("',"): j+=1
    for k,ln in enumerate(new): L.insert(j+1+k,ln)
    print(p,'insert',len(new),'after line',j+1)
    if apply: io.open(p,'w',encoding='utf-8',newline='').write('\n'.join(L))

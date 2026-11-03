import io
P='05_SV-Agent_ai/22_ML_SV_DDL.sql'; L=io.open(P,encoding='utf-8').read().split('\n')
# [1] 원복: 94행(0-idx 93)은 원래 콤마로 끝났다(뒤에 MONTHS_SINCE_JOIN). 잘못 들어간 10줄 제거.
assert L[93].endswith("품질 점검용.',") and L[94].strip().startswith('-- 🆕 [2026-09-28 O186]')
blk=L[94:104]; del L[94:104]
assert L[94].strip().startswith('mr.MONTHS_SINCE_JOIN')
# [8] 적용: oc.PREDICTION_HAS_ERROR 다음 COMMENT 줄
i=next(k for k,l in enumerate(L) if l.strip().startswith('oc.PREDICTION_HAS_ERROR AS'))
assert L[i+2].strip()=="COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다. 품질 점검용.'"
L[i+2]=L[i+2]+','; L[i+3:i+3]=blk
io.open(P,'w',encoding='utf-8',newline='').write('\n'.join(L)); print('ok', i+1)

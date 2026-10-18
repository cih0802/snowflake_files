# O245 — ML SV 4종 패치(22: MEMBER_RISK · SPONSOR_RISK · ONCE_CONVERSION / 25: CHURN_CAMPAIGN) · 사용자 승인 2026-10-18
# 각 치환은 기대 건수를 단언한다(R1-7 · 셸 미경유). 원본 = tmp/o245/<파일>.before
import io, shutil, hashlib

D = '/workspace/05_SV-Agent_ai/'
ATTR_TAIL_OLD = """    ma.ATTR_MATCHED AS ma.ATTR_MATCHED
      WITH SYNONYMS ('특성 매칭 여부')
      COMMENT = 'TRUE=기준월 시점 회원 이력이 매칭됐다. FALSE 회원은 특성이 (미매칭)이다.'"""
ATTR_TAIL_NEW = ATTR_TAIL_OLD + """,
    ma.REGIST_DEPT_NAME AS ma.REGIST_DEPT_NAME
      WITH SYNONYMS ('등록부서', '회원 등록부서')
      COMMENT = '🆕 [O245] 회원 등록부서명(CRM 회원 마스터 현재 값). 🔴 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.',
    ma.CPR_DIV_NAME AS ma.CPR_DIV_NAME
      WITH SYNONYMS ('법인구분', '사단 사복')
      COMMENT = '🆕 [O245] 회원 법인구분(코드사전 CM019 · 사단·사복 · CRM 회원 마스터 현재 값). 개인·기업·단체 구분은 MEMBER_TYPE_NAME 이다.',
    ma.MEMBER_ACTIVE_SPNSR_CNT AS ma.ACTIVE_SPNSR_CNT
      WITH SYNONYMS ('활동 약정 수', '회원 활동 약정 수', '후원 중인 약정 수')
      COMMENT = '🆕 [O245] 그 회원의 기준월 말 활동 중인 후원약정 수(건 · 카테고리·후원사업 무관 전체). 0 = 활동 약정 없음. 회원당 1개 값이다 — 구간으로 나눠 GROUP BY 하거나 그대로 출력하고 SUM 하지 않는다.'"""
TYPE_OLD = """    ma.MEMBER_TYPE_NAME AS ma.MEMBER_TYPE_NAME
      WITH SYNONYMS ('회원구분', '법인구분', '개인 기업 단체')
      COMMENT = '회원구분 = 개인·기업·단체(법인구분 · 기준월 말 시점).',"""
TYPE_NEW = """    ma.MEMBER_TYPE_NAME AS ma.MEMBER_TYPE_NAME
      WITH SYNONYMS ('회원구분', '개인 기업 단체')
      COMMENT = '회원구분 = 개인·기업·단체(기준월 말 시점). 🔴 법인구분(사단·사복)은 CPR_DIV_NAME 이다(O245).',"""
AI_OLD = '[O241-M 회원 특성 축] 성별·연령대·지역·회원상태·회원구분(법인구분)·후원금액대·유지기간·신규기존·납입방식으로'
AI_NEW = '[O241-M · O245 회원 특성 축] 성별·연령대·지역·회원상태·회원구분·법인구분(사단·사복)·등록부서·활동 약정 수·후원금액대·유지기간·신규기존·납입방식으로'

P22 = [
    (TYPE_OLD, TYPE_NEW, 2), (ATTR_TAIL_OLD, ATTR_TAIL_NEW, 2), (AI_OLD, AI_NEW, 2),
    ("(9) 🔴 **회원상태·결제수단·법인구분·가입기간별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 이 SV 에 해당 축이 없다고 답하고, 등급(CHURN_GRADE·LOYAL_GRADE)별 분해를 대안으로 안내한다.",
     "(9) [O245 정정] 회원상태·납입방식(결제수단)·법인구분·유지기간(가입기간)·등록부서·활동 약정 수별 분해는 ma 차원으로 답한다(기준월 말 시점 · 모델 피처 아님). 🔴 캠페인카테고리·후원사업별 분해는 회원당 값이 여러 개라 이 SV 로 만들지 않는다 — SV_ML_CHURN_CAMPAIGN(중단 예측 × 캠페인카테고리 · 후원사업)으로 안내한다.", 1),
    ("(ma · 성별·연령대·지역·회원상태·회원구분·금액대·유지기간·납입방식 · 모델 피처 아님)",
     "(ma · 성별·연령대·지역·회원상태·회원구분·금액대·유지기간·납입방식 · 🆕 O245 법인구분·등록부서·활동 약정 수 · 모델 피처 아님) · 캠페인카테고리·후원사업별 = SV_ML_CHURN_CAMPAIGN", 1),
    ("(6) 🔴 **캠페인별·상위캠페인(채널)별·결제수단별 이탈 예측이나 이탈분류 후원금액을 물으면 SQL 을 만들지 않는다**",
     "(6) 🔴 **캠페인별·상위캠페인(채널)별 이탈 예측이나 이탈분류 후원금액을 물으면 SQL 을 만들지 않는다**(납입방식·결제수단별은 ma.PAYMENT_METHOD_NAME 으로 답한다 · O245)", 1),
    ("비활성: 캠페인·상위캠페인(채널)·결제수단 축 · 이탈분류 후원금액(원천 금액 컬럼 제거) · 업무 위험 임계값(미확정) · 부서 축(원천에 부재).",
     "비활성: 캠페인·상위캠페인(채널) 축 · 이탈분류 후원금액(원천 금액 컬럼 제거) · 업무 위험 임계값(미확정). 🆕 [O245] 활성: 납입방식·등록부서·법인구분·활동 약정 수(ma · 회원 특성 · 모델 피처 아님).", 1),
    # ONCE
    ("""      COMMENT = '일시회원을 등록한 부서명(조직 차원 DEPARTMENT). 🔴 등록 부서이며 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.'
  )""",
     """      COMMENT = '일시회원을 등록한 부서명(조직 차원 DEPARTMENT). 🔴 등록 부서이며 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.',
    oc.CPR_DIV_NAME AS oc.CPR_DIV_NAME
      WITH SYNONYMS ('법인구분', '사단 사복')
      COMMENT = '🆕 [O245] 일시회원 법인구분(코드사전 CM019 · 사단·사복 · 현재 회원 마스터 값).',
    oc.AMOUNT_BAND AS oc.AMOUNT_BAND
      WITH SYNONYMS ('후원금액대', '금액대', '일시후원 금액대')
      COMMENT = '🆕 [O245] 후원금액대(기준월 이하 가장 최근 납입월의 일시후원 납입액 · 5만원 구간). 🔴 정기회원 금액대(약정금액 기준)와 기준이 다르다 — 두 SV 의 금액대를 같은 축으로 비교하지 않는다. 납입 이력이 없으면 NULL.',
    oc.TENURE_BAND AS oc.TENURE_BAND
      WITH SYNONYMS ('유지기간', '가입기간', '후원기간대')
      COMMENT = '🆕 [O245] 유지기간대(기준월 이하 가장 최근 회원 월실적의 기간대1 · 가입일부터 5년 구간). 월실적 행이 없으면 NULL.',
    oc.PAYMENT_METHOD_NAME AS oc.PAYMENT_METHOD_NAME
      WITH SYNONYMS ('납입방식', '결제수단')
      COMMENT = '🆕 [O245] 납입방식(기준월 이하 가장 최근 청구월의 청구액이 가장 큰 결제수단 · 잠정). 청구 이력이 없으면 NULL.',
    oc.SPONSORSHIP_NAME AS oc.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업명', '일시후원 사업')
      COMMENT = '🆕 [O245] 후원사업(기준월 이하 가장 최근 납입월의 납입액이 가장 큰 후원사업). 납입 이력이 없으면 NULL.'
  )""", 1),
    ("(4) 🔴 **가입월·관측월·가입 후 경과월별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축이 없다고 답하고, 성별·회원구분·등록부서별 분해를 대안으로 안내한다.",
     "(4) 🔴 **가입월·관측월·가입 후 경과월별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축이 없다고 답하고, 성별·회원구분·등록부서별 분해를 대안으로 안내한다. (4-b) 🆕 [O245] 법인구분·후원금액대(최근 납입월 납입액)·유지기간대·납입방식·후원사업별 분해는 해당 차원으로 답한다. 🔴 캠페인카테고리·회원상태·연령대·지역은 일시회원에 원천 값이 없다 — 「데이터 없음」으로 답하고 SQL 을 만들지 않는다.", 1),
    ("· 성별·회원구분·등록부서(현재 마스터 스냅샷).", "· 성별·회원구분·등록부서(현재 마스터 스냅샷) · 🆕 [O245] 법인구분·후원금액대(최근 납입월 납입액)·유지기간대·납입방식·후원사업. 데이터 없음(일시회원 원천 값 0): 캠페인카테고리·회원상태·연령대·지역.", 1),
]

CS_TABLE_OLD = """      COMMENT = '예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식). grain = 기준월 × 회원. 🔴 모델 피처가 아니다 — 예측 결과를 특성으로 나눠 보는 집계용이다. 미매칭 = (미매칭).'
  )
  RELATIONSHIPS (
    cc_to_member_attr AS cc(STDR_MT, MBER_NO) REFERENCES ma
  )"""
CS_TABLE_NEW = """      COMMENT = '예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식). grain = 기준월 × 회원. 🔴 모델 피처가 아니다 — 예측 결과를 특성으로 나눠 보는 집계용이다. 미매칭 = (미매칭).',
    cs AS GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V
      WITH SYNONYMS ('후원사업별 중단 예측', '중단 예측 후원사업', '카테고리 후원사업별 중단 위험')
      COMMENT = '🆕 [O245] ML 중단 예측을 기준월 말 활동 약정의 캠페인카테고리 × 후원사업에 결합한 표(base: SERVING.ML_CHURN_BY_SPONSORSHIP_V). [Grain: 기준월 × 회원 × 캠페인카테고리 × 후원사업]. 「후원사업별」 또는 「캠페인카테고리 × 후원사업별」 중단 예측 질문에 쓴다. 🔴 cc 테이블과 grain 이 다르다 — 한 쿼리에서 cc 와 조인하지 않는다.'
  )
  RELATIONSHIPS (
    cc_to_member_attr AS cc(STDR_MT, MBER_NO) REFERENCES ma,
    cs_to_member_attr AS cs(STDR_MT, MBER_NO) REFERENCES ma
  )"""
CS_DIM_OLD = ATTR_TAIL_NEW + """
  )
  METRICS ("""
CS_DIM_NEW = ATTR_TAIL_NEW + """,
    cs.SP_STDR_MT AS cs.STDR_MT
      WITH SYNONYMS ('후원사업 표 기준월')
      COMMENT = '🆕 [O245] cs 표의 기준월(YYYYMM). 🔴 여러 기준월 합산 금지 — 미지정 시 최신 기준월 하나.',
    cs.SP_MBER_NO AS cs.MBER_NO
      WITH SYNONYMS ('후원사업 표 회원번호')
      COMMENT = '🆕 [O245] cs 표의 회원번호. 회원수는 이 축의 중복제거로 센다.',
    cs.SP_CMPGN_CTGR_NM AS cs.CMPGN_CTGR_NM
      WITH SYNONYMS ('후원사업 표 캠페인카테고리')
      COMMENT = '🆕 [O245] cs 표의 캠페인카테고리(기준월 말 활동 약정 · MM294 · 적재 시점 동결값). 실제값은 조회로 확인한다.',
    cs.SPONSORSHIP_NAME AS cs.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업명', '활동 후원사업')
      COMMENT = '🆕 [O245] 기준월 말 활동 약정의 후원사업명(DIM_SPONSORSHIP). 🔴 실제값은 열거하지 않는다 — 후원사업 마스터가 늘어나면 낡는다. 값 목록은 조회로 확인한다.',
    cs.SP_ACTIVE_SPNSR_CNT AS cs.ACTIVE_SPNSR_CNT
      WITH SYNONYMS ('후원사업별 활동 약정 수')
      COMMENT = '🆕 [O245] 그 회원이 이 카테고리·후원사업으로 기준월 말 활동 중인 약정 수(건). 행마다 이미 집계된 값이다 — 명단에는 그대로 쓰고 COUNT 로 다시 세지 않는다.',
    cs.SP_HAS_MEMBER_PRED AS cs.HAS_MEMBER_PRED
      WITH SYNONYMS ('후원사업 표 회원 단위 예측 대상 여부')
      COMMENT = '🆕 [O245] TRUE = 회원 단위 중단 예측 대상 회원.',
    cs.SP_MEMBER_CHURN_GRADE AS cs.MEMBER_CHURN_GRADE
      WITH SYNONYMS ('후원사업 표 회원 중단위험 등급')
      COMMENT = '🆕 [O245] 회원 단위 중단위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 회원 단위 예측 대상 아님.',
    cs.SP_SPONSOR_CHURN_GRADE AS cs.SPONSOR_CHURN_GRADE
      WITH SYNONYMS ('후원사업별 후원건 이탈위험 등급')
      COMMENT = '🆕 [O245] 이 카테고리·후원사업 약정 중 가장 높은 이탈위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 후원건 예측 대상 아님.'
  )
  METRICS ("""
CS_MET_OLD = """      COMMENT = '회원 단위 중단확률 평균(0~1 · 표기는 %로 ×100). 회원당 여러 카테고리 행이 있으면 같은 회원 확률이 중복 반영된다 — 카테고리 하나로 거른 뒤 쓴다.'
  )"""
CS_MET_NEW = """      COMMENT = '회원 단위 중단확률 평균(0~1 · 표기는 %로 ×100). 회원당 여러 카테고리 행이 있으면 같은 회원 확률이 중복 반영된다 — 카테고리 하나로 거른 뒤 쓴다.',
    cs.SP_ACTIVE_MEMBERS AS COUNT(DISTINCT cs.MBER_NO)
      WITH SYNONYMS ('후원사업별 활동회원수')
      COMMENT = '🆕 [O245] 기준월 말 그 후원사업(·카테고리)으로 활동 중인 고유 회원수(명 · 중복제거). 🔴 후원사업별 값을 더하면 다중 후원 회원이 중복된다.',
    cs.SP_MEMBER_HIGH_RISK_MEMBERS AS COUNT(DISTINCT CASE WHEN cs.MEMBER_CHURN_GRADE = '고위험' THEN cs.MBER_NO END)
      WITH SYNONYMS ('후원사업별 중단 고위험 회원수')
      COMMENT = '🆕 [O245] 회원 단위 중단위험 등급이 고위험인 활동회원수(명 · 중복제거).',
    cs.SP_MEMBER_PRED_MEMBERS AS COUNT(DISTINCT CASE WHEN cs.HAS_MEMBER_PRED THEN cs.MBER_NO END)
      WITH SYNONYMS ('후원사업별 회원 단위 예측 대상 회원수')
      COMMENT = '🆕 [O245] 회원 단위 중단 예측 대상인 활동회원수(명 · 중복제거). 고위험 비율의 분모.',
    cs.SP_SPONSOR_HIGH_RISK_MEMBERS AS COUNT(DISTINCT CASE WHEN cs.SPONSOR_HIGH_CNT > 0 THEN cs.MBER_NO END)
      WITH SYNONYMS ('후원사업별 후원건 고위험 회원수')
      COMMENT = '🆕 [O245] 이 후원사업(·카테고리) 약정 중 고위험 후원건이 1건 이상인 활동회원수(명 · 중복제거).'
  )"""
P25 = [
    (TYPE_OLD, TYPE_NEW, 1), (CS_TABLE_OLD, CS_TABLE_NEW, 1), (ATTR_TAIL_OLD, ATTR_TAIL_NEW, 1),
    (CS_DIM_OLD, CS_DIM_NEW, 1), (CS_MET_OLD, CS_MET_NEW, 1), (AI_OLD, AI_NEW, 1),
    ("(6) 🔴 실적 SV 와 조인하지 않는다.'",
     "(6) 🔴 실적 SV 와 조인하지 않는다. (7) 🆕 [O245] 「후원사업별」·「캠페인카테고리 × 후원사업별」 질문은 cs 테이블(cs.SPONSORSHIP_NAME · cs.SP_CMPGN_CTGR_NM)로 답한다 — 분모·고위험 규칙은 (2)·(5)와 같고 cs 컬럼으로 쓴다. 🔴 cc 와 cs 를 한 쿼리에서 조인하지 않는다(grain 이 다르다).'", 1),
    ("「N월 활동회원 중 중단 가능성 높은 회원 중 ○○캠페인(카테고리) 후원 회원 · 회원번호 명단·수」 질문에 쓴다.",
     "「N월 활동회원 중 중단 가능성 높은 회원 중 ○○캠페인(카테고리) 후원 회원 · 회원번호 명단·수」 질문에 쓴다. 🆕 [O245] 후원사업별·카테고리 × 후원사업별 질문은 cs 테이블(ML_CHURN_BY_SPONSORSHIP_V)로 답한다.", 1),
]


def patch(name, reps):
    p = D + name
    a, b = hashlib.sha256(open(p, 'rb').read()).hexdigest(), hashlib.sha256(open(p, 'rb').read()).hexdigest()
    assert a == b
    s = io.open(p, encoding='utf-8', newline='').read()
    for old, new, n in reps:
        c = s.count(old)
        assert c == n, '%s: %r %d != %d' % (name, old[:60], c, n)
        s = s.replace(old, new)
    shutil.copyfile(p, '/workspace/tmp/o245/%s.before' % name)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK', name)


patch('22_ML_SV_DDL.sql', P22)
patch('25_ML_CHURN_CMPGN_CTGR_DDL.sql', P25)

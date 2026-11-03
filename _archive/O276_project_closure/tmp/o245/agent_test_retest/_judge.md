## C1 · 중단×카테고리 : 후원사업
- 질문: ML 중단 예측 최신 기준월 활동회원을 후원사업별로 나눠서 활동회원수와 중단 고위험 회원수를 보여줘
- 도구: analyst_ml_churn_campaign, system_execute_sql, data_to_chart
- 도구 오류: 0
- SQL: `WITH latest AS (SELECT MAX(__cs.sp_stdr_mt) AS mt FROM __cs) SELECT CASE WHEN GROUPING(__cs.sponsorship_name) = 1 THEN '전체 합계' WHEN __cs.sponsorship_name IS NULL THEN '(미매칭)' ELSE __cs.sponsorship_name END AS "후원사업", COUNT(DISTINCT __cs.sp_mber_no) AS "활동회원수(명)", COUNT(DISTINCT CASE WHEN __cs.sp_member_churn_grade = '고위험' THEN __cs.sp_mber_no END) AS "중단 고위험 회원수(명)", COUNT(DISTINCT CASE WHEN __cs.sp_has_member_pred THEN __cs.sp_mber_no END) AS "회원 단위 예측 대상 회원수(명)" FROM __cs WHERE __cs.sp_stdr_mt = (SELECT mt FROM latest) GROUP BY ROLLUP(__cs.sponsorship_name) ORDER BY "활동회원수(명)" DESC NULLS LAST`
- SQL: `WITH __cs AS ( SELECT sponsorship_name, has_member_pred AS sp_has_member_pred, member_churn_grade AS sp_member_churn_grade, mber_no, mber_no AS sp_mber_no, stdr_mt, stdr_mt AS sp_stdr_mt FROM GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V ), latest AS ( SELECT MAX(__cs.sp_stdr_mt) AS mt FROM __cs ) SELECT CASE WHEN GROUPING(__cs.sponsorship_name) = 1 THEN '전체 합계' WHEN __cs.sponsorship_name IS NULL THEN '(미매칭)' ELSE __cs.sponsorship_name END AS "후원사업", COUNT(DISTINCT __cs.sp_mber_no) AS "활동회원수(명)", COUNT(DISTINCT CASE WHEN __cs.sp_member_churn_grade = '고위험' THEN __cs.sp_mber_no END) AS "중단 고위험 회원수(명)", COUNT(DISTINCT CASE WHEN __cs.sp_has_member_pred THEN __cs.sp_mber_no END) AS "회원 단위 예측 대상 회원수(명)"`
- 결과표: 후원사업 | 활동회원수(명) | 중단 고위험 회원수(명) | 회원 단위 예측 대상 회원수(명)
  - 전체 합계 | 738223 | 7016 | 70158
  - 해외아동결연 | 183235 | 1386 | 14254
  - 국내아동권리보호사업(사단법인) | 180611 | 1824 | 20068
  - 보건의료지원사업 | 142372 | 1620 | 13233
  - 국내아동권리보호사업(사회복지법인) | 90370 | 486 | 6287
  - 해외지역개발사업 | 53854 | 592 | 6653
  - 전체사업지원 | 31415 | 366 | 3687
  - 식수위생지원사업 | 29757 | 329 | 2280
- 기대값: [['해외아동결연', '183235', '1386'], ['국내아동권리보호사업(사단법인)', '180611', '1824'], ['보건의료지원사업', '142372', '1620'], ['국내아동권리보호사업(사회복지법인)', '90370', '486'], ['해외지역개발사업', '53854', '592']]
- 최종 답변(말미 600자): 회원수(명): 회원 단위 중단 모델이 예측한 활동회원수. 고위험 비율을 볼 때 이 값이 분모입니다(활동회원 전체가 아니라 예측 대상 회원만 모델이 분류합니다). **한계·주의** - 🔴 머신러닝 예측치이며 실적이 아닙니다. 모델은 테스트 단계라 구조·수치가 교체될 수 있습니다. - 🔴 '고위험'은 회원 단위 등급(순위 구간)이며, 「반드시 중단한다」는 뜻이 아니라 「모델이 고위험으로 분류한 회원」입니다. 예측 지평(향후 몇 개월)은 원천 표기 확인 중이라 숫자로 밝히지 않습니다. - 🔴 후원사업은 다중 후원이 있어 **후원사업별 활동회원수를 더해도 전체 합계(738,223명)와 같지 않습니다** — 전체 합계는 중복제거된 고유 회원수입니다(후원사업별 합을 더하면 중복 반영돼 더 커집니다). - 복지관후원·좋은이웃(사복) 등은 중단 고위험 회원수가 0명입니다. 원천: GN_DW.ML 머신러닝 산출물 → SERVING.ML_CHURN_BY_SPONSORSHIP_V(학습 원천은 BRONZE_CRM) 더 필요하시면 특정 후원사업의 고위험 회원 명단(회원번호), 캠페인카테고리 × 후원사업 교차, 또는 회원 특성(연령대·성별·후원금액대)별 분해도 보여드릴 수 있습니다.

## M4 · 회원중단×납입방식(규칙9 정정)
- 질문: ML 회원 중단 예측에서 납입방식별 모델 중단분류 회원수를 알려줘. 최신 기준월로.
- 도구: analyst_ml_once_conversion, analyst_ml_member_risk, system_execute_sql, data_to_chart
- 도구 오류: 0
- SQL: `SELECT CASE WHEN GROUPING(ma.payment_method_name) = 1 THEN '전체' WHEN ma.payment_method_name IS NULL THEN '(미매칭)' ELSE ma.payment_method_name END AS "납입방식", COUNT(DISTINCT CASE WHEN mr.churn_class = '1' THEN mr.mber_no END) AS "모델 중단분류 회원수(명)", COUNT(DISTINCT mr.mber_no) AS "예측 대상 회원수(명)", ROUND(AVG(mr.churn_prob), 2)::NUMBER(38,2) AS "평균 중단확률" FROM __mr mr INNER JOIN __ma ma ON mr.stdr_mt = ma.stdr_mt AND mr.mber_no = ma.mber_no WHERE mr.stdr_mt = (SELECT MAX(mr2.stdr_mt) FROM __mr mr2) GROUP BY ROLLUP(ma.payment_method_name) ORDER BY "모델 중단분류 회원수(명)" DESC NULLS LAST`
- SQL: `WITH __mr AS ( SELECT churn_class, mber_no, stdr_mt, churn_prob FROM GN_DW.SERVING.ML_MEMBER_RISK_V ), __ma AS ( SELECT payment_method_name, mber_no, stdr_mt FROM GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V ) SELECT CASE WHEN GROUPING(ma.payment_method_name) = 1 THEN '전체' WHEN ma.payment_method_name IS NULL THEN '(미매칭)' ELSE ma.payment_method_name END AS "납입방식", COUNT(DISTINCT CASE WHEN mr.churn_class = '1' THEN mr.mber_no END) AS "모델 중단분류 회원수(명)", COUNT(DISTINCT mr.mber_no) AS "예측 대상 회원수(명)", CAST(ROUND(AVG(mr.churn_prob), 2) AS DECIMAL(38, 2)) AS "평균 중단확률" FROM __mr AS mr INNER JOIN __ma AS ma ON mr.stdr_mt = ma.stdr_mt AND mr.mber_no = ma.mber_no WHERE mr.stdr_mt = ( SELECT MAX(mr2.stdr_mt) FROM `
- 결과표: 납입방식 | 모델 중단분류 회원수(명) | 예측 대상 회원수(명) | 평균 중단확률
  - 전체 | 27328 | 70158 | 0.44
  - (미매칭) | 8849 | 13358 | 0.70
  - 자동이체 | 7642 | 36575 | 0.29
  - 신용카드 | 7088 | 12402 | 0.56
  - 네이버페이 | 2238 | 4574 | 0.54
  - OCR | 1501 | 3173 | 0.47
  - 회비통장 | 6 | 71 | 0.12
  - 휴대폰 | 4 | 5 | 0.67
- 기대값: [['(미매칭)', '8849'], ['자동이체', '7642'], ['신용카드', '7088'], ['네이버페이', '2238'], ['OCR', '1501']]
- 최종 답변(말미 600자): 프** **③ 상세** GN_DW 기준(머신러닝 예측 · 최신 기준월) - **지표 정의**: 「모델 중단분류 회원수」는 모델이 중단(churn)으로 분류한 회원을 중복 제거해 센 값입니다. 「예측 대상 회원수」가 각 납입방식의 분모(모집단)이며, 전체 회원이 아닙니다. - **납입방식 축**: 그 달 청구액이 가장 큰 결제수단 기준(잠정)입니다. **(미매칭)**은 회원 특성 이력에 납입방식이 연결되지 않은 건으로, 「값을 모른다」가 아니라 「마스터에 매칭되지 않은 건」입니다 — 평균 중단확률(0.70)이 높아 별도로 살펴볼 필요가 있습니다. - **주의**: 예측치이며 실적이 아닙니다. 「위험 회원」이 아니라 「모델이 중단으로 분류한 회원」입니다. 머신러닝은 테스트 단계로 모델·구조가 교체될 수 있고, 예측 지평(향후 몇 개월)은 원천 확인 중입니다. 업무 중단 판정선은 아직 확정되지 않았습니다. - 더 자세히 보시려면 **중단위험 등급(고위험/주의/일반)별**, 또는 **유지기간대·회원구분·법인구분별** 분해도 제공할 수 있습니다. 원천: GN_DW.ML 머신러닝 산출물 → SERVING.ML_MEMBER_RISK_V (학습 원천은 BRONZE_CRM)

## M5 · 회원중단×유지기간(규칙9 정정)
- 질문: ML 중단 예측 최신 기준월에서 유지기간대별 평균 중단확률은?
- 도구: analyst_ml_member_risk, system_execute_sql, data_to_chart
- 도구 오류: 0
- SQL: `WITH latest AS ( SELECT MAX(mr.stdr_mt) AS max_mt FROM __mr mr ) SELECT CASE WHEN GROUPING(ma.tenure_band) = 1 THEN '전체' WHEN ma.tenure_band IS NULL THEN '(미매칭)' ELSE ma.tenure_band END AS "유지기간대", COUNT(DISTINCT mr.mber_no) AS "예측 대상 회원수", ROUND(AVG(mr.churn_prob), 2)::NUMBER(38,2) AS "평균 중단확률", ROUND(MAX(mr.churn_prob), 2)::NUMBER(38,2) AS "최대 중단확률" FROM __mr mr JOIN __ma ma ON mr.stdr_mt = ma.stdr_mt AND mr.mber_no = ma.mber_no WHERE mr.stdr_mt = (SELECT max_mt FROM latest) AND mr.has_churn_pred = TRUE GROUP BY ROLLUP(ma.tenure_band) ORDER BY "평균 중단확률" DESC NULLS LAST`
- SQL: `WITH __mr AS ( SELECT has_churn_pred, mber_no, stdr_mt, churn_prob FROM GN_DW.SERVING.ML_MEMBER_RISK_V ), __ma AS ( SELECT tenure_band, mber_no, stdr_mt FROM GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V ), latest AS ( SELECT MAX(mr.stdr_mt) AS max_mt FROM __mr AS mr ) SELECT CASE WHEN GROUPING(ma.tenure_band) = 1 THEN '전체' WHEN ma.tenure_band IS NULL THEN '(미매칭)' ELSE ma.tenure_band END AS "유지기간대", COUNT(DISTINCT mr.mber_no) AS "예측 대상 회원수", CAST(ROUND(AVG(mr.churn_prob), 2) AS DECIMAL(38, 2)) AS "평균 중단확률", CAST(ROUND(MAX(mr.churn_prob), 2) AS DECIMAL(38, 2)) AS "최대 중단확률" FROM __mr AS mr JOIN __ma AS ma ON mr.stdr_mt = ma.stdr_mt AND mr.mber_no = ma.mber_no WHERE mr.stdr_mt = ( SELECT max_mt FROM late`
- 결과표: 유지기간대 | 예측 대상 회원수 | 평균 중단확률 | 최대 중단확률
  - (미매칭) | 8791 | 0.96 | 1.00
  - 전체 | 70158 | 0.44 | 1.00
  - 0~5년 미만 | 43867 | 0.38 | 0.99
  - 5~10년 미만 | 11638 | 0.36 | 0.99
  - 10~15년 미만 | 3870 | 0.32 | 0.99
  - 20~25년 미만 | 458 | 0.32 | 0.99
  - 15~20년 미만 | 1433 | 0.31 | 0.99
  - 30~35년 미만 | 27 | 0.25 | 0.82
- 기대값: [['(미매칭)', '96.37'], ['0~5년 미만', '37.51'], ['10~15년 미만', '31.66'], ['15~20년 미만', '31.45'], ['20~25년 미만', '32.16'], ['25~30년 미만', '23.55'], ['30~35년 미만', '25.3'], ['35~40년 미만', '7.04'], ['5~10년 미만', '36.28']]
- 최종 답변(말미 600자): ** - 유지기간이 길수록 평균 중단확률이 낮아지는 경향이 뚜렷합니다(0~5년 0.38 → 35~40년 0.07). - **(미매칭) 8,791명의 평균 0.96**은 유지기간이 마스터에 연결되지 않은 건입니다(값을 모른다는 뜻이 아니라 차원 마스터에 매칭되지 않은 구조적 결손). 이 묶음이 전체 평균(0.44)을 끌어올리고 있어, 유지기간 분석 시 별도로 다루는 것이 좋습니다. **한계** - 예측치이며 실적이 아닙니다. 머신러닝은 테스트 단계로 모델·피처·테이블 구조가 교체될 수 있어 값의 안정성을 보장하지 않습니다. - 모집단은 전체 회원이 아니라 예측 대상 회원(70,158명)입니다. 예측 지평(향후 몇 개월)은 원천 확인 중이라 숫자로 제시하지 않습니다. - 모델 기본 판정선(0.5)과 업무 위험 판정선은 다르며, 업무 위험 임계값은 아직 미확정입니다. 원천: GN_DW.ML 머신러닝 산출물 → SERVING.ML_MEMBER_RISK_V·ML_MEMBER_ATTR_ASOF_V (학습 원천은 BRONZE_CRM) 더 필요하시면 특정 유지기간대의 중단위험 등급(고위험/주의/일반) 분포나, 유지기간대 × 성별·연령대 교차 분해로 드릴다운해 드리겠습니다.


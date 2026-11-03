import io


def rep(p, a, b):
    s = io.open(p, encoding='utf-8').read()
    assert s.count(a) == 1, (p, a)
    io.open(p, 'w', encoding='utf-8').write(s.replace(a, b))


rep('/workspace/문서실행순서.md',
    '> 🔴 [O261] SV COMMENT 값 목록은 **늘어날 수 있다**',
    '> 🟢 [O261] 신규 구축(위 1~59)은 `34_`(O246-D 폴백 각주)를 따로 돌리지 않는다 — 그 내용을 정본 `22_`·`25_` 에 이식했다(정규화 대조 SV_ML 3종 IDENTICAL). 기존 환경 갱신 35·38 의 「34 마지막」 순서는 그대로 지켜도 결과가 같다.\n'
    '> 🔴 [O261] SV COMMENT 값 목록은 **늘어날 수 있다**')
rep('/workspace/문서실행순서_보조주석.md',
    '| 52 | `25_ML_CHURN_CMPGN_CTGR_DDL.sql` | [ML연계·O224] 중단 ML 예측×캠페인카테고리 사전 결합 뷰·SV(09_2 전 필수) |',
    '| 52 | `25_ML_CHURN_CMPGN_CTGR_DDL.sql` | [ML연계·O224] 중단 ML 예측×캠페인카테고리 사전 결합 뷰·SV(09_2 전 필수) · 🆕 [O261] `22_`·`25_` 에 `34_`(O246-D 기준월 폴백 각주 · 차원 COMMENT 4 × 3 SV · MA 표 COMMENT · 지시문)를 이식 — 종전 신규 구축은 34 가 순서에 없어 각주가 빠졌다 |')
print('ok')

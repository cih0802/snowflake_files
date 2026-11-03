# O266-B — 제작비 COMMENT 문안 교체(수치 제거 R2-6 · 「SV 에 제작비 세세목 정의가 없다」 사유 명시) · 3파일 동일 치환
import io

OLD_DDL = "제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분(세세목 필터 없음). 미기재분(약 99%)은 캠페인을 알 수 없어 포함하지 않는다 ⇒ 실제 제작비보다 작다."
NEW_DDL = ("제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분 전체. 🔴 제작비 세세목 정의가 아직 없어(현업 확인 대기) 세세목으로 거르지 않는다 · "
           "코드 미기재 지출은 캠페인을 알 수 없어 빠진다 ⇒ 전체 지출의 일부만 잡히며 실제 캠페인 제작비와 다르다.")
OLD_SV = "제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분. F(가산). 🔴 코드 미기재 지출(약 99%)은 캠페인을 알 수 없어 빠진다 ⇒ 실제 제작비보다 작다 — 답변에 「세부캠페인코드 기재분만」이라고 밝힌다."
NEW_SV = ("제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분 전체. F(가산). 🔴 이 SV 에는 **제작비 세세목 정의가 없다**(현업 확인 대기) — "
          "세세목으로 거르지 않고 코드가 기재된 지출을 모두 더한다. 코드 미기재 지출은 캠페인을 알 수 없어 빠지므로 전체 지출의 일부만 잡힌다. "
          "답변에 「제작비 세세목 정의가 없어 세부캠페인코드가 기재된 지출결의 전체를 제작비로 집계했다 · 실제 제작비와 다를 수 있다」고 밝힌다.")
PLAN = [
    ('/workspace/03_top-down_gold/06_DDL.sql', OLD_DDL, NEW_DDL),
    ('/workspace/05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql', OLD_DDL, NEW_DDL),
    ('/workspace/05_SV-Agent_ai/05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql', OLD_SV, NEW_SV),
]
for p, old, new in PLAN:
    t = io.open(p, encoding='utf-8').read()
    assert t.count(old) == 1, (p, t.count(old))
    io.open(p, 'w', encoding='utf-8').write(t.replace(old, new))
    print('ok', p)

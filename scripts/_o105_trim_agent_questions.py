# AGENT_MEMBER 추천질문 34 → 12 로 축약하는 1회용 스크립트 (도구 커버리지 기준 유형 분류).
# Co-authored with CoCo
#
# 사용자 지시(2026-08-28) = 「AGENT 설계시 추천질문은 최대 15개로 제한 · 기존 질문 유형을 분류해
#   10개 정도로 줄여라」. 실측 = MEMBER 34 · MARKETING 11 · OVERALL 10 ⇒ MEMBER 만 초과다.
#
# 유형 분류(34문항 · 도구 귀속 기준):
#   회비/납부율 7(1·2·4·5·6·7·8) · 개발사건 8(9·10·11·12·13·14·15·26) · 코호트 이탈률 5(3·19·20·21·22)
#   ML 예측 6(27~32) · 목표 달성율 3(23·24·25) · 원천 2(18·33) · 발송 1(16) · 행사 1(17) · 활동회원 1(34)
# 축약 원칙 = **도구 1개당 대표 1문항** + 원천 규칙 1문항. 같은 도구 안의 축 나열은 한 문항으로 병합
#   (연령대+지역 · 후원구분+법인구분 · 부서+월 목표 · 캠페인 이탈률 3종). 특수 사례 문항(「10대 미만이
#   왜 많은가」)은 system instruction 에 이미 처방이 박혀 있어 추천질문에서 뺀다(중복 노출 제거).
# R1-7-9: 본문에 백틱은 없으나 한글 다수라 셸 경유를 피하고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

PATH = "cortex_project/agents/AGENT_MEMBER/agent_spec.yaml"
SNAP = "_archive/AGENT_MEMBER.agent_spec.yaml.O105-pre-trimQ"

QUESTIONS = [
    # 회비 분해 (analyst_member_fee) — 후원사업·납입방식 축 병합
    "후원사업별·납입방식(결제수단)별 회비 청구액과 납부율을 보여줘",
    # 회원-월 요약 (analyst_member_monthly)
    "연도별 납부율과 미납비중 추이를 보여줘 (2023-2025)",
    # 상태전이 사건 (analyst_member_event) — 개발구분 축
    "개발구분별(신규·증액·감액·재후원·후원중단) 개발/중단 건수와 고유 회원수는?",
    # 상태전이 사건 — 세부캠페인 후원구분·법인구분(2026-08-28 신규 축)
    "세부캠페인 후원구분(정기후원/일시후원)·법인구분(통합/사단/사복)별 개발건수는?",
    # 상태전이 사건 — 사건시점 회원속성 축(연령대+지역 병합)
    "연령대별·지역별 개발건수는? (약정 시점 기준)",
    # 획득 코호트 (analyst_member_cohort) — 이탈률 3문항 병합
    "주요캠페인(캠페인카테고리)별 12개월 이탈률과 획득 회원수를 비교해줘",
    # 목표 대비 실적 (analyst_dev_achievement) — 부서+월 병합
    "2025년 부서별·월별 개발 목표와 실적, 달성율 추이를 보여줘",
    # 활동회원 (analyst_member_sponsor_biz)
    "캠페인별·후원사업별 지금 활동회원 수를 보여줘",
    # 발송 (analyst_service)
    "채널별 발송수와 발송결과(발송상태·통신사 도달결과)를 보여줘",
    # 행사 (analyst_event_participation)
    "행사종류별 참여자수와 참여상태별 분포는?",
    # ML 예측 — 회원 단위 (analyst_ml_member_risk)
    "회원상태별로 모델이 중단으로 분류한 회원수와 평균 중단확률을 보여줘 (예측)",
    # 원천 질문 규칙(도구 미호출 경로) — 예측 원천까지 함께 묻게 해 2문항을 1문항으로 병합
    "납입회비와 회비 예측 데이터의 원천(bronze)은 각각 어디야?",
]

CAP = 15


def main() -> None:
    raw = open(PATH, encoding="utf-8").read()
    lines = raw.split("\n")

    s = [i for i, x in enumerate(lines) if x.strip() == "sample_questions:"]
    e = [i for i, x in enumerate(lines) if x.startswith("tools:")]
    assert len(s) == 1 and len(e) == 1, "블록 경계가 유일하지 않다 — 중단"
    s, e = s[0], e[0]
    old = lines[s + 1:e]
    assert all(x.startswith("  - question: ") for x in old), "블록에 question 이 아닌 줄이 있다 — 중단"
    assert len(QUESTIONS) <= CAP, f"문항 {len(QUESTIONS)} > 상한 {CAP}"
    assert len(set(QUESTIONS)) == len(QUESTIONS), "문항 중복 — 중단"

    shutil.copyfile(PATH, SNAP)
    new = [f"  - question: {q}" for q in QUESTIONS]
    out = "\n".join(lines[:s + 1] + new + lines[e:])
    open(PATH, "w", encoding="utf-8").write(out)

    import yaml
    d = yaml.safe_load(open(PATH, encoding="utf-8"))
    q = d["instructions"]["sample_questions"]
    t = d["tools"]
    over = [i + 1 for i, x in enumerate(out.split("\n")) if len(x) > 2000]
    print(f"스냅샷        = {SNAP}")
    print(f"문항          = {len(old)} -> {len(q)} (상한 {CAP})")
    print(f"바이트        = {len(raw.encode())} -> {len(out.encode())}")
    print(f"SHA256        = {hashlib.sha256(out.encode()).hexdigest()[:16]}")
    print(f"yaml OK       = tools {len(t)} = resources {len(d['tool_resources'])}")
    print(f"2000자 초과   = {over}")
    print(f"신규축 문항   = {[x['question'] for x in q if '후원구분' in x['question']]}")
    assert len(q) == len(QUESTIONS) and not over
    assert len(t) == len(d["tool_resources"])


if __name__ == "__main__":
    main()

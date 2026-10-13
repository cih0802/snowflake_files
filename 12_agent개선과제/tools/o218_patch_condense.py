# O218 — AGENT_MARKETING 지침 축약(이관안 승인 · 2026-10-13) + 사용자 결정 Q19·F23 반영
# ㉠ 사실·도메인 지식 → 코퍼스 RT-20~25(원문 그대로 이관 · R2-8) · 지침에는 1줄 포인터
# ㉡ 중복 삭제(o-29 · o-31=o-70 · o-68=o-12 A · r-08㉡ · r-12①) ㉢ 충돌 정리(o-18 ↔ o-26 → RT-26)
# 결정 = Q19 실적 LTV 표 기본 동반(RT-27) · F23 원천 간 계산 = Agent 계산값 허용(RT-28)
# 사용: python3 o218_patch_condense.py [--check]   (--check = 쓰지 않고 앵커·크기만 점검)
# 🔴 재실행 안전 = TAG 가 있으면 변경 없음 · 앵커가 하나라도 없으면 쓰지 않고 exit 1
# Co-authored with CoCo
import csv
import io
import sys

import yaml

SPEC = "/workspace/cortex_project/agents/AGENT_MARKETING/agent_spec.yaml"
CUR = "/workspace/12_agent개선과제/tools/O217_routing_curated.csv"
TAG = "[O218 축약]"
SRC = "O218 지침 축약 이관(AGENT_MARKETING · 2026-10-13 · 원문 = output/o218/before_O218_AGENT_MARKETING.yaml)"


def cut(t, a, b):
    """a 로 시작해 b 직전까지 — 앵커 실재를 단정한다."""
    i = t.index(a)
    j = t.index(b, i + len(a))
    return t[i:j]


def main():
    check = "--check" in sys.argv
    spec = yaml.safe_load(open(SPEC, encoding="utf-8").read())
    ins = spec["instructions"]
    S, O, R = ins["system"], ins["orchestration"], ins["response"]
    if TAG in S:
        print("이미 적용됨 — 변경 없음")
        return 0
    before = len(S) + len(O) + len(R)
    rows = []

    def move(text, seg, ptr, doc, title, syn, tool, scope="MARKETING"):
        rows.append({"DOC_ID": doc, "DOC_TYPE": "라우팅", "TITLE": title, "SYNONYMS": syn,
                     "DEFINITION": seg.strip(), "FORMULA": "", "AGENT_SCOPE": scope, "TOOL_NAME": tool,
                     "SV_FIELD": "", "LIMITATION": "", "SOURCE_FILE": SRC})
        assert text.count(seg) == 1, doc
        return text.replace(seg, ptr)

    # ── ㉠ system → 코퍼스 ─────────────────────────────────────────────
    S = move(S, cut(S, "🔴 **「목표」를 뭉뚱그려", "🔴 **광고 지표는 계열이"),
             "🔴 " + TAG + " 「목표」를 뭉뚱그려 「없다」고 답하지 않는다 — 회원개발 목표 = analyst_dev_achievement · "
             "사업목표 = analyst_target_biz · 매체별·일별 목표는 원천에 없다(상세 = search_biz_definition RT-20).\n- ",
             "RT-20", "목표 유형(회원개발·매체별·일별·사업목표)", "목표|개발 목표|매체별 목표|일별 목표|사업목표|달성율",
             "analyst_dev_achievement|analyst_target_biz")
    S = move(S, cut(S, "🔴 **산출 불가 항목과 그 사유**", "🔴 **전환회원·LTV 축은"),
             "🔴 산출 불가 항목(소재별 분해·초수·캠페인 유형별 광고 효율·법인명·팀별 분해·연 편성/집행 추정 예산·"
             "잠재고객·GA 전환수)은 「데이터가 없다」로 뭉개지 말고 search_biz_definition(RT-21)에서 항목별 사유를 "
             "확인해 답한다 — 창작 금지.\n- ",
             "RT-21", "산출 불가 항목과 사유(마케팅)", "소재별|초수|광고 길이|캠페인 유형별 광고 효율|법인명|팀별|"
             "연 편성예산|집행 추정치|잠재고객|타겟그룹|GA 전환수", "analyst_ad|analyst_member_event")
    S = move(S, cut(S, "🔴 **전환회원·LTV 축은", "🔴 **연령대·성별은"),
             "🔴 전환회원(analyst_member_event = 사건 시점)·코호트(analyst_member_cohort = 획득 시점)·회비"
             "(analyst_member_fee = 납입 대상) 축은 시점이 달라 서로 더하지 않고 어느 축인지 밝힌다(RT-22).\n- ",
             "RT-22", "전환회원·코호트·회비 축의 시점 차이", "사건 시점|획득 시점|납입 대상|전환회원 축|코호트 축",
             "analyst_member_event|analyst_member_cohort|analyst_member_fee")
    S = move(S, cut(S, "🔴 **캠페인 비교는 12개월", "🔴 **마케팅캠페인 축으로"),
             "🔴 캠페인 비교는 12개월 고정 이탈률로 하고, 집행율은 집행이 존재하는 월만 분모에 넣는다 — "
             "해석 근거 = search_biz_definition RT-23.\n- ",
             "RT-23", "이탈률 비교·집행율 해석", "12개월 이탈률|누적 이탈률|중단률|집행율|편성예산|집행예산",
             "analyst_member_cohort|analyst_budget")
    S = move(S, cut(S, "- **데이터 출처(원천) 질문 응답 규칙**", "🔴🔴 **[2026-08-21 신설]"),
             "- 원천(「어디서 왔어?」) 질문은 SV COMMENT 의 [원천] 절과 search_biz_definition(RT-24 원천 지도)만 "
             "근거로 이름만 답하고, 규모·기간·커버리지 수치는 도구로 조회해 조회 시점 기준임을 밝힌다.\n- ",
             "RT-24", "마케팅 원천 지도(4계열)·원천 질문 응답", "원천|출처|어디서 왔어|bronze|데이터 출처|적재 기간",
             "")
    # ── ㉠ orchestration → 코퍼스 ──────────────────────────────────────
    O = move(O, cut(O, "🔴 [O212-B 원천 컬럼명 원칙", "🔴 [O207-B 연도말"),
             "🔴 [O212-B 분류 축] 질문의 분류 이름(브랜드·공통브랜드·캠페인유형·캠페인유형2·캠페인카테고리(주요캠페인)·"
             "개발인입경로)은 같은 이름의 SV 축으로 바로 넘긴다(원천 컬럼 대응 = search_biz_definition RT-25). "
             "묻지 않은 분류 축을 함께 GROUP BY 하지 않는다. 축 이름(예: 「캠페인유형별」)을 그대로 넣는다.\n\n",
             "RT-25", "분류 축 ↔ 원천 컬럼 대응", "브랜드|공통브랜드|캠페인유형|캠페인유형2|캠페인카테고리|주요캠페인|"
             "개발인입경로|인입경로", "analyst_mstr_spnsr_dvlp")

    # ── ㉡ 중복 삭제 ──────────────────────────────────────────────────
    o29 = cut(O, "🔴 [O207 교차 규칙", "🔴 식별자 규칙")
    O = O.replace(o29, "")
    o68 = cut(O, "🔴 🆕 [O216-D]", "🔴 🆕 [O216-C 9차] 도구 호출")
    O = O.replace(o68, "🔴🔴 MSTR 기준과 GN_DW 기준 수치를 한 표에서 합산·차감·비율 계산하지 않는다 — 함께 필요하면 "
                       "표를 나누고 각 표 제목에 기준(「MSTR 기준」·「GN_DW 기준」)을 단다.\n\n")
    for a in ["㉡ ① 핵심 요약은 한 번만 쓴다(같은 블록 재출력 금지). ",
              "① 답변은 한국어 본문만 쓴다 — 내부 판단·도구 선택 과정(영어 계획 문장 등)을 본문에 쓰지 않고, "
              "같은 내용을 두 번 출력하지 않는다. "]:
        assert R.count(a) == 1, a[:20]
        R = R.replace(a, "")

    # ── ㉢ 충돌 정리 o-18 ↔ o-26 ─────────────────────────────────────
    o18 = cut(O, "🔴 🆕 [O217 예측 우선순위]", "[공통 · 중간 메시지")
    O = O.replace(o18, "🔴 🆕 [O217 예측 우선순위 · O218 충돌 정리] 익월·향후 N개월 개발 예측과 개발 **금액** 예측은 "
                       "머신러닝 예측(analyst_ml_dvlp_forecast · 금액 만원)을 먼저 제시한다(건수 예측은 없다고 밝힌다). "
                       "연말·연도말 예측은 아래 [O207-B] 가 우선한다(RT-26).\n\n")
    a = "**회원개발 예측(익월·연말·향후 3개월)**"
    assert O.count(a) == 1
    O = O.replace(a, "**회원개발 예측(익월·향후 3개월 · 금액)**")
    rows.append({"DOC_ID": "RT-26", "DOC_TYPE": "라우팅", "TITLE": "개발 예측 우선순위(익월·연말)",
                 "SYNONYMS": "익월 예측|연말 예측|연도말 전망|향후 3개월|개발 예측",
                 "DEFINITION": "익월·향후 N개월 개발 예측과 개발 금액 예측 = 머신러닝 개발금액 예측(만원)을 먼저 제시하고 "
                               "건수 예측은 없다고 밝힌다. 연말·연도말 개발 예측(건수·부서·후원사업·신규) = MSTR 연도말 "
                               "추세 참고치(건)를 먼저 제시하고 ML 금액 예측은 별도 참고 표로만 둔다. 두 값을 섞거나 환산하지 않는다.",
                 "FORMULA": "MSTR 연도말 추세 = 마감월 실적 + 남은 월 × 직전 3개월 평균", "AGENT_SCOPE": "MARKETING",
                 "TOOL_NAME": "analyst_ml_dvlp_forecast|analyst_mstr_spnsr_dvlp", "SV_FIELD": "",
                 "LIMITATION": "추세 참고치는 모델 예측이 아니다.", "SOURCE_FILE": SRC + " · o-18↔o-26 충돌 정리"})

    # ── 사용자 결정 Q19 · F23 ─────────────────────────────────────────
    a = "(실적 표와 합산 금지).\n\n"
    assert O.count(a) == 1
    O = O.replace(a, "(실적 표와 합산 금지). 🆕 [O218 사용자 결정 Q19] 「LTV 가 높을(높은) 캠페인·채널」 질문은 "
                     "ML LTV 예측 표와 실적 LTV 표(⑤ 방식)를 **항상 둘 다** 분리해 제시한다(RT-27).\n\n")
    rows.append({"DOC_ID": "RT-27", "DOC_TYPE": "라우팅", "TITLE": "LTV 질문 기본 응답(예측 + 실적)",
                 "SYNONYMS": "LTV 높은 캠페인|LTV 높은 채널|장기 가치|LTV 창출", "DEFINITION":
                 "LTV 가 높을(높은) 캠페인·채널 질문은 머신러닝 LTV 예측 표와 실적 LTV 표(평균 월 납입회비 × 평균 "
                 "유지개월수 · 캠페인 축)를 항상 함께, 분리된 표로 제시한다. 두 표를 합산하지 않는다.",
                 "FORMULA": "실적 LTV = 평균 월 납입회비 × 평균 유지개월수", "AGENT_SCOPE": "MARKETING",
                 "TOOL_NAME": "analyst_ml_ltv_forecast|analyst_member_fee|analyst_member_cohort", "SV_FIELD": "",
                 "LIMITATION": "실적 LTV 는 Agent 계산값 · 평균 유지기간은 중단 회원 기준이라 과소일 수 있다.",
                 "SOURCE_FILE": "O218 사용자 결정 Q19 (2026-10-13)"})
    a = ("  · **CRM 개발실적 기준**(광고비 ÷ CRM 개발 사건수) = **산출 불가**다. 광고비와 CRM 개발실적은\n"
         "    서로 다른 팩트이므로 한 지표식으로 묶을 수 없다(cross-fact). 요구받으면 SQL 을 만들지 말고\n"
         "    두 팩트가 다르다는 것과 대행사 기준 대안을 밝힌다.\n")
    assert S.count(a) == 1
    S = S.replace(a, "  · **CRM 개발실적 기준**(광고비 ÷ CRM 개발건)은 정의된 지표가 아니다. 🆕 [O218 사용자 결정 F23] 사용자가 "
                     "산식을 지정해 요청하면(예: (제작비+광고비) ÷ 개발건수) SQL 로 조인하지 말고 도구를 같은 마케팅캠페인명 "
                     "축으로 각각 호출한 뒤 결과값으로 계산하고 「Agent 계산값 · 원천 간 계산 · 고정값 아님」을 붙인다. "
                     "캠페인명이 모든 원천에 있는 행만 계산하고 나머지 행은 단가를 비운 채 사유를 밝힌다. "
                     "요청이 없으면 먼저 계산하지 않는다(RT-28).\n")
    a = "  ⇒ 여러 원천이 필요하면 **표를 분리하고 각 표에 원천을 각주**로 단다.\n"
    assert S.count(a) == 1
    S = S.replace(a, a.rstrip("\n") + " 단 사용자가 산식을 지정한 원천 간 계산(F23 결정)은 결과값 계산을 허용한다.\n")
    rows.append({"DOC_ID": "RT-28", "DOC_TYPE": "라우팅", "TITLE": "원천 간 계산(사용자 지정 산식)",
                 "SYNONYMS": "통합 성과|제작비+광고비|개발단가 계산|CRM 기준 개발단가|LTV/CAC", "DEFINITION":
                 "사용자가 산식을 지정해 원천을 넘나드는 계산(예: (제작비 ERP + 광고비 대행사) ÷ 개발건수 CRM)을 요청하면 "
                 "SQL 로 조인하지 않고 각 도구를 같은 마케팅캠페인명 축으로 따로 호출한 뒤 결과값으로 계산한다. "
                 "캠페인명이 모든 원천에 있는 행만 계산하고, 한쪽에만 있는 행은 값을 비우고 사유를 밝힌다.",
                 "FORMULA": "개발단가(원천 간) = (제작비 + 광고비) ÷ 개발건수", "AGENT_SCOPE": "MARKETING",
                 "TOOL_NAME": "analyst_expense_resolution|analyst_ad|analyst_mstr_spnsr_dvlp", "SV_FIELD": "",
                 "LIMITATION": "「Agent 계산값 · 원천 간 계산 · 고정값 아님」 표기 필수 · 요청 없이 먼저 계산하지 않는다 · "
                               "대행사 리포트 기준 개발단가(공7·공8)와 다른 지표다.",
                 "SOURCE_FILE": "O218 사용자 결정 F23 (2026-10-13)"})

    after = len(S) + len(O) + len(R)
    print("지침 3필드 %d → %d 자 (%.1f%%) · 코퍼스 신규 %d행 %s" % (before, after, (after - before) * 100.0 / before,
                                                          len(rows), [r["DOC_ID"] for r in rows]))
    if check:
        return 0
    ins["system"], ins["orchestration"], ins["response"] = S, O, R
    o = io.StringIO()
    yaml.safe_dump(spec, o, allow_unicode=True, sort_keys=False, width=200)
    open(SPEC, "w", encoding="utf-8").write(o.getvalue())
    with open(CUR, encoding="utf-8-sig", newline="") as fh:
        rd = csv.DictReader(fh)
        cols, old = rd.fieldnames, list(rd)
    have = {r["DOC_ID"] for r in old}
    new = [r for r in rows if r["DOC_ID"] not in have]
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=cols, lineterminator="\n")
    w.writeheader()
    w.writerows(old + new)
    open(CUR, "w", encoding="utf-8", newline="").write(buf.getvalue())
    back = yaml.safe_load(open(SPEC, encoding="utf-8").read())["instructions"]
    n = sum(1 for _ in csv.DictReader(open(CUR, encoding="utf-8-sig", newline="")))
    ok = TAG in back["system"] and n == len(old) + len(new)
    print("쓰기", "OK" if ok else "🔴 되읽기 실패", "· curated 행", len(old), "→", n)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""30개 추천 질문에 대한 Cortex Analyst 질의 및 SQL 생성/실행 검증 스크립트"""

import json
import subprocess
import sys
import time

QUESTIONS = [
    # AGENT_MEMBER
    {
        "agent": "AGENT_MEMBER",
        "id": "M1",
        "question": "후원사업별·납입방식(결제수단)별 회비 청구액과 납부율을 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_FEE",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M2",
        "question": "연도별 납부율과 미납비중 추이를 보여줘 (2023-2025)",
        "view": "GN_DW.SERVING.SV_MEMBER_MONTHLY",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M3",
        "question": "개발구분별(신규·증액·감액·재후원·후원중단) 개발/중단 건수와 고유 회원수는?",
        "view": "GN_DW.SERVING.SV_MEMBER_EVENT",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M4",
        "question": "세부캠페인 후원구분(정기후원/일시후원)·법인구분(통합/사단/사복)별 개발건수는?",
        "view": "GN_DW.SERVING.SV_MEMBER_EVENT",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M5",
        "question": "연령대별·지역별 개발건수는? (약정 시점 기준)",
        "view": "GN_DW.SERVING.SV_MEMBER_EVENT",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M6",
        "question": "주요캠페인(캠페인카테고리)별 12개월 이탈률과 획득 회원수를 비교해줘",
        "view": "GN_DW.SERVING.SV_MEMBER_COHORT",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M7",
        "question": "2025년 부서별·월별 개발 목표와 실적, 달성율 추이를 보여줘",
        "view": "GN_DW.SERVING.SV_DEV_ACHIEVEMENT",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M8",
        "question": "캠페인별·후원사업별 지금 활동회원 수를 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M9",
        "question": "채널별 발송수와 발송결과(발송상태·통신사 도달결과)를 보여줘",
        "view": "GN_DW.SERVING.SV_SERVICE",
    },
    {
        "agent": "AGENT_MEMBER",
        "id": "M10",
        "question": "행사종류별 참여자수와 참여상태별 분포는?",
        "view": "GN_DW.SERVING.SV_EVENT_PARTICIPATION",
    },
    # AGENT_OVERALL
    {
        "agent": "AGENT_OVERALL",
        "id": "O1",
        "question": "예산구분별 편성예산과 집행예산, 집행율을 집행이 있는 월까지로 보여줘",
        "view": "GN_DW.SERVING.SV_BUDGET",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O2",
        "question": "2025년 디지털 광고 CTR·개발단가와 방송 채널사별 광고비·인바운드콜을 계열을 나눠 보여줘",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O3",
        "question": "전사 납입회비 총액과 미납비중을 연도별로 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_MONTHLY",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O4",
        "question": "채널별 발송수를 월별로 보여줘",
        "view": "GN_DW.SERVING.SV_SERVICE",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O5",
        "question": "전사 개발금액 예측을 예측월별로 보여줘 (만원, 예측)",
        "view": "GN_DW.SERVING.SV_ML_DVLP_FORECAST",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O6",
        "question": "부서별·신규기존·후원사업별 개발 예측을 전사 합계와 함께 비교해줘 (예측)",
        "view": "GN_DW.SERVING.SV_ML_DVLP_FORECAST",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O7",
        "question": "상위캠페인(채널)별 회원평균 LTV 예측 상위 10곳은? (예측)",
        "view": "GN_DW.SERVING.SV_ML_LTV_FORECAST",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O8",
        "question": "캠페인별 후원총액 LTV 스코어 상위 10곳은? (예측)",
        "view": "GN_DW.SERVING.SV_ML_LTV_SCORE",
    },
    {
        "agent": "AGENT_OVERALL",
        "id": "O9",
        "question": "신규 후원 유치와 증액 개발의 상위 5개 기여 요인을 보여줘 (예측)",
        "view": "GN_DW.SERVING.SV_ML_FEATURE_IMPORTANCE",
    },
    # AGENT_MARKETING
    {
        "agent": "AGENT_MARKETING",
        "id": "K1",
        "question": "2025년 부서별·월별 개발 목표와 실적, 달성율을 보여줘",
        "view": "GN_DW.SERVING.SV_DEV_ACHIEVEMENT",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K2",
        "question": "예산구분별·세세목별 편성예산과 집행예산, 집행율을 보여줘",
        "view": "GN_DW.SERVING.SV_BUDGET",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K3",
        "question": "2025년 디지털 광고의 광고유형별 광고비·노출·클릭·CTR과 개발단가를 보여줘",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K4",
        "question": "디지털 광고의 주차별·요일별 효율(노출·클릭·CTR)을 비교해줘",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K5",
        "question": "방송 채널사별·CM위치별 광고비와 인입콜을 보여줘",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K6",
        "question": "재방유형별 재방송 개발건수와 재방송 개발단가는?",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K7",
        "question": "마케팅캠페인별 광고비와 CTR 상위 10곳을 전체 총계와 함께 보여줘",
        "view": "GN_DW.SERVING.SV_AD",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K8",
        "question": "연령대별·개발구분별 전환회원 건수와 고유 회원수를 상위캠페인 축과 함께 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_EVENT",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K9",
        "question": "캠페인별 평균 유지기간·12개월 이탈률과 총납입회비를 상위 10곳으로 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_COHORT",
    },
    {
        "agent": "AGENT_MARKETING",
        "id": "K11",
        "question": "캠페인별·후원사업별 지금 활동회원 수를 보여줘",
        "view": "GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ",
    },
]


def test_question(item):
    cmd = [
        "cortex",
        "analyst",
        "query",
        item["question"],
        f"--view={item['view']}",
    ]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30
        )
        if proc.returncode != 0:
            return False, f"CLI error: {proc.stderr.strip()[:100]}"
        data = json.loads(proc.stdout)
        res = data.get("result", "")
        if "```sql" in res:
            sql = res.split("```sql")[1].split("```")[0].strip()
            return True, sql
        return False, f"No SQL generated: {res[:100]}"
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)


def main():
    print(f"=== Cortex Analyst 30개 추천 질문 테스트 시작 (총 {len(QUESTIONS)}문항) ===")
    pass_cnt = 0
    fail_cnt = 0
    results = []
    for idx, q in enumerate(QUESTIONS, 1):
        ok, detail = test_question(q)
        if ok:
            pass_cnt += 1
            status = "🟢 PASS"
            summary = detail.replace("\n", " ")[:80]
        else:
            fail_cnt += 1
            status = "🔴 FAIL"
            summary = str(detail)[:80]
        print(f"[{idx:02d}/{len(QUESTIONS)}] {status} [{q['agent']}|{q['id']}] {q['question'][:30]}... -> {summary}")
        results.append({
            "id": q["id"],
            "agent": q["agent"],
            "question": q["question"],
            "view": q["view"],
            "status": "PASS" if ok else "FAIL",
            "detail": detail,
        })
        time.sleep(0.5)

    print(f"\n=== 결과 요약 ===")
    print(f"총 {len(QUESTIONS)}문항 중 성공(SQL 생성): {pass_cnt}건, 실패: {fail_cnt}건")
    with open("/tmp/cortex_30_result.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()

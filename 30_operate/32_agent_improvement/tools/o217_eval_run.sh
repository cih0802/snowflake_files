#!/bin/sh
# O217 전후 비교 — 사용법: sh o217_eval_run.sh <before|after> [문항ID ...] · 결과 = output/o217_eval/<tag>_<ID>.txt
# 🔴 순차 실행(병렬 5개는 rc=137 메모리 종료 실측) · 문항ID 를 주면 그 문항만
# Co-authored with CoCo
TAG=$1; shift; ONLY=" $* "; D=/workspace/12_agent개선과제/output/o217_eval
A=GN_DW.SERVING.AGENT_MARKETING
run() {
  case "$ONLY" in "  ") ;; *" $1 "*) ;; *) return ;; esac
  timeout 400 cortex agents run $A "$2" </dev/null >$D/${TAG}_$1.txt 2>&1; echo "$1 rc=$?" >$D/${TAG}_$1.rc
}
run Q24 "일별리포트에서 2026년 5월 META 매체의 개발건수를 가져와줘."
run Q25 "2025년 6월 DR광고의 채널별 개발(명)과 개발(건)을 개발(명)이 많은 순서대로 보여줘."
run Q19 "가장 높은 LTV를 창출할 것으로 예상되는 캠페인은? LTV 산출 근거와 계산식도 알려줘."
run QM4 "2026년 1-9월 사단법인 정기회원 회비를 확인하고, 추이를 통해 10월 회비를 예측해줘."
run QC8 "공통브랜드별 2026년 9월 개발(건)을 보여줘."

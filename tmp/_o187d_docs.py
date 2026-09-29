"""[O187-D] 30_output_share 수기 문서 최신화 — 머리 블록 삽입 + 거짓이 된 문장 옆 포인터(원문 보존).
사실 근거 = 이 세션(O182~O187) 라이브 실측(xf98254 · 2026-09-28) · 정본 좌표는 각 블록에 명시.
"""
import io, os
D = '30_output_share'
H = '> 🆕🆕 **[2026-09-28 O187-D 최신화]** 아래 본문은 작성 시점 기준이다 — **O182~O187 변경분**을 여기 먼저 적는다(실측 xf98254).\n'
F = {
 'E6':  '> · 🟢 **사업목표 원천 입고(E-6)** — `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV` **290행**(2026 · `연사업` 154행 합 348,024건 · `팀` 136행 합 348,000건).\n'
        '>   🔴 두 유형 합이 거의 같아 **같은 목표의 이중 분해**로 보인다 ⇒ `SILVER.CRM_BIZ_TARGET`·`GOLD.FACT_TARGET_PROJECT` 는 **0행 유지**(배선은 현업 회신 후 · 문서20 N-24 ①).\n',
 'D44': '> · 🟢 **예산 차수 이중계상(DEC-44) 해소** — GOLD 는 연도별 최신 차수만 · 연 편성 65,202,608,327원 · 집행 55,094,546,654원 · SV_BUDGET 「보류」 해제.\n'
        '>   ⚠️ **2024 년은 원천에 월별 편성 배분이 없다**(연 총액만) ⇒ 2024 월 집행율은 산출 불가(문서20 N-24 ②).\n',
 'AD':  '> · 🟢 **대행사 광고 원천 재편(O182)** — VIDEO 도 개발건을 보고한다(8,756행) ⇒ 「VIDEO 개발실적 부재」(AD-5)는 **더 이상 사실이 아니다** ·\n'
        '>   SV_AD·Agent 문안 정정 완료 · 방송 시간대는 VIDEO=구간 라벨 / 재방송=시각 · DIGITAL 은 2026-06 이후 단가만 보고(`CRM_DEV_CNT` 전건 NULL).\n',
 'ML':  '> · 🟢 **일시후원 → 정기전환 예측(ML)** — `SV_ML_ONCE_CONVERSION` 배포 + 성별·회원구분·등록부서 3축(현재 마스터 기준) · AGENT_MEMBER VERSION$5.\n',
 'OPS': '> · 🟢 **운영** — dbt 실행 전용 롤 `GN_DW_DBT` 전환(ENGINEER 는 사람 작업 권한으로 축소) · 최신 전체 build PASS 543 · WARN 21 · ERROR 0 ·\n'
        '>   GA4 백필은 `EXECUTE DBT PROJECT … ARGS=\'… --vars …\'` 1줄로 가능(재배포 불요 · 런북 `10_dbt_pipeline/02_dbt_parse_compile_build.sql` Step 3).\n',
 'Q':   '> · 🆕 **현업 문항 신규** — 문서20 **N-23**(최초등록일 71,325명 · 행사 2건 · 발송결과 채널 분할) · **N-24**(사업목표 이중 분해 · 2024 월 편성) ·\n'
        '>   **N-25**(열린 36건 재판정 — AD-5 **폐기 권고** · D-2 는 실측상 CRM). 열린 판정 = 56건 중 **36건 미회신**.\n',
}
PLAN = {
 '01_DW_현업활용가이드.md':            ['AD', 'D44', 'ML'],
 '10_원천입고_결손요약.md':            ['E6', 'AD', 'D44'],
 '15_문서 통합.md':                   ['E6', 'D44', 'AD', 'Q'],
 '16_파이프라인 배선 수정.md':          ['D44', 'AD', 'ML', 'OPS'],
 '17_현업의사결정 요청.md':             ['Q', 'E6', 'D44'],
 '18_목표데이터_요건_및_해결이슈_정의서.md': ['E6'],
 '19_원천입고_및_항목신설_대기.md':      ['E6', 'AD', 'D44'],
 '20_현업의사결정_요청_주니어_해설서.md':  ['Q', 'E6'],
 '21_원천입고_대기_주니어_해설서.md':     ['E6', 'AD'],
 '22_요청서 통합 및 매핑.md':           ['Q'],
}
TAG = 'O187-D 최신화'
for name, keys in PLAN.items():
    p = os.path.join(D, name); L = io.open(p, encoding='utf-8').read().split('\n')
    if any(TAG in l for l in L): print('skip(already)', name); continue
    i = next((k for k, l in enumerate(L) if l.startswith('# ')), -1)
    block = (H + ''.join(F[k] for k in keys)).rstrip('\n').split('\n')
    L[i+1:i+1] = [''] + block
    io.open(p, 'w', encoding='utf-8', newline='').write('\n'.join(L)); print('block', name, len(block))

# 거짓이 된 문장 옆 포인터(원문 보존 · 줄 끝에 덧붙임)
PTR = ' 🆕[2026-09-28] → **원천 입고됨**(`BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV` 290행) · 배선은 문서20 N-24 회신 후'
EDITS = [
 ('10_원천입고_결손요약.md',   '| **CRM** | 사업목표(본부/지부·팀·후원사업별) | — | `E-6` · 문서41 회신대기 |'),
 ('19_원천입고_및_항목신설_대기.md', '  * `SILVER.CRM_BIZ_TARGET` = **0행** (dbt 모델은 배선 완료 · 스텁 상태)'),
 ('18_목표데이터_요건_및_해결이슈_정의서.md', '> 🟢 라이브 실측(2026-09-10) = `SILVER.CRM_BIZ_TARGET` **0행** · `GOLD.FACT_TARGET_PROJECT` **0행**'),
]
for name, line in EDITS:
    p = os.path.join(D, name); t = io.open(p, encoding='utf-8').read()
    if PTR in t: print('skip ptr', name); continue
    assert t.count(line) == 1, (name, line[:40])
    new = line[:-1] + PTR + ' |' if line.endswith('|') else line + PTR
    io.open(p, 'w', encoding='utf-8', newline='').write(t.replace(line, new)); print('ptr', name)

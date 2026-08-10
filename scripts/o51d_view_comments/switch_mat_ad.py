# -*- coding: utf-8 -*-
"""[2026-08-10 O51-F] 광고 위성 2모델을 materialized='gn_view_commented' 로 전환.

동시 처리
  · `post_hook` 의 `COMMENT ON VIEW` 제거 — 뷰 COMMENT 정본은 schema.yml `description` 이고 매크로가 적용한다.
  · 헤더의 **stale 하드코딩 행수 제거**(규칙 7). 종전 기재는 재적재(O41)로 어긋났고, 그 불일치가
    「원인 미규명」으로 방치돼 있었다 — 원인은 재적재였다(O51-F 실측).

🔴 멱등 가드는 **config 블록만** 본다. O51-D-B 에서 주석 문구에 오탐해 8모델을 조용히 스킵한 사례가 있다.

🔴🔴 **본 스크립트의 최초 판이 모델 2개를 손상시켰다**(2026-08-10 · 즉시 복구). 원인 =
   `re.search` 로 config 블록의 **오프셋을 먼저 잡고**, 그 뒤에 헤더 문자열을 치환해 **오프셋이 밀린 상태로**
   `t[:start] + new + t[end:]` 를 실행한 것이다. 밀린 만큼의 본문이 잘려 나갔고 config 블록은 남았다.
   ⇒ 🆕 **P116: 문자열 슬라이스 편집은 오프셋을 잡은 뒤 그 문자열을 바꾸면 안 된다.**
     치환을 모두 끝낸 다음 **다시 검색**해서 슬라이스한다(아래 순서가 그 교정판이다).
"""
import io, re, sys

B = '/workspace/10_dbt_pipeline/models/gold/wide/'
FILES = [B + 'WIDE_AD_BROADCAST.sql', B + 'WIDE_AD_DIGITAL.sql']

OLD_NOTE = "--   ⛔ 컬럼 COMMENT 복구 = materialized='gn_view_commented' + yml columns[] 이관(O51-C 잔여)."
NEW_NOTE = (
"--   ✅ [2026-08-10 O51-F] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.\n"
"--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)\n"
"--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **제거**.\n"
"--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.\n"
"--   🔄 종전 「DROP 예정」 결정 철회(2026-08-10): 이 뷰는 dbt 모델이라 물리 DROP 은 다음 build 가 되살리며,\n"
"--     DEC-8/DEC-10 이 위성 단독 완결을 설계 의도로 명시한다. 보존 + COMMENT 이관으로 확정했다.")

# 헤더 stale 수치 제거 (규칙 7) — 행수는 이슈원장 §O51-F 에 둔다.
HEADER_FIX = [
 ("-- grain = AD_PERF_DK (FAD_B 와 1:1). 실측 37,886행 (VIDEO 35,822 + REBRDC 2,064).",
  "-- grain = AD_PERF_DK (FAD_B 와 1:1). 원천유형 VIDEO·REBROADCAST 2종의 완전 수직분할 지분이다.\n"
  "-- 🔴 행수를 여기에 적지 않는다(규칙 7) — 종전 하드코딩이 재적재로 stale 이 됐고 그 불일치가\n"
  "--   「원인 미규명」으로 방치됐다. 원인은 재적재였다(O51-F 실측). 규모는 이슈원장 §O51-F."),
 ("-- grain = AD_PERF_DK (FAD_D 와 1:1). 실측 197,686행 (DGT).",
  "-- grain = AD_PERF_DK (FAD_D 와 1:1). 원천유형 DIGITAL 단독 지분이다.\n"
  "-- 🔴 행수를 여기에 적지 않는다(규칙 7) — 종전 하드코딩이 재적재로 stale 이 됐다. 규모는 이슈원장 §O51-F."),
 ("--    VIDEO 전용: CM_POSITION·AD_START_TIME·AD_END_TIME·CHANNEL_COMPANY_TYPE·SPOT_TYPE·\n"
  "--                DURATION_SEC·DAY_DIV·PRG_START_TIME·CTV_DIV·CONV_CALL_CNT·AD_VIEW_RT_SRC·CPC_SRC",
  "--    VIDEO 전용: CM_POSITION·AD_START_TIME·AD_END_TIME·CHANNEL_COMPANY_TYPE·SPOT_TYPE·\n"
  "--                DURATION_SEC·DAY_DIV·PRG_START_TIME·CTV_DIV·AD_VIEW_RT_SRC·CPC_SRC\n"
  "--    🔴 [O51-F 실측] CONV_CALL_CNT 는 VIDEO 전용 컬럼이 맞지만 **원천에서 전건 비어 있다** —\n"
  "--      종전 「VIDEO 는 개발 대신 전환콜을 보고한다」는 기술은 컬럼 존재 기준으로만 참이다(AD-5 보강)."),
]

for f in FILES:
    t = io.open(f, encoding='utf-8').read()
    cfg0 = re.search(r"\{\{ config\((.*?)\n\) \}\}", t, re.S)
    if not cfg0:
        sys.exit(f"🔴 config 블록 미발견: {f}")
    if "materialized='gn_view_commented'" in cfg0.group(1):
        print(f"⏭  이미 전환됨: {f.split('/')[-1]}")
        continue
    tags = ",\n    tags=['gold_pending']" if "gold_pending" in cfg0.group(1) else ""

    # ① 문자열 치환을 **먼저 전부** 끝낸다.
    t = t.replace(OLD_NOTE, NEW_NOTE)
    n_hdr = 0
    for a, b in HEADER_FIX:
        if a in t:
            t = t.replace(a, b); n_hdr += 1

    # ② 그 다음 **다시 검색**해서 슬라이스한다(P116 — 오프셋 재획득).
    cfg = re.search(r"\{\{ config\((.*?)\n\) \}\}", t, re.S)
    if not cfg:
        sys.exit(f"🔴 치환 후 config 블록 소실: {f}")
    new = "{{ config(\n    materialized='gn_view_commented'" + tags + "\n) }}"
    t = t[:cfg.start()] + new + t[cfg.end():]

    # ③ 사후 검증 — config 블록이 정확히 1개이고 SELECT 가 살아 있는지 확인한다.
    if t.count('{{ config(') != 1 or '\nselect' not in t:
        sys.exit(f"🔴 사후 검증 실패(손상 의심) — 쓰지 않고 중단: {f}")
    io.open(f, 'w', encoding='utf-8').write(t)
    print(f"✅ {f.split('/')[-1]}  post_hook 제거 · 헤더 stale 교정 {n_hdr}건 · tags={'유지' if tags else '없음'}")

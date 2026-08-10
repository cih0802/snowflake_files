# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D] 8모델을 materialized='gn_view_commented' 로 전환하고 post_hook 을 제거한다."""
import io, re, sys
B='/workspace/10_dbt_pipeline/models/gold/'
FILES = [B+'wide/WIDE_MEMBER_MONTHLY.sql', B+'wide/WIDE_MEMBER_EVENT.sql',
         B+'wide/WIDE_SERVICE_EVENT.sql', B+'wide/WIDE_EVENT_PARTICIPATION.sql',
         B+'wide/WIDE_MEMBER_FEE.sql', B+'wide/WIDE_DEV_ACHIEVEMENT.sql',
         B+'dim/DIM_MEMBER_CURRENT.sql', B+'dim/DIM_MEMBER_ACQUISITION.sql']

OLD_NOTE = "--   ⛔ 컬럼 COMMENT 복구 = materialized='gn_view_commented' + yml columns[] 이관(O51-C 잔여)."
NEW_NOTE = ("--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.\n"
            "--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)\n"
            "--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.\n"
            "--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.")

for f in FILES:
    t = io.open(f, encoding='utf-8').read()
    if re.search(r"\{\{ config\([^)]*materialized='gn_view_commented'", t, re.S):
        print(f"⏭  이미 전환됨: {f.split('/')[-1]}"); continue
    t = t.replace(OLD_NOTE, NEW_NOTE)
    m = re.search(r"\{\{ config\((.*?)\n\) \}\}", t, re.S)
    if not m: sys.exit(f"🔴 config 블록 미발견: {f}")
    body = m.group(1)
    tags = "\n    tags=['gold_ready']," if "tags=['gold_ready']" in body else ""
    new = "{{ config(\n    materialized='gn_view_commented'" + (tags.rstrip(',') if tags else "") + "\n) }}"
    t = t[:m.start()] + new + t[m.end():]
    io.open(f,'w',encoding='utf-8').write(t)
    print(f"✅ {f.split('/')[-1]}  post_hook 제거 · tags={'유지' if tags else '없음'}")

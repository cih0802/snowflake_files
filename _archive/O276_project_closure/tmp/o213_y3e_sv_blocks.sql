-- O213-E · build 후 SV_SERVICE 정본(05_4) 에 넣을 TABLES / RELATIONSHIPS 블록(생성기 범위 밖 · 사람/에이전트가 edit 로 반영)
-- ① TABLES ( … member AS … ) 블록 끝 member 항목 뒤에 쉼표 후 추가:
    req AS GN_DW.GOLD.DIM_SEND_REQUEST
      PRIMARY KEY (SEND_REQUEST_SK)
      WITH SYNONYMS ('발송 요청', '발송 요청 차원')
      COMMENT = '🆕 [O213-E] 발송 요청 차원(1행 = 발송 요청 1건 · SNDNG_KEY). 발송 카테고리(대/중/소)·메시지 구분·발송 시간 구분·우편 처리상태·재발송·대량 여부 축. 🔴 채널마다 원천이 달라 축 대부분이 한 채널 전용이다(비해당 채널 NULL). FACT_MESSAGE_DISPATCH 의 SEND_REQUEST_SK 로 잇는다(2026-10-08 매칭 43,889,463 / 43,892,464 · 0 = 요청 미매칭).'
-- ② RELATIONSHIPS ( … ) 끝에 쉼표 후 추가:
    fse_to_req     AS fse (SEND_REQUEST_SK) REFERENCES req
-- ③ 그 다음 생성기: python3 tmp/o213_y3_sv_gen.py --spec /workspace/tmp/o213_y3e_sv_spec.tsv --apply
-- ④ 배포: python3 tmp/o213_y3_deploy.py SV_SERVICE · 스모크: python3 tmp/o213_y3_smoke.py --spec /workspace/tmp/o213_y3e_sv_spec.tsv

## O243 계정 iw20760 eval o242b 재실행(정답지 V3~V6 재구성) · 배선 보류 12건 처리 · 공91 측정 대상 교체 · SV 3종 metric 신설·라이브 배포 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 = eval·③·라이브 배포·신설 전부 · 확정위반 0)

- 착수 = `/init_ihcho` 브리핑 후 사용자 「전부 승인」 → 실측으로 차단 보고(계정 iw20760 ≠ mn11232 · 정답지 미발견) → 사용자 「VERSION$3 = VERSION$8 · 정답지 그대로 · 3번 진행」 → 「라이브 배포 신설 전부 승인」.
- ① 정답지 = 이 계정 GN_DW.SERVING 에 EVAL_O224_* 0행(GN_DW_ADMIN 확인 · rc=0) ⇒ V3(코퍼스 CSV · dry 부재도구 0) → V4(덮어쓰기 6/6) → V5 → V6 재구성 · DS 12.
  - eval o242b(DEFAULT = VERSION$3) = EXEC 0.968/0.858/0.952/0.733 · MKT 0.976/0.859/0.952/0.979 · MEM 0.795/0.746/0.568/0.522(AC/LC/TS/TE).
  - o241s 비교는 지표 순서 AC/LC/TS/TE 가정 · 저점 문항 = MEM D3·R14·R15 · EXEC Q13.
- ③ 판정표 `tmp/o241/wiring_decisions.tsv` 실측 = ㉠ 117 · 보류 12 · 기처리 1 ⇒ 인수인계 「㉠ 115 · 보류 14」 집계 오기.
  - 공91 = FACT_MESSAGE_DISPATCH.GIFT_PART_AMT 전건 0(44,406,102행) · D5_GIFT_PART_AMT 합 1,303,750,000(32 기대값 일치) ⇒ 생성기 MEASURE_OVERRIDE 교체 · test_metric_sv_wiring PASS.
  - 공13 = SV_AD 에 AD_TYPE_NM(DA·SA·BSA·CPT 실재) 차원이 이미 있었다(보류 사유 「축 없음」 오판) ⇒ AD_TYPE_NM·CHANNEL_COMPANY_TYPE 에 '공13'.
  - 신설 = SV_MEMBER_MONTHLY.YEAR_START_ACTIVE_MEMBERS(공48) · SV_GA_BEHAVIOR.ACTIVE_USERS_ROWSUM(공93) · AVG_SCROLL_DEPTH·MAX_SCROLL_DEPTH(공107).
  - 공66 = DIM_PAYMENT.FEE_TYPE·WIDE_MEMBER_MONTHLY.PAYMENT_FEE_TYPE 전건 NULL ⇒ 보류 유지 · 공112 = 개인정보 👤 결정 · 공59·60 유지.
- 검증 = 임시 이름 3/3 PASS → 배포 3파일 OK → 라이브 조회(공48 202609 658,911 = GOLD 직접 · 스크롤 평균 71.77 · AD_TYPE_NM 별 광고비) · line_len PASS.
- 산출물 = census 재측정 → `30_output_share/05_지표GOLD매핑.{csv,md,xlsx}` 재생성 · 공91 WAIT → PARTIAL(비영 26,544).
- 부수 = `id_collision_gate --next O` 60초 초과(rc=143) ⇒ 백그라운드 재실행.

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R4-4-4`.
- `20_issue/00_BRIEF.md` 1~149 · 도착 · `O0242-B` · `campaign_axis_gate`.
- `99_NEXT_SESSION-O0242-A.md` 1~58 · `-O0242-B.md` 1~57 · 도착 · `000666` · `ML_CHURN_BY_CMPGN_CTGR_V`.
- `99_NEXT_SESSION-O0241-B.md` 1~56 · 도착 · `공147` · `003001`.
- `tmp/o242b/eval_b.py` 1~81 · `tmp/o241b/o224_eval_local.py` 1~58 · 도착 · `EXECUTE_AI_EVALUATION` · `o224_{k}_{TAG}`.
- `scripts/gen_metric_gold_mapping.py` 1~40 · 86~115 · 496~625 · 도착 · `MEASURE_OVERRIDE` · `OK_FILL_MIN`.
- read 미반환 0 · 재호출 0.

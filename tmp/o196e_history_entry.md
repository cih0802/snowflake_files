
> #### 🟢 [2026-10-01 O196-E] dbt build 판정 · SV_RELATION_ACTIVITY 신설 · D-4 ⓑ 확정 · ERP 예산단위 질의 진단 (pw69582 · ㉡ 적용 · 확정위반 0)
>
> - build(사용자 PASS 101 · WARN 1) 판정 = STOP 1,061,430(불변) · 배선 99.74% · DIM_SEND_REQUEST 1,722,090 · FACT_RELATION_ACTIVITY 398,630(회원 NULL 315) · 🔴 FMD `SEND_REQUEST_SK` 고아 11,421 ⇒ 모델을 요청 조인 기준으로 수정(재build 대기).
> - `05_12_SV_DDL_RELATION_ACTIVITY.sql` 신설 · 배포 · SV 게이트 5종 rc=0 · 연·유형 조회 실증(LANG_CD 391종·오염값은 SV 제외).
> - D-4 = DEC-59 #1 ⓑ 확정 · `SV_ML_ONCE_CONVERSION` COMMENT 「요청 중」 stale 정정 → 재배포.
> - ERP 예산단위 질의 = 현행 AGENT_MARKETING 실답변 「예산단위 축 미적재」 · 원인 = SILVER `ERP_BUDGET.BDGT_UNIT_NM`·`DVLP_INBOUND_PATH` 가 GOLD `FACT_BUDGET`·SV_BUDGET 에 미전파 · 🔴 「컬쳐콘텐츠팀」은 ERP 예산단위에 없음(실측 = 콘텐츠기획팀).

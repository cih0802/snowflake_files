# O226 ② campaign_axis_gate GAP 15 → 12 (xh20001 · 2026-10-14)

## 처리 3건

| 컬럼 | 전 | 후 | 근거 |
|---|---|---|---|
| TM_MM_FDRM_MBER_INFO.CMPGN_CD | GAP | WIRED | SV_MEMBER_MONTHLY 에 `first_campaign`(DIM_CAMPAIGN BK 조인) 별칭 테이블 + 차원 4 배포 · BK 유일 · 채움 1,620,086 중 매칭 1,620,082 · 스모크 TOTAL_PAID_ALL 최초캠페인 그룹 합 = 팩트 945,321,724,538 |
| DGT CMPGN_TYPE1_BSN_NM | GAP | EXEMPT | SILVER 232,418행 중 232,415행 `TYPE = TYPE1 || ' ' || TYPE2` · 예외 3행 = TYPE2 NULL(전체사업) ⇒ 결합값이 SV_AD 에 이미 있다 |
| DGT CMPGN_TYPE2_BSN_NM | GAP | EXEMPT | 위와 같음 |

## 남은 12건 분류

| 컬럼 | 분류 | 사유 |
|---|---|---|
| TM_MM_FDRM_MBER_IRSD.CMPGN_CD | 🟠 설계 결정 필요 | 증감액은 FMM 에서 회원×월 롤업(AMT_INCREASE/DECREASE_CUM_CNT · DEC_AMT)이라 캠페인 축을 붙이면 grain 변경 · FME 에 증감 사건 유형 신설이 정공 → 사용자 결정 후 착수 |
| SND_MEMBER_LIST.CURRENT_UPPER_CMPGN | 사유 유지 | 발송 시점 스냅샷 · 수요 미확인 |
| SND_MEMBER_LIST.FIRST_CMPGN | 사유 유지 | 발송 시점 스냅샷 · 회원 현재 최초캠페인은 O226 SV 노출로 대체 |
| SND_MEMBER_LIST.FIRST_UPPER_CMPGN | 사유 유지 | 발송 시점 스냅샷 |
| SND_MEMBER_LIST.LAST_TOP_CMPGN | 사유 유지 | 발송 시점 스냅샷 |
| SND_MEMBER_LIST.LAST_UPPER_CMPGN | 사유 유지 | 발송 시점 스냅샷 |
| VIDEO CMPGN_TY_NM | 사유 유지 | AD_CREATIVE_SK=0(소재 부분키 매칭 설계 대기) |
| VIDEO UPPER_CMPGN_NM | 👤 현업 | 문서20 N-29 ⑥(코드·이름 혼재) |
| TM_CM_CMPGN_MNG.CMPGN_PRPT_YN | 👤 현업 | 값 의미 미확인 |
| TM_CM_CMPGN_MNG.CMPGN_TRGET_CD | 👤 현업 | 코드군 미확인 |
| TM_CM_CMPGN_MNG.CMPGN_STRT_DE | 후속(소) | GOLD CAMPAIGN_OPEN_DATE 존재 · SV 차원 1줄 추가로 해소 가능 |
| TM_CM_CMPGN_MNG.UPPER_CMPGN_YN | 후속 | GOLD DIM_CAMPAIGN 컬럼 추가 필요(build) |

_Co-authored with CoCo_

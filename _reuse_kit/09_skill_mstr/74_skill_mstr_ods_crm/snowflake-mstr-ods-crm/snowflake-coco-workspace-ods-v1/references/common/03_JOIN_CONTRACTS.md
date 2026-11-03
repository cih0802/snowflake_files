# MSTR_ODS CRM JOIN 계약

## 공통 원칙

- 같은 이름의 컬럼은 JOIN 근거가 아니다.
- 표에 기재된 전체 복합키를 사용한다.
- `CONFIRMED_SOURCE_STRUCTURE`는 Snowflake 타입·NULL·중복·미매칭 검증 후 운영에 사용한다.
- JOIN 전에 양쪽 원천을 각자의 네이티브 Grain으로 필터·중복 제거한다.

## 통합 발송

| 기준 데이터 | 연결 데이터 | 전체 연결 기준 | 관계 | 상태 |
|---|---|---|---|---|
| `SND_REQ_MST` | `SND_MEMBER_LIST` | `SEQ_NO = REQ_SEQ_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| `SND_MEMBER_LIST` | `SND_MEMBER_OPEN_LOG` | 우선 `REQ_SEQ_NO + R_NUM` | 1:N 이벤트 | `R_NUM 타입 확인, Grain 검증 필요` |
| `SND_MEMBER_LIST` | `SND_MEMBER_MAIL_LINK_LOG` | 우선 `REQ_SEQ_NO + R_NUM` | 1:N 이벤트 | `R_NUM 타입 확인, Grain 검증 필요` |

오픈 로그와 클릭 로그는 각각 수신자 키로 먼저 집계한 다음 수신자 목록에 연결한다.

## 회원·후원

| 기준 데이터 | 연결 데이터 | 전체 연결 기준 | 관계 | 상태 |
|---|---|---|---|---|
| 정기회원 | 후원 마스터 | `MBER_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 후원 마스터 | 후원사업 상세 | `SPNSR_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 후원사업 상세 | 회원개발 발생금액 | `SPNSR_NO + SPNSR_BSNS_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 후원사업 상세 | 결연개발 발생금액 | `SPNSR_NO + SPNSR_BSNS_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 후원사업 상세 | 후원사업 코드 | `SPNSR_BSNS_ID` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 회원 | 후원 중단 이벤트 | `MBER_NO` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |

## 납입·관계

| 기준 데이터 | 연결 데이터 | 전체 연결 기준 | 관계 | 상태 |
|---|---|---|---|---|
| 회비 납입실적 | 정기회원 | `MBER_NO` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 회비 납입실적 | 후원사업 상세 | `SPNSR_NO + SPNSR_BSNS_NO` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 회비 납입실적 | 결제정보 | `SETLE_KEY` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 결연 마스터 | 정기회원 | `MBER_NO` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 결연 마스터 | 후원사업 상세 | `SPNSR_NO + SPNSR_BSNS_NO` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 결연 마스터 | 아동 마스터 | `CHILD_CD` | N:1 | `CONFIRMED_SOURCE_STRUCTURE` |
| 결연 마스터 | 선물금 | `RELATNSP_KEY` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 결연 마스터 | 서신 | `RELATNSP_KEY` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |

## 캠페인·코드·이벤트

| 기준 데이터 | 연결 데이터 | 전체 연결 기준 | 관계 | 상태 |
|---|---|---|---|---|
| 공통코드 헤더 | 공통코드 상세 | `CD_ID` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 브랜드 | 캠페인 | `BRND_ID` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 캠페인 마스터 | 캠페인 참여자 | `CRMN_CD` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |
| 이벤트 마스터 | 이벤트 참여 상세 | `EVENT_CD` | 1:N | `CONFIRMED_SOURCE_STRUCTURE` |

## 필수 JOIN 프로파일

운영 적용 전 다음 값을 남긴다.

- 좌·우 전체 행 수
- 좌·우 키 NULL 수
- 전체키 고유 수
- 중복키 수와 최대 중복도
- 미매칭 행·키 수
- JOIN 후 행 수와 증폭률
- JOIN 전후 고유 업무키 수

예상 관계와 실제 관계가 다르면 해당 JOIN을 승인하지 않는다.


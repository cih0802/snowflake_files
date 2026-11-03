# 회원개발 통합 리포트 — Snowflake Streamlit

월간 회원개발 실적을 보고하기 위한 정기 리포트 대시보드.

## 파일 구조

```
Untitled 7/
├── streamlit_app.py        # 메인 앱 (단일 파일 버전)
├── snowflake.yml           # Snowflake 배포 설정
├── pyproject.toml          # Python 의존성
└── .streamlit/config.toml  # Streamlit 설정
```

## 실행 방법

### DEMO MODE (기본)

1. Snowflake Workspace에서 이 프로젝트를 엽니다
2. `streamlit_app.py` 파일을 확인합니다
3. `APP_CONFIG["demo_mode"]`가 `True`인지 확인합니다
4. **Run** 버튼을 클릭합니다
5. 샘플 데이터로 전체 UI가 실행됩니다

### 운영 모드 전환

1. `APP_CONFIG["demo_mode"]`를 `False`로 변경
2. `APP_CONFIG["snowflake"]`에서 database, schema, view 이름을 실제 값으로 변경
3. `APP_CONFIG["columns"]`에서 논리 컬럼명과 실제 컬럼명 매핑 확인
4. **Run** 클릭

## APP_CONFIG 설정

### Snowflake 객체 연결

```python
"snowflake": {
    "database": "YOUR_DATABASE",
    "schema": "YOUR_SCHEMA",
    "views": {
        "performance": "V_MEMBER_DEV_MONTHLY",
        "sponsorship": "V_MEMBER_DEV_SPONSORSHIP",
    },
},
```

### 컬럼 매핑

`columns` 딕셔너리에서 논리 컬럼명(키)과 실제 Snowflake 컬럼명(값)을 매핑합니다.
View의 컬럼명이 다른 경우 이 매핑만 변경하면 됩니다.

## 예상 데이터 모델

### 월별 조직 실적 View (V_MEMBER_DEV_MONTHLY)

| 논리 컬럼 | 데이터형 | 설명 | 필수 |
|-----------|---------|------|------|
| REPORT_YEAR | NUMBER | 기준연도 | Y |
| REPORT_MONTH_NO | NUMBER | 기준월 (1~12) | Y |
| ORG_L1 | VARCHAR | 상위 조직 | Y |
| ORG_L2 | VARCHAR | 하위 조직/팀 | Y |
| PERFORMANCE_TYPE | VARCHAR | 실적 유형 (디지털, 방송 등) | Y |
| MONTH_TARGET | NUMBER | 당월 목표 | Y |
| MONTH_ACTUAL | NUMBER(10,1) | 당월 실적 | Y |
| ANNUAL_TARGET | NUMBER | 연간 목표 | Y |
| SORT_ORDER | NUMBER | 표시 정렬 순서 | Y |
| ROW_TYPE | VARCHAR | 행 유형 (detail/subtotal/hq_subtotal/grand_total) | Y |

### 후원사업별 View (V_MEMBER_DEV_SPONSORSHIP)

| 논리 컬럼 | 데이터형 | 설명 | 필수 |
|-----------|---------|------|------|
| ORG_L2 | VARCHAR | 팀명 | Y |
| SPONSORSHIP_TYPE | VARCHAR | 사업유형 (국내/결연/해외/기타) | Y |
| LEGAL_ENTITY_TYPE | VARCHAR | 법인구분 (사단/사복) | Y |
| ANNUAL_TARGET | NUMBER | 연간 목표 | Y |
| MONTH_ACTUAL | NUMBER(10,1) | 월별 실적 | Y |
| REPORT_YEAR | NUMBER | 기준연도 | Y |
| REPORT_MONTH_NO | NUMBER | 기준월 | Y |

## $snowflake-mstr-dw-to-ods 스킬

### 역할
실제 Snowflake 객체 탐색, 컬럼 확인, 집계 기준 확인, 수치 검증에 사용.

### 현재 상태
- **스킬 사용 가능**: 아니오
- **실제 데이터 검증**: 미완료
- **검증 사유**: 현재 환경에 스킬 미설치

### 후속 작업
스킬이 설치된 환경에서 다음을 확인해야 합니다:
1. 실제 Table/View 존재 여부
2. 컬럼명과 데이터형
3. 2026년 9월 기준 대표 수치 비교
4. 집계 기준 (마감/가마감, 취소 반영 등)

## Navigation 구현

### 구현 방식
- **st.sidebar**: 고정 Navigation으로 사용 (Streamlit 기본 제공)
- **Anchor ID**: 각 Section에 HTML `<div id="...">` 설정
- **Anchor Link**: sidebar에 `<a href="#...">` 배치

### Scroll Spy
Snowflake Streamlit 환경에서 JavaScript Scroll Spy는 안정적으로 작동하지 않습니다.
대체 구현: 사용자가 클릭한 마지막 메뉴를 `st.session_state`로 강조 표시.

### Sticky Navigation
st.sidebar는 Streamlit에서 기본적으로 화면 왼쪽에 고정됩니다.
별도 CSS sticky 처리 없이 동일한 효과를 제공합니다.

## Demo 데이터 vs 실제 데이터

| 항목 | Demo | 운영 |
|------|------|------|
| 데이터 출처 | Python DataFrame 생성 | Snowflake View 조회 |
| Snowflake 접속 | 없음 | st.connection("snowflake") |
| 수치 정확도 | 이미지 참고 근사값 | 실제 마감 데이터 |
| 조직 구조 | 하드코딩된 샘플 | View에서 동적 조회 |

## 이미지 대표 수치 (2026년 9월)

| 지표 | 이미지 값 | 검증 상태 |
|------|----------|----------|
| 당월 전체 실적 | 26,455.7건 | 미검증 |
| 당월 목표 | 25,813건 | 미검증 |
| 당월 목표 달성률 | 102.5% | 미검증 |
| 누계 전체 실적 | 249,973.8건 | 미검증 |
| 연간 목표 | 348,000건 | 미검증 |
| 연간 목표 달성률 | 71.8% | 미검증 |

## Snowflake 권한

- View에 대한 SELECT 권한
- Warehouse 사용 권한 (GN_DW_ANALYTICS_WH)

## 테스트 체크리스트

### Demo Mode
- [ ] DEMO_MODE=True에서 Snowflake 없이 실행
- [ ] 조회 연월 필터 표시 및 변경
- [ ] KPI 4개 정상 표시
- [ ] 조직별 성과 요약 + Bar Chart
- [ ] 핵심 포인트 3개 영역
- [ ] 월 마감 상세표 (다단 헤더, 계층)
- [ ] 전년도 실적 비교표
- [ ] 4개년 Line Chart + 테이블
- [ ] 미래 월 null 처리 (0 아님)
- [ ] 후원사업별 누계표
- [ ] Navigation 메뉴 클릭 → Section 이동

### 운영 Mode
- [ ] DEMO_MODE=False → st.connection 생성
- [ ] CONFIG의 View 조회
- [ ] 필수 컬럼 존재 확인
- [ ] 선택 연월에 따른 데이터 변경
- [ ] 목표 0일 때 달성률 "-"
- [ ] 스킬 검증 결과와 일치

## 오류 발생 시

1. **Snowflake View 없음**: DEMO_MODE=True로 전환하여 UI 확인
2. **컬럼 누락**: APP_CONFIG["columns"] 매핑 확인
3. **패키지 오류**: pyproject.toml에 streamlit[snowflake] 확인
4. **빈 데이터**: 선택 연월에 해당하는 데이터 존재 여부 확인

## 새 조직/실적 항목 추가

- 운영 모드: View에 새 행이 추가되면 자동 반영 (SORT_ORDER로 순서 관리)
- Demo 모드: `_build_detail_rows()` 함수에 행 추가

## 알려진 제약

1. Scroll Spy 미구현 (Snowflake Streamlit JS 제약)
2. 외부 폰트(Noto Sans KR) 로딩은 네트워크 정책에 따라 실패 가능 → sans-serif fallback
3. 실제 Snowflake 데이터 미검증 상태
4. 후원사업별 View의 법인별 분리 집계는 View 구조에 따라 조정 필요

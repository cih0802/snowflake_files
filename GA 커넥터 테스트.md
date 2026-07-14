# Google Analytics → Snowflake 직접 연동 가이드

## 1. 배경

Google Analytics(GA4) 데이터를 BigQuery로 내보낸 후 다운로드하여 Snowflake에 적재하는 기존 방식 대신,
Snowflake Marketplace 커넥터를 사용하면 GA4에서 Snowflake로 직접 데이터를 가져올 수 있다.

---

## 2. 사용 가능한 커넥터

| 커넥터 | 제공사 | 데이터 유형 | URL |
|--------|--------|------------|-----|
| Connector for GA Raw Data | Snowflake (공식) | 이벤트 수준 원시 데이터 | https://app.snowflake.com/marketplace/listing/GZSTZTP0KKC |
| Connector for GA Aggregate Data | Snowflake (공식) | 집계 메트릭 (Users, Bounce Rate 등) | https://app.snowflake.com/marketplace/listing/GZSTZTP0KKG |
| GA4 Connector | Windsor.ai | 이벤트/세션/유저/이커머스 (flat 테이블) | https://app.snowflake.com/marketplace/listing/GZ2FVZ47RY6 |
| GA4 Connector | Dataslayer | GA4 메트릭/디멘션 자동 동기화 | https://app.snowflake.com/marketplace/listing/GZTWZFTONP |

---

## 3. 비용 비교 (100 테이블, 10,000 rows 기준)

### Case 1: BigQuery 경유 + 유지보수 업체

| 항목 | 예상 비용 (월) |
|------|---------------|
| BigQuery 스토리지/쿼리 | ~$0 (무료 티어 내) |
| Snowflake 스토리지 | ~$0.5~1 |
| Snowflake 데이터 로드 (warehouse) | ~$2~5 |
| 유지보수 업체 비용 | $500~3,000+ |
| **합계** | **$500~3,000+/월** |

### Case 2: Snowflake Connector 직접 사용

| 항목 | 예상 비용 (월) |
|------|---------------|
| 커넥터 라이선스 | $0 |
| Snowflake 스토리지 | ~$0.5~1 |
| Snowflake Warehouse (동기화) | ~$2~10 |
| **합계** | **~$3~11/월** |

### 결론

- 인프라 비용 자체는 양쪽 모두 미미한 수준
- 실질적 차이는 **유지보수 업체 인건비**와 **운영 복잡도**
- Connector 사용 시 중간 단계 제거로 파이프라인 단순화

---

## 4. Trial 계정에서 테스트 가능 여부

- Trial 계정 (30일, $400 크레딧) 에서 **테스트 가능**
- Marketplace Native App 설치 지원됨
- ACCOUNTADMIN 권한 제공됨 (커넥터 설치에 필요)
- 10,000 rows 규모는 크레딧 소모 거의 없음

---

## 5. 커넥터 설정 방법 (Snowflake Connector for GA Raw Data 기준)

### 5.1 사전 준비

- Snowflake 계정 (Trial 가능)
- ACCOUNTADMIN 역할
- GA4 Property에 대한 관리자 권한
- GA4에서 BigQuery Export가 활성화되어 있을 필요 없음 (커넥터가 직접 연결)

### 5.2 설치 단계

#### Step 1: Marketplace에서 커넥터 설치

1. Snowsight 접속
2. 좌측 메뉴 → **Data Products** → **Marketplace** 클릭
3. 검색창에 "Snowflake Connector for Google Analytics Raw Data" 입력
4. 리스팅 클릭 → **Get** 버튼 클릭
5. 설치할 Warehouse 선택 (XS 권장)
6. 설치 완료 대기

#### Step 2: 커넥터 앱 실행 및 설정

1. 좌측 메뉴 → **Data Products** → **Apps** 클릭
2. 설치된 "Google Analytics Raw Data" 앱 선택
3. 앱 내에서 **Connect** 또는 **Configure** 클릭

#### Step 3: Google 계정 OAuth 연결

1. Google 계정 로그인 팝업 표시됨
2. GA4 데이터에 대한 접근 권한 승인
3. 연결할 GA4 Property 선택

#### Step 4: 동기화 설정

1. **데이터 범위 선택**: 히스토리 데이터 백필 기간 설정
2. **새로고침 주기 설정**: 일일 또는 원하는 주기 선택
3. **대상 Database/Schema 지정**: 데이터가 적재될 위치 설정

#### Step 5: 동기화 실행 및 확인

1. 초기 동기화 시작 (히스토리 데이터 포함 시 시간 소요 가능)
2. 동기화 완료 후 데이터 확인:

```sql
-- 동기화된 데이터베이스 확인
SHOW DATABASES LIKE '%GOOGLE%ANALYTICS%';

-- 테이블 목록 확인
SHOW TABLES IN <동기화된_데이터베이스>;

-- 데이터 샘플 조회
SELECT * FROM <동기화된_데이터베이스>.<스키마>.<테이블명> LIMIT 10;
```

### 5.3 동기화 모니터링

- 앱 내 대시보드에서 동기화 상태 확인 가능
- 실패 시 알림 설정 가능
- Warehouse 사용량은 Account > Usage에서 모니터링

---

## 6. 주의사항

- 커넥터 실행 시 Warehouse가 자동 시작되므로, Auto-suspend 설정 권장 (예: 1분)
- GA4 Property가 여러 개인 경우 각각 연결 필요
- 데이터 스키마는 커넥터가 자동 생성 (수동 DDL 불필요)
- Trial 계정 만료 전 필요한 데이터는 별도 백업 권장

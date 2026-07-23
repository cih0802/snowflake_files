# MFA 환경에서 로컬 Python → Snowflake 연결 가이드

MFA(2차 인증)가 활성화된 Snowflake 계정에서 로컬 Python으로 Bronze 레이어에 데이터를 적재하기 위한 인증 방법을 정리합니다.

---

## 1. Key Pair 인증 (권장)

MFA 팝업 없이 자동화에 가장 적합한 방식입니다.

### 설정 순서

```bash
# 1. RSA 키 생성
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

```sql
-- 2. Snowflake에 공개키 등록
ALTER USER TRIALADMIN SET RSA_PUBLIC_KEY='MIIBIjANBgkq...';
```

```python
# 3. Python 연결
from snowflake.connector import connect
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

with open("rsa_key.p8", "rb") as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(), password=None, backend=default_backend()
    )

conn = connect(
    account="ny60473",
    user="TRIALADMIN",
    private_key=private_key,
    warehouse="COMPUTE_WH",
    database="MY_DB",
    schema="BRONZE"
)
```

---

## 2. External Browser 인증 (개발 중 간편)

브라우저로 한 번 인증하면 토큰이 캐시됩니다.

```python
conn = connect(
    account="ny60473",
    user="TRIALADMIN",
    authenticator="externalbrowser",
    warehouse="COMPUTE_WH",
    database="MY_DB",
    schema="BRONZE"
)
```

- 실행 시 브라우저가 열리고, SSO + MFA를 한 번만 수행
- `client_store_temporary_credential=True` 추가하면 토큰 캐시 가능

---

## 3. MFA 토큰 캐싱

비밀번호 인증을 유지하되, MFA 토큰을 캐시합니다.

```python
conn = connect(
    account="ny60473",
    user="TRIALADMIN",
    password="...",
    authenticator="username_password_mfa",
    client_request_mfa_token=True,
    client_store_temporary_credential=True,
)
```

---

## Bronze 적재 예시 (Key Pair 기준)

```python
import pandas as pd
from snowflake.connector.pandas_tools import write_pandas

df = pd.read_csv("source_data.csv")

success, nchunks, nrows, _ = write_pandas(
    conn,
    df,
    table_name="RAW_EVENTS",
    database="MY_DB",
    schema="BRONZE",
    auto_create_table=True
)
print(f"Loaded {nrows} rows in {nchunks} chunks")
```

---

## 방식별 추천 용도

| 용도 | 방식 |
|------|------|
| 스케줄러/자동화 (Airflow 등) | **Key Pair** |
| 로컬 개발/탐색 | **External Browser** |
| CI/CD 파이프라인 | **Key Pair** + Secrets Manager |

---

## 참고사항

- 자동화 파이프라인을 구축할 계획이라면 **Key Pair 인증**이 MFA 프롬프트를 완전히 우회하면서도 보안이 유지되므로 가장 적합
- `rsa_key.p8` 파일은 절대 Git에 커밋하지 말 것 (`.gitignore`에 추가)
- 필요한 패키지: `pip install snowflake-connector-python cryptography pandas`

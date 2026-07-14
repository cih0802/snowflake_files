-- ============================================================
-- SharePoint 파일 데이터 가져오기 - 단계별 가이드
-- ============================================================
-- 사전 준비 (Azure Portal)
-- 1. Azure AD → App Registration 생성
-- 2. Client ID, Tenant ID, Client Secret 발급
-- 3. SharePoint API 권한 부여: Sites.Read.All (또는 Files.Read.All)
-- 4. 관리자 동의(Admin Consent) 완료
-- ============================================================


-- ============================================================
-- STEP 1: Network Rule 생성
--   - Microsoft Graph API 및 Azure AD 토큰 엔드포인트 허용
-- ============================================================
USE ROLE SYSADMIN;

CREATE OR REPLACE NETWORK RULE sharepoint_network_rule
  MODE       = EGRESS
  TYPE       = HOST_PORT
  VALUE_LIST = (
    'graph.microsoft.com',           -- Microsoft Graph API (SharePoint 파일 접근)
    'login.microsoftonline.com'      -- Azure AD OAuth2 토큰 발급
  )
  COMMENT = 'SharePoint Graph API 및 Azure AD 인증 엔드포인트';


-- ============================================================
-- STEP 2: Secret 생성 (Azure AD 앱 자격증명 저장)
--   - TYPE = PASSWORD 로 Client ID / Client Secret 분리 저장
--   - Snowflake가 평문 노출 없이 안전하게 관리
-- ============================================================
USE ROLE ACCOUNTADMIN;  -- CREATE SECRET 권한 필요

CREATE OR REPLACE SECRET sharepoint_azure_cred
  TYPE     = PASSWORD
  USERNAME = '<YOUR_AZURE_CLIENT_ID>'       -- Azure App Registration Client ID
  PASSWORD = '<YOUR_AZURE_CLIENT_SECRET>'  -- Azure App Registration Client Secret
  COMMENT  = 'SharePoint 접근을 위한 Azure AD 앱 자격증명';


-- ============================================================
-- STEP 3: External Access Integration 생성
--   - Network Rule + Secret 을 하나의 Integration 으로 묶음
--   - ACCOUNTADMIN 또는 CREATE INTEGRATION 권한 필요
-- ============================================================
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION sharepoint_access_integration
  ALLOWED_NETWORK_RULES         = (sharepoint_network_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (sharepoint_azure_cred)
  ENABLED = TRUE
  COMMENT = 'SharePoint 파일 데이터 접근용 External Access Integration';


-- ============================================================
-- STEP 4: 권한 부여 (개발자 Role에 USAGE 허용)
-- ============================================================
GRANT USAGE ON INTEGRATION sharepoint_access_integration TO ROLE SYSADMIN;
GRANT READ  ON SECRET sharepoint_azure_cred              TO ROLE SYSADMIN;


-- ============================================================
-- STEP 5: Python UDF 생성 - SharePoint 파일 목록 조회
--   Graph API: GET /sites/{site-id}/drives/{drive-id}/root/children
-- ============================================================
USE ROLE SYSADMIN;

CREATE OR REPLACE FUNCTION get_sharepoint_files(
  tenant_id  STRING,   -- Azure AD Tenant ID (e.g. 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
  site_id    STRING,   -- SharePoint Site ID
  drive_id   STRING    -- SharePoint Drive ID (Document Library ID)
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'get_files'
EXTERNAL_ACCESS_INTEGRATIONS = (sharepoint_access_integration)
PACKAGES = ('snowflake-snowpark-python', 'requests')
SECRETS = ('cred' = sharepoint_azure_cred)
AS
$$
import _snowflake
import requests

def get_access_token(tenant_id, client_id, client_secret):
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    payload = {
        "grant_type":    "client_credentials",
        "client_id":     client_id,
        "client_secret": client_secret,
        "scope":         "https://graph.microsoft.com/.default"
    }
    response = requests.post(token_url, data=payload)
    response.raise_for_status()
    return response.json()["access_token"]

def get_files(tenant_id, site_id, drive_id):
    cred         = _snowflake.get_username_password('cred')
    client_id    = cred.username
    client_secret = cred.password

    access_token = get_access_token(tenant_id, client_id, client_secret)

    url     = f"https://graph.microsoft.com/v1.0/sites/{site_id}/drives/{drive_id}/root/children"
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()
$$;


-- ============================================================
-- STEP 6: Python UDF 생성 - SharePoint 파일 콘텐츠 다운로드
--   Graph API: GET /sites/{site-id}/drives/{drive-id}/items/{item-id}/content
-- ============================================================
CREATE OR REPLACE FUNCTION get_sharepoint_file_content(
  tenant_id STRING,
  site_id   STRING,
  drive_id  STRING,
  item_id   STRING   -- 파일의 Graph API Item ID
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'get_content'
EXTERNAL_ACCESS_INTEGRATIONS = (sharepoint_access_integration)
PACKAGES = ('snowflake-snowpark-python', 'requests')
SECRETS = ('cred' = sharepoint_azure_cred)
AS
$$
import _snowflake
import requests

def get_access_token(tenant_id, client_id, client_secret):
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    payload = {
        "grant_type":    "client_credentials",
        "client_id":     client_id,
        "client_secret": client_secret,
        "scope":         "https://graph.microsoft.com/.default"
    }
    response = requests.post(token_url, data=payload)
    response.raise_for_status()
    return response.json()["access_token"]

def get_content(tenant_id, site_id, drive_id, item_id):
    cred          = _snowflake.get_username_password('cred')
    client_id     = cred.username
    client_secret = cred.password

    access_token = get_access_token(tenant_id, client_id, client_secret)

    url     = f"https://graph.microsoft.com/v1.0/sites/{site_id}/drives/{drive_id}/items/{item_id}/content"
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(url, headers=headers, allow_redirects=True)
    response.raise_for_status()
    return response.text
$$;


-- ============================================================
-- STEP 7: UDF 호출 예시
-- ============================================================

-- 7-1. SharePoint 드라이브 파일 목록 조회
SELECT get_sharepoint_files(
  '<YOUR_TENANT_ID>',   -- Azure Tenant ID
  '<YOUR_SITE_ID>',     -- SharePoint Site ID
  '<YOUR_DRIVE_ID>'     -- Drive (Document Library) ID
) AS file_list;

-- 7-2. 파일 목록에서 이름/ID 파싱
SELECT
  f.value:name::STRING    AS file_name,
  f.value:id::STRING      AS item_id,
  f.value:size::NUMBER    AS file_size_bytes,
  f.value:lastModifiedDateTime::TIMESTAMP AS last_modified
FROM TABLE(FLATTEN(
  input => get_sharepoint_files(
    '<YOUR_TENANT_ID>',
    '<YOUR_SITE_ID>',
    '<YOUR_DRIVE_ID>'
  ):value
)) f;

-- 7-3. 특정 파일 콘텐츠 가져오기 (텍스트 파일, CSV 등)
SELECT get_sharepoint_file_content(
  '<YOUR_TENANT_ID>',
  '<YOUR_SITE_ID>',
  '<YOUR_DRIVE_ID>',
  '<YOUR_ITEM_ID>'    -- 7-2 결과의 item_id 사용
) AS file_content;


-- ============================================================
-- 참고: Site ID / Drive ID 조회 방법
-- ============================================================
-- SharePoint 사이트 URL 예: https://<tenant>.sharepoint.com/sites/<site-name>
-- Graph API로 Site ID 확인:
--   GET https://graph.microsoft.com/v1.0/sites/<tenant>.sharepoint.com:/sites/<site-name>
-- Graph API로 Drive ID 확인:
--   GET https://graph.microsoft.com/v1.0/sites/<site-id>/drives
-- ============================================================

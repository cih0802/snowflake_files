# Bronze DDL 컬럼 코멘트 자동 주입 스크립트 (컬럼정의서 CSV + GA4 스키마 문서 기반)
# Co-authored with CoCo
import csv, re, sys, collections

BASE = "/workspace"
DDL = f"{BASE}/데이터마이그레이션 GN_DW_BRONZE_DDL_20260713.sql"
CSVF = f"{BASE}/컬럼정의서 20260714.csv"

# 1) CSV -> (table, col)->desc  및  col->최빈 desc(폴백)
pair = {}
byname = collections.defaultdict(collections.Counter)
with open(CSVF, encoding="utf-8-sig", newline="") as f:
    for row in csv.DictReader(f):
        t = (row["테이블명"] or "").strip()
        c = (row["컬럼명"] or "").strip()
        d = (row["컬럼설명(한글)"] or "").strip()
        if not c or not d:
            continue
        if t:
            pair[(t.upper(), c.upper())] = d
        byname[c.upper()][d] += 1

fallback = {c: cnt.most_common(1)[0][0] for c, cnt in byname.items()}

# 메타/공통 컬럼 기본 코멘트
meta = {
    "_LOAD_DT": "적재일시 (ETL 적재 시각)",
    "_BATCH_ID": "배치ID (적재 배치 식별자)",
    "FRST_RGSTR_ID": "최초등록자ID",
    "FRST_REGIST_DT": "최초등록일시",
    "LAST_UPDUSR_ID": "최종수정자ID",
    "LAST_UPDT_DT": "최종수정일시",
}

# 2) GA4 최상위 컬럼 코멘트 (14_bronze_ga4_events_schema.md 기반)
ga4 = {
    "event_date": "이벤트가 기록된 날짜(YYYYMMDD, 속성 시간대 기준)",
    "event_timestamp": "GA4 서버가 이벤트를 수신한 시각(UTC 마이크로초)",
    "event_name": "이벤트 이름(자동수집/커스텀 이벤트명)",
    "event_params": "이벤트 파라미터 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)",
    "event_previous_timestamp": "동일 기기 직전 이벤트 수신 시각(UTC 마이크로초)",
    "event_value_in_usd": "이벤트 value 파라미터의 USD 환산값",
    "event_bundle_sequence_id": "기기→서버 전송 배치(bundle) 요청 순번 ID",
    "event_server_timestamp_offset": "기기 수집 시각과 서버 업로드 시각의 차이(마이크로초)",
    "user_id": "개발자가 설정한 사용자 고유 ID(로그인 사용자, CRM 연계 키)",
    "user_pseudo_id": "GA4 자동 생성 익명 사용자 식별자",
    "privacy_info": "동의모드 데이터 저장 동의 정보(RECORD → OBJECT)",
    "user_properties": "사용자 속성 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)",
    "user_first_touch_timestamp": "사용자 최초 앱실행/웹방문 시각(UTC 마이크로초)",
    "user_ltv": "사용자 생애가치(LTV) 정보(RECORD → OBJECT)",
    "device": "기기 정보(RECORD → OBJECT)",
    "geo": "지리 정보(IP 기반, RECORD → OBJECT)",
    "app_info": "앱 정보(RECORD → OBJECT)",
    "traffic_source": "최초 유입 트래픽 소스(First-touch, User-scoped, RECORD → OBJECT)",
    "stream_id": "이벤트가 수집된 GA4 데이터 스트림 고유 ID",
    "platform": "이벤트 발생 플랫폼(WEB/ANDROID/IOS)",
    "event_dimensions": "이벤트 차원 정보(hostname 등, RECORD → OBJECT)",
    "ecommerce": "전자상거래 정보(RECORD → OBJECT)",
    "items": "상품 배열(REPEATED RECORD → ARRAY, FLATTEN 대상)",
    "collected_traffic_source": "이벤트 시점 원시 UTM 트래픽 소스(Event-scoped, RECORD → OBJECT)",
    "is_active_user": "해당 날짜 사용자 활성 여부(True=활성)",
    "batch_event_index": "동일 배치 내 이벤트 발생 순번",
    "batch_page_id": "세션 내 페이지뷰 순번",
    "batch_ordering_id": "페이지 내 네트워크 요청 단조 증가 순번",
    "session_traffic_source_last_click": "세션 마지막 클릭 트래픽 소스(Session-scoped, GA4 UI 일치, RECORD → OBJECT)",
    "publisher": "퍼블리셔 광고 수익 정보(RECORD → OBJECT)",
}

def esc(s):
    return s.replace("'", "''")

lines = open(DDL, encoding="utf-8").read().split("\n")
out = []
cur_table = None      # 현재 테이블 short name (upper)
cur_schema = None
col_re = re.compile(r'^(\s+)("?)([A-Za-z_][A-Za-z0-9_]*)("?)(\s+)(.+?)(,?)\s*$')
tbl_re = re.compile(r'create or replace TABLE\s+([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\.("?[A-Za-z0-9_]+"?)\s*\(', re.I)

added = 0
for ln in lines:
    m = tbl_re.search(ln)
    if m:
        cur_schema = m.group(2).upper()
        cur_table = m.group(3).strip('"').upper()
        out.append(ln)
        continue
    if ln.strip() == ");":
        cur_table = None
        out.append(ln)
        continue
    if cur_table and "COMMENT" not in ln:
        cm = col_re.match(ln)
        if cm:
            indent, q1, col, q2, sp, typ, comma = cm.groups()
            colU = col.upper()
            desc = None
            if cur_schema == "BRONZE_GA4":
                desc = ga4.get(col) or ga4.get(colU)
            else:
                desc = pair.get((cur_table, colU)) or meta.get(colU) or fallback.get(colU)
            if desc:
                ln = f"{indent}{q1}{col}{q2}{sp}{typ} COMMENT '{esc(desc)}'{comma}"
                added += 1
    out.append(ln)

GEN = "scripts/add_column_comments.py"
_prov = f"-- 컬럼 COMMENT 주입기(생성기): {GEN} — 재실행 시 이 스크립트로 갱신"
if not any(_prov in l for l in out[:6]):
    out.insert(0, _prov)
open(DDL, "w", encoding="utf-8").write("\n".join(out))
print(f"[{GEN}] added {added} column comments → {DDL}")

# BRONZE_GA4.events_YYYYMMDD — 테이블 스키마 명세서

> GA4(BigQuery Export) 원본 이벤트 데이터를 Snowflake Bronze 레이어에 적재하기 위한 스키마 정의 문서.
> 이 문서는 LLM이 스키마 구조·중첩 관계·적재 규칙을 정확히 이해하고 Silver 변환 SQL을 생성할 수 있도록 작성됨.

---

## 1. 테이블 개요 (Table Metadata)

| 항목 | 내용 |
|------|------|
| **소스 테이블** | `todaydata_goodneighbors` 데이터셋 > `events_YYYYMMDD` |
| **Snowflake 적재 위치** | `GN_DW.BRONZE_GA4.events_YYYYMMDD` |
| **테이블 구조** | 일자별 date-sharded 테이블 (하루 1개 테이블). `_TABLE_SUFFIX` 필터로 날짜 범위 쿼리. |
| **데이터 지연 (Latency)** | daily 테이블은 이벤트 발생 후 **최대 72시간**까지 업데이트됨. 72시간 이후 도착한 이벤트는 미수집. |
| **세션 테이블** | GA4는 별도 세션 테이블 없음 (아래 §3 세션 식별자 참조). |

---

## 2. 핵심 처리 규칙 (Critical Processing Rules)

### 2.1 중첩 구조 (Nested / REPEATED RECORD)
- `event_params`, `user_properties`, `items` 는 **`ARRAY<RECORD>` 형태 (REPEATED RECORD)**.
  - → Silver 변환 시 Snowflake **`LATERAL FLATTEN`** 처리 필요.
- `event_params` 는 **key + value 구조**로, 하나의 파라미터당 `string_value` / `int_value` / `float_value` / `double_value` 중 **단 하나만** 채워짐.
  - `float_value` 는 현재 Google 공식 문서 기준 **미사용**. 소수형 값은 반드시 **`double_value`** 사용.

> **⚠️ 타입 표기 주의 (§3 전체 적용):** 아래 §3 스키마의 `타입` 열은 **GA4(BigQuery) 원본의 리프(leaf) 타입**입니다.
> Snowflake Bronze로 적재할 때 중첩 구조는 스칼라 컬럼이 아니라 반정형(semi-structured) 타입으로 저장됩니다.
> - REPEATED RECORD (`event_params`, `user_properties`, `items`) → Snowflake **`ARRAY`** (요소는 `OBJECT`)
> - RECORD (`device`, `geo`, `app_info`, `ecommerce`, `traffic_source`, `collected_traffic_source`, `session_traffic_source_last_click`, `user_ltv`, `privacy_info`, `device.web_info` 등) → Snowflake **`OBJECT`** (또는 `VARIANT`)
> - 최상위 스칼라 필드(`event_date`, `event_timestamp`, `platform` 등)만 STRING/NUMBER 등 스칼라 타입으로 직접 매핑.
> - 따라서 `CREATE TABLE` DDL 생성 시 중첩 그룹을 개별 스칼라 컬럼으로 펼치지 말 것. 리프 타입은 FLATTEN 후 `::` 캐스팅 대상 타입으로 활용.

### 2.2 트래픽 소스 스코프 (Attribution Scope)
> **⚠️ 원문 표기 검증:** 원본 주석은 "트래픽 소스 스코프 **4종**"으로 라벨링되어 있으나, 실제 열거 항목과 GA4(BigQuery) 스키마상 트래픽 소스 RECORD 필드는 **아래 3개**입니다. (원문 '4종'은 표기 오류로 추정 — 4번째 항목은 임의로 보강하지 않음.)

| # | 필드 | 스코프 | 설명 |
|---|------|--------|------|
| ① | `traffic_source` | First-touch (User-scoped) | 사용자 최초 유입 |
| ② | `collected_traffic_source` | Event-scoped | 이벤트 발생 시점의 raw UTM |
| ③ | `session_traffic_source_last_click` | Session-scoped (Last-click) | 세션 기준 마지막 클릭 → **GA4 UI 리포트와 수치 일치** |

> **권장:** GA4 UI 리포트와 수치를 맞추려면 **③ `session_traffic_source_last_click`** 사용.

### 2.3 CRM 연계 키
- `user_id` 필드에 **CRM 회원번호가 심어져 있는지 반드시 확인** 필요.
  - 미설정 시 → `user_pseudo_id` + `transaction_id` 로 간접 연계 고려.

### 2.4 세션 식별자 (Session Key)
- GA4는 세션 테이블이 별도로 없음.
- **세션 식별 복합키 = `user_pseudo_id` + `event_params['ga_session_id']` (int_value)**

---

## 3. 전체 스키마 (Full Schema)

> 표기 규칙: `중첩 필드`가 비어 있으면 최상위 스칼라 필드. `.`(점)은 RECORD 내부 중첩 경로를 의미.
> `[]` 표기 그룹(`event_params`, `user_properties`, `items`)은 REPEATED RECORD(배열) → FLATTEN 대상.

### 3.1 event — 이벤트 기본 정보
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| event_date | | STRING | NULLABLE | 이벤트가 기록된 날짜. 앱/웹 속성의 등록된 시간대 기준 `YYYYMMDD` 형식 문자열. |
| event_timestamp | | INTEGER | NULLABLE | GA4 서버가 이벤트를 수신한 시각. UTC 기준 마이크로초(μs) 단위 정수. |
| event_name | | STRING | NULLABLE | 이벤트 이름. GA4 자동수집 이벤트 및 커스텀 이벤트 이름. |
| event_params `[]` | key | STRING | NULLABLE | 이벤트 파라미터의 이름(키). GA4 자동수집 파라미터 및 커스텀 파라미터 이름. |
| event_params `[]` | value.string_value | STRING | NULLABLE | 파라미터 값이 문자열인 경우 저장. URL, 페이지명, 캠페인명 등 텍스트 값. |
| event_params `[]` | value.int_value | INTEGER | NULLABLE | 파라미터 값이 정수인 경우 저장. |
| event_params `[]` | value.float_value | FLOAT | NULLABLE | 파라미터 값이 단정밀도 부동소수점인 경우 저장. **(현재 미사용 — double_value 사용)** |
| event_params `[]` | value.double_value | FLOAT | NULLABLE | 파라미터 값이 배정밀도 부동소수점인 경우 저장. 수익·금액 등 소수점 정밀도 필요 값. |
| event_previous_timestamp | | INTEGER | NULLABLE | 동일 기기에서 직전에 발생한 이벤트의 수신 시각. UTC 마이크로초. |
| event_value_in_usd | | FLOAT | NULLABLE | 이벤트의 'value' 파라미터를 USD로 환산한 값. GA4 속성 통화 기준 자동 변환. |
| event_bundle_sequence_id | | INTEGER | NULLABLE | 기기에서 GA4 서버로 전송하는 배치(bundle) 요청의 순번 ID. |
| event_server_timestamp_offset | | INTEGER | NULLABLE | 이벤트가 기기에서 수집된 시각과 GA4 서버에 업로드된 시각의 차이. 마이크로초. |

### 3.2 user — 사용자 식별 / 속성
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| user_id | | STRING | NULLABLE | 개발자가 GA4에 직접 설정한 사용자 고유 ID. 로그인한 사용자에게만 값 존재. **(CRM 연계 키 — §2.3)** |
| user_pseudo_id | | STRING | NULLABLE | GA4가 자동 생성하는 익명 사용자 식별자. 앱 최초 실행 또는 웹사이트 최초 방문 시 부여. |
| privacy_info | analytics_storage | STRING | NULLABLE | Consent Mode 적용 시 애널리틱스 데이터 저장 동의 여부. 값: `Yes` / `No` / `Unset` |
| privacy_info | ads_storage | STRING | NULLABLE | 광고 타겟팅 목적의 데이터 저장 동의 여부. 값: `Yes` / `No` / `Unset` |
| privacy_info | uses_transient_token | STRING | NULLABLE | analytics_storage 거부 + 쿠키 없는 서버측 임시 토큰 측정 활성화 시 `Yes`. 값: `Yes` / `No` / `Unset` |
| user_properties `[]` | key | STRING | NULLABLE | 개발자가 GA4에 설정한 사용자 속성(User Property)의 이름(키). REPEATED RECORD. |
| user_properties `[]` | value.string_value | STRING | NULLABLE | 사용자 속성 값이 문자열인 경우 저장. |
| user_properties `[]` | value.int_value | INTEGER | NULLABLE | 사용자 속성 값이 정수인 경우 저장. |
| user_properties `[]` | value.float_value | FLOAT | NULLABLE | 사용자 속성 값이 단정밀도 부동소수점인 경우 저장. |
| user_properties `[]` | value.double_value | FLOAT | NULLABLE | 사용자 속성 값이 배정밀도 부동소수점인 경우 저장. |
| user_properties `[]` | value.set_timestamp_micros | INTEGER | NULLABLE | 해당 사용자 속성이 마지막으로 설정된 시각. UTC 마이크로초. |
| user_first_touch_timestamp | | INTEGER | NULLABLE | 해당 사용자가 앱을 최초 실행하거나 웹사이트에 최초 방문한 시각. UTC 마이크로초. |

### 3.3 user_ltv — 생애 가치
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| user_ltv | revenue | FLOAT | NULLABLE | GA4가 추적한 해당 사용자의 누적 생애 가치(LTV) 수익. 속성 등록 이후 모든 purchase 이벤트 value 합산. |
| user_ltv | currency | STRING | NULLABLE | user_ltv.revenue의 통화 코드. ISO 4217 형식. |

### 3.4 device — 기기 정보
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| device | category | STRING | NULLABLE | 사용자 기기 카테고리. 값: `mobile` / `desktop` / `tablet` |
| device | mobile_brand_name | STRING | NULLABLE | 모바일 기기 제조사 브랜드명. |
| device | mobile_model_name | STRING | NULLABLE | 모바일 기기 모델명. |
| device | mobile_marketing_name | STRING | NULLABLE | 모바일 기기의 마케팅용 공식 제품명. |
| device | mobile_os_hardware_model | STRING | NULLABLE | 운영체제에서 직접 보고하는 기기 하드웨어 모델 정보. |
| device | operating_system | STRING | NULLABLE | 사용자 기기의 운영체제. |
| device | operating_system_version | STRING | NULLABLE | 운영체제 버전. |
| device | vendor_id | STRING | NULLABLE | iOS 기기의 IDFV(Identifier for Vendor). 앱 사용자에게만 적용. |
| device | advertising_id | STRING | NULLABLE | 모바일 광고 식별자. Android=GAID, iOS=IDFA. |
| device | language | STRING | NULLABLE | 사용자 기기/브라우저의 언어 설정. |
| device | is_limited_ad_tracking | STRING | NULLABLE | 광고 추적 제한(LAT) 활성화 여부. 값: `true` / `false` |
| device | time_zone_offset_seconds | INTEGER | NULLABLE | UTC 대비 사용자 기기의 시간대 오프셋(초 단위). |
| device | browser | STRING | NULLABLE | 웹 방문자의 브라우저 종류. |
| device | browser_version | STRING | NULLABLE | 브라우저 버전. |
| device | web_info | RECORD | NULLABLE | 웹 방문자의 추가 정보를 담는 중첩 레코드. |

### 3.5 geo — 지리 정보 (IP 기반)
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| geo | city | STRING | NULLABLE | 이벤트 발생 시 사용자의 도시. IP 주소 기반 지오코딩. |
| geo | country | STRING | NULLABLE | 이벤트 발생 시 사용자의 국가. IP 기반. |
| geo | continent | STRING | NULLABLE | 사용자의 대륙. |
| geo | region | STRING | NULLABLE | 사용자의 지역(광역시·도 수준). IP 기반 지오코딩. |
| geo | sub_continent | STRING | NULLABLE | 사용자의 세부 대륙 구분. |
| geo | metro | STRING | NULLABLE | 사용자의 대도시권(Metropolitan area). 주로 미국 DMA 기반. |

### 3.6 app_info — 앱 정보
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| app_info | id | STRING | NULLABLE | 앱의 패키지명(Android) 또는 번들 ID(iOS). |
| app_info | version | STRING | NULLABLE | 앱 버전 이름. |
| app_info | install_store | STRING | NULLABLE | 앱이 설치된 스토어. |
| app_info | firebase_app_id | STRING | NULLABLE | Firebase에 등록된 앱의 고유 ID. |
| app_info | install_source | STRING | NULLABLE | 앱 설치 출처(referrer). |

### 3.7 traffic_source — ① First-touch (User-scoped)
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| traffic_source | name | STRING | NULLABLE | 사용자 최초 유입 캠페인명 (First-touch, User-scoped attribution). |
| traffic_source | medium | STRING | NULLABLE | 사용자 최초 유입 매체 (First-touch, User-scoped). |
| traffic_source | source | STRING | NULLABLE | 사용자 최초 유입 소스 (First-touch, User-scoped). |

### 3.8 event_dimensions
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| event_dimensions | hostname | STRING | NULLABLE | 이벤트가 발생한 웹사이트의 호스트명(도메인). |

### 3.9 ecommerce — 전자상거래
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| ecommerce | total_item_quantity | INTEGER | NULLABLE | 해당 전자상거래 이벤트의 총 아이템 수량. items 배열 내 quantity 합산. |
| ecommerce | purchase_revenue_in_usd | FLOAT | NULLABLE | purchase 이벤트의 구매 수익. USD 환산. GA4가 자동 환율 적용. |
| ecommerce | purchase_revenue | FLOAT | NULLABLE | purchase 이벤트의 구매 수익. GA4 속성 설정 현지 통화(KRW) 기준. |
| ecommerce | refund_value_in_usd | FLOAT | NULLABLE | refund 이벤트의 환불 금액 (USD 환산). |
| ecommerce | refund_value | FLOAT | NULLABLE | refund 이벤트의 환불 금액 (현지 통화). |
| ecommerce | shipping_value_in_usd | FLOAT | NULLABLE | 배송비 (USD 환산). |
| ecommerce | shipping_value | FLOAT | NULLABLE | 배송비 (현지 통화). |
| ecommerce | tax_value_in_usd | FLOAT | NULLABLE | 세금 (USD 환산). |
| ecommerce | tax_value | FLOAT | NULLABLE | 세금 (현지 통화). |
| ecommerce | unique_items | INTEGER | NULLABLE | 해당 전자상거래 이벤트에서 고유한 아이템 종류 수. |
| ecommerce | transaction_id | STRING | NULLABLE | purchase 이벤트의 거래 고유 ID. 개발자가 직접 설정. **(CRM 간접 연계 키 — §2.3)** |

### 3.10 items — 상품 (REPEATED RECORD `[]` → FLATTEN 대상)
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| items `[]` | item_id | STRING | NULLABLE | 개별 아이템의 고유 ID. 개발자가 설정. |
| items `[]` | item_name | STRING | NULLABLE | 아이템 이름. |
| items `[]` | item_brand | STRING | NULLABLE | 아이템 브랜드명. |
| items `[]` | item_variant | STRING | NULLABLE | 아이템 변형(옵션). |
| items `[]` | item_category | STRING | NULLABLE | 아이템 1차 카테고리. |
| items `[]` | item_category2 | STRING | NULLABLE | 아이템 2차 카테고리. |
| items `[]` | item_category3 | STRING | NULLABLE | 아이템 3차 카테고리. |
| items `[]` | item_category4 | STRING | NULLABLE | 아이템 4차 카테고리. |
| items `[]` | item_category5 | STRING | NULLABLE | 아이템 5차 카테고리. |
| items `[]` | price_in_usd | FLOAT | NULLABLE | 아이템 단가 (USD 환산). |
| items `[]` | price | FLOAT | NULLABLE | 아이템 단가 (현지 통화, KRW). |
| items `[]` | quantity | INTEGER | NULLABLE | 아이템 수량. |
| items `[]` | item_revenue_in_usd | FLOAT | NULLABLE | 아이템 수익 (price_in_usd × quantity, USD 환산). |
| items `[]` | item_revenue | FLOAT | NULLABLE | 아이템 수익 (price × quantity, 현지 통화). |
| items `[]` | item_refund_in_usd | FLOAT | NULLABLE | 아이템 환불 금액 (USD). |
| items `[]` | item_refund | FLOAT | NULLABLE | 아이템 환불 금액 (현지 통화). |
| items `[]` | coupon | STRING | NULLABLE | 적용된 쿠폰 코드. |
| items `[]` | affiliation | STRING | NULLABLE | 제휴사 또는 판매처 이름. |
| items `[]` | location_id | STRING | NULLABLE | 아이템과 연관된 위치 ID. |
| items `[]` | item_list_id | STRING | NULLABLE | 아이템이 표시된 목록의 ID. |
| items `[]` | item_list_name | STRING | NULLABLE | 아이템이 표시된 목록의 이름. |
| items `[]` | item_list_index | STRING | NULLABLE | 목록 내 아이템의 순서(위치 인덱스). |
| items `[]` | promotion_id | STRING | NULLABLE | 적용된 프로모션 ID. |
| items `[]` | promotion_name | STRING | NULLABLE | 프로모션 이름. |
| items `[]` | creative_name | STRING | NULLABLE | 프로모션 크리에이티브(배너/소재) 이름. |
| items `[]` | creative_slot | STRING | NULLABLE | 프로모션 크리에이티브가 표시된 슬롯 위치. |

### 3.11 collected_traffic_source — ② Event-scoped (raw UTM)
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| collected_traffic_source | manual_campaign_id | STRING | NULLABLE | utm_id 파라미터 값. 이벤트 발생 시점의 원시 캠페인 ID (Event-scoped). |
| collected_traffic_source | manual_campaign_name | STRING | NULLABLE | utm_campaign 파라미터 값. 이벤트 발생 시점의 원시 캠페인명. |
| collected_traffic_source | manual_source | STRING | NULLABLE | utm_source 파라미터 값. 이벤트 발생 시점의 원시 소스. |
| collected_traffic_source | manual_medium | STRING | NULLABLE | utm_medium 파라미터 값. 이벤트 발생 시점의 원시 매체. |
| collected_traffic_source | manual_term | STRING | NULLABLE | utm_term 파라미터 값. 유료 검색 키워드. |
| collected_traffic_source | manual_content | STRING | NULLABLE | utm_content 파라미터 값. 광고 소재 구분자. |
| collected_traffic_source | manual_source_platform | STRING | NULLABLE | utm_source_platform 파라미터 값. 소스 플랫폼 구분. |
| collected_traffic_source | manual_creative_format | STRING | NULLABLE | utm_creative_format 파라미터 값. 광고 소재 형식. |
| collected_traffic_source | manual_marketing_tactic | STRING | NULLABLE | utm_marketing_tactic 파라미터 값. 마케팅 전술 구분. |
| collected_traffic_source | gclid | STRING | NULLABLE | Google Click ID. Google Ads 클릭 시 자동 태깅되는 고유 클릭 식별자. |
| collected_traffic_source | dclid | STRING | NULLABLE | Display Click ID. Google DV360 클릭 시 자동 생성 식별자. |
| collected_traffic_source | srsltid | STRING | NULLABLE | Google 쇼핑 검색 결과 클릭 식별자(Search Result Slot ID). |

### 3.12 (최상위) 플래그 / 순번 필드
> 원본 CSV의 `그룹` 열이 비어 있는 **최상위 스칼라 필드**입니다 (특정 RECORD 그룹에 속하지 않음).
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| is_active_user | | BOOLEAN | NULLABLE | 해당 달력 날짜(event_date)에 사용자가 활성 상태였는지 여부. True=활성 / False=비활성. |
| batch_event_index | | INTEGER | NULLABLE | 동일 배치 요청 내에서 이벤트 발생 순서를 나타내는 순번. 2024년 7월 추가된 필드. |
| batch_page_id | | INTEGER | NULLABLE | 세션 내 페이지 뷰 순서를 나타내는 순번. 페이지 이동 시마다 증가. 2024년 7월 추가. |
| batch_ordering_id | | INTEGER | NULLABLE | 특정 페이지에서 네트워크 요청이 전송될 때마다 단조 증가하는 순번. 2024년 7월 추가. |

### 3.13 session_traffic_source_last_click — ③ Session-scoped (Last-click) ★ GA4 UI 일치 권장
> 세션 기준 마지막 클릭 attribution. **GA4 UI 리포트와 수치를 맞추려면 이 그룹 사용 권장.**

#### manual_campaign — 수동 UTM 캠페인
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| manual_campaign.campaign_id | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_id. Session-scoped Last-click attribution 적용. |
| manual_campaign.campaign_name | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_campaign. |
| manual_campaign.source | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_source. |
| manual_campaign.medium | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_medium. |
| manual_campaign.term | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_term. |
| manual_campaign.content | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_content. |
| manual_campaign.source_platform | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_source_platform. |
| manual_campaign.creative_format | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_creative_format. |
| manual_campaign.marketing_tactic | STRING | NULLABLE | 세션 기준 마지막 클릭의 utm_marketing_tactic. |

#### google_ads_campaign — Google Ads
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| google_ads_campaign.customer_id | STRING | NULLABLE | Google Ads 고객(계정) ID. Google Ads 클릭으로 유입된 세션에만 값 존재. |
| google_ads_campaign.account_name | STRING | NULLABLE | Google Ads 계정명. |
| google_ads_campaign.campaign_id | STRING | NULLABLE | Google Ads 캠페인 ID. Ads 자동 태깅(gclid) 기반으로 GA4에서 수집. |
| google_ads_campaign.campaign_name | STRING | NULLABLE | Google Ads 캠페인명. |
| google_ads_campaign.ad_group_id | STRING | NULLABLE | Google Ads 광고 그룹 ID. |
| google_ads_campaign.ad_group_name | STRING | NULLABLE | Google Ads 광고 그룹명. |

#### cross_channel_campaign — 크로스채널 attribution
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| cross_channel_campaign.campaign_id | STRING | NULLABLE | GA4 크로스채널 attribution 모델 기준의 캠페인 ID. |
| cross_channel_campaign.campaign_name | STRING | NULLABLE | 크로스채널 attribution 기준의 캠페인명. |
| cross_channel_campaign.source | STRING | NULLABLE | 크로스채널 attribution 기준의 소스. |
| cross_channel_campaign.medium | STRING | NULLABLE | 크로스채널 attribution 기준의 매체. |
| cross_channel_campaign.source_platform | STRING | NULLABLE | 크로스채널 attribution 기준의 소스 플랫폼. |
| cross_channel_campaign.default_channel_group | STRING | NULLABLE | GA4 기본 채널 그룹 분류. source/medium 규칙에 따라 자동 분류하는 채널. |
| cross_channel_campaign.primary_channel_group | STRING | NULLABLE | GA4 주요 채널 그룹. default_channel_group의 상위 분류. |

#### sa360_campaign — Search Ads 360
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| sa360_campaign.campaign_id | STRING | NULLABLE | SA360 캠페인 ID. SA360 연동 시에만 값 존재. |
| sa360_campaign.campaign_name | STRING | NULLABLE | SA360 캠페인명. |
| sa360_campaign.source | STRING | NULLABLE | SA360 소스. |
| sa360_campaign.medium | STRING | NULLABLE | SA360 매체. |
| sa360_campaign.ad_group_id | STRING | NULLABLE | SA360 광고 그룹 ID. |
| sa360_campaign.ad_group_name | STRING | NULLABLE | SA360 광고 그룹명. |
| sa360_campaign.engine_account_name | STRING | NULLABLE | SA360 엔진 계정명. |
| sa360_campaign.engine_account_type | STRING | NULLABLE | SA360 엔진 계정 유형. |
| sa360_campaign.manager_account_name | STRING | NULLABLE | SA360 관리자 계정명. |

#### cm360_campaign — Campaign Manager 360
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| cm360_campaign.campaign_id | STRING | NULLABLE | CM360 캠페인 ID. CM360 연동 시에만 값 존재. |
| cm360_campaign.campaign_name | STRING | NULLABLE | CM360 캠페인명. |
| cm360_campaign.source | STRING | NULLABLE | CM360 소스. |
| cm360_campaign.medium | STRING | NULLABLE | CM360 매체. |
| cm360_campaign.account_id | STRING | NULLABLE | CM360 계정 ID. |
| cm360_campaign.account_name | STRING | NULLABLE | CM360 계정명. |
| cm360_campaign.advertiser_id | STRING | NULLABLE | CM360 광고주 ID. |
| cm360_campaign.advertiser_name | STRING | NULLABLE | CM360 광고주명. |
| cm360_campaign.creative_id | STRING | NULLABLE | CM360 크리에이티브 ID. |
| cm360_campaign.creative_format | STRING | NULLABLE | CM360 크리에이티브 형식. |
| cm360_campaign.creative_name | STRING | NULLABLE | CM360 크리에이티브명. |
| cm360_campaign.creative_type | STRING | NULLABLE | CM360 크리에이티브 유형. |
| cm360_campaign.creative_type_id | STRING | NULLABLE | CM360 크리에이티브 유형 ID. |
| cm360_campaign.creative_version | STRING | NULLABLE | CM360 크리에이티브 버전. |
| cm360_campaign.placement_id | STRING | NULLABLE | CM360 게재위치 ID. |
| cm360_campaign.placement_cost_structure | STRING | NULLABLE | CM360 게재위치 비용 구조. |
| cm360_campaign.placement_name | STRING | NULLABLE | CM360 게재위치명. |
| cm360_campaign.rendering_id | STRING | NULLABLE | CM360 렌더링 ID. |
| cm360_campaign.site_id | STRING | NULLABLE | CM360 사이트 ID. |
| cm360_campaign.site_name | STRING | NULLABLE | CM360 사이트명. |

#### dv360_campaign — Display & Video 360
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| dv360_campaign.campaign_id | STRING | NULLABLE | DV360 캠페인 ID. DV360 연동 시에만 값 존재. |
| dv360_campaign.campaign_name | STRING | NULLABLE | DV360 캠페인명. |
| dv360_campaign.source | STRING | NULLABLE | DV360 소스. |
| dv360_campaign.medium | STRING | NULLABLE | DV360 매체. |
| dv360_campaign.advertiser_id | STRING | NULLABLE | DV360 광고주 ID. |
| dv360_campaign.advertiser_name | STRING | NULLABLE | DV360 광고주명. |
| dv360_campaign.creative_id | STRING | NULLABLE | DV360 크리에이티브 ID. |
| dv360_campaign.creative_format | STRING | NULLABLE | DV360 크리에이티브 형식. |
| dv360_campaign.creative_name | STRING | NULLABLE | DV360 크리에이티브명. |
| dv360_campaign.exchange_id | STRING | NULLABLE | DV360 광고 거래소 ID. |
| dv360_campaign.exchange_name | STRING | NULLABLE | DV360 광고 거래소명. |
| dv360_campaign.insertion_order_id | STRING | NULLABLE | DV360 삽입 주문 ID. |
| dv360_campaign.insertion_order_name | STRING | NULLABLE | DV360 삽입 주문명. |
| dv360_campaign.line_item_id | STRING | NULLABLE | DV360 라인 아이템 ID. |
| dv360_campaign.line_item_name | STRING | NULLABLE | DV360 라인 아이템명. |
| dv360_campaign.partner_id | STRING | NULLABLE | DV360 파트너 ID. |
| dv360_campaign.partner_name | STRING | NULLABLE | DV360 파트너명. |

#### publisher — 퍼블리셔 광고 수익
| 중첩 필드 | 타입 | 모드 | 설명 |
|----------|------|------|------|
| publisher.ad_revenue_in_usd | FLOAT | NULLABLE | 퍼블리셔 광고 수익 (USD). AdMob 등 광고 수익 모델 앱에서 사용. |
| publisher.ad_format | STRING | NULLABLE | 퍼블리셔 광고 형식. |
| publisher.ad_source_name | STRING | NULLABLE | 퍼블리셔 광고 소스명. |
| publisher.ad_unit_id | STRING | NULLABLE | 퍼블리셔 광고 유닛 ID. |

### 3.14 (최상위) 추가 식별 / 플랫폼 필드
> 원본 CSV의 `그룹` 열이 비어 있는 **최상위 스칼라 필드**입니다.
| 최상위 필드 | 중첩 필드 | 타입 | 모드 | 설명 |
|------------|----------|------|------|------|
| event_original_occurrence_timestamp | | INTEGER | NULLABLE | 이벤트가 기기에서 실제 발생한 원본 시각. UTC 마이크로초. 오프라인 이벤트 재전송 시 원래 발생 시각 보존. |
| stream_id | | STRING | NULLABLE | 이벤트가 수집된 GA4 데이터 스트림의 고유 ID. |
| platform | | STRING | NULLABLE | 이벤트가 발생한 플랫폼. 값: `WEB` / `ANDROID` / `IOS` |

---

## 4. Silver 변환 시 참고 (Quick Reference)

- **FLATTEN 대상 배열:** `event_params`, `user_properties`, `items`
- **event_params 값 추출:** `string_value` / `int_value` / `double_value` 중 채워진 것 사용 (`float_value`는 미사용).
- **세션 식별:** `user_pseudo_id` + `event_params['ga_session_id'].int_value`
- **GA4 UI 수치 일치:** `session_traffic_source_last_click` (③) 기준 attribution 사용.
- **CRM 연계:** `user_id` 우선, 없으면 `user_pseudo_id` + `ecommerce.transaction_id`.
- **날짜 범위 쿼리:** date-sharded 테이블이므로 `_TABLE_SUFFIX` (또는 적재 후 `event_date`) 기준 파티션 필터.
- **데이터 완전성:** 이벤트 발생 후 72시간까지 갱신되므로, 최근 3일(72h)치 데이터는 변동 가능. *(파생 가이드 — 원문 명시 아님: 확정 데이터가 필요하면 D-3 이전 기준 사용 권장.)*

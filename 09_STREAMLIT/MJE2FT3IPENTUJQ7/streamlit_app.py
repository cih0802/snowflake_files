import streamlit as st
import pandas as pd
import numpy as np
from html import escape
from datetime import date
from hashlib import sha256

st.set_page_config(page_title="마케팅 캠페인 통합 성과", page_icon="📊", layout="wide", initial_sidebar_state="expanded")
st.markdown("""
<style>
:root{--bg:#F7F6F1;--panel:#FFFFFF;--ink:#57463D;--muted:#70766F;--line:#DDD9CF;--olive:#89A230;--olive-soft:#E9EADE;--orange:#F36A16;--blue:#397FF0}
.stApp{background:var(--bg);color:var(--ink)}
.block-container{padding-top:1.35rem;padding-bottom:3rem;max-width:1500px}
[data-testid="stSidebar"]{background:#FFF;border-right:1px solid var(--line)}
h1,h2,h3,h4{color:var(--ink);letter-spacing:-.02em}
div[data-testid="stMetric"]{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px 18px;min-height:104px}
.report-kicker{color:var(--olive);font-size:.78rem;font-weight:800;letter-spacing:.10em;margin-bottom:6px}
.report-title{font-size:2rem;font-weight:850;color:var(--ink);line-height:1.2;margin-bottom:6px}
.sidebar-brand{font-size:1rem;font-weight:850;color:var(--ink);margin-bottom:3px}
.sidebar-sub{font-size:.75rem;color:var(--muted);margin-bottom:20px}
.hero-note{background:#F2F3EE;border:1px solid #D8DDD4;border-radius:12px;padding:13px 16px;color:#405047;margin:14px 0 8px}
.section-shell{background:rgba(255,255,255,.58);border:1px solid var(--line);border-radius:10px;padding:16px 18px;margin:14px 0 16px}
.section-number{color:var(--olive);font-weight:900;letter-spacing:.08em;margin-right:7px}
.section-title{font-size:1.25rem;font-weight:850;color:var(--ink)}
.section-desc{font-size:.82rem;color:var(--muted);margin-top:4px}
.insight-card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:14px;margin-bottom:14px;height:390px;overflow:hidden}
.insight-title{font-size:.90rem;font-weight:850;color:var(--ink);margin-bottom:4px}
.insight-description{font-size:.73rem;color:var(--muted);margin-bottom:10px;min-height:32px}
.ranking-row{display:grid;grid-template-columns:24px minmax(0,1fr);column-gap:7px;padding:8px 0;border-bottom:1px solid #ECEAE4}
.ranking-number{width:22px;height:22px;border-radius:50%;background:var(--olive-soft);color:#556A1F;display:flex;align-items:center;justify-content:center;font-size:.72rem;font-weight:850}
.ranking-name{font-size:.79rem;font-weight:750;color:var(--ink);line-height:1.3;overflow-wrap:anywhere}
.ranking-value{font-size:.72rem;color:var(--muted);margin-top:3px}
.ranking-empty{color:var(--muted);font-size:.80rem;padding:15px 0}
.mix-card{background:#FFF;border:1px solid var(--line);border-radius:12px;padding:14px;min-height:270px}
.mix-title{font-size:.88rem;font-weight:850;color:var(--ink);margin-bottom:10px}
.mix-row{margin:8px 0}.mix-label{display:flex;justify-content:space-between;gap:8px;font-size:.75rem}
.mix-bar{height:7px;background:#ECEDE7;border-radius:4px;overflow:hidden;margin-top:4px}
.mix-fill{height:100%;background:var(--olive);border-radius:4px}
[data-testid="stDataFrame"]{border:1px solid var(--line);border-radius:10px;overflow:hidden}
.grid-wrap{background:#FFF;border:1px solid var(--line);border-radius:10px;overflow:auto;max-height:560px;margin-bottom:10px}
.grid-table{border-collapse:collapse;width:100%;font-size:.80rem;color:var(--ink)}
.grid-table th,.grid-table td{border:1px solid #E6E3DA;padding:6px 10px;white-space:nowrap}
.grid-table thead th{background:#E9EADE;color:#405047;font-weight:800;text-align:center}
.grid-table td.num{text-align:right}
.grid-table td.txt{text-align:left}
.grid-table td.note{text-align:left;color:var(--muted);font-size:.74rem}
.grid-table tr.total td{font-weight:850;background:#F7F6F1}
.grid-table tr.sub td{font-weight:800;background:#EAF1D6}
.grid-table tr.hq td{font-weight:850;background:#FFF59D}

/* 최종 보고 화면: 아이보리 배경 / 올리브 강조 / 숫자 전체 표시 */
:root{--bg:#F6F7F3;--panel:#FFFFFF;--ink:#57463D;--muted:#8B7F79;--line:#E0E6DD;--olive:#89A230;--olive-soft:#E9EADE}
.block-container{max-width:1640px;padding-top:1.7rem;padding-left:2rem;padding-right:2rem}
[data-testid="stSidebar"]{background:#FBFCF8}
.report-title{font-size:clamp(1.65rem,2.5vw,2.25rem);font-weight:800;letter-spacing:-.045em}
.report-kicker{font-size:.68rem;letter-spacing:.2em;margin-bottom:10px}
.report-subtitle{color:var(--muted);font-size:.88rem;margin-top:10px;margin-bottom:22px;line-height:1.7}
.sidebar-brand{font-size:1.02rem;line-height:1.6}
.hero-note{background:#EDF2E6;border:1px solid #DCE5D0;border-left:4px solid #89A230;border-radius:12px;line-height:1.9;font-size:.8rem;padding:14px 18px}
.section-shell{background:#FFF;border:1px solid var(--line);border-radius:16px;padding:20px 22px;margin:20px 0 16px}
.section-number{display:inline-flex;align-items:center;justify-content:center;width:29px;height:29px;border-radius:9px;background:#E9EADE;font-size:.8rem;margin-right:10px}
.section-title{font-size:1.16rem}
.section-desc{line-height:1.8;margin-top:8px}
div[data-testid="stMetric"]{border:1px solid #E0E6DD;border-radius:14px;padding:17px 16px;min-height:112px;box-shadow:0 3px 12px rgba(35,57,47,.025)}
[data-testid="stMetricValue"]{font-size:clamp(1.05rem,1.6vw,1.7rem);font-weight:700;font-variant-numeric:tabular-nums;letter-spacing:-.045em}
[data-testid="stMetricValue"]>div{white-space:normal!important;overflow:visible!important;text-overflow:clip!important;overflow-wrap:anywhere}
[data-testid="stMetricLabel"]{font-size:.77rem;color:#6D7B71}
.kpi-card{background:#FFF;border:1px solid #E0E6DD;border-radius:14px;padding:17px 16px;min-height:108px;box-sizing:border-box;box-shadow:0 3px 12px rgba(35,57,47,.025)}
.kpi-label{font-size:.75rem;color:#6D7B71;margin-bottom:10px}
.kpi-value{font-size:clamp(1.05rem,1.55vw,1.65rem);font-weight:750;letter-spacing:-.055em;line-height:1.45;font-variant-numeric:tabular-nums;overflow-wrap:anywhere}
.kpi-value small{font-size:.7em;margin-left:3px;font-weight:500;color:#8B7F79}
[data-baseweb="tab-list"]{gap:8px;border-bottom:1px solid #E0E6DD;padding-bottom:6px}
button[data-baseweb="tab"]{border-radius:9px;padding:10px 14px;height:auto;color:#8B7F79;font-size:.83rem}
button[data-baseweb="tab"][aria-selected="true"]{background:#E9EADE;color:#4D642C;font-weight:750}
[data-baseweb="tab-highlight"]{background:#89A230;height:2px}
[data-testid="stButton"] button{border-radius:9px;border-color:#D9E2D2}
[data-testid="stSelectbox"] [data-baseweb="select"]>div{border-radius:9px}
[data-testid="stVerticalBlockBorderWrapper"]>div{border-radius:16px;border-color:#E0E6DD!important}
.grid-wrap{border-radius:12px;max-height:590px;background:#FFF}
.grid-table{font-size:.79rem;font-variant-numeric:tabular-nums}
.grid-table th,.grid-table td{padding:10px 12px;border-color:#E7ECE2}
.grid-table thead{position:sticky;top:0;z-index:2}
.grid-table thead th{background:#F0F4E8;color:#556A1F}
.grid-table tr.sub td{background:#F5F8EE;font-weight:650}
.grid-table tr.hq td{background:#E5EDD7;font-weight:800;border-top:2px solid #C9D6B7}
.grid-table tr.total td{background:#EEF3E7}
.grid-table tbody tr:hover td{box-shadow:inset 0 0 0 9999px rgba(119,139,55,.035)}
.insight-card{border-radius:14px;height:410px;padding:20px 20px 16px;margin:14px 0 18px;box-shadow:0 3px 12px rgba(35,57,47,.02)}
.top5-wrap{padding:6px 4px 0}
.insight-description{line-height:1.6;min-height:36px}
.ranking-row{padding:10px 0}
.ranking-name{font-size:.78rem;line-height:1.45}
.mix-card{border-radius:14px;padding:16px}
@media(max-width:1100px){.block-container{padding-left:1rem;padding-right:1rem}.grid-table{font-size:.74rem}.kpi-card{padding:13px 10px}.kpi-value{font-size:1.05rem}}

/* ---- 임원 보고용 최종 정리 ---- */
.detail-heading{display:flex;align-items:flex-start;gap:14px;background:#F2F6EB;border:1px solid #DDE6D1;border-left:5px solid #89A230;border-radius:14px;padding:16px 20px;margin:2px 0 10px}
.detail-eyebrow{font-size:.66rem;font-weight:800;letter-spacing:.16em;color:#89A230;margin-bottom:6px}
.detail-title{font-size:clamp(1.02rem,1.45vw,1.28rem);font-weight:800;color:#57463D;line-height:1.55;letter-spacing:-.03em;word-break:keep-all;overflow-wrap:break-word}
.detail-badge{display:inline-block;margin-left:8px;padding:2px 9px;border-radius:999px;background:#57463D;color:#FFF;font-size:.66rem;font-weight:700;vertical-align:middle;letter-spacing:0}
.comp-row{display:flex;flex-wrap:wrap;gap:6px;margin:2px 0 14px}
.comp-label{font-size:.72rem;color:#8B7F79;margin-right:4px;align-self:center}
.comp-chip{font-size:.72rem;color:#3F5537;background:#FFF;border:1px solid #DCE5D0;border-radius:999px;padding:3px 10px;line-height:1.5;word-break:keep-all}
.comp-chip.main{background:#FFF;border-color:#DCE5D0;font-weight:400}
.kpi-value{white-space:nowrap}
.rank-head{display:flex;align-items:center;gap:9px;margin-bottom:4px}
.rank-badge{display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border-radius:8px;background:#89A230;color:#FFF;font-size:.72rem;font-weight:800}
.rank-heading{font-size:.98rem;font-weight:800;color:#57463D}
.rank-desc{font-size:.73rem;color:#8B7F79;line-height:1.6;min-height:38px;margin:4px 0 10px}
.rank-value{font-size:.74rem;color:#556A1F;margin:-2px 0 10px 4px;font-variant-numeric:tabular-nums}
.rank-value b{color:#57463D}
div[class*="st-key-rank_"] button{width:100%;justify-content:flex-start;text-align:left;background:#FAFCF7;border:1px solid #E5EBDD;border-radius:10px;padding:8px 11px;min-height:42px;height:auto}
div[class*="st-key-rank_"] button p{font-size:.79rem;line-height:1.45;text-align:left;word-break:keep-all;overflow-wrap:break-word}
div[class*="st-key-rank_"] button:hover{background:#E9EADE;border-color:#A9BA83;color:#405B28}
.nav-title{font-size:.8rem;font-weight:800;color:#57463D;letter-spacing:.02em;margin:4px 0 2px}
[data-testid="stLinkButton"] a{border-radius:9px;border-color:#C8D6AF;background:#E9EADE;color:#3F5537;font-weight:700}
[data-testid="stLinkButton"] a:hover{background:#E2EBD0;border-color:#89A230;color:#2F4423}


/* 가독성 및 차트 통일 */
.insight-card{height:430px;padding:18px 20px;overflow:auto}
.insight-title{font-size:15px;line-height:1.5}
.insight-description{font-size:12px;line-height:1.6;min-height:24px;margin-bottom:8px}
.ranking-row{grid-template-columns:24px minmax(0,1fr);gap:8px;padding:9px 0;min-height:62px;box-sizing:border-box}
.ranking-number{width:22px;height:22px;font-size:11px;margin-top:2px}
.ranking-name{font-size:13px;line-height:1.5;word-break:keep-all;overflow-wrap:anywhere}
.ranking-value{font-size:12px;line-height:1.5;margin-top:3px;color:#556A1F}
.ranking-value b{font-weight:650;color:#57463D;font-variant-numeric:tabular-nums}
.chart-heading{font-size:16px;font-weight:750;color:#57463D;margin:6px 0 8px}
.chart-key{font-size:13px;line-height:1.6;color:#8B7F79;margin-bottom:8px}
@media(max-width:1100px){.insight-card{height:470px;padding:16px}.ranking-name{font-size:13px}}


/* TOP 5 클릭형 카드: 확정한 작은 글씨 크기 유지 */
div[class*="st-key-rank_link_"] button{width:100%;justify-content:flex-start;text-align:left;background:transparent;border:0;border-radius:5px;padding:3px 0;min-height:28px;height:auto;color:#57463D}
div[class*="st-key-rank_link_"] button p{font-size:13px!important;line-height:1.5;font-weight:650;text-align:left;word-break:keep-all;overflow-wrap:anywhere}
div[class*="st-key-rank_link_"] button:hover{background:#E9EADE;color:#556A1F}
.rank-heading{font-size:15px}.rank-desc{font-size:12px;min-height:24px;margin-bottom:8px}
.rank-value{font-size:12px;margin:0 0 8px 0;color:#685A55;line-height:1.5}
.rank-value b{font-weight:650}.rank-heading{color:#57463D}
[data-testid="stTabs"] [aria-selected="true"]{color:#556A1F!important}
[data-baseweb="tab-highlight"]{background:#89A230!important}

/* 원안의 흰색 3열 카드, 원형 순위, 얇은 구분선 복원 */
div[class*="st-key-top5_card_"]{background:#FFFFFF;border-radius:14px}
div[class*="st-key-top5_card_"] [data-testid="stVerticalBlock"]{gap:0.25rem}
div[class*="st-key-top5_card_"] .insight-title{font-size:15px;font-weight:750;margin-bottom:4px;color:#57463D}
div[class*="st-key-top5_card_"] .insight-description{font-size:12px;min-height:24px;margin-bottom:8px}
div[class*="st-key-top5_card_"] .ranking-number{margin-top:5px;background:#E9EADE;color:#556A1F}
div[class*="st-key-top5_card_"] .ranking-value{font-size:12px;margin-top:1px;line-height:1.5}
div[class*="st-key-top5_card_"] .rank-separator{border-bottom:1px solid #E9EADE;margin:7px 0}
div[class*="st-key-rank_link_"] button{padding:0;min-height:24px;border:0;background:transparent;box-shadow:none}
div[class*="st-key-rank_link_"] button p{font-size:13px!important;line-height:1.5;font-weight:650}

/* 캠페인명 버튼의 내부 flex 정렬까지 왼쪽으로 고정 */
div[class*="st-key-rank_link_"] button{justify-content:flex-start!important;text-align:left!important}
div[class*="st-key-rank_link_"] button > div{width:100%;text-align:left!important;justify-content:flex-start!important}
div[class*="st-key-rank_link_"] button [data-testid="stMarkdownContainer"]{width:100%;text-align:left!important}
div[class*="st-key-rank_link_"] button p{width:100%;text-align:left!important;margin-left:0!important}
.popup-kpi{background:#FFFFFF;border:1px solid #E0E6DD;border-radius:12px;padding:14px 12px;min-height:96px;box-sizing:border-box}
.popup-kpi-label{font-size:12px;color:#685A55;margin-bottom:10px;line-height:1.4}
.popup-kpi-value{font-size:clamp(15px,1.5vw,22px);font-weight:700;white-space:nowrap;letter-spacing:-.04em;color:#57463D;font-variant-numeric:tabular-nums}
</style>
""", unsafe_allow_html=True)
conn = st.connection("snowflake")

try:
    pd.set_option("styler.render.max_elements", 3_000_000)
except Exception:
    pass

# 조회 결과 캐시 시간(초). 발표 중에 화면이 느려지지 않도록 1시간으로 둡니다. 최신 데이터는 사이드바 '데이터 새로고침'으로 다시 불러옵니다.
CACHE_TTL = 3600

# 통합효율 TOP 5 대상 조건: 개발 규모가 너무 작거나, 비용이 덜 들어가 단가가 비정상적으로 낮은 캠페인은 제외합니다.
TOP_EFFICIENCY_MIN_DEV = 1000          # 선택 기간 개발건수 이 값 이상
TOP_EFFICIENCY_MIN_UNIT_COST = 10000   # 통합 개발단가가 이 값(원) 이하이면 제외

# 연결 대시보드: 주소를 넣으면 '연결 준비 중' 버튼이 이동 버튼으로 바뀝니다.
DASHBOARD_LINKS = {
    "디지털": "https://app.snowflake.com/streamlit/cmrqtut/xc97295/#/apps/heszosc553wijqaqgaad",
    "영상광고": "",
    "방송": "",
    "재송출": "",
}

# ------------------------------------------------------------------
# 설정
# ------------------------------------------------------------------
# 통합 캠페인(원방송) 매핑: 개별 캠페인 -> 통합 캠페인
CAMPAIGN_ROLLUP = [
    ("고려인(1편)", "희망TV_고려인(이스타니슬라브,윤예브기니,김유리,한소피아,전다니엘)"),
    ("고려인(2편)", "희망TV_고려인(이콘스탄틴,로뎀학교,전다니엘,이스타니슬라브,허블라디슬라브,문안젤리카,김이리나,황비탈리,프란시스)"),
    ("잘먹고잘사는법플러스_고려인(이스타니슬라브,이콘스탄틴)", "희망TV_고려인(이콘스탄틴,로뎀학교,전다니엘,이스타니슬라브,허블라디슬라브,문안젤리카,김이리나,황비탈리,프란시스)"),
    ("잘먹고잘사는법플러스_고려인(이콘스탄틴,김유리,김메디나)", "희망TV_고려인(이콘스탄틴,로뎀학교,전다니엘,이스타니슬라브,허블라디슬라브,문안젤리카,김이리나,황비탈리,프란시스)"),
    ("세상에서가장아름다운여행_고려인(허블라디슬라브,이콘스탄틴)", "희망TV_고려인(이콘스탄틴,로뎀학교,전다니엘,이스타니슬라브,허블라디슬라브,문안젤리카,김이리나,황비탈리,프란시스)"),
    ("고려인(3편)", "희망TV_고려인(최류드밀라,김메디나,최리자,이콘스탄틴)"),
    ("참전용사(1회)", "희망TV_참전용사(참전용사후손_에티오피아,태국)"),
    ("참전용사(2회)", "희망TV_참전용사(참전용사)"),
    ("해외교육(판디)", "바다건너사랑_정일우(나타나이나,판디,칠라비나)"),
    ("보건의료(마리안)", "글로벌도네이션쇼W(미리암,마리안,프랭크)"),
    ("위기가정(함께한끼)", "국내결식(함께한끼)"),
    ("위기가정(성준)", "휴먼다큐소원(예진,성준)"),
    ("보건의료(폴레트)", "바다건너사랑_윤시윤(폴레트,제시카,야리스)"),
    ("위기가정(그루이루)", "글로벌도네이션쇼W(메리,한그루,케니)"),
    ("위기가정(현아)", "글로벌도네이션쇼W(빌랄,현아,가브리엘)"),
    ("위기가정(성민)", "글로벌도네이션쇼W(성민,희영)"),
    ("위기가정(선오)", "휴먼다큐소원(선오,기백)"),
    ("보건의료(샤리아)", "바다건너사랑_이대호(스메티아,샤리아,기프트)"),
    ("보건의료(가브리엘)", "글로벌도네이션쇼W(가브리엘,멀린)"),
    ("위기가정(초은)", "나누는행복희망플러스(김초은,윤하온)"),
    ("보건의료(하비네자)", "글로벌도네이션쇼W(하비네자,재키,페브리스)"),
    ("위기가정(소피아)", "희망TV_고려인(이스타니슬라브,윤예브기니,김유리,한소피아,전다니엘)"),
    ("보건의료(앤드류)", "바다건너사랑_문희경(앤드류,사피아,기프트)"),
    ("보건의료(메리)", "글로벌도네이션쇼어게인W(케파,메리)"),
    ("보건의료(데릭)", "글로벌도네이션쇼W(데릭,티모시,무함마드)"),
    ("위기가정(정후)", "나누는행복희망플러스(아랑,정후)"),
    ("위기가정(아랑)", "나누는행복희망플러스(아랑,정후)"),
    ("위기가정(수현예진)", "휴먼다큐소원(수현,예진,선영,아영)"),
    ("위기가정(민서)", "나누는행복희망플러스(해찬,민서)"),
    ("위기가정(해찬)", "나누는행복희망플러스(해찬,민서)"),
    ("위기가정(보정)", "휴먼다큐소원(보정,해진)"),
]
ROLLUP_MAP = dict(CAMPAIGN_ROLLUP)

# 산점도·TOP 5에서 제외할 통합 캠페인. 방송 UTM 자동 통합 대상에서도 빠집니다. (상단 카드·표에는 포함)
SCATTER_EXCLUDE = ["24년 이전컨텐츠"]
# 방송 캠페인과 UTM을 공유하는 디지털 캠페인을 그 방송 캠페인으로 자동 통합할지의 기본값(사이드바에서 켜고 끌 수 있음)
AUTO_ROLLUP_DEFAULT = True

# 디지털 원천 캠페인명(CMPGN_NM) -> CRM 캠페인명 보정 (UTM 연결이 안 될 때 사용)
DIGITAL_NAME_ALIAS = [
    ("위기가정(초은)_리뉴얼", "위기가정(초은)"),
    ("교육지원(판디)", "바다건너사랑_정일우(나타나이나,판디,칠라비나)"),
    ("결식(한끼2차)", "국내결식(한끼2차)"),
]

# UTM이 비어 있는 공통비(검색·브랜드·통합·크레딧): 캠페인에 배분하지 않음
COMMON_COST_NAMES = ["N 키워드", "G 키워드", "D 키워드", "N 브랜드", "합계", "국내캠페인(통합)", "N서칭뷰", "CREDIT"]
COMMON_STATUS = "공통비(검색·브랜드)"

# 광고 원천 채널명 -> CRM 채널명 보정 (띄어쓰기·대소문자는 자동 무시)
CHANNEL_ALIAS = [
    ("라디오", "RADIO"),
]

# 광고 원천 그룹: 재송출 원천은 구분(DIV_NM)에 따라 방송 / 재송출로 나눕니다.
SOURCE_GROUP_LABEL = {
    "DIGITAL": "디지털",
    "VIDEO": "영상광고",
    "BROADCAST": "방송",
    "RELAY": "재송출",
    "REBROADCAST_OTHER": "재송출·방송(구분 기타)",
}
# CRM 개발인입경로 -> 광고 원천 그룹 (원천별 표에서 개발건수·제작비를 원천에 맞출 때 사용). 뉴미디어는 방송에서 나옵니다.
INFLOW_TO_SOURCE = {"디지털": "DIGITAL", "영상광고": "VIDEO", "방송": "BROADCAST", "뉴미디어": "BROADCAST", "재송출": "RELAY"}

# 나눔마케팅본부 팀 설정
TEAMS = ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀"]
BROADCAST_TEAMS = ["마케팅기획1팀", "마케팅기획2팀"]
# 광고 원천 -> 팀 규칙 (방송은 아래 원방송 담당 팀 지정표를 따릅니다)
AD_SOURCE_TEAM = {"DIGITAL": "매체운영팀", "VIDEO": "매체운영팀", "RELAY": "매체운영팀"}
# 방송 원방송 담당 팀: 기본은 방송 개발건수가 많은 팀으로 자동 지정하고, 여기에 적은 캠페인은 직접 지정이 우선합니다.
BROADCAST_TEAM_OVERRIDE = {
    "바다건너사랑_윤시윤(폴레트,제시카,야리스)": "마케팅기획2팀",
    "소란스런콜라보": "마케팅기획2팀",
}
INFLOW_ORDER = ["방송", "뉴미디어", "디지털", "영상광고", "재송출", "콜개발"]
INFLOW_NOTE = {
    "방송": "방송 구분 광고비: 원방송 담당 팀 기준",
    "뉴미디어": "광고비는 방송 행에 포함",
    "콜개발": "광고 원천 없음",
}
UNASSIGNED_TEAM = "팀 미지정"
OTHER_DEPT = "본부 외 부서"

# 회원개발 목표 (TM_CM_MBER_DVLP_GOAL_DIV): 목표 종류 / 예산 구분 표시 이름
GOAL_TYPE_NAME = "회원개발"
BUDGET_LABELS = {"연사업": "연목표 (연사업)"}

# 디지털 날짜 복원: 원천 날짜(DATE)가 비어 있거나 1970-01-01일 때 연·월·일 컬럼으로 복원
DIGITAL_DATE_RESTORE = True
DIGITAL_YMD_COLUMNS = ("YEAR", "MONTH", "DAY")


def _sql_text(value):
    return str(value).replace("'", "''")


def _restore_expr(alias, cols):
    y, m, d = (f"{alias}.{c}" for c in cols)
    num = "TRY_TO_NUMBER(REGEXP_REPLACE(TO_VARCHAR({0}),'[^0-9]',''))"
    return (
        f"IFF({num.format(y)} BETWEEN 2000 AND 2100, TRY_TO_DATE("
        f"TO_VARCHAR({num.format(y)}) || '-' || "
        f"LPAD(TO_VARCHAR({num.format(m)}),2,'0') || '-' || "
        f"LPAD(TO_VARCHAR({num.format(d)}),2,'0'), 'YYYY-MM-DD'), NULL)"
    )


if DIGITAL_DATE_RESTORE:
    _DIGITAL_BRANCH = f"""
    SELECT 'DIGITAL',
           IFF(D.DATE IS NULL OR D.DATE = DATE '1970-01-01', COALESCE(D.RESTORED_DATE, D.DATE), D.DATE),
           NULL, NULLIF(UPPER(TRIM(D.UTM_CMPGN_NM)),''),
           D.MATR, D.MEDIA_NM, UPPER(TRIM(D.AD_TY_NM)), D.LAST_STMT_AMT,
           CASE WHEN D.DATE IS NOT NULL AND D.DATE <> DATE '1970-01-01' THEN '원천 날짜'
                WHEN D.RESTORED_DATE IS NOT NULL THEN '연월일 복원'
                ELSE '복원 불가' END,
           NULLIF(TRIM(D.CMPGN_NM),''), NULLIF(TRIM(D.UTM_CMPGN_NM),''),
           D.EXPS_CNT::FLOAT, D.CLICK_CNT::FLOAT, D.CONV_VU_CNT::FLOAT, D.SPNSER_MBER_CNT::FLOAT
    FROM (
        SELECT X.*, {_restore_expr('X', DIGITAL_YMD_COLUMNS)} RESTORED_DATE
        FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS X
    ) D
"""
else:
    _DIGITAL_BRANCH = """
    SELECT 'DIGITAL', DATE, NULL, NULLIF(UPPER(TRIM(UTM_CMPGN_NM)),''),
           MATR, MEDIA_NM, UPPER(TRIM(AD_TY_NM)), LAST_STMT_AMT,
           '원천 날짜', NULLIF(TRIM(CMPGN_NM),''), NULLIF(TRIM(UTM_CMPGN_NM),''),
           EXPS_CNT::FLOAT, CLICK_CNT::FLOAT, CONV_VU_CNT::FLOAT, SPNSER_MBER_CNT::FLOAT
    FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
"""

_ROLLUP_VALUES = ",\n        ".join(f"('{_sql_text(s)}', '{_sql_text(t)}')" for s, t in CAMPAIGN_ROLLUP)
_NAME_ALIAS_VALUES = ", ".join(f"('{_sql_text(s)}', '{_sql_text(t)}')" for s, t in DIGITAL_NAME_ALIAS)
_CHANNEL_ALIAS_VALUES = ", ".join(f"('{_sql_text(s)}', '{_sql_text(t)}')" for s, t in CHANNEL_ALIAS)
_COMMON_LIST = ", ".join(f"'{_sql_text(x)}'" for x in COMMON_COST_NAMES)
_TEAM_LIST = ", ".join(f"'{_sql_text(t)}'" for t in TEAMS)

_CRM_ERP_CTES_RAW = r"""
WITH CRM_CAMPAIGN_BASE AS (
    SELECT NULLIF(TRIM(CMPGN_CD),'') CMPGN_CD,
           NULLIF(TRIM(MK_CMPGN_NM),'') MKTG_CAMPAIGN_NM,
           NULLIF(TRIM(MBER_INFLOW_PATH_NM),'') INFLOW_PATH_NM,
           NULLIF(TRIM(MKTG_UTM_NM),'') MKTG_UTM_NM,
           NULLIF(TRIM(UPPER_CMPGN_CD),'') UPPER_CMPGN_CD,
           NULLIF(TRIM(PARENT_CAMPAIGN_NAME),'') PARENT_CAMPAIGN_NAME,
           COALESCE(NULLIF(TRIM(CMPGN_TYPE1_NM),''),'미분류') CAMPAIGN_TYPE1,
           COALESCE(NULLIF(TRIM(CMPGN_TYPE2_NM),''),'미분류') CAMPAIGN_TYPE2,
           COALESCE(NULLIF(TRIM(MKTG_CHANNEL_NM),''),'미분류') CHANNEL_NAME
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE NULLIF(TRIM(CMPGN_CD),'') IS NOT NULL
      AND NULLIF(TRIM(MK_CMPGN_NM),'') IS NOT NULL
),
CAMPAIGN_DIM AS (
    SELECT MKTG_CAMPAIGN_NM,
           LISTAGG(DISTINCT CAMPAIGN_TYPE1, ', ') WITHIN GROUP (ORDER BY CAMPAIGN_TYPE1) CAMPAIGN_TYPE1,
           LISTAGG(DISTINCT CAMPAIGN_TYPE2, ', ') WITHIN GROUP (ORDER BY CAMPAIGN_TYPE2) CAMPAIGN_TYPE2,
           LISTAGG(DISTINCT CHANNEL_NAME, ', ') WITHIN GROUP (ORDER BY CHANNEL_NAME) CHANNEL_NAME,
           LISTAGG(DISTINCT COALESCE(INFLOW_PATH_NM,'미분류'), ', ')
               WITHIN GROUP (ORDER BY COALESCE(INFLOW_PATH_NM,'미분류')) INFLOW_PATH_NM
    FROM CRM_CAMPAIGN_BASE GROUP BY 1
),
CODE_DIM AS (
    -- 캠페인코드 1개당 1행: 코드별 채널·개발인입경로·유형 (코드가 중복 등록된 경우 대표값 1개 사용)
    SELECT UPPER(CMPGN_CD) CODE_KEY,
           MIN(MKTG_CAMPAIGN_NM) MKTG_CAMPAIGN_NM,
           MIN(CAMPAIGN_TYPE1) CAMPAIGN_TYPE1,
           MIN(CAMPAIGN_TYPE2) CAMPAIGN_TYPE2,
           MIN(CHANNEL_NAME) CHANNEL_NAME,
           MIN(COALESCE(INFLOW_PATH_NM,'미분류')) INFLOW_PATH_NM
    FROM CRM_CAMPAIGN_BASE GROUP BY 1
),
CODE_TEAM AS (
    -- 캠페인코드의 사용부서(USE_DEPT_CD)를 팀명으로 변환 (제작비의 팀 기준)
    SELECT UPPER(TRIM(M.CMPGN_CD)) CODE_KEY, MIN(D.DEPT_NM) TEAM_NAME
    FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG M
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON M.USE_DEPT_CD = D.DEPT_ID
    GROUP BY 1
),
CRM_CHANNEL_KEYS AS (
    SELECT UPPER(REPLACE(TRIM(CHANNEL_NAME),' ','')) CH_KEY, MIN(CHANNEL_NAME) CH_NAME
    FROM CRM_CAMPAIGN_BASE GROUP BY 1
),
CHANNEL_ALIAS AS (
    SELECT UPPER(REPLACE(TRIM(COLUMN1),' ','')) SRC_KEY, MIN(COLUMN2::VARCHAR) CH_NAME
    FROM VALUES __CHANNEL_ALIAS_VALUES__
    GROUP BY 1
),
CAMP_CH_DIM AS (
    -- 캠페인 x 채널별 CRM 캠페인코드 속성 (광고비 행의 유형·개발인입경로 판정에 사용)
    SELECT MKTG_CAMPAIGN_NM, UPPER(REPLACE(TRIM(CHANNEL_NAME),' ','')) CH_KEY,
           LISTAGG(DISTINCT CAMPAIGN_TYPE1, ', ') WITHIN GROUP (ORDER BY CAMPAIGN_TYPE1) CAMPAIGN_TYPE1,
           LISTAGG(DISTINCT CAMPAIGN_TYPE2, ', ') WITHIN GROUP (ORDER BY CAMPAIGN_TYPE2) CAMPAIGN_TYPE2,
           LISTAGG(DISTINCT COALESCE(INFLOW_PATH_NM,'미분류'), ', ')
               WITHIN GROUP (ORDER BY COALESCE(INFLOW_PATH_NM,'미분류')) INFLOW_PATH_NM
    FROM CRM_CAMPAIGN_BASE GROUP BY 1,2
),
CRM_DEV AS (
    SELECT TRY_TO_DATE(D.OCCRRNC_DE,'YYYYMMDD') PERFORMANCE_DATE,
           C.MKTG_CAMPAIGN_NM, C.CAMPAIGN_TYPE1, C.CAMPAIGN_TYPE2, C.CHANNEL_NAME, C.INFLOW_PATH_NM,
           COUNT(DISTINCT CONCAT_WS('|',COALESCE(D.SPNSR_NO,''),
               COALESCE(TO_VARCHAR(D.SPNSR_BSNS_NO),''),COALESCE(D.OCCRRNC_DE,''),
               COALESCE(TO_VARCHAR(D.SER_NO),''))) DEVELOPMENT_COUNT
    FROM GN_DW.SILVER.CRM_MEMBER_DEV D
    JOIN CODE_DIM C ON UPPER(TRIM(D.CMPGN_CD))=C.CODE_KEY
    WHERE REGEXP_LIKE(D.OCCRRNC_DE,'^[0-9]{8}$')
      AND TRY_TO_DATE(D.OCCRRNC_DE,'YYYYMMDD') IS NOT NULL
    GROUP BY 1,2,3,4,5,6
),
ERP0 AS (
    SELECT COALESCE(TRY_TO_DATE(TO_VARCHAR(WRITE_DATE),'YYYYMMDD'),
                    TRY_TO_DATE(TO_VARCHAR(WRITE_DATE))) PERFORMANCE_DATE,
           UPPER(TRIM(CONTENTS_DELIMITER)) CMPGN_CD,
           SUM(COALESCE(SUM_AMT,0)) PRODUCTION_COST
    FROM GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION
    WHERE CONTENTS_DELIMITER IS NOT NULL AND TRIM(CONTENTS_DELIMITER) NOT IN ('','-')
    GROUP BY 1,2
),
ERP AS (
    SELECT E.PERFORMANCE_DATE, C.MKTG_CAMPAIGN_NM, C.CAMPAIGN_TYPE1, C.CAMPAIGN_TYPE2, C.CHANNEL_NAME, C.INFLOW_PATH_NM,
           T.TEAM_NAME,
           SUM(E.PRODUCTION_COST) PRODUCTION_COST
    FROM ERP0 E
    JOIN CODE_DIM C ON E.CMPGN_CD=C.CODE_KEY
    LEFT JOIN CODE_TEAM T ON E.CMPGN_CD=T.CODE_KEY
    WHERE E.PERFORMANCE_DATE IS NOT NULL GROUP BY 1,2,3,4,5,6,7
),
"""
_CRM_ERP_CTES = _CRM_ERP_CTES_RAW.replace("__CHANNEL_ALIAS_VALUES__", _CHANNEL_ALIAS_VALUES)

_AD_MAPPING_PART1 = r"""
MATERIAL_MAP AS (
    SELECT COLUMN1::VARCHAR MATERIAL_NAME, COLUMN2::NUMBER TARGET_ID
    FROM VALUES
        ('메리', 98),
        ('메리V1', 98),
        ('보건_메리_V1', 98),
        ('보건의료_메리', 98),
        ('보건의료_메리_B', 98),
        ('보건의료_메리(최강창민)_B', 98),
        ('메리(팔찌)', 98),
        ('메리(포텐셜)', 98),
        ('보건의료_메리_굿즈', 98),
        ('케파', 98),
        ('케파V1', 98),
        ('케파_보건의료', 98),
        ('보건의료_케파', 98),
        ('보건의료_케파_B', 98),
        ('케파_보건의료(포텐셜)', 98),
        ('보건의료_케파_굿즈', 98),
        ('바르함_교육이혜숙', 80),
        ('바르함(교육/이혜숙)', 80),
        ('교육지원_바르함(이혜숙)', 80),
        ('교육_바르함_이혜숙', 80),
        ('바르함_교육이혜숙(포텐셜)', 80),
        ('바르함(포텐셜)', 80),
        ('교육_바르함_포텐셜_이혜숙', 80),
        ('교육지원_바르함(이혜숙)_굿즈', 80),
        ('교육지원_바르함(이혜숙)_퍼포머셜', 80),
        ('성민(국내)', 393),
        ('성민V1', 393),
        ('위기가정_성민', 393),
        ('위기가정_성민_B', 393),
        ('위기가정_재영', 415),
        ('위기가정_정후', 420),
        ('위기가정_정후_1만원', 420),
        ('위기가정_아랑_1만원', 406),
        ('위기가정_현아', 435),
        ('위기가정_민서', 381),
        ('위기가정_민서_QR', 381),
        ('보건의료_앤드류', 232),
        ('보건의료_앤드류_QR', 232),
        ('보건의료_데릭', 226),
        ('보건의료_데릭(김현주)_B', 226),
        ('보건의료_마리안_1만원', 228),
        ('보건의료_가브리엘', 224),
        ('보건의료_가브리엘_1만원', 224),
        ('보건의료_가브리엘(백지영콜링)', 224),
        ('지역개발_참전용사', 498),
        ('지역개발_참전용사_1만원', 498),
        ('위기가정_함께한끼', 48),
        ('식수(변우민)', 148),
        ('변우민편_영양실조(2023)', 148),
        ('보건의료_영양실조2023(변우민)', 148),
        ('교육(이혜숙)', 80),
        ('교육지원_앤드류', 212),
        ('그루(국내)', 77),
        ('위기가정_그루', 77),
        ('고려인', 594),
        ('지역개발_고려인', 594),
        ('하비네자', 93),
        ('보건의료_하비네자', 93),
        ('재키', 93),
        ('보건의료_재키', 93),
        ('마리안', 79),
        ('보건의료_마리안', 79)
),
CAMPAIGN_ALIAS_MAP AS (
    SELECT COLUMN1::VARCHAR CAMPAIGN_KEY, COLUMN2::NUMBER TARGET_ID
    FROM VALUES
        ('유어턴링(2기)', 441),
        ('위기가정(한끼모험)', 47)
),
BROADCAST_NAME_MAP AS (
    SELECT REPLACE(COLUMN1::VARCHAR,' ','') BROADCAST_KEY, COLUMN2::NUMBER TARGET_ID
    FROM VALUES
        ('2023 글로벌도네이션쇼W 1부', 80),
        ('2023 글로벌도네이션쇼W 2부', 86),
        ('2023 글로벌도네이션쇼W 3부', 92),
        ('2023 글로벌도네이션쇼W 4부', 77),
        ('2023 글로벌도네이션쇼어게인W 1부', 99),
        ('2023 글로벌도네이션쇼어게인W 2부', 97),
        ('2022 글로벌도네이션쇼W 4부', 88),
        ('2023 나누는행복희망플러스 상반기', 132)
),
CONFIRMED_BROADCAST_MAP AS (
    SELECT COLUMN1::VARCHAR UPPER_KEY, COLUMN2::NUMBER TARGET_ID
    FROM VALUES
        ('U0418', 594),
        ('U1312', 85),
        ('U1354', 74),
        ('U1439', 213)
),
CAMPAIGN_ROLLUP AS (
    SELECT COLUMN1::VARCHAR SOURCE_NAME, COLUMN2::VARCHAR ROLLUP_NAME
    FROM VALUES
        """

_AD_MAPPING_PART2 = r"""
),
CRM_TARGETS AS (
    SELECT DISTINCT MKTG_CMPGN_NM TARGET_ID,
           NULLIF(TRIM(MK_CMPGN_NM),'') TARGET_NAME
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE NULLIF(TRIM(MK_CMPGN_NM),'') IS NOT NULL
),
SRC_NAME_ALIAS AS (
    SELECT M.CAMPAIGN_KEY SRC_NAME, T.TARGET_NAME
    FROM CAMPAIGN_ALIAS_MAP M JOIN CRM_TARGETS T ON T.TARGET_ID=M.TARGET_ID
),
CRM_LINK_KEYS AS (
    SELECT DISTINCT 'UPPER_CODE' KEY_TYPE,
           UPPER(TRIM(UPPER_CMPGN_CD)) LINK_KEY, MKTG_CAMPAIGN_NM TARGET_NAME
    FROM CRM_CAMPAIGN_BASE
    WHERE UPPER_CMPGN_CD IS NOT NULL AND TRIM(UPPER_CMPGN_CD) <> '-'
    UNION
    SELECT DISTINCT 'PARENT_NAME', UPPER(TRIM(PARENT_CAMPAIGN_NAME)), MKTG_CAMPAIGN_NM
    FROM CRM_CAMPAIGN_BASE
    WHERE PARENT_CAMPAIGN_NAME IS NOT NULL AND TRIM(PARENT_CAMPAIGN_NAME) <> '-'
    UNION
    SELECT DISTINCT 'MARKETING_NAME', UPPER(TRIM(MKTG_CAMPAIGN_NM)), MKTG_CAMPAIGN_NM
    FROM CRM_CAMPAIGN_BASE
    UNION
    SELECT DISTINCT 'UTM', UPPER(TRIM(S.VALUE)), C.MKTG_CAMPAIGN_NM
    FROM CRM_CAMPAIGN_BASE C,
         LATERAL SPLIT_TO_TABLE(C.MKTG_UTM_NM, ',') S
    WHERE C.MKTG_UTM_NM IS NOT NULL
      AND NULLIF(TRIM(S.VALUE),'') IS NOT NULL
      AND TRIM(S.VALUE) <> '-'
),
DIGITAL_NAME_KEYS AS (
    SELECT LINK_KEY NAME_KEY, TARGET_NAME FROM CRM_LINK_KEYS WHERE KEY_TYPE='MARKETING_NAME'
    UNION
    SELECT UPPER(TRIM(SRC_NAME)), TARGET_NAME FROM SRC_NAME_ALIAS
    UNION
    SELECT UPPER(TRIM(COLUMN1)), COLUMN2 FROM VALUES __NAME_ALIAS_VALUES__
),
BROADCAST_CAMPAIGNS AS (
    SELECT DISTINCT MKTG_CAMPAIGN_NM CAMPAIGN_NAME
    FROM CRM_CAMPAIGN_BASE
    WHERE INFLOW_PATH_NM IN ('방송','재송출')
      AND MKTG_CAMPAIGN_NM <> '24년 이전컨텐츠'
),
CRM_UTM_SPLIT AS (
    SELECT DISTINCT C.MKTG_CAMPAIGN_NM CAMPAIGN_NAME, UPPER(TRIM(S.VALUE)) UTM
    FROM CRM_CAMPAIGN_BASE C,
         LATERAL SPLIT_TO_TABLE(C.MKTG_UTM_NM, ',') S
    WHERE C.MKTG_UTM_NM IS NOT NULL
      AND NULLIF(TRIM(S.VALUE),'') IS NOT NULL
      AND TRIM(S.VALUE) <> '-'
),
BROADCAST_REDIRECT AS (
    SELECT D.CAMPAIGN_NAME SOURCE_NAME,
           LISTAGG(DISTINCT B.CAMPAIGN_NAME, ' | ')
               WITHIN GROUP (ORDER BY B.CAMPAIGN_NAME) BROADCAST_CANDIDATES
    FROM CRM_UTM_SPLIT D
    JOIN CRM_UTM_SPLIT B
      ON D.UTM=B.UTM AND D.CAMPAIGN_NAME<>B.CAMPAIGN_NAME
    JOIN BROADCAST_CAMPAIGNS BC ON BC.CAMPAIGN_NAME=B.CAMPAIGN_NAME
    WHERE D.CAMPAIGN_NAME NOT IN (SELECT CAMPAIGN_NAME FROM BROADCAST_CAMPAIGNS)
    GROUP BY D.CAMPAIGN_NAME
),
AD_RAW AS (
    SELECT 'VIDEO' SOURCE_TYPE,
           IFF(V.BRDC_DATE IS NULL OR V.BRDC_DATE = DATE '1970-01-01',
               COALESCE(V.RESTORED_DATE, V.BRDC_DATE), V.BRDC_DATE) PERFORMANCE_DATE,
           UPPER(TRIM(V.UPPER_CMPGN_NM)) UPPER_KEY,
           UPPER(TRIM(V.CMPGN_NM)) CAMPAIGN_KEY,
           TRIM(V.MATR_NM) MATERIAL_NAME, V.CHNNL_NM SOURCE_CHANNEL,
           UPPER(TRIM(V.AD_TY_NM)) AD_TYPE, V.LAST_AD_COST COST,
           CASE WHEN V.BRDC_DATE IS NOT NULL AND V.BRDC_DATE <> DATE '1970-01-01' THEN '원천 방송일'
                WHEN V.RESTORED_DATE IS NOT NULL THEN '연월일 복원'
                ELSE '복원 불가' END DATE_SOURCE,
           NULL::VARCHAR SOURCE_CAMPAIGN,
           NULL::VARCHAR UTM_RAW,
           NULL::FLOAT IMPRESSIONS, NULL::FLOAT CLICKS,
           NULL::FLOAT CONVERSIONS, NULL::FLOAT SPONSORS
    FROM (
        SELECT X.*, __VIDEO_RESTORE__ RESTORED_DATE
        FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS X
    ) V
    UNION ALL
    SELECT 'REBROADCAST', BRDC_DATE, UPPER(TRIM(UPPER_CMPGN_CD)),
           UPPER(TRIM(CMPGN_CD)), TRIM(BRDC_NM), CHNNL_NM, NULLIF(TRIM(DIV_NM),''), TOT_COST,
           '원천 방송일', NULL::VARCHAR, NULL::VARCHAR,
           NULL::FLOAT, NULL::FLOAT, NULL::FLOAT, NULL::FLOAT
    FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS
    UNION ALL
__DIGITAL_BRANCH__
),
AD_GROUPED AS (
    SELECT SOURCE_TYPE, PERFORMANCE_DATE, UPPER_KEY, CAMPAIGN_KEY,
           MATERIAL_NAME, SOURCE_CHANNEL, AD_TYPE, DATE_SOURCE, SOURCE_CAMPAIGN, UTM_RAW,
           COUNT(*) SOURCE_ROW_COUNT,
           SUM(IFF(COST IS NULL,1,0)) COST_NULL_ROWS,
           SUM(IFF(COST < 0,COST,0)) NEGATIVE_COST_AMOUNT,
           SUM(COALESCE(COST,0)) SOURCE_COST,
           SUM(COALESCE(IMPRESSIONS,0)) IMPRESSIONS,
           SUM(COALESCE(CLICKS,0)) CLICKS,
           SUM(COALESCE(CONVERSIONS,0)) CONVERSIONS,
           SUM(COALESCE(SPONSORS,0)) SPONSORS
    FROM AD_RAW
    GROUP BY 1,2,3,4,5,6,7,8,9,10
),
AD_SOURCE AS (
    SELECT ROW_NUMBER() OVER (
        ORDER BY SOURCE_TYPE, PERFORMANCE_DATE, UPPER_KEY,
                 CAMPAIGN_KEY, MATERIAL_NAME, SOURCE_CHANNEL, AD_TYPE, DATE_SOURCE, SOURCE_CAMPAIGN, UTM_RAW
    ) GROUP_ID, *
    FROM AD_GROUPED
),
AD_CANDIDATES AS (
    SELECT DISTINCT A.GROUP_ID, 0 PRIORITY, T.TARGET_NAME
    FROM AD_SOURCE A
    JOIN CRM_TARGETS T ON T.TARGET_ID=594
    WHERE A.SOURCE_TYPE='REBROADCAST'
      AND A.UPPER_KEY='U0418'
      AND A.MATERIAL_NAME='2024 희망TV 상반기'
      AND UPPER(REPLACE(TRIM(A.SOURCE_CHANNEL),' ',''))
          IN ('SBS','SBSBIZ','SBSFUNE')
      AND A.PERFORMANCE_DATE IN (DATE '2024-05-24',DATE '2024-05-25')
    UNION
    SELECT DISTINCT A.GROUP_ID, 0 PRIORITY, T.TARGET_NAME
    FROM AD_SOURCE A
    JOIN CONFIRMED_BROADCAST_MAP B
      ON A.UPPER_KEY=B.UPPER_KEY
    JOIN CRM_TARGETS T ON T.TARGET_ID=B.TARGET_ID
    WHERE A.SOURCE_TYPE='REBROADCAST'
    UNION
    SELECT DISTINCT A.GROUP_ID, 0 PRIORITY, T.TARGET_NAME
    FROM AD_SOURCE A
    JOIN BROADCAST_NAME_MAP N
      ON REPLACE(TRIM(A.MATERIAL_NAME),' ','')=N.BROADCAST_KEY
    JOIN CRM_TARGETS T ON T.TARGET_ID=N.TARGET_ID
    WHERE A.SOURCE_TYPE='REBROADCAST'
      AND NULLIF(NULLIF(A.UPPER_KEY,''),'-') IS NULL
      AND NULLIF(NULLIF(A.CAMPAIGN_KEY,''),'-') IS NULL
    UNION
    SELECT DISTINCT A.GROUP_ID, 1 PRIORITY, K.TARGET_NAME
    FROM AD_SOURCE A JOIN CRM_LINK_KEYS K
      ON A.UPPER_KEY=K.LINK_KEY
     AND (K.KEY_TYPE='UPPER_CODE'
          OR (A.SOURCE_TYPE='VIDEO' AND K.KEY_TYPE='PARENT_NAME'))
    WHERE A.SOURCE_TYPE IN ('VIDEO','REBROADCAST')
    UNION
    SELECT DISTINCT A.GROUP_ID, 2, K.TARGET_NAME
    FROM AD_SOURCE A JOIN CRM_LINK_KEYS K
      ON A.CAMPAIGN_KEY=K.LINK_KEY AND K.KEY_TYPE='MARKETING_NAME'
    WHERE A.SOURCE_TYPE IN ('VIDEO','REBROADCAST')
    UNION
    SELECT DISTINCT A.GROUP_ID, 2, T.TARGET_NAME
    FROM AD_SOURCE A
    JOIN CAMPAIGN_ALIAS_MAP M ON A.CAMPAIGN_KEY=M.CAMPAIGN_KEY
    JOIN CRM_TARGETS T ON T.TARGET_ID=M.TARGET_ID
    WHERE A.SOURCE_TYPE='VIDEO'
    UNION
    SELECT DISTINCT A.GROUP_ID, 3, T.TARGET_NAME
    FROM AD_SOURCE A
    JOIN MATERIAL_MAP M ON A.MATERIAL_NAME=M.MATERIAL_NAME
    JOIN CRM_TARGETS T ON M.TARGET_ID=T.TARGET_ID
    WHERE A.SOURCE_TYPE='VIDEO' AND A.AD_TYPE='TV'
    UNION
    SELECT DISTINCT A.GROUP_ID, 1, K.TARGET_NAME
    FROM AD_SOURCE A JOIN CRM_LINK_KEYS K
      ON A.CAMPAIGN_KEY=K.LINK_KEY AND K.KEY_TYPE='UTM'
    WHERE A.SOURCE_TYPE='DIGITAL'
    UNION
    SELECT DISTINCT A.GROUP_ID, 4, N.TARGET_NAME
    FROM AD_SOURCE A JOIN DIGITAL_NAME_KEYS N
      ON UPPER(TRIM(A.SOURCE_CAMPAIGN))=N.NAME_KEY
    WHERE A.SOURCE_TYPE='DIGITAL'
),
AD_BEST AS (
    SELECT * FROM AD_CANDIDATES
    QUALIFY PRIORITY=MIN(PRIORITY) OVER (PARTITION BY GROUP_ID)
),
AD_BEST_R AS (
    SELECT B.GROUP_ID, B.PRIORITY, B.TARGET_NAME,
           COALESCE(R.ROLLUP_NAME, B.TARGET_NAME) ROLLED_NAME,
           IFF(BC.CAMPAIGN_NAME IS NOT NULL OR B.TARGET_NAME='24년 이전컨텐츠', 1, 0) IS_BC
    FROM AD_BEST B
    LEFT JOIN CAMPAIGN_ROLLUP R ON B.TARGET_NAME=R.SOURCE_NAME
    LEFT JOIN BROADCAST_CAMPAIGNS BC ON B.TARGET_NAME=BC.CAMPAIGN_NAME
),
COLLAB_PICK AS (
    -- 같은 UTM을 여러 디지털 캠페인이 쓸 때, 원천 캠페인명(CMPGN_NM)이 가리키는 캠페인에 행 단위로 귀속
    SELECT A.GROUP_ID,
           MIN(B.ROLLED_NAME) PICK_ROLLED,
           MIN(B.TARGET_NAME) PICK_LINKED
    FROM AD_SOURCE A
    JOIN AD_BEST_R B ON A.GROUP_ID=B.GROUP_ID
    LEFT JOIN SRC_NAME_ALIAS N ON A.SOURCE_CAMPAIGN=N.SRC_NAME
    WHERE A.SOURCE_TYPE='DIGITAL'
      AND B.IS_BC=0
      AND B.TARGET_NAME=COALESCE(N.TARGET_NAME, A.SOURCE_CAMPAIGN)
    GROUP BY A.GROUP_ID
    HAVING COUNT(DISTINCT B.ROLLED_NAME)=1
),
AD_RESOLUTION AS (
    SELECT GROUP_ID, MIN(PRIORITY) MATCH_PRIORITY,
           COUNT(DISTINCT TARGET_NAME) RAW_TARGET_COUNT,
           COUNT(DISTINCT ROLLED_NAME) ROLLED_COUNT,
           MIN(ROLLED_NAME) ROLLED_SINGLE,
           MIN(TARGET_NAME) LINKED_SINGLE,
           COUNT(DISTINCT IFF(IS_BC=0, ROLLED_NAME, NULL)) NONBC_COUNT,
           MIN(IFF(IS_BC=0, ROLLED_NAME, NULL)) NONBC_ROLLED,
           MIN(IFF(IS_BC=0, TARGET_NAME, NULL)) NONBC_LINKED,
           LISTAGG(DISTINCT TARGET_NAME, ' | ')
               WITHIN GROUP (ORDER BY TARGET_NAME) CANDIDATE_NAMES,
           LISTAGG(DISTINCT IFF(IS_BC=0, ROLLED_NAME, NULL), ' | ')
               WITHIN GROUP (ORDER BY IFF(IS_BC=0, ROLLED_NAME, NULL)) NONBC_NAMES
    FROM AD_BEST_R GROUP BY GROUP_ID
),
AD_AUDIT_BASE AS (
    SELECT A.*, R.MATCH_PRIORITY, R.CANDIDATE_NAMES,
           CASE WHEN A.SOURCE_TYPE='DIGITAL' AND A.CAMPAIGN_KEY IS NULL
                     AND A.SOURCE_CAMPAIGN IN (__COMMON_LIST__) THEN '__COMMON_STATUS__'
                WHEN R.GROUP_ID IS NULL THEN '미연결'
                WHEN R.ROLLED_COUNT=1 THEN '단일 귀속'
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT=1 THEN '단일 귀속'
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT>=2 AND P.GROUP_ID IS NOT NULL THEN '단일 귀속'
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT>=2 THEN '콜라보 공유비'
                ELSE '다중 연결: 귀속 검토' END MAPPING_STATUS,
           CASE WHEN A.SOURCE_TYPE='DIGITAL' AND A.CAMPAIGN_KEY IS NULL
                     AND A.SOURCE_CAMPAIGN IN (__COMMON_LIST__) THEN 0
                WHEN R.GROUP_ID IS NULL THEN 0
                WHEN R.ROLLED_COUNT=1 THEN 1
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT=1 THEN 1
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT>=2 AND P.GROUP_ID IS NOT NULL THEN 1
                ELSE R.ROLLED_COUNT END TARGET_COUNT,
           CASE WHEN A.SOURCE_TYPE='DIGITAL' AND A.CAMPAIGN_KEY IS NULL
                     AND A.SOURCE_CAMPAIGN IN (__COMMON_LIST__) THEN NULL
                WHEN R.ROLLED_COUNT=1 THEN R.ROLLED_SINGLE
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT=1 THEN R.NONBC_ROLLED
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT>=2 AND P.GROUP_ID IS NOT NULL THEN P.PICK_ROLLED
           END TARGET_NAME,
           CASE WHEN A.SOURCE_TYPE='DIGITAL' AND A.CAMPAIGN_KEY IS NULL
                     AND A.SOURCE_CAMPAIGN IN (__COMMON_LIST__) THEN NULL
                WHEN R.RAW_TARGET_COUNT=1 THEN R.LINKED_SINGLE
                WHEN R.ROLLED_COUNT=1 THEN R.CANDIDATE_NAMES
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT=1 THEN R.NONBC_LINKED
                WHEN A.SOURCE_TYPE='DIGITAL' AND R.NONBC_COUNT>=2 AND P.GROUP_ID IS NOT NULL THEN P.PICK_LINKED
           END LINKED_TARGET_NAME,
           IFF(A.SOURCE_TYPE='DIGITAL' AND R.ROLLED_COUNT>1 AND R.NONBC_COUNT>=2, R.NONBC_NAMES, NULL) COLLAB_CAMPAIGNS,
           CASE WHEN A.SOURCE_TYPE<>'DIGITAL' THEN NULL
                WHEN R.MATCH_PRIORITY=4 THEN '원천 캠페인명 연결'
                WHEN COALESCE(R.ROLLED_COUNT,0)<=1 THEN NULL
                WHEN R.NONBC_COUNT=1 THEN '방송 UTM 공유 정리'
                WHEN R.NONBC_COUNT>=2 AND P.GROUP_ID IS NOT NULL THEN '콜라보 UTM: 원천 캠페인명 귀속'
                WHEN R.NONBC_COUNT>=2 THEN '콜라보 UTM: 미분리'
           END DIGITAL_RESOLVE,
           CASE WHEN A.PERFORMANCE_DATE IS NULL THEN '날짜 없음'
                WHEN A.PERFORMANCE_DATE=DATE '1970-01-01' THEN '1970년 날짜: 확인 필요'
                WHEN A.PERFORMANCE_DATE>CURRENT_DATE() THEN '미래 날짜: 실적 여부 확인'
                ELSE '기간 실적 반영 가능' END DATE_STATUS
    FROM AD_SOURCE A
    LEFT JOIN AD_RESOLUTION R ON A.GROUP_ID=R.GROUP_ID
    LEFT JOIN COLLAB_PICK P ON A.GROUP_ID=P.GROUP_ID
),
AD_AUDIT AS (
    SELECT B.*,
           CASE WHEN B.TARGET_COUNT<>1 THEN NULL
                WHEN B.LINKED_TARGET_NAME IS NOT NULL AND B.LINKED_TARGET_NAME<>B.TARGET_NAME THEN '통합 매핑'
                WHEN BC.CAMPAIGN_NAME IS NOT NULL THEN '원방송 직접'
                ELSE '통합 미지정(개별 유지)' END ROLLUP_STATUS,
           IFF(B.TARGET_COUNT=1 AND BC.CAMPAIGN_NAME IS NULL, X.BROADCAST_CANDIDATES, NULL) UTM_BROADCAST_HINT
    FROM AD_AUDIT_BASE B
    LEFT JOIN BROADCAST_CAMPAIGNS BC ON B.TARGET_NAME=BC.CAMPAIGN_NAME
    LEFT JOIN BROADCAST_REDIRECT X ON B.TARGET_NAME=X.SOURCE_NAME
),
AD_CH AS (
    SELECT B.*,
           COALESCE(AL.CH_NAME, K.CH_NAME, NULLIF(TRIM(B.SOURCE_CHANNEL),''), '미상') AD_CHANNEL,
           IFF(AL.CH_NAME IS NOT NULL OR K.CH_NAME IS NOT NULL, 1, 0) CH_MATCHED
    FROM AD_AUDIT B
    LEFT JOIN CHANNEL_ALIAS AL ON UPPER(REPLACE(TRIM(B.SOURCE_CHANNEL),' ',''))=AL.SRC_KEY
    LEFT JOIN CRM_CHANNEL_KEYS K ON UPPER(REPLACE(TRIM(B.SOURCE_CHANNEL),' ',''))=K.CH_KEY
),
D_COST AS (
    SELECT PERFORMANCE_DATE, TARGET_NAME MKTG_CAMPAIGN_NM,
           COALESCE(LINKED_TARGET_NAME, TARGET_NAME) COMPONENT_NM, AD_CHANNEL,
           SUM(SOURCE_COST) DIGITAL_AD_COST
    FROM AD_CH
    WHERE SOURCE_TYPE='DIGITAL' AND TARGET_COUNT=1
      AND DATE_STATUS='기간 실적 반영 가능'
    GROUP BY 1,2,3,4
),
V_COST AS (
    SELECT PERFORMANCE_DATE, TARGET_NAME MKTG_CAMPAIGN_NM,
           COALESCE(LINKED_TARGET_NAME, TARGET_NAME) COMPONENT_NM, AD_CHANNEL,
           SUM(SOURCE_COST) VIDEO_AD_COST
    FROM AD_CH
    WHERE SOURCE_TYPE='VIDEO' AND TARGET_COUNT=1
      AND DATE_STATUS='기간 실적 반영 가능'
    GROUP BY 1,2,3,4
),
R_COST AS (
    SELECT PERFORMANCE_DATE, TARGET_NAME MKTG_CAMPAIGN_NM,
           COALESCE(LINKED_TARGET_NAME, TARGET_NAME) COMPONENT_NM, AD_CHANNEL,
           SUM(SOURCE_COST) REBROADCAST_AD_COST
    FROM AD_CH
    WHERE SOURCE_TYPE='REBROADCAST' AND TARGET_COUNT=1
      AND DATE_STATUS='기간 실적 반영 가능'
    GROUP BY 1,2,3,4
),
"""

_AD_MAPPING_PART2 = (
    _AD_MAPPING_PART2
    .replace("__NAME_ALIAS_VALUES__", _NAME_ALIAS_VALUES)
    .replace("__COMMON_LIST__", _COMMON_LIST)
    .replace("__COMMON_STATUS__", COMMON_STATUS)
    .replace("__VIDEO_RESTORE__", _restore_expr("X", ("YEAR", "MONTH", "DAY")))
    .replace("__DIGITAL_BRANCH__", _DIGITAL_BRANCH)
)
_AD_MAPPING_CTES = _AD_MAPPING_PART1 + _ROLLUP_VALUES + _AD_MAPPING_PART2
_AD_COMMON_SQL = _CRM_ERP_CTES + _AD_MAPPING_CTES

# 행 단위 통합 테이블: CRM 개발·ERP 제작비는 캠페인코드 기준 채널·개발인입경로(제작비는 사용부서 팀 포함),
# 광고비는 광고 원천의 채널(디지털 매체·영상/재송출 채널)과, 구성 캠페인에서 그 채널에 해당하는
# CRM 캠페인코드의 개발인입경로를 가집니다.
INTEGRATED_SQL = _AD_COMMON_SQL + """
ROWS_ALL AS (
    SELECT D.PERFORMANCE_DATE, COALESCE(R.ROLLUP_NAME, D.MKTG_CAMPAIGN_NM) MK, D.MKTG_CAMPAIGN_NM COMP, 'CRM' ROW_KIND,
           D.CAMPAIGN_TYPE1 T1, D.CAMPAIGN_TYPE2 T2, COALESCE(K.CH_NAME, D.CHANNEL_NAME) CH, D.INFLOW_PATH_NM IP,
           NULL::VARCHAR CODE_STATUS, NULL::VARCHAR TM,
           0::FLOAT PROD, 0::FLOAT DIG, 0::FLOAT VID, 0::FLOAT REB, D.DEVELOPMENT_COUNT::FLOAT DEV
    FROM CRM_DEV D
    LEFT JOIN CAMPAIGN_ROLLUP R ON D.MKTG_CAMPAIGN_NM=R.SOURCE_NAME
    LEFT JOIN CRM_CHANNEL_KEYS K ON UPPER(REPLACE(TRIM(D.CHANNEL_NAME),' ',''))=K.CH_KEY
    UNION ALL
    SELECT E.PERFORMANCE_DATE, COALESCE(R.ROLLUP_NAME, E.MKTG_CAMPAIGN_NM), E.MKTG_CAMPAIGN_NM, 'ERP',
           E.CAMPAIGN_TYPE1, E.CAMPAIGN_TYPE2, COALESCE(K.CH_NAME, E.CHANNEL_NAME), E.INFLOW_PATH_NM,
           NULL::VARCHAR, E.TEAM_NAME,
           E.PRODUCTION_COST::FLOAT, 0, 0, 0, 0
    FROM ERP E
    LEFT JOIN CAMPAIGN_ROLLUP R ON E.MKTG_CAMPAIGN_NM=R.SOURCE_NAME
    LEFT JOIN CRM_CHANNEL_KEYS K ON UPPER(REPLACE(TRIM(E.CHANNEL_NAME),' ',''))=K.CH_KEY
    UNION ALL
    SELECT A.PERFORMANCE_DATE, A.MKTG_CAMPAIGN_NM, A.COMPONENT_NM, 'AD',
           COALESCE(CC.CAMPAIGN_TYPE1, X.CAMPAIGN_TYPE1), COALESCE(CC.CAMPAIGN_TYPE2, X.CAMPAIGN_TYPE2),
           A.AD_CHANNEL, COALESCE(CC.INFLOW_PATH_NM, X.INFLOW_PATH_NM),
           IFF(CC.MKTG_CAMPAIGN_NM IS NULL, '채널 CRM 코드 없음', '채널 CRM 코드 있음'), NULL::VARCHAR,
           0, A.DIG, A.VID, A.REB, 0
    FROM (
        SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM, COMPONENT_NM, AD_CHANNEL,
               DIGITAL_AD_COST::FLOAT DIG, 0::FLOAT VID, 0::FLOAT REB FROM D_COST
        UNION ALL
        SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM, COMPONENT_NM, AD_CHANNEL,
               0, VIDEO_AD_COST::FLOAT, 0 FROM V_COST
        UNION ALL
        SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM, COMPONENT_NM, AD_CHANNEL,
               0, 0, REBROADCAST_AD_COST::FLOAT FROM R_COST
    ) A
    LEFT JOIN CAMPAIGN_DIM X ON A.COMPONENT_NM=X.MKTG_CAMPAIGN_NM
    LEFT JOIN CAMP_CH_DIM CC ON A.COMPONENT_NM=CC.MKTG_CAMPAIGN_NM
                            AND UPPER(REPLACE(TRIM(A.AD_CHANNEL),' ',''))=CC.CH_KEY
)
SELECT PERFORMANCE_DATE,
       MK MARKETING_CAMPAIGN_NAME,
       COMP COMPONENT_CAMPAIGN_NAME,
       ROW_KIND,
       COALESCE(T1,'미분류') CAMPAIGN_TYPE1,
       COALESCE(T2,'미분류') CAMPAIGN_TYPE2,
       COALESCE(CH,'미분류') CHANNEL_NAME,
       COALESCE(IP,'미분류') DEVELOPMENT_INFLOW_PATH,
       CODE_STATUS CHANNEL_CODE_STATUS,
       TM TEAM_NAME,
       SUM(PROD) PRODUCTION_COST,
       SUM(DIG) DIGITAL_AD_COST,
       SUM(VID) VIDEO_AD_COST,
       SUM(REB) REBROADCAST_AD_COST,
       SUM(DIG+VID+REB) AD_COST,
       SUM(PROD+DIG+VID+REB) TOTAL_COST,
       SUM(DEV) DEVELOPMENT_COUNT
FROM ROWS_ALL
WHERE PERFORMANCE_DATE IS NOT NULL AND MK IS NOT NULL
GROUP BY 1,2,3,4,5,6,7,8,9,10
HAVING SUM(DEV)<>0 OR SUM(PROD+DIG+VID+REB)<>0
"""

AD_MAPPING_AUDIT_SQL = _AD_COMMON_SQL.rstrip().rstrip(",") + """
SELECT * FROM AD_CH ORDER BY SOURCE_TYPE, ABS(SOURCE_COST) DESC
"""

AD_DETAIL_SQL = _AD_COMMON_SQL.rstrip().rstrip(",") + """
SELECT PERFORMANCE_DATE,
       SOURCE_TYPE,
       IFF(TARGET_COUNT=1, TARGET_NAME, NULL) MARKETING_CAMPAIGN_NAME,
       IFF(TARGET_COUNT=1, COALESCE(LINKED_TARGET_NAME, TARGET_NAME), NULL) COMPONENT_CAMPAIGN_NAME,
       AD_CHANNEL CHANNEL,
       MAPPING_STATUS,
       COLLAB_CAMPAIGNS,
       IFF(SOURCE_TYPE='DIGITAL', COALESCE(CAMPAIGN_KEY,'[UTM 없음]'), NULL) UTM_KEY,
       IFF(SOURCE_TYPE='DIGITAL', COALESCE(UTM_RAW,'[UTM 없음]'), NULL) UTM_RAW,
       SOURCE_CAMPAIGN,
       IFF(SOURCE_TYPE='REBROADCAST', AD_TYPE, NULL) REBRDC_DIV,
       SUM(SOURCE_COST) COST,
       SUM(SOURCE_ROW_COUNT) SOURCE_ROWS,
       SUM(IMPRESSIONS) IMPRESSIONS,
       SUM(CLICKS) CLICKS,
       SUM(CONVERSIONS) CONVERSIONS,
       SUM(SPONSORS) SPONSORS
FROM AD_CH
WHERE DATE_STATUS='기간 실적 반영 가능'
  AND (TARGET_COUNT=1 OR SOURCE_TYPE='DIGITAL')
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
"""

CRM_NAMES_SQL = """
SELECT DISTINCT TRIM(MK_CMPGN_NM) CAMPAIGN_NAME
FROM GN_DW.SILVER.CRM_CAMPAIGN
WHERE NULLIF(TRIM(MK_CMPGN_NM),'') IS NOT NULL
"""

# 방송 통합 후보: 방송·재송출 캠페인과 UTM을 공유하는 디지털 캠페인과, 공유하는 방송 캠페인 목록 (ROLLUP_CANDIDATE_QUERY)
ROLLUP_CANDIDATE_SQL = """
-- ROLLUP_CANDIDATE_QUERY
WITH BASE AS (
    SELECT NULLIF(TRIM(MK_CMPGN_NM),'') CAMPAIGN_NAME,
           NULLIF(TRIM(MBER_INFLOW_PATH_NM),'') INFLOW,
           NULLIF(TRIM(MKTG_UTM_NM),'') UTM_LIST
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE NULLIF(TRIM(CMPGN_CD),'') IS NOT NULL
      AND NULLIF(TRIM(MK_CMPGN_NM),'') IS NOT NULL
),
BC AS (
    SELECT DISTINCT CAMPAIGN_NAME FROM BASE
    WHERE INFLOW IN ('방송','재송출') AND CAMPAIGN_NAME <> '24년 이전컨텐츠'
),
U AS (
    SELECT DISTINCT B.CAMPAIGN_NAME, UPPER(TRIM(S.VALUE)) UTM
    FROM BASE B, LATERAL SPLIT_TO_TABLE(B.UTM_LIST, ',') S
    WHERE B.UTM_LIST IS NOT NULL
      AND NULLIF(TRIM(S.VALUE),'') IS NOT NULL
      AND TRIM(S.VALUE) <> '-'
)
SELECT D.CAMPAIGN_NAME SOURCE_NAME,
       LISTAGG(DISTINCT B.CAMPAIGN_NAME, ' | ') WITHIN GROUP (ORDER BY B.CAMPAIGN_NAME) BROADCAST_CANDIDATES
FROM U D
JOIN U B ON D.UTM=B.UTM AND D.CAMPAIGN_NAME<>B.CAMPAIGN_NAME
JOIN BC ON BC.CAMPAIGN_NAME=B.CAMPAIGN_NAME
WHERE D.CAMPAIGN_NAME NOT IN (SELECT CAMPAIGN_NAME FROM BC)
GROUP BY D.CAMPAIGN_NAME
"""

MEMBER_SQL = """
SELECT TO_DATE(f.STRD_MT || '01','YYYYMMDD') PERFORMANCE_MONTH,
       c.MK_CMPGN_NM MARKETING_CAMPAIGN_NAME,
       COALESCE(c.CMPGN_TYPE1_NM,'미분류') CAMPAIGN_TYPE1,
       COALESCE(c.CMPGN_TYPE2_NM,'미분류') CAMPAIGN_TYPE2,
       COALESCE(c.MKTG_CHANNEL_NM,'미분류') CHANNEL_NAME,
       COALESCE(c.MBER_INFLOW_PATH_NM,'미분류') DEVELOPMENT_INFLOW_PATH,
       COALESCE(cd_pm.DTL_CD_NM,'기타/미지정') PAYMENT_METHOD,
       COALESCE(cd_sex.DTL_CD_NM,'기타/미상') SEX_NAME,
       COALESCE(cd_age.DTL_CD_NM,'기타/미상') AGE_BAND,
       COALESCE(cd_dvlp.DTL_CD_NM,'기타/미지정') DEVELOPMENT_TYPE,
       d.DEPT_NM DEPARTMENT_NAME,
       COALESCE(b.BRND_NM,'미분류') BRAND_NAME,
       IFF(d.DEPT_NM='매체운영팀' AND b.BRND_NM IN ('PC광고마케팅','M광고마케팅'),'광고','오가닉') AD_ORGANIC,
       SUM(COALESCE(f.SPNSR_AMT_CNT,0)) DEVELOPMENT_COUNT
FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM f
LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN c ON f.CMPGN_CD=c.CMPGN_CD
JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO d ON f.ACMSLT_DEPT_CD=d.DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_BRND_MNG b ON f.BRND_ID=b.BRND_ID
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD cd_pm ON cd_pm.CD_ID='PM040' AND f.SETLE_CD=cd_pm.DTL_CD_ID
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD cd_sex ON cd_sex.CD_ID='CM013' AND f.SEX=cd_sex.DTL_CD_ID
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD cd_age ON cd_age.CD_ID='CM014' AND f.AGE_TERM_CD=cd_age.DTL_CD_ID
LEFT JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD cd_dvlp ON cd_dvlp.CD_ID='MM015' AND f.DVLP_DIV_CD=cd_dvlp.DTL_CD_ID
WHERE f.STRD_MT>='202401' AND f.DVLP_DIV_CD IN ('1','2','4') AND c.MK_CMPGN_NM IS NOT NULL
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
"""

# 팀별 개발건수(07 탭): 월별 회원개발 요약을 캠페인 연결 여부와 상관없이 모두 포함합니다.
# 캠페인 테이블에 마케팅캠페인명이 없는 코드는 '[캠페인 미연결]'로 두고, 캠페인코드가 중복 등록돼도 건수가 늘지 않도록 코드당 1행으로 정리해 붙입니다.
TEAM_DEV_SQL = """
WITH CAMP AS (
    SELECT UPPER(TRIM(CMPGN_CD)) CODE_KEY,
           MIN(NULLIF(TRIM(MK_CMPGN_NM),'')) MK_CMPGN_NM,
           MIN(COALESCE(NULLIF(TRIM(CMPGN_TYPE1_NM),''),'미분류')) CAMPAIGN_TYPE1,
           MIN(COALESCE(NULLIF(TRIM(CMPGN_TYPE2_NM),''),'미분류')) CAMPAIGN_TYPE2,
           MIN(COALESCE(NULLIF(TRIM(MKTG_CHANNEL_NM),''),'미분류')) CHANNEL_NAME,
           MIN(COALESCE(NULLIF(TRIM(MBER_INFLOW_PATH_NM),''),'미분류')) INFLOW_PATH
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    GROUP BY 1
)
SELECT TO_DATE(f.STRD_MT || '01','YYYYMMDD') PERFORMANCE_MONTH,
       COALESCE(C.MK_CMPGN_NM,'[캠페인 미연결]') MARKETING_CAMPAIGN_NAME,
       COALESCE(C.CAMPAIGN_TYPE1,'미분류') CAMPAIGN_TYPE1,
       COALESCE(C.CAMPAIGN_TYPE2,'미분류') CAMPAIGN_TYPE2,
       COALESCE(C.CHANNEL_NAME,'미분류') CHANNEL_NAME,
       COALESCE(C.INFLOW_PATH,'미분류') DEVELOPMENT_INFLOW_PATH,
       TRIM(d.DEPT_NM) DEPARTMENT_NAME,
       SUM(COALESCE(f.SPNSR_AMT_CNT,0)) DEVELOPMENT_COUNT
FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM f
JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO d ON f.ACMSLT_DEPT_CD=d.DEPT_ID
LEFT JOIN CAMP C ON UPPER(TRIM(f.CMPGN_CD))=C.CODE_KEY
WHERE f.STRD_MT>='202401' AND f.DVLP_DIV_CD IN ('1','2','4')
  AND TRIM(d.DEPT_NM) IN (__TEAM_LIST__)
GROUP BY 1,2,3,4,5,6,7
""".replace("__TEAM_LIST__", _TEAM_LIST)

# 회원개발 목표(07 탭): 팀 x 개발인입경로(DTL_DIV_NM) x 월. 법인(사단·사복)은 합산하고, 예산 구분(연사업·추가경정 등)은 구분해서 가져옵니다.
GOAL_SQL = """
SELECT TRIM(YEAR) GOAL_YEAR,
       TRIM(BDGT_PRCD_NM) BDGT_PRCD_NM,
       TRIM(TEAM_NM) TEAM_NM,
       TRIM(DTL_DIV_NM) INFLOW,
       SUM(COALESCE(M01_GOAL_CNT,0)) M01, SUM(COALESCE(M02_GOAL_CNT,0)) M02,
       SUM(COALESCE(M03_GOAL_CNT,0)) M03, SUM(COALESCE(M04_GOAL_CNT,0)) M04,
       SUM(COALESCE(M05_GOAL_CNT,0)) M05, SUM(COALESCE(M06_GOAL_CNT,0)) M06,
       SUM(COALESCE(M07_GOAL_CNT,0)) M07, SUM(COALESCE(M08_GOAL_CNT,0)) M08,
       SUM(COALESCE(M09_GOAL_CNT,0)) M09, SUM(COALESCE(M10_GOAL_CNT,0)) M10,
       SUM(COALESCE(M11_GOAL_CNT,0)) M11, SUM(COALESCE(M12_GOAL_CNT,0)) M12
FROM GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV
WHERE TRIM(GOAL_TYPE_NM)='__GOAL_TYPE__'
  AND TRIM(TEAM_NM) IN (__TEAM_LIST__)
GROUP BY 1,2,3,4
""".replace("__GOAL_TYPE__", _sql_text(GOAL_TYPE_NAME)).replace("__TEAM_LIST__", _TEAM_LIST)

GA_SQL = """
WITH MAP AS (
    SELECT UPPER(TRIM(MKTG_UTM_NM)) K,MIN(MK_CMPGN_NM) MARKETING_CAMPAIGN_NAME
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE MKTG_UTM_NM IS NOT NULL AND TRIM(MKTG_UTM_NM) NOT IN ('','-')
    GROUP BY 1 HAVING COUNT(DISTINCT MK_CMPGN_NM)=1
), BASE AS (
    SELECT TO_DATE(A.DATE) PERFORMANCE_DATE,M.MARKETING_CAMPAIGN_NAME,
           COALESCE(A.AD_TY_NM,'미분류') AD_TYPE,COALESCE(A.MEDIA_NM,'미분류') MEDIA_NAME,
           COALESCE(A.CMPGN_NM,'미분류') GA_CAMPAIGN_NAME,
           SUM(COALESCE(A.LAST_STMT_AMT,0)) SETTLE_AMOUNT,
           SUM(COALESCE(A.CONV_VU_CNT,0)) CONVERSION_VALUE,
           SUM(COALESCE(A.SPNSER_MBER_CNT,0)) SPONSOR_COUNT,
           SUM(COALESCE(A.CLICK_CNT,0)) CLICK_COUNT,
           SUM(COALESCE(A.EXPS_CNT,0)) IMPRESSION_COUNT
    FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS A
    JOIN MAP M ON UPPER(TRIM(A.UTM_CMPGN_NM))=M.K
    WHERE A.DATE IS NOT NULL GROUP BY 1,2,3,4,5
)
SELECT *,DIV0(CLICK_COUNT,IMPRESSION_COUNT) GA_CTR,
         DIV0(SPONSOR_COUNT,CLICK_COUNT) GA_CVR,
         DIV0(SETTLE_AMOUNT,CONVERSION_VALUE) GA_UNIT_COST
FROM BASE
"""


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_integrated(sql=INTEGRATED_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_members(sql=MEMBER_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_team_dev(sql=TEAM_DEV_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_goals(sql=GOAL_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_rollup_candidates(sql=ROLLUP_CANDIDATE_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_ga(sql=GA_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_ad_detail(sql=AD_DETAIL_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_ad_mapping_audit(sql=AD_MAPPING_AUDIT_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


@st.cache_data(ttl=CACHE_TTL, show_spinner=False)
def load_crm_names(sql=CRM_NAMES_SQL):
    return conn.query(sql, ttl=CACHE_TTL)


SOURCE_LABEL = {"DIGITAL": "디지털", "VIDEO": "영상광고", "REBROADCAST": "재송출"}
SOURCE_ORDER = ["DIGITAL", "VIDEO", "REBROADCAST"]
PCT_COLUMNS = {"CTR", "CVR(후원자/클릭)", "비중", "GA_CTR", "GA_CVR"}


def show_df(df, **kwargs):
    """표를 천 단위 구분 기호(,)와 소수점 반올림(정수)으로 표시합니다. 비율 열(CTR·CVR·비중)은 %로 표시합니다."""
    if not isinstance(df, pd.DataFrame) or df.empty:
        st.dataframe(df, **kwargs)
        return
    df = df.reset_index(drop=True)
    if df.columns.duplicated().any():
        st.dataframe(df, **kwargs)
        return
    num_cols = [c for c in df.columns
                if pd.api.types.is_numeric_dtype(df[c]) and not pd.api.types.is_bool_dtype(df[c])]
    date_cols = [c for c in df.columns if pd.api.types.is_datetime64_any_dtype(df[c])]
    fmt = {c: ("{:.2%}" if c in PCT_COLUMNS else "{:,.0f}") for c in num_cols}
    for c in date_cols:
        fmt[c] = lambda v: "-" if pd.isna(v) else v.strftime("%Y-%m-%d")
    if fmt and df.shape[0] * df.shape[1] <= 1_200_000:
        try:
            st.dataframe(df.style.format(fmt, na_rep="-"), **kwargs)
            return
        except Exception:
            pass
    out = df.copy()
    for c in num_cols:
        if c not in PCT_COLUMNS:
            out[c] = out[c].round(0)
    st.dataframe(out, **kwargs)


def split_bar(text):
    return [x.strip() for x in str(text or "").split(" | ") if x.strip()]


def join_variants(values):
    vals = sorted({str(v) for v in values.dropna() if str(v).strip()})
    return " / ".join(vals) if vals else "[UTM 없음]"


def md_safe(text):
    """마크다운에서 밑줄·별표 등이 서식으로 해석되지 않도록 이스케이프합니다."""
    s = str(text)
    for ch in ["\\", "_", "*", "~", "$", "\x60"]:
        s = s.replace(ch, "\\" + ch)
    return s


def last_closed_month(ts):
    """기준일(ts)까지 마감된 마지막 달: ts가 그 달의 말일이면 그 달, 아니면 직전 달(1월이면 1)."""
    ts = pd.Timestamp(ts)
    if (ts + pd.Timedelta(days=1)).month != ts.month:
        return ts.month
    return max(ts.month - 1, 1)


def build_auto_rollup(cand_df, manual_map):
    """방송 캠페인과 UTM을 공유하는 디지털 캠페인을 그 방송 캠페인으로 자동 통합합니다.
    - 공유하는 방송 캠페인이 하나로 정해지면(지정 통합표 적용 후 기준) 자동 통합 대상(auto)
    - 둘 이상이면 어느 쪽인지 알 수 없어 통합하지 않고 확인용(ambiguous)으로만 남깁니다.
    - 이미 지정 통합표에 있는 캠페인, SCATTER_EXCLUDE 캠페인은 건드리지 않습니다."""
    auto, ambiguous = {}, {}
    if cand_df is None or len(cand_df) == 0:
        return auto, ambiguous
    for _, r in cand_df.iterrows():
        src = str(r.get("SOURCE_NAME", "") or "").strip()
        if not src or src in manual_map or src in SCATTER_EXCLUDE:
            continue
        targets = sorted({manual_map.get(c, c) for c in split_bar(r.get("BROADCAST_CANDIDATES", ""))
                          if c not in SCATTER_EXCLUDE})
        targets = [t for t in targets if t != src]
        if len(targets) == 1:
            auto[src] = targets[0]
        elif len(targets) > 1:
            ambiguous[src] = targets
    return auto, ambiguous


def won(v):
    return f"{float(v or 0):,.0f}원"


def cnt(v):
    return f"{float(v or 0):,.0f}건"


def pct(v):
    return "-" if pd.isna(v) else f"{float(v)*100:,.2f}%"


def div0(a, b):
    return a / b if b else 0


def show_ad_mapping_audit():
    st.subheader("광고비 연결 및 원방송 귀속 검증")
    st.caption("전체 원천 기준이며 사이드바 필터와 독립적입니다.")
    if not st.checkbox("광고비 연결 점검 조회", key="show_ad_mapping_audit"):
        return

    common = _AD_COMMON_SQL.rstrip().rstrip(",")
    balance_sql = common + """
    , RAW_TOTAL AS (
        SELECT SOURCE_TYPE, COUNT(*) RAW_ROWS,
               SUM(COALESCE(COST,0)) RAW_COST
        FROM AD_RAW GROUP BY 1
    ), AUDIT_TOTAL AS (
        SELECT SOURCE_TYPE, COUNT(*) AUDIT_GROUPS,
               COUNT(DISTINCT GROUP_ID) UNIQUE_GROUPS,
               SUM(SOURCE_ROW_COUNT) AUDIT_ROWS,
               SUM(SOURCE_COST) AUDIT_COST,
               SUM(IFF(TARGET_COUNT=1
                   AND DATE_STATUS='기간 실적 반영 가능',SOURCE_COST,0)) INCLUDED_COST,
               SUM(IFF(TARGET_COUNT=1
                   AND DATE_STATUS='기간 실적 반영 가능',0,SOURCE_COST)) HELD_COST
        FROM AD_AUDIT GROUP BY 1
    )
    SELECT R.SOURCE_TYPE, R.RAW_ROWS, A.AUDIT_ROWS,
           A.AUDIT_ROWS-R.RAW_ROWS ROW_DIFF,
           A.AUDIT_GROUPS-A.UNIQUE_GROUPS DUPLICATE_GROUPS,
           R.RAW_COST, A.AUDIT_COST,
           A.AUDIT_COST-R.RAW_COST COST_DIFF,
           A.INCLUDED_COST, A.HELD_COST,
           A.INCLUDED_COST+A.HELD_COST-R.RAW_COST PARTITION_DIFF
    FROM RAW_TOTAL R LEFT JOIN AUDIT_TOTAL A
      ON R.SOURCE_TYPE=A.SOURCE_TYPE
    ORDER BY R.SOURCE_TYPE
    """
    try:
        audit = load_ad_mapping_audit(AD_MAPPING_AUDIT_SQL).copy()
        balance = conn.query(balance_sql, ttl=CACHE_TTL).copy()
        crm_names = set(load_crm_names(CRM_NAMES_SQL)["CAMPAIGN_NAME"].astype(str).str.strip())
    except Exception as exc:
        st.error("검증 조회에 실패했습니다.")
        st.exception(exc)
        return

    numeric = ["SOURCE_COST", "SOURCE_ROW_COUNT", "COST_NULL_ROWS",
               "TARGET_COUNT", "MATCH_PRIORITY", "NEGATIVE_COST_AMOUNT", "CH_MATCHED"]
    for col in numeric:
        audit[col] = pd.to_numeric(audit[col], errors="coerce")
    if audit.empty:
        st.info("점검할 광고 원천이 없습니다.")
        return

    st.markdown("#### 1. 원천 대비 행 수·금액 보존")
    show_df(balance, use_container_width=True, hide_index=True)
    diff_cols = ["ROW_DIFF", "DUPLICATE_GROUPS", "COST_DIFF", "PARTITION_DIFF"]
    diffs = balance[diff_cols].apply(pd.to_numeric, errors="coerce")
    valid = not balance.empty and diffs.notna().all().all()
    passed = valid and (diffs["ROW_DIFF"] == 0).all() and (diffs["DUPLICATE_GROUPS"] == 0).all()
    passed = passed and (diffs[["COST_DIFF", "PARTITION_DIFF"]].abs() <= 0.01).all().all()
    if passed:
        st.success("원천 대비 행 수 보존, 집계 그룹 중복, 금액 분할 대사가 허용 오차 내에서 일치합니다.")
    else:
        st.warning("행 수·그룹 중복·금액 차이를 확인해주세요. 금액 허용 오차는 0.01원입니다.")
    st.caption("INCLUDED_COST: 캠페인 귀속·기간 실적 반영 / HELD_COST: 공통비·미분리 콜라보·다중 연결·미연결·날짜 검토. 이 검사는 귀속의 업무적 정확성까지 보증하지 않습니다.")

    st.markdown("#### 2. 통합 캠페인 매핑표 확인")
    missing_targets = sorted({t for _, t in CAMPAIGN_ROLLUP if t not in crm_names} | {t for _, t in DIGITAL_NAME_ALIAS if t not in crm_names})
    missing_sources = sorted({s for s, _ in CAMPAIGN_ROLLUP if s not in crm_names})
    if missing_targets or missing_sources:
        if missing_targets:
            st.error("CRM에 없는 귀속 대상 캠페인명: " + " / ".join(missing_targets))
        if missing_sources:
            st.warning("CRM에 없는 개별 캠페인명: " + " / ".join(missing_sources))
    else:
        st.success(f"통합 캠페인 매핑 {len(CAMPAIGN_ROLLUP)}건과 디지털 캠페인명 보정 {len(DIGITAL_NAME_ALIAS)}건의 이름이 모두 CRM에 있습니다.")

    targets = {
        80: "글로벌도네이션쇼W(바르함)",
        98: "글로벌도네이션쇼어게인W(케파,메리)",
    }
    baseline = {80: 1486454955 + 120000021, 98: 2523787228}
    video = audit[audit["SOURCE_TYPE"].eq("VIDEO")].copy()
    assigned = video[video["TARGET_COUNT"].eq(1)].copy()
    selected = assigned[assigned["TARGET_NAME"].isin(targets.values())].copy()

    st.markdown("#### 3. 앞선 소재 매핑 시험과 비교")
    st.caption("비교 범위: TV + 두 연결 키 모두 빈값 또는 '-' + 소재 보완 단일 귀속. 날짜 제한 없이 비교합니다.")

    def blank_key(series):
        return series.fillna("").astype(str).str.strip().isin(["", "-"])

    trial = selected[
        selected["AD_TYPE"].fillna("").eq("TV")
        & selected["MATCH_PRIORITY"].eq(3)
        & blank_key(selected["UPPER_KEY"])
        & blank_key(selected["CAMPAIGN_KEY"])
    ].copy()
    rows = []
    for target_id, name in targets.items():
        subset = trial[trial["TARGET_NAME"].eq(name)]
        amount = float(subset["SOURCE_COST"].sum())
        rows.append({"마케팅캠페인ID": target_id, "원방송캠페인": name,
                     "앞선시험금액": baseline[target_id], "현재동일범위금액": amount,
                     "차액": amount - baseline[target_id],
                     "원천행수": int(subset["SOURCE_ROW_COUNT"].sum())})
    comparison = pd.DataFrame(rows)
    show_df(comparison, use_container_width=True, hide_index=True)
    if comparison["차액"].abs().le(0.01).all():
        st.success("두 캠페인 모두 앞선 소재 매핑 시험 금액과 일치합니다.")
    else:
        st.warning("차액이 있습니다. 원천 갱신·매핑 변경 여부를 확인해주세요.")

    st.markdown("#### 4. 재송출 다중 연결: 원방송 귀속 검토")
    rebroadcast_review = audit[
        audit["SOURCE_TYPE"].eq("REBROADCAST") & audit["TARGET_COUNT"].gt(1)
    ].copy()
    if rebroadcast_review.empty:
        st.info("귀속 검토가 필요한 재송출 다중 연결 자료가 없습니다.")
    else:
        for column in ["UPPER_KEY", "CAMPAIGN_KEY", "MATERIAL_NAME"]:
            rebroadcast_review[column] = (
                rebroadcast_review[column].fillna("").astype(str).str.strip()
                .replace({"": "[빈값]", "-": "[빈값]"})
            )
        rebroadcast_review["방송일"] = pd.to_datetime(rebroadcast_review["PERFORMANCE_DATE"], errors="coerce")
        review_summary = rebroadcast_review.groupby(
            ["UPPER_KEY", "CAMPAIGN_KEY", "MATERIAL_NAME", "CANDIDATE_NAMES", "DATE_STATUS"],
            as_index=False, dropna=False
        ).agg(원천행수=("SOURCE_ROW_COUNT", "sum"),
              최초방송일=("방송일", "min"), 최종방송일=("방송일", "max"),
              순비용=("SOURCE_COST", "sum"))
        for column in ["최초방송일", "최종방송일"]:
            review_summary[column] = review_summary[column].dt.strftime("%Y-%m-%d").fillna("[날짜 없음]")
        show_df(review_summary, use_container_width=True, hide_index=True)

    st.markdown("#### 5. 확인된 원방송 귀속 검증 (재송출)")
    expected = pd.DataFrame([
        {"원천 상위 키": "U0418", "귀속 마케팅 캠페인 ID": 594, "기준 금액": 345419353.7},
        {"원천 상위 키": "U1312", "귀속 마케팅 캠페인 ID": 85, "기준 금액": 323782749},
        {"원천 상위 키": "U1354", "귀속 마케팅 캠페인 ID": 74, "기준 금액": 177243500},
        {"원천 상위 키": "U1439", "귀속 마케팅 캠페인 ID": 213, "기준 금액": 212260400},
    ])
    confirmed = audit[
        audit["SOURCE_TYPE"].eq("REBROADCAST")
        & audit["MATCH_PRIORITY"].eq(0)
        & audit["TARGET_COUNT"].eq(1)
        & audit["UPPER_KEY"].notna()
    ].copy()
    result = confirmed.groupby(["UPPER_KEY", "TARGET_NAME"], as_index=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 귀속금액=("SOURCE_COST", "sum"),
    ).rename(columns={"UPPER_KEY": "원천 상위 키", "TARGET_NAME": "귀속 마케팅 캠페인"})
    result = expected.merge(result, on="원천 상위 키", how="left")
    result["귀속금액"] = result["귀속금액"].fillna(0)
    result["차액"] = result["귀속금액"] - result["기준 금액"]
    show_df(result, use_container_width=True, hide_index=True)

    name_expected = pd.DataFrame([
        {"원천 방송명": "2023 글로벌도네이션쇼W 1부", "기준 금액": 190773749},
        {"원천 방송명": "2023 글로벌도네이션쇼W 2부", "기준 금액": 182554249},
        {"원천 방송명": "2023 글로벌도네이션쇼W 3부", "기준 금액": 179125239},
        {"원천 방송명": "2023 글로벌도네이션쇼W 4부", "기준 금액": 175999999},
        {"원천 방송명": "2023 나누는행복희망플러스 상반기", "기준 금액": 135258450},
        {"원천 방송명": "2023 글로벌도네이션쇼어게인W 1부", "기준 금액": 78802000},
        {"원천 방송명": "2023 글로벌도네이션쇼어게인W 2부", "기준 금액": 55000000},
        {"원천 방송명": "2022 글로벌도네이션쇼W 4부", "기준 금액": 10839750},
    ])
    named = audit[
        audit["SOURCE_TYPE"].eq("REBROADCAST") & audit["MATCH_PRIORITY"].eq(0)
        & audit["TARGET_COUNT"].eq(1) & audit["UPPER_KEY"].isna()
    ].copy()
    named["원천 방송명"] = named["MATERIAL_NAME"].astype(str).str.strip()
    named_result = named.groupby(["원천 방송명", "TARGET_NAME"], as_index=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 귀속금액=("SOURCE_COST", "sum")
    ).rename(columns={"TARGET_NAME": "귀속 마케팅 캠페인"})
    named_result = name_expected.merge(named_result, on="원천 방송명", how="left")
    named_result["귀속금액"] = named_result["귀속금액"].fillna(0)
    named_result["차액"] = named_result["귀속금액"] - named_result["기준 금액"]
    show_df(named_result, use_container_width=True, hide_index=True)
    if result["차액"].abs().le(1).all() and named_result["차액"].abs().le(0.01).all():
        st.success("재송출 확인 귀속 12건 모두 기준 금액과 일치합니다.")
    else:
        st.warning("기준 금액과 차액이 있습니다. 데이터 새로고침 후에도 같으면 원천 갱신 여부를 확인해주세요.")

    st.markdown("#### 6. 원방송 통합 현황 (전체 원천)")
    st.caption("통합 매핑: 개별 캠페인을 통합 캠페인(원방송)으로 모은 비용 / 원방송 직접: 처음부터 원방송에 연결된 비용 / 통합 미지정: 개별 캠페인에 그대로 남은 비용")
    single = audit[audit["TARGET_COUNT"].eq(1)].copy()
    single["원천"] = single["SOURCE_TYPE"].map(SOURCE_LABEL)
    rollup_summary = single.groupby(["원천", "ROLLUP_STATUS"], as_index=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum"))
    show_df(rollup_summary, use_container_width=True, hide_index=True)
    moves = single.groupby(["원천", "ROLLUP_STATUS", "LINKED_TARGET_NAME", "TARGET_NAME", "UTM_BROADCAST_HINT"],
                           as_index=False, dropna=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
    ).rename(columns={"ROLLUP_STATUS": "통합 상태", "LINKED_TARGET_NAME": "연결 캠페인",
                      "TARGET_NAME": "최종 귀속 캠페인", "UTM_BROADCAST_HINT": "UTM 기준 원방송 후보(미반영)"})
    moves = moves.assign(_s=moves["순광고비"].abs()).sort_values(["통합 상태", "_s"], ascending=[True, False]).drop(columns="_s")
    show_df(moves, use_container_width=True, hide_index=True, height=360)
    st.download_button("원방송 통합 상세 CSV 다운로드", moves.to_csv(index=False).encode("utf-8-sig"),
                       file_name="broadcast_rollup_detail.csv", mime="text/csv")

    st.markdown("#### 7. 디지털 콜라보 UTM 귀속 현황")
    st.caption("같은 UTM을 여러 디지털 캠페인이 쓴 경우, 원천 캠페인명(CMPGN_NM)이 가리키는 캠페인에 행 단위로 귀속합니다. 원천 캠페인명으로 구분되지 않는 행만 '미분리'로 남습니다.")
    collab = audit[audit["DIGITAL_RESOLVE"].fillna("").str.startswith("콜라보")].copy()
    if collab.empty:
        st.info("콜라보 UTM 자료가 없습니다.")
    else:
        resolved_amt = collab.loc[collab["DIGITAL_RESOLVE"].eq("콜라보 UTM: 원천 캠페인명 귀속"), "SOURCE_COST"].sum()
        unresolved_amt = collab.loc[collab["DIGITAL_RESOLVE"].eq("콜라보 UTM: 미분리"), "SOURCE_COST"].sum()
        m1, m2 = st.columns(2)
        m1.metric("원천 캠페인명으로 귀속된 금액", f"{resolved_amt:,.0f}원")
        m2.metric("미분리 금액 (캠페인 비용 미포함)", f"{unresolved_amt:,.0f}원")
        collab_summary = collab.groupby(
            ["UTM_RAW", "DIGITAL_RESOLVE", "SOURCE_CAMPAIGN", "LINKED_TARGET_NAME", "TARGET_NAME"],
            as_index=False, dropna=False
        ).agg(원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")).rename(columns={
            "UTM_RAW": "UTM(원천 표기)", "DIGITAL_RESOLVE": "처리", "SOURCE_CAMPAIGN": "원천 캠페인명",
            "LINKED_TARGET_NAME": "귀속 캠페인", "TARGET_NAME": "통합 캠페인"
        }).sort_values("순광고비", ascending=False)
        show_df(collab_summary, use_container_width=True, hide_index=True, height=320)

    st.markdown("#### 8. 디지털 원천 캠페인명 연결 현황")
    st.caption("UTM으로 연결되지 않은 디지털 행을 원천 캠페인명(CMPGN_NM)이 CRM 캠페인명과 같을 때(보정표 포함) 연결한 결과입니다.")
    by_name = audit[audit["DIGITAL_RESOLVE"].eq("원천 캠페인명 연결")].copy()
    if by_name.empty:
        st.info("원천 캠페인명으로 연결된 디지털 자료가 없습니다.")
    else:
        bn = by_name.groupby(["UTM_RAW", "SOURCE_CAMPAIGN", "LINKED_TARGET_NAME", "TARGET_NAME", "MAPPING_STATUS"],
                             as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"UTM_RAW": "UTM(원천 표기)", "SOURCE_CAMPAIGN": "원천 캠페인명",
                          "LINKED_TARGET_NAME": "연결 캠페인", "TARGET_NAME": "통합 캠페인",
                          "MAPPING_STATUS": "귀속 상태"}).sort_values("순광고비", ascending=False)
        st.metric("원천 캠페인명으로 연결된 금액", f"{by_name['SOURCE_COST'].sum():,.0f}원")
        show_df(bn, use_container_width=True, hide_index=True, height=320)

    st.markdown("#### 9. 디지털 공통비 (검색·브랜드·통합·크레딧)")
    st.caption("UTM이 없고 원천 캠페인명이 " + ", ".join(COMMON_COST_NAMES) + "인 행입니다. 캠페인에 배분하지 않고 공통비로 집계합니다.")
    cm_rows = audit[audit["MAPPING_STATUS"].eq(COMMON_STATUS)].copy()
    if cm_rows.empty:
        st.info("공통비 자료가 없습니다.")
    else:
        cms = cm_rows.groupby(["SOURCE_CAMPAIGN", "DATE_SOURCE", "DATE_STATUS"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"SOURCE_CAMPAIGN": "원천 캠페인명", "DATE_SOURCE": "날짜 출처", "DATE_STATUS": "날짜 상태"}).sort_values("순광고비", ascending=False)
        c1, c2 = st.columns(2)
        c1.metric("공통비 합계 (전체 기간)", f"{cm_rows['SOURCE_COST'].sum():,.0f}원")
        c2.metric("기간 집계에서 빠지는 공통비 (날짜 문제)",
                  f"{cm_rows.loc[~cm_rows['DATE_STATUS'].eq('기간 실적 반영 가능'), 'SOURCE_COST'].sum():,.0f}원")
        show_df(cms, use_container_width=True, hide_index=True)

    st.markdown("#### 10. 디지털 다중 연결·미연결")
    remain = audit[audit["SOURCE_TYPE"].eq("DIGITAL") & audit["MAPPING_STATUS"].eq("다중 연결: 귀속 검토")].copy()
    if not remain.empty:
        st.markdown("##### 방송·포괄 캠페인만 후보인 UTM")
        remain_summary = remain.groupby(["UTM_RAW", "CANDIDATE_NAMES"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"UTM_RAW": "UTM(원천 표기)", "CANDIDATE_NAMES": "후보 캠페인"}).sort_values("순광고비", ascending=False)
        show_df(remain_summary, use_container_width=True, hide_index=True, height=260)
    d_un = audit[audit["SOURCE_TYPE"].eq("DIGITAL") & audit["MAPPING_STATUS"].eq("미연결")].copy()
    if d_un.empty:
        st.info("디지털 미연결이 없습니다.")
    else:
        st.markdown("##### 미연결 UTM")
        d_un_summary = d_un.groupby(["UTM_RAW", "SOURCE_CAMPAIGN", "DATE_STATUS"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"UTM_RAW": "UTM(원천 표기)", "SOURCE_CAMPAIGN": "원천 캠페인명", "DATE_STATUS": "날짜 상태"}).sort_values("순광고비", ascending=False)
        st.metric("디지털 미연결 금액", f"{d_un['SOURCE_COST'].sum():,.0f}원")
        show_df(d_un_summary, use_container_width=True, hide_index=True, height=320)
        st.download_button("디지털 미연결 UTM CSV 다운로드", d_un_summary.to_csv(index=False).encode("utf-8-sig"),
                           file_name="digital_unmatched_utm.csv", mime="text/csv")
    dig_all = audit[audit["SOURCE_TYPE"].eq("DIGITAL") & audit["CAMPAIGN_KEY"].notna()]
    variants = dig_all.groupby("CAMPAIGN_KEY")["UTM_RAW"].nunique()
    variants = variants[variants > 1]
    if not variants.empty:
        with st.expander(f"대소문자만 다른 UTM 표기 ({len(variants)}건, 같은 UTM으로 연결됨)"):
            vv = dig_all[dig_all["CAMPAIGN_KEY"].isin(variants.index)].groupby(["CAMPAIGN_KEY", "UTM_RAW"], as_index=False).agg(
                원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
            ).rename(columns={"CAMPAIGN_KEY": "연결 키", "UTM_RAW": "원천 표기"})
            show_df(vv, use_container_width=True, hide_index=True)

    st.markdown("#### 11. 영상광고 소재 보완·미연결")
    mat = audit[audit["SOURCE_TYPE"].eq("VIDEO") & audit["MATCH_PRIORITY"].eq(3) & audit["TARGET_COUNT"].eq(1)].copy()
    if not mat.empty:
        mat_summary = mat.groupby(["MATERIAL_NAME", "LINKED_TARGET_NAME", "TARGET_NAME"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"MATERIAL_NAME": "원천 소재명", "LINKED_TARGET_NAME": "소재 연결 캠페인", "TARGET_NAME": "최종 귀속 캠페인"})
        show_df(mat_summary.sort_values("순광고비", ascending=False), use_container_width=True, hide_index=True, height=300)
    unmatched = audit[audit["SOURCE_TYPE"].eq("VIDEO") & audit["TARGET_COUNT"].eq(0)].copy()
    if not unmatched.empty:
        um = unmatched.groupby(["MATERIAL_NAME", "AD_TYPE"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).sort_values("순광고비", ascending=False)
        with st.expander(f"아직 미연결된 영상광고 소재 ({len(um)}건, {um['순광고비'].sum():,.0f}원)"):
            show_df(um, use_container_width=True, hide_index=True)

    st.markdown("#### 12. 광고 채널 ↔ CRM 채널 대응 확인")
    st.caption("광고 원천 채널(디지털 매체·영상/재송출 채널)을 CRM 채널명과 맞춘 결과입니다. 띄어쓰기·대소문자는 무시하고, 다른 이름은 코드 상단 CHANNEL_ALIAS로 맞춥니다.")
    ch_un = audit[audit["CH_MATCHED"].eq(0) & audit["TARGET_COUNT"].eq(1)].copy()
    if ch_un.empty:
        st.success("캠페인에 귀속된 광고비의 채널이 모두 CRM 채널명과 대응됩니다.")
    else:
        ch_un["원천"] = ch_un["SOURCE_TYPE"].map(SOURCE_LABEL)
        cu = ch_un.groupby(["원천", "SOURCE_CHANNEL"], as_index=False, dropna=False).agg(
            원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
        ).rename(columns={"SOURCE_CHANNEL": "원천 채널명"}).sort_values("순광고비", ascending=False)
        st.metric("CRM 채널과 대응되지 않는 광고비", f"{ch_un['SOURCE_COST'].sum():,.0f}원")
        show_df(cu, use_container_width=True, hide_index=True)

    st.markdown("#### 12-1. 재송출 원천의 구분(DIV_NM) 값")
    st.caption("재송출 원천은 구분이 '방송'이면 방송, '재송출'이면 재송출로 나눕니다. 그 밖의 값이나 빈값이 있으면 '재송출·방송(구분 기타)'로 따로 표시합니다.")
    rb_all = audit[audit["SOURCE_TYPE"].eq("REBROADCAST")].copy()
    rb_all["구분"] = rb_all["AD_TYPE"].fillna("[빈값]")
    rb_div = rb_all.groupby(["구분", "MAPPING_STATUS"], as_index=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
    ).sort_values("순광고비", ascending=False)
    show_df(rb_div, use_container_width=True, hide_index=True)

    st.markdown("#### 13. 날짜 복원 현황 (영상광고·디지털)")
    restore_view = audit[audit["SOURCE_TYPE"].isin(["VIDEO", "DIGITAL"])].copy()
    restore_view["원천"] = restore_view["SOURCE_TYPE"].map(SOURCE_LABEL)
    date_summary = restore_view.groupby(["원천", "DATE_SOURCE", "MAPPING_STATUS", "DATE_STATUS"], as_index=False, dropna=False).agg(
        원천행수=("SOURCE_ROW_COUNT", "sum"), 순광고비=("SOURCE_COST", "sum")
    ).rename(columns={"DATE_SOURCE": "날짜 출처", "MAPPING_STATUS": "귀속 상태", "DATE_STATUS": "날짜 상태"})
    show_df(date_summary, use_container_width=True, hide_index=True)

    st.markdown("#### 14. 전체 연결·날짜 상태 요약")
    summary_all = audit.groupby(
        ["SOURCE_TYPE", "MAPPING_STATUS", "DATE_STATUS"], as_index=False
    ).agg(원천행수=("SOURCE_ROW_COUNT", "sum"),
          금액NULL행수=("COST_NULL_ROWS", "sum"),
          순광고비=("SOURCE_COST", "sum"))
    show_df(summary_all, use_container_width=True, hide_index=True)
    with st.expander("전체 점검 상세"):
        show_df(audit, use_container_width=True, hide_index=True)
    st.caption("GROUP_ID는 조회 내 집계 그룹 번호이며 영구 원천 행 ID가 아닙니다.")


def combine_labels(values):
    return ", ".join(sorted({x.strip() for v in values.dropna().astype(str) for x in v.split(",") if x.strip()})) or "미분류"


def split_options(series):
    return sorted({x.strip() for v in series.dropna().astype(str) for x in v.split(",") if x.strip()})


def multi_filter(df, col, vals):
    if not vals:
        return df
    selected = set(vals)
    return df[df[col].apply(lambda v: bool({x.strip() for x in str(v).split(",") if x.strip()} & selected))]


NUM_INT = ["PRODUCTION_COST", "DIGITAL_AD_COST", "VIDEO_AD_COST", "REBROADCAST_AD_COST", "AD_COST", "TOTAL_COST", "DEVELOPMENT_COUNT"]
LABELS = ["CAMPAIGN_TYPE1", "CAMPAIGN_TYPE2", "CHANNEL_NAME", "DEVELOPMENT_INFLOW_PATH"]


def aggregate_campaigns(df):
    if df.empty:
        return pd.DataFrame(columns=["MARKETING_CAMPAIGN_NAME"] + LABELS + NUM_INT + ["COMPONENT_COUNT", "DEVELOPMENT_UNIT_COST"])
    spec = {c: (c, combine_labels) for c in LABELS}
    spec.update({c: (c, "sum") for c in NUM_INT})
    spec["COMPONENT_COUNT"] = ("COMPONENT_CAMPAIGN_NAME", "nunique")
    g = df.groupby("MARKETING_CAMPAIGN_NAME", as_index=False).agg(**spec)
    g["DEVELOPMENT_UNIT_COST"] = g["TOTAL_COST"].div(g["DEVELOPMENT_COUNT"].replace(0, np.nan)).fillna(0)
    return g



def open_rank_detail(name):
    st.session_state["rank_selected_campaign"] = str(name)


def close_rank_detail():
    st.session_state["rank_selected_campaign"] = None
    st.session_state["rank_pick"] = "선택 안 함"


def clickable_ranking_card(no, title, desc, df, col, formatter, label, key_prefix):
    """캠페인명을 누르면 카드 아래에 상세가 열리는 순위 카드."""
    with st.container(border=True):
        st.markdown(
            f'<div class="rank-head"><span class="rank-badge">{no}</span>'
            f'<span class="rank-heading">{escape(title)}</span></div>'
            f'<div class="rank-desc">{escape(desc)}</div>', unsafe_allow_html=True)
        if df.empty:
            st.caption("조건에 맞는 캠페인이 없습니다.")
        for rank, (_, row) in enumerate(df.iterrows(), 1):
            nm = str(row["MARKETING_CAMPAIGN_NAME"])
            token = sha256(nm.encode("utf-8")).hexdigest()[:12]
            st.button(f"{rank}. {md_safe(nm)}", key=f"rank_{key_prefix}_{token}",
                      on_click=open_rank_detail, args=(nm,), use_container_width=True)
            st.markdown(f'<div class="rank-value">{escape(label)} <b>{escape(formatter(row[col]))}</b></div>',
                        unsafe_allow_html=True)


def select_shared_campaign(name):
    st.session_state["shared_campaign"] = str(name)
    st.session_state["scatter_ver"] = st.session_state.get("scatter_ver", 0) + 1
    st.session_state["pick_campaign"] = "캠페인 선택 안 함"


def ranking_card(title, desc, df, col, formatter, label):
    token_card = sha256(title.encode("utf-8")).hexdigest()[:10]
    with st.container(border=True, height=430, key=f"top5_card_{token_card}"):
        st.markdown(f'<div class="insight-title">{escape(title)}</div><div class="insight-description">{escape(desc)}</div>', unsafe_allow_html=True)
        if df.empty:
            st.caption("조건에 맞는 캠페인이 없습니다.")
        for i, (_, row) in enumerate(df.iterrows(), 1):
            name = str(row["MARKETING_CAMPAIGN_NAME"])
            token = sha256((title + name).encode("utf-8")).hexdigest()[:16]
            rank_col, name_col = st.columns([1, 13], gap="small")
            rank_col.markdown(f'<div class="ranking-number">{i}</div>', unsafe_allow_html=True)
            with name_col:
                st.button(md_safe(name), key=f"rank_link_{token}",
                          on_click=select_shared_campaign, args=(name,), use_container_width=True,
                          help="위쪽 산점도 아래의 캠페인 상세를 이 캠페인으로 바꿉니다.")
                st.markdown(f'<div class="ranking-value">{escape(label)} <b>{escape(formatter(row[col]))}</b></div>', unsafe_allow_html=True)
            st.markdown('<div class="rank-separator"></div>', unsafe_allow_html=True)


def mix_card(df, col, title):
    if df.empty:
        st.markdown(f'<div class="mix-card"><div class="mix-title">{escape(title)}</div>데이터가 없습니다.</div>', unsafe_allow_html=True)
        return
    g = df.groupby(col, as_index=False)["DEVELOPMENT_COUNT"].sum().sort_values("DEVELOPMENT_COUNT", ascending=False)
    total = g["DEVELOPMENT_COUNT"].sum()
    mx = max(g["DEVELOPMENT_COUNT"].max(), 1)
    rows = []
    for _, r in g.head(8).iterrows():
        share = div0(r["DEVELOPMENT_COUNT"], total)
        width = r["DEVELOPMENT_COUNT"] / mx * 100
        rows.append(f'<div class="mix-row"><div class="mix-label"><span>{escape(str(r[col]))}</span><b>{share*100:.1f}% [{r["DEVELOPMENT_COUNT"]:,.0f}건]</b></div><div class="mix-bar"><div class="mix-fill" style="width:{width:.1f}%"></div></div></div>')
    st.markdown(f'<div class="mix-card"><div class="mix-title">{escape(title)}</div>{"".join(rows)}</div>', unsafe_allow_html=True)


def section(no, title, desc):
    st.markdown(f'<div class="section-shell"><span class="section-number">{escape(no)}</span><span class="section-title">{escape(title)}</span><div class="section-desc">{escape(desc)}</div></div>', unsafe_allow_html=True)


def selected_campaign_from_event(event):
    try:
        selected = event.selection.get("campaign_pick", [])
    except (AttributeError, TypeError):
        try:
            selected = event.get("selection", {}).get("campaign_pick", [])
        except (AttributeError, TypeError):
            return None
    if isinstance(selected, dict):
        selected = [selected]
    if not selected:
        return None
    first = selected[0]
    return first.get("MARKETING_CAMPAIGN_NAME") if isinstance(first, dict) else None


# 모든 차트에 공통 적용하는 표현 설정. 집계와 선택 이벤트는 변경하지 않습니다.
CHART_COLORS = ["#89A230", "#5DC6CF", "#F16521", "#C2B49A"]
CHART_NUMBER_EXPR = ("abs(datum.value) >= 100000000 ? format(datum.value / 100000000, ',.1~f') + '억' : "
                     "(abs(datum.value) >= 10000 ? format(datum.value / 10000, ',.1~f') + '만' : format(datum.value, ',.0f'))")
def queue_chart_popup(chart_key, selection_name, field, context):
    state = st.session_state.get(chart_key, {})
    try:
        selection = state.get("selection", {}).get(selection_name, [])
    except AttributeError:
        selection = []
    if isinstance(selection, dict):
        selection = [selection]
    if selection and isinstance(selection[0], dict) and field in selection[0]:
        st.session_state["pending_chart_popup"] = dict(context, value=selection[0][field])


def render_chart(data, spec, **kwargs):
    from copy import deepcopy
    drill = kwargs.pop("drill", None)
    chart = deepcopy(spec)
    if drill:
        field, context = drill
        selection_name = "detail_pick"
        selection = {"name": selection_name, "select": {"type": "point", "fields": [field], "on": "click", "toggle": False, "clear": "dblclick"}}
        if "layer" in chart:
            # 복합 차트의 선택 이벤트는 단일 레이어에만 정의합니다.
            chart["layer"][0]["params"] = [selection]
        else:
            chart["params"] = [selection]
        token = sha256(repr((context, data.to_json(date_format="iso"))).encode("utf-8")).hexdigest()[:16]
        chart_key = "drill_" + token
        kwargs.update(key=chart_key, selection_mode=selection_name,
                      on_select=lambda: queue_chart_popup(chart_key, selection_name, field, context))
    base = {
        "background": "#FFFFFF", "font": "sans-serif", "view": {"stroke": None},
        "axis": {"labelFontSize": 12, "titleFontSize": 13, "labelColor": "#8B7F79",
                 "titleColor": "#556A1F", "gridColor": "#E9EDE5", "gridOpacity": .8,
                 "domain": False, "ticks": False, "labelPadding": 8, "titlePadding": 14,
                 "labelOverlap": "greedy"},
        "legend": {"labelFontSize": 12, "titleFontSize": 12, "labelColor": "#657267",
                   "titleColor": "#556A1F", "symbolType": "circle", "symbolSize": 100,
                   "orient": "bottom", "direction": "horizontal", "title": None,
                   "labelLimit": 240, "columnPadding": 16, "offset": 14},
        "range": {"category": CHART_COLORS},
    }
    for key, value in chart.pop("config", {}).items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            base[key].update(value)
        else:
            base[key] = value
    chart["config"] = base
    chart.setdefault("padding", {"left": 12, "right": 18, "top": 14, "bottom": 8})
    kwargs.pop("width", None)
    kwargs.pop("use_container_width", None)
    return st.vega_lite_chart(data, chart, use_container_width=True, theme=None, **kwargs)


def cost_donut(cost_mix, campaign_name=None):
    if cost_mix["금액"].lt(0).any():
        st.caption("음수 조정액이 있어 비용 구성은 표로 표시합니다.")
        show_df(cost_mix, use_container_width=True, hide_index=True)
        return
    data = cost_mix[cost_mix["금액"] > 0].copy()
    if data.empty:
        st.info("표시할 비용이 없습니다.")
        return
    data["비중"] = data["금액"] / data["금액"].sum()
    spec = {"mark": {"type": "arc", "innerRadius": 72, "outerRadius": 116,
                     "cornerRadius": 3, "padAngle": .018},
            "encoding": {"theta": {"field": "금액", "type": "quantitative"},
                         "color": {"field": "비용 구분", "type": "nominal",
                                   "scale": {"domain": ["제작비", "디지털", "영상광고", "방송·재송출"], "range": CHART_COLORS},
                                   "legend": {"columns": 2}},
                         "tooltip": [{"field": "비용 구분"}, {"field": "금액", "title": "비용(원)", "format": ",.0f"},
                                     {"field": "비중", "format": ".1%"}]}}
    render_chart(data, spec, height=320, drill=("비용 구분", {"kind": "cost", "campaign": campaign_name}))


def cost_comparison_chart(cost):
    names = {"PRODUCTION_COST": "제작비", "DIGITAL_AD_COST": "디지털", "VIDEO_AD_COST": "영상광고", "REBROADCAST_AD_COST": "방송·재송출"}
    data = cost.rename(columns=names).reset_index().melt(id_vars="MARKETING_CAMPAIGN_NAME", value_vars=list(names.values()), var_name="비용 구분", value_name="금액")
    spec = {"mark": {"type": "bar", "cornerRadiusEnd": 3}, "encoding": {
        "y": {"field": "MARKETING_CAMPAIGN_NAME", "type": "nominal", "sort": {"field": "금액", "op": "sum", "order": "descending"}, "title": None, "axis": {"labelLimit": 260}},
        "x": {"field": "금액", "type": "quantitative", "title": "비용(원)", "axis": {"labelExpr": CHART_NUMBER_EXPR}},
        "color": {"field": "비용 구분", "type": "nominal", "scale": {"domain": list(names.values()), "range": CHART_COLORS}},
        "tooltip": [{"field": "MARKETING_CAMPAIGN_NAME", "title": "캠페인"}, {"field": "비용 구분"}, {"field": "금액", "format": ",.0f"}]}}
    render_chart(data, spec, height=max(300, len(cost)*38))


def open_week_chart(wk):
    spec = {"mark": {"type": "line", "strokeWidth": 2.5, "point": {"filled": True, "size": 35}}, "encoding": {
        "x": {"field": "OPEN_WEEK", "type": "quantitative", "title": "집행 시작 후 주차", "axis": {"tickMinStep": 1, "tickCount": 10}},
        "y": {"field": "GA_UNIT_COST", "type": "quantitative", "title": "GA 개발단가(원)", "axis": {"labelExpr": CHART_NUMBER_EXPR}},
        "color": {"field": "MARKETING_CAMPAIGN_NAME", "type": "nominal", "title": "캠페인"},
        "tooltip": [{"field": "MARKETING_CAMPAIGN_NAME", "title": "캠페인"}, {"field": "OPEN_WEEK", "title": "주차"}, {"field": "GA_UNIT_COST", "title": "GA 개발단가(원)", "format": ",.0f"}]}}
    render_chart(wk, spec, height=360)


def monthly_chart(df, height=320, campaign_name=None):
    if df.empty:
        st.info("표시할 월별 데이터가 없습니다.")
        return
    trend = df.assign(MONTH=df["PERFORMANCE_DATE"].dt.to_period("M").astype(str)).groupby("MONTH", as_index=False).agg(TOTAL_COST=("TOTAL_COST", "sum"), DEVELOPMENT_COUNT=("DEVELOPMENT_COUNT", "sum"))
    trend["DEVELOPMENT_UNIT_COST"] = trend["TOTAL_COST"].div(trend["DEVELOPMENT_COUNT"].replace(0, np.nan))
    months = trend["MONTH"].tolist()
    step = max(1, int(np.ceil(len(months)/9)))
    ticks = list(dict.fromkeys(months[::step] + months[-1:]))
    x = {"field": "MONTH", "type": "ordinal", "title": None, "axis": {"values": ticks, "labelAngle": 0, "labelOverlap": "greedy", "grid": False}}
    tips = [{"field": "MONTH", "title": "월"}, {"field": "DEVELOPMENT_COUNT", "title": "개발건수", "format": ",.0f"}, {"field": "DEVELOPMENT_UNIT_COST", "title": "통합 개발단가(원)", "format": ",.0f"}]
    spec = {"layer": [
        {"mark": {"type": "area", "color": "#89A230", "opacity": .23, "interpolate": "linear"}, "encoding": {
            "x": x, "y": {"field": "DEVELOPMENT_COUNT", "type": "quantitative", "title": "개발건수(건)", "axis": {"format": ",.0f", "tickCount": 5, "titleColor": "#89A230"}}, "tooltip": tips}},
        {"mark": {"type": "line", "color": "#685A55", "strokeWidth": 2.5, "interpolate": "linear", "point": {"filled": True, "fill": "#685A55", "stroke": "#FFFFFF", "strokeWidth": 1, "size": 38}}, "encoding": {
            "x": x, "y": {"field": "DEVELOPMENT_UNIT_COST", "type": "quantitative", "title": "통합 개발단가(원/건)", "axis": {"orient": "right", "grid": False, "tickCount": 5, "labelExpr": CHART_NUMBER_EXPR, "titleColor": "#685A55"}}, "tooltip": tips}}
    ], "resolve": {"scale": {"y": "independent"}}}
    st.markdown('<div class="chart-key">● 개발건수: 올리브 면적 · 왼쪽 축　 ● 통합 개발단가: 갈색 선 · 오른쪽 축</div>', unsafe_allow_html=True)
    render_chart(trend, spec, height=height, drill=("MONTH", {"kind": "month", "campaign": campaign_name}))


def digital_metrics(df, group_cols):
    g = df.groupby(group_cols, as_index=False, dropna=False).agg(
        광고비=("COST", "sum"), 노출수=("IMPRESSIONS", "sum"), 클릭수=("CLICKS", "sum"),
        전환가치=("CONVERSIONS", "sum"), 후원자수=("SPONSORS", "sum"),
    )
    g["CTR"] = g["클릭수"].div(g["노출수"].replace(0, np.nan))
    g["CVR(후원자/클릭)"] = g["후원자수"].div(g["클릭수"].replace(0, np.nan))
    g["전환가치당 비용"] = g["광고비"].div(g["전환가치"].replace(0, np.nan))
    return g.sort_values("광고비", ascending=False)


def add_source_group(df):
    """재송출 원천을 구분(REBRDC_DIV)에 따라 방송 / 재송출로 나누는 SOURCE_GROUP 열을 추가합니다."""
    df = df.copy()
    grp = df["SOURCE_TYPE"].astype(str)
    div = df["REBRDC_DIV"].fillna("").astype(str).str.strip()
    rb = grp.eq("REBROADCAST")
    grp = grp.mask(rb & div.eq("방송"), "BROADCAST")
    grp = grp.mask(rb & div.eq("재송출"), "RELAY")
    grp = grp.mask(rb & ~div.isin(["방송", "재송출"]), "REBROADCAST_OTHER")
    df["SOURCE_GROUP"] = grp
    return df


def source_summary_table(rows_df, detail_df):
    """광고 원천별 비용 표: 원천마다 '소계' 줄(광고비·노출·클릭·전환가치 + CRM 개발건수·제작비)과
    그 아래 CRM 개발인입경로별 줄(개발건수·제작비)을 보여줍니다. 광고비는 원천 소계 줄에만 있어 합계가 중복되지 않습니다.
    재송출 원천은 구분에 따라 방송 / 재송출 줄로 나뉩니다."""
    ad = detail_df.groupby("SOURCE_GROUP", as_index=False).agg(
        광고비=("COST", "sum"), 노출수=("IMPRESSIONS", "sum"), 클릭수=("CLICKS", "sum"), 전환가치=("CONVERSIONS", "sum"))
    ad = ad.set_index("SOURCE_GROUP")
    crm = rows_df[rows_df["ROW_KIND"].isin(["CRM", "ERP"])].copy()
    crm["SOURCE_GROUP"] = crm["DEVELOPMENT_INFLOW_PATH"].map(INFLOW_TO_SOURCE).fillna("OTHER")
    ip = crm.groupby(["SOURCE_GROUP", "DEVELOPMENT_INFLOW_PATH"], as_index=False).agg(
        **{"CRM 개발건수": ("DEVELOPMENT_COUNT", "sum"), "제작비": ("PRODUCTION_COST", "sum")})
    cols = ["원천", "CRM 개발인입경로", "광고비", "노출수", "클릭수", "전환가치", "CRM 개발건수", "제작비"]
    rows = []
    totals = {c: 0.0 for c in cols[2:]}
    for code in ["DIGITAL", "VIDEO", "BROADCAST", "RELAY", "REBROADCAST_OTHER", "OTHER"]:
        part = ip[ip["SOURCE_GROUP"].eq(code)].sort_values("CRM 개발건수", ascending=False)
        has_ad = code in ad.index
        if part.empty and not has_ad:
            continue
        label = "광고 원천 없음" if code == "OTHER" else SOURCE_GROUP_LABEL[code]
        sub = {"원천": label, "CRM 개발인입경로": "소계"}
        for c in ["광고비", "노출수", "클릭수", "전환가치"]:
            sub[c] = float(ad.loc[code, c]) if has_ad else 0.0
        sub["CRM 개발건수"] = float(part["CRM 개발건수"].sum())
        sub["제작비"] = float(part["제작비"].sum())
        rows.append(sub)
        for c in cols[2:]:
            totals[c] += sub[c]
        for _, r in part.iterrows():
            rows.append({"원천": "", "CRM 개발인입경로": "  └ " + str(r["DEVELOPMENT_INFLOW_PATH"]),
                         "광고비": np.nan, "노출수": np.nan, "클릭수": np.nan, "전환가치": np.nan,
                         "CRM 개발건수": float(r["CRM 개발건수"]), "제작비": float(r["제작비"])})
    if not rows:
        return pd.DataFrame(columns=cols)
    rows.append({"원천": "합계", "CRM 개발인입경로": "", **totals})
    return pd.DataFrame(rows, columns=cols)


def channel_table_data(rows_df, detail_df):
    """채널별 표 데이터: 개발건수(캠페인코드 채널)와 광고비(광고 원천 채널)를 같은 채널끼리 합칩니다."""
    if rows_df.empty:
        return pd.DataFrame()
    g = rows_df.groupby("CHANNEL_NAME", as_index=False).agg(
        개발건수=("DEVELOPMENT_COUNT", "sum"),
        디지털=("DIGITAL_AD_COST", "sum"), 영상광고=("VIDEO_AD_COST", "sum"), 재송출=("REBROADCAST_AD_COST", "sum"))
    conv = detail_df[detail_df["SOURCE_TYPE"].eq("DIGITAL")].groupby("CHANNEL")["CONVERSIONS"].sum()
    g["전환가치"] = g["CHANNEL_NAME"].map(conv).fillna(0)
    g["소계"] = g["디지털"] + g["영상광고"] + g["재송출"]
    g["CRM 개발단가"] = g["소계"].div(g["개발건수"].replace(0, np.nan))
    g["GA 개발단가"] = g["디지털"].div(g["전환가치"].replace(0, np.nan))
    g["비고"] = np.where(g["개발건수"].eq(0) & g["소계"].ne(0), "광고비만 있음(이 채널 CRM 코드 실적 없음)",
                       np.where(g["소계"].eq(0) & g["개발건수"].ne(0), "광고비 없음", ""))
    g = g.rename(columns={"CHANNEL_NAME": "채널"})
    cols = ["채널", "개발건수", "전환가치", "디지털", "영상광고", "재송출", "소계", "CRM 개발단가", "GA 개발단가", "비고"]
    return g.sort_values(["소계", "개발건수"], ascending=False)[cols].reset_index(drop=True)


def render_channel_grid(g):
    """채널별 성과를 '회원개발 / 총 집행비용 / 개발단가' 묶음 머리글이 있는 표로 보여줍니다."""
    if g.empty:
        st.info("표시할 채널 성과가 없습니다.")
        return

    def n(v):
        return "-" if v is None or pd.isna(v) else f"{v:,.0f}"

    tot = {c: g[c].sum() for c in ["개발건수", "전환가치", "디지털", "영상광고", "재송출", "소계"]}
    tot["CRM 개발단가"] = div0(tot["소계"], tot["개발건수"]) or np.nan
    tot["GA 개발단가"] = div0(tot["디지털"], tot["전환가치"]) or np.nan
    head = (
        '<thead><tr><th rowspan="2">채널</th><th colspan="2">회원개발(건)</th>'
        '<th colspan="4">총 집행비용</th><th colspan="2">개발단가</th><th rowspan="2">비고</th></tr>'
        '<tr><th>개발건수</th><th>전환가치</th><th>디지털</th><th>영상광고</th><th>재송출</th><th>소계</th>'
        '<th>CRM 개발단가</th><th>GA 개발단가</th></tr></thead>'
    )
    body = []
    for _, r in g.iterrows():
        body.append(
            f'<tr><td class="txt">{escape(str(r["채널"]))}</td>'
            + "".join(f'<td class="num">{n(r[c])}</td>' for c in ["개발건수", "전환가치", "디지털", "영상광고", "재송출", "소계", "CRM 개발단가", "GA 개발단가"])
            + f'<td class="note">{escape(str(r["비고"]))}</td></tr>'
        )
    body.append(
        '<tr class="total"><td class="txt">합계</td>'
        + "".join(f'<td class="num">{n(tot[c])}</td>' for c in ["개발건수", "전환가치", "디지털", "영상광고", "재송출", "소계", "CRM 개발단가", "GA 개발단가"])
        + '<td class="note"></td></tr>'
    )
    st.markdown(f'<div class="grid-wrap"><table class="grid-table">{head}<tbody>{"".join(body)}</tbody></table></div>', unsafe_allow_html=True)


# ------------------------------------------------------------------
# 팀 기준 보기
# ------------------------------------------------------------------
def derive_broadcast_team_map(member_df):
    """원방송(통합 캠페인)별 담당 팀: 방송 개발건수가 많은 팀(마케팅기획1팀/2팀)으로 자동 지정하고,
    BROADCAST_TEAM_OVERRIDE에 적은 캠페인은 직접 지정을 우선합니다."""
    cols = ["캠페인", "마케팅기획1팀 개발건수", "마케팅기획2팀 개발건수", "담당 팀", "지정 근거"]
    base = member_df[member_df["DEPARTMENT_NAME"].isin(BROADCAST_TEAMS)]
    found = {}
    for label, inflows in [("방송 개발건수가 많은 팀", ["방송"]), ("방송·뉴미디어 개발건수가 많은 팀", ["방송", "뉴미디어"])]:
        part = base[base["DEVELOPMENT_INFLOW_PATH"].isin(inflows)]
        if part.empty:
            continue
        g = part.groupby(["MARKETING_CAMPAIGN_NAME", "DEPARTMENT_NAME"])["DEVELOPMENT_COUNT"].sum().unstack(fill_value=0)
        for camp, r in g.iterrows():
            if camp in found:
                continue
            a = float(r.get("마케팅기획1팀", 0))
            b = float(r.get("마케팅기획2팀", 0))
            if a == 0 and b == 0:
                continue
            team = "마케팅기획1팀" if a > b else ("마케팅기획2팀" if b > a else UNASSIGNED_TEAM)
            found[camp] = (a, b, team, label if team != UNASSIGNED_TEAM else "두 팀 동률")
    for camp, team in BROADCAST_TEAM_OVERRIDE.items():
        a, b = (found[camp][0], found[camp][1]) if camp in found else (0.0, 0.0)
        found[camp] = (a, b, team, "직접 지정")
    if not found:
        return pd.DataFrame(columns=cols)
    out = pd.DataFrame([(c, *v) for c, v in found.items()], columns=cols)
    out["_s"] = out["마케팅기획1팀 개발건수"] + out["마케팅기획2팀 개발건수"]
    return out.sort_values("_s", ascending=False).drop(columns="_s").reset_index(drop=True)


def assign_ad_team(ad_df, bt_map):
    """광고비 행에 팀(TEAM)과 개발인입경로(INFLOW)를 붙입니다. 디지털·영상광고·재송출=매체운영팀, 방송=원방송 담당 팀."""
    out = ad_df.copy()
    team = out["SOURCE_GROUP"].map(AD_SOURCE_TEAM)
    is_b = out["SOURCE_GROUP"].eq("BROADCAST")
    team = team.where(~is_b, out["MARKETING_CAMPAIGN_NAME"].map(bt_map))
    out["TEAM"] = team.fillna(UNASSIGNED_TEAM)
    out["INFLOW"] = out["SOURCE_GROUP"].map(SOURCE_GROUP_LABEL).fillna("기타")
    return out


def team_long(member_df, erp_df, ad_df, bt_map):
    """팀 × 개발인입경로 × 월 기준의 긴 형태 표: 개발건수(실적부서) · 광고비(원천 규칙) · 제작비(캠페인코드 사용부서)."""
    cols = ["TEAM", "INFLOW", "MONTH", "개발건수", "광고비", "제작비"]
    parts = []
    if not member_df.empty:
        d = member_df[["DEPARTMENT_NAME", "DEVELOPMENT_INFLOW_PATH", "PERFORMANCE_MONTH", "DEVELOPMENT_COUNT"]].copy()
        d.columns = ["TEAM", "INFLOW", "MONTH", "개발건수"]
        d["MONTH"] = pd.to_datetime(d["MONTH"]).dt.to_period("M").astype(str)
        d["TEAM"] = d["TEAM"].where(d["TEAM"].isin(TEAMS), OTHER_DEPT)
        d["광고비"] = 0.0
        d["제작비"] = 0.0
        parts.append(d[cols])
    if not erp_df.empty:
        e = erp_df[["TEAM_NAME", "DEVELOPMENT_INFLOW_PATH", "PERFORMANCE_DATE", "PRODUCTION_COST"]].copy()
        e.columns = ["TEAM", "INFLOW", "MONTH", "제작비"]
        e["MONTH"] = pd.to_datetime(e["MONTH"]).dt.to_period("M").astype(str)
        t = e["TEAM"].fillna("").astype(str).str.strip()
        e["TEAM"] = np.where(t.eq(""), UNASSIGNED_TEAM, np.where(t.isin(TEAMS), t, OTHER_DEPT))
        e["개발건수"] = 0.0
        e["광고비"] = 0.0
        parts.append(e[cols])
    if not ad_df.empty:
        a = assign_ad_team(ad_df, bt_map)
        a = a[["TEAM", "INFLOW", "PERFORMANCE_DATE", "COST"]].copy()
        a.columns = ["TEAM", "INFLOW", "MONTH", "광고비"]
        a["MONTH"] = pd.to_datetime(a["MONTH"]).dt.to_period("M").astype(str)
        a["개발건수"] = 0.0
        a["제작비"] = 0.0
        parts.append(a[cols])
    if not parts:
        return pd.DataFrame(columns=cols)
    return pd.concat(parts, ignore_index=True)


def team_grid_frame(base, teams, value_cols):
    """base(TEAM·INFLOW·값 열)를 팀별 줄 + 소계 + 본부 소계 형태로 만듭니다."""
    out = []
    grand = {c: 0.0 for c in value_cols}
    for team in teams:
        part = base[base["TEAM"].eq(team)].copy()
        if part.empty:
            continue
        part["_o"] = part["INFLOW"].map(lambda x: INFLOW_ORDER.index(x) if x in INFLOW_ORDER else 99)
        part = part.sort_values(["_o", "INFLOW"])
        first = True
        for _, r in part.iterrows():
            row = {"팀": team if first else "", "개발인입경로": r["INFLOW"]}
            row.update({c: float(r[c]) for c in value_cols})
            row["_kind"] = "row"
            out.append(row)
            first = False
        sub = {"팀": "", "개발인입경로": "소계"}
        sub.update({c: float(part[c].sum()) for c in value_cols})
        sub["_kind"] = "sub"
        out.append(sub)
        for c in value_cols:
            grand[c] += sub[c]
    if not out:
        return pd.DataFrame(columns=["팀", "개발인입경로"] + list(value_cols) + ["_kind"])
    tot = {"팀": "나눔마케팅본부 소계", "개발인입경로": ""}
    tot.update(grand)
    tot["_kind"] = "total"
    out.append(tot)
    return pd.DataFrame(out)


def render_grid(df, text_cols, num_cols, groups=None, note_col=None, dec_cols=(), pct_cols=()):
    """_kind 열(row/sub/total)에 따라 소계·본부 소계를 강조하는 HTML 표를 그립니다.
    dec_cols: 소수 4자리까지(끝자리 0은 생략) 표시할 열, pct_cols: %로 표시할 열, 문자열 값(예: 산출불가)은 그대로 표시합니다."""
    if df.empty:
        st.info("표시할 데이터가 없습니다.")
        return
    dec_set = set(dec_cols)
    pct_set = set(pct_cols)

    def n(col, v):
        if isinstance(v, str):
            return escape(v)
        if v is None or pd.isna(v):
            return "-"
        if col in pct_set:
            return f"{v*100:,.1f}%"
        if col in dec_set:
            return f"{v:,.4f}".rstrip("0").rstrip(".")
        return f"{v:,.0f}"

    if groups:
        h1 = "".join(f'<th rowspan="2">{escape(t)}</th>' for t in text_cols)
        h1 += "".join(f'<th colspan="{len(cs)}">{escape(g)}</th>' for g, cs in groups)
        if note_col:
            h1 += f'<th rowspan="2">{escape(note_col)}</th>'
        h2 = "".join(f"<th>{escape(c)}</th>" for _, cs in groups for c in cs)
        head = f"<thead><tr>{h1}</tr><tr>{h2}</tr></thead>"
    else:
        h = "".join(f"<th>{escape(c)}</th>" for c in text_cols + list(num_cols))
        if note_col:
            h += f"<th>{escape(note_col)}</th>"
        head = f"<thead><tr>{h}</tr></thead>"
    cls = {"row": "", "sub": "sub", "total": "hq"}
    body = []
    for _, r in df.iterrows():
        cells = "".join(f'<td class="txt">{escape(str(r[c]))}</td>' for c in text_cols)
        cells += "".join(f'<td class="num">{n(c, r[c])}</td>' for c in num_cols)
        if note_col:
            cells += f'<td class="note">{escape(str(r.get(note_col, "") or ""))}</td>'
        body.append(f'<tr class="{cls.get(r["_kind"], "")}">{cells}</tr>')
    st.markdown(f'<div class="grid-wrap"><table class="grid-table">{head}<tbody>{"".join(body)}</tbody></table></div>', unsafe_allow_html=True)


# ------------------------------------------------------------------
# 목표 대비 진도·잔여 목표
# ------------------------------------------------------------------
def version_label(v):
    return BUDGET_LABELS.get(v, v)


def list_versions(goals_df, year):
    """해당 연도에 등록된 목표 구분(연사업·추가경정 등). 연사업을 먼저 보여줍니다."""
    vs = goals_df.loc[goals_df["GOAL_YEAR"].eq(year), "BDGT_PRCD_NM"].dropna().astype(str).unique().tolist()
    return sorted(vs, key=lambda v: (v != "연사업", v))


GOAL_FRAME_COLS = ["팀", "개발인입경로", "연목표", "누계 목표", "누계 실적", "누계 달성률",
                   "잔여 개발건", "월 필요 건수", "현재 단가", "필요 비용", "비고", "_kind"]


def goal_progress_frame(goal_g, actual_g, unit_g, teams, remain_months):
    """팀 × 개발인입경로별 목표·누계 실적·잔여 개발건·필요 비용 표를 만듭니다.
    - 현재 단가 = (광고비 + 제작비) ÷ 개발건수 (조회 기간 기준, 같은 팀·개발인입경로). 광고비 또는 개발건수가 없으면 '산출불가'.
    - 필요 비용 = 잔여 개발건 × 현재 단가. 잔여 개발건은 줄별로 계산하고(초과 달성 줄은 0) 합산합니다.
    - 소계·본부 소계의 필요 비용은 산출 가능한 줄만 더합니다."""
    keys = pd.concat([goal_g[["TEAM", "INFLOW"]], actual_g[["TEAM", "INFLOW"]]], ignore_index=True).drop_duplicates()
    m = (keys.merge(goal_g, on=["TEAM", "INFLOW"], how="left")
             .merge(actual_g, on=["TEAM", "INFLOW"], how="left")
             .merge(unit_g, on=["TEAM", "INFLOW"], how="left"))
    for c in ["연목표", "누계 목표", "누계 실적", "단가_개발건수", "단가_광고비", "단가_제작비"]:
        m[c] = pd.to_numeric(m[c], errors="coerce").fillna(0.0)
    m = m[m["TEAM"].isin(teams) & ((m["연목표"] > 0) | (m["누계 실적"] != 0))]

    def new_acc():
        return {"연목표": 0.0, "누계 목표": 0.0, "누계 실적": 0.0, "잔여": 0.0, "필요": 0.0, "제외잔여": 0.0, "제외줄": 0}

    def make_row(team_label, inflow, acc, kind, note=""):
        has_goal = acc["연목표"] > 0
        return {
            "팀": team_label, "개발인입경로": inflow,
            "연목표": acc["연목표"] if has_goal else np.nan,
            "누계 목표": acc["누계 목표"] if has_goal else np.nan,
            "누계 실적": acc["누계 실적"],
            "누계 달성률": acc["누계 실적"] / acc["누계 목표"] if acc["누계 목표"] > 0 else np.nan,
            "잔여 개발건": acc["잔여"] if has_goal else np.nan,
            "월 필요 건수": acc["잔여"] / remain_months if has_goal and remain_months > 0 else np.nan,
            "현재 단가": "-", "필요 비용": acc["필요"] if has_goal else np.nan,
            "비고": note, "_kind": kind,
        }

    def exclusion_note(acc):
        if acc["제외줄"]:
            return f"산출불가 {acc['제외줄']}줄 제외(잔여 {acc['제외잔여']:,.0f}건)"
        return ""

    out = []
    grand = new_acc()
    for team in teams:
        part = m[m["TEAM"].eq(team)].copy()
        if part.empty:
            continue
        part["_o"] = part["INFLOW"].map(lambda x: INFLOW_ORDER.index(x) if x in INFLOW_ORDER else 99)
        part = part.sort_values(["_o", "INFLOW"])
        tacc = new_acc()
        first = True
        for _, r in part.iterrows():
            target, cum_t, actual = r["연목표"], r["누계 목표"], r["누계 실적"]
            has_goal = target > 0
            remain = max(target - actual, 0.0) if has_goal else 0.0
            ad, prod, dev = r["단가_광고비"], r["단가_제작비"], r["단가_개발건수"]
            unit = (ad + prod) / dev if ad > 0 and dev > 0 else None
            note = INFLOW_NOTE.get(r["INFLOW"], "")
            if has_goal:
                if remain <= 0:
                    need = 0.0
                elif unit is None:
                    need = "산출불가"
                else:
                    need = remain * unit
            else:
                need = np.nan
                note = (note + " / " if note else "") + "목표 없음"
            row = {
                "팀": team if first else "", "개발인입경로": r["INFLOW"],
                "연목표": target if has_goal else np.nan,
                "누계 목표": cum_t if has_goal else np.nan,
                "누계 실적": actual,
                "누계 달성률": actual / cum_t if cum_t > 0 else np.nan,
                "잔여 개발건": remain if has_goal else np.nan,
                "월 필요 건수": remain / remain_months if has_goal and remain_months > 0 else np.nan,
                "현재 단가": unit if unit is not None else "산출불가",
                "필요 비용": need, "비고": note, "_kind": "row",
            }
            out.append(row)
            first = False
            for acc in (tacc, grand):
                acc["연목표"] += target
                acc["누계 목표"] += cum_t
                acc["누계 실적"] += actual
                acc["잔여"] += remain
                if has_goal and isinstance(need, str):
                    acc["제외잔여"] += remain
                    acc["제외줄"] += 1
                elif has_goal:
                    acc["필요"] += need
        out.append(make_row("", "소계", tacc, "sub", exclusion_note(tacc)))
    if not out:
        return pd.DataFrame(columns=GOAL_FRAME_COLS)
    out.append(make_row("나눔마케팅본부 소계", "", grand, "total", exclusion_note(grand)))
    return pd.DataFrame(out, columns=GOAL_FRAME_COLS)


# ------------------------------------------------------------------
# 선택 캠페인 상세
# ------------------------------------------------------------------
SOURCE_GROUP_ORDER = ["DIGITAL", "VIDEO", "BROADCAST", "RELAY", "REBROADCAST_OTHER", "OTHER"]
SOURCE_GROUP_DEFAULT_INFLOW = {"DIGITAL": "디지털", "VIDEO": "영상광고", "BROADCAST": "방송", "RELAY": "재송출"}
CAMPAIGN_SOURCE_COLS = ["원천", "개발인입경로", "채널", "광고비", "광고비 비중", "노출수", "클릭수", "전환가치",
                        "개발건수", "제작비", "통합 개발단가", "_kind"]


def _inflow_sort_key(x):
    return INFLOW_ORDER.index(x) if x in INFLOW_ORDER else 99


def campaign_source_frame(comp, d, expand):
    """선택 캠페인의 광고 원천별 성과표.
    - 원천 줄: 광고비·노출·클릭·전환가치(디지털만)와 그 원천에 대응하는 CRM 개발인입경로의 개발건수·제작비
    - expand=True 이면 원천 줄 아래에 채널별 줄(광고 원천 채널 + CRM 채널)을 펼칩니다.
    - 통합 개발단가 = (광고비 + 제작비) ÷ 개발건수. 광고비 또는 개발건수가 없으면 비웁니다."""
    crm = comp[comp["ROW_KIND"].isin(["CRM", "ERP"])].copy()
    crm["SOURCE_GROUP"] = crm["DEVELOPMENT_INFLOW_PATH"].map(INFLOW_TO_SOURCE).fillna("OTHER")
    ad = d.copy()
    total_ad = float(ad["COST"].sum())

    def unit(cost, prod, dev):
        return (cost + prod) / dev if dev > 0 and cost > 0 else np.nan

    def inflow_text(g):
        part = crm[(crm["SOURCE_GROUP"] == g) & ((crm["DEVELOPMENT_COUNT"] != 0) | (crm["PRODUCTION_COST"] != 0))]
        vals = sorted(set(part["DEVELOPMENT_INFLOW_PATH"]), key=_inflow_sort_key)
        return " · ".join(vals) if vals else SOURCE_GROUP_DEFAULT_INFLOW.get(g, "-")

    rows = []
    tot = {"광고비": 0.0, "노출수": 0.0, "클릭수": 0.0, "전환가치": 0.0, "개발건수": 0.0, "제작비": 0.0}
    for g in SOURCE_GROUP_ORDER:
        a = ad[ad["SOURCE_GROUP"] == g]
        c = crm[crm["SOURCE_GROUP"] == g]
        cost = float(a["COST"].sum())
        dev = float(c["DEVELOPMENT_COUNT"].sum())
        prod = float(c["PRODUCTION_COST"].sum())
        if cost == 0 and dev == 0 and prod == 0:
            continue
        is_dg = g == "DIGITAL"
        imp, clk, conv = (float(a["IMPRESSIONS"].sum()), float(a["CLICKS"].sum()), float(a["CONVERSIONS"].sum())) if is_dg else (np.nan, np.nan, np.nan)
        rows.append({
            "원천": "광고 원천 없음" if g == "OTHER" else SOURCE_GROUP_LABEL[g],
            "개발인입경로": inflow_text(g), "채널": "전체",
            "광고비": np.nan if g == "OTHER" else cost,
            "광고비 비중": cost / total_ad if total_ad and g != "OTHER" else np.nan,
            "노출수": imp, "클릭수": clk, "전환가치": conv,
            "개발건수": dev, "제작비": prod, "통합 개발단가": unit(cost, prod, dev), "_kind": "sub",
        })
        tot["광고비"] += cost
        tot["개발건수"] += dev
        tot["제작비"] += prod
        if is_dg:
            tot["노출수"] += imp
            tot["클릭수"] += clk
            tot["전환가치"] += conv
        if expand:
            chans = set(a["CHANNEL"].dropna().astype(str)) | set(c["CHANNEL_NAME"].dropna().astype(str))
            ch_rows = []
            for ch in chans:
                ac = a[a["CHANNEL"].astype(str) == ch]
                cc = c[c["CHANNEL_NAME"].astype(str) == ch]
                ccost = float(ac["COST"].sum())
                cdev = float(cc["DEVELOPMENT_COUNT"].sum())
                cprod = float(cc["PRODUCTION_COST"].sum())
                if ccost == 0 and cdev == 0 and cprod == 0:
                    continue
                ch_rows.append({
                    "원천": "", "개발인입경로": "", "채널": "└ " + ch,
                    "광고비": np.nan if g == "OTHER" else ccost,
                    "광고비 비중": ccost / total_ad if total_ad and g != "OTHER" else np.nan,
                    "노출수": float(ac["IMPRESSIONS"].sum()) if is_dg else np.nan,
                    "클릭수": float(ac["CLICKS"].sum()) if is_dg else np.nan,
                    "전환가치": float(ac["CONVERSIONS"].sum()) if is_dg else np.nan,
                    "개발건수": cdev, "제작비": cprod, "통합 개발단가": unit(ccost, cprod, cdev), "_kind": "row",
                    "_s": (ccost, cdev),
                })
            ch_rows.sort(key=lambda r: (-r["_s"][0], -r["_s"][1]))
            for r in ch_rows:
                r.pop("_s")
                rows.append(r)
    if not rows:
        return pd.DataFrame(columns=CAMPAIGN_SOURCE_COLS)
    rows.append({
        "원천": "합계", "개발인입경로": "", "채널": "",
        "광고비": tot["광고비"], "광고비 비중": 1.0 if total_ad else np.nan,
        "노출수": tot["노출수"], "클릭수": tot["클릭수"], "전환가치": tot["전환가치"],
        "개발건수": tot["개발건수"], "제작비": tot["제작비"],
        "통합 개발단가": unit(tot["광고비"], tot["제작비"], tot["개발건수"]), "_kind": "total",
    })
    return pd.DataFrame(rows, columns=CAMPAIGN_SOURCE_COLS)


COMPONENT_COLS = ["세부 캠페인(마케팅명)", "구분", "개발인입경로", "디지털", "영상광고", "방송·재송출",
                  "제작비", "총비용", "총비용 비중", "개발건수", "통합 개발단가", "_kind"]


def integration_method(comp_name, mk, n_comp, auto_map):
    """세부 캠페인이 통합 캠페인에 어떻게 묶였는지 설명합니다."""
    if comp_name == mk:
        return "단독 캠페인" if n_comp == 1 else "대표(원방송) 캠페인"
    if ROLLUP_MAP.get(comp_name) == mk:
        return "통합표 지정"
    if (auto_map or {}).get(comp_name) == mk:
        return "방송 UTM 공유 자동 통합"
    return "구성 캠페인"


def component_frame(comp, mk, auto_map):
    """통합 캠페인을 이루는 세부 캠페인(마케팅명)별 광고비·제작비·개발건수·통합 개발단가.
    방송 캠페인과 그 방송 소스로 진행한 디지털 캠페인을 한 캠페인으로 묶은 효율을 구성별로 풀어서 보여줍니다."""
    if comp.empty:
        return pd.DataFrame(columns=COMPONENT_COLS)
    g = comp.groupby("COMPONENT_CAMPAIGN_NAME", as_index=False).agg(
        디지털=("DIGITAL_AD_COST", "sum"), 영상광고=("VIDEO_AD_COST", "sum"), 방송재송출=("REBROADCAST_AD_COST", "sum"),
        제작비=("PRODUCTION_COST", "sum"), 총비용=("TOTAL_COST", "sum"), 개발건수=("DEVELOPMENT_COUNT", "sum"))
    crm = comp[comp["ROW_KIND"].isin(["CRM", "ERP"])]
    inflow = crm.groupby("COMPONENT_CAMPAIGN_NAME")["DEVELOPMENT_INFLOW_PATH"].agg(
        lambda s: " · ".join(sorted({str(x) for x in s}, key=_inflow_sort_key)))
    g["개발인입경로"] = g["COMPONENT_CAMPAIGN_NAME"].map(inflow).fillna("-")
    g = g.sort_values(["총비용", "개발건수"], ascending=False).reset_index(drop=True)
    total_cost = float(g["총비용"].sum())
    n_comp = len(g)
    rows = []
    for _, r in g.iterrows():
        rows.append({
            "세부 캠페인(마케팅명)": str(r["COMPONENT_CAMPAIGN_NAME"]),
            "구분": integration_method(str(r["COMPONENT_CAMPAIGN_NAME"]), mk, n_comp, auto_map),
            "개발인입경로": r["개발인입경로"],
            "디지털": r["디지털"], "영상광고": r["영상광고"], "방송·재송출": r["방송재송출"],
            "제작비": r["제작비"], "총비용": r["총비용"],
            "총비용 비중": r["총비용"] / total_cost if total_cost else np.nan,
            "개발건수": r["개발건수"],
            "통합 개발단가": r["총비용"] / r["개발건수"] if r["개발건수"] > 0 and r["총비용"] > 0 else np.nan,
            "_kind": "row",
        })
    tdev = float(g["개발건수"].sum())
    rows.append({
        "세부 캠페인(마케팅명)": "통합 합계", "구분": f"{n_comp}개 캠페인", "개발인입경로": "",
        "디지털": float(g["디지털"].sum()), "영상광고": float(g["영상광고"].sum()), "방송·재송출": float(g["방송재송출"].sum()),
        "제작비": float(g["제작비"].sum()), "총비용": total_cost, "총비용 비중": 1.0 if total_cost else np.nan,
        "개발건수": tdev, "통합 개발단가": total_cost / tdev if tdev > 0 and total_cost > 0 else np.nan, "_kind": "total",
    })
    return pd.DataFrame(rows, columns=COMPONENT_COLS)


def integration_overview_frame(filtered_df, auto_map):
    """통합 캠페인 중 세부 캠페인이 둘 이상인 것만, 구성과 통합 방식을 한 표로 보여줍니다."""
    cols = ["통합 캠페인", "세부 캠페인", "통합 방식", "광고비", "제작비", "총비용", "개발건수", "통합 개발단가", "_kind"]
    if filtered_df.empty:
        return pd.DataFrame(columns=cols)
    base = filtered_df.groupby(["MARKETING_CAMPAIGN_NAME", "COMPONENT_CAMPAIGN_NAME"], as_index=False).agg(
        광고비=("AD_COST", "sum"), 제작비=("PRODUCTION_COST", "sum"), 개발건수=("DEVELOPMENT_COUNT", "sum"))
    base["총비용"] = base["광고비"] + base["제작비"]
    n = base.groupby("MARKETING_CAMPAIGN_NAME")["COMPONENT_CAMPAIGN_NAME"].transform("nunique")
    base = base[n > 1]
    if base.empty:
        return pd.DataFrame(columns=cols)
    order = base.groupby("MARKETING_CAMPAIGN_NAME")["총비용"].sum().sort_values(ascending=False).index
    rows = []

    def unit(cost, dev):
        return cost / dev if dev > 0 and cost > 0 else np.nan

    for mk in order:
        part = base[base["MARKETING_CAMPAIGN_NAME"] == mk].sort_values("총비용", ascending=False)
        rows.append({"통합 캠페인": mk, "세부 캠페인": f"전체 {len(part)}개", "통합 방식": "",
                     "광고비": float(part["광고비"].sum()), "제작비": float(part["제작비"].sum()),
                     "총비용": float(part["총비용"].sum()), "개발건수": float(part["개발건수"].sum()),
                     "통합 개발단가": unit(float(part["총비용"].sum()), float(part["개발건수"].sum())), "_kind": "sub"})
        for _, r in part.iterrows():
            comp_name = str(r["COMPONENT_CAMPAIGN_NAME"])
            rows.append({"통합 캠페인": "", "세부 캠페인": comp_name,
                         "통합 방식": integration_method(comp_name, mk, len(part), auto_map),
                         "광고비": r["광고비"], "제작비": r["제작비"], "총비용": r["총비용"], "개발건수": r["개발건수"],
                         "통합 개발단가": unit(r["총비용"], r["개발건수"]), "_kind": "row"})
    return pd.DataFrame(rows, columns=cols)


_toggle = getattr(st, "toggle", st.checkbox)


def campaign_detail_panel(name, current_df, filtered_df, member_df, ga_df, detail_df, collab_df, key_prefix, on_close=None, auto_map=None):
    auto_map = auto_map or {}
    rows = current_df[current_df["MARKETING_CAMPAIGN_NAME"] == name]
    if rows.empty:
        return
    r = rows.iloc[0]
    head_l, head_r = st.columns([7, 1])
    n_comp_badge = int(r.get("COMPONENT_COUNT", 1) or 1)
    badge = f'<span class="detail-badge">통합 {n_comp_badge}개</span>' if n_comp_badge > 1 else ""
    head_l.markdown(
        '<div class="detail-heading"><div><div class="detail-eyebrow">CAMPAIGN DETAIL</div>'
        f'<div class="detail-title">{escape(str(name))}{badge}</div></div></div>',
        unsafe_allow_html=True,
    )
    if on_close is not None:
        head_r.button("닫기 ✕", key=f"{key_prefix}_close", on_click=on_close, use_container_width=True)

    comp = filtered_df[filtered_df["MARKETING_CAMPAIGN_NAME"].eq(name)]
    d = detail_df[detail_df["MARKETING_CAMPAIGN_NAME"].eq(name)]
    comp_names = (comp.groupby("COMPONENT_CAMPAIGN_NAME")["TOTAL_COST"].sum()
                  .sort_values(ascending=False).index.astype(str).tolist())
    # 세부 캠페인명: ' | '로 묶인 이름은 나누고 중복을 없앤 뒤 칩으로 표시합니다.
    chip_names = []
    for cn in comp_names:
        for part in split_bar(cn) or [cn]:
            if part not in chip_names:
                chip_names.append(part)
    # 캠페인 카테고리: 통합 집계에 포함된 유형1·유형2를 중복 없이 칩으로 표시합니다.
    category_names = []
    for category_value in [r.get("CAMPAIGN_TYPE1", ""), r.get("CAMPAIGN_TYPE2", "")]:
        for category in str(category_value or "").split(","):
            category = category.strip()
            if category and category != "미분류" and category not in category_names:
                category_names.append(category)
    if category_names:
        category_chips = "".join(
            f'<span class="comp-chip">{escape(category)}</span>'
            for category in category_names
        )
        st.markdown(
            f'<div class="comp-row"><span class="comp-label">캠페인 카테고리</span>{category_chips}</div>',
            unsafe_allow_html=True,
        )

    if len(chip_names) > 1 or (chip_names and chip_names[0] != name):
        shown = chip_names[:6]
        more = len(chip_names) - len(shown)
        chips = "".join(f'<span class="comp-chip{" main" if c == name else ""}">{escape(c)}</span>' for c in shown)
        if more > 0:
            chips += f'<span class="comp-chip">외 {more}개</span>'
        st.markdown(f'<div class="comp-row"><span class="comp-label">세부 캠페인</span>{chips}</div>',
                    unsafe_allow_html=True)

    boxes = st.columns(5)
    for box, title, col, fmt in zip(boxes,
        ["총비용", "제작비", "광고비", "CRM 개발건수", "통합 개발단가"],
        ["TOTAL_COST", "PRODUCTION_COST", "AD_COST", "DEVELOPMENT_COUNT", "DEVELOPMENT_UNIT_COST"],
        [won, won, won, cnt, won]):
        value = fmt(r[col])
        box.markdown(
            f'<div class="kpi-card"><div class="kpi-label">{escape(title)}</div>'
            f'<div class="kpi-value" title="{escape(value, quote=True)}">{escape(value)}</div></div>',
            unsafe_allow_html=True,
        )

    t_src, t_comp, t_trend, t_ga = st.tabs(["광고 원천별 성과", "세부 캠페인", "월별 추이·비용 구성", "GA 반응·회원 구성"])

    with t_src:
        expand = _toggle("채널별 세부 보기", key=f"{key_prefix}_chexp_{name}",
                         help="켜면 각 광고 원천 아래에 채널별 광고비·개발건수가 펼쳐집니다.")
        frame = campaign_source_frame(comp, d, expand)
        if frame.empty:
            st.info("선택 기간·필터에서 이 캠페인으로 귀속된 광고비와 개발 실적이 없습니다.")
        else:
            text_cols = ["원천", "개발인입경로"] + (["채널"] if expand else [])
            render_grid(
                frame, text_cols,
                ["광고비", "광고비 비중", "노출수", "클릭수", "전환가치", "개발건수", "제작비", "통합 개발단가"],
                groups=[("광고", ["광고비", "광고비 비중", "노출수", "클릭수", "전환가치"]),
                        ("회원개발", ["개발건수", "제작비"]), ("단가", ["통합 개발단가"])],
                pct_cols=["광고비 비중"],
            )
            st.caption(
                "원천 줄의 개발인입경로는 그 원천에 대응하는 CRM 개발인입경로(방송은 방송·뉴미디어)이며, 개발건수·제작비도 그 경로 기준입니다. "
                "노출·클릭·전환가치는 디지털(대행사 리포트)만 있습니다. 통합 개발단가 = (광고비 + 제작비) ÷ 개발건수. "
                + ("" if expand else "채널별 내역은 위의 '채널별 세부 보기'를 켜면 표시됩니다.")
            )
        dsrc = d[d["SOURCE_TYPE"].eq("DIGITAL")]
        if expand and not dsrc.empty:
            with st.expander("디지털 UTM별 성과"):
                ut = digital_metrics(dsrc, ["UTM_RAW", "SOURCE_CAMPAIGN"]).rename(
                    columns={"UTM_RAW": "UTM(원천 표기)", "SOURCE_CAMPAIGN": "원천 캠페인명"})
                show_df(ut, use_container_width=True, hide_index=True, height=260)
                st.caption("같은 UTM의 전체 성과(다른 캠페인 귀속분 포함)는 '06 UTM 보기' 탭에서 확인할 수 있습니다.")
        if not collab_df.empty:
            cdf = collab_df[collab_df["COLLAB_CAMPAIGNS"].apply(lambda t: name in split_bar(t))]
            if not cdf.empty:
                with st.expander("미분리 콜라보 비용 (캠페인 비용 미포함)"):
                    cs = cdf.groupby(["UTM_RAW", "COLLAB_CAMPAIGNS"], as_index=False).agg(
                        미분리비용=("COST", "sum"), 클릭수=("CLICKS", "sum"), 전환가치=("CONVERSIONS", "sum")
                    ).sort_values("미분리비용", ascending=False).rename(columns={"UTM_RAW": "UTM(원천 표기)", "COLLAB_CAMPAIGNS": "참여 캠페인"})
                    show_df(cs, use_container_width=True, hide_index=True)

    with t_comp:
        cf = component_frame(comp, name, auto_map)
        if cf.empty:
            st.info("선택 기간·필터에서 이 캠페인의 세부 캠페인 실적이 없습니다.")
        else:
            render_grid(
                cf, ["세부 캠페인(마케팅명)", "구분", "개발인입경로"],
                ["디지털", "영상광고", "방송·재송출", "제작비", "총비용", "총비용 비중", "개발건수", "통합 개발단가"],
                groups=[("광고비", ["디지털", "영상광고", "방송·재송출"]), ("비용", ["제작비", "총비용", "총비용 비중"]),
                        ("회원개발", ["개발건수"]), ("단가", ["통합 개발단가"])],
                pct_cols=["총비용 비중"],
            )
            st.caption(
                "산점도의 한 풍선은 아래 세부 캠페인을 하나로 합친 효율입니다. 방송 캠페인과 그 방송 소스로 진행한 디지털 캠페인은 "
                "'통합표 지정' 또는 '방송 UTM 공유 자동 통합'으로 묶입니다. 통합 개발단가 = 총비용(광고비+제작비) ÷ 개발건수."
            )

    with t_trend:
        left, right = st.columns([1, 2], gap="medium")
        with left:
            st.markdown('<div class="chart-heading">비용 구성</div>', unsafe_allow_html=True)
            st.markdown('<div class="chart-key">선택 기간 집행비용의 구성 비중</div>', unsafe_allow_html=True)
            cost_mix = pd.DataFrame({"비용 구분": ["제작비", "디지털", "영상광고", "방송·재송출"], "금액": [r["PRODUCTION_COST"], r["DIGITAL_AD_COST"], r["VIDEO_AD_COST"], r["REBROADCAST_AD_COST"]]})
            cost_donut(cost_mix, campaign_name=name)
        with right:
            st.markdown('<div class="chart-heading">월별 비용·개발성과</div>', unsafe_allow_html=True)
            monthly_chart(comp, height=320, campaign_name=name)

    with t_ga:
        gm = ga_df[ga_df["MARKETING_CAMPAIGN_NAME"] == name]
        if not gm.empty:
            st.markdown("##### GA 반응 (UTM 단일 연결 기준)")
            gs = gm[["SETTLE_AMOUNT", "CONVERSION_VALUE", "SPONSOR_COUNT", "CLICK_COUNT", "IMPRESSION_COUNT"]].sum()
            a_, b_, c_, d_ = st.columns(4)
            a_.metric("GA 전환가치", cnt(gs["CONVERSION_VALUE"]))
            b_.metric("GA CTR", pct(div0(gs["CLICK_COUNT"], gs["IMPRESSION_COUNT"])))
            c_.metric("GA CVR", pct(div0(gs["SPONSOR_COUNT"], gs["CLICK_COUNT"])))
            d_.metric("GA 개발단가", won(div0(gs["SETTLE_AMOUNT"], gs["CONVERSION_VALUE"])))
        else:
            st.info("이 캠페인에 연결된 GA 데이터가 없습니다.")
        st.markdown("##### 회원 구성")
        cm = member_df[member_df["MARKETING_CAMPAIGN_NAME"] == name]
        for box, col, title in zip(st.columns(5), ["AGE_BAND", "SEX_NAME", "DEVELOPMENT_TYPE", "PAYMENT_METHOD", "AD_ORGANIC"], ["연령대", "성별", "개발구분", "납입방식", "광고/오가닉"]):
            with box:
                mix_card(cm, col, title)


# ------------------------------------------------------------------
# 화면
# ------------------------------------------------------------------
st.markdown('<div class="report-kicker">MARKETING PERFORMANCE</div><div class="report-title">마케팅 콘텐츠 통합성과 대시보드</div><div class="report-subtitle">콘텐츠별 비용과 성과를 연결하고, 다음 의사결정의 근거를 확인합니다.</div>', unsafe_allow_html=True)
goal_error = None
try:
    with st.spinner("Snowflake 데이터를 불러오는 중입니다."):
        raw = load_integrated(INTEGRATED_SQL)
        members = load_members(MEMBER_SQL)
        team_dev = load_team_dev(TEAM_DEV_SQL)
        ga = load_ga(GA_SQL)
        detail = load_ad_detail(AD_DETAIL_SQL)
except Exception as exc:
    st.error("데이터를 조회하지 못했습니다.")
    st.exception(exc)
    st.stop()
try:
    goals = load_goals(GOAL_SQL)
except Exception as exc:
    goals = pd.DataFrame()
    goal_error = exc
cand_error = None
try:
    cand_df = load_rollup_candidates(ROLLUP_CANDIDATE_SQL)
except Exception as exc:
    cand_df = pd.DataFrame(columns=["SOURCE_NAME", "BROADCAST_CANDIDATES"])
    cand_error = exc
AUTO_PAIRS, AMBIGUOUS = build_auto_rollup(cand_df, ROLLUP_MAP)
if raw.empty:
    st.warning("통합 성과 조회 결과가 없습니다.")
    st.stop()

raw["PERFORMANCE_DATE"] = pd.to_datetime(raw["PERFORMANCE_DATE"], errors="coerce")
raw = raw[raw["PERFORMANCE_DATE"].notna()].copy()
if raw.empty:
    st.warning("유효한 날짜의 통합 성과가 없습니다.")
    st.stop()
for c in NUM_INT:
    raw[c] = pd.to_numeric(raw[c], errors="coerce").fillna(0)
for c in LABELS:
    raw[c] = raw[c].fillna("미분류").astype(str)
raw["COMPONENT_CAMPAIGN_NAME"] = raw["COMPONENT_CAMPAIGN_NAME"].fillna(raw["MARKETING_CAMPAIGN_NAME"])
raw["ROW_KIND"] = raw["ROW_KIND"].fillna("AD").astype(str)

members["PERFORMANCE_MONTH"] = pd.to_datetime(members["PERFORMANCE_MONTH"], errors="coerce")
members["DEVELOPMENT_COUNT"] = pd.to_numeric(members["DEVELOPMENT_COUNT"], errors="coerce").fillna(0)
members["MARKETING_CAMPAIGN_NAME"] = members["MARKETING_CAMPAIGN_NAME"].replace(ROLLUP_MAP)

team_dev["PERFORMANCE_MONTH"] = pd.to_datetime(team_dev["PERFORMANCE_MONTH"], errors="coerce")
team_dev["DEVELOPMENT_COUNT"] = pd.to_numeric(team_dev["DEVELOPMENT_COUNT"], errors="coerce").fillna(0)
team_dev["MARKETING_CAMPAIGN_NAME"] = team_dev["MARKETING_CAMPAIGN_NAME"].astype(str).replace(ROLLUP_MAP)
for c in LABELS + ["DEPARTMENT_NAME"]:
    team_dev[c] = team_dev[c].fillna("미분류").astype(str).str.strip()
team_dev = team_dev[team_dev["PERFORMANCE_MONTH"].notna()].copy()

if not goals.empty:
    goals["GOAL_YEAR"] = goals["GOAL_YEAR"].astype(str).str.strip()
    goals["BDGT_PRCD_NM"] = goals["BDGT_PRCD_NM"].astype(str).str.strip()
    goals["TEAM_NM"] = goals["TEAM_NM"].astype(str).str.strip()
    goals["INFLOW"] = goals["INFLOW"].astype(str).str.strip()
    for m_col in [f"M{m:02d}" for m in range(1, 13)]:
        goals[m_col] = pd.to_numeric(goals[m_col], errors="coerce").fillna(0)

ga["PERFORMANCE_DATE"] = pd.to_datetime(ga["PERFORMANCE_DATE"], errors="coerce")
for c in ["SETTLE_AMOUNT", "CONVERSION_VALUE", "SPONSOR_COUNT", "CLICK_COUNT", "IMPRESSION_COUNT", "GA_CTR", "GA_CVR", "GA_UNIT_COST"]:
    ga[c] = pd.to_numeric(ga[c], errors="coerce").fillna(0)
ga["MARKETING_CAMPAIGN_NAME"] = ga["MARKETING_CAMPAIGN_NAME"].replace(ROLLUP_MAP)

detail["PERFORMANCE_DATE"] = pd.to_datetime(detail["PERFORMANCE_DATE"], errors="coerce")
for c in ["COST", "SOURCE_ROWS", "IMPRESSIONS", "CLICKS", "CONVERSIONS", "SPONSORS"]:
    detail[c] = pd.to_numeric(detail[c], errors="coerce").fillna(0)
detail["SOURCE_CAMPAIGN"] = detail["SOURCE_CAMPAIGN"].fillna("[원천 캠페인명 없음]")
detail = add_source_group(detail)

min_date, max_date = raw["PERFORMANCE_DATE"].min().date(), raw["PERFORMANCE_DATE"].max().date()
SCOPES = ["전체(2024년 이후)", "올해", "최근 1개월", "최근 3개월", "최근 6개월", "최근 1년", "최근 2년", "전체 기간", "직접 선택"]
with st.sidebar:
    st.markdown('<div class="sidebar-brand">나눔마케팅본부 통합 분석</div><div class="sidebar-sub">CRM · ERP · 광고성과</div>', unsafe_allow_html=True)
    demo_mode = st.checkbox("핵심 2화면만 보기", value=True, key="demo_mode")
    st.caption("끄면 비용·GA 상세, 캠페인 상세, 데이터 점검, UTM 보기 탭이 함께 표시됩니다.")
    auto_rollup = st.checkbox("방송 소스 디지털 캠페인 자동 통합", value=AUTO_ROLLUP_DEFAULT, key="auto_rollup",
                              help="방송 캠페인과 UTM을 공유하는 디지털 캠페인을 그 방송 캠페인 하나로 합쳐 효율을 계산합니다. "
                                   "통합표(CAMPAIGN_ROLLUP)에 이미 지정한 캠페인은 그대로 두고, 공유하는 방송 캠페인이 하나로 정해지는 경우만 합칩니다.")
    st.header("분석 필터")
    scope = st.selectbox("분석 범위", SCOPES, index=0, key="analysis_scope_v2")
    offsets = {"최근 1개월": pd.DateOffset(months=1), "최근 3개월": pd.DateOffset(months=3), "최근 6개월": pd.DateOffset(months=6), "최근 1년": pd.DateOffset(years=1), "최근 2년": pd.DateOffset(years=2)}
    if scope == "전체(2024년 이후)":
        start, end = date(2024, 1, 1), max_date
        st.caption("2024.01.01부터 데이터 최종일까지 제작비·광고비·개발건수를 같은 기간으로 집계합니다.")
    elif scope == "올해":
        start, end = max(min_date, date(max_date.year, 1, 1)), max_date
    elif scope in offsets:
        start, end = max(min_date, (pd.Timestamp(max_date) - offsets[scope]).date()), max_date
    elif scope == "전체 기간":
        start, end = min_date, max_date
        st.caption("원천의 모든 날짜를 포함합니다. 2024년 이전 비용은 비교 시 주의하세요.")
    else:
        start = st.date_input("시작일", max(min_date, (pd.Timestamp(max_date) - pd.DateOffset(years=1)).date()), min_value=min_date, max_value=max_date, format="YYYY.MM.DD")
        end = st.date_input("종료일", max_date, min_value=min_date, max_value=max_date, format="YYYY.MM.DD")
    with st.expander("상세 필터 (유형·채널·개발인입경로)", expanded=not demo_mode):
        types = st.multiselect("캠페인 유형1", split_options(raw["CAMPAIGN_TYPE1"]), placeholder="전체")
        types2 = st.multiselect("캠페인 유형2", split_options(raw["CAMPAIGN_TYPE2"]), placeholder="전체")
        channels = st.multiselect("채널", split_options(raw["CHANNEL_NAME"]), placeholder="전체")
        inflows = st.multiselect("개발인입경로", split_options(raw["DEVELOPMENT_INFLOW_PATH"]), placeholder="전체")
        st.caption("개발건수·제작비는 캠페인코드의 채널, 광고비는 광고 원천의 채널(디지털 매체·영상/재송출 채널)로 필터됩니다.")
    if st.button("데이터 새로고침", use_container_width=True):
        st.cache_data.clear()
        st.rerun()
    st.caption(f"데이터 최종일: {max_date:%Y.%m.%d}")
    st.divider()
    st.markdown('<div class="nav-title">연결 대시보드</div>', unsafe_allow_html=True)
    st.caption("통합 성과에서 매체별 상세 분석으로 이어집니다.")
    for _dash in ["디지털", "영상광고", "방송", "재송출"]:
        _url = DASHBOARD_LINKS.get(_dash, "")
        if _url:
            st.link_button(f"{_dash} 대시보드  ↗", _url, use_container_width=True)
        else:
            st.button(f"{_dash} 대시보드 · 준비 중", key=f"nav_{_dash}", disabled=True, use_container_width=True)

# 방송 소스 디지털 캠페인 자동 통합: 디지털 캠페인의 마케팅캠페인명을 방송 캠페인명으로 바꿉니다(세부 캠페인명은 COMPONENT_CAMPAIGN_NAME에 그대로 남습니다).
AUTO_MAP = dict(AUTO_PAIRS) if auto_rollup else {}
if AUTO_MAP:
    for _df in (raw, detail, members, ga, team_dev):
        _df["MARKETING_CAMPAIGN_NAME"] = _df["MARKETING_CAMPAIGN_NAME"].replace(AUTO_MAP)

start_ts, end_ts = pd.Timestamp(start), pd.Timestamp(end)
if start_ts > end_ts:
    st.warning("선택한 기간에 유효한 데이터가 없습니다. 분석 범위 또는 시작일·종료일을 확인하세요.")
    st.stop()

FILTERS = [("CAMPAIGN_TYPE1", types), ("CAMPAIGN_TYPE2", types2), ("CHANNEL_NAME", channels), ("DEVELOPMENT_INFLOW_PATH", inflows)]
any_filter = bool(types or types2 or channels or inflows)

filtered = raw[raw["PERFORMANCE_DATE"].between(start_ts, end_ts)].copy()
for c, v in FILTERS:
    filtered = multi_filter(filtered, c, v)
current = aggregate_campaigns(filtered)
names = set(current["MARKETING_CAMPAIGN_NAME"])

member_filtered = members[(members["PERFORMANCE_MONTH"] >= start_ts.to_period("M").to_timestamp()) & (members["PERFORMANCE_MONTH"] <= end_ts.to_period("M").to_timestamp())].copy()
for c, v in FILTERS:
    if v:
        member_filtered = member_filtered[member_filtered[c].isin(v)]
member_filtered = member_filtered[member_filtered["MARKETING_CAMPAIGN_NAME"].isin(names)]
ga_filtered = ga[ga["PERFORMANCE_DATE"].between(start_ts, end_ts)].copy()
ga_filtered = ga_filtered[ga_filtered["MARKETING_CAMPAIGN_NAME"].isin(names)]

# 팀별 개발건수(07 탭): 사이드바 유형·채널·개발인입경로 필터는 따르지만, 통합 성과 표의 캠페인 목록과는 무관하게 월별 요약 전체를 사용합니다.
team_dev_f = team_dev.copy()
for c, v in FILTERS:
    team_dev_f = multi_filter(team_dev_f, c, v)
team_dev_period = team_dev_f[
    (team_dev_f["PERFORMANCE_MONTH"] >= start_ts.to_period("M").to_timestamp())
    & (team_dev_f["PERFORMANCE_MONTH"] <= end_ts.to_period("M").to_timestamp())
].copy()

detail_period = detail[detail["PERFORMANCE_DATE"].between(start_ts, end_ts)].copy()
detail_filtered = detail_period[detail_period["MAPPING_STATUS"].eq("단일 귀속") & detail_period["MARKETING_CAMPAIGN_NAME"].isin(names)].copy()
if any_filter:
    # 광고 상세도 필터를 통과한 (구성 캠페인, 채널)만 포함
    ad_rows = filtered[filtered["ROW_KIND"].eq("AD")]
    ad_keys = set(zip(ad_rows["COMPONENT_CAMPAIGN_NAME"], ad_rows["CHANNEL_NAME"]))
    detail_filtered = detail_filtered[[k in ad_keys for k in zip(detail_filtered["COMPONENT_CAMPAIGN_NAME"], detail_filtered["CHANNEL"])]]
collab_filtered = detail_period[detail_period["MAPPING_STATUS"].eq("콜라보 공유비")].copy()
common_total = detail_period.loc[detail_period["MAPPING_STATUS"].eq(COMMON_STATUS), "COST"].sum()

prod, ad, dev, total = (current[c].sum() for c in ["PRODUCTION_COST", "AD_COST", "DEVELOPMENT_COUNT", "TOTAL_COST"])
k1, k2, k3, k4, k5 = st.columns(5)
k1.metric("총 제작비", won(prod))
k2.metric("캠페인 광고비", won(ad))
if any_filter:
    k3.metric("공통비(검색·브랜드)", "-", "캠페인 필터 적용 중에는 제외", delta_color="off")
else:
    k3.metric("공통비(검색·브랜드)", won(common_total), f"전체 광고비 {won(ad + common_total)}", delta_color="off")
k4.metric("총 개발건수", cnt(dev))
k5.metric("통합 개발단가", won(div0(total, dev)))
collab_total = collab_filtered["COST"].sum()
note_collab = f"&nbsp;&nbsp;|&nbsp;&nbsp;미분리 콜라보 비용 {collab_total:,.0f}원 별도" if collab_total else ""
st.markdown(f'<div class="hero-note"><b>분석 기준</b>&nbsp;&nbsp;{escape(scope)}&nbsp;&nbsp;{start_ts:%Y.%m.%d} ~ {end_ts:%Y.%m.%d}&nbsp;&nbsp;|&nbsp;&nbsp;통합 캠페인(원방송) 기준&nbsp;&nbsp;|&nbsp;&nbsp;통합 개발단가 = (제작비 + 캠페인 광고비) ÷ CRM 개발건수, 공통비 제외{note_collab}</div>', unsafe_allow_html=True)
if channels or inflows:
    st.caption("채널 필터: 개발건수·제작비는 해당 채널 캠페인코드 실적, 광고비는 해당 채널(매체)에 집행된 광고비만 포함합니다. 개발인입경로 필터의 광고비는 같은 캠페인·채널의 CRM 코드 인입경로 기준입니다.")

# ------------------------------------------------------------------
# 산점도 선택 상태 (펼침·접기)
# ------------------------------------------------------------------
NONE_PICK = "캠페인 선택 안 함"
if "scatter_ver" not in st.session_state:
    st.session_state["scatter_ver"] = 0


def close_detail():
    """상세를 접습니다: 산점도 선택과 직접 선택을 모두 해제합니다."""
    st.session_state["shared_campaign"] = None
    st.session_state["scatter_ver"] += 1
    st.session_state["pick_campaign"] = NONE_PICK


def on_pick_change():
    st.session_state["shared_campaign"] = None
    """직접 선택을 바꾸면 산점도에 남아 있던 선택을 지웁니다."""
    st.session_state["scatter_ver"] += 1


def on_chart_select():
    st.session_state["shared_campaign"] = None
    """산점도에서 원을 클릭하면 직접 선택을 비웁니다."""
    st.session_state["pick_campaign"] = NONE_PICK


TAB_DEFS = [("01", "01 통합 성과"), ("02", "02 비용·GA 상세"), ("03", "03 캠페인 상세"), ("04", "04 오픈 주차"),
            ("05", "05 데이터 점검"), ("06", "06 UTM 보기"), ("07", "07 팀별 실적")]
SIMPLE_TAB_LABELS = {"01": "1. 통합 성과", "07": "2. 팀별 실적·잔여 목표"}
if demo_mode:
    tab_keys = ["01", "07"]
    tab_labels = [SIMPLE_TAB_LABELS[k] for k in tab_keys]
else:
    tab_keys = [k for k, _ in TAB_DEFS]
    tab_labels = [label for _, label in TAB_DEFS]
T = dict(zip(tab_keys, st.tabs(tab_labels)))

AXIS_LABEL_EXPR = ("datum.value >= 100000000 ? format(datum.value / 100000000, ',.1~f') + '억' : "
                   "(datum.value >= 10000 ? format(datum.value / 10000, ',.0f') + '만' : format(datum.value, ',.0f'))")


# 산점도 지표: (원천 집계 열, 화면 단위)
SCATTER_METRICS = {
    "통합 개발단가": ("DEVELOPMENT_UNIT_COST", "원/건"),
    "총비용": ("TOTAL_COST", "원"),
    "광고비": ("AD_COST", "원"),
    "제작비": ("PRODUCTION_COST", "원"),
    "개발건수": ("DEVELOPMENT_COUNT", "건"),
    "디지털 광고비": ("DIGITAL_AD_COST", "원"),
    "영상광고비": ("VIDEO_AD_COST", "원"),
    "방송·재송출 광고비": ("REBROADCAST_AD_COST", "원"),
    "세부 캠페인 수": ("COMPONENT_COUNT", "개"),
}


def scatter_metric_frame(current_df):
    """단가를 계산할 수 없는 행은 산점도용 단가만 결측으로 처리합니다. 원 집계는 유지합니다."""
    frame = current_df[~current_df["MARKETING_CAMPAIGN_NAME"].isin(SCATTER_EXCLUDE)].copy()
    frame["구성"] = np.where(frame["COMPONENT_COUNT"] > 1, "통합", "단일")
    frame.loc[(frame["DEVELOPMENT_COUNT"] <= 0) | (frame["TOTAL_COST"] <= 0), "DEVELOPMENT_UNIT_COST"] = np.nan
    unit = frame.loc[(frame["TOTAL_COST"] > 0) & (frame["DEVELOPMENT_COUNT"] > 0), "DEVELOPMENT_UNIT_COST"]
    q33, q67 = unit.quantile([.33, .67]) if not unit.empty else (np.nan, np.nan)
    frame["효율영역"] = np.select(
        [frame["DEVELOPMENT_UNIT_COST"].isna(), frame["DEVELOPMENT_UNIT_COST"] <= q33,
         frame["DEVELOPMENT_UNIT_COST"] <= q67],
        ["산출 불가", "단가 낮음", "보통"], default="단가 높음",
    )
    return frame


def scatter_visible_frame(frame, only_integrated, x_field, y_field, size_field):
    """통합 필터와 선택 지표의 유효성만 적용합니다. 원 집계 및 TOP 5는 바꾸지 않습니다."""
    out = frame[frame["구성"].eq("통합")].copy() if only_integrated else frame.copy()
    before = len(out)
    valid = np.isfinite(pd.to_numeric(out[x_field], errors="coerce"))
    valid &= np.isfinite(pd.to_numeric(out[y_field], errors="coerce"))
    if size_field:
        size = pd.to_numeric(out[size_field], errors="coerce")
        valid &= np.isfinite(size) & size.ge(0)
    out = out.loc[valid].copy()
    return out, before - len(out)


def scatter_axis_scale(series, request_log):
    """0·음수가 있으면 선형 눈금으로 전환해 금액을 숨기거나 임의 보정하지 않습니다."""
    use_log = bool(request_log and len(series) and series.gt(0).all())
    return ({"type": "log", "nice": True, "zero": False} if use_log
            else {"type": "linear", "nice": True, "zero": True}), use_log


def render_campaign_scatter(current_df):
    """산점도 설정·선택·상세. 반환값은 TOP 5용 전체 캠페인으로 필터와 독립적입니다."""
    base = scatter_metric_frame(current_df)
    top_all = base[(base["TOTAL_COST"] > 0) & (base["DEVELOPMENT_COUNT"] > 0)].copy()
    labels = list(SCATTER_METRICS)
    with st.container(border=True):
        st.markdown("##### 캠페인 비교 설정")
        p1, p2 = st.columns([2.5, 1])
        with p1:
            mode = st.radio("산점도 표시 대상", ["전체 캠페인", "통합 캠페인만"],
                            horizontal=True, key="scatter_scope", on_change=on_pick_change)
        with p2:
            request_log = _toggle("로그 눈금", value=True, key="scatter_log", on_change=on_pick_change,
                                  help="지표 차이가 큰 경우 사용합니다. 0·음수가 있는 축은 자동으로 선형 눈금을 사용합니다.")
        c1, c2, c3 = st.columns(3)
        x_label = c1.selectbox("X축", labels, index=0, key="scatter_x", on_change=on_pick_change)
        y_label = c2.selectbox("Y축", labels, index=1, key="scatter_y", on_change=on_pick_change)
        size_labels = ["개발건수", "총비용", "광고비", "제작비", "디지털 광고비", "영상광고비",
                       "방송·재송출 광고비", "세부 캠페인 수", "통합 개발단가", "동일 크기"]
        size_label = c3.selectbox("풍선 크기", size_labels, index=0, key="scatter_size", on_change=on_pick_change)
        st.caption("설정은 산점도와 캠페인 선택 목록에만 적용됩니다. 상단 KPI·TOP 5·표의 집계 기준은 유지됩니다.")
    x_field, x_unit = SCATTER_METRICS[x_label]
    y_field, y_unit = SCATTER_METRICS[y_label]
    size_field = None if size_label == "동일 크기" else SCATTER_METRICS[size_label][0]
    visible, invalid_count = scatter_visible_frame(base, mode == "통합 캠페인만", x_field, y_field, size_field)
    if invalid_count:
        st.caption(f"선택 지표를 계산할 수 없거나 풍선 크기가 음수인 {invalid_count}개 캠페인은 산점도에서만 제외했습니다.")
    if x_field == y_field:
        st.caption("X축과 Y축이 같은 지표입니다. 서로 다른 지표를 선택하면 비교가 더 쉽습니다.")
    if visible.empty:
        st.session_state["pick_campaign"] = NONE_PICK
        st.info("선택 기간·필터·지표에 해당하는 통합 캠페인이 없습니다. 표시 대상을 전체로 바꾸거나 기간·지표를 조정하세요."
                if mode == "통합 캠페인만" else "선택 기간·필터·지표에 표시할 캠페인이 없습니다.")
        return top_all
    x_scale, x_log = scatter_axis_scale(visible[x_field], request_log)
    y_scale, y_log = scatter_axis_scale(visible[y_field], request_log)
    linear_axes = [label for label, log in [("X축", x_log), ("Y축", y_log)] if not log]
    if request_log and linear_axes:
        st.caption(" · ".join(linear_axes) + ": 0 또는 음수 값이 있어 선형 눈금으로 표시합니다.")
    pick_opts = [NONE_PICK] + sorted(visible["MARKETING_CAMPAIGN_NAME"].astype(str).unique().tolist())
    if st.session_state.get("pick_campaign") not in pick_opts:
        st.session_state["pick_campaign"] = NONE_PICK
    st.selectbox("캠페인 직접 선택", pick_opts, key="pick_campaign", on_change=on_pick_change,
                 help="풍선이 작거나 겹칠 때 목록에서 선택하세요.")
    axis = {"labelExpr": AXIS_LABEL_EXPR, "grid": True, "tickCount": 7,
            "labelColor": "#8B7F79", "titleColor": "#556A1F", "gridColor": "#E9EDE5",
            "domain": False, "tickColor": "#DCE3D6", "titlePadding": 24, "labelPadding": 10}
    encoding = {
        "x": {"field": x_field, "type": "quantitative", "title": f"{x_label} ({x_unit})", "scale": x_scale, "axis": dict(axis)},
        "y": {"field": y_field, "type": "quantitative", "title": f"{y_label} ({y_unit})", "scale": y_scale, "axis": dict(axis)},
        "color": {"field": "효율영역", "type": "nominal", "title": "통합 개발단가 구간",
                  "scale": {"domain": ["단가 낮음", "보통", "단가 높음", "산출 불가"],
                            "range": ["#89A230", "#C2B49A", "#F16521", "#A7B1AC"]},
                  "legend": {"orient": "top", "direction": "horizontal", "title": None, "labelColor": "#657267",
                             "symbolSize": 90, "columnPadding": 18, "offset": 4}},
        "stroke": {"field": "구성", "type": "nominal", "legend": None,
                   "scale": {"domain": ["통합", "단일"], "range": ["#556A1F", "#FFFFFF"]}},
        "strokeWidth": {"field": "구성", "type": "nominal", "legend": None,
                        "scale": {"domain": ["통합", "단일"], "range": [2.5, 1.1]}},
        "opacity": {"condition": {"param": "campaign_pick", "value": .9}, "value": .3},
        "tooltip": [{"field": "MARKETING_CAMPAIGN_NAME", "title": "캠페인"},
                    {"field": "구성", "title": "구성"},
                    {"field": "COMPONENT_COUNT", "title": "세부 캠페인 수", "format": ",.0f"}]
                   + [{"field": field, "title": label, "format": ",.0f"}
                      for label, (field, _) in SCATTER_METRICS.items() if field != "COMPONENT_COUNT"],
    }
    if size_field:
        encoding["size"] = {"field": size_field, "type": "quantitative", "title": size_label,
                            "scale": {"type": "linear", "zero": True, "range": [65, 1550]},
                            "legend": None}
    else:
        encoding["size"] = {"value": 260}
    spec = {
        "params": [{"name": "campaign_pick", "select": {"type": "point", "fields": ["MARKETING_CAMPAIGN_NAME"],
                    "on": "click", "clear": "dblclick", "toggle": False}}],
        "mark": {"type": "circle", "cursor": "pointer"}, "encoding": encoding,
        "padding": {"left": 28, "right": 32, "top": 18, "bottom": 18},
        "config": {"background": "#FFFFFF", "view": {"stroke": None},
                   "axis": {"labelFontSize": 12, "titleFontSize": 13},
                   "legend": {"labelFontSize": 12, "titleFontSize": 12}},
    }
    # 기간·필터·지표가 바뀌면 과거 차트의 선택 이벤트를 재사용하지 않습니다.
    hash_cols = ["MARKETING_CAMPAIGN_NAME", "TOTAL_COST", "DEVELOPMENT_COUNT", "COMPONENT_COUNT", x_field, y_field]
    hash_cols = list(dict.fromkeys(hash_cols + ([size_field] if size_field else [])))
    data_hash = int(pd.util.hash_pandas_object(visible[hash_cols], index=False).sum())
    context = repr((str(start_ts), str(end_ts), FILTERS, mode, x_field, y_field, size_field, request_log, data_hash))
    digest = sha256(context.encode("utf-8")).hexdigest()[:14]
    with st.container(border=True):
        event = render_chart(visible, spec, height=500,
                                  key=f"campaign_scatter_{st.session_state['scatter_ver']}_{digest}",
                                  on_select=on_chart_select, selection_mode="campaign_pick")
    clicked = selected_campaign_from_event(event)
    if clicked not in set(visible["MARKETING_CAMPAIGN_NAME"]):
        clicked = None
    picked = st.session_state.get("pick_campaign")
    shared = st.session_state.get("shared_campaign")
    if shared not in set(current_df["MARKETING_CAMPAIGN_NAME"]):
        shared = None
        st.session_state["shared_campaign"] = None
    selected = clicked or (picked if picked != NONE_PICK else None) or shared
    n_integrated = int(visible["구성"].eq("통합").sum())
    st.caption(f"표시 {len(visible):,}개 (통합 {n_integrated:,}개) · 색상: 통합 개발단가 구간(상대 비교) · 진한 테두리: 통합 캠페인 · "
               + ", ".join(SCATTER_EXCLUDE) + f" 제외 · 풍선 크기: {size_label} · 선택 해제: 닫기 또는 더블클릭")
    if selected:
        with st.container(border=True):
            campaign_detail_panel(selected, current_df, filtered, member_filtered, ga_filtered, detail_filtered,
                                  collab_filtered, "t1", on_close=close_detail, auto_map=AUTO_MAP)
    else:
        st.info("풍선을 클릭하면 광고 원천별 성과·세부 캠페인·월별 추이·회원 구성이 열립니다.")
    return top_all

if "01" in T:
    with T["01"]:
        section("1" if demo_mode else "01", "캠페인 통합 성과",
                "집행비용·개발성과·효율을 원하는 지표로 비교합니다. 풍선을 선택하면 구성 캠페인과 원천별 성과를 확인할 수 있습니다.")
        chart = render_campaign_scatter(current)
        low1, low2, low3, low4 = st.tabs(["주요 캠페인 TOP 5", "월별 통합 성과 흐름", "통합 캠페인별 성과 표", "통합 캠페인 구성"])
        with low1:
            if chart.empty:
                st.info("표시할 캠페인 데이터가 없습니다.")
            else:
                efficient = chart[(chart["DEVELOPMENT_COUNT"] >= TOP_EFFICIENCY_MIN_DEV)
                                  & (chart["DEVELOPMENT_UNIT_COST"] > TOP_EFFICIENCY_MIN_UNIT_COST)]
                efficient = efficient.sort_values(["DEVELOPMENT_UNIT_COST", "DEVELOPMENT_COUNT"], ascending=[True, False]).head(5)
                volume = chart.sort_values("DEVELOPMENT_COUNT", ascending=False).head(5)
                ga_top = ga_filtered[~ga_filtered["MARKETING_CAMPAIGN_NAME"].isin(SCATTER_EXCLUDE)].groupby("MARKETING_CAMPAIGN_NAME", as_index=False).agg(SETTLE_AMOUNT=("SETTLE_AMOUNT", "sum"), CONVERSION_VALUE=("CONVERSION_VALUE", "sum"))
                ga_top["GA_UNIT_COST"] = ga_top["SETTLE_AMOUNT"].div(ga_top["CONVERSION_VALUE"].replace(0, np.nan))
                ga_top = ga_top.dropna(subset=["GA_UNIT_COST"]).sort_values("GA_UNIT_COST").head(5)
                st.markdown('<div class="top5-wrap"></div>', unsafe_allow_html=True)
                with st.expander("TOP 5 선정 기준"):
                    st.caption(f"통합 효율: 개발 {TOP_EFFICIENCY_MIN_DEV:,}건 이상, 통합 개발단가 {TOP_EFFICIENCY_MIN_UNIT_COST:,}원 초과 중 단가 오름차순. GA 효율: 디지털 정산금액 ÷ GA 전환가치 오름차순. 개발건수: CRM 개발건수 내림차순. 기간·필터와 기존 집계 기준은 유지됩니다.")
                c1, c2, c3 = st.columns(3, gap="medium")
                with c1:
                    ranking_card("통합 효율 TOP 5",
                                 "통합 개발단가가 낮은 순",
                                 efficient, "DEVELOPMENT_UNIT_COST", won, "통합단가")
                with c2:
                    ranking_card("GA 효율 TOP 5", "전환가치당 비용이 낮은 순", ga_top, "GA_UNIT_COST", won, "GA 단가")
                with c3:
                    ranking_card("개발건수 TOP 5", "CRM 개발건수가 많은 순", volume, "DEVELOPMENT_COUNT", cnt, "개발건수")
        with low2:
            monthly_chart(filtered)
        with low3:
            tb = current[~current["MARKETING_CAMPAIGN_NAME"].isin(SCATTER_EXCLUDE)].copy()
            if tb.empty:
                st.info("표시할 캠페인이 없습니다.")
            else:
                f1, f2 = st.columns([2, 1.2])
                kw = f1.text_input("캠페인 검색", placeholder="예: 고려인, 유어턴", key="perf_kw")
                sort_by = f2.selectbox("정렬 기준", ["총비용 큰 순", "개발건수 많은 순", "통합 개발단가 낮은 순", "캠페인명 가나다순"], key="perf_sort")
                if kw.strip():
                    tb = tb[tb["MARKETING_CAMPAIGN_NAME"].astype(str).str.contains(kw.strip(), case=False, regex=False)]
                tb["UNIT"] = tb["TOTAL_COST"].div(tb["DEVELOPMENT_COUNT"].where(tb["DEVELOPMENT_COUNT"] > 0))
                order = {"총비용 큰 순": ("TOTAL_COST", False), "개발건수 많은 순": ("DEVELOPMENT_COUNT", False),
                         "통합 개발단가 낮은 순": ("UNIT", True), "캠페인명 가나다순": ("MARKETING_CAMPAIGN_NAME", True)}[sort_by]
                tb = tb.sort_values(order[0], ascending=order[1], na_position="last")
                total_cost = float(tb["TOTAL_COST"].sum())
                tb_view = pd.DataFrame({
                    "통합 캠페인": tb["MARKETING_CAMPAIGN_NAME"].astype(str),
                    "구분": np.where(tb["COMPONENT_COUNT"] > 1, "통합 " + tb["COMPONENT_COUNT"].astype(int).astype(str) + "개", "단일"),
                    "유형": tb["CAMPAIGN_TYPE1"].astype(str),
                    "제작비": tb["PRODUCTION_COST"], "디지털": tb["DIGITAL_AD_COST"], "영상광고": tb["VIDEO_AD_COST"],
                    "방송·재송출": tb["REBROADCAST_AD_COST"], "총비용": tb["TOTAL_COST"],
                    "비용 비중": tb["TOTAL_COST"] / total_cost if total_cost else np.nan,
                    "개발건수": tb["DEVELOPMENT_COUNT"], "통합 개발단가": tb["UNIT"], "_kind": "row",
                })
                tot = {"통합 캠페인": f"합계 ({len(tb_view):,}개)", "구분": "", "유형": "",
                       **{c: float(tb_view[c].sum()) for c in ["제작비", "디지털", "영상광고", "방송·재송출", "총비용", "개발건수"]},
                       "비용 비중": 1.0 if total_cost else np.nan, "_kind": "total"}
                tot["통합 개발단가"] = tot["총비용"] / tot["개발건수"] if tot["개발건수"] else np.nan
                tb_view = pd.concat([tb_view, pd.DataFrame([tot])], ignore_index=True)
                render_grid(tb_view, ["통합 캠페인", "구분", "유형"],
                            ["제작비", "디지털", "영상광고", "방송·재송출", "총비용", "비용 비중", "개발건수", "통합 개발단가"],
                            groups=[("제작", ["제작비"]), ("광고비", ["디지털", "영상광고", "방송·재송출"]),
                                    ("합계", ["총비용", "비용 비중"]), ("성과", ["개발건수", "통합 개발단가"])],
                            pct_cols=["비용 비중"])
                st.caption("채널·개발인입경로 목록은 캠페인 상세(풍선 클릭)에서 확인하세요. 원본 열 전체는 CSV로 받을 수 있습니다.")
                csv = current.rename(columns={
                    "MARKETING_CAMPAIGN_NAME": "통합 캠페인", "CAMPAIGN_TYPE1": "유형1", "CAMPAIGN_TYPE2": "유형2",
                    "CHANNEL_NAME": "채널", "DEVELOPMENT_INFLOW_PATH": "개발인입경로", "PRODUCTION_COST": "제작비",
                    "DIGITAL_AD_COST": "디지털 광고비", "VIDEO_AD_COST": "영상광고비", "REBROADCAST_AD_COST": "방송·재송출 광고비",
                    "AD_COST": "광고비", "TOTAL_COST": "총비용", "DEVELOPMENT_COUNT": "개발건수",
                    "COMPONENT_COUNT": "세부 캠페인 수", "DEVELOPMENT_UNIT_COST": "통합 개발단가"})
                st.download_button("전체 열 CSV 다운로드", csv.to_csv(index=False).encode("utf-8-sig"),
                                   file_name="campaign_performance.csv", mime="text/csv")
        with low4:
            st.caption(
                "여러 세부 캠페인을 한 캠페인으로 합친 경우만 보여줍니다. 통합 방식: 통합표 지정(코드의 CAMPAIGN_ROLLUP에 적은 캠페인), "
                "방송 UTM 공유 자동 통합(방송 캠페인과 UTM을 공유하는 디지털 캠페인을 자동으로 합친 경우)."
            )
            ov = integration_overview_frame(filtered, AUTO_MAP)
            if ov.empty:
                st.info("선택 기간에 여러 캠페인을 합친 통합 캠페인이 없습니다.")
            else:
                render_grid(
                    ov, ["통합 캠페인", "세부 캠페인", "통합 방식"],
                    ["광고비", "제작비", "총비용", "개발건수", "통합 개발단가"],
                    groups=[("비용", ["광고비", "제작비", "총비용"]), ("회원개발", ["개발건수"]), ("단가", ["통합 개발단가"])],
                )
            comps_now = set(filtered["COMPONENT_CAMPAIGN_NAME"]) | set(filtered["MARKETING_CAMPAIGN_NAME"])
            pair_rows = [{"디지털 캠페인": d_, "통합 대상 방송 캠페인": b_, "적용": "적용 중" if auto_rollup else "꺼짐(사이드바에서 켜기)"}
                         for d_, b_ in sorted(AUTO_PAIRS.items()) if d_ in comps_now]
            with st.expander(f"방송 UTM 공유 자동 통합 대상 ({len(pair_rows)}건)"):
                if cand_error is not None:
                    st.warning("통합 후보를 조회하지 못했습니다. 자동 통합은 적용되지 않고, 통합표 지정만 반영됩니다.")
                if pair_rows:
                    show_df(pd.DataFrame(pair_rows), use_container_width=True, hide_index=True)
                    st.caption("이 통합을 영구 규칙으로 고정하려면 코드 상단 CAMPAIGN_ROLLUP에 아래 줄을 추가하세요. 고정하면 자동 통합을 꺼도 유지됩니다.")
                    st.code("\n".join(f'    ("{d_}", "{b_}"),' for d_, b_ in sorted(AUTO_PAIRS.items()) if d_ in comps_now), language="python")
                else:
                    st.info("선택 기간에 자동 통합 대상이 없습니다.")
            amb_rows = []
            for d_, targets in sorted(AMBIGUOUS.items()):
                cur_row = current[current["MARKETING_CAMPAIGN_NAME"] == d_]
                amb_rows.append({"디지털 캠페인": d_, "UTM을 공유하는 방송 캠페인": " | ".join(targets),
                                 "광고비+제작비": float(cur_row["TOTAL_COST"].sum()), "개발건수": float(cur_row["DEVELOPMENT_COUNT"].sum())})
            amb_rows = [r_ for r_ in amb_rows if r_["광고비+제작비"] != 0 or r_["개발건수"] != 0]
            with st.expander(f"자동 통합하지 못한 후보 — 방송 캠페인 여러 개와 UTM 공유 ({len(amb_rows)}건)"):
                if amb_rows:
                    show_df(pd.DataFrame(amb_rows), use_container_width=True, hide_index=True)
                    st.caption("어느 방송 캠페인에 합칠지 알 수 없어 따로 표시합니다. 합칠 대상을 정하면 CAMPAIGN_ROLLUP에 (디지털 캠페인, 방송 캠페인) 형태로 추가하세요.")
                else:
                    st.info("선택 기간에 해당하는 후보가 없습니다.")

if "02" in T:
    with T["02"]:
        section("02", "비용·GA 상세", "광고 원천·채널별 비용과 노출·클릭·전환 성과를 비교합니다.")
        st.markdown("#### 광고 원천별 비용 (선택 기간, 캠페인 귀속분)")
        st.caption("원천마다 '소계' 줄 아래에 CRM 개발인입경로별 줄을 펼쳐 보여줍니다. 광고비·노출·클릭·전환가치는 원천 소계 줄에만 있고, 개발건수·제작비는 개발인입경로별로 나뉩니다. 재송출 원천은 구분 열에 따라 '방송'과 '재송출'로 나눕니다. 개발인입경로 매핑: 디지털→디지털, 영상광고→영상광고, 방송·뉴미디어→방송, 재송출→재송출, 그 밖(콜개발·회원 등)은 '광고 원천 없음'입니다. 공통비는 포함하지 않습니다.")
        src_tbl = source_summary_table(filtered, detail_filtered)
        if src_tbl.empty:
            st.info("표시할 광고비가 없습니다.")
        else:
            show_df(src_tbl, use_container_width=True, hide_index=True)

        st.markdown("#### 채널별 통합 성과")
        st.caption("개발건수는 캠페인코드의 채널, 광고비는 광고 원천의 채널 기준으로 같은 채널끼리 합칩니다. 전환가치는 디지털 대행사 리포트 기준이며, CRM 개발단가 = 소계 ÷ 개발건수, GA 개발단가 = 디지털 ÷ 전환가치입니다. 공통비는 포함하지 않습니다.")
        chp = channel_table_data(filtered, detail_filtered)
        render_channel_grid(chp)
        if not chp.empty:
            st.download_button("채널별 통합 성과 CSV 다운로드", chp.to_csv(index=False).encode("utf-8-sig"),
                               file_name="channel_performance.csv", mime="text/csv")
        crm_part = filtered[filtered["ROW_KIND"].isin(["CRM", "ERP"])]
        if not crm_part.empty:
            with st.expander("채널·개발인입경로별 개발성과 (캠페인코드 기준)"):
                ci = crm_part.groupby(["CHANNEL_NAME", "DEVELOPMENT_INFLOW_PATH"], as_index=False).agg(
                    개발건수=("DEVELOPMENT_COUNT", "sum"), 제작비=("PRODUCTION_COST", "sum"), 캠페인수=("MARKETING_CAMPAIGN_NAME", "nunique")
                ).sort_values("개발건수", ascending=False).rename(columns={"CHANNEL_NAME": "채널", "DEVELOPMENT_INFLOW_PATH": "개발인입경로"})
                show_df(ci, use_container_width=True, hide_index=True, height=300)
        if not any_filter:
            cmn = detail_period[detail_period["MAPPING_STATUS"].eq(COMMON_STATUS)]
            if not cmn.empty:
                st.markdown("#### 공통비(검색·브랜드) 채널별")
                show_df(digital_metrics(cmn, ["SOURCE_CAMPAIGN", "CHANNEL"]).rename(columns={"SOURCE_CAMPAIGN": "원천 캠페인명", "CHANNEL": "채널"}),
                        use_container_width=True, hide_index=True, height=260)
        g = ga_filtered[["IMPRESSION_COUNT", "CLICK_COUNT", "SPONSOR_COUNT", "CONVERSION_VALUE", "SETTLE_AMOUNT"]].sum()
        a, b, c, d, e = st.columns(5)
        a.metric("노출수", f'{g["IMPRESSION_COUNT"]:,.0f}')
        b.metric("클릭수", f'{g["CLICK_COUNT"]:,.0f}')
        c.metric("GA CTR", pct(div0(g["CLICK_COUNT"], g["IMPRESSION_COUNT"])))
        d.metric("GA CVR", pct(div0(g["SPONSOR_COUNT"], g["CLICK_COUNT"])))
        e.metric("GA 개발단가", won(div0(g["SETTLE_AMOUNT"], g["CONVERSION_VALUE"])))
        if not current.empty:
            cost = current.sort_values("TOTAL_COST", ascending=False).head(10).set_index("MARKETING_CAMPAIGN_NAME")
            cost_comparison_chart(cost)
        ga_table = ga_filtered.groupby(["MARKETING_CAMPAIGN_NAME", "AD_TYPE", "MEDIA_NAME"], as_index=False).agg(SETTLE_AMOUNT=("SETTLE_AMOUNT", "sum"), CONVERSION_VALUE=("CONVERSION_VALUE", "sum"), SPONSOR_COUNT=("SPONSOR_COUNT", "sum"), CLICK_COUNT=("CLICK_COUNT", "sum"), IMPRESSION_COUNT=("IMPRESSION_COUNT", "sum"))
        ga_table["GA_CTR"] = ga_table["CLICK_COUNT"].div(ga_table["IMPRESSION_COUNT"].replace(0, np.nan))
        ga_table["GA_CVR"] = ga_table["SPONSOR_COUNT"].div(ga_table["CLICK_COUNT"].replace(0, np.nan))
        ga_table["GA_UNIT_COST"] = ga_table["SETTLE_AMOUNT"].div(ga_table["CONVERSION_VALUE"].replace(0, np.nan))
        show_df(ga_table, use_container_width=True, hide_index=True)

if "03" in T:
    with T["03"]:
        section("03", "캠페인 상세", "통합 캠페인을 골라 광고 원천·세부 캠페인, 회원 구성을 함께 확인합니다.")
        options = current.sort_values("TOTAL_COST", ascending=False)["MARKETING_CAMPAIGN_NAME"].astype(str).tolist()
        if options:
            name = st.selectbox("상세 캠페인", options)
            with st.container(border=True):
                campaign_detail_panel(name, current, filtered, member_filtered, ga_filtered, detail_filtered, collab_filtered, "t3", auto_map=AUTO_MAP)
        else:
            st.info("상세 조회할 캠페인이 없습니다.")

if "04" in T:
    with T["04"]:
        section("04", "캠페인 오픈 주차", "선택 기간 내 첫 디지털 집행일부터 7일 단위로 GA 광고성과를 비교합니다.")
        if ga_filtered.empty:
            st.info("GA 데이터가 없습니다.")
        else:
            week_names = st.multiselect("비교 캠페인", ga_filtered.groupby("MARKETING_CAMPAIGN_NAME")["SETTLE_AMOUNT"].sum().sort_values(ascending=False).index.tolist(), max_selections=8)
            if week_names:
                w = ga_filtered[ga_filtered["MARKETING_CAMPAIGN_NAME"].isin(week_names)].copy()
                opens = w.groupby("MARKETING_CAMPAIGN_NAME")["PERFORMANCE_DATE"].min().rename("OPEN_DATE")
                w = w.join(opens, on="MARKETING_CAMPAIGN_NAME")
                w["OPEN_WEEK"] = (w["PERFORMANCE_DATE"].sub(w["OPEN_DATE"]).dt.days // 7 + 1).astype(int)
                wk = w.groupby(["MARKETING_CAMPAIGN_NAME", "OPEN_WEEK"], as_index=False).agg(SETTLE_AMOUNT=("SETTLE_AMOUNT", "sum"), CONVERSION_VALUE=("CONVERSION_VALUE", "sum"), CLICK_COUNT=("CLICK_COUNT", "sum"), IMPRESSION_COUNT=("IMPRESSION_COUNT", "sum"), SPONSOR_COUNT=("SPONSOR_COUNT", "sum"))
                wk["GA_UNIT_COST"] = wk["SETTLE_AMOUNT"].div(wk["CONVERSION_VALUE"].replace(0, np.nan))
                wk["GA_CTR"] = wk["CLICK_COUNT"].div(wk["IMPRESSION_COUNT"].replace(0, np.nan))
                wk["GA_CVR"] = wk["SPONSOR_COUNT"].div(wk["CLICK_COUNT"].replace(0, np.nan))
                open_week_chart(wk)
                show_df(wk, use_container_width=True, hide_index=True)
            else:
                st.caption("비교할 캠페인을 선택해 주세요.")

if "05" in T:
    with T["05"]:
        show_ad_mapping_audit()
        section("05", "데이터 점검", "비용·CRM·GA 연결 누락과 기준정보 미입력을 확인합니다.")
        if current.empty:
            st.info("점검할 데이터가 없습니다.")
        else:
            checks = {
                "CRM 개발건수 0": current[current["DEVELOPMENT_COUNT"] == 0],
                "제작비 0: 미연결 여부 확인": current[current["PRODUCTION_COST"] == 0],
                "광고비 0: 미연결 여부 확인": current[current["AD_COST"] == 0],
                "캠페인 유형 미분류": current[current["CAMPAIGN_TYPE1"].str.contains("미분류", na=False)],
                "채널 미분류": current[current["CHANNEL_NAME"].str.contains("미분류", na=False)],
                "GA 미연결": current[~current["MARKETING_CAMPAIGN_NAME"].isin(set(ga_filtered["MARKETING_CAMPAIGN_NAME"]))],
                "회원구성 미연결": current[~current["MARKETING_CAMPAIGN_NAME"].isin(set(member_filtered["MARKETING_CAMPAIGN_NAME"]))],
            }
            boxes = st.columns(4)
            for i, (label, data) in enumerate(checks.items()):
                boxes[i % 4].metric(label, f"{len(data):,}개")
            picked = st.selectbox("점검 항목", list(checks))
            show_df(checks[picked], use_container_width=True, hide_index=True)

if "06" in T:
    with T["06"]:
        section("06", "UTM 보기", "디지털 광고비를 UTM 단위로 묶어 봅니다. 캠페인 귀속과 상관없이 같은 UTM의 전체 성과와, 그 안에서 캠페인별로 어떻게 귀속됐는지 확인합니다. UTM은 원천 표기로 표시합니다.")
        dig = detail_period[detail_period["SOURCE_TYPE"].eq("DIGITAL")].copy()
        if dig.empty:
            st.info("선택 기간에 디지털 광고 데이터가 없습니다.")
        else:
            dig["UTM_KEY"] = dig["UTM_KEY"].fillna("[UTM 없음]")
            dig["UTM_RAW"] = dig["UTM_RAW"].fillna("[UTM 없음]")
            disp = dig.groupby("UTM_KEY")["UTM_RAW"].agg(join_variants).rename("UTM")
            dig = dig.join(disp, on="UTM_KEY")
            dig["귀속 캠페인"] = dig["COMPONENT_CAMPAIGN_NAME"].fillna("[미귀속]")
            dig["통합 캠페인"] = dig["MARKETING_CAMPAIGN_NAME"].fillna("[미귀속]")
            utm_sum = dig.groupby(["UTM_KEY", "UTM"], as_index=False).agg(
                광고비=("COST", "sum"), 노출수=("IMPRESSIONS", "sum"), 클릭수=("CLICKS", "sum"),
                전환가치=("CONVERSIONS", "sum"), 후원자수=("SPONSORS", "sum"),
                귀속캠페인수=("귀속 캠페인", "nunique"),
                귀속상태=("MAPPING_STATUS", lambda s: ", ".join(sorted(set(s.dropna().astype(str))))),
            )
            utm_sum["CTR"] = utm_sum["클릭수"].div(utm_sum["노출수"].replace(0, np.nan))
            utm_sum["전환가치당 비용"] = utm_sum["광고비"].div(utm_sum["전환가치"].replace(0, np.nan))
            utm_sum = utm_sum.sort_values("광고비", ascending=False)

            f1, f2 = st.columns([2, 1])
            keyword = f1.text_input("UTM 검색 (대소문자 구분 없음)", placeholder="예: turn24b, meal24a")
            only_multi = f2.checkbox("여러 캠페인이 쓰거나 미귀속인 UTM만 보기", value=False)
            view = utm_sum.copy()
            if keyword.strip():
                view = view[view["UTM"].str.contains(keyword.strip(), case=False, na=False, regex=False)]
            if only_multi:
                view = view[view["귀속캠페인수"].gt(1) | view["귀속상태"].str.contains("콜라보|미연결|다중|공통비", na=False)]
            u1, u2, u3 = st.columns(3)
            u1.metric("UTM 수", f"{len(view):,}개")
            u2.metric("디지털 광고비", won(view["광고비"].sum()))
            u3.metric("전환가치", cnt(view["전환가치"].sum()))
            show_cols = [c for c in view.columns if c != "UTM_KEY"]
            show_df(view[show_cols], use_container_width=True, hide_index=True, height=320)
            st.download_button("UTM 요약 CSV 다운로드", view[show_cols].to_csv(index=False).encode("utf-8-sig"),
                               file_name="utm_summary.csv", mime="text/csv")
            st.caption("대소문자만 다른 표기는 같은 UTM으로 연결되며, 'turn24b / TURN24B'처럼 함께 표시됩니다.")

            if not view.empty:
                labels = dict(zip(view["UTM"], view["UTM_KEY"]))
                pick_label = st.selectbox("상세로 볼 UTM", list(labels.keys()))
                one = dig[dig["UTM_KEY"].eq(labels[pick_label])]
                s = one[["COST", "IMPRESSIONS", "CLICKS", "CONVERSIONS", "SPONSORS"]].sum()
                m1, m2, m3, m4, m5 = st.columns(5)
                m1.metric("광고비", won(s["COST"]))
                m2.metric("노출수", f'{s["IMPRESSIONS"]:,.0f}')
                m3.metric("클릭수", f'{s["CLICKS"]:,.0f}')
                m4.metric("CTR", pct(div0(s["CLICKS"], s["IMPRESSIONS"])))
                m5.metric("전환가치당 비용", won(div0(s["COST"], s["CONVERSIONS"])))

                st.markdown("##### 캠페인별 귀속")
                st.caption("각 행은 원천 캠페인명 기준으로 귀속된 결과입니다. 같은 UTM이라도 각자 쓴 비용이 각자에게 귀속됩니다.")
                by_camp = digital_metrics(one, ["통합 캠페인", "귀속 캠페인", "SOURCE_CAMPAIGN", "MAPPING_STATUS"]).rename(
                    columns={"SOURCE_CAMPAIGN": "원천 캠페인명", "MAPPING_STATUS": "귀속 상태"})
                by_camp["비중"] = by_camp["광고비"].div(by_camp["광고비"].sum() or np.nan)
                show_df(by_camp, use_container_width=True, hide_index=True)

                left, right = st.columns([1, 1.3])
                with left:
                    st.markdown("##### 채널별")
                    show_df(digital_metrics(one, ["CHANNEL"]).rename(columns={"CHANNEL": "채널"}), use_container_width=True, hide_index=True, height=300)
                with right:
                    st.markdown("##### 월별 광고비")
                    mon = one.assign(MONTH=one["PERFORMANCE_DATE"].dt.to_period("M").astype(str)).groupby(["MONTH", "귀속 캠페인"], as_index=False)["COST"].sum()
                    spec = {"mark": {"type": "bar"}, "encoding": {
                        "x": {"field": "MONTH", "type": "ordinal", "title": None},
                        "y": {"field": "COST", "type": "quantitative", "title": "광고비(원)", "stack": True},
                        "color": {"field": "귀속 캠페인", "type": "nominal"},
                        "tooltip": [{"field": "MONTH"}, {"field": "귀속 캠페인"}, {"field": "COST", "format": ",.0f"}]}}
                    spec["encoding"]["x"]["axis"] = {"labelAngle": 0, "labelOverlap": "greedy", "values": mon["MONTH"].tolist()[::max(1, int(np.ceil(len(mon)/9)))], "grid": False}
                    spec["encoding"]["y"]["axis"] = {"labelExpr": CHART_NUMBER_EXPR, "tickCount": 5}
                    spec["mark"] = {"type": "bar", "color": "#89A230", "cornerRadiusEnd": 3}
                    spec["encoding"]["tooltip"] = [{"field": "MONTH", "title": "월"}, {"field": "COST", "title": "광고비(원)", "format": ",.0f"}]
                    render_chart(mon, spec, height=320)

if "07" in T:
    with T["07"]:
        section("2" if demo_mode else "07", "팀별 실적", "나눔마케팅본부 팀 × 개발인입경로 기준으로 개발건수·광고비·제작비를 보고, 목표 대비 잔여 개발건과 필요 비용을 확인합니다.")
        st.caption(
            "개발건수: 월별 회원개발 요약의 실적부서 기준(캠페인 연결 여부와 상관없이 전부 포함, 소수 4자리) · 제작비: 캠페인코드의 사용부서 기준(캠페인코드가 없는 ERP 제작비는 제외) · "
            "광고비: 광고 원천 규칙(디지털·영상광고·재송출=매체운영팀, 방송=원방송 담당 팀). 사이드바의 기간과 유형·채널·개발인입경로 필터를 따릅니다."
        )
        sel_teams = st.multiselect("팀", TEAMS, default=TEAMS, key="team_pick")

        bt_df = derive_broadcast_team_map(team_dev)
        bt_map = dict(zip(bt_df["캠페인"], bt_df["담당 팀"])) if not bt_df.empty else {}
        erp_rows = filtered[filtered["ROW_KIND"].eq("ERP")]
        tl = team_long(team_dev_period, erp_rows, detail_filtered, bt_map)
        base = tl.groupby(["TEAM", "INFLOW"], as_index=False)[["개발건수", "광고비", "제작비"]].sum()

        def render_team_table():
            st.markdown("#### 팀 × 개발인입경로 실적 (선택 기간)")
            frame = team_grid_frame(base, sel_teams, ["개발건수", "광고비", "제작비"])
            if frame.empty:
                st.info("선택한 팀·기간에 표시할 실적이 없습니다.")
                return
            frame["총비용"] = frame["광고비"] + frame["제작비"]
            frame["개발단가"] = frame["총비용"].div(frame["개발건수"].replace(0, np.nan))
            frame.loc[frame["총비용"].eq(0), "개발단가"] = np.nan
            frame["비고"] = frame["개발인입경로"].map(INFLOW_NOTE).fillna("")
            render_grid(
                frame, ["팀", "개발인입경로"], ["개발건수", "광고비", "제작비", "총비용", "개발단가"],
                groups=[("회원개발(건)", ["개발건수"]), ("총 집행비용", ["광고비", "제작비", "총비용"]), ("개발단가", ["개발단가"])],
                note_col="비고", dec_cols=["개발건수"],
            )
            st.caption("개발단가 = (광고비 + 제작비) ÷ 개발건수. 방송 줄의 광고비는 구분이 '방송'인 재송출 원천 광고비이고, 뉴미디어 개발건수는 방송 광고비에 포함되어 단가를 따로 계산하지 않습니다.")
            st.download_button("팀 × 개발인입경로 실적 CSV 다운로드", frame.drop(columns=["_kind"]).to_csv(index=False).encode("utf-8-sig"),
                               file_name="team_inflow_performance.csv", mime="text/csv")

        def render_goal_block():
            st.markdown("#### 잔여 목표와 필요 비용")
            if goal_error is not None:
                st.warning("목표 테이블(BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV)을 조회하지 못했습니다. 조회 권한을 확인해주세요.")
                st.exception(goal_error)
                return
            if goals.empty:
                st.info("목표 테이블에서 '" + GOAL_TYPE_NAME + "' 목표를 찾지 못했습니다.")
                return
            years = sorted(goals["GOAL_YEAR"].unique().tolist(), reverse=True)
            default_year = str(end_ts.year) if str(end_ts.year) in years else years[0]
            g1, g2, g3 = st.columns([1, 2.4, 1])
            goal_year = g1.selectbox("목표 연도", years, index=years.index(default_year), key="goal_year")
            versions = list_versions(goals, goal_year)
            version = g2.radio("목표 구분", versions, horizontal=True, key=f"goal_version_{goal_year}", format_func=version_label)
            gy = int(goal_year)
            if end_ts.year == gy:
                default_cut = last_closed_month(end_ts)
            elif end_ts.year > gy:
                default_cut = 12
            else:
                default_cut = 1
            cutoff = g3.selectbox("누계 기준월", list(range(1, 13)), index=default_cut - 1,
                                  format_func=lambda m: f"{m}월", key=f"goal_cut_{goal_year}_{default_cut}")
            st.caption(
                "목표는 '" + GOAL_TYPE_NAME + "' 목표이며 법인(사단·사복)을 합산했습니다. 연목표는 매년 1월, 추가경정목표는 11월에 등록되며, "
                "새 목표 구분이 등록되면 위 목록에 자동으로 나타납니다. 선택한 구분이 해당 연도의 전체 목표라고 보고 계산합니다. "
                "누계 실적은 목표 연도 1월부터 누계 기준월까지이며, 누계 기준월 기본값은 조회 종료일까지 마감된 마지막 달입니다."
            )
            if any_filter:
                st.warning("사이드바 필터가 적용 중입니다. 목표는 필터되지 않아 달성률이 실제보다 낮게 보일 수 있습니다.")

            month_cols = [f"M{m:02d}" for m in range(1, 13)]
            gsel = goals[(goals["GOAL_YEAR"] == goal_year) & (goals["BDGT_PRCD_NM"] == version)].copy()
            gsel["연목표"] = gsel[month_cols].sum(axis=1)
            gsel["누계 목표"] = gsel[month_cols[:cutoff]].sum(axis=1)
            goal_g = gsel.groupby(["TEAM_NM", "INFLOW"], as_index=False)[["연목표", "누계 목표"]].sum().rename(columns={"TEAM_NM": "TEAM"})

            act = team_dev_f[(team_dev_f["PERFORMANCE_MONTH"].dt.year == gy) & (team_dev_f["PERFORMANCE_MONTH"].dt.month <= cutoff)]
            actual_g = act.groupby(["DEPARTMENT_NAME", "DEVELOPMENT_INFLOW_PATH"], as_index=False)["DEVELOPMENT_COUNT"].sum().rename(
                columns={"DEPARTMENT_NAME": "TEAM", "DEVELOPMENT_INFLOW_PATH": "INFLOW", "DEVELOPMENT_COUNT": "누계 실적"})
            unit_g = base.rename(columns={"개발건수": "단가_개발건수", "광고비": "단가_광고비", "제작비": "단가_제작비"})[
                ["TEAM", "INFLOW", "단가_개발건수", "단가_광고비", "단가_제작비"]]

            gframe = goal_progress_frame(goal_g, actual_g, unit_g, sel_teams, 12 - cutoff)
            if gframe.empty:
                st.info("선택한 팀·연도에 표시할 목표가 없습니다.")
                return
            tot = gframe[gframe["_kind"] == "total"].iloc[0]
            need_total = tot["필요 비용"] if not isinstance(tot["필요 비용"], str) else np.nan
            mm1, mm2, mm3, mm4, mm5 = st.columns(5)
            mm1.metric("연목표", f"{tot['연목표']:,.0f}건" if pd.notna(tot["연목표"]) else "-")
            mm2.metric(f"누계 실적 (1~{cutoff}월)", f"{tot['누계 실적']:,.4f}".rstrip("0").rstrip(".") + "건")
            mm3.metric("누계 달성률", f"{tot['누계 달성률']*100:,.1f}%" if pd.notna(tot["누계 달성률"]) else "-")
            mm4.metric("잔여 개발건", f"{tot['잔여 개발건']:,.0f}건" if pd.notna(tot["잔여 개발건"]) else "-")
            mm5.metric("필요 비용 (산출 가능분)", won(need_total) if pd.notna(need_total) else "-")
            render_grid(
                gframe, ["팀", "개발인입경로"],
                ["연목표", "누계 목표", "누계 실적", "누계 달성률", "잔여 개발건", "월 필요 건수", "현재 단가", "필요 비용"],
                groups=[("목표", ["연목표", "누계 목표"]), ("실적", ["누계 실적", "누계 달성률"]),
                        ("잔여 목표", ["잔여 개발건", "월 필요 건수"]), ("필요 비용(추정)", ["현재 단가", "필요 비용"])],
                note_col="비고", dec_cols=["연목표", "누계 목표", "누계 실적", "잔여 개발건"], pct_cols=["누계 달성률"],
            )
            st.caption(
                "누계 달성률 = 누계 실적 ÷ 누계 목표. 잔여 개발건 = 연목표 − 누계 실적(줄별 계산, 초과 달성한 줄은 0)이며 소계는 줄을 합산합니다. "
                "월 필요 건수 = 잔여 개발건 ÷ 남은 개월 수(" + str(12 - cutoff) + "개월). "
                "현재 단가 = 사이드바 선택 기간의 (광고비 + 제작비) ÷ 개발건수(같은 팀·개발인입경로)이며, 광고비 또는 개발건수가 없는 줄은 '산출불가'입니다. "
                "필요 비용 = 잔여 개발건 × 현재 단가로, 현재 단가가 유지된다는 가정의 추정치입니다. 소계·본부 소계는 산출 가능한 줄만 합산합니다."
            )
            st.download_button("잔여 목표·필요 비용 CSV 다운로드", gframe.drop(columns=["_kind"]).to_csv(index=False).encode("utf-8-sig"),
                               file_name="goal_progress.csv", mime="text/csv")

        def render_monthly():
            st.markdown("#### 월별 팀 × 개발인입경로")
            metric_pick = st.radio("지표", ["개발건수", "광고비", "제작비"], horizontal=True, key="team_metric")
            months = [str(p) for p in pd.period_range(start_ts, end_ts, freq="M")]
            if len(months) > 24:
                months = months[-24:]
                st.caption("기간이 길어 최근 24개월만 표시합니다.")
            mm = tl.groupby(["TEAM", "INFLOW", "MONTH"], as_index=False)[metric_pick].sum()
            if mm.empty:
                st.info("표시할 월별 실적이 없습니다.")
                return
            pv = mm.pivot_table(index=["TEAM", "INFLOW"], columns="MONTH", values=metric_pick, aggfunc="sum", fill_value=0).reset_index()
            pv.columns.name = None
            for m in months:
                if m not in pv.columns:
                    pv[m] = 0.0
            pv["합계"] = pv[months].sum(axis=1)
            pv = pv[pv["합계"].ne(0)]
            mframe = team_grid_frame(pv, sel_teams, months + ["합계"])
            render_grid(mframe, ["팀", "개발인입경로"], months + ["합계"],
                        dec_cols=(months + ["합계"]) if metric_pick == "개발건수" else ())

        # 간단히 보기: 목표 달성 현황(잔여 목표)을 먼저, 팀 × 개발인입경로 실적은 그다음에 보여줍니다.
        if demo_mode:
            with st.container(border=True):
                render_goal_block()
            with st.container(border=True):
                render_team_table()
            with st.expander("월별 팀 × 개발인입경로"):
                render_monthly()
        else:
            with st.container(border=True):
                render_team_table()
            with st.container(border=True):
                render_goal_block()
            with st.container(border=True):
                render_monthly()

        other = tl[tl["TEAM"].isin([UNASSIGNED_TEAM, OTHER_DEPT])]
        if not other.empty:
            with st.expander("팀 미지정·본부 외 부서 실적 (위 본부 소계에 포함되지 않음)"):
                st.caption("팀 미지정: 담당 팀을 정하지 못한 방송 광고비, 사용부서가 비어 있는 캠페인코드의 제작비 / 본부 외 부서: 나눔마케팅본부 4개 팀 밖의 부서 실적")
                ot = other.groupby(["TEAM", "INFLOW"], as_index=False)[["개발건수", "광고비", "제작비"]].sum().rename(columns={"TEAM": "구분", "INFLOW": "개발인입경로"})
                show_df(ot, use_container_width=True, hide_index=True)

        with st.expander("방송 원방송 담당 팀 지정표"):
            st.caption("방송 광고비는 원방송(통합 캠페인) 단위로 담당 팀에 귀속합니다. 방송 개발건수가 많은 팀(마케팅기획1팀·2팀)으로 자동 지정하며, 코드 상단 BROADCAST_TEAM_OVERRIDE에 적은 캠페인은 직접 지정이 우선합니다.")
            if bt_df.empty:
                st.info("지정할 방송 캠페인이 없습니다.")
            else:
                show_df(bt_df, use_container_width=True, hide_index=True, height=320)
            bro = detail_period[detail_period["SOURCE_GROUP"].eq("BROADCAST") & detail_period["MAPPING_STATUS"].eq("단일 귀속")]
            assigned_names = {c for c, t in bt_map.items() if t in BROADCAST_TEAMS}
            un = bro[~bro["MARKETING_CAMPAIGN_NAME"].isin(assigned_names)]
            if un.empty:
                st.success("선택 기간의 방송 광고비는 모두 담당 팀이 지정되어 있습니다.")
            else:
                un = un.assign(MARKETING_CAMPAIGN_NAME=un["MARKETING_CAMPAIGN_NAME"].fillna("[미귀속]"))
                unc = un.groupby("MARKETING_CAMPAIGN_NAME", as_index=False)["COST"].sum().rename(columns={"MARKETING_CAMPAIGN_NAME": "원방송 캠페인", "COST": "방송 광고비"}).sort_values("방송 광고비", ascending=False)
                st.warning("담당 팀이 없어 '팀 미지정'으로 들어간 방송 광고비입니다. BROADCAST_TEAM_OVERRIDE에 캠페인명과 팀을 추가하면 지정됩니다.")
                show_df(unc, use_container_width=True, hide_index=True)

if not demo_mode:
    with st.expander("현재 적용 기준 및 확인 항목"):
        st.write("핵심 2화면만 보기: 사이드바에서 켜면 통합 성과와 팀별 실적·잔여 목표 두 화면만 보여줍니다. 끄면 전체 탭이 표시됩니다.")
        st.write("통합 성과 산점도: x축·y축·풍선 크기를 각각 선택할 수 있습니다. 기본은 통합 개발단가 / 총비용 / 개발건수입니다. 통합 캠페인만 보기 설정은 산점도와 직접 선택 목록에만 적용되고 TOP 5·상단 KPI·표에는 적용되지 않습니다. 금액 차이가 커서 기본은 로그 눈금이며 끌 수 있습니다. 풍선 클릭 또는 목록 선택으로 상세가 열리고 '닫기'로 접습니다. 코드 상단 SCATTER_EXCLUDE에 적은 캠페인(현재 24년 이전컨텐츠)은 산점도·TOP 5에서 제외하며 상단 카드와 표에는 포함됩니다.")
        st.write("방송 소스 디지털 캠페인 통합: 방송 캠페인과 그 소스로 진행한 디지털 캠페인은 한 캠페인으로 합쳐 효율을 계산하고, 세부 캠페인(마케팅명)은 풍선 상세의 '세부 캠페인' 탭에 표시합니다. 통합표(CAMPAIGN_ROLLUP)에 지정한 캠페인에 더해, 방송 캠페인과 UTM을 공유하고 그 방송 캠페인이 하나로 정해지는 디지털 캠페인을 자동 통합합니다(사이드바에서 끌 수 있음). 방송 캠페인 여러 개와 UTM을 공유하는 디지털 캠페인은 합치지 않고 '통합 캠페인 구성' 탭에 후보로만 표시합니다.")
        st.write("선택 캠페인의 광고 원천별 성과: 원천 줄에 대응하는 CRM 개발인입경로를 함께 보여주고, '채널별 세부 보기'를 켜면 원천 아래에 채널별 광고비·개발건수가 펼쳐집니다.")
        st.write("기본 분석 범위는 전체(2024년 이후): 2024.01.01부터 데이터 최종일까지입니다. 올해는 데이터 최종 연도의 1월 1일부터이며, 전체 기간은 2024년 이전 원천도 포함합니다. 2024년 이전 제작비를 포함하는 캠페인 생애 누적 단가와는 다릅니다.")
        st.write("통합 캠페인(원방송) 기준: 개별 디지털 캠페인을 원방송으로 모아 광고비(디지털·영상광고·재송출), CRM 개발건수, ERP 제작비, GA, 회원구성을 함께 집계합니다. 매핑표는 코드 상단 CAMPAIGN_ROLLUP입니다.")
        st.write("팀별 실적(07 탭): 개발건수는 월별 회원개발 요약의 실적부서(캠페인 연결 여부와 상관없이 전부 포함), 제작비는 ERP 제작비가 연결된 캠페인코드의 사용부서(USE_DEPT_CD), 광고비는 원천 규칙(디지털·영상광고·재송출=매체운영팀, 방송=원방송 담당 팀)으로 팀에 붙입니다. 콜개발 광고비는 광고 원천이 없어 없습니다. 공통비는 팀에 배분하지 않습니다.")
        st.write("잔여 목표(07 탭): 목표는 BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV의 '" + GOAL_TYPE_NAME + "' 목표(법인 사단·사복 합산, 개발인입경로=DTL_DIV_NM)이며, 목표 구분(연사업·추가경정 등)을 선택해 조회합니다. 필요 비용은 조회 기간의 현재 단가가 유지된다는 가정의 추정치이고, 광고비가 없는 줄은 산출불가입니다.")
        st.write("재송출 원천은 구분(DIV_NM)에 따라 방송 / 재송출로 나눕니다. 뉴미디어 개발건수는 방송 원천에 대응시키며, 방송 원천에는 뉴미디어를 구별하는 열이 없습니다.")
        st.write("표시 형식: 표의 숫자는 천 단위 구분 기호(,)를 넣고 소수점은 반올림해 표시합니다(07 탭의 개발건수는 소수 4자리). CTR·CVR·비중은 %로 표시합니다. CSV 다운로드는 원래 값을 그대로 담습니다.")
        st.write("채널 기준: CRM 개발건수·ERP 제작비는 캠페인코드의 채널, 광고비는 광고 원천의 채널(디지털=매체 MEDIA_NM, 영상광고·재송출=CHNNL_NM)입니다. 두 채널명은 띄어쓰기·대소문자를 무시해 맞추고, 다른 이름은 CHANNEL_ALIAS로 보정합니다.")
        st.write("광고 원천별 표의 CRM 개발건수·제작비는 캠페인코드의 개발인입경로로 원천에 맞추고, 원천마다 개발인입경로별 줄을 함께 보여줍니다.")
        st.write("광고비 행의 캠페인 유형·개발인입경로는 같은 구성 캠페인 안에서 그 채널에 해당하는 CRM 캠페인코드의 값을 쓰고, 해당 채널 코드가 없으면 캠페인 전체 값을 씁니다. 캠페인코드가 CRM에 중복 등록된 경우 대표값 1개를 사용합니다.")
        st.write("디지털 연결 순서: ① CRM UTM(쉼표로 여러 개 입력된 경우 나눠서 비교) ② UTM으로 연결되지 않으면 원천 캠페인명이 CRM 캠페인명과 같은 캠페인 ③ 디지털 캠페인명 보정표(DIGITAL_NAME_ALIAS).")
        st.write("디지털 다중 연결: 같은 UTM에 디지털 캠페인이 하나뿐이면 그 캠페인에 귀속합니다. 디지털 캠페인이 둘 이상인 콜라보 UTM은 원천 캠페인명으로 행 단위 귀속하고, 구분되지 않는 행만 미분리로 남깁니다.")
        st.write("공통비(검색·브랜드): UTM이 없고 원천 캠페인명이 " + ", ".join(COMMON_COST_NAMES) + "인 디지털 비용은 캠페인에 배분하지 않고 공통비로 표시합니다. 통합 개발단가에는 포함하지 않습니다.")
        st.write("날짜 복원: 영상광고는 방송일이 비어 있거나 1970-01-01이면 YEAR·MONTH·DAY로 복원합니다. 디지털은 DIGITAL_DATE_RESTORE 설정이 켜져 있을 때 같은 방식으로 복원합니다(현재 " + ("켜짐" if DIGITAL_DATE_RESTORE else "꺼짐") + ").")
        st.write("UTM 표시: 연결은 대소문자를 무시해 비교하고, 화면에는 원천 표기를 그대로 보여줍니다.")
        st.write("마리안 콘텐츠는 영상광고·디지털 모두 글로벌도네이션쇼W(미리암,마리안,프랭크)로 귀속합니다.")
        st.write("TV 영상광고는 상위 키·캠페인명 연결이 실패하면 소재명으로 보완 연결합니다. 보건의료(2만원)·포텐셜A/B·소재명 없음은 확인 대기입니다.")
        st.write("재송출 원천: U0418 전체(방송·재송출, 7월 SPOT·채널뷰 포함)→ID 594, U1312→ID 85, U1354→ID 74, U1439→ID 213. 연결 키가 없는 2022~2023 재송출 8개 방송명은 회차 기준으로 귀속합니다.")
        st.write("디지털 채널·UTM별 노출·클릭·전환가치·후원자수는 대행사 리포트 기준입니다. GA 카드는 UTM 단일 연결 기준입니다.")
        st.write("ERP 제작비 계정 범위와 CRM 코드 유일성은 별도 확인 대상입니다.")



# 차트 클릭 상세는 전체 화면 렌더링 이후 한 번만 엽니다.
def popup_cost_detail_frame(comp, ads, category):
    crm = comp[comp["ROW_KIND"].isin(["CRM", "ERP"])].copy()
    if category == "제작비":
        keys = ["COMPONENT_CAMPAIGN_NAME", "DEVELOPMENT_INFLOW_PATH"]
        group = crm.groupby(keys, as_index=False, dropna=False).agg(
            제작비=("PRODUCTION_COST", "sum"), 개발건수=("DEVELOPMENT_COUNT", "sum"))
        group["제작비 기준 개발단가"] = group["제작비"].div(group["개발건수"].where(group["개발건수"] > 0))
        group = group.rename(columns={"COMPONENT_CAMPAIGN_NAME": "세부 캠페인", "DEVELOPMENT_INFLOW_PATH": "개발인입경로"})
        return group
    source, groups = {"디지털": ("DIGITAL", ["DIGITAL"]), "영상광고": ("VIDEO", ["VIDEO"]),
                      "방송·재송출": ("REBROADCAST", ["BROADCAST", "RELAY", "REBROADCAST_OTHER"])}[category]
    matched = crm[crm["DEVELOPMENT_INFLOW_PATH"].map(INFLOW_TO_SOURCE).fillna("OTHER").isin(groups)]
    costs = ads[ads["SOURCE_TYPE"].eq(source)].groupby(
        ["COMPONENT_CAMPAIGN_NAME", "CHANNEL"], as_index=False, dropna=False)["COST"].sum()
    costs = costs.rename(columns={"COMPONENT_CAMPAIGN_NAME": "세부 캠페인", "CHANNEL": "채널", "COST": "광고비"})
    dev = matched.groupby(["COMPONENT_CAMPAIGN_NAME", "CHANNEL_NAME"], as_index=False, dropna=False).agg(
        개발건수=("DEVELOPMENT_COUNT", "sum"), 제작비=("PRODUCTION_COST", "sum"))
    dev = dev.rename(columns={"COMPONENT_CAMPAIGN_NAME": "세부 캠페인", "CHANNEL_NAME": "채널"})
    group = costs.merge(dev, on=["세부 캠페인", "채널"], how="outer", validate="one_to_one")
    for col in ["광고비", "개발건수", "제작비"]:
        group[col] = group[col].fillna(0)
    valid = (group["개발건수"] > 0) & (group["광고비"] > 0)
    group["통합 개발단가"] = (group["광고비"] + group["제작비"]).div(group["개발건수"].where(valid))
    group = group[(group[["광고비", "개발건수", "제작비"]] != 0).any(axis=1)]
    return group.sort_values(["광고비", "개발건수"], ascending=False).reset_index(drop=True)


def render_chart_popup_body(request):
    campaign = request.get("campaign")
    comp = filtered if not campaign else filtered[filtered["MARKETING_CAMPAIGN_NAME"].eq(campaign)]
    ads = detail_filtered if not campaign else detail_filtered[detail_filtered["MARKETING_CAMPAIGN_NAME"].eq(campaign)]
    if campaign:
        st.markdown(f"**{md_safe(campaign)}**")
    if request["kind"] == "month":
        month = str(request["value"])
        comp = comp[comp["PERFORMANCE_DATE"].dt.to_period("M").astype(str).eq(month)]
        ads = ads[ads["PERFORMANCE_DATE"].dt.to_period("M").astype(str).eq(month)]
        st.subheader(f"{month} 월별 성과")
        values = comp[["TOTAL_COST", "AD_COST", "PRODUCTION_COST", "DEVELOPMENT_COUNT"]].sum()
        c1, c2, c3 = st.columns(3)
        c1.metric("총비용", won(values["TOTAL_COST"]))
        c2.metric("개발건수", cnt(values["DEVELOPMENT_COUNT"]))
        c3.metric("통합 개발단가", won(values["TOTAL_COST"] / values["DEVELOPMENT_COUNT"]) if values["DEVELOPMENT_COUNT"] > 0 else "산출불가")
        st.caption(f"광고비 {won(values['AD_COST'])} · 제작비 {won(values['PRODUCTION_COST'])}")
        frame = campaign_source_frame(comp, ads, False)
        show_df(frame.drop(columns=["_kind", "채널"], errors="ignore"), use_container_width=True, hide_index=True)
    else:
        category = str(request["value"])
        st.subheader(f"{category} 비용 상세")
        total = float(comp["TOTAL_COST"].sum())
        if category == "제작비":
            part = comp[comp["ROW_KIND"].eq("ERP")]
            amount = float(part["PRODUCTION_COST"].sum())
            group = part.groupby(["COMPONENT_CAMPAIGN_NAME", "DEVELOPMENT_INFLOW_PATH"], as_index=False)["PRODUCTION_COST"].sum()
            group = group.rename(columns={"COMPONENT_CAMPAIGN_NAME": "세부 캠페인", "DEVELOPMENT_INFLOW_PATH": "개발인입경로", "PRODUCTION_COST": "제작비"})
        else:
            source, column = {"디지털": ("DIGITAL", "DIGITAL_AD_COST"), "영상광고": ("VIDEO", "VIDEO_AD_COST"), "방송·재송출": ("REBROADCAST", "REBROADCAST_AD_COST")}[category]
            part = ads[ads["SOURCE_TYPE"].eq(source)]
            amount = float(comp[column].sum())
            group = part.groupby(["COMPONENT_CAMPAIGN_NAME", "CHANNEL"], as_index=False)["COST"].sum()
            group = group.rename(columns={"COMPONENT_CAMPAIGN_NAME": "세부 캠페인", "CHANNEL": "채널", "COST": "광고비"})
        # 비용 조각에 대응하는 CRM 경로 기준으로 개발건수와 단가를 계산합니다.
        if category == "제작비":
            dev_count = float(comp["DEVELOPMENT_COUNT"].sum())
            unit_cost = amount / dev_count if dev_count > 0 else None
            unit_label = "제작비 기준 개발단가"
            basis = "제작비 조각: 캠페인 전체 CRM 개발건수, 제작비 ÷ 전체 개발건수. 통합 개발단가와는 다릅니다."
        else:
            groups = {"디지털": ["DIGITAL"], "영상광고": ["VIDEO"], "방송·재송출": ["BROADCAST", "RELAY", "REBROADCAST_OTHER"]}[category]
            crm_rows = comp[comp["ROW_KIND"].isin(["CRM", "ERP"])].copy()
            source_group = crm_rows["DEVELOPMENT_INFLOW_PATH"].map(INFLOW_TO_SOURCE).fillna("OTHER")
            matched = crm_rows[source_group.isin(groups)]
            dev_count = float(matched["DEVELOPMENT_COUNT"].sum())
            prod_cost = float(matched["PRODUCTION_COST"].sum())
            unit_cost = (amount + prod_cost) / dev_count if dev_count > 0 and amount > 0 else None
            unit_label = "통합 개발단가"
            basis = "선택 원천에 대응하는 CRM 개발인입경로 기준. 개발단가 = (선택 원천 광고비 + 해당 경로 제작비) ÷ 해당 경로 개발건수. 방송·재송출에는 뉴미디어 개발건수도 포함합니다."
        boxes = st.columns(4, gap="small")
        labels = ["비용", "총비용 대비 비중", "CRM 개발건수", unit_label]
        values = [won(amount), pct(amount / total) if total else "-", cnt(dev_count),
                  won(unit_cost) if unit_cost is not None else "산출불가"]
        for box, label, value in zip(boxes, labels, values):
            box.markdown(f'<div class="popup-kpi"><div class="popup-kpi-label">{escape(label)}</div><div class="popup-kpi-value">{escape(value)}</div></div>', unsafe_allow_html=True)
        st.caption(basis)
        group = popup_cost_detail_frame(comp, ads, category)
        if group.empty:
            st.info("선택 조건에서 표시할 세부 내역이 없습니다.")
        else:
            show_df(group, use_container_width=True, hide_index=True)
        st.caption("현재 기간·필터와 기존 캠페인 귀속 기준을 그대로 사용합니다. 채널별 개발건수·제작비는 CRM 캠페인코드 채널 기준이며, 광고비만 있거나 개발건수가 없는 행의 개발단가는 '-'로 표시합니다. 제작비는 개발단가 계산 근거를 확인할 수 있도록 함께 표시합니다.")


_dialog_factory = getattr(st, "dialog", None) or getattr(st, "experimental_dialog", None)
if _dialog_factory is not None:
    @_dialog_factory("그래프 세부 내용", width="large")
    def show_chart_popup(request):
        render_chart_popup_body(request)
else:
    def show_chart_popup(request):
        st.info("현재 실행 버전은 팝업을 지원하지 않아 아래 상세 영역으로 표시합니다.")
        with st.container(border=True):
            render_chart_popup_body(request)

_popup_request = st.session_state.pop("pending_chart_popup", None)
if _popup_request:
    show_chart_popup(_popup_request)

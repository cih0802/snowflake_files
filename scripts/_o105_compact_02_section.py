# 02-008 의 §O105 절을 300줄 상한 이내로 압축 재작성하는 1회용 스크립트.
# Co-authored with CoCo
#
# 배경: §O105 를 추가해 조각이 320줄(상한 300)이 됐다. --rebalance 는 R4-4-3 승인 대상이므로
#       내용을 버리지 않고 줄을 밀도 높게 합쳐 상한 이내로 되돌린다(정보 손실 0 목표).
# 안전장치: ① 절 시작 마커 유일성 assert ② 절 앞 본문 무변경 assert ③ 스냅샷 후 쓰기
#           ④ 쓴 뒤 줄 수·2000자·핵심 토큰 보존 재검증.
# R1-7-9: 백틱이 본문에 있어 셸 인라인을 쓰지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

PATH = sorted(glob.glob("20_issue/02_상태상세*-008.md"))[0]
SNAP = "_archive/02_상태상세_대시보드_갱신형-008.md.O105-pre-compact"
MARK = "### §O105 — 이슈1·2 실적재 검증 + Agent 2종 보강·배포 (2026-08-28 · 계정 `ZL50263`)"

SECTION = """### §O105 — 이슈1·2 실적재 검증 + Agent 2종 보강·배포 (2026-08-28 · 계정 `ZL50263`)

> 🔴 원장 §1 `O105` 행의 장문 이관부다(`O66` 규약). 판정 요약은 그 행에, 경위·근거는 여기에 둔다.

#### ▣ 신규 발견 3

**㉠ WIDE ↔ SV 소스 축 불일치 (🟠 설계 결정 대기)** — 같은 이름의 캠페인 9속성이 두 표면에서 **다른 소스**를 쓴다:
`GOLD.WIDE_MEMBER_EVENT` 9축 = `DIM_CAMPAIGN` **실시간 조인**(`c.*` · 라이브 뷰 정의 실측) ↔
`SERVING.SV_MEMBER_EVENT` 9차원 = **적재 시점 동결값**(`fme.*_AT_EVENT`).
현 시점 값은 같다(`CAMPAIGN_SK` PK 조인 9축 전건 **불일치 0 / 3,594,843**). 🔴 그러나 캠페인 마스터가
정정·개칭되면 **Streamlit(WIDE 직접 조회)과 Cowork(SV/Agent)이 다른 답**을 낸다. ⚠️ `DEC-43` 이 채택한 축은
**동결값**이므로 규약에서 벗어난 쪽은 WIDE 다. ⇒ 처분 후보 = ㉮ WIDE 를 `*_AT_EVENT` 로 전환(시맨틱 계약
변경 · `R4-4-3` 승인 대상) ㉯ WIDE 컬럼 COMMENT 에 「현재값이며 SV 와 다를 수 있다」 명시 ㉰ 현상 유지 + 등재.

**㉡ SV `AI_SQL_GENERATION` 수치 stale (🟠 SV 재배포 대기)** — `SV_MEMBER_EVENT` 지시문과
`05_2_SV_DDL_MEMBER_EVENT.sql:133` 이 `MKTG_UTM_NM` 매핑률을 **「약 36%」**로 하드코딩한다. 🔴 축이 어긋난다:
캠페인 grain 실측(O102) = **34.00%**(지시문 값은 이 축의 근사이고 이미 낡았다) ↔ 이 SV 의 **사건 grain
실측 = 18.13%**(651,493 / 3,593,369 · 지시문이 사는 SV 의 grain 이 이쪽이다). ⇒ Agent 스펙에는 같은 실수를
반복하지 않으려 **수치를 넣지 않고** 「채움이 낮으니 도구로 조회해 확인하고 부분집합임을 밝혀라」로 썼다
(`R2-6` · 스펙 자체 규약 「원천 답변에 수치를 넣지 않는다」). 🔴 SV 측 시정은 **라이브 재배포**라 미실행.

**㉢ `agent_tool_claim_gate` 축 결함 (🟠 게이트 수정 승인 대기)** — 착수 시
`① SV_MEMBER_SPONSOR_BIZ 「후원사업별」 주장 모순 — MARKETING(불가) ↔ MEMBER(가능)` 으로 **FAIL** 했다.
🟢 **내 편집이 원인이 아님을 실증**했다 — 편집을 메모리에서 되돌려 재측정해도 판정이 **동일**(`-1 ↔ +1`)이고
지목 도구는 이 세션이 만지지 않은 `analyst_member_sponsor_biz` 다. 🔴 **원인 = 게이트가 보는 축이 잘못됐다**:
`stance()` 는 스펙을 **yaml 파싱 없이 원문 그대로** 읽고 `re.split(r'(?<=[.。·\\n])')` 로 문장을 자른다
⇒ **YAML 줄바꿈이 문장 경계가 된다.** MARKETING 은 줄바꿈이 「후원사업별 … SUM 금지 … 기대하지 말 것」을
한 문장에 묶어 `-1`, MEMBER 는 같은 뜻인데 「캠페인·후원사업」/「별 합계는 …」로 갈려 그 문장에 토큰이 없어
`+1` 이다 ⇒ **같은 산문이 줄바꿈 위치에 따라 반대로 채점된다**(두 스펙 모두 실제로는 「정본 도구」로 가능을
선언한다). 🔴 `stance()` 는 첫 neg-only 문장에서 **즉시 `return -1`** 하므로 앞선 pos 문장이 무시된다(순서
의존). ⇒ 처방 후보 = 원문이 아니라 **파싱된 문자열**에 문장 분할 적용 · 또는 neg/pos 누적 비교.
🔴 로직 변경은 기존 판정 21건을 바꾸므로 **승인·회귀 대조 없이 손대지 않았다**(`P224` = 게이트의 축을 본다).

#### ▣ 자기철회 1 — 분모를 먼저 확인하지 않았다 (`P128` 축)

초판은 WIDE ↔ FME 동결값 대조를 **업무키 조인**(`DATE_SK`+`MEMBER_DK`+`EVENT_TYPE`+`SPNSR_AMT`+`DVLP_DIV_CD`)
으로 재서 **7,005,277행**(> FME DEV 3,594,843)을 만들고 불일치 **45만~62만**을 보고했다. 🔴 그 키는 FME 에서
유일하지 않다(팩트 PK 미선언 · SV COMMENT 에 이미 명시돼 있었다). 🟢 `CAMPAIGN_SK` PK 조인으로 재측정해
**0 / 3,594,843** 으로 정정했다. ⇒ 교훈 = **조인 결과 행수를 분모와 먼저 대조**한다. 팬아웃은 불일치를
만들어내지 않고 **부풀린다.**

#### ▣ 동시 편집 사고 (`C7`) — 게이트 3종이 전부 침묵했다

경위 = 본 세션이 원장을 전량 읽은 뒤(10:30 KST) 라벨을 선점 등재하려는 사이 **타 세션이 10:42 KST 같은
`O105` 라벨 행을 삽입하고 허브를 `--republish`** 했다(허브 SHA `41b1c4e8…` → `70130b6d…`). 본 세션은
10:45 KST `R1-7-2` 해시 안정성을 확인했으나 **그 시점에 상대 쓰기가 이미 완료**돼 2회 읽기가 동일했다
⇒ 통과. 10:46 KST 삽입으로 **행 2개**가 됐다.

| 게이트 | 결과 | 못 잡은 이유 |
|---|---|---|
| `index_row_gate` | 🟢 유실 0 · 중복 0 | 두 행의 **행 키(제목)가 달라** 중복이 아니다 |
| `id_collision_gate` | 🟢 정의 중복 0 | 두 행 모두 **참조 형태**(백틱)라 정의 축 밖이다 |
| `R1-7-2` 해시 안정성 | 🟢 통과 | **내 직전 읽기와 대조하지 않는다** — 같은 순간 2회만 본다 |

🟢 **처방 후보 = `R1-7-2` 에 「직전 읽기 해시 보존·대조」를 추가**한다. 지금 조문은 *「같은 파일 2회 이상 읽어
크기·SHA256 동일해야 착수」*인데 이것은 **부분 반환(`C5`)** 은 잡고 **완료된 타 세션 쓰기(`C7`)** 는 구조적으로
못 잡는다 ⇒ **두 사고 유형에 필요한 게이트가 다르다.** ⇒ 사용자 승인으로 중복 2행을 1행 통합했다
(스냅샷 = `_archive/00_INDEX_이슈원장-001.md.O105-pre-merge`).

#### ▣ 배포·기능 검증 (사용자 실행 · `R4-1` 준수)

경로 = `05_SV-Agent_ai/09_2_AGENT_버전업.sql`(`ADD VERSION FROM`) — 착수표 **⑳** 대로
`cortex_agent_save`/`deploy` 는 쓰지 않았다(live 버전이 `ADD VERSION FROM` 을 거부한다).

- `AGENT_MEMBER` **VERSION$9** `is_default=true` · spec 24,788자 · 추천질문 **34** ·
  `AGENT_MARKETING` **VERSION$5** `is_default=true` · spec 18,646자
- 신규 토큰 라이브 실재(`세부캠페인 후원구분`·`세부캠페인 법인구분`·`공통브랜드`·`적재 시점 동결값`) ↔
  직전 `VERSION$7`·`VERSION$4` 는 **전건 0** ⇒ 반영이 이 배포에서 처음 실렸음이 실증된다
- 🟢 **기능 검증** = 「세부캠페인 법인구분별 개발건수」 질의가 `analyst_member_event` 로 라우팅돼
  **통합 195,796 · 사단 1,005 · 사복 1** 반환. 답변이 *「조직 계층의 법인과는 다른 세부캠페인
  법인구분(CM019)」*·*「사건 시점 동결값」*·*「개발 전용이라 중단건으로 쓸 수 없다」* 를 **자발 고지**
  ⇒ 보강 전이라면 「법인별 분해 산출 불가」로 답했을 경로가 닫혔다
- 🟠 부수 stale = `09_2` 가 새기는 버전 COMMENT 문안이 **「추천질문 31」**(실제 34) — 하드코딩 주장(`P212`)
"""

TOKENS = [
    "7,005,277", "0 / 3,594,843", "18.13%", "34.00%", "VERSION$9", "VERSION$5",
    "195,796", "stance()", "index_row_gate", "R1-7-2", "70130b6d", "P128", "P224",
    "추천질문 31", "ADD VERSION FROM",
]


def main() -> None:
    raw = open(PATH, encoding="utf-8").read()
    assert raw.count(MARK) == 1, f"절 마커가 유일하지 않다(={raw.count(MARK)}) — 중단"
    head = raw.split(MARK, 1)[0]

    shutil.copyfile(PATH, SNAP)
    out = head + SECTION
    open(PATH, "w", encoding="utf-8").write(out)

    chk = open(PATH, encoding="utf-8").read()
    L = chk.split("\n")
    over = [i + 1 for i, s in enumerate(L) if len(s) > 2000]
    missing = [t for t in TOKENS if t not in chk]
    print(f"스냅샷      = {SNAP}")
    print(f"줄 수       = {len(raw.split(chr(10)))} -> {len(L)} (상한 300)")
    print(f"바이트      = {len(raw.encode())} -> {len(chk.encode())} (상한 40960)")
    print(f"SHA256      = {hashlib.sha256(chk.encode()).hexdigest()[:16]}")
    print(f"2000자 초과 = {over}")
    print(f"토큰 부재   = {missing} (0건이어야 통과 · 분모 {len(TOKENS)})")
    print(f"절 앞 무변경= {chk.startswith(head)}")
    assert len(L) <= 300 and not over and not missing


if __name__ == "__main__":
    main()

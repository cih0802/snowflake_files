#!/usr/bin/env python3
"""O87-B: `08` DDL object COMMENT 의 실측 수치 제거 (R2-6 시정) + 「손실 0」 철회.

왜 스크립트인가 (`R1-7-9`): 본문에 백틱·`$`·괄호가 섞여 있어 `bash -c` 인라인 python 에
  넣으면 명령치환으로 구간이 삭제된 채 써진다(O83-H 실사고).
왜 `edit` 이 아닌가: 대상 3줄이 모두 매우 긴 단일 줄이라 앵커 사고 위험이 크다(`R1-7-8`).
  ⇒ 줄 전체를 정확 일치로 찾아 치환하고, 치환 건수를 검증한다.

R2-6 원문: "코드 COMMENT 에는 코드값만 기록한다. 실측 수치는 문서10과 이슈 원장에만 기록한다."
  ⇒ object COMMENT 는 Snowflake 카탈로그·SV·Agent 로 전파되므로 stale 이 되면 피해가 크다.
    수치를 빼고 **정본 포인터**를 남긴다.
"""
import hashlib

PATH = "04_silver_design/08_SILVER_테이블DDL_20260714.sql"
PTR = "규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측"

REPL = [
    # ── BIGQUERY_REFINED_DATA.BATCH_ORDERING_ID ──────────────────────────────
    (
        "    BATCH_ORDERING_ID       NUMBER          COMMENT '배치 내 정렬 ID. 🔴 NOT NULL 아님 — 원천 events_20240719 부터 생긴 컬럼이라 2024-01-01~07-18(199일 · 48,862,926행 = 17.10%)은 NULL 이다. PK 에서 내려왔고 EVENT_SEQ 정렬 근거로만 쓴다',",
        "    BATCH_ORDERING_ID       NUMBER          COMMENT '배치 내 정렬 ID. 🔴 NOT NULL 아님 — 원천 events_20240719 부터 생긴 컬럼이라 2024 상반기는 전건 NULL 이다. PK 에서 내려왔고 EVENT_SEQ 정렬 근거로만 쓴다. ⚠️ 2024 상반기는 이 컬럼이 전건 NULL 이므로 EVENT_SEQ 정렬이 사실상 SRC_FILE_NAME 부터 시작한다 — 미결 GA4-SEQ-1. "
        + PTR
        + "',",
    ),
    # ── GA4_EVENT.EVENT_SEQ ──────────────────────────────────────────────────
    (
        "    EVENT_SEQ               NUMBER          NOT NULL COMMENT '동일 3키 내 순번 (PK). 🟢 GA4-PK-1 해소 — 종전 4번째 키 BATCH_ORDERING_ID 는 원천 events_20240719 부터 생긴 컬럼이라 2024-01-01~07-18(199일 · 48,862,926행 = 17.10%)을 NOT NULL 위반으로 배제했다. 3키로 낮춰도 2024-06 기준 3.679%(238,454행) 중복이 남아 단순 제거도 불가였다 ⇒ 기반 테이블이 계보 순 결정적 정렬로 부여한 surrogate 로 대체(손실 0)',",
        "    EVENT_SEQ               NUMBER          NOT NULL COMMENT '동일 3키 내 순번 (PK). 🟢 GA4-PK-1 해소 — 종전 4번째 키 BATCH_ORDERING_ID 는 2024 상반기에 없어 그 구간을 NOT NULL 위반으로 배제했다. 3키로 낮춰도 중복이 남아 단순 제거도 불가였다 ⇒ 기반 테이블이 계보 순으로 부여한 surrogate 로 대체한다. 🔴 [O87-B] 성립하는 것은 「NOT NULL 위반 해소」까지다 — 「손실 0」은 미실증이고 정렬 튜플 동일 행이 실재한다(미결 GA4-SEQ-1). "
        + PTR
        + "',",
    ),
    # ── GA4_EVENT.USER_ID ────────────────────────────────────────────────────
    (
        "    USER_ID                 VARCHAR(64)     COMMENT 'GA4 user_id 원본(불변 보존). 🟢 GA4-LEN-1 해소 — 종전 VARCHAR(10)에서 12,690행(이메일 14자·app- 36/40자)이 초과 실패했다. 🔴 CRM 회원번호가 아닌 값이 섞여 있다 ⇒ ID_SCHEME 과 함께 읽을 것',",
        "    USER_ID                 VARCHAR(64)     COMMENT 'GA4 user_id 원본(불변 보존). 🟢 GA4-LEN-1 해소 — 종전 VARCHAR(10)에서 이메일·app- 접두 포맷이 길이 초과로 실패했다. 🔴 CRM 회원번호가 아닌 값이 섞여 있다 ⇒ ID_SCHEME 과 함께 읽을 것. "
        + PTR
        + "',",
    ),
]

b1 = open(PATH, "rb").read()
b2 = open(PATH, "rb").read()
assert b1 == b2, "unstable read — 중단"
print("stable", len(b1), hashlib.sha256(b1).hexdigest()[:16])

s = b1.decode("utf-8")
for i, (old, new) in enumerate(REPL, 1):
    n = s.count(old)
    assert n == 1, f"[{i}] 정확 일치 {n}건 — 1건이어야 한다"
    s = s.replace(old, new)
    print(f"[{i}] 치환 완료")

open(PATH, "w", encoding="utf-8").write(s)
print("written bytes", len(s.encode("utf-8")))

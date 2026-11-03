#!/usr/bin/env python3
"""O255 · 05_02 SV_MEMBER_EVENT 에 DEC-63-E 현재 부서 축 삽입(줄 기준 · 앵커 = 줄 머리 접두).
삽입 지점 3곳: TABLES 닫는 `  )` 직전 · RELATIONSHIPS 의 fme_to_acq 줄 · org.ORG_PATH 차원 COMMENT 줄 다음.
쓰기 전후 줄 수를 대조하고 삽입 표지 개수를 확인한다.
"""
import sys

P = "/workspace/05_SV-Agent_ai/05_02_SV_DDL_MEMBER_EVENT.sql"
L = open(P, encoding="utf-8").read().split("\n")
n0 = len(L)
if any("DEC-63-E" in x for x in L):
    print("이미 반영됨"); sys.exit(0)

# 1) TABLES: org 블록 다음 첫 `  )` (RELATIONSHIPS 직전)
i_rel = next(i for i, x in enumerate(L) if x.startswith("  RELATIONSHIPS ("))
assert L[i_rel - 1] == "  )", L[i_rel - 1]
L[i_rel - 2] = L[i_rel - 2] + ","
tbl = [
    "    -- 🆕 [2026-10-21 DEC-63-E] 폐지·개편 부서 → 현재 부서 귀속(개발 DEV 행 전용)",
    "    org_succ AS GN_DW.GOLD.DIM_ORG_SUCCESSION",
    "      PRIMARY KEY (OLD_ORG_SK)",
    "      WITH SYNONYMS ('부서 귀속', '현재 부서 귀속')",
    "      COMMENT = '폐지·개편 부서 현재 조직 귀속 차원(DIM_ORG 와 1:1 · OLD_ORG_SK = ORG_SK). PK 유일이라 조인이 행수를 늘리지 않는다. 🔴 중단(STOP) 행은 ORG_SK = 0(원천 실적부서 없음)이라 연결되지 않는다.'",
]
L[i_rel - 1:i_rel - 1] = tbl

# 2) RELATIONSHIPS
i_acq = next(i for i, x in enumerate(L) if x.strip().startswith("fme_to_acq "))
L[i_acq] = L[i_acq] + ","
L.insert(i_acq + 1, "    fme_to_org_succ AS fme (ORG_SK) REFERENCES org_succ")

# 3) DIMENSIONS: org.ORG_PATH 차원 다음 줄들 중 COMMENT 줄 다음
i_path = next(i for i, x in enumerate(L) if x.strip().startswith("org.ORG_PATH AS org.ORG_PATH"))
j = i_path
while "COMMENT" not in L[j]:
    j += 1
assert L[j].rstrip().endswith(","), L[j][-40:]
dims = [
    "    -- 🆕 [2026-10-21 DEC-63-E] 현재 조직 기준 부서 축(개발 DEV 사건 전용)",
    "    org_succ.CUR_DEPARTMENT AS org_succ.CUR_DEPARTMENT",
    "      WITH SYNONYMS ('현재 부서', '현재 부서-팀', '귀속 부서', '현재 조직 기준 부서')",
    "      COMMENT = '개발 실적부서를 **현재 활성 부서-팀**으로 귀속한 부서명(폐지·개편 부서 실적이 현재 부서에 합쳐진다 · DEC-63-E · 현업 확인 대기). 🔴 개발(DEV) 사건 전용 — 중단(STOP) 행은 원천 부서가 없어 NULL 이다(부서별 중단은 SV_MEMBER_SPONSOR_BIZ.CUR_DEPARTMENT). 개발 행의 NULL = 귀속 대상 없는 폐지 부서((미매핑 폐지부서)로 표시). 🔴 「부서별 개발 실적」 기본 축 · 「당시 부서」를 명시하면 ORG_DEPARTMENT.',",
    "    org_succ.CUR_ORG_PATH AS org_succ.CUR_ORG_PATH",
    "      WITH SYNONYMS ('현재 부서-팀 경로', '현재 조직 경로')",
    "      COMMENT = '귀속 현재 부서의 조직 경로(예: 본부 > 회원실 > 회원참여팀). NULL 사유 = CUR_DEPARTMENT 와 같다.',",
    "    org_succ.IS_CONFIRMED AS org_succ.IS_CONFIRMED",
    "      WITH SYNONYMS ('귀속 확정 여부')",
    "      COMMENT = 'TRUE = 활성 부서 또는 현업 확정 귀속 · FALSE = 자동 추정 귀속(현업 검토 전).',",
]
L[j + 1:j + 1] = dims

open(P, "w", encoding="utf-8").write("\n".join(L))
back = open(P, encoding="utf-8").read().split("\n")
added = len(tbl) + 1 + len(dims)
print("lines", n0, "→", len(back), "expect", n0 + added, "marks", sum("DEC-63-E" in x for x in back))

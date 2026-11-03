"""O213-D Y3-C — 회원 차원 신규 축의 SV 배선 명세 생성(tmp/o213_y3c_sv_spec.tsv · 생성기 o213_y3_sv_gen.py 입력)."""
import io

SVS = ["SV_MEMBER_EVENT", "SV_MEMBER_MONTHLY", "SV_SERVICE", "SV_EVENT_PARTICIPATION", "SV_RELATION_ACTIVITY"]
COMMON = [
    ("RELATNSP_DIV_NAME", "MEMBER_RELATNSP_DIV_NAME", "결연구분|결연/비결연",
     "🆕 [O213-D] 결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음)."),
    ("SPECL_MNG_NAME", "MEMBER_SPECL_MNG_NAME", "특별관리|회원 특별관리|특별관리 구분",
     "🆕 [O213-D] 회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다."),
    ("FIRST_SPONSORSHIP_NAME", "MEMBER_FIRST_SPONSORSHIP_NAME", "최초후원사업|최초 후원사업",
     "🆕 [O213-D] 회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%)."),
    ("MOBLPHON_STAT_NAME", "MEMBER_MOBLPHON_STAT_NAME", "휴대폰상태|휴대폰 상태|연락처 상태",
     "🆕 [O213-D] 휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값."),
    ("EMAIL_STAT_NAME", "MEMBER_EMAIL_STAT_NAME", "이메일상태|이메일 상태",
     "🆕 [O213-D] 이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL."),
    ("TSTM_DIV_NAME", "MEMBER_TSTM_DIV_NAME", "TM/TS 거절|전화 거절구분|TM 거절",
     "🆕 [O213-D] TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다."),
]
RECV = [("EMAIL", "이메일", "MS028", [("REFUSE", "1", "수신거부"), ("REGULAR", "2", "정기우편물"), ("RELATION", "3", "결연이메일"),
                                  ("THANKS", "4", "감사서비스"), ("WEBZINE", "5", "웹진"), ("DEV", "6", "개발이메일")]),
        ("POST", "우편물", "MS027", [("REFUSE", "1", "수신거부"), ("REGULAR", "2", "정기우편"), ("RELATION", "3", "결연우편"),
                                  ("NEW_THANKS", "4", "신규/감사 우편")])]
SERVICE_ONLY = [("ETC_CTTPC_STAT_NAME", "MEMBER_ETC_CTTPC_STAT_NAME", "기타연락처 상태",
                 "🆕 [O213-D] 기타연락처 상태(MM008 · 정상·결번·타인번호).")]
for ch, ko, grp, items in RECV:
    for key, code, nm in items:
        col = f"{ch}_RECV_{key}_YN"
        SERVICE_ONLY.append((col, "MEMBER_" + col, f"{ko} {nm} 수신|{ko} 수신항목 {nm}",
                             f"🆕 [O213-D] {ko} 수신 항목에 「{nm}」({grp} 코드 {code})가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다."))
MONTHLY_ONLY = [
    ("SPECL_MNG2_NAME", "MEMBER_SPECL_MNG2_NAME", "특별관리2|특별관리 구분2", "🆕 [O213-D] 회원 특별관리 구분2(MM012) — 값이 있는 회원은 소수다."),
    ("SLRCLD_LRR_NAME", "MEMBER_SLRCLD_LRR_NAME", "생일 양력/음력|양음력", "🆕 [O213-D] 생일 양력/음력(CM029 · 양력·음력·불명확)."),
    ("REL_NAME", "MEMBER_REL_NAME", "일시회원 관계", "🆕 [O213-D] 일시회원 관계(CM009 · 본인·부모·배우자·대표자·기업담당자 등). 정기회원은 NULL(원천 개념 없음)."),
]
rows = ["sv\talias\tcol\texpose\tsynonyms\tcomment"]
for sv in SVS:
    rows += ["\t".join([sv, "member", *c]) for c in COMMON]
rows += ["\t".join(["SV_SERVICE", "member", *c]) for c in SERVICE_ONLY]
rows += ["\t".join(["SV_MEMBER_MONTHLY", "member", *c]) for c in MONTHLY_ONLY]
io.open("/workspace/tmp/o213_y3c_sv_spec.tsv", "w", encoding="utf-8").write("\n".join(rows) + "\n")
print(len(rows) - 1, "rows")

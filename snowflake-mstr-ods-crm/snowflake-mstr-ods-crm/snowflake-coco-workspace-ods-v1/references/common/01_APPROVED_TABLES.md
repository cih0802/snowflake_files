# Approved GN_DW.BRONZE_CRM tables

Only the following 50 tables are approved. Names are case-insensitive for comparison, but generated SQL should use the actual Snowflake identifier form.

## Messaging and engagement

| Table | Role | Source grain / PK | Notes |
|---|---|---|---|
| `SND_REQ_MST` | Unified send request master | `SEQ_NO` | Preferred source for send large/middle/small classification, title, target/send/fail counts |
| `SND_MEMBER_LIST` | Unified send target/member detail | No SQL Server PK; logical key requires Snowflake contract | Join to request by `REQ_SEQ_NO`; do not deduplicate without the added key or approved composite key |
| `snd_member_open_log` | Mail open event log | `LOG_SEQ` | Event count differs from unique opener count |
| `snd_member_mail_link_log` | Mail link click event log | `LOG_SEQ` | Event count differs from unique click member count |
| `TM_MS_EMAIL_SNDNG` | Email send master | `SNDNG_KEY` | Legacy/channel-specific verification path |
| `TD_MS_EMAIL_LQY_SNDNG` | Email send aggregate | `SNDNG_KEY` | Contains send/success/failure/receive and URL metrics |
| `TD_MS_EMAIL_SNDNG_DTLS` | Email recipient detail | `SNDNG_KEY + SNDNG_DTL_KEY` | Large; filter master keys first |
| `TM_MS_MSG_AT_SNDNG` | SMS/AlimTalk send master | `SNDNG_KEY` | Channel-specific verification path |
| `TD_MS_MSG_AT_LQY_SNDNG` | SMS/AlimTalk split aggregate | `SNDNG_KEY + DIVS_DTL_KEY` | Contains send/success/failure/click text fields |
| `TD_MS_MSG_AT_SNDNG_DTLS` | SMS/AlimTalk recipient detail | `SNDNG_KEY + SNDNG_DTL_KEY` | Very large and contains PII/message content |
| `TM_MS_PSTMTR_SNDNG` | Postal send master | `SNDNG_KEY` | Channel-specific verification path |
| `TD_MS_PSTMTR_LQY_SNDNG` | Postal send aggregate | `SNDNG_KEY` in source PK metadata | `SNDNG_SQNC` may be a business sub-grain; verify |
| `TD_MS_PSTMTR_SNDNG_DTL` | Postal recipient/relationship detail | `SNDNG_KEY + SNDNG_DTL_KEY` | Contains member, relationship, address, management keys |
| `TD_MS_AT_TMPLAT_BTN_LIST` | AlimTalk template button | `TMPLAT_ID + BTN_SEQ` | URL/button metadata |
| `TM_MS_EMAIL_TMPLAT_MNG` | Email template master | `TMPLAT_KEY` | Send classification/template descriptions |
| `TC_MKTNG_DTL_CD` | Marketing detail code | Snowflake-only contract pending | Not present in the supplied SQL Server 421-table metadata |

## Member, sponsorship, and development

| Table | Role | Source grain / PK |
|---|---|---|
| `TM_MM_FDRM_MBER_INFO` | Recurring member master | `MBER_NO` |
| `TM_MM_ONCE_MBER_INFO` | One-time member master | `ONCE_MBER_NO` |
| `TM_MM_FDRM_MBER_SPNSR` | Sponsorship master | `SPNSR_NO` |
| `TM_MM_FDRM_MBER_SPNSR_BSNS` | Sponsorship-business detail | `SPNSR_NO + SPNSR_BSNS_NO` |
| `TM_MM_FDRM_MBER_DVLP_AMT` | Member/sponsorship development event amount | `SPNSR_NO + SPNSR_BSNS_NO + OCCRRNC_DE + SER_NO` |
| `TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` | Relationship development event amount | `OCCRRNC_DE + SER_NO + SPNSR_NO + SPNSR_BSNS_NO` |
| `TM_MM_FDRM_MBER_SPNSR_DSCNTC` | Sponsorship discontinuation event | `MBER_NO + SPNSR_DSCNTC_DE + SER_NO` |
| `TM_MM_FDRM_MBER_RE_SPNSR` | Re-sponsorship event | `MBER_NO + SER_NO + RE_SPNSR_DE` |
| `TM_MM_FDRM_MBER_IRSD` | Member development event set | `OCCRRNC_DE + SER_NO`; business meaning requires code/status rule |
| `TH_MM_FDRM_MBER_STNG_DTLS` | Member status-change history | `MBER_NO + SER_NO` |
| `TM_MM_FDRM_MBER_DT_DTLS` | Recurring/one-time member mapping candidate | No SQL Server PK |
| `TM_CM_MBER_DVLP_GOAL` | Department/month member-development goal | `STDYY + STDR_MT + MBER_DVLP_DIV_CD + DEPT_ID` |

## Payment and donation

| Table | Role | Source grain / PK |
|---|---|---|
| `TM_PM_MBRFEE_ACMSLT` | Membership-fee request/payment actual | `MBRFEE_KEY` |
| `TM_PM_DNTN_DTLS` | One-time donation detail | `DNTN_KEY` |
| `TM_PM_SETLE_INFO` | Current settlement/payment-method master | `SETLE_KEY` |
| `TH_PM_SETLE_INFO_HIST` | Settlement/payment-method history | Source PK metadata says `SETLE_KEY`; verify history grain/date |
| `TM_PM_INSTT_ACNUT` | Institution account master | `ACNUT_SER_NO` |
| `TM_PM_SETLE_CMPNY_ACNT` | Settlement-company account master | `SETLE_CMPNY_ACNT_NO` |

## Relationship, child, letter, and gift money

| Table | Role | Source grain / PK |
|---|---|---|
| `TM_RM_RELATNSP_MSTR_INFO` | Member-child relationship master | `RELATNSP_KEY` |
| `TM_RM_RELATNSP_CHG_INFO` | Relationship change record | `RELATNSP_KEY`; confirm whether one current change or history |
| `TM_RM_CHILD_MSTR_INFO` | Child master | `CHILD_CD` |
| `TM_RM_BPLC_MNG` | Child/project business-place master | `BPLC_CD` |
| `TM_RM_RELATNSP_GFTMNEY_INFO` | Relationship gift-money transaction | `RELATNSP_KEY + MNG_NO + MBRFEE_KEY` |
| `TM_RM_RELATNSP_LETTER_INFO` | Relationship letter | `RELATNSP_KEY + MNG_NO` |

## Campaign, event, and dimensions

| Table | Role | Source grain / PK |
|---|---|---|
| `TC_CMMN_CD` | Common-code header | `CD_ID` |
| `TC_CMMN_DTL_CD` | Common-code detail | `CD_ID + DTL_CD_ID` |
| `TM_CM_BRND_MNG` | Brand master | `BRND_ID` |
| `TM_CM_CMPGN_MNG` | Campaign master | `CMPGN_CD` |
| `TM_CM_DEPT_INFO` | Department hierarchy | `DEPT_ID` |
| `TM_CM_SPNSR_BSNS_INFO` | Sponsorship-business code/master | `SPNSR_BSNS_ID` |
| `TM_MS_CRMN` | Participation/campaign master | `CRMN_CD` |
| `TD_MS_CRMN_PRTCPNT` | Campaign participant | `CRMN_CD + PRTCPNT_KEY` |
| `TM_MS_EVENT` | Event master | `EVENT_CD` |
| `TD_MS_EVENT_PRTCPNT_DTL` | Event participation detail | `EVENT_CD + MBER_NO + PARTCPT_SEQ` |


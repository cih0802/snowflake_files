-- 주간중단보고 부서별 드릴다운 로직 (streamlit_app.py 기준)
-- 실적부서(ACMSLT_DEPT_CD) → ① 상위부서 / ② 팀 귀속 매핑 + 사단 중단 후원 건수 예시
WITH
-- 1) 현재 조직도: 사단법인(A000001) 본부(B000004)·국내(B000005) 아래 ORG_LEVEL 2 = 상위부서
L2 AS (
    SELECT O.DEPT_ID, O.DEPT_NM, O.UPPER_DEPT_NM, O.ORG_PATH
    FROM GN_DW.SILVER.V_ORG_PICKER O
    JOIN GN_DW.SILVER.V_ORG_PICKER P ON P.DEPT_ID = O.UPPER_DEPT_ID
    WHERE O.ORG_LEVEL = 2
      AND P.UPPER_DEPT_ID = 'A000001' AND P.DEPT_ID IN ('B000004', 'B000005')
      AND O.DEPT_ID NOT IN ('C000005', 'D001050', 'D000154',                          -- 감사실(사단)·디지털혁신위원회·울산교육센터 준비위원회
                            'C000001', 'D001004', 'C000031', 'C000002', 'D001044', 'D001065')  -- 경영기획실·경영지원실·국제협력실·디지털경영실·미래정책실·브랜드전략실
),
-- 2) 상위부서 하위 전체 노드 (상위부서 자신·중간 부서 포함), IS_LEAF = 팀 목록에 나오는 최하위 노드
TREE AS (
    SELECT L2.UPPER_DEPT_NM AS L1_NM, L2.DEPT_ID AS UP_ID, L2.DEPT_NM AS UP_NM,
           O.DEPT_ID, O.DEPT_NM,
           NOT EXISTS (SELECT 1 FROM GN_DW.SILVER.V_ORG_PICKER K WHERE K.UPPER_DEPT_ID = O.DEPT_ID) AS IS_LEAF
    FROM GN_DW.SILVER.V_ORG_PICKER O
    JOIN L2 ON O.ORG_PATH = L2.ORG_PATH OR STARTSWITH(O.ORG_PATH, L2.ORG_PATH || ' > ')
    WHERE O.ORG_LEVEL >= 2
),
-- 3) 팀 표시명: 회원실 하위 팀 전체 → 회원참여팀(DEPT_TEAM_MERGE) / 팀 통합(DEPT_TEAM_ALIAS)
TEAM AS (
    SELECT T.*,
           CASE WHEN T.UP_ID = 'C000006' THEN '회원참여팀'          -- 회원실: 하위 전체(중간·직속 포함) 통합
                WHEN NOT T.IS_LEAF THEN '(팀 미지정 · 전체에만 포함)'
                WHEN T.UP_ID = 'D001000' AND T.DEPT_NM = '미래전략사업팀' THEN '캠페인기획2팀'
                WHEN T.UP_ID = 'D001000' AND T.DEPT_NM IN ('사회개발교육팀', '세계시민교육센터') THEN '세계시민교육팀'
                WHEN T.UP_ID = 'C000010' AND T.DEPT_NM = '애자일프로젝트팀' THEN '컬쳐콘텐츠팀'
                ELSE T.DEPT_NM END AS TEAM_NM
    FROM TREE T
),
-- 4) 폐지·개편 실적부서 → 현재 조직 귀속 (DEPT_REMAP, 144건)
REMAP (OLD_DEPT_ID, CUR_DEPT_ID) AS (
    SELECT * FROM VALUES
        ('ZE000056', 'C000006'),
        ('ZE000003', 'C000010'),
        ('ZE000019', 'C000010'),
        ('ZE000011', 'C000010'),
        ('ZE000005', 'C000010'),
        ('D000124', 'D000126'),
        ('ZE000002', 'C000006'),
        ('ZE000004', 'C000010'),
        ('E001010', 'D000118'),
        ('ZE000015', 'C000006'),
        ('ZE000253', 'D000126'),
        ('D000155', 'D000116'),
        ('E001158', 'D001000'),
        ('ZE000008', 'C000010'),
        ('ZE000106', 'D000116'),
        ('ZE000007', 'C000006'),
        ('E000013', 'D000116'),
        ('ZE000250', 'D000126'),
        ('ZE000251', 'D000126'),
        ('ZE000148', 'D000116'),
        ('D000022', 'C001023'),
        ('D000156', 'D000121'),
        ('ZE000110', 'D000118'),
        ('E000011', 'D000116'),
        ('D000041', 'D000118'),
        ('D000027', 'D000116'),
        ('ZE000016', 'C000006'),
        ('E000036', 'D000118'),
        ('E000024', 'D000118'),
        ('E000037', 'D000118'),
        ('ZE000121', 'D000126'),
        ('E000082', 'D000126'),
        ('ZE000150', 'D000118'),
        ('E000088', 'D000126'),
        ('E000076', 'D000126'),
        ('E000016', 'D000116'),
        ('ZE000118', 'D000126'),
        ('ZE000252', 'D000126'),
        ('E001028', 'D000121'),
        ('ZE000093', 'D000123'),
        ('D000065', 'D000126'),
        ('E000119', 'D000118'),
        ('D000062', 'D000123'),
        ('F001001', 'D000118'),
        ('ZE000155', 'D000126'),
        ('E000062', 'D000123'),
        ('ZE000153', 'D000123'),
        ('E000068', 'D000126'),
        ('D000066', 'D000126'),
        ('ZE000086', 'D000121'),
        ('ZE000099', 'D000126'),
        ('ZE000113', 'D000118'),
        ('ZE000101', 'D000126'),
        ('ZE000154', 'D000126'),
        ('D000034', 'D000116'),
        ('D000076', 'D000126'),
        ('ZE000098', 'D000126'),
        ('ZE000071', 'D000116'),
        ('ZE000070', 'D000116'),
        ('D000048', 'D000118'),
        ('E000091', 'D000123'),
        ('D000051', 'D000121'),
        ('ZE000076', 'D000118'),
        ('ZE000066', 'D000116'),
        ('ZE000152', 'D000121'),
        ('ZE000078', 'D000118'),
        ('ZE000144', 'D000126'),
        ('ZE000069', 'D000116'),
        ('ZE000102', 'D000126'),
        ('ZE000006', 'C001023'),
        ('ZE000090', 'D000123'),
        ('D000071', 'D000126'),
        ('D000033', 'D000116'),
        ('ZE000108', 'D000116'),
        ('ZE000097', 'D000126'),
        ('D000037', 'D000116'),
        ('ZE000075', 'D000116'),
        ('D000077', 'D000126'),
        ('ZE000105', 'D000126'),
        ('D000078', 'D000123'),
        ('ZE000068', 'D000116'),
        ('ZE000087', 'D000123'),
        ('ZE000084', 'D000118'),
        ('ZE000079', 'D000118'),
        ('ZE000143', 'D000123'),
        ('ZE000072', 'D000116'),
        ('ZE000089', 'D000123'),
        ('ZE000100', 'D000126'),
        ('ZE000077', 'D000118'),
        ('ZE000149', 'D000116'),
        ('ZE000103', 'D000126'),
        ('D000061', 'D000123'),
        ('ZE000022', 'D001067'),
        ('ZE000083', 'D000118'),
        ('ZE000009', 'D001067'),
        ('ZE000091', 'D000123'),
        ('ZE000114', 'D000118'),
        ('ZE000145', 'D000126'),
        ('D000046', 'D000118'),
        ('ZE000088', 'D000123'),
        ('D000047', 'D000118'),
        ('ZE000104', 'D000126'),
        ('ZE000151', 'D000118'),
        ('ZE000080', 'D000118'),
        ('D000043', 'D000118'),
        ('ZE000073', 'D000116'),
        ('D000073', 'D000126'),
        ('ZE000067', 'D000116'),
        ('D000074', 'D000126'),
        ('ZE000085', 'D000118'),
        ('ZE000020', 'D001067'),
        ('ZE000050', 'D001067'),
        ('ZE000142', 'D000126'),
        ('ZE000092', 'D000123'),
        ('ZE000001', 'C001023'),
        ('ZE000146', 'D000126'),
        ('D000070', 'D000126'),
        ('ZE000128', 'D000126'),
        ('ZE000130', 'D000126'),
        ('ZE000141', 'D000126'),
        ('E001148', 'C001023'),
        ('E001004', 'C000010'),
        ('ZE000132', 'D000126'),
        ('ZE000082', 'D000118'),
        ('ZE000129', 'D000126'),
        ('ZE000131', 'D000126'),
        ('ZE000136', 'D000126'),
        ('ZE000134', 'D000123'),
        ('ZE000125', 'D000126'),
        ('ZE000247', 'D000126'),
        ('ZE000126', 'D000126'),
        ('ZE000122', 'D000126'),
        ('F001008', 'D000123'),
        ('ZE000095', 'D000123'),
        ('ZE000094', 'D000123'),
        ('ZE000107', 'D000116'),
        ('ZE000123', 'D000126'),
        ('ZE000074', 'D000116'),
        ('ZE000124', 'D000126'),
        ('E000096', 'D001000'),
        ('D000013', 'C000006'),
        ('D000152', 'D000012'),
        ('ZE000062', 'D001000'),
        ('ZE000058', 'D001000')
),
-- 5) 실적부서 코드 → 귀속 부서 (현재 조직 코드는 자기 자신, 폐지·개편 코드는 REMAP 대상)
CODE_MAP AS (
    SELECT DEPT_ID AS ACMSLT_DEPT_CD, DEPT_ID AS CUR_DEPT_ID FROM TEAM
    UNION ALL
    SELECT R.OLD_DEPT_ID, R.CUR_DEPT_ID FROM REMAP R JOIN TEAM T ON T.DEPT_ID = R.CUR_DEPT_ID
),
-- 6) 사단법인 회원 중단 후원 (예시: 2026년)
STOP AS (
    SELECT B.ACMSLT_DEPT_CD
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M ON M.MBER_NO = B.MBER_NO
    WHERE A.SPNSR_DSCNTC_YN = 'Y'
      AND A.SPNSR_DSCNTC_DE BETWEEN '20260101' AND '20261231'
      AND M.CPR_DIV_CD = 'I'
)
-- 7) 드릴다운 귀속 결과 — 매핑 안 되는 코드(사복·시설·제외·실적부서 없음)는 (사복·기타 실적부서)
SELECT COALESCE(T.L1_NM, '-')                    AS L1_NM,
       COALESCE(T.UP_NM, '(사복·기타 실적부서)')   AS UP_DEPT_NM,
       COALESCE(T.TEAM_NM, COALESCE(D.DEPT_NM, '실적부서 없음')) AS TEAM_NM,
       COUNT(*)                                  AS STOP_SPNSR_CNT
FROM STOP S
LEFT JOIN CODE_MAP C ON C.ACMSLT_DEPT_CD = S.ACMSLT_DEPT_CD
LEFT JOIN TEAM T ON T.DEPT_ID = C.CUR_DEPT_ID
LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON D.DEPT_ID = S.ACMSLT_DEPT_CD
GROUP BY 1, 2, 3
ORDER BY (UP_DEPT_NM = '(사복·기타 실적부서)'), 1, 2, 4 DESC;

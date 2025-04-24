/* -----------------------------------------------------------
   COHORT: Adult (≥18 y) ICU patients with acute MI
           MIMIC‑IV v3.1  (hosp & icu datasets only)
   ----------------------------------------------------------- */

-- ╭────────────────────────── STEP 1 ─────────────────────────╮
-- │ Exclude admissions with pregnancy ICD codes              │
-- ╰───────────────────────────────────────────────────────────╯
WITH non_pregnant_admissions AS (
  SELECT hadm_id
  FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
  GROUP BY hadm_id
  HAVING
    SUM(
      CASE
        WHEN icd_version = 10
         AND SUBSTR(icd_code,1,3) IN (
              'O00','O01','O02','O03','O04','O05','O06','O07','O08','O09',
              'O10','O11','O12','O13','O14','O15','O16','O20','O21','O22',
              'O23','O24','O25','O26','O28','O29','O30','O31','O32','O33',
              'O34','O35','O36','O37','O40','O41','O42','O43','O44','O45',
              'O46','O47','O48','O60','O61','O62','O63','O64','O65','O66',
              'O67','O68','O69','O70','O71','O72','O73','O74','O75','O80',
              'O81','O82','O83','O84','O85','O86','O87','O88','O89','O90',
              'O91','O92','O94','O95','O96','O97','O98','O99','O9A'
            ) THEN 1
        WHEN icd_version = 9
         AND (
              SAFE_CAST(SUBSTR(icd_code,1,3) AS INT64) BETWEEN 630 AND 679
              OR SUBSTR(icd_code,1,3) IN ('V22','V23','V24','V27','V28')
            ) THEN 1
        ELSE 0
      END
    ) = 0
),

-- ╭────────────────────────── STEP 2 ─────────────────────────╮
-- │ MI admissions (ICD‑9 & ICD‑10)                           │
-- ╰───────────────────────────────────────────────────────────╯
mi_admissions AS (
  SELECT DISTINCT hadm_id
  FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
  WHERE icd_code IN (
    '41000','41001','41002','41010','41011','41012','41020','41021','41022',
    '41030','41031','41032','41040','41041','41042','41050','41051','41052',
    '41080','41081','41082','41090','41091','41092','4110','41181','412','42979',
    'I21','I210','I2101','I2102','I2109','I211','I2111','I2119','I212','I2121',
    'I2129','I213','I214','I219','I21A','I21A1','I21A9','I22','I220','I221',
    'I222','I228','I229','I23','I230','I231','I232','I233','I234','I235',
    'I236','I238','I240','I252'
  )
),

-- ╭────────────────────────── STEP 3 ─────────────────────────╮
-- │ Adult ICU stays, non‑pregnant, MI                        │
-- ╰───────────────────────────────────────────────────────────╯
all_icu_admissions AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    icu.intime  AS icu_admit_time,
    icu.outtime AS icu_discharge_time,
    adm.admittime,
    adm.dischtime,
    adm.race,
    pat.anchor_age,
    pat.gender,
    pat.dod,
    adm.admission_type,
    adm.edregtime,
    adm.insurance
  FROM `physionet-data.mimiciv_3_1_icu.icustays`     icu
  JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
    ON icu.hadm_id = adm.hadm_id
  JOIN `physionet-data.mimiciv_3_1_hosp.patients`   pat
    ON icu.subject_id = pat.subject_id
  JOIN non_pregnant_admissions np ON icu.hadm_id = np.hadm_id
  JOIN mi_admissions          mi ON icu.hadm_id = mi.hadm_id
  WHERE pat.anchor_age >= 18
),

-- ╭────────────────────────── STEP 4 ─────────────────────────╮
-- │ Last ICU stay per hospital admission                     │
-- ╰───────────────────────────────────────────────────────────╯
final_icu_stay AS (
  SELECT *
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY hadm_id ORDER BY icu_admit_time DESC) AS rn
    FROM all_icu_admissions
  )
  WHERE rn = 1
),

-- ╭────────────────────────── STEP 5 ─────────────────────────╮
-- │ Earliest HbA1c (item 50852) ±3 months                    │
-- ╰───────────────────────────────────────────────────────────╯
earliest_hba1c AS (
  SELECT
    le.subject_id,
    le.hadm_id,
    le.charttime,
    le.valuenum AS hba1c,
    ROW_NUMBER() OVER (
      PARTITION BY le.subject_id, le.hadm_id
      ORDER BY le.charttime
    ) AS rn
  FROM `physionet-data.mimiciv_3_1_hosp.labevents` le
  JOIN final_icu_stay icu
    ON le.subject_id = icu.subject_id
   AND le.hadm_id    = icu.hadm_id
  WHERE le.itemid = 50852
    AND le.valuenum IS NOT NULL
    AND le.charttime BETWEEN DATE_SUB(icu.admittime, INTERVAL 3 MONTH)
                        AND DATE_ADD (icu.admittime, INTERVAL 3 MONTH)
),

-- ╭────────────────────────── STEP 6 ─────────────────────────╮
-- │ Cohort + mortality flags                                 │
-- ╰───────────────────────────────────────────────────────────╯
cohort AS (
  SELECT
    icu.*,
    h.hba1c,
    h.charttime AS hba1c_charttime,
    DATE_DIFF(icu.icu_admit_time, h.charttime, DAY) AS days_between_hba1c_and_icu,

    -- in‑hospital
    CASE WHEN dod IS NOT NULL
          AND dod BETWEEN icu.admittime AND icu.dischtime THEN 1 ELSE 0 END AS died_in_hosp,

    -- ≤30 days post‑discharge
    CASE WHEN dod IS NOT NULL
          AND DATE_DIFF(dod, icu.dischtime, DAY) BETWEEN 0 AND 30 THEN 1 ELSE 0 END AS died_30day,

    -- ≤365 days post‑discharge
    CASE WHEN dod IS NOT NULL
          AND DATE_DIFF(dod, icu.dischtime, DAY) BETWEEN 0 AND 365 THEN 1 ELSE 0 END AS died_1year
  FROM final_icu_stay icu
  JOIN earliest_hba1c h
    ON icu.subject_id = h.subject_id
   AND icu.hadm_id    = h.hadm_id
  WHERE h.rn = 1
),

/* ===========================================================
   STEP 7 – SOFA (worst value in first 24 h)
   =========================================================== */
base AS (
  SELECT stay_id, subject_id, icu_admit_time AS intime
  FROM cohort
),

-- Respiratory
pao2 AS (
  SELECT subject_id, charttime, valuenum AS pao2
  FROM `physionet-data.mimiciv_3_1_hosp.labevents`
  WHERE itemid = 50821
),
fio2 AS (
  SELECT stay_id, charttime,
         CASE WHEN valuenum > 1 THEN valuenum/100 ELSE valuenum END AS fio2
  FROM `physionet-data.mimiciv_3_1_icu.chartevents`
  WHERE itemid IN (190, 3420, 223835)
    AND valuenum BETWEEN 0.15 AND 100
),
pf_pairs AS (
  SELECT b.stay_id,
         p.charttime,
         p.pao2,
         FIRST_VALUE(f.fio2) OVER (
           PARTITION BY b.stay_id, p.charttime
           ORDER BY ABS(TIMESTAMP_DIFF(f.charttime, p.charttime, MINUTE))
         ) AS fio2_near
  FROM base b
  JOIN pao2 p ON p.subject_id = b.subject_id
  JOIN fio2 f ON f.stay_id    = b.stay_id
  WHERE p.charttime BETWEEN b.intime AND DATETIME_ADD(b.intime, INTERVAL 24 HOUR)
    AND f.charttime BETWEEN DATETIME_SUB(p.charttime, INTERVAL 120 MINUTE)
                        AND DATETIME_ADD(p.charttime, INTERVAL 120 MINUTE)
),
resp_score AS (
  SELECT stay_id,
         CASE
           WHEN MIN(pao2/fio2_near) < 100 THEN 4
           WHEN MIN(pao2/fio2_near) < 200 THEN 3
           WHEN MIN(pao2/fio2_near) < 300 THEN 2
           WHEN MIN(pao2/fio2_near) < 400 THEN 1
           ELSE 0
         END AS resp
  FROM pf_pairs
  GROUP BY stay_id
),

-- Coagulation
coag_score AS (
  SELECT b.stay_id,
         CASE
           WHEN MIN(le.valuenum) < 20  THEN 4
           WHEN MIN(le.valuenum) < 50  THEN 3
           WHEN MIN(le.valuenum) < 100 THEN 2
           WHEN MIN(le.valuenum) < 150 THEN 1
           ELSE 0
         END AS coag
  FROM base b
  JOIN `physionet-data.mimiciv_3_1_hosp.labevents` le
    ON le.subject_id = b.subject_id
  WHERE le.itemid = 51265
    AND le.charttime BETWEEN b.intime AND DATETIME_ADD(b.intime, INTERVAL 24 HOUR)
  GROUP BY b.stay_id
),

-- Liver
liver_score AS (
  SELECT b.stay_id,
         CASE
           WHEN MAX(le.valuenum) >= 12  THEN 4
           WHEN MAX(le.valuenum) >= 6   THEN 3
           WHEN MAX(le.valuenum) >= 2   THEN 2
           WHEN MAX(le.valuenum) >= 1.2 THEN 1
           ELSE 0
         END AS liver
  FROM base b
  JOIN `physionet-data.mimiciv_3_1_hosp.labevents` le
    ON le.subject_id = b.subject_id
  WHERE le.itemid = 50885
    AND le.charttime BETWEEN b.intime AND DATETIME_ADD(b.intime, INTERVAL 24 HOUR)
  GROUP BY b.stay_id
),

-- Cardiovascular (MAP only)
cardio_score AS (
  SELECT stay_id,
         CASE WHEN MIN(map) < 70 THEN 1 ELSE 0 END AS cardio
  FROM (
    SELECT b.stay_id, MIN(ce.valuenum) AS map
    FROM base b
    JOIN `physionet-data.mimiciv_3_1_icu.chartevents` ce
      ON ce.stay_id = b.stay_id
    WHERE ce.itemid IN (52, 456, 220181)
      AND ce.charttime BETWEEN b.intime AND DATETIME_ADD(b.intime, INTERVAL 24 HOUR)
    GROUP BY b.stay_id
  )
  GROUP BY stay_id
),

-- CNS
gcs_components AS (
  SELECT stay_id,
         charttime,
         MAX(CASE WHEN itemid IN (198,223900) THEN valuenum END) AS eye,
         MAX(CASE WHEN itemid IN (184,223901) THEN valuenum END) AS motor,
         MAX(CASE WHEN itemid IN (454,223902) THEN valuenum END) AS verbal
  FROM `physionet-data.mimiciv_3_1_icu.chartevents`
  WHERE itemid IN (198,184,454,223900,223901,223902)
  GROUP BY stay_id, charttime
),
gcs_score AS (
  SELECT b.stay_id,
         CASE
           WHEN MIN(total) < 6  THEN 4
           WHEN MIN(total) < 9  THEN 3
           WHEN MIN(total) < 12 THEN 2
           WHEN MIN(total) < 15 THEN 1
           ELSE 0
         END AS cns
  FROM (
    SELECT stay_id,
           charttime,
           COALESCE(eye,0)+COALESCE(motor,0)+COALESCE(verbal,0) AS total
    FROM gcs_components
  ) t
  JOIN base b USING (stay_id)
  WHERE charttime BETWEEN intime AND DATETIME_ADD(intime, INTERVAL 24 HOUR)
  GROUP BY b.stay_id
),

-- Renal
renal_score AS (
  SELECT b.stay_id,
         CASE
           WHEN MAX(le.valuenum) >= 5.0 THEN 4
           WHEN MAX(le.valuenum) >= 3.5 THEN 3
           WHEN MAX(le.valuenum) >= 2.0 THEN 2
           WHEN MAX(le.valuenum) >= 1.2 THEN 1
           ELSE 0
         END AS renal
  FROM base b
  JOIN `physionet-data.mimiciv_3_1_hosp.labevents` le
    ON le.subject_id = b.subject_id
  WHERE le.itemid = 50912
    AND le.charttime BETWEEN b.intime AND DATETIME_ADD(b.intime, INTERVAL 24 HOUR)
  GROUP BY b.stay_id
),

sofa_scores AS (
  SELECT
    b.stay_id,
    COALESCE(resp,0)+COALESCE(coag,0)+COALESCE(liver,0)+
    COALESCE(cardio,0)+COALESCE(cns,0)+COALESCE(renal,0) AS sofa_24h
  FROM base b
  LEFT JOIN resp_score   USING (stay_id)
  LEFT JOIN coag_score   USING (stay_id)
  LEFT JOIN liver_score  USING (stay_id)
  LEFT JOIN cardio_score USING (stay_id)
  LEFT JOIN gcs_score    USING (stay_id)
  LEFT JOIN renal_score  USING (stay_id)
),

/* ===========================================================
   STEP 8 – Medication flags
   =========================================================== */
medications AS (
  SELECT
    hadm_id,
    MAX(CASE WHEN REGEXP_CONTAINS(LOWER(medication), r'\baspirin\b')      THEN 1 ELSE 0 END) AS aspirin_use,
    MAX(CASE WHEN REGEXP_CONTAINS(LOWER(medication), r'\bclopidogrel\b')  THEN 1 ELSE 0 END) AS clopidogrel_use,
    MAX(CASE WHEN REGEXP_CONTAINS(LOWER(medication), r'\bprasugrel\b')    THEN 1 ELSE 0 END) AS prasugrel_use,
    MAX(CASE WHEN REGEXP_CONTAINS(LOWER(medication), r'\bticagrelor\b')   THEN 1 ELSE 0 END) AS ticagrelor_use,
    MAX(CASE WHEN REGEXP_CONTAINS(
                 LOWER(medication),
                 r'statin|atorvastatin|simvastatin|rosuvastatin|pravastatin|lovastatin|fluvastatin|pitavastatin')
             THEN 1 ELSE 0 END) AS statin_use,
    MAX(CASE WHEN REGEXP_CONTAINS(LOWER(medication), r'insulin')          THEN 1 ELSE 0 END) AS insulin_use
  FROM `physionet-data.mimiciv_3_1_hosp.pharmacy`
  GROUP BY hadm_id
),

/* ===========================================================
   STEP 9 – Comorbidities & shock
   =========================================================== */
comorbid AS (
  SELECT
    cohort.hadm_id,
    CASE
      WHEN MAX(CASE
                 WHEN (icd_code LIKE '410%')
                   OR (icd_code LIKE 'I21[0-3]%' OR icd_code LIKE 'I22[0-2]%')
               THEN 1 ELSE 0 END) = 1 THEN 'STEMI'
      ELSE 'NSTEMI'
    END AS mi_severity,
    MAX(CASE WHEN icd_code LIKE '401%' THEN 1 ELSE 0 END) AS hypertension,
    MAX(CASE WHEN icd_code IN ('4280','4281','42820','42821','42822',
                               '42823','42830','42831','42832','42833',
                               '42840','42841','42842','42843','4289') THEN 1 ELSE 0 END) AS heart_failure,
    MAX(CASE WHEN icd_code LIKE '585%' THEN 1 ELSE 0 END) AS chronic_renal_failure,
    MAX(CASE WHEN icd_code IN ('78551','R570','T8111','T8111XA',
                               'T8111XD','T8111XS','99801') THEN 1 ELSE 0 END) AS shock,
    MAX(CASE
          WHEN (icd_version = 9  AND icd_code LIKE '250%')
            OR (icd_version = 10 AND SUBSTR(icd_code,1,3) IN ('E08','E09','E10','E11','E13'))
          THEN 1 ELSE 0 END) AS diabetes_mellitus
  FROM cohort
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.diagnoses_icd` diag
    ON cohort.hadm_id = diag.hadm_id
  GROUP BY cohort.hadm_id
),

/* ===========================================================
   STEP 10 – Latest labs before ICU admit
   =========================================================== */
labeled_labs AS (
  SELECT
    le.subject_id, le.hadm_id, le.charttime, le.valuenum, di.label
  FROM `physionet-data.mimiciv_3_1_hosp.labevents` le
  JOIN `physionet-data.mimiciv_3_1_hosp.d_labitems` di
    ON le.itemid = di.itemid
  JOIN cohort c
    ON le.subject_id = c.subject_id AND le.hadm_id = c.hadm_id
  WHERE le.valuenum IS NOT NULL
    AND le.charttime <= c.icu_admit_time
    AND di.label IN ('Creatinine','WBC','Glucose','Hemoglobin','eGFR')
),
recent_labs AS (
  SELECT
    subject_id, hadm_id, label, valuenum,
    ROW_NUMBER() OVER (
      PARTITION BY subject_id, hadm_id, label
      ORDER BY charttime DESC
    ) AS rn
  FROM labeled_labs
),
pivot_labs AS (
  SELECT *
  FROM (
    SELECT subject_id, hadm_id, label, valuenum
    FROM recent_labs
    WHERE rn = 1
  )
  PIVOT (
    MAX(valuenum) FOR label IN ('Creatinine','WBC','Glucose','Hemoglobin','eGFR')
  )
),

/* ===========================================================
   STEP 11 – Final merge
   =========================================================== */
final_output AS (
  SELECT
    c.*,                               -- includes dod
    com.mi_severity,
    com.hypertension,
    com.heart_failure,
    com.chronic_renal_failure,
    com.shock,
    com.diabetes_mellitus,
    m.aspirin_use,
    m.clopidogrel_use,
    m.prasugrel_use,
    m.ticagrelor_use,
    m.statin_use,
    m.insulin_use,
    p.*,
    s.sofa_24h
  FROM cohort           c
  LEFT JOIN sofa_scores s   USING (stay_id)
  LEFT JOIN medications  m  ON c.hadm_id = m.hadm_id
  LEFT JOIN comorbid     com ON c.hadm_id = com.hadm_id
  LEFT JOIN pivot_labs   p   ON c.subject_id = p.subject_id
                            AND c.hadm_id   = p.hadm_id
)

/* ===========================================================
   RETURN
   =========================================================== */
SELECT *
FROM final_output
LIMIT 1000;

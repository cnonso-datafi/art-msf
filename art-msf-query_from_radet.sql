WITH all_records AS (
	WITH bio_data AS (SELECT DISTINCT (p.uuid) AS personUuid,p.hospital_number AS hospitalNumber,
	EXTRACT(YEAR FROM  AGE(CURRENT_DATE, date_of_birth)) AS age,
	INITCAP(p.sex) AS gender,
	p.date_of_birth AS dateOfBirth,
	facility.name AS facilityName,
	facility_lga.name AS lga,
	facility_state.name AS state,
	boui.code AS datimId,
	p.date_of_registration as dateOfRegistration,
	EXTRACT(YEAR FROM AGE(date_of_birth))::int AS age_years,
	CASE
		            WHEN date_of_birth IS NULL THEN 'Unknown'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) < 1 THEN '<1'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 1 AND 4 THEN '1-4'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 5 AND 9 THEN '5-9'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 10 AND 14 THEN '10-14'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 15 AND 19 THEN '15-19'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 20 AND 24 THEN '20-24'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 25 AND 29 THEN '25-29'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 30 AND 34 THEN '30-34'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 35 AND 39 THEN '35-39'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 40 AND 44 THEN '40-44'
		            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 45 AND 49 THEN '45-49'
		            ELSE '50+'
		        END AS age_group
	FROM patient_person p
	INNER JOIN base_organisation_unit facility ON facility.id = facility_id
	INNER JOIN base_organisation_unit facility_lga ON facility_lga.id = facility.parent_organisation_unit_id
	INNER JOIN base_organisation_unit facility_state ON facility_state.id = facility_lga.parent_organisation_unit_id
	INNER JOIN base_organisation_unit_identifier boui ON boui.organisation_unit_id = facility_id AND boui.name='DATIM_ID'
	INNER JOIN hiv_enrollment_commencement h ON h.person_uuid = p.uuid
	WHERE p.facility_id = 1624 AND p.archived = 0
	),
	hivEnrollment AS (
	SELECT person_uuid personUuid101, unique_id uniqueId, date_art_started artStartDate, dateEnrolled, hrt.description regimenLineAtStart, is_kp, kp_typology_id,
	hr.description regimenAtStart, ecareEntry.display careEntry, eSetting.display enrollmentSetting, ovc_unique_id ovcNumber, household_unique_number householdNumber,
	hrInh.description tpt_medication, tpt_dose, tpt_start_date, tpt_completed, tpt_completion_date, cd_4 FROM (
	SELECT person_uuid, unique_id, is_kp, kp_typology_id, COALESCE(date_art_started,visit_date,date_enrolled_in_hiv_care) date_art_started, COALESCE(date_enrolled_in_hiv_care, visit_date) dateEnrolled,
	visit_date, regimen_line_id, regimen_id, care_entry_point_id, enrollment_setting, ovc_data->>'ovc_unique_id' ovc_unique_id, ovc_data->>'household_unique_number' household_unique_number,
	tpt_medication, tpt_dose, tpt_start_date, tpt_completed, tpt_completion_date,COALESCE(cd4_at_art_start, cd4_percentage) AS cd_4,
	ROW_NUMBER() OVER (PARTITION BY person_uuid ORDER by visit_date DESC) rnkk
	FROM hiv_enrollment_commencement
	WHERE archived = 0 AND visit_date BETWEEN '1901-01-01' AND CURRENT_DATE AND facility_id = 1624 AND CAST(regimen_line_id AS INTEGER) IN (1,2,3,4,14, 16)
	) sub
	LEFT JOIN base_application_codeset eSetting ON eSetting.code = sub.enrollment_setting
	LEFT JOIN base_application_codeset ecareEntry ON ecareEntry.code = sub.care_entry_point_id
	LEFT JOIN hiv_regimen hrInh ON hrInh.id = sub.tpt_medication
	INNER JOIN hiv_regimen hr ON hr.id = sub.regimen_id
	INNER JOIN hiv_regimen_type hrt ON hrt.id = sub.regimen_line_id AND sub.regimen_line_id IN (1,2,3,4,14, 16)
	WHERE rnkk = 1
	),
	patient_lga as (select DISTINCT ON (personUuid) personUuid as personUuid11,
	case when (addr ~ '^[0-9\\\\\\\\\\\\\\\\\\\\.]+$') =TRUE
	 then (select name from base_organisation_unit where id = cast(addr as int)) ELSE
	(select name from base_organisation_unit where id = cast(facilityLga as int)) end as lgaOfResidence
	from (
	 select pp.uuid AS personUuid, facility_lga.parent_organisation_unit_id AS facilityLga, (jsonb_array_elements(pp.address->'address')->>'district') as addr from patient_person pp
	LEFT JOIN base_organisation_unit facility_lga ON facility_lga.id = CAST (pp.organization->'id' AS INTEGER)
	) dt),
	current_clinical AS (SELECT * FROM (
	SELECT tvs.person_uuid AS person_uuid10, hac.visit_date, CAST(tvs.capture_date AS DATE),
	CASE
	WHEN hac.tb_screen IS NOT NULL THEN hac.visit_date
	ELSE NULL
	END AS dateOfTbScreened1,
	(CASE
	WHEN INITCAP(pp.sex) = 'Male' THEN NULL
	WHEN hac.pregnancy_status IS NOT NULL THEN preg.display
	END ) AS pregnancyStatus, bac.display AS currentClinicalStage,
	body_weight AS currentWeight, tbs.display AS tbStatus1, bacDsdStatus.display dsd_status, bacDsdModel.display dsd_model, date_devolved,
	ROW_NUMBER() OVER (PARTITION BY hac.person_uuid ORDER BY hac.visit_date DESC) AS rnkkkk
	FROM hiv_art_clinical hac
	INNER JOIN triage_vital_sign tvs ON tvs.uuid = hac.vital_sign_uuid
	LEFT JOIN patient_person pp ON hac.person_uuid = pp.uuid
	INNER JOIN hiv_enrollment_commencement he ON he.person_uuid = hac.person_uuid
	LEFT JOIN base_application_codeset bacDsdStatus ON bacDsdStatus.code = hac.dsd_status
	LEFT JOIN base_application_codeset bacDsdModel ON bacDsdModel.code = hac.dsd_model
	LEFT JOIN base_application_codeset bac ON bac.id = hac.clinical_stage_id
	LEFT JOIN base_application_codeset preg ON preg.code = hac.pregnancy_status
	LEFT JOIN base_application_codeset tbs ON tbs.id = CASE WHEN hac.tb_status ~ '^[0-9]+$' THEN CAST(hac.tb_status AS INTEGER) ELSE 0 END  
	WHERE hac.archived = 0 AND he.archived = 0 AND tvs.archived = 0 AND he.facility_id = 1624  AND hac.visit_date BETWEEN '1901-01-01' AND CURRENT_DATE) subQ where rnkkkk = 1
	),
	sample_collection_date AS (
	  SELECT sample.date_sample_collected as dateOfViralLoadSampleCollection, patient_uuid as person_uuid120  FROM (
	SELECT lt.viral_load_indication, sm.facility_id,CAST(sm.date_sample_collected AS DATE), sm.patient_uuid, sm.archived, ROW_NUMBER () OVER (PARTITION BY sm.patient_uuid ORDER BY date_sample_collected DESC) as rnkk
	FROM public.laboratory_sample  sm
	  INNER JOIN public.laboratory_test lt ON lt.id = sm.test_id
	WHERE lt.lab_test_id=16 AND CAST(sm.date_sample_collected AS DATE) <= CURRENT_DATE AND (sm.archived is null OR sm.archived = 0)
	AND  lt.viral_load_indication !=719
	AND sm.date_sample_collected IS NOT null
	 )as sample
	WHERE sample.rnkk = 1 AND sample.facility_id = 1624),
	tbstatus as (
	WITH cs AS (
	WITH FilteredObservations AS (
	 SELECT id, person_uuid, date_of_observation AS dateOfTbScreened,
	(CASE
	WHEN data->'tbIptScreening'->>'status' = 'Presumptive TB and referred for evaluation'
	THEN 'Presumptive TB'
	ELSE data->'tbIptScreening'->>'status'
	 END) AS tbStatus,
	CASE
	WHEN EXTRACT(MONTH FROM CAST (date_of_observation AS DATE)) BETWEEN 10 AND 12
	OR EXTRACT(MONTH FROM CAST (date_of_observation AS DATE)) BETWEEN 1 AND 3
	THEN 'October - March'
	WHEN EXTRACT(MONTH FROM CAST (date_of_observation AS DATE)) BETWEEN 4 AND 9
	THEN 'April - September'
	 END AS reportingPeriod,
	EXTRACT(YEAR FROM date_of_observation) AS yearOfReporting,
	 data->'tbIptScreening'->>'tbScreeningType' AS tbScreeningType,
	 ROW_NUMBER() OVER (PARTITION BY person_uuid ORDER BY date_of_observation DESC) AS rowNums
	 FROM
	 hiv_observation
	 WHERE
	 type = 'Chronic Care'
	 AND data IS NOT NULL AND archived = 0
	 -- Peter Start
	-- AND date_of_observation BETWEEN (CAST (CURRENT_DATE AS DATE) - INTERVAL '6 MONTHS') AND CAST(CURRENT_DATE AS DATE)
	-- Peter End
	),
	FilteredLatestObservations AS (
	 SELECT id, person_uuid, dateOfTbScreened, tbStatus, tbScreeningType, reportingPeriod, yearOfReporting
	 FROM
	 FilteredObservations
	 WHERE rowNums = 1
	),
	ReportingPeriod AS (
	 SELECT
	 CASE
	WHEN EXTRACT(MONTH FROM CAST (CURRENT_DATE AS DATE)) BETWEEN 10 AND 12
	OR EXTRACT(MONTH FROM CAST (CURRENT_DATE AS DATE)) BETWEEN 1 AND 3
	THEN 'October - March'
	WHEN EXTRACT(MONTH FROM CAST (CURRENT_DATE AS DATE)) BETWEEN 4 AND 9
	THEN 'April - September'
	 END AS currentReportingPeriod
	),
	PresumptiveCheck AS (
	SELECT DISTINCT person_uuid, ho.date_of_observation dateScreened, ho.data->'tbIptScreening'->>'status' AS tbStatus, ho.data->'tbIptScreening'->>'tbScreeningType' tbScreeningType,
	CASE
	WHEN EXTRACT(MONTH FROM CAST (ho.date_of_observation AS DATE)) BETWEEN 10 AND 12
	OR EXTRACT(MONTH FROM CAST (ho.date_of_observation AS DATE)) BETWEEN 1 AND 3
	THEN 'October - March'
	WHEN EXTRACT(MONTH FROM CAST (ho.date_of_observation AS DATE)) BETWEEN 4 AND 9
	THEN 'April - September'
	 END AS preSumpReportingPeriod
	FROM hiv_observation ho
	  WHERE ho.type = 'Chronic Care'
	AND ho.data IS NOT NULL
	-- Peter Start
	-- AND ho.archived = 0 AND ho.date_of_observation BETWEEN (CAST (CURRENT_DATE AS DATE) - INTERVAL '6 MONTHS') AND CAST(CURRENT_DATE AS DATE)
	-- Peter End
	AND ho.data->'tbIptScreening'->>'status' ILIKE 'Presumptive TB%'
	)
	SELECT
	lo.id,
	lo.person_uuid,
	CASE WHEN rp.currentReportingPeriod = pc.preSumpReportingPeriod THEN pc.tbStatus
	WHEN lo.reportingPeriod = rp.currentReportingPeriod  THEN lo.tbStatus ELSE NULL END AS tbStatus,
	CASE WHEN rp.currentReportingPeriod = pc.preSumpReportingPeriod THEN pc.dateScreened
	WHEN lo.reportingPeriod = rp.currentReportingPeriod  THEN lo.dateOfTbScreened ELSE NULL END AS dateOfTbScreened,
	CASE WHEN rp.currentReportingPeriod = pc.preSumpReportingPeriod THEN pc.tbScreeningType
	WHEN lo.reportingPeriod = rp.currentReportingPeriod  THEN lo.tbScreeningType ELSE NULL END AS tbScreeningType
	  FROM
	FilteredLatestObservations lo
	LEFT JOIN PresumptiveCheck pc ON  pc.person_uuid = lo.person_uuid
	CROSS JOIN ReportingPeriod rp
	)
	SELECT * FROM cs ),
	tblam AS (
	  SELECT
	*
	  FROM (
	 SELECT
	 CAST(lr.date_result_reported AS DATE) AS dateOfLastTbLam,
	 lr.patient_uuid as personuuidtblam,
	 lr.result_reported as tbLamResult,
	 ROW_NUMBER () OVER (
	PARTITION BY lr.patient_uuid
	ORDER BY
	lr.date_result_reported DESC
	 ) as rank2333
	 FROM
	 laboratory_result lr
	 INNER JOIN public.laboratory_test lt on lr.test_id = lt.id
	 WHERE
	 lt.lab_test_id = 51
	 AND lr.date_result_reported IS NOT NULL
	 AND lr.date_result_reported <= CURRENT_DATE
	 AND lr.date_result_reported >= '1901-01-01'
	 AND lr.result_reported is NOT NULL
	 AND lr.archived = 0
	 AND lr.facility_id = 1624
	) as tblam
	  WHERE
	tblam.rank2333 = 1
	),
	current_vl_result AS (SELECT * FROM (
	  SELECT CAST(ls.date_sample_collected AS DATE ) AS dateOfCurrentViralLoadSample, sm.patient_uuid as person_uuid130 , sm.facility_id as vlFacility, sm.archived as vlArchived, acode.display as viralLoadIndication, sm.result_reported as currentViralLoad,CAST(sm.date_result_reported AS DATE) as dateOfCurrentViralLoad,
	ROW_NUMBER () OVER (PARTITION BY sm.patient_uuid ORDER BY ls.date_sample_collected DESC) as rank2
	  FROM public.laboratory_result  sm
	 INNER JOIN public.laboratory_test  lt on sm.test_id = lt.id
	  INNER JOIN public.laboratory_sample ls on ls.test_id = lt.id
	 INNER JOIN public.base_application_codeset  acode on acode.id =  lt.viral_load_indication
	  WHERE lt.lab_test_id = 16 AND CAST(ls.date_sample_collected AS DATE) BETWEEN '1901-01-01' AND CURRENT_DATE
	AND  lt.viral_load_indication !=719
	AND sm. date_result_reported IS NOT NULL AND CAST(sm. date_result_reported AS DATE) <= CURRENT_DATE
	AND sm.result_reported is NOT NULL
	)as vl_result
	WHERE vl_result.rank2 = 1 AND vl_result.dateOfCurrentViralLoad <= CURRENT_DATE
	AND (vl_result.vlArchived = 0 OR vl_result.vlArchived is null)
	AND  vl_result.vlFacility = 1624
	),
	labCD4 AS (SELECT * FROM (
	SELECT sm.patient_uuid AS cd4_person_uuid,  sm.result_reported as cd4Lb,sm.date_result_reported as dateOfCD4Lb, ROW_NUMBER () OVER (PARTITION BY sm.patient_uuid ORDER BY date_result_reported DESC) as rnk
	FROM public.laboratory_result  sm
	INNER JOIN public.laboratory_test  lt on sm.test_id = lt.id
	WHERE lt.lab_test_id IN (1, 50)
	AND sm. date_result_reported IS NOT NULL
	AND sm.archived = 0
	AND sm.facility_id = 1624
	AND CAST(sm.date_result_reported AS DATE) <= CURRENT_DATE
	 )as cd4_result
	WHERE  cd4_result.rnk = 1
	),
	tb_sample_collection AS (SELECT sample.created_by,CAST(sample.date_sample_collected AS DATE) as dateOfTbSampleCollection, patient_uuid as personTbSample  FROM (
	SELECT llt.lab_test_name,sm.created_by, lt.viral_load_indication, sm.facility_id,sm.date_sample_collected, sm.patient_uuid, sm.archived, ROW_NUMBER () OVER (PARTITION BY sm.patient_uuid ORDER BY date_sample_collected DESC) as rnkk
	FROM public.laboratory_sample  sm
	  INNER JOIN public.laboratory_test lt ON lt.id = sm.test_id
	  INNER JOIN  laboratory_labtest llt on llt.id = lt.lab_test_id
	WHERE lt.lab_test_id IN (65, 66, 51, 64, 67, 72, 71, 86, 58, 73)
	 AND sm.archived = 0 AND date_sample_collected IS NOT null
	 AND sm.date_sample_collected <= CURRENT_DATE
	 AND sm.facility_id = 1624
	 )as sample
	 WHERE sample.rnkk = 1
	),
	current_tb_result AS (WITH tb_test as (SELECT personTbResult, dateofTbDiagnosticResultReceived, dateOfTbSampleCollected, tbDiagnosticResult,
	coalesce(
	MAX(CASE WHEN lab_test_id = 66 THEN 'Chest X-ray' END) ,
	MAX(CASE WHEN lab_test_id = 65 THEN 'Gene Xpert' END) ,
	MAX(CASE WHEN lab_test_id = 51 THEN 'TB-LAM' END) ,
	MAX(CASE WHEN lab_test_id = 64 THEN 'AFB Smear Microscopy' END),
	MAX(CASE WHEN lab_test_id = 67 THEN 'Gene Xpert' END) ,
	MAX(CASE WHEN lab_test_id = 72 THEN 'TrueNAT' END) ,
	MAX(CASE WHEN lab_test_id = 71 THEN 'TB-LAM' END) ,
	MAX(CASE WHEN lab_test_id = 86 THEN 'Cobas' END) ,
	MAX(CASE WHEN lab_test_id = 73 THEN 'TB-LAMP' END) ,
	MAX(CASE WHEN lab_test_id = 58 THEN 'TB-LAM' END)
	) as tbDiagnosticTestType
	 FROM (
	SELECT sm.patient_uuid as personTbResult, CASE WHEN (CAST(lr.date_result_reported AS DATE) > CURRENT_DATE AND lr.result_reported IS NOT NULL) THEN NULL ELSE lr.result_reported END  as tbDiagnosticResult,
	CASE WHEN CAST(lr.date_result_reported AS DATE) > CURRENT_DATE THEN NULL ELSE CAST(lr.date_result_reported AS DATE) END  as dateofTbDiagnosticResultReceived,cast(sm.date_sample_collected as date) AS dateOfTbSampleCollected,
	lt.lab_test_id, sm.date_sample_collected, ROW_NUMBER() OVER (PARTITION BY  sm.patient_uuid ORDER BY sm.date_sample_collected DESC) AS rnkkk
	FROM laboratory_sample sm
	 INNER JOIN laboratory_test lt on lt.id = sm.test_id
	 LEFT JOIN laboratory_result lr ON lt.id = lr.test_id
	 WHERE lt.lab_test_id IN (65, 51, 64, 67, 72, 71, 86, 58, 73, 66) and sm.archived = 0 AND sm.date_sample_collected IS NOT NULL
	  AND sm.facility_id = 1624
	) AS tbSubQ where rnkkk = 1
	GROUP BY tbSubQ.personTbResult, tbSubQ.dateofTbDiagnosticResultReceived, tbSubQ.dateOfTbSampleCollected, tbDiagnosticResult)
	SELECT * FROM tb_test),
	tbTreatment AS (
	SELECT * FROM (SELECT
	 COALESCE(NULLIF(CAST(data->'tbIptScreening'->>'treatementType' AS text), ''), '') as tbTreatementType,
	 NULLIF(CAST(NULLIF(data->'tbIptScreening'->>'tbTreatmentStartDate', '') AS DATE), NULL) as tbTreatmentStartDate,
	 CAST(data->'tbIptScreening'->>'treatmentOutcome' AS text) as tbTreatmentOutcome,
	 NULLIF(CAST(NULLIF(data->'tbIptScreening'->>'completionDate', '') AS DATE), NULL) as tbCompletionDate,
	 person_uuid as tbTreatmentPersonUuid,
	 ROW_NUMBER() OVER ( PARTITION BY person_uuid ORDER BY date_of_observation DESC)
	FROM public.hiv_observation WHERE type = 'Chronic Care' AND date_of_observation BETWEEN '1901-01-01' AND CURRENT_DATE
	AND facility_id = 1624 and archived = 0
	) tbTreatment WHERE row_number = 1
	AND tbTreatmentStartDate IS NOT NULL),
	tbTreatmentNew AS (
	WITH tb_start AS (
	SELECT * FROM (
	SELECT
	 person_uuid AS person_uuid,
	date_of_observation as screeningDate,
	 NULLIF(CAST(NULLIF(data->'tptMonitoring'->>'tbTreatmentStartDate' , '') AS DATE), NULL) AS tbTreatmentStartDate,
	 data->'tbIptScreening'->>'tbTestResult' AS tbDiagnosticResult,
	data->'tbIptScreening'->>'chestXrayResult' as chestXrayResult,
	 data->'tbIptScreening'->>'diagnosticTestType' AS tbDiagnosticTestType,
	COALESCE(NULLIF(data->'tptMonitoring'->>'tbType',''), NULLIF(data->'tbIptScreening'->>'tbType','')) AS tbTreatmentType,
	NULLIF(CAST(NULLIF(data->'tbIptScreening'->>'dateSpecimenSent', '') AS DATE), NULL) AS specimenSentDate,
	data->'tbIptScreening'->>'status' as screeningStatus,
	data->'tbIptScreening'->>'dateOfDiagnosticTest' as dateOfDiagnosticTest,
	data->'tbIptScreening'->>'tbScreeningType' AS tbScreeningType, CAST(NULLIF(data->'tbIptScreening'->>'cadScore', '') AS INTEGER) AS cadScore,
	data->'tptMonitoring'->>'clinicallyEvaulated' AS clinicallyEvaulated,
	data->'tbIptScreening'->>'chestXrayDone' AS chestXrayDone,
	data->'tbIptScreening'->>'chestXrayResultTest' AS chestXrayResultTest,
	data->'tbIptScreening'->>'dateOfChestXrayResultTestDone' AS dateOfChestXrayResultTestDone,
	ROW_NUMBER() OVER (PARTITION BY person_uuid ORDER BY date_of_observation DESC) as rnk3
	FROM
	 hiv_observation
	WHERE archived = 0 AND date_of_observation BETWEEN '1901-01-01' AND CURRENT_DATE AND
	 (
	(data->'tbIptScreening'->>'status' LIKE '%Presumptive TB'
	 or data->'tbIptScreening'->>'status' = 'No signs or symptoms of TB'))
	)  subTc WHERE rnk3 = 1 ),
	tb_completion AS (
	SELECT
	 person_uuid AS person_uuid,
	 NULLIF(CAST(NULLIF(data->'tbIptScreening'->>'completionDate', '') AS DATE), NULL)  AS completionDate,
	 data->'tbIptScreening'->>'treatmentOutcome' AS treatmentOutcome
	FROM
	 hiv_observation
	WHERE
	 (data->'tbIptScreening'->>'treatmentOutcome' IS NOT NULL AND data->'tbIptScreening'->>'treatmentOutcome' != '')
	AND archived =0 )
	SELECT
	COALESCE(ts.person_uuid, tc.person_uuid) AS person_uuid_tb,
	ts.tbTreatmentStartDate,
	COALESCE(ts.tbDiagnosticResult,ts.chestXrayResult) as tbDiagnosticResult,
	ts.tbDiagnosticTestType,
	ts.tbScreeningType,
	ts.screeningStatus,
	ts.tbTreatmentType,
	ts.screeningDate,
	ts.specimenSentDate,
	dateOfDiagnosticTest,
	tc.completionDate,
	tc.treatmentOutcome, ts.cadScore, ts.clinicallyEvaulated, ts.chestXrayDone, ts.chestXrayResultTest, ts.dateOfChestXrayResultTestDone
	FROM
	tb_start ts
	FULL OUTER JOIN
	tb_completion tc
	ON
	ts.person_uuid = tc.person_uuid  order by screeningDate desc
	),
	pharmacy_details_regimen AS (
	  select * from (
	select *, ROW_NUMBER() OVER (PARTITION BY pr1.person_uuid40 ORDER BY pr1.lastPickupDate DESC) as rnk3
	from (
	SELECT p.person_uuid as person_uuid40, COALESCE(ds_model.display, p.dsd_model_type) as dsdModel, p.visit_date as lastPickupDate,
	r.description as currentARTRegimen, rt.description as currentRegimenLine,
	p.next_appointment as nextPickupDate,
	CAST(p.refill_period /30.0 AS DECIMAL(10,1)) AS monthsOfARVRefill
	from public.hiv_art_pharmacy p
	  INNER JOIN public.hiv_art_pharmacy_regimens pr
	 ON pr.art_pharmacy_id = p.id
	  INNER JOIN public.hiv_regimen r on r.id = pr.regimens_id
	  INNER JOIN public.hiv_regimen_type rt on rt.id = r.regimen_type_id
	left JOIN base_application_codeset ds_model on ds_model.code = p.dsd_model_type
	WHERE r.regimen_type_id in (1,2,3,4,14, 16)
	  AND  p.archived = 0
	  AND  p.facility_id = 1624
	  AND  p.visit_date >= '1901-01-01'
	  AND  p.visit_date  <= CURRENT_DATE
	 ) as pr1
	) as pr2
	  where pr2.rnk3 = 1
	),
	negativeTbDiagnosticResults AS (
	SELECT sm.patient_uuid as personTbResult, CASE WHEN (CAST(lr.date_result_reported AS DATE) > CURRENT_DATE AND lr.result_reported IS NOT NULL) THEN NULL ELSE lr.result_reported END  as tbDiagnosticResult,
	CASE WHEN CAST(lr.date_result_reported AS DATE) > CURRENT_DATE THEN NULL ELSE CAST(lr.date_result_reported AS DATE) END  as dateofTbDiagnosticResultReceived,cast(sm.date_sample_collected as date) AS dateOfTbSampleCollected,
	lt.lab_test_id, sm.date_sample_collected, ROW_NUMBER() OVER (PARTITION BY  sm.patient_uuid ORDER BY sm.date_sample_collected DESC) AS rnkkk
	FROM laboratory_sample sm
	 INNER JOIN laboratory_test lt on lt.id = sm.test_id
	 LEFT JOIN laboratory_result lr ON lt.id = lr.test_id
	 WHERE lt.lab_test_id IN (86, 65, 67, 64, 58, 51, 73, 72, 71) and sm.archived = 0 AND sm.date_sample_collected IS NOT NULL AND (lr.result_reported ILIKE '%negative%' OR lr.result_reported ILIKE '%MTB not detected%')
	),
	-- Peter Start
	positiveTbDiagnosticResults AS (
		SELECT
			sm.patient_uuid as personTbResult,
			CASE WHEN (
					CAST(lr.date_result_reported AS DATE) > CURRENT_DATE AND lr.result_reported IS NOT NULL
				) THEN NULL
				ELSE lr.result_reported END as tbDiagnosticResult,
			CASE WHEN CAST(lr.date_result_reported AS DATE) > CURRENT_DATE THEN NULL
				ELSE CAST(lr.date_result_reported AS DATE) END as dateofTbDiagnosticResultReceived,
			cast(sm.date_sample_collected as date) AS dateOfTbSampleCollected,
			lt.lab_test_id,
			sm.date_sample_collected,
			ROW_NUMBER() OVER (
				PARTITION BY sm.patient_uuid
				ORDER BY
					sm.date_sample_collected DESC) AS rnkkk
		FROM
			laboratory_sample sm
			INNER JOIN laboratory_test lt on lt.id = sm.test_id
			LEFT JOIN laboratory_result lr ON lt.id = lr.test_id
		WHERE
			lt.lab_test_id IN (86, 65, 67, 64, 58, 51, 73, 72, 71)
			and sm.archived = 0
			AND sm.date_sample_collected IS NOT NULL
			AND (
				lr.result_reported ILIKE '%MTB detected%'
				OR lr.result_reported ILIKE '%MTB trace RIF resistance indeterminate%'
			)
	),
		pharmacy_tpt_data AS (
		SELECT
			person_uuid AS pharm_person_uuid,
			MAX(CASE WHEN h.ipt_type = 'IPT_TYPE_START_INITIATION' THEN visit_date END) AS pharm_tpt_initiation_date,
			MAX(visit_date) AS pharm_tpt_any_refill_date,
			
			MAX(CASE WHEN h.ipt_type = 'IPT_TYPE_START_INITIATION' AND h.ipt ->> 'drugName' = 'Isoniazid-(INH) 300mg' THEN visit_date END) AS pharm_6h_start_date,
			MAX(CASE WHEN h.ipt ->> 'drugName' = 'Isoniazid-(INH) 300mg' THEN visit_date END) AS pharm_6h_any_date,
			
			MAX(CASE WHEN h.ipt_type = 'IPT_TYPE_START_INITIATION' AND h.ipt ->> 'drugName' = 'Isoniazid and Rifapentine-(3HP)' THEN visit_date END) AS pharm_3hp_start_date,
			MAX(CASE WHEN h.ipt ->> 'drugName' = 'Isoniazid and Rifapentine-(3HP)' THEN visit_date END) AS pharm_3hp_any_date,
			
			MAX(CASE WHEN h.ipt_type = 'IPT_TYPE_START_INITIATION' AND h.ipt ->> 'drugName' = 'Isoniazid and Rifampicin-(3HR)' THEN visit_date END) AS pharm_3rh_start_date,
			MAX(CASE WHEN h.ipt ->> 'drugName' = 'Isoniazid and Rifampicin-(3HR)' THEN visit_date END) AS pharm_3rh_any_date
		FROM 
			public.hiv_art_pharmacy h
		WHERE 
			h.archived = 0
			AND h.facility_id = 1624
			AND h.visit_date <= '2026-12-31'
		GROUP BY
			h.person_uuid
	),

	-- Peter End
	eac as (SELECT * FROM (SELECT enrolledEac.facility_id, enrolledEac.person_uuid person_uuid50, enrolledEac.uuid,
	firstEac.sessionDate dateOfCommencementOfEAC,
	(
	CASE WHEN eacSession.status = 'SIXTH EAC' THEN 5
	    WHEN eacSession.status = 'FIFTH EAC' THEN 4
	    WHEN (postEacVl.date_sample_collected IS NOT NULL AND postEacVl.date_sample_collected > thirdEac.sessionDate) OR eacSession.status = 'FOURTH EAC' THEN 3
	    WHEN eacSession.status = 'THIRD EAC' THEN 2
	    WHEN eacSession.status = 'SECOND EAC' THEN 1
	    WHEN eacSession.status = 'FIRST EAC' THEN 0
	END) AS numberOfEACSessionCompleted,
	(CASE WHEN eacSession.status = 'SIXTH EAC' THEN COALESCE(fifthEac.sessionDate, fourthEac.sessionDate, thirdEac.sessionDate, secondEac.sessionDate, firstEac.sessionDate)
	    WHEN eacSession.status = 'FIFTH EAC' THEN COALESCE(fifthEac.sessionDate, fourthEac.sessionDate, thirdEac.sessionDate, secondEac.sessionDate, firstEac.sessionDate)
	    WHEN eacSession.status = 'FOURTH EAC' THEN COALESCE(postEacVl.date_sample_collected, fourthEac.sessionDate, thirdEac.sessionDate, secondEac.sessionDate, firstEac.sessionDate)
	    WHEN eacSession.status = 'THIRD EAC' THEN COALESCE(postEacVl.date_sample_collected, thirdEac.sessionDate, secondEac.sessionDate, firstEac.sessionDate)
	    WHEN eacSession.status = 'SECOND EAC' THEN  COALESCE(secondEac.sessionDate,firstEac.sessionDate)
	    WHEN eacSession.status = 'FIRST EAC' THEN NULL END) AS dateOfLastEACSessionCompleted,
	COALESCE (fifthEac.sessionDate,sixthEac.sessionDate) dateOfExtendEACCompletion,
	(CASE WHEN postEacVl.date_sample_collected >= thirdEac.sessionDate  THEN postEacVl.date_sample_collected END) dateOfRepeatViralLoadEACSampleCollection, (CASE WHEN postEacVl.date_sample_collected >= thirdEac.sessionDate THEN postEacVl.result_reported END) repeatViralLoadResult,
	(CASE WHEN postEacVl.date_sample_collected >= thirdEac.sessionDate THEN postEacVl.date_result_reported END) dateOfRepeatViralLoadResult, eacSession.status, eacSession.eac_session_date,
	ROW_NUMBER () OVER (PARTITION BY enrolledEac.person_uuid ORDER BY firstEac.sessionDate DESC) as rowkk
	FROM
	hiv_eac enrolledEac
	INNER JOIN (
	SELECT person_uuid, eac_id, eac_session_date, status, ROW_NUMBER() OVER (PARTITION BY person_uuid ORDER BY eac_session_date DESC, eac_id) eacRank,
	COUNT(*) OVER (PARTITION BY eac_id, person_uuid) AS eacCount
	FROM hiv_eac_session
	WHERE archived = 0 AND eac_session_date BETWEEN '1901-01-01' AND CURRENT_DATE
	) eacSession ON eacSession.eac_id = enrolledEac.uuid AND eacSession.eacRank = 1
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'FIRST EAC'
	) firstEac ON firstEac.eac_id = eacSession.eac_id
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'SECOND EAC'
	) secondEac ON secondEac.eac_id = eacSession.eac_id
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'THIRD EAC'
	) thirdEac ON thirdEac.eac_id = eacSession.eac_id
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'FOURTH EAC'
	) fourthEac ON fourthEac.eac_id = eacSession.eac_id
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'FIFTH EAC'
	) fifthEac ON fifthEac.eac_id = eacSession.eac_id
	LEFT JOIN (
	SELECT person_uuid, eac_id, eac_session_date sessionDate, status FROM hiv_eac_session WHERE archived = 0 AND status = 'SIXTH EAC'
	) sixthEac ON sixthEac.eac_id = eacSession.eac_id
	LEFT JOIN (select * from(
	SELECT CAST(ls.date_sample_collected AS DATE ) AS date_sample_collected, ls.patient_uuid as patient_uuid , ls.facility_id as vlFacility, ls.archived as vlArchived, acode.display as viralLoadIndication,
	sm.result_reported as result_reported, CAST(sm.date_result_reported AS DATE) as date_result_reported,
	ROW_NUMBER () OVER (PARTITION BY ls.patient_uuid ORDER BY ls.date_sample_collected DESC) as row
	FROM public.laboratory_sample  ls
	INNER JOIN public.laboratory_test  lt on ls.test_id = lt.id AND lt.archived = 0
	INNER JOIN public.base_application_codeset  acode on acode.id =  lt.viral_load_indication
	LEFT JOIN public.laboratory_result sm ON sm.test_id = ls.test_id AND sm.archived = 0
	WHERE  lt.lab_test_id = 16 AND ls.archived = 0 AND CAST(ls.date_sample_collected AS DATE) BETWEEN '1901-01-01' AND CURRENT_DATE
	AND  lt.viral_load_indication IN (302, 305, 304) AND (sm.date_result_reported IS NULL OR CAST(sm.date_result_reported AS DATE) <= CURRENT_DATE)
	) pe where row = 1
	) postEacVl ON postEacVl.patient_uuid = enrolledEac.person_uuid
	WHERE archived = 0 AND facility_id = 1624)finalEAC WHERE rowkk = 1),
	dsd1 as (
	select person_uuid as person_uuid_dsd_1, dateOfDevolvement, modelDevolvedTo
	from (select d.person_uuid, d.date_devolved as dateOfDevolvement, bmt.display as modelDevolvedTo,
	ROW_NUMBER() OVER (PARTITION BY d.person_uuid ORDER BY d.date_devolved ASC ) AS row from dsd_devolvement d
	left join base_application_codeset bmt on bmt.code = d.dsd_type
	where d.archived = 0 and d.date_devolved between  '1901-01-01' and CURRENT_DATE) d1 where row = 1),
	dsd2 as (
	select d2.person_uuid as person_uuid_dsd_2, d2.dateOfCurrentDSD, d2.currentDSDModel, d2.dateReturnToSite, bac.display as currentDsdOutlet, dsdOutlet
	from (select d.person_uuid, d.date_devolved as dateOfCurrentDSD, bmt.display as currentDSDModel, d.date_return_to_site AS dateReturnToSite, outlet_name as dsdOutlet,
	 ROW_NUMBER() OVER (PARTITION BY d.person_uuid ORDER BY d.date_devolved DESC ) AS row from dsd_devolvement d
	left join base_application_codeset bmt on bmt.code = d.dsd_type
	where d.archived = 0 and d.date_devolved between '1901-01-01' and CURRENT_DATE) d2
	left join base_application_codeset bac on bac.code = d2.dsdOutlet where d2.row = 1),
	biometric AS (
	SELECT
	DISTINCT ON (he.person_uuid) he.person_uuid AS person_uuid60,
	biometric_count.enrollment_date AS dateBiometricsEnrolled,
	biometric_count.count AS numberOfFingersCaptured,
	recapture_count.recapture_date AS dateBiometricsRecaptured,
	recapture_count.count AS numberOfFingersRecaptured,
	bst.biometric_status AS biometricStatus,
	bst.status_date
	FROM
	hiv_enrollment_commencement he
	LEFT JOIN (SELECT  b.person_uuid, CASE WHEN COUNT(b.person_uuid) > 10 THEN 10 ELSE COUNT(b.person_uuid) END,
	MAX(enrollment_date) enrollment_date
	  FROM
	biometric b
	  WHERE archived = 0 AND (recapture = 0 or recapture is null)
	  GROUP BY b.person_uuid
	) biometric_count ON biometric_count.person_uuid = he.person_uuid
	LEFT JOIN (
	SELECT b.person_uuid, max_capture.max_capture_date AS recapture_date, b.recapture,
	 CASE WHEN COUNT(b.person_uuid) > 10 THEN 10 ELSE COUNT(b.person_uuid) END
	FROM biometric b
	LEFT JOIN (select person_uuid,max(enrollment_date) max_capture_date from biometric group by person_uuid) max_capture
	ON b.person_uuid=max_capture.person_uuid
	where b.enrollment_date=max_capture.max_capture_date AND b.archived=0 AND b.recapture !=0 and b.recapture is NOT null
	group by 1,2,3
	order by b.person_uuid
	) recapture_count ON recapture_count.person_uuid = he.person_uuid
	LEFT JOIN (
	SELECT DISTINCT ON (person_id) person_id, biometric_status,
	MAX(status_date) OVER (PARTITION BY person_id ORDER BY status_date DESC) AS status_date
	FROM hiv_status_tracker
	WHERE archived=0 AND facility_id=1624
	) bst ON bst.person_id = he.person_uuid
	WHERE he.archived = 0),
	current_regimen AS (SELECT DISTINCT ON (regiment_table.person_uuid) regiment_table.person_uuid AS person_uuid70,
	 start_or_regimen AS dateOfCurrentRegimen,
	 regiment_table.max_visit_date,
	 regiment_table.regimen
	  FROM
	 (SELECT MIN(visit_date) start_or_regimen, MAX(visit_date) max_visit_date, regimen, person_uuid
	 FROM
	  ( SELECT hap.id, hap.person_uuid, hap.visit_date, hivreg.description AS regimen, ROW_NUMBER() OVER(ORDER BY person_uuid, visit_date) rn1,
	ROW_NUMBER() OVER(PARTITION BY hivreg.description ORDER BY person_uuid, visit_date) rn2
	 FROM
	public.hiv_art_pharmacy AS hap
	  INNER JOIN (SELECT
	 MAX(hapr.id) AS id,
	 art_pharmacy_id,
	 regimens_id,
	 hr.description
	  FROM
	 public.hiv_art_pharmacy_regimens AS hapr
	INNER JOIN hiv_regimen AS hr ON hapr.regimens_id = hr.id
	  WHERE
	hr.regimen_type_id IN (1,2,3,4,14, 16)
	  GROUP BY
	 art_pharmacy_id, regimens_id, hr.description ) AS hapr ON hap.id = hapr.art_pharmacy_id and hap.archived=0
	  INNER JOIN hiv_regimen AS hivreg ON hapr.regimens_id = hivreg.id
	  INNER JOIN hiv_regimen_type AS hivregtype ON hivreg.regimen_type_id = hivregtype.id
	  AND hivreg.regimen_type_id IN (1,2,3,4,14,16) AND hap.visit_date BETWEEN '1901-01-01' AND CURRENT_DATE
	 ORDER BY person_uuid, visit_date) t
	GROUP BY person_uuid, regimen, rn1 - rn2 ORDER BY
	  MIN(visit_date)
	 ) AS regiment_table
	INNER JOIN (
	SELECT
	  DISTINCT MAX(visit_date) AS max_visit_date,
	 person_uuid
	FROM hiv_art_pharmacy hap
	INNER JOIN hiv_art_pharmacy_regimens hapr ON hapr.art_pharmacy_id = hap.id
	INNER JOIN hiv_regimen AS hr ON hapr.regimens_id = hr.id
	WHERE hr.regimen_type_id IN (1,2,3,4,14, 16) AND hap.archived = 0 AND hap.visit_date BETWEEN '1901-01-01' AND CURRENT_DATE
	GROUP BY
	  person_uuid
	 ) AS hap ON regiment_table.person_uuid = hap.person_uuid
	  WHERE
	regiment_table.max_visit_date = hap.max_visit_date
	  GROUP BY
	 regiment_table.person_uuid,
	 regiment_table.regimen,
	 regiment_table.max_visit_date,
	 start_or_regimen),
	iptNew AS (WITH tpt_completed AS (
	SELECT * FROM (
	SELECT person_uuid AS person_uuid, data->'tptMonitoring'->>'endedTpt' AS endedTpt, NULLIF(CAST(NULLIF(data->'tptMonitoring'->>'dateTptEnded', '') AS DATE), NULL) AS tptCompletionDate,
	 data->'tptMonitoring'->>'outComeOfIpt' AS tptCompletionStatus, data->'tbIptScreening'->>'outcome' AS completion_tptPreventionOutcome,
	 ROW_NUMBER () OVER (PARTITION BY person_uuid ORDER BY date_of_observation  DESC) rowNum
	FROM hiv_observation
	WHERE data->'tptMonitoring'->>'endedTpt' = 'Yes' AND data->'tbIptScreening'->>'outcome' IS NOT NULL AND data->'tbIptScreening'->>'outcome' != '' AND data->'tptMonitoring'->>'outComeOfIpt' IS NOT NULL AND data->'tptMonitoring'->>'outComeOfIpt' !=''
	 AND archived = 0 ) subTc WHERE rowNum = 1
	),
	pt_screened AS (SELECT person_uuid AS person_uuid, data->'tptMonitoring'->>'tptRegimen' AS tptType, NULLIF(CAST(NULLIF(data->'tptMonitoring'->>'dateTptStarted', '') AS DATE), NULL) AS tptStartDate,
	 data->'tptMonitoring'->>'eligibilityTpt' AS eligibilityTpt
	FROM hiv_observation
	WHERE (data->'tptMonitoring'->>'eligibilityTpt' IS NOT NULL AND  data->'tptMonitoring'->>'eligibilityTpt' != '')
	 AND (data->'tbIptScreening'->>'outcome' != 'Currently on TPT') )
	SELECT COALESCE(tc.person_uuid, ts.person_uuid) AS person_uuid, ts.tptType, ts.tptStartDate, ts.eligibilityTpt, tc.endedTpt, tc.tptCompletionDate, tc.tptCompletionStatus
	FROM
	pt_screened ts
	FULL OUTER JOIN
	tpt_completed tc
	ON
	ts.person_uuid = tc.person_uuid),
	ipt as (
	with ipt_c as ( select person_uuid, date_completed as iptCompletionDate, iptCompletionStatus from (
	select person_uuid, cast(ipt->>'dateCompleted' as date) as date_completed,
	COALESCE(NULLIF(CAST(ipt->>'completionStatus' AS text), ''), '') AS iptCompletionStatus,
	row_number () over (partition by person_uuid order by cast(ipt->>'dateCompleted' as date) desc) as rnk
	from hiv_art_pharmacy where (ipt->>'dateCompleted' is not null and ipt->>'dateCompleted' != 'null' and ipt->>'dateCompleted' != '' AND TRIM(ipt->>'dateCompleted') <> '')
	and archived = 0 AND ipt->>'completionStatus' != '' AND ipt->>'completionStatus' != 'null' AND ipt->>'completionStatus' <> '') ic where ic.rnk = 1),
	ipt_s as (SELECT person_uuid, visit_date as dateOfIptStart, regimen_name as iptType
	FROM (SELECT h.person_uuid, h.visit_date, CAST(pharmacy_object ->> 'regimenName' AS VARCHAR) AS regimen_name,
	ROW_NUMBER() OVER (PARTITION BY h.person_uuid ORDER BY h.visit_date ASC) AS rnk
	FROM hiv_art_pharmacy h
	INNER JOIN jsonb_array_elements(h.extra -> 'regimens') WITH ORDINALITY p(pharmacy_object) ON TRUE
	INNER JOIN hiv_regimen hr ON hr.description = CAST(p.pharmacy_object ->> 'regimenName' AS VARCHAR)
	INNER JOIN hiv_regimen_type hrt ON hrt.id = hr.regimen_type_id  AND hrt.id IN (15, 9) AND hrt.id NOT IN (1,2,3,4,14, 16)
	WHERE hrt.id IN (15, 9) AND h.archived = 0 AND hr.description ILIKE '%Isoniazid%'
	) AS ic WHERE ic.rnk = 1 ),
	ipt_c_cs as (
	SELECT person_uuid, iptStartDate, iptCompletionSCS, iptCompletionDSC
	FROM ( SELECT person_uuid,  CASE WHEN (data->'tbIptScreening'->>'dateTPTStart') IS NULL OR (data->'tbIptScreening'->>'dateTPTStart') = ''
	OR (data->'tbIptScreening'->>'dateTPTStart') = ' '  THEN NULL ELSE CAST((data->'tbIptScreening'->>'dateTPTStart') AS DATE) END as iptStartDate,
	data->'tptMonitoring'->>'outComeOfIpt' as iptCompletionSCS,
	CASE WHEN (data->'tptMonitoring'->>'date') = 'null' OR (data->'tptMonitoring'->>'date') = '' OR (data->'tptMonitoring'->>'date') = ' '  THEN NULL
	 ELSE cast(data->'tptMonitoring'->>'date' as date)  END as iptCompletionDSC, ROW_NUMBER() OVER (PARTITION BY person_uuid ORDER BY
	 CASE WHEN (data->'tptMonitoring'->>'date') = 'null' OR (data->'tptMonitoring'->>'date') = '' OR (data->'tptMonitoring'->>'date') = ' '  THEN NULL ELSE cast(data->'tptMonitoring'->>'date' as date) END  DESC) AS ipt_c_sc_rnk
	FROM hiv_observation
	WHERE type = 'Chronic Care'
	AND archived = 0
	AND (data->'tptMonitoring'->>'date') IS NOT NULL
	AND (data->'tptMonitoring'->>'date') != 'null'
	) AS ipt_ccs
	WHERE ipt_c_sc_rnk = 1)
	select ipt_s.person_uuid as personuuid80, (CASE WHEN coalesce(ipt_c_cs.iptCompletionDSC, ipt_c.iptCompletionDate) > CURRENT_DATE THEN NULL ELSE coalesce(ipt_c_cs.iptCompletionDSC, ipt_c.iptCompletionDate) END) as iptCompletionDate,
	(CASE WHEN coalesce(ipt_c_cs.iptCompletionDSC, ipt_c.iptCompletionDate) > CURRENT_DATE THEN NULL ELSE coalesce(ipt_c_cs.iptCompletionSCS, ipt_c.iptCompletionStatus) END) as iptCompletionStatus, COALESCE(ipt_s.dateOfIptStart, ipt_c_cs.iptStartDate) AS dateOfIptStart, ipt_s.iptType
	from ipt_s
	left join ipt_c on ipt_s.person_uuid = ipt_c.person_uuid
	left join ipt_c_cs on ipt_s.person_uuid = ipt_c_cs.person_uuid ),
	ipt_s as ( SELECT person_uuid, visit_date as dateOfIptStart, regimen_name as iptType
	FROM ( SELECT h.person_uuid, h.visit_date, CAST(pharmacy_object ->> 'regimenName' AS VARCHAR) AS regimen_name,
	ROW_NUMBER() OVER (PARTITION BY h.person_uuid ORDER BY h.visit_date ASC) AS rnk
	FROM hiv_art_pharmacy h
	INNER JOIN jsonb_array_elements(h.extra -> 'regimens') WITH ORDINALITY p(pharmacy_object) ON TRUE
	INNER JOIN hiv_regimen hr ON hr.description = CAST(p.pharmacy_object ->> 'regimenName' AS VARCHAR)
	INNER JOIN hiv_regimen_type hrt ON hrt.id = hr.regimen_type_id  AND hrt.id IN (15) AND hrt.id NOT IN (1,2,3,4,14, 16)
	WHERE hrt.id IN (15) AND h.archived = 0 AND hr.description ILIKE '%Isoniazid%'
	) AS ic WHERE ic.rnk = 1 ),
	 cervical_cancer AS (select * from (select  ho.person_uuid AS person_uuid90, ho.date_of_observation AS dateOfCervicalCancerScreening,
	ho.data ->> 'screenTreatmentMethodDate' AS treatmentMethodDate,cc_type.display AS cervicalCancerScreeningType,
	cc_method.display AS cervicalCancerScreeningMethod, cc_trtm.display AS cervicalCancerTreatmentScreened,
	cc_result.display AS resultOfCervicalCancerScreening,
	ROW_NUMBER() OVER (PARTITION BY ho.person_uuid ORDER BY ho.date_of_observation DESC) AS row
	from hiv_observation ho
	LEFT JOIN base_application_codeset cc_type ON cc_type.code = CAST(ho.data ->> 'screenType' AS VARCHAR)
	 LEFT JOIN base_application_codeset cc_method ON cc_method.code = CAST(ho.data ->> 'screenMethod' AS VARCHAR)
	 LEFT JOIN base_application_codeset cc_result ON cc_result.code = CAST(ho.data ->> 'screeningResult' AS VARCHAR)
	 LEFT JOIN base_application_codeset cc_trtm ON cc_trtm.code = CAST(ho.data ->> 'screenTreatment' AS VARCHAR)
	where ho.archived = 0 and type = 'Cervical cancer') as cc where row = 1),
	previous_previous AS (SELECT person_uuid AS prePrePersonUuid,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%' THEN 'Died'
	WHEN( status_date > maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%'))
	 THEN hiv_status
	ELSE status
	END) AS status,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%'  THEN status_date
	WHEN(status_date > maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%')) THEN status_date
	ELSE visit_date
	END
	) AS status_date,
	 cause_of_death, va_cause_of_death
	 FROM (
	SELECT
	  pharmacy.person_uuid,
	  pharmacy.visit_date maxdate,
	  stat.hiv_status,
	  stat.cause_of_death,
	  stat.va_cause_of_death,
	  stat.status_date,
	(CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= '2026-06-30' THEN 'IIT'
	  ELSE 'Active'
	  END
	) status,
	 (CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= '2026-06-30' THEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day'
	  ELSE pharmacy.visit_date
	  END) AS visit_date
	FROM (
	  SELECT ph.person_uuid, ph.visit_date, ph.refill_period,ROW_NUMBER() OVER (PARTITION BY ph.person_uuid ORDER BY ph.visit_date DESC ) AS rn
	  FROM hiv_art_pharmacy ph
	  INNER JOIN hiv_enrollment_commencement h ON h.person_uuid = ph.person_uuid AND h.archived = 0
	  INNER JOIN public.hiv_art_pharmacy_regimens pr ON pr.art_pharmacy_id = ph.id
	  INNER JOIN public.hiv_regimen r ON r.id = pr.regimens_id
	  INNER JOIN public.hiv_regimen_type rt ON rt.id = r.regimen_type_id
	  WHERE r.regimen_type_id IN (1,2,3,4,14,16) AND ph.archived = 0
	    AND ph.visit_date <= '2026-06-30'
	) AS pharmacy
	LEFT JOIN (
	  SELECT
	    status.person_id, status.status_date, status.hiv_status, status.cause_of_death, status.va_cause_of_death
	  FROM (
	    SELECT
	      hst.person_id, hst.status_date, hst.hiv_status, hst.cause_of_death,
	      hst.va_cause_of_death,ROW_NUMBER() OVER (PARTITION BY hst.person_id ORDER BY hst.status_date DESC ) AS rn
	    FROM hiv_status_tracker hst
	    WHERE hst.archived = 0
	      AND hst.status_date <='2026-06-30'
	  ) AS status
	  WHERE status.rn = 1
	) AS stat
	  ON stat.person_id = pharmacy.person_uuid
	WHERE pharmacy.rn = 1) statuss),
	previous AS (SELECT person_uuid AS prePersonUuid,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%' THEN 'Died'
	WHEN( status_date > maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%'))
	 THEN hiv_status
	ELSE status
	END) AS status,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%'  THEN status_date
	WHEN(status_date > maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%')) THEN status_date
	ELSE visit_date
	END
	) AS status_date,
	 cause_of_death, va_cause_of_death
	 FROM (
	SELECT
	  pharmacy.person_uuid,
	  pharmacy.visit_date maxdate,
	  stat.hiv_status,
	  stat.cause_of_death,
	  stat.va_cause_of_death,
	  stat.status_date,
	(CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= '2026-09-30' THEN 'IIT'
	  ELSE 'Active'
	  END
	) status,
	 (CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= '2026-09-30' THEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day'
	  ELSE pharmacy.visit_date
	  END) AS visit_date
	FROM (
	  SELECT ph.person_uuid, ph.visit_date, ph.refill_period,ROW_NUMBER() OVER (PARTITION BY ph.person_uuid ORDER BY ph.visit_date DESC ) AS rn
	  FROM hiv_art_pharmacy ph
	  INNER JOIN hiv_enrollment_commencement h ON h.person_uuid = ph.person_uuid AND h.archived = 0
	  INNER JOIN public.hiv_art_pharmacy_regimens pr ON pr.art_pharmacy_id = ph.id
	  INNER JOIN public.hiv_regimen r ON r.id = pr.regimens_id
	  INNER JOIN public.hiv_regimen_type rt ON rt.id = r.regimen_type_id
	  WHERE r.regimen_type_id IN (1,2,3,4,14,16) AND ph.archived = 0
	    AND ph.visit_date <= '2026-09-30'
	) AS pharmacy
	LEFT JOIN (
	  SELECT
	    status.person_id, status.status_date, status.hiv_status, status.cause_of_death, status.va_cause_of_death
	  FROM (
	    SELECT
	      hst.person_id, hst.status_date, hst.hiv_status, hst.cause_of_death,
	      hst.va_cause_of_death,ROW_NUMBER() OVER (PARTITION BY hst.person_id ORDER BY hst.status_date DESC ) AS rn
	    FROM hiv_status_tracker hst
	    WHERE hst.archived = 0
	      AND hst.status_date <= '2026-09-30'
	  ) AS status
	  WHERE status.rn = 1
	) AS stat
	  ON stat.person_id = pharmacy.person_uuid
	WHERE pharmacy.rn = 1) statuss),
	current_status AS (SELECT person_uuid AS cuPersonUuid,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%' THEN 'Died'
	WHEN( status_date >= maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%'))
	 THEN hiv_status
	ELSE status
	END) AS status,
	 (CASE
	WHEN hiv_status ILIKE '%DEATH%' OR hiv_status ILIKE '%Died%'  THEN status_date
	WHEN(status_date >= maxdate AND (hiv_status ILIKE '%stop%' OR hiv_status ILIKE '%out%' OR hiv_status ILIKE '%Invalid %' OR hiv_status ILIKE '%ART Transfer In%')) THEN status_date
	ELSE visit_date
	END
	) AS status_date,
	 cause_of_death, va_cause_of_death
	 FROM (
	SELECT
	  pharmacy.person_uuid,
	  pharmacy.visit_date maxdate,
	  stat.hiv_status,
	  stat.cause_of_death,
	  stat.va_cause_of_death,
	  stat.status_date,
	(CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= CURRENT_DATE THEN 'IIT'
	  ELSE 'Active'
	  END
	) status,
	 (CASE
	  WHEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day' <= CURRENT_DATE THEN pharmacy.visit_date + pharmacy.refill_period + INTERVAL '29 day'
	  ELSE pharmacy.visit_date
	  END) AS visit_date
	FROM (
	  SELECT ph.person_uuid, ph.visit_date, ph.refill_period,ROW_NUMBER() OVER (PARTITION BY ph.person_uuid ORDER BY ph.visit_date DESC ) AS rn
	  FROM hiv_art_pharmacy ph
	  INNER JOIN hiv_enrollment_commencement h ON h.person_uuid = ph.person_uuid AND h.archived = 0
	  INNER JOIN public.hiv_art_pharmacy_regimens pr ON pr.art_pharmacy_id = ph.id
	  INNER JOIN public.hiv_regimen r ON r.id = pr.regimens_id
	  INNER JOIN public.hiv_regimen_type rt ON rt.id = r.regimen_type_id
	  WHERE r.regimen_type_id IN (1,2,3,4,14,16) AND ph.archived = 0
	    AND ph.visit_date <= CURRENT_DATE
	) AS pharmacy
	LEFT JOIN (
	  SELECT
	    status.person_id, status.status_date, status.hiv_status, status.cause_of_death, status.va_cause_of_death
	  FROM (
	    SELECT
	      hst.person_id, hst.status_date, hst.hiv_status, hst.cause_of_death,
	      hst.va_cause_of_death,ROW_NUMBER() OVER (PARTITION BY hst.person_id ORDER BY hst.status_date DESC ) AS rn
	    FROM hiv_status_tracker hst
	    WHERE hst.archived = 0
	      AND hst.status_date <= CURRENT_DATE
	  ) AS status
	  WHERE status.rn = 1
	) AS stat
	  ON stat.person_id = pharmacy.person_uuid
	WHERE pharmacy.rn = 1) statuss
	),
	naive_vl_data AS (SELECT pp.uuid AS nvl_person_uuid, EXTRACT(YEAR FROM AGE(CURRENT_DATE, pp.date_of_birth) ) as age, ph.visit_date, ph.regimen
	  FROM patient_person pp
	 INNER JOIN (SELECT DISTINCT * FROM (SELECT pharm.*,
	 ROW_NUMBER() OVER (PARTITION BY pharm.person_uuid ORDER BY pharm.visit_date DESC)
	 FROM
	(SELECT DISTINCT * FROM hiv_art_pharmacy hap
	  INNER JOIN hiv_art_pharmacy_regimens hapr
	  INNER JOIN hiv_regimen hr ON hr.id=hapr.regimens_id
	  INNER JOIN hiv_regimen_type hrt ON hrt.id=hr.regimen_type_id
	  INNER JOIN hiv_regimen_resolver hrr ON hrr.regimensys=hr.description
	 ON hapr.art_pharmacy_id=hap.id
	 WHERE hap.archived=0 AND hrt.id IN (1,2,3,4,14, 16) AND hap.facility_id = 1624 ) pharm
	)ph WHERE ph.row_number=1
	  )ph ON ph.person_uuid=pp.uuid
	  WHERE pp.uuid NOT IN (
	 SELECT patient_uuid FROM (
	 SELECT COUNT(ls.patient_uuid), ls.patient_uuid FROM laboratory_sample ls
	  INNER JOIN laboratory_test lt ON lt.id=ls.test_id AND lt.lab_test_id=16
	 WHERE ls.archived=0 AND ls.facility_id=1624
	 GROUP BY ls.patient_uuid)t )
	),
	crytococal_antigen as (
	 select * from
	(select DISTINCT ON (lr.patient_uuid) lr.patient_uuid as personuuid12,
	 CAST(lr.date_result_reported AS DATE) AS dateOfLastCrytococalAntigen,
	 lr.result_reported AS lastCrytococalAntigen ,
	 ROW_NUMBER() OVER (
	PARTITION BY lr.patient_uuid
	ORDER BY
	lr.date_result_reported DESC
	 ) as rowNum
	 from
	 public.laboratory_test lt
	 inner join laboratory_result lr on lr.test_id = lt.id
	 where
	 lab_test_id = 52 OR lab_test_id = 69 OR lab_test_id = 70
	 AND lr.date_result_reported IS NOT NULL
	 AND lr.date_result_reported <= CURRENT_DATE
	 AND lr.date_result_reported >= '1901-01-01'
	 AND lr.result_reported is NOT NULL
	 AND lr.archived = 0
	 AND lr.facility_id = 1624
	) dt
	  where
	rowNum = 1),
	vaCauseOfDeath AS (
	SELECT
	 hst.hiv_status,
	 hst.person_id,
	 hst.cause_of_death,
	 hst.va_cause_of_death,
	 hst.status_date
	  FROM
	 (SELECT * FROM (SELECT DISTINCT (person_id) person_id, status_date, cause_of_death, va_cause_of_death,
	hiv_status, ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY status_date DESC)
	 FROM hiv_status_tracker WHERE hiv_status ilike '%Died%' AND archived=0 AND status_date <= CURRENT_DATE )s
	WHERE s.row_number=1) hst
	INNER JOIN hiv_enrollment_commencement he ON he.person_uuid = hst.person_id
	  WHERE hst.status_date <= CURRENT_DATE
	),
	case_manager AS (
	 SELECT DISTINCT ON (cmp.person_uuid)person_uuid AS caseperson, cmp.case_manager_id, CONCAT(cm.first_name, ' ', cm.last_name) AS caseManager FROM (SELECT person_uuid, case_manager_id,
	 ROW_NUMBER () OVER (PARTITION BY person_uuid ORDER BY id DESC)
	 FROM case_manager_patients) cmp  INNER JOIN case_manager cm ON cm.id=cmp.case_manager_id
	 WHERE cmp.row_number=1 AND cm.facility_id=1624),
	client_verification AS (
	 SELECT * FROM (select person_uuid, data->'attempt'->0->>'outcome' AS clientVerificationOutCome,
	data->'attempt'->0->>'verificationStatus' AS clientVerificationStatus,
	CAST (data->'attempt'->0->>'dateOfAttempt' AS DATE) AS dateOfOutcome,
	ROW_NUMBER() OVER ( PARTITION BY person_uuid ORDER BY CAST(data->'attempt'->0->>'dateOfAttempt' AS DATE) DESC)
	from public.hiv_observation where type = 'Client Verification'
	AND archived = 0 AND CAST(data->'attempt'->0->>'dateOfAttempt' AS DATE) <= CURRENT_DATE AND CAST(data->'attempt'->0->>'dateOfAttempt' AS DATE) >= '1901-01-01' AND facility_id = 1624
	) clientVerification WHERE row_number = 1 AND dateOfOutcome IS NOT NULL )
	SELECT DISTINCT ON (bd.personUuid) personUuid AS uniquePersonUuid,
	bd.*,
	CONCAT(bd.datimId, '_', bd.personUuid) AS ndrPatientIdentifier,
	p_lga.*,
	enroll.*,
	scd.*,
	cvlr.*,
	pdr.*,
	b.*,
	c.*,
	e.*,
	ca.dateOfCurrentRegimen,
	ca.person_uuid70,
	COALESCE(enroll.tpt_start_date, iptStart.dateOfIptStart) AS dateOfIptStart,
	COALESCE(enroll.tpt_completion_date, CAST(iptN.tptCompletionDate AS DATE), ipt.iptCompletionDate) AS iptCompletionDate,
	(CASE WHEN COALESCE(iptN.tptCompletionStatus, ipt.iptCompletionStatus) = 'IPT Completed' THEN 'Treatment completed' ELSE COALESCE(iptN.tptCompletionStatus, ipt.iptCompletionStatus) END) AS iptCompletionStatus,
	COALESCE(enroll.tpt_medication, iptStart.iptType) AS iptType, iptN.eligibilityTpt,
	cc.*,
	COALESCE(c.date_devolved, dsd1.dateOfDevolvement) dateOfDevolvement, COALESCE(c.dsd_status, dsd1.modelDevolvedTo) modelDevolvedTo,  dsd2.dateOfCurrentDSD, COALESCE(c.dsd_model, dsd2.currentDSDModel) currentDSDModel, dsd2.dateReturnToSite, dsd2.currentDsdOutlet, dsd2.dsdOutlet,  
	(CASE WHEN COALESCE(tbTmentNew.tbTreatmentType, tbTment.tbTreatementType) IN ('New', 'Relapse', 'Relapsed') THEN 'New/Relapse' ELSE COALESCE(tbTmentNew.tbTreatmentType, tbTment.tbTreatementType) END)  AS tbTreatementType, tbTmentNew.cadScore,
	COALESCE(tbTmentNew.tbTreatmentStartDate, tbTment.tbTreatmentStartDate) AS tbTreatmentStartDate,
	COALESCE(tbTmentNew.treatmentOutcome, tbTment.tbTreatmentOutcome) AS tbTreatmentOutcome,
	COALESCE(tbTmentNew.completionDate, tbTment.tbCompletionDate) AS tbCompletionDate,
	COALESCE(tbTmentNew.person_uuid_tb, tbTment.tbTreatmentPersonUuid) AS tbTreatmentPersonUuid,
	(CASE WHEN (tbTmentNew.clinicallyEvaulated = 'Yes' AND tbTmentNew.tbScreeningType ILIKE '%Chest X-Ray with CAD and/or Symptom screening%' AND tbTmentNew.chestXrayDone = 'Yes' AND negativeTb.tbDiagnosticResult IS NOT NULL AND tbTmentNew.cadScore >= 40) THEN CAST(tbTmentNew.dateOfChestXrayResultTestDone AS DATE) ELSE NULL END)  AS dateTbScoreCad, (CASE WHEN (tbTmentNew.clinicallyEvaulated = 'Yes' AND tbTmentNew.tbScreeningType ILIKE '%Chest X-Ray with CAD and/or Symptom screening%' AND tbTmentNew.chestXrayDone = 'Yes' AND tbTmentNew.cadScore >= 40 AND negativeTb.tbDiagnosticResult IS NOT NULL) THEN tbTmentNew.chestXrayResultTest ELSE NULL END) AS resultTbScoreCad,
	tbSample.*,
	tbResult.*,
	tbS.*,
	tbl.*,
	crypt.*,
	COALESCE (vaod.cause_of_death, ct.cause_of_death) AS causeOfDeath,
	COALESCE (vaod.va_cause_of_death, ct.va_cause_of_death) AS vaCauseOfDeath,
	(CASE WHEN prepre.status ILIKE '%DEATH%' THEN 'Died'
	WHEN prepre.status ILIKE '%out%' THEN 'Transferred Out'
	WHEN pre.status ILIKE '%DEATH%' THEN 'Died'
	WHEN pre.status ILIKE '%out%' THEN 'Transferred Out'
	WHEN (prepre.status ILIKE '%IIT%' OR prepre.status ILIKE '%stop%') AND (pre.status ILIKE '%ACTIVE%') THEN 'Active Restart'
	WHEN prepre.status ILIKE '%ACTIVE%' AND pre.status ILIKE '%ACTIVE%' THEN 'Active' ELSE REPLACE(pre.status, '_', ' ') END ) AS previousStatus,
	CAST((CASE WHEN prepre.status ILIKE '%DEATH%' THEN prepre.status_date
	WHEN prepre.status ILIKE '%out%' THEN prepre.status_date
	WHEN pre.status ILIKE '%DEATH%' THEN pre.status_date
	WHEN pre.status ILIKE '%out%' THEN pre.status_date
	WHEN (prepre.status ILIKE '%IIT%' OR prepre.status ILIKE '%stop%' ) AND (pre.status ILIKE '%ACTIVE%') THEN pre.status_date WHEN prepre.status ILIKE '%ACTIVE%' AND pre.status ILIKE '%ACTIVE%' THEN pre.status_date ELSE pre.status_date
	END ) AS DATE)AS previousStatusDate,
	(CASE WHEN ((pre.status ILIKE '%IIT%' OR pre.status ILIKE '%stop%') AND (ct.status ILIKE '%ACTIVE%')) THEN 'Active Restart'
	WHEN ct.status ILIKE '%ACTIVE%' THEN 'Active'
	WHEN ct.status ILIKE '%ART Transfer In%' THEN ''
	WHEN prepre.status ILIKE '%DEATH%' THEN 'Died'
	WHEN prepre.status ILIKE '%out%' THEN 'Transferred Out'
	WHEN pre.status ILIKE '%DEATH%' THEN 'Died'
	WHEN pre.status ILIKE '%out%' THEN 'Transferred Out'
	WHEN ct.status ILIKE '%IIT%' THEN 'IIT'
	WHEN ct.status ILIKE '%out%' THEN 'Transferred Out'
	WHEN ct.status ILIKE '%DEATH%' THEN 'Died'
	WHEN pre.status ILIKE '%ACTIVE%' AND ct.status ILIKE '%ACTIVE%' THEN 'Active'
	ELSE REPLACE(ct.status, '_', ' ') END ) AS currentStatus,
	CAST((CASE WHEN ct.status ILIKE '%ACTIVE%' THEN ct.status_date
	WHEN ct.status ILIKE '%ART Transfer In%' THEN ct.status_date
	WHEN prepre.status ILIKE '%DEATH%' THEN prepre.status_date
	WHEN prepre.status ILIKE '%out%' THEN prepre.status_date
	WHEN pre.status ILIKE '%DEATH%' THEN pre.status_date
	WHEN pre.status ILIKE '%out%' THEN pre.status_date
	WHEN ct.status ILIKE '%IIT%' THEN
	CASE WHEN (pre.status ILIKE '%DEATH%' OR pre.status ILIKE '%out%' OR pre.status ILIKE '%stop%') THEN pre.status_date ELSE ct.status_date END
	WHEN ct.status ILIKE '%stop%' THEN
	CASE
	WHEN (pre.status ILIKE '%DEATH%' OR pre.status ILIKE '%out%' OR pre.status ILIKE '%IIT%') THEN ct.status_date ELSE pre.status_date END
	WHEN ct.status ILIKE '%out%' THEN
	CASE WHEN (pre.status ILIKE '%DEATH%' OR pre.status ILIKE '%stop%' OR pre.status ILIKE '%IIT%') THEN pre.status_date
	ELSE ct.status_date END
	WHEN (pre.status ILIKE '%IIT%' OR pre.status ILIKE '%stop%') AND (ct.status ILIKE '%ACTIVE%') THEN ct.status_date
	WHEN pre.status ILIKE '%ACTIVE%' AND ct.status ILIKE '%ACTIVE%' THEN ct.status_date ELSE ct.status_date END )AS DATE) AS currentStatusDate,
	cvl.clientVerificationStatus, cvl.clientVerificationOutCome,
	(CASE WHEN prepre.status ILIKE '%DEATH%' THEN FALSE
	WHEN prepre.status ILIKE '%out%' THEN FALSE
	WHEN pre.status ILIKE '%DEATH%' THEN FALSE
	WHEN pre.status ILIKE '%out%' THEN FALSE
	WHEN ct.status ILIKE '%IIT%' THEN FALSE
	WHEN ct.status ILIKE '%out%' THEN FALSE
	WHEN ct.status ILIKE '%DEATH%' THEN FALSE
	WHEN ct.status ILIKE '%stop%' THEN FALSE
	WHEN (nvd.age >= 15 AND nvd.regimen ILIKE '%DTG%'
	AND enroll.artstartdate + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%') THEN TRUE
	WHEN (nvd.age >= 15 AND nvd.regimen NOT ILIKE '%DTG%'
	AND enroll.artstartdate + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%') THEN TRUE
	WHEN (nvd.age <= 15 AND enroll.artstartdate + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%') THEN TRUE
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) IS NULL
	AND scd.dateofviralloadsamplecollection IS NULL AND
	cvlr.dateofcurrentviralload IS NULL
	AND CAST(enroll.artstartdate AS DATE) + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) IS NULL
	AND scd.dateofviralloadsamplecollection IS NOT NULL AND
	cvlr.dateofcurrentviralload IS NULL
	AND CAST(enroll.artstartdate AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) < 1000
	AND( scd.dateofviralloadsamplecollection < cvlr.dateofcurrentviralload
	OR  scd.dateofviralloadsamplecollection IS NULL )
	AND CAST(cvlr.dateofcurrentviralload AS DATE) + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	WHEN  CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) < 1000
	AND (scd.dateofviralloadsamplecollection > cvlr.dateofcurrentviralload
	OR cvlr.dateofcurrentviralload IS NULL )
	AND CAST(scd.dateofviralloadsamplecollection AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) > 1000
	AND ( scd.dateofviralloadsamplecollection < cvlr.dateofcurrentviralload OR scd.dateofviralloadsamplecollection IS NULL)
	AND CAST(cvlr.dateofcurrentviralload AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) > 1000 AND (scd.dateofviralloadsamplecollection > cvlr.dateofcurrentviralload OR cvlr.dateofcurrentviralload IS NULL)
	AND CAST(scd.dateofviralloadsamplecollection AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN TRUE
	ELSE FALSE END ) AS vlEligibilityStatus,
	CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) AS test,
	(CASE WHEN prepre.status ILIKE '%DEATH%' THEN NULL
	WHEN prepre.status ILIKE '%out%' THEN NULL
	WHEN pre.status ILIKE '%DEATH%' THEN NULL
	WHEN pre.status ILIKE '%out%' THEN NULL
	WHEN ct.status ILIKE '%IIT%' THEN NULL
	WHEN ct.status ILIKE '%out%' THEN NULL
	WHEN ct.status ILIKE '%DEATH%' THEN NULL
	WHEN ct.status ILIKE '%stop%' THEN NULL
	WHEN (nvd.age >= 15
	AND nvd.regimen ILIKE '%DTG%'
	AND enroll.artstartdate + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%')
	THEN CAST(enroll.artstartdate + 91 AS DATE)
	WHEN (nvd.age >= 15
	AND nvd.regimen NOT ILIKE '%DTG%'
	AND enroll.artstartdate + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%')
	THEN CAST(enroll.artstartdate + 181 AS DATE)
	WHEN (nvd.age <= 15 AND enroll.artstartdate + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%')
	THEN CAST(enroll.artstartdate + 181 AS DATE)
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) IS NULL
	AND scd.dateofviralloadsamplecollection IS NULL AND
	cvlr.dateofcurrentviralload IS NULL
	AND CAST(enroll.artstartdate AS DATE) + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN
	CAST(enroll.artstartdate AS DATE) + 181
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) IS NULL
	AND scd.dateofviralloadsamplecollection IS NOT NULL AND
	cvlr.dateofcurrentviralload IS NULL
	AND CAST(enroll.artstartdate AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN
	CAST(enroll.artstartdate AS DATE) + 91
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) < 1000
	AND( scd.dateofviralloadsamplecollection < cvlr.dateofcurrentviralload
	OR  scd.dateofviralloadsamplecollection IS NULL )
	AND CAST(cvlr.dateofcurrentviralload AS DATE) + 181 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%'
	THEN CAST(cvlr.dateofcurrentviralload AS DATE) + 181
	WHEN  CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) < 1000
	AND (scd.dateofviralloadsamplecollection > cvlr.dateofcurrentviralload
	OR cvlr.dateofcurrentviralload IS NULL)
	AND CAST(scd.dateofviralloadsamplecollection AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN
	CAST(scd.dateofviralloadsamplecollection AS DATE) + 91
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) > 1000
	AND ( scd.dateofviralloadsamplecollection < cvlr.dateofcurrentviralload OR scd.dateofviralloadsamplecollection IS NULL)
	AND CAST(cvlr.dateofcurrentviralload AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN
	CAST(cvlr.dateofcurrentviralload AS DATE) + 91
	WHEN CAST(NULLIF(REGEXP_REPLACE(cvlr.currentviralload, '[^0-9]', '', 'g'), '') AS INTEGER) > 1000 AND (scd.dateofviralloadsamplecollection > cvlr.dateofcurrentviralload OR cvlr.dateofcurrentviralload IS NULL)
	AND CAST(scd.dateofviralloadsamplecollection AS DATE) + 91 < CURRENT_DATE AND ct.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' AND prepre.status ILIKE '%ACTIVE%' THEN
	CAST(scd.dateofviralloadsamplecollection AS DATE) + 91 ELSE NULL END) AS dateOfVlEligibilityStatus,
	(CASE WHEN cd.cd4lb IS NOT NULL THEN  cd.cd4lb
	WHEN  enroll.cd_4 IS NOT NULL THEN CAST(enroll.cd_4 as VARCHAR)
	ELSE NULL END) as lastCd4Count,
	(CASE WHEN cd.dateOfCd4Lb IS NOT NULL AND cd.cd4lb IS NOT NULL THEN  CAST(cd.dateOfCd4Lb as DATE)
	WHEN enroll.artStartDate IS NOT NULL AND enroll.cd_4 IS NOT NULL THEN CAST(enroll.artStartDate as DATE)
	ELSE NULL END) as dateOfLastCd4Count,
	INITCAP(cm.caseManager) AS caseManager,
	-- Peter Start
	tbTmentNew.specimenSentDate,
	CASE WHEN posTb.personTbResult IS NOT NULL THEN TRUE ELSE FALSE END AS hasActiveTb,
	CASE WHEN posTb.personTbResult IS NOT NULL THEN posTb.dateofTbDiagnosticResultReceived ELSE posTb.dateofTbDiagnosticResultReceived END AS dateOfTbPositiveResult,
	tbTmentNew.tbTreatmentStartDate AS tbTreatmentStartDateRaw,
	iptN.tptCompletionStatus AS tptCompletionStatusRaw,
	CAST(iptN.tptCompletionDate AS DATE) AS tptCompletionDateRaw,
	pharmIpt.pharm_tpt_initiation_date AS pharmacyTptStartDateRaw,
	pharmIpt.pharm_tpt_any_refill_date AS pharmacyTptEverReceivedDateRaw,
	-- Expose multi-drug variables:
	pharmIpt.pharm_6h_start_date,
	pharmIpt.pharm_6h_any_date,
	pharmIpt.pharm_3hp_start_date,
	pharmIpt.pharm_3hp_any_date,
	pharmIpt.pharm_3rh_start_date,
	pharmIpt.pharm_3rh_any_date
	-- Peter End
	FROM bio_data bd
	INNER JOIN hivEnrollment enroll ON enroll.personUuid101 = bd.personUuid
	 LEFT JOIN patient_lga p_lga on p_lga.personUuid11 = bd.personUuid
	 LEFT JOIN pharmacy_details_regimen pdr ON pdr.person_uuid40 = bd.personUuid
	 LEFT JOIN current_clinical c ON c.person_uuid10 = bd.personUuid
	 LEFT JOIN sample_collection_date scd ON scd.person_uuid120 = bd.personUuid
	 LEFT JOIN current_vl_result  cvlr ON cvlr.person_uuid130 = bd.personUuid
	 LEFT JOIN  labCD4 cd on cd.cd4_person_uuid = bd.personUuid
	 LEFT JOIN eac e ON e.person_uuid50 = bd.personUuid
	 LEFT JOIN biometric b ON b.person_uuid60 = bd.personUuid
	 LEFT JOIN current_regimen  ca ON ca.person_uuid70 = bd.personUuid
	 LEFT JOIN ipt ipt ON ipt.personUuid80 = bd.personUuid
	 LEFT JOIN iptNew iptN ON iptN.person_uuid = bd.personUuid
	 LEFT JOIN cervical_cancer cc ON cc.person_uuid90 = bd.personUuid
	 LEFT JOIN current_status ct ON ct.cuPersonUuid = bd.personUuid
	 LEFT JOIN previous pre ON pre.prePersonUuid = ct.cuPersonUuid
	 LEFT JOIN previous_previous prepre ON prepre.prePrePersonUuid = ct.cuPersonUuid
	 LEFT JOIN naive_vl_data nvd ON nvd.nvl_person_uuid = bd.personUuid
	 LEFT JOIN tb_sample_collection tbSample ON tbSample.personTbSample = bd.personUuid
	 LEFT JOIN  tbTreatment tbTment ON tbTment.tbTreatmentPersonUuid = bd.personUuid
	 LEFT JOIN  tbTreatmentNew tbTmentNew ON tbTmentNew.person_uuid_tb = bd.personUuid
	 LEFT JOIN  current_tb_result tbResult ON tbResult.personTbResult = bd.personUuid
	 LEFT JOIN crytococal_antigen crypt on crypt.personuuid12= bd.personUuid
	 LEFT JOIN  tbstatus tbS on tbS.person_uuid = bd.personUuid
	 LEFT JOIN  tblam tbl  on tbl.personuuidtblam = bd.personUuid
	 LEFT JOIN  dsd1 dsd1  on dsd1.person_uuid_dsd_1 = bd.personUuid
	 LEFT JOIN  dsd2 dsd2  on dsd2.person_uuid_dsd_2 = bd.personUuid
	 LEFT JOIN case_manager cm on cm.caseperson= bd.personUuid
	 LEFT JOIN client_verification cvl on cvl.person_uuid = bd.personUuid
	 LEFT JOIN vaCauseOfDeath vaod ON vaod.person_id = bd.personUuid
	 LEFT JOIN negativeTbDiagnosticResults negativeTb ON negativeTb.personTbResult = bd.personUuid AND negativeTb.dateOfTbSampleCollected = tbTmentNew.specimenSentDate
	 LEFT JOIN ipt_s iptStart ON iptStart.person_uuid = bd.personUuid
	 -- Peter Start
	 LEFT JOIN positiveTbDiagnosticResults posTb ON posTb.personTbResult = bd.personUuid
	 LEFT JOIN pharmacy_tpt_data pharmIpt ON pharmIpt.pharm_person_uuid = bd.personUuid
	 -- Peter End
 ),
total_newly_art_started_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in'  THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in'THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and artstartdate between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records
),
total_newly_art_started AS (
    SELECT
		kv.ord,
		'ART - 1' AS section,
		'Number of people living with HIV newly started on ART during the month (excludes ART transfer-in)' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_newly_art_started_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_1st_line_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line'  THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line'THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%1st line' and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records
),
total_receiving_art_1st_line AS (
    SELECT
		kv.ord,
		'ART - 2' AS section,
		'Number of people living with HIV and receiving ART and on 1st line regimen' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_1st_line_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_2nd_line_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line'  THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line'THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%2nd line' and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records
),
total_receiving_art_2nd_line AS (
    SELECT
		kv.ord,
		'ART - 2' AS section,
		'Number of people living with HIV and receiving ART and on 2nd line regimen' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_2nd_line_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_3rd_line_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line'  THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line'THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and currentregimenline ilike '%3rd line' and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records
),
total_receiving_art_3rd_line AS (
    SELECT
		kv.ord,
		'ART - 2' AS section,
		'Number of people living with HIV and receiving ART and on 3rd line regimen' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_3rd_line_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_mmd_wide as(
select 
		
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and monthsofarvrefill:: decimal < 3 THEN uniquepersonuuid END) as total_mmdlt3,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and monthsofarvrefill:: decimal between 3 and 5 THEN uniquepersonuuid END) as total_mmd35,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and monthsofarvrefill:: decimal >= 6 THEN uniquepersonuuid END) as total_mmd6plus,	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active'  and monthsofarvrefill > 0 THEN uniquepersonuuid END) as total
	FROM all_records
),
total_receiving_art_mmd AS (
    SELECT
		kv.ord,
		'ART - 2' AS section,
		'Number of people living with HIV and receiving ART and on Multi-Month Dispensing' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_mmd_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'total_mmdlt3', w.total_mmdlt3),
            (2, 'total_mmd35', w.total_mmd35),
            (3, 'total_mmd6plus', w.total_mmd6plus),
            (39, 'total', w.total)
    ) kv(ord,columnKey,value)
),
total_receiving_art_with_viralload_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)   THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12)  THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12) and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records
),
total_receiving_art_with_viralload AS (
    SELECT
		kv.ord,
		'ART - 3' AS section,
		'Number of people living with HIV on ART for at least 6 months with a viral load test result within the last 12 months' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_with_viralload_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_with_viralload_suppression_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='<1' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)   THEN uniquepersonuuid END) as male_lt1, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='<1' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_lt1,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='1-4' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_14, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='1-4' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_14,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='5-9' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_59, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='5-9' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='10-14' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_1014, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='10-14' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_1014,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='15-19' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_1519, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='15-19' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_1519,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='20-24' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_2024, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='20-24' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_2024,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='25-29' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_2529, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='25-29' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_2529,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='30-34' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_3034, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='30-34' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_3034,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='35-39' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_3539, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='35-39' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_3539,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='40-44' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_4044, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='40-44' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_4044,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='45-49' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_4549, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='45-49' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_4549,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_group ='50+' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as male_50plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group ='50+' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as female_50plus, 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='<1' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_lt1,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='1-4' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_14,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='5-9' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_59,	
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='10-14' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_1014,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='20-24' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_2024,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='15-19' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_1519,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='25-29' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_2529,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='30-34' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_3034,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='35-39' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_3539,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='40-44' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_4044,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='45-49' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_4549,
	count(distinct CASE WHEN uniquepersonuuid is not null and age_group ='50+' 	and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_50plus,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_male,
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000)  THEN uniquepersonuuid END) as total_female,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) THEN uniquepersonuuid END) as total,
	
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true and kp_typology_id='KP_TYPE_MSM' THEN uniquepersonuuid END) as total_kp_msm,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true and kp_typology_id='KP_TYPE_FSW' THEN uniquepersonuuid END) as total_kp_fsw,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true and kp_typology_id='KP_TYPE_PWID' THEN uniquepersonuuid END) as total_kp_pwid,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true and kp_typology_id='KP_TYPE_TG' THEN uniquepersonuuid END) as total_kp_tg,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true and kp_typology_id='KP_TYPE_PERSONS_IN_CUSTODIAL_CENTERS' THEN uniquepersonuuid END) as total_kp_picc,
	count(distinct CASE WHEN uniquepersonuuid is not null and  currentstatus = 'Active' and  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, artstartdate)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, artstartdate)) >= 6) and (currentviralload is not null or currentviralload != 'Failed') and (EXTRACT(YEAR FROM AGE(CURRENT_DATE, dateofcurrentviralload)) * 12 + EXTRACT(MONTH FROM AGE(CURRENT_DATE, dateofcurrentviralload)) <12 and currentviralload::int <= 1000) and is_kp=true THEN uniquepersonuuid END) as total_kp
	FROM all_records WHERE currentviralload ~ '^[0-9]+$'
),
total_receiving_art_with_viralload_suppression AS (
    SELECT
		kv.ord,
		'ART - 4' AS section,
		'Number of PLHIV on ART (for at least 6 months) who have virologic suppression (≤1000 copies/ml) within the last 12 months' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_with_viralload_suppression_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt1', w.male_lt1),
            (2, 'female_lt1', w.female_lt1),
            (3, 'total_lt1', w.total_lt1),
            (4, 'male_14', w.male_14),
            (5, 'female_14', w.female_14),
            (6, 'total_14', w.total_14),
            (7, 'male_59', w.male_59),
            (8, 'female_59', w.female_59),
            (9, 'total_59', w.total_59),
            (10, 'male_1014', w.male_1014),
            (11, 'female_1014', w.female_1014),
            (12, 'total_1014', w.total_1014),
            (13, 'male_1519', w.male_1519),
            (14, 'female_1519', w.female_1519),
            (15, 'total_1519', w.total_1519),
            (16, 'male_2024', w.male_2024),
            (17, 'female_2024', w.female_2024),
            (18, 'total_2024', w.total_2024),
            (19, 'male_2529', w.male_2529),
            (20, 'female_2529', w.female_2529),
            (21, 'total_2529', w.total_2529),
            (22, 'male_3034', w.male_3034),
            (23, 'female_3034', w.female_3034),
            (24, 'total_3034', w.total_3034),
            (25, 'male_3539', w.male_3539),
            (26, 'female_3539', w.female_3539),
            (27, 'total_3539', w.total_3539),
            (28, 'male_4044', w.male_4044),
            (29, 'female_4044', w.female_4044),
            (30, 'total_4044', w.total_4044),
            (31, 'male_4549', w.male_4549),
            (32, 'female_4549', w.female_4549),
            (33, 'total_4549', w.total_4549),
            (34, 'male_50plus', w.male_50plus),
            (35, 'female_50plus', w.female_50plus),
            (36, 'total_50plus', w.total_50plus),
            (37, 'total_male', w.total_male),
            (38, 'total_female', w.total_female),
            (39, 'total', w.total),
            (39, 'total_kp_msm', w.total_kp_msm),
            (39, 'total_kp_fsw', w.total_kp_fsw),
            (39, 'total_kp_pwid', w.total_kp_pwid),
            (39, 'total_kp_tg', w.total_kp_tg),
            (39, 'total_kp_picc', w.total_kp_picc),
            (39, 'total_kp', w.total_kp)
    ) kv(ord,columnKey,value)
),
total_receiving_art_iit_wide as(
select 
		
	count(distinct CASE WHEN uniquepersonuuid is not null and  LOWER(currentstatus) = 'stopped treatment'  	and currentstatusdate between '2026-01-01' and '2026-10-31' THEN uniquepersonuuid END) as total_stopped_treatment,
	count(distinct CASE WHEN uniquepersonuuid is not null and  LOWER(currentstatus) = 'iit' and currentstatusdate between '2026-01-01' and '2026-10-31' THEN uniquepersonuuid END) as total_lost_to_followup,
	count(distinct CASE WHEN uniquepersonuuid is not null and  LOWER(currentstatus) = 'died' and currentstatusdate between '2026-01-01' and '2026-10-31' THEN uniquepersonuuid END) as total_dead,	
	count(distinct CASE WHEN uniquepersonuuid is not null and (LOWER(currentstatus) = 'stopped treatment' or LOWER(currentstatus) = 'iit' or LOWER(currentstatus) = 'died') and currentstatusdate between '2026-01-01' and '2026-10-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_receiving_art_iit AS (
    SELECT
		kv.ord,
		'ART - 5' AS section,
		'Number of people living with HIV on ART who had treatment interruption by the end of the reporting quarter  ' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_iit_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'total_stopped_treatment', w.total_stopped_treatment),
            (2, 'total_lost_to_followup', w.total_lost_to_followup),
            (3, 'total_dead', w.total_dead),
            (4, 'total', w.total)
    ) kv(ord,columnKey,value)
),
total_receiving_art_restarted_wide as(
select 	
	count(distinct CASE WHEN uniquepersonuuid is not null and LOWER(currentstatus) = 'restarted' and currentstatusdate between '2026-10-01' and '2026-10-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_receiving_art_restarted AS (
    SELECT
		kv.ord,
		'ART - 6' AS section,
		'Number of people living with HIV who restarted ART during the month ' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_restarted_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'total', w.total)
    ) kv(ord,columnKey,value)
),
total_receiving_art_transferred_out_wide as(
select 	
	count(distinct CASE WHEN uniquepersonuuid is not null and LOWER(currentstatus) = 'transferred out' and currentstatusdate between '2026-10-01' and '2026-10-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_receiving_art_transferred_out AS (
    SELECT
		kv.ord,
		'ART - 7' AS section,
		'Number of people living with HIV who were transferred out during the month' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_transferred_out_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'total', w.total)
    ) kv(ord,columnKey,value)
),
total_receiving_art_transferred_in_wide as(
select 	
	count(distinct CASE WHEN uniquepersonuuid is not null and LOWER(careentry) = 'transfer-in' and currentstatusdate between '2026-10-01' and '2026-10-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_receiving_art_transferred_in AS (
    SELECT
		kv.ord,
		'ART - 8' AS section,
		'Number of people living with HIV who were transferred in during the month' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_receiving_art_transferred_in_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'total', w.total)
    ) kv(ord,columnKey,value)
),
total_newly_art_enrolled_wide as(
select 
	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_years < 5 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in'  THEN uniquepersonuuid END) as male_lt5, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_years < 5 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_lt5,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_years between 5 and 14 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_514, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_years between 5 and 14 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_514,	
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male'   and age_years >=15 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as male_15plus, 
	count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_years >=15 and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in' THEN uniquepersonuuid END) as female_15plus,	
	count(distinct CASE WHEN uniquepersonuuid is not null and dateenrolled between '2026-01-01' and '2026-01-31' and LOWER(careentry) != 'transfer-in'THEN uniquepersonuuid END) as total
	FROM all_records
),
total_newly_art_enrolled AS (
    SELECT
		kv.ord,
		'ART - 17' AS section,
		'Number of people living with HIV newly enrolled during the month' as rowLabel,
		kv.columnKey,
		kv.value
    FROM total_newly_art_enrolled_wide w
    CROSS JOIN LATERAL (
        VALUES
            (1, 'male_lt5', w.male_lt5),
            (2, 'female_lt5', w.female_lt5),
            (3, 'male_514', w.male_514),
            (4, 'female_514', w.female_514),
            (5, 'male_15plus', w.male_15plus),
            (6, 'female_15plus', w.female_15plus),
            (7, 'total', w.total)
    ) kv(ord,columnKey,value)
),
-- Peter Start

total_clinically_screened_tb_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus IS NOT NULL THEN uniquepersonuuid END) as total
	FROM all_records
),
total_clinically_screened_tb AS (
	SELECT
		kv.ord,
		'ART - 9' AS section,
		'Number of people living with HIV on ART (Including PMTCT) who were Clinically Screened for TB in HIV Treatment Settings' as rowLabel,
		kv.columnKey,
		kv.value
	FROM
		total_clinically_screened_tb_wide w
		CROSS JOIN LATERAL (
			VALUES
				(1, 'male_lt5', w.male_lt5),
				(2, 'female_lt5', w.female_lt5),
				(3, 'total_lt5', w.total_lt5),
				(4, 'male_514', w.male_514),
				(5, 'female_514', w.female_514),
				(6, 'total_514', w.total_514),
				(7, 'male_15plus', w.male_15plus),
				(8, 'female_15plus', w.female_15plus),
				(9, 'total_15plus', w.total_15plus),
				(10, 'total_male', w.total_male),
				(11, 'total_female', w.total_female),
				(12, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_presumptive_tb_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_presumptive_tb AS (
	SELECT
		kv.ord,
		'ART - 10' AS section,
		'Number of people living with HIV on ART with Presumptive TB during the month' as rowLabel,
		kv.columnKey,
		kv.value
	FROM
		total_presumptive_tb_wide w
		CROSS JOIN LATERAL (
			VALUES
				(1, 'male_lt5', w.male_lt5),
				(2, 'female_lt5', w.female_lt5),
				(3, 'total_lt5', w.total_lt5),
				(4, 'male_514', w.male_514),
				(5, 'female_514', w.female_514),
				(6, 'total_514', w.total_514),
				(7, 'male_15plus', w.male_15plus),
				(8, 'female_15plus', w.female_15plus),
				(9, 'total_15plus', w.total_15plus),
				(10, 'total_male', w.total_male),
				(11, 'total_female', w.total_female),
				(12, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_presumptive_tb_tested_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and dateOfTbScreened between '2026-01-01' and '2026-01-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_presumptive_tb_tested AS (
	SELECT
		kv.ord,
		'ART - 11' AS section,
		'Number of people living with HIV on ART with Presumptive TB who were tested for TB during the month' as rowLabel,
		kv.columnKey,
		kv.value
	FROM
		total_presumptive_tb_tested_wide w
		CROSS JOIN LATERAL (
			VALUES
				(1, 'male_lt5', w.male_lt5),
				(2, 'female_lt5', w.female_lt5),
				(3, 'total_lt5', w.total_lt5),
				(4, 'male_514', w.male_514),
				(5, 'female_514', w.female_514),
				(6, 'total_514', w.total_514),
				(7, 'male_15plus', w.male_15plus),
				(8, 'female_15plus', w.female_15plus),
				(9, 'total_15plus', w.total_15plus),
				(10, 'total_male', w.total_male),
				(11, 'total_female', w.total_female),
				(12, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_active_tb_disease_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_active_tb_disease AS (
	SELECT
		kv.ord,
		'ART - 12' AS section,
		'Number of people living with HIV on ART who have Active TB Disease' as rowLabel,
		kv.columnKey,
		kv.value
	FROM
		total_active_tb_disease_wide w
		CROSS JOIN LATERAL (
			VALUES
				(1, 'male_lt5', w.male_lt5),
				(2, 'female_lt5', w.female_lt5),
				(3, 'total_lt5', w.total_lt5),
				(4, 'male_514', w.male_514),
				(5, 'female_514', w.female_514),
				(6, 'total_514', w.total_514),
				(7, 'male_15plus', w.male_15plus),
				(8, 'female_15plus', w.female_15plus),
				(9, 'total_15plus', w.total_15plus),
				(10, 'total_male', w.total_male),
				(11, 'total_female', w.total_female),
				(12, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_initiated_tb_treatment_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and dateOfTbScreened between '2025-01-01' and '2026-12-31' and tbStatus = 'Presumptive TB' and specimenSentDate between '2025-01-01' and '2026-12-31' and dateOfTbPositiveResult between '2025-01-01' and '2026-12-31' and tbTreatmentStartDateRaw between '2025-01-01' and '2026-12-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_initiated_tb_treatment AS (
	SELECT
		kv.ord,
		'ART - 13' AS section,
		'Number of people living with HIV on ART with active TB disease who initiated TB treatment' as rowLabel,
		kv.columnKey,
		kv.value
	FROM
		total_initiated_tb_treatment_wide w
		CROSS JOIN LATERAL (
			VALUES
				(1, 'male_lt5', w.male_lt5),
				(2, 'female_lt5', w.female_lt5),
				(3, 'total_lt5', w.total_lt5),
				(4, 'male_514', w.male_514),
				(5, 'female_514', w.female_514),
				(6, 'total_514', w.total_514),
				(7, 'male_15plus', w.male_15plus),
				(8, 'female_15plus', w.female_15plus),
				(9, 'total_15plus', w.total_15plus),
				(10, 'total_male', w.total_male),
				(11, 'total_female', w.total_female),
				(12, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_initiated_tpt_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_15plus,
		
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_15plus_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_15plus_6h,
		-- 3HP
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_15plus_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_15plus_3hp,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as male_15plus_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_start_date between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as female_15plus_3rh,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and pharmacyTptStartDateRaw between '2026-01-01' and '2026-01-31' THEN uniquepersonuuid END) as total
	FROM all_records
),
total_initiated_tpt AS (
	SELECT kv.ord, 'ART - 14' AS section, 'Number of people living with HIV on ART who initiated TB preventive treatment (TPT)' as rowLabel, kv.columnKey, kv.value
	FROM total_initiated_tpt_wide w CROSS JOIN LATERAL (VALUES
		(1, 'male_lt5', w.male_lt5), (2, 'female_lt5', w.female_lt5), (3, 'total_lt5', w.total_lt5),
		(4, 'male_514', w.male_514), (5, 'female_514', w.female_514), (6, 'total_514', w.total_514),
		(7, 'male_15plus', w.male_15plus), (8, 'female_15plus', w.female_15plus), (9, 'total_15plus', w.total_15plus),
		(10, 'male_lt5_6H', w.male_lt5_6h), (11, 'female_lt5_6H', w.female_lt5_6h), (12, 'male_15plus_6H', w.male_15plus_6h), (13, 'female_15plus_6H', w.female_15plus_6h),
		(14, 'male_lt5_3HP', w.male_lt5_3hp), (15, 'female_lt5_3HP', w.female_lt5_3hp), (16, 'male_15plus_3HP', w.male_15plus_3hp), (17, 'female_15plus_3HP', w.female_15plus_3hp),
		(18, 'male_lt5_3RH', w.male_lt5_3rh), (19, 'female_lt5_3RH', w.female_lt5_3rh), (20, 'male_15plus_3RH', w.male_15plus_3rh), (21, 'female_15plus_3RH', w.female_15plus_3rh),
		(22, 'total_male', w.total_male), (23, 'total_female', w.total_female), (24, 'total', w.total)
	) kv(ord, columnKey, value)
),
total_completed_tpt_wide as (
	select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total_15plus,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_15plus_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_15plus_6h,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_15plus_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_15plus_3hp,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as male_15plus_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_start_date IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as female_15plus_3rh,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and pharmacyTptStartDateRaw IS NOT NULL and tptCompletionDateRaw between '2026-01-01' and '2026-01-31' and tptCompletionStatusRaw = 'Treatment Completed' THEN uniquepersonuuid END) as total
		FROM all_records
),
total_completed_tpt AS (
		SELECT kv.ord, 'ART - 15' AS section, 'Number of people living with HIV on ART who completed a course of TB preventive treatment among those who initiated TPT' as rowLabel, kv.columnKey, kv.value
		FROM total_completed_tpt_wide w CROSS JOIN LATERAL (VALUES
		(1, 'male_lt5', w.male_lt5), (2, 'female_lt5', w.female_lt5), (3, 'total_lt5', w.total_lt5),
		(4, 'male_514', w.male_514), (5, 'female_514', w.female_514), (6, 'total_514', w.total_514),
		(7, 'male_15plus', w.male_15plus), (8, 'female_15plus', w.female_15plus), (9, 'total_15plus', w.total_15plus),
		(10, 'male_lt5_6H', w.male_lt5_6h), (11, 'female_lt5_6H', w.female_lt5_6h), (12, 'male_15plus_6H', w.male_15plus_6h), (13, 'female_15plus_6H', w.female_15plus_6h),
		(14, 'male_lt5_3HP', w.male_lt5_3hp), (15, 'female_lt5_3HP', w.female_lt5_3hp), (16, 'male_15plus_3HP', w.male_15plus_3hp), (17, 'female_15plus_3HP', w.female_15plus_3hp),
		(18, 'male_lt5_3RH', w.male_lt5_3rh), (19, 'female_lt5_3RH', w.female_lt5_3rh), (20, 'male_15plus_3RH', w.male_15plus_3rh), (21, 'female_15plus_3RH', w.female_15plus_3rh),
		(22, 'total_male', w.total_male), (23, 'total_female', w.total_female), (24, 'total', w.total)
		) kv(ord, columnKey, value)
),
total_ever_received_tpt_wide as (
		select
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as male_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as female_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total_lt5,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as male_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as female_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group IN ('5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total_514,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as male_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as female_15plus,
		count(distinct CASE WHEN uniquepersonuuid is not null and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total_15plus,


		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_6h_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_lt5_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_15plus_6h,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_6h_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_15plus_6h,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3hp_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_lt5_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_15plus_3hp,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3hp_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_15plus_3hp,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group IN ('<1', '1-4') and currentstatus = 'Active' and pharm_3rh_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_lt5_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_any_date <= '2026-01-31' THEN uniquepersonuuid END) as male_15plus_3rh,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and age_group NOT IN ('<1', '1-4', '5-9', '10-14') and currentstatus = 'Active' and pharm_3rh_any_date <= '2026-01-31' THEN uniquepersonuuid END) as female_15plus_3rh,

		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Male' and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total_male,
		count(distinct CASE WHEN uniquepersonuuid is not null and gender = 'Female' and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total_female,
		count(distinct CASE WHEN uniquepersonuuid is not null and currentstatus = 'Active' and pharmacyTptEverReceivedDateRaw <= '2026-01-31' THEN uniquepersonuuid END) as total
		FROM all_records
),
total_ever_received_tpt AS (
		SELECT kv.ord, 'ART - 16' AS section, 'Number of people living with HIV currently on ART who had ever received TB preventive treatment (TPT)' as rowLabel, kv.columnKey, kv.value
		FROM total_ever_received_tpt_wide w CROSS JOIN LATERAL (VALUES
		(1, 'male_lt5', w.male_lt5), (2, 'female_lt5', w.female_lt5), (3, 'total_lt5', w.total_lt5),
		(4, 'male_514', w.male_514), (5, 'female_514', w.female_514), (6, 'total_514', w.total_514),
		(7, 'male_15plus', w.male_15plus), (8, 'female_15plus', w.female_15plus), (9, 'total_15plus', w.total_15plus),
		(10, 'male_lt5_6H', w.male_lt5_6h), (11, 'female_lt5_6H', w.female_lt5_6h), (12, 'male_15plus_6H', w.male_15plus_6h), (13, 'female_15plus_6H', w.female_15plus_6h),
		(14, 'male_lt5_3HP', w.male_lt5_3hp), (15, 'female_lt5_3HP', w.female_lt5_3hp), (16, 'male_15plus_3HP', w.male_15plus_3hp), (17, 'female_15plus_3HP', w.female_15plus_3hp),
		(18, 'male_lt5_3RH', w.male_lt5_3rh), (19, 'female_lt5_3RH', w.female_lt5_3rh), (20, 'male_15plus_3RH', w.male_15plus_3rh), (21, 'female_15plus_3RH', w.female_15plus_3rh),
		(22, 'total_male', w.total_male), (23, 'total_female', w.total_female), (24, 'total', w.total)
		) kv(ord, columnKey, value)
)

-- Peter End
select * from total_newly_art_started
UNION ALL
select * from total_receiving_art_1st_line
UNION ALL
select * from total_receiving_art_2nd_line
UNION ALL
select * from total_receiving_art_3rd_line
UNION ALL
select * from total_receiving_art_mmd
UNION ALL
select * from total_receiving_art_with_viralload
UNION ALL
select * from total_receiving_art_with_viralload_suppression
UNION ALL
select * from total_receiving_art_iit
UNION ALL
select * from total_receiving_art_restarted
UNION ALL
select * from total_receiving_art_transferred_out
UNION ALL
select * from total_receiving_art_transferred_in
UNION ALL
select * from total_newly_art_enrolled
-- Peter Start
UNION ALL
select * from total_clinically_screened_tb
UNION ALL
select * from total_presumptive_tb
UNION ALL
select * from total_presumptive_tb_tested
UNION ALL
select * from total_active_tb_disease
UNION ALL
select * from total_initiated_tb_treatment
UNION ALL
select * from total_initiated_tpt
UNION ALL
select * from total_completed_tpt
UNION ALL
select * from total_ever_received_tpt
-- Peter End
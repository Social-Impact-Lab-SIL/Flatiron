/*Let's get the Flatiron vitals and med order files down to a manageable size */

/*Use this when using Windows-mounted
cd "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Serena\working" 
global path "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Original"
sysdir set PLUS "\\vast.rde.missouri.edu\mp94p-lab\StataUserPackages"
*/

/*
/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global path "/cluster/VAST/mp94p-lab/Flatiron/Data/Original"
sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"
*/
global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")


*log using "gotcare90days_${today}.log", replace
set processors 24

ssc install listsome
set linesize 255

/*

/*Make small files to tinker around */
foreach cancer in CRC /*RCC Pancreatic NSCLC MetProstate MetastaticBreast Melanoma HeadNeck Gastric Bladder*/ {

*Address annoying variable naming inconsistencies
use "${path}/`cancer'/Visit.dta", clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	sample 1000, count
}
save "`cancer'_Rvis.dta", replace

*Address annoying variable naming inconsistencies
use "${path}/`cancer'/MedicationOrder.dta", clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	sample 1000, count
}
save "`cancer'_Rmed.dta", replace
}
*/

/*We don't have Stata versions of Lab files - let's make this once then we do not have to do it again */
foreach cancer in CRC RCC Pancreatic NSCLC MetProstate MetastaticBreast Melanoma HeadNeck Gastric Bladder {
	import delimited "${path}/`cancer'/Lab.csv", clear
	compress
	save "${path}/`cancer'/Lab.dta", replace
}




/*We want the earliest dates AFTER the index date. This is tricky because sometimes these dates are BEFORE the index date - I'm guessing if the patient had workup done prior to diagnosis? But it doesn't necessarily imply they got treatment where they got diagnosed.
This chunk of program will keep 1 obs per person/cohort for each type of medical encounter file IF they have one within 90 days, then merge it all together so we can tell if they might've gone elsewhere for tx or not*/
foreach cancer in CRC RCC Pancreatic NSCLC MetProstate MetastaticBreast Melanoma HeadNeck Gastric Bladder {

if "`cancer'"== "CRC" {
	local cohort="Metastatic colorectal"
}
else if "`cancer'"== "RCC" {
	local cohort="Metastatic renal"
}
else if "`cancer'"== "Pancreatic" {
	local cohort="Metastatic pancreatic"
}
else if "`cancer'"== "NSCLC" {
	local cohort="Advanced non-small cell lung cancer"
}
else if "`cancer'"== "MetProstate" {
	local cohort="Metastatic prostate"
}
else if "`cancer'"== "MetastaticBreast" {
	local cohort="Metastatic breast"
}
else if "`cancer'"== "Melanoma" {
	local cohort="Advanced melanoma"
}
else if "`cancer'"== "HeadNeck" {
	local cohort="Advanced head and neck"
}
else if "`cancer'"== "Gastric" {
	local cohort="Advanced gastric"
}
else  /*Bladder*/ {
	local cohort="Advanced urothelial carcinoma"
}
display "`cancer'"


*Visits
use "${path}/`cancer'/Visit.dta", clear
	display "`cancer' Visit"
	foreach x of varlist _all  {
		rename `x' `=lower("`x'")'
	}
	desc * 
	keep patientid visitdate
	gen float actualdate=date(visitdate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_vis=actualdate-indexdate
	gen include_vis=1 if diff_vis>=0 & diff_vis<=90
	display "Visit `cohort'"
	*Check
	listsome patientid visitdate indexdate diff_vis include_vis if include_vis==1, random
	listsome patientid visitdate indexdate diff_vis include_vis if include_vis==., random
	
	sort patientid include_vis diff_vis
	keep if patientid!=patientid[_n-1] & include_vis==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop visitdate
	rename actualdate visitdate
	gen file="visits"
	keep patientid visitdate include_vis diff_vis
save "`cancer'_vis.dta", replace /*End up with a file with patients to include_visd based on visits*/




*Medication orders
use "${path}/`cancer'/MedicationOrder.dta", clear
display "`cancer' Med Orders"
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	}
	desc *
	keep patientid ordereddate
	gen actualdate=date(ordereddate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_medord=actualdate-indexdate
	gen include_medord=1 if diff_medord>=0 & diff_medord<=90
	display "Med order `cohort'"
	*Check
	listsome patientid ordereddate indexdate diff_medord include_medord if include_medord==1, random
	listsome patientid ordereddate indexdate diff_medord include_medord if include_medord==., random
	
	sort patientid include_medord diff_medord
	keep if patientid!=patientid[_n-1] & include_medord==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop ordereddate
	rename actualdate orderdate
	gen file="orders"
	keep patientid orderdate include_medord diff_medord
save "`cancer'_medord.dta", replace


*Lab
use "${path}/`cancer'/Lab.dta", clear
display "`cancer' Lab"
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	}
	desc *
	keep patientid testdate
	gen actualdate=date(testdate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_lab=actualdate-indexdate
	gen include_lab=1 if diff_lab>=0 & diff_lab<=90
	display "Lab `cohort'"
	*Check
	listsome patientid testdate indexdate diff_lab include_lab if include_lab==1, random
	listsome patientid testdate indexdate diff_lab include_lab if include_lab==., random
	
	sort patientid include_lab diff_lab
	keep if patientid!=patientid[_n-1] & include_lab==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop testdate
	rename actualdate testdate
	gen file="lab"
	rename testdate labdate
	keep patientid labdate include_lab diff_lab
save "`cancer'_lab.dta", replace


*Vitals
use "${path}/`cancer'/Vitals.dta", clear
display "`cancer' Vitals"
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	}
	desc *
	keep patientid testdate
	gen actualdate=date(testdate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_vitals=actualdate-indexdate
	gen include_vitals=1 if diff_vitals>=0 & diff_vitals<=90
	display "Vitals `cohort'"
	*Check
	listsome patientid testdate indexdate diff_vitals include_vitals if include_vitals==1, random
	listsome patientid testdate indexdate diff_vitals include_vitals if include_vitals==., random
	
	sort patientid include_vitals diff_vitals
	keep if patientid!=patientid[_n-1] & include_vitals==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop testdate
	rename actualdate vitdate
	gen file="vitals"
	keep patientid vitdate include_vitals diff_vitals
save "`cancer'_vitals.dta", replace


*Med Administration
use "${path}/`cancer'/MedicationAdministration.dta", clear
display "`cancer' Med admin"
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	}
	desc *
	keep patientid administereddate
	gen actualdate=date(administereddate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_medadm=actualdate-indexdate
	gen include_medadm=1 if diff_medadm>=0 & diff_medadm<=90
	display "Med admin `cohort'"
	*Check
	listsome patientid administereddate indexdate diff_medadm include_medadm if include_medadm==1, random
	listsome patientid administereddate indexdate diff_medadm include_medadm if include_medadm==., random
	
	sort patientid include_medadm diff_medadm
	keep if patientid!=patientid[_n-1] & include_medadm==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop administereddate
	rename actualdate administereddate
	gen file="medadmin"
	keep patientid administereddate include_medadm diff_medadm
save "`cancer'_medadmin.dta", replace


*Drug Episode
use "${path}/`cancer'/DrugEpisode.dta", clear
display "`cancer' drugep"
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
	}
	desc *
	keep patientid episodedate
	gen actualdate=date(episodedate,"YMD")
	format actualdate %tdnn/dd/CCYY
	gen cohort = "`cohort'"
	merge m:1 patientid cohort using "all_merged", keepusing(indexdate)
	*Flag obs if there's a visit day falling within 90 day window of index date
	sort patientid actualdate
	gen diff_drug=actualdate-indexdate
	gen include_drug=1 if diff_drug>=0 & diff_drug<=90
	display "drugep `cohort'"
	*Check
	listsome patientid episodedate indexdate diff_drug include_drug if include_drug==1, random
	listsome patientid episodedate indexdate diff_drug include_drug if include_drug==., random
	
	sort patientid include_drug diff_drug
	keep if patientid!=patientid[_n-1] & include_drug==1 /*keep only 1 (first) obs for each patient where the visit date fits in the window */
	order patientid actualdate
	drop episodedate
	rename actualdate drugdate
	gen file="drugep"
	keep patientid drugdate include_drug diff_drug 
save "`cancer'_drugep.dta", replace



*Merge
use "`cancer'_vis.dta", clear
merge 1:1 patientid using "`cancer'_medord.dta"
drop _merge
merge 1:1 patientid using "`cancer'_lab.dta"
drop _merge
merge 1:1 patientid using "`cancer'_vitals.dta"
drop _merge
merge 1:1 patientid using "`cancer'_medadmin.dta"
drop _merge
merge 1:1 patientid using "`cancer'_drugep.dta"
drop _merge
egen include_tot=rowtotal(include_drug include_medadm include_vitals  include_lab  include_medord  include_vis   )
replace include_tot=1 if include_tot>0 & !missing(include_tot)
label var include_tot "At least 1 med encounter in last 90 days"
gen cohort="`cancer'"
ta cohort include_tot, missing
duplicates list patientid cohort
save "`cancer'gotcare90days.dta", replace

}

*Append everyone
use "CRCgotcare90days.dta", clear
append using "RCCgotcare90days.dta"
append using "Pancreaticgotcare90days.dta"
append using "NSCLCgotcare90days.dta"
append using "MetProstategotcare90days.dta"
append using "MetastaticBreastgotcare90days.dta"
append using "Melanomagotcare90days.dta"
append using "HeadNeckgotcare90days.dta"
append using "Gastricgotcare90days.dta"
append using "Bladdergotcare90days.dta"

replace cohort="Advanced urothelial carcinoma" if cohort=="Bladder"
replace cohort="Metastatic colorectal" if cohort=="CRC"
replace cohort="Advanced gastric" if cohort=="Gastric"
replace cohort="Advanced head and neck" if cohort=="HeadNeck"
replace cohort="Advanced melanoma" if cohort=="Melanoma"
replace cohort="Metastatic prostate" if cohort=="MetProstate"
replace cohort="Metastatic breast" if cohort=="MetastaticBreast"
replace cohort="Advanced non-small cell lung cancer" if cohort=="NSCLC"
replace cohort="Metastatic pancreatic" if cohort=="Pancreatic"
replace cohort="Metastatic renal" if cohort=="RCC"
compress
save "gotcare90days.dta", replace


*log  close






















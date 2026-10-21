/*This program sets up the Flatiron analytic file 
* A separate do file sets up line of therapy in the first step: "${labpath}/Flatiron/Data/Serena/Line.do"
* A separate do file makes variables for identifying any structured activity (identifying folks who might've gotten tx elsewhere) because Visits, Labs etc. other files are way too big to do outside of batch mode. "${labpath}/Flatiron/Data/Serena/VisitsMeds_2024.05.06b". It gets called in partway through this program
* Guthrie's file sets up PSL policy data
* Flatironpolicysetup....do set up other policy controls


*/

/*Use this when using Windows-mounted
cd "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Serena\working"
global path "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Original"
global labpath "\\vast.rde.missouri.edu\mp94p-lab\"
sysdir set PLUS "\\vast.rde.missouri.edu\mp94p-lab\StataUserPackages"
sysdir set PERSONAL "\\vast.rde.missouri.edu\mp94p-lab\StataUserPackages"
*/


/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global path "/cluster/VAST/mp94p-lab/Flatiron/Data/Original"
global labpath "/cluster/VAST/mp94p-lab/"
sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"
sysdir set PERSONAL "/cluster/VAST/mp94p-lab/StataUserPackages"
global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")


****************************************
*Set up the Line of Therapy files

do "${labpath}/Flatiron/Data/Serena/1a.Line.do"

log using "FlatironSetup_${today}d.log", replace

/*FIRST run the script "FlatironVisitsMeds.sh" which runs program "VisitsMeds", which identifies the earliest visits/med orders per patient. Needs to run in Hellbender because the files are too big otherwise */


****************************************
/*Combine basic files across all cancers -  based on Guthrie's program */
foreach cancer in CRC RCC Pancreatic NSCLC MetProstate MetastaticBreast Melanoma HeadNeck Gastric Bladder {

if "`cancer'"== "CRC" {
	local cohort="Metastatic colorectal"
	local enhanced="Enhanced_MetastaticCRC"
}
else if "`cancer'"== "RCC" {
	local cohort="Metastatic renal"
	local enhanced="Enhanced_MetastaticRCC"	
}
else if "`cancer'"== "Pancreatic" {
	local cohort="Metastatic pancreatic"
	local enhanced="Enhanced_MetPancreatic"
}
else if "`cancer'"== "NSCLC" {
	local cohort="Advanced non-small cell lung cancer"
	local enhanced="Enhanced_AdvancedNSCLC"
}
else if "`cancer'"== "MetProstate" {
	local cohort="Metastatic prostate"
	local enhanced="Enhanced_MetProstate"
}
else if "`cancer'"== "MetastaticBreast" {
	local cohort="Metastatic breast"
	local enhanced="Enhanced_MetastaticBreast"
}
else if "`cancer'"== "Melanoma" {
	local cohort="Advanced melanoma"
	local enhanced="Enhanced_AdvancedMelanoma"
}
else if "`cancer'"== "HeadNeck" {
	local cohort="Advanced head and neck"
	local enhanced="Enhanced_AdvHeadNeck"
}
else if "`cancer'"== "Gastric" {
	local cohort="Advanced gastric"
	local enhanced="Enhanced_AdvGastricEsoph"
}
else  /*Bladder*/ {
	local cohort="Advanced urothelial carcinoma"
	local enhanced="Enhanced_AdvUrothelial"
}
display "`cancer'"


*Address annoying variable naming inconsistencies
use "${path}/`cancer'/`enhanced'.dta", clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
}
save "`cancer'_enh.dta", replace

use "${path}/`cancer'/Demographics.dta", clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
}
save "`cancer'_demo.dta", replace

use "${path}/`cancer'/SocialDeterminantsOfHealth.dta", clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
}
save "`cancer'_sdoh.dta", replace

use "${path}/`cancer'/Enhanced_Mortality_V2.dta" , clear
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
}
save "`cancer'_mort.dta", replace

*Can't merge this one because people have mult insurance observations possibly
*Something went wrong with reading this in from spreadsheet. I'm going to redo it. gastric & renal didn't read in headers as headers
import delimited "${path}/`cancer'/Insurance.csv", varnames(1) clear 
save "${path}/`cancer'/Insurance.dta", replace
foreach x of varlist _all  {
	rename `x' `=lower("`x'")'
}
gen cohort = "`cohort'"
save "`cancer'_ins.dta", replace


*merge
use "`cancer'_enh.dta", clear
duplicates report patientid 
display "demo"
merge 1:1 patientid using "`cancer'_demo.dta"
drop _merge
display "sdoh"
merge 1:1 patientid using "`cancer'_sdoh.dta"
drop _merge
display "mort"
merge 1:1 patientid  using "`cancer'_mort.dta"
drop _merge
display "l1"
merge 1:1 patientid using "`cancer'l1.dta"
drop _merge
*generating cohort to denote Metastatic CRC type
gen cohort = "`cohort'"

save "`cancer'_merged.dta", replace
clear

}

*************************
*append all basic files

use "Bladder_merged.dta", clear
append using CRC_merged.dta RCC_merged.dta Pancreatic_merged.dta NSCLC_merged.dta MetProstate_merged.dta MetastaticBreast_merged.dta Melanoma_merged.dta HeadNeck_merged.dta Gastric_merged.dta 

*How many people are in more than 1 cohort?
duplicates report patientid
duplicates tag patientid, generate(multobs)
label var multobs "# additional instances for this individual"


*************************
*We need to figure out which obs to drop. Let's flag them one by one
gen drop=0
gen dropreason=""
label var drop "Possibly dropped (for any reason)"
label var dropreason "Why drop? (mut excl)"


*************************
*What's the geography situation?
ta state, missing

*get FIPS codes merged on
rename state stateabbrev
merge m:1 stateabbrev using "${labpath}/reusable_files/Working/state_names_fips.dta"
*I think the Flatiron data masks low population geographies: Alaska, Montana, North Dakota, South Dakota, Vermont, Wyoming
ta state if _merge==2, missing 
drop if _merge==2
drop _merge

replace drop=1 if stateabbrev=="PR"
gen drop_terr=1 if stateabbrev=="PR"
label var drop_terr "Drop reason: territory"
replace dropreason="Exclude Puerto Rico" if stateabbrev=="PR" & missing(dropreason)
replace drop=1 if missing(stateabbrev)
gen drop_nogeo=1 if missing(stateabbrev)
label var drop_nogeo "Drop reason: Missing state information"
replace dropreason="Missing state information" if missing(stateabbrev) & missing(dropreason)


*************************
*Figure out diagnosis date
ta cohort if !missing( diagnosisdate) 
ta cohort if !missing( advanceddiagnosisdate ) 
ta cohort if  !missing( metdiagnosisdate )
ta cohort if !missing( advanceddiagnosisdate ) & !missing( metdiagnosisdate )

*We need to combine advanced and metastatic diagnosis dates. Melanoma has both - but is part of the advanced database so lets go with that
gen indexdate=advanceddiagnosisdate 
replace indexdate=metdiagnosisdate if missing(indexdate) & !missing(metdiagnosisdate) & cohort!="Advanced melanoma"


*Some missing in the renal cohort
ta cohort if missing(indexdate), missing

replace drop=1 if missing(indexdate)
gen drop_noindex=1 if missing(indexdate)
label var drop_noindex "Drop reason: missing adv/met diagnosis date"
replace dropreason= "missing adv/met diagnosis date" if missing(indexdate) & missing(dropreason)

gen indexdate1=date(indexdate, "YMD")
format indexdate1 %tdnn/dd/CCYY
gen indexyear=year(indexdate1)
gen indexmonth=month(indexdate1)
drop indexdate
rename indexdate1 indexdate
label var indexdate "Adv/Met Diagnosis Date to use for timeliness calc"
label var indexyear "Adv/Met Diagnosis Year to use for timeliness calc"
label var indexmonth "Adv/Met Diagnosis Month to use for timeliness calc"

*Our year range is 2011-2023
ta indexyear, missing
*What does this look like by cancer? Not bad! Decent coverage across years across cancers. Note Pancreatic, colorectal, and prostate start late.
set linesize 255
ta cohort indexyear, missing

*************************
*Age
*creating minimum age of diagnosis based on the  diagnosis dates provided
gen agedx = indexyear - birthyear - 1
tabstat agedx, statistics(n mean min max)
label var agedx "Age at Adv/Met Diagnosis"

gen agegrp=1 if agedx <18 & !missing(agedx)
replace agegrp=2 if agedx >=18 & agedx<65 & !missing(agedx)
replace agegrp=3 if agedx >64 & !missing(agedx)
label define agegrp 1 "Age <18" 2 "Age 18-64" 3 "Age 65+"
label values agegrp agegrp
label var agegrp "Age group at Adv/Met Dx"
*Check
ta agegrp, missing
ta agedx agegrp, missing
*What's up with the missing ages?
set linesize 255
ta dropreason cohort if missing(agedx), missing /*All seem to be metastatic renal. Why? I checked the original Enhanced_MetastaticRCC file and MetDiagnosisDate truly is missing. They all are stage IV though so there should be a date. They're all getting dropped anyway so it's moot that they're missing age */

*What's up with the kids?
li patientid cohort birthyear diagnosisdate advanceddiagnosisdate metdiagnosisdate agedx agegrp if agedx<18
*OK - they seem legit kids, but there are so few we should probably drop
replace drop=1 if agegrp==1
gen drop_young=1 if agegrp==1
label var drop_young "Drop reason: age under 18"
replace dropreason="Under age 18" if agegrp==1 & missing(dropreason)


*************************
*Calculate timeliness variables

gen actualdate=date(startdate,"YMD")
format actualdate %tdnn/dd/CCYY
label var actualdate "Line 1 start date"
rename actualdate l1startdate

*Continuous
gen time_days=l1startdate- indexdate
tabstat time_days, statistics(n min p10 p25 p50 p75 p90 max) 

replace drop=1 if missing(l1startdate)
gen drop_nol1date=1 if missing(l1startdate)
label var drop_nol1date "Drop reason: missing Line 1 start date"
replace dropreason="no line 1 start date recorded" if missing(l1startdate) & missing(dropreason)

*Examine negative days to treatment start
*most of these are only about a couple weeks before the start date
tabstat time_days if time_days<0, statistics(n min p10 p25 p50 p75 p90 max) 
ta time_days if time_days<0
set linesize 255
listsome patientid cohort diagnosisdate advanceddiagnosisdate metdiagnosisdate l1startdate linename linenumber time_days if time_days<0, random

*Let's bottom code time_days as 0 if the discrepancy is within 2 weeks. Otherwise, let's drop as possible entry error
gen time_days_orig=time_days

replace time_days=0 if time_days>-15 & time_days<=0


replace drop=1 if time_days<-14
replace dropreason = "negative # days between index adv/met diagnosis date and first day of line 1 therapy, > 14 day difference" if  time_days<-14 & missing(dropreason)
gen drop_neg=1 if time_days<-14
label var drop_neg "Drop reason: negative # days between index adv/met diagnosis date and first day of line 1 therapy, > 14 day difference"

replace time_days=. if time_days<-14 
ta time_days_orig time_days if time_days_orig<0, missing
label var time_days_orig "Cont Diff. adv/met dx & tx start, Original"
label var time_days "Cont Diff. adv/met dx & tx start, >=-14 bottom coded at 0"

*Reminder: we'll need to decide how to top code time_days as well - I imagine high outliers might be entry errors etc.
tabstat time_days, statistics(n min p10 p25 p50 p75 p90 max)

*Adamson: "Sensitivity analyses were performed excluding patients with first-line systemic therapy documented as starting at least 1 year after diagnosis"
*What's with the really high numbers? i.e. folks who didn't get treated within the year?
ta cohort if time_days>365 & !missing(time_days), missing /*Interesting - lots of prostate - I wonder if some of these folks are "watch and wait"? */
ta agegrp if time_days>365 & !missing(time_days), missing /*I thought maybe it could skew super elderly where folks choose not to treat. Can't tell - would need to look at these #s vs. distribution of ages in general */
ta groupstage if time_days>365 & !missing(time_days), missing /*Not seeing a clear stage pattern - possibly lots of unknown etc. - implies people seeing care elsewhere perhaps?*/

*Flag really high #s for possible exclusion
gen drop_time_days_1yrpls=0
replace drop_time_days_1yrpls=1 if time_days>365 & !missing(time_days)
label var drop_time_days_1yrpls "Flag: Treatment start # days>365 days"


*Adamson timeliness = tx within 30 days. Let's try 14 and 60 day windows too
*Note: be careful at analysis stage - everyone including folks not treated is currently 0. We're going to rely on sample exclusions to take care of this.
gen timely30=.
replace timely30=0 if time_days>30 & !missing(time_days) 
replace timely30=1 if time_days>=0 & time_days<=30
label var timely30 "Tx initiation within 30 days of adv/met dx"

gen timely14=.
replace timely14=0 if time_days>14 & !missing(time_days) 
replace timely14=1 if time_days>=0 &time_days<=14
label var timely14 "Tx initiation within 14 days of adv/met dx"

gen timely60=.
replace timely60=0 if time_days>60 & !missing(time_days) 
replace timely60=1 if time_days>=0 & time_days<=60
label var timely60 "Tx initiation within 60 days of adv/met dx"

*check
bysort timely30: tabstat time_days, statistics(n mean min max)
bysort timely14: tabstat time_days, statistics(n mean min max)
bysort timely60: tabstat time_days, statistics(n mean min max)

*************************
*Let's look at Stage. Adamson drops initial stage 0 dx

*Codebook says "groupstage" should be stage at time of initial dx
ta groupstage, missing

replace drop=1 if groupstage=="0"
replace dropreason="Initial stage 0 dx" if groupstage=="0" & missing(dropreason)
gen drop_stage0=1 if groupstage=="0"
label var drop_stage0 "Drop reason: Initial stage 0 dx"


*************************
*Mortality
gen died=0
replace died=1 if !missing(dateofdeath)
label var died "Record of death?"
ta died

*Adamson: exclude people who died within 30 days
*Death date looks like year month only - so can't be quite precise with "30 days" exclusion.
gen actualdate=date(dateofdeath,"YM")
format actualdate %tdnn/dd/CCYY
gen deathyear=year(actualdate)
gen deathmonth=month(actualdate)
*check
ta deathyear deathmonth, missing
listsome deathyear deathmonth dateofdeath, random max(5)
drop actualdate


*Aaron Cohen recommends considering death by the next month after diagnosis in defining death in the first 30 days. If we do same month only it's only 2 people.
*Make sequential year month for index date and death date, with no gaps. ym #s for index & death months should be on the same year/month measuring stick
egen ym_index=group(indexyear indexmonth)

gen ym_death=.
local y =2011
local ym=1

while `y' < 2024 {
	local m = 1
	while `m'<13 {
		display "`y' `m' `ym'"
		replace ym_death=`ym' if deathyear==`y' & deathmonth==`m'
		local ym=`ym'+1
	local m=`m'+1
	}
	
	local y=`y'+1
}

listsome ym_index indexyear indexmonth ym_death deathyear deathmonth if died==1, random

li if ym_death<ym_index & !missing(ym_death) & !missing(ym_index)

gen died30=0
replace died30=1 if (ym_death-ym_index==1)|(ym_death-ym_index==0)
ta died30, missing
listsome patientid cohort birthyear diagnosisdate advanceddiagnosisdate metdiagnosisdate dateofdeath if died30==1, random

replace drop=1 if died30==1
replace dropreason="Died within month of adv/met dx date" if died30==1 & missing(dropreason)
rename died30  drop_died30
label var drop_died30 "Drop reason: Died within month of adv/met dx date"

*************************
**Race/ethnicity: OK - quite a bit missing. Weirdly, Hispanic shows up both under race and ethnicity and sometimes conflicts. Logic-wise, going with any Hispanic anywhere=Hispanic
ta race ethnicity, missing
*Mutually exclusive category version of race/ethnicity
gen raceeth=.
replace raceeth=1 if ethnicity =="Hispanic or Latino"| race=="Hispanic or Latino" /*Hispanic*/
replace raceeth=2 if missing(raceeth) & race=="White" /*White*/
replace raceeth=3 if missing(raceeth) & race=="Black or African American" /*Black*/
replace raceeth=4 if missing(raceeth) & (race=="Other Race"|race=="Asian") /*Other*/
replace raceeth=5 if missing(raceeth) & race=="" /*Missing*/
label define raceeth 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Other" 5 "Missing race"
label values raceeth raceeth

*check - OK looks good
ta raceeth, missing
foreach x in race ethnicity {
	ta `x' raceeth, missing
}
label var raceeth "Race/Ethnicity"

*************************
*SES - quite a bit missing but it seems distributed throughout geographies and cancers, though perhaps Michigan looks a little extra high with missings
ta sesindex2015_2019, missing
ta cohort if missing(sesindex2015_2019)
ta state if missing(sesindex2015_2019)

*Let's make a version of SES that allows for missing so they don't drop if added to the model
gen sesindex_m=1 if sesindex2015_2019=="1 - Lowest SES"
replace sesindex_m=2 if sesindex2015_2019=="2"
replace sesindex_m=3 if sesindex2015_2019=="3"
replace sesindex_m=4 if sesindex2015_2019=="4"
replace sesindex_m=5 if sesindex2015_2019=="5 - Highest SES"
replace sesindex_m=999 if missing(sesindex2015_2019)
label define sesindex_m 1 "1 - Lowest SES" 5 "5 - Highest SES" 999 "Missing SES Index"
label values sesindex_m sesindex_m
label var sesindex_m "SES Index 2015-2019, missing cat included"

*check
ta sesindex_m sesindex2015_2019, missing

save "all_merged.dta", replace


*************************
/*Do 90 day encounter program to ID those who might've gotten care elsewhere. This needs to be run in Hellbender using a script*/
do "${labpath}/Flatiron/Data/Serena/1b.VisitsMeds_2024.05.06b.do"

use "all_merged.dta", clear
merge 1:1 patientid cohort using "gotcare90days.dta"
drop _merge
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                        36,521
        from master                    36,521  (_merge==1)
        from using                          0  (_merge==2)

    Matched                           244,730  (_merge==3)
    -----------------------------------------
*/

*Check - who has activity in last 90 days?
set linesize 255
listsome patientid diagnosisdate advanceddiagnosisdate metdiagnosisdate  indexdate l1startdate visitdate orderdate labdate vitdate administereddate drugdate include_vis include_medord include_lab include_vitals include_medadm include_drug if include_tot==1, random
*listsome patientid diagnosisdate advanceddiagnosisdate metdiagnosisdate  indexdate l1startdate visitdate orderdate labdate vitdate administereddate drugdate include_vis include_medord include_lab include_vitals include_medadm include_drug if missing(l1startdate) & include_tot==1, random
*Check - who does not have activity in last 90 days?
listsome patientid diagnosisdate advanceddiagnosisdate metdiagnosisdate  indexdate l1startdate visitdate orderdate labdate vitdate administereddate drugdate include_vis include_medord include_lab include_vitals include_medadm include_drug if include_tot==., random


label var visitdate "1st visit date within 90 days of index"
label var diff_vis "Visit date-index date (earliest within 90 days)"
label var include_vis "Visit within 90 days of index?"
label var orderdate "1st order date within 90 days of index"
label var diff_medord "Med order date-index date (earliest within 90 days)"
label var include_medord "Med order within 90 days of index?"
label var labdate  "1st lab date within 90 days of index"
label var diff_lab "Lab date-index date (earliest within 90 days)"
label var include_lab "Lab within 90 days of index?"
label var vitdate "1st vitals date within 90 days of index"
label var diff_vitals "Vitals date-index date (earliest within 90 days)"
label var include_vitals "Vitals within 90 days of index?"
label var administereddate "1st med admin date within 90 days of index"
label var diff_medadm  "Med admin date-index date (earliest within 90 days)"
label var include_medadm "Med admin within 90 days of index?"
label var drugdate "1st drug date within 90 days of index"
label var diff_drug "Drug date-index date (earliest within 90 days)"
label var include_drug "Drug within 90 days of index?"

gen drop_90d=1 if missing(include_tot)
ta drop_90d include_tot, missing
label var drop_90d "Drop reason: no activity within 90 days of index"

save "all_merged.dta", replace

*************************
*Let's grab the insurance status at time of diagnosis

use "CRC_ins.dta", clear
append using "RCC_ins.dta"
append using "Pancreatic_ins.dta"
append using "NSCLC_ins.dta"
append using "MetProstate_ins.dta"
append using "MetastaticBreast_ins.dta"
append using "Melanoma_ins.dta"
append using "HeadNeck_ins.dta"
append using "Gastric_ins.dta"
append using "Bladder_ins.dta"

merge m:1 patientid cohort using "all_merged.dta", keepusing(indexdate agedx cohort)

ta cohort if _merge==2 /*I'm guessing these folks are just missing insurance info - they're in the patient file but don't have observations in the insurance files  */
desc startdate enddate indexdate

gen startdate1=date(startdate, "YMD")
format startdate1 %tdnn/dd/CCYY

gen enddate1=date(enddate, "YMD")
format enddate1 %tdnn/dd/CCYY

/*There are also obvious typos for some dates. Let's make those problem dates missing*/
gen yearstartd=year(startdate1)
gen yearendd=year(enddate1)
ta yearstartd, missing
ta yearendd, missing

gen yearindex=year(indexdate)
gen birthyear=yearindex-agedx
set linesize 255
listsome patientid startdate1 enddate1 agedx indexdate birthyear  ismedicareadv ismedicaresupp ispartaonly ispartbonly ispartaandpartb ispartdonly ismanagedgovtplan ismanagedmedicaid ismedicaremedicaid if birthyear>yearstartd, random
replace startdate1=. if birthyear>yearstartd & !missing(birthyear) /*you cant have insurance start before you were born*/
replace enddate1=. if birthyear>yearendd& !missing(birthyear) /*you cant have insurance end before you were born*/
replace startdate1=. if yearstartd>2023 & !missing(yearstartd)  /*you cant have insurance start in the future*/
replace enddate1=. if yearendd>2025 & !missing(yearendd) /*people possibly know if their insurance will end in a year or 2? so giving some leeway. But probably the values way into the future are wrong*/

*Weirdly some end dates are before some start dates. Only a couple thousand. These look fairly close usually? I'll trust the startdate over the end date because end date is more missing and iffy
listsome startdate1 enddate1 if startdate1>enddate1 &!missing(startdate1) & !missing(enddate1), random 
replace enddate1=. if startdate1>enddate1 &!missing(startdate1) & !missing(enddate1)


*We have both missing start and end dates. Missing start dates are more problematic but less common than missing end dates. 
ta cohort if missing(startdate1) & _merge==3, missing
ta cohort if missing(enddate1) & _merge==3, missing


/*Insurance is so messy. Let's  try a few different versions. There are also obvious typos for some dates.
 
1) Main: diagnosis date is between start & end dates, or after start with no end, or before end with no start. Some leeway - if the insurance start date is within a couple weeks of the index date we accept that (could be that it was documented a little late)
2) Liberal: Any of the insurance type and ignore dates?
3) Conservative: diagnosis date is between start & end dates. Must have start date. If no end date, must be within 1 month of start date.

*/
/*Incl1 = Main*/
*Aaron thinks it's reasonable to consider insurances with missing start dates as being current as long as our index date isn't after its end date
gen incl1=0
*If we have both start & end dates: include only if index date is between start & end dates
replace incl1=1 if indexdate>=startdate1-14 & indexdate<enddate1 & !missing(startdate1) & !missing(enddate1) & !missing(indexdate) 

*If we only have start: include if index is after start, don't consider end
replace incl1=1 if indexdate>=startdate1 & !missing(startdate1) & missing(enddate1) & !missing(indexdate) 

*If we only have end: include if index is before end date, don't consider start
replace incl1=1 if indexdate<enddate1 & missing(startdate1) & !missing(enddate1) & !missing(indexdate)  /*incl1ude if diagnosis is before the insurance stops*/

ta incl1, missing

*check - looks good
set linesize 255
listsome patientid startdate enddate indexdate payercategory if incl1==1,random
listsome patientid startdate enddate indexdate payercategory if incl1==0,random

/*Incl2 = Liberal*/
*Don't need an indicator there - taking it all

/*Incl3 = Conservative: MUST have a start date */
gen incl3=0
*If we have both start & end dates: include only if index date is between start & end dates
replace incl3=1 if indexdate>=startdate1 & indexdate<enddate1 & !missing(startdate1) & !missing(enddate1) & !missing(indexdate) 

*If we only have start: include if index is after start, don't consider end
replace incl3=1 if indexdate>=startdate1 & indexdate<startdate1+31 & !missing(startdate1) & missing(enddate1) & !missing(indexdate) 

ta incl3, missing

/*Inclf= first insurance type recorded, regardless of anything else*/
*Make a hierarchy of payers - will do mostly by N, but deprioritizing "other" since we can't do much with that
gen inscat=1 if payercategory=="Commercial Health Plan"
replace inscat=2 if payercategory=="Medicare"
replace inscat=3 if payercategory=="Medicaid"
replace inscat=4 if payercategory=="Patient Assistance Program"
replace inscat=5 if payercategory=="Self Pay"
replace inscat=6 if payercategory=="Workers Compensation"
replace inscat=7 if payercategory=="Other Government Program"
replace inscat=8 if payercategory=="Other Payer - Type Unknown"

sort patientid startdate inscat
gen inclf=0
sort patientid startdate inscat
replace inclf=1 if patientid!=patientid[_n-1] /*Grab first insurance for each pt*/
order patientid payercategory startdate enddate incl1 incl3 inclf


*check - looks good
set linesize 255
listsome patientid startdate enddate indexdate payercategory agedx if incl3==1,random
listsome patientid startdate enddate indexdate payercategory agedx if incl3==0,random

save initialins.dta, replace


foreach version in 1 3 {
	if "`version'"=="1" {
		local max=6
		local needthis ""
		local needthis1  ""
		local needthis2  ""
	}
	else {
		local max=5
		local needthis  "gen ins_payercategory6="""
		local needthis1  "gen ins_startdate6 =."
		local needthis2  "gen ins_enddate6 =."
	}

use initialins.dta, clear
*The only relevant observations are those where the index date is within the start/end dates of the insurance period
keep if incl`version'==1

ta payercategory, missing

keep patientid payercategory  cohort startdate1 enddate1 indexdate
rename startdate1 startdate
rename enddate1 enddate
rename * ins_*
rename ins_patientid patientid 
rename ins_cohort cohort
label var ins_startdate "Insurance start date"
label var ins_enddate "Insurance end date"

*Some observations contain identical info. Maybe they're multiple types of private insurance or something or there's some other legit reason? But either way, we don't get the detail and they're effectively just duplicates, so drop.
duplicates report
duplicates drop
*Example of someone who essentially has a lot of duplicates.
li  if patientid=="FFFF0C7AEB80D"

*Let's only keep the 1st obs for each insurance type for each person/cohort. IT shouldn't really matter which sicne everyone in this sample is included as being relevant to the current dx
duplicates report patientid cohort ins_payercategory
duplicates drop patientid cohort ins_payercategory, force

*now it looks like peoplecan have up to 6 types of insurance for a relevant period
duplicates report patientid cohort

*We need to make this wide to accommodate multiple insurance types
gen str idcoh=patientid+"_"+cohort
egen num=seq(), by(patientid cohort) from(1) to (`max')
reshape wide ins_startdate ins_enddate ins_payercategory , i(idcoh) j(num)
drop idcoh


foreach var of varlist ins_startdate* {
	local num=substr("`var'", -1,.)
		label var `var' "Insurance start date (type `num')"
}
foreach var of varlist ins_enddate* {
	local num=substr("`var'", -1,.)
		label var `var' "Insurance end date (type `num')"
}
foreach var of varlist ins_payercategory* {
	local num=substr("`var'", -1,.)
		label var `var' "Insurance type (type `num')"
}

`needthis'
`needthis1'
`needthis2'

foreach instype in priv mcare mcaid othgov othunk assist self workcomp {
	*Make indicators for each type of insurance
	gen ins_`instype'`version'=0
	
	if "`instype'"=="priv" {
			local text="Commercial Health Plan"
	}
	else if "`instype'"=="mcare" {
			local text="Medicare"
	}
	else if "`instype'"=="mcaid" {
			local text="Medicaid"
	}
	else if "`instype'"=="othgov" {
			local text="Other Government Program"
	}
	else if "`instype'"=="othunk" {
			local text="Other Payer - Type Unknown"
	}
	else if "`instype'"=="assist" {
			local text="Patient Assistance Program"
	}
	else if "`instype'"=="self" {
			local text="Self Pay"
	}
	else  {
			local text="Workers Compensation"
	}

	display "`instype' `version'"
replace ins_`instype'`version'=1  if (inlist(ins_payercategory1,"`text'")| inlist(ins_payercategory2 ,"`text'")| inlist(ins_payercategory3,"`text'")| inlist( ins_payercategory4 ,"`text'")| inlist(ins_payercategory5,"`text'")| inlist( ins_payercategory6,"`text'"))

label var ins_`instype'`version' "`text' (v`version')"

gen ins_`instype'`version'_start=.
gen ins_`instype'`version'_end=.

label var ins_`instype'`version'_start "Start date: `text' (v`version')"
label var ins_`instype'`version'_end "End date: `text' (v`version')"

local num 1
while `num'<7 {
	replace ins_`instype'`version'_start=ins_startdate`num' if ins_payercategory`num'=="`text'"
	replace ins_`instype'`version'_end=ins_enddate`num' if ins_payercategory`num'=="`text'"
	local num=`num'+1
}

}



*Check
set linesize 255
listsome patientid cohort ins_payercategory1 ins_payercategory2 ins_payercategory3 ins_payercategory4 ins_payercategory5 ins_payercategory6 ins_priv`version' ins_mcare`version' ins_mcaid`version' ins_othgov`version' ins_othunk`version' ins_assist`version' ins_self`version' ins_workcomp`version', random

drop ins_payercategory1 ins_startdate1 ins_enddate1 ins_payercategory2 ins_startdate2 ins_enddate2 ins_payercategory3 ins_startdate3 ins_enddate3 ins_payercategory4 ins_startdate4 ins_enddate4 ins_payercategory5 ins_startdate5 ins_enddate5 ins_payercategory6 ins_startdate6 ins_enddate6

save ins`version'.dta, replace
}

*Do this step again for the "first" version of the variable
use initialins.dta, clear
*The only relevant observations are those where the index date is within the start/end dates of the insurance period
keep if inclf==1

ta payercategory, missing

keep patientid payercategory  cohort startdate1 enddate1 indexdate
rename startdate1 startdate
rename enddate1 enddate
rename * ins_*
rename ins_patientid patientid 
rename ins_cohort cohort
label var ins_startdate "Insurance start date"
label var ins_enddate "Insurance end date"

*shouldnt have duplicates anyway
duplicates drop

rename ins_payercategory ins_payercategory1 
rename ins_startdate ins_startdate1 
rename ins_enddate ins_enddate1


foreach instype in priv mcare mcaid othgov othunk assist self workcomp {
	*Make indicators for each type of insurance
	gen ins_`instype'f=0
	
	if "`instype'"=="priv" {
			local text="Commercial Health Plan"
	}
	else if "`instype'"=="mcare" {
			local text="Medicare"
	}
	else if "`instype'"=="mcaid" {
			local text="Medicaid"
	}
	else if "`instype'"=="othgov" {
			local text="Other Government Program"
	}
	else if "`instype'"=="othunk" {
			local text="Other Payer - Type Unknown"
	}
	else if "`instype'"=="assist" {
			local text="Patient Assistance Program"
	}
	else if "`instype'"=="self" {
			local text="Self Pay"
	}
	else  {
			local text="Workers Compensation"
	}

	display "`instype' f"
replace ins_`instype'f=1  if inlist(ins_payercategory1,"`text'")
label var ins_`instype'f "`text' (1st)"

gen ins_`instype'f_start=.
gen ins_`instype'f_end=.

label var ins_`instype'f_start "Start date: `text' (1st)"
label var ins_`instype'f_end "End date: `text' (1st)"


replace ins_`instype'f_start=ins_startdate1 if ins_payercategory1=="`text'"
replace ins_`instype'f_end=ins_enddate1 if ins_payercategory1=="`text'"

}
foreach x in ins_indexdate ins_startdate1 ins_enddate1 ins_privf_start ins_privf_end ins_mcaref_start ins_mcaref_end ins_mcaidf_start ins_mcaidf_end ins_othgovf_start ins_othgovf_end ins_othunkf_start ins_othunkf_end ins_assistf_start ins_assistf_end ins_selff_start ins_selff_end ins_workcompf_start ins_workcompf_end {
	format `x' %tdnn/dd/CCYY
}


drop ins_payercategory1 ins_startdate1 ins_enddate1 

save insf.dta, replace


use "all_merged.dta"
merge 1:1 patientid cohort using "ins1.dta"
ta _merge
drop _merge
merge 1:1 patientid cohort using "ins3.dta"
ta _merge
drop _merge
merge 1:1 patientid cohort using "insf.dta"
ta _merge
drop _merge


*************************************
*Clean up everything
foreach var of varlist primarysite groupstage isprimarysurgery primarysurgerydate surgery surgerydate {
	rename `var' clin_`var'
}
foreach var of varlist visitdate diff_vis include_vis orderdate diff_medord include_medord labdate diff_lab include_lab vitdate diff_vitals include_vitals administereddate diff_medadm include_medadm drugdate diff_drug include_drug include_tot {
	rename `var' d90_`var'
}
foreach var of varlist agedx agegrp raceeth  birthyear gender race ethnicity {
	rename `var' demo_`var'
}


*enhancedcohort isn't quite right missing values - let's also clean up cohort
rename cohort cohortdesc
gen cohort=.
replace cohort=1 if cohortdesc=="Advanced non-small cell lung cancer"
replace cohort=2 if cohortdesc=="Metastatic colorectal"
replace cohort=3 if cohortdesc=="Metastatic breast"
replace cohort=4 if cohortdesc=="Metastatic prostate"
replace cohort=5 if cohortdesc=="Advanced melanoma"
replace cohort=6 if cohortdesc=="Metastatic pancreatic"
replace cohort=7 if cohortdesc=="Advanced gastric"
replace cohort=8 if cohortdesc=="Metastatic renal"
replace cohort=9 if cohortdesc=="Advanced urothelial carcinoma"
replace cohort=10 if cohortdesc=="Advanced head and neck"

labmask cohort, values(cohortdesc)

drop enhancedcohort cohortdesc
drop startdate
label var cohort "Cohort (cancer type)"
label var diagnosisdate "Initial dx date"
label var advanceddiagnosisdate "Adv dx date"
label var dateofdeath "Date of death"
label var metdiagnosisdate "Met dx date"

*Fill in drops reasons in a hierarchy, in the same order as Adamson (overwriting what I did before)
replace drop=1 if  drop_terr==1| drop_nogeo==1| drop_noindex==1| drop_young==1| drop_nol1date==1| drop_neg==1| drop_time_days_1yrpls==1| drop_stage0==1| drop_died30==1| drop_90d==1
replace dropreason="" 
replace dropreason="Missing state information" if drop_nogeo==1 & missing(dropreason)
replace dropreason="Exclude Puerto Rico" if drop_terr==1 & missing(dropreason)
replace dropreason="Under age 18" if drop_young==1 & missing(dropreason)
replace dropreason="Initial stage 0 dx" if drop_stage0==1 & missing(dropreason)
replace dropreason="Missing adv/met diagnosis date" if drop_noindex==1 & missing(dropreason)
replace dropreason="Died within month of adv/met dx date" if drop_died30==1 & missing(dropreason)
replace dropreason="No line 1 start date recorded" if drop_nol1date==1 & missing(dropreason)
replace dropreason="negative # days between index adv/met diagnosis date and first day of line 1 therapy, > 14 day difference" if drop_neg==1 & missing(dropreason)
replace dropreason="No activity within 90 days of index" if drop_90d==1 & missing(dropreason)
replace dropreason="Tx start # days>365 days" if drop_time_days_1yrpls==1 & missing(dropreason)

*Don't include 90 day inactivity or 1 year plus line 1 start in this version
gen maindrop =0
replace maindrop=1 if drop_terr==1| drop_nogeo==1| drop_noindex==1| drop_young==1| drop_nol1date==1| drop_neg==1|drop_stage0==1| drop_died30==1

ta dropreason demo_agegrp, missing
label var maindrop "Drop - for main analysis"

*Fix up time variables to get ready for merges
gen year=indexyear
gen month=indexmonth
label var year "Index year of Adv/Met DX"
label var month "Index month of Adv/Met DX"
gen yearmonth=""
replace yearmonth=string(year, "%04.0f") + string(month, "%02.0f")
replace yearmonth="" if yearmonth==".."
destring yearmonth, replace
label var yearmonth "Index year/month"

*make race dummies
ta demo_raceeth, missing gen(raceeth_)

**********************************
/*Make demo variables mergeable for NHIS group rates*/
gen female=0 if demo_gender=="M"
replace female=1 if demo_gender=="F"

*Actually let's also fix gender so that it's not missing
gen demo_female=female
replace demo_female=2 if missing(female)
label var demo_female "Female?"
label define demo_female 0 "Male" 1 "Female" 2 "Missing"
label values demo_female demo_female


gen raceeth=.
replace raceeth=1 if demo_raceeth==1 /*Hispanic*/
replace raceeth=2 if demo_raceeth==2 /*White*/
replace raceeth=3 if demo_raceeth==3 /*Black*/
replace raceeth=4 if demo_raceeth==4 /*Other*/
label define raceeth1 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Other" 
label values raceeth raceeth1


/*Maybe insurance is not good to merge on - missing too many probably
*Make a single insurance variable for Age 18-64 only - to match the NHIS insurance variable to get PSL rates for groups.
*Hierarchy: Private > Medicaid> Other> Uninsured (because these groups are not mutually exclusive)
gen insurance=.
replace insurance=2 if demo_agedx>17 & demo_agedx<65 & (ins_priv==1) /*Private - assume primary overwriting everything else*/
replace insurance=1 if demo_agedx>17 & demo_agedx<65 & (ins_mcaid==1) & missing(insurance) /*Medicaid*/
replace insurance=3 if demo_agedx>17 & demo_agedx<65 & (ins_mcare==1| ins_othgov==1| ins_othunk==1| ins_workcomp==1) & missing(insurance) /*Other*/
replace insurance=0 if demo_agedx>17 & demo_agedx<65 & (ins_self==1| ins_assist==1) & missing(insurance) /*Uninsured: "Self Pay" "Patient Assistance Program" - as long as no other thing is selected*/

label define insurance 0 "Uninsured" 1 "Medicaid" 2 "Private" 3 "Other"
label values insurance insurance
label var insurance "NHIS Insurance groups used for merging"
listsome patientid cohort ins_payercategory1 ins_payercategory2 ins_payercategory3 ins_payercategory4 ins_payercategory5 ins_payercategory6  ins_priv ins_mcare ins_mcaid ins_othgov ins_othunk ins_assist ins_self ins_workcomp if missing(insurance) & demo_agedx<65, random
*/

gen agegrp=.
replace agegrp=1 if demo_agedx>17 & demo_agedx<35
replace agegrp=2 if demo_agedx>34 & demo_agedx<45
replace agegrp=3 if demo_agedx>44 & demo_agedx<55
replace agegrp=4 if demo_agedx>54 & demo_agedx<65
label define agegrpnhis  1 "18-34" 2 "35-44" 3 "45-54" 4 "55-64"
label values agegrp agegrpnhis
label var agegrp "NHIS Age groups used for merging"
ta demo_agedx agegrp, missing


**********************************
/*Indicator for advanced/met dx date = initial diagnosis date*/

gen diagnosisdate1=date(diagnosisdate, "YMD")
format diagnosisdate1 %tdnn/dd/CCYY
gen diagnosisyear=year(diagnosisdate1)
gen diagnosismonth=month(diagnosisdate1)
drop diagnosisdate
rename diagnosisdate1 diagnosisdate

gen samedate=.
replace samedate=1 if diagnosisdate==indexdate
*Accept also if diagnosis date is within a month of index date
replace samedate=1 if diagnosisdate+30>=indexdate &  diagnosisdate<=indexdate & !missing(diagnosisdate) & !missing(indexdate)
label var samedate "Adv/Met dx date within 30 days of Initial dx"

order patientid cohort state demo* diagnosisdate advanceddiagnosisdate metdiagnosisdate indexdate indexyear indexmonth l1startdate linename linenumber l1year l1month time_days time_days_orig timely30 timely14 timely60 died dateofdeath deathyear deathmonth  sesindex2015_2019 sesindex_m ins* d90* clin* drop* 

*Make some dummies
ta cohort, gen(cohort_)
label var cohort_1 "Advanced non-small cell lung cancer"
label var cohort_2 "Metastatic colorectal"
label var cohort_3 "Metastatic breast"
label var cohort_4 "Metastatic prostate"
label var cohort_5 "Advanced melanoma"
label var cohort_6 "Metastatic pancreatic"
label var cohort_7 "Advanced gastric"
label var cohort_8 "Metastatic renal"
label var cohort_9 "Advanced urothelial carcinoma"
label var cohort_10 "Advanced head and neck"


*ta demo_raceeth, missing gen(raceeth_)
ta sesindex_m, missing gen(sesindex_)


numlabel, add

save "${labpath}/Flatiron/Data/Serena/all_merged_${today}d.dta", replace

/*
*Let's make a smaller file. Some cancers have their own specific variables and we don't need them.
keep   patientid cohort state demo_birthyear demo_gender demo_race demo_ethnicity demo_agedx demo_agegrp demo_raceeth diagnosisdate advanceddiagnosisdate metdiagnosisdate indexdate indexyear indexmonth l1startdate linename linenumber time_days time_days_orig timely30 timely14 timely60 died dateofdeath  sesindex2015_2019 sesindex_m ins_payercategory1 ins_startdate1 ins_enddate1 ins_payercategory2 ins_startdate2 ins_enddate2 ins_payercategory3 ins_startdate3 ins_enddate3 ins_payercategory4 ins_startdate4 ins_enddate4 ins_payercategory5 ins_startdate5 ins_enddate5 ins_payercategory6 ins_startdate6 ins_enddate6 d90_visitdate d90_diff_vis d90_include_vis d90_orderdate d90_diff_medord d90_include_medord d90_labdate d90_diff_lab d90_include_lab d90_vitdate d90_diff_vitals d90_include_vitals d90_administereddate d90_diff_medadm d90_include_medadm d90_drugdate d90_diff_drug d90_include_drug d90_include_tot clin_primarysite clin_groupstage clin_surgery clin_surgerydate clin_isprimarysurgery clin_primarysurgerydate drop dropreason drop_terr drop_nogeo drop_noindex drop_young drop_nol1date drop_neg drop_time_days_1yrpls drop_stage0 drop_died30 drop_90d  multobs maindrop

order patientid cohort state demo* diagnosisdate advanceddiagnosisdate metdiagnosisdate indexdate indexyear indexmonth l1startdate linename linenumber time_days time_days_orig timely30 timely14 timely60 died dateofdeath sesindex2015_2019 sesindex_m ins* d90* clin* drop* 
compress
save "${labpath}/Flatiron/Data/Serena/all_merged_trim_${today}.dta", replace
*/


log close




/*

**********************************
/*Let's play around with possibilities of other treatment modalities
These have SURGERY: Pancreatic, gastric, head & neck, urothelial, prostate, renal, melanoma (7)
No surgery for NSCLC, Breast, CRC
Head & neck and Prostate have radiation too.
We can make a measure for: 1) time to surgery, 2) time to radiation, 3) time to surgery or systemic, 4) time to literally any tx with data available
*/
*Read in prostate tx data
use "${path}/MetProstate/Enhanced_MetPC_PrimaryTreatment.dta", clear
foreach x of varlist _all  {
	rename `x' prost_`=lower("`x'")'
}
gen cohort=4
rename prost_patientid patientid
*really just 1 entry per person
duplicates report patientid

*Can't have missing treatment date. 
drop if missing( prost_treatmentdate)

save prostatetx.dta, replace

*Read in gastric tx data
use "${path}/Gastric/Enhanced_AdvGESurgery.dta", clear
foreach x of varlist _all  {
	rename `x' gast_`=lower("`x'")'
}
gen cohort=7
rename gast_patientid patientid
*Keep the first surgery only - duplicate IDs are all secondary
drop if gast_resectionsetting=="Secondary"

*Drop if missing resection date - we can do anyhting if we don't have a date
drop if missing( gast_resectiondate)

save gastrictx.dta, replace


*Read in melanoma tx data
use "${path}/Melanoma/Enhanced_AdvMelanomaProcedures.dta", clear
foreach x of varlist _all  {
	rename `x' mel_`=lower("`x'")'
}
gen cohort=5
rename mel_patientid patientid
drop if missing( mel_proceduredate)
*There's a lot of duplicates for each person
duplicates report patientid

*I consider biopsy to be diagnostic and not curative
drop if regexm(mel_proceduretype, "Biopsy")
ta mel_proceduretype, missing

*Keep first obs only
sort patientid mel_proceduredate
drop if patientid==patientid[_n-1]

save meltx.dta, replace



*Merge

use "${labpath}/Flatiron/Data/Serena/merged_pol_${today}.dta", clear
merge 1:1 patientid cohort using "prostatetx.dta"
drop _merge
merge 1:1 patientid cohort using "gastrictx.dta"
drop _merge
merge 1:1 patientid cohort using "meltx.dta"
drop _merge

*Let's look at the original surgical variables
foreach x in  clin_surgery clin_surgerydate clin_isprimarysurgery clin_primarysurgerydate surgerytype issurgery nephrectomydate  prost_treatmenttype prost_treatmentdate gast_resectiontype gast_resectiondate gast_resectionsetting mel_proceduredate mel_proceduretype {
	display "`x'"
	ta cohort if !missing(`x')
}

foreach d in clin_surgerydate clin_primarysurgerydate nephrectomydate prost_treatmentdate gast_resectiondate mel_proceduredate {
	gen `d'1=date(`d', "YMD")
	format `d'1 %tdnn/dd/CCYY
}

*Most people should really just have 1 date if they had any surgery, but either way, let's consolidate into a single date variable and pick the earliest one
egen surgerydate=rowmin( clin_surgerydate1 clin_primarysurgerydate1 nephrectomydate1 prost_treatmentdate1 gast_resectiondate1 mel_proceduredate1)
format surgerydate %tdnn/dd/CCYY
listsome patientid cohort surgerydate clin_surgerydate1 clin_primarysurgerydate1 nephrectomydate1 prost_treatmentdate1 gast_resectiondate1 mel_proceduredate1 if !missing(surgerydate), random
listsome patientid cohort indexdate surgerydate l1startdate linename clin_surgery surgerytype prost_treatmenttype gast_resectiontype mel_proceduretype if !missing(surgerydate), random
label var surgerydate "Date of first surgery"

*Are there cases where surgery is before met/adv diagnosis? Yes, most. Bah we probably can't use these then. Unless we look at original DX date and surgery.
ta cohort if surgerydate<indexdate & !missing(surgerydate) & !missing(indexdate)
ta cohort if surgerydate<l1startdate & !missing(surgerydate) & !missing(l1startdate)
ta cohort if !missing(surgerydate)
*/


/*
log using "quick.log"
global indivctrls demo_agedx i.demo_raceeth

foreach indiv in "" "${indivctrls}" {
foreach tx in "i.psl_40" "psl_percentstate" "i.psl_any" "i.psl_state" {
foreach out in timely14 timely30 timely60 time_days{
areg `out' `tx' i.yearmonth `indiv' if drop==0 , absorb(state) cluster(state)
}
}
}
log close




























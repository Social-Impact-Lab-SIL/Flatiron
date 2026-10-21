/*This program sets up the state-month level policy control merge files for Flatiron
*/
/*
/*Use this when using Windows-mounted*/
cd "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Serena\working"
global path "\\vast.rde.missouri.edu\mp94p-lab\reusable_files"
global labpath "\\vast.rde.missouri.edu\mp94p-lab\"
sysdir set PLUS "\\vast.rde.missouri.edu\mp94p-lab\StataUserPackages"
*/

/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global path "/cluster/VAST/mp94p-lab/reusable_files"
global labpath "/cluster/VAST/mp94p-lab/"

sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"
sysdir set PERSONAL "/cluster/VAST/mp94p-lab/StataUserPackages"



global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")
log using "policysetup_${today}d.log", replace

***********************************
/*Indicator of whether there are state-level paid family & medical insurance laws in a given quarter. Data source is National Partnership for Women & Families: https://nationalpartnership.org/wp-content/uploads/2023/02/state-paid-family-leave-laws.pdf */
import excel "${labpath}/Flatiron/Data/Original/Controls/FMLI.xlsx", sheet("Sheet1") firstrow clear
drop Source
save "fmli.dta", replace

***********************************
/*NHIS
We want to get group specific rates of PSL by: 1) age/sex, 2) age/sex/race 3) age/sex/insurance 4) age/ sex/ race/ insurance for baseline year 2011. Age group: 18-34,35-44,45-54, 55-64
Paid sick leave NHIS details:
* https://nhis.ipums.org/nhis-action/variables/PAIDSICK#universe_section
* 2011-2018: Sample adults aged 18+ years who were working last week, or who were with a job or business but not at work, or who were working, but not for pay, at a family-owned job or business, or who have ever worked.
Instrument Variable Name: PDSICK
QuestionText:
[If DOINGLW2 eq (1,2,4)] Do you have paid sick leave on this MAIN job or business? [Else if EVERWRK eq (1) and [WHYNOWK2 eq 03 or AGE ge 65] Did you ever have paid sick leave on the job you held the longest?[Else if EVERWRK eq (1) and WHYNOWK2 ne 03 and AGE lt 65] Did you ever have paid sick leave on the job you held most recently?
1 Yes
2 No
7 Refused
9 Don't know
UniverseText: Sample adults 18+ who were working last week, or who were with a job or business but not at work, or who were working but not for pay at a family-owned job or business, or who have ever worked

IPUMS says use sampweight

Insurance types in the Flatiron data are: commercial, medicaid, medicare, other govt, other unknown, patient assistance, self-pay, workers comp. For group, let's do insurance groups in this hierarchy: 1)uninsured, 2) Medicaid, 3) Private

Our rates will end up meaning the % of people for the demographic group with PSL among those who were asked
*/
use "${labpath}/Flatiron/Data/Original/Controls/nhis_00017.dta", clear
numlabel, add
ta year, missing
ta sex, missing
ta age, missing
drop if age<18|age>64
gen agegrp=.
replace agegrp=1 if age>17 & age<35
replace agegrp=2 if age>34 & age<45
replace agegrp=3 if age>44 & age<55
replace agegrp=4 if age>54 & age<65
label define agegrp  1 "18-34" 2 "35-44" 3 "45-54" 4 "55-64"
label values agegrp agegrp
ta age agegrp, missing

gen female=0
replace female=1 if sex==2
label define female 0 "Male" 1 "Female"
label values female female 
ta sex female, missing
rename sex sex_orig


ta paidsick, missing

rename paidsick paidsick_orig
gen paidsick=.
replace paidsick=0 if paidsick_orig==1
replace paidsick=1 if paidsick_orig==2
ta paidsick, missing
ta paidsick
drop if paidsick==.

/*
*make insurance var: for original NHIS vars 1=no 2=yes
gen insurance=.
replace insurance=0 if hinotcov==2
replace insurance=1 if himcaid==2 & missing(insurance)
replace insurance=2 if hiprivate==2 & missing(insurance)
replace insurance=3 if missing(insurance)

/*What insurance does everyone else have?
foreach ins in hichip himilva himcare hiothgov hindian hinone hiprivatee himilite {
	ta `ins' if missing(insurance), missing
}
*/

label define insurance 0 "Uninsured" 1 "Medicaid" 2 "Private" 3 "Other"
label values insurance insurance

ta insurance, missing
*/

*race ethnicity
ta racenew, missing
ta hispyn, missing

gen raceeth=.
replace raceeth=1 if hispyn ==2 /*Hispanic*/
replace raceeth=2 if missing(raceeth) & racenew==100 /*White*/
replace raceeth=3 if missing(raceeth) & racenew==200 /*Black*/
replace raceeth=4 if missing(raceeth) & inlist(racenew,300,400,530,541) /*Other*/
label define raceeth 1 "Hispanic" 2 "NH White" 3 "NH Black" 4 "NH Other" 
label values raceeth raceeth
ta raceeth, missing


*Assign group
egen group1=group(agegrp female), label
egen group2=group(agegrp female raceeth),  label
*egen group3=group(agegrp female insurance), label
*egen group4=group(agegrp female raceeth insurance), label

keep sampweight agegrp female paidsick /*insurance*/ raceeth group1 group2 /*group3 group4*/

svyset [pweight=sampweight]


foreach grp in 1 2 /*3 4*/ {
	gen nhis`grp'=.
	levelsof group`grp', local(levels)

	foreach s of local levels {
			display "`grp', `s'"
			svy: mean paidsick if  group`grp'==`s'
			replace nhis`grp'=_b[paidsick] if  group`grp'==`s'
	}
}

label var nhis1 "PSL rate: Group1 (age/sex)"
label var nhis2 "PSL rate: Group2 (age/sex/raceeth)"
*label var nhis3 "PSL rate: Group3 (age/sex/insurance)"
*label var nhis4 "PSL rate: Group4 (age/sex/raceeth/insurance)"
drop sampweight
drop paidsick
duplicates drop
sort agegrp female  raceeth
save "nhisrates.dta", replace





***********************************
/*Variables from our core files*/
use "${path}/state_core_q_2025.04.dta", clear
keep state year quarter ACA econ_unemploy_st demo_uninsured_st demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st demo_pov_st demo_popwaadult_st demo_popadult_st demo_popkid_st covid_deaths_cdc_st covid_dmiss_cdc_st
keep if year>2010
save state.dta, replace

use "${path}/cntytostate_2025.04.dta", clear
keep state year quarter covid_cases_cntysum covid_ccases_cntysum
keep if year>2010
merge 1:1 state year quarter using "state.dta"
drop _merge

/*Make quarterly into monthly */
gen month=1 if quarter==1
replace month=4 if quarter==2
replace month=7 if quarter==3
replace month=10 if quarter==4
sort state year quarter
expand 3
bysort state year quarter: replace month = month+ _n-1

statastates, fips(state)
drop _merge

merge m:1 state_name using "fmli.dta" 
gen fmli=0
replace fmli =1 if year>effective_year | (year==effective_year & month>=effective_month)
label var fmli "state paid family & medical leave insurance"
drop effective_month effective_year _merge state_abbrev state_name state_abbrev state_name

/*State-level temporary disability insurance program is in place. Data source is U.S. Department of Labor (https://oui.doleta.gov/unemploy/pdf/uilawcompar/2013/disability.pdf) None in a really long time. States: "Rhode Island passed the first TDI law in 1942; California followed in 1946; New Jersey in 1948; New York in 1949; Puerto Rico in 1968; and Hawaii in 1969." */
gen sdi=0
replace sdi=1 if inlist(state,44,6,34,36,15)
label var sdi "State temporary disability insurance"

drop if year>2023


replace covid_deaths_cdc_st =0 if year<2020
replace covid_dmiss_cdc_st =0 if year<2020


*merge in Guthrie's covid controls - 2020-2021
merge 1:1 state year month using "${labpath}/Flatiron/Data/Guthrie/working/Covid_controls/all_covid_controls.dta", keepusing(pct_month_eps pct_month_sah pct_month_int)
*Fill in other years that are missing
replace pct_month_int=0 if missing(pct_month_int) 
replace pct_month_eps=0 if missing(pct_month_eps) 
replace pct_month_sah=0 if missing(pct_month_sah) 
drop _merge

rename  pct_month_int covid_int
rename pct_month_eps covid_eps
rename pct_month_sah covid_sah

*Look for missings. I don't really need the pop #s - leave for now.
tabstat  covid_ccases_cntysum covid_cases_cntysum ACA econ_unemploy_st demo_popadult_st demo_popkid_st demo_popwaadult_st demo_pov_st demo_uninsured_st demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st covid_deaths_cdc_st covid_dmiss_cdc_st month fmli sdi covid_int covid_eps covid_sah, by(year) statistics(n mean min max)

*carry forward
foreach x in demo_pov_st demo_uninsured_st demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st covid_ccases_cntysum covid_cases_cntysum {
	sort state year month
	replace `x'=`x'[_n-1] if missing(`x') & year>2022
}


order state year quarter month covid*
sort state year month
save "policy.dta", replace



**********************************
/*Add policy data*/

use "all_merged_${today}d.dta", clear
*Add in PSL data - Guthrie sets it up here: ${labpath}/Flatiron/Data/Guthrie/working/Flatiron_controls/
merge m:1 state year month using "${labpath}/Flatiron/Data/Guthrie/working/Flatiron_controls/state_psl_coverage_v6.dta"
ta state year if _merge==2 /*These are either too early in the period, or low pop states. THough some states like CO and DE etc. have matches for some months but not others*/
ta state year if _merge==1 /*These are missing state or missing index year*/
drop if _merge==2
drop _merge
ta state psl_state_y, missing
ta state psl_state_q, missing
ta state psl_state_m, missing

*Add in other policy controls
merge m:1 state year month using "policy.dta"
ta state year if _merge==1, missing /*mostly missing states*/
ta state year if _merge==2, missing
drop if _merge==2
drop _merge


*Add in NHIS data. Those over 65 wont be matched
merge m:1 agegrp raceeth female  using "nhisrates.dta"
ta female  if _merge==1 & age<65, missing 
ta raceeth  if _merge==1 & age<65, missing 
ta female if _merge==2, missing
ta agegrp if _merge==2, missing
ta raceeth if _merge==2, missing
drop if _merge==2
drop _merge




*save "${labpath}/Flatiron/Data/Serena/merged_pol_${today}d.dta", replace




********************************************
/*	Kevin: we need pre-period trend to be linear for AGB to be meaningful
	Look at pre-trends further out in terms of pre-period to see what binned first point represents
	Pick a reasonable window- e.g. 4 to 5 points, and don't bin it.
 */

*Make "event" at the year isntead of month level
*State version
replace event_state=. if psl_state_arm==0
gen event_st_y=event_state/12
replace event_st_y=floor(event_st_y)

listsome year event_st_y event_state psl_state_arm year_treat, random
ta event_st_y psl_state_arm, missing

*40% version
replace event_40=. if psl_40_arm==0
gen event_40_y=event_40/12
replace event_40_y=floor(event_40_y)

listsome year event_40_y event_40 psl_40_arm year_treat, random
ta event_40_y psl_40_arm, missing

*PSL only no PTO (make 23, 26, 32 controls)
ta psl_state_arm psl_pslonly_arm, missing
ta state if psl_state_arm==1 & psl_pslonly_arm==0

gen event_pslonly=event_state 
replace event_pslonly=. if psl_pslonly_arm==0

*check- good
ta state if event_pslonly != event_state, missing

gen event_pslonly_y=event_pslonly/12
replace event_pslonly_y=floor(event_pslonly_y)

ta event_pslonly_y psl_pslonly_arm, missing

**Now make year versions of FAKE event
*state
gen event_fake_st_y=event_fake_state/12
replace event_fake_st_y=floor(event_fake_st_y)

*PSL only no PTO
gen event_fake_pslonly_y=event_fake_pslonly/12
replace event_fake_pslonly_y=floor(event_fake_pslonly_y)

*check
ta event_fake_st_y psl_state_arm, missing
ta event_fake_pslonly_y psl_pslonly_arm, missing
listsome yearmonth event_fake_state event_fake_st_y   event_state event_st_y psl_state_arm year_treat fakeyearmonthtreat, random

/*
*Problem: event_fake_st_y can't be used in AGB because it has negative values
gen event_fake_st_y_pos=event_fake_st_y+100
ta event_fake_st_y_pos pt_fake_state, missing
label var event_fake_st_y_pos "Period time, PSL state, year, 100=t0"
*/

/*11/14/2024: make a version of 40% PSL that takes out PTO
PTO states in our year range (2011-2023): Michigan 2019, Nevada 2020, Maine 2021, Illinois 2024 (NOT included)
40% triggers for: NYC 4/2014 (later all of NY adopts 9/2020); Chicago/cook 7/2017 (all Illinois adopts 1/2024)


 psl_40_arm psl_40_m psl_40_q psl_40_y event_40 pt_40*/
gen psl_40nopto_arm=psl_40_arm if pto_arm!=1
replace psl_40nopto_arm=0 if pto_arm==1
label var psl_40nopto_arm ">=40% PSL arm, NO PTO"
ta state psl_40nopto_arm , missing


*Year treat for 40% PSL with no PTO
gen year_treat_40nopto=year_treat
replace year_treat_40nopto=0 if pto_arm==1 
replace year_treat_40nopto =2017 if state==17
replace year_treat_40nopto =2014 if state==36 /*Changes NY from 2020 to 2014*/
*check - looks good.
ta state year_treat_40nopto, missing
label var year_treat_40nopto "Year that PSL started (>=40% PSL, no PTO)"


*Indicator - should only be different from PSL only indicator for 36 and 17 (NY and chicago)
gen psl_40nopto_y=psl_pslonly_y
replace psl_40nopto_y= psl_40_y if inlist(state,36,17)
label var psl_40nopto_y ">=40% PSL, PTO excluded"
*check
ta state psl_40nopto_y, missing
sort state year month
ta year psl_40nopto_y if state==36, missing
ta year psl_40nopto_y if state==17, missing
ta year psl_40nopto_y if inlist(state,26,23,32), missing /*pto states*/

*Event variables - we can just use the 40% kind  and set PTOs to 0. We aren't detrending 40% variables so we don't need "fake" versions
*Event variable: control states should be MISSING
gen event_40nopto_y= event_40_y
replace event_40nopto_y=. if pto_arm==1
set linesize 255
listsome state yearmonth event_40nopto_y psl_40nopto_y year_treat_40nopto psl_40nopto_arm if psl_40nopto_arm==1, random
listsome state yearmonth event_40nopto_y psl_40nopto_y year_treat_40nopto psl_40nopto_arm if inlist(state,36,17), random /*40% states*/
listsome state yearmonth event_40nopto_y psl_40nopto_y year_treat_40nopto psl_40nopto_arm if inlist(state,26,23,32), random /*pto states*/

*40% with no pto
gen pt_40pslonly=pt_40 if pto_arm!=1
replace pt_40pslonly=0 if pto_arm!=0
label var pt_40pslonly "Period time (years) for 40% PSL only (no PTO)"
label values pt_40pslonly pt_40



/*Make a longer pre-period version of period time */
gen ptlong_state=.
replace ptlong_state= 9 if event_state>-1 & event_state<12 /*The year that it happened; 0-11 */
replace ptlong_state = 10 if event_state>11 & event_state<24 
replace ptlong_state = 11 if event_state>23 & event_state<36
replace ptlong_state = 12 if event_state>35 & event_state<48 
replace ptlong_state = 13 if event_state>47 & event_state<60 
replace ptlong_state = 14 if event_state>59 & !missing(event_state)

replace ptlong_state = 8 if event_state>-13 & event_state<0
replace ptlong_state = 7 if event_state>-25 & event_state<-12
replace ptlong_state = 6 if event_state>-37 & event_state<-24 
replace ptlong_state = 5 if event_state>-49 & event_state<-36 
replace ptlong_state = 4 if event_state>-61 & event_state<-48
replace ptlong_state = 3 if event_state>-73 & event_state<-60
replace ptlong_state = 2 if event_state>-85 & event_state<-72
replace ptlong_state = 1 if event_state>-900 & event_state<-84

replace ptlong_state=0 if event_state==.

label var ptlong_state "Period time (years) for PSL mandate state (long pre-period)"
label define ptlong_state 0 "Never mandate" 1 "<-6" 2 "[-6 to-5)" 3 "[-5 to-4)" 4 "[-4 to-3)" 5 "[-4 to-3)" 6 "[-3 to-2)" 7 "[-2 to-1)" 8 "[-1 to 0)" 9 "[0 to 1)" 10 "[1 to 2)" 11 "[2 to 3)" 12 "[3 to 4)" 13 "[4 to 5)" 14 "5+"
label values ptlong_state ptlong_state
numlabel, add

ta  ptlong_state, missing
ta  ptlong_state pt_state, missing

save "all_merged_${today}d.dta", replace


desc *
sum *


log close

/*Outdated

log using "samplefigure_${today}d.log", replace
*********************************
/*Sample construction steps for flow chart */
count

/*Drop sequence: count how many get dropped at each step, for flow-chart*/
ta cohort, missing
ta year, missing

*Count after dropping PR
drop if drop_terr==1
count

*Count after dropping missing state info (most of these are likely academic locations)
drop if drop_nogeo==1
count

*Count after dropping older ages
ta demo_agegrp
keep if demo_agegrp==2

*Count after dropping missing adv/met dx date
drop if drop_noindex==1
count

*Count after dropping missing Line 1 start date/ no systemic therapy
drop if drop_nol1date==1
count

*Count after dropping negative # days between index date & first day of tx
drop if drop_neg==1
count


*Count after dropping died within month of adv/dx date
drop if drop_died30==1
count

*Count after dropping those with adv/met diagnosis >30 days of initial diagnosis date
keep if samedate==1
count

*Count after drop initial stage 0 dx
drop if drop_stage0==1
count

/*If someone has more than 1 diagnosis, let's keep only their first one */
sort patientid indexdate
duplicates tag patientid, gen(dupe)
*Drops the later date, but this will be random if they get 2 diagnoses on the same date.
sort dupe patientid indexdate
drop if patientid==patientid[_n-1] & dupe>0 & !missing(dupe) 
duplicates report patientid
count



assert !missing(yearquarter) & !missing(state)
save "analyticsample_${today}d.dta", replace


log close



*/



























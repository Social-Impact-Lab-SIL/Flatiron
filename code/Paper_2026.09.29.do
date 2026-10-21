/* FLATIRON/ACS ANALYSIS 

8/2026 edits:
* Clarify race/eth label in stratified results for Other
* Make decimals into percentages for graphs
* ATT rather than Coef label


*/
/*
/*Use this when using Windows-mounted*/
cd "Z:\Flatiron\Data\Serena\working"
global flatpath "Z:\Flatiron"
global labpath "Z:\"
global output "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/output/2026.10"
sysdir set PLUS "Z:\StataUserPackages"
*/


/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global flatpath "/cluster/VAST/mp94p-lab/Flatiron"
global labpath "/cluster/VAST/mp94p-lab/"
global output "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/output/2026.10"
sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"


global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")
set linesize 255



log using "${output}/samplefigure_${today}d.log", replace
*********************************
use "all_merged_2025.06.17d.dta", clear
/*Sample construction steps for flow chart */
count

/*Drop sequence: count how many get dropped at each step, for flow-chart*/
ta cohort, missing
ta year, missing

*Drop 2023 for right censoring
drop if year==2023

*Count after dropping PR
drop if drop_terr==1
count

*Count after dropping missing state info (most of these are likely academic locations)
drop if drop_nogeo==1
count

*Count after dropping DC (always treated)
drop if state==11
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
*keep if samedate==1
count

*Count after drop initial stage 0 dx
drop if drop_stage0==1
count

/*If someone has more than 1 diagnosis, let's keep only their first one 
Also sort by cohort so that the observation dropped won't change every time in cases where patient gets diagnosed with more than 1 cancer on the same date*/
sort patientid indexdate 
duplicates tag patientid, gen(dupe)
sort dupe patientid indexdate cohort
drop if patientid==patientid[_n-1] & dupe>0 & !missing(dupe) 
duplicates report patientid
count

*Drop if no treatment start within 1 year
drop if drop_time_days_1yrpls==1


*Make a flag for diagnosed at stage IV of any type
ta clin_groupstage, missing
gen stageIV=1 if regexm(clin_groupstage,"IV")
replace stageIV=0 if missing(stageIV)
label var stageIV "Diagnosed at stage IV"
ta clin_groupstage stageIV, missing /*About 33,323 with stage IV initial dx*/

/*Make 3 level race - i.e. just make an other group that isn't white or black */
ta demo_raceeth, missing
gen othrace=1 if inlist(demo_raceeth, 1,4) /*Hispanic and "Other" - NO missing race included*/
label var othrace "Other race/ethnicity"
ta demo_raceeth othrace, missing


*12/9/2025: Mike wants me to flag only folks living in states with partial geography PSL in the years that it applies
gen partpsl=0
replace partpsl=1 if (state==6 &year>2007 & year<2016) | (state==24 & year>2015 & year<2019) | (state==34 & year>2013 & year<2019) | (state==36 & year>2013 & year< 2021) | ( state==53 & year>2011 & year<2019)
ta state partpsl, missing

assert !missing(yearquarter) & !missing(state)


************************
*Patching in new variables to use

gen timely45=.
replace timely45=0 if time_days>45 & !missing(time_days) 
replace timely45=1 if time_days>=0 & time_days<=45
label var timely45 "Tx initiation within 45 days of adv/met dx"

*flag 6 month+ for possible exclusion: 182 days
gen drop_time_days_6mpls=0
replace drop_time_days_6mpls=1 if time_days>182 & !missing(time_days)
label var drop_time_days_6mpls "Flag: Treatment start # days>182 days"

*No states that have PSL adoption locally - whether yes or no state wide adoption
ta state psl_state_arm, missing
gen localpsl=1 if inlist(state,6,17,24,27,34,35,36,41,42,53)
ta state localpsl, missing

save "analyticsample_2026.09.03.dta", replace
count

log close


log using "desc_${today}d.log", replace
****************************************
****************************************
*DESCRIPTIVES
****************************************
****************************************

/*DESCRIPTIVES tables by mandate status*/
use "analyticsample_2026.09.03.dta", clear

label var raceeth_1 "Hispanic"
label var raceeth_2 "NH White"
label var raceeth_3 "NH Black"
label var raceeth_4 "NH Other"
label var raceeth_5 "Missing race"
label var female "Female"
label var sesindex_1 "Lowest SES quintile"
label var sesindex_2 "21-40% SES quintile"
label var sesindex_3 "41-60% SES quintile"
label var sesindex_4 "61-80% SES quintile"
label var sesindex_5 "Highest SES quintile"
label var sesindex_6 "Missing SES"
label var demo_edu_underHS_st "State % < HS"
label var demo_edu_HS_st "State % HS or GED"
label var demo_edu_somecoll_st "State % Some college"
label var demo_edu_coll_st "State % Bachelor's Degree"
label var demo_edu_grad_st "State % Graduate or professional"
label var ACA "State ACA Medicaid expansion"
label var econ_unemploy_st "State mean unemployment rate"
label var fmli "State paid family & medical leave insurance"
label var covid_cases_cntysum "State # COVID cases"
label var covid_deaths_cdc_st "State # COVID deaths"
label var covid_int "COVID interstate travel quarantine mandate"
label var covid_eps "COVID elective procedure suspension mandate"
label var covid_sah "COVID stay at home mandate"

*9/24/2026: multiply binary outcomes by 100 to get %s			
foreach x in timely60 /*time_days*/ timely45 timely30 timely14 ///
			/*demo_agedx */raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA /*econ_unemploy_st*/ fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st */ covid_int covid_eps covid_sah {
			replace `x'=`x'*100
			tabstat `x', statistics(n mean min max)
			}
*This makes a descriptive table for ALL observations, (alt stage IV only)		
foreach sample in all /*iv*/ {
	if "`sample'"=="all" {
		local sampcomm=""
		local desc "Full"
	}
	
	else {
		local sampcomm "& stageIV==1"
		local desc "Stage IV at dx only"
	}
		foreach group in /*"both"*/ "0" "1" {
			if "`group'"=="both" {
				local comm="psl_state_arm==0|psl_state_arm==1"
			}
			else if "`group'"=="0" {
				local comm="psl_state_arm==0"
			}
			else {
				local comm="psl_state_arm==1"
			}

			eststo desc`group': estpost sum /*timely30 timely14*/ timely60 time_days ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah ///
			if (drop_time_days_1yrpls!=1)   & demo_agegrp==2  & (`comm') `sampcomm'
			
		}


	eststo desc_ttest: estpost ttest /*timely30 timely14*/ timely60 time_days ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah ///
	if (drop_time_days_1yrpls!=1)    & demo_agegrp==2 `sampcomm', by(psl_state_arm)



esttab  /*descboth*/ desc0 desc1 desc_ttest desc_ttest using "${output}/Desc_`sample'_${today}.html", replace html label nonumber nostar cells("mean(fmt(3) pattern(1 1 0 0 )) sd(fmt(3) par([ ]) pattern( 1 1 0 0))  b(pattern(0 0 1 0 )) p(pattern(0 0 0 1))") title("Descriptive Statistics by PSL mandate status. `desc' Sample. Ages 18-64 (State unbalanced panel, treatment start date>1 year excluded)") mtitle(/*"All"*/ "Never Adopt PSL Mandate" "Adopt PSL Mandate" "Difference" "P-value of Difference") nogap stats(N, fmt(%9.0gc))

}
/*
*This makes a descriptives table for PRE-INTERVENTION period only (for treated group) so that we can compare things at "baseline"
	foreach group in "0" "1" {
			if "`group'"=="0" {
				local comm="psl_state_arm==0"
			}
			else {
				local comm="psl_state_arm==1 & psl_state_y==0"
			}

			eststo desc`group': estpost sum  timely60 time_days timely45 timely30 timely14 ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah ///
			if (drop_time_days_1yrpls!=1)   & demo_agegrp==2  & (`comm')
			
		}

	*T-test only for the sample of control + treated arm during the pre-treatment period
	eststo desc_ttest: estpost ttest  timely60 time_days timely45 timely30 timely14  ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah*/ ///
	if (drop_time_days_1yrpls!=1)    & demo_agegrp==2 & (psl_state_arm==0|(psl_state_arm==1 & psl_state_y==0)), by(psl_state_arm)



esttab  /*descboth*/ desc0 desc1 desc_ttest desc_ttest using "${output}/Desc_baseline_${today}.html", replace html label nonumber nostar cells("mean(fmt(3) pattern(1 1 0 0 )) sd(fmt(3) par([ ]) pattern( 1 1 0 0))  b(pattern(0 0 1 0 )) p(pattern(0 0 0 1))") title("Baseline descriptive Statistics by PSL mandate status. All Control Arm observations + Pre-treatment period only for Treated Arm. Ages 18-64 (State unbalanced panel, treatment start date>1 year excluded)") mtitle(/*"All"*/ "Never Adopt PSL Mandate" "Adopt PSL Mandate" "Difference" "P-value of Difference") nogap stats(N, fmt(%9.0gc))

*/

*This makes a descriptives table with 3 columns: Control, Treatment pre-period, Treatment post-period
	foreach group in "0" "1" "2" {
			if "`group'"=="0" {
				local comm="psl_state_arm==0"
			}
			else if "`group'"=="1" {
				local comm="psl_state_arm==1 & psl_state_y==0"
			}
			else {
				local comm="psl_state_arm==1 & psl_state_y==1"
			}

			eststo desc`group': estpost sum  timely60 time_days timely45 timely30 timely14 ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah ///
			if (drop_time_days_1yrpls!=1)   & demo_agegrp==2  & (`comm')
			
		}

	*T-test only for the sample of control + treated arm during the pre-treatment period
	eststo desc_ttest: estpost ttest  timely60 time_days timely45 timely30 timely14  ///
			demo_agedx raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA econ_unemploy_st fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah*/ ///
	if (drop_time_days_1yrpls!=1)    & demo_agegrp==2 & (psl_state_arm==0|(psl_state_arm==1 & psl_state_y==0)), by(psl_state_arm)



esttab  /*descboth*/ desc0 desc1 desc2  desc_ttest desc_ttest  using "${output}/Desc_split_${today}.html", replace html label nonumber nostar cells("mean(fmt(3) pattern(1 1 1 0 0)) sd(fmt(3) par([ ]) pattern( 1 1 1 0 0))  b(pattern(0 0 0 1 0 )) p(pattern(0 0 0 0 1))") title("Descriptive Statistics by PSL mandate and treatment status. Ages 18-64 (State unbalanced panel, treatment start date>1 year excluded)") mtitle(/*"All"*/ "Never Adopt PSL Mandate" "Adopt PSL Mandate (pre-intervention only)" "Adopt PSL Mandate (post-intervention only)" "Baseline Difference" "P-value of Baseline Difference") nogap stats(N, fmt(%9.0gc))

* Export same table to CSV
esttab desc0 desc1 desc2 /*desc_ttest desc_ttest*/ ///
    using "${output}/Desc_split_${today}.csv", replace ///
    label nonumber nostar ///
    cells("mean(fmt(3) pattern(1 1 1 0 0))  sd(fmt(3) par([ ]) pattern(1 1 1 0 0)) b(pattern(0 0 0 1 0)) p(pattern(0 0 0 0 1))") ///
    title("Descriptive Statistics by PSL mandate and treatment status. Ages 18-64 (State unbalanced panel, treatment start date>1 year excluded)") ///
    mtitle("Never Adopt PSL Mandate" ///
           "Adopt PSL Mandate (pre-intervention only)" ///
           "Adopt PSL Mandate (post-intervention only)" ///
           "Baseline Difference" ///
           "P-value of Baseline Difference") ///
    nogap stats(N, fmt(%9.0gc))
	
*Quick descriptive graph of control vs. PSL mandate arm trends by year
preserve

collapse (mean) timely60 time_days timely45 timely30 timely14, ///
    by(year psl_state_arm)

set graphics off

foreach dv in timely30 timely14 timely45 timely60 {

    if "`dv'" == "timely30" {
        local l "≤30 days (%)"
    }
    else if "`dv'" == "timely14" {
        local l "≤14 days (%)"
    }
    else if "`dv'" == "timely45" {
        local l "≤45 days (%)"
    }
    else {
        local l "≤60 days (%)"
    }

    sort psl_state_arm year

    twoway ///
        (line `dv' year if psl_state_arm==0, lwidth(medthick)) ///
        (line `dv' year if psl_state_arm==1, lwidth(medthick)), ///
        legend(off) ///
        ytitle("`l'", size(small)) ///
        xtitle("Year", size(small)) ///
        ylabel(0(10)100, labsize(small)) ///
        xlabel(2011 2013 2015 2017 2019 2021 , labsize(small)) ///
        aspectratio(.95)

    gr save "desc_`dv'.gph", replace
}

*Version with legend
twoway ///
    (line time_days year if psl_state_arm==0, lwidth(medthick)) ///
    (line time_days year if psl_state_arm==1, lwidth(medthick)), ///
    legend(order(1 "Never Adopting" 2 "Adopting") size(small)) ///
    ytitle("Days to treatment", size(small)) ///
    xtitle("Year", size(small)) ///
    xlabel(2011 2013 2015 2017 2019 2021, labsize(small)) ///
    ylabel(, labsize(small)) ///
    aspectratio(.95)

gr save "desc_time_days_leg.gph", replace
gr export "time_days_leg.jpg", as(jpg) replace

*Version without legend
twoway ///
    (line time_days year if psl_state_arm==0, lwidth(medthick)) ///
    (line time_days year if psl_state_arm==1, lwidth(medthick)), ///
    legend(off) ///
    ytitle("Days to treatment", size(small)) ///
    xtitle("Year", size(small)) ///
    xlabel(2011 2013 2015 2017 2019 2021 2023, labsize(small)) ///
    ylabel(, labsize(small)) ///
    aspectratio(.95)

gr save "desc_time_days.gph", replace
gr export "time_days.jpg", as(jpg) replace



graph combine  "desc_timely60.gph" ///
    "desc_time_days.gph" ///
    "desc_timely14.gph" ///
    "desc_timely30.gph" ///
    "desc_timely45.gph", iscale(.4) ysize(10) xsize(10) commonscheme  cols(2) graphregion(color(white)) 
gr export "${output}/desctrend_${today}.jpg", as(jpg) replace height(10000)

format timely60 time_days timely45 timely30 timely14 %9.3f
export excel year psl_state_arm timely60 time_days timely45 timely30 timely14 ///
    using "${output}/PSLtrendrawvalues.xlsx", firstrow(variables) nolabel replace
    
restore

***************
*Get basic %s for each outcome by arm

foreach arm in 0 1 {
	foreach dv in timely60 time_days timely45 timely30 timely14 {
		display "arm: `arm' dv: `dv'"
ta year if psl_state_arm==`arm', summarize(`dv')
}
}
***********************
*CONTROLS
global indiv  demo_agedx i.demo_raceeth i.demo_female
global edu demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st /*demo_edu_grad_st - referent*/
global policy ACA econ_unemploy_st  i.fmli 
global covid covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah

****************************************
****************************************
*Baseline balance
*Per Mike: TWFE is OK, include all controls, state & year FE, cluster at state. DV = actual treatment and not the arm. Include all obs
****************************************
****************************************

*10/2/2026: multiply by 100 to temporarily get on a % scale - this change doesn't get saved
replace psl_state_y =psl_state_y *100



ta cohort year, missing
areg psl_state_y  demo_agedx ib2.demo_raceeth i.demo_female ${edu} ${policy} ${covid} i.cohort ib5.sesindex_m i.year ,absorb(state) cluster(state)


log close


***********************
*CONTROLS
global indiv  demo_agedx i.demo_raceeth i.demo_female
global edu demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st /*demo_edu_grad_st - referent*/
global policy ACA econ_unemploy_st  i.fmli 
global covid covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah

***********************
*Compare main results using never treated vs. not yet treated as controls
log using comparisongroup.log, replace
use "analyticsample_2026.09.03.dta", clear


*9/24/2026: multiply binary outcomes by 100 to get %s			
foreach x in timely60 /*time_days*/ timely45 timely30 timely14 ///
			/*demo_agedx */raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA /*econ_unemploy_st*/ fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st */ covid_int covid_eps covid_sah {
			replace `x'=`x'*100
			}
			
*Default - never
csdid timely60 i.cohort demo_agedx i.demo_raceeth i.demo_female demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st ACA econ_unemploy_st i.fmli covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah i.sesindex_m if demo_agegrp==2 , cluster(state) time(year) gvar(year_treat) method(reg) wboot long2
estat simple

*Not yet
csdid timely60 i.cohort demo_agedx i.demo_raceeth i.demo_female demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st ACA econ_unemploy_st i.fmli covid_cases_cntysum covid_deaths_cdc_st covid_int covid_eps covid_sah i.sesindex_m if demo_agegrp==2 , cluster(state) time(year) gvar(year_treat) method(reg) wboot long2 notyet
estat simple
log close


*********************************************
/*C&S Regressions - INDIVIDUAL REPEATED CROSS-SECTIONS VERSION*/
*********************************************
foreach stage in all  nomin iv no6m no90d nolocal noctrls nopol nopolcov indivses indiv notyet nopto {

*Make samples
	if "`stage'"=="all" {
		local stagedesc "All stages. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local stagepop ""
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}

	else if "`stage'"=="nomin" {
		local stagedesc "All stages, Exclude states with PSL firm exemptions based on size. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local stagepop "& psl_exarm!=1"
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	else if "`stage'"=="iv" {
		local stagepop "& stageIV==1"
		local stagedesc "Stage IV at dx only. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	else if "`stage'"=="no6m"  {
		local stagepop "& drop_time_days_6mpls==0"
		local stagedesc "Exclude No tx within 6+ months. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	else if "`stage'"=="no90d"  {
		local stagepop "& drop_90d!=1"
		local stagedesc "Drop if no activity within 90 days of index. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	else if "`stage'"=="noctrls" {
		local stagepop ""
		local stagedesc "No controls."
		local ctrls " "
		local notyet ""
			}
	else  if "`stage'"=="nolocal"  {
		local stagepop "& localpsl!=1"
		local stagedesc "Exclude states with local PSL adoption. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	else  if "`stage'"=="nopol"  {
		local stagepop ""
		local stagedesc "No policy controls. Cancer type, individual, education, COVID, SES quintiles controls Only."
		local ctrls "i.cohort ${indiv} ${edu} ${covid} i.sesindex_m "
		local notyet ""
	}
	else  if "`stage'"=="nopolcov"  {
		local stagepop ""
		local stagedesc "No policy or COVID controls. Cancer type, individual, education, SES quintiles controls Only"
		local ctrls "i.cohort ${indiv} ${edu} i.sesindex_m "
		local notyet ""
	}
	else  if "`stage'"=="indivses"  {
		local stagepop ""
		local stagedesc "Cancer type, individual, SES quintiles controls Only. No area controls whatsoever."
		local ctrls "i.cohort ${indiv} i.sesindex_m "
		local notyet ""
	}
	else   if "`stage'"=="indiv"  {
		local stagepop ""
		local stagedesc "Cancer type, individual controls Only"
		local ctrls "i.cohort ${indiv} "
		local notyet ""
	}
	else if "`stage'"=="notyet"   {
		local stagedesc "Main model specification, with NOT YET TREATED (instead of never treated) used as controls"
		local stagepop ""
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet "notyet"
	}
	else {
		local stagedesc "Excludes PTO states. All stages. Cancer type, individual, education, area, COVID, SES quintiles controls."
		local stagepop "& pto_arm!=1"
		local ctrls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m "
		local notyet ""
	}
	
log using "${output}/CSind_1864_pslst_`stage'_${today}d.log", replace
use "analyticsample_2026.09.03.dta", clear


*9/24/2026: multiply binary outcomes and fractions by 100 to get %s			
foreach x in timely60 /*time_days*/ timely45 timely30 timely14 ///
			/*demo_agedx */raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA /*econ_unemploy_st*/ fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st */ covid_int covid_eps covid_sah {
			replace `x'=`x'*100
			tabstat `x', statistics(n mean min max)
			}
			
display "C&S 18-64 NOT restricted to new diagnosis, Population: a1864 `stagedesc'"

	foreach dv in timely30 timely14 timely45  timely60 time_days {
	
			if "`dv'" == "timely30" {
				local l "Treatment within 30 days (%)"
			}
			else if "`dv'" == "timely14" {
				local l "Treatment within 14 days  (%)"
			}
			else if "`dv'" == "timely45" {
				local l "Treatment within 45 days  (%)"
			}
			else if "`dv'" == "timely60" {
				local l "Treatment within 60 days  (%)"
			}
			else {
				local l "# Days to treatment"
			}

		
			
		display "Model iteration: C&S PSL type: pslst Table: a1864 `stagedesc'   Time: year DV Type: `dv' Control: `notyet'"
		*Fernando: "you cant do state fixed effects, because state would be colinear with treatment. and weird things happen then. when using repeated crossection, you are not really adding individual "fixed effects", but instead cohort fixed effects"
		eststo `dv'_`stage'_12: csdid `dv' `ctrls' if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2 `notyet'
		display "eststo `dv'_`stage'_12: csdid `dv' `ctrls' if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2 `notyet'"
		estadd local comm "eststo `dv'_`stage'_12: csdid `dv' `ctrls' if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2 `notyet'" :  `dv'_`stage'_12

		estat simple
		matrix list r(table)
		matrix `dv'`stage' = r(table)
		estadd scalar ATT=`dv'`stage'[1,1]  : `dv'_`stage'_12
		estadd scalar ATTse=`dv'`stage'[2,1]  : `dv'_`stage'_12
		estadd scalar ATTp=`dv'`stage'[4,1]  : `dv'_`stage'_12
		estadd scalar ATTlowci=round(`dv'`stage'[5,1],.001): `dv'_`stage'_12 /*lower CI*/
		estadd scalar ATThighci=round(`dv'`stage'[6,1],.001): `dv'_`stage'_12 /*high CI*/
		est restore `dv'_`stage'_12
		summarize `dv'  if e(sample)==1 & psl_state_arm==1 & psl_state_y==0, meanonly /*pretreatment dependent mean for treated geos only*/
		estadd scalar dependent_mean = r(mean) : `dv'_`stage'_12
		display e(dependent_mean)
		est restore `dv'_`stage'_12
		summarize psl_state_y if e(sample) == 1, meanonly
		estadd scalar mandate = r(mean) :  `dv'_`stage'_12
		
	/*Event study for C&S with controls*/	
		est restore `dv'_`stage'_12
		estat event, window(-6 5)
		csdid_plot, name(e_`dv'_`stage'_12, replace)  ytitle("`l'") title("`l'", size(small))  style(rcap) xlabel(-7(1)5 ,labsize(small))  xline(-.5) legend(off) graphregion(color(white)) /*Unbinned endpoints*/
		graph save "e_`dv'_`stage'_12" "e_`dv'_`stage'_12_${today}.gph", replace
		
		
			}
			
			
/*Print C&S table*/
 esttab timely14_`stage'_12 timely30_`stage'_12  timely45_`stage'_12 timely60_`stage'_12 time_days_`stage'_12  using "${output}/CS1864_allDVs_`stage'_${today}d.html", append html label brackets cells(none) scalars("ATT ATT" "ATTse ATT SE" "ATTp ATT p-value" "ATTlowci ATT 95%CI LB" "ATThighci ATT 95%CI UB"  "N N" "dependent_mean Dependent Mean"  "mandate Mandate Mean" "comm Command") sfmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0fc %9.5f %9.5f %9.0g) noobs title("PSL & Timeliness, Flatiron, C&S individual repeated cross-sections, unbalanced panel, treatment at year level. Age 18-64." "`psldesc'." "`stagedesc'  ". ) mtitle("Tx initiation within 14 days of adv/met dx" "Tx initiation within 30 days of adv/met dx"  "Tx initiation within 45 days of adv/met dx" "Tx initiation within 60 days of adv/met dx" "Cont Diff. adv/met dx & tx start, >=-14 bottom coded at 0" ) alignment(center) star(+ 0.1 * 0.05 ** 0.01 *** 0.001)   addnotes( "Star levels: + 0.1 * 0.05 ** 0.01 *** 0.001" " " " " )

/*C&S Figure Event study combo*/
graph combine  "e_timely14_`stage'_12_${today}.gph" "e_timely30_`stage'_12_${today}.gph"  "e_timely45_`stage'_12_${today}.gph"  "e_timely60_`stage'_12_${today}.gph" "e_time_days_`stage'_12_${today}.gph" , iscale(.4) ysize(10) xsize(10) commonscheme  cols(2) graphregion(color(white)) 
gr export "${output}/CS1864_allDVs_ev_`stage'_${today}.jpg", as(jpg) replace height(10000)

log close
		}


*********************************************
/*SENSITIVITY - Analysis up to 2019 ONLY
C&S Regressions - INDIVIDUAL REPEATED CROSS-SECTIONS VERSION*/
*********************************************
local stage = "upto2019"
local stagepop "& year<2020"
local stagedesc "All stages, Excluding all years 2020+"

log using "${output}/CSind_1864_pslst_`stage'_${today}d.log", replace
use "analyticsample_2026.09.03.dta", clear


*9/24/2026: multiply binary outcomes and fractions by 100 to get %s			
foreach x in timely60 /*time_days*/ timely45 timely30 timely14 ///
			/*demo_agedx */raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA /*econ_unemploy_st*/ fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st */ covid_int covid_eps covid_sah {
			replace `x'=`x'*100
			tabstat `x', statistics(n mean min max)
			}
			
*Subset to just up to 2019
ta year, missing
drop if year>2019

*Need to recode the treatment variable to stop considering late treated PSL states as treated (just for this specification - not saved)
ta year_treat, missing
ta state year_treat, missing
ta state if year_treat>2019
replace year_treat=0 if inlist(state,8,23,32,35,36)
replace psl_state_arm=0 if inlist(state,8,23,32,35,36)
ta year_treat, missing

display "C&S 18-64 NOT restricted to new diagnosis, Population: a1864 `stagedesc'"

	foreach dv in timely30 timely14  timely60 time_days {
	
			if "`dv'" == "timely30" {
				local l "Treatment within 30 days (%)"
			}
			else if "`dv'" == "timely14" {
				local l "Treatment within 14 days  (%)"
			}
			else if "`dv'" == "timely60" {
				local l "Treatment within 60 days  (%)"
			}
			else {
				local l "# Days to treatment"
			}

			
		display "Model iteration: C&S PSL type: pslst Table: a1864 `stagedesc'   Time: year DV Type: `dv' "
		*Fernando: "you cant do state fixed effects, because state would be colinear with treatment. and weird things happen then. when using repeated crossection, you are not really adding individual "fixed effects", but instead cohort fixed effects"
		eststo `dv'_`stage'_12: csdid `dv' i.cohort ${indiv} ${edu} ${policy}  i.sesindex_m  if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2
		display "eststo `dv'_`stage'_12: csdid `dv' i.cohort ${indiv} ${edu} ${policy} i.sesindex_m  if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2"
		estadd local comm "eststo `dv'_`stage'_12: csdid `dv' i.cohort ${indiv} ${edu} ${policy} i.sesindex_m  if  demo_agegrp==2 `stagepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2" :  `dv'_`stage'_12

		estat simple
		matrix list r(table)
		matrix `dv'`stage' = r(table)
		estadd scalar ATT=`dv'`stage'[1,1]  : `dv'_`stage'_12
		estadd scalar ATTse=`dv'`stage'[2,1]  : `dv'_`stage'_12
		estadd scalar ATTp=`dv'`stage'[4,1]  : `dv'_`stage'_12
		estadd scalar ATTlowci=round(`dv'`stage'[5,1],.001): `dv'_`stage'_12 /*lower CI*/
		estadd scalar ATThighci=round(`dv'`stage'[6,1],.001): `dv'_`stage'_12 /*high CI*/

		est restore `dv'_`stage'_12
		summarize `dv'  if e(sample)==1 & psl_state_arm==1 & psl_state_y==0, meanonly /*pretreatment dependent mean for treated geos only*/
		estadd scalar dependent_mean = r(mean) : `dv'_`stage'_12
		display e(dependent_mean)
		est restore `dv'_`stage'_12
		summarize psl_state_y if e(sample) == 1, meanonly
		estadd scalar mandate = r(mean) :  `dv'_`stage'_12
		
	/*Event study for C&S with controls*/	
		est restore `dv'_`stage'_12
		estat event, window(-5 4)
		csdid_plot, name(e_`dv'_`stage'_12, replace)  ytitle("`l'") title("`l'", size(small))  style(rcap) xlabel(-7(1)5 ,labsize(small))  xline(-.5) legend(off) graphregion(color(white)) /*Unbinned endpoints*/
		graph save "e_`dv'_`stage'_12" "e_`dv'_`stage'_12_${today}.gph", replace
		
		
			}
			
			
/*Print C&S table*/
 esttab timely14_`stage'_12 timely30_`stage'_12 timely60_`stage'_12 time_days_`stage'_12  using "${output}/CS1864_allDVs_`stage'_${today}d.html", append html label brackets cells(none) scalars("ATT ATT" "ATTse ATT SE" "ATTp ATT p-value" "ATTlowci ATT 95%CI LB" "ATThighci ATT 95%CI UB"  "N N" "dependent_mean Dependent Mean"  "mandate Mandate Mean" "comm Command") sfmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0fc %9.5f %9.5f %9.0g) noobs title("PSL & Timeliness, Flatiron, C&S individual repeated cross-sections, unbalanced panel, treatment at year level. Age 18-64." "`psldesc'." "Cancer type, individual, education, area,  SES quintiles controls." "`stagedesc'  ". ) mtitle("Tx initiation within 14 days of adv/met dx" "Tx initiation within 30 days of adv/met dx"  "Tx initiation within 60 days of adv/met dx" "Cont Diff. adv/met dx & tx start, >=-14 bottom coded at 0" ) alignment(center) star(+ 0.1 * 0.05 ** 0.01 *** 0.001)   addnotes( "Star levels: + 0.1 * 0.05 ** 0.01 *** 0.001" " " " " )

/*C&S Figure Event study combo*/
graph combine  "e_timely30_`stage'_12_${today}.gph" "e_timely14_`stage'_12_${today}.gph" "e_timely60_`stage'_12_${today}.gph" "e_time_days_`stage'_12_${today}.gph" , iscale(.4) ysize(10) xsize(10) commonscheme  cols(2) graphregion(color(white)) 
gr export "${output}/CS1864_allDVs_ev_`stage'_${today}.jpg", as(jpg) replace height(10000)

log close



log using "sens.log", replace

****************
*Combined sensitivity graph summarizing all different versions
****************

			gen csremove_timely60_12=.
			gen cscoef_timely60_12=.
			gen csci_lb_timely60_12=.
			gen csci_ub_timely60_12=.

*Dump coefficients
*Main 60
est restore	timely60_all_12 	
replace csremove_timely60_12=1 in 1
replace cscoef_timely60_12= timely60all[1,1] in 1
replace csci_lb_timely60_12= timely60all[5,1] in 1
replace csci_ub_timely60_12= timely60all[6,1] in 1	

*45
est restore	timely45_all_12 	
replace csremove_timely60_12=2 in 2
replace cscoef_timely60_12= timely45all[1,1] in 2
replace csci_lb_timely60_12= timely45all[5,1] in 2
replace csci_ub_timely60_12= timely45all[6,1] in 2	

*30
est restore	timely30_all_12 	
replace csremove_timely60_12=3 in 3
replace cscoef_timely60_12= timely30all[1,1] in 3
replace csci_lb_timely60_12= timely30all[5,1] in 3
replace csci_ub_timely60_12= timely30all[6,1] in 3	

*14
est restore	timely14_all_12 	
replace csremove_timely60_12=4 in 4
replace cscoef_timely60_12= timely14all[1,1] in 4
replace csci_lb_timely60_12= timely14all[5,1] in 4
replace csci_ub_timely60_12= timely14all[6,1] in 4	
	
*stage IV
est restore	timely60_iv_12 	
replace csremove_timely60_12=5 in 5
replace cscoef_timely60_12= timely60iv[1,1] in 5
replace csci_lb_timely60_12= timely60iv[5,1] in 5
replace csci_ub_timely60_12= timely60iv[6,1] in 5	
	
*Drop 2020+
est restore	timely60_upto2019_12 	
replace csremove_timely60_12=6 in 6
replace cscoef_timely60_12= timely60upto2019[1,1] in 6
replace csci_lb_timely60_12= timely60upto2019[5,1] in 6
replace csci_ub_timely60_12= timely60upto2019[6,1] in 6	
	
*No 90 day activity
est restore	timely60_no90d_12 	
replace csremove_timely60_12=7 in 7
replace cscoef_timely60_12= timely60no90d[1,1] in 7
replace csci_lb_timely60_12= timely60no90d[5,1] in 7
replace csci_ub_timely60_12= timely60no90d[6,1] in 7	

*Excl no tx start in 6 months
est restore	timely60_no6m_12 	
replace csremove_timely60_12=8 in 8
replace cscoef_timely60_12= timely60no6m[1,1] in 8
replace csci_lb_timely60_12= timely60no6m[5,1] in 8
replace csci_ub_timely60_12= timely60no6m[6,1] in 8	
				
*Excl exempt size
est restore	timely60_nomin_12 	
replace csremove_timely60_12=9 in 9
replace cscoef_timely60_12= timely60nomin[1,1] in 9
replace csci_lb_timely60_12= timely60nomin[5,1] in 9
replace csci_ub_timely60_12= timely60nomin[6,1] in 9	
	
*Excl local PSL states
est restore	timely60_nolocal_12 	
replace csremove_timely60_12=10 in 10
replace cscoef_timely60_12= timely60nolocal[1,1] in 10
replace csci_lb_timely60_12= timely60nolocal[5,1] in 10
replace csci_ub_timely60_12= timely60nolocal[6,1] in 10	
	
*Excl PTO arm states
est restore	timely60_nopto_12 	
replace csremove_timely60_12=11 in 11
replace cscoef_timely60_12= timely60nopto[1,1] in 11
replace csci_lb_timely60_12= timely60nopto[5,1] in 11
replace csci_ub_timely60_12= timely60nopto[6,1] in 11	

*Make it easier to tweak output without rerunning regression
save "tempgraph.dta", replace
*Alt DVs
twoway (scatter cscoef_timely60_12 csremove_timely60_12) (rcap csci_ub_timely60_12 csci_lb_timely60_12 csremove_timely60_12) in 1/4, graphregion(color(white)) title("Alternative Outcomes") ytitle("Percent (%)") xtitle("Model") ///
legend(order(1 "ATT" 2 "95% CI")) scale(.75) yline(0) /*xlabel(1(1)8)*/ ///
xlabel(1 "60 days" 2 "45 days" 3 "30 days" 4 "14 days" , angle(35) labsize(medsmall)) 
graph save "${output}/CSindSensAltDV_${today}d.gph", replace
graph export "${output}/CSindSensAltDV_${today}d.jpg", as(jpg) replace

*Alt Samples

* Evenly spaced x positions for the models to show (skips 2-4)
capture drop xpos
gen xpos = .
local i = 1
foreach v in 1 5 6 7 8 9 10 11 {
    replace xpos = `i' if csremove_timely60_12 == `v'
    local ++i
}

twoway (scatter cscoef_timely60_12 xpos) ///
       (rcap csci_ub_timely60_12 csci_lb_timely60_12 xpos) ///
       if !missing(xpos), ///
       graphregion(color(white)) title("Alternative Samples") ///
       ytitle("Treatment within 60 days (%)") xtitle("Model") ///
       legend(order(1 "ATT" 2 "95% CI")) scale(.75) yline(0) ///
       xscale(range(0.5 8.5)) ///
       xlabel(1 "Main" 2 "Stage IV at Dx" 3 "Drop 2020+" ///
              4 "No EHR activity 90+ days" 5 "Excl. no tx in 6 months" ///
              6 "Excl. size except." 7 "Excl. states w/ local PSL" ///
              8 "Excl. PTO states", angle(35) labsize(medsmall))

drop xpos
graph save "${output}/CSindSens60d_${today}d.gph", replace
graph export "${output}/CSindSens60d_${today}d.jpg", as(jpg) replace

log close


*********************************

/*Run Individual C&S for each subpopulation of interest */


foreach table in all /*nl*/ {
	
/*Main regression and event study*/
log using "${output}/CSind_Strat_`table'_${today}d.log", replace
use "analyticsample_2026.09.03.dta", clear
count
	

*9/24/2026: multiply binary outcomes by 100 to get %s			
foreach x in timely60 /*time_days*/ timely45 timely30 timely14 ///
			/*demo_agedx */raceeth_1 raceeth_2 raceeth_3 raceeth_4 raceeth_5 female ///
			sesindex_1 sesindex_2 sesindex_3 sesindex_4 sesindex_5 sesindex_6 ///
			cohort_1 cohort_2 cohort_3 cohort_4 cohort_5 cohort_6 cohort_7 cohort_8 cohort_9 cohort_10  ///
			demo_edu_underHS_st demo_edu_HS_st demo_edu_somecoll_st demo_edu_coll_st demo_edu_grad_st ///
			ACA /*econ_unemploy_st*/ fmli ///
			/*covid_cases_cntysum covid_deaths_cdc_st */ covid_int covid_eps covid_sah {
			replace `x'=`x'*100
			tabstat `x', statistics(n mean min max)
			}
	*Make samples
	if "`table'"=="all" {
		local tabledesc "All stages"
		local tablepop ""
	}
	else {
		
		local tablepop "& localpsl!=1"
		local tabledesc "Exclude states with local PSL adoption. "
	}

display "C&S 18-64 NOT restricted to new diagnosis, Population: a1864 `tabledesc' "

foreach pop in a1864  hses lses1 wh bl oth  m f   ip1  mcaid1 self {
			*Set titles to all be blank
		if "`pop'"=="a1864" {
			local popdesc "Age 18-64"
			local demo "none"
			local w "1"
			local subpop "& demo_agegrp==2"
			local controls "i.cohort ${indiv}  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		
		else if "`pop'"=="hses" {
			local popdesc "Highest SES (top quintile)"
			local demo "ses"
			local w "10"
			local subpop "& sesindex_m==5"
			local controls "i.cohort ${indiv}  ${edu} ${policy} ${covid}"
			local ctrldesc "Cancer type, individual, education, area, COVID controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		else if "`pop'"=="lses1" {
			local popdesc "Lowest SES (bottom quintile)"
			local demo "ses"
			local w "11"
			local subpop "& sesindex_m==1"
			local controls "i.cohort ${indiv}  ${edu} ${policy} ${covid}"
			local ctrldesc "Cancer type, individual, education, area, COVID controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		
		else if "`pop'"=="wh" {
			local popdesc "NH White"
			local demo "race"
			local w "2"
			local subpop "& demo_raceeth==2"
			local controls "i.cohort demo_agedx i.demo_female  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		else if "`pop'"=="bl" {
			local popdesc "NH Black"
			local demo "race"
			local w "3"
			local subpop "& demo_raceeth==3"
			local controls "i.cohort demo_agedx i.demo_female  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		else if "`pop'"=="oth" {
			local popdesc "Hispanic/ Other race"
			local demo "race"
			local w "4"
			local subpop "& othrace==1"
			local controls "i.cohort demo_agedx i.demo_female  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
	
		else if "`pop'"=="m" {
			local popdesc "Male"
			local demo "sex"
			local w "8"
			local subpop "& demo_female==0"
			local controls "i.cohort demo_agedx i.demo_raceeth  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
		else if "`pop'"=="f" {
			local popdesc "Female"
			local demo "sex"
			local w "9"
			local subpop "& demo_female==1"
			local controls "i.cohort demo_agedx i.demo_raceeth  ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}

		else if "`pop'"=="ip1"  {
			local popdesc "Insurance: Commercial Health Plan"
			local demo "none"
			local w "5"
			local subpop "& ins_priv1==1"
			local controls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}		
		else if "`pop'"=="mcaid1" {
			local popdesc "Insurance: Medicaid"
			local demo  "none"
			local w "6"
			local subpop "& (ins_mcaid1==1)"
			local controls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}		
		else  {
			local popdesc "Insurance: Patient Assistance Program or Self-Pay"
			local demo  "none"
			local w "7"
			local subpop "& (ins_assist1==1|ins_self1==1)"
			local controls "i.cohort ${indiv} ${edu} ${policy} ${covid} i.sesindex_m"
			local ctrldesc "Cancer type, individual, education, area, COVID, SES quintiles controls.  Drop if treatment start # days>365 days. "
			local cnt 13
		}
	


			
	display "C&S 18-64 all diagnosis, Population: `pop' Table: `table'"

	
	foreach dv in timely30 timely14 timely45  timely60 time_days {
			if "`dv'" == "timely30" {
				local l "Treatment within 30 days  (%)"
			}
			else if "`dv'" == "timely14" {
				local l "Treatment within 14 days  (%)"
			}
			else if "`dv'" == "timely45" {
				local l "Treatment within 45 days  (%)"
			}
			else if "`dv'" == "timely60" {
				local l "Treatment within 60 days  (%)"
			}

			else {
				local l "# Days to treatment"
			}
			
			if "`pop'"=="a1864" {
			gen csremove_`dv'_`table'=.
			gen cscoef_`dv'_`table'=.
			gen csci_lb_`dv'_`table'=.
			gen csci_ub_`dv'_`table'=.
			}
			else {
			}
			
		display "Model iteration: C&S PSL type: pslst Table: `pop'  Time: year DV Type: `dv' "
		*Fernando: "you cant do state fixed effects, because state would be colinear with treatment. and weird things happen then. when using repeated crossection, you are not really adding individual "fixed effects", but instead cohort fixed effects"
		eststo `dv'_pslst_`pop'_`table': csdid `dv' `controls' if demo_agegrp==2  `subpop' `tablepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2
		display "eststo `dv'_pslst_`pop'_`table': csdid `dv' `controls' if demo_agegrp==2  `subpop' `tablepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2"
		estadd local comm "eststo `dv'_pslst_`pop'_`table': csdid `dv' `controls' if demo_agegrp==2  `subpop' `tablepop'  , cluster(state)  time(year) gvar(year_treat) method(reg) wboot long2" :  `dv'_pslst_`pop'_`table'

		estat simple
		matrix list r(table)
		matrix r = r(table)
		estadd scalar ATT=r[1,1]  : `dv'_pslst_`pop'_`table'
		estadd scalar ATTse=r[2,1]  : `dv'_pslst_`pop'_`table'
		estadd scalar ATTp=r[4,1]  : `dv'_pslst_`pop'_`table'
		estadd scalar ATTlowci=round(r[5,1],.001): `dv'_pslst_`pop'_`table' /*lower CI*/
		estadd scalar ATThighci=round(r[6,1],.001): `dv'_pslst_`pop'_`table' /*high CI*/
		replace csremove_`dv'_`table'=`w' in `w'
		replace cscoef_`dv'_`table'= r(table)[1,1] in `w'
		replace csci_lb_`dv'_`table'= r(table)[5,1] in `w'
		replace csci_ub_`dv'_`table'= r(table)[6,1] in `w'
		matrix drop r
		
		est restore `dv'_pslst_`pop'_`table'
		summarize `dv'  if e(sample)==1 & psl_state_arm==1 & psl_state_y==0, meanonly /*pretreatment dependent mean for treated geos only*/
		estadd scalar dependent_mean = r(mean) : `dv'_pslst_`pop'_`table'
		display e(dependent_mean)
		est restore `dv'_pslst_`pop'_`table'
		summarize psl_state_y if e(sample) == 1, meanonly
		estadd scalar mandate = r(mean) :  `dv'_pslst_`pop'_`table'
		
		/*Event study for C&S with controls*/	
		est restore `dv'_pslst_`pop'_`table'
		estat event, window(-6 5)
		csdid_plot, name(e_`dv'_pslst_`pop'_`table', replace)  ytitle("`l'") title("`l'", size(small))  style(rcap) xlabel(-7(1)5 ,labsize(small))  xline(-.5) legend(off) graphregion(color(white)) /*Unbinned endpoints*/
		graph save "e_`dv'_pslst_`pop'_`table'" "e_`dv'_pslst_`pop'_`table'_${today}.gph", replace
		
		
			}


/*Print C&S table*/
 esttab timely14_pslst_`pop'_`table' timely30_pslst_`pop'_`table' timely45_pslst_`pop'_`table' timely60_pslst_`pop'_`table' time_days_pslst_`pop'_`table' using "${output}/CS1864ind_`table'_`pop'_pslst_${today}d.html", `apprep' html label brackets cells(none) scalars("ATT ATT" "ATTse ATT SE" "ATTp ATT p-value" "ATTlowci ATT 95%CI LB" "ATThighci ATT 95%CI UB"  "N N" "dependent_mean Dependent Mean"  "mandate Mandate Mean" "comm Command") sfmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0fc %9.5f %9.5f %9.0g) noobs title("PSL & Timeliness, Flatiron, C&S individual repeated cross-sections, unbalanced panel. Drop if tx start >1 year. Treatment at year level. Age 18-64." "`psldesc'." "`pop'" "`ctrldesc'". "`popdesc'". "`tabledesc'". ) mtitle("14 days" "30 days" "45 days" "60 days" "Cont Diff. adv/met dx & tx start, >=-14 bottom coded at 0" ) alignment(center) star(+ 0.1 * 0.05 ** 0.01 *** 0.001)   addnotes( "Star levels: + 0.1 * 0.05 ** 0.01 *** 0.001" " " " " )

 
/*C&S Figure Event study combo*/
graph combine "e_timely14_pslst_`pop'_`table'_${today}.gph"  "e_timely30_pslst_`pop'_`table'_${today}.gph" "e_timely45_pslst_`pop'_`table'_${today}.gph"  "e_timely60_pslst_`pop'_`table'_${today}.gph" "e_time_days_pslst_`pop'_`table'_${today}.gph" , iscale(.4) ysize(10) xsize(10) commonscheme  cols(2) graphregion(color(white)) 
gr export "${output}/CSind_ev_pslst_`table'_`pop'_`table'_${today}.jpg", as(jpg) replace height(10000)

}
	eststo drop *


	
save "temp.dta", replace

li cscoef_timely60_all if !missing(cscoef_timely60_all)
foreach dv in timely30 timely14 timely45  timely60 time_days  {

		if "`dv'" == "timely30" {
				local l "Treatment within 30 days  (%)"
			}
			else if "`dv'" == "timely14" {
				local l "Treatment within 14 days  (%)"
			}
			else if "`dv'" == "timely45" {
				local l "Treatment within 45 days  (%)"
			}
			else if "`dv'" == "timely60" {
				local l "Treatment within 60 days  (%)"
			}
	else   {
		local l "# Days to treatment"
	}
	
	
twoway (scatter cscoef_`dv'_`table' csremove_`dv'_`table') (rcap csci_ub_`dv'_`table' csci_lb_`dv'_`table' csremove_`dv'_`table') in 1/11, graphregion(color(white)) title("`l'") ytitle("`l'") xtitle("Sub-group") ///
legend(order(1 "ATT" 2 "95% CI")) scale(.75) yline(0) /*xlabel(1(1)8)*/ ///
xlabel(1 "All" 2 "NH White" 3 "NH Black" 4 "Hispanic/ Other race" 5 "Commercial Ins" 6 "Medicaid" 7 "Self-Pay/ Assist" 8 "Male" 9 "Female" 10 "Highest SES" 11 "Lowest SES", angle(23) labsize(medsmall)) 
graph save "${output}/CSind1864STRAT_`table'_`dv'_${today}d.gph", replace
graph export "${output}/CSind1864STRAT_`table'_`dv'_${today}d.jpg", as(jpg) replace


}
capture log close

		}


/*Grab line of therapy that we want */


/*Use this when using Windows-mounted
cd "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Serena\working"
global path "\\vast.rde.missouri.edu\mp94p-lab\Flatiron\Data\Original"
sysdir set PLUS "\\vast.rde.missouri.edu\mp94p-lab\StataUserPackages"
*/


/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global path "/cluster/VAST/mp94p-lab/Flatiron/Data/Original"
sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"

global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")

log using "lineoftherapysetup_${today}d.log", replace

***************
/* Set up line of therapy (tested on CRC first, then looped)
patientid linename linenumber enhancedcohort startdate l1year l1month
*/
foreach cancer in CRC RCC Pancreatic NSCLC MetProstate MetastaticBreast Melanoma HeadNeck Gastric Bladder {
display "`cancer'"
use "${path}/`cancer'/LineOfTherapy.dta", clear
desc * 
ta linenumber
keep if linenumber==1

/*
*Will we lose people if we drop all the maintenance therapy? i.e. are there line 1 of therapy that are maintenance ONLY? - No we shouldn't
sort patientid linenumber ismaintenancetherapy
li if ismaintenancetherapy=="True" & patientid!=patientid[_n-1]
*/
keep if ismaintenancetherapy=="False"

gen actualdate=date(startdate,"YMD")
gen l1year=year(actualdate)
gen l1month=month(actualdate)
label var l1year "Line 1 start year"
label var l1month "Line 1 start month"

/*There are duplicates. Going with the earliest start date */
duplicates report patientid
duplicates tag patientid, generate(dup)
list if dup==3

*Only keep the first observation for each patient - i.e. earliest start date.
sort patientid actualdate 
keep if patientid!=patientid[_n-1]
duplicates report patientid

drop dup actualdate enddate ismaintenancetherapy regimenclass linesetting

save "`cancer'l1.dta", replace

}

***************
/*Append everything*/
use "CRCl1.dta", clear
append using "RCCl1.dta"
append using "Pancreaticl1.dta"
append using "NSCLCl1.dta"
append using "MetProstatel1.dta"
append using "MetastaticBreastl1.dta"
append using "Melanomal1.dta"
append using "HeadNeckl1.dta"
append using "Gastricl1.dta"
append using "Bladderl1.dta"

ta enhancedcohort, missing
ta linenumber, missing
ta l1year l1month, missing
compress
save "Line.dta", replace

log close
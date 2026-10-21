/*Program to map study status */

/*
/*Use this when using Windows-mounted*/
cd "Z:\Flatiron\Data\Serena\working"
global flatpath "Z:\Flatiron"
global labpath "Z:\"
global output "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/output/paper_final"
sysdir set PLUS "Z:\StataUserPackages"
sysdir set PERSONAL "Z:\StataUserPackages"
*/


/*Use this for Hellbender batch mode runs */
cd "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/working" 
global flatpath "/cluster/VAST/mp94p-lab/Flatiron"
global labpath "/cluster/VAST/mp94p-lab/"
global output "/cluster/VAST/mp94p-lab/Flatiron/Data/Serena/output/paper_final"
sysdir set PLUS "/cluster/VAST/mp94p-lab/StataUserPackages"
sysdir set PERSONAL "/cluster/VAST/mp94p-lab/StataUserPackages"


ssc install maptile, replace
maptile_install using "http://files.michaelstepner.com/geo_state.zip", replace

global today: display %tdCCYY.NN.DD =daily("`c(current_date)'", "DMY")
set linesize 255

log using "map_${today}d.log", replace
*Grab the treatment arm status straight from our analytic file to make sure it's reflective
use "analyticsample_2026.09.03.dta", clear

keep state psl_state_arm year_treat
duplicates drop

merge 1:1 state using "${labpath}/reusable_files/Working/state_names_fips.dta"

rename psl_state_arm status
label define status 0 "Never-adopting" 1 "Adopting" 2 "Excluded"
label values status status
ta status _merge, missing
replace status = 2 if _merge==2

drop _merge

replace year_treat=. if year_treat==0
save "flatironmap.dta", replace

*Make the map

*Get maptile installed and install the state geography file we need
*ssc install maptile
*h maptile
*maptile_install using "http://files.michaelstepner.com/geo_state.zip"

*Convert shape file
*shp2dta using "tl_2024_us_state/tl_2024_us_state", ///
data("statedata") coor("statecoor") genid(id) replace

use "statedata.dta", replace
destring STATEFP, replace
rename STATEFP state
ta id if inlist(state,72,69,78, 66, 60)
drop if inlist(state,72,69,78, 66, 60)

merge 1:1 state using "flatironmap.dta"
drop _merge


drop ALAND AWATER DIVISION FUNCSTAT INTPTLAT INTPTLON MTFCC REGION STATENS STUSPS
rename state statefips
rename stateabbrev state

*Check final data
ta status, missing
ta state status, missing
ta state year_treat, missing


save "flatironmapgeo.dta", replace
 
 *Map
maptile status, geo(state) ///
    cutvalues(0 1 2) ///
    fcolor(gs4 gs13 white) ///
    spopt(legend(order(2 "Never-adopting" ///
                       3 "Adopting" ///
                       4 "Excluded") ///
                size(*0.7)))
graph export "flatpolicymap.jpg", as(jpg) replace
 log close



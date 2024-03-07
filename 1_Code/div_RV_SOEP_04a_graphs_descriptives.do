********************************************************************************
** 						SOEP-RV: Graphics - Descriptives					  **
********************************************************************************

/*******************************************************************************
 Do-Files generates Graphs created with RV-SOEP Data:

	o Descriptive MP
	o Life Cycle Income
		- Raw Average
		- Average with Cohort FE
		- Raw Average by Cohort
	O Childbirths distance to Marriage info
	o Linked Partners
		- MEGPT_work  
		- MEGPT_work_rel_marr1
		- MEGPT_work_share
		- MEGPT_work_couple
	o Time-Use around Marriage
		- Collapse (absolute & relative)
		- Shares + Stagged
		- by Parental status
*******************************************************************************/

********************************************************************************
** Descriptive MP **
********************************************************************************
use "$datawork/mp_soeprv_women_all.dta", clear 
append using "$datawork/mp_soeprv_men_all.dta" 

** income [in 2015 €] **
global ep2015 = 35363 /*this is equivalent to 1 EP in 2015*/
gen income_monthly_2015EUR = MEGPT_work*$ep2015 /*monthly income in 2015€*/
gen income_annual_2015EUR = income_monthly_2015EUR*12 /*annual income in 2015€*/

local y = 12 /*yearly: 1; monthly: 12*/
local eventtime_min=`y'*5
local eventtime_max=`y'*10
	
keep if inrange(eventtime, -`eventtime_min', `eventtime_max') /*keep only relevant range of eventtime*/
	
**store N for subsample**
bys pid (monthly): gen n = 1 if _n==1 /*set 1 for 1st row of each couple*/
ereplace n = total(n) /*replace with sum*/
	
*******************
** Collapse data **
*******************
collapse (mean) MEGPT_work income_monthly_2015EUR n, by(eventtime sex)
sort eventtime sex

*****************
** Plot figure **
*****************
*sample size*
local N = n

*figure*
#delimit ; 
twoway 
	line MEGPT_work eventtime if sex==1, lcolor(orange) || 
	line MEGPT_work eventtime if sex==2, lcolor(navy) 
graphregion(color(white)) 
graphregion(color(white))
	xline(0, lcolor(cranberry)) 
	xtitle("Time relative to marriage (Months)") 
	xlabel(-`eventtime_min'(`y')`eventtime_max')
	ytitle("Mean sample income (EP)")  
	ylabel(0(0.01)0.1, grid angle(0))
	ttext(0 `eventtime_max' "N = `N'", placement(nw) justification(left) size(small))
	legend(order(1 "Men" 2 "Women") col(1) pos(7) ring(0) region(lstyle(none) lcolor(white)));
#delimit cr
graph export "$graphs_soeprv/mp_eventtime_descriptives_`outcome'.png", replace
graph export "$graphs_soeprv/mp_eventtime_descriptives_`outcome'.pdf", replace


********************************************************************************
** Life cycle graphs **
********************************************************************************

use "$datawork/soeprv_edited.dta", clear 

** income [in 2015 €] **
global ep2015 = 35363 /*this is equivalent to 1 EP in 2015*/
gen income_monthly_2015EUR = MEGPT_work*$ep2015 /*monthly income in 2015€*/
gen income_annual_2015EUR = income_monthly_2015EUR*12 /*annual income in 2015€*/

*********************************
** Raw averages (no cohort FE) **
*********************************

preserve

collapse (mean) income_annual_2015EUR, by(age female married_ever)

*Graph*
	#delimit ; 
	twoway 
		connected income_annual_2015EUR age if female==1 & married_ever==1 & inrange(age,20,60), lcolor(navy) msymbol(O) mcolor(navy) msize(small) || 
		connected income_annual_2015EUR age if female==1 & married_ever==0 & inrange(age,20,60), lcolor(navy) msymbol(Sh) mcolor(navy) msize(small)  ||
		connected income_annual_2015EUR age if female==0 & married_ever==1 & inrange(age,20,60), lcolor(orange) msymbol(O) mcolor(orange) msize(small) || 
		connected income_annual_2015EUR age if female==0 & married_ever==0 & inrange(age,20,60), lcolor(orange) msymbol(Sh) mcolor(orange) msize(small)
	graphregion(color(white)) 
		xtitle("Age") 
		ytitle("Annual Gross Earnings")  
		xlabel(20(10)60) 
		yscale(r(0 40000)) ylabel(0(10000)40000, format(%9.0fc) grid angle(0)) 
		legend(order(1 "Women - married" 2 "Women - unmarried" 3 "Men - married" 4 "Men - unmarried") col(2) region(lstyle(none) lcolor(white))) ;
	#delimit cr
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married.png", replace
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married.pdf", replace
	
restore

*****************************
** Averages with cohort FE **
*****************************

*Graph -- men vs women +  married vs not for all cohorts (with cohort FE)*
preserve

	capture drop income_predicted
	reghdfe income_monthly_2015EUR female##married_ever##age if inrange(age,20,60), a(birth_decade)
	predict income_predicted if e(sample)

	collapse (mean) income_predicted, by(age female married_ever)

	#delimit ; 
	twoway 
		connected income_predicted age if female==1 & married_ever==1 & inrange(age,20,60), lcolor(navy) msymbol(O) mcolor(navy) msize(small) || 
		connected income_predicted age if female==1 & married_ever==0 & inrange(age,20,60), lcolor(navy) msymbol(Sh) mcolor(navy) msize(small)  ||
		connected income_predicted age if female==0 & married_ever==1 & inrange(age,20,60), lcolor(orange) msymbol(O) mcolor(orange) msize(small) || 
		connected income_predicted age if female==0 & married_ever==0 & inrange(age,20,60), lcolor(orange) msymbol(Sh) mcolor(orange) msize(small)
	graphregion(color(white)) 
		xtitle("Age") 
		ytitle("Monthly Income")  
		xlabel(20(10)60) 
		yscale(r(0(1000)3000)) ylabel(0(1000)3000, format(%9.0fc) grid angle(0)) 
		legend(order(1 "Women - married" 2 "Women - unmarried" 3 "Men - married" 4 "Men - unmarried") col(2) region(lstyle(none) lcolor(white))) ;
	#delimit cr
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohortFE.png", replace
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohortFE.pdf", replace
	
restore


*Graph -- men vs women +  married vs not for cohorts <= 1955 (observed until 60)*
preserve

capture drop income_predicted
reghdfe income_monthly_2015EUR female##married_ever##age if inrange(age,20,60) & gebjahr<=1955, a(birth_decade)
predict income_predicted if e(sample)

collapse (mean) income_predicted, by(age female married_ever)

#delimit ; 
	twoway 
		connected income_predicted age if female==1 & married_ever==1 & inrange(age,20,60), lcolor(navy) msymbol(O) mcolor(navy) msize(small) || 
		connected income_predicted age if female==1 & married_ever==0 & inrange(age,20,60), lcolor(navy) msymbol(Sh) mcolor(navy) msize(small)  ||
		connected income_predicted age if female==0 & married_ever==1 & inrange(age,20,60), lcolor(orange) msymbol(O) mcolor(orange) msize(small) || 
		connected income_predicted age if female==0 & married_ever==0 & inrange(age,20,60), lcolor(orange) msymbol(Sh) mcolor(orange) msize(small)
	graphregion(color(white)) 
		xtitle("Age") 
		ytitle("Monthly Income")  
		xscale(r(20(10)60)) xlabel(20(10)60) 
		yscale(r(0(1000)3000)) ylabel(0(1000)3000, format(%9.0fc) grid angle(0)) 
		legend(order(1 "Women - married" 2 "Women - unmarried" 3 "Men - married" 4 "Men - unmarried") col(2) region(lstyle(none) lcolor(white))) 
		;
#delimit cr

graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohortspre1955.png", replace
graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohortspre1955.pdf", replace

restore 

****************************
** Raw averages by cohort **
****************************
preserve

collapse (mean) income_monthly_2015EUR, by(age female married_ever birth_decade)

qui sum income_monthly_2015EUR if inrange(age,20,60)

*Graph -- men vs women +  married vs not for every cohort*
forvalues cohort = 1930(10)1990 {
	#delimit ; 
	twoway 
		connected income_monthly_2015EUR age if female==1 & married_ever==1 & birth_decade==`cohort' & inrange(age,20,60), lcolor(navy) msymbol(O) mcolor(navy) msize(small) || 
		connected income_monthly_2015EUR age if female==1 & married_ever==0 & birth_decade==`cohort' & inrange(age,20,60), lcolor(navy) msymbol(Sh) mcolor(navy) msize(small)  ||
		connected income_monthly_2015EUR age if female==0 & married_ever==1 & birth_decade==`cohort' & inrange(age,20,60), lcolor(orange) msymbol(O) mcolor(orange) msize(small) || 
		connected income_monthly_2015EUR age if female==0 & married_ever==0 & birth_decade==`cohort' & inrange(age,20,60), lcolor(orange) msymbol(Sh) mcolor(orange) msize(small)
	graphregion(color(white)) 
		xtitle("Age") 
		ytitle("Monthly Income")  
		xscale(r(20(10)60)) xlabel(20(10)60) 
		yscale(r(0(1000)3000)) ylabel(0(1000)3000, format(%9.0fc) grid angle(0)) 
		legend(order(1 "Women - married" 2 "Women - unmarried" 3 "Men - married" 4 "Men - unmarried") col(2) region(lstyle(none) lcolor(white))) ;
	#delimit cr
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohort`cohort'.png", replace
	graph export "$graphs_soeprv/lifecycle_income_men_women_un_married_cohort`cohort'.pdf", replace
}	

*Graph -- every cohort for men/women married/unmarried*
forvalues female = 0/1 {
	forvalues married = 0/1 {
		#delimit ; 
		twoway 
			connected income_monthly_2015EUR age if birth_decade==1930 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("255 0 0") msymbol(circle) mcolor("255 0 0") msize(small) || 
			connected income_monthly_2015EUR age if birth_decade==1940 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("255 142 0") msymbol(circle) mcolor("255 142 0") msize(small)  ||
			connected income_monthly_2015EUR age if birth_decade==1950 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("255 255 0") msymbol(circle) mcolor("255 255 0") msize(small) || 
			connected income_monthly_2015EUR age if birth_decade==1960 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("0 142 0") msymbol(circle) mcolor("0 142 0") msize(small) || 
			connected income_monthly_2015EUR age if birth_decade==1970 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("0 192 192") msymbol(circle) mcolor("0 192 192") msize(small) || 
			connected income_monthly_2015EUR age if birth_decade==1980 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("64 0 152") msymbol(circle) mcolor("64 0 152") msize(small) || 
			connected income_monthly_2015EUR age if birth_decade==1990 & female==`female' & married_ever==`married' & inrange(age,20,60), lcolor("142 0 142") msymbol(circle) mcolor("142 0 142") msize(small)
		graphregion(color(white)) 
			xtitle("Age") 
			ytitle("Monthly Income")  
			xscale(r(20(10)60)) xlabel(20(10)60) 
			yscale(r(0(1000)3000)) ylabel(0(1000)3000, format(%9.0fc) grid angle(0)) 
			legend(order(1 "1930" 2 "1940" 3 "1950" 4 "1960" 5 "1970" 6 "1980" 7 "1990") row(2) region(lstyle(none) lcolor(white))) ;
		#delimit cr
		graph export "$graphs_soeprv/lifecycle_income_cohort`cohort'_female`female'married`married'.png", replace
		graph export "$graphs_soeprv/lifecycle_income_cohort`cohort'_female`female'married`married'.pdf", replace
	} //married
} //female
restore


********************************************************************************
** Distribution first child relative to marriage **
********************************************************************************
** Open data on marriage sample  **
use "$datawork/mp_soeprv_women_all.dta", replace
append using "$datawork/mp_soeprv_men_all.dta" 

gen dist_childbirth1_marr1_my=-dist_marr1_childbirth1_my
gen dist_childbirth1_marr1_y =-dist_marr1_childbirth1_y

	****************************************************************************
	** monthly **
	****************************************************************************

	preserve
	** collapsed data set over time relative to marriage **
	gen random=(marr1beginmy_random_soep!=0 & child1birthmy_random!=0)
	collapse (count) rv_id if marr1beginmy_event_time==0 & n_children>0 /*[pw=())]*/, by( dist_childbirth1_marr1_my random)

	sort dist_childbirth1_marr1_my

	**sum irregardless of random status
	rename rv_id marr_random
	bys  dist_childbirth1_marr1_my: egen marr_sum=sum(marr_random)

	**share of marriages
	egen sum_all = total(marr_random)
	bys random: egen sum_random = total(marr_random)
	gen  share_all = marr_sum/sum_all
		/*have the share for all only in one row for t b/c we want to sum for cdf inm the next step*/
		gen help=1
		bys dist_childbirth1_marr1_my (random): replace help=sum(help)
		replace share_all=. if help==2
		replace marr_sum=. if help==2
	*By random info
	gen  share_random = marr_random/sum_random
	
	sort dist_childbirth1_marr1_my random 
	**cdf for share of marriages
	gen share_all_cdf = sum(share_all) 
	bys random (dist_childbirth1_marr1_my): gen share_random_cdf = sum(share_random) 

	sort dist_childbirth1_marr1_my random 

	**************
	*** Graphs ***
	**************

	foreach sample in all months_observed months_random {
		if "`sample'" == "all" {
			local var_abs = "marr_sum"
			local var_rel = "share_all"
			local var_cdf = "share_all_cdf"
			local ifsample = ""
		}
		if "`sample'" == "months_observed" {
			local var_abs = "marr_random"
			local var_rel = "share_random"
			local var_cdf = "share_random_cdf"
			local ifsample = "& random==0"
		}
		if "`sample'" == "months_random" {
			local var_abs = "marr_random"
			local var_rel = "share_random"
			local var_cdf = "share_random_cdf"
			local ifsample = "& random==1"
		}
		
		**********************
		** absolute numbers **
		**********************
		#delimit ;
		twoway bar `var_abs' dist_childbirth1_marr1_my if inrange(dist_childbirth1_marr1_my, -60, 120) `ifsample',
				barwidth(1) fcolor(teal%20) lcolor(teal%20)
				graphregion(color(white)) 
				/*X-Axis*/
				xtitle("Months Relative to Marriage") 
				xline(0 /*8*/, lcolor(teal) lpattern(-)) /*two lines indicate time range where mother was pregnant at marriage*/
				xlabel(-60(12)120, angle(45) grid)
				/*Y-Axis*/
				ytitle("N births") ylabel(, angle(0) format(%9.0fc));
		#delimit cr		
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'.png", replace
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'.pdf", replace
		
		***********
		** share **
		***********
		#delimit ;
		twoway bar `var_rel' dist_childbirth1_marr1_my if  inrange(dist_childbirth1_marr1_my, -60, 120) `ifsample',
				barwidth(1) fcolor(teal%20) lcolor(teal%20)
				graphregion(color(white)) 
				/*X-Axis*/
				xtitle("Months Relative to Marriage") 
				xline(0 /*8*/, lcolor(teal) lpattern(-)) /*two lines indicate time range where mother was pregnant at marriage*/
				xlabel(-60(12)120, angle(45) grid)
				/*Y-Axis*/
				ytitle("Share of births") 
				ylabel(0(0.01)0.03, angle(0) format(%9.2fc));
		#delimit cr
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'_share.png", replace
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'_share.pdf", replace
		
		*********
		** cdf **
		*********
		#delimit ;
		twoway line `var_cdf' dist_childbirth1_marr1_my if inrange(dist_childbirth1_marr1_my, -60, 120) `ifsample',
				lcolor(teal)
				graphregion(color(white)) 
				/*X-Axis*/
				xtitle("Months Relative to Marriage") 
				xline(0 /*8*/, lcolor(teal) lpattern(-)) /*two lines indicate time range where mother was pregnant at marriage*/
				xlabel(-60(12)120, angle(45) grid)
				/*Y-Axis*/
				ytitle("cdf births") 
				ylabel(0(0.2)1, angle(0) format(%9.1fc));
		#delimit cr	
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'_share_cdf.png", replace
		graph export "$graphs_soeprv/N_births_monthly_marriage_1_`sample'_share_cdf.pdf", replace
		
	}

	save "$datawork/mp_soeprv_monthly_collapsed_child_age_marriage_1.dta", replace
	restore
	
	****************************************************************************
	** yearly **
	****************************************************************************

	preserve
	** collapsed data set over time relative to marriage **
	collapse (count) rv_id if marr1beginy_event_time==0 & n_children>0, by(dist_childbirth1_marr1_y)

	**sum irregardless of random status
	rename rv_id marr_sum

	**share of marriages
	egen sum_all = total(marr_sum)
	gen  share_all = marr_sum/sum_all
	
	sort dist_childbirth1_marr1_y
	
	**cdf for share of marriages
	gen share_all_cdf = sum(share_all) 

	**************
	*** Graphs ***
	**************

	**********************
	** absolute numbers **
	**********************
	#delimit ;
	twoway bar marr_sum dist_childbirth1_marr1_y if inrange(dist_childbirth1_marr1_y, -5, 10),
			barwidth(1) fcolor(teal%20) lcolor(teal%20)
			graphregion(color(white)) 
			/*X-Axis*/
			xtitle("Years Relative to Marriage") 
			xline(0 , lcolor(teal) lpattern(-))
			xlabel(-5(1)10, grid)
			xscale(titlegap(1.5))
			/*Y-Axis*/
			ytitle("N births") ylabel(, angle(0) format(%9.0fc));
	#delimit cr		
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_yearly.png", replace
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_yearly.pdf", replace
	
	***********
	** share **
	***********
	#delimit ;
	twoway bar share_all dist_childbirth1_marr1_y if  inrange(dist_childbirth1_marr1_y, -5, 10),
			barwidth(1) fcolor(teal%20) lcolor(teal%20)
			graphregion(color(white)) 
			/*X-Axis*/
			xtitle("Years Relative to Marriage") 
			xline(0 , lcolor(teal) lpattern(-))
			xlabel(-5(1)10, grid)
			/*Y-Axis*/
			ytitle("Share of births") 
			ylabel(, angle(0) format(%9.2fc));
	#delimit cr
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_share_yearly.png", replace
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_share_yearly.pdf", replace
	
	*********
	** cdf **
	*********
	#delimit ;
	twoway line share_all_cdf dist_childbirth1_marr1_y if inrange(dist_childbirth1_marr1_y, -5, 10),
			lcolor(teal)
			graphregion(color(white)) 
			/*X-Axis*/
			xtitle("Years Relative to Marriage") 
			xline(0 , lcolor(teal) lpattern(-))
			xlabel(-5(1)10, grid)
			/*Y-Axis*/
			ytitle("cdf births") 
			ylabel(0(0.2)1, angle(0) format(%9.1fc));
	#delimit cr	
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_share_cdf_yearly.png", replace
	graph export "$graphs_soeprv/N_births_monthly_marriage_1_all_share_cdf_yearly.pdf", replace
		

	save "$datawork/mp_soeprv_monthly_collapsed_child_age_marriage_1_yearly.dta", replace
	restore
	
********************************************************************************
** Linked Partners - Descriptive Graphs **
********************************************************************************
local y = 12 /*Monthly results: 12; Yearly results: 1*/
local eventtime_min=5*`y'
local eventtime_max=10*`y'

** loop over running vars (marriage, divorce) **
foreach eventtime in marr1beginmy_event_time_f /*marr1endmy_event_time_f*/ {
** loop over different outcomes **
foreach outcome in MEGPT_work MEGPT_work_rel_marr1 MEGPT_work_share MEGPT_work_couple {
				
	use "$datawork/mp_soeprv_linked_spouses_all", clear /*cp_soeprv_linked_spouses_all*/
				
	**********************
	** Sample selection **
	**********************
	
	**marital status**
	if "`eventtime'" == "marr1beginmy_event_time_f" {
		/*if event = marriage 1: drop when seperated = divorce-12 months*/
		drop if marr1endmy_event_time_f>=-1*`y' & !missing(marr1endmy_event_time_f)
	}
	if "`eventtime'" == "marr1endmy_event_time_f" {
		/*if event = divorce 1: drop pre marriage*/
		drop if marr1beginmy_event_time_f<0 
	}
	
	**constant N**
	keep if inrange(`eventtime', -`eventtime_min', `eventtime_max') /*keep only relevant range of eventtime*/
	
	**store N for subsample**
	bys pid_f (monthly): gen n = 1 if _n==1 /*set 1 for 1st row of each couple*/
	ereplace n = total(n) /*replace with sum*/
	
	*******************
	** Collapse data **
	*******************
	collapse (mean) `outcome'* n, by(`eventtime')

	*****************
	** Plot figure **
	*****************
	
	** locals for figure **
	*y-axis*
	if "`outcome'"=="MEGPT_work" {
		local ytitle = "Monthly wage income (EP)" 
		local ymin = 0
		local yinterval = 0.02
		local ymax = 0.1
	}
	if "`outcome'"=="MEGPT_work_rel_marr1" {
		local ytitle = "Monthly wage income relative to t-12" 
		local ymin = 0
		local yinterval = 0.2
		local ymax = 1.4
	}
	if "`outcome'"=="MEGPT_work_share" {
		local ytitle = "Income share spouses" 
		local ymin = 0
		local yinterval = 0.1
		local ymax = 1
	}
	if "`outcome'"=="MEGPT_work_couple" {
		local ytitle = "Total income spouses" 
		local ymin = 0.1
		local yinterval = 0.02
		local ymax = 0.18
	}
	*x-axis*
	if "`eventtime'" == "marr1beginmy_event_time_f" {
		local event = "marriage"
	}
	if "`eventtime'" == "marr1endmy_event_time_f" {
		local event = "divorce"
	} 
	*sample size*
	local N = n
	
	if "`outcome'" != "MEGPT_work_couple" {
		*figure*
		#delimit ; 
		twoway 
			line `outcome'_m `eventtime', lcolor(orange) || 
			line `outcome'_f `eventtime', lcolor(navy) 
		graphregion(color(white)) 
		graphregion(color(white))
			xline(0, lcolor(cranberry)) 
			xtitle("Time relative to `event' (Months)") 
			xlabel(-`eventtime_min'(24)`eventtime_max', grid)
			ytitle("`ytitle'")  
			yscale(r(`ymin'(`yinterval')`ymax')) 
			ylabel(`ymin'(`yinterval')`ymax', grid angle(0))
			ttext(`ymin' `eventtime_max' "N = `N'", placement(nw) justification(left) size(small))
			legend(order(1 "Men" 2 "Women") col(1) pos(7) ring(0) region(lstyle(none) lcolor(white)));
		#delimit cr
		graph export "$graphs_soeprv/soeprv_linked_spouses_`eventtime'_`outcome'_minus`eventtime_min'_plus`eventtime_max'.png", replace
		graph export "$graphs_soeprv/soeprv_linked_spouses_`eventtime'_`outcome'_minus`eventtime_min'_plus`eventtime_max'.pdf", replace
	}
	
	if "`outcome'" == "MEGPT_work_couple" {
		*figure*
		#delimit ; 
		twoway 
			line `outcome' `eventtime', lcolor(green) 
		graphregion(color(white)) 
		graphregion(color(white))
			xline(0, lcolor(cranberry)) 
			xtitle("Time relative to `event' (Months)") 
			xlabel(-`eventtime_min'(24)`eventtime_max', grid)
			ytitle("`ytitle'")  
			yscale(r(`ymin'(`yinterval')`ymax')) 
			ylabel(`ymin'(`yinterval')`ymax', grid angle(0))
			ttext(`ymin' `eventtime_max' "N = `N'", placement(nw) justification(left) size(small))
			legend(order(1 "Men" 2 "Women") col(1) pos(7) ring(0) region(lstyle(none) lcolor(white)));
		#delimit cr
		graph export "$graphs_soeprv/soeprv_linked_spouses_`eventtime'_`outcome'.png", replace
		graph export "$graphs_soeprv/soeprv_linked_spouses_`eventtime'_`outcome'.pdf", replace
	} 
		
	} // outcome
} // eventtime

********************************************************************************
** Time Use Graphs **
********************************************************************************
use "$datawork/mp_soeprv_timeuse.dta", clear 
/*
foreach task in work carework {
	by rv_id: gen `task'_rel = `task'_hours if eventtime == -12
	by rv_id: ereplace `task'_rel = mean(`task'_rel)
	
	gen `task'_change = (`task'_hours - `task'_rel) /`task'_rel
}
*/

*how to treat zeros?
global tasks "labourwork housework child leisure sleep"
keep if inrange(eventtime, -5, 10)
collapse *_hours, by (eventtime female)

sort female eventtime

***************************
* Absolut - all - Weekday *
***************************

foreach task of global tasks {

#delimit ; 
twoway 
	line `task'_wd_hours eventtime if female==0, lcolor(orange) lwidth(medsmall) || 
	line `task'_wd_hours eventtime if female==1, lcolor(navy) lwidth(medsmall)
, graphregion(color(white)) 
	xline(-0.5, lcolor(cranberry)) 
	yline(0, lstyle(grid)) 
	xtitle("Time relative to Marriage (Years)") 
	ytitle("Hours spend on `task' on Weekday")  
	xlabel(-5(1)10) xscale(titlegap(1.5))
	legend(order(1 "Men" 2 "Women") col(2) region(lstyle(none) lcolor(white))) 
	;
#delimit cr

graph export "$graphs_soeprv/mp_timeuse_absolut_`task'.png", replace
graph export "$graphs_soeprv/mp_timeuse_absolut_`task'.pdf", replace

}


*******************************
* Absolut - stagged - Weekday *
*******************************
* cummulative values for graph
global tasks "labourwork housework carework leisure sleep"
gen labourwork_cum=labourwork_wd_hours
tokenize $tasks
forval i=2/5 {
	local l=`i'-1
	gen ``i''_cum=``l''_cum+``i''_wd_hours
}


/* Color palettes for area plots:
	orange (men):	"255 236 191" "255 209 114" "255 174 20" "255 127 0" "220 80 0"
	navy (women):  	"209 218 225" "100 118 145" "33 58 97" "11 26 40" "0 10 20"
	--> palettes go from lightest to darkest 
	--> for graphs with 4 colors, dismiss the first (lightest) color */ 
	local orange0 = "255 236 191" 
	local orange1 = "255 209 114" 
	local orange2 = "255 174  20" 
	local orange3 = "255 127   0" 
	local orange4 = "220  80   0"
	local navy0 = "218 228 241"
	local navy1 = "157 185 225"
	local navy2 = " 71 117 201"
	local navy3 = " 35  60 175"
	local navy4 = "  0   0 128"
    
local l=0
foreach gender in Men Women {
	if `l'==0 {
		local color = "orange"
	}
	if `l'==1 {
		local color = "navy"
	}
	#delimit ; 
	twoway 
		area leisure_cum carework_cum housework_cum labourwork_cum eventtime 
				if female==`l', 
				color("``color'1'" "``color'2'" "``color'3'" "``color'4'") ||
		scatteri 0 -0.5 20 -0.5, connect(l) msymbol(none) lpattern(line) lcolor(cranberry)
	, graphregion(color(white)) 
		xline(-0.5, lcolor(cranberry)) 
		xtitle("Time relative to Marriage (Years)") 
		ytitle("Hours spend")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		legend(order(1 "Leisure" 2 "Child & Other care" 3 "Housework" 4 "Work & Education") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/mp_timeuse_absolut_stagged_`gender'.png", replace
	graph export "$graphs_soeprv/mp_timeuse_absolut_stagged_`gender'.pdf", replace

	local l=`l'+1
}

**********
* Shares *
**********
* w/o sleep * 
egen day_hours=rowtotal(labourwork_wd_hours housework_wd_hours carework_wd_hours leisure_wd_hours)

foreach task of global tasks {
	gen `task'_share = `task'_wd_hours/day_hours
}

*change the variables for the graph
replace labourwork_share=labourwork_share*100
tokenize $tasks
forval i=2/5 {
	local l=`i'-1
	replace ``i''_share=``i''_share*100 +``l''_share
}

local l=0
foreach gender in Men Women {
	if `l'==0 {
		local color = "orange"
	}
	if `l'==1 {
		local color = "navy"
	}
	#delimit ; 
	twoway
		area labourwork_share eventtime  if female==`l', fcolor("``color'4'") lwidth(none) || 
		rarea labourwork_share housework_share eventtime  if female==`l', fcolor("``color'3'") lwidth(none) || 
		rarea housework_share carework_share eventtime  if female==`l', fcolor("``color'2'") lwidth(none) || 
		rarea carework_share leisure_share eventtime if female==`l', fcolor("``color'1'") lwidth(none) ||
		scatteri 0 -0.5 100 -0.5, connect(l) msymbol(none) lpattern(line) lcolor(cranberry)
	, graphregion(color(white)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to Marriage (Years)") 
		ytitle("Share of time Spend on Task")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(0(20)100)
		legend(order(1 "Leisure" 2 "Child & Other care" 3 "Housework" 4 "Work & Education") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/mp_timeuse_share_`gender'_nosleep.png", replace
	graph export "$graphs_soeprv/mp_timeuse_share_`gender'_nosleep.pdf", replace

	local l=`l'+1
}

******************************************
** Time Use Graphs - By Parental Status **
******************************************
use "$datawork/mp_soeprv_timeuse.dta", clear 

*how to treat zeros? - Smaler window due to smaller sample size
keep if inrange(eventtime, -3, 8)
collapse *_hours, by (eventtime childdummy female)

sort female childdummy eventtime  

/*We have three values for the child subsample: 
	- 1 (Children during Marriage or <=12 months earlier)
	- 0 (No children Ever)
	- . (Missing = Children >12 Months before or after divorce */
	
*********************
* Absolut - stagged *
*********************
* cummulative values for graph
gen labourwork_cum=labourwork_wd_hours
tokenize $tasks
forval i=2/5 {
	local l=`i'-1
	gen ``i''_cum=``l''_cum+``i''_wd_hours
}

*Parental Status
forval j=0/1 {

	local l=0
	
	*Gender
	foreach gender in Men Women {
		if `l'==0 {
			local color = "orange"
		}
		if `l'==1 {
			local color = "navy"
		}
		local title0 = "Childless `gender'"
		local title1 = "`gender' with Child"
		
		#delimit ; 
		twoway 
			area leisure_cum carework_cum housework_cum labourwork_cum eventtime if female==`l' & childdummy==`j', color("``color'1'" "``color'2'" "``color'3'" "``color'4'") ||
			scatteri 0 -0.5 16 -0.5, connect(l) msymbol(none) lpattern(line) lcolor(cranberry)
		, graphregion(color(white)) 
			xline(-0.5, lcolor(cranberry)) 
			xtitle("Time relative to Marriage (Years)") 
			ytitle("Hours spend")  
			title("`title`j''")
			xlabel(-3(1)8) xscale(titlegap(1.5))
			legend(order(1 "Leisure" 2 "Child & Other care" 3 "Housework" 4 "Work & Education") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_timeuse_absolut_stagged_`gender'_child`j'.png", replace
		graph export "$graphs_soeprv/mp_timeuse_absolut_stagged_`gender'_child`j'.pdf", replace

		local l=`l'+1
	} // gender 
} // j



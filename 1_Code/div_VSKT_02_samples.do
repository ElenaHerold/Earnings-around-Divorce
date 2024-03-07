*******************************************************************************
** VSKT: Generate (Sub-)Samples for later Analysis **
********************************************************************************

/*******************************************************************************
 This Do-File generates the samples used from the VSKTVA2015 Data.
 We use three main samples for our analysis:

 Marriage Penalty Sample:
	- Observations with divorce (this is when we can define marriages)
	- Observe for min. 4 before and 8 years after
	- Age 18-45 at marriage
	- Subsamples:
		o All women & men
		o By parental status for women
		o Women with Children during or 12 months before Marriage
		(we cannot do men b/c child info for men not reliable)
		
*******************************************************************************/
		
********************************************************************************
** 					 	 Marriage (Penalty) Sample							  **
********************************************************************************
	
	* keep only necessary variables *
	#delimit ;
	local varlist =	"case 
					 year monthly 
					 hrf
					 marriage_1_event_time marriage_1_event_time_y
					 marriage_1_date marriage_1_year marriage_1_date_decade age_marriage_1
					 lengthy_marriage_1 lengthm_marriage_1 d_marriage2
					 divorce_1_date divorce_1_year divorce_1_event_time_y
					 female
					 gbja age birth_decade
					 east_first east_marriage east_marriage_group
					 MEGPT_work SES_work
					 time_event_birth_child_* time_event_y_birth_child_*
					 child1_timing_marr_1 dist_marr1_childbirth1_y 
					 n_child_within_marriage_1 n_children
					 ktsd" 
					 ;
	#delimit cr 

	use `varlist' using "$datawork/sufvskt2015va_edited_mp_divorce_only.dta", clear 
	sort case monthly

	* Event Var *
	clonevar eventtime=marriage_1_event_time

	* Same Name for external margin *
	rename SES_work dummy_work

	* Restrictions *

	*Time before/after event
	local y=12
	bysort case: egen after  = max(eventtime)
	bysort case: egen before = min(eventtime) 
	*Necessary observation Window
	keep if before <= -4*`y' & after >= 8*`y'
	*Age 
	gen age_restr = .
	replace age_restr = 1 if eventtime == 0 & inrange(age, 18, 45)
	bysort case: egen eventage = max(age_restr) 
	drop if eventage==. 

	
	****************************************************************************
	** Subsamples **
	****************************************************************************

	**********
	* Gender *
	**********
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/mp_vskt_women_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/mp_vskt_men_all.dta", replace 
	restore
		
	
	*****************************
	* Women by parental Status  *
	*****************************
	
	/*In the VSKT data, children are not always covered. Particularly, there is 
	almost no data on children for men, because children are typically not  
	relevant for men's pension claims. This is why we can only differenciate by
	parental status for women. This means we CANNOT estimate the penalty point 
	estimate, b/c it requires male earnings as well. But we CAN compute the 
	coefficients for the event study dummies for women w/ & w/o children, b/c 
	that is independent of men. In addition, we plot the estimates for all men, 
	for illustration. 
	We restrict the sample of women to those whose pension accounts have been 
	checked already (Kontenklärung). This applies for the vast majority (98%) of 
	divorced women. To see this: "tab ktsd" (ktsd gives the year of the last 
	check with 0 indicating "no check yet" and 9999 indicating "check not 
	completed"; 2008 captures all years <= 2008).
	*/
	
	*****************
	* binary status * 
	*****************
	
	* Without children ever
	preserve
		keep if female==1 & child1_timing_marr_1==0 & ktsd>0 & ktsd<9999
		save "$datawork/mp_vskt_women_nochild.dta", replace
	restore
	* With 1st child during marriage (or 12 months earlier)
	preserve
		keep if female==1 & inlist(child1_timing_marr_1, 2, 3) & ktsd>0 & ktsd<9999
		save "$datawork/mp_vskt_women_withchild.dta", replace
	restore
	
	*************************
	* All 5 parental status *
	*************************

	forval n=0/4 {
		preserve
			keep if female==1 & child1_timing_marr_1==`n'
			save "$datawork/mp_vskt_women_childstatus`n'.dta", replace
		restore
	}

	****************************************************
	* Women years between 1st child and marriage *
	****************************************************

	forval n=-5/5 /*marriage 5 years before/after birth*/ {
		if `n' < 0 {
			local pos = -`n'
			local name = "minus`pos'"
		}
		if `n' >= 0 {
			local name = "`n'"
		}
		preserve
			keep if female==1 & dist_marr1_childbirth1_y==`n'
			save "$datawork/mp_vskt_women_years_marriage_birth_`name'.dta", replace
		restore
	}

	*************
	* east/west *
	*************
	
	local s=0
	foreach sex in men women {
		foreach var in east_first east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_vskt_`sex'_`var'`n'.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_vskt_`sex'_east_marriage_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	
	****************************
	* east/west - reunification*
	****************************
	
	local s=0
	foreach sex in men women {
		foreach var in east_first east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if gbja<1989 & marriage_1_year>1990 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_vskt_`sex'_`var'`n'_reunification.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if gbja<1989 & marriage_1_year>1990 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_vskt_`sex'_east_marriage_group`n'_reunification.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	*******************************
	* Maximum length of marriage  *
	*******************************
	
	foreach length in 10 15 20 {
		
		*Define necissary post-window length
		local min10=8
		local min15=12
		local min20=16
		
		* Women *
		preserve
			keep if before <= -4*12 & after >= `min`length''*12
			keep if female==1 & lengthy_marriage_1>`length'
			save "$datawork/mp_vskt_women_minmarrlength_`length'.dta", replace 
		restore 

		* Men *
		preserve
			keep if before <= -4*12 & after >= `min`length''*12
			keep if female==0 & lengthy_marriage_1>`length'
			save "$datawork/mp_vskt_men_minmarrlength_`length'.dta", replace 
		restore
	}
	
	
	
********************************************************************************
** 				 	 Marriage (Penalty) Sample - Yearly						  **
********************************************************************************
	collapse age birth_decade female east_first east_marriage east_marriage_group  marriage_1_event_time_y time_event_y_birth_child_1 time_event_y_birth_child_2 time_event_y_birth_child_3 MEGPT_work before after lengthy_marriage_1 marriage_1_year dummy_work gbja marriage_1_date marriage_1_date_decade age_marriage_1 divorce_1_date divorce_1_year divorce_1_event_time_y d_marriage2, by(year case) 
	
	*adjust variables*
	/*dummy = 1 if work for >= 1 month in given year*/
	replace dummy_work=(dummy_work>0 & !missing(dummy_work))
	/*Age: round to full years for FE (biological age already rounded to end of year age)*/
	replace age=ceil(age)
	
	**********
	* Gender *
	**********
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/mp_vskt_yearly_women_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/mp_vskt_yearly_men_all.dta", replace 
	restore
	
	*************
	* east/west *
	*************
	
	local s=0
	foreach sex in men women {
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_vskt_yearly_`sex'_east_marriage_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	****************************
	* east/west - reunification*
	****************************	
	local s=0
	foreach sex in men women {
		foreach var in east_first east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if gbja<1989 & marriage_1_year>1990 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_vskt_yearly_`sex'_`var'`n'_reunification.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if gbja<1989 & marriage_1_year>1990 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_vskt_yearly_`sex'_east_marriage_group`n'_reunification.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	********************
	* Divorce groups   *
	********************
	gen marr1_divorced_g=.
		replace marr1_divorced_g=1 if inrange(lengthy_marriage_1, 0, 5) & d_marriage2 == 0 /*no second marriage*/
		replace marr1_divorced_g=2 if inrange(lengthy_marriage_1, 6, 10) & d_marriage2 == 0
		replace marr1_divorced_g=3 if lengthy_marriage_1>10	& d_marriage2 == 0
	
	local s=0
	foreach sex in men women {
		forval n=1/3 {
			preserve
				keep if female==`s' & marr1_divorced_g==`n'
				save "$datawork/mp_vskt_yearly_`sex'_divorced_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	gen marr1_divorced_g2=.
		replace marr1_divorced_g2=1 if inrange(lengthy_marriage_1, 0, 5)
		replace marr1_divorced_g2=2 if inrange(lengthy_marriage_1, 6, 10)
		replace marr1_divorced_g2=3 if inrange(lengthy_marriage_1, 10, 20)
		replace marr1_divorced_g2=4 if lengthy_marriage_1>20
	
	local s=0
	foreach sex in men women {
		forval n=1/4 {
			preserve
				keep if female==`s' & marr1_divorced_g2==`n'
				save "$datawork/mp_vskt_yearly_`sex'_divorced_group`n'_2.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	*******************************
	* Maximum length of marriage  *
	*******************************
	
	foreach length in 10 15 20 {
		
		*Define necissary post-window length
		local min10=8
		local min15=12
		local min20=16
		
		* Women *
		preserve
			keep if before <= -4*12 & after >= `min`length''*12
			keep if female==1 & lengthy_marriage_1>`length'
			save "$datawork/mp_vskt_yearly_women_minmarrlength_`length'.dta", replace 
		restore 

		* Men *
		preserve
			keep if before <= -4*12 & after >= `min`length''*12
			keep if female==0 & lengthy_marriage_1>`length'
			save "$datawork/mp_vskt_yearly_men_minmarrlength_`length'.dta", replace 
		restore
	}
	

	
********************************************************************************
** 						 	 Divorce  Sample								  **
********************************************************************************

	* keep only necessary variables *
	#delimit ;
	local varlist =	"case 
					 year monthly 
					 divorce_1_event_time 
					 divorce_1_date divorce_1_date_decade age_divorce_1 d_marriage2
					 female
					 gbja age birth_decade
					 MEGPT_work SES_work
					 n_children lengthm_marriage_1
					 ktsd" 
					 ;
	#delimit cr 
	/*Maybe add child1_timing_marr_1*/


	use `varlist' using "$datawork/sufvskt2015va_edited_mp_divorce_only.dta", clear 
	sort case monthly

	* Event Var *
	clonevar eventtime=divorce_1_event_time

	* Same Name for external margin *
	rename SES_work dummy_work

	* Restrictions *

	*Time before/after event
	local y=12
	bysort case: egen after  = max(eventtime)
	bysort case: egen before = min(eventtime) 
	*Necessary observation Window
	keep if before <= -4*`y' & after >= 8*`y'
	*Age 
	gen age_restr = .
	replace age_restr = 1 if eventtime == 0 & inrange(age, 25, 55)
	bysort case: egen eventage = max(age_restr) 
	drop if eventage==. 

	
	****************************************************************************
	** Subsamples **
	****************************************************************************

	**********
	* Gender *
	**********
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/dp_vskt_women_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/dp_vskt_men_all.dta", replace 
	restore

	*****************************
	* ....  *
	*****************************
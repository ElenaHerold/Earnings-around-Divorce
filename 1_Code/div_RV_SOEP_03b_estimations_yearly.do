********************************************************************************
** 					 SOEP-RV: Penalty Estimations - Yearly 					  **
********************************************************************************

/*******************************************************************************
This do-file estimates: 
	- Naive Marriage Penalties (yearly data)
	- Joint Marriage Penalties (yearly data)
	- Naive Child Penalties (yearly data)
	- Joint Child Penalties (yearly data)
*******************************************************************************/

***********************
** Sub-Group Samples ** 
***********************
global s_basic "all"
global s_dec "only_intensive decomposition_varwd decomposition_varweekly decomposition_only_intensive_varwd decomposition_only_intensive_varweekly"
global s_divorce "divorced0 divorced1 divorced_group1 divorced_group2 divorced_group3"
global s_decade "marriage_decade1950 marriage_decade1960 marriage_decade1970 marriage_decade1980 marriage_decade1990 marriage_decade2000 marriage_decade2010"
global s_age "marriage_agegroup3_1 marriage_agegroup3_2 marriage_agegroup3_3"
global s_region "east_first0 east_first1 east_first0_bornpre_marrpost east_first1_bornpre_marrpost east_marriage0 east_marriage1 east_marriage_group1 east_marriage_group2 east_marriage_group3 east_marriage_group4"
global s_region_cp "east_first0 east_first1 east_first0_bornpre_childpost east_first1_bornpre_childpost"
global s_norm "gender_progressive1_0 gender_progressive1_1 gender_progressive2_0 gender_progressive2_1 gender_progressive3_0 gender_progressive3_1"
global s_month "decmarriage_0 decmarriage_1"
global s_edu "educationgroup_1 educationgroup_2 educationgroup_3 educationgroup_4"

********************************************************************************
** Naive Marriage Penalties - Yearly **
********************************************************************************
global samples "$s_basic"
global outcomes "MEGPT_work dummy_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
foreach age in age_bio age_bio_labor {
		if "`age'" == "age_bio" /*biological age*/ {
			local agevar = "age"
		}
		if "`age'" == "age_bio_labor" /*both ages*/ {
			local agevar = "age age_labor_market"
		}
		
		foreach sex in women men {
	
		use "$datawork/mp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		*yearly variables from SOEP
		capture drop eventtime 
		gen eventtime=marr1beginy_event_time
		
		gen time = syear

		gen var=`outcome'
		
		* reduce to important years
		keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
		
		*Creating Event Time Dummies and ommiting Period -1
		sort rv_id eventtime
		char eventtime[omit] `omit'
		xi i.eventtime
		
		*Regression & caluclated Coefficients
		reghdfe var _Ieventtime*, absorb(`agevar' time, save) vce(cluster rv_id) residuals
		predict var_p, xbd
		
		gen b  =0 if eventtime == `omit' /*point estiamte*/
		gen bL =0 if eventtime == `omit' /*CI lower bound*/
		gen bH =0 if eventtime == `omit' /*CI upper bound*/
	
		foreach i of numlist 1(1)`eventtime_range' {
			if `i' != `eventtime_min' +`omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
				replace b  =_b[_Ieventtime_`i']                           if eventtime==`i'-`eventtime_min'-1 
				replace bL =_b[_Ieventtime_`i']-1.96*_se[_Ieventtime_`i'] if eventtime==`i'-`eventtime_min'-1
				replace bH =_b[_Ieventtime_`i']+1.96*_se[_Ieventtime_`i'] if eventtime==`i'-`eventtime_min'-1
			} // i != `eventtime_min'
		} // i
		
		*Counterfactual= prediction - coefficient of period
		gen var_c  = var_p - b	
		gen var_cL = var_p - bL	
		gen var_cH = var_p - bH	
		
		*Collapsing & saving data 
		keep eventtime var_* b bL bH
		sort eventtime
		collapse var* b bL bH, by(eventtime)
		gen sample  = "`sample'"
		gen outcome = "`outcome'"
		gen sex     = "`sex'"
		
		tempfile mp_base_`sex'
		save "`mp_base_`sex''"
	}	//sex	
	
	***************
	** Penalties ** 
	***************
	
	use "`mp_base_women'", clear
	append using "`mp_base_men'"

	*Reshape data & calculate Penalty
	gen gap    = (var_p - var_c) /(var_c)
	gen boundL = (var_p - var_cL)/(var_c) // JE: Low
	gen boundH = (var_p - var_cH)/(var_c) // JE: High 
	keep b* var_* gap eventtime sex sample outcome
	reshape wide b* var_* gap, i(eventtime) j(sex, string)

	*Penalty (relates to female counterfactual income) *
	gen penal  = (bmen  - bwomen)/var_cwomen
	
	save "$datawork/mp_penalty_yearly_`sample'_`outcome'_`age'", replace
}	// age
}	//sample
}	//outcomes


********************************************************************************
** Joint Marriage Penalties - Yearly **
********************************************************************************
global outcomes "MEGPT_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_weekly_hours labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
global samples "$s_edu"
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
	foreach age in age_bio age_labor age_bio_labor {
		if "`age'" == "age_bio" /*biological age*/ {
			local agevar = "age"
		}
		if "`age'" == "age_labor" /*labor market age*/ {
			local agevar = "age_labor_market"
		}
		if "`age'" == "age_bio_labor" /*both ages*/ {
			local agevar = "age age_labor_market"
		}
	foreach sex in women men {
	
		use "$datawork/mp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		sort rv_id syear 
		
		qui sum syear
		gen time = syear - r(min) 
		
		/*now this is priliminary but i want to find a solution to the issue that we have two different variables we are testing*/
		if "`outcome'" == "labour_wd_hours" & inlist("`sample'", "decomposition_only_intensive_varweekly", "decomposition_varweekly") local outcome == `labour_weekly_hours'
		gen var=`outcome'
		
		*define max n children that are considered in this sample 
		if "`sample'" != "n_children1" & "`sample'" != "n_children2"  {
			global cmax = 3 /*take into account 3 children unless subsamples with <3 children*/
		}
		if "`sample'" == "n_children2" {
			global cmax 2
		}
		if "`sample'" == "n_children1" {
			global cmax 1
		}
		
		*define eventtime for marriage & child birth
		clonevar eventtime_m1 = marr1beginy_event_time
		forvalues n = 1/$cmax /*up to 3rd child*/ {
			clonevar eventtime_c`n' = child`n'birthy_event_time
		}
		
		* reduce to important years (wrt marriage)
		keep if inrange(eventtime_m1, -`eventtime_min', `eventtime_max')
		
		* summarize child eventtimes
		forvalues n = 1/$cmax /*up to 3rd child*/ {
			sum child`n'birthy_event_time
			scalar child`n'_zero_`sex' = -r(min) + 1
		}
		
		*Event Time Dummies for marriage and ommiting Period -1 year
		sort rv_id eventtime_m1
		char eventtime_m1[omit] `omit'
		xi i.eventtime_m1, prefix(_Im1) /*we add two more characters for prefix -->  this reduces varnames by two characters (_Imeventi_ instead of _Ieventime_)*/
			
		*Event Time Dummies for childbirth - omitting never children + time pre birth next older child
		forvalues n = 1/$cmax /*up to 3rd child*/ {
			replace eventtime_c`n' = 9999 if missing(eventtime_c`n') /*label missing child eventtime (= never children) with same value*/
			if `n' > 1 {
				local x = `n'-1 /*child before, e.g. for n=2 --> x=1*/
				replace eventtime_c`n' = 9999 if eventtime_c`x'<0 | eventtime_c`x'==9999 /*eventtime child n irrelevant as long as child x not yet born*/
			}
			sort rv_id eventtime_c`n' 
			char eventtime_c`n'[omit] 9999
			xi i.eventtime_c`n', prefix(_Ic`n')
		}
		
		sort rv_id eventtime_m1 /*sort by eventtime marriage*/
		
		*local with vars for reg
		local cvars = ""
		local cdummies = ""
		forvalues n = 1/$cmax /*up to 3rd child*/ {
			local cvars = "`cvars' c`n'"
			local cdummies = "`cdummies' _Ic`n'eventti*"
		}
		
		foreach event in m1 `cvars' /*m1 = marriage 1, cvars = c1/c2/c3 = 1st/2nd/3rd child */ {
			*min/max for renaming event dummies *
			tempvar min max 
			bys rv_id: egen `min' = min(eventtime_`event') if eventtime_`event' < 9999 
			bys rv_id: egen `max' = max(eventtime_`event') if eventtime_`event' < 9999 
			replace `min'=. if `max'<-10 /*don't account for event time if only pre birth & <-10 years pre*/
			replace `max'=. if `max'<-10 
			replace `min'=. if `min'>10 /*don't account for event time if only post birth & >10 years post*/
			replace `max'=. if `min'>10 
			qui sum `min'
			local eventtime_min_`event' = - r(min)
			qui sum `max'
			local eventtime_max_`event' = r(max)
			local eventtime_range_`event' = `eventtime_max_`event'' + `eventtime_min_`event'' + 1
		} // event
		
		*Regression & calculated Coefficients
		eststo `outcome'`sex': reghdfe var _Im1eventti* `cdummies', absorb(`agevar' time, save) vce(cluster rv_id) residuals
			/*no "_" in the eststo b/c otherwise name too long for Stata*/
		predict var_p, xbd
	
		foreach event in m1 c1 c2 c3 {
			preserve
			
			gen b_`event'  = 0 if eventtime_`event' == `omit' /*point estiamte*/
			gen bL_`event' = 0 if eventtime_`event' == `omit' /*CI lower bound*/
			gen bH_`event' = 0 if eventtime_`event' == `omit' /*CI upper bound*/
			
			* marriage
			if "`event'" == "m1" {
			foreach i of numlist 1(1)`eventtime_range_`event'' {
				if `i' != `eventtime_min_`event'' + `omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i != `eventtime_min'
			} // i
			} //if m1
			
			* children
			if "`event'" == "c1" | "`event'" == "c2" | "`event'" == "c3" {
				foreach i of numlist 1(1)`eventtime_range_`event'' {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i
			} //if c1	

			
			*Counterfactual= prediction - coefficient of period --> this includes estimates for children!
			gen var_c_`event'  = var_p - b_`event'	
			gen var_cL_`event' = var_p - bL_`event'	
			gen var_cH_`event' = var_p - bH_`event'	
			
			*Collapsing & saving data 
			keep eventtime_`event' var_* b_* bL_* bH_* /*eventtime = marriage eventtime*/
			sort eventtime_`event'
			collapse var* b_* bL_* bH_*, by(eventtime_`event')
			gen sample  = "`sample'"
			gen outcome = "`outcome'"
			gen sex     = "`sex'"
			gen event    = "`event'"
			tempfile mp_base_`sex'_`event'
			save "`mp_base_`sex'_`event''"
			
			restore
		} // event
	}	//sex	
	
	************************************************
	** Table with ES regressions -- within sample **
	************************************************
	#delimit ;
	/*Combine women & men to 1 table for each output & sample*/
	estout `outcome'women `outcome'men
		/*Latex Output*/
		using "$tables_soeprv/es_mp_yearly_`outcome'_`sample'_controlchildtime_`age'.tex", replace
		style(tex)
		/*Define output for Cells (beta + stars + SE)*/
		cells(b(star fmt(4)) se(par fmt(4))) 
		/*Rename Models for column headings*/
		mlabels("women" "men", none)
		/*Remove other col labels*/
		collabels(,none)
		/*Add R2 and N*/
		stats(r2 N, fmt(4 0) labels("R2" "N"))
		/*Define sign. level & symbols*/
		starlevels("\(^{*}\)" 0.1 "\(^{**}\)" 0.05 "\(^{***}\)" 0.01) 
	;
	#delimit cr
	
	***************
	** Penalties ** 
	***************
	foreach event in m1 c1 c2 c3 {
		use "`mp_base_women_`event''", clear
		append using "`mp_base_men_`event''"

		*Reshape data & calculate Penalty
		gen gap_`event'    = (var_p - var_c_`event') /(var_c_`event')
		gen boundL_`event' = (var_p - var_cL_`event')/(var_c_`event') // JE: Low
		gen boundH_`event' = (var_p - var_cH_`event')/(var_c_`event') // JE: High 
		keep b_`event' bH_`event' bL_`event' var_c_`event' var_cL_`event' var_cH_`event' var_p gap_`event' boundL_`event' boundH_`event' eventtime_`event' sex sample event outcome
		reshape wide b_`event' bH_`event' bL_`event' var_c_`event' var_cL_`event' var_cH_`event' var_p gap_`event' boundL_`event' boundH_`event', i(eventtime_`event') j(sex, string)

		*Penalty (relates to female counterfactual income) *
		gen penal_`event'  = (b_`event'men  - b_`event'women)/var_c_`event'women
				
		* Rename variables for appending later
		rename eventtime_`event' eventtime
		
		* save event and outcome specific data
		save "$datawork/mp_penalty_yearly_`sample'_`outcome'_`event'_controlchildtime_`age'", replace

		} // event
	} // age
	}	//sample
}	//outcomes


********************************************************************************
** Naive Child Penalties (only first child) - Yearly **
********************************************************************************
global outcomes "MEGPT_work dummy_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
global samples all
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
	foreach sex in women men {
	
		use "$datawork/cp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		*yearly variables from SOEP
		capture drop eventtime 
		gen eventtime=child1birthy_event_time
		
		gen time = syear

		gen var=`outcome'
		
		* reduce to important years
		keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
		
		*Creating Event Time Dummies and ommiting Period -1
		sort rv_id eventtime
		char eventtime[omit] `omit'
		xi i.eventtime
		
		*Regression & caluclated Coefficients
		reghdfe var _Ieventtime*, absorb(age time, save) vce(cluster rv_id) residuals
		predict var_p, xbd
		
		gen b  =0 if eventtime == `omit' /*point estiamte*/
		gen bL =0 if eventtime == `omit' /*CI lower bound*/
		gen bH =0 if eventtime == `omit' /*CI upper bound*/
	
		foreach i of numlist 1(1)`eventtime_range' {
			if `i' != `eventtime_min' +`omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
				replace b  =_b[_Ieventtime_`i']                           if eventtime==`i'-`eventtime_min'-1 
				replace bL =_b[_Ieventtime_`i']-1.96*_se[_Ieventtime_`i'] if eventtime==`i'-`eventtime_min'-1
				replace bH =_b[_Ieventtime_`i']+1.96*_se[_Ieventtime_`i'] if eventtime==`i'-`eventtime_min'-1
			} // i != `eventtime_min'
		} // i
		
		*Counterfactual= prediction - coefficient of period
		gen var_c  = var_p - b	
		gen var_cL = var_p - bL	
		gen var_cH = var_p - bH	
		
		*Collapsing & saving data 
		keep eventtime var_* b bL bH
		sort eventtime
		collapse var* b bL bH, by(eventtime)
		gen sample  = "`sample'"
		gen outcome = "`outcome'"
		gen sex     = "`sex'"
		
		tempfile cp_base_`sex'
		save "`cp_base_`sex''"
	}	//sex	
	
	***************
	** Penalties ** 
	***************
	
	use "`cp_base_women'", clear
	append using "`cp_base_men'"

	*Reshape data & calculate Penalty
	gen gap    = (var_p - var_c) /(var_c)
	gen boundL = (var_p - var_cL)/(var_c) // JE: Low
	gen boundH = (var_p - var_cH)/(var_c) // JE: High 
	keep b* var_* gap eventtime sex sample outcome
	reshape wide b* var_* gap , i(eventtime) j(sex, string)

	*Penalty (relates to female counterfactual income) *
	gen penal  = (bmen  - bwomen)/var_cwomen
	
	save "$datawork/cp_penalty_yearly_`sample'_`outcome'", replace
}	//sample
}	//outcomes

********************************************************************************
** Naive Child Penalties (child 1, 2, 3) - Yearly **
********************************************************************************
global outcomes "MEGPT_work dummy_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
global samples "all"
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
	foreach sex in women men {
	
		use "$datawork/cp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		qui sum syear
		gen time = syear - r(min) 

		gen var=`outcome'

		*define eventtime for marriage & child birth
		forvalues n = 1/3 {
			clonevar eventtime_c`n' = child`n'birthy_event_time
		}
		
		* reduce to important years (wrt first child)
		keep if inrange(eventtime_c1, -`eventtime_min', `eventtime_max') //take out to have later children

		*Event Time Dummies for childbirth1 and ommiting Period -1 year
		char eventtime_c1[omit] `omit'
		xi i.eventtime_c1, prefix(_Ic1) 
		
		*Event Time Dummies for other events - omitting never 
		foreach n in c2 c3 {
			replace eventtime_`n' = 9999 if missing(eventtime_`n') /*label missing/never with same value*/
			
				replace eventtime_c2 = 9999 if eventtime_c1<=0 /*eventtime child n irrelevant as long as child x not yet born - really?*/
				replace eventtime_c3 = 9999 if eventtime_c2<=0 /*eventtime child n irrelevant as long as child x not yet born - really?*/

			sort rv_id eventtime_`n' 
			char eventtime_`n'[omit] 9999
			xi i.eventtime_`n', prefix(_I`n')
		}
		
		sort rv_id eventtime_c1 /*sort by eventtime child1*/
		
		*local with vars for reg
		local vars = "c2 c3"
		local dummies = "_Ic2eventti* _Ic3eventti*"
		
		foreach event in c1 c2 c3 {
			*min/max for renaming event dummies *
			tempvar min max 
			bys rv_id: egen `min' = min(eventtime_`event') if eventtime_`event' < 9999 
			bys rv_id: egen `max' = max(eventtime_`event') if eventtime_`event' < 9999 
			replace `min'=. if `max'<-10 /*don't account for event time if only pre birth & <-10 years pre*/
			replace `max'=. if `max'<-10 
			replace `min'=. if `min'>10 /*don't account for event time if only post birth & >10 years post*/
			replace `max'=. if `min'>10 
			qui sum `min'
			local eventtime_min_`event' = - r(min)
			qui sum `max'
			local eventtime_max_`event' = r(max)
			local eventtime_range_`event' = `eventtime_max_`event'' + `eventtime_min_`event'' + 1
		} // event
		
		
		*Regression & caluclated Coefficients
		reghdfe var _Ic1eventti* `dummies', absorb(age time, save) vce(cluster rv_id) residuals
		
		predict var_p, xbd
	
		foreach event in c1 c2 c3 {
			preserve
			
			* keep only range -5 - 10 for each eventage		
			gen b_`event'  = 0 if eventtime_`event' == `omit' /*point estiamte*/
			gen bL_`event' = 0 if eventtime_`event' == `omit' /*CI lower bound*/
			gen bH_`event' = 0 if eventtime_`event' == `omit' /*CI upper bound*/
			
			* main event
			if "`event'" == "c1" {
			foreach i of numlist 1(1)`eventtime_range_`event'' {
				if `i' != `eventtime_min_`event'' + `omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i != `eventtime_min'
			} // i
			} //if m1
			
			* others
			if "`event'" == "c2" | "`event'" == "c3" {
				foreach i of numlist 1(1)`eventtime_range_`event'' {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i
			} //if c1	

			
			*Counterfactual= prediction - coefficient of period --> this includes estimates for children!
			gen var_c_`event'  = var_p - b_`event'	
			gen var_cL_`event' = var_p - bL_`event'	
			gen var_cH_`event' = var_p - bH_`event'	
			
			*Collapsing & saving data 
			keep eventtime_`event' var_* b_* bL_* bH_* /*eventtime = marriage eventtime*/
			sort eventtime_`event'
			collapse var* b_* bL_* bH_*, by(eventtime_`event')
			gen sample  = "`sample'"
			gen outcome = "`outcome'"
			gen sex     = "`sex'"
			gen event    = "`event'"
			tempfile cp_base_`sex'_`event'
			save "`cp_base_`sex'_`event''"
			
			restore
		} // event
	}	//sex	
	
	
	***************
	** Penalties ** 
	***************
	foreach event in c1 c2 c3 {
		use "`cp_base_women_`event''", clear
		append using "`cp_base_men_`event''"

		*Reshape data & calculate Penalty
		gen gap_`event'    = (var_p - var_c_`event') /(var_c_`event')
		gen boundL_`event' = (var_p - var_cL_`event')/(var_c_`event') // JE: Low
		gen boundH_`event' = (var_p - var_cH_`event')/(var_c_`event') // JE: High 
		keep b* var* gap_`event' eventtime_`event' sex sample event outcome
		reshape wide b* var* gap_`event', i(eventtime_`event') j(sex, string)

		*Penalty (relates to female counterfactual income) *
		gen penal_`event'  = (b_`event'men  - b_`event'women)/var_c_`event'women
				
		* Rename variables for appending later
		rename eventtime_`event' eventtime
		
		* save event and outcome specific data
		save "$datawork/cp_penalty_yearly_`sample'_`outcome'_`event'_second_third_child", replace

		} // event
	}	//sample
}	//outcomes

********************************************************************************
** Joint Child Penalties Estimation (only first child) - yearly **
********************************************************************************
global outcomes "MEGPT_work dummy_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
global samples "all"
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
	foreach sex in women men {
	
		use "$datawork/cp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		qui sum syear
		gen time = syear - r(min) 

		gen var=`outcome'

		*define eventtime for marriage & child birth
		clonevar eventtime_m1 = marr1beginy_event_time
		clonevar eventtime_c1 = child1birthy_event_time		

		* reduce to important years (wrt first child)
		keep if inrange(eventtime_c1, -`eventtime_min', `eventtime_max') //take out to have later children

		*Event Time Dummies for childbirth1 and ommiting Period -1 year
		char eventtime_c1[omit] `omit'
		xi i.eventtime_c1, prefix(_Ic1) 
		
		*Event Time Dummies for other events - omitting never 
		foreach n in m1 {
			replace eventtime_`n' = 9999 if missing(eventtime_`n') /*label missing/never with same value*/
		
			sort rv_id eventtime_`n' 
			char eventtime_`n'[omit] 9999
			xi i.eventtime_`n', prefix(_I`n')
		}
		
		sort rv_id eventtime_c1 /*sort by eventtime child1*/
		
		*local with vars for reg
		local vars = "m1"
		local dummies = "_Im1eventti*"
		
		foreach event in m1 c1 {
			*min/max for renaming event dummies *
			tempvar min max 
			bys rv_id: egen `min' = min(eventtime_`event') if eventtime_`event' < 9999 
			bys rv_id: egen `max' = max(eventtime_`event') if eventtime_`event' < 9999 
			replace `min'=. if `max'<-10 /*don't account for event time if only pre birth & <-10 years pre*/
			replace `max'=. if `max'<-10 
			replace `min'=. if `min'>10 /*don't account for event time if only post birth & >10 years post*/
			replace `max'=. if `min'>10 
			qui sum `min'
			local eventtime_min_`event' = - r(min)
			qui sum `max'
			local eventtime_max_`event' = r(max)
			local eventtime_range_`event' = `eventtime_max_`event'' + `eventtime_min_`event'' + 1
		} // event
		
		
		*Regression & caluclated Coefficients
		reghdfe var _Ic1eventti* `dummies', absorb(age time, save) vce(cluster rv_id) residuals
		
		predict var_p, xbd
	
		foreach event in m1 c1 {
			preserve
			
			* keep only range -5 - 10 for each eventage		
			gen b_`event'  = 0 if eventtime_`event' == `omit' /*point estiamte*/
			gen bL_`event' = 0 if eventtime_`event' == `omit' /*CI lower bound*/
			gen bH_`event' = 0 if eventtime_`event' == `omit' /*CI upper bound*/
			
			* main event
			if "`event'" == "c1" {
			foreach i of numlist 1(1)`eventtime_range_`event'' {
				if `i' != `eventtime_min_`event'' + `omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i != `eventtime_min'
			} // i
			} //if m1
			
			* others
			if "`event'" == "m1" | "`event'" == "c2" | "`event'" == "c3" {
				foreach i of numlist 1(1)`eventtime_range_`event'' {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i
			} //if c1	

			
			*Counterfactual= prediction - coefficient of period --> this includes estimates for children!
			gen var_c_`event'  = var_p - b_`event'	
			gen var_cL_`event' = var_p - bL_`event'	
			gen var_cH_`event' = var_p - bH_`event'	
			
			*Collapsing & saving data 
			keep eventtime_`event' var_* b_* bL_* bH_* /*eventtime = marriage eventtime*/
			sort eventtime_`event'
			collapse var* b_* bL_* bH_*, by(eventtime_`event')
			gen sample  = "`sample'"
			gen outcome = "`outcome'"
			gen sex     = "`sex'"
			gen event    = "`event'"
			tempfile cp_base_`sex'_`event'
			save "`cp_base_`sex'_`event''"
			
			restore
		} // event
	}	//sex	
	
	
	***************
	** Penalties ** 
	***************
	foreach event in m1 c1 {
		use "`cp_base_women_`event''", clear
		append using "`cp_base_men_`event''"

		*Reshape data & calculate Penalty
		gen gap_`event'    = (var_p - var_c_`event') /(var_c_`event')
		gen boundL_`event' = (var_p - var_cL_`event')/(var_c_`event') // JE: Low
		gen boundH_`event' = (var_p - var_cH_`event')/(var_c_`event') // JE: High 
		keep b_`event' bH_`event' bL_`event' var_c_`event' gap_`event' boundL_`event' boundH_`event' eventtime_`event' sex sample event outcome
		reshape wide b_`event' bH_`event' bL_`event' var_c_`event' gap_`event' boundL_`event' boundH_`event', i(eventtime_`event') j(sex, string)

		*Penalty (relates to female counterfactual income) *
		gen penal_`event'  = (b_`event'men  - b_`event'women)/var_c_`event'women
				
		* Rename variables for appending later
		rename eventtime_`event' eventtime
		
		* save event and outcome specific data
		save "$datawork/cp_penalty_yearly_`sample'_`outcome'_`event'_controlmarriagetime", replace

		} // event
	}	//sample
}	//outcomes


********************************************************************************
** Joint Child Penalties Estimation (child 1, 2, 3) - yearly **
********************************************************************************
global outcomes "MEGPT_work dummy_work" /*MEGPT_work dummy_work gross_hourly_y_2015EUR gross_hourly_y gross_hour_2015EURsoep dummy_work labour_wd_hours labourwork_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours*/
global samples "all"
local eventtime_min=5
local eventtime_max=10
local eventtime_range=`eventtime_max'+`eventtime_min'+1
local omit -1

****************
** Regression ** 
****************
/*Run Regression for each (sub)group and outcome variables*/

foreach outcome of global outcomes {
foreach sample of global samples {
	foreach sex in women men {
	
		use "$datawork/cp_soeprv_`sex'_yearly_`sample'.dta", replace
		
		qui sum syear
		gen time = syear - r(min) 

		gen var=`outcome'

		*define eventtime for marriage & child birth
		clonevar eventtime_m1 = marr1beginy_event_time
		forvalues n = 1/3 {
			clonevar eventtime_c`n' = child`n'birthy_event_time
		}
		

		* reduce to important years (wrt first child)
		keep if inrange(eventtime_c1, -`eventtime_min', `eventtime_max') //take out to have later children

		*Event Time Dummies for childbirth1 and ommiting Period -1 year
		char eventtime_c1[omit] `omit'
		xi i.eventtime_c1, prefix(_Ic1) 
		
		*Event Time Dummies for other events - omitting never 
		foreach n in m1 c2 c3 {
			replace eventtime_`n' = 9999 if missing(eventtime_`n') /*label missing/never with same value*/
			
				replace eventtime_c2 = 9999 if eventtime_c1<=0 /*eventtime child n irrelevant as long as child x not yet born - really?*/
				replace eventtime_c3 = 9999 if eventtime_c2<=0 /*eventtime child n irrelevant as long as child x not yet born - really?*/

			sort rv_id eventtime_`n' 
			char eventtime_`n'[omit] 9999
			xi i.eventtime_`n', prefix(_I`n')
		}
		
		sort rv_id eventtime_c1 /*sort by eventtime child1*/
		
		*local with vars for reg
		local vars = "m1 c2 c3"
		local dummies = "_Im1eventti* _Ic2eventti* _Ic3eventti*"
		
		foreach event in m1 c1 c2 c3 {
			*min/max for renaming event dummies *
			tempvar min max 
			bys rv_id: egen `min' = min(eventtime_`event') if eventtime_`event' < 9999 
			bys rv_id: egen `max' = max(eventtime_`event') if eventtime_`event' < 9999 
			replace `min'=. if `max'<-10 /*don't account for event time if only pre birth & <-10 years pre*/
			replace `max'=. if `max'<-10 
			replace `min'=. if `min'>10 /*don't account for event time if only post birth & >10 years post*/
			replace `max'=. if `min'>10 
			qui sum `min'
			local eventtime_min_`event' = - r(min)
			qui sum `max'
			local eventtime_max_`event' = r(max)
			local eventtime_range_`event' = `eventtime_max_`event'' + `eventtime_min_`event'' + 1
		} // event
		
		
		*Regression & caluclated Coefficients
		reghdfe var _Ic1eventti* `dummies', absorb(age time, save) vce(cluster rv_id) residuals
		
		predict var_p, xbd
	
		foreach event in m1 c1 c2 c3 {
			preserve
			
			* keep only range -5 - 10 for each eventage		
			gen b_`event'  = 0 if eventtime_`event' == `omit' /*point estiamte*/
			gen bL_`event' = 0 if eventtime_`event' == `omit' /*CI lower bound*/
			gen bH_`event' = 0 if eventtime_`event' == `omit' /*CI upper bound*/
			
			* main event
			if "`event'" == "c1" {
			foreach i of numlist 1(1)`eventtime_range_`event'' {
				if `i' != `eventtime_min_`event'' + `omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i != `eventtime_min'
			} // i
			} //if m1
			
			* others
			if "`event'" == "m1" | "`event'" == "c2" | "`event'" == "c3" {
				foreach i of numlist 1(1)`eventtime_range_`event'' {
					replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
					replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
					replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1	
				} // i
			} //if c1	

			
			*Counterfactual= prediction - coefficient of period --> this includes estimates for children!
			gen var_c_`event'  = var_p - b_`event'	
			gen var_cL_`event' = var_p - bL_`event'	
			gen var_cH_`event' = var_p - bH_`event'	
			
			*Collapsing & saving data 
			keep eventtime_`event' var_* b_* bL_* bH_* /*eventtime = marriage eventtime*/
			sort eventtime_`event'
			collapse var* b_* bL_* bH_*, by(eventtime_`event')
			gen sample  = "`sample'"
			gen outcome = "`outcome'"
			gen sex     = "`sex'"
			gen event    = "`event'"
			tempfile cp_base_`sex'_`event'
			save "`cp_base_`sex'_`event''"
			
			restore
		} // event
	}	//sex	
	
	
	***************
	** Penalties ** 
	***************
	foreach event in m1 c1 c2 c3 {
		use "`cp_base_women_`event''", clear
		append using "`cp_base_men_`event''"

		*Reshape data & calculate Penalty
		gen gap_`event'    = (var_p - var_c_`event') /(var_c_`event')
		gen boundL_`event' = (var_p - var_cL_`event')/(var_c_`event') // JE: Low
		gen boundH_`event' = (var_p - var_cH_`event')/(var_c_`event') // JE: High 
		keep b_`event' bH_`event' bL_`event' var_c_`event' gap_`event' boundL_`event' boundH_`event' eventtime_`event' sex sample event outcome
		reshape wide b_`event' bH_`event' bL_`event' var_c_`event' gap_`event' boundL_`event' boundH_`event', i(eventtime_`event') j(sex, string)

		*Penalty (relates to female counterfactual income) *
		gen penal_`event'  = (b_`event'men  - b_`event'women)/var_c_`event'women
				
		* Rename variables for appending later
		rename eventtime_`event' eventtime
		
		* save event and outcome specific data
		save "$datawork/cp_penalty_yearly_`sample'_`outcome'_`event'_controlmarriagetime_second_third_child", replace

		} // event
	}	//sample
}	//outcomes

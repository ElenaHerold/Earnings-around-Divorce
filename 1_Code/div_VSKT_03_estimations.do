********************************************************************************
*							VSKTVA2015: Estimations							   *
********************************************************************************

/*******************************************************************************
This do-file estimates: 
	- Naive Marriage Penalties (monthly) - Men & Women
	- Naive Marriage Penalties (monthly) - Women Subgroups
	- Naive Marriage Penalties (yearly) - Men & Women
	- Linked Marriage Penalties (yearly) - Only Women
	- Divorce Penalties (monthly) - Men & Women
... using VSKTVA2015 data
*******************************************************************************/

***********************
** Sub-Group Samples ** 
***********************
global s_basic "all"
global s_children "withchild nochild childstatus0 childstatus1 childstatus2 childstatus3 childstatus4"
global s_birth "years_marriage_birth_minus5 years_marriage_birth_minus4 years_marriage_birth_minus3 years_marriage_birth_minus2 years_marriage_birth_minus1 years_marriage_birth_0 years_marriage_birth_1 years_marriage_birth_2 years_marriage_birth_3 years_marriage_birth_4 years_marriage_birth_5 "
global s_region "east_first0 east_first1 east_marriage0 east_marriage1 east_marriage_group1 east_marriage_group2 east_marriage_group3 east_marriage_group4"
global s_region_restr "east_first0_reunification east_first1_reunification east_marriage0_reunification east_marriage1_reunification east_marriage_group1_reunification east_marriage_group2_reunification east_marriage_group3_reunification east_marriage_group4_reunification"
global s_length "minmarrlength_10 minmarrlength_15 minmarrlength_20"
global s_divorce "divorced_group1 divorced_group2 divorced_group3 divorced_group1_2 divorced_group2_2 divorced_group3_2 divorced_group4_2"

********************************************************************************
** Naive Marriage Penalties  -- all women & men **
********************************************************************************
	global outcomes "MEGPT_work dummy_work"
	global samples "$s_basics"
	local eventtime_min=60
	local eventtime_max=120
	local eventtime_range=`eventtime_max'+`eventtime_min'+1
	local omit -12

	****************
	** Regression ** 
	****************
	/*Run Regression for each (sub)group and outcome variables*/

	foreach outcome of global outcomes {
		foreach sample of global samples  {
			foreach sex in women men {
	
				use "$datawork/mp_vskt_`sex'_`sample'.dta", replace
				
				qui sum monthly
				gen time = monthly - r(min) 

				gen var=`outcome'
				
				* reduce to important years
				keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
				
				*Creating Event Time Dummies and ommiting Period -1
				sort case eventtime
				char eventtime[omit] `omit'
				xi i.eventtime
				
				*Regression & caluclated Coefficients
				eststo `outcome'`sex': qui reghdfe var _Ieventtime*, absorb(age time, save) vce(cluster case) residuals
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
			
			************************************************
			** Table with ES regressions -- within sample **
			************************************************
			#delimit ;
			/*Combine women & men to 1 table for each output & sample*/
			estout `outcome'women `outcome'men
				/*Latex Output*/
				using "$tables_vskt/es_mp_`outcome'_`sample'.tex", replace
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
			
			use "`mp_base_women'", clear
			append using "`mp_base_men'"

			*Reshape data & calculate Penalty
			gen gap    = (var_p - var_c) /(var_c)
			gen boundL = (var_p - var_cL)/(var_c) // JE: Low
			gen boundH = (var_p - var_cH)/(var_c) // JE: High 
			keep b var_c gap boundL boundH eventtime sex sample outcome
			reshape wide b var_c gap boundL boundH, i(eventtime) j(sex, string)

			*Penalty (relates to female counterfactual income) *
			gen penal  = (bmen  - bwomen)/var_cwomen
			
			save "$datawork/mp_penalty_vskt_`sample'_`outcome'", replace
			
			}	//sample
		}	//outcomes


********************************************************************************
** Marriage Penalties  -- women only (subgroups) **
********************************************************************************
	global outcomes "MEGPT_work dummy_work"
	global samples "$s_children"
	local eventtime_min=60
	local eventtime_max=120
	local eventtime_range=`eventtime_max'+`eventtime_min'+1
	local omit -12

	****************
	** Regression ** 
	****************
	/*Run Regression for each (sub)group and outcome variables*/

	foreach outcome of global outcomes {
		foreach sample of global samples {
			foreach sex in women {
	
				use "$datawork/mp_vskt_`sex'_`sample'.dta", replace
				
				qui sum monthly
				gen time = monthly - r(min) 

				gen var=`outcome'
				
				* reduce to important years
				keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
				
				*Creating Event Time Dummies and ommiting Period -1
				sort case eventtime
				char eventtime[omit] `omit'
				xi i.eventtime
				
				*Regression & caluclated Coefficients
				eststo `outcome'`sex': qui reghdfe var _Ieventtime*, absorb(age time, save) vce(cluster case) residuals
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
			
			************************************************
			** Table with ES regressions -- within sample **
			************************************************
			#delimit ;
			/*Combine women & men to 1 table for each output & sample*/
			estout `outcome'women
				/*Latex Output*/
				using "$tables_vskt/es_mp_`outcome'_`sample'.tex", replace
				style(tex)
				/*Define output for Cells (beta + stars + SE)*/
				cells(b(star fmt(4)) se(par fmt(4))) 
				/*Rename Models for column headings*/
				mlabels("women", none)
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
			
			use "`mp_base_women'", clear
			
			*Reshape data & calculate Penalty
			gen gap    = (var_p - var_c) /(var_c)
			gen boundL = (var_p - var_cL)/(var_c) // JE: Low
			gen boundH = (var_p - var_cH)/(var_c) // JE: High 
			keep b var_c gap boundL boundH eventtime sex sample outcome
			
			reshape wide b var_c gap boundL boundH, i(eventtime) j(sex, string)
			
			*Penalty (relates to female counterfactual income) *
			save "$datawork/mp_penalty_vskt_`sample'_`outcome'_women", replace
			
			}	//sample
		}	//outcomes
		

********************************************************************************
** Naive Marriage Penalties -- yearly**
********************************************************************************
	local length 10
	global outcomes "MEGPT_work dummy_work"
	global samples "$s_lenght"
	local eventtime_min=5
	local eventtime_max=`length'
	local eventtime_range=`eventtime_max'+`eventtime_min'+1
	local omit -1

	****************
	** Regression ** 
	****************
	/*Run Regression for each (sub)group and outcome variables*/

	foreach outcome of global outcomes {
		foreach sample of global samples {
			foreach sex in women men {
	
				use "$datawork/mp_vskt_yearly_`sex'_`sample'.dta", replace
				
				qui sum year
				gen time = year - r(min) 

				gen var=`outcome'
				gen eventtime=marriage_1_event_time_y
				
				* reduce to important years
				keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
				
				*Creating Event Time Dummies and ommiting Period -1
				sort case eventtime
				char eventtime[omit] `omit'
				xi i.eventtime
				
				*Regression & caluclated Coefficients
				eststo `outcome'`sex': qui reghdfe var _Ieventtime*, absorb(age time, save) vce(cluster case) residuals
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
			
			************************************************
			** Table with ES regressions -- within sample **
			************************************************
			#delimit ;
			/*Combine women & men to 1 table for each output & sample*/
			estout `outcome'women
				/*Latex Output*/
				using "$tables_vskt/es_mp_yearly`outcome'_`sample'.tex", replace
				style(tex)
				/*Define output for Cells (beta + stars + SE)*/
				cells(b(star fmt(4)) se(par fmt(4))) 
				/*Rename Models for column headings*/
				mlabels("women", none)
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
			
			use "`mp_base_women'", clear
			append using "`mp_base_men'"
			
			*Reshape data & calculate Penalty
			gen gap    = (var_p - var_c) /(var_c)
			gen boundL = (var_p - var_cL)/(var_c) // JE: Low
			gen boundH = (var_p - var_cH)/(var_c) // JE: High 
			keep b var_c gap boundL boundH eventtime sex sample outcome
			
			reshape wide b var_c gap boundL boundH, i(eventtime) j(sex, string)
			
			*Penalty (relates to female counterfactual income) *
			save "$datawork/mp_penalty_vskt_yearly`length'_`sample'_`outcome'", replace
			
			}	//sample
		}	//outcomes
		
		
		
********************************************************************************
** Linked Marriage and Child Penalties  --  yearly **
********************************************************************************
	global outcomes "MEGPT_work"
	global samples "$s_divorce"
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
						      
			foreach sex in women {
	
				use "$datawork/mp_vskt_yearly_`sex'_`sample'.dta", replace
				
		
				gen time = year

				gen var=`outcome'

				*define max n children that are considered in this sample 
				local cmax = 0
				forval n=1/3{
					sum time_event_y_birth_child_`n'
					if `r(N)'!=0 {
						local cmax = 0+`n'
					}
					else {
						local cmax= `cmax'
					} 
				}
				
				*define eventtime for marriage & child birth
				clonevar eventtime_m1 = marriage_1_event_time_y
				forvalues n = 1/`cmax' /*up to 3rd child*/ {
					clonevar eventtime_c`n' = time_event_y_birth_child_`n'
				}
				
				
				* reduce to important years (wrt marriage)
				keep if inrange(eventtime_m1, -`eventtime_min', `eventtime_max')
				
				*Event Time Dummies for marriage and ommiting Period -1 year
				sort case eventtime_m1
				char eventtime_m1[omit] `omit'
				xi i.eventtime_m1, prefix(_Im1) /*we add two more characters for prefix -->  this reduces varnames by two characters (_Imeventi_ instead of _Ieventime_)*/
					
				*Event Time Dummies for childbirth - omitting never children + time pre birth next older child
				forvalues n = 1/`cmax' /*up to 3rd child*/ {
					replace eventtime_c`n' = 9999 if missing(eventtime_c`n') /*label missing child eventtime (= never children) with same value*/
					if `n' > 1 {
						local x = `n'-1 /*child before, e.g. for n=2 --> x=1*/
						replace eventtime_c`n' = 9999 if eventtime_c`x'<0 | eventtime_c`x'==9999 /**eventtime child n irrelevant as long as child x not yet born*/
					}
					sort case eventtime_c`n' 
					char eventtime_c`n'[omit] 9999
					xi i.eventtime_c`n', prefix(_Ic`n')
				}
				
				sort case eventtime_m1 /*sort by eventtime marriage*/
				
				*local with vars for reg
				local cvars = ""
				local cdummies = ""
				forvalues n = 1/`cmax' /*up to 3rd child*/ {
					local cvars = "`cvars' c`n'"
					local cdummies = "`cdummies' _Ic`n'eventti*"
				}
				
				foreach event in m1 `cvars' /*m1 = marriage 1, cvars = c1/c2/c3 = 1st/2nd/3rd child */ {
					*min/max for renaming event dummies *
					qui sum eventtime_`event' if eventtime_`event' < 9999 /*this excludes the never children value*/
					local eventtime_min_`event' = - r(min)
					local eventtime_max_`event' = r(max)
					local eventtime_range_`event' = `eventtime_max_`event'' + `eventtime_min_`event'' + 1
				
				} // event
				
				*Regression & caluclated Coefficients
				eststo `outcome'`sex': reghdfe var _Im1eventti* `cdummies', absorb(age time, save) vce(cluster case) residuals
					/*no "_" in the eststo b/c otherwise name too long for Stata*/
				predict var_p, xbd
				
				foreach event in m1 /*m1 = marriage 1*/ {
					gen b_`event'  = 0 if eventtime_`event' == `omit' /*point estiamte*/
					gen bL_`event' = 0 if eventtime_`event' == `omit' /*CI lower bound*/
					gen bH_`event' = 0 if eventtime_`event' == `omit' /*CI upper bound*/
					foreach i of numlist 1(1)`eventtime_range_`event'' {
						if `i' != `eventtime_min_`event'' +`omit' + 1 /*omitted: eventtime = `omit'  --> i = `eventtime_min' */ {
							replace b_`event'  =_b[_I`event'eventti_`i']                           		if eventtime_`event'==`i'-`eventtime_min_`event''-1 
							replace bL_`event' =_b[_I`event'eventti_`i']-1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
							replace bH_`event' =_b[_I`event'eventti_`i']+1.96*_se[_I`event'eventti_`i'] if eventtime_`event'==`i'-`eventtime_min_`event''-1
						} // i != `eventtime_min'
					} // i
				} // event
				
				*Counterfactual= prediction - coefficient of period --> this includes estimates for children!
				gen var_c  = var_p - b_m1	
				gen var_cL = var_p - bL_m1	
				gen var_cH = var_p - bH_m1	
				
				*Collapsing & saving data 
				keep eventtime_m1 var_* b_* bL_* bH_* /*eventtime = marriage eventtime*/
				sort eventtime_m1
				collapse var* b_* bL_* bH_*, by(eventtime_m1)
				gen sample  = "`sample'"
				gen outcome = "`outcome'"
				gen sex     = "`sex'"
				
				tempfile mp_base_`sex'
				save "`mp_base_`sex''"
			}	//sex	
			
			************************************************
			** Table with ES regressions -- within sample **
			************************************************
			#delimit ;
			/*Combine women & men to 1 table for each output & sample*/
			estout `outcome'women
				/*Latex Output*/
				using "$tables_vskt/es_mp_vskt_yearly_`outcome'_`sample'_controlchildtime.tex", replace
				style(tex)
				/*Define output for Cells (beta + stars + SE)*/
				cells(b(star fmt(4)) se(par fmt(4))) 
				/*Rename Models for column headings*/
				mlabels("women", none)
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
			
			use "`mp_base_women'", clear
			*append using "`mp_base_men'"

			*Reshape data & calculate Penalty
			gen gap    = (var_p - var_c) /(var_c)
			gen boundL = (var_p - var_cL)/(var_c) // JE: Low
			gen boundH = (var_p - var_cH)/(var_c) // JE: High 
			keep b_m1 var_c gap boundL boundH eventtime_m1 sex sample outcome
			reshape wide b_m1 var_c gap boundL boundH, i(eventtime_m1) j(sex, string)

			*Penalty (relates to female counterfactual income) *
			*gen penal  = (b_m1men  - b_m1women)/var_cwomen
			
			save "$datawork/mp_penalty_vskt_yearly_`sample'_`outcome'_controlchildtime", replace
			
		} // sample
	} //outcomes
	
		
********************************************************************************
** Divorce Eventstudy for Income **
********************************************************************************
	global outcomes "MEGPT_work"
	local eventtime_min=60
	local eventtime_max=120
	local eventtime_range=`eventtime_max'+`eventtime_min'+1
	local omit -12

	****************
	** Regression ** 
	****************
	/*Run Regression for each (sub)group and outcome variables*/

	foreach outcome of global outcomes {
		foreach sample in all /*add subsamples*/ {
			foreach sex in women men {
	
				use "$datawork/dp_vskt_`sex'_`sample'.dta", replace
				
				qui sum monthly
				gen time = monthly - r(min) 

				gen var=`outcome'
				
				* reduce to important years
				keep if inrange(eventtime, -`eventtime_min', `eventtime_max')
				
				*Creating Event Time Dummies and ommiting Period -1
				sort case eventtime
				char eventtime[omit] `omit'
				xi i.eventtime
				
				*Regression & caluclated Coefficients
				eststo `outcome'`sex':  reghdfe var _Ieventtime*, absorb(age time, save) vce(cluster case) residuals
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
			
			************************************************
			** Table with ES regressions -- within sample **
			************************************************
			#delimit ;
			/*Combine women & men to 1 table for each output & sample*/
			estout `outcome'women `outcome'men
				/*Latex Output*/
				using "$tables_vskt/es_dp_`outcome'_`sample'.tex", replace
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
			
			use "`mp_base_women'", clear
			append using "`mp_base_men'"

			*Reshape data & calculate Penalty
			gen gap    = (var_p - var_c) /(var_c)
			gen boundL = (var_p - var_cL)/(var_c) // JE: Low
			gen boundH = (var_p - var_cH)/(var_c) // JE: High 
			keep b bL bH var_c gap boundL boundH eventtime sex sample outcome
			reshape wide b bL bH var_c gap boundL boundH, i(eventtime) j(sex, string)

			*Penalty (relates to female counterfactual income) *
			gen penal  = (bmen  - bwomen)/var_cwomen
			
			save "$datawork/dp_penalty_vskt_`sample'_`outcome'", replace
			
			}	//sample
		}	//outcomes
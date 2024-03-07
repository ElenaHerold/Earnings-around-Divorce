********************************************************************************
** SOEP-RV: Generate (Sub-)Samples for later Analysis **
********************************************************************************

/*******************************************************************************
 This Do-File generates the samples used from the SOEP-RV Data.
 We use three main samples for our analysis:

 Marriage Penalty Sample:
	- Observations with marriage
	- Observe for min. 4 before and 8 years after
	- Age 18-45 at marriage
	- Subsamples:
		o By Parental status (Childless vs. Children during or 12 months before Marriage)
		o By all Parental status (Childless, children pre/during/post marriage)
		o By decade of marriage
		o By Age-group at marriage
		o By parents' co-habiting status
		o Yearly Samples
		
 Child Penalty Sample
	- Observations with first child birth
	- Observe for min. 4 before and 8 years after
	- Age 18-45 at marriage
	- Subsamples:
		o By Marital Status (Married Parents vs. Not-Married)
		o By Marital Status (Married Parents vs. Not-Married & Not-Single)
		o Yearly Samples

 Linked Partners Sample
	- Observations where we have both partners in SOEP und RV Data
	- Able to link spouses
	- Create marriage penalty sample
		o Subsamples: Female vs. Male Breadwinner
*******************************************************************************/
		
********************************************************************************
** 					 	 Marriage (Penalty) Sample							  **
********************************************************************************
* Chose necessary variables *
#delimit ;
local varlist =	"pid rv_id 
				 phrf_consent
				 syear monthly MONAT
				 partner *marr* 
				 female sex
				 gebjahr age birth_decade
				 pgpsbil pgcasmin
				 east_first east_born east_marriage east_marriage_group
				 gender_progressive*
				 child1_timing_marr_1 sumkids dist_child1_child2 dist_marr1_childbirth1_my n_children child_ever
				 child1birthm child1birthy child_birth_source_vskt
				 child1birthmy_event_time child2birthmy_event_time child3birthmy_event_time
				 child1birthy_event_time child2birthy_event_time child3birthy_event_time n_children child1_timing_marr_1 
				 child1birthmy_random child2birthmy_random child3birthmy_random
				 cohab* dist_marr1_cohab*
				 marr1_divorced marr1endmy marr1endmy_event_time 
				 marr1beginm marr1beginmy_random_soep marr1source_vskt
				 MEGPT_work_pre_marriage_1_group
				 grewup_bothparents
				 MEGPT_work
				 gross_income* gross_hourl*
				 dummy_work
				 age_labor_market
				 pli0038_h pli0043_h pli0044_h pli0051 pli0059 *_hours" 
				 ;
#delimit cr 

use `varlist' using "$datawork/soeprv_edited.dta", clear 
sort pid monthly

* Event Var *
clonevar eventtime=marr1beginmy_event_time

* Restrictions *

*Time before/after event
local y=12
bysort rv_id: egen after  = max(eventtime)
bysort rv_id: egen before = min(eventtime) 
*Necessary observation Window
keep if before <= -4*`y' & after >= 8*`y'
*Age 
gen age_restr = .
replace age_restr = 1 if eventtime == 0 & inrange(age, 18, 45)
bysort rv_id: egen eventage = max(age_restr) 
drop if eventage==. 



	****************************************************************************
	** Subsamples - monthly **
	****************************************************************************

	**********
	* Gender *
	**********
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/mp_soeprv_women_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/mp_soeprv_men_all.dta", replace 
	restore
	
	********************************
	* By Gender & Parental Status  *
	********************************
	local s=0
	foreach sex in men women {
		* Without Children ever
		preserve
			keep if female==`s' & child1_timing_marr_1==0
			save "$datawork/mp_soeprv_`sex'_nochild.dta", replace
		restore
		* With 1st Child during marriage (or 12 months earlier)
		preserve
			keep if female==`s' & inlist(child1_timing_marr_1, 2, 3)
			save "$datawork/mp_soeprv_`sex'_withchild.dta", replace
		restore
		local s=`s'+1
	}
	
	************************************
	* By Gender & All Parental Status  *
	************************************
	local s=0
	foreach sex in men women {
		forval n=0/4 {
			preserve
				keep if female==`s' & child1_timing_marr_1==`n'
				save "$datawork/mp_soeprv_`sex'_childstatus`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	***************************
	* By Gender & N children  *
	***************************
	/*subsamples for individuals with 1, 2, or 3 children 
		--> we don't do 0 b/c that's the same as child1_timing_marr_1==0 
		--> we don't do 4+ children b/c small sample (but could do if we want) */
	local s=0
	foreach sex in men women {
		forval n=1/3 {
			preserve
				keep if female==`s' & n_children==`n'
				save "$datawork/mp_soeprv_`sex'_n_children`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	****************************************************
	* By Gender & years between 1st child and marriage *
	****************************************************
	local s=0
	foreach sex in men women {
		forval n=-5/5 /*marriage 5 years before/after birth*/ {
			if `n' < 0 {
			    local pos = -`n'
			    local name = "minus`pos'"
			}
			if `n' >= 0 {
			    local name = "`n'"
			}
			preserve
				keep if female==`s' & dist_marr1_childbirth1_y==`n'
				save "$datawork/mp_soeprv_`sex'_years_marriage_birth_`name'.dta", replace
			restore
		}
		local s=`s'+1
	}	
	
	******************************
	* By Gender & Divorce Status *
	******************************
	local s=0
	foreach sex in men women {
		forval n=0/1 {
			preserve
				keep if female==`s' & marr1_divorced==`n'
				save "$datawork/mp_soeprv_`sex'_divorced`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	**********************************
	* By gender & decade of marriage *
	**********************************
	local s=0
	foreach sex in men women {
		forval d=1950(10)2010 {
			preserve
				keep rv_id monthly syear eventtime MEGPT_work gross_hourly gross_hourly_2015EUR dummy_work female age age_labor_market marr1begindecade marr1beginmy_event_time child*birthmy_event_time
				keep if female==`s' & marr1begindecade==`d'
				save "$datawork/mp_soeprv_`sex'_marriage_decade`d'.dta", replace
			restore
		}
		local s=`s'+1 
	}
	
	*************************************
	* By gender & age-group at marriage *
	*************************************
	local s=0
	foreach sex in men women {
		forval d=1/3 {
			preserve
				keep rv_id monthly syear eventtime MEGPT_work gross_hourly gross_hourly_2015EUR dummy_work female age age_labor_market age_marr1begin_grouped3 marr1beginmy_event_time child*birthmy_event_time
				keep if female==`s' & age_marr1begin_grouped3==`d'
				save "$datawork/mp_soeprv_`sex'_marriage_agegroup3_`d'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	***********************************
	* By gender & pre-marriage income *
	***********************************
	local s=0
	foreach sex in men women {
		forval ep = 25(25)150 /*this is excluding 0 pre-marriage income + income >150% of average (b/c small N for women*/ {
			preserve
				keep rv_id monthly syear eventtime MEGPT_work gross_hourly gross_hourly_2015EUR dummy_work female age age_labor_market MEGPT_work_pre_marriage_1_group marr1beginmy_event_time child*birthmy_event_time
				keep if female==`s' & MEGPT_work_pre_marriage_1_group==`ep'
				save "$datawork/mp_soeprv_`sex'_premarriageincome_percent_`ep'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	*******************************************
	* By gender & parents' co-habiting status *
	*******************************************
	local s=0
	foreach sex in men women {
		forval n=0/1 {
			preserve
				keep if female==`s' & grewup_bothparents==`n'
				save "$datawork/mp_soeprv_`sex'_grewup_bothparents`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	*************************
	* By gender & east/west *
	*************************
	
	local s=0
	foreach sex in men women {
		foreach var in east_born east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_soeprv_`sex'_`var'`n'.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_soeprv_`sex'_east_marriage_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	****************************
	* By Gender & Gender Norms *
	****************************
	local s=0
	foreach sex in men women {
		foreach var in gender_progressive1 gender_progressive2 gender_progressive3 {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_soeprv_`sex'_`var'_`n'.dta", replace
				restore 
			}	
		}
		local s=`s'+1
	}
	
	*****************************
	* By Gender & Randomization *
	*****************************
	local s=0
	foreach sex in men women {
		forvalues n = 0/1 {
			preserve 
				keep if female==`s' & random_m_marr1xchild1==`n'
				save "$datawork/mp_soeprv_`sex'_randommarr1child1_`n'.dta", replace
			restore 
		}
		local s=`s'+1
	}
	*extra file where we delate all randomized where childbirth and marriage was in same year*/
	local s=0
	foreach sex in men women {
			preserve 
				keep if female==`s' 
				drop if ((marr1beginy==child1birthy) & (marr1source_vskt==0 | (child_birth_source_vskt & child1birthmy_random==1)))
				save "$datawork/mp_soeprv_`sex'_randommarr1child1_2.dta", replace
			restore 
		local s=`s'+1
	}
	
	*************************
	* Only intensive margin *
	*************************
	
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & dummy_work==1
			save "$datawork/mp_soeprv_`sex'_only_intensive.dta", replace
		restore 
		local s=`s'+1
	}
	
	*************************
	* Decomposition Sample *
	*************************
	/*so far: unbalanced sample - for both hours worked variables*/
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & !missing(labour_wd_hours)
			save "$datawork/mp_soeprv_`sex'_decomposition.dta", replace
	local s=`s'+1
	}
	
	/*so far: unbalanced sample - for both hours worked variables & only intensive*/
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & !missing(labour_wd_hours) & dummy_work==1
			save "$datawork/mp_soeprv_`sex'_decomposition_only_intensive.dta", replace
		restore 
	local s=`s'+1
	}
	
	************
	* Time-Use *
	************
	preserve 
	
	keep pid sex gebjahr rv_id syear age age_labor_market birth_decade female marr1beginy_event_time marr1_lengthy marr1_divorced age_marr1begin marr_childbirth1 *_hours child1_timing_marr_1 
	
	gen childdummy=inlist(child1_timing_marr_1, 2, 3)
	replace childdummy=. if inlist(child1_timing_marr_1, 1, 4)
	
	gen eventtime = marr1beginy_event_time
	order syear eventtime, after(pid)
	collapse eventtime-childdummy, by(pid syear)
		
	save "$datawork/mp_soeprv_timeuse.dta", replace 
	restore
	
	****************************************************************************
	** Subsamples - yearly **
	****************************************************************************
	
	**************
	** Collapse **
	**************
	
	/*time use: have one var that adds hours from care and housework*/
	egen unpaidwork_wd_hours = rowtotal(housework_wd_hours carework_wd_hours)
	
	/*monthly data --> annual average*/
	#delimit ;
	collapse 	gebjahr sex sumkids age age_labor_market female 
				phrf_consent
				east_first east_born east_marriage east_marriage_group gender_progressive*
				pgcasmin pgpsbil
				marr1beginy marr1beginy_event_time 
				age_marr1begin_grouped3 marr1begindecade
				MEGPT_work gross_income* gross_hourl* dummy_work  
				marr1endy marr1endy_event_time marr1_lengthy marr1_divorced d_marriage2 age_marr1begin 
				marr1beginm marr1beginmy_random_soep marr1source_vskt
				dist_marr1_childbirth1_y
				child1birthy_event_time child2birthy_event_time child3birthy_event_time n_children child1_timing_marr_1
				cohab* dist_marr1_cohab_y
				labourwork_wd_hours labour_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours
				, by(syear rv_id)
	;
	#delimit cr

	*adjust variables*
	/*dummy = 1 if work for >= 1 month in given year*/
	replace dummy_work=(dummy_work>0 & !missing(dummy_work))
	/*Age: round to full years for FE (biological age already rounded to end of year age)*/
	replace age_labor_market=ceil(age_labor_market)
	replace age=ceil(age)
	
	**********
	* Gender *
	**********
	* Women *
	preserve
		keep if female==1 
		save "$datawork/mp_soeprv_women_yearly_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/mp_soeprv_men_yearly_all.dta", replace 
	restore
	
	**********************************
	* By gender & decade of marriage *
	**********************************
	local s=0
	foreach sex in men women {
		forval d=1950(10)2010 {
			preserve
				keep rv_id syear MEGPT_work gross_hourly_y gross_hourly_y_2015EUR dummy_work female age age_labor_market marr1begindecade marr1beginy_event_time child*birthy_event_time
				keep if female==`s' & marr1begindecade==`d'
				save "$datawork/mp_soeprv_`sex'_yearly_marriage_decade`d'.dta", replace
			restore
		}
		local s=`s'+1 
	}
	
	*************************************
	* By gender & age-group at marriage *
	*************************************
	local s=0
	foreach sex in men women {
		forval d=1/3 {
			preserve
				keep rv_id syear MEGPT_work gross_hourly_y gross_hourly_y_2015EUR dummy_work female age age_labor_market age_marr1begin_grouped3 marr1beginy_event_time child*birthy_event_time
				keep if female==`s' & age_marr1begin_grouped3==`d'
				save "$datawork/mp_soeprv_`sex'_yearly_marriage_agegroup3_`d'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	****************************************************
	* By Gender & years between 1st child and marriage *
	****************************************************
	local s=0
	foreach sex in men women {
		forval n=-5/5 /*marriage 5 years before/after birth*/ {
			if `n' < 0 {
			    local pos = -`n'
			    local name = "minus`pos'"
			}
			if `n' >= 0 {
			    local name = "`n'"
			}
			preserve
				keep if female==`s' & dist_marr1_childbirth1_y==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_years_marriage_birth_`name'.dta", replace
			restore
		}
		local s=`s'+1
	}	
	
	******************************
	* By Gender & Divorce Status *
	******************************
	local s=0
	foreach sex in men women {
		forval n=0/1 {
			preserve
				keep if female==`s' & marr1_divorced==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_divorced`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	** subsample: divorce ranges **	
	gen marr1_divorced_g=.
	replace marr1_divorced_g=0 if marr1_divorced==0
	replace marr1_divorced_g=1 if inrange(marr1_lengthy, 0, 5) & marr1_divorced==1
	replace marr1_divorced_g=2 if inrange(marr1_lengthy, 6, 10) & marr1_divorced==1
	replace marr1_divorced_g=3 if marr1_lengthy>10 & marr1_divorced==1	 
	
	local s=0
	foreach sex in men women {
		forval n=0/3 {
			preserve
				keep if female==`s' & marr1_divorced_g==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_divorced_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	** subsample: divorce ranges 2 **	
	gen marr1_divorced_g2=.
	replace marr1_divorced_g2=0 if marr1_divorced==0
	replace marr1_divorced_g2=1 if marr1_lengthy<10 & marr1_divorced==1
	replace marr1_divorced_g2=2 if marr1_lengthy>=10 & marr1_divorced==1
	
	local s=0
	foreach sex in men women {
		forval n=0/3 {
			preserve
				keep if female==`s' & marr1_divorced_g2==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_divorced_group`n'_2.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	
	******************************
	* By Gender & Marriage Month *
	******************************
	local s=0
	foreach sex in men women {
			preserve
				keep if female==`s' & inrange(marr1beginm,11,12) /*december*/ & (marr1beginmy_random_soep==0 | marr1source_vskt==1) /*have monthly info*/
				save "$datawork/mp_soeprv_`sex'_yearly_decmarriage_1.dta", replace
			restore
			preserve
				keep if female==`s' & inrange(marr1beginm,5,8) /*not december*/ & (marr1beginmy_random_soep==0 | marr1source_vskt==1) /*have monthly info*/
				save "$datawork/mp_soeprv_`sex'_yearly_decmarriage_0.dta", replace
			restore
		local s=`s'+1
	}
	
	*************************
	* By gender & east/west *
	*************************
	
	** all marriages **
	local s=0
	foreach sex in men women {
		foreach var in east_born east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_soeprv_`sex'_yearly_`var'`n'.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & east_marriage_group==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_east_marriage_group`n'.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	** subsample: born pre-reunification, married post reunification **
	/*restrictions: 
		pre  = born pre 1989 
		post = married post 1990 */
	local s=0
	foreach sex in men women {
		foreach var in east_born east_marriage {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n' & gebjahr<1989 & marr1beginy>1990 & !missing(marr1beginy)
					save "$datawork/mp_soeprv_`sex'_yearly_`var'`n'_bornpre_marrpost.dta", replace
				restore 
			}	
		}
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & east_marriage_group==`n' & gebjahr<1989 & marr1beginy>1990 & !missing(marr1beginy)
				save "$datawork/mp_soeprv_`sex'_yearly_east_marriage_group`n'_bornpre_marrpost.dta", replace
			restore
		}
		local s=`s'+1
	}
	
	******************************
	* By Gender & Gender Norms   *
	******************************
	local s=0
	foreach sex in men women {
		foreach var in gender_progressive1 gender_progressive2 gender_progressive3 {
			forvalues n = 0/1 {
				preserve 
					keep if female==`s' & `var'==`n'
					save "$datawork/mp_soeprv_`sex'_yearly_`var'_`n'.dta", replace
				restore 
			}	
		}
		local s=`s'+1
	}
		
	**********************************
	* By Gender & Education Status   *
	**********************************
	** Find out highest education in timeframe
	bys rv_id (syear): egen education= max(pgcasmin)
	replace education=. if inlist(education,-1) //-1 no answer, 
	
	** Set groups
	gen educationgroup=.
	* Hauptschulabschluss or not finished
	replace educationgroup=1 if inlist(education, 1, 2 , 3)
	* Realschule
	replace educationgroup=2 if inlist(education, 4, 5)
	* Fachhochschulreife / Abi
	replace educationgroup=3 if inlist(education, 6, 7)
	* Fachuni / Uniabschluss
	replace educationgroup=4 if inlist(education, 8, 9)
	
	local s=0
	foreach sex in men women {
		forvalues n = 1/4 {
			preserve 
				keep if female==`s' & educationgroup==`n'
				save "$datawork/mp_soeprv_`sex'_yearly_educationgroup_`n'.dta", replace
			restore 
		}		
		local s=`s'+1
	}
	
	**********************************
	* By Gender & Cohabitation Group *
	**********************************
	/*By specific groups*/
	local s=0
	foreach sex in men women {
		/*Cohabitation starts with marriage*/
		preserve 
			keep if female==`s' & dist_marr1_cohab_y==0
			save "$datawork/mp_soeprv_`sex'_yearly_cohabitation_g1.dta", replace
		restore 
		/*Cohabitation starts min 2 years before marriage*/
		preserve 
			keep if female==`s' & dist_marr1_cohab_y>1 & !missing(dist_marr1_cohab_y)
			save "$datawork/mp_soeprv_`sex'_yearly_cohabitation_g2.dta", replace
		restore 
		
		local s=`s'+1
	}
	
	*************************
	* only intensive margin *
	*************************
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & dummy_work==1
			save "$datawork/mp_soeprv_`sex'_yearly_only_intensive.dta", replace
		restore 
		local s=`s'+1
	}
	
	*************************
	* Decomposition Sample *
	*************************
	** only if hours worked variable**
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & !missing(labour_wd_hours)
			save "$datawork/mp_soeprv_`sex'_yearly_decomposition.dta", replace
		restore 
	local s=`s'+1
	}
	
	** only intensive & only if hours worked variable**
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & !missing(labour_wd_hours) & dummy_work==1
			save "$datawork/mp_soeprv_`sex'_yearly_decomposition_only_intensive.dta", replace
		restore 
	local s=`s'+1
	}


********************************************************************************
**							 Child (Penalty) Sample							  **
********************************************************************************
* Chose necessary variables *
#delimit ;
	local varlist =	"pid rv_id 
					phrf_consent
					syear monthly 
					partner *child1* 
					female sex
					gebjahr age birth_decade age_labor_market
					east_first east_born east_marriage east_marriage_group
					sumkids n_children child1_timing_marr_1 dist_child1_child2
					child1birthy_event_time child2birthy_event_time child3birthy_event_time child2birthmy_event_time child3birthmy_event_time
					random_m_marr1xchild1
					married_ever marr1_divorced dummy_child1_within_marriage_* 
					dist_marr1_childbirth1_my dist_marr1_childbirth1_y dist_marr2_childbirth1_my marr_childbirth1 d_marriage2
					marr1beginy marr1beginy_event_time marr1endy age_marr1begin
					marr1beginmy_event_time single_childbirth1 fam_stat
					MEGPT_work
					gross_income_month_2015EUR gross_income_year
					gross_hour* *_hours
					dummy_work
					age_labor_market" ;
#delimit cr 

use `varlist' using "$datawork/soeprv_edited.dta", clear 

sort pid monthly

* Event Var *
clonevar eventtime=child1birthmy_event_time

* Restrictions *
local y=12
bysort rv_id: egen after  = max(eventtime)
bysort rv_id: egen before = min(eventtime) 
*Necessary observation Window
keep if before <= -4*`y' & after >= 8*`y'
*Age 
gen age_restr = .
replace age_restr = 1 if eventtime == 0 & inrange(age, 18, 45)
bysort rv_id: egen eventage = max(age_restr) 
drop if eventage==. 

count	//3,269,392

	****************************************************************************
	** Subsamples **
	****************************************************************************
	
	**********
	* Gender *
	**********
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/cp_soeprv_women_all.dta", replace
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/cp_soeprv_men_all.dta", replace 
	restore
	
	*******************************
	* By Gender & Marital Status  *
	*******************************
	local s=0		
	/*As of now, this subsamples regards marriage 1 & 2 - if we only want to use marriage 1,
		--> use variable dummy_child1_within_marriage_1 instead of marr_childbirth1*/
	foreach sex in men women {
		* Not Married 
		preserve
			keep if female==`s' & ///
				/*not during 1st or 2nd marriarage*/ (marr_childbirth1==0 & ///
				/*not 1st marriage 12 months later*/ (!inrange(dist_marr1_childbirth1_my, 0 ,12) | missing(dist_marr1_childbirth1_my)) & ///
				/*not 2nd marriage 12 months later*/ (!inrange(dist_marr2_childbirth1_my, 0 ,12) | missing(dist_marr2_childbirth1_my))) 
			save "$datawork/cp_soeprv_`sex'_notmarried.dta", replace
		restore
		* Married
		preserve
			keep if female==`s' & ///
				/*Married at childbirth or*/ (marr_childbirth1==1 | ///
				/*1st marriage 12 months after childbirth1 or */ (inrange(dist_marr1_childbirth1_my, 0 ,12)) | ///
				/*2nd marriage 12 months after childbirth1 */ (inrange(dist_marr2_childbirth1_my, 0 ,12))) 
			save "$datawork/cp_soeprv_`sex'_married.dta", replace
		restore
		
		* Not Married & Not Single
		preserve
			keep if female==`s' & ///
				/*not during 1st or 2nd marriarage*/ (marr_childbirth1==0 & ///
				/*not 1st marriage 12 months later*/ (!inrange(dist_marr1_childbirth1_my, 0 ,12) | missing(dist_marr1_childbirth1_my)) & ///
				/*not 2nd marriage 12 months later*/ (!inrange(dist_marr2_childbirth1_my, 0 ,12) | missing(dist_marr2_childbirth1_my)) & ///
				/*not single parent*/ single_childbirth1==0)
			save "$datawork/cp_soeprv_`sex'_notmarriednotsingle.dta", replace
		restore
		
		*for Loop
		local s=`s'+1
	}
	
	*****************************
	* By Gender & Randomization *
	*****************************
	local s=0
	foreach sex in men women {
		forvalues n = 0/1 {
			preserve 
				keep if female==`s' & random_m_marr1xchild1==`n'
				save "$datawork/cp_soeprv_`sex'_randommarr1child1_`n'.dta", replace
			restore 
		}
		local s=`s'+1
	}
	
	****************************************************************************
	** Subsamples - yearly **
	****************************************************************************

	/*time use: have one var that adds hours from care and housework*/
	egen unpaidwork_wd_hours = rowtotal(housework_wd_hours carework_wd_hours)
	
	* Collapse * 
	collapse gebjahr sex sumkids age age_labor_market female marr1beginy marr1beginy_event_time MEGPT_work dummy_work marr1endy marr1_divorced d_marriage2 age_marr1begin child1birthy child1birthy_event_time child2birthy_event_time child3birthy_event_time n_children child1_timing_marr_1 east_first east_born east_marriage east_marriage_group gross_hour* labourwork_wd_hours labour_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours,  by(syear rv_id)

	*adjust variables*
	/*dummy = 1 if work for >= 1 month in given year*/
	replace dummy_work=(dummy_work>0 & !missing(dummy_work))
	/*Age: round to full years for FE (biological age already rounded to end of year age)*/
	replace age_labor_market=ceil(age_labor_market)
	replace age=ceil(age)
	
	* Women *
	preserve
		keep if female==1 
		save "$datawork/cp_soeprv_women_yearly_all.dta", replace 
	restore 

	* Men *
	preserve
		keep if female==0 
		save "$datawork/cp_soeprv_men_yearly_all.dta", replace 
	restore
	
	*************************
	* By gender & east/west *
	*************************
	
	** by birth region **
	local s=0
	foreach sex in men women {
		foreach sample in /*all childbirths*/ all /*only born pre, childbirth post reunification*/ bornpre_childpost { 
			if "`sample'" == "all" local name = ""
			if "`sample'" == "bornpre_childpost" local name = "_bornpre_childpost"
			
			forvalues n = 0/1 {
				preserve 
					if "`sample'" == "all" keep if female==`s' & east_born==`n'
					if "`sample'" == "bornpre_childpost" keep if female==`s' & east_born==`n' & gebjahr<1989 & child1birthy>1990 & !missing(child1birthy)
					save "$datawork/cp_soeprv_`sex'_yearly_east_born`n'`name'.dta", replace
				restore 
			}	// n
		}	// sample
		local s=`s'+1
	}	// sex

	*************************
	* only intensive margin *
	*************************
	local s=0
	foreach sex in men women {
		preserve 
			keep if female==`s' & dummy_work==1
			save "$datawork/cp_soeprv_`sex'_yearly_only_intensive.dta", replace
		restore 
		local s=`s'+1
	}
	
********************************************************************************
**				 			  Matched Partners Sample			 		      **
********************************************************************************
* Chose necissary variables *
#delimit ;
	local varlist =	"pid rv_id hid pgpartnr
					 phrf_consent
					 syear monthly 
					 age gebjahr
					 partner *marr* 
					 child_ever *child1* *child2* *child3*
					 sex female
					 MEGPT_work
					 age_labor_market
					 ijob1 ijob2 iself income" ;
#delimit cr 

use `varlist' using "$datawork/soeprv_edited.dta", clear 
	
sort pid monthly


***********************************
** link partners to nth marriage **
***********************************

	/*marriage 1 & 2 w/ VSKT & SOEP data*/
	forvalues n = 1/2 {
	    clonevar pgpartnr_marr`n' = pgpartnr if inrange(monthly, marr`n'beginmy, marr`n'endmy - 1) & !missing(marr`n'beginmy) /*& !missing(marr`n'endmy)*/ & inlist(partner, 1, 3) /*partner ID in the years of marriage n but only if SOEP states marriage*/ 
			replace pgpartnr_marr`n' = . if pgpartnr_marr`n' <0 /*recode missings from SOEP (-2) to "."*/
	}
	
	/*marriage 3 & 4 w/ SOEP data only*/
	forvalues n = 3/4 {
	    clonevar pgpartnr_marr`n' = pgpartnr if inrange(syear, marr`n'beginy_soep, marr`n'endy_soep) & !missing(marr`n'beginy_soep) /*& !missing(marr`n'endy_soep)*/ & inlist(partner, 1, 3)/*partner ID in the years of marriage n*/
			replace pgpartnr_marr`n' = . if pgpartnr_marr`n' <0 /*recode missings from SOEP (-2) to "."*/
	}

	/*check for cases w/ several  partner IDs for 1 marriage*/
	forvalues n = 1/4 {
		by pid: egen long pgpartnr_marr`n'_min = min(pgpartnr_marr`n')
		by pid: egen long pgpartnr_marr`n'_max = max(pgpartnr_marr`n')
		gen flag`n' = 1 if pgpartnr_marr`n'_min != pgpartnr_marr`n'_max

	    di "N i with > 1 partner ID for marriage `n'"
		unique pid if flag`n' == 1
	}
	/*	only one i for marriage 2 */
	
	
	forvalues n = 1/4 {
	    replace pgpartnr_marr`n' = . if pgpartnr_marr`n'_min!=pgpartnr_marr`n'_max
		by pid: ereplace long pgpartnr_marr`n' = max(pgpartnr_marr`n'_max) if pgpartnr_marr`n'_min==pgpartnr_marr`n'_max
		
		drop pgpartnr_marr`n'_max pgpartnr_marr`n'_min
	}
	
	forvalues n = 1/4 {
	    di "N i, with linked 1 partner ID for marriage `n'"
		unique pid if !missing(pgpartnr_marr`n')
	}
	/* 	N i, with linked 1 partner ID for marriage 1
			Number of unique values of pid is  5401 --> we have 5401 linked spouses for 1st marriage (of 1 spouse)
		N i, with linked 1 partner ID for marriage 2
			Number of unique values of pid is  624
		N i, with linked 1 partner ID for marriage 3
			Number of unique values of pid is  86
		N i, with linked 1 partner ID for marriage 4
			Number of unique values of pid is  5
		*/
		
*************************************
** link partners to 1st childbirth **
*************************************

	clonevar pgpartnr_child1 = pgpartnr if inrange(syear, child1birthy -1, child1birthy + 1) & !missing(child1birthy) 
							/*& inlist(partner, , )*/ /*check relationship status?*/ 
		replace pgpartnr_child1 = . if pgpartnr_child1 <0 

	/*check for cases w/ several  partner IDs for 1 marriage*/
	by pid: egen long pgpartnr_child1_min = min(pgpartnr_child1)
	by pid: egen long pgpartnr_child1_max = max(pgpartnr_child1)
	gen flag = 1 if pgpartnr_child1_min != pgpartnr_child1_max

	di "N i with > 1 partner ID for child 1"
	unique pid if flag == 1

	replace pgpartnr_child1 = . if pgpartnr_child1_min!=pgpartnr_child1_max
	by pid: ereplace long pgpartnr_child1 = max(pgpartnr_child1_max) if pgpartnr_child1_min==pgpartnr_child1_max
	
	drop pgpartnr_child1_max pgpartnr_child1_min
	di "N i, with linked 1 partner ID for child 1"
	unique pid if !missing(pgpartnr_child1)
	/* 	Number of unique values of pid is  1347 -
	-> 1347 linked spouses for childbirth1
		*/
	drop flag*	

*********************************************
** generate subsample with linked partners **
*********************************************
	
	/*keep i with unambiguous sex info (female or male in both SOEP & VSKT)*/
	unique pid if (female==1 & sex==1) /*VSKT: female, SOEP: male*/ | (female==0 & sex==2) /*VSKT: male, SOEP: female*/
	 /*--> 3 individuals*/
	keep if (female==1 & sex==2) /*female*/ | (female==0 & sex==1) /*male*/
	
	** 1a) sample with married women **
	preserve
	keep if female==1 
	drop if missing(pgpartnr_marr1) /*1st marriage*/
	rename MEGPT_work_pre_marriage_1_group MEGPT_work_pre_marriage_1_g
	rename * *_f
	foreach var in syear monthly {
		rename `var'_f `var'
	}
	clonevar link = pgpartnr_marr1_f
	tempfile women_merge_m 
	save `women_merge_m', replace
	restore 
	
	** 1b) sample with women withchildbirth **
	preserve
	keep if female==1 
	drop if missing(pgpartnr_child1) /*1st child*/
	rename MEGPT_work_pre_child1_group MEGPT_work_pre_child1_g
	drop MEGPT_work_pre_marriage_1_group 
	rename * *_f
	foreach var in syear monthly {
		rename `var'_f `var'
	}
	clonevar link = pgpartnr_child1_f
	tempfile women_merge_c 
	save `women_merge_c', replace
	restore 
	
	** 2) sample with all men **
	preserve 
	keep if female==0 
	rename MEGPT_work_pre_marriage_1_group MEGPT_work_pre_marriage_1_g
	rename MEGPT_work_pre_child1_group MEGPT_work_pre_child1_g
	rename * *_m 
	foreach var in syear monthly {
		rename `var'_m `var'
	}
	clonevar link = pid_m
	tempfile men_merge 
	save `men_merge', replace
	restore

*******************************
** Merge Men & Women Samples **
*******************************

	*****************************************
	* 1a) Merge marriage *
	*****************************************
	
	use `women_merge_m', clear 
	unique pid_f /*3,574*/
	merge m:1 link monthly using `men_merge', gen(_merge_linkhh)
	
	/*link m:1 to allow for the case that > 1 women are married to the same man 
	in their 1st marriage*/
	
	/* Result                       # of obs.
    -----------------------------------------
    not matched                     1,935,462
        from master                   523,970  (_merge_linkhh==1)--> women: i x t not matched (but i may be 
        from using                  1,411,492  (_merge_linkhh==2)--> men: i x t not matched (but i may be 

    matched                           818,677  (_merge_linkhh==3)--> women & men: matched i x t
    ----------------------------------------- 	*/
	
	** keep all t for i that has at least one 1 matched **
	bys pid_f: egen long merge_linkhh_max = max(_merge_linkhh) /*=3 for all t of i if matched for any t*/
	unique pid_f if merge_linkhh_max==1 /*N = 1036*/
	unique pid_f if merge_linkhh_max==2 /*N =     1*/
	unique pid_f if merge_linkhh_max==3 /*N = 1894*/
	
	keep if merge_linkhh_max==3
	
	** have pid for both spouses in every row (even if only one spouse observed in that row) **
	by pid_f: ereplace long pid_f = max(pid_f)
	by pid_f: ereplace long pid_m = max(pid_m)
	
	** gen new variables **
	*total income*
	egen MEGPT_work_couple = rowtotal(MEGPT_work_f MEGPT_work_m)
	replace MEGPT_work_couple = . if MEGPT_work_couple == 0 /*recode "0" --> "." for spouses with no recorded income in month t*/
	foreach sex in f m {
		*income share*
		gen MEGPT_work_share_`sex' = MEGPT_work_`sex'/MEGPT_work_couple /*income share i*/
			replace MEGPT_work_share_`sex' = 0 if missing(MEGPT_work_`sex') & !missing(MEGPT_work_couple) /*recode "."  --> "0" if own MEGPT is missing, but spouse's MEGPT is >0 & !missing*/
			
		*income relative to marriage -12 months*
		clonevar MEGPT_work_rel_marr1_`sex' = MEGPT_work_`sex' if marr1beginmy_event_time_f==-12 /*row filled for 12 months before marriage*/
		by pid_f: ereplace MEGPT_work_rel_marr1_`sex' = max(MEGPT_work_rel_marr1_`sex') /*same value for all rows*/
		replace MEGPT_work_rel_marr1_`sex' = MEGPT_work_`sex'/MEGPT_work_rel_marr1_`sex' /*in each row, set income relative to income at marriage*/
	}
	
	** save dataset **
	compress
	save "$datawork/mp_SOEP_RV_linked_spouses_marr1_women.dta", replace
	
	
	*****************************
	** Marriage Penalty Sample **
	*****************************
	#delimit ;
		keep 
			pid_* rv_id_*
			syear monthly
			age_* gebjahr_* 
			child1_timing_marr_1_* child*birthy_event_time* *marr*
			MEGPT_work_* MEGPT_work_share_*
			ijob1_* ijob2_* iself_* income_*;
	#delimit cr 
	/*might add  dummy_work_* later on*/

	sort pid_f monthly

	* Event Var *
	clonevar eventtime=marr1beginmy_event_time_f

	* Restrictions *
	local y=1
	bysort rv_id_f: egen after  = max(eventtime)
	bysort rv_id_f: egen before = min(eventtime) 
	*Necessary observation Window (shortened)
	keep if before <= -3*`y' & after >= 6*`y'
	*Age 
	gen age_restr = .
	replace age_restr = 1 if eventtime == 0 & inrange(age_f, 18, 45)
	bysort rv_id_f: egen eventage = max(age_restr) 
	drop if eventage==. 
	
	* no gendered Dataset necissary *
	/*we already have female and male variable in each observation row
	due to linkage of partners*/
	
	save "$datawork/mp_soeprv_linked_spouses_all.dta", replace
	
	*****************************************
	* 1b) Merge Childbirth *
	*****************************************	
	use `women_merge_c', clear 
	unique pid_f /*3,574*/
	merge m:1 link monthly using `men_merge', gen(_merge_linkhh)	
	/*link m:1 to allow for the case that > 1 women are parents with the same man*/
	
	/* Result                       # of obs.
    -----------------------------------------
     Not matched                     2,176,487

        from master                    70,494  (_merge_linkhh==1) (women)
        from using                  2,105,993  (_merge_linkhh==2) (men)

    Matched                           124,335  (_merge_linkhh==3)
    -----------------------------------------	*/
	
	** keep all t for i that has at least one 1 matched **
	bys pid_f: egen long merge_linkhh_max = max(_merge_linkhh) /*=3 for all t of i if matched for any t*/
	unique pid_f if merge_linkhh_max==1 /*N = 231*/
	unique pid_f if merge_linkhh_max==2 /*N =   1*/
	unique pid_f if merge_linkhh_max==3 /*N = 494*/
	
	keep if merge_linkhh_max==3
	
	** have pid for both spouses in every row (even if only one spouse observed in that row) **
	by pid_f: ereplace long pid_f = max(pid_f)
	by pid_f: ereplace long pid_m = max(pid_m)
	
	** gen new variables **
	*total income*
	egen MEGPT_work_couple = rowtotal(MEGPT_work_f MEGPT_work_m)
	replace MEGPT_work_couple = . if MEGPT_work_couple == 0 /*recode "0" --> "." for spouses with no recorded income in month t*/
	foreach sex in f m {
		*income share*
		gen MEGPT_work_share_`sex' = MEGPT_work_`sex'/MEGPT_work_couple /*income share i*/
			replace MEGPT_work_share_`sex' = 0 if missing(MEGPT_work_`sex') & !missing(MEGPT_work_couple) /*recode "."  --> "0" if own MEGPT is missing, but spouse's MEGPT is >0 & !missing*/
		
		*income relative to marriage -12 months*
		clonevar MEGPT_work_rel_child1_`sex' = MEGPT_work_`sex' if child1birthmy_event_time_f==-12 /*row filled for 12 months before marriage*/
		by pid_f: ereplace MEGPT_work_rel_child1_`sex' = max(MEGPT_work_rel_child1_`sex') /*same value for all rows*/
		replace MEGPT_work_rel_child1_`sex' = MEGPT_work_`sex'/MEGPT_work_rel_child1_`sex' /*in each row, set income relative to income at marriage*/
	}	
	
	** save dataset **
	compress
	save "$datawork/cp_SOEP_RV_linked_spouses_child1_women.dta", replace
	
	************************
	* Child Penalty Sample *
	************************
	#delimit ;
		keep 
			pid_* rv_id_*
			syear monthly
			age_* gebjahr_* 
			child*birthy_event_time* *marr*
			MEGPT_work_* MEGPT_work_share_*
			ijob1_* ijob2_* iself_* income_*;
	#delimit cr 

	sort pid_f monthly

	* Event Var *
	clonevar eventtime=child1birthy_event_time_f

	* Restrictions *
	bysort rv_id_f: egen after  = max(eventtime)
	bysort rv_id_f: egen before = min(eventtime) 
	*Necessary observation Window (shortened)
	local y=1
	count if before <= -2*`y' & after >= 6*`y'
	*Age 
	gen age_restr = .
	replace age_restr = 1 if eventtime == 0 & inrange(age_f, 18, 45)
	bysort rv_id_f: egen eventage = max(age_restr) 
	drop if eventage==. 
	
	save "$datawork/cp_soeprv_linked_spouses_all.dta", replace

	***************************
	** Primary vs. Secondary **
	***************************
	*restrict when MEGTP always 0? 
	gen empty_inc_m=(MEGPT_work_share_f==1) if inrange(marr1beginmy_event_time_f, -16, 16)
		bys rv_id_f: ereplace empty_inc_m=sum(empty_inc_m)
		replace empty_inc_m=(empty_inc_m==33)
	gen empty_inc_f=(MEGPT_work_share_m==1) if inrange(marr1beginmy_event_time_f, -16, 16) 
		bys rv_id_f: ereplace empty_inc_f=sum(empty_inc_f) 
		replace empty_inc_f=(empty_inc_f==33)
		
		*Female breadwinner var
		gen femalebreadwinner=(MEGPT_work_share_f>=0.5) & !missing(MEGPT_work_share_f) & !missing(MEGPT_work_share_m)
		
		gen femalebreadwinner_premarr=femalebreadwinner if eventtime==-12 & !missing(MEGPT_work_share_f)
			by rv_id_f: ereplace femalebreadwinner_premarr=max(femalebreadwinner_premarr)

		* primary earner female
		preserve
			keep if femalebreadwinner==1
			drop if empty_inc_m==1
			save "$datawork/mp_soeprv_linked_spouses_femalebreadwinner.dta", replace
		restore
		* primary earner male
		preserve
			keep if femalebreadwinner==0
			drop if empty_inc_f==1
			save "$datawork/mp_soeprv_linked_spouses_malebreadwinner.dta", replace
		restore
	











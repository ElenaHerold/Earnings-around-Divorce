********************************************************************************
** Data preparation for later analysis - panel data **
********************************************************************************

********************************************************************************
** Reshape **
********************************************************************************

/*******************************************************************************
All time variant variables of the VSKT dataset come as a seperated file in wide 
format. This do-file reshapes these files from wide to long. 
List of variables I reshape:
	- MEGPT:	Entgeltpunkte für Monat X bezogen auf die SES
	- SES:		Soziale Erwerbssituation
*******************************************************************************/

/*THIS IS VERY TIME INTENSIVE, ONLY NEED TO DO THIS ONCE 
	--> for this, set global reshape = 1 in main.do*/

if $reshape == 1 { 

	foreach var in MEGPT SES RCEG {
		
		**************************
		/* open data set (wide) */
		**************************
		use "$data_vskt/sufvskt2015va_`=lower("`var'")'.dta", clear
		
		**************************
		/* reshape wide -> long */
		**************************
		reshape long `var'_, i(case) j(month_bio)
		rename `var'_ `var'
		
		****************
		/* clean data */
		****************
		/* add date of birth to assign date of observation */
		merge m:1 case using "$data_vskt/sufvskt2015va_fix.dta", keepusing(ja /*year of wave*/ gbja /*year of birth*/)
		drop _merge
		/* generate year of observation */ 
		gen year = gbja + 14 + int((month_bio-1)/12)
		/* drop future observations (= missing) */	
		drop if year > ja
		/* drop date variables */
		drop ja gbja year
		
		**********
		/* save */
		**********
		save "$datawork/`var'_long.dta", replace
	}
}

********************************************************************************
** Combine different datasets to one panel data set **
********************************************************************************

	**************************************************
	/* Open dataset with time invariant information */
	**************************************************
	use "$data_vskt/sufvskt2015va_fix.dta", clear 
	sort case
	
	****************************************************************************
	** IMPORTANT ** 
	****************************************************************************
	/*To speed up the data prep, we immediately restrict the sample to those who 
	get divorced eventually. For full sample analysis, reomve this line. */
	drop if missing(EB1_Jahr) /* only keep those from the divorced subpopulation */
	****************************************************************************
	
	**********************************************
	/* Merge panel data for different variables */
	**********************************************
	
	/* 1st variable: merge variable + biography month */
	merge 1:m case using "$datawork/MEGPT_long.dta"
	drop if _merge == 2 /*drop obs that appear in using only --> individuals who are not divoprced*/
	drop _merge
	
	/* Other variables: merge variable only, biography month already merged */
	foreach var in RCEG SES /*for now, we only merge RCEG & SES, but could have a list of vars here*/ {
		merge 1:1 case month_bio using "$datawork/`var'_long.dta", keepusing(`var')
		drop if _merge == 2 /*drop obs that appear in using only --> individuals who are not divoprced*/
		drop _merge
	}
	
	* label variables * 
	label var MEGPT "Entgeltpunkte für Monat X bezogen auf die SES"
	label var RCEG 	"Rechtsgrundlage für die Entgeltermittlung"
	label var SES	"Soziale Erwerbssituation"
	
	foreach var in SES {
		label values `var' `=lower("`var'")'
	}
				
********************************************************************************
** Generate new variables **
********************************************************************************

	*****************
	/*define labels*/
	*****************
	do "$do/mp_labels.do"
	
	********************
	/* Date Variables */
	********************
	
	* year of observation *
	gen year = gbja + 14 + int((month_bio-1)/12)
		label variable year "Year of observation"
	* month of observation * 
	gen month = month_bio - (int((month_bio-1)/12)*12)
		label variable month "Month of observation"
	* monthly date of observation *
	gen monthly = ym(year, month) // monthly: eindeutiges Datum auf Monatsebene, z.B. 2013m1; monthly == 636 für 01-2013
		format monthly %tm
		label variable monthly "Date (monthly) of observation"
	
	****************************
	/* Define panel structure */
	****************************
	xtset case monthly	/* Panel: id = case; t = monthly */
	sort case monthly 
	
	
	*****************************************
	* Relevant operands for social security *
	*****************************************
	/* This includes rlevant operands for the pension, health, old age care, and 
	unemployment insurance. */
	global year="year"
	global month="month"
	do "$do/mp_vskt_02b_operands_social_security.do"
		
	** store 2015 values in global **
	/*average income --> used to compute income from EP */
	qui sum average_annual_income if year==2015 /*this is equivalent to 1 EP in 2015*/
		global ep2015 = r(mean)
	/*pension value --> used to compute EP worth*/
	qui sum ep_value_west if year==2015 /*this is how much 1 EP pays in pensions in 2015 - west*/
		global ep_value_west2015 = r(mean)
	qui sum ep_value_east if year==2015 /*this is how much 1 EP pays in pensions in 2015 - east*/
		global ep_value_east2015 = r(mean)
		
	******************
	/* Demographics */
	******************
	
	
	/* Age */
	gen age = year-gbja
		replace age = year-gbja-1 if month<gbmo
		label variable age "Age (end of month)"
	
	/* Date of Birth */
	gen birth_monthly = ym(gbja, gbmo)
		format birth_monthly %tm
		label variable birth_monthly "Date of birth (monthly)"		
	gen birth_year = gbja
		label variable birth_year "Date of birth (year)"		
	gen birth_decade = floor(birth_year/10)*10
		label variable birth_decade "Date of birth (decade)"
	
	/* Female */
	gen female = 0	
		replace female = 1 if geh == 2
		label variable female "Female"
		label values female female	
	
	/* east west */ 
	
	/* We have two measures for east/west 
		(1) WHOT_BLAND = state of residence as of 2015 East 
		(2) RCEG = info whether EP in given month is linked to east or west*/
		
	** dummy east for current month **
	gene east_monthly = RCEG /*RCEG=0 for west, 2,5,6,7 for east, and . if no EP*/
		replace east_monthly = 1 if inlist(east_monthly, 2,5,6,7)
		label variable east_monthly "east EP in this month"
		label values east_monthly east
	
	** dummy living in the east 2015 **
	gen east_living_2015 = 0
		replace east_living_2015 = 1 if WHOT_BLAND >=11 
		label variable east_living_2015 "Lives in Eastern German state (2015)"
		label values east_living_2015 east
		
	** first EP east/west **
	/*this var captures east/west for the first month we observe an individual 
		--> proxy for the individual grew up */
	sort case monthly 
	tempvar first
	by case: egen `first' = min(monthly) if !missing(RCEG) /*first month with nonmissing RCEG*/
	gen east_first = RCEG if monthly==`first' /*RCEG=0 for west, 2,5,6,7 for east, and . if no EP*/
		replace east_first = 1 if inlist(east_first, 2,5,6,7)
		by case: ereplace east_first = max(east_first)
		label var east_first "east/west 1st observed month"
		label values east_first east

	** east/west month of marriage **
	/*cases with filled RCEG month of marriage*/
	gen east_marriage = east_monthly if monthly== ym(EB1_Jahr, EB1_Monat)
	/*cases with missing RCEG month of marriage 
		--> take closest month 
		--> if same distance pre/post we take post "ties(after)" */
	tempvar east_mip
		bys case: mipolate east_monthly monthly, nearest ties(after) gen(`east_mip')
	replace east_marriage = `east_mip' if missing(east_marriage) & monthly== ym(EB1_Jahr, EB1_Monat) 
	/*same values for all rows*/
	bys case: ereplace east_marriage = max(east_marriage)
		label var east_marriage "east/west month of marriage"
		label values east_marriage east
	
	** group var: east/west 1st month vs marriage **	
	gen east_marriage_group = .
		/*1 = 1st obs east, married east */
		replace east_marriage_group = 1 if east_first==1 & east_marriage==1
		/*2 = 1st obs east, married west */
		replace east_marriage_group = 2 if east_first==1 & east_marriage==0
		/*3 = 1st obs west, married west */
		replace east_marriage_group = 3 if east_first==0 & east_marriage==0
		/*4 = 1st obs west, married east */
		replace east_marriage_group = 4 if east_first==0 & east_marriage==1
		label var east_marriage_group "east/west pattern marriage"
		label values east_marriage_group eastwestmarr
		
	************************
	/* Marriage / Divorce */	
	************************
	
	/* Time variables for the events: marriage, divorce, court decision (divorce) */
	forvalues i = 1/2 /*1st and 2nd marriage*/ {
		****************
		* Monthly date * 
		****************
		*marriage*
		gen marriage_`i'_date = ym(EB`i'_Jahr, EB`i'_Monat)
			format marriage_`i'_date %tm
		*divorce*
		gen divorce_`i'_date = ym(ES`i'_Jahr, ES`i'_Monat)
			format divorce_`i'_date %tm
		*court ruling*
		gen court_`i'_date = ym(DRK_Jahr_`i', DRK_Monat_`i')
			format court_`i'_date %tm
			
		***************
		* Yearly date * 
		***************
		*marriage*
		gen marriage_`i'_year = EB`i'_Jahr
		*divorce*
		gen divorce_`i'_year = ES`i'_Jahr
			
		**********
		* Decade * 
		**********
		*marriage*
		gen marriage_`i'_date_decade = floor(EB`i'_Jahr/10)*10
		*divorce*
		gen divorce_`i'_date_decade = floor(ES`i'_Jahr/10)*10
		*court ruling*
		gen court_`i'_date_decade = floor(DRK_Jahr_`i'/10)*10
		
		***********************************
		* Time relative to event (months) *
		***********************************
		
		foreach event in marriage divorce court {
			*months*
			gen `event'_`i'_event_time = monthly /*date of obs.*/ - `event'_`i'_date
		}
		foreach event in marriage divorce {
			*years*
			gen `event'_`i'_event_time_y = year /*year of obs.*/ - `event'_`i'_year
		}

		*****************
		*Length marriage*
		*****************
		gen lengthm_marriage_`i' = (divorce_`i'_date) - marriage_`i'_date /*use divorce date, not separation date (this is typically 12 months before divorce date)*/
		gen lengthy_marriage_`i' = ceil((lengthm_marriage_`i')/12)
		replace lengthy_marriage_`i'=1 if lengthy_marriage_`i'==0

		****************************
		*Divorce after reform 2008 *
		****************************
		gen postreform_divorce_`i' = divorce_`i'_date>575 /*575 = Dec 2007*/
		label val postreform_divorce_`i' postreform
		
		gen postreform_separation_`i' = divorce_`i'_date>563 /*575 = Dec 2006*/
		label val postreform_separation_`i' postreform
	
	}	
	
	***************************************
	/* Bonus / Malus points from divorce */
	***************************************
	/*At divorce, spouses share pension entitlements that were acquired during 
		marriage 50/50. Each spouse gives 50% of the pension points to their ex 
		("Abschlag", captured in VAAB_ES1/2) and receives 50% of their ex's 
		points ("Zuschlag", captured in VAZU_ES1/2). In sum, both will have the 
		same total of pension points for the period of marriage. 
		Comparing VAAB_ES1 & VAZU_ES1 informs about total wage income difference 
		during marriage: 
			- VAAB_ES1 > VAZU_ES1 --> i = primary wage earner
			- VAAB_ES1 = VAZU_ES1 --> i = exactly 50%  
			- VAAB_ES1 < VAZU_ES1 --> i = secondary wage earner */
	forvalues i = 1/2 {
		
		*Dummy: 1 = bonus, 0 = malus*
		gen dummy_bonus_`i' = . 
			/* dummy = 1 if bonus points > malus points */
			replace dummy_bonus_`i' = 1 if VAZU_ES`i' > VAAB_ES`i' & !missing(VAZU_ES`i')
			/* dummy = 0 if bonus points < malus points */
			replace dummy_bonus_`i' = 0 if VAZU_ES`i' < VAAB_ES`i' & !missing(VAAB_ES`i')
			label values dummy_bonus_`i' bonus
		
		*Aggregate bonus & malus to 1 variable (with positive and negative values)*
		gen bonus_malus_`i' = VAZU_ES`i' - VAAB_ES`i' if !missing(VAZU_ES`i') & !missing(VAAB_ES`i') /*>0 = more bonus points, <0 = more malus points --> there are no missings*/
		
		*normalize aggregated bonus/malus by length of marraige (monthly)*
		gen bonus_malus_`i'_monthly = bonus_malus_`i' / lengthm_marriage_`i'
	
		* bonus/malus points in 2015 € **
		/*!! for now: west values only !!*/
		gen bonus_malus_`i'2015EUR = bonus_malus_`i'*$ep_value_west2015 
			label var bonus_malus_`i'2015EUR "bonus/malus points from marriage `i' in 2015 EUR"
		* sum bonus/malus points assuming 20 years in retirement, in 2015 €
		gen bonus_malus_`i'2015EUR20y = bonus_malus_`i'2015EUR*12*20
			label var bonus_malus_`i'2015EUR20y "sum 20 years of bonus/malus points from marriage `i' in 2015 EUR"
	}
	
	
	*******************************
	/* Age at marriage / divorce */ 
	*******************************
	forvalues i = 1/2 /*1st and 2nd marriage*/ {
		foreach event in marriage divorce court {
			/*Age in years*/
			tempvar store_age 
				gen `store_age' = age if `event'_`i'_event_time==0 /*store age infor from month of event*/
			bysort case: egen age_`event'_`i' = max(`store_age') /*have same value for all months*/
		}
	}
	/*Age groups -- seperately for marriage 1 bc different age distributions*/
	gen age_marriage_1_grouped = . 
		replace age_marriage_1_grouped = 1 if age_marriage_1 < 18
		replace age_marriage_1_grouped = 2 if inrange(age_marriage_1, 18, 21)
		replace age_marriage_1_grouped = 3 if inrange(age_marriage_1, 22, 25)
		replace age_marriage_1_grouped = 4 if inrange(age_marriage_1, 26, 29)
		replace age_marriage_1_grouped = 5 if inrange(age_marriage_1, 30, 33)
		replace age_marriage_1_grouped = 6 if age_marriage_1 >33
		label var age_marriage_1_grouped  "Age at marriage 1 -- grouped"
		label values age_marriage_1_grouped age_marriage
	/*Age groups -- seperately for divorce 1 */
	gen age_divorce_1_grouped = . 
		replace age_divorce_1_grouped = 1 if age_divorce_1 < 25
		replace age_divorce_1_grouped = 2 if inrange(age_divorce_1, 25, 30)
		replace age_divorce_1_grouped = 3 if inrange(age_divorce_1, 31, 35)
		replace age_divorce_1_grouped = 4 if inrange(age_divorce_1, 36, 40)
		replace age_divorce_1_grouped = 5 if inrange(age_divorce_1, 41, 45)
		replace age_divorce_1_grouped = 6 if age_divorce_1 >45
		label var age_divorce_1_grouped  "Age at divorce 1 -- grouped"
		label values age_divorce_1_grouped age_divorce
		
		******************
		/* 2nd marriage */ 
		******************
		gen d_marriage2=(!missing(marriage_2_date))
		label var d_marriage2 "Dummy for 2nd Marriage"
		label values d_marriage2 dummy_m2
		
	
	**************
	/* Children */
	**************
	
	/* Information on children is available for a parent if the children are of 
		relevance for their pension entitlements. This si typically the case for 
		parents who stayed at home to take care of their child(ren), i.e. 
		parental leave. Given the strong persistence of traditional gender roles 
		in German families, this applies nearly only to mothers and barely to 
		fathers. Thus, we can identify the vast majority of divorced mothers, 
		but only a minority of divorced fathers. */
		
	/* time in-variant */	
				
		*************************
		** Dummy ever children **
		*************************
		gen dummy_kids = 0
			replace dummy_kids = 1 if GBKIJ1 > 0	
		label values dummy_kids dummy_kids
			
		************************
		** Number of children **
		************************
		/*total number of children (as of last observation)*/
		gen n_children = 0
		forval n=1/10 {
			replace n_children=n_children+1 if GBKIJ`n'!=0
		}
		
		* Birth date & age children*
		forvalues x = 1/10 /*data has info on up to 10 children*/ {
			*Birth date (monthly)*
			gen child`x'birthmy = ym(GBKIJ`x', GBKIM`x') 
				replace child`x'birthmy = . if GBKIJ`x' == 0 /*0 when no kids*/
				format child`x'birthmy %tm
				label variable child`x'birthmy "Date of Birth Child `x' (monthly)"
			*Birth date (year)*
			gen child`x'birthy = GBKIJ`x'
				replace child`x'birthy = . if GBKIJ`x' == 0 /*0 when no kids*/
				label variable child`x'birthmy "Date of Birth Child `x' (year)"
			*Time relative to birth (monthly)*
			gen time_event_birth_child_`x' = monthly - child`x'birthmy
				label variable time_event_birth_child_`x' "Months Relative to Birth Child `x'"
			*Time relative to birth (years)*
			gen time_event_y_birth_child_`x' = year - child`x'birthy
				label variable time_event_y_birth_child_`x' "Years Relative to Birth Child `x'"
			*Age in years (in given month of observation) -- INCLUDING negative age (= future birhts)*
			gen age_child_`x' = year - GBKIJ`x' /*birth year child x*/
				replace age_child_`x' = year - GBKIJ`x' - 1 if month < GBKIM`x'
				replace age_child_`x' = . if GBKIJ`x' == 0 /*0 when no kids*/
				label variable age_child_`x' "Age child `x' (end of month)"
			*Positive age in months (in given month of observation) -- EXCLUDING negative age (= no future birhts)*
			gen age_child_`x'_p = age_child_`x' if age_child_`x'>=0
		}	
		
		* birth date youngest child *
		egen birth_child_youngest_m = rowmax(child1birthmy child2birthmy child3birthmy child4birthmy child5birthmy child6birthmy child7birthmy child8birthmy child9birthmy child10birthmy)	
		format birth_child_youngest_m %tm
		
		* Distance first & second child *
		gen dist_child1_child2= child2birthmy - child1birthmy if !missing(child2birthmy)
		
		* age first child at marriage / divorce (negative values = not yet born) *
		foreach event in marriage divorce {
			forvalues i = 1/2 {
				gen age_child_1_`event'_`i'_m = `event'_`i'_date - child1birthmy if !missing(child1birthmy) /*age in months*/
				gen age_child_1_`event'_`i' = floor(age_child_1_`event'_`i'_m/12) if !missing(child1birthmy) /*age in years */
			}
		}
		
		* age youngest child at marriage / divorce*
		foreach event in marriage divorce {
			forvalues i = 1/2 {
				*any children ever born: including not yet born (negative values = not yet born)*
				tempvar help /*tempvar var that stores youngest child's age at divorce*/
				egen `help' = rowmin(age_child_1 age_child_2 age_child_3 age_child_4 age_child_5 age_child_6 age_child_7 age_child_8 age_child_9 age_child_10) if divorce_`i'_event_time==0 
				by case: egen age_child_youngest_`event'_`i' = max(`help') /*store info in every row*/
				label var age_child_youngest_`event'_`i' "Age youngest child at `event' `i'"
				
				*age groups (any age, icl. <0)*
				gen age_child_youngest_`event'_`i'_g = . 
					*6 age groups*
					replace age_child_youngest_`event'_`i'_g = 1  if inrange(age_child_youngest_`event'_`i', 0, 2)   	/* 0 - < 3 (pre kindergarten)*/
					replace age_child_youngest_`event'_`i'_g = 2  if inrange(age_child_youngest_`event'_`i', 3, 5)   	/* 3 - < 6 (kindergarten)*/
					replace age_child_youngest_`event'_`i'_g = 3  if inrange(age_child_youngest_`event'_`i', 6, 9)   	/* 6 - <10 (primary school)*/
					replace age_child_youngest_`event'_`i'_g = 4  if inrange(age_child_youngest_`event'_`i', 10, 13)	/*10 - <13 (early 2ndary school)*/
					replace age_child_youngest_`event'_`i'_g = 5  if inrange(age_child_youngest_`event'_`i', 14, 17) 	/*13 - <18 (teenagers, minor)*/
					replace age_child_youngest_`event'_`i'_g = 6  if age_child_youngest_`event'_`i' >= 18 			 	/*18+		(adults) (missings are corrected for below)*/
					*specific missings for: no children at all vs children later in life*
					replace age_child_youngest_`event'_`i'_g = .a if dummy_kids == 0 			 						/*no children ever*/
					replace age_child_youngest_`event'_`i'_g = .b if age_child_1 < 0 			 						/*no children yet, but later in life*/
					label var age_child_youngest_`event'_`i'_g "Age group youngest child at `event' `i'"
					label values age_child_youngest_`event'_`i'_g childagegroup
					
				*children born already (= non-negative age)*
				tempvar help /*tempvar var that stores youngest child's age at divorce*/
				egen `help' = rowmin(age_child_1_p age_child_2_p age_child_3_p age_child_4_p age_child_5_p age_child_6_p age_child_7_p age_child_8_p age_child_9_p age_child_10_p) if divorce_`i'_event_time==0 
				by case: egen age_child_youngest_`event'_`i'_p = max(`help') /*store info in every row*/
				label var age_child_youngest_`event'_`i'_p "Age youngest child at `event' `i' (already born)"
				
				*age groups (non-negative age)*
				gen age_child_youngest_`event'_`i'_pg = . 
					*6 age groups*
					replace age_child_youngest_`event'_`i'_pg = 1  if inrange(age_child_youngest_`event'_`i'_p, 0, 2)   /* 0 - < 3 (pre kindergarten)*/
					replace age_child_youngest_`event'_`i'_pg = 2  if inrange(age_child_youngest_`event'_`i'_p, 3, 5)   /* 3 - < 6 (kindergarten)*/
					replace age_child_youngest_`event'_`i'_pg = 3  if inrange(age_child_youngest_`event'_`i'_p, 6, 9)   /* 6 - <10 (primary school)*/
					replace age_child_youngest_`event'_`i'_pg = 4  if inrange(age_child_youngest_`event'_`i'_p, 10, 13) /*10 - <13 (early 2ndary school)*/
					replace age_child_youngest_`event'_`i'_pg = 5  if inrange(age_child_youngest_`event'_`i'_p, 14, 17) /*13 - <18 (teenagers, minor)*/
					replace age_child_youngest_`event'_`i'_pg = 6  if age_child_youngest_`event'_`i'_p >= 18 			 /*18+		(adults) (missings are corrected for below)*/
					*specific missings for: no children at all vs children later in life*
					replace age_child_youngest_`event'_`i'_pg = .a if dummy_kids == 0 			 						 /*no children ever*/
					replace age_child_youngest_`event'_`i'_pg = .b if age_child_1 < 0 			 						 /*no children yet, but later in life*/
					label var age_child_youngest_`event'_`i'_pg "Age group youngest child at `event' `i' (already born)"
					label values age_child_youngest_`event'_`i'_pg childagegroup
			}
		}

			
		*************************************
		/* Distance marriage & child birth */
		*************************************
		*Only for specific marriage* 
		forvalues n = 1/1 /*rn we only do this for the 1st child, can add more children here if needed*/ {
			forvalues m= 1/2 /*marriage 1 & 2*/ {
				/*months*/
				gen dist_marr`m'_childbirth`n'_my= marriage_`m'_date-child`n'birthmy 
				label var dist_marr`m'_childbirth`n'_my "Distance to Marriage `m' at Childbirth `n' (in Months)"
				/*calendar years*/
				/*we do calendar years here to have it comparable to SOEPRV, where month may be missing*/
				gen dist_marr`m'_childbirth`n'_y= EB`m'_Jahr-GBKIJ`n'
			}
		}
		
		
		****************************************************
		/* Dummy: 1st child born pre/within/post marriage */
		****************************************************
		
		forvalues i = 1/2 /*marriage 1 & 2*/ {
			/* pre marriage: 
				--> 1st child born before marriage */
			gen dummy_child1_pre_marriage_`i' = 0
				replace dummy_child1_pre_marriage_`i'= 1 if child1birthmy < marriage_`i'_date & !missing(child1birthmy, marriage_`i'_date)
				label var dummy_child1_pre_marriage_`i' "1st Child born before Marriage `i'"
				label val dummy_child1_pre_marriage_`i' yesno
			
			/* within marriage: 
				--> 1st child born within marriage (>= month marriage start & <= month marriage end) */
			gen dummy_child1_within_marriage_`i' = 0
				replace dummy_child1_within_marriage_`i' = 1 if inrange(child1birthmy, marriage_`i'_date, divorce_`i'_date) & !missing(child1birthmy, marriage_`i'_date, divorce_`i'_date)
				label var dummy_child1_within_marriage_`i' "1st Child born within Marriage `i'"
				label val dummy_child1_within_marriage_`i' yesno
			
			/*post marriage
				--> 1st child born post marriage = after divorce*/
			gen dummy_child1_post_marriage_`i' = 0
				replace dummy_child1_post_marriage_`i'= 1 if child1birthmy > divorce_`i'_date & !missing(child1birthmy,  divorce_`i'_date)
			label var dummy_child1_post_marriage_`i' "1st Child born after Marriage `i'"
			label val dummy_child1_post_marriage_`i' yesno
		}
	
		**********************************************
		/* N children born pre/during/post marriage */
		**********************************************
		forvalues i = 1/2 /*marriage 1 & 2*/ {			

			/*pre marriage -> amount*/
			gen n_child_pre_marriage_`i' = 0
				forvalues x = 1/10 {
					replace n_child_pre_marriage_`i' = n_child_pre_marriage_`i'+1 if child`x'birthmy < marriage_`i'_date & !missing(child`x'birthmy, marriage_`i'_date)
				}
			label var n_child_pre_marriage_`i' "N Children pre Marriage `i'"
			
			/*within marriage -> amount*/
			gen n_child_within_marriage_`i' = 0
				forvalues x = 1/10 {
					replace n_child_within_marriage_`i' = n_child_within_marriage_`i'+1 if inrange(child`x'birthmy, marriage_`i'_date, divorce_`i'_date) & !missing(child`x'birthmy, marriage_`i'_date)
				}
			label var n_child_within_marriage_`i' "N Children within Marriage `i'"
			
			/*post marriage -> amount*/
			gen n_child_post_marriage_`i' = 0
				forvalues x = 1/10 {
					replace n_child_post_marriage_`i' = n_child_post_marriage_`i'+1 if child`x'birthmy > divorce_`i'_date & !missing(child`x'birthmy, divorce_`i'_date)
				}
			label var n_child_post_marriage_`i' "N Children post Marriage `i'"
			
			/* N children at divorce */
			gen n_child_divorce`i' = n_children - n_child_post_marriage_`i'
			label var n_child_divorce`i' "N children at divorce `i'"
		}	
	
		***********************************************
		/* General timing info: 1st child & marriage */
		***********************************************
		forvalues i = 1/2 /*marriage 1 & 2*/ {		
			/* Information child before/within, after marriage, no child*/
			gen child1_timing_marr_`i' = .
				/*never children*/
				replace child1_timing_marr_`i' = 0 if dummy_kids==0
				/*children more than 12 months before marriage*/
				replace child1_timing_marr_`i' = 1 if dist_marr`i'_childbirth1_my>12 & !missing(dist_marr`i'_childbirth1_my) 
				/*children in 12 months before marriage*/
				replace child1_timing_marr_`i' = 2 if inrange(dist_marr`i'_childbirth1_my,0,12)
				/*children during marriage*/
				replace child1_timing_marr_`i' = 3 if dummy_child1_within_marriage_1==1
				/*children post marriage*/
				replace child1_timing_marr_`i' = 4 if dummy_child1_post_marriage_1==1
				
			label var child1_timing_marr_`i' "Children and Marriage `i'"
			label val child1_timing_marr_`i' marrchild
		}
		
		* dummy for minor kids at divorce *
		forvalues i = 1/2 {
			gen dummy_kids_minor_divorce_`i' = 0
				replace dummy_kids_minor_divorce_`i' = 1 if inrange(age_child_youngest_divorce_`i'_p, 0, 18) /*only children who are born <= divorce date*/
		}
	
	
		/* time variant */
		
		* age youngest child *
		*in years*
		gen age_child_youngest = floor((monthly - birth_child_youngest_m)/12) if monthly >= birth_child_youngest_m
		*in months*
		gen age_child_youngest_m = monthly - birth_child_youngest_m if monthly >= birth_child_youngest_m
		
		* dummy for kids (minor kids only) *
		gen kids_minor = 0
			replace kids_minor = 1 if age_child_youngest < 18 
		
	
	***************************
	/* Working Life / Income */
	***************************
	
	/* dummies for different SES (= type of employment / situation for given month) */
	forvalues x = 1/15 {
		gen SES_`x' = 0
			replace SES_`x' = 1 if SES == `x'
	}
	
	/*dummy for SES = working*/
	gen SES_work = 0
			replace SES_work = 1 if inlist(SES, 10, 11, 13) 
			/* 10 = Mini-job employee
			   11 = Self-employed
			   13 = regular employee */
			   
	/* Aggregated labor market experience */
	*so far, as of month t (time variant)*
	foreach var in SES_10 SES_11 SES_13 SES_work {
		by case (monthly): gen `var'_month_sum = sum(`var') /* counting months with SES=1 */
			label variable `var'_month_sum "Experience `var' so far"
		by case: egen `var'_total_sum = max(`var'_month_sum) /* counting total months with SES=1 for observable lifetime */
		label variable  `var'_total_sum "Total experience `var'"
	}
		
	/*month first employment*/
	by case (monthly): gen help = monthly if SES_work==1 & SES_work[_n-1]==0 /*help var with month if 1st observarion in the labor market*/
	by case: egen date_enter_labor_market = min(help) /*time invariant information: date entering the labor market*/
		format date_enter_labor_market %tm 
		label variable date_enter_labor_market "Date Entering Labor Market"
		drop help
	
	*********************
	** Earnings Points **
	*********************
	/* Earningspoints for different SES */
		* all observations *
		forvalues x = 1/15 {
			gen MEGPT_SES_`x' = 0
		}
		* only those to whom SES applies *
		forvalues x = 1/15 {
			gen MEGPT_SES_`x'_positive = MEGPT if SES == `x'
		}
	
	/* Earningspoints from labor income (employment & self employment) */
		* all observations *
		gen MEGPT_work = 0
			replace MEGPT_work = MEGPT if inlist(SES, 10, 11, 13) 
			/* 10 = Mini-job employee
			   11 = Self-employed
			   13 = regular employee */
			label variable MEGPT_work "EP from labor income"
		* only those who have labor income *
		gen MEGPT_work_positive = MEGPT if inlist(SES, 10, 11, 13) 
			label variable MEGPT_work_positive "EP from labor income"
		
	foreach var in MEGPT MEGPT_work {
		* Aggregated EP, as of month t (time variant)*
		by case (monthly): gen `var'_month_sum = sum(`var') /* counting EPs that have been acquired so far (not counting ".") */
			label variable `var'_month_sum "Sum `var' so far"	
		*over lifetime as captured in the data set (time invariant)*
		by case: egen `var'_total_sum = max(`var'_month_sum) /* Counting total amount of EP for observable lifetime */
			label variable `var'_total_sum "Sum `var' total"
		*acquired EP at event of marriage/divorce 
		foreach event in marriage divorce {
			forvalues i = 1/2 /*1st & 2nd marriage/divorce*/ {
				tempvar help 
				gen `help' = `var'_month_sum if monthly == `event'_`i'_date /*sum EP at the date of marriage/divorce*/
				by case: egen `var'_month_`event'_`i'_sum = max(`help')
					label variable `var'_month_`event'_`i'_sum "Sum `var' at `event'"
			}
		}
		*sum EP aquired during marriage*
		forvalues i = 1/2 /*1st & 2nd marriage*/ {
			*total*
			gen `var'_marriage_`i'_sum = `var'_month_divorce_`i'_sum - `var'_month_marriage_`i'_sum /*difference total EP divorce vs marriage*/
				label variable `var'_marriage_`i'_sum  "`var' Acquired During Marriage `i'"
			*mean*
			gen `var'_marriage_`i'_mean = `var'_marriage_`i'_sum / lengthm_marriage_`i' /*sum EP acquired during divided by length marriage*/
				label variable `var'_marriage_`i'_mean  "Mean Monthly `var' Acquired During Marriage `i'"
		}
	}
		
	/*share EP from labor income during marriage*/
	forvalues i = 1/2 /*1st & 2nd marriage*/ {
	    gen share_MEGPT_work_marriage_`i' = MEGPT_work_marriage_`i'_sum / MEGPT_marriage_`i'_sum
			label variable share_MEGPT_work_marriage_`i'  "Share EP from Labor Income During Marriage `i'"
	} // i (marriage)
	
	/*sum EP spouse during marriage*/
	/* based on the sum of individual EP during marriage and the bonus/malus EP, 
		we can infer the sum of EP for the spouse during marriage. 
	   With the length of marriage, this gives us the monthly EP as well. */
	forvalues i = 1/2 /*1st & 2nd marriage*/ {
	    *sum EP spouse during marriage*
		gen MEGPT_spouse_marriage_`i'_sum = MEGPT_marriage_`i'_sum + bonus_malus_`i'
			label variable MEGPT_spouse_marriage_`i'_sum  "Sum EP Spouse During Marriage `i'"
		*average monthly EP spouse during marriage*
		gen MEGPT_spouse_marriage_`i'_mean = MEGPT_spouse_marriage_`i'_sum / lengthm_marriage_`i'
			label variable MEGPT_spouse_marriage_`i'_mean  "Mean monthly EP Spouse During Marriage `i'"
	} // i (marriage)
	
	
	************
	** INCOME **
	************
		
	**************************
	/* Monthly gross income */	
	**************************
	/*in € (= gross income in that year)*/
	gen gross_income_month = MEGPT_work * average_annual_income
		label variable gross_income_month "Monthly income [€]"
		*replace gross_income_month = if SES == 13 & inlist(RTVS, 5, 6) /* to do: seperate calculation for East German states? */
	
	/*in 2015 €*/
	gen gross_income_month_2015EUR = MEGPT_work*$ep2015
		label variable gross_income_month_2015EUR "Monthly income [2015 €]"
	
	***********************
	* Annual gross income *	
	***********************
	egen case_year = concat(case year), punct("_") /* unique identifier for case x year combination */
	
	bysort case_year: egen gross_income_year = total(gross_income_month)
	
	if "`:sortedby'" != "case (monthly)"{
		sort case (monthly)
		}	

	*****************************************
	* Income threshold for Mini- & Midi-Job *
	*****************************************
	
	gen threshold_mini_job = .
		replace threshold_mini_job = 400 if inrange(monthly, ym(2003,4), ym(2012,12))
		replace threshold_mini_job = 450 if year > 2012
		
	gen threshold_midi_job = .
		replace threshold_midi_job = 800 if inrange(monthly, ym(2003,4), ym(2012,12))
		replace threshold_midi_job = 850 if year > 2012
	
	
	******************************
	* Lifetime income (in 2015€) *
	******************************
	
	** monthly gross income in 2015€ **
	gen income_monthly_2015EUR = MEGPT_work*$ep2015 /*monthly income in 2015€*/
		label variable income_monthly_2015EUR "monthly gross income (2015€)"
		
	** lifetime income aggregated as of given month **
	gen lti_month_sum_2015EUR = MEGPT_work_month_sum*$ep2015
		label var lti_month_sum_2015EUR "life-time gross income so far (2015 €)"

	**aggregated lifetime income at the end of month before a person turns 60 **
	gen lti_total_sum_60_2015EUR = lti_month_sum_2015EUR if age==59 & age[_n+1]==60 & case==case[_n+1] 
		by case: ereplace lti_total_sum_60_2015EUR=max(lti_total_sum_60_2015EUR)
		label var lti_total_sum_60_2015EUR "life-time gross income age 60 (2015 €)"
		
	***********************
	* Pre-marriage income *
	***********************
	
	/*Earnings points*/
	by case: egen MEGPT_work_pre_marriage_1 = mean(MEGPT_work) if inrange(marriage_1_event_time, -12, -1) /*mean EP in the 12 months preceeding marriage*/
	by case: ereplace MEGPT_work_pre_marriage_1 = max(MEGPT_work_pre_marriage_1) /*have that var filled for every row*/
		label var MEGPT_work_pre_marriage_1 "mean EP 12 months pre marriage"
	
	/*2015 income*/
	gen income_pre_marriage_1_2015EUR = MEGPT_work_pre_marriage_1*$ep2015
		label var income_pre_marriage_1_2015EUR "mean income 12 months pre marriage"
	
	*************************
	* income duing marriage *
	*************************
	gen income_marriage_1_mean_2015EUR = MEGPT_marriage_1_mean*$ep2015
		label var income_marriage_1_mean_2015EUR "mean income during marriage"
		
	
	**********************************
	* Spousal income during marriage *
	**********************************
	
	forvalues i = 1/2 /*1st & 2nd marriage*/ {
	    gen income_spouse_m`i'_mean_2015EUR = MEGPT_spouse_marriage_`i'_mean*$ep2015
			label variable income_spouse_m`i'_mean_2015EUR  "Mean Income Spouse During Marriage `i' (2015€)"
		gen income_spouse_m`i'_sum_2015EUR = MEGPT_spouse_marriage_`i'_sum*$ep2015
			label variable income_spouse_m`i'_sum_2015EUR  "Sum Income Spouse During Marriage `i' (2015€)"
	} // i (marriage)
	
	*************
	* Education *	
	*************
	gen education = .
		replace education = 1 if inlist(TTSC3_KLDB1988,1,3)
		replace education = 2 if inlist(TTSC3_KLDB1988,2,4)
		replace education = 3 if TTSC3_KLDB1988==5
		replace education = 5 if TTSC3_KLDB1988==6
		replace education =. if TTSC3_KLDB1988==7
	
		replace education = TTSC3_KLDB2010 if TTSC3_KLDB1988==0
		replace education = . if TTSC3_KLDB2010 == 9
		
		replace education = . if education ==0
	
	
********************************************************************************
** save data set **
********************************************************************************
	
	compress
	
	
	** entire data set **
	capture drop __0* /*drop potential left-overs from tempvars*/
	*save "$datawork/sufvskt2015va_edited_mp.dta", replace
	
	** 1% sample of the entire data set **
	set seed 1234	
	tempname uniform
	gen `uniform' = uniform()
	bysort case: replace `uniform' = `uniform'[1]
	
	preserve
	keep if `uniform' <.01
	capture drop __0* /*drop potential left-overs from tempvars*/
	save "$datawork/sufvskt2015va_edited_mp_1_percent.dta", replace
	restore 
	
	** data set with divorced individuals only **
	drop if missing(EB1_Jahr) /* only keep those from the divorced subpopulation */
	capture drop __0* /*drop potential left-overs from tempvars*/
	save "$datawork/sufvskt2015va_edited_mp_divorce_only.dta", replace
	

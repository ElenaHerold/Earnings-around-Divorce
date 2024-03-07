********************************************************************************
** SHARE: Data preparation for later analysis **
********************************************************************************

********************************************************************************
*** load relevant data ***
********************************************************************************
	
	clear all 
	
	********************************
	*** SHARE Job Episodes Panel ***
	********************************
	use "$data_share/sharewX_rel8-0-0_gv_job_episodes_panel.dta", clear
	
	
	do "$do/mp_SHARE_labels.do"
	
	sort mergeid year 
	
********************************************************************************
*** add new variables ***
********************************************************************************

	***************
	*** General ***
	***************
	by mergeid: gen id_n=_n
	
	****************************************************************************
	*** country codes ***
	****************************************************************************
	
	gen str2 code = ""
		replace code = "AT" if country == 11
		replace code = "BR" if country == 23
		replace code = "BG" if country == 51
		replace code = "HR" if country == 47
		replace code = "CY" if country == 53
		replace code = "CZ" if country == 28
		replace code = "DK" if country == 18
		replace code = "EE" if country == 35
		replace code = "FI" if country == 55
		replace code = "FR" if country == 17
		replace code = "DE" if country == 12
		replace code = "GR" if country == 19
		replace code = "HU" if country == 32
		replace code = "IE" if country == 30
		replace code = "IL" if country == 25
		replace code = "IT" if country == 16
		replace code = "LV" if country == 57
		replace code = "LT" if country == 48
		replace code = "LU" if country == 31
		replace code = "MT" if country == 59
		replace code = "NL" if country == 14
		replace code = "PL" if country == 29
		replace code = "PT" if country == 33
		replace code = "RO" if country == 61
		replace code = "SK" if country == 63
		replace code = "SI" if country == 34
		replace code = "ES" if country == 15
		replace code = "SE" if country == 13
		replace code = "CH" if country == 20
		label var code "country code" 
	
	**************************
	*** save country codes ***
	**************************
	preserve
	decode country, gen(countrynames)
	collapse country, by(countrynames code)
	save "${datawork}/SHARE/SHARE_countrycode"
	restore

	
	****************************************************************************
	*** demographics ***
	****************************************************************************
	
	***********
	*** sex ***
	***********
	gen female = .
		replace female = 0 if gender==1 
		replace female = 1 if gender==2 
		label var female "dummy female"
		label values female yesno
	
	********************
	*** civil status ***
	********************
	/*	1 = single 
		2 = married 
		3 = divorced OR widowed */
	tempvar married_help
		by mergeid (year): gen `married_help' = sum(married)
	gen civil_status = . 
		replace civil_status = 1 if married==0 & `married_help'==0
		replace civil_status = 2 if married==1
		replace civil_status = 3 if married==0 & `married_help'>0
		label var civil_status "civil status"
		label values civil_status civil_status_vals
		
	
	****************************************************************************
	*** marriage ***
	****************************************************************************
	
	************************
	*** year of marriage ***
	************************
	tempvar flag_marr 
		gen `flag_marr' = 1 if civil_status==2 
		by mergeid (year): replace `flag_marr' = sum(`flag_marr') /*N years married so far*/
		replace `flag_marr' = 0 if `flag_marr'!=1 /*keep only 1 for 1st year*/
	gen marriage_year = year if `flag_marr'==1 
		by mergeid: ereplace marriage_year = max(marriage_year)
		label var marriage_year "year 1st marriage"
		
	**************************
	*** Dummy ever married ***
	**************************
	gen marriage_ever = 0
		replace marriage_ever = 1 if !missing(marriage_year)
		label var marriage_ever "dummy ever married"
		label val marriage_ever yesno
		
	***************************
	*** event time marriage ***
	***************************
	gen marriage_event_time = year - marriage_year
		label var marriage_event_time "years relative to 1st marriage"
	
	****************************
	*** year end of marriage ***
	****************************
	tempvar flag_end 
		gen `flag_end' = 1 if civil_status==3 
		by mergeid (year): replace `flag_end' = sum(`flag_end') /*N years divorced so far*/
		replace `flag_end' = 0 if `flag_end'!=1 /*keep only 1 for 1st year*/
	gen marriage_end_year = year if `flag_end'==1 
		by mergeid: ereplace marriage_end_year = min(marriage_end_year)
		label var marriage_end_year "year end 1st marriage (divorced/widowed)"
	/*to-do: think about whether we want "year end of marriage" to be the 1st 
	year where i is no longer married (that's what we have rn). OR whether we  
	want this to be the year before = the last year i is married. Because we 
	have annual data, it's not clear which to choose here. */
	
	*******************************
	*** Dummy marriage divorced ***
	*******************************
	gen marriage_divorced=.
		replace marriage_divorced=1 if !missing(marriage_end_year) & !missing(marriage_year)
		replace marriage_divorced=0 if missing(marriage_end_year) & !missing(marriage_year)
		
	***********************
	*** Marriage Lenght ***
	***********************
	gen marriage_length = marriage_end_year - marriage_year if !missing(marriage_divorced)
	
	***********************
	*** age at marriage ***
	***********************
	gen age_marriage = age if marriage_event_time == 0
		by mergeid: ereplace age_marriage = max(age_marriage)
		label var age_marriage "age 1st marriage"

	
	****************************************************************************
	*** child birth ***
	****************************************************************************
	
	/*we have two variables: 
		nchildren:		N children in given year 
		age_youngest:	age youngest child in given year 
	--> we can use those to identify year of birth for 1st, 2nd, ..., child
	--> we identify n children based on when they were born within the household 
		--> this means that we account for any children (natural and other) that 
			arrive in the household at age  0 
		--> child1 = oldest child that was with that person at age 0  
		--> there can be an older child that only arrived in the household when 
			older than 0 (i.e., because	they were living with another parent or 
			adopted at older age). 
		--> With the variable age_youngest we can check how often it is the case 
			that these children are in fact the first born children for a person
		--> It's only a few (~500) cases. To see this, run: 
			tempvar year_youngest 
			gen `year_youngest'= year - age_youngest /*stores birth year youngest child at any point for given year*/
			by mergeid: egen child1st_birthyear = min(`year_youngest') /*have birthyear for all rows*/
			unique mergeid if child1st_birthyear!=child1_birthyear
			*/
	
	*******************************
	*** year of birth nth child ***
	*******************************
	
	** year of birth younger children **
	tempvar birth nbirths 
	gen `birth' = 1 if age_youngest==0 /*birth in this year*/
	by mergeid: gen `nbirths' = sum(`birth') /*N of births so far*/
	
	quietly sum nchildren 
	global childmax = 5 /*define N children for which we compute this*/
	forvalues n = 1/$childmax {
		gen child`n'_birthyear = year if `birth'==1 & `nbirths'==`n' /*row where this child was born*/
		by mergeid: ereplace child`n'_birthyear = max(child`n'_birthyear) /*have birthyear for all rows*/
	}

	**********************************
	*** event time birth nth child ***
	**********************************
	forvalues n = 1/$childmax {
		gen child`n'_event_time = year - child`n'_birthyear
		label var child`n'_event_time "years relative to birth child `n'"
	}
	
	******************************
	*** age at birth 1st child ***
	******************************
	gen age_child1_birth = age if marriage_event_time == 0
		by mergeid: ereplace age_child1_birth = max(age_child1_birth)
		label var age_child1_birth "age birth 1st child"
	
	*************************
	*** sum children ever ***
	*************************
	by mergeid: egen sum_children=max(nchildren)
	
	***************************
	*** Dummy ever children ***
	***************************
	gen child_ever = 0
		replace child_ever = 1 if !missing(child1_birthyear)
		label var child_ever "dummy ever children"
		label val child_ever yesno
		
	****************************************************************************
	*** marriage & child birth ***
	****************************************************************************
	
	*************************************************
	*** General timing info: 1st child & marriage ***
	*************************************************
	/* Information child before/within, after marriage, no child
		0 = no children
		1 = 1st child before marriage
		2 = 1st child during marriage (inlcuding year of marriage)
		3 = 1st child after marriage*/
	gen child1_timing_marr = .
		/*never children*/
		replace child1_timing_marr = 0 if child_ever==0
		replace child1_timing_marr = 1 if child1_birthyear<marriage_year & !missing(marriage_year) 
		replace child1_timing_marr = 2 if inrange(child1_birthyear, marriage_year, marriage_end_year-1) & !missing(child1_birthyear) 
		replace child1_timing_marr = 3 if child1_birthyear>=marriage_end_year & !missing(child1_birthyear)
		
	label var child1_timing_marr "timing 1st child and 1st marriage"
	label val child1_timing_marr marrchild
	
	********************************
	*** children during marriage ***
	********************************
	/* Informtion on nr. of children within marriage 1:
		- if divorced: subtract nr. of children at beginning of marriage from nr
		               of children at divorce
		- if no divorce: subtract nr. of children at beginning of marriage from
		                 value of all children ever */
	
	/*tempvar for nr of children at beginning and end of marriage 1*/
 	tempvar child_start_marriage1
	tempvar child_end_marriage1
	gen `child_start_marriage1'=nchildren if year==marriage_year
	by mergeid: ereplace `child_start_marriage1'=mean(`child_start_marriage1')
	gen `child_end_marriage1'=nchildren if year==marriage_end_year
	by mergeid: ereplace `child_end_marriage1'=mean(`child_end_marriage1')
	
	gen nchildren_marriage1=.
	/*with divorce*/
	replace nchildren_marriage1=`child_end_marriage1' - `child_start_marriage1' if !missing(marriage_end_year)
	/*without divorce*/
	replace nchildren_marriage1=sum_children-`child_start_marriage1' if missing(marriage_end_year)
	
	replace nchildren_marriage1=0 if nchildren_marriage1<0 /*data mistake or death of child?*/
	/*missing values are now only i's with mo marriage ever*/
	
	***************************************
	*** Distance Marriage & Childbirth ***
	***************************************
	gen dist_marriage_childbirth1 = marriage_year - child1_birthyear
	label var dist_marriage_childbirth1 "Distance to Marriage at Childbirth 1"

	
	***************************************
	*** Familystatus at birth 1st child ***	
	***************************************
	/* We define family status based on civil status & cohabiting status: 
		1 = unmarried, single  
		2 = unmarried, cohabiting 
		3 = married
	--> for now, take this simple classification, b/c it's closest to what we 
		can do w/ our other datasets
	--> but we could also add: divorced, married, not co-habiting */
	gen family_child1_birth = .
		replace family_child1_birth = 1 if civil_status== 1 & withpartner==0 & child1_event_time==0
		replace family_child1_birth = 2 if civil_status== 1 & withpartner==1 & child1_event_time==0
		replace family_child1_birth = 3 if civil_status== 2 & child1_event_time==0
		by mergeid: ereplace family_child1_birth = max(family_child1_birth) /*same for all rows*/
		label var family_child1_birth "family status birth 1st child"
		label values family_child1_birth family_status_vals
	
	****************************************************************************
	*** labor market outcomes ***
	****************************************************************************
	
	
	
	****************************************************************************
	*** Country fixed effects ***
	****************************************************************************	
	
	*********************
	*** Share married ***
	*********************
	/*Internal information from SHARE*/
	gen share_married=marriage_ever if id_n==1
		bys country (mergeid year): ereplace share_married=mean(share_married)
		
	/*External data*/
	merge m:1 country year using "${data_other}/oecd_family_marriage"
	
	rename marriage_rate oecd_marriage_rate
	rename divorce_rate oecd_divorce_rate
	
********************************************************************************
*** save dataset ***
********************************************************************************	
	
	/*trop vars from tempvars etc*/
	capture drop __00*
	
	/*compress data*/
	compress

	*******************************
	*** draw relevant subsample ***
	*******************************
	
	
	***************************
	*** save edited dataset ***
	***************************
	save "$datawork/SHARE/SHARE_edited.dta", replace

	

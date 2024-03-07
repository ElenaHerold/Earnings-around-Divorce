********************************************************************************
** SOEP-RV: Data preparation for later analysis **
********************************************************************************

********************************************************************************
** Understand Matching SOEP-core & SOEP-IS with VSKT **
********************************************************************************

/* VSKT is a monthly and SOEP is an annual panel, we match by id and year. 
Matching process:
	(1) we use rv_id to match VSKT to ppathl.dta 
		(rv_id = individual identifier from SOEP-RV) 
	(2) we use pid to match any other SOEP data 
		(pid = individual identifier used throughout all SOEP data sets) */
	
	/* For the SOEP-RV linkage, a total of 4 datasets is linked, 2 from the SOEP 
	and 2 from the pension insurance 
	
	Pension Insurance:
	VSKT (not yet retired individuals) --> SUF.SOEP-RV.VSKT.2020.fix.1-0.dta: 14,494 individuals
	
	SOEP: 
	(I)  SOEP core (main panel) --> ppath.dta: 12,927 individuals (rv_id)
	(II) SOEP-IS (innovation sample) --> SOEP IS pbrutto.dta: 2,573 individuals (reclin_drv_erg)
	-->	We want: (I) & (II)
	
	*/
	

********************************************************************************
** Merge SOEP & VSKT data **
********************************************************************************
	
	**********************************
	** 1. Start with SOEP ppath.dta **
	**********************************
	*dataset with time-invariant SOEP data*
	use "$data_soep/ppath.dta", clear 
	
	*drop individuals from SOEP who are not linked*
	drop if rv_id == -2 /*matching ID = -2 if not linked*/
	
	*keep only relevant vars* 
	#delimit ;
	keep 	rv_id 		/*identifier SOEP-RV linkage*/ 
			pid 		/*identifier individual within all SOEP waves*/ 
			eintritt 	/*1st year of contact with SOEP*/
			austritt 	/*last year of contact with SOEP*/
			sex 		/*sex*/ 
			sexor 		/*sexual orientation*/
			gebjahr 	/*year of birth*/
			germborn	/*born in Germany*/
			migback 	/*migration background (i or parents born abroad)*/
			corigin 	/*country of origin*/
			loc1989 	/*place of residence in 1989 (fall Berlin wall)*/ 
			todjahr		/*year of death*/ ; 
	#delimit cr
	
	
	************************
	** 2. Merge VSKT data **
	************************
	
	*****************************
	** 2.1 Merge VSKT fix data **
	*****************************
	merge 1:1 rv_id using "$data_soeprv/SUF.SOEP-RV.VSKT.2020.fix.1-0.dta", gen(_merge_vskt_fix)
	
	/*
	    Result                           # of obs.
    -----------------------------------------
    not matched                         3,313
        from master                       873  (_merge_vskt_fix==1) --> presumably individuals who agreed but couldn't be matched (see manual chapter 3.2)
        from using                      2,440  (_merge_vskt_fix==2) --> presumably (II) (SOEP-IS/VSKT)

    matched                            12,054  (_merge_vskt_fix==3) --> (I) (SOEP-core/VSKT)
    -----------------------------------------
	*/

	*keep only matched individuals*
	keep if _merge_vskt_fix==3 
	
	
	*******************************
	** 2.2 Merge VSKT panel data **
	*******************************
	merge 1:m rv_id using "$data_soeprv/SUF.SOEP-RV.VSKT.2020.var.1-0.dta", gen(_merge_vskt_var)
	
	/*
	Result                           # of obs.
    -----------------------------------------
    not matched                     1,233,228
        from master                         0  (_merge_vskt_var==1)
        from using                  1,233,228  (_merge_vskt_var==2) --> monthly values for 2,440 individuals we drpped before --> presumably (II)

    matched                         5,495,352  (_merge_vskt_var==3) --> monthly values for 12,054 individuals --> (I)
    -----------------------------------------
	*/
	
	*keep only matched individuals*
	keep if _merge_vskt_var==3 
	
	
	************************
	** 3. Merge SOEP data **
	************************
	
	gen syear = JAHR /*matching var names for year*/
	
	*******************************
	** 3.1 Merge SOEP ppathl.dta **
	*******************************
	#delimit ; 
	merge m:m rv_id syear using "$data_soep/ppathl.dta", 
		gen(_merge_ppathl)
		keepusing(
			hid 		/*identifier household within all SOEP waves*/ 
			partner 	/*yearly information on partner, incl. co-habiting*/
			phrf		/*weight*/
		);
	#delimit cr
	
	/*
	    Result                           # of obs.
    -----------------------------------------
    not matched                     4,932,718
        from master                 3,843,060  (_merge_ppathl==1) --> linked i, t covered in VSKT only (keep)
        from using                  1,089,658  (_merge_ppathl==2) --> could be linked i, t covered in SOEP only (keep) 
																  --> OR unlinked i from SOEP (don't keep)

    matched                         1,652,292  (_merge_ppathl==3) --> linked i, t covered in SOEP & VSKT (keep)
    -----------------------------------------
	*/
	
	/*Drop i if only in SOEP, but keep all t for i with any t matched*/
	sort rv_id syear 
	tempvar marker_linkage
	by rv_id: egen `marker_linkage' = max(_merge_ppathl) /*= 3 for all t of i if linked for any t*/
	drop if `marker_linkage' < 3 /*drop i if never matched*/
	/*(1,084,134 observations deleted)*/
	
	/*Drop "empty" data from SOEP*/
	drop if _merge_ppathl==2 /*t only in SOEP*/ & missing(pid) /*no actual info in SOEP*/
	/*(5,524 observations deleted)
		--> these are cases with filled partner var but no other var (pid is missing) */
		
	tab _merge_ppathl
	/* 
			  _merge_ppathl |      Freq.     Percent        Cum.
	------------------------+-----------------------------------
			master only (1) |  3,843,060       69.93       69.93 	--> t only covered in VSKT 
																	--> no t covered in SOEP only (makes sense b/c VSKT covers 14+)
				matched (3) |  1,652,292       30.07      100.00	--> t covered in both SOEP & VSKT
	------------------------+-----------------------------------
					  Total |  5,495,352      100.00
	*/	
	
	******************
	** SOEP: pl.dta **
	******************
	#delimit ;
	merge m:1 pid syear using "$data_soep/pl.dta", 
		gen(_merge_pl) 
		keepusing(
			/*Main employment*/
			plb0022_h	/*current employment status*/
			plb0031_h 	/*new employment since year t-1*/
			p_isco08	/*occupation (ISCO08)*/
			p_kldb2010	/*occupation (KLDB2010)*/
			plb0036_h	/*tenure with current employer*/
			plb0040		/*employer: public sector*/
			plb0049_v4	/*N employees within firm (1999-2004)*/
			plb0049_v5	/*N employees within firm (2005-2015)*/
			plb0049_v6	/*N employees within firm (2016-2019)*/
			plb0050		/*employee representation within firm*/
			plc0502_h	/*collective wage agreement*/
			/*Household income*/
			plc0010		/*within couple income sharing*/
			plc0011		/*within couple decision making for financial decisions*/
			plc0013_h	/*gross income (last month)*/
			plc0014_h	/*net income (last month)*/
			plc0015_h	/*gross wage income (last month)*/
			plc0017_h	/*net wage income (last month)*/
			/*Family status*/
			pld0131_v1	/*family status 1984-2018*/
			pld0131_v2	/*family status 2019*/
			pld0131_v3	/*family status 2020*/
			pld0132_h 	/*stable partnership*/
			pld0133 	/*partner lives in hh*/
			pld0134		/*marriage*/
			pld0135 	/*marriage: month in t-1*/
			pld0136		/*marriage: month in t*/
			pld0140 	/*divorce*/
			pld0141 	/*divorce: month in t-1*/ 
			pld0142 	/*divorce: month in t*/
			pld0143 	/*separation*/
			pld0144 	/*separation: month in t-1*/ 
			pld0145 	/*separation: month in t*/
			pld0146 	/*death of partner*/
			pld0147 	/*death of partner: month in t-1*/ 
			pld0148 	/*death of partner: month in t*/
			pld0152		/*child born*/
			pld0153 	/*child born: month in t-1*/ 
			pld0154 	/*child born: month in t*/
			/*time use*/
			pli0003_h	/*time use -- saturday -- work*/
			pli0007_h	/*time use -- sunday -- work*/
			pli0038_h 	/*time use -- workday -- work*/
			pli0012_h	/*time use -- saturday -- household*/
			pli0016_h	/*time use -- sunday   -- household*/
			pli0043_h 	/*time use -- workday  -- household*/
			pli0019_h 	/*time use -- saturday -- children*/
			pli0022_h 	/*time use -- sunday   -- children*/
			pli0044_h 	/*time use -- workday  -- children*/
			pli0024_h	/*time use -- saturday -- education*/
			pli0028_h	/*time use -- sunday   -- education*/
			pli0047_v1  /*time use -- workday  -- education*/
			pli0031_h   /*time use -- saturday -- reperation*/
			pli0034_v4  /*time use -- sunday   -- reperation*/
			pli0049_h   /*time use -- workday  -- reperation*/
			pli0010		/*time use -- sunday   -- leisure */
			pli0036		/*time use -- saturday -- leisure */
			pli0051		/*time use -- workday  -- leisure */
			pli0046		/*time use -- workday  -- care persons*/
			pli0055		/*time use -- saturday -- care persons*/
			pli0057		/*time use -- sunday   -- care persons*/
			pli0011		/*time use -- sunday   -- errands*/
			pli0040		/*time use -- workday  -- errands*/
			pli0054		/*time use -- general  -- errands*/
			pli0059		/*time use -- workday  -- sleep*/
			pli0060		/*time use -- weekend  -- sleep*/
			/*values and norms*/
			plh0298_v1 
			plh0298_v2	/*Child young than 6 suffers with working mum*/
			plh0300_v1 
			plh0300_v2	/*Marry if lived with partner for long*/
			plh0301		/*Women Should Rather Care About Family Than Career*/
			plh0302_v1 
			plh0302_v2	/*Child young than 3 suffers with working mum*/
			plh0303		/*Fam: Men Involved in Housework*/
			plh0304		/*Children Suffer When Father Focused On Career*/
			plh0305		/*Fam: Marriage is a Lifelong Union*/
			plh0306		/*Fam: Marriage When Child is Born*/
			plh0308_v1 
			plh0308_v2 /**Best if man and woman work the same amount so they can share the responsibility*/
			plh0309		/*WarmthFam: Working Mothers Equal Emotional*/ 
			plh0358		/*Single Parent can raise child as well as couple*/
			plh0359		/*Gleichgeschlechtliches Paar kann Kind genauso gut grossziehen*/
			/*other*/ 
			pld0299		/*prenuptial agreement / marriage contract*/
		); 
	#delimit cr	
	
	/*
	
    Result                           # of obs.
    -----------------------------------------
    not matched                     4,557,573
        from master                 3,944,028  (_merge_pl==1)
        from using                    613,545  (_merge_pl==2)

    matched                         1,551,324  (_merge_pl==3)
    -----------------------------------------
	*/	
	
	/*Drop i if only in SOEP, but keep all t for i with any t matched*/
	sort rv_id syear 
	tempvar marker_linkage
	by rv_id: egen `marker_linkage' = max(_merge_pl) /*= 3 for all t of i if linked for any t*/
	drop if `marker_linkage' < 3 /*drop i if never matched*/
	/*(613,593 observations deleted) 
		--> this includes 48 observation from one i that is master only = not in pl.dta (rv_id 70025630 / pid 21201803) */
	
	tab _merge_pl
	/*
	pl.dta lacks years that are covered in ppathl.dta 
	--> result: more cases here with "master only" (we could match them with ppathl but not with pl)
				  _merge_pl |      Freq.     Percent        Cum.
	------------------------+-----------------------------------
			master only (1) |  3,943,980       71.77       71.77	--> t only covered in VSKT (+ 100,920 as compared to 3,843,060)
																		
				matched (3) |  1,551,324       28.23      100.00	--> t covered in both SOEP & VSKT (- 100,968 as compared to 1,652,292)
	------------------------+-----------------------------------
					  Total |  5,495,304      100.00				--> N: 48 obs less than before b/c one i not in pl.dta 
	*/

	
	***********************
	** SOEP: pwealth.dta **
	***********************
	#delimit ; 
	merge m:1 pid syear using "$data_soep/pwealth.dta", 
		gen(_merge_pwealth) 
		keepusing(
		/*Individual Wealth
		(we don't consider the n01xxx variables incl student loan and vehicles b/c they're only avialable for 2017*/
		w0101* 		/*Gross wealth, 5 different imputations: a-e*/
		w0011* 		/*Overall debt, 5 different imputations: a-e*/
		w0111* 		/*Net wealth, 5 different imputations: a-e*/
		c0100*		/*Consumer debt, 5 different imputations: a-e*/
		); 
	#delimit cr
	
	/*
    Result                           # of obs.
    -----------------------------------------
    not matched                     5,306,322
        from master                 5,222,856  (_merge_pwealth==1)
        from using                     83,466  (_merge_pwealth==2)

    matched                           272,448  (_merge_pwealth==3)	--> few obs matched b/c wealth only available for 4 years (2022, 2007, 2012, 2017)
    -----------------------------------------
	*/ 
	
	/*drop data from SOEP only*/
	drop if _merge_pwealth == 2 /*(83,466 observations deleted)*/
	
	/*many obs cannot be matched here b/c wealth only available for 4 years (2022, 2007, 2012, 2017) 
	-->  only drop _merge_pwealth == 2*/
	
	***********************
	** SOEP: hwealth.dta **
	***********************
	#delimit ; 
	merge m:1 hid syear using "$data_soep/hwealth.dta", 
		gen(_merge_hwealth) 
		keepusing(
		/*Household Wealth 
		(we don't consider the n01xxx variables incl student loan and vehicles b/c they're only avialable for 2017*/
		w010h* 		/*Gross wealth, 5 different imputations: a-e*/
		w001h* 		/*Overall debt, 5 different imputations: a-e*/
		w011h* 		/*Net wealth, 5 different imputations: a-e*/
		c010h*		/*Consumer debt, 5 different imputations: a-e*/
		); 
	#delimit cr
	
	/* 	Result                           # of obs.
    -----------------------------------------
    not matched                     5,255,831
        from master                 5,215,944  (_merge_hwealth==1)
        from using                     39,887  (_merge_hwealth==2)

    matched                           279,360  (_merge_hwealth==3) --> few obs matched b/c wealth only available for 4 years (2022, 2007, 2012, 2017)
    -----------------------------------------
	*/
	
	/*drop data from SOEP only*/
	drop if _merge_hwealth == 2 /*(39,887 observations deleted)*/
	
	/*many obs cannot be matched here b/c wealth only available for 4 years (2022, 2007, 2012, 2017) 
	-->  only drop _merge_hwealth == 2*/
	
	
	************
	/* pequiv */
	************
	/*pequiv(=individual and household-level, cross-national equivalent file)*/
	
	#delimit ; 
	merge m:1 pid syear using "$data_soep/pequiv.dta", 
		gen(_merge_pequiv) 
		keepusing(
		/*persons/children in hh*/
		d11106 	/*N persons in hh*/
		d11107 	/*N children in hh*/
		h11103 	/*N hh members age 0-1*/
		h11104 	/*N hh members age 2-4*/
		h11105 	/*N hh members age 5-7*/
		h11106 	/*N hh members age 8-10*/
		h11107 	/*N hh members age 11-12*/
		h11108 	/*N hh members age 13-15*/
		h11109 	/*N hh members age 16-18*/
		h11110	/*N hh members age 19+ (or 16-18, ind)*/
		/*employment / income soources*/
		e11103 	/*employment level /(full / part time)*/
		ijob1 	/*wage main job [€]*/
		ijob2 	/*wage 2ndary employment [€]*/
		iself 	/*income self employed [€]*/
		ialim 	/*received alimony [€]*/
		/*other*/
		l11102 	/*Region: east / west DE*/
		y11101 	/*cpi*/
		); 
	#delimit cr
	
	/*	Result                     	# of obs.
    -----------------------------------------
    not matched                     4,811,010
        from master                 3,879,144  (_merge_pequiv==1)	--> linked i, t covered in VSKT only (keep)
        from using                    931,866  (_merge_pequiv==2)	--> not linked, no rv_id (drop) 

    matched                         1,616,160  (_merge_pequiv==3)	--> linked i, t covered in SOEP & VSKT (keep)
    -----------------------------------------
	*/
	
	drop if _merge_pequiv==2
	
	************
	/* pgen */
	************
	/*pgen=Generated individual data*/
	
	#delimit ; 
	merge m:1 pid syear using "$data_soep/pgen.dta", 
		gen(_merge_pgen) 
		keepusing(
		/*individual characteristics*/
		pgfamstd 	/*marital status*/
		pgpartz		/*partner indicator*/
		pgnation 	/*citizenship*/
		/*partner*/
		pgpartnr 	/*SOEP ID for partner*/
		/*labor market*/
		pgstib 		/*occupational position*/
		pglfs 		/*labor force status (incl. maternity leave)*/
		pglabgro 	/*gross labor income*/
		pglabnet	/*net labor income*/
		pgvebzeit	/*working hours (contractual)*/
		pgtatzeit 	/*working hours (actual)*/
		/*education*/
		pgcasmin 	/*highest degree (CASMIN)*/
		pgpsbil 	/*school-leaving degree*/
		); 
	#delimit cr
	
	
    /*	Result                    	# of obs.
    -----------------------------------------
    not matched                     4,552,806
        from master                 3,932,592  (_merge_pgen==1)	--> linked i, t covered in VSKT only (keep)
        from using                    620,214  (_merge_pgen==2)	--> not linked, no rv_id (drop) 

    matched                         1,562,712  (_merge_pgen==3)	--> linked i, t covered in SOEP & VSKT (keep)
    -----------------------------------------
	*/
	
	drop if _merge_pgen==2
	
	
	*************
	/* pbrutto */
	*************
	/*Gross individual Data*/
	
	#delimit ; 
	merge m:1 pid syear using "$data_soep/pbrutto.dta", 
		gen(_merge_pbrutto) 
		keepusing(
		stell_h	/*Relationship to head of hh [harmonised]*/
		);
	#delimit cr 
	
	/*  Result                     	# of obs.
    -----------------------------------------
    not matched                     4,918,271
        from master                 3,844,392  (_merge_pbrutto==1)	--> linked i, t covered in VSKT only (keep)
        from using                  1,073,879  (_merge_pbrutto==2)	--> not linked, no rv_id (drop) -- large N here b/c gross data
    matched                         1,650,912  (_merge_pbrutto==3)	--> linked i, t covered in SOEP & VSKT (keep)
    -----------------------------------------
	*/
	
	drop if _merge_pbrutto==2
	
	
	**********
	/* pkal */
	**********
	/*Individual calendar data*/

	#delimit ; 
	merge m:1 pid syear using "$data_soep/pkal.dta", 
		gen(_merge_pkal) 
		keepusing(
		/*labor market status previous year*/
		kal1a01 /*full time employment*/
		kal1b01 /*part time employment*/
		kal1d01 /*unemployed*/
		kal1e01 /*retired*/
		kal1f01 /*maternity benefits*/
		kal1i01 /*full-time housework*/
		kal1n01 /*minijob*/
		/*income previous year*/
		kal2a01 /*income: wages / salary*/
		kal2b01 /*income: self employment*/
		kal2c01 /*income: 2nd job*/
		kal2h01 /*received alimony*/
		);
	#delimit cr 

	/* 	Result                    	# of obs.
    -----------------------------------------
    not matched                     4,557,525
        from master                 3,943,980  (_merge_pkal==1)	--> linked i, t covered in VSKT only (keep)
        from using                    613,545  (_merge_pkal==2)	--> not linked, no rv_id (drop)
    matched                         1,551,324  (_merge_pkal==3)	--> linked i, t covered in SOEP & VSKT (keep)
    -----------------------------------------
	*/
	
	drop if _merge_pkal==2
	
	**********
	/* biol */
	**********
	/*biographic information*/
	
	/*Typically, individuals are asked these Qs only once and biol.dta contains 
	only 1 syear for them. Sometimes, there are more syears, with different info 
	between syears, most of the time missing vs non-missing. 
	Before merging, we clean biol.dta such that we only have 1 row for each i.*/
	
	
	preserve 
	
		use "$data_soep/biol.dta", clear

		sort pid syear 

		/*count rows / individual*/
		by pid (syear): gen n = _n
		by pid: egen N = max(n)
		tab N /*--> max: 4*/

		/*store info on changes between syears for relevant vars*/
		foreach var in lb0013_h lb0019_h lb0060 lb0311 lb0312_h lb0313 lb0314_h lb0315_h lb0316 lb0317_h lb0318_h lb0319 lb0320_h lb0382 lb1168 lb1143 lr3193 {
			replace `var' = . if `var' <0 /*recode missings from negative to "."*/
			by pid: egen n_`var' = count(`var') 			/*how many rows (= syear) filled for this var? (excl missings)*/
			by pid: egen min_`var' = min(`var')				/*minimum value (excl missings)*/
			by pid: egen max_`var' = max(`var')				/*minimum value (excl missings)*/
			gen change_`var' = 1 if  min_`var'!=max_`var'	/*dummy = 1 if var changes at least once*/
		}

		/*dummy=1 if change for >= 1 of the vars*/
		egen change_all = rowtotal(change_lb0013_h change_lb0019_h change_lb0060 change_lb0311 change_lb0312_h change_lb0313 change_lb0314_h change_lb0315_h change_lb0316 change_lb0317_h change_lb0318_h change_lb0319 change_lb0320_h change_lb0382 change_lb1168 change_lb1143 change_lr3193)

		/*replace missings with non-missings from other syear (if unique non-missing value)*/
		foreach var in lb0013_h lb0019_h lb0060 lb0311 lb0312_h lb0313 lb0314_h lb0315_h lb0316 lb0317_h lb0318_h lb0319 lb0320_h lb0382 lb1168 lb1143 lr3193 {
				replace `var' = max_`var' if N > 1 & change_`var' == . /*more than 1 row, but no change: replace missing with the 1 value that is observed*/
		}

		unique pid if change_all>0 /*--> only 16 individuals left with changes in the var*/

		/*for those 16 individuals with change, we take the most recent available info*/
		foreach var in lb0013_h lb0019_h lb0060 lb0311 lb0312_h lb0313 lb0314_h lb0315_h lb0316 lb0317_h lb0318_h lb0319 lb0320_h lb0382 lb1168 lb1143 lr3193 {
			forvalues nrows = 1/4 /*n rows observed*/ {
				/*value from last row if nonmissing*/
				by pid: replace `var' = `var'[`nrows'] if !missing(`var'[`nrows']) & N ==`nrows' & change_`var' == 1 /*change in this var*/
				/*value from 2nd to last row if last row missing*/
				by pid: replace `var' = `var'[`nrows'-1] if !missing(`var'[`nrows'-1]) & missing(`var'[`nrows']) & N ==`nrows' & N > 1 & change_`var' == 1 
				/*value from 3rd to last row if last & 2nd to last row missing*/
				by pid: replace `var' = `var'[`nrows'-2] if !missing(`var'[`nrows'-2]) & missing(`var'[`nrows']) & missing(`var'[`nrows'-1]) & N ==`nrows' & N > 2 & change_`var' == 1 
				/*value from 4th to last (= 1st, bc max = 4) row if last, 2nd & 3rd to last row missing*/
				by pid: replace `var' = `var'[`nrows'-3] if !missing(`var'[`nrows'-3]) & missing(`var'[`nrows']) & missing(`var'[`nrows'-1]) & missing(`var'[`nrows'-2]) & N ==`nrows' & N > 3 & change_`var' == 1 
			}
		}
		
		
/* sufficient?
		foreach var in lb0013_h lb0019_h lb0060 lb0311 lb0312_h lb0313 lb0314_h lb0315_h lb0316 lb0317_h lb0318_h lb0319 lb0320_h lb0382 lb0382 lb1168 lb1143 lr3193 {
			forvalues nrows = 1/4 /*n rows observed*/ {
				by pid: replace `var' = `var'[`nrows'] if !missing(`var'[`nrows']) & n ==`nrows' 
			}
		}
*/
		/*keep only 1 row / individual*/
		keep if n == 1

		/*keep only vars we need*/
		keep pid lb0013_h lb0019_h lb0060 lb0311 lb0312_h lb0313 lb0314_h lb0315_h lb0316 lb0317_h lb0318_h lb0319 lb0320_h lb0382 lb0382 lb1168 lb1143 lr3193 

		tempfile biol_merge 
		
		save `biol_merge'
	restore 
	
	
	/*merge cleaned biol data stored as temp data*/
	
	#delimit ; 
	merge m:1 pid using `biol_merge', 
		gen(_merge_biol) 
		keepusing(
		/*migration*/
		lb0013_h 	/*place of birth (inside/outside DE)*/
		lb0019_h 	/*year moving to DE*/
		/*info on i's parents*/
		lb0060		/*Grown Up With Parents ('84-'99)*/
		lb0382		/*Grown Up With Parents (much fewer obs, mostly '94 & '95)*/
		/*marriage*/
		lb0311 		/*marital status*/
		lb0312_h 	/*marriage 1: year of marriage*/
		lb0313 		/*marriage 1: marriage status (married, divorced, widowed)*/
		lb0314_h 	/*marriage 1: year end of marriage*/
		lb0315_h 	/*marriage 2: year of marriage*/
		lb0316 		/*marriage 2: marriage status (married, divorced, widowed)*/
		lb0317_h 	/*marriage 2: year end of marriage*/
		lb0318_h 	/*marriage 3: year of marriage*/
		lb0319 		/*marriage 3: marriage status (married, divorced, widowed)*/
		lb0320_h	/*marriage 3: year end of marriage*/
		);
	#delimit cr  
	
	/* Result                 		# of obs.
    -----------------------------------------
    not matched                       149,655
        from master                    68,808  (_merge_biol==1)		--> ??? Who are those people???
        from using                     80,847  (_merge_biol==2)		--> not linked, no rv_id (drop)

    matched                         5,426,496  (_merge_biol==3)		--> linked i
    -----------------------------------------
	*/
	
	drop if _merge_biol==2
	
	
	*************
	/* bioagel */
	*************
	/*Parent-Child Information*/
	
	/*Individuals are asked these Qs over different years. 
	Each year contained different focus (e.g. 2003-> Mothers with young children only)
	The rows are constructed such that the child id is the pid. Thus, if an individual
	has several children, than there are several observations per syear.
	
	Before merging we reshape the data to have information for child the children 
	in each row if it is filled in the same year. In the end we are most interested 
	in child nr.1
	 */
	
	preserve 
	
		use "${data_soep}/bioagel.dta", clear
		
		rename pid kid
		rename pide pid
		
		local vars "suppartn hwsupprt nchild maincare fathinhh biochild biopar_fid famofreq_fid fathfreq_fid mothinhh"
		
		keep syear pid kid `vars' 
		sort pid syear kid 

		/*count rows / individual*/
		by pid syear: gen n = _n
		sum n
		/*local for all variables that will be created*/
		local all_vars
		forval n=1/`r(max)' {
		foreach var of local vars {
             local all_vars `all_vars' `var'`n'
			}
		}
	
		/*reshape to wide*/
		reshape wide kid `vars', j(n) i(pid syear) 

		/*mark empty entries*/
		foreach var of local all_vars {
			replace `var'=.x if `var'==.
			replace `var'=. if `var'<0

		}
		
		/*save in tempfile*/
		tempfile bioagel_merge 
		save `bioagel_merge'
	
	restore 
	
	/*merge cleaned bioagel data stored as temp data*/
	
	#delimit ; 
	merge m:1 pid syear using `bioagel_merge', 
		gen(_merge_bioagel) 
		keepusing(
		kid*			/*kid n ID*/
		nchild* 		/*kid n - numbered kid*/
		biochild* 		/*kid n biological child*/
		mothinhh* 		/*kid n mother in hh*/
		fathinhh* 		/*kid n father in hh*/
		suppartn* 		/*support by partner*/ 
		maincare* 		/*main careperson mother*/ 
		hwsupprt* 		/*Amount of support of partner*/ 
		biopar_fid* 	/*mother/father respondant*/
		famofreq_fid*	/*freq. child sees mother/father*/
		fathfreq_fid*	/*freq. child sees father*/
		);
	#delimit cr  
	
	/* Result                 		# of obs.
    -----------------------------------------
    not matched                       XX
        from master                    XX  (_merge_bioagel==1)		--> ??? Who are those people???
        from using                     XX  (_merge_bioagel==2)		--> not linked, no rv_id (drop)

    matched                         XX  (_merge_bioagel==3)		--> linked i
    -----------------------------------------
	*/
	
	drop if _merge_bioagel==2
	
	
	**************
	/* biobirth */
	**************
	/*Generated biographical information*/

	#delimit ; 
	merge m:1 pid using "$data_soep/biobirth.dta", 
		gen(_merge_biobirth) 
		keepusing(
		sumkids 		/*total N births*/
		kidgeb* 		/*year of birth xth child (kidgeb01, kidgeb02, ..., kidgeb19*/
		kidmon* 		/*month of birth xth child (kidmon01, kidmon02, ..., kidmon19*/
		);
	#delimit cr 
	
	
    /* Result                           # of obs.
    -----------------------------------------
    not matched                       145,732
        from master                         0  (_merge_biobirth==1)
        from using                    145,732  (_merge_biobirth==2)		--> not linked, no rv_id (drop)

    matched                         5,495,304  (_merge_biobirth==3)		--> linked i
    -----------------------------------------
	*/
	
	drop if _merge_biobirth==2 

	
	************
	/*bioparen*/
	************
	
	/*This dataset contains information on the SOEP respondents' parents. Info 
	is invariant = 1 row / individual.
	
	Most relevant for us, it includes a measure for the N years the respondent 
	lived with with their parents.
	
	bioparen also contains the parents' SOEP ID if they are in the SOEP sample. 
	This is typically true for cases where the SOEP started in a household with 
	children, the children grew up and where followed in the SOEP when moving to 
	their own new hosuheold. In these cases the former children are now 
	respondents in the SOEP and their parents are also in the sample. 
	
	SOEP ID for parents: 
		- fnr: ID father 
		- mnr: ID mother 
		--> both are -1 if missing = parents not in the SOEP */
	
	#delimit ; 
	merge m:1 pid using "$data_soep/bioparen.dta", 
		gen(_merge_bioparen) 
		keepusing(
		living* 	/*living1-living8 = N years the respondent lived with different family constellations (as a child, < 15)*/
		fnr 		/*SOEP ID father*/
		mnr 		/*SOEP ID father*/
		);
	#delimit cr 
	
	drop if _merge_bioparen==2 
	
	***********************************
	** save preliminary data version **
	***********************************
	compress
	save "$datawork/soeprv_edited.dta", replace
	
	
	***********************
	/*biomarsm & biomarsy*/
	***********************
	
	**run code that prepares marsm & marsy data**
	do "$do/mp_SOEP_02a_maritalinfo.do" 
	
	/*dummies for LC / RC*/
	gen dummy_lc = 0
		replace dummy_lc = 1 if inlist(censorm_corr, 1, 2, 7, 8, 9, 10, 11, 12, 13, 14) 
	gen dummy_rc = 0
		replace dummy_rc = 1 if inrange(censorm_corr, 3, 14) 
		
	/*put label on spells that cover nth marriage (n = 1, 2)*/
	sort pid spelltyp beginy beginmonth /*chronological order of events*/
	by pid spelltyp: gen label_marr = _n if inlist(spelltyp, 2, 7) /*married (2), icl. civil partnerships (7), excl. living separated (6)*/	 
	
	/*gen time invariant vars with info on nth marriage
	
		naming convention: 
			- y = year of event, e.g. beginy */
	
	qui sum nmarriage
	local max = r(max) /*store max N marriages in local for loop*/
	
	forvalues n = 1/`max' /*loop over 1st, 2nd, ..., nth marriage*/ {
		
		*****************
		** beginy/endy **
		*****************
		/*tempvar stores year begin/end marriage in row*/
		gen marr`n'beginy = beginy if label_marr==`n' & beginy>0
		gen marr`n'endy   = endy   if label_marr==`n' & endy>0
		
		/*have year in every row for i*/
		by pid: ereplace marr`n'beginy = max(marr`n'beginy) 
		by pid: ereplace marr`n'endy   = max(marr`n'endy) 
		
		*******************
		** beginmy/endmy **
		*******************
		gen marr`n'beginmy = beginmonth if label_marr==`n' & beginmonth>0
		gen marr`n'endmy   = endmonth   if label_marr==`n' & endmonth>0 
		
		/*correct spells with wrong month info from marsm
			--> set begin/end missing if lc/rc in marsm
			--> unless year from marsy is same as marsm: then keep marsm month*/
		replace marr`n'beginmy = . if dummy_lc==1 & beginy!=year(dofm(beginmonth))
		replace marr`n'endmy   = . if dummy_rc==1 & endy!=year(dofm(endmonth)) 
		
		/* replace missing with random months 
			--> flag these cases
			--> take year from marsy & put random month
			--> this applies to missings created above + spells that are only in marsy */
		gen marr`n'beginmy_random = 0 if label_marr==`n' 
			replace marr`n'beginmy_random = 1 if label_marr==`n' & missing(marr`n'beginmy)
		gen marr`n'endmy_random = 0 if label_marr==`n' 
			replace marr`n'endmy_random = 1 if label_marr==`n' & missing(marr`n'endmy)
		
		replace marr`n'beginmy = ym(beginy, runiformint(1, 12)) if label_marr==`n' &  missing(marr`n'beginmy)
		replace marr`n'endmy   = ym(endy,   runiformint(1, 12)) if label_marr==`n' &  missing(marr`n'endmy)
		
		/*remaining missings for cases with label_marr==n & missing beginy/endy --> only few cases*/
		
		/*have monthly begin/end in every row for i*/
		by pid: ereplace marr`n'beginmy = max(marr`n'beginmy)
		by pid: ereplace marr`n'endmy   = max(marr`n'endmy)
		format %tmMonth_CCYY marr`n'beginmy
		format %tmMonth_CCYY marr`n'endmy
		
		/*have dummy for random month in every row for i*/
		by pid: ereplace marr`n'beginmy_random = max(marr`n'beginmy_random) 
		by pid: ereplace marr`n'endmy_random   = max(marr`n'endmy_random ) 
		
		*****************
		** beginm/endm **
		*****************
		/*calendar month (e.g., 2 = February)*/
		gen marr`n'beginm = month(dofm(marr`n'beginmy)) if marr`n'beginmy>0
		gen marr`n'endm   = month(dofm(marr`n'endmy)) if marr`n'endmy>0
		
		**************************
		** type end of marriage ** 
		**************************
		/*(separation / death)*/
		sort pid spellnr 
		
		/*tempvar stores endtype marriage n in row*/
		tempvar endtype
		gen `endtype' = . 
			replace `endtype' = spelltyp[_n+1] if label_marr==`n' & pid==pid[_n+1] & dummy_rc==0 /*next status if not RC*/ 
			replace `endtype' = 9 if label_marr==`n' & dummy_rc==1 /*9 (= gap) if RC*/ 
			/* 
			** Alternative: define grouped spell types **
			/*	1 = divorce/separation 
				2 = death of partner 
				3 = gap (no info)
			problem: Not clear how to deal with spelltype [5] divorced/widowed */
			
			replace `endtype' = 1 if  label_marr==`n' /*spell = marriage n */ ///
									& inlist(spelltyp[_n+1], 2, 3, 6, 7) /*next spell: separated [6], divorced [3], married / civil partnership (again) [2, 7]) */ ///
									& pid==pid[_n+1] /*make sure it's same i*/ / ///
									& dummy_rc==0 /*make sure it's not RC*/ 
			replace `endtype' = 2 if  label_marr==`n' /*spell = marriage n */ ///
									& spelltyp[_n+1]==4 /*next spell: widowed) [4] */ /// 
									& pid==pid[_n+1] /*make sure it's same i*/ /// 
									& dummy_rc==0 /*make sure it's not RC not RC*/ 
			replace `endtype' = 3 if label_marr==`n' & dummy_rc==1 /*9 (= gap) if RC*/
		*/
		
		/*have endtype marriage n in every row for i*/
		by pid: egen marr`n'end_type = max(`endtype') 
			label variable marr`n'end_type "End of Marriage: Spelltype"
			label values marr`n'end_type spelltyp
	}

	***************************************************
	**save dataset with info on begin/end marriage(s)**
	***************************************************
	
	/*keep only 1 row / i*/
	by pid: keep if _n == 1
	
	/*keep only relevant vars = pid + info on begin/end marriages*/
	keep pid marr*begin* marr*end* 
	
	/*rename to label as soep data*/
	rename (*) (*_soep) /*adds_soep to all vars*/
	rename pid_soep pid /*removes _soep from pid*/
	
	tempfile marriage_spells
	
	save `marriage_spells', replace
	
	**go back to preliminary data version**
	use "$datawork/soeprv_edited.dta", clear
	
	merge m:1 pid using `marriage_spells'

	/* Result                     	# of obs.
    -----------------------------------------
    not matched                         2,959
        from master                     2,088  (_merge==1) --> i SOEP-IS (?) --> keep
        from using                        871  (_merge==2) --> i gave consent but not linked --> drop

    matched                         5,493,216  (_merge==3) --> i x t for matched 
    ----------------------------------------- */
	
	drop if _merge==2
	drop _merge
	
	***********************************
	** save preliminary data version **
	***********************************
	save "$datawork/soeprv_edited.dta", replace

	*************************
	/*biocouplm & biocouply*/
	*************************
	/*--> similar to code above but now its all relationships and not only marriage*/
	
	**run code that prepares couplm & couply data**
	do "$do/mp_SOEP_02b_coupleinfo.do" 
	
	** merge **
	tempfile relationship_spells
	save `relationship_spells', replace
	
	**go back to preliminary data version**
	use "$datawork/soeprv_edited.dta", clear
	
	merge m:1 pid using `relationship_spells'

	/* Result                     	# of obs.
    -----------------------------------------
    not matched                         2,959
        from master                     2,088  (_merge==1) --> i SOEP-IS (?) --> keep
        from using                        871  (_merge==2) --> i gave consent but not linked --> drop

    matched                         5,493,216  (_merge==3) --> i x t for matched 
    ----------------------------------------- */
	
	drop if _merge==2
	
	*********************************
	/* adjust marriage information */
	*********************************
	/*We randomized months for marriage & relationship but need it to be 
	synchronized whenever the relationship is a marriage*/
	
	** Store Relationship number of marriage **
	gen marr1_rel_nr = .
	gen marr2_rel_nr = .
	gen marr3_rel_nr = .
	gen marr4_rel_nr = .

	forval n=1/22 {
		replace marr1_rel_nr = `n' if rel`n'_type_soep == 4 /*marriage*/ ///
								& missing(marr1_rel_nr) /*only first entry*/
		replace marr2_rel_nr = `n' if rel`n'_type_soep == 4 /*marriage*/ ///
								& missing(marr2_rel_nr) /*only first entry*/ ///
								& `n'>marr1_rel_nr	/*not first marriage*/
		replace marr3_rel_nr = `n' if rel`n'_type_soep == 4 /*marriage*/ ///
								& missing(marr3_rel_nr) /*only first entry*/ ///
								& `n'>marr2_rel_nr	/*not marriages before*/
		replace marr4_rel_nr = `n' if rel`n'_type_soep == 4 /*marriage*/ ///
								& missing(marr4_rel_nr) /*only first entry*/ ///
								& `n'>marr3_rel_nr	/*not marriages before*/
	}
			
	** Adjust begin and end of relationships to match marriage info **
	qui sum marr4_rel_nr
	/*To-Do: Somehow there are some mistakes with second marriages - which start 
	during the first marriage but are only visable in the relitanship variable
	--> was to tired to fix that*/
	forval n=1/1  /*marriage*/ {
	forval m=1/`r(max)' /*relationship*/ {
		
		* Marriage *
		replace rel`m'beginm_soep 	= marr`n'beginm_soep	if marr`n'_rel_nr==`m'
		replace rel`m'endm_soep 	= marr`n'endm_soep 		if marr`n'_rel_nr==`m'
		replace rel`m'beginmy_soep 	= marr`n'beginmy_soep 	if marr`n'_rel_nr==`m'
		replace rel`m'endmy_soep 	= marr`n'endmy_soep		if marr`n'_rel_nr==`m'
		
		* Relationship after - only if not marriage*
		if `m'<22 {
		local b = `m' + 1

		replace rel`b'beginm_soep 	= marr`n'endm_soep+1 	if marr`n'_rel_nr==`m' & rel`b'_type_soep!=4
		replace rel`b'beginmy_soep 	= marr`n'endmy_soep+1 	if marr`n'_rel_nr==`m' & rel`b'_type_soep!=4
		}
		
		* Relationship before -  only if not marriage *
		if `m'>1 {
		local e = `m' - 1
		
		replace rel`e'endm_soep 	= marr`n'beginm_soep-1 	if marr`n'_rel_nr==`m' & rel`e'_type_soep!=4
		replace rel`e'endmy_soep 	= marr`n'beginmy_soep-1 if marr`n'_rel_nr==`m' & rel`e'_type_soep!=4
		}
		
	}
	}
	
********************************************************************************
** Generate new variables from VSKT **
********************************************************************************

	****************************************************************************
	/* Define Labels */
	****************************************************************************
	
	do "$do/mp_labels.do"

	****************************************************************************
	/* Date Variables */
	****************************************************************************

	* monthly date of observation *
	gen monthly = ym(JAHR, MONAT) /* monthly: monthly calendar date e.g. 2013m1; monthly == 636 for 01-2013*/
		format monthly %tm
		label variable monthly "Date (monthly) of observation"

	
	****************************************************************************
	/* Define panel structure */
	****************************************************************************
	xtset rv_id monthly	/* Panel: id = rv_id; t = monthly */
	sort rv_id monthly 

	
	****************************************************************************
	/* Demographics */
	****************************************************************************
	
	*********
	** Age **
	*********
	/*no monthly age b/c no birth month in SOEP-RV data*/
	gen age = JAHR - GBJAVS /*calendar year  - birth year*/
		label variable age "Age (end of year)" 
		
	/* Date of Birth */
	/*no monthly birth date b/c no birth month in SOEP-RV data*/
	gen birth_year = GBJAVS
		label variable birth_year "Date of birth (year)"		
	gen birth_decade = floor(birth_year/10)*10
		label variable birth_decade "Date of birth (decade)"
	
	/* Female */
	gen female = 0	
		replace female = 1 if GEVS == 2
		label variable female "Female"
		label values female female	
	
	
	*****************
	** East / West **
	*****************
	
	/*--> this includes both pre and post reunification*/
	
	/*SOEPRV data has info on monthly employment in east/west in STATUS_1:
		WSB = gainful employment (subject to social insurance contributions) – west
		WKN = miner’s employment – west
		OSB = gainful employment (subject to social insurance contributions) – east since 7/1990
		OKN = miner’s employment – east since 7/1990
		DDR OSB = gainful employment (subject to social insurance contributions) – east until 6/1990
		DDR OKN = miner’s employment – east until 6/1990
		WSS = self-employment (obligated to pay social insurance) – west
		OSS = self-employment (obligated to pay social insurance) – east
	*/
	
	** dummy east for current month **
	/*this is only filled if i is employed in t*/
	gen east_monthly = . 
		replace east_monthly = 0 if inlist(STATUS_1, "WKN", "WSB", "WSS")
		replace east_monthly = 1 if inlist(STATUS_1, "OKN", "OSB", "OSS", "DDR OKN", "DDR OSB")
		label variable east_monthly "east/west this month"
		label values east_monthly east
	
	** dummy east - imputed **
	/*this fills missing east/west info for months with missing STATUS_1
		--> take closest month 
		--> if same distance pre/post we take post "ties(after)"*/
	bys rv_id: mipolate east_monthly monthly, nearest ties(after) gen(east_monthly_imputed)
		label variable east_monthly_imputed "east/west this month (imputed)"
		label values east_monthly_imputed east 
	
	** first EP east/west **
	/*this var captures east/west for the first month we observe an individual 
		--> proxy for the individual grew up */
	tempvar first
	by rv_id: egen `first' = min(monthly) if STATUS_1!="" /*first month with nonmissing STATUS_1*/
	gen east_first = east_monthly if monthly==`first' 
		by rv_id: ereplace east_first = max(east_first)
		label var east_first "east/west 1st observed month"
		label values east_first east
	
	
	****************************************************************************
	/* Marriage/Divorce */
	****************************************************************************
	
	/*gen vars with similar naming to those from SOEP --> facilitate loops etc */
	forvalues n = 1/2 {
		/*begin marriage*/ 
		gen marr`n'beginy_vskt 	= EB`n'_JAHR if EB`n'_JAHR>0 /*-2 if missing*/
		gen marr`n'beginm_vskt 	= EB`n'_MONAT if EB`n'_MONAT>0 /*-2 if missing*/ 
		gen marr`n'beginmy_vskt	= ym(EB`n'_JAHR, EB`n'_MONAT)
			format %tmMonth_CCYY marr`n'beginmy_vskt
		/*end marriage = separation = divorce date - 12 moths*/
		gen marr`n'endy_vskt	= ES`n'_JAHR - 1 /* --> year of divorce -1*/
			replace marr`n'endy_vskt	= . if marr`n'endy_vskt<0 /* correct missing value*/
		gen marr`n'endm_vskt	= ES`n'_MONAT if ES`n'_MONAT>0 	/*--> same calendar month, -2 if missing*/
		gen marr`n'endmy_vskt	= ym(ES`n'_JAHR, ES`n'_MONAT) - 12 /*divorce date - 12 moths*/
			format %tmMonth_CCYY marr`n'endmy_vskt
	}

	****************************************************************************
	/*Labor market participation*/
	****************************************************************************
	
	/*dummy for whether a person is active in the labor market in a given month 
		--> active in the labor market = generating labor income 
		--> we differentiate 3 types of labor market participation: 
			1) regular employment (subject to social insurance contributions)
				STATUS_1 =	"WSB" / "OSB" / "DDR OSB" --> regular employment west / east / GDR
							"WKN" / "OKN" / "DDR OKN" --> miner’s employment west / east / GDR
				(in addition, STATUS_2 and _3 also covers employment if i has > 1 job 
					--> here we only care about 0/1, so we don't need that info)
			2) mini-job employment 
				STATUS_4_TAGE =	mini-job w/o insurance contributions
				STATUS_5_TAGE = mini-job w/ insurance contributions
			3) self employment (not well covered in the VSKT)
				STATUS_1 =	"WSS" / "OSS" --> compulsory self-employment contribution west / east
			*/
	*** dummy regular employment ***
	gen dummy_employed_regular = 0
		replace dummy_employed_regular = 1 if inlist(STATUS_1, "WSB", "OSB", "DDR OSB", "WKN", "OKN", "DDR OKN") 
		label var dummy_employed_regular "Regular employment (VSKT)"

	*** dummy minijob employment ***
	gen dummy_employed_minijob = 0
		replace dummy_employed_minijob = 1 if !missing(STATUS_4_TAGE) | !missing(STATUS_5_TAGE) 
		label var dummy_employed_minijob "Mini-job (VSKT)"
	
	*** dummy minijob employment only (= no other employment) ***
	gen dummy_employed_minijobonly = 0
		replace dummy_employed_minijobonly = 1 if (!missing(STATUS_4_TAGE) | !missing(STATUS_5_TAGE)) & STATUS_1 == "" 
		label var dummy_employed_minijobonly "Mini-job only (VSKT)"	
		
	*** dummy self employment ***
 	gen dummy_selfemployed = 0
		replace dummy_selfemployed = 1 if inlist(STATUS_1, "WSS", "OSS") 
		label var dummy_selfemployed "Self-employment (VSKT)"

	*** dummy any work (any of the above) ***
	gen dummy_work = 0
		replace dummy_work=1 if inlist(1, dummy_employed_regular, dummy_employed_minijobonly, dummy_selfemployed)
		label var dummy_work "Any (self-)employment (VSKT)"
		
	
	***********************************
	/*Labor market experience (years)*/
	***********************************
	
	/*Measure for since when has an individual been in the labor market
		--> we take the first month with regular or self employment 
			(not counting mini-jobs)*/
	by rv_id: egen age_labor_market = min(monthly) if dummy_employed_regular==1 |  dummy_selfemployed==1 /*min for rows with regular/self employment*/
	by rv_id: ereplace age_labor_market=min(age_labor_market) /*min in all rows*/
	replace age_labor_market = monthly-age_labor_market /*months since first regular/self employment*/
	replace age_labor_market = floor(age_labor_market/12) /*round to years, year 0 = month 0-11 etc.*/
	label var age_labor_market "years in the labor market"
	
	
	********************
	/* Overall Income */
	********************
	
	/* Earningspoints from labor income (employment & self employment) */
	* all observations *
	egen MEGPT_work = rowtotal(STATUS_1_EGPT STATUS_5_EGPT)
		replace MEGPT_work = MEGPT_work + STATUS_2_EGPT if STATUS_2=="NJB" & STATUS_2_EGPT!=.
		replace MEGPT_work = MEGPT_work + STATUS_2_EGPT if STATUS_3=="NJB" & STATUS_3_EGPT!=.
		/* 1 = Beschäftigung
		   2 = Andere sozialversichpf. oder selbst. Erwerbstätigkeiten (NJB=Nebenjob)		   
		   3 = - " -
		   5 = geringfügige Beschäftigung mit Versicherungspflicht */
		label variable MEGPT_work "EP from labor income"
	* only those who have labor income *
	gen MEGPT_work_positive = MEGPT_work if MEGPT_work>0
		label variable MEGPT_work_positive "EP from labor income"
			
			
	****************************************************************************
	/* Children */
	****************************************************************************	
	
	/*rename Childbirth variable for loop - combine with SOEP data later to 
	receive information on men*/
	forvalues n = 1/10 {
		gen child`n'birthy_vskt 	= GBKIJ`n' if GBKIJ`n'>0 /*want missing "." instead of 0 to align missings*/
		gen child`n'birthm_vskt 	= GBKIM`n' if GBKIM`n'>0
		gen child`n'birthmy_vskt 	= ym(GBKIJ`n', GBKIM`n')
	
		format %tmMonth_CCYY child`n'birthmy_vskt
	}
	
	/*Number of children*/
	gen nchildren_vskt=0
	forval n=1/10 {
		replace nchildren_vskt=nchildren_vskt+1 if !missing(child`n'birthy_vskt)
	}
		

	
********************************************************************************
** Generate new variables from SOEP **
********************************************************************************

	****************************************************************************
	/* statistical weights */
	****************************************************************************
	preserve 
	do "$do/mp_RV_SOEP_01b_reweighting.do"
	restore
	
	merge m:1 pid using "$datawork/soeprv_adjusted_weights.dta", gen(_merge_weights)
	
	drop if _merge_weights==1 /*master only --> that's only 1 observation*/
	drop if _merge_weights==2 /*using only*/
	
	****************************************************************************
	/* labor income */
	****************************************************************************
	gen income=ijob1+ijob2+iself
	label variable income "Overall Income (Erwerbseinkommen)"
	
	****************************************************************************
	/* Time Use */
	****************************************************************************

	***********
	** Daily **
	***********

	* workweek *
	gen labour_wd_hours=pli0038_h if pli0038_h>=0
		replace labour_wd_hours=18 if labour_wd_hours>18 & !missing(labour_wd_hours)
	gen errands_wd_hours=pli0040 if pli0040>=0
		replace errands_wd_hours=18 if errands_wd_hours>18 & !missing(errands_wd_hours)
	gen house_wd_hours=pli0043_h if pli0043_h>=0
		replace house_wd_hours=18 if house_wd_hours>18 & !missing(house_wd_hours)
	gen child_wd_hours=pli0044_h if pli0044_h>=0
		replace child_wd_hours=18 if child_wd_hours>18 & !missing(child_wd_hours)
	gen careperson_wd_hours=pli0046 if pli0046>=0
		replace careperson_wd_hours=18 if careperson_wd_hours>18 & !missing(careperson_wd_hours)
	gen education_wd_hours=pli0047_v1 if pli0047_v1>=0
		replace education_wd_hours=18 if education_wd_hours>18 & !missing(education_wd_hours)
	gen reperation_wd_hours=pli0049_h if pli0049_h>=0
		replace reperation_wd_hours=18 if reperation_wd_hours>18 & !missing(reperation_wd_hours)
	gen leisure_wd_hours=pli0051 if pli0051>=0
		replace leisure_wd_hours=18 if leisure_wd_hours>18 & !missing(leisure_wd_hours)
	gen sleep_wd_hours=pli0059 if pli0059>=0
		/*replace sleep_hours=18 if sleep_hours*/

	*combine vars
	gen labourwork_wd_hours=labour_wd_hours+education_wd_hours

	gen housework_wd_hours=house_wd_hours+reperation_wd_hours+errands_wd_hours

	gen carework_wd_hours=child_wd_hours+careperson_wd_hours
	
	* weekend *
	gen labour_we_hours=pli0003_h if pli0003_h>=0	/*saturday*/
		replace labour_we_hours=labour_we_hours + pli0007_h if pli0007_h>=0	/*sunday*/
		replace labour_we_hours=36 if labour_we_hours>36 & !missing(labour_we_hours)

	gen errands_we_hours=pli0011 if pli0011>=0	/*sunday*/
		replace errands_we_hours=18 if errands_we_hours>18 & !missing(errands_we_hours)

	gen house_we_hours=pli0012_h if pli0012_h>=0	/*saturday*/
		replace house_we_hours=house_we_hours + pli0016_h if pli0016_h>=0	/*sunday*/
		replace house_we_hours=36 if house_we_hours>36 & !missing(house_we_hours)

	gen child_we_hours=pli0019_h if pli0019_h>=0	/*saturday*/
		replace child_we_hours=child_we_hours + pli0022_h if pli0022_h>=0	/*sunday*/
		replace child_we_hours=36 if child_we_hours>36 & !missing(child_we_hours)

	gen careperson_we_hours=pli0055 if pli0055>=0	/*saturday*/
		replace careperson_we_hours=child_we_hours + pli0057 if pli0057>=0	/*sunday*/
		replace careperson_we_hours=36 if careperson_we_hours>36 & !missing(careperson_we_hours)

	gen education_we_hours=pli0024_h if pli0024_h>=0	/*saturday*/
		replace education_we_hours=education_we_hours + pli0028_h if pli0028_h>=0	/*sunday*/
		replace education_we_hours=36 if education_we_hours>36 & !missing(education_we_hours)
	
	gen reperation_we_hours=pli0031_h if pli0031_h>=0	/*saturday*/
		replace reperation_we_hours=reperation_we_hours + pli0034_v4 if pli0034_v4>=0	/*sunday*/
		replace reperation_we_hours=36 if reperation_we_hours>36 & !missing(reperation_we_hours)

	gen leisure_we_hours=pli0036 if pli0036>=0	/*saturday*/
		replace leisure_we_hours=leisure_we_hours + pli0010 if pli0010>=0	/*sunday*/
		replace leisure_we_hours=36 if leisure_we_hours>36 & !missing(leisure_we_hours)

	gen sleep_we_hours=pli0060 if pli0060>=0
	
	*combine vars
	gen labourwork_we_hours=labour_we_hours+education_we_hours

	gen housework_we_hours=house_we_hours+reperation_we_hours+errands_we_hours

	gen carework_we_hours=child_we_hours+careperson_we_hours


	*************
	** Monthly **
	*************
	/*available only for labour hours worked*/
	gen labour_weekly_hours	 = pgvebzeit if pgvebzeit>=0 /*contractual*/
	gen labour_weekly_hours_eff = pgtatzeit if pgtatzeit>=0 /*actuall/effective*/
	

	
	****************************************************************************
	/* Children */
	****************************************************************************	
	
	/*rename Childbirth variable for loop*/
	forvalues n = 1/9 {
		rename kidgeb0`n' kidgeb`n'
		rename kidmon0`n' kidmon`n'
	}
	
	//Issue should we differntiate between -1 & -2 as -2 could refer to no child and -1 to no information?
	forvalues n = 1/19 {
		gen child`n'birthy_soep	 = kidgeb`n' if kidgeb`n'>0
		gen child`n'birthm_soep	 = kidmon`n' if kidmon`n'>0
		gen child`n'birthmy_soep = ym(child`n'birthy_soep ,  child`n'birthm_soep)
		format %tmMonth_CCYY child`n'birthmy_soep
	}
	
	/*variable correction of kidgeb*/
	/* Issue: For some observations, childbirth info is missing for child 1 but not for 
	child 2. What should we do?
	Idea: Shift information for first child. To see type:
	br pid female GBKIJ1 GBKIJ2 GBKIJ3 kidgeb* if kidgeb1<0 & kidgeb2>0
	unique pid if kidgeb1<0 & kidgeb2>0
	
	foreach period in y m my {
		forval n=1/18 {
			local a=n+1
			replace child`n'birth`period'_soep=child`a'birth`period'_soep if kidgeb1<0 & kidgeb2>0
		}
	}
	*/
	
	
	/* replace missing with random months 
		--> flag these cases
		--> take year from kidgeb & put random month */
	sort rv_id syear 
	forvalues n = 1/19 {
		gen child`n'birthmy_random = 0 if !missing(child`n'birthy_soep) 
			replace child`n'birthmy_random = 1 if !missing(child`n'birthy_soep) & missing(child`n'birthm_soep)   /*dummy for random month */
		
		by rv_id: replace child`n'birthmy_soep = ym(child`n'birthy_soep, runiformint(1, 12)) if  child`n'birthmy_random == 1
		by rv_id: replace child`n'birthmy_soep = child`n'birthmy_soep[1] if  child`n'birthmy_random == 1
	}	

	/*number of children*/
	gen nchildren_soep=0
	forval n=1/19 {
		replace nchildren_soep=nchildren_soep + 1 if !missing(child`n'birthy_soep)
	}
	
	****************************************************************************
	/* Relationship Status */	
	****************************************************************************
	/*use current and biography data
	--> current information: 
		- partner: status of partnership (No partner=0; spouse=1/3; partner=2/4) 
		- pld0133: partner lives in hh (yes=1/no=2), 
		- - h11110 d11107 d11106: people in household
	--> bio information:
		- rel`n'begin`period'_soep rel`n'end`period'_soep 
		- rel`n'_type_soep: what kind of relationship_status
		*/
		
		* Dummy for each partnership atm*/
		gen rel_hh=.
		gen rel_nothh=.
		gen single=.
		
		gen rel_hh_nr=.
		gen rel_nothh_nr=.
		gen single_nr=.
		
			forval n=1/16 {
				
				***Relationship at that moment***
				/*use biography information*/
				replace rel_hh=1 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep==3
				replace rel_hh_nr=`n' if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) /// 
								& rel`n'_type_soep==3
				*other type of relationship info at that point
				replace rel_hh=0 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep!=3 & !missing(rel`n'_type_soep)
				
				/*use current information --> only if not yet filled */
				replace rel_hh=1 if missing(rel_nothh) & inlist(partner, 2, 4) /*partner*/ & pld0133!=2 /*not partner outside hh*/
				replace rel_hh=0 if missing(rel_nothh) & inlist(partner, 2, 4) /*partner*/ & pld0133==2 /*partner outside hh*/
				
				***Relationship outside hh at that moment***
				replace rel_nothh=1 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep==2
				replace rel_nothh_nr=`n' if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep==2
				*other type of relationship info at that point
				replace rel_nothh=0 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep!=2 & !missing(rel`n'_type_soep)
				
				/*use current information --> only if not yet filled*/
				replace rel_nothh=1 if missing(rel_nothh) & partner==0 /*has partner*/ & pld0133==2 /*partner outside hh*/
				replace rel_nothh=0 if missing(rel_nothh) & pld0133==1 /*info that partner lives in hh*/
				
				***Single at that moment***
				replace single=1 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep==1
				replace single_nr=`n' if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) /// 
								& rel`n'_type_soep==1
				*other type of relationship info at that point
				replace single=0 if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) ///
								& rel`n'_type_soep!=1 & !missing(rel`n'_type_soep)
				
				/*use current information  --> only if not yet filled
				--> difficult to use since there is no differention between single and no partner in hh*/
				replace single=1 if missing(single) & partner==0 /*no partner*/ & pld0133==-2 /*partner hh = does not apply*/
				replace single=0 if missing(single) & inlist(partner, 1, 2, 3, 4) /*partner*/
			}
	/*issue: Always have different months due to randomization*/

	
	****************************************************************************
	** parents **
	****************************************************************************
	
	*** linkage with parents ***
	gen dummy_parents_linked = 0
		replace dummy_parents_linked = 1 if (fnr>-1 & !missing(fnr)) /*father linked*/ | (mnr>-1 & !missing(mnr)) /*mother linked*/
		label values dummy_parents_linked yesno 
		label var dummy_parents_linked "Parent(s) linked in SOEP"
		
	*** biography: living w/ parents ***
	/*There is a total of 8 living variables, capturing how many years a 
	repsondent lived in a certain family constellation as a child (< 15):
		living1: 	N years living with biological parents 
		living2: 	N years living with single mum 
		living3: 	N years living with mum + partner
		living4: 	N years living with single dad
		living5: 	N years living with dad + partner
		living7: 	N years living with foster parents
		living6: 	N years living with other relatives
		living8: 	N years living in children's home
	*/
	
	/*check whether variables are filled correctly
		--> sum of all living* should always be 15 
		--> b/c SOEP codes missings as -5/-3/-2 we need tempvars here*/
	forvalues x = 1/8 {
		tempvar help`x'
		clonevar `help`x'' = living`x'
		replace `help`x'' = . if `help`x''<0
	}
	egen grewup_years = rowtotal(`help1' `help2' `help3' `help4' `help5' `help6' `help7' `help8'), missing
		label var grewup_years "N years w/ info on family situation as a child"
		/*Conditional on being filled, the living* variables are almost always 
		filled correctly (sum = 15 years)! 
		To see this: 
		unique pid if grewup_years==15 		/* this is N individuals w/ full info*/
		unique pid if grewup_years<15 		/* this is N individuals w/ incomplete info*/
		unique pid if missing(grewup_years) /* this is N individuals w/o any info*/
		*/
	
	*dummy: all childhood w/ both parents*
	gen grewup_bothparents = .
		replace grewup_bothparents = 0 if inrange(living1, 0, 14) /*< 15/15 years with both parents*/
		replace grewup_bothparents = 1 if living1==15 /* 15/15 years with both parents*/
		forvalues x = 6/8 {
			replace grewup_bothparents = . if living`x'>0 & !missing(living`x') /*not filled if i lived w/o parents for at least 1 year*/
		}
		replace grewup_bothparents = . if grewup_years!=15
		label values grewup_bothparents yesno
		label var grewup_bothparents "Lived with both parents until 15 (& w/ single parent else)"
		
	*dummy: (some) childhood w/ single parent (potentially w/ partner)* 
	gen grewup_singleparent = . 
		replace grewup_singleparent = 0 if living2==0 & living3==0 & living4==0 & living5==0
		forvalues x = 2/5 {
			replace grewup_singleparent = 1 if inrange(living`x', 1, 15) /*at least 1 year with only 1 parent*/
		}
		forvalues x = 6/8 {
			replace grewup_singleparent = . if living`x'>0 & !missing(living`x') /*not filled if i lived w/o parents for at least 1 year*/
		}
		replace grewup_singleparent = . if grewup_years!=15
		label values grewup_singleparent yesno
		label var grewup_singleparent "Lived with single parent at least once (& w/ both parents else)"
			
		/*rn, grewup_bothparents and grewup_singleparent are mutually exclusive 
		and perfectly correlated (if one is 1 the other is 0). Keep both vars 
		in case we want to change definition / have more greup dummy vars. */
		
		
	****************************************************************************
	** Gender Norms **
	****************************************************************************
	/* Gender norm variables where either asked in 2012 or 2018
	Variable from 2012 have a 1-7 scalar on statements while in 2018 4 scale ratio
	from fully disagreeing - rather disagreeing - rather agreeing - fully agreeing */
	
	** global all variables
	global norms "plh0298_v1 plh0298_v2 plh0300_v1 plh0300_v2 plh0301 plh0302_v1 plh0302_v2 plh0303 plh0304 plh0305 plh0306 plh0308_v1 plh0308_v2 plh0309 plh0358 plh0359"
	
	** set missing answers to missing*/
	foreach var of global norms {
		replace `var'=. if `var'<0
	}
	
	** Generate new variables with aligned scale
	/* Aligned scale: Statements can be stated gender traditional or gender 
	progressive, allign scale s.t. high values are alway gender traditional and 
	scale is always 1-7. We translate the 1-4 scale from 1=1, 2=3, 3=5 & 4=7 or 
	vice versa. At the end of the rescaling we want:
	7=gender traditional and 1=gender progressive*/
	
	/*Child young than 6 suffers with working mum*/
	gen gn_workingmum6=plh0298_v1 
		recode gn_workingmum6 (1=7) (2=5) (3=3) (4=1)
	replace gn_workingmum6=plh0298_v2 if missing(gn_workingmum6)
		by rv_id: ereplace gn_workingmum6=mean(gn_workingmum6)
	label var gn_workingmum6 "Agreement to mother should stay at home with child younger 6"
	
	/*Child young than 3 suffers with working mum*/
	gen gn_workingmum3=plh0302_v1 
		recode gn_workingmum3 (1=7) (2=5) (3=3) (4=1)
	replace gn_workingmum3=plh0302_v2 if missing(gn_workingmum3)
		by rv_id: ereplace gn_workingmum3=mean(gn_workingmum3)
	label var gn_workingmum3 "Agreement to mother should stay at home with child younger 3"
	
	/*Women Should Rather Care About Family Than Career*/
	gen gn_carrerwomen=plh0301
		recode gn_carrerwomen (1=7) (2=5) (3=3) (4=1)
		by rv_id: ereplace gn_carrerwomen=mean(gn_carrerwomen)
	label var gn_carrerwomen "Agrement to Women Should Rather Care About Family Than Career"

	/*Best if man and woman work the same amount so they can share the responsibility*/
	gen gn_sharedrsp=plh0308_v1
		recode gn_sharedrsp (1=1) (2=3) (3=5) (4=7)
		tempvar help
		gen `help'=1 if !missing(gn_sharedrsp)
	replace gn_sharedrsp=plh0308_v2 if missing(gn_workingmum3)	
		recode gn_sharedrsp (1=7) (2=6) (3=5) (4=4) (5=3) (6=2)(7=1) if `help'!=1
		by rv_id: ereplace gn_sharedrsp=mean(gn_sharedrsp)
	label var gn_sharedrsp "Disagreement to Men and women should work equally"
	
	/*Fam: Men Involved in Housework
	gen gn_housemen=plh0303
		recode gn_housemen (1=1) (2=3) (3=5) (4=7)
		by rv_id: ereplace gn_housemen=mean(gn_housemen)
	label var gn_housemen "Disagreement to Men should be involved in housework"
	*/
	
	** predict score
	pca gn_workingmum6 gn_workingmum3 gn_carrerwomen gn_sharedrsp /*gn_housemen*/, component(4)
		predict pca_gn_workingmum6 pca_gn_workingmum3 pca_gn_carrerwomen pca_gn_sharedrsp
		
	egen gnorms1=rowmean(pca_gn_workingmum6 pca_gn_workingmum3 pca_gn_carrerwomen pca_gn_sharedrsp)	
	egen gnorms2=rowmean(gn_workingmum6 gn_workingmum3 gn_carrerwomen gn_sharedrsp)
	
	** choose gender norms score
	gen gender_progressive1=.
		replace gender_progressive1=1 if gnorms2<4
		replace gender_progressive1=0 if gnorms2>4
	gen gender_progressive2=.
		replace gender_progressive2=1 if gnorms2<3
		replace gender_progressive2=0 if gnorms2>5
	gen gender_progressive3=.
		replace gender_progressive3=1 if gnorms2<=2
		replace gender_progressive3=0 if gnorms2>=6
		
		
	**marital norms 
	gen mn_lifelong=plh0306
		recode gn_sharedrsp (1=1) (2=3) (3=5) (4=7)
		
		
	/*variable overview
				
		/*Child young than 6 suffers with working mum*/
		plh0298_v1 	//2012
		plh0298_v2 	//2018	
		/*Marry if lived with partner for long*/
		plh0300_v1 	//2012
		plh0300_v2	//2018
		/*Women Should Rather Care About Family Than Career*/
		plh0301		//2012
		/*Child young than 3 suffers with working mum*/
		plh0302_v1 	//2012
		plh0302_v2	//2018
		/*Fam: Men Involved in Housework*/
		plh0303		//2012
		/*Children Suffer When Father Focused On Career*/
		plh0304		//2012	
		/*Fam: Marriage is a Lifelong Union*/
		plh0305		//2012		
		/*Fam: Marriage When Child is Born*/
		plh0306		//2012	
		/*Best if man and woman work the same amount so they can share the responsibility*/
		plh0308_v1   //2012
		plh0308_v2   //2018
		/*WarmthFam: Working Mothers Equal Emotional*/ 
		plh0309		//2012
		/*Single Parent can raise child as well as couple*/
		plh0358		//2018
		/*Gleichgeschlechtliches Paar kann Kind genauso gut grossziehen*/
		plh0359		//2018
	*/
	
********************************************************************************
** Generate new variables from VSKT & SOEP **
********************************************************************************

/*For some variables, we combine info from VSKT & SOEP data. 
As default, we always use the admin data from VSKT, but add SOEP data when VSKT 
data is not available. 
Example: marriage & divorce 
	1) check whether there is marriage & divorce info in the VSKT 
		(true for spouses who divorced and shared their pension entitlements)
	2) if yes: take this information 
	   if no:  check whether there is marriage & divorce info in the SOEP 
	3) if yes: take this information 
	   if no:  assume there is no marriage/divorce 
	   
	potential mistakes: misreporting in the SOEP 
	*/

	****************************************************************************
	/* Marriage / Divorce */	
	****************************************************************************
	
	/*Overview relevant variables for marriage n 
		VSKT (raw)
		- EB`n'_JAHR	= begin marriage -- calendar year (e.g., 1999)
		- EB`n'_MONAT	= begin marriage -- calendar month (e.g., 2 for February)
		- ES`n'_JAHR	= divorce date -- calendar year (e.g., 1999)
		- ES`n'_MONAT	= divorce date -- calendar month (e.g., 2 for February)
		- DRK`n'_JAHR 	= court ruling -- calendar year (e.g., 1999)
		- DRK`n'_MONAT	= court ruling -- calendar month (e.g., 2 for February)
		
		VSKT (generated from raw above)
		- marr`n'beginy_vskt	= begin marriage -- calendar year (e.g., 1999)
		- marr`n'beginm_vskt	= begin marriage -- calendar month (e.g., 2 )
		- marr`n'beginm_vskt	= begin marriage -- monthly date (e.g., 2000m2 = 481)
		- marr`n'endmy_vskt		= end marriage -- calendar year (e.g., 1999)
		- marr`n'beginm_vskt	= end marriage -- calendar month (e.g., 2 )
		- marr`n'endmy_vskt		= end marriage -- monthly date (e.g., 2000m2 = 481)
		--> end marriage defined as separation = divorce date - 12 months 
		
		SOEP (generated from marsm/marsy)
		- marr`n'beginy_soep	= begin marriage -- calendar year (e.g., 1999)
		- marr`n'beginm_soep	= begin marriage -- calendar month (e.g., 2 )
		- marr`n'beginm_soep	= begin marriage -- monthly date (e.g., 2000m2 = 481)
		- marr`n'endmy_soep		= end marriage -- calendar year (e.g., 1999)
		- marr`n'beginm_soep	= end marriage -- calendar month (e.g., 2 )
		- marr`n'endmy_soep		= end marriage -- monthly date (e.g., 2000m2 = 481)
		*/
	
	

	forvalues n = 1/2 /*1st & 2nd marriage -- SOEP & VSKT*/ {
		**************************
		** Begin / End Marriage **
		**************************
		foreach period in m /*month*/ y /*year*/ my /*month-year*/ {
			
			foreach event in begin end {
				gen marr`n'`event'`period' = .
				/*VSKT*/ replace marr`n'`event'`period' = marr`n'`event'`period'_vskt if !missing(marr`n'`event'`period'_vskt) /*missing = .*/
				/*SOEP*/ replace marr`n'`event'`period' = marr`n'`event'`period'_soep if missing(marr`n'`event'`period'_vskt) /*missing = .*/ ///
																			  & !missing( marr`n'`event'`period'_soep) /*missing = . */	
			}
			
			/*SOEP*/ replace marr`n'end`period' =. if missing(marr`n'end`period'_vskt) /*missing = .*/ ///
														& !missing( marr`n'end`period'_soep) /*missing = . */	///
														& marr`n'end_type_soep!=9 /*No Luecke or RC für marriage end information in SOEP*/
		}

		format %tmMonth_CCYY marr`n'beginmy
		format %tmMonth_CCYY marr`n'endmy
		
		*******************************
		** Data Source Marriage Info **
		*******************************
		gen marr`n'source_vskt = . /*dummy for whether info is from admin VSKT data (1), or not = SOEP (0)*/
			replace marr`n'source_vskt = 1 if !missing(marr`n'beginy_vskt) /*missing = .*/
			replace marr`n'source_vskt = 0 if missing(marr`n'beginy_vskt) /*missing = .*/ & !missing(marr`n'endy_soep) /*missing = .*/ 
	}
			

	forvalues n = 1/2 /*1st, 2nd marriage*/ {
		foreach event in begin end {
			
			****************
			** Event time **
			****************
			**Months** 
			gen marr`n'`event'my_event_time = monthly /*monthly date of obs.*/ - marr`n'`event'my /*monthly date marriage*/
			**Years**
			gen marr`n'`event'y_event_time = JAHR /*annual date of obs.*/ - marr`n'`event'y /*annual date marriage*/
			
			*********************
			** Decade of Event **
			*********************
			gen marr`n'`event'decade = floor(marr`n'`event'y/10)*10			
		}
	}	
	
		************************
		** Dummy ever married **
		************************
		tempvar beginy1 
		tempvar endy1 
		sort pid monthly 
		by pid: egen `beginy1' = max(marr1beginy) /*filled with year if married, missing else*/
		by pid: egen `endy1'   = max(marr1endy)   /*filled with year if married, missing else*/
		gen married_ever = 0
			replace married_ever = 1 if !missing(`beginy1') | !missing(`endy1')
			label var married_ever "Dummy ever married"
			label val married_ever dummy_married
			
		*****************************
		** Dummy divorced marriage **
		***************************** 
		forvalues n = 1/2 {
			gen marr`n'_divorced = 0 if !missing(marr`n'beginy)
				replace marr`n'_divorced = 1 if (!missing(marr`n'endy) & marr1source_vskt==1)
				replace marr`n'_divorced = 1 if (!missing(marr`n'endy) & marr1source_vskt==0 & inlist(marr1end_type_soep, 3, 5))				
				label var marr`n'_divorced "Dummy marriage divorced"
				label val marr`n'_divorced dummy_divorce	
				
		}
		
			
		*********************
		** Length Marriage **
		*********************
		forvalues n = 1/2 {
			**Months** 
			gen marr`n'_lengthm = marr`n'endmy - marr`n'beginmy if marr`n'_divorced == 1 
			*Replace if end because of data end
			
			**Years**
			gen marr`n'_lengthy = marr`n'endy - marr`n'beginy if marr`n'_divorced == 0
			*Replace if end because of data end
		}
		
		*********************************
		** Divorced marriage w. lenght **
		*********************************
		forvalues n = 1/2 {
			gen marr`n'_divorced_g = 0 if !missing(marr`n'beginy)
				replace marr`n'_divorced_g = 1 if (!missing(marr`n'endy) & marr1source_vskt==1)
				replace marr`n'_divorced_g = 1 if (!missing(marr`n'endy) & marr1source_vskt==0 & inlist(marr1end_type_soep, 3, 5))
				replace marr`n'_divorced_g = 2 if marr`n'_divorced==1 & marr`n'_lengthy>=10
				label var marr`n'_divorced_g "Marriage divorced + lenght"
				label val marr`n'_divorced_g dummy_divorce_g	
		}
		
		
		
		************************
		** Dummy 2nd marriage ** 
		************************
		gen d_marriage2=(!missing(marr2beginy) | !missing(marr2endy))
		label var d_marriage2 "Dummy for 2nd Marriage"
		label values d_marriage2 dummy_m2
		
		
		**************************
		** Marriage 1 SOEP-VSKT ** 
		**************************
		gen marr_vskt_soep = .
		replace marr_vskt_soep = 0 if ///
			!inrange(marr1beginy_soep, marr1beginy_vskt-1, marr1beginy_vskt+1) & ///
			!inrange(marr1endy_soep, marr1endy_vskt-1, marr1endy_vskt+1) & ///
			!missing(marr1beginy_vskt) & !missing(marr2beginy_soep)
		replace marr_vskt_soep = 1 if marr_vskt_soep == 0 & ///
			marr1beginy_soep<marr1beginy_vskt & ///
			inrange(marr2beginy_soep, marr1beginy_vskt-1, marr1beginy_vskt+1)
		
		
		************************************
		** Age at marriage / end marriage ** 
		************************************
		forvalues n = 1/2 {
			foreach event in begin end {
				/*Age in years*/
				tempvar store_age 
					gen `store_age' = age if marr`n'`event'my_event_time==0 /*store age*/
				bysort pid (monthly): egen age_marr`n'`event' = max(`store_age') /*same value for all months*/
			}
		}
		
		/*Age groups -- seperately for marriage 1 bc different age distributions*/
		gen age_marr1begin_grouped = . 
			replace age_marr1begin_grouped = 1 if age_marr1begin < 18
			replace age_marr1begin_grouped = 2 if inrange(age_marr1begin, 18, 21)
			replace age_marr1begin_grouped = 3 if inrange(age_marr1begin, 22, 25)
			replace age_marr1begin_grouped = 4 if inrange(age_marr1begin, 26, 29)
			replace age_marr1begin_grouped = 5 if inrange(age_marr1begin, 30, 33)
			replace age_marr1begin_grouped = 6 if age_marr1begin >33
			label var age_marr1begin_grouped  "Age at marriage 1 -- grouped"
			label values age_marr1begin_grouped age_marriage
		/*Age groups -- seperately for marriage end 1 */
		gen age_marr1end_grouped = . 
			replace age_marr1end_grouped = 1 if age_marr1end < 25
			replace age_marr1end_grouped = 2 if inrange(age_marr1end, 25, 30)
			replace age_marr1end_grouped = 3 if inrange(age_marr1end, 31, 35)
			replace age_marr1end_grouped = 4 if inrange(age_marr1end, 36, 40)
			replace age_marr1end_grouped = 5 if inrange(age_marr1end, 41, 45)
			replace age_marr1end_grouped = 6 if age_marr1end >45
			label var age_marr1end_grouped  "Age at end of marriage 1 -- grouped"
			label values age_marr1end_grouped age_divorce
		/*Age groups -- seperately for divorce 1 */
		gen age_divorce1_grouped = . 
			replace age_divorce1_grouped = 1 if age_marr1end < 25 & marr1_divorced == 1
			replace age_divorce1_grouped = 2 if inrange(age_marr1end, 25, 30) & marr1_divorced == 1
			replace age_divorce1_grouped = 3 if inrange(age_marr1end, 31, 35) & marr1_divorced == 1
			replace age_divorce1_grouped = 4 if inrange(age_marr1end, 36, 40) & marr1_divorced == 1
			replace age_divorce1_grouped = 5 if inrange(age_marr1end, 41, 45) & marr1_divorced == 1
			replace age_divorce1_grouped = 6 if age_marr1end >45 & marr1_divorced == 1
			label var age_divorce1_grouped  "Age at divorce 1 -- grouped"
			label values age_divorce1_grouped age_divorce
		
		/*Age groups2*/
		gen age_marr1begin_grouped2 = . /*neglect younger than 18*/
			replace age_marr1begin_grouped2 = 1 if inrange(age_marr1begin, 18, 24)
			replace age_marr1begin_grouped2 = 2 if inrange(age_marr1begin, 25, 29)
			replace age_marr1begin_grouped2 = 3 if inrange(age_marr1begin, 30, 35)
			replace age_marr1begin_grouped2 = 4 if age_marr1begin >35
			label var age_marr1begin_grouped2  "Age at marriage 1 -- grouped 2"
		
		/*Age groups3 */
		gen age_marr1begin_grouped3 = . 
			replace age_marr1begin_grouped3 = 1 if inrange(age_marr1begin, 18, 29)
			replace age_marr1begin_grouped3 = 2 if inrange(age_marr1begin, 30, 39)
			replace age_marr1begin_grouped3 = 3 if age_marr1begin >39
			label var age_marr1begin_grouped3  "Age at marriage 1 -- grouped 3"
			
			
		************************************
		** Marriage x Time Dumy ** 
		************************************
		forval n=1/2 {
			gen marr`n'dummy=inrange(monthly, marr`n'beginmy, marr`n'endmy) 
			replace  marr`n'dummy=. if missing(marr`n'beginmy)
		}
	
		**********************************************
		/* Prenuptial agreement / marriage contract */
		**********************************************
		/*Variable on prenuptial agreement: pld0299 from pl.dta 
			[ 1] = yes 
			[ 2] = no 
			[-1] = no answer
			[-2] = does not apply 
			[-3] = not asked in that year (only asked 2019 & 2020)
		--> this is SOEP data, but we want combined marriage info before we use it */

		** dummy for prenup in marriage 1 ** 
		tempvar help_prenup
		gen `help_prenup' = .
		replace `help_prenup' = 0 if pld0299==2 & inrange(syear, marr1beginy, marr1endy)
		replace `help_prenup' = 1 if pld0299==1 & inrange(syear, marr1beginy, marr1endy)
		bys rv_id: egen prenup_marr1 = max(`help_prenup') if inrange(syear, marr1beginy, marr1endy) & !missing(`help_prenup') & !missing(marr1beginy) /*if asked twice, we assume they have a prenup if stated once*/
		bys rv_id: ereplace prenup_marr1 = max(prenup_marr1) /*same value for all rows*/
		label var prenup_marr1 "prenuptial agreement marriage 1"
		label values prenup_marr1 yesno 
		
	****************************************************************************
	/* Relationships */
	****************************************************************************
	/* generate relationship info from all possible variables */	
	* general variables *
	gen fam_stat=.
	/*SOEP Relationship information*/
	forval n=1/16 {
		replace fam_stat=rel`n'_type_soep if inrange(monthly, rel`n'beginmy_soep, rel`n'endmy_soep) & !missing(rel`n'beginmy_soep)
	}
	/* marital info always dominates (if random or not) */
	replace fam_stat=4 /*married*/ if inrange(monthly, marr1beginmy, marr1endmy) & !missing(marr1beginmy)
	replace fam_stat=4 /*married*/ if inrange(monthly, marr2beginmy, marr2endmy) & !missing(marr2beginmy)
	
	/* do we want to add current information?
	replace fam_stat=2 if partner==0 /*no partner in hh*/ &  pld0133==2 /*partner does not live in hh*/
	replace fam_stat=3 if inlist(partner,2 ,4) /*partner*/ & pld0133!=2 /*does not live in other hh*/
	replace fam_stat=1 if partner==0 /*no partner in hh*/ & pld0133==-2 /*does not apply*/ */
	
	label val fam_stat famstatus
	
	****************************
	/* Cohabitation eventtime */
	****************************	
	/* We want to know when cohabitation starts pre marriage.
		Steps for this: 
		- find last month single/ partner in different household pre marriage 
		- take t+1 as month for moving in 
		--> this includes people who cohabit pre marriage 
			+ those who move in in month of marriage 
		--> this excludes those who only move in after marriage 
		--> this is assuming that the cohabiting partner pre-marriage is also 
			the spouse. For this to be someone else, the individual would have 
			to switch from cohabiting with partner A to being married with 
			partner B in 1 month. 
			--> seems unlikely, but we can also check that later 
		--> var is missing for everyone for whom we don't have cohabitation info 
			from SOEP 
		--> var is also missing if fam_stat is unknown after the last month 
			living single*/
			
	/*find last month living w/o partner pre-marriage*/	
	tempvar last 
	bys rv_id (monthly): egen `last'=max(monthly) if inlist(fam_stat, 1 /*single*/, 2 /*partner diff hh*/) & marr1beginmy_event_time<0
	bys rv_id: ereplace `last' = max(`last')
	
	/*find first month living with partner if that is the first filled variable*/
	tempvar first
	bys rv_id (monthly): egen `first'=min(monthly) if fam_stat==3 & missing(`last') & marr1beginmy_event_time<0
	bys rv_id: ereplace `first' = max(`first')
	
	/*gen begin time*/
	gen cohabbeginmy = (`last'+1) /*+1 b/c we want the 1st cohabiting, not last single*/
		replace cohabbeginmy = (`first') if missing(cohabbeginmy)
		format %tm cohabbeginmy
	gen cohabbeginy = yofd(dofm(cohabbeginmy))
	
	/*gen event time*/
	gen cohabbeginmy_event_time = monthly - (cohabbeginmy) 
	
	/*reset to missing if fam stat t+1 is missing*/	
	tempvar help 
	gen `help' = fam_stat if cohabbeginmy_event_time==0 /*fam stat in t=0 (what we think is begin cohabitation)*/
		bys rv_id: ereplace `help' = max(`help') /*same value in all rows*/
	replace cohabbeginmy=. if missing(`help')
	replace cohabbeginy =. if missing(`help')
	replace cohabbeginmy_event_time=. if missing(`help')
	
	label var cohabbeginmy_event_time "time relative to moving in (pre/at marriage)"
	
	/*distance between cohabitation and marriage*/
	gen dist_marr1_cohab_my = marr1beginmy - cohabbeginmy
	gen dist_marr1_cohab_y = marr1beginy - cohabbeginy
	
	/*as long as we still have random months for marr beginmy, we can have 
		fam_stat = single for cohabbeginmy_event_time==0 
		--> this is cases where i is living single pre marriage 
			= same eventtime for marriage & cohabitation
		--> in most cases, fam_stat = married for t=0 
		--> but if we randomized beginmy, it's possible to still see 
			fam_stat = single for t=0 */

	****************************************************************************
	/* Children */	
	****************************************************************************
		
		*************************
		** Information in Both **
		*************************
		/*if VSKT and SOEP child information is both filled (thus nchildren_vskt!=0) but doesn't align -> trust VSKT
		 But: Label cases where SOEP has more information. )*/
		gen children_more_soep=(nchildren_soep > nchildren_vskt) & nchildren_vskt!=0 /*nchildren is never mising only 0*/

		forvalues n = 1/10 /*child 1-10 -- SOEP & VSKT*/ {
		**********************
		** Birth of child N **
		**********************
		
		foreach period in m /*month*/ y /*year*/ my /*month-year*/ {
			
			gen child`n'birth`period' = .
			
			/*cases where N children SOEP <= N children VSKT 
				--> stick to VSKT info for all children (= disregard SOEP)*/
			/*VSKT*/replace child`n'birth`period'  = child`n'birth`period'_vskt ///
					if !missing(child`n'birth`period'_vskt) /*child info in VSKT*/ ///
					  & children_more_soep==0 /*nr. information less in soep or not filled in soep and thus =0*/
					
			/* missing VSKT = no children at all in VSKT, but children in SOEP
				--> trust SOEP */
			/*SOEP*/ replace child`n'birth`period' = child`n'birth`period'_soep ///
					if nchildren_vskt==0 /*no children in VSKT*/ & ///
					  nchildren_soep!=0 /*children in SOEP*/ 	
			
			/* children in SOEP & VSKT, more children in SOEP*/
				
			/*Fathers: always trust SOEP (b/c VSKT basically no child infos for men)*/
					replace child`n'birth`period'  = child`n'birth`period'_soep ///
					if children_more_soep==1 & female==0 /*condition: more children in SOEP --> take all `n' child info from SOEP*/
					
			/*Mothers: depending on where the oldest child is listed*/
			/*Mothers I*/replace child`n'birth`period'  = child`n'birth`period'_soep ///
					if children_more_soep==1 & female==1 & ///
					   child1birthy_soep<child1birthy_vskt /*use SOEP if 1st child in SOEP older than in VSKT*/
			/*Mothers II*/replace child`n'birth`period'  = child`n'birth`period'_vskt ///
					if children_more_soep==1 & female==1 & ///
					   child1birthy_soep>=child1birthy_vskt /*use VSKT if 1st child in VSKT same or older than 1st child in SOEP --> even if we see more children in SOEP, we disregard the additional child(ren) b/c SOEP misses 1st child*/
					 
		}
		format %tmMonth_CCYY child`n'birthmy 
		
		*********************
		** Decade of Birth **
		*********************
		gen child`n'birthdecade = floor(child`n'birthy/10)*10
		}
			
		*******************************
		** Data Source Child Info **
		*******************************
		/*dummy for whether info is from admin VSKT data (1), or not = SOEP (0)
			--> same if conditions as above */
		gen child_birth_source_vskt = . 
			replace child_birth_source_vskt = 1 if nchildren_vskt>0 /*default: VSKT, we overwrite in the next lines the SOEP cases*/
			replace child_birth_source_vskt = 0 if nchildren_vskt==0 & nchildren_soep!=0
			replace child_birth_source_vskt = 0 if children_more_soep==1 & female==0 
			replace child_birth_source_vskt = 0 if children_more_soep==1 & female==1 & child1birthy_soep<child1birthy_vskt
			
		********************
		** Youngest Child **
		********************
		egen birthmy_youngest_child = rowmax(child1birthmy child2birthmy child3birthmy child4birthmy child5birthmy child6birthmy child7birthmy child8birthmy child9birthmy child10birthmy)	
		format birthmy_youngest_child %tm
		
		********************
		** Oldest Child **
		********************
		egen birthmy_oldest_child = rowmin(child1birthmy child2birthmy child3birthmy child4birthmy child5birthmy child6birthmy child7birthmy child8birthmy child9birthmy child10birthmy)	
		format birthmy_oldest_child %tm
		
		forvalues n = 1/10 /*child 1-10 -- SOEP & VSKT*/ {
		****************
		** Event time **
		****************
		**Months** 
		gen child`n'birthmy_event_time = monthly /*monthly date of obs.*/ - child`n'birthmy /*monthly date birth 1st child*/
		**Years**
		gen child`n'birthy_event_time = JAHR /*annual date of obs.*/ - child`n'birthy /*monthly date birth 1st child*/
	}	
	
		***********************
		** Age at childbirth **
		***********************
		forvalues n = 1/10 {
			gen age_at_child`n'	= child`n'birthy - GBJAVS if !missing(child`n'birthy)
			label var age_at_child`n' "Age at Childbirth `n'"
		}
	
		************************
		** Distance 1st & 2nd **
		************************
		gen dist_child1_child2=child2birthy-child1birthy if !missing(child2birthy) 
			label var dist_child1_child2 "Distance between 1st and 2nd Child (Years)"

		*************************
		** Dummy ever children **
		*************************
		gen child_ever = 0
			replace child_ever = 1 if !missing(child1birthy)
			label var child_ever "Dummy ever children"
			label val child_ever dummy_kids
		

		************************
		** Number of children **
		************************
		/*total number of children (as of last observation)*/
		gen n_children = 0
		forval n=1/10 {
			replace n_children = n_children + 1 if !missing(child`n'birthy)
		}
		label var n_children "total number of children ever"
		
		**************************
		** Time variant - Child **
		**************************
		* age youngest child *
		*in months*
		gen agemy_youngest_child = monthly - birthmy_youngest_child if monthly >= birthmy_youngest_child
			format agemy_youngest_child %tm
		
		
		* dummy for children (minor children only) *
		gen child_minor = 0
			replace child_minor = 1 if agemy_youngest_child < 18 /*agemy_youngest_child always >= 0*/
		
		
	****************************************************************************
	/* Familystatus at childbirth */	
	****************************************************************************
	//Work in Progress -> single & co-habiting
	forvalues n = 1/10 {
	* Dummy married or not *
		gen marr_childbirth`n'=.
		/*child born pre/post marriage or never married
			--> to be precise, this is child born. But we replace children born within marriage in the next steps*/
		replace marr_childbirth`n'=0 if child`n'birthmy!=. 
		
		/*child born in 1st marriage*/
		replace marr_childbirth`n'=1 if inrange(child`n'birthmy, marr1beginmy, marr1endmy) ///
										& child`n'birthmy!=. & marr1beginmy!=.
		
		/*child born in 2nd marriage*/
		replace marr_childbirth`n'=1 if inrange(child`n'birthmy, marr2beginmy, marr2endmy) ///
										& child`n'birthmy!=. & marr2beginmy!=.
		
		label var marr_childbirth`n' "Marital status at Childbirth `n'"
		label val marr_childbirth`n' married_birth
		
	* single or not *
	gen single_childbirth`n'=.
		/*child born & no single information*/
		replace single_childbirth`n'=0 if child`n'birthmy!=. 
		
		/*child born when single*/
		replace single_childbirth`n'=1 if child`n'birthmy_event_time==0 & fam_stat==1 ///
										& marr_childbirth`n'!=1 /*no marriage classification*/
		
		/*fill for every row*/
		bys pid (monthly): ereplace single_childbirth`n'=max(single_childbirth`n')
		
		label var single_childbirth`n' "Single at Childbirth `n'"
	
	* relationship or not * 
	gen partner_childbirth`n'=.
		/*child born & no partner information*/
		replace partner_childbirth`n'=0 if child`n'birthmy!=. 
		
		/*Partner when child born*/
		replace partner_childbirth`n'=1 if child`n'birthmy_event_time==0 & inlist(fam_stat,3) ///
										& marr_childbirth`n'!=1 /*no marriage classification*/
		
		/*fill for every row*/
		bys pid (monthly): ereplace partner_childbirth`n'=max(partner_childbirth`n')
		
		label var partner_childbirth`n' "Partner at Childbirth `n'"
	}  
	
	forvalues n = 1/1 /*do this for 1st child for now but can do more children later*/ {
		gen fam_stat_childbirth`n' = .
			/*store min/max value for fam_stat in year of birth
				1 = single, 2 = partner diff household, 3 = partner in household, 4 = married */
			foreach x in min max {
				tempvar `x'
				bys pid: egen ``x'' = `x'(fam_stat) if child1birthy_event_time==0 /*filled in year of birth*/
			}
			/*1 = single (= single 1 month, co-habiting else)*/
			replace fam_stat_childbirth`n' = 1 if inlist(`min', 1, 2) & `max'<4
			/*2 = co-habiting*/
			replace fam_stat_childbirth`n' = 2 if `min'==3 & `max'==3
			/*3 = married (married at least one month)*/
			replace fam_stat_childbirth`n' = 3 if `max'==4
			label var fam_stat_childbirth`n' "Family status at birth (child `n')"
			label values fam_stat_childbirth`n' famstat3
	}
		
	

	*************************************
	/* Distance marriage & child birth */
	*************************************
	*Only for specific marriage* 
	forvalues n = 1/1 /*rn we only do this for the 1st child, can add more children here if needed*/ {
		forvalues m= 1/2 /*marriage 1 & 2*/ {
			/*months*/
			gen dist_marr`m'_childbirth`n'_my= marr`m'beginmy-child`n'birthmy 
			label var dist_marr`m'_childbirth`n'_my "Distance to Marriage `m' at Childbirth `n' (in Months)"
			/*calendar years*/
			/*we do calendar years here b/c with dates from SOEP, month may be missing*/
			gen dist_marr`m'_childbirth`n'_y = marr`m'beginy-child`n'birthy 
			label var dist_marr`m'_childbirth`n'_y "Distance to Marriage `m' at Childbirth `n' (in calendar years)"
		}
	}
	
	****************************************************
	/* Dummy: 1st child born pre/within/post marriage */
	****************************************************
	
	forvalues i = 1/2 /*marriage 1 & 2*/ {
		/* pre marriage: 
			--> 1st child born before marriage */
		gen dummy_child1_pre_marriage_`i' = 0
			replace dummy_child1_pre_marriage_`i'= 1 if child1birthmy < marr`i'beginmy & !missing(child1birthmy, marr`i'beginmy)
		label var dummy_child1_pre_marriage_`i' "1st Child born before Marriage `i'"
		label val dummy_child1_pre_marriage_`i' yesno
		
		/* within marriage: 
			--> 1st child born within marriage (>= month marriage start & <= month marriage end) */
		gen dummy_child1_within_marriage_`i' = 0
			replace dummy_child1_within_marriage_`i' = 1 if inrange(child1birthmy, marr`i'beginmy, marr`i'endmy) & !missing(child1birthmy, marr`i'beginmy) 
			/*if marr`i'endmy = . --> marriage not divorced, birth always inrange 
			(but almost all cases have an endmy, either from VKST b/c all are divorced or from SOEP) */ 
		label var dummy_child1_within_marriage_`i' "1st Child born within Marriage `i'"
		label val dummy_child1_within_marriage_`i' yesno
		
		/*post marriage
			--> 1st child born post marriage = after divorce*/
		gen dummy_child1_post_marriage_`i' = 0
			replace dummy_child1_post_marriage_`i'= 1 if child1birthmy > marr`i'endmy & !missing(child1birthmy , marr`i'endmy)
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
				replace n_child_pre_marriage_`i' = n_child_pre_marriage_`i'+1 if child`x'birthmy < marr`i'beginmy & !missing(child`x'birthmy, marr`i'beginmy)
			}
		label var n_child_pre_marriage_`i' "Amount of Children pre Marriage `i'"
		
		/*within marriage -> amount*/
		gen n_child_within_marriage_`i' = 0
			forvalues x = 1/10 {
				replace n_child_within_marriage_`i' = n_child_within_marriage_`i'+1 if inrange(child`x'birthmy, marr`i'beginmy, marr`i'endmy) & !missing(child`x'birthmy, marr`i'beginmy)
			}
		label var n_child_within_marriage_`i' "Amount of Children within Marriage `i'"
		
		/*post marriage -> amount*/
		gen n_child_post_marriage_`i' = 0
			forvalues x = 1/10 {
				replace n_child_post_marriage_`i' = n_child_post_marriage_`i'+1 if child`x'birthmy > marr`i'endmy & !missing(child`x'birthmy, marr`i'endmy)
			}
		label var n_child_post_marriage_`i' "Amount of Children post Marriage `i'"
	}	
		
	
	***********************************************
	/* General timing info: 1st child & marriage */
	***********************************************
	forvalues i = 1/2 /*marriage 1 & 2*/ {		
		/* Information child before/within, after marriage, no child*/
		gen child1_timing_marr_`i' = .
			/*never children*/
			replace child1_timing_marr_`i' = 0 if child_ever==0
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
	
	**********************
	/*Randomization info*/
	**********************
	gen random_m_marr1xchild1=.
		replace random_m_marr1xchild1=1 if (marr1beginmy_random_soep==1 & marr1source_vskt==0) ///
										 | (child1birthmy_random==1 & child_birth_source_vskt==0)
		replace random_m_marr1xchild1=0 if (marr1beginmy_random_soep==0 | marr1source_vskt==1 | missing(marr1beginmy)) ///
										 & (child1birthmy_random==0 | child_birth_source_vskt==1 | missing(child1birthm))
	
	****************************************************************************
	/* Income related variables */	
	****************************************************************************
	
	*************************************
	/* Translate MEGPT into EUR amount */
	*************************************
	/*run do file on average income each year (value of EP=1)*/
	global year = "syear"
	global month = "MONAT"
	do "${do}/mp_vskt_02b_operands_social_security.do"
	
	
	** store 2015 values in global **
	/*average income --> used to compute income from EP */
	qui sum average_annual_income if syear==2015 /*1 EP in 2015*/
		global ep2015 = r(mean)
	
		
	**************************
	/* Monthly gross income */	
	**************************
	
	** admin data **
	/*in € (= gross income in that year)*/
	gen gross_income_month = MEGPT_work * average_annual_income
		label variable gross_income_month "Monthly income [€]"
		
	/*in 2015 €*/
	gen gross_income_month_2015EUR = MEGPT_work*$ep2015
		label variable gross_income_month_2015EUR "Monthly income [2015 €]"
	
	
	***********************
	* Annual gross income *	
	***********************
	bysort rv_id syear (monthly): egen gross_income_year = total(gross_income_month)	
	bysort rv_id syear (monthly): egen gross_income_year_2015EUR = total(gross_income_month_2015EUR)	
	
	** survey data in 2015 € **
	/*we want to adjust for CPI here 
		--> for admin data, we could just use the EP and translate 
			into 2015 EUR 
		--> from survey, we have gross income info 
		--> we take CPI values an normalize to 2015 EUR */
	gen cpi = . 
		replace cpi = 0.655 if syear == 1991
		replace cpi = 0.688 if syear == 1992
		replace cpi = 0.719 if syear == 1993
		replace cpi = 0.738 if syear == 1994
		replace cpi = 0.751 if syear == 1995
		replace cpi = 0.761 if syear == 1996
		replace cpi = 0.776 if syear == 1997
		replace cpi = 0.783 if syear == 1998
		replace cpi = 0.788 if syear == 1999
		replace cpi = 0.799 if syear == 2000
		replace cpi = 0.815 if syear == 2001
		replace cpi = 0.826 if syear == 2002
		replace cpi = 0.835 if syear == 2003
		replace cpi = 0.849 if syear == 2004
		replace cpi = 0.862 if syear == 2005
		replace cpi = 0.876 if syear == 2006
		replace cpi = 0.896 if syear == 2007
		replace cpi = 0.919 if syear == 2008
		replace cpi = 0.922 if syear == 2009
		replace cpi = 0.932 if syear == 2010
		replace cpi = 0.952 if syear == 2011
		replace cpi = 0.971 if syear == 2012
		replace cpi = 0.985 if syear == 2013
		replace cpi = 0.995 if syear == 2014
		replace cpi = 	  1 if syear == 2015
		replace cpi = 1.005 if syear == 2016
		replace cpi = 1.02  if syear == 2017
		replace cpi = 1.038 if syear == 2018
		replace cpi = 1.053 if syear == 2019
		replace cpi = 1.058 if syear == 2020

	gen gross_income_year_2015EUR_soep = (pglabgro*12)/cpi
		label variable gross_income_year_2015EUR_soep "Annual income SOEP [2015 €]"

	*****************
	/* Hourly Wage */
	*****************
	** Weekly hours worked variable - > less well filled **
	
	** Daily hours worked variable **
	/*5*50= workdays per week * weeks per year = year*/
	foreach var in "" _2015EUR {
		/*monthly*/
		gen gross_hourly`var'=gross_income_month`var'/(labour_wd_hours*5*50/12)
		/*yearly*/
		gen gross_hourly_y`var'=gross_income_year`var'/(labour_wd_hours*5*50)
	}
	
	** survey income data **
	gen gross_hourly_2015EURsoep = gross_income_year_2015EUR_soep/(labour_wd_hours*5*50)

	*****************************************
	* Income threshold for Mini- & Midi-Job *
	*****************************************
	
	gen threshold_mini_job = .
		replace threshold_mini_job = 400 if inrange(monthly, ym(2003,4), ym(2012,12))
		replace threshold_mini_job = 450 if syear > 2012
		
	gen threshold_midi_job = .
		replace threshold_midi_job = 800 if inrange(monthly, ym(2003,4), ym(2012,12))
		replace threshold_midi_job = 850 if syear > 2012
	
	
	*************************
	/* Pre-marriage income */
	*************************
	
	/*income from VSKT but with marriage info from VSKT + SOEP
		--> this is why we do this here*/
	
	*** Earnings points ***
	bys pid: egen MEGPT_work_pre_marriage_1 = mean(MEGPT_work) if inrange(marr1beginmy_event_time, -12, -1) /*mean EP in the 12 months preceeding marriage*/
		bys pid: ereplace MEGPT_work_pre_marriage_1 = max(MEGPT_work_pre_marriage_1) /*have that var filled for every row*/
		label var MEGPT_work_pre_marriage_1 "mean EP 12 months pre marriage"
	
	*** Earnings points grouped ***
	gen MEGPT_work_pre_marriage_1_group = .
		replace MEGPT_work_pre_marriage_1_group = 0 if MEGPT_work_pre_marriage_1==0 
		forvalues ep = 25(25)200 /*categorize by annual income = 25% - 200% of average annual income*/ {
		    /*for if condition, we take MEGPT_work_pre_marriage_1 x 12 x 100 to get annual income in %
				--> that's just b/c 25% - 200% is more intuitive than monthly values (multiples of 1/12)*/
			replace MEGPT_work_pre_marriage_1_group = `ep' if MEGPT_work_pre_marriage_1*12*100>`ep'-25 & MEGPT_work_pre_marriage_1*12*100<=`ep'
		}
		label var MEGPT_work_pre_marriage_1_group "mean relative EP 12 months pre marriage (grouped)"
		label values MEGPT_work_pre_marriage_1_group megpt_percent
		
	***************************
	/* Pre-childbirth income */
	***************************
	/*income from VSKT but with childbirth info from VSKT + SOEP*/
	
	*** Earnings points ***
	bys pid: egen MEGPT_work_pre_child1 = mean(MEGPT_work) if inrange(child1birthmy_event_time, -12, -1) 
		bys pid: ereplace MEGPT_work_pre_child1 = max(MEGPT_work_pre_child1) 
		label var MEGPT_work_pre_child1 "mean EP 12 months pre childbirth 1"
	
	*** Earnings points grouped ***
	gen MEGPT_work_pre_child1_group = .
		replace MEGPT_work_pre_child1_group = 0 if MEGPT_work_pre_child1==0 
		forvalues ep = 25(25)200 {
			replace MEGPT_work_pre_child1_group = `ep' if MEGPT_work_pre_child1*12*100>`ep'-25 & MEGPT_work_pre_child1*12*100<=`ep'
		}
		label var MEGPT_work_pre_child1_group "mean relative EP 12 months pre childbirth1 (grouped)"
		label values MEGPT_work_pre_child1_group megpt_percent
	
	****************************************************************************
	/* Other Variables */	
	****************************************************************************
	
	**********************
	/* East/West origin */
	**********************
	gen east_born=.
		/*SOEP info*/
		replace east_born=1 if loc1989==1
		replace east_born=0 if loc1989==2
		/*VSKT if missing*/
		replace east_born=1 if loc1989==-1 & east_first==1
		replace east_born=0 if loc1989==-1 & east_first==0
	
	*********************************
	** East/West at marriage month **
	*********************************
	/*we use imputed values for east/west here = if info missig for given month: 
		--> take closest month 
		--> if same distance pre/post we take post 
		(see definition for east_monthly_imputed) */
	gen east_marriage = east_monthly_imputed if marr1beginmy_event_time==0 
		bys rv_id: ereplace east_marriage = max(east_marriage) /*same values for all rows*/
		label var east_marriage "east/west month of marriage"
		label values east_marriage east
	
	** group var: east/west 1st month vs marriage **	
	gen east_marriage_group = .
		/*1 = 1st obs east, married east */
		replace east_marriage_group = 1 if east_born==1 & east_marriage==1
		/*2 = 1st obs east, married west */
		replace east_marriage_group = 2 if east_born==1 & east_marriage==0
		/*3 = 1st obs west, married west */
		replace east_marriage_group = 3 if east_born==0 & east_marriage==0
		/*4 = 1st obs west, married east */
		replace east_marriage_group = 4 if east_born==0 & east_marriage==1
		label var east_marriage_group "east/west pattern marriage"
		label values east_marriage_group eastwestmarr
		
	
	
********************************************************************************
** Clean data **
********************************************************************************

	***********************
	** Drop empty months **
	***********************
	
	/* We want to drop all rows/months that are empty before (after) the first 
	(last) oberservation for i in the data.
	From the VSKT data, we have all months since the year i turned 14. In many 
	cases, the first observation is much later, e.g. when i starts their first 
	job. 
	From the SOEP data, we may have info on i for years before we see info for 
	them in the VSKT. 
	We will thus drop months if they are before first observation in VSKT and 
	before first observation in SOEP. 
	*/
	
		**********
		** VSKT **
		**********
		/*We use the variables STATUS_x_TAGE that indicates number of days i 
		spend in status x at given t. The variable have values from 1-31 if i 
		was 1-31 days in the given status and is missing else. 
		1) sum the days for all status x of i at given t 
		2) store info whether t is >= first t with any status and <= last t with 
			any status (= time range covered by VSKT)
		3) gen marker that is 1 when within covered time range & 0 else */
		
		/*--> 1)*/
		tempvar help1 
		egen `help1' = rowtotal(STATUS_1_TAGE STATUS_2_TAGE STATUS_3_TAGE STATUS_4_TAGE STATUS_5_TAGE)
		replace `help1' = . if `help1' == 0
		/*--> 2)*/
		tempvar help2
		bys rv_id: mipolate `help1' monthly, linear gen(`help2') /*linear extrapolation but missing before 1st and after last observation*/	
		/*--> 3)*/
		gen marker_period_vskt = 0
			replace marker_period_vskt = 1 if !missing(`help2') /*1 if within VSKT range and 0 else*/
		
		
		**********
		** SOEP **
		**********
		/*From the SOEP data, we know the first and last point of contact:
			- eintritt = 1st contact
			- austritt = last contact 
		Based on this, we can define the range of SOEP coverage */
		gen marker_period_soep = 0
			replace marker_period_soep = 1 if inrange(syear, eintritt, austritt)
		
		tab marker_period_vskt marker_period_soep,m 
		/*
		marker_per |  marker_period_soep
		  iod_vskt |         0          1 |     Total
		-----------+----------------------+----------
				 0 |   646,052    176,079 |   822,131 
				 1 | 3,196,756  1,476,417 | 4,673,173 
		-----------+----------------------+----------
			 Total | 3,842,808  1,652,496 | 5,495,304 
		--> we have 646,052 rows that we can drop b/c not in period covered by 
			VSKT or SOEP 
		--> we have much more periods that are covered by VSKT but not by SOEP 
			than vice versa. Makes sense b/c VSKT can go back to age 14 while 
			SOEP started in 1984 only & many are sampled only later. 
		--> periods that are coveres by SOEP but not by VSKT are also plausible, 
			e.g. after last labor market participation 
		*/
		
		*************************************************************
		** Drop observations that are not covererd by SOEP or VSKT **
		*************************************************************
		drop if marker_period_vskt==0 & marker_period_soep==0
		/*(646,052 observations deleted)*/
		
	****************************************
	** drop variables that we do not need **
	****************************************
	
	** child vars for 4th+ children **
	drop GBKIJ4 GBKIJ5 GBKIJ6 GBKIJ7 GBKIJ8 GBKIJ9 GBKIJ10
	drop GBKIM4 GBKIM5 GBKIM6 GBKIM7 GBKIM8 GBKIM9 GBKIM10
	drop child4* child5* child6* child7* child8* child9* child10* child11* child12* child13* child14* child15* child16* child17* child18* child19*
	drop nchild4 biochild4 famofreq_fid4 fathfreq_fid4 nchild5 biochild5 famofreq_fid5 fathfreq_fid5 nchild6 biochild6 famofreq_fid6 fathfreq_fid6
	drop kidgeb4 kidgeb5 kidgeb6 kidgeb7 kidgeb8 kidgeb9 kidgeb10 kidgeb11 kidgeb12 kidgeb13 kidgeb14 kidgeb15 kidgeb16 kidgeb17 kidgeb18 kidgeb19
	drop kidmon4 kidmon5 kidmon6 kidmon7 kidmon8 kidmon9 kidmon11 kidmon10 kidmon12 kidmon13 kidmon14 kidmon15 kidmon16 kidmon17 kidmon18 kidmon19
	drop age_at_child4 age_at_child5 age_at_child6 age_at_child7 age_at_child8 age_at_child9 age_at_child10
	drop marr_childbirth4 single_childbirth4 partner_childbirth4 marr_childbirth5 single_childbirth5 partner_childbirth5 marr_childbirth6 single_childbirth6 partner_childbirth6 marr_childbirth7 single_childbirth7 partner_childbirth7 marr_childbirth8 single_childbirth8 partner_childbirth8 marr_childbirth9 single_childbirth9 partner_childbirth9 marr_childbirth10 single_childbirth10 partner_childbirth10
	
********************************************************************************
** save datatset **
********************************************************************************

capture drop __00* /*drop potential left overs from temp vars*/

compress

label language EN /*use English labels for SOEP vars*/

save "$datawork/soeprv_edited.dta", replace















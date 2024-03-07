********************************************************************************
** 							SOEP-RV: Graphics - Penalties		  			  **
********************************************************************************

/*******************************************************************************
 Do-Files generates Graphs created with RV-SOEP Data:

Marriage Penalty (Income & Time-Use)
    - By Gender
        o naive 
        o with event children
        o combined
		o decomposition: extenisve margin, intensive margin, wages
    - By Gender & Parental Status
        o Binary
        o 5 categories
    - By Gender & ...
        o years between 1st child and marriage
        o By Gender & divorce status
        o By Gender & decade of marriage (1950 - 2000)
        o By Gender & age group at marriage
        o By Gender & pre-marriage income
        o By Gender & parents co-habitation status
    -  For Linked Partners 
        o By Gender 
        o By Gender & Breadwinner Status

Marriage Penalty controling CP - yearly
        
Child Penalty 
    - By Gender
        o naive
        o with event marriage
		o decomposition: extenisve margin, intensive margin, wages
    - By Gender & Marital Status
        o All
        o Excluding Singles
		
*******************************************************************************/


********************************************************************************
** Marriage Penalty Graphs **
********************************************************************************

*************
* By Gender *
*************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
	
	use "$datawork/mp_penalty_all_`outcome'.dta", clear 

	* Penalty *
	local penaltylength = 120 / 2
		quietly sum penal if eventtime >= `penaltylength'	
		local m1 = r(mean)
	gen penalty = `m1'*100
	format penalty %9.1fc
	tostring penalty, replace force usedisplayformat
	local penalty = penalty

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	* Graph *
	#delimit ; 
	twoway 
		rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
		line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		ttext(-0.6 -58  "{it:Longterm Gap}" "= `penalty'%", 
		placement(ne) justification(left) size(medsmall)) ;
	#delimit cr

	graph export "$graphs_soeprv/mp_all_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_all_`outcome'.pdf", replace
}


***********************************
* By Gender - w/ event time child *
***********************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
	foreach sample in all randommarr1child1_0 n_children1 n_children2 n_children3 {
	foreach age in age_bio /*age_labor*/ /*age_bio_labor*/ {
		if "`age'" == "age_bio" /*biological age*/ {
			local agevar = "age"
		}
		if "`age'" == "age_labor" /*labor market age*/ {
			local agevar = "age_labor_market"
		}
		if "`age'" == "age_bio_labor" /*both ages*/ {
			local agevar = "age age_labor_market"
		}
		use "$datawork/mp_penalty_`sample'_`outcome'_controlchildtime_`age'.dta", clear 

		* Penalty *
		local penaltylength = 120 / 2
			quietly sum penal if eventtime >= `penaltylength'	
			local m1 = r(mean)
		gen penalty = `m1'*100
		format penalty %9.1fc
		tostring penalty, replace force usedisplayformat
		local penalty = penalty

		*outcome specific locals*
		if "`outcome'" == "MEGPT_work" {
			local ytitle = "Earnings relative to t-12"
		}
		if "`outcome'" == "dummy_work" {
			local ytitle = "Share working relative to t-12"
		}
		
		foreach sex in women men {
			gen var_p`sex'= var_c`sex' + b_m1`sex'
			foreach bound in H L { 
				gen var_c`bound'`sex' = var_p`sex' - bound`bound'`sex'*var_c`sex'
				gen b`bound'`sex' = var_p`sex' - var_c`bound'`sex'
			} // bound
		} // sex
				
		* Graph - plain ES estimate in 2015 EUR*
		foreach sex in women men {
			foreach var in b_m1`sex' bL`sex' bH`sex' {
				gen `var'_2015EUR = `var' * 35363
			} // var
		} // sex
					
		#delimit ; 
		twoway 
			rarea bLmen_2015EUR bHmen_2015EUR eventtime, fcolor(orange%20) lwidth(none) || 
			rarea bLwomen_2015EUR bHwomen_2015EUR eventtime, fcolor(navy%20) lwidth(none) || 
			line b_m1men_2015EUR eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line b_m1women_2015EUR eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			yscale(r(-1000 600))
			ylabel(-1000(200)600, angle(0) format(%9.0fc))
			xlabel(-60(12)120) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_`outcome'_controlchildtime_`age'_abs_2015EUR.png", replace
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_controlchildtime_`age'_abs_2015EUR.pdf", replace
		
		* Graph - Kleven style estimate*
		#delimit ; 
		twoway 
			rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
			line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			/*ttext(-0.6 -58  "{it:Longterm Gap}" "= `penalty'%", 
			placement(ne) justification(left) size(medsmall))*/ ;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_`outcome'_controlchildtime_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_controlchildtime_`age'.pdf", replace
	} // age 
	} // sample
} // outcome

*********************************
** naive & w/ controlchildtime **
*********************************
foreach outcome in MEGPT_work /*dummy_work*/ {
	foreach sample in all randommarr1child1_0 {
	foreach age in age_bio /*age_labor age_bio_labor*/ {
	foreach estimate in beta /*plain ES estimate*/ gap /*Kleven style estimate*/ {
		
		** locals for different age ** 
		if "`age'" == "age_bio" /*biological age*/ {
			local agevar = "age"
		}
		if "`age'" == "age_labor" /*labor market age*/ {
			local agevar = "age_labor_market"
		}
		if "`age'" == "age_bio_labor" /*both ages*/ {
			local agevar = "age age_labor_market"
		}
		
		******************
		** open dataset ** 
		******************
		*naive estimation*
		use "$datawork/mp_penalty_`sample'_`outcome'_`age'.dta", clear  
		rename * naive_* /*rename all vars so we can diff both estimations*/
		*control childtime*
		append using "$datawork/mp_penalty_`sample'_`outcome'_controlchildtime_`age'.dta"
		
		** locals etc. for different estimates ** 
		if "`estimate'" == "beta" {
			/*compute bounds for abs estimate (b/c we don't take them from estimation sample)*/
			foreach sex in women men {
				gen naive_var_p`sex'= naive_var_c`sex' + naive_b`sex'
				gen var_p`sex'= var_c`sex' + b_m1`sex'
				foreach bound in H L { 
					gen naive_var_c`bound'`sex' = naive_var_p`sex' - naive_bound`bound'`sex'*naive_var_c`sex'
					gen var_c`bound'`sex' = var_p`sex' - bound`bound'`sex'*var_c`sex'
					gen naive_b`bound'`sex' = naive_var_p`sex' - naive_var_c`bound'`sex'
					gen b`bound'`sex' = var_p`sex' - var_c`bound'`sex'
				} // bound
			} // sex
			** EUR values for outcome == earnings ** 
			if "`outcome'" == "MEGPT_work" {
				local name = "_2015EUR"
				local name_file = "_abs_2015EUR"
				foreach sex in women men {
					foreach var in b_m1`sex' bL`sex' bH`sex' naive_b`sex' naive_bL`sex' naive_bH`sex' {
						gen `var'_2015EUR = `var' * 35363
					} // var
				} // sex
			}
			if "`outcome'" == "dummy_work" {
				local name = ""
				local name_file "_abs"
			}
			gen penal_abs = b_m1men`name' - b_m1women`name'
			gen naive_penal_abs = naive_bmen`name' - naive_bwomen`name'
			local penal = "penal_abs" /*we use this for point estimate longterm gap*/
			local naive_penal = "naive_penal_abs"
			local plot = "b_m1"
			local naive_plot = "b"
			local plotbound = "b" 
			local naive_plotbound = "b"
		}
		if "`estimate'" == "gap" {
			local penal = "penal" /*we use this for point estimate longterm gap*/
			local naive_penal = "naive_penal"
			local name = ""
			local name_file = ""
			local plot = "gap"
			local naive_plot = "gap"
			local plotbound = "bound"
			local naive_plotbound = "bound"
		}
		
		*************
		** Penalty **
		*************
		local penaltylength = 120 / 2
		*naive estimation & control childtime*
		foreach specification in naive childtime { 
			if "`specification'" == "naive" {
				local pre = "naive_" 
			}
			if "`specification'" == "childtime" {
				local pre = "" 
			}
			quietly sum `pre'`penal' if `pre'eventtime >= `penaltylength'	
			local m1 = r(mean)
			if "`estimate'" == "beta" {
				if "`outcome'" == "MEGPT_work" {
					gen `pre'penalty = `m1' /*this is already in EUR*/
					format `pre'penalty %9.0fc
					local unit = "€"
				}
				if "`outcome'" == "dummy_work" {
					gen `pre'penalty = `m1'*100
					format `pre'penalty %9.1fc
					local unit = "%P"
				}
			}
			if "`estimate'" == "gap" {
				gen `pre'penalty = `m1'*100 /*x 100 b/c we want this as %*/
				format `pre'penalty %9.1fc
				local unit = "%"
			}
			tostring `pre'penalty, replace force usedisplayformat
			local `pre'penalty = `pre'penalty
		}
		
		*****************
		** plot graphs ** 
		*****************
		*locals for graph* 
		local ylabel = "-0.6(0.2)0.2, angle(0) format(%9.1fc)" /*default*/
		local yscale = "r(-0.65 0.25)"
		local textx1 = "-0.4"
		local textx2 = "-0.435"
		if "`outcome'" == "MEGPT_work" {
			local ytitle = "Monthly gross earnings"
			if "`estimate'" == "beta" {
				local ylabel = "-1500(500)500, angle(0) format(%9.0fc)" /*change only for EUR values*/
				local yscale = "r(-1500 500)"
				local textx1 = "-1000"
				local textx2 = "-1100"
			}
		}
		if "`outcome'" == "dummy_work" {
			local ytitle = "Share working"
		}
		* Graph -- only naive *
		#delimit ;
		twoway 
			/*naive*/
			rarea naive_`naive_plotbound'Lmen`name' naive_`naive_plotbound'Hmen`name' naive_eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_`naive_plotbound'Lwomen`name' naive_`naive_plotbound'Hwomen`name' naive_eventtime, fcolor(navy%20) lwidth(none) || 
			line naive_`naive_plot'men`name' naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) || 
			line naive_`naive_plot'women`name' naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) ||
			/*control childtime*/
			rarea `plotbound'Lmen`name' `plotbound'Hmen`name' eventtime if eventtime==999, fcolor(orange%20) lwidth(none) || 
			rarea `plotbound'Lwomen`name' `plotbound'Hwomen`name' eventtime if eventtime==999, fcolor(navy%20) lwidth(none) || 
			line `plot'men`name' eventtime if eventtime==999, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line `plot'women`name' eventtime if eventtime==999, lcolor(navy) lpattern(solid) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for children" 8 "Women - account for children") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_1_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_1_`age'`name_file'.pdf", replace
		
		* Graph -- naive + control childtime *
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_`naive_plotbound'Lmen`name' naive_`naive_plotbound'Hmen`name' naive_eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_`naive_plotbound'Lwomen`name' naive_`naive_plotbound'Hwomen`name' naive_eventtime, fcolor(navy%20) lwidth(none) || 
			line naive_`naive_plot'men`name' naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) || 
			line naive_`naive_plot'women`name' naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) ||
			/*control childtime*/
			rarea `plotbound'Lmen`name' `plotbound'Hmen`name' eventtime, fcolor(orange%20) lwidth(none) || 
			rarea `plotbound'Lwomen`name' `plotbound'Hwomen`name' eventtime, fcolor(navy%20) lwidth(none) || 
			line `plot'men`name' eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line `plot'women`name' eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)  
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for children" 8 "Women - account for children") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_2_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_2_`age'`name_file'.pdf", replace
		
		* Graph -- naive + control childtime WITH POINT ESTIMATE*
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_`naive_plotbound'Lmen`name' naive_`naive_plotbound'Hmen`name' naive_eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_`naive_plotbound'Lwomen`name' naive_`naive_plotbound'Hwomen`name' naive_eventtime, fcolor(navy%20) lwidth(none) || 
			line naive_`naive_plot'men`name' naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) || 
			line naive_`naive_plot'women`name' naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) ||
			/*control childtime*/
			rarea `plotbound'Lmen`name' `plotbound'Hmen`name' eventtime, fcolor(orange%20) lwidth(none) || 
			rarea `plotbound'Lwomen`name' `plotbound'Hwomen`name' eventtime, fcolor(navy%20) lwidth(none) || 
			line `plot'men`name' eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line `plot'women`name' eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			ttext(`textx1' -60  "{it:Longterm Gap}" "naive: `naive_penalty'`unit'", 
				placement(ne) justification(left) size(small))
			ttext(`textx2' -60  "account for children: `penalty'`unit'", 
				placement(ne) justification(left) size(small))
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for children" 8 "Women - account for children") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_3_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_`outcome'_naive_controlchildtime_3_`age'`name_file'.pdf", replace
	
	} // estimate
	} // age
	} // sample
} // outcome

****************************************************************************
** By Gender - decomposition Sample **
****************************************************************************
/*Monthly information is for result on income and extensive margin. For hours 
 worked and hourly wage see yearly graphs*/

foreach var in wd weekly {
foreach outcome in MEGPT_work dummy_work {
	foreach age in age_bio {
		
		**********
		** data **
		**********
		* Append Data for every event *	
		use "$datawork/mp_penalty_decomposition_var`var'_`outcome'_controlchildtime_`age'_unweighted", replace
						
		if "`outcome'" == "MEGPT_work" local ytitle = "Income (EP)"
		if "`outcome'" == "dummy_work" local ytitle = "Share working"
		************
		** graphs **
		***********

		#delimit ; 
		twoway 
			rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
			line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle' relative to t-1")  
			xlabel(-60(12)120) xscale(titlegap(1.5))
			/*ylabel(-0.6(0.2)0.2, angle(0))*/
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_decomposition_var`var'_`outcome'_controlchildtime_`age'.png", replace
		graph export "$graphs_soeprv/mp_decomposition_var`var'_`outcome'_controlchildtime_`age'.pdf", replace
	}
	}
}

****************************************
* By Gender & Parental Status - Binary *
****************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {

	use "$datawork/mp_penalty_nochild_`outcome'.dta", clear 
	append using "$datawork/mp_penalty_withchild_`outcome'.dta" 

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	egen penalty1 = mean(penal) if sample=="nochild"
		ereplace penalty1=mean(penalty1)
		replace penalty1=penalty1*100
		format penalty1 %9.1fc
		tostring penalty1, replace force usedisplayformat 
		local penalty1 = penalty1
	egen penalty2 = mean(penal) if sample=="withchild"
		ereplace penalty2=mean(penalty2)
		replace penalty2=penalty2*100
		format penalty2 %9.1fc
		tostring penalty2, replace force usedisplayformat 
		local penalty2 = penalty2
		
	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="nochild", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="nochild", fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime if sample=="withchild", 	fcolor(navy%25) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="withchild", 	fcolor(orange%25) lwidth(none) ||
		line gapwomen eventtime if sample=="nochild", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
		line gapmen   eventtime if sample=="nochild", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
		line gapwomen eventtime if sample=="withchild", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="withchild", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		xtitle("Time relative to marriage (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120)  xscale(titlegap(1.5))
		legend(order(5 "Women: No Children Ever" 6 "Men: No Children Ever" 7 "Women: Children in Marriage" 8 "Men: Children in Marriage") 
		col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
		ttext(-0.6 -58 
			"{it:Longterm Gap: }"
			"{it:No Children} = `penalty1'%" 
			"{it:Children during} = `penalty2'%", 
			justification(left) size(small) placement(ne));
	#delimit cr

	graph export "$graphs_soeprv/mp_parentalstatus_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_parentalstatus_`outcome'.pdf", replace
}


**********************************************
* By Gender & Parental Status - 5 Categories *
**********************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
	
	clear
	forval n=0/4 {
		append using "$datawork/mp_penalty_childstatus`n'_`outcome'.dta" 
	}

	local title0 "No Children ever"
	local yscale0 "-0.4(0.2)0.2"
	local texty0 "-0.4"
	local title1 "Children >12 Months before Marriage"
	local yscale1 "-0.4(0.2)0.6"
	local texty1 "-0.4"
	local title2 "Children <=12 Months before Marriage"
	local yscale2 "-0.8(0.2)0.2"
	local texty2 "-0.8"
	local title3 "Children during Marriage"
	local yscale3 "-0.6(0.2)0.2"
	local texty3 "-0.6"
	local title4 "Children after Marriage"
	local yscale4 "-0.6(0.2)0.4"
	local texty4 "-0.6"

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	forval n=0/4 {

	egen penalty`n' = mean(penal) if sample=="childstatus`n'"
		ereplace penalty`n'=mean(penalty`n')
		replace penalty`n'=penalty`n'*100
		format penalty`n' %9.1fc
		tostring penalty`n', replace force usedisplayformat 
		local penalty`n' = penalty`n'

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
		
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="childstatus`n'", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="childstatus`n'", fcolor(orange%20) lwidth(none) || 
		line gapwomen eventtime if sample=="childstatus`n'", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="childstatus`n'", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(`yscale`n'', angle(0)) 
		xtitle("Time relative to marriage (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) 
		legend(order(3 "Women" 4 "Men")
		col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
		/*title("`title`n''")*/
		ttext("`texty`n''" -58 
			"{it:Longterm Gap}: `penalty`n''%", 
			justification(left) size(small) placement(ne));
	#delimit cr

	graph export "$graphs_soeprv/mp_parentalstatus_`n'_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_parentalstatus_`n'_`outcome'.pdf", replace
	}
}

****************************************************
* By Gender & years between 1st child and marriage *
****************************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
	clear

	/*0 value*/
	append using "$datawork/mp_penalty_years_marriage_birth_0_`outcome'.dta" 
	forval n=1/5 {
		/*negative values = */
		append using "$datawork/mp_penalty_years_marriage_birth_minus`n'_`outcome'.dta" 
		/*positive values = */
		append using "$datawork/mp_penalty_years_marriage_birth_`n'_`outcome'.dta" 
	}

	*** All groups individually (n = -5, ..., 0, ..., 5) ***
	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	forval n=-5/5 /*marriage 5 years before/after birth*/ {
				if `n' < 0 {
					local pos = -`n'
					local name = "minus`pos'"
				}
				if `n' >= 0 {
					local name = "`n'"
				}
	egen penalty`name' = mean(penal) if sample=="years_marriage_birth_minus`n'"
		ereplace penalty`name'=mean(penalty`name')
		replace penalty`name'=penalty`name'*100
		format penalty`name' %9.1fc
		tostring penalty`name', replace force usedisplayformat 
		local penalty`name' = penalty`name'

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="years_marriage_birth_`name'", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="years_marriage_birth_`name'", fcolor(orange%20) lwidth(none) || 
		line gapwomen eventtime if sample=="years_marriage_birth_`name'", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="years_marriage_birth_`name'", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(`yscale`n'', angle(0)) 
		xtitle("Time relative to marriage (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) 
		legend(order(3 "Women" 4 "Men")
		col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
		title("`title`n''")
		ttext( "`texty`n''" -58 
			"{it:Longterm Gap}: `penalty`n''%", 
			justification(left) size(small) placement(ne));
	#delimit cr

	graph export "$graphs_soeprv/mp_years_marriage_birth_`name'_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_years_marriage_birth_`name'_`outcome'.pdf", replace
	}

	*** All births >= year of marriage together (n = -5, ..., 0) ***
	#delimit ; 
	twoway 	line gapwomen eventtime if sample=="years_marriage_birth_0", lcolor(black) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime if sample=="years_marriage_birth_minus1", lcolor(navy) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime if sample=="years_marriage_birth_minus2", lcolor(navy%80) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime if sample=="years_marriage_birth_minus3", lcolor(navy%60) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime if sample=="years_marriage_birth_minus4", lcolor(navy%40) lpattern(solid) lwidth(medthick) || 
			line gapwomen eventtime if sample=="years_marriage_birth_minus5", lcolor(navy%20) lpattern(solid) lwidth(medthick)
			graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(`yscale`n'', angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) 
			legend(order(1 "birth in year of marriage" 2 "1 year after marriage" 3 "2 years after marriage" 4 "3 years after marriage" 5 "4 years after marriage" 6 "5 years after marriage")
			col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
	;
	#delimit cr
	graph export "$graphs_soeprv/mp_years_marriage_birth_0to5_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_years_marriage_birth_0to5_`name'_`outcome'.pdf", replace
}

***************************************
* By Gender & Divorce Status - Binary *
***************************************
use "$datawork/mp_penalty_divorced0_MEGPT_work.dta", clear 
append using "$datawork/mp_penalty_divorced1_MEGPT_work.dta" 

local penaltylength = (120 / 2) 
bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
	replace penal = . if eventtime < `penaltylength' 
egen penalty1 = mean(penal) if sample=="divorced0"
	ereplace penalty1=mean(penalty1)
	replace penalty1=penalty1*100
	format penalty1 %9.1fc
	tostring penalty1, replace force usedisplayformat 
	
egen penalty2 = mean(penal) if sample=="divorced1"
	ereplace penalty2=mean(penalty2)
	replace penalty2=penalty2*100
	format penalty2 %9.1fc
	tostring penalty2, replace force usedisplayformat 
	
local penalty1 = penalty1
local penalty2 = penalty2

*Graph*	
#delimit ; 
twoway 
	rarea boundLwomen boundHwomen eventtime if sample=="divorced0", fcolor(navy%20) lwidth(none) || 
	rarea boundLmen   boundHmen   eventtime if sample=="divorced0", fcolor(orange%20) lwidth(none) || 
	rarea boundLwomen boundHwomen eventtime if sample=="divorced1", 	fcolor(navy%25) lwidth(none) || 
	rarea boundLmen   boundHmen   eventtime if sample=="divorced1", 	fcolor(orange%25) lwidth(none) ||
	line gapwomen eventtime if sample=="divorced0", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
	line gapmen   eventtime if sample=="divorced0", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
	line gapwomen eventtime if sample=="divorced1", lcolor(navy) lpattern(solid) lwidth(medthick) || 
	line gapmen   eventtime if sample=="divorced1", lcolor(orange) lpattern(solid) lwidth(medthick)
, graphregion(color(white) lstyle(none)) 
	xline(-0.5, lcolor(cranberry)) 
	yline(0, lstyle(grid)) 
	ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
	xtitle("Time relative to marriage (months)") 
	ytitle("Earnings relative to t-12")  
	xlabel(-60(12)120)  xscale(titlegap(1.5))
	legend(order(5 "Women: No Divorce" 6 "Men: No Divorce" 7 "Women: Divorce" 8 "Men: Divorce") 
	col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
	ttext(-0.6 -58 
		"{it:Longterm Gap: }"
		"{it:No Divorce} = `penalty1'%" 
		"{it:Divorce} = `penalty2'%", 
		justification(left) size(small) placement(ne));
#delimit cr

graph export "$graphs_soeprv/mp_divorcestatus_MEGPT_work.png", replace
graph export "$graphs_soeprv/mp_divorcestatus_MEGPT_work.pdf", replace


************************************************
* By Gender & decade of marriage (1950 - 2000) *
************************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {

	clear

	forval d=1950(10)2000 {
		append using "$datawork/mp_penalty_marriage_decade`d'_`outcome'.dta" 
	}

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	** each decade separately **
	forval d=1950(10)2000 {

		egen penalty`d' = mean(penal) if sample=="marriage_decade`d'"
			ereplace penalty`d'=mean(penalty`d')
			replace penalty`d'=penalty`d'*100
			format penalty`d' %9.1fc
			tostring penalty`d', replace force usedisplayformat 
			local penalty`d' = penalty`d'
		
			
		*Graph*	
		#delimit ; 
		twoway 
			rarea boundLwomen boundHwomen eventtime if sample=="marriage_decade`d'", fcolor(navy%20) lwidth(none) || 
			rarea boundLmen   boundHmen   eventtime if sample=="marriage_decade`d'", fcolor(orange%20) lwidth(none) || 
			line gapwomen eventtime if sample=="marriage_decade`d'", lcolor(navy) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="marriage_decade`d'", lcolor(orange) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.2, angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-60(12)120) 
			legend(order(3 "Women" 4 "Men")
			col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
			ttext( -0.5 -58 
				"{it:Longterm Gap}: `penalty`d''%", 
				justification(left) size(small) placement(ne));
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_decade_`d'_`outcome'.png", replace
		graph export "$graphs_soeprv/mp_marriage_decade_`d'_`outcome'.pdf", replace
	}

	** all decades together in one figure **
	#delimit ;
	twoway 	/*1960*/
		line gapwomen eventtime if sample=="marriage_decade1960",
			lcolor(yellow) || 
		line gapmen eventtime if sample=="marriage_decade1960",
			lcolor(yellow) lpattern(-) || 
		/*1970*/
		line gapwomen eventtime if sample=="marriage_decade1970",
			lcolor(orange) || 
		line gapmen eventtime if sample=="marriage_decade1970",
			lcolor(orange) lpattern(-) || 
		/*1980*/
		line gapwomen eventtime if sample=="marriage_decade1980",
			lcolor(red)  || 
		line gapmen eventtime if sample=="marriage_decade1980",
			lcolor(red) lpattern(-)  || 
		/*1990*/
		line gapwomen eventtime if sample=="marriage_decade1990",
			lcolor(pink) || 
		line gapmen eventtime if sample=="marriage_decade1990",
			lcolor(pink) lpattern(-) || 
		/*2000*/
		line gapwomen eventtime if sample=="marriage_decade2000",
			lcolor(purple)  || 
		line gapmen eventtime if sample=="marriage_decade2000",
			lcolor(purple) lpattern(-) 
		graphregion(fcolor(white)) 
		xline(0, lstyle(grid))
		xtitle("Time relative to marriage (months)")
		xlabel(-60(12)120) 
		ytitle("`ytitle'")  
		legend(order(1 "1960s" 3 "1970s" 5 "1980s" 7 "1990s" 9 "2000s") r(1))
		graphregion(fcolor(white)) 
	;
	#delimit cr
	graph export "$graphs_soeprv/mp_marriage_decades_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_marriage_decades_`outcome'.pdf", replace
}

********************************************************
* By Gender & Age group at Marriage *
********************************************************
clear

forval d=1/3 {
	append using "$datawork/mp_penalty_marriage_agegroup3_`d'_MEGPT_work.dta" 
}

local penaltylength = (120 / 2) 
bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
	replace penal = . if eventtime < `penaltylength' 

	** each decade separately **
	forval d=1/3 {

		egen penalty`d' = mean(penal) if sample=="marriage_agegroup3_`d'"
			ereplace penalty`d'=mean(penalty`d')
			replace penalty`d'=penalty`d'*100
			format penalty`d' %9.1fc
			tostring penalty`d', replace force usedisplayformat 
			local penalty`d' = penalty`d'
		
			
		*Graph*	
		#delimit ; 
		twoway 
			rarea boundLwomen boundHwomen eventtime if sample=="marriage_agegroup3_`d'", fcolor(navy%20) lwidth(none) || 
			rarea boundLmen   boundHmen   eventtime if sample=="marriage_agegroup3_`d'", fcolor(orange%20) lwidth(none) || 
			line gapwomen eventtime if sample=="marriage_agegroup3_`d'", lcolor(navy) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="marriage_agegroup3_`d'", lcolor(orange) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.2, angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-12")  
			xlabel(-60(12)120) 
			legend(order(3 "Women" 4 "Men")
			col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
			ttext( -0.5 -58 
				"{it:Longterm Gap}: `penalty`d''%", 
				justification(left) size(small) placement(ne));
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_marriage_agegroup3_`d'_MEGPT_work.png", replace
		graph export "$graphs_soeprv/mp_marriage_marriage_agegroup3_`d'_MEGPT_work.pdf", replace
	}

***********************************
* By Gender & pre-marriage income *
***********************************
clear

forval ep=25(25)150 {
	append using "$datawork/mp_penalty_premarriageincome_percent_`ep'_MEGPT_work.dta" 
}

	** all income groups together -- women & men **
	#delimit ; 
		twoway 
			/*>0 - 25% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_25", lcolor(red) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_25", lcolor(red) lpattern(-) lwidth(medthick) ||
			/*>25 - 50% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_50", lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_50", lcolor(orange) lpattern(-) lwidth(medthick) ||
			/*>50 - 75% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_75", lcolor(yellow) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_75", lcolor(yellow) lpattern(-) lwidth(medthick) ||
			/*>75 - 100% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_100", lcolor(lime) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_100", lcolor(lime) lpattern(-) lwidth(medthick) ||
			/*>100 - 125% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_125", lcolor(blue) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_125", lcolor(blue) lpattern(-) lwidth(medthick) ||
			/*>125 - 150% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_150", lcolor(purple) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_150", lcolor(purple) lpattern(-) lwidth(medthick) ||
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.2, angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-12")  
			xlabel(-60(12)120) 
			legend(order(1 "Women >0-25%" 3 ">25-50%" 5 ">50-75%" 7 "75-100%"  9 ">100-125%" 11 ">125-150%"
						 2 "Men >0-25%"   4 ">25-50%" 6 ">50-75%" 8 "75-100%" 10 ">100-125%" 12 ">125-150%")
			row(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)));
		#delimit cr
		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_MEGPT_work.png", replace
		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_MEGPT_work.pdf", replace
	
	** all income groups together -- women only **
	#delimit ; 
		twoway 
			/*>0 - 25% of average annual income*/
			/*line gapwomen eventtime if sample=="premarriageincome_percent_25", lcolor(red) lpattern(solid) lwidth(medthick) ||*/
			/*>25 - 50% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_50", lcolor(orange) lpattern(solid) lwidth(medthick) || 
			/*>50 - 75% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_75", lcolor(yellow) lpattern(solid) lwidth(medthick) || 
			/*>75 - 100% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_100", lcolor(lime) lpattern(solid) lwidth(medthick) || 
			/*>100 - 125% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_125", lcolor(blue) lpattern(solid) lwidth(medthick) || 
			/*>125 - 150% of average annual income*/
			line gapwomen eventtime if sample=="premarriageincome_percent_150", lcolor(purple) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.2, angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-12")  
			xlabel(-60(12)120) 
			legend(order(/*1 "Women >0-25%" 2 ">25-50%" 3 ">50-75%" 4 "75-100%" 5 ">100-125%" 6 ">125-150%"*/
						1 ">25-50%" 2 ">50-75%" 3 "75-100%" 4 ">100-125%" 5 ">125-150%")
			row(1) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)));
		#delimit cr
		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_MEGPT_work_women.png", replace
		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_MEGPT_work_women.pdf", replace
		
	** each income group separately **
	forval ep=25(25)150 {
		
		/*no penalty estimate b/c we cannot link women and men here 
			--> only have their individual income*/
		
		*Graph*	
		#delimit ; 
		twoway 
			rarea boundLwomen boundHwomen eventtime if sample=="premarriageincome_percent_`ep'", fcolor(navy%20) lwidth(none) || 
			rarea boundLmen   boundHmen   eventtime if sample=="premarriageincome_percent_`ep'", fcolor(orange%20) lwidth(none) || 
			line gapwomen eventtime if sample=="premarriageincome_percent_`ep'", lcolor(navy) lpattern(solid) lwidth(medthick) || 
			line gapmen   eventtime if sample=="premarriageincome_percent_`ep'", lcolor(orange) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.2, angle(0)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-12")  
			xlabel(-60(12)120) 
			legend(order(3 "Women" 4 "Men")
			col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)));
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_`ep'_MEGPT_work.png", replace
		graph export "$graphs_soeprv/mp_marriage_premarriageincome_percent_`ep'_MEGPT_work.pdf", replace
	}


*******************************************
* By gender & parents' co-habiting status *
*******************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {

	use "$datawork/mp_penalty_grewup_bothparents0_`outcome'.dta", clear 
	append using "$datawork/mp_penalty_grewup_bothparents1_`outcome'.dta" 

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	egen penalty1 = mean(penal) if sample=="grewup_bothparents0"
		ereplace penalty1=mean(penalty1)
		replace penalty1=penalty1*100
		format penalty1 %9.1fc
		tostring penalty1, replace force usedisplayformat 
		local penalty1 = penalty1
	egen penalty2 = mean(penal) if sample=="grewup_bothparents1"
		ereplace penalty2=mean(penalty2)
		replace penalty2=penalty2*100
		format penalty2 %9.1fc
		tostring penalty2, replace force usedisplayformat 
		local penalty2 = penalty2
		
	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="grewup_bothparents0", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="grewup_bothparents0", fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime if sample=="grewup_bothparents1", 	fcolor(navy%25) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="grewup_bothparents1", 	fcolor(orange%25) lwidth(none) ||
		line gapwomen eventtime if sample=="grewup_bothparents0", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
		line gapmen   eventtime if sample=="grewup_bothparents0", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
		line gapwomen eventtime if sample=="grewup_bothparents1", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="grewup_bothparents1", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		xtitle("Time relative to marriage (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120)  xscale(titlegap(1.5))
		legend(order(5 "Women: grew up w/ single parent" 6 "Men: grew up w/ single parent" 7 "Women: grew up w/ both parents" 8 "Men: grew up w/ both parents") 
		col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
		ttext(-0.6 -58 
			"{it:Longterm Gap: }"
			"{it:w/ single parent} = `penalty1'%" 
			"{it:w/ both parents} = `penalty2'%", 
			justification(left) size(small) placement(ne));
	#delimit cr

	graph export "$graphs_soeprv/mp_grewup_`outcome'.png", replace
	graph export "$graphs_soeprv/mp_grewup_`outcome'.pdf", replace
}


*******************************************
* By Gender & Randomization of Month info *
*******************************************
forval n==0/2 {
use "$datawork/mp_penalty_randommarr1child1_`n'_MEGPT_work_controlchildtime_age_bio.dta", clear 

*Graph*	
#delimit ; 
twoway 
	rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
	rarea boundLmen   boundHmen   eventtime, fcolor(orange%20) lwidth(none) || 
	line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) || 
	line gapmen   eventtime, lcolor(orange) lpattern(solid) lwidth(medthick)
, graphregion(color(white) lstyle(none)) 
	xline(-0.5, lcolor(cranberry)) 
	yline(0, lstyle(grid)) 
	ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
	xtitle("Time relative to marriage (months)") 
	ytitle("Earnings relative to t-12")  
	xlabel(-60(12)120)  xscale(titlegap(1.5))
	legend(order(3 "Women" 4 "Men") 
	col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
	;
#delimit cr

graph export "$graphs_soeprv/mp_randommarr1child1_`n'_MEGPT_work_controlchildtime_age_bio.png", replace
graph export "$graphs_soeprv/mp_randommarr1child1_`n'_MEGPT_work_controlchildtime_age_bio.pdf", replace
}

***************************************
* Linked Spouses: By Gender - Income  *
***************************************
use "$datawork/mp_penalty_linked_spouses_all_MEGPT_work.dta", clear 

* Penalty *
local penaltylength = 10 / 2
	quietly sum penal if eventtime >= `penaltylength'	
	local m1 = r(mean)
gen penalty = `m1'*100
format penalty %9.1fc
tostring penalty, replace force usedisplayformat
local penalty = penalty

* Graph *
#delimit ; 
twoway 
	rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
	rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
	line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick)  || 
	line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
, graphregion(color(white) lstyle(none)) 
	xline(-0.5, lcolor(cranberry)) 
	yline(0, lstyle(grid)) 
	xtitle("Time relative to Marriages (Months)") 
	ytitle("Earnings relative to t-12")  
	xlabel(-60(12)120) xscale(titlegap(1.5))
	ylabel(-0.6(0.1)0.2, angle(0))
	legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
	ttext(-0.5 -58  "{it:Longterm Gap}" "= `penalty'%", 
	placement(ne) justification(left) size(medsmall)) ;
#delimit cr

graph export "$graphs_soeprv/mp_linked_spouses_all_MEGPT_work.png", replace
graph export "$graphs_soeprv/mp_linked_spouses_all_MEGPT_work.pdf", replace

*****************************************************
* Linked Spouses: By Gender & Breadwinner - Income  *
*****************************************************
use "$datawork/mp_penalty_linked_spouses_femalebreadwinner_MEGPT_work.dta", clear 
append using "$datawork/mp_penalty_linked_spouses_malebreadwinner_MEGPT_work.dta" 

sum eventtime
local max = `r(max)'
local penaltylength = `max'/2
display `penaltylength'
bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
	replace penal = . if eventtime < `penaltylength' 
egen penalty1 = mean(penal) if sample=="femalebreadwinner"
	ereplace penalty1=mean(penalty1)
	replace penalty1=penalty1*100
	format penalty1 %9.1fc
	tostring penalty1, replace force usedisplayformat 
	
egen penalty2 = mean(penal) if sample=="malebreadwinner"
	ereplace penalty2=mean(penalty2)
	replace penalty2=penalty2*100
	format penalty2 %9.1fc
	tostring penalty2, replace force usedisplayformat 
	
local penalty1 = penalty1	
local penalty2 = penalty2
	
*Graph*	
#delimit ; 
twoway 
	rarea boundLwomen boundHwomen eventtime if sample=="femalebreadwinner", fcolor(navy%20) lwidth(none) || 
	rarea boundLmen   boundHmen   eventtime if sample=="femalebreadwinner", fcolor(orange%20) lwidth(none) || 
	rarea boundLwomen boundHwomen eventtime if sample=="malebreadwinner", 	fcolor(navy%25) lwidth(none) || 
	rarea boundLmen   boundHmen   eventtime if sample=="malebreadwinner", 	fcolor(orange%25) lwidth(none) ||
	line gapwomen eventtime if sample=="femalebreadwinner", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
	line gapmen   eventtime if sample=="femalebreadwinner", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
	line gapwomen eventtime if sample=="malebreadwinner", lcolor(navy) lpattern(solid) lwidth(medthick) || 
	line gapmen   eventtime if sample=="malebreadwinner", lcolor(orange) lpattern(solid) lwidth(medthick)
, graphregion(color(white) lstyle(none)) 
	xline(-0.5, lcolor(cranberry)) 
	yline(0, lstyle(grid)) 
	ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
	xtitle("Time relative to marriage (months)") 
	ytitle("Earnings relative to t-12")  
	xlabel(-60(12)120)  xscale(titlegap(1.5))
	legend(order(5 "Women: Primary Earner before" 6 "Men: Secondary Earner before" 7 "Women: Secondary Earner before" 8 "Men: Primary Earner before") 
	col(2) symx(3pt) size(small) region(lstyle(none) lcolor(white) margin(vsmall)))
	ttext(-0.6 -58 
		"{it:Longterm Gap: }"
		"{it:femalebreadwinner before} = `penalty1'%" 
		"{it:malebreadwinner before} = `penalty2'%", 
		justification(left) size(small) placement(ne));
#delimit cr

graph export "$graphs_soeprv/mp_linked_spouses_breadwinner_MEGPT_work.png", replace
graph export "$graphs_soeprv/mp_linked_spouses_breadwinner_MEGPT_work.pdf", replace



********************************************************************************
** Marriage Penalty controling CP - yearly ** 
********************************************************************************

	****************************************************************************
	** baseline -- monthly gross wage income **
	****************************************************************************
	global cmax 3
	
	foreach outcome in MEGPT_work dummy_work {
	foreach age in age_bio /*age_labor age_bio_labor*/ {
	foreach estimate in beta /*plain ES estimate*/ gap /*Kleven style estimate*/ {
		
		**********
		** data **
		**********
		* naive estimation *	
		use "$datawork/mp_penalty_yearly_all_`outcome'_`age'", clear
		rename * naive_* /*rename all vars so we can diff both estimations*/
		rename naive_eventtime eventtime 
		
		append using "$datawork/mp_penalty_yearly_all_`outcome'_m1_controlchildtime_`age'"
	
		order eventtime event outcome sample, first

		* keep only necessary event window * 
		keep if inrange(eventtime, -5, 10)
		
		** locals etc. for different estimates ** 
		if "`estimate'" == "beta" {
			
			** EUR values for outcome == earnings ** 
			if "`outcome'" == "MEGPT_work" {
				local name = "_2015EUR"
				local name_file = "_abs_2015EUR"
				foreach sex in women men {
					foreach var in b_m1`sex' bL_m1`sex' bH_m1`sex' naive_b`sex' naive_bL`sex' naive_bH`sex' {
						gen `var'_2015EUR = `var' * 35363 * 12 /*annual income*/
					} // var
				} // sex
			}
			if "`outcome'" == "dummy_work" {
				local name = ""
				local name_file "_abs"
			}
			gen penal_abs = b_m1men`name' - b_m1women`name'
			gen naive_penal_abs = naive_bmen`name' - naive_bwomen`name'
			local penal = "penal_abs" /*we use this for point estimate longterm gap*/
			local naive_penal = "naive_penal_abs"
			local plot = "b_m1"
			local naive_plot = "b"
			local plotbound = "b" 
			local naive_plotbound = "b"
		}
		
		if "`estimate'" == "gap" {
			local penal = "penal" /*we use this for point estimate longterm gap*/
			local naive_penal = "naive_penal"
			local name = ""
			local name_file = ""
			local plot = "gap_m1"
			local naive_plot = "gap"
			local plotbound = "bound"
			local naive_plotbound = "bound"
		}
		
		*************
		** Penalty **
		*************
		local penaltylength = 5
		quietly sum penal_m1 if eventtime >= `penaltylength'	
		local em1 = r(mean)
		gen penalty_m1 = `em1'*100
		format penalty_m1 %9.1fc
		tostring penalty_m1, replace force usedisplayformat
		local penalty = penalty_m1
		
		*****************
		** plot graphs ** 
		*****************
		*locals for graph* 
		local ylabel = "-0.6(0.2)0.2, angle(0) format(%9.1fc)" /*default*/
		local yscale = "r(-0.65 0.25)"
		
		if "`outcome'" == "MEGPT_work" {
			local ytitle = "Annual gross earnings"
			if "`estimate'" == "beta" {
				local ylabel = "-15000(5000)5000, angle(0) format(%9.0fc)" /*change only for EUR values*/
				local yscale = "r(-15500 5500)"
			}
		}
		if "`outcome'" == "dummy_work" {
			local ytitle = "Share working"
		}
		
		* Graph -- only naive (but with legend entry for controlchildtime) *
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_`naive_plotbound'Lmen`name' naive_`naive_plotbound'Hmen`name' eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_`naive_plotbound'Lwomen`name' naive_`naive_plotbound'Hwomen`name' eventtime, fcolor(navy%20) lwidth(none) || 
			connect naive_`naive_plot'men`name' eventtime, lcolor(orange) lpattern(-) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
			connect naive_`naive_plot'women`name' eventtime, lcolor(navy) lpattern(-) lwidth(medthick) mcolor(navy) msymbol(Oh)   ||
		/*control childtime*/
		rarea `plotbound'L_m1men`name' `plotbound'H_m1men`name' eventtime if eventtime==999, fcolor(orange%20) lwidth(none) || 
		rarea `plotbound'L_m1women`name' `plotbound'H_m1women`name' eventtime if eventtime==999, fcolor(navy%20) lwidth(none) || 
		connect `plot'men`name' eventtime if eventtime==999, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connect `plot'women`name' eventtime if eventtime==999, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
			graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for children" 8 "Women - account for children") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_1_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_1_`age'`name_file'.pdf", replace
		
		* Graph -- naive + control childtime*
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_`naive_plotbound'Lmen`name' naive_`naive_plotbound'Hmen`name' eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_`naive_plotbound'Lwomen`name' naive_`naive_plotbound'Hwomen`name' eventtime, fcolor(navy%20) lwidth(none) || 
			connect naive_`naive_plot'men`name' eventtime, lcolor(orange) lpattern(-) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
			connect naive_`naive_plot'women`name' eventtime, lcolor(navy) lpattern(-) lwidth(medthick) mcolor(navy) msymbol(Oh)   ||
			/*control childtime*/
			rarea `plotbound'L_m1men`name' `plotbound'H_m1men`name' eventtime, fcolor(orange%20) lwidth(none) || 
			rarea `plotbound'L_m1women`name' `plotbound'H_m1women`name' eventtime, fcolor(navy%20) lwidth(none) || 
			connect `plot'men`name' eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connect `plot'women`name' eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
			graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for children" 8 "Women - account for children") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_2_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_2_`age'`name_file'.pdf", replace
		
		* Graph -- only controlchildtime *
		#delimit ; 
		twoway 
		/*control childtime*/
		rarea `plotbound'L_m1men`name' `plotbound'H_m1men`name' eventtime, fcolor(orange%20) lwidth(none) || 
		rarea `plotbound'L_m1women`name' `plotbound'H_m1women`name' eventtime, fcolor(navy%20) lwidth(none) || 
		connect `plot'men`name' eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connect `plot'women`name' eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
			graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(`ylabel') yscale(`yscale')
			legend(order(3 "Men" 4 "Women")
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_`age'`name_file'.png", replace
		graph export "$graphs_soeprv/mp_all_yearly_`outcome'_controlchildtime_`age'`name_file'.pdf", replace
			
	} // estimate
	} // age
	} // outcome 
	
	
	****************************************************************************
	** baseline -- marriage decade -- seperate **
	****************************************************************************
	foreach age in age_bio /*age_labor age_bio_labor*/ {
	forval d=1960(10)2000 { 
		* Append Data for every event *	
		use "$datawork/mp_penalty_yearly_marriage_decade`d'_MEGPT_work_m1_controlchildtime_`age'", replace

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
			connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1") 
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.4, angle(0))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_decade`d'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_decade`d'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	
	****************************************************************************
	** baseline -- age group -- seperate **
	****************************************************************************
	/*using bio age can lead to collinearities*/ 
	foreach age in age_labor {
	forval d=1/3 { 
		* Append Data for every event *	
		use "$datawork/mp_penalty_yearly_marriage_agegroup3_`d'_MEGPT_work_m1_controlchildtime_`age'", replace

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_agegroup3_`d'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_marriage_agegroup3_`d'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	****************************************************************************
	** baseline -- distance marriage & childbirth -- seperate **
	****************************************************************************
	/*using bio age can lead to collinearities*/ 
	foreach age in age_bio {
	foreach sample in years_marriage_birth_minus4 years_marriage_birth_minus3 years_marriage_birth_minus2 years_marriage_birth_minus1 years_marriage_birth_0 years_marriage_birth_1 years_marriage_birth_2 years_marriage_birth_3 years_marriage_birth_4 years_marriage_birth_5 { 
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	****************************************************************************
	** baseline -- december marriage**
	****************************************************************************
	**************
	** Seperate **
	**************
	foreach age in age_bio {
	foreach sample in decmarriage_0 decmarriage_1 {
		
		* Append Data for every event *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.4, angle(0))
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	**************
	** Together **
	**************

	foreach age in age_bio {
		
		* Append Data for every event *	
		use "$datawork/mp_penalty_yearly_divorced0_MEGPT_work_m1_controlchildtime_`age'", replace
		append using "$datawork/mp_penalty_yearly_divorced1_MEGPT_work_m1_controlchildtime_`age'"
								

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime if sample=="divorced0", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="divorced0", fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime if sample=="divorced0", lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime if sample=="divorced0", lcolor(navy) lpattern(solid) lwidth(medthick) ||
			rarea boundL_m1men boundH_m1men eventtime if sample=="divorced1", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="divorced1", fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime if sample=="divorced1", lcolor(orange) lpattern(dash) lwidth(medthick) || 
			line gap_m1women eventtime if sample=="divorced1", lcolor(navy) lpattern(dash) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men - no divorced" 4 "Women - no divorce" 7 "Men - divorced" 8 "Women - divorced") col(2) region(lstyle(none) lcolor(white))) 
			;
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_divorce01_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_marriage_divorce01_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	
	****************************************************************************
	** baseline -- divorce yes/no -- seperate **
	****************************************************************************

	foreach age in age_bio {
		foreach sample in divorced0 divorced1 {
			
		* Open Data *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1") 
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr


		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
		}
	}
	
	****************************************************************************
	** baseline -- divorce group -- seperate **
	****************************************************************************

	foreach age in age_bio{
	foreach sample in divorced_group0 divorced_group1 divorced_group2 divorced_group3 {
		
		* Open Data *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	****************************************************************************
	** baseline -- divorce group 2 **
	****************************************************************************
	**************
	** Seperate **
	**************
	foreach age in age_bio{
	foreach sample in divorced_group0_2 divorced_group1_2 divorced_group2_2 {
		
		* Open Data *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	**************
	** Together **
	**************

	foreach age in age_bio {
		
		* Append Data for every event *	
		use "$datawork/mp_penalty_yearly_divorced_group0_2_MEGPT_work_m1_controlchildtime_`age'", replace
		append using "$datawork/mp_penalty_yearly_divorced_group1_2_MEGPT_work_m1_controlchildtime_`age'"
		append using "$datawork/mp_penalty_yearly_divorced_group2_2_MEGPT_work_m1_controlchildtime_`age'"

								

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime if sample=="divorced_group0_2", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="divorced_group0_2", fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime if sample=="divorced_group0_2", lcolor(orange) lpattern(solid) lwidth(medthick) || 
			line gap_m1women eventtime if sample=="divorced_group0_2", lcolor(navy) lpattern(solid) lwidth(medthick) ||
			rarea boundL_m1men boundH_m1men eventtime if sample=="divorced_group1_2", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="divorced_group1_2", fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime if sample=="divorced_group1_2", lcolor(orange) lpattern(dash_dot) lwidth(medthick) || 
			line gap_m1women eventtime if sample=="divorced_group1_2", lcolor(navy) lpattern(dash_dot) lwidth(medthick) ||
			rarea boundL_m1men boundH_m1men eventtime if sample=="divorced_group2_2", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="divorced_group2_2", fcolor(navy%20) lwidth(none) || 
			line gap_m1men eventtime if sample=="divorced_group2_2", lcolor(orange) lpattern(shortdash) lwidth(medthick) || 
			line gap_m1women eventtime if sample=="divorced_group2_2", lcolor(navy) lpattern(shortdash) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (months)") 
			ytitle("Earnings relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men - no divorced" 4 "Women - no divorce" 7 "Men - divorced" 8 "Women - divorced") col(2) region(lstyle(none) lcolor(white))) 
			;
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_marriage_divorcegroup2_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_marriage_divorcegroup2_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	
	
	****************************************************************************
	** baseline -- gender norms **
	****************************************************************************
	
	foreach age in age_bio {
	foreach sample in gender_progressive1_0 gender_progressive1_1 {
		
		* Open Data *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
		
		* Penalty 
		local penaltylength = (10 / 2) 
			sum penal_m1 if eventtime >= `penaltylength' 
			gen penalty=`r(mean)'*100
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connected gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.5, angle(0))
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	****************************************************************************
	** baseline -- education **
	****************************************************************************
	
	foreach age in age_bio {
	foreach sample in educationgroup_1 educationgroup_2 educationgroup_3 educationgroup_4 {
		
		* Open Data *	
		use "$datawork/mp_penalty_yearly_`sample'_MEGPT_work_m1_controlchildtime_`age'", replace
		
		* Penalty 
		local penaltylength = (10 / 2) 
			sum penal_m1 if eventtime >= `penaltylength' 
			gen penalty=`r(mean)'*100
								
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connected gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			ylabel(-0.6(0.2)0.5, angle(0))
			xtitle("Time relative to marriage (months)") 
			ytitle("`ytitle'")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white)))
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_MEGPT_work_controlchildtime_m1_`age'.pdf", replace
	}
	}
	
	****************************************************************************
	** baseline: east/west **
	****************************************************************************
	
	*****************************************
	** (1) first observation, (2) marriage **
	*****************************************
	foreach east in /*(1)*/ east_first /*(2)*/ east_marriage {
		foreach sample in /*all marriages*/ all /*only born pre, married post reunification*/ bornpre_marrpost {
			if "`sample'" == "all" {
				local name = ""
			}
			if "`sample'" == "bornpre_marrpost" {
				local name = "_bornpre_marrpost"
			}
			foreach age in age_bio age_labor age_bio_labor {
				use "$datawork/mp_penalty_yearly_`east'0`name'_MEGPT_work_m1_controlchildtime_`age'", clear /*0=east*/
				append using "$datawork/mp_penalty_yearly_`east'1`name'_MEGPT_work_m1_controlchildtime_`age'.dta" /*1=west*/
				
				* Graph *
				#delimit ; 
				twoway 
					/*east*/
					rarea boundL_m1men boundH_m1men eventtime if sample=="`east'1`name'", fcolor(orange%20) lwidth(none) || 
					rarea boundL_m1women boundH_m1women eventtime if sample=="`east'1`name'", fcolor(navy%20) lwidth(none) || 
					connected gap_m1men eventtime if sample=="`east'1`name'", lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
					connected gap_m1women eventtime if sample=="`east'1`name'", lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) ||
					/*west*/
					rarea boundL_m1men boundH_m1men eventtime if sample=="`east'0`name'", fcolor(orange%20) lwidth(none) || 
					rarea boundL_m1women boundH_m1women eventtime if sample=="`east'0`name'", fcolor(navy%20) lwidth(none) || 
					connected gap_m1men eventtime if sample=="`east'0`name'", lcolor(orange) lpattern(-) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
					connected gap_m1women eventtime if sample=="`east'0`name'", lcolor(navy) lpattern(-) lwidth(medthick) mcolor(navy) msymbol(Oh)
				, graphregion(color(white) lstyle(none)) 
					xline(-0.5, lcolor(cranberry)) 
					yline(0, lstyle(grid)) 
					xtitle("Time relative to marriage (years)") 
					ytitle("Earnings relative to t-12")  
					xlabel(-5(1)10) xscale(titlegap(1.5))
					ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
					legend(order(3 "Men - east" 4 "Women - east" 7 "Men - west" 8 "Women - west") col(2) region(lstyle(none) lcolor(white))) 
					;
				#delimit cr

				graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'.png", replace
				graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'.pdf", replace
			
	
	** for the version we have in the paper: plot east & west separately ** 
	local east = "east_first"
	local name = "_bornpre_marrpost"
	local age = "age_bio"

	use "$datawork/mp_penalty_yearly_`east'0`name'_MEGPT_work_m1_controlchildtime_`age'", clear /*0=east*/
	append using "$datawork/mp_penalty_yearly_`east'1`name'_MEGPT_work_m1_controlchildtime_`age'.dta" /*1=west*/
	
	* Graph -- east*
	#delimit ; 
	twoway 
		/*east*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="`east'1`name'", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="`east'1`name'", fcolor(navy%20) lwidth(none) || 
		connected gap_m1men eventtime if sample=="`east'1`name'", lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connected gap_m1women eventtime if sample=="`east'1`name'", lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Earnings relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.6, angle(0)) yscale(range(-0.7 0.7))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr
	graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'_east.png", replace
	graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'_east.pdf", replace
	
	* Graph -- west*
	#delimit ; 
	twoway 
		/*west*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="`east'0`name'", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="`east'0`name'", fcolor(navy%20) lwidth(none) || 
		connected gap_m1men eventtime if sample=="`east'0`name'", lcolor(orange) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connected gap_m1women eventtime if sample=="`east'0`name'", lcolor(navy) lwidth(medthick) mcolor(navy) msymbol(O)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Earnings relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.6, angle(0)) yscale(range(-0.7 0.7))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'_west.png", replace
	graph export "$graphs_soeprv/mp_`east'`name'_yearly_MEGPT_work_controlchildtime_`age'_west.pdf", replace
	
	} // age
	} // sample
	} // east
	
	
	****************************************************************************
	** baseline: Dezember Marriage **
	****************************************************************************
	
	***********************
	** Standard estimate **
	***********************
	foreach age in age_bio /*age_labor age_bio_labor*/ {
	
	* Data *
	use "$datawork/mp_penalty_yearly_decmarriage_0_MEGPT_work_m1_controlchildtime_`age'", clear 
	append using "$datawork/mp_penalty_yearly_decmarriage_1_MEGPT_work_m1_controlchildtime_`age'"	
	
	* Graph *
	#delimit ; 
	twoway 
		/*cohabitation start marriage*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="decmarriage_0", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="decmarriage_0", fcolor(navy%20) lwidth(none) || 
		line gap_m1men eventtime if sample=="decmarriage_0", lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gap_m1women eventtime if sample=="decmarriage_0", lcolor(navy) lpattern(solid) lwidth(medthick) ||
		/*cohabitation later*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="decmarriage_1", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="decmarriage_1", fcolor(navy%20) lwidth(none) || 
		line gap_m1men eventtime if sample=="decmarriage_1", lcolor(orange) lpattern(dash) lwidth(medthick) || 
		line gap_m1women eventtime if sample=="decmarriage_1", lcolor(navy) lpattern(dash) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Income (EP) relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		legend(order( - "Men" - "Women" 3 "Summer" 4 "Summer" 7 "December" 8 "December")
		colgap(vsmall) keygap(vsmall) just(center) col(2) size(small) 
		region(lstyle(none) lcolor(white))) 
		;
	#delimit cr
	.Graph.legend.plotregion1.move label[1] on 5 1
	.Graph.legend.plotregion1.move label[2] on 5 5
	.Graph.legend.plotregion1.label[2].style.editstyle box_alignment(center) editcopy
	.Graph.legend.plotregion1.label[2].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle box_alignment(center) editcopy
	.Graph.drawgraph

	graph export "$graphs_soeprv/mp_marriagemonth_yearly_MEGPT_work_controlchildtime_`age'.png", replace
	graph export "$graphs_soeprv/mp_marriagemonth_yearly_MEGPT_work_controlchildtime_`age'.pdf", replace
	}
	
	****************************************************************************
	** baseline: by cohabitation (Seperated by status 1 year before) **
	****************************************************************************
	
	***********************
	** Standard estimate **
	***********************
	foreach age in age_bio age_labor age_bio_labor {
	
	* Data *
	use "$datawork/mp_penalty_yearly_cohabitation_g1_MEGPT_work_m1_controlchildtime_`age'", clear 
	append using "$datawork/mp_penalty_yearly_cohabitation_g2_MEGPT_work_m1_controlchildtime_`age'"	
	
	* One - Graph *
	#delimit ; 
	twoway 
		/*cohabitation start marriage*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="cohabitation_g1", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="cohabitation_g1", fcolor(navy%20) lwidth(none) || 
		line gap_m1men eventtime if sample=="cohabitation_g1", lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gap_m1women eventtime if sample=="cohabitation_g1", lcolor(navy) lpattern(solid) lwidth(medthick) ||
		/*cohabitation later*/
		rarea boundL_m1men boundH_m1men eventtime if sample=="cohabitation_g2", fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime if sample=="cohabitation_g2", fcolor(navy%20) lwidth(none) || 
		line gap_m1men eventtime if sample=="cohabitation_g2", lcolor(orange) lpattern(dash) lwidth(medthick) || 
		line gap_m1women eventtime if sample=="cohabitation_g2", lcolor(navy) lpattern(dash) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Income (EP) relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.4, angle(0)) yscale(range(-0.7 0.25) titlegap(-10))
		legend(order( - "Men" - "Women" 3 "Live seperatly" 4 "Live seperatly" 7 "Cohabitation" 8 "Cohabitation")
		colgap(vsmall) keygap(vsmall) just(center) col(2) size(small) 
		region(lstyle(none) lcolor(white))) 
		;
	#delimit cr
	.Graph.legend.plotregion1.move label[1] on 5 1
	.Graph.legend.plotregion1.move label[2] on 5 5
	.Graph.legend.plotregion1.label[2].style.editstyle box_alignment(center) editcopy
	.Graph.legend.plotregion1.label[2].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle box_alignment(center) editcopy
	.Graph.drawgraph

	graph export "$graphs_soeprv/mp_cohabitation_combined_yearly_MEGPT_work_controlchildtime_`age'.png", replace
	graph export "$graphs_soeprv/mp_cohabitation_combined_yearly_MEGPT_work_controlchildtime_`age'.pdf", replace
	
	* Seperate - Graph *
	forval n=1/2 {
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime if sample=="cohabitation_g`n'", fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime if sample=="cohabitation_g`n'", fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime if sample=="cohabitation_g`n'", lcolor(orange) mcolor(orange) mlcolor(orange) lpattern(solid) lwidth(medthick) || 
			connect gap_m1women eventtime if sample=="cohabitation_g`n'", lcolor(navy) mcolor(navy) mlcolor(navy) lpattern(solid) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("Income (EP) relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.4, angle(0)) yscale(titlegap(-10))
			legend(order( 3 "Men" 4 "Women")
			colgap(vsmall) keygap(vsmall) just(center) col(2) size(small) 
			region(lstyle(none) lcolor(white))) 
			;
		#delimit cr
		graph export "$graphs_soeprv/mp_cohabitation_group`n'_yearly_MEGPT_work_controlchildtime_`age'.png", replace
		graph export "$graphs_soeprv/mp_cohabitation_group`n'_yearly_MEGPT_work_controlchildtime_`age'.pdf", replace
		}	//n
	}	//age
	
	*****************************
	** Absolute betas estimate **
	*****************************
	foreach age in age_bio age_labor age_bio_labor {
	
	* Data *
	use "$datawork/mp_penalty_yearly_cohabitation_g1_MEGPT_work_m1_controlchildtime_`age'", clear 
	append using "$datawork/mp_penalty_yearly_cohabitation_g2_MEGPT_work_m1_controlchildtime_`age'"	
	
	* Graph *
	#delimit ; 
	twoway 
		/*cohabitation start marriage*/
		rarea bL_m1men bH_m1men eventtime if sample=="cohabitation_g1", fcolor(orange%20) lwidth(none) || 
		rarea bL_m1women bH_m1women eventtime if sample=="cohabitation_g1", fcolor(navy%20) lwidth(none) || 
		line b_m1men eventtime if sample=="cohabitation_g1", lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line b_m1women eventtime if sample=="cohabitation_g1", lcolor(navy) lpattern(solid) lwidth(medthick) ||
		/*cohabitation later*/
		rarea bL_m1men bH_m1men eventtime if sample=="cohabitation_g2", fcolor(orange%20) lwidth(none) || 
		rarea bL_m1women bH_m1women eventtime if sample=="cohabitation_g2", fcolor(navy%20) lwidth(none) || 
		line b_m1men eventtime if sample=="cohabitation_g2", lcolor(orange) lpattern(dash) lwidth(medthick) || 
		line b_m1women eventtime if sample=="cohabitation_g2", lcolor(navy) lpattern(dash) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Income (EP) relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		/*ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))*/
		legend(order( - "Men" - "Women" 3 "At marriage" 4 "At marriage" 7 "+1 years before" 8 "+1 years before")
		colgap(vsmall) keygap(vsmall) just(center) col(2) size(small) 
		region(lstyle(none) lcolor(white))) 
		;
	#delimit cr
	.Graph.legend.plotregion1.move label[1] on 5 1
	.Graph.legend.plotregion1.move label[2] on 5 5
	.Graph.legend.plotregion1.label[2].style.editstyle box_alignment(center) editcopy
	.Graph.legend.plotregion1.label[2].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle size(small) editcopy
	.Graph.legend.plotregion1.label[1].style.editstyle box_alignment(center) editcopy
	.Graph.drawgraph

	graph export "$graphs_soeprv/mp_cohabitation_yearly_MEGPT_work_absolutbetas_controlchildtime_`age'.png", replace
	graph export "$graphs_soeprv/mp_cohabitation_yearly_MEGPT_work_absolutbetas_controlchildtime_`age'.pdf", replace
	}
	
	****************************************************************************
	** baseline: intensive margin **
	****************************************************************************
	
	use "$datawork/mp_penalty_yearly_only_intensive_MEGPT_work_m1_controlchildtime_age_bio", clear 
		
	* Graph *
	#delimit ; 
	twoway 
		rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
		connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to marriage (years)") 
		ytitle("Hours relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/mp_only_intensive_yearly_MEGPT_work_controlchildtime.png", replace
	graph export "$graphs_soeprv/mp_only_intensive_yearly_MEGPT_work_controlchildtime.pdf", replace
	
	
	****************************************************************************
	** baseline: hourly wages **
	****************************************************************************

	** admin data on income (hours from survey) **
	foreach sample in all only_intensive {
	foreach outcome in gross_hourly_y_2015EUR gross_hour_2015EURsoep {
	foreach age in age_bio {
		use "$datawork/mp_penalty_yearly_all_`outcome'_m1_controlchildtime_`age'", replace	

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("Hourly wage relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.3)0.9, angle(0)) yscale(range(-0.7 0.25))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_`outcome'_m1_controlchildtime_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_`outcome'_m1_controlchildtime_`age'.pdf", replace
	} // age
	} // outcome
	} // sample
	
	****************************************************************************
	** Decomposition Samples **
	****************************************************************************
	** admin data on income (hours from survey) **
	foreach var in wd /*weekly*/ {
	foreach outcome in MEGPT_work dummy_work gross_hourly_y labour_`var'_hours {
	foreach age in age_bio {
		
		if inlist("`outcome'", "MEGPT_work", "dummy_work") local sample "decomposition"
		if !inlist("`outcome'", "MEGPT_work", "dummy_work") local sample "decomposition_only_intensive"
		if "`outcome'" == "MEGPT_work" local ytitle "Income (EP)"
		if "`outcome'" == "dummy_work" local ytitle "Share working"
		if "`outcome'" == "labour_`var'_hours" local ytitle "Hours"
		if "`outcome'" == "gross_hourly_y" local ytitle "Hourly wage"
		
		use "$datawork/mp_penalty_yearly_`sample'_var`var'_`outcome'_m1_controlchildtime_`age'", replace	

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("`ytitle' relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.4(0.2)0.7, angle(0))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_var`var'_yearly_`outcome'_m1_controlchildtime_`age'.png", replace
		graph export "$graphs_soeprv/mp_`sample'_var`var'_yearly_`outcome'_m1_controlchildtime_`age'.pdf", replace
	} // age
	} // outcome
	} // var
	
	****************************************************************************
	** baseline: time use **
	****************************************************************************
		
	**************************
	* hours worked by gender *
	**************************
	** with & w/o education **
	foreach sample in only_intensive {
	foreach outcome in labourwork_wd_hours labour_wd_hours {
		
		use "$datawork/mp_penalty_yearly_`sample'_`outcome'_m1_controlchildtime_age_bio.dta", clear 
		* Penalty *
		local penaltylength = 10 / 2
			quietly sum penal if eventtime >= `penaltylength'	
			local m1 = r(mean)
		gen penalty = `m1'*100
		format penalty %9.1fc
		tostring penalty, replace force usedisplayformat
		local penalty = penalty

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to Marriages (Years)") 
			ytitle("Hours relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.1)0.2, angle(0))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_`sample'_yearly_`outcome'_m1_controlchildtime.png", replace
		graph export "$graphs_soeprv/mp_`sample'_yearly_`outcome'_m1_controlchildtime.pdf", replace
	}
	}

	******************************************
	** time use: paid labor vs unpaid labor **
	******************************************
	
	** each activity individually **
	foreach hours in labourwork_wd_hours labour_wd_hours housework_wd_hours carework_wd_hours unpaidwork_wd_hours {
		use "$datawork/mp_penalty_yearly_all_`hours'_m1_controlchildtime_age_bio", clear 
		
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_m1men boundH_m1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_m1women boundH_m1women eventtime, fcolor(navy%20) lwidth(none) || 
			connect gap_m1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connect gap_m1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("Hours relative to t-12")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/mp_all_yearly_hours_`hours'_m1_controlchildtime.png", replace
		graph export "$graphs_soeprv/mp_all_yearly_hours_`hours'_m1_controlchildtime.pdf", replace
	}
	
	** labor & household for women vs men **
	*labor*
	use "$datawork/mp_penalty_yearly_all_labour_wd_hours_m1_controlchildtime_age_bio", clear 
	rename * l_* 
	rename (l_eventtime l_sample l_outcome l_event) (eventtime sample outcome event)
	tempfile labour 
	save `labour', replace
	*household*
	use "$datawork/mp_penalty_yearly_all_housework_wd_hours_m1_controlchildtime_age_bio", clear 
	rename * h_* 
	rename (h_eventtime h_sample h_outcome h_event) (eventtime sample outcome event)
	*append both*
	append using `labour'
	
	foreach sex in women men {
		if "`sex'" == "women" {
			local color = "navy"
		}
		if "`sex'" == "men" {
			local color = "orange"
		}
		#delimit ; 
		twoway 
			rarea l_boundL_m1`sex' l_boundH_m1`sex' eventtime, fcolor(`color'%20) lwidth(none) || 
			rarea h_boundL_m1`sex' h_boundH_m1`sex' eventtime, fcolor(`color'%20) lwidth(none) || 
			connect l_gap_m1`sex' eventtime, lcolor(`color') lpattern(solid) lwidth(medthick) mcolor(`color') msymbol(O) || 
			connect h_gap_m1`sex' eventtime, lcolor(`color') lpattern(-) lwidth(medthick) mcolor(`color') msymbol(Oh)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("Hours relative to t-12")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.3))
			legend(order(3 "Paid work labor market" 4 "Unpaid work household") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr
		
		graph export "$graphs_soeprv/mp_all_yearly_hours_labour_household_`sex'_m1_controlchildtime.png", replace
		graph export "$graphs_soeprv/mp_all_yearly_hours_labour_household_`sex'_m1_controlchildtime.pdf", replace

	}
	
	

	****************************************************************************
	** baseline: Time use only intensive margin sample **
	****************************************************************************
	
	** labor & household for women vs men **
	*labor*
	use "$datawork/mp_penalty_yearly_only_intensive_labour_wd_hours_m1_controlchildtime_age_bio", clear 
	rename * l_* 
	rename (l_eventtime l_sample l_outcome l_event) (eventtime sample outcome event)
	tempfile labour 
	save `labour', replace
	*household*
	use "$datawork/mp_penalty_yearly_only_intensive_housework_wd_hours_m1_controlchildtime_age_bio", clear 
	rename * h_* 
	rename (h_eventtime h_sample h_outcome h_event) (eventtime sample outcome event)
	*append both*
	append using `labour'
	
	
	* Point estimates *
	local penaltylength = (10 / 2) 
	foreach sex in men women {
	foreach j in h l {
		sum `j'_gap_m1`sex' if eventtime >= `penaltylength' 
		gen ps_`j'_`sex'=`r(mean)'*100
		sum `j'_b_m1`sex' if eventtime >= `penaltylength' 
		gen ps_abs_`j'_`sex'=`r(mean)'
		
	}	
	}
	
	foreach sex in women men {
		if "`sex'" == "women" {
			local color = "navy"
		}
		if "`sex'" == "men" {
			local color = "orange"
		}
		
		#delimit ; 
		twoway 
			rarea l_boundL_m1`sex' l_boundH_m1`sex' eventtime, fcolor(`color'%20) lwidth(none) || 
			rarea h_boundL_m1`sex' h_boundH_m1`sex' eventtime, fcolor(`color'%20) lwidth(none) || 
			connect l_gap_m1`sex' eventtime, lcolor(`color') lpattern(solid) lwidth(medthick) mcolor(`color') msymbol(O) || 
			connect h_gap_m1`sex' eventtime, lcolor(`color') lpattern(-) lwidth(medthick) mcolor(`color') msymbol(Oh)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to marriage (years)") 
			ytitle("Hours relative to t-12")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-0.6(0.2)0.4, angle(0)) yscale(range(-0.65 0.45))
			legend(order(3 "Paid work labor market" 4 "Unpaid work household") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr
		
		graph export "$graphs_soeprv/mp_only_intensive_yearly_hours_labour_household_`sex'_m1_controlchildtime.png", replace
		graph export "$graphs_soeprv/mp_only_intensive_yearly_hours_labour_household_`sex'_m1_controlchildtime.pdf", replace

	}
	
********************************************************************************
** Child Penalty Graphs **
********************************************************************************

*************
* By Gender *
*************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
		
	use "$datawork/cp_penalty_all_`outcome'.dta", clear 

	* Penalty *
	local penaltylength = 120 / 2
		quietly sum penal if eventtime >= `penaltylength'	
		local m1 = r(mean)
	gen penalty = `m1'*100
	format penalty %9.1fc
	tostring penalty, replace force usedisplayformat
	local penalty = penalty

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	* Graph *
	#delimit ; 
	twoway 
		rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
		line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		ylabel(-1(0.2)0.6, angle(0)) yscale(range(-1 0.6))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/cp_all_`outcome'.png", replace
	graph export "$graphs_soeprv/cp_all_`outcome'.pdf", replace
}

******************************
* By Gender & Marital Status *
******************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
		
	use "$datawork/cp_penalty_notmarried_`outcome'.dta", clear 
	append using "$datawork/cp_penalty_married_`outcome'.dta" 

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	egen penalty1 = mean(penal) if sample=="notmarried"
		ereplace penalty1=mean(penalty1)
		replace penalty1=penalty1*100
		format penalty1 %9.1fc
		tostring penalty1, replace force usedisplayformat 
		
	egen penalty2 = mean(penal) if sample=="married"
		ereplace penalty2=mean(penalty2)
		replace penalty2=penalty2*100
		format penalty2 %9.1fc
		tostring penalty2, replace force usedisplayformat 
		
	local penalty1 = penalty1	
	local penalty2 = penalty2
		
	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="notmarried", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="notmarried", fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime if sample=="married", 	fcolor(navy%25) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="married", 	fcolor(orange%25) lwidth(none) ||
		line gapwomen eventtime if sample=="notmarried", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
		line gapmen   eventtime if sample=="notmarried", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
		line gapwomen eventtime if sample=="married", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="married", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(-1(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		xtitle("Time relative to childbirth (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		legend(order(5 "Women: Not Married" 6 "Men: Not Married" 7 "Women: Married" 8 "Men: Married") 
		col(2) symx(3pt) size(medsmall) region(lstyle(none) lcolor(white) margin(vsmall)))
		ttext(-0.8 -61 
			"{it:Longterm Gap: }"
			"{it:Not Married} = `penalty1'%" 
			"{it:Married at Childb.} = `penalty2'%", 
			justification(left) size(small) placement(ne));
	#delimit cr
		
	graph export "$graphs_soeprv/cp_maritalstatus_`outcome'.png", replace
	graph export "$graphs_soeprv/cp_maritalstatus_`outcome'.pdf", replace
}

********************************************
* By Gender & Marital Status (no Singles)  *
********************************************
** income & dummy working **
foreach outcome in MEGPT_work dummy_work {
	use "$datawork/cp_penalty_notmarriednotsingle_`outcome'.dta", clear 
	append using "$datawork/cp_penalty_married_`outcome'.dta" 

	local penaltylength = (120 / 2) 
	bys sample (eventtime): ereplace penal = mean(penal) if eventtime >= `penaltylength' 
		replace penal = . if eventtime < `penaltylength' 
	egen penalty1 = mean(penal) if sample=="notmarriednotsingle"
		ereplace penalty1=mean(penalty1)
		replace penalty1=penalty1*100
		format penalty1 %9.1fc
		tostring penalty1, replace force usedisplayformat 
		
	egen penalty2 = mean(penal) if sample=="married"
		ereplace penalty2=mean(penalty2)
		replace penalty2=penalty2*100
		format penalty2 %9.1fc
		tostring penalty2, replace force usedisplayformat 
		
	local penalty1 = penalty1	
	local penalty2 = penalty2
		
	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	*Graph*	
	#delimit ; 
	twoway 
		rarea boundLwomen boundHwomen eventtime if sample=="notmarriednotsingle", fcolor(navy%20) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="notmarriednotsingle", fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime if sample=="married", 	fcolor(navy%25) lwidth(none) || 
		rarea boundLmen   boundHmen   eventtime if sample=="married", 	fcolor(orange%25) lwidth(none) ||
		line gapwomen eventtime if sample=="notmarriednotsingle", lcolor(navy) lpattern(shortdash) lwidth(medthick) || 
		line gapmen   eventtime if sample=="notmarriednotsingle", lcolor(orange) lpattern(shortdash) lwidth(medthick) ||
		line gapwomen eventtime if sample=="married", lcolor(navy) lpattern(solid) lwidth(medthick) || 
		line gapmen   eventtime if sample=="married", lcolor(orange) lpattern(solid) lwidth(medthick)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		ylabel(-1(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
		xtitle("Time relative to childbirth (months)") 
		ytitle("`ytitle'")  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		legend(order(5 "Women: Not Married" 6 "Men: Not Married" 7 "Women: Married" 8 "Men: Married") 
		col(2) symx(3pt) size(medsmall) region(lstyle(none) lcolor(white) margin(vsmall)))
		ttext(-0.8 -61 
			"{it:Longterm Gap: }"
			"{it:Not Married} = `penalty1'%" 
			"{it:Married at Childb.} = `penalty2'%", 
			justification(left) size(small) placement(ne));
	#delimit cr
		
	graph export "$graphs_soeprv/cp_maritalstatus_nosingles_`outcome'.png", replace
	graph export "$graphs_soeprv/cp_maritalstatus_nosingles_`outcome'.pdf", replace
}

	
	************************************
	* CP by Gender yearly - Work Hours *
	************************************
	** with & w/o education **
	foreach outcome in labourwork_wd_hours labour_wd_hours {
	foreach sample in only_intensive {
		
		use "$datawork/cp_penalty_yearly_all_`outcome'.dta", clear 

		* Penalty *
		local penaltylength = 10 / 2
			quietly sum penal if eventtime >= `penaltylength'	
			local m1 = r(mean)
		gen penalty = `m1'*100
		format penalty %9.1fc
		tostring penalty, replace force usedisplayformat
		local penalty = penalty

		* Graph *
		#delimit ; 
		twoway 
			rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
			line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick)  || 
			line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle("Hours relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-1(0.2)0.6, angle(0))
			yscale(r(-1 0.6))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'.png", replace
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'.pdf", replace
	} // outcome 
	} // sample

	**************************************
	* CP by Gender yearly - hourly wages *
	**************************************
	** admin data on income (hours from survey) **
	foreach outcome in gross_hourly_y_2015EUR /*earnings from VSKT*/ gross_hour_2015EURsoep /*earnings from SOEP*/ {
	foreach sample in only_intensive {
		
		use "$datawork/cp_penalty_yearly_`sample'_`outcome'.dta", clear 
		
		* Graph *
		#delimit ; 
		twoway 
			rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
			line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick)  || 
			line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle("Hourly wage relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-1(0.2)0.6, angle(0))
			yscale(r(-1 0.6))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr
		
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'.png", replace
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'.pdf", replace
		
	} // outcome
	} // sample


	
********************************************************************************
** Joint Child and Marriage Graphs **
********************************************************************************
	
foreach outcome in MEGPT_work dummy_work {
		
	******************
	** open dataset ** 
	******************
	*naive estimation*
	use "$datawork/cp_penalty_all_`outcome'.dta", clear  
	rename * naive_* /*rename all vars so we can diff both estimations*/
	*control marriagetime*
	append using "$datawork/cp_penalty_all_`outcome'_controlmarriagetime"
		
	** locals etc. for different estimates ** 

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Earnings relative to t-12"
	}
	if "`outcome'" == "dummy_work" {
		local ytitle = "Share working relative to t-12"
	}
	
	/*compute coefficient bounds for abs estimate (b/c we don't take them from estimation sample)*/
	foreach sex in women men {
		gen naive_var_p`sex'= naive_var_c`sex' + naive_b`sex'
		gen var_p`sex'= var_c`sex' + b_c`sex'
		foreach bound in H L { 
			gen naive_var_c`bound'`sex' = naive_var_p`sex' - naive_bound`bound'`sex'*naive_var_c`sex'
			gen var_c`bound'`sex' = var_p`sex' - bound`bound'`sex'*var_c`sex'
			gen naive_b`bound'`sex' = naive_var_p`sex' - naive_var_c`bound'`sex'
			gen b`bound'`sex' = var_p`sex' - var_c`bound'`sex'
		} // bound
	} // sex

	** EUR values for outcome == earnings ** 
	local name = "_2015EUR"
	local name_file = "_abs_2015EUR"
	foreach sex in women men {
		foreach var in b_c`sex' bL`sex' bH`sex' naive_b`sex' naive_bL`sex' naive_bH`sex' {
			gen `var'_2015EUR = `var' * 35363
		} // var
	}	//sex

	*************
	** Penalty **
	*************
	local penaltylength = 120 / 2
	*naive estimation & control childtime*
	foreach specification in naive childtime { 
		if "`specification'" == "naive" {
			local pre = "naive_" 
		}
		if "`specification'" == "childtime" {
			local pre = "" 
		}
		
		quietly sum `pre'penal if `pre'eventtime >= `penaltylength'	
		local m1 = r(mean)
		gen `pre'penalty = `m1'*100
		format `pre'penalty %9.1fc
	}
	
	*Absolute change 
	foreach sex in women men {
		quietly sum b_c`sex'_2015EUR if eventtime >= `penaltylength'	
		gen change_abs_`sex' = `m1'
		format `pre'penalty %9.0fc
		quietly sum naive_b`sex' if naive_eventtime >= `penaltylength'	
		gen naive_change_abs_`sex' = `m1'
		format `pre'penalty %9.0fc
		
		*gen abs_penalty_`sex'=
	}
		
	*****************
	** plot graphs ** 
	*****************

	* Graph -- control childtime *
	#delimit ; 
	twoway 
		/*control childtime*/
		rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
		line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (months)") 
		ytitle(`ytitle')  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		ylabel(-1(0.2)0.6, angle(0)) yscale(r(-1(0.2)0.6))
		legend(order(3 "Men" 4 "Women") 
					 col(2) region(lstyle(none) lcolor(white)) size(small)) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_all_`outcome'_controlmarriagetime.png", replace
	graph export "$graphs_soeprv/cp_all_`outcome'_controlmarriagetime.pdf", replace
	
	* Graph -- naive + control childtime *
	#delimit ; 
	twoway 
		/*naive*/
		rarea naive_boundLmen naive_boundHmen naive_eventtime, fcolor(orange%20) lwidth(none) || 
		rarea naive_boundLwomen naive_boundHwomen naive_eventtime, fcolor(navy%20) lwidth(none) || 
		line naive_gapmen naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) || 
		line naive_gapwomen naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) ||
		/*control childtime*/
		rarea boundLmen boundHmen eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundLwomen boundHwomen eventtime, fcolor(navy%20) lwidth(none) || 
		line gapmen eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line gapwomen eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (months)") 
		ytitle(`ytitle')  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		ylabel(`ylabel', angle(0)) /*yscale(`yscale')*/
		legend(order(3 "Men - naive" 4 "Women - naive"
					 7 "Men - account for marriage" 8 "Women - account for marriage") 
					 col(2) region(lstyle(none) lcolor(white)) size(small)) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_all_`outcome'_naive_controlmarriagetime_2.png", replace
	graph export "$graphs_soeprv/cp_all_`outcome'_naive_controlmarriagetime_2.pdf", replace

	* Graph -- naive + control childtime ABSOLUT*
	#delimit ; 
	twoway 
		/*naive*/
		rarea naive_bLmen_2015EUR naive_bHmen_2015EUR naive_eventtime, fcolor(orange%20) lwidth(none) || 
		rarea naive_bLwomen_2015EUR naive_bHwomen_2015EUR naive_eventtime, fcolor(navy%20) lwidth(none) || 
		line naive_bmen_2015EUR naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) || 
		line naive_bwomen_2015EUR naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) ||
		/*control childtime*/
		rarea bLmen_2015EUR bHmen_2015EUR eventtime, fcolor(orange%20) lwidth(none) || 
		rarea bLwomen_2015EUR bHwomen_2015EUR eventtime, fcolor(navy%20) lwidth(none) || 
		line b_cmen_2015EUR eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) || 
		line b_cwomen_2015EUR eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (months)") 
		ytitle(`ytitle')  
		xlabel(-60(12)120) xscale(titlegap(1.5))
		ylabel(, angle(0)) /*yscale()*/
		legend(order(3 "Men - naive" 4 "Women - naive"
					 7 "Men - account for marriage" 8 "Women - account for marriage") 
					 col(2) region(lstyle(none) lcolor(white)) size(small)) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_all_`outcome'_naive_controlmarriagetime_abs_2015EUR.png", replace
	graph export "$graphs_soeprv/cp_all_`outcome'_naive_controlmarriagetime_abs_2015EUR.pdf", replace

} // outcome
	
********************************************************************************
** Joint Child and Marriage Graphs -- Yearly **
********************************************************************************
	
foreach outcome in MEGPT_work dummy_work {
		
	******************
	** open dataset ** 
	******************
	*naive estimation*
	use "$datawork/cp_penalty_yearly_all_`outcome'.dta", clear  
	rename *women *_c1women /*naming convention to match the other dataset we merge in the next step*/
	foreach pre in c p L H b /*need to add this because otherwise we change woMEN variables as well*/ {
		rename *`pre'men *`pre'_c1men 
	}
	rename penal penal_c1
	rename * naive_* /*rename all vars so we can diff both estimations*/
	*control marriagetime*
	append using "$datawork/cp_penalty_yearly_all_`outcome'_c1_controlmarriagetime"
		
	** locals etc. for different estimates ** 

	*outcome specific locals*
	if "`outcome'" == "MEGPT_work" {
		local ytitle = "Absolute child penalty"

		** EUR values for outcome == earnings ** 
		local name = "_2015EUR"
		local name_file = "_abs_2015EUR"
		foreach sex in women men {
			foreach var in b_c1`sex' bL_c1`sex' bH_c1`sex' naive_b_c1`sex' naive_bL_c1`sex' naive_bH_c1`sex' {
				gen `var'_2015EUR = `var' * 35363 * 12
			} // var
		}	//sex
	}
	
	if "`outcome'" == "dummy_work" {
		local ytitle = "Relative child penalty"
	}
	
	*************
	** Penalty **
	*************
	local penaltylength = 120 / 2
	*naive estimation & control childtime*
	foreach specification in naive childtime { 
		if "`specification'" == "naive" {
			local pre = "naive_" 
		}
		if "`specification'" == "childtime" {
			local pre = "" 
		}
		
		quietly sum `pre'penal_c1 if `pre'eventtime >= `penaltylength'	
		local m1 = r(mean)
		gen `pre'penalty_c1 = `m1'*100
		format `pre'penalty_c1 %9.1fc
	}
		
	*****************
	** plot graphs ** 
	*****************

	* Graph -- control childtime *
	#delimit ; 
	twoway 
		/*control childtime*/
		rarea boundL_c1men boundH_c1men eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundL_c1women boundH_c1women eventtime, fcolor(navy%20) lwidth(none) || 
		connected gap_c1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connected gap_c1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (years)") 
		ytitle(`ytitle')  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-1(0.2)0.2, angle(0))
		legend(order(3 "Men" 4 "Women") 
					 col(2) region(lstyle(none) lcolor(white)) size(small)) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime.png", replace
	graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime.pdf", replace
	
	* Graph -- naive + control childtime *
	#delimit ; 
	twoway 
		/*naive*/
		rarea naive_boundL_c1men naive_boundH_c1men naive_eventtime, fcolor(orange%20) lwidth(none) || 
		rarea naive_boundL_c1women naive_boundH_c1women naive_eventtime, fcolor(navy%20) lwidth(none) || 
		connected naive_gap_c1men naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
		connected naive_gap_c1women naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) mcolor(navy) msymbol(Oh) ||
		/*control childtime*/
		rarea boundL_c1men boundH_c1men eventtime, fcolor(orange%20) lwidth(none) || 
		rarea boundL_c1women boundH_c1women eventtime, fcolor(navy%20) lwidth(none) || 
		connected gap_c1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connected gap_c1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) 
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (years)") 
		ytitle(`ytitle')  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		ylabel(-1(0.2)0.2, angle(0)) /*yscale(`yscale')*/
		legend(order(3 "Men - naive" 4 "Women - naive"
					 7 "Men - account for marriage" 8 "Women - account for marriage") 
					 col(2) region(lstyle(none) lcolor(white)) size(small)) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_2.png", replace
	graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_2.pdf", replace

	* Graph -- naive + control childtime ABSOLUT*
	if "`outcome'" == "MEGPT_work" {
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_bL_c1men_2015EUR naive_bH_c1men_2015EUR naive_eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_bL_c1women_2015EUR naive_bH_c1women_2015EUR naive_eventtime, fcolor(navy%20) lwidth(none) || 
			connected naive_b_c1men_2015EUR naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
			connected naive_b_c1women_2015EUR naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) mcolor(navy) msymbol(Oh) ||
			/*control childtime*/
			rarea bL_c1men_2015EUR bH_c1men_2015EUR eventtime, fcolor(orange%20) lwidth(none) || 
			rarea bL_c1women_2015EUR bH_c1women_2015EUR eventtime, fcolor(navy%20) lwidth(none) || 
			connected b_c1men_2015EUR eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected b_c1women_2015EUR eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle(`ytitle')  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-20000(5000)5000, angle(0) format(%9.0fc)) /*yscale()*/
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for marriage" 8 "Women - account for marriage") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr
		graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_abs_2015EUR_2.png", replace
		graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_abs_2015EUR_2.pdf", replace
	}
	if "`outcome'" == "dummy_work" {
		#delimit ; 
		twoway 
			/*naive*/
			rarea naive_bL_c1men naive_bH_c1men naive_eventtime, fcolor(orange%20) lwidth(none) || 
			rarea naive_bL_c1women naive_bH_c1women naive_eventtime, fcolor(navy%20) lwidth(none) || 
			connected naive_b_c1men naive_eventtime, lcolor(orange) lpattern(_) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
			connected naive_b_c1women naive_eventtime, lcolor(navy) lpattern(_) lwidth(medthick) mcolor(navy) msymbol(Oh) ||
			/*control childtime*/
			rarea bL_c1men bH_c1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea bL_c1women bH_c1women eventtime, fcolor(navy%20) lwidth(none) || 
			connected b_c1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected b_c1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle(`ytitle')  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-1(0.2)0.2, angle(0) format(%9.1fc)) /*yscale()*/
			legend(order(3 "Men - naive" 4 "Women - naive"
						 7 "Men - account for marriage" 8 "Women - account for marriage") 
						 col(2) region(lstyle(none) lcolor(white)) size(small)) 
			;
		#delimit cr
		graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_abs_2.png", replace
		graph export "$graphs_soeprv/cp_yearly_all_`outcome'_controlmarriagetime_abs_2.pdf", replace
	}
	
} // outcome

	
	*************************************************
	** East/West (1) all, (2) born pre, child post **
	*************************************************
	
	foreach sample in /*(1) all childbirths*/ all /* (2) only born pre, childbirth post reunification*/ bornpre_childpost {
		if "`sample'" == "all" local name = ""
		if "`sample'" == "bornpre_marrpost" local name = "bornpre_childpost"
		
			use "$datawork/cp_penalty_yearly_east_first0`name'_MEGPT_work_c1_controlmarriagetime", clear /*0=east*/
			append using "$datawork/cp_penalty_yearly_east_first1`name'_MEGPT_work_c1_controlmarriagetime.dta" /*1=west*/
			
			* Graph *
			#delimit ; 
			twoway 
				/*east*/
				rarea boundL_c1men boundH_c1men eventtime if sample=="east_first1`name'", fcolor(orange%20) lwidth(none) || 
				rarea boundL_c1women boundH_c1women eventtime if sample=="east_first1`name'", fcolor(navy%20) lwidth(none) || 
				connected gap_c1men eventtime if sample=="east_first1`name'", lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
				connected gap_c1women eventtime if sample=="east_first1`name'", lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O) ||
				/*west*/
				rarea boundL_c1men boundH_c1men eventtime if sample=="east_first0`name'", fcolor(orange%20) lwidth(none) || 
				rarea boundL_c1women boundH_c1women eventtime if sample=="east_first0`name'", fcolor(navy%20) lwidth(none) || 
				connected gap_c1men eventtime if sample=="east_first0`name'", lcolor(orange) lpattern(-) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
				connected gap_c1women eventtime if sample=="east_first0`name'", lcolor(navy) lpattern(-) lwidth(medthick) mcolor(navy) msymbol(Oh)
			, graphregion(color(white) lstyle(none)) 
				xline(-0.5, lcolor(cranberry)) 
				yline(0, lstyle(grid)) 
				xtitle("Time relative to childbirth (years)") 
				ytitle("Earnings relative to t-12")  
				xlabel(-5(1)10) xscale(titlegap(1.5))
				ylabel(-0.6(0.2)0.2, angle(0)) yscale(range(-0.7 0.25))
				legend(order(3 "Men - east" 4 "Women - east" 7 "Men - west" 8 "Women - west") col(2) region(lstyle(none) lcolor(white))) 
				;
			#delimit cr

			graph export "$graphs_soeprv/cp_east_first`name'_yearly_MEGPT_work_controlmarriagetime.png", replace
			graph export "$graphs_soeprv/cp_east_first`name'_yearly_MEGPT_work_controlmarriagetime.pdf", replace
	} // sample

	
	** for the version we have in the paper: plot east & west separately **
	use "$datawork/cp_penalty_yearly_east_first0_bornpre_childpost_MEGPT_work_c1_controlmarriagetime", clear /*0=east*/
	append using "$datawork/cp_penalty_yearly_east_first1_bornpre_childpost_MEGPT_work_c1_controlmarriagetime.dta" /*1=west*/
	
	* Graph -- east*
	#delimit ; 
	twoway 
		/*east*/
		rarea boundL_c1men boundH_c1men eventtime if sample=="east_first1_bornpre_childpost", fcolor(orange%20) lwidth(none) || 
		rarea boundL_c1women boundH_c1women eventtime if sample=="east_first1_bornpre_childpost", fcolor(navy%20) lwidth(none) || 
		connected gap_c1men eventtime if sample=="east_first1_bornpre_childpost", lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
		connected gap_c1women eventtime if sample=="east_first1_bornpre_childpost", lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)  
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (years)") 
		ytitle("Earnings relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		yscale(titlegap(*-30))
		ylabel(-0.8(0.2)0.2, angle(0))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr
	graph export "$graphs_soeprv/cp_east_first_bornpre_childpost_yearly_MEGPT_work_controlmarriagetime_east.png", replace
	graph export "$graphs_soeprv/cp_east_first_bornpre_childpost_yearly_MEGPT_work_controlmarriagetime_east.pdf", replace
	
	* Graph -- west*
	#delimit ; 
	twoway 
		/*west*/
		rarea boundL_c1men boundH_c1men eventtime if sample=="east_first0_bornpre_childpost", fcolor(orange%20) lwidth(none) || 
		rarea boundL_c1women boundH_c1women eventtime if sample=="east_first0_bornpre_childpost", fcolor(navy%20) lwidth(none) || 
		connected gap_c1men eventtime if sample=="east_first0_bornpre_childpost", lcolor(orange) lpattern(-) lwidth(medthick) mcolor(orange) msymbol(Oh) || 
		connected gap_c1women eventtime if sample=="east_first0_bornpre_childpost", lcolor(navy) lpattern(-) lwidth(medthick) mcolor(navy) msymbol(Oh)
	, graphregion(color(white) lstyle(none)) 
		xline(-0.5, lcolor(cranberry)) 
		yline(0, lstyle(grid)) 
		xtitle("Time relative to childbirth (years)") 
		ytitle("Earnings relative to t-1")  
		xlabel(-5(1)10) xscale(titlegap(1.5))
		yscale(titlegap(*-30))
		ylabel(-0.8(0.2)0.2, angle(0))
		legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
		;
	#delimit cr

	graph export "$graphs_soeprv/cp_east_first_bornpre_childpost_yearly_MEGPT_work_controlmarriagetime_west.png", replace
	graph export "$graphs_soeprv/cp_east_first_bornpre_childpost_yearly_MEGPT_work_controlmarriagetime_west.pdf", replace
	
	
	************************************
	* CP by Gender yearly - Work Hours *
	************************************
	** with & w/o education **
	foreach outcome in labourwork_wd_hours labour_wd_hours {
	foreach sample in only_intensive {
		
		use "$datawork/cp_penalty_yearly_`sample'_`outcome'_c1_controlmarriagetime.dta", clear 
		* Penalty *
		local penaltylength = 10 / 2
			quietly sum penal if eventtime >= `penaltylength'	
			local m1 = r(mean)
		gen penalty = `m1'*100
		format penalty %9.1fc
		tostring penalty, replace force usedisplayformat
		local penalty = penalty

		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_c1men boundH_c1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_c1women boundH_c1women eventtime, fcolor(navy%20) lwidth(none) || 
			connected gap_c1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected gap_c1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle("Hours relative to t-12")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-1(0.2)0.6, angle(0))
			yscale(r(-1 0.6))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr

		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'_controlmarriagetime.png", replace
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'_controlmarriagetime.pdf", replace
	} // outcome 
	} // sample

	**************************************
	* CP by Gender yearly - hourly wages *
	**************************************
	foreach outcome in gross_hourly_y_2015EUR /*earnings from VSKT*/ gross_hour_2015EURsoep /*earnings from SOEP*/ {
	foreach sample in only_intensive {
		
		use "$datawork/cp_penalty_yearly_`sample'_`outcome'_c1_controlmarriagetime.dta", clear 
		
		* Graph *
		#delimit ; 
		twoway 
			rarea boundL_c1men boundH_c1men eventtime, fcolor(orange%20) lwidth(none) || 
			rarea boundL_c1women boundH_c1women eventtime, fcolor(navy%20) lwidth(none) || 
			connected gap_c1men eventtime, lcolor(orange) lpattern(solid) lwidth(medthick) mcolor(orange) msymbol(O) || 
			connected gap_c1women eventtime, lcolor(navy) lpattern(solid) lwidth(medthick) mcolor(navy) msymbol(O)
		, graphregion(color(white) lstyle(none)) 
			xline(-0.5, lcolor(cranberry)) 
			yline(0, lstyle(grid)) 
			xtitle("Time relative to childbirth (years)") 
			ytitle("Hourly wage relative to t-1")  
			xlabel(-5(1)10) xscale(titlegap(1.5))
			ylabel(-1(0.2)0.6, angle(0))
			yscale(r(-1 0.6))
			legend(order(3 "Men" 4 "Women") col(2) region(lstyle(none) lcolor(white))) 
			;
		#delimit cr
		
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'_controlmarriagetime.png", replace
		graph export "$graphs_soeprv/cp_`sample'_yearly_`outcome'_controlmarriagetime.pdf", replace
		
	} // outcome
	} // sample
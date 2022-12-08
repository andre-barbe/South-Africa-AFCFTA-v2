*********************
*This is the STATA do file that actually does all the data cleaning and aggregation


**# Paths
* Input Folder path for CSV
	global input_data_dir "C:\Users\Wb582332\OneDrive - WBG\Sharepoint\Projects\AfCFTA\AfCFTA v2 Results\CSV from AfCFTAtest"
* Output excel file
* This line needs to be modified when changing countries. Currently set to South Africa
	global output_data_file "C:\Modeling\South-Africa-AFCFTA-v2\Excel-CGE-Results-South-Africa.xlsx"

* List of simulations to keep
*Need to use ` before and ' after expression to tell STATA that this local contains quotes
*See https://www.stata.com/statalist/archive/2013-03/msg01071.html
*AfCFTAR          = AfCFTA Trade
*AfCFTAsavpta = AfCFTA Broad
*BaU                  = Baseline
*AfCFTAsavtcst = AfCFTA Deep
local sims_to_keep `""BaU","AfCFTAR","AfCFTARsavpta","AfCFTARsavtcst""'

*List of year to used
local year_to_keep 2035

*region_to_keep_in_giddlab
* specify region of country I'm looking at ZAF is South Africa
local region_to_keep_in_giddlab "ZAF"

*Aggregation options
local flag_agg_region=0

*Options for only running part of file, for debugging
local run_output_data_part 1
local run_bilat_data_part 1
local run_giddlab_data_part 1


********************************************************************************
*Trade.csv and Output.csv
********************************************************************************
if `run_output_data_part'==1 {
*Rename export and import tax
tempfile temp
import delimited "$input_data_dir\Trade.csv", clear
replace var="mtax_trd" if var=="mtax"
replace var="etax_trd" if var=="etax"
save `temp', replace

*rename activities to commodities
import delimited "$input_data_dir\Output.csv", clear
gen commodity=substr(activit,1,4)
replace commodity=subinstr(commodity,"-","",1)
replace commodity=commodity+"-c"
drop activity
append using `temp'
save `temp', replace

*Create total commodity from gdpop file
import delimited "$input_data_dir\gdppop.csv", clear
gen commodity="ttot-c"
append using `temp'

*Keep data only for specified simulations
keep if inlist(sim, `sims_to_keep')

rename value v
drop if year<2018
save `temp', replace

**********************
**Sector aggregation
**********************
* I am no longer doing sectoral aggregation so this is very simple

*Define com2
gen com2=commodity

*Collapse commodities into assigned aggregated commodities
collapse (sum) v, by( var sim region year com2)
rename com2 commodity


**********************
**Unit test to check if double counting after sectoral aggregation
**********************

*Count number of entries. This should be 1
count if sim=="BaU" & year==`year_to_keep' & var=="xp" & commodity=="AGR-c" & region=="BFA"

*Save count result to a scalar
scalar test_count = r(N)

*Deletes the data set if fails unit test
*need to use "=" before scalars as described in https://stackoverflow.com/questions/27515636/using-scalar-value-in-stata
if `=test_count'!=1 {
    clear
    display "Error: unit test 1 failed"
    exit
}


**********************
**Regional Aggregation
**********************

**** Disabled regional aggregation in this version at Maryla's request
***** Define regional aggregation************************
if `flag_agg_region'==1 {
    foreach var in region {
        replace `var'="XLC" if inlist(`var',"BRA","MEX")
        *replace `var'="XSA" if inlist(`var',"IND")
        replace `var'="XEA" if inlist(`var',"MYS","PHL","THA","VNM")

        *Andre modifies `var' variable replacement
        //ZAF is no longer aggregated with rest of XSS
        *replace `var'="XSS" if inlist(`var',"ZAF","NGA","RWA")
        replace `var'="SSA" if inlist(`var',"NGA","RWA","XEC") //XEC is rest of East Africa

        //TUR is now lumped in with rest of middle east. I checked in the excel to check that XMN is the right `var'
        //It is ok to add `var's to an aggregated `var', the collapse takes care of that
        replace `var' ="XEC" if inlist(`var', "TUR")
        *end modified by Andre

        //Middle East has Egypt
        replace `var' ="XMN" if inlist(`var', "EGY")

        //South Asia has Indonesia
        replace `var'="XSA" if inlist(`var',"IDN")

        //do not use ROW region as that causes problems
    }
}



*Aggregates regions into aggregate regions
collapse (sum) v, by( var sim region year commodity)


*Final data exporting
reshape wide v, i( var sim commodity year) j(region) s
gen ind=var+sim+ commodity+ string(year)
order ind

**********************
**Final export of data
**********************

export excel using "$output_data_file", sheet("Data_output_csv") sheetreplace firstrow(variables)
}

************************************************************************************************************************
*Bilateral trade data (bilat.csv)
************************************************************************************************************************
if `run_bilat_data_part'==1 {

tempfile temp
import delimited "$input_data_dir\\bilat.csv", clear

*Keep data only for specified simulations
keep if inlist(sim, `sims_to_keep')

rename value v
keep if year==`year_to_keep'
keep if inlist(var,"XWd_d","XWs_d")

**********************
**Sectoral aggregation
**********************

* I am keeping all commodities so there is nothing here

*keep if commodity=="ttot-c"

**********************
**Create total exports and imports
**********************

rename source ctry1
rename destination ctry2
preserve
keep if inlist(var,"XWs_d")
save `temp', replace
restore
keep if inlist(var,"XWd_d")
rename ctry1 ctry
rename ctry2 ctry1
rename ctry ctry2
append using `temp'
order var sim ctry1 commodity ctry2  year
save `temp', replace

*Aggregate regions
collapse (sum) v, by( var sim ctry1 commodity ctry2 year)

*Reshape data to wide
reshape wide v, i( var sim ctry1 commodity year) j( ctry2) s

*Put industries in the right order
gen ind=var+sim+ctry1+commodity+string(year)
order ind


*Export final data
export excel using "$output_data_file", sheet("Data_bilat_csv") sheetreplace firstrow(variables)
}


************************************************************************************************************************
*Employment Data (GIDDLAB.csv)
************************************************************************************************************************
if `run_giddlab_data_part'==1 {

*Load GIDDLab.csv
tempfile temp
import delimited "$input_data_dir\\GIDDLab.csv", clear

*Keep data only for specified simulations
keep if inlist(sim, `sims_to_keep')

*Keep data only for specified year
keep if year==`year_to_keep'

*Keep data only for specified region code
keep if region=="`region_to_keep_in_giddlab'"

*Reshape data to wide, with sims along the rows
* "string" means that string values are allowed
reshape wide value, i(var region lab act year) j(sim) string

*generate single id variable for use in vlookup in excel
gen id=var+region+lab+act+string(year)
*Put id variable first as that is what vlookup requires
order id

*Export final data
export excel using "$output_data_file", sheet("Data_giddlab_csv") sheetreplace firstrow(variables)
}

*Program complete
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* DAHBSIM Model - Household Module (Simplified Version)
*
* GAMS file : household_module.gms
* @purpose : Define core household module components
* @author  : Maria Blanco / Mathieu Cuilleret
* @date    : 11.07.25
* @since   : May 2014
* @refDoc  : 
* @seeAlso : 
* @calledBy: gen_baseline.gms, simulation_model.gms
*08-09 Cleaning of some unused item
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

$onglobal

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 1: MODEL PARAMETERS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

parameter
*-- Core Household Data
    p_hholdData(hhold,hvar)       'Household characteristics dataset'
    p_consoData(hhold,good,*)     'Household consumption patterns'
    p_gpridata(hhold,good,*)      'Market prices for goods (nc)'
    p_workTimeMax(hhold,m)        'Maximum working days per month'
    
*-- Initial Value Parameters
    v0_hholdSize(hhold)           'Initial household size (number of members)'
    v0_offFarmInc(hhold)          'Initial off-farm income (nc)'
    v0_selfcons(hhold,inout)      'Initial self-consumption quantities (kg/y)'
    v0_hconquant(hhold,good)      'Initial consumption quantities (kg/y)'
    
*-- Price Parameters
    p_goodPrice(hhold,good)       'Consumption goods prices'
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 2: DATA LOADING AND INITIALIZATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*-- Helper parameters for data loading
parameter 
    p_MaxHiredLabor               'Maximum allowed hired labor'
    p_raw_workTimeMax             'Raw working time limits data'
;

*-- Load household datasets
execute_load 'DATA\household_data_load%region%_new.gdx' p_hholdData p_consoData p_MaxHiredLabor p_raw_workTimeMax;
*-- Load price datasets    
execute_load 'DATA\price_data_load%region%_new.gdx' p_gpriData;

*-- Initialize household characteristics
v0_hholdSize(hhold) = p_hholdData(hhold,'hh_size');
v0_offFarmInc(hhold) = p_hholdData(hhold,'inc_offfarm');

*-- Set working time limits
p_workTimeMax(hhold,m) = p_raw_workTimeMax;

*-- Process consumption data
p_consoData(hhold,gd,'ave') = p_consoData(hhold,gd,'ave');
v0_hconquant(hhold,gd) = p_consoData(hhold,gd,'ave') * p_hholdData(hhold,'hh_size');



*-- Initialize price parameters
alias(gd,gd2);
p_goodprice(hhold,gd) = p_gpriData(hhold,gd,'p_good_price');

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 3: MODEL VARIABLES
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

variable
    v_fullIncome(hhold,year)      'Total household income (cn)'
;
positive variables
    v_offFarmInc(hhold,year)      'Off-farm income component (nc)'
    v_hiredLabor(hhold,year,m)    'Hired labor quantity (person-days)'
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 4: MODEL EQUATIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
equations
*-- Resource Constraints
    E_TIMEBALANCE     'Family labor availability constraint'
    E_maxhiredlabor   'Hired labor capacity constraint'
*-- Income Equations
    E_INCOME_OFF      'Off-farm income definition'
    E_INCOME_TOT      'Total income calculation'
*-- Consumption Equations
    E_HHCON           'Fixed consumption requirement'
    E_CASH            'Budget constraint'
;

*-- Family labor availability constraint
* (Total farm labor cannot exceed available family labor)
E_TIMEBALANCE(hhold,y,m).. 
    V_Labor_Farm_Fam(hhold,y,m) =L= (p_workTimeMax(hhold,m) * p_hholdData(hhold,'lab_family'));

*-- Hired labor capacity constraint
* (Total hired labor cannot exceed maximum allowed, considering all activities)
E_maxhiredlabor(hhold,y,m).. 
    p_MaxHiredLabor =g= 0
$ifi %CROP%==ON  + V_HLabor_C(hhold,y,m)
$ifi %LIVESTOCK_simplified%==ON + V_HLabor_A(hhold,m,y)
$ifi %ORCHARD%==ON + V_HLabor_AF(hhold,y,m)
;

*-- Off-farm income definition (fixed at initial values)
E_INCOME_OFF(hhold,y)..  
    v_offFarmInc(hhold,y) =E= v0_offFarmInc(hhold);

*-- Total income calculation (farm + off-farm income)
E_INCOME_TOT(hhold,y)..  
    v_fullIncome(hhold,y) =E= v_FarmIncome(hhold,y) + v_offFarmInc(hhold,y);

*-- Budget constraint (expenditures cannot exceed income)
E_CASH(hhold,y)..   
    v_fullincome(hhold,y) =g= sum(gd, p_goodprice(hhold,gd)*v_markPurch(hhold,gd,y));

*-- Fixed consumption requirement (set to initial quantities)
E_HHCON(hhold,gd,y).. 
    v_hconQuant(hhold,gd,y) =e= v0_hconquant(hhold,gd);

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 5: MODEL DEFINITION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

model hholdmod 'Core Household Module' /
    e_timebalance        
    E_maxhiredlabor      
    e_income_off         
    e_income_tot         
*$ifi %CONS%==on e_cash    
$ifi %CONS%==on e_hhcon   
/;
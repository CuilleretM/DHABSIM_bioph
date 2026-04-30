*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext
   DAHBSIM Model - Farm Module

   File        : farm_module.gms
   Purpose     : Defines the farm module for the DAHBSIM model
   Authors     : Maria Blanco, Mathieu Cuilleret
   Date        : 11.07.25
   Last Update : 
   Reference   :
   See Also    :
   Called By   : gen_baseline.gms, simulation_model.gms
   08-09 Displacement of variable in the set_database and new organization of the file
$offtext
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$onglobal

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 1: PARAMETERS DECLARATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter
*-- Market Environment --
    p_cpriData(hhold,inout,*)         'Price data for cropping activities'
    p_spriData(hhold,crop_activity,*) 'Seed price data (normalized currency/kg)'
    p_selPrice(hhold,inout)           'Crop selling price (normalized currency/kg)'
    p_buyPrice(hhold,inout)           'Crop buying price (normalized currency/kg)'
    p_seedbuypri(hhold,crop_activity) 'Seeds buying price (normalized currency/kg)'
;

* Additional parameters
parameter p_farm_loss(inout)          'Farm production losses';

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 2: DATA LOADING
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
execute_load 'DATA%system.DirSep%farm_data_load_%region%_new.gdx' p_farm_loss;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 3: VARIABLES DECLARATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
variables
    v_farmIncome(hhold,year)          'Total farm income (normalized currency)'
;
positive variables
*-- Labor Variables --
    V_Labor_Farm_Fam(hhold,year,m)    'Farm labor (person-day)'
*-- Production and Consumption Variables --
    v_markPurch(hhold,good,year)      'Market purchases quantity (kg)'
    v_hconQuant(hhold,good,year)      'Household consumption quantity (kg)'
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 4: INCLUDE SUB-MODULES
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ifi %ORCHARD%==ON $include "agroforestry_module.gms" 
$ifi %LIVESTOCK_simplified%==ON $include "livestock_module.gms" 
$ifi %VALUECHAIN%==ON $include "valuechain_module.gms" 

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 5: EQUATIONS DECLARATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
equations
*-- Resource Constraints --
    E_LABORBALANCE_farm        'Labor constraint by subperiods'
*-- Nutrient Balance --
*    E_NitrBal                  'Nitrate balance'
*-- Income and Demand Balances --
    E_INCOME_FARM              'Farm income calculation'
    E_DBALANCE_GD              'Demand balance for goods'
    E_limit_selfcons_c_product 'Limit on self-consumption of crop products'
*    E_limit_selfcons_ctreej    'Limit on self-consumption of tree products'
*    E_limit_selfcons_ak        'Limit on self-consumption of livestock products'
    E_NorgBal
    E_NcompBal
*20-04 
    E_landbalance 
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 6: EQUATION DEFINITIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*-- Labor Balance Equation --
* Sums labor from all active modules (crops, agroforestry, livestock)
E_LABORBALANCE_farm(hhold,y,m).. 
    V_Labor_Farm_Fam(hhold,y,m) =E= 0
$ifi %CROP%==ON       + V_FamLabor_C(hhold,y,m)
$ifi %ORCHARD%==ON    + V_FamLabor_AF(hhold,y,m)
$ifi %LIVESTOCK_simplified%==ON + V_FamLabor_A(hhold,m,y)
;

*-- Goods Demand Balance Equation --
* Balances household consumption with production and purchases
E_DBALANCE_GD(hhold,gd,y)..  
    v_hconQuant(hhold,gd,y) =E=
    sum(output_good(c_product,gd), v_selfCons(hhold,c_product,y))
$ifi %ORCHARD%==ON    + sum(output_good(c_treej,gd), v_selfCons(hhold,c_treej,y))
$ifi %LIVESTOCK_simplified%==ON + sum(output_good(ak,gd), v_selfCons(hhold,ak,y))
    + v_markPurch(hhold,gd,y)
;

*-- Farm Income Equation --
* Aggregates income from all farming activities
E_INCOME_FARM(hhold,y).. 
    v_farmIncome(hhold,y) =E=
$ifi %CROP%==ON       V_annualGM_C(hhold,y)
$ifi %LIVESTOCK_simplified%==ON + V_annualGM_A(hhold,y)
$ifi %ORCHARD%==ON    + V_annualGM_AF(hhold,y)
;

*-- Self-Consumption Limit Equations --
* Ensure self-consumption doesn't exceed total household consumption
E_limit_selfcons_c_product(hhold,c_product,gd,y)$output_good(c_product,gd)..
    v_selfCons(hhold,c_product,y) =L= v_hconQuant(hhold,gd,y);

E_NorgBal(hhold).. 
v_norg_crop(hhold) + v_norg_tree(hhold)=e=
0
$ifi %VALUECHAIN%==OFF $ifi %BIOPH%==ON $ifi %LIVESTOCK_simplified%==ON +p_Norg(hhold)
;
E_NcompBal(hhold).. 
v_ncomp_crop(hhold) + v_ncomp_tree(hhold)=e=0
$ifi %VALUECHAIN%==OFF $ifi %BIOPH%==ON + p_Ncomp(hhold)
;



*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 7: MODEL DEFINITION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
model farmMod 'Farm Module' /
$ifi %CROP%==on            cropMod
$ifi %LIVESTOCK_simplified%==on LivestockModule
$ifi %ORCHARD%==ON         orchard_model
    E_LABORBALANCE_farm
*    E_NitrBal
    E_DBALANCE_GD
    E_INCOME_FARM
    E_limit_selfcons_c_product
$ifi %VALUECHAIN%==on      valuechainMod
    E_NorgBal
    E_NcompBal
/;
*================================================================================
* DAHBSIM MODEL - DATA LOADING AND INITIALIZATION MODULE
*================================================================================
* Purpose: Loads and initializes data for Livestock, Agroforestry, and Value Chain components
* Author: [Original Author]
* Date: 02/12/2015
* Modified: [Current Date]
* Description: This module handles all data loading, parameter initialization, and 
*              set definitions required for the DAHBSIM agricultural household model.
*              It supports multiple modules: crops, agroforestry, livestock, value chain,
*              biophysical processes, and energy accounting.
*================================================================================

$ontext
   DAHBSIM model - Agricultural Household Model
   Includes: Crop production, Agroforestry, Livestock, Value Chain, Biophysical processes
   Version: 08-09 Addition of variables from household and farm modules
            Addition of biophysical parameters
$offtext

$goto %1
*================================================================================
* GENERAL SETTINGS
*================================================================================
*option decimals=3;
$label set_database_ini
*$label settings_glo
******DEFINITION OF THE MODULE AND OF THE CASE STUDY
set settings_set / BIOPH, CONS, DATABASE, ORCHARD, 
                    LIVESTOCK_simplified, CROP, PMPCalib,BiophCalib, 
                    VALUECHAIN, DIONYSUS, ENERGY, FIXEDIRRIGATION, LINUX /;

parameter settings(settings_set);
set region_text;
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%setting.xlsx
    symbols:
      - name: settings
        range: setting!A5:B18
        columnDimension: 0
        rowDimension: 1
        type: par
      - name: region_text
        range: setting!C5
        columnDimension: 0
        rowDimension: 1
        type: set
- GAMSWriter:
    symbols: all
$offEmbeddedCode



*** Generation of setglobal.gms
file fout /setglobal.gms/;
put fout;

* Case study
put '$setglobal REGION ';
loop(region_text,
    put region_text.tl:0;
);
put /;

** ON-OFF parameter
loop(settings_set,
    put '$setglobal ', settings_set.tl:0;
    if(settings(settings_set) = 1,
        put ' on';
    else
        put ' off';
    );
    put /;
);

putclose;
$include "setglobal.gms"
* Inclusion of the activated module and name of case study



*================================================================================
* SECTION 1: MODEL SETS DEFINITION AND LOADING
*================================================================================
* This section loads all set definitions that define the dimensions of the model
* including households, crops, fields, intensification levels, etc.
*================================================================================

* Load generic sets (households, crops, fields, months, years, etc.)
*$batinclude "settings.gms" sets_generic
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Declare generic sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
*-- Temporal sets
  year          'years'
  m             'months'
  
*-- Spatial and organizational sets
  reg           'regional units'
  hhold         'household types'
  
*-- Agricultural production sets
  field         'field number'
  inten         'intensification level - management practices'
  crop_activity 'cropping activities'

*08-09 Delete because they are not use
*-- Resource sets
*  labtype       'labor types'
*  labclass      'labor classes'

*-- Input/Output sets
  input_quantity 'quantity-based inputs (kg/ha)'
  input_value    'value-based inputs (nc/ha)'
  cmpro          'crop main products'
  ccpro          'crop by-products'
  task           'labor tasks'
*-- Balance sets
  seedbal       'seed balance positions'
*-- Consumption sets
  good          'goods for LES function'
*-- Data structure sets
  hvar          'household definition variables'
*-- Mapping sets
  activity_output 'activity-output mapping'
  a_j            'activity-main product mapping'
  a_k            'activity-by-product mapping'
  c_c(crop_activity,crop_activity)            'crop-preceding crop mapping'
  c_t_m          'crop-task-month mapping'
  output_good    'main product-good mapping'
;


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Load generic sets from GDX file
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- load sets from gdx
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%%region%_new.xlsx
    symbols:
       - {name: input_quantity, range: sets!F4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: input_value, range: sets!G4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: cmpro, range: sets!H4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: ccpro, range: sets!I4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: good, range: sets!J4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: activity_output, range: sets!R4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: output_good, range: sets!T4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: year, range: sets!A4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: crop_activity, range: sets!C4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: seedbal, range: sets!K4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: hvar, range: sets!N4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: task, range: sets!Q4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: field, range: sets!D4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: reg, range: sets!L4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: hhold, range: sets!M4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: inten, range: sets!E4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: m, range: sets!B4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: c_c, range: sets!V4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: c_t_m, range: sets!X4, columnDimension: 0, rowDimension: 3, type: set}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
*       

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #3 Define aggregate sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  input         'all input categories'                 /set.input_quantity,set.input_value/
  output        'all output categories'                /set.cmpro,set.ccpro/
  inout         'combined inputs/outputs'     /set.input,set.output/
;


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #4 Define sub-sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  inpq(inout)   'quantity inputs'     /set.input_quantity/
  inpv(inout)   'value inputs' /set.input_value/
  outm(inout)   'main products'           /set.cmpro/
  outc(inout)   'by-products'             /set.ccpro/
  feed(inout)   'feed sources'       /set.inout/
 ;




* Load region-specific settings (region definitions, specific parameters)
*$batinclude "settings.gms" settings_reg

*-- Year set definitions

$setglobal FstAnte 2025
$setglobal LstPost 2027
$setglobal FstYear 2025
$setglobal LstYear 2027


*set  yy(year) 'ex-post and ex-ante years' /%FstAnte%*%LstPost%/;
set  y2(year) 'simulation years' /%FstYear%*%LstYear%/;
*if you put a bigger value it cause issue with pmp
set  y(year)  'model years'      /y01*y02/; 



* Load specific sets for this model instance (activity-specific sets)
*$batinclude "settings.gms" sets_specific
*-- Specific set declarations for current run

*~~~~~~~~~~~~~~~~ Temporal sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  y(year) 'years in current run'
;

*~~~~~~~~~~~~~~~~ Agricultural production sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  type_animal       'livestock types in current run'
  crop_activity_endo(crop_activity) 'endogenous crop activities in current run'
;

*~~~~~~~~~~~~~~~~ Input/Output sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  i(inout)            'inputs'
  c_product(inout)    'crop products'
  c_product_endo(inout) 'endogenous crop products'
  ck(inout)           'crop by-products'
  cken(inout)         'endogenous by-products'
  gd(good)            'consumption goods'
  crop_preceding(crop_activity) 'preceding crops in rotation'
  ak(inout)           'animal products' 
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Define specific relationships and mappings
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- Create aliases for cross-referencing
alias(crop_activity,crop_activity2);
alias(m,m2);
alias(gd,gd2);

*-- crop activities endogenous and exogenous
crop_activity_endo(crop_activity) = yes $sum(crop_activity2,c_c(crop_activity,crop_activity2));
alias(crop_activity_endo,crop_activity_endo2);

*-- Identify preceding crops in rotation
crop_preceding(crop_activity_endo) = yes;


*-- Define input categories
* Nitrogen inputs
i('nitr')  = yes;
* Seed inputs  
i('seed')  = yes;  
* Phytosanitary inputs
i('phyto') = yes;  
* Other inputs
i('other') = yes;  
*NEW parameter to solve the issue of word


Set NameStraw / ystraw/ ;
Set NameYield / yield/ ;
Set NameArea / area/ ;
Set   NameSeed(inout);
NameSeed('seed') = yes; 
Set   NameLabor(inout);
NameLabor('labor') = yes; 
Set   NameNitr(inout);
NameNitr('nitr') = yes;
Set   NamePlantsNb(inout);
NamePlantsNb('plants_nb') = yes;
Set   NamePhyto(inout);
NamePhyto('phyto') = yes; 
Set   NameOther(inout);
NameOther('other') = yes; 
Set   NameseedOnFarm(seedbal)         'seed inputs';
NameseedOnFarm('seedOnFarm') = yes;
Set   NameseedTotal(seedbal)         'seed inputs';
NameseedTotal('seedTotal') = yes; 
Set   NameFert(inout);
NameFert('fert') = yes;
Set   NamePlanting(task)         ;
NamePlanting('planting') = yes; 
Set   NameWeeding(task)         ;
NameWeeding('weeding') = yes; 
Set   NameHerbicide(task)       ;
NameHerbicide('herbicide') = yes;
Set   NameChe_fert(task)        ;
NameChe_fert('che_fert') = yes;
Set   NameOrg_fert(task)        ;
NameOrg_fert('org_fert') = yes;
Set   NamePesticide(task)       ;
NamePesticide('pesticide') = yes;
Set   NameHarvest(task)       ;
NameHarvest('harvest') = yes;

*-- Identify crop products and their relationships
c_product(outm) = yes $(sum(activity_output(crop_activity,outm),1));
a_j(crop_activity,c_product) $(activity_output(crop_activity,c_product)) = yes ;
c_product_endo(outm) = yes $(sum(activity_output(crop_activity_endo,outm),1));

*-- Identify by-products and their relationships
ck(outc) = yes $(sum(activity_output(crop_activity,outc),1));
a_k(crop_activity,ck) $(activity_output(crop_activity,ck)) = yes ;
cken(outc) = yes $(sum(activity_output(crop_activity_endo,outc),1));

*-- Identify consumption goods
gd(good)= yes  ;
*================================================================================
* SECTION 2: CROP ACTIVITY DATA PARAMETERS
*================================================================================
* This section declares all parameters needed for crop production activities,
* including input-output coefficients, labor requirements, and price data.
* It handles two intensification levels (extensive and intensive).
*================================================================================

* Crop data parameters - main storage for crop production coefficients
parameters
  p_cropCoef(hhold,crop_activity,field,inten,*)   'Input-output coefficients for crop activities'
  p_laborReq(hhold,crop_activity,inten,m)         'Total labor requirements (person-days per hectare)'
  p_labReqTask(hhold,crop_activity,inten,task)    'Labor requirements by specific task type'
  p_residuedep                                   'Residue carryover percentage between months'
  p_perresmulch(inout)                           'Percentage of crop residue allocated for mulch'
  p_seedData(hhold,crop_activity,*)              'Seed data: on-farm vs purchased (kg per hectare)'
  p_farmData(hhold,*,*,*)                        'Farm-level data (land, labor, etc.)'
  p_consoData(hhold,good,*)                      'Household consumption data'
  p_hholdData(hhold,hvar)                        'Household characteristics (size, income, etc.)'
  p_cpriData(hhold,inout,*)                      'Crop buying and selling prices'
  p_apriData(hhold,inout,*)                      'Animal product prices'
  p_gpriData(hhold,good,*)                       'Goods prices (consumption items)'
  p_spriData(hhold,crop_activity,*)              'Seed purchase prices'
*-- Auxiliary parameters for raw data loading
  p_cropCoef_raw(*,*,*,*,*)                      'Raw crop coefficients from Excel'
  labReqTask(*,*,*,*)                            'Raw labor requirement data'
  farmlabData_raw(hhold,*)                       'Raw farm labor data'
  outData_raw(hhold,inout,*)                     'Raw output data'
  hholdData_raw(hhold,*)                         'Raw household data'
  consoData_raw(hhold,good,*)                    'Raw consumption data'
  apriData_raw(hhold,inout,*)                    'Raw animal product prices'
  cpriData_raw(hhold,*,*)                        'Raw crop price data'
  gpriData_raw(hhold,good,*)                     'Raw goods price data'
  spriData_raw(hhold,crop_activity,*)            'Raw seed price data'
  p_pricescalar                                  'Price scalar for currency conversion'
  p_selPrice(hhold,inout)                        'Crop selling price (normalized currency/kg)'
  p_buyPrice(hhold,inout)                        'Crop buying price (normalized currency/kg)'
*SEED
  p_seedbuypri(hhold,crop_activity)              'Seed purchase price (normalized currency/kg)'
  seedData_raw(*,*,*)                            'Raw seed data'
  p_crop_loss_raw                                'Raw crop loss data'
  p_crop_loss(hhold,inout)                       'Crop loss percentage by household and crop'
  p_resmulch                                     'Residue mulch allocation data'
*HOUSEHOLD INFORMATION
  p_landField(hhold,field)                     'Land area by household and field type'
  p_farm_loss(inout)                           'Farm-level crop loss rates'
  p_MaxHiredLabor                              'Maximum hired labor available (days)'
  p_raw_workTimeMax                             'Maximum work time per person'
  p_distanceprice(hhold)                       'Distance-based price adjustment'
*-- Crop activity coefficients (detailed breakdown)
  p_cropCoef(hhold,crop_activity,field,inten,*)   'Complete crop input-output coefficients'
  p_laborReq(hhold,crop_activity,inten,m)         'Monthly labor requirement (person-days per ha)'
  p_inputReq(hhold,crop_activity,field,inten,inout) 'Direct input requirements (fertilizer)'
  
*-- Observed activity levels (baseline data for calibration)
  p_seedData(hhold,crop_activity,*)               'Observed seed use (kg per hectare)'
  V0_Plant_C(hhold,crop_activity,*,field,inten)   'Observed activity level (hectares)'
  v0_Land_C(hhold,crop_activity,field)            'Observed crop area by soil type (hectares)'
  v0_Use_Land_C(hhold,field)                      'Total observed cropland (hectares)'
  v0_Prd_C(hhold,crop_activity,field,inten)       'Observed crop production (kg)'
  v0_prodQuant(hhold,inout)                       'Total observed crop output (kg)'
  v0_Yld_C(hhold,crop_activity,*,field,inten)     'Observed crop yield (kg/ha)'
  V0_Use_Input_C(hhold,crop_activity,inout)       'Observed input use (kg)'
  v0_inputCost(hhold,crop_activity,inout)         'Observed input cost (normalized currency)'
  V0_Use_Seed_C(hhold,crop_activity,seedbal)      'Observed seed use by source (kg)'
  v0_Yld_C_stress(hhold,*,*,field,inten)          'Yield under stress conditions'

*-- Parameter to map crop and harvest month
    indic(inout,m)              'Indicator for crop-harvest month relationship'
    flag(inout,m)               'Flag for month mapping'
    count                       'Counter for iterations'
    stopflag                    'Stop condition flag'
    flagm(inout,m)              'Month mapping flag'
    countm                      'Month counter'
;

set
*-- SET OF CROP
previouscrop                                 'Set of preceding crops for rotation y-2'
hhold_crop_map(hhold,crop_activity)         'Mapping of households to crops they produce'
fieldcrop(hhold,field,crop_activity) 'Mapping between fields and crops with positive production'
fieldcrop_tree(hhold,field) 'Mapping field that are occupied by tree and crop'
c_t_m_map(inout,m)          'Map crop product to harvest month'
*-- SET OF TREE
    c_tree                  'Tree crop types (cocoa, coffee, fruit trees, etc.)'
    task_tree               'Agroforestry task types (planting, pruning, harvesting, etc.)'
    ageclass_tree           'Tree age classes (young, adult, old)'
    inputprice_tree         'Input price categories for trees'
    othcost_tree            'Other cost categories for trees'
    age_tree                'Tree age groups'
    c_t_m_orchard           'Orchard task-month mapping'
    c_treej(inout)          'Tree products in current simulation'
    a_c_treej               'Mapping from tree activities to main products'
;



*================================================================================
* SECTION 2.1: AGROFORESTRY/ORCHARD PARAMETERS
*================================================================================
* Parameters specific to tree-based agricultural systems including age classes,
* labor requirements, and yield patterns over tree lifetime.
*================================================================================


set othcost_tree / other_localCurrency_ha, phyto_localCurrency_ha, area_ha, nitr_kg_ha, plants_nb_ha /;

Parameter 
p_taskLabor_cost_LocalCur(*,*)  'Labor cost by task (local currency)'
life_tree(c_tree)               'Total lifespan of tree (years)'
oldAge_tree(c_tree)             'Age when production starts declining (years)'
type_age_tree(*,*)              'Age classification parameters'
harvestingAge_tree(c_tree)      'Age when first harvest occurs (years)'
v0_Yld_C_tree(field,*, ageclass_tree<) 'Observed tree yield data'
p_selPrice_tree(c_tree)         'Sales price for tree products (USD/kg)'
p_buyPrice_tree_LocalCur(inputprice_tree<,c_tree<) 'Input purchase prices (USD/kg)'
V0_Area_AF(hhold,field,c_tree,age_tree,inten)    'Initial tree area by age class (ha)'
v0costPhyto_AF
v0costOther_AF
p_inputcost(hhold,c_tree,field,inten)            'Input costs for trees'
v0_Age_AF(c_tree,field, age_tree)                'Age distribution of trees'
v0_cropCoef_AF(hhold,c_tree,field,inten,othcost_tree) 'Agroforestry coefficients'
Labor_Task_AF(*,*,*,*)                           'Labor requirements for tree tasks'
p_Labor_Task_AF(*,*,*,*)                         'Processed labor requirements'
p_laborReq_AF(*,*,*,*)                           'Monthly labor requirements for trees'
p_taskLabor_cost(c_tree,task_tree)               'Task-based labor costs'
p_buyPrice_tree(inputprice_tree,c_tree)          'Tree input purchase prices'
p_field_AF(hhold,field)                          'Field suitability for agroforestry'
p_iniprim(hhold,field)                           'Initial primary vegetation'
;

parameter pressuretree(hhold,c_tree,field,inten) 'Pressure index for tree growth';

* Task classification for agroforestry operations
Set NameWeedingAF(task_tree)          'Weeding tasks'
    NameGrubbAF(task_tree)            'Grubbing up tasks'
    NameChe_fertAF(task_tree)         'Chemical fertilizer application'
    NameOrg_fertAF(task_tree)         'Organic fertilizer application'
    NamePesticideAF(task_tree)        'Pesticide application'
    NamePruningAF(task_tree)          'Pruning tasks'
    NameAdult(ageclass_tree)          'Adult tree age class'
    NameHarvestAF(task_tree)          'Harvesting tasks'
    NameYoung(ageclass_tree)          'Young tree age class'
    NameNitrAF(othcost_tree)          'Nitrogen application'
    NameOld(ageclass_tree)             'Old tree age class'
    NamePlantsAF(othcost_tree)         'Planting material'
    NameNitrPrice(inputprice_tree)     'Nitrogen fertilizer price'
    NamePlantsPrice(inputprice_tree)   'Planting material price'
    NamePlantingAF(task_tree)          'Planting tasks'
;

*================================================================================
* SECTION 2.2: LIVESTOCK PARAMETERS
*================================================================================
* Parameters for animal production including feed requirements, reproduction,
* mortality, and product yields (meat, milk).
*================================================================================

sets
    age                    'Animal age groups (young, adult, old)'
    akmeat(ak)             'Meat products (beef, pork, poultry, etc.)'
    akmilk(ak)             'Milk products (cow milk, goat milk, etc.)'
    feedc                  'Feed types (concentrates, fodder, etc.)'
    animal_feed(type_animal,feedc) 'Mapping of feed types to animal types'
;

parameters
*-- Economic parameters for livestock
    p_selPriceLivestock(hhold,type_animal,*) 'Selling price of animal products (nc/unit)'
    p_othCostLivestock(hhold,type_animal)    'Other costs per animal (nc/head)'
    p_costVeterinary(hhold,type_animal)      'Veterinary costs per animal (nc/head)'
    p_AdditionalCostLivestock(hhold,type_animal) 'Additional miscellaneous costs (nc/head)'
    p_laborPrice                             'General labor price (nc/day)'
    p_Repro(hhold,type_animal,age)           'Reproduction rate by animal age group'
    
*-- Production parameters
    p_feedReq(type_animal,*)                 'Feed requirement per animal (kg/head)'
    p_MortalityRate(hhold,type_animal,age)   'Mortality rate by animal age group'
    p_LaborReqLivestock(hhold,type_animal,m) 'Labor requirement per animal (days/head/month)'
    p_yieldLivestock(hhold,type_animal,ak,age) 'Yield of animal products by age'
    
*-- Nutritional parameters (for feed quality and animal nutrition)
    p_prot_intake(hhold,type_animal)         'Protein intake parameter'
    p_prot_metab(hhold,type_animal)          'Protein metabolism parameter'
    p_ca(hhold,type_animal)                  'Calcium requirement parameter'
    p_grossenergy_feed(feedc)                'Gross energy content of feed (MJ/kg)'
    p_protein_feed(feedc)                    'Protein content of feed (%)'
    p_drymatter_feed(feedc)                  'Dry matter content of feed (%)'

*-- Initial values for model initialization
    p_initPopulation(hhold,type_animal,age)  'Initial animal population (heads)'
    p_DataLive                               'Raw livestock data from Excel'
    p_selPriceLivestock_raw(hhold,type_animal,*) 'Raw selling price data'
    p_yieldLivestock_raw                     'Raw yield data by product'
    p_feed_price_LocalCur(hhold,feedc)       'Feed prices (local currency)'
    p_feed_price(hhold,feedc)                'Processed feed prices (nc/kg)'
;

*================================================================================
* SECTION 2.3: VALUE CHAIN PARAMETERS
*================================================================================
* Parameters for market linkages including buyers, sellers, transportation,
* and transaction costs for all agricultural products.
*================================================================================

set
seller_C                'Crop sellers in value chain'
seller_AF               'Agroforestry product sellers'
seller_A                'Animal product sellers'
buyer                   'Buyers in value chain'
seeder                  'Seed suppliers'
inout_a                 'Agricultural inputs and outputs'
Livestock_seller        'Livestock sellers'
Feed_seller             'Feed sellers'
;

* Market and transaction parameters
Parameter
P_GHG(hhold,*)                           'Greenhouse gas emissions parameters'
P_buyer(inout,buyer,*)                   'Buyer characteristics (price, capacity, labor)'
p_capacity_buyer(inout,buyer)            'Buyer purchase capacity'
p_distance(hhold,*)                      'Distance between households and market actors'
p_distance_buyer(hhold,buyer)            'Distance to buyers'
p_labor_buyer(inout,buyer)               'Labor required for buyer transactions'
p_price_buyer                            'Buyer offer prices'
p_price_seller                           'Seller asking prices'
p_price_seeder                           'Seed supplier prices'
p_price_Feed_seller                      'Feed seller prices'
p_price_Livestock_seller                 'Livestock seller prices'
;

set inout_a /costVeterinary, othCostLivestock, AdditionalCostLivestock/;

Set NamecostVeterinary(inout_a)           'Veterinary cost category'
    NameothCostLivestock(inout_a)         'Other livestock cost category'
    NameAdditionalCostLivestock(inout_a)  'Additional livestock cost category'
;

* Seller parameters by product category
Parameter
P_seller_C(inout,seller_C,*)              'Crop seller parameters'
p_capacity_seller_C(inout,seller_C)       'Crop seller capacity'
p_distance_seller_C(hhold,seller_C)       'Distance to crop sellers'
p_labor_seller_C(inout,seller_C)          'Labor for crop transactions'

P_seeder(crop_activity,seeder,*)          'Seed supplier parameters'
p_capacity_seeder(crop_activity,seeder)   'Seed supplier capacity'
p_distance_seeder(hhold,seeder)           'Distance to seed suppliers'
p_labor_seeder(crop_activity,seeder)      'Labor for seed transactions'

P_seller_A(*,seller_A,*)                  'Animal product seller parameters'
p_capacity_seller_A(inout_a,seller_A)     'Seller capacity for animal products'
p_labor_seller_A(*,seller_A)              'Labor for animal product transactions'
p_distance_seller_A(hhold,seller_A)       'Distance to animal product sellers'

P_Livestock_seller (type_animal,Livestock_seller,*) 'Livestock seller parameters'
p_capacity_Livestock_seller(type_animal,Livestock_seller) 'Livestock seller capacity'
p_distance_Livestock_seller(hhold,Livestock_seller) 'Distance to livestock sellers'
p_labor_Livestock_seller(type_animal,Livestock_seller) 'Labor for livestock transactions'

P_Feed_seller (feedc,Feed_seller,*)       'Feed seller parameters'
p_capacity_Feed_seller(feedc,Feed_seller) 'Feed seller capacity'
p_distance_Feed_seller(hhold,Feed_seller) 'Distance to feed sellers'
p_labor_Feed_seller(feedc,Feed_seller)    'Labor for feed transactions'

P_seller_AF(inout,seller_AF,*)            'Agroforestry seller parameters'
p_capacity_seller_AF(inout,seller_AF)     'Agroforestry seller capacity'
p_distance_seller_AF(hhold,seller_AF)     'Distance to agroforestry sellers'
p_labor_seller_AF(inout,seller_AF)        'Labor for agroforestry transactions'
;

*================================================================================
* SECTION 2.4: PMP CALIBRATION PARAMETERS
*================================================================================
* Parameters for Positive Mathematical Programming (PMP) calibration
* Used to calibrate the model to observed baseline data
*================================================================================

parameter
  delta1                   'Small number for PMP calibration (0.0001)'
  PMPslope(hhold,crop_activity)      'PMP cost function slope coefficient'
  PMPint(hhold,crop_activity)        'PMP cost function intercept'
  PMPdualVal(hhold,crop_activity)    'Shadow value from PMP calibration constraints'
  PMPSolnCheck(hhold,crop_activity,*) 'Comparison of calibration results with data'
  PMPswitch                          'Switch for PMP constrained calibration stage (1=on)'
;

Set crop_and_tree(*)                   'Union of crops and trees for biophysical module';

*================================================================================
* SECTION 2.5: BIOPHYSICAL PARAMETERS (WATER AND NITROGEN)
*================================================================================
* Parameters for crop growth modeling including water stress, evapotranspiration,
* soil water balance, and nitrogen dynamics.
*================================================================================

parameter
*-- Yield response parameters
         ym(*,field,inten)              'Maximum potential yield (t/ha)'
         p_hw(hhold,*,field,inten)      'Water stress factor'
         p_etm(*,field,inten)           'Maximum evapotranspiration (mm/day)'
         p_kc(*,field,inten)            'Crop coefficient'
         p_et0                           'Reference evapotranspiration (mm/day)'
         p_et0_raw                       'Monthly ET0 variation per year'
         p_eta_m                         'Monthly actual evapotranspiration (mm)'
         p_etm_m                         'Monthly maximum evapotranspiration (mm)'
         p_etm_t                         'Annual maximum evapotranspiration (mm)'
         p_eta_t                         'Annual actual evapotranspiration (mm)'

*-- Irrigation parameters for crops
         p_luse(*,field,inten,m)        'Land use coefficient during crop cycle'
         p_rain                         'Monthly effective rainfall (mm/month)'
         
*-- Soil water parameters
         p_asi                           'Available soil water index'
         p_swd0(hhold,*,field,inten)          'Initial soil water depth (mm/month)'
         p_swd(hhold,*,field,inten,m)         'Actual soil water depth at sowing (mm/month)'
         p_wdf                           'Soil water depletion fraction'
         p_factor(*,field,inten)         'Actual soil water depletion factor (FAO Table 22)'
         p_rdm(*,inten)                  'Maximum rooting depth by crop (m)'
         p_swa(*,field,inten)            'Available soil water by crop (mm/m depth)'
         p_swr                           'Remaining soil water (mm)'
         p_swa_m(*,field,inten,*)        'Monthly available soil water (mm/m)'
         p_swm(field)                    'Maximum soil water available (mm/m depth)'
         p_d(hhold,crop_activity,field,inten,m) 'Soil water drainage (mm/month)'
         P_D_t(hhold,crop_activity,field,inten) 'Total drainage (mm/season)'
         p_swd12(hhold,crop_activity,field,inten) 'Soil water depth at day 12'
         last_active_month               'Last month of crop activity'

*-- Crop yield under stress
         v0_Yld_C(hhold,crop_activity,*,field,inten)       'Observed yield (t/ha)'
         v_Yld_C_max(hhold,crop_activity,*,field,inten)    'Maximum potential yield (t/ha)'
;

* Nitrogen dynamics parameters
Parameters
    p_nav_begin_fixed(hhold,field,inten,*,y)   'Fixed available N at year start'
    p_nmin_fixed(hhold,field,y)              'Fixed mineralized nitrogen'
    p_Nres_fixed(hhold,field,y)              'Fixed nitrogen from crop residues'
    p_nl_fixed(hhold,*,field,inten,y)          'Fixed nitrogen leaching'
    p_nfin_fixed(hhold,field,inten,*,y)        'Fixed final nitrogen'
    p_hini_fixed(hhold,field,y)              'Fixed initial humus content'
    p_hfin_fixed(hhold,field,y)              'Fixed final humus content'
    p_nav_fixed(hhold,field,inten,*,y)         'Fixed total available nitrogen'
    p_nab_fixed(hhold,*,field,inten,y)         'Fixed nitrogen absorbed by crop'
    p_nstress_fixed(hhold,*,field,inten,y)     'Fixed nitrogen stress coefficient'
;

* Water balance parameters
Parameters
    p_irrigation_opt_fixed(hhold,*,field,inten,m,y) 'Fixed optimal irrigation (mm)'
    p_KS_month_fixed(hhold,*,field,inten,m,y)      'Fixed monthly water stress coefficient'
    p_DR_start_fixed(hhold,*,field,inten,m,y)      'Fixed water balance at month start'
    p_DR_end_fixed(hhold,*,field,inten,m,y)        'Fixed water balance at month end'
    p_KS_avg_annual_fixed(hhold,*,field,inten,y)   'Fixed annual average water stress'
    p_DR_excess_fixed(hhold,*,field,inten,m,y)     'Fixed excess water (runoff)'
    p_KS_total_fixed(hhold,*,field,inten,m,y)      'Fixed cumulative water stress'
    p_b_KS_fixed(hhold,*,field,inten,m,y)          'Fixed binary water stress indicator'
    p_b_DR_negative_fixed(hhold,*,field,inten,m,y) 'Fixed binary drainage indicator'
;
Positive Variable
v_ncomp_crop(hhold)
v_ncomp_tree(hhold)
v_norg_tree(hhold)
v_norg_crop(hhold)
V_energy(hhold,y)
;
* Soil water holding parameters
Parameter
    TAW(hhold,*,field,inten)                    'Total Available Water (mm)'
    RAW(hhold,*,field,inten,m,y)                'Readily Available Water (mm)'
    CR(hhold,*,field,inten)                     'Capillary Rise (mm)'
    days_in_month(m)                            'Days per month'
    ET0_month(hhold,*,field,inten,m,y)          'Monthly reference ET'
    p_test(hhold,*,field,inten,m,y)             'Test parameter'
;

*================================================================================
* SECTION 2.6: NITROGEN CYCLE PARAMETERS
*================================================================================
* Parameters for soil nitrogen dynamics including mineralization, 
* leaching, and crop uptake.
*================================================================================

parameter
calibBioph(hhold,crop_activity,*,field,inten)  'Biophysical calibration parameters'

p_cropCoef(hhold,crop_activity,field,inten,*)  'Crop coefficients (redeclaration)'

*-- Sources of nitrate by activity
p_Qfert(hhold,crop_activity,field,inten)      'Fertilizer application rate (kg N/ha)'
p_Qres(hhold,inout,field,inten)               'Residues from preceding crop (kg/ha)'
p_Qcomp(hhold)                                 'Compost application rate (kg N/ha)'
p_humus                                        'Humus content (kg/ha)'

*-- Nitrate stress parameters
P_Npot(hhold,*,field,inten)                   'N required for optimal growth (kg N/ha)'
p_Nmin(hhold,crop_activity,field,inten)       'N mineralized from humus (kg N/ha)'
p_Nab(hhold,crop_activity,field,inten)        'Actual N uptake (kg N/ha)'
p_Nav(hhold,crop_activity,field,inten)        'Available N (kg N/ha)'
p_Nini(hhold,field)                           'Initial soil N content (kg N/ha)'
p_Nl(hhold,crop_activity,field,inten)         'N leaching losses (kg N/ha)'
p_Nw(hhold,crop_activity,field,inten)         'Nitrogen stress coefficient'

*-- Nitrate sources and sinks
p_Nitr(hhold,crop_activity,field,inten)       'Total N requirement (kg N/ha)'
p_Nres(hhold,inout,field,inten)               'N from residues (kg N/ha)'
p_Nres_raw                                    'Raw residue N data'
p_Norg(hhold)                                  'N from organic sources (kg N/ha)'
p_Nfert(hhold,crop_activity,field,inten)      'N from mineral fertilizer (kg N/ha)'
p_Nfin(hhold,crop_activity,field,inten)       'Final N content (kg N/ha)'
p_Hfin(hhold,crop_activity,field,inten)       'Final humus content (%)'
p_Hini(hhold,field)                            'Initial humus content (%)'

*-- Other parameters for nitrogen dynamics
p_MScomp(hhold)                                'Compost dry matter content (%)'
K3                                            'Humification rate'
P_Nfert_y(hhold,crop_activity,field,inten)    'Annual N fertilizer application'
K1(*)                                         'Nitrate conversion coefficients'
K2(field)                                      'Mineralization rate'
da                                            'Soil bulk density (kg/m³)'
prof                                          'Plowed layer depth (m)'
p_MSres                                        'Dry matter content of residues (%)'
p_effr(inout)                                  'N content per kg of biomass'
p_Nini_raw                                     'Initial N content data'
p_Norg_raw                                     'Organic N data'
p_Qcomp_raw                                    'Raw compost quantity data'
p_MScomp_raw                                   'Raw compost dry matter data'
p_Nl_raw                                       'N leaching rate'
p_Nw2(*,*,*,*,*)                               'N stress response parameters'
p_OrgMat(*,*,*,*)                              'Organic matter parameters'
p_nfert_max_annual_raw                         'Maximum annual N application rate'
p_Hini_raw                                     'Initial humus content data'
;

* Monthly days and time parameters
parameter
  mday(m)    'Days per month' /(M01,M03,M05,M07,M08,M10,M12) 31
                              (M04,M06,M09,M11) 30
                               M02              28/
;

Scalar lastMonth                              'Last month index';
lastMonth = card(m);
Scalar discretization2 /10000/     ;           

parameter p_meteo                              'Meteorological data'
           p_Humus                             'Humus parameters'
           agro                                'Agroforestry parameters'
;

* Irrigation parameters
parameter v0_max_irrigation(hhold,*,field,inten,m,y) 'Maximum irrigation capacity'
p_cost_irrigation(hhold)                        'Irrigation cost per mm'
irrigation_raw                                  'Raw irrigation data'
irrigation_month                                'Monthly irrigation data'

parameter 
p_water_calib(crop_activity,inten)              'Water calibration parameters'
p_nitr_calib(crop_activity,inten)               'Nitrogen calibration parameters'

Parameter
    p_ncomp(hhold)                              'Annual compost N application (kg/ha)'
    p_nfert_max_annual(hhold,crop_activity,field,inten) 'Maximum annual N application (kg/ha)'
;

*================================================================================
* SECTION 2.7: ENERGY BALANCE PARAMETERS
*================================================================================
* Parameters for energy accounting in agricultural activities
*================================================================================

parameter
enerReqtask_crop(*,*,*,*)          'Energy requirements for crop tasks (MJ/ha)'
enerReqtask_AF(*,*,*,*)            'Energy requirements for agroforestry tasks (MJ/ha)'
enerReq_Livestock(*,*,*)           'Energy requirements for livestock (MJ/head)'
enerReq_Feed(*,*,*)                'Energy content of feeds (MJ/kg)'

scalar n_total                    'Total number of observations for diversity index';
n_total = card(hhold) * card(y) * card(crop_activity_endo);

parameter
p_energy_crop(hhold,crop_activity,inten,*)      'Total crop energy use'
p_energy_task_crop(hhold,crop_activity,inten,*) 'Energy by task for crops'
p_energy_task_AF(hhold,c_tree,inten,*)          'Energy by task for agroforestry'
p_energy_AF(hhold,c_tree,inten,*)               'Total agroforestry energy use'

parameter
*-- Discounting parameters
  dr                    'Discount rate'
  rho            'Discount factor per year'
  p_phi                 'Risk aversion coefficient for utility function'
;


*20-04

parameter p_buffer;
parameter MaxConcNitr; 
parameter InitConcNitr;

*================================================================================
* SECTION 3: DATA LOADING FROM EXCEL FILES
*================================================================================
* This section uses GAMS Embedded Code to read data from Excel files
* It loads all raw data and maps it to the parameters defined above
*================================================================================

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%%region%_new.xlsx
    symbols:
       - {name: p_cropCoef_raw, range: crop_data!H4:S5000, columnDimension: 1, rowDimension: 4, type: par}
       - {name: p_resmulch, range: crop_data!F4:G5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: labReqtask, range: crop_data!T4:AC5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: p_crop_loss_raw, range: crop_data!C4:E5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: previouscrop, range: crop_data!A4:A5000, columnDimension: 0, rowDimension: 1, type: set}
       - {name: farmlabData_raw, range: farm_data!D4, columnDimension: 1, rowDimension: 1, type: par}
       - {name: p_farm_loss, range: farm_data!A4, columnDimension: 0, rowDimension: 1, type: par}
       - {name: hholdData_raw, range: household_data!A4:C5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: consoData_raw, range: household_data!H4:J5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_MaxHiredLabor, range: household_data!F4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_raw_workTimeMax, range: household_data!F5, columnDimension: 0, rowDimension: 0, type: par}
       - {name: cpriData_raw, range: price_data!E4:H5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: spriData_raw, range: price_data!J4:L5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: gpriData_raw, range: price_data!N4:P5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_pricescalar, range: price_data!C4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: type_age_tree, range: agroforestry_data!A5:C5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: p_buyPrice_tree_LocalCur, range: agroforestry_data!D5:F5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: age_tree, range: agroforestry_data!G5:G5000, columnDimension: 0, rowDimension: 1, type: set}
       - {name: task_tree, range: agroforestry_data!H5:H5000, columnDimension: 0, rowDimension: 1, type: set}       
       - {name: c_t_m_orchard, range: agroforestry_data!I5:K5000, columnDimension: 0, rowDimension: 3, type: set}       
       - {name: p_taskLabor_cost_LocalCur, range: agroforestry_data!L5:N5000, columnDimension: 0, rowDimension: 2, type: par}  
       - {name: v0_Age_AF, range: agroforestry_data!O5:R5000, columnDimension: 0, rowDimension: 3, type: par}
       - {name: v0_cropCoef_AF, range: agroforestry_data!S5:AA5000, columnDimension: 1, rowDimension: 4, type: par}
       - {name: v0_Yld_C_tree, range: agroforestry_data!AB6:AE5000, columnDimension: 0, rowDimension: 3, type: par}
       - {name: Labor_Task_AF, range: agroforestry_data!AF4:AP5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: ak, range: Livestock!A4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: akmeat, range: Livestock!B4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: akmilk, range: Livestock!C4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: type_animal, range: Livestock!D4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: age, range: Livestock!E4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: feedc, range: Livestock!F4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: p_DataLive, range: Livestock!M4:Z5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: p_selPriceLivestock_raw, range: Livestock!AA5:AD30, columnDimension: 0, rowDimension: 3, type: par}
       - {name: p_feed_price_LocalCur, range: Livestock!AE5:AG5000, columnDimension: 0, rowDimension: 2, type: par}       
       - {name: p_yieldLivestock_raw, range: Livestock!AH4:AL5000, columnDimension: 1, rowDimension: 4, type: par}
       - {name: p_feedReq, range: Livestock!AM4:AP5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: p_grossenergy_feed, range: Livestock!G4:H5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: p_drymatter_feed, range: Livestock!I4:J5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: p_protein_feed, range: Livestock!K4:L5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: animal_feed, range: Livestock!AQ4:AR5000, columnDimension: 0, rowDimension: 2, type: set}
       - {name: buyer, range: value_chain!M5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_buyer, range: value_chain!N4:R5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_distance, range: value_chain!AQ5:AS5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: P_GHG, range: value_chain!AT5:AV5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: seller_C, range: value_chain!A5:A5000, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_C, range: value_chain!B4:F5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: seeder, range: value_chain!G5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seeder, range: value_chain!H4:L5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: seller_A, range: value_chain!Y5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_A, range: value_chain!Z4:AD5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: Livestock_seller, range: value_chain!AE5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_Livestock_seller, range: value_chain!AF4:AJ5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: Feed_seller, range: value_chain!AK5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_Feed_seller, range: value_chain!AQ5:AS5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: seller_AF, range: value_chain!S5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_AF, range: value_chain!T4:X5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_meteo, range: water!A4:M5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: p_et0_raw, range: water!N4:Z5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: agro, range: water!AA3:AF5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_swm, range: water!AG4:AH5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: irrigation_raw, range: water!AX3:AZ5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: irrigation_month, range: water!AI3:AW5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: K1, range: nitrogen!A4:B5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: p_Nres_raw, range: nitrogen!E4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: K2, range: nitrogen!C4:D5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: K3, range: nitrogen!G4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: da, range: nitrogen!H4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: prof, range: nitrogen!I4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Msres, range: nitrogen!J4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_effr, range: nitrogen!K4:L5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: p_Nini_raw, range: nitrogen!M4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Norg_raw, range: nitrogen!N4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Qcomp_raw, range: nitrogen!O4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Mscomp_raw, range: nitrogen!P4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Nl_raw, range: nitrogen!Q4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_nfert_max_annual_raw, range: nitrogen!R4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_Hini_raw, range: nitrogen!S4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_water_calib, range: calib_data!A4:C5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: p_nitr_calib, range: calib_data!D4:F5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: enerReqtask_crop, range: energy_data!A4:N5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: enerReqtask_AF, range: energy_data!O4:AC5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: enerReq_Livestock, range: energy_data!AD4:AF5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: enerReq_Feed, range: energy_data!AG4:AI5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: dr, range: risk!B2, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_phi, range: risk!B1, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_buffer, range: agroforestry_data!AQ5, columnDimension: 0, rowDimension: 0, type: par}
       - {name: MaxConcNitr, range: nitrogen!U3, columnDimension: 0, rowDimension: 0, type: par}
       - {name: InitConcNitr, range: nitrogen!U4, columnDimension: 0, rowDimension: 0, type: par}
- GAMSWriter:
    symbols: all  # Write all loaded symbols to GDX files
$offEmbeddedCode
$endif

*================================================================================
* SECTION 4: DATA PROCESSING AND PARAMETER CALCULATION
*================================================================================
* This section processes raw data, calculates derived parameters, and prepares
* all parameters for use in the optimization models.
*================================================================================
$iftheni %CROP%==on
* Process crop loss data
p_crop_loss(hhold,inout)=p_crop_loss_raw(hhold,inout,'value');

* Process and map raw crop data to model parameters
p_cropCoef(hhold,crop_activity,field,inten,NameSeed)  = p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_kg_ha");
p_cropCoef(hhold,crop_activity,field,inten,NameNitr)  = p_cropCoef_raw(hhold,crop_activity,field,inten,"nitr_kg_ha");
p_cropCoef(hhold,crop_activity,field,inten,NameYield) = p_cropCoef_raw(hhold,crop_activity,field,inten,"yield_kg_ha");
p_cropCoef(hhold,crop_activity,field,inten,NameStraw) = p_cropCoef_raw(hhold,crop_activity,field,inten,"ystraw_kg_ha");
p_cropCoef(hhold,crop_activity,field,inten,NamePhyto) = p_cropCoef_raw(hhold,crop_activity,field,inten,"phyto_localCurrency_ha");
p_cropCoef(hhold,crop_activity,field,inten,NameOther) = p_cropCoef_raw(hhold,crop_activity,field,inten,"other_localCurrency_ha");
p_cropCoef(hhold,crop_activity,field,inten,NameArea) = p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha");
p_perresmulch(inout)=p_resmulch(inout);

* Process seed data
p_seedData(hhold,crop_activity,NameseedOnFarm) =  smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_onFarm_ha"));
p_seedData(hhold,crop_activity,NameseedTotal)= smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_kg_ha"));

* Create mapping of households to crops they produce
hhold_crop_map(hhold,crop_activity) = 
    sum((field,inten), p_cropCoef_raw(hhold,crop_activity,field,inten,"yield_kg_ha")) > 0;

* Calculate land area by field type
p_landField(hhold,field)=sum((inten,crop_activity,NameArea),p_cropCoef(hhold,crop_activity,field,inten,NameArea));
display p_landField;

* Process labor requirements by task
p_labReqTask(hhold,crop_activity,inten,NamePlanting) =  labReqTask(hhold,crop_activity,inten,"plant_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameWeeding)  =  labReqTask(hhold,crop_activity,inten,"weed_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameHerbicide)=  labReqTask(hhold,crop_activity,inten,"herb_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameChe_fert) =  labReqTask(hhold,crop_activity,inten,"chemfer_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameOrg_fert) =  labReqTask(hhold,crop_activity,inten,"orgfer_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NamePesticide)=  labReqTask(hhold,crop_activity,inten,"pest_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameHarvest)  =  labReqTask(hhold,crop_activity,inten,"harv_persday_ha");

* Calculate total monthly labor requirements (sum of all tasks in each month)
p_laborReq(hhold,crop_activity,inten,m) = sum(c_t_m(crop_activity,task,m), p_labReqTask(hhold,crop_activity,inten,task) );
$endif
*================================================================================
* SECTION 4.1: FARM AND HOUSEHOLD DATA PROCESSING
*================================================================================

* Calculate farm data parameters
p_farmData(hhold,'allc',field,'cropland') = sum((crop_activity,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
p_farmData(hhold,'allc','total','cropland') = sum((crop_activity,field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
p_farmData(hhold,'labor','family','total')  =  farmlabData_raw(hhold,'fam_m_persday_ha')+ farmlabData_raw(hhold,'fam_f_persday_ha');

* Save farm data to GDX file
execute_unload 'DATA%system.DirSep%farm_data_load_%region%_new.gdx' p_farmData, p_farm_loss;

*================================================================================
* SECTION 4.2: HOUSEHOLD CONSUMPTION DATA PROCESSING
*================================================================================

* Process household demographic and economic data
p_hholdData(hhold,'hh_size')        = hholdData_raw(hhold,'hh_size');
p_hholdData(hhold,'lab_family')     = p_farmData(hhold,'labor','family','total');
p_hholdData(hhold,'inc_offfarm')    = hholdData_raw(hhold,'inc_offfarm');
p_consoData(hhold,gd,'ave') = consodata_raw(hhold,gd,'average');

*================================================================================
* SECTION 4.3: PRICE DATA PROCESSING AND CURRENCY NORMALIZATION
*================================================================================

* Process raw price data and normalize to standard currency
p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice');
p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice');
p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price');
$iftheni %CROP%==on
p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg');

* Normalize all prices using scalar (convert from local currency to USD or standard unit)
p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)= p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)/p_pricescalar;
p_cropCoef(hhold,crop_activity,field,inten,NameOther)= p_cropCoef(hhold,crop_activity,field,inten,NameOther)/p_pricescalar;
$endIf


p_hholdData(hhold,'inc_offfarm')=p_hholdData(hhold,'inc_offfarm')/p_pricescalar;

p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice')/p_pricescalar;
p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice')/p_pricescalar;
p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price')/p_pricescalar;
$iftheni %CROP%==on
p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg')/p_pricescalar;
$endIf

p_distanceprice(hhold)=cpriData_raw(hhold,'distance_km','buyPrice')/p_pricescalar;

* Extract buying and selling prices for convenience
p_selPrice(hhold,inout)=  p_cpriData(hhold,inout,'selprice');
p_buyPrice(hhold,inout)=  p_cpriData(hhold,inout,'buyprice');
$iftheni %CROP%==on
p_seedbuypri(hhold,crop_activity)= p_spriData(hhold,crop_activity,'seedPrice');
$endIf

* Save processed data to GDX files
execute_unload 'DATA\crop_data_load_%region%_new.gdx' p_cropCoef, p_perresmulch, p_residuedep, p_labReqTask, p_laborReq, p_seedData,previouscrop,p_crop_loss ;
execute_unload 'DATA\household_data_load%region%_new.gdx' p_hholdData, p_consoData, p_MaxHiredLabor, p_raw_workTimeMax;
execute_unload 'DATA\price_data_load%region%_new.gdx' p_cpriData, p_gpriData, p_spriData;

*================================================================================
* SECTION 5: CROP MODULE INITIALIZATION (Conditional)
*================================================================================
* This section defines crop-related variables and initial values when the crop module is active
*================================================================================

* Define consumption-related variables (used across modules)
positive variable
  v_selfCons(hhold,inout,year)          'Self-consumption quantity (kg)'
  v_markSales(hhold,inout,year)         'Market sales quantity (kg)'
  v_prodQuant(hhold,inout,year)         'Total production quantity (kg)'
;

$iftheni %CROP%==on

* Initialize crop activity coefficients from loaded data
v0_Yld_C(hhold,crop_activity,'allp',field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield));

* Assume similar yields for all preceding crops (simplification)
v0_Yld_C(hhold,crop_activity,crop_preceding,field,inten) $(c_c(crop_activity,crop_preceding)) = 
    v0_Yld_C(hhold,crop_activity,'allp',field,inten);

* Initialize cropland allocation
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea));
display v0_Land_C;
v0_Use_Land_C(hhold,field) = sum(crop_activity, v0_Land_C(hhold,crop_activity,field));

* Initialize planting area
V0_Plant_C(hhold,crop_activity,'allp',field,inten) = sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
V0_Plant_C(hhold,crop_activity,previouscrop,field,inten) = V0_Plant_C(hhold,crop_activity,'allp',field,inten);

* Calculate crop production quantities
v0_Prd_C(hhold,crop_activity,field,inten) = 
    sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield)) * 
    sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));

* Create mapping for fields with positive crop production
fieldcrop(hhold,field,crop_activity)$(sum(inten,v0_Prd_C(hhold,crop_activity,field,inten)) > 0) = yes;

* Calculate total production quantities by product
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), 
    sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield)) * 
    sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));

v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), 
    sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw)) * 
    sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));

* Set input requirements (excluding labor)
p_inputReq(hhold,crop_activity_endo,field,inten,inpq) $(not NameLabor(inpq)) = 
    p_cropcoef(hhold,crop_activity_endo,field,inten,inpq);
p_inputReq(hhold,crop_activity_endo,field,inten,inpv) = 
    p_cropcoef(hhold,crop_activity_endo,field,inten,inpv);

* Initialize input use and costs
V0_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), 
    p_cropCoef(hhold,crop_activity,field,inten,NameArea) * 
    p_inputReq(hhold,crop_activity,field,inten,i));

V0_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm);
V0_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal);
v0_inputCost(hhold,crop_activity_endo,inpv)=sum((field,inten),p_cropcoef(hhold,crop_activity_endo,field,inten,inpv));

* Define crop module variables
variable
  V_annualGM_C(hhold,year)              'Income from cropping activities (normalized currency)'
;

positive variable
  V_Plant_C(hhold,crop_activity,crop_activity,field,inten,year)      'Crop activity level (ha)'
  v_Prd_C(hhold,crop_activity,field,inten,year)          'Crop production (kg)'
  v_Yld_C(hhold,crop_activity,crop_activity,field,inten,year)      'Crop yield (kg/ha)'
  v_Land_C(hhold,crop_activity,field,year)               'Crop area by soil type (ha)'
  v_Land_C_Agg(hhold,crop_activity,year)               'Crop area aggregated across soil types (ha)'
  v_Use_Land_C(hhold,field,year)                   'Total cropland used (ha)'
  V_FamLabor_C(hhold,year,m)                     'Family labor for crops (person-days)'
  V_HLabor_C(hhold,year,m)                     'Hired labor for crops (person-days)'
  V_Use_Input_C(hhold,crop_activity,inout,year)              'Input usage (kg)'
  V_Use_Seed_C(hhold,crop_activity,year)                   'Seed quantity (kg)'
  v_residuesfeedm(hhold,inout,year,m)           'Monthly crop residues for livestock feed (kg)'
  v_residuesmulch(hhold,inout,year)             'Crop residues for mulch (kg)'
  v_residuesfeed(hhold,inout,year)              'Crop residues for livestock feed (kg)'
  v_residuessell(hhold,inout,year)              'Crop residues sold (kg)'
  v_residuessellm(hhold,inout,year,m)           'Monthly crop residues sold (kg)'
  V_Sale_C(hhold,year)                'Crop sales revenue (normalized currency)'
  V_VarCost_C(hhold,year)                'Variable crop costs (normalized currency)'
  V_Nfert_C(hhold,y)                        'Chemical fertilizer quantity (kg)'
  v_seedOnfarm(hhold,crop_activity,year)          'On-farm seed use (kg)'
  v_seedPurch(hhold,crop_activity,year)           'Purchased seed (kg)'
  v_feedOnfarm(hhold,inout,year)        'On-farm feed use (kg)'
;

* Create mapping for harvest timing of co-products
* Set c_t_m_map(cken, m) to yes if harvest occurs in month m for activity crop_activity_endo
loop((crop_activity_endo, cken)$activity_output(crop_activity_endo, cken),
  c_t_m_map(cken, m)$c_t_m(crop_activity_endo, 'harvest', m) = yes;
);

$endif

*================================================================================
* SECTION 6: AGROFORESTRY MODULE INITIALIZATION (Conditional)
*================================================================================
* This section initializes tree crop parameters and variables when the agroforestry module is active
*================================================================================

$iftheni %ORCHARD%==on

* Initialize pressure factor (for growth constraints)
pressuretree(hhold,c_tree,field,inten)=1;

* Load tree life cycle parameters
harvestingAge_tree(c_tree)=type_age_tree("harvesting age",c_tree);
oldAge_tree(c_tree)=type_age_tree("old age",c_tree);
life_tree(c_tree)=type_age_tree("life",c_tree);

* Display tree parameters for debugging
display harvestingAge_tree, life_tree, oldAge_tree, p_buyPrice_tree_LocalCur, 
        v0_Yld_C_tree age_tree, v0_Age_AF v0_cropCoef_AF, c_t_m_orchard,
        p_taskLabor_cost_LocalCur, Labor_Task_AF, task_tree;

* Calculate field suitability for agroforestry
p_field_AF(hhold,field)=sum((c_tree,inten),v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha"));
display p_field_AF;

* Define agroforestry task sets
NamePlantingAF('planting') = yes;
NameWeedingAF('weeding') = yes;
NameGrubbAF('grubbingup') = yes;
NameChe_fertAF('che_fert') = yes;
NameOrg_fertAF('org_fert') = yes;
NamePesticideAF('pesticide') = yes;
NameHarvestAF('harvest') = yes;
NamePruningAF('pruning') = yes;

* Define age class sets
NameYoung('young') = yes;
NameAdult('adult') = yes;
NameOld('old') = yes;

* Define cost and input categories
NameNitrAF('nitr_kg_ha') = yes;
NamePlantsAF('plants_nb_ha') = yes;
NameNitrPrice('nitr_price_kg') = yes;
NamePlantsPrice('plant_price_nbr') = yes;

* Create mapping for tree products
c_treej(outm) = yes $(sum(activity_output(c_tree,outm),1));
a_c_treej(c_tree,c_treej) $(activity_output(c_tree,c_treej)) = yes ;

* Initialize agroforestry area by age class
V0_Area_AF(hhold,field,c_tree,age_tree,inten)=v0_Age_AF(c_tree,field, age_tree)*
    v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha");
display V0_Area_AF;
*Create mapping linking field to tree and crop for buffer needed
$ifi %CROP%==on fieldcrop_tree(hhold,field)$(    sum((crop_activity,inten), v0_Prd_C(hhold,crop_activity,field,inten)) > 0     AND     sum((c_tree,age_tree,inten), v0_Area_AF(hhold,field,c_tree,age_tree,inten)) > 0) = yes;


* Process agroforestry costs (normalize to standard currency)
v0costPhyto_AF(hhold,c_tree,field,inten) = 
    (v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha")/p_pricescalar)$ 
    v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha");
v0costOther_AF(hhold,c_tree,field,inten)=
    v0_cropCoef_AF(hhold,c_tree,field,inten,"other_localCurrency_ha")/p_pricescalar;

* Process labor costs and input prices
p_taskLabor_cost(c_tree,task_tree)=p_taskLabor_cost_LocalCur(c_tree,task_tree)/p_pricescalar;
p_buyPrice_tree(inputprice_tree,c_tree)=p_buyPrice_tree_LocalCur(inputprice_tree,c_tree)/p_pricescalar;

* Process labor requirements by task
p_Labor_Task_AF(hhold,c_tree,inten,NamePlantingAF) =  Labor_Task_AF(hhold,c_tree,inten,"plant_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameWeedingAF)  =  Labor_Task_AF(hhold,c_tree,inten,"weed_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameGrubbAF)=  Labor_Task_AF(hhold,c_tree,inten,"grubb_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameChe_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"chemfer_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameOrg_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"orgfer_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NamePesticideAF)=  Labor_Task_AF(hhold,c_tree,inten,"pest_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameHarvestAF)  =  Labor_Task_AF(hhold,c_tree,inten,"harv_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NamePruningAF)  =  Labor_Task_AF(hhold,c_tree,inten,"prun_persday_ha");

* Calculate monthly labor requirements (sum of tasks in each month)
p_laborReq_AF(hhold,c_tree,inten,m) = 
    sum(c_t_m_orchard(c_tree,task_tree,m), p_Labor_Task_AF(hhold,c_tree,inten,task_tree));

* Define agroforestry variables
Positive Variable
    V_Area_AF(hhold,field,c_tree,age_tree,inten,y) 'Tree area by age class (ha)'
    v_Prd_AF(hhold,c_tree, y) 'Tree product production (kg)'    
    V_FamLabor_AF(hhold,y,m) 'Family labor for agroforestry (person-days)'
    V_Nfert_AF(hhold,c_tree,y) 'Nitrogen fertilizer for trees (kg)'
    V_Phyto_AF(hhold,y) 'Phytosanitary costs (normalized currency)'
    V_other_AF(hhold,y) 'Other costs (normalized currency)'
    V_PlantsNB_AF(hhold,c_tree,y) 'Number of plants (units)'
    V_HLabor_AF(hhold,y,m) 'Hired labor for agroforestry (person-days)'
    V_VarCost_AF(hhold,y) 'Variable costs (normalized currency)'
    V_Sale_AF(hhold,y) 'Sales revenue (normalized currency)'
;

$onExternalOutput
Variable
    V_annualGM_AF(hhold,y) 'Total benefit from agroforestry (discounted)'
;
$offExternalOutput

$endif

*================================================================================
* SECTION 7: LIVESTOCK MODULE INITIALIZATION (Conditional)
*================================================================================
* This section initializes livestock parameters and variables when the livestock module is active
*================================================================================
$iftheni %LIVESTOCK_simplified%==on
* Process livestock prices
p_selPriceLivestock(hhold,type_animal,ak) = p_selPriceLivestock_raw(hhold,type_animal,ak)/p_pricescalar;
p_selPriceLivestock(hhold,type_animal,'liveanimal') =    p_selPriceLivestock_raw(hhold,type_animal,'liveanimal')/p_pricescalar;
* Process yield data
p_yieldLivestock(hhold,type_animal,akmeat,age) = p_yieldLivestock_raw(hhold,type_animal,akmeat,age,'yield');
p_yieldLivestock(hhold,type_animal,akmilk,age) = p_yieldLivestock_raw(hhold,type_animal,akmilk,age,'yield');
* Assign economic parameters from raw data
p_othCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_othCostLivestock')/p_pricescalar;
p_costVeterinary(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_costVeterinary')/p_pricescalar;
p_AdditionalCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_AdditionalCostLivestock')/p_pricescalar;
* Process biological parameters of livestock
p_Repro(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_BirthRate');       
p_MortalityRate(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_MortalityRate');   
p_LaborReqLivestock(hhold,type_animal,m) = p_DataLive(hhold,type_animal,'1','p_LaborReq')/12;        
p_prot_metab(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_prot_metab');       
p_ca(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_ca');   
p_initPopulation(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_initPopulation');
* Process feed prices
p_feed_price(hhold,feedc)=p_feed_price_LocalCur(hhold,feedc)/p_pricescalar;
* Create product mappings
a_k(type_animal,ak)$activity_output(type_animal,ak) = yes;
akmilk(ak) = yes;
* Define livestock variables
positive variables
    v_FeedPurchase(hhold,feedc,y)     'Purchased feed (kg)'
    v_residuesbuy(hhold,inout,y)      'Purchased crop residues (kg)'
    v_FeedConsumed(hhold,feedc,type_animal,y)     'Feed consumed (kg)'
    V_FamLabor_A(hhold,m,y)    'Family labor for livestock (person-days)'
    v_FeedAvailable(hhold,feedc,y)    'Feed available (kg)'
    v_ManureProd(hhold,type_animal,y)       'Manure production (kg)'
    V_HLabor_A(hhold,m,y)  'Hired labor for livestock (person-days)'
    v_NitrogenOutput_Sell(hhold,y)     'Nitrogen output sold (kg)'
    v_NitrogenOutput_OnFarm(hhold,y)   'Nitrogen output used on farm (kg)'
    V_FixCost_A(hhold,y)               'Fixed costs (normalized currency)'
;
Integer Variable
    V_animals(hhold,type_animal,age,y)   'Animal population (heads)'
    v_Slaughter(hhold,type_animal,age,y)    'Animals slaughtered (heads)'
    V_NewPurchased(hhold,type_animal,age,y)    'Animals purchased (heads)'
    v_NewBorns(hhold,type_animal,age,y)    'Newborn animals (heads)'
    v_Mortality(hhold,type_animal,age,y)   'Animal mortality (heads)'
;
Positive Variable
    V_Revenue_A(hhold,y)      'Total livestock revenue (normalized currency)'
    V_VarCost_A(hhold,y)         'Total variable cost (normalized currency)'
    v_NitrogenOutput(hhold,type_animal,y)  'Nitrogen output (kg)'
    V_veterinary_A(hhold,y)    'Veterinary costs (normalized currency)'
    V_other_A(hhold,y)         'Other costs (normalized currency)'
    V_additional_A(hhold,y)    'Additional costs (normalized currency)'
;

$onExternalOutput
variables
    V_annualGM_A(hhold,y)       'Total livestock benefit (normalized currency)'
;
$offExternalOutput

$endif

*================================================================================
* SECTION 8: VALUE CHAIN MODULE INITIALIZATION (Conditional)
*================================================================================
* This section initializes market actors and transaction parameters
*================================================================================

$iftheni %VALUECHAIN%==on

* Define cost categories
NamecostVeterinary('costVeterinary') = yes;
NameothCostLivestock('othCostLivestock') = yes;
NameAdditionalCostLivestock('AdditionalCostLivestock') = yes;

* Process buyer parameters
p_capacity_buyer(inout,buyer)=P_buyer(inout,buyer,"p_capacity_buyer");
p_labor_buyer(inout,buyer)=P_buyer(inout,buyer,"p_labor_buyer");
p_distance_buyer(hhold,buyer)=p_distance(hhold,buyer);
p_price_buyer(inout,buyer)=P_buyer(inout,buyer,"p_price_buyer")/p_pricescalar;

* Process crop seller parameters (if crop module active)
$iftheni %CROP%==on
p_capacity_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_capacity_seller");
p_labor_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_labor_seller");
p_distance_seller_C(hhold,seller_C)=p_distance(hhold,seller_C);
p_price_seller(inout,seller_C)=P_seller_C(inout,seller_C,"p_price_seller")/p_pricescalar;

p_capacity_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_capacity_seeder");
p_labor_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_labor_seeder");
p_distance_seeder(hhold,seeder)=p_distance(hhold,seeder);
p_price_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_price_seeder")/p_pricescalar;
$endif

* Process livestock seller parameters (if livestock module active)
$iftheni %LIVESTOCK_simplified%==on
p_capacity_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_labor_seller");
p_distance_seller_A(hhold,seller_A)=p_distance(hhold,seller_A);

p_capacity_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_labor_seller");

p_capacity_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_labor_seller");

p_capacity_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller (type_animal,Livestock_seller,"p_capacity_seller");
p_distance_Livestock_seller(hhold,Livestock_seller)=p_distance(hhold,Livestock_seller);
p_labor_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller(type_animal,Livestock_seller,"p_labor_seller");

p_capacity_Feed_seller(feedc,Feed_seller)=P_Feed_seller (feedc,Feed_seller,"p_capacity_seller");
p_distance_Feed_seller(hhold,Feed_seller)=p_distance(hhold,Feed_seller);
p_labor_Feed_seller(feedc,Feed_seller)=P_Feed_seller(feedc,Feed_seller,"p_labor_seller");
p_price_Feed_seller(feedc,Feed_seller)=P_Feed_seller(feedc,Feed_seller,"p_price_seller")/p_pricescalar;
p_price_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller(type_animal,Livestock_seller,"p_price_seller")/p_pricescalar;

loop(inout_a,
    p_capacity_seller_A(inout_a,seller_A) = P_seller_A(inout_a,seller_A,"p_capacity_seller");
    p_labor_seller_A(inout_a,seller_A)    = P_seller_A(inout_a,seller_A,"p_labor_seller");
);
$endif

* Process agroforestry seller parameters (if agroforestry module active)
$iftheni %ORCHARD%==on
p_capacity_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_capacity_seller");
p_labor_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_labor_seller");
p_distance_seller_AF(hhold,seller_AF)=p_distance(hhold,seller_AF);
p_price_seller(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_price_seller")/p_pricescalar;
$endif

* Define value chain variables
positive Variable
v_transportCost_seller(hhold,y) "Transport cost from sellers to households"
v_transportCost_buyer(hhold,y)  "Transport cost from households to buyers"
v_laborSellerInput(y)           "Total labor input from sellers"
v_laborBuyerOutput(y)           "Total labor output for buyers"
v_outputBuyer(hhold,inout,buyer,y)    "Quantity sold to buyers"
v_inputSeller_C(hhold,inout,seller_C,y)   "Quantity purchased from sellers (crops)"
v_inputSeller_AF(hhold,inout,seller_AF,y)   "Quantity purchased from sellers (agroforestry)"
v_inputSeller_A(hhold,*,seller_A,y)   "Quantity purchased from sellers (animals)"
v_laborSeller_A(y)                  "Labor for animal seller transactions"
v_transportCost_crop(hhold,y)        "Transport cost for crops"
v_transportCost_orchard(hhold,y)     "Transport cost for orchard products"
V_TransportCost_A(hhold,y)           "Transport cost for livestock"
v_seedSeeder(hhold,crop_activity,seeder,y)   "Seed purchases from suppliers"
v_laborSeeder(y)                             "Labor for seed transactions"
v_transportCost_seeder(hhold,y)              "Transport cost for seeds"
v_Livestock_seller(hhold,type_animal,Livestock_seller,y) "Livestock purchased"
v_laborLivestock_seller(y)                               "Labor for livestock transactions"
v_transportCost_Livestock_seller(hhold,y)                "Transport cost for livestock"
v_laborSeller_AF(y)                                      "Labor for agroforestry seller transactions"
v_Feed_seller(hhold,feedc,Feed_seller,y)                 "Feed purchased"
v_laborFeed_seller(y)                                    "Labor for feed transactions"
v_transportCost_Feed_seller(hhold,y)                     "Transport cost for feed"
v_GHG(hhold,y)                                           "Total GHG emissions"
v_GHG_C(hhold,y) "GHG emissions from crops"
v_GHG_AF(hhold,y) "GHG emissions from agroforestry"
v_GHG_livestock(hhold,y) "GHG emissions from livestock"
;

$endif

*================================================================================
* SECTION 9: PMP CALIBRATION INITIALIZATION (Conditional)
*================================================================================
* Initialize PMP parameters for Positive Mathematical Programming calibration
*================================================================================

$iftheni %CROP%==on
PMPint(hhold,crop_activity_endo) = 0;
PMPslope(hhold,crop_activity_endo) = 0;
$endif
*================================================================================
* SECTION 10: BIOPHYSICAL MODULE INITIALIZATION (Conditional)
*================================================================================
* Initialize water balance and nitrogen dynamics parameters
*================================================================================

$iftheni %BIOPH%==on
* Create union of crops and trees for biophysical module
$ifi %CROP%==ON crop_and_tree(crop_activity) = yes;
$ifi %ORCHARD%==ON crop_and_tree(c_tree) = yes;
* Define irrigation cost and capacity variables
POSITIVE variable
 v_costirr_crop(hhold,y)       'Irrigation cost for crops (normalized currency)'
 v_costirr_tree(hhold,y)      'Irrigation cost for trees (normalized currency)';
* Initialize biophysical calibration parameters
calibBioph(hhold,crop_activity,crop_preceding,field,inten)=eps;
* Set maximum irrigation capacity
$ifi %BIOPH%==ON v0_max_irrigation(hhold,crop_and_tree,field,inten,m,y)=irrigation_raw(hhold,'v0_max_irrigation');
$ifi %BIOPH%==ON p_cost_irrigation(hhold)=irrigation_raw(hhold,'p_cost_irrigation');
$endIf

*================================================================================
* SECTION 11: NITROGEN CYCLE INITIALIZATION
*================================================================================
* Initialize nitrogen dynamics parameters for annual optimization
*================================================================================
* INITIALIZATION of nitrogen value
*initial organic amount
p_norg(hhold) = p_norg_raw;
*initial amount of residue nitrogen
p_Nres(hhold,ck,field,inten) = p_Nres_raw;
* Maximum annual fertilizer application (kg/ha)
p_nfert_max_annual(hhold,crop_activity_endo,field,inten) = p_nfert_max_annual_raw;

*================================================================================
* SECTION 12: DIVERSITY INDEX AND ENERGY MODULE INITIALIZATION
*================================================================================
* Initialize diversity and energy accounting variables
*================================================================================

* Diversity index variables
positive variable
    overall_cv          'Coefficient of variation for diversity'
    total_sum            'Total sum of observations'
    mean_val             'Mean value'
    variance_val         'Variance'
    std_dev              'Standard deviation'
;
variable
cv_val                   'Coefficient of variation'
V_Total_ValueChain_Labor 'Total value chain labor'
V_GHGtotal               'Total GHG emissions'
;

$iftheni %ENERGY%==on
variable
    V_energy(hhold,y)    'Total energy consumption (MJ)'
;

* Process energy requirements for agroforestry (if active)
$iftheni %ORCHARD%==on
p_energy_task_AF(hhold,c_tree,inten,NamePlantingAF) =  enerReqtask_AF(hhold,c_tree,inten,"plant_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameGrubbAF)=enerReqtask_AF(hhold, c_tree,inten,"grubb_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameChe_fertAF) =  enerReqtask_AF(hhold, c_tree,inten,"chemfer_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameWeedingAF)=enerReqtask_AF(hhold, c_tree,inten,"weed_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameOrg_fertAF) =  enerReqtask_AF(hhold, c_tree,inten,"orgfer_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NamePesticideAF)=  enerReqtask_AF(hhold, c_tree,inten,"pest_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameHarvestAF)  =  enerReqtask_AF(hhold, c_tree,inten,"harv_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NamePruningAF)  =  enerReqtask_AF(hhold, c_tree,inten,"prun_MJ_ha");
p_energy_AF(hhold,c_tree,inten,m) = sum(c_t_m_orchard(c_tree,task_tree,m), 
    p_energy_task_AF(hhold,c_tree,inten,task_tree));
$endIf

* Process energy requirements for crops (if active)
$iftheni %CROP%==on
p_energy_task_crop(hhold,crop_activity,inten,NamePlanting) =  enerReqtask_crop(hhold,crop_activity,inten,"plant_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameWeeding)  =  enerReqtask_crop (hhold,crop_activity,inten,"weed_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameHerbicide)=  enerReqtask_crop (hhold,crop_activity,inten,"herb_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameChe_fert) =  enerReqtask_crop(hhold,crop_activity,inten,"chemfer_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameOrg_fert) =  enerReqtask_crop(hhold,crop_activity,inten,"orgfer_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NamePesticide)=  enerReqtask_crop(hhold,crop_activity,inten,"pest_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameHarvest)  =  enerReqtask_crop(hhold,crop_activity,inten,"harv_MJ_ha");
p_energy_crop(hhold,crop_activity,inten,m) = sum(c_t_m(crop_activity,task,m), 
    p_energy_task_crop(hhold,crop_activity,inten,task));
$endIf
$endIf

$exit
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
*-- Year set definitions

$setglobal FstAnte 2025
$setglobal LstPost 2027
$setglobal FstYear 2025
$setglobal LstYear 2027


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
  input         'all input categories'    /set.input_quantity,set.input_value/
  output        'all output categories'   /set.cmpro,set.ccpro/
  inout         'combined inputs/outputs' /set.input,set.output/
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #4 Define sub-sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  inpq(inout)   'quantity inputs'     /set.input_quantity/
  inpv(inout)   'value inputs'        /set.input_value/
  outm(inout)   'main products'       /set.cmpro/
  outc(inout)   'by-products'         /set.ccpro/
  feed(inout)   'feed sources'        /set.inout/
 ;

* Load region-specific settings (region definitions, specific parameters)



*set  yy(year) 'ex-post and ex-ante years' /%FstAnte%*%LstPost%/;
set  y2(year) 'simulation years' /%FstYear%*%LstYear%/;
*if you put a bigger value it cause issue with pmp
set  y(year)  'model years'      /y01*y02/; 

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
*================================================================================
* SECTION 1: CROP PRODUCTION PARAMETERS
* Core coefficients and requirements for crop-based agricultural activities
*================================================================================

*------------------------------------------------------------------------------
* 1.1 Primary Crop Production Parameters
*------------------------------------------------------------------------------
parameters
  p_cropCoef(hhold,crop_activity,field,inten,*)   'Input-output coefficients for crop activities (yield, inputs, outputs per ha)'
  p_labReqTask(hhold,crop_activity,inten,task)    'Labor requirements disaggregated by specific task type (person-days per ha)'
  p_laborReq(hhold,crop_activity,inten,m)         'Total monthly labor requirements aggregated across tasks (person-days per ha)'
  p_seedData(hhold,crop_activity,*)              'Seed utilization data: on-farm saved vs purchased seeds (kg per ha)'
  
*------------------------------------------------------------------------------
* 1.2 Crop Residue Management Parameters
*------------------------------------------------------------------------------
  p_perresmulch(inout)                           'Percentage of crop residue allocated to mulch applications'
  
*------------------------------------------------------------------------------
* 1.3 Farm and Household Data Parameters
*------------------------------------------------------------------------------
  p_farmData(hhold,*,*,*)                        'Comprehensive farm-level data (land allocation, labor supply, capital)'
  p_consoData(hhold,good,*)                      'Household consumption patterns and quantities'
  p_hholdData(hhold,hvar)                        'Household demographic and economic characteristics (size, income, assets)'
  
*------------------------------------------------------------------------------
* 1.4 Price Parameters for Agricultural Markets
*------------------------------------------------------------------------------
  p_cpriData(hhold,inout,*)                      'Crop transaction prices (buying and selling)'
  p_apriData(hhold,inout,*)                      'Animal product market prices'
  p_gpriData(hhold,good,*)                       'Non-agricultural goods prices for household consumption'
  p_spriData(hhold,crop_activity,*)              'Seed purchase prices by crop type'
  p_pricescalar                                  'Currency conversion scalar for price normalization'
  p_selPrice(hhold,inout)                        'Net selling price for crops (normalized currency/kg)'
  p_buyPrice(hhold,inout)                        'Net buying price for crops (normalized currency/kg)'
  p_seedbuypri(hhold,crop_activity)              'Seed purchase price (normalized currency/kg)'
  
*------------------------------------------------------------------------------
* 1.5 Crop Loss and Land Parameters
*------------------------------------------------------------------------------
  p_crop_loss_raw                                'Raw crop loss data before processing'
  p_crop_loss(hhold,inout)                       'Post-harvest and storage loss percentage by household and crop'
  p_landField(hhold,field)                       'Available land area by household and field type (ha)'
  p_farm_loss(inout)                             'Field-level crop loss rates during production'
  p_MaxHiredLabor                                'Maximum available hired labor in the village (person-days)'
  p_raw_workTimeMax                              'Maximum daily work time per economically active person (hours/day)'
  p_distanceprice(hhold)                         'Distance-based price adjustment factor for market access'
;

*------------------------------------------------------------------------------
* 1.6 Data Loading Auxiliary Parameters (Raw Excel Imports)
*------------------------------------------------------------------------------
parameters
  p_cropCoef_raw(*,*,*,*,*)                      'Unprocessed crop coefficients imported from Excel'
  labReqTask(*,*,*,*)                            'Raw labor requirement data pre-aggregation'
  farmlabData_raw(hhold,*)                       'Unprocessed farm labor supply data'
  outData_raw(hhold,inout,*)                     'Raw agricultural output data'
  hholdData_raw(hhold,*)                         'Unprocessed household survey data'
  consoData_raw(hhold,good,*)                    'Raw household consumption data'
  apriData_raw(hhold,inout,*)                    'Raw animal product price data'
  cpriData_raw(hhold,*,*)                        'Unprocessed crop price data'
  gpriData_raw(hhold,good,*)                     'Raw non-agricultural goods price data'
  spriData_raw(hhold,crop_activity,*)            'Unprocessed seed price data'
  seedData_raw(*,*,*)                            'Raw seed utilization data'
  p_resmulch                                     'Raw residue mulch allocation coefficients'
;

*===============================================================================
* SECTION 2: BASELINE OBSERVATIONS FOR MODEL CALIBRATION
* Observed activity levels from base year data used to calibrate the model
*===============================================================================

parameters
*------------------------------------------------------------------------------
* 2.1 Land Use and Crop Management Observations
*------------------------------------------------------------------------------
  V0_Plant_C(hhold,crop_activity,*,field,inten)   'Observed cropping activity level (hectares cultivated)'
  v0_Land_C(hhold,crop_activity,field)            'Observed crop area by soil/cropping system type (ha)'
  v0_Use_Land_C(hhold,field)                      'Total observed cropland utilization (ha)'
  
*------------------------------------------------------------------------------
* 2.2 Production and Yield Observations
*------------------------------------------------------------------------------
  v0_Prd_C(hhold,crop_activity,field,inten)       'Observed crop production quantity (kg)'
  v0_prodQuant(hhold,inout)                       'Total observed crop output aggregated across activities (kg)'
  p_Yld_C(hhold,crop_activity,*,field,inten)      'Observed crop yield calculated from production/area (kg/ha)'
  p_Yld_C_stress(hhold,*,*,field,inten)           'Observed yield under biophysical stress conditions (kg/ha)'
  
*------------------------------------------------------------------------------
* 2.3 Input Utilization Observations
*------------------------------------------------------------------------------
  p_Use_Input_C(hhold,crop_activity,inout)       'Observed agricultural input use (fertilizer, pesticides) (kg)'
  p_inputCost(hhold,crop_activity,inout)         'Observed expenditure on agricultural inputs (normalized currency)'
  p_Use_Seed_C(hhold,crop_activity,seedbal)      'Observed seed use disaggregated by source (on-farm vs purchased) (kg)'
;

*===============================================================================
* SECTION 3: CROP CALENDAR AND ROTATION MAPPINGS
* Temporal and spatial relationships between crops, fields, and seasons
*===============================================================================

sets
*------------------------------------------------------------------------------
* 3.1 Crop Rotation and Temporal Sets
*------------------------------------------------------------------------------
  previouscrop                                 'Set of preceding crops for multi-year rotation sequences (y-2, y-1)'
  c_t_m_map(inout,m)                          'Mapping of crop products to their primary harvest months'
  
*------------------------------------------------------------------------------
* 3.2 Household-Crop-Field Relationships
*------------------------------------------------------------------------------
  hhold_crop_map(hhold,crop_activity)         'Valid crop-household combinations based on observed production'
  fieldcrop(hhold,field,crop_activity)        'Valid field-crop combinations with positive observed production'
  fieldcrop_tree(hhold,field)                 'Fields currently occupied by tree-crop intercropping systems'
;

*------------------------------------------------------------------------------
* 3.3 Calendar and Iteration Control Sets
*------------------------------------------------------------------------------
sets
  indic(inout,m)              'Indicator matrix for crop-harvest month relationships'
  flag(inout,m)               'Binary flag for month mapping validation'
  flagm(inout,m)              'Month mapping verification flag'
  count                       'Iteration counter for calibration routines'
  stopflag                    'Termination condition flag for iterative processes'
  countm                      'Month counter for temporal iterations'
;

*===============================================================================
* SECTION 4: AGROFORESTRY AND ORCHARD SYSTEMS
* Parameters specific to tree-based agricultural systems including perennial crops
*===============================================================================

sets
*------------------------------------------------------------------------------
* 4.1 Agroforestry Classification Sets
*------------------------------------------------------------------------------
  c_tree                  'Perennial tree crop types (cocoa, coffee, rubber, fruit trees, oil palm)'
  task_tree               'Agroforestry management operations (planting, pruning, harvesting, pest control)'
  ageclass_tree           'Tree age classes for production modeling (young, adult, old/senescent)'
  inputprice_tree         'Input cost categories for tree establishment and maintenance'
  othcost_tree            'Other cost categories for orchard operations'
  age_tree                'Tree age groups for demographic modeling'
  c_t_m_orchard           'Orchard management task timing by month'
  c_treej(inout)          'Tree products included in current simulation period'
  a_c_treej               'Mapping from tree activities to their primary marketed products'
;

*------------------------------------------------------------------------------
* 4.2 Agroforestry Cost Categories
*------------------------------------------------------------------------------
set othcost_tree / 
  other_localCurrency_ha    
  phyto_localCurrency_ha    
  area_ha                   
  nitr_kg_ha                
  plants_nb_ha              
/;

*===============================================================================
* SECTION 5: AGROFORESTRY PARAMETER DECLARATIONS
*===============================================================================

Parameter 
*------------------------------------------------------------------------------
* 5.1 Tree Lifecycle and Development Parameters
*------------------------------------------------------------------------------
  life_tree(c_tree)               'Total economic lifespan of tree species (years until replanting)'
  oldAge_tree(c_tree)             'Age at which production begins declining from peak (years)'
  type_age_tree(*,*)              'Age class definitions and transition parameters'
  harvestingAge_tree(c_tree)      'Age at which best commercial harvest becomes  (years)'
  pressuretree(hhold,c_tree,field,inten) 'Biophysical stress index affecting tree growth and yield'
  
*------------------------------------------------------------------------------
* 5.2 Tree Yield and Economic Parameters
*------------------------------------------------------------------------------
  p_Yld_C_tree(field,*, ageclass_tree<) 'Observed tree yield by field type, variety, and age class (kg/ha)'
  p_selPrice_tree(c_tree)         'Farmgate selling price for tree products (USD/kg)'
  p_buyPrice_tree_LocalCur(inputprice_tree<,c_tree<) 'Purchase prices for tree production inputs (local currency/kg)'
  p_taskLabor_cost(c_tree,task_tree) 'Labor cost disaggregated by tree type and management task'
  p_buyPrice_tree(inputprice_tree,c_tree) 'Input purchase prices normalized to model currency'
  
*------------------------------------------------------------------------------
* 5.3 Initial Tree Stock and Area Distribution
*------------------------------------------------------------------------------
  V0_Area_AF(hhold,field,c_tree,age_tree,inten) 'Initial tree crop area by age class and management intensity (ha)'
  v0_Age_AF(c_tree,field, age_tree) 'Age distribution profile of existing tree stands'
  p_field_AF(hhold,field)          'Binary  indicator for field in agroforestry'
  p_iniprim(hhold,field)            'Initial primary vegetation type before tree establishment'
  
*------------------------------------------------------------------------------
* 5.4 Agroforestry Cost and Labor Parameters
*------------------------------------------------------------------------------
  p_costPhyto_AF                    'Baseline phytosanitary costs for agroforestry (local currency)'
  p_costOther_AF                    'Baseline other operational costs for agroforestry'
  v0_cropCoef_AF(hhold,c_tree,field,inten,othcost_tree) 'Agroforestry input-output coefficients'
  Labor_Task_AF(*,*,*,*)            'unaggregated labor requirements for tree management tasks'
  p_Labor_Task_AF(*,*,*,*)          'aggregated labor requirements for tree tasks (person-days/ha)'
  p_laborReq_AF(*,*,*,*)             'Monthly labor requirement profiles for tree systems'
;

*------------------------------------------------------------------------------
* 5.5 Agroforestry Task Classification
*------------------------------------------------------------------------------
Set 
  NameWeedingAF(task_tree)          'Manual or mechanical weed control operations'
  NameGrubbAF(task_tree)            'Uprooting and removal of old/senescent trees'
  NameChe_fertAF(task_tree)         'Synthetic/inorganic fertilizer application'
  NameOrg_fertAF(task_tree)         'Organic fertilizer and compost application'
  NamePesticideAF(task_tree)        'Pesticide and fungicide application operations'
  NamePruningAF(task_tree)          'Canopy management and branch pruning'
  NameAdult(ageclass_tree)          'Mature, peak-production age class indicator'
  NameHarvestAF(task_tree)          'Fruit/nut harvesting operations'
  NameYoung(ageclass_tree)          'Establishment and juvenile growth phase indicator'
  NameNitrAF(othcost_tree)          'Nitrogen fertilizer application category'
  NameOld(ageclass_tree)            'Senescent, declining production phase indicator'
  NamePlantsAF(othcost_tree)        'Planting material and nursery category'
  NameNitrPrice(inputprice_tree)    'Nitrogen fertilizer price category'
  NamePlantsPrice(inputprice_tree)  'Seedling/planting material price category'
  NamePlantingAF(task_tree)         'Tree planting and establishment operations'
;

*===============================================================================
* SECTION 6: LIVESTOCK PRODUCTION PARAMETERS
* Animal husbandry parameters including feed, reproduction, and product yields
*===============================================================================

sets
*------------------------------------------------------------------------------
* 6.1 Livestock Classification Sets
*------------------------------------------------------------------------------
  age                    'Animal age'
  akmeat(ak)             'Meat product categories '
  akmilk(ak)             'Milk product categories '
  feedc                  'Feed resource types (concentrates, forage, crop residues, grazing)'
  animal_feed(type_animal,feedc) 'Valid feed-animal type combinations for ration formulation'
;

parameters
*------------------------------------------------------------------------------
* 6.2 Livestock Economic Parameters
*------------------------------------------------------------------------------
  p_selPriceLivestock(hhold,type_animal,*) 'Market selling prices for live animals and products (nc/unit)'
  p_othCostLivestock(hhold,type_animal)    'Non-feed operational costs per animal (veterinary, housing, bedding) (nc/head)'
  p_costVeterinary(hhold,type_animal)      'Veterinary service and medicine costs (nc/head/year)'
  p_AdditionalCostLivestock(hhold,type_animal) 'Supplementary costs (marketing, transport, insurance) (nc/head)'
  p_laborPrice                             'Wage rate for agricultural labor (nc/person-day)'
  
*------------------------------------------------------------------------------
* 6.3 Livestock Production and Biological Parameters
*------------------------------------------------------------------------------
  p_Repro(hhold,type_animal,age)           'Reproduction rate by age group (offspring per female per year)'
  p_feedReq(type_animal,*)                 'Daily feed requirements by feed type (kg DM/head/day)'
  p_MortalityRate(hhold,type_animal,age)   'Annual mortality rate by animal age group (% of herd)'
  p_LaborReqLivestock(hhold,type_animal,m) 'Monthly labor requirement per animal (person-days/head/month)'
  p_yieldLivestock(hhold,type_animal,ak,age) 'Product yield by age group (milk l/head/day, meat kg/head)'
  
*------------------------------------------------------------------------------
* 6.4 Animal Nutrition and Feed Quality Parameters
*------------------------------------------------------------------------------
  p_prot_intake(hhold,type_animal)         'Daily crude protein intake requirement (g/head/day)'
  p_prot_metab(hhold,type_animal)          'Protein metabolism coefficient'
  p_ca(hhold,type_animal)                  'CA coefficient'
  p_grossenergy_feed(feedc)                'Gross energy content of feed types (MJ/kg DM)'
  p_protein_feed(feedc)                    'Crude protein content of feeds (% of DM)'
  p_drymatter_feed(feedc)                  'Dry matter content of feeds as-fed basis (%)'

*------------------------------------------------------------------------------
* 6.5 Initial Livestock Populations and Price Data
*------------------------------------------------------------------------------
  p_initPopulation(hhold,type_animal,age)  'Initial animal population by age class (heads)'
  p_DataLive                               'Livestock data'
  p_selPriceLivestock_raw(hhold,type_animal,*) 'Raw loaded livestock product price data'
  p_yieldLivestock_raw                     'Raw livestock yield data by product type'
  p_feed_price_LocalCur(hhold,feedc)       'Local currency feed prices before normalization'
  p_feed_price(hhold,feedc)                'Processed feed prices (normalized currency/kg DM)'
;

*===============================================================================
* SECTION 7: VALUE CHAIN AND MARKET LINKAGES
* Parameters for agricultural market actors, transaction costs, and linkages
*===============================================================================

sets
*------------------------------------------------------------------------------
* 7.1 Market Actor Classification
*------------------------------------------------------------------------------
  seller_C                'Crop wholesale and retail sellers in the value chain'
  seller_AF               'Agroforestry product market intermediaries and exporters'
  seller_A                'Animal product sellers (butchers, dairy cooperatives, collectors)'
  buyer                   'Agricultural input and output buyers (traders, processors, retailers)'
  seeder                  'Seed suppliers and agro-dealers'
  inout_a                 'Agricultural inputs and outputs traded in markets'
  Livestock_seller        'Live animal traders and auction markets'
  Feed_seller             'Commercial feed manufacturers and distributors'
;

*------------------------------------------------------------------------------
* 7.2 Transaction and Market Access Parameters
*------------------------------------------------------------------------------
Parameter
  P_GHG(hhold,*)                           'Greenhouse gas emissions coefficients by activity and source'
  P_buyer(inout,buyer,*)                   'Buyer characteristics matrix (offer prices, quality requirements, payment terms)'
  p_capacity_buyer(inout,buyer)            'Maximum purchase capacity of buyers (kg per period)'
  p_distance(hhold,*)                      'Road distance between household and market actors (km)'
  p_distance_buyer(hhold,buyer)            'Distance from household to buyer locations (km)'
  p_labor_buyer(inout,buyer)               'Labor requirement for buyer transactions (person-days per kg)'
  p_price_buyer                            'Price offers from buyers (normalized currency/kg)'
  p_price_seller                           'Price asks from sellers (normalized currency/kg)'
  p_price_seeder                           'Seed supplier price quotes (nc/kg)'
  p_price_Feed_seller                      'Feed seller price quotes (nc/kg DM)'
  p_price_Livestock_seller                 'Livestock seller price quotes (nc/head)'
;

*------------------------------------------------------------------------------
* 7.3 Cost Category Definitions for Livestock
*------------------------------------------------------------------------------
set inout_a / 
  costVeterinary          
  othCostLivestock        
  AdditionalCostLivestock  
/;

Set 
  NamecostVeterinary(inout_a)           'Veterinary cost identifier'
  NameothCostLivestock(inout_a)         'Other livestock cost identifier'
  NameAdditionalCostLivestock(inout_a)  'Additional cost identifier'
;

*------------------------------------------------------------------------------
* 7.4 Seller Parameter Matrices by Product Category
*------------------------------------------------------------------------------
Parameter
* Crop sellers
  P_seller_C(inout,seller_C,*)              'Crop seller parameters (price, quality, reliability)'
  p_capacity_seller_C(inout,seller_C)       'Crop seller supply capacity (kg per period)'
  p_distance_seller_C(hhold,seller_C)       'Distance from household to crop sellers (km)'
  p_labor_seller_C(inout,seller_C)          'Labor requirement for selling transactions (person-days/kg)'

* Seed suppliers
  P_seeder(crop_activity,seeder,*)          'Seed supplier parameters (variety availability, price)'
  p_capacity_seeder(crop_activity,seeder)   'Seed supplier capacity by crop type (kg)'
  p_distance_seeder(hhold,seeder)           'Distance to seed suppliers (km)'
  p_labor_seeder(crop_activity,seeder)      'Labor for seed purchase transactions (person-days/kg)'

* Animal product sellers
  P_seller_A(*,seller_A,*)                  'Animal product seller parameters'
  p_capacity_seller_A(inout_a,seller_A)     'Seller capacity for animal products (kg or units)'
  p_labor_seller_A(*,seller_A)              'Labor for animal product transactions (person-days/unit)'
  p_distance_seller_A(hhold,seller_A)       'Distance to animal product sellers (km)'

* Livestock sellers
  P_Livestock_seller (type_animal,Livestock_seller,*) 'Live animal seller parameters'
  p_capacity_Livestock_seller(type_animal,Livestock_seller) 'Seller capacity (heads per period)'
  p_distance_Livestock_seller(hhold,Livestock_seller) 'Distance to livestock markets (km)'
  p_labor_Livestock_seller(type_animal,Livestock_seller) 'Transaction labor requirement (person-days/head)'

* Feed sellers
  P_Feed_seller (feedc,Feed_seller,*)       'Commercial feed seller parameters'
  p_capacity_Feed_seller(feedc,Feed_seller) 'Feed supply capacity (kg DM per period)'
  p_distance_Feed_seller(hhold,Feed_seller) 'Distance to feed suppliers (km)'
  p_labor_Feed_seller(feedc,Feed_seller)    'Labor for feed purchase (person-days/kg)'

* Agroforestry product sellers
  P_seller_AF(inout,seller_AF,*)            'Agroforestry product seller parameters'
  p_capacity_seller_AF(inout,seller_AF)     'Agroforestry product purchase capacity (kg)'
  p_distance_seller_AF(hhold,seller_AF)     'Distance to agroforestry buyers (km)'
  p_labor_seller_AF(inout,seller_AF)        'Transaction labor for agroforestry products (person-days/kg)'
;
parameter
  p_inputReq(hhold,crop_activity,field,inten,inout) 'Direct input requirements (fertilizer)';
*===============================================================================
* SECTION 8: POSITIVE MATHEMATICAL PROGRAMMING (PMP) CALIBRATION
* Parameters for calibrating non-linear cost functions to observed baseline data
*===============================================================================

parameter
  delta1                   'Small perturbation parameter for PMP calibration (typically 0.0001)'
  PMPslope(hhold,crop_activity)      'PMP cost function slope coefficient (marginal cost parameter)'
  PMPint(hhold,crop_activity)        'PMP cost function intercept (fixed cost parameter)'
  PMPdualVal(hhold,crop_activity)    'Shadow value from calibration constraint (marginal value of land/resources)'
  PMPSolnCheck(hhold,crop_activity,*) 'Diagnostic matrix comparing calibrated values with observed data'
  PMPswitch                          'Binary switch for PMP calibration stage'
;

Set crop_and_tree(*)                   'Union set of annual crops and perennial trees for biophysical module integration';

*===============================================================================
* SECTION 9: BIOPHYSICAL CROP GROWTH MODELS
* Water balance, evapotranspiration, and nitrogen dynamics parameters
*===============================================================================

parameter
*------------------------------------------------------------------------------
* 9.1 Soil Water Balance Parameters
*------------------------------------------------------------------------------
  p_swd0(hhold,*,field,inten)    'Initial soil water depth at beginning of simulation (mm/month)'
  p_rain                         'Monthly effective rainfall after interception losses (mm/month)'
  p_kc(*,field,inten)            'FAO crop coefficient (Kc) for evapotranspiration calculation'
  p_et0_raw                      'Monthly reference evapotranspiration (ET0) variation (mm/day)'
  p_rdm(*,inten)                 'Maximum effective rooting depth by crop and intensity (m)'
  p_swa(*,field,inten)           'Available soil water holding capacity by crop, field, intensity (mm/m depth)'
  p_swm(field)                   'Maximum soil water storage capacity by field type (mm/m)'
  ym(*,field,inten)              'Maximum potential crop yield under optimal conditions (t/ha)'
  p_factor(*,field,inten)        'Soil water depletion factor (p-factor from FAO 56 Table 22)'
  last_active_month              'Index of the final month of crop physiological activity'
  
*------------------------------------------------------------------------------
* 9.2 Crop Yield Under Stress Conditions
*------------------------------------------------------------------------------
  p_Yld_C(hhold,crop_activity,*,field,inten)       'Observed actual yield under prevailing conditions (t/ha)'
  p_Yld_C_max(hhold,crop_activity,*,field,inten)   'Maximum potential yield with optimal water/nitrogen (t/ha)'
;
Parameter 
p_taskLabor_cost_LocalCur(*,*)  'Labor cost by task (local currency)';
*------------------------------------------------------------------------------
* 9.3 Nitrogen Dynamics Parameters
*------------------------------------------------------------------------------
Parameters
  p_nav_begin_fixed(hhold,field,inten,*,y)   'Fixed initial available soil nitrogen at year start (kg N/ha)'
  p_nmin_fixed(hhold,field,y)                'Fixed mineralized nitrogen from soil organic matter (kg N/ha/year)'
  p_Nres_fixed(hhold,field,y)                'Fixed nitrogen contribution from crop residue decomposition (kg N/ha)'
  p_nl_fixed(hhold,*,field,inten,y)          'Fixed nitrogen leaching losses below rooting zone (kg N/ha)'
  p_nfin_fixed(hhold,field,inten,*,y)        'Fixed final available nitrogen after crop uptake (kg N/ha)'
  p_hini_fixed(hhold,field,y)                'Fixed initial humus/organic matter content (kg C/ha)'
  p_hfin_fixed(hhold,field,y)                'Fixed final humus content after decomposition (kg C/ha)'
  p_nav_fixed(hhold,field,inten,*,y)         'Fixed total available nitrogen profile (kg N/ha)'
  p_nab_fixed(hhold,*,field,inten,y)         'Fixed nitrogen absorbed by crop biomass (kg N/ha)'
  p_nstress_fixed(hhold,*,field,inten,y)     'Fixed nitrogen stress coefficient (0-1, 1=no stress)'
  
*------------------------------------------------------------------------------
* 9.4 Water Stress and Irrigation Parameters
*------------------------------------------------------------------------------
  p_irrigation_opt_fixed(hhold,*,field,inten,m,y) 'Fixed optimal irrigation requirement (mm/month)'
  p_KS_month_fixed(hhold,*,field,inten,m,y)      'Fixed monthly water stress coefficient (0-1, 1=no stress)'
  p_DR_start_fixed(hhold,*,field,inten,m,y)      'Fixed soil water depletion at month start (mm)'
  p_DR_end_fixed(hhold,*,field,inten,m,y)        'Fixed soil water depletion at month end (mm)'
  p_KS_avg_annual_fixed(hhold,*,field,inten,y)   'Fixed annual average water stress index'
  p_DR_excess_fixed(hhold,*,field,inten,m,y)     'Fixed excess water (runoff + deep drainage) (mm)'
  p_KS_total_fixed(hhold,*,field,inten,m,y)      'Fixed cumulative water stress over growing season'
  p_b_KS_fixed(hhold,*,field,inten,m,y)          'Fixed binary indicator for water stress occurrence (1=stress present)'
  p_b_DR_negative_fixed(hhold,*,field,inten,m,y) 'Fixed binary indicator for water deficit (1=deficit)'
;

parameter 
    pressureCrop(hhold, crop_activity, crop_activity, field, inten)   "Combined stress pressure on crops"
    diffyield(hhold, crop_activity, crop_activity, field, inten)      "Yield difference due to stress"
;

Positive Variable
v_norg_crop(hhold)
v_ncomp_crop(hhold)
v_ncomp_tree(hhold)
v_norg_tree(hhold);
*------------------------------------------------------------------------------
* 9.6 Soil Water Holding Capacity Parameters
*------------------------------------------------------------------------------
Parameter
  TAW(hhold,*,field,inten)                    'Total Available Water in root zone (mm)'
  RAW(hhold,*,field,inten,m,y)                'Readily Available Water after allowing for stress (mm)'
  CR(hhold,*,field,inten)                     'Capillary Rise from water table (mm/month)'
  days_in_month(m)                            'Number of days in each month for water balance calculations'
  ET0_month(hhold,*,field,inten,m,y)          'Monthly reference evapotranspiration adjusted for location (mm/month)'
;

*===============================================================================
* SECTION 10: SOIL NITROGEN CYCLE PARAMETERS
* Comprehensive nitrogen transformation and cycling parameters
*===============================================================================

parameter
*------------------------------------------------------------------------------
* 10.1 General Nitrogen Cycle Parameters
*------------------------------------------------------------------------------
  calibBioph(hhold,crop_activity,*,field,inten)  'Biophysical calibration parameters for model fitting'
  p_cropCoef(hhold,crop_activity,field,inten,*)  'Crop coefficients (redeclaration for completeness)'
  p_Nini(hhold,field)                            'Initial soil inorganic nitrogen content (kg N/ha)'
  p_Nini_raw                                     'Raw initial nitrogen content data'
  p_Hini_raw                                     'Raw initial humus content data'
  p_Qres(hhold,inout,field,inten)                'Crop residues from preceding cropping cycle (kg DM/ha)'
  p_Qcomp_raw                                    'Raw compost quantity data before processing'
  p_Qcomp(hhold)                                 'Compost application rate (kg DM/ha)'
  P_Npot(hhold,*,field,inten)                    'Nitrogen required for optimal crop growth (kg N/ha)'
  p_MScomp(hhold)                                'Compost dry matter content percentage (%)'
  p_MScomp_raw                                   'Raw compost dry matter data'
  
*------------------------------------------------------------------------------
* 10.2 Nitrogen Transformation Rate Constants
*------------------------------------------------------------------------------
  K3                                            'Humification rate constant (conversion of residues to humus)'
  prof                                          'Plowed/prepared soil layer depth (meters)'
  da                                            'Soil bulk density (kg/m³)'
  K2(field)                                     'Soil organic matter mineralization rate constant (per year)'
  p_MSres                                       'Dry matter content of crop residues (%)'
  p_effr(inout)                                 'Nitrogen content per kg of crop residue biomass (kg N/kg DM)'
  p_Nl_raw                                      'Raw nitrogen leaching rate'
  K1(*)                                         'Nitrification rate coefficients for NH4 to NO3 conversion'
  p_Norg_raw                                    'Raw organic nitrogen input data'
  p_Norg(hhold)                                 'Nitrogen from organic sources (manure, compost) (kg N/ha)'
  p_Nres_raw                                    'Raw residue nitrogen data'
  p_Nres(hhold,inout,field,inten)               'Nitrogen from crop residue decomposition (kg N/ha)'
  p_nfert_max_annual_raw                        'Raw maximum annual nitrogen application data'
;

*------------------------------------------------------------------------------
* 10.3 Temporal and Meteorological Parameters
*------------------------------------------------------------------------------
parameter
  mday(m)    'Days per month for calendar calculations' /(M01,M03,M05,M07,M08,M10,M12) 31
                              (M04,M06,M09,M11) 30
                               M02              28/
;

Scalar lastMonth                              'Last month index for simulation period';
lastMonth = card(m);
Scalar discretization2 /10000/     ;
*            'Discretization parameter for numerical stability'

parameter   
  p_meteo                              'Rainfall'
  p_Humus                              'Humus dynamics parameters (C:N ratios, decomposition rates)'
  agro                                'Agroforestry system parameters (shading, microclimate effects)'
  v0_max_irrigation(hhold,*,field,inten,m,y) 'Maximum available irrigation capacity (mm/month)'
  p_cost_irrigation(hhold)                        'Variable cost of irrigation water (nc/mm applied)'
  irrigation_raw                                  'Raw irrigation infrastructure data'
  irrigation_month                                'Monthly irrigation application data'
  p_water_calib(crop_activity,inten)              'Water stress calibration parameters by crop'
  p_nitr_calib(crop_activity,inten)               'Nitrogen stress calibration parameters by crop'
  p_ncomp(hhold)                                  'Annual compost nitrogen application rate (kg N/ha)'
  p_nfert_max_annual(hhold,crop_activity,field,inten) 'Maximum annual synthetic N fertilizer application (kg N/ha)'
;

*===============================================================================
* SECTION 11: ENERGY BALANCE AND ECONOMIC PARAMETERS
* Energy accounting for agricultural operations and discounting for intertemporal choices
*===============================================================================

parameter
*------------------------------------------------------------------------------
* 11.1 Energy Requirements by Activity
*------------------------------------------------------------------------------
  enerReqtask_crop(*,*,*,*)          'Direct and indirect energy requirements for crop tasks (MJ/ha)'
  enerReqtask_AF(*,*,*,*)            'Energy requirements for agroforestry management tasks (MJ/ha)'
  enerReq_Livestock(*,*,*)           'Energy requirements for livestock operations (MJ/head/year)'
  enerReq_Feed(*,*,*)                'Embedded energy content of purchased feeds (MJ/kg DM)'

*------------------------------------------------------------------------------
* 11.2 Diversity Index Calculation Parameter
*------------------------------------------------------------------------------
scalar n_total                    'Total number of observations for Simpson diversity index calculation';
n_total = card(hhold) * card(y) * card(crop_activity_endo);

*------------------------------------------------------------------------------
* 11.3 Aggregated Energy Use Parameters
*------------------------------------------------------------------------------
parameter
  p_energy_crop(hhold,crop_activity,inten,*)      'Total annual crop system energy use by category'
  p_energy_task_crop(hhold,crop_activity,inten,*) 'Task-level energy disaggregation for crops'
  p_energy_task_AF(hhold,c_tree,inten,*)          'Task-level energy disaggregation for agroforestry'
  p_energy_AF(hhold,c_tree,inten,*)               'Total annual agroforestry energy use by category'

*------------------------------------------------------------------------------
* 11.4 Intertemporal Choice Parameters
*------------------------------------------------------------------------------
parameter
  dr                    'Annual discount rate for future benefits and costs (%)'
  rho                   'Discount factor per year (1/(1+dr))'
  p_phi                 'Relative risk aversion coefficient for household utility function (CRRA specification)'
;

*===============================================================================
* SECTION 12: WATER QUALITY AND ENVIRONMENTAL PARAMETERS
* Parameters for water quality assessment and environmental constraints
*===============================================================================

parameter 
  p_buffer              'Buffer zone width parameter for riparian areas (meters)'
  MaxConcNitr           'Maximum allowable nitrate concentration in water (mg NO3-N/L)'
  InitConcNitr          'Initial nitrate concentration in water bodies (mg NO3-N/L)'
;

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
       - {name: p_Yld_C_tree, range: agroforestry_data!AB6:AE5000, columnDimension: 0, rowDimension: 3, type: par}
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
execute_unload 'DATA\crop_data_load_%region%_new.gdx' p_cropCoef, p_perresmulch,  p_labReqTask, p_laborReq, p_seedData,previouscrop,p_crop_loss ;
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
p_Yld_C(hhold,crop_activity,'allp',field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield));

* Assume similar yields for all preceding crops (simplification)
p_Yld_C(hhold,crop_activity,crop_preceding,field,inten) $(c_c(crop_activity,crop_preceding)) = 
    p_Yld_C(hhold,crop_activity,'allp',field,inten);

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
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), 
    p_cropCoef(hhold,crop_activity,field,inten,NameArea) * 
    p_inputReq(hhold,crop_activity,field,inten,i));

p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm);
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal);
p_inputCost(hhold,crop_activity_endo,inpv)=sum((field,inten),p_cropcoef(hhold,crop_activity_endo,field,inten,inpv));

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
        p_Yld_C_tree age_tree, v0_Age_AF v0_cropCoef_AF, c_t_m_orchard,
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
p_costPhyto_AF(hhold,c_tree,field,inten) = 
    (v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha")/p_pricescalar)$ 
    v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha");
p_costOther_AF(hhold,c_tree,field,inten)=
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
*20-04 linearised
*    v_FeedConsumed(hhold,feedc,type_animal,y)     'Feed consumed (kg)'
    V_FamLabor_A(hhold,m,y)    'Family labor for livestock (person-days)'
    v_FeedAvailable(hhold,feedc,type_animal,y)    'Feed available (kg)'
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
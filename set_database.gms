*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : set_database.gms
   @purpose  : Loading data and initialization of Livestock Agroforestry and Value Chain
   @author   : 
   @date     : 02/12/2015
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy :
  08-09 Addition of some variable from household and farm module
  08-09 Add the biophysical parameters
$offtext
$goto %1
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* General settings for numerical display
*option decimals=3;

$label set_database_ini
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 1: Load and process model sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* Load generic sets
$batinclude "settings.gms" sets_generic
* Load region-specific settings
$batinclude "settings.gms" settings_reg
* Load specific sets
$batinclude "settings.gms" sets_specific

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 2: Crop Activity Data
*            - Loads coefficients for crop activities
*            - Handles two intensification levels (extensive and intensive)
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* Declare parameters for crop data
*-- crop data parameters and livestock prices
parameters
  p_cropCoef(hhold,crop_activity,field,inten,*)   'Input-output coefficients'
  p_laborReq(hhold,crop_activity,inten,m)         'Labor requirements'
  p_labReqTask(hhold,crop_activity,inten,task)    'Labor by task'
  p_residuedep                                   'Residue carryover percentage'
  p_perresmulch(inout)                           'Residue allocation for mulch'
  p_seedData(hhold,crop_activity,*)              'Seed data'
  p_farmData(hhold,*,*,*)                        'Farm data'
*  p_outData(hhold,inout,*)
  p_consoData(hhold,good,*)
  p_hholdData(hhold,hvar)
  p_cpriData(hhold,inout,*)
  p_apriData(hhold,inout,*)
  p_gpriData(hhold,good,*)
  p_spriData(hhold,crop_activity,*)               'buying price of seeds, local currency'
*-- auxiliary parameters
  p_cropCoef_raw(*,*,*,*,*)
  labReqTask(*,*,*,*)
  farmlabData_raw(hhold,*)
  outData_raw(hhold,inout,*)
  hholdData_raw(hhold,*)
  consoData_raw(hhold,good,*)
  apriData_raw(hhold,inout,*)
  cpriData_raw(hhold,*,*)
  gpriData_raw(hhold,good,*)
  spriData_raw(hhold,crop_activity,*)
  p_pricescalar
  p_selPrice(hhold,inout)          'crop selling price (normalized currency/kg)'
  p_buyPrice(hhold,inout)          'crop buying price (normalized currency/kg)'
  p_seedbuypri(hhold,crop_activity)          'seeds buying price (normalized currency/kg)'
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 10: PMP Calibration (Conditional)
*             - Includes PMP calibration components when active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 10: ENERGY
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*


*-1) Load crop coefficients and create gdx file with crop activity data
set previouscrop;
parameter
  seedData_raw(*,*,*)
  p_crop_loss_raw
  p_crop_loss(hhold,inout)
  p_resmulch                             'location of p_perresmulch'
;
*-- import data (from xls to gdx)
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%crop_data_%region%_new.xlsx o=DATA%system.DirSep%crop_data_%region%_new.gdx se=2 index=index_coef!A3"
$gdxin "DATA%system.DirSep%crop_data_%region%_new.gdx"
$load p_cropCoef_raw p_resmulch labReqtask p_crop_loss_raw previouscrop 
$gdxin
$endif
$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%crop_data_%region%_new.xlsx
    symbols:
       - {name: p_cropCoef_raw, range: crop_data!H4:S5000, columnDimension: 1, rowDimension: 4, type: par}
       - {name: p_resmulch, range: crop_data!F4:G5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: labReqtask, range: crop_data!T4:AC5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: p_crop_loss_raw, range: crop_data!C4:E5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: previouscrop, range: crop_data!A4:A5000, columnDimension: 0, rowDimension: 1, type: set}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

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

p_seedData(hhold,crop_activity,NameseedOnFarm) =  smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_onFarm_ha"));
p_seedData(hhold,crop_activity,NameseedTotal)= smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_kg_ha"));
*30-01
*Mapping of hhold to crop_activity combinations
Set hhold_crop_map(hhold,crop_activity) ;
hhold_crop_map(hhold,crop_activity) = 
    sum((field,inten), p_cropCoef_raw(hhold,crop_activity,field,inten,"yield_kg_ha")) > 0;

Parameter
    p_landField(hhold,field)
;
*land by field
p_landField(hhold,field)=sum((inten,crop_activity,NameArea),p_cropCoef(hhold,crop_activity,field,inten,NameArea));
display p_landField;

*-- write to labor requirement parameter
p_labReqTask(hhold,crop_activity,inten,NamePlanting) =  labReqTask(hhold,crop_activity,inten,"plant_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameWeeding)  =  labReqTask(hhold,crop_activity,inten,"weed_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameHerbicide)=  labReqTask(hhold,crop_activity,inten,"herb_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameChe_fert) =  labReqTask(hhold,crop_activity,inten,"chemfer_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameOrg_fert) =  labReqTask(hhold,crop_activity,inten,"orgfer_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NamePesticide)=  labReqTask(hhold,crop_activity,inten,"pest_persday_ha");
p_labReqTask(hhold,crop_activity,inten,NameHarvest)  =  labReqTask(hhold,crop_activity,inten,"harv_persday_ha");
p_laborReq(hhold,crop_activity,inten,m) = sum(c_t_m(crop_activity,task,m), p_labReqTask(hhold,crop_activity,inten,task) );


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 3: Farm and Output Data
*            - Loads farm-level information including land use and labor
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*Loss on the farm
parameter p_farm_loss(inout);
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%farm_data_%region%_new.xlsx o=DATA%system.DirSep%farm_data_%region%_new.gdx se=2 index=index_farm!A3"
$gdxin "DATA%system.DirSep%farm_data_%region%_new.gdx"
$load  farmlabData_raw p_farm_loss
$gdxin
$endif

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%farm_data_%region%_new.xlsx
    symbols:
       - {name: farmlabData_raw, range: farm_data!D4, columnDimension: 1, rowDimension: 1, type: par}
       - {name: p_farm_loss, range: farm_data!A4, columnDimension: 0, rowDimension: 1, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif


* Calculate farm data parameters
p_farmData(hhold,'allc',field,'cropland') = sum((crop_activity,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
p_farmData(hhold,'allc','total','cropland') = sum((crop_activity,field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
p_farmData(hhold,'labor','family','total')  =  farmlabData_raw(hhold,'fam_m_persday_ha')+ farmlabData_raw(hhold,'fam_f_persday_ha');
execute_unload 'DATA%system.DirSep%farm_data_load_%region%_new.gdx' p_farmData, p_farm_loss;
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 4: Household and Consumption Data
*            - Loads demographic and consumption information
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter p_MaxHiredLabor                     'limit of the hiring work'
          p_raw_workTimeMax
          p_distanceprice(hhold)
          p_pricescalar
          ;
$iftheni %LINUX%==off          
$call "gdxxrw.exe DATA\household_data_%region%_new.xlsx o=DATA\household_data_%region%_new.gdx se=2 index=index_hh!A3"
$gdxin "DATA\household_data_%region%_new.gdx"
$load hholdData_raw consoData_raw p_MaxHiredLabor p_raw_workTimeMax 
$gdxin
$endif

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%household_data_%region%_new.xlsx
    symbols:
       - {name: hholdData_raw, range: household_data!A4:C5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: consoData_raw, range: household_data!H4:J5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_MaxHiredLabor, range: household_data!F4, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_raw_workTimeMax, range: household_data!F5, columnDimension: 0, rowDimension: 0, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif


*Set NameHH / hh_size/ ;
p_hholdData(hhold,'hh_size')        = hholdData_raw(hhold,'hh_size');
p_hholdData(hhold,'lab_family')     = p_farmData(hhold,'labor','family','total')  ;
p_hholdData(hhold,'inc_offfarm')    = hholdData_raw(hhold,'inc_offfarm');
p_consoData(hhold,gd,'ave') = consodata_raw(hhold,gd,'average');


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 5: Price Data
*            - Loads and processes price information for all commodities
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%price_data_%region%_new.xlsx o=DATA%system.DirSep%price_data_%region%_new.gdx se=2 index=index_pri!A3"
$gdxin "DATA%system.DirSep%price_data_%region%_new.gdx"
$load  cpriData_raw spriData_raw gpriData_raw p_pricescalar
$gdxin
$endif
*
$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%price_data_%region%_new.xlsx
    symbols:
       - {name: cpriData_raw, range: price_data!E4:H5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: spriData_raw, range: price_data!J4:L5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: gpriData_raw, range: price_data!N4:P5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_pricescalar, range: price_data!C4, columnDimension: 0, rowDimension: 0, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

*in localCurrency
p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice');
p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice');
p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price');
p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg');
*in USD

p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)= p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)/p_pricescalar;
p_cropCoef(hhold,crop_activity,field,inten,NameOther)= p_cropCoef(hhold,crop_activity,field,inten,NameOther)/p_pricescalar;
p_hholdData(hhold,'inc_offfarm')=p_hholdData(hhold,'inc_offfarm')/p_pricescalar ;

p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice')/p_pricescalar;
p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice')/p_pricescalar;
p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price')/p_pricescalar;
p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg')/p_pricescalar;
p_distanceprice(hhold)=cpriData_raw(hhold,'distance_km','buyPrice')/p_pricescalar;
p_selPrice(hhold,inout)=  p_cpriData(hhold,inout,'selprice');
p_buyPrice(hhold,inout)=  p_cpriData(hhold,inout,'buyprice');
p_seedbuypri(hhold,crop_activity)= p_spriData(hhold,crop_activity,'seedPrice') ;


execute_unload 'DATA\crop_data_load_%region%_new.gdx' p_cropCoef, p_perresmulch, p_residuedep, p_labReqTask, p_laborReq, p_seedData,previouscrop,p_crop_loss ;
execute_unload 'DATA\household_data_load%region%_new.gdx' p_hholdData, p_consoData, p_MaxHiredLabor, p_raw_workTimeMax;
execute_unload 'DATA\price_data_load%region%_new.gdx' p_cpriData, p_gpriData, p_spriData;


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 6: Crop Module (Conditional)
*            - Defines crop-related variables and equations when crop module is active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*CONSUMPTION
positive variable
  v_selfCons(hhold,inout,year)          'self-consumption quantity(kg)'
  v_markSales(hhold,inout,year)         'market sales quantity(kg)'
  v_prodQuant(hhold,inout,year)                 'production quantity (kg)'
;



$iftheni %CROP%==on

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Model parameters
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter
*-- Crop activity coefficients
  p_cropCoef(hhold,crop_activity,field,inten,*)   'crop data (input-output coefficients)'
  p_laborReq(hhold,crop_activity,inten,m)            'labor requirement (person-day per ha)'
  p_inputReq(hhold,crop_activity,field,inten,inout)   'direct input requirements'
*-- Observed activity level
  p_seedData(hhold,crop_activity,*)                'observed seed data,kg by ha'
  p_perresmulch(inout)                 '% of crop residue production allocated to field as mulch'
  p_residuedep                         '% of feed not wasted between months, then can be carried forward from m to m+1'
  V0_Plant_C(hhold,crop_activity,*,field,inten)       'observed activity level (ha)'
  v0_Land_C(hhold,crop_activity,field)              'observed crop area by soil type (ha)'
  v0_Use_Land_C(hhold,field)                  'observed crop land (ha)'
  v0_Prd_C(hhold,crop_activity,field,inten)         'observed crop activity production (kg)'
  v0_prodQuant(hhold,inout)                'observed crop output (kg)'
  v0_Yld_C(hhold,crop_activity,*,field,inten)       'crop activity yield (kg/ha)'
  V0_Use_Input_C(hhold,crop_activity,inout)             'input use (kg)'
  v0_inputCost(hhold,crop_activity,inout)            'input cost (nc)'
  V0_Use_Seed_C(hhold,crop_activity,seedbal)          'seed use (kg)'
  v0_Yld_C_stress(hhold,*,*,field,inten)
;
*set previouscrop;
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Load crop activity coefficients
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ifi %BIOPH%==OFF execute_load "DATA\crop_data_load_%region%_new.gdx" p_cropCoef, p_perresmulch, p_residuedep, p_labReqTask, p_laborReq, p_seedData,previouscrop,p_crop_loss ;

*Similar to lines in bioph module delete
*-- crop yield
v0_Yld_C(hhold,crop_activity,'allp',field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield));
*TFix: yield by activity needed => assume similar yields over all preceding crops
v0_Yld_C(hhold,crop_activity,crop_preceding,field,inten) $(c_c(crop_activity,crop_preceding)) = v0_Yld_C(hhold,crop_activity,'allp',field,inten);
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- Cropland allocation
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
display v0_Land_C;
v0_Use_Land_C(hhold,field) = sum(crop_activity, v0_Land_C(hhold,crop_activity,field)) ;
V0_Plant_C(hhold,crop_activity,'allp',field,inten) = sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
V0_Plant_C(hhold,crop_activity,previouscrop,field,inten) = V0_Plant_C(hhold,crop_activity,'allp',field,inten);
*-- Crop production (kg)
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
*creation of a mapping
set
fieldcrop(hhold,field,crop_activity) 'mapping field-crop when production > 0'
;

fieldcrop(hhold,field,crop_activity)$(sum(inten,v0_Prd_C(hhold,crop_activity,field,inten)) > 0) = yes;

v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));

*~~~~~~~~~~~~~~~~ input requirements    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- endogenous activities => crop coefficients
*   .. labor not included
p_inputReq(hhold,crop_activity_endo,field,inten,inpq) $(not NameLabor(inpq)) = p_cropcoef(hhold,crop_activity_endo,field,inten,inpq);
p_inputReq(hhold,crop_activity_endo,field,inten,inpv) = p_cropcoef(hhold,crop_activity_endo,field,inten,inpv);
p_inputReq(hhold,crop_activity_endo,field,inten,NameFert) $(sum(NameNitr,p_inputReq(hhold,crop_activity_endo,field,inten,NameNitr))) = 0;

*~~~~~~~~~~~~~~~~ inputs and outputs      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- initial input use and cost
V0_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
V0_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
V0_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
v0_inputCost(hhold,crop_activity_endo,inpv)=sum((field,inten),p_cropcoef(hhold,crop_activity_endo,field,inten,inpv));
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Variables
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

variable
  V_annualGM_C(hhold,year)              'income from cropping activities (normalized currency)'
;

positive variable
  V_Plant_C(hhold,crop_activity,crop_activity,field,inten,year)      'crop activity level by cp (ha)'
  v_Prd_C(hhold,crop_activity,field,inten,year)          'crop activity total (ha)'
  v_Yld_C(hhold,crop_activity,crop_activity,field,inten,year)      'crop activity yield (ha)'
  v_Land_C(hhold,crop_activity,field,year)               'crop area by soil type (ha)'
** (SiwaPMP) added this as the variable we calibrate to ***
  v_Land_C_Agg(hhold,crop_activity,year)               'crop area by soil type (ha) aggregated across soil types'
  v_Use_Land_C(hhold,field,year)                   'cropland used (ha)'
  V_FamLabor_C(hhold,year,m)                     'labor used for cropping activities (person-day)'
  V_HLabor_C(hhold,year,m)                     'labor used for cropping activities (person-day)'
  V_Use_Input_C(hhold,crop_activity,inout,year)              'input use'
  V_Use_Seed_C(hhold,crop_activity,year)                   'total seed quantity (kg/ha)'
  v_residuesfeedm(hhold,inout,year,m)           'kg crop residues allocated for potential livestock feed intake or for feed balance each month'
  v_residuesmulch(hhold,inout,year)             'kg crop residues allocated to crops for mulch'
  v_residuesfeed(hhold,inout,year)              'kg crop residues allocated for potential livestock use or for feed balance'
  v_residuessell(hhold,inout,year)              'kg crop residues sold'
  v_residuessellm(hhold,inout,year,m)           'kg crop residues sold /month'
  V_Sale_C(hhold,year)                'sales revenue from crops (normalized currency)'
  V_VarCost_C(hhold,year)                'direct crop costs excluding labor (normalized currency)'
  V_Nfert_C(hhold,y)                        'qty of chemical fertilizer (kg)'
  v_seedOnfarm(hhold,crop_activity,year)          'on-farm seed use (kg)'
  v_seedPurch(hhold,crop_activity,year)           'input purchases (kg)'
  v_feedOnfarm(hhold,inout,year)        'on-farm feed use (kg)'
  v_selfCons(hhold,inout,year)          'self-consumption quantity(kg)'
  v_markSales(hhold,inout,year)         'market sales quantity(kg)'
;

*=================================================
* The below code map sets
*=================================================
sets
c_t_m_map(inout,m) 'map coproduct-harvest month'
parameters
indic(inout,m)
flag(inout,m)
count
stopflag
flagm(inout,m)
countm
;

*Creation of the map for the harvest of coproducts
* Set c_t_m_map(cken, m) to yes if harvest occurs in month m for activity crop_activity_endo
loop((crop_activity_endo, cken)$activity_output(crop_activity_endo, cken),
  c_t_m_map(cken, m)$c_t_m(crop_activity_endo, 'harvest', m) = yes;
);




$endif

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 7: Agroforestry Module (Conditional)
*            - Defines orchard/agroforestry components when module is active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

* Declare agroforestry sets and parameters

set c_tree          'crops'
    task_tree       'task'
    ageclass_tree   'age classes'
    inputprice_tree
    othcost_tree
    age_tree
    c_t_m_orchard
    c_treej(inout)      'tree products in current run'
    a_c_treej           'mapping activity-main product'
    ;
$iftheni %ORCHARD%==on

set othcost_tree / other_localCurrency_ha,phyto_localCurrency_ha,area_ha,nitr_kg_ha,plants_nb_ha /;

*set ageclass_tree /young,adult,old/;

Parameter p_taskLabor_cost_LocalCur(*,*) 'task labor'
          life_tree(c_tree)              'plant life (years)'
          oldAge_tree(c_tree)  'age of reducing production (years)'
          type_age_tree(*,*)
          harvestingAge_tree(c_tree)  'age of first harvest (years)'
          v0_Yld_C_tree(field,*, ageclass_tree<) 'load data'
          p_selPrice_tree(c_tree)       'sales price (USD per kg)'
          p_buyPrice_tree_LocalCur(inputprice_tree<,c_tree<) 'buying price (USD per kg)'
          V0_Area_AF(hhold,field,c_tree,age_tree,inten)    'land available (ha)'
          p_inputcost(hhold,c_tree,field,inten) 'input cost'
          v0_Age_AF(c_tree,field, age_tree) 'Age of trees'
          v0_cropCoef_AF(hhold,c_tree,field,inten,othcost_tree)
          Labor_Task_AF(*,*,*,*)
          p_Labor_Task_AF(*,*,*,*)
          p_laborReq_AF(*,*,*,*)
          p_pricescalar
          v0costPhyto_AF(hhold,c_tree,field,inten)
          v0costOther_AF(hhold,c_tree,field,inten)
          p_taskLabor_cost(c_tree,task_tree)
          p_buyPrice_tree(inputprice_tree,c_tree)
          p_field_AF(hhold,field)
;

* Load agroforestry data
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%agroforestry_data_%region%_new.xlsx o=DATA%system.DirSep%agroforestry_data_%region%_new.gdx se=2 index=index_coef!A3"
$gdxin "DATA%system.DirSep%agroforestry_data_%region%_new.gdx"
$load type_age_tree p_buyPrice_tree_LocalCur age_tree c_t_m_orchard p_taskLabor_cost_LocalCur Labor_Task_AF task_tree v0_Yld_C_tree v0_Age_AF v0_cropCoef_AF
$gdxin
$endif
*display life_tree p_buyPrice_tree_LocalCur c_t_m_orchard p_taskLabor_cost_LocalCur v0_Age_AF v0_Yld_C_tree v0_cropCoef_AF  ;



$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%agroforestry_data_%region%_new.xlsx
    symbols:
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
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif


harvestingAge_tree(c_tree)=type_age_tree("harvesting age",c_tree);
oldAge_tree(c_tree)=type_age_tree("old age",c_tree);
life_tree(c_tree)=type_age_tree("life",c_tree);
display harvestingAge_tree
life_tree
oldAge_tree
p_buyPrice_tree_LocalCur
v0_Yld_C_tree age_tree
v0_Age_AF v0_cropCoef_AF
c_t_m_orchard
p_taskLabor_cost_LocalCur
Labor_Task_AF
task_tree
*ageclass_tree
;

p_field_AF(hhold,field)=sum((c_tree,inten),v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha"));


*
*
Set   NamePlantingAF(task_tree)         ;
NamePlantingAF('planting') = yes;
Set   NameWeedingAF(task_tree)         ;
NameWeedingAF('weeding') = yes;
Set   NameGrubbAF(task_tree)         ;
NameGrubbAF('grubbingup') = yes;
Set   NameChe_fertAF(task_tree)         ;
NameChe_fertAF('che_fert') = yes;
Set   NameOrg_fertAF(task_tree);
NameOrg_fertAF('org_fert') = yes;
Set   NamePesticideAF(task_tree);
NamePesticideAF('pesticide') = yes;
Set   NameHarvestAF(task_tree);
NameHarvestAF('harvest') = yes;
Set   NamePruningAF(task_tree);
NamePruningAF('pruning') = yes;
Set   NameYoung(ageclass_tree);
NameYoung('young') = yes;
Set   NameAdult(ageclass_tree);
NameAdult('adult') = yes;
Set   NameOld(ageclass_tree);
NameOld('old') = yes;
Set   NameNitrAF(othcost_tree);
NameNitrAF('nitr_kg_ha') = yes;
Set   NamePlantsAF(othcost_tree);
NamePlantsAF('plants_nb_ha') = yes;
Set   NameNitrPrice(inputprice_tree);
NameNitrPrice('nitr_price_kg') = yes;
Set   NamePlantsPrice(inputprice_tree);
NamePlantsPrice('plant_price_nbr') = yes;

c_treej(outm) = yes $(sum(activity_output(c_tree,outm),1));
a_c_treej(c_tree,c_treej) $(activity_output(c_tree,c_treej)) = yes ;

* Process agroforestry data
*V0_Area_AF(hhold,field,inten)=sum(c_tree,v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha")) ;
*Initial value

V0_Area_AF(hhold,field,c_tree,age_tree,inten)=v0_Age_AF(c_tree,field, age_tree)*v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha");

display V0_Area_AF;
v0costPhyto_AF(hhold,c_tree,field,inten) = 
    (v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha")/p_pricescalar)$ v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha");
*v0costPhyto_AF(hhold,c_tree,field,inten)=v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha")/p_pricescalar;
v0costOther_AF(hhold,c_tree,field,inten)=v0_cropCoef_AF(hhold,c_tree,field,inten,"other_localCurrency_ha")/p_pricescalar;
p_taskLabor_cost(c_tree,task_tree)=p_taskLabor_cost_LocalCur(c_tree,task_tree)/p_pricescalar;
p_buyPrice_tree(inputprice_tree,c_tree)=p_buyPrice_tree_LocalCur(inputprice_tree,c_tree)/p_pricescalar;


p_Labor_Task_AF(hhold,c_tree,inten,NamePlantingAF) =  Labor_Task_AF(hhold,c_tree,inten,"plant_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameWeedingAF)  =  Labor_Task_AF(hhold,c_tree,inten,"weed_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameGrubbAF)=  Labor_Task_AF(hhold,c_tree,inten,"grubb_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameChe_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"chemfer_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameOrg_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"orgfer_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NamePesticideAF)=  Labor_Task_AF(hhold,c_tree,inten,"pest_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NameHarvestAF)  =  Labor_Task_AF(hhold,c_tree,inten,"harv_persday_ha");
p_Labor_Task_AF(hhold,c_tree,inten,NamePruningAF)  =  Labor_Task_AF(hhold,c_tree,inten,"prun_persday_ha");
p_laborReq_AF(hhold,c_tree,inten,m) = sum(c_t_m_orchard(c_tree,task_tree,m), p_Labor_Task_AF(hhold,c_tree,inten,task_tree) );
*
* Declare agroforestry variables
Positive Variable
    V_Area_AF(hhold,field,c_tree,age_tree,inten,y) 'Age of trees per year'
    v_Prd_AF(hhold,c_tree, y) 'production (kg)'    
    V_FamLabor_AF(hhold,y,m)
    V_Nfert_AF(hhold,c_tree,y)
    V_Phyto_AF(hhold,y)
    V_other_AF(hhold,y)
    V_PlantsNB_AF(hhold,c_tree,y)
    V_HLabor_AF(hhold,y,m)
    V_VarCost_AF(hhold,y) 'process cost (USD)'
    V_Sale_AF(hhold,y) 'sales revenue (USD)'
;
$onExternalOutput
Variable

    V_annualGM_AF(hhold,y) 'total benefit (discounted cost)'

;
$offExternalOutput
Positive Variable V_Area_AF,  v_Prd_AF;
$endif

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 8: Livestock Module (Simplified, Conditional)
*            - Defines livestock components when module is active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*============================================================================*
* #1 DECLARE SETS AND PARAMETERS
*============================================================================*
* Declare livestock sets
sets
    age      'Animal age groups'
    akmeat(ak) 'Meat products'
    akmilk(ak) 'Milk products'
    feedc    'Feed types'
    animal_feed(type_animal,feedc) 'Map food animal'
;

$iftheni %LIVESTOCK_simplified%==on



parameters
* Economic parameters
    p_selPriceLivestock(hhold,type_animal,*) 'Selling price of animal products (nc/unit)'
    p_othCostLivestock(hhold,type_animal)    'Other costs per animal (nc/head)'
    p_costVeterinary(hhold,type_animal)      'Veterinary costs (nc)'
    p_AdditionalCostLivestock(hhold,type_animal) 'Additional costs (nc)'
    p_laborPrice                    'Labor price (nc/day)'
    p_Repro(hhold,type_animal,age)              'Reproduction rate by age'
    
* Production parameters
    p_feedReq(type_animal,*)          'Feed requirement per animal (kg/head)'
    p_MortalityRate(hhold,type_animal,age)   'Mortality rate by age'
    p_LaborReqLivestock(hhold,type_animal,m) 'Labor requirement per animal (days/head)'
    p_yieldLivestock(hhold,type_animal,ak,age)   'Yield of animal products'
    
* Nutritional parameters
    p_prot_intake(hhold,type_animal)         'Protein intake parameter'
    p_prot_metab(hhold,type_animal)          'Protein metabolism parameter'
    p_ca(hhold,type_animal)                  'CA parameter'
    p_grossenergy_feed(feedc)       'Gross energy of feed'
    p_protein_feed(feedc)       'Gross energy of feed'
    p_drymatter_feed(feedc)       'Dry matter of feed'

* Initial values
    p_initPopulation(hhold,type_animal,age)  'Initial animal population (head)'
    p_DataLive                      'Raw livestock data'
    p_selPriceLivestock_raw(hhold,type_animal,*)         'Raw selling price data'
    p_yieldLivestock_raw            'Raw yield data'
    p_pricescalar
    p_feed_price_LocalCur(hhold,feedc)
    p_feed_price(hhold,feedc)

;


* Load livestock data
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%livestock_data_%region%_new.xlsx o=DATA%system.DirSep%livestock_data_%region%_new.gdx index=index!A3"
$gdxin "DATA%system.DirSep%livestock_data_%region%_new.gdx"
$load age feedc type_animal p_DataLive p_grossenergy_feed p_protein_feed p_drymatter_feed p_feed_price_LocalCur p_feedReq p_selPriceLivestock_raw p_yieldLivestock_raw ak akmeat akmilk animal_feed
$gdxin
$endIf

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%livestock_data_%region%_new.xlsx
    symbols:
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
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif
     
display p_selPriceLivestock_raw animal_feed;

p_selPriceLivestock(hhold,type_animal,ak) = p_selPriceLivestock_raw(hhold,type_animal,ak)/p_pricescalar;
p_selPriceLivestock(hhold,type_animal,'liveanimal') = p_selPriceLivestock_raw(hhold,type_animal,'liveanimal')/p_pricescalar;

* Process loaded data
*p_selPriceLivestock(hhold,type_animal,ak) = p_selPriceLivestock_raw(hhold,type_animal,ak,'price')/p_pricescalar;
*p_selPriceLivestock(hhold,type_animal,'liveanimal') = p_selPriceLivestock_raw(hhold,type_animal,'liveanimal','price')/p_pricescalar;
p_yieldLivestock(hhold,type_animal,akmeat,age) = p_yieldLivestock_raw(hhold,type_animal,akmeat,age,'yield');
p_yieldLivestock(hhold,type_animal,akmilk,age) = p_yieldLivestock_raw(hhold,type_animal,akmilk,age,'yield');

* Assign parameter values from raw data
p_othCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_othCostLivestock')/p_pricescalar;
p_costVeterinary(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_costVeterinary')/p_pricescalar;
p_AdditionalCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_AdditionalCostLivestock')/p_pricescalar;
*p_MilkYield(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_MilkYield');       
*p_MeatYield(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_MeatYield');        
p_Repro(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_BirthRate');       
p_MortalityRate(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_MortalityRate');   
p_LaborReqLivestock(hhold,type_animal,m) = p_DataLive(hhold,type_animal,'1','p_LaborReq')/12;        
p_prot_metab(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_prot_metab');       
p_ca(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_ca');   
p_initPopulation(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_initPopulation');
p_feed_price(hhold,feedc)=p_feed_price_LocalCur(hhold,feedc)/p_pricescalar;

* Create mappings
a_k(type_animal,ak)$activity_output(type_animal,ak) = yes;
akmilk(ak) = yes;
*akmeat(ak) = yes;

* Declare livestock variables
positive variables
    v_FeedPurchase(hhold,feedc,y)     'Purchased feed (kg)'
    v_residuesbuy(hhold,inout,y)      'kg of a residue consumed from market purchases'
    v_FeedConsumed(hhold,feedc,type_animal,y)     'Feed consumed (kg)'
    V_FamLabor_A(hhold,m,y)    'Labor requirement (days)'
    v_FeedAvailable(hhold,feedc,y)    'Feed available (kg)'
    v_ManureProd(hhold,type_animal,y)       'Manure production (kg)'
    V_HLabor_A(hhold,m,y)  'Hired labor for livestock (days)'
    v_NitrogenOutput_Sell(hhold,y)
    v_NitrogenOutput_OnFarm(hhold,y)
    V_FixCost_A(hhold,y)
*    V_animals(hhold,type_animal,age,y)   'Animal population (head)'
*    v_Slaughter(hhold,type_animal,age,y)    'Animals slaughtered (head)'
*    V_NewPurchased(hhold,type_animal,age,y)    'Animals purchased (head)'
;


Integer Variable
*positive variables
    V_animals(hhold,type_animal,age,y)   'Animal population (head)'
    v_Slaughter(hhold,type_animal,age,y)    'Animals slaughtered (head)'
    V_NewPurchased(hhold,type_animal,age,y)    'Animals purchased (head)'
    v_NewBorns(hhold,type_animal,age,y)    'Newborn animals (head)'
    v_Mortality(hhold,type_animal,age,y) 
;

Positive Variable
    V_Revenue_A(hhold,y)      'Total livestock revenue (nc)'
    V_VarCost_A(hhold,y)         'Total livestock cost (nc)'
    v_NitrogenOutput(hhold,type_animal,y)  'Nitrogen output (kg)'
    V_veterinary_A(hhold,y)
    V_other_A(hhold,y)
    V_additional_A(hhold,y)
;
$onExternalOutput
variables
    V_annualGM_A(hhold,y)       'Total livestock benefit (nc)'
;
$offExternalOutput
$endif

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 9: Value Chain Module (Conditional)
*            - Defines market linkages when module is active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$iftheni %VALUECHAIN%==on
* Declare value chain sets
set
seller_C
seller_AF
seller_A
buyer
seeder
inout_a
Livestock_seller
Feed_seller
;

*Buyer and generic
Parameter
P_GHG(hhold,*)  
P_buyer(inout,buyer,*)
p_capacity_buyer(inout,buyer)
p_distance(hhold,*)
p_distance_buyer(hhold,buyer)
p_labor_buyer(inout,buyer)
p_price_buyer
p_price_seller
p_price_seeder
p_price_Feed_seller
p_price_Livestock_seller
;

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%value_chain_%region%_new.xlsx
    symbols:
       - {name: buyer, range: value_chain!M5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_buyer, range: value_chain!N4:R5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_distance, range: value_chain!AQ5:AS5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: P_GHG, range: value_chain!AT5:AV5000, columnDimension: 0, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endIf

* Load value chain data
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%value_chain_%region%_new.xlsx o=DATA%system.DirSep%value_chain_%region%_new.gdx se=2 index=index!A3"
$gdxin "DATA%system.DirSep%value_chain_%region%_new.gdx"
$load    buyer P_buyer p_distance P_GHG
$gdxin
$endIf


set inout_a /costVeterinary, othCostLivestock, AdditionalCostLivestock/;
Set   NamecostVeterinary(inout_a);
NamecostVeterinary('costVeterinary') = yes;
Set   NameothCostLivestock(inout_a);
NameothCostLivestock('othCostLivestock') = yes;
Set   NameAdditionalCostLivestock(inout_a);
NameAdditionalCostLivestock('AdditionalCostLivestock') = yes;

p_capacity_buyer(inout,buyer)=P_buyer(inout,buyer,"p_capacity_buyer");
p_labor_buyer(inout,buyer)=P_buyer(inout,buyer,"p_labor_buyer");
p_distance_buyer(hhold,buyer)=p_distance(hhold,buyer);
p_price_buyer(inout,buyer)=   P_buyer(inout,buyer,"p_price_buyer")/p_pricescalar;

*Value chain and crop activity
$iftheni %CROP%==on
Parameter
P_seller_C(inout,seller_C,*)
p_capacity_seller_C(inout,seller_C)
p_distance_seller_C(hhold,seller_C)
p_labor_seller_C(inout,seller_C)

P_seeder(crop_activity,seeder,*)
p_capacity_seeder(crop_activity,seeder)
p_distance_seeder(hhold,seeder)
p_labor_seeder(crop_activity,seeder)
;

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%value_chain_%region%_new.xlsx
    symbols:
       - {name: seller_C, range: value_chain!A5:A5000, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_C, range: value_chain!B4:F5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: seeder, range: value_chain!G5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seeder, range: value_chain!H4:L5000, columnDimension: 1, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%value_chain_%region%_new.xlsx o=DATA%system.DirSep%value_chain_%region%_new.gdx se=2 index=index!A3"
$gdxin "DATA%system.DirSep%value_chain_%region%_new.gdx"
$load  seller_C P_seller_C seeder P_seeder
$gdxin
$endIf
p_capacity_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_capacity_seller");
p_labor_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_labor_seller");
p_distance_seller_C(hhold,seller_C)=p_distance(hhold,seller_C);
p_price_seller(inout,seller_C)=   P_seller_C(inout,seller_C,"p_price_seller")/p_pricescalar;

p_capacity_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_capacity_seeder");
p_labor_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_labor_seeder");
p_distance_seeder(hhold,seeder)=p_distance(hhold,seeder);
p_price_seeder(crop_activity,seeder)=   P_seeder(crop_activity,seeder,"p_price_seeder")/p_pricescalar;
$endif


*Value chain and livestock activity


$iftheni %LIVESTOCK_simplified%==on
Parameter
P_seller_A(*,seller_A,*)
p_capacity_seller_A(inout_a,seller_A)
p_labor_seller_A(*,seller_A)
p_distance_seller_A(hhold,seller_A)

P_Livestock_seller (type_animal,Livestock_seller,*)
p_capacity_Livestock_seller(type_animal,Livestock_seller)
p_distance_Livestock_seller(hhold,Livestock_seller)
p_labor_Livestock_seller(type_animal,Livestock_seller)

P_Feed_seller (feedc,Feed_seller,*)
p_capacity_Feed_seller(feedc,Feed_seller)
p_distance_Feed_seller(hhold,Feed_seller)
p_labor_Feed_seller(feedc,Feed_seller)
;
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%value_chain_%region%_new.xlsx o=DATA%system.DirSep%value_chain_%region%_new.gdx se=2 index=index!A3"
$gdxin "DATA%system.DirSep%value_chain_%region%_new.gdx"
$load   seller_A P_seller_A  Livestock_seller P_Livestock_seller Feed_seller P_Feed_seller
$gdxin
$endif

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%value_chain_%region%_new.xlsx
    symbols:
       - {name: seller_A, range: value_chain!Y5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_A, range: value_chain!Z4:AD5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: Livestock_seller, range: value_chain!AE5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_Livestock_seller, range: value_chain!AF4:AJ5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: Feed_seller, range: value_chain!AK5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_Feed_seller, range: value_chain!AQ5:AS5000, columnDimension: 1, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif


p_capacity_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_labor_seller");
p_distance_seller_A(hhold,seller_A)=p_distance(hhold,seller_A);
p_capacity_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_labor_seller");
p_capacity_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
p_labor_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_labor_seller");
p_distance_seller_A(hhold,seller_A)=p_distance(hhold,seller_A);

p_capacity_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller (type_animal,Livestock_seller,"p_capacity_seller");
p_distance_Livestock_seller(hhold,Livestock_seller)=p_distance(hhold,Livestock_seller);
p_labor_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller(type_animal,Livestock_seller,"p_labor_seller");

p_capacity_Feed_seller(feedc,Feed_seller)=P_Feed_seller (feedc,Feed_seller,"p_capacity_seller");
p_distance_Feed_seller(hhold,Feed_seller)=p_distance(hhold,Feed_seller);
p_labor_Feed_seller(feedc,Feed_seller)=P_Feed_seller(feedc,Feed_seller,"p_labor_seller");
p_price_Feed_seller(feedc,Feed_seller)=   P_Feed_seller(feedc,Feed_seller,"p_price_seller")/p_pricescalar;
p_price_Livestock_seller(type_animal,Livestock_seller)=   P_Livestock_seller(type_animal,Livestock_seller,"p_price_seller")/p_pricescalar;

loop(inout_a,
    p_capacity_seller_A(inout_a,seller_A) = P_seller_A(inout_a,seller_A,"p_capacity_seller");
    p_labor_seller_A(inout_a,seller_A)    = P_seller_A(inout_a,seller_A,"p_labor_seller");
);
$endif

*Value chain and agroforestry activity

$iftheni %ORCHARD%==on
Parameter
P_seller_AF(inout,seller_AF,*)
p_capacity_seller_AF(inout,seller_AF)
p_distance_seller_AF(hhold,seller_AF)
p_labor_seller_AF(inout,seller_AF)
;

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%value_chain_%region%_new.xlsx
    symbols:
       - {name: seller_AF, range: value_chain!S5, columnDimension: 0, rowDimension: 1, type: set}
       - {name: P_seller_AF, range: value_chain!T4:X5000, columnDimension: 1, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%value_chain_%region%_new.xlsx o=DATA%system.DirSep%value_chain_%region%_new.gdx se=2 index=index!A3"
$gdxin "DATA%system.DirSep%value_chain_%region%_new.gdx"
$load  seller_AF P_seller_AF
$gdxin
$endif







p_capacity_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_capacity_seller");
p_labor_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_labor_seller");
p_distance_seller_AF(hhold,seller_AF)=p_distance(hhold,seller_AF);
p_price_seller(inout,seller_AF)=   P_seller_AF(inout,seller_AF,"p_price_seller")/p_pricescalar;
$endif


* Declare value chain variables
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
positive Variable
v_transportCost_seller(hhold,y) "Transport cost from sellers to households"
v_transportCost_buyer(hhold,y)  "Transport cost from households to buyers"
v_laborSellerInput(y)           "Total labor input from sellers"
v_laborBuyerOutput(y)           "Total labor output for buyers"
v_outputBuyer(hhold,inout,buyer,y)    "Quantity sold to buyers"
v_inputSeller_C(hhold,inout,seller_C,y)   "Quantity purchased from sellers"
v_inputSeller_AF(hhold,inout,seller_AF,y)   "Quantity purchased from sellers"
v_inputSeller_A(hhold,*,seller_A,y)   "Quantity purchased from sellers"
v_laborSeller_A(y)

v_transportCost_crop(hhold,y)
v_transportCost_orchard(hhold,y)
V_TransportCost_A(hhold,y)

v_seedSeeder(hhold,crop_activity,seeder,y)
v_laborSeeder(y)
v_transportCost_seeder(hhold,y)

v_Livestock_seller(hhold,type_animal,Livestock_seller,y)
v_laborLivestock_seller(y)
v_transportCost_Livestock_seller(hhold,y)
v_laborSeller_AF(y)
v_Feed_seller(hhold,feedc,Feed_seller,y)
v_laborFeed_seller(y)
v_transportCost_Feed_seller(hhold,y)
v_GHG(hhold,y)
v_GHG_C(hhold,y) "GHG from crop"
v_GHG_AF(hhold,y) "GHG from agroforestry"
v_GHG_livestock(hhold,y) "GHG from livestock"
;
$endif

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 10: PMP Calibration (Conditional)
*             - Includes PMP calibration components when active
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$iftheni %CROP%==on
parameter
** (SiwaPMP) additional parameters needed for PMP calibration
  delta1                   small number  /0.0001/
  PMPslope(hhold,crop_activity)      'PMP cost function slope'
  PMPint(hhold,crop_activity)        'PMP cost function intercept'
  PMPdualVal(hhold,crop_activity)    'shadow value from PMP calibration constraints'
  PMPSolnCheck(hhold,crop_activity,*)    'Comparison of results from PMP calibration with data'
  PMPswitch   switch for PMP constrained calibration stage  /1/
;
PMPint(hhold,crop_activity_endo) = 0;
PMPslope(hhold,crop_activity_endo) = 0;
display delta1;
$endif

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 10: Biophysical
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$iftheni %BIOPH%==on
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Sets for water
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*All these categories cames from the book of FAO 
set
  CC      'crop categories'       /cc1*cc4/
  GE      'Etm categories'        /E02*E10/
  GDe     'D   categories'        /D025,D050,D100,D150,D200/
  GGA     'ASI  categories'       /A000,A017,A033,A050,A067,A100/

;
*correction 03-12
* #2 Water parameters (WATER)
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter
*-- yield response parameters

         ym(crop_activity,field,inten)              'maximum yield (t/ha)'
*         p_ky(crop_activity,field,inten)            'yield response factor specified by crop'
         p_hw(hhold,crop_activity,field,inten)            'water stress factor'
         p_etm(crop_activity,field,inten)           'maximum evapotransporation (mm/day)'
         p_kc(crop_activity,field,inten)            'crop coefficient'
         p_et0                           'reference evapotransporation (mm/day)'
         p_et0_raw                    'variation of et0 per month per year'
         p_eta_m                         'monthly actual evapotransporation (mm)'
         p_etm_m                         'monthly maximum evapotransporation (mm)'
         p_etm_t                         'annual maximum evapotransporation (mm)'
         p_eta_t                         'annual actual evapotransporation (mm)'

*-- irrigation parameters for crops
         p_luse(crop_activity,field,inten,m)        'crop cycle - land use coefficient'
*         p_nirr                          'monthly net irrigation (mm/month)'
         p_rain                       'monthly effective rainfall (mm/month)'
*-- soil water parameters
         p_asi                           'available soil water index'
         p_swd0(hhold,crop_activity,field,inten)          'initial soil water depth (mm/month)'
         p_swd(hhold,crop_activity,field,inten,m)         'actual soil water depth at sowing (mm/month)'
*wdf is p : the soil water depletion fraction
         p_wdf                           'soil water depletion fraction for crop groups and Etm'
         p_factor(crop_activity,field,inten)       'actual soil water depletion fraction table 22 FAO'
*rdm is the D parameter
         p_rdm(crop_activity,inten)                'maximum rooting depth by crop (m)'
         p_swa(crop_activity,field,inten)           'soil water available by crop (mm/m soil depth)'
         p_swr                           'remaining soil water (mm)'
         p_swa_m(crop_activity,field,inten,*)       'soil water available by crop (mm/m soil depth)'
*         p_eta_tab                       'table to calculate eta as function of asi and swr'
*         p_swpar                         'soil water parameters'
*excel
         p_swm(field)                       'maximum soil water available (mm/m depth of the soil)'   
         p_cropCoef(hhold,crop_activity,field,inten,*)
         p_d(hhold,crop_activity,field,inten,m)                             'soil water drainage'
         P_D_t(hhold,crop_activity,field,inten)
         p_ke(crop_activity,field,inten,ge)
         p_pricescalar
         p_kee(*,*,*,ge)
         p_kd(*,*,*,gde)
         p_swd12(hhold,crop_activity,field,inten)
         crop_wdf(crop_activity, ge)
         ky2(*,*,*,*,*)
         hw2(*,*,*,*,*)
         last_active_month

*-- crop yield
         v0_Yld_C(hhold,crop_activity,*,field,inten)       'crop activity yield (t/ha)'
         v_Yld_C_max(hhold,crop_activity,*,field,inten)    'maximum activity yield (t/ha)'
;

POSITIVE variable
* v_irr(hhold,crop_activity,field,inten,m,y)      'irrigation quantity mm/month or m3/ha/month/10'
 v_costirr(hhold,y);



*Nitrogen fixed value
Parameters
    p_nav_begin_fixed(hhold,field,inten,crop_activity,y)   'Fixed available N at year beginning'
    p_nmin_fixed(hhold,field,y)              'Fixed mineralized nitrogen'
    p_Nres_fixed(hhold,field,y)              'Fixed nitrogen from residues'
    p_nl_fixed(hhold,crop_activity,field,inten,y)          'Fixed nitrogen leaching'
    p_nfin_fixed(hhold,field,inten,crop_activity,y)        'Fixed final nitrogen'
    p_hini_fixed(hhold,field,y)              'Fixed initial humus'
    p_hfin_fixed(hhold,field,y)              'Fixed final humus'
    p_nav_fixed(hhold,field,inten,crop_activity,y)         'Fixed total available nitrogen'
    p_nab_fixed(hhold,crop_activity,field,inten,y)         'Fixed nitrogen absorbed by crop'
    p_nstress_fixed(hhold,crop_activity,field,inten,y)     'Fixed nitrogen stress coefficient'
;

Parameters
    p_irrigation_opt_fixed(hhold,crop_activity,field,inten,m,y) 'Fixed monthly irrigation (mm)'
    p_KS_month_fixed(hhold,crop_activity,field,inten,m,y)      'Fixed monthly water stress KS'
    p_DR_start_fixed(hhold,crop_activity,field,inten,m,y)      'Fixed water balance at month beginning'
    p_DR_end_fixed(hhold,crop_activity,field,inten,m,y)        'Fixed water balance at month end'
    p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,y)   'Fixed annual average KS'
    p_DR_excess_fixed(hhold,crop_activity,field,inten,m,y)     'Fixed excess water'
    p_KS_total_fixed(hhold,crop_activity,field,inten,m,y)      'Fixed sum of KS by month'
    p_b_KS_fixed(hhold,crop_activity,field,inten,m,y)          'Fixed binary KS indicator'
    p_b_DR_negative_fixed(hhold,crop_activity,field,inten,m,y) 'Fixed binary DR negative indicator'
;

Parameter
    TAW(hhold,crop_activity,field,inten)                    'Total Available Water (mm)'
    RAW(hhold,crop_activity,field,inten,m,y)                    'Readily Available Water (mm)'
    CR(hhold,crop_activity,field,inten)                     'Capillary Rise, arbitrary put at this level'
    days_in_month(m)                                    'Nombre de jours par mois'
    ET0_month(hhold,crop_activity,field,inten,m,y)
    p_test(hhold,crop_activity,field,inten,m,y)  
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Parameters for nitrate
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter
calibBioph(hhold,crop_activity,*,field,inten);

calibBioph(hhold,crop_activity,crop_preceding,field,inten)=eps;

parameters
p_cropCoef(hhold,crop_activity,field,inten,*)
*-- Source of nitrate by activity
p_Qfert(hhold,crop_activity,field,inten)      'Quantity of fertilizer by activity (kg per ha)'
p_Qres(hhold,inout,field,inten)       'Quantity of residues from precedent crop (kg per ha)'
p_Qcomp(hhold)      'Quantity of compost (kg per ha)'
*P_Qman(crop_activity,field,inten,y)          'Quantity of manure (kg per ha)'
p_humus                          'Quantity of humus (kg per ha)'

*-- Nitrate parameters to compute the nitrate stress
P_Npot(hhold,crop_activity,field,inten)       'N necessary for optimal growth (kg per ha)'
p_Nmin(hhold,crop_activity,field,inten)       'N mineralized from humus (kg per ha)'
p_Nab(hhold,crop_activity,field,inten)        'Current absorption of Nitrate (kg per ha)'
p_Nav(hhold,crop_activity,field,inten)        'Available Nitrate (kg per ha)'
p_Nini(hhold,field)       'Initial amount of Nitrate'
p_Nl(hhold,crop_activity,field,inten)         'N leaching (fixed at 10% of N_fert in kg per ha)'
p_Nw(hhold,crop_activity,field,inten)             'Coefficient of Nitrate stress'

*-- Nitrate parameters according to origin
*p_Nitr=p_Nres+p_ Norg+p_Nfert+p_Ncomp
p_Nitr(hhold,crop_activity,field,inten)       'Total Nitrate requirements by activity (kg per ha)'
p_Nres(hhold,inout,field,inten)       'N from precedent crop residue (kg per ha)'
p_Nres_raw
p_Norg(hhold)       'N from organic fertilization (kg per ha)'
p_Nfert(hhold,crop_activity,field,inten)      'N from mineral fertilization (kg per ha)'
*p_Ncomp(hhold,crop_activity,field,inten)      'N from compost (kg per ha)'
p_Nfin(hhold,crop_activity,field,inten)       'N at the end of the growth period (kg per ha)'
p_Hfin(hhold,crop_activity,field,inten)       'Final amount of humus (%)'
p_Hini(hhold,field)       'Amount of inorganic matter (initial amount of humus) (%)'
*--other parameters
p_MScomp(hhold)     'amount of biomass from compost (%)'
K3                               'humification rate'
P_Nfert_y(hhold,crop_activity,field,inten)
K1(crop_activity)           'Coefficient for Nitrate conversion'
K2(field)            'mineralization rate'
da               'Soil bulk density (kg per m3)'
prof             'Ploughed layer (m)'
p_MSres          '% of dry matter from Qres'
p_effr(inout)    'Nitrate by kg of biomass'
p_Nini_raw          'Nini is given at the begining (month 1, year 1)'
p_Norg_raw          'Nitrate from manure for first year'
p_Qcomp_raw
p_MScomp_raw
p_Nl_raw            'Rate of nitrate leaching'
p_Nw2(*,*,*,*,*)
p_OrgMat(*,*,*,*)
p_nfert_max_annual_raw
p_Hini_raw          'Nini is given at the begining (month 1, year 1)'
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* After water stress we add the Nitogen
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*set map_cc ;
parameter
  mday(m)    'number of days per month' /(M01,M03,M05,M07,M08,M10,M12) 31
                                         (M04,M06,M09,M11) 30
                                          M02              28/
;
Scalar lastMonth;
lastMonth = card(m);
Scalar discretization2 /10000/;
parameter  p_meteo
*          p_eta_tab
           p_Humus
           agro
;

*Irrigation small module 06-2025
parameter v0_max_irrigation(hhold,crop_activity,field,inten,m,y)
p_cost_irrigation(hhold)
*v0_irrigation(hhold,crop_activity,field,inten,m)
irrigation_raw
irrigation_month;

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%biopars_%region%_new.xlsx
    symbols:
       - {name: p_meteo, range: water!A4:M5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: p_et0_raw, range: water!N4:Z5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: agro, range: water!AA3:AF5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: p_swm, range: water!AG4:AH5000, columnDimension: 0, rowDimension: 1, type: par}
       - {name: irrigation_raw, range: water!AX3:AZ5000, columnDimension: 1, rowDimension: 1, type: par}
       - {name: irrigation_month, range: water!AI3:AW5000, columnDimension: 1, rowDimension: 3, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endIf

* delete map_cc p_idat
*   ---- import data (from xls to gdx)
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA/biopars_%region%_new.xlsx se=2 o=DATA/biopars_%region%_new.gdx se=2 index=index!A3"
$gdxin DATA/biopars_%region%_new.gdx
$load  p_meteo p_et0_raw p_swm agro  irrigation_raw irrigation_month
$gdxin
$endIf





v0_max_irrigation(hhold,crop_activity_endo,field,inten,m,y)=irrigation_raw(hhold,'v0_max_irrigation');
p_cost_irrigation(hhold)=irrigation_raw(hhold,'p_cost_irrigation');
*v0_irrigation(hhold,crop_activity_endo,field,inten,m)=irrigation_month(hhold,m);


*loading agronomic parameters
$iftheni %LINUX%==off
*$gdxin "biopars.gdx"
*$load  p_humus
*$gdxin
$call "gdxxrw.exe DATA%system.DirSep%nitratedata_%region%_new.xlsx o=DATA%system.DirSep%nitratedata_%region%_new.gdx se=2 index=index_nitrate!A3"
$gdxin "DATA%system.DirSep%nitratedata_%region%_new.gdx"
$load K1 p_Nres_raw K2 da prof p_MSres p_effr p_Nini_raw p_Qcomp_raw p_MScomp_raw K3 p_Norg_raw p_Nl_raw p_nfert_max_annual_raw p_Hini_raw
$gdxin
$endIf

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%nitratedata_%region%_new.xlsx
    symbols:
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
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif
*$include "Biophysical_database.gms"

$iftheni %BiophCalib%==on

parameter 
p_water_calib(crop_activity,inten)
p_nitr_calib(crop_activity,inten)
;
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%bioph_calib_%region%_new.xlsx o=DATA%system.DirSep%bioph_calib_%region%_new.gdx se=2 index=index!A3"
$gdxin "DATA%system.DirSep%bioph_calib_%region%_new.gdx"
$load p_water_calib p_nitr_calib
$gdxin
$endIf

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%bioph_calib_%region%_new.xlsx
    symbols:
       - {name: p_water_calib, range: calib_data!A4:C5000, columnDimension: 0, rowDimension: 2, type: par}
       - {name: p_nitr_calib, range: calib_data!D4:F5000, columnDimension: 0, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif
display
p_nitr_calib
p_water_calib
;

$endIf

* ================================================================
* SETS AND PARAMETERS FOR ANNUAL NITROGEN OPTIMIZATION
* ================================================================
* Nitrogen parameters (annual basis)
*Parameter
**    p_k1(crop_activity)      'Coefficient for nitrate conversion'
**    p_k2(field)                   'Mineralization rate'
**    p_k3                          'Compost conversion factor' /0.7/
*    p_da                          'Soil bulk density (kg/m³)' /1.41/
**    p_prof                        'Ploughed layer depth (m)' /0.25/
**    p_mscomp                      '% of dry matter in compost'
**    p_ncomp_raw                   'Initial compost nitrogen'
**    p_qcomp_raw                   'Initial compost quantity'
**    p_effr(crop_activity)    'Nitrogen efficiency by crop'
*    p_perresmulch(crop_activity) 'Percentage of residue mulch'
*;





* Annual nitrogen dynamics parameters
Parameter
*    p_nmin(hhold,crop_activity,field,inten)     'Annual mineralized nitrogen (kg/ha)'
*    p_nav(hhold,crop_activity,field,inten)      'Annual available nitrogen (kg/ha)'
*    p_npot(hhold,crop_activity,field,inten)     'Annual potential nitrogen demand (kg/ha)'
*    p_nab(hhold,crop_activity,field,inten)      'Annual absorbed nitrogen (kg/ha)'
*    p_qres(hhold,crop_activity,field,inten)     'Annual residue quantity (kg/ha)'
*    p_nres(hhold,crop_activity,field,inten)     'Annual nitrogen from residues (kg/ha)'
    p_ncomp(hhold)    'Annual nitrogen from compost (kg/ha)'
*    p_nfert_total(hhold,crop_activity,field,inten) 'Annual fertilizer input (kg/ha)'
*    p_nl(hhold,crop_activity,field,inten)       'Annual nitrogen leaching (kg/ha)'
*    p_norg(hhold,crop_activity,field,inten)     'Annual organic nitrogen (kg/ha)'
    p_nfert_max_annual(hhold,crop_activity,field,inten) 'Maximum annual fertilizer application (kg/ha)'
    
;

* Initial organic nitrogen (could be from manure)
p_norg(hhold) = p_norg_raw;
p_Nres(hhold,ck,field,inten) = 0;
* Maximum annual fertilizer application (kg/ha)
p_nfert_max_annual(hhold,crop_activity_endo,field,inten) =  p_nfert_max_annual_raw;




$endif
***DIVERSITY****
****DIVERSITY
* Total number of observations (households × years × crops)
scalar n_total;
n_total = card(hhold) * card(y) * card(crop_activity_endo);
* This approach is most likely to converge without initial values
positive variable
    overall_cv;
positive variable
    total_sum
    mean_val
    variance_val
    std_dev
    ;
variable
cv_val
V_Total_ValueChain_Labor
V_GHGtotal
;



$iftheni %ENERGY%==on
variable
    V_energy(hhold,y)
;
parameter
enerReqtask_crop(*,*,*,*)
enerReqtask_AF(*,*,*,*)
enerReq_Livestock(*,*,*)
enerReq_Feed(*,*,*)
;
*-- import data (from xls to gdx)
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA%system.DirSep%energy_%region%_new.xlsx o=DATA%system.DirSep%energy_%region%_new.gdx se=2 index=index_coef!A3"
$gdxin "DATA%system.DirSep%energy_%region%_new.gdx"
$load enerReqtask_crop  enerReqtask_AF enerReq_Livestock enerReq_Feed
$gdxin
$endif
$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%energy_%region%_new.xlsx
    symbols:
       - {name: enerReqtask_crop, range: energy_data!A4:N5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: enerReqtask_AF, range: energy_data!O4:AC5000, columnDimension: 1, rowDimension: 3, type: par}
       - {name: enerReq_Livestock, range: energy_data!AD4:AF5000, columnDimension: 1, rowDimension: 2, type: par}
       - {name: enerReq_Feed, range: energy_data!AG4:AI5000, columnDimension: 1, rowDimension: 2, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

parameter
enerReqtask_crop(*,*,*,*)
enerReqtask_AF(*,*,*,*)
enerReq_Livestock(*,*,*)
enerReq_Feed(*,*,*)
p_energy_crop(hhold,crop_activity,inten,*)
p_energy_task_crop(hhold,crop_activity,inten,*)
p_energy_task_AF(hhold,c_tree,inten,*)
p_energy_AF(hhold,c_tree,inten,*)
;

$iftheni %ORCHARD%==on
*enerReqtask_AF(hhold,c_tree,inten,*)
p_energy_task_AF(hhold,c_tree,inten,NamePlantingAF) =  enerReqtask_AF(hhold,c_tree,inten,"plant_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameGrubbAF)=enerReqtask_AF(hhold, c_tree,inten,"grubb_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameChe_fertAF) =  enerReqtask_AF(hhold, c_tree,inten,"chemfer_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameWeedingAF)=enerReqtask_AF(hhold, c_tree,inten,"weed_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameOrg_fertAF) =  enerReqtask_AF(hhold, c_tree,inten,"orgfer_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NamePesticideAF)=  enerReqtask_AF(hhold, c_tree,inten,"pest_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NameHarvestAF)  =  enerReqtask_AF(hhold, c_tree,inten,"harv_MJ_ha");
p_energy_task_AF(hhold,c_tree,inten,NamePruningAF)  =  enerReqtask_AF(hhold, c_tree,inten,"prun_MJ_ha");
p_energy_AF(hhold,c_tree,inten,m) = sum(c_t_m_orchard(c_tree,task_tree,m), p_energy_task_AF(hhold,c_tree,inten,task_tree) );
$endIf

*enerReqtask_crop(hhold,crop_activity,inten,*)
*-- write to labor requirement parameter
$iftheni %CROP%==on
p_energy_task_crop(hhold,crop_activity,inten,NamePlanting) =  enerReqtask_crop(hhold,crop_activity,inten,"plant_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameWeeding)  =  enerReqtask_crop (hhold,crop_activity,inten,"weed_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameHerbicide)=  enerReqtask_crop (hhold,crop_activity,inten,"herb_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameChe_fert) =  enerReqtask_crop(hhold,crop_activity,inten,"chemfer_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameOrg_fert) =  enerReqtask_crop(hhold,crop_activity,inten,"orgfer_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NamePesticide)=  enerReqtask_crop(hhold,crop_activity,inten,"pest_MJ_ha");
p_energy_task_crop(hhold,crop_activity,inten,NameHarvest)  =  enerReqtask_crop(hhold,crop_activity,inten,"harv_MJ_ha") ;
p_energy_crop(hhold,crop_activity,inten,m) = sum(c_t_m(crop_activity,task,m), p_energy_task_crop(hhold,crop_activity,inten,task) );

display enerReqtask_crop;
*p_energy_AF(hhold,c_tree,inten,m)
* p_energy_crop(hhold,crop_activity,inten,m) 
*enerReqtask_AF(hhold,c_tree,inten,"fertilizer")    
*enerReqtask_AF(hhold,c_tree,inten,"phytosanitary") 
*enerReqtask_AF(hhold,c_tree,inten,"seeds") 
*enerReqtask_AF(hhold,c_tree,inten,"irrigation")
*enerReqtask_crop(hhold,crop_activity,inten,"fertilizer")    
*enerReqtask_crop(hhold,crop_activity,inten,"phytosanitary") 
*enerReqtask_crop(hhold,crop_activity,inten,"seeds") 
*enerReqtask_crop(hhold,crop_activity,inten,"irrigation")
*enerReq_Livestock(hhold,type_animal,"energy")
*enerReq_Feed(hhold,feedc,"p_feed_energy")
*
$endIf
$endIf
$exit





*$label set_database_reinitialize
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 2: Crop Activity Data
**            - Loads coefficients for crop activities
**            - Handles two intensification levels (extensive and intensive)
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** Declare parameters for crop data
**-- crop data parameters and livestock prices
*
*
** Process and map raw crop data to model parameters
*p_cropCoef(hhold,crop_activity,field,inten,NameSeed)  = p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_kg_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NameNitr)  = p_cropCoef_raw(hhold,crop_activity,field,inten,"nitr_kg_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NameYield) = p_cropCoef_raw(hhold,crop_activity,field,inten,"yield_kg_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NameStraw) = p_cropCoef_raw(hhold,crop_activity,field,inten,"ystraw_kg_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NamePhyto) = p_cropCoef_raw(hhold,crop_activity,field,inten,"phyto_localCurrency_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NameOther) = p_cropCoef_raw(hhold,crop_activity,field,inten,"other_localCurrency_ha");
*p_cropCoef(hhold,crop_activity,field,inten,NameArea) = p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha");
*p_perresmulch(inout)=p_resmulch(inout);
*p_residuedep = residuedep;
*p_seedData(hhold,crop_activity,NameseedOnFarm) =  smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_onFarm_ha"));
*p_seedData(hhold,crop_activity,NameseedTotal)= smax((field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"seeds_kg_ha"));
*
**-- write to labor requirement parameter
*p_labReqTask(hhold,crop_activity,inten,NamePlanting) =  labReqTask(hhold,crop_activity,inten,"plant_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NameWeeding)  =  labReqTask(hhold,crop_activity,inten,"weed_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NameHerbicide)=  labReqTask(hhold,crop_activity,inten,"herb_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NameChe_fert) =  labReqTask(hhold,crop_activity,inten,"chemfer_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NameOrg_fert) =  labReqTask(hhold,crop_activity,inten,"orgfer_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NamePesticide)=  labReqTask(hhold,crop_activity,inten,"pest_persday_ha");
*p_labReqTask(hhold,crop_activity,inten,NameHarvest)  =  labReqTask(hhold,crop_activity,inten,"harv_persday_ha");
*p_laborReq(hhold,crop_activity,inten,m) = sum(c_t_m(crop_activity,task,m), p_labReqTask(hhold,crop_activity,inten,task) );
*
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 3: Farm and Output Data
**            - Loads farm-level information including land use and labor
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*
*
** Calculate farm data parameters
*p_farmData(hhold,'allc',field,'cropland') = sum((crop_activity,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
*p_farmData(hhold,'allc','total','cropland') = sum((crop_activity,field,inten),p_cropCoef_raw(hhold,crop_activity,field,inten,"area_ha"));
*p_farmData(hhold,'labor','family','total')  =  farmlabData_raw(hhold,'fam_m_persday_ha')+ farmlabData_raw(hhold,'fam_f_persday_ha');
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 4: Household and Consumption Data
**            - Loads demographic and consumption information
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*
**Set NameHH / hh_size/ ;
*p_hholdData(hhold,'hh_size')        = hholdData_raw(hhold,'hh_size');
*p_hholdData(hhold,'lab_family')     = p_farmData(hhold,'labor','family','total')  ;
*p_hholdData(hhold,'inc_offfarm')    = hholdData_raw(hhold,'inc_offfarm');
*p_consoData(hhold,gd,'ave') = consodata_raw(hhold,gd,'average');
*
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 5: Price Data
**            - Loads and processes price information for all commodities
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*
**in localCurrency
*p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice');
*p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice');
*p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price');
*p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg');
**in USD
*
*p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)= p_cropCoef(hhold,crop_activity,field,inten,NamePhyto)/p_pricescalar;
*p_cropCoef(hhold,crop_activity,field,inten,NameOther)= p_cropCoef(hhold,crop_activity,field,inten,NameOther)/p_pricescalar;
*p_hholdData(hhold,'inc_offfarm')=p_hholdData(hhold,'inc_offfarm')/p_pricescalar ;
*
*p_cpriData(hhold,inout,'buyPrice') =   cpriData_raw(hhold,inout,'buyPrice')/p_pricescalar;
*p_cpriData(hhold,inout,'selPrice')=    cpriData_raw(hhold,inout,'selPrice')/p_pricescalar;
*p_gpriData(hhold,gd,'p_good_price')  = gpriData_raw(hhold,gd,'p_good_price')/p_pricescalar;
*p_spriData(hhold,crop_activity,'seedPrice') = spriData_raw(hhold,crop_activity,'pseed_localCurrency_kg')/p_pricescalar;
*p_distanceprice(hhold)=cpriData_raw(hhold,'distance_km','buyPrice')/p_pricescalar;
*p_selPrice(hhold,inout)=  p_cpriData(hhold,inout,'selprice');
*p_buyPrice(hhold,inout)=  p_cpriData(hhold,inout,'buyprice');
*p_seedbuypri(hhold,crop_activity)= p_spriData(hhold,crop_activity,'seedPrice') ;
*
*
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 6: Crop Module (Conditional)
**            - Defines crop-related variables and equations when crop module is active
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*
*$iftheni %CROP%==on
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** #1 Model parameters
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
**set previouscrop;
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** #2 Load crop activity coefficients
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**Similar to lines in bioph module delete
**-- crop yield
*v0_Yld_C(hhold,crop_activity,'allp',field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield));
**TFix: yield by activity needed => assume similar yields over all preceding crops
*v0_Yld_C(hhold,crop_activity,crop_preceding,field,inten) $(c_c(crop_activity,crop_preceding)) = v0_Yld_C(hhold,crop_activity,'allp',field,inten);
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**-- Cropland allocation
*v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
*display v0_Land_C;
*v0_Use_Land_C(hhold,field) = sum(crop_activity, v0_Land_C(hhold,crop_activity,field)) ;
*V0_Plant_C(hhold,crop_activity,'allp',field,inten) = sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
*V0_Plant_C(hhold,crop_activity,previouscrop,field,inten) = V0_Plant_C(hhold,crop_activity,'allp',field,inten);
**-- Crop production (kg)
*v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
*v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
*v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
*
**~~~~~~~~~~~~~~~~ input requirements    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**-- endogenous activities => crop coefficients
**   .. labor not included
*p_inputReq(hhold,crop_activity_endo,field,inten,inpq) $(not NameLabor(inpq)) = p_cropcoef(hhold,crop_activity_endo,field,inten,inpq);
*p_inputReq(hhold,crop_activity_endo,field,inten,inpv) = p_cropcoef(hhold,crop_activity_endo,field,inten,inpv);
*p_inputReq(hhold,crop_activity_endo,field,inten,NameFert) $(sum(NameNitr,p_inputReq(hhold,crop_activity_endo,field,inten,NameNitr))) = 0;
*
**~~~~~~~~~~~~~~~~ inputs and outputs      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**-- initial input use and cost
*V0_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
*V0_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
*V0_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
*v0_inputCost(hhold,crop_activity_endo,inpv)=sum((field,inten),p_cropcoef(hhold,crop_activity_endo,field,inten,inpv));
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** #2 Variables
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*
**=================================================
** The below code map sets
**=================================================
*
*
**Creation of the map for the harvest of coproducts
** Set c_t_m_map(cken, m) to yes if harvest occurs in month m for activity crop_activity_endo
*loop((crop_activity_endo, cken)$activity_output(crop_activity_endo, cken),
*  c_t_m_map(cken, m)$c_t_m(crop_activity_endo, 'harvest', m) = yes;
*);
*
** Coproduct handling 
** Identification of the months in which coproducts are harvested and flags subsequent months.
**(count to track the first harvest month and flag for the subsequent month)
*loop(cken,  
*  count = 0; 
*  stopflag = 0;  
*  loop(m$(stopflag eq 0),  
*    count = count + 1;  
*    indic(cken, m)$c_t_m_map(cken, m) = 1;  
*    stopflag$(indic(cken, m) eq 1) = 1; 
*  );
*  flag(cken, m)$(ord(m) ge count) = 1;  
*);
*
** Calculation of coproduct indicators 
** This section calculates indicators (flagm) for coproducts based on their harvest order.
*loop(cken,  
*  countm = 0;  
*  loop(m$flag(cken, m),  
*    flagm(cken, m) = 1$(countm = 0);  
*    flagm(cken, m) = 1 - (p_residuedep * countm)$(countm > 0);  
*    countm = countm + 1; 
*  );
*);
*
*
*$endif
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 7: Agroforestry Module (Conditional)
**            - Defines orchard/agroforestry components when module is active
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
** Declare agroforestry sets and parameters
*$iftheni %ORCHARD%==on
*
*c_treej(outm) = yes $(sum(activity_output(c_tree,outm),1));
*a_c_treej(c_tree,c_treej) $(activity_output(c_tree,c_treej)) = yes ;
*
** Process agroforestry data
*V0_Area_AF(hhold,field,inten)=sum(c_tree,v0_cropCoef_AF(hhold,c_tree,field,inten,"area_ha")) ;
*v0costPhyto_AF(hhold,c_tree,field,inten)=v0_cropCoef_AF(hhold,c_tree,field,inten,"phyto_localCurrency_ha")/p_pricescalar;
*v0costOther_AF(hhold,c_tree,field,inten)=v0_cropCoef_AF(hhold,c_tree,field,inten,"other_localCurrency_ha")/p_pricescalar;
*p_taskLabor_cost(task_tree)=p_taskLabor_cost_LocalCur(task_tree)/p_pricescalar;
*p_buyPrice_tree(inputprice_tree,c_tree)=p_buyPrice_tree_LocalCur(inputprice_tree,c_tree)/p_pricescalar;
*
*p_Labor_Task_AF(hhold,c_tree,inten,NamePlantingAF) =  Labor_Task_AF(hhold,c_tree,inten,"plant_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NameWeedingAF)  =  Labor_Task_AF(hhold,c_tree,inten,"weed_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NameGrubbAF)=  Labor_Task_AF(hhold,c_tree,inten,"grubb_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NameChe_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"chemfer_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NameOrg_fertAF) =  Labor_Task_AF(hhold,c_tree,inten,"orgfer_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NamePesticideAF)=  Labor_Task_AF(hhold,c_tree,inten,"pest_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NameHarvestAF)  =  Labor_Task_AF(hhold,c_tree,inten,"harv_persday_ha");
*p_Labor_Task_AF(hhold,c_tree,inten,NamePruningAF)  =  Labor_Task_AF(hhold,c_tree,inten,"harv_persday_ha");
*p_laborReq_AF(hhold,c_tree,inten,m) = sum(c_t_m_orchard(c_tree,task_tree,m), p_Labor_Task_AF(hhold,c_tree,inten,task_tree) );
**
*
*$endif
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 8: Livestock Module (Simplified, Conditional)
**            - Defines livestock components when module is active
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**============================================================================*
** #1 DECLARE SETS AND PARAMETERS
**============================================================================*
*
*$iftheni %LIVESTOCK_simplified%==on
*
*
*
*
** Process loaded data
*p_selPriceLivestock(hhold,type_animal,ak) = p_selPriceLivestock_raw(hhold,type_animal,ak,'price')/p_pricescalar;
*p_selPriceLivestock(hhold,type_animal,'liveanimal') = p_selPriceLivestock_raw(hhold,type_animal,'liveanimal','price')/p_pricescalar;
*p_yieldLivestock(hhold,type_animal,akmeat) = p_yieldLivestock_raw(hhold,type_animal,akmeat,'yield');
*p_yieldLivestock(hhold,type_animal,akmilk) = p_yieldLivestock_raw(hhold,type_animal,akmilk,'yield');
*
** Assign parameter values from raw data
*p_othCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_othCostLivestock')/p_pricescalar;
*p_costVeterinary(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_costVeterinary')/p_pricescalar;
*p_AdditionalCostLivestock(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_AdditionalCostLivestock')/p_pricescalar;
**p_MilkYield(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_MilkYield');       
**p_MeatYield(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_MeatYield');        
*p_Repro(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_BirthRate');       
*p_MortalityRate(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_MortalityRate');   
*p_LaborReqLivestock(hhold,type_animal,m) = p_DataLive(hhold,type_animal,'1','p_LaborReq')/12;        
*p_prot_metab(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_prot_metab');       
*p_ca(hhold,type_animal) = p_DataLive(hhold,type_animal,'1','p_ca');   
*p_initPopulation(hhold,type_animal,age) = p_DataLive(hhold,type_animal,age,'p_initPopulation');
*p_feed_price(hhold,feedc)=p_feed_price_LocalCur(hhold,feedc)/p_pricescalar;
*
** Create mappings
*a_k(type_animal,ak)$activity_output(type_animal,ak) = yes;
*akmilk(ak) = yes;
*akmeat(ak) = yes;
*
*
*$endif
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 9: Value Chain Module (Conditional)
**            - Defines market linkages when module is active
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*$iftheni %VALUECHAIN%==on
*
*
*
*
*p_capacity_buyer(inout,buyer)=P_buyer(inout,buyer,"p_capacity_buyer");
*p_labor_buyer(inout,buyer)=P_buyer(inout,buyer,"p_labor_buyer");
*p_distance_buyer(hhold,buyer)=p_distance(hhold,buyer);
*p_price_buyer(inout,buyer)=   P_buyer(inout,buyer,"p_price_buyer")/p_pricescalar;
*
*p_capacity_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_capacity_seller");
*p_labor_seller_C(inout,seller_C)=P_seller_C(inout,seller_C,"p_labor_seller");
*p_distance_seller_C(hhold,seller_C)=p_distance(hhold,seller_C);
*p_price_seller(inout,seller_C)=   P_seller_C(inout,seller_C,"p_price_seller")/p_pricescalar;
*
*p_capacity_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_capacity_seeder");
*p_labor_seeder(crop_activity,seeder)=P_seeder(crop_activity,seeder,"p_labor_seeder");
*p_distance_seeder(hhold,seeder)=p_distance(hhold,seeder);
*p_price_seeder(crop_activity,seeder)=   P_seeder(crop_activity,seeder,"p_price_seeder")/p_pricescalar;
*$endif
*
*
**Value chain and livestock activity
*
*
*$iftheni %LIVESTOCK_simplified%==on
*
*
*
*
*
*p_capacity_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_capacity_seller")/p_pricescalar;
*p_labor_seller_A(NamecostVeterinary,seller_A)=P_seller_A(NamecostVeterinary,seller_A,"p_labor_seller");
*p_distance_seller_A(hhold,seller_A)=p_distance(hhold,seller_A);
*p_capacity_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
*p_labor_seller_A(NameothCostLivestock,seller_A)=P_seller_A(NameothCostLivestock,seller_A,"p_labor_seller");
*p_capacity_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_capacity_seller")/p_pricescalar;
*p_labor_seller_A(NameAdditionalCostLivestock,seller_A)=P_seller_A(NameAdditionalCostLivestock,seller_A,"p_labor_seller");
*p_distance_seller_A(hhold,seller_A)=p_distance(hhold,seller_A);
*
*p_capacity_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller (type_animal,Livestock_seller,"p_capacity_seller");
*p_distance_Livestock_seller(hhold,Livestock_seller)=p_distance(hhold,Livestock_seller);
*p_labor_Livestock_seller(type_animal,Livestock_seller)=P_Livestock_seller(type_animal,Livestock_seller,"p_labor_seller");
*
*p_capacity_Feed_seller(feedc,Feed_seller)=P_Feed_seller (feedc,Feed_seller,"p_capacity_seller");
*p_distance_Feed_seller(hhold,Feed_seller)=p_distance(hhold,Feed_seller);
*p_labor_Feed_seller(feedc,Feed_seller)=P_Feed_seller(feedc,Feed_seller,"p_labor_seller");
*p_price_Feed_seller(feedc,Feed_seller)=   P_Feed_seller(feedc,Feed_seller,"p_price_seller")/p_pricescalar;
*p_price_Livestock_seller(type_animal,Livestock_seller)=   P_Livestock_seller(type_animal,Livestock_seller,"p_price_seller")/p_pricescalar;
*
*loop(inout_a,
*    p_capacity_seller_A(inout_a,seller_A) = P_seller_A(inout_a,seller_A,"p_capacity_seller");
*    p_labor_seller_A(inout_a,seller_A)    = P_seller_A(inout_a,seller_A,"p_labor_seller");
*);
*$endif
*
**Value chain and agroforestry activity
*
*$iftheni %ORCHARD%==on
*$ifi %VALUECHAIN%==ON p_capacity_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_capacity_seller");
*$ifi %VALUECHAIN%==ON p_labor_seller_AF(inout,seller_AF)=P_seller_AF(inout,seller_AF,"p_labor_seller");
*$ifi %VALUECHAIN%==ON p_distance_seller_AF(hhold,seller_AF)=p_distance(hhold,seller_AF);
*$ifi %VALUECHAIN%==ON p_price_seller(inout,seller_AF)=   P_seller_AF(inout,seller_AF,"p_price_seller")/p_pricescalar;
*$endif
*
*v0_Land_C(hhold,crop_activity,field)      =  sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;;
**-- Crop production
*v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
*V0_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
*V0_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
*V0_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
*v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
*v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
**
**
**
**
**
*
*
*
*
*
*
*
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** After water stress we add the Nitogen
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
**loading agronomic parameters
*
*
****DIVERSITY****
*****DIVERSITY
** Total number of observations (households × years × crops)
*
**
**
*
*$exit
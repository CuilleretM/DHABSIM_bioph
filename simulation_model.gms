*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : simulation_model.gms
   @purpose  : Define simulation model
   @author   : Maria Blanco <maria.blanco@upm.es>
   @date     : 22.09.14
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy : run_scenario.gms
 08-09 addition of stress in the loop
$offtext
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$onglobal
$iftheni %BIOPH%==on
Variable
  V_Tot_WaterUse
  V_QN
;
equations
*   E_max_irr             'cash constraint'
   E_cost_irr
   E_Tot_WaterUse
   E_QN
;

E_cost_irr(hhold,y).. v_costirr(hhold,y)=e=0
$ifi %CROP%==on  +(SUM((crop_activity,field,inten,m),v_irrigation_opt(hhold,crop_activity,field,inten,m,y)*sum(crop_preceding,V_Plant_C(hhold,crop_activity,crop_preceding,field,inten,y))*p_cost_irrigation(hhold)))/p_pricescalar;


E_QN ..
      V_QN =E= 0    
$ifi %CROP%==on  +p_Nl_raw*(sum((hhold,y),sum(crop_activity_endo, sum(NameNitr,V_Use_Input_C(hhold,crop_activity_endo,NameNitr,y)))))
$ifi %ORCHARD%==on + p_Nl_raw* sum((hhold,c_tree,y),V_Nfert_AF(hhold,c_tree,y))
;         

E_Tot_WaterUse ..
     V_Tot_WaterUse
          =E=
SUM((hhold,crop_activity,field,inten,y,m),v_irrigation_opt(hhold,crop_activity,field,inten,m,y))
;

$endIf
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Model parameters
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*Define before risk module because use in both module
parameter
*-- Discount factor
  dr                    'discount rate'
  rho(year)             'discount factor'
  p_phi                 'risk aversion coefficient';        
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA\RiskModule_%region%.xlsx o=DATA\RiskModule_%region%.gdx se=2 index=index_coef!A3"
$gdxin "DATA\RiskModule_%region%.gdx"
$load dr p_phi
$gdxin
$endif

$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%RiskModule_%region%.xlsx
    symbols:
       - {name: dr, range: dr!B1, columnDimension: 0, rowDimension: 0, type: par}
       - {name: p_phi, range: p_phi!B1, columnDimension: 0, rowDimension: 0, type: par}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif
rho(y) = 1/( (1+dr)**(y.pos-1) );

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Model Variables
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
variable
  v_npv_tot  'regional net present value'
  v_npv      'household net present value'
  v_util     'household utility'
  v_objectif
  V_Diversity
;
* Binary variable
    Binary Variables
        V_Crop_Number(y, hhold, crop_activity);
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #3 Model equations
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
equation
   E_UTIL        'utility function'
   E_NPV         'net present value'
   E_NPV_TOT     'net present value'
** (SiwaPMP) add equations needed for PMP (1st stage) calibration
   E_AreaConst_UpB  'upper bound constraint on crop area for calibration'
   E_AreaConst_LoB  'lower bound constraint on crop area for calibration'
   E_income_up
   E_income_lo


;  


equation
    E_Crop_Number_Def
    E_Diversity
    E_AreaConst
;
*
*scalar tiny_diversity /0.000001/;
$iftheni %CROP%==on
** Link to land allocation
E_Crop_Number_Def(hhold, crop_activity_endo, y)..
        sum(field,v_Land_C(hhold, crop_activity_endo,field, y)) =l= V_Crop_Number(y, hhold, crop_activity_endo) * 100;
*** The diversity measure itself
E_Diversity..
       V_Diversity =e= sum((y, hhold, crop_activity_endo), V_Crop_Number(y, hhold, crop_activity_endo));
$endIf



******************************************************************************************

*~~~~~~~~~~~~~~~~ utility definition    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*Utility based on the farm income define in farm module
E_UTIL(hhold,y)..  v_util(hhold,y) =E=  v_fullIncome(hhold,y)
$ifi %CONS%==on +sum(gd, p_goodPrice(hhold,gd)*(sum(output_good(c_product,gd), v_selfCons(hhold,c_product,y))- v_markPurch(hhold,gd,y))) ;
;

*~~~~~~~~~~~~~~~~ net present value     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- discounted utility + final value (value of liquidating farm in last year)

E_NPV(hhold)..     v_npv(hhold) =E=
  sum(y, rho(y)*v_util(hhold,y))
;


*RISK condition
E_NPV_TOT.. 
    v_npv_tot =E= 
    sum(hhold, v_npv(hhold)) 
$ifi %CROP%==on $ifi %PMPCalib%==on   - sum((hhold,crop_activity_endo,field,y), (PMPint(hhold,crop_activity_endo,field)$(PMPswitch = 2) + PMPslope(hhold,crop_activity_endo,field)$(PMPswitch = 2)*v_Land_C(hhold,crop_activity_endo,field,y))*v_Land_C(hhold,crop_activity_endo,field,y))$(PMPswitch = 2)
;


** (SiwaPMP)
$iftheni %CROP%==on
*~~~~~~~~~~~~~~  PMP calibration constraints (stage 1)~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* in first stage the calibration is based on the real value of land allocation plus or minus the small variation terms that we define
E_AreaConst_UpB(hhold,crop_activity_endo,field,y)$( (ord(y) eq 1)  and (PMPswitch = 1) )..
     v_Land_C(hhold,crop_activity_endo,field,y) =L=  v0_Land_C(hhold,crop_activity_endo,field) *( 1 + delta1 )
;
E_AreaConst_LoB(hhold,crop_activity_endo,field,y)$(  (ord(y) eq 1) and (PMPswitch = 1) )..
     v_Land_C(hhold,crop_activity_endo,field,y) =G=  v0_Land_C(hhold,crop_activity_endo,field)*( 1 - delta1 )
;
$endif

**MOTAD version
*E_income_up(WS).. v_deviation(WS)=g= v_npvrd_tot(WS)-v_npv_tot;
*E_income_lo(WS).. v_deviation(WS)=g= v_npv_tot - v_npvrd_tot(WS);
*E_objectif..    v_objectif =e=   v_npv_tot-p_PHI*(1/card(WS)*sum(WS,v_deviation(WS)))
*$ifi %PMPCalib%==on   - sum((hhold,crop_activity_endo,y), (PMPint(hhold,crop_activity_endo)$(PMPswitch = 2) + PMPslope(hhold,crop_activity_endo)$(PMPswitch = 2)*v_Land_C_Agg(hhold,crop_activity_endo,y))*v_Land_C_Agg(hhold,crop_activity_endo,y))$(PMPswitch = 2);
*$endif.inir

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #4 Model definition
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~**


model dahbsim 'dynamic agricultural household model'   /
                 farmMod
                 hholdMod
                 E_UTIL
                 E_NPV
                 E_NPV_TOT
$ifi  %CROP%==on                E_Crop_Number_Def
$ifi  %CROP%==on                 E_Diversity
$ifi %VALUECHAIN%==ON     E_Total_ValueChain_Labor
$ifi %BIOPH%==ON     E_Tot_WaterUse
$ifi %BIOPH%==ON     E_QN
$ifi %VALUECHAIN%==ON     E_ghg_total
** (SiwaPMP) include calibration constraints in model definition
$ifi %CROP%==on $ifi %PMPCalib%==on  E_AreaConst_UpB
$ifi %CROP%==on $ifi %PMPCalib%==on  E_AreaConst_LoB
$ifi %BIOPH%==on E_cost_irr
/

;



*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #5 Solve
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- sliding time horizon
parameter fyear,lyear;
fyear=%FstYear%;
lyear=%LstYear%;

Set
    objSet /GM, WAT, LAB, GHG, DIV, MCDA/;

$onExternalOutput
parameters
           rephh(*,*,*,*) income during simulation 
           repyld(*,*,*,*,*,*,*) yield during simulation years
           repArea(*,*,*,*,*) aggregated crop area by cp and soil type
           r_WstressCoefficient(*,*,*,*,*)
           r_NstressCoefficient(*,*,*,*,*)
           r_SWICoefficient(*,*,*,*,*) 
;
$offExternalOutput

Parameter 
    P_KeyPartners(*,*,*,*),
    P_KeyActivities(*,*,*,*),
    P_KeyResources(*,*),
    P_ValuePropositions(*,*,*),
    P_CustomerRelationships(*,*),
    P_Channels(*,*,*),
    P_CustomerSegments(*,*,*,*),
    P_CostStructure(*,*),
    P_RevenueStreams(*,*)
    P_Water_Indicator(*, y2)
    P_Energy_Indicator(*, y2)
    P_Food_Indicator(*, y2)
    P_Ecosystem_Indicator(*, y2)
    P_CropBuyers(y2,*),
    P_LivestockBuyers(y2,*),
    P_TreeProductionBuyers(y2,*)
;    

Parameter
    p_Diversity(hhold,y2)     'Total number of distinct crops'

parameters
           repcons(*,*,*,*) consumption quantity during simulation
           repfert(*,*,*) Quantity of fertilizer used in simulation
           repself(*,*,*,*) Consumption quantity of self 
           repMpur(*,*,*,*) Quantity of market purchased per product   
           repProd(*,*,*,*) Quantity of production per product 
           repUtil(*,*,*) Net present value of each household

           repcact(*,*,*,*,*,*,*) crop area by act
           
*BIOPHYSICAL DECLARATION due to the loop
           Wstress(*,*,*,*,*,*,*) Water stress define biophmodule
           Nstress(*,*,*,*,*,*,*) Nitrate stress define in biophmodule
           repghg_saved(objSet,y2)
           repGM_saved(objSet,y2)
           repWaterUse_saved(objSet,y2)
           repDiversity_saved(objSet,y2)
           repN_leaching_saved(objSet,y2)
           repLabor_saved(objSet,y2)
           repKSannual(*,*,*,*)
           rep_v_nstress
           rep_v_nfin
           rep_v_nini
           rep_v_fertilizer_annual
           rep_v_nres
           rep_v_nmin
           rep_v_nl
           rep_v_irrigation_opt(*,*,*,*,*) 
           rep_v_DR_start(*,*,*,*,*,*)
           rep_v_DR_end(*,*,*,*,*,*)
           rep_v_KS_avg_annual(*,*,*,*,*)
           rep_Area_AF
           rep_Livestock_Pop
           rep_bluewater
           rep_greenwater
*******WEFENI
           repEnergy(*,*,*,*) ENERGY
           repGHG(*,*,*,*) GHG
           repWater(*,*,*,*) WATER
           repIncome(*,*,*,*)
           repProductivity(*,*,*,*)
;


option rephh :2:3:1;
option repcons :2:3:1;
option repyld :2:6:1;
option repArea :2:4:1;
option repfert :2:2:1;
option repself :2:3:1;
option repMpur :2:3:1;
option repProd :2:3:1;
option repUtil :2:2:1;
************************(SiwaPMP) *************************************************
******** include the module that calculates the necessary PMP parameters ************
*************************************************************************************
$ifi %BIOPH%==on p_test(hhold,crop_activity_endo,field,inten,m,y)=  p_swd0(hhold,crop_activity_endo,field,inten)      - p_rain(y,m)      -irrigation_month(hhold,crop_activity_endo,inten,m)    - CR(hhold,crop_activity_endo,field,inten)    + ET0_month(hhold,crop_activity_endo,field,inten,m,y)     * p_kc(crop_activity_endo,field,inten);
$ifi %BIOPH%==on display p_test;
$ifi %BIOPH%==ON v_irrigation_opt.fx(hhold,crop_activity_endo,field,inten,m,y) =irrigation_month(hhold,crop_activity_endo,inten,m);

*******************************
*****Necessity to fx value for orchard and animals?
**$ifi %LIVESTOCK_simplified%==ON V_animals.fx(hhold,type_animal,age,y)=p_initPopulation(hhold,type_animal,age);
*solve dahbsim using MINLP maximizing v_npv_tot;

*******************************
*****Necessity to calibrate biophysical?
*$ifi %CROP%==on $ifi %BIOPH%==on  $include "BIOPHcalibrationModule.gms"
$ifi %CROP%==on $ifi %PMPCalib%==on  $include "PMPcalibrationModule.gms"
$ifi %CROP%==on $ifi %PMPCalib%==on  display PMPSolnCheck;
***************************************************************************************
$ifi %CROP%==on $ifi %PMPCalib%==on execute_unload "PMPresult/PMPSolnCheck.gdx" PMPSolnCheck;
$iftheni %PMPCalib%==on
EmbeddedCode Connect:
- GAMSReader:
    symbols: [ {name: PMPSolnCheck}]
- ExcelWriter:
    file: Dahbsim_PMP.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: PMPSolnCheck, range: PMPSolnCheck!A1}
endEmbeddedCode
$endIf

********************************************************************************
* ANNUAL MODEL SOLUTION AND RESULTS PROCESSING LOOP
* This loop executes the model for each year and collects all results
********************************************************************************
loop(y2,
solve NITROGEN_OPTIMIZATION using MINLP maximizing TOTAL_NSTRESS_SUM;
p_nav_begin_fixed(hhold,field,inten,crop_activity,y) =    v_nav_begin.l(hhold,field,inten,crop_activity,y);
p_nmin_fixed(hhold,field,y) = v_nmin.l(hhold,field,y);
p_Nres_fixed(hhold,field,y) = v_Nres.l(hhold,field,y);
p_nl_fixed(hhold,crop_activity,field,inten,y) = v_nl.l(hhold,crop_activity,field,inten,y);
p_nfin_fixed(hhold,field,inten,crop_activity,y) = v_nfin.l(hhold,field,inten,crop_activity,y);
p_hini_fixed(hhold,field,y) = v_hini.l(hhold,field,y);
p_hfin_fixed(hhold,field,y) = v_hfin.l(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_activity,y) = v_nav.l(hhold,field,inten,crop_activity,y);
p_nab_fixed(hhold,crop_activity,field,inten,y) = v_nab.l(hhold,crop_activity,field,inten,y);
p_nstress_fixed(hhold,crop_activity,field,inten,y) = v_nstress.l(hhold,crop_activity,field,inten,y);
solve IRRIGATION_OPTIMIZATION using MINLP maximizing TOTAL_KS_SUM;
p_irrigation_opt_fixed(hhold,crop_activity,field,inten,m,y) =     v_irrigation_opt.l(hhold,crop_activity,field,inten,m,y);
p_KS_month_fixed(hhold,crop_activity,field,inten,m,y) =     v_KS_month.l(hhold,crop_activity,field,inten,m,y);
p_DR_start_fixed(hhold,crop_activity,field,inten,m,y) =     v_DR_start.l(hhold,crop_activity,field,inten,m,y);
p_DR_end_fixed(hhold,crop_activity,field,inten,m,y) =     v_DR_end.l(hhold,crop_activity,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,y) =     v_KS_avg_annual.l(hhold,crop_activity,field,inten,y);
p_b_KS_fixed(hhold,crop_activity,field,inten,m,y) =     b_KS.l(hhold,crop_activity,field,inten,m,y);
p_b_DR_negative_fixed(hhold,crop_activity,field,inten,m,y) =    b_DR_negative.l(hhold,crop_activity,field,inten,m,y);

display p_nfin_fixed
p_nstress_fixed
p_DR_start_fixed
p_KS_avg_annual_fixed;


*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using MINLP maximizing v_npv_tot;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = INF;
*****************************************************************************
** SECTION 1: CORE MODEL OUTPUTS
** Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
*repfert(hhold,'Nitr',y2)= V_Nfert_C.l(hhold,'y01');
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.L(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('GM',y2) = sum(hhold, v_GHG.l(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==on rep_greenwater(y2) = sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) ));
$ifi %BIOPH%==on $ifi %CROP%==on rep_bluewater(y2) = sum((hhold,m,crop_activity,field,inten),min(v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)  ) ));

****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"GM","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"GM","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,"GM","water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater(y2)+rep_bluewater(y2)
;
repIncome(hhold,"GM","income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,"GM","productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('GM',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('GM',y2) = SUM((hhold,crop_activity,field,inten,m,y), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('GM',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on repN_leaching_saved('GM',y2) = 0
*$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + V_Nfert_C.l(hhold,'y01'))
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON repLabor_saved('GM',y2) =v_laborSeller_AF.l('y01')+v_laborFeed_seller.l('y01')+v_laborLivestock_seller.l('y01')+v_laborSeller_A.l('y01')+v_laborSeeder.l('y01')+v_laborSellerInput.l('y01')+v_laborBuyerOutput.l('y01');
;
*****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =  SUM((hhold,crop_activity,field,inten,m), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) = 0;
$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) =sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw);

****************************************************************************
* SECTION 5: VALUE CHAIN PARTNERS AND BUSINESS MODEL CANVAS
* Comprehensive value chain analysis following business model canvas framework
****************************************************************************
$iftheni %VALUECHAIN%==on
* 5.1 Key Partners - Input suppliers
$ifi %CROP%==on P_KeyPartners('Crop Input Suppliers', y2, inout, seller_C) = SUM(hhold, v_inputSeller_C.L(hhold,inout,seller_C,'y01'));
$ifi %LIVESTOCK_simplified%==on P_KeyPartners('Feed Suppliers', y2, feedc, Feed_seller) = SUM(hhold, v_Feed_seller.L(hhold,feedc,Feed_seller,'y01'));
$ifi %ORCHARD%==on P_KeyPartners('Tree Production Input Suppliers', y2, inout, seller_AF) = SUM(hhold, v_inputseller_AF.L(hhold,inout,seller_AF,'y01'));
* 5.2 Buyers/Customers
$ifi %CROP%==on P_CropBuyers(y2,buyer) = 1$sum((c_product_endo,hhold), v_outputBuyer.L(hhold,c_product_endo,buyer,'y01'));
$ifi %ORCHARD%==on P_TreeProductionBuyers(y2,buyer) = 1$sum((c_treej,hhold), v_outputBuyer.L(hhold,c_treej,buyer,'y01'));
$ifi %LIVESTOCK_simplified%==on P_LivestockBuyers(y2,buyer) = 1$SUM((ak,hhold), v_outputBuyer.L(hhold,ak,buyer,'y01'));
* 5.3 Key Activities
$ifi %CROP%==on P_KeyActivities('Crop Production (hectare)', y2, field, crop_activity_endo) = SUM((crop_preceding,inten,hhold), V_Plant_C.L(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
$ifi %LIVESTOCK_simplified%==on P_KeyActivities('Livestock Management (head)', y2, type_animal,age) = sum((hhold), V_animals.L(hhold,type_animal,age,'y01') + V_NewPurchased.L(hhold,type_animal,age,'y01'));
$ifi %ORCHARD%==on P_KeyActivities('Tree Production (hectare)', y2, field, c_tree) = SUM((inten,hhold,age_tree), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01'));
* 5.4 Key Resources
$ifi %CROP%==on P_KeyResources('Land Area', y2) = SUM((crop_activity_endo,field,crop_preceding,inten,hhold), V_Plant_C.L(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
$ifi %CROP%==on P_KeyResources('Family Labor (Crops)', y2) = sum((hhold,m), V_FamLabor_C.L(hhold,'y01',m));
$ifi %CROP%==on P_KeyResources('Hired Labor (Crops)', y2) = sum((hhold,m), V_HLabor_C.L(hhold,'y01',m));
$ifi %LIVESTOCK_simplified%==on P_KeyResources('Family Labor (Livestock)', y2) = sum((hhold,m), V_FamLabor_A.L(hhold,m,'y01'));
$ifi %LIVESTOCK_simplified%==on P_KeyResources('Hired Labor (Livestock)', y2) = sum((hhold,m), V_HLabor_A.L(hhold,m,'y01'));
$ifi %ORCHARD%==on P_KeyResources('Family Labor (Tree Production)', y2) = sum((hhold,m), V_FamLabor_AF.L(hhold,'y01',m));
$ifi %ORCHARD%==on P_KeyResources('Hired Labor (Tree Production)', y2) = sum((hhold,m), V_HLabor_AF.L(hhold,'y01',m));
* 5.5 Value Propositions - Economic
$ifi %CROP%==on P_ValuePropositions('Economic','Maximized Gross Margin (Crops)', y2) = sum(hhold, V_annualGM_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_ValuePropositions('Economic', 'Maximized Operating Profit (Livestock)', y2) = sum(hhold, V_annualGM_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_ValuePropositions('Economic', 'Maximized Operating Profit (Tree Production)', y2) = sum(hhold, V_annualGM_AF.L(hhold,'y01'));
$endIf
* End of VALUECHAIN conditional
* 5.6 Value Propositions - Societal (Job Creation)
$iftheni %VALUECHAIN%==on P_ValuePropositions('Societal', 'Maximized Job Creation', y2) = 0
$ifi %LIVESTOCK_simplified%==on    + sum((hhold,m), V_FamLabor_A.L(hhold,m,'y01') + V_HLabor_A.L(hhold,m,'y01')) 
$ifi %CROP%==on     + sum((hhold,m), V_FamLabor_C.L(hhold,'y01',m) + V_HLabor_C.L(hhold,'y01',m)) 
$ifi %ORCHARD%==on    + sum((hhold,m), V_FamLabor_AF.L(hhold,'y01',m) + V_HLabor_AF.L(hhold,'y01',m)) + v_laborBuyerOutput.L('y01') 
$ifi %CROP%==on       + v_laborSellerInput.L('y01') + v_laborSeeder.L('y01') 
$ifi %LIVESTOCK_simplified%==on + v_laborSeller_A.L('y01') + v_laborLivestock_seller.L('y01') + v_laborFeed_seller.L('y01')
;
$endIf
* 5.7 Value Propositions - Environmental



$ifi %BIOPH%==on $ifi %CROP%==on P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =             SUM((hhold,crop_activity,field,inten,m), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
$ifi %CROP%==on          P_ValuePropositions('Environmental', 'Maximized Biodiversity', y2) = sum(hhold, p_Diversity(hhold,y2));
* 5.8 Customer Relationships and GHG Emissions
$iftheni %VALUECHAIN%==on
$ifi %CROP%==on P_CustomerRelationships('Number of Crop Customers', y2) = SUM(buyer, P_CropBuyers(y2,buyer));
$ifi %LIVESTOCK_simplified%==on  P_CustomerRelationships('Number of Livestock Customers', y2) = SUM(buyer, P_LivestockBuyers(y2,buyer));
$ifi %ORCHARD%==on P_CustomerRelationships('Number of Tree Production Customers', y2) = SUM(buyer, P_TreeProductionBuyers(y2,buyer));
* GHG Emissions by sector
P_ValuePropositions('Environmental', 'Minimized GHG Emission', y2) = sum(hhold, v_GHG.L(hhold,'y01'));
$ifi %CROP%==on P_Energy_Indicator("Crop", y2) = sum(hhold, v_GHG_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on  P_Energy_Indicator("Livestock", y2) = sum(hhold, v_GHG_livestock.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Energy_Indicator("Tree", y2) = sum(hhold, v_GHG_AF.L(hhold,'y01'));

* 5.9 Channels and Customer Segments
$ifi %CROP%==on P_Channels('Direct Sales (Crops)', y2, buyer) = P_CropBuyers(y2,buyer);    
$ifi %LIVESTOCK_simplified%==on P_Channels('Direct Sales (Livestock)', y2, buyer) = P_LivestockBuyers(y2,buyer);
$ifi %ORCHARD%==on P_Channels('Direct Sales (Tree Production)', y2, buyer) = P_TreeProductionBuyers(y2,buyer);
$ifi %CROP%==on P_CustomerSegments('Crop Product Buyers', y2, c_product_endo, buyer) =                 sum(hhold, v_outputBuyer.L(hhold,c_product_endo,buyer,'y01'));
$ifi %LIVESTOCK_simplified%==on P_CustomerSegments('Livestock Product Buyers', y2, ak, buyer) = SUM(hhold, v_outputBuyer.L(hhold,ak,buyer,'y01'));
$ifi %ORCHARD%==on P_CustomerSegments('Tree Product Buyers', y2, c_treej, buyer) = sum(hhold, v_outputBuyer.L(hhold,c_treej,buyer,'y01'));
$endIf

* 5.10 Cost Structure
$ifi %CROP%==on P_CostStructure('Variable Costs (Crops)', y2) = sum(hhold, V_VarCost_C.L(hhold,'y01'));
$ifi %CROP%==on P_CostStructure('Labor Costs (Crops)', y2) = sum(hhold, sum(m, V_HLabor_C.L(hhold,'y01',m)) * p_buyPrice(hhold,'labor'));
$ifi %CROP%==on $ifi %VALUECHAIN%==ON    P_CostStructure('Transportation Costs (Crops)', y2) = sum(hhold, v_transportCost_crop.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on   P_CostStructure('Variable Costs (Livestock)', y2) = sum(hhold, V_VarCost_A.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on   P_CostStructure('Labor Costs (Livestock)', y2) = sum(hhold, sum(m, V_HLabor_A.L(hhold,m,'y01')) * p_buyPrice(hhold,'labor'));
$ifi %LIVESTOCK_simplified%==on $ifi %VALUECHAIN%==ON     P_CostStructure('Transportation Costs (Livestock)', y2) = sum(hhold, V_TransportCost_A.L(hhold,'y01'));
$ifi %ORCHARD%==on         P_CostStructure('Variable Costs (Tree Production)', y2) = sum(hhold, V_VarCost_AF.L(hhold,'y01'));
$ifi %ORCHARD%==on        P_CostStructure('Labor Costs (Tree Production)', y2) = sum(hhold, sum(m, V_HLabor_AF.L(hhold,'y01',m)) * p_buyPrice(hhold,'labor'));
$ifi %ORCHARD%==on $ifi %VALUECHAIN%==ON P_CostStructure('Transportation Costs (Tree Production)', y2) = sum(hhold, v_transportCost_orchard.L(hhold,'y01'));
* 5.11 Revenue Streams
$ifi %CROP%==on P_RevenueStreams('Revenue from Crop Production', y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_RevenueStreams('Revenue from Livestock Production', y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_RevenueStreams('Revenue from Tree Production', y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));

****************************************************************************
* SECTION 6: BIOPHYSICAL PROCESS DETAILS
* Detailed soil, water, and nutrient dynamics
****************************************************************************
$iftheni %BIOPH%==on
$ifi %CROP%==on rep_v_nstress(hhold,crop_activity,field,inten,y2)          = v_nstress.l(hhold,crop_activity,field,inten,'y01');
rep_v_nfin(hhold,field,y2) = sum((inten,crop_activity_endo),        
p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));;
rep_v_nres(hhold,field,y2) = p_Nres_fixed(hhold,field,'y01');
rep_v_nmin(hhold,field,y2) = p_nmin_fixed(hhold,field,'y01');
rep_v_nl(hhold,field,y2) = sum((crop_activity,inten),p_nl_fixed(hhold,crop_activity,field,inten,'y01') );
rep_v_irrigation_opt(hhold,crop_activity,field,inten,y2)   = sum(m, p_irrigation_opt_fixed(hhold,crop_activity,field,inten,m,'y01')) / 12;
rep_v_DR_start(hhold,crop_activity,field,inten,m,y2)       = p_DR_start_fixed(hhold,crop_activity,field,inten,m,'y01');       
rep_v_DR_end(hhold,crop_activity,field,inten,m,y2)         = p_DR_end_fixed(hhold,crop_activity,field,inten,m,'y01');
rep_v_KS_avg_annual(hhold,crop_activity,field,inten,y2)    = p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01');
$endIf
****************************************************************************
* YEAR RESET AND PREPARATION FOR NEXT ITERATION
****************************************************************************
$include "reset_iniyear.gms" 
);
*
*












*
********************************************************************************
** ANNUAL MODEL SOLUTION AND RESULTS PROCESSING LOOP
** This loop executes the model for each year and collects all results
*********
*******FINITO
$iftheni %BIOPH%==on
embeddedCode Connect:
- GAMSReader:
    symbols: [ {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]
- ExcelWriter:
    file: BiophDahbsim.xlsx
    valueSubstitutions: {EPS: 0}
    symbols:
      - {name: rep_v_irrigation_opt,range: rep_v_irrigation_opt!A1}
      - {name: rep_v_DR_start,range: rep_v_DR_start!A1}
      - {name: rep_v_DR_end,range: rep_v_DR_end!A1}
      - {name: rep_v_KS_avg_annual,range: rep_v_KS_avg_annual!A1}
      - {name: rep_v_nstress,range: rep_v_nstress!A1}
      - {name: rep_v_nfin,range: rep_v_nfin!A1}
      - {name: rep_v_nmin,range: rep_v_nmin!A1}
      - {name: rep_v_nl,range: rep_v_nl!A1}
      - {name: rep_v_nres,range: rep_v_nres!A1}
endEmbeddedCode
$endIf
**
*
*
****
****
*$iftheni %DIONYSUS%==on
*********************************************INITIALIZATION************************************************
*********************************************************************************************
*$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
*$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
*v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
*v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
*V0_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
*V0_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
*V0_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
*v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
*v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
*$ifi %BIOPH%==ON v_irrigation_opt.fx(hhold,crop_activity_endo,field,inten,m,y)=irrigation_month(hhold,crop_activity_endo,inten,m);
**********************************************DIVERSITY***********************************************
*********************************************************************************************
**
*loop(y2,
***** Unfix variables only after the first year due to calibration
***** This allows the model to adjust irrigation decisions in subsequent years
*solve dahbsim using MINLP maximizing V_Diversity;
*** Free up irrigation decision variables after year 1 (calibration period)
*)
*   
*$ifi %BIOPH%==ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
*$ifi %BIOPH%==ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = INF;
*
*****************************************************************************
** SECTION 1: CORE MODEL OUTPUTS
** Basic household-level economic and consumption results
*****************************************************************************
*rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
*repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
*$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
*$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
*$iftheni %CROP%==on
*repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
*repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
*repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
*repfert(hhold,'Nitr',y2)= V_Nfert_C.l(hhold,'y01');
*$endIf
*repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
*repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
*repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
*repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
*$ifi %VALUECHAIN%==ON repghg_saved('DIV',y2) = sum(hhold, v_GHG.l(hhold,'y01'));
*$ifi %BIOPH%==on $ifi %CROP%==on rep_greenwater(y2) = sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) ));
*$ifi %BIOPH%==on $ifi %CROP%==on rep_bluewater(y2) = sum((hhold,m,crop_activity,field,inten),min(v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)  ) ));
*****************************************************************************
** SECTION 2: WEFENI INDICATORS
** Water-Energy-Food-Environment Nexus Indicators
*****************************************************************************
*$ifi %VALUECHAIN%==ON     repEnergy(hhold,"DIV","energy",y2) = V_energy.l(hhold,'y01');
*$ifi %VALUECHAIN%==ON     repGHG(hhold,"DIV","ghg",y2)       = v_GHG.l(hhold,'y01');
*repWater(hhold,"DIV","water",y2)   = 0
*$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater(y2)+rep_bluewater(y2)
*;
*
*
*
*
*repIncome(hhold,"DIV","income",y2)          = v_fullIncome.l(hhold,'y01');
*repProductivity(hhold,"DIV","productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
*****************************************************************************
** SECTION 3: MCDA DATA PREPARATION
** Multi-Criteria Decision Analysis indicators
*****************************************************************************
*repGM_saved('DIV',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
*    
*$ifi %BIOPH%==on repWaterUse_saved('DIV',y2) = SUM((hhold,crop_activity,field,inten,m,y), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
*    
*$ifi %VALUECHAIN%==ON     repDiversity_saved('DIV',y2) = V_diversity.l;
** Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
*$ifi %BIOPH%==on
*repN_leaching_saved('DIV',y2) = 0
*$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + V_Nfert_C.l(hhold,'y01'))
*$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
*;
*$ifi %VALUECHAIN%==ON     repLabor_saved('DIV',y2) =v_laborSeller_AF.l('y01')+v_laborFeed_seller.l('y01')+v_laborLivestock_seller.l('y01')+v_laborSeller_A.l('y01')+v_laborSeeder.l('y01')+v_laborSellerInput.l('y01')+v_laborBuyerOutput.l('y01');
*****************************************************************************
** SECTION 4: SECTOR-SPECIFIC INDICATORS
** Biodiversity, water use, food production, and ecosystem indicators
*****************************************************************************
** Count number of crops grown (biodiversity indicator)
*p_Diversity(hhold,y2) = 0
*$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
*;
*$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =  SUM((hhold,crop_activity,field,inten,m), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
*$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) = 0;
*$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
*$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
*$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
** sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
*$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
*$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) =sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw);
*;
*
*****************************************************************************
** SECTION 5: VALUE CHAIN PARTNERS AND BUSINESS MODEL CANVAS
** Comprehensive value chain analysis following business model canvas framework
*****************************************************************************
*$iftheni %VALUECHAIN%==on
** 5.1 Key Partners - Input suppliers
*$ifi %CROP%==on P_KeyPartners('Crop Input Suppliers', y2, inout, seller_C) = SUM(hhold, v_inputSeller_C.L(hhold,inout,seller_C,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_KeyPartners('Feed Suppliers', y2, feedc, Feed_seller) = SUM(hhold, v_Feed_seller.L(hhold,feedc,Feed_seller,'y01'));
*$ifi %ORCHARD%==on P_KeyPartners('Tree Production Input Suppliers', y2, inout, seller_AF) = SUM(hhold, v_inputseller_AF.L(hhold,inout,seller_AF,'y01'));
** 5.2 Buyers/Customers
*$ifi %CROP%==on P_CropBuyers(y2,buyer) = 1$sum((c_product_endo,hhold), v_outputBuyer.L(hhold,c_product_endo,buyer,'y01'));
*$ifi %ORCHARD%==on P_TreeProductionBuyers(y2,buyer) = 1$sum((c_treej,hhold), v_outputBuyer.L(hhold,c_treej,buyer,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_LivestockBuyers(y2,buyer) = 1$SUM((ak,hhold), v_outputBuyer.L(hhold,ak,buyer,'y01'));
** 5.3 Key Activities
*$ifi %CROP%==on P_KeyActivities('Crop Production (hectare)', y2, field, crop_activity_endo) = SUM((crop_preceding,inten,hhold), V_Plant_C.L(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_KeyActivities('Livestock Management (head)', y2, type_animal,age) = sum((hhold), V_animals.L(hhold,type_animal,age,'y01') + V_NewPurchased.L(hhold,type_animal,age,'y01'));
*$ifi %ORCHARD%==on P_KeyActivities('Tree Production (hectare)', y2, field, c_tree) = SUM((inten,hhold,age_tree), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01'));
** 5.4 Key Resources
*$ifi %CROP%==on P_KeyResources('Land Area', y2) = SUM((crop_activity_endo,field,crop_preceding,inten,hhold), V_Plant_C.L(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
*$ifi %CROP%==on P_KeyResources('Family Labor (Crops)', y2) = sum((hhold,m), V_FamLabor_C.L(hhold,'y01',m));
*$ifi %CROP%==on P_KeyResources('Hired Labor (Crops)', y2) = sum((hhold,m), V_HLabor_C.L(hhold,'y01',m));
*$ifi %LIVESTOCK_simplified%==on P_KeyResources('Family Labor (Livestock)', y2) = sum((hhold,m), V_FamLabor_A.L(hhold,m,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_KeyResources('Hired Labor (Livestock)', y2) = sum((hhold,m), V_HLabor_A.L(hhold,m,'y01'));
*$ifi %ORCHARD%==on P_KeyResources('Family Labor (Tree Production)', y2) = sum((hhold,m), V_FamLabor_AF.L(hhold,'y01',m));
*$ifi %ORCHARD%==on P_KeyResources('Hired Labor (Tree Production)', y2) = sum((hhold,m), V_HLabor_AF.L(hhold,'y01',m));
** 5.5 Value Propositions - Economic
*$ifi %CROP%==on P_ValuePropositions('Economic','Maximized Gross Margin (Crops)', y2) = sum(hhold, V_annualGM_C.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_ValuePropositions('Economic', 'Maximized Operating Profit (Livestock)', y2) = sum(hhold, V_annualGM_A.L(hhold,'y01'));
*$ifi %ORCHARD%==on P_ValuePropositions('Economic', 'Maximized Operating Profit (Tree Production)', y2) = sum(hhold, V_annualGM_AF.L(hhold,'y01'));
*$endIf
** End of VALUECHAIN conditional
** 5.6 Value Propositions - Societal (Job Creation)
*$iftheni %VALUECHAIN%==on P_ValuePropositions('Societal', 'Maximized Job Creation', y2) = 0
*$ifi %LIVESTOCK_simplified%==on    + sum((hhold,m), V_FamLabor_A.L(hhold,m,'y01') + V_HLabor_A.L(hhold,m,'y01')) 
*$ifi %CROP%==on     + sum((hhold,m), V_FamLabor_C.L(hhold,'y01',m) + V_HLabor_C.L(hhold,'y01',m)) 
*$ifi %ORCHARD%==on    + sum((hhold,m), V_FamLabor_AF.L(hhold,'y01',m) + V_HLabor_AF.L(hhold,'y01',m)) + v_laborBuyerOutput.L('y01') 
*$ifi %CROP%==on       + v_laborSellerInput.L('y01') + v_laborSeeder.L('y01') 
*$ifi %LIVESTOCK_simplified%==on + v_laborSeller_A.L('y01') + v_laborLivestock_seller.L('y01') + v_laborFeed_seller.L('y01')
*;
*$endIf
** 5.7 Value Propositions - Environmental
*$ifi %BIOPH%==on $ifi %CROP%==on          P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =             SUM((hhold,crop_activity,field,inten,m), v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01'));
*$ifi %CROP%==on          P_ValuePropositions('Environmental', 'Maximized Biodiversity', y2) = sum(hhold, p_Diversity(hhold,y2));
** 5.8 Customer Relationships and GHG Emissions
*$iftheni %VALUECHAIN%==on
*$ifi %CROP%==on P_CustomerRelationships('Number of Crop Customers', y2) = SUM(buyer, P_CropBuyers(y2,buyer));
*$ifi %LIVESTOCK_simplified%==on  P_CustomerRelationships('Number of Livestock Customers', y2) = SUM(buyer, P_LivestockBuyers(y2,buyer));
*$ifi %ORCHARD%==on P_CustomerRelationships('Number of Tree Production Customers', y2) = SUM(buyer, P_TreeProductionBuyers(y2,buyer));
** GHG Emissions by sector
*P_ValuePropositions('Environmental', 'Minimized GHG Emission', y2) = sum(hhold, v_GHG.L(hhold,'y01'));
*$ifi %CROP%==on P_Energy_Indicator("Crop", y2) = sum(hhold, v_GHG_C.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on  P_Energy_Indicator("Livestock", y2) = sum(hhold, v_GHG_livestock.L(hhold,'y01'));
*$ifi %ORCHARD%==on P_Energy_Indicator("Tree", y2) = sum(hhold, v_GHG_AF.L(hhold,'y01'));
*
** 5.9 Channels and Customer Segments
*$ifi %CROP%==on P_Channels('Direct Sales (Crops)', y2, buyer) = P_CropBuyers(y2,buyer);    
*$ifi %LIVESTOCK_simplified%==on P_Channels('Direct Sales (Livestock)', y2, buyer) = P_LivestockBuyers(y2,buyer);
*$ifi %ORCHARD%==on P_Channels('Direct Sales (Tree Production)', y2, buyer) = P_TreeProductionBuyers(y2,buyer);
*$ifi %CROP%==on P_CustomerSegments('Crop Product Buyers', y2, c_product_endo, buyer) =                 sum(hhold, v_outputBuyer.L(hhold,c_product_endo,buyer,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_CustomerSegments('Livestock Product Buyers', y2, ak, buyer) = SUM(hhold, v_outputBuyer.L(hhold,ak,buyer,'y01'));
*$ifi %ORCHARD%==on P_CustomerSegments('Tree Product Buyers', y2, c_treej, buyer) = sum(hhold, v_outputBuyer.L(hhold,c_treej,buyer,'y01'));
*$endIf
*
** 5.10 Cost Structure
*$ifi %CROP%==on P_CostStructure('Variable Costs (Crops)', y2) = sum(hhold, V_VarCost_C.L(hhold,'y01'));
*$ifi %CROP%==on P_CostStructure('Labor Costs (Crops)', y2) = sum(hhold, sum(m, V_HLabor_C.L(hhold,'y01',m)) * p_buyPrice(hhold,'labor'));
*$ifi %CROP%==on $ifi %VALUECHAIN%==ON    P_CostStructure('Transportation Costs (Crops)', y2) = sum(hhold, v_transportCost_crop.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on   P_CostStructure('Variable Costs (Livestock)', y2) = sum(hhold, V_VarCost_A.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on   P_CostStructure('Labor Costs (Livestock)', y2) = sum(hhold, sum(m, V_HLabor_A.L(hhold,m,'y01')) * p_buyPrice(hhold,'labor'));
*$ifi %LIVESTOCK_simplified%==on $ifi %VALUECHAIN%==ON     P_CostStructure('Transportation Costs (Livestock)', y2) = sum(hhold, V_TransportCost_A.L(hhold,'y01'));
*$ifi %ORCHARD%==on         P_CostStructure('Variable Costs (Tree Production)', y2) = sum(hhold, V_VarCost_AF.L(hhold,'y01'));
*$ifi %ORCHARD%==on        P_CostStructure('Labor Costs (Tree Production)', y2) = sum(hhold, sum(m, V_HLabor_AF.L(hhold,'y01',m)) * p_buyPrice(hhold,'labor'));
*$ifi %ORCHARD%==on $ifi %VALUECHAIN%==ON P_CostStructure('Transportation Costs (Tree Production)', y2) = sum(hhold, v_transportCost_orchard.L(hhold,'y01'));
** 5.11 Revenue Streams
*$ifi %CROP%==on P_RevenueStreams('Revenue from Crop Production', y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
*$ifi %LIVESTOCK_simplified%==on P_RevenueStreams('Revenue from Livestock Production', y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
*$ifi %ORCHARD%==on P_RevenueStreams('Revenue from Tree Production', y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
*
*****************************************************************************
** SECTION 6: BIOPHYSICAL PROCESS DETAILS
** Detailed soil, water, and nutrient dynamics
*****************************************************************************
*$iftheni %BIOPH%==on
*$ifi %CROP%==on rep_v_nstress(hhold,crop_activity,field,inten,y2)          = v_nstress.l(hhold,crop_activity,field,inten,'y01');
*rep_v_nfin(hhold,field,y2) = v_nfin.l(hhold,field,'y01');
*rep_v_fertilizer_annual(hhold,crop_activity,field,inten,y2)= v_fertilizer_annual.l(hhold,crop_activity,field,inten,'y01');
*rep_v_nres(hhold,field,y2) = v_Nres.l(hhold,field,'y01');
*rep_v_nmin(hhold,field,y2) = v_nmin.l(hhold,field,'y01');
*rep_v_nl(hhold,field,y2) = sum((crop_activity,inten),v_nl.l(hhold,crop_activity,field,inten,'y01'));
*rep_v_irrigation_opt(hhold,crop_activity,field,inten,y2)   = sum(m, v_irrigation_opt.l(hhold,crop_activity,field,inten,m,'y01')) / 12;
*rep_v_DR_start(hhold,crop_activity,field,inten,m,y2)       = v_DR_start.l(hhold,crop_activity,field,inten,m,'y01');       
*rep_v_DR_end(hhold,crop_activity,field,inten,m,y2)         = v_DR_end.l(hhold,crop_activity,field,inten,m,'y01');
*rep_v_KS_avg_annual(hhold,crop_activity,field,inten,y2)    = v_KS_avg_annual.l(hhold,crop_activity,field,inten,'y01');
*$endIf
****************************************************************************
* YEAR RESET AND PREPARATION FOR NEXT ITERATION
****************************************************************************
*$include "reset_iniyear.gms"
*);
* End of annual loop y2


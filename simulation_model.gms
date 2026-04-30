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
* ============================================================================
* DYNAMIC AGRICULTURAL HOUSEHOLD BIO-PHYSICAL MODEL
* ============================================================================
* This section handles bio-physical constraints related to water use and
* nitrogen application, including irrigation costs and water quality indicators
* ============================================================================

$iftheni %BIOPH% == on

* ----------------------------------------------------------------------------
* VARIABLE DECLARATIONS
* ----------------------------------------------------------------------------
Variables
    V_Tot_WaterUse      "Total water consumption across all activities"
    V_QN                "Nitrogen balance indicator (surplus/deficit)"
;

* ----------------------------------------------------------------------------
* EQUATION DECLARATIONS
* ----------------------------------------------------------------------------
Equations
    E_cost_irr_crop     "Irrigation cost calculation for crop activities"
    E_cost_irr_tree     "Irrigation cost calculation for orchard/tree activities"
    E_Tot_WaterUse      "Total water use accounting"
    E_QN                "Nitrogen balance equation"
;

* ----------------------------------------------------------------------------
* IRRIGATION COST EQUATIONS
* ----------------------------------------------------------------------------

* Crop irrigation cost equation
* Calculates total irrigation costs for crop production, accounting for:
* - Fixed irrigation requirements per activity
* - Crop planting area
* - Household-specific irrigation costs
E_cost_irr_crop(hhold, y)..
    v_costirr_crop(hhold, y) =e= 0
$ifi %CROP% == on + (
    SUM((crop_activity, field, inten, m),
        p_irrigation_opt_fixed(hhold, crop_activity, field, inten, m, y) *
        SUM(crop_preceding, V_Plant_C(hhold, crop_activity, crop_preceding, field, inten, y)) *
        p_cost_irrigation(hhold)
    ) / p_pricescalar
);

* Orchard/Tree irrigation cost equation
* Similar to crop irrigation but adapted for perennial tree crops
* Accounts for tree age classes and area under each age category
E_cost_irr_tree(hhold, y)..
    v_costirr_tree(hhold, y) =e= 0
$ifi %ORCHARD% == on + (    SUM((c_tree, field, inten, m),        p_irrigation_opt_fixed(hhold, c_tree, field, inten, m, y) *        SUM(age_tree, V_Area_AF(hhold, field, c_tree, age_tree, inten, y)) *        p_cost_irrigation(hhold)    ) / p_pricescalar)
;

* ----------------------------------------------------------------------------
* NITROGEN BALANCE EQUATION
* ----------------------------------------------------------------------------
* Calculates total nitrogen application across all activities
* Note: Original commented code shows alternative formulations using production
*       quantities, but current implementation uses direct nitrogen application
E_QN ..
    V_QN =e= 0
$ifi %CROP% == on + SUM((hhold, crop_activity, field, inten, y),     (p_Nl_raw * SUM(NameNitr, V_Use_Input_C(hhold, crop_activity, NameNitr, y))))
$ifi %ORCHARD% == on + SUM((c_treej, hhold, y),     (p_Nl_raw * SUM(c_tree, V_Nfert_AF(hhold, c_tree, y))))
;

* ----------------------------------------------------------------------------
* TOTAL WATER USE EQUATION
* ----------------------------------------------------------------------------
* Sums irrigation water applied to both annual crops and perennial tree crops
* Original commented code used a productivity-based formulation (production/irrigation)
* Current implementation directly sums irrigation applications
E_Tot_WaterUse ..
    V_Tot_WaterUse =e= 0
$ifi %CROP% == on +SUM((hhold, crop_activity, field, inten, m, y),    p_irrigation_opt_fixed(hhold, crop_activity, field, inten, m, y) *    SUM(crop_preceding, V_Plant_C(hhold, crop_activity, crop_preceding, field, inten, y))
)
$ifi %ORCHARD% == on + SUM((hhold, c_tree, field, inten, m, y),    p_irrigation_opt_fixed(hhold, c_tree, field, inten, m, y) *    SUM(age_tree, V_Area_AF(hhold, field, c_tree, age_tree, inten, y)))
;

$endif

* ============================================================================
* MODEL PARAMETERS
* ============================================================================
* Calculate discount factor rho for each year based on discount rate (dr)
* rho(y) = 1 / (1 + dr)^(t-1) where t is the year position
rho(y) = 1 / ((1 + dr) ** (y.pos - 1));

* ============================================================================
* MODEL VARIABLES
* ============================================================================
Variables
    v_npv_tot           "Regional net present value (aggregate across households)"
    v_npv               "Household-level net present value"
    v_util              "Household utility"
    v_objectif          "Objective function value (for MOTAD models)"
    V_Diversity         "Crop and tree diversity index"
;

* ----------------------------------------------------------------------------
* BINARY VARIABLES
* ----------------------------------------------------------------------------
* Used to count distinct crop/tree types for diversity measurement
Binary Variables
    V_Crop_Number(y, hhold, crop_activity)   "Indicator: crop activity used"
    V_Tree_Number(y, hhold, c_tree)          "Indicator: tree type present"
;

* ============================================================================
* MODEL EQUATIONS
* ============================================================================
Equations
    E_UTIL              "Utility function - links utility to farm income"
    E_NPV               "Net present value calculation"
    E_NPV_TOT_PMP       "Net present value with PMP calibration terms"
    E_NPV_TOT           "Standard net present value (normative PMP)"
    
* PMP Calibration Constraints (Stage 1)
    E_AreaConst_UpB     "Upper bound on crop area for PMP calibration"
    E_AreaConst_LoB     "Lower bound on crop area for PMP calibration"
    
    E_income_up         "Upper deviation for MOTAD risk specification"
    E_income_lo         "Lower deviation for MOTAD risk specification"
    
* Diversity-related equations
    E_Crop_Number_Def   "Crop count definition for diversity index"
    E_Crop_Number_Lower "Minimum amount of number"
    E_Tree_Number_Def   "Tree count definition for diversity index"
    E_Tree_Number_Lower
    E_Diversity         "Diversity index aggregation"
    E_AreaConst         "Land area constraint (placeholder)"
;

* ----------------------------------------------------------------------------
* DIVERSITY CONSTRAINTS
* ----------------------------------------------------------------------------

$iftheni %CROP% == on
* Crop diversity definition


E_Crop_Number_Lower(hhold, crop_activity, y)..
    SUM(field, v_Land_C(hhold, crop_activity, field, y)) =g= 
    0.01 * V_Crop_Number(y, hhold, crop_activity)/card(y);


* Ensures that if area > 0, the binary indicator is set to 1
* The multiplier 100 is a scaling factor (smallest area unit is 0.01 ha)
E_Crop_Number_Def(hhold, crop_activity, y)..
    SUM(field, v_Land_C(hhold, crop_activity, field, y)) =l= 
    V_Crop_Number(y, hhold, crop_activity)*100;
$endif

$iftheni %ORCHARD% == on
* Tree diversity definition

E_Tree_Number_Lower(hhold, c_tree, y)..
    SUM((field, age_tree, inten), 
        V_Area_AF(hhold, field, c_tree, age_tree, inten, y)) =g= 
    0.01 * V_Tree_Number(y, hhold, c_tree);

* Similar logic for perennial tree crops across age classes and intensities
E_Tree_Number_Def(hhold, c_tree, y)..
    SUM((field, age_tree, inten), 
        V_Area_AF(hhold, field, c_tree, age_tree, inten, y)) =l= 
    V_Tree_Number(y, hhold, c_tree)*100;
$endif

* Diversity index aggregation
* Sums all binary indicators to create a count of distinct crop/tree types
* Higher values indicate greater on-farm biodiversity
E_Diversity..
    V_Diversity =e= 0
$ifi %CROP% == on + SUM((y, hhold, crop_activity), V_Crop_Number(y, hhold, crop_activity)/card(y))
$ifi %ORCHARD% == on + SUM((y, hhold, c_tree), V_Tree_Number(y, hhold, c_tree)/card(y))
;

* ============================================================================
* UTILITY AND NET PRESENT VALUE DEFINITIONS
* ============================================================================

* ----------------------------------------------------------------------------
* UTILITY FUNCTION
* ----------------------------------------------------------------------------
* Household utility is equated to full income (including on-farm consumption
* and market transactions). The commented CONS section was removed to avoid
* double-counting as these are already captured in full income.
E_UTIL(hhold, y)..
    v_util(hhold, y) =e= v_fullIncome(hhold, y);

* ----------------------------------------------------------------------------
* NET PRESENT VALUE
* ----------------------------------------------------------------------------
* Discounted sum of utility over the planning horizon
* Note: Final value (farm liquidation) is not included but could be added
E_NPV(hhold)..
    v_npv(hhold) =e= SUM(y, rho(y) * v_util(hhold, y));

* ----------------------------------------------------------------------------
* PMP CALIBRATION OBJECTIVES
* ----------------------------------------------------------------------------
* PMP (Positive Mathematical Programming) calibration objective
* Includes quadratic penalty terms when PMPswitch = 2
* The terms PMPint and PMPslope are calibration parameters derived from Stage 1
E_NPV_TOT_PMP..
    v_npv_tot =e= 
    SUM(hhold, v_npv(hhold))
$ifi %CROP% == on $ifi %PMPCalib% == on - SUM((hhold, crop_activity_endo, y),
    (PMPint(hhold, crop_activity_endo) $ (PMPswitch = 2) + 
     PMPslope(hhold, crop_activity_endo) $ (PMPswitch = 2) * 
     v_Land_C_Agg(hhold, crop_activity_endo, y)) * 
    v_Land_C_Agg(hhold, crop_activity_endo, y)
) $ (PMPswitch = 2);

* Standard NPV objective (without PMP adjustment)
E_NPV_TOT..
    v_npv_tot =e= SUM(hhold, v_npv(hhold));

* ----------------------------------------------------------------------------
* PMP CALIBRATION CONSTRAINTS (STAGE 1)
* ----------------------------------------------------------------------------
* These constraints are active only in the first stage (PMPswitch = 1)
* They bound crop area within delta1% of observed base-year values (v0_Land_C)
* delta1 is a small perturbation parameter (typically 0.01-0.05)

$iftheni %CROP% == on

E_AreaConst_UpB(hhold, crop_activity_endo, y) $
    (SUM(field, v0_Land_C(hhold, crop_activity_endo, field)) AND 
     ord(y) EQ 1 AND (PMPswitch = 1))..
    v_Land_C_Agg(hhold, crop_activity_endo, y) =l= 
    SUM(field, v0_Land_C(hhold, crop_activity_endo, field)) * (1 + delta1);

E_AreaConst_LoB(hhold, crop_activity_endo, y) $
    (SUM(field, v0_Land_C(hhold, crop_activity_endo, field)) AND 
     ord(y) EQ 1 AND (PMPswitch = 1))..
    v_Land_C_Agg(hhold, crop_activity_endo, y) =g= 
    SUM(field, v0_Land_C(hhold, crop_activity_endo, field)) * (1 - delta1);

$endif

* ============================================================================
* MOTAD RISK MODEL (Commented - preserved for future use)
* ============================================================================
* The MOTAD (Minimization of Total Absolute Deviation) approach captures
* farm income risk across weather states (WS)
* 
* E_income_up(WS).. v_deviation(WS) =g= v_npvrd_tot(WS) - v_npv_tot;
* E_income_lo(WS).. v_deviation(WS) =g= v_npv_tot - v_npvrd_tot(WS);
* 
* E_objectif.. v_objectif =e= v_npv_tot - p_PHI * (1/card(WS) * SUM(WS, v_deviation(WS)))
* $ifi %PMPCalib% == on - SUM((hhold, crop_activity_endo, y),
*     (PMPint(hhold, crop_activity_endo) $ (PMPswitch = 2) + 
*      PMPslope(hhold, crop_activity_endo) $ (PMPswitch = 2) * 
*      v_Land_C_Agg(hhold, crop_activity_endo, y)) * 
*     v_Land_C_Agg(hhold, crop_activity_endo, y)) $ (PMPswitch = 2);

* ============================================================================
* MODEL DEFINITIONS
* ============================================================================

* ----------------------------------------------------------------------------
* BASE MODEL (standard optimization)
* ----------------------------------------------------------------------------
Model dahbsim 'dynamic agricultural household model' /
    farmMod
    hholdMod
    E_UTIL
    E_NPV
    E_NPV_TOT
$ifi %ORCHARD% == on     E_Tree_Number_Def
$ifi %ORCHARD% == on     E_Tree_Number_Lower
$ifi %CROP% == on        E_Crop_Number_Def
$ifi %CROP% == on        E_Crop_Number_Lower
    E_Diversity
$ifi %VALUECHAIN% == on  E_Total_ValueChain_Labor
$ifi %BIOPH% == on       E_Tot_WaterUse
$ifi %BIOPH% == on       E_QN
$ifi %VALUECHAIN% == on  E_ghg_total
$ifi %CROP% == on $ifi %PMPCalib% == on  E_AreaConst_UpB
$ifi %CROP% == on $ifi %PMPCalib% == on  E_AreaConst_LoB
$ifi %BIOPH% == on       E_cost_irr_crop
$ifi %BIOPH% == on       E_cost_irr_tree
/;

* ----------------------------------------------------------------------------
* PMP CALIBRATION MODEL
* ----------------------------------------------------------------------------
* This variant replaces the standard NPV objective with the PMP-calibrated
* version that includes quadratic adjustment terms
Model dahbsim_PMP / dahbsim - E_NPV_TOT + E_NPV_TOT_PMP /;

* ============================================================================
* SOLVE SETUP
* ============================================================================
* Sliding time horizon parameters
* Define first and last years of the simulation period
Parameter 
    fyear   "First year of simulation"
    lyear   "Last year of simulation";

fyear = %FstYear%;
lyear = %LstYear%;

Set
    objSet /GM, WAT, LAB, GHG,NL, DIV, MCDA/;

* ============================================================================
* SECTION 1: EXTERNAL OUTPUT DECLARATIONS
* ============================================================================
* These parameters receive output from external simulation modules
* (e.g., biophysical models, crop growth models)
* ============================================================================

$onExternalOutput

parameters
           rephh(*,*,*,*)                     "Income during simulation period"
           repyld(*,*,*,*,*,*,*)              "Yield during simulation years"
           repArea(*,*,*,*,*)                 "Aggregated crop area by crop type and soil type"
           r_WstressCoefficient(*,*,*,*,*)    "Water stress coefficient from biophysical module"
           r_NstressCoefficient(*,*,*,*,*)    "Nitrogen stress coefficient from biophysical module"
           r_SWICoefficient(*,*,*,*,*)        "Soil water index coefficient"
;

$offExternalOutput

* ============================================================================
* SECTION 2: BUSINESS MODEL CANVAS PARAMETERS
* ============================================================================
* Parameters representing Osterwalder's Business Model Canvas components
* ============================================================================

Parameter 
    P_KeyPartners(*,*,*,*)          "Key partnerships and collaborations"
    P_KeyActivities(*,*,*,*)        "Main value-creating activities"
    P_KeyResources(*,*)             "Strategic resources required"
    P_ValuePropositions(*,*,*)      "Value offered to customers"
    P_CustomerRelationships(*,*)    "Relationship types with customer segments"
    P_Channels(*,*,*)               "Distribution and communication channels"
    P_CustomerSegments(*,*,*,*)     "Target customer groups"
    P_CostStructure(*,*)              "Major cost categories"
    P_RevenueStreams(*,*)             "Revenue generation mechanisms"
* Sustainability Indicators (WEFE Nexus)
    P_Water_Indicator(*, y2)        "Water-related sustainability metric"
    P_Energy_Indicator(*, y2)       "Energy-related sustainability metric"
    P_Food_Indicator(*, y2)         "Food security sustainability metric"
    P_Ecosystem_Indicator(*, y2)    "Ecosystem services metric"
    
* Market/Buyer Parameters
    P_CropBuyers(y2,*)              "Crop buyers by year"
    P_LivestockBuyers(y2,*)         "Livestock buyers by year"
    P_TreeProductionBuyers(y2,*)    "Tree product buyers by year"
;    

* ============================================================================
* SECTION 3: HOUSEHOLD-LEVEL SIMULATION OUTPUTS
* ============================================================================
* Parameters tracking household-level economic and consumption variables
* ============================================================================

Parameter
    p_Diversity(hhold, y2)          "Total number of distinct crops cultivated per household"
;

parameters
           repcons(*,*,*,*)          "Consumption quantity during simulation"
           repfert(*,*,*)            "Quantity of fertilizer used in simulation"
           repself(*,*,*,*)          "Self-consumption quantity"
           repMpur(*,*,*,*)          "Quantity of market-purchased products"
           repProd(*,*,*,*)          "Quantity of production per product"
           repUtil(*,*,*)            "Net present value (NPV) per household"
           repcact(*,*,*,*,*,*,*)    "Crop area by activity type"
;

* ============================================================================
* SECTION 4: BIOPHYSICAL SIMULATION OUTPUTS
* ============================================================================
* Parameters generated from biophysical module loops
* ============================================================================
Parameters
           Wstress(*,*,*,*,*,*,*)    "Water stress index (from biophysical module)"
           Nstress(*,*,*,*,*,*,*)    "Nitrate stress index (from biophysical module)"
           
* Saved output aggregates
           repghg_saved(objSet, y2)           "Saved GHG emissions"
           repGM_saved(objSet, y2)            "Saved gross margin"
           repWaterUse_saved(objSet, y2)      "Saved water usage"
           repDiversity_saved(objSet, y2)     "Saved biodiversity/diversity index"
           repN_leaching_saved(objSet, y2)    "Saved nitrogen leaching"
           repLabor_saved(objSet, *)          "Saved labor requirements"
           
* Nitrogen and irrigation tracking
           repKSannual(*,*,*,*)               "Annual crop coefficient (Kc)"
           rep_v_nstress                      "Nitrogen stress variable"
           rep_v_nfin                         "Final nitrogen content"
           rep_v_nini                         "Initial nitrogen content"
           rep_v_fertilizer_annual            "Annual fertilizer application"
           rep_v_nres                         "Residual nitrogen"
           rep_v_nmin                         "Mineralized nitrogen"
           rep_v_nl                           "Nitrogen leaching"
           rep_v_irrigation_opt(*,*,*,*,*)    "Optimal irrigation amounts"
           rep_v_DR_start(*,*,*,*,*,*)        "Deficit irrigation start timing"
           rep_v_DR_end(*,*,*,*,*,*)          "Deficit irrigation end timing"
           rep_v_KS_avg_annual(*,*,*,*,*)     "Average annual crop coefficient"
           rep_Area_AF                        "Agricultural area"
           rep_Livestock_Pop                  "Livestock population"
           rep_bluewater                      "Blue water consumption (surface/groundwater)"
           rep_greenwater                     "Green water consumption (rainwater)"
           rep_greywater                      "Grey water (water required to assimilate pollutants)"
;

* ============================================================================
* SECTION 5: WEFE NEXUS INDICATORS
* ============================================================================
* Water-Energy-Food-Ecosystem Nexus indicators
* ============================================================================

parameters
           repEnergy(*,*,*,*)        "Energy consumption/production"
           repGHG(*,*,*,*)           "Greenhouse gas emissions"
           repWater(*,*,*,*)         "Water consumption/withdrawal"
           repIncome(*,*,*,*)        "Income generation"
           repProductivity(*,*,*,*)  "Productivity metrics"
;

* ============================================================================
* SECTION 6: REPORT OUTPUT FORMATTING OPTIONS
* ============================================================================
* Controls decimal precision and dimension display in output reports
* ============================================================================

option rephh      :2:3:1;
option repcons    :2:3:1;
option repyld     :2:6:1;
option repArea    :2:4:1;
option repfert    :2:2:1;
option repself    :2:3:1;
option repMpur    :2:3:1;
option repProd    :2:3:1;
option repUtil    :2:2:1;

* ============================================================================
* SECTION 7: BIOPHYSICAL MODEL FIXED PARAMETERS (SiwaPMP Module)
* ============================================================================
* Stores baseline biophysical parameters for use during calibration
* ============================================================================

$iftheni %BIOPH%==on

* Store fixed values from biophysical module
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y);
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) = irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) = p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) = p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) = p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) = p_KS_year(hhold,crop_and_tree,field,inten,y);

* ============================================================================
* SECTION 8: CROP STRESS AND PRESSURE CALCULATIONS
* ============================================================================
* Calculates combined stress indices and yield adjustments based on
* nitrogen and water stress coefficients
* ============================================================================


$ifThenI %CROP%==ON 
* Calculate combined stress pressure = N-stress × water stress (Kc)
pressureCrop(hhold, crop_activity, crop_preceding, field, inten) = 
    p_nstress_fixed(hhold, crop_activity, field, inten, 'y01') * 
    p_KS_avg_annual_fixed(hhold, crop_activity, field, inten, 'y01');
$endif
* Handle orchard/tree crops separately
$ifThenI %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
    display pressuretree;
$endif
$endif
* ============================================================================
* SECTION 9: BIOPHYSICAL CALIBRATION MODULE
* ============================================================================
* Calculates calibration adjustments for biophysical model parameters
* ============================================================================

$iftheni %BIOPHcalib%==on

* Calculate calibration adjustment factor
calibBioph(hhold, crop_activity, crop_preceding, field, inten) = 0
$ifi %CROP%==on     +pressureCrop(hhold, crop_activity, crop_preceding, field, inten) * 
$ifi %CROP%==on     p_Yld_C_max(hhold, crop_activity, crop_preceding, field, inten) -
$ifi %CROP%==on     p_Yld_C(hhold, crop_activity, crop_preceding, field, inten)

;

* Calculate yield difference after calibration
diffyield(hhold, crop_activity, crop_preceding, field, inten) = 0
$ifi %CROP%==on     +(p_Yld_C_max(hhold, crop_activity, crop_preceding, field, inten) * 
$ifi %CROP%==on      pressureCrop(hhold, crop_activity, crop_preceding, field, inten) - 
$ifi %CROP%==on      calibBioph(hhold, crop_activity, crop_preceding, field, inten)) - 
$ifi %CROP%==on     p_Yld_C(hhold, crop_activity, crop_preceding, field, inten)
;

$endif

* ============================================================================
* SECTION 10: STRESS-ADJUSTED YIELD CALCULATION
* ============================================================================
* Calculates final yield under combined water and nitrogen stress conditions
* ============================================================================
$iftheni %BIOPH%==on
$iftheni %CROP%==on
p_Yld_C_stress(hhold, crop_activity, crop_preceding, field, inten) = 
    max(0, (
        (p_Yld_C_max(hhold, crop_activity, crop_preceding, field, inten) * 
         p_nstress_fixed(hhold, crop_activity, field, inten, 'y01') * 
         p_KS_avg_annual_fixed(hhold, crop_activity, field, inten, 'y01')) - 
        calibBioph(hhold, crop_activity, crop_preceding, field, inten)
    ));
$endif
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif
$endif

* ============================================================================
* SECTION 11: PMP (Positive Mathematical Programming) CALIBRATION
* ============================================================================
* Includes calibration modules for production activity analysis
* ============================================================================

* Conditionally include calibration modules based on compiler flags
$ifi %CROP%==on $ifi %PMPCalib%==on $include "PMPcalibrationModule.gms"
$ifi %CROP%==on $ifi %PMPCalib%==on display PMPSolnCheck;

* ============================================================================
* SECTION 12: PMP RESULTS EXPORT
* ============================================================================
* Exports PMP calibration results to Excel for analysis
* ============================================================================

$ifi %CROP%==on $ifi %PMPCalib%==on execute_unload "PMPresult/PMPSolnCheck.gdx" PMPSolnCheck;

$iftheni %PMPCalib%==on
* Export to Excel format
execute 'gdxxrw PMPresult/PMPSolnCheck.gdx output=PMPresult/PMPSolnCheck.xlsx par=PMPSolnCheck rng=A1';

* Embedded code for direct Excel writing (alternative method)
* EmbeddedCode Connect:
* - GAMSReader:
*     symbols: [ {name: PMPSolnCheck}]
* - ExcelWriter:
*     file: Dahbsim_PMP.xlsx
*     valueSubstitutions: {EPS: 0, INF: 999999}
*     symbols:
*       - {name: PMPSolnCheck, range: PMPSolnCheck!A1}
* endEmbeddedCode
$endIf

* ============================================================================


*********************************************************************************
** ANNUAL MODEL SOLUTION AND RESULTS PROCESSING LOOP
** This loop executes the model for each year and collects all results
*********************************************************************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf

$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif

$endIf

*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
$ifi %DIONYSUS%==on solve dahbsim using MIP maximizing v_npv_tot;
$ifi %DIONYSUS%==off solve dahbsim_PMP using MINLP maximizing v_npv_tot;

* Free up irrigation decision variables after year 1 (calibration period)

$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.lo(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.up(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;


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


*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('GM',y2)=0
*GREENWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;

*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('GM',y2) = 0
*BLUEWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('GM',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);




****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"GM","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"GM","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'GM',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("GM",y2)+rep_bluewater("GM",y2)+ rep_greywater("GM",y2)
;
repIncome(hhold,'GM',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,'GM',"productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('GM',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('GM',y2) = rep_bluewater('GM',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('GM',y2) = 0+ V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on repN_leaching_saved('GM',y2) = 0
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON repLabor_saved('GM',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
$ifi %VALUECHAIN%==ON +v_laborBuyerOutput.l('y01');
;
*****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));

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



$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));
;
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
display rephh;
EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_GM.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode





*
*********************************************************************************
*** ANNUAL MODEL SOLUTION AND RESULTS PROCESSING LOOP
*** This loop executes the model for each year and collects all results
**********
********FINITO
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
*


$iftheni %DIONYSUS%==on

*********************************************INITIALIZATION
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif


$endIf

*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using mip maximizing V_Diversity;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.lo(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.up(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;

****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('DIV',y2) = sum(hhold, v_GHG.l(hhold,'y01'));


*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('DIV',y2)=0
*GREENWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('DIV',y2) = 0
*BLUEWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('DIV',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"DIV","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"DIV","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'DIV',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater('DIV',y2)+rep_bluewater('DIV',y2)+rep_greywater('DIV',y2)
;
;
repIncome(hhold,'DIV',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,"DIV","productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('DIV',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('DIV',y2) = rep_bluewater('DIV',y2);;
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('DIV',y2) = V_diversity.l;
;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on repN_leaching_saved('DIV',y2) = 0
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('DIV',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
;
****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));


$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
* sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) =sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw);
;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;

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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));
;
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
* End of annual loop y2


EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_DIV.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode












*******************************************INITIALIZATION************************************************
*******************************************************************************************
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif


$endIf


*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using mip minimizing V_Tot_WaterUse;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.lo(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.up(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;


****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('WAT',y2) = sum(hhold, v_GHG.l(hhold,'y01'));


*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('WAT',y2)=0
*GREENWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('WAT',y2) = 0
*BLUEWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('WAT',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"WAT","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"WAT","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'WAT',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("WAT",y2)+rep_bluewater("WAT",y2)+rep_greywater("WAT",y2)
;
repIncome(hhold,'WAT',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,'WAT',"productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('WAT',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('WAT',y2) =rep_bluewater('WAT',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('WAT',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on  repN_leaching_saved('WAT',y2) = 0
$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('WAT',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
;

****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));



$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) =sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw)
;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));
;
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
* End of annual loop y2


EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_WAT.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode


*******************************************INITIALIZATION************************************************
*******************************************************************************************
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif

$endIf
*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using mip maximizing V_Total_ValueChain_Labor;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.lo(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.up(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;




****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('LAB',y2) = sum(hhold, v_GHG.l(hhold,'y01'));

*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('LAB',y2)=0
*GREENWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('LAB',y2) = 0
*BLUEWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('LAB',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"LAB","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"LAB","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'LAB',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("LAB",y2)+rep_bluewater("LAB",y2)+rep_greywater("LAB",y2)
;
repIncome(hhold,'LAB',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,'LAB',"productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('LAB',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('LAB',y2) =rep_bluewater('LAB',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('LAB',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on  repN_leaching_saved('LAB',y2) = 0
$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('LAB',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
;
****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));

$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
* sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) = sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw)
;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));
;
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
* End of annual loop y2


EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_LAB.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode

*$onText


*******************************************INITIALIZATION************************************************
*******************************************************************************************
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif


$endIf
*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using MIP minimizing V_GHGtotal;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.lo(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.up(hhold,feedc,type_animal,y) = 100000;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;

****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('GHG',y2) = sum(hhold, v_GHG.l(hhold,'y01'));

*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('GHG',y2)=0
*GREENWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('GHG',y2) = 0
*BLUEWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('GHG',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"GHG","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"GHG","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'GHG',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("GHG",y2)+rep_bluewater("GHG",y2)+rep_greywater("GHG",y2)
;
repIncome(hhold,'GHG',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,'GHG',"productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('GHG',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('GHG',y2) =rep_bluewater('GHG',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('GHG',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on  repN_leaching_saved('GHG',y2) = 0
$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('GHG',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
;
****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));

$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
* sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) = sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw)
;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)))
;
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
* End of annual loop y2


EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_GHG.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode




******NITRATE LEACHING

*******************************************INITIALIZATION************************************************
*******************************************************************************************
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif

$endIf

*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve dahbsim using MIP minimizing V_QN;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;

****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('NL',y2) = sum(hhold, v_GHG.l(hhold,'y01'));
*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('NL',y2)=0
*GREENWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('NL',y2) = 0
*BLUEWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('NL',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"NL","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"NL","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,'NL',"water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("NL",y2)+rep_bluewater("NL",y2)+rep_greywater("NL",y2)
;
repIncome(hhold,'NL',"income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,'NL',"productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('NL',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('NL',y2) =rep_bluewater('NL',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('NL',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on  repN_leaching_saved('NL',y2) = 0
$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('NL',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));

$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
* sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) = sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw)
;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)))
;
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
* End of annual loop y2


EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_NL.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode









scalar
repGM_saved_max
repGM_saved_min
repghg_saved_max
repghg_saved_min
repWaterUse_saved_max
repWaterUse_saved_min
repDiversity_saved_max
repDiversity_saved_min
repN_leaching_saved_max
repN_leaching_saved_min
repLabor_saved_max
repLabor_saved_min
;

Parameter
    VGM_max, VGM_min,
    VW_max,  VW_min,
    VL_max,  VL_min,
    VGHG_max, VGHG_min,
    VD_max,  VD_min
    VNL_max, VNL_min;

repGM_saved_max  = smax((objSet,y2), repGM_saved(objSet,y2));
repGM_saved_min  = smin((objSet,y2), repGM_saved(objSet,y2));
repghg_saved_max  = smax((objSet,y2), repghg_saved(objSet,y2));
repghg_saved_min  = smin((objSet,y2), repghg_saved(objSet,y2));
repWaterUse_saved_max= smax((objSet,y2), repWaterUse_saved(objSet,y2));
repWaterUse_saved_min= smin((objSet,y2), repWaterUse_saved(objSet,y2));
repDiversity_saved_max= smax((objSet,y2), repDiversity_saved(objSet,y2));
repDiversity_saved_min= smin((objSet,y2), repDiversity_saved(objSet,y2));
repN_leaching_saved_max= smax((objSet,y2), repN_leaching_saved(objSet,y2));
repN_leaching_saved_min= smin((objSet,y2), repN_leaching_saved(objSet,y2));
repLabor_saved_max= smax((objSet,y2), repLabor_saved(objSet,y2));
repLabor_saved_min= smin((objSet,y2), repLabor_saved(objSet,y2));

display
repGM_saved_max
repGM_saved_min
repghg_saved_max
repghg_saved_min
repWaterUse_saved_max
repWaterUse_saved_min
repDiversity_saved_max
repDiversity_saved_min
repN_leaching_saved_max
repN_leaching_saved_min
repLabor_saved_max
repLabor_saved_min

;
*
Variable
V_MCDA;

Equation
E_MCDA 'MCDA objective'
;


Parameter
P_W_GM/0.2/
P_W_Water/0/
P_W_JobCreation/0.2/
P_W_GHG/0.2/
P_W_Biodiversity/0.2/
P_W_NL/0.2/
;



*- alpha*
*               SUM((year,field,crop)$P_Q_C(year,field,crop),P_Q_C(year,field,crop)*
*               POWER(SUM(c_crop,V_Plant_C(year,field,c_crop,crop)$rot(field,c_crop,crop)),2)))
*0
E_MCDA..
     V_MCDA
          =E=  
               P_W_GM * (v_npv_tot - repGM_saved_min)/(repGM_saved_max - repGM_saved_min )
- P_W_Water * (V_Tot_WaterUse- repWaterUse_saved_min)/(repWaterUse_saved_max - repWaterUse_saved_min+0.0001)
+ P_W_JobCreation * (V_Total_ValueChain_Labor - repLabor_saved_min)/(repLabor_saved_max - repLabor_saved_min )
- P_W_GHG * (V_GHGtotal - repghg_saved_min)/(repghg_saved_max - repghg_saved_min )
+ P_W_Biodiversity * (v_diversity - repDiversity_saved_min)/(repDiversity_saved_max - repDiversity_saved_min)
- P_W_NL * (V_QN - repN_leaching_saved_min)/(repN_leaching_saved_max - repN_leaching_saved_min )
;


model MCDA /dahbsim_PMP +E_MCDA/;


*******************************************INITIALIZATION************************************************
*******************************************************************************************
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity,field) = sum((inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)) ;
v0_Prd_C(hhold,crop_activity,field,inten) = sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea));
p_Use_Input_C(hhold,crop_activity,i) = sum((field,inten,NameArea), p_cropCoef(hhold,crop_activity,field,inten,NameArea)*p_inputReq(hhold,crop_activity,field,inten,i));
p_Use_Seed_C(hhold,crop_activity,NameseedTotal)  = p_seedData(hhold,crop_activity,NameseedTotal) ;
p_Use_Seed_C(hhold,crop_activity,NameseedOnFarm) = p_seedData(hhold,crop_activity,NameseedOnFarm) ;
v0_prodQuant(hhold,c_product) = sum((a_j(crop_activity,c_product),field,inten), sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
v0_prodQuant(hhold,ck) = sum((a_k(crop_activity,ck),field,inten), sum(NameStraw,p_cropCoef(hhold,crop_activity,field,inten,NameStraw))*sum(NameArea,p_cropCoef(hhold,crop_activity,field,inten,NameArea)));
$endIf
$ifi %BIOPH%==ON 


**********************************************DIVERSITY**************************
loop(y2,
$iftheni %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
p_nav_begin_fixed(hhold,field,inten,crop_and_tree,y) =    p_nav_begin(hhold,field,inten,crop_and_tree,y);
p_nmin_fixed(hhold,field,y) = p_nmin(hhold,field,y);
p_Nres_fixed(hhold,field,y) = p_Nres_tot(hhold,field,y);
p_nl_fixed(hhold,crop_and_tree,field,inten,y) = p_nl(hhold,crop_and_tree,field,inten,y) ;
p_nfin_fixed(hhold,field,inten,crop_and_tree,y) = p_nfin(hhold,field,inten,crop_and_tree,y);
p_hini_fixed(hhold,field,y) = p_hini(hhold,field);
p_hfin_fixed(hhold,field,y) = p_hfin(hhold,field,y);
p_nav_fixed(hhold,field,inten,crop_and_tree,y) = p_nav(hhold,field,inten,crop_and_tree,y);
p_nab_fixed(hhold,crop_and_tree,field,inten,y) = p_nab(hhold, crop_and_tree, field, inten, y);
p_nstress_fixed(hhold,crop_and_tree,field,inten,y) = p_nstress(hhold,crop_and_tree,field,inten,y);
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
p_irrigation_opt_fixed(hhold,crop_and_tree,field,inten,m,y) =     irrigation_month(hhold,crop_and_tree,inten,m);
p_KS_month_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_KS_month(hhold,crop_and_tree,field,inten,m,y);
p_DR_start_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_start(hhold,crop_and_tree,field,inten,m,y);
p_DR_end_fixed(hhold,crop_and_tree,field,inten,m,y) =     p_DR_end(hhold,crop_and_tree,field,inten,m,y);
p_KS_avg_annual_fixed(hhold,crop_and_tree,field,inten,y) =     p_KS_year(hhold,crop_and_tree,field,inten,y);

$iftheni %CROP%==on
p_Yld_C_stress(hhold,crop_activity,crop_preceding,field,inten)=max(0,((p_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten)*p_nstress_fixed(hhold,crop_activity,field,inten,'y01')*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,'y01'))-   calibBioph(hhold,crop_activity,crop_preceding,field,inten)));
$endIf
$iftheni %ORCHARD%==ON 
    pressuretree(hhold, c_tree, field, inten) = 
        p_nstress_fixed(hhold, c_tree, field, inten, 'y01') * 
        p_KS_avg_annual_fixed(hhold, c_tree, field, inten, 'y01');
$endif


$endIf

*** Unfix variables only after the first year due to calibration
*** This allows the model to adjust irrigation decisions in subsequent years
solve MCDA using MINLP maximizing V_MCDA;
* Free up irrigation decision variables after year 1 (calibration period)
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.lo(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 0;
$ifi %FIXEDIRRIGATION% == OFF $ifi %BIOPH% == ON v_irrigation_opt.up(hhold,crop_activity_endo,field,inten,m,y)$(ord(y2) > 1) = 1e9;
*
$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= 0;
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= 1e9;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,type_animal,y)=0;
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,type_animal,y)=1e9;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = 0;
*$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = 1e9;
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = 0;
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = 1;





****************************************************************************
* SECTION 1: CORE MODEL OUTPUTS
* Basic household-level economic and consumption results
****************************************************************************
rephh(hhold,'income','full',y2)        = v_fullIncome.l(hhold,'y01');
repcons(hhold,good,'hconQuant',y2)     = v_hconQuant.l(hhold,good,'y01');
$ifi %ORCHARD%==on rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$ifi %LIVESTOCK_simplified%==on rep_Livestock_Pop(hhold,type_animal,age,y2)=V_animals.L(hhold,type_animal,age,'y01');
$iftheni %CROP%==on
repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2)   = V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repyld(hhold,crop_activity_endo,crop_preceding,field,inten,'yield',y2)   = v_Yld_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01');
repArea(hhold,crop_activity_endo,inten,'area',y2)= sum((crop_preceding,field), V_Plant_C.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'));
repfert(hhold,'Nitr',y2)= sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01'));
$endIf
repself(hhold,c_product,'Selfcons',y2)  = v_selfcons.l(hhold,c_product,'y01');
repMpur(hhold,good,'MketPurch',y2)      = v_markPurch.l(hhold,good,'y01');
repProd(hhold,c_product_endo,'Production',y2) = v_prodQuant.l(hhold,c_product_endo,'y01');
repUtil(hhold,'Utility',y2)              = v_npv.l(hhold);
$ifi %VALUECHAIN%==ON repghg_saved('ghg',y2) = sum(hhold, v_GHG.l(hhold,'y01'));
*20-04
*GREENWATER
$ifi %BIOPH%==on rep_greenwater('MCDA',y2)=0
*GREENWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(       (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)), p_rain('y01',m) )*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*GREENWATER ORCHARD
$ifi %ORCHARD%==on +  sum((hhold,m,c_tree,field,inten),min((ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)), p_rain('y01',m))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*BLUEWATER
$ifi %BIOPH%==on rep_bluewater('MCDA',y2) = 0
*BLUEWATER CROP
$ifi %CROP%==on + sum((hhold,m,crop_activity,field,inten),min(irrigation_month(hhold,crop_activity,inten,m),max(0, (ET0_month(hhold,crop_activity,field,inten,m,'y01') * p_kc(crop_activity,field,inten)) - p_rain('y01',m)))*sum(crop_preceding,V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
*BLUEWATER ORCHARD
$ifi %ORCHARD%==on + sum((hhold,m,c_tree,field,inten),min(irrigation_month(hhold,c_tree,inten,m),max(0, (ET0_month(hhold,c_tree,field,inten,m,'y01') * p_kc(c_tree,field,inten)) - p_rain('y01',m)))*sum(age_tree,V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
;
*GREYWATER
$ifi %BIOPH%==on rep_greywater('MCDA',y2) = (0
*GREYWATER CROP
$ifi %BIOPH%==on $ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
*GREYWATER ORCHARD
$ifi %BIOPH%==on $ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
$ifi %BIOPH%==on )/(MaxConcNitr-InitConcNitr);
****************************************************************************
* SECTION 2: WEFENI INDICATORS
* Water-Energy-Food-Environment Nexus Indicators
****************************************************************************
$ifi %VALUECHAIN%==ON     repEnergy(hhold,"MCDA","energy",y2) = V_energy.l(hhold,'y01');
$ifi %VALUECHAIN%==ON     repGHG(hhold,"MCDA","ghg",y2)       = v_GHG.l(hhold,'y01');
repWater(hhold,"MCDA","water",y2)   = 0
$ifi %BIOPH%==on $ifi %CROP%==ON    +     rep_greenwater("MCDA",y2)+rep_bluewater("MCDA",y2)+rep_greywater("MCDA",y2)
;
repIncome(hhold,"MCDA","income",y2)          = v_fullIncome.l(hhold,'y01');
repProductivity(hhold,"MCDA","productivity",y2) = sum(c_product_endo, v_prodQuant.l(hhold,c_product_endo,'y01'));
****************************************************************************
* SECTION 3: MCDA DATA PREPARATION
* Multi-Criteria Decision Analysis indicators
****************************************************************************
repGM_saved('MCDA',y2) = sum(hhold, rho('y01') * v_util.l(hhold,'y01'));
    
$ifi %BIOPH%==on repWaterUse_saved('MCDA',y2) =rep_bluewater('MCDA',y2);
    
$ifi %VALUECHAIN%==ON     repDiversity_saved('MCDA',y2) = V_diversity.l;
* Calculate nitrogen leaching (sum of crop and orchard nitrogen use * leaching factor)
$ifi %BIOPH%==on  repN_leaching_saved('MCDA',y2) = 0
$ifi %CROP%==on +p_Nl_raw * sum(hhold,             sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')) + repfert(hhold,'Nitr',y2)= p_Nl_raw * sum(crop_activity_endo, V_Use_Input_C.l(hhold,crop_activity_endo,'nitr','y01')))
$ifi %ORCHARD%==on + p_Nl_raw * sum((hhold,c_tree), V_Nfert_AF.l(hhold,c_tree,'y01'))
;
$ifi %VALUECHAIN%==ON     repLabor_saved('MCDA',y2) =0
$ifi %VALUECHAIN%==ON $ifi %ORCHARD%==on  +v_laborSeller_AF.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborFeed_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborLivestock_seller.l('y01')
$ifi %VALUECHAIN%==ON $ifi %LIVESTOCK_simplified%==on +v_laborSeller_A.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSeeder.l('y01')
$ifi %VALUECHAIN%==ON $ifi %CROP%==on  +v_laborSellerInput.l('y01')
+v_laborBuyerOutput.l('y01');
;
****************************************************************************
* SECTION 4: SECTOR-SPECIFIC INDICATORS
* Biodiversity, water use, food production, and ecosystem indicators
****************************************************************************
* Count number of crops grown (biodiversity indicator)
p_Diversity(hhold,y2) = 0
$ifi %CROP%==on  + sum(crop_activity_endo,V_Crop_Number.l('y01', hhold, crop_activity_endo))
;
$ifi %BIOPH%==on $ifi %CROP%==on P_Water_Indicator("Crop", y2) =SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')));
$ifi %LIVESTOCK_simplified%==on P_Water_Indicator("Livestock", y2) = 0;  
$ifi %ORCHARD%==on P_Water_Indicator("Tree", y2) =SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')));

$ifi %CROP%==on P_Food_Indicator("Crop", y2) = sum(hhold, V_Sale_C.L(hhold,'y01'));
$ifi %LIVESTOCK_simplified%==on P_Food_Indicator("Livestock", y2) = sum(hhold, V_Revenue_A.L(hhold,'y01'));
$ifi %ORCHARD%==on P_Food_Indicator("Tree", y2) = sum(hhold, V_Sale_AF.L(hhold,'y01'));
$ifi %BIOPH%==on $ifi %CROP%==onP_Ecosystem_Indicator("Crop", y2) = sum((hhold,crop_activity_endo), V_Use_Input_C.L(hhold,crop_activity_endo,"nitr",'y01'));
* sum((crop_activity,field,inten), p_Nl(hhold,crop_activity,field,inten)));
$ifi %LIVESTOCK_simplified%==on P_Ecosystem_Indicator("Livestock", y2) = 0;           
$ifi %ORCHARD%==on $ifi %BIOPH%==on P_Ecosystem_Indicator("Tree", y2) =sum((hhold,c_tree), V_Nfert_AF.L(hhold,c_tree,'y01') * p_nl_raw)
;;

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
$ifi %BIOPH%==on           P_ValuePropositions('Environmental', 'Minimized Water Use', y2) =
$ifi %BIOPH%==on   $ifi %ORCHARD%==on +SUM((hhold,c_tree,inten,m), irrigation_month(hhold,c_tree,inten,m) * SUM((age_tree,field), V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01')))
$ifi %BIOPH%==on   $ifi %CROP%==on +SUM((hhold,crop_activity,inten,m), irrigation_month(hhold,crop_activity,inten,m)*SUM((crop_preceding,field), V_Plant_C.L(hhold,crop_activity,crop_preceding,field,inten,'y01')))
;
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
$iftheni %BIOPH%==on rep_v_nstress(hhold,crop_and_tree,field,inten,y2)          = p_nstress_fixed(hhold,crop_and_tree,field,inten,'y01')
;
rep_v_nfin(hhold,field,y2) =0
$ifi %CROP%==on +sum((inten,crop_activity_endo),        p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)))
;
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
* End of annual loop y2

EmbeddedCode Connect:

- GAMSReader:
    symbols: [ {name: rephh},
               {name: repcons},
               {name: repcact},
               {name: repyld},
               {name: repArea},
               {name: repfert},
               {name: repself},
               {name: repMpur},
               {name: repProd},
               {name: repUtil},
               {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity},
               {name: repghg_saved},
               {name: repGM_saved},
               {name: repWaterUse_saved},
               {name: repDiversity_saved},
               {name: repN_leaching_saved},
               {name: repLabor_saved},
               {name: p_Diversity},
               {name: P_Water_Indicator},
               {name: P_Food_Indicator},
               {name: P_Ecosystem_Indicator},
               {name: P_Energy_Indicator},
               {name: P_KeyPartners},
               {name: P_CropBuyers},
               {name: P_TreeProductionBuyers},
               {name: P_LivestockBuyers},
               {name: P_KeyActivities},
               {name: P_KeyResources},
               {name: P_ValuePropositions},
               {name: P_CustomerRelationships},
               {name: P_Channels},
               {name: P_CustomerSegments},
               {name: P_CostStructure},
               {name: P_RevenueStreams},
               {name: rep_v_irrigation_opt},
               {name: rep_v_DR_start},
               {name: rep_v_DR_end},
               {name: rep_v_KS_avg_annual},
               {name: rep_v_nstress},
               {name: rep_v_nfin},
               {name: rep_v_nmin},
               {name: rep_v_nl},
               {name: rep_v_nres}]

- ExcelWriter:
    file: Dahbsim_Output_MCDA.xlsx
    valueSubstitutions: {EPS: 0, INF: 999999}
    symbols:
      - {name: rephh, range: rephh!A1}
      - {name: repcons, range: repcons!A1}
      - {name: repself, range: repself!A1}
      - {name: repMpur, range: repMpur!A1}
      - {name: repProd, range: repProd!A1}
      - {name: repUtil, range: repUtil!A1}
      - {name: repcact, range: Crop_Activity!A1}
      - {name: repyld, range: Crop_Yield!A1}
      - {name: repArea, range: Crop_Area!A1}
      - {name: repfert, range: Fertilizer!A1}
      - {name: repEnergy, range: Energy!A1}
      - {name: repGHG, range: GHG!A1}
      - {name: repWater, range: Water!A1}
      - {name: repIncome, range: Income!A1}
      - {name: repProductivity, range: Productivity!A1}
      - {name: repghg_saved, range: GHG_Saved!A1}
      - {name: repGM_saved, range: GM_Saved!A1}
      - {name: repWaterUse_saved, range: WaterUse_Saved!A1}
      - {name: repDiversity_saved, range: Diversity!A1}
      - {name: repN_leaching_saved, range: N_Leaching!A1}
      - {name: repLabor_saved, range: Labor!A1}
      - {name: p_Diversity, range: p_Diversity!A1}
      - {name: P_Water_Indicator, range: Water_Indicator!A1}
      - {name: P_Food_Indicator, range: Food_Indicator!A1}
      - {name: P_Ecosystem_Indicator, range: Ecosystem!A1}
      - {name: P_Energy_Indicator, range: Energy_Indicator!A1}
      - {name: P_KeyPartners, range: Key_Partners!A1}
      - {name: P_CropBuyers, range: Crop_Buyers!A1}
      - {name: P_TreeProductionBuyers, range: Tree_Buyers!A1}
      - {name: P_LivestockBuyers, range: Livestock_Buyers!A1}
      - {name: P_KeyActivities, range: Key_Activities!A1}
      - {name: P_KeyResources, range: Key_Resources!A1}
      - {name: P_ValuePropositions, range: Value_Props!A1}
      - {name: P_CustomerRelationships, range: Customer_Relations!A1}
      - {name: P_Channels, range: Channels!A1}
      - {name: P_CustomerSegments, range: Customer_Segments!A1}
      - {name: P_CostStructure, range: Cost_Structure!A1}
      - {name: P_RevenueStreams, range: Revenue_Streams!A1}
      - {name: rep_v_irrigation_opt, range: Irrigation!A1}
      - {name: rep_v_DR_start, range: DR_Start!A1}
      - {name: rep_v_DR_end, range: DR_End!A1}
      - {name: rep_v_KS_avg_annual, range: KS_Avg!A1}
      - {name: rep_v_nstress, range: N_Stress!A1}
      - {name: rep_v_nfin, range: N_Fin!A1}
      - {name: rep_v_nmin, range: N_Min!A1}
      - {name: rep_v_nl, range: N_Leaching_Detail!A1}
      - {name: rep_v_nres, range: N_Residue!A1}

endEmbeddedCode


embeddedCode Connect:
- GAMSReader:
    symbols: [ {name: repEnergy},
               {name: repGHG},
               {name: repWater},
               {name: repIncome},
               {name: repProductivity}]
- ExcelWriter:
    file: WEFENI.xlsx
    valueSubstitutions: {EPS: 0}
    symbols:
      - {name: repEnergy,range: repEnergy!A1}
      - {name: repGHG,range: repGHG!A1}
      - {name: repWater,range: repWater!A1}
      - {name: repIncome,range: repIncome!A1}
      - {name: repProductivity,range: repProductivity!A1}
endEmbeddedCode

*$offText
* ----- Scaling & IO multipliers
Scalar Scale_National           "Number of identical representative farms"           / 1000 /
       IO_Mult_TypeI            "Upstream (Type I) output multiplier"               / 0.35 /
       IO_Mult_TypeII           "Induced (Type II) add-on over Type I"             / 0.20 /;

* ----- Value-added shares of revenue (direct VA)
Scalar VA_Share_C               "Crop value-added share of revenue"                 / 0.45 /
       VA_Share_A               "Livestock value-added share of revenue"            / 0.35 /
       VA_Share_AF              "Tree/AF value-added share of revenue"              / 0.40 /;

* ----- Import content (share of spending that leaks abroad)
Scalar Import_Share_InputC      "Crop input import content"                         / 0.40 /
       Import_Share_InputA      "Feed import content"                                / 0.50 /
       Import_Share_InputAF     "AF input import content"                            / 0.30 /;

* ----- Export shares of sales (to form Ag Trade Balance proxy)
Scalar Export_Share_C           "Share of crop sales exported"                      / 0.25 /
       Export_Share_A           "Share of livestock sales exported"                  / 0.15 /
       Export_Share_AF          "Share of tree sales exported"                       / 0.30 /;

* ----- Water → energy & unit conversions
Scalar k_m3_per_mmha            "m3 per mm*ha (constant)"                           / 10   /
       kWh_per_m3               "Pumping energy intensity (kWh per m3)"             / 0.5  /;

* ----- Labor conversion to FTE
Scalar Days_per_FTE            "Annual days per full-time job"                    / 265 /;

* ----- Food supply & CPI proxy
Scalar Food_Value_Ref           "Baseline dom. food value (EUR) for index"          / 1e7  /
       CPI_Pass                 "CPI pass-through from food value gap"              / 0.15 /
       CPI_Food_Weight          "Food weight in CPI basket"                         / 0.20 /;


Parameter
    P_Spend_InputC(y2)   "Crop input spending (EUR)"
    P_Spend_InputA(y2)   "Feed/input spending (EUR)"
    P_Spend_InputAF(y2)  "AF input spending (EUR)";



*Miss fertilizer tax

$ifi %CROP%==on P_Spend_InputC(y2) = P_CostStructure('Variable Costs (Crops)', y2)    ;
$ifi %LIVESTOCK_simplified%==on P_Spend_InputA(y2) = P_CostStructure('Variable Costs (Livestock)', y2);
$ifi %ORCHARD%==on P_Spend_InputAF(y2) = P_CostStructure('Variable Costs (Tree Production)', y2);
    

Parameter
    P_GDP_Ag_Direct          "Direct ag value-added (EUR)"
    P_GDP_Ag_Total           "Ag VA incl. multipliers (EUR)"
    P_Employment_FTE         "Employment (FTE), direct+IO"
    P_TradeBalance_Ag        "Ag trade balance proxy (EUR)"
    P_National_Water_m3      "National water use (m3)"
    P_National_Energy_kWh    "Pumping energy use (kWh)"
    P_National_GHG_kg        "National GHG (kg CO2e)"
    P_FoodSupply_Index       "Food supply index (=1 baseline)"
    P_CPI_Proxy              "CPI proxy (index points)";
    


P_GDP_Ag_Direct =
  Scale_National *SUM(y2, 0
$ifi %CROP%==on      +   VA_Share_C  * P_RevenueStreams('Revenue from Crop Production', y2)
$ifi %LIVESTOCK_simplified%==on    + VA_Share_A  * P_RevenueStreams('Revenue from Livestock Production', y2) 
$ifi %ORCHARD%==on    +  VA_Share_AF * P_RevenueStreams('Revenue from Tree Production', y2)
);

P_GDP_Ag_Total =
  P_GDP_Ag_Direct * (1 + IO_Mult_TypeI + IO_Mult_TypeII);
  

P_Employment_FTE =
  Scale_National
 * ( sum(y2,repLabor_saved('MCDA',y2) )/ Days_per_FTE )
 * (1 + IO_Mult_TypeI + IO_Mult_TypeII);
 
P_TradeBalance_Ag =
    Scale_National * SUM(y2,0
$ifi %CROP%==on     + Export_Share_C  * P_RevenueStreams('Revenue from Crop Production', y2)
$ifi %LIVESTOCK_simplified%==on     + Export_Share_A  * P_RevenueStreams('Revenue from Livestock Production', y2) 
$ifi %ORCHARD%==on       + Export_Share_AF * P_RevenueStreams('Revenue from Tree Production', y2)
)
  - Scale_National * SUM(y2,0
$ifi %CROP%==on       +     Import_Share_InputC  * P_Spend_InputC(y2)
$ifi %LIVESTOCK_simplified%==on   + Import_Share_InputA  * P_Spend_InputA(y2)
$ifi %ORCHARD%==on          + Import_Share_InputAF * P_Spend_InputAF(y2)
);
 
   
P_National_Water_m3 =
  Scale_National * k_m3_per_mmha
 * sum(y2,rep_bluewater('MCDA',y2));

P_National_Energy_kWh =
  P_National_Water_m3 * kWh_per_m3;
  
P_National_GHG_kg =
  Scale_National *sum((hhold,y2), repGHG(hhold,"MCDA","ghg",y2));
  
P_FoodSupply_Index =
  ( Scale_National * SUM(y2, 0
$ifi %CROP%==on      +   P_RevenueStreams('Revenue from Crop Production', y2)
$ifi %LIVESTOCK_simplified%==on    +  P_RevenueStreams('Revenue from Livestock Production', y2) 
$ifi %ORCHARD%==on    +  P_RevenueStreams('Revenue from Tree Production', y2)
))  / MAX(1e-6, Food_Value_Ref);

P_CPI_Proxy =
  CPI_Food_Weight * CPI_Pass * ( P_FoodSupply_Index - 1 );


Parameter
  P_GDP_Ag_Direct_y(y2)     "EUR"
  P_Employment_FTE_y(y2)    "FTE"
  P_Water_m3_y(y2)          "m3"
  P_Energy_kWh_y(y2)        "kWh"
  P_GHG_kg_y(y2)            "kg CO2e";

P_GDP_Ag_Direct_y(y2) =
  Scale_National *( 0
$ifi %CROP%==on      +   VA_Share_C  * P_RevenueStreams('Revenue from Crop Production', y2)
$ifi %LIVESTOCK_simplified%==on    + VA_Share_A  * P_RevenueStreams('Revenue from Livestock Production', y2) 
$ifi %ORCHARD%==on    +  VA_Share_AF * P_RevenueStreams('Revenue from Tree Production', y2)
);  

*Need to add the hired employment and the family labor
P_Employment_FTE_y(y2) =
  (Scale_National * repLabor_saved('MCDA',y2)/ Days_per_FTE )
                   * (1 + IO_Mult_TypeI + IO_Mult_TypeII) ;

P_Water_m3_y(y2) =
  Scale_National * k_m3_per_mmha * ( rep_bluewater('MCDA',y2));

P_Energy_kWh_y(y2) = P_Water_m3_y(y2) * kWh_per_m3;

P_GHG_kg_y(y2) =
  Scale_National *sum((hhold), repGHG(hhold,"MCDA","ghg",y2)) ;




******************************************************************
*============ 1) Labels for MIRO groups (nice titles) ============*
Set MacroVar  /
  "Ag GDP – Direct (EUR)"
  "Ag GDP – Total incl. Multipliers (EUR)"
  "Employment – FTE (Direct+IO)"
  "Ag Trade Balance (EUR)"
  "CPI Proxy (index pts)"
/;

Set WEFEVar   /
  "Water – National Use (m³)"
  "Energy – Pumping (kWh)"
  "GHG – National (kg CO₂e)"
  "Food – Supply Index (=1 baseline)"
  "Water Saved – Drip/Sprinkler (mm)"
  "GHG Offset – Biogas (kg CO₂e)"
/;

*============ 2) Aggregated (all-years) MIRO parameters ============*
Parameter
  P_MIRO_Macro(MacroVar)   "Macro-economic indicators (aggregated)"
  P_MIRO_WEFE(WEFEVar)     "WEFE macro indicators (aggregated)";


* ---- Macro group (use your previously computed parameters) ----
P_MIRO_Macro("Ag GDP – Direct (EUR)")                   = P_GDP_Ag_Direct;
P_MIRO_Macro("Ag GDP – Total incl. Multipliers (EUR)")  = P_GDP_Ag_Total;
P_MIRO_Macro("Employment – FTE (Direct+IO)")            = P_Employment_FTE;
P_MIRO_Macro("Ag Trade Balance (EUR)")                  = P_TradeBalance_Ag;
P_MIRO_Macro("CPI Proxy (index pts)")                   = P_CPI_Proxy;

* ---- WEFE group (use your previously computed parameters) ----
P_MIRO_WEFE("Water – National Use (m³)")                = P_National_Water_m3;
P_MIRO_WEFE("Energy – Pumping (kWh)")                   = P_National_Energy_kWh;
P_MIRO_WEFE("GHG – National (kg CO₂e)")                 = P_National_GHG_kg;
P_MIRO_WEFE("Food – Supply Index (=1 baseline)")        = P_FoodSupply_Index;


*============ 3) Year-by-year MIRO tables (for charts) ============*
Parameter
  P_MIRO_Macro_y(MacroVar,y2)   "Macro-economic indicators by year"
  P_MIRO_WEFE_y(WEFEVar,y2)     "WEFE macro indicators by year"
;

* ---- Macro (yearly splits) ----
P_MIRO_Macro_y("Ag GDP – Direct (EUR)",y2)                  = P_GDP_Ag_Direct_y(y2);
P_MIRO_Macro_y("Employment – FTE (Direct+IO)",y2)           = P_Employment_FTE_y(y2);


* ---- WEFE (yearly splits) ----
P_MIRO_WEFE_y("Water – National Use (m³)",y2)               = P_Water_m3_y(y2);
P_MIRO_WEFE_y("Energy – Pumping (kWh)",y2)                  = P_Energy_kWh_y(y2);
P_MIRO_WEFE_y("GHG – National (kg CO₂e)",y2)                = P_GHG_kg_y(y2);


P_MIRO_WEFE_y("Food – Supply Index (=1 baseline)",y2)       = 
  ( Scale_National *( 0
$ifi %CROP%==on      +   P_RevenueStreams('Revenue from Crop Production', y2)
$ifi %LIVESTOCK_simplified%==on    +  P_RevenueStreams('Revenue from Livestock Production', y2) 
$ifi %ORCHARD%==on    +  P_RevenueStreams('Revenue from Tree Production', y2)
))  / MAX(1e-6, Food_Value_Ref);

*****************************************************************************

***************************************************************************************************************************
$ontext
From Rhouma et al. 2025, the WEFENI is built on five indicators:

Water footprint (WF) – m³ of (green+blue) water per unit production.

Energy footprint (EF) – MJ of diesel+electricity per kg of production.

Carbon footprint (CF) – kg CO₂e per ton of production (inputs, energy, soil N₂O).

Land productivity (PROD) – t/ha.

Net income (INC) – €/ha (revenues – costs).

Then they do:

Normalization (Juwana et al. 2012): “positive” vs “negative” indicators.

CRITIC weights (CRiteria Importance Through Intercriteria Correlation) (Diakoulaki et al. 1995).

WEFENI (WEFE Nexus index) = weighted sum of normalized indicators.
$offtext
* ----------------------------------------------------------------
* WEFE indicators (WF, EF, CF, Productivity, Income) + WEFENI
* ----------------------------------------------------------------

Set ind      "WEFE indicators" / WF, EF, CF, PROD, INC /;
Alias (ind,ind2);

Set ind_pos(ind) "Indicators where higher is better" / PROD, INC /;
Set ind_neg(ind) "Indicators where higher is worse" / WF, EF, CF /;


* Here we treat each year as one “alternative” for the CRITIC–WEFENI calculation. We can later replace year by a scenario or zone set if needed.

Scalar tiny   "Small number to avoid division by zero" /1e-6/
       N_alt  "Number of alternatives (here: years)";

N_alt = CARD(y2);

Parameter
    LandProd_y(y2)      "Total land actually under crop + tree production (ha)"
    ProdCropMass_y(y2)  "Total physical crop output (mass units)"
    ProdAnimalMass_y(y2)"Total physical livestock output"
    ProdTreeMass_y(y2)  "Total physical tree output"
    TotalMass_y(y2)     "Total physical output (all products)"
    NetIncome_y(y2)     "Net income (gross margin) per year (EUR)"
    ;

* Effective land in use (crops + tree production) in each year
LandProd_y(y2) = 0
$ifi %CROP%==on      +  sum((hhold,field,c_tree,age_tree,inten),rep_Area_AF(hhold,field,c_tree,age_tree,inten,y2))
$ifi %ORCHARD%==on      + sum((hhold,crop_activity_endo,crop_preceding,field,inten),repcact(hhold,crop_activity_endo,crop_preceding,field,inten,'area',y2) )
;


TotalMass_y(y2) = sum((hhold,c_product),repProd(hhold,c_product,'Production',y2))/1000;

Parameter
Water_green_m3_y
Water_blue_m3_y
Water_grey_m3_y
Water_total_m3_y
  WF_total_m3_per_t_y   "Farm water footprint intensity (m3/t)"
  WF_green_m3_per_t_y    "Farm green water footprint intensity (m3/t)"
  WF_blue_m3_per_t_y    "Farm blue water footprint intensity (m3/t)"

;



Water_green_m3_y(y2) = rep_greenwater("MCDA",y2);
Water_blue_m3_y(y2) =+rep_bluewater("MCDA",y2);
Water_grey_m3_y(y2) =+rep_greywater("MCDA",y2);
Water_total_m3_y(y2)=Water_green_m3_y(y2) +Water_blue_m3_y(y2) +Water_grey_m3_y(y2);


WF_total_m3_per_t_y(y2) =
  Water_total_m3_y(y2) / max(tiny, TotalMass_y(y2));
  
WF_green_m3_per_t_y(y2) =
  Water_green_m3_y(y2) / max(tiny, TotalMass_y(y2));
  
WF_blue_m3_per_t_y(y2) =
  Water_blue_m3_y(y2) / max(tiny, TotalMass_y(y2));



Parameter
  CF_kgCO2e_ha_y(y2)     "Carbon footprint intensity (kg CO2e/ha)"
;
CF_kgCO2e_ha_y(y2) = sum(hhold,repGHG(hhold,"MCDA","ghg",y2))/max(tiny, LandProd_y(y2));


Parameter
  EF_MJ_per_kg_y(y2)      "Energy footprint intensity (MJ/kg)"
;


EF_MJ_per_kg_y(y2) = sum(hhold,repEnergy(hhold,"MCDA","energy",y2))/max(tiny, TotalMass_y(y2)/1000);


Parameter
  NetIncome_EUR_per_ha_y(y2)   "EUR/ha"
;

NetIncome_EUR_per_ha_y(y2) =
repGM_saved('MCDA',y2)  / max(tiny, LandProd_y(y2));

Parameter PROD_t_per_ha_y(y2);

PROD_t_per_ha_y(y2) =
  TotalMass_y(y2) / max(tiny, LandProd_y(y2));




Parameter
    Ind_Value(ind,y2) "Raw WEFE indicator values (before normalization)"
    ;

* Water footprint intensity: m3 water per ha of productive land (lower is better)     
Ind_Value("WF",y2) =
    WF_total_m3_per_t_y(y2);     

* Energy footprint intensity: MJ per kg of physical output (all products) (lower is better)
Ind_Value("EF",y2) =
    EF_MJ_per_kg_y(y2);       

* Carbon footprint: kg CO2e per ha of productive land (lower is better)
Ind_Value("CF",y2) =
    CF_kgCO2e_ha_y(y2);       

* Land productivity: physical output t per ha (higher is better)
Ind_Value("PROD",y2) =
    PROD_t_per_ha_y(y2);      

* Net income: EUR per ha (higher is better)
Ind_Value("INC",y2)  =
    NetIncome_EUR_per_ha_y(y2);     

Parameter
    Ind_min(ind)   "Minimum value across years"
    Ind_max(ind)   "Maximum value across years"
    Denom(ind)     "Max - Min (with tiny lower bound)"
    Ind_norm(ind,y2) "Normalized indicators in [0,1]"
    ;

Ind_max(ind) = smax(y2, Ind_Value(ind,y2));
Ind_min(ind) = smin(y2, Ind_Value(ind,y2));
Denom(ind)   = max(tiny, Ind_max(ind) - Ind_min(ind));

* Indicators where higher is better (productivity, income)
Ind_norm(ind_pos,y2) =
    ( Ind_Value(ind_pos,y2) - Ind_min(ind_pos) ) / Denom(ind_pos);

* Indicators where higher is worse (footprints)
Ind_norm(ind_neg,y2) =
    ( Ind_max(ind_neg) - Ind_Value(ind_neg,y2) ) / Denom(ind_neg);





Parameter
    Ind_mean(ind)          "Mean of normalized indicator over years"
    Ind_dev(ind,y2)      "Deviation from mean"
    Ind_sigma(ind)         "Standard deviation of normalized indicator"
    Ind_cov(ind,ind2)      "Covariance matrix"
    Ind_corr(ind,ind2)     "Correlation matrix r_ik"
    Ind_conflict(ind)      "Sum_k (1 - r_ik)"
    Ind_C(ind)             "Information content C_i"
    Ind_weight(ind)        "CRITIC weight W_i (sum = 1)"
    ;

* Means of normalized indicators
Ind_mean(ind) = SUM(y2, Ind_norm(ind,y2)) / max(1, N_alt);

* Deviations
Ind_dev(ind,y2) = Ind_norm(ind,y2) - Ind_mean(ind);

* Standard deviations
Ind_sigma(ind) =
    sqrt( SUM(y2, sqr(Ind_dev(ind,y2))) / max(1, N_alt - 1) );

* Covariances
Ind_cov(ind,ind2) =
    SUM(y2, Ind_dev(ind,y2) * Ind_dev(ind2,y2)) / max(1, N_alt - 1);

* Correlation coefficients r_ik
Ind_corr(ind,ind2)$(Ind_sigma(ind) > 0 AND Ind_sigma(ind2) > 0) =
    Ind_cov(ind,ind2) / (Ind_sigma(ind) * Ind_sigma(ind2));

* Perfect self-correlation on the diagonal
Ind_corr(ind,ind) = 1;

* Clip to [-1,1] just in case of rounding issues
Ind_corr(ind,ind2) = max(-1, min(1, Ind_corr(ind,ind2)));

* Conflict measure: sum_k (1 - r_ik)
Ind_conflict(ind) = SUM(ind2, 1 - Ind_corr(ind,ind2));

* Information content C_i = sigma_i * conflict_i
Ind_C(ind) = Ind_sigma(ind) * Ind_conflict(ind);

Scalar C_sum "Sum of all C_i";
C_sum = SUM(ind, Ind_C(ind));

* CRITIC weights W_i
Ind_weight(ind)$C_sum = Ind_C(ind) / C_sum;




Parameter
    WEFENI_y(y2) "WEFE Nexus Index per year"
    WEFENI_mean    "Average WEFE Nexus Index over all years"
    ;

WEFENI_y(y2) =
    SUM(ind, Ind_weight(ind) * Ind_norm(ind,y2)) / SUM(ind, Ind_weight(ind));

WEFENI_mean =
    SUM(y2, WEFENI_y(y2)) / max(1, N_alt);


Parameter
    WEFENI_ClassNum(y2) "1 = Low, 2 = Moderate, 3 = High sustainability";

WEFENI_ClassNum(y2)$ (WEFENI_y(y2) < 0.50) = 1;
WEFENI_ClassNum(y2)$ (WEFENI_y(y2) >= 0.50 AND WEFENI_y(y2) <= 0.75) = 2;
WEFENI_ClassNum(y2)$ (WEFENI_y(y2) > 0.75) = 3;


Parameter
    P_WEFE_Ind_Value(ind,y2) "Raw WEFE indicators (per ha)"
    P_WEFE_Ind_Norm(ind,y2)  "Normalized WEFE indicators"
    P_WEFE_Weight(ind)         "CRITIC weights"
    P_WEFENI_y(y2)           "WEFENI per year"
    P_WEFENI_mean              "Average WEFENI over years";


P_WEFE_Ind_Value(ind,y2) = Ind_Value(ind,y2);
P_WEFE_Ind_Norm(ind,y2)  = Ind_norm(ind,y2);
P_WEFE_Weight(ind)         = Ind_weight(ind);
P_WEFENI_y(y2)           = WEFENI_y(y2);
P_WEFENI_mean              = WEFENI_mean;




display P_WEFENI_mean;

$endIf
**

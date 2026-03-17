


delta1=eps;



solve dahbsim using MINLP maximizing v_npv_tot;
*



$ifi %LIVESTOCK_simplified%==ON V_animals.lo(hhold,type_animal,age,y)= V_animals.L(hhold,type_animal,age,y);
$ifi %LIVESTOCK_simplified%==ON V_animals.up(hhold,type_animal,age,y)= V_animals.L(hhold,type_animal,age,y);
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.lo(hhold,feedc,y)=v_FeedAvailable.L(hhold,feedc,y);
$ifi %LIVESTOCK_simplified%==ON v_FeedAvailable.up(hhold,feedc,y)=v_FeedAvailable.L(hhold,feedc,y);
$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = v_FeedConsumed.L(hhold,feedc,type_animal,y);
$ifi %LIVESTOCK_simplified%==ON v_FeedConsumed.fx(hhold,feedc,type_animal,y) = v_FeedConsumed.L(hhold,feedc,type_animal,y);
$ifi %CROP%==ON V_Crop_Number.lo(y, hhold, crop_activity) = V_Crop_Number.L(y, hhold, crop_activity);
$ifi %CROP%==ON V_Crop_Number.up(y, hhold, crop_activity) = V_Crop_Number.L(y, hhold, crop_activity);



*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 2: EXTRACT AND PROCESS SHADOW VALUES
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*-- Save shadow values from calibration constraints
  PMPdualVal(hhold,crop_activity_endo) = 
      E_AreaConst_UpB.M(hhold,crop_activity_endo,'y01') + 
      E_AreaConst_LoB.M(hhold,crop_activity_endo,'y01');
display PMPdualVal;
  
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 3: CALCULATE PMP COST FUNCTION PARAMETERS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- Initialize PMP parameters
PMPint(hhold,crop_activity_endo) = 0;

*-- Calculate PMP slope parameter (quadratic term)
PMPslope(hhold,crop_activity_endo)$v_Land_C_Agg.L(hhold,crop_activity_endo,'y01') = 
      PMPdualVal(hhold,crop_activity_endo) / 
      (2 * v_Land_C_Agg.L(hhold,crop_activity_endo,'y01'));
    
display PMPslope;

*-- Calculate PMP intercept parameter (linear term)
PMPint(hhold,crop_activity_endo) = 
      PMPdualVal(hhold,crop_activity_endo) - 
      abs(PMPdualVal(hhold,crop_activity_endo));

*-- Recalculate slope with absolute value for stability
  PMPslope(hhold,crop_activity_endo)$v_Land_C_Agg.L(hhold,crop_activity_endo,'y01') = 
      abs(PMPdualVal(hhold,crop_activity_endo) / 
      (2 * v_Land_C_Agg.L(hhold,crop_activity_endo,'y01')));

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 4: SOLVE UNCONSTRAINED PMP-CALIBRATED PROBLEM
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
*$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
*-- Set PMP switch to unconstrained mode
PMPswitch = 2;

*-- Solve the unconstrained PMP-calibrated model
*$ifi %RISK%==off
solve dahbsim using MINLP maximizing v_npv_tot;
*$ifi %RISK%==on  solve dahbsim using MINLP maximizing v_objectif;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 5: Creation of the output of PMP
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*-- Compare PMP solution with base year data
PMPSolnCheck(hhold,crop_activity_endo,'PMPsoln') = 
      v_Land_C_Agg.L(hhold,crop_activity_endo,'y01');
PMPSolnCheck(hhold,crop_activity_endo,'baseData') = 
      sum(field, v0_Land_C(hhold,crop_activity_endo,field));
*-- Compare PMP solution with base year data
PMPSolnCheck(hhold,crop_activity_endo,'PMPsoln') = 
    v_Land_C_agg.L(hhold,crop_activity_endo,'y01');
    
PMPSolnCheck(hhold,crop_activity_endo,'baseData') = 
    sum(field,v0_Land_C(hhold,crop_activity_endo,field));

display PMPSolnCheck;
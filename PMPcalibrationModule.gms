


model BIOPH/
$ifi %BIOPH%==on IRRIGATION_OPTIMIZATION
$ifi %BIOPH%==on NITROGEN_OPTIMIZATION
/;

option minlp = baron;
*solve BIOPH using MINLP maximizing TOTAL_NSTRESS_SUM;
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

*VALUE OF STRESS
*p_KS_avg_annual_fixed(hhold,crop_activity,field,inten,y)*p_nstress_fixed(hhold,crop_activity,field,inten,y)

solve dahbsim using MINLP maximizing v_npv_tot;
*
*

PMPdualVal(hhold,crop_activity_endo,field) = 
    E_AreaConst_UpB.M(hhold,crop_activity_endo,field,'y01') + 
    E_AreaConst_LoB.M(hhold,crop_activity_endo,field,'y01');


*PMPdualVal(hhold,crop_activity_endo,field) = E_AreaConst.M(hhold,crop_activity_endo,field,'y01');
*
***~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*** SECTION 3: CALCULATE PMP COST FUNCTION PARAMETERS
***~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
***-- Initialize PMP parameters
PMPint(hhold,crop_activity_endo,field) = 0;

*-- Calculate PMP slope parameter (quadratic term)
*PMPslope(hhold,crop_activity_endo,field)$v_Land_C.L(hhold,crop_activity_endo,field,'y01') = 
*    PMPdualVal(hhold,crop_activity_endo,field) / 
*    (2 * v_Land_C.L(hhold,crop_activity_endo,field,'y01'));
***    
PMPdualVal(hhold,crop_activity_endo,field) = 
    E_AreaConst_UpB.M(hhold,crop_activity_endo,field,'y01') + 
    E_AreaConst_LoB.M(hhold,crop_activity_endo,field,'y01');

**-- Calculate PMP intercept parameter (linear term)
PMPint(hhold,crop_activity_endo,field) = 
    PMPdualVal(hhold,crop_activity_endo,field) - 
    abs(PMPdualVal(hhold,crop_activity_endo,field));

*-- Recalculate slope with absolute value for stability
PMPslope(hhold,crop_activity_endo,field)$v_Land_C.L(hhold,crop_activity_endo,field,'y01') = 
    abs(PMPdualVal(hhold,crop_activity_endo,field) / 
    (4 * v_Land_C.L(hhold,crop_activity_endo,field,'y01')));
display PMPint
PMPslope;
*
***~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*** SECTION 4: SOLVE UNCONSTRAINED PMP-CALIBRATED PROBLEM
***~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
*$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
**-- Set PMP switch to unconstrained mode
PMPswitch = 2;
*

*
solve dahbsim using MINLP maximizing v_npv_tot;




**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
** SECTION 5: Creation of the output of PMP
**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*
*-- Compare PMP solution with base year data
PMPSolnCheck(hhold,crop_activity_endo,field,'PMPsoln') = 
    v_Land_C.L(hhold,crop_activity_endo,field,'y01');
    
PMPSolnCheck(hhold,crop_activity_endo,field,'baseData') = 
    v0_Land_C(hhold,crop_activity_endo,field);

display PMPSolnCheck;
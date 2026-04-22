*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SiwaPMP - PMP Calibration Module for DAHBSIM
*
* @purpose : Perform PMP calibration for agricultural activities
* @note    : Included file (not standalone executable)
* @date    : 1 April 2016
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 1: SOLVE CONSTRAINED PROBLEM FOR Bioph CALIBRATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
parameter pressureCrop(hhold,crop_activity,field,inten)
;
delta1 =eps;

* Solve the model
solve dahbsim using MINLP maximizing v_npv_tot;



parameter pressureCrop(hhold,crop_activity,field,inten)
;

pressureCrop(hhold,crop_activity,field,inten) =sum(m,v_KS_month.L(hhold,crop_activity,field,inten,m,'y01')) *  v_nstress.L(hhold,crop_activity,field,inten,'y01') ;


calibBioph(hhold,crop_activity,field,inten)=pressureCrop(hhold,crop_activity,field,inten)*ym(crop_activity,field,inten)-sum(NameYield,p_cropCoef(hhold,crop_activity,field,inten,NameYield)));

display calibBioph;


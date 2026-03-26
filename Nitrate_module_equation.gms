*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext
   GAMS file : nitrate_optimization_annual.gms
   @purpose  : Annual nitrogen optimization model
   @author   : Based on water model by Maria Blanco and Sophie Drogue
   @date     : [Current Date]
   @since    : [Current Date]
   @seeAlso  : Water optimization model
   @calledBy :
$offtext
$goto %1
***INITIALISATION OF NITROGEN MODULE
$Label nitrate_init
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*************************************************************************************
* ================================================================
* VARIABLES FOR ANNUAL NITROGEN OPTIMIZATION
* ================================================================
**
* Maximum yield parameter
ym(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"ym");
v_Yld_C_max(hhold,crop_activity_endo,'allp',field,inten) $ (p_cropCoef(hhold,crop_activity_endo,field,inten,'yield')>0) = 
    ym(crop_activity_endo,field,inten);
v_Yld_C_max(hhold,crop_activity_endo,crop_preceding,field,inten) = v_Yld_C_max(hhold,crop_activity_endo,'no_plant',field,inten);
*Initial value of nitrate Nini is given at the begining (month 1, year 1)
p_nini(hhold,field)=p_Nini_raw;
*Initial humus level
p_hini(hhold,field)=p_Hini_raw;
p_Npot(hhold,crop_activity,field,inten)$(K1(crop_activity)<> 0) = v_Yld_C_max(hhold,crop_activity,'allp',field,inten)*K1(crop_activity)
$ifi %BIOPHcalib%==OFF  * p_nitr_calib(crop_activity,inten)
/100;
v_Yld_C_max(hhold,crop_activity_endo,crop_preceding,field,inten)=v_Yld_C_max(hhold,crop_activity_endo,'allp',field,inten);
display p_Npot;
****RESIDUE**** -> variabilize
**The qty of residue is equal to the rate of mulch of straw in 
p_Qres(hhold,ck,field,inten)= sum(a_k(crop_activity_endo,ck),p_cropCoef(hhold,crop_activity_endo,field,inten,'ystraw')*p_cropCoef(hhold,crop_activity_endo,field,inten,'area'))*p_perresmulch(ck);
****COMPOST****
*equation of nitrogen from compost we don't know it so we fix it at 0
*The qty of compost
p_Qcomp(hhold) =p_Qcomp_raw;
*Percentage of dry matter in compost
p_MScomp(hhold)  =p_MScomp_raw;
****ORGANIC****
*Nitrate from organic (Norg is given ?)
*N_org is Nitrate from manure is equal to zero in the 1st year as we consider no animal
p_Norg(hhold) = p_Norg_raw;
p_Ncomp(hhold) = p_Qcomp(hhold)* p_MScomp(hhold) * k3 / (10000 * prof * da * 1000);



$exit

$Label first_sim
Positive Variables
    v_nstress(hhold,crop_activity,field,inten,y)           'Annual nitrogen stress coefficient (0-1)'
    v_nav_begin(hhold,field,inten,crop_activity,y)         'Available N at year beginning (kg/ha)'
    v_nmin(hhold,field,y)              'Mineralized nitrogen'
    v_Nres(hhold,field,y)              'Nitrogen from residues'
    v_nl(hhold,crop_activity,field,inten,y)                'Nitrogen leaching'
    v_nfin(hhold,field,inten,crop_activity,y)              'Final nitrogen (kg/ha)'
    v_hini(hhold,field,y)              'Final humus (kg/ha)'
    v_hfin(hhold,field,y)              'Final humus (kg/ha)'
    v_nav(hhold,field,inten,crop_activity,y)               'Total available nitrogen'
    v_nab(hhold,crop_activity,field,inten,y)               'Nitrogen absorbed by crop'

;




Variables
    TOTAL_NSTRESS_SUM                                    'Sum of all nitrogen stress'
;


* ================================================================
* EQUATIONS FOR ANNUAL NITROGEN OPTIMIZATION
* ================================================================


Equation
    E_N_ANNUAL_INIT(hhold,crop_activity,field,inten,y)     'Initial nitrogen balance'
    E_N_ANNUAL_INIT_SUBSEQUENT(hhold,crop_activity,field,inten,y)
    E_H_ANNUAL_INIT(hhold,field,y)      'Initial Humus quantity'
    E_H_ANNUAL_INIT_SUBSEQUENT(hhold,field,y)
    E_N_MINERALIZATION(hhold,field,y)  'Annual nitrogen mineralization'
    E_NRES_ini(hhold,field,y)
    E_NRES(hhold,field,y)              'Nitrogen from residues calculation'
    E_N_AVAILABLE(hhold,crop_activity,inten,field,y)       'Total available nitrogen'
    E_N_STRESS_CALC(hhold,crop_activity,field,inten,y)     'Nitrogen stress calculation'
    E_N_LEACHING(hhold,crop_activity,field,inten,y)        'Nitrogen leaching'
    E_N_FINAL_BALANCE(hhold,crop_activity,field,inten,y)   'Final nitrogen balance'
    E_H_FINAL_BALANCE(hhold,field,y)   'Final humus balance'
    E_v_nab_choice1(hhold,crop_activity,field,inten,y)
    E_v_nab_choice2(hhold,crop_activity,field,inten,y)
    E_b_choice1
    E_b_choice2
    E_N_OBJECTIVE
;

* Discretization should be big enough and tiny small enough
Scalar tiny / 1e-5 /
discretization /10000000/;

* Binary variable
binary variable
    b_choice(hhold,crop_activity,field,inten,y);
    
***************Initial and Final value***********
* Annual Humus initialization by field by ha
E_H_ANNUAL_INIT(hhold,field,y)..
    v_hini(hhold,field,y) =e=
    p_hini(hhold,field);
* Initial nitrogen balance for first year
E_N_ANNUAL_INIT(hhold,crop_activity_endo,field,inten,y)..
    v_nav_begin(hhold,field,inten,crop_activity_endo,y) =e= 
    p_nini(hhold,field);

E_N_FINAL_BALANCE(hhold,crop_activity_endo,field,inten,y)$(p_landField(hhold,field) > 0)..
    v_nfin(hhold,field,inten,crop_activity_endo,y) =e=      
        (v_nav(hhold,field,inten,crop_activity_endo,y) 
           - v_nab(hhold,crop_activity_endo,field,inten,y))
;



* Final humus balance 
E_H_FINAL_BALANCE(hhold,field,y)..
    v_hfin(hhold,field,y) =e=
    v_hini(hhold,field,y) * (1 - k2(field)) + 
    p_ncomp(hhold);

* Optimization objective (maximize nitrogen use efficiency)
E_N_OBJECTIVE..
    TOTAL_NSTRESS_SUM =e= 
    sum((hhold,crop_activity_endo,field,inten,y), v_nstress(hhold,crop_activity_endo,field,inten,y)) ;
*v_KS_avg_annual(hhold,crop_activity_endo,field,inten,y)
*************NITROGEN COMPONENTS*************
*Mineralization of humus in the field - Coefficient by field or general
E_N_MINERALIZATION(hhold,field,y)..
    v_nmin(hhold,field,y) =e=
    (v_hini(hhold,field,y) * k2(field) * da * 1000 * prof * 10000)/19.5;

*Residue calculation
E_NRES_ini(hhold,field,y)..
    v_Nres(hhold,field,y) =e= (p_Nres_raw $ (p_landField(hhold,field))
    + 
        sum((inten,crop_activity_endo,ck) $ a_k(crop_activity_endo,ck),
            p_Nres(hhold,ck,field,inten) * p_MSres * p_effr(ck)
        )
    ) / (p_landField(hhold,field)+0.00001 $ (not p_landField(hhold,field)))
;

* Nitrogen leaching (10% of fertilizer)
E_N_LEACHING(hhold,crop_activity_endo,field,inten,y)..
    v_nl(hhold,crop_activity_endo,field,inten,y) =e= p_nl_raw * sum(NameNitr,        p_cropcoef(hhold,crop_activity_endo,field,inten,NameNitr));

* Total available nitrogen by area planted
E_N_AVAILABLE(hhold,crop_activity_endo,inten,field,y)..
    v_nav(hhold,field,inten,crop_activity_endo,y) =e=
*Nitrate after the last season
    v_nav_begin(hhold,field,inten,crop_activity_endo,y)
*Mineralisation in the field
    + v_nmin(hhold,field,y)
    + v_Nres(hhold,field,y)    
    + (1-p_nl_raw) *sum(NameNitr,p_cropcoef(hhold,crop_activity_endo,field,inten,NameNitr))
    - v_nl(hhold,crop_activity_endo,field,inten,y)
;

****************Measure of Nitrogen Stress by field********************
* Nitrogen stress coefficient (similar to water stress KS)
E_N_STRESS_CALC(hhold,crop_activity_endo,field,inten,y)$(k1(crop_activity_endo) <> 0 and p_cropCoef(hhold,crop_activity_endo,field,inten,'yield') > 0)..
    v_nstress(hhold,crop_activity_endo,field,inten,y) =e=
    (v_nab(hhold,crop_activity_endo,field,inten,y) / (p_npot(hhold,crop_activity_endo,field,inten)))
;

E_v_nab_choice1(hhold, crop_activity_endo, field, inten, y)..
    v_nab(hhold, crop_activity_endo, field, inten, y) =g= 
    v_nav(hhold, field, inten, crop_activity_endo, y) - 
    (v_nav(hhold, field, inten, crop_activity_endo, y) - 
     p_Npot(hhold, crop_activity_endo, field, inten)) * 
    b_choice(hhold, crop_activity_endo, field, inten, y);

E_v_nab_choice2(hhold, crop_activity_endo, field, inten, y)..
    v_nab(hhold, crop_activity_endo, field, inten, y) =l= 
    v_nav(hhold, field, inten, crop_activity_endo, y) - 
    (v_nav(hhold, field, inten, crop_activity_endo, y) - 
     p_Npot(hhold, crop_activity_endo, field, inten)) * 
    b_choice(hhold, crop_activity_endo, field, inten, y);

E_b_choice1(hhold, crop_activity_endo, field, inten, y)..
    v_nav(hhold, field, inten, crop_activity_endo, y) - 
    p_Npot(hhold, crop_activity_endo, field, inten) =l= 
    discretization * b_choice(hhold, crop_activity_endo, field, inten, y);

E_b_choice2(hhold, crop_activity_endo, field, inten, y)..
    v_nav(hhold, field, inten, crop_activity_endo, y) - 
    p_Npot(hhold, crop_activity_endo, field, inten) =g= 
    -discretization * (1 - b_choice(hhold, crop_activity_endo, field, inten, y));

* ================================================================
* NITROGEN OPTIMIZATION MODEL
* ================================================================

Model NITROGEN_OPTIMIZATION 'Annual nitrogen model'
    /
E_H_ANNUAL_INIT
E_N_ANNUAL_INIT
E_N_FINAL_BALANCE
E_H_FINAL_BALANCE
E_N_OBJECTIVE
E_N_MINERALIZATION
E_NRES_ini
E_N_LEACHING
E_N_AVAILABLE
E_N_STRESS_CALC
E_v_nab_choice1
E_v_nab_choice2
E_b_choice1
E_b_choice2
    /;


Scalar last_year;
display p_Nres;
display p_MSres
p_effr
p_landField
p_Npot;

$exit



$Label resetBIOPH
$onglobal
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* RESET FOR NEXT ITERATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* Update for next iteration for WATER
*Reinitialization parameter water 
p_rain(y,m) = p_meteo(y2,m);
p_swd0(hhold,crop_activity,field,inten) = p_DR_end_fixed(hhold,crop_activity,field,inten,"M12","y01");
p_kc(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"p_kc");
CR(hhold,crop_activity_endo,field,inten) = 0.1;
ET0_month(hhold,crop_activity_endo,field,inten,m,y) =p_et0_raw(y2,m)*days_in_month(m);
RAW(hhold, crop_activity_endo, field, inten, m, y) = 
    (p_factor(crop_activity_endo, field, inten) + 
     0.04 * (5 - p_kc(crop_activity_endo, field, inten) * 
         p_et0_raw(y2,m))) * 
    TAW(hhold, crop_activity_endo, field, inten);
*********************************************************************
*********************************************************************
*********************************************************************

* Update for next iteration for nitrogen
last_year = smax(y, ord(y));
*Important storage of value for the iterative work for nitrate
p_nini(hhold,field) = sum((inten,crop_activity_endo),p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01') * sum(crop_preceding, v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01')/ p_landField(hhold,field)));
p_hini(hhold,field) =p_hfin_fixed(hhold,field,'y01');
*p_Nres_raw represent the residue from initialisation then it is put to 0 value to only consider the residue from previous iteration
p_Nres_raw=0;
p_Nres(hhold,ck,field,inten) = v_residuesmulch.l(hhold,ck,'y01');
$ifi %LIVESTOCK_simplified%==ON    p_Norg(hhold) =min(p_Norg_raw,v_NitrogenOutput_OnFarm.l(hhold,'y01'));
p_Qcomp(hhold) =p_Qcomp_raw;
p_MScomp(hhold)  =p_MScomp_raw;
p_Ncomp(hhold) = p_Qcomp(hhold)* p_MScomp(hhold) * k3 / (10000 * prof * da * 1000);


*Important storage of value for the iterative work for water
last_active_month = smax(m, ord(m));
p_swd0(hhold,crop_activity_endo,field,inten) =
    sum(m$(ord(m) = last_active_month), 
        v_DR_end.l(hhold,crop_activity_endo,field,inten,m,'y01'));
$exit
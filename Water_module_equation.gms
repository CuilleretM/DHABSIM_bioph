*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   GAMS file : sets_global.gms
   @purpose  : Linear biophysical model
   @author   : Maria Blanco and Sophie Drogue <drogue@supagro.inra.fr>
   @date     : 26.01.15
   @since    : January 2015
   @seeAlso  :
   @calledBy :
08-09 correction of crop not possible and of problem in the mapping of p_factor

$offtext
$goto %1
***INITIALISATION OF WATER MODULE
$Label water_init
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$onglobal
*************************************************************************************
* ================================================================
* SETS ET PARAMÈTRES POUR L'OPTIMISATION D'IRRIGATION
* ================================================================
* Paramètres météorologiques mensuels

* Initial soil water depletion equivalent in fao to Dr, i-1 = 1000(qFC - qwp i-1) Zr (87)
p_swd0(hhold,crop_and_tree,field,inten) = 5;
*p_swd0(hhold,c_tree,field,inten) = 5;
display p_swd0;
*Initial rain by month 
p_rain(y,m) = p_meteo('%FstYear%',m);
* Crop coefficient parameters available in FAO and value by crop
*p_kc(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"p_kc")
* - p_water_calib(crop_activity_endo,inten)
*;
p_kc(crop_and_tree,field,inten) =agro(crop_and_tree,inten,"p_kc")
;

* Rate of Evapotranspiration simplified as a year mean value mm/day
*p_et0(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"p_et0");
*p_et0_month(crop_activity_endo,field,inten,m) = p_et0(crop_activity_endo,field,inten);
*Maximum amount of irrigation per month mm
*p_nirr(hhold,crop_activity_endo,field,inten,m) = v0_irrigation(hhold,crop_activity_endo,field,inten,m);


* Initial Capillary Rise value
CR(hhold,crop_and_tree,field,inten) = 0.1;
* Number of day per month
days_in_month(m) = 30;
* Necessity to adjust
*Conversion from daily value to mensual value
ET0_month(hhold,crop_and_tree,field,inten,m,y) = p_et0_raw('%FstYear%',m)*days_in_month(m);

* Calculation of TAW and RAW
*rdm is identified through fao table of maximum root depth (ZR in fao coding) 
p_rdm(crop_and_tree,inten) = agro(crop_and_tree,inten,"p_rdm");
*SWM depends on the type of soil and need to be identified as a difference through qfc and qwp: (q FC - q WP) 
p_swa(crop_and_tree,field,inten) = 1000*p_swm(field) * p_rdm(crop_and_tree,inten);
*Taw/Raw monthly not necessary because it is used just at the end of the month
*Total available water
TAW(hhold,crop_and_tree,field,inten) = p_swa(crop_and_tree,field,inten);
*Value of p available in table Depletion Fraction 2 (for ET = 5 mm/day)
p_factor(crop_and_tree, field, inten) = agro(crop_and_tree,inten,"p_factor");
*Readily available water problem due to multiple period
RAW(hhold,crop_and_tree,field,inten,m,y) =(p_factor(crop_and_tree,field,inten) +
 0.04 * (5 - p_kc(crop_and_tree, field, inten) * 
         p_et0_raw('%FstYear%',m))) * TAW(hhold,crop_and_tree,field,inten);


display RAW;
display TAW;
display ET0_month;
display p_rain;

 
$exit
* ================================================================
* Modeling of irrigation and yield response
* ================================================================

$Label first_sim
scalar BigExcess /1000000/;
scalar BigKs /500/;
scalar tinywater /1e-5/;
binary Variable
    b_KS(hhold,*,field,inten,m,y)
    b_DR_negative(hhold,*,field,inten,m,y) 'Binary variable to indicate if v_DR_calc is negative'
    b_KS_negative(hhold,*,field,inten,m,y)
    b_KS_one(hhold,*,field,inten,m,y)
;
Positive Variables
    v_irrigation_opt(hhold,*,field,inten,m,y) 'Monthly irrigation (mm)'
    v_KS_avg_annual(hhold,*,field,inten,y)        'Annual average value of KS'
;
Variables
    TOTAL_KS_SUM 'Sum of all KS'
    v_balance(hhold,*,field,inten,m,y)
    v_DR_start(hhold,*,field,inten,m,y)       'Water balance at the beginning of the month'
    v_DR_end(hhold,*,field,inten,m,y)         'Water balance at the end of the month'
    v_KS_month(hhold,*,field,inten,m,y)         'Water stress by month KS'
    v_KS_month_balance(hhold,*,field,inten,m,y)  

;


$ifi %BIOPH%==on v_KS_avg_annual.lo(hhold,crop_and_tree,field,inten,y)=0;
$ifi %BIOPH%==on v_KS_avg_annual.up(hhold,crop_and_tree,field,inten,y)=1;
$ifi %BIOPH%==on v_KS_month.lo(hhold,crop_and_tree,field,inten,m,y)  = 0;
$ifi %BIOPH%==on v_KS_month.up(hhold,crop_and_tree,field,inten,m,y)  = 1;


Equation
    E_DR_START_INIT(hhold,*,field,inten,m,y)          'Initial value for root zone depletion for the first month of first year'
    E_DR_EQUAL_NONNEGATIVE
    E_DR_ZERO_WHEN_NEGATIVE
    E_WATER_LIMIT(hhold,*,field,inten,m,y)            'Limits of water'
    E_KS_ANNUAL(hhold,*,field,inten,y)
    E_KS_MONTH_CALC1(hhold,*,field,inten,m,y)
    E_KS_MONTH_CALC2(hhold,*,field,inten,m,y)
    E_KS_MONTH_CALC3(hhold,*,field,inten,m,y)
    E_DR_MONTH_CONTINUITY(hhold,*,field,inten,m,y)
    E_KS_OBJECTIVE                                              'Optimization factor'
    E_BALANCE_DEF
    E_NEGATIVE_INDICATOR
    E_POSITIVE_INDICATOR
    E_KS_MONTH_force_negative
    E_KS_MONTH_force_positive
    E_KS_MONTH_force_negative_one
    E_KS_MONTH_force_positive_one
;
Equation E_DR_negative(hhold,*,field,inten,m,y);
Equation E_DR_positive(hhold,*,field,inten,m,y);

E_BALANCE_DEF(hhold,crop_and_tree,field,inten,m,y)$(ord(m) >= 1)..
    v_balance(hhold,crop_and_tree,field,inten,m,y) =e=
    v_DR_start(hhold,crop_and_tree,field,inten,m,y)
    - p_rain(y,m)
    - v_irrigation_opt(hhold,crop_and_tree,field,inten,m,y)
    - CR(hhold,crop_and_tree,field,inten)
    + ET0_month(hhold,crop_and_tree,field,inten,m,y) * p_kc(crop_and_tree,field,inten);

* Initial value for root zone depletion for the first month of first year
E_DR_START_INIT(hhold,crop_and_tree,field,inten,m,y)$(ord(m) = 1)..
    v_DR_start(hhold,crop_and_tree,field,inten,m,y) =e= 
    p_swd0(hhold,crop_and_tree,field,inten);
* v_balance <0 -> b_DR_negative=0
E_DR_negative(hhold,crop_and_tree,field,inten,m,y)..
    v_balance(hhold,crop_and_tree,field,inten,m,y) =g= -BigExcess * (1 - b_DR_negative(hhold,crop_and_tree,field,inten,m,y));
* v_balance >0 -> b_DR_negative=1
E_DR_positive(hhold,crop_and_tree,field,inten,m,y)..
    v_balance(hhold,crop_and_tree,field,inten,m,y) =l= BigExcess * b_DR_negative(hhold,crop_and_tree,field,inten,m,y);

E_DR_EQUAL_NONNEGATIVE(hhold,crop_and_tree,field,inten,m,y)$(ord(m) >= 1)..
    v_DR_end(hhold,crop_and_tree,field,inten,m,y) =e=  v_balance(hhold,crop_and_tree,field,inten,m,y)*( b_DR_negative(hhold,crop_and_tree,field,inten,m,y));

*
*****************************************************************************************

*****************************************************************************************

* Continuity of water balance between months (same year)
E_DR_MONTH_CONTINUITY(hhold,crop_and_tree,field,inten,m,y)$(ord(m) < card(m))..
    v_DR_start(hhold,crop_and_tree,field,inten,m+1,y) =e= 
    v_DR_end(hhold,crop_and_tree,field,inten,m,y);
* Limits of irrigation water
E_WATER_LIMIT(hhold,crop_and_tree,field,inten,m,y)$(ord(m) >= 1)..
    v_irrigation_opt(hhold,crop_and_tree,field,inten,m,y) =l= 
    v0_max_irrigation(hhold,crop_and_tree,field,inten,m,y)  
;
*****************************************************************************************

*****************************************************************************************
E_KS_MONTH_CALC1(hhold,crop_and_tree,field,inten,m,y)..
v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y) =e= 
        (TAW(hhold,crop_and_tree,field,inten) - v_DR_end(hhold,crop_and_tree,field,inten,m,y))
        / (TAW(hhold,crop_and_tree,field,inten) - RAW(hhold,crop_and_tree,field,inten,m,y))
;
* v_KS_month_balance <0 -> b_KS_negative=0
E_KS_MONTH_force_negative(hhold,crop_and_tree,field,inten,m,y)..
    v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y) =g= -BigExcess * (1 - b_KS_negative(hhold,crop_and_tree,field,inten,m,y));
* v_ks_month_balance >0 -> b_KS_negative=1
E_KS_MONTH_force_positive(hhold,crop_and_tree,field,inten,m,y)..
    v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y) =l= BigExcess * b_KS_negative(hhold,crop_and_tree,field,inten,m,y);


* v_KS_month_balance <1 -> b_KS_one=0
E_KS_MONTH_force_negative_one(hhold,crop_and_tree,field,inten,m,y)..
    v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y)-1 =g= -BigExcess * (1 - b_KS_one(hhold,crop_and_tree,field,inten,m,y));
* v_KS_month_balance >1 -> b_KS_one=1
E_KS_MONTH_force_positive_one(hhold,crop_and_tree,field,inten,m,y)..
    v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y)-1 =l= BigExcess * b_KS_one(hhold,crop_and_tree,field,inten,m,y);


E_KS_MONTH_CALC2(hhold,crop_and_tree,field,inten,m,y)..
    v_KS_month(hhold,crop_and_tree,field,inten,m,y) =e= v_KS_month_balance(hhold,crop_and_tree,field,inten,m,y)*b_KS_negative(hhold,crop_and_tree,field,inten,m,y)*(1-b_KS_one(hhold,crop_and_tree,field,inten,m,y))+b_KS_one(hhold,crop_and_tree,field,inten,m,y)
;

* Annual average KS value
E_KS_ANNUAL(hhold,crop_and_tree,field,inten,y)..
    v_KS_avg_annual(hhold,crop_and_tree,field,inten,y) =e= 
    sum(m$(ord(m) >= 1), v_KS_month(hhold,crop_and_tree,field,inten,m,y))/12
;


E_KS_OBJECTIVE..
    TOTAL_KS_SUM =e=  sum((hhold,crop_and_tree,field,inten,y), v_KS_avg_annual(hhold,crop_and_tree,field,inten,y)) ;
;




* ================================================================
* 
* ================================================================
Model IRRIGATION_OPTIMIZATION 'Water model'
    /
E_KS_MONTH_force_negative
E_KS_MONTH_force_positive
E_DR_START_INIT
E_DR_EQUAL_NONNEGATIVE
E_DR_MONTH_CONTINUITY
E_BALANCE_DEF
E_DR_negative
E_DR_positive
E_KS_ANNUAL
E_KS_MONTH_CALC1
E_KS_MONTH_CALC2
E_KS_OBJECTIVE
E_KS_MONTH_force_positive_one
E_KS_MONTH_force_negative_one
    /;
** =========
$exit











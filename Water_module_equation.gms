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
p_swd0(hhold,crop_activity,field,inten) = 5;
*Initial rain by month 
p_rain(y,m) = p_meteo('%FstYear%',m);
* Crop coefficient parameters available in FAO and value by crop
*p_kc(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"p_kc")
* - p_water_calib(crop_activity_endo,inten)
*;
p_kc(crop_activity_endo,field,inten) =agro(crop_activity_endo,inten,"p_kc")
;

* Rate of Evapotranspiration simplified as a year mean value mm/day
*p_et0(crop_activity_endo,field,inten) = agro(crop_activity_endo,inten,"p_et0");
*p_et0_month(crop_activity_endo,field,inten,m) = p_et0(crop_activity_endo,field,inten);
*Maximum amount of irrigation per month mm
*p_nirr(hhold,crop_activity_endo,field,inten,m) = v0_irrigation(hhold,crop_activity_endo,field,inten,m);


* Initial Capillary Rise value
CR(hhold,crop_activity_endo,field,inten) = 0.1;
* Number of day per month
days_in_month(m) = 30;
* Necessity to adjust
*Conversion from daily value to mensual value
ET0_month(hhold,crop_activity_endo,field,inten,m,y) = p_et0_raw('%FstYear%',m)*days_in_month(m);

* Calculation of TAW and RAW
*rdm is identified through fao table of maximum root depth (ZR in fao coding) 
p_rdm(crop_activity_endo,inten) = agro(crop_activity_endo,inten,"p_rdm");
*SWM depends on the type of soil and need to be identified as a difference through qfc and qwp: (q FC - q WP) 
p_swa(crop_activity_endo,field,inten) = 1000*p_swm(field) * p_rdm(crop_activity_endo,inten);
*Taw/Raw monthly not necessary because it is used just at the end of the month
*Total available water
TAW(hhold,crop_activity_endo,field,inten) = p_swa(crop_activity_endo,field,inten);
*Value of p available in table Depletion Fraction 2 (for ET = 5 mm/day)
p_factor(crop_activity_endo, field, inten) = agro(crop_activity_endo,inten,"p_factor");
*Readily available water problem due to multiple period
RAW(hhold,crop_activity_endo,field,inten,m,y) =(p_factor(crop_activity_endo,field,inten) +
 0.04 * (5 - p_kc(crop_activity_endo, field, inten) * 
         p_et0_raw('%FstYear%',m))) * TAW(hhold,crop_activity_endo,field,inten);


display RAW;
display TAW;
display ET0_month;
display p_rain;

 
$exit
* ================================================================
* Modeling of irrigation and yield response
* ================================================================

$Label first_sim
scalar BigExcess /10000000/;
scalar BigKs /150000/;
scalar tinywater /1e-5/;
binary Variable
    b_KS(hhold,crop_activity,field,inten,m,y)
    b_DR_negative(hhold,crop_activity,field,inten,m,y) 'Binary variable to indicate if v_DR_calc is negative'
;
Positive Variables
    v_irrigation_opt(hhold,crop_activity,field,inten,m,y) 'Monthly irrigation (mm)'
    v_KS_month(hhold,crop_activity,field,inten,m,y)         'Water stress by month KS'
    v_DR_start(hhold,crop_activity,field,inten,m,y)       'Water balance at the beginning of the month'
    v_DR_end(hhold,crop_activity,field,inten,m,y)         'Water balance at the end of the month'
    v_KS_avg_annual(hhold,crop_activity,field,inten,y)        'Annual average value of KS'
;
Variables
    TOTAL_KS_SUM 'Sum of all KS'
;





Equation
    E_DR_START_INIT(hhold,crop_activity,field,inten,m,y)          'Initial value for root zone depletion for the first month of first year'
    E_DR_EQUAL_NONNEGATIVE
    E_DR_ZERO_WHEN_NEGATIVE
    E_WATER_LIMIT(hhold,crop_activity,field,inten,m,y)            'Limits of water'
    E_KS_ANNUAL(hhold,crop_activity,field,inten,y)
    E_KS_MONTH_CALC1(hhold,crop_activity,field,inten,m,y)
    E_KS_MONTH_CALC2(hhold,crop_activity,field,inten,m,y)
    E_KS_MONTH_CALC3(hhold,crop_activity,field,inten,m,y)
    E_DR_MONTH_CONTINUITY(hhold,crop_activity,field,inten,m,y)
    E_KS_OBJECTIVE                                              'Optimization factor'
;



* Initial value for root zone depletion for the first month of first year
E_DR_START_INIT(hhold,crop_activity_endo,field,inten,m,y)$(ord(m) = 1)..
    v_DR_start(hhold,crop_activity_endo,field,inten,m,y) =e= 
    p_swd0(hhold,crop_activity_endo,field,inten);
* Lower bound: 
* If b_DR_negative = 0 (CALC >= 0): v_DR_end >= CALC
* If b_DR_negative = 1 (CALC < 0): constraint is relaxed (v_DR_end >= very negative number)
* Force v_DR_end to equal the calculated value when it's non-negative
E_DR_EQUAL_NONNEGATIVE(hhold,crop_activity_endo,field,inten,m,y)$(ord(m) >= 1)..
    v_DR_end(hhold,crop_activity_endo,field,inten,m,y) =e=
    (v_DR_start(hhold,crop_activity_endo,field,inten,m,y)
     - p_rain(y,m)  
     - v_irrigation_opt(hhold,crop_activity_endo,field,inten,m,y)
     - CR(hhold,crop_activity_endo,field,inten)
     + ET0_month(hhold,crop_activity_endo,field,inten,m,y)  
     * p_kc(crop_activity_endo,field,inten)
    ) * (1 - b_DR_negative(hhold,crop_activity_endo,field,inten,m,y));

* Force v_DR_end to be 0 when the calculated value is negative
E_DR_ZERO_WHEN_NEGATIVE(hhold,crop_activity_endo,field,inten,m,y)$(ord(m) >= 1)..
    v_DR_end(hhold,crop_activity_endo,field,inten,m,y) =l=
    BigExcess * (1 - b_DR_negative(hhold,crop_activity_endo,field,inten,m,y));
*****************************************************************************************

*****************************************************************************************

* Continuity of water balance between months (same year)
E_DR_MONTH_CONTINUITY(hhold,crop_activity_endo,field,inten,m,y)$(ord(m) < card(m))..
    v_DR_start(hhold,crop_activity_endo,field,inten,m+1,y) =e= 
    v_DR_end(hhold,crop_activity_endo,field,inten,m,y);
* Limits of irrigation water
E_WATER_LIMIT(hhold,crop_activity_endo,field,inten,m,y)$(ord(m) >= 1)..
    v_irrigation_opt(hhold,crop_activity_endo,field,inten,m,y) =l= 
    v0_max_irrigation(hhold,crop_activity_endo,field,inten,m,y)  
;

* Annual average KS value
E_KS_ANNUAL(hhold,crop_activity_endo,field,inten,y)..
    v_KS_avg_annual(hhold,crop_activity_endo,field,inten,y) =e= 
    sum(m$(ord(m) >= 1), v_KS_month(hhold,crop_activity_endo,field,inten,m,y))/12
;


E_KS_OBJECTIVE..
    TOTAL_KS_SUM =e= 
    sum((hhold,crop_activity_endo,field,inten,y), v_KS_avg_annual(hhold,crop_activity_endo,field,inten,y)) ;

* KS calculation equations with year index
E_KS_MONTH_CALC1(hhold,crop_activity_endo,field,inten,m,y)..
    v_KS_month(hhold,crop_activity_endo,field,inten,m,y) =l= 
        (TAW(hhold,crop_activity_endo,field,inten) - v_DR_end(hhold,crop_activity_endo,field,inten,m,y))
        / (TAW(hhold,crop_activity_endo,field,inten) - RAW(hhold,crop_activity_endo,field,inten,m,y))
;


E_KS_MONTH_CALC2(hhold,crop_activity_endo,field,inten,m,y)..
    v_KS_month(hhold,crop_activity_endo,field,inten,m,y) =g= 
        (TAW(hhold,crop_activity_endo,field,inten) - v_DR_end(hhold,crop_activity_endo,field,inten,m,y))
        / (TAW(hhold,crop_activity_endo,field,inten) - RAW(hhold,crop_activity_endo,field,inten,m,y))
        - BigKs * (1 - b_KS(hhold,crop_activity_endo,field,inten,m,y))  
;

E_KS_MONTH_CALC3(hhold,crop_activity_endo,field,inten,m,y)..
    v_KS_month(hhold,crop_activity_endo,field,inten,m,y) =g= 
        1 - BigKs * b_KS(hhold,crop_activity_endo,field,inten,m,y)
;




* ================================================================
* I
* ================================================================
Model IRRIGATION_OPTIMIZATION 'Water model'
    /
E_DR_START_INIT
E_DR_EQUAL_NONNEGATIVE
E_DR_ZERO_WHEN_NEGATIVE
E_DR_MONTH_CONTINUITY
E_WATER_LIMIT
E_KS_ANNUAL
E_KS_MONTH_CALC3
E_KS_MONTH_CALC1
E_KS_MONTH_CALC2
E_KS_OBJECTIVE
    /;
** =========
$exit











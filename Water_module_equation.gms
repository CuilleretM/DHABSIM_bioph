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

parameter p_DR_start
        p_DR_end
        p_KS_month
        p_KS_year;
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
p_kc(crop_and_tree,field,inten) =agro(crop_and_tree,inten,"p_kc")
;


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


loop(m,

p_DR_start(hhold,crop_and_tree,field,inten,m,y)$(ord(m) = 1) =    p_swd0(hhold,crop_and_tree,field,inten);

p_DR_end(hhold,crop_and_tree,field,inten,m,y)=
max(0 ,p_DR_start(hhold,crop_and_tree,field,inten,m,y)
    - p_rain(y,m)
    - irrigation_month(hhold,crop_and_tree,inten,m)
    - CR(hhold,crop_and_tree,field,inten)
    + ET0_month(hhold,crop_and_tree,field,inten,m,y) *      p_kc(crop_and_tree,field,inten));

p_DR_start(hhold,crop_and_tree,field,inten,m+1,y) =    p_DR_end(hhold,crop_and_tree,field,inten,m,y);

p_KS_month(hhold,crop_and_tree,field,inten,m,y) = min(1,max(0,
        (TAW(hhold,crop_and_tree,field,inten) - p_DR_end(hhold,crop_and_tree,field,inten,m,y))
        / (TAW(hhold,crop_and_tree,field,inten) - RAW(hhold,crop_and_tree,field,inten,m,y))));
****************
);
p_KS_year(hhold,crop_and_tree,field,inten,y)=sum(m,p_KS_month(hhold,crop_and_tree,field,inten,m,y))/12;

$exit
* ================================================================
* Modeling of irrigation and yield response
* ================================================================

$Label first_sim
loop(m,

p_DR_start(hhold,crop_and_tree,field,inten,m,y)$(ord(m) = 1) =    p_swd0(hhold,crop_and_tree,field,inten);

p_DR_end(hhold,crop_and_tree,field,inten,m,y)=
max(0 ,p_DR_start(hhold,crop_and_tree,field,inten,m,y)
    - p_rain(y,m)
    - irrigation_month(hhold,crop_and_tree,inten,m)
    - CR(hhold,crop_and_tree,field,inten)
    + ET0_month(hhold,crop_and_tree,field,inten,m,y) *      p_kc(crop_and_tree,field,inten));

p_DR_start(hhold,crop_and_tree,field,inten,m+1,y) =    p_DR_end(hhold,crop_and_tree,field,inten,m,y);

p_KS_month(hhold,crop_and_tree,field,inten,m,y) = min(1,max(0,
        (TAW(hhold,crop_and_tree,field,inten) - p_DR_end(hhold,crop_and_tree,field,inten,m,y))
        / (TAW(hhold,crop_and_tree,field,inten) - RAW(hhold,crop_and_tree,field,inten,m,y))));
****************
);
p_KS_year(hhold,crop_and_tree,field,inten,y)=sum(m,p_KS_month(hhold,crop_and_tree,field,inten,m,y))/12;

$exit











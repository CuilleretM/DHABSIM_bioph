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
parameter p_nfin
p_hini
p_nav_begin
p_hfin
p_nmin
p_Nres_tot
p_nl
p_nab(hhold,*,field,inten,y)
p_nav(hhold,field,inten,*,y)
p_npot
p_nstress;
***********************************************************************
**
* Maximum yield parameter
ym(crop_and_tree,field,inten) = agro(crop_and_tree,inten,"ym");
v_Yld_C_max(hhold,crop_activity,'allp',field,inten) $ (p_cropCoef(hhold,crop_activity,field,inten,'yield')>0) = 
    ym(crop_activity,field,inten);
v_Yld_C_max(hhold,crop_activity,crop_preceding,field,inten) = v_Yld_C_max(hhold,crop_activity,'no_plant',field,inten);
*Initial value of nitrate Nini is given at the begining (month 1, year 1)
p_nini(hhold,field)=p_Nini_raw;
*Initial humus level
p_hini(hhold,field)=p_Hini_raw;
$ifi %CROP%==ON  p_Npot(hhold,crop_activity,field,inten)$(K1(crop_activity)<> 0) = v_Yld_C_max(hhold,crop_activity,'allp',field,inten)*K1(crop_activity)
$ifi %BIOPHcalib%==OFF  * p_nitr_calib(crop_and_tree,inten)
$ifi %CROP%==ON /100;
$ifi %ORCHARD%==ON  p_Npot(hhold,c_tree,field,inten)$(K1(c_tree)<> 0) =K1(c_tree)*ym(c_tree,field,inten)/100;
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

*****************************************************
p_nav_begin(hhold,field,inten,crop_and_tree,y) = p_nini(hhold,field);

p_nmin(hhold,field,y) =
    (p_hini(hhold,field) * k2(field) * da * 1000 * prof * 10000)/19.5;

p_Nres_tot(hhold,field,y)$(p_landField(hhold,field) > 0)=(p_Nres_raw     + sum((inten,crop_activity_endo,ck) $ a_k(crop_activity_endo,ck),            p_Nres(hhold,ck,field,inten) * p_MSres * p_effr(ck)        ))     / (p_landField(hhold,field))
;
p_nl(hhold,c_tree,field,inten,y)   =p_nl_raw *(0
$ifi %ORCHARD%==ON +sum(NameNitrAF,v0_cropCoef_AF(hhold,c_tree,field,inten,NameNitrAF))
);
p_nl(hhold,crop_activity,field,inten,y) = p_nl_raw * (0
$ifi %CROP%==ON + sum(NameNitr,   p_cropcoef(hhold,crop_activity,field,inten,NameNitr))
);
p_nav(hhold,field,inten,crop_and_tree,y)=
*Nitrate after the last season
    p_nav_begin(hhold,field,inten,crop_and_tree,y)
*Mineralisation in the field
    + p_nmin(hhold,field,y)
    + p_Nres_tot(hhold,field,y)    
    + (1/p_nl_raw) *p_nl(hhold,crop_and_tree,field,inten,y)
    - p_nl(hhold,crop_and_tree,field,inten,y)
;
p_nab(hhold, crop_and_tree, field, inten, y) =min(p_nav(hhold, field, inten, crop_and_tree, y),p_Npot(hhold, crop_and_tree, field, inten));
p_nstress(hhold,crop_and_tree,field,inten,y) =min(1,   (p_nab(hhold,crop_and_tree,field,inten,y) /max (0.00001,p_Npot(hhold,crop_and_tree,field,inten))));
p_nfin(hhold,field,inten,crop_and_tree,y)$(p_landField(hhold,field) > 0) =(p_nav(hhold,field,inten,crop_and_tree,y) - p_nab(hhold,crop_and_tree,field,inten,y))
;
p_hfin(hhold,field,y) = p_hini(hhold,field) * (1 - k2(field)) + 
    p_ncomp(hhold);

$exit

$Label first_sim

p_nav_begin(hhold,field,inten,crop_and_tree,y) = p_nini(hhold,field);

p_nmin(hhold,field,y) =
    (p_hini(hhold,field) * k2(field) * da * 1000 * prof * 10000)/19.5;

p_Nres_tot(hhold,field,y)$(p_landField(hhold,field) > 0)=(p_Nres_raw     + sum((inten,crop_activity_endo,ck) $ a_k(crop_activity_endo,ck),            p_Nres(hhold,ck,field,inten) * p_MSres * p_effr(ck)        ))     / (p_landField(hhold,field))
;


p_nl(hhold,c_tree,field,inten,y)   =p_nl_raw *(0
$ifi %ORCHARD%==ON +sum(NameNitrAF,v0_cropCoef_AF(hhold,c_tree,field,inten,NameNitrAF))
);
p_nl(hhold,crop_activity,field,inten,y) = p_nl_raw * (0
$ifi %CROP%==ON + sum(NameNitr,   p_cropcoef(hhold,crop_activity,field,inten,NameNitr))
);
p_nav(hhold,field,inten,crop_and_tree,y)=
*Nitrate after the last season
    p_nav_begin(hhold,field,inten,crop_and_tree,y)
*Mineralisation in the field
    + p_nmin(hhold,field,y)
    + p_Nres_tot(hhold,field,y)    
    + (1/p_nl_raw) *p_nl(hhold,crop_and_tree,field,inten,y)
    - p_nl(hhold,crop_and_tree,field,inten,y)
;
p_nab(hhold, crop_and_tree, field, inten, y) =min(p_nav(hhold, field, inten, crop_and_tree, y),p_Npot(hhold, crop_and_tree, field, inten));
p_nstress(hhold,crop_and_tree,field,inten,y) =min(1,   (p_nab(hhold,crop_and_tree,field,inten,y) /max (0.00001,p_Npot(hhold,crop_and_tree,field,inten))));
p_nfin(hhold,field,inten,crop_and_tree,y)$(p_landField(hhold,field) > 0) =(p_nav(hhold,field,inten,crop_and_tree,y) - p_nab(hhold,crop_and_tree,field,inten,y))
;
p_hfin(hhold,field,y) = p_hini(hhold,field) * (1 - k2(field)) + 
    p_ncomp(hhold);

$exit


$Label resetBIOPH
$onglobal
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* RESET FOR NEXT ITERATION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* Update for next iteration for WATER
*Reinitialization parameter water 
p_rain(y,m) = p_meteo(y2,m);

p_swd0(hhold,crop_and_tree,field,inten) = p_DR_end_fixed(hhold,crop_and_tree,field,inten,"M12","y01");
p_kc(crop_and_tree,field,inten) = agro(crop_and_tree,inten,"p_kc");
CR(hhold,crop_and_tree,field,inten) = 0.1;
ET0_month(hhold,crop_and_tree,field,inten,m,y) =p_et0_raw(y2,m)*days_in_month(m);
RAW(hhold, crop_and_tree, field, inten, m, y) = 
    (p_factor(crop_and_tree, field, inten) + 
     0.04 * (5 - p_kc(crop_and_tree, field, inten) * 
         p_et0_raw(y2,m))) * 
    TAW(hhold, crop_and_tree, field, inten);
*********************************************************************
*********************************************************************
*********************************************************************

* Update for next iteration for nitrogen
*last_year = smax(y, ord(y));

display p_nfin_fixed ;
*
p_nini(hhold,field)$((0
$ifi %CROP%==ON +p_landField(hhold,field)
$ifi %ORCHARD%==ON + p_field_AF(hhold,field)
)> 0) = 

        (0
$ifi %CROP%==ON    +     sum((inten,crop_activity_endo),               p_nfin_fixed(hhold,field,inten,crop_activity_endo,'y01')$ (p_landField(hhold,field) > 0)* sum(crop_preceding,v_plant_c.l(hhold,crop_activity_endo,crop_preceding,field,inten,'y01'))$ (p_landField(hhold,field) > 0))
        
$ifi %ORCHARD%==ON           +sum((inten,c_tree), p_nfin_fixed(hhold,field,inten,c_tree,'y01')$(p_field_AF(hhold,field) > 0) * sum(age_tree,V_Area_AF.l(hhold,field,c_tree,age_tree,inten,'y01'))$ (p_field_AF(hhold,field) > 0) )
        )
        /
        ( 0
$ifi %CROP%==ON            + p_landField(hhold,field)
$ifi %ORCHARD%==ON         + p_field_AF(hhold,field)
        )

;

display p_nini;

p_hini(hhold,field) =p_hfin_fixed(hhold,field,'y01');
*p_Nres_raw represent the residue from initialisation then it is put to 0 value to only consider the residue from previous iteration
p_Nres_raw=0;
p_Nres(hhold,ck,field,inten) =
0
$ifi %CROP%==on +v_residuesmulch.l(hhold,ck,'y01')
;
$ifi %LIVESTOCK_simplified%==ON    p_Norg(hhold) =min(p_Norg_raw,v_NitrogenOutput_OnFarm.l(hhold,'y01'))
;
p_Qcomp(hhold) =p_Qcomp_raw;
p_MScomp(hhold)  =p_MScomp_raw;
p_Ncomp(hhold) = p_Qcomp(hhold)* p_MScomp(hhold) * k3 / (10000 * prof * da * 1000);


*Important storage of value for the iterative work for water
last_active_month = smax(m, ord(m));
p_swd0(hhold,crop_and_tree,field,inten) =
    sum(m$(ord(m) = last_active_month), 
        p_DR_end(hhold,crop_and_tree,field,inten,m,'y01'));
        


$exit
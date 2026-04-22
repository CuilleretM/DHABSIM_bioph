*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : crop_module.gms
   @purpose  : Define crop module
   @author   : Maria Blanco/ Sophie Drogue /Mathieu Cuilleret
   @date     : 11.07.2025
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy : gen_baseline.gms, simulation_model.gms

$offtext
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$onglobal

 v_Use_Land_C.up(hhold,field,y) = v0_Use_Land_C(hhold,field);
v_Land_C.fx(hhold,crop_activity_endo,field,y)$(not hhold_crop_map(hhold,crop_activity_endo)) = 0;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1. EQUATION DECLARATIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
equations
*-- Land balance constraints
    E_CLANDBALANCE        'Total cropland cannot exceed available land'
    E_LandC               'Cropland allocation to different crops'
   
*-- Labor constraints
    E_Labor_C             'Labor use by month for crop activities'
    
*-- Rotation and area constraints
    E_CROPAREA_EN         'Calculation of crop area for endogenous crops'
    E_CROPAREA_EN_AGG     'Aggregation of crop area across soil types (SiwaPMP addition)'
    E_ROTATION            'Crop rotation constraint'
    
*-- Crop production equations
    E_CACTPRD_EN          'Crop activity production calculation'
    E_CACTYLD_EN          'Crop yield calculation'
    E_CROPPRD_c_product   'Main crop production calculation'
    E_CROPPRD_CK          'Co-product (e.g., straw) production calculation'
    
*-- Input use equations
    E_INPUTUSE_EN         'Input use calculation'
*    E_SEEDUSE             'Seed use calculation'
    E_INPUTUSE_constraint
    
*-- Residue management equations
    E_residues            'Total residue balance (feed/sales/mulch)'
    E_residuesmulch       'Allocation of residues for mulch'
    E_residuesfeed        'Allocation of residues for livestock feed'
    E_residuessell        'Allocation of residues for sales'
    
*-- Economic equations
    E_AnnualGM_C          'Gross margin from crop activities'
    E_VarCost_C           'Variable costs of crop production'
    E_Revenue_C           'Revenue from crop sales'
    
*-- Seed and product balance equations
    E_SEEDBALANCE         'Seed balance for endogenous crops'
    E_SEEDBALANCE_1       'Seed balance for first period'
    E_SBALANCE_c_product  'Production balance for vegetal products'
    E_CROPAREA_EN2
    
;
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2. EQUATION DEFINITIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*




*-- Land Constraints ---------------------------------------------------------

* Total cropland use cannot exceed available land
E_CLANDBALANCE(hhold,field,y)..   v_Use_Land_C(hhold,field,y) =L= v0_Use_Land_C(hhold,field)  ;
* Cropland allocation to different crops
E_LandC(hhold,field,y).. v_Use_Land_C(hhold,field,y)  =E= sum(crop_activity_endo, v_Land_C(hhold,crop_activity_endo,field,y))
;

*-- Labor Constraints --------------------------------------------------------
* Labor use by month for crop activities

E_Labor_C(hhold,y,m).. V_FamLabor_C(hhold,y,m)+V_HLabor_C(hhold,y,m) =E=
  sum((crop_activity_endo,crop_preceding,field,inten)$c_c(crop_activity_endo,crop_preceding), V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y)*p_laborReq(hhold,crop_activity_endo,inten,m))
;

*-- Rotation and Area Constraints --------------------------------------------
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~aggregation of area across soil types~~~~~~~~~~~~~~~~~~~*
E_CROPAREA_EN_AGG(hhold,crop_activity_endo,y).. v_Land_C_Agg(hhold,crop_activity_endo,y) =E= sum(field, v_Land_C(hhold,crop_activity_endo,field,y));
*~~~~~~~~~~~~~~~~ rotation constraints  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- endogenous crop activities => crop area equals sum over ca-cp areas (Stock current activity?)
E_CROPAREA_EN(hhold,crop_activity_endo,field,y)..   v_Land_C(hhold,crop_activity_endo,field,y) =e=sum((c_c(crop_activity_endo,crop_preceding),inten), V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) ) ;

*correction not in rotation
E_CROPAREA_EN2(hhold,crop_activity_endo,field,y)..   v_Land_C(hhold,crop_activity_endo,field,y) =e=sum((inten,crop_preceding), V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) ) ;

*-- preceding-crop area this year cannot surpass area allocated to this crop last year
E_ROTATION(hhold,crop_preceding,field,y).. sum((c_c(crop_activity_endo,crop_preceding),inten),V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y)) =L=
  v_Land_C(hhold,crop_preceding,field,y-1) + v0_Land_C(hhold,crop_preceding,field)$(y.pos eq 1);
*~~~~~~~~~~~~~~~~ crop activity production ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- endogenous crop activities => both area and yield change over time
*links with the new continuous bioph model
E_CACTYLD_EN(hhold,crop_activity_endo,crop_preceding,field,inten,y).. v_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) =E=
$ifi %BIOPH%==OFF v0_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten)
$ifi %BIOPH%==ON + v_KS_avg_annual(hhold,crop_activity_endo,field,inten,y)*v_nstress(hhold,crop_activity_endo,field,inten,y) *v0_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten)
;

*21-04
E_CACTPRD_EN(hhold,crop_activity_endo,field,inten,y).. v_Prd_C(hhold,crop_activity_endo,field,inten,y) =E=
  sum(c_c(crop_activity_endo,crop_preceding), V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y)*
$ifi %BIOPH%==OFF v0_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten)
$ifi %BIOPH%==ON v_KS_avg_annual(hhold,crop_activity_endo,field,inten,y)*v_nstress(hhold,crop_activity_endo,field,inten,y) *v0_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten)


*$ifi %BIOPH%==ON v0_Yld_C_stress(hhold,crop_activity_endo,crop_preceding,field,inten)
*20-04 NLP to MIP
*v_Yld_C(hhold,crop_activity_endo,crop_preceding,field,inten,y))
);

*-- Crop Production Equations ------------------------------------------------
*-- main production by activity
E_CROPPRD_c_product(hhold,c_product_endo,y).. v_prodQuant(hhold,c_product_endo,y) =E= (1-p_crop_loss(hhold,c_product_endo))*
sum((a_j(crop_activity_endo,c_product_endo),field,inten), v_Prd_C(hhold,crop_activity_endo,field,inten,y)) ;
*-- co-product (for crops is straw)

E_CROPPRD_CK(hhold,cken,y).. 
    v_prodQuant(hhold,cken,y) =E=
    sum((a_k(crop_activity_endo,cken), crop_preceding, field, inten, NameStraw)$
        c_c(crop_activity_endo,crop_preceding), 
        V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y)
        * p_cropcoef(hhold,crop_activity_endo,field,inten,NameStraw)
    );
 
*-- Residue Management Equations ---------------------------------------------
*straw balance (the qty of straw produced is balanced between feed/sales/mulch)
E_residues(hhold,cken,y)..
v_residuesfeed(hhold,cken,y)+v_residuessell(hhold,cken,y)+v_residuesmulch(hhold,cken,y)
*$ifi %BIOPH%==on + sum((field,inten),v_qres(hhold,cken ,field,inten,y))
=e=
v_prodQuant(hhold,cken,y);
*feed
E_residuesfeed(hhold,cken,y)..v_residuesfeed(hhold,cken,y)=e=
sum(m,v_residuesfeedm(hhold,cken,y,m));
*sales
E_residuessell(hhold,cken,y)..v_residuessell(hhold,cken,y)=e=
sum(m,v_residuessellm(hhold,cken,y,m));
*mulch
E_residuesmulch(hhold,cken,y)..v_residuesmulch(hhold,cken,y)=e=
v_prodQuant(hhold,cken,y)*p_perresmulch(cken);

*-- Input Use Equations -----------------------------------------------------

* Input use calculation
E_INPUTUSE_EN(hhold,crop_activity_endo,i,y).. 
    V_Use_Input_C(hhold,crop_activity_endo,i,y) =E=
    sum((c_c(crop_activity_endo,crop_preceding),field,inten), 
        V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y)*p_cropcoef(hhold,crop_activity_endo,field,inten,i));

*20-04 constraint on the input_use if valuechain off
E_INPUTUSE_constraint(hhold,i,y).. 
   sum(crop_activity_endo, V_Use_Input_C(hhold,crop_activity_endo,i,y)) 
   =L= 
$ifi %VALUECHAIN%==OFF sum((crop_activity_endo,field,inten), p_cropcoef(hhold,crop_activity_endo,field,inten,i) * V0_Plant_C(hhold,crop_activity_endo,'allp',field,inten))
$ifi %VALUECHAIN%==ON 9999999999
;




*-- Economic Equations ------------------------------------------------------

* Annual gross margin from crop activities
E_AnnualGM_C(hhold,y).. 
    V_annualGM_C(hhold,y) =E= 
    V_Sale_C(hhold,y) - V_VarCost_C(hhold,y)
$ifi %VALUECHAIN%==ON - v_transportCost_crop(hhold,y)
    - sum(m, V_HLabor_C(hhold,y,m))*sum(NameLabor,p_buyPrice(hhold,NameLabor));

* Revenue from crop sales
E_Revenue_C(hhold,y)..
    V_Sale_C(hhold,y) =E=
    sum((c_product), 
        (v_selfCons(hhold,c_product,y))$sum(gd, output_good(c_product,gd)) * p_selPrice(hhold,c_product)
    )
$ifi %VALUECHAIN%==OFF + sum(c_product, v_markSales(hhold,c_product,y)*p_selPrice(hhold,c_product))
$ifi %VALUECHAIN%==ON + sum((c_product,buyer), v_outputBuyer(hhold,c_product,buyer,y)*p_price_buyer(c_product,buyer));
;
* Variable costs of crop production
E_VarCost_C(hhold,y).. 
    V_VarCost_C(hhold,y) =E=
    sum((crop_activity_endo,inpv), V_Use_Input_C(hhold,crop_activity_endo,inpv,y))
* Seed cost
$ifi %VALUECHAIN%==ON + sum((crop_activity_endo,seeder), v_seedSeeder(hhold,crop_activity_endo,seeder,y)*p_price_seeder(crop_activity_endo,seeder))
$ifi %VALUECHAIN%==OFF + sum(crop_activity_endo, v_seedPurch(hhold,crop_activity_endo,y)*p_seedbuyPri(hhold,crop_activity_endo))
* Nitrogen cost
*if valuechain on then the price is going through the market and the valuechain module
$ifi %VALUECHAIN%==ON + sum((inpq,seller_C), v_inputSeller_C(hhold,inpq,seller_C,y)*p_price_seller(inpq,seller_C))



*if valuechain off then the price is just depending on the quantity bought
$ifi %VALUECHAIN%==OFF + (sum(crop_activity_endo, V_Use_Input_C(hhold,crop_activity_endo,'nitr',y))
*$ifi %VALUECHAIN%==OFF $ifi %BIOPH%==ON $ifi %LIVESTOCK_simplified%==ON
-v_norg_crop(hhold)
*$ifi %VALUECHAIN%==OFF $ifi %BIOPH%==ON
-v_ncomp_crop(hhold)
$ifi %VALUECHAIN%==OFF )*sum(NameNitr,p_buyPrice(hhold,NameNitr))



  

* Irrigation cost
$ifi %BIOPH%==ON + v_costirr_crop(hhold,y);
;
*-- Seed and Product Balance Equations ---------------------------------------

* Vegetal product balance (production = seed + feed + consumption + sales)
E_SBALANCE_c_product(hhold,c_product_endo,y)..  
    v_prodQuant(hhold,c_product_endo,y)*(1-p_farm_loss(c_product_endo)) =E=
    sum(a_j(crop_activity_endo,c_product_endo), v_seedOnfarm(hhold,crop_activity_endo,y)) +
    v_feedOnfarm(hhold,c_product_endo,y) + 
    v_selfCons(hhold,c_product_endo,y)$sum(gd, output_good(c_product_endo,gd)) + 
    v_markSales(hhold,c_product_endo,y);

E_SEEDBALANCE(hhold, crop_activity_endo, y) ..
    sum(NameSeed, V_Use_Input_C(hhold,crop_activity_endo,NameSeed,y)) =E=
* For first period: only purchased seeds
    (v_seedPurch(hhold, crop_activity_endo, y))$(y.pos eq 1)
* For subsequent periods: on-farm seeds from previous year + purchased seeds
    + (v_seedonfarm(hhold, crop_activity_endo, y-1) 
       + v_seedPurch(hhold, crop_activity_endo, y))$(y.pos gt 1);







*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #4 Module definiton
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*30-01 change land to not have crop that is not linked with the hhold

model cropMod 'crop module'
/
e_cLandBalance
E_LandC
E_Labor_C
e_cropArea_en
e_rotation
e_cactPrd_en
e_cactYld_en
e_cropPrd_c_product
e_cropPrd_ck
e_residues
e_residuesmulch
e_residuesfeed
e_residuessell
e_inputUse_en
E_INPUTUSE_constraint
*e_seedUse
** (SiwaPMP) added this eqn to model definition ***
E_CROPAREA_EN_AGG
E_AnnualGM_C
E_VarCost_C
E_Revenue_C
*E_SEEDBALANCE_1
E_seedbalance
e_sBalance_c_product
*eq_total_land
*eq_proportion
*eq_shannon
*E_yld_obj
E_CROPAREA_EN2
/
;






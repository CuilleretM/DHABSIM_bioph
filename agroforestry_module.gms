$ontext
   DAHBSIM model - Agroforestry Module

   GAMS file : Agroforestry_module.gms
   @author   : Mathieu Cuilleret
   @date     : 11/07/25
   @since    : 0.1
   @refDoc   :
   @seeAlso  :
   @calledBy : farm_module.gms
   08-09 Necessity to add one extra year to the possible age to consider the possibility of death of the trees
$offtext

*==============================================================================
* #1 INITIALIZATION AND CONSTRAINTS
*==============================================================================

* Fix self-consumption to zero for tree crops that are not output goods
v_selfCons.fx(hhold,c_treej,y)$[not sum(gd, output_good(c_treej,gd))] = 0;  

*==============================================================================
* #2 EQUATION DECLARATIONS
*==============================================================================

Equation
* Land allocation constraints
    E_LandAF(hhold,field,inten,y)          'Total orchard area cannot exceed available area'
    E_TreeSequencing(hhold,field,c_tree,age_tree,inten,y) 'Age progression of trees by field'
    E_PLANTING_AF(hhold,field,inten,age_tree,y) 'Planting area constraint'
    
* Production constraints
    E_CROPPRD_AF(hhold,c_tree,y)           'Activity production per tree crop'
    E_CROPPRD_AF_C_TREEJ                   'Output production per tree crop'
    E_SBALANCE_c_tree                      'Production balance between sales and self-consumption'
    
* Economic constraints
    E_VarCost_AF(hhold,y)                  'Orchard variable costs calculation'
    E_Revenue_AF(hhold,y)                  'Orchard revenue calculation'
    E_AnnualGM_AF(hhold,y)                 'Total annual gross margin calculation'
    
* Resource balance constraints
    E_Labor_AF(hhold,y,m)                  'Labor requirement balance'
    E_Fertilizer_Balance_AF(hhold, c_tree,y)       'Fertilizer usage balance'
    E_Phyto_Balance_AF(hhold,y)            'Phytosanitary products balance'
    E_Other_Balance_AF(hhold,y)            'Other inputs balance'
    E_PlantsNB_Balance_AF(hhold,c_tree,y)         'Plant number balance'
;



*============================================================================*
* #3 EQUATION DEFINITIONS
*============================================================================*

* Production balance between different tree crop outputs
E_CROPPRD_AF_C_TREEJ(hhold,c_treej,y)..
    v_prodQuant(hhold,c_treej,y) =E= 
    sum(a_c_treej(c_tree,c_treej), v_Prd_AF(hhold,c_tree,y));

* Fertilizer usage calculation
E_Fertilizer_Balance_AF(hhold, c_tree,y)..
    V_Nfert_AF(hhold, c_tree,y) =e= 
    sum((field, inten), 
        sum(age_tree, V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) *  
        sum(NameNitrAF,v0_cropCoef_AF(hhold,c_tree,field,inten,NameNitrAF))
    );

* Phytosanitary products calculation
E_Phyto_Balance_AF(hhold,y)..
    V_Phyto_AF(hhold,y) =e= 
    sum((field, c_tree, inten),
        sum(age_tree, V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) *
        v0costPhyto_AF(hhold,c_tree,field,inten)
    );

* Other input costs calculation
E_Other_Balance_AF(hhold,y)..
    V_other_AF(hhold,y) =e= 
    sum((field, c_tree, inten),
        sum(age_tree, V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) *
        v0costOther_AF(hhold,c_tree,field,inten)
    );

* Plant number calculation
E_PlantsNB_Balance_AF(hhold,c_tree,y)..
    V_PlantsNB_AF(hhold,c_tree,y) =e= 
    sum((field,  inten),
        sum(age_tree, V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) *
        sum(NamePlantsAF,v0_cropCoef_AF(hhold,c_tree,field,inten,NamePlantsAF)))
    ;

* Labor requirement calculation
E_Labor_AF(hhold,y,m)..
    V_FamLabor_AF(hhold,y,m) + V_HLabor_AF(hhold,y,m) =e= 
    sum((inten,c_tree),
        sum((field,age_tree), V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) *
        p_laborReq_AF(hhold,c_tree,inten,m)
    );

* Planting area constraint (for years after the first)
E_PLANTING_AF(hhold,field,inten,age_tree,y)$(ord(y) > 1)..
    sum(c_tree, V_Area_AF(hhold,field,c_tree,age_tree,inten,y)$(ord(age_tree) = 1)) =l= 
    sum((c_tree),V0_Area_AF(hhold,field,c_tree,age_tree,inten))+0.0001;
    
* Total land allocation constraint
E_LandAF(hhold,field,inten,y)..
    sum((age_tree,c_tree), V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) =l=
    sum((c_tree,age_tree),V0_Area_AF(hhold,field,c_tree,age_tree,inten));

* Tree age progression logic
E_TreeSequencing(hhold,field,c_tree,age_tree,inten,y)..
    V_Area_AF(hhold,field,c_tree,age_tree,inten,y) =e=
* Initial condition for first year
        (V0_Area_AF(hhold,field,c_tree,age_tree,inten))$(ord(y) = 1)
* Age progression for subsequent years
        + V_Area_AF(hhold,field,c_tree,age_tree-1,inten,y-1)$(ord(y) > 1 and ord(age_tree) > 1 and ord(age_tree) <= life_tree(c_tree))
* New plantings
        + V_Area_AF(hhold,field,c_tree,age_tree,inten,y)$(ord(y) > 1 and ord(age_tree) = 1);



* Tree crop production calculation by age class
E_CROPPRD_AF(hhold,c_tree,y)..
    v_Prd_AF(hhold,c_tree,y) =e=
        sum((field, inten),
* Young trees production
            sum(NameYoung,v0_Yld_C_tree(field, c_tree, NameYoung)) * 
            sum(age_tree$(ord(age_tree) < harvestingAge_tree(c_tree)), 
                V_Area_AF(hhold, field, c_tree,age_tree, inten, y)) +
* Adult trees production
            sum(NameAdult,v0_Yld_C_tree(field, c_tree, NameAdult)) * 
            sum(age_tree$(ord(age_tree) >= harvestingAge_tree(c_tree) and ord(age_tree) < oldAge_tree(c_tree)), 
                V_Area_AF(hhold, field, c_tree,age_tree, inten, y)) +
* Old trees production
            sum(NameOld,v0_Yld_C_tree(field, c_tree, NameOld)) * 
            sum(age_tree$(ord(age_tree) >= oldAge_tree(c_tree)), 
                V_Area_AF(hhold, field, c_tree,age_tree, inten, y))
        );

* Variable costs calculation

*task_tree


*08-09 correction of missing cost
E_VarCost_AF(hhold,y)..
    V_VarCost_AF(hhold,y) =e= 
* Labor costs for different operations
    (sum((c_tree, field, inten),
        sum(NamePlantingAF,p_taskLabor_cost(c_tree,NamePlantingAF))
        * sum(age_tree$(ord(age_tree) = 1), 
            V_Area_AF(hhold, field, c_tree,age_tree, inten, y))
        + sum(NameHarvestAF,p_taskLabor_cost(c_tree,NameHarvestAF))
        * sum(age_tree$(ord(age_tree) >= harvestingAge_tree(c_tree)), 
            V_Area_AF(hhold, field,c_tree, age_tree, inten, y))
        + (
        sum(NamePesticideAF,p_taskLabor_cost(c_tree,NamePesticideAF))
        + sum(NameWeedingAF,p_taskLabor_cost(c_tree,NameWeedingAF)) 
           + sum(NamePruningAF,p_taskLabor_cost(c_tree,NamePruningAF))
           + sum(NameOrg_fertAF,p_taskLabor_cost(c_tree,NameOrg_fertAF)) 
           + sum(NameChe_fertAF,p_taskLabor_cost(c_tree,NameChe_fertAF)))
            * sum(age_tree, V_Area_AF(hhold, field, c_tree, age_tree, inten, y)) 
        + sum(NameGrubbAF,p_taskLabor_cost(c_tree,NameGrubbAF))
        * sum(age_tree$(ord(age_tree) = life_tree(c_tree)), 
            V_Area_AF(hhold, field, c_tree, age_tree, inten, y))
    ))

* Input costs (conditional on value chain setting)
$ifi %VALUECHAIN%==OFF + sum(c_tree, (V_Nfert_AF(hhold,c_tree,y)*sum(NameNitrPrice,p_buyPrice_tree(NameNitrPrice,c_tree))))
$ifi %VALUECHAIN%==OFF +sum(c_tree, (V_PlantsNB_AF(hhold,c_tree,y)*sum(NamePlantsPrice,p_buyPrice_tree(NamePlantsPrice,c_tree))))
$ifi %VALUECHAIN%==on  + sum(seller_AF, sum(NameNitr,v_inputSeller_AF(hhold,NameNitr,seller_AF,y)*p_price_seller(NameNitr,seller_AF)))
$ifi %VALUECHAIN%==on + sum(seller_AF, sum(NamePlantsNb,v_inputSeller_AF(hhold,NamePlantsNb,seller_AF,y)*p_price_seller(NamePlantsNb,seller_AF)))
    + V_other_AF(hhold,y) + V_Phyto_AF(hhold,y);

* Annual gross margin calculation
E_AnnualGM_AF(hhold,y)..
    V_annualGM_AF(hhold,y) =e= 
    V_Sale_AF(hhold,y) - V_VarCost_AF(hhold,y)
    - sum(m, V_HLabor_AF(hhold,y,m)) * sum(NameLabor,p_buyPrice(hhold,NameLabor))
$ifi %VALUECHAIN%==ON - v_transportCost_orchard(hhold,y);
;

* Revenue calculation
E_Revenue_AF(hhold,y)..
    V_Sale_AF(hhold,y) =e=
    sum(c_treej, v_selfCons(hhold,c_treej,y)$sum(gd, output_good(c_treej,gd)) * p_selPrice(hhold,c_treej))
$ifi %VALUECHAIN%==ON + sum((buyer,c_treej), v_outputBuyer(hhold,c_treej,buyer,y)*p_price_buyer(c_treej,buyer))
$ifi %VALUECHAIN%==OFF + sum(c_treej, v_markSales(hhold,c_treej,y))
;

* Production balance equation
E_SBALANCE_c_tree(hhold,c_treej,y).. 
    v_prodQuant(hhold,c_treej,y) =E= 
    v_markSales(hhold,c_treej,y) +
    v_selfCons(hhold,c_treej,y)$sum(gd, output_good(c_treej,gd))
    ;

*==============================================================================
* #4 MODEL DEFINITION
*==============================================================================

Model orchard_model /
    E_LandAF
    E_CROPPRD_AF
    E_VarCost_AF
    E_Revenue_AF
    E_AnnualGM_AF
    E_TreeSequencing
    E_PLANTING_AF
    E_Labor_AF
    E_Fertilizer_Balance_AF
    E_Phyto_Balance_AF
    E_Other_Balance_AF
    E_CROPPRD_AF_C_TREEJ
    E_SBALANCE_c_tree
/;
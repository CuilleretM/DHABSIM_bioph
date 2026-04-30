*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* DAHBSIM - Value Chain Module
*
* GAMS file : valuechain_module.gms
* @purpose : Models agricultural value chain transactions including
*            production, transportation, and market interactions
* @author  : [Your Name]
* @date    : [Current Date]
* @since   : v1.0
* @refDoc  : [Reference Documents]
* @seeAlso : [Related Models]
* @calledBy: gen_baseline.gms, run_scenario.gms
*08-09 GHG and correction of previous missing value
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

$onglobal


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 1: EQUATION DECLARATIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

equations
*-- General Value Chain Equations --------------------------------------
    E_output_capacity(inout,buyer,y)      "Buyer capacity constraint"
    E_output_buyer(hhold,inout,y)         "Output balance equation"
    E_labor_buyer(y)                      "Total buyer labor calculation"
    
*-- Crop Module Equations ---------------------------------------------
    E_labor_seller(y)                     "Total seller labor calculation"
    E_TransportCost_C(hhold,y)            "Crop transport cost calculation"
    E_GHG_C(hhold,y)            "Crop GHG calculation"

* Crop Input Seller Equations
    E_input_capacity_nitr_C(inout,seller_C,y)   "Nitrogen seller capacity"
    E_input_seller_C(hhold,inout,y)             "Nitrogen input balance"
    E_input_capacity_phyto_C(inout,seller_C,y)  "Phytosanitary seller capacity"
    E_input_seller_phyto_C(hhold,inout,y)       "Phytosanitary input balance"
    E_input_capacity_other_C(inout,seller_C,y)  "Other inputs seller capacity"
    E_input_seller_other_C(hhold,inout,y)       "Other inputs balance"
    
* Seed Seller Equations
    E_seed_capacity(crop_activity,seeder,y)    "Seed capacity constraint"
    E_seed_seeder(hhold,crop_activity,y)       "Seed balance equation"
    E_transportCost_seeder(hhold,y)            "Seed transport cost"
    E_labor_seeder(y)                          "Seeder labor calculation"
    
*-- Agroforestry Module Equations -------------------------------------
    E_TransportCost_AF(hhold,y)                "Agroforestry transport cost"
    E_GHG_AF(hhold,y)                "Agroforestry GHG"

* Agroforestry Input Seller Equations
    E_input_capacity_nitr_AF(inout,seller_AF,y)  "AF nitrogen seller capacity"
    E_input_seller_AF(hhold,inout,y)             "AF nitrogen input balance"
    E_input_capacity_phyto_AF(inout,seller_AF,y) "AF phytosanitary capacity"
    E_input_seller_phyto_AF(hhold,inout,y)       "AF phytosanitary balance"
    E_input_capacity_other_AF(inout,seller_AF,y) "AF other inputs capacity"
    E_input_seller_other_AF(hhold,inout,y)       "AF other inputs balance"
    E_input_capacity_plants_AF(inout,seller_AF,y) "AF plants capacity"
    E_input_seller_plants_AF(hhold,inout,y)      "AF plants balance"
    E_labor_seller_AF
*-- Livestock Module Equations ----------------------------------------
    E_transportCost_livestock(hhold,y)         "Livestock transport cost"
    E_GHG_livestock(hhold,y)         "Livestock GHG"

* Livestock Input Seller Equations
    E_input_capacity_other_A(hhold,y)          "Livestock other costs capacity"
    E_input_seller_other_A(seller_A,y)         "Livestock other costs balance"
    E_input_capacity_veterinary_A(hhold,y)      "Veterinary costs capacity"
    E_input_seller_veterinary_A(seller_A,y)     "Veterinary costs balance"
    E_input_capacity_addcost_A(hhold,y)         "Additional costs capacity"
    E_input_seller_addcost_A(seller_A,y)        "Additional costs balance"
    E_labor_seller_A(y)                        "Livestock seller labor"
    
* Livestock Seller Equations
    E_Livestock_Seller_capacity(type_animal,Livestock_seller,y) "Livestock capacity"
    E_Livestock_Seller(hhold,type_animal,y)    "Livestock balance"
    E_transportCost_Livestock_Seller(hhold,y)  "Livestock transport cost"
    E_labor_Livestock_Seller(y)                "Livestock seller labor"
    
* Feed Seller Equations
    E_Feed_Seller_capacity(feedc,Feed_Seller,y) "Feed capacity constraint"
    E_Feed_Seller(hhold,feedc,y)               "Feed balance equation"
    E_transportCost_Feed_Seller(hhold,y)       "Feed transport cost"
    E_labor_Feed_Seller(y)                     "Feed seller labor"
*GHG
    E_GHG(hhold,y)         "GHG"
E_Total_ValueChain_Labor
 E_ghg_total
E_Energy(hhold,y) 

;
******************************************************************************************
E_ghg_total ..
    V_GHGtotal =E=
    sum((hhold,y),v_GHG(hhold,y))
;

*E_Total_ValueChain_Labor ..
E_Total_ValueChain_Labor ..
    V_Total_ValueChain_Labor =E=
sum(y,0
$ifi %ORCHARD%==on +v_laborSeller_AF(y)
$ifi %LIVESTOCK_simplified%==on   +v_laborFeed_seller(y)
$ifi %LIVESTOCK_simplified%==on   +v_laborLivestock_seller(y)
$ifi %LIVESTOCK_simplified%==on   +v_laborSeller_A(y)
$ifi %CROP%==on   +v_laborSeeder(y)
$ifi %CROP%==on   +v_laborSellerInput(y)
+v_laborBuyerOutput(y)
)
;

E_Energy(hhold,y) ..
    V_energy(hhold,y) =E= 
$ifi %ORCHARD%==on sum((inten,c_tree,m), sum((field,age_tree), V_Area_AF(hhold,field,c_tree,age_tree,inten,y)) * p_energy_AF(hhold,c_tree,inten,m))+sum((c_tree,inten),enerReqtask_AF(hhold,c_tree,inten,"fertilizer") *             sum((field,age_tree), V_Area_AF(hhold,field,c_tree,age_tree,inten,y) *              sum(NameNitrAF, v0_cropCoef_AF(hhold,c_tree,field,inten,NameNitrAF)))+ enerReqtask_AF(hhold,c_tree,inten,"phytosanitary") *               V_Phyto_AF(hhold,y) + enerReqtask_AF(hhold,c_tree,inten,"plants") * sum((field,age_tree) $ (ord(age_tree) = 1),V_Area_AF(hhold, field, c_tree, age_tree, inten, y))       
$ifi %BIOPH%==on + sum(field, enerReqtask_AF(hhold,c_tree,inten,"irrigation")*sum(m,p_irrigation_opt_fixed(hhold,c_tree,field,inten,m,'y01'))*sum(age_tree,V_Area_AF(hhold, field, c_tree, age_tree, inten, y)))
$ifi %ORCHARD%==on ) 
$ifi %CROP%==on            + sum((crop_activity_endo,crop_preceding,field,inten,m) $ c_c(crop_activity_endo,crop_preceding),            V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) *            p_energy_crop(hhold,crop_activity_endo,inten,m))+ sum((crop_activity_endo,inten),            enerReqtask_crop(hhold,crop_activity_endo,inten,"fertilizer") *             sum((crop_preceding,field) $ c_c(crop_activity_endo,crop_preceding),                 V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) *                sum(NameNitr, p_cropcoef(hhold,crop_activity_endo,field,inten,NameNitr)))) + sum((crop_activity_endo,inten),            enerReqtask_crop(hhold,crop_activity_endo,inten,"phytosanitary") *            sum((crop_preceding,field) $ c_c(crop_activity_endo,crop_preceding),                 V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) *                sum(NamePhyto, p_cropcoef(hhold,crop_activity_endo,field,inten,NamePhyto)))) + sum((crop_activity_endo,inten),            enerReqtask_crop(hhold,crop_activity_endo,inten,"seeds") *            sum((crop_preceding,field) $ c_c(crop_activity_endo,crop_preceding),                 V_Plant_C(hhold,crop_activity_endo,crop_preceding,field,inten,y) *                sum(NameSeed, p_cropcoef(hhold,crop_activity_endo,field,inten,NameSeed))))
$ifi %CROP%==on            + sum((crop_activity_endo,field,inten,m),            enerReqtask_crop(hhold,crop_activity_endo,inten,"irrigation"))
*            v_irrigation_opt(hhold,crop_activity_endo,field,inten,m,y)

$ifi %LIVESTOCK_simplified%==on         + sum(type_animal, enerReq_Livestock(hhold,type_animal,"energy"))
        
$ifi %LIVESTOCK_simplified%==on         + sum(feedc,enerReq_Feed(hhold,feedc,"p_feed_energy"))
            ;
            


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 2: EQUATION DEFINITIONS
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

*-- GENERAL VALUE CHAIN EQUATIONS -----------------------------------------
* Buyer capacity constraint, maximum capacity  they can buy
E_output_capacity(inout,buyer,y)..
    sum(hhold, v_outputBuyer(hhold,inout,buyer,y)) =L= 
    p_capacity_buyer(inout,buyer);
* Output balance equation
E_output_buyer(hhold,inout,y)..
    v_markSales(hhold,inout,y) =E= 
    sum(buyer, v_outputBuyer(hhold,inout,buyer,y));
* Buyer labor calculation
E_labor_buyer(y)..
    v_laborBuyerOutput(y) =E= 
    sum((hhold,buyer,inout), v_outputBuyer(hhold,inout,buyer,y) * 
        p_labor_buyer(inout,buyer));


E_GHG(hhold,y)..
    v_GHG(hhold,y)=E=0
    
$ifi %LIVESTOCK_simplified%==on     +v_GHG_livestock(hhold,y)
$ifi %CROP%==on    +v_GHG_C(hhold,y)
$ifi %ORCHARD%==on    +v_GHG_AF(hhold,y)
;


*-- CROP MODULE EQUATIONS -----------------------------------------
$iftheni %CROP%==on

*-- Nitrogen Input Equations ----------------------------------------------
E_input_capacity_nitr_C(inout,seller_C,y)..
    sum(hhold, v_inputSeller_C(hhold,"nitr",seller_C,y)) =L= 
    p_capacity_seller_C("nitr",seller_C);
E_input_seller_C(hhold,inout,y)..
    (sum(crop_activity_endo, V_Use_Input_C(hhold,crop_activity_endo,'nitr',y))
$ifi %BIOPH%==ON $ifi %LIVESTOCK_simplified%==ON    -v_norg_crop(hhold)
$ifi %BIOPH%==ON -v_ncomp_crop(hhold)
)
    =E= 
    sum(seller_C, v_inputSeller_C(hhold,"nitr",seller_C,y));




*-- Phytosanitary Input Equations ----------------------------------------
E_input_capacity_phyto_C(inout,seller_C,y)..
    sum(hhold, v_inputseller_C(hhold,"phyto",seller_C,y)) =L= 
    p_capacity_seller_C("phyto",seller_C);
E_input_seller_phyto_C(hhold,inout,y)..
    sum((crop_activity), V_Use_Input_C(hhold,crop_activity,"phyto",y)) =E= 
    sum(seller_C, v_inputSeller_C(hhold,"phyto",seller_C,y));

*-- Other Input Equations ------------------------------------------------
E_input_capacity_other_C(inout,seller_C,y)..
    sum(hhold, v_inputSeller_C(hhold,"other",seller_C,y)) =L= 
    p_capacity_seller_C("other",seller_C);
E_input_seller_other_C(hhold,inout,y)..
    sum((crop_activity), V_Use_Input_C(hhold,crop_activity,"other",y)) =E= 
    sum(seller_C, v_inputSeller_C(hhold,"other",seller_C,y));

*-- Seller Labor Calculation --------------------------------------------
E_labor_seller(y)..
    v_laborSellerInput(y) =E= 
    sum((hhold,seller_C,inout), v_inputSeller_C(hhold,inout,seller_C,y) * 
        p_labor_seller_C(inout,seller_C));

*-- Seed Equations -----------------------------------------------------
E_seed_capacity(crop_activity,seeder,y)..
    sum(hhold, v_seedSeeder(hhold,crop_activity,seeder,y)) =L= 
    p_capacity_seeder(crop_activity,seeder);

E_seed_seeder(hhold,crop_activity_endo,y)..
    v_seedPurch(hhold,crop_activity_endo,y) =E= 
    sum(seeder, v_seedSeeder(hhold,crop_activity_endo,seeder,y));

E_transportCost_seeder(hhold,y)..
    v_transportCost_seeder(hhold,y) =E= 
    sum((crop_activity_endo,seeder), 
        v_seedSeeder(hhold,crop_activity_endo,seeder,y) * 
        p_distance_seeder(hhold,seeder)*p_distanceprice(hhold));

E_labor_seeder(y)..
    v_laborSeeder(y) =E= 
    sum((hhold,seeder,crop_activity_endo), v_seedSeeder(hhold,crop_activity_endo,seeder,y) * 
        p_labor_seeder(crop_activity_endo,seeder));

*-- Crop Transport Cost Calculation -------------------------------------
E_TransportCost_C(hhold,y)..
    v_transportCost_crop(hhold,y) =E= 
    sum((inpv,seller_C), v_inputSeller_C(hhold,inpv,seller_C,y) * 
        p_distance_seller_C(hhold,seller_C)*p_distanceprice(hhold))
    + sum((inpq,seller_C), v_inputSeller_C(hhold,inpq,seller_C,y) * 
        p_distance_seller_C(hhold,seller_C)*p_distanceprice(hhold))
    + sum((c_product_endo,buyer),v_outputBuyer(hhold,c_product_endo,buyer,y)* 
        p_distance_buyer(hhold,buyer)*p_distanceprice(hhold))
    + sum((crop_activity_endo,seeder),v_seedSeeder(hhold,crop_activity_endo,seeder,y) * 
        p_distance_seeder(hhold,seeder)*p_distanceprice(hhold));

E_GHG_C(hhold,y)..
    v_GHG_C(hhold,y)=E= (
 sum((inpv,seller_C), v_inputSeller_C(hhold,inpv,seller_C,y)*
        (p_distance_seller_C(hhold,seller_C)*P_GHG(hhold,"ghg_km")+P_GHG(hhold,inpv)))
        
    + sum((inpq,seller_C), v_inputSeller_C(hhold,inpq,seller_C,y) * 
        (p_distance_seller_C(hhold,seller_C)*P_GHG(hhold,"ghg_km")+P_GHG(hhold,inpq)))
        
    + sum((c_product_endo,buyer),v_outputBuyer(hhold,c_product_endo,buyer,y)* 
        (p_distance_buyer(hhold,buyer)*P_GHG(hhold,"ghg_km")+P_GHG(hhold,c_product_endo)))
        
    + sum((crop_activity_endo,seeder),v_seedSeeder(hhold,crop_activity_endo,seeder,y) * 
        (p_distance_seeder(hhold,seeder)*P_GHG(hhold,"ghg_km")+P_GHG(hhold,crop_activity_endo)))+0.00001);
;        

$endIf

*-- AGROFORESTRY MODULE EQUATIONS -----------------------------------------
$iftheni %ORCHARD%==on

*-- Nitrogen Input Equations (Agroforestry) -----------------------------
E_input_capacity_nitr_AF(inout,seller_AF,y)..
    sum(hhold, v_inputSeller_AF(hhold,"nitr",seller_AF,y)) =L= 
    p_capacity_seller_AF("nitr",seller_AF);

E_input_seller_AF(hhold,inout,y)..
    sum(c_tree,V_Nfert_AF(hhold, c_tree,y)) =E= 
    sum(seller_AF, v_inputSeller_AF(hhold,"nitr",seller_AF,y));

*-- Phytosanitary Input Equations (Agroforestry) -----------------------
E_input_capacity_phyto_AF(inout,seller_AF,y)..
    sum(hhold, v_inputseller_AF(hhold,"phyto",seller_AF,y)) =L= 
    p_capacity_seller_AF("phyto",seller_AF);

E_input_seller_phyto_AF(hhold,inout,y)..
    V_Phyto_AF(hhold,y) =E= 
    sum(seller_AF, v_inputSeller_AF(hhold,"phyto",seller_AF,y));

*-- Other Input Equations (Agroforestry) -------------------------------
E_input_capacity_other_AF(inout,seller_AF,y)..
    sum(hhold, v_inputSeller_AF(hhold,"other",seller_AF,y)) =L= 
    p_capacity_seller_AF("other",seller_AF);

E_input_seller_other_AF(hhold,inout,y)..
    V_other_AF(hhold,y) =E= 
    sum(seller_AF, v_inputSeller_AF(hhold,"other",seller_AF,y));

*-- Plant Input Equations (Agroforestry) -------------------------------
E_input_capacity_plants_AF(inout,seller_AF,y)..
    sum(hhold, v_inputSeller_AF(hhold,"plants_nb",seller_AF,y)) =L= 
    p_capacity_seller_AF("plants_nb",seller_AF);

E_input_seller_plants_AF(hhold,inout,y)..
    sum(c_tree,V_PlantsNB_AF(hhold,c_tree,y)) =E= 
    sum(seller_AF, v_inputSeller_AF(hhold,"plants_nb",seller_AF,y));

*-- Agroforestry Transport Cost ----------------------------
E_TransportCost_AF(hhold,y)..
    v_transportCost_orchard(hhold,y) =E= 0
$ifi %ORCHARD%==on + sum(seller_AF,v_inputSeller_AF(hhold,"other",seller_AF,y)* p_distance_seller_AF(hhold,seller_AF)*p_distanceprice(hhold))
$ifi %ORCHARD%==on + sum(seller_AF,v_inputSeller_AF(hhold,"phyto",seller_AF,y)*         p_distance_seller_AF(hhold,seller_AF)*p_distanceprice(hhold))
$ifi %ORCHARD%==on + sum(seller_AF,v_inputSeller_AF(hhold,"nitr",seller_AF,y)*         p_distance_seller_AF(hhold,seller_AF)*p_distanceprice(hhold))
$ifi %ORCHARD%==on + sum(seller_AF,v_inputSeller_AF(hhold,"plants_nb",seller_AF,y)*         p_distance_seller_AF(hhold,seller_AF)*p_distanceprice(hhold))
$ifi %ORCHARD%==on + sum((c_treej,buyer),v_outputBuyer(hhold,c_treej,buyer,y)*p_distance_buyer(hhold,buyer)*p_distanceprice(hhold));

E_GHG_AF(hhold,y)..
    v_GHG_AF(hhold,y) =E=(
    sum(seller_AF, 
        v_inputSeller_AF(hhold,"other",seller_AF,y) *
        (p_distance_seller_AF(hhold,seller_AF) * P_GHG(hhold,"ghg_km") + P_GHG(hhold,"other"))
    )
    + sum(seller_AF, 
        v_inputSeller_AF(hhold,"phyto",seller_AF,y) *
        (p_distance_seller_AF(hhold,seller_AF) * P_GHG(hhold,"ghg_km") + P_GHG(hhold,"phyto"))
    )
    + sum(seller_AF, 
        v_inputSeller_AF(hhold,"nitr",seller_AF,y) *
        (p_distance_seller_AF(hhold,seller_AF) * P_GHG(hhold,"ghg_km") + P_GHG(hhold,"nitr"))
    )
    + sum(seller_AF, 
        v_inputSeller_AF(hhold,"plants_nb",seller_AF,y) *
        (p_distance_seller_AF(hhold,seller_AF) * P_GHG(hhold,"ghg_km") + P_GHG(hhold,"plants_nb"))
    )
    + sum((c_treej,buyer), 
        v_outputBuyer(hhold,c_treej,buyer,y) *
        (p_distance_buyer(hhold,buyer) * P_GHG(hhold,"ghg_km") + P_GHG(hhold,c_treej))
    )+0.00001);

E_labor_seller_AF(y)..
    v_laborSeller_AF(y) =E= 
    sum((hhold,seller_AF),
    v_inputSeller_AF(hhold,"other",seller_AF,y)*p_labor_seller_AF("other",seller_AF)
    +v_inputSeller_AF(hhold,"phyto",seller_AF,y)*p_labor_seller_AF("phyto",seller_AF)
    +v_inputSeller_AF(hhold,"nitr",seller_AF,y)*p_labor_seller_AF("nitr",seller_AF)
    +v_inputSeller_AF(hhold,"plants_nb",seller_AF,y)*p_labor_seller_AF("plants_nb",seller_AF)
)
;

$endIf

*-- LIVESTOCK MODULE EQUATIONS -----------------------------------------
$iftheni %LIVESTOCK_simplified%==on

*-- Other Costs Equations -----------------------------------------------
E_input_capacity_other_A(hhold,y)..
    V_other_A(hhold,y) =E= 
    sum(seller_A,v_inputSeller_A(hhold,"othCostLivestock",seller_A,y));

E_input_seller_other_A(seller_A,y)..
    sum(hhold, v_inputSeller_A(hhold,"othCostLivestock",seller_A,y)) =L= 
    p_capacity_seller_A("othCostLivestock",seller_A);

*-- Veterinary Costs Equations -----------------------------------------
E_input_capacity_veterinary_A(hhold,y)..
    V_veterinary_A(hhold,y) =E= 
    sum(seller_A,v_inputSeller_A(hhold,"costVeterinary",seller_A,y));

E_input_seller_veterinary_A(seller_A,y)..
    sum(hhold, v_inputSeller_A(hhold,"costVeterinary",seller_A,y)) =L= 
    p_capacity_seller_A("costVeterinary",seller_A);

*-- Additional Costs Equations -----------------------------------------
E_input_capacity_addcost_A(hhold,y)..
    V_additional_A(hhold,y) =E= 
    sum(seller_A,v_inputSeller_A(hhold,"AdditionalCostLivestock",seller_A,y));

E_input_seller_addcost_A(seller_A,y)..
    sum(hhold, v_inputSeller_A(hhold,"AdditionalCostLivestock",seller_A,y)) =L= 
    p_capacity_seller_A("AdditionalCostLivestock",seller_A);

*-- Livestock Seller Labor Calculation --------------------------------
E_labor_seller_A(y)..
    v_laborSeller_A(y) =E= 
    sum((hhold,inout_A),sum(seller_A,v_inputSeller_A(hhold,inout_A,seller_A,y)*p_labor_seller_A(inout_A,seller_A)));

*-- Livestock Seller Equations ----------------------------------------
E_Livestock_Seller_capacity(type_animal,Livestock_seller,y)..
    sum(hhold, v_Livestock_seller(hhold,type_animal,Livestock_seller,y)) =L= 
    p_labor_Livestock_seller(type_animal,Livestock_seller);

E_Livestock_Seller(hhold,type_animal,y)..
    V_NewPurchased(hhold,type_animal,"1",y) =E=
    sum(Livestock_Seller, v_Livestock_seller(hhold,type_animal,Livestock_seller,y));

E_transportCost_Livestock_Seller(hhold,y)..
    v_transportCost_Livestock_Seller(hhold,y) =E= 
    sum((type_animal,Livestock_Seller), 
        v_Livestock_seller(hhold,type_animal,Livestock_seller,y) * 
        p_distance_Livestock_Seller(hhold,Livestock_Seller)*p_distanceprice(hhold));

E_labor_Livestock_Seller(y)..
    v_laborLivestock_seller(y)=E=
    sum((hhold,Livestock_Seller,type_animal), v_Livestock_seller(hhold,type_animal,Livestock_seller,y) * 
        p_labor_Livestock_Seller(type_animal,Livestock_Seller));

*-- Feed Seller Equations --------------------------------------------
E_Feed_Seller_capacity(feedc,Feed_Seller,y)..
    sum(hhold, v_Feed_seller(hhold,feedc,Feed_seller,y)) =L= 
    p_capacity_Feed_seller(feedc,Feed_seller);

E_Feed_Seller(hhold,feedc,y)..
    v_FeedPurchase(hhold,feedc,y) =E=sum(Feed_seller, v_Feed_seller(hhold,feedc,Feed_seller,y));

E_transportCost_Feed_Seller(hhold,y)..
    v_transportCost_Feed_seller(hhold,y) =E= 
    sum((feedc,Feed_seller), 
        v_Feed_seller(hhold,feedc,Feed_seller,y) * 
        p_distance_Feed_seller(hhold,Feed_seller)*p_distanceprice(hhold));

E_labor_Feed_Seller(y)..
    v_laborFeed_seller(y)=E=
    sum((hhold,Feed_seller,feedc), v_Feed_seller(hhold,feedc,Feed_seller,y) * 
        p_labor_Feed_seller(feedc,Feed_seller));

*-- Livestock Transport Cost Calculation ----------------------------
E_transportCost_livestock(hhold,y)..
    V_TransportCost_A(hhold,y) =E=  
    sum((seller_A), v_inputSeller_A(hhold,"AdditionalCostLivestock",seller_A,y)*p_distance_seller_A(hhold,seller_A)*p_distanceprice(hhold))
    + sum((ak,buyer),v_outputBuyer(hhold,ak,buyer,y)*p_distance_buyer(hhold,buyer)*p_distanceprice(hhold))
    + v_transportCost_Livestock_Seller(hhold,y)
    + v_transportCost_Feed_seller(hhold,y);
    
E_GHG_livestock(hhold,y)..
   v_GHG_livestock(hhold,y) =E= (sum((seller_A), v_inputSeller_A(hhold,"AdditionalCostLivestock",seller_A,y)*
    (p_distance_seller_A(hhold,seller_A)*p_GHG(hhold,"ghg_km")+p_GHG(hhold,"AdditionalCostLivestock")))
   
    + sum((ak,buyer),v_outputBuyer(hhold,ak,buyer,y)*
    (p_distance_buyer(hhold,buyer)*p_GHG(hhold,"ghg_km")+p_GHG(hhold,ak)))
    

    +sum((type_animal,Livestock_Seller), 
        v_Livestock_seller(hhold,type_animal,Livestock_seller,y) * 
        p_distance_Livestock_Seller(hhold,Livestock_Seller)*p_GHG(hhold,"ghg_km"))
    
    +sum((feedc,Feed_seller), 
        v_Feed_seller(hhold,feedc,Feed_seller,y)*(P_GHG(hhold,feedc) + 
        p_distance_Feed_seller(hhold,Feed_seller)*p_GHG(hhold,"ghg_km")))
    
    +sum((type_animal,age),p_GHG(hhold,type_animal)*V_animals(hhold,type_animal,age,y))+0.00001)
    
;
$endIf

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* SECTION 3: MODEL DEFINITION
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*

model valuechainMod 'Value Chain Module'
/
*-- General Value Chain Equations
    E_output_capacity
    E_output_buyer
    E_labor_buyer
    E_GHG
*-- Crop Module Equations
$ifi %CROP%==on E_input_capacity_phyto_C
$ifi %CROP%==on E_input_seller_phyto_C
$ifi %CROP%==on E_input_capacity_other_C
$ifi %CROP%==on E_input_seller_other_C
$ifi %CROP%==on E_input_capacity_nitr_C
$ifi %CROP%==on E_input_seller_C
$ifi %CROP%==on E_labor_seller
$ifi %CROP%==on E_TransportCost_C
$ifi %CROP%==on     E_GHG_C
$ifi %CROP%==on E_transportCost_seeder
$ifi %CROP%==on E_labor_seeder
$ifi %CROP%==on E_seed_seeder
$ifi %CROP%==on E_seed_capacity
$ifi %ENERGY%==on E_Energy
*-- Agroforestry Module Equations
$ifi %ORCHARD%==on E_input_capacity_nitr_AF
$ifi %ORCHARD%==on E_input_seller_AF
$ifi %ORCHARD%==on E_input_capacity_phyto_AF
$ifi %ORCHARD%==on E_input_seller_phyto_AF
$ifi %ORCHARD%==on E_input_capacity_other_AF
$ifi %ORCHARD%==on E_input_seller_other_AF
$ifi %ORCHARD%==on E_input_capacity_plants_AF
$ifi %ORCHARD%==on E_input_seller_plants_AF
$ifi %ORCHARD%==on E_TransportCost_AF
$ifi %ORCHARD%==on         E_GHG_AF
$ifi %ORCHARD%==on         E_labor_seller_AF
*-- Livestock Module Equations
$ifi %LIVESTOCK_simplified%==on E_input_capacity_other_A
$ifi %LIVESTOCK_simplified%==on E_input_seller_other_A
$ifi %LIVESTOCK_simplified%==on E_input_capacity_veterinary_A
$ifi %LIVESTOCK_simplified%==on E_input_seller_veterinary_A
$ifi %LIVESTOCK_simplified%==on E_input_capacity_addcost_A
$ifi %LIVESTOCK_simplified%==on E_input_seller_addcost_A
$ifi %LIVESTOCK_simplified%==on E_transportCost_livestock
$ifi %LIVESTOCK_simplified%==on E_labor_seller_A
$ifi %LIVESTOCK_simplified%==on E_Feed_Seller_capacity
$ifi %LIVESTOCK_simplified%==on E_Feed_Seller
$ifi %LIVESTOCK_simplified%==on E_transportCost_Feed_Seller
$ifi %LIVESTOCK_simplified%==on E_labor_Feed_Seller
    
$ifi %LIVESTOCK_simplified%==on E_Livestock_Seller_capacity
$ifi %LIVESTOCK_simplified%==on E_Livestock_Seller
$ifi %LIVESTOCK_simplified%==on E_transportCost_Livestock_Seller
$ifi %LIVESTOCK_simplified%==on E_labor_Livestock_Seller
$ifi %LIVESTOCK_simplified%==on E_GHG_livestock
/;
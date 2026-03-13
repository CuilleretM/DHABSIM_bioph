$ontext

   DAHBSIM model - Livestock Module

   GAMS file : livestock_module.gms
   @purpose  : Livestock production and economics
   @author   : Mathieu Cuilleret
   @date     : 11.07.25
   @since    : [Version]
   @refDoc   :
   @seeAlso  :
   @calledBy : farm_module.gms

   TODO: Integer value for head
   TODO: Variation for input price
   08-09 modification e_slaughter for long term modeling
$offtext

display p_initPopulation
p_selPriceLivestock;

*============================================================================*
* #1 INITIALIZATION AND PARAMETERS
*============================================================================*

* Fix self-consumption to zero for households without output goods
v_selfCons.fx(hhold,ak,y)$[not sum(gd, output_good(ak,gd))] = 0;
V_slaughter.up(hhold,type_animal,age,'y01') = p_initPopulation(hhold,type_animal,age);
*============================================================================*
* #2 EQUATION DECLARATIONS
*============================================================================*

equations
* Economic equations
    E_AnnualGM_A(hhold,y)         'Total livestock gross margin calculation'
    E_Revenue_A(hhold,y)          'Total livestock revenue calculation'
    E_VarCost_A(hhold,y)          'Total livestock variable cost calculation'
    E_FixCost_A(hhold,y)          'Total livestock fixed cost calculation'
    
* Input cost equations
    E_other_input(hhold,y)        'Other input costs calculation'
    E_veterinary_input(hhold,y)   'Veterinary costs calculation'
    E_additional_input(hhold,y)   'Additional input costs calculation'
    
* Feed equations
    e_FeedBalance(hhold,feedc,y)       'Feed balance constraint'
    e_FeedEnergy(hhold,type_animal,y)  'Feed energy requirement constraint'
    e_FeedProtein(hhold,type_animal,y) 'Feed protein requirement constraint'
    e_FeedDryMatter(hhold,type_animal,y) 'Feed dry matter requirement constraint'
    e_FeedAvailable(hhold,feedc,y)     'Feed available calculation'
    
* Production equations
    E_Manure_Outputs(hhold,type_animal,y) 'Manure production calculation'
    E_LIVEPRD(hhold,ak,y)            'Livestock production equation'
    E_SBALANCE_AK(hhold,ak,y)        'Animal product balance equation'
    
* Population dynamics
    e_PopDynamics(hhold,type_animal,age,y) 'Population dynamics equation'
    e_NewBorns(hhold,type_animal,age,y)    'Newborns calculation'
    e_Slaughter_Constraint(hhold,type_animal,age,y) 'Slaughter constraint'
    e_Slaughter_ConstraintPreviousYear(hhold,type_animal,age,y)
    e_Slaughter_Constraint0(hhold,type_animal,age,y)
    e_PopLimits(hhold,type_animal,y)             'Population limits on farms'
    e_Slaughter_ConstraintInit(hhold,type_animal,age,y)
* Labor equations
    E_Labor_A(hhold,m,y)             'Labor requirement calculation'
* Nutrient equations
    e_NitrogenOutput(hhold,type_animal,y) 'Nitrogen output calculation'
    e_Balance_NitrogenOutput(hhold,y)
*for birthrate and deathrate
EQ_INT1_NB(hhold,type_animal,y)
EQ_INT2_NB(hhold,type_animal,y)
*for birthrate and deathrate
EQ_INT1_D(hhold,type_animal,age,y)
EQ_INT2_D(hhold,type_animal,age,y)

;


*---------------------------------------------------------------------------*
* Input Cost Equations
*---------------------------------------------------------------------------*

E_other_input(hhold,y)..
    V_other_A(hhold,y) =E= sum((type_animal,age), 
        p_othCostLivestock(hhold,type_animal)*V_animals(hhold,type_animal,age,y))
;

E_veterinary_input(hhold,y)..
    V_veterinary_A(hhold,y) =E= sum((type_animal,age), 
        p_costVeterinary(hhold,type_animal)*V_animals(hhold,type_animal,age,y))
;

E_additional_input(hhold,y)..
    V_additional_A(hhold,y) =E= sum((type_animal,age), 
        p_AdditionalCostLivestock(hhold,type_animal)*V_animals(hhold,type_animal,age,y))
;

*---------------------------------------------------------------------------*
* Production Equations
*---------------------------------------------------------------------------*
display a_k
ak
akmeat;

E_LIVEPRD(hhold,ak,y)..
    v_prodQuant(hhold,ak,y) =E=  
     sum(type_animal,
     sum(age, V_animals(hhold,type_animal,age,y)*p_yieldLivestock(hhold,type_animal,ak,age)$akmilk(ak))) +
     sum(type_animal,sum(age,v_Slaughter(hhold,type_animal,age,y)*p_yieldLivestock(hhold,type_animal,ak,age)$akmeat(ak)))
     ;

E_SBALANCE_AK(hhold,ak,y)..
    v_prodQuant(hhold,ak,y) =E= v_selfCons(hhold,ak,y)$sum(gd, output_good(ak,gd)) + v_markSales(hhold,ak,y);

*---------------------------------------------------------------------------*
* Economic Equations
*---------------------------------------------------------------------------*

E_AnnualGM_A(hhold,y).. 
    V_annualGM_A(hhold,y) =E= V_Revenue_A(hhold,y)
    - V_VarCost_A(hhold,y)
$ifi %VALUECHAIN%==ON - V_TransportCost_A(hhold,y)
    - sum(m,V_HLabor_A(hhold,m,y))*p_buyPrice(hhold,'labor')
    - V_FixCost_A(hhold,y)  
;

E_Revenue_A(hhold,y).. 
    V_Revenue_A(hhold,y) =E= sum(ak,v_selfCons(hhold,ak,y)$sum(gd, output_good(ak,gd))* p_selPrice(hhold,ak))
$ifi %VALUECHAIN%==ON  + sum((buyer,ak),v_outputBuyer(hhold,ak,buyer,y)*p_price_buyer(ak,buyer))
$ifi %VALUECHAIN%==OFF + sum((age,type_animal,ak),V_animals(hhold,type_animal,age,y)*p_yieldLivestock(hhold,type_animal,ak,age)$akmilk(ak)*p_selPriceLivestock(hhold,type_animal,ak))
$ifi %VALUECHAIN%==OFF +   sum((age,type_animal,ak),v_Slaughter(hhold,type_animal,age,y)*p_yieldLivestock(hhold,type_animal,ak,age)$akmeat(ak)*p_selPriceLivestock(hhold,type_animal,ak))        
;







E_VarCost_A(hhold,y).. 
    V_VarCost_A(hhold,y) =E=
    sum((type_animal,age), 
        (p_othCostLivestock(hhold,type_animal)
        + p_costVeterinary(hhold,type_animal)) * V_animals(hhold,type_animal,age,y) 
        + p_AdditionalCostLivestock(hhold,type_animal))
$ifi %VALUECHAIN%==OFF + sum((type_animal,age),V_NewPurchased(hhold,type_animal,age,y)*p_selPriceLivestock(hhold,type_animal,'liveanimal'))        
$ifi %VALUECHAIN%==OFF + sum(feedc,v_FeedPurchase(hhold,feedc,y)*p_feed_price(hhold,feedc))
$ifi %VALUECHAIN%==ON  + sum((type_animal,Livestock_Seller), v_Livestock_seller(hhold,type_animal,Livestock_seller,y) * p_price_Livestock_seller(type_animal,Livestock_seller))     
$ifi %VALUECHAIN%==ON  + sum((feedc,Feed_seller), v_Feed_seller(hhold,feedc,Feed_seller,y) * p_price_Feed_seller(feedc,Feed_seller))
;

E_FixCost_A(hhold,y)..
    V_FixCost_A(hhold,y) =E= 0
;

*---------------------------------------------------------------------------*
* Feed Equations
*---------------------------------------------------------------------------*
e_FeedAvailable(hhold,feedc,y).. 
    v_FeedAvailable(hhold,feedc,y) =E= v_FeedPurchase(hhold,feedc,y)
$ifi %CROP%==ON + sum(cken$sameas(feedc,cken), v_residuesfeed(hhold,cken,y))
;
e_FeedBalance(hhold,feedc,y).. 
    v_FeedAvailable(hhold,feedc,y) =G= 
    sum(type_animal$animal_feed(type_animal,feedc), 
        sum(age, v_FeedConsumed(hhold,feedc,type_animal,y) * V_animals(hhold,type_animal,age,y)));


e_FeedEnergy(hhold,type_animal,y).. 
    sum(feedc, p_grossenergy_feed(feedc) * 
        sum(age, v_FeedConsumed(hhold,feedc,type_animal,y) * V_animals(hhold,type_animal,age,y))) 
    =G= sum(age, p_feedReq(type_animal,"gross_energy") * V_animals(hhold,type_animal,age,y));



e_FeedProtein(hhold,type_animal,y).. 
    sum(feedc, p_protein_feed(feedc) * sum(age,v_FeedConsumed(hhold,feedc,type_animal,y)* V_animals(hhold,type_animal,age,y))) 
    =G= sum((feedc,age), p_feedReq(type_animal,"protein") * V_animals(hhold,type_animal,age,y));

e_FeedDryMatter(hhold,type_animal,y).. 
    sum(feedc, p_drymatter_feed(feedc) * sum(age,v_FeedConsumed(hhold,feedc,type_animal,y)* V_animals(hhold,type_animal,age,y))) 
    =G= sum((feedc,age), p_feedReq(type_animal,"dry_matter") * V_animals(hhold,type_animal,age,y));


*---------------------------------------------------------------------------*
* Manure and Nutrient Equations
*---------------------------------------------------------------------------*

E_Manure_Outputs(hhold,type_animal,y).. 
    v_ManureProd(hhold,type_animal,y) =E= 
    p_feedReq(type_animal,"dry_matter") * 0.356 * 0.8 * sum(age,V_animals(hhold,type_animal,age,y));

e_NitrogenOutput(hhold,type_animal,y).. 
    v_NitrogenOutput(hhold,type_animal,y) =E=
    (1/6.25) *
    

(sum(feedc, v_FeedConsumed(hhold,feedc,type_animal,y)  * p_protein_feed(feedc)) 
        - p_prot_metab(hhold,type_animal)
        + p_ca(hhold,type_animal) * 0.44 *
        sum(feedc, p_grossenergy_feed(feedc) * v_FeedConsumed(hhold,feedc,type_animal,y)) * (1/1000))*            sum(age, V_animals(hhold,type_animal,age,y))
        ;

e_Balance_NitrogenOutput(hhold,y).. sum(type_animal,v_NitrogenOutput(hhold,type_animal,y))=e=
v_NitrogenOutput_OnFarm(hhold,y)+v_NitrogenOutput_Sell(hhold,y);
*p_selPriceLivestock(hhold,type_animal,"manure")

*            sum(age, V_animals(hhold,type_animal,age,y))
*---------------------------------------------------------------------------*
* Labor Equations
*---------------------------------------------------------------------------*

E_Labor_A(hhold,m,y).. 
    V_FamLabor_A(hhold,m,y) + V_HLabor_A(hhold,m,y) =E= 
    sum((type_animal,age), p_LaborReqLivestock(hhold,type_animal,m) * V_animals(hhold,type_animal,age,y));

*---------------------------------------------------------------------------*
* Population Dynamics Equations
*---------------------------------------------------------------------------*

e_PopDynamics(hhold,type_animal,age,y)..
    V_animals(hhold,type_animal,age,y) =E=
    (p_initPopulation(hhold,type_animal,age))$(ord(y) = 1)
    + (V_animals(hhold,type_animal,age-1,y-1))$(ord(y) > 1)
    -v_Mortality(hhold,type_animal,age,y) 
    + v_NewBorns(hhold,type_animal,"1",y)
    - v_Slaughter(hhold,type_animal,age,y)$(ord(age)>2)
    + (V_NewPurchased(hhold,type_animal,age,y))
;

e_Slaughter_Constraint(hhold,type_animal,age,y)$(ord(age)>=2 and ord(y)>1) ..
    V_slaughter(hhold,type_animal,age,y) =l=
    V_animals(hhold,type_animal,age,y)
    ;

e_Slaughter_ConstraintInit(hhold,type_animal,age,y)$(ord(age)>=2 and ord(y)=1) ..
    V_slaughter(hhold,type_animal,age,y) =l=
    p_initPopulation(hhold,type_animal,age)
;
e_Slaughter_ConstraintPreviousYear(hhold,type_animal,age,y)$(ord(age)>=2 and ord(y)>1) ..
    V_slaughter(hhold,type_animal,age,y) =l=
    V_animals(hhold,type_animal,age,y-1);
    
e_Slaughter_Constraint0(hhold,type_animal,age,y)$(ord(age)<2) ..
    V_slaughter(hhold,type_animal,age,y) =e=
    0;






e_PopLimits(hhold,type_animal,y)..
    sum(age,V_animals(hhold,type_animal,age,y)) =L= 
    sum(age,p_initPopulation(hhold,type_animal,age))
;

EQ_INT1_NB(hhold,type_animal,y)..
    v_NewBorns(hhold,type_animal,"1",y) =L= 
    sum(age, p_Repro(hhold,type_animal,age) * V_animals(hhold,type_animal,age,y-1)) + 0.5;
EQ_INT2_NB(hhold,type_animal,y)..
    v_NewBorns(hhold,type_animal,"1",y) =G= 
    sum(age, p_Repro(hhold,type_animal,age) * V_animals(hhold,type_animal,age,y-1)) - 0.5;
EQ_INT1_D(hhold,type_animal,age,y)..
    v_Mortality(hhold,type_animal,age,y) =L= 
    p_MortalityRate(hhold,type_animal,age) * V_animals(hhold,type_animal,age,y-1) + 0.5;
EQ_INT2_D(hhold,type_animal,age,y)..
    v_Mortality(hhold,type_animal,age,y) =G= 
     p_MortalityRate(hhold,type_animal,age) * V_animals(hhold,type_animal,age,y-1) - 0.5;





*============================================================================*
* #4 MODEL DEFINITION AND SOLVE STATEMENT
*============================================================================*

model LivestockModule /
* Economic equations
    E_AnnualGM_A
    E_Revenue_A
    E_VarCost_A
    E_FixCost_A
    
* Input cost equations
    E_other_input
    E_veterinary_input
    E_additional_input
    
* Feed equations
    e_FeedBalance
    e_FeedEnergy
    e_FeedProtein
    e_FeedDryMatter
    e_FeedAvailable
    
* Production equations
    E_Manure_Outputs
    E_SBALANCE_AK
    E_LIVEPRD
    
* Population dynamics
    e_PopDynamics
    e_Slaughter_Constraint
    e_Slaughter_Constraint0
    e_Slaughter_ConstraintPreviousYear
*    e_Slaughter_ConstraintInit
    e_PopLimits
    EQ_INT1_NB
    EQ_INT2_NB
    EQ_INT1_D
    EQ_INT2_D
* Labor equations
    E_Labor_A       
    
* Nutrient equations
    e_NitrogenOutput
    e_Balance_NitrogenOutput
    
/;

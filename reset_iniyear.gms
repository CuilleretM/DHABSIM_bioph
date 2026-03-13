*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : reset_iniyear.gms
   @purpose  : Reinitialize initial conditions
   @author   : Maria Blanco <maria.blanco@upm.es>
   @date     : 22.09.14
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy : simulation_model.gms
   08-09 Change in the organization and cleaning of these equations.
$offtext
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$onglobal

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Crop module
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- crop yield
$iftheni.inib %BIOPH%==on
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  resetBIOPH
$endif.inib

$iftheni %CROP%==on
v0_Land_C(hhold,crop_activity_endo,field)      = v_Land_C.l(hhold,crop_activity_endo,field,'y01');
*-- Crop production
v0_Prd_C(hhold,crop_activity_endo,field,inten) = v_Prd_C.l(hhold,crop_activity_endo,field,inten,'y01') ;
V0_Use_Input_C(hhold,crop_activity_endo,i) = V_Use_Input_C.l(hhold,crop_activity_endo,i,'y01');
display V0_Use_Input_C;
*V0_Use_Seed_C(hhold,crop_activity_endo,'seedTotal')  = V_Use_Seed_C.l(hhold,crop_activity_endo,'y01') ;
*V0_Use_Seed_C(hhold,crop_activity_endo,'seedOnfarm') = v_seedOnfarm.l(hhold,crop_activity_endo,'y01');
v0_prodQuant(hhold,c_product_endo) = v_prodQuant.l(hhold,c_product_endo,'y01') ;
v0_prodQuant(hhold,cken) = v_prodQuant.l(hhold,cken,'y01') ;

$endif
$iftheni %ORCHARD%==on
V0_Area_AF(hhold,field,c_tree,age_tree+1,inten)=V_Area_AF.L(hhold,field,c_tree,age_tree,inten,'y01');
$endIf
**
$iftheni %LIVESTOCK_simplified%==on
display p_initPopulation;
p_initPopulation(hhold,type_animal,age+1)=V_animals.L(hhold,type_animal,age,'y02');
$endIf
*
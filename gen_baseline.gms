*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : gen_baseline.gms
   @purpose  : Generate baseline
   @author   : Maria Blanco/Sophie Drogue
   @date     : 22.11.15
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy :

$offtext
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$offsymxref
$onglobal
*option limrow=20;
*option optcr = 0.001
*option optca = 0.0001
*option lp = CPLEX;
*option nlp = IPOPT;
option minlp = baron;
option rminlp = baron;
option threads = 30;
*option iterlim = 200000;
*option reslim = 150;
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 General sets + settings
* Set_database.gms has been ran to create the necessary database
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- general settings
$batinclude "settings.gms" settings_glo
**$include "set_database.gms" 
$batinclude "set_database.gms" set_database_ini

***=================================================
**
****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
**** #3 Model generation (modular structure)
****~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
****
**-- include biophysical module (if biophysical data exist)
**   calculation of endogenous yields
**   evolution of soil fertility
*initialisation of the model of water and irrigation
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  water_init
$ifi %BIOPH%==on $batinclude "Water_module_equation.gms"  first_sim
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  nitrate_init
$ifi %BIOPH%==on $batinclude "Nitrate_module_equation.gms"  first_sim
*-- include crop module (core module used in all simulations)
*   cropland allocation
*   labor use
*   rotation constraints
**
$ifi %CROP%==on $include "crop_module.gms"
**************************************************************************************************
*** create a parameter for seedstock -- will integrate this better into the data structure later
parameter v0_seedStorage;
*** assume their storage is 3 times the seed use in base data
$ifi %CROP%==on v0_seedStorage(hhold,crop_activity_endo,'firstYear') = V0_Use_Seed_C(hhold,crop_activity_endo,'seedTotal')*3;
*************************************************************************************************
$include "farm_module.gms"
$include "household_module.gms"

**~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #5 Simulation: definition of scenario
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ifi %BIOPH%==on v_KS_month.lo(hhold,crop_activity,field,inten,m,y)  = 0;
$ifi %BIOPH%==on v_KS_month.up(hhold,crop_activity,field,inten,m,y)  = 1;
$ifi %BIOPH%==on v_nstress.lo(hhold,crop_activity_endo,field,inten,y)=0;
$ifi %BIOPH%==on v_nstress.up(hhold,crop_activity_endo,field,inten,y)=1;
display v0_Prd_C;
*
$include "simulation_model.gms"


*
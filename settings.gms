*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
$ontext

   DAHBSIM model

   GAMS file : setting.gms
   @purpose  : general setting
   @author   : 
   @date     : 15/07/2025
   @since    : May 2014
   @refDoc   :
   @seeAlso  :
   @calledBy :
 08-09 addition of linux modification cleaning of unused sets
$offtext
*=============================================================================
* SECTION 1: GLOBAL SETTINGS AND CONFIGURATION
*=============================================================================
$goto %1

$label settings_glo
*-- Global configuration parameters
*-- Region selection (Siliana, Dedza, or Egypt)
*$setglobal REGION tizi
*$setglobal REGION SousMassa


*-- Global configuration parameters
*-- Region selection (Siliana, Dedza, or Egypt)

* Set definition
set settings_set / BIOPH, CONS, DATABASE, ORCHARD, 
                    LIVESTOCK_simplified, CROP, PMPCalib,BiophCalib, 
                    VALUECHAIN, DIONYSUS, ENERGY, FIXEDIRRIGATION, LINUX /;

parameter settings(settings_set);
set region_text;
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%setting.xlsx
    symbols:
      - name: settings
        range: setting!A5:B18
        columnDimension: 0
        rowDimension: 1
        type: par
      - name: region_text
        range: setting!C5
        columnDimension: 0
        rowDimension: 1
        type: set
- GAMSWriter:
    symbols: all
$offEmbeddedCode

display  region_text;

*if (settings('BIOPH') = 1,
*$setglobal BIOPH on
*else
*$setglobal BIOPH off
*);
*if (settings('CONS') = 1,
*$setglobal CONS on
*else
*$setglobal CONS off
*);
*if (settings('ORCHARD') = 1,
*$setglobal ORCHARD on
*else
*$setglobal ORCHARD off
*);
*if (settings('DATABASE') = 1,
*$setglobal DATABASE on
*else
*$setglobal DATABASE off
*);
*if (settings('LIVESTOCK_simplified') = 1,
*$setglobal LIVESTOCK_simplified on
*else
*$setglobal LIVESTOCK_simplified off
*);
*if (settings('CROP') = 1,
*$setglobal CROP on
*else
*$setglobal CROP off
*);
*if (settings('PMPCalib') = 1,
*$setglobal PMPCalib on
*else
*$setglobal PMPCalib off
*);
*if (settings('PMPCalib') = 1,
*$setglobal PMPCalib on
*else
*$setglobal PMPCalib off
*);
*if (settings('VALUECHAIN') = 1,
*$setglobal VALUECHAIN on
*else
*$setglobal VALUECHAIN off
*);
*if (settings('DIONYSUS') = 1,
*$setglobal DIONYSUS on
*else
*$setglobal DIONYSUS off
*);
*if (settings('ENERGY') = 1,
*$setglobal ENERGY on
*else
*$setglobal ENERGY off
*);
*if (settings('FIXEDIRRIGATION') = 1,
*$setglobal FIXEDIRRIGATION on
*else
*$setglobal FIXEDIRRIGATION off
*);
*if (settings('LINUX') = 1,
*$setglobal LINUX on
*else
*$setglobal LINUX off
*);
*









*$setglobal REGION Siliana
*$setglobal BIOPH on
*$setglobal CONS on
*$setglobal DATABASE on
*$setglobal ORCHARD on
*$setglobal LIVESTOCK_simplified on
*$setglobal CROP on
*$setglobal PMPCalib on
*$setglobal VALUECHAIN on
*$setglobal DIONYSUS on
*$setglobal ENERGY on
*$setglobal FIXEDIRRIGATION on
*$setglobal LINUX off

*** Generation of setglobal.gms
file fout /setglobal.gms/;
put fout;

* Case study
put '$setglobal REGION ';
loop(region_text,
    put region_text.tl:0;
);
put /;

** Paramètres binaires
loop(settings_set,
    put '$setglobal ', settings_set.tl:0;
    if(settings(settings_set) = 1,
        put ' on';
    else
        put ' off';
    );
    put /;
);

putclose;

* Inclusion of the activated module and name of case study
$include "setglobal.gms"





*-- GAMS system configuration (commented out by default)
*$setglobal gamsPath C:\gams22.8\  * GAMS installation path
*$setglobal NoCPU 4                * Number of CPUs for parallel processing
*$setglobal procSpeedRelative 100  * Relative processor speed
*$setglobal JAVA ON                * Java integration flag
*$setglobal nuteval ON             * Nutrient module evaluation

$exit

*=============================================================================
* SECTION 2: GENERIC SET DEFINITIONS
*=============================================================================
$label sets_generic

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #1 Declare generic sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
*-- Temporal sets
  year          'years'
  m             'months'
  
*-- Spatial and organizational sets
  reg           'regional units'
  hhold         'household types'
  
*-- Agricultural production sets
  field         'field number'
  inten         'intensification level - management practices'
  crop_activity 'cropping activities'

*08-09 Delete because they are not use
*-- Resource sets
*  labtype       'labor types'
*  labclass      'labor classes'

*-- Input/Output sets
  input_quantity 'quantity-based inputs (kg/ha)'
  input_value    'value-based inputs (nc/ha)'
  cmpro          'crop main products'
  ccpro          'crop by-products'
  task           'labor tasks'
*-- Balance sets
  seedbal       'seed balance positions'
*-- Consumption sets
  good          'goods for LES function'
*-- Data structure sets
  hvar          'household definition variables'
*-- Mapping sets
  activity_output 'activity-output mapping'
  a_j            'activity-main product mapping'
  a_k            'activity-by-product mapping'
  c_c(crop_activity,crop_activity)            'crop-preceding crop mapping'
  c_t_m          'crop-task-month mapping'
  output_good    'main product-good mapping'
;


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Load generic sets from GDX file
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- load sets from gdx
$iftheni %LINUX%==off
$call "gdxxrw.exe DATA\sets_dahbsim_%region%_new.xlsx o=DATA\sets_generic_%region%_new.gdx se=2 index=index_set!A3"
$gdxin "DATA\sets_generic_%region%_new.gdx"
$load year m reg hhold field inten crop_activity  
$load input_quantity input_value cmpro ccpro  good activity_output output_good 
$load  task seedbal hvar 
$load  c_c c_t_m 
$gdxin
$endif




$iftheni %LINUX%==on
$onEmbeddedCode Connect:
- ExcelReader:
    file: DATA%system.DirSep%sets_dahbsim_%region%_new.xlsx
    symbols:
       - {name: input_quantity, range: sets!F4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: input_value, range: sets!G4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: cmpro, range: sets!H4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: ccpro, range: sets!I4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: good, range: sets!J4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: activity_output, range: sets!R4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: output_good, range: sets!T4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: year, range: sets!A4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: crop_activity, range: sets!C4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: seedbal, range: sets!K4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: hvar, range: sets!N4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: task, range: sets!Q4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: field, range: sets!D4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: reg, range: sets!L4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: hhold, range: sets!M4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: inten, range: sets!E4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: m, range: sets!B4, columnDimension: 0, rowDimension: 1, type: set}
       - {name: c_c, range: sets!V4, columnDimension: 0, rowDimension: 2, type: set}
       - {name: c_t_m, range: sets!X4, columnDimension: 0, rowDimension: 3, type: set}
- GAMSWriter:
    symbols: all  # GAMS 48
$offEmbeddedCode
$endif

*       

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #3 Define aggregate sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  input         'all input categories'                 /set.input_quantity,set.input_value/
  output        'all output categories'                /set.cmpro,set.ccpro/
  inout         'combined inputs/outputs'     /set.input,set.output/
;


*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #4 Define sub-sets
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  inpq(inout)   'quantity inputs'     /set.input_quantity/
  inpv(inout)   'value inputs' /set.input_value/
  outm(inout)   'main products'           /set.cmpro/
  outc(inout)   'by-products'             /set.ccpro/
  feed(inout)   'feed sources'       /set.inout/
 ;
$exit

*=============================================================================
* SECTION 3: REGION-SPECIFIC SETTINGS
*=============================================================================
$label settings_reg

*-- Year set definitions

$setglobal FstAnte 2004
$setglobal LstPost 2007
$setglobal FstYear 2004
$setglobal LstYear 2007


*set  yy(year) 'ex-post and ex-ante years' /%FstAnte%*%LstPost%/;
set  y2(year) 'simulation years' /%FstYear%*%LstYear%/;
*if you put a bigger value it cause issue with pmp
set  y(year)  'model years'      /y01*y02/; 
*set  y(year)  'model years'      /y01/;
*set firsty(y) 'First year';  firsty(y)=YES$(ORD(y)=1);
*set firstm(m) 'First month'; firstm(m) = YES$(ORD(m)=1);
*set lasty(y)'Last year';     lasty(y) =YES$(ORD(y) EQ CARD(y));
*set lastm(m) 'Last year';    lastm(m)  = YES$(ORD(m) EQ CARD(m));
*set firstyear(y2) 'First y2';firstyear(y2)=YES$(ORD(y2)=1);
*set secondyear(y2) 'Second y2';secondyear(y2)=YES$(ORD(y2)=2);
*set thirdyear(y2) 'Third y2';thirdyear(y2)=YES$(ORD(y2)=3);
*set fourthyear(y2) 'Fourth y2';fourthyear(y2)=YES$(ORD(y2)=4);
*set secondthirdfourth(y2); secondthirdfourth(y2)=YES$((ORD(y2)=2) or (ORD(y2)=3) or (ORD(y2)=4))
*
*-- Model module switches
*$setglobal RISK off
*$setglobal BIOPH on
*$setglobal CONS on
*$setglobal DATABASE ON
*$setGlobal ORCHARD off
**16-07-2025 Off it's better for PMP
*$setGlobal LIVESTOCK_simplified off
*$setglobal CROP on
*$setglobal PMPCalib on
*$setglobal VALUECHAIN on
*$setglobal DIONYSUS off
*$setglobal ENERGY on
*$setglobal FIXEDIRRIGATION on

$exit



*=============================================================================
* SECTION 4: REGION-SPECIFIC SET DEFINITIONS
*=============================================================================
$label sets_specific
*-- Specific set declarations for current run

*~~~~~~~~~~~~~~~~ Temporal sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  y(year) 'years in current run'
;

*~~~~~~~~~~~~~~~~ Agricultural production sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  type_animal       'livestock types in current run'
  crop_activity_endo(crop_activity) 'endogenous crop activities in current run'
;

*~~~~~~~~~~~~~~~~ Input/Output sets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
set
  i(inout)            'inputs'
  c_product(inout)    'crop products'
  c_product_endo(inout) 'endogenous crop products'
  ck(inout)           'crop by-products'
  cken(inout)         'endogenous by-products'
  gd(good)            'consumption goods'
  crop_preceding(crop_activity) 'preceding crops in rotation'
  ak(inout)           'animal products' 
;

*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
* #2 Define specific relationships and mappings
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*-- Create aliases for cross-referencing
alias(crop_activity,crop_activity2);
alias(m,m2);
alias(gd,gd2);

*-- crop activities endogenous and exogenous
crop_activity_endo(crop_activity) = yes $sum(crop_activity2,c_c(crop_activity,crop_activity2));
alias(crop_activity_endo,crop_activity_endo2);

*-- Identify preceding crops in rotation
crop_preceding(crop_activity_endo) = yes;


*-- Define input categories
* Nitrogen inputs
i('nitr')  = yes;
* Seed inputs  
i('seed')  = yes;  
* Phytosanitary inputs
i('phyto') = yes;  
* Other inputs
i('other') = yes;  
*NEW parameter to solve the issue of word


Set NameStraw / ystraw/ ;
Set NameYield / yield/ ;
Set NameArea / area/ ;
Set   NameSeed(inout);
NameSeed('seed') = yes; 
Set   NameLabor(inout);
NameLabor('labor') = yes; 
Set   NameNitr(inout);
NameNitr('nitr') = yes;

Set   NamePlantsNb(inout);
NamePlantsNb('plants_nb') = yes;

Set   NamePhyto(inout);
NamePhyto('phyto') = yes; 
Set   NameOther(inout);
NameOther('other') = yes; 
Set   NameseedOnFarm(seedbal)         'seed inputs';
NameseedOnFarm('seedOnFarm') = yes;
Set   NameseedTotal(seedbal)         'seed inputs';
NameseedTotal('seedTotal') = yes; 
Set   NameFert(inout);
NameFert('fert') = yes;
Set   NamePlanting(task)         ;
NamePlanting('planting') = yes; 
Set   NameWeeding(task)         ;
NameWeeding('weeding') = yes; 
Set   NameHerbicide(task)       ;
NameHerbicide('herbicide') = yes;
Set   NameChe_fert(task)        ;
NameChe_fert('che_fert') = yes;
Set   NameOrg_fert(task)        ;
NameOrg_fert('org_fert') = yes;
Set   NamePesticide(task)       ;
NamePesticide('pesticide') = yes;
Set   NameHarvest(task)       ;
NameHarvest('harvest') = yes;





*display inout;
*-- Identify crop products and their relationships
c_product(outm) = yes $(sum(activity_output(crop_activity,outm),1));
a_j(crop_activity,c_product) $(activity_output(crop_activity,c_product)) = yes ;
c_product_endo(outm) = yes $(sum(activity_output(crop_activity_endo,outm),1));

*-- Identify by-products and their relationships
ck(outc) = yes $(sum(activity_output(crop_activity,outc),1));
a_k(crop_activity,ck) $(activity_output(crop_activity,ck)) = yes ;
cken(outc) = yes $(sum(activity_output(crop_activity_endo,outc),1));

*-- Identify consumption goods
gd(good)= yes  ;
$exit
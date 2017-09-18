!This subroutine does the actual calculations of the SUEWS code (mostly old SUEWS_Temporal).
!Made by LJ and HW Oct 2014
!Gives in the grid ID (Gridiv) and number of line in the met forcing data to be analyzed (ir)
!Last modification
!
!Last modification:
! LJ  15 Jun 2017 - Add parts where NonWaterFraction=0 is used as a divider so that the code won't crash with 100% water
! TS  20 May 2017 - Add surface-level diagonostics: T2, Q2, U10
! HCW 09 Dec 2016 - Add zenith and azimuth to output file
! HCw 24 Aug 2016 - smd and state for each surface set to NAN in output file if surface does not exist.
!                 - Added Fc to output file
! HCW 21 Jul 2016 - Set soil variables to -999 in output when grid is 100% water surface.
! HCW 29 Jun 2016 - Commented out StateDay and SoilMoistDay as creates jumps and should not be needed.
!                   Would not work unless each met block consists of a whole day for each grid.
! TS 09 Mar 2016  - Added AnOHM subroutine to calculate heat storage
! HCW 10 Mar 2016 - Calculation of soil moisture deficit of vegetated surfaces added (vsmd)
! LJ 2 Jan 2016   - Calculation of snow fraction moved from SUEWS_Calculations to SUEWS_Snow
! HCW 12 Nov 2015 - Added z0m and zdm to output file
! HCW 05 Nov 2015 - Changed Kawai et al. (2007) z0v calculation so VegFraction(veg+soil) rather than veg_fr(veg+soil+water) is used.
! HCW 29 Jun 2015 - Added albEveTr and albGrass
! HCW 25 Jun 2015 - Fixed bug in LAI calculation at year change.
!                 - Changed AlbDec to use id value (not (id-1) value) to avoid issues at year change.
! HCW 27 Apr 2015 - Correction to tot_chang_per_tstep calculation (water balance should now close)
! HCW 16 Feb 2015 - Updated water balance calculations
!                 - Corrected area-averaged calculations (soil moisture, drain, two versions of state with/out water)
!                 - Replaced soilmoist_state variable with soilstate (as seems to be duplicate)
! HCW 15 Jan 2015 - Added switch OHMIncQF to calculate QS with (1, default) or without (0) QF added to QSTAR
! To do
!      - add iy and imin to output files (may impact LUMPS_RunoffFromGrid)
!      - phase out _per_interval water balance variables
!      - renormalise by NonWaterFraction where necessary
!      - Update Snow subroutines similarly in terms of water balance
!==================================================================

SUBROUTINE SUEWS_Calculations(Gridiv,ir,iMB,irMax)

  USE data_in
  USE time
  USE NARP_MODULE
  USE defaultNotUsed
  USE allocateArray
  USE sues_data
  USE snowMod
  USE gis_data
  USE initial
  USE moist
  USE mod_z
  USE mod_k
  USE solweig_module
  USE WhereWhen
  USE SUEWS_Driver


  IMPLICIT NONE

  INTEGER        :: Gridiv,ir,ih,iMB
  ! LOGICAL        :: debug=.FALSE.
  ! REAL(KIND(1d0)):: idectime
  !real(kind(1d0)):: SnowDepletionCurve  !for SUEWS_Snow - not needed here (HCW 24 May 2016)
  REAL(KIND(1d0)):: lai_wt
  INTEGER        :: irMax

  !==================================================================
  !==================================================================


  !Translate all data to the variables used in the model calculations
  IF(Diagnose==1) WRITE(*,*) 'Calling SUEWS_Translate...'
  CALL SUEWS_Translate(Gridiv,ir,iMB)

  IF(Diagnose==1) WRITE(*,*) 'Calling RoughnessParameters...'
  ! CALL RoughnessParameters(Gridiv) ! Added by HCW 11 Nov 2014
  CALL RoughnessParameters(&
       RoughLenMomMethod,&! input
       nsurf,& ! number of surface types
       PavSurf,&! surface type code
       BldgSurf,&! surface type code
       WaterSurf,&! surface type code
       ConifSurf,&! surface type code
       BSoilSurf,&! surface type code
       DecidSurf,&! surface type code
       GrassSurf,&! surface type code
       sfr,&! surface fractions
       areaZh,&
       bldgH,&
       EveTreeH,&
       DecTreeH,&
       porosity(id),&
       FAIBldg,FAIEveTree,FAIDecTree,Z,&
       planF,&! output
       Zh,Z0m,Zdm,ZZD)


  ! !=============Get data ready for the qs calculation====================

  ! IF(NetRadiationMethod==0) THEN !Radiative components are provided as forcing
  !    !avkdn=NAN                  !Needed for resistances for SUEWS.
  !    ldown     = NAN
  !    lup       = NAN
  !    kup       = NAN
  !    tsurf     = NAN
  !    lup_ind   = NAN
  !    kup_ind   = NAN
  !    tsurf_ind = NAN
  !    qn1_ind   = NAN
  !    Fcld      = NAN
  ! ENDIF
  !

  ! IF(ldown_option==1) THEN
  !    Fcld = NAN
  ! ENDIF
  ! qh = -999 ! Added HCW 26 Feb 2015
  ! H  = -999 ! Added HCW 26 Feb 2015
  !=====================================================================
  ! Initialisation for OAF's water bucket scheme
  ! LUMPS only (Loridan et al. (2012))
  ! RAINRES = 0.
  ! RAINBUCKET = 0.
  ! E_MOD=0 !RAIN24HR = 0.;

  !=====================================================================

  !Initialize variables calculated at each 5-min timestep
  ! runoffAGveg             = 0
  ! runoffAGimpervious      = 0
  ! runoffWaterBody         = 0
  ! runoffSoil_per_tstep    = 0
  ! runoffSoil_per_interval = 0
  ! chSnow_per_interval     = 0
  ! mwh                     = 0 !Initialize snow melt and heat related to snowmelt
  ! fwh                     = 0
  ! Qm                      = 0 !Heat related to melting/freezing
  ! QmFreez                 = 0
  ! QmRain                  = 0
  ! Mw_ind                  = 0
  ! SnowDepth               = 0
  ! zf                      = 0
  ! deltaQi                 = 0
  ! swe                     = 0
  ! MwStore                 = 0
  ! WaterHoldCapFrac        = 0



  ! Calculate sun position
  IF(Diagnose==1) WRITE(*,*) 'Calling sun_position...'
  CALL sun_position(&
       year,&!input:
       dectime-halftimestep,&! sun position at middle of timestep before
       timezone,lat,lng,alt,&
       azimuth,zenith_deg)!output:
  !write(*,*) DateTime, timezone,lat,lng,alt,azimuth,zenith_deg


  IF(CBLuse>=1)THEN ! If CBL is used, calculated Temp_C and RH are replaced with the obs.
     IF(Diagnose==1) WRITE(*,*) 'Calling CBL...'
     CALL CBL(ir,iMB,Gridiv)   !ir=1 indicates first row of each met data block
  ENDIF

  !Call the dailystate routine to get surface characteristics ready
  IF(Diagnose==1) WRITE(*,*) 'Calling DailyState...'
  CALL DailyState(Gridiv)

  IF(LAICalcYes==0)THEN
     lai(id-1,:)=lai_obs ! check -- this is going to be a problem as it is not for each vegetation class
  ENDIF

  !Calculation of density and other water related parameters
  IF(Diagnose==1) WRITE(*,*) 'Calling atmos_moist_lumps...'
  CALL atmos_moist_lumps(&
                                ! input:
       Temp_C,Press_hPa,avRh,dectime,&
                                ! output:
       lv_J_kg,lvS_J_kg,&
       es_hPa,&
       Ea_hPa,&
       VPd_hpa,&
       VPD_Pa,&
       dq,&
       dens_dry,&
       avcp,&
       avdens)

  !======== Calculate soil moisture =========
  CALL soilMoist_update(&
       nsurf,ConifSurf,DecidSurf,GrassSurf,&!input
       NonWaterFraction,&
       soilstoreCap,sfr,soilmoist,&
       soilmoistCap,soilstate,&!output
       vsmd,smd)


  ! ===================NET ALLWAVE RADIATION================================
  CALL SUEWS_cal_Qn(&
       nsurf,NetRadiationMethod,snowUse,ldown_option,id,&!input
       DecidSurf,ConifSurf,GrassSurf,Diagnose,&
       snow_obs,ldown_obs,fcld_obs,&
       dectime,ZENITH_deg,avKdn,Temp_C,avRH,Press_hPa,qn1_obs,&
       SnowAlb,&
       AlbedoChoice,DiagQN,&
       NARP_G,NARP_TRANS_SITE,NARP_EMIS_SNOW,IceFrac,sfr,emis,&
       alb,albDecTr,DecidCap,albEveTr,albGrass,surf,&!inout
       snowFrac,ldown,fcld,&!output
       qn1,qn1_SF,qn1_S,kclear,kup,lup,tsurf)


  ! ===================SOLWEIG OUTPUT ========================================
  IF (SOLWEIGuse==1) THEN
     IF (OutInterval==imin) THEN
        IF (RunForGrid==-999) THEN
           IF(Diagnose==1) WRITE(*,*) 'Calling SOLWEIG_2014a_core...'
           CALL SOLWEIG_2014a_core(iMB)
           SolweigCount=SolweigCount+1
        ELSE
           IF (Gridiv == RunForGrid) THEN
              IF(Diagnose==1) WRITE(*,*) 'Calling SOLWEIG_2014a_core...'
              CALL SOLWEIG_2014a_core(iMB)
              SolweigCount=SolweigCount+1
           ENDIF
        ENDIF
     ENDIF
  ELSE
     SOLWEIGpoi_out=0
  ENDIF

  ! ===================ANTHROPOGENIC HEAT FLUX================================
  ih=it-DLS
  IF(ih<0) ih=23

  IF(AnthropHeatMethod==1) THEN
     IF(Diagnose==1) WRITE(*,*) 'Calling SAHP_1...'
     CALL SAHP_1(qf_sahp,QF_SAHP_base,QF_SAHP_heat,id,ih,imin)
     qn1_bup=qn1
     qn1=qn1+QF_SAHP
  ELSEIF(AnthropHeatMethod==2) THEN
     IF(Diagnose==1) WRITE(*,*) 'Calling SAHP_2...'
     CALL SAHP_2(qf_sahp,QF_SAHP_base,QF_SAHP_heat,id,ih,imin)
     qn1_bup=qn1
     qn1=qn1+QF_SAHP
  ELSEIF(AnthropHeatMethod==3) THEN
     IF(Diagnose==1) WRITE(*,*) 'Calling SAHP_3...'
     CALL SAHP_3(qf_sahp,id,ih,imin)
     qn1_bup=qn1
     qn1=qn1+QF_SAHP
  ELSE
     qn1_bup=qn1
     qn1=qn1+qf
  ENDIF

  ! -- qn1 is now QSTAR+QF (net all-wave radiation + anthropogenic heat flux)
  ! -- qn1_bup is QSTAR only
  IF(AnthropHeatMethod>=1) THEN
     qf=QF_SAHP
  ENDIF

  ! Calculate CO2 fluxes from anthropogenic components
  IF(Diagnose==1) WRITE(*,*) 'Calling CO2_anthro...'
  CALL CO2_anthro(id,ih,imin)

  ! PRINT*, 'alb in calculations', SHAPE(alb)
  ! PRINT*, 'MetForcingData in calculations', SHAPE(MetForcingData(:,:,Gridiv))
  ! =================STORAGE HEAT FLUX=======================================
  CALL SUEWS_cal_Qs(&
       nsurf,&
                                !  size(MetForcingData(:,:,Gridiv), dim=1),&
       StorageHeatMethod,&
       OHMIncQF,&
       Gridiv,&
       id,&
       Diagnose,&
       sfr,&
       OHM_coef,&
       OHM_threshSW,OHM_threshWD,&
       soilmoist,&
       soilstoreCap,&
       state,&
       nsh,&
       BldgSurf,&
       WaterSurf,&
       SnowUse,&
       DiagQS,&
       HDD(id-1,4),&
       MetForcingData(:,:,Gridiv),&
       qn1,qn1_bup,&
       alb,&
       emis,&
       cpAnOHM,&
       kkAnOHM,&
       chAnOHM,&
       AnthropHeatMethod,&
       qn1_store,&
       qn1_S_store,&
       qn1_av_store,&
       qn1_S_av_store,&
       surf,&
       qn1_S,&
       snowFrac,&
       qs,&
       deltaQi,&
       a1,&
       a2,&
       a3)



  ! For the purpose of turbulent fluxes, remove QF from the net all-wave radiation
  qn1=qn1_bup  !Remove QF from QSTAR

  ! -- qn1 is now QSTAR only



  !==================Energy related to snow melting/freezing processes=======
  IF(Diagnose==1) WRITE(*,*) 'Calling MeltHeat'
  CALL MeltHeat_cal(&
       snowUse,&!input
       bldgsurf,nsurf,PavSurf,WaterSurf,&
       lvS_J_kg,lv_J_kg,tstep_real,&
       RadMeltFact,TempMeltFact,SnowAlbMax,SnowDensMin,&
       Temp_C,Precip,PrecipLimit,PrecipLimitAlb,&
       nsh_real,waterdens,&
       sfr,Tsurf_ind,state,qn1_ind_snow,Meltwaterstore,deltaQi,&
       SnowPack,snowFrac,SnowAlb,SnowDens,& ! inout
       mwh,fwh,Qm,QmFreez,QmRain,CumSnowfall,snowCalcSwitch,&!output
       Qm_melt,Qm_freezState,Qm_rain,FreezMelt,FreezState,FreezStateVol,&
       rainOnSnow,SnowDepth,mw_ind,veg_fr)


  !==========================Turbulent Fluxes================================

  tlv=lv_J_kg/tstep_real !Latent heat of vapourisation per timestep

  IF(Diagnose==1) WRITE(*,*) 'Calling LUMPS_QHQE...'
  !Calculate QH and QE from LUMPS
  CALL LUMPS_QHQE(&
       veg_type,& !input
       snowUse,&
       qn1,&
       qf,&
       qs,&
       Qm,&
       Temp_C,&
       Veg_Fr,&
       avcp,&
       Press_hPa,&
       lv_J_kg,&
       tlv,&
       DRAINRT,&
       nsh_real,&
       Precip,&
       RainMaxRes,&
       RAINCOVER,&
       sfr(ivConif+2:ivGrass+2),&
       lai(id-1,Gridiv),&
       LAImax,&
       LAImin,&
       H_mod,& !output
       E_mod,&
       psyc_hPa,&
       s_hPa,&
       sIce_hpa,&
       TempVeg)


  IF(Diagnose==1) WRITE(*,*) 'Calling WaterUse...'
  !Gives the external and internal water uses per timestep
  CALL WaterUse(&
       nsh_real,&! input:
       SurfaceArea,&
       sfr,&
       IrrFracConif,&
       IrrFracDecid,&
       IrrFracGrass,&
       DayofWeek(id,:),&
       WUProfA_tstep,&
       WUProfM_tstep,&
       InternalWaterUse_h,&
       HDD(id-1,:),&
       WU_Day(id-1,:),&
       WaterUseMethod,&
       ConifSurf,&
       DecidSurf,&
       GrassSurf,&
       NSH,&
       it,imin,DLS,nsurf,&
       OverUse,&
       WUAreaEveTr_m2,&!  output:
       WUAreaDecTr_m2,&
       WUAreaGrass_m2,&
       WUAreaTotal_m2,&
       wu_EveTr,&
       wu_DecTr,&
       wu_Grass,&
       wu_m3,&
       int_wu,&
       ext_wu)

  IF(Precip>0) THEN   !Initiate rain data [mm]
     pin=Precip
  ELSE
     pin=0
  ENDIF



  ! Get first estimate of sensible heat flux. Modified by HCW 26 Feb 2015
  CALL SUEWS_cal_Hinit(&
       qh_obs,avdens,avcp,h_mod,qn1,dectime,&
       H)

  !------------------------------------------------------------------

  IF(Diagnose==1) WRITE(*,*) 'Calling STAB_lumps...'
  !u* and Obukhov length out
  CALL STAB_lumps(&

                                ! input
       StabilityMethod,&
       dectime,& !Decimal time
       zzd,&     !Active measurement height (meas. height-displac. height)
       z0M,&     !Aerodynamic roughness length
       zdm,&     !Displacement height
       avU1,&    !Average wind speed
       Temp_C,&  !Air temperature
       h,    & !Kinematic sensible heat flux [K m s-1] used to calculate friction velocity
                                ! output:
       L_mod,& !Obukhov length
       Tstar,& !T*
       USTAR,& !Friction velocity
       psim)!Stability function of momentum

  IF(Diagnose==1) WRITE(*,*) 'Calling AerodynamicResistance...'
  CALL AerodynamicResistance(&
                                ! input:
       ZZD,&
       z0m,&
       AVU1,&
       L_mod,&
       Ustar,&
       VegFraction,&
       AerodynamicResistanceMethod,&
       StabilityMethod,&
       RoughLenHeatMethod,&
                                ! output:
       RA)     !RA out

  IF (snowUse==1) THEN
     IF(Diagnose==1) WRITE(*,*) 'Calling AerodynamicResistance for snow...'
     !  CALL AerodynamicResistance(RAsnow,AerodynamicResistanceMethod,StabilityMethod,3,&
     ! ZZD,z0m,k2,AVU1,L_mod,Ustar,VegFraction,psyh)      !RA out
     CALL AerodynamicResistance(&
                                ! input:
          ZZD,&
          z0m,&
          AVU1,&
          L_mod,&
          Ustar,&
          VegFraction,&
          AerodynamicResistanceMethod,&
          StabilityMethod,&
          3,&
                                ! output:
          RAsnow)     !RA out
  ENDIF

  IF(Diagnose==1) WRITE(*,*) 'Calling SurfaceResistance...'
  ! CALL SurfaceResistance(id,it)   !qsc and surface resistance out
  CALL  SurfaceResistance(&
       id,it,&! input:
       SMDMethod,&
       ConifSurf,&
       DecidSurf,&
       GrassSurf,&
       WaterSurf,&
       snowFrac,&
       sfr,&
       nsurf,&
       avkdn,&
       Temp_C,&
       dq,&
       xsmd,&
       vsmd,&
       MaxConductance,&
       LaiMax,&
       lai(id-1,:),&
       INT(SurfaceChar(Gridiv,c_gsModel)),&!  gsModel,&
       SurfaceChar(Gridiv,c_GsKmax),&!  Kmax,&
       SurfaceChar(Gridiv,c_GsG1),&! G1,&
       SurfaceChar(Gridiv,c_GsG2),&! G2,&
       SurfaceChar(Gridiv,c_GsG3),&! G3,&
       SurfaceChar(Gridiv,c_GsG4),&! G4,&
       SurfaceChar(Gridiv,c_GsG5),&! G5,&
       SurfaceChar(Gridiv,c_GsG6),&! G6,&
       SurfaceChar(Gridiv,c_GsTH),&! TH,&
       SurfaceChar(Gridiv,c_GsTL),&! TL,&
       SurfaceChar(Gridiv,c_GsS1),&! S1,&
       SurfaceChar(Gridiv,c_GsS2),&! S2,&
       gsc,&! output:
       ResistSurf)

  IF(Diagnose==1) WRITE(*,*) 'Calling BoundaryLayerResistance...'
  CALL BoundaryLayerResistance(&
       zzd,&! input:     !Active measurement height (meas. height-displac. height)
       z0M,&     !Aerodynamic roughness length
       avU1,&    !Average wind speed
       USTAR,&  ! input/output:
       rb)  ! output:

  !========= CO2-related calculations ================================
  ! Calculate CO2 fluxes from biogenic components
  IF(Diagnose==1) WRITE(*,*) 'Calling CO2_biogen...'
  CALL CO2_biogen
  ! Sum anthropogenic and biogenic CO2 flux components to find overall CO2 flux
  Fc = Fc_anthro + Fc_biogen
  !========= CO2-related calculations end================================

  !========= these need to be wrapped================================
  sae   = s_hPa*(qn1_SF+qf-qs)    !s_haPa - slope of svp vs t curve. qn1 changed to qn1_SF, lj in May 2013
  vdrc  = vpd_hPa*avdens*avcp
  sp    = s_hPa/psyc_hPa
  numPM = sae+vdrc/ra
  !write(*,*) numPM, sae, vdrc/ra, s_hPA+psyc_hPa, NumPM/(s_hPA+psyc_hPa)
  !========= these need to be wrapped end================================


  !=====================================================================
  !========= Water balance calculations ================================
  ! Needs to run at small timesteps (i.e. minutes)
  ! Previously, v2014b switched to 60/NSH min intervals here
  ! Now whole model runs at a resolution of tstep

  ! Initialise water balance variables
  ! qe               = 0
  ! ev               = 0
  ! ev_snow          = 0
  ! SurplusEvap      = 0
  ! evap             = 0
  ! chang            = 0
  ! runoff           = 0
  ! runoffSoil       = 0
  ! surplusWaterBody = 0

  ! Added by HCW 13 Feb 2015
  ! qe_per_tstep         = 0     ![W m-2]
  ! ev_per_tstep         = 0
  ! drain_per_tstep      = 0
  ! surf_chang_per_tstep = 0
  ! tot_chang_per_tstep  = 0
  ! state_per_tstep      = 0
  ! NWstate_per_tstep    = 0
  ! runoff_per_tstep     = 0

  ! Retain previous surface state and soil moisture state
  stateOld     = state     !State of each surface [mm] for the previous timestep
  soilmoistOld = soilmoist !Soil moisture of each surface [mm] for the previous timestep

  !============= calculate water balance =============
  CALL SUEWS_cal_water(&
       Diagnose,&!input
       nsurf,&
       snowUse,&
       NonWaterFraction,addPipes,addImpervious,addVeg,addWaterBody,&
       state,&
       sfr,&
       surf,&
       WaterDist,&
       nsh_real,&
       drain_per_tstep,&  !output
       drain,&
       AddWaterRunoff,&
       AdditionalWater,runoffPipes,runoff_per_interval,&
       addWater)
  !============= calculate water balance end =============


  !======== Evaporation and surface state ========
  CALL SUEWS_cal_QE(&
       Diagnose,&!input
       id,&
       nsurf,&
       tstep,&
       imin,&
       it,&
       ity,&
       snowfractionchoice,&
       ConifSurf,&
       BSoilSurf,&
       BldgSurf,&
       PavSurf,&
       WaterSurf,&
       DecidSurf,&
       GrassSurf,&
       snowCalcSwitch,&
       CRWmin,&
       CRWmax,&
       nsh_real,&
       lvS_J_kg,&
       lv_j_kg,&
       avdens,&
       waterdens,&
       avRh,&
       Press_hPa,&
       Temp_C,&
       RAsnow,&
       psyc_hPa,&
       avcp,&
       sIce_hPa,&
       PervFraction,&
       vegfraction,&
       addimpervious,&
       numPM,&
       s_hPa,&
       ResistSurf,&
       sp,&
       ra,&
       rb,&
       tlv,&
       snowdensmin,&
       precip,&
       PipeCapacity,&
       RunoffToWater,&
       pin,&
       NonWaterFraction,&
       wu_EveTr,&
       wu_DecTr,&
       wu_Grass,&
       addVeg,&
       addWaterBody,&
       SnowLimPaved,&
       SnowLimBuild,&
       SurfaceArea,&
       drain,&
       WetThresh,&
       stateold,&
       mw_ind,&
       soilstorecap,&
       rainonsnow,&
       freezmelt,&
       freezstate,&
       freezstatevol,&
       Qm_Melt,&
       Qm_rain,&
       Tsurf_ind,&
       sfr,&
       StateLimit,&
       DayofWeek,&
       surf,&
       runoff_per_interval,&!inout:
       snowPack,&
       snowFrac,&
       MeltWaterStore,&
       SnowDepth,&
       iceFrac,&
       addwater,&
       addwaterrunoff,&
       SnowDens,&
       SurplusEvap,&
       snowProf,&  !out:
       runoffSnow,&
       runoff,&
       runoffSoil,&
       chang,&
       changSnow,&
       SnowToSurf,&
       state,&
       snowD,&
       ev_snow,&
       soilmoist,&
       SnowRemoval,&
       evap,&
       rss_nsurf,&
       p_mm,&
       rss,&
       qe,&
       state_per_tstep,&
       NWstate_per_tstep,&
       qeOut,&
       swe,&
       ev,&
       chSnow_per_interval,&
       ev_per_tstep,&
       qe_per_tstep,&
       runoff_per_tstep,&
       surf_chang_per_tstep,&
       runoffPipes,&
       mwstore,&
       runoffwaterbody,&
       FlowChange,&
       runoffAGimpervious_m3,&
       runoffAGveg_m3,&
       runoffWaterBody_m3,&
       runoffPipes_m3)


  !============ Sensible heat flux ===============
  CALL SUEWS_cal_QH(&
       1,&
       qn1,&
       qf,&
       QmRain,&
       qeOut,&
       qs,&
       QmFreez,&
       qm,&
       avdens,&
       avcp,&
       tsurf,&
       Temp_C,&
       ra,&
       qh)


  !=== Horizontal movement between soil stores ===
  ! Now water is allowed to move horizontally between the soil stores
  IF(Diagnose==1) WRITE(*,*) 'Calling HorizontalSoilWater...'
  ! CALL HorizontalSoilWater
  CALL HorizontalSoilWater(&
       nsurf,&! input:
       sfr,&! surface fractions
       SoilStoreCap,&!Capacity of soil store for each surface [mm]
       SoilDepth,&!Depth of sub-surface soil store for each surface [mm]
       SatHydraulicConduct,&!Saturated hydraulic conductivity for each soil subsurface [mm s-1]
       SurfaceArea,&!Surface area of the study area [m2]
       NonWaterFraction,&! sum of surface cover fractions for all except water surfaces
       tstep_real,& !tstep cast as a real for use in calculations
                                ! inout:
       SoilMoist,&!Soil moisture of each surface type [mm]
       runoffSoil,&!Soil runoff from each soil sub-surface [mm]
       runoffSoil_per_tstep&!Runoff to deep soil per timestep [mm] (for whole surface, excluding water body)
       )

  !========== Calculate soil moisture ============
  soilstate=0       !Area-averaged soil moisture [mm] for whole surface
  IF (NonWaterFraction/=0) THEN !Fixed for water surfaces only
     DO is=1,nsurf-1   !No water body included
        soilstate=soilstate+(soilmoist(is)*sfr(is)/NonWaterFraction)
        IF (soilstate<0) THEN
           CALL ErrorHint(62,'SUEWS_Calculations: total soilstate < 0 (just added surface is) ',soilstate,NotUsed,is)
        ELSEIF (soilstate>SoilMoistCap) THEN
           CALL ErrorHint(62,'SUEWS_Calculations: total soilstate > capacity (just added surface is) ',soilstate,NotUsed,is)
           !SoilMoist_state=soilMoistCap !What is this LJ 10/2010 - SM exceeds capacity, but where does extra go?HCW 11/2014
        ENDIF
     ENDDO  !end loop over surfaces
  ENDIF
  ! Calculate soil moisture deficit
  smd=soilMoistCap-soilstate   !One value for whole surface
  smd_nsurf=SoilstoreCap-soilmoist   !smd for each surface


  ! Soil stores can change after horizontal water movements
  ! Calculate total change in surface and soil state
  tot_chang_per_tstep = surf_chang_per_tstep   !Change in surface state
  DO is=1,(nsurf-1)   !No soil for water surface (so change in soil moisture is zero)
     tot_chang_per_tstep = tot_chang_per_tstep + ((SoilMoist(is)-SoilMoistOld(is))*sfr(is))   !Add change in soil state
  ENDDO


  !============ surface-level diagonostics ===============
  CALL SUEWS_cal_diag(&
       0.,0.,&!input
       tsurf,qh,&
       Press_hPa,qeOut,&
       ustar,veg_fr,z0m,L_mod,k,avdens,avcp,tlv,&
       RoughLenHeatMethod,StabilityMethod,&
       avU10_ms,t2_C,q2_gkg)!output
  !============ surface-level diagonostics end ===============


  !=====================================================================
  !====================== Prepare data for output ======================

  ! Check surface composition (HCW 21 Jul 2016)
  ! if totally water surface, set output to -999 for columns that do not exist
  !IF(sfr(WaterSurf)==1) THEN
  !   NWstate_per_tstep = NAN    !no non-water surface
  !   smd = NAN                  !no soil store beneath water surface
  !   soilstate = NAN
  !   runoffSoil_per_tstep = NAN
  !   drain_per_tstep = NAN      !no drainage from water surf
  !ENDIF
  !These removed as now all these get a value of 0. LJ 15/06/2017

  ! Remove non-existing surface type from surface and soil outputs   ! Added back in with NANs by HCW 24 Aug 2016
  DO is=1,nsurf
     IF (sfr(is)<0.00001) THEN
        stateOut(is)= NAN
        smd_nsurfOut(is)= NAN
        !runoffOut(is)= NAN
        !runoffSoilOut(is)= NAN
     ELSE
        stateOut(is)=state(is)
        smd_nsurfOut(is)=smd_nsurf(is)
        !runoffOut(is)=runoff(is)
        !runoffSoilOut(is)=runoffSoil(is)
     ENDIF
  ENDDO

  ! Remove negative state   !ErrorHint added, then commented out by HCW 16 Feb 2015 as should never occur
  !if(st_per_interval<0) then
  !   call ErrorHint(63,'SUEWS_Calculations: st_per_interval < 0',st_per_interval,NotUsed,NotUsedI)
  !   !st_per_interval=0
  !endif

  !Set limits on output data to avoid formatting issues ---------------------------------
  ! Set limits as +/-9999, depending on sign of value
  ! errorHints -> warnings commented out as writing these slow down the code considerably when there are many instances
  IF(ResistSurf > 9999) THEN
     !CALL errorHint(6,'rs set to 9999 s m-1 in output; calculated value > 9999 s m-1',ResistSurf,notUsed,notUsedI)
     ResistSurf=9999
  ENDIF

  IF(l_mod > 9999) THEN
     !CALL errorHint(6,'Lob set to 9999 m in output; calculated value > 9999 m',L_mod,notUsed,notUsedI)
     l_mod=9999
  ELSEIF(l_mod < -9999) THEN
     !CALL errorHint(6,'Lob set to -9999 m in output; calculated value < -9999 m',L_mod,notUsed,notUsedI)
     l_mod=-9999
  ENDIF


  ! Set NA values   !!Why only these variables??  !!ErrorHints here too - error hints can be very slow here
  IF(ABS(qh)>pNAN) qh=NAN
  IF(ABS(qh_r)>pNAN) qh_r=NAN
  IF(ABS(qeOut)>pNAN) qeOut=NAN
  IF(ABS(qs)>pNAN) qs=NAN
  IF(ABS(ch_per_interval)>pNAN) ch_per_interval=NAN
  IF(ABS(surf_chang_per_tstep)>pNAN) surf_chang_per_tstep=NAN
  IF(ABS(tot_chang_per_tstep)>pNAN) tot_chang_per_tstep=NAN
  IF(ABS(soilstate)>pNAN) soilstate=NAN
  IF(ABS(smd)>pNAN) smd=NAN

  ! If measured smd is used, set components to -999 and smd output to measured one
  IF (SMDMethod>0) THEN
     smd_nsurf=NAN
     smd_nsurfOut=NAN
     smd=xsmd
  ENDIF

  ! Calculate areally-weighted LAI
  IF(iy == (iy_prev_t+1) .AND. (id-1) == 0) THEN   !Check for start of next year and avoid using lai(id-1) as this is at the start of the year
     lai_wt=0
     DO is=1,nvegsurf
        lai_wt=lai_wt+lai(id_prev_t,is)*sfr(is+2)
     ENDDO
  ELSE
     lai_wt=0
     DO is=1,nvegsurf
        lai_wt=lai_wt+lai(id-1,is)*sfr(is+2)
     ENDDO
  ENDIF

  ! Calculate areally-weighted albedo
  bulkalbedo = 0
  DO is=1,nsurf
     bulkalbedo = bulkalbedo + alb(is)*sfr(is)
  ENDDO

  ! Save qh and qe for CBL in next iteration
  IF(Qh_choice==1) THEN   !use QH and QE from SUEWS
     qhforCBL(Gridiv) = qh
     qeforCBL(Gridiv) = qeOut
  ELSEIF(Qh_choice==2)THEN   !use QH and QE from LUMPS
     qhforCBL(Gridiv) = h_mod
     qeforCBL(Gridiv) = e_mod
  ELSEIF(qh_choice==3)THEN  !use QH and QE from OBS
     qhforCBL(Gridiv) = qh_obs
     qeforCBL(Gridiv) = qe_obs
     IF(qh_obs<-900.OR.qe_obs<-900)THEN  ! observed data has a problem
        CALL ErrorHint(22,'Unrealistic observed qh or qe_value.',qh_obs,qe_obs,qh_choice)
     ENDIF
  ENDIF


  !=====================================================================
  !====================== Write out files ==============================
  !Define the overall output matrix to be printed out step by step
  dataOut(ir,1:ncolumnsDataOut,Gridiv)=(/REAL(iy,KIND(1D0)),REAL(id,KIND(1D0)),REAL(it,KIND(1D0)),REAL(imin,KIND(1D0)),dectime,&   !5
       avkdn,kup,ldown,lup,tsurf,&
       qn1,qf,qs,qh,qeOut,&
       h_mod,e_mod,qh_r,&
       precip,ext_wu,ev_per_tstep,runoff_per_tstep,tot_chang_per_tstep,&
       surf_chang_per_tstep,state_per_tstep,NWstate_per_tstep,drain_per_tstep,smd,&
       FlowChange/nsh_real,AdditionalWater,&
       runoffSoil_per_tstep,runoffPipes,runoffAGimpervious,runoffAGveg,runoffWaterBody,&
       int_wu,wu_EveTr,wu_DecTr,wu_Grass,&
       (smd_nsurfOut(is),is=1,nsurf-1),&
       (stateOut(is),is=1,nsurf),&
       zenith_deg,azimuth,bulkalbedo,Fcld,&
       lai_wt,z0m,zdm,&
       ustar,l_mod,ra,ResistSurf,&
       Fc,&
       Fc_photo,Fc_respi,Fc_metab,Fc_traff,Fc_build,&
       qn1_SF,qn1_S,SnowAlb,&
       Qm,QmFreez,QmRain,swe,mwh,MwStore,chSnow_per_interval,&
       (SnowRemoval(is),is=1,2),&
       t2_C,q2_gkg,avU10_ms& ! surface-level diagonostics
       /)

  IF (snowUse==1) THEN
     dataOutSnow(ir,1:ncolumnsDataOutSnow,Gridiv)=(/REAL(iy,KIND(1D0)),REAL(id,KIND(1D0)),&               !2
          REAL(it,KIND(1D0)),REAL(imin,KIND(1D0)),dectime,&                                        !5
          SnowPack(1:nsurf),mw_ind(1:nsurf),Qm_melt(1:nsurf),&                                     !26
          Qm_rain(1:nsurf),Qm_freezState(1:nsurf),snowFrac(1:(nsurf-1)),&                          !46
          rainOnSnow(1:nsurf),&                                                                    !53
          qn1_ind_snow(1:nsurf),kup_ind_snow(1:nsurf),freezMelt(1:nsurf),&                         !74
          MeltWaterStore(1:nsurf),SnowDens(1:nsurf),&                                              !88
          snowDepth(1:nsurf),Tsurf_ind_snow(1:nsurf)/)                                             !102
  ENDIF

  !Calculate new snow fraction used in the next timestep if snowUse==1
  !Calculated only at end of each hour.
  !if (SnowFractionChoice==2.and.snowUse==1.and.it==23.and.imin==(nsh_real-1)/nsh_real*60) then
  !   do is=1,nsurf-1
  !      if ((snowPack(is)>0.and.mw_ind(is)>0)) then
  !         write(*,*) is,snowPack(is),snowD(is),mw_ind(is),snowFrac(is)!

  !         snowFrac(is)=SnowDepletionCurve(is,snowPack(is),snowD(is))
  !         write(*,*) snowFrac(is)
  !         pause
  !      elseif (snowPack(is)==0) then
  !         snowFrac(is)=0
  !      endif
  !   enddo
  !endif


  !write(*,*) DecidCap(id), id, it, imin, 'Calc - before translate back'
  !write(*,*) iy, id, it, imin, 'Calc - before translate back'
  !if(Gridiv==1)  write(*,*) iy, id, it, imin, HDD(id-1,5), HDD(id,5), HDD(id-1,6), HDD(id,6)
  !if(id==12) pause
  !write(*,*) ' '

  IF(Diagnose==1) WRITE(*,*) 'Calling SUEWS_TranslateBack...'
  CALL SUEWS_TranslateBack(Gridiv,ir,irMax)

  !  ! store water balance states of the day, by TS 13 Apr 2016
  !  IF ( ir==irMax ) THEN
  !       PRINT*, 'ending end of', id,it,imin
  !     stateDay(id,Gridiv,:)     = state(:)
  !     soilmoistDay(id,Gridiv,:) = soilmoist(:)
  !       PRINT*, 'state:', state
  !       PRINT*, 'soilmoist', soilmoist
  !       PRINT*, '********************************'
  !  END IF

  ! if ( id>10 ) then
  !   stop "stop to test state"
  ! end if

!!!if((id <=3 .or. id > 364).and. it == 0 .and. imin == 0) pause
!!!if((id <=3 .or. id > 364).and. it == 23 .and. imin == 55) pause
!!!if((id >=100 .or. id < 103).and. it == 0 .and. imin == 0) pause

  ! write(*,*) '------------'

END SUBROUTINE SUEWS_Calculations

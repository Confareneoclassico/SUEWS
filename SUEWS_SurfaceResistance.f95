SUBROUTINE SurfaceResistance(&

     ! input:
     SMDMethod,&
     ConifSurf,&
     DecidSurf,&
     GrassSurf,&
     WaterSurf,&
    !  ivConif,&
    !  ivGrass,&
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
     lai_id,&
     gsModel,&
     Kmax,&
     G1,&
     G2,&
     G3,&
     G4,&
     G5,&
     G6,&
     TH,&
     TL,&
     S1,&
     S2,&
     ! output:
    !  gl,&
    !  QNM,&
    !  gq,&
    !  gdq,&
    !  TC,&
    !  TC2,&
    !  gtemp,&
    !  sdp,&
    !  gs,&
     gsc,&
     ResistSurf)
  ! Calculates bulk surface resistance (ResistSurf [s m-1]) based on Jarvis 1976 approach
  ! Last modified -----------------------------------------------------
  ! HCW 21 Jul 2016: If no veg surfaces, vsmd = NaN so QE & QH = NaN; if water surfaces only, smd = NaN so QE & QH = NaN.
  !                  Add checks here so that gs (soil part) = 0 in either of these situations.
  !                  This shouldn't change results but handles NaN error.
  ! HCW 01 Mar 2016: SM dependence is now on modelled smd for vegetated surfaces only (vsmd) (Note: obs smd still not operational!)
  ! HCW 18 Jun 2015: Alternative gs parameterisation added using different functional forms and new coefficients
  ! HCW 31 Jul 2014: Modified condition on g6 part to select meas/mod smd
  ! LJ  24 Apr 2013: Added impact of snow fraction in LAI and in soil moisture deficit
  ! -------------------------------------------------------------------

  ! USE allocateArray
  ! USE data_in
  ! USE defaultNotUsed
  ! USE gis_data
  ! USE moist
  ! USE resist
  ! USE sues_data

  IMPLICIT NONE

  INTEGER,INTENT(in):: &
       gsModel,&!Choice of gs parameterisation (1 = Ja11, 2 = Wa16)
       SMDMethod,&!Method of measured soil moisture
       ConifSurf,&!= 3, surface code
       DecidSurf,&!= 4, surface code
       GrassSurf,&!= 5, surface code
       WaterSurf,&!= 7, surface code
      !  ivConif,&!= 1, When only vegetated surfaces considered (1-3)
      !  ivGrass,&!= 3, When only vegetated surfaces considered (1-3)
       nsurf!= 7, Total number of surfaces


  REAL(KIND(1d0)),INTENT(in):: &
       avkdn,&!Average downwelling shortwave radiation
       Temp_C,&!Air temperature
       Kmax,&!Annual maximum hourly solar radiation
       G1,&!Fitted parameters related to surface res. calculations
       G2,&!Fitted parameters related to surface res. calculations
       G3,&!Fitted parameters related to surface res. calculations
       G4,&!Fitted parameters related to surface res. calculations
       G5,&!Fitted parameters related to surface res. calculations
       G6,&!Fitted parameters related to surface res. calculations
       S1,&!Fitted parameters related to surface res. calculations
       S2,&!Fitted parameters related to surface res. calculations
       TH,&!Maximum temperature limit
       TL,&!Minimum temperature limit
       dq,&!Specific humidity deficit
       xsmd,&!Measured soil moisture deficit
       vsmd,&!Soil moisture deficit for vegetated surfaces only (what about BSoil?)
       MaxConductance(3),&!Max conductance [mm s-1]
       LaiMax(3),&!Max LAI  [m2 m-2]
       lai_id(3),&!=lai_id(id-1,:), LAI for each veg surface [m2 m-2]
       snowFrac(nsurf),&!Surface fraction of snow cover
       sfr(nsurf)!Surface fractions [-]


  REAL(KIND(1d0)),INTENT(out):: &
      !  gl,&!G(LAI)
      !  gsc,&!Surface Layer Conductance
      !  QNM,&!QMAX/(QMAX+G2)
      !  gq,&!G(Q*)
      !  gdq,&!G(dq)
      !  TC,&!Temperature parameter 1
      !  TC2,&!Temperature parameter 2
      !  gtemp,&!G(T)
      !  sdp,&!S1/G6+S2
      !  gs,&!G(Soil moisture deficit)
      gsc,&!Surface Layer Conductance
       ResistSurf!Surface resistance

REAL(KIND(1d0)):: &
     gl,&!G(LAI)
     QNM,&!QMAX/(QMAX+G2)
     gq,&!G(Q*)
     gdq,&!G(dq)
     TC,&!Temperature parameter 1
     TC2,&!Temperature parameter 2
     gtemp,&!G(T)
     sdp,&!S1/G6+S2
     gs!G(Soil moisture deficit)


  INTEGER:: id,it,iv
  REAL(KIND(1d0)):: id_real

  INTEGER,PARAMETER :: notUsed=-55
  REAL(KIND(1d0)),PARAMETER :: notUsedi=-55.5

  id_real = REAL(id) !Day of year in real number

  !gsModel = 1 - original parameterisation (Jarvi et al. 2011)
  !gsModel = 2 - new parameterisation (Ward et al. 2016)

  IF(gsModel == 1) THEN
     IF(avkdn<=0) THEN   !At nighttime set gsc at arbitrary low value: gsc=0.1 mm/s (Shuttleworth, 1988b)
        gsc=0.1   !Is this limit good here? ZZ
     ELSE
        ! kdown ----
        QNM=Kmax/(Kmax+G2)
        !gq=(qn1/(g2+qn1))/qnm !With net all-wave radiation
        gq=(avkdn/(G2+avkdn))/QNM !With Kdown

        ! specific humidity deficit ----
        IF(dq<G4) THEN
           gdq=1-G3*dq
        ELSE
           gdq=1-G3*G4
        ENDIF

        ! air temperature ----
        TC=(TH-G5)/(G5-TL)
        TC2=(G5-TL)*(TH-G5)**TC
        !If air temperature below TL or above TH, fit it to TL+0.1/TH-0.1
        IF (Temp_C<=tl) THEN
           gtemp=(tl+0.1-tl)*(th-(tl+0.1))**tc/tc2

           !Call error only if no snow on ground
           !  IF (MIN(snowFrac(1),snowFrac(2),snowFrac(3),snowFrac(4),snowFrac(5),snowFrac(6))/=1) THEN
           IF (MINVAL(snowFrac(1:6))/=1) THEN
              CALL errorHint(29,'subroutine SurfaceResistance.f95: T changed to fit limits TL=0.1,Temp_c,id,it',&
                   REAL(Temp_c,KIND(1d0)),id_real,it)
           ENDIF

        ELSEIF (Temp_C>=th) THEN
           gtemp=((th-0.1)-tl)*(th-(th-0.1))**tc/tc2
           CALL errorHint(29,'subroutine SurfaceResistance.f95: T changed to fit limits TH=39.9,Temp_c,id,it',&
                REAL(Temp_c,KIND(1d0)),id_real,it)
        ELSE
           gtemp=(Temp_C-tl)*(th-Temp_C)**tc/tc2
        ENDIF

        ! soil moisture deficit ----
        sdp=S1/G6+S2
        IF(SMDMethod>0)THEN         !Modified from ==1 to > 0 by HCW 31/07/2014
           gs=1-EXP(g6*(xsmd-sdp))  !Measured soil moisture deficit is used
        ELSE
           gs=1-EXP(g6*(vsmd-sdp))   !Modelled is used
           IF(sfr(ConifSurf) + sfr(DecidSurf) + sfr(GrassSurf) == 0 .OR. sfr(WaterSurf)==1 ) THEN
              gs=0   !If no veg so no vsmd, or all water so no smd, set gs=0 (HCW 21 Jul 2016)
           ENDIF
        ENDIF

        gs = gs*(1-SUM(snowFrac(1:6))/6)

        IF(gs<0)THEN
           CALL errorHint(65,'subroutine SurfaceResistance.f95 (gsModel=1): g(smd) < 0 calculated, setting to 0.0001',gs,id_real,it)
           gs=0.0001
        ENDIF

        !LAI
        !Original way
        !gl=((lai(id,2)*areaunir/lm)+areair)/(areair+areaunir)
        !New way
        gl=0    !First initialize
        ! vegetated surfaces
        ! check basis for values koe - maximum surface conductance
        !  print*,id,it,sfr
        ! DO iv=ivConif,ivGrass
        DO iv=1,3
           ! gl=gl+(sfr(iv+2)*(1-snowFrac(iv+2)))*lai(id-1,iv)/LaiMax(iv)*MaxConductance(iv)
           gl=gl+(sfr(iv+2)*(1-snowFrac(iv+2)))*lai_id(iv)/LaiMax(iv)*MaxConductance(iv)
        ENDDO

        ! Multiply parts together
        gsc=(G1*gq*gdq*gtemp*gs*gl)

        IF(gsc<=0) THEN
           CALL errorHint(65,'subroutine SurfaceResistance.f95 (gsModel=1): gs <= 0, setting to 0.1 mm s-1',gsc,id_real,it)
           gsc=0.1
        ENDIF
     ENDIF

  ELSEIF(gsModel == 2) THEN
     IF(avkdn<=0) THEN      !At nighttime set gsc at arbitrary low value: gsc=0.1 mm/s (Shuttleworth, 1988b)
        gsc=0.1
     ELSE
        ! ---- g(kdown)----
        QNM = Kmax/(Kmax+G2)
        gq = (avkdn/(avkdn+G2))/QNM
        IF(avkdn >= Kmax) THEN   !! Add proper error handling later - HCW!!
           WRITE(*,*) 'Kmax exceeds Kdn setting to g(Kdn) to 1'
           gq = 1
        ENDIF
        ! ---- g(delq) ----
        gdq = G3 + (1-G3)*(G4**dq)   !Ogink-Hendriks (1995) Eq 12 (using G3 as Kshd and G4 as r)
        ! ---- g(Tair) ----
        Tc=(TH-G5)/(G5-TL)
        Tc2=(G5-TL)*(TH-G5)**Tc
        ! If air temperature below TL or above TH, then use value for TL+0.1 or TH-0.1
        IF (Temp_C <= TL) THEN
           gtemp=(TL+0.1-TL)*(TH-(TL+0.1))**Tc/Tc2
           ! Call error only if no snow on ground
           IF (MIN(snowFrac(1),snowFrac(2),snowFrac(3),snowFrac(4),snowFrac(5),snowFrac(6))/=1) THEN
              CALL errorHint(29,'subroutine SurfaceResistance.f95: T changed to fit limits TL+0.1,Temp_C,id,it',&
                   REAL(Temp_c,KIND(1d0)),id_real,it)
           ENDIF
        ELSEIF (Temp_C >= TH) THEN
           gtemp=((TH-0.1)-TL)*(TH-(TH-0.1))**Tc/Tc2
           CALL errorHint(29,'subroutine SurfaceResistance.f95: T changed to fit limits TH-0.1,Temp_C,id,it',&
                REAL(Temp_c,KIND(1d0)),id_real,it)
        ELSE
           gtemp=(Temp_C-TL)*(TH-Temp_C)**Tc/Tc2
        ENDIF
        ! ---- g(smd) ----
        sdp=S1/G6+S2
        IF(SMDMethod>0) THEN   !Modified from ==1 to > 0 by HCW 31/07/2014
           gs=(1-EXP(g6*(xsmd-sdp)))/(1-EXP(g6*(-sdp)))   !Use measured smd
        ELSE
           !gs=1-EXP(g6*(vsmd-sdp))   !Use modelled smd
           gs=(1-EXP(g6*(vsmd-sdp)))/(1-EXP(g6*(-sdp)))
           IF(sfr(ConifSurf) + sfr(DecidSurf) + sfr(GrassSurf) == 0 .OR. sfr(WaterSurf)==1 ) THEN
              gs=0   !If no veg so no vsmd, or all water so no smd, set gs=0 HCW 21 Jul 2016
           ENDIF
        ENDIF

        gs = gs*(1-SUM(snowFrac(1:6))/6)

        IF(gs<0)THEN
           CALL errorHint(65,'subroutine SurfaceResistance.f95 (gsModel=2): gs < 0 calculated, setting to 0.0001',gs,id_real,it)
           gs=0.0001
        ENDIF

        ! ---- g(LAI) ----
        gl=0    !Initialise
        ! DO iv=ivConif,ivGrass   !For vegetated surfaces
          DO iv=1,3   !For vegetated surfaces
           !  gl=gl+(sfr(iv+2)*(1-snowFrac(iv+2)))*lai(id-1,iv)/LaiMax(iv)*MaxConductance(iv)
           gl=gl+(sfr(iv+2)*(1-snowFrac(iv+2)))*lai_id(iv)/LaiMax(iv)*MaxConductance(iv)
        ENDDO

        ! Multiply parts together
        gsc=(G1*gq*gdq*gtemp*gs*gl)

        IF(gsc<=0) THEN
           CALL errorHint(65,'subroutine SurfaceResistance.f95 (gsModel=2): gsc <= 0, setting to 0.1 mm s-1',gsc,id_real,it)
           gsc=0.1
        ENDIF

     ENDIF

  ELSEIF(gsModel < 1 .OR. gsModel > 2) THEN
     CALL errorHint(71,'Value of gsModel not recognised.',notUsed,NotUsed,gsModel)
  ENDIF

  ResistSurf=1/(gsc/1000)  ![s m-1]

  RETURN
END SUBROUTINE SurfaceResistance

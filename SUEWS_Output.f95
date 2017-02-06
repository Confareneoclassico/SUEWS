!In this subroutine the output files will be opened and the output matrices will be printed out.
!
!Last change:
! HCW 12 Dec 2016 - Restructured writing of output files and introduced families of output variables
! HCW 04 Jul 2016 - GridID can now be up to 10 digits long. If file not found or not read correctly, program stops
! HCW 29 Jun 2016 - Fixed bug in output file (4 columns were repeated twice)
!                 - Changed ESTM output file to be written for more than one met block
! HCW 25 May 2016 - changed QF, QH QE in output file to qf, qh, qe to match input file. Also e.g. RA, RS, L_mod -> ra, rs, L_Ob
! HCW 12 Nov 2015
! Added z0m and zdm to output file
! HCW 27 Apr 2015
! Increased output resolution of water balance components (N.B. model time steps < 5 min may require higher precision)
! LJ in 13 April 2014
! FL in 10 June 2014
! HCW 18 Nov 2014
! LJ 5 Jan 2015: code cleaned, daily and monthly filesaving added
!-----------------------------------------------------------------------------------------------
SUBROUTINE SUEWS_Output(Gridiv, year_int, iv, irMax, CurrentGrid)
  !INPUT: Gridiv   = Grid number
  !       year_int = Year as a integer
  !       iv       = Block number of met data
  !       irMax    = Maximum number of rows in met data
  !       CurrentGrid   = Grid ID (according to SiteSelect.txt)

  USE allocateArray
  USE cbl_module
  USE data_in
  USE defaultNotUsed
  USE ESTM_data
  USE gis_data
  USE initial
  USE solweig_module
  USE sues_data 
  USE time

  IMPLICIT NONE

  INTEGER:: Gridiv, year_int, iv, irMax, CurrentGrid !inputs
  INTEGER:: i  
  
  CHARACTER(len=10):: str2, grstr2, yrstr2
  CHARACTER(len=100):: rawpath, SnowOut,ESTMOut, FileOutFormat

  ! N.B. if change lengths here, also adjust in MODULE AllocateArray accordingly
  CHARACTER(len=10),DIMENSION(nColumnsDataOut):: HeaderAll, FormatAll  !Header and formats for all output variables
  CHARACTER(len=14*nColumnsDataOut):: HeaderOut, FormatOut             !Header and format for selected output variables (untrimmed) 
  CHARACTER(len=12*nColumnsDataOut):: FormatOutNoSep, HeaderOutNoSep   !Format for selected output variables (not comma sep)
  CHARACTER(len=12),DIMENSION(nColumnsDataOut):: UnitsAll              !Units for all output variables
  CHARACTER(len=14*nColumnsDataOut):: UnitsOut                         !Units for selected output variables
  CHARACTER(len=50),DIMENSION(nColumnsDataOut):: LongNmAll             !LongName for all output variables
  CHARACTER(len=52*nColumnsDataOut):: LongNmOut                        !LongName for selected output variables (untrimmed)
  CHARACTER(len= 1),DIMENSION(nColumnsDataOut):: AggregAll             !Aggregation method required for all output variables
  CHARACTER(len= 3*nColumnsDataOut):: AggregOut                        !Aggregation method required for selected output variables
  CHARACTER(len= 4*nColumnsDataOut):: ColNos
  
  CHARACTER(len=10):: fy, ft, fd, f94, f104, f106   !Useful formats
  CHARACTER(len= 1):: aT, aA, aS, aL   !Useful formats
  CHARACTER(len= 3):: itext

  ! Define useful formats here  
  fy   = '(i0004,1X)'   !4 digit integer for year
  ft   = '(i0003,1X)'   !3 digit integer for id, it, imin
  fd   = '(f08.4,1X)'   !3 digits + 4 dp for dectime
  f94  = '(f09.4,1X)'   !standard output format: 4 dp + 4 digits
  f104 = '(f10.4,1X)'   !standard output format: 4 dp + 5 digits
  f106 = '(f10.6,1X)'   !standard output format: 6 dp + 3 digits
  ! Define aggregation methods here (for wrapper)
  aT = '0'   !time columns
  aA = '1'   !average
  aS = '2'   !sum
  aL = '3'   !last value
  
  !========== Set file path and file names ==========
  WRITE(str2,'(i2)') TSTEP/60
  WRITE(grstr2,'(i10)') CurrentGrid
  WRITE(yrstr2,'(i4)') year_int

  rawpath=TRIM(FileOutputPath)//TRIM(FileCode)//TRIM(ADJUSTL(grstr2))//'_'//TRIM(ADJUSTL(yrstr2))
  FileOut=TRIM(rawpath)//'_'//TRIM(ADJUSTL(str2))//'.txt'
  SOLWEIGpoiOut=TRIM(rawpath)//'_SOLWEIGpoiOut.txt'
  ESTMOut=TRIM(rawpath)//'_ESTM_5.txt'
  BLOut=TRIM(rawpath)//'_BL.txt'
  SnowOut=TRIM(rawpath)//'_snow_5.txt'
  FileOutFormat=TRIM(FileOutputPath)//TRIM(FileCode)//'_YYYY_'//TRIM(ADJUSTL(str2))//'_OutputFormat.txt'
  
  
  !========== Get headers and write out output info to file ==========
  ! To add extra columns, change all these (Header, Units, LongNm, Format, Agg) together
  ! Could change to read from external file later
  IF(OutputFormats==1) THEN   !Once per run
     ! Set all output variables here. This must agree with dataOut (see SUEWS_Calculations.f95)
     HeaderAll(:) = '-'   !Initialise
     UnitsAll (:) = '-'
     FormatAll(:) = '-'
     AggregAll(:) = '-'
     LongNmAll(:) = '-'
     
     HeaderAll(1:5) = (/'   Year','    DOY','   Hour','    Min','Dectime'/)   !datetime info
     UnitsAll (1:5) = (/'   YYYY','    DOY','     HH','     MM','      -'/)
     FormatAll(1:5) = (/fy,ft,ft,ft,fd/)
     AggregAll(1:5) = aT
     LongNmAll(1:5) = (/'        Year',' Day of Year','        Hour','      Minute','Decimal time'/)     
     
     HeaderAll(6:9) = (/'Kdown','  Kup','Ldown','  Lup'/)  !radiation components
     UnitsAll (6:9) = 'W_m-2'
     FormatAll(6:9) = f94
     AggregAll(6:9) = aA
     LongNmAll(6:9) = (/'Incoming shortwave radiation','Outgoing shortwave radiation', &
                        ' Incoming longwave radiation',' Outgoing longwave radiation'/)
     
     HeaderAll(10) = 'Tsurf'
     UnitsAll (10) = 'degC'     
     FormatAll(10) = f94
     AggregAll(10) = aA
     LongNmAll(10) = 'Bulk surface temperature'
     
     HeaderAll(11:15) = (/'QN','QF','QS','QH','QE'/)  !energy fluxes
     UnitsAll (11:15) = 'W_m-2'
     FormatAll(11:15) = f94
     AggregAll(11:15) = aA
     LongNmAll(11:15) = (/' Net all-wave radiation','Anthropogenic heat flux','  Net storage heat flux', &
                          '     Sensible heat flux','       Latent heat flux'/)

     HeaderAll(16:18) = (/'QHlumps','QElumps','QHresis'/)   !energy fluxes (other approaches) 
     UnitsAll (16:18)  = 'W_m-2'
     FormatAll(16:18) = f94
     AggregAll(16:18) = aA
     LongNmAll(16:18) = (/ '      Sensible heat flux (using LUMPS)','        Latent heat flux (using LUMPS)', &
                           'Sensible heat flux (resistance method)'/)
     
     HeaderAll(19:23) = (/' Rain','  Irr',' Evap','   RO','TotCh'/)   !water balance components
     UnitsAll (19:23) = 'mm'
     FormatAll(19:23) = f106 
     AggregAll(19:23) = aS
     LongNmAll(19:23) = (/'                            Rain','                      Irrigation', &
                          '                     Evaporation','                          Runoff', &
                          'Surface and soil moisture change'/)
     
     HeaderAll(24:28) = (/'    SurfCh','     State',' NWtrState','  Drainage','       SMD'/)   !water balance components cont.
     UnitsAll (24:28) = 'mm'
     FormatAll(24:28) = (/ f106,f104,f106,f106,f94 /)
     AggregAll(24:28) = (/aS,aL,aL,aS,aL/)
     LongNmAll(24:28) = (/'                   Surface moisture change','                       SurfaceWetnessState', &
                          'Surface wetness state (non-water surfaces)','                                  Drainage', &
                          '                       SoilMoistureDeficit'/)
     
     
     HeaderAll(29:30) = (/'  FlowCh','AddWater'/)                                          !water balance components cont.
     UnitsAll (29:30) = 'mm'
     FormatAll(29:30) = f104
     AggregAll(29:30) = aS
     LongNmAll(29:30) = (/' Additional flow into water body','Addtional water from other grids'/)
     
     HeaderAll(31:35) = (/' ROSoil',' ROPipe','  ROImp','  ROVeg','ROWater'/)   !runoff components
     UnitsAll (31:35) = 'mm'
     FormatAll(31:35) = f106
     AggregAll(31:35) = aS
     LongNmAll(31:35) = (/'                 Runoff to soil','                Runoff to pipes', &
                          'Runoff over impervious surfaces',' Runoff over vegetated surfaces', &
                          '       Runoff for water surface'/)
     
     HeaderAll(36:39) = (/'  WUInt','WUEveTr','WUDecTr','WUGrass'/)                !water use
     UnitsAll (36:39) = 'mm'
     FormatAll(36:39) = f94
     AggregAll(36:39) = aS
     LongNmAll(36:39) = (/'             InternalWaterUse', &
                          'Water use for evergreen trees','Water use for deciduous trees','          Water use for grass'/)
     
     HeaderAll(40:45) = (/'SMDPaved','SMDBldgs','SMDEveTr','SMDDecTr','SMDGrass','SMDBSoil'/)  !smd for each surface 
     UnitsAll (40:45) = 'mm'
     FormatAll(40:45) = f94
     AggregAll(40:45) = aL
     LongNmAll(40:45) = (/'         Soil moisture deficit for paved surface', &
                          '      Soil moisture deficit for building surface', &
                          'Soil moisture deficit for evergreen tree surface', &
                          'Soil moisture deficit for deciduous tree surface', &
                          '         Soil moisture deficit for grass surface', &
                          '     Soil moisture deficit for bare soil surface'/)
     
     HeaderAll(46:52) = (/'StPaved','StBldgs','StEveTr','StDecTr','StGrass','StBSoil','StWater'/)   !states
     UnitsAll (46:52) = 'mm'
     FormatAll(46:52) = (/SPREAD(f94,1,6),f104/)
     AggregAll(46:52) = aL
     LongNmAll(46:52) = (/'         Surface wetness state for paved surface', &
                          '      Surface wetness state for building surface', &
                          'Surface wetness state for evergreen tree surface', &
                          'Surface wetness state for deciduous tree surface', &
                          '         Surface wetness state for grass surface', &
                          '     Surface wetness state for bare soil surface', &
                          '         Surface wetness state for water surface'/)
     
     HeaderAll(53:54) = (/' Zenith','Azimuth'/)! solar angles
     UnitsAll (53:54) = 'deg'
     FormatAll(53:54) = f94
     AggregAll(53:54) = aL
     LongNmAll(53:54) = (/' Solar zenith angle','Solar azimuth angle'/)
     
     HeaderAll(55:56) = (/'AlbBulk','   Fcld'/)                ! extra radiation info 
     UnitsAll (55:56) = '-'
     FormatAll(55:56) = f94
     AggregAll(55:56) = aA
     LongNmAll(55:56) = (/'   Bulk albedo','Cloud fraction'/)
     
     HeaderAll(57)    = 'LAI'   ! extra surface info
     UnitsAll (57)    = 'm2_m-2'
     FormatAll(57)    = f94
     AggregAll(57)    = aA
     LongNmAll(57)    = 'Leaf area index'
     
     HeaderAll(58:59) = (/'z0m','zdm'/)                
     UnitsAll (58:59) = 'm'
     FormatAll(58:59) = f94
     AggregAll(58:59) = aA
     LongNmAll(58:59) = (/' Roughness length for momentum','Zero-plane displacement height'/)
     
     HeaderAll(60:63) = (/'ustar','  Lob','   ra','   rs'/)                ! turbulence 
     UnitsAll (60:63) = (/'m_s-1','    m','s_m-1','s_m-1'/)
     FormatAll(60:63) = (/f94,f104,f94,f94/)
     AggregAll(60:63) = aA
     LongNmAll(60:63) = (/'     Friction velocity','        Obukhov length', &
                          'Aerodynamic resistance','    Surface resistance'/)
     
     HeaderAll(64:69) = (/'     Fc','FcPhoto','FcRespi','FcMetab','FcTraff','FcBuild'/)   ! CO2 flux & components
     UnitsAll (64:69) = 'umol_m-2_s-1'
     FormatAll(64:69) = f94
     AggregAll(64:69) = aA
     LongNmAll(64:69) = (/'                    CO2 flux', &
                          'CO2 flux from photosynthesis','   CO2 flux from respiration', &
                          '    CO2 flux from metabolism','       CO2 flux from traffic','     CO2 flux from buildings'/)
     
     HeaderAll(70:72) = (/'QNSnowFr','  QNSnow',' AlbSnow'/)                             ! snow-related (radiation) 
     UnitsAll (70:72) = (/'W_m-2','W_m-2','    -'/)
     FormatAll(70:72) = f94
     AggregAll(70:72) = aA
     LongNmAll(70:72) = (/'Net all-wave radiation for non-snow area','    Net all-wave radiation for snow area', &
                          '                             Snow albedo'/)
     
     HeaderAll(73:75) = (/'        QM','  QMFreeze','    QMRain'/)
     UnitsAll (73:75) = 'W_m-2'
     FormatAll(73:75) = f106
     AggregAll(73:75) = aA
     LongNmAll(73:75) = (/'   Snow-related heat exchange','       Internal energy change','Heat released by rain on snow'/)
     
     HeaderAll(76:79) = (/'       SWE',' MeltWater','MeltWStore','    SnowCh'/)   !snow 
     UnitsAll (76:79) = 'mm'
     FormatAll(76:79) = f106
     AggregAll(76:79) = aS
     LongNmAll(76:79) = (/'Snow water equivalent','            Meltwater','      Meltwater store','  Change in snow pack' /)
     
     HeaderAll(80:81) = (/'SnowRPaved','SnowRBldgs'/)   !snow-related (removal)
     UnitsAll (80:81) = 'mm'
     FormatAll(80:81) = f94
     AggregAll(80:81) = aS
     LongNmAll(80:81) = (/'   Snow removed from paved surface','Snow removed from building surface' /)
     
     
     ! Select variables to be written out                  
     !write(*,*) 'WriteOutOption:', WriteOutOption
     IF(WriteOutOption == 0) THEN   !all (not snow-related)
        ALLOCATE(UseColumnsDataOut(69))
        UsecolumnsDataOut = (/ (i, i=1,69, 1) /)
     ELSEIF(WriteOutOption == 1) THEN   !all plus snow-related 
        ALLOCATE(UseColumnsDataOut(nColumnsDataOut))
        UsecolumnsDataOut = (/ (i, i=1,nColumnsDataOut, 1) /)
     ELSEIF(WriteOutOption == 2) THEN   !minimal output
        ALLOCATE(UseColumnsDataOut(33))
        UsecolumnsDataOut = (/ (i, i=1,15, 1),(i, i=19,28, 1), 53,54,55,56, 57, 60,61, 64 /) 
     ELSE
        write(*,*) 'RunControl: WriteOutOption code not recognised, so writing out all variables.'    
        ALLOCATE(UseColumnsDataOut(69))
        UsecolumnsDataOut = (/ (i, i=1,69, 1) /)
     ENDIF

     ! Create subset of HeaderAll and FormatAll for selected variables only   
     DO i=1,SIZE(UseColumnsDataOut)
        write(itext,'(i3)') i
        IF(i==1) THEN
           HeaderOut=adjustl(HeaderAll(UsecolumnsDataOut(i)))
           HeaderOutNoSep=adjustl(HeaderAll(UsecolumnsDataOut(i)))
           UnitsOut=adjustl(UnitsAll(UsecolumnsDataOut(i)))
           FormatOut=adjustl(FormatAll(UsecolumnsDataOut(i)))
           FormatOutNoSep=adjustl(FormatAll(UsecolumnsDataOut(i)))
           LongNmOut=adjustl(LongNmAll(UsecolumnsDataOut(i)))
           AggregOut=adjustl(AggregAll(UsecolumnsDataOut(i)))
           ColNos=adjustl(itext)
        ELSE  
           HeaderOut=trim(HeaderOut)//';'//adjustl(HeaderAll(UsecolumnsDataOut(i)))
           HeaderOutNoSep=trim(HeaderOutNoSep)//' '//adjustl(HeaderAll(UsecolumnsDataOut(i)))
           !write(*,*) HeaderOut
           UnitsOut=trim(UnitsOut)//';'//adjustl(UnitsAll(UsecolumnsDataOut(i)))
           !write(*,*) UnitsOut
           FormatOut=trim(FormatOut)//';'//adjustl(FormatAll(UsecolumnsDataOut(i)))
           FormatOutNoSep=trim(FormatOutNoSep)//' '//adjustl(FormatAll(UsecolumnsDataOut(i)))
           !write(*,*) FormatOut
           LongNmOut=trim(LongNmOut)//';'//adjustl(LongNmAll(UsecolumnsDataOut(i)))
           !write(*,*) LongNmOut
           AggregOut=trim(AggregOut)//';'//adjustl(AggregAll(UsecolumnsDataOut(i)))
           !write(*,*) AggregOut
           ColNos=trim(ColNos)//';'//adjustl(itext)
        ENDIF
     ENDDO
     !HeaderUse=trim(adjustl(HeaderOut))//' ' !with extra space at end of header row
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(HeaderOut)))):: HeaderUse)
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(UnitsOut)))):: UnitsUse)
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(LongNmOut)))):: LongNmUse)
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(FormatOut)))):: FormatUse)
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(AggregOut)))):: AggregUse)
     !ALLOCATE(CHARACTER(LEN(trim(adjustl(ColNos)))):: ColNosUse)
     HeaderUse=TRIM(adjustl(HeaderOut))
     HeaderUseNoSep=TRIM(adjustl(HeaderOutNoSep))
     UnitsUse=TRIM(adjustl(UnitsOut))
     LongNmUse=TRIM(adjustl(LongNmOut))
     FormatUse=TRIM(adjustl(FormatOut))
     FormatUseNoSep='('//TRIM(adjustl(FormatOutNoSep))//')'     
     AggregUse=TRIM(adjustl(AggregOut))
     ColNosUse=TRIM(adjustl(ColNos))
     !write(*,*) '||',TRIM(HeaderUse),'||'
     !write(*,*) '||',TRIM(FormatUse),'||'  
     !write(*,*) '||',TRIM(ColNosUse),'||'
         

    !=========== Write output format info to file ===========  
     OPEN(50,file=TRIM(FileOutFormat),err=111)
     WRITE(50,'(a)') TRIM(ColNosUse)
     WRITE(50,'(a)') TRIM(HeaderUse)
     WRITE(50,'(a)') TRIM(LongNmUse)
     WRITE(50,'(a)') TRIM(UnitsUse)
     WRITE(50,'(a)') TRIM(FormatUse)   !also write formats to output file (without outer brackets)
     WRITE(50,'(a)') TRIM(AggregUse)
     CLOSE (50)
     OutputFormats = 0
  ENDIF
  
  !========== Open output file (and first time print header) ==========
  
  ! Main output file --------------------------------------------------
  lfnOutC=39  !Output file code
  IF (iv==1) THEN
     OPEN(lfnOutC,file=TRIM(FileOut),err=112)
     WRITE(lfnOutC,'(a)') HeaderUseNoSep
  ELSE
     OPEN(lfnOutC,file=TRIM(FileOut),position='append')!,err=112)
  ENDIF
  
  ! SOLWEIG output file -----------------------------------------------
  IF (SOLWEIGpoi_out==1) THEN
     OPEN(9,file=SOLWEIGpoiOut)
     WRITE(9,113)
113  FORMAT('%doy dectime  azimuth altitude GlobalRad DiffuseRad DirectRad ', &
            ' Kdown2d    Kup2d    Ksouth     Kwest    Knorth     Keast ', &
            ' Ldown2d    Lup2d    Lsouth     Lwest    Lnorth     Least ', &
            '   Tmrt       I0       CI        gvf      shadow    svf    svfbuveg    Ta    Tg')
  ENDIF
  
  ! BL ouput file -----------------------------------------------------
  IF (CBLuse>=1) THEN
     OPEN(53,file=BLOut,status='unknown')
     WRITE(53, 102)
102  FORMAT('iy  id   it imin dectime         z            theta          q',&
            '               theta+          q+              Temp_C          rh',&
            '              QH_use          QE_use          Press_hPa       avu1',&
            '            ustar           avdens          lv_J_kg         avcp',&
            '            gamt            gamq')
  ENDIF

  ! Snow output file --------------------------------------------------
  IF (SnowUse>=1) THEN
     IF (iv==1) THEN
        OPEN(54,file=SnowOut)
        WRITE(54, 114)
114     FORMAT('%iy  id   it imin dectime ',&
               'SWE_Paved SWE_Bldgs SWE_EveTr SWE_DecTr SWE_Grass SWE_BSoil SWE_Water ',&
               'Mw_Paved Mw_Bldgs Mw_EveTr Mw_DecTr Mw_Grass Mw_BSoil Mw_Water ',&
               'Qm_Paved Qm_Bldgs Qm_EveTr Qm_DecTr Qm_Grass Qm_BSoil Qm_Water ',&
               'Qa_Paved Qa_Bldgs Qa_EveTr Qa_DecTr Qa_Grass Qa_BSoil Qa_Water ',&
               'QmFr_Paved QmFr_Bldgs QmFr_EveTr QmFr_DecTr QmFr_Grass QmFr_BSoil QmFr_Water ',&
               'fr_Paved fr_Bldgs fr_EveTr fr_DecTr fr_Grass fr_BSoil ',&
               'RainSn_Paved RainSn_Bldgs RainSn_EveTr RainSn_DecTr RainSn_Grass RainSn_BSoil RainSn_Water ',&
               'Qn_PavedSnow Qn_BldgsSnow Qn_EveTrSnpw Qn_DecTrSnow Qn_GrassSnpw Qn_BSoilSnow Qn_WaterSnow ',&
               'kup_PavedSnow kup_BldgsSnow kup_EveTrSnpw kup_DecTrSnow kup_GrassSnpw kup_BSoilSnow kup_WaterSnow ',&
               'frMelt_Paved frMelt_Bldgs frMelt_EveTr frMelt_DecTr frMelt_Grass frMelt_BSoil frMelt_Water ',&
               'MwStore_Paved MwStore_Bldgs MwStore_EveTr MwStore_DecTr MwStore_Grass MwStore_BSoil MwStore_Water ',&
               'SnowDens_Paved SnowDens_Bldgs SnowDens_EveTr SnowDens_DecTr SnowDens_Grass SnowDens_BSoil SnowDens_Water ',&
               'Sd_Paved Sd_Bldgs Sd_EveTr Sd_DecTr Sd_Grass Sd_BSoil Sd_Water ',&
               'Tsnow_Paved Tsnow_Bldgs Tsnow_EveTr Tsnow_DecTr Tsnow_Grass Tsnow_BSoil Tsnow_Water')
     ELSE
        OPEN(54,file=TRIM(SnowOut),position='append')
     ENDIF
  ENDIF

  ! ESTM ouput file ---------------------------------------------------
  IF (StorageHeatMethod==4 .OR. StorageHeatMethod==14) THEN
     IF (iv==1) THEN    
        OPEN(58,file=TRIM(ESTMOut),status='unknown')
        WRITE(58, 115)
115     FORMAT('%iy id it imin dectime ',&
               'QSNET QSAIR QSWALL QSROOF QSGROUND QSIBLD ',&
               'TWALL1 TWALL2 TWALL3 TWALL4 TWALL5 ',&       !T0_WALL TWALL1 TWALL2 TWALL3 TN_WALL
               'TROOF1 TROOF2 TROOF3 TROOF4 TROOF5 ',&
               'TGROUND1 TGROUND2 TGROUND3 TGROUND4 TGROUND5 ',&
               'TiBLD1 TiBLD2 TiBLD3 TiBLD4 TiBLD5 TaBLD ')
     ELSE
        OPEN(58,file=TRIM(ESTMOut),position='append')
     ENDIF
  ENDIF

  !These belong to NARP ouput file
     ! 'kup_Paved kup_Bldgs kup_EveTr kup_DecTr kup_Grass kup_BSoil kup_Water ',&
     ! 'lup_Paved lup_Bldgs lup_EveTr lup_DecTr lup_Grass lup_BSoil lup_Water ',&
     ! 'Ts_Paved Ts_Bldgs Ts_EveTr Ts_DecTr Ts_Grass Ts_BSoil Ts_Water ',&
     ! 'qn_Paved qn_Bldgs qn_EveTr qn_DecTr qn_Grass qn_BSoil qn_Water ',& 
  
  !========== Write out data ==========
  DO i=1,irMax
      WRITE(lfnoutC,FormatUseNoSep) INT(dataOut(i,PACK(UseColumnsDataOut, UsecolumnsDataOut < 5),Gridiv)),&
           dataOut(i,PACK(UseColumnsDataOut, UsecolumnsDataOut >= 5),Gridiv)
     !WRITE(lfnoutC,301) (INT(dataOut(i,is,Gridiv)),is=1,4),&      
     !      dataOut(i,5:ncolumnsDataOut,Gridiv)
  
  ENDDO
  
  IF (SOLWEIGpoi_out==1) THEN
     DO i=1,SolweigCount-1
        WRITE(9,304) INT(dataOutSOL(i,1,Gridiv)),(dataOutSOL(i,is,Gridiv),is=2,ncolumnsdataOutSOL)
     ENDDO
  ENDIF

  IF(CBLuse>=1) THEN
     DO i=1,iCBLcount
        WRITE(53,305)(INT(dataOutBL(i,is,Gridiv)),is=1,4),(dataOutBL(i,is,Gridiv),is=5,ncolumnsdataOutBL)
     ENDDO
  ENDIF

  IF(SnowUse>=1) THEN
     DO i=1,irmax
        WRITE(54,306)(INT(dataOutSnow(i,is,Gridiv)),is=1,4),(dataOutSnow(i,is,Gridiv),is=5,ncolumnsDataOutSnow)
     ENDDO
  ENDIF
  
  IF (StorageHeatMethod==4 .OR. StorageHeatMethod==14)THEN
     DO i=1,irMax
        WRITE(58, 307)(INT(dataOutESTM(i,is,Gridiv)),is=1,4),(dataOutESTM(i,is,Gridiv),is=5,32)
     ENDDO
  ENDIF

304 FORMAT(1(i3,1X),4(f8.4,1X),23(f9.3,1X))          !Solweig output
305 FORMAT((i4,1X),3(i3,1X),(f8.4,1X),17(f15.7,1x))  !CBL output
306 FORMAT((i4,1X),3(i3,1X),(f8.4,1X)&               !Snow out
       7(f10.4,1X),7(f10.4,1X),7(f10.4,1X),&
       7(f10.4,1X),7(f12.4,1X),6(f10.4,1X),&
       7(f10.4,1X),&
       7(f10.4,1X),7(f10.4,1X),7(f10.4,1X),&
       7(f10.4,1X),7(f10.4,1X),7(f10.4,1X),7(f10.4,1X))
307 FORMAT((i4,1X),3(i3,1X),(f8.4,1X),27(f12.4,1X))  !ESTM out

  !================CLOSE OUTPUTFILE================
  CLOSE (lfnoutC)
  CLOSE (9)
  CLOSE (53)
  CLOSE (54)
  CLOSE (58)
  RETURN

  !Error commands
111 CALL ErrorHint(52,TRIM(fileOutFormat),notUsed,notUsed,notUsedI)
112 CALL ErrorHint(52,TRIM(fileOut),notUsed,notUsed,notUsedI)


END SUBROUTINE SUEWS_Output

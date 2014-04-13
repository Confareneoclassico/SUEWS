!.c!! For Lumps Version 2 - no stability calculations
! Latent heat of sublimation when air temperature below zero added. LJ Nov 2012

SUBROUTINE atmos_moist_lumps(air_dens)
  USE data_in
  USE moist
  USE gas
  USE time
  use snowMod
  
  IMPLICIT NONE
  REAL(KIND(1d0))::vap_dens, air_dens
  REAL(KIND(1d0))::sat_vap_press,spec_heat_beer,lat_vap,lat_vapSublim   ! functions
  real(kind(1d0))::SPEC_HUM_DEF
  integer::from=1
  
  !Saturation vapour pressure over water in hPa
  es_hPa = sat_vap_press(Temp_C,Press_hPa,from)

  !Vapour pressure of water in hPa
  Ea_hPa=avRh/100*es_hPa  
  
 ! if(debug.and.dectime>55.13.and.dectime<55.2)write(35,*)'%',Temp_C
    
  VPd_hpa=es_hPa-ea_hpa           !vapour pressure deficit in hPa 
  VPD_Pa=(es_hPa*100)-(Ea_hPa*100)!vapour pressure deficit in Pa 
  
  dq=(spec_hum_def(vpd_hPa,Press_hPa)) !Specific humidity deficit in g/kg
  
  !Vap density or absolute humidity	 (kg/m3)
  vap_dens=(Ea_hPa*100/((Temp_C+273.16)*gas_ct_wv))
  
  !density Dry Air Beer(1991)	kg/m3
  dens_dry=((Press_hPa-Ea_hPa)*100)/(gas_ct_dry*(273.16+Temp_C))
 
  !Air density in kg/m3
  air_dens=(Press_hPa*100)/(gas_ct_dry*(Temp_C+273.16))
  
  !Calculate specific heat capacity in J kg-1 K-1
  avcp=spec_heat_beer(Temp_C,avRh,vap_dens,dens_dry)
  
  lv_J_kg=lat_vap(Temp_C,Ea_hPa,Press_hPa,avcp)

  if(Temp_C<0) then
     lvS_J_kg=lat_vapSublim(Temp_C,Ea_hPa,Press_hPa,avcp)
  endif
  
  !if(debug)write(*,*)lv_J_kg,Temp_C,'lv2'
  if(press_hPa<900)write(*,*)dectime,Press_hPa
  RETURN
END SUBROUTINE atmos_moist_lumps

!=====================================================================
! sg sept 99 f90
! Uses eqns from Buck (1981) JAM 20, 1527-1532
! units T (deg C) e (mb) P (mb)
! f corrects for the fact that we are not dealing with pure water
! LJ Feb 2010
!Changed to use the updated version (Buck research manual, 1996) from Buck (1981)
!For water different equations in cold and warm temperatures

FUNCTION sat_vap_press(Temp_c,PRESS_hPa,from) RESULT(es_hPa)
  use time
  use defaultnotUsed
  IMPLICIT NONE
  
  REAL(KIND(1d0))::e,f,temp_C,press_hpa,press_kpa,es_hPA!,pw
  integer:: from,iv
  
  !If air temperature between -0.001 - 
  IF(abs(temp_C)<0.001)THEN
    if(from==1) then  ! not from determining Tw
      iv=int(press_Hpa)
      call errorHint(29,'Function sat_vap_press: temp_C, dectime,press_Hpa = ',temp_C, dectime,iv) 
    
    endif
    temp_C=0.001
  ENDIF
  
  Press_kPa=Press_hPa/10
  
  IF(Temp_C<50.and.Temp_C>-40)THEN
     !e=6.1121*EXP(((18.729-Temp_C/227.3)*Temp_C)/(Temp_C+257.87)) !Old one
     !f=1.00072+Press_hPa*(3.2E-6+5.9D-10*Temp_C**2)
		
     if (Temp_C>=0.001) then
     	e=6.1121*exp(((18.678-Temp_C/234.5)*Temp_C)/(Temp_C+257.14))
       	f=1.00072+Press_kPa*(3.2E-6+5.9E-10*Temp_C**2)
        es_hPa=e*f

     elseif (Temp_C<=-0.001) then
        e=6.1115*exp(((23.036-Temp_C/333.7)*Temp_C)/(Temp_C+279.82))
        f=1.00022+Press_kPa*(3.83E-6+6.4E-10*Temp_C**2)
        es_hPa=e*f
     endif	
     
  ELSE
     call ErrorHint(28,'FUNCTION sat_vap_press: [Temperature is out of range], Temp_C,dectime',Temp_C,dectime,notUsedI)
     
  ENDIF

  RETURN
END FUNCTION sat_vap_press


FUNCTION sat_vap_pressIce(Temp_c,PRESS_hPa,from) RESULT(es_hPa)
  use time
  use defaultnotUsed
  IMPLICIT NONE
  
  REAL(KIND(1d0))::e,f,temp_C,press_hpa,press_kpa,es_hPA!,pw
  integer:: from,iv
  
  !If air temperature between -0.001 - 
  IF(abs(temp_C)<0.001)THEN
    if(from==1) then  ! not from determining Tw
      iv=int(press_Hpa)
      call errorHint(29,'Function sat_vap_press: temp_C, dectime,press_Hpa = ',temp_C, dectime,iv) 
    
    endif
    temp_C=0.001
  ENDIF
  
  Press_kPa=Press_hPa/10
  
  IF(Temp_C<50.and.Temp_C>-40)THEN
    e=6.1115*exp(((23.036-Temp_C/333.7)*Temp_C)/(Temp_C+279.82))
    f=1.00022+Press_kPa*(3.83E-6+6.4E-10*Temp_C**2) !In hPa
    es_hPa=e*f
     
  ELSE
     call ErrorHint(28,'FUNCTION sat_vap_press: [Temperature is out of range], Temp_C,dectime',Temp_C,dectime,notUsedI)
     
  ENDIF

  RETURN
END FUNCTION sat_vap_pressIce

!==========================================================
!Output: specific humidity deficit in g/kg
!Input: Dry air density and air pressure in hPa
function spec_hum_def(vpd_hPa,press_hPa) result(dq)
 use gas
 implicit none
 real(kind(1d0))::press_hPa,vpd_hPa,dq
 dq=epsil_gkg*vpd_hPa/press_hPa ! Phd Thesis II.13 p 196
end function spec_hum_def

! ==============================================================================
FUNCTION spec_heat_beer(Temp_C,rh,rho_v,rho_d) RESULT (cp)
! Input: Air temperature, relative humidity, water vapour and dry air densities
! Output: heat capacity in units J kg-1 K-1
  IMPLICIT NONE
  REAL(kind(1d0))::cp,cpd,cpm,rho_v,rho_d,rh,temp_C

  !Garratt equation a20 (1992)
  CPd=1005.0+((Temp_C+23.16)**2)/3364.0 !Changed from 23.15 to 23.16
  
  !Beer (1991) for water vapor
  cpm = 1859 + 0.13*rH+ (19.3+0.569*rH)*(Temp_C/100.) + &
       (10.+0.5*rH)*(Temp_C/100.)**2
       
  IF(abs(rho_d)<0.001.OR.abs(rho_v)<0.001.OR.abs(rho_d+rho_v)<0.001)THEN
     PRINT*,'~/progs/spec_heat.f',rho_v,rho_d
  ENDIF
  
  cp=cpd*(rho_d/(rho_d+rho_v))+cpm*(rho_v/(rho_d+rho_v))
  !   print*,"cp: ",cp,cpd,rho_d,rho_v,cpm,rh
END FUNCTION spec_heat_beer

!==========================================================
!Latent_heat.f sg nov 96
!sg sep 99 converted f90 FUNCTION
!Added calcualation of latent heat of sublimation, LJ June 2012

FUNCTION Lat_vap(Temp_C,Ea_hPa,Press_hPa,cp) RESULT (lv_J_kg)
!Input: Air temperature, Water vapour pressure, Air pressure, heat capacity
!Output: latent heat of vaporization

  use time
  use SnowMod
  
  IMPLICIT none
  REAL(KIND(1d0))::cp,lv_J_kg,ea_fix,tw,& 
       incr,es_tw,psyc,ea_est,press_hPa,ea_HPa, temp_C!,Temp_K
  real (Kind(1d0))::sat_vap_press,psyc_const ! functions
       
  LOGICAL:: switch1=.FALSE.,switch2=.FALSE.!,debug=.true.
  INTEGER:: ii,from=2
  
  ea_fix=ea_hPa
  !if(debug) write(*,*)Temp_C, 'LV'
  !Temp_K=temp_C+273.16
  	
  !lv=1.91846E6*(Temp_K/(Temp_K-33.91))**2
    
  lv_J_kg=(2500.25-2.365*temp_C)*1000  !First guess for lv in units J/kg


  tw=Temp_C/2.  !First estimate for wet bulb temperature
  incr=3.
  DO ii=1,100
      If(Press_hPa<900) write(*,*)Press_hPA,'1',ii !If air presure below 900 print the loop number
      
      ! if(debug.and.dectime>55.13.and.dectime<55.2)write(35,*)'% 1',Tw
      
      es_tw=sat_vap_press(Tw,Press_hPa,from)  !Calculate saturation vapour pressure in hPa
      
      !if(debug.and.dectime>55.13.and.dectime<55.2)write(35,*)'% 2',Tw
       
      If(Press_hPa<900)write(*,*)Press_hPA,'2',ii
      
      psyc=psyc_const(cp,Press_hPa,lv_J_kg) !in units hPa/K
      
      If(Press_hPa<900)write(*,*)Press_hPA,'31',ii
        
      ea_est=es_tw-psyc*(temp_C-tw)
      
      lv_J_kg=(2500.25-2.365*tw)*1e3
      
      IF(switch1.AND.switch2)THEN
          incr=incr/10.
          switch1=.FALSE.
          switch2=.FALSE.
      ENDIF
      IF(ABS(ea_est-ea_fix)<0.001)THEN
          RETURN
      ELSEIF(ea_est > ea_fix)THEN
          tw=tw-incr
          switch1=.TRUE.
      ELSEIF(ea_est< ea_fix)THEN
          tw=tw+incr
          switch2=.TRUE.
      ENDIF
 ENDDO

  RETURN
END FUNCTION lat_vap


FUNCTION Lat_vapSublim(Temp_C,Ea_hPa,Press_hPa,cp) RESULT (lvS_J_kg)
!Input: Air temperature, Water vapour pressure, Air pressure, heat capacity
!Output: latent heat of sublimation in units J/kg

  use time
  
  IMPLICIT none
  REAL(KIND(1d0))::cp,lvS_J_kg,ea_fix,tw,& 
       incr,es_tw,psyc,ea_est,press_hPa,ea_HPa, temp_C!,Temp_K
  real (Kind(1d0))::sat_vap_pressIce,psyc_const ! functions
       
  LOGICAL:: switch1=.FALSE.,switch2=.FALSE.!,debug=.true.
  INTEGER:: ii,from=2
  

  !Latent heat for sublimation
  !From Rogers&Yau (A short course in cloud physics), Wikipedia
  
  !ea_fix=ea_hPa
 
  lvS_J_kg=(2834.1-0.29*temp_C)*1e3 !First guess for Ls in J/kg
     
  !tw=Temp_C/2.  !First estimate for wet bulb temperature
  !incr=3.
  !DO ii=1,100
     
   !   es_tw=sat_vap_pressIce(Tw,Press_hPa,from)  !Calculate saturation vapour pressure in hPa
      
    !  psyc=psyc_const(cp,Press_hPa,lv_J_kg) 
      
     ! ea_est=es_tw-psyc*(temp_C-tw)
      !lvS_J_kg=(2834.1-0.29*tw)*1e3
      
     
     ! IF(switch1.AND.switch2)THEN
    !    incr=incr/10.
     !   switch1=.FALSE.
     !   switch2=.FALSE.
    !  ENDIF
  !
     ! IF(ABS(ea_est-ea_fix)<0.001)THEN
     !   RETURN
     ! ELSEIF(ea_est > ea_fix)THEN
    !    tw=tw-incr
    !    switch1=.TRUE.
    !  ELSEIF(ea_est< ea_fix)THEN
    !    tw=tw+incr
    !    switch2=.TRUE.
    !  ENDIF
! ENDDO  

  RETURN
END FUNCTION lat_vapSublim



!=====================================================================
!psyc_const.f   sg   nov 96
!sg june 99 f90
!calculate psyc - psychrometic constant Fritschen and Gay (1979)

FUNCTION psyc_const(cp,Press_hPa,lv_J_kg) RESULT(psyc_hPa) !In units hPa/K
  USE gas 

  IMPLICIT NONE
  REAL (KIND(1d0))::cp,lv_J_kg,press_hPa,psyc_hpa
  !     cp for moist air (shuttleworth p 4.13)
  IF(cp*press_hpA<900.OR.lv_J_kg<10000)then
     call errorHint(19,'psychrometric constant:  cp, press (hPa), lv (J/kg):',cp,press_hPA,int(lv_J_kg))
    endif 
  
  psyc_hPa=(cp*press_hPa)/(epsil*lv_J_kg)
!    if(debug)write(*,*)psyc_hpa, 'g',cp,press_HPa,lv
! LV MJKg-1
 !www.cimis.water.ca.gov/infoEotPmEquation.jsp
  !psyc_hPa=(0.00163*(Press_hPa/10)/LV)*10
   ! write(*,*)psyc_hpa
  !psyc=psyc*100.! convert into Pa
END FUNCTION psyc_const

!==========================================================

  FUNCTION dewpoint(ea_hPa) RESULT(Temp_C_dew)
   ! ea = vapor pressure (hPa)
   ! td = dewpoint (oC)  
   !calculates dewpoint in degC from 
   ! http://www.atd.ucar.edu/weather_fl/dewpoint.html
   !     dewpoint = (237.3 * ln(e_vp/6.1078)) / (17.27 - (ln(e_vp/6.1078)))

   REAL(KIND(1d0)) 			::ea_hPa,temp_C_dew
   Temp_C_dew = (237.3 * LOG(ea_hPa/6.1078)) / (17.27 - (LOG(ea_hPa/6.1078)))
 END FUNCTION dewpoint
 !===============================================================================
FUNCTION slope_svp(temp_C) RESULT(s_hPa)
  !COEFFICENTS FOR CALCULATING desat/dT
  !Slope of the saturation vapor pressure vst air temperature curve 
   
  IMPLICIT  NONE

  REAL (KIND(1d0)):: b1,b2,b3,b4,b5,b6,b7,S_hPa,temp_C
  B1=4.438099984D-1
  B2=2.857002636D-2
  B3=7.938054040D-4
  B4=1.215215065D-5
  B5=1.036561403D-7
  B6=3.532421810D-10
  B7=-7.090244804D-13

  !     s - slope of saturation vapour pressure curve - Lowe (1977) -T (K)
  !     mb /K
  S_hPa=B1+temp_C*(B2+temp_C*(B3+temp_C*(B4+temp_C*(B5+temp_C*(B6+B7*temp_C)))))
 ! write(*,*)'s',s_hpa,temp_C
  !s_Pa=s_Pa*100  ! Pa/K
  !www.cimis.water.ca.gov/infoEotPmEquation.jsp
 ! s_hPa=(((4099 *(es_hPa/10))/(Temp_C+273.3)**2))*10
     ! if(debug)write(*,*)s_hpa
  RETURN
END FUNCTION slope_svp

!===============================================================================
FUNCTION slopeIce_svp(temp_C) RESULT(s_hPa)
  !COEFFICENTS FOR CALCULATING desat/dT
  !Slope of the saturation vapor pressure vst air temperature curve 
   
  IMPLICIT  NONE

  REAL (KIND(1d0)):: b1,b2,b3,b4,b5,b6,b7,S_hPa,temp_C
  B1=5.030305237D-1
  B2=3.773255020D-2
  B3=1.267995369D-3
  B4=2.477563108D-5
  B5=3.005693132D-7
  B6=2.158542548D-9
  B7=7.131097725D-12

  ! s - slope of saturation vapour pressure curve - Lowe (1977) -T (K)
  ! mb /K
  S_hPa=B1+temp_C*(B2+temp_C*(B3+temp_C*(B4+temp_C*(B5+temp_C*(B6+B7*temp_C)))))

  RETURN
END FUNCTION slopeIce_svp












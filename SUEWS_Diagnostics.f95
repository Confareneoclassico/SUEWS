SUBROUTINE diagSfc(xSurf,xFlux,us,xDiag,opt)
  ! Ting Sun 20 May 2017: calculate surface-level diagonostics

  USE mod_k
  use mod_z
  USE sues_data
  USE data_in
  USE moist

  IMPLICIT NONE

  REAL(KIND(1d0)),INTENT(in) :: xSurf,xFlux,us
  REAL(KIND(1d0)),INTENT(out):: xDiag
  INTEGER,INTENT(in)         :: opt ! 0 for momentum, 1 for temperature, 2 for humidity

  REAL(KIND(1d0))            :: &
       psymz2,psymz10,psymz0,psyhz2,psyhz0,& ! stability correction functions
       z0h,& ! Roughness length for heat
       z2zd,z10zd,&
       stab_fn_mom,stab_fn_heat !stability correction functions

  !***************************************************************
  ! log-law based stability corrections:
  ! Roughness length for heat
  z0h=z0m/10
  ! zX-z0
  z2zd=2+z0h   ! set lower limit as z0h to prevent arithmetic error
  z10zd=10+z0m ! set lower limit as z0m to prevent arithmetic error

  ! stability correction functions
  ! momentum:
  psymz10=stab_fn_mom(StabilityMethod,z10zd/L_mod,z10zd/L_mod)
  psymz2=stab_fn_mom(StabilityMethod,z2zd/L_mod,z2zd/L_mod)
  psymz0=stab_fn_mom(StabilityMethod,z0m/L_mod,z0m/L_mod)

  ! heat and vapor: assuming both are the same

  psyhz2=stab_fn_heat(StabilityMethod,z2zd/L_mod,z2zd/L_mod)
  psyhz0=stab_fn_heat(StabilityMethod,z0h/L_mod,z0h/L_mod)
  !***************************************************************

  SELECT CASE (opt)
  CASE (0) ! wind (momentum) at 10 m
     xDiag=ustar/k*(LOG(z10zd/z0m)-psymz10+psymz0)

  CASE (1) ! temperature at 2 m
    !  PRINT*, 'xSurf',xSurf
    !  PRINT*, 'xFlux',xFlux
    !  PRINT*, 'k*us*avdens*avcp',k*us*avdens*avcp
    !  PRINT*, 'k',k
    !  PRINT*, 'us',us
    !  PRINT*, 'avdens',avdens
    !  PRINT*, 'avcp',avcp
    !  PRINT*, 'stab',(LOG(z2zd/z0h)-psyhz2+psyhz0)
     xDiag=xSurf-xFlux/(k*us*avdens*avcp)*(LOG(z2zd/z0h)-psyhz2+psyhz0)
    !  PRINT*, 'xDiag',xDiag

  CASE (2) ! humidity at 2 m
     xDiag=xSurf-xFlux/(k*us*avdens*tlv)*(LOG(z2zd/z0h)-psyhz2+psyhz0)

  END SELECT

END SUBROUTINE diagSfc

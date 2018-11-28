!
! Copyright (C) 2015-2018 Andrea Dal Corso 
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
SUBROUTINE write_gruneisen_band(file_disp, file_vec)
  !
  ! reads data files produced by write_ph_dispersions for ngeo geometries, 
  ! interpolates them with a polynomial and computes and writes a file with 
  ! the mode gruneisen parameters: minus the derivatives of the logarithm of 
  ! the phonon frequencies with respect to the logarithm of the volume.
  ! This is calculated at the volume given in input or at the volume
  ! that corresponds to the temperature given in input. This routine is 
  ! used when lmurn=.TRUE..
  ! 
  USE kinds,          ONLY : DP
  USE ions_base,      ONLY : nat, ntyp => nsp
  USE data_files,     ONLY : flgrun
  USE thermo_mod,     ONLY : ngeo, omega_geo, no_ph
  USE anharmonic,     ONLY : vmin_t
  USE ph_freq_anharmonic, ONLY : vminf_t
  USE grun_anharmonic, ONLY : poly_order
  USE control_grun,   ONLY : temp_ph, volume_ph
  USE initial_conf,   ONLY : amass_save, ityp_save, ibrav_save
  USE control_mur,    ONLY : vmin
  USE control_thermo, ONLY : ltherm_dos, ltherm_freq
  USE temperature,    ONLY : temp, ntemp
  USE freq_interpolate, ONLY : interp_freq_eigen, compute_polynomial, &
                               compute_polynomial_der
  USE io_bands,       ONLY : read_bands, read_parameters, write_bands
  USE mp,             ONLY : mp_bcast
  USE io_global,      ONLY : stdout, ionode, ionode_id
  USE mp_images,      ONLY : intra_image_comm, root_image, my_image_id

  IMPLICIT NONE

  CHARACTER(LEN=256), INTENT(IN) :: file_disp, file_vec

  REAL(DP), ALLOCATABLE :: freq_geo(:,:,:), k(:,:), frequency_geo(:,:), &
                           omega_data(:), poly_grun(:,:), frequency(:,:), &
                           gruneisen(:,:)
  COMPLEX(DP), ALLOCATABLE :: displa_geo(:,:,:,:), displa(:,:,:)
  INTEGER :: nks, nbnd, cgeo_eff, central_geo, ibnd, ios, i, n, igeo, ndata, &
             iumode
  INTEGER :: find_free_unit
  REAL(DP) :: vm, f, g
  LOGICAL, ALLOCATABLE :: is_gamma(:)
  LOGICAL :: copy_before, allocated_variables
  CHARACTER(LEN=256) :: filename, filedata, filegrun, filefreq
  CHARACTER(LEN=6), EXTERNAL :: int_to_char

  IF ( my_image_id /= root_image ) RETURN
  IF (flgrun == ' ') RETURN
!
!  Part one: read the frequencies and the mode eigenvectors.
!
  IF (ionode) iumode=find_free_unit()
  allocated_variables=.FALSE.
  DO igeo = 1, ngeo(1)
     IF (no_ph(igeo)) CYCLE
     filedata = "phdisp_files/"//TRIM(file_disp)//'.g'//TRIM(int_to_char(igeo))
     CALL read_parameters(nks, nbnd, filedata)
     IF (nks <= 0 .or. nbnd <= 0) THEN
        CALL errore('write_gruneisen_band','reading plot namelist',ABS(ios))
     ELSE
        WRITE(stdout, '(5x,"Reading ",i4," dispersions at ",i6," k-points for&
                       & geometry",i4)') nbnd, nks, igeo
     ENDIF
     IF (.NOT.allocated_variables) THEN
        ALLOCATE (freq_geo(nbnd,nks,ngeo(1)))
        ALLOCATE (displa_geo(nbnd,nbnd,ngeo(1),nks))
        ALLOCATE (k(3,nks)) 
        allocated_variables=.TRUE.
     ENDIF
     CALL read_bands(nks, nbnd, k, freq_geo(1,1,igeo), filedata)

     filename="phdisp_files/"//TRIM(file_vec)//".g"//TRIM(int_to_char(igeo))
     IF (ionode) OPEN(UNIT=iumode, FILE=TRIM(filename), FORM='formatted', &
                STATUS='old', ERR=210, IOSTAT=ios)
210  CALL mp_bcast(ios, ionode_id, intra_image_comm)
     CALL errore('write_gruneisen_band','modes are needed',ABS(ios))
     IF (ionode) THEN
        CALL readmodes(nat,nks,k,displa_geo,ngeo(1),igeo,ntyp,ityp_save,  &
                                                         amass_save,iumode)
        CLOSE(UNIT=iumode, STATUS='KEEP')
     ENDIF
  ENDDO
  CALL mp_bcast(displa_geo, ionode_id, intra_image_comm)
  ALLOCATE (is_gamma(nks))
  DO n=1,nks
     is_gamma(n) = (( k(1,n)**2 + k(2,n)**2 + k(3,n)**2) < 1.d-12)
  ENDDO
!
!  Part two: Compute the Gruneisen parameters
!
!  find how many data have been really calculated 
!
  ndata=0
  DO igeo=1, ngeo(1)
     IF (.NOT.no_ph(igeo)) ndata=ndata+1
  ENDDO
!
!   find the central geometry of this set of data and save the volume of
!   each computed geometry
!
  ALLOCATE(omega_data(ndata))
  CALL find_central_geo(ngeo,no_ph,central_geo)
  ndata=0
  DO igeo=1, ngeo(1)
     IF (no_ph(igeo)) CYCLE
     ndata=ndata+1
     IF (central_geo==igeo) cgeo_eff=ndata
     omega_data(ndata)=omega_geo(igeo)
  ENDDO
!
!  Compute the volume at which the Gruneisen parameters and the frequencies
!  are interpolated
!
  IF (volume_ph==0.0_DP) THEN
     IF (ltherm_freq) THEN
        CALL evaluate_vm(temp_ph, vm, ntemp, temp, vminf_t)
     ELSEIF (ltherm_dos) THEN
        CALL evaluate_vm(temp_ph, vm, ntemp, temp, vmin_t)
     ELSE
        vm=vmin
     ENDIF
  ELSE
     vm=volume_ph
  ENDIF

  WRITE(stdout,'(/,5x,"Plotting Gruneisen parameters at volume",f17.8,&
                                                    &" (a.u.)^3")') vm
  IF (volume_ph==0.0_DP.AND.(ltherm_freq.OR.ltherm_dos)) &
            WRITE(stdout,'(5x,"Corresponding to T=",f17.8)') temp_ph
!
!  Allocate space for interpolating the frequencies
!
  ALLOCATE(frequency_geo(nbnd,ndata))
  ALLOCATE(displa(nbnd,nbnd,ndata))
  ALLOCATE(poly_grun(poly_order,nbnd))
  ALLOCATE(frequency(nbnd,nks))
  ALLOCATE(gruneisen(nbnd,nks))

  copy_before=.FALSE.
  frequency(:,:)= 0.0_DP
  gruneisen(:,:)= 0.0_DP
  DO n = 1,nks
     IF (is_gamma(n)) THEN
!
!    At the gamma point the Gruneisen parameters are not defined.
!    In order to have a continuous plot we take the same parameters
!    of the previous point, if this point exists and is not gamma.
!    Otherwise at the next point we copy the parameters in the present one
!
        copy_before=.FALSE.
        IF (n==1) THEN
           copy_before=.TRUE.
        ELSEIF (is_gamma(n-1)) THEN
           copy_before=.TRUE.
        ELSE
           DO ibnd=1,nbnd
              gruneisen(ibnd,n)=gruneisen(ibnd,n-1)
              frequency(ibnd,n)=frequency(ibnd,n-1)
           ENDDO
!
!  At the gamma point the first three frequencies vanishes
!
           DO ibnd=1,3
              frequency(ibnd,n)=0.0_DP
           ENDDO
        ENDIF
     ELSE
!
!  interpolates the frequencies with a polynomial and gives the coefficients
!  poly_grun
!
        ndata=0
        DO igeo=1, ngeo(1)
           IF (no_ph(igeo)) CYCLE
           ndata=ndata+1
           frequency_geo(1:nbnd,ndata)=freq_geo(1:nbnd,n,igeo)
           displa(1:nbnd,1:nbnd,ndata) = displa_geo(1:nbnd,1:nbnd,igeo,n)
        ENDDO
        CALL interp_freq_eigen(ndata, frequency_geo, omega_data, &
                          cgeo_eff, displa, poly_order, poly_grun)
!
!  frequencies and gruneisen parameters are calculated at the chosen
!  volume using the intepolating polynomial
!
        DO ibnd=1,nbnd
           CALL compute_polynomial(vm, poly_order, poly_grun(:,ibnd),f)
           CALL compute_polynomial_der(vm, poly_order, poly_grun(:,ibnd),g)
           frequency(ibnd,n)=f
           gruneisen(ibnd,n)=g
!
!     g here is V d w / d V. We change sign and divide by the frequency w 
!     to get the gruneisen parameter.
!
           IF (frequency(ibnd,n) > 0.0_DP ) THEN
              gruneisen(ibnd,n) = - gruneisen(ibnd,n) / frequency(ibnd,n)
           ELSE
              gruneisen(ibnd,n) = 0.0_DP
           ENDIF
           IF (copy_before) THEN
              gruneisen(ibnd,n-1) = gruneisen(ibnd,n)
              frequency(ibnd,n-1) = frequency(ibnd,n)
           ENDIF 
        ENDDO
        copy_before=.FALSE.
!
!  At the gamma point the first three frequencies vanishes
!
        IF (n>1.AND.is_gamma(n-1)) THEN
           DO ibnd=1,3
              frequency(ibnd,n-1)=0.0_DP
           ENDDO
        ENDIF
     ENDIF
  ENDDO
!
!  Third part: writes Gruneisen parameters on file
!
   filegrun="anhar_files/"//TRIM(flgrun)
   CALL write_bands(nks, nbnd, k, gruneisen, 1.0_DP, filegrun)
!
!  writes frequencies at the chosen volume on file
!
   filefreq=TRIM(filegrun)//'_freq'
   CALL write_bands(nks, nbnd, k, frequency, 1.0_DP, filefreq)

   DEALLOCATE( gruneisen )
   DEALLOCATE( frequency )
   DEALLOCATE( poly_grun )
   DEALLOCATE( displa )
   DEALLOCATE( frequency_geo )
   DEALLOCATE( omega_data )
   DEALLOCATE( is_gamma )
   DEALLOCATE( k ) 
   DEALLOCATE( displa_geo )
   DEALLOCATE( freq_geo )

   RETURN
END SUBROUTINE write_gruneisen_band

SUBROUTINE evaluate_vm(temp_ph, vm, ntemp, temp, vminf_t)

USE kinds, ONLY : DP
USE io_global, ONLY : stdout
IMPLICIT NONE
INTEGER, INTENT(IN) :: ntemp
REAL(DP), INTENT(IN) :: temp(ntemp), vminf_t(ntemp)
REAL(DP), INTENT(INOUT) :: temp_ph, vm

INTEGER :: itemp0, itemp1, itemp

itemp0=1
DO itemp=1,ntemp
   IF (temp(itemp) < temp_ph) itemp0=itemp
ENDDO

IF (itemp0 == ntemp) THEN
   WRITE(stdout,'(5x,"temp_ph too large setting to",f15.8 )') temp(ntemp-1)
   temp_ph=temp(ntemp-1)
   vm=vminf_t(ntemp-1)
   RETURN
ENDIF

IF (itemp0 == 1) THEN
   WRITE(stdout,'(5x,"temp_ph too small setting to",f15.8 )') temp(2)
   temp_ph=temp(2)
   vm=vminf_t(2)
   RETURN
ENDIF

itemp1=itemp0+1

vm = vminf_t(itemp0) + (temp_ph - temp(itemp0)) *          &
                       (vminf_t(itemp1)-vminf_t(itemp0)) / &
                       (temp(itemp1)-temp(itemp0))

RETURN
END SUBROUTINE evaluate_vm

!
! Copyright (C) 2014 Andrea Dal Corso
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
SUBROUTINE write_thermo(igeom)

USE kinds,          ONLY : DP
USE phdos_module,   ONLY : phdos_type, read_phdos_data, zero_point_energy, &
                          free_energy, vib_energy, vib_entropy, &
                          specific_heat_cv, integrated_dos
USE thermo_mod,     ONLY : ngeo
USE temperature,    ONLY : tmin, tmax, deltat, ntemp, temp
USE thermodynamics, ONLY : ph_ener, ph_free_ener, ph_entropy, ph_cv, phdos_save
USE mp_images,      ONLY : root_image, my_image_id
USE io_global,      ONLY : ionode, stdout
USE control_thermo, ONLY : fltherm

IMPLICIT NONE
INTEGER, INTENT(IN) :: igeom

INTEGER  :: i, ios
REAL(DP) :: e0, tot_states
INTEGER  :: itemp
INTEGER  :: iu_therm
!
IF (my_image_id /= root_image) RETURN

IF ( igeom < 1 .OR. igeom > ngeo ) CALL errore('print_thermo', & 
                                               'Too many geometries',1)
WRITE(stdout,'(/,2x,76("+"))')
WRITE(stdout,'(5x,"Computing the thermodynamical properties")')
WRITE(stdout,'(5x,"Writing on file ",a)') TRIM(fltherm)
WRITE(stdout,'(2x,76("+"),/)')

!
!  Allocate thermodynamic quantities
!
IF (deltat <= 0.0_8) CALL errore('print_thermo','Negative deltat',1)
ntemp=1+NINT((tmax-tmin)/deltat)

IF (.NOT.ALLOCATED(temp)) ALLOCATE(temp(ntemp))

IF (.NOT.ALLOCATED(ph_free_ener)) ALLOCATE(ph_free_ener(ntemp,ngeo))
IF (.NOT.ALLOCATED(ph_ener)) ALLOCATE(ph_ener(ntemp,ngeo))
IF (.NOT.ALLOCATED(ph_entropy)) ALLOCATE(ph_entropy(ntemp,ngeo))
IF (.NOT.ALLOCATED(ph_cv)) ALLOCATE(ph_cv(ntemp,ngeo))

CALL zero_point_energy(phdos_save(igeom), e0)
CALL integrated_dos(phdos_save(igeom), tot_states)

DO itemp = 1, ntemp
   temp(itemp) = tmin + (itemp-1) * deltat
   CALL free_energy(phdos_save(igeom), temp(itemp), ph_free_ener(itemp,igeom))
   CALL vib_energy(phdos_save(igeom), temp(itemp), ph_ener(itemp,igeom))
   CALL vib_entropy(phdos_save(igeom), temp(itemp), ph_entropy(itemp, igeom))
   CALL specific_heat_cv(phdos_save(igeom), temp(itemp), ph_cv(itemp, igeom))
   ph_free_ener(itemp,igeom)=ph_free_ener(itemp,igeom)+e0
   ph_ener(itemp,igeom)=ph_ener(itemp,igeom)+e0
END DO

IF (ionode) THEN
   iu_therm=2
   OPEN (UNIT=iu_therm, FILE=TRIM(fltherm), STATUS='unknown',&
                                                     FORM='formatted')
   WRITE(iu_therm,'("# Zero point energy is:", f9.5, " Ry/cell,", f9.5, &
                    &" kJ*N/mol,", f9.5, " kcal*N/mol")') e0, &
                       e0 * 1313.313_DP, e0 * 313.7545_DP 
   WRITE(iu_therm,'("# Total number of states is:", f15.5,",")') tot_states
   WRITE(iu_therm,'("# Temperature T in K, ")')
   WRITE(iu_therm,'("# Energy and free energy in Ry/cell,")')
   WRITE(iu_therm,'("# Entropy in Ry/cell/K,")')
   WRITE(iu_therm,'("# Heat capacity Cv in Ry/cell/K.")')
   WRITE(iu_therm,'("# Multiply by 13.6058 to have energies in &
                       &eV/cell etc..")')
   WRITE(iu_therm,'("# Multiply by 13.6058 x 23060.35 = 313 754.5 to have &
                  &energies in cal*N/mol.")')
   WRITE(iu_therm,'("# We assume that N_A cells contain N moles &
                  &(N_A is the Avogadro number).")')
   WRITE(iu_therm,'("# For instance in silicon N=2. Divide by N to have &
                   &energies in cal/mol etc. ")')
   WRITE(iu_therm,'("# Multiply by 13.6058 x 96526.0 = 1 313 313 to &
                  &have energies in J/mol.")')
   WRITE(iu_therm,'("#",5x,"   T  ", 7x, " energy ", 4x, "  free energy ",&
                  & 4x, " entropy ", 7x, " Cv ")') 

   DO itemp = 1, ntemp
      WRITE(iu_therm, '(5e16.8)') temp(itemp), &
                    ph_ener(itemp,igeom), ph_free_ener(itemp,igeom), &
                    ph_entropy(itemp,igeom), ph_cv(itemp,igeom)
   END DO

   CLOSE(iu_therm)
END IF

RETURN
END SUBROUTINE write_thermo

SUBROUTINE write_thermo_ph(igeom)

USE kinds,          ONLY : DP
USE ph_freq_module,   ONLY : ph_freq_type, zero_point_energy_ph, &
                          free_energy_ph, vib_energy_ph, vib_entropy_ph, &
                          specific_heat_cv_ph
USE temperature,    ONLY : tmin, tmax, deltat, ntemp, temp
USE ph_freq_thermodynamics, ONLY : phf_ener, phf_free_ener, phf_entropy, &
                           phf_cv, ph_freq_save
USE thermo_mod,     ONLY : ngeo
USE mp_images,      ONLY : root_image, my_image_id
USE io_global,      ONLY : ionode, stdout
USE control_thermo, ONLY : fltherm

IMPLICIT NONE
INTEGER, INTENT(IN) :: igeom

INTEGER  :: i, ios
REAL(DP) :: e0
INTEGER  :: itemp
INTEGER  :: iu_therm
!
IF (my_image_id /= root_image) RETURN

IF ( igeom < 1 .OR. igeom > ngeo ) CALL errore('print_thermo', & 
                                               'Too many geometries',1)
WRITE(stdout,'(/,2x,76("+"))')
WRITE(stdout,'(5x,"Computing the thermodynamical properties from frequencies")')
WRITE(stdout,'(5x,"Writing on file ",a)') TRIM(fltherm)//'_ph'
WRITE(stdout,'(2x,76("+"),/)')

!
!  Allocate thermodynamic quantities
!
IF (deltat <= 0.0_8) CALL errore('print_thermo','Negative deltat',1)
ntemp=1+NINT((tmax-tmin)/deltat)

IF (.NOT.ALLOCATED(temp)) ALLOCATE(temp(ntemp))

IF (.NOT.ALLOCATED(phf_free_ener)) ALLOCATE(phf_free_ener(ntemp,ngeo))
IF (.NOT.ALLOCATED(phf_ener)) ALLOCATE(phf_ener(ntemp,ngeo))
IF (.NOT.ALLOCATED(phf_entropy)) ALLOCATE(phf_entropy(ntemp,ngeo))
IF (.NOT.ALLOCATED(phf_cv)) ALLOCATE(phf_cv(ntemp,ngeo))

CALL zero_point_energy_ph(ph_freq_save(igeom), e0)

DO itemp = 1, ntemp
   temp(itemp) = tmin + (itemp-1) * deltat
   IF (MOD(itemp,30)==0) WRITE(6,'(5x,"Computing temperature ", i5)') itemp
   CALL free_energy_ph(ph_freq_save(igeom), temp(itemp), &
                                       phf_free_ener(itemp,igeom))
   CALL vib_energy_ph(ph_freq_save(igeom), temp(itemp), &
                                       phf_ener(itemp, igeom))
!   CALL vib_entropy_ph(ph_freq_save(igeom), temp(itemp), &
!                                       phf_entropy(itemp, igeom))
   CALL specific_heat_cv_ph(ph_freq_save(igeom), temp(itemp), &
                                       phf_cv(itemp, igeom))
   phf_free_ener(itemp,igeom)=phf_free_ener(itemp,igeom)+e0
   phf_ener(itemp,igeom)=phf_ener(itemp,igeom)+e0
END DO
phf_entropy(:,igeom)=(phf_ener(:, igeom) - phf_free_ener(:, igeom))/  &
                        temp(:)
IF (ionode) THEN
   iu_therm=2
   OPEN (UNIT=iu_therm, FILE=TRIM(fltherm)//'_ph', STATUS='unknown',&
                                                     FORM='formatted')
   WRITE(iu_therm,'("# Zero point energy is:", f9.5, " Ry/cell,", f9.5, &
                    &" kJ*N/mol,", f9.5, " kcal*N/mol")') e0, &
                       e0 * 1313.313_DP, e0 * 313.7545_DP 
   WRITE(iu_therm,'("# Temperature T in K, ")')
   WRITE(iu_therm,'("# Energy and free energy in Ry/cell,")')
   WRITE(iu_therm,'("# Entropy in Ry/cell/K,")')
   WRITE(iu_therm,'("# Heat capacity Cv in Ry/cell/K.")')
   WRITE(iu_therm,'("# Multiply by 13.6058 to have energies in &
                       &eV/cell etc..")')
   WRITE(iu_therm,'("# Multiply by 13.6058 x 23060.35 = 313 754.5 to have &
                  &energies in cal*N/mol.")')
   WRITE(iu_therm,'("# We assume that N_A cells contain N moles &
                  &(N_A is the Avogadro number).")')
   WRITE(iu_therm,'("# For instance in silicon N=2. Divide by N to have &
                   &energies in cal/mol etc. ")')
   WRITE(iu_therm,'("# Multiply by 13.6058 x 96526.0 = 1 313 313 to &
                  &have energies in J/mol.")')
   WRITE(iu_therm,'("#",5x,"   T  ", 7x, " energy ", 4x, "  free energy ",&
                  & 4x, " entropy ", 7x, " Cv ")') 

   DO itemp = 1, ntemp
      WRITE(iu_therm, '(5e16.8)') temp(itemp), &
                    phf_ener(itemp,igeom), phf_free_ener(itemp,igeom), &
                    phf_entropy(itemp,igeom), phf_cv(itemp,igeom)
   END DO

   CLOSE(iu_therm)
END IF

RETURN
END SUBROUTINE write_thermo_ph
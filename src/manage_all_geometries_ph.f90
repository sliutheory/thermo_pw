!
! Copyright (C) 2017 Andrea Dal Corso
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!--------------------------------------------------------------------------
SUBROUTINE manage_all_geometries_ph()
!--------------------------------------------------------------------------
!
!  This routine controls the calculation of the phonon dispersions 
!  when geometries are made in parallel. It first reads the input files
!  of all the phonon calculations and computes all the tasks to do.
!  Then it runs asynchronously all the tasks and finally collects the 
!  results.
!
  USE input_parameters, ONLY : outdir

  USE thermo_mod,       ONLY : no_ph, start_geometry, last_geometry, &
                               phgeo_on_file
  USE control_ph,       ONLY : always_run, low_directory_check, trans

  USE distribute_collection, ONLY : me_igeom
  USE mp_asyn,          ONLY : stop_signal_activated
  USE mp_images,        ONLY : nimage, my_image_id
  USE mp,               ONLY : mp_barrier
  USE mp_world,         ONLY : world_comm
  USE output,           ONLY : fildyn
  USE control_thermo,   ONLY : outdir_thermo, after_disp, lq2r
  USE io_global,        ONLY : stdout

IMPLICIT NONE

INTEGER  :: part, nwork, igeom, iaux
CHARACTER(LEN=6) :: int_to_char
LOGICAL :: ldcs, something_todo

CHARACTER (LEN=256) :: auxdyn=' '

always_run=.TRUE.
CALL start_clock( 'PHONON' )
CALL check_phgeo_on_file()
IF (.NOT.after_disp) THEN
!
!  Initialize the work of all the geometries and analyze what is on disk
!  This routine must be called by all processors
!
   CALL check_geo_initial_status(something_todo)
!
!  Initialize the asynchronous work
!
   IF (something_todo) THEN
      auxdyn=fildyn
      part=2
      CALL initialize_thermo_work(nwork, part, iaux)
!
!  Asynchronous work starts here. No communication is
!  allowed except though the master/slave mechanism
!  
      CALL run_thermo_asynchronously(nwork, part, 1, auxdyn)

      CALL deallocate_asyn()
      IF (stop_signal_activated) GOTO 100
   ENDIF
!
!  Now all calculations are done, we collect the results. 
!  Each image acts independently. The total number of collection tasks
!  are divided between images. The processors must be resynchronized here
!  otherwise some partial dynamical matrix could be missing.
!
   CALL mp_barrier(world_comm)
   IF (trans) CALL divide_all_collection_work()
   DO igeom=start_geometry, last_geometry
      IF (.NOT.me_igeom(igeom)) CYCLE
      WRITE(stdout,'(/,5x,40("%"))') 
      WRITE(stdout,'(5x,"Collecting geometry ", i5)') igeom
      WRITE(stdout,'(5x,40("%"),/)') 
      outdir=TRIM(outdir_thermo)//'/g'//TRIM(int_to_char(igeom))//'/'
      !
      ! ... reads the phonon input
      !
      CALL initialize_geometry_and_ph(.TRUE., igeom, auxdyn)
      ldcs=low_directory_check
      low_directory_check=.TRUE.
      CALL check_initial_geometry(auxdyn)
      low_directory_check=ldcs

      CALL manage_collection(auxdyn, igeom)

      CALL close_ph_geometry(.TRUE.)
   ENDDO
   CALL clean_collection_work()
ENDIF
!
!  resynchronize all processors, otherwise some dynamical matrix could be
!  missing. The calculation of the thermodynamical properties is
!  parallelized over all processors, so the following routines must
!  be called by all images.
!
CALL mp_barrier(world_comm)

DO igeom=start_geometry, last_geometry
   IF (no_ph(igeom)) CYCLE
   WRITE(stdout,'(/,5x,40("%"))') 
   WRITE(stdout,'(5x,"Computing thermodynamic properties", i5)') igeom
   WRITE(stdout,'(5x,40("%"),/)') 

   CALL set_files_names(igeom)
   auxdyn=fildyn
!
!  Compute the dispersions and the thermodynamic properties
!
   IF (lq2r) CALL manage_ph_postproc(auxdyn, igeom)

ENDDO
100 CONTINUE
CALL restore_files_names()

RETURN
END SUBROUTINE manage_all_geometries_ph

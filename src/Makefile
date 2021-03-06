# Makefile for thermo_pw 

include ../../make.inc

# location of needed modules and included files (if any)
MODFLAGS= $(BASEMOD_FLAGS) \
          $(MOD_FLAG)../../PW/src  \
          $(MOD_FLAG)../../dft-d3/ \
          $(MOD_FLAG)../../LR_Modules \
          $(MOD_FLAG)../../PHonon/PH \
          $(MOD_FLAG)../lib \
          $(MOD_FLAG)../qe \
          $(MOD_FLAG).

#objects of libthermo_pw.a
THERMOOBJS = \
adjust_tau.o \
addusdens1d_so.o \
allocate_thermo.o \
bands_sub.o \
bcast_thermo_input.o \
b_factor_reduction.o \
check_existence.o \
check_file_exists.o \
check_all_geometries_done.o \
check_el_cons.o \
check_el_cons_qha.o \
check_geo_initial_status.o \
check_phgeo_on_file.o \
clean_bfgs_history.o \
clean_dfft.o \
clean_ngeo.o \
clean_path.o \
collect_everything.o \
collect_info.o \
compute_cp.o \
compute_density.o \
compute_el_comp_t.o \
compute_eref_band.o \
compute_omega_geo.o \
deallocate_asyn.o \
deallocate_thermo.o \
deallocate_q2r.o \
do_pwscf.o \
do_berry.o \
do_phonon.o \
dos_sub.o \
dynmatrix_tpw.o \
elastic_constants_t.o \
ev_sub.o \
float_to_char.o \
find_symmetry.o \
find_band_sym_proj.o \
find_mode_sym_proj.o \
fit_frequencies.o \
generate_k_along_lines_kz.o \
generalized_phdos.o \
gen_qpoints.o \
initialize_geometry_and_ph.o \
initialize_thermo_work.o \
interpolate_bfact.o \
interpolate_el_cons.o \
interpolate_freq.o \
interpolate_free_ener_strain.o \
interpolate_thermo.o \
io_bands.o \
initialize_ph_geometry.o \
local_dos1d_so.o \
manage_anhar.o   \
manage_bands.o   \
manage_elastic_cons.o \
manage_elastic_cons_qha.o \
manage_elastic_cons_qha_2.o \
manage_energy_minimum.o \
manage_piezo_tensor.o \
manage_ph.o \
manage_all_geometries_ph.o \
manage_ph_postproc.o \
manage_ph_symmetry.o \
manage_surface_states.o \
manage_xrdp.o \
matdyn_sub.o \
plan_avg_sub.o \
plot_bz.o \
plot_anhar.o \
plot_anhar_anis.o \
plotband_sub.o \
plot_2d_bz.o \
plot_dispersion.o \
plot_dos.o \
plot_ef.o \
plot_e_ke.o \
plot_e_nk.o \
plot_formf.o \
plot_gruneisen_band_anis.o \
plot_elastic_t.o \
plot_epsilon_omega.o \
plot_macro_el_t.o \
plot_multi_energy.o \
plot_mur.o \
plot_phdos.o \
plot_thermo.o \
plot_xrdp.o \
print_polarization.o \
proj_band_structure.o \
q2r_sub.o \
quadratic_fit.o \
read_elastic_qha.o \
readmodes.o \
read_state_densities.o \
run_thermo_asyncronously.o \
save_ph_variables.o \
set_2d_bz_path.o \
set_bz_path.o \
set_dos_kpoints.o \
set_elastic_constants_t.o \
set_elastic_cons_work.o \
set_files_names.o \
set_fft_mesh.o \
set_k_points.o \
set_paths_disp.o \
set_piezo_tensor_work.o \
set_temperature.o \
set_thermo_work_todo.o \
set_work_for_elastic_const.o \
simple_nonanal.o \
simple_plot.o \
something_to_do_all.o \
surface.o     \
sym_band_sub.o \
thermo_mod.o \
thermo_readin.o \
thermo_setup.o \
thermo_summary.o \
write_anhar.o \
write_anhar_anis.o \
write_e_nk.o \
write_e_ke.o  \
write_e_omega.o \
write_el_thermo.o \
write_ev_input.o \
write_elastic_t.o \
write_elastic_t_qha.o \
write_gruneisen_band.o \
write_gruneisen_band_anis.o \
write_gnuplot_energy.o \
write_minimum_energy_data.o \
write_mur.o \
write_phdos.o \
write_ph_freq.o \
write_ph_dispersions.o \
write_quadratic.o \
write_thermo.o 

#libraries of QE
PWOBJS = ../../PHonon/PH/libph.a \
         ../../PP/src/libpp.a \
         ../../LR_Modules/liblrmod.a \
         ../../PW/src/libpw.a 

#library modules of QE
QEMODS = ../../Modules/libqemod.a \
         ../../KS_Solvers/libks_solvers.a \
         ../../FFTXlib/libqefft.a \
         ../../LAXlib/libqela.a   \
         ../../UtilXlib/libutil.a \
         ../../dft-d3/libdftd3qe.a

#libraries of thermo_pw
LIBTHERMO = ../qe/thermo_qe.a \
            ../lib/thermo_lib.a 

MODULES = $(LIBTHERMO) $(PWOBJS) $(QEMODS) $(LIBOBJS)

all : thermo_pw.x 

thermo_pw.x : thermo_pw.o libthermo_pw.a $(MODULES)
	$(LD) $(LDFLAGS) -o $@ ./thermo_pw.o ./libthermo_pw.a \
              ../../PHonon/PH/rigid.o ../../PHonon/PH/write_eigenvectors.o \
        $(MODULES) $(QELIBS)
	- ( cd ../../bin ; ln -fs ../thermo_pw/src/thermo_pw.x . )

libthermo_pw.a : $(THERMOOBJS) 
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

clean :
	- /bin/rm -f *.x *.o *.a *~ *_tmp.f90 *.d *.mod *.i *.L
	- /bin/rm -rf ../../bin/thermo_pw.x 

include make.depend
# DO NOT DELETE

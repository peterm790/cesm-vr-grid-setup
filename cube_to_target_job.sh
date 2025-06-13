#!/bin/bash
#PBS -N cube_to_target
#PBS -A Pxxxxxxxxx
#PBS -j oe
#PBS -k eod
#PBS -S /bin/bash
#PBS -l select=1:ncpus=1
#PBS -A Pxxxxxxxxx
#PBS -q main
#PBS -l walltime=12:00:00
#PBS -o out_WCSAF.log

cd $PBS_O_WORKDIR

./cube_to_target \
  --rrfac_manipulation \
  --grid_descriptor_file="${REPO}/grids/${grid_name}_np4_SCRIP.nc" \
  --intermediate_cs_name="/glade/campaign/cgd/amp/pel/topo/cubedata/gmted2010_modis_bedmachine-ncube3000-220518.nc" \
  --output_grid="${grid_name}" \
  --rrfac_max=4 \
  --smoothing_scale=100.0 \
  -u "Peter Marsh, peter.marsh@uct.ac.za"
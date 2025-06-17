# Creating and Running Variable Resolution Grid in CESM

This documents my process of creating a Variable Resolution Grid in CESM. It is based on the tutorial by Louisa Emmons available [here](https://wiki.ucar.edu/spaces/MUSICA/pages/611287733/Custom+Grid+in+CESM).

The original tutorial is probably more complete! This is just a messy living doc of trying to make it work!

## Table of Contents
- [Creating and Running Variable Resolution Grid in CESM](#creating-and-running-variable-resolution-grid-in-cesm)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Step 1: Log in](#step-1-log-in)
  - [Step 2: Configure shell for work flow](#step-2-configure-shell-for-work-flow)
  - [step 3: Build The Grid Editor Tool](#step-3-build-the-grid-editor-tool)
  - [Step 4: Make a Grid!](#step-4-make-a-grid)
      - [Now we can create the final \_EXODUS.nc file](#now-we-can-create-the-final-_exodusnc-file)
      - [Next up create a mesh.](#next-up-create-a-mesh)
  - [Step 4 and 3/4 We need a version of CESM3 installed](#step-4-and-34-we-need-a-version-of-cesm3-installed)
  - [Step 5: Modify the CESM input files to match our new grid](#step-5-modify-the-cesm-input-files-to-match-our-new-grid)
    - [a) regrid CAM IC](#a-regrid-cam-ic)
    - [b) regrid atmsrf file](#b-regrid-atmsrf-file)
    - [c) create topography file](#c-create-topography-file)
    - [d) Surface Datasets for CTSM (CLM)](#d-surface-datasets-for-ctsm-clm)
  - [Step 6: Config CESM to play with our new files!](#step-6-config-cesm-to-play-with-our-new-files)
  - [step 7: create a new case](#step-7-create-a-new-case)
    - [update the CAM namelist](#update-the-cam-namelist)
    - [set the time step](#set-the-time-step)
    - [update the CLM namelist](#update-the-clm-namelist)
    - [Run the model](#run-the-model)
- [data to plot](#data-to-plot)
- [For restarting here are all the exports:](#for-restarting-here-are-all-the-exports)
- [glossary of pete's cases:](#glossary-of-petes-cases)
- [even messier notes:](#even-messier-notes)

## Prerequisites

- Access to NCAR's CASPER computing cluster. (or a computer with the full CESM model and dependencies installed)
- Xquartz on your local machine (X11 forwarding capability for GUI applications)

## Step 1: Log in

1. Connect to CASPER using SSH with X11 forwarding:
   ```bash
   ssh -YX username@casper.ucar.edu
   ```
   Notes: 
   
   - Replace `username` with your NCAR username. The `-YX` flags enable X11 forwarding for GUI applications.
   - You will also need to have xquartz installed


## Step 2: Configure shell for work flow 
It would make sense to have some of this in your .bashrc, I'm not doing this yet as I'm not fully sure what will change often and whats static yet. 

First lets decide on a name for our grid.

Here the `ne0np4` is the standard spectral element grid. (I think)

I've chosen a name of `WCSAF` for Western Cape, South Africa and `ne30x4` is the standard `ne30` spectral grid with a 1-degree resolution equivalent, with 5 faces across the globe. 


   ```bash
   export grid_name=ne0np4.WCSAF.ne30x4
   export grid_label=WCSAF.ne30x4
   ```

We can now set up a repo to make the grid. Our initial condition files will end up here eventually so this needs to be outside of the home directory.  

At NCAR this is `/glade/work/` kind of equivalent to CSAG's `/terra/users/`

```bash
export REPO=/glade/work/$USER/grid_tut/$grid_name

mkdir $REPO

cd $REPO
```
## step 3: Build The Grid Editor Tool

First we need to install and use the [Mesh Generation tool kit](https://github.com/ESMCI/Community_Mesh_Generation_Toolkit.git)

There is a small bug in the code fixed in the [Pull Request](https://github.com/ESMCI/Community_Mesh_Generation_Toolkit/pull/5). So clining straight from that branch is easier here. 

**Make sure it is still open, if it's merged then rather clone the latest available.**

```bash
git clone --branch path-1 git@github.com:lkemmons/Community_Mesh_Generation_Toolkit.git

cd Community_Mesh_Generation_Toolkit

export VRM_tools=$REPO/Community_Mesh_Generation_Toolkit/VRM_tools
```

Next up we load dependancies and build the VRM (variable Resolution Mesh) Editor

```bash
cd ${VRM_tools}/VRM_Editor/src
module load gcc 
module load ncarenv/23.10
qmake VRM_Editor.pro # this .pro file is specific to NCAR's system, and would need to be modified to run elsewhere (I think!) 
make

module load gnu # this fails on casper but doesn't seem important
make -f Makefile-Create_VRMgrid
```

## Step 4: Make a Grid!

We can now go back to the top of our working repo

```bash
cd $REPO

mkdir grids # make a folder to save our grids to

cd grids

${VRM_tools}/VRM_Editor/src/VRM_Editor # run the GUI
```

This will open a GUI to create the grid. *Refer to the original tutorial for more detailed instructions*

*Take some screen shots or notes along the way you will need to remember the `grid_type`, `resolution`, `refine_level`, `smooth_type`, `smooth_dist`, `smooth_iter`, `x_rotate`, `y_rotate` and `lon_shift` used*

1) Click `Generate VarMesh` to create a base grid
2) Ideally you want your refined region in the middle of a face. Use `Longitude shift` to rotate the grid east/west. Shifting North South can result in some strange behaviour due to the geometry but using `rotate-Y` can achieve this. Ideally you want the borders of your refinement to align along the grid lines, if you want a grid that is not square in reference to lat/lons use `rotate-X` to align the global grid to your desired axis. 
3)  When you are happy with your grid you can now create the refinement region. go to `edit` tab, >  `Edit refine Map` > `Polygon Editor` (or rectangle but polygon is usually the best even if the goal is a rectangle). This creates a region somewhere in the pacific. Now enjoy spending hours moving it to your desired location :) Click `Exit Edit Mode` when you are done. This is scarey but don't worry you haven't lost your work. 
4)  Go back to the first tab (`VRM`). Now we can select the desired upscaling amount. I believe `LOWCONN` is best. the upscaling is exponential ie. `max res` = `OG grid` / (2^`refinement level`). I just used `refinement level` = 2 for a 0.25 degree refinement. Then select the smoothing from OG to refinement grid. I think this is in units of how many OG grid cells are scaled. I used `spring` with `iterations = 2` and `length = 2`. More smoothing is probably better but makes it harder to get neat borders. 
   
   """The LOWCONN setting uses templates that span 2x2 base elements to transition between resolutions, and the SPRING smoothing rounds out the element shapes to reduce sharp angles.  There may be situations when other settings give better results.""" - [Louisa's tutorial](https://wiki.ucar.edu/spaces/MUSICA/pages/611287733/Custom+Grid+in+CESM3) 

Ideally a 'halo' should be added around the refinement region to step down the resolution, I never got the hang of this. 

Next up use the GUI to save the grid under the actions menu (hiding in the top left of window). Save a {grid_name}.nc via `Save Refinement Map` and a .dat file via `Write Refinement Grid`. The nc allows you to resart making your grid and is used to get some meta/descriptive data for your grid. The .dat does the work when creating the grid. This means you can open the file in an editor and smooth out any odd shapes that you could not fix in the editor. 

#### Now we can create the final _EXODUS.nc file

it is possible in the GUI I believe but if you have manualy edited the .dat (advised), then via terminal is best. 

```bash
${VRM_tools}/VRM_Editor/src/Create_VRMgrid \
  --refine_type "LOWCONN" \
  --grid_type "CubeSquared" \
  --resolution 30 \
  --refine_level 2 \
  --smooth_type "SPRING" \
  --smooth_dist 2 \
  --smooth_iter 2 \
  --x_rotate 0 \
  --y_rotate -20 \
  --lon_shift 20 \
  --refine_file "${grid_name}.nc" \
  --refine_cube "${grid_name}.dat" \
  --output "${grid_name}_EXODUS.nc"
```

And a few more supporting metadata files. 

first build Gen_ControlVolumes.exe (with GNU compiler)

```bash
cd ${VRM_tools}/VRM_ControlVolumes/src
module load gcc
make
module load intel
```
and use it to build an input name list 
```bash
cd $REPO/grids

cp ${VRM_tools}/VRM_ControlVolumes/src/input.nl input-${grid_name}.nl
```

We now need to manually update this namelist to match our naming and repo config/paths

```bash
${VRM_tools}/VRM_ControlVolumes/src/Gen_ControlVolumes.exe input-${grid_name}.nl > LOG_gen_ControlVolumes
```

This produces the `SCRIP` and `LATLON` file named as per your updates to `input-${grid_name}.nl` so ideally `${grid_name}_np4_SCRIP.nc` and `${grid_name}_np4_LATLON.nc`

To get a sense of the cost of your grid you can check the number of columns in the LATLON file: 

```ncdump -h ${grid_name}_np4_LATLON.nc```

I have ncols = 70850

Not sure how many a standard grid has.... would be a nice reference. 

#### Next up create a mesh. 

```
module load mpi-serial # I've just been using the defaults check tutorial for version numbers if these give problems
module load esmf
```

next up this monster script to create the unstructure grid at the time of writing this path works. But if not use the below to find the right path to ESMF_Scrip2Unstruct executable.

```bash
module show esmf # /8.5.0  # and look for the PATH dir
```

and create the unstructured mesh file: 

```bash
/glade/u/apps/casper/23.10/spack/opt/spack/esmf/8.5.0/mpi-serial/2.3.0/oneapi/2023.2.1/dfkx/bin/ESMF_Scrip2Unstruct ${grid_name}_np4_SCRIP.nc ${grid_name}_np4_MESH.nc 0
```

Note the 0 at the end. 

We now have a shareable/reusable grid. The next bits are how to use this to create initail conditions files to do a run!

The Rest of This Is Just for Running a Model Using This newly created Grid!

## Step 4 and 3/4 We need a version of CESM3 installed 

Check the latest 'beta' version by viewing all tags at the cesm git [repo](https://github.com/ESCOMP/CESM/tags)


get the code

```bash
cd /glade/work/$USER/code/ # make the code dir if you dont have it

git clone https://github.com/ESCOMP/CESM.git cesm3_0_beta06 # clone and name the dir, be sure this dir doesnt already exist from previous work. I think a clean version makes sense

cd cesm3_0_beta06 # open model
 
git checkout cesm3_0_beta06 # checkout the beta 6 barnch

./bin/git-fleximod update # this is an internal tool (is it?) that links to the correct static files and dependencies. Stored at a shared location
```

## Step 5: Modify the CESM input files to match our new grid

```
cd $REPO
mkdir inic 
mkdir maps  
mkdir atmsrf
mkdir topo
```
### a) regrid CAM IC

First up we modify the interpic program. This is used to interpolate surface datasets from their source grid to the model grid

step 1 is to modify the file at 

`cesm3_0_beta06/components/cam/tools/interpic_new/MakeFile`

here we need to update `LIB_NETCDF` from using /usr/local/lib to `$(NETCDF)/lib` and a few other things. Not sure why?

```
Edit Makefile:
l.15 from: LIB_NETCDF := /usr/local/lib
     to: LIB_NETCDF := $(NETCDF)/lib
l.18 from: INC_NETCDF := /usr/local/include
     to: INC_NETCDF := $(NETCDF)/include
l.99 from: LDFLAGS = -L$(LIB_NETCDF) -lnetcdf
     to: LDFLAGS = -L$(LIB_NETCDF) -lnetcdff -lnetcdf  
```
**I have also copied a version of this update MakeFile to this repo called Makefile_interpic_cesm3_mod**

<font color="red">**This could MAYBE be why this run is crashing need to try one with this and the FClimo2010 compset to test**</font>

now we can use this to create 

```bash
cd $REPO/inic
cp ${VRM_tools}/gen_CAMncdata/TEMPLATES/interpic_script_TEMPLATE.sh interpic_script_WCSAF.sh
vim interpic_script_WCSAF.sh # and update to your settings 
```

**or copy the interpic_script_WCSAF.sh in this repo**

then run this shell. Louisa uses qcmd (slurm equivalent) to run the job as a batch. Kwesi suggests just doing this in derecho for simplicity. Which I will do from now on. 

```bash
module load nco
module load ncl
./interpic_script_WCSAF.sh > log
```

### b) regrid atmsrf file

again on derecho or use qcmd for ncl command.

```
cd $REPO/atmsrf
cp ${VRM_tools}/gen_atmsrf/TEMPLATES/gen_atmsrf_TEMPLATE.ncl gen_atmsrf_WCSAF.ncl # or copy from repo
vim gen_atmsrf_WCSAF.ncl # update to match your set up
module load ncl
module load esmf
ncl gen_atmsrf_WCSAF.ncl > log
```
**or copy the gen_atmsrf_WCSAF.ncl in this repo, which I created as qcmd seemed to not be passing the ncl and esmf dependencies**


### c) create topography file

This will need to be batched as it takes a long time (+- 3 hours) so running on derecho via shell not possible. 

"The following steps get the [Topo software](https://github.com/NCAR/Topo), build the cube_to_target executable and run it. Documentation for Topo is available on its wiki page."

```bash
cd $REPO/topo
git clone https://github.com/NCAR/Topo.git Topo
cd Topo/cube_to_target


module load ncarenv ncl gcc ncarcompilers hdf5 netcdf openmpi esmf # most should already be loaded

gmake -f Makefile clean
gmake -f Makefile

qcmd -l walltime=12:00:00 -l select=1:ncpus=1 -- ./cube_to_target \
  --rrfac_manipulation \
  --grid_descriptor_file="${REPO}/grids/${grid_name}_np4_SCRIP.nc" \
  --intermediate_cs_name="/glade/campaign/cgd/amp/pel/topo/cubedata/gmted2010_modis_bedmachine-ncube3000-220518.nc" \
  --output_grid="${grid_name}" \
  --rrfac_max=4 \
  --smoothing_scale=100.0 \
  -u "Peter Marsh, peter.marsh@uct.ac.za" > out_WCSAF
```
*So this qcmd command works but requires you to remain connected, else it will be killed. I decided to instead create a shell and run it as a batch job from derecho*

instead of the above (from derecho). Copy the file `cube_to_target_job.sh` to the dir

```bash 
qsub -V cube_to_target_job.sh # -V passes env vars to job
```


### d) Surface Datasets for CTSM (CLM)

this can be done on derecho again. 

We need to install CTSM (just as we did CESM)

```bash
cd /glade/work/$USER/code/ 
git clone https://github.com/ESCOMP/CTSM ctsm5.3 
cd ctsm5.3
git checkout ctsm5.3.0 # not sure which are stable and which are dev 

./bin/git-fleximod update -o

cd tools/mksurfdata_esmf
./gen_mksurfdata_build
```

Generate namelist files containing specifications for creating the surface datasets.  

```bash
module load conda/latest
conda activate npl
```

Now we run a convenience script to generate the namelist with the correct res and ncols for a variable mesh 

remember to update ncol!

```bash
./gen_mksurfdata_namelist \
  --res "${grid_label}" \
  --start-year 1979 \
  --end-year 2026 \
  --ssp-rcp SSP3-7.0 \
  --model-mesh "${REPO}/grids/${grid_name}_np4_MESH.nc" \
  --model-mesh-nx 70850 \
  --model-mesh-ny 1
```
 This creates files like: landuse_timeseries_SSP3-7.0_1979-2026_78pfts.txt and surfdata_${grid_label}_SSP3-7.0_1979_78pfts_c70850.namelist.

now a new job

```bash
./gen_mksurfdata_jobscript_single \
  --number-of-nodes 4 \
  --tasks-per-node 128 \
  --namelist-file surfdata_WCSAF.ne30x4_SSP3-7.0_1979_78pfts_c250613.namelist
```

this creates mksurfdata_jobscript_single.sh which we must update to include our project number

```bash 
vim mksurfdata_jobscript_single.sh # update with proj number

qsub mksurfdata_jobscript_single.sh

conda deactivate
```

This takes a few minutes and creates the netcdf files that will be used in your simulation. Lets copy them to the repo

```bash
mkdir ${REPO}/land
cp *.nc ${REPO}/land/. # maybe mv more space efficient
```

## Step 6: Config CESM to play with our new files!

asuming CESM is at `/glade/work/$USER/code/cesm3_0_beta06`

```bash
cd /glade/work/$USER/code/cesm3_0_beta06/
```

We need to edit the `component_grids_nuopc.xml` file. 
This defines valid combinations of component grids our model components (eg atm, ocean, land) can run (with the nuopc driver?)

```bash
cd ccs_config/
vim component_grids_nuopc.xml
```

and add (remember to update ncols)

```
  <domain name="ne0np4.WCSAF.ne30x4">
    <nx>70850</nx> <ny>1</ny>
    <mesh>/glade/work/$USER/grid_tut/ne0np4.WCSAF.ne30x4/grids/ne0np4.WCSAF.ne30x4_np4_MESH.nc</mesh>
    <desc>ne0np4.WCSAF.ne30x4_np4 is a Spectral Elem 1-deg grid with a 1/4 deg refined region over South Africa, optimised to the Western Cape:</desc>
    <support>testing testing 123</support>
  </domain>
```

then

```bash
vim modelgrid_aliases_nuopc.xml
```

add 

not sure what the `mt12` is for in the alias name? 

```
  <model_grid alias="ne0np4.WCSAF.ne30x4_np4_mt12" not_compset="_POP">
    <grid name="atm">ne0np4.WCSAF.ne30x4</grid>
    <grid name="lnd">ne0np4.WCSAF.ne30x4</grid>
    <grid name="ocnice">ne0np4.WCSAF.ne30x4</grid>
    <mask>tx0.1v3</mask>
  </model_grid>
```

## step 7: create a new case

this is where the compsets come in. First we need to create a directory for these. I'm keeping everything in `/glade/work/$USER/`

```bash
mkdir /glade/work/$USER/cases
```

this will create a compset at `cases/`

```bash
cd /glade/work/${USER}/code/cesm3_0_beta06/cime/scripts/
./create_newcase \
  --case /glade/work/${USER}/cases/f.e3beta06.FHIST.WCSAF.ne30x4.01 \
  --res ne0np4.WCSAF.ne30x4_np4_mt12 \
  --compset FHIST \
  --run-unsupported \
  --project Pxxxxxxxx \
  --pecount 2048
```

now this becomes our case root. 

```bash
export CASEROOT=/glade/work/${USER}/cases/f.e3beta06.FHIST.WCSAF.ne30x4.01/

cd $CASEROOT
./case.setup
```

### update the CAM namelist 
then add the following to the namelist at `user_nl_cam`


Add to user_nl_cam:
```
ncdata = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/inic/cami-mam4_0000-01-01_ne0np4.WCSAF.ne30x4_L32_cYYMMDD.nc'
bnd_topo = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/topo/Topo/cube_to_target/output/ne0np4.WCSAF.ne30x4_gmted2010_modis_bedmachine_nc3000_Laplace0100_noleak_20250613.nc'
drydep_srf_file = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/atmsrf/atmsrf_ne0np4.WCSAF.ne30x4_YYMMDD.nc'
se_refined_mesh = .true.
se_mesh_file = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/grids/ne0np4.WCSAF.ne30x4_EXODUS.nc'
```
A `user_nl_cam` file is available in these notes for reference.

### set the time step

Set the timestep based on [recommended value](https://github.com/ESMCI/Community_Mesh_Generation_Toolkit/blob/master/VRM_tools/Docs/CAM-tsteps-inic-for-newgrids_v0.pdf)

`./xmlchange ATM_NCPL=192`

So for my ne30x4 grid 192 seems the recommended time step. This is number of seconds per day (86400) divided by this ATM_NCPL value to give us 86400/192 = 450 to give us a physics integration/ coupling every 7.5 minutes. This is in theory the optimum but can likely be pushed longer. Worth experimenting before doing a long run. 

### update the CLM namelist

Add to user_nl_clm:
```
fsurdat = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/land/surfdata_WCSAF.ne30x4_SSP3-7.0_1979_78pfts_c250613.nc'
flanduse_timeseries = '/glade/work/peterm/grid_tut/ne0np4.WCSAF.ne30x4/land/landuse.timeseries_WCSAF.ne30x4_SSP3-7.0_1979-2026_78pfts_c250613.nc'
```
I have also uploaded a `user_nl_clm` file to this repo for reference


Add the override flag in your individual case directory to ensure CTSM doesn’t error out due to an unsupported grid:

```bash
./xmlchange --append CLM_BLDNML_OPTS="-no-chk_res"
```

### Run the model

build
```bash
qcmd -- ./case.build
```

Set up to run a few days.

```bash  
./xmlchange RUN_STARTDATE="2010-01-01"
./xmlchange STOP_N="5"
```

Before running we should also pick a few key variables to save. Add the below to the end of the `user_nl_cam`

```bash
/
 avgflag_pertape = 'A', 'A'
 !mfilt          = 1,5
 !nhtfrq         = 0,-24
  mfilt          = 5,5
 nhtfrq         = -24,-24
 interpolate_gridtype           =   1,1
 interpolate_nlat               = 192,192
 interpolate_nlon               = 288,288
 interpolate_output             = .true.,.false.


 fincl1         = 'CLDLIQ', 'CLDTOT', 'CLOUD', 'PRECC', 'PRECT', 'PS', 'PSL', 'T', 'T500', 'T700', 'TS', 'U', 'U10', 'V', 'Z500', 'U500', 'U250', 'V500', 'V250', 'Z200', 'Z500', 'Z700'
 fincl2         = 'CLDLIQ', 'CLDTOT', 'CLOUD', 'PRECC', 'PRECT', 'PS', 'PSL', 'T', 'T500', 'T700', 'TS', 'U', 'U10', 'V', 'Z500', 'U500', 'U250', 'V500', 'V250', 'Z200', 'Z500', 'Z700'
 ```

 This will save the above listed varilables. And one of them will be interpolated back on to a standard grid. While the other will be left as just rows of the stretch grid in the netcdf file. We can then use [uxarray](https://github.com/UXARRAY/uxarray) to work with this data in it's native form.

To actually run the model, refer to [this quick start](https://escomp.github.io/CESM/versions/master/html/quickstart.html#run-the-case). But in essence:

```bash
./case.submit
```

Will do it. ****

To find out where the results will land up (in `glade/scatch/`):

```bash
./xmlquery RUNDIR,CASE,CASEROOT,DOUT_S,DOUT_S_ROOT
```
A useful utility to monitor your case is:

```bash
more CaseStatus
```

for my case successful results ended up at:

```bash
/glade/derecho/scratch/peterm/archive/f.e3beta06.FHIST.WCSAF.ne30x4.01/
```

this includes initial conditions, restart files and results files (with default variables and those defined in the user_nl_cam for atm, user_nl_clm for lnd, etc)

And logs as well as results for working or failed runs at 

```bash
/glade/derecho/scratch/peterm/f.e3beta06.FHIST.WCSAF.ne30x4.01/run/
```


If it does not run, try [adjusting parameters](https://github.com/ESMCI/Community_Mesh_Generation_Toolkit/blob/master/VRM_tools/Docs/CAM-tsteps-inic-for-newgrids_v0.pdf)

Save the final *cam.i.* file to use for future CAM simulations (ncdata in user_nl_cam). 

Save the final CLM restart file (*.clm2.r.*.nc) to use for finidat in user_nl_clm in future runs.

also see tut for how to run a CAM-chem case with met nidging and more. 

# data to plot

as `scrath` files are temporary and deleted once a month I have copied the files of interest from successful runs to `/glade/work/peterm/data/` this is for `f.e3beta06.FHIST.WCSAF.ne30x4.02` and `f.e3beta06.FHIST.ne30_ne30.03`

# For restarting here are all the exports:

```
export PBS_ACCOUNT=Pxxxxxxxx
export grid_name=ne0np4.WCSAF.ne30x4
export grid_label=WCSAF.ne30x4
export REPO=/glade/work/$USER/grid_tut/$grid_name
export VRM_tools=$REPO/Community_Mesh_Generation_Toolkit/VRM_tools
export CASEROOT=/glade/work/$USER/cases/f.e3beta06.FHIST.${grid_label}.01
```

# glossary of pete's cases:

these are all at `/glade/work/peterm/cases/`

| Case Name | Description | Outcome |
|-----------|-------------|----------|
| f.e3beta06.FHIST.ne30_ne30.01 | 1st stretch attempt | Failed to build `CLUBB` |
| f.e3beta06.FHIST.ne30_ne30.02 | 1st attempt with same model to build generic global grid | Failed to build `CLMBuildNamelist` - `FHIST` compset not available for cesm3 |
| f.e3beta06.FHIST.WCSAF.ne30x4.01 | 2nd stretch attempt with clean model install | Same `CLUBB` error |
| f.e3beta01.FHIST.ne30_ne30.01 | 2nd attempt at generic global but with beta01 | Same `CLMBuildNamelist` error |
| f.e3beta01.F2010climo.ne30_ne30.01 | 1st attempt at `F2010climo` compset with modified `interpic_new` file | Failed to build - `CLUBB error` (check this) |
| f.e3beta06.F2010climo.ne30_ne30.02 | 2nd attempt at `F2010climo` compset with clean model `cesm3_0_beta06_2` | Builds and runs! :) |
| f.e3beta06.F2010climo.WCSAF.ne30x4.01 | 1st attempt at Stretch grid with `F2010climo` and clean model `cesm3_0_beta06_2` | Also Builds and runs! :) |
| f.e3beta06.F2010climo.WCSAF.ne30x4.02 |  2nd attempt at stretch grid `cesm3_0_beta06_2` after modifying `interpic_new` in tutorial| Also Builds and runs! :), not sure what the cause of the `CLUBB` failure in `f.e3beta01.F2010climo.ne30_ne30.01` was, perhaps just a mistake, or partial build along the way |
| f.e3beta06.FHIST.ne30_ne30.03 | Standard ne30 global grid with `flanduse_timeseries = ' '` in `user_nl_clm`| Builds and runs! :) |
| f.e3beta06.FHIST.WCSAF.ne30x4.02 | Stretch grid running FHIST exactly as per tutorial| Builds and runs! :) not sure what happened above then|


# even messier notes:

`/glade/work/tilmes/derecho/highres/f.e22.cesm2.2.2_musica.FHIST.ne30np4.2010.001/user_nl_cam`

below controls the variables to save

my minimal version

```bash
/
 avgflag_pertape = 'A', 'A'
 !mfilt          = 1,5
 !nhtfrq         = 0,-24
  mfilt          = 5,5
 nhtfrq         = -24,-24
 interpolate_gridtype           =   1,1
 interpolate_nlat               = 192,192
 interpolate_nlon               = 288,288
 interpolate_output             = .true.,.false.


 fincl1         = 'CLDLIQ', 'CLDTOT', 'CLOUD', 'PRECC', 'PRECT', 'PS', 'PSL', 'T', 'T500', 'T700', 'TS', 'U', 'U10', 'V', 'Z500', 'U500', 'U250', 'V500', 'V250', 'Z200', 'Z500', 'Z700'
 fincl2         = 'CLDLIQ', 'CLDTOT', 'CLOUD', 'PRECC', 'PRECT', 'PS', 'PSL', 'T', 'T500', 'T700', 'TS', 'U', 'U10', 'V', 'Z500', 'U500', 'U250', 'V500', 'V250', 'Z200', 'Z500', 'Z700'
 ```

or lots but I think need chemistry to work with all 

```bash
/
 avgflag_pertape                = 'A', 'A', 'A', 'A', 'I', 'A', 'A', 'A', 'I'
 !mfilt          = 1,5,20,1,120,240,365,73,1
 !nhtfrq         = 0,-24,-6,0,-1,1,-24,-120,-1
  mfilt          = 5,5,20,1,120,240,365,73,1
 nhtfrq         = -24,-24,-6,0,-1,1,-24,-120,-1
 interpolate_gridtype           =   1,1,1,1,1
 interpolate_nlat               = 192,192,192,192,192
 interpolate_nlon               = 288,288,288,288,288
 interpolate_output             = .true.,.false.,.false.,.false.,.false.


 fincl1         = 'ACTNL', 'ACTREL', 'BURDENBCdn', 'BURDENDUSTdn', 'BURDENPOMdn', 'BURDENSEASALTdn', 'BURDENSO4dn', 'BURDENSOAdn', 'CDNUMC', 'CLDICE',
         'CLDLIQ', 'CLDTOT', 'CLOUD', 'CMFMC', 'CMFMCDZM', 'FCTL', 'FLDS', 'FLDSC', 'FLNR', 'FLNS', 'FLNSC',
         'FLNT', 'FLNTC', 'FLUT', 'FLUTC', 'FSDS', 'FSDSC', 'FSNR', 'FSNS', 'FSNSC', 'FSNTOA', 'FSNTOAC',
         'LHFLX', 'MASS', 'O3', 'OMEGA', 'OMEGA500', 'PBLH', 'PDELDRY', 'PM25_SRF', 'PRECC', 'PRECT', 'PS',
         'PSL', 'Q', 'QREFHT', 'QSNOW', 'RELHUM', 'RHREFHT', 'SHFLX', 'SOLIN', 'SOLLD', 'SOLSD', 'T',
         'T500', 'T700', 'T850', 'TAUBLJX', 'TAUBLJY', 'TAUGWX', 'TAUGWY', 'TAUX', 'TAUY', 'TGCLDIWP', 'TGCLDLWP',
         'TMQ', 'TREFHT', 'TREFHTMN', 'TREFHTMX', 'TS', 'TSMN:M', 'TSMX:X', 'U', 'U10',
         'V', 'Z3', 'Z500', 'U500', 'U250', 'UBOT', 'V500', 'V250', 'VBOT',
         'Z200', 'Z500', 'Z700', 'ZBOT', 'CLDTOT', 'Q', 'OMEGA', 'OMEGA850', 'OMEGA500', 'PSL', 'AODDUSTdn','AODVISstdn',
         'AODVISdn', 'dst_a1', 'dst_a2', 'dst_a3'
 fincl2         = 'ACTNL', 'ACTREL', 'BURDENBCdn', 'BURDENDUSTdn', 'BURDENPOMdn', 'BURDENSEASALTdn', 'BURDENSO4dn', 'BURDENSOAdn', 'CDNUMC', 'CLDICE',
         'CLDLIQ', 'CLDTOT', 'CLOUD', 'CMFMC', 'CMFMCDZM', 'FCTL', 'FLDS', 'FLDSC', 'FLNR', 'FLNS', 'FLNSC',
         'FLNT', 'FLNTC', 'FLUT', 'FLUTC', 'FSDS', 'FSDSC', 'FSNR', 'FSNS', 'FSNSC', 'FSNTOA', 'FSNTOAC',
         'LHFLX', 'MASS', 'O3', 'OMEGA', 'OMEGA500', 'PBLH', 'PDELDRY', 'PM25_SRF', 'PRECC', 'PRECT', 'PS',
         'PSL', 'Q', 'QREFHT', 'QSNOW', 'RELHUM', 'RHREFHT', 'SHFLX', 'SOLIN', 'SOLLD', 'SOLSD', 'T',
         'T500', 'T700', 'T850', 'TAUBLJX', 'TAUBLJY', 'TAUGWX', 'TAUGWY', 'TAUX', 'TAUY', 'TGCLDIWP', 'TGCLDLWP',
         'TMQ', 'TREFHT', 'TREFHTMN', 'TREFHTMX', 'TS', 'TSMN:M', 'TSMX:X', 'U', 'U10',
         'V', 'Z3', 'Z500', 'U500', 'U250', 'UBOT', 'V500', 'V250', 'VBOT',
         'Z200', 'Z500', 'Z700', 'ZBOT', 'CLDTOT', 'Q', 'OMEGA', 'OMEGA850', 'OMEGA500', 'PSL', 'AODDUSTdn','AODVISstdn',
         'AODVISdn', 'dst_a1', 'dst_a2', 'dst_a3'
```
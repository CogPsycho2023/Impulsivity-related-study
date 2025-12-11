#!/bin/bash

###############################################
# User-configurable paths (generic for GitHub)
###############################################

# Directory containing preprocessed functional volumes
input="/path/to/dpabi_analysis"

# Directory containing BBR outputs for each subject
BBR="/path/to/BBR_directory"

# Subject list file
subj="list.txt"

# HCP standard mesh atlas directories
mask="/path/to/HCPpipelines/global/templates/standard_mesh_atlases"
atlas="${mask}/resample_fsaverage"

# Surface directories produced earlier in your pipeline
RawSurf="RawSurf"
Surf164="Surf164"
Surf32="Surf32"

# Output time-series directories
RawSeries="Series/Raw"
Series164="Series/164"
Series32="Series/32"
Seriesdscalar="Series/dscalar"

mkdir -p "$Seriesdscalar" "$RawSeries" "$Series164" "$Series32"

###############################################

for subject in $(cat "$subj"); do

  # Extract cortical BOLD series using the BBR brain mask
  fslmaths \
    "$input/FunImgARCF/${subject}/Filtered_4DVolume.nii" \
    -mas "$BBR/${subject}_fun_brain.nii.gz" \
    "$BBR/${subject}.series_brain.nii.gz"

  for hem in lh rh; do

    # Project fMRI volume to native FS surface
    mri_vol2surf \
      --mov       "${BBR}/${subject}.series_brain.nii.gz" \
      --reg       "${BBR}/${subject}.bbr.dat" \
      --trgsubject T_${subject} \
      --interp    nearest \
      --projfrac  0.5 \
      --hemi      "${hem}" \
      --o         "${RawSeries}/${subject}.${hem}.func.gii" \
      --noreshape \
      --cortex \
      --surfreg   "T_${subject}/surf/${hem}.sphere.reg"

    # Resample native functional metric → fs_LR 164k
    wb_command -metric-resample \
      "${RawSeries}/${subject}.${hem}.func.gii" \
      "${RawSurf}/${subject}.${hem}.sphere.reg.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii" \
      ADAP_BARY_AREA \
      "${Series164}/${subject}.${hem}.164k.func.gii" \
      -area-surfs \
      "${RawSurf}/${subject}.${hem}.midthickness.surf.gii" \
      "${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii"

    # Resample fs_LR 164k → fs_LR 32k
    wb_command -metric-resample \
      "${Series164}/${subject}.${hem}.164k.func.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.32k_fs_LR.surf.gii" \
      ADAP_BARY_AREA \
      "${Series32}/${subject}.${hem}.32k.func.gii" \
      -area-surfs \
      "${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii" \
      "${Surf32}/${subject}.${hem}.32k.midthickness.surf.gii"

    # Smooth 32k surface metric
    wb_command -metric-smoothing \
      "${Surf32}/${subject}.${hem}.32k.midthickness.surf.gii" \
      "${Series32}/${subject}.${hem}.32k.func.gii" \
      4.25 \
      "${Series32}/${subject}.${hem}.32k.s4.25.func.gii"

    # Mask using the 32k ROI atlas
    wb_command -metric-mask \
      "${Series32}/${subject}.${hem}.32k.s4.25.func.gii" \
      "${mask}/${hem}.atlasroi.32k_fs_LR.shape.gii" \
      "${Series32}/${subject}.${hem}.32k.s4.25.func.gii"

  done

  # Create 32k dtseries (left + right hemisphere)
  wb_command -cifti-create-dense-timeseries \
    "${Seriesdscalar}/${subject}.32k.dtseries.nii" \
    -left-metric  "${Series32}/${subject}.lh.32k.s4.25.func.gii" \
    -right-metric "${Series32}/${subject}.rh.32k.s4.25.func.gii"

done

#!/bin/bash

#This script is designed for extracting individual gray-white matter contrast (GWC) from Freesurfer recon-all directories and resampling from individual surface to fs_LR 32k surface#
###############################################
# User-configurable paths (generic for GitHub)
###############################################

# Root directory containing FreeSurfer recon-all outputs
# (i.e., SUBJECTS_DIR; each subject has surf/, etc.)
T1="/path/to/T1_directory"

# Output / working directories (created in the current directory)
RawSurf="RawSurf"
Surf164="Surf164"
Surf32="Surf32"

# Text file with one subject ID per line (can be overridden by first argument)
subj="${1:-list}"

# HCP Pipelines standard_mesh_atlases:
# - mask points to the base standard_mesh_atlases directory
# - atlas points to its resample_fsaverage subdirectory
mask="/path/to/HCPpipelines/global/templates/standard_mesh_atlases"
atlas="${mask}/resample_fsaverage"

###############################################

mkdir -p "${RawSurf}" "${Surf164}" "${Surf32}"

# Loop over subjects listed in $subj
for subject in $(cat "${subj}"); do
  [ -z "${subject}" ] && continue
  echo "Processing subject: ${subject}"

  for hem in lh rh; do
    echo "  Hemisphere: ${hem}"

        #surface-resample preparation#
    wb_shortcuts -freesurfer-resample-prep \
      ${T1}/${subject}/surf/${hem}.white \
      ${T1}/${subject}/surf/${hem}.pial \
      ${T1}/${subject}/surf/${hem}.sphere.reg \
      ${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii \
      ${RawSurf}/${subject}.${hem}.midthickness.surf.gii \
      ${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii \
      ${RawSurf}/${subject}.${hem}.sphere.reg.surf.gii

    # Surface resampling: fs_LR 164k -> 32k
    wb_command -surface-resample \
      "${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.32k_fs_LR.surf.gii" \
      BARYCENTRIC \
      "${Surf32}/${subject}.${hem}.32k.midthickness.surf.gii"

    # Convert FreeSurfer WG metric (mgh) to GIFTI metric on white surface
    mris_convert -c \
      "${T1}/${subject}/surf/${hem}.w-g.pct.mgh" \
      "${T1}/${subject}/surf/${hem}.white" \
      "${RawSurf}/${subject}.${hem}.WG.shape.gii"

    # Metric resampling: native (FS) -> fs_LR 164k
    wb_command -metric-resample \
      "${RawSurf}/${subject}.${hem}.WG.shape.gii" \
      "${RawSurf}/${subject}.${hem}.sphere.reg.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii" \
      ADAP_BARY_AREA \
      "${Surf164}/${subject}.${hem}.WG.164k.shape.gii" \
      -area-surfs \
      "${RawSurf}/${subject}.${hem}.midthickness.surf.gii" \
      "${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii"

    # Metric resampling: fs_LR 164k -> fs_LR 32k
    wb_command -metric-resample \
      "${Surf164}/${subject}.${hem}.WG.164k.shape.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.164k_fs_LR.surf.gii" \
      "${atlas}/fs_LR-deformed_to-fsaverage.${hem}.sphere.32k_fs_LR.surf.gii" \
      ADAP_BARY_AREA \
      "${Surf32}/${subject}.${hem}.WG.32k.shape.gii" \
      -area-surfs \
      "${Surf164}/${subject}.${hem}.midthickness.164k.surf.gii" \
      "${Surf32}/${subject}.${hem}.32k.midthickness.surf.gii"

    # Smooth the 32k metric on the 32k midthickness surface
    wb_command -metric-smoothing \
      "${Surf32}/${subject}.${hem}.32k.midthickness.surf.gii" \
      "${Surf32}/${subject}.${hem}.WG.32k.shape.gii" \
      4.25 \
      "${Surf32}/${subject}.${hem}.WG.32k.s4.25.shape.gii"

    # Mask with HCP atlas ROI
    wb_command -metric-mask \
      "${Surf32}/${subject}.${hem}.WG.32k.s4.25.shape.gii" \
      "${mask}/${hem}.atlasroi.32k_fs_LR.shape.gii" \
      "${Surf32}/${subject}.${hem}.WG.32k.s4.25.shape.gii"

  done

  # Create combined CIFTI dense scalar (lh + rh 32k WG metric)
  wb_command -cifti-create-dense-scalar \
    "${Surf32}/${subject}.WG.32k.dscalar.nii" \
    -left-metric  "${Surf32}/${subject}.lh.WG.32k.s4.25.shape.gii" \
    -right-metric "${Surf32}/${subject}.rh.WG.32k.s4.25.shape.gii"

done

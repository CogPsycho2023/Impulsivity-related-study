#!/bin/bash

###############################################
# User-configurable paths (generic for GitHub)
###############################################

# Subject list
subj="list.txt"

# Output directory for ROI FC maps
out="ROIFC"

# Directory containing dtseries files generated in previous script
Series="/path/to/SMRI/Series/dscalar"

###############################################

for subject in $(cat "$subj"); do
  #Take the seed from WG significant clusters separately#
  for ROI in WG; do
    mkdir -p "${out}/${ROI}"

    # Compute mean FC between ROI cluster and every vertex
    wb_command -cifti-average-roi-correlation \
      "${out}/${ROI}/${subject}.FC.dscalar.nii" \
      -cifti-roi  "${out}/${ROI}/${ROI}.cluster.dscalar.nii" \
      -cifti      "${Series}/${subject}.32k.dtseries.nii"

  done

done

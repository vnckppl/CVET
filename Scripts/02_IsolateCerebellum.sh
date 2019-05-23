#!/bin/bash

# Isolate Cerebellum and Brain Stem using SUIT toolbox

# Environment
SUB="subject_string"
oDIR="/my/output/folder/${SUB}"

# Initialize FSL
source /usr/share/fsl/5.0/etc/fslconf/fsl.sh

# Apparently, SUIT only works if the data are in LPI
echo "Reorient to standard space (LPI)"
fslreorient2std \
    ${oDIR}/N4_${SUB}.nii \
    ${oDIR}/roN4_${SUB}_01.nii

# Unzip for SPM
echo "Unzip for SPM"
gunzip -v ${oDIR}/roN4_${SUB}_01.nii.gz

# Run isolation job
echo "Run SUIT isolate"
matlab \
    -nodesktop \
    -nosplash \
    -r "run ${sDIR}/${SUB}_isolate.m; quit;"

# Zip nifti files
echo "Zip nifti files"
cd ${oDIR}
find . -iname "*.nii" | xargs -I {} gzip -9 {}

exit

#!/bin/bash

# This script performas N4 bias field correction
# within a brain mask.

# Initialize FSL
source /usr/share/fsl/5.0/etc/fslconf/fsl.sh

# Path
sDIR=${sDIR}
aDIR=/home/Software/Anima-Binaries-2.2
export PATH=${PATH}:${sDIR}:${aDIR}


# Environment
SUB="subject_string"
iDIR="/my/input/folder/${SUB}"
oDIR="/my/output/folder/${SUB}"
tDIR="/path/to/MICCAI2012-Multi-Atlas-Challenge-Data"
mkdir -p ${oDIR}


# Skull Strip
echo "<---------- 01: Skull Strip ---------->"
antsBrainExtraction.sh \
-d 3 \
-a ${iDIR}/memprage.nii \
-e ${tDIR}/T_template0.nii.gz \
-m ${tDIR}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
-f ${tDIR}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
-o ${oDIR}/ss_${SUB}_ \
-k 0


# N4 Bias Field Correction
echo "<---------- 02: N4 Bias Field Correction ---------->"
fslmaths \
${oDIR}/ss_${SUB}_BrainExtractionMask.nii.gz \
-dilM -dilM \
${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz

fslcpgeom \
${iDIR}/memprage.nii \
${oDIR}/ss_${SUB}_BrainExtractionMask.nii.gz

fslcpgeom \
${iDIR}/memprage.nii \
${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz

# Note: adding a mask forces the N4 application within the mask
# We want to do the estimation within the mask, but the application
# on the whole image. So we use -w but not -x.
N4BiasFieldCorrection \
-d 3 \
-i ${iDIR}/memprage.nii \
-w ${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz \
-s 2 \
-c [125x100x75x50] \
-o [${oDIR}/N4_${SUB}.nii.gz,${oDIR}/BF_${SUB}.nii.gz] \
-v 1

# Unzip for SUIT (SPM does not work with .gz files)
gunzip ${oDIR}/N4_${SUB}.nii.gz

# Exit
exit

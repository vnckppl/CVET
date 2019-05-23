#!/bin/bash

# Build Template with ANTs

# Settings for antsMultivariateTemplateConstruction2.sh
I=2            # Iteration limit (default=4)
Q=10x10x10x5   # Iterations (default=100x100x70x20)
G=0.25         # Gradient step size (smaller=better+slower; default=0.25)
F=8x4x2x1      # Shrink factor (default=6x4x2x1)
S=4x2x1x0      # Smoothing factor (default=3x2x1x0)
J=3            # Number of CPUs

# Initialize FSL
source /etc/fsl/fsl.sh

# Environment
SUB="subject_string"
iDIR="/my/input/folder/${SUB}"  # Location where all the cropped cerebelli are

# Settings for antsMultivariateTemplateConstruction2.sh
I=$I   # Iteration limit (default=4)
Q=$Q   # Iterations (default=100x100x70x20)
G=$G   # Gradient step size (smaller=~better+slower; default=0.25)
F=$F   # Shrink factor (default=6x4x2x1)
S=$S   # Smoothing factor (default=3x2x1x0)
J=$J   # Number of CPUs

# Create output folder
oDIR="/my/output/folder/${SUB}" # Location where you will store the template output
mkdir -p ${oDIR}

# Goto output folder
cd ${oDIR}


# Build template
# Input files are all cropped cerebelli of one subject
antsMultivariateTemplateConstruction2.sh \
-d 3 \
-o T${SUB}_ \
-a 1 \
-c 2 \
-g ${G} \
-i ${I} \
-j ${J} \
-q ${Q} \
-f ${F} \
-s ${S} \
-n 0 \
-r 1 \
-m CC \
-t Rigid \
$(ls ${iDIR}/  <<<<All input files>>>>        *.nii.gz)


# Apply warps to the skull stripped images
for FILE in $(ls ${oDIR}/T${SUB}_ss_*_T1*GenericAffine.mat); do

    # Subject ID
    SES="subject-ID-string"

    # Announce
    echo "Apply warp to ${SES}"

    # Apply warp
    antsApplyTransforms \
    -d 3 \
    -i ${iDIR}/${SES}_T1.nii.gz \
    -r T${SUB}_template0.nii.gz \
    -o ${oDIR}/${SES}_2T.nii.gz \
    -t ${FILE} \
    --float \
    -v
done


# Average images
echo "Combine images into 4D file"
fslmerge \
-t \
${oDIR}/T${SUB}_Template_4D.nii.gz \
$(ls ${oDIR}/*_2T.nii.gz)

echo "Average images"
fslmaths \
${oDIR}/T${SUB}_Template_4D.nii.gz \
-Tmean \
${oDIR}/T${SUB}_Template.nii.gz

exit

#!/bin/bash

# This script performs N4 bias field correction within a brain mask.

# Environment
SID="${1}"
SES="${2}"
iDIR=/input/ses-${SES}/anat
oDIR=/output/sub-${SID}/ses-${SES}/01_SSN4
mkdir -p ${oDIR}
tDIR="/sofware/ANTS-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcelation Pipeline                        ###
### PART 1: T1 Skull Stripping and Bias Field Correction   ###
### Start date and time: `date`     ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# Test for multiple T1 images. If there is more than one T1
# image, average this image. Otherwise, copy the single image.
cat <<EOF
##############################################################
### Average multiple T1-weighted images (if present)       ###
##############################################################

EOF
# Count number of T1 weighted images
T1list=( $(ls ${iDIR}/sub-${SID}_ses-${SES}_run-?_T1w.nii.gz) )
echo "Number of T1-weighted images found: ${#T1list[@]}"
echo "${T1list[@]}" | tr " " "\n" | sed 's/^  *//g'

if [ ${#T1list[@]} -gt 1 ]; then

    # Average T1 weighted images
    echo "Averaging the ${#T1list[@]} T1-weighted images..."
    AnatomicalAverage \
        -v \
        -n \
        -o ${oDIR}/T1.nii.gz \
        ${T1list[@]}

elif [ ${#T1list[@]} -eq 1 ]; then

    # Copy over the single T1 image
    cp ${T1list[@]} ${oDIR}/T1.nii.gz

elif [ ${#T1list[@]} -eq 0 ]; then

    # No T1 scans found!
    echo "No T1-weighted images were found. Check your input folder."
    exit 1

else \
    # Something went wrong
    echo "Something went wrong. Please check your code and input arguments."
    exit 1

fi



# Skull stripping using ANTs Brain Extraction with the
# MICCAI2012-Multi-Atlas-Challenge-Data templates.
cat <<EOF


##############################################################
### Skull strip T1-weighted image using ANTs               ###
##############################################################

EOF

antsBrainExtraction.sh \
    -d 3 \
    -a ${oDIR}/T1.nii.gz \
    -e ${tDIR}/T_template0.nii.gz \
    -m ${tDIR}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -f ${tDIR}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
    -o ${oDIR}/ \
    -k 0



# Run N4 Bias Field Correction
cat <<EOF


##############################################################
### Run N4 Bias Field Correction                           ###
##############################################################

EOF

# Create a dilated brain mask to make sure we are not excluding
# any brain tissue, in case the brain mask created by ANTs in
# the previous step was a bit too tight.
fslmaths \
    ${oDIR}/BrainExtractionMask.nii.gz \
    -dilM -dilM \
    ${oDIR}/BrainExtractionMask_dilM2.nii.gz

# ITK is very sensitive with any deviations between
# sform / qform codes beteween images. Even decimal changes
# will result in problems with the bias field correction.
# We are therefore going to copy over the affine matrix
# from the original T1 to the brain masks to avoid this.
fslcpgeom \
    ${oDIR}/T1.nii.gz \
    ${oDIR}/BrainExtractionMask.nii.gz

fslcpgeom \
    ${oDIR}/T1.nii.gz \
    ${oDIR}/BrainExtractionMask_dilM2.nii.gz

# Note: adding a mask forces the N4 application within the mask
# We want to do the estimation within the mask, but the application
# to the entire image. So we use -w but not -x.
N4BiasFieldCorrection \
    -d 3 \
    -i ${oDIR}/T1.nii.gz \
    -w ${oDIR}/BrainExtractionMask_dilM2.nii.gz \
    -s 2 \
    -c [125x100x75x50] \
    -o [${oDIR}/N4_T1.nii.gz,${oDIR}/BF_T1.nii.gz] \
    -v 1

# Exit
exit

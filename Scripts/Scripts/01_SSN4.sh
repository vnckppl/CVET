#!/bin/bash

# This script performs N4 bias field correction within a brain mask.

# Input arguments
while getopts "s:t:a:i:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         t)
             SES=$OPTARG
             ;;
         a)
             AVERAGE=$OPTARG
             ;;
         i)
             INTERMEDIATE=$OPTARG
             ;;
         r)
             REPORT=$OPTARG
             ;;
         ?)
             exit
             ;;
     esac
done



# Environment
iDIR=/input/ses-${SES}/anat
oDIR=/output/01_SSN4/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}
tDIR="/software/ANTS-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 1: T1 Skull Stripping and Bias Field Correction   ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# Test for multiple T1 images. If there is more than one T1
# image, average this image. Otherwise, copy the single image.
cat <<EOF
##############################################################
### Average multiple T1-weighted images (if chosen)        ###
##############################################################

EOF
# Count number of T1 weighted images
T1list=( $(ls ${iDIR}/sub-${SID}_ses-${SES}_run-?_T1w.nii.gz | sort) )
echo "Number of T1-weighted images found: ${#T1list[@]}"
echo "${T1list[@]}" | tr " " "\n" | sed 's/^  *//g'

# When the list is empty (no T1 scans found):
if [ ${#T1list[@]} -eq 0 ]; then
    echo "No T1-weighted images were found. Check your input folder."
    exit 1
fi

# If selected to average images
if [ ${AVERAGE} -eq 1 ]; then

    # Check if there are is more than one image
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
        echo "Only a single T1-weighted image was found. Proceed the pipeline with this image..."
        cp ${T1list[@]} ${oDIR}/T1.nii.gz

    fi

elif [ ${AVERAGE} -eq 0 ]; then
    echo "No averaging selected. We will be using the first image that was collected for this session, ignoring any other T1 images that may have been collected during this session."
    cp ${T1list[0]} ${oDIR}/T1.nii.gz
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

# Create image for quality control of bias field correction.
# For this, we will z-transform both the T1 and the N4_T1 image.
mean_T1=$(fslstats ${oDIR}/T1.nii.gz -m)
sd_T1=$(fslstats ${oDIR}/T1.nii.gz -s)
fslmaths ${oDIR}/T1.nii.gz -sub ${mean_T1} ${oDIR}/T1-mean.nii.gz
fslmaths ${oDIR}/T1-mean.nii.gz -div ${sd_T1} ${oDIR}/zT1.nii.gz

mean_N4T1=$(fslstats ${oDIR}/N4_T1.nii.gz -m)
sd_N4T1=$(fslstats ${oDIR}/N4_T1.nii.gz -s)
fslmaths ${oDIR}/N4_T1.nii.gz -sub ${mean_N4T1} ${oDIR}/N4_T1-mean.nii.gz
fslmaths ${oDIR}/N4_T1-mean.nii.gz -div ${sd_N4T1} ${oDIR}/zN4_T1.nii.gz

fslmaths ${oDIR}/zT1.nii.gz -sub ${oDIR}/zN4_T1.nii.gz ${oDIR}/N4_effect.nii.gz

rm -f ${oDIR}/T1-mean.nii.gz
rm -f ${oDIR}/zT1.nii.gz
rm -f ${oDIR}/N4_T1-mean.nii.gz
rm -f ${oDIR}/zN4_T1.nii.gz



# Clean up if flag to keep intermediate files is not set
if [ ${INTERMEDIATE} -eq 0 ]; then
    rm -f ${oDIR}/BF_T1.nii.gz
    rm -f ${oDIR}/BrainExtractionBrain.nii.gz
    rm -f ${oDIR}/BrainExtractionMask.nii.gz
    rm -f ${oDIR}/BrainExtractionMask_dilM2.nii.gz
    rm -f ${oDIR}/BrainExtractionPrior0GenericAffine.mat
    rm -f ${oDIR}/T1.nii.gz
fi

# Exit
exit

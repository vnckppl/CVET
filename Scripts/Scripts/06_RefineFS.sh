#!/bin/bash

# This script refines the SUIT cerebellar atlas labels  in native space
# using a cerebellum mask created by combining the FreeSurfer cerebellum labels.

# Input arguments
while getopts "s:t:i:f:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         t)
             SES=$OPTARG
             ;;
         i)
             INTERMEDIATE=$OPTARG
             ;;
         f)
             FREESURFER=$OPTARG
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
iDIR1=/output/01_SSN4/sub-${SID}/ses-${SES}
iDIR2=/output/02_CerIso/sub-${SID}/ses-${SES}
iDIR3=/output/03_Template/sub-${SID}
iDIR31=${iDIR3}/01_SubjectTemplate
iDIR32=${iDIR3}/02_SUITTemplate
iDIR4=/output/04_Segment/sub-${SID}/ses-${SES}
oDIR=/output/06_RefineFS/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}
tDIR="/software/SUIT-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 6: Refinement of ROI volumes with FreeSurfer's C. ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# Create a cerebellar mask from FreeSurfer's labels.
cat <<EOF
##############################################################
### Create a cerebellar mask from the 4 FreeSurfer         ###
### cerebellar labels (L+R * GM+WM labels)                 ###
##############################################################

EOF

if [ ${FREESURFER} -eq 1 ]; then echo "This option has not been implemented yet. Exit"; exit 1; fi
if [ ${FREESURFER} -eq 2 ]; then

    # Figure out which FS folder to use. Search for subject and
    # session; then for a longitudinal folder. If that is not
    # present, then look for a cross-sectional folder.
    FSDIR=$(ls /freesurfer/ | grep ${SUB} | grep ${SES} | grep long)
    if [ ! -d ${FSDIR} ]; then
        FSDIR=$(ls /freesurfer/ | grep ${SUB} | grep ${SES})
    fi
    if [ ! -f ${FSDIR} ]; then
        echo "No FreeSurfer folder for Subject ${SUB}, Session ${SES} found. Exit."
        exit 1
    fi

fi

# Convert files from FreeSurfer's mgh to Nifti format
mri_convert \
    ${FSDIR}/mri/aseg.mgz \
    ${oDIR}/aseg.nii.gz

mri_convert \
    ${FSDIR}/mri/brainmask.mgz \
    ${oDIR}/brainmask.nii.gz

mri_convert \
    ${FSDIR}/mri/T1.mgz \
    ${oDIR}/T1.nii.gz

# Rigid registration of FreeSurfer's skull stripped T1
# to the skull stripped T1 that we created in the first
# step of this pipeline using ANTs.
flirt \
    -dof 6 \
    -in ${oDIR}/brainmask.nii.gz \
    -ref ${iDIR1}/BrainExtractionBrain.nii.gz \
    -out ${oDIR}/FS_to_NativeSpace.nii.gz \
    -omat ${oDIR}/FS_to_NativeSpace.mat \
    -v 

# Apply this rigid transformation to FreeSurfer's
# labels (including the infratentorial labels)
flirt \
    -in ${oDIR}/aseg.nii.gz \
    -ref ${iDIR1}/BrainExtractionBrain.nii.gz \ \
    -applyxfm -init ${oDIR}/FS_to_NativeSpace.mat \
    -out ${oDIR}/aseg_NS.nii.gz \
    -interp nearestneighbour

# Create cerebellum mask from FreeSurfer labels
ROIn=(7 8 46 47)                              # Lables numbers
ROIl=("LcWM" "LcGM" "RcWM" "RcGM")            # Labels
ROIi=( $(seq -w 0 $(( ${#ROIn[@]} - 1 )) ) )  # Index list
for R in ${ROIi[@]}; do

    fslmaths \
        ${oDIR}/aseg_NS.nii.gz \
        -thr ${ROIn[${R}]} \
        -uthr ${ROIn[${R}]} \
        ${DIR}/${ROIl[${R}]}.nii.gz

done

fslmaths \
    ${DIR}/LcWM.nii.gz \
    -add ${DIR}/LcGM.nii.gz \
    -add ${DIR}/RcWM.nii.gz \
    -add ${DIR}/RcGM.nii.gz \
    -bin \
    ${DIR}/cerebellumMask.nii.gz

# Reslice
mri_convert \
    ${DIR}/cerebellumMask.nii.gz \
    -rl ${DIR}/atlasNativeSpace.nii.gz \
    ${DIR}/ccerebellumMask.nii.gz \

# Apply mask
fslmaths \
    ${DIR}/atlasNativeSpace.nii.gz \
    -mas ${DIR}/ccerebellumMask.nii.gz \
    ${DIR}/atlasNativeSpace_FSmasked.nii.gz




# Extract ROI volumes using the refined mask
cat <<EOF


##############################################################
### Extract cerebellar volumes for each of the 28 lobules  ###
### using the refined masks.                               ###
##############################################################

EOF

# Extract volume per lobule for all regions
echo "Extract volume per lobule for all regions"
listOfLobules=$(fslstats \
	            -K ${oDIR}/atlasNativeSpace_FSmasked.nii.gz \
	            ${oDIR}/atlasNativeSpace_FSmasked.nii.gz \
	            -M )

listMeanVal=$(fslstats \
	          -K ${oDIR}/atlasNativeSpace_FSmasked.nii.gz \
	          ${oDIR}/cgm.nii.gz \
	          -m | sed 's/  */,/g' | sed 's/.,$//g' )

listNumVox=$(fslstats \
	         -K ${oDIR}/atlasNativeSpace_FSmasked.nii.gz \
	         ${oDIR}/atlasNativeSpace_FSmasked.nii.gz \
	         -v | awk '{ for (i=1;i<=NF;i+=2) print $i }' \
	         | tr "\n" "," | sed 's/,$//g')

# Write this info out to a file
oFile=${oDIR}/sub-${SID}_ses-${SES}_cGM_FSmasked.csv
# Header
# mean Gray Matter per voxel
H1=$(for i in $(echo "${listOfLobules}" | sed 's/\.000000//g'); do
	 if [ ${i} -lt 10 ]; then
	     echo -n mGM_0${i},
	 else echo -n mGM_${i},
	 fi
     done | sed 's/,$//g')
# number of voxels
H2=$(for i in $(echo "${listOfLobules}" | sed 's/\.000000//g'); do
	 if [ ${i} -lt 10 ]; then
	     echo -n vGM_0${i},
	 else echo -n vGM_${i},
	 fi
     done | sed 's/,$//g')

# ICV
eTIV=$(cat ${FSDIR}/stats/aseg.stats | grep EstimatedTotalIntraCranialVol | awk '{ print $(NF-1) }')

# Write out Header and Data
echo SUB,SES,${H1},${H2},eTIV | sed 's/  *//g' > ${oFile}
echo ${SID},${SES},${listMeanVal},${listNumVox},${eTIV} | sed 's/  *//g' >> ${oFile}


exit

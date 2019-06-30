#!/bin/bash

# Input arguments
while getopts "s:t:i:r:" OPTION
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
oDIR=/output/05_ApplyWarp/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}
tDIR="/software/SUIT-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 5: Apply Warps and Obtain Cerebellar Volumes      ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# Apply warps to bring the SUIT atlas into subject
# native space. 
cat <<EOF
##############################################################
### Apply the inverse of the warp parameters to bring the  ###
### SUIT atlas into 'single subject, single time point'    ###
### space by stacking up the warps from single subject     ###
### + time point to subject template space, and from       ###
### subject template space to SUIT space.                  ###
##############################################################

EOF

# Warp atlas back to native space
twarp=$(ls ${iDIR31}/T_mc_roN4_T1_*0GenericAffine.mat | grep ${SES})

antsApplyTransforms \
    -d 3 \
    -i ${tDIR}/Cerebellum-SUIT.nii.gz \
    -r ${iDIR2}/c_roN4_T1.nii.gz \
    -o ${oDIR}/atlasNativeSpace.nii.gz \
    -t [${twarp},1] \
    -t [${iDIR32}/ants_0GenericAffine.mat,1] \
    -t ${iDIR32}/ants_1InverseWarp.nii.gz \
    -n NearestNeighbor \
    --float \
    -v

#  Calculate SPM12's ICV
fslmaths \
    ${iDIR4}/c1roN4_T1.nii.gz \
    -add \
    ${iDIR4}/c2roN4_T1.nii.gz \
    -add \
    ${iDIR4}/c3roN4_T1.nii.gz \
    -thr 0.5 \
    -bin \
    ${oDIR}/SPMbrainMask.nii.gz

ICVm=$(fslstats ${oDIR}/SPMbrainMask.nii.gz -m)
ICVv=$(fslstats ${oDIR}/SPMbrainMask.nii.gz -v | awk '{ print $NF }')


# Extract volume per lobule for all regions
echo "Extract volume per lobule for all regions"
listOfLobules=$(fslstats \
	            -K ${oDIR}/atlasNativeSpace.nii.gz \
	            ${oDIR}/atlasNativeSpace.nii.gz \
	            -M )

listMeanVal=$(fslstats \
	          -K ${oDIR}/atlasNativeSpace.nii.gz \
	          ${oDIR}/cgm.nii.gz \
	          -m | sed 's/  */,/g' | sed 's/.,$//g' )

listNumVox=$(fslstats \
	         -K ${oDIR}/atlasNativeSpace.nii.gz \
	         ${oDIR}/atlasNativeSpace.nii.gz \
	         -v | awk '{ for (i=1;i<=NF;i+=2) print $i }' \
	         | tr "\n" "," | sed 's/,$//g')

# Write this info out to a file
oFile=${oDIR}/sub-${SID}_ses-${SES}_cGM.csv
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

# Write out Header and Data
echo SUB,SES,${H1},${H2},mICVSPM,vICVSPM | sed 's/  *//g' > ${oFile}
echo ${SID},${SES},${listMeanVal},${listNumVox},${ICVm},${ICVv} | sed 's/  *//g' >> ${oFile}



# Create modulated warped smoothed cerebellar images for a
# VBM style analysis
cat <<EOF


##############################################################
### Create modulated warped smoothed cerebellar gray       ###
### matter maps that are ready for a VBM style analysis.   ###
### The modulation is only applied from the non-linear     ###
### transformation. Therefore, there this images is        ###
### taking into account brain scaling and you should not   ###
### additionally adjust for ICV in the voxel wise analysis.###
##############################################################

EOF

# Reslice GM map to cropped cerebellum space
mri_convert \
    ${iDIR4}/c1roN4_T1.nii.gz \
    -rl ${iDIR2}/c_roN4_T1.nii.gz \
    ${oDIR}/cgm.nii.gz

# Apply warp: Cerebbellar GM map to SUIT space (forward warp)
itwarp=$(ls ${iDIR31}/T_mc_roN4_T1_*0GenericAffine.mat | grep ${SES})

antsApplyTransforms \
    -d 3 \
    -i ${oDIR}/cgm.nii.gz \
    -r ${tDIR}/Cerebellum-SUIT.nii.gz \
    -o ${oDIR}/wcgm.nii.gz \
    -t ${iDIR32}/ants_1Warp.nii.gz \
    -t ${iDIR32}/ants_0GenericAffine.mat \
    -t ${itwarp} \
    --float \
    -v

# Calculate the Jacobian
CreateJacobianDeterminantImage \
    3 \
    ${iDIR32}/ants_1Warp.nii.gz \
    ${oDIR}/Jacobian.nii.gz

# Multiply the Jacobian determinant with the warped GM map
fslmaths \
    ${oDIR}/wcgm.nii.gz \
    -mul ${oDIR}/Jacobian.nii.gz \
    ${oDIR}/mwcgm.nii.gz

# 4mm FWHM smoothing for cerebellum: https://www.haririlab.com/methods/vbm.html
# Mask (cerebellum) en Smooth de GM map; FWMH ~= sigma * 2.35; 4mm FWHM = sigma(4/2.35); sigma= 1.70
fslmaths \
    ${oDIR}/mwcgm.nii.gz \
    -mas ${tDIR}/maskSUIT.nii.gz \
    -s 1.70 \
    ${oDIR}/s8mwcgm.nii.gz

exit



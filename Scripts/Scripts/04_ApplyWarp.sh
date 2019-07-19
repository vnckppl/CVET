#!/bin/bash

# Input arguments
while getopts "s:t:n:f:i:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         t)
             SES=$OPTARG
             ;;
         n)
             SESN=$OPTARG
             ;;
         f)
             FSDATA=$OPTARG
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



# Logging
cat <<EOF
##############################################################
### Cerebellar Volume Extraction Tool (CVET)               ###
### PART 4: Apply Warps and Obtain Cerebellar Volumes      ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF

# Environment
iDIR2=/data/out/02_Template/sub-${SID}
iDIR21=${iDIR2}/01_CerebellumMask/ses-${SES}
iDIR22=${iDIR2}/02_SubjectTemplate
iDIR23=${iDIR2}/03_SUITTemplate
iDIR3=/data/out/03_Segment/sub-${SID}/ses-${SES}
oDIR=/data/out/04_ApplyWarp/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}
tDIR="/software/SUIT-templates"

# Set FreeSurfer data location
if [ ${FSDATA} -eq 0 ]; then
    FSDATADIR=/freesurfer
elif [ ${FSDATA} -eq 1 ]; then
    FSDATADIR=/data/out/01_FreeSurfer
fi



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

# Figure out which FS folder to use. Search for subject and
# session; then for a longitudinal folder. If that is not
# present, then look for a cross-sectional folder.
if [ ${SESN} -gt 1 ]; then
    FSSUBDIR=$(ls ${FSDATADIR} | grep ${SID} | grep ${SES} | grep long)
    FSDIR="${FSDATADIR}/${FSSUBDIR}"
    if [ ! -d ${FSDATADIR} ]; then
        FSSUBDIR=$(ls ${FSDATADIR} | grep ${SID} | grep ${SES})
        FSDIR="${FSDATADIR}/${FSSUBDIR}"
    fi
elif [ ${SESN} -eq 1 ]; then
    FSSUBDIR=$(ls ${FSDATADIR} | grep ${SID} | grep ${SES} | grep -v long)
    FSDIR="${FSDATADIR}/${FSSUBDIR}"               
fi                  
if [ ! -d ${FSDIR} ]; then
    echo "No FreeSurfer folder for Subject ${SID}, Session ${SES} found. Exit."
    exit 1
fi

# Warp atlas back to native space (rawavg) where the GM map resides
# If this is cross-sectional data, there is only one set of warps:
# rawavg cerebellum (cropped) to SUIT space.
# If there is more than one session, there are three sets of warps
# for each session:
# 1) rawavg cross-sectional -> rawavg longitudinal
# 2) rawavg longitudinal (cropped) -> ANTs subject template
# 3) ANTs subject template -> SUIT space

# Test if this is cross-sectional or longitudinal data by counting
# how many masked cropped cerebellar images there have been created
# for the current subject
CLIST=( $(find ${iDIR21}/.. -iname "sub-${SID}_ses-*_ccereb.nii.gz" | sort) )

# If this is longitudinal data, we have to convert the registration
# from rawavg cross-sectional -> rawavg longitudinal, which is in FreeSurfer
# lta format to ANTs ITK format, so we can stack them up with other ANTs
# transformations later.
if [ ${#CLIST[@]} -gt 1 ]; then

    # Convert transformation
    FS_transform=${FSDIR}/mri/transforms/sub-${SID}_ses-${SES}_to_sub-${SID}_ses-${SES}.long.sub-${SID}.lta
    ANTs_transform=${oDIR}/sub-${SID}_ses-${SES}_to_sub-${SID}_ses-${SES}.long.sub-${SID}.txt
    lta_convert \
        --inlta ${FS_transform} \
        --outitk ${ANTs_transform}

    # Now add this transformation and the transformation from FreeSurfer
    # Subject Template (long) to ANTs Subject template
    transform_FS_CS2Long=$(echo "-t [${ANTs_transform},1]")
    transform_FS_Long_2_ANTs_template=$(
        echo "-t [$(ls ${iDIR22}/T_sub-${SID}_ses-${SES}_ccereb*GenericAffine.mat | grep ${SES}),1]")
    
fi



# Apply the transformations to bring the cerebellar atlas into native (rawavg) space
antsApplyTransforms \
    -d 3 \
    -i ${tDIR}/Cerebellum-SUIT.nii.gz \
    -r ${iDIR3}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -o ${oDIR}/atlasNativeSpace.nii.gz \
    ${transform_FS_CS2Long} \
    ${transform_FS_Long_2_ANTs_template} \
    -t [${iDIR23}/ants_0GenericAffine.mat,1] \
    -t ${iDIR23}/ants_1InverseWarp.nii.gz \
    -n NearestNeighbor \
    --float \
    -v

#  Calculate SPM12's ICV
fslmaths \
    ${iDIR3}/c1sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
    -add \
    ${iDIR3}/c2sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
    -add \
    ${iDIR3}/c3sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
    -thr 0.5 \
    -bin \
    ${oDIR}/SPMbrainMask.nii.gz

ICVm=$(fslstats ${oDIR}/SPMbrainMask.nii.gz -m)
ICVv=$(fslstats ${oDIR}/SPMbrainMask.nii.gz -v | awk '{ print $NF }')

# Crop the GM mask with the cerebellum mask to make
# sure the GM tissue of within the SUIT atlas space
# is not outside the cerebellum. For this, we want
# to have the cerebellum mask from the longitudinal
# pipeline if that is available.
if [ ${#CLIST[@]} -gt 1 ]; then

    # Transform the cerebellum mask from
    # long space to native space
    antsApplyTransforms \
    -d 3 \
    -i ${iDIR21}/cerebellumMask.nii.gz \
    -r ${iDIR3}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -o ${oDIR}/cMask_long_in_rawavg.nii.gz \
    ${transform_FS_CS2Long} \
    -n NearestNeighbor \
    --float \
    -v

    cerebMask=${oDIR}/cMask_long_in_rawavg.nii.gz

elif  [ ${#CLIST[@]} -eq 1 ]; then

    # If there is only one time point, we have to convert
    # this freesurfer native space image back to true
    # native space. We already created this registration
    # matrix.
    antsApplyTransforms \
    -d 3 \
    -i ${iDIR21}/cerebellumMask.nii.gz \
    -r ${iDIR3}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -o ${oDIR}/cMask_in_rawavg.nii.gz \
    -t [${iDIR3}/register.native.txt,1] \
    -n NearestNeighbor \
    --float \
    -v

    cerebMask=${oDIR}/cMask_in_rawavg.nii.gz

fi

fslmaths \
    ${iDIR3}/c1sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
    -mas ${cerebMask} \
    ${oDIR}/cgm.nii.gz


# Refine atlas by masking with FreeSufer cerebellar mask
fslmaths \
    ${oDIR}/atlasNativeSpace.nii.gz \
    -mas ${cerebMask} \
    ${oDIR}/c_atlasNativeSpace.nii.gz



# Extract volume per lobule for all regions
echo "Extract volume per lobule for all regions"
listOfLobules=$(fslstats \
	            -K ${oDIR}/c_atlasNativeSpace.nii.gz \
	            ${oDIR}/c_atlasNativeSpace.nii.gz \
	            -M )

listMeanVal=$(fslstats \
	          -K ${oDIR}/c_atlasNativeSpace.nii.gz \
	          ${oDIR}/cgm.nii.gz \
	          -m | sed 's/  */,/g' | sed 's/.,$//g' )

listNumVox=$(fslstats \
	         -K ${oDIR}/c_atlasNativeSpace.nii.gz \
	         ${oDIR}/c_atlasNativeSpace.nii.gz \
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

# Get FreeSurfer's estimated total ICV
eTIV=$(cat ${FSDIR}/stats/aseg.stats | grep EstimatedTotalIntraCranialVol | awk '{ print $(NF-1) }')

# Write out Header and Data
echo SUB,SES,${H1},${H2},mICVSPM,vICVSPM,eTIV | sed 's/  *//g' > ${oFile}
echo ${SID},${SES},${listMeanVal},${listNumVox},${ICVm},${ICVv},${eTIV} | sed 's/  *//g' >> ${oFile}



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

# Apply warp: Cerebellar GM map to SUIT space (forward warp)
# If there is more than one session, there are 2 additional transformations
# (see above)
if [ ${#CLIST[@]} -gt 1 ]; then

    # Now add this transformation and the transformation from FreeSurfer
    # Subject Template (long) to ANTs Subject template
    transform_FS_CS2Long=$(echo "-t ${ANTs_transform}")
    transform_FS_Long_2_ANTs_template=$(
        echo "-t $(ls ${iDIR22}/T_sub-${SID}_ses-${SES}_ccereb*GenericAffine.mat | grep ${SES})")

fi

antsApplyTransforms \
    -d 3 \
    -i ${oDIR}/cgm.nii.gz \
    -r ${tDIR}/Cerebellum-SUIT.nii.gz \
    -o ${oDIR}/wcgm.nii.gz \
    -t ${iDIR23}/ants_1Warp.nii.gz \
    -t ${iDIR23}/ants_0GenericAffine.mat \
    ${transform_FS_Long_2_ANTs_template} \
    ${transform_FS_CS2Long} \
    --float \
    -v

# Calculate the Jacobian
CreateJacobianDeterminantImage \
    3 \
    ${iDIR23}/ants_1Warp.nii.gz \
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



# Clean up intermediate files
if [ ${INTERMEDIATE} -eq 0 ]; then

    # Announce
    echo "REMOVING INTERMEDIATE FILES..."

    rm -vf \
       ${oDIR}/Jacobian.nii.gz \
       ${oDIR}/atlasNativeSpace.nii.gz \
       ${oDIR}/mwcgm.nii.gz \
       ${oDIR}/wcgm.nii.gz

    trans=${oDIR}/sub-${SUB}_ses-${SES}_to_sub-${SUB}_ses-${SES}.long.sub-${SUB}.txt
    if [ -f ${trans} ]; then rm -vf ${trans}; fi
    
fi

exit



#!/bin/bash

# This script creates a subject specific cerebellar template and
# calcualtes the warp from this template to SUIT space.

# Environment
SID="${1}"
SESN="${2}"
KI=0; if [ ${3} = "KI" ]; then KI=1; fi
iDIR=/output/02_CerIso/sub-${SID}
oDIR=/output/03_Template/sub-${SID}
oDIRt=/output/03_Template/sub-${SID}/01_SubjectTemplate
oDIRs=/output/03_Template/sub-${SID}/02_SUITTemplate
mkdir -p ${oDIRt} ${oDIRs}
tDIR="/sofware/ANTS-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 3: Subject Template Creation and Warping to SUIT  ###
### Start date and time: `date`     ###
### Subject: ${SID}                                     ###
### Number of sessions included in the template: ${SESN}         ###
##############################################################

EOF



# Build subject specific cerebellar template with ANTs.
# Only do this if there is more than a single time point.
cat <<EOF
##############################################################
### Build subject specific cerebellar template, if there   ###
### is more than a single time point.                      ###
##############################################################

EOF

# Check for which time points cropped cerebelli are availble
CLIST=( $(find ${iDIR} -iname "mc_roN4_T1_?.nii.gz" ) )

# If there are more than two time points, create a template.
if [ ${#CLIST} -gt 1 ]; then

    # Settings for antsMultivariateTemplateConstruction2.sh
    I=2            # Iteration limit (default=4)
    Q=10x10x10x5   # Iterations (default=100x100x70x20)
    G=0.25         # Gradient step size (smaller=better+slower; default=0.25)
    F=8x4x2x1      # Shrink factor (default=6x4x2x1)
    S=4x2x1x0      # Smoothing factor (default=3x2x1x0)
    J=1            # Number of CPUs

    # Goto output folder
    cd ${oDIRt}

    # Build template
    # Input files are all cropped cerebelli of one subject
    antsMultivariateTemplateConstruction2.sh \
        -d 3 \
        -o T_ \
        -a 1 \
        -c 2 \
        -i ${I} \
        -q ${Q} \
        -g ${G} \
        -f ${F} \
        -s ${S} \
        -j ${J} \
        -n 0 \
        -r 1 \
        -m CC \
        -t Rigid \
        ${CLIST[@]}

fi



# Warp subject specific cerebellar template to SUIT space
cat <<EOF
##############################################################
### Warp subject specific cerebellar template to SUIT      ###
### space if there is more than one session. If there is   ###
### is only one session, warp the single time point to     ###
### SUIT space.                                            ###
##############################################################

EOF

# Goto output folder
cd ${oDIRs}

# Define SUIT Template and Subject Template
SUIT_Template=/software/SUIT-templates/SUIT.nii.gz
Subject_Template=${oDIRt}/T_template0.nii.gz
if [ ${#CLIST} -eq 1 ]; then
    Subject_Template=${CLIST}
fi

# Calculate warp
antsRegistration  \
   -d 3  \
   -r [       "${SUIT_Template}" , "${Subject_Template}" ,1]  \
   -m mattes[ "${SUIT_Template}" , "${Subject_Template}" , 1 , 32, regular, 0.3 ]  \
      -t translation[ 0.1 ]  \
      -c [10000x111110x11110,1.e-8,20]  \
      -s 4x2x1vox  \
      -f 6x4x2 -l 1  \
   -m mattes[ "${SUIT_Template}" , "${Subject_Template}" , 1 , 32, regular, 0.3 ]  \
      -t rigid[ 0.1 ]  \
      -c [10000x111110x11110,1.e-8,20]  \
      -s 4x2x1vox  \
      -f 3x2x1 -l 1  \
   -m mattes[ "${SUIT_Template}" , "${Subject_Template}" , 1 , 32, regular, 0.3 ]  \
      -t affine[ 0.1 ]  \
      -c [10000x111110x11110,1.e-8,20]  \
      -s 4x2x1vox  \
      -f 3x2x1 -l 1  \
   -m mattes[ "${SUIT_Template}" , "${Subject_Template}" , 0.5 , 32 ]  \
   -m cc[     "${SUIT_Template}" , "${Subject_Template}" , 0.5 , 4 ]  \
      -t SyN[ .20, 3, 0 ]  \
      -c [ 100x100x50,-0.01,5 ]  \
      -s 1x0.5x0vox  \
      -f 4x2x1 -l 1 -u 1 -z 1  \
   -o [ants_,ants_warped.nii.gz,ants_inv.nii.gz]  \
   -v 1
   


# # Apply warp from single subject + single time point space
# # to SUIT space via subject specific template space by
# # stacking up the warp parameters.
# cat <<EOF
# ##############################################################
# ### Apply the inverse of the warp parameters to bring the  ###
# ### SUIT atlas into 'single subject, single time point'    ###
# ### space by stacking up the warps from single subject     ###
# ### + time point to subject template space, and from       ###
# ### subject template space to SUIT space.                  ###
# ##############################################################

# EOF

# # ANTs normalization: Apply Warp (Subject Template to SUIT Template)
# echo "--> ANTs apply warp to bring the Subject Template into SUIT space"
# antsApplyTransforms \
# -d 3 \
# -e 3 \
# -i <<< Subject Cerebellum Template .nii.gz >>> \
# -r ${tmpl1mm} \
# -n linear \
# -t ${oDIR}/ants_1Warp.nii.gz \
# -t ${oDIR}/ants_0GenericAffine.mat \
# -o <<< Output File .nii.gz >>>  \
# -v 1





# Apply warps to the skull stripped images
# for FILE in $(ls ${oDIR}/T${SUB}_ss_*_T1*GenericAffine.mat); do

#     # Subject ID
#     SES="subject-ID-string"

#     # Announce
#     echo "Apply warp to ${SES}"

#     # Apply warp
#     antsApplyTransforms \
#     -d 3 \
#     -i ${iDIR}/${SES}_T1.nii.gz \
#     -r T${SUB}_template0.nii.gz \
#     -o ${oDIR}/${SES}_2T.nii.gz \
#     -t ${FILE} \
#     --float \
#     -v
# done


# Average images
# echo "Combine images into 4D file"
# fslmerge \
# -t \
# ${oDIR}/T${SUB}_Template_4D.nii.gz \
# $(ls ${oDIR}/*_2T.nii.gz)

# echo "Average images"
# fslmaths \
# ${oDIR}/T${SUB}_Template_4D.nii.gz \
# -Tmean \
# ${oDIR}/T${SUB}_Template.nii.gz

exit

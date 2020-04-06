#!/bin/bash

# * Make Cerebellum Template
# This script creates a subject specific cerebellar template and
# calcualtes the warp from this template to SUIT space.

# * Input arguments
while getopts "s:n:f:c:i:l:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         n)
             SESN=$OPTARG
             ;;
         f)
             FSDATA=$OPTARG
             ;;
         c)
             CPUS=$OPTARG
             ;;
         i)
             INTERMEDIATE=$OPTARG
             ;;
         l)
             LOCALCOPY=${OPTARG}
             ;;
         r)
             REPORT=$OPTARG
             ;;
         ?)
             exit
             ;;
     esac
done



# * Logging
cat <<EOF
##############################################################
### CVET - Cerebellar Volume Extration Tool                ###
### PART 2: Subject Template Creation and Warping to SUIT  ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Number of sessions included in the template: ${SESN}         ###
##############################################################

EOF

# * Environment
oDIR=/data/out/02_Template/sub-${SID}
oDIRt=${oDIR}/02_SubjectTemplate
oDIRs=${oDIR}/03_SUITTemplate
mkdir -p ${oDIRt} ${oDIRs}
tDIR="/sofware/ANTS-templates"

# * Set FreeSurfer data location
if [ ${FSDATA} -eq 0 ]; then
    if [ ${LOCALCOPY=1} ]; then
        FSDATADIR=/data/tmp/01_FreeSurfer
    elif [ ${LOCALCOPY=0} ]; then
        FSDATADIR=/freesurfer
    fi
elif [ ${FSDATA} -eq 1 ]; then
     FSDATADIR=/data/out/01_FreeSurfer
fi



# * Create a cerebellar mask from FreeSurfer's labels.
cat <<EOF
##############################################################
### Create a cerebellar mask from the 4 FreeSurfer         ###
### cerebellar labels (L+R * GM+WM labels)                 ###
##############################################################

EOF

# * Extract session list
SESLIST=(
    $(ls ${FSDATADIR} \
          | grep sub-${SID}_ses- \
          | grep -v long \
          | sed "s/sub-${SID}_ses-//g"
    )
)

# * Loop over sessions
for SES in ${SESLIST[@]}; do

    # ** Set output folder
    oDIRm=${oDIR}/01_CerebellumMask/ses-${SES}
    mkdir -p ${oDIRm}

    # ** Select FreeSurfer data
    # Figure out which FS folder to use. Search for subject and
    # session; then for a longitudinal folder. If that is not
    # present, then look for a cross-sectional folder.
    if [ ${SESN} -gt 1 ]; then
        FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES} | grep long)
        FSDIR="${FSDATADIR}/${FSSUBDIR}"
        if [ ! -d ${FSDATADIR} ]; then
            FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES})
            FSDIR="${FSDATADIR}/${FSSUBDIR}"
        fi
    elif [ ${SESN} -eq 1 ]; then
        FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES} | grep -v long)
        FSDIR="${FSDATADIR}/${FSSUBDIR}"               
    fi
    if [ -z ${FSDIR} ]; then
        echo "No FreeSurfer folder for Subject ${SID}, Session ${SES} found. Exit."
        exit 1
    fi

    # ** Convert files from FreeSurfer's mgh to Nifti format
    mri_convert \
        ${FSDIR}/mri/aseg.mgz \
        ${oDIRm}/aseg.nii.gz

    mri_convert \
        ${FSDIR}/mri/T1.mgz \
        ${oDIRm}/T1.nii.gz

    # ** Create cerebellum + brain stem  mask from FreeSurfer labels
    ROIn=(7 8 46 47 16)                              # Lables numbers
    ROIl=("LcWM" "LcGM" "RcWM" "RcGM" "BrainStem")   # Labels
    ROIi=( $(seq -w 0 $(( ${#ROIn[@]} - 1 )) ) )     # Index list
    for R in ${ROIi[@]}; do

        fslmaths \
            ${oDIRm}/aseg.nii.gz \
            -thr ${ROIn[${R}]} \
            -uthr ${ROIn[${R}]} \
            ${oDIRm}/${ROIl[${R}]}.nii.gz

    done

    # ** Mask with Brain Stem (for normalization)
    fslmaths \
        ${oDIRm}/LcWM.nii.gz \
        -add ${oDIRm}/LcGM.nii.gz \
        -add ${oDIRm}/RcWM.nii.gz \
        -add ${oDIRm}/RcGM.nii.gz \
        -add ${oDIRm}/BrainStem.nii.gz \
        -bin \
        ${oDIRm}/cerebellumMask.nii.gz

    # ** Mask without Brain Stem (for volume extraction)
    fslmaths \
        ${oDIRm}/LcWM.nii.gz \
        -add ${oDIRm}/LcGM.nii.gz \
        -add ${oDIRm}/RcWM.nii.gz \
        -add ${oDIRm}/RcGM.nii.gz \
        -bin \
        ${oDIRm}/cerebellumMask_noBS.nii.gz
    
    # ** Apply mask
    fslmaths \
        ${oDIRm}/T1.nii.gz \
        -mas ${oDIRm}/cerebellumMask.nii.gz \
        ${oDIRm}/sub-${SID}_ses-${SES}_cereb.nii.gz

    # ** Crop
    fslroi \
        ${oDIRm}/sub-${SID}_ses-${SES}_cereb.nii.gz \
        ${oDIRm}/sub-${SID}_ses-${SES}_ccereb.nii.gz \
        $(fslstats ${oDIRm}/sub-${SID}_ses-${SES}_cereb.nii.gz -w)
    
done



# * Build Template
# Build subject specific cerebellar template with ANTs.
# Only do this if there is more than a single time point.
cat <<EOF


##############################################################
### Build subject specific cerebellar template, if there   ###
### is more than a single time point.                      ###
##############################################################

EOF

# * Check for which time points cerebelli are available
CLIST=( $(find ${oDIR} -iname "sub-${SID}_ses-*_ccereb.nii.gz" | sort) )

# * If there are more than two time points, create a template.
if [ ${#CLIST[@]} -gt 1 ]; then

    # ** Select type of parallel computing
    if [ ${CPUS} -eq 1 ]; then
        TYPE=0
    elif [ ${CPUS} -gt 1 ]; then
        TYPE=2
    fi
    
    # ** Settings for antsMultivariateTemplateConstruction2.sh
    J=${CPUS}      # Number of CPUs
    C=${TYPE}      # Type of parallel computing
    I=4            # Iteration limit (default=4)
    Q=25x15x10x5   # Iterations (default=100x100x70x20)
    G=0.25         # Gradient step size (smaller=better+slower; default=0.25)
    F=6x4x2x1      # Shrink factor (default=6x4x2x1)
    S=3x2x1x0      # Smoothing factor (default=3x2x1x0)

    # ** Goto output folder
    cd ${oDIRt}

    # ** Build template
    # Input files are all cropped cerebelli of one subject
    antsMultivariateTemplateConstruction2.sh \
        -d 3 \
        -o ${oDIRt}/T_ \
        -a 1 \
        -j ${J} \
        -c ${C} \
        -i ${I} \
        -q ${Q} \
        -g ${G} \
        -f ${F} \
        -s ${S} \
        -n 0 \
        -r 1 \
        -m CC \
        -t Rigid \
        ${CLIST[@]}

elif [ ${#CLIST[@]} -eq 1 ]; then
    
    echo "Only one session with imaging data found."
    echo "Skip template creation."
    
fi



# * Warp subject specific cerebellar template to SUIT space
cat <<EOF


##############################################################
### Warp subject specific cerebellar template to SUIT      ###
### space if there is more than one session. If there is   ###
### is only one session, warp the single time point to     ###
### SUIT space.                                            ###
##############################################################

EOF

# * Goto output folder
cd ${oDIRs}

# * Define SUIT Template and Subject Template
SUIT_Template=/software/SUIT-templates/SUIT.nii.gz
Subject_Template=${oDIRt}/T_template0.nii.gz

# If there is only one time point, there is no template.
# In this case, select the single masked cerebellum as
# the input file for warping to SUIT space.
if [ ${#CLIST[@]} -eq 1 ]; then
    Subject_Template=${CLIST[0]}
fi

# * Calculate warp
antsRegistration  \
    -d 3  \
    --winsorize-image-intensities [0.005,0.995] \
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
   
exit


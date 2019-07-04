#!/bin/bash

# This script creates a subject specific cerebellar template and
# calcualtes the warp from this template to SUIT space.

# Input arguments
while getopts "s:n:c:i:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         n)
             SESN=$OPTARG
             ;;
         c)
             CPUS=$OPTARG
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
iDIR=/data/out/02_CerIso/sub-${SID}
oDIR=/data/out/03_Template/sub-${SID}
oDIRt=${oDIR}/01_SubjectTemplate
oDIRs=${oDIR}/02_SUITTemplate
mkdir -p ${oDIRt} ${oDIRs}
tDIR="/sofware/ANTS-templates"



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 3: Subject Template Creation and Warping to SUIT  ###
### Start date and time: `date`      ###
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

# Check for which time points cropped cerebelli are available
CLIST=( $(find ${iDIR} -iname "mc_roN4_T1_*.nii.gz" | sort) )

# If there are more than two time points, create a template.
if [ ${#CLIST[@]} -gt 1 ]; then

    # Select type of parallel computing
    if [ ${CPUS} -eq 1 ]; then
        TYPE=0
    elif [ ${CPUS} -gt 1 ]; then
        TYPE=2
    fi
    
    # Settings for antsMultivariateTemplateConstruction2.sh
    J=${CPUS}      # Number of CPUs
    C=${TYPE}      # Type of parallel computing
    I=4            # Iteration limit (default=4)
    Q=25x15x10x5   # Iterations (default=100x100x70x20)
    G=0.25         # Gradient step size (smaller=better+slower; default=0.25)
    F=8x4x2x1      # Shrink factor (default=6x4x2x1)
    S=4x2x1x0      # Smoothing factor (default=3x2x1x0)


    # Goto output folder
    cd ${oDIRt}

    # Build template
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

# If there is only one time point, there is no template.
# In this case, select the single maskes cerebellum as
# the input file for warping to SUIT space.
if [ ${#CLIST[@]} -eq 1 ]; then
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
   
exit

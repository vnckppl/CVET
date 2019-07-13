#!/bin/bash

# This script runs FreeSurfer

# Input arguments
while getopts "s:a:c:i:r:" OPTION
do
    case $OPTION in
        s)
            SID=$OPTARG
            ;;
        a)
            AVERAGE=$OPTARG
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



# Logging
cat <<EOF
##############################################################
### CVET - Cerebellar Volume Extration Tool                ###
### PART 1: FreeSurfer                                     ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
##############################################################

EOF

# Environment
iDIR=/data/in/sub-${SID}
oDIR=/data/out/01_FreeSurfer
mkdir -p ${oDIR}

# List of Sessions
SESLIST=( $(find ${iDIR} -maxdepth 1 -type d -iname "ses-*" | sort | sed "s#${iDIR}/ses-##g") )



# Test for multiple T1 images. If there is more than one T1
# image, average this image. Otherwise, copy the single image.
cat <<EOF
##############################################################
### Average multiple T1-weighted images (if chosen)        ###
##############################################################

EOF

# Loop over sessions
for SES in ${SESLIST[@]}; do

    # Count number of T1 weighted images
    T1list=( $(ls ${iDIR}/ses-${SES}/anat/sub-${SID}_ses-${SES}_run-?_T1w.nii.gz 2>/dev/null| sort) )
    echo "Number of T1-weighted images found for session ${SES}: ${#T1list[@]}"
    echo "${T1list[@]}" | tr " " "\n" | sed 's/^  *//g'
    echo

    # When the list is empty (no T1 scans found):
    if [ ${#T1list[@]} -eq 0 ]; then
        echo "No T1-weighted images were found for session ${SES}. Check your input folder."
        tmpses=( $(echo ${SESLIST[@]} | sed "s/${SES}//g") )
        SESLIST=( $(echo ${tmpses[@]}) )
        continue
    fi

    # Create variable in which we will store the list of T1 images
    FS_input_files="$(echo input_${SES})"
    
    # If selected to average images
    if [ ${AVERAGE} -eq 1 ]; then

        # Check if there is more than one image
        if [ ${#T1list[@]} -gt 1 ]; then

            # Prepare FreeSurfer input command
            eval ${FS_input_files}='$(echo ${T1list[@]} | sed -e "s/ / -i /g" -e "s/^/-i /g")'

        elif [ ${#T1list[@]} -eq 1 ]; then

            # Prepare FreeSurfer input command
            echo "Only one T1 was found for session ${SES}, even though 'averaging' was selected."
            echo "Continue FreeSurfer with this single T1 image."
            eval ${FS_input_files}='$(echo "-i ${T1list[0]}")'

        fi

    elif [ ${AVERAGE} -eq 0 ]; then
        echo "No averaging selected. We will be using the first image that was collected for this session, ignoring any other T1 images that may have been collected during this session."
        eval ${FS_input_files}='$(echo "-i ${T1list[0]}")'

    fi

done



# CrossSectional processing with FreeSurfer
cat <<EOF

##############################################################
### Run FreeSurfer - Cross Sectional                       ###
##############################################################

EOF

# Loop over sessions
for SES in ${SESLIST[@]}; do
#for SES in tp5; do
    # Announce
    echo "Working on ${SID}: ${SES} [FreeSurfer CrossSectional Processing]"

    # Pick up input
    input="$(echo input_${SES})"
    
    # Prepare Freesurfer
    export SUBJECTS_DIR=${oDIR}
    eval "$(echo "recon-all ${!input} -s sub-${SID}_ses-${SES}" | tr "\t" " " | tr "\n" " ")"
    
    # Run Cross Sectional FreeSurfer
    recon-all \
        -autorecon-all \
        -parallel \
        -openmp ${CPUS} \
        -s sub-${SID}_ses-${SES}
    
done
exit
# Only run the rest of this script if there is more than one time point.
if [ ${#SESLIST[@]} -lt 2 ]; then
    echo \
        "Only 1 session found. 
        No need for longitudinal processing.
        Done."
    exit 0
fi



# Create Subject Template with FreeSurfer
cat <<EOF


##############################################################
### Create Subject Template with FreeSurfer                ###
##############################################################

EOF

# Create list of input sessions
TLIST=(
    $(for SES in ${SESLIST[@]}; do
          echo ${SES} | sed "s/^/sub-${SID}_ses-/g"
      done
    )
)

# Run template creation
recon-all -base ${SID} ${TLIST} -all -parallel -openmp ${CPUS}




# Longitudinal processing with FreeSurfer
cat <<EOF

##############################################################
### Run FreeSurfer - Longitudinal                          ###
##############################################################

EOF

# Loop over sessions
for SES in ${SESLIST[@]}; do

    # Announce
    echo "Working on ${SID}: ${SES} [FreeSurfer Longitudinal Processing]"
    
    # Run Longitudinal FreeSurfer
    recon-all \
        -parallel \
        -openmp ${CPUS} \
        -long  sub-${SID}_ses-${SES} \
        ${SID} \
        -all
    
done



# Clean up if flag to keep intermediate files is not set
if [ ${INTERMEDIATE} -eq 0 ]; then
    echo "Removing intermediate files has not been implemented yet"
fi

# Exit
exit

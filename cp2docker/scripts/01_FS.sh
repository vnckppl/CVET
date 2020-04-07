#!/bin/bash

# * This script runs FreeSurfer

# * Input arguments
while getopts "s:a:c:i:r:l:n:" OPTION
do
    case $OPTION in
        s)
            SID=${OPTARG}
            ;;
        a)
            AVERAGE=${OPTARG}
            ;;
        c)
            CPUS=${OPTARG}
            ;;
        i)
            INTERMEDIATE=${OPTARG}
            ;;
        r)
            REPORT=${OPTARG}
            ;;
        l)
            LOCALCOPY=${OPTARG}
            ;;
        n)
            N4=${OPTARG}
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
### PART 1: FreeSurfer                                     ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
##############################################################

EOF

# * Environment
iDIR=/data/in/sub-${SID}
oDIR=/data/out/01_FreeSurfer
mkdir -p ${oDIR}


# * Already Processed Data
# If FreeSurfer data was already processed and
# the user requests to copy this data to inside the
# container, do that here.
if [ ${LOCALCOPY} -eq 1 ]; then

    # ** Announce
    cat <<-EOF
	##############################################################
	### Copy processed FreeSurfer data into the container      ###
	##############################################################

EOF

    echo "Copy Processed FreeSurfer data inside the container"

    # ** Grab subject folders
    subFolders=(
        $(find /freesurfer \
               -maxdepth 1 \
               -type d \
               -iname "sub-${SID}*"
        )
    )

    # ** Temoprary Storage Folder within Container
    tDIR=/data/tmp/01_FreeSurfer
    mkdir -p ${tDIR}
    
    # ** Copy data
    # Loop over folders
    for subFolder in ${subFolders[@]}; do
        cp -r ${subFolder} ${tDIR}
    done

    # ** Done
    # Now we are done with FreeSurfer 'processing',
    # so we can exit this script.
    exit
    
fi



# * N4 non-uniformity (bias field) corretion
# Apply bias field correction on the T1 images
if [ ${N4} -eq 1 ]; then

    # ** Announce
    cat <<-EOF
	##############################################################
	### Apply N4 biasfield correction to the T1 images         ###
	##############################################################

EOF

    # ** Environment
    nDIR=/data/out/00_N4
    mkdir -p ${nDIR}

    # ** Session list
    sessions=(
        $(find ${iDIR} \
               -maxdepth 1 \
               -type d \
               -iname "ses-*"
        )
    )

    # ** Loop over sessions
    for session in ${sessions[@]}; do

        # *** Basename
        SES=$(basename ${session})

        # *** Announce
        echo "Bias Field Correction of T1 data of Subject ${SID}, Session ${SES}'"

        # *** Output folder
        n4oDIR=${nDIR}/sub-${SID}/${SES}/anat
        mkdir -p ${n4oDIR}

        # *** List all T1 images
        T1list=(
            $(find ${iDIR}/${SES}/anat \
                   -maxdepth 1 \
                   -type f \
                   -iname "sub-${SID}_${SES}*T1w.nii*"
            )
        )

        # *** Create brain mask
        # Loop over T1 images 
        for T1 in ${T1list[@]}; do

            # **** Basename
            T1img=$(basename ${T1})

            # **** Naming info
            # We don't use the entire BIDS naming
            # scheme, because we use that for globbing
            # later, and we don't want to mess that up.
            naming=$(echo ${T1img} \
                         | sed \
                               -e "s#sub-${SID}_${SES}_##g" \
                               -e "s#.nii.gz##g" \
                               -e "s#.nii##g"
                  )

            # **** Create coarse brain mask
            # We only need a simple brain mask, because
            # it is only for directing the esgtimation
            # of the bias field. It does not need to be
            # very precise.
            # Calculate affine registration from MNI to subject
            flirt \
                -in /software/FSL-templates/MNI152_T1_1mm.nii.gz \
                -ref ${iDIR}/${SES}/anat/${T1img} \
                -omat ${n4oDIR}/affine_${naming}.mat \
                -v
            # Apply regsitration to MNI brain mask
            flirt \
                -in /software/FSL-templates/MNI152_T1_1mm_brain_mask.nii.gz \
                -ref ${iDIR}/${SES}/anat/${T1img} \
                -applyxfm -init ${n4oDIR}/affine_${naming}.mat \
                -interp nearestneighbour \
                -o ${n4oDIR}/mask_${naming}.nii.gz \
                -v


            # **** Run N4 biasfield correction
            # Run B4 correction with the biasfield estimated
            # from within the brain mask.
            N4BiasFieldCorrection \
                -d 3 \
                -i ${iDIR}/${SES}/anat/${T1img} \
                -w ${n4oDIR}/mask_${naming}.nii.gz \
                -o [${n4oDIR}/sub-${SID}_${SES}_N4_${naming}.nii.gz,${n4oDIR}/BF_${naming}.nii.gz] \
                -s 2 \
                -c 100x75x50 \
                --verbose 1

        done

    done

    # ** Set input folder
    # Now set the input folder to this N4 folder, instead
    # of the original (mounted) input folder.
    iDIR=${nDIR}/sub-${SID}
    
fi



# Test for multiple T1 images. If there is more than one T1
# image, average this image. Otherwise, copy the single image.
cat <<EOF
##############################################################
### Average multiple T1-weighted images (if chosen)        ###
##############################################################

EOF

# * List of Sessions
SESLIST=(
    $(find ${iDIR} -maxdepth 1 -type d -iname "ses-*" | sort | sed "s#${iDIR}/ses-##g")
)

# * Loop over sessions
for SES in ${SESLIST[@]}; do

    # ** Count number of T1 weighted images
    T1list=( $(ls ${iDIR}/ses-${SES}/anat/sub-${SID}_ses-${SES}*T1w.{nii,nii.gz} 2>/dev/null| sort) )
    echo "Number of T1-weighted images found for session ${SES}: ${#T1list[@]}"
    echo "${T1list[@]}" | tr " " "\n" | sed 's/^  *//g'
    echo

    # ** When the list is empty (no T1 scans found):
    if [ ${#T1list[@]} -eq 0 ]; then
        echo "No T1-weighted images were found for session ${SES}. Check your input folder."
        tmpses=( $(echo ${SESLIST[@]} | sed "s/${SES}//g") )
        SESLIST=( $(echo ${tmpses[@]}) )
        continue
    fi

    # ** Create variable in which we will store the list of T1 images
    FS_input_files="$(echo input_${SES})"
    
    # ** If selected to average images
    if [ ${AVERAGE} -eq 1 ]; then

        # *** Check if there is more than one image
        if [ ${#T1list[@]} -gt 1 ]; then

            # *** Prepare FreeSurfer input command
            eval ${FS_input_files}='$(echo ${T1list[@]} | sed -e "s/ / -i /g" -e "s/^/-i /g")'

        elif [ ${#T1list[@]} -eq 1 ]; then

            # *** Prepare FreeSurfer input command
            echo "Only one T1 was found for session ${SES}, even though 'averaging' was selected."
            echo "Continue FreeSurfer with this single T1 image."
            eval ${FS_input_files}='$(echo "-i ${T1list[0]}")'

        fi

    elif [ ${AVERAGE} -eq 0 ]; then
        echo "No averaging selected. We will be using the first image that was collected for this session, ignoring any other T1 images that may have been collected during this session."
        eval ${FS_input_files}='$(echo "-i ${T1list[0]}")'

    fi

done



# * CrossSectional processing with FreeSurfer
cat <<EOF

##############################################################
### Run FreeSurfer - Cross Sectional                       ###
##############################################################

EOF

# * Loop over sessions
for SES in ${SESLIST[@]}; do

    # ** Announce
    echo "Working on ${SID}: ${SES} [FreeSurfer CrossSectional Processing]"

    # ** Pick up input
    input="$(echo input_${SES})"
    
    # ** Prepare Freesurfer
    export SUBJECTS_DIR=${oDIR}
    eval "$(echo "recon-all ${!input} -s sub-${SID}_ses-${SES}" | tr "\t" " " | tr "\n" " ")"
    
    # ** Run Cross Sectional FreeSurfer
    recon-all \
        -autorecon-all \
        -parallel \
        -openmp ${CPUS} \
        -s sub-${SID}_ses-${SES}
    
done

# * Only run the rest of this script if there is more than one time point.
if [ ${#SESLIST[@]} -lt 2 ]; then
    echo \
        "Only 1 session found. 
        No need for longitudinal processing.
        Done."
    exit 0
fi



# * Create Subject Template with FreeSurfer
cat <<EOF


##############################################################
### Create Subject Template with FreeSurfer                ###
##############################################################

EOF

# * Create list of input sessions
TLIST=(
    $(for SES in ${SESLIST[@]}; do
          echo "-tp $(echo "${SES} " | sed "s/^/sub-${SID}_ses-/g")"
      done
    )
)

# * Run template creation
recon-all -base sub-${SID} ${TLIST[@]} -all -parallel -openmp ${CPUS}




# * Longitudinal processing with FreeSurfer
cat <<EOF

##############################################################
### Run FreeSurfer - Longitudinal                          ###
##############################################################

EOF

# * Loop over sessions
for SES in ${SESLIST[@]}; do

    # ** Announce
    echo "Working on ${SID}: ${SES} [FreeSurfer Longitudinal Processing]"
    
    # ** Run Longitudinal FreeSurfer
    recon-all \
        -parallel \
        -openmp ${CPUS} \
        -long sub-${SID}_ses-${SES} \
        sub-${SID} \
        -all
    
done



# * Clean up if flag to keep intermediate files is not set
if [ ${INTERMEDIATE} -eq 0 ]; then
    echo "Removing intermediate files has not been implemented yet"
fi

# * Exit
exit

#!/bin/bash

# This script outputs cerebellar volumes from T1-weighted images.
# The input is a BIDS data folder of a single subject.
# Data can be cross-sectional (1 time point) or longitudinal
# (2 or more time points).

# The pipeline is a multi step approach:
# 1) T1 bias field correction using N4
# 2) Cerebellar and brain stem isolation using SPM and the SUIT toolbox
# 3) Creating a subject specific template and calculating the warp from this template to SUIT space
# 4) Apply the warps to bring the SUIT atlas into native space. Also, bring the cerebellar GM map
#    into SUIT space and modulate and smooth this image for a subsequent VBMB style analysis.
# 5) Extract the GM volume per ROI for each of the 28 lobules of the cerebellum
# 6) Refine the cerebellar mask using FreeSurfer's cerebellar labels and re-extract the
#    GM volume per ROI for each of the 28 lobules of the cerebellum



# Usage
usage() {
    cat<<EOF
$(tput setaf 4)$(tput bold)
- This tool generates 1) a list of gray matter volume for all 28 cerebellar 
  lobules; 2) a modulated gray matter cerebellar volume map in SUIT space.
- As input, it takes a BIDS format compliant subject folder. 
- If there are more than two sessions, a longitudinal processing pipeline 
  will be used.
$(tput sgr0)

OPTIONS:
(mandatory)
   $(tput setaf 5)-s$(tput sgr0)                     The ($(tput setaf 5)$(tput bold)s$(tput sgr0))ubjects BIDS ID without the 'sub-' part.

(optional)
   $(tput setaf 5)-a$(tput sgr0)                     Create an ($(tput setaf 5)$(tput bold)a$(tput sgr0))verage from multiple T1-weighted 
                          images if more than one T1-weighted image was 
                          collected per session. Default is to not average
                          weighted images, but to take the first 
                          T1-weighted image collected during a session. 
                          If an average is created, this will be used for
                          the rest of the pipeline.

   $(tput setaf 5)-c$(tput sgr0)                     Set the number of ($(tput setaf 5)$(tput bold)c$(tput sgr0))pu cores to be used. 
                          The default is 1.

   $(tput setaf 5)-i$(tput sgr0)                     Keep ($(tput setaf 5)$(tput bold)i$(tput sgr0))ntermediate files. By default, 
                          intermediate files will be deleted.

   $(tput setaf 5)-f$(tput sgr0)                     Use ($(tput setaf 5)$(tput bold)F$(tput sgr0))reeSurfer's cerebellum labels to create a 
                          mask to refine the SUIT cerebellum labels that 
                          were registered to subject space. By default, 
                          this is step is omitted. Enter 1 as argument to 
                          process your T1 images with FreeSurfer as part
                          part of this pipeline, or 2 if you want to use
                          previously processed FreeSurfer data. In the
                          latter case, make sure to mount your FreeSurfer
                          SUBJECTS folder where your data resides when
                          starting the container:
                          -v <local subjects folder>:/freesurfer:ro

   $(tput setaf 5)-r$(tput sgr0)                     Write out a ($(tput setaf 5)$(tput bold)r$(tput sgr0))eport with some metrics for 
                          quality control. 

   $(tput setaf 5)-h$(tput sgr0)                     Show this ($(tput setaf 5)$(tput bold)h$(tput sgr0))elp menu

EOF
}

# Input arguments
# Defaults
AVERAGE=0
CPUS=1
INTERMEDIATE=0
REPORT=0
FREESURFER=0

# User defined
while getopts "s:ac:if:rh" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         a)
             AVERAGE=1
             ;;
         c)
             CPUS=$OPTARG
             ;;
         i)
             INTERMEDIATE=1
             ;;
         f)
             FREESURFER=$OPTARG
             ;;
         r)
             REPORT=1
             ;;
         h)
             usage
             exit 1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done


# Print error with layout function
printError() {
    echo "$(tput setaf 7)$(tput setab 1)${1}$(tput sgr0)"
    echo
    usage 
    exit 1
}

# Check input arguments
if [ -z ${SID} ]; then
    printError "Missing mandatory subject argument. Exit."
    exit 1
fi

# Check if number of CPUs is a number
[ "${CPUS}" -eq "${CPUS}" ] 2>/dev/null
if [ $? -ne 0 ]; then
    printError "Number of CPUs incorrectly specified. Exit."
    exit 1
fi  

# Check if FreeSurfer is either set to 1 or to a folder
if [ ! -z ${FREESURFER} ]; then
    if [ ! ${FREESURFER} -eq 0 ] && [ ! ${FREESURFER} -eq 1 ] && [ ! ${FREESURFER} -eq 2 ]; then
        printError "FreeSurfer parameter incorrectly specified. Exit."
        exit 1
    fi
fi



# Processing settings
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${CPUS}



# Environment
inputFolder=/input
scriptsDir=/software/scripts

# Session list
SESL=$(
    ls -p ${inputFolder} \
        | grep ses- \
        | grep \/ \
        | sed 's/\///g' \
        | sed 's/ses-//g'
    )
SESL=( ${SESL} )
# Number of sessions
SESN=${#SESL[@]}



# Run scripts
# 01 T1 Bias Field Correction
# Loop over sessions
for SES in ${SESL[@]}; do

    # Define log file
    logFolder=/output/01_SSN4/sub-${SID}/ses-${SES}
    mkdir -p ${logFolder}
    log=${logFolder}/sub-${SID}_ses-${SES}_log-01-SSN4.txt

    # Start Script
    bash \
        ${scriptsDir}/01_SSN4.sh \
        -s ${SID} \
        -t ${SES} \
        -c ${CPUS} \
        -i ${INTERMEDIATE} \
        -r ${REPORT} \
        &> ${log}

done



# 02 Cerebellum + Brain Stem Isolation
# Loop over sessions
for SES in ${SESL[@]}; do

    # Define log file
    logFolder=/output/02_CerIso/sub-${SID}/ses-${SES}
    mkdir -p ${logFolder}
    log=${logFolder}/sub-${SID}_ses-${SES}_log-02-CerIso.txt

    # Start Script
    bash \
        ${scriptsDir}/02_CerIso.sh \
        -s ${SID} \
        -t ${SES} \
        -i ${INTERMEDIATE} \
        -r ${REPORT} \
        &> ${log}

done



# 03 Subject Template Creation and Normalization to SUIT Space
# Define log file
logFolder=/output/03_Template/sub-${SID}
mkdir -p ${logFolder}
log=${logFolder}/sub-${SID}_log-03-MkTmplt.txt

# Start Script
bash \
    ${scriptsDir}/03_MkTmplt.sh \
    -s ${SID} \
    -n ${SESN} \
    -c ${CPUS} \
    -i ${INTERMEDIATE} \
    -r ${REPORT} \
    &> ${log}



# 04 Segment the whole brain images using SPM12
# Loop over sessions
for SES in ${SESL[@]}; do

    # Define log file
    logFolder=/output/04_Segment/sub-${SID}/ses-${SES}
    mkdir -p ${logFolder}
    log=${logFolder}/sub-${SID}_ses-${SES}_log-04-Segment.txt

    # Start Script
    bash \
        ${scriptsDir}/04_Segment.sh \
        -s ${SID} \
        -t ${SES} \
        -i ${INTERMEDIATE} \
        -r ${REPORT} \
        &> ${log}

done



# 05 Extact volumes and create modulated warped GM maps
# Loop over sessions
for SES in ${SESL[@]}; do

    # Define log file
    logFolder=/output/05_ApplyWarp/sub-${SID}/ses-${SES}
    mkdir -p ${logFolder}
    log=${logFolder}/sub-${SID}_ses-${SES}_log-05-ApplyWarp.txt

    # Start Script
    bash \
        ${scriptsDir}/05_ApplyWarp.sh \
        -s ${SID} \
        -t ${SES} \
        -i ${INTERMEDIATE} \
        -r ${REPORT} \
        &> ${log}

done

fi

# 06 Refine the cerebellar labels with a Extact volumes and create modulated warped GM maps
# If the user selected to apply FreeSurfer:
if [ ${FREESURFER} -eq 1 ] || [ ${FREESURFER} -eq 2 ]; then

    # Loop over sessions
    for SES in ${SESL[@]}; do

        # Define log file
        logFolder=/output/06_RefineFS/sub-${SID}/ses-${SES}
        mkdir -p ${logFolder}
        log=${logFolder}/sub-${SID}_ses-${SES}_log-06-RefineFS.txt

        # Start Script
        bash \
            ${scriptsDir}/06_RefineFS.sh \
            -s ${SID} \
            -t ${SES} \
            -i ${INTERMEDIATE} \
            -f ${FREESURFER} \
            -r ${REPORT} \
            &> ${log}

    done
fi




exit

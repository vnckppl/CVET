#!/bin/bash

# This script outputs cerebellar volumes from T1-weighted images.
# The input is a BIDS data folder of a single subject.
# Data can be cross-sectional (1 time point) or longitudinal
# (2 or more time points).

# The pipeline is a multi step approach:
# 1) T1 bias field correction using N4
# 2) Cerebellar and brain stem isolation using SPM and the SUIT toolbox
# 3) Creating a subject specific template and calculating the warp from this template to SUIT space

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
                          process your T1 images with FreeSurfer, or a 
                          subject's FreeSurfer derivatives if available.

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
fi

# Check if number of CPUs is a number
[ "${CPUS}" -eq "${CPUS}" ] 2>/dev/null
if [ $? -ne 0 ]; then
    printError "Number of CPUs incorrectly specified. Exit."
fi  

# Check if FreeSurfer is either set to 1 or to a folder
if [ ! ${FREESURFER} -eq 0 ] && [ ! ${FREESURFER} -eq 1 ] && [ ! -d ${FREESURFER} ]; then
    printError "FreeSurfer parameter incorrectly specified. Exit."
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

DOEN="NEE"
if [ ${DOEN} = "JA" ]; then

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

fi

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


exit

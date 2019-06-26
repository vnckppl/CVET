#!/bin/bash

# This script outputs cerebellar volumes from T1-weighted images.
# The input is a BIDS data folder of a single subject.
# Data can be cross-sectional (1 time point) or longitudinal
# (2 or more time points).

# The pipeline is a multi step approach:
# 1) T1 bias field correction using N4


# Usage
usage() {
    cat<<EOF
Run this command as:
${0} sub-<Your-BIDS-Subject-ID-Goes-Here>
EOF
}


# Check input arguments
if [ -z ${1} ]; then
    echo "Missing subject argument. Exit."
    usage
    exit 1
fi


# Environment
SID=${1}
inputFolder=/input
subFolder=/output/sub-${SID}
scriptsDir=/software/scripts
mkdir -p ${subFolder}

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
    logFolder=${subFolder}/ses-${SES}/01_SSN4
    mkdir -p ${logFolder}
    log=${logFolder}/sub-${SID}_ses-${SES}_log-01-SSN4.txt

    # Start Script
    bash \
        ${scriptsDir}/01_SSN4.sh \
        ${SID} \
        ${SES} \
        &> ${log}

done


# 02 Cerebellum + Brain Stem Isolation
# Loop over sessions
# for SES in ${SESL[@]}; do

#     # Define log file
#     logFolder=${subFolder}/ses-${SES}/02_CerIso
#     mkdir -p ${logFolder}
#     log=${logFolder}/sub-${SID}_ses-${SES}_log-02-CerIso.txt

#     # Start Script
#     bash \
#         ${scriptsDir}/02_CerIso.sh \
#         ${SID} \
#         ${SES} \
#         &> ${log}

# done





exit

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
${0} sub-<Your-BIDS-Subject-ID-Goes-Here> KeepIntermediate
'KeepIntermediate' is optional. If you add it, intermediate files will not be deleted.
EOF
}


# Check input arguments
if [ -z ${1} ]; then
    echo "Missing subject argument. Exit."
    usage
    exit 1
fi

if [ ${2} = "KeepIntermediate" ]; then
    KI="KI"
fi

# Environment
SID=${1}
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
        ${SID} \
        ${SES} \
        ${KI} \
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
        ${SID} \
        ${SES} \
        ${KI} \
        &> ${log}

done


# 03 Subject Template Creation and Normalization to SUIT Space
# Define log file
logFolder=${subFolder}/subjectTemplate
mkdir -p ${logFolder}
log=${logFolder}/sub-${SID}_log-03-Template.txt

# Start Script
bash \
    ${scriptsDir}/03_Template.sh \
    ${SID} \
    ${SESN} \
    &> ${log}


exit

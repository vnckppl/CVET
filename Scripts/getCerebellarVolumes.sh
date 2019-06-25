#!/bin/bash

# This script outputs cerebellar volumes from T1-weighted images.
# The input is a BIDS data folder of a single subject.
# Data can be cross-sectional (1 time point) or longitudinal
# (2 or more time points).

# The pipeline is a multi step approach:
# 1) T1 bias field correction using N4

# Environment
inputFolder=/input
scriptsDir=/software/scripts


# Test if this at least looks like bids data
prefix="$(basename ${inputFolder} | cut -c 1-4)"
sDirName=$(dirname "${inputFolder}" | awk -F/ '{ print $NF }')
if [ ! "${prefix}" = "sub-" ] || [ ! "${sDirName}" = "sourcedata" ]; then
    echo "ERROR: The folder you entered as input folder does not seem to be a BIDS data folder of a single subject. Exit"
    exit 1
fi

# Test if there is already a derivatives folder
dDirName=$(echo $(dirname $(dirname ${inputFolder}))/derivatives)
if [ ! -d ${dDirName} ]; then
    
    echo "No derivatives folder found. Creating derivatives folder"
    mkdir ${dDirName}

fi

# Derive Subject ID from folder
SID=$(sDirnName | sed 's/sub-//g')

# Session list
SESL=$(cat ${inputFolder}/sub-${SID}_sessions.tsv \
           | tr "\t" " " \
           | sed 's/  */ /g' \
           | rs -T \
           | grep session_id \
           | sed 's/  */ /g' \
           | cut -d " " -f 2- \
    )
SESL=( ${SESL} )
# Number of sessions
SESN=${#SESL[@]}


# Run scripts
# T1 Bias Field Correction
# Loop over sessions
for SES in ${SESL[@]}; do

    bash ${scriptsDir}/01_N4SS.sh ${SID} ${SES}

done



exit

#!/bin/bash

# Wrapper to run the LHAB-SUIT Docker file

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
   $(tput setaf 5)-d$(tput sgr0)                     Local source ($(tput setaf 5)$(tput bold)d$(tput sgr0))data path. This is the root 
                          folder in which all the session folders are located 
                          for one individual. This folder should adhere to 
                          the BIDS structure. The subject ID will be derived
                          from this folder name.

   $(tput setaf 5)-l$(tput sgr0)                     Path to local FreeSurfer ($(tput setaf 5)$(tput bold)l$(tput sgr0))icense file.
                          This pipeline uses FreeSurfer commands. A FreeSurfer 
                          license (.license or license.txt) is therefore 
                          required. Get your free license here: 
                          https://surfer.nmr.mgh.harvard.edu/registration.html. 


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
                          part of this pipeline, or a path to an existing
                          folder with previously processed FreeSurfer data.
                          This folder should contain subfolders that 
                          include the subject ID in their name 
                          and adhering to the BIDS strucure.
                          
   $(tput setaf 5)-r$(tput sgr0)                     Write out a ($(tput setaf 5)$(tput bold)r$(tput sgr0))eport with some metrics for 
                          quality control. 

   $(tput setaf 5)-h$(tput sgr0)                     Show this ($(tput setaf 5)$(tput bold)h$(tput sgr0))elp menu

EOF
}

# Print error with layout function
printError() {
    echo
    echo "$(tput setaf 7)$(tput setab 1)${1}$(tput sgr0)"
    echo
    usage 
    exit 1
}

# Check if Docker is available
docker images &>/dev/null
if [ $? -ne 0 ]; then
    printError "Docker error. Is Docker running?"
    exit 1
fi

# Check if my container is available
if [ ! "$(docker images | grep -w "vkoppelm/suit" | grep -w "lhab")" ]; then
    printError "Can't find Docker image 'vkoppelm/suit:lhab'. Exit."
    exit 1
fi

# Input arguments
# Defaults
CPUS=1
FREESURFER=0

# User defined
while getopts "d:l:ac:if:rh" OPTION
do
     case $OPTION in
         d)
             DATA=$OPTARG
             ;;
         l)
             LICENSE=$OPTARG
             ;;
         a)
             AVERAGE="-a"
             ;;
         c)
             CPUS=$OPTARG
             ;;
         i)
             INTERMEDIATE="-i"
             ;;
         f)
             FREESURFER=$OPTARG
             ;;
         r)
             REPORT="-r"
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



# Check input arguments
if [ ! -d ${DATA} ]; then
    printError "Missing mandatory data folder argument. Exit."
    echo
    usage
    exit 1
fi

# Obtain Subject ID
SID=$(basename ${DATA} | sed 's/sub-//g' )

# Check if license file exists
if [ ! -f ${LICENSE} ]; then
    printError "License file '${LICENSE}' does not exist. Exit."
    echo
    usage
    exit 1
fi

# Check if number of CPUs is a number
[ "${CPUS}" -eq "${CPUS}" ] 2>/dev/null
if [ $? -ne 0 ]; then
    printError "Number of CPUs incorrectly specified. Exit."
    echo
    usage
    exit 1
fi  

# Check if FreeSurfer is either set to 1 or to a folder
# Check if FREESURFER is a number
[ "${FREESURFER}" -eq "${FREESURFER}" ] 2>/dev/null
OUT=$?
if [ ${OUT} -eq 0 ]; then

    # If FreeSurfer is set to 1 (process all data with
    # FreeSurfer), then forward this option
    if [ ${FREESURFER} -eq 1 ]; then
        FSPROCESS="-f 1"

    # If this number is not 1
    elif [ ! ${FREESURFER} -eq 1 ]; then
        printError "FreeSurfer parameter incorrectly specified.. Exit."
        usage
        exit 1
    fi

# If FREESURER is not a number...
elif [ ${OUT} -ne 0 ]; then

    # ...check if it is an existing folder 
    if [ ! -d ${FREESURFER} ]; then
        printError "Path to FreeSurfer data not an existing folder.. Exit."
        usage
        exit 1
    
    # If a FreeSurfer data path is an existing folder, then mount this
    # path with Docker (see below)
    elif [ -d ${FREESURFER} ]; then
        FSPATH="-v ${FREESURFER}:/freesurfer:ro"
        
    fi
fi
    



# Run Docker
docker \
    run -it \
    -v ${DATA}:/input:ro \
    -v /Users/vincent/Data/tmp/20190625_N4test/derivatives/SUIT:/output \
    -v ${LICENSE}:/software/freesurfer/.license:ro ${FSPATH} ${FSPROCESS} \
    vkoppelm/suit:lhab \
    bash /software/scripts/getCerebellarVolumes.sh \
    -s ${SID} \
    ${AVERAGE} \
    -c ${CPUS} \
    ${INTERMEDIATE} \
    -f ${FREESURFER} \
    ${REPORT}


exit

#!/bin/bash

# Wrapper to run the Docker file

usage() {
    cat <<EOF 
Run this command as:
${0} Your-BIDS-Subject-ID-Goes-Here

The BIDS Subject ID is the ID without the 'sub-' part.

EOF
}

# Check input arguments
if [ -z ${1} ]; then
    echo "Missing subject argument. Exit."
    usage
    exit
fi

SUBID=${1}

# Run Docker
docker \
    run -it \
    -v /Volumes/lhab_data/LHAB/LHAB_v1.1.1/sourcedata/sub-${SUBID}:/input:ro \
    -v /Volumes/lhab_data/LHAB/LHAB_v1.1.1/derivatives/SUIT:/output \
    vkoppelm/suit:lhab \
    bash /software/scripts/getCerebellarVolumes.sh ${SUBID} KeepIntermediate

exit

#!/bin/bash

# This script outputs cerebellar volumes from T1-weighted images.
# The input is a BIDS data folder of a single subject.
# Data can be cross-sectional (1 time point) or longitudinal
# (2 or more time points).

# The pipeline is a multi step approach:
# 1) T1 bias field correction using N4

# Environment
inputFolder="${$1}"
scriptsDir=$(echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"/Scripts)


# Test if this at least looks like bids data
prefix="$(basename ${inputFolder} | cut -c 1-4)"
sDirName=$(dirname "${inputFolder}" | awk -F/ '{ print $NF }')
if [ ! "${prefix}" = "sub-" ] || [ ! "${sDirName}" = "sourcedata" ]; then
    echo "ERROR: The folder you entered as input folder does not seem to be a BIDS data folder. Exit"
    exit 1
fi

# Test if there is already a derivatives folder
dDirName=$(echo $(dirname $(dirname ${inputFolder}))/derivatives)
if [ ! -d ${dDirName} ]; then
    
    echo "No derivatives folder found. Creating derivatives folder"
    mkdir ${dDirName}

fi

# Run scripts













# This script takes in a BIDS data folder of a single subject
# with one or more time points and uses only the T1 to 

# This script performas N4 bias field correction
# within a brain mask.

# Initialize FSL
source /usr/local/fsl/bin/fsl

# Environment
lhab_data="/home/vkoppe-utah/lhab_data/LHAB/LHAB_v1.1.1"
iDIR="${lhab_data}/sourcedata"
oDIR="${lhab_data}/derivatives/CerebSUIT_20190617"
tDIR="/path/to/MICCAI2012-Multi-Atlas-Challenge-Data"
mkdir -p ${oDIR}

# Loop over subjects
for SUB in $(ls ${iDIR}); do

    # Create Script for N4 bias field correction
    cat <<-EOF > 
	#!/bin/bash

	# This script creates a skull stripped brain
	# image for subject ${SUB}. It was generated
	# on $(date).

	# Environment
	SUB=${SUB}
	iDIR=${iDIR}/\${SUB}
	oDIR=${oDIR}/\${SUB}/01_SSN4
	mkdir -p \${oDIR}	

	# Copy over data
	


	# Skull Strip
	echo "<---------- 01: Skull Strip ---------->"
	antsBrainExtraction.sh \
	    -d 3 \
	    -a ${iDIR}/memprage.nii \
	    -e ${tDIR}/T_template0.nii.gz \
	    -m ${tDIR}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
	    -f ${tDIR}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
	    -o ${oDIR}/ss_${SUB}_ \
	    -k 0
	
	
	# N4 Bias Field Correction
	echo "<---------- 02: N4 Bias Field Correction ---------->"
	fslmaths \
	    ${oDIR}/ss_${SUB}_BrainExtractionMask.nii.gz \
	    -dilM -dilM \
	    ${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz
	
	# ITK is very sensitive with any deviations between
	# sform / qform codes. Decimal changes that occur
	# will result in problems with the bias field correction.
	# We are therefore going to copy over the affine matrix
	# to avoid this.
	fslcpgeom \
	    ${iDIR}/memprage.nii \
	    ${oDIR}/ss_${SUB}_BrainExtractionMask.nii.gz
	
	fslcpgeom \
	    ${iDIR}/memprage.nii \
	    ${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz
	
	# Note: adding a mask forces the N4 application within the mask
	# We want to do the estimation within the mask, but the application
	# on the whole image. So we use -w but not -x.
	N4BiasFieldCorrection \
	    -d 3 \
	    -i ${iDIR}/memprage.nii \
	    -w ${oDIR}/ss_${SUB}_BrainExtractionMask_dilM2.nii.gz \
	    -s 2 \
	    -c [125x100x75x50] \
	    -o [${oDIR}/N4_${SUB}.nii.gz,${oDIR}/BF_${SUB}.nii.gz] \
	    -v 1
	
	# Unzip for SUIT (SPM does not work with .gz files)
	gunzip ${oDIR}/N4_${SUB}.nii.gz
	
	# Exit
	exit

 eof
done

	

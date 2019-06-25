#!/bin/bash

# This script performas N4 bias field correction within a brain mask.

# Environment
iDIR=/input/sub-${SID}
oDIR=/output/derivatives




lhab_data="/home/vkoppe-utah/lhab_data/LHAB/LHAB_v1.1.1"
iDIR="${lhab_data}/sourcedata"
oDIR="${lhab_data}/derivatives/CerebSUIT_20190617"
tDIR="/path/to/MICCAI2012-Multi-Atlas-Challenge-Data"
mkdir -p ${oDIR}

# Loop over subjects
for SUB in $(ls ${iDIR}); do

    # Create Script for N4 bias field correction

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


done

	

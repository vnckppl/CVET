#!/bin/bash

# This script isolates the Cerebellum and Brain Stem using the SUIT toolbox for SPM

# Environment
SID="${1}"
SES="${2}"
iDIR=/output/sub-${SID}/ses-${SES}/01_SSN4
oDIR=/output/sub-${SID}/ses-${SES}/02_CerIso
mkdir -p ${oDIR}



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcelation Pipeline                        ###
### PART 2: Cerebellum + Brain Stem Isolation              ###
### Start date and time: `date`     ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# SUIT only works if the data is in LPI orientation. Make
# sure this is the case.
cat <<EOF
##############################################################
### Reortient T1 to LPI                                    ###
##############################################################

EOF
fslreorient2std \
    ${oDIR}/N4_T1.nii.gz
    ${oDIR}/roN4_T1.nii.gz



# Run SUIT Cerebellar Isolation under SPM
cat <<EOF
##############################################################
### Isolate the Cerebellum and Brainstem using SUIT        ###
##############################################################

EOF

# Unzip for SPM
gunzip -v ${oDIR}/roN4_T1.nii.gz

# Create matlab batch file
cat <<EOF> ${oDIR}/isolate_job.m
%-----------------------------------------------------------------------
% SUIT Cerebellum Isolation Batch
% This script was automatically generated on `date` 
%-----------------------------------------------------------------------
matlabbatch{1}.spm.tools.suit.isolate_seg.source = {{'${oDIR}/roN4_T1.nii,1'}};
matlabbatch{1}.spm.tools.suit.isolate_seg.bb = [-76 76
                                                -108 -6
                                                -70 11];
matlabbatch{1}.spm.tools.suit.isolate_seg.maskp = 0.2;
matlabbatch{1}.spm.tools.suit.isolate_seg.keeptempfiles = 0;

EOF

# Run isolation job
/software/run_spm12.sh \
    /software/MCR/v94 \
    batch ${oDIR}/isolate_job.m

# Zip nifti files
cd ${oDIR}
find . -iname "*.nii" | xargs -I {} gzip -9 {}

# Exit
exit

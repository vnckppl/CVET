#!/bin/bash

# This script segments the whole brain into a GM tissue class using SPM

# Input arguments
while getopts "s:t:i:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         t)
             SES=$OPTARG
             ;;
         i)
             INTERMEDIATE=$OPTARG
             ;;
         r)
             REPORT=$OPTARG
             ;;
         ?)
             exit
             ;;
     esac
done



# Environment
tDIR=/software/SPM_Templates
iDIR=/output/02_CerIso/sub-${SID}/ses-${SES}
oDIR=/output/04_Segment/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}



# Logging
cat <<EOF
##############################################################
### Cerebellar Parcellation Pipeline                       ###
### PART 4: Segmentation                                   ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF



# Run SUIT Cerebellar Isolation under SPM
cat <<EOF
##############################################################
### Segment brain using SPM12                              ###
##############################################################

EOF

# Unzip for SPM
gunzip -vc ${iDIR}/roN4_T1.nii.gz > ${oDIR}/roN4_T1.nii

# Create matlab batch file
cat <<EOF> ${oDIR}/segment_job.m
%-----------------------------------------------------------------------
% SUIT Cerebellum Isolation Batch
% This script was automatically generated on `date` 
%-----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.preproc.channel.vols = {'${oDIR}/roN4_T1.nii,1'};
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 10;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = Inf;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {'${tDIR}/TPM.nii,1'};
matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {'${tDIR}/TPM.nii,2'};
matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {'${tDIR}/TPM.nii,3'};
matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {'${tDIR}/TPM.nii,4'};
matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {'${tDIR}/TPM.nii,5'};
matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {'${tDIR}/TPM.nii,6'};
matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0];
EOF

# Run segmentation job
/software/SPM/run_spm12.sh \
    /software/MCR/v94 \
    batch ${oDIR}/segment_job.m

# Zip nifti files
cd ${oDIR}
find . -iname "*.nii" | xargs -I {} gzip -9 {}



# Clean up if flag to keep intermediate files is not set
if [ ${INTERMEDIATE} -eq 0 ]; then

    echo "No files here to clean up yet"

fi

# Exit
exit

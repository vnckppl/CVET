#!/bin/bash

# This script segments the whole brain into a GM tissue class using SPM

# Input arguments
while getopts "s:t:n:f:i:r:" OPTION
do
     case $OPTION in
         s)
             SID=$OPTARG
             ;;
         t)
             SES=$OPTARG
             ;;
         n)
             SESN=$OPTARG
             ;;
         f)
             FSDATA=$OPTARG
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



# Logging
cat <<EOF
##############################################################
### CVET - Cerebellar Volume Extration Tool                ###
### PART 3: Tissue Class Segmentation                      ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF

# Environment
tDIR=/software/SPM-templates
iDIR=/data/out/01_FreeSurfer/sub-${SID}/ses-${SES}/
oDIR=/data/out/03_Segment/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}

# Set FreeSurfer data location
if [ ${FSDATA} -eq 0 ]; then
    FSDATADIR=/freesurfer
elif [ ${FSDATA} -eq 1 ]; then
    FSDATADIR=/data/out/01_FreeSurfer
fi



# Run SUIT Cerebellar Isolation under SPM
cat <<EOF
##############################################################
### Segment brain using SPM12                              ###
##############################################################

EOF

# Figure out which FS folder to use. Search for subject and
# session; then for a longitudinal folder. If that is not
# present, then look for a cross-sectional folder.
if [ ${SESN} -gt 1 ]; then
    FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES} | grep long)
    FSDIR="${FSDATADIR}/${FSSUBDIR}"
    if [ ! -d ${FSDATADIR} ]; then
        FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES})
        FSDIR="${FSDATADIR}/${FSSUBDIR}"
    fi
elif [ ${SESN} -eq 1 ]; then
    FSSUBDIR=$(ls -p ${FSDATADIR} | grep \/ | sed 's/\///g' | grep sub-${SID}_ses-${SES} | grep -v long)
    FSDIR="${FSDATADIR}/${FSSUBDIR}"               
fi
if [ -z ${FSDIR} ]; then
    echo "No FreeSurfer folder for Subject ${SID}, Session ${SES} found. Exit."
    exit 1
fi

# Convert native space averaged T1 to nii for SPM
rawavg=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep rawavg.mgz)
mri_convert \
    ${rawavg} \
    ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz

# Apply bias field correction in a brain mask.
# First transform brainmask to rawavg space
orig=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep orig.mgz)
# Extract the registation parameters from native space to freesurfer native space
tkregister2 \
    --mov ${rawavg} \
    --targ ${orig} \
    --reg ${oDIR}/register.native.dat \
    --noedit \
    --regheader

# Convert this registration to ITK (ANTs) format
lta_convert \
    --inreg ${oDIR}/register.native.dat \
    --outitk ${oDIR}/register.native.txt \
    --trg ${orig} \
    --src ${rawavg}

# Conert the brain mask to nifti
brainmask=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep brainmask.mgz)
mri_convert \
    ${brainmask} \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask.nii.gz

# Apply the registration to the brian mask
antsApplyTransforms \
    -d 3 \
    -i ${oDIR}/sub-${SID}_ses-${SES}_brainmask.nii.gz \
    -r ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -o ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
    -t [${oDIR}/register.native.txt,1] \
    --float \
    -v

# Create the binary dilated brain mask for N4biasfield correction
fslmaths \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
    -bin \
    -dilM \
    -dilM \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask_bin_dilM2.nii.gz

# Note: adding a mask forces the N4 application within the mask
# We want to do the estimation within the mask, but the application
# to the entire image. So we use -w but not -x.
N4BiasFieldCorrection \
    -d 3 \
    -i ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -w ${oDIR}/sub-${SID}_ses-${SES}_brainmask_bin_dilM2.nii.gz \
    -s 2 \
    -c [125x100x75x50] \
    -o [${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz,${oDIR}/BF_rawavg.nii.gz] \
    -v 1

# Create image for quality control of bias field correction.
# For this, we will z-transform both the T1 and the N4_T1 image.
mean_T1=$(fslstats ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz -m)
sd_T1=$(fslstats ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz -s)
fslmaths ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz -sub ${mean_T1} ${oDIR}/T1-mean.nii.gz
fslmaths ${oDIR}/T1-mean.nii.gz -div ${sd_T1} ${oDIR}/zT1.nii.gz

mean_N4T1=$(fslstats ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz -m)
sd_N4T1=$(fslstats ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz -s)
fslmaths ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz -sub ${mean_N4T1} ${oDIR}/N4_T1-mean.nii.gz
fslmaths ${oDIR}/N4_T1-mean.nii.gz -div ${sd_N4T1} ${oDIR}/zN4_T1.nii.gz

fslmaths ${oDIR}/zT1.nii.gz -sub ${oDIR}/zN4_T1.nii.gz ${oDIR}/N4_effect.nii.gz

rm -f ${oDIR}/T1-mean.nii.gz
rm -f ${oDIR}/zT1.nii.gz
rm -f ${oDIR}/N4_T1-mean.nii.gz
rm -f ${oDIR}/zN4_T1.nii.gz


# Unip for SPM
gunzip -v ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz


# Create matlab batch file
cat <<EOF> ${oDIR}/segment_job.m
%-----------------------------------------------------------------------
% SUIT Cerebellum Isolation Batch
% This script was automatically generated on `date` 
%-----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.preproc.channel.vols = {'${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii,1'};
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0;
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

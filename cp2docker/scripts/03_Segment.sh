#!/bin/bash

# This script segments the whole brain into a GM tissue class using SPM12 or ANTs Atropos

# * Input arguments
while getopts "s:t:n:f:m:i:l:r:" OPTION
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
         m)
             METHOD=$OPTARG
             ;;
         i)
             INTERMEDIATE=$OPTARG
             ;;
         l)
             LOCALCOPY=${OPTARG}
             ;;
         r)
             REPORT=$OPTARG
             ;;
         ?)
             exit
             ;;
     esac
done



# * Logging
cat <<EOF
##############################################################
### CVET - Cerebellar Volume Extration Tool                ###
### PART 3: Tissue Class Segmentation                      ###
### Start date and time: `date`      ###
### Subject: ${SID}                                     ###
### Session: ${SES}                                           ###
##############################################################

EOF

# * Environment
tDIR=/software/SPM-templates
pDIR=/software/TissuePriors
oDIR=/data/out/03_Segment/sub-${SID}/ses-${SES}
mkdir -p ${oDIR}

# * Set FreeSurfer data location
if [ ${FSDATA} -eq 0 ]; then
    if [ ${LOCALCOPY} -eq 1 ]; then
        FSDATADIR=/data/tmp/01_FreeSurfer
    elif [ ${LOCALCOPY} -eq 0 ]; then
        FSDATADIR=/freesurfer
    fi
elif [ ${FSDATA} -eq 1 ]; then
     FSDATADIR=/data/out/01_FreeSurfer
fi



# * Prepare for Segmentation: Brain Masking and Bias Field Correction
cat <<EOF
##############################################################
### T1 Brain Masking and N4 Bias Field Correction          ###
##############################################################

EOF

# * Fetch FreeSurfer Subject and Session Data Folder
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

# * Convert native space averaged T1 to nii
rawavg=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep rawavg.mgz)
mri_convert \
    ${rawavg} \
    ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz

# * Apply bias field correction in a brain mask.
# ** First transform brainmask to rawavg space
orig=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep orig.mgz)
# Extract the registation parameters from native space to freesurfer native space
tkregister2 \
    --mov ${rawavg} \
    --targ ${orig} \
    --reg ${oDIR}/register.native.dat \
    --noedit \
    --regheader

# ** Convert this registration to ITK (ANTs) format
lta_convert \
    --inreg ${oDIR}/register.native.dat \
    --outitk ${oDIR}/register.native.txt \
    --trg ${orig} \
    --src ${rawavg}

# ** Convert the brain mask to nifti
brainmask=$(find ${FSDATADIR} | grep sub-${SID}_ses-${SES} | grep -v long | grep brainmask.mgz)
mri_convert \
    ${brainmask} \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask.nii.gz

# ** Apply the registration to the brain mask
antsApplyTransforms \
    -d 3 \
    -i ${oDIR}/sub-${SID}_ses-${SES}_brainmask.nii.gz \
    -r ${oDIR}/sub-${SID}_ses-${SES}_rawavg.nii.gz \
    -o ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
    -t [${oDIR}/register.native.txt,1] \
    --float \
    -v

# ** Create the binary dilated brain mask for N4biasfield correction
fslmaths \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
    -bin \
    -dilM \
    -dilM \
    ${oDIR}/sub-${SID}_ses-${SES}_brainmask_bin_dilM2.nii.gz

# ** Apply N4 Bias Field Correction
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

# ** Create image for quality control of bias field correction.
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

# * Segmentation
if [ ${METHOD} = "S" ]; then

    # ** SPM
    cat <<-EOF
	##############################################################
	### Segment brain using SPM12                              ###
	##############################################################
EOF

    # *** Unip T1 for SPM
    gunzip -v ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz

    # *** Create matlab batch file
    cat <<-EOF> ${oDIR}/segment_job.m
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

    # *** If you are NOT root, set your home folder
    # If you run the container as user, then HOME is set to '/'.
    # This results in a permission error from the spm binary.
    # Create a HOME folder and set the environment.
    if [ ! "$(whoami)" = "root" ]; then
        
        # Export and create home folder 
        echo "CVET running as user: set 'HOME' environment for homeless user"
        export HOME=/software/myHome
        mkdir -p ${HOME}
        
    fi

    # *** Run segmentation job
    /software/SPM/run_spm12.sh \
        /software/MCR/v94 \
        batch ${oDIR}/segment_job.m

    # *** Zip nifti files
    cd ${oDIR}
    find . -iname "*.nii" | xargs -I {} gzip -9 {}

elif [ "${METHOD}" = "A" ]; then

    # ** ANTs Atropos
    cat <<-EOF
	##############################################################
	### Segment brain using ANTs Atropos                       ###
	##############################################################
EOF

    # ** Create Binary Brain Mask
    fslmaths \
        ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
        -bin \
        ${oDIR}/sub-${SID}_ses-${SES}_bin_brainmask_in_rawavg.nii.gz

    # ** Create Skull Stripped Brain
    fslmaths \
        ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
        -mas ${oDIR}/sub-${SID}_ses-${SES}_bin_brainmask_in_rawavg.nii.gz \
        ${oDIR}/sub-${SID}_ses-${SES}_rawavg_ssN4.nii.gz
    
    # ** Calculate warp from Tissue Prior Probability Map space to Native Space
    T="${pDIR}/MNI152_T1_1mm_brain.nii.gz"
    M="${oDIR}/sub-${SID}_ses-${SES}_rawavg_ssN4.nii.gz"
    oDIRa1="${oDIR}/01_Warp"
    mkdir -p "${oDIRa1}"

    # ** Calculate warp using ANTs with SyN
    cd ${oDIRa1}
    antsRegistration \
        -d 3 \
        --winsorize-image-intensities [0.005,0.995] \
        -r [ "${T}" , "${M}" , 1] \
        -m mattes[ "${T}", "${M}" , 1, 32, regular, 0.3] \
        -t translation[ 0.1 ] \
        -c [10000x111110x11110,1.e-8,20]  \
        -s 4x2x1vox  \
        -f 6x4x2 -l 1 \
        -m mattes[ "${T}", "${M}" , 1 , 32, regular, 0.3 ] \
        -t rigid[ 0.1 ] \
        -c [10000x111110x11110,1.e-8,20]  \
        -s 4x2x1vox  \
        -f 3x2x1 -l 1 \
        -m mattes[ "${T}", "${M}" , 1 , 32, regular, 0.3 ] \
        -t affine[ 0.1 ] \
        -c [10000x111110x11110,1.e-8,20]  \
        -s 4x2x1vox  \
        -f 3x2x1 -l 1 \
        -m mattes[ "${T}" , "${M}" , 0.5 , 32 ] \
        -m cc[ "${T}" , "${M}" , 0.5 , 4 ] \
        -t SyN[ .20, 3, 0 ] \
        -c [ 100x100x50,-0.01,5 ]  \
        -s 1x0.5x0vox  \
        -f 4x2x1 -l 1 -u 1 -z 1 \
        -o [ants_,normalizedImage.nii.gz,inverseWarpField.nii.gz] \
        -v 1

    # ** Apply Warps to the Tissue Probabily Maps
    oDIRa2="${oDIR}/02_WarpedTPMs"
    mkdir -p "${oDIRa2}"

    for i in {1..6}; do

        # Apply registration
        antsApplyTransforms \
            -d 3 \
            -i ${pDIR}/p${i}.nii.gz \
            -r ${M} \
            -o ${oDIRa2}/wp${i}.nii.gz \
            -t ${oDIRa1}/ants_1InverseWarp.nii.gz \
            -t [${oDIRa1}/ants_0GenericAffine.mat,1] \
            --float \
            -v 1

    done

    # ** Create Mask That Includes Tissue Classes
    # I.e., all voxels.
    fslmaths \
        ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
        -add 1 \
        -bin \
        ${oDIR}/sub-${SID}_ses-${SES}_all_voxel_mask_in_rawavg.nii.gz
    
    # ** Atropos segmentation
    oDIRa3="${oDIR}/03_Atropos"
    mkdir -p "${oDIRa3}"
    cd ${oDIRa3}

    antsAtroposN4.sh \
        -d 3 \
        -a ${oDIR}/sub-${SID}_ses-${SES}_rawavg_N4.nii.gz \
        -c 6 \
        -x ${oDIR}/sub-${SID}_ses-${SES}_all_voxel_mask_in_rawavg.nii.gz \
        -p ${oDIRa2}/wp%d.nii.gz \
        -o ${oDIRa3}/
    
    # ** Restrict segmentations to brain mask
    for i in {1..6}; do

        # Mask out
        fslmaths \
            ${oDIRa3}/SegmentationPosteriors${i}.nii.gz \
            -mas ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
            ${oDIR}/c${i}sub-${SID}_ses-${SES}_rawavg_N4.nii.gz
    done

    # ** Restrict labeled image to brain mask
    fslmaths \
        ${oDIRa3}/Segmentation.nii.gz \
        -mas ${oDIR}/sub-${SID}_ses-${SES}_brainmask_in_rawavg.nii.gz \
        ${oDIRa3}/labels.nii.gz          
  
fi

# * Clean up if flag to keep intermediate files is not set
if [ ${INTERMEDIATE} -eq 0 ]; then

    rm -f \
       ${oDIR}/register.native.dat \
       ${oDIR}/register.native.txt \
       ${oDIR}/BF_rawavg.nii.gz \
       ${oDIR}/N4_effect.nii.gz       
            
    if [ "${METHOD}" = "A" ]; then
        
        rm -rf ${oDIRa1} ${oDIRa2} ${oDIRa3}
        rm -f \
           ${oDIR}/sub-${SID}_ses-${SES}_all_voxel_mask_in_rawavg.nii.gz
           
    fi
    
fi

# Exit
exit

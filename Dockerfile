FROM ubuntu:bionic

# LAHB Longituindal SUIT Docker image setup 

### Create software and data input and output folders
RUN \
        mkdir -p /software/scripts && \
        mkdir -p /input && \
        mkdir -p /output



### Install Dependencies
RUN \
        apt-get update && \
        apt-get dist-upgrade -y --no-install-recommends && \
        apt-get install -y \
        cmake \
        git \
        g++ \
        zlib1g \
        zlib1g-dev \
        wget \
        curl \
        gnupg2 \
        unzip rs



############
### ANTS ###
############
### Install ANTs
RUN \
        sourceDir="/software/ANTS-source" && \
        mkdir -p ${sourceDir} && \
        cd ${sourceDir} && \
        git clone https://github.com/ANTsX/ANTs --branch v2.3.1 && \
        source="${sourceDir}/ANTs" && \
        binDir="/software/ANTS-2.3.1" && \
        mkdir -p ${binDir} && \
        cd ${binDir} && \
        cmake ${source} -DZLIB_LIBRARY=/usr/lib/x86_64-linux-gnu/libz.so && \
        cmake ${source} && \
        make -j 4 && \
        mv ${source}/Scripts/* ${binDir}/bin

ENV \
        ANTSPATH=/software/ANTS-2.3.1/bin \
        PATH=${PATH}:/software/ANTS-2.3.1/bin \
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1

### Add templates for Skull Stripping
ADD \
        Template/MICCAI2012-Multi-Atlas-Challenge-Data \
        /software/ANTS-templates/



###########
### FSL ###
###########
ENV DEBIAN_FRONTEND=noninteractive
# Sometimes the apt-key command results in an error and building the container breaks.
# If you just rerun the build command without removing the images, the build process
# starts where it left off.
# See: https://github.com/docker-library/official-images/issues/4252#issuecomment-381783035
# Solution: http://neuro.debian.net/faq.html (Under 'What means "The following signatures couldn't be verified..."?')
# Replaced:         apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 && \
# ...with: 2nd line below (curl) and third line below (apt-key add)

RUN \
        wget -O- http://neuro.debian.net/lists/bionic.us-ca.full \
        | tee /etc/apt/sources.list.d/neurodebian.sources.list && \
        curl http://neuro.debian.net/_static/neuro.debian.net.asc \
        > /software/neuroDebian.key && \
        apt-key add /software/neuroDebian.key && \
        apt-get update && \
        apt-get install -y fsl-core=5.0.9-5~nd18.04+1

# Configure environment
ENV \
        FSLDIR=/usr/share/fsl/5.0 \
        FSLOUTPUTTYPE=NIFTI_GZ \
        PATH=${PATH}:/usr/lib/fsl/5.0 \
        FSLMULTIFILEQUIT=TRUE \
        POSSUMDIR=/usr/share/fsl/5.0 \
        LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
        FSLWISH=/usr/bin/wish



###########################
### MATLAB + SPM + SUIT ###
###########################
### Matlab Runtime (for SPM+SUIT standalone)
RUN \
        mkdir /software/MCRinstaller && \
        cd /software/MCRinstaller && \
        wget http://ssd.mathworks.com/supportfiles/downloads/R2018a/deployment_files/R2018a/installers/glnxa64/MCR_R2018a_glnxa64_installer.zip && \
        unzip /software/MCRinstaller/MCR_R2018a_glnxa64_installer.zip && \
        /software/MCRinstaller/install -mode silent -agreeToLicense yes -destinationFolder /software/MCR && \
        rm -rf /software/MCRinstaller

ENV \
        LD_LIBRARY_PATH=/software/MCR/v94/runtime/glnxa64:$LD_LIBRARY_PATH \
        LD_LIBRARY_PATH=/software/MCR/v94/bin/glnxa64:$LD_LIBRARY_PATH \
        LD_LIBRARY_PATH=/software/MCR/v94/sys/os/glnxa64:$LD_LIBRARY_PATH

### Include the standalone version of SPM+SUIT
ADD \
        SPM_SUIT \
        /software/SPM

### Add SUIT template, mask, and atlas
ADD \
        Template/SUIT \
        /software/SUIT-templates/

### Add SPM12 segmentation TPM
ADD \
        Template/SPM \
        /software/SPM-templates/



##################
### FreeSurfer ###
##################
### Install FreeSurfer
RUN apt-get -y update && \
        wget -qO- https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz | tar zxv -C /software \
        --exclude='freesurfer/trctrain' \
        --exclude='freesurfer/subjects/fsaverage_sym' \
        --exclude='freesurfer/subjects/fsaverage3' \
        --exclude='freesurfer/subjects/fsaverage4' \
        --exclude='freesurfer/subjects/fsaverage5' \
        --exclude='freesurfer/subjects/fsaverage6' \
        --exclude='freesurfer/subjects/cvs_avg35' \
        --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
        --exclude='freesurfer/subjects/bert' \
        --exclude='freesurfer/subjects/V1_average' \
        --exclude='freesurfer/average/mult-comp-cor' \
        --exclude='freesurfer/lib/cuda' \
        --exclude='freesurfer/lib/qt' && \
        /bin/bash -c 'touch /software/freesurfer/.license'

# Set up the environment
ENV \
        OS=Linux \
        FS_OVERRIDE=0 \
        FIX_VERTEX_AREA= \
        SUBJECTS_DIR=/software/freesurfer/subjects \
        FSF_OUTPUT_FORMAT=nii.gz \
        MNI_DIR=/software/freesurfer/mni \
        LOCAL_DIR=/software/freesurfer/local \
        FREESURFER_HOME=/software/freesurfer \
        FSFAST_HOME=/software/freesurfer/fsfast \
        MINC_BIN_DIR=/software/freesurfer/mni/bin \
        MINC_LIB_DIR=/software/freesurfer/mni/lib \
        MNI_DATAPATH=/software/freesurfer/mni/data \
        FMRI_ANALYSIS_DIR=/software/freesurfer/fsfast \
        PERL5LIB=/software/freesurfer/mni/lib/perl5/5.8.5 \
        MNI_PERL5LIB=/software/freesurfer/mni/lib/perl5/5.8.5 \
        PATH=${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/software/freesurfer/bin:/software/freesurfer/fsfast/bin:/software/freesurfer/tktools:/software/freesurfer/mni/bin



###############
### Scripts ###
###############
RUN apt-get install -y libglu1-mesa python3
RUN apt-get install -y git wget tcsh build-essential gfortran
RUN apt-get install -y libblas-dev liblapack-dev zlib1g-dev
RUN apt-get install -y libxmu-dev libxmu-headers libxi-dev libxt-dev libx11-dev
# libglu1-mesa-dev

# Python packages
RUN \
        apt-get update && \
        apt-get install -y python3-pip

RUN \
        apt-get update && \
        apt-get dist-upgrade -y

RUN \
        pip3 install nipype && \
        pip3 install nibabel && \
        pip3 install nilearn && \
        pip3 install scikit-learn && \
        pip3 install matplotlib && \
        pip3 install ipython && \
        pip3 install scipy && \
        pip3 install svgutils && \
        pip3 install pandas

### Copy over scripts
ADD \
        Scripts/* \
        /software/scripts/

### Set work directory to /software
WORKDIR /software

### Run
ENTRYPOINT ["python3", "/software/scripts/CVET.py"]

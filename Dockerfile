FROM ubuntu:bionic

# CVET Docker image setup 

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
        build-essential \
        cmake \
        curl \
        g++ \
        gfortran \
        git \
        gnupg2 \
        libblas-dev \
        libglu1-mesa \
        liblapack-dev \
        libx11-dev \
        libxi-dev \
        libxmu-dev \
        libxmu-headers \
        libxt-dev \
        python3 \
        python3-pip \
        rs \
        tcsh \
        unzip \
        wget \
        zlib1g \
        zlib1g-dev



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
        mv ${source}/Scripts/* ${binDir}/bin && \
        mv /software/ANTS-2.3.1/bin /software/bin && \
        rm -rf /software/ANTS-2.3.1/* && \
        mv /software/bin /software/ANTS-2.3.1/bin && \
        rm -rf /software/ANTS-source

ENV \
        ANTSPATH=/software/ANTS-2.3.1/bin \
        PATH=${PATH}:/software/ANTS-2.3.1/bin \
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1



###########
### FSL ###
###########
ENV DEBIAN_FRONTEND=noninteractive

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
### Python  ###
###############
RUN \
        pip3 install \
        ipython \
        matplotlib \
        nibabel \
        nilearn \
        nipype \
        pandas \
        scikit-learn \
        scipy \
        svgutils



############################
### Software and Scripts ###
############################
ADD \
        cp2docker/ \
        /software/

### Set work directory to /software and set permissions
WORKDIR /software
RUN \
        find /software -type d -not -path "*freesurfer*" -not -path "*MCR*" | xargs chmod 777 && \
        find /software/scripts | xargs chmod 777 && \
        chmod 777 /



### Run
ENTRYPOINT ["python3", "/software/scripts/CVET.py"]

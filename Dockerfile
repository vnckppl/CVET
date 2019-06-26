FROM ubuntu:bionic

# LAHB Longituindal SUIT Docker image setup 

### Create software and data input and output folders
RUN \
        mkdir -p /software/scripts && \
        mkdir -p /input && \
        mkdir -p /output

### Copy over scripts
ADD Scripts/* /software/scripts/


### Install ANTs
RUN \
        apt-get update && \
        apt-get dist-upgrade -y && \
        apt-get install -y cmake git g++ zlib1g zlib1g-dev wget curl gnupg2 unzip rs

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

ENV ANTSPATH=/software/ANTS-2.3.1/bin
ENV PATH="${PATH}":"${ANTSPATH}"
ENV ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1

### Add templates for Skull Stripping
ADD \
        Template/MICCAI2012-Multi-Atlas-Challenge-Data \
        /sofware/ANTS-templates/

### FSL
ENV DEBIAN_FRONTEND=noninteractive
# Sometimes the apt-key command results in an error and building the container breaks.
# If you just rerun the build command without removing the images, the build process
# starts where it left off.
# See: https://github.com/docker-library/official-images/issues/4252#issuecomment-381783035
# Solution: http://neuro.debian.net/faq.html (Under 'What means "The following signatures couldn't be verified..."?')
# Replaced:         apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 && \
# ...with: 2nd line below (curl) and third line below (apt-key add)

RUN \
        wget -O- http://neuro.debian.net/lists/bionic.us-ca.full | tee /etc/apt/sources.list.d/neurodebian.sources.list && \
        curl http://neuro.debian.net/_static/neuro.debian.net.asc > /software/neuroDebian.key && \
        apt-key add /software/neuroDebian.key && \
        apt-get update && \
        apt-get install -y fsl-core=5.0.9-5~nd18.04+1

# Configure environment
ENV FSLDIR=/usr/share/fsl/5.0
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=/usr/lib/fsl/5.0:$PATH
ENV FSLMULTIFILEQUIT=TRUE
ENV POSSUMDIR=/usr/share/fsl/5.0
ENV LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH
ENV FSLWISH=/usr/bin/wish


### Matlab Runtime (for SPM+SUIT standalone)
WORKDIR /software/MCRinstaller
RUN \
        wget http://ssd.mathworks.com/supportfiles/downloads/R2018a/deployment_files/R2018a/installers/glnxa64/MCR_R2018a_glnxa64_installer.zip && \
        unzip /software/MCRinstaller/MCR_R2018a_glnxa64_installer.zip && \
        /software/MCRinstaller/install -mode silent -agreeToLicense yes -destinationFolder /software/MCR && \
        rm -rf /software/MCRinstaller

ENV LD_LIBRARY_PATH=/software/MCR/v94/runtime/glnxa64:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=/software/MCR/v94/bin/glnxa64:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=/software/MCR/v94/sys/os/glnxa64:$LD_LIBRARY_PATH

### Include the standalone version of SPM+SUIT
ADD SPM_SUIT /software/SPM


### Run
CMD ["/bin/bash"]

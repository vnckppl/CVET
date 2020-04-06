#!/bin/bash

# 2020-04-06

# Build Docker image using docker setup file

# * Environment
version="1.29"
DIR="/Users/vincent/Data/Documents/Utah/Kladblok/20171002_Neuroimaging/20190831_CVET/20190521_CVET"
cd ${DIR}


# * Announce
echo "CVET v${version}"


# * Build Docker
read -p "Do you want to build this docker (y/n)? " ANS

if [ ${ANS} = "y" ]; then
time(
    docker \
    build \
    -t vkoppelm/cvet:v${version} \
    . \
    -f ${DIR}/Dockerfile \
    --cpuset-cpus 3
)
fi


# * Export Docker
echo
read -p "Do you want to export this docker container (y/n)? " ANS

if [ ${ANS} = "y" ]; then
    time(
        docker \
            save vkoppelm/cvet:v${version} \
            > ~/Data/tmp/CVET_v${version}.tar
    )
fi


exit



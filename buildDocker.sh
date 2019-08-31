#!/bin/bash

# 2019-08-31

# Build Docker image using docker setup file
DIR="/Users/vincent/Data/Documents/Utah/Kladblok/20171002_Neuroimaging/20190831_CVET/20190521_CVET"
cd ${DIR}

docker \
    build \
    -t vkoppelm/cvet:v1.23 \
    . \
    -f ${DIR}/Dockerfile \
    --cpuset-cpus 3

exit



#!/bin/bash

# 2019-09-12

# Build Docker image using docker setup file
DIR="/Users/vincent/Data/Documents/Utah/Kladblok/20171002_Neuroimaging/20190831_CVET/20190521_CVET"
cd ${DIR}

docker \
    build \
    -t vkoppelm/cvet:v1.25 \
    . \
    -f ${DIR}/Dockerfile \
    --cpuset-cpus 3

exit



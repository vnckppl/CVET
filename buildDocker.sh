#!/bin/bash

# 2019-06-24

# Build Docker image using docker setup file
DIR="/Users/vincent/Data/Documents/Utah/Kladblok/20190521_Zurich/20190521_Pipeline/Scripts"
cd ${DIR}

docker \
    build \
    -t vkoppelm/cvet:lhab_v1.1 \
    . \
    -f ${DIR}/Dockerfile \
    --cpuset-cpus 3

exit



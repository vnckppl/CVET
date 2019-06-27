#!/bin/bash

# ANTs normalization: Calculate Warp:
# Subject Cerebellum Template to SUIT Template
echo "--> ANTs calculate warp from Subject Template to SUIT"
oDIR="/path/to/location/for/warp/parameters"
cd "${oDIR}"

tmpl1mm=/path/to/suit/template.nii
subTemp=/path/to/subjectCerebellumTemplate.nii.gz

antsRegistration  \
-d 3  \
-r [ ${tmpl1mm}, ${subTemp} ,1]  \
-m mattes[  ${tmpl1mm}, ${subTemp} , 1 , 32, regular, 0.3 ]  \
-t translation[ 0.1 ]  \
-c [10000x111110x11110,1.e-8,20]  \
-s 4x2x1vox  \
-f 6x4x2 -l 1  \
-m mattes[ ${tmpl1mm}, ${subTemp} , 1 , 32, regular, 0.3 ]  \
-t rigid[ 0.1 ]  \
-c [10000x111110x11110,1.e-8,20]  \
-s 4x2x1vox  \
-f 3x2x1 -l 1  \
-m mattes[ ${tmpl1mm}, ${subTemp} , 1 , 32, regular, 0.3 ]  \
-t affine[ 0.1 ]  \
-c [10000x111110x11110,1.e-8,20]  \
-s 4x2x1vox  \
-f 3x2x1 -l 1  \
-m mattes[ ${tmpl1mm}, ${subTemp} , 0.5 , 32 ]  \
-m cc[ ${tmpl1mm}, ${subTemp} , 0.5 , 4 ]  \
-t SyN[ .20, 3, 0 ]  \
-c [ 100x100x50,-0.01,5 ]  \
-s 1x0.5x0vox  \
-f 4x2x1 -l 1 -u 1 -z 1  \
-o [ants_,ants_warped.nii.gz,ants_inv.nii.gz]  \
-v 1


# ANTs normalization: Apply Warp (Subject Template to SUIT Template)
echo "--> ANTs apply warp to bring the Subject Template into SUIT space"
antsApplyTransforms \
-d 3 \
-e 3 \
-i <<< Subject Cerebellum Template .nii.gz >>> \
-r ${tmpl1mm} \
-n linear \
-t ${oDIR}/ants_1Warp.nii.gz \
-t ${oDIR}/ants_0GenericAffine.mat \
-o <<< Output File .nii.gz >>>  \
-v 1

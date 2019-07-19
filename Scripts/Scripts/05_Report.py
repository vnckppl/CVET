#! /usr/bin/env python3

# Libraries
import sys
import argparse
import os
import datetime
from glob import glob
from nipype.interfaces import fsl
from nipype.interfaces.freesurfer import MRIConvert
import nibabel as nb
import nilearn
from nilearn import plotting



# Input arguments
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Cerebellar Volume Extraction Tool. Create quality '
        'control reports. ')

    parser.add_argument('--SID',
                        help='Subject ID',
                        required=True)

args = parser.parse_args()
SID=args.SID


# Date for logging
now = datetime.datetime.now()
now = now.isoformat()

# Logging
message = f"""
##############################################################
### Cerebellar Volume Extraction Tool (CVET)               ###
### PART 5: Report for Quality Control                     ###
### Start date and time: {now}        ###
### Subject: {SID}                                     ###
##############################################################

"""
print(message)

# Environment
# iDIR2='/data/out/02_Template/sub-'+SID
# iDIR22=iDIR2+'/02_SubjectTemplate'
# iDIR23=iDIR2+'/03_SUITTemplate'
# iDIR3='/data/out/03_Segment/sub-'+SID
# iDIR4='/data/out/04_ApplyWarp/sub-'+SID
# oDIR='/data/out/05_Report/sub-'+SID
# os.makedirs(oDIR, exist_ok=True)
# tDIR='/software/SUIT-templates'


iDIR2='/Users/vincent/Data/tmp/20190625_N4test/derivatives/CVET/02_Template/sub-'+SID
iDIR22=iDIR2+'/02_SubjectTemplate'
iDIR23=iDIR2+'/03_SUITTemplate'
iDIR3='/Users/vincent/Data/tmp/20190625_N4test/derivatives/CVET/03_Segment/sub-'+SID
iDIR4='/Users/vincent/Data/tmp/20190625_N4test/derivatives/CVET/04_ApplyWarp/sub-'+SID
oDIR='/Users/vincent/Data/tmp/20190625_N4test/derivatives/CVET/05_Report/sub-'+SID
os.makedirs(oDIR, exist_ok=True)
tDIR="/Users/vincent/Data/tmp/SPM12StandaloneWithSUIT/spm12/toolbox/suit/atlas"

# List of sessions
SESLIST=sorted(glob(iDIR4+'/*'))
SESLIST=[i.split('ses-',1)[1] for i in SESLIST]




# Prepare images for display
message = f"""
##############################################################
### Prepare images for display                             ###
##############################################################

"""
print(message)

for SES in SESLIST:
    
    # Set output folder
    oDIRc=oDIR+'/ses-'+SES
    os.makedirs(oDIRc, exist_ok=True)
    
    # Reortient cerebellar to standard space
    print("Reorient cerebellar mask to standard space")
    iFile=glob(iDIR4+'/ses-'+SES+'/cMask*.nii.gz')
    oFile=oDIRc+'/cMask.nii.gz'
    
    myObject = fsl.Reorient2Std()
    myObject.inputs.in_file = iFile[0]
    myObject.inputs.out_file = oFile
    results = myObject.run()
    
    # Dilate cerebellar mask twice to make sure the entire 
    # cerebellum will be covered in the screenshots
    print("Dilate cerebellar mask")
    iFile=oDIRc+'/cMask.nii.gz'
    oFile=oDIRc+'/cMask_dilM2.nii.gz'
    
    myObject = fsl.ImageMaths(
        in_file=iFile,
        op_string= '-dilM -dilM',
        out_file=oFile
    )
    results = myObject.run()
    
    # Crop the dilated cerebellar mask for display
    print("Crop cerebellar mask to mask borders")
    
    iFile=oDIRc+'/cMask_dilM2.nii.gz'
    oFile=oDIRc+'/ccMask_dilM2.nii.gz'
    
    myObject = fsl.ImageStats(
        in_file=iFile,
        op_string='-w',
        terminal_output='allatonce'
    )
    
    results = myObject.run()
    # Store parameters
    cropParameters=results.outputs.out_stat
    # Convert to integers
    cp = [round(x) for x in cropParameters]
    
    # fslroi
    myObject = fsl.ExtractROI(
        in_file=iFile,
        x_min=cp[0],
        x_size=cp[1],
        y_min=cp[2],
        y_size=cp[3],
        z_min=cp[4],
        z_size=cp[5],
        t_min=cp[6],
        t_size=cp[7],
        roi_file=oFile
    )
    
    results = myObject.run()    
    
    # Reslice other images like the cropped image to match its dimensions
    Ifiles=[
        iDIR3+'/ses-'+SES+'/sub-'+SID+'_ses-'+SES+'_rawavg_N4.nii.gz',
        iDIR4+'/ses-'+SES+'/cgm.nii.gz',
        iDIR4+'/ses-'+SES+'/c_atlasNativeSpace.nii.gz'
    ]
    
    Ofiles=[
        oDIRc+'/T1.nii.gz',
        oDIRc+'/gm.nii.gz',
        oDIRc+'/atlas.nii.gz'
    ]
    
    for file in range(len(Ifiles)):
        
        # Announce
        print('Reslice: '+Ifiles[file])
        # Reslice
        myObject = MRIConvert()
        myObject.inputs.in_file=Ifiles[file]
        myObject.inputs.out_file=Ofiles[file]
        myObject.inputs.reslice_like=oDIRc+'/ccMask_dilM2.nii.gz'
        
        results = myObject.run()



# Create overview of GM map for each subject/session
message = f"""
##############################################################
### Create overview of GM segmentation                     ###
##############################################################

"""
print(message)


# Set number of slices to display per plane
nX=7
nY=5
nZ=5

# Loop over all sessions
for SES in SESLIST:

    # Announce
    print('------------------- Working on session: '+SES)
    
    # Set output folder
    oDIRc=oDIR+'/ses-'+SES
    
    # Get image dimensions of T1 image
    T1=nb.load(oDIRc+'/T1.nii.gz')
    
    # Calculate the cut points for the screenshots
    cut_distance_X=T1.shape[0] / (nX + 1)
    cut_distance_Y=T1.shape[1] / (nY + 1)
    cut_distance_Z=T1.shape[2] / (nZ + 1)
    
    # Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1,nX+1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1,nY+1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1,nZ+1)]
    
    # Convert these image coordinates to mm coordinates
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, T1.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, T1.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, T1.affine)[2] for x in cutpoints_Z]
    
    # Create screenshots
    for plane in ['X','Y','Z']:

        # Announce
        print('--------------------------------------- PLANE: '+plane)
        
        # T1 image
        print('--------------------------------------- T1 image')
        nilearn.plotting.plot_img(
            T1, 
            display_mode=plane.lower(),
            cut_coords= eval('cutpoints_'+plane+'_mm'),
            cmap='gray',
            output_file=oDIRc+'/T1_'+plane+'.svg'
        )
        
        # Gray matter map
        print('--------------------------------------- Gray Matter map')
        GMimg=nb.load(oDIRc+'/gm.nii.gz')
        
        plotting.plot_stat_map(
            GMimg, 
            bg_img=T1, 
            display_mode=plane.lower(),
            cut_coords= eval('cutpoints_'+plane+'_mm'),
            threshold=0.05,
            alpha=0.5,
            output_file=oDIRc+'/GM_'+plane+'.svg'
        )
        
        # SUIT altas
        print('--------------------------------------- SUIT Atlas')
        atlas=nb.load(oDIRc+'/atlas.nii.gz')
        
        for alpha in [0.0, 0.3, 0.7]:
            plotting.plot_roi(
                atlas, 
                bg_img=T1, 
                display_mode=plane.lower(),
                cut_coords= eval('cutpoints_'+plane+'_mm'),
                alpha=alpha,
                output_file=oDIRc+'/SUIT_'+plane+'_'+str(alpha)+'_.svg'
            )



# Create overview of the subject template 
message = f"""
##############################################################
### Create overview of the Suject Template                 ###
##############################################################

"""
print(message)

# Template creation (only if there is more than one time point)
if len(SESLIST) > 1:

    # Create output folder
    oDIRt=oDIR+'/template'
    os.makedirs(oDIRt, exist_ok=True)
    
    # Get image dimensions of Subject Template image
    ST=nb.load(iDIR22+'/T_template0.nii.gz')
    
    # Calculate the cut points for the screenshots
    cut_distance_X=ST.shape[0] / (nX + 1)
    cut_distance_Y=ST.shape[1] / (nY + 1)
    cut_distance_Z=ST.shape[2] / (nZ + 1)
    print(cut_distance_X)
    print(cut_distance_Y)
    print(cut_distance_Z)
    
    # Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1,nX+1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1,nY+1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1,nZ+1)]
    print(cutpoints_X)
    print(cutpoints_Y)
    print(cutpoints_Z)
    
    # Convert these image coordinates to mm coordinates
    
    #<<< Hier zit een probleem met de affine matrix. Die zet voor de Y en Z planes de
    #<<< coordinaten niet goed om van voxel naar RAS.
    #<<< Eventueel een andere tool (FSL?) hiervoor gebruiken?
    
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, ST.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, ST.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, ST.affine)[2] for x in cutpoints_Z]
    print(cutpoints_X_mm)
    print(cutpoints_Y_mm)
    print(cutpoints_Z_mm)
    
    # Create list of ST image and all time point images
    myList = [iDIR22+'/T_template0.nii.gz']
    myFname = ['Template']
    for SES in SESLIST:
        myList.append(glob(iDIR22+'/T_template0sub-'+SID+'_ses-'+SES+'_ccereb*WarpedToTemplate.nii.gz')[0])
        myFname.append(SES)
        
    print(myList)
    
    # Loop over images in list
    for i in range(len(myList)):
        
        # Announce
        print('--------------------------------------- Template: '+str(myFname[i]))
        
        # Create screenshots
        for plane in ['X','Y','Z']:
            
            # Announce
            print('--------------------------------------- PLANE: '+plane)
            fileToPlot=nb.load(str(myList[i]))
            
            print(oDIRt+'/T_'+str(myFname[i])+'_'+plane+'.svg')
            
            # Plot image
            nilearn.plotting.plot_img(
                fileToPlot, 
                display_mode=plane.lower(),
                cut_coords= eval('cutpoints_'+plane+'_mm'),
                cmap='gray',
                output_file=oDIRt+'/T_'+str(myFname[i])+'_'+plane+'.svg'
            )
            
else:
    print("Single session, no subject template was created")


# Normalization from subject template to SUIT
message = f"""
##############################################################
### Create overview of template normalization to SUIT      ###
##############################################################

"""
print(message)

# Loop over all sessions
for SES in SESLIST:

    # Announce
    print('------------------- Working on session: '+SES)
    
    # Set output folder
    oDIRc=oDIR+'/ses-'+SES
    
    # Get image dimensions of T1 image
    SUIT=nb.load(tDIR+'/SUIT.nii')
    
    # Calculate the cut points for the screenshots
    cut_distance_X=SUIT.shape[0] / (nX + 1)
    cut_distance_Y=SUIT.shape[1] / (nY + 1)
    cut_distance_Z=SUIT.shape[2] / (nZ + 1)
    
    # Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1,nX+1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1,nY+1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1,nZ+1)]
    
    # Convert these image coordinates to mm coordinates
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, SUIT.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, SUIT.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, SUIT.affine)[2] for x in cutpoints_Z]
    
    # Create screenshots
    for plane in ['X','Y','Z']:
        
        # Announce
        print('--------------------------------------- PLANE: '+plane)
        
        # SUIT Template
        print('--------------------------------------- T1 SUIT Template')
        nilearn.plotting.plot_img(
            SUIT, 
            display_mode=plane.lower(),
            cut_coords= eval('cutpoints_'+plane+'_mm'),
            cmap='gray',
            output_file=oDIRc+'/SUIT_'+plane+'.svg'
        )
        
        # Subject Template normalized to SUIT space
        print('--------------------------------------- Subject Template to SUIT Template')
        SUB2SUIT=nb.load(iDIR23+'/ants_warped.nii.gz')
        
        nilearn.plotting.plot_img(
            SUB2SUIT, 
            display_mode=plane.lower(),
            cut_coords= eval('cutpoints_'+plane+'_mm'),
            cmap='gray',
            output_file=oDIRc+'/Sub2SUIT_'+plane+'.svg'
        )

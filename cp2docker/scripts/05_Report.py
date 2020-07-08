#! /usr/bin/env python3

# * Libraries
import argparse
import os
import datetime
from glob import glob
from nipype.interfaces import fsl
from nipype.interfaces.freesurfer import MRIConvert
import nibabel as nb
import nilearn
from nilearn import plotting
import svgutils.compose as sc
import re
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np


# * Input arguments
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Cerebellar Volume Extraction Tool. Create quality '
        'control reports. ')

    parser.add_argument('--SID',
                        help='Subject ID',
                        required=True)

args = parser.parse_args()
SID = args.SID


# * Function to compile two svg images into animations
def compileSVG(DIR, svg1, svg2, outSVG):

    # ** Open the top svg image and remove svg tag from text file
    with open(svg2, 'r') as f:
        lines = f.read().splitlines()

        # *** Everything but last line
        myLines = lines[:-1]

        # Remove black background from image
        # All lines between    <g id="patch_1">
        #                      <g id="axes_2">
        # Find line number of lines
        for line in range(0, len(myLines)):

            # Test if a line contains the string ' <g id="patch_1">'
            # If so, store this line number
            regex = re.compile('  <g id="patch_1">')
            if re.match(regex, myLines[line]):
                start = line

            # Test if a line contains the string ' <g id="axes_2">'
            # If so, store this line number
            regex = re.compile('  <g id="axes_2">')
            if re.match(regex, myLines[line]):
                stop = line

        # *** Remove the lines between start and stop
        myLines = myLines[:start] + myLines[stop:]

        # *** Extract image dimensions
        regex = re.compile('<svg height')
        matches = [string for string in myLines if re.match(regex, string)]
        myParameters = str(matches).split(' ')
        # *** Height
        regex = re.compile('height')
        height = [string for string in myParameters if re.match(regex, string)]
        height = str(height).split('"')[1]
        # *** Width
        regex = re.compile('width')
        width = [string for string in myParameters if re.match(regex, string)]
        width = str(width).split('"')[1]

        # *** Convert this list back to a string with new lines
        myStringLines = ""
        for line in myLines:
            myStringLines = myStringLines + str(line) + "\n"

    # ** Open the top svg image and create an animations svg snippet for each png in the file
    with open(svg2, 'r') as f:
        # *** Create list from 'words' separated by a space
        content = f.read()
        myList = content.split(" ")

        # *** Find all image IDs
        regex = re.compile('id="image')
        matches = [string for string in myList if re.match(regex, string)]
        matches

        # *** Create new strings with animation information in svg format
        for match in matches:

            myString = f"""

            <animate href="#{match[4:]}
                     attributeName="opacity"
                     values="0;0;1;1;0" dur="5s"
                     repeatCount="indefinite"
                     />"
            """

            # **** Append string to svg image
            myStringLines = myStringLines + myString

        # *** Add closing svg tag
        myStringLines = myStringLines + '</svg>'

    # # ** Fix image width
    # # For these compiled images, extra whitespace is added
    # # because there are lines that reference columns outside
    # # the original image. Filter these lines out here.
    # #  Strings to List
    # myListLines = myStringLines.split('\n')
    # #  Remove lines where x (width) references
    # # x > image width
    # myListLines = [i for i in myListLines if '<use x="' not in i or float(i.split('"')[1]) < float(width.replace("pt", ""))]
    # # Convert list back to string
    # myStringLines = '\n'.join(myListLines)

    # ** Save to file
    tmpSVG = DIR + '/tmp.svg'
    with open(tmpSVG, "w") as text_file:
        text_file.write(str(myStringLines))

    # ** Combine images
    sc.Figure(width,
              height,
              sc.Panel(sc.SVG(svg1)),
              sc.Panel(sc.SVG(tmpSVG))
              ).save(outSVG)

    # ** Clean up
    os.remove(tmpSVG)


# * Date for logging
now = datetime.datetime.now()
now = now.isoformat()

# * Logging
message = f"""
##############################################################
### Cerebellar Volume Extraction Tool (CVET)               ###
### PART 5: Report for Quality Control                     ###
### Start date and time: {now}        ###
### Subject: {SID}                                     ###
##############################################################

"""
print(message)

# * Environment
iDIR2 = '/data/out/02_Template/sub-' + SID
iDIR22 = iDIR2 + '/02_SubjectTemplate'
iDIR23 = iDIR2 + '/03_SUITTemplate'
iDIR3 = '/data/out/03_Segment/sub-' + SID
iDIR4 = '/data/out/04_ApplyWarp/sub-' + SID
oDIR = '/data/out/05_Report/sub-' + SID
os.makedirs(oDIR, exist_ok=True)
tDIR = '/software/SUIT-templates'


# * List of sessions
SESLIST = sorted(glob(iDIR4 + '/*'))
SESLIST = [i.split('ses-', 1)[1] for i in SESLIST]


# * Prepare images for display
message = f"""
##############################################################
### Prepare images for display                             ###
##############################################################

"""
print(message)

for SES in SESLIST:

    # ** Set output folder
    oDIRc = oDIR + '/ses-' + SES
    os.makedirs(oDIRc, exist_ok=True)

    # ** Reortient cerebellar to standard space
    print("Reorient cerebellar mask to standard space")
    iFile = glob(iDIR4 + '/ses-' + SES + '/cMask*.nii.gz')
    oFile = oDIRc + '/cMask.nii.gz'

    myObject = fsl.Reorient2Std()
    myObject.inputs.in_file = iFile[0]
    myObject.inputs.out_file = oFile
    results = myObject.run()

    # Dilate cerebellar mask twice to make sure the entire
    # cerebellum will be covered in the screenshots
    print("Dilate cerebellar mask")
    iFile = oDIRc + '/cMask.nii.gz'
    oFile = oDIRc + '/cMask_dilM2.nii.gz'

    myObject = fsl.ImageMaths(
        in_file=iFile,
        op_string='-dilM -dilM',
        out_file=oFile
    )
    results = myObject.run()

    # ** Crop the dilated cerebellar mask for display
    print("Crop cerebellar mask to mask borders")

    iFile = oDIRc + '/cMask_dilM2.nii.gz'
    oFile = oDIRc + '/ccMask_dilM2.nii.gz'

    myObject = fsl.ImageStats(
        in_file=iFile,
        op_string='-w',
        terminal_output='allatonce'
    )

    results = myObject.run()
    # ** Store parameters
    cropParameters = results.outputs.out_stat
    # ** Convert to integers
    cp = [round(x) for x in cropParameters]

    # ** fslroi
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

    # ** Reslice other images like the cropped image to match its dimensions
    Ifiles = [
        iDIR3 + '/ses-' + SES + '/sub-' + SID + '_ses-' + SES + '_rawavg_N4.nii.gz',
        iDIR4 + '/ses-' + SES + '/cgm.nii.gz',
        iDIR4 + '/ses-' + SES + '/c_atlasNativeSpace.nii.gz'
    ]

    Ofiles = [
        oDIRc + '/T1.nii.gz',
        oDIRc + '/gm.nii.gz',
        oDIRc + '/atlas.nii.gz'
    ]

    for file in range(len(Ifiles)):

        # ** Announce
        print('Reslice: ' + Ifiles[file])
        # ** Reslice
        myObject = MRIConvert()
        myObject.inputs.in_file = Ifiles[file]
        myObject.inputs.out_file = Ofiles[file]
        myObject.inputs.reslice_like = oDIRc + '/ccMask_dilM2.nii.gz'
        results = myObject.run()

    # Mask the atlas file with the binarized GM image and visa versa
    # Load data
    gm_image = nb.load(oDIRc + '/gm.nii.gz')
    gm_data = gm_image.get_fdata()
    atlas_image = nb.load(oDIRc + '/atlas.nii.gz')
    atlas_data = atlas_image.get_fdata()
    # Binarize
    gm_data_bin = (gm_data > 0).astype(np.int_)
    atlas_data_bin = (atlas_data > 0).astype(np.int_)
    # Mask
    gm_masked = np.multiply(gm_data, atlas_data_bin)
    atlas_masked = np.multiply(atlas_data, gm_data_bin)
    # Save
    gm_array = nb.Nifti1Image(gm_masked, gm_image.affine)
    nb.save(gm_array, oDIRc + '/gm.nii.gz')
    atlas_array = nb.Nifti1Image(atlas_masked, atlas_image.affine)
    nb.save(atlas_array, oDIRc + '/atlas.nii.gz')

    # ** Create 4D file from the atlas image for outline display
    # Split atlas image
    for i in range(1, 29):
        izp = str(i).zfill(2)
        myObject = fsl.ImageMaths(
            in_file=oDIRc + "/atlas.nii.gz",
            op_string=f''' -thr {i} -uthr {i} ''',
            out_file=oDIRc + '/lobule_' + izp + '.nii.gz'
        )
        results = myObject.run()
    # Merge atlas images
    lobule_files = sorted(glob(oDIRc + '/lobule*.nii.gz'))
    myObject = fsl.Merge()
    myObject.inputs.in_files = lobule_files
    myObject.inputs.dimension = 't'
    myObject.inputs.output_type = 'NIFTI_GZ'
    myObject.inputs.merged_file = (oDIRc + '/atlas_4D.nii.gz')
    results = myObject.run()
    # Remove intermediate files
    for i in range(1, 29):
        izp = str(i).zfill(2)
        file = oDIRc + '/lobule_' + izp + '.nii.gz'
        os.remove(file)


# * Create overview of GM map for each subject/session
message = f"""
##############################################################
### Create overview of GM segmentation                     ###
##############################################################

"""
print(message)

# * HTML Header
html = f"""
<!DOCTYPE html>
<html>
  <head>
    <style>
      body, html {{
          font-family: 'Open Sans', sans-serif;
          padding: 3px;
      }}
      h1 {{
          font-weight: 400;
          font-size: 42px;
          color: #414a52;
      }}
      h2 {{
          margin: 0 0 20px 0;
          font-weight: 400;
          font-size: 30px;
          color: #0871dc;
      }}
      .img {{
          margin: 0px;
          padding: 0%;
          padding-bottom: -20px;
          width: auto;
          max-width: 100%
      }}
      .imgbox {{
          resize: both;
          overflow: auto;
          <!-- margin-bottom: -20px; -->
      }}
    </style>
    <title>CVET {SID}</title>
  </head>
  <body>
    <h1><b>CVET Report for Subject {SID}</b></h1>
"""

# * Set number of slices to display per plane
nX = 7
nY = 7
nZ = 7

# * Loop over all sessions
for SES in SESLIST:

    # ** Announce
    print('------------------- Working on session: ' + SES)

    # ** Export session name to HTML
    html = html + f"""
    <h1>Session: {SES}</h1>
    """
    # ** Set output folder
    oDIRc = oDIR + '/ses-' + SES

    # ** Get image dimensions of T1 image
    T1 = nb.load(oDIRc + '/T1.nii.gz')
    # Contour fix
    # remove the affine matrix because this currently results in
    # errors with nilearn.
    T1_noAffine = nb.load(oDIRc + '/T1.nii.gz')
    T1_noAffine.set_sform(T1_noAffine.affine * np.identity(4))

    # ** Calculate the cut points for the screenshots
    cut_distance_X = T1.shape[0] / (nX + 1)
    cut_distance_Y = T1.shape[1] / (nY + 1)
    cut_distance_Z = T1.shape[2] / (nZ + 1)

    # ** Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1, nX + 1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1, nY + 1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1, nZ + 1)]

    # ** Convert these image coordinates to mm coordinates
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, T1.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, T1.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, T1.affine)[2] for x in cutpoints_Z]

    # ** Create screenshots
    for plane in ['X', 'Y', 'Z']:

        # *** Announce
        print('--------------------------------------- PLANE: ' + plane)

        # *** T1 image
        print('--------------------------------------- T1 image')
        nilearn.plotting.plot_anat(
            T1,
            display_mode=plane.lower(),
            cut_coords=eval('cutpoints_' + plane + '_mm'),
            cmap='gray',
            dim=-1,
            output_file=oDIRc + '/T1_' + plane + '.svg'
        )

        # *** FreeSurfer Cerebellum Mask
        print('--------------------------------------- FreeSurfer Cerebellum Mask outline')
        CMask = nb.load(oDIRc + '/cMask.nii.gz')
        display = plotting.plot_anat(T1, display_mode=plane.lower(), dim=-1)
        display.add_contours(CMask, levels=[0.5], colors='r')
        output_file = oDIRc + '/Mask_' + plane + '.svg'
        display.savefig(output_file)

        # *** Gray matter map
        print('--------------------------------------- Gray Matter map')
        GMimg = nb.load(oDIRc + '/gm.nii.gz')

        for alpha in [0.0, 1.0]:
            plotting.plot_stat_map(
                GMimg,
                bg_img=T1,
                display_mode=plane.lower(),
                cut_coords=eval('cutpoints_' + plane + '_mm'),
                threshold=0.05,
                alpha=alpha,
                dim=-1,
                output_file=oDIRc + '/GM_' + plane + '_' + str(alpha) + '.svg'
            )

        # *** Create GM animation
        svg1 = oDIRc + '/GM_' + plane + '_0.0.svg'
        svg2 = oDIRc + '/GM_' + plane + '_1.0.svg'
        outSVG = oDIRc + '/GM_' + plane + '.svg'
        compileSVG(oDIR, svg1, svg2, outSVG)

        # *** Clean up
        os.remove(svg1)
        os.remove(svg2)

        # *** SUIT atlas Animation
        print('--------------------------------------- SUIT Atlas (animation)')
        atlas = nb.load(oDIRc + '/atlas.nii.gz')

        for alpha in [0.0, 1.0]:
            plotting.plot_roi(
                atlas,
                bg_img=T1,
                display_mode=plane.lower(),
                cut_coords=eval('cutpoints_' + plane + '_mm'),
                alpha=alpha,
                dim=-1,
                output_file=oDIRc + '/SUIT_atlas_' + plane + '_' + str(alpha) + '.svg',
            )

        # *** Create SUIT animation
        svg1 = oDIRc + '/SUIT_atlas_' + plane + '_0.0.svg'
        svg2 = oDIRc + '/SUIT_atlas_' + plane + '_1.0.svg'
        outSVG = oDIRc + '/SUIT_atlas_' + plane + '.svg'
        compileSVG(oDIR, svg1, svg2, outSVG)

        # *** Clean up
        os.remove(svg1)
        os.remove(svg2)

        # *** SUIT atlas static contours
        print('--------------------------------------- SUIT Atlas (contours)')
        atlas = nb.load(oDIRc + '/atlas_4D.nii.gz')
        atlas.set_sform(atlas.affine * np.identity(4))
        display = plotting.plot_prob_atlas(atlas, bg_img=T1_noAffine, dim=-1, linewidths=0.5, alpha=1, display_mode=plane.lower(),)
        output_file = oDIRc + '/SUIT_contour_' + plane + '.svg'
        display.savefig(output_file)

    # ** Add Screenshots to HTML: T1 images
    html = html + f"""
    <h2>T1 overview</h2>
    <div class="imgbox">
    """
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/T1_{plane}.svg">
        """
    html = html + f"""
    </div>
    """
    # ** Add Screenshots to HTML: FreeSurfer Cerebellum mask
    html = html + f"""
    <h2>Cerebellum mask</h2>
    <div class="imgbox">
    """
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/Mask_{plane}.svg">
        """
    html = html + f"""
    </div>
    """
    # ** Add Screenshots to HTML: GM overlay images
    html = html + f"""
    <h2>GM overlay</h2>
    <div class="imgbox">
    """
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/GM_{plane}.svg">
        """
    html = html + f"""
    </div>
    """
    # ** Add Screenshots to HTML: SUIT atlas overlay images - Animation
    html = html + f"""
    <h2>SUIT atlas parcellation</h2>
    <div class="imgbox">
    """
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/SUIT_atlas_{plane}.svg">
        """
    html = html + f"""
    </div>
    """
    # ** Add Screenshots to HTML: SUIT atlas overlay images - Contour
    html = html + f"""
    <div class="imgbox">
    """
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/SUIT_contour_{plane}.svg">
        """
    html = html + f"""
    </div>
    """

# * Create overview of the subject template
message = f"""
##############################################################
### Create overview of the Subject Template                ###
##############################################################

"""
print(message)

# * Template creation
# (only if there is more than one time point)
if len(SESLIST) > 1:

    # ** Export to HTML
    html = html + f"""
    <h1>Subject Template</h1>
    """

    # ** Create output folder
    oDIRt = oDIR + '/template'
    os.makedirs(oDIRt, exist_ok=True)

    # ** Reorient template image to standard space
    reorient = fsl.Reorient2Std()
    reorient.inputs.in_file = iDIR22 + '/T_template0.nii.gz'
    reorient.inputs.out_file = oDIRt + '/ro_T_template0.nii.gz'
    ro = reorient.run()

    # ** Get image dimensions of Subject Template image
    ST = nb.load(oDIRt + '/ro_T_template0.nii.gz')

    # ** Calculate the cut points for the screenshots
    cut_distance_X = ST.shape[0] / (nX + 1)
    cut_distance_Y = ST.shape[1] / (nY + 1)
    cut_distance_Z = ST.shape[2] / (nZ + 1)
    print(cut_distance_X)
    print(cut_distance_Y)
    print(cut_distance_Z)

    # ** Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1, nX + 1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1, nY + 1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1, nZ + 1)]
    print(cutpoints_X)
    print(cutpoints_Y)
    print(cutpoints_Z)

    # ** Convert these image coordinates to mm coordinates
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, ST.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, ST.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, ST.affine)[2] for x in cutpoints_Z]
    print(cutpoints_X_mm)
    print(cutpoints_Y_mm)
    print(cutpoints_Z_mm)

    # ** Create list of ST image and all time point images
    myList = [iDIR22 + '/T_template0.nii.gz']
    myFname = ['Template']
    for SES in SESLIST:
        myList.append(glob(iDIR22 + '/T_template0sub-' + SID + '_ses-' + SES + '_ccereb*WarpedToTemplate.nii.gz')[0])
        myFname.append(SES)

    print(myList)

    # ** Loop over images in list
    for i in range(len(myList)):

        # *** Announce
        print('--------------------------------------- Template: ' + str(myFname[i]))

        # *** Export to HTML
        TP = str(myFname[i])
        if i > 0:
            html = html + f"""
            <h2>Session {TP} to Subject Template</h2>
            <div class="imgbox">
            """

        # *** Create screenshots
        for plane in ['X', 'Y', 'Z']:

            # **** Announce
            print('--------------------------------------- PLANE: ' + plane)
            fileToPlot = nb.load(str(myList[i]))

            print(oDIRt + '/T_' + str(myFname[i]) + '_' + plane + '.svg')

            # **** Plot image
            nilearn.plotting.plot_img(
                fileToPlot,
                display_mode=plane.lower(),
                cut_coords=eval('cutpoints_' + plane + '_mm'),
                cmap='gray',
                output_file=oDIRt + '/T_' + str(myFname[i]) + '_' + plane + '.svg',
                title='Session: ' + myFname[i] + '                '
            )

            # **** Create animations
            if i > 0:

                # ***** Combine images
                svg1 = oDIRt + '/T_Template_' + plane + '.svg'
                svg2 = oDIRt + '/T_' + str(myFname[i]) + '_' + plane + '.svg'
                outSVG = oDIRt + '/T_' + str(myFname[i]) + '_' + plane + '.svg'
                compileSVG(oDIR, svg1, svg2, outSVG)

                # ***** Clean up
                # os.remove(svg2)

        # *** Export to HTML
        if i > 0:
            for plane in ['X', 'Y', 'Z']:
                html = html + f"""
                <img class="img" src="./template/T_{TP}_{plane}.svg">
                """
            html = html + f"""
            </div>
            """
else:
    print("Single session, no subject template was created")


# * Normalization from subject template to SUIT
message = f"""
##############################################################
### Create overview of template normalization to SUIT      ###
##############################################################

"""
print(message)

# * Export to HTML
html = html + f"""
<h1>Normalization from Subject Session Space via Subject Template Space to SUIT Space</h1>
"""

# * Loop over all sessions
for SES in SESLIST:

    # ** Announce
    print('------------------- Working on session: ' + SES)

    # ** Export to HTML
    html = html + f"""
    <h2>Session: {SES}</h2>
    <div class="imgbox">
    """

    # ** Set output folder
    oDIRc = oDIR + '/ses-' + SES

    # ** Get image dimensions of T1 image
    SUIT = nb.load(tDIR + '/SUIT.nii.gz')

    # ** Calculate the cut points for the screenshots
    cut_distance_X = SUIT.shape[0] / (nX + 1)
    cut_distance_Y = SUIT.shape[1] / (nY + 1)
    cut_distance_Z = SUIT.shape[2] / (nZ + 1)

    # ** Convert the cut distances to a list of cut points
    cutpoints_X = [cut_distance_X * x for x in range(1, nX + 1)]
    cutpoints_Y = [cut_distance_Y * x for x in range(1, nY + 1)]
    cutpoints_Z = [cut_distance_Z * x for x in range(1, nZ + 1)]

    # ** Convert these image coordinates to mm coordinates
    cutpoints_X_mm = [nilearn.image.coord_transform(x, 0, 0, SUIT.affine)[0] for x in cutpoints_X]
    cutpoints_Y_mm = [nilearn.image.coord_transform(0, x, 0, SUIT.affine)[1] for x in cutpoints_Y]
    cutpoints_Z_mm = [nilearn.image.coord_transform(0, 0, x, SUIT.affine)[2] for x in cutpoints_Z]

    # ** Create screenshots
    for plane in ['X', 'Y', 'Z']:

        # *** Announce
        print('--------------------------------------- PLANE: ' + plane)

        # *** SUIT Template
        print('--------------------------------------- T1 SUIT Template')
        nilearn.plotting.plot_img(
            SUIT,
            display_mode=plane.lower(),
            cut_coords=eval('cutpoints_' + plane + '_mm'),
            cmap='gray',
            output_file=oDIRc + '/SUIT_' + plane + '.svg',
            title='SUIT Template'
        )

        # *** Subject Template normalized to SUIT space
        print('--------------------------------------- Subject Template to SUIT Template')
        SUB2SUIT = nb.load(iDIR23 + '/ants_warped.nii.gz')

        nilearn.plotting.plot_img(
            SUB2SUIT,
            display_mode=plane.lower(),
            cut_coords=eval('cutpoints_' + plane + '_mm'),
            cmap='gray',
            output_file=oDIRc + '/Sub2SUIT_' + plane + '.svg',
            title='Subject warped to SUIT Template'
        )

        # *** Create animations
        svg1 = oDIRc + '/SUIT_' + plane + '.svg'
        svg2 = oDIRc + '/Sub2SUIT_' + plane + '.svg'
        outSVG = oDIRc + '/Sub2SUIT_' + plane + '_a.svg'
        compileSVG(oDIR, svg1, svg2, outSVG)

        # *** Clean up
        os.remove(svg1)
        os.remove(svg2)

    # ** Export to HTML
    for plane in ['X', 'Y', 'Z']:
        html = html + f"""
        <img class="img" src="./ses-{SES}/Sub2SUIT_{plane}_a.svg">
        """
    html = html + f"""
    </div>
    """


# * Create Spaghetti Plot for ROI volumes
message = f"""
##############################################################
### Create Spaghetti Plot for ROI volumes                  ###
##############################################################

"""
print(message)

# * Spaghetti plot
# (only if there is more than one time point)
if len(SESLIST) > 1:

    # ** Export to HTML
    html = html + f"""
    <h1>Cerebellar Lobule Volume Changes Over Time</h1>
    """

    # ** List all data files
    searchPattern = iDIR4 + '/**/*csv*'
    list = sorted(glob(searchPattern))

    # ** Append all data
    data = pd.read_csv(list[0])
    for i in range(1, len(list)):

        dataTmp = data.append(pd.read_csv(list[i]))
        data = dataTmp

    # ** Initialize the figure
    plt.style.use('seaborn-darkgrid')
    plt.figure(figsize=(12, 12))

    # ** Font size
    plt.rcParams.update({'font.size': 9})

    # ** Create a color palette
    palette = plt.get_cmap('viridis', 33)

    # ** Multiple line plot
    num = 0
    for column in data.drop(['SUB', 'SES'], axis=1):
        num += 1

        # *** Find the right spot on the plot
        plt.subplot(5, 6, num)

        # *** Plot the lineplot
        plt.plot(data['SES'], data[column], marker='', color=palette(num), linewidth=1.9, alpha=0.9, label=column)

        # *** Add title
        plt.title(column, loc='left', fontsize=9, fontweight=0, color=palette(num))

    # ** Improve spacing
    plt.tight_layout()

    # ** Write out graph
    oPlot = oDIR + "/ROIs_over_time.svg"
    plt.savefig(oPlot)

    # ** Add to html
    html = html + f"""
    <div class="imgbox">
    <img class="img" src="./ROIs_over_time.svg">
    </div>
    """

# * Close html
html = html + f"""
  </body>
</html>
"""

# * Write out html
webpage = open(oDIR + "/CVET_sub-" + SID + ".html", "w")
webpage.write("%s" % html)
webpage.close()

#! /usr/bin/env python3

import sys
import argparse
import os
import subprocess
from glob import glob


# Gather arguments
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Cerebellar Volume Extraction Tool. This script outputs '
        'cerebellar volumes from T1-weighted images. BIDS mode. '
        'If you specify a BIDS-formatted freesurfer folder as input. All data '
        'is extracted automatiacally from that folder. ')
    
    
    parser.add_argument('bids_dir',
                        help='The directory with the input dataset '
                        'formatted according to the BIDS standard. This '
                        ' is the root folder of a BIDS valid dataset '
                        '(sub-XXXXX folders should be found at the top '
                        'level in this folder).')
    parser.add_argument('out_dir',
                        help='Results are put into {out_dir}/CVET.')
    parser.add_argument('analysis_level', help='Processing stage to be run, '
                        'only "participant" in the case of the Cerebellar '
                        ' Volume Extraction Tool (see BIDS-Apps specification). ',
                        choices=['participant'])
    
    
    parser.add_argument('--participant_label',
                        help='The label of the participant that should be analyzed. The label '
                        'corresponds to sub-<participant_label> from the BIDS spec '
                        '(so it does not include "sub-"). If this parameter is not '
                        'provided all subjects should be analyzed. Multiple '
                        'participants can be specified with a space separated list.',
                        nargs="+")
    parser.add_argument('--freesurfer',
                        help="If you have already processed your data using FreeSurfer "
                        "set this flag to 1 to use this data as input. This will "
                        "omit reprocessing the data and save you some time. Make "
                        "sure that if you have longitudinal data that you used "
                        "FreeSurfer's longitudinal pipeline. Also, make sure to mount "
                        "your FreeSurfer subject folder to /freesurfer with docker.",
                        choices=[0,1],
                        default=0,
                        type=int)
    parser.add_argument('--segment',
                        help="Select which algorithm to use for tissue class segmentation: "
                        "ANTs Atropos (default), or SPM12.",
                        choices=['A','S'],
                        default='A')
    parser.add_argument('--average',
                        help='Select 1 to create an average from multiple T1-weighted '
                        'images if more than one T1-weighted image was '
                        'collected per session. The default (0) is to not '
                        'average T1-weighted images, but to take the first '
                        'T1-weighted image collected during a session. If '
                        'an average is created, this average will be used  '
                        'throughout the rest of the pipeline. ',
                        choices=[0,1],
                        default=0,
                        type=int)
    parser.add_argument('--n_cpus',
                        help='Number of CPUs/cores available to use.',
                        default=1,
                        type=int)
    parser.add_argument('--intermediate_files',
                        help='How to handle intermediate files (0=delete, 1=keep)',
                        choices=[0,1],
                        default=1,
                        type=int)
    parser.add_argument('--report',
                        help='Generate a report for quality control of the data processing')
    
    args = parser.parse_args()
    
    
    
    # Parse arguments
    # FreeSurfer
    # If '--freesurfer' has been set to 1, check
    # if there is any data in that folder.
    if args.freesurfer == 1:
    
        files = glob('/freesurfer/sub-*')
        if len(files) < 1:
            print('No subject data found in the folder that '
                  'was specified as the FreeSurfer data folder.'
                  'Check that you mounted the correct freesurfer '
                  'dat folder with docker to /freesurfer and that '
                  'this folder contains all BIDS formatted subject '
                  'folders (e.g., sub-001).')
            sys.exit(1)
        elif len(files) > 0:
            # Forward option to shell script
            FSOPT=0
    
    if args.freesurfer == 0:
        FSOPT=1
    
    
    
    # Environment
    inputFolder='/data/in'
    scriptsDir='/software/scripts'
    
    
    
    # Define function to pass environment variable to shell
    def run_cmd(cmd, logfile, env={}):
        merged_env = os.environ
        merged_env.update(env)
        try:
            with open(logfile, 'w') as shelloutput:
                subprocess.run(cmd, stdout=shelloutput, stderr=shelloutput, check=True, env=merged_env)
        except subprocess.CalledProcessError as err:
            raise Exception(err)
        
        
        
    # Create a list of subjects that need to be processed
    # If the participant_label has not been specified,
    # process all subjects
    if not args.participant_label:
        # List all the subject folders in the input folder
        SUBLIST = [os.path.basename(x) for x in glob(inputFolder+'/sub-*')]
        # Strip the 'sub-' part
        SUBLIST = ([s.replace('sub-', '') for s in SUBLIST])
    else:
        # If a single or list of subjects has been specified
        # as argument to participant_label, then forward
        # these subjects to the loop
        SUBLIST=args.participant_label
    
    
    
    
    # Loop over subjects
    for SID in SUBLIST:
    
        # Announce
        print('Working on: Subject '+SID)
        
        # Subject DIR
        SUBDIR = inputFolder+'/sub-'+SID
        
        # Create a list with all sessions
        # Test for sessions with T1w images
        # There may be more than 1 T1 images in the anat
        # folder (multiple runs). Therefore, only
        # pick one from each sessions folder: If there is
        # a 'run' identifier in the file names, only pick
        # 'run-1'.
        #T1LIST=sorted(glob(SUBDIR+'/ses-*/anat/*T1w.nii*'))
        
        # List all time points with anat folders
        ANATLIST=sorted(glob(SUBDIR+'/ses-*/anat'))
        ANATLIST=[i.split('/anat',1)[0] for i in ANATLIST]
        ANATLIST=[i.split('ses-',1)[1] for i in ANATLIST]
        
        # Test if there are T1-weigthed image(s) in the
        # anat folders of these time points. If this is then
        # case, add the session to the list of sessions
        SESLIST=[]
        for ASES in ANATLIST:
            # List all the T1-weighted images for this time point
            T1LIST=sorted(glob(SUBDIR+'/ses-'+ASES+'/anat/*T1w.nii*'))
            # If there is at least one image, add this
            # session to the session list
            if len(T1LIST) > 0:
                SESLIST.append(ASES)
        
        # Count the sessions
        SESN=len(SESLIST)
        
        
        
        
        ### RUN SCRIPTS
        
        
        
        # 01 FreeSurfer
        # Only run FreeSurfer if no FreeSurfer folder was mounted
        if FSOPT==1:
            # Announce
            print('               +----------> Run FreeSurfer')
            
            # Define log file
            logFolder='/data/out/01_FreeSurfer'
            os.makedirs(logFolder, exist_ok=True)
            log=logFolder+'/sub-'+SID+'_log-01-FS.txt'
            
            # Arguments
            script=scriptsDir+'/01_FS.sh'
            arguments=[script,
                       '-s', SID,
                       '-a', str(args.average),
                       '-c', str(args.n_cpus),
                       '-i', str(args.intermediate_files)
            ]
            
            # Start script
            run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
        
        
        
        # 02 Subject Template Creation and Normalization to SUIT Space
        # Announce
        print('               +----------> Build Subject Template and Normalize to SUIT')
        
        # Define log file
        logFolder='/data/out/02_Template/sub-'+SID
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_log-02-Template.txt'
        
        # Arguments
        script=scriptsDir+'/02_MkTmplt.sh'
        arguments=[script,
                   '-s', SID,
                   '-n', str(SESN),
                   '-f', str(FSOPT),
                   '-c', str(args.n_cpus),
                   '-i', str(args.intermediate_files)
        ]
        
        # Start script
        run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
        
        
        
        # 03 Segment the whole brain images using SPM12 or ANTs Atropos
        # Loop over sessions
        for SES in SESLIST:
            
            # Announce
            print('               +----------> Tissue Segmentation   -- Session '+SES)
            
            # Define log file
            logFolder='/data/out/03_Segment/sub-'+SID+'/ses-'+SES
            os.makedirs(logFolder)
            log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-03-Segment.txt'
            
            # Arguments
            script=scriptsDir+'/03_Segment.sh'
            arguments=[script,
                       '-s', SID,
                       '-t', SES,
                       '-n', str(SESN),
                       '-f', str(FSOPT),
                       '-m', str(args.segment),
                       '-i', str(args.intermediate_files)
            ]
            
            # Start script
            run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
        
        
        
        # 04 Extract volumes and create modulated warped GM maps
        # Loop over sessions
        for SES in SESLIST:
            
            # Announce
            print('               +----------> Volume Extraction     -- Session '+SES)
            
            # Define log file
            logFolder='/data/out/04_ApplyWarp/sub-'+SID+'/ses-'+SES
            os.makedirs(logFolder)
            log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-04-ApplyWarp.txt'
            
            # Arguments
            script=scriptsDir+'/04_ApplyWarp.sh'
            arguments=[script,
                       '-s', SID,
                       '-t', SES,
                       '-n', str(SESN),
                       '-f', str(FSOPT),
                       '-m', str(args.segment),
                       '-i', str(args.intermediate_files)
            ]
            
            # Start script
            run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
            
            
            
        # 05 Create quality control HTML report
        # Loop over sessions
            
        # Announce
        print('               +----------> Quality Control HTML Report')
        
        # Define log file
        logFolder='/data/out/05_Report/sub-'+SID
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_log-05-QC_Report.txt'
        
        # Arguments
        script=scriptsDir+'/05_Report.py'
        arguments=[script,
                   '--SID', SID
        ]
            
        # Start script
        run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})


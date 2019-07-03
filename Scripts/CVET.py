#! /usr/bin/env python

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
    parser.add_argument('--freesurfer_run',
                        action='store_true',
                        help='Run FreeSurfer and use the cerebellum labels for '
                        'refinement of the cerebellum mask. If you already have '
                        'run your data through FreeSurfer, use the --freesurfer_dir '
                        'instead.')
    parser.add_argument('--freesurfer_dir',
                        dest='FSdataDir',
                        help="Folder with FreeSurfer subjects formatted according "
                        "to BIDS standard. If subject's recon-all folder "
                        "cannot be found, recon-all will be run. "
                        "If not specified freesurfer data will be saved to {"
                        "out_dir}/freesurfer")
    parser.add_argument('-a','--average',
                        help='Select 1 to create an average from multiple T1-weighted '
                        'images if more than one T1-weighted image was ' 
                        'collected per session. Default (0) is to not average '
                        'weighted images, but to take the first '
                        'T1-weighted image collected during a session. ' 
                        'If an average is created, this will be used for '
                        'the rest of the pipeline. ',
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
# If '--freesurfer_dir' has been set, check if there is any
# data in that folder.
files = glob(args.FSdataDir+'/sub-*')
if len(files) < 1:
    print('No subject data found in the folder that '
          'was specified as the FreeSurfer data folder.')
    sys.exit(1)
elif len(files) > 0:
    # Forward option to shell script
    FSOPT=1

if args.freesurfer_run == True:
    FSOPT=2



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
    # List all the session folders in the subject folder
    SESLIST = [os.path.basename(x) for x in sorted(glob(SUBDIR+'/ses-*'))]
    # Strip the 'ses-' part
    SESLIST = ([s.replace('ses-', '') for s in SESLIST])
    
    # Count the sessions
    SESN=len(SESLIST)
    
    
    
    
    ### RUN SCRIPTS
    
    
    
    # 01 T1 Bias Field Correction
    # Loop over sessions
    for SES in SESLIST:
        
        # Announce
        print('               +----------> Bias Field Correction -- Session '+SES)
        
        # Define log file
        logFolder='/data/out/01_SSN4/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-01-SSN4.txt'
        
        # Arguments
        script=scriptsDir+'/01_SSN4.sh'
        arguments=[script, '-s', SID, '-t', SES, '-a', str(args.average), '-i', str(args.intermediate_files)]
        
        # Start script
        run_cmd(arguments, log, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
    
    
    
    # 02 Cerebellum + Brain Stem Isolation
    # Loop over sessions
    for SES in SESLIST:
        
        # Announce
        print('               +----------> Cerebellar Isolation  -- Session '+SES)
        
        # Define log file
        logFolder='/data/out/02_CerIso/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-02-CerIso.txt'
        
        # Arguments
        script=scriptsDir+'/02_CerIso.sh'
        arguments=[script, '-s', SID, '-t', SES, '-i', str(args.intermediate_files)]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
    
    
    
    # 03 Subject Template Creation and Normalization to SUIT Space
    # Announce
    print('               +----------> Build Subject Template and Normalize to SUIT')
    
    # Define log file
    logFolder='/data/out/03_MkTmplt/sub-'+SID+'/ses-'+SES
    os.makedirs(logFolder)
    log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-03-MkTmplt.txt'
    
    # Arguments
    script=scriptsDir+'/03_MkTmplt.sh'
    arguments=[script, '-s', SID, '-n', SESN, '-c', str(args.n_cpus), '-i', str(args.intermediate_files)]
    
    # Start script
    run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
    
    
    
    # 04 Segment the whole brain images using SPM12
    # Loop over sessions
    for SES in SESLIST:
        
        # Announce
        print('               +----------> Tissue Segmentation   -- Session '+SES)
        
        # Define log file
        logFolder='/data/out/04_Segment/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-04-Segment.txt'
        
        # Arguments
        script=scriptsDir+'/04_Segment.sh'
        arguments=[script, '-s', SID, '-t', SES, '-i', str(args.intermediate_files)]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
    
    
    
    # 05 Extact volumes and create modulated warped GM maps
    # Loop over sessions
    for SES in SESLIST:
        
        # Announce
        print('               +----------> Volume Extraction     -- Session '+SES)
        
        # Define log file
        logFolder='/data/out/05_ApplyWarp/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-05-ApplyWarp.txt'
        
        # Arguments
        script=scriptsDir+'/05_ApplyWarp.sh'
        arguments=[script, '-s', SID, '-t', SES, '-i', str(args.intermediate_files)]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})
    
    
    
    # 06 Refine the cerebellar labels with a Extact volumes and create modulated warped GM maps
    # If the user selected to apply FreeSurfer:
    if [ FSOPT == 1 ] | [ FSOPT == 2 ]:
        
        for SES in SESLIST:
            
            # Announce
            print('               +----------> Volume Refinement     -- Session '+SES)
            
            # Define log file
            logFolder='/data/out/06_RefineFS/sub-'+SID+'/ses-'+SES
            os.makedirs(logFolder)
            log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-06-RefineFS.txt'
            
            # Arguments
            script=scriptsDir+'/06_RefineFS.sh'
            arguments=[script, '-s', SID, '-t', SES, '-i', str(args.intermediate_files), '-f', str(FSOPT)]
            
            # Start script
            run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': str(args.n_cpus)})

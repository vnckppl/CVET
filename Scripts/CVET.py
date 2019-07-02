#! /usr/bin/env python

import sys
import argparse
import os
import subprocess


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
                        help='Create an average from multiple T1-weighted '
                        'images if more than one T1-weighted image was ' 
                        'collected per session. Default is to not average '
                        'weighted images, but to take the first '
                        'T1-weighted image collected during a session. ' 
                        'If an average is created, this will be used for '
                        'the rest of the pipeline. ')
    parser.add_argument('--n_cpus',
                        help='Number of CPUs/cores available to use.',
                        default=1,
                        type=int)
    parser.add_argument('--intermediate_files',
                        help='How to handle intermediate files (0=delete, 1=keep)',
                        choices=[0,1],
                        default=1)
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
    aF='-f 1'
    FSOPT=1

if args.freesurfer_run == True:
    aF='-f 2'
    FSOPT=2



# Convert options to format for shell scripts
aS='-s '+SID
aT='-t '+SES
aA='-a '+args.average
aC='-c '+args.n_cpus
aI='-i '+args.intermediate_files
aR='-r '+arg.report



# Environment
inputFolder='/data/in'
scriptsDir='/software/scripts'



# Create a list of subjects that need to be processed
# If the participant_label has not been specified,
# process all subjects
if not arg.participant_label:
    # List all the subject folders in the input folder
    SUBLIST = [os.path.basename(x) for x in glob('/data/in/sub-*')]
    # Strip the 'sub-' part
    SUBLIST = ([s.replace('sub-', '') for s in SUBLIST])
else:
    # If a single or list of subjects has been specified
    # as argument to participant_label, then forward
    # these subjects to the loop
    SUBLIST=arg.participant_label
    
# Loop over subjects
for SID in SUBLIST:
    
    # Subject DIR
    SUBDIR = '/data/in/sub-'+SID
    
    # Create a list with all sessions
    # List all the session folders in the subject folder
    SESLIST = [os.path.basename(x) for x in glob(SUBDIR+'/ses-*')]
    # Strip the 'ses-' part
    SESLIST = ([s.replace('ses-', '') for s in SESLIST])
    
    # Count the sessions
    SESN=len(SESLIST)
    aN='-n SESN'
    
    
    
    
    ### RUN SCRIPTS



    # Define function to pass environment variable to shell
    def run_cmd(cmd, env={}):
        merged_env = os.environ
        merged_env.update(env)
        try:
            subprocess.run(cmd, shell=True, check=True, env=merged_env)
        except subprocess.CalledProcessError as err:
            raise Exception(err)
    
    
    
    # 01 T1 Bias Field Correction
    # Loop over sessions
    for SES in SESLIST:
        
        # Define log file
        logFolder='/data/out/01_SSN4/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-01-SSN4.txt'
        logFile = open(log, 'w')
        sys.stdout = sys.stderr = logFile
        
        # Arguments
        script=scriptsDir+'/01_SSN4.sh'
        arguments=[script, aS, aT, aA, aI, aR]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': args.n_cpus})
        
        # Close log file
        logFile.close()
    
    
    
    # 02 Cerebellum + Brain Stem Isolation
    # Loop over sessions
    # Define log file
    for SES in SESLIST:
        
        # Define log file
        logFolder='/data/out/02_CerIso/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-02-CerIso.txt'
        logFile = open(log, 'w')
        sys.stdout = sys.stderr = logFile
        
        # Arguments
        script=scriptsDir+'/02_CerIso.sh'
        arguments=[script, aS, aT, aI, aR]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': args.n_cpus})
        
        # Close log file
        logFile.close()
    
    
    
    # 03 Subject Template Creation and Normalization to SUIT Space
    # Define log file
    logFolder='/data/out/03_MkTmplt/sub-'+SID+'/ses-'+SES
    os.makedirs(logFolder)
    log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-03-MkTmplt.txt'
    logFile = open(log, 'w')
    sys.stdout = sys.stderr = logFile
    
    # Arguments
    script=scriptsDir+'/03_MkTmplt.sh'
    arguments=[script, aS, aN, aC, aI, aR]
    
    # Start script
    subprocess.call(arguments)
        
    # Close log file
    logFile.close()
    
    
    
    # 04 Segment the whole brain images using SPM12
    # Loop over sessions
    for SES in SESLIST:
        
        # Define log file
        logFolder='/data/out/04_Segment/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-04-Segment.txt'
        logFile = open(log, 'w')
        sys.stdout = sys.stderr = logFile
        
        # Arguments
        script=scriptsDir+'/04_Segment.sh'
        arguments=[script, aS, aT, aI, aR]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': args.n_cpus})
        
        # Close log file
        logFile.close()
    
    
    
    # 05 Extact volumes and create modulated warped GM maps
    # Loop over sessions
    for SES in SESLIST:
        
        # Define log file
        logFolder='/data/out/05_ApplyWarp/sub-'+SID+'/ses-'+SES
        os.makedirs(logFolder)
        log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-05-ApplyWarp.txt'
        logFile = open(log, 'w')
        sys.stdout = sys.stderr = logFile
        
        # Arguments
        script=scriptsDir+'/05_ApplyWarp.sh'
        arguments=[script, aS, aT, aI, aR]
        
        # Start script
        run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': args.n_cpus})
        
        # Close log file
        logFile.close()
    
    
    
    # 06 Refine the cerebellar labels with a Extact volumes and create modulated warped GM maps
    # If the user selected to apply FreeSurfer:
    if [ FSOPT == 1 ] | [ FSOPT == 2 ]:
        
        for SES in SESLIST:
        
            # Define log file
            logFolder='/data/out/06_RefineFS/sub-'+SID+'/ses-'+SES
            os.makedirs(logFolder)
            log=logFolder+'/sub-'+SID+'_ses-'+SES+'_log-06-RefineFS.txt'
            logFile = open(log, 'w')
            sys.stdout = sys.stderr = logFile
            
            # Arguments
            script=scriptsDir+'/06_RefineFS.sh'
            arguments=[script, aS, aT, aI, aF, aR]
            
            # Start script
            run_cmd(arguments, {'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS': args.n_cpus})
            
            # Close log file
            logFile.close()

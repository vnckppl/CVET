% Isolate Cerebellum and Brain Stem using SUIT toolbox

% Load packages
SUIT='/path/to/SUIT/toolbox';
addpath(SUIT);

% Environment
DIR="/my/output/folder/subject"

% Matlab batch
FILE=strcat(DIR,'/','roN4_subjectID_01.nii,1');  % input the reoriented, biasfield corrected, and unzipped T1 image
%fprintf(strcat("\nWorking on:\n",FILE,"\n\n"));
matlabbatch{1}.spm.tools.suit.isolate_seg.source = {{FILE}};
matlabbatch{1}.spm.tools.suit.isolate_seg.bb = [-76 76
	                                        -108 -6
	                                        -70 11];
matlabbatch{1}.spm.tools.suit.isolate_seg.maskp = 0.2;
matlabbatch{1}.spm.tools.suit.isolate_seg.keeptempfiles = 0;

% Run job
spm('defaults', 'FMRI');
spm_jobman('run',matlabbatch);

% Quit
quit


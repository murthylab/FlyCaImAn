%% demo for analysis of ball video + stimuli (song) + imaging data
%% 1) add paths
% it assumes you have already add the repository folders to your path
addpath(genpath(pwd))

% add paths of all dependencies
% CaImAn, NoRMCorre, CMTK_matlab_wrapper

%% 2) Move to folder and Download demo data
tDir = strrep(which('FlyCaImAn_demo'), 'FlyCaImAn_demo.m', '');
cd(tDir)

url = 'https://www.dropbox.com/s/x5w0d554kfls4pm/20200909.zip?dl=1';
filename = '20200909.zip';

if ~exist('demodata', 'dir')
    mkdir('demodata')
end
cd demodata

outfilename = websave(filename, url);
unzip(outfilename);
clear url outfilename

%% 3) process behavior videos with fictract
% 1.2.1) Generate fictrac input files
FolderName = '20200909'; FileName = [];
setupID = 'Alevel_2p1';
% readout a tiff for mask or extract from video mp4
im_mode = 1;

batch_gen_fictrac_input_files(FolderName, FileName, setupID, im_mode)
% this function generates:
% 20200911_1_1_maskim.tiff
% 20200911_1_1_calibration-transform.dat
% which are used by fictrac

% 1.2.2) Run fictrac on each file per current directory
FolderName = '20200909'; FileName = [];
fictracpars = [];
fictracpars.redo = 1;
fictracpars.do_search_flag = 1; % to do global search
%fictracpars.load_template_flag = 1; % to load pre-generated template
%fictracpars.template_fn = 'template_im.jpg'; % pre-generated template image

batch_fictrac_perfile(FolderName, FileName, fictracpars)
% this function generates:
% 20200911_1_1_fictrac.txt
% 20200911_1_1_fictrac-debug.avi
% 20200911_1_1_fictrac-raw_frames.avi
% *.avi are for visualization and debugging
% 20200911_1_1_vDat.mat
% fictrac variables are saved as 'fictrac'

%% 4) add stimuli metadata

FolderName = '20200909'; FileName = [];

m2vpar = [];
m2vpar.SpMode = '3DxT_song_prv';
m2vpar.ch2save = [1 2];
m2vpar.Zres = [];
m2vpar.ch2plot = [];

batch_tiff2mat(FolderName, FileName, m2vpar)
% generates '20200909_1_1_metadata.mat'
% generates '20200909_1_1_rawdata.mat' with imaging data

cmpar = [];
cmpar.pgate = 1;
cmpar.pgates = 1;
cmpar.mode = 1;

batch_collectmetada(FolderName, FileName, cmpar)
% passes stimuli and imaging info to '20200909_1_1_metadata.mat'

mcpar = [];
mcpar.debug = 0;
mcpar.rigidg = 1;
mcpar.nrigidg = 0;
mcpar.stack2del = 1;
mcpar.sgate = 1; 
mcpar.withinplane_flag = 1; % just do within plane motion correction

batch_NoRMCorre(FolderName, FileName, mcpar)

stpar = [];
stpar.sigma = [];
stpar.size = [];
stpar.newtimeres = 0.1;
stpar.time = [];
stpar.debug = 0;
stpar.direction = 'invert';
stpar.fshift = [6 6];

batch_SpaTemp_ResFilt(FolderName, FileName, stpar)
% resamples imaging data and passes both fictrac, stimuli, 
%   and imaging info to '20200909_1_1_metadata.mat' stored in wDat

%% 5) plot stim vs fictrac

FolderName = '20200909'; FileName = [];
fictracpar = [];
fictracpar.dir_depth = 1;
fictracpar.timeres = 0.05;

batch_plot_fictrac_results(FolderName, FileName, fictracpar)

%% 6) format imaging data to be compatible with ROI segmentation
% it formats Data to be ready for ROI segmentation
FolderName = '20200909'; FileName = [];

bmpar = [];
bmpar.tsuffix = 1;
bmpar.fsuffix = '_metadata';

batch_brainmaskgen(FolderName, FileName, bmpar)

cstpar = [];
cstpar.oDir = [];
cstpar.idp_run_flag = 1;
cstpar.fshift = [6 6];

batch_formatstacks(FolderName, FileName, cstpar)

%% 7) Make DFoF, SNR, DF, and maxF videos:

FolderName = '20200909'; FileName = [];
ipars.metadata_suffix = '_metadata.mat';
ipars.rawdata_suffix = '_rawdata.mat';
 
ipars.range = [0 1; 0 1; 0 1; 0 3];
ipars.axisratio = 1;
ipars.baseline_tp = 1:60;
ipars.dir_depth = 1;
ipars.df_flag = [0 1 2 3];
ipars.sign2use = 0;
ipars.redo = 1;
ipars.axisratio = 0;

batch_plot_df_dfof_maxf(FolderName, FileName, ipars)

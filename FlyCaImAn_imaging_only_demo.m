%% demo for imaging only data (two volumes sequentially imaged)
%% 1) add paths
% it assumes you have already add the repository folders to your path
addpath(genpath(pwd))

% add paths of all dependencies
% CaImAn, NoRMCorre, CMTK_matlab_wrapper

%% 2) Move to folder and Download demo data
tDir = strrep(which('CaImProPi_demo'), 'CaImProPi_demo.m', '');
cd(tDir)

url = 'https://www.dropbox.com/s/1s2h6yigfmdhodf/20161129.zip?dl=1';
filename = '20161129.zip';

if ~exist('demodata', 'dir')
    mkdir('demodata')
end
cd demodata

outfilename = websave(filename, url);
unzip(outfilename);
clear url outfilename

%% 4) process imaging videos 
%% Test batch_tiff2mat
FolderName = {'20161129'}; FileName = [];
m2vpar = [];
m2vpar.SpMode = '3DxT_song_prv';
m2vpar.ch2save = [1 2];
m2vpar.Zres = 2; % Z resolution in um
m2vpar.ch2plot = [];

batch_tiff2mat(FolderName, FileName, m2vpar)

%% Test batch_collectmetada
FolderName = {'20161129'}; FileName = [];
cmpar = [];
cmpar.pgate = 1;
cmpar.pgates = 1;
cmpar.mode = 1;

batch_collectmetada(FolderName, FileName, cmpar)

%% Test batch_NoRMCorre
FolderName = []; FileName = [];
mcpar = [];
mcpar.debug = 0;
mcpar.rigidg = 1;
mcpar.nrigidg = 0;
mcpar.stack2del = [1:3 97:100];
mcpar.sgate = 1; %(1 = smooth and zero, 2 = smooth, 3 = zeroing, 0 = raw)
mcpar.withinplane_flag = 1; % within plane motion correction
mcpar.withinplane_flag = 0; % 3D motion correction

batch_NoRMCorre(FolderName, FileName, mcpar)

%% Test batch_SpaTemp_ResFilt
FolderName = []; FileName = [];
stpar = [];
stpar.sigma = [];
stpar.size = [];
stpar.newtimeres = 0.5;
stpar.time = [];
stpar.debug = 1;
stpar.direction = 'invert';
stpar.fshift = [6 6];
stpar.idp_run_flag = 1;

batch_SpaTemp_ResFilt(FolderName, FileName, stpar)

%% Test batch_stitch_format_stacks_a
% stitch serially imaged stacks, part 1, it stitchs mean image
FolderName = []; FileName = [];
cspfpars = [];
cspfpars.refcha = 2;
cspfpars.fshift = [6 6];

batch_stitch_format_stacks_a(FolderName, FileName, cspfpars)

%% generate brain mask based on F threshold + manual editing
FolderName = []; FileName = [];
bmpar = [];

batch_brainmaskgen(FolderName, FileName, bmpar)

iparams.dir_depth = 1;
batch_plot_brainside_MIP(...
    [], [], iparams)

%% Test batch_stitch_format_stacks_b
% stitch serially imaged stacks, part 2
%   it stitchs whole 3DxT volume (it formats Data to be ready for ROI segmentation)
FolderName = []; FileName = [];
cstpar = [];
cstpar.oDir = [];

batch_stitch_format_stacks_b(FolderName, FileName, cstpar)

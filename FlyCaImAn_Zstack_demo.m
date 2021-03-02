%% demo for analysis of ball video only
%% 1) add paths
% it assumes you have already add the repository folders to your path
addpath(genpath(pwd))

% add paths of all dependencies
% CaImAn, NoRMCorre, CMTK_matlab_wrapper

%% 2) Move to folder and Download demo data
tDir = strrep(which('FlyCaImAn_demo'), 'FlyCaImAn_demo.m', '');
cd(tDir)

url = 'https://www.dropbox.com/s/purvtala87l1hpe/20200322.zip?dl=1';
filename = '20200322.zip';

if ~exist('demodata', 'dir')
    mkdir('demodata')
end
cd demodata

outfilename = websave(filename, url);
unzip(outfilename);
clear url outfilename
    
%% 3) process z-stack tiffs
%% 3.1) Collect structural Zstacks

FolderName = '20200322'; FileName = [];
zstackpar = [];
zstackpar.ths = 50;
zstackpar.redo = 1;
zstackpar.integrate_flag = 1;
zstackpar.shift_f = [50 50];
%zstackpar.im_format = '.nrrd';
zstackpar.im_format = '.nii';

batch_zstacktiff2mat(FolderName, FileName, zstackpar)
% batch_zstacktiff2mat(FolderName, FileName, params)
% 1) going from raw scanimage tiff to nrrd or nii.
% 2) average all frames per plane.
% 3) average image/volume.

%% 3.2) Stitch structural Zstack

FolderName = '20200322'; FileName = [];
stitchpar.refcha = 1;
stitchpar.peaknum = 5;
stitchpar.init_xyz = [0 0 0 0 0 0];
stitchpar.redo = 1;
stitchpar.debug_flag = 1;
stitchpar.ijscript = 'refstitcher_1to2_3to4.ijm';
%stitchpar.im_format = '.nrrd';
stitchpar.im_format = '.nii';

batch_stitcher_nrrd(FolderName, FileName, stitchpar)
%batch_stitcher_nrrd(FolderName, FileName, stitchpar)
% 1) stitch segments

%% 3.3) Split volume into channels (and edit)

FolderName = '20200322'; FileName = [];
z2spars.fisuffix = '_Zstack';
z2spars.redo = 1;
z2spars.refcha = [1 2];
z2spars.nchannels = 2;
z2spars.sig = 2;
z2spars.size = 3;
z2spars.oXYZres = [0.75 0.75 1];
z2spars.padgate = 1; 
z2spars.padnum = 10;
z2spars.zflipgate = 1;
z2spars.mirror_flag = 1;
z2spars.im_format = '.nrrd';
%z2spars.im_format = '.nii';
z2spars.dir_depth = 1;
z2spars.oDir = ['.', filesep, 'ready2register'];

batch_format_and_edit_zstack(FolderName, FileName, z2spars)
%batch_format_and_edit_zstack(FolderName, FileName, z2spars)

% 1.1) flip in z axis
% 1.2) smooth just up to the 2nd dimension
%   hardcoded-pre smoothing to clean up the resampling
% 1.3) resample voxel size (z2spars.oXYZres: (width, height, depth))
% 1.4) smooth just up to the 2nd dimension (so X and Y)
%   (in this case this blurs the image)
% 1.5) pad image in Z (adds zero frames above and below)

%% 3.4 convert nrrd to nii or vice versa
FolderName = []; FileName = [];

z2spars = [];
z2spars.nchannels = 1;
z2spars.im_direction = 1;
z2spars.dir_depth = 1;

nrrd2nii(FolderName, FileName, z2spars)
%nrrd2nii(FolderName, FileName, z2spars)

function batch_stitcher_nrrd(FolderName, FileName, iparams)
% batch_stitcher_nrrd: stitch nrrd files that are contiguous on the XY axis
% 	(it can be 3 or 4 contiguous files, order is 1 --> 2, 3 -> 4, 
%   then fuses fused-1-2 --> fused-3-4)
%
% Usage:
%   batch_stitcher_nrrd(FolderName, FileName, iparams)
%
% Args:
%   FolderName: name of folders to load
%   FileName: name of files to load
%   iparams: parameters
%       (fo2reject: folders to reject)
%           (default, {'.', '..', 'colldata', 'BData', 'preprocessed'})
%       (FieldOfView: field of view of microscope)
%           (default, 768 um)
%       (nchannel: default number of channels)
%           (default, 2)
%       (suffix: pattern of files to look for)
%           (default, '_Zstack_')
%       (refcha: reference channel for stitching)
%           (default, 1, red channel)
%       (peaknum: number of peaks for the stitching algorithm)
%           (default, 5)
%       (init_xyz: initial image positions [0 0 0 0 0 0], x x y y z z)
%           (default, [0 0 0 0 0 0])
%       (redo: gate to overwrite old files)
%           (default, 0)
%       (ijscript: stitching script to use)
%           (default, 'refstitcher_1to2_3to4.ijm')
%           (default, 'refstitcher_1_2to3.ijm')
%           (default, 'refstitcher_1to4_2to3.ijm')
%       (fusion_method: method of imaeg fusion)
%           (default, 0, 'Linear Blending')
%           (1, 'Max. Intensity')
%       (debug_flag: flag for debug mode for loading FIJI)
%           (default, 0)
%       (im_format: 'nrrd' or 'NIfTI')
%           (default, '.nrrd', if NIfTI use '.nii')
% 
% Notes:
% requires the following Fiji pluggins:
%   ImageScience & Image_Stitching
% see https://imagej.net/ImageScience
% see http://imagej.net/Image_Stitching
%
% 20210122
%   generalize to .nrrd and .nii image formats

stpars = [];

stpars.fo2reject = {'.', '..', 'colldata', 'BData', 'preprocessed'};
stpars.FieldOfView = 768;
stpars.nchannel = 2;
stpars.suffix = '_Zstack_';
stpars.refcha = 1;
stpars.peaknum = 5;
stpars.init_xyz = [0 0 0 0 0 0];
stpars.redo = 0;
stpars.ijscript = 'refstitcher_1to2_3to4.ijm';
stpars.fusion_method = 0;
stpars.debug_flag = 0;
stpars.im_format = '.nrrd';

% update variables
if ~exist('FolderName','var')
    FolderName = [];
end
if ~exist('FileName','var')
    FileName = [];
end
if ~exist('iparams', 'var'); iparams = []; end
stpars = loparam_updater(stpars, iparams);

% Finding folders and filtering out data that is not selected

cDir = pwd;
fo2run = dir;
fo2run = str2match(FolderName, fo2run);
fo2run = str2rm(stpars.fo2reject, fo2run);
fo2run = {fo2run.name};

fprintf('Running nrrd stitcher\n');
fprintf(['Running n-folders : ', num2str(numel(fo2run)), '\n'])

for i = 1:numel(fo2run)
    fprintf(['Running folder : ', fo2run{i}, '\n']); 
    cd(fo2run{i}) 
    brainstitcher(FileName, stpars)
    cd(cDir)
end

fprintf('\n ********** Done **********\n')

end

function brainstitcher(FileName, stpars)
% brainStitch: stitch images using fiji
%
% Usage:
%   brainStitch(flyname, segment_n, stpars)
%
% Args:
%   FileName: files to use
%   stpars: input params
%       (FieldOfView: default 768um, set for this setup)
%       (nchannel: default number of channels (2))
%       (suffix: pattern of files to use '_Zstack_')
%       (refcha: reference channel for stitching (1 == red channel))
%       (Zres: resolution on the z axis (1 um))
%       (peaknum: number of peaks for the stitching algorithm (5))
%       (init_xyz: initial image positions [0 0 0 0 0 0], x x y y z z)
%       (redo: gate to overwrite old files)
%       (ijscript: stitching script to use)
%           (default, 'refstitcher_1to2_3to4.ijm')
%           (default, 'refstitcher_1_2to3.ijm')
%           (default, 'refstitcher_1to4_2to3.ijm')
%       (fusion_method: method of imaeg fusion)
%           (default, 0, 'Linear Blending')
%           (1, 'Max. Intensity')
%       (debug_flag: flag for debug mode for loading FIJI)

% Update local folder
stpars.cDir = pwd;

% Stitching and getting metadata from whole brain images

[rootName, ~] = NameSplitter([], stpars.suffix, FileName, stpars.im_format);
fly_names = unique(rootName);

fprintf('Stitching nrrd files\n');
for fly_i = 1:numel(fly_names)
    
    % Determine the number of stacks to stitch
    
    flyname_i = [fly_names{fly_i}, stpars.suffix(1:end-1)];
    [~, segname] = NameSplitter(fly_names(fly_i), ...
        stpars.suffix, FileName, stpars.im_format);
    seg_n = numel(segname);
    
    % Get metadata from mat file (to get XYZ resolution) and update fDat
    
    load([flyname_i, '_metadata.mat'], 'fDat', 'iDat')

    fDat.FileName = flyname_i;

    for iSeg = 1:numel(segname)
        fDat.InputFile{1, iSeg} = [flyname_i, segname{iSeg}, stpars.im_format];
    end

    stpars.width = num2str(iDat.MetaData{3}(1));
    stpars.height = num2str(iDat.MetaData{3}(2));
    stpars.depth = num2str(iDat.MetaData{3}(3));
    
    if ~exist([flyname_i, stpars.im_format], 'file') || stpars.redo
        
        if seg_n > 1
            
            % Stitch volumes
            brainStitch(flyname_i, seg_n, stpars)

            % Update metadata
            Data = [];
            
            if strcmp(stpars.im_format, '.nrrd')
                
                [Data, ~] = nrrdread(fullfile([flyname_i, stpars.im_format]));
                
            elseif strcmp(stpars.im_format, '.nii')
                
                Data = niftiread(fullfile([flyname_i, stpars.im_format]));
                
            end
            
            nDim = size(Data); 
            Data = [];
            
        else
            
            % Update metadata
            Data = []; 

            if strcmp(stpars.im_format, '.nrrd')
                
                % load original file
                [Data, ~] = nrrdread(fullfile([flyname_i, '_1', stpars.im_format]));
                nDim = size(Data); 
            
                % save stitched volume
                width_height_depth = iDat.MetaData{3};
                nrrdWriter([flyname_i, stpars.im_format], mat2uint16(Data, 0), ...
                    width_height_depth, [0 0 0], 'gzip');
                
            elseif strcmp(stpars.im_format, '.nii')
                
                % load original file
                Data = niftiread(fullfile([flyname_i, '_1', stpars.im_format]));
                nifti_info = niftiinfo(fullfile([flyname_i, stpars.im_format]));
                
                nDim = size(Data);                
                
                niftiwrite(mat2uint16(Data, 0), [flyname_i, stpars.im_format], ...
                    nifti_info)
                
            end
            
        end
        
        iDat.FrameN = nDim(3)/stpars.nchannel; % Z
        iDat.FrameSize = [nDim(1) nDim(2)]; % Y X
        
        % save mat metadata file
        save([stpars.cDir, filesep, fDat.FileName, ...
            '_metadata.mat'], 'fDat', 'iDat')
        
    else
        
        fprintf(['File ', flyname_i, stpars.im_format, ' already exist - skipping \n'])
        
    end
    
    clear SegmentNum fDat iDat Data tempName SegmentNum
    
end

end

function brainStitch(filename, segment_n, stpars)
% brainStitch: stitch images using fiji
%
% Usage:
%   brainStitch(flyname, segment_n, stpars)
%
% Args:
%   filename: files to use
%   segment_n: input params
%   stpars: input params
%       (FieldOfView: default 768um, set for this setup)
%       (nchannel: default number of channels (2))
%       (suffix: pattern of files to use '_Zstack_')
%       (refcha: reference channel for stitching (1 == red channel))
%       (Zres: resolution on the z axis (1 um))
%       (peaknum: number of peaks for the stitching algorithm (5))
%       (init_xyz: initial image positions [0 0 0 0 0 0], x x y y z z)
%       (redo: gate to overwrite old files)
%
% Notes:

ij = fiji_fullpath;
repoDir = which('FlyCaImAn_demo');
repoDir = strrep(repoDir, 'FlyCaImAn_demo.m', '');
ijmScript = [repoDir, 'toolbox', filesep, ...
    'utilitites', filesep, 'fiji_macros', ...
    filesep, stpars.ijscript];

% Assumes it is running from the data folder, argument generation
inputDir = [pwd, filesep]; 
planeN = num2str(segment_n);

inputarg = [inputDir, '*', filename, ...
    '*', planeN, '*', num2str(stpars.refcha), ...
    '*', stpars.width, '*', stpars.height, ...
    '*', stpars.depth, '*', num2str(stpars.peaknum), ...
    '*', num2str(stpars.init_xyz(1)), ...
    '*', num2str(stpars.init_xyz(2)), ...
    '*', num2str(stpars.init_xyz(3)), ...
    '*', num2str(stpars.init_xyz(4)), ...
    '*', num2str(stpars.init_xyz(5)), ...
    '*', num2str(stpars.init_xyz(6)), ...
    '*', num2str(stpars.fusion_method), ...
    '*', num2str(stpars.debug_flag), ...
    '*', stpars.im_format];

% execute
CMD = sprintf('%s -macro %s %s', ij, ijmScript, inputarg);

if ispc
    system(CMD)
else
    unix(CMD)
end

end

function [basename, segment] = ...
    NameSplitter(inputsuffix, ...
    suffix, FileName, im_format)
% NameSplitter: splits name into: basename_file-number and rep-number
% 
% Usage:
%   [basename, segment] = ...
%       NameSplitter(inputsuffix, ...
%       suffix, FileName, im_format)
%
% Args:
%   inputsuffix: folders to use (name)
%   suffix: suffix to use
%   FileName: filename to select
%   im_format: image format 'nrrd' or 'NIfTI'
%   	(default, '.nrrd', if NIfTI use 'nii')
%
% Notes:

if ~exist('inputsuffix', 'var')
    inputsuffix = [];
end

fi_all = rdir(['*', suffix, '*', im_format]);
fi_all = str2match(FileName, fi_all);
fi_all = str2match(inputsuffix, fi_all);

fi_all = {fi_all.name};
fi_all = strrep(fi_all, im_format, '');

basename = cell(1, numel(fi_all));  
segment = cell(1, numel(fi_all));

for FNum = 1:numel(fi_all)
    TempS = strsplit2(fi_all{FNum}, suffix);
    basename{1, FNum} = TempS{1};
    segment{1, FNum} = ['_', TempS{2}];
end

end

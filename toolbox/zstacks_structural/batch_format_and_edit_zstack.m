function batch_format_and_edit_zstack(FolderName, FileName, iparams)
% batch_format_and_edit_zstack: function that formats input images (.nrrd/.nii)
%   splitting images into containing channels, and performing spatial
%   resampling and smoothing, and flipping of X and Z axis. New generated
%   images have in case of smoothing the '_s' followed by the 'siz' - kernel size - per
%   dimension and 'sig' - kernel sigma - per dimension '_w' followed by 
%   the channel index '01' or '02'
%
% Usage:
%   batch_format_and_edit_zstack(FolderName, FileName, iparams)
%
% Args:
%   FolderName: Folder name to load
%   FileName: File name to load
%   ip: parameters to update
%       (fisuffix: file suffix)
%           ('_Zstack', default)
%       (redo: redo)
%           (0, default)
%       (refcha: channel to save as nrrd, for wholebrain)
%           (1 = red channel, default)
%       (nchannels: number of channels)
%           (2, default)
%       %%% smoothing settings %%%
%       (sig: sigma)
%           (2, default)
%       (size: size)
%           (3, default)
%       %%% resampling settings %%%
%       (oXYZres: output spatial resolution (width, height, depth))
%           ([1.2 1.2 1] um, default)
%       %%% padding settings %%%
%       (padgate: gate to pad)
%           (0, default)
%       (padnum: number of planes, lines to use for padding)
%           (10, default)
%       (zflipgate: gate to flip orientation in Z)
%           (1, default)
%       (mirror_flag: flag to also save mirror image (_mw))
%           (1, default, mirror in x)
%           (2, default, mirror in y)
%       (im_format: image format ".nrrd" or ".nii")
%           (default, '.nrrd')
%       (dir_depth: depth of directory search)
%           (default, 1)
%       (oDir: output directory)
%           (pwd, default)
%
% Notes:
% 1) For whole brains it gets the resolution from the nrrd/nifti image
% 2) Performs some processing to whole brains:
%   *reshape
%   *choose/reorder channels to split
%   *flip Z axes
%   *blur
%   *resample
%   *mirror
%   *output image is saved as nrrd/nifti

% Default iparams
z2spars.fisuffix = '_Zstack';
z2spars.redo = 0;
z2spars.refcha = 1;
z2spars.nchannels = 2;
z2spars.sig = 2;
z2spars.size = 3;
z2spars.oXYZres = [1.2 1.2 1];
z2spars.padgate = 0; 
z2spars.padnum = 10;
z2spars.zflipgate = 1;
z2spars.mirror_flag = 1;
z2spars.im_format = '.nrrd';
z2spars.dir_depth = 1;
z2spars.oDir = ['.', filesep];

% update variables
if ~exist('FolderName', 'var') || isempty(FolderName)
    FolderName = [];
end

if ~exist('FileName', 'var') || isempty(FileName)
    FileName = [];
end

if ~exist('iparams', 'var')
    iparams = [];
end

z2spars = loparam_updater(z2spars, iparams);

% define files to use
if z2spars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
       z2spars.fisuffix, z2spars.im_format]);
elseif z2spars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', z2spars.fisuffix, z2spars.im_format]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        z2spars.fisuffix, z2spars.im_format]);
end

f2run = {f2run.name}';
[filename, iDir] = split_path(f2run);

if ~isempty(FileName)
    f2run = find(contains(filename, FileName));
    filename = filename(f2run);
    iDir = iDir(f2run);
end

if ~isempty(FolderName)
    f2run = find(contains(iDir, FolderName));
    filename = filename(f2run);
    iDir = iDir(f2run);
end

fprintf(['Running n-files : ', num2str(numel(filename)), '\n'])

for i = 1:numel(filename)
    
    fprintf(['Running file : ', filename{i}, '\n']); 
    genrrdIm(filename{i}, iDir{i}, z2spars);
    
end

fprintf('... Done\n')

end

function genrrdIm(filename, full_dir_path, z2spars)
% genrrdIm: per file name, _w nrrd images
%
% Usage:
%   gennrrd(filename, full_dir_path, z2spars)
%
% Args:
%   filename: file name
%   full_dir_path: full directory path
%   z2spars: input parameters

% generate target folder
oDir = z2spars.oDir;

if ~strcmp(oDir(end), filesep)
    oDir = [oDir, filesep];
end

if ~exist(oDir, 'dir')
    mkdir(oDir)
end

smooth_str = '';

if ~isempty(z2spars.sig) && ~isempty(z2spars.size)

    smooth_str = ['_ssiz', num2str(z2spars.size), ...
        'sig', num2str(z2spars.sig)];
    smooth_str = strrep(smooth_str, ' ', '');

end

filename_o_name = strrep(filename, [z2spars.fisuffix, z2spars.im_format], '');

% load image
fullfilename = fullfile([full_dir_path, filesep, filename]);

if strcmp(z2spars.im_format, '.nrrd')

    [Data, meta] = nrrdread(fullfilename);
    iXYZres = nrrdread_res(meta);

    % reshape flat image to X Y channel and Z
    siz = size(Data);
    Data = double(reshape(Data, ...
        [siz(1:2), z2spars.nchannels, ...
        prod(siz(3:end))/(z2spars.nchannels)]));

    % reorder to X Y Z and channel
    Data = permute(Data, [1 2 4 3]);

elseif strcmp(z2spars.im_format, '.nii')

    Data = niftiread(fullfilename);
    nifti_info = niftiinfo(fullfilename);
    iXYZres = nifti_info.PixelDimensions;
    iXYZres = iXYZres(1:3);

    % flip XY and channel to get X Y Z and channel
    Data = permute(Data, [2 1 3 5 4]);
    Data = double(Data);

end

% 1.1) reshape Data (necessary when it has 2 channels, all the cases)
fprintf('reshaping data, ')

% reduce number of channels or reorder channels prior to splitting them
Data = Data(:, :, :, z2spars.refcha);

% check if files already exist
status_ = [];
k = 1;

for t = 1:size(Data, 4)   
    
    oDir_ = [oDir, 'images_ch', num2str(t), filesep];
    
    if ~exist(oDir_, 'dir')
        mkdir(oDir_)
    end
    
    lname = [oDir_, filename_o_name, smooth_str, ...
        '_w_0', num2str(t), z2spars.im_format];
    status_(k) = ~exist(lname, 'file');
    k = k + 1;

    lname = [oDir_, filename_o_name, smooth_str, ...
        '_wm_0', num2str(t), z2spars.im_format];
    status_(k) = ~exist(lname, 'file');
    k = k + 1;
    
end

if sum(status_) || z2spars.redo
   
    % 1.2) flip in z axis
    if z2spars.zflipgate
        Data = flip(Data, 3);
    end
      
    % 1.3) find new spatial resolution
    if isempty(z2spars.oXYZres)
        z2spars.oXYZres = iXYZres;
    end
    
    % 1.4) smooth just up to the 2nd dimension
    %   hardcoded-pre smoothing to clean up the resampling
    if ~isempty(z2spars.sig) && sum(z2spars.oXYZres == iXYZres) ~= 3
        fprintf('smoothing data, ');
        Data = imblur(Data, z2spars.sig(1), 3, 2);
    end
    
    % 1.5) resample voxel size (z2spars.oXYZres: (width, height, depth))
    if sum(z2spars.oXYZres == iXYZres) ~= 3
        
        fprintf(['resample image, old(', ...
            num2str(iXYZres(1)), ' ', ...
            num2str(iXYZres(2)), ' ', num2str(iXYZres(3)), ...
            ') new(', num2str(z2spars.oXYZres(1)), ...
            ' ', num2str(z2spars.oXYZres(2)), ' ', ...
            num2str(z2spars.oXYZres(3)), ')\n']);
        Data = interp3DxT(Data, iXYZres, z2spars.oXYZres, 3);
        %interp3DxT(Data3DxT, XYZinit, XYZfinal, LastDim)
        % consider a more expensive one **

    end

    % 1.6) Smooth up to dimension defined by z2spars.size/z2spars.sig
    if ~isempty(z2spars.sig) && ~isempty(z2spars.size)
        
        fprintf('smoothing data, ')
        Data = imblur(Data, z2spars.sig, z2spars.size, ...
            max([length(z2spars.size), length(z2spars.sig)]));
       
    end
   
    % 1.7) pad image in Z (adds zero frames above and below)
    if z2spars.padgate
        
        fprintf('padding image, ')
        if length(size(Data)) == 3
            Data = padarray(Data, [0, 0, z2spars.padnum]); 
        else
            Data = padarray(Data, [0, 0, z2spars.padnum, 0]); 
        end
        
    end

    % 1.7) save nrrd/nifti images of each channel

    for t = 1:size(Data, 4)
        fprintf(['saving images channel ', num2str(t), ','])
        
        oDir_ = [oDir, 'images_ch', num2str(t), filesep];
        
        if ~exist(oDir_, 'dir')
            mkdir(oDir_)
        end
        
        tData = Data(:, :, :, t);
        
        % original
        lname = [oDir_, filename_o_name, ...
            smooth_str, '_w_0', num2str(t), z2spars.im_format];
        
        if strcmp(z2spars.im_format, '.nrrd')
            
            nrrdWriter(lname, mat2uint16(tData, 0), ...
                z2spars.oXYZres, [0 0 0], 'gzip');
        
        elseif strcmp(z2spars.im_format, '.nii')
            
            % permute to match acquisition axis
            tData = permute(tData, [2 1 3 4]);
    
            nifti_info.Filename = lname;
            nifti_info.SpaceUnits = 'Micron';
            nifti_info.ImageSize = size(tData);
            nifti_info.PixelDimensions = z2spars.oXYZres;
            nifti_info.Datatype = 'uint16';

            niftiwrite(mat2uint16(tData, 0), lname, nifti_info);
        
            tData = permute(tData, [2 1 3 4]);
            
        end
       
        % mirror
        if z2spars.mirror_flag
            
            if z2spars.mirror_flag == 1
                tData = flip(tData, 2);
            elseif z2spars.mirror_flag == 2
                tData = flip(tData, 1);
            end
            
            lname = [oDir_, filename_o_name, ...
                smooth_str, '_wm_0', num2str(t), z2spars.im_format];
            
            if strcmp(z2spars.im_format, '.nrrd')

                nrrdWriter(lname, mat2uint16(tData, 0), ...
                    z2spars.oXYZres, [0 0 0], 'gzip');

            elseif strcmp(z2spars.im_format, '.nii')

                % permute to match acquisition axis
                tData = permute(tData, [2 1 3 4]);

                nifti_info.Filename = lname;
                nifti_info.SpaceUnits = 'Micron';
                nifti_info.ImageSize = size(tData);
                nifti_info.PixelDimensions = z2spars.oXYZres;
                nifti_info.Datatype = 'uint16';

                niftiwrite(mat2uint16(tData, 0), lname, nifti_info);

            end
            
            clear tData
            
        end
        
    end
    
else
    
    fprintf('File already generated\n\n')
    
end

end

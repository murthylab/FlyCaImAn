function nrrd2nii(FolderName, FileName, iparams)
% nrrd2nii: function that converts nrrd images to nii an viceversa
%
% Usage:
%   nrrd2nii(FolderName, FileName, iparams)
%
% Args:
%   FolderName: Folder name to load
%   FileName: File name to load
%   ip: parameters to update
%       (im_direction: from which format to waht to do the conversion)
%           (default, 1, from nrrd 2 nii, 2 from nii to nrrd)
%       (dir_depth: depth of directory search)
%           (default, 1)
%       (nchannels: number of channels)
%           (2, default)

% Default iparams
z2spars.im_direction = 1;
z2spars.im_format = {'.nrrd', '.nii'};
z2spars.dir_depth = 1;
z2spars.nchannels = 2;

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

if z2spars.im_direction == 1
    z2spars.im_format = z2spars.im_format{1};
else
    z2spars.im_format = z2spars.im_format{2};
end

% define files to use
if z2spars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
       z2spars.im_format]);
elseif z2spars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', z2spars.im_format]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        z2spars.im_format]);
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
    im_convert(filename{i}, iDir{i}, z2spars);
    
end

fprintf('... Done\n')

end

function im_convert(filename, iDir, z2spars)
% im_convert: function converts each image file

filename_in = fullfile([iDir, filesep, filename]);

if strcmp(z2spars.im_format, '.nrrd')
    
    filename_out = strrep(filename_in, '.nrrd', '.nii');
    [Data, meta] = nrrdread(filename_in);
    iXYZres = nrrdread_res(meta);

    % reshape flat YXChZ image to 4D matrix YXChZ
    siz = size(Data);
    Data = double(reshape(Data, ...
        [siz(1:2), z2spars.nchannels, ...
        prod(siz(3:end))/(z2spars.nchannels)]));

    % reorder to X Y Z 1 and channel
    Data = permute(Data, [2 1 4 3]);

    siz = size(Data);
    
    % if more than on channel, pass channel to 5th dimension
    if numel(siz) > 3 && siz(4) > 1
        Data = reshape(Data, [siz(1:2), siz(3), 1, siz(4)]);
    end
    
    % create initial
    niftiwrite(mat2uint16(Data, 0), filename_out);
    
    % readout and edit metadata
    Data = niftiread(filename_out);
    
    nifti_info = niftiinfo(filename_out);
    nifti_info.SpaceUnits = 'Micron';
    nifti_info.Datatype = 'uint16';
    nifti_info.ImageSize = size(Data);
    nifti_info.PixelDimensions(1:3) = iXYZres;

    niftiwrite(mat2uint16(Data, 0), filename_out, nifti_info);

elseif strcmp(z2spars.im_format, '.nii')

    filename_out = strrep(filename_in, '.nii', '.nrrd');

    Data = niftiread(filename_in);
    nifti_info = niftiinfo(filename_in);
    iXYZres = nifti_info.PixelDimensions;
    iXYZres = iXYZres(1:3);

    % flip XY and channel to get Y X Z and channel
    Data = permute(Data, [2 1 3 5 4]);
    
    siz = size(Data);
    
    if numel(siz) > 3 && siz(4) > 1
        Data = reshape(Data, [siz(1:2), prod(siz(3:4))]);
    end
    
    nrrdWriter(filename_out, mat2uint16(Data, 0), ...
        iXYZres, [0 0 0], 'gzip');
                
end

end

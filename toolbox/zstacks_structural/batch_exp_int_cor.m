function batch_exp_int_cor(FolderName, FileName, iparams)
% batch_exp_int_cor: function that applies exponential intensity
%   correction to images per directory
%
% Usage:
%   batch_exp_int_cor(FolderName, FileName, iparams)
%
% Args:
%   FolderName: Folder name to load
%   FileName: File name to load
%   ipars: parameters to update
%       (fisuffix: file suffix)
%           ('', default)
%       (im_format: image format ".nrrd" or ".nii")
%           (default, '.nrrd')
%       (dir_depth: depth of directory search)
%           (default, 1)
%       (padval: value that is assumed to be padding)
%           (0, default)
%       (oDir: output directory)
%           (pwd, default)
%       (Lz: set the number of planes to ~ double (2.7183) CorIdx)
%           (100, default)
%       (z0: plane at which CorIdx == 1)
%           (0, default)
%       (depth_direction: direction of exponential increase)
%           (0, default, from 1 to end)
%           (1, from end to 1)

% Default iparams
ipars.fisuffix = '';
ipars.im_format = '.nrrd';
ipars.dir_depth = 1;
ipars.padval = 0;
ipars.oDir = '.';
ipars.Lz = 100;
ipars.z0 = 0;
ipars.depth_direction = 0;

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

ipars = loparam_updater(ipars, iparams);

% define files to use
if ipars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
       ipars.fisuffix, ipars.im_format]);
elseif ipars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', ipars.fisuffix, ipars.im_format]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        ipars.fisuffix, ipars.im_format]);
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
    correct_pefile(filename{i}, iDir{i}, ipars);
    
end

fprintf('... Done\n')

end

function correct_pefile(filename, full_dir_path, ipars)
% correct_pefile: correct each image
%
% Usage:
%   correct_pefile(filename, full_dir_path, ipars)
%
% Args:
%   filename: file name
%   full_dir_path: full directory path
%   ipars: input parameters

% generate target folder
oDir = ipars.oDir;

if ~strcmp(oDir(end), filesep)
    oDir = [oDir, filesep];
end

if ~exist(oDir, 'dir')
    mkdir(oDir)
end

% remove '.nrrd' from image
if contains(filename, ipars.im_format)
    filename = strrep(filename, ipars.im_format, '');
end

% load nrrd and smooth
[Data, meta] = nrrdread([full_dir_path, filesep, filename, ipars.im_format]);

Data = double(Data);
Data(Data == 0) = nan;

% generate exponential corrections
for z_i = 1:size(Data, 3)
    power_per_plane(z_i) = 1*exp((z_i - ipars.z0)/ipars.Lz);
end

% flip depth order
if ipars.depth_direction
    power_per_plane = flip(power_per_plane, 2);
end

power_per_plane = reshape(power_per_plane, ...
        [1 1 size(power_per_plane, 2)]);
Data = bsxfun(@times, Data, power_per_plane);
Data(isnan(Data)) = 0;

nrrdWriter([oDir, filesep, filename, '_intcor', ipars.im_format], ...
    mat2uint16(Data), nrrdread_res(meta), [0 0 0], 'gzip');

end

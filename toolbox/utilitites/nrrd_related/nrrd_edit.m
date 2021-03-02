function nrrd_edit(FolderName, FileName, iparams)
% nrrd_edit: function that edits nrrd voxel size, numerical type, and compress images.
%
% Usage:
%   nrrd_edit(FolderName, FileName, iparams)
%
% Args:
%   FolderName: nrrd metadata as output from nrrdread.m
%   FolderName: nrrd metadata as output from nrrdread.m
%   iparams: parameters to update
%       (XYZres: pixel resolution ('x y z', 'width height depth'))
%           (default, [])
%       (numtype: numerical type ('uint16', 'uint8'))
%           (default, [])
%       (compression: type of compresssion (gzip, or raw))
%           (default, [])
%       (planes2zero: set of planes to set to zero)
%           (default, [])
%       (dir_depth: depth of directory search)
%           (default, 0)

if ~exist('FileName','var')
    FileName = [];
end

if ~exist('FolderName','var')
    FolderName = [];
end

ipars.XYZres = [];
ipars.numtype = [];
ipars.compression = [];
ipars.fsuffix = '.nrrd';
ipars.planes2zero = [];
ipars.dir_depth = 0;

% update variables
if ~exist('iparams', 'var'); iparams = []; end
ipars = loparam_updater(ipars, iparams);

% define files to use
if ipars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
        ipars.fsuffix]);
elseif ipars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', ipars.fsuffix]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        ipars.fsuffix]);
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

fprintf(['Editing ', ...
    num2str(numel(filename)), ' files\n'])

% plot sMod results
for i = 1:numel(filename)

    editnrrd([iDir{i}, filesep, filename{i}], ipars);

end

fprintf('... Done\n')

end

function editnrrd(filename, ipars)
% editnrrd: edit each nrrd file
%
% Usage:
%   editnrrd(filename, ipars)
%
% Args:
%   filename: full file name
%   ipars: parameters to update
%       (XYZres: pixel resolution ('x y z', 'width height depth'))
%           (default, [])
%       (numtype: numerical type ('uint16', 'uint8'))
%           (default, [])
%       (compression: type of compresssion (gzip, or raw))
%           (default, [])
%       (dir_depth: depth of directory search)
%           (default, 0)

% load image
[Data, meta] = nrrdread(filename);

% update voxel size
if ~isempty(ipars.XYZres)
    
    fprintf(['updating voxel size from ', num2str(nrrdread_res(meta)), ...
        'to', num2str(ipars.XYZres), '\n'])
    
else
    
    ipars.XYZres = nrrdread_res(meta);
    
end

% update numeric type size
if ~isempty(ipars.numtype)
    
    numtype = ipars.numtype;
    
else
    
    numtype = 'uint16';
    
end

if ~isempty(ipars.planes2zero)
    Data(:, :, ipars.planes2zero) = 0;
end

switch numtype

    case 'uint16'

        Data = mat2uint16(Data, 1);

    case 'uint8'

        Data = mat2uint8(Data, 1);

end

fprintf(['Saving nrrd as ', numtype, '\n'])

if ~isempty(ipars.compression)
    
    compressiontype = ipars.compression;
    
else
    
    compressiontype = 'gzip';
    
end

fprintf(['Saving nrrd as ', compressiontype, '\n'])

nrrdWriter(filename, Data, ipars.XYZres, [0 0 0], compressiontype);

end

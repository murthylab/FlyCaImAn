function batch_threshold_ims(FolderName, FileName, iparams)
% batch_threshold_ims: function that thresholds images based on their
%   intensity. It is supervised, as the intensity thresholds need to be
%   manually set or tuned per image. It assumes that input images are
%   single channels.
%
% Usage:
%   batch_threshold_ims(FolderName, FileName, iparams)
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
%       (input_int_ths: set of intensity thresholds)
%           ([75 75 75 90 95], default)
%       (z_slices_per_int_ths: z slice number per input_int_ths)
%           ([0 100 130 170 200 240], default)
%       (z_slices_per_int_ths: z slice number per input_int_ths)
%           ([0 100 130 170 200 240], default)
%       (default_planes: planes to be plotted)
%           ([10 30 50 70 100 130 170 200 230], default)
%       (medfilt_flag: flag to do median filtering)
%           (0, default)
%       (medfilt: filter)
%           ([3 3 1], default)
%       (sig: kernel sigma for gaussian smoothing)
%           ([10 10 5], default)
%       (siz: kernel size for gaussian smoothing)
%           ([20 20 10], default)
%       (redo: redo flag)
%           ([0], default)
%
% Todo
%   generalize to nii

% Default iparams
ipars.fisuffix = '';
ipars.im_format = '.nrrd';
ipars.dir_depth = 1;
ipars.padval = 0;
ipars.oDir = ['.', filesep];
ipars.input_int_ths = [75 75 75 90 95];
ipars.z_slices_per_int_ths = [0 100 130 170 200 240];
ipars.default_planes = [10 30 50 70 100 130 170 200 230];
ipars.medfilt_flag = 0;
ipars.medfilt = [3 3 1];
ipars.sig = [10 10 5];
ipars.siz = [20 20 10];
ipars.redo = 0;

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
    threslholdims(filename{i}, iDir{i}, ipars);
    
end

fprintf('... Done\n')

end

function threslholdims(filename, full_dir_path, ipars)
% threslholdims: crop each image
%
% Usage:
%   threslholdims(filename, full_dir_path, ipars)
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

if strcmp(oDir(end), filesep)
    oDir = oDir(1:end-1);
end

% remove '.nrrd' from image
if contains(filename, ipars.im_format)
    filename = strrep(filename, ipars.im_format, '');
end

if ~exist([oDir, filesep, filename, ipars.im_format], 'file') || ipars.redo
    
    % load nrrd and smooth
    [Data, meta] = nrrdread([full_dir_path, filesep, filename, ipars.im_format]);

    % optional extra editing
    if ipars.medfilt_flag
        Data = medfilt3(double(Data), ipars.medfilt);
    end

    Data_smooth = double(Data);
    Data_smooth(ipars.padval >= Data_smooth) = nan;
    Data_smooth = imblur(Data_smooth, ipars.sig, ipars.siz, 3);
    im_size = size(Data_smooth);

    ipars.z_slices_per_int_ths(end) = im_size(end);

    [Data_mask, ipars.int_ths_per_z] = generate_binary_mask(ipars.input_int_ths, ...
        ipars.z_slices_per_int_ths, Data_smooth);

    % plot results so far
    displayresults(Data_smooth, Data_mask, ipars)

    % Edit manually input_int_ths by looking at the intensity in plotted planes
    edit threshold_ims_maninput
    keyboard

    % save image
    if ipars.medfilt_flag
        Data = Data.*double(Data_mask);   
    else
        Data = Data.*uint16(Data_mask);   
    end

    nrrdWriter([oDir, filesep, filename, ipars.im_format], ...
        mat2uint16(Data), nrrdread_res(meta), [0 0 0], 'gzip');

end

end

function [input_im, int_ths_per_z] = generate_binary_mask(input_int_ths, ...
    z_slices_per_int_ths, input_im)
% generate_binary_mask: threshold images with many intensity values per group of
%   planes.
%
% Usage:
%   thresholdIm(input_im_name, output_im_name, input_int_ths, ...
%       outputType, min_obj_size, input_im_dir, output_im_dir, padn, ...
%       z_slices_per_int_ths, min_size_type, padval, paddirrection, im2mask_name)
%
% Args:
%   input_int_ths: set of intensity thresholds
%   z_slices_per_int_ths: z slice number per input_int_ths
%       default([0 size(Data, 3)])
%   input_im: input image to threshold

int_ths_per_z = zeros(size(input_im, 3), 1);

% Intensity Thresholding
for i = 1:numel(input_int_ths)
    
    %threshold based on intensity
    temp_ = input_im(:, :, (z_slices_per_int_ths(i)+1):(z_slices_per_int_ths(i+1)));
    temp_(temp_ <= input_int_ths(i)) = 0;
    
    % delete small objects
    l_cs = bwconncomp(temp_ > 0);
    c_siz = cellfun(@numel, l_cs.PixelIdxList)';
    
    % use the largest component
    pix2del = find(c_siz ~= max(c_siz));
    pix2del = cell2mat(l_cs.PixelIdxList(pix2del)');
    temp_(pix2del) = 0;
    input_im(:, :, (z_slices_per_int_ths(i)+1):(z_slices_per_int_ths(i+1))) = temp_;
    clear temp_ l_cs c_siz pix2del
    
    % save intensity threshold
    int_ths_per_z((z_slices_per_int_ths(i)+1):(z_slices_per_int_ths(i+1))) = ...
        input_int_ths(i);

end

% output the mask
input_im(input_im > 0) = 1;

end

function displayresults(Data_smooth, Data_mask, ipars)
% displayresults: plot image intensity per plane and contour of mask
%
% Usage:
%   displayresults(Data_smooth, Data_mask, ipars)
%
% Args:
%   Data_smooth: image used to generate binary mask
%   Data_mask: binary mask
%   ipars: input parameters

% plot results so far
figH = figure('Position', genfigpos(1, [], [1600 900]));
colormap(jet)

for i = 1:numel(ipars.default_planes)
    
    axH(i) = subplot(3, 3, i);
    imagesc(Data_smooth(:, :, ipars.default_planes(i)), 'Parent', axH(i));
    hold(axH(i), 'on')
    contour(Data_mask(:, :, ipars.default_planes(i)) > 0, 1, ...
        'color', 'k', 'Linewidth', 2, 'Parent', axH(i));
    axH(i).Title.String = ['Plane ', num2str(ipars.default_planes(i)), ...
        ' Int ths: ', num2str(ipars.int_ths_per_z(ipars.default_planes(i)))];
    colorbar(axH(i))
    
end

end

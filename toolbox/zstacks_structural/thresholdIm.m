function thresholdIm(input_im_name, output_im_name, input_int_ths, ...
    outputType, min_obj_size, input_im_dir, output_im_dir, padn, ...
    z_slices_per_int_ths, min_size_type, padval, paddirrection, im2mask_name)
% thresholdIm: threshold images with many intensity values per group of
%   planes, and shifts image in XYZ, saves image as nrrd
%
% Usage:
%   thresholdIm(input_im_name, output_im_name, input_int_ths, ...
%       outputType, min_obj_size, input_im_dir, output_im_dir, padn, ...
%       z_slices_per_int_ths, min_size_type, padval, paddirrection, im2mask_name)
%
% Args:
%   input_im_name: full name of input image to edit
%   output_im_name: full name of output image to edit
%   input_int_ths: set of intensity thresholds
%   outputType: type of image to save
%       default(0, saves thresholded Im, 1, saves mask, 2 saves im2mask_name using mask generated)
%   min_obj_size: minimun size of objects to keep as ratio from whole volume
%       default(0.1)
%   input_im_dir: directory of input image to edit
%       default('.')
%   output_im_dir: directory of output image to edit
%       default('.')
%   padn: number of pixels to pad per dimension
%       default([0 0 0])
%   z_slices_per_int_ths: z slice number per input_int_ths
%       default([0 size(Data, 3)])
%   min_size_type: flag to use min_obj_size or just pick the biggest obj
%       default([])
%   padval: value to use for padding
%       default(0)
%   paddirrection: direction of padding
%       default('pre')
%   im2mask_name: full name of image to mask
%       default([])

if ~exist('outputType', 'var') || isempty(outputType)
    outputType = 0;
end

if ~exist('min_obj_size', 'var') || isempty(min_obj_size)
    min_obj_size = 0.1;
end

if ~exist('input_im_dir', 'var') || isempty(input_im_dir)
    input_im_dir = '.';
end

if ~exist('output_im_dir', 'var') || isempty(output_im_dir)
    output_im_dir = '.';
end

if ~exist('padn', 'var') || isempty(padn)
    padn = 0;
end

if ~exist('z_slices_per_int_ths', 'var') || isempty(z_slices_per_int_ths)
    z_slices_per_int_ths = [];
end

if ~exist('min_size_type', 'var') || isempty(min_size_type)
    min_size_type = [];
end

if ~exist('padval', 'var') || isempty(padval)
    padval = 0;
end

if ~exist('paddirrection', 'var') || isempty(paddirrection)
    paddirrection = 'pre';
end

if ~exist('im2mask_name', 'var') || isempty(im2mask_name)
    im2mask_name = [];
end

% remove '.nrrd' from image
if contains(input_im_name, '.nrrd')
    input_im_name = strrep(input_im_name, '.nrrd', '');
end

if contains(output_im_name, '.nrrd')
    output_im_name = strrep(output_im_name, '.nrrd', '');
end

% Load Im
[Data, meta] = nrrdread(fullfile([input_im_dir, filesep, input_im_name, '.nrrd']));
Data = double(Data);
iRes = nrrdread_res(meta);

if isempty(z_slices_per_int_ths)
    z_slices_per_int_ths = [0 size(Data, 3)];
end

% Intensity Thresholding
for i = 1:numel(input_int_ths)
    
    %threshold based on intensity
    temp_ = Data(:, :, (z_slices_per_int_ths(i)+1):(z_slices_per_int_ths(i+1)));
    temp_(temp_ <= input_int_ths(i)) = 0;
    
    % delete small objects
    l_cs = bwconncomp(temp_ > 0);
    c_siz = cellfun(@numel, l_cs.PixelIdxList)';
    
    if min_size_type == 1
        pix2del = find(c_siz < min_obj_size*numel(temp_));
    else
        pix2del = find(c_siz ~= max(c_siz));
    end
    
    pix2del = cell2mat(l_cs.PixelIdxList(pix2del)');
    temp_(pix2del) = 0;
    Data(:, :, (z_slices_per_int_ths(i)+1):(z_slices_per_int_ths(i+1))) = temp_;
    clear temp_ l_cs c_siz pix2del
    
end

% Image to save
editIm = 1; % gate to scale values to 2^16 if <= 1
med_siz = 3; % size of median filter (pixels)

if outputType == 1
    
    % Saves the mask itself
    Data(Data > 0) = 1;
    Data = medfilt3(Data, [med_siz med_siz med_siz]);
    editIm = 0;
    
elseif outputType == 2

    if contains(im2mask_name, '.nrrd')
        im2mask_name = strrep(im2mask_name, '.nrrd', '');
    end
    
    % load image to be masked (assumes images have the same dimensions and resolution)
    [temp, ~] = nrrdread(fullfile([input_im_dir, filesep, im2mask_name, '.nrrd']));
    Data = double(temp).*(Data > 0);

    editIm = 0;
    
end

% shift image in Z, direction is from XYZ = [0,0,0] to [n,n,n]
dDim = size(Data);
if sum(padn) ~= 0
    Data = padarray(Data, padn, padval, paddirrection);
    Data = Data(:, :, 1:dDim(3));
end

% save Data
nrrdWriter([output_im_dir, filesep, output_im_name, '.nrrd'], ...
    mat2uint16(Data, editIm), iRes, [0 0 0], 'gzip');

end

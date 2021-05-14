function batch_zstacktiff2mat(FolderName, FileName, iparams)
% batch_zstacktiff2mat: parse and converts tiff files (in a zstack
% structure) to mat files (files with *Zstack pattern)
%
% Usage:
%   batch_zstacktiff2mat(FolderName, FileName, iparams)
%
% Args:
%   FolderName: folders to use (name)
%   FileName: files to use (name)
%   iparams: parameters
%       (fo2reject: folders to reject)
%           (default, {'.', '..', 'colldata', 'BData', 'preprocessed'})
%       (FileName: files to use)
%       (FieldOfView: field of view of microscope)
%           (default, 768 um)
%       (suffix: pattern of files to use)
%           (default, 'Zstack_*_*.tif')
%       (ch2save: channels to save ([1 2], red and green))
%           (default, [1 2])
%       (SpMode: type of data (3DxT))
%       (ths: intensity threshold, to detect frames where PMTs went off)
%           (default, 55)
%       (unitres: number of decimals to keep)
%           (default, 10^4)
%       (format: nrrd format raw vs gzip ('gzip'))
%           (default, 'gzip')
%       (im_format: image format ".nrrd" or ".nii")
%           (default, '.nrrd')
%       (redo: gate to overwrite old files)
%           (default, 0)
%       (zres: resolution in z axis)
%           (default, 1)
%       (pixelsym: pixel size is symmetric or not, 0 = asymmetric, 1 = symmetric)
%           (default, 0)
%       (integrate_flag: number of timepoints to integrate as single 
%           timepoint before averaging across timepoints)
%           (default, 1)
%       (shift_f: shift distribution of F to the positive side)
%           (default, [5 5])
%       (hbins: range to generate histogram plot)
%           (default, -10^3:3*10^3)
%       (oDir: directory where to save histogram plot)
%           (default, [pwd, filesep, 'rawtiff'])
%       (dimOrder: order of dimensions time (t) then slice (z))
%           (default: 'zt', alternative 'tz')
%       (debug_flag: flag to evaluate results prior to saving)
%           (default: 1)
%       (maxtiff2load: maximun tiffs to load per session)
%           (default: [])
%
% Notes:
%   FieldOfView needs to be define for each setup (see batch_tiff2mat.m)

zt2m = []; 
zt2m.cDir = pwd;
zt2m.fo2reject = {'.', '..', 'colldata', 'BData', 'preprocessed'};
zt2m.FileName = []; 
zt2m.FieldOfView = 768;
zt2m.suffix = 'Zstack_*_*.tif';
zt2m.ch2save = [1 2]; 
zt2m.SpMode = '3DxT'; 
zt2m.ths = 55;
zt2m.unitres = 10^4;
zt2m.format = 'gzip';
zt2m.im_format = '.nrrd';
zt2m.redo = 0;
zt2m.zres = 1;
zt2m.pixelsym = 0;
zt2m.integrate_flag = 1;
zt2m.shift_f = [5 5];
zt2m.hbins = -10^3:3*10^3;
zt2m.oDir = [pwd, filesep, 'rawtiff'];
zt2m.dimOrder = 'zt';
zt2m.debug_flag = 0;
zt2m.maxtiff2load = [];

if ~exist('FolderName', 'var'); FolderName = []; end
if ~exist('FileName', 'var'); FileName = []; end
if ~exist('iparams', 'var'); iparams = []; end
zt2m = loparam_updater(zt2m, iparams);

fprintf('Running Tiff2Mat for Zstack\n');

if ~isempty(zt2m.oDir) && ...
        ~exist(zt2m.oDir, 'dir')
    mkdir(zt2m.oDir)
end

% finding folders and filtering out data that is not selected
fo2run = dir;
fo2run = str2match(FolderName, fo2run);
fo2run = str2rm(zt2m.fo2reject, fo2run);
fo2run = {fo2run.name};

fprintf(['Running n-folders : ', num2str(numel(fo2run)), '\n'])

fprintf(['Running n-folders : ', num2str(numel(fo2run)), '\n'])

for folder_i = 1:numel(fo2run)
    
    fprintf(['Running folder : ', fo2run{folder_i}, '\n']);
    cd(fo2run{folder_i}); 
    zt2m.Folder2Run = fo2run{folder_i};
    runperfolder(FileName, fo2run{folder_i}, zt2m);
    cd(zt2m.cDir)
    
end

fprintf('... Done\n')

end

function runperfolder(fname, foname, zt2m)
% runperfolder: function 
%
% Usage:
%   runperfolder(fname, foname, tifpars)
%
% Args:
%   fname: file name
%   foname: folder name
%   zt2m: parameters

% checking files inside folder
[BaseFName, ~, ~] = ...
    rdir_namesplit([], zt2m.suffix, [], [], fname, 3);
BaseFName = unique(BaseFName);

fprintf(['Running Folder : ', num2str(foname), ...
    ' (n-exp-types, ', num2str(numel(BaseFName)), ') ,'])

% running each exptype (basename)

% get unique flynum and fly-trials per basename
for basename_i = 1:numel(BaseFName)

    [~, AnimalNum, TrialNum, str_length] = ...
        rdir_namesplit(BaseFName(basename_i), ...
        zt2m.suffix, [], [], fname, 3);

    % get the number of trials per unique AnimalNum and basename
    for ani_i = unique(AnimalNum)

        % plot results (intensity)
        zt2m.figH = figure();
        zt2m.AxH(1) = subplot(2, 1, 1);
        zt2m.AxH(2) = subplot(2, 1, 2);
        zt2m.figH.Name = [BaseFName{basename_i}, '-', num2str(ani_i)];
        
        TrialPerAnimal = TrialNum(AnimalNum == ani_i);
        str_length_i = str_length(AnimalNum == ani_i, :); 
        
        if isempty(TrialPerAnimal)

            fprintf(['Does not have any file with', ...
                ' flynumber :', num2str(ani_i), ' \n'])

        else

            [Trial2Load, idx2use] = unique(TrialPerAnimal);
            str_length_i = str_length_i(idx2use, :);
            clear idx2use
            
            fprintf([' (n-trials, ', ...
                num2str(unique(TrialPerAnimal)), ')\n']);

            for trial_i = 1:numel(Trial2Load)

                % collapsing all timepoints and z-slices to 1 mat file
                animal_str = sprintf(['%0', ...
                    num2str(str_length_i(trial_i, 2)), 'd'], ani_i);
                trial_str = sprintf(['%0', ...
                    num2str(str_length_i(trial_i, 3)), 'd'], Trial2Load(trial_i));
                
                NameRoot = [BaseFName{basename_i}, '_', ...
                        animal_str, '_Zstack_', trial_str, '_'];
                im_name = [BaseFName{basename_i}, '_', ...
                        num2str(ani_i), '_Zstack_', ...
                        num2str(Trial2Load(trial_i))];
                    
                if ~exist([im_name, zt2m.im_format], 'file') || zt2m.redo

                    tic;
                    collalltrials(NameRoot, zt2m);
                    clear rootname;
                    toc

                else

                    fprintf(['File ', im_name, ...
                        zt2m.im_format, ' already exist - skipping \n'])

                end

            end 

        end

    end

    clear AnimalNum TrialNum str_length

end

end

function collalltrials(tif_name, zt2m)
% collalltrials: parse all tiffs with 'rootname*.tif', 
%   average trials, and generate a 3D matrix
%
% Usage:
%   collalltrials(tif_name, zt2m)
%
% Args:
%   tif_name: suffix of tif files to use
%   zt2m: input params
%       (FieldOfView: 768 um, hard coded constant (microscope dependent variable)
%       (FileName: files to use)
%       (Folder2Run: current folder)
%       (ch2save: channels to save ([1 2], red and green))
%       (SpMode: type of data (3DxT))
%       (ths: intensity threshold)
%       (unitres: number of decimals to keep (10^4))
%       (format: nrrd format raw vs gzip ('gzip'))
%       (zres: resolution in z axis (1))
%
% Notes:

% generate mat file names (remove zero padding

[Basename, AnimalNum, TrialNum, str_length] = ...
        rdir_namesplit(tif_name, ...
        zt2m.suffix, [], [], [], 3);
mat_name = [Basename{1}, '_', ...
    num2str(AnimalNum(1)), '_Zstack_', ...
    num2str(TrialNum(1))];

% define the number of tiffs to load per session/experiment
if isempty(zt2m.maxtiff2load)
    tif_num = numel(rdir([tif_name, '*.tif']));
else
    tif_num = zt2m.maxtiff2load;
end

% tif start number
if exist([tif_name, ...
        sprintf(['%0', num2str(str_length(1, 3)), 'd'], 0), ...
        '.tif'], 'file')
    start_n = 0;
else
    start_n = 1;
end

% remove last underline
tif_name = tif_name(1:end-1);
Data = []; 

fprintf(['n-repts = ', num2str(tif_num), '\n']) 

for tif_i = 1:tif_num
    
    tif_idx = tif_i + start_n - 1;
    tif_idx = sprintf(['%0', num2str(str_length(tif_i, 3)), 'd'], tif_idx);  
    
    % load and concatenate all files
    try
        
        [tempdata, ImMeta] = ...
            tiff2mat_scanimage([tif_name, '_', tif_idx], zt2m.SpMode, 1);
        
        % tiff2mat_scanimage output is always 4D (X, Y, frame, pmt)
        Data = cat(3, Data, tempdata);
        clear tempdata;
        
    end
    
    fprintf('*');
    
    if mod(tif_i, 60) == 0 || ...
            tif_i == tif_num
        fprintf('\n');
    end
    
end

clear rep_i t_num
fprintf(['Channels imported: ',num2str(ImMeta.ChNum), '\n'])

% update ImMeta, prune Data (ch)
% Selecting channel to save

ch_num = size(Data, 4);

if ch_num > 1
    
    if length(zt2m.ch2save) < 2
        Data = squeeze(Data(:, :, :, zt2m.ch2save)); 
        fprintf([' collecting just channel ', num2str(zt2m.ch2save)])
    end
    
end

clear ch_num
fprintf(['Data original size: ', num2str(size(Data)), '\n'])

% get histograms
for i = 1:size(Data, 4)
    temp_data = Data(:, :, :, i);
    temp_data = temp_data(:);
    [hist_pre(:, i), ~] = hist(temp_data, zt2m.hbins);
    clear temp_data
end

if zt2m.debug_flag
    
    % plot histograms with current settings (zt2m.hbins)
    plot_histogram(zt2m.hbins, hist_pre, hist_pre, zt2m.oDir, 'test')
    
    keyboard
    % pause to decide if manually update 'zt2m.shift_f' and/or 'zt2m.hbins'
    
end

% shift distribution by 5 values to the right and make negative values 0
Data(:, :, :, 1) = ...
    Data(:, :, :, 1) + zt2m.shift_f(1);
if length(size(Data)) > 3
    Data(:, :, :, 2) = ...
        Data(:, :, :, 2) + zt2m.shift_f(2);
end
Data(Data < 0) = 0;
ImMeta.RepeatNum = floor(size(Data, 3)/ImMeta.Z); 
ImMeta.FrameNum = ImMeta.Z;

% get histograms
for i = 1:size(Data, 4)
    temp_data = Data(:, :, :, i);
    temp_data = temp_data(:);
    [hist_post(:, i), ~] = hist(temp_data, zt2m.hbins);
    clear temp_data
end

% resize Data
siz = size(Data);

try
    siz(5) = siz(4); 
catch
    siz(5) = 1; 
end

if strcmpi(zt2m.dimOrder, 'zt')
    siz(3) = ImMeta.FrameNum; 
    siz(4) = ImMeta.RepeatNum;
elseif strcmpi(zt2m.dimOrder, 'tz')
    siz(3) = ImMeta.RepeatNum;   
    siz(4) = ImMeta.FrameNum; 
end

Data = Data(:, :, 1:siz(4)*siz(3), :);

% integrate signal over time
if zt2m.integrate_flag > 1
    
    fprintf('integrate signal over time\n')

    new_vol_num = floor(siz(4)/zt2m.integrate_flag);

    preData = Data(:, :, ...
        1:(siz(3)*zt2m.integrate_flag*new_vol_num), :);
    preData = reshape(preData, [siz(1:2), siz(3), ...
        zt2m.integrate_flag, new_vol_num, siz(5)]);
    preData = squeeze(sum(preData, 4));

    Data = preData;
    siz(4) = new_vol_num;
    Data = reshape(Data, [siz(1:2), siz(4)*siz(3), siz(5)]);
    
end

% get average signal
fprintf('Averaging volumes\n')
Data = avbrain(Data, zt2m.ths, siz, zt2m.shift_f, ...
    zt2m.dimOrder, zt2m.AxH, zt2m.debug_flag);

Data = permute(Data, [1 2 4 3]);
ImMeta.FrameNum = size(Data, 4);

fprintf(['Data final size: ',num2str(size(Data)), '\n'])
eval(['Data = ', ImMeta.Imclass, '(Data);'])

premaxRed = max(Data(:, :, :, 1), [], 3); 
try 
    preMaxGreen = max(Data(:, :, :, 2), [], 3);
catch
    preMaxGreen = nan;
end

display(['Max val per channel ', ...
    num2str([max(premaxRed(:)), max(preMaxGreen(:))])])

% generate metadata

[fDat, iDat] = generatemetadata(mat_name, ImMeta, zt2m);
width_height_depth = iDat.MetaData{3};

% plot histograms
plot_histogram(zt2m.hbins, hist_pre, hist_post, zt2m.oDir, fDat.FileName)

siz = size(Data); 
Data = reshape(Data, [siz(1:2), prod(siz(3:4))]);

% save data as nrrd image
if strcmp(zt2m.im_format, '.nrrd')
    
    nrrdWriter([mat_name, zt2m.im_format], mat2uint16(Data, 0), ...
        width_height_depth, [0 0 0], zt2m.format);
    
elseif strcmp(zt2m.im_format, '.nii')

    % permute to match acquisition axis
    Data = permute(Data, [2 1 3 4]);
    
    % create initial
    niftiwrite(mat2uint16(Data, 0), [mat_name, zt2m.im_format]);
    
    % readout and edit metadata
    Data = niftiread(fullfile([mat_name, zt2m.im_format]));
    nifti_info = niftiinfo(fullfile([mat_name, zt2m.im_format]));
    nifti_info.SpaceUnits = 'Micron';
    nifti_info.Datatype = 'uint16';
    nifti_info.ImageSize = size(Data);
    nifti_info.PixelDimensions = width_height_depth;

    niftiwrite(mat2uint16(Data, 0), [mat_name, zt2m.im_format], ...
        nifti_info);
    
end

% save metadata
save([zt2m.cDir, filesep, zt2m.Folder2Run, filesep, ...
    fDat.FileName, '_metadata.mat'], 'fDat', 'iDat')

clear Data iDat fDat ImMeta

end

function [fDat, iDat] = generatemetadata(t_fname, ImMeta, zt2m)
% generatemetadata: Loading existing metadata, Load matfile asociated with this tiff file
% Usage:
%   [fDat, iDat] = generatemetadata(t_fname, ImMeta, zt2m)
%
% Args:
%   t_fname: folders to use (name)
%   ImMeta: image intensity threshold
%   zt2m: input params
%       (FieldOfView: 768 um, hard coded constant (microscope dependent variable)
%       (Folder2Run: current folder)
%       (SpMode: type of data (3DxT))
%       (ths: intensity threshold)
%       (unitres: number of decimals to keep (10^4))
%       (zres: resolution in z axis (1))
%
% Notes:

try
    load([zt2m.cDir, filesep, zt2m.Folder2Run, ...
        filesep, t_fname, '.mat'], 'fDat', 'iDat');
end

% fDat
fDat.FileName = strprune(t_fname, '_', 3); 
fDat.FolderOrigin = zt2m.cDir;
fDat.FolderTrace = zt2m.cDir((max(strfind(zt2m.cDir, filesep)) + 1):end);
fDat.DataType = zt2m.SpMode; 
fDat.fName = []; 

if ~exist('iDat', 'var')
    fprintf('writing new iDat\n');
    iDat = struct('MetaData', [], 'ZoomFactor', ImMeta.Zoom);
end

% if Zres provided by scanimage then read that value
if isfield(ImMeta, 'Z_stepsiz') && ~isempty(ImMeta.Z_stepsiz)
    Zres = abs(ImMeta.Z_stepsiz);
    fprintf(['Z step size provided by scanimage: ', ...
        num2str(Zres), ' um \n'])
else
    Zres = zt2m.zres;
end

% overwrite pixel symmetry flag if not provided by tiff
if ~isfield(ImMeta, 'sympixels') || ...
        (isfield(ImMeta, 'sympixels') && ...
        isempty(ImMeta.sympixels))
   ImMeta.sympixels = zt2m.pixelsym;
end

% pixel size (symmetric or not)
if ImMeta.sympixels == 0
    
    iDat.MetaData = {'voxelsize', 'x y z', ...
        round([zt2m.FieldOfView/(ImMeta.Zoom*ImMeta.X), ...
        zt2m.FieldOfView/(ImMeta.Zoom*ImMeta.Y), ...
        Zres]*zt2m.unitres)/zt2m.unitres};
    
else
    
    iDat.MetaData = {'voxelsize', 'x y z', ...
        round([zt2m.FieldOfView/(ImMeta.Zoom*ImMeta.X), ...
        zt2m.FieldOfView/(ImMeta.Zoom*ImMeta.X), ...
        Zres]*zt2m.unitres)/zt2m.unitres};
    
end

iDat.FrameN = ImMeta.FrameNum; 
iDat.StackN = ImMeta.RepeatNum;

%[lines, pixels per line, slices] [height width depth] [y, x, z]
iDat.FrameSize = [ImMeta.Y, ImMeta.X];

iDat.Power = ImMeta.Power; 
iDat.f_ths = zt2m.ths;

% add rate variables (in Hz)
iDat.framerate = ImMeta.framerate;
iDat.volumerate = ImMeta.volumerate;

end

function avgim = avbrain(im, im_ths, isiz, shift_f, dimOrder, axH, debug_flag)
% avbrain: get the average image of green and red channel
%
% Usage:
%   avgim = avbrain(im, im_ths, isiz, shift_f, axH, debug_flag)
%
% Args:
%   im: folders to use (name)
%   im_ths: image intensity threshold
%   isiz: image size
%   shift_f: shift in F added.
%   dimOrder: order of dimensions time (t) then slice (z)
%   	(default: 'zt', alternative 'tz')
%   axH: axis handle
%   debug_flag: debug flag
%
% Notes:

% reshape volume to be have this order: x,y,z,t,channel
if strcmpi(dimOrder, 'tz')
    im = reshape(im, isiz);
    im = permute(im, [1 2 4 3 5]);
    isiz([3 4]) = isiz([4 3]);
    im = reshape(im, [isiz(1:2) prod(isiz(3:4)) isiz(5)]);
end

% get max per frame (both channels)
maxpertime_r = squeeze(max(max(im(:, :, :, 1), [], 1), [], 2));
if isiz(end) > 1
    maxpertime_g = squeeze(max(max(im(:, :, :, 2), [], 1), [], 2)); 
end

im = reshape(im, isiz);

maxpertime_r = reshape(maxpertime_r, isiz([3 4]));
if isiz(end) > 1
    maxpertime_g = reshape(maxpertime_g, isiz([3 4]));
end

% remove flyback planes
im(:, :, 1, :, :) = [];
maxpertime_r(1, :) = [];
try maxpertime_g(1, :) = []; end

% plot max's
plot(maxpertime_r(:), 'r', 'Parent', axH(2));
try plot(maxpertime_g(:), 'g', 'Parent', axH(1)); end
hold(axH(1), 'on'); hold(axH(2), 'on')

% generate average brain
avgim = inf(size(im, 1), size(im, 2), size(im, 3), size(im, 5));

if size(im, 4) == 1
    slice_n = 1;
else
    slice_n = 2;
end

for z = 1:size(im, 3)
    
    if sum((maxpertime_r(z, :)) > im_ths) >= slice_n
        avgim(:, :, z, 1) = mean(squeeze(im(:, :, z, ...
            (maxpertime_r(z, :)) > im_ths, 1)), 3);
    end
    
    if isiz(end) > 1
        if sum((maxpertime_g(z, :)) > im_ths) >= slice_n
            avgim(:, :, z, 2) = mean(squeeze(im(:, :, z, ...
                (maxpertime_g(z, :)) > im_ths, 2)), 3);
        end
    end
    
end

% find Inf planes and debug them

M = squeeze(max(max(avgim, [], 1), [], 2));

if sum(isinf(M(:))) ~= 0 || ...
        (sum(M(:) > 2048 + min(shift_f)) ~= 0) ...
        || debug_flag
    
    % for dealing with this exceptions use:
    
    edit zstacktiff2mat_maninput.m
    keyboard
    
end

end

function plot_histogram(hbins, hist_pre, hist_post, oDir, filename)
% plot_histogram: function to plot histograms
%
% Usage:
%   plot_histogram(hbins, hist_pre, hist_post, oDir, filename)
%
% Args:
%   hbins: histogram bins
%   hist_pre: histogram pre shift
%   hist_post: histogram post shift
%   oDir: output directory
%   filename: filename
%
% Notes:

% plot figure
figH = figure('position', genfigpos(1, 'center', [1000 700]));
axH(1) = subplot(2, 2, 1);
axH(2) = subplot(2, 2, 3);
axH(3) = subplot(2, 2, 2);
axH(4) = subplot(2, 2, 4);
color_vect = [1 0 0; 0 0.5 0];
strH = [];

% plot traces
for i = 1:size(hist_pre, 2)
    
    lineH(i) = plot(hbins, hist_pre(:, i), ...
        'Color', color_vect(i, :), ...
        'Parent', axH(1));
    hold(axH(1), 'on')
    
    plot(hbins, hist_pre(:, i), ...
        'Color', color_vect(i, :), ...
        'Parent', axH(2))
    hold(axH(2), 'on')
        
    plot(hbins, hist_post(:, i), ...
        'Color', color_vect(i, :), ...
        'Parent', axH(3));
    hold(axH(3), 'on')
    
    plot(hbins, hist_post(:, i), ...
        'Color', color_vect(i, :), ...
        'Parent', axH(4))
    hold(axH(4), 'on')
    
    strH{i} = ['cha-', num2str(i)];
    
end

% add labels
axH(1).XLabel.String = 'F (a.u)';
axH(2).XLabel.String = 'F (a.u)';
axH(3).XLabel.String = 'F (a.u)';
axH(4).XLabel.String = 'F (a.u)';

axH(1).YLabel.String = 'Count';
axH(2).YLabel.String = 'Count';
axH(3).YLabel.String = 'Count';
axH(4).YLabel.String = 'Count';

axH(2).YScale = 'log';
axH(4).YScale = 'log';
axH(1).XLim = hbins([1 end]);
axH(2).XLim = hbins([1 end]);
axH(3).XLim = hbins([1 end]);
axH(4).XLim = hbins([1 end]);

legH = legend(axH(1), lineH, strH);

% figure format
figformat = [1 0 0 0 0 0 0 0 1];
resolution_ = '-r300';

% save figure
figEdit(axH, figH);
savefig_int(figH, oDir, [filename, '_hist'], ...
    figformat, resolution_);
close(figH)

end

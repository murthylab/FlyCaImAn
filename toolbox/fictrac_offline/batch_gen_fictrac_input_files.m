function batch_gen_fictrac_input_files(...
    FolderName, FileName, setupID, im_mode)
% batch_gen_fictrac_input_files: function that generates ball mask, optionally
%   extracts example frame from video, generates calibration-transform.dat
%   file, and copies *_config.txt files to local directory.
%
% Usage:
%	batch_gen_fictrac_input_files(...
%       FolderName, FileName, setupID, im_mode)
%
% Args:
%   FolderName: name of folder to run
%   FileName: name of file to run
%   setupID: ID of setup used
%       (Alevel_2p1, default)
%       (bezos_2p, Alevel_behav)
%   im_mode: mode of finding input files
%       (0, use tif)
%       (1, extract rawim from mp4/avi)
%
% Notes:
% Based on a function written by Dudi Deutsch.
% Uses function from
%   https://www.mathworks.com/matlabcentral/fileexchange/5557-circle-fit (already in utilities)
% Calculating VFOV
%   Use a ruler and:
%   1.1) calculate distance from camera to ruler
%       distance_ = 18; % cm;
%   1.2) measure the height of the FOV (using the ruler, see camera_fov_callibration.jpg)
%       height_ = 0.82; % cm;
%   2) get the angle
%       vfov = radtodeg(2*atan(height_/(2*distance_))) = 2.6097;
%   This example comes from a ROI of 882 x 992 [height width]
%       if using full FOV 1024 x 1280 [height width], then height_ = 0.9520 % cm
%       and vfov = 3.0296
%   if cropping FOV update calculation
%       (put ruler in focal point and measure distance between pixels)
%   if using the same camera the height_ might change depending on final zoom used with lenses.   
%
% See also gen_fictrac_calibration_transform.m

if ~exist('FolderName', 'var')
   FolderName = [];
end

if ~exist('FileName', 'var')
   FileName = [];
end

if ~exist('im_mode', 'var')
   im_mode = 0;
end

if ~exist('setupID', 'var')
   setupID = 'Alevel_2p1';
end

fo2reject = {'.', '..', 'preprocessed', ...
    'BData', 'motcor', 'rawtiff', 'stitch'};

cDir = pwd;

% add setup and corresponding vfov
allsetupIDs = {'bezos_2p', 'Alevel_2p1', 'Alevel_behav'};
settingpersetup(1).vfov = deg2rad(2.15);
settingpersetup(2).vfov = deg2rad(2.6097);
settingpersetup(3).vfov = deg2rad(3.8183);

% select settings given an input setup
settingpersetup = ...
    settingpersetup(contains(allsetupIDs, setupID));

% finding folders and filtering out data that is not selected
fo2run = dir;
fo2run = str2match(FolderName, fo2run);
fo2run = str2rm(fo2reject, fo2run);
fo2run = {fo2run.name};

fprintf(['Running n-folders : ', num2str(numel(fo2run)), '\n'])

for folder_i = 1:numel(fo2run)
    
    fprintf(['Running folder : ', fo2run{folder_i}, '\n']);
    cd(fo2run{folder_i}); 
    runperfolder(FileName, settingpersetup, im_mode);
    cd(cDir)
    
end

fprintf('... Done\n')

end

function runperfolder(fname, settingpersetup, im_mode)
% runperfolder: function that runs all files per directory
%
% Usage:
%   runperfolder(fname, settingpersetup, im_mode)
%
% Args:
%   fname: file name
%   settingpersetup: camera/fictrac settings (basically vfov)
%   im_mode: mode of finding input files
%       (0, use tif)
%       (1, extract rawim from mp4)

% find and add code folder path
Calibration_Directory = ...
    strrep(which('batch_gen_fictrac_input_files'), ...
    'batch_gen_fictrac_input_files.m', '');
addpath(genpath(Calibration_Directory))
% get directory of fictrac settings
Calibration_Directory = ...
    strrep(Calibration_Directory, 'toolbox', 'fictrac_settings');

if im_mode == 0
    
    % find most updated MASK file
    SnapFile = get_recent_file('raw*.tif');

    %find the most updated SNAP file
    try
        MaskFile = get_recent_file('*mask*.tiff');
    catch
        imwrite(logical(SnapFile), 'mask.tiff')
        MaskFile = get_recent_file('*mask*.tiff');    
    end

    % 1) Updated mask by user if needed
    [sphere_cx_px, sphere_cy_px, ...
        sphere_radius_px, height_pix, width_pix] = ...
        get_ball_features(MaskFile, SnapFile);

    % 2) generate 'calibration-transform.dat'
    oDir = [pwd, filesep, 'calibration-transform.dat'];
    gen_fictrac_calibration_transform(...
        sphere_cx_px, sphere_cy_px, ...
        sphere_radius_px, width_pix, ...
        height_pix, settingpersetup.vfov, oDir)

elseif im_mode == 1
    
    % use video to extract a single frame for mask generation
    prefixstr = '.mp4';
    vid2use = rdir(['*', prefixstr]);
    vid2use = {vid2use.name}';
    
    if isempty(vid2use)
        prefixstr = '.avi';
        vid2use = rdir(['*', prefixstr]);
        vid2use = {vid2use.name}';
        vid2use = str2rm({'-debug.avi'}, vid2use);
    end
    
    vid2use = str2match(fname, vid2use);

    for i = 1:numel(vid2use)
        
        if i == 1
           preim = strrep(vid2use{i}, ['_vid', prefixstr], '_maskim.tiff');
        else
           preim = strrep(vid2use{i - 1}, ['_vid', prefixstr], '_maskim.tiff');
        end
        
        rawim = strrep(vid2use{i}, ['_vid', prefixstr], '_rawim.tiff');
        maskim = strrep(vid2use{i}, ['_vid', prefixstr], '_maskim.tiff');
        
        vid2load = VideoReader(vid2use{i});
        frame = read(vid2load, 1);
        if size(frame, 3) == 3
            frame = rgb2gray(frame);
        end
        imwrite(frame, rawim)
            
        % find most updated MASK file
        SnapFile = get_recent_file(rawim);

        %find the most updated SNAP file
        try
            MaskFile = get_recent_file(maskim);
        catch
            imwrite(logical(frame), maskim)
            MaskFile = get_recent_file(maskim);    
        end

        % 1) Updated mask by user if needed
        [sphere_cx_px, sphere_cy_px, ...
            sphere_radius_px, height_pix, width_pix] = ...
            get_ball_features(MaskFile, SnapFile, preim);

        if ~isempty(sphere_cx_px)
            
            % 2) generate 'calibration-transform.dat'
            oDir = [pwd, filesep, strrep(vid2use{i}, ...
                ['_vid', prefixstr], '_calibration-transform.dat')];
            gen_fictrac_calibration_transform(...
                sphere_cx_px, sphere_cy_px, ...
                sphere_radius_px, width_pix, ...
                height_pix, settingpersetup.vfov, oDir)
            
        else
            
            % copy mask and calibration-trnasform from previous file
            if ~strcmp(MaskFile, fullfile(pwd, preim))
                copyfile(fullfile(pwd, preim), MaskFile);
            end

            oDir = [pwd, filesep, strrep(vid2use{i}, ...
                ['_vid', prefixstr], '_calibration-transform.dat')];
            
            if ~strcmp(strrep(fullfile(pwd, preim), '_maskim.tiff', ...
                    '_calibration-transform.dat'), oDir)
                copyfile(strrep(fullfile(pwd, preim), '_maskim.tiff', ...
                    '_calibration-transform.dat'), oDir);
            end
            
        end
        
    end
    
end

% 3) copy fictrac configfile
try
    copyfile([Calibration_Directory, 'FicTrac_config.txt'], ...
        [pwd, filesep, 'FicTrac_config.txt'])
end

try
    copyfile([Calibration_Directory, 'FicTracPGR_config.txt'], ...
        [pwd, filesep, 'FicTracPGR_config.txt'])
end

end

function [sphere_cx_px, sphere_cy_px, ...
    sphere_radius_px, height_pix, width_pix] = ...
    get_ball_features(mask_filename, ...
    rawim_filename, pre_mask_filename)
% get_ball_features: generate ball mask, and update transform *.dat file
%
% Usage:
%	[sphere_cx_px, sphere_cy_px, ...
%       sphere_radius_px, height_pix, width_pix] = ...
%       get_ball_features(mask_filename, rawim_filename)
%
% Args:
%   mask_filename: full path of mask image file
%   rawim_filename: full path of raw image file
%   pre_mask_filename: previous mask filename to compare to

% read image file
if exist('pre_mask_filename', 'var') && ...
        ~isempty(pre_mask_filename)
    MASK = imread(pre_mask_filename);
else
    MASK = imread(mask_filename);
end

% if the image file is a true RGB image file, convert
if size(MASK, 3) == 3
    MASK = rgb2gray(MASK);
end

if size(imread(rawim_filename), 3) > 1
    SNAP = rgb2gray(imread(rawim_filename));
else
    SNAP = imread(rawim_filename);
end

% show snap with transparent mask overlaid
figure(1); clf
colormap(gray)
C = imfuse(SNAP, MASK, 'blend');
imshow(C)

% 1) Updated mask by user if needed
prompt = 'Mask OK? Y/N [Y]: ';

while 1
    IsOK = input(prompt, 's');
    
    if isempty(IsOK)
        IsOK = 'Y';
    end
    
    if strcmpi(IsOK, 'N') || strcmpi(IsOK, 'Y')
        break
    end
    disp('Wrong input value, Y/N only')
end

%create new mask
if strcmpi(IsOK, 'N')
    MaskOK = 0;
    imageSizeX = size(SNAP, 2);
    imageSizeY = size(SNAP, 1);
    [columnsInImage, rowsInImage] = ...
        meshgrid(1:imageSizeX, 1:imageSizeY);
   
    while 1
        %user defines ball circle
        disp('Define ball borders')
        fig = figure(1); clf(fig)
        imshow(SNAP)
        [x, y] = getpts(fig);
        [xc,yc,R,~] = circfit(x,y);
        config_shpere_centre_px = ['sphere_centre_px ', ...
            num2str(round(xc,2)),' ',num2str(round(yc,2))];
        config_sphere_radius_px = ['sphere_radius_px ', ...
            num2str(round(R,2))];
        disp(config_shpere_centre_px)
        disp(config_sphere_radius_px)
        BallPixels = (rowsInImage - yc).^2 ...
            + (columnsInImage - xc).^2 <= R.^2;

        % circlePixels is white - mask on
        BallMASK = BallPixels;

        sphere_cx_px = round(xc, 2);
        sphere_cy_px = round(yc, 2);
        sphere_radius_px = round(R, 2);

        %user defines glare circle
        disp('Define glare borders')
        fig = figure(1); clf(fig)
        imshow(SNAP)
        [x, y] = getpts(fig);
        [xc, yc, R, ~] = circfit(x, y);

        % circlePixels is a 2D "logical" array.
        glarePixels = (rowsInImage - yc).^2 ...
        + (columnsInImage - xc).^2 <= R.^2;
        %so that the glare is black - mask off
        GlareMASK = 1 - glarePixels;

        %user defines ball holder
        while 1
            disp('Define holder upper point (1 point)')
            fig = figure(1); clf(fig)
            imshow(SNAP)
            [x, y] = getpts(fig);
            if length(x) == 1
                break
            else
                disp('1 point only please..')
            end
        end     

        %create a black mask for the part of the holder that shadows the ball
        %(1) straight line under the ball (in any image orientation)
        %(2) black all the way to the bottom (just in case the bottom was marked wrongly)
        % Assuming: air stream axis: up
        xx = [1 size(SNAP, 2) size(SNAP, 2) 1];
        yy = [size(SNAP, 1) size(SNAP, 1) y y];

        BallHolder = poly2mask(xx, yy, ...
            size(SNAP, 1), size(SNAP, 2));

        % so that the ball holder is black - mask off
        BallHolderMASK = 1 - BallHolder;

        %make mask
        MASK = BallMASK & GlareMASK & BallHolderMASK;

        fig = figure(1); clf(fig)
        C = imfuse(SNAP, MASK, 'blend');
        imshow(C)

        prompt = 'Mask OK? Y/N [Y]: ';
        
        while 1
            IsOK = input(prompt, 's');

            if isempty(IsOK)
                IsOK = 'Y';
            end

            if strcmpi(IsOK, 'N') || strcmpi(IsOK, 'Y')
                break
            end

            disp('Wrong input value, Y/N only')
        end

        if strcmpi(IsOK, 'y')
            MaskOK = 1;
        end

        if MaskOK == 1
            % update mask
            delete(mask_filename)
            imwrite(MASK, mask_filename)
            break
        end
      
    end
    
    close(gcf)
    
else
    
    disp('Mask wasnt modified')
   
end

if ~exist('sphere_cx_px', 'var')
    sphere_cx_px = [];
end

if ~exist('sphere_cy_px', 'var')
    sphere_cy_px = [];
end

if ~exist('sphere_radius_px', 'var')
    sphere_radius_px = [];
end

% get image dimensions
height_pix = size(MASK, 1);
width_pix = size(MASK, 2);

end

function filepath = get_recent_file(file_pattern)
% get_recent_file: find the most updated "file_pattern" 
%   file and provide full path
%
% Usage:
%	filepath = get_recent_file(file_pattern)
%
% Args:
%   file_pattern: str pattern for finding files
%       ('*mask*.tiff')

allfiles = dir(file_pattern);
DateModified = zeros(1, size(allfiles, 1));

if isempty(allfiles)
    
    return
    
else
    
    for i = 1:size(allfiles,1)
       DateModified(i) = ...
           datenum(allfiles(i).date);
    end

    index = DateModified == max(DateModified);
    
    filepath = fullfile(pwd, ...
        allfiles(index).name);

end

end

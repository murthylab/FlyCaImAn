function batch_stitch_format_stacks_a(FolderName, FileName, iparams)
% batch_stitch_format_stacks_a: compiles and stitches sub-stacks
%   to whole brain (or stack) and saves variables in a 
%   ROIseg-compatible way
%
% Usage:
%   batch_stitch_format_stacks_a(FolderName, FileName, iparams)
%
% Args:
%   FolderName: name of folders to load
%   FileName: name of files to load
%   iparams: parameters to update
%       (cDir: current directory)
%       (debug: debug flag)
%       (fo2reject: folders to reject)
%       (fi2reject: files to reject)
%       (fsuffix: suffix of files to load)
%           (default, '_rawdata')
%       %%%%%%%%%%%% shift fluorescence distribution %%%%%%%%%%%%
%       (bkgate: flag for background substraction)
%           (default, 0)
%       (blowcap: fluorescence below which it is zerored)
%           (default, 0)
%       (fshift: shift distribution of F to the positive side)
%           (default, 6)
%       %%%%%%%%%%%% parpool & server related %%%%%%%%%%%%
%       (serId: server id)
%           (default, 'int')
%       (corenum: number of cores)
%           (default, 4)
%       %%%%%%%%%%%% stitching related %%%%%%%%%%%%
%       (zrange: range of shift in z)
%           (default, [1:7])
%       (maxshift: max displacement in z)
%           (default, 8)
%       (maxZshift: threshold for man - min change 
%           from init to last frame to remove edge)
%           (default, 0.3)
%       (maxshift_xy: maximun shift in x and y)
%           (default, [15 15])
%       (direction: used for iverting order of planes in the z axis, see notes)
%           (default, 'invert')
%       (phaseflag: flag for using phase correlation, use this when SNR is high)
%           (default, 1)
%       (planeshift: how to interpret the plane with highest correlation
%           when stitching serially imaged stacks, this dependes on the
%           resolution in z and the overlap between stacks)
%           (as the contiguous plane, 0, default)
%           (as the same plane, 1)
%               For example if axial resolution is 2um and overlap between planes
%               is 2um then I would consider the plane with high correlation to be
%               the contigous plane from the previous stack.
%       %%%%%%%%%%%% manual editing %%%%%%%%%%%%
%       (stack2rem: entire stacks to ignore)
%           (default, [])
%       (zend_man: input last plane to use, 
%           used when there was a circular mapping on XYZ axis)
%           ({1} stack idx and {2} end plane)
%           (default, [])
%       (plot_flag: flag to plot stitch correction)
%           (default, 0)
%       %%%%%%%%%%%% plot stitching results %%%%%%%%%%%%
%       (plot_stitch_flag: flag to plot results)
%           (default, 0)
%       (range: range of intensity to display)
%           (default, [0 100])
%       (refcha: reference channel (red channel == 1, green channel == 2))
%           (default, 1)
%       (oDir: target directory to save figures)
%           (default, [])
%       (debug_flag: flag to debug stitching of a particular stack)
%           (default, [])
%
% Notes:
% How to orient consecutive planes and stacks 
%   (particularly to match brain atlas orientation: 
%       anterior-posterior (central brain) or ventral-dorsal (VNC))
%   Imaging from the central brain posterior
%      (need to be inverted to have a anterior-posterior orientation)
%   Imaging from the VNC from ventral side already has a ventral-dorsal orientation.

cspfa = [];
cspfa.cDir = pwd;
cspfa.fo2reject = {'.', '..', 'preprocessed', ...
    'BData', 'rawtiff', 'motcor', 'stitch', ...
    'dfrel_vid', 'smod', 'roicov'};
cspfa.fi2reject = {'Zstack'};
cspfa.fsuffix = '_rawdata';
cspfa.bkgate = 0;
cspfa.blowcap = 0;
cspfa.fshift = [6 6];
cspfa.serverid = 'int';
cspfa.corenum = 4;
cspfa.zrange = 1:7;
cspfa.maxshift = 8;
cspfa.maxZshift = 0.3;
cspfa.maxshift_xy = [15 15];
cspfa.direction = 'invert';
cspfa.phaseflag = 0;
cspfa.planeshift = 0;
cspfa.stack2rem = [];
cspfa.zend_man = [];
cspfa.plot_flag = 0;
cspfa.plot_stitch_flag = 1;
cspfa.range = [0 1];
cspfa.refcha = 1;
cspfa.oDir = [pwd, filesep, 'stitch'];
cspfa.debug_flag = 0;

if ~exist('FolderName', 'var'); FolderName = []; end
if ~exist('FileName', 'var'); FileName = []; end
if ~exist('iparams', 'var'); iparams = []; end
cspfa = loparam_updater(cspfa, iparams);

if ~exist(cspfa.oDir, 'dir')
   mkdir(cspfa.oDir)
end

% start pararell pool if not ready yet
ppobj = setup_parpool(cspfa.serverid, cspfa.corenum);

% Selecting folders
f2run = dir;
f2run = str2match(FolderName, f2run);
f2run = str2rm(cspfa.fo2reject, f2run);
f2run = {f2run.name};

fprintf(['Running n-folders : ', num2str(numel(f2run)), '\n'])

for i = 1:numel(f2run)
    
    fprintf(['Running folder : ', f2run{i}, '\n']); 
    cd(f2run{i});
    runperfolder(FileName, cspfa);
    cd(cspfa.cDir);
    fprintf('\n')
    
end

delete_parpool(ppobj);

fprintf('... Done\n')

end

function runperfolder(fname, cspfa)
% runperfolder: run all files per folder
%
% Usage:
%   runperfolder(fname)
%
% Args:
%   fname: file name pattern
%   cspfa: parameter variable

% Run all files per folder
[f2plot, ~, ~] = ...
    rdir_namesplit(fname, '.mat', ...
    cspfa.fsuffix, cspfa.fi2reject, [], 1);
f2plot = unique(f2plot);

fprintf(['Compiling stacks from ', ...
    num2str(numel(f2plot)), ' flies\n'])

for file_i = 1:numel(f2plot)
    
    % Compiling all stacks per fly
    fprintf(['Running fly ', f2plot{file_i}, '\n'])
    
    [filename, ~, repnum] = ...
        rdir_namesplit(f2plot{file_i}, '.mat', ...
        cspfa.fsuffix, cspfa.fi2reject, [], 1); 
    filename = unique(filename);
    
    % remove stacks (init or end)
    if ~isempty(cspfa.stack2rem)
        repnum = setdiff(repnum, cspfa.stack2rem);
    end
    
    % sort stacks cspfa.direction
    if strcmp(cspfa.direction, 'invert')
        repnum = sort(repnum, 'descend');
    else
        repnum = sort(repnum, 'ascend');
    end
    
    % run per fly
    if numel(filename) == 1
        fcompiler(filename{1}, repnum, cspfa);
    else
        fprintf('error')
    end
    
    fprintf('\n')
    
end

end

function fcompiler(fname, reps, cspfa)
% fcompiler: for each filename compile 
%   all sub-stacks in the right order
%
% Usage:
%   fcompiler(fname)
%
% Args:
%   fname: file name
%   reps: all repetitions to use
%   cspfa: parameter variable

if exist('flip', 'builtin')
    str2use = 'flip';
else
    str2use = 'flipdim';
end

% Get Z-displacement
SimRed = [];
SimGreen = [];
fPlane = zeros(numel(reps), 1);
fprintf('Found NaN pixels: +\n')
fprintf('Found NaN slices: ^ (removing that plane)\n')
fprintf('Stack with decent Z displacement: ~ (removing that plane)\n')

for rep_i = 1:numel(reps)
    
    fprintf('*')
    load([fname, '_', num2str(reps(rep_i)), '_metadata.mat'], ...
        'iDat', 'mcDat');
    
    % for files with empty imaging data
    if isempty(iDat.StackN)
        fprintf('No imaging data found\n')
        return
    end
    
    % Correct for inverse z order
    if strcmp(cspfa.direction, 'invert')
        local(rep_i).RedChaMean = flip(iDat.RedChaMean, 3);
        local(rep_i).GreenChaMean = flip(iDat.GreenChaMean, 3);
    else
        local(rep_i).RedChaMean = iDat.RedChaMean;
        local(rep_i).GreenChaMean = iDat.GreenChaMean;        
    end
    
    % remove edges
    pix2rm = 10;
    local(rep_i).RedChaMean = ...
        local(rep_i).RedChaMean(pix2rm:end-pix2rm, ...
        pix2rm:end-pix2rm, :);
    local(rep_i).GreenChaMean = ...
        local(rep_i).RedChaMean(pix2rm:end-pix2rm, ...
        pix2rm:end-pix2rm, :);
    
    frame_siz = size(local(rep_i).RedChaMean);
    frame_siz = prod(frame_siz(1:2));
    
    % edit channels
    if cspfa.bkgate
    	local(rep_i).RedChaMean = ...
            local(rep_i).RedChaMean - iDat.bs(1); 
        local(rep_i).GreenChaMean = ...
            local(rep_i).GreenChaMean - iDat.bs(2); 
    end
    
    local(rep_i).RedChaMean = ...
        local(rep_i).RedChaMean + cspfa.fshift(1); 
    local(rep_i).RedChaMean(local(rep_i).RedChaMean < cspfa.blowcap) = ...
        cspfa.blowcap;
    local(rep_i).GreenChaMean = ...
        local(rep_i).GreenChaMean + cspfa.fshift(2); 
    local(rep_i).GreenChaMean(local(rep_i).GreenChaMean < cspfa.blowcap) = ...
        cspfa.blowcap;
    
    % Detecting nan
    if sum(isnan(local(rep_i).RedChaMean(:))) > 0
        fprintf('+'); %keyboard
    end
    
    % Detecting nan and choosing last plane (delete empty)
    fPlane(rep_i) = size(local(rep_i).RedChaMean, 3);
    
    if iscell(mcDat.rigid)
        mcDat.rigid = read_mcDat_shifts(mcDat.rigid, 1);
    end
    
    if abs(max(mcDat.rigid(3, :)) - min(mcDat.rigid(3, :))) >= cspfa.maxZshift
        fprintf('~');
        fPlane(rep_i) = fPlane(rep_i) - 1;
    end
    
    while sum(sum(isnan(local(rep_i).RedChaMean(:, :, fPlane(rep_i))), 2), 1) == frame_siz
        fprintf('^');
        fPlane(rep_i) = fPlane(rep_i) - 1;
        
        if fPlane(rep_i) == 0
            keyboard;
        end
        
    end
    
    if rep_i > 1
        
        % Set nan to min F value
        local(rep_i).RedChaMean(isnan(local(rep_i).RedChaMean)) = ...
            min(local(rep_i).RedChaMean(:));
        local(rep_i).GreenChaMean(isnan(local(rep_i).GreenChaMean)) = ...
            min(local(rep_i).GreenChaMean(:));
        
        % get initial planes for contiguous stacks
        preSimRed = findXYZmotion(local(rep_i-1).RedChaMean(:, :, fPlane(rep_i-1)), ...
        local(rep_i).RedChaMean(:, :, cspfa.zrange), cspfa.maxshift);
        preSimGreen = findXYZmotion(local(rep_i-1).GreenChaMean(:, :, fPlane(rep_i-1)), ...
        local(rep_i).GreenChaMean(:, :, cspfa.zrange), cspfa.maxshift);
        SimRed(rep_i, :) = squeeze(max(max(preSimRed, [], 1), [], 2));
        SimGreen(rep_i, :) = squeeze(max(max(preSimGreen, [], 1), [], 2));
        
    else
        
        % get initial plane:
        SimRed(rep_i, :) = zeros([1, size(cspfa.zrange, 2)]);
        SimGreen(rep_i, :) = zeros([1, size(cspfa.zrange, 2)]);
        zshift = 1;
        
        while sum(sum(isnan(local(rep_i).RedChaMean(:, :, zshift)), 2), 1) == frame_siz
            zshift = zshift + 1;
            if zshift == (size(local(rep_i).RedChaMean, 3) + 1)
                keyboard;
            end
        end
        
        SimRed(rep_i, zshift) = 1;
        SimGreen(rep_i, zshift) = 1;
        
    end
    
    clear iDat mcDat; fprintf(' ')
    
end

fprintf('\n')

wDat.Zstitch.Zshift(:, 1) = maxperrow(SimRed);
wDat.Zstitch.Zshift(:, 2) = maxperrow(SimGreen);
wDat.Zstitch.Zend(:, 1) = fPlane;

fprintf(['Z-shift ', num2str(wDat.Zstitch.Zshift(:, cspfa.refcha)'), '\n'])
fprintf(['Last planes ', num2str(wDat.Zstitch.Zend(:, 1)'), '\n'])

if ~isempty(cspfa.zend_man)
    wDat.Zstitch.Zend(cspfa.zend_man{1}, 1) = ...
        cspfa.zend_man{2};
end

clear SimRed local fPlane

% Get XY-displacement and compile fixed stacks
wDat.Zstitch.Zidx = [];
wDat.Zstitch.Xshift = [];
wDat.Zstitch.Yshift = [];
wDat.MotCor.Zshift = [];
wDat.MotCor.sXshift = [];
wDat.MotCor.sYshift = [];
shifts_align = [];

for rep_i = 1:numel(reps)
        
    % Load files
    fprintf('#')
    load([fname, '_', num2str(reps(rep_i)), '_metadata.mat'], ...
        'iDat', 'fDat', 'mcDat', 'lStim', 'vidDat');
    
    if ~exist('vidDat', 'var')
        vidDat = [];
    end
    
    if ~exist('mcDat', 'var')
        mcDat = [];
    end
    
    if ~isempty(strfind(fDat.DataType, 'opto'))
        load([fname, '_', num2str(reps(rep_i)), '_metadata.mat'], ...
            'cDat')
    end
    
    if ~exist('cDat', 'var'); cDat = []; end
    
    % Compare volumes
    if rep_i == 1
        
        % collect metadata
        fprintf(['voxelSize: ', num2str(iDat.MetaData{3}(1:3)), '\n'])
        
        % Collect the red and green template
        if strcmp(cspfa.direction, 'invert')
            wDat.RedChaMean = flip(iDat.RedChaMean, 3);
            wDat.GreenChaMean = flip(iDat.GreenChaMean, 3);
        else
            wDat.RedChaMean = iDat.RedChaMean;
            wDat.GreenChaMean = iDat.GreenChaMean;           
        end
        
        % delete empty planes if nan
        wDat.RedChaMean = wDat.RedChaMean(:, :, ...
            wDat.Zstitch.Zshift(rep_i, 1):wDat.Zstitch.Zend(rep_i, 1));
        wDat.GreenChaMean = wDat.GreenChaMean(:, :, ...
            wDat.Zstitch.Zshift(rep_i, 1):wDat.Zstitch.Zend(rep_i, 1));
        
        if cspfa.bkgate
            wDat.RedChaMean = wDat.RedChaMean - iDat.bs(1); 
            wDat.GreenChaMean = wDat.GreenChaMean - iDat.bs(2); 
        end
        
        wDat.RedChaMean = wDat.RedChaMean + cspfa.fshift(1); 
        wDat.RedChaMean(wDat.RedChaMean < cspfa.blowcap) = cspfa.blowcap;
        wDat.GreenChaMean = wDat.GreenChaMean + cspfa.fshift(2);
        wDat.GreenChaMean(wDat.GreenChaMean < cspfa.blowcap) = cspfa.blowcap;
        
        % size of substack
        zlength = size(wDat.RedChaMean, 3);
        
        % generate NoRMCorreSetParms
        dgDim = size(wDat.RedChaMean);
        dgDim(3) = 1;
        options_align = NoRMCorreSetParms(...
            'd1', dgDim(1), 'd2', dgDim(2), 'd3', dgDim(3), ...
            'grid_size', dgDim(1:3), 'bin_width', 50, 'mot_uf', [4, 4, 1],...
            'us_fac', 10, 'overlap_pre', 16, 'overlap_post', 16, ...
            'use_parallel', true, 'correct_bidir', false, ...
            'max_shift', cspfa.maxshift_xy, 'phase_flag', cspfa.phaseflag, ...
            'boundary', 'NaN', 'shifts_method', 'linear');
        
    else
        
        % Correct for inverse z order
        if strcmp(cspfa.direction, 'invert')
            iDat.RedChaMean = flip(iDat.RedChaMean, 3);
            iDat.GreenChaMean = flip(iDat.GreenChaMean, 3);
        end
        
        % delete empty planes if nan
        iDat.RedChaMean = iDat.RedChaMean(:, :, ...
            wDat.Zstitch.Zshift(rep_i, 1):wDat.Zstitch.Zend(rep_i, 1));
        iDat.GreenChaMean = iDat.GreenChaMean(:, :, ...
            wDat.Zstitch.Zshift(rep_i, 1):wDat.Zstitch.Zend(rep_i, 1));
        
        if cspfa.bkgate
            iDat.RedChaMean = iDat.RedChaMean - iDat.bs(1); 
            iDat.GreenChaMean = iDat.GreenChaMean - iDat.bs(2); 
        end
        
        iDat.RedChaMean = iDat.RedChaMean + cspfa.fshift(1); 
        iDat.RedChaMean(iDat.RedChaMean < cspfa.blowcap) = ...
            cspfa.blowcap;
        iDat.GreenChaMean = iDat.GreenChaMean + cspfa.fshift(2);
        iDat.GreenChaMean(iDat.GreenChaMean < cspfa.blowcap) = ...
            cspfa.blowcap;
        
        % Get shift
        % reset size of stack
        options_align.d3 = dgDim(3);
        options_align.grid_size(3) = dgDim(3);
        
        % get rid of nan values for motion correction
        if cspfa.refcha == 1
            refIm = wDat.RedChaMean(:, :, end);
        else
            refIm = wDat.GreenChaMean(:, :, end);
        end
        refIm(isnan(refIm)) = min(refIm(:));
        
        if cspfa.refcha == 1
            floatIm = iDat.RedChaMean(:, :, 1:2);
        else
            floatIm = iDat.GreenChaMean(:, :, 1:2);
        end                
        floatIm(isnan(floatIm)) = min(floatIm(:));
        
        % do motion correction
        [~, shifts_align, ~] = normcorre(floatIm, options_align, refIm);
             
        shifts_align = shifts_align(1);
        shifts_align.shifts(1, 1, 1, 3) = 0;
        shifts_align.shifts_up(1, 1, 1, 3) = 0;
        
        if sum(ismember(cspfa.debug_flag, reps(rep_i)))
            keyboard
        end
        
        shifts_pr(rep_i-1) = shifts_align;       
                
        if sum(ismember(cspfa.debug_flag, reps(rep_i)))
            
            % Plot shifts (use to vizualize correction along the Z axis)
            %   if change is not as expected manually edit
            %   'shifts_align.shifts' [X, Y, Z] [rows, columns, planes]
            plot_pair_of_shifted_planes(...
                floatIm, refIm, shifts_align(1), options_align)
            
        end
        
        clear floatIm refIm
        
        % Align Red- and Green-ChaMean
        % update 3rd dimention
        options_align.d3 = size(iDat.RedChaMean, 3);
        options_align.grid_size(3) = options_align.d3;
        options_align.grid_size = ...
            [options_align.d1 options_align.d2 options_align.d3];
        
        % apply shift to each channel
        % how to interpret plane with highest correlation (see notes)
        if cspfa.planeshift
            init_slice = 1;
            wDat.Zstitch.Zshift(rep_i, 1) = ...
                wDat.Zstitch.Zshift(rep_i, 1) + 1;
        else
            init_slice = 0;
        end
        
        floatIm = iDat.RedChaMean(:, :, (1 + init_slice):end);
        floatIm(isnan(floatIm)) = min(floatIm(:));
        prered = apply_shifts(floatIm, shifts_align, options_align);
        clear floatIm
        floatIm = iDat.GreenChaMean(:, :, (1 + init_slice):end);
        floatIm(isnan(floatIm)) = min(floatIm(:));
        pregreen = apply_shifts(floatIm, shifts_align, options_align);
        clear floatIm
        
        % concatenate
        wDat.RedChaMean = cat(3, wDat.RedChaMean, prered);
        wDat.GreenChaMean = cat(3, wDat.GreenChaMean, pregreen);
        
        % size of substack
        zlength = size(prered, 3);
        clear prered pregreen
        
    end
    
    % get stim metadata
    try
        wDat = getStimInfo(wDat, iDat, fDat, ...
            lStim, cDat, mcDat, vidDat, [fname, '_', ...
            num2str(reps(rep_i))], ...
            rep_i, reps, shifts_align, zlength);
    catch
        keyboard
    end
    
    clear shifts_align zlength
    
    if cspfa.bkgate
        wDat.prepros.bsSubs = 1;
    end
    
    % get Z idx for each subvolume
    clear iDat cDat fDat mcDat lStim
    
end

wDat.mask = max(isnan(wDat.RedChaMean), [], 3);
wDat.RedChaMean = pruneIm(wDat.RedChaMean, wDat.mask);
wDat.GreenChaMean = pruneIm(wDat.GreenChaMean, wDat.mask);
wDat.fSize = [size(wDat.RedChaMean, 1), size(wDat.RedChaMean, 2)];
wDat.vSize = [wDat.fSize, size(wDat.RedChaMean, 3)];
wDat.vOrient = cspfa.direction;

if cspfa.plot_flag
    
    fHandle = plot_NoRMCorr_shitfs(3, [], [], [], shifts_pr);
    fHandle.Name = [strrep(fname, '_', ' '), ' shifts'];
    
end

% save stack to be removed per folder
stack2rem = cspfa.stack2rem;

if ~exist('shifts_pr', 'var')
    shifts_pr = [];
end

save([fname, '_prosmetadata.mat'], 'wDat', 'shifts_pr', 'stack2rem');

% save videos and figures
if cspfa.plot_stitch_flag
    
    if ~exist(cspfa.oDir, 'dir')
        mkdir(cspfa.oDir)
    end
    
    plot_stitch_results(wDat, fname, cspfa.oDir, cspfa)
    
end

end

function plot_pair_of_shifted_planes(...
    floatIm, refIm, shifts_align, options_align)
% plot_pair_of_shifted_planes: function that 
%   plots shifted planes relative
%   to reference plane (useful for debuging)
%
% Usage:
%   plot_pair_of_shifted_planes(...
%       floatIm, refIm, shifts_align, options_align)
%
% Args:
%   floatIm: floating image
%   refIm: reference image
%   shifts_align: X, Y, Z shifts
%   options_align: NoRMCorre params

ip.range = [0 1];
ip.refcha = 1;

% 1) plot overlay of edges
floatIm(isnan(floatIm)) = min(floatIm(:));
floatIm = apply_shifts(floatIm, shifts_align, options_align);

im = double(floatIm);
im = im - prctile(im(:), 1);
im = im/prctile(im(:), 99);

im_ = double(refIm);
im_ = im_ - prctile(im_(:), 1);
im_ = im_/prctile(im_(:), 99);

im_1 = mat2gray(im(:, :, 1), ip.range);
im_2 = mat2gray(im_(:, :, 1), ip.range);

figH = figure();
axH = subplot(1, 1, 1);
C = imfuse(im_1, im_2, ...
   'falsecolor', 'Scaling', ...
   'joint', 'ColorChannels', ...
   [1 2 0]);
imshow(C, 'Parent', axH)

end

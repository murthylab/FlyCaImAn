function batch_NoRMCorre(FolderName, FileName, iparams)
% batch_NoRMCorre: function to perform motion correction to files within a
%   folder
%
% Usage:
%   batch_NoRMCorre(FolderName, FileName, iparams)
%
% Args:
%   FolderName: name of folders to load
%   FileName: name of files to load
%   iparams: parameters to update
%       (cDir: current directory)
%       (redo: redo gate)
%       (debug: debug gate)
%       (fsuffix: suffix of files to load)
%       (fo2reject: folders to reject)
%       %%%%%%%%%%%% parpool & server related %%%%%%%%%%%%
%       (serverid: server id)
%           (default, 'int')
%       (corenum: number of cores)
%           (default, 4)
%       %%%%%%%%%%%% motion corretion params %%%%%%%%%%%%
%       (stack2del: timepoints to delete (for first frames when the laser warms up))
%           (default, [])
%       (rigidg: ridig motion correction gate)
%           (default, 1)
%       (nrigidg: nonridig motion correction gate)
%           (default, 0)
%       (refcha: reference channel)
%           (red channel, 1, default)
%           (green channel, 2)
%       (iter_num: number of iterations)
%           (1, default)
%       (keepsize_flag: flag to keep original size across dimensions 
%           after motion correction, pads wit nans)
%           (0, default)
%       (withinplane_flag: for 3DxT volumes do motion correction on each plane separately)
%           (0, default)
%       %%%%%%%%%%%% internal NoRMCorre params %%%%%%%%%%%%
%       (def_maxshift: max shift allowed from frame-to-frame)
%           (default, [5 5 2])
%       (phaseflag: flag for using phase correlation, use this when SNR is high)
%           (default, 1)
%       (shifts_method: method to use for resampling)
%           ('linear', 'fft', 'cubic')
%       (boundary: method of boundary treatment)
%           (default, 'NaN')
%       (grid_size: size of non-overlapping regions)
%           (default, [64, 64, 5])
%       (bin_width: width of each bin
%           (deafult, 50)
%       (mot_uf: degree of patches upsampling)
%           (deafult, [4 4 1])
%       (us_fac: upsampling factor for subpixel registration)
%           (deafult, 10)
%       (overlap_pre: size of overlapping region)
%           (deafult, [16 16 3])
%       (overlap_post: size of overlapping region after upsampling)
%           (deafult, [16 16 3])
%       (use_parallel: for each frame, update patches in parallel)
%           (deafult, true)
%       (min_patch_size: minimum size of patch)
%           (deafult, [64 64 5])
%       (plot_df_flag: flag to plot df videos)
%           (deafult, 0)
%           (if 1, it plots iteration 0, and the last iteration)
%           (if 2, it plots iteration 0, and all iterations)
%       (baseline_tp: timepoints to use as baseline to generate DF videos)
%           (deafult, [1:5])
%       (int_range: intensity range for DF videos)
%           (deafult, [0 1])
%       (oDir: directory where videos are saved)
%           (deafult, pwd)
%       %%%%%%%%%%%% extra editing %%%%%%%%%%%%
%       (shift_ths: max cumulative motion or delta from fram-to-frame (assummes smoothness))
%           (default, [18, 0.7])
%       (span: number of timepoints (frames | volumes) to smooth)
%           (penalizes fast motion, assumes it is mostly slow motion == drift))
%           (default, 10)
%       (sgate: type of editing)
%           (1 = smooth and zero big displacements)
%           (2 = smooth, 3 = zeroing)
%           (0 = raw)
%       (readextfile_flag: flag to read shifts from another matfile and apply those to this file)
%       (readextfile_dir: input directory)
%       %%%%%%%%%%%% find saturated frames %%%%%%%%%%%%
%       (PMT_sat_flag: find saturated frames)
%           (default, 0)
%       (PMT_cha: channel to use)
%           (default, 1)
%       (f_threshold: fluorescence value beyond which a frame is considered saturated)
%           (default, 1000)
%       %%%%%%%%%%%% shift fluorescence distribution %%%%%%%%%%%%
%       (shift_f_flag: substract the minimun F value)
%       %%%%%%%%%%%% smooth data before correction %%%%%%%%%%%%
%       (smooth_sig: std of gaussian kernel)
%           (default, [])
%       (smooth_siz: size of kernel)
%           (default, [])
%
% Notes:
% This function uses NoRMCorre (https://github.com/flatironinstitute/NoRMCorre)
% see NoRMCorre functions: NoRMCorreSetParms, normcorre_batch
% To avoid cropping videos iteratively, it generates 'iDat.timepointsdel'
%   (it stores stack2del, this field is removed by batch_tiff2mat to reset file)
%
% 20191015:
%   1) added option to shift fluorescence distribution for both
%       channels (substract the min, so all values are positive)
%   2) added option to find saturated frames defined by a threshold
%       fluorescence intensity 'f_threshold'. This frames are replaced by the
%       nearby frame/volume or by the mean of preceding and following frames/volumes
% 20191028:
%   1) it plots shifts and correlation to template
%   2) option to provide smoothed data to estimate shifts (for low SNR stacks)
% 20200918:
%   1) add option to do within plane motion correction for 3DxT volumes
%
% ToDo:
% add optical flow
% re-run old correction readextfile_flag/readextfile_dir
% reduce memory load

% default params
pMC = [];
pMC.cDir = pwd;
pMC.redo = 0;
pMC.debug = 0;
pMC.fsuffix = '_rawdata.mat';
pMC.fo2reject = {'.', '..', 'preprocessed', ...
    'BData', 'rawtiff', 'motcor', 'stitch', ...
    'dfrel_vid', 'smod', 'roicov'};
pMC.serverid = 'int';
pMC.corenum = 4; 
pMC.stack2del = [];
pMC.rigidg = 1;
pMC.nrigidg = 0;
pMC.refcha = 1;
pMC.iter_num = 1;
pMC.keepsize_flag = 0;
pMC.withinplane_flag = 0;
pMC.def_maxshift = [5 5 2];
pMC.phaseflag = 1;
pMC.shifts_method = 'linear';
pMC.boundary = 'NaN';
pMC.grid_size = [64, 64, 5];
pMC.bin_width = 50;
pMC.mot_uf = [4 4 1];
pMC.us_fac = 10;
pMC.overlap_pre = [16 16 3];
pMC.overlap_post = [16 16 3];
pMC.use_parallel = true;
pMC.min_patch_size = [64 64 4];
pMC.plot_df_flag = 1;
pMC.baseline_tp = 1:5;
pMC.int_range = [0 1];
pMC.oDir = [pwd, filesep, 'motcor'];
pMC.shift_ths = [18, 0.7];
pMC.span = 10;
pMC.sgate = 1;
pMC.readextfile_flag = 0;
pMC.readextfile_dir = [];
pMC.PMT_sat_flag = 0;
pMC.PMT_cha = 1;
pMC.f_threshold = 10;
pMC.shift_f_flag = 0;
pMC.smooth_sig = [];
pMC.smooth_siz = [];

% update variables
if ~exist('FolderName', 'var'); FolderName = []; end
if ~exist('FileName', 'var'); FileName = []; end
if ~exist('iparams', 'var'); iparams = []; end
pMC = loparam_updater(pMC, iparams);

if ~exist(pMC.oDir, 'dir')
   mkdir(pMC.oDir)
end

if pMC.iter_num ~= numel(pMC.sgate)
    pMC.sgate = pMC.sgate*ones(1, pMC.iter_num);
end

% start pararell pool if not ready yet
ppobj = setup_parpool(pMC.serverid, pMC.corenum);

% Selecting folders
f2run = dir;
f2run = str2match(FolderName, f2run);
f2run = str2rm(pMC.fo2reject, f2run);
f2run = {f2run.name};

fprintf('Motion Correction NoRMCorre\n')
fprintf(['Running n-folders : ', num2str(numel(f2run)), '\n'])

for i = 1:numel(f2run)
    
    fprintf(['Running folder : ', f2run{i}, '\n']);
    cd(f2run{i});
    runperfolder(FileName, pMC);
    cd(pMC.cDir)
    
    % plot corrections
    if pMC.plot_df_flag ~= 0
        motpar.oDir = pMC.oDir;
        batch_plot_shifts_over_time(...
            f2run{i}, FileName, motpar);
    end
    
end

delete_parpool(ppobj);

fprintf('... Done\n')

end

function runperfolder(fname, pMC)
% runperfolder: run all files per folder
%
% Usage:
%   runperfolder(fname, pMC)
%
% Args:
%   fname: file name pattern
%   pMC: parameter variable

global RedCha GreenCha

figH = [];
axH = [];
input_colors = jet(pMC.iter_num);

shifts_pre = [];
shifts_r = [];
shifts_nr = [];
RedCha = [];
GreenCha = [];

% Files to load
f2run = rdir(['.', filesep, '*', pMC.fsuffix]);
fname = addsuffix(fname, pMC.fsuffix);
f2run = str2match(fname, f2run);
f2run = {f2run.name};
fprintf('Correcting motion\n')
k = 1;

for F2R_idx = 1:numel(f2run)
    
    try
        runperfile(f2run{F2R_idx}, pMC)
    catch error
        if ispc
            keyboard
        end
        failedfiles{k, 1} = strrep(f2run{F2R_idx}, ...
            '_rawdata', '_refdata');
        k = k + 1;
    end
    
end

if exist('failedfiles', 'var')
    failedfiles
end

fprintf('****** Done ******\n')

end

function runperfile(f2run, pMC)
% runperfile: run each file
%
% Usage:
%   runperfile(f2run, pMC)
%
% Args:
%   f2run: file name
%   pMC: parameter variable

global RedCha GreenCha

% initialize variables
figH = [];
axH = [];
input_colors = jet(pMC.iter_num);

shifts_pre = [];
shifts_r = [];
shifts_nr = [];

RedCha = [];
GreenCha = [];

cha_str = {'RedCha', 'GreenCha'};

% Loading files
fprintf(['Correcting file: ', ...
    f2run((max(strfind(f2run, filesep))+1):end), '\n'])

% Loading metadata
load(strrep(f2run, '_rawdata', '_metadata'), ...
    'iDat', 'lStim', 'fDat')

% for files with empty imaging data
if isempty(iDat.StackN)
    fprintf('No imaging data found\n')
    return
end        

if iDat.MotCorr == 0 || pMC.redo == 1

    % Loading Data (uint16) and keeping the format as double
    %   (because some functions require double precision)
    if pMC.redo == 1 && exist(strrep(f2run, '_rawdata', '_refdata'), 'file')

        load(strrep(f2run, '_rawdata', '_metadata'), 'mcDat')
        green_obj = matfile(f2run, 'Writable', true);            
        GreenCha = green_obj.Data; 
        red_obj = matfile(strrep(f2run, ...
            '_rawdata', '_refdata'), 'Writable', true);            
        RedCha = red_obj.Data;

    else

        data_obj = matfile(f2run, 'Writable', true);
        
        % Find saturated frames to remove from estimation of mean channel
        if pMC.PMT_sat_flag
            iDat = gen_PMT_score(iDat, data_obj, ...
                pMC.PMT_cha, pMC.f_threshold);
        end
        
        % Delete frame during flyback / update frameN / RedChaMean
        iDat = deleteflybackframe(iDat, fDat, data_obj);

        if ~exist('lStim', 'var')
            lStim = [];
        end

        % prune timepoints
        if ~isfield(iDat, 'timepointsdel')
            [lStim, iDat] = ...
                volumeprunner(lStim, iDat, data_obj, pMC.stack2del);
        end
        
        % update lStim and iDat
        save(strrep(f2run, '_rawdata', '_metadata'), ...
            'iDat', 'lStim', '-append')

        siz = size(data_obj.Data);
        ChannelSplitter(siz, pMC.shift_f_flag, data_obj)

    end

    orig_siz = size(GreenCha);
    
    % fill in gaps in RedCha if it is opto data
    %   (when opto stim is overlapping with red PMT)
    fillgaps_redcha(fDat, iDat, pMC.PMT_cha, pMC.debug)

    % save max-df movie to asses motion
    if pMC.plot_df_flag
        video_name = strrep(f2run, '_rawdata.mat', '');
        plot_df_video(GreenCha, pMC.int_range, ...
            pMC.baseline_tp, pMC.oDir, [video_name, '_DF_iter_0'])
    end

    % Do motion correction
    for iter_i = 1:pMC.iter_num
        fprintf(['Iteration # ', num2str(iter_i), '\n'])

        dgDim = size(GreenCha);
        display(dgDim)

        % motion correction parameters
        [options_r, options_nr] = ...
            generate_normcore_params(dgDim, pMC);

        % crispness of the mean        
        if iter_i == 1
            eval(['mcDat.crisp(1, 1) = get_crisp_idx(', ...
                cha_str{pMC.refcha}, ');']);
        end

        % Run rigid
        if pMC.rigidg

            fprintf('RigidMC\n')
            % correct for motion (using selected ref channel)
            % shifts: [height, width, depth]
            
            try
                
                if pMC.withinplane_flag && length(dgDim) == 4
                    
                    % do each plane separately
                    for plane_i = 1:dgDim(3)
                        if ~isempty(pMC.smooth_siz) && ...
                                isempty(pMC.smooth_sig)
                            eval(['[~, shifts_pre{plane_i}, template_(:, :, plane_i), ~, col_shift{plane_i}] = ', ...
                                'normcorre_batch(imblur(squeeze(', cha_str{pMC.refcha}, ...
                                '(:, :, plane_i, :)), pMC.smooth_sig, pMC.smooth_siz, 2), options_r);']);
                        else
                            eval(['[~, shifts_pre{plane_i}, template_(:, :, plane_i), ~, col_shift{plane_i}] = ', ...
                                'normcorre_batch(squeeze(', cha_str{pMC.refcha}, '(:, :, plane_i, :)), options_r);']);
                        end
                    end
                    
                else
                    
                    if ~isempty(pMC.smooth_siz) && ...
                            isempty(pMC.smooth_sig)
                        eval(['[~, shifts_pre, template_, ~, col_shift] = ', ...
                            'normcorre_batch(imblur(', cha_str{pMC.refcha}, ...
                            ', pMC.smooth_sig, pMC.smooth_siz, 2), options_r);']);
                    else
                        eval(['[~, shifts_pre, template_, ~, col_shift] = ', ...
                            'normcorre_batch(', cha_str{pMC.refcha}, ', options_r);']);
                    end
                    
                end
                
            catch
                fprintf(['normcorre_batch failed', ...
                    ' at iteration ', num2str(iter_i), '\n'])
            end
            
            % correlation with the mean (CM):
            if iter_i == 1
                eval(['mcDat.CM(1, :) = get_CM(template_,', ...
                    cha_str{pMC.refcha}, ');']);
            end

            % shifts_g = struct('shifts',cell(T,1),'shifts_up',cell(T,1),'diff',cell(T,1));

            % Edit shifts (use raw, smooth, or zero shifts)
            igate = 0;
            
            if pMC.sgate(iter_i) == 1
                
                % smooth shift and zero it if the delta is too big
                fprintf('\n smoothing and zeroing if necessary\n')
                [shifts_r, shifts_s, igate] = ...
                    checkshift(shifts_pre, pMC.span, pMC.shift_ths);
                
            elseif pMC.sgate(iter_i) == 2
                
                % just smooth shift
                fprintf('\n smoothing\n');
                shifts_r = smoothshift(shifts_pre, [], pMC.span);
                
            elseif pMC.sgate(iter_i) == 3
                
                % just zero shift
                fprintf('\n zeroing\n')
                shifts_r = zeroshift(shifts_pre);
                
            else
                
                % use raw
                fprintf('\n not editing\n');
                shifts_r = shifts_pre;
                
            end

            if ~exist('shifts_s', 'var')
                shifts_s = shifts_r;
            end

            if pMC.debug

                % plot shifts
                figName = strrep(strrep(strrep(f2run, ...
                    ['.', filesep], ''), '_rawdata.mat', ''), '_', '-');

                if length(dgDim) == 4 && ~pMC.withinplane_flag
                    [figH, axH] = plot_NoRMCorr_shitfs(3, ...
                         figH, axH, input_colors(iter_i, :), shifts_r);
                    %[figH, aH] = plot_NoRMCorr_shitfs(im_dim, varargin)
                    % shifts_pre, shifts_s,
                else
                    if ~pMC.withinplane_flag
                        [figH, axH] = plot_NoRMCorr_shitfs(2, ...
                             figH, axH, input_colors(iter_i, :), shifts_r);
                    else
                        [figH, axH] = plot_NoRMCorr_shitfs(2, ...
                             figH, axH, input_colors(iter_i, :), shifts_r{:});                        
                    end
                end

                figH.Name = figName;

            end

            if pMC.debug
                % Plot video of single plane                
                %keyboard
                %plot_2DoR(1, RedCha, GreenCha, [], 0.001, {'RedCha','GreenCha'})
                %plot_2DoR(5, GreenCha, Ymr, [], 0.001, {'Raw','Corrected'})
            end

            % apply shifts to Y
            if pMC.withinplane_flag && length(dgDim) == 4
                    
                    % do each plane separately
                    for plane_i = 1:dgDim(3)
            
                        eval([cha_str{pMC.refcha}, '(:, :, plane_i, :) = apply_shifts(squeeze(', ...
                            cha_str{pMC.refcha}, ...
                            '(:, :, plane_i, :)), shifts_r{plane_i}, options_r, [], [], [], col_shift{plane_i});']);

                        if eval(['~isempty(', cha_str{setdiff([1 2], pMC.refcha)}, ')'])
                            eval([cha_str{setdiff([1 2], pMC.refcha)}, ...
                                '(:, :, plane_i, :) = apply_shifts(squeeze(', ...
                                cha_str{setdiff([1 2], pMC.refcha)}, ...
                                '(:, :, plane_i, :)), shifts_r{plane_i}, options_r, [], [], [], col_shift{plane_i});']);
                        end
                        
                    end
                    
            else
            
                eval([cha_str{pMC.refcha}, ' = apply_shifts(', cha_str{pMC.refcha}, ...
                    ', shifts_r, options_r, [], [], [], col_shift);']);

                if eval(['~isempty(', cha_str{setdiff([1 2], pMC.refcha)}, ')'])
                    eval([cha_str{setdiff([1 2], pMC.refcha)}, ...
                        ' = apply_shifts(', cha_str{setdiff([1 2], pMC.refcha)}, ...
                        ', shifts_r, options_r, [], [], [], col_shift);']);
                end
                
            end

            clear col_shift
            
            % find nan pixels per plane, and whole nan planes
            floatIm = [];
            if length(dgDim) == 4
                nan_plane = sum(reshape(isnan(mean(GreenCha, length(dgDim))), ...
                    [prod(dgDim([1 2])) dgDim(3)])) ~= prod(dgDim([1 2]));

                % use non-nan planes
                nan_mask = max(isnan(mean(GreenCha(:, :, nan_plane, :), ...
                    length(dgDim))), [], 3);
                template_ = template_(:, :, nan_plane);
            else
                nan_plane = [];
                nan_mask = max(isnan(mean(GreenCha, length(dgDim))), [], 3);
            end

            % for pMC.iter_num > 1, remove nan pixels from red/green
            %   channels
            
            if pMC.iter_num > 1
                
                if length(dgDim) == 4
                    
                    % udpate iDat.FrameN and iDat.fstEn
                    idx2del = [];
                    for z2del = find(~nan_plane(:))'
                        idx2del = [idx2del, ...
                            z2del:iDat.FrameN:iDat.FrameN*iDat.StackN];
                    end
                    iDat.fstEn(idx2del, :) = [];
                    iDat.FrameN = sum(nan_plane);
                    clear idx2del z2del

                    if ~isempty(RedCha)
                        RedCha = pruneIm(RedCha(:, :, nan_plane, :), nan_mask);
                    end
                    if ~isempty(GreenCha)
                        GreenCha = pruneIm(GreenCha(:, :, nan_plane, :), nan_mask);
                    end

                    if size(iDat.fstEn, 1) ~= prod([iDat.FrameN iDat.StackN])
                        fprintf('Error fstEn and Data size dont match')
                        keyboard
                    end
                    
                else

                    if ~isempty(RedCha)
                        RedCha = pruneIm(RedCha, nan_mask);
                    end
                    if ~isempty(GreenCha)
                        GreenCha = pruneIm(GreenCha, nan_mask);
                    end

                end

                eval(['floatIm = ', cha_str{pMC.refcha}, ';']);

            else
                
                if length(dgDim) == 4
                    eval(['floatIm = pruneIm(', cha_str{pMC.refcha}, ...
                        '(:, :, nan_plane, :), nan_mask);']);
                else
                    eval(['floatIm = pruneIm(', cha_str{pMC.refcha}, ...
                        ', nan_mask);']);
                end
                
            end
                
            % correlation after correction      
            mcDat.CM(iter_i + 1, :) = ...
                get_CM(pruneIm(template_, nan_mask), floatIm);

            % crispness of the mean
            mcDat.crisp(iter_i + 1, 1) = get_crisp_idx(floatIm);

            clear floatIm

            % add optic flow
            % edit opticalFlowFarneback

            % if running each plane per volume separately save the average
            %   across planes
            if pMC.withinplane_flag && length(dgDim) == 4
                shifts_r = average_shifts(shifts_r);
                shifts_pre = average_shifts(shifts_pre);
                shifts_nr = average_shifts(shifts_nr);
            end
            
            % Get displacements
            shifts = parseshift(shifts_r, shifts_pre, shifts_nr);
            mcDat.axes = {'Y', 'X', 'Z'};

            if pMC.redo == 1 && ...
                    exist(strrep(f2run, '_rawdata', '_refdata'), 'file')
                mcDat.rigid{iter_i, 1} = mcDat.rigid + shifts{1};
                mcDat.nonrigid{iter_i, 1} = mcDat.nonrigid + shifts{3}; 
                mcDat.rigids{iter_i, 1} = mcDat.rigids + shifts{2};
            else
                mcDat.rigid{iter_i, 1} = shifts{1};
                mcDat.nonrigid{iter_i, 1} = shifts{3};
                mcDat.rigids{iter_i, 1} = shifts{2};
            end
            mcDat.ergate(iter_i, 1) = igate;

            clear shifts
            shifts_pre = [];
            shifts_r = [];
            shifts_nr = [];

            % save max-df movie to asses motion
            if pMC.plot_df_flag == 1 && iter_i == pMC.iter_num
                video_name = strrep(f2run, ...
                     '_rawdata.mat', '');
                plot_df_video(GreenCha, pMC.int_range, ...
                    pMC.baseline_tp, pMC.oDir, ...
                    [video_name, '_DF_iter_', num2str(iter_i)])
            elseif pMC.plot_df_flag == 2
                video_name = strrep(f2run, ...
                     '_rawdata.mat', '');
                plot_df_video(GreenCha, pMC.int_range, ...
                    pMC.baseline_tp, pMC.oDir, ...
                    [video_name, '_DF_iter_', num2str(iter_i)])                
            end

        end

    end
        
    % keep original X and Y size
    if pMC.keepsize_flag
        
        fprintf(['padding image to match original size ', ...
            num2str(orig_siz), '\n'])

        % pad volume
        delta_siz = abs(size(GreenCha) - orig_siz);
        delta_siz = delta_siz(1:(length(delta_siz)-1));
             
        if ~isempty(RedCha)
            RedCha = padarray(RedCha, delta_siz, nan, 'pre');
        end
        if ~isempty(GreenCha)
            GreenCha = padarray(GreenCha, delta_siz, nan, 'pre');
        end
               
        % reconstitute deleted timestamps (copy last frame)
        init_temp = reshape(iDat.fstEn(:, 1), [iDat.FrameN, iDat.StackN]);
        end_temp = reshape(iDat.fstEn(:, 2), [iDat.FrameN, iDat.StackN]);

        for l = 1:delta_siz(3)
            init_temp(end + 1, :) = init_temp(end, :);
            end_temp(end + 1, :) = end_temp(end, :);
        end
        
        iDat.fstEn = [init_temp(:) end_temp(:)];
        clear init_temp end_temp delta_siz
        
        % provide final size after removing nans
        dgDim = size(GreenCha);
        if length(dgDim) == 4
            nan_plane = sum(reshape(isnan(mean(GreenCha, length(dgDim))), ...
                [prod(dgDim([1 2])) dgDim(3)])) ~= prod(dgDim([1 2]));
        else
            nan_plane = [];
        end
        
        fprintf('planes to keep\n')
        display(nan_plane)
        
    end

    % Save metadata, avg image and save
    fprintf('Saving ... ')

    iDat.MotCorr = 1;
    
    % Get mean volumes
    iDat.GreenChaMean = mean(GreenCha, length(dgDim));
    iDat.RedChaMean = mean(RedCha, length(dgDim));

    % update size
    iDat.FrameSize = [size(GreenCha, 1) size(GreenCha, 2)];
    
    if length(dgDim) == 4
        iDat.FrameN = size(GreenCha, 3);
    end
    
    % saving processed video to .mat file
    save(strrep(f2run, '_rawdata', '_metadata'), ...
        'iDat', 'lStim', 'mcDat', '-append')

    Data = GreenCha;
    
    % plot image of start vs end of recording
    if ~isempty(Data)
        
        if length(dgDim) == 4
            float_im_1 = ...
                mean(Data(:, :, :, 1:10), 4);
            float_im_2 = ...
                mean(Data(:, :, :, end-10:end), 4);
        else
            float_im_1 = ...
                mean(Data(:, :, 1:10), 3);
            float_im_2 = ...
                mean(Data(:, :, end-10:end), 3);         
        end
        
        plot_fused_image_vid(...
            float_im_1, float_im_2, ...
            strrep(f2run, '_rawdata', '_init_end_im_g'), ...
            pMC.oDir);
        
    end
    
    save(f2run, 'Data', '-v7.3');
    GreenCha = [];

    Data = RedCha;
    
    if ~isempty(Data)
        
        if length(dgDim) == 4
            float_im_1 = ...
                mean(Data(:, :, :, 1:10), 4);
            float_im_2 = ...
                mean(Data(:, :, :, end-10:end), 4);
        else
            float_im_1 = ...
                mean(Data(:, :, 1:10), 3);
            float_im_2 = ...
                mean(Data(:, :, end-10:end), 3);         
        end
        
        plot_fused_image_vid(...
            float_im_1, float_im_2, ...
            strrep(f2run, '_rawdata', '_init_end_im_r'), ...
            pMC.oDir);
        
        save(strrep(f2run, '_rawdata', '_refdata'), ...
            'Data', '-v7.3');
        
    end
    
    RedCha = [];

    Data = [];
            
    fprintf('Done\n')

else

    fprintf(' *already corrected*\n')

end

clear dDim iDat lStim fDat mcDat

end

% ********************************************
% ************* NormCore related *************
% ********************************************

function [options_r, options_nr] = ...
    generate_normcore_params(siz, pMC)
% generate_normcore_params: calculate correlation of 
%   template to each frame of floating image
%
% Usage:
%   [options_r, options_nr] = ..
%       generate_normcore_params(siz, pMC)
%
% Args:
%   siz: image dimensions
%   pMC: floating image
%
% Returns:
%   options_r & options_nr motion correction parameters (see NoRMCorreSetParms)

% motion correction parameters
if length(siz) == 4 && ~pMC.withinplane_flag
    d3 = siz(3);
else
    d3 = 1;
    pMC.overlap_pre = pMC.overlap_pre(1);
    pMC.overlap_post = pMC.overlap_post(1);
    pMC.grid_size(3) = 1;
end

% rigid correction settings
options_r = NoRMCorreSetParms(...
    'd1', siz(1), 'd2', siz(2), 'd3', d3, ...
    'grid_size', [siz(1:2) d3], 'bin_width', pMC.bin_width, ...
    'mot_uf', pMC.mot_uf, 'us_fac', pMC.us_fac, ...
    'overlap_pre', pMC.overlap_pre, 'overlap_post', pMC.overlap_post, ...
    'use_parallel', pMC.use_parallel, 'max_shift', pMC.def_maxshift, ...
    'phase_flag', pMC.phaseflag, 'boundary', pMC.boundary, ...
    'shifts_method', pMC.shifts_method);
options_r.correct_bidir = 0;

% non-rigid correction settings
options_nr = NoRMCorreSetParms(...
    'd1', siz(1), 'd2', siz(2), 'd3', d3, ...
    'grid_size', pMC.grid_size, 'bin_width', pMC.bin_width, ...
    'mot_uf', pMC.mot_uf, 'us_fac', pMC.us_fac, ...
    'overlap_pre', pMC.overlap_pre, 'overlap_post', pMC.overlap_post, ...
    'min_patch_size', pMC.def_maxshift, 'use_parallel', pMC.use_parallel, ...
    'max_shift', pMC.def_maxshift, 'phase_flag', pMC.phaseflag, ...
    'boundary', pMC.boundary, 'shifts_method', pMC.shifts_method);
options_nr.correct_bidir = 0;

end

% **********************************************************
% ************* measure of correction goodness *************
% **********************************************************

function CM = get_CM(templateIm, floatIm)
% get_CM: calculate correlation of template to each frame of floating image
%
% Usage:
%   CM = get_crisp_idx(iDat, fDat, data_obj)
%
% Args:
%   templateIm: reference channel to use
%   floatIm: floating image
%
% Returns:
%   CM: correlation

siz_ = size(floatIm);
templateIm = reshape(templateIm, [prod(siz_(1:end-1)) 1]);
floatIm = reshape(floatIm, [prod(siz_(1:end-1)) siz_(end)]);

CM = corr(templateIm, floatIm)';

end

function crisp_idx = get_crisp_idx(Y)
% get_crisp_idx: calculate crispness index as in
%   (http://dx.doi.org/10.1016/j.jneumeth.2017.07.031)
%
% Usage:
%   crisp_idx = get_crisp_idx(Y)
%
% Args:
%   Y: input 3D or 2D matrix
%
% Returns:
%   crisp_idx: crispness

crisp_idx = [];

siz_ = size(Y);
pre_matrix = abs(reshape(squeeze(mean(Y, length(siz_))),...
    [prod(siz_(1:end-1)) 1]));

crisp_idx = norm(pre_matrix, 'fro');

end

% *****************************************
% ************* stack editing *************
% *****************************************


function iDat = deleteflybackframe(iDat, fDat, data_obj)
% deleteflybackframe: delete deleting z frame and related time stamps (Piezzo fly back)
%
% Usage:
%   iDat = deleteflybackframe(iDat, fDat, data_obj)
%
% Args:
%   iDat: image metadata variable
%   fDat: metadata variable
%   data_obj: memmap data object
%
% Returns:
%   iDat: updated image metadata variable
%
% Notes:
% choose plane to delete based on data input type 
%   (Also, if already LEDcorr then this step has already happened)

if contains(fDat.DataType, '3DxT') && ~iDat.LEDCorr ...
        && ~contains(fDat.DataType, 'remotefocus')
    
    if contains(fDat.DataType, 'old')
        z2del = size(data_obj.Data, 3);
        % old, Chop Data and update iDat
    else
        z2del = 1;
        % new, Chop Data and update iDat
    end
    
    if isfield(iDat, 'sstEn')
        iDat = rmfield(iDat, 'sstEn');
    end
    
    % update frame time / Data / RedChaMean
    fprintf('Deleting flyback frame, final size: ')
    iDat.fstEn(z2del:iDat.FrameN:end, :) = [];
    
    % load data
    data = data_obj.Data;
    
    % delete flyback frame
    data(:, :, z2del, :, :) = [];
    
    % overwrite data
    data_obj.Data = data;
    
else
    
    if iDat.LEDCorr
        fprintf('flyback frame deletion already performed, final size: ')
    elseif contains(fDat.DataType, 'remotefocus')
        fprintf('there is no flyback frame, so it does not require slice removal ')
    else
        fprintf('It is 2DxT data, so it does not require slice removal ')
    end
    
end

if contains(fDat.DataType, '3DxT')
    iDat.FrameN = size(data_obj.Data, 3);
elseif contains(fDat.DataType, '2DxT')
    iDat.FrameN = 1;
end

fprintf([num2str(iDat.FrameN), '\n'])

end

function iDat = gen_PMT_score(iDat, data_obj, ...
    PMT_cha, f_ths)
% gen_PMT_score: find frames that saturate
%
% Usage:
%   iDat = gen_PMT_score(iDat, data_obj, PMT_cha)
%
% Args:
%   iDat: image metadata variable
%   data_obj: memmap data object
%   PMT_cha: channel to use
%   f_ths: intensity threshold
%
% Returns:
%   iDat: updated image metadata variable

% load data
data = data_obj.Data;

if iDat.FrameN > 1
    data = data(:, :, :, :, PMT_cha);
else
    data = data(:, :, :, PMT_cha);
end

iDat.PMT_fscore = ...
    squeeze(max(max(data, [], 1), [], 2));

% flag frames above f_ths
if size(iDat.PMT_fscore, 1) == 1
    iDat.PMT_fscore = iDat.PMT_fscore < f_ths;
else
    iDat.PMT_fscore = sum(iDat.PMT_fscore < f_ths, 1);
end

end

function ChannelSplitter(siz, shift_f_flag, data_obj)
% ChannelSplitter: splits data_obj.Data variable into channels that
%   comprise it.
%
% Usage:
%   ChannelSplitter(siz, data_obj)
%
% Args:
%   siz: image size
%   shift_f_flag: substract the minimun of F
%   data_obj: memmap data object

global RedCha GreenCha

if length(siz) == 4 && siz(end) == 2
    
    RedCha = single(data_obj.Data(:, :, :, 1));
    GreenCha = single(data_obj.Data(:, :, :, 2));
    
elseif length(siz) == 5 && siz(end) == 2
    
    RedCha = single(data_obj.Data(:, :, :, :, 1));
    GreenCha = single(data_obj.Data(:, :, :, :, 2));
    
else
    GreenCha = single(data_obj.Data);
end

if shift_f_flag
    RedCha = RedCha - min(RedCha(:));
    GreenCha = GreenCha - min(GreenCha(:));
end

end

function [lStim, iDat] = ...
    volumeprunner(lStim, iDat, data_obj, stack2del)
% volumeprunner: prunes the original Data
%   and adjust lStim and iDat metadata accordingly
%
% Usage:
%   [lStim, iDat] =  ...
%       volumeprunner(lStim, iDat, data_obj, stack2del)
%
% Args:
%   lStim: stimuli metadata variable
%   iDat: image metadata variable
%   data_obj: memmap data object
%   stack2del: timepoints to delete
%
% Return:
%   lStim: updated stimuli metadata variable
%   iDat: updated image metadata variable

% Prune Data
if ~isempty(stack2del)
    fprintf(['Pruning ', num2str(stack2del), ' timepoints\n'])
    
    % load data
    data = data_obj.Data;
    
    if iDat.FrameN > 1
        data(:, :, :, stack2del, :) = [];
    else
        data(:, :, stack2del, :) = [];
    end
    
    % overwrite data
    data_obj.Data = data;
    
    % Rechape fsTen
    initF = reshape(iDat.fstEn(:, 1), [iDat.FrameN, iDat.StackN]);
    initF(:, stack2del) = [];
    initF = initF(:);
    
    endF = reshape(iDat.fstEn(:, 2), [iDat.FrameN, iDat.StackN]);
    endF(:, stack2del) = [];
    endF = endF(:);
    
    iDat.fstEn = [];
    iDat.fstEn(:, 1) = initF;
    iDat.fstEn(:, 2) = endF;
    
    % Prune lStim
    if ~isempty(lStim) && isfield(lStim, 'trace') ...
            && isfield(lStim, 'lstEn')
        lStim.trace = lStim.trace(iDat.fstEn(1, 1):iDat.fstEn(end, 2));
        lStim.lstEn = lStim.lstEn - iDat.fstEn(1, 1) + 1;
    end
    
    % Zero frame init
    iDat.fstEn = iDat.fstEn - iDat.fstEn(1, 1) + 1;
    
    % Get frame times and prune them too
    iDat.StackN = iDat.StackN - numel(stack2del);
    
    % Update PMT_fscore
    if isfield(iDat, 'PMT_fscore') && ~isempty(iDat.PMT_fscore)
        iDat.PMT_fscore(:, stack2del) = [];
    end
    
    % update metadata
    iDat.timepointsdel = stack2del;
    
end

end

function fillgaps_redcha(fDat, iDat, channel2fill, idebug)
% fillgaps_redcha: fill saturated frames/volumes in red channel
%   (for cases where opto stimuli is used and bleeds through red/green channel)
%
% Usage:
%   fillgaps_redcha(fDat, iDat, idebug)
%
% Args:
%   fDat: stimuli metadata variable
%   iDat: image metadata variable
%   channel2fill: channel to fill saturated frames
%   idebug: debug gate

global RedCha GreenCha

if contains(fDat.DataType, 'opto') && ~isempty(RedCha)
    
    tp2fill = [];
    
    if contains(fDat.DataType, '3DxT') && isfield(iDat, 'PMT_fscore')
        tp2fill = find(iDat.PMT_fscore < (iDat.FrameN + 1));
    elseif contains(fDat.DataType, '2DxT') && isfield(iDat, 'PMT_fscore')
        tp2fill = find(iDat.PMT_fscore < 1);
    end
    
    if idebug
        Data4display = squeeze(max(max(RedCha, [], 1), [], 2));
        subplot(1, 2, 1);
        imagesc(Data4display);
        title('Red_input')
    end
    
    if channel2fill == 1
        RedCha = framegapfill(tp2fill, RedCha);
    else
        GreenCha = framegapfill(tp2fill, GreenCha);
    end
    
    if idebug
        Data4display = squeeze(max(max(RedCha, [], 1), [], 2));
        subplot(1, 2, 2);
        imagesc(Data4display);
        title('Red_output')
    end
    
end

end

% ******************************************
% ************* shifts-related *************
% ******************************************

function [shifts_i, shifts_s, igate] = ...
    checkshift(shifts_i, smooth_span, shift_ths)
% checkshift: get all shifts and smooth the change over time
%
% Usage:
%   [shifts_i, shifts_s, igate] = checkshift(shifts_i)
%
% Args:
%   shifts_i: input shifts
%   smooth_span: span for smoothing
%   shift_ths: threshold for the shifts
%
% Returns:
%   shifts_i, shifts_s, igate: zeroed shifts in vector format

if ~iscell(shifts_i)
    shifts_i = {shifts_i};
end

for i = 1:numel(shifts_i)
    
    igate = 0;
    shifts_s{i} = shifts_i{i};
    shifts_r = shifts_editor(shifts_i{i}, 'read');

    for ii = 1:size(shifts_r, 2)

        % Smooth
        shifts_sr(:, ii) = smooth(shifts_r(:, ii), smooth_span);
        % Round to 2 decimal
        shifts_sr(:, ii) = round(shifts_sr(:, ii)*100)/100;

    end

    shifts_delta = abs(shifts_sr - shifts_r);

    for ii = 1:size(shifts_r, 2)
        display([max(shifts_delta(:, ii)) sum(shifts_delta(:, ii))])

        if max(shifts_delta(:, ii)) > shift_ths(2) ...
                || sum(shifts_delta(:, ii)) > shift_ths(1)
            shifts_sr(:, ii) = 0;
            igate = 1;     
        end

    end

    % if a max delta is greater than ths then zero all those shifts
    % save smooth trace
    shifts_s{i} = shifts_editor(shifts_s{i}, 'write_r', shifts_sr);
    shifts_i{i} = shifts_editor(shifts_i{i}, 'write_r', shifts_sr);

end

if numel(shifts_s) == 1
    shifts_s = shifts_s{1};
    shifts_i = shifts_i{1};
end

end

function shifts_s = smoothshift(shifts_i, ax2use, smooth_span)
% smoothshift: smooth shifts, axes specific
%
% Usage:
%   shifts_s = smoothshift(shifts_i, ax2use, smooth_span)
%
% Args:
%   shifts_i: input shifts
%   ax2use: axes to use
%   smooth_span: span for smoothing
%
% Returns:
%   shifts: smoothed shifts in vector format

if ~iscell(shifts_i)
    shifts_i = {shifts_i};
end

for i = 1:numel(shifts_i)
    
    shifts_s{i} = shifts_i{i};
    shifts_r = shifts_editor(shifts_i{i}, 'read');
    shifts_sr = shifts_r;

    if ~exist('ax2use', 'var') || isempty(ax2use)
        ax2use = 1:size(shifts_r, 2);
    end

    for ii = ax2use
        % Smooth
        shifts_sr(:, ii) = smooth(shifts_r(:, ii), smooth_span);
        % Round to 2 decimal
        shifts_sr(:, ii) = round(shifts_sr(:, ii)*100)/100;
    end

    % save smooth trace
    shifts_s{i} = shifts_editor(shifts_s{i}, 'write_r', shifts_sr);
    
end

if numel(shifts_s) == 1
    shifts_s = shifts_s{1};
end

end

function shifts_s = zeroshift(shifts_i, ax2use)
% zeroshift: zero shifts, axes specific
%
% Usage:
%   shifts_s = smoothshift(shifts_i, ax2use)
%
% Args:
%   shifts_i: input shifts
%   ax2use: axes to use
%
% Returns:
%   shifts: zeroed shifts in vector format

if ~iscell(shifts_i)
    shifts_i = {shifts_i};
end

for i = 1:numel(shifts_i)

    shifts_s{i} = shifts_i{i};
    shifts_r = shifts_editor(shifts_i{i}, 'read');

    if ~exist('ax2use', 'var')
        ax2use = 1:size(shifts_r, 2);
    end

    shifts_sr = shifts_r;

    % Zeroing values
    for ii = ax2use
        shifts_sr(:, ii) = shifts_r(:, ii)*0;
    end

    % save trace
    shifts_s{i} = shifts_editor(shifts_s{i}, 'write_r', shifts_sr);

end

if numel(shifts_s) == 1
    shifts_s = shifts_s{1};
end

end

function shifts_out = average_shifts(shifts_in)
% average_shifts: average shifts contained in a cell shifts_in
%
% Usage:
%   shifts_out = average_shifts(shifts_in)
%
% Args:
%   shifts_in: cell with many shifts
%
% Returns:
%   shifts_out: mean shifts as structure

if ~isempty(shifts_in)
    
    shifts_out = shifts_in{1};

    for t_i = 1:numel(shifts_out)

        for i = 1:numel(shifts_in)
            shifts(:, :, :, :, i) = shifts_in{i}(t_i).shifts;
            shifts_up(:, :, :, :, i) = shifts_in{i}(t_i).shifts_up;
            diff(:, i) = shifts_in{i}(t_i).diff;
        end

        shifts_out(t_i).shifts = mean(shifts, 5);
        shifts_out(t_i).shifts(:, :, :, 3) = 0;
        shifts_out(t_i).shifts_up = mean(shifts_up, 5);
        shifts_out(t_i).shifts_up(:, :, :, 3) = 0;
        shifts_out(t_i).diff = mean(diff, 2);

        clear shifts shifts_up diff

    end
    
else
    
    shifts_out = [];
    
end

end

function shifts = parseshift(varargin)
% parseshift: get shifts in vector format per dimension
%
% Usage:
%   shifts = parseshift(varargin)
%
% Args:
%   varargin: shifts (in cells)
%
% Returns:
%   shifts: shifts in vector format

shifts = cell(numel(varargin), 1);

for i = 1:numel(varargin)
    
    % get structure shifts_i and plots them
    shifts_i = varargin{i};
    
    if ~isempty(shifts_i)
        shifts_t = shifts_editor(shifts_i, 'read');
        if ~iscell(shifts_t); shifts_t = shifts_t'; end
    else
        shifts_t = [];
    end
    
    shifts{i} = shifts_t;
    clear shifts_i shifts_t shifts_r
    
end

end

% ********************************************
% ************* plotting related *************
% ********************************************

function plot_df_video(input_im, im_range, ...
    baseline_tp, target_directory, filename)
% plot_df_video: function that plots DF videos
%
% Usage:
%   plot_df_video(input_im, im_range, ...
%       baseline_tp, target_directory, filename)
%
% Args:
%   input_im: input image
%   im_range: range if intensities for plotting
%   baseline_tp: baseline timepoints
%   target_directory: taget directory
%   filename: output file name

% baseline substract and max-project on the Z axis
if length(size(input_im)) == 4
    %input_im = input_im - nanmean(input_im(:, :, :, baseline_tp), 4);
    input_im = squeeze(nanmax(input_im, [], 3));
else
    %input_im = input_im - nanmean(input_im(:, :, baseline_tp), 3);
end

% scale to [0 1]
input_im = input_im - prctile(input_im(:), 1);
input_im = input_im/prctile(input_im(:), 99);

pi.range = im_range;
pi.vgate = 1;
pi.vname = [target_directory, filesep, filename];
pi.vquality = 100;
pi.frate = 10;
pi.cmap = parula;
pi.axisratio = 0;

slice3Dmatrix(input_im, pi)

end

% Run non rigid still in progress
% if pMC.nrigidg
% 
%     fprintf('NonRigidMC\n')
%     if pMC.refcha == 1
%         if length(dgDim) == 4
%             Y = RedCha(:, :, :, perm);
%         else
%             Y = RedCha(:, :, perm);
%         end
%     else
%         if length(dgDim) == 4
%             Y = GreenCha(:, :, :, perm);
%         else
%             Y = GreenCha(:, :, perm);
%         end
%     end
% 
%     [Y, shifts_nr, ~] = normcorre_batch(Y, options_nr);
% 
%     if pMC.refcha == 1 
%         if length(dgDim) == 4
%             RedCha(:, :, :, perm) = Y;
%         else
%             RedCha(:, :, perm) = Y;
%         end
%     else
%         if length(dgDim) == 4
%             GreenCha(:, :, :, perm) = Y;
%         else
%             GreenCha(:, :, perm) = Y;
%         end
%     end
% 
%     shifts_nr(perm)  = shifts_nr;
% 
%     if pMC.refcha == 1 && ~isempty(GreenCha)
%         GreenCha = apply_shifts(GreenCha, shifts_nr, options_nr);
%     elseif pMC.refcha == 2 && ~isempty(RedCha)
%         RedCha = apply_shifts(RedCha, shifts_nr, options_nr);
%     end
% 
%     clear Ymr
% 
% end

function batch_append_dfcha_to_wDat(...
    Filename, iparams)
% batch_append_dfcha_to_wDat: plot MIP of segment to 
%   see match with brain side
%
% Usage:
%   batch_append_dfcha_to_wDat(...
%       Filename, iparams)
%
% Args:
%   Filename: name pattern of files to use
%       (default, [])
%   iparams: parameters to update
%       (fmetsuffix: suffix of metadata file)
%           (default, '_metadata.mat')
%       (dir_depth: depth of directory search)
%           (default, 0)
%       (bs_range: time before stim and after 
%           stim to use for baseline and df calculation in seconds (s))
%           (default, [-10 -0.5])
%       (sti_range: time before stim and after stim
%            to use for sti in seconds (s))
%           (default, [0 0])
%       (stat2use: stat to use from the set of
%           timepoints, max (1) or mean (0))
%           (default, 0)
%       (sign2use: use positive or negative changes
%           (by multipliying it by 1/-1))
%           (default, 1 (positive))
%           (-1 (negative))
%           (0 (absolute))
%       (stim2use: stimuli to use)
%           (default, 1)
%       (chunk_size: size of chunks)
%           (default, 20)
%       (corenumber: number of cores to use)
%           (default, 4)
%       (serId: server ID)
%           ('int' | ispc or ismac, to run locally)
% Notes

% default params
metpars = [];
metpars.fmetsuffix = '_prosmetadata.mat';
metpars.fisuffix = '_prosdata.mat';
metpars.fitoreject = {'BData', 'Zstack'};
metpars.dir_depth = 0;
metpars.bs_range = [-10 -0.5];
metpars.sti_range = [0 0];
metpars.stat2use = 0;
metpars.sign2use = 0;
metpars.stim2use = 1;
metpars.chunk_size = 20;
metpars.corenumber = 4;
metpars.serId = 'int';

if ~exist('Filename', 'var')
    Filename = [];
end

% update variables
if ~exist('iparams', 'var'); iparams = []; end
metpars = loparam_updater(metpars, iparams);

setup_parpool(metpars.serId, ...
    metpars.corenumber);

% define files to use
if metpars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
        metpars.fmetsuffix]);
elseif metpars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', metpars.fmetsuffix]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        metpars.fmetsuffix]);
end

f2run = str2rm(metpars.fitoreject, f2run);
f2run = {f2run.name}';
[filename, iDir] = split_path(f2run);
filename = strrep(filename, metpars.fmetsuffix, '');

if ~isempty(Filename)
    f2run = find(contains(filename, Filename));
    filename = filename(f2run);
    iDir = iDir(f2run);
end

fprintf(['Collecting DF images for ', ...
    num2str(numel(filename)), ' files\n'])

% plot sMod results
for i = 1:numel(filename)

    fprintf(['Running ', filename{i}, '\n'])
    
    tic
    load([iDir{i}, filesep, filename{i}, ...
        metpars.fmetsuffix], 'wDat');

    wDat = get_avg_df(wDat, filename{i}, ...
        metpars.stat2use, metpars.sign2use, ...
        iDir{i}, metpars.bs_range, ...
        metpars.sti_range, metpars.stim2use, ...
        metpars.chunk_size, metpars.corenumber, ...
        metpars.fisuffix);
    
    save([iDir{i}, filesep, filename{i}, ...
        metpars.fmetsuffix], 'wDat', '-append')
    toc

end

fprintf('... Done\n')

end

function wDat = get_avg_df(wDat, filename, ...
        stat2use, sign2use, iDir, ...
        bs_range, sti_range, stim2use, ...
        chunk_size, corenumber, fisuffix)
% get_avg_df: get median dfof green channel
%
% Usage:
%   get_avg_df(wDat, filename, ...
%       stat2use, sign2use, iDir)
%
% Args:
%   wDat: input structure
%   filename: file name
%   stat2use: stat to use from the set of timepoints, max (1) or mean (0)
%       (default, 0)
%   sign2use: use positive or negative changes (by multipliying it by 1/-1).
%       (default, 1 (positive))
%       (-1 (negative))
%       (0 (absolute))
%   iDir: filename directory
%   bs_range: time before stim and after 
%       stim to use for baseline and df calculation in seconds (s))
%       (default, [-10 -0.5])
%   sti_range: time before stim and after stim
%       to use for sti in seconds (s))
%       (default, [0 0])
%   stim2use: stimuli to use)
%       (default, 1)
%   chunk_size: size of chunks.
%   corenumber: number of cores to use.
%   fisuffix: suffix of raw data

dt = diff(wDat.fTime(1:2));
bs_range_f = bs_range/dt;
sti_range_f = sti_range/dt;

% get Y handle
dataObj = matfile([iDir, filesep, ...
    filename, fisuffix], 'writable', false);

% collect stimuli info
stimuli_name = cellfun(@(x, y) [x '_AMP_' num2str(y)], ...
wDat.sPars.name(1, :), chunk2cell(wDat.sPars.int(1, :), 1), ...
'UniformOutput', false);

% assumes that stim order is the same across all segments
[sName, ~, stim_u_idx] = unique(stimuli_name, 'stable');
stim_all_idx = stim_u_idx(wDat.sPars.order(1, :));

if size(stim_all_idx, 1) == 1
    stim_all_idx = stim_all_idx';
end

sIdx = stim_all_idx(1:size(wDat.sTime, 1), 1);

% get Y dimensions
siz = dataObj.sizY;

% reduce stimuli to only available ones;
stim2use = intersect(stim2use, unique(stim_all_idx'));

fprintf(['Runing stimuli: ', num2str(stim2use), '\n'])
for i = stim2use
   display(sName{i})
end

stim_dfof_p_sti = zeros([siz(1:end-1), numel(stim2use)]);

for sti_i = 1:numel(stim2use)
    
    % select stim to use
    sti_En = getStim_InitEnd(wDat.fTime, ...
        wDat.sTime(ismember(sIdx, stim2use(sti_i)), :));
    
    for t_i = 1:size(sti_En, 1)
        
        if length(siz) == 4
            stim_dfof(:, :, :, t_i) = ...
                get_avg_df_per_stim(dataObj, ...
                sti_En(t_i, :), bs_range_f, sti_range_f, sign2use, ...
                stat2use, chunk_size, corenumber);
        else
            stim_dfof(:, :, t_i) = ...
                get_avg_df_per_stim(dataObj, ...
                sti_En(t_i, :), bs_range_f, sti_range_f, sign2use, ...
                stat2use, chunk_size, corenumber);            
        end
        
    end
    
    if length(siz) == 4
        stim_dfof_p_sti(:, :, :, sti_i) = ...
            median(stim_dfof, length(siz));
    else
        stim_dfof_p_sti(:, :, sti_i) = ...
            median(stim_dfof, length(siz));
    end
    
end

wDat.GreenChaDfof = stim_dfof_p_sti;

end

function stim_dfof = get_avg_df_per_stim(dataObj, ...
    sti_En, bs_range_f, sti_range_f, sign2use, ...
    stat2use, chunk_size, corenumber)
% get_avg_df_per_stim: generate mean/max dfof volume/plane
%
% Usage:
%   stim_dfof = get_avg_df_per_stim(dataObj, ...
%       sti_En, bs_range_f, sti_range_f, sign2use, ...
%       stat2use, chunk_size, corenumber)
%
% Args:
%   dataObj: data object, data is stored at Y
%   sti_En: stimulus onset and offset
%   bs_range_f: time before stim and after stim 
%       to use for baseline and df calculation in timepoints
%   sti_range_f: time before stim and after stim 
%       to use for sti in timepoints
%   sign2use: use positive or negative changes (by multipliying it by 1/-1).
%       (default, 1 (positive))
%       (-1 (negative))
%       (0 (absolute))
%   stat2use: stat to use from the set of timepoints, max (1) or mean (0)
%       (default, 0)
%   chunk_size: size of chunks.
%   corenumber: number of cores to use.

for i = 1:size(sti_En, 1)
    baseline_tp{i} = (sti_En(i, 1) + bs_range_f(1)): ...
            sti_En(i, 1) + bs_range_f(2);
    stim_tp{i} = (sti_En(i, 1) + sti_range_f(1)): ...
            (sti_En(i, 2) + sti_range_f(2));
end
baseline_tp = cell2mat(baseline_tp);
stim_tp = cell2mat(stim_tp);

fprintf('load and generate baseline\n')

% get Y dimensions
siz = dataObj.sizY;

tic
bas_mean = mean(stackloader(dataObj, ...
    baseline_tp, chunk_size, corenumber), ...
    length(siz));
toc

fprintf('generate df\n')

tic
stim_dfof = stackloader(dataObj, stim_tp, ...
    chunk_size, corenumber);
    
stim_dfof = imblur(stim_dfof - bas_mean, 1, 3, length(siz) - 1);

if sign2use == 0
    stim_dfof = abs(stim_dfof);
else
    stim_dfof = sign2use*stim_dfof;
end

stim_dfof = stim_dfof./abs(imblur(bas_mean, 1, 3, length(siz) - 1));

if stat2use == 0
    stim_dfof = mean(stim_dfof, length(siz));
else
    stim_dfof = max(stim_dfof, [], length(siz));
end

toc

end

function Y = stackloader(dataObj, ...
    time2load, chunk_size, corenumber)
% stackloader: load variable timepoint by timepoint
%
% Usage:
%   Y = stackloader(dataObj, ...
%       time2load, siz, chunk_size, corenumber)
%
% Args:
%   dataObj: data object, data is stored at Y.
%   time2load: tipemoints to load.
%   chunk_size: size of chunks.
%   corenumber: number of cores to use.

siz = dataObj.sizY;

% check that time2load are all positive integers
error_flag = numel(find(time2load <= 0));
if error_flag
    fprintf('Time points are negative')
    display(time2load)
end

% initialize variables
if length(siz) == 4
    Y = zeros([siz(1:3) numel(time2load)]);
else
    Y = zeros([siz(1:2) numel(time2load)]);
end

[~, ~, chunk_idx] = ...
    ppool_makechunks(chunk_size, ....
    corenumber, numel(time2load));

% time patches    
for j = 1:numel(chunk_idx)

    if j == 1
        t0 = stic;
    end

    batch2run = chunk_idx{j};
    t_idx = cell(corenumber, 1);
    temp_i = cell(corenumber, 1);

    parfor ii = 1:numel(batch2run)

        t_idx{ii, 1} = (batch2run(ii):min(batch2run(ii) + ...
            chunk_size - 1, numel(time2load)))';
        iv = 1;

        for iii = t_idx{ii, 1}'

            if length(siz) == 4
                temp_i{ii}(:, :, :, iv) = ...
                    double(dataObj.Y(:, :, :, time2load(iii)));
            else
                temp_i{ii}(:, :, iv) = ...
                    double(dataObj.Y(:, :, time2load(iii)));
            end
            iv = iv + 1;

        end

    end

    t_idx = cell2mat(t_idx);
    temp_i = temp_i(~cellfun(@(x) isempty(x), temp_i));
    
    if length(siz) == 4
        Y(:, :, :, t_idx) = cat(4, temp_i{:});
    else
        Y(:, :, t_idx) = cat(3, temp_i{:});
    end        

    if j == 1 
        stocf(t0, 'Time per chunk ');
        fprintf(['Estimated time ', ...
            num2str(stoc(t0)*numel(chunk_idx)/60), ...
            ' minutes\n'])
    end

    if mod(j, 10) == 0
        fprintf('%2.1f%% of chunks completed \n', ...
            j*100/numel(chunk_idx));
    end

end
    
end

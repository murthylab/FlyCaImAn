function batch_plot_df_SNR_F_over_z(Filename, oDir, iparams)
% batch_plot_df_SNR_F_over_z: Generate raw data videos 
%   (DF, SNR, or raw fluorescence from gren or red channel) for selected
%   files
%
% Usage:
%   batch_plot_df_SNR_F_over_z(Filename, oDir, iparams)
%
% Args:
%   Filename: name pattern of files to use
%       (default, [])
%   oDir: output directory.
%   iparams: parameters to update
%       (metadata_suffix: suffix of files to load, metadata files)
%       (redo: redo flag)
%           (default, 0 )
%       %%%%%%%%%%%% video settings %%%%%%%%%%%%
%       (vgate: save gate)
%       (vquality: video quality)
%       (frate: frame rate)
%       (cmap: foreground image colormap)
%       (range: intensity range for each type of video)
%       (axisratio: axis ratio to use, see variable within 'slice3Dmatrix')
%       %%%%%%%%%%%% DF calculation %%%%%%%%%%%%
%       (vid2plot: logical defining which videos to plot)
%           (default, [1 1 1 1] (plot all))
%           ([df, SNR, red, green])
%       %%%%%%%%%%%% extra %%%%%%%%%%%%
%       (dir_depth: depth of directory search)
%           (default, 0)
%
% Notes:
%   See get_df_MIP

% parameters
ipars.metadata_suffix = '_metadata.mat';
ipars.redo = 0;
ipars.vgate = 1;
ipars.vquality = 100;
ipars.frate = 10;
ipars.cmap = {buildcmap('rwb'), buildcmap('rwb'), ...
    buildcmap('kr'), buildcmap('kg')};
ipars.range = [-.5 .5; -1 1; 0 150; 0 300];
ipars.axisratio = 1;
ipars.vid2plot = [1 1 1 1];
ipars.fields2plot = {'GreenChaDfof', 'GreenChaSNR', ...
    'RedChaMean', 'GreenChaMean'};
ipars.vidprefix = {'_dfof_perplane', '_snr_perplane', ...
    '_r_mean_perplane', '_g_mean_perplane'};
ipars.dir_depth = 0;

if ~exist('Filename', 'var')
    Filename = [];
end

if ~exist('oDir', 'var') || isempty(oDir)
    oDir = [pwd, filesep, 'dfrel_vid'];
end

if ~exist('iparams', 'var'); iparams = []; end
ipars = loparam_updater(ipars, iparams);

if exist('oDir', 'var') && ...
        ~isempty(oDir) && ~exist(oDir, 'dir')
    mkdir(oDir)
end

% define files to use
if ipars.dir_depth == 0
    f2run = rdir(['.', filesep, '*', ...
        ipars.metadata_suffix]);
elseif ipars.dir_depth == 1
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', ipars.metadata_suffix]);
else
    f2run = rdir(['.', filesep, '*', ...
        filesep, '*', filesep, '*', ...
        ipars.metadata_suffix]);
end

f2run = {f2run.name}';
f2run = str2rm({'Zstack'}, f2run);
[filename, iDir] = split_path(f2run);
filename = strrep(filename, ipars.metadata_suffix, '');

if ~isempty(Filename)
    f2run = find(contains(filename, Filename));
    filename = filename(f2run);
    iDir = iDir(f2run);
end

fprintf(['Generating videos for ', ...
    num2str(numel(filename)), ' files\n'])

video_suffix = ipars.vidprefix;
colormap_matrix = ipars.cmap;
image_range = ipars.range;

for i = 1:numel(filename)
    
        tic
        fprintf(['plotting ', filename{i}, '\n'])
        
        load([iDir{i}, filesep, filename{i}, ...
            ipars.metadata_suffix], 'wDat')

        if i == numel(filename)
            ipars.cbargate = 1;
        else
            ipars.cbargate = 0;
        end
        
        % generate videos
        for ii = 1:numel(video_suffix)

            ipars.vname = [oDir, filesep, filename{i}, video_suffix{ii}];
            
            if ipars.vid2plot(ii) && (~exist([ipars.vname, '.avi'], 'file') || ipars.redo)
            
                fprintf(['plot ', video_suffix{ii}, ' \n'])
                ipars.cmap = colormap_matrix{ii};
                ipars.range = image_range(ii, :);
                eval(['ipars.sizY = size(wDat.', ipars.fields2plot{ii}, ');'])
                eval(['slice3Dmatrix(flip(wDat.', ipars.fields2plot{ii}, ', 2), ipars)'])
                
            end

        end
                
        clear wDat
        toc

end

end

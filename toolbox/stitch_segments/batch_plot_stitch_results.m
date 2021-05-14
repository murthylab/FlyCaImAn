function batch_plot_stitch_results(Filename, oDir, iparams)
% batch_plot_stitch_results: plot stitching results
%
% Usage:
%   batch_plot_stitch_results(FileName, oDir, iparams)
%
% Args:
%   Filename: name pattern of files to use
%       (default, [])
%   oDir: output directory.
%   iparams: parameters to update
%       (fmetsuffix: suffix of metadata file)
%           (default, '_metadata.mat')
%       (range: range for plotting)
%           (default, [0 1])
%       (refcha: reference channel to use for plotting overlay)
%           (default, 1)
%       (dir_depth: depth of directory search)
%           (default, 0)
%       (axisratio: flag to use equal axis or not)
%
% Notes

% default params
metpars = [];
metpars.fmetsuffix = '_prosmetadata.mat';
metpars.range = [0 1];
metpars.refcha = 1;
metpars.dir_depth = 0;
metpars.axisratio = 1;

if ~exist('Filename', 'var')
    Filename = [];
end

if isempty(oDir)
    oDir = [pwd, filesep, 'stitch'];
end

% update variables
if ~exist('iparams', 'var'); iparams = []; end
metpars = loparam_updater(metpars, iparams);

if ~isempty(oDir) && ~exist(oDir, 'dir')
    mkdir(oDir)
end

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

f2run = {f2run.name}';
[filename, iDir] = split_path(f2run);
filename = strrep(filename, metpars.fmetsuffix, '');

if ~isempty(Filename)
    f2run = find(contains(filename, Filename));
    filename = filename(f2run);
    iDir = iDir(f2run);
end

fprintf(['Generating plots for ', ...
    num2str(numel(filename)), ' files\n'])

% plot stitch results
for i = 1:numel(filename)

    load([iDir{i}, filesep, filename{i}, ...
        metpars.fmetsuffix], 'wDat');

    plot_stitch_results(wDat, filename{i}, ...
        oDir, metpars)

end

fprintf('... Done\n')

end

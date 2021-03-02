function batch_signalextract(FolderName, FileName, iparams)
% batch_signalextract(FolderName, FileName, iparams, roiparams)
% roiparams need to be provided
global p
p = [];
p.cDir = pwd;
p.sep = filesep;
p.fo2reject = {'.', '..', 'preprocessed', 'BData'};
p.fi2reject = {'Zstack'};
p.FolderName = []; 
p.FileName = [];
p.corenum = 1; % numbre of cores to request
p.fisuffix = '_prosroi'; 
p.orawfsuffix = '_prosdata';
p.orefsuffix = '_prosref';
p.osuffix = '_prosroi';
p.redo = 0;
p.serverid = 'int';
p.corenum = 1;

if ~exist('iparams', 'var'); iparams = []; end
p = loparam_updater(p, iparams);

if exist('FolderName','var'); p.FolderName = FolderName; end
if exist('FileName','var'); p.FileName = FileName; end

% set up parpool
setup_parpool(p.serverid, p.corenum);

% Selecting folders
f2run = dir;
f2run = str2match(p.FolderName, f2run);
f2run = str2rm(p.fo2reject, f2run);
f2run = {f2run.name};
fprintf(['Running n-folders : ', num2str(numel(f2run)), '\n'])

for i = 1:numel(f2run)
    
    fprintf(['Running folder : ', f2run{i}, '\n']); 
    cd(f2run{i})
    runperfolder(p.FileName)
    cd(p.cDir)
    fprintf('\n')
    
end

delete(gcp)
fprintf('... Done\n')

end

function runperfolder(fname)

global p

% Run all flies per folder
f2run = rdir(['.', p.sep, '*', p.fisuffix, '.mat']);
f2run = str2rm(p.fi2reject, f2run);
f2run = str2match(fname, f2run);
f2run = {f2run.name};
f2run = strrep(f2run, ['.', p.sep], '');
f2run = strrep(f2run, [p.fisuffix, '.mat'], '');
f2run = unique(f2run);

fprintf(['Extracting signal from ', num2str(numel(f2run)),' flies\n'])

for fly_i = 1:numel(f2run)
    fprintf(['Extracting signal from fly: ', f2run{fly_i} ,'\n'])
    batch_getCatrace(f2run{fly_i});
end

end

function batch_getCatrace(filename)
% batch_CaROISeg(FileName, roiparams)
% segment ROIs from 2DxT or 3DxT data (not big data though)
% runs ROI segmentation per mat file, it requires the mat file to be in the right mat format

% parameters
global p
obj = CaROISeg;
% load roi data
load([filename, p.osuffix], 'roi')
% populate fields
populate_obj(obj, roi)
% add Green-Data
obj.data = matfile([filename, p.orawfsuffix, '.mat'], 'Writable', true);
userparams = roi.userparams;

% run signal extraction
if ~isfield(roi, 'filtered_') || ~isfield(roi, 'filtered') ...
        || isempty(roi.filtered_) || p.redo
    
    % extract signal from raw data
    rawsignal(obj, [filename, p.orefsuffix])
    % extract signal from raw and ref data
    %rawsignal_red(obj, [filename, p.orefsuffix])
    bas_estimate(obj)
    roi = snapshot(obj);
    roi.userparams = userparams;
    save([filename, p.osuffix], 'roi', '-append')
    
else
    
    fprintf(['Already extracted signal of fly: ', filename, '\n']);
    display([p.cDir, p.sep, filename, p.osuffix, '.mat'])
    
end

end

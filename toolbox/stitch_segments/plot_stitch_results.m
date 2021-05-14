function plot_stitch_results(wDat, ...
    fname, oDir, iparams)
% plot_stitch_results: plot stitch results
%
% Usage:
%   plot_stitch_results(wDat, ...
%       fname, oDir, iparams)
%
% Args:
%   wDat: input structure
%   fname: figure name
%   oDir: output directory to save figures or videos
%   iparams: parameters to update
%       (range: range of intensity to display)
%       (refcha: reference channel (red channel == 1, green channel == 2))
%       (axisratio: flag to use equal axis or not)

% default params
ip.range = [0 1];
ip.refcha = 1;

if ~exist('iparams', 'var'); iparams = []; end
ip = loparam_updater(ip, iparams);

% 1) plot overlay of edges
if ip.refcha == 1
    im = double(wDat.RedChaMean);
elseif ip.refcha == 2
    im = double(wDat.GreenChaMean);
end

im = im - prctile(im(:), 1);
im = im/prctile(im(:), 99);

stack_idx = wDat.Zstitch.Zidx;
n_stack = numel(unique(stack_idx));

if n_stack <= 4
    x_sp = 2; y_sp = 2;
elseif n_stack > 4 && n_stack <= 6
    x_sp = 3; y_sp = 2;
elseif n_stack > 6 && n_stack <= 9
    x_sp = 3; y_sp = 3;
else
    x_sp = 4; y_sp = 4;
end

[figH, axH] = makefigs(y_sp, x_sp, [1000 700], 'whole');
figH.Name = strrep(fname, '_', '-');

for i = unique(stack_idx)'
   
    try
        
        % start and end of stacks to stitch
        if strcmp(wDat.vOrient, 'invert')
            idx_i = find(stack_idx == i, 1, 'first');
            idx_e = find(stack_idx == i + 1, 1, 'last');
        else
            idx_i = find(stack_idx == i, 1, 'last');
            idx_e = find(stack_idx == i + 1, 1, 'first');
        end
        
        im_1 = mat2gray(im(:, :, idx_i), ip.range);
        im_2 = mat2gray(im(:, :, idx_e), ip.range);

        C = imfuse(im_1, im_2, ...
           'falsecolor', 'Scaling', ...
           'joint', 'ColorChannels', ...
           [1 2 0]);
        imshow(C, 'Parent', axH(i))
        axH(i).Title.String = ['stack ', num2str(i)];
        
    catch error
        error
    end
    
end

% 2) plot and save video

ip.vgate = 1;
ip.frate = 1;
ip.vname = [oDir, filesep, fname, '_red'];
ip.axisratio = 1;

if ~exist('iparams', 'var'); iparams = []; end
ip = loparam_updater(ip, iparams);

im = double(wDat.RedChaMean);
im = im - prctile(im(:), 1);
im = im/prctile(im(:), 99);

slice3Dmatrix(im, ip)

ip.vname = [oDir, filesep, fname, '_green'];

im = double(wDat.GreenChaMean);
im = im - prctile(im(:), 1);
im = im/prctile(im(:), 99);

slice3Dmatrix(im, ip)

savefig_int(figH, oDir, [fname, '_stitch'], ...
    [0 0 0 0 0 0 0 0 1])
close(figH)

end

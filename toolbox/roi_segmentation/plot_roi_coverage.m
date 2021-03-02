function plot_roi_coverage(filename, ...
    vid2plot, wDat, roi, oDir, roi2sel, cha2use)
% plot_roi_coverage: plot roi coverage
%   it plot both sum of max norm weights 
%   and binarized voxels
%
% Usage:
%   plot_roi_coverage(filename, ...
%       vid2plot, wDat, roi, oDir, roi2sel, cha2use)
%
% Args:
%   filename: file name
%   vid2plot: type of video to plot
%       [1 0 0] energy normalized, [0 1 0] max normalized, [0 0 1] binarized
%       (default, [1 1 1])
%   wDat: metadata parameter
%   roi: roi parameter
%   oDir: output directory
%   roi2sel: indeces of ROIs to use
%   channel2use: define the channel to use

if ~exist('vid2plot', 'var') || isempty(vid2plot)
   vid2plot = [1 1 1];
end

if ~exist('roi2sel', 'var') || isempty(roi2sel)
   roi2sel = [];
end

if ~exist('oDir', 'var') || isempty(oDir)
   oDir = pwd;
end

if ~exist('cha2use', 'var') || isempty(cha2use)
   cha2use = 'wDat.GreenChaMean';
end

% deafult video settings
vidpar.xyzres = wDat.XYZres{2};
vidpar.overcor = [1 0 0];
vidpar.lag = 0.01;
vidpar.vgate = 1;
        
% set brackground image and intensity range
eval(['vidpar.Y2 = double(', cha2use,' )']); 
vidpar.Y2range = [0 prctile(vidpar.Y2(:), 95)];
vidpar.sizY = size(vidpar.Y2);
 
% collapse all ROIs into a single one
if ~isempty(roi2sel)
   roi.A = roi.A(:, roi2sel); 
end

% 1) energy normalized
A2use = [roi.A, roi.b];
K = size(A2use, 2);
nA = sqrt(sum(A2use.^2))';
A2use = A2use/spdiags(nA, 0, K, K);
A2use = A2use(:, 1:end-1);
A2use = double(full(sum(A2use, 2)));

if vid2plot(1)
    
    % plot video
    vidpar.range = [min(A2use(:))...
        prctile(A2use(A2use ~= 0), 95)];
    vidpar.vname = [oDir, filesep, filename, '_roicov_energyn'];
    slice3Dmatrix(A2use, vidpar);
    
end

% 2) max normalized
A2use = roi.A;
A2use = bsxfun(@times, A2use, 1./max(A2use, [], 1));
A2use = double(full(max(A2use, [], 2))); 

if vid2plot(2)
    
    % plot video
    vidpar.range = [min(A2use(:))...
        prctile(A2use(A2use ~= 0), 95)];
    vidpar.vname = [oDir, filesep, filename, '_roicov_maxn'];
    slice3Dmatrix(A2use, vidpar);
    
end

% 3) binarized
A2use = double(A2use > 0); 

if vid2plot(3)
    
    % plot video
    vidpar.range = [0 2];
    vidpar.vname = [oDir, filesep, filename, '_roicov_bin'];
    slice3Dmatrix(A2use, vidpar);
    
end

end

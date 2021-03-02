function rho = neighcorr_2D(Y, iparams)
% neighcorr_2D: Function that uses lc2Dgen to generate a correlation image
%   based on neighboring pixels, but in this case it deals better with big
%   matrices (memmap).
%
% Usage:
%   rho = neighcorr_2D(Y, iparams)
%
% Args:
%   Y: M x N x T movie
%   iparams: parameter variable
%
% Returns:
%   rho: M x N matrix, cross-correlation with adjacent pixel
%
% Notes: 
% splits volume in n parts and runs lc2Dgen on each

if ~exist('iparams', 'var'); iparams = []; end

neigh_2d.overlap = [2 2];
neigh_2d.chunksize = [50 50];
neigh_2d.timestamps = [];

neigh_2d = loparam_updater(neigh_2d, iparams);

memmaped = isobject(Y);

if memmaped
    sizY = Y.sizY;
    patches = construct_patches(sizY(1:end-1), ...
        neigh_2d.chunksize, neigh_2d.overlap);
else
    sizY = size(Y);
end

if memmaped
    
    fprintf('Running neighcorr_2D for big matrices ')
    
    for p_i = 1:length(patches)
        xi = patches{p_i}(1):patches{p_i}(2);
        yi = patches{p_i}(3):patches{p_i}(4);
        temp_rho{p_i} = lc2Dgen(Y.Y(xi, yi, :), neigh_2d.timestamps);
        fprintf('*')
    end
    
    fprintf(' ')
    
    % Correct interseccions
    rho = seampatch(patches, temp_rho, sizY);
    fprintf('\n')
    
else
    
    rho = lc2Dgen(Y);
    
end

end

function rho = lc2Dgen(data, timestamps)
% lc2Dgen: get local correlation of the calcium imaging data (8 neighboring pixels)
%
%
% Usage:
%   rho = lc2Dgen(data, timestamps)
%
% Args:
%   data: M x N x T movie
%   timestamps: parameter variable
%
% Returns:
%   rho: M x N matrix, cross-correlation with adjacent pixel
%
% Author: Yuanjun Gao

if exist('timestamps', 'var') && ~isempty(timestamps)
    data = data(:, :, timestamps);
end

[M, N, ~] = size(data);
rho = zeros(M, N);

%normalizing data
data = bsxfun(@minus, data, mean(data, 3));
dataStd = sqrt(mean(data.^2, 3));
data = bsxfun(@rdivide, data, dataStd);

%calculate cross-correlation
rho1 = mean(data(1:(end - 1), :, :) .* data(2:end, :, :), 3);
rho2 = mean(data(:, 1:(end - 1), :) .* data(:, 2:end, :), 3);
rho3 = mean(data(2:end, 2:end, :) .* data(1:(end - 1), 1:(end - 1), :), 3);
rho4 = mean(data(1:(end - 1), 2:end, :) .* data(2:end, 1:(end - 1), :), 3);

%add all cross-correlation
rho(1:(end - 1), :) = rho(1:(end - 1), :) + rho1;
rho(2:end, :) = rho(2:end, :) + rho1;
rho(:, 1:(end - 1)) = rho(:, 1:(end - 1)) + rho2;
rho(:, 2:end) = rho(:, 2:end) + rho2;
rho(1:(end - 1), 1:(end - 1)) = rho(1:(end - 1), 1:(end - 1)) + rho3;
rho(2:end, 2:end) = rho(2:end, 2:end) + rho3;
rho(1:(end - 1), 2:end) = rho(1:(end - 1), 2:end) + rho4;
rho(2:end, 1:(end - 1)) = rho(2:end, 1:(end - 1)) + rho4;

%normalize by number of adjacent pixels
nNgbr = 8 + zeros(M, N);
nNgbr([1,end], :) = nNgbr([1,end], :) - 3;
nNgbr(:, [1,end]) = nNgbr(:, [1,end]) - 3;
nNgbr(1, 1) = nNgbr(1, 1) + 1;
nNgbr(1, end) = nNgbr(1, end) + 1;
nNgbr(end, 1) = nNgbr(end, 1) + 1;
nNgbr(end, end) = nNgbr(end, end) + 1;

rho = rho ./ nNgbr;

rho(isnan(rho)) = 0;

end

function rho = seampatch(patches, rho_i, dims)
% seampatch: function that merges partially computed patches of a matrix
%   matrix
%
% Usage:
%   rho = seampatch(patches, rho_i, dims)
%
% Args:
%   patches: X,Y,Z patches
%   rho_i: M x N matrix, cross-correlation with adjacent pixel per patch
%   dims: dimensions of the full matrix

% Final matrix
rho = zeros(dims(1:end-1));

% get unique column and row values
for p_i = 1:length(patches)
    rowidx(p_i, :) = [patches{p_i}(1), patches{p_i}(2)];
    colidx(p_i, :) = [patches{p_i}(3), patches{p_i}(4)];
    if length(patches{p_i}) == 6
        depthidx(p_i, :) = [patches{p_i}(5), patches{p_i}(6)];
    end
end
rownum = sort(unique(rowidx(:, 1)));
colnum = sort(unique(colidx(:, 1)));
if exist('depthidx', 'var')
    depthnum = sort(unique(depthidx(:, 1)));
end

% get cropped matrix from patches
for p_ii = 1:numel(patches)
    
    % Prunning edges (lateral)
    lsize = size(rho_i{p_ii});
    
    if lsize(2) ~= dims(2)
        
        if colidx(p_ii, 1) == colnum(1)
            yii = colidx(p_ii, 1):(colidx(p_ii, 2)-1);
            yi = 1:(lsize(2)-1);             
        elseif colidx(p_ii, 1) == colnum(end)
            yii = (colidx(p_ii, 1)+1):colidx(p_ii, 2);
            yi = 2:lsize(2);
        else
            yii = (colidx(p_ii, 1)+1):(colidx(p_ii, 2)-1);
            yi = 2:(lsize(2)-1);
        end
        
    else
        
       yii = 1:dims(2);
       yi = 1:lsize(2);
       
    end
    
    % Prunning edges (vertical)
    if lsize(1) ~= dims(1)
        
        if rowidx(p_ii, 1) == rownum(1)
            xii = rowidx(p_ii, 1):(rowidx(p_ii, 2)-1);
            xi = 1:(lsize(1)-1);            
        elseif rowidx(p_ii, 1) == rownum(end)
            xii = (rowidx(p_ii, 1)+1):rowidx(p_ii, 2);
            xi = 2:lsize(1);
        else
            xii = (rowidx(p_ii, 1)+1):(rowidx(p_ii, 2)-1);
            xi = 2:(lsize(1)-1);
        end
        
    else
        
       xii = 1:dims(1);
       xi = 1:lsize(1);
       
    end
    
    % prunning planes (depth)
    if exist('depthidx', 'var')
        
        if length(lsize) == 3 && lsize(3) ~= dims(3)
            
            if depthidx(p_ii, 1) == depthnum(1)
                zii = depthidx(p_ii, 1):(depthidx(p_ii, 2)-1);
                zi = 1:(lsize(1)-1);            
            elseif depthidx(p_ii, 1) == depthnum(end)
                zii = (depthidx(p_ii, 1)+1):depthidx(p_ii, 2);
                zi = 2:lsize(1);
            else
                zii = (depthidx(p_ii, 1)+1):(depthidx(p_ii, 2)-1);
                zi = 2:(lsize(1)-1);
            end
            
        else
            
           zii = 1:dims(1);
           zi = 1:lsize(1);
           
        end
        
    end
    
    if exist('depthidx', 'var')
        rho(xii, yii, zii) = rho_i{p_ii}(xi, yi, zi);
    else
        rho(xii, yii) = rho_i{p_ii}(xi, yi);
    end
    
    fprintf('+')
    
end

end

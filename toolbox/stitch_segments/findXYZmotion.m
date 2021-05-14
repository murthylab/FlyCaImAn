function coridx_per_xyz = findXYZmotion(refIm, floatIm, maxshift)
% findXYZmotion: gets the correlation of refIm to floatIm plus some shift
%   in x and y (from -maxshift to +maxshift)
%
% Usage:
%   coridx_per_xyz = findXYZmotion(refIm, floatIm, maxshift)
%
% Args:
%   refIm: reference image
%   floatIm: floating image
%   maxshift: maximun pixel shift in X/Y

coridx_per_xyz = zeros(1, size(floatIm, 3));
xrange = -maxshift:1:maxshift;
yrange = -maxshift:1:maxshift;

for z = 1:size(floatIm, 3)
    
    for x = xrange
        
        xi = find(xrange == x);
        
        for y = yrange
            
            yi = find(yrange == y);
            coridx_per_xyz(xi, yi, z) = ...
                corr2(refIm((1+maxshift):(end-maxshift-1), ...
                (1+maxshift):(end-maxshift-1)), ...
                floatIm((1+maxshift+x):(end-maxshift-1+x), ...
                (1+maxshift+y):(end-maxshift-1+y), z));
            
        end
        
    end
    
end

end

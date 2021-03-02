function Im = mat2uint8(Im, scale_flag)
% mat2uint8: convert matrix or vector to uint8, with the option of rescaling
%
% Im = mat2uint8(Im, scale_flag)
%
% Args:
%   Im: matrix/vector
%   scale_flag: flag to scale
%       (0: no scaling)
%       (1: assumed to be 0-1 range, then multiplying by 2^16)
%       (2: scale to min-max range, then multiplying by 2^16)

if ~exist('scale_flag', 'var') || isempty(scale_flag)
    scale_flag = 0;
end

if round(range(Im(:))) <= 1 && scale_flag == 1
    
    % Im range is assumed to be from 0-1
    Im = Im*2^8;
    
elseif scale_flag == 2
    
    % normalize to min and max then rescale
    Im = double(Im);
    Im = (Im - min(Im(:)))/max(Im(:));
    Im = Im*2^8;
    
end

Im = uint8(Im);

end

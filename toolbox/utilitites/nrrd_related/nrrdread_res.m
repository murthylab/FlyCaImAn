function iXYZres = nrrdread_res(meta)
% nrrdread_res: read pixel image resolution from nrrd metadata
%
% Usage:
%   iXYZres = nrrdread_res(meta)
%
% Args:
%   meta: nrrd metadata as output from nrrdread.m
%
% Returns:
%   iXYZres: pixel resolution ('x y z', 'width height depth')

fres = 10^4; % max resolution
init = strfind(meta.spacedirections, '(');
endt = strfind(meta.spacedirections, ')');

for i_axes = 1:numel(init)
    string_i = strsplit2(meta.spacedirections(init(i_axes)+1:endt(i_axes)-1), ',');
    iXYZres(1, i_axes) = round(str2double(string_i{i_axes})*fres)/fres;
end

end
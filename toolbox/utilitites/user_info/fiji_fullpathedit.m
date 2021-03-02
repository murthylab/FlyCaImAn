% copy, edit and save this function as 'fiji_fullpath.m'
% provide the right fiji directory per system (PC, mac)

function fijiDirs = fiji_fullpath
% fiji_fullpath: user defined directory of FIJI executable (full path) 
%
% Usage:
%   fijiDirs = fiji_fullpath
%
% Args:
%
% Output:
%   fijiDirs: directory of FIJI executable (full path)

% fijiDir

fijiDirs = [];

if ispc
    fijiDirs = 'C:\Users\*\Fiji.app\ImageJ-win64.exe';
elseif ismac
    fijiDirs = '/Applications/Fiji.app/Contents/MacOS/ImageJ-macosx';
end

end

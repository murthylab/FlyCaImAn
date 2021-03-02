function newstr = strprune(string, delimiter, string2keep)
% strprune: function to to split a string and reconstitutes parts of it
%
% Usage:
%   newstr = strprune(string, delimiter, string2keep)
%
% Args:
%   string: input string
%   delimiter: delimiter pattern to split string
%   string2keep: number of string pieces to keep
 
tokens = regexp(string, ['\s*\' delimiter '\s*'], 'split');

if numel(string2keep) == 1
    string2keep = 1:string2keep;
end

newstr = [];

for i = string2keep
    
    if i < string2keep(end)
        newstr = [newstr, tokens{i}, delimiter];
    else
        newstr = [newstr, tokens{i}];
    end
    
end

end

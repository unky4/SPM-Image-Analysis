function output = isdatacontains(data, words)
% Decides whether the data contains any of the words
% Input:
%   - data: the cell array where we search
%   - word: the search words in a cell
%
% Output:
%   - output: True/False. If any found then true.
%       - True: if the data somewhere contains any of the words defined
%               in the words cell
%       - False: else
%
    output = any(cellfun(@(x) ~isnumeric(x) && contains(x, words), data), 'all');
end
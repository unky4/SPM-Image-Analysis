function output = findfirstincell(data, word)
% Finds the first instance of a word in the data cell array
% Input:
%   - data: the cell array where we search
%   - word: the search word
%
% Output:
%   - output: the index where the word is located
%
    output = find(cellfun(@(x) ~isnumeric(x) && contains(x, word), data), 1, 'first');
end
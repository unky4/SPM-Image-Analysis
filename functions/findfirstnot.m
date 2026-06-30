function output = findfirstnot(data, word)
% Finds the first instance in the data cell array which is not the word (after this word appeared)
% Input:
%   - data: the cell array where we search
%   - word: the search word
%
% Output:
%   - output: the index where the word is located
%
    idx = findfirstincell(data, word);
    data = data(idx:end);
    output = find(cellfun(@(x) ~isnumeric(x) && ~contains(x, word), data), 1, 'first') + idx - 1;
end